---
title: OTelリスナー機構（.claude/hooks/otel/）
type: spec
description: Claude Code公式のOpenTelemetry（OTLP）エクスポートをローカルで受信し、session.id属性からワークスペースを引いてusage/配下へ振り分け保存するperl製リスナー機構の仕様
tags: [otel, telemetry, usage, perl]
keywords: [OpenTelemetry, OTLP, session.id, listener, session-start, sessions.jsonl, unrouted, IO::Socket::INET, settings.local.json]
---

# OTelリスナー機構（.claude/hooks/otel/）

## 背景・目的

issue #103。Claude Code公式のOpenTelemetry（OTLP）エクスポートをローカルで受信し、
`session.id`属性からセッションの出力先ワークスペースを引いて`<ワークスペース>/usage/`配下へ
振り分け保存する機構。参考資料（`参考ディレクトリ/otel/`、Git管理外のPython/PowerShell実装）
を土台に、本リポジトリの言語方針に合わせてperlへ移植した。

**既存の対応工数レポート機構**（`.claude/hooks/post-push-usage-report.sh` /
`.claude/hooks/lib/UsageTracking.sh`）は`transcript_path`が指すJSONLの自前パースに依存しており、
この非公開フォーマット依存のリスクはDDR
[i0000-04](../ddr/i0000-04-対応工数レポートはtranscript自前パースで実装する.md)に記録済みである。
本機構は、この非公開フォーマット依存に対して**Claude Code公式のテレメトリ経路（OTLP）を
並行して確保する土台**であり、**対応工数レポートの集計元をtranscriptパースからテレメトリへ
置き換えるものではない**（issue #103期待する動作9で明示的にスコープ外）。

## 仕組み

1. `SessionStart`フック（`.claude/hooks/otel/session-start.sh`）の標準入力に`session_id`と
   `cwd`が届く。
2. フックがこれを対応表（共有位置の`sessions.jsonl`）へ追記し、リスナーが起動していなければ
   デタッチ起動する。
3. リスナー（`.claude/hooks/otel/listener.pl`）は受信したOTLP/JSONペイロードを再帰的に全走査
   して`session.id`属性を拾い（`.claude/hooks/otel/lib/SessionIdFinder.pm`）、対応表から
   出力先ワークスペースを引く（`.claude/hooks/otel/lib/OtelRegistry.pm`）。
4. 引けた分は`<cwd>/usage/claude-otel-YYYYMMDD.jsonl`へ、引けなかった分は共有位置の
   `unrouted-YYYYMMDD.jsonl`へ追記する。

`session.id`はメトリクスにもログにも付く標準属性（`OTEL_METRICS_INCLUDE_SESSION_ID`の既定が
true）。ネストの深さがシグナル種別（メトリクス/ログ/トレース）によって異なるため、リスナーは
構造を決め打ちせずJSON全体を全走査する。

## 配置

```
.claude/hooks/otel/
├── listener.pl              # HTTPリスナー本体
├── session-start.sh         # SessionStartフック本体（bash）
├── lib/
│   ├── SessionIdFinder.pm   # session.id全走査（純粋関数）
│   ├── OtelRegistry.pm      # 対応表の読み書き（純粋関数＋ファイルI/O層）
│   └── HttpMinimal.pm       # IO::Socket::INETでのHTTP/1.1最小パーサ
└── test/
    ├── test_session_id_finder.pl
    └── test_otel_registry.pl
```

`.claude/scripts/test/`（`.claude/scripts/src/`配下スクリプト専用、
`.claude/rules/directory-structure.md`）ではなく`.claude/hooks/otel/test/`にテストを置く。
本機構は`.claude/hooks/`配下の常駐プロセスであり、`.claude/scripts/src/`配下のAIエージェント
能動実行スクリプトとは性質が異なるため。

## 設定項目

| ファイル | 管理 | 内容 |
|---|---|---|
| `.claude/settings.json` | Git管理下（共有） | `hooks.SessionStart`のフック登録、環境非依存の`env`（`CLAUDE_CODE_ENABLE_TELEMETRY`・`OTEL_METRICS_EXPORTER`・`OTEL_LOGS_EXPORTER`・`OTEL_EXPORTER_OTLP_PROTOCOL`・`OTEL_METRIC_EXPORT_INTERVAL`・`OTEL_METRICS_INCLUDE_ENTRYPOINT`） |
| `.claude/settings.local.json` | Git管理外（`.gitignore`対象） | 環境依存の`env`（`OTEL_EXPORTER_OTLP_ENDPOINT`・`OTEL_RESOURCE_ATTRIBUTES`）。Windows/WSLで異なるポート・属性値を持つため分離している（理由・却下案: [i0103-02](../ddr/i0103-02-OTelエンドポイント設定をsettings.local.jsonへ分離する理由.md)） |
| `.claude/settings.local.json.example` | Git管理下（テンプレート） | 上記のコピー元。導入手順（`DEVELOPERS.md`）から参照する |

環境変数（リスナー・フックのプロセス環境）:

| 変数 | 既定値 | 意味 |
|---|---|---|
| `OTEL_USAGE_PORT` | `4318` | リスナーの待受ポート |
| `CLAUDE_OTEL_SHARED_DIR` | Windows: `%USERPROFILE%\.claude-otel\`、WSL/Linux: `~/.claude-otel/` | 対応表・未振り分けファイル・リスナーログの共有位置 |

Windows/WSL間でポート番号（4318/4319）を分けるのは、両者が127.0.0.1を共有しつつも別プロセス
空間で動くため、同じポートで両方のリスナーを同時に立てられないため（issue #103期待する動作5）。

## 出力形式

### 対応表（`<共有位置>/sessions.jsonl`）

session_id → cwd の対応表。1行1エントリのJSONL。

```json
{"schemaVersion":1,"session_id":"...","cwd":"..."}
```

`schemaVersion`は、複数リポジトリ・複数バージョンの本機構を同時運用したときに、対応表の行が
どのバージョンで書かれたか判別できるようにするために付与している（一致しない行はリスナー側で
無視される）。500行を超えたら直近300行へ切り詰める。

### セッション出力（`<cwd>/usage/claude-otel-YYYYMMDD.jsonl`）

`session.id`を引けたペイロードの記録。日次ローテーション（日付はリスナーのローカル時刻）。

```json
{"ts":"2026-08-23T05:08:58+0900","payload":{ /* OTLP/JSONペイロードそのもの */ }}
```

### 未振り分け（`<共有位置>/unrouted-YYYYMMDD.jsonl`）

`session.id`を引けなかったペイロード・不正なJSONペイロードの退避先。フォーマットは
セッション出力と同じ（`payload`に不正JSONの場合は`{"raw": "..."}`が入る）。

## 多重起動防止・デタッチ起動

- 多重起動防止: `/dev/tcp/127.0.0.1/${PORT}`への接続試行（bash組み込み、外部コマンド不要）。
  既に待受中ならリスナーを起動せず終了する。
- デタッチ起動: `uname`相当の判定で環境分岐する。
  - WSL/Linux: `setsid nohup perl listener.pl >listener.log 2>&1 </dev/null & disown`
  - Windows(git bash/MSYS): `nohup perl listener.pl >listener.log 2>&1 </dev/null & disown`
    （`setsid`が存在しないため省く）

## ベストエフォート方針

`session-start.sh`は`set -u`のみを使い`set -e`は使わない。個別コマンドの失敗は`2>/dev/null`や
`|| true`で握りつぶし、**必ずexit 0で終了する**（フック失敗がClaude Codeのセッション開始を
妨げないため）。リスナー本体も、書き込み失敗時は`warn`のみでプロセスを継続する。

## 既知の制限

参考実装（`参考ディレクトリ/otel/README.md`）の制限をそのまま踏襲する。

- セッション開始直後の数秒間は、リスナー起動前のエクスポートを取りこぼす。
- セッション中に`cwd`が変わっても対応表は追従しない（`CwdChanged`フックでの更新は本機構の
  スコープ外）。
- 出力ファイル（`usage/claude-otel-YYYYMMDD.jsonl`）は日次ローテーションのみで、古いファイルの
  自動削除は行わない。
- リスナーはClaude Code終了後も常駐する。ログオン時の自動起動は本機構のスコープ外。

## 導入手順

`DEVELOPERS.md`「OpenTelemetryリスナーの導入」節を参照（前提・設定手順・動作確認・単体テスト
実行方法を記載。本specでは重複記載しない）。

## 影響範囲

### issue #103（新規追加）

新規:
- `.claude/hooks/otel/listener.pl`
- `.claude/hooks/otel/session-start.sh`
- `.claude/hooks/otel/lib/SessionIdFinder.pm` / `OtelRegistry.pm` / `HttpMinimal.pm`
- `.claude/hooks/otel/test/test_session_id_finder.pl` / `test_otel_registry.pl`
- `.claude/settings.local.json.example`
- `.claude/docs/spec/otel-listener.md`（本ファイル）
- `.claude/docs/ddr/i0103-01-perlを常駐プロセス実装の選択肢に加える理由.md`
- `.claude/docs/ddr/i0103-02-OTelエンドポイント設定をsettings.local.jsonへ分離する理由.md`

変更:
- `.claude/settings.json`（`env`セクション新設、`hooks.SessionStart`へフック登録）
- `.gitignore`（`/.claude/settings.local.json`を追加）
- `DEVELOPERS.md`（導入手順を追記）

## 未決定事項・懸念点

- **WSL実機でのe2e検証・Claude Code本体からの実際のOTLPエクスポート結線確認は、issue #103の
  MRでは実施していない**。単体テスト（TAP形式、全19件成功）とWindows実機でのe2e検証
  （scratchpad上の隔離環境、curl等での模擬リクエスト）は実施済みだが、実際のWSL環境での起動・
  Claude Code本体を起動した状態での結線は、導入時にユーザー側で確認する方針で合意済み
  （flow-id 3-8レビュー）。
- **対応表・未振り分けファイルの共有位置（`%USERPROFILE%\.claude-otel\` / `~/.claude-otel/`）は、
  複数リポジトリ間で共有される。** 複数のワークスペースを同時に開く場合、対応表は1つのファイルに
  複数ワークスペース分のエントリが混在するが、`session_id`をキーに引くため混線はしない
  （実機検証で確認済み、`reports/20260823_humming-mapping-pie_OTelリスナー機構の実装.md`）。
- **リスナーのバージョン不整合**: 複数のリポジトリ（本機構の異なるバージョンを持つ）が同じ
  マシン上で同じ共有位置を使う場合、先に起動したリスナーのバージョンが後から開いたリポジトリの
  リスナー起動を防いでしまう可能性がある（多重起動防止はポート単位のため）。`schemaVersion`は
  対応表の行の互換性チェックには使えるが、リスナープロセス自体のバージョン管理は行っていない。
