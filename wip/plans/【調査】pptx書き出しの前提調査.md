---
title: 【調査】pptx書き出しの前提調査
type: plan
description: issue #169 のフェーズ2個別調査計画。zip可用性・構成案JSONスキーマ依存範囲・最小OOXML構造・雛形の形態・6型の写像・検証手段の6問を実測で確定する
tags: [plan, research, pptx]
keywords: [調査計画, zip, OOXML, pptx, 雛形, スキーマ, slideN.xml, Content_Types, 検証]
---

# 【調査】pptx書き出しの前提調査

- issue: #169 / PR: #199 / フェーズ2 flow-id 2-1
- 上位計画: `wip/plans/json-to-pptx-export-plan.md`（フェーズ2の問いQ1〜Q6を具体化する）
- 作成日: 2026-08-23

## 目的

フェーズ3（実装）の設計を確定するために、次の6問へ実測ベースで答える。
**結果は本ファイルへは書かず** `wip/reports/2026-08-23_json-to-pptx-export-plan_前提調査.md`
（+同名.html）へ記録する（計画と実施結果の分離）。

## 調査項目

### Q1. zip相当の可用性と代替戦略（受け入れ条件1）

- この実行環境（Linux）: `zip`/`unzip`/`python3` の所在とバージョンを実測で記録する。
- ユーザー常用環境（Windows git bash）: 実機が無いため、Git for Windows の標準同梱物
  （既知の事実として `zip` 非同梱）を前提に、代替手段の優先順位を決める。
  - 比較対象: (a) `zip` コマンド、(b) python3 + `zipfile` モジュール、
    (c) PowerShell `Compress-Archive`（issue本文がOOXML破壊リスクを指摘）、
    (d) jar 等その他。
  - 決めるもの: 検出ロジック（`command -v` の優先順位）と、どれも無い場合の振る舞い
    （明示的なエラーで止める）。
- OOXMLのzip制約の確認: 先頭エントリ・圧縮方式・パス区切りが PowerPoint の読み込みに
  影響するか（`[Content_Types].xml` の位置、`/` 区切り、mimetype的な制約の有無）を、
  最小構成の実生成で確かめる。

### Q2. 構成案JSONスキーマの依存範囲（受け入れ条件7）

- PR #194 の調査レポートQ5（スキーマの方針）を精読し、.pptx側が依存する範囲を
  「type enum 8種＋各型の必須キー」に限定できるかを確認する。
- スキーマ具体化（PR #194 フェーズ3）前に着手するため、**こちら側で入力検証に使う
  必須キー集合**を定義し、PR #194 側が確定した際の突合方法（差分確認の手順）を決める。
- PR #194 の進捗を再確認する（フェーズ3でスキーマファイルが追加されていれば、それを正とする）。

### Q3. 最小OOXML構造（受け入れ条件3）

- 警告なく開く .pptx に必要なパーツ一覧を、実際に最小構成を組んで確定する:
  `[Content_Types].xml`・`_rels/.rels`・`ppt/presentation.xml`・`ppt/_rels/presentation.xml.rels`・
  `ppt/slideMasters/`・`ppt/slideLayouts/`・`ppt/theme/`・`docProps/core.xml`・`docProps/app.xml`・
  スライド本体とそのrels。
- スライド枚数が可変のとき連動して書き換える箇所（`[Content_Types].xml` の Override・
  `presentation.xml` の `sldIdLst`・`presentation.xml.rels`・`docProps/app.xml` の枚数）を列挙する。
- 検証: この環境で組んだ最小 .pptx を独立実装（python-pptx があれば導入せず標準ライブラリの
  zipfile+ElementTree で構造検査。LibreOffice があれば変換テスト）で開けるか確かめる。

### Q4. 雛形の形態

- 比較: (a) 展開ディレクトリ（XMLをGit管理し生成時にzip）、(b) バイナリ .pptx をリポジトリへ置く。
- 評価軸: 差分レビュー可能性／`.gitattributes`・配布への影響／PowerPoint製の雛形へ後から
  差し替えられるか／生成スクリプトの単純さ。
- issue本文は「雛形をPowerPointで作る」想定だが、この環境にPowerPointが無い。雛形の
  置き換え可能性（インターフェイス＝プレースホルダの規約）をどう設計するか決める。

### Q5. 8種のtype → スライドXML表現の写像（受け入れ条件6）

- 6型必須: `title`（表紙）・`section`（章扉）・`bullets`（箇条書き）・`two-column`（2カラム）・
  `table`（表）・`summary`（まとめ）→ テキストボックス `<p:sp>`（箇条書きは `<a:pPr>` の
  レベル）・表 `<a:tbl>` の対応を決める。
- 2型代替: `diagram`（図解）→ ノード・エッジの箇条書き表現、`comparison`（比較）→ 表表現、
  の写像案を決める。
- `speakerNotes` の扱い（notesSlide を出すか、フェーズ3のスコープに含めるか）を決める。

### Q6. 検証手段の切り分け（受け入れ条件3・4・5）

- この環境で機械検証できるもの: zip整合性（`unzip -t`/zipfile.testzip）・XML well-formed
  （ElementTree）・必須パーツの存在・Content_Types と実体の突合・テキストが `<a:t>` として
  存在すること（＝画像化されていないことの構造的証明）。
- 人間の実機確認に残すもの: PowerPointで警告なく開く・テキスト/表の編集操作。
  PRレビューへの依頼文面の要点を決める。

## やらないこと（スコープ外）

- 実装本体（スクリプト・SKILL.md）の作成（フェーズ3）
- PR #194 側成果物の変更

## 検証（この調査自体の完了条件)

- Q1〜Q6のすべてに、実測root（コマンドと出力）または「確かめられなかったこと」としての明記がある。
- 最小構成 .pptx の実生成と構造検査が再現可能なコマンドとして記録されている。
