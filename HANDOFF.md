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

- issue: #205（https://github.com/yuki-matsu783/MR-driven-workflow/issues/205 ）
- ブランチ: claude/pr-mr-diffview-link-yxim1l
- PR: #206（https://github.com/yuki-matsu783/MR-driven-workflow/pull/206 ）
- push回数: 1
- 現在のループ: なし
- 未返信スレッド: 0
- 追従監視: あり（subscribe_pr_activity で PR #206 を購読中。セッション終了で止まるため次セッションは resume で取り直す）

| 進捗 | flow-id | ステップ | 担当 |
|---|---|---|---|
| [x] | 1-1 | issueを起票する | 人間 |
| [x] | 1-2 | issueの内容を取得する | `start` |
| [x] | 1-3 | featureブランチとDraft MRを作成する | `start`（エージェント） |
| [x] | 1-4 | 全体作業計画を作成する | エージェント |
| [] | 1-5 | 全体作業計画に合意する | 人間 |
| [x] | 1-6 | 全体作業計画をもとにHANDOFF.mdを更新する | エージェント |
| [x] | 2-1 | 個別調査計画を作成する | エージェント |
| [] | 2-2 | commitし、pushしてレビュー依頼を行う | エージェント |
| [] | 2-3 | MRで調査計画についてレビュー・コメントする | 人間 |
| [] | 2-4 | レビュー内容を取得し、調査計画を修正する | `comments` / `reply` |
| [] | 2-5 | 調査計画をもとにMR descriptionを更新する | `describe` |
| [] | 2-6 | 調査を実施し、結果をwip/reports/へ記録する | エージェント |
| [] | 2-7 | commitし、pushしてレビュー依頼を行う | エージェント |
| [] | 2-8 | MRで調査結果についてレビュー・コメントする | 人間 |
| [] | 2-9 | レビュー内容を取得し、調査結果を修正する | `comments` / `reply` |
| [] | 2-10 | 調査結果をもとにMR descriptionを更新する | `describe` |
| [] | 3-1 | 個別作業計画を作成する | エージェント |
| [] | 3-2 | commitし、pushしてレビュー依頼を行う | エージェント |
| [] | 3-3 | MRで作業計画についてレビュー・コメントする | 人間 |
| [] | 3-4 | レビュー内容を取得し、作業計画を修正する | `comments` / `reply` |
| [] | 3-5 | 作業計画をもとにMR descriptionを更新する | `describe` |
| [] | 3-6 | 作業を進め、結果をwip/reports/へ記録する | エージェント |
| [] | 3-7 | commitし、pushしてレビュー依頼を行う | エージェント |
| [] | 3-8 | MRでレビュー・コメントする | 人間 |
| [] | 3-9 | レビュー内容を取得し、実装・ドキュメントを修正する | `comments` / `reply` |
| [] | 3-10 | 作業内容をもとにMR descriptionを更新する | `describe` |
| [] | 4-1 | 個別反映計画を作成する（反映対象の洗い出し） | エージェント |
| [] | 4-2 | commitし、pushしてレビュー依頼を行う | エージェント |
| [] | 4-3 | MRで反映計画についてレビュー・コメントする | 人間 |
| [] | 4-4 | レビュー内容を取得し、反映計画を修正する | `comments` / `reply` |
| [] | 4-5 | 反映計画をもとにMR descriptionを更新する | `describe` |
| [] | 4-6 | 反映を進め、結果をwip/reports/へ記録する | エージェント |
| [] | 4-7 | commitし、pushしてレビュー依頼を行う | エージェント |
| [] | 4-8 | MRでレビュー・コメントする | 人間 |
| [] | 4-9 | レビュー内容を取得し、設計・AIアセットを修正する | `comments` / `reply` |
| [] | 4-10 | 反映内容をもとにMR descriptionを更新する | `describe` |
| [] | 5-1 | defaultブランチとのコンフリクトを検知・解消する | エージェント |
| [] | 5-2 | 関連issueへマージ前通知を行う | エージェント |
| [] | 5-3 | `.claude/` の変更を `.gemini/` へ変換同期する | エージェント |
| [] | 5-4 | 最終統括レポートを作成しPR/MRへ反映する | エージェント |
| [] | 5-5 | wip/配下を片付け、HANDOFF.mdをリセットする | エージェント |
| [] | 5-6 | commitし、pushしてDraftを解除する | エージェント |
| [] | 5-7 | マージする | 人間 |

## やったこと

- flow-id 1-1/1-2: issue #205 の内容を MCP（`mcp__github__issue_read`）で取得した。
  この実行環境には `gh`/`glab` CLI が無く、`get_vcs_access_mode` は `mcp` を返す。
- flow-id 1-4: 全体作業計画 `wip/plans/diffview-link-switchover.md` と同名の `.html` を作成した。
- flow-id 1-3: Draft PR #206 を `mcp__github__create_pull_request` で作成し、
  `subscribe_pr_activity` で追従監視を開始した。
- flow-id 2-1: 個別調査計画 `wip/plans/【調査】Diffviewリンクの出し分けとMCP経路での解決手段.md`
  （+ `.html`）と worklog を作成した。調査項目は Q1〜Q6。
- **push直後のhookが本issueの問題をそのまま再現した**（「defaultブランチとの差分」が
  Compareページ、MRリンクは「CLI不在のため未取得」）。問題の実在を実測で確認できた。

## 次にやること

- flow-id 2-2 の直後に、個別調査計画に対する敵対的レビュー（フェーズ2の1回目）を実行する。
- flow-id 2-6: Q1〜Q6の調査を実施し、`wip/reports/` へ結果を記録する。

## 判断を迷った内容

- **ブランチ名がこのリポジトリの命名規則（`feature-<issue番号>-<slug>`）に一致しない。**
  ハーネス（実行基盤）が `claude/pr-mr-diffview-link-yxim1l` を指定しており、
  「NEVER push to a different branch without explicit permission」という制約があるため、
  ハーネス側の指定に従った。`.claude/rules/git-workflow.md` の命名規則からは外れる。
- **全体作業計画をplanツール（Planモード）で作らなかった。** このリモート実行環境では
  Planモードの承認をユーザーから受け取れず、承認待ちでセッションが停止するため、
  Write で直接作成した。ファイル名もハーネスの自動命名が無いため手で付けた。

## 未解決の内容

- MCP経路（CLI不在）でMR/PR URLをhookからどう解決するか（フェーズ2の調査対象）。

## 守るべき条件・触ってはいけない範囲

- **push先は `claude/pr-mr-diffview-link-yxim1l` のみ。** 他ブランチへpushしない。
- **マージ（flow-id 5-7）は行わない。** ユーザーの明示指示があるまで flow-id 5-6 で止まる。
- **`.gemini/` を直接編集しない**（`.claude/` からの生成物。flow-id 5-3 で再生成する）。
- 非対話セッションのため、人間のレビュー往復（2-3/2-4 等）は成立しない。ループ範囲の進捗記号は
  `[]` のまま残し、実施した内容は「やったこと」へ文章で補足する
  （`.claude/rules/docs-workflow.md` 末尾の規定）。
