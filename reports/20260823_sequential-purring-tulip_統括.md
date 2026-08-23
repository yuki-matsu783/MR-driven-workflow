---
title: issue #171 統括レポート
type: report
description: .gitignoreのDDR参照切れ2箇所の修正と、同種の参照切れを機械的に検出する仕組み（check-doc-references.sh）の追加についての、ブランチ全体の統括レポート
tags: [gitignore, ddr, doc-references, issue-171, 統括]
keywords: [DDR識別子, ゼロ埋め, 参照切れ, gitignore, 検出スクリプト, ロケール依存, 敵対的レビュー, mainマージ]
---

# issue #171 統括レポート

## 何を変えたか

- **`.gitignore`のDDR参照切れ2箇所を修正した**（28行目`i00-13`→`i0000-13`、40行目`i36-01`→
  `i0036-01`）。ただし本ブランチの作業完了後、flow-id 5-1でdefaultブランチ（main）を
  マージした際、main側の独立した意思決定（DDR i0070-01: `.gemini/`配下をGit管理下へ置く
  方針変更）により、`.gitignore`の`.gemini/`関連コメント自体が全面削除されていた。
  そのため**28行目（`i0000-13`）の修正は、マージの結果として構造ごと不要になった**（実害は
  無い。参照先ごと消えたため参照切れも起きない）。**40行目（`i0036-01`）の修正は生き残り、
  マージ後の`.gitignore`に残る唯一の本issue由来の差分**である
  （`diff <(git show origin/main:.gitignore) .gitignore`で確認済み）。
- **DDRファイルパス形式の参照切れを検出する新規スクリプト
  `.claude/scripts/src/check-doc-references.sh`を追加した。** `.md`/`.sh`/`.gitignore`を
  対象に、`.claude/docs/ddr/i<issue番号>-<枝番>-...\.md`形式の候補文字列をgrep一括抽出し、
  コードフェンス内・省略記法（`...`/`…`）を含む候補・特定の除外ディレクトリ
  （`.claude/scripts/test/` `.gemini/scripts/test/` `plans/` `reports/` `worklog/`）配下を
  除いたうえで実在確認する。単体テスト`.claude/scripts/test/test_check_doc_references.sh`
  （純粋関数6つの単体テスト＋使い捨てgitリポジトリでの統合テスト、計49ケース）を付けた。
- **新規DDR
  `.claude/docs/ddr/i0171-01-DDR参照切れ検出は絶対パス形式に限定しgrep一括抽出で実装する.md`**
  を作成し、対象範囲を絶対パス形式のDDR参照に限定した理由・検出方式（grep一括抽出＋3フィルタ）が
  2回の敵対的レビューを経て変遷した経緯（ロケール依存の罠を含む）・手動実行のみとする判断・
  新規spec作成の判断を記録した。
- **新規spec`.claude/docs/spec/check-doc-references.md`**を作成し、検出対象・除外フィルタ・
  連結候補の分割・終了コード・実装方式・ロケール依存の罠・実行の起点を仕様として記録した。
- **`.claude/rules/shell-script-style.md`へ2件追記した**（既存記述は変更していない）:
  POSIX/`LANG`未設定ロケールでブラケット式に多バイト文字を含めるとgrep・bashの`[[ =~ ]]`が
  マッチしなくなるロケール依存の罠、大量データの走査でbashループより`grep`一括委譲が有利な
  場合の実測。
- **`.claude/rules/docs-workflow.md`のDDR行へ、DDRファイルの改名・移動・削除後に
  `check-doc-references.sh`を実行する旨を追記した**（実行の起点が恒久ドキュメントのどこにも
  無かったという、フェーズ4作業実施への敵対的レビュー指摘への対応）。
- **mainマージ（flow-id 5-1）後、`.gemini/scripts/test/`（`sync-gemini-assets.sh`が
  `.claude/scripts/test/`から生成するミラー。本issue着手時点ではGit管理下になかった新規ディレクトリ）
  が除外ディレクトリに含まれておらず、フィクスチャの架空DDRパス19件を参照切れとして誤検知する
  問題が見つかったため、除外リストへ追加した。** あわせてspecの「検出対象」節が記述していた
  具体的な追跡ファイル件数（204件中182件）がmainマージにより陳腐化したため、数値を削除し
  「都度`git ls-files`で確認する」旨へ差し替えた。
- **flow-id 5-3として`.claude/`→`.gemini/`の変換同期（`sync-gemini-assets.sh`）を実行した。**
  上記の`.claude/`側の変更（DDR・spec・rules・スクリプト・単体テスト）が`.gemini/`側へも
  ミラーされている。

## なぜそうしたか

- **検出対象をDDRファイルパス形式の**絶対パス**参照に限定した**（相対パス表記・裸の識別子
  表記は対象外）。理由は、これらが実測でも本issueの主眼である`.gitignore`のような
  ファイル参照コメントの誤りを機械的に検出できる一方、裸の識別子表記はドキュメント中で
  規約説明の例示として多用され誤検知源になりやすいため。詳細はDDR `i0171-01`「理由」節。
- **検出方式は当初bash単独ループ（`[[ =~ ]]`によるファイルごとの行走査）で実装したが、
  2回の敵対的レビューを経てgrep一括抽出方式へ変更した。** 理由は主に2点: (1) 実行速度
  （リポジトリ全体走査で5.2秒→0.96秒に短縮）、(2) レビューで提案された「全角句読点を
  終端文字集合へ追加する」対処をそのまま実装したところ、この実行環境
  （`LANG`未設定・POSIXロケール）ではPOSIX ERE のブラケット式に多バイト文字を含めると
  grep・bashのどちらも該当行に一切マッチしなくなるという、実機再現で発見したロケール依存の
  罠により、リポジトリ全体の候補が0件に落ちる致命的な回帰を引き起こしたため。対処は
  正規表現自体には手を入れず、抽出後の候補文字列をASCII構造だけで判定する後処理
  （`split_concatenated_candidates_to_reply`）へ設計変更した。却下した案（正規表現へ多バイト
  文字を直接含める、スクリプト内で`LC_ALL=C.UTF-8`を明示的に設定する等）はDDR `i0171-01`
  「却下した案」節を参照。
- **実行タイミングは手動実行のみとし、SessionStart/PostToolUseフックへの自動組み込みは
  行わなかった。** `.claude/rules/shell-script-style.md`「外部プロセス起動のコスト」の
  規約に照らし、頻度の低い整合性チェックを毎ツール呼び出し・毎コミットで走らせる価値が
  無いと判断したため。実行の起点は「DDRファイルの改名・移動・削除を行った場合」と
  `docs-workflow.md`へ明記した。
- **新規specファイルを作成する判断へ、フェーズ3の当初判断（作らない）から転換した。**
  当初は「計画＋テストコード＋DDR」で十分という判断だったが、フェーズ4のレビューで
  「計画（`plans/`）自体もflow-id 5-5で削除されmainに残らないため、手動実行という運用手順を
  恒久的に記録する場所が無くなる」と指摘され、新規spec作成へ方針転換した。

## 検証結果

- `bash .claude/scripts/src/check-doc-references.sh`（mainマージ後・最終状態）:
  `走査ファイル数=309（除外ディレクトリ配下=49、削除済み未ステージのためスキップ=0）`
  `候補数=244（フェンス内除外=6、省略記法による除外=6）` `参照切れ数=0`（終了コード0）。
- `bash .claude/scripts/test/test_check_doc_references.sh`: `passed=49 failures=0`。
- `bash .claude/scripts/src/generate-ddr-list.sh --check`: `DDR一覧は最新です（79件）`
  （main由来の新規DDR i0026-01/i0070-01/i0070-02を含む）。
- `bash .claude/scripts/src/sync-gemini-assets.sh --check`: `.gemini/ は .claude/ と
  同期しています。`（終了コード0）。
- `bash -n`によるスクリプト構文チェック（`check-doc-references.sh`・`generate-ddr-list.sh`）:
  いずれも構文OK。
- リポジトリ全体でコンフリクトマーカー（`<<<<<<<` `=======` `>>>>>>>`）が残っていないことを
  `grep -rn`で確認済み。
- 敵対的レビューは各フェーズの計画作成時・作業実施後に計4回実施した
  （フェーズ4個別反映計画: 12件、フェーズ4作業実施: 11件。フェーズ2・3実施分と合わせ
  計画v2・v3への反映、実装のblocker級バグ2件の発見・修正を含む。詳細は各`reports/`・
  `worklog/`のmd参照。squash merge前提のためPR本体には残らないが、コミット履歴からは
  辿れる）。

## spec・DDRへの反映先

- `.claude/docs/spec/check-doc-references.md`: 検出対象・除外フィルタ・連結候補の分割・
  終了コード・実装方式・ロケール依存の罠・実行の起点を記録（新規作成）。
- `.claude/docs/ddr/i0171-01-DDR参照切れ検出は絶対パス形式に限定しgrep一括抽出で実装する.md`:
  対象範囲の限定・検出方式の変遷（ロケール依存の罠を含む）・手動実行のみとする判断・
  新規spec作成の判断・却下した案4件を記録（新規作成）。
- `.claude/rules/shell-script-style.md`: ロケール依存の正規表現マッチ罠、grep一括委譲が
  有利なケースの実測を追記（既存記述は変更なし）。
- `.claude/rules/docs-workflow.md`: DDR行へ、DDRファイルの改名・移動・削除後に
  `check-doc-references.sh`を実行する旨を追記。

## 残課題

- **相対パス表記のDDR参照（フェーズ2調査時点で約79件）の追跡issue化は見送った。**
  `issue-create`スキルの起票前重複チェック・最終確認が非対話セッションでは実施できないため、
  本セッションでは新規issueを起票していない。関連issue通知（flow-id 5-2）で候補
  （#32・#163等）を検討したが、いずれも本issueの変更が影響する3類型（前提が変わる／
  一部が解決される／記述が矛盾する）に該当しなかったため通知もスキップした。相対パス参照の
  追跡issue化自体は人間の判断に委ねる。
- **`.claude/VERSION`の増分は提案のみで、書き換えは行っていない。**
  `.claude/docs/spec/distribution-assets.md`の規約により増分の最終判断は人間が行うため。
  今回の配布対象アセット新設（`check-doc-references.sh`・`test_check_doc_references.sh`・
  `check-doc-references.md`）を踏まえ、MINOR増分（`0.2.0`→`0.3.0`系）を提案する。
- 見逃す範囲として明示的にスコープ外とした項目（変更していない）: DDR以外のドキュメント
  （spec等）への参照切れ検出、パスを伴わない裸のDDR識別子表記の参照切れ検出。詳細は
  DDR `i0171-01`「決定」節参照。
