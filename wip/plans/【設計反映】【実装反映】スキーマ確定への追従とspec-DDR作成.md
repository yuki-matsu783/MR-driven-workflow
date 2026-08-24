---
title: 【設計反映】【実装反映】スキーマ確定への追従とspec・DDR作成
type: plan
description: issue #169 のフェーズ4個別反映計画。PR #194マージで確定した構成案JSONスキーマへ pptx-slides の入力検証・写像を追従させ、spec・DDR・rules への設計反映を行う
tags: [plan, reflection, pptx]
keywords: [反映計画, pptx-slides, スキーマ突合, slide-outline, spec, DDR, patsub_replacement, VERSION]
---

# 【設計反映】【実装反映】スキーマ確定への追従とspec・DDR作成

- issue: #169 / PR: #199 / フェーズ4 flow-id 4-1
- 作成日: 2026-08-24

## 前提（合意状況）

- 上位計画: `wip/plans/json-to-pptx-export-plan.md`。フェーズ3〈作業〉は完了
  （結果: `wip/reports/2026-08-24_json-to-pptx-export-plan_実装.md`。flow-id 3-10 まで実施済み。
  人間のレビュー往復は非対話セッションのため未実施で、進捗記号は `[]` のまま）。
- **PR #194（issue #168）が 2026-08-24T00:33Z にマージされ、構成案JSONスキーマ
  `.claude/skills/html-slides/references/slide-outline.schema.json` が main で確定した**
  （マージは人間の操作）。スキーマは `git show origin/main:<path>` で読める。
- 当ブランチは main から4コミット behind（PR #199 の mergeable_state は clean でコンフリクト
  なし）。**ベースブランチの取り込みは `AskUserQuestion` の承認が必要**（`git-workflow.md`）だが
  非対話セッションで承認を得られないため、**このフェーズでは取り込まない**（flow-id 5-1 で扱う。
  スキーマの参照は取り込み不要で行える）。
- 種別を【設計反映】【実装反映】と併記したのは、**両者に一方向の依存があるため**である:
  spec の入力仕様節（作業項目2）は「確定スキーマとの対応表」を正史として書くもので、
  【実装反映】（作業項目1）でスキーマ追従を終えた実装の姿が定まらないと書けない。分割して
  4-6〜4-10 を2周に分けると、1周目の spec は追従前の実装（スキーマ適合入力を拒否する状態）を
  正史として記述するか、書けないまま空欄で往復するかの二択になる。この依存ゆえに同一 push で
  実装追従と spec を揃えるのが、原則（併記せず分ける。`references/planning.md`）の例外として
  妥当と判断した（敵対的レビューAR-4-03の指摘を受け、当初の理由「非対話セッションで合意を
  1回で取るため」を撤回して差し替えた。非対話セッションでは合意自体が発生しないため）。

## スキーマ突合の結果（この計画の起点）

確定スキーマと現実装（push7時点）の入力仕様の差分。**フェーズ2調査時点で確定していたのは
type enum 8種と meta の構造・`title` 全型必須（上流準拠）で、型別フィールドは暫定だった**
（区分は前提調査レポート「上流スキーマとの整合」節の記載どおり。type enum は現実装の jq が
そのまま持ち確定スキーマとも一致＝変更なし）。**確定スキーマは暫定だった型別フィールドが
想定と大きく異なり、現実装はスキーマ適合入力を拒否する。**

| type | 確定スキーマ（main） | 現実装の想定 | 差分の扱い |
|---|---|---|---|
| （共通） | `additionalProperties: false`。`speakerNotes` は全型任意 | 表に無いキーは無視 | 変更なし（無視方針は維持） |
| meta | `issue` は **integer** | 文字列想定 | `tostring` で吸収済み（変更なし） |
| cover | **`title`・`subtitle` は任意**（省略時 `meta.title`／`meta.subtitle` を採る）。required は `type` のみ | title 全型必須 | **要修正**: cover のみ title 任意にし、meta へのフォールバックを実装 |
| section | **`chapter`（任意。例: 第1章）** | 未対応（無視され消える） | **要修正**: 章番号段落として出力 |
| bullets | `items[]` は **文字列のみ**（1〜6件） | 文字列＋入れ子オブジェクト対応 | **要修正**: スキーマへ揃える（`items` の要素は文字列のみへ検証を狭め、入れ子分岐 `item_text`・`BUL lvl=1` を削除。`additionalProperties: false` のスキーマでは正当な入力に入れ子が現れず、残すとテスト到達不能なデッドコードになるため。敵対的レビューAR-4-11で「維持」から変更） |
| two-column | **`columns[2]`（各要素 `heading`＋`items[]`）** | `left`／`right` | **要修正**: columns 対応へ全面置換 |
| diagram | **`nodes[]`（各要素 `label` 必須＋`note` 任意、2件以上）。edges・caption は存在しない** | nodes（label//id//文字列）＋edges＋caption | **要修正**: ノードのフロー表現（label を「 → 」連結）＋note行へ。edges/caption 処理は削除 |
| table | **`columns[]`（ヘッダ行）**＋`rows[][]` | `headers[]`＋`rows[][]` | **要修正**: キー名を columns へ |
| comparison | **`sides[2..3]`（各要素 `name`＋`points[]`＋`tone`（pro/con/neutral・任意））** | `options[]`（name/pros/cons/verdict） | **要修正**: sides 対応へ全面置換（表: 列=name、行=points の転置） |
| summary | `items[]`＋**`takeaway`（任意。持ち帰り1文）** | items のみ | **要修正**: takeaway を強調段落として出力 |

## 作業項目

### 1.【実装反映】スキーマ確定への追従

対象: `slides-to-records.jq`・`json-to-pptx.sh`・`SKILL.md`・`test_json_to_pptx.sh`。

- **入力検証（jq）を確定スキーマへ揃える**: cover のみ title 任意／two-column は
  `columns`（長さ2・各要素は `heading`（文字列）と `items`（1件以上の配列）を持つ
  オブジェクト）／table は `columns`（1件以上）＋`rows`（各行は配列）／comparison は
  `sides`（2〜3件・各要素は `name`＋`points`（1件以上））／diagram は `nodes`（2件以上・
  各要素は `label` を持つオブジェクト）／bullets・summary は `items`（1件以上、
  **各要素は文字列**——入れ子オブジェクト対応は突合表 bullets 行のとおり削除）。
  違反はキー名を挙げた明示エラー（現行方針の維持）。
- **写像の変更**（レコード形式と受け側 `json-to-pptx.sh` の対応を対で定める。
  `slides-to-records.jq` 冒頭のレコード種別コメントも同時に更新する）:
  - cover: 見出し= `slides[].title // meta.title`、サブタイトル行= `slides[].subtitle //
    meta.subtitle`＋`meta.date`＋`meta.author`（現行のSUB行構成を維持。フォールバックは
    jq側で解決するため受け側の変更なし）。
  - section: `chapter` があれば見出しの**上**に小さめの段落。新レコード
    `CHAP<US>テキスト`（jq側で `chapter` があるときだけ出す）。受け側は
    `CUR_CHAP` バッファを新設（`reset_slide_buffers` へ初期化を追加）し、`flush_slide` の
    `section)` 分岐で `CUR_TITLE` のシェイプの前に段落として描画する。
  - two-column: 各カラムは `heading`（太字段落）＋ `items` の各行。新レコード
    `COLH<US>L|R<US>テキスト`（既存 `COL` と同じ第2フィールドで左右を持つ。
    `columns[0]`→L・`columns[1]`→R に固定）。受け側は `CUR_COLH_L`／`CUR_COLH_R` を新設し、
    各カラムの先頭で太字段落として描画する。既存の `COL<US>L|R<US>行` は維持。
  - comparison: 表（1行目= `name`（`tone` があれば「（採用寄り）（却下寄り）（中立）」を
    後置）、データ行= 各 side の `points` を転置し不足セルは空埋め）。レコードは既存の
    `TROW` をそのまま使う（転置・tone注記はjq側で解決。受け側の表バッファは変更なし）。
  - diagram: `label` を「 → 」で連結した1段落（フロー表現）＋ `note` を持つノードごとに
    「label: note」の行。レコードは新設せず、連結段落と note 行を**箇条書き記号の付かない
    段落**として出すため新レコード `PARA<US>テキスト` を追加する（既存 `BUL` を流用すると
    「•」が付きフロー表現として不自然なため）。受け側は `CUR_PARAS` バッファを新設し
    本文シェイプへ段落として描画する。edges・caption の処理と、ノードの `.id`
    フォールバック・文字列ノード対応は削除（スキーマが `additionalProperties: false` で
    持たないため、正当な入力に現れない）。
  - summary: `items` の箇条書きの後に `takeaway` を太字段落で出力（`PARA` に太字フラグを
    持たせるか `TAKEAWAY` レコードを新設するかは実装時に決め、レコード種別コメントへ残す）。
  - comparison の別名（`.label`／`.advantages`／`.disadvantages`／`.decision`）は sides への
    全面置換で自然に消える。
- **条件7突合の対象外リストへ `slides[].sides[].tone` を追加**（5つへ）。理由: tone は
  見た目の色分け指示子（スキーマのdescriptionが明記）で本文ではなく、値そのもの
  （pro/con/neutral）は日本語注記へ写像され `<a:t>` に現れないため。`slides[].type` と
  同じ扱い。
- **SKILL.md**: 必須キー表・型別表現表を確定スキーマの語彙（columns/sides/nodes等）へ
  書き換える。突合手順の参照先（specのパス）は変更なし。
- **単体テスト**: サンプルJSONをスキーマ適合形へ書き換える（8種type・section.chapter・
  tone・takeaway・note を含める）。**cover はサンプルへ2枚置く**: 1枚目は title/subtitle を
  省略して meta フォールバックを検証し、2枚目は自前の title/subtitle を持たせて上書き側を
  検証する（`.meta.title`／`.meta.subtitle` は1枚目の `<a:t>` に現れるため、条件7の突合対象の
  ままで通る。対象外リストを増やさずにフォールバック両側を検証するためのサンプル設計）。
  - `meta.issue` を integer（169）へ変えるのに伴い、`verify_pptx.py` の
    `norm(data["meta"].get("issue", ""))` を `norm(str(...))` 相当へ修正する（文字列前提の
    `.replace` が AttributeError になるため）。条件7の `walk()` は int を葉として拾わないため
    `.meta.issue` の対象外指定が実質デッドになる点は、specの突合手順の記述に明記する。
  - 個別アサーションを追加: (1) tone 指定どおり「（採用寄り）」「（却下寄り）」「（中立）」が
    `<a:t>` 連結に現れること、(2) cover 1枚目（省略側）のスライドXMLに `meta.title`・
    `meta.subtitle` が現れること（対象外化・フォールバック化で条件7から漏れる写像を個別に固定）。
  - 境界値テストを新語彙へ追従する: 空 columns・sides 1件・nodes 1件・rows 要素が配列で
    ない等。既存テストの扱いを明示する——**そのまま維持**するのは jq途中失敗・制御文字・
    改行入りmeta.title のテスト。**新語彙へ書き換える**のは不揃いな表（`headers`→`columns`）と
    「空headers」「空options」「options要素がオブジェクトでない」（メッセージ文言ごと
    `columns`／`sides` へ）。**削除する**のは「edges要素がオブジェクトでない」と入れ子bullets
    （スキーマが edges・入れ子を持たず、検証・分岐ごと削除するため。テスト本数の後退は
    この2件で、理由を結果レポートへ残す）。検証スクリプトの条件7対象外へ tone を追加。
  - **サンプルが確定スキーマに適合することの機械検証**: この環境は `python3 -c "import
    jsonschema"` が `ModuleNotFoundError`（python 3.11.15。計画時点で実測済み）のため、
    jsonschema には依存しない。**jq による決定的な適合チェックをテストへ組み込む**
    （スキーマJSONを読み、`required` 充足・`additionalProperties: false` の余剰キー検出・
    `type` 判別・`minItems`/`maxItems`・`enum` を検査する。使用語彙が draft-07 の基本のみ
    のため実装可能）。目視確認は完了条件に置かない。

### 2.【設計反映】spec `.claude/docs/spec/pptx-slides.md`（新規）

構成: 背景・目的／仕様／影響範囲／設定項目／未決定事項・懸念点（`docs-workflow.md` の型）。
内容: 入力仕様（確定スキーマとの対応表。要素の型検証を含む）／type別写像（8種）／
rId採番規則・連動5箇所／zip経路試行（能力ベース検出・2段階のエラー方針）／
自己検証の範囲（zip整合性＋必須パーツ＋python検出時のwell-formed）／jq終了コードの検知
（一時ファイル経由の理由）／制御文字の空白化／表の列数決定（全行の最大・不足は空埋め）／
**条件7突合の手順（対象外5つ: `meta.title`・`meta.issue`・`speakerNotes`・`slides[].type`・
`slides[].sides[].tone`。`meta.issue` は integer のため文字列の葉としては現れず、対象外指定が
実質効かない点も明記する）**／PowerPoint製雛形への差し替え前処理条件（調査レポートQ4の記録）／
実機確認の依頼事項（表の罫線を含む4点）。**新規spec作成の人間承認は得られないため、
◆としてPRレビューへ依頼し、HANDOFFの未解決事項に含める。**

### 3.【設計反映】DDR `i0169-01`（新規）

タイトル案: 「pptx書き出しは雛形展開ディレクトリとzip再梱包で実装しpython-pptx等の
外部依存を持たない」。却下案（調査レポート「設計への反映」の5件が原文）:
クリップボード経由の貼り付け／python-pptx等のライブラリ／XMLゼロから生成／
バイナリ雛形（.pptxをリポジトリへ同梱）／PowerShell `Compress-Archive`。
作成後に `bash .claude/scripts/src/generate-ddr-list.sh` を実行し、README差分を同じ
コミットへ含める。

### 4.【設計反映】rules・既存ドキュメントの整合

- `.claude/rules/directory-structure.md`: skills ツリーへ `pptx-slides/` を追記
  （assets/scripts の実例として）。
- `index.md`（Repository Map）: skills 列挙へ `pptx-slides`（構成案JSONからの .pptx 生成。
  issue #169）を追記する。`directory-structure.md` 冒頭が「役割説明は index.md を正とする」と
  定めており、main 側の直前の同型変更（issue #168／html-slides）も index.md を更新している。
- **上記2ファイルは main 側でも同じ箇所（skills の列挙）が html-slides の追記で変更済みの
  ため、flow-id 5-1 の main 取り込みで同じ箇所のコンフリクトが起きうる。解消時は両方の行を
  残す**（この注意を worklog にも残す）。
- `.claude/rules/shell-script-style.md`: **bash 5.2 `patsub_replacement` の罠**
  （パラメータ展開の置換文字列中の `&` がマッチ全体へ展開される。sedと同じ罠が
  bash 5.2以降の既定ONで存在し、`shopt -u patsub_replacement 2>/dev/null || true` で
  無効化する）を「パラメータ展開の既定値」節の近くへ追記する。実測の根拠は結果レポート。
- `.claude/VERSION`: layer=core の配布対象アセット追加のため MINOR 増分が要る。
  **ただし当ブランチの値は 0.4.0（分岐時点）で main は 0.5.0 のため、今書き換えると
  必ずコンフリクトする。flow-id 5-1 で main を取り込んだ直後に 0.5.0→0.6.0 へ増分する**
  （VERSIONファイル自体はこのフェーズでは触らない）。
  - **据え置きの記録**（`distribution-assets.md` の規定 (c)。据え置く場合もspecのchangelogへ
    事実を残す）: flow-id 4-6 で `.claude/docs/spec/distribution-assets.md` のchangelogへ
    issue #169 のエントリを追加し、(i) 配布対象アセット（`.claude/skills/pptx-slides/` 一式・
    新規spec・新規DDR）が増えたこと、(ii) 分岐状況のため本フェーズでは据え置き、5-1 の
    取り込み直後に 0.5.0→0.6.0（MINOR）を適用する予定であること、を残す。HANDOFF
    「判断を迷った内容」へも同じ判断を記載する（記載済み）。5-1 でVERSIONを書けなかった場合
    （権限拒否の先例が同specにある）は、人間へ報告して据え置く。

## やらないこと（スコープ外）

- main の取り込み（flow-id 5-1。承認が必要なため）と `.claude/VERSION` の増分（同上）。
- `.gemini/` への変換同期（flow-id 5-3）。
- speakerNotes（notesSlide）出力・`tableStyles.xml` 同梱（実機確認の結果待ち。
  結果レポートの残課題）。
- html-slides スキル側（PR #194 成果物）の変更。

## 検証（この作業自体の完了条件）

- 全 `.sh` が `bash -n` を通り、`bash .claude/scripts/test/test_json_to_pptx.sh` が
  `failures=0`（スキーマ適合サンプルでの機械検証12項目・両zip経路を含む）。
- スキーマ適合の確認: サンプルJSONが `origin/main` のスキーマに適合することを、単体テストへ
  組み込む **jq による決定的な適合チェック**（required／余剰キー／型／minItems・maxItems／
  enum）で機械検証する（python の jsonschema はこの環境に無いことを計画時点で実測済み——
  `ModuleNotFoundError`。目視確認は完了条件に置かない）。適合チェック自体が異常を検出できる
  ことは、意図的に不適合なJSON（余剰キー等）を1件与えて失敗することで確かめる。
- 既存機構への影響確認（フェーズ3と同じ3コマンドを名指しで固定）: `.claude/scripts/test/`
  全件・`bash .claude/scripts/src/check-dist-coverage.sh`・
  `bash .claude/scripts/src/extract-frontmatter.sh .`。
- `bash .claude/scripts/src/generate-ddr-list.sh` の差分がREADMEのDDR一覧の1行追加のみで
  あること。`bash .claude/scripts/src/check-doc-references.sh` で参照切れ0。
- 結果は `wip/reports/2026-08-24_json-to-pptx-export-plan_反映.md`（+同名.html）へ記録する
  （本計画へは書かない）。
