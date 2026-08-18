---
title: セッションログ保存hook（post-push-save-logs.sh）
type: spec
description: git push検知時にGemini CLI/Claude Codeのセッションログ（メイン＋サブエージェント）をlogs/push-<N>/へ保存するhookの仕様
tags: [hooks, session-logs, gemini-cli, claude-code]
keywords: [post-push-save-logs, tool_name, run_shell_command, transcript_path, subagents, logs, gitignore, AfterTool, PostToolUse]
---

# セッションログ保存hook（post-push-save-logs.sh）

## 背景・目的

`git push`のたびに、そのセッションのtranscript（メイン＋サブエージェント）をリポジトリ直下の
`logs/push-<N>/`へスナップショットとして保存し、後から調査・デバッグしやすくする。対応工数
レポート機能（`.claude/hooks/lib/UsageTracking.sh`）が使う`usage/session-logs/`とは別系統で、
用途もディレクトリも異なる（`usage/session-logs/`は対応工数レポートの集計専用の内部状態、
`logs/push-<N>/`は人間が直接参照する生ログのアーカイブ）。

Gemini CLI向けの実装として追加された後、issue #3でClaude Code対応を追加し、両エンジンで
共通に動作するようにした。

## 仕様

### 実行契機

`git push`を含むコマンドの実行後（Gemini CLI: `AfterTool`、Claude Code: `PostToolUse`）に、
`.claude/hooks/post-push-save-logs.sh`が起動する。サブエージェント内実行（`agent_id`がhook
入力に含まれる場合）では何もしない。

### エンジン判定

hook入力の`tool_name`で実行中のエンジンを判定する。両エンジンの`tool_name`の値集合は重複しない
ため、これだけで機械的に一意判定できる。

| `tool_name` | エンジン |
|---|---|
| `run_shell_command` | Gemini CLI |
| `Bash` / `PowerShell` | Claude Code |
| 上記以外 | 対象外として即終了 |

プロジェクトルートは`${GEMINI_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-}}`で取得する（どちらも
未設定なら終了）。

### 保存先ディレクトリ

`<プロジェクトルート>/logs/push-<N>/`（`N`は`logs/`配下の既存`push-*`ディレクトリを走査して
決定する連番。既存ディレクトリを壊さないよう常に最大値+1を使う）。

### ログの探索方法（エンジンごとに異なる）

メインtranscript（`transcript_path`）のコピーはエンジン共通。サブエージェントログの探索方法のみ
エンジンごとに異なる。

- **Gemini CLI**: `transcript_path`のあるディレクトリ（`chats_dir`）配下の、`session_id`と
  同名のディレクトリをサブエージェントログとして丸ごとコピーする（`cp -R`）。
- **Claude Code**: `${transcript_path%.jsonl}/subagents/agent-*.jsonl`を列挙し、対応する
  `<agentId>.meta.json`（存在すれば）とあわせて`push_dir/subagents/`へコピーする
  （`.claude/hooks/lib/UsageTracking.sh`の`_usage_sync_session_logs`と同じ探索パターン）。

### hookの登録

- **Claude Code**: `.claude/settings.json`の`hooks.PostToolUse`（`matcher: "Bash|PowerShell"`、
  `if`フィールドで`"Bash(git push*)"` / `"PowerShell(git push*)"`）へ、既存の
  `post-push-usage-report.sh`/`post-push-compact-prompt.sh`と同じパターンで登録する。
- **Gemini CLI**: `.gemini/settings.json`の`hooks`キー配下（`SessionStart`/`BeforeTool`/
  `AfterTool`）に、`.claude/hooks/*.sh`一式（`session-start`, `block-direct-git-commit`,
  `post-push-usage-report`, `post-push-compact-prompt`, `post-push-save-logs`）をまとめて登録する。
  `BeforeTool`/`AfterTool`の`matcher`は`"run_shell_command|Bash|PowerShell"`という両エンジンの
  `tool_name`を含む形にしている（各hookスクリプト内部で`tool_name`により絞り込むため、
  マッチャーを広めに取っても誤発火はしない）。`command`フィールドは単一のシェル文字列
  （`args`配列に相当するフィールドはGemini CLI側に無い）で、`${GEMINI_PROJECT_DIR}`は
  ダブルクォートで囲む。`.gemini/settings.json`の既存キー（`general.plan.directory`）は
  そのまま維持し、`hooks`キーのみを追加する。

失敗時はgit push自体をブロックしない設計（`( main ) || true; exit 0`）。

### `.gitignore`

`logs/`はローカル作業状態のため`.gitignore`に`/logs/`を追記している（`usage/`と同じ扱い）。

## 影響範囲

- `.claude/hooks/post-push-save-logs.sh`
- `.claude/settings.json`
- `.gemini/settings.json`
- `.gitignore`

## 未決定事項・懸念点

- **Gemini CLI側のサブエージェント探索の前提が実態と合っていない可能性**: Gemini CLI本体の
  [Issue #20258](https://github.com/google-gemini/gemini-cli/issues/20258)によれば、現行
  バージョンのGemini CLIではサブエージェントが親と同じセッションIDで動作するとの報告がある。
  これが事実であれば、本hookが前提とする「`chats_dir`配下に`session_id`名のディレクトリで
  サブエージェントログが格納される」という構造と実際の挙動がズレている可能性がある。issue #3の
  対応では、既存のGemini CLI側の保存動作を変更しない方針としたため、この懸念への対応は
  見送っている（未検証のまま）。
- **`.gemini/settings.json`のスキーマは限定的にしか検証していない**: `hooks`セクションの内容は
  PRレビューで提示された実物を採用したが、Gemini CLI公式ドキュメント側の記載
  （[Hooks reference](https://geminicli.com/docs/hooks/reference/)）は`command`フィールドが
  `args`配列を持つか等、一部未文書化の挙動がある。実際にGemini CLI上で動作確認できていない
  （Claude Code環境での実装のため）。
