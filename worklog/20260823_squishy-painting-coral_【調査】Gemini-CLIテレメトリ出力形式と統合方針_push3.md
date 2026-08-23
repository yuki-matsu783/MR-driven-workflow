# worklog: 【調査】Gemini CLIテレメトリ出力形式と統合方針

対象: issue #105 のフェーズ2個別調査計画作成（2026-08-23）。
全体作業計画: `plans/squishy-painting-coral.md`
個別作業計画: `plans/【調査】Gemini-CLIテレメトリ出力形式と統合方針.md`
push回数: 3（予定）

## 試したこと

- issue #105本文・コメント3件（PR #101/#137/#158マージ前通知）を取得し、既存実装（issue #97
  セッションログ集計、issue #103 Claude Code OTel）との関係を確認した。
- `.claude/docs/spec/issue-mr-workflow.md`「対応工数レポート」節・「Gemini CLI経路」小節を通読し、
  既存のGemini集計（`_usage_gemini_fold`系）の設計を把握した。
- `.claude/docs/spec/otel-listener.md`を通読し、issue #103の出力先命名・設定分離パターンを把握した。
- Explore エージェントで `UsageTracking.sh`・`post-push-usage-report.sh`・`.gemini/settings.json`・
  既存テストの構成を調査した。

## うまくいったこと

- 既存のGemini経路（セッションログ集計）と本issueが対象とする「公式テレメトリ」は入力データ
  ソースが別物であることを、事前調査の時点で切り分けられた。全体作業計画・個別調査計画の
  両方にこの区別を明記した。

## ダメだったこと

- 特になし。

## 追記（敵対的レビュー1回目・push3後）

- フェーズ2の敵対的レビューを1回実施（`adversarial-review-count.sh`のフェーズ2カウンタは1）。
  11件の指摘（major 6件・minor 5件）を得て、うち10件（major/high 4件・major/medium 2件・
  minor/high 4件）をMR #174へインラインコメントとして投稿した（1件はminor/mediumのため報告のみ）。
- 主な指摘: (1) 受け入れ条件5（`.gemini/settings.json`のTelemetrySettingsスキーマ確認）に
  対応する調査項目が無い、(2) mdの「検証手順」に実行可能なコマンドが無い、(3) md側に
  「前提（合意状況）」節が無い、(4) HTMLの「方針」がmdの7項目を圧縮しすぎている、
  (5) 出力形式未検証のままテストフィクスチャを作る前提になっている、(6) 実機検証可否の
  判定方法・代替手段が無い、(7) 受け入れ条件番号の参照誤り（二重計上は条件6ではなく2・3）、
  (8) md/htmlの見出し不一致、(9) HTMLの検証コマンドが`|| true`で常に成功する、
  (10) HTML冒頭の説明コメントが未実施。
- すべて修正: 方針を7項目→8項目へ再構成（TelemetrySettingsスキーマ確認を追加）、
  前提（合意状況）節・「issueの受け入れ条件との対応」表をmdへ追加、検証節を実行可能な
  コマンド＋合格条件へ書き換え、受け入れ条件番号を訂正、見出しをテンプレート節名へ統一。
  HTMLは方針節をmdと同じ粒度で書き直し、検証コマンドを`|| true`を外した形へ変更、
  冒頭に説明コメントを追加。report11（outfile形式の推測依存）も方針3・8の記述から
  「可能性が高い」という決め打ちを外し、両方の場合分けを明記する形で対応した。

## 追記（flow-id 2-6・調査実施）

- 実機検証可否を`command -v gemini`で確認 → 存在せず（exit=1）。実機起動での検証は不可。
- 代替として、`google-gemini/gemini-cli`のGitHub `main`ブランチ（2026-08-23時点）を
  WebSearch/WebFetchで直接確認した。主な発見:
  - `packages/core/src/telemetry/file-exporters.ts`: FileSpanExporter/FileLogExporter/
    FileMetricExporterはコンストラクタで`filePath`を受け取り追記モード（`flags:'a'`）で開く。
    シリアライズは`JSON.stringify(data,null,2)+'\n'`（pretty-print、**1行1JSONではない**）。
  - `packages/core/src/telemetry/sdk.ts`: 3エクスポータはすべて同一の`telemetryOutfile`で
    初期化される → **単一ファイルにspans/logs/metricsが混在**。
  - `packages/core/src/telemetry/loggers.ts`: `gemini_cli.api_response`はLogRecord
    （`logger.emit()`）として記録される（Spanイベントではない）。
  - `packages/cli/src/config/settingsSchema.ts`: `telemetry`はトップレベルキー
    （`general`配下ではない）。
  - GitHub検索（`/search?q=`）はレート制限（429, Retry-After: 3600）に当たったため、
    `TelemetrySettings`型の完全な定義ファイルへは到達できなかった。判断に必要な範囲
    （キー名・ネスト位置・既定値）は`docs/cli/telemetry.md`から確認済み。
- 8項目すべてに判断根拠を得られたため、`reports/20260823_squishy-painting-coral_
  Gemini-CLIテレメトリ出力形式と統合方針の調査結果.md`（＋同名html）へ記録した。
  検証コマンド（8項目それぞれの見出し件数）はすべて1以上を返すことを確認済み。

## 追記（敵対的レビュー2回目・push3後、reports/への修正）

- フェーズ2の敵対的レビューを2回目実施（`adversarial-review-count.sh`のフェーズ2カウンタは2）。
  対象は`reports/`の調査結果（md・html）。16件の指摘（major 9件・minor 7件）を得た。
- 確度・重大度の投稿基準（major×high/medium、minor×highの一部）に従い、上限10件を
  severity降順で選別してMR #174へインラインコメント投稿した（major 9件＋minor/high 1件）。
  残り6件（minor/high 3件・minor/medium 3件）はこの場で報告のみとし、レビュー本文へ列挙した。
- **投稿・報告した16件すべてに対応した**（ユーザー指示「指摘に対する修正を行いながら進める」に
  従い、投稿分だけでなく報告のみの分も含めて修正）。
  - **確認により裏取りできた重大な欠落2件**: (1) `loggers.ts`の`logApiResponse()`を再確認し、
    `toLogRecord`/`toSemanticLogRecord`が**無条件で常に2回**emitされることを確認（同一イベントの
    2重計上リスクが「未検討の懸念」から「確定した制約」に変わった）。(2) `sdk.ts`を再確認し、
    `FileMetricExporter`が`PeriodicExportingMetricReader`（`exportIntervalMillis: 10000`）で
    登録されることを確認（metricsは10秒間隔で周期exportされ、単純合算だと二重計上する）。
    → 4.（差分カーソル単位）へ「metricsを集計対象から除外し、LogRecordの2重emitを重複排除する」
    という必須要件として反映。
  - **配布先での安全性の欠陥**: 7.の「`logPrompts:false`なら既定ONで安全」という結論が、
    (a) プロンプト本文以外の機微情報の未確認、(b) 本リポジトリの`.gitignore`は配布対象では
    ないため配布先で`.gitignore`保護が効かない、という2点で成り立たないと判明。既定有効化の
    判断を「確定」から「保留」へ変更した。
  - **新発見（当初の判断を覆した）**: `docs/cli/telemetry.md`を再確認したところ、
    `GEMINI_TELEMETRY_OUTFILE`をはじめとする`GEMINI_TELEMETRY_*`環境変数群が存在し、
    「settings.jsonが静的だから動的パスを渡せない」という3.・8.の当初の判断が誤りだったと
    判明。起動ラッパーが無いため結論（固定ファイル名・ローテーション未実装）自体は変えないが、
    理由づけと将来の拡張余地を書き直した。
  - **DDR i0097-01との整合**: 5.の状態ファイルにブランチ／セッションのスコープ判断が
    無かったため、「ブランチにもセッションにも紐づかないグローバルなバイトオフセットカーソル」
    という判断を追加し、DDR i0097-01の考え方（ブランチ非依存）と整合させた。
  - **カーソル方式の耐障害性**: 途中書き込み・ファイル縮小・状態ファイル破損への対処を
    4.へ具体的に追記（DDR i0097-01の`needsReset`・`.claude/rules/shell-script-style.md`の
    自己回復ロジック要求を踏まえた）。
  - **WebFetch由来の断定表現**: 冒頭に調査手法の注記を追加し、WebFetchが要約であること・
    重要な判断は2回のWebFetchで一致を確認していることを明記。ローテーション不在の断定を
    「確認した1ファイルの範囲では」に弱めた。
  - **軽微な修正**: 受け入れ条件9項目対応表の追加（まとめの後）、`logPrompts`既定値の参照誤り
    訂正（1.→2.）、シリアライズ関数表記の統一（`safeJsonStringify`に統一）、参照ソースの
    コミットSHA・permalink追記、実機確認依頼リストの具体化（7項目）、HTML内の`**`残骸を`<b>`へ
    修正。
  - HTML版はmdの変更点をすべて反映して全面更新した（サマリ表・受け入れ条件対応表セクションの
    新設を含む）。

## 次の一歩

- flow-id 2-9〜2-10: 修正済みのreports・worklog・HANDOFF.mdをcommitしてpushする。
  レビュー依頼メッセージを送り、MR descriptionを更新する。

---
