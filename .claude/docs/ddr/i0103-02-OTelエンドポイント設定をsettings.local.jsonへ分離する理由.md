---
title: i0103-02. OTelエンドポイント設定をsettings.local.jsonへ分離する理由
type: ddr
description: OTelリスナー機構（issue #103）の環境依存設定（OTEL_EXPORTER_OTLP_ENDPOINT等）を、共有の.claude/settings.jsonではなくGit管理外の.claude/settings.local.jsonへ分離した決定。環境ごとに別ポートを割り当てる要求と、単一の共有設定ファイルの制約が両立しないため。
tags: [otel, telemetry, settings, windows, wsl]
keywords: [OTEL_EXPORTER_OTLP_ENDPOINT, settings.local.json, ポート, 環境分岐, プロジェクトスコープ]
---

# i0103-02. OTelエンドポイント設定をsettings.local.jsonへ分離する理由

issue #103（Claude CodeのOpenTelemetry出力をローカルで受信し、ワークスペースの`usage/`配下へ
振り分けて保存する機構を追加する）での決定。

## 決定

Claude Codeのテレメトリ関連`env`設定のうち、**環境に依存しない値**
（`CLAUDE_CODE_ENABLE_TELEMETRY`・`OTEL_METRICS_EXPORTER`・`OTEL_LOGS_EXPORTER`・
`OTEL_EXPORTER_OTLP_PROTOCOL`・`OTEL_METRIC_EXPORT_INTERVAL`・
`OTEL_METRICS_INCLUDE_ENTRYPOINT`）は共有の`.claude/settings.json`（Git管理下）に置き、
**環境に依存する値**（`OTEL_EXPORTER_OTLP_ENDPOINT`・`OTEL_RESOURCE_ATTRIBUTES`）は
`.claude/settings.local.json`（Claude Code標準のローカルオーバーライド設定、`.gitignore`
対象）に分離する。後者はテンプレート`.claude/settings.local.json.example`をコピーして
利用者ごとに作成する。

## 背景

issue期待する動作5は「WSLはWindows側の同一ポート番号を占有するため、環境ごとに別ポートを
割り当てる」ことを求めている。一方、フェーズ2の調査（`reports/20260823_humming-mapping-pie_
OTel設計論点調査.md`）では「設定はプロジェクトスコープの`.claude/settings.json`で完結可能」
と結論していた。フェーズ3の個別作業計画作成中に、**この2つが両立しないこと**が判明した。

- `.claude/settings.json`はリポジトリに1つしか無く、Git管理下でWindows/WSL間で共有される。
- しかし`OTEL_EXPORTER_OTLP_ENDPOINT`はOS（正確にはClaude Codeがどちらの環境で起動している
  か）によって異なる値（Windows: `http://localhost:4318`、WSL: `http://localhost:4319`）を
  持つ必要がある。
- 単一の共有JSONファイルには、1つのキーに対して1つの値しか持てない。

Claude Codeは`.claude/settings.local.json`という、プロジェクトスコープの`.claude/
settings.json`に対するローカルオーバーライド設定を標準でサポートしており、**Git管理外
（`.gitignore`対象）** である。この仕組みを使うことで、環境依存の値だけを各利用者のローカル
環境ごとに設定できる。

## 期待する動作6との整合性

issue期待する動作6は「可能な限りリポジトリ内で完結（ユーザーホーム外への書き込みを避ける）」
ことを求めている。`.claude/settings.local.json`は**プロジェクトディレクトリ直下**（リポジトリ
のワーキングツリー内）に置かれるファイルであり、Git管理下に無いだけでユーザーホームへの
書き込みは発生しない。したがって、この決定は期待する動作6の趣旨（ユーザーホームへ設定を
分散させない）を損なわない。

## 却下した案

- **単一の`.claude/settings.json`にすべてを書く**: Windows/WSL間でポートを分けられず、
  issue期待する動作5に反する。
- **ユーザーホームの`~/.claude/settings.json`に環境依存設定を置く**（参考実装
  `参考ディレクトリ/otel/README.md`のまま）: リポジトリ外（ユーザーホーム）への書き込みが
  発生し、issue期待する動作6に反する。
- **`.claude/settings.json`をOSごとに2ファイル用意し、シンボリックリンク等で切り替える**:
  Windows/WSL間でファイルシステムが異なり（NTFS junctionがWSL側から見えない等、`.claude/
  rules/directory-structure.md`「配置の指針」の`.gemini/`と同種の問題）、両OSで確実に動く
  切り替え機構を新たに作る必要があり、標準機能の`.claude/settings.local.json`を使う方が
  シンプル。
