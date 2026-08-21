---
title: 【設計反映】canvas-report刷新のDDR起票
type: plan
description: issue #141の個別反映計画。フェーズ4の反映対象の洗い出し結果と、DDR起票の方針。
tags: [canvas-report, ddr, plan]
keywords: [設計反映, DDR, Tailwind, フラットparent, 洗い出し, generate-ddr-list]
---

# 【設計反映】canvas-report刷新のDDR起票

全体作業計画: `plans/canvas-report-code-canvas-refresh.md`（issue #141）。flow-id 4-1相当。

## 反映対象の洗い出し結果

| 候補 | 判断 |
|---|---|
| spec（`.claude/docs/spec/canvas-report.md` 新設） | **見送る**。データモデル・操作・抽出手順・規模指針はスキル利用時に必ず読む `SKILL.md` が既に持っており、specを新設すると二重管理になる（レビュー観点「同じ内容が複数ファイルに重複して書かれていないか」）。テンプレートの内部実装はテンプレート自身のコメントが自己記述する |
| DDR: canvas形式テンプレートのTailwindCSS CDN非依存化 | **起票する**（`i0141-01`）。検討・却下案を伴う意思決定であり、後から「なぜreports標準のTailwind方式でないのか」が必ず問われるため |
| DDR: データモデルをネスト記法でなくフラットなparent参照にする | **起票する**（`i0141-02`）。受け入れ条件（循環parent検出）とデータ表現の関係という、コードから読み取りにくい判断のため |
| AIアセット反映（`.claude/rules/` `CLAUDE.md` 等） | **なし**。スキル自身（SKILL.md）はフェーズ3で更新済み。canvas-reportスキルの `description`（発火条件）は据え置きで機能する |

## 作業内容

1. `i0141-01` / `i0141-02` のDDRを `.claude/docs/ddr/` へ作成する。
2. `bash .claude/scripts/src/generate-ddr-list.sh` を実行し、`.claude/docs/README.md` の差分を同じコミットへ含める。
3. `reports/…canvas検証.md` は既にフェーズ3の結果を持つため追記しない（DDRの参照だけ追える状態にする）。
