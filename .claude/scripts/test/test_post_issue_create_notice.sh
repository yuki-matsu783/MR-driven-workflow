#!/usr/bin/env bash
# .claude/hooks/post-issue-create-notice.sh の単体テスト（issue #39で新設）。
# ネットワーク・git操作を伴わない純粋関数（is_issue_create_call / write_additional_context /
# raw_hints_at_issue_create）と、「sourceしても本体が実行されない」ことを検証する。前置フィルタ
# （issue #159）はsourceして直接呼ぶ単体テストに加え、main()冒頭で実際に呼ばれ、jqより前に
# 足切りされることは関数の存在だけでは保証できないため、サブプロセス起動＋スタブjqでも検証する。
# 規約: passed=N failures=N を標準出力へ出し、失敗があれば終了コード1
#       （.claude/rules/shell-script-style.md「テスト」。test_session_start.sh を雛形にした）。
# 実行: bash .claude/scripts/test/test_post_issue_create_notice.sh
set -euo pipefail

script_dir="${BASH_SOURCE[0]%/*}"
[[ "$script_dir" == "${BASH_SOURCE[0]}" ]] && script_dir="."
repo_root="$(cd "$script_dir/../../.." && pwd)"

# source した時点で本体（stdin読み取り・コンテキスト注入）が走らないことが前提。
# 走ってしまう場合、ここでstdin待ちのままハングするか、JSONが標準出力へ漏れる。
# shellcheck source=../../../.claude/hooks/post-issue-create-notice.sh
source "$repo_root/.claude/hooks/post-issue-create-notice.sh"

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
    echo "  expected to contain: $needle"
    echo "  actual            : $haystack"
  fi
}

# is_issue_create_call の判定結果を 0/1 で受け取る。
# set -e 配下でコマンド置換に頼ると終了コードが取れないため if で受ける
# （.claude/rules/shell-script-style.md「テスト」）。
detect() {
  if is_issue_create_call "$1" "${2:-}" "${3:-}"; then
    printf '0'
  else
    printf '1'
  fi
}

# --- CLI経路（create-issue.sh の実行） ---
assert_eq "Bashでcreate-issue.shを実行したら起票と判定する" "0" \
  "$(detect 'Bash' '.claude/scripts/src/create-issue.sh --title "x" --purpose "y"' '')"
assert_eq "パスの前に別コマンドが連結されていても判定する" "0" \
  "$(detect 'Bash' 'cd /repo && bash .claude/scripts/src/create-issue.sh --title "x"' '')"
assert_eq "Gemini CLIのrun_shell_commandでも判定する" "0" \
  "$(detect 'run_shell_command' '.claude/scripts/src/create-issue.sh --title "x"' '')"
assert_eq "PowerShellでも判定する" "0" \
  "$(detect 'PowerShell' '.claude/scripts/src/create-issue.sh --title "x"' '')"
assert_eq "無関係なコマンドは対象外" "1" "$(detect 'Bash' 'git status' '')"
assert_eq "コマンドが空なら対象外" "1" "$(detect 'Bash' '' '')"

# --- CLI経路のコマンド位置判定（issue #149） ---
# is_issue_create_call は CommandPosition.sh 経由（_pin_cli_match）で判定する。source した
# このテストプロセスでは、post-issue-create-notice.sh 冒頭のトップレベル3段ガードが実行済みの
# ため、command_invokes_script を使った判定になっているはず（フォールバックへ縮退していない
# ことは、下の「cat/grepでは発火しない」ケースが 1（対象外）になることで確認できる——
# フォールバック（部分一致）のままなら、これらは誤って 0（起票と判定）になってしまう）。
assert_eq "改行区切りの2行目でも判定する" "0" \
  "$(detect 'Bash' "ls .claude/scripts/src/create-issue.sh
bash .claude/scripts/src/create-issue.sh --title x" '')"
assert_eq "ファイルを開くだけのcatでは発火しない" "1" \
  "$(detect 'Bash' 'cat .claude/scripts/src/create-issue.sh' '')"
assert_eq "ファイルを検索するだけのgrepでは発火しない" "1" \
  "$(detect 'Bash' 'grep -rn create-issue.sh .claude/' '')"
assert_eq "コメント内の言及では発火しない" "1" \
  "$(detect 'Bash' '# create-issue.shを実行するhook' '')"
assert_eq "ヒアドキュメント本文内の言及では発火しない" "1" \
  "$(detect 'Bash' "cat <<'EOF'
create-issue.shの説明
EOF" '')"

# --- MCP経路（gh/glab CLI不在時。issue #34） ---
assert_eq "issue_writeのmethod=createは起票と判定する" "0" \
  "$(detect 'mcp__github__issue_write' '' 'create')"
assert_eq "issue_writeでもmethod=updateは対象外" "1" \
  "$(detect 'mcp__github__issue_write' '' 'update')"
assert_eq "issue_write以外のMCPツールは対象外" "1" \
  "$(detect 'mcp__github__create_pull_request' '' 'create')"

# --- raw_hints_at_issue_create（前置フィルタの純粋関数。issue #159） ---
hints() {
  if raw_hints_at_issue_create "$1"; then
    printf '0'
  else
    printf '1'
  fi
}
assert_eq "create-issue.shを含む生JSONは通過する" "0" \
  "$(hints '{"tool_input":{"command":".claude/scripts/src/create-issue.sh --title x"}}')"
assert_eq "issue_writeを含む生JSONは通過する" "0" \
  "$(hints '{"tool_name":"mcp__github__issue_write","tool_input":{"method":"create"}}')"
assert_eq "無関係な生JSONは足切りされる" "1" "$(hints '{"tool_input":{"command":"git status"}}')"
assert_eq "空文字列は足切りされる" "1" "$(hints '')"
# CommandPosition.sh の正規化はバックスラッシュを落とすため（block-direct-git-commit.sh と
# 同じ理由）、is_issue_create_call が将来コマンド位置判定へ差し替わっても超集合であり続けるよう、
# 前置フィルタもバックスラッシュ分割・大文字小文字を吸収する。
assert_eq "create-\\issue.shのようにバックスラッシュで分割されていても通過する" "0" \
  "$(hints '{"tool_input":{"command":"bash .claude/scripts/src/create-\\issue.sh --title x"}}')"
assert_eq "大文字のCREATE-ISSUE.SHでも通過する" "0" \
  "$(hints '{"tool_input":{"command":"bash .claude/scripts/src/CREATE-ISSUE.SH --title x"}}')"
# 注意: is_issue_create_call の現行CLI経路判定（単純な部分一致）は "create-issue.sh" という
# 語自体にJSONエスケープを要する文字を含まないため、下記のJSON化テストは「現行の超集合関係を
# 保つために必須」ではない。block-direct-git-commit.sh の raw_hints_at_git_commit と同じ
# 正規化（JSONエスケープ列の除去）をここにも入れているのは、issue #149着手時に
# is_issue_create_call がコマンド位置判定へ差し替わった場合に備えた前倒しの安全マージンで
# あり、その正規化がJSONエンコードをまたいでも壊れずに動くことを確認する目的で置く
# （block-direct-git-commit.sh側で見つかった反例と同じ壊れ方をしないことの確認）。
create_issue_line_cont_cmd=$'bash .claude/scripts/src/create-\\\nissue.sh --title x'
create_issue_line_cont_payload="$(jq -nc --arg c "$create_issue_line_cont_cmd" '{tool_input:{command:$c}}')"
assert_eq "create-\\<改行>issue.shのようにバックスラッシュ+改行で分割されていても通過する（#149着手時の安全マージン確認）" "0" \
  "$(hints "$create_issue_line_cont_payload")"

# --- 注意文の内容 ---
assert_contains "注意文が同一セッションでのstart抑止に言及する" "$NOTICE_TEXT" '/issue-mr-flow start'
assert_contains "注意文が新しいセッションでの実行を勧める" "$NOTICE_TEXT" '新しいセッション'
assert_contains "注意文がHANDOFF.mdを更新しない旨に言及する" "$NOTICE_TEXT" 'HANDOFF.md'

# --- 出力JSONの形 ---
# 注意（`tr -d '\r'`）: Windowsネイティブjqは標準出力をテキストモードで開くため、`jq -r` が出力する
# 各行の行末にCRが付く。コマンド置換が落とすのは末尾の `\r\n` だけなので、**取り出す値が複数行の
# 場合、最終行以外のCRが残ったまま**assert_eqへ渡り、目視では同一に見える値で失敗する
# （issue #94。`NOTICE_TEXT` はまさに複数行）。`jq -r` の結果は必ずCRを除去してから比較する
# （.claude/rules/shell-script-style.md「文字コード」）。
context_json="$(write_additional_context "$NOTICE_TEXT")"
assert_eq "hookEventNameがPostToolUse" "PostToolUse" \
  "$(printf '%s' "$context_json" | jq -r '.hookSpecificOutput.hookEventName' | tr -d '\r')"
assert_eq "additionalContextへ注意文がそのまま入る" "$NOTICE_TEXT" \
  "$(printf '%s' "$context_json" | jq -r '.hookSpecificOutput.additionalContext' | tr -d '\r')"

# --- 前置フィルタ（issue #159）: main()冒頭の read + case による足切り ---
# raw_hints_at_issue_create 自体は上でsourceして直接テスト済みだが、main()冒頭で実際に
# 呼ばれ、jqより前に足切りされることは関数の存在だけでは保証できないため、hookスクリプトを
# サブプロセスとして起動して確認する。スタブjqは「呼ばれたらマーカーへ書いてから失敗する」
# ことで、足切りされたペイロードでjqが1回も呼ばれないことを時間計測ではなく呼び出し有無
# そのもので確認する。
hook="$repo_root/.claude/hooks/post-issue-create-notice.sh"
stub_dir="$(mktemp -d)"
trap 'rm -rf "$stub_dir"' EXIT
cat > "$stub_dir/jq" <<'EOF'
#!/usr/bin/env bash
echo "called" >> "$STUB_JQ_MARKER"
exit 1
EOF
chmod +x "$stub_dir/jq"

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

notice_payload() {
  # $1=tool_name $2=command $3=method
  jq -nc --arg tn "$1" --arg cmd "$2" --arg m "$3" \
    '{tool_name: $tn, tool_input: {command: $cmd, method: $m}}'
}

run_with_stub_jq_to_reply "$(notice_payload 'Bash' 'git status' '')"
assert_eq "起票と無関係なコマンドはjqを呼ばない" "0" "$REPLY_JQ_CALLED"
assert_eq "起票と無関係なコマンドはexit 0" "0" "$REPLY_EXIT"

run_with_stub_jq_to_reply ""
assert_eq "空入力はjqを呼ばない" "0" "$REPLY_JQ_CALLED"

run_with_stub_jq_to_reply "$(notice_payload 'mcp__github__create_pull_request' '' 'create')"
assert_eq "issue_write以外のMCPツールはjqを呼ばない" "0" "$REPLY_JQ_CALLED"

run_with_stub_jq_to_reply "$(notice_payload 'Bash' 'bash .claude/scripts/src/create-issue.sh --title x' '')"
assert_eq "CLI経路（create-issue.sh）はjqを呼ぶ" "1" "$REPLY_JQ_CALLED"

run_with_stub_jq_to_reply "$(notice_payload 'Bash' 'cd /repo && bash .claude/scripts/src/create-issue.sh --title x' '')"
assert_eq "語が連続しない複合コマンドでもjqを呼ぶ" "1" "$REPLY_JQ_CALLED"

run_with_stub_jq_to_reply "$(notice_payload 'mcp__github__issue_write' '' 'create')"
assert_eq "MCP経路（issue_write, method=create）はjqを呼ぶ" "1" "$REPLY_JQ_CALLED"

run_with_stub_jq_to_reply "$(notice_payload 'mcp__github__issue_write' '' 'update')"
assert_eq "MCP経路はmethodの値に関わらずjqを呼ぶ（前置フィルタは足切りでmethodまでは絞らない）" "1" "$REPLY_JQ_CALLED"

# --- 超集合性: 実際のjqを使い、精密判定まで到達して注意文が注入されるか ---
run_hook_real() {
  # $1=tool_name $2=command $3=method 。戻り値 REPLY_STDOUT
  REPLY_STDOUT="$(notice_payload "$1" "$2" "$3" | bash "$hook")"
}

run_hook_real 'Bash' 'bash .claude/scripts/src/create-issue.sh --title x' ''
assert_contains "CLI経路は実際に注意文を注入する" "$REPLY_STDOUT" 'additionalContext'

run_hook_real 'Bash' 'git status' ''
assert_eq "無関係なコマンドは何も出力しない" "" "$REPLY_STDOUT"

# --- 3段ガードの縮退経路（ライブラリ非存在時。issue #149, 2回目レビュー） ---
# 通常のテスト実行では lib/CommandPosition.sh が常に存在するため、_pin_cli_match は初回呼び出しで
# 必ずコマンド位置判定へ差し替わり、既定値（部分一致）の分岐が一度も通らない
# （3段ガードの「担保が働くか」自体を確かめるテストが無かった。敵対的レビューで指摘）。
# ライブラリを意図的に置かない環境を再現し、縮退した部分一致が実際に機能することを確認する。
fallback_dir="$(mktemp -d)"
trap 'rm -rf "$stub_dir" "$fallback_dir"' EXIT
cp "$hook" "$fallback_dir/post-issue-create-notice.sh"
# lib/ を置かない（=> CommandPosition.sh を読み込めない => 部分一致へ縮退する）。

run_hook_fallback() {
  # $1=command 。戻り値 REPLY_STDOUT
  REPLY_STDOUT="$(notice_payload 'Bash' "$1" '' | bash "$fallback_dir/post-issue-create-notice.sh")"
}

# `cat <script>` は位置判定なら miss だが、縮退時の既定値（部分一致）では hit になる。
# 位置判定と縮退後の判定が区別できる入力を使うことで、縮退が実際に効いていることを確認する。
run_hook_fallback 'cat .claude/scripts/src/create-issue.sh'
assert_contains "ライブラリ非存在時は部分一致へ縮退し、catでも発火する" "$REPLY_STDOUT" 'additionalContext'

run_hook_fallback 'git status'
assert_eq "ライブラリ非存在時でも無関係なコマンドでは発火しない" "" "$REPLY_STDOUT"

echo "passed=$passed failures=$failures"
[[ "$failures" -eq 0 ]]
