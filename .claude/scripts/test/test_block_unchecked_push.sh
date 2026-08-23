#!/usr/bin/env bash
# .claude/hooks/block-unchecked-push.sh の単体テスト（issue #17）。
#
# 3層構成（test_block_direct_git_commit.sh の2層構成を踏襲し、hook固有の終了コード契約を
# 確かめる層を足したもの）。
#   1. 前置フィルタ（raw_hints_at_git_push・純粋関数）を source して直接呼ぶ。
#      **超集合であること**の反例（`pu\sh`・`PUSH`・JSONエスケープをまたぐ `pu\<改行>sh`）を持つ。
#   2. サブプロセス起動＋PATH先頭のスタブjq。対象外ペイロードで**jqが1度も呼ばれない**ことを
#      確認する（時間計測ではなく呼び出し有無そのもので見る）。
#   3. 使い捨てgitリポジトリを CLAUDE_PROJECT_DIR に据えて実際に起動し、
#      **未完了なら exit 2 / 完了なら exit 0 / コミット忘れなら exit 1** を確かめる。
#      `set -e` 配下で verify の非0を素で受けると exit 1 へ落ちる罠を機械的に塞ぐのが目的。
#
# 規約: passed=N failures=N を標準出力へ出し、失敗があれば終了コード1
#       （.claude/rules/shell-script-style.md「テスト」）。
# 実行: bash .claude/scripts/test/test_block_unchecked_push.sh
set -euo pipefail

script_dir="${BASH_SOURCE[0]%/*}"
[[ "$script_dir" == "${BASH_SOURCE[0]}" ]] && script_dir="."
repo_root="$(cd "$script_dir/../../.." && pwd)"
hook="$repo_root/.claude/hooks/block-unchecked-push.sh"

# source した時点で本体（stdin読み取り）が走らないことが前提
# （.claude/rules/shell-script-style.md「テスト」）。
# shellcheck source=../../../.claude/hooks/block-unchecked-push.sh
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

# 終了コードは if で受ける（set -e 配下でコマンド置換に頼ると取れない）。
hints() {
  if raw_hints_at_git_push "$1"; then
    printf '0'
  else
    printf '1'
  fi
}

payload() {
  # $1=tool_name $2=command
  jq -nc --arg tn "$1" --arg cmd "$2" '{tool_name: $tn, tool_input: {command: $cmd}}'
}

# --- 層1: 前置フィルタ（超集合であること）---------------------------------

assert_eq "層1: git push を含む生JSONは通過する" "0" "$(hints "$(payload Bash 'git push')")"
assert_eq "層1: git -C /x push（語が非連続）も通過する" "0" "$(hints "$(payload Bash 'git -C /x push')")"
assert_eq "層1: git --no-pager push origin HEAD も通過する" "0" \
  "$(hints "$(payload Bash 'git --no-pager push origin HEAD')")"
assert_eq "層1: 大文字のPUSHでも通過する" "0" "$(hints "$(payload Bash 'git PUSH')")"
assert_eq "層1: pushと無関係なコマンドは足切りされる" "1" "$(hints "$(payload Bash 'git status')")"
assert_eq "層1: 空文字列は足切りされる" "1" "$(hints '')"

# バックスラッシュで語が分割された形（CommandPosition.sh は `\x` の `\` を落として x を残す
# ため、精密判定は push として拾う。前置フィルタが取りこぼすと機構が無言で死ぬ）。
assert_eq "層1: pu\\sh のようにバックスラッシュで分割されても通過する" "0" \
  "$(hints "$(payload Bash 'git pu\sh')")"
# JSONエスケープ列をまたぐ分割（バックスラッシュ＋改行の行継続）。
line_cont_cmd=$'git pu\\\nsh origin HEAD'
line_cont_payload="$(jq -nc --arg tn Bash --arg c "$line_cont_cmd" '{tool_name:$tn,tool_input:{command:$c}}')"
assert_eq "層1: バックスラッシュ+改行で分割されたpushも通過する（JSONエスケープをまたぐ反例）" "0" \
  "$(hints "$line_cont_payload")"

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

run_with_stub_jq_to_reply "$(payload 'Bash' 'ls -la .claude/hooks')"
assert_eq "層2: pushを含まないコマンドはjqを呼ばない" "0" "$REPLY_JQ_CALLED"

run_with_stub_jq_to_reply "$(payload 'Bash' 'git commit -m x')"
assert_eq "層2: git commitはjqを呼ばない（コミット側hookの担当）" "0" "$REPLY_JQ_CALLED"

run_with_stub_jq_to_reply ""
assert_eq "層2: 空入力はjqを呼ばずexit 0" "0" "$REPLY_JQ_CALLED"
assert_eq "層2: 空入力はexit 0" "0" "$REPLY_EXIT"

run_with_stub_jq_to_reply "$(payload 'Bash' 'git push -u origin HEAD')"
assert_eq "層2: git pushはjqを呼ぶ" "1" "$REPLY_JQ_CALLED"

run_with_stub_jq_to_reply "$(payload 'Bash' 'git -C /x push')"
assert_eq "層2: 語が非連続でもjqを呼ぶ" "1" "$REPLY_JQ_CALLED"

run_with_stub_jq_to_reply "$(payload 'Bash' 'echo "pushed already"')"
assert_eq "層2: pushという語を含むだけの無害なコマンドも過剰検知でjqを呼ぶ（無害）" "1" "$REPLY_JQ_CALLED"

run_with_stub_jq_to_reply "$line_cont_payload"
assert_eq "層2: バックスラッシュ+改行で分割されたpushもjqを呼ぶ" "1" "$REPLY_JQ_CALLED"

# --- 層3: 実リポジトリ相当での終了コード契約 --------------------------------

bp_repo="$fixture_dir/repo"
pc_script="$repo_root/.claude/scripts/src/push-checklist.sh"

setup_bp_repo() {
  rm -rf "$bp_repo"
  mkdir -p "$bp_repo/wip/plans" "$bp_repo/wip/worklogs" "$bp_repo/.claude/scripts/src/vcs"
  cp "$pc_script" "$bp_repo/.claude/scripts/src/"
  cp "$repo_root/.claude/scripts/src/vcs/Provider.sh" \
    "$repo_root/.claude/scripts/src/vcs/Github.sh" \
    "$repo_root/.claude/scripts/src/vcs/Gitlab.sh" "$bp_repo/.claude/scripts/src/vcs/"
  git -C "$bp_repo" init -q -b feature-17-checklist >/dev/null 2>&1 ||
    git -C "$bp_repo" init -q >/dev/null 2>&1
  git -C "$bp_repo" config user.email 'test@example.com'
  git -C "$bp_repo" config user.name 'test'
  printf '%s\n' \
    '{"defaultBaseBranch":"main","plansDir":"wip/plans","worklogDir":"wip/worklogs","reportsDir":"wip/reports"}' \
    >"$bp_repo/.mrworkflow.json"
  printf '個別計画\n' >"$bp_repo/wip/plans/【実装】テスト.md"
}

bp_commit_all() {
  git -C "$bp_repo" add -A >/dev/null 2>&1
  git -C "$bp_repo" commit -q -m "$1" >/dev/null 2>&1
}
bp_publish() {
  git -C "$bp_repo" update-ref refs/remotes/origin/main "$(git -C "$bp_repo" rev-parse HEAD)"
}
bp_pc() { (cd "$bp_repo" && bash "$bp_repo/.claude/scripts/src/push-checklist.sh" "$@"); }

# hookを実プロセスとして起動する。戻り値 REPLY_EXIT / REPLY_STDERR
run_hook_real() {
  # $1=tool_name $2=command （$3 を渡すと CLAUDE_PROJECT_DIR を空にする）
  local out no_dir="${3:-}"
  set +e
  if [ -n "$no_dir" ]; then
    out="$(payload "$1" "$2" | env -u CLAUDE_PROJECT_DIR -u GEMINI_PROJECT_DIR bash "$hook" 2>&1 >/dev/null)"
  else
    out="$(payload "$1" "$2" | env -u GEMINI_PROJECT_DIR CLAUDE_PROJECT_DIR="$bp_repo" bash "$hook" 2>&1 >/dev/null)"
  fi
  REPLY_EXIT=$?
  set -e
  REPLY_STDERR="$out"
}

# (a) HEADにチェックリストが無い（＝フローの対象外／初回）ときはブロックしない
setup_bp_repo
bp_commit_all 'init'
run_hook_real 'Bash' 'git push -u origin HEAD'
assert_eq "層3: HEADにチェックリストが無ければブロックしない" "0" "$REPLY_EXIT"

# (b) 未完了のチェックリストがHEADにあるとブロックする（exit 2）
bp_publish
bp_pc new >/dev/null
bp_commit_all 'checklist（未完了）'
run_hook_real 'Bash' 'git push -u origin HEAD'
assert_eq "層3: 未完了ならブロックする（exit 2）" "2" "$REPLY_EXIT"
assert_contains "層3: ブロックメッセージに未完了の項目名が入る" "$REPLY_STDERR" '未完了: worklog'
assert_contains "層3: ブロックメッセージにcommitスキルのパスが入る" "$REPLY_STDERR" \
  '.claude/skills/commit/SKILL.md'
assert_contains "層3: ブロックメッセージにspecのパスが入る" "$REPLY_STDERR" \
  '.claude/docs/spec/push-checklist.md'

# 語が非連続な push でも同じくブロックされる（精密判定まで到達している証拠）
run_hook_real 'Bash' 'git -C /x push'
assert_eq "層3: 語が非連続なgit pushもブロックする" "2" "$REPLY_EXIT"

# push以外のコマンドはブロックしない（未完了のチェックリストがあっても）
run_hook_real 'Bash' 'git status'
assert_eq "層3: push以外はブロックしない" "0" "$REPLY_EXIT"
run_hook_real 'Bash' 'echo "pushed already"'
assert_eq "層3: pushという語を含むだけのコマンドはブロックしない" "0" "$REPLY_EXIT"

# Gemini CLI 経路（run_shell_command）でも同じくブロックされる
run_hook_real 'run_shell_command' 'git push -u origin HEAD'
assert_eq "層3: run_shell_command（Gemini CLI経路）でもブロックする" "2" "$REPLY_EXIT"

# 対象外のtool_nameは素通り
run_hook_real 'Read' 'git push -u origin HEAD'
assert_eq "層3: 対象外のtool_nameは素通りする" "0" "$REPLY_EXIT"

# CLAUDE_PROJECT_DIR が無ければ何もしない（誤ってカレントのリポジトリを見に行かない）
run_hook_real 'Bash' 'git push -u origin HEAD' 'no-dir'
assert_eq "層3: project_dirが無ければ素通りする" "0" "$REPLY_EXIT"

# (c) 全件完了してコミットすれば通る
for id in worklog handoff frontmatter-index plan-report-sync commit-skill; do
  bp_pc check "$id" "テストで${id}を完了にした" >/dev/null
done
bp_commit_all 'checklist（全件完了）'
run_hook_real 'Bash' 'git push -u origin HEAD'
assert_eq "層3: 全件完了ならブロックしない" "0" "$REPLY_EXIT"

# (d) コミット忘れは非ブロックの警告（exit 1）。**exit 2 ではない**。
bp_publish
bp_pc new >/dev/null
run_hook_real 'Bash' 'git push -u origin HEAD'
assert_eq "層3: コミット忘れは非ブロックの警告（exit 1）" "1" "$REPLY_EXIT"
assert_contains "層3: 警告にコミット忘れの旨が入る" "$REPLY_STDERR" 'コミットされていないチェックリスト'

echo "passed=$passed failures=$failures"
[[ "$failures" -eq 0 ]]
