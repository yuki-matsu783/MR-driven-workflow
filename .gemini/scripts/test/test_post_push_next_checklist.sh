#!/usr/bin/env bash
# .claude/hooks/post-push-next-checklist.sh の単体テスト（issue #17）。
#
# 3層構成（test_block_unchecked_push.sh と同じ切り分け）。
#   1. 前置フィルタ（raw_hints_at_git_push・純粋関数）を source して直接呼ぶ。
#   2. サブプロセス起動＋PATH先頭のスタブjq。対象外ペイロードでjqが1度も呼ばれないこと。
#   3. 使い捨てgitリポジトリを CLAUDE_PROJECT_DIR に据えて実際に起動し、
#      次回分のチェックリストが生成されること・生成条件を満たさないときは静かに終わることを
#      確かめる。**PostToolUseは常に exit 0**（ここが非0になると、pushのたびにエラーが出続ける）。
#
# **このテストは当初この機構の計画から漏れていた**（フェーズ3の敵対的レビュー1回目で指摘）。
# 計画自身が「テストを伴わない実装は成立しない」と書いているのに、hook 3本目だけが例外に
# なっていた。
#
# 規約: passed=N failures=N を標準出力へ出し、失敗があれば終了コード1
#       （.claude/rules/shell-script-style.md「テスト」）。
# 実行: bash .claude/scripts/test/test_post_push_next_checklist.sh
set -euo pipefail

script_dir="${BASH_SOURCE[0]%/*}"
[[ "$script_dir" == "${BASH_SOURCE[0]}" ]] && script_dir="."
repo_root="$(cd "$script_dir/../../.." && pwd)"
hook="$repo_root/.claude/hooks/post-push-next-checklist.sh"

# shellcheck source=../../../.claude/hooks/post-push-next-checklist.sh
source "$hook"

passed=0
failures=0

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

assert_contains() {
  local name="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    passed=$((passed + 1))
  else
    failures=$((failures + 1))
    echo "FAIL: $name"
    echo "  「$needle」を含むはずが含まれていない"
    echo "  actual  : $haystack"
  fi
}

hints() {
  if raw_hints_at_git_push "$1"; then
    printf '0'
  else
    printf '1'
  fi
}

payload() {
  jq -nc --arg tn "$1" --arg cmd "$2" '{tool_name: $tn, tool_input: {command: $cmd}}'
}

# --- 層1: 前置フィルタ（超集合であること）---------------------------------

assert_eq "層1: git push を含む生JSONは通過する" "0" "$(hints "$(payload Bash 'git push')")"
assert_eq "層1: git -C /x push（語が非連続）も通過する" "0" "$(hints "$(payload Bash 'git -C /x push')")"
assert_eq "層1: 大文字のPUSHでも通過する" "0" "$(hints "$(payload Bash 'git PUSH')")"
assert_eq "層1: pu\\sh のようにバックスラッシュで分割されても通過する" "0" \
  "$(hints "$(payload Bash 'git pu\sh')")"
assert_eq "層1: pushと無関係なコマンドは足切りされる" "1" "$(hints "$(payload Bash 'git status')")"
assert_eq "層1: 空文字列は足切りされる" "1" "$(hints '')"

line_cont_cmd=$'git pu\\\nsh origin HEAD'
line_cont_payload="$(jq -nc --arg tn Bash --arg c "$line_cont_cmd" '{tool_name:$tn,tool_input:{command:$c}}')"
assert_eq "層1: バックスラッシュ+改行で分割されたpushも通過する" "0" "$(hints "$line_cont_payload")"

# --- 層2: スタブjq（空振りでforkしないこと）--------------------------------

stub_dir="$(mktemp -d)"
fixture_dir="$(mktemp -d)"
trap 'rm -rf "$stub_dir" "$fixture_dir"' EXIT
cat >"$stub_dir/jq" <<'EOF'
#!/usr/bin/env bash
echo "called" >> "$STUB_JQ_MARKER"
exit 1
EOF
chmod +x "$stub_dir/jq"

run_with_stub_jq_to_reply() {
  local payload_="$1"
  local marker
  marker="$(mktemp -u)"
  : >"$marker"
  local exit_code=0
  printf '%s' "$payload_" | PATH="$stub_dir:$PATH" STUB_JQ_MARKER="$marker" \
    bash "$hook" >/dev/null 2>/dev/null || exit_code=$?
  REPLY_EXIT="$exit_code"
  if [[ -s "$marker" ]]; then
    REPLY_JQ_CALLED=1
  else
    REPLY_JQ_CALLED=0
  fi
  rm -f "$marker"
}

run_with_stub_jq_to_reply "$(payload 'Bash' 'git status')"
assert_eq "層2: 無関係なコマンドはjqを呼ばない" "0" "$REPLY_JQ_CALLED"
assert_eq "層2: 無関係なコマンドはexit 0" "0" "$REPLY_EXIT"

run_with_stub_jq_to_reply "$(payload 'Bash' 'git commit -m x')"
assert_eq "層2: git commitはjqを呼ばない" "0" "$REPLY_JQ_CALLED"

run_with_stub_jq_to_reply ""
assert_eq "層2: 空入力はjqを呼ばずexit 0" "0" "$REPLY_JQ_CALLED"
assert_eq "層2: 空入力はexit 0" "0" "$REPLY_EXIT"

run_with_stub_jq_to_reply "$(payload 'Bash' 'git push -u origin HEAD')"
assert_eq "層2: git pushはjqを呼ぶ" "1" "$REPLY_JQ_CALLED"

run_with_stub_jq_to_reply "$(payload 'Bash' 'git -C /x push')"
assert_eq "層2: 語が非連続でもjqを呼ぶ" "1" "$REPLY_JQ_CALLED"

run_with_stub_jq_to_reply "$line_cont_payload"
assert_eq "層2: バックスラッシュ+改行で分割されたpushもjqを呼ぶ" "1" "$REPLY_JQ_CALLED"

# --- 層3: 実リポジトリ相当での生成 ------------------------------------------

pn_repo="$fixture_dir/repo"

setup_pn_repo() {
  rm -rf "$pn_repo"
  mkdir -p "$pn_repo/wip/plans" "$pn_repo/wip/worklogs" "$pn_repo/.claude/scripts/src/vcs"
  cp "$repo_root/.claude/scripts/src/push-checklist.sh" "$pn_repo/.claude/scripts/src/"
  cp "$repo_root/.claude/scripts/src/vcs/Provider.sh" \
    "$repo_root/.claude/scripts/src/vcs/Github.sh" \
    "$repo_root/.claude/scripts/src/vcs/Gitlab.sh" "$pn_repo/.claude/scripts/src/vcs/"
  git -C "$pn_repo" init -q -b feature-17-checklist >/dev/null 2>&1 ||
    git -C "$pn_repo" init -q >/dev/null 2>&1
  git -C "$pn_repo" config user.email 'test@example.com'
  git -C "$pn_repo" config user.name 'test'
  printf '%s\n' \
    '{"defaultBaseBranch":"main","plansDir":"wip/plans","worklogDir":"wip/worklogs","reportsDir":"wip/reports"}' \
    >"$pn_repo/.mrworkflow.json"
  printf '個別計画\n' >"$pn_repo/wip/plans/【実装】テスト.md"
}

pn_commit_all() {
  git -C "$pn_repo" add -A >/dev/null 2>&1
  git -C "$pn_repo" commit -q -m "$1" >/dev/null 2>&1
}
pn_publish() {
  git -C "$pn_repo" update-ref refs/remotes/origin/main "$(git -C "$pn_repo" rev-parse HEAD)"
}
pn_checklists() {
  local f n=0
  for f in "$pn_repo"/wip/worklogs/*_checklist.tsv; do
    [ -f "$f" ] || continue
    n=$((n + 1))
  done
  printf '%s' "$n"
}

run_hook_real() {
  # $1=tool_name $2=command （$3 を渡すと CLAUDE_PROJECT_DIR を空にする）。
  # 戻り値 REPLY_EXIT / REPLY_STDOUT
  local out no_dir="${3:-}"
  set +e
  if [ -n "$no_dir" ]; then
    out="$(payload "$1" "$2" | env -u CLAUDE_PROJECT_DIR -u GEMINI_PROJECT_DIR bash "$hook" 2>/dev/null)"
  else
    out="$(payload "$1" "$2" | env -u GEMINI_PROJECT_DIR CLAUDE_PROJECT_DIR="$pn_repo" bash "$hook" 2>/dev/null)"
  fi
  REPLY_EXIT=$?
  set -e
  REPLY_STDOUT="$out"
}

# (a) 未公開のうちは生成しない（が exit 0）
setup_pn_repo
pn_commit_all 'init'
run_hook_real 'Bash' 'git push -u origin HEAD'
assert_eq "層3: 未公開でも exit 0" "0" "$REPLY_EXIT"
assert_eq "層3: 未公開なら生成しない" "0" "$(pn_checklists)"
assert_eq "層3: 未公開なら何も出力しない" "" "$REPLY_STDOUT"

# (b) 3条件が揃えば生成する
pn_publish
run_hook_real 'Bash' 'git push -u origin HEAD'
assert_eq "層3: 生成しても exit 0" "0" "$REPLY_EXIT"
assert_eq "層3: チェックリストが1本できる" "1" "$(pn_checklists)"
assert_contains "層3: 作成したパスを知らせる" "$REPLY_STDOUT" '_push1_checklist.tsv'
assert_contains "層3: 次のcommitに含めるよう促す" "$REPLY_STDOUT" '次のcommitに含めてください'

# (c) 冪等: 同じHEADでは増えない
run_hook_real 'Bash' 'git push -u origin HEAD'
assert_eq "層3: 同じHEADでは本数が増えない" "1" "$(pn_checklists)"
assert_eq "層3: 同じHEADでは何も出力しない" "" "$REPLY_STDOUT"

# (d) push以外のコマンドでは何もしない
setup_pn_repo
pn_commit_all 'init'
pn_publish
run_hook_real 'Bash' 'git status'
assert_eq "層3: push以外では生成しない" "0" "$(pn_checklists)"
run_hook_real 'Read' 'git push -u origin HEAD'
assert_eq "層3: 対象外のtool_nameでは生成しない" "0" "$(pn_checklists)"

# (e) Gemini CLI 経路（run_shell_command）でも生成する
run_hook_real 'run_shell_command' 'git push -u origin HEAD'
assert_eq "層3: run_shell_command（Gemini CLI経路）でも生成する" "1" "$(pn_checklists)"

# (f) project_dir が無ければ何もしない
setup_pn_repo
pn_commit_all 'init'
pn_publish
run_hook_real 'Bash' 'git push -u origin HEAD' 'no-dir'
assert_eq "層3: project_dirが無ければ exit 0" "0" "$REPLY_EXIT"
assert_eq "層3: project_dirが無ければ生成しない" "0" "$(pn_checklists)"

# (g) push-checklist.sh が配布されていなくても落ちない（PostToolUseは常に exit 0）
setup_pn_repo
pn_commit_all 'init'
pn_publish
rm -f "$pn_repo/.claude/scripts/src/push-checklist.sh"
run_hook_real 'Bash' 'git push -u origin HEAD'
assert_eq "層3: 本体が無くても exit 0（pushのたびにエラーを出さない）" "0" "$REPLY_EXIT"

echo "passed=$passed failures=$failures"
[[ "$failures" -eq 0 ]]
