---
title: pptx-slides（構成案JSONからのpptx書き出し）
type: spec
description: スライド構成案JSONから編集可能な .pptx を雛形展開ディレクトリ＋zip再梱包方式で生成する pptx-slides スキルの仕様。入力検証・type別写像・rId採番・zip経路試行・自己検証・条件7突合の正史
tags: [pptx, slides, ooxml, spec]
keywords: [pptx, PowerPoint, OOXML, json-to-pptx, slide-outline, スキーマ, zip, 雛形, rId, 自己検証, 突合, patsub_replacement]
---

# pptx-slides（構成案JSONからのpptx書き出し）

## 背景・目的

- issue #169。スライド構成案JSON（issue #168 / `html-slides` スキルと同じ入力）から、
  **テキスト・表がPowerPointで編集可能な** `.pptx` を生成する。内容はすべてテキストボックス
  （`<p:sp>`）とネイティブ表（`<a:tbl>`）で出力し、画像化しない。
- 生成方式は「雛形（展開ディレクトリ形式のOOXML静的パーツ）＋ `ppt/slides/slideN.xml` 生成＋
  zip再梱包」。python-pptx等の新規外部依存を持たない（却下案の記録は DDR i0169-01）。
- **この仕様の新規作成はAIエージェントが非対話セッションで行っており、人間の承認を
  得ていない**（issue #169 のPR #199 レビューで承認を依頼中。承認までは暫定の正史）。

## 仕様

### 構成

| パス | 役割 |
|---|---|
| `.claude/skills/pptx-slides/SKILL.md` | スキル定義（実行方法・入力・型別表現・制約） |
| `.claude/skills/pptx-slides/scripts/json-to-pptx.sh` | 生成本体（bash） |
| `.claude/skills/pptx-slides/scripts/slides-to-records.jq` | 入力検証＋レコードストリーム変換（実行あたりjq起動1回） |
| `.claude/skills/pptx-slides/assets/pptx-template/` | 雛形（静的パーツのみ。`[Content_Types].xml`・`presentation.xml`・同rels・`app.xml`・`ppt/slides/**` はスクリプトが生成） |
| `.claude/scripts/test/test_json_to_pptx.sh` | 単体テスト |

### 入力仕様（確定スキーマとの対応）

入力の正は構成案JSONスキーマ
`.claude/skills/html-slides/references/slide-outline.schema.json`（issue #168。PR #194で確定）。
本スキルの検証はjq（`slides-to-records.jq`）の必須キー・要素型検査で行い、**スキーマファイル
自体は実行時に読まない**（依存を検査ロジックへ閉じる。スキーマとの同期は単体テストの
jq適合チェックが固定する）。

| 対象 | 検証内容 |
|---|---|
| meta | `title`（文字列・必須）。`issue` は integer（docPropsへは文字列化して入る） |
| slides | 配列・1件以上 |
| type | 8種enum（cover/section/bullets/two-column/diagram/table/comparison/summary） |
| title | **coverのみ任意**（省略時 `meta.title`）。他の7型は必須。coverで書く場合も文字列 |
| bullets/summary | `items[]` 1件以上・各要素は文字列 |
| two-column | `columns[]` ちょうど2件・各要素は `heading`（文字列）＋`items[]`（1件以上）を持つオブジェクト |
| table | `columns[]` 1件以上＋`rows[][]`（各行は配列） |
| comparison | `sides[]` 2〜3件・各要素は `name`（文字列）＋`points[]`（1件以上）を持つオブジェクト。`tone`（pro/con/neutral）は任意 |
| diagram | `nodes[]` 2件以上・各要素は `label`（文字列）を持つオブジェクト。`note` は任意 |

- 違反は**キー名を挙げた明示エラー**（複数件をまとめて表示）・非0終了。
- 表に無いキーは無視する（スキーマの `additionalProperties: false` より緩い超集合。
  過剰キーで失敗しない）。逆にスキーマが持たない形（bulletsの入れ子オブジェクト・
  diagramのedges/caption・旧語彙 headers/options/left/right）は**受け付けない**
  （issue #169 フェーズ4でスキーマ確定に追従し、検証・分岐ごと削除した）。

### type別写像（8種）

| type | 表現 |
|---|---|
| cover | 見出し大 = `title // meta.title`。サブタイトル行 = `subtitle // meta.subtitle`・`meta.date`・`meta.author` |
| section | `chapter`（任意）を見出しの上の小さめ段落＋章タイトル大（中央帯） |
| bullets | 見出し＋箇条書き |
| summary | 見出し＋箇条書き＋`takeaway`（任意）を太字段落 |
| two-column | 見出し＋左右2つの本文ボックス。各カラムは `heading` の太字段落＋`items` の段落。`columns[0]`→左・`columns[1]`→右に固定 |
| table | 見出し＋ネイティブ表（`<a:tbl>`。1行目強調） |
| comparison | 見出し＋表による代替表現。列 = 各side（ヘッダ = `name`＋tone注記）、行 = `points` の転置（不足セルは空埋め） |
| diagram | 見出し＋`label` を「 → 」で連結したフロー1段落＋`note` を持つノードごとの「label: note」行（箇条書き記号なしの段落） |

- `tone` の写像: pro→「（採用寄り）」・con→「（却下寄り）」・neutral→「（中立）」を
  `name` の後置注記として出す。**値そのもの（pro/con/neutral）は出力に現れない。**
- `meta.title`→`docProps/core.xml` の `dc:title`、`meta.author`→`dc:creator`、
  `meta.issue`→`cp:keywords`（文字列化）。
- speakerNotes は出力しない。入力にあれば標準エラーへ件数付き警告（処理は継続）。
  notesSlide対応は後続issue（連動がスライド枚数比例で2種類増えるため切り出した）。

### レコードストリーム（jq→bashのインターフェイス）

`slides-to-records.jq` が US（0x1F）区切り・1行1レコードで出力し、bash側が1パスで読む
（種別と形式の正は同ファイル冒頭のコメント）。種別: ERR/HDR/NOTEWARN/SLIDE/TITLE/SUB/
CHAP/BUL/COLH/COL/PARA/TROW。

- **jqの終了コードは一時ファイル経由で検知する**（`jq ... > "$tmp/records"` して非0なら
  明示エラー）。プロセス置換 `< <(jq ...)` は途中失敗が伝わらず「内容の欠けた .pptx を
  成功として出力する」形になる（実測）。コマンド置換・`--argjson` を使わないのは
  レコードが入力サイズに比例するため（`.claude/rules/shell-script-style.md`「JSON操作」）。
- **制御文字の空白化**: XML 1.0が許さないC0制御文字（TAB/LF/CR以外）はjq側 `clean` で
  空白へ置換する。CRは除去、改行は段落分割（表セル・docProps行きの値のみ空白化）。
- **表の列数は全行（ヘッダ含む）の最大セル数**で決定する（TROWはバッファへ溜め、
  `flush_slide` で確定）。不足セルは空埋め・超過セルは切り捨てない。全行が実質空なら
  「表の列数を決定できません」の明示エラー（先頭行基準はゼロ除算・無言の切り捨てを
  生んだため廃止。フェーズ3の敵対的レビューで検出）。

### rId採番規則と連動5箇所

- `ppt/_rels/presentation.xml.rels`: rId1=slideMaster・rId2=theme を**予約**し、
  スライドは rId3 から連番。`sldIdLst` の id は256から連番。
- スライド枚数に連動して生成するのは5箇所: (1) スライド毎の `slideN.xml.rels`、
  (2) `[Content_Types].xml` のスライドOverride、(3) `presentation.xml` の `sldIdLst`、
  (4) `ppt/_rels/presentation.xml.rels` のスライドRelationship、(5) `docProps/app.xml` の
  `Slides` 枚数。

### zip経路試行と自己検証

- 経路は `zip -q -X -D -r` → python zipfile（`python3`/`python`/`py -3` を
  **能力ベース**（`import zipfile` が通るか）で検出）→ どちらも不可なら明示エラー、の順。
  途中経路の失敗はフォールバック（出力を削除して次へ）、全滅は非0終了。
- 自己検証（`verify_pptx`）: zip整合性＋必須パーツ存在＋（python検出時）全 `.xml`/`.rels`
  パーツの well-formed 検査。python不在では well-formed 検査だけ省略し、その旨を警告する。
  検証失敗時は出力を削除して非0（**壊れた .pptx を残さない**）。

### 条件7突合（受け入れ条件7の検証手順）

入力JSONの**文字列の葉の値ごと**に、正規化（CR除去・0x1F空白化・改行分割）後の各行が
生成物の全 `<a:t>` 連結文字列へ部分一致で現れることを突合する（単体テストの
`verify_pptx.py` が実装）。**対象外は5つ**:

| 対象外 | 理由 |
|---|---|
| `meta.title` | docProps（`dc:title`）行き。coverが省略時に限り `<a:t>` にも現れる |
| `meta.issue` | docProps（`cp:keywords`）行き。**加えて integer のため「文字列の葉」として走査に現れず、この対象外指定は実質効かない**（記録として残す） |
| `speakerNotes` | 出力しない設計 |
| `slides[].type` | 構造の判別子で `<a:t>` に現れない |
| `slides[].sides[].tone` | 値そのものは日本語注記へ写像され `<a:t>` に現れない |

対象外化で突合から漏れる写像（tone注記・coverのmetaフォールバック）は、単体テストの
個別アサーションで固定する。

### PowerPoint製雛形への差し替え（前処理条件の記録）

雛形は手組みの展開ディレクトリ（DDR i0169-01）。PowerPoint製パッケージへの差し替えは
**無加工では成立せず**、次の前処理が要る（前提調査Q4。検証済みの機能ではなく設計上の
可能性の記録）:

1. `ppt/slides/` 配下と `ppt/_rels/presentation.xml.rels` を削除してから置く
   （どちらも生成スクリプトが丸ごと所有・生成するため）。
2. `presentation.xml` の `sldIdLst` を空（`<p:sldIdLst/>`）にしておく。
3. スライドが参照するレイアウトは `ppt/slideLayouts/slideLayout1.xml` に固定する。

前処理後もPowerPoint製の追加パーツ（presProps等）が壊れず残るかは未検証。

## 影響範囲

- 新規スキルの追加であり、既存機構の変更は無い（既存テスト全件・`check-dist-coverage.sh`・
  `extract-frontmatter.sh` の通過を issue #169 の各pushで確認）。
- 配布対象（layer=core）への資産追加のため `.claude/VERSION` はMINOR増分の対象
  （増分の記録は `.claude/docs/spec/distribution-assets.md` のchangelog）。

## 設定項目

なし（引数は `<入力.json> [出力.pptx]` のみ。出力省略時は入力と同じディレクトリの
`<ベース名>.pptx`）。

## 実機確認の依頼事項（未達の完了条件の代替）

開発環境（Linux・PowerPoint/LibreOffice不能）では機械検証（zip整合性・XML well-formed・
パーツ突合・条件7突合）までしか行えないため、次の4点はPowerPoint実機での確認を依頼する:

1. 警告・修復ダイアログなく開くこと。
2. テキストと表が編集できること。
3. 8種typeが表示されること。
4. **表に罫線・1行目の強調が付いていること**（表スタイルは組み込みGUIDの `tableStyleId`
   参照のみで `tableStyles.xml` を同梱しないため、環境によっては無装飾になる可能性がある。
   無装飾だった場合は後続で `tableStyles.xml` を同梱する）。

Windows git bash での1回の実行確認（`zip` 不在環境ではpython経路が使われること）も
あわせて依頼する。

## 未決定事項・懸念点

- **本specの人間承認が未取得**（PR #199 レビューの◆）。
- speakerNotes（notesSlide）出力・`tableStyles.xml` 同梱は実機確認の結果待ちの後続課題。
- bash 5.2 の `patsub_replacement` はスクリプト冒頭で無効化している（罠の詳細は
  `.claude/rules/shell-script-style.md`「パラメータ展開の既定値」節の隣の記載）。

## 変更履歴

- issue #169: 新規作成（フェーズ3で実装、フェーズ4でスキーマ確定（PR #194マージ）へ追従。
  旧語彙 headers/options/left/right・edges/caption・入れ子bulletsの受け付けはフェーズ4で
  削除し、cover metaフォールバック・section.chapter・COLH/PARA・sides転置・takeaway を追加）。
