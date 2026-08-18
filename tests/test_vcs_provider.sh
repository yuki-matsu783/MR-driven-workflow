#!/usr/bin/env bash
# .claude/scripts/src/vcs/{Github,Gitlab}.sh の純粋ロジック（`gh`/`glab`呼び出しを伴わない
# URL組み立て関数）の単体テスト。issue #13対応で追加した
# `github_get_mr_diff_url` / `github_get_mr_diff_since_url` /
# `gitlab_get_mr_diff_url` / `gitlab_get_mr_diff_since_url` が対象。
# Provider.sh経由のディスパッチ（`get_mr_diff_url`等）は `git remote get-url origin` に依存し
# 純粋ではないため対象外（Github.sh/Gitlab.sh の関数を直接呼ぶ）。
# 規約: passed=N failures=N を標準出力へ出し、失敗があれば終了コード1
#       （.claude/rules/shell-script-style.md「テスト」）。
# 実行: bash tests/test_vcs_provider.sh
set -euo pipefail

script_dir="${BASH_SOURCE[0]%/*}"
[[ "$script_dir" == "${BASH_SOURCE[0]}" ]] && script_dir="."
repo_root="$(cd "$script_dir/.." && pwd)"

# shellcheck source=../.claude/scripts/src/vcs/Github.sh
source "$repo_root/.claude/scripts/src/vcs/Github.sh"
# shellcheck source=../.claude/scripts/src/vcs/Gitlab.sh
source "$repo_root/.claude/scripts/src/vcs/Gitlab.sh"

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

# --- github_get_mr_diff_url ---------------------------------------------------

assert_eq "github_get_mr_diff_url: PR URLに/filesを付与" \
  "https://github.com/o/r/pull/13/files" \
  "$(github_get_mr_diff_url "https://github.com/o/r/pull/13")"

# --- github_get_mr_diff_since_url ----------------------------------------------

assert_eq "github_get_mr_diff_since_url: from..toのコミット範囲URLを組み立てる" \
  "https://github.com/o/r/pull/13/files/aaa111..bbb222" \
  "$(github_get_mr_diff_since_url "https://github.com/o/r/pull/13" "aaa111" "bbb222")"

# --- gitlab_get_mr_diff_url -----------------------------------------------------

assert_eq "gitlab_get_mr_diff_url: MR URLに/diffsを付与" \
  "https://gitlab.example.com/o/r/-/merge_requests/13/diffs" \
  "$(gitlab_get_mr_diff_url "https://gitlab.example.com/o/r/-/merge_requests/13")"

# --- gitlab_get_mr_diff_since_url ------------------------------------------------

assert_eq "gitlab_get_mr_diff_since_url: start_shaクエリを付与（to_shaは未使用）" \
  "https://gitlab.example.com/o/r/-/merge_requests/13/diffs?start_sha=aaa111" \
  "$(gitlab_get_mr_diff_since_url "https://gitlab.example.com/o/r/-/merge_requests/13" "aaa111" "bbb222")"

echo "passed=$passed failures=$failures"
[ "$failures" -eq 0 ]
