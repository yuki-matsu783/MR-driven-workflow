#!/usr/bin/env bash
# .claude/hooks/block-direct-git-commit.sh の単体テスト（issue #159で新設）。
#
# 判定本体（command_invokes_git_subcommand）は .claude/scripts/test/test_command_position.sh が
# 既にテストしているため、ここでは前置フィルタ（raw_hints_at_git_commit・純粋関数）を対象にする。
# 前置フィルタ自体は source して直接テストできるが、「main()冒頭で実際に呼ばれ、jqより前に
# 足切りするか」は関数の存在だけでは保証できないため、あわせてフックスクリプトをサブプロセスとして
# 起動し、標準入力へJSONペイロードを流し込んで確認する。
#
# 規約: passed=N failures=N を標準出力へ出し、失敗があれば終了コード1
#       （.claude/rules/shell-script-style.md「テスト」）。
# 実行: bash .claude/scripts/test/test_block_direct_git_commit.sh
set -euo pipefail

script_dir="${BASH_SOURCE[0]%/*}"
[[ "$script_dir" == "${BASH_SOURCE[0]}" ]] && script_dir="."
repo_root="$(cd "$script_dir/../../.." && pwd)"
hook="$repo_root/.claude/hooks/block-direct-git-commit.sh"

# source した時点で本体（stdin読み取り）が走らないことが前提
# （.claude/rules/shell-script-style.md「テスト」）。
# shellcheck source=../../../.claude/hooks/block-direct-git-commit.sh
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

# raw_hints_at_git_commit の判定結果を 0/1 で受け取る
# （set -e 配下でコマンド置換に頼ると終了コードが取れないためifで受ける。
# .claude/rules/shell-script-style.md「テスト」）。
hints() {
  if raw_hints_at_git_commit "$1"; then
    printf '0'
  else
    printf '1'
  fi
}

# --- raw_hints_at_git_commit（純粋関数）の単体テスト ---
assert_eq "git commitを含む生JSONは通過する" "0" "$(hints '{"tool_input":{"command":"git commit -m x"}}')"
assert_eq "gitとcommitが非連続（語が連続しない形）でも通過する" "0" \
  "$(hints '{"tool_input":{"command":"git -C /x commit -m x"}}')"
assert_eq "大文字のCOMMITでも通過する" "0" "$(hints '{"tool_input":{"command":"git COMMIT -m x"}}')"
assert_eq "commitと無関係なコマンドは足切りされる" "1" "$(hints '{"tool_input":{"command":"git status"}}')"
assert_eq "空文字列は足切りされる" "1" "$(hints '')"

# --- バックスラッシュによる語の分割（敵対的レビューで検出。issue #159） ---
# CommandPosition.sh の正規化は `\x`（xが[A-Za-z0-9_./-]）のバックスラッシュを落として
# xだけを残すため、`com\mit` のように commit という語の途中へバックスラッシュを挟んでも
# 精密判定は「commit」として拾う。前置フィルタも同じ結果になることを固定する。
assert_eq "com\\mitのようにバックスラッシュで分割されたcommitも通過する（超集合の反例対策）" "0" \
  "$(hints '{"tool_input":{"command":"git com\\mit -m x"}}')"
assert_eq "\\gitでエイリアスを迂回する書式でも通過する" "0" \
  "$(hints '{"tool_input":{"command":"\\git commit -m x"}}')"

# --- JSONエスケープ列をまたぐ語の分割（作業結果への敵対的レビューで検出。issue #159） ---
# raw_hints_at_git_commit が受け取るのはjqデコード前の生JSON文字列。実コマンド中の
# バックスラッシュ＋改行（行継続）は、JSON化すると `\\\n`（バックスラッシュ3つ＋n）になる。
# バックスラッシュだけを除去する初版ではこの `n` が単独で残り `comnmit` になって
# 一致しなくなっていた（超集合が壊れる反例）。jqでJSONを正しく組み立てて固定する。
line_cont_cmd=$'git com\\\nmit -m "x"'
line_cont_payload="$(jq -nc --arg c "$line_cont_cmd" '{tool_input:{command:$c}}')"
assert_eq "バックスラッシュ+改行(行継続)で分割されたcommitも通過する（JSONエスケープをまたぐ反例対策）" "0" \
  "$(hints "$line_cont_payload")"

# --- スタブjq: 呼ばれたらマーカーファイルへ1行書いてから失敗する。
# 「足切りされたペイロードではjqが1回も呼ばれない」ことを、時間計測ではなく
# 呼び出し有無そのもので確認するため（issue #159の受け入れ条件）。
stub_dir="$(mktemp -d)"
trap 'rm -rf "$stub_dir"' EXIT
cat > "$stub_dir/jq" <<'EOF'
#!/usr/bin/env bash
echo "called" >> "$STUB_JQ_MARKER"
exit 1
EOF
chmod +x "$stub_dir/jq"

# ペイロードをhookへ渡し、スタブjqが呼ばれたか（マーカーの有無）と終了コードを返す。
# 戻り値はグローバル REPLY_EXIT / REPLY_JQ_CALLED（shell-script-style.md「REPLYへ返す」）。
run_with_stub_jq_to_reply() {
  local payload="$1"
  local marker; marker="$(mktemp -u)"
  : > "$marker"
  local exit_code=0
  printf '%s' "$payload" | PATH="$stub_dir:$PATH" STUB_JQ_MARKER="$marker" \
    bash "$hook" >/dev/null 2>/dev/null || exit_code=$?
  REPLY_EXIT="$exit_code"
  if [[ -s "$marker" ]]; then
    REPLY_JQ_CALLED=1
  else
    REPLY_JQ_CALLED=0
  fi
  rm -f "$marker"
}

payload() {
  # $1=tool_name $2=command
  jq -nc --arg tn "$1" --arg cmd "$2" '{tool_name: $tn, tool_input: {command: $cmd}}'
}

# --- 足切りされるべきペイロード: jqが1回も呼ばれず、exit 0 ---
run_with_stub_jq_to_reply "$(payload 'Bash' 'git status')"
assert_eq "無関係なコマンドはjqを呼ばずexit 0" "0" "$REPLY_JQ_CALLED"
assert_eq "無関係なコマンドはexit 0" "0" "$REPLY_EXIT"

run_with_stub_jq_to_reply "$(payload 'Bash' 'ls -la .claude/hooks')"
assert_eq "commitを含まないコマンドはjqを呼ばない" "0" "$REPLY_JQ_CALLED"

run_with_stub_jq_to_reply "$(payload 'Bash' 'git -C /x push')"
assert_eq "commitと無関係なgit push（語が非連続）はjqを呼ばない" "0" "$REPLY_JQ_CALLED"

run_with_stub_jq_to_reply "$(payload 'Read' 'irrelevant')"
assert_eq "Bash/PowerShell以外のtool_nameでもcommitが無ければjqを呼ばない" "0" "$REPLY_JQ_CALLED"

run_with_stub_jq_to_reply ""
assert_eq "空入力はjqを呼ばずexit 0" "0" "$REPLY_JQ_CALLED"
assert_eq "空入力はexit 0" "0" "$REPLY_EXIT"

# --- 通過すべきペイロード（超集合）: jqが呼ばれる ---
run_with_stub_jq_to_reply "$(payload 'Bash' 'git commit -m "fix"')"
assert_eq "git commitはjqを呼ぶ" "1" "$REPLY_JQ_CALLED"

run_with_stub_jq_to_reply "$(payload 'Bash' 'git -C /x commit -m "fix"')"
assert_eq "gitとcommitが非連続でもjqを呼ぶ（語が連続しない形）" "1" "$REPLY_JQ_CALLED"

run_with_stub_jq_to_reply "$(payload 'Bash' 'git COMMIT -m "fix"')"
assert_eq "大文字のCOMMITでもjqを呼ぶ" "1" "$REPLY_JQ_CALLED"

run_with_stub_jq_to_reply "$(payload 'Bash' 'echo "committed already"')"
assert_eq "commitという語を含むだけの無害なコマンドも過剰検知でjqを呼ぶ（無害な超過検知）" "1" "$REPLY_JQ_CALLED"

run_with_stub_jq_to_reply "$line_cont_payload"
assert_eq "バックスラッシュ+改行(行継続)で分割されたcommitもjqを呼ぶ" "1" "$REPLY_JQ_CALLED"

# --- 超集合性: 実際のjqを使い、精密判定まで到達して正しくブロックされるか ---
run_hook_real() {
  # $1=tool_name $2=command 。戻り値 REPLY_EXIT / REPLY_STDERR
  local out
  set +e
  out="$(payload "$1" "$2" | bash "$hook" 2>&1 >/dev/null)"
  REPLY_EXIT=$?
  set -e
  REPLY_STDERR="$out"
}

run_hook_real 'Bash' 'git -C /x commit -m "fix"'
assert_eq "語が非連続なgit commitは精密判定まで到達しブロックされる（exit 2）" "2" "$REPLY_EXIT"

run_hook_real 'Bash' 'git commit -m "fix"'
assert_eq "通常のgit commitはブロックされる" "2" "$REPLY_EXIT"

run_hook_real 'Bash' "$line_cont_cmd"
assert_eq "com\\<改行>mitのようにバックスラッシュ+改行で分割されたcommitも精密判定まで到達しブロックされる（exit 2。作業結果への敵対的レビューで検出した反例の回帰テスト）" "2" "$REPLY_EXIT"

run_hook_real 'Bash' 'git com\mit -m "x"'
assert_eq "com\\mitのようにバックスラッシュで分割されたcommitも精密判定まで到達しブロックされる（exit 2）" "2" "$REPLY_EXIT"

run_hook_real 'Bash' 'git status'
assert_eq "git statusはブロックされない" "0" "$REPLY_EXIT"

run_hook_real 'Bash' 'git -C /x push'
assert_eq "git pushはブロックされない" "0" "$REPLY_EXIT"

run_hook_real 'Bash' 'bash .claude/scripts/src/create-commit.sh --message "x" -- a.txt'
assert_eq "create-commit.sh経由の呼び出しはブロックされない" "0" "$REPLY_EXIT"

echo "passed=$passed failures=$failures"
[[ "$failures" -eq 0 ]]
