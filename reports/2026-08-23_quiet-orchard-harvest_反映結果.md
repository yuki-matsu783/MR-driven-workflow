---
title: '反映結果: 収穫スキルの正史反映とエラー方針の規約訂正'
type: report
description: issue #27 フェーズ4の反映実施結果（spec/DDR/usecase新規・README・directory-structure・SKILL.md・VERSION増分・shell-script-styleエラー方針訂正）と検証記録
tags: [report, harvest, phase4]
keywords: [設計反映, AIアセット反映, harvest-from-projects, i0027-01, i0027-02, usecase, VERSION, errexit, inherit_errexit, generate-ddr-list]
---

# 反映結果: 収穫スキルの正史反映とエラー方針の規約訂正 — issue #27

個別反映計画 `plans/【設計反映】収穫スキルの正史反映.md`・
`plans/【AIアセット反映】エラー方針の規約訂正.md`（いずれも敵対的レビュー5回目の指摘15件を
反映済みの版）に基づく flow-id 4-6 の実施結果。

## 作成・変更したファイル

| ファイル | 操作 | 内容 |
|---|---|---|
| `.claude/docs/spec/harvest-from-projects.md` | 新規 | 収穫スキルの分析スクリプトの正史仕様（scanスキーマ・分類規則・conflict判定・縮退モード・merge3終了コード5値・読み取り専用の保証・git起動一括化・エラー隔離）。影響範囲に core 層包含の判断と changelog（VERSION 適用記録）を含む |
| `.claude/docs/ddr/i0027-01-収穫スキルは読み取り専用分析とissue起票までを出口にする.md` | 新規 | 出口レベル・読み取り専用・除外の正1本化・フェイルクローズ・removedUpstream 別枠の決定と却下案4つ |
| `.claude/docs/ddr/i0027-02-エラー隔離は条件文脈の外のサブシェルでset-eを掛け直して行う.md` | 新規 | errexit の2機構（条件文脈の一時停止のサブシェル内側への伝播／コマンド置換の inherit_errexit 既定オフ）の実測・再現コマンド・採用2形・却下案3つ |
| `.claude/docs/usecase/配布先の改善を本家へ収穫する.md` | 新規 | issue #170 の4見出し構成。手順詳細は書かず SKILL.md・spec へのリンクで参照 |
| `.claude/docs/README.md` | 変更 | DDR一覧の再生成（85→87件）＋ spec 節へ1行＋ usecase 節へ1行（手書き） |
| `.claude/rules/directory-structure.md` | 変更 | `.claude/scripts/test/` の対象を「`.claude/scripts/src/` および `.claude/skills/*/scripts/` 配下スクリプトの単体テスト」へ拡張（3箇所: ツリーのコメント・配置の指針・otel 例外段落。最小差分） |
| `.claude/skills/harvest-from-projects/SKILL.md` | 変更 | 「制約」節の予告文（未来形）を新設 spec への実リンクへ差し替え |
| `.claude/VERSION` | 変更 | `0.3.0` → `0.4.0`（MINOR。非対話適用。記録は spec changelog と HANDOFF の両方） |
| `.claude/rules/shell-script-style.md` | 変更 | 「エラー方針」の理由付けを2機構へ書き分け・推奨パターンを2形（出力を捨てる形／受け取る形）へ差し替え・従来パターンの制約明記・「テスト」節の `"$(func; echo $?)"` の理由付け訂正（結論は維持） |
| `HANDOFF.md` | 変更 | 「判断を迷った内容」へ VERSION 適用の事実と根拠を追記。ヘッダの「現在のループ」を 4-6〜4-9 の1周目へ |

### 敵対的レビュー6回目（フェーズ4・対象=反映一式）の反映で追加した変更

| ファイル | 操作 | 内容 |
|---|---|---|
| `.claude/skills/harvest-from-projects/scripts/harvest-from-projects.sh` | 変更 | merge3 の層判定フェイルクローズの穴を修正——manifest は読めるが当該パスの記録が無く dist-layers.json でも解決できない場合、従来は層未確定のまま 3-way が走り exit 0 を返していた。層が確定しなければ exit 3 で止める形へ |
| `.claude/scripts/test/test_harvest_from_projects.sh` | 変更 | 上記を固定する T21b を追加（89→91 アサーション） |
| `.claude/docs/spec/shell-scripts.md` | 変更 | 「設計方針」の try/catch 節に残っていた旧前提（フォークされた側では set -e が正しく機能する）を2機構の書き分けへ訂正し、規約・DDR へのリンクに寄せた |
| `.claude/REVIEW-POINTS.md` | 変更 | 「スクリプトの作法」の観点を、旧パターンを合格にする記述から「フォークされる側の内側で set -e を掛け直しているか」へ書き換え |
| `.claude/docs/spec/harvest-from-projects.md` | 変更 | 縮退条件へ dist-layers.json 不読を追加・スキーマ表の条件付きキー明記・removedUpstream と upstreamDeleted の情報源分離・conflict 判定の dist-layers 除外・git 起動の cat-file/ls-files 追記・`--upstream`/`-h` の記載・フェイルクローズの境界明記 |
| `.claude/skills/harvest-from-projects/SKILL.md` | 変更 | スキーマ・終了コードの重複を spec へのリンクへ置き換え（正を1箇所へ）。縮退条件・フェイルクローズの説明を spec・実装と同じ粒度へ |

## 実施の要点

- **spec の影響範囲**には、スキル本体が exclude 層である一方、spec/DDR/usecase/README/rules の
  変更分は `.claude` の core エントリに包含されすべて配布対象になること、exclude スキルの
  spec/DDR を core で配ることを許容する明示判断を記載した。
- **`i0027-02`** は、実測（bash 5.2.21）の再現コマンド3つを本文に持ち、
  「明示サブシェルは `-e` を継承するが条件文脈で一時停止が内側へ伝播する」（機構1）と
  「コマンド置換は `inherit_errexit` 既定オフのため条件文脈に関係なく継承しない」（機構2）を
  分けて記録した。却下案は `shopt -s inherit_errexit` 常時オン（bash 4.4 未満不可・副作用が
  広い・機構1に効かない）・`set -E`＋`trap ERR`・個別検査の3つ。
- **shell-script-style.md の訂正**は、`"$(func; echo $?)"` を使わないという「テスト」節の
  結論を維持したまま理由付けだけを差し替えた。旧前提の残存確認は、当初「同一ファイル内・
  単語1つの grep」で済ませており、**リポジトリ横断では2箇所（`spec/shell-scripts.md` の
  設計方針節・`.claude/REVIEW-POINTS.md` のスクリプト作法）が残っていた**（敵対的レビュー
  6回目の指摘）。両方を2機構の書き分けへ訂正したうえで、検証を「旧前提の語
  （`フォークされた側では`・`コマンド置換または明示サブシェル`等）のリポジトリ横断 grep ＋
  全ヒットの仕分け」へ改めた（下記「検証の記録」8）。
- 新規正史ドキュメントでは、ベースブランチ（main）側で再配置済みのタスク単位ディレクトリの
  具体名への言及を避けた（計画の前提「ベースブランチの遅れ」の制約(1)）。

## 検証の記録

計画の「検証」節のコマンドの実行結果（Claude Code on the web の Linux 環境／2026-08-23）。

1. **frontmatter インデックス問い合わせ**（合格）: `extract-frontmatter.sh .` 実行後、
   spec / DDR 2本 / usecase の4件すべて `jq -e` が `true`（終了コード0）。
2. **DDR一覧の冪等性**（合格）: 生成→ステージ→再生成で
   `git diff --exit-code -- .claude/docs/README.md` が 0（87件。再実行しても差分なし）。
3. **DDR識別子の重複なし**（合格）: `check-base-conflicts.sh | jq -e
   '.hasDuplicateDdrNumber == false and (.duplicateDdrNumbers | length == 0)'` が `true`。
4. **層分け網羅性**（合格）: 新規4ファイルをパス列挙で `git add` 後、
   `check-dist-coverage.sh` が「検査1 472/472・検査2 9/9・検査3 0件・検査4 不正0件・OK」。
5. **README の行**（合格）: `harvest-from-projects.md`・`配布先の改善を本家へ収穫する.md` の
   grep が各1以上。
6. **errexit 5ケースの再実測**（合格。訂正後の規約本文と全ケース一致）:
   (1) `( f ) || rc=$?` → `REACHED`・rc=0／(2) 条件文脈外の `( f )` → 無出力・exit=1／
   (3) `out="$(f)"` → `R2`・`after`・exit=0／(4) `set +e; ( set -e; f ); rc=$?` → rc=1／
   (5) `set +e; out="$(set -e; f)"; rc=$?` → rc=1・out 空。
7. **制御文字混入なし**（合格）: 新規・変更6ファイルの `tr -d '\037\000'` 前後のバイト数が一致。
8. **旧前提の残存ゼロ**（合格。敵対的レビュー6回目の反映で追加）: 旧前提の語
   （`フォークされた側では`・`コマンド置換または明示サブシェル`・`フォークされたサブシェルの
   内部では`）をタスク成果物・生成物を除く全 md へ grep。ヒットは `spec/shell-scripts.md` と
   DDR `i0027-02` の各1箇所のみで、いずれも**旧主張を引用して否定する訂正済みの文**。規範
   （合格基準・推奨）として旧前提を述べる記述は 0 件。`引き継ぐ`/`継承` の他のヒット
   （issue-mr-workflow.md 等）は作業引き継ぎ・トークン集計等の無関係な用法であることを
   目視で仕分けた。
9. **単体テスト再実行**（合格）: `test_harvest_from_projects.sh` が T21b 込みで
   `passed=91 failures=0`。

## 確かめられなかったこと

- ベースブランチ（main）取り込み後の整合（behind 2。取り込みはユーザー承認待ちのため
  flow-id 5-1 で扱う。directory-structure.md の変更は最小差分に留めており、マージ解消時に
  再適用しやすい形にしてある）。
- VERSION 増分（0.4.0）の人間による追認（非対話適用。否認されたら元へ戻す）。
