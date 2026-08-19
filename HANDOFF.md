---
title: HANDOFF
type: handoff
description: セッション間・作業者間の引継ぎメモ（現在地・次回やること等）
tags: [handoff, workflow]
keywords: [フロー進捗, worklog, 引き継ぎ, plan, レビュー]
---

# HANDOFF

<!--
AI⇔AI/AI⇔人間の状況引継ぎメモ。常に「このブランチの現状」を表現する
-->

- issue: #92 全体作業計画には調査フェーズ・反映フェーズを必ず含めるルールを追加する
- ブランチ: claude/master-plan-rule-addition-gcw0t6
- PR: 未作成（ハーネスがPR作成を制限する非対話的セッションのため。`.claude/rules/git-workflow.md`「ハーネスがPR作成を制限する環境での扱い」）
- push回数: 0
- 追従監視: 未開始（PR未作成のため）

## フロー進捗状況

進捗記号: `[x]` 完了 / `[]` 未着手・進行中 / `[-]` 今回は実施しない（スキップ）

| 進捗 | flow-id | ステップ | 担当 |
|----|---|---|---|
| [x] | 1-1 | issueを起票する（`.github/ISSUE_TEMPLATE/task.md` / `.gitlab/issue_templates/Default.md` で目的・現状・期待する動作・受け入れ条件を記載） | 人間（AIが代行する場合は `issue-create` スキル） |
| [x] | 1-2 | issueの内容を取得する | `start <issue番号>` |
| [x] | 1-3 | featureブランチ（ハーネス指定の `claude/master-plan-rule-addition-gcw0t6`）を作成する。Draft PRは非対話的セッションのため未作成 | `start`（エージェント） |
| [x] | 1-4 | **「全体作業計画」を作成する**（このissueをどう進めるかの全体像。`plans/issue92-全体作業計画.md`） | エージェント |
| [] | 1-5 | 全体作業計画に合意する | 人間 |
| [x] | 1-6 | 全体作業計画をもとにHANDOFF.mdを更新する | エージェント |
| [x] | 2-1 | **個別調査計画**`plans/【調査】〜.md`を**planツールを使わず**Write/Editで作成する。 | エージェント |
| [] | 2-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 2-3 | MRで調査計画についてレビュー・コメントする。 | 人間 |
| [] | 2-4 | レビュー内容を取得し、調査計画を修正する。 | `comments` / `reply` |
| [] | 2-5 | 調査計画をもとにMR descriptionを更新する | `describe` |
| [] | 2-6 | **調査を実施**し、結果を個別調査計画・worklogに記録する。 | エージェント |
| [] | 2-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 2-8 | MRで調査結果についてレビュー・コメントする。 | 人間 |
| [] | 2-9 | レビュー内容を取得し、調査結果を修正する。 | `comments` / `reply` |
| [] | 2-10 | 調査結果をもとにMR descriptionを更新する | `describe` |
| [] | 3-1 | **調査結果をもとに**、個別作業計画`plans/【設計】【実装】〜.md`等を**planツールを使わず**Write/Editで作成する | エージェント |
| [] | 3-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 3-3 | MRで作業計画についてレビュー・コメントする。 | 人間 |
| [] | 3-4 | レビュー内容を取得し、作業計画を修正する。 | `comments` / `reply` |
| [] | 3-5 | 作業計画をもとにMR descriptionを更新する | `describe` |
| [] | 3-6 | 作業計画をもとに作業を進める、作業内容はworklogに更新する | エージェント |
| [] | 3-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 3-8 | MRでレビュー・コメントする。 | 人間 |
| [] | 3-9 | レビュー内容を取得し、実装・ドキュメントを修正する。 | `comments` / `reply` |
| [] | 3-10 | 作業内容をもとにMR descriptionを更新する | `describe` |
| [] | 4-1 | **作業結果と`plans/` `worklog/` の内容をもとに**、個別反映計画`plans/【設計反映】【AIアセット反映】〜.md`等を**planツールを使わず**Write/Editで作成する | エージェント |
| [] | 4-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 4-3 | MRで反映計画についてレビュー・コメントする。 | 人間 |
| [] | 4-4 | レビュー内容を取得し、反映計画を修正する。 | `comments` / `reply` |
| [] | 4-5 | 反映計画をもとにMR descriptionを更新する | `describe` |
| [] | 4-6 | 反映計画をもとに作業を進める、反映内容はworklogに更新する（**設計反映**: `plans/` `worklog/` の内容を `.claude/docs/spec/` `.claude/docs/ddr/`（アプリ本体があれば`docs/spec/` `docs/ddr/`）へ反映する／**AIアセット反映**: 作業中に気づいたルール・スキルの不備を `.claude/rules/` `.claude/skills/` `CLAUDE.md` `AGENTS.md` に反映する） | エージェント |
| [] | 4-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 4-8 | MRでレビュー・コメントする。 | 人間 |
| [] | 4-9 | レビュー内容を取得し、設計・AIアセットの内容を修正する。 | `comments` / `reply` |
| [] | 4-10 | 反映内容をもとにMR descriptionを更新する | `describe` |
| [] | 5-1 | 次タスクのために、`plans/` `worklog/` `reports/` を削除し、`HANDOFF.md` をリセットする | エージェント |
| [] | 5-2 | **defaultブランチとのコンフリクトを検知し、あれば解消する**（`check-base-conflicts.sh` → `resolve-conflict` スキル） | エージェント（`resolve-conflict` スキル） |
| [] | 5-3 | `commit`スキル経由でcommitし、リモートへ反映してDraftを解除する（解除は `set_mr_ready <MR番号>`） | エージェント |
| [] | 5-4 | マージする（squash merge。ブランチは削除してよい） | 人間 |

詳細についてはworklogを確認してください。

## やったこと

- **フェーズ1**: issue #92 を取得し（`gh` CLI不在のためMCP経路）、全体作業計画
  `plans/issue92-全体作業計画.md` を作成した。**このissueのルールを先取りし、調査（フェーズ2）・
  反映（フェーズ4）の節を最初から枠として置いてある**。Draft PRはハーネスがPR作成を制限する
  非対話的セッションのため作成していない（flow-id 1-3）。
- **フェーズ2〈調査〉**: `plans/【調査】全体作業計画へのフェーズ必須化の記載箇所を特定する.md`
  に計画と結果をまとめ、報告HTML
  `reports/20260819_issue92-全体作業計画_記載箇所と差し込み位置の調査.html` を作成した。
  差し込み位置は**SKILL.md の全体フロー表の直後**に決定。既存記述との矛盾（「フェーズ1,4,5は
  必ず実施する」）を1件検出した。
  - 非対話的セッションのため人間のレビュー往復（2-3/2-4・2-8/2-9）は実施できず、
    ループ範囲の進捗記号は `[]` のまま残している（`.claude/rules/docs-workflow.md`）。
  - 同じ理由で 2-1〈調査計画〉と 2-6〈調査実施〉の間にレビューを挟めないため、計画と結果を
    1ファイルにまとめている。

## 次にやること

- フェーズ3: `plans/【設計】【実装】〜.md` を作成し、`.claude/skills/issue-mr-flow/SKILL.md` と
  `.claude/rules/docs-workflow.md` を変更する。
- フェーズ4: 反映対象を洗い出し（spec・DDR 0040・README のDDR一覧の見込み）、反映する。
- フェーズ5: `plans/` `worklog/` `reports/` の削除、HANDOFF.mdのリセット、コンフリクト確認、
  リモートへの反映。

## 判断を迷った内容

（無し）

## 未解決の内容

（無し）

## 守るべき条件・触ってはいけない範囲

（無し）
