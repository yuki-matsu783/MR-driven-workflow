---
title: 実装結果レポート: pptx-slidesスキルの作成（フェーズ3）
type: report
description: issue #169 フェーズ3の作業結果。pptx-slidesスキル一式（SKILL.md・生成スクリプト・jqフィルタ・OOXML雛形）と単体テスト49件を作成し、機械検証・既存機構への影響確認まで完了した
tags: [report, implementation, pptx]
keywords: [実装結果, pptx-slides, json-to-pptx, OOXML, zip, 単体テスト, 機械検証, patsub_replacement, 実機確認依頼]
---

# 実装結果レポート: pptx-slidesスキルの作成（フェーズ3）

- issue: #169 / PR: #199 / フェーズ3 flow-id 3-6
- 実施日: 2026-08-23〜2026-08-24
- 対応する計画: `wip/plans/【実装】【テスト】pptx-slidesスキルの作成.md`
- 実施環境: Claude Code on the web（Linux）。bash 5.2系・jq 1.7・python 3.11・
  Info-ZIP zip/unzip あり
- ファイル名の日付が計画の記載（`2026-08-23_…_実装.md`）と異なるのは、実装完了が日付を
  またいだため（命名規則の「日付」＝作成日を優先した）

## 重点レビュー依頼

- ◆ **PowerPoint実機確認（受け入れ条件3・4・5の代替検証）**: この環境ではOOXMLフルパーサでの
  開封検証ができない（フェーズ2調査で実測済み）。生成した .pptx を実機のPowerPointで開き、
  (1) 修復ダイアログ・警告なしに開けること、(2) テキストボックス・表がクリックして編集できる
  こと、(3) 8種type全てのスライドが表示されること、(4) **表に罫線・1行目の強調が付いている
  こと**（表スタイルは組み込みGUIDの `tableStyleId` 参照のみで `tableStyles.xml` を同梱して
  いないため、解決されない環境では無装飾の表になりうる。敵対的レビュー2回目の指摘）の確認を
  依頼する。確認手順: `bash .claude/skills/pptx-slides/scripts/json-to-pptx.sh <構成案JSON>` で
  生成した .pptx をWindowsへコピーして開く。**この結果が返るまで flow-id 5-6（Draft解除）へ
  進まない**。
- ◆ **Windows git bash実機での実行確認**: zip不在環境でのpython経路フォールバック
  （`py -3` への候補送りを含む）はスタブでのみ検証した。実機での1回の実行確認を依頼する。
- ◇ **条件7突合の対象外リストへ `slides[].type` を追加**: 計画の対象外3つ（`meta.title`・
  `meta.issue`・`speakerNotes`）に加え、`slides[].type` も対象外にした（構造の判別子であり
  `<a:t>` に現れない。下記「想定と異なった点」1）。
- ◇ **bash 5.2 `patsub_replacement` の無効化**: パラメータ展開の置換にもsedと同種の
  `&` 再解釈があることが実測で判明し、スクリプト冒頭で `shopt -u patsub_replacement` を
  置いた（下記「想定と異なった点」2。単体テストが再発を固定する）。

## サマリ（結論の一覧）

1. **◎ スキル一式を作成し、8種type全部入りサンプルからの生成が両zip経路で機械検証に全合格**。
   単体テスト `passed=70 failures=0`（敵対的レビュー2回目の指摘反映後の値。反映前は49件）。
2. **◎ 既存機構への影響なし**: 分岐点時点の既存テスト21本を含む22本全件 `failures=0`・
   `check-dist-coverage.sh` 4種通過（498/498件）・`extract-frontmatter.sh .` エラーなし
   （新規SKILL.mdはインデックスへ載る）。
3. **✕→◎ 実装中に実バグ3件を検出し修正**: bash 5.2の `patsub_replacement` によるXML
   エスケープ破壊／HDRレコードの値内改行での行分割／（テスト側）PATH制限時の `bash` 探索。
   いずれも単体テストで再発を固定した。
4. **✕→◎ 敵対的レビュー（フェーズ3の2回目・対象=実装diff）の指摘10件を修正**: 最重要は
   blocker「jqの途中失敗を検知せず、内容の欠けた .pptx を成功として出力する」。ほかに
   制御文字入力での不正XML・表の列数の先頭行依存（ゼロ除算）・超過セルの無言切り捨て等
   （詳細は章6）。
5. **△ 受け入れ条件3・4・5（PowerPointでの編集可能性）は実機未検証**のまま（計画どおり
   実機確認をレビュー依頼へ切り出し。上記◆）。

## 確かめられなかったこと

- PowerPoint実機での開封・編集（この環境に実機・フルパーサが無い。機械検証はzip整合性・
  XML well-formed・パーツ突合・葉テキスト突合まで）。
- Windows git bash実機での実行（`py -3` 候補・MSYSのパス変換・fork単価）。
- LibreOffice等による相互運用検証（フェーズ2調査でこの環境では使用不能と判明済み）。

## 実施した内容と結果

### 1. 成果物

| パス | 内容 |
|---|---|
| `.claude/skills/pptx-slides/SKILL.md` | スキル定義（実行方法・必須キー・型別表現・speakerNotes非出力の明記・実機確認依頼の注意） |
| `.claude/skills/pptx-slides/scripts/json-to-pptx.sh` | 生成スクリプト本体（約450行。入力検証→雛形コピー→slideN.xml生成→連動5箇所→zip梱包経路試行→自己検証） |
| `.claude/skills/pptx-slides/scripts/slides-to-records.jq` | 構成案JSON→レコードストリーム変換（入力検証を含む、実行あたり1回だけのjq呼び出し） |
| `.claude/skills/pptx-slides/assets/pptx-template/` | 静的OOXMLパーツ7ファイル（`_rels/.rels`・`docProps/core.xml`（プレースホルダ）・slideMaster+rels・slideLayout+rels・theme） |
| `.claude/scripts/test/test_json_to_pptx.sh` | 単体テスト（アサーション70件） |

設計は計画どおり: `[Content_Types].xml`・`presentation.xml`・`presentation.xml.rels`・
`app.xml`・`ppt/slides/**` はスクリプトが丸ごと所有し、rIdはrId1=slideMaster/rId2=theme予約・
スライドはrId3から、sldId idは256から連番。XMLエスケープはbashの純粋関数
`xml_escape_to_reply`（5種）が唯一の実装。テキスト値内の改行は段落分割で表現。
プレースホルダ置換はパラメータ展開（sed/awk不使用）。一時ディレクトリは
`mktemp -d`＋`trap EXIT` で正常・異常とも残さない。

### 2. 単体テストの結果（生の出力。2026-08-24、敵対的レビュー2回目の指摘反映後に再実行）

```
$ bash .claude/scripts/test/test_json_to_pptx.sh
passed=70 failures=0
```

内訳（要点）:

- 純粋関数: `xml_escape_to_reply`（5種の特殊文字・日本語・`&` の一回置換）、
  `resolve_out_path_to_reply`（`.slides.json` 両落とし・ディレクトリ無し・拡張子なし・絶対パス）。
- 正常系（機械検証）: 8種type全部入り・8枚のサンプルから生成し、python検証スクリプトで
  12項目を検査（zip整合性 testzip・先頭エントリ`[Content_Types].xml`＋ディレクトリエントリ
  0件・全XMLパーツ well-formed・必須パーツ実在・Content_Types突合・rels整合（全Target実在）・
  rId重複0・sldIdLst整合・table/comparisonの `a:tbl` 存在・条件7の葉テキスト突合・
  core.xmlプロパティ・app.xml枚数）。`unzip -t` も別途通過。
- 経路: zip経路とpython経路（`zip` をPATHから隠す）の両方で生成し、経路間突合
  （エントリ集合一致＋先頭固定＋ディレクトリエントリ0件。順序全体は比較しない）に合格。
  「`zip` はあるが失敗する」スタブでpython経路へフォールバック、「存在するが実行できない
  `python3`」スタブで `python` への候補送り（能力ベース検出の採用理由そのものの検証）、
  全候補失敗・全経路不在での明示エラー、失敗時に出力ファイル・一時ディレクトリを残さない
  こと（TMPDIR制御）を確認。
- 異常系: 不正JSON（パス入り明示エラー）・type不正（8種enum）・スライドtitle欠落・
  meta.title欠落・空slides・入力ファイル無し・出力先がディレクトリ・親ディレクトリ不在。
- 異常系（要素の型・境界値。敵対的レビュー2回目で追加）: 空 `headers`・空 `options`・
  `rows[0]` が配列でない・`options[0]`／`edges[0]` がオブジェクトでない・全セル空の表
  （いずれもキー名を挙げた明示エラー）。jqが途中で失敗する経路（stub jq）で非0終了し
  出力を残さないこと。制御文字（0x01）入り入力が空白へ置換されwell-formedのまま生成される
  こと。不揃いな表（超過セル・不足セル）で列数が全行の最大になり超過セルが捨てられないこと。
- 警告: speakerNotes入り入力で標準エラーへ件数付き警告（`2 件`）・終了コードは0のまま・
  生成自体は行われる。
- docProps: 改行・特殊文字入り `meta.title` が `dc:title` へ1行に潰れてエスケープ経由で
  入る（下記バグ修正3の再発固定）。

### 3. 既存機構への影響確認（計画で名指しのコマンド3種・生の要約）

本数の根拠: 分岐点（origin/main）時点の既存テストは
`git ls-tree origin/main --name-only .claude/scripts/test/ | grep -c 'test_.*\.sh$'` = **21本**、
現在は新規1本を含め `ls .claude/scripts/test/test_*.sh | wc -l` = **22本**。
以下は敵対的レビュー2回目の指摘反映後（2026-08-24）に再実行した生の出力。

```
$ for t in .claude/scripts/test/test_*.sh; do bash "$t"; done   # 22本全件（rc=0）
test_adversarial_review_count.sh: passed=22 failures=0
test_block_direct_git_commit.sh: passed=27 failures=0
test_check_base_conflicts.sh: passed=31 failures=0
test_check_base_sync.sh: passed=55 failures=0
test_check_dist_coverage.sh: passed=29 failures=0
test_check_doc_references.sh: passed=49 failures=0
test_cleanup_task.sh: passed=79 failures=0
test_collect_review_points.sh: passed=27 failures=0
test_command_position.sh: passed=118 failures=0
test_extract_frontmatter.sh: passed=32 failures=0
test_generate_ddr_list.sh: passed=52 failures=0
test_harvest_from_projects.sh: passed=91 failures=0
test_install_to_project.sh: passed=100 failures=0
test_json_to_pptx.sh: passed=70 failures=0   ← 新規
test_post_issue_create_notice.sh: passed=38 failures=0
test_search_frontmatter.sh: passed=114 failures=0
test_select_adversarial_findings.sh: passed=34 failures=0
test_session_start.sh: passed=74 failures=0
test_sync_gemini_assets.sh: passed=91 failures=0
test_update_handoff_progress.sh: passed=118 failures=0
test_usage_tracking.sh: passed=120 failures=0
test_vcs_provider.sh: passed=225 failures=0

$ bash .claude/scripts/src/check-dist-coverage.sh
検査1 追跡ファイルの分類: 498 / 498 件   # 今回追加の .claude/skills/pptx-slides/** を含めて被覆
検査2 .gitignore の行の被覆: 10 / 10 行
検査3 空振りエントリ: 0 件（うち pathspec として不正 0 件）
検査4 layer / strategy の妥当性: 不正 0 件
結果: OK（4種すべて通過）

$ bash .claude/scripts/src/extract-frontmatter.sh .
files=178 built=4 reused=174 failed=0 skipped=0   # エラーなし。pptx-slides/SKILL.md は
                                                  # .claude/skills/pptx-slides/index.jsonl に載る
```

### 6. 敵対的レビュー（フェーズ3の2回目・対象=実装diff）の指摘と修正

指摘10件（blocker1・major3・minor6）。7件をPR #199へインライン投稿し、3件は報告のみ
（worklog push6参照）。全件を以下のとおり修正した。

| 指摘 | 修正 |
|---|---|
| **blocker**: プロセス置換のためjqの途中失敗が伝わらず、内容の欠けた .pptx を「成功」として出力 | レコードを一時ファイルへ落としてから読む形へ変更し、jqの終了コードを検知して明示エラー・非0終了。stub jqで再発を固定 |
| **major**: 制御文字（0x01等）が `<a:t>` へ入り、不正XMLの .pptx が rc=0 で出る | jqの `clean` でXML 1.0が許さないC0制御文字（TAB/LF/CR以外）を空白へ置換。自己検証にもwell-formed検査を追加（python検出時。不在時は省略を警告） |
| **major**: 表の列数が先頭行依存で、空ヘッダだとゼロ除算・comparisonで行と列数の不整合 | 列数を全行の最大セル数で決定する形へ再構成。全セル空は明示エラー。jq側検証へ `headers`/`options` 1件以上を追加 |
| **major**: ヘッダより多いセルの無言切り捨て | 同上の再構成で切り捨て自体を廃止（不足セルは空埋め、超過セルは列を広げて保持）。SKILL.mdへ挙動を明記 |
| minor: SKILL.mdの検証範囲の記述が実装と食い違う | 自己検証へwell-formed検査を実装で追加したうえで、記述を「zip整合性＋必須パーツ＋（python検出時）well-formed」へ統一 |
| minor: レポートのテスト本数（22/23本）が実測（21/22本）と不一致 | 本レポート・HTML・HANDOFF・worklogの数値を実測コマンド付きで修正 |
| minor: worklogに生の0x1F混入 | 読める表記（バックスラッシュ＋u001f）へ書き換え、バイト数比較で0件を確認 |
| 報告のみ: 貼付出力（`files=176`・`484/484`）が現在のツリーで再現しない | コミット後のツリーで再実行した値へ差し替え、実行日を明記 |
| 報告のみ: HANDOFF進捗表で 3-2 が `[]` のまま 3-5 が `[x]` | 実施済みの 2-2・3-2 を `[x]` へ。人間レビュー待ちのループ範囲（2-3〜2-4等）を `[]` のまま残す理由を「判断を迷った内容」へ明記 |
| 報告のみ: `tableStyleId` のGUID参照だが `tableStyles.xml` が無い（確度low・実機でしか検証不能） | 実機確認依頼へ「(4) 表に罫線・1行目強調が付くこと」を追加（上記◆）。無装飾だった場合は `tableStyles.xml` の同梱を後続で行う |

- **jq検証の強化に伴う入力仕様の明確化**: `rows[]` の各要素は配列・`options[]`／`edges[]` の
  各要素はオブジェクト・`headers`／`options` は1件以上、をjq側で検査し明示エラーにする
  （SKILL.mdの必須キー節にも追記済み）。
- 修正後の再実行結果が本レポートの章2・章3の値（`passed=70 failures=0` 等）である。

## 設計への反映（フェーズ4への引き継ぎ）

- spec `.claude/docs/spec/pptx-slides.md`（新規）: 入力仕様（必須キー表。要素の型・1件以上の
  検証を含む）・type別写像・表の列数決定（全行の最大・不足は空埋め）・rId採番規則・連動5箇所・
  zip経路試行・**jq終了コードの検知（一時ファイル経由）と制御文字の空白化**・自己検証の範囲
  （zip整合性＋必須パーツ＋python検出時のwell-formed）・**条件7突合の手順（対象外=
  `meta.title`・`meta.issue`・`speakerNotes`・`slides[].type` の4つ）**・PowerPoint製雛形への
  差し替え前処理条件・**bash 5.2 `patsub_replacement` の罠と `shopt -u` の根拠**。
  SKILL.md はこのspecを参照済み（フェーズ4で実体を作るまでリンク先が無い状態。
  フェーズ4の個別反映計画へ明記済み）。
- DDR: 却下案（クリップボード経由・python-pptx・XMLゼロから生成・バイナリ雛形・
  Compress-Archive）の記録（原文は調査レポート「設計への反映」）。
- `.claude/rules/directory-structure.md` のツリーへ `pptx-slides` を追記、
  `.claude/rules/shell-script-style.md` へ `patsub_replacement` の注意を追記するか検討。
- `.gemini/` への変換同期はフェーズ5（flow-id 5-3）。

## 想定と異なった点

1. **条件7突合の対象外リストが3つ→4つになった**: 計画は `meta.title`・`meta.issue`・
   `speakerNotes` の3つとしたが、テスト実装時に `slides[].type` のenum値（`"cover"` 等）も
   入力JSONの葉文字列でありながら `<a:t>` に現れない（構造の判別子で本文ではない）ことが
   判明し、対象外へ追加した。突合の実装は「対象外を除く全葉テキスト値の行単位部分一致」で
   計画どおり。
2. **bash 5.2 の `patsub_replacement` がXMLエスケープを破壊していた**: 計画は「`sed`/`awk` の
   `&` 再解釈の罠を避けるためパラメータ展開で置換する」としたが、bash 5.2以降は
   **パラメータ展開の置換文字列にも同じ `&` 再解釈がある**（既定ON）。
   `${s//</&lt;}` が `&lt;` ではなく `<lt;` を生み（`&` がマッチ全体へ展開される）、
   エスケープ済みの値（`&amp;` 等を含む）を使うcore.xmlのプレースホルダ置換も同様に壊れる。
   最初のテスト実行が検出した（`xml_escape: 5種の特殊文字と日本語` FAIL・core.xml/slide3.xml
   の well-formed FAIL）。スクリプト冒頭の `shopt -u patsub_replacement 2>/dev/null || true`
   （5.2未満にはshopt自体が無い）で無効化し、テスト49件が全合格へ変わった。
3. **HDRレコードが値内改行で行分割される潜在バグ**: `meta.title` 等に改行が入ると、
   jqが出すHDRレコード自体が2行に割れ、2行目が未知タグとして無言で捨てられていた
   （`dc:title` が1行目だけになる）。docProps行きの値は1行の意味を持つため、jq側で改行を
   空白へ潰す正規化（`cell`）を適用して修正。テスト「改行入りmeta.title」が再発を固定する。
4. **テストのPATH制限では `bash` 自体も合成binへ要る**: `PATH=... bash "$target"` の形は
   一時代入のPATHが `bash` のコマンド探索にも使われ、127で落ちる。合成binへ `bash` の
   リンクを含めて解決（テスト側のみの話でスクリプト本体は無関係）。
5. **レポートのファイル名日付**: 計画記載の `2026-08-23_…_実装.md` に対し、実施が日付を
   またいだため `2026-08-24_…` とした（命名規則の「日付」を優先）。

## 残課題

- ◆2件（PowerPoint実機確認・Windows git bash実機確認）: PRレビューで依頼済み事項。
  結果が返るまで flow-id 5-6（Draft解除）へ進まない（`HANDOFF.md` の「守るべき条件」）。
- 実機確認で表が無装飾（罫線・1行目強調なし）だった場合は、`ppt/tableStyles.xml` の同梱と
  presentation.xml.rels への追加（rId採番規則の拡張を含む）を行う（敵対的レビュー2回目の
  指摘。確度lowのため実機確認の結果待ち）。
- PR #194（issue #168）のスキーマ具体化に伴う突合: Draft解除前に再確認する
  （必須キー検査はスキーマファイル本体へ依存しない設計のため、フィールド名変更時のみ追従）。
- speakerNotes（notesSlide）対応は後続issue（入力にあれば警告で観測可能）。
