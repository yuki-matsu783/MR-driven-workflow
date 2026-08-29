---
title: 20260829_silver-drifting-lantern_統括
type: report
description: issue #203（レポートHTMLビューのデザイン案4種のテンプレート化）ブランチ全体の統括レポート
tags: [report, issue-mr-flow, template, issue203]
keywords: [reports-clean, reports-neobrutal, reports-mono, reports-paper, 共通DOM, 選択基準, 検査6, test_report_templates.sh, i0203-01, VERSION]
---

# 統括レポート: issue #203（レポートHTMLビューのデザイン案4種のテンプレート化）

対象: issue #203 / PR #204。全体作業計画: `wip/plans/silver-drifting-lantern.md`。

## 何を変えたか

- `.claude/skills/issue-mr-flow/assets/` へ **レポート用テンプレートを4本**（`reports-clean`・
  `reports-neobrutal`・`reports-mono`・`reports-paper`）追加した。**共通のDOMを1つ持ち、`<style>`
  ブロックの中身だけが違う**構成で、`<style>` を除いた部分は4本とも373行・23808バイトで
  バイト単位に一致する。外部依存はゼロ（CDN・外部フォント・画像を参照しない）。
- 既定は `reports-clean`。現行 `.claude/skills/issue-mr-flow/assets/reports.template.html` は
  **併存させ据え置いた**（ノード構造が新4本と異なるため、`<style>` の差し替えだけでは移行できない。
  移行期の位置づけをテンプレート冒頭コメントへ明記）。
- **検査手順を3種から6種へ拡張し、正を1箇所（`references/deliverables.md`）へ集約した。**
  追加した3種は外部依存の2細分（src/href・url()/@import）と、**構造の妥当性**（`<style>` が
  ちょうど1つであること）。最後のものは作業中に実際に踏んだ不具合——`<style>` の重複出力で
  2つ目がCSSテキストとして扱われ `:root { … }` ブロックごと破棄される——から追加した。
  検査手順の実体が5テンプレートへ複製されるのを避け、テンプレート側は使い方の説明に留めた。
- **不変条件（4本はスタイル以外バイト一致）を機械的に守る単体テストを新設した**
  （`.claude/scripts/test/test_report_templates.sh`。8アサーション・負のコントロール2件・
  `passed=8 failures=0`）。
- 参照側（`deliverables.md`・`directory-structure.md`・`SKILL.md`・`docs-workflow.md`・
  spec `issue-mr-workflow.md`・`phase5-close.md`・`start-resume.md`・`canvas-report/SKILL.md`・
  `plans.template.html`・`wip/{plans,reports}/REVIEW-POINTS.md`）を更新し、テンプレート選択基準
  （既定・使い分け表）を `references/deliverables.md`「レポートテンプレートの選び方」へ集約した。
- **新規DDR `i0203-01`** を作成し、共通DOM＋4スタイル構成の採用理由と却下案2件を記録した。
- `main`（issue #176・#187・#194 等）を取り込み、`.gemini/` を `sync-gemini-assets.sh` で
  同期し直した。

## なぜそうしたか

- **共通DOM＋スタイル差し替えの構成を採った**（却下: 4本を独立したHTMLとして持つ案、
  現行テンプレートを置き換える案）。デザインごとに構造まで独立させると、検査・不変条件の
  担保コストが4倍になる。詳細: `.claude/docs/ddr/i0203-01-…md`。
- **現行 `reports.template.html` は置き換えず併存させた**。新4本とはノード構造（`nav.toc` +
  `#review-focus` + `#summary` の分離 vs `aside.sidebar` + 統合 `#overview`）が異なり、
  安全に移行する手段が無かったため。既存レポートの参照を壊さずに済む。
- **検査手順の正を1箇所へ集約した**。5テンプレートへ複製すると、検査を改訂したときに
  一部だけが古くなるリスクがあったため（実際に敵対的レビュー4回目で、参照側だけ直して
  テンプレート本体を直し忘れる事故を1回起こしている。下記「検証結果」参照）。
- **`.claude/VERSION` は据え置いた**（このPR独自の増分は付けていない）。非対話セッションの
  例外を `.claude/VERSION` へ適用してよいかが未決定（issue #185）で、issue #165 に
  「今後上げる場合は人間の指示を起点に検討する」という判断が残っているため。`main` が
  issue #187・#176 を経て到達していた `0.6.0` は、マージで無変更のまま取り込んだ。

## 検証結果

- **敵対的レビュー4回**（フェーズ2の調査計画1回・フェーズ3の作業計画1回・フェーズ4の反映計画
  1回・反映作業1回）を実施し、**指摘63件すべてに対応した**（内訳: 12件・17件・19件・15件。
  詳細はPR #204のコメント）。うち複数回、成果物そのものの欠陥（`<style>` 二重出力・
  「実施していない作業を実施したと報告していた」等）を検出・修正した。
- `bash .claude/scripts/test/test_report_templates.sh` → `passed=8 failures=0`
- `bash .claude/scripts/src/check-dist-coverage.sh` → OK（4種すべて通過）
- `bash .claude/scripts/src/check-doc-references.sh` → 参照切れ0（候補267）
- `bash .claude/scripts/src/check-base-conflicts.sh` → `hasConflict: false`（`main` 取り込み後）
- 4テンプレートの `<style>` を除いた部分のハッシュ種別 → 1（完全一致）
- `bash .claude/scripts/src/sync-gemini-assets.sh --check` → 実行前「食い違いあり」・実行後
  「同期しています」

## spec・DDRへの反映先

- `.claude/docs/spec/issue-mr-workflow.md`「計画・レポートのHTMLビュー」節: テンプレート一覧・
  正の所在表を更新。`## 影響範囲`へ `### issue #203` の変更点一覧を追記。
- `.claude/docs/ddr/i0203-01-レポートHTMLビューは共通DOMと4スタイルで持ち現行を残す.md`:
  共通DOM＋4スタイル構成の採用と却下案2件（独立HTML案・現行置き換え案）。
- `.claude/skills/issue-mr-flow/references/deliverables.md`:
  「レポートテンプレートの選び方」「検査手順の正はこの節にある」（6種）
  「HTMLビュー共通の書き方」の3節を新設。
- `.claude/rules/directory-structure.md`・`.claude/rules/docs-workflow.md`: テンプレート一覧・
  ライフサイクル表の記述を新4本へ更新。

## 残課題

- **`wip/design-samples/` を持つブランチ（`claude/report-template-design-0bpul1`）の削除**は
  未実施。取り消しが難しい操作のため、ユーザーの明示指示があるまで実行しない
  （受け入れ条件5「決めて実施している」のうち、決定・記録は済み、実行だけが残る）。
- **ブラウザでの実表示は1件も確認していない**（この実行環境に表示確認手段が無いため）。
  6項目（`position: sticky`・`prefers-color-scheme`・`color-scheme: light`・案10のハードシャドウ・
  案13の `@media print`・二重罫線）。ユーザーへ確認し「記録に残すだけ」との回答を得たため、
  別issueは起票していない。spec の未決定事項・DDR・本レポートへ記録するに留める。
- **`.claude/VERSION` の増分は行っていない**（上記「なぜそうしたか」参照）。ユーザーの指示が
  あれば増分する。
