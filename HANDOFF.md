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

（次タスク着手時に記入する）

## やったこと

- 対応工数レポートのフッターにある過小カウントの注記（「既知の過小カウント要因が報告されています。」
  ＋詳細リンク）を、Claude Code由来のトークン行を含むレポートにだけ出すようにした
  （Gemini CLIのセッションログについては同種の報告が無いため）。判定はengineではなくデータで行う
  （DDR 0052と同じ理由。繰り越しでGemini CLIからの投稿にClaude Code由来の行が載る場合に備える）。
- `.claude/hooks/post-push-usage-report.sh` / `.claude/scripts/test/test_usage_tracking.sh`
  （81→90ケース、`passed=90 failures=0`）／`.claude/docs/spec/issue-mr-workflow.md` を更新。

## 次にやること

- PR #120（https://github.com/yuki-matsu783/MR-driven-workflow/pull/120 ）のレビュー待ち。
- マージはユーザーの明示指示があるまで行わない。

## 判断を迷った内容

- mainのマージ時、`.claude/docs/spec/issue-mr-workflow.md`「影響範囲」の末尾で、main側（PR #119
  「レビュー依頼のターンでのaskツール禁止」）と本ブランチ側（「過小カウントの注記は…」）が
  それぞれ別の `###` エントリを `## 未決定事項・懸念点` の直前へ追記して競合した（類型C/D）。
  **両方のエントリを残し、既にmainへ入っている#119のエントリを先、本ブランチのエントリを後**の
  時系列順に並べた（片方を捨てない・過去エントリの中身は書き換えないという規約に従う）。

## 未解決の内容

（無し）

## 守るべき条件・触ってはいけない範囲

（無し）
