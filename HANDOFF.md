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

- issue: #33 配布テンプレートとして不足している資産（PR/MRテンプレート・LICENSE・.gitattributes・版管理）を整備する
- ブランチ: claude/distribution-template-assets-oi4uai
- PR: #136 (Draft) https://github.com/yuki-matsu783/MR-driven-workflow/pull/136
- push回数: 5
- 現在のループ: 3-6〜3-9 の1周目（進行中・人間レビュー未実施）
- 追従監視: 購読あり（subscribe_pr_activity で PR #136 を購読。セッション終了で止まるため、次セッションは resume で取り直す）

## フロー進捗状況

| 進捗 | flow-id | ステップ | 担当 |
|----|---|---|---|
| [x] | 1-1 | issueを起票する（`.github/ISSUE_TEMPLATE/task.md` / `.gitlab/issue_templates/Default.md` で目的・現状・期待する動作・受け入れ条件を記載） | 人間（AIが代行する場合は `issue-create` スキル） |
| [x] | 1-2 | issueの内容を取得する | `start <issue番号>` |
| [x] | 1-3 | featureブランチ（`feature-<issue番号>-<slug>`）とDraft MRを作成する（既にあれば `sync` のみ） | `start`（エージェント） |
| [x] | 1-4 | Planモードで「全体作業計画」を作成する | エージェント |
| [] | 1-5 | 全体作業計画に合意する | 人間 |
| [x] | 1-6 | 全体作業計画をもとにHANDOFF.mdを更新する | エージェント |
| [x] | 2-1 | 個別調査計画`plans/【調査】〜.md`をplanツールを使わずWrite/Editで作成する | エージェント |
| [x] | 2-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 2-3 | MRで調査計画についてレビュー・コメントする | 人間 |
| [] | 2-4 | レビュー内容を取得し、調査計画を修正する | `comments` / `reply` |
| [x] | 2-5 | 調査計画をもとにMR descriptionを更新する | `describe` |
| [] | 2-6 | 調査を実施し、結果を`reports/日付_<全体計画名>_<内容を簡潔に>.md`とworklogに記録する | エージェント |
| [] | 2-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 2-8 | MRで調査結果についてレビュー・コメントする | 人間 |
| [] | 2-9 | レビュー内容を取得し、調査結果を修正する | `comments` / `reply` |
| [x] | 2-10 | 調査結果をもとにMR descriptionを更新する | `describe` |
| [x] | 3-1 | 調査結果をもとに、個別作業計画`plans/【設計】【実装】〜.md`等をplanツールを使わずWrite/Editで作成する | エージェント |
| [x] | 3-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 3-3 | MRで作業計画についてレビュー・コメントする | 人間 |
| [] | 3-4 | レビュー内容を取得し、作業計画を修正する | `comments` / `reply` |
| [x] | 3-5 | 作業計画をもとにMR descriptionを更新する | `describe` |
| [] | 3-6 | 作業計画をもとに作業を進める | エージェント |
| [] | 3-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 3-8 | MRでレビュー・コメントする | 人間 |
| [] | 3-9 | レビュー内容を取得し、実装・ドキュメントを修正する | `comments` / `reply` |
| [x] | 3-10 | 作業内容をもとにMR descriptionを更新する | `describe` |
| [x] | 4-1 | 作業結果と`plans/` `worklog/` の内容をもとに、個別反映計画`plans/【設計反映】【AIアセット反映】〜.md`等をplanツールを使わずWrite/Editで作成する | エージェント |
| [] | 4-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 4-3 | MRで反映計画についてレビュー・コメントする | 人間 |
| [] | 4-4 | レビュー内容を取得し、反映計画を修正する | `comments` / `reply` |
| [] | 4-5 | 反映計画をもとにMR descriptionを更新する | `describe` |
| [] | 4-6 | 反映計画をもとに作業を進める | エージェント |
| [] | 4-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 4-8 | MRでレビュー・コメントする | 人間 |
| [] | 4-9 | レビュー内容を取得し、設計・AIアセットの内容を修正する | `comments` / `reply` |
| [] | 4-10 | 反映内容をもとにMR descriptionを更新する | `describe` |
| [] | 5-1 | defaultブランチとのコンフリクトを検知し、あれば解消する | エージェント（`resolve-conflict` スキル） |
| [] | 5-2 | 今回のMRが影響する関連issueを特定し、承認を得てから当該issueへ通知する（差分からキーワードを抽出 → `search_issues` で候補提示 → `AskUserQuestion` で対象issueとコメント本文の承認 → `add_issue_comment` で投稿） | エージェント |
| [] | 5-3 | 次タスクのために、`plans/` `worklog/` `reports/` を削除しHANDOFF.mdをリセットする | エージェント |
| [] | 5-4 | `commit`スキル経由でcommitし、push して Draftを解除する | エージェント |
| [] | 5-5 | マージする | 人間 |

## やったこと

- flow-id 1-2: issue #33 の内容をMCP（`mcp__github__issue_read`）で取得した（この実行環境には
  `gh` CLIが無いため、`.claude/skills/issue-mr-flow/SKILL.md`「`gh`/`glab` CLI不在時のMCP
  フォールバック」に従いMCP経路を使用）。
- flow-id 1-4: 全体作業計画 `plans/配布テンプレート資産の整備.md` を作成した（Planモードを
  既に抜けた状態で開始したため、planツールではなくWrite/Editで作成した。命名は
  `【` で始まらない＝全体作業計画として識別できる形にしている）。
- ユーザー判断: LICENSEの種別は「なし」（＝LICENSEファイルを追加しない）、版管理は
  「VERSIONファイルのみ採用（CHANGELOGなし）」に確定した。

## 次にやること

- flow-id 2-1: 個別調査計画 `plans/【調査】配布経路と既存資産の棚卸し.md` を作成する。

## 判断を迷った内容

- 受け入れ条件の「LICENSE ファイルが追加される」は、ユーザーが種別「なし」を選択したため
  **意図的に満たさない**扱いとする。判断と影響（明示的な許諾が無い状態になること）はDDRへ残す。

## 未解決の内容

- issue #26（配布方式のmanifest化）は未着手。本issueで追加する資産が、#26の層分け
  （core/seed/merge/local）のどこに属するかは本issueでは決めず、#26側で決める。

## 守るべき条件・触ってはいけない範囲

- ブランチはハーネス指定の `claude/distribution-template-assets-oi4uai` を使う
  （`.mrworkflow.json` の `feature-{issue}-{slug}` 規則とは異なるが、ハーネス指定が優先）。
- マージ（flow-id 5-5）は行わない。Draft解除（5-4）で止まる。
- DDRの本文は追記のみ。既存DDRの本文を書き換えない。
