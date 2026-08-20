#!/usr/bin/env bash
#
# Claude Code PreToolUse hook（`git commit`の直接実行をブロック、issue #39）。
# 設計: issue #39 →
#       .claude/docs/ddr/i0000-09-コミットはcommitスキル経由を機構的に強制する.md
#
# 目的: すべてのコミットを `.claude/skills/commit/SKILL.md`（`commit`スキル）経由で行わせる
# （issue #39の受け入れ条件）。ドキュメント上のルールだけではエージェントの遵守に依存するため、
# Bash/PowerShellツールのコマンド文字列が gitのコミットを**実行する**場合を機構的にブロックする。
#
# .claude/settings.json 側で matcher: "Bash|PowerShell" として広く受け、本スクリプト側で
# command 文字列を正規表現でチェックする（既存の post-push-usage-report.sh と同じ設計。
# `permissions.deny` の prefix マッチだけでは `cd src && git commit -m "fix"` のような
# 複合コマンドをすり抜けてしまうため、hook側でも実文字列を検査する）。
#
# commitスキル自身は `.claude/scripts/src/create-commit.sh` というラッパー経由でコミットするため、
# 呼び出し文字列にgitのコミット呼び出しが現れず、本hookには引っかからない
# （ラッパー内部で `git commit` を実行すること自体は問題ない。本hookが検査するのは
# Bash/PowerShellツールへの「呼び出し文字列」のみで、その呼び出しが実行するスクリプトの
# 内部処理までは見ていないため）。
#
# 判定は .claude/hooks/lib/CommandPosition.sh の command_invokes_git_subcommand が行う
# （issue #53）。以前は部分文字列マッチだったため、ヒアドキュメント本文・クォート内・
# コメント・日本語の地の文に該当語が含まれるだけで誤ってブロックしていた。現在は
# コマンドとして実行される位置にある場合だけブロックする。
#
# 既知のトレードオフ: 意図的な文字列分割等による回避への対策は行わない（安全境界ではなく、
# 既定動作を確実な方向へ倒すための仕組み）。逆に、文字列をコードとして受け取る実行系
# （`eval` / `bash -c` / `xargs` / `find` 等）が混ざる場合は、位置判定で一致しなくても
# 従来どおりの部分一致でブロックする（素通りを増やさないため）。詳細は
# .claude/docs/spec/command-position.md。

set -uo pipefail

main() {
  set -euo pipefail

  local raw
  raw="$(cat)"
  [ -n "$raw" ] || exit 0

  local hook_input
  hook_input="$(printf '%s' "$raw" | jq -c '.' 2>/dev/null)" || exit 0
  [ -n "$hook_input" ] || exit 0

  local tool_name
  tool_name="$(printf '%s' "$hook_input" | jq -r '.tool_name // empty')"
  if [ "$tool_name" != "Bash" ] && [ "$tool_name" != "PowerShell" ]; then
    exit 0
  fi

  local command
  command="$(printf '%s' "$hook_input" | jq -r '.tool_input.command // empty')"
  [ -n "$command" ] || exit 0

  # 判定は .claude/hooks/lib/CommandPosition.sh へ委譲する（issue #53）。
  # ライブラリを読めない場合だけ、従来どおりの部分一致で安全側へ倒す
  # （検知そのものが無効になるより、誤検知が残るほうがまし）。
  local lib="${BASH_SOURCE[0]%/*}/lib/CommandPosition.sh"
  local blocked=1
  if [ -r "$lib" ]; then
    # shellcheck source=lib/CommandPosition.sh
    source "$lib"
    if command_invokes_git_subcommand "$command" commit; then
      blocked=0
    fi
  elif printf '%s' "$command" | grep -qiE 'git[[:space:]]+commit'; then
    blocked=0
  fi

  if [ "$blocked" = 0 ]; then
    echo "git commit の直接実行はブロックされています。commit スキル（.claude/skills/commit/SKILL.md）経由で、.claude/scripts/src/create-commit.sh を使ってコミットしてください。" >&2
    exit 2
  fi

  exit 0
}

# `source` されたときは関数定義のみを読み込ませ、`main` を実行しない（issue #57）。
# `main` は冒頭で `raw="$(cat)"` を実行するため、ガードが無いとテストから `source` した時点で
# stdin待ちのままハングする。
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main
fi
