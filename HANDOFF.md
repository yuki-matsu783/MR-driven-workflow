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

- issue: #142
- ブランチ: `claude/docs-workflow-heading-rule-mi3krb`
- PR: #188（Draft, https://github.com/yuki-matsu783/MR-driven-workflow/pull/188 ）
- push回数: 3
- 現在のループ: 2-3〜2-4 の1周目（完了）
- 未返信スレッド: 0
- 追従監視: あり（`subscribe_pr_activity` でPR #188 を購読中。セッション終了で止まるため、次セッションは `resume` で取り直す）

| 進捗 | flow-id | ステップ | 担当 |
|---|---|---|---|
| [x] | 1-1 | issueを起票する | 人間 |
| [x] | 1-2 | issueの内容を取得する | サブコマンド |
| [x] | 1-3 | featureブランチとDraft MRを作成する | サブコマンド/エージェント |
| [x] | 1-4 | 全体作業計画を作成する | エージェント |
| [-] | 1-5 | 全体作業計画に合意する | 人間 |
| [x] | 1-6 | 全体作業計画をもとにHANDOFF.mdを更新する | エージェント |
| [x] | 2-1 | 個別調査計画を作成する | エージェント |
| [x] | 2-2 | commitしpushしてレビュー依頼 | エージェント |
| [x] | 2-3 | 調査計画をレビュー・コメント | 人間 |
| [x] | 2-4 | レビュー内容を取得し調査計画を修正 | サブコマンド |
| [] | 2-5 | 調査計画をもとにMR descriptionを更新 | サブコマンド |
| [] | 2-6 | 調査を実施しreportsへ記録 | エージェント |
| [] | 2-7 | commitしpushしてレビュー依頼 | エージェント |
| [] | 2-8 | 調査結果をレビュー・コメント | 人間 |
| [] | 2-9 | レビュー内容を取得し調査結果を修正 | サブコマンド |
| [] | 2-10 | 調査結果をもとにMR descriptionを更新 | サブコマンド |
| [] | 3-1 | 個別作業計画を作成する | エージェント |
| [] | 3-2 | commitしpushしてレビュー依頼 | エージェント |
| [] | 3-3 | 作業計画をレビュー・コメント | 人間 |
| [] | 3-4 | レビュー内容を取得し作業計画を修正 | サブコマンド |
| [] | 3-5 | 作業計画をもとにMR descriptionを更新 | サブコマンド |
| [] | 3-6 | 作業を進めreportsへ記録 | エージェント |
| [] | 3-7 | commitしpushしてレビュー依頼 | エージェント |
| [] | 3-8 | レビュー・コメント | 人間 |
| [] | 3-9 | レビュー内容を取得し修正 | サブコマンド |
| [] | 3-10 | 作業内容をもとにMR descriptionを更新 | サブコマンド |
| [] | 4-1 | 個別反映計画を作成する | エージェント |
| [] | 4-2 | commitしpushしてレビュー依頼 | エージェント |
| [] | 4-3 | 反映計画をレビュー・コメント | 人間 |
| [] | 4-4 | レビュー内容を取得し反映計画を修正 | サブコマンド |
| [] | 4-5 | 反映計画をもとにMR descriptionを更新 | サブコマンド |
| [] | 4-6 | 反映作業を進めreportsへ記録 | エージェント |
| [] | 4-7 | commitしpushしてレビュー依頼 | エージェント |
| [] | 4-8 | レビュー・コメント | 人間 |
| [] | 4-9 | レビュー内容を取得し修正 | サブコマンド |
| [] | 4-10 | 反映内容をもとにMR descriptionを更新 | サブコマンド |
| [] | 5-1 | defaultブランチとのコンフリクト検知・解消 | エージェント |
| [] | 5-2 | 関連issueへのマージ前通知 | エージェント |
| [] | 5-3 | `.claude/` を `.gemini/` へ変換同期 | エージェント |
| [] | 5-4 | 最終統括レポートを作成しPRへ反映 | エージェント |
| [] | 5-5 | plans/worklog/reportsを削除しHANDOFF.mdをリセット | エージェント |
| [] | 5-6 | commitしpushしてDraft解除 | エージェント |
| [] | 5-7 | マージする | 人間 |

## やったこと

- flow-id 1-2: issue #142 の本文と、通知コメント2件（PR #139 由来・issue #155 由来）を取得した。
  同型の事故が **4件**（issue #64 / #109 / PR #139 / issue #155）あることを確認した。
- flow-id 1-3: ハーネス指定ブランチ `claude/docs-workflow-heading-rule-mi3krb` で Draft PR #188 を
  作成し、`subscribe_pr_activity` で追従監視を開始した。
- flow-id 1-4: 全体作業計画 `plans/brisk-weaving-lantern.md`（＋同名 `.html`）を作成した。
- flow-id 1-5 は `[-]`。**非対話的セッション**のため人間の合意を待てない。ユーザーからの指示
  「各フェーズの計画時に一度、作業実施ごとに一度、敵対的レビューを自動で行い、指摘に対する修正を
  行いながら進めること」をもって着手の合意とみなす。
- flow-id 2-1: 個別調査計画 `plans/【調査】残置テキストの係り先ルールの射程と重複を洗い出す.md`
  （＋`.html`）と worklog を作成した。
- flow-id 2-2: commit・push（push 1）。HANDOFF.mdのヘッダ更新で push 2。
- flow-id 2-3〜2-4（1周目、敵対的レビューで代替）: 計画に対する敵対的レビューを実施し、
  **7件をインライン投稿・2件を報告のみ**とした。7件すべてへ対応し返信済み（未返信スレッド 0）。
  - 投稿したスレッド:
    - https://github.com/yuki-matsu783/MR-driven-workflow/pull/188#discussion_r3838550549 （md/html非同期）
    - https://github.com/yuki-matsu783/MR-driven-workflow/pull/188#discussion_r3838551127 （#109の壊れた位置の軸が食い違い）
    - https://github.com/yuki-matsu783/MR-driven-workflow/pull/188#discussion_r3838551519 （Q2が`.gemini/`を数える）
    - https://github.com/yuki-matsu783/MR-driven-workflow/pull/188#discussion_r3838551929 （検証が1実例・1ファイル）
    - https://github.com/yuki-matsu783/MR-driven-workflow/pull/188#discussion_r3838552346 （Q3の循環依存）
    - https://github.com/yuki-matsu783/MR-driven-workflow/pull/188#discussion_r3838552762 （Q4が識別子だけで判定）
    - https://github.com/yuki-matsu783/MR-driven-workflow/pull/188#discussion_r3838553202 （合格条件が空振り）
  - 報告のみの2件（`.gemini/`が変更対象に無い／前提にflow-idが無い）も、あわせて計画へ反映した。
  - 敵対的レビューの実施回数: フェーズ2は 1/3。

## 次にやること

- flow-id 2-5: 調査計画をもとにMR descriptionを更新する（`describe`）。
- flow-id 2-6: 調査を実施し、`reports/` へ結果を記録する。

## 判断を迷った内容

- **ブランチ名がリポジトリの命名規則（`feature-<issue番号>-<slug>`）と異なる。** ハーネスが
  `claude/docs-workflow-heading-rule-mi3krb` を指定しており、他ブランチへのプッシュを禁じているため、
  ハーネスの指定を優先した。
- **flow-id 1-5（人間の合意）の扱い。** 非対話的セッションでは待てないため `[-]`（今回は実施しない）と
  した。人間のレビュー往復（2-3/2-4・2-8/2-9・3-3/3-4・3-8/3-9・4-3/4-4・4-8/4-9）は、ユーザーの指示に
  従い敵対的レビューで代替する。**代替したループ範囲の記号は `[]` のまま残す**
  （`.claude/rules/docs-workflow.md`「非対話的実行環境で人間担当のレビュー待ちステップを省略する場合」）。

## 未解決の内容

- （無し）

## 守るべき条件・触ってはいけない範囲

- **issue #64 由来の既存の実例2件を消さない**（受け入れ条件。`計画の2階層構造` の位置の話と、
  「同じ節名でもファイルごとに結論が変わる」話）。
- **ルールの適用対象を、操作の種類の列挙で書かない**（issue #155 の3例目が、列挙した4操作の
  どれにも入らなかったため）。
- マージ（flow-id 5-7）は行わない。AIエージェントは flow-id 5-6 で止まる。
