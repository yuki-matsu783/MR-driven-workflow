---
name: html-slides
description: 発表用HTMLスライド（PowerPoint風）を作成するために使う。調査結果・作業結果・設計方針などを人へ発表する資料が必要な場面で、自己完結HTMLのスライド（キーボード/クリックでページ送り・進行表示・印刷で1スライド1ページ）と、その元になる構成案JSON（将来の .pptx 書き出しの入力になる形）を対で生成する。構成の設計は slide-outline-designer サブエージェント、HTMLへの穴埋めは slide-html-generator サブエージェントへ委譲できる。
title: HTMLスライド作成
type: skill
tags: [slides, html, presentation, agents]
keywords: [スライド, 発表, プレゼン, テンプレート, 構成案, スキーマ, ページ送り, 進行表示, 印刷, pptx, サブエージェント]
---

# html-slides スキル

発表用のHTMLスライドを、**構成案JSON（内容）→ テンプレート穴埋め（表示）**の2段で作る
（issue #168）。内容と表示を分けるのは、構成の妥当性をHTMLより先にレビュー・機械検査できる
ようにするためと、構成案JSONを将来の .pptx 書き出しの入力にそのまま使えるようにするためである。

## 成果物と置き場所

| 成果物 | パス |
|---|---|
| スライドHTML | `wip/reports/日付_<全体計画名>_<内容を簡潔に>.slides.html`（既定。ほかの用途では依頼元の指定に従う） |
| 構成案JSON | 上と同じベース名の `.slides.json`（必ず対で置く） |

- **既定の出力先 `wip/reports/` は flow-id 5-5 で削除され、mainには残らない**（他の
  `wip/reports/` 成果物と同じ寿命）。発表後も恒久的に残したいスライドは、依頼元が
  `wip/` の外の置き場所を指定すること。
- テンプレート: `.claude/skills/html-slides/assets/slides.template.html`
- スキーマ: `.claude/skills/html-slides/references/slide-outline.schema.json`
- **スライド型8種の名前と見出し構成の正はテンプレート側**（`data-type` とスキーマの `type` は
  同一のenum）。本ファイルには再掲しない。

## 手順

1. **テンプレートを出力先へコピーする**（`cp`。テンプレート自体は編集しない）。
2. **構成案JSON（`.slides.json`）を作る。** 発表テーマ・元資料・目安枚数が入力。
   自分で書いてもよいが、元資料の読解が要る場合は `slide-outline-designer` サブエージェントへ
   委譲する（読み取り専用。構成案JSONだけを返し、HTMLは生成しない）。
3. **スキーマ検査を通す。** 空チェックを jq より先に置く（空入力は `jq -e` が検知できない
   ことがある）。型名の一覧はスキーマから導出する（正を1箇所に保つ。`definitions | keys` は
   `speakerNotes` を含むため使わない）。

   ```bash
   outline="<構成案JSONのパス>"
   SCHEMA=".claude/skills/html-slides/references/slide-outline.schema.json"
   known="$(jq -c '[.properties.slides.items.oneOf[]."$ref" | sub(".*/";"")]' "$SCHEMA")"
   [ -s "$outline" ] && jq -e --argjson known "$known" 'has("meta") and (.meta|has("title")) and
     ((.slides | length) > 0) and
     ([.slides[].type] | all(. as $t | ($known | index($t)) != null))' "$outline" >/dev/null; echo "ok=$?"
   ```

   `ok=0` が合格（実測: 正常=0／型名不正=1／空ファイル=1／0枚=1）。これは最小限の構造検査
   （メタ情報・型名・1枚以上）。型ごとの必須フィールドはスキーマ本体を参照して確認する。
4. **テンプレートを穴埋めする。** 構成案の各要素を、同じ `data-type` の見本の複製へ転記する
   （`speakerNotes` は `<aside class="notes">` へ）。`slide-html-generator` サブエージェントへ
   委譲できる（**構成案に忠実に埋める。構成の再設計はしない。** 構成案の `type` がテンプレートに
   無い等の食い違いは、生成せず呼び出し元へ差し戻す）。
5. **機械検査を通す。** いずれもスライドHTMLに対して実行する。

   ```bash
   out="<スライドHTMLのパス>"
   outline="<構成案JSONのパス>"
   SCHEMA=".claude/skills/html-slides/references/slide-outline.schema.json"
   # プレースホルダ残存（0が合格）
   grep -c '<!-- ここに書く' "$out"
   # 外部参照（2種とも0件=フォールバック文言が出るのが合格）
   grep -nE "(src|href)=['\"]?(https?:)?//" "$out" || echo EXT_REF_NONE
   grep -nE "(url\(|@import[[:space:]]+)['\"]?(https?:)?//" "$out" || echo EXT_CSS_NONE
   # 出力の data-type が全てスキーマの型8種のいずれか（出力なしが合格）
   grep -oE 'data-type="[^"]+"' "$out" | sed 's/.*="//; s/"$//' | sort -u |
     comm -23 - <(jq -r '.properties.slides.items.oneOf[]."$ref" | sub(".*/";"")' "$SCHEMA" | sort)
   # スライド枚数が構成案と一致（COUNT_OK が出るのが合格）
   test "$(grep -c '<section class="slide"' "$out")" = "$(jq '.slides | length' "$outline")" && echo COUNT_OK
   ```
6. **動的検証（任意）。** node と Playwright＋Chromium が使える実行環境（例: Claude Code on
   the web のリモート実行環境）でのみ、ヘッドレスブラウザでページ送りと印刷を実測する。
   **使えない環境では実行せず、「動的検証: 未実施1件（環境なし）。代替: 手順5の静的検査」の形で
   件数を出して報告する**（無言のスキップはしない）。検証スクリプトはscratchpad等の一時領域に
   置き、リポジトリへはコミットしない。確認するのは (a) キー送出で進行表示（`.progress`）が
   進むこと、(b) `page.pdf()` のページ数がスライド枚数と一致すること、
   (c) `scrollHeight > clientHeight` のスライドが0枚であること（内容あふれは `overflow: hidden`
   により無言で切り落とされ、静的検査では検出できない）、の3点。印刷・PDFは `@media print` が
   `:root` をライトパレットへ上書きするため、OSがダークモードでもライト配色で出力される
   （ダーク検証は `page.emulateMedia({ colorScheme: 'dark' })` を併用する）。

## サブエージェントとの境界

| | slide-outline-designer（構成設計） | slide-html-generator（HTML生成） |
|---|---|---|
| 入力 | 発表テーマ・元資料パス・目安枚数 | 構成案JSONのパス・テンプレートのパス・出力先 |
| 出力 | 構成案JSON（スキーマ適合を自分で確認して返す） | スライドHTML（手順5の機械検査を自分で実行して返す） |
| しないこと | **HTMLの生成**・元資料の変更 | **構成の再設計**（項目の追加・削除・並べ替え）・スキーマの変更 |
| 食い違い時 | — | 生成せず呼び出し元へ差し戻す |

## 人間に確認してもらう項目

機械検査では代替できないため、成果物のレビュー依頼へ次の3点を明記する。

1. 見た目の品質（文字の大きさ・投影時の視認性）
2. 実プリンタでの印刷（1スライド1ページに収まるか）
3. Chromium以外のブラウザでの表示・ページ送り
