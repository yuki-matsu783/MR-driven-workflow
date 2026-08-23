---
title: worklog - 【調査】plansDirectoryのネストパス対応検証
type: log
description: issue #165フェーズ2調査の詳細ログ
tags: [worklog, issue-165]
keywords: [wip, plansDirectory, ネストパス, 実機検証]
---

# worklog: 【調査】plansDirectoryのネストパス対応検証

対象: issue #165 フェーズ2 - plansDirectoryのネストパス実機検証（2026-08-23）。
全体作業計画: `plans/transient-brewing-pelican.md`
個別作業計画: `plans/【調査】plansDirectoryのネストパス対応検証.md`
push回数: 1

## 試したこと

- `.claude/settings.json` の `plansDirectory: "./wip/plans"` が設定された状態で
  `EnterPlanMode` を呼び出し、"Plan File Info" に提示される計画ファイルパスを確認した。
- 提示されたパス（`wip/plans/glimmering-dancing-penguin.md`）へ検証用のダミー内容を書き、
  `ExitPlanMode` でユーザーの承認を得た。
- 承認後に `ls -la` で実ファイルの存在を確認し、`plans/` 直下（ネスト前の旧既定値相当）へは
  誤って作成されていないことも確認した。

## うまくいったこと

- `plansDirectory` のネストパス（`./wip/plans`）は実際に機能することを確認した。ハーネスが
  提示したパスは `wip/plans/<自動命名>.md` であり、`plans/<自動命名>.md` へのフォールバックは
  発生しなかった。詳細は `reports/20260823_transient-brewing-pelican_plansDirectoryネストパス検証.md`
  を参照。

## ダメだったこと

- 本検証に先立ち、同一セッション内で `.claude/settings.json` を書き換えてから
  `EnterPlanMode` へ再入する方法を試したが失敗した。ハーネスは既存の計画ファイル
  （`plans/transient-brewing-pelican.md`）をそのまま提示し続け、設定変更が反映されなかった
  （偽陰性。新規セッションでの検証方式へ切り替える契機になった）。
- 対照実験（フラットな新規パス`./plans2`）のための新規セッション起動が、サービス一時停止
  （`create_session`が"the service is temporarily unavailable"で複数回失敗）により保留中。

## 次の一歩

- 検証用ダミーファイル（`wip/plans/glimmering-dancing-penguin.md`）は別セッションのワークツリー
  上で削除されたと報告されたが、本ブランチからは裏取りできない（コミットされていないため）。
- 対照実験（`./plans2`）用の新規セッションを再試行する。
- `.gemini/settings.json` の `general.plan.directory` について、記法上の妥当性確認を別途行う
  （実行環境にGemini CLIが無いため実機検証は対象外）。
- 調査結果に対する敵対的レビュー（1周目）の指摘13件へ対応中。対応完了後、2周目のレビューへ進む。

---
