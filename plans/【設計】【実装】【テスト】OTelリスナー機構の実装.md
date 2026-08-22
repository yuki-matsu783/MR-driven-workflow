---
title: 【設計】【実装】【テスト】OTelリスナー機構の実装
type: plan
description: issue #103のフェーズ3個別作業計画。調査結果（reports/）をもとにperl製OTLPリスナー・SessionStartフック拡張・単体テストの設計と実装を行う
tags: [otel, telemetry, usage, perl]
keywords: [OpenTelemetry, OTLP, session.id, listener, session-start, usage, perl, IO::Socket::INET, ポート, settings.local.json, ローテーション]
---

# 【設計】【実装】【テスト】OTelリスナー機構の実装

対象: issue #103。全体作業計画 `plans/humming-mapping-pie.md` のフェーズ3。
前提: `reports/20260823_humming-mapping-pie_OTel設計論点調査.md`（フェーズ2調査結果）。

設計・実装・テストをまとめて1ファイルで進める。理由: 設計判断の大半はフェーズ2の調査で
既に確定しており、残る論点（後述の持ち越し事項・新規判明事項）も実装時に確定できる規模で
あるため、設計だけを独立してレビューする意義が薄い。実装とテストも同時に書くのが自然なため
併記する。

## 目的

Claude Code公式のOTLP（OpenTelemetry）エクスポートをローカルで受信し、`session.id`属性から
出力先ワークスペースを引いて`<ワークスペース>/usage/`配下へ振り分け保存する機構を、
`参考ディレクトリ/otel/`のPython/PowerShell実装を土台にperlへ移植する。

## やらないこと（スコープ外）

- 対応工数レポートの集計元をtranscriptパースからテレメトリへ置き換えること（issue本文
  期待する動作9で明示的にスコープ外）
- `CwdChanged`フックでの対応表更新（参考実装の既知の制限として残す。README該当箇所を踏襲）
- リスナーのログオン時自動起動（タスクスケジューラ／`~/.profile`連携。参考実装は「必要なら」
  という位置づけであり、本issueの受け入れ条件には含まれない）

## 設計判断

### 1. 配置場所

`reports/`の結論どおり `.claude/hooks/otel/` を新設する。

```
.claude/hooks/otel/
├── listener.pl              # HTTPリスナー本体
├── session-start.sh         # SessionStartフック本体（bash）
├── lib/
│   ├── SessionIdFinder.pm   # session.id全走査（純粋関数）
│   ├── OtelRegistry.pm      # 対応表の読み書き（mtimeキャッシュ付き）
│   └── HttpMinimal.pm       # IO::Socket::INETでのHTTP/1.1最小パーサ
└── test/
    ├── test_session_id_finder.pl
    └── test_otel_registry.pl
```

**テストの置き場所を`.claude/scripts/test/`ではなく`.claude/hooks/otel/test/`にする判断**
について: issue受け入れ条件の文言は「`.claude/scripts/test/`配下」を指定しているが、
`.claude/rules/directory-structure.md`は`.claude/scripts/test/`を「`.claude/scripts/src/`
配下スクリプトの単体テスト」の置き場と位置づけており、本機構は`.claude/scripts/src/`ではなく
`.claude/hooks/`配下に置く（1.の結論）。ディレクトリ構成の一貫性を優先し、
**`.claude/hooks/otel/test/`に置く案を提案し、レビューで確認する**（issue文言と現在の
規約の間にズレがあるため、独断で決めず合意を取る）。

### 2. データフォーマット・状態の置き場所

- **対応表**（`sessions.jsonl`相当）: 共有位置に置く。各行
  `{"schemaVersion":1,"session_id":"...","cwd":"..."}`。
  **`schemaVersion`を追加する**（持ち越し事項1: 機構バージョンの不整合対策。複数リポジトリで
  異なるバージョンのOTel機構を同時に開いた場合、リスナー側がバージョン不明な行を無視できる
  ようにするため）。
- **出力先**: `<cwd>/usage/claude-otel-YYYYMMDD.jsonl`（持ち越し事項2: 日次ローテーション採用。
  日付はリスナーのローカル時刻）。
- **未振り分け**: 共有位置の`unrouted-YYYYMMDD.jsonl`（同様に日次ローテーション）。
- **共有位置の具体パス**（持ち越し事項4）: Windows: `%USERPROFILE%\.claude-otel\`、
  WSL/Linux: `~/.claude-otel/`。

### 3. ポート・エンドポイント設定の環境分岐（新規判明事項）

issue期待する動作5は「WSLはWindows側の同一ポート番号を占有するため、環境ごとに別ポートを
割り当てる」と明記している。しかし単一の`.claude/settings.json`（Git管理下・Windows/WSL共有）
では`env.OTEL_EXPORTER_OTLP_ENDPOINT`に1つの値しか持てず、**フェーズ2の結論4（プロジェクト
スコープの`.claude/settings.json`で完結可能）だけでは、環境ごとのポート分離を満たせない**
ことが本計画の作成中に判明した。

**対応方針（案）**: 環境非依存の設定は`.claude/settings.json`（共有）に、環境依存の
`OTEL_EXPORTER_OTLP_ENDPOINT`・`OTEL_RESOURCE_ATTRIBUTES`（`host.env=win`/`host.env=wsl`）は
`.claude/settings.local.json`（Claude Code標準のローカルオーバーライド設定。Git管理外）に置く。

| ファイル | 管理 | 内容 |
|---|---|---|
| `.claude/settings.json` | Git管理下（共有） | `hooks.SessionStart`のフック登録、`CLAUDE_CODE_ENABLE_TELEMETRY`・`OTEL_METRICS_EXPORTER`・`OTEL_LOGS_EXPORTER`・`OTEL_EXPORTER_OTLP_PROTOCOL`・`OTEL_METRIC_EXPORT_INTERVAL`等の環境非依存の値 |
| `.claude/settings.local.json` | Git管理外（`.gitignore`追加要） | `OTEL_EXPORTER_OTLP_ENDPOINT`（Windows: `http://localhost:4318`、WSL: `http://localhost:4319`）・`OTEL_RESOURCE_ATTRIBUTES` |
| `.claude/settings.local.json.example` | Git管理下（テンプレート） | 上記のコピー元。導入手順から参照する |

この方針は「可能な限りリポジトリ内で完結」（期待する動作6）を「ユーザーホームではなく
プロジェクトディレクトリ内で完結」と解釈し直すもので、`.claude/settings.local.json`自体は
プロジェクト直下にあるためリポジトリ外（ユーザーホーム）への書き込みは発生しない。
**この解釈・方針転換をレビューで確認する**（フェーズ2の結論を実質的に修正するため）。

### 4. 多重起動防止・デタッチ起動（環境分岐）

`reports/`の結論どおり。

- 多重起動防止: `/dev/tcp/127.0.0.1/${PORT}`への接続試行（bash組み込み、外部コマンド不要）。
- デタッチ起動: `session-start.sh`内で`uname -s`相当により判定し分岐する。
  - WSL/Linux: `setsid nohup perl listener.pl >listener.log 2>&1 </dev/null & disown`
  - Windows(git bash/MSYS): `nohup perl listener.pl >listener.log 2>&1 </dev/null & disown`
    （`setsid`を省く）

### 5. 対応表への追記（python3依存の排除）

参考実装の`session-start.sh`はJSON生成にpython3のワンライナーを使っているが、本リポジトリは
Pythonへの依存を持たない（issue現状セクション）。**perlのワンライナー
（`perl -MJSON::PP -e '...'`）に置き換える**（`session-start.sh`本体はbashのまま、
JSON生成部分だけperlを呼ぶ）。

### 6. HTTPサーバー実装

`reports/`で実機検証済みの方式を踏襲。`IO::Socket::INET`でリッスンし、シングルスレッドの
逐次`accept`ループで処理する（排他制御不要。理由は`reports/`5節参照）。不正なペイロードは
`eval`で捕捉し200を返す（クラッシュしない）。

### 7. 単体テストの出力形式

`reports/`の推奨案どおり、**`Test::More`のTAP形式のまま採用する**（bash版の
`passed=N failures=N`への変換は行わない）。`.claude/rules/shell-script-style.md`に
「perlの単体テストは`Test::More`を使いTAP形式で出力する」旨を追記する（フェーズ4で反映）。

### 8. フックのタイムアウト・ベストエフォート方針

`reports/`の結論どおり。`session-start.sh`のtimeoutは10秒。各処理は失敗しても
フック自体の終了コードを0で返す（`set -u`のみ、`set -e`は使わない。個別コマンドの失敗は
`2>/dev/null`や`|| true`で握りつぶす）。

## 実装対象ファイル

| ファイル | 責務 |
|---|---|
| `.claude/hooks/otel/listener.pl` | HTTPリスナー本体。`HttpMinimal.pm`でリクエストを受け、`SessionIdFinder.pm`でsession.idを抽出、`OtelRegistry.pm`で出力先を引いて振り分け書き込み |
| `.claude/hooks/otel/session-start.sh` | stdinから`session_id`/`cwd`を取得し対応表へ追記、多重起動判定、デタッチ起動（環境分岐） |
| `.claude/hooks/otel/lib/SessionIdFinder.pm` | OTLP JSONの再帰全走査によるsession.id収集（純粋関数） |
| `.claude/hooks/otel/lib/OtelRegistry.pm` | 対応表の読み込み（mtimeキャッシュ）・追記・肥大化時の切り詰め |
| `.claude/hooks/otel/lib/HttpMinimal.pm` | `IO::Socket::INET`でのHTTP/1.1最小パーサ（リクエスト行・ヘッダ・Content-Length分のbody読み取り） |
| `.claude/hooks/otel/test/test_session_id_finder.pl` | `SessionIdFinder.pm`の単体テスト |
| `.claude/hooks/otel/test/test_otel_registry.pl` | `OtelRegistry.pm`の単体テスト |
| `.claude/settings.json` | `hooks.SessionStart`へのエントリ追加、環境非依存の`env`追加 |
| `.claude/settings.local.json.example` | 環境依存`env`（`OTEL_EXPORTER_OTLP_ENDPOINT`等）のテンプレート |
| `.gitignore` | `.claude/settings.local.json`を追加 |
| `DEVELOPERS.md` | 導入手順（`.claude/settings.local.json`の作成方法、依存perlモジュールの確認方法） |

## テスト方針

副作用の無い純粋ロジック（`SessionIdFinder.pm`のsession.id抽出、`OtelRegistry.pm`の
JSONLパース・肥大化判定）を`Test::More`で単体テストする。HTTPサーバー本体・実際のファイル
I/Oを伴う結合確認は、Windows実機・WSL実機での動作確認で代替する（`reports/`のscratchpad
検証コードを土台に、コミット対象のテストコードとして整備する）。

## 検証手順（受け入れ条件との対応）

| 受け入れ条件 | 検証方法 |
|---|---|
| プロンプト1回で`usage/`にJSONLが生成・追記される | Windows実機でプロンプトを1回実行し確認 |
| 別ワークスペースのセッションが混ざらない | 2ワークスペースで同時にセッションを起動し確認 |
| session.idを引けなかったペイロードが失われない | `curl`で`session.id`を含まないペイロードを送信し`unrouted-*.jsonl`を確認 |
| 二重起動せずセッション開始が遅延しない | リスナー起動済み状態で2つ目のセッションを起動しプロセス数・応答時間を確認 |
| Windows/WSL双方でポート・出力先を奪い合わない | `.claude/settings.local.json`をそれぞれの環境で設定し同時起動して確認 |
| 追加パッケージ無しで両perlから起動できる | `reports/`で確認済みのコアモジュールのみで構成。実行確認で再確認 |
| 受け口・フック失敗時もセッションが継続する | ポートを塞ぐ・フックを一時的に壊すなどでエラーを発生させ、セッションが継続することを確認 |
| テレメトリ出力先が`.gitignore`対象 | `git check-ignore -v`で確認（`reports/`で確認済み） |
| 単体テストが動作する | `perl .claude/hooks/otel/test/test_session_id_finder.pl`等を実行しTAP出力を確認 |
| DDR・spec・導入手順 | フェーズ4で対応 |

## 主要ファイル

- `参考ディレクトリ/otel/listener.py` / `session-start.sh`（移植元）
- `reports/20260823_humming-mapping-pie_OTel設計論点調査.md`（フェーズ2結論）
- `.claude/settings.json`
- `.claude/rules/directory-structure.md`
- `.claude/rules/shell-script-style.md`
