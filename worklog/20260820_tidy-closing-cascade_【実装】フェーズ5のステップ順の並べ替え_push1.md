---
title: worklog 20260820 フェーズ5のステップ順の並べ替え push1
type: log
description: issue #112（フェーズ5のステップ順の並べ替え）の実装中の試行錯誤ログ。
tags: [worklog, issue-mr-flow, phase5]
keywords: [flow-id, 並べ替え, SKILL.md, DDR, changelog, 除外, cleanup-task]
---

# worklog: 【実装】フェーズ5のステップ順の並べ替え

対象: issue #112 フェーズ5のステップ順を 5-2 → 5-3 → 5-1 → 5-4 へ並べ替える（2026-08-20）。
全体作業計画: `plans/tidy-closing-cascade.md`
個別作業計画: `plans/【実装】フェーズ5のステップ順の並べ替え.md`
push回数: 1

## 試したこと

- `grep -rn "5-1\|5-2\|5-3\|5-4\|5-5"` でリポジトリ全体の参照を洗い出し、
  「現在の状態を説明する記述」「過去の記録（DDR本文・specのchangelog）」へ仕分けた。

## うまくいったこと

- **動くのは 5-1〜5-3 の3ステップだけ**と分かった。5-4（Draft解除）・5-5（マージ）は
  番号が変わらないため、`git-workflow.md` の担当表・`Provider.sh` の `set_mr_ready` 周辺・
  `commit` スキルの `2-2/2-7/.../5-4` の列挙は一切触らずに済む。
- `update-handoff-progress.sh` の `LOOP_RANGES` はフェーズ2〜4の6範囲だけで、フェーズ5を
  含まない。並べ替えでロジック・テーブルを変える必要は無く、コメント1行の修正で足りる。
- `.claude/docs/spec/adversarial-review.md` に flow-id 5-x の参照が0件であることを再確認した
  （issue #112 のコメントの報告どおり）。受け入れ条件の当該ファイルは実質的に対象外。

## ダメだったこと

- 特になし。

## 次の一歩

- 特になし（実装完了）。
