---
title: worklog 20260823 【調査】反映対象の切り出し判断基準 push2
type: log
description: issue #176 フェーズ2〈調査〉の詳細な試行錯誤ログ（push2）
tags: [worklog, issue-mr-flow, research]
keywords: [調査, 切り出し, 反映対象, 4類型, DDR, 固定費, 記録先, 敵対的レビュー]
---

# worklog: 【調査】反映対象の切り出し判断基準

対象: フェーズ4の反映対象に対する「このMRで対応するか別issueへ切り出すか」の判断基準を書くための調査（2026-08-23）。
全体作業計画: `wip/plans/reflection-split-criteria.md`
個別作業計画: `wip/plans/【調査】反映対象の切り出し判断基準.md`
push回数: 2

## 試したこと

- flow-id 1-2〜1-6: issue #176 の本文・コメントを MCP（`mcp__github__issue_read`）で取得した。
  `gh` CLI が不在の実行環境のため、`Provider.sh` の CLI 経路は使わず MCP フォールバック
  （`references/mcp-fallback.md`）を採った。
- 全体作業計画・個別調査計画を作成し、いずれも同名 `.html` を
  `plans.template.html` から生成した。**プレースホルダ残存 0 件・アンカー破断 0 件**を
  スクリプトで確認した（テンプレート冒頭コメントが求める検査）。

## うまくいったこと

- HTMLビューの生成を「テンプレートの `<!DOCTYPE>`〜`<body>` をそのまま流用し、body だけを
  書き下ろす」形にした。`<style>` を触らないため、テンプレートが保証する自己完結性
  （外部依存なし）が自動的に保たれる。

## ダメだったこと

- 最初の `git fetch origin main claude/reflection-plan-criteria-tnhfvs` が
  `fatal: couldn't find remote ref claude/…` で落ち、**同じコマンドに含めた `main` の
  fetch も反映されなかった**（`origin/main` が古いまま残り、`git rev-list --left-right`
  が「HEAD が 32 コミット進んでいる」という誤った読みを返した）。ブランチを個別に fetch し
  直して解消した。**複数refspecの fetch は、1つでも存在しないと他も巻き添えになる。**

## 次の一歩

- flow-id 2-1 の敵対的レビュー（フェーズ2・1回目）を実施する。
- flow-id 2-6: 6問の調査を実施し、結果を `wip/reports/` へ書く。
