---
title: 【実装】【テスト】pptx-slidesスキルの作成
type: plan
description: issue #169 のフェーズ3個別作業計画。構成案JSONから編集可能な .pptx を生成する pptx-slides スキル（SKILL.md・生成スクリプト・展開ディレクトリ雛形）と単体テストを作成する
tags: [plan, implementation, pptx]
keywords: [作業計画, pptx-slides, json-to-pptx, OOXML, 雛形, zip, jq, 単体テスト, rId採番]
---

# 【実装】【テスト】pptx-slidesスキルの作成

- issue: #169 / PR: #199 / フェーズ3 flow-id 3-1
- 作成日: 2026-08-23

## 前提（合意状況）

- 上位計画: `wip/plans/json-to-pptx-export-plan.md`。フェーズ2〈調査〉は完了し、設計の根拠は
  調査レポート `wip/reports/2026-08-23_json-to-pptx-export-plan_前提調査.md`（以下「調査レポート」）
  のQ1〜Q6の結論とする。
- flow-id 2-8/2-9（人間のレビュー往復）と調査レポートの◆3件（雛形方針・speakerNotes採否・
  完了条件の一部未達のままの進行可否）は**人間の回答を得ていない**。人間のレビュー往復を
  待てないセッションのため、ユーザーの当初指示（PR作成＋各フェーズの計画時・作業実施毎の
  敵対的レビュー自動実施）を包括承認として、下記「◆未回答のまま進めるための判断」を仮決めして
  進める（レビューで覆れば本計画ごと修正する）。

### ◆未回答のまま進めるための判断（仮決め。レビューで覆せる）

| ◆ | 仮決め | 理由 |
|---|---|---|
| Q4 雛形方針 | 手組みの展開ディレクトリで進める | 調査レポートの比較検討どおり。PowerPoint製への差し替えは前処理条件をspecへ残すのみで、実装はスコープ外 |
| Q5 speakerNotes | **フェーズ3では出力しない**（SKILL.mdへ「speakerNotesは出力されない」と明記し、条件7突合の対象外リストへ `speakerNotes` を入れる） | 連動コストがスライド枚数に比例して2種類増える（調査レポートQ5）割に、テキストの編集可能性という受け入れ条件の本筋に寄与しない。後続issueで追加できる形（notesSlideを持たない構成は追加に対して開いている）を保つ |
| 完了条件未達 | PowerPoint実機確認（Q6の依頼文面）を代替として進める | この環境ではOOXMLフルパーサが使用不能（実測済み）。実機確認はPRレビューの必須依頼事項として明示する |

## 目的

構成案JSON（issue #168 / PR #194 と同じ入力）から、テキスト・表が編集可能な .pptx を生成する
スキル一式を作成する。**結果は本ファイルへは書かず**
`wip/reports/2026-08-23_json-to-pptx-export-plan_実装.md`（+同名.html）へ記録する。

## 作業項目

### 1.【実装】雛形 `assets/pptx-template/`（展開ディレクトリ）

調査レポートQ3の2枚構成15パーツのうち、**生成スクリプトが所有しない静的パーツ**を
`.claude/skills/pptx-slides/assets/pptx-template/` へ置く:

```
_rels/.rels
docProps/core.xml                # プレースホルダ置換の対象（下記「meta の写像」）
ppt/slideMasters/slideMaster1.xml
ppt/slideMasters/_rels/slideMaster1.xml.rels
ppt/slideLayouts/slideLayout1.xml
ppt/slideLayouts/_rels/slideLayout1.xml.rels
ppt/theme/theme1.xml
```

- **雛形に含めない（生成スクリプトが丸ごと所有する）パーツ**: `[Content_Types].xml`・
  `ppt/presentation.xml`・`ppt/_rels/presentation.xml.rels`・`docProps/app.xml`・
  `ppt/slides/**`（調査レポートQ3の連動5箇所＋rId採番規則のとおり）。
- スライドサイズは16:9（`sldSz cx="12192000" cy="6858000"`）。テーマは調査で機械検証済みの
  フルセット（clrScheme・fontScheme・fmtScheme）を使う。

### 2.【実装】生成スクリプト `scripts/json-to-pptx.sh`

`.claude/skills/pptx-slides/scripts/json-to-pptx.sh`。構造は調査レポート「設計への反映」1のとおり:

1. **入力検証**: jqで必須キー検査（調査レポートQ2の必須キー表。type enum 8種・title全型必須・
   型別必須キー。表に無いキーは無視する）。違反はキー名を挙げて明示エラー・非0終了。
2. **slideN.xml 生成**: type別写像（調査レポートQ5の表。cover/section/bullets/two-column/
   table/summary はテキストボックス `<p:sp>`＋表 `<a:tbl>`、diagram→箇条書き代替、
   comparison→表代替）。
3. **連動5箇所の生成**: `[Content_Types].xml`・`presentation.xml`（sldIdLst）・
   `presentation.xml.rels`（rId1=slideMaster・rId2=theme予約、スライドはrId3から連番）・
   `docProps/app.xml`（Slides枚数）・スライド毎rels。
4. **zip梱包**: 能力ベース検出（`zip -X -D -r` が使え生成後検証が通る → 経路1／
   `python3`→`python`→`py -3` の順に `import zipfile` 成否 → 経路2／どちらも無ければ
   明示エラー）。`[Content_Types].xml` を先頭に格納。
5. **自己検証**: zip整合性＋必須パーツ存在。失敗したら**出力ファイルを削除して非0終了**。

決めごと:

- CLI: `bash json-to-pptx.sh <入力.json> [出力.pptx]`。出力省略時は入力と同じディレクトリの
  `<ベース名>.pptx`（入力名が `<ベース名>.slides.json` なら `.slides` も落とす）。
- **XMLエスケープ**: JSONの全テキスト値は `&` `<` `>` `"` `'` をエスケープしてから
  XMLへ埋める（jqの `@html` は `'` を実体参照化しないため自前の置換で5種を揃える。
  エスケープ関数は純粋関数として切り出し単体テスト対象にする）。
- **テキスト中の改行**: `<a:t>` は改行を保持しないため、値内の改行は `<a:br/>` ではなく
  段落分割（複数 `<a:p>`）で表現する（bullets等の配列要素と同じ構造に揃える）。
- **meta の写像**: `meta.title`→`docProps/core.xml` の `dc:title`、`meta.author`→`dc:creator`、
  `meta.date`→本文には出さず `cover` スライドのサブタイトル行、`meta.issue`→`cp:keywords`
  （docProps行き。条件7突合の対象外リストどおり）。core.xml はプレースホルダ置換
  （`__PPTX_TITLE__` 等の固定トークン）で埋める。
- **シェル規約**: `.claude/rules/shell-script-style.md` に従う（`set -euo pipefail`・
  ループ内で外部コマンドを呼ばずjq呼び出しをスライド単位以下へ集約・`REPLY`返し・
  BOM無しUTF-8/LF・`--argjson`へ大きなJSONを渡さずファイルパス渡し）。

### 3.【AIアセット作成に相当する実装】`SKILL.md`

`.claude/skills/pptx-slides/SKILL.md`（frontmatter: name/description/title/type/tags/keywords）。
内容: 入力（構成案JSONのパスと必須キー）・実行方法・出力・**speakerNotesは出力されない**旨・
制約（PowerPoint実機確認をレビューで依頼すること・Windows git bashでの検出経路）・
PR #194 スキーマ確定時の突合（調査レポートQ2の手順への参照）。
命名 `pptx-slides` は調査レポートQ5で確定済み（html-slides と対になる機能名詞）。

### 4.【テスト】単体テスト `test_json_to_pptx.sh`

`.claude/scripts/test/test_json_to_pptx.sh`（`passed=N failures=N` 規約・失敗時終了コード1）。

- **正常系（機械検証10種**（調査レポートQ6。検証8種＋a:tbl存在＋条件7突合）**）**:
  8種type全部入り・**スライド3枚以上**のサンプルJSON（テスト内でヒアドキュメント生成）で
  .pptx を生成し、10種を検査する。条件7突合は「入力JSONの葉テキスト値ごとの部分一致
  （全 `<a:t>` 連結文字列へ）。対象外= `meta.issue`・`speakerNotes`」で実装する。
- **異常系**: type不正／必須キー欠落（title欠落を含む）／空slides／入力ファイル無し／
  zip・python3両不在の明示エラー（PATH差し替えスタブ）／**生成失敗時に出力ファイルが
  残らないこと**。
- **純粋関数の単体**: XMLエスケープ関数（5種の特殊文字・改行・日本語）。
- python3経路のテスト: この環境では両経路が実行可能なため、`zip` をPATHから隠した状態で
  経路2に落ちること＋生成物が検証を通ることを確認する。

## やらないこと（スコープ外）

- speakerNotes（notesSlide/notesMaster）の出力（上記の仮決め。SKILL.mdへ明記する）
- PowerPoint製雛形への差し替え機能の実装（前処理条件の記録はフェーズ4のspecで行う）
- PR #194 側成果物（html-slides・スキーマファイル）の変更
- spec/DDR・`.gemini/` 変換同期（フェーズ4・5の担当）

## 検証（この作業自体の完了条件）

- 全 `.sh` が `bash -n` を通る。
- `bash .claude/scripts/test/test_json_to_pptx.sh` が `failures=0` で通り、その出力を
  結果レポートへ生のまま貼る。
- 8種type全部入りサンプルから生成した .pptx が機械検証10種に合格する（両zip経路とも）。
- 既存テストへの影響が無い（`.claude/scripts/test/` の既存テストが引き続き通ることを、
  変更が波及しうるもの（無ければ実行対象なしと記録）について確認する）。
- PowerPoint実機・Windows git bash実機の確認は本フェーズでは行えない（調査レポートQ6の
  依頼文面でPRレビューへ依頼する。結果レポートへ依頼事項として明記する）。
