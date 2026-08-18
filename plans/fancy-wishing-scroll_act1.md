---
title: Gemini CLI + GitLabでの工数レポートコメント機能の調査
type: log
description: Claude Code+GitHubで動作する対応工数レポートのMR/PRコメント機能が、Gemini CLI+GitLabの組み合わせでも同様に動作するかを調査した記録
tags: [調査, gemini-cli, gitlab, usage-report, hooks]
keywords: [post-push-usage-report, UsageTracking, Provider.sh, Gitlab.sh, CLAUDE_PROJECT_DIR, GEMINI_PROJECT_DIR, tool_name, session-log-hooks, 工数レポート]
---

## Context

ユーザーから「Claude Code + GitHubでは前回push時からの作業工数レポートがMR/PRにコメントされるが、
Gemini CLI + GitLabでも同様に動作するようになっているか」という調査依頼があった。本タスクは
コード変更を伴わない調査のみであり、AGENTS.mdのルールに従い着手前に計画を提示する。

## 実施内容（調査のみ、コード変更なし）

Exploreエージェントにより以下を確認した。

1. `post-push-usage-report.sh`（工数レポートをMR/PRへコメント投稿するhook本体）の全体像
2. Claude Code + GitHubでの投稿経路（`.claude/settings.json` → hook → `Provider.sh`(VCS抽象化) →
   `Github.sh`）
3. Gemini CLI + GitLabでの経路の有無
4. `.claude/settings.json` / `.gemini/settings.json` のhook登録差分
5. 関連spec/ddr（`session-log-hooks.md`, `issue-mr-workflow.md`, DDR 0017/0018）の記述
6. `UsageTracking.sh` にVCS/AIツール分岐があるか

### 調査結果（結論）

**Gemini CLI + GitLabでは工数レポートのMR/PRコメントは投稿されない。** GitLabかGitHubかに関わらず、
Gemini CLIである時点で処理が止まる。

- `.gemini/hooks/post-push-usage-report.sh` は `.claude/hooks/` へのローカルリンク（DDR 0017）であり
  中身はClaude Code専用実装。以下2箇所でGemini CLI実行時に必ず即終了する。
  - `[ -n "${CLAUDE_PROJECT_DIR:-}" ] || exit 0`（`GEMINI_PROJECT_DIR` は見ていない）
  - `tool_name` が `Bash`/`PowerShell` 以外（Gemini CLIは `run_shell_command`）なら終了
  同様の作りの `post-push-compact-prompt.sh` も同じ理由で動かない。
- GitLab側のVCS実装自体（`Gitlab.sh` の `gitlab_get_mr_for_branch` / `gitlab_add_mr_comment`、
  `glab` CLI利用）はコードとして存在するが、両関数とも「このリポジトリのremoteはGitHubのみのため
  実機未検証」と明記されている（`issue-mr-workflow.md` にも同旨の記載）。
- 対照的に **`post-push-save-logs.sh` のみ** `tool_name`（`run_shell_command`→gemini /
  `Bash`|`PowerShell`→claude）と `${GEMINI_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-}}` によるエンジン判定が
  明示的に実装・`session-log-hooks.md` に文書化済み（issue #3, 直近コミットで対応）。ただしこの機能は
  セッションログを `logs/` へ保存するだけで、MR/PRへのコメント投稿は行わない別系統の機能。
- `.gemini/settings.json` は3本の post-push hook（usage-report / compact-prompt / save-logs）を
  すべて `AfterTool` に登録しているが、スクリプト本体側の対応が save-logs のみのため、残り2本は
  「設定上は登録されているが実質空振りする」状態になっている。
- `UsageTracking.sh` 自体にはVCS/AIツールの分岐は無く、Claude Code由来のtranscript JSONLを前提に
  集計するのみ（VCS分岐は呼び出し元が `Provider.sh` 経由、AIツール分岐は呼び出し元の `tool_name`
  判定でのみ行われる設計）。

根拠ファイル: `.claude/hooks/post-push-usage-report.sh`, `.claude/hooks/post-push-compact-prompt.sh`,
`.claude/hooks/post-push-save-logs.sh`, `.claude/hooks/lib/UsageTracking.sh`,
`.claude/scripts/src/vcs/Provider.sh`, `.claude/scripts/src/vcs/Gitlab.sh`, `.claude/settings.json`,
`.gemini/settings.json`, `.claude/docs/spec/session-log-hooks.md`,
`.claude/docs/spec/issue-mr-workflow.md`, `.claude/docs/ddr/0017-...md`, `.claude/docs/ddr/0018-...md`

## 対象外

- 本タスクではコード修正・issue起票は行わない（調査結果の報告のみ）。
- GitLab側の実機検証（別リポジトリ用意等）は行わない。

## 検証方法

読み取り専用の調査のため、コード変更に対する動作検証は不要。調査結果はユーザーへの報告として
チャット上に提示する。
