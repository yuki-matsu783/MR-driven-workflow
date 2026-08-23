---
title: 調査結果: pptx書き出しの前提調査
type: report
description: issue #169 の .pptx 書き出し機能の設計を確定するための前提調査（Q1〜Q6）の結果。最小構成pptxの実生成・zip経路の実測・PR #194スキーマの転記を含む
tags: [report, research, pptx]
keywords: [調査結果, zip, OOXML, 最小構成, 雛形, スキーマ転記, cover, slideN.xml, rels, LibreOffice]
---

# 調査結果: pptx書き出しの前提調査

- issue: #169 / PR: #199
- フェーズ: 2〈調査〉 flow-id 2-6
- 個別調査計画: `wip/plans/【調査】pptx書き出しの前提調査.md`
- 実施日: 2026-08-23。一次情報はリポジトリ内のファイル・issue本文・PR #194ブランチの現物・
  実行環境の実測のみ（外部Web不使用）

## 重点レビュー依頼

- ◆特に見てほしい（判断に困っている）
  - **Q4. 雛形を「手組みの展開ディレクトリ」とする点**。issue本文の「雛形をPowerPointで作る」
    という想定をこの環境では満たせないため、機械検証＋人間の実機確認＋後からPowerPoint製へ
    差し替え可能な構造、で代替する。この方針でよいか。
  - **Q5. speakerNotes をフェーズ3のスコープに含める点**（notesMaster/notesSlideの分だけ
    雛形が増える）。落とすならフェーズ3の作業計画で外す。
- ◇承認が欲しい（方針は決めたので確認してほしい）
  - Q1. zip経路の優先順位（`zip` → `python3 zipfile` → 明示エラー）。
  - Q2. type enum を PR #194 の `cover` 改名へ追従した8種で確定する点。
  - スキル名 `pptx-slides`（html-slides と対になる命名）。
- ・細かいレビューは不要（ほぼ確実）
  - Q3（実測で合格済み）、Q6（検証の切り分け）。

## サマリ（結論の一覧）

| # | 問い | 結論 |
|---|---|---|
| Q1 | zip相当の可用性 | この環境は `zip`/`unzip`/`python3` すべて有り（実測）。生成経路は **`zip` → `python3 zipfile` → 明示エラー** の優先順位。両経路で同一エントリ集合の .pptx を実生成し検証合格 |
| Q2 | スキーマ依存範囲 | **type enum 8種（表紙は `cover`。PR #194 フェーズ3で `title` から改名）＋型別必須キー**に限定。入力検証はjqの必須キー検査。スキーマファイル本体（未コミット）へは依存しない |
| Q3 | 最小OOXML構造 | **13パーツ**で unzip -t・XML well-formed・Content_Types突合・rels整合すべて合格（実測）。スライド枚数可変時の連動書き換えは4箇所＋スライド毎rels |
| Q4 | 雛形の形態 | **展開ディレクトリ**（XMLをGit管理し生成時にzip）を採用。バイナリ .pptx は却下 |
| Q5 | 8種typeの写像 | 6型はテキストボックス `<p:sp>`＋表 `<a:tbl>` で表現。diagram→箇条書き代替、comparison→表代替。speakerNotes は notesSlide として出力（方針） |
| Q6 | 検証の切り分け | 機械検証7種（下記）＋人間の実機確認3種。受け入れ条件7は「入力JSONの全テキスト値 ⊆ pptxの `<a:t>` 集合」の突合で担保 |

## 実施条件（測った対象・環境）

- 実行環境: Claude Code on the web のリモート実行環境（Linux）。実施日: 2026-08-23。
- 1環境の観測であり、Windows git bash 実機・PowerPoint実機の挙動は本調査の対象外
  （個別調査計画の完了条件どおり「確かめられなかったこと」へ記載）。

## Q1. zip相当の可用性と代替戦略（受け入れ条件1）

### この環境の実測

```
$ command -v zip unzip python3 jar soffice
/usr/bin/zip        # Zip 3.0 (July 5th 2008), by Info-ZIP
/usr/bin/unzip      # UnZip 6.00 of 20 April 2009
/usr/local/bin/python3   # Python 3.11.15
/usr/bin/jar        # JDK付属
/usr/bin/soffice    # LibreOffice 24.2.7.2（ただし下記のとおり使用不可）
```

- `python3 -c "import pptx"` は **ModuleNotFoundError**（python-pptx 不在。方針どおり新規
  インストールせず、検証は標準ライブラリ zipfile+ElementTree で行った）。
- **LibreOffice はこの環境ではフィルタ欠落により使用不可**: `soffice --headless --convert-to pdf`
  が **プレーンテキスト（.txt）に対してすら** `Error: source file could not be loaded` で失敗する
  （フレッシュプロファイル `-env:UserInstallation=...` でも同じ）。つまり失敗は当方の .pptx の
  構造起因ではない。独立フルパーサでの開封検証は「確かめられなかったこと」へ回す。

### 生成経路の優先順位（結論）

| 優先 | 経路 | 実測 | 判断 |
|---|---|---|---|
| 1 | `zip` コマンド（`zip -X -r`） | 本環境で実生成し検証合格 | 採用（最優先） |
| 2 | `python3` + 標準ライブラリ `zipfile` | 本環境で実生成し検証合格。エントリ集合・先頭エントリ・`/` 区切りが経路1と一致することを突合済み | 採用（フォールバック） |
| — | PowerShell `Compress-Archive` | 本環境に無く検証不能。issue本文がパス区切り（`\`）・格納順でOOXMLを壊すリスクを指摘 | **却下**（検証できない手段を自動フォールバックに入れない） |
| — | `jar cfM` | 本環境には有るが、git bash環境でのJDK存在は前提にできない。経路1・2に対する利点が無い | **却下** |

- **検出ロジック**: `command -v zip` → 無ければ `command -v python3` → どちらも無ければ
  **明示エラーで停止**（無言で壊れた .pptx を出さない。調査計画Q1の縮退方針どおり）。
- Git for Windows に `zip` が同梱されるかはこの環境では検証できない（未検証の前提として扱う。
  同梱されない構成でも python3（Windows版が入っていれば）経路で動き、どちらも無ければ明示
  エラーになる。Windows実機での動作確認は人間の実機確認へ回す。Q6）。

### OOXMLのzip制約（実測と既知の仕様）

- OPC（OOXML のパッケージ規約）には ODF の `mimetype`（先頭・無圧縮）に相当する制約は無い。
  Deflate圧縮で問題ない（実測: 経路1・2ともDeflateで生成し、後述のQ3検証にすべて合格）。
- エントリ名は `/` 区切りが必須。実測: 経路1・2とも `\` 混入なし（突合スクリプトで確認）。
- `[Content_Types].xml` を先頭エントリに置いた（両経路で実測確認）。OPC仕様上は位置の規定は
  無いが、PowerPoint自身の出力と同じ並びに寄せておく（害が無く、リーダー実装差への保険）。
- PowerPoint実機が読むかはこの環境では確認できない（人間の実機確認へ。Q6）。

## Q2. 構成案JSONスキーマの依存範囲（受け入れ条件7）

### PR #194 の現状（2026-08-23 再取得）

- PR #194 は**フェーズ3に進行**（`wip/plans/【AIアセット作成】HTMLスライドスキル一式の作成.md`
  まで作成済み）。スキーマファイル
  `.claude/skills/html-slides/references/slide-outline.schema.json` は**まだコミットされていない**。
- **重要な変更**: フェーズ3計画で**表紙のtype名が `title` から `cover` へ改名**された（スライド
  要素の必須フィールド `title`（見出し）と型名が衝突するため）。当方の写像もこれへ追従する。

### 依存内容の転記（PR #194 ブランチの現物より。マージ後も参照できるようここへ残す）

- トップレベル: `{meta: {title, subtitle, date, author, issue}, slides: [...]}`
- 各スライド: `{type, ...型ごとのフィールド, speakerNotes}`（`speakerNotes`・`meta.issue` は
  .pptx のノート・ドキュメントプロパティに対応する項目として明示的に保持される）
- type enum（8種）: `cover` `section` `bullets` `two-column` `diagram` `table` `comparison` `summary`
- 型別フィールド（PR #194 調査レポートQ5の記載。スキーマ未確定のため**暫定**）:
  `bullets`→`items[]`（入れ子1段）／`two-column`→`left`/`right`／`table`→`headers[]`/`rows[][]`／
  `comparison`→`options[]`（名前・利点・欠点・採否）／`diagram`→`nodes[]`/`edges[]`＋`caption`
- スキーマは「表示スタイルではなく内容だけを持つ」（HTML固有の色・レイアウト座標を含めない）

### .pptx側の入力検証（必須キー集合。jqで検査）

- `meta.title`: 文字列（必須）
- `slides`: 配列・1件以上（必須）
- 各スライド: `type` が上記enumの8種のいずれか（必須）＋ `title`（`cover` 以外は必須。
  `cover` は `meta.title` へフォールバック可）
- 型別: `bullets`/`summary`→`items`（配列）、`two-column`→`left`と`right`、
  `table`→`headers`と`rows`、`comparison`→`options`（配列）、`diagram`→`nodes`（配列。
  `edges` は任意）
- 上記に**無い**キーは無視する（過剰なキーで失敗しない。スキーマ側の将来の追加に耐える）

### 突合手順と分岐（PR #194 スキーマ確定後）

1. `.claude/skills/html-slides/references/slide-outline.schema.json` がmainまたは #194 ブランチへ
   現れた時点で、上記の必須キー集合とdiffを取る。
2. 分岐: type名・必須キーに差分 → 当方の写像・検証・サンプルを追従修正／差分なしまたは任意キーの
   追加のみ → 記録のみ／PR #194 がクローズ → 当方の必須キー集合を暫定の正としてspecへ明記し、
   ユーザーへ報告する。
3. 実施タイミング: フェーズ5のDraft解除前（flow-id 5-6の前提確認）に必ず1回。それ以前でも
   PR #194 のpushを検知したら随時。

## Q3. 最小OOXML構造（受け入れ条件3）

### 必須パーツ一覧（実生成で確定。13ファイル）

```
[Content_Types].xml
_rels/.rels
docProps/core.xml            docProps/app.xml
ppt/presentation.xml         ppt/_rels/presentation.xml.rels
ppt/slideMasters/slideMaster1.xml   ppt/slideMasters/_rels/slideMaster1.xml.rels
ppt/slideLayouts/slideLayout1.xml   ppt/slideLayouts/_rels/slideLayout1.xml.rels
ppt/theme/theme1.xml
ppt/slides/slide1.xml        ppt/slides/_rels/slide1.xml.rels
```

- theme1.xml は `clrScheme`・`fontScheme`・`fmtScheme`（fill/line/effect/bgFill 各3件）の
  フルセットが必須（省くとスキーマ違反になる既知の構造）。
- スライド本体にはテキストボックス2つ（タイトル・箇条書き2階層）と `<a:tbl>`（2×2表）を
  入れて生成した（`<a:t>` 7箇所）。

### スライド枚数が可変のとき連動して書き換える箇所

| 箇所 | 内容 |
|---|---|
| `[Content_Types].xml` | スライドごとの `<Override PartName="/ppt/slides/slideN.xml" .../>` |
| `ppt/presentation.xml` | `<p:sldIdLst>` の `<p:sldId id="256+n" r:id="rIdX"/>` |
| `ppt/_rels/presentation.xml.rels` | スライドごとの `<Relationship ... Target="slides/slideN.xml"/>` |
| `docProps/app.xml` | `<Slides>N</Slides>`（枚数） |
| `ppt/slides/_rels/slideN.xml.rels` | スライドごとに1本（レイアウトへの参照） |

### 検証結果（すべて合格。再現コマンドは「再現手順」節）

| 検査 | 結果 |
|---|---|
| `zip -X -r` での生成 | rc=0 |
| `unzip -t` | No errors detected |
| `zipfile.testzip()` | None（全エントリ正常） |
| 全 `.xml`/`.rels`（24エントリ中該当全件）の well-formed | NG 0件 |
| Content_Types の Override宣言と実体の突合 | 欠落 0件 |
| rels整合（全 Relationship Target の実在・`presentation.xml` の `r:id` 解決） | OK |
| `python3 zipfile` 経路との突合（エントリ集合・先頭・`/` 区切り） | 一致 |

## Q4. 雛形の形態 — 展開ディレクトリを採用

| 案 | 判定 | 理由 |
|---|---|---|
| **(a) 展開ディレクトリ**（`assets/pptx-template/` にXMLをそのまま置き、生成時にzip） | **採用** | XMLがテキストとしてGit管理され差分レビュー可能。`.gitattributes` 追記不要（バイナリを持たない）。生成スクリプトは「テンプレートディレクトリ＋生成した slideN.xml 群」を単純にzipするだけ |
| (b) バイナリ .pptx をリポジトリへ置き、生成時に差し替え | 却下 | 差分レビュー不能。バイナリのGit管理（`.gitattributes`・配布）に追加の配慮が要る。更新にはPowerPointか展開・再圧縮の往復が要り、(a) に対する利点が「PowerPoint製の保証」しか無い |

- **issue本文の「雛形をPowerPointで作る」との差分**: この環境にPowerPointが無いため、雛形は
  手組みのOOXML（Q3で機械検証済み）から始める。**PowerPoint製の保証は「機械検証＋人間の
  実機確認（初回レビュー時にPowerPointで開く）」で代替**する。
- **差し替え可能な構造**: 生成スクリプトのインターフェイスを「雛形ディレクトリのパスを引数に
  取り、`ppt/slides/` 配下と連動4箇所（Q3の表）だけを生成・上書きする」形に固定する。将来
  PowerPointで作った .pptx を `unzip` して同じディレクトリ構造に置けば、スクリプトを変えずに
  雛形だけ差し替えられる（マスター・レイアウト・テーマはスクリプトが触らないため）。

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

- 箇条書き・表のテキストはすべて `<a:t>` 要素として出力される（＝編集可能・画像化されない。
  Q3の実測でPowerPoint以外の実装でも `<a:t>` 7箇所を機械抽出できた）。
- **speakerNotes**: `notesSlideN.xml` として出力する方針（雛形へ `notesMaster1.xml` を同梱。
  Content_Types・rels の連動が各1箇所増える）。フェーズ3の作業計画で作業量を見て確定し、
  落とす場合は「speakerNotesは出力されない」ことをSKILL.mdへ明記する。

### スキル名・出力先（フェーズ3の前提として確定）

- スキル名: **`pptx-slides`**（`html-slides` と対になる命名。「同じ構成案JSONの別出力」という
  関係が名前から読める）。却下: `pptx-export`（何をpptxにするのかが読めない）・
  `json-to-pptx`（入力形式を名前にするのは既存スキルの命名（機能名詞）と不揃い）。
- 出力先の既定: 入力 `<ベース名>.slides.json` と同じディレクトリの `<ベース名>.pptx`
  （html-slides の `.slides.html`/`.slides.json` ペアと同じベース名で並ぶ）。

## Q6. 検証手段の切り分け（受け入れ条件3・4・5・7）

### 機械検証（フェーズ3で単体テストへ組み込む）

1. zip整合性: `unzip -t`（または `zipfile.testzip()`）
2. 全 `.xml`/`.rels` の well-formed（ElementTree）
3. Content_Types の Override と実体の突合
4. rels整合（Target実在・`r:id` 解決）
5. テキストが `<a:t>` として存在する（画像化されていないことの構造的証明）
6. `table`/`comparison` スライドに `<a:tbl>` が存在する（受け入れ条件5の構造的証明）
7. **受け入れ条件7の突合**: 入力JSONの全テキスト値（title・items・セル等）が、生成 .pptx の
   `<a:t>` テキスト集合に**過不足なく**含まれる（過=JSONに無いテキストの混入は雛形の固定文言を
   除外リストで管理。不足=取りこぼしは即失敗）。HTML版そのものとの直接比較は PR #194 未マージの
   ためできない。**「同じJSONに対する忠実性」を双方が独立に検査する**分担とし、HTML側の忠実性は
   #194 側の機械検査・差し戻し条件に依存することを限界として明記する。

### 人間の実機確認（PRレビューへ依頼する。依頼文面の要点）

1. 生成した .pptx（サンプルを添付またはブランチから取得）が **PowerPointで警告なく開く**こと
2. テキストがテキストボックスとして、表がネイティブ表として**選択・編集できる**こと
3. **Windows git bash 上で生成スクリプトが動く**こと（`zip` 検出→無ければ `python3` 検出→
   どちらも無ければ明示エラー、の各経路）

## 設計への反映（フェーズ3の個別作業計画への引き継ぎ）

1. スキル `pptx-slides`（`.claude/skills/pptx-slides/`）: SKILL.md＋`scripts/json-to-pptx.sh`＋
   `assets/pptx-template/`（展開ディレクトリ雛形）＋`.claude/scripts/test/test_json_to_pptx.sh`。
2. 生成スクリプトの構造: 入力検証（jq必須キー検査）→ slideN.xml 生成（type別写像）→ 連動4箇所の
   生成 → zip（`zip`→`python3`→明示エラー）→ 機械検証。
3. テストは機械検証7種＋異常系（type不正・必須キー欠落・空入力・zip/python3両不在の明示エラー）。

## 確かめられなかったこと（個別調査計画の完了条件で許容された範囲）

- PowerPoint実機での開封・編集（Windows実機が無い。人間の実機確認へ）。
- Windows git bash での生成スクリプト実行・`zip` 同梱有無（同上）。
- PowerShell `Compress-Archive` の実挙動（Windows実機が無い。却下判断は「検証できない手段を
  自動フォールバックに入れない」という理由であり、その理由自体がこの検証不能性に基づく）。
- LibreOffice等の独立フルパーサでの開封（この環境の soffice はフィルタ欠落で .txt すら読めず
  使用不能。標準ライブラリでの構造検査で代替した）。

## 再現手順（主要コマンド）

```bash
# Q1: 所在確認
command -v zip unzip python3 jar soffice; zip -v | head -2; python3 --version

# Q3: 雛形の生成→zip化→検証（雛形XMLの内容はフェーズ3で assets/ へ収める）
cd <雛形ディレクトリ> && zip -q -X -r out.pptx '[Content_Types].xml' _rels docProps ppt
unzip -t out.pptx
python3 -c "
import zipfile, xml.etree.ElementTree as ET
z=zipfile.ZipFile('out.pptx'); assert z.testzip() is None
[ET.fromstring(z.read(n)) for n in z.namelist() if n.endswith(('.xml','.rels'))]
print('OK')"

# Q2: PR #194 の現物確認
git fetch origin claude/html-slide-skill-template-ymue7k
git show 'origin/claude/html-slide-skill-template-ymue7k:wip/plans/【AIアセット作成】HTMLスライドスキル一式の作成.md'
```
