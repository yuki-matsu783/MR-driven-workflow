---
title: 【調査】plansDirectoryのネストパス対応検証
type: plan
description: issue #165受け入れ条件1対応。.claude/settings.jsonのplansDirectory・.gemini/settings.jsonのgeneral.plan.directoryにネストしたパス(./wip/plans)を設定した場合に実際にそこへ出力されるかを実機検証する
tags: [issue-mr-flow, plansDirectory, investigation]
keywords: [wip, plans, plansDirectory, Planモード, ネストパス, 実機検証, 新規セッション]
---

# 【調査】plansDirectoryのネストパス対応検証

## 目的

issue #165 受け入れ条件1「着手時にまず `plansDirectory` のネストパス対応を実機検証する」に従い、
`.claude/settings.json` の `plansDirectory` を `"./wip/plans"` のようなネストしたパスへ変更した
場合に、Planモードで作成する全体作業計画が実際にそのパスへ出力されるかを確認する。

## 変更対象

- `.claude/settings.json`（一時的に `plansDirectory` を書き換えて検証。このファイル自体の正式な
  変更は個別作業計画3-1で行う）
- `.gemini/settings.json`（同上。ただしGemini CLI自体は本実行環境に存在しないため、実行による
  検証はできない。設定ファイルの記法・ドキュメント上の裏付けで代替する）

## 方針

**同一セッション内での「設定書き換え→`EnterPlanMode`再入」は使わない。** 計画レビューで、
(a) ハーネスがこのセッションの計画ファイルパスを既に確定させている場合、設定変更後も同じパスが
提示され続け「ネストパス非対応」と誤判定する（偽陰性）恐れ、(b) DDR `i0009-01`
（planツールの利用は全体作業計画に限定しissueにつき1回）に反し、承認済みの全体作業計画を
壊す・2つ目の全体作業計画を作ってしまう恐れ、の2点が指摘された。実際にこのセッション内で試した
ところ、既存の `plans/transient-brewing-pelican.md` がそのまま提示され設定変更は反映されず、
この懸念が現実に起きることを確認した。

1. `.claude/settings.json` の `plansDirectory` を `"./wip/plans"` へ変更する（ブランチへcommit・
   push済みの状態にする）。
2. **新規の別セッション**（`mcp__Claude_Code_Remote__create_session` 等）を、このブランチを
   チェックアウトさせた状態で立ち上げる。そのセッションに「`EnterPlanMode`を呼び、提示された
   計画ファイルパスを報告してから、ダミー内容で`ExitPlanMode`する」よう依頼する。
3. 対照実験として、存在しない別のフラットなパス（例 `./plans2`）へ変更した場合に提示パスが
   変わるかも確認する（設定がそもそも読み込まれているかどうかの切り分け）。
4. 報告されたパスが `wip/plans/<自動命名>.md` になっていれば成功。`plans/<自動命名>.md`
   （ネストが無視されルート直下になる）等、意図と異なる場所になっていれば失敗と判定する。
5. 検証専用セッションは確認後アーカイブする。検証で作られたダミー計画ファイル・ディレクトリ
   （新規セッション側のワークツリーに閉じるため、このブランチのワークツリーには残らない見込み）
   を確認し、残っていれば削除する。

## やらないこと

- `.gemini/settings.json` の実機検証（Gemini CLIが実行環境に無いため不可能。設定ファイルの
  記法上の妥当性確認のみに留める）。
- 本実装（`git mv`によるディレクトリ移動、他ファイルの参照更新）は個別作業計画（フェーズ3）で行う。
  本計画では `wip/plans` を事前作成しない（`git mv plans wip/plans` の移動先として存在すると、
  `git mv`はエラーにならず配下へ入れてしまい `wip/plans/plans` のような二重ネストを無言で作るため）。

## 検証手順

上記「方針」のとおり。結果は `reports/日付_transient-brewing-pelican_plansDirectoryネストパス検証.md`
（結果の正文）へ記録する。試行錯誤の詳細は
`worklog/20260823_transient-brewing-pelican_【調査】plansDirectoryのネストパス対応検証_push1.md`
へ記録する。
