---
title: 【調査】Gemini CLIテレメトリ出力形式と統合方針
type: plan
description: issue #105のフェーズ2個別調査計画。Gemini CLI公式テレメトリの出力形式・出力先配置・差分カーソル単位・二重計上回避方針・logPrompts既定・既定有効化可否・ローテーション方針を調査する計画
tags: [gemini-cli, telemetry, usage-report, issue-105, investigation]
keywords: [OpenTelemetry, outfile, target-local, FileSpanExporter, gemini_cli.api_response, logPrompts, 二重計上, otel-listener, TelemetrySettings, ローテーション]
---

# 【調査】Gemini CLIテレメトリ出力形式と統合方針

## 目的

全体作業計画（`plans/squishy-painting-coral.md`）のフェーズ2に定めた7項目を調査し、フェーズ3
（設計・実装）の判断材料を揃える。実装は本計画の対象外（「これから何を調べるか」のみを書き、
調査結果は `reports/` へ記録する。`.claude/skills/issue-mr-flow/SKILL.md`「計画と実施結果の分離」）。

## 変更対象

コード変更なし。調査のみ。読む対象は次のとおり。

- issue #105 本文（Gemini CLI公式テレメトリの設定キー・イベント属性の一次情報）
- `.claude/docs/spec/otel-listener.md`（issue #103、Claude Code側OTel機構の仕様。出力先命名・
  設定分離パターンの比較対象）
- `.claude/docs/spec/issue-mr-workflow.md`「対応工数レポート」節・「Gemini CLI経路（issue #97）」節
- `.claude/hooks/lib/UsageTracking.sh`（`_sync_usage_state_gemini` / `_usage_gemini_fold` 系の
  既存実装。統合方針の検討対象）
- `.claude/docs/ddr/i0097-01`〜`i0097-05`、`i0103-01`〜`i0103-02`
- Gemini CLI公式ドキュメント（doc-search・WebSearch等、アクセス可能な手段で確認できる範囲）

## 方針

1. **出力ファイル形式の確認**: issue本文の記載（`FileSpanExporter`/`FileLogExporter`/
   `FileMetricExporter`が`outfile`へ直接書き出す）を一次情報とし、可能ならWebSearchで
   Gemini CLI公式ドキュメント（`docs/cli/telemetry.md`相当）を確認する。実機（Gemini CLI起動）
   での検証はこの実行環境で実施できるかを最初に判定し、できなければ「未検証」と明示する。
2. **出力先配置の比較**: issue #103の`usage/claude-otel-YYYYMMDD.jsonl`という命名・日次
   ローテーションのパターンと、Gemini側（`outfile`は単一ファイル固定パスを指定する方式である
   可能性が高い）の制約を突き合わせ、整合させるか・させない場合の理由を判定する。
3. **差分カーソル単位の判定**: 出力ファイルが追記型で1行1JSON（OTLPペイロード）なら行カーソル
   方式が使えるか、Claude Code経路（issue #37）・Gemini CLIセッションログ経路（issue #97の
   畳み込み方式）のどちらに近いかを判定する。同一イベントの後埋め（トークンの遅延反映等）が
   起きるかを、issue本文のイベント属性（`input_token_count`等）から推測する。
4. **二重計上回避方針**: 既存のトークン列判別ロジック（`thoughts`キーの有無で判定、DDR
   i0097-03）に、テレメトリ由来の列をどう追加すれば衝突しないかを検討する。セッションログ由来
   （issue #97）とテレメトリ由来のどちらを正とするか、または併記するかを判定する
   （issue #105受け入れ条件6）。
5. **`logPrompts`の扱い**: 既定`true`のリスク（プロンプト本文の平文出力）を確認し、既定値を
   `false`にするか、`.gemini/settings.json`への追記時にどう明記するかを判定する。
6. **既定有効化の可否**: `.gemini/settings.json`は利用者全員に影響する共有ファイルであるため、
   `telemetry.enabled`を既定でONにするか、任意設定（ドキュメント案内のみ）に留めるかを判定する。
   issue #103（Claude Code側）が既定ONを選んだ理由・トレードオフを参考にする。
7. **ローテーション方針**: `outfile`が単一ファイル固定パスの場合、無制限増大への対処
   （エクスポート間隔設定、または本機構側での日次ローテーション実装の要否）を判定する。

## やらないこと

- 実装（`.gemini/settings.json`の変更、集計ロジックの追加）はフェーズ3で行う。
- Gemini CLI本体への変更提案は行わない（外部プロジェクト）。

## 検証手順

- 各判断項目について、根拠（issue本文の引用・既存spec/DDRの参照・実機検証の有無）を
  `reports/` へ記録し、フェーズ3の個別作業計画の設計判断として引用できる形にする。
