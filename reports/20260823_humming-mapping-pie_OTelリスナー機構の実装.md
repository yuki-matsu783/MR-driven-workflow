---
title: 20260823 humming-mapping-pie OTelリスナー機構の実装
type: report
description: issue #103のフェーズ3実装結果。perl製OTLPリスナー・SessionStartフック拡張・単体テストの実装と実機検証の記録
tags: [otel, telemetry, usage, perl]
keywords: [OpenTelemetry, OTLP, session.id, listener, session-start, usage, perl, IO::Socket::INET, 実機検証, unrouted]
---

# OTelリスナー機構の実装（issue #103・フェーズ3〈設計・実装〉結果）

対象: issue #103。全体作業計画 `plans/humming-mapping-pie.md` のフェーズ3。
前提: `plans/【設計】【実装】【テスト】OTelリスナー機構の実装.md`（個別作業計画。
設計判断8点はレビューで承認済み）。

## 実装したファイル

| ファイル | 内容 |
|---|---|
| `.claude/hooks/otel/lib/SessionIdFinder.pm` | OTLP JSONの再帰全走査によるsession.id収集（純粋関数） |
| `.claude/hooks/otel/lib/OtelRegistry.pm` | 対応表の読み書き。純粋関数（`parse_registry_lines`/`needs_rotation`/`rotate_lines`）とファイルI/O層（`read_registry`/`append_registry_entry`）を分離 |
| `.claude/hooks/otel/lib/HttpMinimal.pm` | `IO::Socket::INET`でのHTTP/1.1最小パーサ |
| `.claude/hooks/otel/listener.pl` | HTTPリスナー本体。上記3モジュールを組み合わせ、`usage/`または`unrouted-*.jsonl`へ振り分け |
| `.claude/hooks/otel/session-start.sh` | 対応表への追記・多重起動判定・デタッチ起動（環境分岐） |
| `.claude/hooks/otel/test/test_session_id_finder.pl` | `SessionIdFinder.pm`の単体テスト（7ケース） |
| `.claude/hooks/otel/test/test_otel_registry.pl` | `OtelRegistry.pm`の純粋関数の単体テスト（12ケース） |
| `.claude/settings.json` | `env`セクション新設（環境非依存6項目）、`hooks.SessionStart`へフック登録 |
| `.claude/settings.local.json.example` | 環境依存2項目（`OTEL_EXPORTER_OTLP_ENDPOINT`/`OTEL_RESOURCE_ATTRIBUTES`）のテンプレート |
| `.gitignore` | `/.claude/settings.local.json`を追加 |
| `DEVELOPERS.md` | 導入手順（前提・設定手順・動作確認・単体テスト実行・既知の制限）を追記 |

個別作業計画の設計判断8点（配置場所・データフォーマット・ポート環境分岐・多重起動防止・
python3依存排除・HTTPサーバー実装・単体テスト出力形式・ベストエフォート方針）は、
いずれもそのまま実装へ反映した（差分は無し）。

## 単体テスト結果

```
$ perl .claude/hooks/otel/test/test_session_id_finder.pl
1..7
ok 1 - ネストの異なる2箇所からsession.idを収集できる
...(中略、全7件ok)

$ perl .claude/hooks/otel/test/test_otel_registry.pl
1..12
ok 1 - 正常な2行を読み込める
...(中略、全12件ok)
```

いずれも`Test::More`のTAP形式で全件成功（exit=0）。`perl -c`による全perlファイルの
構文チェック、`bash -n`による`session-start.sh`の構文チェックもあわせて実施し、
いずれも成功した。

## 実機検証（Windows / git bash）

scratchpad配下に隔離した一時ディレクトリ（共有位置・ワークスペース2つ）を使い、
ポート14320（実運用ポート4318とは別）でe2e検証を行った。

| 検証項目 | 手順 | 結果 |
|---|---|---|
| 対応表への追記・リスナー起動 | `session-start.sh`にstdinで`{"session_id":...,"cwd":...}`を渡して実行 | 対応表に1行追記、リスナープロセスが1つ起動、ポート待受を確認 |
| 正常なOTLPペイロードの振り分け | session.idを含むペイロードをcurlでPOST | `<cwd>/usage/claude-otel-YYYYMMDD.jsonl`へ追記 |
| session.idを引けないペイロード | session.id属性を含まないペイロードをPOST | `unrouted-YYYYMMDD.jsonl`へ退避 |
| 不正JSON・空body | 不正な文字列・空文字列をPOST | いずれも`unrouted-*.jsonl`へ退避、リスナーはクラッシュせず稼働継続（ポート開いたまま） |
| 二重起動防止 | 2つ目のセッションで`session-start.sh`を再実行 | プロセス数は1のまま増えない。応答時間0.7秒（フックタイムアウト10秒に対し十分速い） |
| 別ワークスペースの分離 | 2つ目のワークスペース向けセッションを追加登録し、そのsession.idでPOST | 1つ目のワークスペースの`usage/`には混ざらず、2つ目にのみ正しく振り分け |
| ベストエフォート方針 | 不正JSON・空stdin・session_id欠落・共有ディレクトリ書き込み不可の4パターンで`session-start.sh`を実行 | いずれもexit 0で終了（フック失敗がセッション開始を止めないことを確認） |
| `.gitignore`対象 | `.claude/settings.local.json`を作成し`git check-ignore -v`で確認 | `.gitignore:50:/.claude/settings.local.json`にマッチ（対象） |

検証後、Windows PID（`ps -W`のWINPID列）を指定した`taskkill //F //PID <pid>`でリスナー
プロセスを終了し、一時ディレクトリを削除して片付けた。

### 未検証・今回のスコープ外（flow-id 3-8レビューでユーザー側検証と合意済み）

- **WSL実機でのリスナー起動・疎通確認は今回は実施していない**（フェーズ2でperlコア
  モジュールの利用可否・`setsid`の有無は確認済みだが、フェーズ3ではWindows側のみ
  e2e検証を行った）。実装（環境分岐ロジック）はコードレビューベースで妥当性を確認した。
  **この先もMRの中では追加検証を行わず、ユーザー側での検証に委ねる**（flow-id 3-8の
  レビューで合意済み）。
- **Claude Code実機からの実際のOTLPエクスポート結線は未確認**（`session-start.sh`への
  stdin入力とHTTPリクエストはcurl等で模擬したもので、Claude Code本体を起動して
  `.claude/settings.local.json`経由の設定でテレメトリが実際に飛ぶことまでは今回確認して
  いない）。**こちらも同様にユーザー側での検証に委ねる**（flow-id 3-8のレビューで合意済み）。

## 受け入れ条件との対応

| 受け入れ条件 | 状況 |
|---|---|
| プロンプト1回で`usage/`にJSONLが生成・追記される | e2e検証で模擬確認済み。Claude Code実機での結線は未確認（上記） |
| 別ワークスペースのセッションが混ざらない | 確認済み |
| session.idを引けなかったペイロードが失われない | 確認済み |
| 二重起動せずセッション開始が遅延しない | 確認済み（0.7秒） |
| Windows/WSL双方でポート・出力先を奪い合わない | Windows側は確認済み。WSL側は未検証（ユーザー側での検証に委ねる。上記） |
| 追加パッケージ無しで両perlから起動できる | Windows側は確認済み。WSL側はフェーズ2で確認済み（コアモジュール利用可否のみ、起動確認はユーザー側での検証に委ねる） |
| 受け口・フック失敗時もセッションが継続する | 確認済み（4パターンでexit 0） |
| テレメトリ出力先が`.gitignore`対象 | 確認済み |
| 単体テストが動作する | 確認済み（TAP形式、全19件成功） |
| DDR・spec・導入手順が揃っている | 導入手順（DEVELOPERS.md）のみ完了。DDR・specはフェーズ4で対応 |

## フェーズ4への持ち越し事項

- DDR新規作成: perlを採用する理由（コアモジュールのみに依存を限る事情を含む）、
  `.claude/settings.local.json`分離の理由（環境ごとのポート分離とプロジェクトスコープ
  設定の両立）。
- spec新規作成: `.claude/docs/spec/`配下にOTelリスナー機構の仕様（配置・ポート・出力
  形式・設定項目・既知の制限）を1本新設する。
- AIアセット反映候補: `.claude/rules/directory-structure.md`の`usage/`節・「配置の指針」
  節への追記、`.claude/rules/shell-script-style.md`への「perlの単体テストはTest::Moreを
  使いTAP形式で出力する」旨の追記。
- **WSL実機でのe2e検証・Claude Code本体からの結線確認は、フェーズ4でも行わずユーザー側での
  検証に委ねる**（flow-id 3-8のレビューで合意済み。「どちらもユーザ側での検証で良い」）。
