#!/usr/bin/env bash
#
# Gemini CLI / Claude Code 共通 AfterTool・PostToolUse hook（git push検知、セッションログ保存、bash版）。
# 設計: plans/20260818-collect-gemini-session-logs.md, plans/jazzy-giggling-crescent.md（issue #3）
#
# AfterTool/PostToolUse（対象: run_shell_command（Gemini CLI）/ Bash・PowerShell（Claude Code））で
# git push コマンドが実行されたことを検知して、該当プロジェクトの今回のセッションログ（サブエージェント
# 分を含む）をプロジェクトルート直下の `logs/push-<num>/` ディレクトリに保存します。
#
# tool_name から実行中のエンジン（Gemini CLI / Claude Code）を自動判定し（Gemini CLIは
# `run_shell_command`、Claude Codeは`Bash`/`PowerShell`というtool_nameを使うため両者は重複せず、
# 機械的に一意判定できる）、それぞれのセッションログのディレクトリ構造に応じた保存ロジックに分岐します。
# メインtranscriptのコピー処理自体はエンジン共通、サブエージェントログの探索方法のみ分岐します
# （詳細: plans/jazzy-giggling-crescent.md「調査結果」）。
#
# 注意（未検証の既知の懸念、issue #3対応時に判明）: Gemini CLI側の「transcript_pathのある
# ディレクトリ（chats_dir）配下に、session_id名のディレクトリでサブエージェントログが格納される」
# という前提は、Gemini CLI本体のissue https://github.com/google-gemini/gemini-cli/issues/20258
# の報告（サブエージェントが親と同じセッションIDで動作する）と整合しない可能性がある。本対応では
# Gemini CLI側の既存の保存動作を変更しない方針のため、この懸念には手を入れず、既知の注意点として
# 記録するに留める。

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

  # tool_name から実行中のエンジンを判定する。該当しないtool_nameは対象外として即終了する
  # （Gemini CLI: run_shell_command / Claude Code: Bash・PowerShell）。
  local tool_name engine engine_label
  tool_name="$(printf '%s' "$hook_input" | jq -r '.tool_name // empty')"
  case "$tool_name" in
    run_shell_command) engine="gemini"; engine_label="Gemini CLI" ;;
    Bash|PowerShell) engine="claude"; engine_label="Claude Code" ;;
    *) exit 0 ;;
  esac

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

  local session_id
  session_id="$(printf '%s' "$hook_input" | jq -r '.session_id // empty')"

  # Gemini CLI分岐用: chats ディレクトリの特定（既存動作を変更しないため、元のスクリプトと同じ位置で
  # 同じガードを行う。transcript_pathが実在する以上、このガードが失敗することは通常無い）。
  local chats_dir=""
  if [ "$engine" = "gemini" ]; then
    chats_dir="$(dirname "$transcript_path")"
    [ -d "$chats_dir" ] || exit 0
  fi

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

  # 1. メインセッションログのコピー（エンジン共通）
  cp "$transcript_path" "$push_dir/"

  # 2. サブエージェントセッションログのコピー（存在する場合。探索方法はエンジンごとに異なる）
  if [ "$engine" = "gemini" ]; then
    # Gemini CLI: chats_dir 配下の session_id 名ディレクトリにサブエージェントログが格納される
    # （既存動作。未検証の懸念はファイル冒頭コメント参照）。
    if [ -n "$session_id" ]; then
      local subagents_dir="${chats_dir}/${session_id}"
      if [ -d "$subagents_dir" ]; then
        cp -R "$subagents_dir" "$push_dir/"
      fi
    fi
  else
    # Claude Code: ${transcript_path%.jsonl}/subagents/agent-*.jsonl (+ 対応する .meta.json) が
    # サブエージェントログ（.claude/hooks/lib/UsageTracking.shの_usage_sync_session_logsと同じ
    # 探索パターン。詳細: plans/jazzy-giggling-crescent.md「調査結果」）。
    local session_dir="${transcript_path%.jsonl}"
    if [ -d "${session_dir}/subagents" ]; then
      mkdir -p "${push_dir}/subagents"
      local f meta
      for f in "${session_dir}/subagents"/agent-*.jsonl; do
        [ -e "$f" ] || continue
        cp "$f" "${push_dir}/subagents/" 2>/dev/null || true
        meta="${f%.jsonl}.meta.json"
        if [ -f "$meta" ]; then
          cp "$meta" "${push_dir}/subagents/" 2>/dev/null || true
        fi
      done
    fi
  fi

  echo "${engine_label} session logs for current session (including subagents) successfully saved to ${push_dir}/" >&2
}

( main ) || true
exit 0
