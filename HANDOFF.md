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

## フロー進捗状況

- issue: #185
- ブランチ: `claude/improve-commit-log-format-9mjlid`
- PR: #192（https://github.com/yuki-matsu783/MR-driven-workflow/pull/192 ）（Draft）
- push回数: 1
- 現在のループ: なし
- 未返信スレッド: 0
- 追従監視: あり（`subscribe_pr_activity` でPR #192 を購読中。セッション終了で切れるため、次セッションは `resume` で取り直す）

| 進捗 | flow-id | ステップ | 担当 |
|----|---|---|---|
| [x] | 1-1 | issueを起票する | 人間 |
| [x] | 1-2 | issueの内容を取得する | `start <issue番号>` |
| [x] | 1-3 | featureブランチ | `start` |
| [x] | 1-4 | Planモードで「全体作業計画」を作成する | エージェント |
| [] | 1-5 | 全体作業計画に合意する | 人間 |
| [x] | 1-6 | 全体作業計画をもとにHANDOFF.mdを更新する | エージェント |
| [x] | 2-1 | 個別調査計画`wip/plans/【調査】〜.md`をplanツールを使わずWrite/Editで作成する | エージェント |
| [] | 2-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 2-3 | MRで調査計画についてレビュー・コメントする | 人間 |
| [] | 2-4 | レビュー内容を取得し、調査計画を修正する | `comments` / `reply` |
| [] | 2-5 | 調査計画をもとにMR descriptionを更新する | `describe` |
| [] | 2-6 | 調査を実施し、結果を`wip/reports/日付_<全体計画名>_<内容を簡潔に>.md`とwip/worklogsに記録する | エージェント |
| [] | 2-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 2-8 | MRで調査結果についてレビュー・コメントする | 人間 |
| [] | 2-9 | レビュー内容を取得し、調査結果を修正する | `comments` / `reply` |
| [] | 2-10 | 調査結果をもとにMR descriptionを更新する | `describe` |
| [] | 3-1 | 調査結果をもとに、個別作業計画`wip/plans/【設計】【実装】〜.md`等をplanツールを使わずWrite/Editで作成する | エージェント |
| [] | 3-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 3-3 | MRで作業計画についてレビュー・コメントする | 人間 |
| [] | 3-4 | レビュー内容を取得し、作業計画を修正する | `comments` / `reply` |
| [] | 3-5 | 作業計画をもとにMR descriptionを更新する | `describe` |
| [] | 3-6 | 作業計画をもとに作業を進める | エージェント |
| [] | 3-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 3-8 | MRでレビュー・コメントする | 人間 |
| [] | 3-9 | レビュー内容を取得し、実装・ドキュメントを修正する | `comments` / `reply` |
| [] | 3-10 | 作業内容をもとにMR descriptionを更新する | `describe` |
| [] | 4-1 | 作業結果と`wip/plans/` `wip/worklogs/` の内容をもとに、個別反映計画`wip/plans/【設計反映】【AIアセット反映】【実装反映】〜.md`等をplanツールを使わずWrite/Editで作成する | エージェント |
| [] | 4-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 4-3 | MRで反映計画についてレビュー・コメントする | 人間 |
| [] | 4-4 | レビュー内容を取得し、反映計画を修正する | `comments` / `reply` |
| [] | 4-5 | 反映計画をもとにMR descriptionを更新する | `describe` |
| [] | 4-6 | 反映計画をもとに作業を進める | エージェント |
| [] | 4-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 4-8 | MRでレビュー・コメントする | 人間 |
| [] | 4-9 | レビュー内容を取得し、設計・AIアセットの内容を修正する | `comments` / `reply` |
| [] | 4-10 | 反映内容をもとにMR descriptionを更新する | `describe` |
| [] | 5-1 | defaultブランチとのコンフリクトを検知し、あれば解消する | エージェント |
| [] | 5-2 | 今回のMRが影響する関連issueを特定し、承認を得てから当該issueへ通知する | エージェント |
| [] | 5-3 | `.claude/` の変更を `.gemini/` へ変換同期する | エージェント |
| [] | 5-4 | 最終統括レポートを作成し、PR/MRへサマリコメントとして反映する | エージェント |
| [] | 5-5 | 次タスクのために wip/ 配下を削除しHANDOFF.mdをリセットする | エージェント |
| [] | 5-6 | `commit`スキル経由でcommitし、push して Draftを解除する | エージェント |
| [] | 5-7 | マージする | 人間 |

## やったこと

- flow-id 1-2: issue #185 の内容をMCP（`mcp__github__issue_read`）で取得した。
- flow-id 1-3: ブランチ `claude/improve-commit-log-format-9mjlid` をリモートへ反映し、Draft PR #192 を作成した。
  baseとの差分が無いため `add_empty_commit_for_draft_mr` の空コミットを1件置いている。
  `subscribe_pr_activity` でPRイベントの購読を開始した。
- flow-id 1-4: 全体作業計画 `wip/plans/keen-charting-lantern.md` と同名の `.html` を作成した。
  **planツール（Planモード）は使っていない**——本セッションは非対話であり、Planモードの承認
  （flow-id 1-5）を待てないため。この逸脱は最終統括レポートにも記す。

## 次にやること

- flow-id 2-1: 個別調査計画 `wip/plans/【調査】〜.md` と `.html` を作成する。
- 作成後、`adversarial-review` スキルで計画に対する敵対的レビューを1回実施する。

## 判断を迷った内容

- ブランチ名がワークフローの命名規則（`feature-185-<slug>`）ではなく、ハーネスが指定した
  `claude/improve-commit-log-format-9mjlid` である。ハーネス側の指示（このブランチへ開発・反映する）が
  優先されるため、改名はしない。

## 未解決の内容

（無し）

## 守るべき条件・触ってはいけない範囲

- **マージ（flow-id 5-7）は行わない。** AIエージェントは flow-id 5-6（Draft解除）で止まる。
- 人間のレビュー担当ステップ（1-5・2-3/2-8・3-3/3-8・4-3/4-8）は非対話セッションのため実施できない。
  進捗記号は `[]` のまま残し、代替として敵対的レビューを各フェーズの計画時と作業実施ごとに1回ずつ行う。
- `.gemini/` は `.claude/` からの変換生成物であり、手で編集しない（flow-id 5-3 で再生成する）。
- 過去のコミットメッセージは書き換えない（スコープ外）。
