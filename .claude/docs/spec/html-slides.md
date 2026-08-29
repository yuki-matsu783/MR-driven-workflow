---
title: html-slidesスキル（発表用HTMLスライド生成）
type: spec
description: 発表用HTMLスライド（PowerPoint風）を構成案JSONとテンプレート穴埋めの2段で生成するhtml-slidesスキル・スライドテンプレート・スキーマ・サブエージェント2本の仕様
tags: [spec, slides, skill, agents]
keywords: [HTMLスライド, html-slides, テンプレート, slides.template, スキーマ, slide-outline, サブエージェント, ページ送り, 印刷, pptx, 検査]
---

# html-slidesスキル（発表用HTMLスライド生成）

## 背景・目的

調査結果・作業結果・設計方針を人へ発表する場面で、レポートHTML（読み物）とは別に
スライド形式（1画面1トピック・ページ送り・投影/印刷前提）の資料が必要になる（issue #168）。
生成を**構成案JSON（内容）→ テンプレート穴埋め（表示）**の2段に分けるのは、

1. 構成の妥当性をHTMLより先にレビュー・機械検査できるようにするため、
2. 構成案JSONを将来の .pptx 書き出し（別issue）の入力にそのまま使えるようにするため
   （HTMLからの逆変換を避けるというissue本文の要求）。

## 仕様

### 構成要素

| ファイル | 役割 |
|---|---|
| `.claude/skills/html-slides/SKILL.md` | 手順6段（コピー→構成案→スキーマ検査→穴埋め→機械検査→任意の動的検証）の定義 |
| `.claude/skills/html-slides/assets/slides.template.html` | スライドテンプレート。**型8種の名前と見出し構成の正** |
| `.claude/skills/html-slides/references/slide-outline.schema.json` | 構成案JSON（`.slides.json`）のスキーマ（JSON Schema draft-07） |
| `.claude/agents/slide-outline-designer.md` | 構成設計サブエージェント（書き込みを行わない約束。構成案JSONだけを返す） |
| `.claude/agents/slide-html-generator.md` | HTML生成サブエージェント（構成案に忠実に穴埋め。再設計しない・食い違いは差し戻す） |

### 成果物と置き場所

- 既定: `wip/reports/日付_<全体計画名>_<内容を簡潔に>.slides.html` ＋ 同じベース名の
  `.slides.json`（必ず対で置く）。**対応するmdを持たない**（「mdが正文・HTMLは視覚化」の
  併存規約の例外。機械可読の対は構成案JSON）。
- 寿命は他の `wip/reports/` 成果物と同じ（flow-id 5-5 で削除。mainに残らない）。恒久保存したい
  場合は依頼元が `wip/` の外の置き場所を指定する（理由・却下案:
  `.claude/docs/ddr/i0168-01-スライドの出力先はwip-reports既定とし恒久ディレクトリを新設しない.md`）。

### 型8種とスキーマ契約

- 型は `cover` / `section` / `bullets` / `two-column` / `diagram` / `table` / `comparison` /
  `summary` の8種。**テンプレートの `data-type`・スキーマの `type` enum・サブエージェント2本の
  受け渡し契約の3箇所で同一の文字列**を使う（表紙を `title` としない理由:
  `.claude/docs/ddr/i0168-02-表紙スライドの型名はtitleでなくcoverにする.md`）。
- トップレベルは `{meta: {title, subtitle, date, author, issue}, slides[]}`。全型が任意の
  `speakerNotes` を持つ（.pptx のノート・ドキュメントプロパティに対応）。cover の
  `title`/`subtitle` は任意（省略時は `meta` から採る）。
- スキーマに**HTML固有の表現（色・レイアウト座標・CSSクラス）を含めない**。見た目の指定は
  comparison の `tone`（pro/con/neutral）のような抽象値までとし、クラスへの対応は
  テンプレート側の見本コメントが定義する。
- SKILL.md の検査は型名の文字列を再掲せず、**スキーマの `oneOf` の `$ref` から導出する**
  （`definitions | keys` は `speakerNotes` を含むため使わない）。

### テンプレートの表示仕様

- 自己完結（CDN・外部フォント・画像への参照ゼロ）。`:root` CSS変数＋
  `prefers-color-scheme: dark`。
- ページ送り: ←→・Space/PageDown・PageUp・Home/End・画面左右30%のクリック。進行表示
  `.progress`・操作ヒント `.nav-hint` は削除可（JSは要素の有無を確認するガード付きで、
  スライド0枚・`.progress` 欠落でも例外で止まらない）。
- 印刷: `@media print` で1スライド=1ページ。**`:root` をライトパレットへ上書き**するため、
  画面がダークモードでも印刷・PDFは常にライト配色。
- あふれ対策: `.slide` は `justify-content: safe center`（上端を守る）。あふれ自体は許さず
  構成側で枚数を分ける（動的検証に `scrollHeight > clientHeight` のスライド0枚の検査がある）。

### 検査

- 静的（SKILL.md 手順3・5）: 空チェック→jq構造検査（`ok=$?` を必ず出力。0枚も不合格）、
  プレースホルダ残存0、外部参照grep2種0件、出力 `data-type` とスキーマ由来リストの照合、
  枚数一致（`COUNT_OK`）。
- 動的（手順6・任意）: node＋Playwright＋Chromium が使える環境でのみ、ページ送り・
  `page.pdf()` のページ数一致・あふれスライド0枚を実測する。使えない環境では
  「未実施1件（環境なし）」の形で件数を出して報告する（無言のスキップをしない）。
- **検査対象の文字列をテンプレートのコメント・説明文へ書くと検査が誤検知する。**
  実例: 冒頭コメントに `data-type="..."` の記法例を書いたところ、型8種の一意数検査が
  9を返した（issue #168 のフェーズ3で実測。コメントを「section要素の data-type 属性で
  型を示す」という表現へ変えて回避）。テンプレート・見本コメントを編集する際は、
  検査のgrepパターンに一致する文字列を地の文へ置かない。

### サブエージェント境界

| | slide-outline-designer | slide-html-generator |
|---|---|---|
| tools | Read, Grep, Glob, Bash | ＋Write（Editは持たない） |
| しないこと | HTMLの生成・元資料の変更 | 構成の再設計・スキーマの変更 |
| 食い違い時 | — | 生成せず呼び出し元へ差し戻す |

「書き込みを行わない」「新規書き出しのみ」は、いずれも**エージェント定義本文の指示による
約束であり、ツール権限では強制されない**（両者ともBashを持つため、技術的には書き込み・削除が
可能）。ツール権限で担保されているのは、generatorがEditを持たない（既存ファイルの部分編集は
できない）ことまでである。

## 影響範囲

- 配布・変換同期（dist-layers.json・check-dist-coverage.sh・sync-gemini-assets.sh・
  extract-frontmatter.sh）の**設定変更は不要**（フェーズ2調査で実測確認。エージェント定義は
  ホワイトリスト対象キー1行値・`GEMINI_TOOL_PAIRS` 内のtoolsという変換制約に従っている）。
- `wip/reports/` へ新しい拡張子（`.slides.html`/`.slides.json`）が置かれるため、
  「mdとhtmlの2種類」と述べる既存ドキュメント（`directory-structure.md`・`docs-workflow.md`・
  `deliverables.md`・`index.md`・`issue-mr-workflow.md`）とレビュー観点
  （`wip/reports/REVIEW-POINTS.md`）へ例外の注記を追記した（issue #168 フェーズ4）。

## 設定項目

無し（`.mrworkflow.json` 等への追加設定は持たない）。

## 未決定事項・懸念点

- **.pptx 書き出し**: 構成案JSONを入力にできる状態にするまでが issue #168 のスコープ。
  変換の実装は別issue。
- **サブエージェント2本の実運転**: フェーズ3の検証はSKILL.mdの手順をセッションが代行して
  行った（定義の静的検査・変換制約・インデックス掲載は合格）。Agentツールでの実起動
  （構成案の品質・差し戻し動作・機械検査の自走）は初回の実利用で確認する。
- 検査コマンド群はLinux（Claude Code on the web）での実測のみ。git bash実機は未計測。
  Windows版jqのCR付与（`.claude/rules/shell-script-style.md`「文字コード」節）については、
  手順5の `data-type` 照合の複数行 `jq -r` 出力へ `tr -d '\r'` を挟む対処を適用済み
  （issue #168 フェーズ4の敵対的レビュー指摘）。
- **型名3箇所（テンプレート・スキーマ・サブエージェント契約）の同期は人手で担保しており、
  ずれを検出する機械検査・テストを持たない。** SKILL.md手順5の照合は「出力HTML対スキーマ」で
  あり、テンプレート対スキーマの直接照合ではない。ずれを疑うときは
  `grep -oE 'data-type="[^"]+"' <テンプレート> | sort -u` とスキーマの `$ref` 導出リストを
  突き合わせて確認する。

## 変更履歴

- issue #168: 新規作成（スキル・テンプレート・スキーマ・サブエージェント2本の追加）。
  あわせて `.claude/VERSION` を 0.4.0 → 0.5.0 へ増分した（layer=core の配布対象アセットの
  追加のため、`distribution-assets.md` の目安表で MINOR。非対話セッションのためAIが適用し、
  記録を本changelogと `HANDOFF.md`「判断を迷った内容」へ残した）。
