---
title: 【設計反映】usecase層の設計判断のDDR化
type: plan
description: issue #170フェーズ4の個別反映計画（設計反映）。ユースケース逆引き層の設計判断をDDR i0170-01として記録し、DDR一覧を再生成する
tags: [usecase-docs, plan, design-reflect]
keywords: [設計反映, DDR, i0170-01, README一本化, 日本語ファイル名, 生成物化, generate-ddr-list]
---

# 【設計反映】usecase層の設計判断のDDR化

- issue: #170 / PR: #173
- 全体作業計画: `plans/usecase-atlas.md`
- 作成日: 2026-08-23

## 前提（合意状況）

- 依拠する結果: `reports/20260823_usecase-atlas_調査結果.md`・`reports/20260823_usecase-atlas_作業結果.md`
  「設計への反映」（いずれも人間レビューは未実施。敵対的レビュー計4回・46件の指摘修正で代替）。
- 上位の全体作業計画は flow-id 1-5 未合意のまま先行中（扱いは全体作業計画「実行環境と運用の前提」）。

## 反映対象（洗い出しの結果）

フェーズ2〜3で行った次の意思決定は、`plans/`・`reports/` が flow-id 5-5 で削除された後は
どこにも残らないため、DDRとして記録する。

1. **DDR `i0170-01` を新規作成する**: 「ユースケース逆引き層はREADME一本化・日本語ファイル名・
   手動一覧で運用する」。内容は次の決定と却下案（調査結果 問い3・問い4が正）。
   - 一覧の正は `.claude/docs/README.md` のusecase節1箇所（却下: `usecase/` 直下の独立README）。
   - ファイル名は場面を表す日本語（却下: 英語kebab-case、番号プレフィックス）。
   - 一覧は手動更新＋同一コミット更新ルール（却下: DDR一覧同様の生成物化。8件規模では
     導入・保守コストが上回る。再検討条件＝手動更新の漏れが実際に起きたとき、も記録する）。
2. `bash .claude/scripts/src/generate-ddr-list.sh` を実行し、README.mdのDDR一覧の差分を
   同じコミットへ含める。

## やらないこと（スコープ外）

- spec の新設（usecase層の運用の正は `.claude/rules/docs-workflow.md` の表と README のusecase節に
  既に置いた。specを足すと正が3箇所になる）。
- DDR本文への手順詳細の記載（決定と却下案・理由のみ）。

## 検証（実行できるコマンドと合格条件）

```bash
# 1. DDRが規約どおりの識別子で存在する（出力1で合格）
ls .claude/docs/ddr/i0170-01-*.md | wc -l
# 2. frontmatterが規約どおり（type: ddr。出力1で合格）
grep -c '^type: ddr$' .claude/docs/ddr/i0170-01-*.md
# 3. DDR一覧が最新（終了コード0で合格）
bash .claude/scripts/src/generate-ddr-list.sh --check
```
