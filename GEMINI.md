---
title: Gemini CLI固有ルール
type: rule
description: Gemini CLI向けの追加ルール（AGENTS.mdの共通ルールに加えて適用する固有ルール）へのポインタ
tags: [gemini-cli, rule]
keywords: [agents-md, gemini-cli, 固有ルール]
---

## エージェント共通ルール

@./AGENTS.md

## geminiCLI固有ルール

プロジェクト固有のルールは `.claude/rules/<名前>.md` へ置く（セッション開始時に自動で
読み込まれる）。このファイルへ直接書き足さないこと——このファイルは配布元が所有しており
（layer=core）、再適用で上書きされる。

**Gemini CLI 利用時も `.claude/` への依存は切れない。** `.gemini/` は `.claude/` からの
変換生成物であり（`.claude/scripts/src/sync-gemini-assets.sh`）、hook・サブエージェント定義の
実体は `.claude/hooks/` `.claude/scripts/` を指し続ける。`.gemini/` を自立させる（この依存を
切る）ことは issue #172 で検討したが、構造的に不可能と判断し見送った（DDR `i0172-01`）。
