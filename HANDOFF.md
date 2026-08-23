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

- issue: #172
- ブランチ: `claude/gemini-exclude-decision-yp5p70`
- PR: #193（Draft）（https://github.com/yuki-matsu783/MR-driven-workflow/pull/193 ）
- push回数: 3
- 現在のループ: 2-3〜2-4 の1周目（進行中）
- 未返信スレッド: 0
- 追従監視: PRイベント購読中（`subscribe_pr_activity` で PR #193 を購読。セッション終了とともに止まるため、次セッションは `resume` で取り直す）

| 進捗 | flow-id | ステップ | 担当 |
|---|---|---|---|
| [x] | 1-1 | issueを起票する | 人間 |
| [x] | 1-2 | issueの内容を取得する | サブコマンド |
| [x] | 1-3 | featureブランチとDraft MRを作成する | エージェント |
| [x] | 1-4 | 全体作業計画を作成する（md・html） | エージェント |
| [] | 1-5 | 全体作業計画に合意する | 人間 |
| [x] | 1-6 | 全体作業計画をもとにHANDOFF.mdを更新する | エージェント |
| [x] | 2-1 | 個別調査計画を作成する（md・html）・worklog作成 | エージェント |
| [] | 2-2 | commit・push してレビュー依頼 | エージェント |
| [] | 2-3 | 調査計画をレビュー・コメントする | 人間 |
| [] | 2-4 | レビュー内容を取得し調査計画を修正・返信する | サブコマンド |
| [] | 2-5 | 調査計画をもとにMR descriptionを更新する | サブコマンド |
| [] | 2-6 | 調査を実施し結果をreports（md・html）へ記録する | エージェント |
| [] | 2-7 | commit・push してレビュー依頼 | エージェント |
| [] | 2-8 | 調査結果をレビュー・コメントする | 人間 |
| [] | 2-9 | レビュー内容を取得し調査結果を修正・返信する | サブコマンド |
| [] | 2-10 | 調査結果をもとにMR descriptionを更新する | サブコマンド |
| [] | 3-1 | 個別作業計画を作成する（md・html） | エージェント |
| [] | 3-2 | commit・push してレビュー依頼 | エージェント |
| [] | 3-3 | 作業計画をレビュー・コメントする | 人間 |
| [] | 3-4 | レビュー内容を取得し作業計画を修正・返信する | サブコマンド |
| [] | 3-5 | 作業計画をもとにMR descriptionを更新する | サブコマンド |
| [] | 3-6 | 作業を実施し結果をreports（md・html）へ記録する | エージェント |
| [] | 3-7 | commit・push してレビュー依頼 | エージェント |
| [] | 3-8 | 作業結果をレビュー・コメントする | 人間 |
| [] | 3-9 | レビュー内容を取得し実装・ドキュメントを修正・返信する | サブコマンド |
| [] | 3-10 | 作業内容をもとにMR descriptionを更新する | サブコマンド |
| [] | 4-1 | 個別反映計画を作成する（反映対象の洗い出しを含む） | エージェント |
| [] | 4-2 | commit・push してレビュー依頼 | エージェント |
| [] | 4-3 | 反映計画をレビュー・コメントする | 人間 |
| [] | 4-4 | レビュー内容を取得し反映計画を修正・返信する | サブコマンド |
| [] | 4-5 | 反映計画をもとにMR descriptionを更新する | サブコマンド |
| [] | 4-6 | 設計反映・AIアセット反映・実装反映を実施しreportsへ記録する | エージェント |
| [] | 4-7 | commit・push してレビュー依頼 | エージェント |
| [] | 4-8 | 反映結果をレビュー・コメントする | 人間 |
| [] | 4-9 | レビュー内容を取得し設計・AIアセットを修正・返信する | サブコマンド |
| [] | 4-10 | 反映内容をもとにMR descriptionを更新する | サブコマンド |
| [] | 5-1 | defaultブランチとのコンフリクトを検知し、あれば解消する | エージェント |
| [] | 5-2 | 関連issueへマージ前通知を行う（承認必須） | エージェント |
| [] | 5-3 | `.claude/` の変更を `.gemini/` へ変換同期する | エージェント |
| [] | 5-4 | 最終統括レポートを作成しPRへ反映する | エージェント |
| [] | 5-5 | wip/ を片付けHANDOFF.mdをリセットする | エージェント |
| [] | 5-6 | commit・push してDraftを解除する | エージェント |
| [] | 5-7 | マージする（squash merge） | 人間 |

## やったこと

- flow-id 1-1〜1-2: issue #172 の内容を取得した（`mcp__github__issue_read`。`gh` CLI不在のためMCP経路）。
- flow-id 1-4: 全体作業計画 `wip/plans/mellow-drifting-lantern.md`（＋同名 `.html`）を作成した。
  planツール（Planモード）は使用していない（このセッションは既にPlanモードを抜けており、
  ハーネスからの自動命名の提示が無いため、命名規則に沿った名前を自分で付けた）。
- flow-id 1-5: 非対話セッションのため人間の合意を待てない。合意は得ていない（進捗記号は `[]` のまま）。
- flow-id 1-6: このHANDOFF.mdを更新した。
- flow-id 1-3: Draft PR #193 を作成した（`mcp__github__create_pull_request`）。
- flow-id 2-1: 個別調査計画 `wip/plans/【調査】gemini生成対象3ディレクトリの参照実態.md`（＋`.html`）と
  worklog `wip/worklogs/20260823_…_push2.md` を作成した。
- flow-id 2-2: commit・pushし、**計画に対する敵対的レビュー（フェーズ2・1回目）を実施**した。
  findings 11件 → 投稿候補7件 → PR #193 へ6スレッドとしてインライン投稿。
  投稿したスレッド:
  - https://github.com/yuki-matsu783/MR-driven-workflow/pull/193#discussion_r3838831895
  - https://github.com/yuki-matsu783/MR-driven-workflow/pull/193#discussion_r3838832231
  - https://github.com/yuki-matsu783/MR-driven-workflow/pull/193#discussion_r3838832804
  - https://github.com/yuki-matsu783/MR-driven-workflow/pull/193#discussion_r3838833312
  - https://github.com/yuki-matsu783/MR-driven-workflow/pull/193#discussion_r3838833686
  - https://github.com/yuki-matsu783/MR-driven-workflow/pull/193#discussion_r3838834102
- flow-id 2-5: MR description を更新した。
- flow-id 2-6: **Q1〜Q6 を実測**し、`wip/reports/20260823_mellow-drifting-lantern_gemini生成対象の参照実態.md`
  （＋`.html`）へ記録した。要点は、hooks/ scripts/ は Gemini CLI から読まれず切れるリンクは1件ずつ、
  docs/ は18件が切れる、3ディレクトリで `.gemini/` の 78.7%（2.49MB）を占めるが配布物のサイズは
  変わらない（`layer: exclude`）。worklog は `_push3.md`。
- **flow-id 2-3〜2-4 相当**: 人間のレビュー往復は非対話セッションのため成立しない（進捗記号は
  `[]` のまま）。代わりに、上記6スレッドの指摘すべてを計画へ反映し、6スレッドすべてへ返信した
  （未返信スレッド 0）。MRへ投稿しなかった「報告のみ」4件も、内容は妥当だったため同じpushで
  修正し、内訳を worklog へ書き出した。

## 次にやること

- flow-id 2-7: commit・pushし、調査結果に対する敵対的レビュー（フェーズ2・2回目）を実施する。
- flow-id 3-1: 3ディレクトリそれぞれの採否を決める個別作業計画を書く。

（済）flow-id 2-5: 調査計画をもとにMR descriptionを更新する。


## 判断を迷った内容

- **ブランチ名がリポジトリの命名規則（`feature-<issue番号>-<slug>`）と異なる。**
  ハーネス（Claude Code on the web）が `claude/gemini-exclude-decision-yp5p70` を指定し、
  「他のブランチへpushしない」ことを求めているため、ハーネス側の指示を優先した
  （`.claude/rules/git-workflow.md`「ハーネスがPR作成を制限する環境での扱い」と同じ考え方）。
- **flow-id 1-3 と 1-4 の順序を入れ替えた。** GitHubはコミットが1件も無いブランチに対して
  PRを作成できず、ブランチ作成直後は `origin/main` と同一だったため。
- **issue #172 は分割しない。** 受け入れ条件は3ディレクトリという同型項目の並列列挙であり、
  `wip/plans/REVIEW-POINTS.md`「issue分割のトリガー」の判定対象に当たる。各項目は単独で
  マージされてもシステムが壊れないが、1件あたりの作業が spec/DDR への追記と除外定義1行と極小で、
  5フェーズを3回まわす固定費のほうが上回るため分割しない。
- **全体作業計画（flow-id 1-4）単独での敵対的レビューは行わない。**
  `adversarial-review-count.sh` が受け付けるフェーズは 2 / 3 / 4 に限られ、フェーズ1を
  指定すると実行前に弾かれる（実行して確認済み）。全体作業計画は flow-id 2-2 の
  敵対的レビュー（対象は `wip/plans/` 配下の計画すべて）に含めて1回で見る。

## 未解決の内容

（無し）

## 守るべき条件・触ってはいけない範囲

- **`.gemini/` を手で編集しない。** `.claude/` からの変換生成物であり、
  `bash .claude/scripts/src/sync-gemini-assets.sh` で再生成する（flow-id 5-3）。
- **コミットは必ず `commit` スキル経由**（`.claude/scripts/src/create-commit.sh`）。
- **変換規則そのもの**（agents frontmatter・settings.jsonのキー対応）は本issueのスコープ外。
