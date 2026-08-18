---
title: 【AIアセット反映】index.jsonl生成物化のAIアセット反映
type: guide
description: issue #36の実装内容をルール・スキル文書へ反映する個別反映計画（AIアセット反映のみ）
tags: [frontmatter, index-jsonl, docs-workflow, skill]
keywords: [flow-id5-1, docs-workflow, SKILL.md, directory-structure]
---

# 【AIアセット反映】index.jsonl生成物化のAIアセット反映

対象: issue #36 frontmatter index.jsonlをGit管理から外し生成物として扱う（AIアセット反映のみ）。
全体作業計画: `plans/whimsical-launching-reef.md`
先行する設計反映計画: `plans/【設計反映】index.jsonl生成物化の設計反映.md`

**着手タイミング**: レビュー指摘（「設計反映とAIアセット反映は基本的に別タイミングでやる」）を
受け、`plans/【設計反映】index.jsonl生成物化の設計反映.md`の実施・レビュー完了後に本計画へ着手する
（本ファイルはその後の作業のために計画のみ先行して用意しておくもの）。

## 背景

flow-id 3-6の実装（`index.jsonl`のGit管理除外・SessionStart hookでの自動再生成）により、
`.claude/skills/issue-mr-flow/SKILL.md`のflow-id 5-1に組み込まれていた「`plans/index.jsonl`を
個別削除し`index.jsonl`群を再生成する」という特殊対応が不要になった。この事実を運用ルールへ
反映する。

## AIアセット反映

### 1. `.claude/skills/issue-mr-flow/SKILL.md`のflow-id 5-1特殊対応記述の除去

- 全体フロー表の5-1行を簡略化する:
  変更前「次タスクのために、`plans/` `worklog/` `reports/` を削除し、`HANDOFF.md` をリセットする。
  **あわせて `plans/index.jsonl` も削除し、`bash .claude/scripts/src/extract-frontmatter.sh .` で
  `index.jsonl` 群を再生成する**（下記「flow-id 5-1での `index.jsonl` の扱い」）」
  → 変更後「次タスクのために、`plans/` `worklog/` `reports/` を削除し、`HANDOFF.md` をリセットする」
- 「## flow-id 5-1での `index.jsonl` の扱い」見出しのセクション全体（`rm -f plans/index.jsonl`の
  コマンド例を含む）を削除する。
- 「## PRがflow-id 5-1実施前にマージされてしまった場合の対処」内、手順3の
  「`plans/index.jsonl`の削除と`index.jsonl`群の再生成も含む。上記「flow-id 5-1での
  `index.jsonl` の扱い」参照）」という言及を除去し、
  「（内容はflow-id 5-1で行うものと同じ）」に簡略化する。

### 2. `.claude/rules/docs-workflow.md`の更新

- `plans/【種別】タスク内容.md`行の「運用」列末尾にある
  「**flow-id 5-1では`plans/*.md`とあわせて`plans/index.jsonl`も削除し、`index.jsonl`群を再生成する**
  （`extract-frontmatter.sh`はmarkdownが直下に存在するディレクトリのみを出力対象にするため、
  再生成では消えず陳腐化したまま残る。詳細: `.claude/skills/issue-mr-flow/SKILL.md`「flow-id 5-1
  での `index.jsonl` の扱い」）」という括弧書きを除去する。

### 3. `.claude/rules/directory-structure.md`の確認

grep調査の結果、`index.jsonl`への直接言及は無い（ヒットしたのは`usage/state/push-index.jsonl`
という無関係の別ファイル）。矛盾なし、**変更不要**と結論する。

### 4. `.claude/rules/markdown-frontmatter.md`

flow-id 3-6で既に更新済み（本計画の対象外）。

## 動作確認方法

- `git grep -n "flow-id 5-1での" .claude` で参照切れが残っていないことを確認
- `git grep -n "index.jsonl" .claude/skills/issue-mr-flow/SKILL.md .claude/rules/docs-workflow.md` で
  除去漏れが無いことを確認
