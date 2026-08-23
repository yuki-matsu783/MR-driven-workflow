---
title: 【実装】【テスト】push前チェックリスト機構の実装
type: plan
description: issue #17 のpush前チェックリスト機構を、スクリプト1本・hook2本・テスト2本＋既存T11の改修として実装する計画。
tags: [plan, issue-mr-flow, hook, push]
keywords: [push前チェックリスト, PreToolUse, PostToolUse, push-checklist, 前置フィルタ, TSV, 単体テスト, T11]
---

# 【実装】【テスト】push前チェックリスト機構の実装

対象: issue #17「hookを使って、push時にしてほしいことを実現する」フェーズ3。
全体作業計画: `wip/plans/steady-guarding-checkpoint.md`
前提となる調査結果: `wip/reports/20260823_steady-guarding-checkpoint_push前チェックリスト機構の設計調査.md`
（**Q1〜Q8の結論がこの計画の入力である。設計判断をここで作り直さない**）

**種別を `【実装】【テスト】` と併記する理由**: テストコードは実装と同時に書き、まとめて1回で
合意を取る（`.claude/skills/issue-mr-flow/references/planning.md`「種別を複数併記する場合／分ける場合」）。
本機構はhookであり、**テストを伴わない実装は成立しない**（前置フィルタが超集合でなくなると
hookが無言で発火しなくなるため）。分けると同じ内容を2回説明することになる。

## この計画で作るもの

| # | ファイル | 種別 | 役割 |
|---|---|---|---|
| 1 | `.claude/scripts/src/push-checklist.sh` | 新規 | 生成・チェック記録・検証・パス解決の本体 |
| 2 | `.claude/hooks/block-unchecked-push.sh` | 新規 | PreToolUse。未完了なら exit 2 |
| 3 | `.claude/hooks/post-push-next-checklist.sh` | 新規 | PostToolUse。次回分を生成 |
| 4 | `.claude/scripts/test/test_push_checklist.sh` | 新規 | 1のテスト |
| 5 | `.claude/scripts/test/test_block_unchecked_push.sh` | 新規 | 2のテスト（2層構成） |
| 6 | `.claude/scripts/test/test_sync_gemini_assets.sh` | **改修** | T11を2本→3本対応へ |
| 7 | `.claude/settings.json` | **改修** | hook登録（PreToolUse 1件・PostToolUse 2件） |

**6・7は既存ファイルの改修であり、見落としやすい。** とくに6は、足さなければT11が緑のまま
3本目の写経のドリフトを見逃す（調査結果Q5の指摘）。

## 実装の順序

依存関係の順に並べる。**各段でその段のテストを通してから次へ進む**（最後にまとめてテストしない）。

1. **`push-checklist.sh` を書く**（4も同時に書く）。hookはこれに委譲するだけなので、ここが本体。
2. **`block-unchecked-push.sh` を書く**（5も同時に書く）。
3. **`post-push-next-checklist.sh` を書く**。
4. **`test_sync_gemini_assets.sh` のT11を3本対応へ改修する**（3を書いた直後。先に改修すると
   ファイルが存在せずT11が落ちる）。
5. **`.claude/settings.json` へ登録する**。
6. **回帰確認**（下記「検証」）。

## 1. `push-checklist.sh`（本体）

### サブコマンド

| サブコマンド | 引数 | 役割 | 終了コード |
|---|---|---|---|
| `path` | なし | カレントブランチの**最新**チェックリストのパスをstdoutへ。無ければ空で終了コード1 | 0 / 1 |
| `new` | なし | 次回分を生成する。生成条件（Q6の3つ）を満たさなければ**何もせず0で終わる** | 0 |
| `check <id> <ログ>` | id・実施ログ | その行を `done` にし、4列目へログを書く | 0 / 1 |
| `skip <id> <理由>` | id・理由 | その行を `skip` にし、4列目へ理由を書く | 0 / 1 |
| `verify` | なし | 最新チェックリストの**HEAD断面**を検証する。通れば0、通らなければ1 | 0 / 1 |

- **`verify` は「通ってよいか」だけを返し、exit 2 を返さない。** exit 2 はhookの契約であり、
  スクリプト単体の終了コードとしては使わない（テストから呼ぶときに紛らわしいため）。
  hook側が1を受けて2へ翻訳する。
- **`check` / `skip` は作業ツリー上のファイルを書き換える**（`verify` はHEAD断面を読む）。
  この非対称は意図的で、調査結果Q4の結論（hookはHEADを読む）に対応する。

### 置き場所・命名

- 置き場所は `get_workflow_config`（`.claude/scripts/src/vcs/Provider.sh`）の `worklogDir` から
  解決する。**自前で `// "..."` の既定値を書かない**（`get_workflow_config` 自身が既定値を
  持っており、`cleanup-task.sh` と同じ値になる。ここを独自に `wip/worklogs` と書くと、
  `.mrworkflow.json` が無い配布先で削除側と食い違う。調査結果Q1の訂正を参照）。
- 命名は `<YYYYMMDD>_<ブランチslug>_push<N>_checklist.tsv`。
  - ブランチslugは `[^a-zA-Z0-9_-]` を `_` へ。`post-push-compact-prompt.sh` と同じ変換だが、
    **`sed` ではなくbash組み込み（`${branch//...}` のループ）で行う**（hookから呼ばれるため）。
  - `<N>` は既存チェックリストの最大値 + 1。

### ファイル形式

```
# generated-for: <HEADのSHA>
# id	項目	状態	実施ログ
worklog	worklogを作成／今回のpush分を追記した	pending
```

- 1行目・2行目は `#` で始まるコメント。**`#` で始まる行は読み飛ばす。**
- データ行は**常にちょうど4フィールド**（`pending` でも4列目を空で出す）。
- 状態は `pending` / `done` / `skip` の3値。
- 項目（5件）とidは**スクリプト内の定数**として持つ。文言は調査結果Q2の表をそのまま使う。

### `verify` の判定（否定形）

「通してよい」と積極的に確認できたときだけ0を返す。1つでも欠ければ1。

1. 全データ行が**ちょうど4フィールド**。
2. `id` 列の集合が**5件の定数と過不足なく一致**。
3. 全行の状態が `done` または `skip`。
4. `done` / `skip` の行の**4列目が空でない**。

**複数のチェックリストがHEADに存在する場合は `<N>` が最大の1本だけを見る。**

### `new` の生成条件（3つすべて）

1. HEADが公開済み（`git branch --remotes --contains HEAD` が1件以上）。
2. **そのHEAD SHAを `# generated-for:` に持つチェックリストが1本も無い。**
3. HEADにタスク成果物が残っている（`plansDir` / `worklogDir` / `reportsDir` のいずれかに、
   `TEMPLATE.md`・`REVIEW-POINTS*.md` を除くファイルがある）。

**条件を満たさないときは、エラーではなく静かに0で終わる**（PostToolUseの正常系だから）。

## 2. `block-unchecked-push.sh`（PreToolUse）

`block-direct-git-commit.sh` の構造をそのまま踏襲する。

1. `main()` 冒頭で**前置フィルタ** `raw_hints_at_git_push`（`post-push-compact-prompt.sh:222-240` と
   **同一実装**を写経）。
2. `jq` で `tool_name` / `tool_input.command` を取り出す。
3. `CommandPosition.sh` を `source` して `command_invokes_git_subcommand "$command" push`。
   `BASH_VERSINFO` ≥ 4.3・`[ -r ]`・`source` 成否・`declare -F` の4点を確かめ、**駄目なら
   `grep -qiE 'git[[:space:]]+push'` の部分一致へ縮退**（ブロック側へ倒す）。
4. push と判定したら `push-checklist.sh verify` を呼ぶ。
   - 0 → `exit 0`
   - 1（未完了・壊れている） → 理由と**ルールファイルのパス**をstderrへ出して `exit 2`
   - チェックリストがHEADに無い → ブロックしない。ただし**作業ツリーには存在する**なら
     `exit 1`（非ブロックのエラー）＋警告
5. 末尾に `if [ "${BASH_SOURCE[0]}" = "${0}" ]; then main; fi` のガードを置く。

**ブロックメッセージには「未完了の項目名」と「`.claude/skills/commit/SKILL.md` /
`.claude/docs/spec/push-checklist.md`」を必ず含める**（issue #17 の受け入れ条件）。

## 3. `post-push-next-checklist.sh`（PostToolUse）

同じく前置フィルタ＋`command_invokes_git_subcommand` のあと、`push-checklist.sh new` を呼ぶだけ。

- **既存2本より後ろに登録する**（既存の出力を邪魔しない）。
- **既存2本のロジックは1バイトも変更しない**（issue #17 の受け入れ条件）。
- `new` が静かに0で終わる設計なので、hook側に条件分岐を持たない。

## 4-5. 新規テスト2本

`test_block_direct_git_commit.sh` の2層構成を踏襲する。

- **層1（純粋関数）**: hookを `source` して `raw_hints_at_git_push` を直接呼ぶ。
  **超集合であることのケースを必ず持つ**（`pu\sh`・`PUSH`・JSONエスケープを跨いだ
  `pu\<改行>sh` 等）。終了コードは `if` で受ける（`$(func; echo $?)` は `set -e` 配下で空になる）。
- **層2（結合）**: サブプロセス起動＋`PATH` 先頭のスタブ `jq`。対象外ペイロードで
  **`jq` が1度も呼ばれないこと**を確認する。
- `push-checklist.sh` のテストは、**一時ディレクトリにgitリポジトリを作って**実行する
  （このリポジトリの状態を変えない）。`verify` の4条件それぞれについて、
  **意図的に壊したTSVで1が返ること**を確かめる（「異常が無ければ何も出ない」形にしない）。
- 出力は `passed=N failures=N`、失敗時は終了コード1。

## 6. `test_sync_gemini_assets.sh` のT11改修

```
323:for h in post-push-usage-report post-push-compact-prompt; do
339:assert_eq "T11: 2本の raw_hints_at_git_push が同一実装である" \
```

- ループへ `block-unchecked-push` `post-push-next-checklist` を足して**4本**にする。
  （調査結果は「3本」と書いているが、これは `raw_hints_at_git_push` を持つhookの本数であり、
  **新規hookは2本ともこれを持つ**ため実際は4本になる。**この食い違いは実装時に確定させる。**）
- ケース名の「2本の」を実際の本数へ直す。
- **テストは実装を `source` して呼ぶ形を崩さない**（テスト側へ写経しない）。

## 7. `.claude/settings.json`

- `PreToolUse` の `Bash|PowerShell` matcher へ `block-unchecked-push.sh` を追加（`if` は付けない。
  `block-direct-git-commit.sh` と同じ）。
- `PostToolUse` の `Bash|PowerShell` matcher の**末尾**へ、`if: "Bash(git push*)"` と
  `if: "PowerShell(git push*)"` の2エントリを追加。
- `timeout` は既存に合わせ、PreToolUse 10 / PostToolUse 20。

## 検証（合格条件）

**着手前に変更前のツリーで流し、期待どおりの結果になることを確かめてから実装する。**

```bash
# 1. 構文チェック（新規3本）
for f in .claude/scripts/src/push-checklist.sh \
         .claude/hooks/block-unchecked-push.sh \
         .claude/hooks/post-push-next-checklist.sh; do
  bash -n "$f" || echo "NG: $f"
done

# 2. 前置フィルタが全hookで同一実装であること（T11）
bash .claude/scripts/test/test_sync_gemini_assets.sh

# 3. 新規テスト2本
bash .claude/scripts/test/test_push_checklist.sh
bash .claude/scripts/test/test_block_unchecked_push.sh

# 4. 既存テストの回帰（失敗を集計して終了コードへ伝播させる）
fail=0; n=0
for t in .claude/scripts/test/test_*.sh; do
  n=$((n + 1))
  bash "$t" || { echo "NG: $t"; fail=1; }
done
echo "実行本数=$n"
[ "$n" -gt 0 ] && [ "$fail" = 0 ]

# 5. settings.json が妥当なJSONで、hookが登録されていること
jq -e '.hooks.PreToolUse[].hooks[] | select(.args[0] | endswith("block-unchecked-push.sh"))' \
  .claude/settings.json > /dev/null
jq '[.hooks.PostToolUse[].hooks[] | select(.args[0] | endswith("post-push-next-checklist.sh"))] | length' \
  .claude/settings.json   # 2 であること

# 6. 配布層の網羅性（新規ファイルが core に含まれること）
bash .claude/scripts/src/check-dist-coverage.sh
```

**5の `jq -e` は、登録漏れがあれば非0で落ちる**（「異常が無ければ何も出ない」形を避けている）。
6は `.claude/` 配下へファイルを足したときに落ちうるので必ず流す。

## やらないこと

- **チェック項目の実施そのものを機械判定しない**（自己申告のまま）。理由は調査結果の
  「守れない範囲」・DDR `i0017-01` の却下案として書く。
- **既存push系hook 2本のロジックを変更しない。**
- **`.gemini/` を直接編集しない**（flow-id 5-3 の変換同期で追随させる）。
- **spec / DDR / `docs-workflow.md` 等への反映はフェーズ4で行う**（この計画の対象外）。
  ただし**新規スクリプトのヘッダコメントには、参照先として issue番号と
  `.claude/docs/spec/push-checklist.md` を書く**（`wip/` 配下を参照しない）。

## 未確定事項（実装中に確定させる）

1. **T11の対象本数が3本か4本か**（上記6）。`raw_hints_at_git_push` を新規hook 2本とも持つなら4本。
   PreToolUse側も同じ前置フィルタでよいかを実装時に確かめる。
2. **`check` / `skip` のTSV書き換えで、実施ログ中のタブをどう扱うか。** 調査結果Q3は
   「エスケープしない」方針だが、`verify` が4フィールド固定を要求するため、
   **タブを空白へ潰す**のが最小の対処になる見込み。
3. **警告（exit 1）の文面**。stderrが届くか未確認なので、届かなくても機構が壊れないことを保つ。
