#!/usr/bin/env bash
# .claude/scripts/src/check-base-sync.sh の単体テスト（issue #67）。
# 外部コマンド呼び出しを伴わない純粋関数（parse_left_right_to_reply / truncate_file_list）
# のみを対象とする。git操作を伴うmainは対象外（.claude/scripts/test/では実リポジトリを汚さない方針）。
# 規約: passed=N failures=N を標準出力へ出し、失敗があれば終了コード1
#       （.claude/rules/shell-script-style.md「テスト」。test_check_base_conflicts.sh を雛形にした）。
# 実行: bash .claude/scripts/test/test_check_base_sync.sh
set -euo pipefail

script_dir="${BASH_SOURCE[0]%/*}"
[[ "$script_dir" == "${BASH_SOURCE[0]}" ]] && script_dir="."
repo_root="$(cd "$script_dir/../../.." && pwd)"

# shellcheck source=../../../.claude/scripts/src/check-base-sync.sh
source "$repo_root/.claude/scripts/src/check-base-sync.sh"

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

# --- parse_left_right_to_reply -------------------------------------------

# 終了コードは `if` の条件式で受ける（`"$(func; echo $?)"` は set -e 配下で空文字列になりうる。
# .claude/rules/shell-script-style.md「テスト」）。
REPLY_BEHIND=""; REPLY_AHEAD=""
parse_left_right_to_reply "$(printf '4\t1')"
assert_eq "parse: behindを取り出す" "4" "$REPLY_BEHIND"
assert_eq "parse: aheadを取り出す" "1" "$REPLY_AHEAD"

REPLY_BEHIND=""; REPLY_AHEAD=""
parse_left_right_to_reply "$(printf '0\t0')"
assert_eq "parse: 両方0（追従済み）" "0" "$REPLY_BEHIND"
assert_eq "parse: 両方0（aheadも0）" "0" "$REPLY_AHEAD"

REPLY_BEHIND=""; REPLY_AHEAD=""
parse_left_right_to_reply "$(printf '1234\t5678')"
assert_eq "parse: 桁数が多くても扱える" "1234" "$REPLY_BEHIND"
assert_eq "parse: 桁数が多くても扱える（ahead）" "5678" "$REPLY_AHEAD"

# WindowsネイティブjqのCR付与や、CRLFで受け取った場合の保険
REPLY_BEHIND=""; REPLY_AHEAD=""
parse_left_right_to_reply "$(printf '3\t2\r')"
assert_eq "parse: 末尾のCRを取り除く" "2" "$REPLY_AHEAD"

# 区切りがスペースでも読める（gitはTABを出すが、区切りの種類に依存しない）
REPLY_BEHIND=""; REPLY_AHEAD=""
parse_left_right_to_reply "7 8"
assert_eq "parse: スペース区切りでも読める" "7" "$REPLY_BEHIND"

if parse_left_right_to_reply ""; then empty_status=0; else empty_status=1; fi
assert_eq "parse: 空文字列は終了コード1" "1" "$empty_status"
assert_eq "parse: 空文字列ならREPLY_BEHINDは空" "" "$REPLY_BEHIND"
assert_eq "parse: 空文字列ならREPLY_AHEADは空" "" "$REPLY_AHEAD"

if parse_left_right_to_reply "4"; then single_status=0; else single_status=1; fi
assert_eq "parse: 数値が1つだけなら終了コード1" "1" "$single_status"

if parse_left_right_to_reply "$(printf 'a\tb')"; then nonnum_status=0; else nonnum_status=1; fi
assert_eq "parse: 数値でなければ終了コード1" "1" "$nonnum_status"

if parse_left_right_to_reply "$(printf -- '-1\t2')"; then neg_status=0; else neg_status=1; fi
assert_eq "parse: 負数は受け付けない" "1" "$neg_status"

if parse_left_right_to_reply "$(printf '1\t2\t3')"; then three_status=0; else three_status=1; fi
assert_eq "parse: 3つ以上は受け付けない" "1" "$three_status"

# --- truncate_file_list --------------------------------------------------

REPLY_FILES="x"; REPLY_TOTAL="x"
truncate_file_list "" 50
assert_eq "truncate: 空入力は0件" "0" "$REPLY_TOTAL"
assert_eq "truncate: 空入力の一覧は空文字列" "" "$REPLY_FILES"

REPLY_FILES=""; REPLY_TOTAL=""
truncate_file_list "a.md" 50
assert_eq "truncate: 1件" "1" "$REPLY_TOTAL"
assert_eq "truncate: 1件の一覧" "a.md" "$REPLY_FILES"

REPLY_FILES=""; REPLY_TOTAL=""
truncate_file_list "$(printf 'a\nb\nc')" 3
assert_eq "truncate: 上限ちょうどなら全件" "3" "$REPLY_TOTAL"
assert_eq "truncate: 上限ちょうどの一覧" "$(printf 'a\nb\nc')" "$REPLY_FILES"

REPLY_FILES=""; REPLY_TOTAL=""
truncate_file_list "$(printf 'a\nb\nc\nd')" 3
assert_eq "truncate: 上限+1件でも全件数は失わない" "4" "$REPLY_TOTAL"
assert_eq "truncate: 上限+1件なら先頭3件へ切り詰める" "$(printf 'a\nb\nc')" "$REPLY_FILES"

REPLY_FILES=""; REPLY_TOTAL=""
truncate_file_list "$(printf 'a\n\nb\n')" 50
assert_eq "truncate: 空行は数えない" "2" "$REPLY_TOTAL"
assert_eq "truncate: 空行を除いた一覧" "$(printf 'a\nb')" "$REPLY_FILES"

# 日本語を含むパス（このリポジトリの plans/【調査】〜.md 等）が壊れないこと。
# 先頭を ${var:0:N} で切り出す比較は使わない（バイト単位で切られマルチバイト文字が壊れる。
# .claude/rules/shell-script-style.md「テスト」）。
REPLY_FILES=""; REPLY_TOTAL=""
truncate_file_list "$(printf 'plans/【調査】ベースブランチ.md\n.claude/rules/shell-script-style.md')" 50
assert_eq "truncate: 日本語を含むパスの件数" "2" "$REPLY_TOTAL"
assert_eq "truncate: 日本語を含むパスが壊れない" \
  "plans/【調査】ベースブランチ.md" "$(printf '%s' "$REPLY_FILES" | head -1)"

REPLY_FILES=""; REPLY_TOTAL=""
truncate_file_list "$(printf 'a\nb')" 0
assert_eq "truncate: 上限0なら一覧は空だが件数は残る" "2" "$REPLY_TOTAL"
assert_eq "truncate: 上限0の一覧" "" "$REPLY_FILES"

echo "passed=$passed failures=$failures"
[[ "$failures" -eq 0 ]]
