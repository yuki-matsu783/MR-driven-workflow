---
title: worklog 20260823 humming-mapping-pie 【調査】OTelリスナー機構の設計論点調査 push2
type: log
description: issue #103のOTelリスナー機構の設計論点調査（flow-id 2-1〜）の試行錯誤ログ
tags: [otel, telemetry, usage, perl, worklog]
keywords: [OpenTelemetry, OTLP, session-id, perl, ポート, 調査]
---

# worklog: 【調査】OTelリスナー機構の設計論点調査

対象: issue #103のOTLPリスナー機構実装に向けた設計論点の調査（2026-08-23）。
全体作業計画: `plans/humming-mapping-pie.md`
個別作業計画: `plans/【調査】OTelリスナー機構の設計論点調査.md`
push回数: 2

## 試したこと

- `参考ディレクトリ/otel/`の全ファイル（README.md/listener.py/session-start.sh/listener.ps1/
  session-start.ps1）を読み、対応表方式・`session.id`全走査・多重起動防止・デタッチ起動の
  設計を把握した。
- `.claude/rules/directory-structure.md`「配置の指針」節を再読し、`.claude/scripts/src/`と
  `.claude/hooks/`の境界を確認した。
- `.claude/settings.json`の現在の`hooks`/`env`/`permissions`セクションをjqで抽出して確認した。
- perlのHTTP/1.1最小パーサ（`IO::Socket::INET`）を検証コードとしてscratchpad配下に書き、
  バックグラウンド起動して`curl`で3種類のリクエスト（正常JSON・空JSON・不正JSON）をPOSTし
  応答を確認した。
- `session.id`全走査ロジックを`SessionIdFinder.pm`として純粋関数に切り出し、`Test::More`で
  単体テストを書いて実行した。
- `wsl.exe -l -v`でWSL(Ubuntu)が利用可能なことを確認し、`wsl.exe -e perl ...`でWSL側のperl
  バージョン・コアモジュール（IO::Socket::INET/JSON::PP/Test::More/POSIX）を確認した。
- git bash・WSL双方で`setsid`/`nohup`/`/dev/tcp/...`疑似デバイスの利用可否を`command -v`と
  実際の接続試行で確認した。
- `usage/`配下に空ファイルを作って`git check-ignore -v`で除外パターンを確認した。

## うまくいったこと

- perlのHTTP/1.1最小パーサは初回の実装でそのまま動作した（`Content-Length`を読んでbodyを
  受け取る方式で、不正なJSONでも`eval`で捕捉してクラッシュしない）。
- WSL側のperlバージョン・コアモジュール確認は、初回の`wsl.exe`呼び出しで
  `Wsl/Service/0x8007274c`という文字化けしたエラー（WSLサービスのコールドスタート起因と
  推定）が一部のモジュールで出たが、再試行したら成功した。1回の失敗だけで「利用不可」と
  結論づけず、再試行する判断が奏功した。
- `usage/`配下の新設ファイルは既存`.gitignore`の`/usage/`パターンでそのまま除外されることを
  確認でき、追加のignoreルールが不要と分かった。

## ダメだったこと

- Windows側git bash（MSYS）には`setsid`コマンドが存在しなかった（`command -v setsid`が
  exit 1）。参考実装の`session-start.sh`が使う`setsid nohup … & disown`はそのまま移植できず、
  Windows側は`setsid`を省いた形にする必要があると判明した。
- 「ワークスペースごとに動的ポート割り当て」案を当初検討したが、OTLPエクスポート先は
  Claude Code起動時に`.claude/settings.json`から静的に読まれるため、SessionStartフック側で
  動的に決めたポートを後から反映する手段が無く、実現不可能と判断して却下した。

## 次の一歩

- 調査結果を`reports/20260823_humming-mapping-pie_OTel設計論点調査.md`（および同名html）に
  まとめた。flow-id 2-7でcommitし、pushしてレビュー依頼を行う。

---
