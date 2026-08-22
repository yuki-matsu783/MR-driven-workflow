---
title: worklog 20260823 humming-mapping-pie 【設計】【実装】【テスト】OTelリスナー機構の実装 push1
type: log
description: issue #103のOTelリスナー機構の設計・実装・テスト（flow-id 3-1〜）の試行錯誤ログ
tags: [otel, telemetry, usage, perl, worklog]
keywords: [OpenTelemetry, OTLP, session-id, perl, listener, settings.local.json, 実装]
---

# worklog: 【設計】【実装】【テスト】OTelリスナー機構の実装

対象: issue #103のOTLPリスナー機構の設計・実装・テスト（2026-08-23〜）。
全体作業計画: `plans/humming-mapping-pie.md`
個別作業計画: `plans/【設計】【実装】【テスト】OTelリスナー機構の実装.md`
push回数: 1

## 試したこと

- フェーズ2調査結果（`reports/20260823_humming-mapping-pie_OTel設計論点調査.md`）と
  issue #103本文を突き合わせ、個別作業計画を作成した。
- issue期待する動作5「WSLはWindows側の同一ポート番号を占有するため、環境ごとに別ポートを
  割り当てる」と、フェーズ2結論4「プロジェクトスコープの`.claude/settings.json`で完結可能」
  の整合性を検討したところ、**単一の`.claude/settings.json`ではOS別にエンドポイントを
  分けられない**という矛盾に気づいた。
- 参考ディレクトリの`session-start.ps1`/`listener.py`/`session-start.sh`を再読し、
  python3依存箇所（対応表へのJSON追記）の移植方針を確認した。

## うまくいったこと

- 矛盾の解決策として、環境非依存の設定は`.claude/settings.json`（共有）、環境依存の
  `OTEL_EXPORTER_OTLP_ENDPOINT`等は`.claude/settings.local.json`（Claude Code標準の
  ローカルオーバーライド、Git管理外）に分離する方針を立てた。「リポジトリ内で完結」という
  期待する動作6の精神は保ちつつ（ユーザーホームではなくプロジェクト直下）、環境ごとの
  ポート分離も実現できる。

## ダメだったこと

（現時点では無し。計画作成段階のため実装上の失敗はまだ発生していない）

## 次の一歩（更新: flow-id 3-3〜3-5完了時点）

- flow-id 3-3: ユーザーから「`.claude/settings.local.json`への設定分離方針→OK」
  「単体テストの置き場所→OK」の回答をチャットで受けた。
- flow-id 3-4: チャットで受けた判断であるため、`.claude/skills/issue-mr-flow/SKILL.md`
  「チャットで受けたレビュー判断の記録」節の手順に従い、個別作業計画の該当箇所を
  「承認済み」に書き換えたうえで、`add_mr_comment`でMR #158へも記録コメントを投稿した
  （GitHub/GitLab上に判断の経緯が残るようにするため。個別計画はflow-id 5-4で削除される）。
- flow-id 3-5: 承認済みの設計判断8点をもとにMR #158 のdescriptionを更新した。
- 次はflow-id 3-6（perlによるHTTPリスナー・SessionStartフック拡張・単体テストの実装）に着手する。

## flow-id 3-6: 実装の進捗（このpush内で継続中）

### できたこと

- `.claude/hooks/otel/lib/SessionIdFinder.pm`: scratchpad検証版を土台に本実装。
- `.claude/hooks/otel/lib/OtelRegistry.pm`: 対応表の読み書き。純粋関数
  （`parse_registry_lines`/`needs_rotation`/`rotate_lines`）とファイルI/O層
  （`read_registry`/`append_registry_entry`）を分離し、単体テストは純粋関数のみを対象にした。
  schemaVersion不一致行は無視、500行超で直近300行へ切り詰め。
- `.claude/hooks/otel/lib/HttpMinimal.pm`: `IO::Socket::INET`用HTTP/1.1最小パーサ。
- `.claude/hooks/otel/listener.pl`: 上記3モジュールを組み合わせたリスナー本体。
  session.idが引ける分は`<cwd>/usage/claude-otel-YYYYMMDD.jsonl`、引けない分は
  共有位置の`unrouted-YYYYMMDD.jsonl`へ振り分け。ベストエフォート（書き込み失敗はwarnのみ）。
- `.claude/hooks/otel/session-start.sh`: stdinのJSONをperlワンライナー
  （`OtelRegistry::append_registry_entry`呼び出し）で対応表へ追記、`/dev/tcp/...`での
  多重起動判定、`setsid`有無で分岐したデタッチ起動。`set -e`は使わずベストエフォート。
- 単体テスト2本（`test_session_id_finder.pl`/`test_otel_registry.pl`）作成、
  `perl <path>`で実行しTAP形式で全件成功（7件・12件）を確認。
- `perl -c`で全perlファイルの構文チェック、`bash -n`でsession-start.shの構文チェック、
  いずれも成功。
- **scratchpad配下に隔離したe2e環境で実機検証**（ポート14320、共有ディレクトリ・
  ワークスペース2つとも一時ディレクトリ）:
  - session-start.sh初回実行で対応表への追記・リスナー起動を確認（プロセス1つ）。
  - 正常なOTLPペイロード送信→`usage/claude-otel-20260823.jsonl`への書き込みを確認。
  - session.idを含まないペイロード・不正JSON・空bodyの3種→いずれも
    `unrouted-20260823.jsonl`へ退避され、リスナーはクラッシュせず稼働継続（ポート開いたまま）。
  - 2回目のsession-start.sh実行→プロセス数は1のまま増えない（多重起動防止）、
    応答時間0.7秒（フックタイムアウト10秒に対し十分速い）。
  - 別ワークスペース向けの2つ目のセッション（test-sess-3）→1つ目のワークスペースの
    `usage/`には混ざらず、2つ目のワークスペースにのみ正しく振り分けられることを確認。
  - 不正JSON・空stdin・session_id欠落・共有ディレクトリ書き込み不可の4パターン、
    いずれも`session-start.sh`はexit 0で終了（ベストエフォート方針の実機確認）。
  - 検証後、Windows PID指定の`taskkill //F //PID <pid>`でリスナープロセスを終了、
    一時ディレクトリを削除して片付け済み。
- `.claude/settings.json`: `env`セクションを新設し環境非依存の6項目
  （`CLAUDE_CODE_ENABLE_TELEMETRY`等）を追加、`hooks.SessionStart`の既存matcherへ
  `.claude/hooks/otel/session-start.sh`のフックエントリを追加登録。`jq .`でJSON構文確認済み。
- `.claude/settings.local.json.example`: 環境依存の2項目
  （`OTEL_EXPORTER_OTLP_ENDPOINT`・`OTEL_RESOURCE_ATTRIBUTES`、Windows値をデフォルトに記載）
  をテンプレートとして新規作成。
- `.gitignore`: `/.claude/settings.local.json`を追加。

### 次の一歩

- `DEVELOPERS.md`に導入手順（`.claude/settings.local.json`の作成方法・WSL側の値・
  依存perlモジュールの確認方法）を追記する。
- 実装結果を`reports/日付_<全体計画名>_<内容>.md`へ記録する（個別作業計画には書かない）。
- `commit`スキル経由でcommit・push・レビュー依頼（flow-id 3-7）。

---
