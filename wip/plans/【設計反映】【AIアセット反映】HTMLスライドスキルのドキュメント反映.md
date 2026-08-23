---
title: 【設計反映】【AIアセット反映】HTMLスライドスキルのドキュメント反映
type: plan
description: issue #168 フェーズ4の個別反映計画。spec新設・DDR2件の記録と、調査Q7で確定した既存ドキュメント5点への追記を行う
tags: [plan, slides, docs, ddr]
keywords: [反映計画, 設計反映, AIアセット反映, spec, DDR, directory-structure, docs-workflow, index, REVIEW-POINTS, usecase]
---

# 【設計反映】【AIアセット反映】HTMLスライドスキルのドキュメント反映

- issue: #168 ／ フェーズ4（flow-id 4-6 の個別反映計画。作成は 4-1）
- 上位計画: `wip/plans/html-slides-skill-plan.md`「フェーズ4〈反映〉」
- 入力: `wip/reports/2026-08-23_html-slides-skill-plan_前提調査.md`（Q4・Q7）・
  `wip/reports/2026-08-23_html-slides-skill-plan_AIアセット作成結果.md`（「設計への反映」）・
  worklog 2本
- 種別を併記する理由: 本セッションは非対話であり、フェーズ4内で合意を複数回に分けても人間の
  レビュー往復を挟めないため、設計反映（spec/DDR）とAIアセット反映（rules/index/REVIEW-POINTS）を
  1つの計画で合意対象にする。

## この計画で何をするか

フェーズ2・3で確定した意思決定と成果物を、永続ドキュメント（spec・DDR・rules・index・
REVIEW-POINTS）へ反映する。反映しないと、(1) 出力先・型名の決定理由がwip削除（flow-id 5-5）と
ともに失われ、(2) `directory-structure.md`「wip/reports/にはmdとhtmlの2種類」等の既存記述が
事実と食い違ったままmainへマージされる。

## 変更対象

### 設計反映（spec・DDR）

| # | ファイル | 内容 |
|---|---|---|
| 1 | `.claude/docs/spec/html-slides.md`（新設） | html-slidesスキルの正史仕様。背景・目的／仕様（成果物と置き場所・型8種とスキーマ契約・検査群・サブエージェント境界・動的検証の位置づけ）／影響範囲／設定項目（無し）／未決定事項（.pptx書き出し・サブエージェント実運転） |
| 2 | `.claude/docs/ddr/i0168-01-スライドの出力先はwip-reports既定とし恒久ディレクトリを新設しない.md`（新設） | 出力先の意思決定。却下案: 恒久ディレクトリ新設・.gitignore対象ローカル（調査Q4の比較表が根拠） |
| 3 | `.claude/docs/ddr/i0168-02-表紙スライドの型名はtitleでなくcoverにする.md`（新設） | 型名の意思決定。却下案: 調査Q5素案の `title`（フィールド名 `title` との衝突・3箇所同一使用の契約が根拠） |
| 4 | `.claude/docs/README.md` | `bash .claude/scripts/src/generate-ddr-list.sh` でDDR一覧を再生成（手書きしない）。spec一覧の節が手書きなら `html-slides.md` の行を追記 |

- 新規spec作成は本来「人間承認が必須」（docs-workflow.md）。非対話セッションのため、ユーザーの
  当初指示を包括承認として作成し、レビュー依頼（敵対的レビュー＋PR description）で明示する。
- DDRの識別子は issue #168 → `i0168-01`・`i0168-02`（4桁ゼロ埋め・枝番01から）。

### AIアセット反映（既存ドキュメントへの追記。調査Q7の5点）

| # | ファイル | 内容 |
|---|---|---|
| 5 | `.claude/rules/directory-structure.md` | ツリーへ `skills/html-slides/`（`assets/`・`references/` の内訳）と agents 2本の追記。「`wip/reports/` には**mdとhtmlの2種類**を置く」の段落へ `.slides.html`・`.slides.json`（スキル成果物。対応mdを持たない）を追記 |
| 6 | `.claude/rules/docs-workflow.md` | ライフサイクル表の `wip/reports/` 関連行の近くへ、`wip/reports/*.slides.html`＋`.slides.json`（html-slidesスキルの成果物。寿命は他のreports成果物と同じ、flow-id 5-5で削除）を追記 |
| 7 | `index.md`（Repository Map） | スキル列挙へ `/html-slides` を追加。`.claude/agents/` の説明（現状「issue-mr-flow途中引き継ぎ用」）をスライド用2本を含む記述へ更新 |
| 8 | `wip/reports/REVIEW-POINTS.md` | 適用範囲の注記を追加: `*.slides.html`・`*.slides.json` はスライド成果物であり、reports.template.html 前提の観点（結論カード・md同期等）は適用しない。スライドへ適用する検査は `.claude/skills/html-slides/SKILL.md` 手順5・6が正 |
| 9 | `.claude/docs/usecase/*.md`（8本） | 影響確認のみ（flow-id 4-6 の定め）。html-slidesに触れるべき既存記述・リンク切れが無いかを確認し、影響があれば更新、無ければ「影響なし」を反映結果レポートへ記録 |

## 方針

- **調査・作業の結論を転記するときは文言をそのまま引用し、変える場合は変更点と理由を明示する**
  （フェーズ3のレビューで学んだ再発防止策）。specの契約記述は作業結果レポートの対照表を正とする。
- DDRの本文は「検討したが✕✕を採用した」の型で、調査レポートの比較表（Q4・Q5）から根拠を引く。
  レポートはflow-id 5-5で消えるため、**DDR本文が単独で読める分量まで根拠を書き写す**。
- 過去の記録（specのchangelog・DDR本文）への機械的一括置換はしない（docs-workflow.mdの制限）。
- frontmatterは `markdown-frontmatter.md` の規約どおり（spec: type spec / ddr: type ddr）。
- 各mdの追記位置は、直前の節の地の文の係り先が変わらない位置を選ぶ（docs-workflow.mdの注意）。

## やらないこと（スコープ外）

- .pptx 書き出しの設計・実装（別issue。specの未決定事項として記録するに留める）
- `.gemini/` への変換同期（flow-id 5-3 で実施）
- wip配下の削除・HANDOFFリセット（flow-id 5-5）
- 既存DDR・既存specの本文変更（今回の反映はいずれも新設または追記）

## 検証

```bash
# 1. DDR一覧が生成物として更新され、差分がREADMEに限られること
bash .claude/scripts/src/generate-ddr-list.sh
git status --porcelain -- .claude/docs/README.md   # 変更が出る（追記後の再実行では出ない）

# 2. ドキュメント参照の破断が無いこと（0件が合格）
bash .claude/scripts/src/check-doc-references.sh

# 3. 新設3ファイルが frontmatter インデックスへ載ること（spec 1件・ddr 2件）
bash .claude/scripts/src/extract-frontmatter.sh .
grep -c '"concept_id":".claude/docs/spec/html-slides"' .claude/docs/spec/index.jsonl
grep -cE '"concept_id":".claude/docs/ddr/i0168-0[12]-' .claude/docs/ddr/index.jsonl   # 2

# 4. 追記5点が実際に入っていること（各1件以上）
grep -c 'html-slides' .claude/rules/directory-structure.md
grep -c 'slides' .claude/rules/docs-workflow.md
grep -c 'html-slides' index.md
grep -c 'slides' wip/reports/REVIEW-POINTS.md

# 5. 計画・レポートのHTMLビュー機械検査（プレースホルダ0・外部参照2種0件）
```

合格条件: 1〜4がすべて上記のとおり（2は検出0件）。5は md/html 作成のたびに実施。
usecase影響確認（対象9）は結果（影響なし／更新内容）を反映結果レポートへ件数付きで記録する。

## レビュー依頼で人間に確認してもらう項目

1. 新規spec `.claude/docs/spec/html-slides.md` の新設可否（本来は人間承認必須。包括承認で進めた）
2. DDR 2件の採用理由・却下案の妥当性
3. `wip/reports/REVIEW-POINTS.md` の適用範囲の線引き（スライドへ既存観点を適用しない判断）
