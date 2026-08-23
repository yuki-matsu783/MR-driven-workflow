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

- issue: #27 他プロジェクトで改善されたAIアセットを本家へ収穫（逆輸入）するスキルを新設する
- ブランチ: claude/ai-asset-reverse-import-skill-g4qa9s
- PR: #189 https://github.com/yuki-matsu783/MR-driven-workflow/pull/189（Draft）
- push回数: 3
- 現在のループ: なし
- 未返信スレッド: 7
- 追従監視: なし

| 進捗 | flow-id | ステップ | 担当 |
|---|---|---|---|
| [x] | 1-1 | issueを起票する | 人間 |
| [x] | 1-2 | issueの内容を取得する | サブコマンド |
| [x] | 1-3 | featureブランチとDraft MRを作成する | エージェント |
| [x] | 1-4 | 全体作業計画を作成する | エージェント |
| [] | 1-5 | 全体作業計画に合意する | 人間 |
| [x] | 1-6 | HANDOFF.mdを更新する | エージェント |
| [x] | 2-1 | 個別調査計画を作成する | エージェント |
| [] | 2-2 | commitしpushしてレビュー依頼 | エージェント |
| [] | 2-3 | 調査計画をレビューする | 人間 |
| [] | 2-4 | レビューを反映する | サブコマンド |
| [] | 2-5 | MR descriptionを更新する | サブコマンド |
| [] | 2-6 | 調査を実施しreportsへ記録する | エージェント |
| [] | 2-7 | commitしpushしてレビュー依頼 | エージェント |
| [] | 2-8 | 調査結果をレビューする | 人間 |
| [] | 2-9 | レビューを反映する | サブコマンド |
| [] | 2-10 | MR descriptionを更新する | サブコマンド |
| [] | 3-1 | 個別作業計画を作成する | エージェント |
| [] | 3-2 | commitしpushしてレビュー依頼 | エージェント |
| [] | 3-3 | 作業計画をレビューする | 人間 |
| [] | 3-4 | レビューを反映する | サブコマンド |
| [] | 3-5 | MR descriptionを更新する | サブコマンド |
| [] | 3-6 | 作業を実施しreportsへ記録する | エージェント |
| [] | 3-7 | commitしpushしてレビュー依頼 | エージェント |
| [] | 3-8 | レビューする | 人間 |
| [] | 3-9 | レビューを反映する | サブコマンド |
| [] | 3-10 | MR descriptionを更新する | サブコマンド |
| [] | 4-1 | 個別反映計画を作成する（反映対象の洗い出し） | エージェント |
| [] | 4-2 | commitしpushしてレビュー依頼 | エージェント |
| [] | 4-3 | 反映計画をレビューする | 人間 |
| [] | 4-4 | レビューを反映する | サブコマンド |
| [] | 4-5 | MR descriptionを更新する | サブコマンド |
| [] | 4-6 | 反映を実施しreportsへ記録する | エージェント |
| [] | 4-7 | commitしpushしてレビュー依頼 | エージェント |
| [] | 4-8 | レビューする | 人間 |
| [] | 4-9 | レビューを反映する | サブコマンド |
| [] | 4-10 | MR descriptionを更新する | サブコマンド |
| [] | 5-1 | defaultブランチとのコンフリクトを検知・解消する | エージェント |
| [] | 5-2 | 関連issueへ通知する | エージェント |
| [] | 5-3 | .claude/の変更を.gemini/へ変換同期する | エージェント |
| [] | 5-4 | 最終統括レポートを作成しPRへ反映する | エージェント |
| [] | 5-5 | plans/worklog/reportsを削除しHANDOFF.mdをリセットする | エージェント |
| [] | 5-6 | commitしpushしてDraftを解除する | エージェント |
| [] | 5-7 | マージする | 人間 |

## やったこと

- flow-id 1-2〜1-3: issue #27 の内容を取得し、ブランチ
  `claude/ai-asset-reverse-import-skill-g4qa9s`（ハーネス指定名）をpush、Draft PR #189 を作成した
  （ユーザーから「PR作って進めて」の明示指示あり）。
- flow-id 1-4: 全体作業計画 `plans/quiet-orchard-harvest.md`（＋同名.html）を作成した。
- 非対話セッションのため、flow-id 1-5（人間の合意）は待たずに進む（ユーザーの当初指示
  「PRを作って進めて。各フェーズ計画時と作業実施毎に敵対的レビューを自動実施」に基づく）。
  記号は `[]` のまま残す。
- flow-id 2-1: 個別調査計画 `plans/【調査】収穫スキルの前提調査.md`（＋.html）と
  worklog（push1）を作成した。
- flow-id 2-2直後: 敵対的レビュー1回目（フェーズ2・対象=調査計画）を実施。findings 8件の
  うち7件をインライン投稿（下記URL）、1件（変更対象の「のみ」表現・minor/medium）は
  報告のみ。修正は8件すべて反映した（計画へ前提・方針・Q8・検証コマンドを追加）。
  - https://github.com/yuki-matsu783/MR-driven-workflow/pull/189#discussion_r3838553264 （前提合意の明記）
  - https://github.com/yuki-matsu783/MR-driven-workflow/pull/189#discussion_r3838553759 （-dirty SHA）
  - https://github.com/yuki-matsu783/MR-driven-workflow/pull/189#discussion_r3838554061 （検証コマンド）
  - https://github.com/yuki-matsu783/MR-driven-workflow/pull/189#discussion_r3838554457 （added/deleted Q8）
  - https://github.com/yuki-matsu783/MR-driven-workflow/pull/189#discussion_r3838554718 （LF正規化の粒度差）
  - https://github.com/yuki-matsu783/MR-driven-workflow/pull/189#discussion_r3838554982 （HTML要約で情報欠落）
  - https://github.com/yuki-matsu783/MR-driven-workflow/pull/189#discussion_r3838555266 （方針節の欠落）
- flow-id 2-6: 調査を実施し `reports/2026-08-23_quiet-orchard-harvest_調査結果.md`（＋.html）へ
  Q1〜Q8 の回答と実行検証の記録を書いた。

## 次にやること

- 7スレッドへ対応内容を返信（返信後 `set-header --unreplied 0`）→ describe で
  MR description 更新 → 敵対的レビュー2回目（対象=調査結果レポート）→ 指摘反映 →
  フェーズ3（個別作業計画）へ。

## 判断を迷った内容

- ブランチ名がリポジトリ命名規則 `feature-27-<slug>` ではなくハーネス指定の
  `claude/ai-asset-reverse-import-skill-g4qa9s` である（ハーネスの指示が優先。別ブランチへの
  push は禁止されているためこのまま進める）。

## 未解決の内容

（無し）

## 守るべき条件・触ってはいけない範囲

- 収穫スキルは本家の `.claude/rules/` `.claude/skills/` `.claude/docs/` を直接書き換えない
  設計にする（issue #27 受け入れ条件）。
- マージ（flow-id 5-7）はユーザーの明示指示があるまで実行しない。
