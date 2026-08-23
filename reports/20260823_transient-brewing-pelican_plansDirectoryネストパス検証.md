---
title: plansDirectoryネストパス実機検証結果
type: report
description: issue #165受け入れ条件1対応。.claude/settings.jsonのplansDirectoryにネストパス(./wip/plans)を設定した場合にPlanモード（EnterPlanMode/ExitPlanMode）が実際にそこへ出力するかを実機検証した結果
tags: [issue-mr-flow, plansDirectory, investigation]
keywords: [wip, plans, plansDirectory, Planモード, ネストパス, 実機検証, EnterPlanMode, ExitPlanMode]
---

# plansDirectoryネストパス実機検証結果

対象: issue #165 フェーズ2調査（受け入れ条件1・最優先）。
全体作業計画: `plans/transient-brewing-pelican.md`
個別計画: `plans/【調査】plansDirectoryのネストパス対応検証.md`

## 結論

**`.claude/settings.json` の `plansDirectory: "./wip/plans"`（ネストしたパス）は実際に機能する。**
Planモードに入った際にハーネスが提示する計画ファイルパスは、ネストを反映した
`wip/plans/<自動命名>.md` であり、ルート直下の `plans/<自動命名>.md` へフォールバックする
ことはなかった。

## 検証条件

- 検証時点で `.claude/settings.json` の `plansDirectory` は既に `"./wip/plans"` に設定済み
  （変更は不要だった。git履歴上いつ設定されたかは本調査のスコープ外）。
- `wip/plans/` ディレクトリは検証前から存在していた（`.gitkeep` のみを含む空ディレクトリ）。

## 手順と実測結果

1. `EnterPlanMode` を呼び出した。
2. 応答内の "Plan File Info" システムメッセージに、以下の実際の絶対パスが提示された。

   ```
   /home/user/MR-driven-workflow/wip/plans/glimmering-dancing-penguin.md
   ```

3. このパスへ検証用の計画内容をWriteツールで書き込んだ。
4. `ExitPlanMode` を呼び出し、ユーザーの承認を得た。
5. 承認後、`ls -la` で実ファイルの存在を確認した。

   ```
   -rw-r--r-- 1 root root 1988 Aug 23 04:54 /home/user/MR-driven-workflow/wip/plans/glimmering-dancing-penguin.md
   ```

6. 比較のため `plans/` 直下（ネスト前の旧既定値に相当するパス）に同名ファイルが
   誤って作成されていないことも確認した（該当ファイルなし）。

## 判定

| 項目 | 結果 |
|---|---|
| 提示された計画ファイルパスが `wip/plans/` 配下か | Yes（`plans/` 直下へのフォールバックなし） |
| 実際にそのパスにファイルが作成されたか | Yes（1988バイト、作成日時2026-08-23 04:54） |
| ネストパス対応が機能しているか | **成功** |

## 検証対象外（本調査でのスコープ外）

- `.gemini/settings.json` の `general.plan.directory` への同様のネストパス設定は、
  Gemini CLI自体が本実行環境（Claude Code on the web）に存在しないため、実行による検証は
  できなかった。設定ファイルの記法上の妥当性のみ、別途ドキュメント上の裏付けで確認する。

## 後片付け

- 検証用に作成した `wip/plans/glimmering-dancing-penguin.md` は、本報告の記録後に削除する
  （このファイル自体はダミーの検証専用ファイルであり、正式な全体作業計画ではないため）。
