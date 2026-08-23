---
title: 【調査】Gemini CLIテレメトリ出力形式と統合方針
type: plan
description: issue #105のフェーズ2個別調査計画。Gemini CLI公式テレメトリの出力形式・出力先配置・差分カーソル単位・二重計上回避方針・logPrompts既定・既定有効化可否・ローテーション方針を調査する計画
tags: [gemini-cli, telemetry, usage-report, issue-105, investigation]
keywords: [OpenTelemetry, outfile, target-local, FileSpanExporter, gemini_cli.api_response, logPrompts, 二重計上, otel-listener, TelemetrySettings, ローテーション]
---

# 【調査】Gemini CLIテレメトリ出力形式と統合方針

## 前提（合意状況）

- 上位の計画: `plans/squishy-painting-coral.md`（全体作業計画、flow-id 1-5 で合意）。
- 依拠する既存の実装・DDR: issue #97（Gemini CLIセッションログ集計、`_usage_gemini_fold`系）、
  issue #103（Claude Code側OTelリスナー、`.claude/docs/spec/otel-listener.md`）。

## この計画で何をするか

全体作業計画（`plans/squishy-painting-coral.md`）のフェーズ2に定めた7項目を調査し、フェーズ3
（設計・実装）の判断材料を揃える。実装は本計画の対象外（「これから何を調べるか」のみを書き、
調査結果は `reports/` へ記録する。`.claude/skills/issue-mr-flow/SKILL.md`「計画と実施結果の分離」）。

## 変更対象

コード変更なし。調査のみ。読む対象は次のとおり。

- issue #105 本文（Gemini CLI公式テレメトリの設定キー・イベント属性の一次情報）
- 現行の `.gemini/settings.json`（`telemetry`をどこへ追加するかの現況確認。既存は
  `general.plan.directory` / `hooks` のみで `env`/`telemetry` キーは無い）
- Gemini CLI公式スキーマ定義（`schemas/settings.schema.json` の `TelemetrySettings`。issue本文が
  参照先として明記。実機・参考実装ディレクトリがこの実行環境に無い場合は公式ドキュメントで代替）
- `.claude/docs/spec/otel-listener.md`（issue #103、Claude Code側OTel機構の仕様。出力先命名・
  設定分離パターンの比較対象）
- `.claude/docs/spec/issue-mr-workflow.md`「対応工数レポート」節・「Gemini CLI経路（issue #97）」節
- `.claude/hooks/lib/UsageTracking.sh`（`_sync_usage_state_gemini` / `_usage_gemini_fold` 系の
  既存実装。統合方針の検討対象）
- `.claude/scripts/test/test_usage_tracking.sh`（既存テストの構成。フィクスチャの妥当化方法の
  参考にする）
- `.claude/docs/ddr/i0097-01`〜`i0097-05`、`i0103-01`〜`i0103-02`
- Gemini CLI公式ドキュメント（doc-search・WebSearch等、アクセス可能な手段で確認できる範囲）

## 方針

1. **出力ファイル形式の確認**: issue本文の記載（`FileSpanExporter`/`FileLogExporter`/
   `FileMetricExporter`が`outfile`へ直接書き出す）を一次情報とし、可能ならWebSearchで
   Gemini CLI公式ドキュメント（`docs/cli/telemetry.md`相当）を確認する。
   - **実機検証可否の判定方法**: `command -v gemini` でGemini CLI本体の有無を確認する
     （この実行環境では未確認だが、実行前に必ず確認する）。無ければ「実施できない」と判定し、
     以降は「未検証」として扱う。
   - **検証不能だった場合の受け入れ条件1の扱い**: 受け入れ条件1「telemetry設定により`usage/`
     配下へファイルが生成・追記される」は実際の生成を求めているため、「未検証」のまま閉じない。
     この実行環境で検証できない場合は、(a) 人間のローカルGemini CLI環境で1回実行し出力を
     採取してもらうことを`reports/`で依頼する、(b) 条件1の実機確認をフェーズ3のレビュー往復
     （3-8/3-9）または人間への依頼へ持ち越す、のいずれかを`reports/`に明記する。
   - **テストフィクスチャの妥当化方法**: 出力形式が実機で確認できない場合、単体テスト
     （受け入れ条件2の検証手段）のフィクスチャは推測に基づくため「緑になること」が実形式を
     保証しない。フィクスチャは (a) 公式ドキュメントに掲載されたサンプル出力、または
     (b) Gemini CLIのエクスポータ実装（OSS）のソースコードが確認できればその構造、のいずれかを
     一次情報として起こし、根拠を`reports/`に明記する。どちらも確認できない場合は、その旨を
     `reports/`に明記したうえで、実機での検証を受け入れ条件2の残課題としてフェーズ5（flow-id
     5-2 相当）またはDDRの未決定事項として記録する。
2. **`.gemini/settings.json`のスキーマ確認（受け入れ条件5）**: 公式スキーマ（`TelemetrySettings`）
   の正しいキー名・ネスト位置（トップレベル`telemetry`か`general`配下か等）・型・必須/任意を
   確認する。現行の`.gemini/settings.json`の既存キー（`general.plan.directory`, `hooks`）と
   衝突しない置き場所を判定する。
3. **出力先配置の比較**: issue #103の`usage/claude-otel-YYYYMMDD.jsonl`という命名・日次
   ローテーションのパターンと、Gemini側の制約を突き合わせ、整合させるか・させない場合の理由を
   判定する。**`outfile`が単一ファイル固定パス指定なのか、ディレクトリ指定・自動命名を持つのかは
   方針1の調査結果で確定する前提とし、いずれの場合の対応も判定項目に含める**
   （単一ファイル固定パスなら本方針の比較軸をそのまま適用、そうでなければissue #103の
   日次ローテーションパターンとの類似度を評価し直す）。
4. **差分カーソル単位の判定**: 出力ファイルが追記型で1行1JSON（OTLPペイロード）なら行カーソル
   方式が使えるか、Claude Code経路（issue #37）・Gemini CLIセッションログ経路（issue #97の
   畳み込み方式）のどちらに近いかを判定する。同一イベントの後埋め（トークンの遅延反映等）が
   起きるかを、issue本文のイベント属性（`input_token_count`等）から推測する。
5. **二重計上回避方針**（受け入れ条件2・3）: 既存のトークン列判別ロジック（`thoughts`キーの
   有無で判定、DDR i0097-03）に、テレメトリ由来の列をどう追加すれば衝突しないかを検討する。
   セッションログ由来（issue #97）とテレメトリ由来のどちらを正とするか、または併記するかを
   判定する。
6. **`logPrompts`の扱い**（受け入れ条件6）: 既定`true`のリスク（プロンプト本文の平文出力）を
   確認し、既定値を`false`にするか、`.gemini/settings.json`への追記時にどう明記するかを判定する。
7. **既定有効化の可否**（受け入れ条件7）: `.gemini/settings.json`は利用者全員に影響する共有
   ファイルであるため、`telemetry.enabled`を既定でONにするか、任意設定（ドキュメント案内のみ）に
   留めるかを判定する。issue #103（Claude Code側）が既定ONを選んだ理由・トレードオフを参考にする。
8. **ローテーション方針**: 方針1・3の結果、出力が単一ファイル固定パスだと判明した場合、
   無制限増大への対処（エクスポート間隔設定、または本機構側での日次ローテーション実装の要否）を
   判定する。ディレクトリ指定・自動命名だった場合は、Gemini CLI側の既定ローテーション有無を
   確認したうえで判定する。

## やらないこと（スコープ外）

- 実装（`.gemini/settings.json`の変更、集計ロジックの追加）はフェーズ3で行う。
- Gemini CLI本体への変更提案は行わない（外部プロジェクト）。

## 検証

```bash
# reports/ に調査結果mdが存在し、7項目それぞれの見出しがあることを確認する
# （先頭がハイフンになりうるパターンには -- を付ける）
report="$(ls reports/*Gemini*出力形式*.md 2>/dev/null | head -1)"
test -n "$report" && echo "found: $report"
for h in "出力ファイル形式" "settings.jsonのスキーマ" "出力先配置" "差分カーソル単位" \
         "二重計上回避" "logPrompts" "既定有効化" "ローテーション"; do
  grep -c -- "$h" "$report"
done
```

合格条件: `reports/` に本計画の8項目（方針1〜8。方針1は出力形式判定と受け入れ条件1の扱いの
両方を含む）それぞれについて、根拠付きの判断（または「未検証」＋代替手段の明示）が記録されて
おり、上記コマンドがすべて1以上を返すこと。

## issueの受け入れ条件との対応

| 受け入れ条件 | この計画での対応箇所 |
|---|---|
| 1. telemetry設定によりusage/配下へファイルが生成・追記される | 方針1（実機検証可否の判定・検証不能時の代替手段） |
| 2. テレメトリ由来の集計値が対応工数レポートへ載り差分が二重計上されない（単体テスト検証） | 方針1（テストフィクスチャの妥当化）・方針4・方針5 |
| 3. issue #97実装のセッションログ集計とテレメトリ集計が二重計上にならない | 方針5 |
| 4. Claude Code側の集計結果・レポート内容が変化せず既存テストが通る | フェーズ3の検証事項（本計画では調査のみ、変更対象に含めない） |
| 5. `.gemini/settings.json`がTelemetrySettingsスキーマに沿っている | 方針2 |
| 6. `logPrompts`の既定・出力先がgitignore対象であることが明記されている | 方針6 |
| 7. 出力先配置がissue #103と整合している、または整合しない理由が記録されている | 方針3 |
| 8. 設計判断がDDRとして記録されている | フェーズ4（本計画の対象外。方針2/3/5/6/7/8の判断結果がDDR化対象） |
| 9. 仕様がspecに記録されている、実機検証できない範囲は「未検証」と明示されている | 方針1・フェーズ4（本計画は「未検証」の判定・記録方法までを扱う） |
