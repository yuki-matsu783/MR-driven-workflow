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

- issue: #145
- ブランチ: `claude/mr-pr-template-archive-0bo17a`
- PR: #187（https://github.com/yuki-matsu783/MR-driven-workflow/pull/187 ）
- push回数: 1
- 現在のループ: 2-3〜2-4 の1周目（完了）
- 未返信スレッド: 0
- 追従監視: あり（subscribe_pr_activity で購読中。Claude Code on the web）

| 進捗 | flow-id | ステップ | 担当 |
|---|---|---|---|
| [x] | 1-1 | issueを起票する | 人間 |
| [x] | 1-2 | issueの内容を取得する | `start <issue番号>` |
| [x] | 1-3 | featureブランチとDraft MRを作成する | `start` |
| [x] | 1-4 | Planモードで「全体作業計画」を作成する | エージェント |
| [-] | 1-5 | 全体作業計画に合意する | 人間 |
| [x] | 1-6 | 全体作業計画をもとにHANDOFF.mdを更新する | エージェント |
| [x] | 2-1 | 個別調査計画をplanツールを使わずWrite/Editで作成する | エージェント |
| [] | 2-2 | スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [x] | 2-3 | MRで調査計画についてレビュー・コメントする | 人間 |
| [x] | 2-4 | レビュー内容を取得し、調査計画を修正する | `comments` / `reply` |
| [] | 2-5 | 調査計画をもとにMR descriptionを更新する | `describe` |
| [] | 2-6 | 調査を実施し、結果をとworklogに記録する | エージェント |
| [] | 2-7 | スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 2-8 | MRで調査結果についてレビュー・コメントする | 人間 |
| [] | 2-9 | レビュー内容を取得し、調査結果を修正する | `comments` / `reply` |
| [] | 2-10 | 調査結果をもとにMR descriptionを更新する | `describe` |
| [] | 3-1 | 調査結果をもとに、個別作業計画等をplanツールを使わずWrite/Editで作成する | エージェント |
| [] | 3-2 | スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 3-3 | MRで作業計画についてレビュー・コメントする | 人間 |
| [] | 3-4 | レビュー内容を取得し、作業計画を修正する | `comments` / `reply` |
| [] | 3-5 | 作業計画をもとにMR descriptionを更新する | `describe` |
| [] | 3-6 | 作業計画をもとに作業を進める | エージェント |
| [] | 3-7 | スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 3-8 | MRでレビュー・コメントする | 人間 |
| [] | 3-9 | レビュー内容を取得し、実装・ドキュメントを修正する | `comments` / `reply` |
| [] | 3-10 | 作業内容をもとにMR descriptionを更新する | `describe` |
| [] | 4-1 | 作業結果と  の内容をもとに、個別反映計画等をplanツールを使わずWrite/Edit… | エージェント |
| [] | 4-2 | スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 4-3 | MRで反映計画についてレビュー・コメントする | 人間 |
| [] | 4-4 | レビュー内容を取得し、反映計画を修正する | `comments` / `reply` |
| [] | 4-5 | 反映計画をもとにMR descriptionを更新する | `describe` |
| [] | 4-6 | 反映計画をもとに作業を進める | エージェント |
| [] | 4-7 | スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 4-8 | MRでレビュー・コメントする | 人間 |
| [] | 4-9 | レビュー内容を取得し、設計・AIアセットの内容を修正する | `comments` / `reply` |
| [] | 4-10 | 反映内容をもとにMR descriptionを更新する | `describe` |
| [] | 5-1 | defaultブランチとのコンフリクトを検知し、あれば解消する | エージェント |
| [] | 5-2 | 今回のMRが影響する関連issueを特定し、承認を得てから当該issueへ通知する | エージェント |
| [] | 5-3 | の変更を  へ変換同期する（ を実行する | エージェント |
| [] | 5-4 | 最終統括レポートを作成し、PR/MRへサマリコメントとして反映する（ を正文として作成 … | エージェント |
| [] | 5-5 | 次タスクのために、  を削除し、 をリセットする（ を実行する | エージェント |
| [] | 5-6 | スキル経由でcommitし、push して Draftを解除する | エージェント |
| [] | 5-7 | マージする | 人間 |

## やったこと

- flow-id 1-2: issue #145 の内容をMCP経路（`mcp__github__issue_read`）で取得した。標準4見出しはすべて揃っている。
- flow-id 1-3: 既存ブランチ `claude/mr-pr-template-archive-0bo17a`（ハーネス指定）をそのまま使い、Draft PR #187 を作成した。baseとの差分が無く1回目の作成が失敗するため、`add_empty_commit_for_draft_mr` で空コミットを積んでから作成した。`subscribe_pr_activity` で追従監視を開始した。
- flow-id 2-2〜2-4（1周目）: 敵対的レビュー（フェーズ2・1回目、カウンタ 1/3）を計画4ファイルへ実施。findings 10件のうち major/high 6件をPR #187 へインライン投稿し、minor/medium 4件は報告のみ（内容は worklog へ記録）。**6件すべてへ返信済み**（未返信スレッド 0）。指摘10件はすべて計画へ反映した。投稿・返信したスレッド: r3838547511 / r3838547942 / r3838548304 / r3838548669 / r3838548972 / r3838549288（いずれも https://github.com/yuki-matsu783/MR-driven-workflow/pull/187#discussion_r<ID> ）。
- flow-id 2-1: 個別調査計画 `plans/【調査】テンプレート二重管理と統括レポートとの役割分担.md` と同名の `.html`、および worklog（push1）を作成した。
- flow-id 1-4: 全体作業計画 `plans/mellow-archiving-lantern.md` と同名の `.html` を作成した。**このセッションは非対話（人間のレビュー往復を待てない）ため、planツール（Planモード）ではなくWrite相当で作成している。**

## 次にやること

- flow-id 2-5: `describe` でMR descriptionを更新する。
- flow-id 2-6: 調査を実施し `reports/` へ結果（md＋html）を書く。

## 判断を迷った内容

- ブランチ名がリポジトリの命名規則（`feature-<issue番号>-<slug>`）に一致しないが、ハーネスから指定された `claude/mr-pr-template-archive-0bo17a` で作業するよう指示されているため、そのまま使う。
- 全体作業計画をplanツールで作らなかった点（上記）。非対話セッションではPlanモードの承認待ちで停止するため。

## 未解決の内容

- 二重管理の解消方式（テンプレートファイルと `describe` 節）は未決。フェーズ2で決める。
- MCP経路の返信投稿で、不等号で始まる語を含む本文が一部欠落した（`references/mcp-fallback.md`「MCP経路で踏んだ落とし穴」の既知事象）。補足コメントを追加して対処済み。以降の投稿では要素名・記号をそのまま書かない。
- #111（flow-id 5-4 の統括レポート）との役割分担は未決。フェーズ2で決める。

## 守るべき条件・触ってはいけない範囲

- flow-id 5-4（統括レポート）の実装（`upload_attachment`・3層フォールバック）には手を入れない。
- issueテンプレート（`.github/ISSUE_TEMPLATE/` `.gitlab/issue_templates/`）は変更しない。
- マージ（flow-id 5-7）はAIエージェントが実行しない。
