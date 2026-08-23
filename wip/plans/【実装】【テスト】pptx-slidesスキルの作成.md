---
title: 【実装】【テスト】pptx-slidesスキルの作成
type: plan
description: issue #169 のフェーズ3個別作業計画。構成案JSONから編集可能な .pptx を生成する pptx-slides スキル（SKILL.md・生成スクリプト・展開ディレクトリ雛形）と単体テストを作成する
tags: [plan, implementation, pptx]
keywords: [作業計画, pptx-slides, json-to-pptx, OOXML, 雛形, zip, jq, 単体テスト, rId採番]
---

# 【実装】【テスト】pptx-slidesスキルの作成

- issue: #169 / PR: #199 / フェーズ3 flow-id 3-1
- 作成日: 2026-08-23（敵対的レビュー（フェーズ3の1回目）の指摘14件を反映して改訂）

## 前提（合意状況）

- 上位計画: `wip/plans/json-to-pptx-export-plan.md`。フェーズ2〈調査〉は完了し、設計の根拠は
  調査レポート `wip/reports/2026-08-23_json-to-pptx-export-plan_前提調査.md`（以下「調査レポート」）
  のQ1〜Q6の結論とする。
- flow-id 2-8/2-9（人間のレビュー往復）と調査レポートの◆3件（雛形方針・speakerNotes採否・
  完了条件の一部未達のままの進行可否）は**人間の回答を得ていない**。人間のレビュー往復を
  待てないセッションのため、下記の仮決めで**未回答のまま暫定で進める（承認は得ていない）**。
  ユーザーの当初指示が認めているのは「敵対的レビューを自動で回しながら進めること」までで、
  ◆3件そのものへの回答ではない。◆3件は `HANDOFF.md` の「判断を迷った内容」「未解決の内容」へ
  転記し、**フェーズ5のDraft解除（flow-id 5-6）前に人間の回答を得ることを必須の前提とする**
  （レビューで覆れば本計画ごと修正する）。
- 種別を【実装】【テスト】と**併記**したのは、非対話セッションでフェーズごとに合意を挟めず、
  スキル一式＋テストの合意を1回で取るためである。**SKILL.md は【AIアセット作成】として分けず
  【実装】に含める**: SKILL.md はスクリプトの使用説明としてスクリプト本体と不可分であり、
  単体で作成・合意する意味が無いため（主たる成果物は「スキル一式」であり、この判断で
  8種の種別の外のラベルは使わない）。

### ◆未回答のまま暫定で進めるための仮決め（承認は得ていない。レビューで覆せる）

| ◆ | 仮決め | 理由 |
|---|---|---|
| Q4 雛形方針 | 手組みの展開ディレクトリで進める | 調査レポートの比較検討どおり。PowerPoint製への差し替えは前処理条件をspecへ残すのみで、実装はスコープ外 |
| Q5 speakerNotes | **フェーズ3では出力しない**（SKILL.mdへ「speakerNotesは出力されない」と明記し、条件7突合の対象外リストへ `speakerNotes` を入れる。**ただし無警告では捨てない**——入力に `speakerNotes` が1件でもあれば標準エラーへ件数付きで警告する（終了コードは0のまま）） | 連動コストがスライド枚数に比例して2種類増える（調査レポートQ5）割に、テキストの編集可能性という受け入れ条件の本筋に寄与しない。後続issueで追加できる形（notesSlideを持たない構成は追加に対して開いている）を保つ。警告を出すのは「HTML版には出るがpptx版には出ない情報がある」という条件7の後退を、利用者が観測できる形にするため |
| 完了条件未達 | PowerPoint実機確認（Q6の依頼文面）を代替として進める。**実機確認の結果が返るまで flow-id 5-6（Draft解除）へ進まない**（下記「検証」の完了条件） | この環境ではOOXMLフルパーサが使用不能（実測済み）。受け入れ条件3・4・5は実機確認でしか検証できないため、未検証のままmainへ入れないゲートを置く |

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

`.claude/skills/pptx-slides/scripts/json-to-pptx.sh`。構造は調査レポート「設計への反映」1を
ベースに、次の順で処理する:

1. **入力検証**:
   - まず `jq empty` でJSON構文を検査する。**不正JSONはファイルパスとjqのエラーメッセージを
     添えて明示エラー・非0終了**（`set -e` 任せの無言終了にしない）。
   - 次にjqで必須キー検査（調査レポートQ2の必須キー表。type enum 8種・title全型必須・
     型別必須キー。表に無いキーは無視する）。違反はキー名を挙げて明示エラー・非0終了。
   - **`speakerNotes` を持つスライドが1件でもあれば、標準エラーへ件数付きで
     「このスキルはspeakerNotesを出力しない」と警告する**（終了コードは0のまま処理継続）。
2. **作業ディレクトリの用意**: `mktemp -d` した一時ディレクトリへ**雛形をコピーしてから**
   加工する（Git管理下の雛形の実体には触れない。プレースホルダ置換をリポジトリ内で行うと
   差分が出る・2回目以降はトークンが消えている、という壊れ方をするため）。
   `trap 'rm -rf "$tmp"' EXIT` で**正常・異常のどちらでも一時ディレクトリを残さない**。
3. **slideN.xml 生成**: type別写像（調査レポートQ5の表。cover/section/bullets/two-column/
   table/summary はテキストボックス `<p:sp>`＋表 `<a:tbl>`、diagram→箇条書き代替、
   comparison→表代替）。
4. **連動5箇所の生成**: `[Content_Types].xml`・`presentation.xml`（sldIdLst）・
   `presentation.xml.rels`（rId1=slideMaster・rId2=theme予約、スライドはrId3から連番）・
   `docProps/app.xml`（Slides枚数）・スライド毎rels。
5. **zip梱包（経路試行）**: 能力ベース検出で使える経路を順に試す。
   - 経路1: `command -v zip` があれば `zip -X -D -r` で生成し、直後に自己検証
     （zip整合性＋必須パーツ存在）。**検証に失敗したらその出力を削除して経路2へ進む**。
   - 経路2: `python3` → `python` → `py -3` の順に `import zipfile` の成否で実行可能な
     候補を探して生成し、直後に自己検証。**検証に失敗したらその出力を削除する**。
   - **最後の経路まで失敗（または使える経路が1つも無い）場合は、明示エラーで非0終了する**
     （出力ファイルは残さない）。経路選択の試行と「最終的な失敗」を混同しない——
     途中経路の検証失敗はフォールバック、全経路の失敗が非0終了である。
   - `[Content_Types].xml` を先頭に格納する。**経路間の一致条件は「エントリ集合の一致＋
     先頭が `[Content_Types].xml`＋ディレクトリエントリ0件」であり、順序全体の一致は
     条件にしない**（`zip -r` の格納順はファイルシステムの走査順に依存するため。先頭配置は
     スクリプト側で明示的に制御する）。

決めごと:

- CLI: `bash json-to-pptx.sh <入力.json> [出力.pptx]`。出力省略時は入力と同じディレクトリの
  `<ベース名>.pptx`（入力名が `<ベース名>.slides.json` なら `.slides` も落とす。拡張子の無い
  入力名は `<入力名>.pptx`）。**既存の出力ファイルは上書きする**（生成物のため）。出力先が
  ディレクトリ・親ディレクトリが存在しない場合は明示エラー・非0終了。
- **XMLエスケープ**: JSONの全テキスト値は `&` `<` `>` `"` `'` をエスケープしてから
  XMLへ埋める（jqの `@html` は `'` を実体参照化しないため自前の置換で5種を揃える。
  エスケープ関数は純粋関数として切り出し単体テスト対象にする）。
- **テキスト中の改行**: `<a:t>` は改行を保持しないため、値内の改行は `<a:br/>` ではなく
  段落分割（複数 `<a:p>`）で表現する（bullets等の配列要素と同じ構造に揃える）。
- **プレースホルダ置換はbashのパラメータ展開（`${content//__PPTX_TITLE__/$escaped}`）で行い、
  `sed`/`awk` を使わない**（置換文字列中の `&` がマッチ全体へ展開される・エスケープが
  再解釈される罠があるため。`.claude/rules/shell-script-style.md`「文字コード」節。
  エスケープ済みの値は必ず `&` を含みうるので、この罠は必ず発火する）。
- **meta の写像**（条件7突合との整合が正になるよう `<a:t>` へ出すものを明確にする）:
  - `meta.subtitle`・`meta.date`・`meta.author` → **cover スライドのサブタイトル行群として
    `<a:t>` へ出す**（調査レポートQ5のcover表現「タイトル大＋サブタイトル・日付・作成者」の
    とおり。cover の見出し大は各スライド必須の `title` フィールドが担う）。
    `meta.author` は `docProps/core.xml` の `dc:creator` へも併記する。
  - `meta.title` → `docProps/core.xml` の `dc:title` のみ（**`<a:t>` へは出さない**。
    cover の見出しは `slides[].title` が担い、通常 `meta.title` と重複するため）。
  - `meta.issue` → `cp:keywords`（docProps行き）。
  - core.xml はコピー後の作業ディレクトリ上で固定トークン（`__PPTX_TITLE__` 等）を
    パラメータ展開で置換して埋める。
- **条件7突合の対象外リスト（上記写像から機械的に決まる）**: `meta.title`・`meta.issue`
  （いずれもdocProps行きで `<a:t>` に現れない）・`speakerNotes`（本フェーズでは出力しない）。
  **この3つを除く入力JSONの全葉テキスト値が突合対象**である。対象外が3つある分だけ
  受け入れ条件7の担保範囲は狭まる（`meta.title`・`meta.issue` はdocPropsとして、
  `speakerNotes` は警告として観測可能にする、が代替）。
- **シェル規約**: `.claude/rules/shell-script-style.md` に従う（`set -euo pipefail`・
  ループ内で外部コマンドを呼ばずjq呼び出しをスライド単位以下へ集約・`REPLY`返し・
  BOM無しUTF-8/LF・`--argjson`へ大きなJSONを渡さずファイルパス渡し）。

### 3.【実装】`SKILL.md`

`.claude/skills/pptx-slides/SKILL.md`（frontmatter: name/description/title/type/tags/keywords。
上記「前提」のとおり、スクリプトの使用説明として【実装】に含める）。
内容: 入力（構成案JSONのパスと必須キー）・実行方法・出力・**speakerNotesは出力されない**旨
（警告が出ることを含む）・制約（PowerPoint実機確認をレビューで依頼すること・
Windows git bashでの検出経路）・PR #194 スキーマ確定時の突合について。

- **SKILL.md から `wip/reports/` の調査レポートを参照しない**（flow-id 5-5 で削除され、
  配布先にはそもそも存在しないため）。突合手順の正は**フェーズ4で作成する
  `.claude/docs/spec/pptx-slides.md`（仮名）へ書き**、SKILL.md からはそのspecのパスと
  issue番号（#169 / #168）だけを参照する。フェーズ4までの間、突合手順の正文は
  調査レポートQ2にあるが、SKILL.md はそれを指さずspecの完成を待つ
  （フェーズ4の個別反映計画へこの引き継ぎを明記する）。
- 命名 `pptx-slides` は調査レポートQ5で確定済み（html-slides と対になる機能名詞）。

### 4.【テスト】単体テスト `test_json_to_pptx.sh`

`.claude/scripts/test/test_json_to_pptx.sh`（`passed=N failures=N` 規約・失敗時終了コード1）。

- **正常系（機械検証10種**（調査レポートQ6。検証8種＋a:tbl存在＋条件7突合）**）**:
  8種type全部入り・**スライド3枚以上**のサンプルJSON（テスト内でヒアドキュメント生成）で
  .pptx を生成し、10種を検査する。条件7突合は「入力JSONの葉テキスト値ごとの部分一致
  （全 `<a:t>` 連結文字列へ）。対象外= `meta.title`・`meta.issue`・`speakerNotes`」で実装する。
  経路間突合の一致条件は上記の決めごと（集合一致＋先頭＋ディレクトリエントリ0件。
  順序全体は比較しない）。
- **異常系**:
  - 入力起因: type不正／必須キー欠落（title欠落を含む）／空slides／入力ファイル無し／
    **入力ファイルは在るがJSONとして構文エラー**（パスとjqのエラーを含む明示エラーになること）。
  - 出力先起因: 出力先がディレクトリ／親ディレクトリ不在（いずれも明示エラー）。
  - 経路起因: zip・python3両不在の明示エラー（PATH差し替えスタブ）／
    **「存在するが実行できない `python3`」スタブ（呼ばれたら非0で終了）で `python` → `py -3`
    への候補送りが働くこと・全候補が失敗したら明示エラーになること**（能力ベース検出が
    存在確認と違う挙動をする、という採用理由そのものの検証）／
    **「`zip` はあるが失敗する」スタブで経路2へフォールバックすること**。
  - 後始末: **生成失敗時に出力ファイルが残らないこと・一時ディレクトリが残らないこと**。
  - 警告: **speakerNotes入りJSONで標準エラーへ警告が出ること（終了コードは0）**。
- **純粋関数の単体**: XMLエスケープ関数（5種の特殊文字・改行・日本語。`&` `<` 混在・`/` 入り・
  改行入りの `meta.title` を通した core.xml 生成まで含める）。
- python3経路のテスト: この環境では両経路が実行可能なため、`zip` をPATHから隠した状態で
  経路2に落ちること＋生成物が検証を通ることを確認する。

## やらないこと（スコープ外）

- speakerNotes（notesSlide/notesMaster）の出力（上記の仮決め。SKILL.mdへ明記し、入力に
  含まれる場合は警告を出す）
- PowerPoint製雛形への差し替え機能の実装（前処理条件の記録はフェーズ4のspecで行う）
- PR #194 側成果物（html-slides・スキーマファイル）の変更
- spec/DDR・`.gemini/` 変換同期（フェーズ4・5の担当。SKILL.mdが参照するspecの作成を含む）

## 検証（この作業自体の完了条件）

- 全 `.sh` が `bash -n` を通る。
- `bash .claude/scripts/test/test_json_to_pptx.sh` が `failures=0` で通り、その出力を
  結果レポートへ生のまま貼る。
- 8種type全部入りサンプルから生成した .pptx が機械検証10種に合格する（両zip経路とも）。
- **既存機構への影響確認（実行するコマンドを名指しで固定する。「波及なし」の自己申告で
  済ませない）**:
  - `.claude/scripts/test/` の既存テストを**全件**実行し、新規追加分を除いて結果が
    変わらないこと。
  - `bash .claude/scripts/src/check-dist-coverage.sh` が通ること（`.claude/` 配下への
    新規ファイル追加が層分け定義に被覆されていること）。
  - `bash .claude/scripts/src/extract-frontmatter.sh .` が新規の SKILL.md を含めて
    エラーなく走ること。
- PowerPoint実機・Windows git bash実機の確認は本フェーズでは行えない（調査レポートQ6の
  依頼文面でPRレビューへ依頼する。結果レポートへ依頼事項として明記する）。
  **この実機確認の結果が返るまで、フェーズ5の flow-id 5-6（Draft解除）へ進まない**
  （受け入れ条件3・4・5が未検証のままmainへ入ることを防ぐゲート。`HANDOFF.md` の
  「守るべき条件」にも同じゲートを記載する）。
