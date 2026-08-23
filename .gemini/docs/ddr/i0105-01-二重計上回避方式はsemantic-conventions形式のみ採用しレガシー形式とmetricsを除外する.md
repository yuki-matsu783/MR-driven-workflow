---
title: i0105-01. 二重計上回避方式はsemantic conventions形式のみ採用しレガシー形式とmetricsを除外する
type: ddr
description: Gemini CLI公式テレメトリの同一イベント2重emit（レガシー形式・semantic conventions形式）とmetricsの周期exportに対し、semantic conventions形式のログのみを採用しレガシー形式・metricsを構造的に除外することで二重計上を避ける判断
tags: [gemini-cli, telemetry, ddr, usage-report]
keywords: [semantic conventions, gen_ai, toLogRecord, toSemanticLogRecord, metrics, 二重計上, 重複排除]
---

# i0105-01. 二重計上回避方式はsemantic conventions形式のみ採用しレガシー形式とmetricsを除外する

## 背景

issue #105で、Gemini CLI公式のOpenTelemetryテレメトリ（`outfile`への直接書き出し）を対応工数
レポートへ統合するにあたり、フェーズ2の調査（`google-gemini/gemini-cli`のGitHub公式ソースを
WebSearch/WebFetch経由で確認）で、テレメトリの出力に次の性質があることが判明した。

- `gemini_cli.api_response`相当のイベントは、**同一の呼び出しに対して常に2つの形式で
  emitされる**: レガシー形式（`toLogRecord`）とsemantic conventions形式
  （`toSemanticLogRecord`、属性キーに`gen_ai.`プレフィックスを持つ）。
- metricsレコードは**周期export**される（間隔の具体値は未確認。本リポジトリの
  `.claude/settings.json`が**Claude Code向けに**設定する`OTEL_METRIC_EXPORT_INTERVAL: "10000"`
  との混同を避けるため、Gemini CLI側の値としては数値を明記しない）。トークン数の生データは
  ログ側の`api_response`イベントにも含まれるため、metricsとログの両方を対応工数として計上すると
  独立した二重計上経路になる。

素朴に「outfile内の全エントリを集計する」実装では、両方の性質がそのまま二重計上に直結する。

## 決定

**semantic conventions形式（`gen_ai.`属性を持つ）のログレコードのみを対応工数の一次情報として
採用し、レガシー形式・metricsレコードはいずれも集計対象から構造的に除外する。**

`_usage_otel_fold`（`.claude/hooks/lib/UsageTracking.sh`）は、次の2段階のフィルタで実現する。

1. `is_metric_record`（`dataPoints`/`sum`/`gauge`/`histogram`/`scopeMetrics`/`resourceMetrics`
   のいずれかのフィールドを持つレコード）に一致するものを除外する。
2. 残ったログレコードのうち、`is_semantic_api_response`（`attributes`が`gen_ai.`プレフィックス
   を持つキーを含み、かつイベント名が`gemini_cli.api_response`と厳密一致するもの）に一致する
   ものだけを採用する。

## 理由

### レガシー形式との重複排除には「常に一方だけを見る」が最も単純で頑健

同一イベントが2形式でemitされる以上、二重計上を避けるには次のいずれかが必要になる。

- (a) 両形式を採用しつつ、イベント単位の一意キーで重複排除する。
- (b) 一方の形式だけを常に採用する。

(a)は「イベントを一意に識別するキー」をレガシー形式・semantic conventions形式の両方から
安定して取り出せることが前提になるが、フェーズ2調査時点でこの一意キーの実在・安定性は
確認できていない。**キーが取り出せない、または形式間で一致しないケースが1つでもあれば、
その回だけ二重計上または過小計上が起きる。**

(b)は前提を必要としない。**片方の形式を最初から見なければ、境界（差分読み取りウィンドウの
切れ目）をまたいでも原理的に二重計上が起きない**（(a)は境界をまたいだ場合、片方の形式が今回、
もう片方が次回の差分に分かれて現れると重複排除のための状態を余分に持つ必要が生じる）。

### semantic conventions形式を選ぶ理由

レガシー形式・semantic conventions形式のどちらを残すかは、属性名の裏取りしやすさで決めた。
`gen_ai.request.model`・`gen_ai.usage.*`はOpenTelemetryのsemantic conventions（gen_ai）を
参考にした命名であり、レガシー形式の属性名（`toLogRecord`側の独自命名）よりも外部の仕様と
突き合わせやすい。ただし**いずれの属性名も実データでの裏取りはできていない**
（`.claude/docs/spec/gemini-cli-telemetry.md`「未決定事項・懸念点」）。

### metricsは除外する

metricsは周期exportであり、対応工数（実際に何回APIを呼んだか・何トークン使ったか）という
呼び出し単位と対応しない。ログ側の`api_response`イベントが呼び出し単位の一次情報を持つため、
metricsは対応工数の計上には使わず、単純に集計対象から除外する。

## 却下した案

| 案 | 却下理由 |
|---|---|
| 両形式を採用し、イベント一意キーで重複排除する | 一意キーの実在・形式間での安定した一致が実データで未確認。取り出せない・一致しないケースが二重計上または過小計上に直結する。実装も状態（見たイベントの集合）を持つ必要があり複雑化する |
| レガシー形式のみを採用する | 属性名（`toLogRecord`側の命名）が、semantic conventions形式の`gen_ai.*`ほど外部仕様と突き合わせて確認できていない |
| metricsも採用し、ログ側と付き合わせて整合性チェックに使う | 対応工数レポートの目的（トークン・呼び出し回数の参考値提示）に対し過剰な複雑さであり、周期exportと呼び出し単位のログでは単位が異なり単純な突き合わせができない |

## 影響

- `.claude/hooks/lib/UsageTracking.sh`の`_usage_otel_fold`（`is_metric_record`/
  `is_semantic_api_response`）。
- 仕様: `.claude/docs/spec/gemini-cli-telemetry.md`「二重計上回避」節。
- 前提となる出力形式（2重emit・metricsの周期export）自体が実データ未確認のため、実機確認が
  得られた場合はこのDDRの前提から見直す必要がある（`.claude/docs/spec/gemini-cli-telemetry.md`
  「未決定事項・懸念点」）。
