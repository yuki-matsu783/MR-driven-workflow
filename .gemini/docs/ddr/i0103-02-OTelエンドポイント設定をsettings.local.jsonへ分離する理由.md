---
title: i0103-02. OTelエンドポイント設定をsettings.local.jsonへ分離する理由
type: ddr
description: OTelリスナー機構の環境依存設定（OTEL_EXPORTER_OTLP_ENDPOINT等）を、共有の.claude/settings.jsonではなくGit管理外の.claude/settings.local.jsonへ分離した決定。環境ごとに別ポートを割り当てる要求と、単一の共有設定ファイルの制約が両立しないため。
tags: [otel, telemetry, settings, windows, wsl]
keywords: [OTEL_EXPORTER_OTLP_ENDPOINT, settings.local.json, ポート, 環境分岐, プロジェクトスコープ]
---

# i0103-02. OTelエンドポイント設定をsettings.local.jsonへ分離する理由

Claude Code公式のOpenTelemetry（OTLP）出力をローカルで受信し、`session.id`属性からセッションの
出力先ワークスペースを引いて`usage/`配下へ振り分け保存する機構（詳細:
[otel-listener.md](../spec/otel-listener.md)）で、環境依存の設定をどこに置くかの決定。

## 決定

Claude Codeのテレメトリ関連`env`設定のうち、**環境に依存しない値**
（`CLAUDE_CODE_ENABLE_TELEMETRY`・`OTEL_METRICS_EXPORTER`・`OTEL_LOGS_EXPORTER`・
`OTEL_EXPORTER_OTLP_PROTOCOL`・`OTEL_METRIC_EXPORT_INTERVAL`・
`OTEL_METRICS_INCLUDE_ENTRYPOINT`）は共有の`.claude/settings.json`（Git管理下）に置き、
**環境に依存する値**（`OTEL_EXPORTER_OTLP_ENDPOINT`・`OTEL_RESOURCE_ATTRIBUTES`・
`OTEL_USAGE_PORT`）は`.claude/settings.local.json`（Claude Code標準のローカル
オーバーライド設定、`.gitignore`対象）に分離する。後者はテンプレート
`.claude/settings.local.json.example`をコピーして利用者ごとに作成する。

## 背景

本機構は、WindowsとWSLが127.0.0.1を共有しつつ別プロセス空間で動くため、同じポート番号を
使うと双方のリスナーを同時に立てられないという制約から、**環境ごとに別ポートを割り当てる**
必要がある。事前調査の時点では「設定はプロジェクトスコープの`.claude/settings.json`で完結
可能」という見立てだったが、実装方針を詰める過程で、**この見立てとポートを環境ごとに分ける
要求が両立しないこと**が判明した。

- `.claude/settings.json`はリポジトリに1つしか無く、Git管理下でWindows/WSL間で共有される。
- しかし`OTEL_EXPORTER_OTLP_ENDPOINT`はOS（正確にはClaude Codeがどちらの環境で起動している
  か）によって異なる値（Windows: `http://localhost:4318`、WSL: `http://localhost:4319`）を
  持つ必要がある。
- 単一の共有JSONファイルには、1つのキーに対して1つの値しか持てない。

Claude Codeは`.claude/settings.local.json`という、プロジェクトスコープの`.claude/settings.json`
に対するローカルオーバーライド設定を標準でサポートしており、**Git管理外（`.gitignore`対象）**
である。この仕組みを使うことで、環境依存の値だけを各利用者のローカル環境ごとに設定できる。

## リポジトリ内で完結する方針との整合性

本機構は基本方針として、可能な限りリポジトリ内で完結させ、ユーザーホーム外への書き込みを
避けることを求めている。`.claude/settings.local.json`は**プロジェクトディレクトリ直下**
（リポジトリのワーキングツリー内）に置かれるファイルであり、Git管理下に無いだけでユーザー
ホームへの書き込みは発生しない。したがって、この決定はこの方針の趣旨（ユーザーホームへ設定を
分散させない）を損なわない。

## 却下した案

- **単一の`.claude/settings.json`にすべてを書く**: Windows/WSL間でポートを分けられず、
  環境ごとに別ポートを割り当てる要求に反する。
- **ユーザーホームの`~/.claude/settings.json`に環境依存設定を置く**（移植元実装のまま）:
  リポジトリ外（ユーザーホーム）への書き込みが発生し、リポジトリ内で完結する方針に反する。
- **`.claude/settings.json`をOSごとに2ファイル用意し、シンボリックリンク等で切り替える**:
  Windows/WSL間でファイルシステムが異なり（NTFS junctionがWSL側から見えない等、
  `.claude/rules/directory-structure.md`「配置の指針」の`.gemini/`と同種の問題）、両OSで
  確実に動く切り替え機構を新たに作る必要があり、標準機能の`.claude/settings.local.json`を
  使う方がシンプル。
