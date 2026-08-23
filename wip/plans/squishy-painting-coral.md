---
title: Gemini CLIのテレメトリをローカルファイルへ出力し、push毎に集計して対応工数レポートへ加える（全体作業計画）
type: plan
description: issue #105 の全体作業計画。Gemini CLI公式のOpenTelemetryテレメトリをusage/配下のローカルファイルへ出力させ、push毎に差分集計して対応工数レポートへ統合するまでの、調査・作業・反映の3フェーズを定義する
tags: [gemini-cli, telemetry, usage-report, issue-105]
keywords: [OpenTelemetry, outfile, FileSpanExporter, usage対応工数レポート, gemini-totals, DDR, otel-listener, 二重計上, logPrompts]
---

# Gemini CLIのテレメトリをローカルファイルへ出力し、push毎に集計して対応工数レポートへ加える（全体作業計画）

## Context

issue #97 で、Gemini CLIの**セッションログ**（`~/.gemini/tmp/<hash>/chats/*.jsonl`）を対応工数
レポートの集計対象に加える対応が完了した（`_usage_gemini_fold` 系、`UsageTracking.sh`）。この
セッションログは Gemini CLI の非公開・内部フォーマットであり、将来のバージョン変更で集計が壊れる
リスクがある（Claude Code側の同じ懸念は DDR i0000-04 に記録済み）。

本issue #105 は、この非公開フォーマット依存に対して**Gemini CLI公式のテレメトリ経路
（OpenTelemetry。`.gemini/settings.json` の `telemetry.enabled: true` / `target: "local"` /
`outfile: <パス>`）を並行して確保する土台**を作る。Claude Code側の同種の機構は issue #103
（`.claude/hooks/otel/` の常駐perlリスナー）が実装済みだが、Gemini CLIは `outfile` でファイルへ
**直接書き出せる**ため、常駐リスナーが不要という大きな違いがある。

得られたテレメトリ由来の値を push毎に差分集計し、対応工数レポート
（`.claude/hooks/post-push-usage-report.sh`）へ反映する。**セッションログ由来（issue #97）の
トークンとテレメトリ由来のトークンが二重計上されないこと**が本issueの核心的な受け入れ条件である。

## 事前調査で判明した前提（詳細調査はフェーズ2で行う）

- `.claude/hooks/lib/UsageTracking.sh`: `sync_usage_state` が第5引数 `engine` で
  `_sync_usage_state_gemini`（Gemini経路）と Claude Code経路を分岐する既存構造がある
  （`.claude/hooks/lib/UsageTracking.sh:859-934`）。Gemini経路は行カーソルを使わず、
  ファイル全体を `id` 単位で畳み込んで前回累計との差分を取る方式（DDR i0097-01）。
  **この既存のGemini経路は「セッションログ」専用であり、本issueが対象とする「公式テレメトリ
  ファイル」とは入力データソースが別物**。両者の統合方法（同じ `_usage_gemini_fold` 系に
  相乗りさせるか、独立した集計経路にするか）はフェーズ2の調査事項。
- `.gemini/settings.json` には現状 `env`/`telemetry` キーが無い（`hooks` 登録のみ）。
- `usage/state/gemini-totals/<sessionId>.json`（ブランチ非依存の前回累計置き場）は既存パターンとして
  参考にできるが、テレメトリ由来の前回累計は**別ファイル・別ディレクトリ**に置く必要がある
  （同じキーへ異なる意味の値を混在させない、という `.claude/docs/spec/issue-mr-workflow.md` の
  既存方針に倣う）。
- issue #103（Claude Code OTel、`.claude/docs/spec/otel-listener.md`）の出力先命名は
  `usage/claude-otel-YYYYMMDD.jsonl`。本issueはこれと**整合させるか、しない理由を記録する**ことが
  受け入れ条件。Gemini側は常駐リスナーが無い分、`outfile` の指すファイルが直接 `usage/` 配下に
  作られる設計になる見込み（例: `usage/gemini-otel-YYYYMMDD.jsonl` 等。命名はフェーズ3で確定）。
- `.claude/scripts/test/test_usage_tracking.sh`（478行）が唯一の対象単体テストファイル。実jqを
  フィクスチャに対して直接実行する方式（jqスタブ無し）。同じパターンに合わせてテストを追加する。
- issue本文には Gemini CLI 側の設定キー・イベント属性（`gemini_cli.api_response` の
  `model`/`input_token_count`/`output_token_count`/`cached_content_token_count`/
  `thoughts_token_count`/`tool_token_count`/`total_token_count`/`duration_ms`/`status_code`等）が
  一次情報として記載されている。実機（Gemini CLI）でのファイル出力形式の実測は、この実行環境に
  参考実装ディレクトリが無いため**実施できない可能性が高く、その場合は「未検証」と明示する**
  （issue本文の受け入れ条件どおり）。

## issueの分割要否判定（issue #64基準）

本issueの受け入れ条件8項目は「テレメトリ出力設定 → push毎の差分集計 → レポート反映」という
**1本のパイプラインの各段階に対する設計判断**であり、画面・API・CLIサブコマンドのような
「同種成果物の並列列挙」には該当しない。各段階は単独でマージしても意味を持たない
（例: 出力設定だけ入れて集計・反映が無い状態は receiver のない発信に過ぎない）。
**分割は提案せず、1issue・1MRで進める。**

## フェーズ2〈調査〉

- Gemini CLI公式テレメトリの出力ファイル形式を確認する（1行1JSON/OTLPペイロードそのもの/
  spans・logs・metricsが同一ファイルに混在するか等）。実機検証できるかを最初に判定し、できなければ
  issue本文の記載とGemini CLI公式ドキュメント（doc-search・WebSearch等、アクセス可能な手段）を
  一次情報として扱い、その旨を明示する。
- 出力先ディレクトリの配置案を、issue #103（`usage/claude-otel-YYYYMMDD.jsonl`）と比較し、
  整合させるか・させない場合の理由を決める。
- 差分カーソルの単位（ファイル形式に応じて、行カーソル方式が使えるか、Gemini経路の既存の
  「畳み込み」方式が必要か）を決める。
- トークンの情報源の二重化（セッションログ由来 vs テレメトリ由来）への対処方針を決める
  （既存のトークン列は `thoughts` キーの有無で判別しているため、テレメトリ由来の列をどう追加・
  区別するかを含む）。
- `logPrompts` の既定値の扱い（機微情報）を決める。
- `.gemini/settings.json` を変更した場合の影響範囲（利用者全員への影響）を踏まえ、既定で有効化する
  か・任意設定として案内するに留めるかを決める。
- 出力ファイルの増大への対処方針（エクスポート間隔・ローテーション要否）を決める。

成果物: `plans/【調査】Gemini-CLIテレメトリ出力形式と統合方針.md` と `reports/` への調査結果記録。

## フェーズ3〈作業〉

調査結果をもとに、少なくとも以下を実施する見込み（確定はフェーズ2完了後）。

- `.gemini/settings.json` へ `telemetry` 設定を追加（`target: "local"` 固定、`outfile` は
  `usage/` 配下）。
- `UsageTracking.sh` （または新規ファイル）へ、テレメトリファイルの差分集計ロジックを追加する。
- `post-push-usage-report.sh` からの呼び出しに統合し、レポート本文へテレメトリ由来の値を追加する
  （二重計上防止の検証を含む）。
- `.claude/scripts/test/test_usage_tracking.sh`（または新規テストファイル）に単体テストを追加し、
  `passed=N failures=N` を確認する。
- 機微情報の扱い（`logPrompts` 既定・`.gitignore` 対象であること）をドキュメント化する。

成果物: `plans/【設計】【実装】【テスト】〜.md`（種別は調査結果を見て確定。必要なら分割）、
`reports/` への作業結果記録。

## フェーズ4〈反映〉

- 設計反映: `.claude/docs/spec/otel-listener.md` への追記、または新規spec
  （Gemini CLI公式テレメトリ機構の仕様）を作成し、`.claude/docs/README.md` の一覧に載せる。
- DDR記録: 出力先配置・`logPrompts`既定・差分カーソル単位・トークン正情報源・既定有効化可否の
  各判断を `.claude/docs/ddr/i0105-XX-〜.md` として記録する。
- AIアセット反映: 作業中に気づいたルール・スキルの不備があれば反映する。
- 反映対象の洗い出しは flow-id 4-1 で行う（本節は枠のみ）。

## 検証方法

- `.claude/scripts/test/test_usage_tracking.sh` を実行し `passed=N failures=N`（failures=0）を確認。
- 既存のClaude Code経路・Gemini CLIセッションログ経路（issue #97）の集計結果・レポート内容が
  変化しないことを、既存テストの全件成功で確認する。
- 実機（Gemini CLI）での検証はこの実行環境では実施できない可能性が高い。できない場合はその旨を
  spec・reportsに明示する。
