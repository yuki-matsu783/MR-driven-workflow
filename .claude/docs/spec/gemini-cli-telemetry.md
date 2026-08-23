---
title: Gemini CLI公式テレメトリ機構
type: spec
description: Gemini CLI公式のOpenTelemetryテレメトリ（outfileへの直接ファイル書き出し）をusage/配下でバイトオフセットカーソル集計し、対応工数レポートへ参考値として統合する機構の仕様
tags: [gemini-cli, telemetry, usage, otel]
keywords: [outfile, byteOffset, prefixFingerprint, semantic conventions, gen_ai, 二重計上, sync-gemini-assets, UsageTracking, post-push-usage-report]
---

# Gemini CLI公式テレメトリ機構

## 背景・目的

issue #97 で、Gemini CLIの**セッションログ**（`~/.gemini/tmp/<hash>/chats/*.jsonl`）を対応工数
レポートの集計対象に加えた（`_usage_gemini_fold`系、DDR i0097-01〜05）。このセッションログは
Gemini CLIの非公開・内部フォーマットであり、将来のバージョン変更で集計が壊れるリスクがある
（Claude Code側の同じ懸念はDDR
[i0000-04](../ddr/i0000-04-対応工数レポートはtranscript自前パースで実装する.md)に記録済み）。

本機構（issue #105）は、この非公開フォーマット依存に対して**Gemini CLI公式のテレメトリ経路
（OpenTelemetry。`.gemini/settings.json`の`telemetry.enabled` / `target: "local"` /
`outfile: <パス>`）を並行して確保する土台**である。**セッションログ経路（issue #97）を
置き換えるものではない**（明示的にスコープ外。両者は独立した状態ファイル・独立したレポート
セクションを持ち、二重計上しない設計を採る。下記「二重計上回避」参照）。

Claude Code側の同種の機構は
[otel-listener.md](otel-listener.md)（issue #103、`.claude/hooks/otel/`の常駐perlリスナー）が
実装済みだが、本機構とは**受信方式が根本的に異なる**。Claude Code公式のOTLPエクスポートは
ネットワーク送信（HTTP）で受信する構成を採っており（`otel-listener.md`「設定項目」の
`OTEL_EXPORTER_OTLP_ENDPOINT`等）、outfileへの直接書き出しのような経路は本リポジトリでは
確認できていない。一方Gemini CLIは`target: "local"`を指定すると**outfileへ直接ファイル
追記**する。したがって本機構には常駐プロセスが無く、`usage/`配下のoutfileをpush毎に
バイトオフセットカーソルで差分読み取りするだけで完結する。

## 仕組み

> 以下は`telemetry.enabled: true`にした場合の動作である。**現状は`enabled: false`固定
> （下記「設定項目」）のため、1〜4はいずれも起きない**（outfileは1バイトも書かれず、
> 集計・レポート反映も対象データが無いまま常に空を返す）。

1. `.gemini/settings.json`（`sync-gemini-assets.sh`が`.claude/settings.json`から変換生成する際、
   固定値ブロックとして注入する。下記「設定項目」参照）に従い、Gemini CLIが起動するたびに
   `usage/gemini-otel.log`へOTLPペイロード相当のログ・メトリクスを追記する。
2. `git push`成功時（`post-push-usage-report.sh`）、`usage/gemini-otel.log`の存在有無で
   本機構の集計を行うかを判定する（`engine`ではなくデータの有無で判定する。既存の
   「トークン列の構成はengineではなくデータで決める」設計方針（DDR i0097-03）と整合させた）。
   outfileのパスは固定文字列ではなく、`_usage_otel_resolve_outfile_to_reply`
   （`.claude/hooks/lib/UsageTracking.sh`）が`.gemini/settings.json`の`telemetry.outfile`を
   **動的に読んで**解決する（設定ファイルが無い・不正・キー未設定なら既定値
   `usage/gemini-otel.log`へフォールバック）。相対パスは**repo_root基点**で解決するが、
   **Gemini CLI側が相対`outfile`を何基点で解決するか（起動時CWDかプロジェクトルートか）は
   未確認**である（下記「未決定事項・懸念点」）。
3. `_sync_usage_state_otel`（`.claude/hooks/lib/UsageTracking.sh`）が、前回までに読み取った
   バイトオフセット以降を差分読み取りし、完全にパースできたエントリだけを畳み込んで
   `usage/state/gemini-otel/cursor.json`へ書き戻す。
4. `post-push-usage-report.sh`が、畳み込んだ値を対応工数レポートへ「### Gemini CLI公式
   テレメトリ（参考値）」という独立したセクションとして追加する。既存のトークンテーブル
   （Claude Code経路・Gemini CLIセッションログ経路）へは合算しない。投稿要否のゲートは、
   セッションログ由来の合計が0でも**`telemetry`の`calls`が1件以上あれば投稿する**よう
   拡張されている（詳細は[issue-mr-workflow.md](issue-mr-workflow.md)「対応工数レポート」節）。

## 設定項目

| キー | 値 | 注入元 |
|---|---|---|
| `telemetry.enabled` | `false`固定 | `sync-gemini-assets.sh`の`SETTINGS_JQ_FILTER` |
| `telemetry.target` | `"local"`固定 | 同上 |
| `telemetry.outfile` | `"usage/gemini-otel.log"`（`GEMINI_OTEL_OUTFILE_REL`定数） | 同上 |
| `telemetry.logPrompts` | `false`固定 | 同上 |

**`.gemini/settings.json`は`.claude/`からの変換生成物**であり（issue #70、
[sync-gemini-assets.md](sync-gemini-assets.md)）、本機構の`telemetry`ブロックは
`.claude/settings.json`側に対応するキーを持たない**固定値注入**である（変換対象ではなく、
常に同じ値を書き込む）。詳細な注入位置・変換規則との関係は
[sync-gemini-assets.md](sync-gemini-assets.md)「固定値で注入するブロック」節を参照。

- **`enabled: false`固定**: 保留の根拠は**機微情報（`tool_call`引数等）未確認の1点**に絞る
  （下記、DDR
  [i0105-02](../ddr/i0105-02-既定有効化は機微情報未確認のため保留する.md)「決定」）。
  配布先`.gitignore`の`/usage/`未整備は、フェーズ2敵対的レビューで発見された時点では
  保留根拠の1つだったが、**フェーズ3で`install-to-project.sh`へ`/usage/`除外を追加し解消済み**
  であり、現在の保留理由には含めない（DDR i0105-02の経緯として記録）。
  **現時点でこれをtrueへ切り替える手段は存在しない**（`.claude/settings.json`側に対応する
  スイッチが無く変換元を持たないため、`.gemini/settings.json`を手で書き換えても次回の
  `sync-gemini-assets.sh`実行で無言でfalseへ戻る。`--check`は自動実行されないため、この
  上書きに気づく仕組みも無い。下記「未決定事項・懸念点」）。
- **`logPrompts: false`**: プロンプト本文の記録を明示的に抑制する。ただし、これが制御するのは
  プロンプト本文のみであり、**他イベント（`tool_call`の引数等）に機微情報が残るかは未確認**
  （下記「未決定事項・懸念点」）。
- **出力先はGit管理下に置かない**: `usage/`は`.gitignore`対象（`/usage/`）。配布先でも
  `install-to-project.sh`の`ignore_rules`へ`/usage/`が追加済み（フェーズ3、issue #105）。

## 出力形式（未検証・issue本文とフェーズ2調査からの推測）

> 実機（`gemini`コマンド）がこの実行環境に存在しないため、以下は`google-gemini/gemini-cli`の
> GitHub公式ソース（mainブランチ）をWebSearch/WebFetch経由で確認した内容に基づく推測であり、
> **実データでの裏取りができていない**。詳細は下記「未決定事項・懸念点」。

- 単一ファイル・追記型。spans/logs/metricsが同一ファイルに混在する。
- 各エントリは`safeJsonStringify(data, 2) + '\n'`（インデント2のpretty-print JSON＋末尾改行1つ）
  で書かれる想定。1行1JSONのJSONL形式ではない。
- **同一イベントが常に2回emitされる**: `gemini_cli.api_response`相当のLogRecordは、レガシー
  形式（`toLogRecord`）とsemantic conventions形式（`toSemanticLogRecord`、属性キーに
  `gen_ai.`プレフィックスを持つ）の2形式で毎回emitされる（下記DDR i0105-01「二重計上回避」）。
- metricsレコードは10秒間隔で周期exportされる（集計対象から除外。下記「カーソル方式」）。

## カーソル方式（`usage/state/gemini-otel/cursor.json`）

**ブランチ・セッション非依存のグローバルなバイトオフセットカーソル**（既存の`usage/state/`直下
ではなく`usage/state/gemini-otel/`サブディレクトリに置く。直下だと`usage/state/<branch>.json`
というブランチ別状態ファイル名と同名のブランチが存在した場合に内容を壊し合う可能性があるため）。

```json
{"byteOffset": 0, "prefixFingerprint": "", "sinceLastPush": {"tokensByModel": {}, "calls": 0}}
```

- **完全なエントリの境界判定**: 行頭（列0）が`}`のみである行を1エントリの終端とみなす
  （pretty-print出力の性質上、各値のトップレベルの閉じ括弧だけが列0に来るという前提に基づく、
  **実装依存の判定**。Gemini CLI側の出力形式が変わると壊れる）。途中書き込み（末尾が完結して
  いない）分はバイトオフセットを進めず次回へ持ち越す。
- **初回集計（カーソル0）でも特別扱いしない**: outfileはローテーション無しの無制限追記のため、
  有効化前から溜まっていたデータも初回の1回で全量計上される。
- **ファイル縮小検知**: ファイルサイズが前回の`byteOffset`より小さければ、カーソルを0へ
  リセットする（DDR i0097-01の`needsReset`と同じ考え方）。
- **`prefixFingerprint`によるファイル作り直し検知**: ファイル縮小検知だけでは、outfileが
  削除・作り直しされた後に前回のオフセットを超える量が新たに書かれた場合（サイズは縮んでいない）
  を検知できない。前回読み込んだ範囲の`cksum`（チェックサム）をstateへ保存し、次回読み込み前に
  同じ範囲を取り直して突き合わせ、不一致なら先頭から再取得する。
- **書き込み前検証**: `_usage_write_otel_state`は、書き込む値がJSONとして妥当かを検証してから
  書く。不正なJSONを無検証で書き込むと、cursor.jsonが壊れた状態のまま残り、次回の読み取りが
  既定値へ自己回復してbyteOffsetが0へ戻り、同じ場所で再び壊れるという恒久的な回復不能ループに
  陥るため（`.claude/rules/shell-script-style.md`「JSON操作」が記録する事故と同型）。

## 二重計上回避

3つの独立した対策を組み合わせている（設計判断の詳細・却下案はDDR
[i0105-01](../ddr/i0105-01-二重計上回避方式はsemantic-conventions形式のみ採用しレガシー形式とmetricsを除外する.md)）。

1. **セッションログ経路（issue #97）とは別の状態ファイル・別のレポートセクション**に表示する
   （合算しない）。
2. **同一イベントの2重emitに対しては、semantic conventions形式（`gen_ai.`属性）のみを採用し、
   レガシー形式は常に無視する**ことで、構造的に重複排除する。
3. **metricsレコードは集計対象から除外する**（10秒間隔で周期exportされ、ログとは独立した
   集計単位を持つため。ログ側の`api_response`だけを対応工数の一次情報として扱う）。

## 対応工数レポートへの統合

`post-push-usage-report.sh`の`build_usage_report_body()`が第6引数`telemetry`（既定値付き。
既存の5引数呼び出しは無変更で通過する）として受け取り、「### Gemini CLI公式テレメトリ
（参考値）」という独立したセクションを出す。`telemetry.calls`が0（または`telemetry`自体が
空/`null`）の場合はセクションごと出さない。投稿要否のゲート（合計が0なら投稿しない判定）にも
`telemetry`の`calls`を含める（テレメトリしか無いpushでもレポートが出るようにするため）。

対応工数レポート機構全体の記録範囲・投稿トリガー等は
[issue-mr-workflow.md](issue-mr-workflow.md)「対応工数レポート」節を参照。

## 既知の制限

- **実機（Gemini CLI）での動作確認が未実施**。出力ファイル形式・2重emitの実データ確認・
  属性キー名（`gen_ai.request.model`・`gen_ai.usage.*`）・列0`}`境界判定方式・
  `tool_call`引数等の機微情報の有無は、いずれも実データでの裏取りができていない
  （下記「未決定事項・懸念点」）。
- 単体テストは実装と同じ仮定に基づく合成フィクスチャに対する検証であり、実データに対する
  正しさを示すものではない。
- outfileが実際に長時間・大量に追記され続けた場合の性能特性（ファイルサイズが数百MB〜GB規模に
  なった場合の`wc -c`・`tail -c`・`grep`・`cksum`の所要時間）は測っていない。
- ローテーションは実装しない（当面）。`GEMINI_TELEMETRY_OUTFILE`環境変数を使った起動ラッパーは
  将来の拡張として残す。
- `enabled: false`固定配線に対する有効化手段の確立はスコープ外（DDR i0105-02）。
- **attributesがOTLP標準の配列形式（`[{key,value}]`）だった場合、1件も採用されず無言で
  ゼロ計上になる**（`is_semantic_api_response`は`attributes`が`type == "object"`であることを
  要求する。実データが配列形式だった場合、全エントリがフィルタで落ち`calls: 0`となり
  レポートのセクションごと出ない）。**このときbyteOffsetは読み取り済みとして進むため、
  後から属性形式が判明しても遡って計上できない。** エラー・警告も出ないため、利用者からは
  「テレメトリが動いていない」としか見えない。実機データ入手時に最初に確認すべき項目。

## 影響範囲

### 新規追加

- `.claude/docs/spec/gemini-cli-telemetry.md`（本ファイル）
- `.claude/docs/ddr/i0105-01-二重計上回避方式はsemantic-conventions形式のみ採用しレガシー形式とmetricsを除外する.md`
- `.claude/docs/ddr/i0105-02-既定有効化は機微情報未確認のため保留する.md`
- `usage/gemini-otel.log`（実行時生成、`.gitignore`対象）
- `usage/state/gemini-otel/cursor.json`（実行時生成、`.gitignore`対象）

### 変更

- `.claude/scripts/src/sync-gemini-assets.sh`（`SETTINGS_JQ_FILTER`への`telemetry`ブロック注入、
  `GEMINI_OTEL_OUTFILE_REL`定数）
- `.claude/hooks/lib/UsageTracking.sh`（`_usage_otel_*`系関数群、`_sync_usage_state_otel`、
  `_usage_reset_otel_since_last_push`）
- `.claude/hooks/post-push-usage-report.sh`（`build_usage_report_body()`第6引数、投稿要否ゲート）
- `.claude/skills/apply-mr-workflow-to-project/scripts/install-to-project.sh`（`ignore_rules`へ
  `/usage/`追加）
- `.claude/scripts/test/test_usage_tracking.sh`（本機構のテストケース追加）
- `.claude/scripts/test/test_install_to_project.sh`（`/usage/`除外の固定テスト追加）
- `.claude/scripts/test/fixtures/sync-gemini-assets/settings-expected.json`（`telemetry`ブロック
  分のゴールデンフィクスチャ更新）
- `.claude/docs/spec/sync-gemini-assets.md`（`env`行の帰結訂正、固定値注入ブロックの仕様化）
- `.claude/docs/spec/issue-mr-workflow.md`（「対応工数レポート」節への相互リンク）
- `.claude/docs/spec/distribution-assets.md`（既知の問題の記述更新）
- `.claude/rules/directory-structure.md`（`usage/`内訳一覧への追加）

### 本機構と直接の因果関係を持たないが同issue内で行った変更

- `.claude/skills/issue-mr-flow/SKILL.md`（`mcp__github__pull_request_read`の
  ページネーションパラメータ注記。issue #105の作業中に踏んだAIアセットの不備で、
  本機構の仕様自体とは関係が無い）

## 未決定事項・懸念点

- **実機での動作確認が未実施**。出力ファイル生成・形式・2重emitの実データ確認・属性キー名・
  `tool_call`引数等の機微情報の有無は、人間による実機確認に持ち越している（issue #105の
  受け入れ条件1は現時点で**未達**）。データが得られない間は、本specの記述（semantic
  conventions形式のみ採用等）を確定値として運用し、実機データ入手後に差し替える。
- **`enabled: false`固定配線に対する有効化手段の確立**（`.claude/settings.json`側にスイッチを
  設ける等）は本issueのスコープ外（DDR i0105-02の却下案として記録するのみ）。
- **バイトオフセット境界判定方式（列0の`}`）とprefixFingerprint方式（`cksum`）は、いずれも
  実装依存の判定**であり、Gemini CLI側の出力形式が変わると壊れる可能性がある。実機データが
  得られ次第、より頑健な判定方式（実際のOTLP JSON構造をパースする等）への切り替えを検討する。
- **配布先での既定有効化・オプトアウト手段**: `enabled: false`固定のため現状は該当しないが、
  将来有効化する場合は`otel-listener.md`の「未決定事項・懸念点」に記録されている同種の懸念
  （配布先でのテレメトリ既定ON・常駐プロセス既定起動を望まない場合のオプトアウト手段が未定義）
  と合わせて検討する必要がある。

## changelog

- issue #105: 新規作成。フェーズ2（調査）・フェーズ3（作業）の設計判断を反映。
  `.claude/VERSION`の増分（実装スクリプト4本——`sync-gemini-assets.sh` / `UsageTracking.sh` /
  `post-push-usage-report.sh` / `install-to-project.sh`——の変更に対しMINORを提案。
  `sync-assets.sh`は`.claude/`配下をディレクトリ単位でまとめて配布するため、実際の配布範囲は
  上記スクリプト4本に加え本specやDDR等のドキュメントも含む）は人間の判断待ち
  （据え置く場合はその事実をここへ追記する）。
