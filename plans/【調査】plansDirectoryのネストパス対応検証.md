---
title: 【調査】plansDirectoryのネストパス対応検証
type: plan
description: issue #165受け入れ条件1対応。.claude/settings.jsonのplansDirectory・.gemini/settings.jsonのgeneral.plan.directoryにネストしたパス(./wip/plans)を設定した場合に実際にそこへ出力されるかを実機検証する
tags: [issue-mr-flow, plansDirectory, investigation]
keywords: [wip, plans, plansDirectory, Planモード, ネストパス, 実機検証]
---

# 【調査】plansDirectoryのネストパス対応検証

## 目的

issue #165 受け入れ条件1「着手時にまず `plansDirectory` のネストパス対応を実機検証する」に従い、
`.claude/settings.json` の `plansDirectory` を `"./wip/plans"` のようなネストしたパスへ変更した
場合に、Planモードで作成する全体作業計画が実際にそのパスへ出力されるかを確認する。

## 変更対象

- `.claude/settings.json`（一時的に `plansDirectory` を書き換えて検証し、検証後は結果に応じて
  本実装へ引き継ぐ。このファイル自体は個別作業計画3-1で正式に変更する）
- `.gemini/settings.json`（同上。ただしGemini CLI自体は本実行環境に存在しないため、実行による
  検証はできない。設定ファイルの記法・ドキュメント上の裏付けで代替する）

## 方針

1. `.claude/settings.json` の `plansDirectory` を `"./wip/plans"` へ一時的に変更する。
2. `wip/plans` ディレクトリを作成する（存在しないと書き込み自体が失敗する可能性があるため）。
3. Planモード（EnterPlanMode）に入り、ダミーの計画を作成してExitPlanModeを呼ぶ前に、
   ハーネスが提示する plan file のパスを確認する（"Plan File Info" のシステムメッセージに
   実際のパスが出力される）。
4. パスが `wip/plans/<自動命名>.md` になっていれば成功。`plans/<自動命名>.md`
   （ネストが無視されルート直下になる）等、意図と異なる場所になっていれば失敗と判定する。
5. 検証用に作成したダミー計画ファイルは削除し、`.claude/settings.json` の変更も
   このタスクの個別作業計画（3-1）へ引き継ぐか、検証専用の一時変更として一旦元に戻すかを、
   検証結果を見て判断する。

## やらないこと

- `.gemini/settings.json` の実機検証（Gemini CLIが実行環境に無いため不可能。設定ファイルの
  記法上の妥当性確認のみに留める）。
- 本実装（`git mv`によるディレクトリ移動、他ファイルの参照更新）は個別作業計画（フェーズ3）で行う。

## 検証手順

上記「方針」のとおり。結果は `reports/日付_transient-brewing-pelican_plansDirectoryネストパス検証.md`
へ記録する。
