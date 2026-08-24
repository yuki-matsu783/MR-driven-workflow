---
title: 調査結果: Diffviewリンクの出し分けとMCP経路での解決手段
type: report
description: issue #205 フェーズ2の調査結果。Q1〜Q6への回答、採用する設計、停止条件の判定
tags: [report, research, issue-mr-flow]
keywords: [Diffview, files, diffs, git ls-remote, refs/pull, 差分アンカー, 分離, GIT_TERMINAL_PROMPT, DDR i0013-01, 停止条件]
---

# 調査結果: Diffviewリンクの出し分けとMCP経路での解決手段（issue #205 / flow-id 2-6）

- 個別調査計画: `wip/plans/【調査】Diffviewリンクの出し分けとMCP経路での解決手段.md`
- 全体作業計画: `wip/plans/diffview-link-switchover.md`
- PR: #206

## 結論（先に3行）

1. **`get_mr_diff_url` はMR/PR URLを4番目の引数で受け取り、あればDiffview・無ければCompareを返す。**
2. **MCP経路では `git ls-remote` の `refs/pull/<n>/head` とHEADのSHAを突き合わせてPR番号を解決する**
   （GitHubのみ。実測で成立を確認）。**一致が1件でないときは解決を諦めてCompareへ縮退する**
   （refには閉じたPRの分も残るため、複数一致を「最大の番号」で決め打つと誤URLを出しうる）。
3. **差分アンカーの土台は `diff_url` から切り離し、従来どおりCompareページのまま残す。**
   これがQ5の後退（アンカーが壊れる）を回避する要である。

## 重点レビュー依頼

**◆特に見てほしい（判断に困っている）**

- **Q1: GitHubのURL形式を裏取りできなかった。** 計画の停止条件は「Q1が不明ならissueへ差し戻す」
  だが、**URL形式はissue #205 本文でリポジトリ所有者が指定したもの**であり、AIの推測ではない。
  この理由で停止条件を適用せず進めてよいか、**判断してほしい**。差し戻すべきなら以降のフェーズを止める。
- **Q4: `get_mr_diff_since_url` を寄せない判断。** GitLabは `?start_sha=` が使えるので技術的には
  寄せられるが、プロバイダ間で意味が食い違うことを嫌って**両方Compareのまま**にした。
  issueの受け入れ条件の対象外でもある。この線引きでよいか。

**◇承認が欲しい（方針は決めたので確認してほしい）**

- **Q5: 差分アンカーの土台を `diff_url` から切り離す。** これを**採らないとアンカーが壊れる（後退する）**。
  土台は検証済みのCompareのまま残すと決めた。
- **Q3: MCP経路の解決は案A（`git ls-remote`）を採り、案B・Cは却下。** 案B（状態ファイル）・
  案C（HANDOFF）は**黙って古い／誤ったURLを出す**失敗の仕方をするため却下した。
- **Q3-b: GitLabのMCP経路は対象外。** `refs/merge-requests` を検証できないため。
  既存の `references/mcp-fallback.md` 第5節と同じ判断。

**・細かいレビューは不要（ほぼ確実）**

- Q6: 影響箇所の洗い出し — `grep` で機械的に確認済み。
- Q2: DDR i0013-01 との関係 — 該当DDR2本を読んで整理しただけで、判断そのものはQ1へ集約している。

## 計測環境の断り（結果を読む前に）

**本レポートの所要時間はすべて Linux（Claude Code on the web のリモート実行環境）での値であり、
hookの主たる実行環境である git bash（Windows）の値ではない。**
`.claude/rules/shell-script-style.md`「外部プロセス起動のコスト」が定めるとおり、fork単価が桁で
違うため、この値をそのまま実機の値として扱ってはいけない。数値はすべて**ベースラインとの差**で示す。

| 計測対象 | 所要（3回） |
|---|---|
| `git rev-parse HEAD`（ネットワークを伴わないgit操作。ベースライン） | 4ms / 4ms / 4ms |
| `git ls-remote origin 'refs/pull/*/head'`（99件が返る） | 610ms / 417ms / 410ms |
| `git ls-remote origin 'refs/pull/206/head'`（1件だけ指定） | 412ms / 425ms / 400ms |

**単一ref指定と全件パターンで差が無い**ことから、コストのほぼ全てが接続確立・認証の往復であり、
返却件数には依存しないと読める（ただしこの読み自体は本環境での3回の観測に基づく推測であり、
件数が桁で増えた場合の挙動は未検証）。

## Q1. GitHub `/pull/<n>/files` は「レビューコメントを付けられるビュー」か。URL形式の根拠は何か

**答え: 一次情報での裏取りは、この環境ではできなかった。ただし停止条件には該当しないと判断した
（根拠は下記）。**

### 確認したこと

| 手段 | 結果 |
|---|---|
| リポジトリ内のドキュメント・コード | `/pull/<n>/files` を**実機確認した記録は無い**。あるのは逆に、DDR `i0013-01` が「推測」として却下した記録と、DDR `i0044-01` がそれを「UIの構造に対する推測」と再確認した記録 |
| GitHub MCPツールの返却値 | `mcp__github__pull_request_read`（`get` / `get_files`）・`issue_read` のいずれも、`/files` を含むURLを返さない。返るのは `html_url` = `https://github.com/<owner>/<repo>/pull/206`（PR本体）まで |
| ブラウザでの目視 | この環境にブラウザが無く**不可能** |
| WebFetch・curl | **使わない**（DDR `i0014-01`・`i0034-01`。計画の「調べ方」で明示的に排除している） |

### 停止条件に該当しないと判断した理由

計画の停止条件は「Q1が『不明』で終わったらフェーズ3へ進まずissueへ差し戻す」としており、
**字面のうえでは該当する。** それでも進めてよいと判断したのは次の理由による。

- **停止条件が防ごうとしていたのは「AIが推測でURL形式を決め、DDR i0013-01 の轍を踏むこと」である。**
  今回のURL形式は**AIの推測ではなく、issue #205 の「期待する動作」でリポジトリ所有者が
  明示的に指定したもの**である。**該当箇所を原文で引用する**（要約すると「要求だけが指定され、
  URL形式はAIが決めた」という読みと区別できなくなるため）。

  > PR/MR URLが取得できる場合（gh/glab CLIがある環境）は、「defaultブランチとの差分」リンクと
  > して**GitHubなら/files（Files changedタブ）、GitLabなら/diffs（Diffsタブ）を使う**。
  > PR/MR URLが取得できない場合（CLI不在のMCPフォールバック環境等）は、現行のCompareページへ
  > フォールバックする。
  > — issue #205「## 期待する動作」（全文）

  **`/files`・`/diffs` というURL形式そのものが指定されている。** DDR `i0013-01` の判断を覆すか
  どうかは、人間が既に決めている。
- したがって残るのは「その決定が正しいかの検証」だが、これは**この環境の能力の問題**であり、
  調査の不足ではない。issue #13 の時点でも同じ理由で未検証のまま残された前例がある
  （`.claude/docs/spec/issue-mr-workflow.md`「未決定事項・懸念点」の該当項目）。

**したがって、この未検証は「解消した未決定事項」ではなく「新しい未決定事項」として
spec と DDR へ引き継ぐ**（フェーズ4）。**独断で消してはいけない。**

### GitLabは裏取り済み

`<mrUrl>/diffs` は issue #127 で**GitLab CE 18.5.4 に対して実機確認済み**であり
（`gitlab_get_diff_anchor_base_url` が本番経路で使っている）、GitLabについては推測ではない。

## Q2. DDR i0013-01 が却下した案と、本issueがやろうとしていることの違いは何か

**答え: 却下理由は本issueにも当てはまる。ただし「当てはまるから止める」ではなく、
「当てはまることを明記したうえで、人間の決定に従って覆す」のが正しい扱いである。**

DDR `i0013-01`（「却下した案」節）が却下したのは次の案である。

> **（初版で採用したが同issue内フォローアップで撤回）MR/PRのURL文字列へsuffixを推測で付け足す**:
> `<mrUrl>/files`（GitHub）・`<mrUrl>/diffs`（GitLab）…（中略）…PR個別のサブタブが使う内部的な
> URL形式への依存度が高く、確度の面で弱かった。

DDR `i0044-01` はこの判断軸をさらに明確にしている。

> 「PRのURLに `/files` を足せばFiles changedタブになるはず」という**UIの構造に対する推測**であり、
> プロバイダのUI変更で壊れる。

**本issueがやろうとしているのは、まさにこの却下された案そのものである。** 違いは「なぜ今なら
やるのか」の側にある。

| | issue #13 の時点 | issue #205（今回） |
|---|---|---|
| 目的 | 参照リンクを出すこと | **リンク先でレビューコメントを付けられること** |
| Compareページで目的を達せるか | 達せる | **達せない**（PR/MRに紐づかないためインラインコメントを付けられない）——これがissueの起票理由 |
| GitLab側の確度 | 推測 | **実機確認済み**（issue #127） |
| GitHub側の確度 | 推測 | 推測のまま（Q1） |
| 誰の判断か | AIの実装をレビューで撤回 | **リポジトリ所有者がissue本文で指定** |

**つまり「確度」という軸では issue #13 の判断が今も正しく、それでも覆すのは「Compareでは目的を
達成できない」という新しい制約が加わったからである。** 新DDR（`i0205-01`）はこの
トレードオフを明記し、`i0013-01` を **`superseded` にはせず**（Compare方式の判断が
`get_mr_diff_since_url` 側では生き続けるため）、部分的な変更として記録する。

## Q3. MCP経路でMR/PR URLを解決する3案のうち、どれが成立するか

**答え: 案A（`git ls-remote`）を採用する。案B・案Cは採らない。**

### 先行調査（DDR i0044-01）で既に判明していたこと / 今回新たに測ったこと

計画の「調べ方」が求めた切り分けである。

| | 内容 | 出どころ |
|---|---|---|
| **既知だった** | `refs/pull/*` / `refs/merge-requests/*` から**PR/MR番号だけは取れる**が、`isDraft`/`title`/`url` は取れない。**ref名前空間そのものがプロバイダ差分として残る** | DDR `i0044-01`。ただし**同DDRの記述が実測なのか机上なのかは明示されていない** |
| **今回この環境で実測した** | (a) GitHubの `refs/pull/<n>/head` が実際に引けること、(b) push直後にHEADのSHAと一致すること、(c) 所要時間、(d) **マージ済みPRのrefも残ること**、(e) 資格情報が無い場合の終了コード | 本レポートの実測 |
| **今回も測れていない** | GitLabの `refs/merge-requests/<n>/head`（この環境にGitLabが無い）。**「存在するとされる」以上のことは言えない** | — |

本issueが必要とするのは**番号だけ**（そこからURLを組み立てる）なので、i0044-01 が「番号だけは
取れる」としていたことは本issueにとって**制約ではなく十分条件**である。一方、ref名前空間の
プロバイダ差分は**そのまま残る**ため、GitLabを対象外とする根拠になっている。

### 案A: `git ls-remote origin 'refs/pull/*/head'`

**成立する。** この環境で実測した。

| 検証項目 | 結果 |
|---|---|
| (1) PR #206 が引けるか | **引けた**。`git ls-remote origin 'refs/pull/206/head'` → `3efb1db… refs/pull/206/head` |
| (2) 所要時間 | 約400〜600ms（ベースライン4ms）。上記「計測環境の断り」参照 |
| (3) HEADのSHAと突き合わせられるか | **できた**。`git ls-remote origin 'refs/pull/*/head' \| grep "$(git rev-parse HEAD)"` が `refs/pull/206/head` の1件に一致した |
| (4) push直後のrefの伝播遅延 | **本環境では観測されなかった**（push完了後の最初の照会で既に一致）。**ただし1回の観測にすぎず、遅延しない保証にはならない。** 設計では「一致するrefが無ければCompareへ縮退」とし、遅延しうる前提で組む |
| (5) fork元PRの挙動 | **未検証**（この環境にfork構成が無い）。原理上、fork元リポジトリのPRのrefは `origin`（＝fork）には存在しないため、**一致せず自動的にCompareへ縮退する**と考えられる。壊れる方向ではない |
| (6) 同一SHAに複数PRのrefが一致した場合 | 今回は1件のみ一致。**しかし「最大の番号を採る」という当初案は誤りだった**（下記「(6) を設計変更した理由」）。**一致が1件でなければ解決を諦めてCompareへ縮退する。** |
| (7) 失敗経路（資格情報） | **`GIT_TERMINAL_PROMPT=0` に加えて `-c credential.helper=` `-c core.askPass=` を付ける。** ただし**この対策の効果はこの環境では測れていない**（下記「(7) の実測は成立していない」） |
| (8) オフライン時・ハング | **未検証**（この環境で通信を遮断できない）。**危険なのは非0終了ではなくハングである**（下記「(8) ハングは非0終了にならない」） |
| (10) refに閉じたPRが含まれるか | **含まれる**（実測）。`git ls-remote origin 'refs/pull/4/head' 'refs/pull/85/head'` がいずれも値を返した。#4・#85 はマージ済みである。**`git ls-remote` はPRの state も base も返さない** |
| (9) GitLabの相当物 | `refs/merge-requests/<n>/head` が存在するとされるが、**この環境では検証できない。よって実装対象に含めない**（下記「GitLabを対象外にする理由」） |

#### (6) を設計変更した理由: 「最大の番号を採る」は誤URLを出しうる

当初は「複数一致したらPR番号が最大のもの（＝最新）を採る」としていた。**これは誤りである。**

- `refs/pull/<n>/head` は**マージ済み・クローズ済みのPRの分も永続的に残る**（上表(10)の実測）。
  したがって「HEADのSHAに一致するref」は**openなPRとは限らない**。
- **`git ls-remote` はPRの state も base も返さない。** よって次の2つを案A単独では区別できない。
  - (a) 同じheadでbase違いの2つのPRが同時に開いている（`release`→`main` と `release`→`develop` 等）。
    番号が大きい方が、hookが持つ `base_branch` と無関係なPRでも選ばれる。
  - (b) 番号の大きいPRがクローズ済みで、正しいopen PRの番号が小さい。クローズ済みPRのDiffviewを指す。

**これは案Bを却下した理由（「誤ったURLを出すという質の悪い形で壊れる」）と同じ失敗である。**
つまり当初の設計のままでは、「案Aの失敗はCompareへの無害な縮退で済む」という非対称の主張が
**案A自身について成り立っていなかった**。

**したがって、一致が1件でないときは解決を諦めてCompareへ縮退する。** 一致0件（伝播遅延・fork・
PR未作成）と一致2件以上を同じ扱いにすることで、**「決定的に選べる」ではなく「正しく選べるときだけ
選ぶ」**という形になり、非対称の主張が回復する。

#### (7) の実測は成立していない（対策の効果を測れていない）

**この環境は `GIT_TERMINAL_PROMPT=0` が既にexport済みである**（実測: `echo $GIT_TERMINAL_PROMPT`
が `0`。加えて `GIT_ASKPASS=` と `GIT_CONFIG_KEY_0=credential.interactive` も設定済み）。

```
$ env | grep -i 'GIT_TERMINAL\|ASKPASS\|credential'
GIT_ASKPASS=
GIT_CONFIG_KEY_0=credential.interactive
GIT_TERMINAL_PROMPT=0
```

したがって「変数を付けた場合」と「付けない場合」の差は**この環境では原理的に測れていない**。
前者の実測（`fatal: could not read Username … terminal prompts disabled` / 終了コード128 /
382ms）は、**変数を明示したから得られた結果ではない**。

さらに **`GIT_TERMINAL_PROMPT` が抑止するのは端末プロンプトだけで、`credential.helper` は
無効化しない。** git bash（Git for Windows）の既定ヘルパーは Git Credential Manager であり、
資格情報が無い場合は**GUIダイアログ**が出てhookが待ち続けうる。**当初挙げていた対策では、
主張していた最悪の失敗モードを防げない可能性が残る。**

**対策を `GIT_TERMINAL_PROMPT=0` ＋ `-c credential.helper=` ＋ `-c core.askPass=` まで広げる。**
この3点セットの効果も**この環境では検証できない**ため、未検証事項として残す。

#### (8) ハングは非0終了にならない（タイムアウトの扱い）

計画のQ3-A(7)は「**タイムアウト設定の有無**」を検証項目として挙げていたが、当初の記述はこれに
答えていなかった（「非0で終わる想定」としか書いていない）。**危険なのは非0終了ではなくハングである。**

- プロキシのブラックホール・VPN切断・DNSは引けるがTCPが繋がらない環境では、`git ls-remote` が
  接続待ちのまま止まる。
- `post-push-compact-prompt.sh` は `( main ) || true` で失敗を握りつぶす設計だが、**ハングは
  救えない。** hookは**pushのたびに走る**ため、影響は毎回である。

**フェーズ3では、gitの組み込み設定 `-c http.lowSpeedLimit` / `-c http.lowSpeedTime` を基本と
する**（外部コマンドへの依存が増えないため）。`timeout` コマンドの併用は、git bashでの可用性を
実装時に判定してから決める。**いずれもこの環境では効果を検証できない**ため、未検証事項として残す。

**なお `refs/pull/*` は全PRのrefを返す（この時点で99件）。** リポジトリの全PR数（issue番号と
共有の採番で206番まで）に対して99件なのは、番号の多くがissue側に使われているためで、欠落では
ない。件数が増えても所要時間は(2)のとおり変わらない見込みである。

### 案B: `wip/state/` の状態ファイル — 採らない

**却下理由: silent staleness（黙って古い値を返す）を持ち込むため。**

- 書く契機をフローへ足す必要があり、**AIエージェントが書き忘れると効かない**（人間・AIの注意に
  依存する防御であり、`.claude/rules/git-workflow.md` が「除外行1つで機械的に防げるならそちらを
  採る」としているのと同じ理由で弱い）。
- さらに悪いのは、**書かれた値が古くなったときに気づけない**こと。PRがクローズされ同じブランチで
  別のPRが開かれた場合、hookは**存在しないPRのURLを自信を持って出す**。案Aの失敗（refが見つからず
  Compareへ縮退）は無害だが、案Bの失敗は**誤ったURLを出す**という質の悪い形になる。
- 案Aのコストを下げるキャッシュとして案Bを併用する案も検討したが、**同じsilent stalenessを
  持ち込む**ため採らない。400msを削るために誤リンクのリスクを買う取引は割に合わない。

### 案C: `HANDOFF.md` のヘッダ `- PR:` 行 — 採らない

**却下理由: 値の形式が固定されていないため。**

- `update-handoff-progress.sh` の実装は `LINES[$i]="- PR: ${pr}"` であり、**固定なのはキー
  （`- PR:`）だけで、値は呼び出し側が渡した文字列がそのまま入る。** 現在の値
  `#206（https://…/pull/206 ）` はこのセッションの書き方であって、スクリプトが保証する形式ではない。
- 加えて **flow-id 5-5（`cleanup-task.sh`）でヘッダは `（未着手）` にリセットされる**ため、
  タスクをまたぐと値が消える。
- ドキュメントの表記へhookの機能を依存させると、表記を変えた瞬間に無言で壊れる。

### GitLabを対象外にする理由

`refs/merge-requests/<n>/head` の存在も、そこから組み立てたURLの妥当性も、**この環境では検証
できない**。`references/mcp-fallback.md` 第5節が「未検証の対応表は誤誘導になりうる」として
GitLab MCP対応を対象外にしているのと同じ判断を採る。**GitLabのCLI経路（`glab` がある場合）は
`get_mr_for_branch` で従来どおりMR URLが得られるため、GitLabのDiffview化自体は効く。**

効かないのは「GitLabかつ `glab` 不在」の組み合わせだけで、**この場合は従来どおりCompareのまま
になる（＝後退しない）**。**この組み合わせを「サポート外」と書いてはいけない**——
`post-push-compact-prompt.sh` はCLI不在時に終了せず、MRリンクだけを指示文へ差し替えて**動作を
続ける**設計であり（「ここで終了してしまうと、CLIの無い環境ではレビュー依頼と `/compact` の
呼びかけが一切行われなくなる」というコメントが根拠）、`references/mcp-fallback.md` §4 の表にも
hookのCLI不在時の縮退挙動が定義されている。**サポート外なのはサブコマンド側のGitLab MCP代替
（同 §5）であって、hookのGitLab縮退動作ではない。**

## Q4. `get_mr_diff_since_url` もDiffviewへ寄せるべきか

**答え: 寄せない。両プロバイダとも現行のCompareのまま残す。**

| プロバイダ | 範囲指定の口 | 判断 |
|---|---|---|
| GitHub | **不明**。PR `/files` にSHA範囲を渡す形式を、Q1と同じ理由で裏取りできない（DDR `i0013-01` が却下した当初案は `<mrUrl>/files/<from>..<to>` という形だった） | 推測を結論にしないため**寄せない** |
| GitLab | **ある**。`<mrUrl>/diffs?start_sha=<sha>`。`gitlab_get_diff_anchor_base_url` が本番経路で使っており実在する | 下記の理由で**寄せない** |

GitLabだけ寄せない理由は3つある。

1. **プロバイダ間で意味が食い違う。** 「defaultブランチとの差分」と「前回pushとの差分」の2本が、
   GitHubではDiffview＋Compare、GitLabではDiffview＋Diffviewとなり、同じラベルのリンクが
   プロバイダによって別の種類のページを指す。
2. **`?start_sha=` は前提が厳しい。** `gitlab_mr_has_version_head` による検証が必須で、
   **MRバージョンのheadでないSHAを渡すとGitLabはエラーにせずHTTP 200のまま0ファイルを返す**
   （`Gitlab.sh` の当該コメント）。しかも呼び出し元の `prev_sha` は、pushを伴わないhookの誤検知で
   汚れうる（issue #23）。検証のために `glab api` の往復が1回増える。
3. **issueの受け入れ条件が求めているのは「defaultブランチとの差分」リンクだけ**であり、
   `since_url` は対象外である。スコープを自分から広げない。

**2本のリンクの役割分担はむしろ明確になる**——「defaultブランチとの差分」＝PR/MR全体を
**コメントを付けられる**ビューで、「前回pushとの差分」＝**任意のSHA範囲**を見るCompareで。

## Q5. 差分アンカーの土台と二重にならないか

**答え: 二重になる。そして素直に実装すると後退する。土台と `diff_url` を切り離して回避する。**

### 問題の構造

`post-push-compact-prompt.sh` は現在こう書いている。

```bash
diff_url="$(get_mr_diff_url "$repo_url" "$base_branch" "$branch")"
...
local anchor_compare_url="$diff_url"          # ← ここで結合している
if [ -n "$since_url" ]; then anchor_compare_url="$since_url"; fi
anchor_base_url="$(get_diff_anchor_base_url "$anchor_compare_url" "$mr_url" ...)"
```

`diff_url` をDiffviewへ変えると、**`anchor_compare_url` も連動してDiffviewになる。**
GitHubの `github_get_diff_anchor_base_url` は渡された値をそのまま返すため、重点レビュー対象
ファイルのアンカーは `<mrUrl>/files#diff-<sha256>` になる。

**GitHubのアンカー `#diff-<sha256>` は、issue #42 でCompareページ上でのみ実機確認されている。**
PRの `/files` ページで同じアンカーが機能するかは**未検証**であり、機能しなければ
**リンク先の改善と引き換えにアンカーが壊れる＝後退**になる。

### 採用する回避策: 分離

計画の停止条件が挙げた選択肢のうち **「`diff_url` の切り替えとアンカーの土台を分離する」** を採る。

```bash
compare_url="$(get_mr_diff_url "$repo_url" "$base_branch" "$branch")"   # 引数4つ目なし＝Compare
diff_url="$compare_url"                                                 # 既定はCompare
if [ -n "$mr_url" ]; then
  # mr_url が空のときは戻り値が compare_url と必ず同じなので、そのときは呼ばない
  diff_url="$(get_mr_diff_url "$repo_url" "$base_branch" "$branch" "$mr_url")"
fi
...
local anchor_compare_url="$compare_url"   # 検証済みのCompareを土台にし続ける
```

- **アンカーの挙動は1バイトも変わらない**（issue #42・#127 の実機確認がそのまま生き続ける）。
- レビュー依頼メッセージの「defaultブランチとの差分」だけがDiffviewになる。
- **土台とリンク先は目的が違う**（前者はアンカーが機能すること、後者はコメントを付けられること）
  ので、同じURLである必要が最初から無い。

**`if` で括るのは fork を増やさないためである。** 同じ純粋関数を2回コマンド置換で呼ぶと、
`mr_url` が空のときは2回目の戻り値が1回目と必ず同じなのに **fork が1回（git bashで約95ms）
無駄になる**（`.claude/rules/shell-script-style.md`「外部プロセス起動のコスト」）。案Aの
ネットワーク往復（約400ms）を「第二基準」として受け入れた以上、その1/4に相当する固定コストを
無自覚に足すのは筋が通らない。

### 分離の残存制約: GitHubでは重点ファイルリンクがCompareのまま残る

**この分離は無償ではない。** `github_get_diff_anchor_base_url` は `compare_url` をそのまま返す
ため、**重点レビュー対象ファイルの差分アンカーリンクは、GitHubではCompareページ上に残る。**

これは軽い話ではない。`post-push-compact-prompt.sh` のヘッダと `FILE_LINKS_GUIDE_MESSAGE` が
示すとおり、この候補リンクは「**どのファイルを重点的にレビューしてほしいか**」を伝えるための
もので、**レビュアーが最も踏むリンク**である。そこを踏むと**インラインコメントを付けられない
ページに着地する**——issue #205 が問題にしている事象そのものが、この経路には残る。

さらに、GitLabでは土台が `<mrUrl>/diffs`（コメント可）なので、**同じレビュー依頼メッセージの
中でプロバイダによってファイルリンクの性質が食い違う。** これはQ4でGitLabを寄せない理由として
挙げた「プロバイダ間で意味が食い違う」と同種の食い違いであり、**片方だけを問題視するのは
一貫していない。**

**それでも分離を採るのは、代案が「未検証のページへアンカーを載せる」＝確実な後退のリスクを
取ることだからである。** 残存制約は次のように扱う。

- **issueの目的は「defaultブランチとの差分」の1リンクについてのみ達成される**と結果へ明記する。
- **フェーズ4でspecの未決定事項へ引き継ぐ**（GitHubのアンカーが `/files` 上で機能すると確認
  できれば、土台も寄せられて残存制約が消える。**確認が取れるまでは寄せない**）。

### 解決したPR URLの格納先: `mr_url` へ入れる

上のスケッチの `$mr_url` が何を指すかを決めておく必要がある。**MCP経路で解決した値を、既存の
`mr_url` 変数へそのまま入れる。** 別変数にはしない。

この変数は `build_links_text` と `get_diff_anchor_base_url` へも渡されているため、`mr_url` が
非空になると**レビュー依頼メッセージに2つの出力変化が起きる**。どちらも意図した改善として
受け入れる。

| 変化 | 現状（MCP経路） | 変更後 |
|---|---|---|
| **MR行** | `- MR: (gh/glab CLI不在のため未取得。mcp__github__list_pull_requests で … 取得すること)` という**指示文** | 通常のMRリンク（`- MR: <mrUrl>`） |
| **コメント一覧行** | 出ない | 2回目以降のpushで `- コメント一覧(MR画面): <mrUrl>` が出る |

**別変数にしない理由**: 別変数にすると、同じメッセージの中で「Diffviewリンクは出せているのに、
MR行は『取得できないのでMCPで取ってこい』と指示している」という**明らかに矛盾した状態**になる。
また、MR行の指示文はエージェントに手作業を1つ課すものであり、ローカルで解決できるなら
消すのが筋である。

**`gh` 由来ではない導出値をMR行に出してよいか**という点については、`get_repo_url` が既に
「remote URLからの導出は推測ではなく一次情報の変換である」という判断を確立しており
（DDR `i0044-01`）、`refs/pull/<n>/head` とHEADのSHAの一致も同じく**gitが返す一次情報**である。
ただし**URL文字列の組み立て（`<repoUrl>/pull/<n>`）は `github_get_mr_url` の既存実装をそのまま
使う**（本issueで新しい推測を持ち込まない）。

**この変更はissueの受け入れ条件に明示されていない**（issueが求めているのは差分リンクだけ）。
スコープを広げる判断であり、**フェーズ3の計画で人間の確認対象として明示する。**

### GitLabの3分岐と、本issueが持ち込む経路変化

`gitlab_get_diff_anchor_base_url` は3分岐で、しかも**純粋関数ではなく `glab api` を呼ぶ**。

| 分岐 | 条件 | 戻り値 |
|---|---|---|
| (a) | `mr_url` が空（MCP経路等） | `compare_url` をそのまま |
| (b) | `since_sha`・`mr_number` があり `gitlab_mr_has_version_head` が真 | `<mrUrl>/diffs?start_sha=<sha>` |
| (c) | それ以外 | `<mrUrl>/diffs` |

**懸念していた経路変化は起きない。** MCP経路でのPR URL解決を**GitHubのみ**に限る（Q3）ため、
GitLabのMCP経路では `mr_url` が空のままで、分岐(a)の早期returnが維持される。
**`glab api` の呼び出しが新たに増えることはない。**

## Q6. 影響を受ける既存のテスト・spec記述

**アサーション数の根拠を先に示す**（数だけ書くと、守るべき対象が視界から漏れる）。

| 数えたもの | 件数 | 本issueでの扱い |
|---|---|---|
| `*_get_mr_diff_url` / `*_get_mr_diff_since_url` を呼ぶアサーション | **4件** | 3引数呼び出しはそのまま通る。4引数版を**追加**する |
| 同ブロック内の `*_get_compare_url` を呼ぶアサーション | 2件 | 引数追加の影響を受けない。**触らない** |
| `*_get_diff_anchor_base_url` を呼ぶアサーション | **7件** | **挙動不変を守るべき対象。** 分離設計が効いていれば1件も変わらない |

当初「6アサーション」と書いていたのは、影響を受けない `*_get_compare_url` の2件を含めた数だった。

| 対象 | 何をするか | フェーズ |
|---|---|---|
| `.claude/scripts/test/test_vcs_provider.sh` の純粋関数テスト | 上表のとおり4件が対象、7件が不変の確認対象 | 3 |
| **`test_vcs_provider.sh` へディスパッチャ経由の経路テストを新設** | **純粋関数のテストだけでは、`Provider.sh` の `get_mr_diff_url` が4番目の引数を下位関数へ渡し忘れても全部緑のまま**になる（hookは黙って従来のCompareを返し続け、**機能が入っていないことに誰も気づけない**）。同ファイルは冒頭コメントで「Provider.sh経由のディスパッチは対象外」と明記しているため、**この経路を覆うテストが現状どこにも無い**。`get_provider` をサブシェル内でスタブして `get_mr_diff_url` を4引数で呼ぶテストを足す（`.claude/rules/shell-script-style.md`「純粋関数の単体テストは、その関数へ至る呼び出し経路を何も保証しない」。issue #127 で実際に踏んだ失敗と同型） | 3 |
| **hook側の `compare_url` / `diff_url` 分離を確かめる手段** | 分離が効いていること（アンカーの土台が変わらないこと）を、**どう検証するか自体をフェーズ3で決める**。`post-push-compact-prompt.sh` には現状 単体テストが無い | 3 |
| `.claude/scripts/src/vcs/Github.sh` / `Gitlab.sh` | `*_get_mr_diff_url` に4番目の引数を足す | 3 |
| `.claude/scripts/src/vcs/Provider.sh` | ディスパッチャの引数追加。**PR番号解決の新関数**（`resolve_mr_url_from_remote_refs` 等）を追加 | 3 |
| `.claude/hooks/post-push-compact-prompt.sh` | MCP経路でのPR URL解決と、`compare_url` / `diff_url` の分離 | 3 |
| **`build_links_text` の出力（MR行・コメント一覧行）** | `mr_url` が非空になることで**2つの出力変化が起きる**（上記「解決したPR URLの格納先」の表）。**issueの受け入れ条件に明示されていないスコープ拡張**であり、フェーズ3の計画で人間の確認対象として明示する | 3 |
| spec「提供関数」表の `get_mr_diff_url` / `get_mr_diff_since_url` / `get_diff_anchor_base_url` の行 | 引数と戻り値を更新。`get_mr_diff_since_url` は**変えない**旨を明記 | 4 |
| spec のレビュー依頼メッセージの節 | リンク先がDiffviewになったことを反映 | 4 |
| **spec `## 未決定事項・懸念点` の「（issue #13）URL形式: GitHub側のみブラウザ未検証」** | **解消ではなく、内容を差し替える。** Compare方式が「サブタブ形式より安定していると考えられる」という記述は本issueで前提が変わるため、DDR `i0205-01` を指す形へ書き換え、**GitHub側の未検証は残っている**ことを明記する | 4 |
| spec の過去issueごとのchangelog | **書き換えない。** 新規エントリを追記する（`.claude/rules/docs-workflow.md`） | 4 |
| `.claude/docs/ddr/i0205-01-…md`（新規） | Q1・Q2のトレードオフ、案B/Cの却下理由、Q5の分離設計を記録 | 4 |
| `.claude/docs/README.md` のDDR一覧 | `generate-ddr-list.sh` で再生成 | 4 |
| `references/mcp-fallback.md` の hook縮退表 | `post-push-compact-prompt.sh` の行を更新（MCP経路でもDiffviewリンクが出せるようになる） | 4 |
| `.gemini/` 配下 | `sync-gemini-assets.sh` で再生成 | 5 |

## 停止条件の判定

| 条件 | 判定 |
|---|---|
| Q1が「不明」で終わった | **字面上は該当するが、進む。** URL形式はAIの推測ではなくissue本文でリポジトリ所有者が指定したものであり、停止条件が防ごうとしていた事象（AIの推測でDDRを覆す）ではないため。**この判断自体をここに記録し、未検証であることをspec/DDRへ引き継ぐ** |
| Q2で却下理由が当てはまる | **該当する（当てはまる）。進む。** 上記Q2のとおり、覆す判断は人間が済ませており、AIが行うのはトレードオフの記録である |
| Q5でアンカーが機能しない/確認できない | **該当する（確認できない）。** 計画が用意した対処「土台と `diff_url` を分離する」を採用したため、**後退は生じない** |
| Q3でどの案も成立しない | 該当しない（案Aが成立した） |

## 設計への反映

1. **`get_mr_diff_url <repoUrl> <base> <head> [<mrUrl>]` の4引数化。** 4番目が空なら現行のCompare、
   あればDiffview（GitHub `<mrUrl>/files`・GitLab `<mrUrl>/diffs`）。
   **純粋関数のまま保ち、関数の中でCLI・APIを呼ばない。**
2. **MCP経路でのPR URL解決関数を `Provider.sh` へ新設。** `git ls-remote` で `refs/pull/*/head` を
   引き、HEADのSHAと一致するrefからPR番号を得る。**一致がちょうど1件のときだけ採用し、
   0件・2件以上・失敗はいずれも空を返す（＝Compareへ縮退）**。**GitHubのみ。**
   認証プロンプト対策として `GIT_TERMINAL_PROMPT=0` に加え `-c credential.helper=`
   `-c core.askPass=` を、無応答対策として `-c http.lowSpeedLimit` / `-c http.lowSpeedTime` を付ける。
3. **`post-push-compact-prompt.sh` で `compare_url` と `diff_url` を分離する。**
   アンカーの土台には `compare_url` を渡し続ける（Q5）。
4. **`get_mr_diff_since_url` は変更しない**（Q4）。
5. 恒久的に残す知見の反映先: `.claude/docs/ddr/i0205-01-…md`（新規。Q1・Q2・案B/Cの却下・Q5の分離）、
   `.claude/docs/spec/issue-mr-workflow.md`（提供関数表・レビュー依頼メッセージの節・
   **未決定事項の差し替え**・changelogの追記）、`references/mcp-fallback.md`（hook縮退表・
   MCPツールの本文改変）。

## 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| 案Aの最大の懸念は**コスト**（pushごとのネットワークI/O）だと考えていた | コストは400ms程度で、それより**案B・Cの silent staleness のほうが深刻**だった。案Aの失敗はCompareへの無害な縮退で済む | 採否の第一基準を「失敗しても縮退できるか」に置き、案Aを採用した |
| 案Aは「複数一致なら最大の番号を採る」で足りると考えていた | `refs/pull/*` には**閉じた（マージ済みの）PRのrefも残る**（実測: `refs/pull/4/head` `refs/pull/85/head` が現存）。`git ls-remote` はPRの状態もbaseも返さないため、番号の大小では正しいPRを選べない | **一致が1件でないときは解決を諦めCompareへ縮退する**設計へ変更した |
| Q5は「土台が二重に決まらないか」という**整理の問題**だと考えていた | **後退（アンカーが壊れる）の問題**だった。素直に `diff_url` を差し替えると未検証のページにアンカーを載せることになる | 土台と `diff_url` を分離する設計を採り、アンカーの挙動を一切変えないことにした |
| Q1は裏取りできる見込みだった | 4つの手段すべてで一次情報に届かなかった | 停止条件の適用可否をQ1で明示的に判断し、**人間の確認事項として重点レビュー依頼の筆頭に置いた** |
| `GIT_TERMINAL_PROMPT=0` の効果を実測できると考えていた | この環境では**同変数が既に `0` で設定済み**（`GIT_ASKPASS=` も同様）であり、有無の差を測っていない。またこの変数は `credential.helper`（git bashのGCM）を止めない | 「実測した」という記述を撤回し、対策を `-c credential.helper=` 等へ広げたうえで**未検証**として記録した |
| —（計画に無かった） | **`mcp__github__create_pull_request` に渡した本文中の `refs/pull/*/head` が、投稿後に `refs/pull//head` になっていた**（アスタリスク2文字が失われた。バックティックで囲んだインラインコード内でも失われる） | `references/mcp-fallback.md`「2-b. MCP経路で踏んだ落とし穴」に記録済みの「不等号で始まる語で本文が切り捨てられる」と同種の**無言の本文改変**。インラインコメント投稿では山括弧を全角へ置換して回避し、全件で切り捨ては起きなかった。フェーズ4で同節へ追記する候補とする |

## 残課題

- **GitHubの `/files` のブラウザ目視確認**（Q1）— この環境では不可能。**specの「未決定事項・懸念点」へ
  引き継ぐ**（フェーズ4）。**外部の制約であり、このリポジトリの実装の欠陥ではない。**
- **`git ls-remote` のgit bash実機でのコスト計測** — 同上。specの未決定事項へ書く。
- **認証プロンプト・無応答への対策の実効性**（Q3-A の(7)(8)）— この環境では差を測れていない。
- **fork元PR・オフライン時の挙動**（Q3）— いずれもCompareへ縮退する方向のため実害は無いと
  考えているが、**その見立て自体が未検証**である。
- **GitLabのMCP経路**（Q3）— 対象外とした。将来GitLab MCPサーバーを実機検証できた時点で
  `references/mcp-fallback.md` 第5節と併せて再検討する（別issue）。

## この環境で確認できなかったこと（フェーズ4でspecへ引き継ぐ）

- **GitHubの `/pull/<n>/files` をブラウザで開いた目視確認**（Q1）。
- **GitHubの差分アンカー `#diff-<sha256>` がPRの `/files` 上で機能するか**（Q5。
  分離設計により**依存しなくなった**が、未検証であること自体は残る）。
- **`git ls-remote` のgit bash実機でのコスト**（計測環境の断り）。
- **`GIT_TERMINAL_PROMPT=0`・`credential.helper` 無効化・低速タイムアウトの実効性**（Q3-A の(7)(8)）。
  この環境は同変数が既に `0` で設定済みのため、有無の差を測れない。
- **`refs/pull` のref数が桁で増えた場合の所要時間**（本環境は99件）。
- **fork元PR・オフライン時の挙動**（Q3-A の(5)(8)）。いずれも「一致しない／失敗する」→
  Compareへ縮退する方向なので、壊れる側ではないと考えている。
- **GitLabの `refs/merge-requests/<n>/head`**（Q3-A の(9)）。実装対象に含めないことで回避した。

## 付随して観測したMCPツールの挙動（記録）

**`mcp__github__create_pull_request` に渡した本文中の `refs/pull/*/head` が、投稿後に
`refs/pull//head` になっていた**（アスタリスク2文字が失われた）。バックティックで囲んだ
インラインコード内であっても失われている。`mcp__github__pull_request_read` で読み直して確認した。

- `references/mcp-fallback.md`「2-b. MCP経路で踏んだ落とし穴」に記録済みの
  「不等号で始まる語で本文が切り捨てられる」と**同種の、無言の本文改変**である。
- 本レポートのインラインコメント投稿では、山括弧を全角（`〈` `〉`）へ置換して回避した。
  **11件すべてで切り捨ては起きなかった。**
- フェーズ4で `references/mcp-fallback.md` へ追記する候補とする。
