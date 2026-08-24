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
   （GitHubのみ。実測で成立を確認）。失敗したらCompareへ縮退する。
3. **差分アンカーの土台は `diff_url` から切り離し、従来どおりCompareページのまま残す。**
   これがQ5の後退（アンカーが壊れる）を回避する要である。

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
  今回のURL形式（GitHub `/files`・GitLab `/diffs`）は**AIの推測ではなく、issue #205 の
  「期待する動作」でリポジトリ所有者が明示的に指定したもの**である。
  DDR `i0013-01` の判断を覆すかどうかは、**人間が既に決めている**。
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

### 案A: `git ls-remote origin 'refs/pull/*/head'`

**成立する。** この環境で実測した。

| 検証項目 | 結果 |
|---|---|
| (1) PR #206 が引けるか | **引けた**。`git ls-remote origin 'refs/pull/206/head'` → `3efb1db… refs/pull/206/head` |
| (2) 所要時間 | 約400〜600ms（ベースライン4ms）。上記「計測環境の断り」参照 |
| (3) HEADのSHAと突き合わせられるか | **できた**。`git ls-remote origin 'refs/pull/*/head' \| grep "$(git rev-parse HEAD)"` が `refs/pull/206/head` の1件に一致した |
| (4) push直後のrefの伝播遅延 | **本環境では観測されなかった**（push完了後の最初の照会で既に一致）。**ただし1回の観測にすぎず、遅延しない保証にはならない。** 設計では「一致するrefが無ければCompareへ縮退」とし、遅延しうる前提で組む |
| (5) fork元PRの挙動 | **未検証**（この環境にfork構成が無い）。原理上、fork元リポジトリのPRのrefは `origin`（＝fork）には存在しないため、**一致せず自動的にCompareへ縮退する**と考えられる。壊れる方向ではない |
| (6) 同一SHAに複数PRのrefが一致した場合 | 今回は1件のみ一致。**複数一致しうる**（同じブランチで2つのPRを開いた場合等）ため、設計では**PR番号が最大のもの（＝最新）を採る**。決定的に選べるので、pushごとに結果が揺れない |
| (7) 失敗経路 | **`GIT_TERMINAL_PROMPT=0` を明示的に付ける。** 資格情報が無い場合の実測は `fatal: could not read Username for 'https://github.com': terminal prompts disabled` / 終了コード128 / 382ms。**この環境は既定でプロンプトが無効だが、git bash実機では既定で有効であり、付けないと資格情報の入力待ちでブロックする**（pushの後処理が固まる最悪の失敗モード） |
| (8) オフライン時 | **未検証**（この環境で通信を遮断できない）。(7)と同じく非0で終わる想定で、呼び出し側は失敗を握りつぶしてCompareへ縮退する |
| (9) GitLabの相当物 | `refs/merge-requests/<n>/head` が存在するとされるが、**この環境では検証できない。よって実装対象に含めない**（下記「GitLabを対象外にする理由」） |

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
効かないのは「GitLabかつ `glab` 不在」の組み合わせだけで、これは元々サポート外である。

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
compare_url="$(get_mr_diff_url "$repo_url" "$base_branch" "$branch")"          # ← 引数4つ目なし＝Compare
diff_url="$(get_mr_diff_url "$repo_url" "$base_branch" "$branch" "$mr_url")"   # ← Diffview（無ければCompare）
...
local anchor_compare_url="$compare_url"   # ← 検証済みのCompareを土台にし続ける
```

- **アンカーの挙動は1バイトも変わらない**（issue #42・#127 の実機確認がそのまま生き続ける）。
- レビュー依頼メッセージの「defaultブランチとの差分」だけがDiffviewになる。
- **「未検証のものを増やさない」という点で、これは妥協ではなく正しい設計である。**
  土台とリンク先は目的が違う（前者はアンカーが機能すること、後者はコメントを付けられること）
  ので、同じURLである必要が最初から無い。

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

| 対象 | 何をするか | フェーズ |
|---|---|---|
| `.claude/scripts/test/test_vcs_provider.sh` の6アサーション | 既存の3引数呼び出し（Compareを返す）は**そのまま通る**。4引数版（Diffviewを返す）のアサーションを**追加**する | 3 |
| `.claude/scripts/src/vcs/Github.sh` / `Gitlab.sh` | `*_get_mr_diff_url` に4番目の引数を足す | 3 |
| `.claude/scripts/src/vcs/Provider.sh` | ディスパッチャの引数追加。**PR番号解決の新関数**（`resolve_mr_url_from_remote_refs` 等）を追加 | 3 |
| `.claude/hooks/post-push-compact-prompt.sh` | MCP経路でのPR URL解決と、`compare_url` / `diff_url` の分離 | 3 |
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

## この環境で確認できなかったこと（フェーズ4でspecへ引き継ぐ）

- **GitHubの `/pull/<n>/files` をブラウザで開いた目視確認**（Q1）。
- **GitHubの差分アンカー `#diff-<sha256>` がPRの `/files` 上で機能するか**（Q5。
  分離設計により**依存しなくなった**が、未検証であること自体は残る）。
- **`git ls-remote` のgit bash実機でのコスト**（計測環境の断り）。
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
