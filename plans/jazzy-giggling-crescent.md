---
title: post-push-save-logs.shのGemini CLI/Claude Code自動判定化
type: plan
description: post-push-save-logs.shが実行中のCLI(Gemini CLI/Claude Code)を自動判定し、Claude Codeのセッションログもlogsディレクトリへ保存できるようにするための調査計画
tags: [hooks, session-logs, gemini-cli, claude-code]
keywords: [post-push-save-logs, tool_name, run_shell_command, transcript_path, subagents, logs, gitignore, settings.json]
---

# post-push-save-logs.shのGemini CLI/Claude Code自動判定化

対応issue: [#3](https://github.com/yuki-matsu783/MR-driven-workflow/issues/3)

## Context

`.claude/hooks/post-push-save-logs.sh` は「輸入」コミットで追加されたばかりの、`git push`検知時に
セッションログ（メイン＋サブエージェント）を`logs/push-<N>/`へ保存するhookスクリプト。ヘッダコメント上は
「Gemini CLI専用」だが、中身は既に`tool_name`（`run_shell_command`=Gemini CLI、`Bash`/`PowerShell`=
Claude Code）で判定を分岐できる下地がある。しかし：

- セッションログの保存先探索ロジックはGemini CLI固有のディレクトリ構造
  （`transcript_path`のあるディレクトリ配下に`session_id`ディレクトリでサブエージェントログが
  格納される構造）専用になっており、Claude Code固有の構造（`transcript_path`本体がメインログ、
  `${transcript_path%.jsonl}/subagents/agent-*.jsonl` ＋ `.meta.json`がサブエージェントログ。
  `.claude/hooks/lib/UsageTracking.sh`の`_usage_sync_session_logs`が参考実装）には対応していない。
- どちらのCLIのhooksにもまだ登録されておらず（`.claude/settings.json`にも`.gemini/settings.json`にも
  記載なし）、現状発火しない。
- 保存先`logs/`は`.gitignore`に含まれていないが、`commit`スキルのジャンクファイル除外リストには
  既に`*.log`, `logs/`が含まれている（想定はローカル作業状態としてコミット対象外）。

ユーザーからの依頼は「起動しているのがGemini CLIかClaude Codeかを自動で判断し、Claude Codeの場合の
セッションログもlogsディレクトリに保存する」こと。これに向けた調査計画を立てる。

## 調査

### 調査の目的

実装（作業計画）に着手する前に、以下を確定させる。

1. **エンジン判定の方式**: `tool_name`（`run_shell_command` vs `Bash`/`PowerShell`）と環境変数
   （`GEMINI_PROJECT_DIR`/`CLAUDE_PROJECT_DIR`）のどちらを一次判定に使うか、フォールバックの
   組み合わせ方を確定する。既存の`session-start.sh`/`post-push-usage-report.sh`が
   `CLAUDE_PROJECT_DIR`の有無をガードに使っているパターンとの整合性を確認する。
2. **Claude Code側のログ収集ロジック**: `UsageTracking.sh`の`_usage_sync_session_logs`が実装済みの
   「メインtranscriptコピー＋`${transcript_path%.jsonl}/subagents/agent-*.jsonl`列挙」パターンを
   そのまま流用できるか、`logs/push-<N>/`向けに調整が必要な差分（ディレクトリ命名・meta.jsonの扱い等）
   を洗い出す。
3. **Claude Code側のhook登録**: `.claude/settings.json`の`PostToolUse`（`Bash|PowerShell`マッチャー、
   `if`フィルタで`git push*`）へ、既存2エントリ（`post-push-usage-report.sh`,
   `post-push-compact-prompt.sh`）と同じパターンで追加登録できるか確認する。
4. **Gemini CLI側のhook登録可否**: `.gemini/settings.json`に現状hooks定義が無く、Gemini CLIの
   実際のhook設定スキーマ（イベント名が`AfterTool`か等）がこのリポジトリ内で未検証であることを
   確認したうえで、今回のissueの受け入れ条件（「Gemini CLI上での既存の保存動作に回帰がないこと」）
   の範囲でどこまで対応するかを見極める（Gemini CLI側の新規配線は情報が不足していれば別issueとして
   切り出す前提で調査する）。
5. **`logs/`の`.gitignore`扱い**: `/usage/`と同様に`.gitignore`へ追記すべきか、`commit`スキルの
   除外リストのみで足りているかを確認する。
6. **検証方法**: このリポジトリには`tests/`ディレクトリが存在しない（アプリ本体を持たないテンプレート
   のため）。hookスクリプトへの疑似JSON入力（`echo '{...}' | bash post-push-save-logs.sh`）による
   手動シミュレーションと`bash -n`構文チェックで代替できるか、新規に`tests/`を設けて
   `.claude/rules/shell-script-style.md`の「テスト」節に沿った単体テストを追加すべきかを判断する。

### 調査しないこと（対象外）

- Gemini CLI・Claude Code以外のCLI（将来対応する可能性のあるツール）への対応は行わない。
- `usage/session-logs/`（対応工数レポート用の既存の別系統のログ保存）の仕組み自体の変更は行わない
  （参考にするのみ）。

### 調査方法

- `.claude/hooks/post-push-save-logs.sh`, `.claude/hooks/lib/UsageTracking.sh`,
  `.claude/hooks/post-push-usage-report.sh`, `.claude/hooks/session-start.sh`,
  `.claude/settings.json`, `.gemini/settings.json`, `.gitignore`, `.claude/skills/commit/SKILL.md`
  を読み込み、既存パターンを突き合わせる（Read/Grep。今回のセッションで既に大部分実施済みのため、
  flow-id 10ではその内容を`plans/jazzy-giggling-crescent.md`の「調査結果」節・
  `worklog/`へ整理して記録する）。
- Gemini CLIの実際のhook設定スキーマ（イベント名・マッチャー形式）について、リポジトリ内に
  確証が無いため、WebSearch/WebFetchで一次情報を確認する。確認できない場合はその旨を調査結果に
  明記し、対応範囲から切り離す判断根拠とする。
- 疑似hook入力JSONを使い、現状のスクリプトを実際に手元で実行して動作を確認する
  （`GEMINI_PROJECT_DIR`/`CLAUDE_PROJECT_DIR`を設定した2パターン）。
