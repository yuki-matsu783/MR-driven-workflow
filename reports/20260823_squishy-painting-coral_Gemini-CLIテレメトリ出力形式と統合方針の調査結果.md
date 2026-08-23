---
title: Gemini CLIテレメトリ出力形式と統合方針の調査結果
type: report
description: issue #105フェーズ2の調査結果。公式ソース（google-gemini/gemini-cli mainブランチ）を直接確認し、出力形式・settings.jsonスキーマ・出力先配置・差分カーソル単位・二重計上回避・logPrompts・既定有効化・ローテーションの8項目について判断根拠を記録する
tags: [gemini-cli, telemetry, usage-report, issue-105, investigation]
keywords: [OpenTelemetry, outfile, FileSpanExporter, FileLogExporter, FileMetricExporter, TelemetrySettings, logPrompts, LogRecord, バイトオフセットカーソル, 二重計上, ローテーション]
---

# Gemini CLIテレメトリ出力形式と統合方針の調査結果

対応する計画: `plans/【調査】Gemini-CLIテレメトリ出力形式と統合方針.md`（flow-id 2-6）

## 実機検証可否の判定

```bash
command -v gemini
echo "exit=$?"
```

この実行環境（Claude Code on the webのリモート実行環境）には`gemini`コマンドが存在しない
（実行結果: `exit=1`）。**Gemini CLI本体を起動した実機検証は実施できない。**

代替として、**Gemini CLI本体の公式ソースコード**（`google-gemini/gemini-cli`、GitHub `main`ブランチ、
参照時点2026-08-23）を直接確認した。以下の判断はすべてこのソースコードを一次情報とする
（実機起動による動作確認は未検証のまま）。

## 1. 出力ファイル形式

### 確認したソース

- `docs/cli/telemetry.md`（公式ドキュメント）
- `packages/core/src/telemetry/sdk.ts`
- `packages/core/src/telemetry/file-exporters.ts`
- `packages/core/src/telemetry/loggers.ts`

### 判明した事実

- `outfile`は**単一ファイル固定パス**を指定する。`target: "local"`かつ`outfile`が設定された場合、
  `FileSpanExporter` / `FileLogExporter` / `FileMetricExporter` の3つのエクスポータが、
  **すべて同一の`telemetryOutfile`値で初期化される**（`sdk.ts`より、`config.getTelemetryOutfile()`
  の戻り値を3エクスポータ共通で渡している）。つまり**spans・logs・metricsが1つのファイルへ混在して
  追記される**。
- `file-exporters.ts`のコンストラクタは `fs.createWriteStream(filePath, { flags: 'a' })` で
  ファイルを**追記モード**で開く。
- シリアライズは `safeJsonStringify(data, 2) + '\n'`（インデント2のpretty-print JSON文字列＋末尾
  改行1つ）。**「1行1JSON」ではない。** 各エントリは複数行にわたるインデント付きJSONで、区切りは
  各エントリ末尾の改行1つのみ。ファイル全体は「複数のJSON値が連続して並ぶストリーム」になる
  （`jq -n 'inputs'`のようなホワイトスペース区切りの複数JSON値パーサで読める設計。厳密な検証は
  フェーズ3で実データ・フィクスチャに対して行う）。
- ローテーション実装は**無い**（`file-exporters.ts`にサイズ・日付ベースの切り替えロジックは
  見当たらない）。
- `gemini_cli.api_response`イベントは**OpenTelemetryのLogRecord**として記録される
  （`loggers.ts`で`logger.emit(event.toLogRecord(config))` / `logger.emit(event.toSemanticLogRecord
  (config))`。Spanのイベント（`span.addEvent`）ではない）。属性には `model` / `status_code` /
  `duration_ms` と、`input_token_count` / `output_token_count` / `cached_content_token_count` /
  `thoughts_token_count` / `tool_token_count` の各トークン種別が含まれる（`loggers.ts`の
  `tokenUsageData`配列より）。
- `session.id`属性がresource属性かlog属性かは、`loggers.ts`単体からは確定できなかった
  （`event.toOpenTelemetryAttributes(config)`内で処理されており、この関数の実装までは追えて
  いない。**未確認**）。

### テストフィクスチャの妥当化方法

上記`serialize()`の実装（`JSON.stringify(payload, null, 2) + '\n'`相当）を根拠に、
フェーズ3のテストフィクスチャは以下の方針で作成する。

- 各エントリはOpenTelemetry JS SDKの`ReadableLogRecord` / `ReadableSpan` /
  `ResourceMetrics`型のJSON表現を模した構造とする（正確なフィールド名は実データが無いため、
  OpenTelemetry JS SDKの型定義・`docs/cli/telemetry.md`のサンプル出力を参考にする）。
- ファイル全体は「複数のpretty-print JSON値が改行区切りで連続する」形式とし、jqでの読み込み方式
  （`inputs`によるストリーム読み込み）が正しく機能することを、まず最小のフィクスチャで単体検証
  してからテスト本体へ組み込む。
- **この段階のフィクスチャは推測に基づく**ため、フェーズ3実装時・フェーズ5（またはレビュー往復）で
  実機出力との突き合わせが取れ次第、フィクスチャを実データへ差し替える。差し替えるまでの間、
  spec・DDRに「フィクスチャは公式ソースコードからの推測であり実機出力での確認は未検証」と明示する。

### 受け入れ条件1（telemetry設定によりusage/配下へファイルが生成・追記される）の扱い

この実行環境では実機起動できないため、条件1の**実際の生成確認は本フェーズでは行えない**。
以下のいずれかを人間へ依頼する必要がある。

- (a) 人間のローカルGemini CLI環境で`telemetry.enabled: true` / `target: "local"` /
  `outfile: <パス>`を設定して1回実行し、出力ファイルが生成されることを確認してもらう。
- (b) 条件1の実機確認をフェーズ3のレビュー往復（3-8/3-9）またはフェーズ5への持ち越しとして
  記録する。

**本reportでは(b)を採用し、フェーズ3の個別作業計画に「受け入れ条件1の実機確認は人間へ依頼する」
と明記することを推奨する。**

## 2. `.gemini/settings.json`のスキーマ確認（受け入れ条件5）

### 確認したソース

- `packages/cli/src/config/settingsSchema.ts`
- `docs/cli/telemetry.md`

### 判明した事実

`settingsSchema.ts`で`telemetry`キーは次のように定義されている（引用）。

```typescript
telemetry: {
  type: 'object',
  label: 'Telemetry',
  category: 'Advanced',
  requiresRestart: true,
  default: undefined as TelemetrySettings | undefined,
  description: 'Telemetry configuration.',
  showInDialog: false,
  ref: 'TelemetrySettings',
}
```

**`telemetry`は`.gemini/settings.json`の トップレベルキー**であり、`general`配下ではない
（現行の`.gemini/settings.json`が持つ`general.plan.directory`とは別の階層）。

`docs/cli/telemetry.md`が示すキー一覧（`telemetry`オブジェクト直下）:

| キー | 型 | 既定値 | 備考 |
|---|---|---|---|
| `enabled` | boolean | `false` | テレメトリの有効/無効 |
| `traces` | boolean | `false` | 詳細属性トレーシング |
| `target` | `"local"` \| `"gcp"` | `"local"` | 送信先 |
| `otlpEndpoint` | string | `http://localhost:4317` | OTLPコレクタエンドポイント（`useCollector`利用時等） |
| `otlpProtocol` | `"grpc"` \| `"http"` | `"grpc"` | 転送プロトコル |
| `outfile` | string | （なし） | ファイル出力パス |
| `logPrompts` | boolean | `true` | プロンプト本文をログに含めるか |
| `useCollector` | boolean | `false` | 外部OTLPコレクタを使うか |
| `useCliAuth` | boolean | `false` | GCP向けCLI認証情報の利用 |

`TelemetrySettings`型自体の完全なフィールド定義（`packages/core/src/telemetry/types.ts`は
別の型セット（`BaseTelemetryEvent`等イベント型）であり見つからなかった）は未確認だが、
`docs/cli/telemetry.md`の設定例JSONと`settingsSchema.ts`のトップレベル配置により、本issueの
判断に必要な範囲（キー名・ネスト位置・型・既定値）は確認できた。

設定例（`docs/cli/telemetry.md`より引用）:

```json
{
  "telemetry": {
    "enabled": true,
    "target": "local",
    "outfile": ".gemini/telemetry.log"
  }
}
```

**判定**: 既存の`.gemini/settings.json`のキー（`general.plan.directory`, `hooks`）と衝突しない。
`telemetry`をトップレベルへ追加すればよい。

## 3. 出力先配置の比較（受け入れ条件7）

issue #103（Claude Code側OTelリスナー）は`usage/claude-otel-YYYYMMDD.jsonl`という**日次
ローテーション命名**を持つが、これは常駐perlリスナー自身が受信時刻に基づいてファイルを切り替える
ことで実現している（`.claude/docs/spec/otel-listener.md`）。

一方Gemini CLI側の`outfile`は、1.で確認したとおり**単一ファイル固定パス**であり、Gemini CLI本体に
日付ベースでファイルを切り替える機構は無い。`.gemini/settings.json`は静的なJSONファイルのため、
起動時に動的な日付を`outfile`へ埋め込むこともできない。

**判定: 完全な整合は取れない。** 出力先は`usage/gemini-otel.log`のような**固定ファイル名**とする
（issue #103のような日次ファイル分割はできない）。この判断はDDRへ「Gemini CLI本体が
ローテーション機構を持たないため、issue #103の日次命名パターンとは整合させない」として記録する。

## 4. 差分カーソル単位の判定

1.で確認したとおり、出力ファイルは「単一ファイル・追記型・spans/logs/metrics混在・各エントリが
複数行にわたるpretty-print JSON（区切りは末尾改行のみ）」という性質を持つ。

- **Claude Code経路の行カーソル方式（`lastLineCount`）は使えない**: 1エントリが複数行にまたがる
  ため、「行数」という単位そのものが意味を持たない。
- **Gemini CLIセッションログ経路の「ファイル全体を毎回`id`単位で畳み込む」方式（DDR i0097-01）も
  適さない**: セッションログは同一`id`のメッセージが後埋め・再送されるためこの方式を採ったが、
  テレメトリのログレコード・スパン・メトリクスは一度emitされたら不変であり、後から同じレコードが
  更新されて再出力されることは無い（`loggers.ts`の実装は、都度新しいイベントを`logger.emit()`する
  だけで、既存レコードの更新は行わない）。
- **推奨方式: バイトオフセットカーソル。** 前回処理した末尾のバイト位置を状態ファイルへ記録し、
  次回はそこ以降の新規バイトだけを読んで、複数のJSON値としてパースする（`jq -n 'inputs'`のような
  ホワイトスペース区切りの複数JSON値読み込みが利用できる見込み。フェーズ3で実装・検証する）。
  各エントリは一度しか出力されないため、この方式なら二重計上は起きない（Claude Code経路の行
  カーソルと同じ「一度数えた範囲は二度と数え直さない」原則が成り立つ）。

## 5. 二重計上回避方針（受け入れ条件2・3）

セッションログ由来（issue #97、`_usage_gemini_fold`系）とテレメトリ由来は、**入力データソースが
完全に別物**（前者は`~/.gemini/tmp/<hash>/chats/*.jsonl`、後者は`outfile`が指すファイル）であり、
別の状態ファイル（例: `usage/state/gemini-otel-cursor.json`）を持たせる設計にする。

既存のトークン列判別ロジック（`thoughts`キーの有無で判定、DDR i0097-03）と衝突させないため、
**当面はテレメトリ由来の値を既存の`tokensByModel`へ合算せず、レポート上の別セクション
（例: 「### Gemini CLI公式テレメトリ（参考値）」）として追加表示する**方針を推奨する。

理由: 「どちらを正とするか」を決め打ちで片方だけ表示する設計は、既にマージ・安定稼働している
issue #97のセッションログ集計を置き換えることになり、受け入れ条件4「Claude Code側の集計結果・
レポート内容が変化せず既存テストが通る」のリスクを不必要に広げる。別セクション表示なら、
両者を独立に検証・ロールバックできる。この判断はDDRへ記録する。

## 6. `logPrompts`の扱い（受け入れ条件6）

既定値は`true`（1.で確認済み）。プロンプト本文がログレコードの属性へ含まれる設計と見られる
（`docs/cli/telemetry.md`の記載。属性名までは本調査では未確認）。

**推奨: `.gemini/settings.json`へtelemetry設定を追記する際、`logPrompts: false`を明示的に
指定する。** 出力先（`usage/`配下）は`.gitignore`対象のためリポジトリへのコミットリスクは
無いが、ローカルディスク上に平文プロンプトが残ること自体を避ける。

## 7. 既定有効化の可否（受け入れ条件7の一部）

issue #103（Claude Code側）は`.claude/settings.json`（共有ファイル）へ`env.
CLAUDE_CODE_ENABLE_TELEMETRY`等を追加し、**配布先の利用者全員に対して既定でONにした**
（`.claude/docs/spec/otel-listener.md`「配布時の扱い」）。

Gemini CLI側も同様に`.gemini/settings.json`（共有ファイル）へ`telemetry.enabled: true`を
追加すれば、配布先全体で既定有効になる。`logPrompts: false`を明示指定する前提（6.）であれば、
既定でONにしてもプロンプト漏洩のリスクは無い。

**推奨: `logPrompts: false`を明示指定したうえで、`telemetry.enabled: true`を既定にする**
（issue #103と同じ判断に揃える）。

## 8. ローテーション方針

1.・3.で確認したとおり、Gemini CLI本体にはファイルローテーション機構が無く、`outfile`は
起動中ずっと同じファイルへ追記され続ける。

対応工数レポート側（push検知hook）で日次ローテーションを試みることも考えられるが、**Gemini CLI
プロセスが起動中に元ファイルをリネームすると、そのプロセスは同じinodeへ書き込みを継続するため、
新しいファイル名で内容を追跡できなくなる**（Unix系のファイルディスクリプタの一般的な挙動。
Gemini CLI固有の検証はしていない）。実行中プロセスに影響を与えない安全なローテーションは、
本機構側だけでは実現が難しい。

**推奨: 当面はローテーションを実装せず、無制限の追記を許容する。** 4.のバイトオフセットカーソル
方式により集計自体は正しく差分計算できるため、ファイルサイズの増大は運用上の課題（ディスク
使用量）にとどまる。将来的な対処（定期的な手動クリーンアップの案内、Gemini CLI起動をラップして
起動時に日付ベースのパスを渡す仕組み等）は、DDRの未決定事項として記録する。

## まとめ（フェーズ3への申し送り）

| 項目 | 判断 |
|---|---|
| 出力ファイル形式 | 単一ファイル・追記型・spans/logs/metrics混在・各エントリはpretty-print複数行JSON（区切りは末尾改行）。実機未検証（ソースコードで確認） |
| settings.jsonのスキーマ | `telemetry`はトップレベルキー。`enabled`/`target`/`otlpEndpoint`/`otlpProtocol`/`outfile`/`logPrompts`/`useCollector`/`useCliAuth` |
| 出力先配置 | issue #103とは整合させない（Gemini CLI側にローテーション機構が無いため）。固定ファイル名（例: `usage/gemini-otel.log`） |
| 差分カーソル単位 | バイトオフセットカーソル（行カーソル・畳み込み方式のいずれも不適） |
| 二重計上回避 | セッションログ由来とテレメトリ由来は別状態ファイル・レポート上は別セクション表示（合算しない） |
| logPrompts | `false`を明示指定 |
| 既定有効化 | `telemetry.enabled: true`を既定ON（logPrompts:false前提） |
| ローテーション | 当面実装しない（実行中プロセスへの影響が避けられないため） |

## 未検証・残課題

- Gemini CLI実機での動作確認（受け入れ条件1の生成確認、ファイル形式の実データ確認）はこの
  実行環境では実施できなかった。フェーズ3以降で人間のローカル環境での確認を依頼する。
- `session.id`属性がresource属性かlog属性かは未確認。
- `TelemetrySettings`型の完全なフィールド定義（`packages/core/src/telemetry/types.ts`ではなく
  別ファイルにある可能性）は未確認。`docs/cli/telemetry.md`とsettingsSchema.tsのトップレベル
  配置により、本issueの判断に必要な範囲は確認済み。
- 参照した公式ソースは2026-08-23時点の`google-gemini/gemini-cli` `main`ブランチ。
