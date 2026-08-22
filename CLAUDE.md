---
title: Claude Code固有ルール
type: rule
description: Claude Code向けの追加ルール（AGENTS.mdの共通ルールに加えて適用する固有ルール）へのポインタ
tags: [claude-code, rule]
keywords: [agents-md, 計画モード, claude-code, 固有ルール]
---

## エージェント共通ルール

@./AGENTS.md

## Claude Code固有ルール

プロジェクト固有のルールは `.claude/rules/<名前>.md` へ置く（セッション開始時に自動で
読み込まれる）。このファイルへ直接書き足さないこと——このファイルは配布元が所有しており
（layer=core）、再適用で上書きされる。
