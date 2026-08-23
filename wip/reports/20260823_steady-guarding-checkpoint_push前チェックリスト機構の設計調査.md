---
title: push前チェックリスト機構の設計調査（issue #17）
type: report
description: issue #17 のpush前チェックリスト機構について、置き場所・命名・項目定義・hookが読む断面・誤ブロック条件・既存hookとの競合・ライフサイクル・テストの型の8点を確定させた調査結果。
tags: [issue-mr-flow, hook, push, checklist]
keywords: [push前チェックリスト, PreToolUse, PostToolUse, CommandPosition, TSV, cleanup-task, 誤ブロック, upstream, 前置フィルタ, 超集合]
---

# push前チェックリスト機構の設計調査（issue #17）

## 重点レビュー依頼

**◆特に見てほしい（判断に困っている）**

1. [Q5](#q5-誤ブロックしない条件) — **縮退時にブロック側と素通り側のどちらへ倒すか**で迷った。
   `block-direct-git-commit.sh` はブロック側だが、pushは止まると作業が進まない。
   「チェックリストが存在し未完了項目がある」ときだけブロックする設計で緩和されるという判断でよいか。
2. [Q7](#q7-ライフサイクル) — issue本文は **flow-id 4-6 で削除**を求めているが、そうすると
   4-7 以降のpushでチェックリストが消える。**flow-id 5-5（`cleanup-task.sh`）へ寄せる**と
   判断したが、issue本文からの意図的な逸脱なので確認してほしい。

**◇承認が欲しい（方針は決めたので確認してほしい）**

3. [Q1](#q1-チェックリストの置き場所と命名) — 命名を
   `<worklogDir>/<YYYYMMDD>_<ブランチslug>_push<N>_checklist.tsv` と決めた。
   issue本文の「全体計画名_個別計画名」ではなく**ブランチslug**を使い、置き場所は
   `.mrworkflow.json` から解決する。
4. [Q2](#q2-項目何をチェックさせるかの定義) — 項目は**5件の固定リスト**とし、スクリプト内の
   定数として持つ（外部定義ファイルにしない）と決めた。
5. [Q4](#q4-pretooluse-hookが読む断面) — hookは**HEADにコミット済みの断面**を読み、
   push対象refは読み取らず常に現在のブランチを見ると決めた。
6. [Q6](#q6-posttooluse-hookの次回分生成と既存hookとの競合) — push成否（正確には
   **HEADが公開済みか**）の判定に、`tool_response` でも `HEAD == @{upstream}` でもなく
   **`git branch --remotes --contains HEAD`** を使うと決めた。当初案の `@{upstream}` は
   敵対的レビュー2回目の指摘を受けて実測し、**両方向に誤る**ことを確認して撤回した。

**・細かいレビューは不要（ほぼ確実）**

7. [Q3](#q3-チェック済みの表現とtsvの列構成) — 4列TSV。実装時に確定する細部のみ。
8. [Q8](#q8-単体テストの型) — 既存 `test_block_direct_git_commit.sh` の2層構成をそのまま踏襲する。

## サマリ（結論の一覧）

| # | 結論 | 性質 | 根拠 |
|---|---|---|---|
| Q1 | 置き場所は `.mrworkflow.json` の `worklogDir` から解決、命名は `<YYYYMMDD>_<ブランチslug>_push<N>_checklist.tsv` | ◎良 | 実装の確認＋実行 |
| Q2 | 項目は5件の固定リスト。スクリプト内の定数として持つ | ◎良 | 実装の確認 |
| Q3 | 4列TSV（`id` / `項目` / `状態` / `実施ログ`）。状態は `pending` / `done` / `skip` | ◎良 | 設計判断 |
| Q4 | hookは**HEADにコミット済みの断面**を読む（作業ツリーではない）。push対象refは読み取らない | ◎良 | 要件からの導出＋実装の確認 |
| Q5 | ブロックは「チェックリストがHEADに存在し、かつ `pending` が残る」ときだけ。縮退時はブロック側へ倒す。フロー対象なのに未生成なら exit 1 で警告する | △注意 | 実装の確認 |
| Q6 | HEADが公開済みかを `git branch --remotes --contains HEAD` で判定する。`tool_response` は既存hookも参照しておらず当てにしない。当初案の `HEAD == @{upstream}` は実測により撤回 | ◎良 | 実測（一時リポジトリで5ケース） |
| Q7 | 削除は flow-id 5-5（`cleanup-task.sh`）。**追加実装は不要**で自動的に対象へ入る | ◎良 | 実測（`--dry-run`） |
| Q8 | 既存 `test_block_direct_git_commit.sh` の2層構成（純粋関数の直接テスト＋スタブ `jq` の結合テスト）を踏襲 | ◎良 | 実行（`passed=27 failures=0`） |

## 確かめられなかったこと

この結果が言っていないこと:

- **`tool_response` に終了コードが含まれるか**を確かめていない（[Q6](#q6-posttooluse-hookの次回分生成と既存hookとの競合)）。
  リポジトリ内に `tool_response` を参照している箇所が1つも無く、実際のhook起動を再現できていない。
  そのため「含まれない」ではなく「**確かめていないので当てにしない**」という設計にしている。
- **複数hookが同時に `additionalContext` を返したときの合成のされ方**を確かめていない
  （[Q6](#q6-posttooluse-hookの次回分生成と既存hookとの競合)）。既存2本が同時に返す構成で運用
  されている事実から「両方届く」と推測しているが、実際の合成結果は観測していない。
- **`.claude/settings.json` の `if` フィルタの照合規則**（前方一致か部分一致か）。issue #47 から
  未解明のままであり、本調査でも切り分けていない。**あわせて「PreToolUseで `if` を使えるか」も
  確かめていない**（本機構は `block-direct-git-commit.sh` と同じく、判定が単純な文字列一致に
  収まらないため `if` を使わない設計であり、可否が判明しても結論は変わらない）。
- **PreToolUse hookが exit code 1 を返したときに、stderr が実際にユーザーへ表示されるか**
  （[Q5](#q5-誤ブロックしない条件)）。規約上はそうなるはずだが、本セッションでhookの実起動を
  再現できていない。**届かなくても機構が壊れない設計**にしてある。
- **git bash（Windows）実機での挙動・性能**。本セッションはLinuxであり、fork単価が桁違いの
  環境の計測値を持ち込めない（`.claude/rules/shell-script-style.md`「起動回数がゼロであることを
  計測で確かめるとき」）。
- **Gemini CLI経路での動作**。`.gemini/` は flow-id 5-3 の変換同期で追随させるが、実機確認は
  行っていない。

## 実施条件（調べた対象・環境）

- 実行環境: Claude Code on the web のリモート実行環境（Linux 6.18.44）。`gh`/`glab` CLIは無い。
- 対象: 本リポジトリの `main` を取り込んだ時点のブランチ `claude/hook-implementation-17-vjhppj`
  （`f58bfdd`）。
- 実施日: 2026-08-23。
- 使ったコマンド:
  - `grep -n` / `sed -n` による実装の読み取り、`jq` による `.claude/settings.json` の走査。
  - `bash .claude/scripts/test/test_block_direct_git_commit.sh`（既存テストの型と実行結果の確認）。
  - `bash .claude/scripts/src/cleanup-task.sh --dry-run --skip-index`（[Q7](#q7-ライフサイクル)。
    ダミーの `.tsv` が削除対象へ入ることの確認）。
  - `bash .claude/scripts/src/extract-frontmatter.sh .`（同上。`.tsv` が `index.jsonl` に
    載らないことの確認）。
  - 使い捨ての一時リポジトリ上で走らせた検証スクリプト3本（[Q6](#q6-posttooluse-hookの次回分生成と既存hookとの競合)）。
    scratchpad に置き `bash <path>` で実行した（コマンド位置に `git push` が立つため、
    その場のコマンド文字列としては書けない）。**このリポジトリではなく一時リポジトリを
    対象にしている**ので、本ブランチの状態は変えていない。

## 実施した内容と結果

### Q1. チェックリストの置き場所と命名

**答え**: `wip/worklogs/<YYYYMMDD>_<ブランチslug>_push<N>_checklist.tsv`。

- **置き場所は `wip/worklogs/`**（既定値。解決方法は次項）。issue本文の `worklog/` は
  **issue #165** で `wip/worklogs/` へ改名されている（根拠: `.claude/docs/spec/cleanup-task.md`
  「issue #165」節。`#178` はその squash merge の PR番号であってissueではない）。
- **`<ブランチslug>` はブランチ名の `[^a-zA-Z0-9_-]` を `_` へ置換したもの。** この置換規則は
  `post-push-compact-prompt.sh:330` が `wip/state/review-links/<branch>.txt` の組み立てに
  使っている既存の慣習と同じである。

  ```
  $ grep -n 'safe_branch' .claude/hooks/post-push-compact-prompt.sh
  330:  safe_branch="$(printf '%s' "$branch" | sed -E 's/[^a-zA-Z0-9_-]/_/g')"
  ```

  ただし本機構はhook内で使うため、forkする `sed` ではなくbash組み込みだけで同じ変換を行う
  （`.claude/rules/shell-script-style.md`「外部プロセス起動のコスト」）。
- **置き場所は `.mrworkflow.json` の `worklogDir` から解決する**（ハードコードしない）。
  `cleanup-task.sh` が issue #165 で同じ形へ変わっており（`.claude/docs/spec/cleanup-task.md`
  「issue #165」節）、揃えないと**配布先が `worklogDir` を変えたときにチェックリストだけが
  片付かずに残る**。**解決は生成・検証スクリプト側が行い、hookはそこへ委譲する**
  （設定の読み方を2箇所に持たない）。
  - **フォールバック値は `wip/worklogs` ではなく `worklog` である**（flow-id 3-1 の計画作成中に
    実装を読み直して判明。当初は `wip/worklogs` と書いていたが誤りだった）。`cleanup-task.sh` は
    `.worklogDir // "worklog"`（`cleanup-task.sh:232`）、`Provider.sh` の `get_workflow_config` も
    設定ファイルが無いときは `"worklogDir": "worklog"` を返す（`Provider.sh:66`）。いずれも
    **issue #165 より前の値**のまま据え置かれている。
  - **ここを `wip/worklogs` にすると、まさにこの節が避けようとした食い違いを自分で作る。**
    `.mrworkflow.json` が無い配布先で、生成側が `wip/worklogs/` へ置き、削除側（`cleanup-task.sh`）が
    `worklog/` を見る、という形になる。**フォールバックは `cleanup-task.sh` に合わせて `worklog` とし、
    そもそも `get_workflow_config` を呼んで同じ既定値を共有する**（自前で `// "..."` を書かない）。
- **`<N>` は、そのブランチの既存チェックリストの最大値 + 1。** `HANDOFF.md` の `- push回数:` は
  人間・AIが手で書き換えられる値であり、チェックリストの実体と食い違いうるので使わない。
  **採用理由はこの1点だけである。**
  - **`<N>` の採り方自体は冪等ではない**（敵対的レビュー2回目で指摘）。生成器がファイルを作った
    時点で「最大値」が変わるため、2回目の起動は N+2 を作る。むしろ却下した `HANDOFF.md` 案の
    ほうが、生成器がHANDOFF.mdを書き換えない以上この尺度では冪等である。当初「ファイル名から
    導けば生成が冪等になる」と書いていたのは**誤り**だった。
  - **冪等性は、生成側の条件2（同じHEAD SHAを記録したチェックリストが既にあれば作らない）が
    保証する**（[Q6](#q6-posttooluse-hookの次回分生成と既存hookとの競合)）。`<N>` の採り方は
    冪等性と無関係である。

**「ブランチ間でconflictしない」の根拠**: ファイル名に**ブランチslugを含める**こと自体が保証に
なる。issue本文が挙げていた「全体計画名_個別計画名」は、2つのブランチが同じ種別
（例: `【調査】`）で同じ日に作業すると**同名になりうる**ため、それだけでは保証にならない。

**採らなかった案**:

| 案 | 却下理由 |
|---|---|
| `<全体計画名>_<個別計画名>` を含める（issue本文の案） | 個別計画名を機械的に一意に取り出せない（`wip/plans/【*.md` が0件・2件以上になりうる）。ブランチ間の非衝突も保証できない |
| `<N>` を `HANDOFF.md` の `- push回数:` から取る | 手で書き換えられる値であり、チェックリストの実体と食い違う。生成が冪等でなくなる |
| `usage/state/push-index.jsonl` から取る | 対応工数レポートのローカル状態であり `.gitignore` 対象。配布先・クローン直後に存在しない |
| `.gitignore` 対象の `wip/state/` へ置く | 受け入れ条件「レビュアーがPRの差分から確認できる」を満たせない |
| 置き場所をハードコードする | 配布先が `worklogDir` を変えると、`cleanup-task.sh` の削除対象から外れてチェックリストだけが残る |

### Q2. 項目（何をチェックさせるか）の定義

**答え**: **5件の固定リスト**を、生成スクリプト内の定数として持つ。

| id | 項目 |
|---|---|
| `worklog` | worklogを作成し、このpushまでの試行錯誤を追記した |
| `handoff` | `HANDOFF.md` の進捗表・ヘッダを更新した（commitより前・同じcommitに含めた） |
| `frontmatter-index` | frontmatterを変更した場合、`index.jsonl` を最新化した |
| `plan-report-sync` | `wip/plans/` `wip/reports/` の md と html を同期した |
| `commit-skill` | `commit` スキル（`create-commit.sh`）経由でコミットした |

**「常に実施すべき」と言える粒度にするための工夫**: 3・4は条件付き（frontmatterを変えていない
push、計画・レポートを触っていないpushがある）。これを「項目を可変にする」ことで解こうとすると
flow-idの判定がhookへ入り込んで壊れやすくなるため、**項目は固定のまま、状態に `skip`（理由を
実施ログへ書く）を用意して吸収する**（[Q3](#q3-チェック済みの表現とtsvの列構成)）。

**定義の置き場所をスクリプト内の定数にした理由**: 項目は**フロー定義そのもの**であり、
`.claude/` は配布層 `core`（本家所有。`.claude/dist-layers.json`）である。外部定義ファイルに
すると、配布先が項目を書き換えたとき本家の更新で壊れるか、`merge` 層の新設が要る。

**採らなかった案**:

| 案 | 却下理由 |
|---|---|
| flow-idに応じて項目を可変にする | hookが現在のflow-idを知る必要があり、`HANDOFF.md` の解析に依存する。壊れやすさに見合う利得が無い |
| 外部定義ファイル（`.claude/push-checklist-items.tsv` 等）を置く | 配布層の設計（`core`）と噛み合わない。`merge` 層の新設が要る |
| 項目を「条件に当てはまるときだけ生成する」 | 生成時点では条件（frontmatterを変えるか）が未確定である |

### Q3. チェック済みの表現とTSVの列構成

**答え**: ヘッダ行（`#` 始まり）＋ 4列。

```
# generated-for: 2fcb4e40d514e660c5357f5bbd932ab2e98ba8f8
# id	項目	状態	実施ログ
worklog	worklogを作成し、このpushまでの試行錯誤を追記した	pending
handoff	HANDOFF.md の進捗表・ヘッダを更新した（commitより前・同じcommitに含めた）	done	3-6完了として mark-done 3-6 を実行
```

**上の `pending` 行も、実際には4フィールド目（空文字列）を持つ**（行末がタブで終わる）。
markdownのコードブロックでは見えないが、**列数は常に4で固定する**（下記）。

- **列数は常に4で固定する**（敵対的レビュー2回目で指摘）。`pending` 行も4列目を空文字列で必ず
  出す。可変にすると、`IFS=$'\t' read -r id item state log` で読む生成器と、
  `awk -F'\t' 'NF!=4'` のような妥当性検査を入れる検証器とで前提が食い違う。
  **検証器はフィールド数が4でない行をブロック対象とする**
  （[Q5](#q5-誤ブロックしない条件)）。
- **1行目に `# generated-for: <HEAD SHA>` を置く。** どの断面に対して生成されたかを記録し、
  [Q6](#q6-posttooluse-hookの次回分生成と既存hookとの競合) の生成条件2（冪等性）が参照する。
- **状態は `pending` / `done` / `skip` の3値。** **3値以外の値もブロック対象**である
  （`Done` `PENDING` `pendign` のようなタイプミスが素通りしないようにするため。
  [Q5](#q5-誤ブロックしない条件)）。
- **項目の文言はQ2の定数と一字一句同じものを書き出す**（上のサンプルもQ2の表と一致させてある）。
- **`done` / `skip` は実施ログ（4列目）が非空であることを要求する。** 空の `done` を許すと
  「チェックだけ付ける」が最短経路になるため、少なくとも**何をしたかを書く**コストは課す。
  **この要求は検証器（`verify`）側でも強制する**——`check` サブコマンドを通さずEdit/Writeで
  直接TSVを書けば `check` の検証点を通らないため、生成器側だけの要求では意味を持たない
  （敵対的レビュー2回目で指摘）。
- **エスケープは行わず、書き込み時にタブ・改行を半角スペースへ潰す。** TSVのエスケープ規則を
  持ち込むと `git diff` での読みやすさ（受け入れ条件）が落ちる。実施ログは1行の自由記述で足りる。
- **1行の長さは短く保つ。** 列順を `id` → `項目` → `状態` → `実施ログ` にしているのは、
  `git diff` の1行を左から読んだときに**どの項目がどう変わったか**が先に分かるようにするため。

**採らなかった案**:

| 案 | 却下理由 |
|---|---|
| 2値（`done` / `pending`）にする | 条件付きの項目（frontmatterを変えていないpush）を表現できず、嘘の `done` を強いる |
| markdownのチェックボックス（`- [ ]`）にする | 拡張子が `.md` になると `extract-frontmatter.sh` の走査対象に入る（下記の実行結果） |
| JSONにする | `git diff` で1項目の変更が複数行に散る。hookでの読み取りに `jq`（fork）が要る |

### Q4. PreToolUse hookが読む断面

**答え**: **HEADにコミット済みの断面**（`git show HEAD:<path>`）を読む。作業ツリーは読まない。

issue #17 の期待する動作2は「commit前に各項目を実施したことをチェックリストへ記録し、
**チェックリスト自体をそのcommitに含める**」と定めている。作業ツリーを読むと、
チェック済みだがコミットしていないチェックリストが**pushされる内容に含まれないまま**通ってしまい、
受け入れ条件「レビュアーがPRの差分からチェックリストの実施内容を確認できる」が崩れる。

HEADを読めば、この2つが同時に保証される。

- チェックが付いている ＝ その内容がコミットに入っている。
- pushされる内容とhookが見たものが一致する。

**HEADにチェックリストが無い場合はブロックしない**（[Q5](#q5-誤ブロックしない条件)）。

**どのref（どのブランチ）に対するpushかは読み取らず、常に現在のブランチのチェックリストを見る。**
`command_invokes_git_subcommand` は0/1しか返さず、refspecを露出しないためである
（[Q5](#q5-誤ブロックしない条件) の `--dry-run` と同じ制約）。この割り切りの帰結は次のとおり。

| pushの形 | 見るチェックリスト | 妥当か |
|---|---|---|
| `git push` / `git push origin <現在のブランチ>` | 現在のブランチ | ◎ 一致する |
| `git push origin HEAD:other` | 現在のブランチ | ◎ 内容は現在のHEADなので一致する |
| `git push origin main`（別ブランチを名指し） | 現在のブランチ | △ 過剰にブロックしうる |
| `git push --all` / 複数refspec | 現在のブランチ | △ 同上 |
| `git push --tags`（タグのみ） | 現在のブランチ | △ 同上 |

いずれも**過剰ブロック側**であり、素通り側ではない。チェックリストを埋めれば通るため、
作業内容は失われない。

**採らなかった案**:

| 案 | 却下理由 |
|---|---|
| 作業ツリーを読む | チェック済み・未コミットのチェックリストで通ってしまう |
| refspecをコマンド文字列から自前で解析する | `CommandPosition.sh` は引数を露出しない。素朴な部分一致で解析すると、issue #53 がやめた「コメント・ヒアドキュメント本文への反応」を持ち込む |
| index（ステージ済み）を読む | ステージしただけではpushされない。作業ツリーと同じ穴が残る |
| 作業ツリーとHEADの両方を読み、差があれば警告 | 判定が2系統になり、どちらが正かが曖昧になる。ブロック条件は1つに保つ |

### Q5. 誤ブロックしない条件

**答え**: 判定は**否定形**で書く。「通してよい」と積極的に確認できたときだけ通し、それ以外は
ブロックする。

1. コマンドが `git push` を**コマンド位置で**実行する
   （`command_invokes_git_subcommand "$command" push`）。**しなければ何もしない。**
2. カレントブランチのチェックリストが**HEADに存在しない**なら、ブロックしない（下記の警告条件へ）。
3. 存在する場合、**次をすべて満たすときだけ通す**。1つでも欠ければ **exit 2 でブロックする**。
   - 全データ行が**ちょうど4フィールド**である（[Q3](#q3-チェック済みの表現とtsvの列構成)）。
   - `id` 列の集合が、スクリプトが持つ**5件の定数と過不足なく一致**する。
   - 全行の状態が `done` または `skip` である（`pending` はもちろん、`Done` `PENDING` `pendign` の
     ような**3値以外の値もブロック**する）。
   - `done` / `skip` の行の**実施ログ（4列目）が空でない**。

**なぜ肯定形（「`pending` が1件以上ならブロック」）にしないか**（敵対的レビュー2回目で指摘）:
肯定形だと、チェックリスト本体の読み取りが縮退したときだけ**素通り側**へ倒れる。
状態列のタイプミス・空ファイル・列ずれ・項目行の削除は、いずれも「`pending` に一致しない」ため
通ってしまう。**「縮退時はブロック側へ倒す」という本節の方針と正反対**であり、しかも症状は
「ブロックされない＝正常に見える」ので気づけない。

**複数のチェックリストがHEADに存在する場合は、`<N>` が最大の1本だけを見る。**
それより古いものは、そのpushを通した時点で全件 `done`/`skip` だったはずであり、再検査しても
結果が変わらないためである（[Q1](#q1-チェックリストの置き場所と命名) の生成ガードにより、
そもそも同一断面に対して2本目は作られない）。

したがって次はブロックされない。

- **チェックリスト未生成**（フロー対象外のブランチ・機構の導入直後・ブランチ初回push）。
- `git push` 以外のリモート反映手段（MCP経由のファイル作成等）。
  hookが検知できないため、**そもそも守れない範囲**として仕様へ明記する。

**`git push --dry-run` は特別扱いしない（ブロックされる）。** 理由は2つある。

1. `command_invokes_git_subcommand` は**0/1しか返さず、引数リストを露出しない**
   （`.claude/hooks/lib/CommandPosition.sh:584-606`）。`--dry-run` を除外するには、
   コマンド文字列に対する別の判定を自前で書くことになる。
2. その自前判定を素朴な部分一致で書くと、**コメントやヒアドキュメント本文に `--dry-run` と
   書くだけでブロックを迂回できる**バイパスができる。issue #53 がコマンド位置判定へ寄せた
   目的（部分一致をやめる）に逆行する。

一方 `--dry-run` がブロックされる損失は「チェックリストを埋めるまで試行できない」だけで、
**作業内容は1バイトも失われない**。非対称なので、特別扱いしない側へ倒す。

**「生成したのにコミットし忘れた」ことを検出可能にする（ブロックはしない）。** 素通りさせる
だけだと、PostToolUseが生成したチェックリストを**コミットし忘れた**場合に機構が**無言で
無効化**され、しかも「ブロックされないので正常に見える」。そこで、

- チェックリストが**HEADには無い**が、
- **作業ツリーには存在する**（未追跡または未ステージ）

ときは、**exit code 1（非ブロックのエラー）＋ 標準エラーへの警告**でpushを通す。
Claude Code のhookは「0＝成功／2＝ブロック／それ以外＝非ブロックのエラー（stderrをユーザーへ
表示し、実行は継続）」という規約のため、この形なら**ブロックせずに気づかせられる**。
**この警告が実際にユーザーへ届くかは本セッションでは確かめていない**ため、届かなくても
機構が壊れない設計（通す側は変わらない）にしている。

**当初は「フロー対象のブランチ（`wip/plans/` 等にタスク成果物がある）なのにチェックリストが
無い」を条件にしていたが、2つの理由で上の形へ変えた**（敵対的レビュー2回目で指摘）。

1. **正常系で必ず出る警告になっていた。** チェックリストはPostToolUse（＝最初の成功pushの後）で
   初めて生成されるのに、`wip/plans/` の計画は flow-id 1-4/2-1 で作られ 2-2 のcommitで先に
   HEADへ入る。つまり**すべてのブランチの初回pushで条件が成立する**。正常時に毎回出る警告は
   信号として機能せず、本来検出したい「コミット忘れ」まで一緒に無視される。
2. **`wip/plans/` `wip/worklogs/` をパスとして直書きしていた。**
   [Q1](#q1-チェックリストの置き場所と命名) が「ハードコードしない」と決めた方針に反しており、
   `plansDir` / `worklogDir` を変えた配布先では判定が常に偽になって**検知が丸ごと無効**になる。

新しい条件（HEADに無く作業ツリーにある）は、**検出したい失敗そのもの**を直接見ているため
初回pushでは成立せず、パスの解決も生成・検証スクリプト側の1箇所（設定値から解決）で済む。

**縮退時（`CommandPosition.sh` が使えない／部分一致へ落ちる）はブロック側へ倒す。**
`block-direct-git-commit.sh` と同じ扱いにする。pushは「止まると作業が進まない」度合いが大きいが、
上の条件2により**チェックリストがHEADに存在するときにしか発火しない**ため、誤ブロックの
被害範囲は「チェックを埋めれば通る」に限られる。

**前置フィルタは既存の `raw_hints_at_git_push` と同型のものを持つ。**
`post-push-compact-prompt.sh:222-240` に実装があり、JSON文字列エスケープの2文字シーケンスを
まとめて除去してからブラケット式で `push` を大文字小文字非依存に探す形になっている。
**3本目として同じ実装を持たせる**（`source` で共有しない理由は、既存2本が同型の実装を
それぞれ持っている前例に従い、hookが単独で動くことを優先するため）。

**ただし、その前例が成立しているのは `test_sync_gemini_assets.sh` のT11がドリフトを禁じて
いるからであり、T11は現在2本に決め打ちされている**（敵対的レビュー2回目で指摘）。

```
$ grep -n 'for h in post-push' .claude/scripts/test/test_sync_gemini_assets.sh
323:for h in post-push-usage-report post-push-compact-prompt; do
$ grep -n 'T11: 2本の raw_hints_at_git_push が同一実装である' .claude/scripts/test/test_sync_gemini_assets.sh
339:assert_eq "T11: 2本の raw_hints_at_git_push が同一実装である" \
```

このままでは3本目を足してもT11は緑のままで、**3本目の写経がドリフトしたことを検出しない**。
前置フィルタが超集合でなくなるとhookが無言で発火しなくなるため、**T11を3本対応へ更新することを
実装単位に含める**（下記「設計への反映」）。

| 採らなかった案 | 却下理由 |
|---|---|
| 前置フィルタを `.claude/hooks/lib/` へ共有関数として切り出す | hookが `source` の成否に依存する。`block-direct-git-commit.sh` は `source` 失敗時に部分一致へ縮退する設計を持つが、**前置フィルタは判定本体より前に走る**ため、そこで落ちるとhook自体が起動しない。既存2本と非対称な設計になる |
| 3本目を足すがT11は2本のままにする | 写経方式の根拠（テストがドリフトを禁じている）が3本目にだけ効かない。**無言で超集合が壊れる**経路を作る |

### Q6. PostToolUse hookの次回分生成と既存hookとの競合

**答え**: push成否は **「HEADがいずれかのremote-trackingref（`origin/*`）に含まれるか」**
（`git branch --remotes --contains HEAD`）で判定する。`tool_response` も `@{upstream}` も使わない。

リポジトリ内に `tool_response` を参照している箇所は**1つも無い**。既存の
`post-push-usage-report.sh` / `post-push-compact-prompt.sh` も参照しておらず、
「push成功後」という前提はどちらも検証していない。

```
$ grep -rn 'tool_response' .claude/
（0件）
```

#### `HEAD == @{upstream}` を採らない理由（当初案の撤回）

**当初は `HEAD == @{upstream}` を採ると書いていたが、敵対的レビュー2回目の指摘を受けて実測し、
両方向へ誤ることを確認したため撤回した。** 一時リポジトリでの実測結果は次のとおり。

```
$ bash upstream-probe.sh   # 一時リポジトリで @{u} の意味論を測る使い捨てスクリプト
=== 何も送らない up-to-date な再push ===
  何も送っていないのに HEAD == @{u} → 『成功』と判定される（誤り）
=== upstream未設定のブランチ ===
  @{u} を解決できない（rev-parse が非0）→ set -e 配下ならhookが落ちる
=== 別ref宛てpushが成功した直後 ===
  git push origin HEAD:other は成功（終了コード 0）
  HEAD = 2de4972c / @{u} = f2dd3f1e
  不一致 → 誤って『失敗』と判定される
```

| 誤る形 | 帰結 |
|---|---|
| up-to-date な再push（何も送っていない）を「成功」と読む | 未完了チェックリストが余分に生成される |
| `git push origin HEAD:other` の**成功**を「失敗」と読む | チェックリストが生成されず、以降のpushが古い全 `done` チェックリストで**素通りし続ける**（機構の無言の無効化） |
| upstream未設定・detached HEAD で `@{u}` の解決自体が失敗 | `set -euo pipefail` 配下でhookが異常終了し、**次回分が永久に生成されない** |

#### 採用案の実測

`git branch --remotes --contains HEAD` は、上の3つの形すべてで正しく振る舞う。

```
$ bash contains-probe.sh
1. 通常push直後:              contains件数=1  → 公開済みと判定
2. commit後・push前:          contains件数=0  → 未公開と判定（正しい）
3. 別ref宛てpushの成功後:     contains件数=1  → 公開済みと判定（@{u}方式は誤判定していた）
4. upstream未設定・push前:    contains件数=0  → 未公開と判定（rev-parse @{u} と違い落ちない）
5. upstream未設定・push成功後: contains件数=1  → 公開済みと判定
```

**upstreamの設定を一切参照しないため、解決に失敗して落ちる経路が無い**（上表の3行目の問題も
同時に消える）。

#### 生成の条件（3つすべてを満たすときだけ生成する）

1. **HEADが公開済みである**（上記の `--contains` が1件以上）。
2. **そのHEAD SHAを記録したチェックリストが、まだ1本も存在しない。**
   チェックリストは1行目のヘッダコメントへ「どの断面に対して生成されたか」を記録する。
   これが**冪等性の保証**であり、up-to-date な再pushで2本目が生えることを防ぐ
   （[Q1](#q1-チェックリストの置き場所と命名) の `<N>` の採り方だけでは冪等にならない）。
3. **HEADにタスク成果物が残っている**（`plansDir` / `worklogDir` / `reportsDir` のいずれかに、
   `TEMPLATE.md`・`REVIEW-POINTS*.md` を除くファイルがある）。

条件3は **flow-id 5-5 で片付けた直後の 5-6 のpushで生成しないため**である（敵対的レビュー2回目
で指摘）。5-5 が `wip/worklogs/` を空にし、その削除を 5-6 の commit＋push で確定させるのに、
そのpushの直後に次回分を生成すると、**片付けたはずのディレクトリに未追跡ファイルが1本残ったまま
タスクが終わる**。`wip/worklogs/` は `.gitignore` 対象ではない（載るのは `/wip/state/` だけ）
ため、この残骸は次タスクの `git status` に現れ続け、`.claude/rules/git-workflow.md` が警告して
いる事故（issue #127 の `bash.exe.stackdump`）と同じ形になる。

| 採らなかった案（生成の停止条件） | 却下理由 |
|---|---|
| Draft解除済みのMRでは生成しない | hookからMRの状態を取るのに外部CLI・APIの往復が要る（`gh`/`glab` 不在の環境もある）。`--contains` と同じくローカルで完結する条件を優先した |
| 生成物を `.gitignore` に載せる | 受け入れ条件「レビュアーがPRの差分から確認できる」と衝突する |
| 停止条件を置かず、残骸は `commit` スキルの除外リストで拾う | 残骸が出ること自体は変わらない。`git status` に現れる新種の副産物は、`.claude/rules/git-workflow.md` が「見落としの機会そのものを消す」ことを求めている |

#### 既存hookとの競合

`.claude/settings.json` の `PostToolUse` には、既に同じ matcher（`Bash|PowerShell`）で4エントリが
`if: "Bash(git push*)"` / `if: "PowerShell(git push*)"` 付きで並んでいる。本機構は
**5・6番目のエントリとして末尾に足す**（既存の2本より後に走らせ、既存の出力を邪魔しない）。
`if` フィルタも既存2本と同じ2種を付ける（Gemini CLI経路では `if` が効かないため、いずれにせよ
自前判定が要る）。

**別立ての状態ファイル（`wip/state/` 等）は持たない。** 冪等性に必要な「どの断面に対して
生成したか」は、チェックリスト自身のヘッダコメントが持つ。

### Q7. ライフサイクル

**答え**: **flow-id 5-5（`cleanup-task.sh`）でまとめて削除する。追加実装は不要。**

`cleanup-task.sh` の `collect_files_under` は `find "$dir" -type f` で**拡張子を問わず**
全ファイルを集め、`is_keep_path` が除外するのは `wip/worklogs/TEMPLATE.md` と、
どの階層にあっても `REVIEW-POINTS.md` / `REVIEW-POINTS.local.md` だけである。

```
$ sed -n '174,190p' .claude/scripts/src/cleanup-task.sh
collect_files_under() {
  ...
  done < <(find "$dir" -type f -print0 | LC_ALL=C sort -z)
```

したがって `wip/worklogs/*_checklist.tsv` は**何もしなくても削除対象に入る**。実際に
ダミーの `.tsv` を置いて `--dry-run` で確かめた。

```
$ touch wip/worklogs/_probe.tsv
$ bash .claude/scripts/src/cleanup-task.sh --dry-run --skip-index | jq -r '.deletedFiles[]' | grep -c '_probe.tsv'
1
$ bash .claude/scripts/src/cleanup-task.sh --dry-run --skip-index | jq -r '.targetDirs'
[
  "wip/plans",
  "wip/worklogs",
  "wip/reports"
]
```

**`targetDirs` は `.mrworkflow.json` の設定値から組み立てられている**（`worklogDir` 等）。
[Q1](#q1-チェックリストの置き場所と命名) で生成側も同じ設定値から解決すると決めたのは、
この削除側と食い違わせないためである。

**flow-id 5-5 で消した直後の 5-6 のpushで再生成されないこと**は、削除側ではなく生成側が
担保する（[Q6](#q6-posttooluse-hookの次回分生成と既存hookとの競合) の生成条件3）。
`cleanup-task.sh` は削除するだけなので、生成条件を持たないと 5-6 のpush後に
**追跡されていないチェックリストが1件だけ残る**（片付けたはずのディレクトリが復活する）。

**issue本文の「flow-id 4-6 で削除」を採らない理由**: 4-6 で消すと、直後の 4-7 のpushで
チェックリストが存在しなくなり、**フェーズ4以降のpushが機構の対象外へ落ちる**。
issue #17 起票時点では現行フローの片付けが flow-id 5-5 に集約されていることが前提に
入っていなかったと見られる。

**`extract-frontmatter.sh` の走査対象に入らないことの確認**: 走査は `.md` に限られている
（`extract-frontmatter.sh:407`）。ソースの目視は「拡張子が何であっても1行ヒットする」ため
検証にならないので、**実際にダミーの `.tsv` を置いて走らせた**。

```
$ touch wip/worklogs/_probe.tsv
$ bash .claude/scripts/src/extract-frontmatter.sh .
$ grep -c '_probe\.tsv' wip/worklogs/index.jsonl
0
```

`.claude/rules/docs-workflow.md` の運用表へ足す行は次の内容にする
（対象=AI専用／寿命=タスク単位・flow-id 5-5で削除／内容=push前に済ませるべき作業の実施状況／
運用=生成はPostToolUse hook、更新はcommit前にAIエージェント、検証はPreToolUse hook）。

### Q8. 単体テストの型

**答え**: `test_block_direct_git_commit.sh` の**2層構成をそのまま踏襲する**。

```
$ bash .claude/scripts/test/test_block_direct_git_commit.sh
passed=27 failures=0
```

1. **純粋関数の直接テスト**: hookを `source` して前置フィルタを直接呼ぶ
   （hook側は `if [ "${BASH_SOURCE[0]}" = "${0}" ]` のガードで `main` が走らないため可能）。
   終了コードは `if` で受ける（`$(func; echo $?)` は `set -e` 配下で空になる）。
2. **サブプロセス起動＋スタブ `jq` の結合テスト**: `PATH` の先頭に「呼ばれたら失敗する `jq`」を
   置き、対象外ペイロードで**`jq` が1度も呼ばれないこと**を確認する。

**超集合であることの表明**は、既存の `test_block_direct_git_commit.sh` が
「`com\mit` のようにバックスラッシュで分割された語も通過する」というケースで固定している
（59〜66行）。同じ形で `pu\sh` 等のケースを持たせる。

加えて、本機構は**生成・チェック記録・検証**を行うスクリプトを持つため、そちらは
`passed=N failures=N` 規約の通常の単体テストを新設する（一時ディレクトリに git リポジトリを
作って実行する）。

## 設計への反映

1. **flow-id 3-1（個別作業計画）で確定させる実装単位**は次の4つ。
   - `.claude/scripts/src/push-checklist.sh`（生成 `new` / チェック記録 `check` / 検証 `verify` /
     パス解決 `path`）
   - `.claude/hooks/block-unchecked-push.sh`（PreToolUse。前置フィルタ＋
     `command_invokes_git_subcommand` まではhook内で行い、**HEAD断面の検証は
     `push-checklist.sh verify` へ委譲する**。未完了なら exit 2、フロー対象なのに未生成なら
     exit 1 の警告）
   - `.claude/hooks/post-push-next-checklist.sh`（PostToolUse。`git branch --remotes --contains HEAD`
     による公開済み判定 ＋ 3つの生成条件 ＋ 次回分の生成）
   - `.claude/scripts/test/test_push_checklist.sh` / `test_block_unchecked_push.sh`
2. **既存ファイルへの変更**（新規作成ではないので見落としやすい）。
   - `.claude/scripts/test/test_sync_gemini_assets.sh` の **T11**。`raw_hints_at_git_push` を
     持つhookが2本である前提で書かれており（`for h in post-push-usage-report post-push-compact-prompt`、
     ケース名も「2本の〜」）、3本目を足すと**この前提のほうが古くなる**。3本を対象にし、
     ケース名の件数も直す。**テストは実装を `source` して呼ぶ形を崩さない**（写経しない）。
   - `.claude/settings.json`（hook登録。PreToolUse・PostToolUseの両方）
3. **flow-id 4-6（設計反映）で書く先**。
   - `.claude/docs/spec/push-checklist.md`（新規。仕様の正）
   - **`.claude/docs/README.md` のspec一覧への追記**（specを新設したら一覧も更新する。
     DDR一覧と違い生成物ではないので、手で足さないと載らない）
   - `.claude/docs/ddr/i0017-01`（配置場所・拡張子・ブロック方式。Q1〜Q5・Q7の却下案をそのまま使う）。
     **却下案として「実施そのものを機械判定する」も書く**（worklogの存在・`index.jsonl` の鮮度は
     判定できるが、`HANDOFF.md` の内容が正しいかは判定できない。一部だけ機械判定にすると
     「機械判定された項目だけが信頼できる」という非対称を仕様の読み手が読み取れなくなる）
   - `bash .claude/scripts/src/generate-ddr-list.sh` の実行（DDR一覧は生成物）
   - `.claude/rules/docs-workflow.md` 運用表への1行（Q7）
   - `.claude/rules/directory-structure.md` / `index.md`（`wip/worklogs/` に `.md` 以外が
     置かれるようになるため、ツリーの説明が古くなる）
   - `.claude/skills/commit/SKILL.md` / `.claude/skills/issue-mr-flow/SKILL.md`（commit前の更新手順）
   - `.claude/VERSION`（配布物の版。`.claude/` 配下へ機能を足すため）
4. **仕様へ明記すべき「守れない範囲」**。
   - `git push` 以外のリモート反映手段（IDEのGUI・別ツール経由など、Bashツールを通らない経路）。
   - `if` フィルタの照合規則が未解明であること。
   - `tool_response` を当てにしていないこと。
   - **チェック状態はAIエージェントの自己申告である**こと。`push-checklist.sh check` が
     状態を `done` にするだけで、その項目が実際に行われたかを機構は検証しない
     （例: worklogを書かずに `check` だけ打っても通る）。本機構が防ぐのは
     「**やるべきことの存在を忘れる**」ことであって、「やったと偽る」ことではない。
     [Q5](#q5-誤ブロックしない条件) の否定形の通し条件も、この前提の上に立っている。

## 残課題

- git bash 実機での前置フィルタの空振りコスト測定。`.claude/rules/shell-script-style.md` の
  手順に従い、**手順だけを仕様へ書き、計測は行わない**（Linuxの値を持ち込まない）。
- `tool_response` の構造の確認（[確かめられなかったこと](#確かめられなかったこと)）。本機構は
  参照しない設計にしたため実装をブロックしないが、将来 `if` フィルタの照合規則とあわせて
  切り分ける価値がある（issue #47 の未解明事項と同じ束）。
