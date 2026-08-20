---
title: フェーズ5のステップ順を 5-2 → 5-3 → 5-1 → 5-4 へ並べ替える（全体作業計画）
type: plan
description: issue #112 の全体作業計画。フェーズ5のクローズ手順を「コンフリクト解消 → 関連issue通知 → 片付け → commit・push・Draft解除」の順へ並べ替え、flow-idの参照を全ドキュメント・スクリプトで揃えるまでの全体像。
tags: [plan, workflow, issue-mr-flow, phase5]
keywords: [フェーズ5, flow-id, 並べ替え, cleanup-task, 関連issue通知, コンフリクト検知, HANDOFF, DDR, issue112]
---

# 全体作業計画: フェーズ5のステップ順の並べ替え（issue #112）

対象issue: https://github.com/yuki-matsu783/MR-driven-workflow/issues/112
ブランチ: `claude/phase-5-step-reorder-mrb714`

## このタスクで実現すること

`.claude/skills/issue-mr-flow/SKILL.md` のフェーズ5を次の順序へ並べ替え、
リポジトリ内の flow-id 参照をすべて新しい番号へ揃える。

| 新flow-id | 内容 | 旧flow-id |
|---|---|---|
| 5-1 | defaultブランチとのコンフリクトを検知し、あれば解消する | 5-2 |
| 5-2 | 今回のMRが影響する関連issueを特定し、承認を得てから通知する | 5-3 |
| 5-3 | 次タスクのために `plans/` `worklog/` `reports/` を削除し `HANDOFF.md` をリセットする | 5-1 |
| 5-4 | commit・push して Draft を解除する（AIエージェントはここで止まる） | 5-4 |

5-4（Draft解除）・5-5（マージ）は番号・内容とも変わらない。動くのは 5-1〜5-3 の3ステップのみ。

## フェーズ2〈調査〉

- リポジトリ内の `5-1` `5-2` `5-3` の参照箇所を洗い出し、**書き換える対象**と
  **書き換えてはいけない対象**（DDR本文・specの過去issueごとのchangelog）に仕分ける。
- `.claude/scripts/src/update-handoff-progress.sh` の `LOOP_RANGES` にフェーズ5の範囲が
  含まれるかを確認する（含まれなければテーブル自体の変更は不要）。
- `.claude/docs/spec/adversarial-review.md` に flow-id 5-x の参照が本当に無いかを確認する
  （issue #112 のコメントで0件と報告済み。受け入れ条件の裏取りとして再確認する）。
- issue #108（`HANDOFF.md` をタスク単位のファイルにする）との前後関係を整理する。

## フェーズ3〈実装〉

- `.claude/skills/issue-mr-flow/SKILL.md`（全体フロー表・フェーズ5の各節・監視節・
  レビュー依頼節の flow-id 参照）を並べ替える。
- 新5-2（関連issue通知）の手順へ、差分から `plans/` `worklog/` `reports/` を除外する旨を補う。
- `.claude/rules/` `.claude/skills/` `index.md` `.claude/docs/spec/` の現在の状態を説明する
  記述と、`.claude/scripts/src/` のコメントを新しい番号へ更新する。

## フェーズ4〈反映〉

- `.claude/docs/spec/issue-mr-workflow.md` `.claude/docs/spec/cleanup-task.md`
  `.claude/docs/spec/check-base-conflicts.md` 等へ反映し、影響範囲へ本issue分のエントリを追記する。
- DDRを1本追加し、並べ替えの理由・却下案・DDR 0044/0048との関係・issue #108 との前後関係を記録する
  （番号は 0056）。

## この計画で決めないこと（スコープ外）

- issue #108（`HANDOFF.md` をタスク単位のファイルにする）そのものの実装。本タスクでは
  「先に #108 が入った場合に何が変わるか」を記録するだけにとどめる。
- flow-id 連番の重複検知（issue #108 が後続候補として記録している論点）。
- フェーズ5以外のフェーズのステップ順。

## 検証

```bash
bash -n .claude/scripts/src/update-handoff-progress.sh
bash -n .claude/scripts/src/cleanup-task.sh
bash -n .claude/scripts/src/check-base-conflicts.sh
bash .claude/scripts/test/test_update_handoff_progress.sh
bash .claude/scripts/test/test_cleanup_task.sh
# 並べ替え後に旧番号の参照が残っていないことの目視確認
grep -rn "flow-id 5-" --include='*.md' --include='*.sh' . | grep -v '/ddr/'
```
