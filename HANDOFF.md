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

- **DDR番号を2回繰り下げた**（`main` がレビュー中にさらに進んだため）。
  - 1回目: `main`（issue #50 / PR #96、issue #95 / PR #98）が 0041・0042 を使用済みだったため
    **0041 → 0043**。
  - 2回目: `main`（issue #92 / PR #100）が 0043 を使用済みだったため **0043 → 0044**。
  - いずれも「defaultブランチ側を正とし作業ブランチ側を繰り下げる」規則どおり。ファイル名・
    frontmatterの `title`・本文見出し・`.claude/docs/README.md` の一覧・`SKILL.md`／`Provider.sh`／
    spec からの参照をすべて更新した。
- `.claude/docs/spec/issue-mr-workflow.md` の「影響範囲」は、先にマージされた issue #50 →
  issue #92 → 本ブランチの issue #86、という時系列順で全エントリを残した（類型D）。
  **他issueのエントリ本文は書き換えていない。** `sed` による一括置換が他issueのエントリまで
  及びかけた（`（DDR一覧へ00NNを追加）` の行）ため、2回とも該当行を元の番号へ戻している。
- `.claude/docs/README.md` のDDR一覧は両ブランチの追記をどちらも残し、番号順に並べ直した（類型C）。
- `.claude/rules/docs-workflow.md` の `HANDOFF.md` 行は、本ブランチの変更（41ステップ・
  flow-id 5-4）と `main` 側 issue #93 の変更（ヘッダへ「現在のループ」を追加）が同一行で
  競合したため、**両方の意図を1行へ統合**した（類型C）。

## 未解決の内容

（無し）

## 守るべき条件・触ってはいけない範囲

（無し）
