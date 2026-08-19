#!/usr/bin/env bash
# .claude/hooks/lib/UsageTracking.sh の単体テスト（issue #23で新設）。
# ネットワーク・MR投稿を伴わない範囲（ミラーのコピー・push-indexの追記・サブエージェント集計の
# 戻り値形・sync_usage_stateの一連の更新）を、mktemp -d のフィクスチャで検証する。
# 規約: passed=N failures=N を標準出力へ出し、失敗があれば終了コード1
#       （.claude/rules/shell-script-style.md「テスト」）。
# 実行: bash .claude/scripts/test/test_usage_tracking.sh
set -euo pipefail

script_dir="${BASH_SOURCE[0]%/*}"
[[ "$script_dir" == "${BASH_SOURCE[0]}" ]] && script_dir="."
repo_root="$(cd "$script_dir/../../.." && pwd)"

# shellcheck source=../../../.claude/hooks/lib/UsageTracking.sh
source "$repo_root/.claude/hooks/lib/UsageTracking.sh"

passed=0
failures=0

fixture_dir="$(mktemp -d)"
cleanup_fixtures() {
  rm -rf "$fixture_dir"
}
trap cleanup_fixtures EXIT

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    passed=$((passed + 1))
  else
    failures=$((failures + 1))
    echo "FAIL: $name"
    echo "  expected: $expected"
    echo "  actual  : $actual"
  fi
}

assert_file_exists() {
  local name="$1" path="$2"
  if [[ -f "$path" ]]; then
    passed=$((passed + 1))
  else
    failures=$((failures + 1))
    echo "FAIL: $name"
    echo "  ファイルが存在しません: $path"
  fi
}

assert_not_exists() {
  local name="$1" path="$2"
  if [[ ! -e "$path" ]]; then
    passed=$((passed + 1))
  else
    failures=$((failures + 1))
    echo "FAIL: $name"
    echo "  存在しないはずのパスがあります: $path"
  fi
}

# assistantエントリを1行生成する（集計対象になる最小構造）
make_entry() {
  local branch="$1" ts="$2" tool="${3:-}"
  jq -c -n --arg branch "$branch" --arg ts "$ts" --arg tool "$tool" '
    {type: "assistant", gitBranch: $branch, timestamp: $ts,
     message: {model: "claude-sonnet-5",
       usage: {input_tokens: 10, output_tokens: 5,
               cache_creation_input_tokens: 0, cache_read_input_tokens: 0},
       content: (if $tool == "" then [] else [{type: "tool_use", name: $tool, id: "t1", input: {}}] end)}}
  '
}

# =============================================================================
# _usage_append_push_index
# =============================================================================

idx_root="$fixture_dir/idxrepo"
mkdir -p "$idx_root"
index_file="$idx_root/usage/state/push-index.jsonl"

_usage_append_push_index "$idx_root" "feature-x" "sess-1" "claude" 1 10 '{}'

assert_file_exists "push-index: 初回でファイルが作られる" "$index_file"
assert_eq "push-index: 初回は push=1" "1" \
  "$(jq -r '.push' "$index_file" | tr -d '\r')"
assert_eq "push-index: 初回の行範囲" "1-10" \
  "$(jq -r '"\(.main.from)-\(.main.to)"' "$index_file" | tr -d '\r')"
assert_eq "push-index: branch/sessionId/engineが記録される" "feature-x|sess-1|claude" \
  "$(jq -r '"\(.branch)|\(.sessionId)|\(.engine)"' "$index_file" | tr -d '\r')"

_usage_append_push_index "$idx_root" "feature-x" "sess-1" "claude" 11 25 \
  '{"ag1":{"from":1,"to":7}}'

assert_eq "push-index: 2回目は push=2（最大値+1）" "2" \
  "$(jq -s -r '.[1].push' "$index_file" | tr -d '\r')"
assert_eq "push-index: 2回目の行範囲" "11-25" \
  "$(jq -s -r '"\(.[1].main.from)-\(.[1].main.to)"' "$index_file" | tr -d '\r')"
assert_eq "push-index: agentsが記録される" "1-7" \
  "$(jq -s -r '"\(.[1].agents.ag1.from)-\(.[1].agents.ag1.to)"' "$index_file" | tr -d '\r')"
assert_eq "push-index: 行数は2行" "2" "$(grep -c '' "$index_file")"
# WindowsネイティブjqのCR混入対策（tr -d '\r'）が効いていることの確認。
# `grep -c $'\r'` は環境によってパターンが空文字として渡り全行にマッチしてしまう（実機で確認）ため、
# CRを除去する前後のバイト数を比較する形で判定する。
assert_eq "push-index: CRが混入していない" \
  "$(wc -c < "$index_file")" \
  "$(tr -d '\r' < "$index_file" | wc -c)"

# agent_ranges を省略した場合は {} が既定になる（`"${7:-\{\}}"` の書き方だと
# バックスラッシュが残って不正なJSONになる、というバグの回帰テスト）
_usage_append_push_index "$idx_root" "feature-x" "sess-1" "claude" 26 30
assert_eq "push-index: agent_ranges省略時は空オブジェクト" "{}" \
  "$(jq -s -c -r '.[2].agents' "$index_file" | tr -d '\r')"

# =============================================================================
# _usage_sync_session_logs（Claude Code）
# =============================================================================

cc_root="$fixture_dir/ccrepo"
cc_src="$fixture_dir/ccsrc"
mkdir -p "$cc_src/sess-cc/subagents"
make_entry "feature-y" "2026-08-18T00:00:00Z" > "$cc_src/sess-cc.jsonl"
make_entry "feature-y" "2026-08-18T00:00:10Z" "Read" > "$cc_src/sess-cc/subagents/agent-ag1.jsonl"
printf '%s\n' '{"agentType":"Explore","description":"調査用"}' \
  > "$cc_src/sess-cc/subagents/agent-ag1.meta.json"

cc_log_dir="$(_usage_sync_session_logs "$cc_root" "sess-cc" "$cc_src/sess-cc.jsonl" "claude")"

assert_eq "sync(claude): コピー先はセッション単位（ブランチ階層が無い）" \
  "$cc_root/usage/session-logs/sess-cc" "$cc_log_dir"
assert_file_exists "sync(claude): main.jsonl がコピーされる" "$cc_log_dir/main.jsonl"
assert_file_exists "sync(claude): agent-*.jsonl が subagents/ 直下へコピーされる" \
  "$cc_log_dir/subagents/agent-ag1.jsonl"
assert_file_exists "sync(claude): .meta.json もコピーされる" \
  "$cc_log_dir/subagents/agent-ag1.meta.json"

# engine省略時はclaudeとして扱う（既存呼び出しの互換性）
cc_root2="$fixture_dir/ccrepo2"
cc_log_dir2="$(_usage_sync_session_logs "$cc_root2" "sess-cc" "$cc_src/sess-cc.jsonl")"
assert_file_exists "sync: engine省略時もClaude Code構造で動く" \
  "$cc_log_dir2/subagents/agent-ag1.jsonl"

# =============================================================================
# _usage_sync_session_logs（Gemini CLI）
# =============================================================================

gm_root="$fixture_dir/gmrepo"
gm_src="$fixture_dir/gmsrc"
mkdir -p "$gm_src/sess-gm"
make_entry "feature-y" "2026-08-18T00:00:00Z" > "$gm_src/sess-gm.jsonl"
make_entry "feature-y" "2026-08-18T00:00:10Z" "Read" > "$gm_src/sess-gm/agent-inner.jsonl"

gm_log_dir="$(_usage_sync_session_logs "$gm_root" "sess-gm" "$gm_src/sess-gm.jsonl" "gemini")"

assert_file_exists "sync(gemini): main.jsonl がコピーされる" "$gm_log_dir/main.jsonl"
assert_file_exists "sync(gemini): subagents/<session_id>/ 配下へコピーされる" \
  "$gm_log_dir/subagents/sess-gm/agent-inner.jsonl"
# 集計側の glob `subagents/agent-*.jsonl` に**マッチしないこと**が、
# 「Geminiのログは保存するが集計対象にはしない」というスコープ境界の担保になっている
assert_not_exists "sync(gemini): subagents/直下には置かれない（集計globに掛からない）" \
  "$gm_log_dir/subagents/agent-inner.jsonl"

# =============================================================================
# _usage_aggregate_and_merge_subagents の戻り値形
# =============================================================================

sa_root="$fixture_dir/sarepo"
mkdir -p "$sa_root/usage/state"
empty_state='{"branch":"feature-y","sessions":{},"sinceLastPush":{"tokensByModel":{},"toolCalls":{},"turns":0,"activeSeconds":0,"skillCalls":[],"agentCalls":[],"askUserQuestions":[]}}'

# サブエージェントが1件も無い場合
no_sub_dir="$fixture_dir/nosub"
mkdir -p "$no_sub_dir"
res="$(_usage_aggregate_and_merge_subagents "$empty_state" "$no_sub_dir" "feature-y" "$sa_root")"
assert_eq "subagents: サブエージェント無しでも {state, agents} を返す" "state agents" \
  "$(printf '%s' "$res" | jq -r 'keys_unsorted | join(" ")' | tr -d '\r')"
assert_eq "subagents: サブエージェント無しなら agents は空" "{}" \
  "$(printf '%s' "$res" | jq -c '.agents' | tr -d '\r')"

# サブエージェントが1件ある場合
res2="$(_usage_aggregate_and_merge_subagents "$empty_state" "$cc_log_dir" "feature-y" "$sa_root")"
assert_eq "subagents: 集計したagentの行範囲が agents に載る" "1-1" \
  "$(printf '%s' "$res2" | jq -r '"\(.agents.ag1.from)-\(.agents.ag1.to)"' | tr -d '\r')"
assert_eq "subagents: stateへagentIdごとの差分が畳み込まれる" "Explore" \
  "$(printf '%s' "$res2" | jq -r '.state.agents.ag1.agentType' | tr -d '\r')"

# 2回目（新規行が無い）はスキップされ、agents に現れない
res3="$(_usage_aggregate_and_merge_subagents "$empty_state" "$cc_log_dir" "feature-y" "$sa_root")"
assert_eq "subagents: 新規行が無いagentは agents に現れない" "{}" \
  "$(printf '%s' "$res3" | jq -c '.agents' | tr -d '\r')"

# =============================================================================
# sync_usage_state（一連の更新）
# =============================================================================

sy_root="$fixture_dir/syrepo"
sy_src="$fixture_dir/sysrc"
mkdir -p "$sy_root" "$sy_src"
{
  make_entry "feature-z" "2026-08-18T00:00:00Z" "Read"
  make_entry "feature-z" "2026-08-18T00:00:30Z" "Bash"
} > "$sy_src/sess-sy.jsonl"

sync_usage_state "$sy_root" "feature-z" "sess-sy" "$sy_src/sess-sy.jsonl" "claude" >/dev/null

assert_file_exists "sync_usage_state: 新レイアウトのミラーが作られる" \
  "$sy_root/usage/session-logs/sess-sy/main.jsonl"
assert_not_exists "sync_usage_state: 旧レイアウト（ブランチ階層）は作られない" \
  "$sy_root/usage/session-logs/feature-z"
assert_file_exists "sync_usage_state: 状態ファイルが作られる" \
  "$sy_root/usage/state/feature-z.json"
assert_eq "sync_usage_state: カーソルが進む" "2" \
  "$(jq -r '.lastLineCount' "$sy_root/usage/state/session-cursors/sess-sy.json" | tr -d '\r')"
assert_eq "sync_usage_state: push-indexへ1行追記される" "1" \
  "$(grep -c '' "$sy_root/usage/state/push-index.jsonl")"
assert_eq "sync_usage_state: push-indexの行範囲が全行を指す" "1-2" \
  "$(jq -r '"\(.main.from)-\(.main.to)"' "$sy_root/usage/state/push-index.jsonl" | tr -d '\r')"
assert_eq "sync_usage_state: ツール実行回数が集計される" "1" \
  "$(jq -r '.sinceLastPush.toolCalls.Read' "$sy_root/usage/state/feature-z.json" | tr -d '\r')"

# 2回目: 新規行が無いのでpush-indexは増えない
sync_usage_state "$sy_root" "feature-z" "sess-sy" "$sy_src/sess-sy.jsonl" "claude" >/dev/null
assert_eq "sync_usage_state: 新規行が無ければpush-indexは増えない" "1" \
  "$(grep -c '' "$sy_root/usage/state/push-index.jsonl")"

# 3回目: 行を追記してから呼ぶと、続きの範囲が記録される
make_entry "feature-z" "2026-08-18T00:01:00Z" "Edit" >> "$sy_src/sess-sy.jsonl"
sync_usage_state "$sy_root" "feature-z" "sess-sy" "$sy_src/sess-sy.jsonl" "claude" >/dev/null
assert_eq "sync_usage_state: 追記後は push=2 が積まれる" "2" \
  "$(grep -c '' "$sy_root/usage/state/push-index.jsonl")"
assert_eq "sync_usage_state: 続きの行範囲が記録される" "3-3" \
  "$(jq -s -r '.[1] | "\(.main.from)-\(.main.to)"' "$sy_root/usage/state/push-index.jsonl" | tr -d '\r')"

echo "passed=$passed failures=$failures"
[ "$failures" -eq 0 ]
