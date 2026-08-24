---
name: pptx-slides
description: スライド構成案JSON（html-slidesスキルと同じ入力。issue #168のスキーマ）から、テキスト・表がPowerPointで編集可能な .pptx ファイルを生成するために使う。「構成案をパワポにして」「pptxで書き出して」のように、スライドをHTMLではなくPowerPoint形式で欲しい場面で呼び出す。生成は雛形（OOXMLパーツ）＋slideN.xml生成＋zip再梱包方式で、zipコマンドが無い環境ではpythonのzipfileへ自動フォールバックする。
title: 構成案JSONからのpptx書き出し
type: skill
tags: [pptx, slides, skill, ooxml]
keywords: [pptx, PowerPoint, スライド, 構成案JSON, OOXML, zip, 雛形, json-to-pptx, 編集可能]
---

# pptx-slides スキル

スライド構成案JSON（issue #168 / `html-slides` スキルと同じ入力）から、**テキスト・表が
PowerPointで編集可能な** `.pptx` を生成する（issue #169）。スライドの内容はすべて
テキストボックス（`<p:sp>`）とネイティブ表（`<a:tbl>`）として出力され、画像化されない。

## 実行方法

```bash
bash .claude/skills/pptx-slides/scripts/json-to-pptx.sh <入力.json> [出力.pptx]
```

- 出力を省略すると、入力と同じディレクトリの `<ベース名>.pptx` になる
  （`deck.slides.json` → `deck.pptx`。既存の同名ファイルは上書きする）。
- 生成に成功すると `生成しました（スライドN枚・経路=...）` を表示して終了コード0。
  失敗時は**明示エラーを出して非0で終了し、壊れた .pptx を残さない**（生成後に
  zip整合性＋必須パーツ存在の自己検証を行い、失敗したら出力を削除する）。

## 入力（構成案JSONの必須キー）

- `meta.title`（文字列・必須）と `slides`（配列・1件以上・必須）。
- 各スライドは `type`（8種enum: `cover` `section` `bullets` `two-column` `diagram`
  `table` `comparison` `summary`）と `title`（全型必須）を持つ。
- 型別の必須キー: `bullets`/`summary`→`items[]`、`two-column`→`left`/`right`、
  `table`→`headers[]`/`rows[][]`、`comparison`→`options[]`、`diagram`→`nodes[]`
  （`edges` は任意）。**表に無いキーは無視する**（過剰なキーで失敗しない）。
- 違反はキー名を挙げた明示エラーになる。

## スライド型の表現

| type | 表現 |
|---|---|
| `cover` | タイトル大＋サブタイトル行（`meta.subtitle`・`meta.date`・`meta.author`） |
| `section` | 章タイトル大（中央帯） |
| `bullets` / `summary` | 見出し＋箇条書き（入れ子1段） |
| `two-column` | 見出し＋左右2つの本文ボックス |
| `table` | 見出し＋ネイティブ表（1行目強調） |
| `comparison` | 見出し＋表（列=候補、行=利点/欠点/採否）による代替表現 |
| `diagram` | 見出し＋ノード箇条書き＋「A → B（ラベル）」のエッジ列挙による代替表現 |

- `meta.title` はドキュメントプロパティ（`dc:title`）へ、`meta.issue` は `cp:keywords` へ
  入り、スライド上には現れない。

## 制約・注意

- **speakerNotes は出力されない。** 入力に `speakerNotes` 付きスライドがあると、
  標準エラーへ件数付きの警告を出す（処理は継続する。ノートが必要になったら
  後続issueで notesSlide 対応を追加する）。
- zip梱包は `zip -X -D -r` → `python3`/`python`/`py -3` の `zipfile` の順に**能力ベース**
  （実際に生成→検証が通るか）で試し、どの経路も使えなければ明示エラーで止まる。
  Windows git bash で `zip` が無い環境でも、python が入っていれば動く。
- **生成した .pptx をPRに含めるときは、PowerPoint実機での確認（警告なく開く・テキストと
  表が編集できる）をレビューで依頼すること**（この環境ではOOXMLフルパーサでの検証が
  できないため。機械検証はzip整合性・XML well-formed・パーツ突合まで）。
- 構成案JSONのスキーマ確定（issue #168 / PR #194）後の突合手順は
  `.claude/docs/spec/pptx-slides.md` を参照する（issue #169 のフェーズ4で作成）。

## バンドルリソース

| パス | 役割 |
|---|---|
| `scripts/json-to-pptx.sh` | 生成スクリプト本体 |
| `scripts/slides-to-records.jq` | 構成案JSON→レコードストリーム変換（入力検証を含む） |
| `assets/pptx-template/` | 展開ディレクトリ形式のOOXML雛形（静的パーツのみ。`[Content_Types].xml`・`presentation.xml`・`presentation.xml.rels`・`app.xml`・`ppt/slides/**` はスクリプトが生成する） |

単体テスト: `bash .claude/scripts/test/test_json_to_pptx.sh`
