#!/usr/bin/env bash
#
# Gemini CLI PostToolUse hook (git push検知、セッションログ保存、bash版)。
# 設計: plans/20260818-collect-gemini-session-logs.md
#
# AfterTool（対象: run_shell_command / Bash / PowerShell）で git push コマンドが
# 実行されたことを検知して、該当プロジェクトの今回のセッションログ（サブエージェント分を含む）を
# プロジェクトルート直下の `logs/push-<num>/` ディレクトリに保存します。

set -uo pipefail

main() {
  set -euo pipefail

  local raw
  raw="$(cat)"
  [ -n "$raw" ] || exit 0

  local hook_input
  hook_input="$(printf '%s' "$raw" | jq -c '.' 2>/dev/null)" || exit 0
  [ -n "$hook_input" ] || exit 0

  # サブエージェント内実行では何もしない
  local agent_id
  agent_id="$(printf '%s' "$hook_input" | jq -r '.agent_id // empty')"
  [ -z "$agent_id" ] || exit 0

  # tool_name が Bash、PowerShell、または run_shell_command であることを確認
  local tool_name
  tool_name="$(printf '%s' "$hook_input" | jq -r '.tool_name // empty')"
  if [ "$tool_name" != "Bash" ] && [ "$tool_name" != "PowerShell" ] && [ "$tool_name" != "run_shell_command" ]; then
    exit 0
  fi

  # 実行されたコマンドに git push が含まれているか確認
  local command
  command="$(printf '%s' "$hook_input" | jq -r '.tool_input.command // empty')"
  if [ -z "$command" ] || ! printf '%s' "$command" | grep -qiE 'git[[:space:]]+push'; then
    exit 0
  fi

  # プロジェクトのルートディレクトリを取得
  local project_dir="${GEMINI_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-}}"
  [ -n "$project_dir" ] || exit 0
  cd "$project_dir"

  # transcript_path の取得
  local transcript_path
  transcript_path="$(printf '%s' "$hook_input" | jq -r '.transcript_path // empty')"
  [ -n "$transcript_path" ] && [ -f "$transcript_path" ] || exit 0

  # chats ディレクトリの特定
  local chats_dir
  chats_dir="$(dirname "$transcript_path")"
  [ -d "$chats_dir" ] || exit 0

  # 保存先 logs ディレクトリの作成
  local logs_dest_dir="${project_dir}/logs"
  mkdir -p "$logs_dest_dir"

  # プッシュ回数（連番）の動的決定
  local push_num=1
  local max_num=0
  local d
  # 既存の push-X フォルダを走査して次の連番を決定
  for d in "$logs_dest_dir"/push-*; do
    if [ -d "$d" ]; then
      local dir_name
      dir_name="$(basename "$d")"
      local num="${dir_name#push-}"
      if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -gt "$max_num" ]; then
        max_num="$num"
      fi
    fi
  done
  push_num=$(( max_num + 1 ))

  # 今回のプッシュに対応する保存先フォルダ
  local push_dir="${logs_dest_dir}/push-${push_num}"
  mkdir -p "$push_dir"

  # 1. メインセッションログのコピー
  cp "$transcript_path" "$push_dir/"

  # 2. サブエージェントセッションログのコピー（存在する場合）
  local session_id
  session_id="$(printf '%s' "$hook_input" | jq -r '.session_id // empty')"
  if [ -n "$session_id" ]; then
    local subagents_dir="${chats_dir}/${session_id}"
    if [ -d "$subagents_dir" ]; then
      cp -R "$subagents_dir" "$push_dir/"
    fi
  fi

  echo "Gemini session logs for current session (including subagents) successfully saved to ${push_dir}/" >&2
}

( main ) || true
exit 0