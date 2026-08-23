#!/usr/bin/env bash
# .claude/scripts/src/check-doc-references.sh の単体テスト（issue #171）。
# 外部コマンド呼び出しを伴わない純粋関数（is_excluded_target_path / is_placeholder_candidate /
# is_fence_delimiter_line / strip_fenced_lines_to_reply / extract_ddr_candidates_to_reply）
# のみを対象とする。git操作・ファイルシステムの実在確認を伴うmainは対象外
# （.claude/scripts/test/では実リポジトリを汚さない方針）。
# 規約: passed=N failures=N を標準出力へ出し、失敗があれば終了コード1
#       （.claude/rules/shell-script-style.md「テスト」）。
# 実行: bash .claude/scripts/test/test_check_doc_references.sh
set -euo pipefail

script_dir="${BASH_SOURCE[0]%/*}"
[[ "$script_dir" == "${BASH_SOURCE[0]}" ]] && script_dir="."
repo_root="$(cd "$script_dir/../../.." && pwd)"

# shellcheck source=../../../.claude/scripts/src/check-doc-references.sh
source "$repo_root/.claude/scripts/src/check-doc-references.sh"

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

assert_true() {
  local name="$1"
  if "$2" "${@:3}"; then
    passed=$((passed + 1))
  else
    failures=$((failures + 1))
    echo "FAIL: $name (expected true)"
  fi
}

assert_false() {
  local name="$1"
  if "$2" "${@:3}"; then
    failures=$((failures + 1))
    echo "FAIL: $name (expected false)"
  else
    passed=$((passed + 1))
  fi
}

# --- is_excluded_target_path -------------------------------------------------

assert_true  "is_excluded_target_path: .claude/scripts/test/配下は除外" \
  is_excluded_target_path ".claude/scripts/test/test_foo.sh"
assert_true  "is_excluded_target_path: plans/配下は除外" \
  is_excluded_target_path "plans/【調査】foo.md"
assert_true  "is_excluded_target_path: reports/配下は除外" \
  is_excluded_target_path "reports/20260101_foo.md"
assert_true  "is_excluded_target_path: worklog/配下は除外" \
  is_excluded_target_path "worklog/20260101_foo_push1.md"
assert_false "is_excluded_target_path: .claude/docs/spec/配下は除外しない" \
  is_excluded_target_path ".claude/docs/spec/foo.md"
assert_false "is_excluded_target_path: .gitignoreは除外しない" \
  is_excluded_target_path ".gitignore"

# --- is_placeholder_candidate -------------------------------------------------

assert_true  "is_placeholder_candidate: 半角三点リーダーを含む" \
  is_placeholder_candidate ".claude/docs/ddr/i0032-01-...Default.mdを正とし...md"
assert_true  "is_placeholder_candidate: 全角三点リーダー（…）を含む" \
  is_placeholder_candidate ".claude/docs/ddr/i0000-13-gemini配下は…md"
assert_false "is_placeholder_candidate: 省略記法を含まない" \
  is_placeholder_candidate ".claude/docs/ddr/i0036-01-frontmatterのindex.jsonlをGit管理から外しSessionStart-hookで生成する.md"

# --- is_fence_delimiter_line -------------------------------------------------

assert_true  "is_fence_delimiter_line: 行頭のバッククォート3連" \
  is_fence_delimiter_line '```bash'
assert_true  "is_fence_delimiter_line: インデントされたフェンス" \
  is_fence_delimiter_line '  ```markdown'
assert_true  "is_fence_delimiter_line: チルダ3連" \
  is_fence_delimiter_line '~~~'
assert_false "is_fence_delimiter_line: 通常の本文行" \
  is_fence_delimiter_line 'これは通常の説明文です。'
assert_false "is_fence_delimiter_line: 行中にバッククォート3連があっても行頭でなければ対象外" \
  is_fence_delimiter_line 'コード片は ```foo``` のように書く'

# --- strip_fenced_lines_to_reply ---------------------------------------------

REPLY=""
strip_fenced_lines_to_reply $'本文1\n```\n参照: .claude/docs/ddr/i9999-99-架空.md\n```\n本文2'
assert_eq "strip_fenced_lines_to_reply: 閉じたフェンス内の行を除外する" \
  $'本文1\n本文2\n' "$REPLY"

REPLY=""
strip_fenced_lines_to_reply $'本文1\n  ```markdown\n参照: .claude/docs/ddr/i9999-99-架空.md\n  ```\n本文2'
assert_eq "strip_fenced_lines_to_reply: インデントされたフェンスも除外する" \
  $'本文1\n本文2\n' "$REPLY"

REPLY=""
strip_fenced_lines_to_reply $'本文1\n```\n参照: .claude/docs/ddr/i9999-99-架空.md\n本文2'
assert_eq "strip_fenced_lines_to_reply: フェンスが未閉鎖（奇数回）なら除外しない（安全側）" \
  $'本文1\n```\n参照: .claude/docs/ddr/i9999-99-架空.md\n本文2' "$REPLY"

# --- extract_ddr_candidates_to_reply ------------------------------------------

REPLY_CANDIDATES=()
extract_ddr_candidates_to_reply '.gitignoreの28行目は.claude/docs/ddr/i0000-13-gemini配下はGit管理下に置かずセットアップスクリプトで生成する.mdを参照する。'
assert_eq "extract: 通常のDDRパスを1件抽出する" \
  ".claude/docs/ddr/i0000-13-gemini配下はGit管理下に置かずセットアップスクリプトで生成する.md" \
  "${REPLY_CANDIDATES[0]:-}"
assert_eq "extract: 抽出件数は1件" "1" "${#REPLY_CANDIDATES[@]}"

REPLY_CANDIDATES=()
extract_ddr_candidates_to_reply '存在しない参照: .claude/docs/ddr/i9999-99-架空のDDR.mdを見よ'
assert_eq "extract: 存在しないパスも文字列として抽出する（実在確認はmain側の責務）" \
  ".claude/docs/ddr/i9999-99-架空のDDR.md" "${REPLY_CANDIDATES[0]:-}"

REPLY_CANDIDATES=()
extract_ddr_candidates_to_reply '（仕様: .claude/docs/spec/create-commit.md、経緯: .claude/docs/ddr/i0060-01-create-commitは削除ステージ済みパスをgit-addの失敗時分類で吸収する.md）。'
assert_eq "extract: 貪欲マッチでファイル名自体に.mdを含まないケースも正しく1本になる" \
  ".claude/docs/ddr/i0060-01-create-commitは削除ステージ済みパスをgit-addの失敗時分類で吸収する.md" \
  "${REPLY_CANDIDATES[0]:-}"

# 実際にDDR名自体が「.md」という文字列を含むケース（貪欲マッチの境界値。省略記法を含まない実名）
REPLY_CANDIDATES=()
extract_ddr_candidates_to_reply '（詳細: .claude/docs/ddr/i0032-01-GitLab-issueテンプレートは予約名Default.mdを正とし文書側を合わせる.md）'
assert_eq "extract: ファイル名自体に.mdを含むDDRでも貪欲マッチで末尾まで一致する" \
  ".claude/docs/ddr/i0032-01-GitLab-issueテンプレートは予約名Default.mdを正とし文書側を合わせる.md" \
  "${REPLY_CANDIDATES[0]:-}"

tab_char=$'\t'
REPLY_CANDIDATES=()
extract_ddr_candidates_to_reply ".claude/docs/ddr/i0000-13-gemini配下はGit管理下に置かずセットアップスクリプトで生成する.md${tab_char}.claude/docs/ddr/i0036-01-frontmatterのindex.jsonlをGit管理から外しSessionStart-hookで生成する.md"
assert_eq "extract: タブ区切りで並ぶ2パスは2件の独立した候補になる" "2" "${#REPLY_CANDIDATES[@]}"
assert_eq "extract: タブ区切りの1件目" \
  ".claude/docs/ddr/i0000-13-gemini配下はGit管理下に置かずセットアップスクリプトで生成する.md" \
  "${REPLY_CANDIDATES[0]:-}"
assert_eq "extract: タブ区切りの2件目" \
  ".claude/docs/ddr/i0036-01-frontmatterのindex.jsonlをGit管理から外しSessionStart-hookで生成する.md" \
  "${REPLY_CANDIDATES[1]:-}"

REPLY_CANDIDATES=()
extract_ddr_candidates_to_reply '枝番が1桁のケース: .claude/docs/ddr/i0133-1-枝番ゼロ埋め漏れ.mdを参照。'
assert_eq "extract: 枝番1桁（ゼロ埋め漏れ）も候補として抽出される" \
  ".claude/docs/ddr/i0133-1-枝番ゼロ埋め漏れ.md" "${REPLY_CANDIDATES[0]:-}"

REPLY_CANDIDATES=()
extract_ddr_candidates_to_reply '枝番が3桁のケース: .claude/docs/ddr/i0133-013-枝番3桁.mdを参照。'
assert_eq "extract: 枝番3桁も候補として抽出される" \
  ".claude/docs/ddr/i0133-013-枝番3桁.md" "${REPLY_CANDIDATES[0]:-}"

REPLY_CANDIDATES=()
extract_ddr_candidates_to_reply '本文中にDDRパスが無い普通の行'
assert_eq "extract: 該当箇所が無ければ0件" "0" "${#REPLY_CANDIDATES[@]}"

echo "passed=$passed failures=$failures"
[[ "$failures" -eq 0 ]]
