---
title: 20260823 humming-mapping-pie 統括
type: report
description: issue #103（OTelリスナー機構の追加）の最終統括レポート。全フェーズの変更内容・判断根拠・検証結果・spec/DDRへの反映先・残課題をまとめる
tags: [otel, telemetry, perl, usage, 統括]
keywords: [OpenTelemetry, OTLP, session.id, listener, perl, usage, DDR, spec, 対応工数レポート]
---

# OTelリスナー機構 統括（issue #103 / PR #158）

対象: 全体作業計画 `plans/humming-mapping-pie.md`。フェーズ1〜4の全成果をまとめる。

## 何を変えたか

- Claude Code公式のOpenTelemetry（OTLP）エクスポートをローカルで受信し、`session.id`属性から
  出力先ワークスペースを引いて`<ワークスペース>/usage/`配下へ振り分け保存するperl製の常駐
  リスナー機構を新設した（`.claude/hooks/otel/`）。
  - `listener.pl`: `IO::Socket::INET`による自前HTTP/1.1最小パーサでOTLP/JSONペイロードを受信。
  - `session-start.sh`: `SessionStart`フックが`session_id`/`cwd`を共有位置の対応表
    （`sessions.jsonl`）へ追記し、リスナー未起動時はデタッチ起動する。
  - `lib/SessionIdFinder.pm`: ペイロードを構造非依存で全走査し`session.id`属性を収集する純粋関数。
  - `lib/OtelRegistry.pm`: 対応表の読み書き（`schemaVersion`付与・500行超で300行へ切り詰め）。
  - `lib/HttpMinimal.pm`: HTTP/1.1リクエストの最小パース。
  - 出力: `<ワークスペース>/usage/claude-otel-YYYYMMDD.jsonl`（1つ以上の出力先が引けた場合、
    重複を除いた各ワークスペースへペイロード全体を複製して追記）。1つも引けなかった場合のみ
    共有位置の`unrouted-YYYYMMDD.jsonl`へ退避。
- 設定を環境非依存（`.claude/settings.json`、Git管理下）と環境依存（`.claude/settings.local.json`、
  Git管理外。エンドポイント・待受ポート）に分離した。Windows/WSLは同じ127.0.0.1を別プロセス空間で
  共有するため、ポート番号（既定4318、WSL側は4319等）を環境ごとに揃える必要がある。
- perl製単体テスト2本（`test/test_session_id_finder.pl`・`test/test_otel_registry.pl`、TAP形式・
  全19件成功）を追加した。
- 設計反映として、DDR2件（`i0103-01`: perlを常駐プロセス実装の選択肢に加える理由、`i0103-02`:
  OTelエンドポイント設定を`settings.local.json`へ分離する理由）とspec1件
  （`.claude/docs/spec/otel-listener.md`）を新設した。
- AIアセット反映として、`.claude/rules/directory-structure.md`（常駐プロセスのディレクトリ構成・
  テスト配置ルール・`usage/`節へのOTel出力の説明）・`.claude/rules/shell-script-style.md`
  （perl製常駐プロセスの単体テストは`Test::More`/TAP形式でよい旨）・
  `.claude/docs/spec/shell-scripts.md`（常駐プロセスが必要な場合の第三の選択肢としてperlを追加）・
  `index.md`を更新した。`.claude/VERSION`を`0.1.2`→`0.2.0`へ更新した（配布対象アセットの追加）。
- 敵対的レビュー（`/adversarial-review`、フェーズ4実施1回目）で17件の指摘（投稿10件・報告7件）を
  受け、すべてに対応した。他プロジェクトへの配布を踏まえ、DDR・specの本文からissue番号への参照を
  内容の直接要約へ置き換えた（DDRのファイル名・識別子`i0103-01`等は命名規則上必須のため維持）。
- 関連issue #105（Gemini CLIテレメトリのローカル出力・push毎集計）へマージ前通知を投稿した。

## なぜそうしたか

- **perlの採用**: 常駐HTTPサーバが必要（bashでは実装できない）という制約のもと、追加インストール
  不要なコアモジュール（`IO::Socket::INET`・`JSON::PP`）のみで実装できる言語としてperlを選んだ。
  `HTTP::Daemon`はコア添付ではないため使わず、自前の最小パーサを実装した。詳細・却下案は
  [i0103-01](../.claude/docs/ddr/i0103-01-perlを常駐プロセス実装の選択肢に加える理由.md)。
- **設定ファイルの分離**: 環境依存の値（Windows/WSLで異なるポート・エンドポイント）を単一の
  共有設定ファイルへ持たせると環境ごとに切り替えられないため、Git管理外の
  `.claude/settings.local.json`へ分離した。プロジェクトスコープでの完結を優先し、ユーザーホームへは
  置かない設計にした。詳細・却下案は
  [i0103-02](../.claude/docs/ddr/i0103-02-OTelエンドポイント設定をsettings.local.jsonへ分離する理由.md)。
- **既存の対応工数レポート機構との関係**: transcript自前パースに依存する既存機構（DDR
  [i0000-04](../.claude/docs/ddr/i0000-04-対応工数レポートはtranscript自前パースで実装する.md)）を
  置き換えるのではなく、公式テレメトリ経路を並行して確保する土台として位置づけた
  （集計元の置き換えは明示的にスコープ外）。
- **WSL実機でのe2e検証とClaude Code本体からの実際の結線確認**は、フェーズ3レビュー（flow-id 3-8）
  でユーザー側での検証に委ねることに合意した。

## 検証結果

| 検証項目 | 結果 |
|---|---|
| perl単体テスト（TAP形式） | `test_session_id_finder.pl`・`test_otel_registry.pl`とも全19件成功 |
| scratchpad隔離環境でのe2e実機検証 | 正常振り分け・unrouted退避・二重起動防止・別ワークスペース分離・ベストエフォート方針を確認 |
| `.gitignore`対象確認 | `/.claude/settings.local.json`・`/usage/`とも対象内 |
| defaultブランチとのコンフリクト（`check-base-conflicts.sh`） | `hasConflict: false`（テキストコンフリクト無し・DDR番号重複無し） |
| DDR識別子の命名規則 | `i0103-01`/`i0103-02`とも準拠 |
| `generate-ddr-list.sh`実行後のREADME.md差分 | 追加2行のみ（既存記述への影響無し） |
| frontmatter抽出（`extract-frontmatter.sh`） | 全ラウンドで`failed=0` |
| 敵対的レビュー指摘対応 | 投稿10件・報告7件の計17件すべてに対応し、MRスレッドへ返信済み |

## spec・DDRへの反映先

- `.claude/docs/spec/otel-listener.md`: OTelリスナー機構の仕様一式（背景・仕組み・配置・設定項目・
  出力形式・多重起動防止/デタッチ起動・ベストエフォート方針・既知の制限・配布時の扱い・影響範囲・
  未決定事項）。
- `.claude/docs/ddr/i0103-01-perlを常駐プロセス実装の選択肢に加える理由.md`: perl採用の判断。
- `.claude/docs/ddr/i0103-02-OTelエンドポイント設定をsettings.local.jsonへ分離する理由.md`:
  設定ファイル分離の判断。
- `.claude/docs/spec/shell-scripts.md`: 常駐プロセスが必要な場合の第三の選択肢としてperlを追加。

## 残課題

- WSL実機でのe2e検証と、Claude Code本体からの実際の結線確認は、ユーザー側での検証に委ねる
  （フェーズ3レビューで合意済み）。
- 配布先での既定動作（テレメトリ収集がデフォルトON、perlリスナーが明示的なオプトインなしで
  毎セッション起動する）について、明示的なオプトアウト手段は未定義（`otel-listener.md`
  「未決定事項」に明記済み）。
- 対応工数レポートの集計元をテレメトリへ置き換える対応は、今回のスコープ外のまま。関連issue #105
  （Gemini CLI側の同種対応）へマージ前通知を投稿済み。
