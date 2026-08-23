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
6. [Q6](#q6-posttooluse-hookの次回分生成と既存hookとの競合) — push成否の判定に `tool_response`
   ではなく **`HEAD == @{upstream}`** を使うと決めた。

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
| Q6 | push成否は `HEAD == @{upstream}` で判定する。`tool_response` は既存hookも参照しておらず当てにしない | ◎良 | 実測 |
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
- 使ったコマンド: `grep -n` による実装の読み取り、`jq` による `.claude/settings.json` の走査、
  `bash .claude/scripts/test/test_block_direct_git_commit.sh` の実行、`git rev-parse`。

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
  片付かずに残る**。設定・キーが無い場合のフォールバックは `wip/worklogs`。
  **解決は生成・検証スクリプト側が行い、hookはそこへ委譲する**（設定の読み方を2箇所に持たない）。
- **`<N>` は、そのブランチの既存チェックリストの最大値 + 1。** `HANDOFF.md` の `- push回数:` は
  人間・AIが手で書き換えられる値であり、チェックリストの実体と食い違いうるので使わない。
  ファイル名から導けば、**生成が冪等**になる（同じ状態で2回走らせても同じ番号になる）。

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
# id	項目	状態	実施ログ
worklog	worklogを作成し、このpushまでの試行錯誤を追記した	pending
handoff	HANDOFF.mdの進捗表・ヘッダを更新した	done	3-6完了として mark-done 3-6 を実行
```

- **状態は `pending` / `done` / `skip` の3値。** `pending` が1件でも残っていればブロックする。
- **`done` / `skip` は実施ログ（4列目）が非空であることを要求する。** 空の `done` を許すと
  「チェックだけ付ける」が最短経路になるため、少なくとも**何をしたかを書く**コストは課す。
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

**答え**: ブロックするのは次の**すべて**を満たすときだけ。

1. コマンドが `git push` を**コマンド位置で**実行する
   （`command_invokes_git_subcommand "$command" push`）。
2. カレントブランチのチェックリストが**HEADに存在する**。
3. そのチェックリストに `pending` の行が**1件以上ある**。

したがって次はブロックされない。

- **チェックリスト未生成**（フロー対象外のブランチ・機構の導入直後・ブランチ初回push）。
  ただし**無条件に黙って通すのではなく、「フロー対象のブランチなのにチェックリストが無い」
  ときだけ警告する**（下記）。
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

**「未生成のまま素通りした」ことを検出可能にする（ブロックはしない）。** 素通りさせるだけだと、
PostToolUseが生成したチェックリストを**コミットし忘れた**場合に機構が**無言で無効化**され、
しかも「ブロックされないので正常に見える」。そこで、

- HEADに `wip/plans/` または `wip/worklogs/` のタスク成果物がある（`TEMPLATE.md`・
  `REVIEW-POINTS*.md` を除く）＝**フロー対象のブランチ**であり、
- それなのにチェックリストがHEADに無い

ときは、**exit code 1（非ブロックのエラー）＋ 標準エラーへの警告**でpushを通す。
Claude Code のhookは「0＝成功／2＝ブロック／それ以外＝非ブロックのエラー（stderrをユーザーへ
表示し、実行は継続）」という規約のため、この形なら**ブロックせずに気づかせられる**。
**この警告が実際にユーザーへ届くかは本セッションでは確かめていない**ため、届かなくても
機構が壊れない設計（通す側は変わらない）にしている。

**縮退時（`CommandPosition.sh` が使えない／部分一致へ落ちる）はブロック側へ倒す。**
`block-direct-git-commit.sh` と同じ扱いにする。pushは「止まると作業が進まない」度合いが大きいが、
上の条件2・3により**チェックリストが存在し未完了項目があるときにしか発火しない**ため、
誤ブロックの被害範囲は「チェックを埋めれば通る」に限られる。

**前置フィルタは既存の `raw_hints_at_git_push` と同型のものを持つ。**
`post-push-compact-prompt.sh:222-240` に実装があり、JSON文字列エスケープの2文字シーケンスを
まとめて除去してからブラケット式で `push` を大文字小文字非依存に探す形になっている。
**3本目として同じ実装を持たせる**（`source` で共有しない理由は、既存2本が同型の実装を
それぞれ持っている前例に従い、hookが単独で動くことを優先するため）。

### Q6. PostToolUse hookの次回分生成と既存hookとの競合

**答え**: push成否は **`HEAD == @{upstream}`** で判定する。`tool_response` は使わない。

リポジトリ内に `tool_response` を参照している箇所は**1つも無い**。既存の
`post-push-usage-report.sh` / `post-push-compact-prompt.sh` も参照しておらず、
「push成功後」という前提はどちらも検証していない。

```
$ grep -rn 'tool_response' .claude/
（0件）
```

一方 `HEAD == @{upstream}` は、pushが成功していれば一致し、失敗していれば一致しない。
実測でも一致を確認した。

```
$ git rev-parse HEAD
f58bfdd763befe9504bbeef234d1e7504d162702
$ git rev-parse '@{u}'
f58bfdd763befe9504bbeef234d1e7504d162702
```

**なぜこの判定が要るか**: pushが失敗しているのに次回分を生成すると、**再pushが新しい未完了の
チェックリストにブロックされる**。「失敗したpushをやり直せない」という最悪の failure mode に
なるため、ここは緩めない。

**既存hookとの競合**: `.claude/settings.json` の `PostToolUse` には、既に同じ matcher
（`Bash|PowerShell`）で4エントリが `if: "Bash(git push*)"` / `if: "PowerShell(git push*)"` 付きで
並んでいる。本機構は**5・6番目のエントリとして末尾に足す**（既存の2本より後に走らせ、
既存の出力を邪魔しない）。`if` フィルタも既存2本と同じ2種を付ける
（Gemini CLI経路では `if` が効かないため、いずれにせよ自前判定が要る）。

**状態ファイルは持たない。** 次回の番号はファイル名から導ける（[Q1](#q1-チェックリストの置き場所と命名)）。

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
   - `.claude/hooks/post-push-next-checklist.sh`（PostToolUse。`HEAD == @{upstream}` の確認 ＋
     次回分の生成）
   - `.claude/scripts/test/test_push_checklist.sh` / `test_block_unchecked_push.sh`
2. **flow-id 4-6（設計反映）で書く先**。
   - `.claude/docs/spec/push-checklist.md`（新規。仕様の正）
   - `.claude/docs/ddr/i0017-01`（配置場所・拡張子・ブロック方式。Q1〜Q5・Q7の却下案をそのまま使う）
   - `.claude/rules/docs-workflow.md` 運用表への1行（Q7）
   - `.claude/skills/commit/SKILL.md` / `.claude/skills/issue-mr-flow/SKILL.md`（commit前の更新手順）
   - `.claude/settings.json`（hook登録）
3. **仕様へ明記すべき「守れない範囲」**: `git push` 以外のリモート反映手段、`if` フィルタの
   照合規則が未解明であること、`tool_response` を当てにしていないこと。

## 残課題

- git bash 実機での前置フィルタの空振りコスト測定。`.claude/rules/shell-script-style.md` の
  手順に従い、**手順だけを仕様へ書き、計測は行わない**（Linuxの値を持ち込まない）。
- `tool_response` の構造の確認（[確かめられなかったこと](#確かめられなかったこと)）。本機構は
  参照しない設計にしたため実装をブロックしないが、将来 `if` フィルタの照合規則とあわせて
  切り分ける価値がある（issue #47 の未解明事項と同じ束）。
