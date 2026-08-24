---
title: push前チェックリスト機構
type: spec
description: pushの前に済ませるべき作業を、pushごとに一意なGit管理下のTSVチェックリストとして持たせ、未完了ならPreToolUse hookがexit code 2でブロックする機構の仕様。
tags: [spec, hook, push, workflow]
keywords: [push前チェックリスト, PreToolUse, PostToolUse, push-checklist, TSV, verify, stale, ブロック, worklog, skip]
---

# push前チェックリスト機構

## 背景・目的

push前に済ませるべき作業——worklogの作成・追記、`HANDOFF.md` の進捗表・ヘッダの更新、
frontmatterインデックス（`index.jsonl`）の最新化、`wip/plans/` `wip/reports/` の md と html の
同期、`commit` スキル経由でのコミット——は、いずれもドキュメント上のルールとしてしか
存在しておらず、AIエージェントの遵守に依存していた。実際に、issue #17 の作業中だけでも
「`HANDOFF.md` の `- push回数:` をpushの後に更新し、その1行だけが未コミットで残る」という
形で1度失敗している。

そこで、**pushごとに一意なGit管理下のチェックリスト**を持たせ、未完了のままpushしようとした
場合に PreToolUse hook が **exit code 2** でブロックする。

**Git管理下に置くのは、レビュアーがPRのdiffで見られるようにするため**である（issue #17 の
受け入れ条件）。「AIが自己申告した内容」そのものが差分としてレビューの俎上に載る。

**pushごとに別ファイルにするのは、ブランチをまたいでコンフリクトさせないため**である。
ファイル名にブランチのスラッグと連番を持たせるため、別ブランチが同じ名前のファイルを作ることが
無い（DDRの連番がブランチ間で必ず衝突していた問題と同型で、そちらは issue #133 で解決した）。

## 仕様

### 構成要素

| ファイル | 役割 |
|---|---|
| `.claude/scripts/src/push-checklist.sh` | 生成（`new`）・記録（`check` / `skip`）・検証（`verify`）・コミット忘れ検知（`stale`）・パス解決（`path`）の本体 |
| `.claude/hooks/block-unchecked-push.sh` | PreToolUse。`verify` が検証失敗を返したら `exit 2` でブロックする。`stale`（コミット忘れ）でも `exit 2` |
| `.claude/hooks/post-push-next-checklist.sh` | PostToolUse。次回分のチェックリストを生成する |

いずれも `.claude/settings.json` の `hooks` へ登録済みである（PreToolUse は
`matcher: "Bash|PowerShell"`、PostToolUse は `if: "Bash(git push*)"` /
`if: "PowerShell(git push*)"`）。

### ファイルの形式と置き場所

`worklogDir`（`.mrworkflow.json`。本リポジトリでは `wip/worklogs`）配下へ、
次の名前で置く。

```
<YYYYMMDD>_<ブランチのスラッグ>_push<N>_checklist.tsv
```

- ブランチのスラッグは `[^a-zA-Z0-9_-]` を `_` へ置換したもの（`post-push-compact-prompt.sh`
  と同じ変換だが、hookから間接的に呼ばれる経路にあるため `sed` ではなくbash組み込みで行う）。
- `<N>` は、**作業ツリーとHEADの最大値のうち大きいほうに 1 を足した値**である。片方だけを
  見ると、コミット済みのものを見落として番号が巻き戻る。

中身はタブ区切りで、1行目が生成元のコミットSHA、2行目がヘッダ、3行目以降が項目である。

```
# generated-for: <生成時のHEADのSHA>
# id	項目	状態	実施ログ
worklog	worklogを作成し、このpushまでの試行錯誤を追記した	pending
handoff	HANDOFF.md の進捗表・ヘッダを更新した（commitより前・同じcommitに含めた）	pending
frontmatter-index	frontmatterを変更した場合、index.jsonl を最新化した	pending
plan-report-sync	wip/plans/ wip/reports/ の md と html を同期した	pending
commit-skill	commit スキル（create-commit.sh）経由でコミットした	pending
```

**全行が4フィールド固定である。** `pending` 行も4列目（空文字列）を持つため、行末はタブで
終わる。この不変条件は `verify` の検査対象でもある。

> **`IFS=$'\t' read -r -a` でこのTSVを分割してはいけない。** タブはIFS空白文字として扱われる
> ため、連続タブが畳まれ**行末タブが捨てられる**。4フィールド固定という前提が壊れ、`verify` が
> 自分の生成物を必ず落とす形になる（issue #17 の実装中に実際に踏んだ）。本体は
> bash組み込みだけの `split_tsv_line` で分割している。同じ罠は
> `.claude/rules/shell-script-style.md` にも記載がある。

項目の文言のうち `{plansDir}` / `{reportsDir}` はプレースホルダで、`.mrworkflow.json` の
実際の設定値で埋められる。**ディレクトリ名を決め打ちしない**——同じスクリプトが設定を読んで
いるのに文言だけ本リポジトリ固有の `wip/plans/` を埋め込むと、配布先で存在しないパスを案内
することになる。

### サブコマンドと終了コード

| サブコマンド | 動作 | 終了コード |
|---|---|---|
| `path` | 最新チェックリストのパスをstdoutへ | 0 / 無ければ 1 |
| `new` | 次回分を生成する。生成条件を満たさなければ何もしない | 常に 0 |
| `check <id> <ログ>` | その行を `done` にし4列目へログを書く | 0 / 1 |
| `skip <id> <理由>` | その行を `skip` にし4列目へ理由を書く | 0 / 1 |
| `verify` | **HEAD断面**を検証する | 0=通す / 1=検証失敗 / 3=HEADに対象なし |
| `stale` | コミット忘れの検知 | 0=あり / 1=なし |

**本スクリプトは `exit 2` を返さない。** `exit 2` は Claude Code のhook契約であり、
スクリプト単体の終了コードとしては使わない。hook側が 1 を受けて 2 へ翻訳する。

**`verify` が3値なのは、hook側の3分岐（ブロックする／通す／対象が無いので判断しない）を
2値では表現できないためである。**

### 作業ツリーとHEADの非対称

**`check` / `skip` は作業ツリーを書き換え、`verify` は HEAD にコミット済みの断面を読む。**
この非対称は意図的で、「作業ツリーだけ埋めてpushする」ことを防ぐためである。

結果として、**チェックリストを埋めただけではpushは通らない。** 埋めたうえで、その変更を
**同じコミットへ含める**必要がある。

### 生成の条件（`new`）

PostToolUse hook が push の後に `new` を呼ぶ。次の**3条件をすべて満たすときだけ**生成する。

| # | 条件 | なぜ要るか |
|---|---|---|
| 1 | HEADが公開済み（`git branch --remotes --contains HEAD` が非空） | pushが実際に成功したときだけ次回分を作る。**`HEAD == @{upstream}` は使わない**——両方向へ誤ることを一時リポジトリでの実測により確認した |
| 2 | そのHEAD SHAを `# generated-for:` に持つチェックリストが1本も無い | 冪等性。同じpushで2本作らない |
| 3 | HEADにタスク成果物（`plansDir` / `worklogDir` / `reportsDir` 配下のファイル。`TEMPLATE.md` と `REVIEW-POINTS.md` / `REVIEW-POINTS.local.md` を除く）が残っている | flow-id 5-5 の片付け直後の 5-6 のpushで再生成しないため |

### ブロックの条件（PreToolUse）

hook は「pushかどうか」を判定し、そうであれば `verify` と `stale` を順に見る。

| 判定 | 動作 |
|---|---|
| `verify` = 1（未完了の項目がある） | **exit 2**。未完了の項目名と、`check` / `skip` の使い方、ルールファイルのパスを stderr へ出す |
| `verify` = 0 または 3 で、`stale` = 0（作業ツリーの最大N > HEADの最大N） | **exit 2**。チェックリストがコミットされていないことと、回復手順を出す |
| それ以外 | exit 0（通す） |

**`stale` を別に見るのは、`verify` だけでは「新しく生成された分をコミットし忘れた」場合を
拾えないため**である。チェックリストは flow-id 5-5 まで蓄積するため、`verify` は HEAD に残る
古い（全 done の）チェックリストを見て 0 を返してしまう。

> **`stale` は当初 exit 1（非ブロックの警告）だった。** しかし本機構の動機そのもの——「必要な
> 更新をcommitへ含め忘れ、その分だけが未コミットで残る」——に当たるのがこの経路であり、
> **機構が防ぎたい失敗が唯一ブロックされない経路**になっていた。加えて exit 1 の stderr が
> ユーザーへ届くかは未確認である（下記「未決定事項・懸念点」）。ブロックへ倒しても回復手段は
> 「チェックリストをcommitへ含める」だけで、その `create-commit.sh` の呼び出しは push を
> 含まないため止まらない。

**ブロックメッセージは、未完了の項目名に加えてルールファイルのパス**
（`.claude/skills/commit/SKILL.md` / `.claude/docs/spec/push-checklist.md`）**を必ず含める**
（issue #17 の受け入れ条件）。

### push検知（自前で書かない）

判定は `.claude/hooks/lib/CommandPosition.sh` の `command_invokes_git_subcommand` へ委譲する
（issue #17 のコメントによる指示。仕様: `.claude/docs/spec/command-position.md`）。
ヒアドキュメント本文・クォート内・コメントの地の文では発火しない。

本hookには `if` フィールドが無く、Bash/PowerShellの全呼び出しで起動するため、判定本体
（jq呼び出しを含む）へ入る前に**bash組み込みだけの前置フィルタ**で足切りする
（`.claude/rules/shell-script-style.md`「hookの前置フィルタ」）。関数 `raw_hints_at_git_push`
の**本文は既存のpush系hook 2本と一字一句同じ**で、同一性は `test_sync_gemini_assets.sh` の
T11 が機械的に固定している。

#### 縮退時のフォールバックに前置フィルタを流用しない

`CommandPosition.sh` を使えない場合（bash 4.3未満・配布漏れ・構文エラー）のフォールバックには、
**前置フィルタではなく専用の `command_hints_at_git_push_degraded` を使う。**

前置フィルタは「`push` という語がどこかに現れるか」しか見ない超集合であり、判定本体として
使うと過剰検知がそのまま `exit 2` になる。**回復のために叩く `push-checklist.sh check` は
パスに `push` を含むため必ずブロックされ、縮退環境では自力で回復できなくなる。**
「縮退時はブロック側へ倒す」方針は妥当だが、倒した先が回復不能では方針として成立しない。

`command_hints_at_git_push_degraded` は実コマンド文字列を空白で分割し、
(1) basename が `git` のトークンがあり、(2) その後ろに `push` トークンがある、の両方が
揃ったときだけブロックする。`git` トークンをAND条件にしたことで、回復コマンドは構造的に
ブロックされない。精密判定の超集合ではなくなる（`eval "git push"` 等を取りこぼす）が、
縮退時は元々 best-effort であり、**取りこぼしの害（1回のpushが素通りする）より回復不能の害が
大きい**。

> **前置フィルタとブロック判定は、超集合であるべき向きが逆である。** 前置フィルタでは過剰検知が
> 「jq起動1回の無駄」で済むため緩める側へ倒すが、ブロック判定では過剰検知が「実行の停止」に
> なる。同じ関数を両方へ使い回さないこと。

### 逃げ道（`skip`）

**全項目に対して `skip <id> <理由>` が提供されている。** `verify` の合格条件は
「全行の状態が `done` **または** `skip`」であり、理由は4列目へ書かれてGit管理下のdiffに残る。

したがって**詰まったときは `skip` で解く**。`--tags` / `--delete` のような「現在のブランチを
送らないpush」も一律でブロックされるが、これも `skip` で解く（下記「設定項目」）。

**環境変数等による無効化スイッチは用意しない。** `skip` で足りるものを二重に作ることに
なるうえ、`block-direct-git-commit.sh` が無効化スイッチを持っていないのとも揃わない。
`skip` と環境変数スイッチの違いは、**迂回した事実がレビュアーに見えるかどうか**である。

## 影響範囲

### 新規に追加したもの

| パス | 種別 |
|---|---|
| `.claude/scripts/src/push-checklist.sh` | スクリプト本体 |
| `.claude/hooks/block-unchecked-push.sh` | PreToolUse hook |
| `.claude/hooks/post-push-next-checklist.sh` | PostToolUse hook |
| `.claude/scripts/test/test_push_checklist.sh` | 単体テスト |
| `.claude/scripts/test/test_block_unchecked_push.sh` | 単体テスト |
| `.claude/scripts/test/test_post_push_next_checklist.sh` | 単体テスト |

### 既存への変更

| パス | 変更 |
|---|---|
| `.claude/settings.json` | PreToolUse へ1本、PostToolUse へ2本（Bash / PowerShell）を登録 |
| `.claude/scripts/test/test_sync_gemini_assets.sh` | T11（前置フィルタの同一性）の対象へ新規hookを追加、T12 を追随 |

**既存のpush系hook 2本（`post-push-usage-report.sh` / `post-push-compact-prompt.sh`）の
ロジックは1バイトも変更していない**（issue #17 の受け入れ条件「責務を既存2本と分離する」）。
あちらは push の**後**に対応工数を集計し `/compact` を促す PostToolUse であり、こちらは
push の**前**に止める PreToolUse である。

### チェックリスト自体のライフサイクル

`wip/worklogs/` 配下に置かれるため、**worklogと同じ寿命**である。すなわち**タスク（issue／
ブランチ）単位で、flow-id 5-5 でまとめて削除される**（`cleanup-task.sh`）。squash merge に
より main には残らない。ライフサイクル表は `.claude/rules/docs-workflow.md` が正。

## 設定項目

本機構に固有の設定ファイルは無い。参照するのは `.mrworkflow.json` の既存キーだけである。

| キー | 用途 | 既定値 |
|---|---|---|
| `plansDir` | 項目文言の `{plansDir}` の置換、生成条件3の判定 | `plans` |
| `worklogDir` | チェックリストの置き場所、生成条件3の判定 | `worklog` |
| `reportsDir` | 項目文言の `{reportsDir}` の置換、生成条件3の判定 | `reports` |

> **`get_workflow_config` はキー単位の既定値補完をしない**（`.mrworkflow.json` が存在すれば
> 中身をそのまま返すだけ）。既定値は `jq` の `//` 演算子で呼び出し側が当てている。

### チェック項目を変えたい場合

項目は `push-checklist.sh` の `CHECKLIST_IDS` / `CHECKLIST_ITEM_TEMPLATES` が持つ。
**外部定義ファイルにはしていない**——項目はフロー定義そのものであり、`.claude/` は配布層
`core`（本家所有）だからである。配布先が項目を変えたい場合は上流へ提案する。

### hookを止めたい場合

配布先で本機構が合わない場合、**第一手は `skip`**（項目ごとに理由を残して迂回する）、
**次の手は `.claude/settings.json` から本hookの登録を外すこと**である。

これが必要になりうる代表例が **`git push --tags` / `git push origin --delete <branch>` を
日常的に行う配布先**である。本機構はpushの**引数を解釈しない**ため、現在のブランチを送らない
pushもチェックリスト未完了なら一律でブロックする。

> **引数を解釈しない判断の根拠は、誤りの向きの非対称である。** refspec・`--all` / `--mirror`・
> `push.default` まで解釈しないと正しく判定できず、判定の面積がpush検知本体より大きくなる。
> そして判定が誤ると**通してはいけないpushを通す**（ガードが黙って効かなくなる）。一律ブロック
> の誤りは**通すべきpushを止める**だけで、その場で見えるうえ必ず解ける。却下案の詳細は
> DDR `i0017-01` を参照。

**このコストは本リポジトリの現時点のフローでは0だが（`--tags` も `--delete` も行わない）、
本機構は配布層 `core` として配られるため、配布先では0とは限らない。**

## 未決定事項・懸念点

### 「作業ツリーが常にクリーンかつリモートと一致」と構造的に両立しない

pushのたびに PostToolUse hook が次回分を生成するため、**pushの直後には必ず未コミットの
チェックリストが1本ある**。さらにそれを `pending` のままコミットすると、今度は `verify` の
対象がそのファイルになるので**埋めるまでpushできない**。

つまり「作業ツリーがクリーンかつリモートと一致」は、**pushの直後の一瞬しか成立しない**。
運用としてはこれで正しい（次のpushの作業をしながら埋める）が、**「未コミット・未pushを常に
ゼロに保つ」種の別の仕組みとは両立しない。**

**実害は無いが、知らずに両方を満たそうとすると「中身が確定していないチェックリストを埋めたく
なる」——すなわち実施していないことを `done` と書く動機になる。** 本機構は自己申告に立って
いるため、これが最も避けたい壊れ方である。**両立させようとせず、次のpushで埋めること。**

### 誤ブロックの再現条件が1件、特定できていない

issue #17 の作業中、長いコマンドが2回 `stale` のメッセージで `exit 2` された。原因の切り分けは
できていない。

- `command_invokes_git_subcommand` 単体（ヒアドキュメント本文・シングル／ダブル／ANSI-C
  クォート内・コメント行・HTMLタグ内・python三重引用符の8ケース）では**いずれも検知しない**。
- hookを実プロセスとして起動した6ケースでも、`exit 2` になるのは**実際のpushだけ**だった。
- 「ANSI-Cクォート内のエスケープ済みシングルクォートがトークナイザ上でクォートを閉じる」と
  いう仮説を3ケースで試したが再現しなかった。

**そもそも判定の誤りだったのか、`stale` の条件が当時の状態で真だった（＝正しいブロックだった）
のかも切り分けられていない。** 再現条件が不明なため実装は変更していない。再発した場合は、
`stale` のメッセージが出す「作業ツリー push<N> > HEAD push<M>」の実際の値を先に確かめること。

### 確かめられていないこと

いずれも「確かめていないので当てにしない」側へ倒した設計になっており、実装をブロックしない。

| 項目 | 状況 |
|---|---|
| PreToolUse の `exit 1` の stderr がユーザーへ届くか | 未確認。このため `stale` を exit 2 へ倒した |
| `tool_response` の構造 | 未確認。PostToolUse では使わず、`git branch --remotes --contains HEAD` で実際の状態を見る |
| 複数hookの `additionalContext` の合成 | 未確認 |
| `.claude/settings.json` の `if` フィルタの照合規則（前方一致か部分一致か） | issue #47 から未解明。本機構の PreToolUse は `if` を持たないため影響しない |
| git bash実機（Windows）での挙動・性能 | 未検証。本リポジトリのリモート実行環境（Linux）でのみ確認している |

## 変更履歴

### issue #17（新規作成）

push前チェックリスト機構を新設した。スクリプト本体1本・hook2本・単体テスト3本を追加し、
`.claude/settings.json` へ登録した。既存のpush系hook 2本のロジックは変更していない。
