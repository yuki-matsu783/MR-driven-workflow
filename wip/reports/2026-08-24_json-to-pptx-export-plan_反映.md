---
title: 反映結果: スキーマ確定への追従とspec・DDR作成
type: report
description: issue #169 フェーズ4〈反映〉（flow-id 4-6）の実施結果。確定スキーマへの実装追従（jq検証・写像・テストの全面改修）と、spec pptx-slides.md・DDR i0169-01・rules/index.md 整合・VERSION据え置き記録の正文
tags: [report, pptx, reflection]
keywords: [反映結果, pptx-slides, スキーマ追従, slide-outline, spec, DDR, schema_check, patsub_replacement, 条件7]
---

# 反映結果: スキーマ確定への追従とspec・DDR作成

- issue: #169 / PR: #199 / フェーズ4 flow-id 4-6。実施日: 2026-08-24
- 計画: `wip/plans/【設計反映】【実装反映】スキーマ確定への追従とspec-DDR作成.md`（結果は本レポートへ分離）

## 1. 概要（何をしたか）

1. 【実装反映】PR #194 マージで確定した構成案JSONスキーマへ、pptx-slides の入力検証・写像・
   SKILL.md・単体テストを追従させた。**旧語彙（headers/options/left/right）・edges/caption・
   入れ子bulletsの受け付けは削除**し、cover metaフォールバック・section.chapter・
   カラム見出し（COLH）・sides転置＋tone注記・takeaway・diagramフロー表現を追加した。
2. 【設計反映】spec `.claude/docs/spec/pptx-slides.md`（新規）・DDR `i0169-01`（新規・
   却下案5件の記録）＋DDR一覧再生成・`directory-structure.md`／`index.md` のskills追記・
   `shell-script-style.md` へ `patsub_replacement` の罠を追記・`distribution-assets.md` の
   changelogへVERSION据え置きの記録を追加した。

## 2. 実施内容の詳細

### 2-1. slides-to-records.jq（入力検証・写像の全面改修）

- 検証: cover のみ title 任意（あれば文字列）／two-column は `columns[2]{heading,items[1..]}`／
  table は `columns[1..]`＋`rows[][]`（各行は配列）／comparison は `sides[2..3]{name,points[1..]}`／
  diagram は `nodes[2..]{label}`／bullets・summary は `items[1..]`（**各要素は文字列**）。
  違反はキー名を挙げた明示エラー（従来方針の維持）。
- 写像: cover 見出し=`title // meta.title`・サブタイトル=`subtitle // meta.subtitle`＋date＋author／
  section の `chapter` は新レコード `CHAP`／two-column のカラム見出しは新レコード
  `COLH<US>L|R`（columns[0]→L・columns[1]→R 固定）／comparison はヘッダ=`name`＋tone注記
  （pro→（採用寄り）・con→（却下寄り）・neutral→（中立））・データ行=`points` の転置
  （不足セル空埋め。既存TROW流用）／diagram は `label` の「 → 」連結1段落＋`note` 行を
  新レコード `PARA<US>b|n`（箇条書き記号なし）で出力／summary の `takeaway` は `PARA b`（太字）。
- レコード種別コメント（ファイル冒頭）を新形式へ更新した。

### 2-2. json-to-pptx.sh（受け側）

- `CUR_CHAP` バッファを新設（`reset_slide_buffers` へ初期化を追加）し、section の
  `flush_slide` 分岐で見出しの上に描画。`CHAP`/`COLH`/`PARA` のハンドラを追加。
- **計画との差分（実装で簡素化した2点）**: 計画は `CUR_COLH_L/R`・`CUR_PARAS` の新設バッファを
  挙げていたが、jqが「heading → items」「フロー段落 → note行 →（summaryでは items → takeaway）」の
  順でレコードを出すため、**COLH は既存の `CUR_COL_L/R`、PARA は既存の `CUR_BODY` への追記で
  同じ描画結果になる**（新設したのは CUR_CHAP のみ）。takeaway は TAKEAWAY レコード新設ではなく
  `PARA` の太字フラグ（`b|n`）で表現した（計画が「実装時に決めてコメントへ残す」とした点）。

### 2-3. SKILL.md・spec・DDR・rules

- SKILL.md: 入力節・型別表現表を確定スキーマの語彙へ書き換え（入力仕様の正がスキーマである
  ことを明記）。
- spec `pptx-slides.md`: 入力仕様対応表／type別写像8種／レコードストリーム／rId採番・連動5箇所／
  zip経路試行／自己検証／条件7突合（**対象外5つ**。`meta.issue` は integer のため文字列の葉に
  現れず対象外指定が実質効かない点を明記）／PowerPoint製雛形の前処理条件3つ／実機確認依頼4点。
  **新規spec作成の人間承認は未取得（◆）。**
- DDR `i0169-01`: 却下案5件（クリップボード経由／python-pptx／XMLゼロから生成／バイナリ雛形／
  Compress-Archive）を前提調査レポートの原文で記録。`generate-ddr-list.sh` の差分は
  README のDDR一覧1行追加のみ。
- `directory-structure.md`: skills ツリーへ `pptx-slides/` を追記。`index.md`: skills 列挙へ
  `/pptx-slides` を追記（**main側は同じ箇所へ html-slides を追記済みのため、flow-id 5-1 の
  取り込みで両ファイルとも同箇所のコンフリクトが起きうる。解消時は両方の行を残す**）。
- `shell-script-style.md`「パラメータ展開の既定値」節の先頭へ bash 5.2 `patsub_replacement` の
  罠（`${s//</&lt;}` が `<lt;` になる・`shopt -u` で無効化）を追記。
- `distribution-assets.md` changelog: issue #169 エントリを追加（MINOR対象のアセット追加・
  当ブランチ0.4.0／main 0.5.0 の分岐状況により**このフェーズでは据え置き**・5-1 直後に
  0.5.0→0.6.0 適用予定・書けなかった場合は人間へ報告）。
- ユースケース文書への影響: `.claude/docs/usecase/` にスライド・pptx関連の記述は無く、
  影響なし（`grep -rln 'pptx\|スライド' .claude/docs/usecase/` = 0件）。

### 2-4. 単体テスト（test_json_to_pptx.sh）

- サンプルJSONをスキーマ適合形へ全面書き換え（8種type・**cover 2枚**・chapter・tone 3種・
  takeaway・note・特殊文字・値内改行・`meta.issue`=169（integer））。cover 2枚は
  「1枚目=metaフォールバック・2枚目=自前 title/subtitle」で、`.meta.title`/`.meta.subtitle` が
  1枚目の `<a:t>` へ現れるため条件7の突合対象のままで通るサンプル設計（計画どおり）。
- `verify_pptx.py`: `meta.issue` の integer 化に伴い `norm(str(...))` へ修正。条件7の対象外へ
  `slides[].sides[].tone` を追加（5つ）。
- **個別アサーション6件を追加**: tone注記3種が生成物に現れること・cover省略側に
  meta.title/meta.subtitle が現れること・cover自前側で自前値が優先され meta.subtitle が
  出ないこと（対象外化・フォールバック化で条件7から漏れる写像の固定）。
- **スキーマ適合の機械検証**: python の jsonschema はこの環境に無い（`import jsonschema` が
  `ModuleNotFoundError`・python 3.11.15）ため、**jq による決定的な適合チェック
  （`schema_check.jq`: $ref解決・type（integer含む）・enum・const・required・
  additionalProperties:false の余剰キー・minItems/maxItems・items再帰・oneOf は
  `properties.type.const` で枝選択）をテストへ組み込んだ**。スキーマはワーキングツリー →
  `origin/main` の順で解決し、どちらからも得られなければ**失敗として数える**（目視へ
  縮退させない）。空振り排除として、意図的に不適合なJSON（余剰キー＋enum違反）で
  ちょうど2件検出されることも検査した。
- 境界値テストを新語彙へ追従: 空columns（table）・rows要素非配列・sides 1件・sides要素の
  points欠落・nodes 1件・nodes要素非オブジェクト・two-columnのcolumns 1件・columns要素の
  items欠落・items要素が文字列でない（入れ子拒否）・coverのtitle非文字列・全セル空の表。
- **削除したテスト（2系統・後退の記録）**: 「edges要素がオブジェクトでない」（スキーマが
  edges を持たず検証ごと削除したため）と、入れ子bullets（サンプルから除去し、逆に
  「入れ子は明示エラーで拒否される」テストへ置き換え）。維持したのは jq途中失敗・制御文字・
  改行入りmeta.title・不揃いな表（`columns` へ改名）・経路系・speakerNotes警告の各テスト。

## 3. 検証結果（実測。実行日 2026-08-24）

初回実施（push10。コミット前のワーキングツリー）とP4R2反映後（push11。コミット前の
ワーキングツリー）の両方を残す。数値の分母（`check-dist-coverage.sh`等）は追跡ファイルの
みを数えるため、コミット前後で変わる（詳細は章6参照）。

| 検証 | push10時点 | push11（P4R2反映後）時点 |
|---|---|---|
| `bash -n`（json-to-pptx.sh・test_json_to_pptx.sh） | エラーなし | エラーなし |
| `bash .claude/scripts/test/test_json_to_pptx.sh` | `passed=88 failures=0` | `passed=111 failures=0`（境界値11件・個別アサーション4件・全セル空の表テスト書き換え4件で+23） |
| 既存テスト全件（`test_*.sh` 22本） | 全件 rc=0 | 全件 rc=0 |
| `bash .claude/scripts/src/check-dist-coverage.sh` | 501/501（4-1の計画ファイル追加分をコミット済みの状態） | 506/506（push10の新規5ファイルをコミット済みの状態） |
| `bash .claude/scripts/src/extract-frontmatter.sh .` | `files=182 built=11 reused=171 failed=0` | `files=184 built=6 reused=178 failed=0` |
| `bash .claude/scripts/src/generate-ddr-list.sh` | README差分はDDR一覧の1行追加のみ（95件） | 差分なし（95件。DDR本文の文言修正のみでfrontmatterは変更していないため） |
| `bash .claude/scripts/src/check-doc-references.sh` | 参照切れ0（候補255件・走査392ファイル） | 参照切れ0（候補255件・走査396ファイル） |

スキーマ適合チェックは上記テスト内で実施（`スキーマ適合: サンプルが確定スキーマに適合する` と
`不適合サンプルで2件検出` の2アサーション）。

## 4. 想定と異なった点・踏んだ罠

- **ツール呼び出しのJSONデコードで `\uXXXX` が生バイト化する罠を再度踏んだ**（このタスクで
  4回目）。Writeツールで `slides-to-records.jq` を書いた際、u001f・u0000〜u001f の
  Unicodeエスケープ表記（バックスラッシュ＋uXXXXの6文字）が生の制御バイト7個として
  ファイルへ入った。バイト数比較
  （`wc -c` と `tr -d` 後の比較）で即検出し、pythonでエスケープ表記の文字列へ修復した。
  **jqフィルタ内のエスケープ表記を含むファイルはWriteで書いた直後に必ずバイト数比較で検査する**
  （`shell-script-style.md` の既存ルール「ソースコードへ生の制御文字を書かない」の
  ツール経由版。worklog push8 参照）。
- **jqの「パイプ右辺で `.` が差し替わる」罠**（`shell-script-style.md` 記載済み）を
  `schema_check.jq` の `has(.)` で踏んだ（`$v | has(.)` の `.` が `$v` 自身になる）。
  先に `. as $k` へ束縛して解消。既存ルールどおりの現象で、新規の追記は不要と判断した。
- 受け側の実装は計画より簡素になった（2-2の「計画との差分」参照。新設バッファは
  CUR_CHAP の1つで足りた）。

## 5. 残課題（フェーズ5以降へ）

- flow-id 5-1: main 取り込み（要承認）→ 直後に `.claude/VERSION` 0.5.0→0.6.0 適用 →
  `directory-structure.md`・`index.md` の skills 箇所のコンフリクト解消（両方の行を残す）。
- ◆ spec `pptx-slides.md` の新規作成承認・実機確認4点（表の罫線含む）・調査レポート◆3件への
  回答は、引き続きDraft解除（5-6）前の必須ゲート。
- speakerNotes（notesSlide）出力・`tableStyles.xml` 同梱は実機確認の結果待ちの後続課題。

## 6. 敵対的レビュー2回目（P4R2）の反映（push11）

対象diff: push10（3f5224d..df6f1f6）。指摘12件（major1・minor11）のうち11件をPR #199へ
インライン投稿、1件は報告のみ（HANDOFFの「現在のループ」欄が`なし`のまま食い違っていた件。
`set-header --loop`で即時対応）。11件全件を反映した。

| # | severity | 概要 | 対応 |
|---|---|---|---|
| AR-4-12 | major | `clean`がC0制御文字のみ正規化しU+FFFE/FFFFでXML生成が失敗、しかも誤診断メッセージ | `clean`正規表現へufffe/uffff追加。生成失敗と検証失敗を区別し全経路が後者なら入力起因メッセージへ分岐 |
| AR-4-13 | minor | トップレベル非オブジェクトでjqがエラー終了しバグ報告へ誤誘導 | 検証全体をif-elseでラップし型チェックを先頭へ |
| AR-4-14 | minor | スキーマ上正当な空文字列titleを拒否 | 空文字列チェックを削除（型チェックのみ） |
| AR-4-15 | minor | two-column/table/comparison/diagramの要素型検証漏れ | 4箇所へ`type != "string"`検査を追加 |
| AR-4-16 | minor | specの検証内容表に未検証3項目が記載 | 「検証内容」「検証しない」の2列表へ再構成（SKILL.mdも同期） |
| AR-4-17 | minor | 「jq適合チェックが同期を固定する」は過剰主張 | spec・DDR i0169-01の文言を実態に合わせて弱める |
| AR-4-18 | minor | `read -a`が末尾空セルを落とし表の列数が過小評価される | TROWレコードへセル数を明示フィールド化（jq・bash両側） |
| AR-4-19 | minor | 計画で削除予定だった`BUL lvl=1`分岐が残存・無記録 | lvl引数を削除し常時lvl=0の描画へ統一 |
| AR-4-20 | minor | 新設4写像に個別アサーションが無い | slide3/5/8/9を直接パースする個別アサーション4件を追加 |
| AR-4-21 | minor | レポートの「501/501」がコミット前の値で事実誤り | md・html3箇所を506/506＋説明へ訂正 |
| AR-4-23 | minor | 新規specがREADMEのspec一覧に未掲載 | 一覧末尾へ追記 |

修正の詳細・踏んだ罠（AR-4-18修正で既存テストが1件、AR-4-18バグに依存していたことが
判明し書き換えた経緯）は `wip/worklogs/..._push11.md` を参照。
