---
title: plansDirectoryネストパス実機検証結果
type: report
description: issue #165受け入れ条件1対応。.claude/settings.jsonのplansDirectoryにネストパス(./wip/plans)を設定した場合にEnterPlanModeが提示する計画ファイルパスを実機検証した結果
tags: [issue-mr-flow, plansDirectory, investigation]
keywords: [wip, plans, plansDirectory, Planモード, ネストパス, 実機検証, EnterPlanMode, ExitPlanMode, 対照実験]
---

# plansDirectoryネストパス実機検証結果

対象: issue #165 フェーズ2調査（受け入れ条件1・最優先）。
全体作業計画: `plans/transient-brewing-pelican.md`
個別計画: `plans/【調査】plansDirectoryのネストパス対応検証.md`

## 結論

**`.claude/settings.json` の `plansDirectory: "./wip/plans"`（ネストしたパス）は、新規セッションで
`EnterPlanMode`に入った際に実際に反映される。** ハーネスが提示した計画ファイルパスは
`wip/plans/<自動命名>.md` であり、ルート直下の `plans/<自動命名>.md` ではなかった。

**限定**: この結論は、Claude Code on the web（リモート実行環境、Linux）・2026-08-23・N=1（新規
セッション1回）の観測に基づく。ローカル環境（Windows/git bash等）・別バージョンでの挙動は
未確認。根拠は「EnterPlanModeが提示したパス」1点のみであり、その後Writeツールで実際にファイルが
書けたことは`plansDirectory`の検証根拠にはならない（Writeツールは任意のパスへ書き込めるため）。

## 検証条件（セットアップと実行環境）

- このタスク自身のコミット（`aafaab7`, 2026-08-23 04:51:32）で、`.claude/settings.json` の
  `plansDirectory` を `"./wip/plans"` へ変更し、`wip/plans/.gitkeep` を作成した上でpushした
  （外から与えられた前提条件ではなく、この検証のためのセットアップである）。
- 検証は、上記コミットをチェックアウトした**新規の別セッション**（session_01A48PeEHLHrnXihSbMdmvnw、
  実行環境: Claude Code on the web）で実施した。同一セッション内での設定変更→Planモード再入では
  ないことが重要（下記「想定と異なった点」参照）。

## 実施した内容と結果

### 1. 新規セッションでのEnterPlanMode/ExitPlanMode実行

1. `EnterPlanMode` を呼び出した。
2. 応答内の "Plan File Info" システムメッセージに、以下の実際の絶対パスが提示された。

   ```
   /home/user/MR-driven-workflow/wip/plans/glimmering-dancing-penguin.md
   ```

3. このパスへ検証用の計画内容をWriteツールで書き込み、`ExitPlanMode` を呼び出してユーザーの
   承認を得た（Writeツールでの書き込み自体は`plansDirectory`の検証根拠にはならない。任意のパスへ
   書けるため。根拠は手順2の提示パスのみ）。
4. 検証用ダミーファイル（`wip/plans/glimmering-dancing-penguin.md`）は、別セッションのワークツリー
   上にのみ存在し、本ブランチへコミットされていない（`git log`にも現れない）。当該セッションの
   最終応答時点で「削除済み」と報告されたが、本ブランチからは削除の裏取りができない
   （ワークツリーがセッション間で共有されないため）。

### 2. 対照実験: フラットな新規パス（`./plans2`）での検証

個別調査計画は、設定がそもそも読み込まれているか（ネストパス特有の対応ではなく、任意の文字列が
反映されるだけではないか）を切り分けるため、フラットな新規パスでの対照実験を求めていた。
`.claude/settings.json` の `plansDirectory` を一時的に `"./plans2"` へ変更しpushした上で、新規
セッションの起動を複数回試みたが、`create_session` が「the service is temporarily unavailable」
（インフラの一時停止）で連続して失敗し、**対照実験は未完了のまま保留とした**。設定はいったん
`"./plans"`（元の値）へ戻し、既存の全体作業計画パスへの影響を残さないようにした。対照実験は
サービス復旧後に再試行し、結果をこの節へ追記する。

### 3. 同一セッション内での再入（参考・失敗した試行）

本検証に先立ち、このセッション自身で `.claude/settings.json` を書き換えてから
`EnterPlanMode` へ再入する方法を試したが、ハーネスは既存の計画ファイル
（`plans/transient-brewing-pelican.md`）をそのまま提示し続け、設定変更は反映されなかった。
詳細は下記「想定と異なった点」。

## 確かめられなかったこと

- `.gemini/settings.json` の `general.plan.directory` についても同様にネストパスが機能するかは、
  Gemini CLI自体が本実行環境に存在しないため実行による確認ができていない。設定ファイルの記法上の
  妥当性のみ、別途ドキュメントで裏付ける。
- `wip/plans` ディレクトリが事前に存在しない状態でも同じ結果になるかは未検証（今回の検証時点で
  既に `wip/plans/.gitkeep` を含む状態だった）。
- 対照実験（`./plans2`）が完了していない場合、「ネストパス特有の対応である」こと自体は
  厳密には確定していない（設定が反映されること自体は確認済み）。

## 設計への反映

1. フェーズ3で `.claude/settings.json` の `plansDirectory` を正式に `"./wip/plans"` へ変更して
   よいと判断できる（対照実験の結果を待って最終確認する）。
2. この結論と検証方法（同一セッション内再入が使えない理由・新規セッションを使う理由）をDDRとして
   記録する（フェーズ4）。
3. `.gemini/settings.json` 側は、記法上の妥当性確認の結果を別途DDR/specへ記載する。

## 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| 同一セッション内で `.claude/settings.json` を書き換えてから `EnterPlanMode` へ再入すれば検証できると想定していた | ハーネスは既に確定した計画ファイル（`plans/transient-brewing-pelican.md`）をそのまま提示し続け、設定変更が反映されなかった（偽陰性） | 新規セッションでの検証方式へ切り替えた（計画フェーズの敵対的レビューでも同じ懸念が指摘された） |
