---
title: 【調査】Gemini CLIの記法と.gemini同期方式の確定
type: plan
description: .gemini/を.claude/からの変換生成物へ改めるにあたり、Gemini CLIの記法・同期対象・実行位置・波及範囲を確定するための個別調査計画
tags: [issue-mr-flow, gemini, 調査, plan]
keywords: [gemini-cli, agents, tools, settings.json, hooks, skills, 同期, flow-id, 冪等, 波及範囲]
---

# 【調査】Gemini CLIの記法と `.gemini/` 同期方式の確定

全体作業計画: `plans/nimble-syncing-lantern.md`（issue #70 / PR #157）

**この計画は「何をどう調べるか」だけを書く。調査結果は
`reports/20260822_nimble-syncing-lantern_gemini同期方式の調査.md` へ書く**
（`.claude/skills/issue-mr-flow/SKILL.md`「計画と実施結果の分離」）。

## 目的

フェーズ3の個別作業計画（flow-id 3-1）を書けるだけの前提を確定する。具体的には、
`.claude/scripts/src/sync-gemini-assets.sh`（仮称）の**入力・出力・変換規則・実行位置**を、
推測ではなく確かめた事実の上に置く。

## 前提（flow-id 1-4 で確定済み）

- スコープの正は issue #70 の2番目のコメント（2026-08-20「方針転換」）。issue本文は途中で切れている
- issue分割はしない（横断的変更）
- **Gemini CLI はこの実行環境に無い**（`command -v gemini` が空）

## 調査項目

### Q1. Gemini CLI の `agents/*.md` frontmatter スキーマ

**本issueの元の症状**（`tools.0: Invalid tool name`）を直接決める項目。

- 何を調べるか
  - `tools` に許される値の集合（`run_shell_command` / `read_file` / `search_file_content` /
    `glob` 等、実際の語彙）
  - `model` キーの扱い（存在するか／値の語彙／省略可否）
  - 必須キー・許容キー（`name` / `description` 以外に何が要るか）。**Claude 側が持つ
    `title` / `type` / `tags` / `keywords`（`.claude/rules/markdown-frontmatter.md` 由来）が
    バリデーションで弾かれないか**は、`tools` と同じくらい重要。弾かれるなら除去も変換に含める
  - エラーメッセージ `tools.0: Invalid tool name` の出どころ（配列の0番目を指すので、
    `tools` は**配列**として解釈されている。Claude 側のカンマ区切り文字列がどう解釈されるか）
- どう調べるか
  1. Gemini CLI の公式リポジトリ・ドキュメントを一次情報として参照する（WebFetch/WebSearch）
  2. `.claude/agents/*.md` の現行値 2件を実入力として、変換前後の対応表を作る
- **確かめられないこと**: 実際にローダを通しての検証。**「一次情報にこう書いてある」と
  「実機で通った」を結果レポートで明確に分けて書く**

### Q2. Gemini CLI は `skills/` を読むか

- 読む → `SKILL.md` も変換対象（frontmatter の記法差を調べる）
- 読まない → コピーのみ、あるいは同期対象から外す
- **判断できない場合は「コピーのみ（変換なし）」を採る**。変換しない方が情報を落とさず、
  後から変換を足せるため

### Q3. `settings.json` の写像

issue #70 のコメントが挙げる10項目（イベント名・matcher・`command`＋`args[]`・timeout単位・
環境変数・plans設定・`if`・`permissions`・`name`・SessionStart matcher）を、
**現行の `.claude/settings.json` と手書きの `.gemini/settings.json` の実物を突き合わせて**検証する。

- 手書き版が既に「あるべき出力」として使えるなら、**変換スクリプトの期待値（ゴールデンファイル）
  として単体テストに固定できる**。まずこの一致を確認する
- 一致しない点があれば、どちらが正しいかを一次情報で判断する
- **情報が落ちる写像**（`permissions` の破棄・`if` の畳み込み）を、落ちる事実として明示できる形に
  まとめる。`if` の畳み込みで **`post-push-*` が「git push 以外のBash呼び出しでも毎回発火する」
  ことになる**点は、機能等価ではないので必ず洗い出す

### Q4. コピー対象・除外対象

`.claude/` 配下のうち、`.gemini/` へ持って行くもの／行かないものを確定する。

- 除外候補: `index.jsonl`（`.gitignore` 対象の生成物・各ディレクトリに散在）、`state/`（同）、
  `settings.json`（変換対象なのでコピーではない）、`scripts/test/`（要否を判断）
- **`.gemini/` をGit管理下に置くことの副作用**を洗い出す
  - `rg` / `grep` / Glob の二重ヒット
  - `extract-frontmatter.sh` の走査対象がほぼ倍増する（性能。`.claude/rules/shell-script-style.md`
    「外部プロセス起動のコスト」）。`index.jsonl` が `.gemini/` 側にも生成されるか
  - `doc-search` スキルの検索結果に `.gemini/` 側が混ざるか

### Q5. 同期の実行位置（flow-id）

issue #70 は「flow-id 5-3（片付け）の直前へ新設」と書くが、**この番号は issue #111 の
統括レポート追加以降ずれており、現在の片付けは 5-4** である。3案を比較する。

| 案 | 内容 | 繰り下げ |
|---|---|---|
| A | 5-4 の直前へ新規 flow-id を挿入 | 5-4→5-5 / 5-5→5-6 / 5-6→5-7 が発生 |
| B | 既存の片付け（5-4 / `cleanup-task.sh`）へ統合 | 無し |
| C | flow-id を増やさない**並行手順**として定義（`REVIEW-POINTS.md` 収集・追従監視・敵対的レビューと同じ扱い） | 無し |

- 各案の実コストを**実測する**（`grep` で `flow-id 5-[3-6]` の出現箇所をファイル別に数える）
- 判断材料として、DDR は本文を変更しない運用（`.claude/rules/docs-workflow.md`）のため
  DDR 側は更新対象外である点を確認する

### Q6. 波及範囲の全件洗い出し

`.gemini` / `setup-gemini-links.sh` に言及するファイルを全件挙げ、**変更要否を1件ずつ判定する**。

- 既知の言及先（`grep` 実測）: `README.md` / `index.md` / `.claude/rules/directory-structure.md` /
  `.claude/docs/spec/{distribution-assets,issue-mr-workflow,search-frontmatter}.md` /
  `.claude/hooks/post-push-{compact-prompt,usage-report}.sh` /
  `.claude/scripts/src/search-frontmatter.sh` / `.claude/scripts/test/test_search_frontmatter.sh` /
  `.claude/skills/apply-mr-workflow-to-project/{SKILL.md,scripts/sync-assets.sh,scripts/install-to-project.sh}` /
  DDR 9件
- **DDR は本文を変更しない**（`i0000-13` は frontmatter の `status` のみ）
- **配布（`apply-mr-workflow-to-project`）への波及**は、配布先で `.gemini/` をどう作るかの
  判断を含むため、変更要否だけでなく**方針まで**決める

## この計画で決めないこと（スコープ外）

- 変換スクリプトの実装そのもの（フェーズ3）
- Gemini CLI の実機での動作確認（環境に無い）
- GitLab（`glab`）側の対応
- issue #26（AIアセットのmanifest配布）本体の改訂

## 検証（この調査自体が正しく行えたかの確認）

- Q1・Q2 の結論に**出典URL**が添えられていること。添えられないものは「未確認」と明記する
- Q3 の写像表の各行に、**現行2ファイルの実際の値**（変換前・変換後）が入っていること
- Q5 のコスト比較に、次のコマンドの**実出力**が添えられていること

  ```bash
  grep -rno "flow-id 5-[3-6]" --include="*.md" . | grep -v "/ddr/" \
    | awk -F: '{print $1}' | sort | uniq -c | sort -rn
  ```

- Q6 の一覧が、次のコマンドの出力を**全件カバー**していること（判定を書いていない行が無いこと）

  ```bash
  grep -rln "\.gemini\|setup-gemini-links" --include="*.md" --include="*.sh" --include="*.json" .
  ```

## 成果物

- `reports/20260822_nimble-syncing-lantern_gemini同期方式の調査.md`（正文）
- `reports/20260822_nimble-syncing-lantern_gemini同期方式の調査.html`（視覚化）
