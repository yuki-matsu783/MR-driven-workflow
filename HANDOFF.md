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

- issue: #149 post-issue-create-notice.shの検知をコマンド位置ベースにして誤検知を減らす
- ブランチ: claude/post-issue-notice-detection-xleu14
- PR: https://github.com/yuki-matsu783/MR-driven-workflow/pull/179 (Draft)
- push回数: 3
- 現在のループ: なし
- 追従監視: 購読あり（web。subscribe_pr_activity + 1時間ごとの自己チェックイン）

| 進捗 | flow-id | ステップ | 担当 |
|---|---|---|---|
| [x] | 1-1 | issueを起票する | 人間（AIが代行する場合は `issue-create` スキル） |
| [x] | 1-2 | issueの内容を取得する | `start <issue番号>` |
| [x] | 1-3 | featureブランチとDraft MRを作成する | `start`（エージェント） |
| [x] | 1-4 | 全体作業計画を作成する | エージェント |
| [-] | 1-5 | 全体作業計画に合意する | 人間 |
| [x] | 1-6 | 全体作業計画をもとにHANDOFF.mdを更新する | エージェント |
| [-] | 2-1 | 個別調査計画を作成する | エージェント |
| [-] | 2-2 | commitし、pushしてレビュー依頼を行う | エージェント |
| [-] | 2-3 | MRで調査計画についてレビュー・コメントする | 人間 |
| [-] | 2-4 | レビュー内容を取得し、調査計画を修正する | `comments` / `reply` |
| [-] | 2-5 | 調査計画をもとにMR descriptionを更新する | `describe` |
| [-] | 2-6 | 調査を実施し、結果をreports/へ記録する | エージェント |
| [-] | 2-7 | commitし、pushしてレビュー依頼を行う | エージェント |
| [-] | 2-8 | MRで調査結果についてレビュー・コメントする | 人間 |
| [-] | 2-9 | レビュー内容を取得し、調査結果を修正する | `comments` / `reply` |
| [-] | 2-10 | 調査結果をもとにMR descriptionを更新する | `describe` |
| [x] | 3-1 | 個別作業計画を作成する | エージェント |
| [] | 3-2 | commitし、pushしてレビュー依頼を行う | エージェント |
| [] | 3-3 | MRで作業計画についてレビュー・コメントする | 人間 |
| [] | 3-4 | レビュー内容を取得し、作業計画を修正する | `comments` / `reply` |
| [] | 3-5 | 作業計画をもとにMR descriptionを更新する | `describe` |
| [] | 3-6 | 作業計画をもとに作業を進め、結果をreports/へ記録する | エージェント |
| [] | 3-7 | commitし、pushしてレビュー依頼を行う | エージェント |
| [] | 3-8 | MRでレビュー・コメントする | 人間 |
| [] | 3-9 | レビュー内容を取得し、実装・ドキュメントを修正する | `comments` / `reply` |
| [] | 3-10 | 作業内容をもとにMR descriptionを更新する | `describe` |
| [] | 4-1 | 個別反映計画を作成する（反映対象を洗い出す） | エージェント |
| [] | 4-2 | commitし、pushしてレビュー依頼を行う | エージェント |
| [] | 4-3 | MRで反映計画についてレビュー・コメントする | 人間 |
| [] | 4-4 | レビュー内容を取得し、反映計画を修正する | `comments` / `reply` |
| [] | 4-5 | 反映計画をもとにMR descriptionを更新する | `describe` |
| [] | 4-6 | 反映計画をもとに作業を進め、結果をreports/へ記録する | エージェント |
| [] | 4-7 | commitし、pushしてレビュー依頼を行う | エージェント |
| [] | 4-8 | MRでレビュー・コメントする | 人間 |
| [] | 4-9 | レビュー内容を取得し、設計・AIアセットの内容を修正する | `comments` / `reply` |
| [] | 4-10 | 反映内容をもとにMR descriptionを更新する | `describe` |
| [] | 5-1 | defaultブランチとのコンフリクトを検知・解消する | エージェント（`resolve-conflict` スキル） |
| [] | 5-2 | 関連issueへマージ前通知を行う | エージェント |
| [] | 5-3 | 最終統括レポートを作成し、PR/MRへ反映する | エージェント |
| [] | 5-4 | plans/worklog/reportsを削除しHANDOFF.mdをリセットする | エージェント |
| [] | 5-5 | commitし、pushしてDraftを解除する | エージェント |
| [] | 5-6 | マージする | 人間 |

## やったこと

- issue #149 の内容を取得し、標準4見出し（目的・現状・期待する動作・受け入れ条件）が揃っていることを確認した。
- ブランチ `claude/post-issue-notice-detection-xleu14` を origin へpushし、baseとの差分が無かったため
  `add_empty_commit_for_draft_mr` で空コミットしてから Draft PR #179 を作成した。
- PRイベントを購読した（`subscribe_pr_activity`）。
- 関連実装（`.claude/hooks/lib/CommandPosition.sh`, `block-direct-git-commit.sh`,
  `test_command_position.sh`, `test_post_issue_create_notice.sh`, `command-position.md`,
  `issue-mr-workflow.md`）を事前調査した。issue #147（block-direct-git-commit.shのコマンド位置化）が
  そのまま参考実装になることを確認した。
- 全体作業計画（`plans/post-issue-notice-command-position.md`/`.html`）を作成し、commit・pushした
  （flow-id 1-4/1-6）。**フェーズ2〈調査〉は実施しない**（事前調査で十分に方針を確定できたため。
  計画本文に理由を明記）。
- 非対話セッションのため、人間レビュー待ち（1-5・2-x）は進捗記号を動かさず進める
  （`.claude/rules/docs-workflow.md`「非対話的実行環境」の扱いに従う）。
- 敵対的レビューの実施回数カウンタ（`adversarial-review-count.sh`）はフェーズ2/3/4のみ対応で
  フェーズ1（全体作業計画）は対象外だったため、全体作業計画への敵対的レビューは行わず、
  フェーズ3の個別作業計画（実質的な設計内容）から敵対的レビューを開始する方針とした。

- flow-id 3-1: 個別作業計画（`plans/【設計】【実装】【テスト】post-issue-create-noticeコマンド位置判定化.md`/`.html`）を
  作成した。`command_invokes_script`（新規公開関数）の設計・3段ガードの置き換えイメージ・
  検証コマンドを記載した。
- 敵対的レビュー（フェーズ3・1回目/最大3回）をバックグラウンドで起動した
  （`adversarial-reviewer` サブエージェント。`adversarial-review-count.sh increment 3` 済み）。
  結果は次のpush以降で確認・反映する。

## 次にやること

- 敵対的レビュー（1回目）の指摘を確認し、必要なら計画を修正する。
- 計画に沿って実装（`CommandPosition.sh`・`post-issue-create-notice.sh`・テスト2本）を進める。

## 判断を迷った内容

（無し）

## 未解決の内容

（無し）

## 守るべき条件・触ってはいけない範囲

（無し）
