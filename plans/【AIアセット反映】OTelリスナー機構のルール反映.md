---
title: 【AIアセット反映】OTelリスナー機構のルール反映
type: plan
description: issue #103のフェーズ4個別反映計画。OTelリスナー機構の実装で得た知見を.claude/rules/へ反映する
tags: [otel, telemetry, perl, ai-asset]
keywords: [directory-structure, shell-script-style, Test::More, TAP, AIアセット反映]
---

# 【AIアセット反映】OTelリスナー機構のルール反映

対象: issue #103。全体作業計画 `plans/humming-mapping-pie.md` のフェーズ4（AIアセット反映）。
前提: `plans/【設計反映】OTelリスナー機構のDDR_spec新設.md`の完了・レビュー後に着手する
（`.claude/rules/docs-workflow.md`「設計反映を完了・レビューしてからAIアセット反映に着手する」
方針）。

## 目的

OTelリスナー機構の実装で得た知見のうち、今後のAI作業一般に関わる運用ルールを
`.claude/rules/`へ反映する。

## 反映対象の洗い出し

| 対象ファイル | 反映内容 |
|---|---|
| `.claude/rules/directory-structure.md` | 「配置の指針」節に、`.claude/hooks/`配下へ常駐プロセス用のサブディレクトリ（`.claude/hooks/otel/`のような`lib/`・`test/`を持つ構成）を新設してよい旨を追記。`usage/`節の説明に、OTelリスナー機構が出力する`claude-otel-YYYYMMDD.jsonl`の存在を追記 |
| `.claude/rules/shell-script-style.md` | 「perlの単体テストは`Test::More`を使いTAP形式で出力する（bash版の`passed=N failures=N`への変換は行わない）」旨を追記。実例として`.claude/hooks/otel/test/`を挙げる |

## やらないこと

- 設計反映（DDR・spec新設）は`plans/【設計反映】OTelリスナー機構のDDR_spec新設.md`で扱う。
- `.claude/rules/ai-command-style.md`への追記は今回の実装で新たな知見が無いため対象外。

## 検証手順

- 追記後、`.claude/rules/directory-structure.md`・`.claude/rules/shell-script-style.md`の
  該当節を読み直し、既存の記述と矛盾しないか確認する。
- markdownのfrontmatter（`alwaysApply: true`を持つファイルの既存キー配置ルール）に沿っているか確認する。

## 主要ファイル

- `.claude/rules/directory-structure.md`
- `.claude/rules/shell-script-style.md`
- `.claude/hooks/otel/`（反映内容の実例）
