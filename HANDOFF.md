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

- issue: #176
- ブランチ: `claude/reflection-plan-criteria-tnhfvs`
- PR: #196（Draft・https://github.com/yuki-matsu783/MR-driven-workflow/pull/196 ）
- push回数: 2
- 現在のループ: なし
- 未返信スレッド: 0
- 追従監視: あり（PRイベント購読 + 定期チェックイン。Claude Code on the web セッション）

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
| [] | 2-6 | 調査を実施し、結果を記録する | エージェント |
| [] | 2-7 | commitし、pushしてレビュー依頼を行う | エージェント |
| [] | 2-8 | MRで調査結果についてレビュー・コメントする | 人間 |
| [] | 2-9 | レビュー内容を取得し、調査結果を修正する | `comments` / `reply` |
| [] | 2-10 | 調査結果をもとにMR descriptionを更新する | `describe` |
| [] | 3-1 | 個別作業計画を作成する | エージェント |
| [] | 3-2 | commitし、pushしてレビュー依頼を行う | エージェント |
| [] | 3-3 | MRで作業計画についてレビュー・コメントする | 人間 |
| [] | 3-4 | レビュー内容を取得し、作業計画を修正する | `comments` / `reply` |
| [] | 3-5 | 作業計画をもとにMR descriptionを更新する | `describe` |
| [] | 3-6 | 作業計画をもとに作業を進める | エージェント |
| [] | 3-7 | commitし、pushしてレビュー依頼を行う | エージェント |
| [] | 3-8 | MRでレビュー・コメントする | 人間 |
| [] | 3-9 | レビュー内容を取得し、実装・ドキュメントを修正する | `comments` / `reply` |
| [] | 3-10 | 作業内容をもとにMR descriptionを更新する | `describe` |
| [] | 4-1 | 個別反映計画を作成する | エージェント |
| [] | 4-2 | commitし、pushしてレビュー依頼を行う | エージェント |
| [] | 4-3 | MRで反映計画についてレビュー・コメントする | 人間 |
| [] | 4-4 | レビュー内容を取得し、反映計画を修正する | `comments` / `reply` |
| [] | 4-5 | 反映計画をもとにMR descriptionを更新する | `describe` |
| [] | 4-6 | 反映計画をもとに作業を進める | エージェント |
| [] | 4-7 | commitし、pushしてレビュー依頼を行う | エージェント |
| [] | 4-8 | MRでレビュー・コメントする | 人間 |
| [] | 4-9 | レビュー内容を取得し、設計・AIアセットの内容を修正する | `comments` / `reply` |
| [] | 4-10 | 反映内容をもとにMR descriptionを更新する | `describe` |
| [] | 5-1 | defaultブランチとのコンフリクトを検知し、あれば解消する | エージェント |
| [] | 5-2 | 関連issueへマージ前通知を行う | エージェント |
| [] | 5-3 | `.claude/` の変更を `.gemini/` へ変換同期する | エージェント |
| [] | 5-4 | 最終統括レポートを作成しPR/MRへ反映する | エージェント |
| [] | 5-5 | 次タスクのための片付けとHANDOFF.mdリセット | エージェント |
| [] | 5-6 | commitし、pushしてDraftを解除する | エージェント |
| [] | 5-7 | マージする | 人間 |

## やったこと

- flow-id 1-2: issue #176 の本文とコメント1件（issue #155 / PR #175 からの前提変更通知）を取得した。
- flow-id 1-3: ブランチ `claude/reflection-plan-criteria-tnhfvs` をリモートへ反映し、Draft PR #196 を作成した。PRイベントの購読を開始した。
- flow-id 1-4: 全体作業計画 `wip/plans/reflection-split-criteria.md`（＋同名 `.html`）を作成した。フェーズ2〈調査〉・フェーズ4〈反映〉の節を含む。
- flow-id 1-6: 本ファイルへ進捗表・ヘッダを記入した。
- flow-id 2-1: 個別調査計画 `wip/plans/【調査】反映対象の切り出し判断基準.md`（＋`.html`）と worklog `wip/worklogs/20260823_reflection-split-criteria_【調査】反映対象の切り出し判断基準_push2.md` を作成した。調べる問いは6問。

## 次にやること

- flow-id 2-2: commit・pushしてレビュー依頼を行い、`adversarial-review` スキルでフェーズ2の計画に対する敵対的レビューを1回実施する（ユーザー指示による自動起動）。
- flow-id 2-6: 6問の調査を実施し、結果を `wip/reports/2026-08-23_reflection-split-criteria_調査結果.md`（＋`.html`）へ書く。

## 判断を迷った内容

- **flow-id 1-5（人間による全体作業計画の合意）は非対話セッションのため成立しない。** 進捗記号は `[]` のまま残し、代わりに敵対的レビューでレビューの空白を埋める（`.claude/rules/docs-workflow.md`「非対話的実行環境」）。
- **受け入れ条件の「SKILL.md に節がある」の解釈。** issue #160 で SKILL.md の詳細節は `references/` 配下へ切り出されているため、そのまま SKILL.md 本体へ書くと構造に反する。フェーズ2の問い1で結論を出す。

## 未解決の内容

（無し）

## 守るべき条件・触ってはいけない範囲

- ブランチは `claude/reflection-plan-criteria-tnhfvs` 固定（ハーネス指定。`.mrworkflow.json` の
  `feature-<issue番号>-<slug>` 規則とは異なるが、ハーネス側の指定を優先する）。
- DDR本文・spec内の過去changelog（point-in-time の記録）は書き換えない。
