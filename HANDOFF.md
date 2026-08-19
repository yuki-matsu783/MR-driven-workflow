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

（無し）

## 次にやること

（無し）

## 判断を迷った内容

- `main`（issue #50 / PR #96、issue #93 / PR #98）が先に DDR 0041・0042 を使用していたため、
  `main` をマージして本ブランチの DDR を **0041 → 0043** へ繰り下げた（ファイル名・frontmatterの
  `title`・本文見出し・`.claude/docs/README.md` の一覧・`SKILL.md`／`Provider.sh`／spec からの
  参照をすべて更新）。
- `.claude/docs/spec/issue-mr-workflow.md` の「影響範囲」は、先にマージされた issue #50 の
  エントリ → 本ブランチの issue #86 のエントリ、という時系列順で両方を残した（類型D）。
  issue #50 のエントリ本文は書き換えていない。
- `.claude/docs/README.md` のDDR一覧は両ブランチの追記をどちらも残し、番号順に並べ直した（類型C）。

## 未解決の内容

（無し）

## 守るべき条件・触ってはいけない範囲

（無し）
