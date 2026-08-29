---
title: 統括レポート: スライド構成案JSONから編集可能な .pptx を書き出す機能を追加する
type: report
description: issue #169 のブランチ全体（フェーズ1〜5）の統括レポート。何を変えたか・なぜそうしたか・検証結果・spec/DDRへの反映先・残課題
tags: [report, pptx, slides, summary]
keywords: [統括, pptx, OOXML, zip, スライド構成案JSON, 敵対的レビュー, issue169]
---

# 統括レポート: スライド構成案JSONから編集可能な .pptx を書き出す機能を追加する

## 1. 概要（何をしたか）

issue #169 に対応し、HTMLスライド生成（issue #168。PR #194でマージ済み）が使う「構成案JSON」を
入力として、テキスト・表が編集可能な `.pptx` ファイルを書き出すスキル `pptx-slides` を新設した。
入力検証・写像はjq、OOXML組み立てはbash＋静的雛形（展開ディレクトリ）＋zip再梱包で行い、
Python/LibreOffice等の外部ライブラリに依存しない。issue-mr-flowの5フェーズ全てを通し、各フェーズの
計画・実施のたびに敵対的レビューを実施して指摘を反映した（フェーズ2〜4で計6回・findings76件の
うち58件をPR上へ投稿・全件返信済み、未返信0）。単体テストは`test_json_to_pptx.sh`
`passed=111 failures=0`、既存機構の単体テスト23本全てと合わせて回帰なし。

## 2. 何を変えたか

- **新規スキル `.claude/skills/pptx-slides/`**:
  - `scripts/slides-to-records.jq` — 構成案JSONの検証（必須キー・型・トップレベル形状・
    XML1.0禁止文字域を含む）と、OOXML組み立て用の中間レコード（HDR/TROW/PARA/COLH/BUL等）への写像。
  - `scripts/json-to-pptx.sh` — 中間レコードを読み、雛形展開ディレクトリの `slideN.xml` 等を
    生成・zip再梱包して `.pptx` を作る。zip実行系→`python3 zipfile`の2段階フォールバックと、
    生成失敗／検証失敗を区別した自己診断メッセージを持つ。
  - `assets/pptx-template/` — 最小構成の展開済みOOXML雛形（`_rels`・`docProps`・
    `ppt/slideLayouts`・`ppt/slideMasters`・`ppt/theme`の静的パーツ）。
  - `SKILL.md` — 呼び出しタイミング・入出力・検証範囲の説明。
- **単体テスト `.claude/scripts/test/test_json_to_pptx.sh`**（新規、`passed=111 failures=0`）。
  境界値（空セル・末尾セル空文字列）・要素型検証・トップレベル非オブジェクト・スキーマ適合
  サンプルの個別アサーション等を含む。
- **spec新設 `.claude/docs/spec/pptx-slides.md`** — 入出力仕様・検証内容（検証する項目／
  スキーマより緩く検証しない項目を区別）・雛形構成・既知の制約。
- **DDR新設 `.claude/docs/ddr/i0169-01-pptx書き出しは雛形展開ディレクトリとzip再梱包で実装し外部依存を持たない.md`**
  — 却下案5件（python-pptx／LibreOffice headless／OOXML専用ライブラリ／PowerPoint COM操作／
  単一巨大テンプレートの直接バイト編集）と採用理由。
- **既存ドキュメントの更新**: `.claude/rules/shell-script-style.md`（bash 5.2の
  `patsub_replacement`罠を追記）・`.claude/rules/directory-structure.md` / `index.md`
  （skills一覧へ`pptx-slides`追記）・`.claude/docs/README.md`（spec一覧へ追記）・
  `.claude/docs/spec/distribution-assets.md`（VERSION changelogへ本issue分を記録）。
- **`.claude/VERSION`**: `0.4.0`→`0.7.0`（layer=core の配布対象アセット追加によるMINOR増分。
  詳細は下記「想定と異なった点」）。
- **`.gemini/`**: 上記`.claude/`側の変更を`sync-gemini-assets.sh`で変換同期。

## 3. なぜそうしたか（採用案・却下案）

**雛形展開ディレクトリ＋zip再梱包を採用**した理由は、この実行環境（Claude Code on the web）に
Python等の追加インストールが安定して行えるか不透明な一方、`zip`/`unzip`と`bash`は前提として
使える点にある。却下した案（python-pptx／LibreOffice headless／専用OOXMLライブラリ／PowerPoint
COM操作／単一巨大テンプレートの直接バイト編集）は、いずれも外部依存のインストール可否に
実行結果が左右されるか、実装コストに見合わない複雑さを持つ。詳細・却下理由の詳細は
DDR `i0169-01` を参照。

**入力検証をjqの必須キー検査で行い、スキーマファイル本体（`slide-outline.schema.json`）へ
実装として依存しない設計**にした理由は、issue #169着手時点でissue #168（依存元のスキーマ確定）が
未マージだったため。フェーズ4で#168マージ後の確定スキーマへ全面追従したが、この設計判断により
「フェーズ3の成果物が丸ごと作り直しになる」事態を避けられた。

## 4. 検証結果（実測。実行日 2026-08-29）

| 検証 | 結果 |
|---|---|
| `test_json_to_pptx.sh` | `passed=111 failures=0` |
| 既存単体テスト全23本（`.claude/scripts/test/test_*.sh`） | 全て `failures=0` |
| `check-dist-coverage.sh` | 545/545件（4種すべて通過） |
| `check-doc-references.sh` | 走査421ファイル・参照切れ0 |
| `extract-frontmatter.sh .` | 差分なし（キャッシュ再利用） |
| `generate-ddr-list.sh` | 変更なし（103件、生成物は最新） |
| `check-base-conflicts.sh --no-fetch` の `hasDuplicateDdrNumber` | `false`（DDR識別子重複なし） |
| コンフリクトマーカー残存（`git diff --check`） | 0件 |

## 5. 設計への反映

- 入力検証・写像・雛形組み立ての詳細仕様は `.claude/docs/spec/pptx-slides.md` に集約した。
  今後スキーマ（`slide-outline.schema.json`）が変わった場合は、同specの「検証内容」表と
  `slides-to-records.jq` の対応関係を見て追従範囲を判断する。
- 雛形展開ディレクトリ方式・zip再梱包という設計判断はDDR `i0169-01` に固定した。将来
  python-pptx等の外部ライブラリが安定して使える環境になった場合の再検討条件も同DDRに記録している。
- `.claude/rules/shell-script-style.md` へ追記した `patsub_replacement` の罠（bash 5.2以降で
  置換文字列中の `&` がマッチ全体へ展開される）は、本issueのXMLエスケープ処理で実際に踏んだ
  もので、今後同種のエスケープ処理を書く際の一般的な注意として機構全体で共有される。

## 6. 敵対的レビュー実績

各フェーズの計画・実施のたびに敵対的レビューを実施した（`adversarial-review-count.sh` の
上限どおり各フェーズ最大2回、フェーズ2〜4で計6回）。

| ラウンド | 対象 | 指摘件数 | 投稿件数 | 主な内容 |
|---|---|---|---|---|
| P2R1 | 調査計画 | 14 | 7 | 検証項目の精緻化・zip経路の再定義 |
| P2R2 | 調査結果 | 15 | 13 | zip経路実測の再検証・rId採番規則・受け入れ条件の再定義 |
| P3R1 | 作業計画 | 14 | 11 | metaの写像整合・実機確認ゲートの明記 |
| P3R2 | 実装diff | 10 | 7 | jq終了コード不検知（blocker）・列数決定ロジックの再構成 |
| P4R1 | 反映計画 | 11 | 9 | verify_pptx.pyのAttributeError・VERSION扱いの整合 |
| P4R2 | 反映diff | 12 | 11 | XML1.0禁止文字の正規化漏れ・表セル数の境界値バグ |

投稿した58件（うちblocker1・major多数・残りminor）は全てPR #199へインライン投稿し、全スレッドへ
対応内容を返信済み（未返信0）。報告のみ（インライン投稿しなかった）18件はworklogに記録し、
判断根拠を残した。フェーズ5（クローズ）は敵対的レビューの対象外とした（コンフリクト解消・
gemini変換同期はいずれも既定の手順に従う機械的な作業であり、設計判断を伴わないため）。

## 7. 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| `.claude/VERSION` はmain取り込み直後（flow-id 5-1）に `0.5.0`→`0.6.0` を適用する想定だった | main取り込み時点で main は他issue（#185・#145等）の増分により既に `0.6.0` まで進んでいた | マージでVERSION自体はコンフリクトせず `main` 側 `0.6.0` が自動採用されたため、そこから `0.6.0`→`0.7.0` を適用した。distribution-assets.mdのchangelogにこの経緯を記録した |
| フェーズ4完了時点でDraft解除まで到達する想定は無かったが、PowerPoint実機確認が調査レポートの◆3件（雛形手組み・speakerNotes非出力・完了条件代替）への回答とセットで必要 | 本セッション終了時点でも人間からの実機確認結果・◆回答は未取得 | Draft解除（flow-id 5-6）は引き続きゲート対象として保留する（下記「残課題」） |

## 8. 残課題

- **PowerPoint実機確認の結果、および調査レポートの◆3件（雛形は手組み展開ディレクトリで
  進める／speakerNotesはフェーズ3では出力しない／OOXMLフルパーサでの開封という完了条件未達は
  PowerPoint実機確認で代替する）への人間の回答が未取得。** Draft解除（flow-id 5-6）前に
  必須の前提として残っている。
  - 実機確認の結果、生成された `.pptx` がPowerPointで正しく開けない、または回答が仮決めと
    異なる場合は、フェーズ3・4の成果物へ遡って修正が必要になる可能性がある。
- issue #168 側で今後スキーマにフィールドが追加された場合、`slides-to-records.jq` の追従が
  改めて必要になる（フェーズ2で最小化した依存範囲を再確認する）。
