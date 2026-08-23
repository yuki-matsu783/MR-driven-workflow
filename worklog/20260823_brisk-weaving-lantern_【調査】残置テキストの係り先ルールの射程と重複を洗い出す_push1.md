---
title: worklog 20260823 【調査】残置テキストの係り先ルールの射程と重複を洗い出す push1
type: log
description: issue #142 フェーズ2の調査における試行錯誤ログ（push1）
tags: [worklog, research, docs-workflow]
keywords: [係り先, 残置テキスト, 射程, 重複, DDR, 敵対的レビュー, issue142]
---

# worklog: 【調査】残置テキストの係り先ルールの射程と重複を洗い出す

対象: `.claude/rules/docs-workflow.md` の「見出しの差し込み時に係り先を確認する」ルールの一般化（2026-08-23）。
全体作業計画: `plans/brisk-weaving-lantern.md`
個別作業計画: `plans/【調査】残置テキストの係り先ルールの射程と重複を洗い出す.md`
push回数: 1

## 試したこと

- issue #142 本文とコメント2件を MCP（`mcp__github__issue_read`）で取得した。CLI（`gh`）は
  この実行環境に無く、`get_vcs_access_mode` が `mcp` を返す。
- Draft PR 作成時、ブランチと `main` の差分が0だったため `create_pull_request` が失敗する見込みだった。
  `add_empty_commit_for_draft_mr` で空コミットを作ってから作成した。
- 計画HTMLは、テンプレート（`assets/plans.template.html`）の DOCTYPE〜`/head` を切り出して
  body を差し込む使い捨てスクリプトを scratchpad へ置いて生成した（`.claude/rules/ai-command-style.md`
  「切り出し先の選び方」に従い、使い捨てなので `.claude/scripts/src/` へは置かない）。
- md と HTML の同期確認は、md の `##`/`###` と HTML の `h2`/`h3` を正規化して突き合わせる
  Python スクリプトで行った（バッククォートと `code` タグの差を落としてから比較する）。
- 表の列ずれ検査は、各 `table` の `td`/`th` の数が全行で揃っているかで見た。

## うまくいったこと

- 同型の事故が **4件**（issue #64 / #109 / PR #139 / issue #155）あることを、issue本文と
  通知コメント2件だけで確定できた。**発掘のための横断調査が要らない**と判断できたため、
  調査項目からその作業を外した（スコープ外へ明記）。

## ダメだったこと

- **上位計画と個別計画で「壊れた位置」の軸がずれていた。** 上位計画は「分割点から見た位置」
  （#109 は「(1) の直後」）、個別計画は「新しく書いた部分から見た位置」（#109 は「前」）で書いており、
  同じ事例が前とも後ろとも読めた。敵対的レビューが検出。**新しく書いた部分から見た軸へ統一**した。
  皮肉なことに、これはこのissueが扱っている「係り先の食い違い」そのものである。
- **全体作業計画の md と html が同期していなかった。** 検証コマンドと「変更対象」節が html に
  しか無く、正文（md）側が `plans/REVIEW-POINTS.md` の観点を満たしていなかった。md を正として
  html を作り直し、見出しの突き合わせスクリプトで一致を確認する運用にした。

## 次の一歩

- flow-id 2-5: `describe` でMR descriptionを更新する。
- flow-id 2-6: Q1〜Q5 の調査を実施し、`reports/` へ結果を記録する。
