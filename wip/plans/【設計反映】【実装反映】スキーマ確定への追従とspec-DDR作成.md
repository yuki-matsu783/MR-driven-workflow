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
- 種別を【設計反映】【実装反映】と併記したのは、スキーマ確定への実装追従（フェーズ3成果物の
  修正）と spec/DDR/rules への設計反映が同じ根（スキーマ確定と実装完了）から出ており、
  非対話セッションで合意を1回で取るため。

## スキーマ突合の結果（この計画の起点）

確定スキーマと現実装（push7時点）の入力仕様の差分。**フェーズ2調査時点では方針レベル
（8種type enum・meta・型別フィールドは未確定）であり、現実装の型別キーは当時の想定に
基づいていた。確定スキーマは想定と大きく異なり、現実装はスキーマ適合入力を拒否する。**

| type | 確定スキーマ（main） | 現実装の想定 | 差分の扱い |
|---|---|---|---|
| （共通） | `additionalProperties: false`。`speakerNotes` は全型任意 | 表に無いキーは無視 | 変更なし（無視方針は維持） |
| meta | `issue` は **integer** | 文字列想定 | `tostring` で吸収済み（変更なし） |
| cover | **`title`・`subtitle` は任意**（省略時 `meta.title`／`meta.subtitle` を採る）。required は `type` のみ | title 全型必須 | **要修正**: cover のみ title 任意にし、meta へのフォールバックを実装 |
| section | **`chapter`（任意。例: 第1章）** | 未対応（無視され消える） | **要修正**: 章番号段落として出力 |
| bullets | `items[]` は **文字列のみ**（1〜6件） | 文字列＋入れ子オブジェクト対応 | 現実装が超集合。維持（入れ子はスキーマ外だが害なし） |
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
  各要素は `label` を持つオブジェクト）／bullets・summary は `items`（1件以上）。
  違反はキー名を挙げた明示エラー（現行方針の維持）。
- **写像の変更**:
  - cover: 見出し= `slides[].title // meta.title`、サブタイトル行= `slides[].subtitle //
    meta.subtitle`＋`meta.date`＋`meta.author`（現行のSUB行構成を維持）。
  - section: `chapter` があれば見出しの上に小さめの段落（新レコード CHAP）。
  - two-column: 各カラムは `heading`（太字段落。新レコード COLH）＋ `items` の各行。
  - comparison: 表（1行目= `name`（`tone` があれば「（採用寄り）（却下寄り）（中立）」を
    後置）、データ行= 各 side の `points` を転置し不足セルは空埋め）。
  - diagram: `label` を「 → 」で連結した1段落（フロー表現）＋ `note` を持つノードごとに
    「label: note」の行。edges・caption の処理は削除（スキーマが
    `additionalProperties: false` で持たないため、正当な入力に現れない）。
  - summary: `items` の箇条書きの後に `takeaway` を太字段落で出力。
- **条件7突合の対象外リストへ `slides[].sides[].tone` を追加**（5つへ）。理由: tone は
  見た目の色分け指示子（スキーマのdescriptionが明記）で本文ではなく、値そのもの
  （pro/con/neutral）は日本語注記へ写像され `<a:t>` に現れないため。`slides[].type` と
  同じ扱い。
- **SKILL.md**: 必須キー表・型別表現表を確定スキーマの語彙（columns/sides/nodes等）へ
  書き換える。突合手順の参照先（specのパス）は変更なし。
- **単体テスト**: サンプルJSONをスキーマ適合形へ書き換え（8種type・cover の title 省略・
  section.chapter・tone・takeaway・note を含める）。境界値テストを新語彙へ追従
  （空 columns・sides 1件・nodes 1件・rows 要素が配列でない等）。検証スクリプトの
  条件7対象外へ tone を追加。**サンプルが確定スキーマに適合することを、pythonの
  jsonschema が使えれば機械検証し、使えなければ目視で確認して結果レポートへ方法を明記する。**
  不揃いな表・jq途中失敗・制御文字等の既存テストは維持する。

### 2.【設計反映】spec `.claude/docs/spec/pptx-slides.md`（新規）

構成: 背景・目的／仕様／影響範囲／設定項目／未決定事項・懸念点（`docs-workflow.md` の型）。
内容: 入力仕様（確定スキーマとの対応表。要素の型検証を含む）／type別写像（8種）／
rId採番規則・連動5箇所／zip経路試行（能力ベース検出・2段階のエラー方針）／
自己検証の範囲（zip整合性＋必須パーツ＋python検出時のwell-formed）／jq終了コードの検知
（一時ファイル経由の理由）／制御文字の空白化／表の列数決定（全行の最大・不足は空埋め）／
**条件7突合の手順（対象外5つ: `meta.title`・`meta.issue`・`speakerNotes`・`slides[].type`・
`slides[].sides[].tone`）**／PowerPoint製雛形への差し替え前処理条件（調査レポートQ4の記録）／
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
  （assets/scripts の実例として）。**main側は同じ節へ `html-slides` を追記済みのため、
  flow-id 5-1 の main 取り込みで同じ箇所のコンフリクトが起きうる。解消時は両方の行を
  残す**（この注意を worklog にも残す）。
- `.claude/rules/shell-script-style.md`: **bash 5.2 `patsub_replacement` の罠**
  （パラメータ展開の置換文字列中の `&` がマッチ全体へ展開される。sedと同じ罠が
  bash 5.2以降の既定ONで存在し、`shopt -u patsub_replacement 2>/dev/null || true` で
  無効化する）を「パラメータ展開の既定値」節の近くへ追記する。実測の根拠は結果レポート。
- `.claude/VERSION`: layer=core の配布対象アセット追加のため MINOR 増分が要る。
  **ただし当ブランチの値は 0.4.0（分岐時点）で main は 0.5.0 のため、今書き換えると
  必ずコンフリクトする。flow-id 5-1 で main を取り込んだ後に 0.5.0→0.6.0 へ増分する**
  （このフェーズでは触らない。判断の記録だけ残す）。

## やらないこと（スコープ外）

- main の取り込み（flow-id 5-1。承認が必要なため）と `.claude/VERSION` の増分（同上）。
- `.gemini/` への変換同期（flow-id 5-3）。
- speakerNotes（notesSlide）出力・`tableStyles.xml` 同梱（実機確認の結果待ち。
  結果レポートの残課題）。
- html-slides スキル側（PR #194 成果物）の変更。

## 検証（この作業自体の完了条件）

- 全 `.sh` が `bash -n` を通り、`bash .claude/scripts/test/test_json_to_pptx.sh` が
  `failures=0`（スキーマ適合サンプルでの機械検証12項目・両zip経路を含む）。
- スキーマ適合の確認: サンプルJSONが `origin/main` のスキーマに適合すること
  （jsonschema が使えれば機械検証、不可なら目視。方法を結果レポートへ明記）。
- 既存機構への影響確認（フェーズ3と同じ3コマンドを名指しで固定）: `.claude/scripts/test/`
  全件・`bash .claude/scripts/src/check-dist-coverage.sh`・
  `bash .claude/scripts/src/extract-frontmatter.sh .`。
- `bash .claude/scripts/src/generate-ddr-list.sh` の差分がREADMEのDDR一覧の1行追加のみで
  あること。`bash .claude/scripts/src/check-doc-references.sh` で参照切れ0。
- 結果は `wip/reports/2026-08-24_json-to-pptx-export-plan_反映.md`（+同名.html）へ記録する
  （本計画へは書かない）。
