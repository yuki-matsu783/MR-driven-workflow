---
title: 調査結果: pptx書き出しの前提調査
type: report
description: issue #169 の .pptx 書き出し機能の設計を確定するための前提調査（Q1〜Q6）の結果。最小構成pptxの実生成（2枚構成・rId採番規則込み）・2つのzip経路の突合・PR #194スキーマの転記を含む
tags: [report, research, pptx]
keywords: [調査結果, zip, OOXML, 最小構成, 雛形, スキーマ転記, cover, slideN.xml, rels, rId採番, LibreOffice]
---

# 調査結果: pptx書き出しの前提調査

- issue: #169 / PR: #199
- フェーズ: 2〈調査〉 flow-id 2-6
- 個別調査計画: `wip/plans/【調査】pptx書き出しの前提調査.md`
- 実施日: 2026-08-23。一次情報はリポジトリ内のファイル・issue本文・PR #194ブランチの現物・
  実行環境の実測のみ（外部Web不使用）
- 改訂: 敵対的レビュー（フェーズ2の2回目）の指摘15件を反映し、2枚構成・rId採番規則・
  `zip -D`・`jar tf` での再実測を行った（初版の実測は1枚構成・rId採番未定義で、
  詳細は「想定と異なった点」参照）

## 重点レビュー依頼

- ◆特に見てほしい（判断に困っている）
  - **Q4. 雛形を「手組みの展開ディレクトリ」とする点**。issue本文の「雛形をPowerPointで作る」
    という想定をこの環境では満たせないため、機械検証＋人間の実機確認で代替する。
    **PowerPoint製雛形への差し替えには前処理（下記Q4の条件3つ）が必要**で、「無加工で
    差し替え可能」ではない。この方針でよいか。
  - **Q5. speakerNotes をフェーズ3のスコープに含めるかの判断**。notesSlide の連動箇所は
    「各1箇所」ではなく**スライド枚数に比例する連動が2種類**増える（正確な内訳はQ5参照。
    notesMaster入りの最小構成は実生成しておらず、見積りの実測rootは無い）。含めるか
    落とすか（落とす場合はSKILL.mdへ「speakerNotesは出力されない」と明記）。
  - **完了条件の一部未達**: 「独立実装での開封」はzip層2実装（python zipfile・jar）で
    満たしたが、**OOXMLとして解釈するフルパーサでの開封は未達**（LibreOfficeがこの環境で
    使用不能のため。詳細は「確かめられなかったこと」）。この未達のままフェーズ3へ進んで
    よいか（PowerPoint実機確認がその代替になる想定）。
- ◇承認が欲しい（方針は決めたので確認してほしい）
  - Q1. zip経路の優先順位（`zip` → `python3 zipfile` → 明示エラー）と能力ベース検出。
  - Q2. type enum を PR #194 の `cover` 改名へ追従した8種＋**title全型必須（上流準拠）**で
    確定する点。
  - スキル名 `pptx-slides`（html-slides と対になる命名）。
- ・細かいレビューは不要（ほぼ確実)
  - Q3（2枚構成で再実測済み）、Q6（検証の切り分け）。

## サマリ（結論の一覧）

検査件数はすべて「Q3の検証表の8種」を指す（他の数え方はしない）。

| # | 問い | 結論 |
|---|---|---|
| Q1 | zip相当の可用性 | この環境は `zip`/`unzip`/`python3` すべて有り（実測）。生成経路は **`zip -X -D` → `python3 zipfile` → 明示エラー** の優先順位。両経路の生成物は**全エントリ一致**（`-D` 採用後の再実測） |
| Q2 | スキーマ依存範囲 | **type enum 8種（表紙は `cover`）＋title全型必須（上流準拠）＋型別必須キー**に限定。入力検証はjqの必須キー検査。スキーマファイル本体（未コミット）へは依存しない |
| Q3 | 最小OOXML構造 | **15パーツ（2枚構成）**で検証8種すべて合格（実測）。**rId採番規則を定義**（固定rels=rId1/rId2予約、スライドはrId3から連番） |
| Q4 | 雛形の形態 | **展開ディレクトリ**を採用。PowerPoint製雛形への差し替えは**前処理条件付き**で可能（無加工では不可） |
| Q5 | 8種typeの写像 | 6型はテキストボックス `<p:sp>`＋表 `<a:tbl>` で表現。diagram→箇条書き代替、comparison→表代替。speakerNotesの採否は◆でレビュー依頼中 |
| Q6 | 検証の切り分け | 機械検証8種＋人間の実機確認4種。受け入れ条件7は「入力JSONの**葉テキスト値ごとの部分一致**」の突合で担保（対象外リスト付き） |

## 実施条件（測った対象・環境）

- 実行環境: Claude Code on the web のリモート実行環境（Linux）。実施日: 2026-08-23。
- 1環境の観測であり、Windows git bash 実機・PowerPoint実機の挙動は本調査の対象外。

## Q1. zip相当の可用性と代替戦略（受け入れ条件1）

### この環境の実測（コマンドと生の出力）

```
$ command -v zip unzip python3 jar soffice
/usr/bin/zip
/usr/bin/unzip
/usr/local/bin/python3
/usr/bin/jar
/usr/bin/soffice
```

```
$ zip -v | head -2
Copyright (c) 1990-2008 Info-ZIP - Type 'zip "-L"' for software license.
This is Zip 3.0 (July 5th 2008), by Info-ZIP.
$ unzip -v | head -1
UnZip 6.00 of 20 April 2009, by Debian. Original by Info-ZIP.
$ python3 --version
Python 3.11.15
$ soffice --version | head -1
LibreOffice 24.2.7.2 420(Build:2)
```

- `python3 -c "import pptx"` は ModuleNotFoundError（python-pptx 不在。方針どおり新規
  インストールせず、検証は標準ライブラリ zipfile+ElementTree で行った）。
- **LibreOffice はこの環境ではフィルタ欠落により使用不可**: `soffice --headless --convert-to pdf`
  が**プレーンテキスト（.txt）に対してすら** `Error: source file could not be loaded` で失敗する
  （フレッシュプロファイル `-env:UserInstallation=...` でも同じ。なお失敗時も終了コードは0では
  なく2だが、成果物は作られない）。失敗は当方の .pptx の構造起因ではない。

### 生成経路の優先順位（結論）

| 優先 | 経路 | 実測 | 判断 |
|---|---|---|---|
| 1 | `zip -X -D -r`（**`-D` でディレクトリエントリを作らない**） | 2枚構成で実生成し検証8種合格 | 採用（最優先） |
| 2 | `python3` 標準ライブラリ `zipfile` | 同上。**全エントリ（15件）・順序の先頭・`/` 区切りが経路1と完全一致**することを突合済み | 採用（フォールバック） |
| — | PowerShell `Compress-Archive` | 本環境に無く検証不能。issue本文がパス区切り（バックスラッシュ）・格納順でOOXMLを壊すリスクを指摘 | **却下**（検証できない手段を自動フォールバックに入れない） |
| — | `jar cfM` | 本環境には有るが、git bash環境でのJDK存在は前提にできない。経路1・2に対する利点が無い（**読み出し `jar tf` は独立実装の検証としてQ3で使用**） | **却下**（生成用途） |

- **初版の実測との差分**: 初版は `-D` 無しで生成しており、zip経路だけがディレクトリエントリ
  11件を含んでいた（一致していたのはファイルエントリ集合のみ）。PowerPoint自身の出力は
  ディレクトリエントリを持たないため、**`-D` を付けて両経路を完全一致させた**（再実測済み）。
- **検出ロジックは「存在」ではなく「能力」で行う**:
  1. `command -v zip` があり、かつ実際にzip生成→自己検証が通る → 経路1
  2. `python3 -c "import zipfile"` が終了コード0 → 経路2（**Windowsでは `python3` という名の
     コマンドが無い（python.orgインストーラは `python.exe`/`py` を置く）／Storeのスタブ
     `python3.exe` が存在するのに実行できない、の両方がありうる**ため、存在確認だけでは
     未検出・誤検出のどちらにも倒れる。候補は `python3` → `python` → `py -3` の順に
     `import zipfile` の成否で試す）
  3. どちらも無ければ**明示エラーで停止**
  - **生成後に必ず自己検証（zip整合性＋必須パーツ存在）を行い、失敗したら出力ファイルを
    削除して非0で終了する**（「無言で壊れた .pptx を出さない」の実装形。検出をすり抜けた
    Storeスタブ等もここで捕まえる）。
- Git for Windows に `zip` が同梱されるかはこの環境では検証できない（未検証の前提として扱う）。
  Windows実機確認の依頼には「`python3` という名前が無い構成」「Storeスタブがある構成」の
  2ケースを明示する（Q6）。

### OOXMLのzip制約（事実と理解を分けて書く）

- **実測した事実**: Deflate圧縮・`/` 区切り・`[Content_Types].xml` 先頭配置・ディレクトリ
  エントリ無しで生成した両経路の成果物が、Q3の検証8種（3つの独立zip実装での読み出しを含む）に
  合格した。
- **未確認の理解（出典を持たない）**: OPC仕様にはODFの `mimetype`（先頭・無圧縮）に相当する
  制約は無い、と理解しているが、本調査は外部Web不使用のため仕様原文での裏取りはしていない。
  PowerPoint実機が受理するかも未確認（人間の実機確認へ。Q6）。先頭配置・`-D` は
  「PowerPoint自身の出力と同じ形へ寄せる」保険であり、必須性を主張しない。

## Q2. 構成案JSONスキーマの依存範囲（受け入れ条件7）

### PR #194 の現状（2026-08-23 再取得）

- PR #194 は**フェーズ3に進行**（`wip/plans/【AIアセット作成】HTMLスライドスキル一式の作成.md`
  まで作成済み）。スキーマファイル
  `.claude/skills/html-slides/references/slide-outline.schema.json` は**まだコミットされていない**。
- **重要な変更**: フェーズ3計画で**表紙のtype名が `title` から `cover` へ改名**された（スライド
  要素の必須フィールド `title`（見出し）と型名が衝突するため）。当方の写像もこれへ追従する。

### 依存内容の転記（PR #194 ブランチの現物より。マージ後も参照できるようここへ残す）

- トップレベル: `{meta: {title, subtitle, date, author, issue}, slides: [...]}`
- 各スライド: **`type` と `title` を必須で持つ**（上流の定義）＋型ごとのフィールド＋
  `speakerNotes`（任意。`speakerNotes`・`meta.issue` は .pptx のノート・ドキュメント
  プロパティに対応する項目として明示的に保持される）
- type enum（8種）: `cover` `section` `bullets` `two-column` `diagram` `table` `comparison` `summary`
- 型別フィールド（PR #194 調査レポートQ5の記載。スキーマ未確定のため**暫定**）:
  `bullets`→`items[]`（入れ子1段）／`two-column`→`left`/`right`／`table`→`headers[]`/`rows[][]`／
  `comparison`→`options[]`（名前・利点・欠点・採否）／`diagram`→`nodes[]`/`edges[]`＋`caption`
- スキーマは「表示スタイルではなく内容だけを持つ」（HTML固有の色・レイアウト座標を含めない）

### .pptx側の入力検証（必須キー集合。jqで検査）

| キー | 条件 | 出どころ |
|---|---|---|
| `meta.title` | 文字列（必須） | 上流 |
| `slides` | 配列・1件以上（必須） | 上流（1件以上は当方の独自定義） |
| 各スライドの `type` | 8種enumのいずれか（必須） | 上流 |
| 各スライドの `title` | **全型で必須**（`cover` も例外にしない） | 上流（初版では cover のみ任意としていたが、上流で弾かれるJSONを当方が通す非対称になるため上流準拠へ改めた） |
| `bullets`/`summary` の `items` | 配列（必須） | `bullets` は上流／`summary` への適用は当方の独自定義 |
| `two-column` の `left`/`right` | 必須 | 上流 |
| `table` の `headers`/`rows` | 必須 | 上流 |
| `comparison` の `options` | 配列（必須） | 上流 |
| `diagram` の `nodes` | 配列（必須。`edges` は任意） | 上流（必須/任意の別は当方の独自定義） |

- 上記に**無い**キーは無視する（過剰なキーで失敗しない。スキーマ側の将来の追加に耐える）。

### 突合手順と分岐（PR #194 スキーマ確定後）

1. `.claude/skills/html-slides/references/slide-outline.schema.json` がmainまたは #194 ブランチへ
   現れた時点で、上記の必須キー表とdiffを取る。
2. 分岐: type名・必須キー・**必須性の緩和/強化**に差分 → 当方の写像・検証・サンプルを追従修正／
   差分なしまたは任意キーの追加のみ → 記録のみ／PR #194 がクローズ → 当方の必須キー表を暫定の
   正としてspecへ明記し、ユーザーへ報告する。
3. 実施タイミング: フェーズ5のDraft解除前（flow-id 5-6の前提確認）に必ず1回。それ以前でも
   PR #194 のpushを検知したら随時。

## Q3. 最小OOXML構造（受け入れ条件3）

### パーツ一覧（2枚構成15ファイル。この構成で機械検査に合格した — 必要性・PowerPoint受理は未検証）

```
[Content_Types].xml
_rels/.rels
docProps/core.xml            docProps/app.xml
ppt/presentation.xml         ppt/_rels/presentation.xml.rels
ppt/slideMasters/slideMaster1.xml   ppt/slideMasters/_rels/slideMaster1.xml.rels
ppt/slideLayouts/slideLayout1.xml   ppt/slideLayouts/_rels/slideLayout1.xml.rels
ppt/theme/theme1.xml
ppt/slides/slide1.xml        ppt/slides/_rels/slide1.xml.rels
ppt/slides/slide2.xml        ppt/slides/_rels/slide2.xml.rels
```

- 「この15パーツで下記の検証8種に合格した」ことを測った。**どれか1つを外すと壊れるか
  （必要性）と、PowerPointが警告なく受理するか（十分性の最終確認）は測っていない**
  （後者は人間の実機確認へ。Q6）。
- theme1.xml に `clrScheme`・`fontScheme`・`fmtScheme`（fill/line/effect/bgFill 各3件）の
  フルセットを含めた。**「省くとスキーマ違反」は未検証の前提**（「確かめられなかったこと」参照）。
- スライド本体にはテキストボックス（タイトル・箇条書き2階層）・`<a:tbl>`（2×2表）・
  章扉相当の2枚目を入れた（`<a:t>` 計8箇所）。

### rIdの採番規則（初版に無かった結論。1枚構成では表面化しない衝突を2枚構成で解消）

- **初版の実測（1枚構成）の雛形は rId1=slideMaster / rId2=slide1 / rId3=theme で、
  「スライドN枚目=rId(N+1)」と採番すると2枚目で theme と衝突する**構造だった（敵対的
  レビューの指摘で判明）。
- **結論**: `ppt/_rels/presentation.xml.rels` は**生成スクリプトが丸ごと所有**（雛形の同名
  ファイルは使わず毎回生成）し、**固定relsを rId1=slideMaster・rId2=theme に予約、スライドは
  rId3 から枚数分の連番**とする。`presentation.xml` の `sldIdLst` も同じ規則で生成する
  （`sldId` の `id` は256から連番）。
- 機械検証に「**全 `.rels` 内で rId 重複0件**」を追加する（下記の検証8種に含む）。

### スライド枚数が可変のとき連動して書き換える箇所

| 箇所 | 内容 |
|---|---|
| `[Content_Types].xml` | スライドごとの `<Override PartName="/ppt/slides/slideN.xml" .../>` |
| `ppt/presentation.xml` | `<p:sldIdLst>` の `<p:sldId id="255+N" r:id="rId(N+2)"/>`（上記採番規則） |
| `ppt/_rels/presentation.xml.rels` | ファイル全体を生成（固定rels＋スライドごとの Relationship） |
| `docProps/app.xml` | `<Slides>N</Slides>`（枚数） |
| `ppt/slides/_rels/slideN.xml.rels` | スライドごとに1本（レイアウトへの参照） |

### 構造を決める4ファイルの現物（再現可能性のため。2枚構成の実測に使ったもの）

`[Content_Types].xml`:

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
<Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
<Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
<Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
<Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
<Override PartName="/ppt/slides/slide2.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>
```

`_rels/.rels`:

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>
```

`ppt/presentation.xml`:

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
<p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>
<p:sldIdLst><p:sldId id="256" r:id="rId3"/><p:sldId id="257" r:id="rId4"/></p:sldIdLst>
<p:sldSz cx="12192000" cy="6858000"/>
<p:notesSz cx="6858000" cy="9144000"/>
</p:presentation>
```

`ppt/_rels/presentation.xml.rels`:

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="theme/theme1.xml"/>
<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>
<Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide2.xml"/>
</Relationships>
```

（残る11ファイル — theme1.xml・slideMaster1.xml・slideLayout1.xml・slide1.xml・slide2.xml・
各rels・docProps — の現物はフェーズ3で `assets/pptx-template/` としてコミットする。上の4本が
rId採番・連動書き換えの構造を決めており、指摘のあった再現性の核はここにある）

### 検証結果（検証8種。2枚構成・zip -D 採用後の再実測。生の出力）

```
$ unzip -t minimal2.pptx | tail -1
No errors detected in compressed data of .../minimal2.pptx.
```

```
$ python3 <検証スクリプト>   # 内容は「再現手順」参照
minimal2.pptx: entries=15 dirEntries=0 wf_ng=0 rId_dup=[] rels_ng=[]
minimal2-py.pptx: entries=15 dirEntries=0 wf_ng=0 rId_dup=[] rels_ng=[]
完全一致(全エントリ): True / 先頭: [Content_Types].xml [Content_Types].xml
```

```
$ jar tf minimal2.pptx | wc -l
15
```

| # | 検査 | 結果 |
|---|---|---|
| 1 | `zip -X -D -r` での生成（rc=0） | 合格 |
| 2 | `unzip -t`（Info-ZIP実装での読み出し） | 合格 |
| 3 | `zipfile.testzip()`（python実装での読み出し） | 合格（None） |
| 4 | 全 `.xml`/`.rels`（15エントリ中該当全件）の well-formed | 合格（NG 0件） |
| 5 | Content_Types の Override宣言と実体の突合 | 合格（欠落0件） |
| 6 | rels整合（全 Relationship Target の実在・`presentation.xml` の `r:id` 解決） | 合格 |
| 7 | 全 `.rels` 内の rId 重複0件 | 合格 |
| 8 | `python3 zipfile` 経路との突合（**全エントリ完全一致**・先頭・`/` 区切り）＋ `jar tf`（第3の独立zip実装）での読み出し | 合格 |

## Q4. 雛形の形態 — 展開ディレクトリを採用

| 案 | 判定 | 理由 |
|---|---|---|
| **(a) 展開ディレクトリ**（`assets/pptx-template/` にXMLをそのまま置き、生成時にzip） | **採用** | XMLがテキストとしてGit管理され差分レビュー可能。`.gitattributes` 追記不要（バイナリを持たない）。生成スクリプトは「テンプレートディレクトリ＋生成した slideN.xml 群」をzipするだけ |
| (b) バイナリ .pptx をリポジトリへ置き、生成時に差し替え | 却下 | 差分レビュー不能。バイナリのGit管理（`.gitattributes`・配布）に追加の配慮が要る。更新にはPowerPointか展開・再圧縮の往復が要り、(a) に対する利点が「PowerPoint製の保証」しか無い |

- **issue本文の「雛形をPowerPointで作る」との差分**: この環境にPowerPointが無いため、雛形は
  手組みのOOXML（Q3で機械検証済み）から始める。**PowerPoint製の保証は「機械検証＋人間の
  実機確認（初回レビュー時にPowerPointで開く）」で代替**する。
- **PowerPoint製雛形への差し替えは、無加工では成立しない**（PowerPoint製パッケージは
  rId採番が異なる・既存の `slide1.xml` と `sldIdLst` エントリを持つ・slideLayoutが多数あり
  スライドの参照先が変わる・`presProps.xml` 等の追加パーツを持つ、の4点で「固定書式の
  連動書き換え」と衝突するため）。差し替えに必要な**前処理条件**をインターフェイスとして
  固定する:
  1. `ppt/slides/` 配下と `ppt/_rels/presentation.xml.rels` を**削除してから**置く
     （どちらも生成スクリプトが丸ごと所有・生成するため。Q3の採番規則）。
  2. `presentation.xml` の `sldIdLst` を空（`<p:sldIdLst/>`）にしておく（生成スクリプトが
     書き直す）。
  3. スライドが参照するレイアウトは `ppt/slideLayouts/slideLayout1.xml` に固定する
     （別のレイアウトを使いたい場合は、その名前へリネームするか生成スクリプト側の対応を
     フェーズ3以降の課題とする）。
  - この前処理を行ってもPowerPoint製の追加パーツ（presProps等）が壊れずに残るかは
    未検証であり、**差し替えは「設計上の可能性」であって検証済みの機能ではない**
    （フェーズ3のスコープにも含めない）。

## Q5. 8種のtype → スライドXML表現の写像（受け入れ条件6）

type名は Q2 の転記どおり（表紙=`cover`）。

| type | 表現 | 実現要素 |
|---|---|---|
| `cover`（必須6型） | タイトル大＋サブタイトル・日付・作成者 | テキストボックス `<p:sp>` ×2〜3 |
| `section`（必須） | 章番号＋章タイトル大 | `<p:sp>` ×1〜2 |
| `bullets`（必須） | 見出し＋箇条書き（入れ子1段= `<a:pPr lvl="0/1">`） | `<p:sp>` ×2 |
| `two-column`（必須） | 見出し＋左右2つの本文ボックス | `<p:sp>` ×3 |
| `table`（必須） | 見出し＋ネイティブ表（`firstRow` 強調） | `<p:sp>`＋`<p:graphicFrame>`/`<a:tbl>` |
| `summary`（必須） | 見出し＋箇条書き（bulletsと同構造） | `<p:sp>` ×2 |
| `diagram`（代替） | 見出し＋「ノード一覧」箇条書き＋「A → B（ラベル）」形式のエッジ列挙＋caption | `<p:sp>` ×2〜3 |
| `comparison`（代替） | 見出し＋表（列=候補、行=利点/欠点/採否） | `<p:sp>`＋`<a:tbl>` |

- 箇条書き・表のテキストはすべて `<a:t>` 要素として出力される（＝編集可能・画像化されない）。
- **speakerNotes（notesSlide）の連動コストは「各1箇所」ではない**（初版の見積りは過小。
  敵対的レビューの指摘）。少なくとも: (a) `[Content_Types].xml` へ notesMaster 1件＋
  **notesSlideごとに1件**の Override、(b) `presentation.xml` へ `<p:notesMasterIdLst>` の追加＋
  `presentation.xml.rels` へ notesMaster 1件、(c) **notesSlideごとに
  `ppt/notesSlides/_rels/notesSlideN.xml.rels`**（対応スライドとnotesMasterへの参照）、
  (d) notesMaster自身のrels（theme参照）。つまり**スライド枚数に比例する連動が2種類増える**。
  notesMaster入りの最小構成は実生成しておらず、この列挙自体の実測rootは無い。
  **採否は◆としてレビュー依頼**（落とす場合はSKILL.mdへ「speakerNotesは出力されない」と明記）。

### スキル名・出力先（フェーズ3の前提として確定）

- スキル名: **`pptx-slides`**（`html-slides` と対になる命名。「同じ構成案JSONの別出力」という
  関係が名前から読める）。却下: `pptx-export`（何をpptxにするのかが読めない）・
  `json-to-pptx`（入力形式を名前にするのは既存スキルの命名（機能名詞）と不揃い）。
- 出力先の既定: 入力 `<ベース名>.slides.json` と同じディレクトリの `<ベース名>.pptx`。

## Q6. 検証手段の切り分け（受け入れ条件3・4・5・7）

### 機械検証（フェーズ3で単体テストへ組み込む。Q3の検証8種＋内容突合）

1〜8. Q3の検証8種（zip整合性×3実装・well-formed・Content_Types突合・rels整合・rId重複0・
経路間突合）

9. **table/comparison スライドに `<a:tbl>` が存在する**（受け入れ条件5の構造的証明）

10. **受け入れ条件7の突合（定義を初版から修正）**: 入力JSONの**葉テキスト値ごと**に、
    生成 .pptx の全 `<a:t>` テキストを連結した文字列（notesSlideを出力する場合はそれも含む）へ
    **部分一致**で存在すること。1件でも見つからなければ失敗。
    - 完全一致の集合包含にしない理由: Q5の写像がテキストを合成するため（diagramのエッジ
      「A → B（ラベル）」は葉値 A・B・ラベルの連結、comparisonの行見出し「利点/欠点/採否」は
      スクリプトが足す定型文言）。合成された文字列の中に葉値が部分一致で見つかることを検査する。
    - **対象外リスト**（`<a:t>` に現れないことが正しい値）: `meta.issue`（docProps行き）。
      speakerNotes をフェーズ3スコープから落とした場合は `speakerNotes` も対象外へ入れる。
    - 検査方向はJSON→pptxの包含のみ（pptx側にスクリプト由来の定型文言があることは失敗に
      しない）。
    - HTML版そのものとの直接比較は PR #194 未マージのためできない。**「同じJSONに対する
      忠実性」を双方が独立に検査する**分担とし、HTML側の忠実性は #194 側の機械検査・
      差し戻し条件に依存することを限界として明記する。

### 人間の実機確認（PRレビューへ依頼する。依頼文面の要点）

1. 生成した .pptx が **PowerPointで警告なく開く**こと
2. テキストがテキストボックスとして、表がネイティブ表として**選択・編集できる**こと
3. **Windows git bash 上で生成スクリプトが動く**こと。とくに (a) `zip` が無い構成での
   pythonフォールバック、(b) **`python3` という名前が無い構成**（python.orgインストーラ）、
   (c) **Storeのアプリ実行エイリアス `python3.exe` がある構成**、での検出・縮退の挙動
4. どちらの経路（zip / python3）で生成した .pptx かをPowerPoint確認時に記録する
   （両経路の生成物は全エントリ一致まで確認済みだが、実機確認はどちらか一方になるため）

## 設計への反映（フェーズ3・4の計画への引き継ぎ）

1. フェーズ3へ: スキル `pptx-slides`（`.claude/skills/pptx-slides/`）= SKILL.md＋
   `scripts/json-to-pptx.sh`＋`assets/pptx-template/`（展開ディレクトリ雛形）＋
   `.claude/scripts/test/test_json_to_pptx.sh`。生成スクリプトの構造: 入力検証（jq必須キー
   検査）→ slideN.xml 生成（type別写像）→ 連動5箇所の生成（Q3の表）→ zip（能力ベース検出・
   2経路・明示エラー）→ 自己検証（失敗時は出力を削除して非0）。
2. テストへ: 機械検証10種（Q6）＋異常系（type不正・必須キー欠落・空入力・zip/python3両不在の
   明示エラー・生成失敗時に出力ファイルが残らないこと）。
3. フェーズ4へ: **DDR（受け入れ条件8）** — 採用（雛形＋差し替え＋再zip）と却下案の記録。
   却下理由の原文は次のとおり:
   - **クリップボード経由**: ブラウザがクリップボードへ書ける形式は `text/plain`/`text/html`/
     `image/png` に限られ、PowerPointが図形として読むネイティブ形式（`Art::GVML ClipFormat`）を
     書き込めないため、貼り付けが1つのテキストボックスへの流し込みになりレイアウトが失われる
     （issue #169 本文の記載を採用根拠として引き継ぐ）。
   - **python-pptx（生成手段として）**: 新規の外部依存（pipインストール）が要り、git bash実機に
     存在する保証が無い。このリポジトリのスクリプト規約（bash+jq前提）とも不揃い。実測でも
     この環境に不在だった。
   - **XMLをゼロから組む（雛形なしで毎回全パーツを生成）**: マスター・レイアウト・テーマまで
     生成コードに埋まり、見た目の調整のたびにスクリプト修正が要る。雛形方式ならXML差し替えだけで
     済み、将来のPowerPoint製雛形への差し替え余地も残る。
   - **バイナリ .pptx 雛形**・**Compress-Archive**: Q4・Q1の却下理由のとおり。
   あわせて spec（`.claude/docs/spec/`）、`directory-structure.md` ツリー追記、
   `.claude/VERSION` 増分の提案（資産追加=MINOR）または据え置きの記録。

## 想定と異なった点

- **初版の実測（1枚構成・`-D`無し）には2つの誤りが混じっていた**（敵対的レビューで検出、
  いずれも再実測で解消）: (1) zip経路だけがディレクトリエントリ11件を含み「エントリ集合一致」は
  ファイル集合のみの一致だった → `-D` で完全一致へ。(2) 雛形のrId並びが「スライド追加で
  theme と衝突する」構造だった → 採番規則を定義し2枚構成で再実測。**1枚構成での合格は
  多枚数の根拠にならない**という教訓はフェーズ3のテスト設計（複数枚のサンプル必須）へ
  引き継ぐ。
- LibreOffice が存在するのに一切のファイルを読めない（フィルタ欠落）。OOXMLフルパーサでの
  独立検証は不能と判明。
- PR #194 が調査時点（フェーズ2完了直後）からフェーズ3へ進行し、表紙のtype名が `cover` へ
  変わっていた。依存の再確認を調査実施中にも行ったことで検出できた。

## 確かめられなかったこと

**うち「OOXMLフルパーサでの開封」は、個別調査計画の完了条件の許容リスト（Windows実機依存の
挙動のみ）に入らない＝完了条件の一部未達である。** zip層は unzip・python zipfile・jar の
3実装で読み出せることを確認したが、OOXMLとして解釈する独立実装での開封はこの環境では
LibreOffice不能のため実施できなかった。PowerPoint実機確認（Q6）を代替とし、未達のまま
フェーズ3へ進む可否を◆としてレビュー依頼へ上げている。

- PowerPoint実機での開封・編集（Windows実機が無い → 人間の実機確認へ）
- Windows git bash での生成スクリプト実行・`zip` 同梱有無（同上）
- PowerShell `Compress-Archive` の実挙動（Windows実機が無い。「検証できない手段を自動
  フォールバックに入れない」という却下理由自体がこの検証不能性に基づく）
- LibreOffice等のOOXMLフルパーサでの開封（上記のとおり完了条件の一部未達）
- theme1.xml のフルセット（fmtScheme等）が**必須である**こと（省いた構成での失敗を実測して
  いない。フルセットを含めた構成で合格したことのみが事実）

## 再現手順（主要コマンドと検証スクリプト）

```bash
# Q1: 所在確認（出力は本文Q1に生のまま貼付）
command -v zip unzip python3 jar soffice; zip -v | head -2; python3 --version

# Q3: 雛形（本文の4ファイル＋フェーズ3でassets/へ収める11ファイル）を組み、zip -D で梱包
cd <雛形ディレクトリ> && zip -q -X -D -r out.pptx '[Content_Types].xml' _rels docProps ppt
unzip -t out.pptx | tail -1
jar tf out.pptx | wc -l

# 検証スクリプト（well-formed・Content_Types突合・rels整合・rId重複）
python3 - out.pptx <<'EOF'
import sys, zipfile, posixpath, xml.etree.ElementTree as ET
z = zipfile.ZipFile(sys.argv[1]); assert z.testzip() is None
names = z.namelist()
R = '{http://schemas.openxmlformats.org/package/2006/relationships}'
nsr = '{http://schemas.openxmlformats.org/officeDocument/2006/relationships}'
for n in names:
    if n.endswith(('.xml', '.rels')):
        ET.fromstring(z.read(n))
import re
ct = z.read('[Content_Types].xml').decode()
assert all(p.lstrip('/') in names for p in re.findall(r'PartName="([^"]+)"', ct))
relmap = {}
for n in [x for x in names if x.endswith('.rels')]:
    base = posixpath.dirname(posixpath.dirname(n)); m = {}
    rels = ET.fromstring(z.read(n)).findall(R + 'Relationship')
    ids = [r.get('Id') for r in rels]
    assert len(ids) == len(set(ids)), f'rId duplicate in {n}'
    for r in rels:
        t = r.get('Target'); m[r.get('Id')] = t
        resolved = posixpath.normpath(posixpath.join(base, t)) if not t.startswith('/') else t.lstrip('/')
        assert resolved in names, f'{n}: {t}'
    relmap[n] = m
pres = ET.fromstring(z.read('ppt/presentation.xml'))
ids = relmap['ppt/_rels/presentation.xml.rels']
for el in pres.iter():
    rid = el.get(nsr + 'id')
    assert rid is None or rid in ids
print('OK')
EOF

# Q2: PR #194 の現物確認
git fetch origin claude/html-slide-skill-template-ymue7k
git show 'origin/claude/html-slide-skill-template-ymue7k:wip/plans/【AIアセット作成】HTMLスライドスキル一式の作成.md'
```
