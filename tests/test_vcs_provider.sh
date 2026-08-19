#!/usr/bin/env bash
# .claude/scripts/src/vcs/{Github,Gitlab}.sh の純粋ロジック（`gh`/`glab`呼び出しを伴わない
# URL組み立て関数）の単体テスト。issue #13対応で追加した
# `github_get_compare_url` / `github_get_mr_diff_url` / `github_get_mr_diff_since_url` /
# `gitlab_get_compare_url` / `gitlab_get_mr_diff_url` / `gitlab_get_mr_diff_since_url` が対象。
# `github_get_repo_url` / `gitlab_get_repo_url`（`gh repo view` / `glab repo view`を呼ぶ）と
# Provider.sh経由のディスパッチ（`get_mr_diff_url`等）は外部コマンド・`git remote get-url origin`
# に依存し純粋ではないため対象外（Github.sh/Gitlab.sh の関数を直接呼ぶ）。
# あわせてissue #34で追加した `parse_repo_slug`（リモートURLのパース）と `mcp_tool_hint`
# （CLI不在時に提示するMCPツール名）も対象とする。後者は `get_provider` をテスト内で上書きして
# プロバイダを固定する。
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

# --- github_get_compare_url / github_get_mr_diff_url / github_get_mr_diff_since_url -------

assert_eq "github_get_compare_url: リポジトリURLに/compare/<from>...<to>を付与" \
  "https://github.com/o/r/compare/main...aaa111" \
  "$(github_get_compare_url "https://github.com/o/r" "main" "aaa111")"

assert_eq "github_get_mr_diff_url: defaultブランチとの比較URL（ブランチ名指定）" \
  "https://github.com/o/r/compare/main...feature-13-x" \
  "$(github_get_mr_diff_url "https://github.com/o/r" "main" "feature-13-x")"

assert_eq "github_get_mr_diff_since_url: 前回push〜今回pushのSHA範囲の比較URL" \
  "https://github.com/o/r/compare/aaa111...bbb222" \
  "$(github_get_mr_diff_since_url "https://github.com/o/r" "aaa111" "bbb222")"

# --- gitlab_get_compare_url / gitlab_get_mr_diff_url / gitlab_get_mr_diff_since_url --------

assert_eq "gitlab_get_compare_url: リポジトリURLに/-/compare/<from>...<to>を付与" \
  "https://gitlab.example.com/o/r/-/compare/main...aaa111" \
  "$(gitlab_get_compare_url "https://gitlab.example.com/o/r" "main" "aaa111")"

assert_eq "gitlab_get_mr_diff_url: defaultブランチとの比較URL（ブランチ名指定）" \
  "https://gitlab.example.com/o/r/-/compare/main...feature-13-x" \
  "$(gitlab_get_mr_diff_url "https://gitlab.example.com/o/r" "main" "feature-13-x")"

assert_eq "gitlab_get_mr_diff_since_url: 前回push〜今回pushのSHA範囲の比較URL" \
  "https://gitlab.example.com/o/r/-/compare/aaa111...bbb222" \
  "$(gitlab_get_mr_diff_since_url "https://gitlab.example.com/o/r" "aaa111" "bbb222")"

# --- parse_repo_slug / mcp_tool_hint（issue #34: gh/glab CLI不在時のMCPフォールバック） -------
#
# `parse_repo_slug` はリモートURL文字列だけを入力とする純粋関数のためそのままテストできる。
# `mcp_tool_hint` は内部で `get_provider`（`git remote get-url origin`）を呼ぶため、テスト内で
# `get_provider` を上書きしてプロバイダを固定する（Provider.shをsourceした後に定義することで、
# 元の定義を差し替える）。

# shellcheck source=../.claude/scripts/src/vcs/Provider.sh
source "$repo_root/.claude/scripts/src/vcs/Provider.sh"

assert_eq "parse_repo_slug: https形式（.git付き）" \
  "github.com|o|r|o/r|https://github.com/o/r" \
  "$(parse_repo_slug "https://github.com/o/r.git" | jq -r '[.host, .owner, .repo, .path, .url] | join("|")')"

assert_eq "parse_repo_slug: https形式（.git無し・末尾スラッシュ）" \
  "github.com|o|r|o/r|https://github.com/o/r" \
  "$(parse_repo_slug "https://github.com/o/r/" | jq -r '[.host, .owner, .repo, .path, .url] | join("|")')"

assert_eq "parse_repo_slug: ssh(scp形式)" \
  "github.com|o|r|o/r|https://github.com/o/r" \
  "$(parse_repo_slug "git@github.com:o/r.git" | jq -r '[.host, .owner, .repo, .path, .url] | join("|")')"

assert_eq "parse_repo_slug: ssh://形式" \
  "github.com|o|r|o/r|https://github.com/o/r" \
  "$(parse_repo_slug "ssh://git@github.com/o/r.git" | jq -r '[.host, .owner, .repo, .path, .url] | join("|")')"

assert_eq "parse_repo_slug: ssh://形式（ポート付き）" \
  "ghe.example.com|o|r|o/r|https://ghe.example.com/o/r" \
  "$(parse_repo_slug "ssh://git@ghe.example.com:2222/o/r.git" | jq -r '[.host, .owner, .repo, .path, .url] | join("|")')"

assert_eq "parse_repo_slug: GitLabのネストしたnamespaceはownerにグループ階層が入る" \
  "gitlab.example.com|g/sub|r|g/sub/r|https://gitlab.example.com/g/sub/r" \
  "$(parse_repo_slug "https://gitlab.example.com/g/sub/r.git" | jq -r '[.host, .owner, .repo, .path, .url] | join("|")')"

get_provider() { printf 'github\n'; }

assert_eq "mcp_tool_hint: get_issue（GitHub）" \
  "mcp__github__issue_read (method=\"get\", owner, repo, issue_number)" \
  "$(mcp_tool_hint get_issue)"

assert_eq "mcp_tool_hint: set_mr_description（GitHub）" \
  "mcp__github__update_pull_request (owner, repo, pullNumber, body=ファイル内容)" \
  "$(mcp_tool_hint set_mr_description)"

assert_eq "mcp_tool_hint: 未知の関数名でも空にならずSKILL.mdの対応表へ誘導する" \
  "対応するMCPツールは .claude/skills/issue-mr-flow/SKILL.md の対応表を参照" \
  "$(mcp_tool_hint unknown_function)"

get_provider() { printf 'gitlab\n'; }

assert_eq "mcp_tool_hint: GitLabは対象外である旨を返す" \
  "GitLab向けのMCPフォールバックは対象外です（DDR 0026）。glab CLIをインストール・認証してください" \
  "$(mcp_tool_hint get_issue)"

echo "passed=$passed failures=$failures"
[ "$failures" -eq 0 ]
