---
title: 【設計反映】OTelリスナー機構のDDR_spec新設
type: plan
description: issue #103のフェーズ4個別反映計画。フェーズ2・3で確定した設計判断をDDR・specへ反映する
tags: [otel, telemetry, usage, perl, ddr, spec]
keywords: [OpenTelemetry, DDR, spec, settings.local.json, 設計反映, i0103]
---

# 【設計反映】OTelリスナー機構のDDR_spec新設

対象: issue #103。全体作業計画 `plans/humming-mapping-pie.md` のフェーズ4（設計反映）。
前提: `reports/20260823_humming-mapping-pie_OTel設計論点調査.md`（フェーズ2）、
`reports/20260823_humming-mapping-pie_OTelリスナー機構の実装.md`（フェーズ3）。

`.claude/rules/docs-workflow.md`「`【設計反映】`と`【AIアセット反映』は基本的に併記せず分ける」
方針に従い、AIアセット反映（`.claude/rules/`への追記）は別計画
`plans/【AIアセット反映】OTelリスナー機構のルール反映.md`に分ける。

## 目的

フェーズ2・3で確定した設計判断のうち、恒久的に参照される意思決定（DDR）と現在の仕様
（spec）として記録すべきものを、それぞれ`.claude/docs/ddr/`・`.claude/docs/spec/`へ反映する。

## 反映対象の洗い出し

### DDR新規作成（2件）

| 識別子 | タイトル | 内容 |
|---|---|---|
| `i0103-01` | perlを常駐プロセス実装の選択肢に加える理由 | `HTTP::Daemon`はコア添付ではなくインストールが必要なため、`IO::Socket::INET`での自前HTTP/1.1最小パーサを採用した理由。`.claude/rules/shell-script-style.md`の既存方針「bashで実現できないものだけPowerShellへ」に「常駐プロセスが必要な場合はperl」という枝を追加する判断として記録する。却下案: Python/PowerShell（参考実装のまま。追加インストールが要る／Windows専用で環境非依存にならない） |
| `i0103-02` | OTelエンドポイント設定を`.claude/settings.local.json`へ分離する理由 | issue期待する動作5（環境ごとに別ポート）とプロジェクトスコープ`.claude/settings.json`（単一・共有）の両立が不可能だったため、環境依存の値だけを`.claude/settings.local.json`（Git管理外）へ分離した判断。却下案: ユーザーホームの`~/.claude/settings.json`（参考実装のまま。リポジトリ内で完結という受け入れ条件に反する） |

### spec新規作成（1件）

`.claude/docs/spec/otel-listener.md`: OTelリスナー機構の仕様。以下を含む。

- 背景・目的（既存の対応工数レポート DDR i0000-04 との関係: 置き換えではなく並行経路の追加）
- 仕組み（対応表・session.id全走査・unrouted退避・多重起動防止・デタッチ起動の環境分岐）
- 配置（`.claude/hooks/otel/`配下のファイル構成）
- 設定項目（`.claude/settings.json`の`env`・`.claude/settings.local.json`の環境依存項目）
- 出力形式（対応表`sessions.jsonl`のschemaVersion付きフォーマット、
  `usage/claude-otel-YYYYMMDD.jsonl`、共有位置の`unrouted-YYYYMMDD.jsonl`）
- 既知の制限（起動直後数秒の取りこぼし、cwd変更への非追従、無限に伸びるファイル、
  WSL実機検証・Claude Code結線確認はユーザー側検証に委ねたこと）
- 導入手順は`DEVELOPERS.md`を参照（specでは重複記載しない）

## やらないこと

- AIアセット反映（`.claude/rules/directory-structure.md`・`.claude/rules/shell-script-style.md`
  への追記）は別計画`plans/【AIアセット反映】OTelリスナー機構のルール反映.md`で扱う。
- 対応工数レポートの実装変更（DDR i0000-04で決めたtranscriptパース方式は変更しない。
  issue期待する動作9で明示的にスコープ外）。

## 検証手順

- DDR識別子`i0103-01`/`i0103-02`が、`.claude/rules/markdown-frontmatter.md`「DDRの識別子」の
  命名規則（`i<issue番号4桁>-<枝番2桁>-<タイトル>.md`）に従っているか確認する。
- DDR・spec新設後、`bash .claude/scripts/src/generate-ddr-list.sh`を実行し、
  `.claude/docs/README.md`のDDR一覧の差分を確認する。
- specのfrontmatter（`type: spec`）が`.claude/rules/markdown-frontmatter.md`の規約に沿っているか確認する。

## 主要ファイル

- `.claude/docs/ddr/i0103-01-perlを常駐プロセス実装の選択肢に加える理由.md`（新規）
- `.claude/docs/ddr/i0103-02-OTelエンドポイント設定をsettings.local.jsonへ分離する理由.md`（新規）
- `.claude/docs/spec/otel-listener.md`（新規）
- `.claude/docs/README.md`（DDR一覧、`generate-ddr-list.sh`で再生成）
- `.claude/docs/ddr/i0000-04-対応工数レポートはtranscript自前パースで実装する.md`（関係整理の参照先）
