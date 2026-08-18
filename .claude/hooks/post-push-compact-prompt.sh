#!/usr/bin/env bash
#
# Gemini CLI / Claude Code 共通 AfterTool・PostToolUse hook（git push検知、/compact実施を促す
# メッセージ注入）。
# 設計: issue #11 → .claude/docs/spec/issue-mr-workflow.md,
#       issue #7（Gemini CLI対応）
#
# .claude/settings.json 側で matcher: "Bash|PowerShell"、.gemini/settings.json 側で
# matcher: "run_shell_command|Bash|PowerShell" と、各エントリの if フィールド
# （"Bash(git push*)" / "PowerShell(git push*)"）によって、tool_input のコマンドが
# git push を含む場合のみ起動される（マッチしなければプロセスが起動されず、通常のBash/
# PowerShell/run_shell_command利用への性能影響は無い）。if フィルタはベストエフォートのため、
# 本スクリプト側でも念のため command 文字列を正規表現で再チェックする
# （検知ロジックは post-push-usage-report.sh と同一パターン）。tool_nameによるエンジン判定・
# プロジェクトルート取得も同様に post-push-usage-report.sh と同じパターンを使う。
#
# post-push-usage-report.sh と責務を分離した別スクリプト（使用量集計の投稿先はMRコメントだが、
# 本スクリプトはユーザーへの直接的な呼びかけであり、伝達手段・関心事が異なるため）。
# 伝達手段は session-start.sh の write_additional_context と同じ
# `hookSpecificOutput.additionalContext` 方式（stdoutへJSON出力→コンテキストへ注入→
# エージェントが応答に反映）を PostToolUse で使う。
#
# 参照リンクの付与（issue #13）: レビュー依頼メッセージにMRへのリンクが無いと、レビュアーが
# 見に行くまでに1段階ハードルがあるという指摘への対応。以下の参照リンクをadditionalContext経由で
# 具体的なURLとして渡し、エージェントがレビュー依頼メッセージに含めるよう促す。
#   - 常に: MRへのリンク、defaultブランチとの差分へのリンク
#   - このブランチで2回目以降のpush（＝レビュー指摘対応のpush）の場合のみ追加: 前回push時点から
#     今回push時点までの差分へのリンク、コメント一覧（MR画面）へのリンク
# 「前回push時点」の判定は、このスクリプト自身が `.claude/state/review-links/<branch>.txt` へ
# 直前pushのHEAD SHAを保存し、次回push時に読み出す形で行う（`usage/`と同様、ブランチ横断・
# 非コミット対象のローカル作業状態。責務分離のため対応工数レポート側の状態とは別ファイルにする）。
# 差分系のURLは、MR/PRのURL文字列から`/files`等のsuffixを推測する方式ではなく、
# `get_repo_url`（`gh repo view` / `glab repo view`）で取得したリポジトリの正規URLを土台に、
# GitHub/GitLabいずれも持つ汎用の「Compare」ページ（`/compare/<from>...<to>`）を組み立てる方式にした
# （issue #13フォローアップ:「gh/glabでURLの正確性を担保したい」という指摘への対応。詳細は
# `.claude/docs/ddr/0023-...md`参照）。
#
# 注意（エラー方針）: 本体処理は `main` 関数にまとめ、`( main )` のように実サブシェル（丸括弧）の
# 中で呼ぶことで、内部で失敗したコマンドの時点で確実にサブシェルごと終了させる（bashの
# 「if/||の条件式の中では-eが一時停止する」という仕様の影響を受けないようにするため。詳細:
# .claude/docs/spec/shell-scripts.md「bashでのtry/catch相当の書き方」節）。失敗はすべて
# 握りつぶし、git push自体はブロックしない。

set -uo pipefail

CONTEXT_MESSAGE='ユーザにMRレビュー依頼をするためのフックです。下記の参照リンクをレビュー依頼メッセージに含めてください。また、前回のcompact実施から一定期間経過している場合、/compactの実施を促してください。'
COMPACT_PROMPT_MESSAGE='メッセージ例: MRのレビューをお願いします。/compactを実施をしていただくと、レビュー中にコンテキストを圧縮して今後の作業が効率的になる可能性があります'

write_additional_context() {
  local text="$1"
  jq -nc --arg text "$text" \
    '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $text}}'
}

# 参照リンクのテキストブロックを組み立てる。prev_shaが空（このブランチでの初回push）の場合は
# 「前回pushとの差分」「コメント一覧」の2行を省略する（issue #13受け入れ条件）。
# diff_url/repo_urlは、いずれもgh/glab由来の情報（PR/MRのURL・リポジトリの正規URL）から
# 組み立てたものを渡す（issue #13フォローアップ: URL文字列からの推測を避け正確性を担保する）。
build_links_text() {
  local mr_url="$1" diff_url="$2" repo_url="$3" prev_sha="$4" current_sha="$5"
  local text
  text="$(printf '参照リンク:\n- MR: %s\n- defaultブランチとの差分: %s' "$mr_url" "$diff_url")"
  if [ -n "$prev_sha" ] && [ "$prev_sha" != "$current_sha" ]; then
    local since_url
    since_url="$(get_mr_diff_since_url "$repo_url" "$prev_sha" "$current_sha")"
    text="$(printf '%s\n- 前回push時との差分: %s\n- コメント一覧(MR画面): %s' "$text" "$since_url" "$mr_url")"
  fi
  printf '%s' "$text"
}

main() {
  set -euo pipefail

  local raw
  raw="$(cat)"
  [ -n "$raw" ] || exit 0

  local hook_input
  hook_input="$(printf '%s' "$raw" | jq -c '.' 2>/dev/null)" || exit 0
  [ -n "$hook_input" ] || exit 0

  local agent_id
  agent_id="$(printf '%s' "$hook_input" | jq -r '.agent_id // empty')"
  # サブエージェント内実行では何もしない（post-push-usage-report.shと同じガード）
  [ -z "$agent_id" ] || exit 0

  # tool_name から実行中のエンジンを判定する。該当しないtool_nameは対象外として即終了する
  # （Gemini CLI: run_shell_command / Claude Code: Bash・PowerShell。post-push-usage-report.shと
  # 同じ判定パターン）。
  local tool_name
  tool_name="$(printf '%s' "$hook_input" | jq -r '.tool_name // empty')"
  case "$tool_name" in
    run_shell_command|Bash|PowerShell) ;;
    *) exit 0 ;;
  esac

  local command
  command="$(printf '%s' "$hook_input" | jq -r '.tool_input.command // empty')"
  if [ -z "$command" ] || ! printf '%s' "$command" | grep -qiE 'git[[:space:]]+push'; then
    exit 0
  fi

  local project_dir="${GEMINI_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-}}"
  [ -n "$project_dir" ] || exit 0
  cd "$project_dir"
  source "${project_dir}/.claude/scripts/src/vcs/Provider.sh"

  local branch base_branch
  branch="$(git branch --show-current 2>/dev/null || true)"
  base_branch="$(get_workflow_config | jq -r '.defaultBaseBranch')"
  [ -n "$branch" ] && [ "$branch" != "$base_branch" ] || exit 0

  local mr
  mr="$(get_mr_for_branch "$branch")"
  [ -n "$mr" ] || exit 0

  local mr_url repo_url diff_url
  mr_url="$(printf '%s' "$mr" | jq -r '.url')"
  repo_url="$(get_repo_url)"
  diff_url="$(get_mr_diff_url "$repo_url" "$base_branch" "$branch")"

  local repo_root safe_branch state_file current_sha prev_sha=""
  repo_root="$(get_repo_root)"
  safe_branch="$(printf '%s' "$branch" | sed -E 's/[^a-zA-Z0-9_-]/_/g')"
  state_file="${repo_root}/.claude/state/review-links/${safe_branch}.txt"
  current_sha="$(git rev-parse HEAD)"
  if [ -f "$state_file" ]; then
    prev_sha="$(cat "$state_file")"
  fi

  local links_text
  links_text="$(build_links_text "$mr_url" "$diff_url" "$repo_url" "$prev_sha" "$current_sha")"

  # 次回push時の「前回pushとの差分」計算のため、今回pushのHEAD SHAを保存する
  mkdir -p "$(dirname "$state_file")"
  printf '%s' "$current_sha" > "$state_file"

  write_additional_context "$(printf '%s\n\n%s\n\n%s' "$CONTEXT_MESSAGE" "$links_text" "$COMPACT_PROMPT_MESSAGE")"
}

( main ) || true

exit 0
