#!/usr/bin/env bash
# .claude/scripts/src/vcs/{Github,Gitlab,Provider}.sh の純粋ロジック（`gh`/`glab`呼び出しを
# 伴わないURL組み立て・JSON整形・文字列判定関数）の単体テスト。issue #13対応で追加した
# `github_get_compare_url` / `github_get_mr_diff_url` / `github_get_mr_diff_since_url` /
# `gitlab_get_compare_url` / `gitlab_get_mr_diff_url` / `gitlab_get_mr_diff_since_url` が対象。
# `github_get_repo_url` / `gitlab_get_repo_url`（`gh repo view` / `glab repo view`を呼ぶ）と
# Provider.sh経由のディスパッチ（`get_mr_diff_url`等）は外部コマンド・`git remote get-url origin`
# に依存し純粋ではないため対象外（Github.sh/Gitlab.sh の関数を直接呼ぶ）。
# issue #48対応で追加した `gitlab_format_discussion_notes`（discussions JSONの整形）も対象。
# issue #45対応で追加した `provider_from_remote_url`（remote URLのホスト部からプロバイダを判定）も
# 対象。`get_provider` 本体は `git remote get-url origin` を呼ぶため対象外で、URL文字列を
# 受け取る純粋関数側を切り出してテストしている。
# あわせてissue #34で追加した `parse_repo_slug`（リモートURLのパース）と `mcp_tool_hint`
# （CLI不在時に提示するMCPツール名）も対象とする。後者は `get_provider` をテスト内で上書きして
# プロバイダを固定する。
# 規約: passed=N failures=N を標準出力へ出し、失敗があれば終了コード1
#       （.claude/rules/shell-script-style.md「テスト」）。
# 実行: bash .claude/scripts/test/test_vcs_provider.sh
set -euo pipefail

script_dir="${BASH_SOURCE[0]%/*}"
[[ "$script_dir" == "${BASH_SOURCE[0]}" ]] && script_dir="."
repo_root="$(cd "$script_dir/../../.." && pwd)"

# shellcheck source=../../../.claude/scripts/src/vcs/Github.sh
source "$repo_root/.claude/scripts/src/vcs/Github.sh"
# shellcheck source=../../../.claude/scripts/src/vcs/Gitlab.sh
source "$repo_root/.claude/scripts/src/vcs/Gitlab.sh"
# shellcheck source=../../../.claude/scripts/src/vcs/Provider.sh
source "$repo_root/.claude/scripts/src/vcs/Provider.sh"

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

# --- gitlab_format_discussion_notes（issue #48） -------------------------------------------
# GitLabのdiscussions APIは「説明を変更した」等の操作履歴を、レビューコメントと同じ配列で
# `system: true` のnoteとして返す。これがレビュー往復の完了判定を狂わせないことを確認する。
# フィクスチャはローカルGitLab CE 18.5.4の実レスポンス形状に合わせている
# （`changed the description` は実機で実際に観測されたシステムノートのbody）。
gitlab_discussions_fixture='[
  {"id":"d1","individual_note":false,"notes":[
    {"id":1,"body":"ここは修正してください","author":{"username":"reviewer"},
     "system":false,"resolvable":true,"resolved":false}]},
  {"id":"d2","individual_note":false,"notes":[
    {"id":2,"body":"対応済みの指摘","author":{"username":"reviewer"},
     "system":false,"resolvable":true,"resolved":true}]},
  {"id":"d3","individual_note":true,"notes":[
    {"id":3,"body":"changed the description","author":{"username":"root"},
     "system":true,"resolvable":false}]},
  {"id":"d4","individual_note":true,"notes":[
    {"id":4,"body":"通常コメント","author":{"username":"root"},
     "system":false,"resolvable":false}]}
]'

assert_eq "gitlab_format_discussion_notes: 既定では未解決のみ返し、システムノートと解決済みを除外する" \
  "[unresolved threadId=d1] reviewer: ここは修正してください

[unresolved threadId=d4] root: 通常コメント" \
  "$(gitlab_format_discussion_notes "$gitlab_discussions_fixture")"

assert_eq "gitlab_format_discussion_notes: include_resolved=trueでは解決済みを含むがシステムノートは除外する" \
  "[unresolved threadId=d1] reviewer: ここは修正してください

[resolved threadId=d2] reviewer: 対応済みの指摘

[unresolved threadId=d4] root: 通常コメント" \
  "$(gitlab_format_discussion_notes "$gitlab_discussions_fixture" true)"

assert_eq "gitlab_format_discussion_notes: システムノートのbodyは全件取得時も出力に現れない" \
  "0" \
  "$(gitlab_format_discussion_notes "$gitlab_discussions_fixture" true | grep -c 'changed the description' || true)"

# resolvableでないnote（individual_note等）は resolved 扱いにせず常に含める。
assert_eq "gitlab_format_discussion_notes: resolvableでないnoteはunresolvedとして扱う" \
  "[unresolved threadId=d4] root: 通常コメント" \
  "$(gitlab_format_discussion_notes '[{"id":"d4","individual_note":true,"notes":[{"id":4,"body":"通常コメント","author":{"username":"root"},"system":false,"resolvable":false}]}]')"

# Windowsネイティブjqは出力行末にCRを付与するため、関数側で除去している
# （.claude/rules/shell-script-style.md「文字コード」）。CRの検査はバイト数比較で行う
# （`grep -c $'\r'` は環境によって空パターン扱いになり全行にマッチするため使わない）。
gitlab_notes_output="$(gitlab_format_discussion_notes "$gitlab_discussions_fixture" true)"
assert_eq "gitlab_format_discussion_notes: 出力にCRが混入しない" \
  "$(printf '%s' "$gitlab_notes_output" | wc -c)" \
  "$(printf '%s' "$gitlab_notes_output" | tr -d '\r' | wc -c)"

# --- parse_repo_slug / mcp_tool_hint（issue #34: gh/glab CLI不在時のMCPフォールバック） -------
#
# `parse_repo_slug` はリモートURL文字列だけを入力とする純粋関数のためそのままテストできる。
# `mcp_tool_hint` は内部で `get_provider`（`git remote get-url origin`）を呼ぶため、テスト内で
# `get_provider` を上書きしてプロバイダを固定する（冒頭で `Provider.sh` をsource済みのため、
# ここでの再定義が元の定義を差し替える）。
#
# 注意: この上書きは以降のテスト全体に効く。`get_provider` に依存するテストをこれより後ろへ
# 追加しないこと（issue #45で追加した `provider_from_remote_url` のテストは `get_provider` を
# 呼ばないため影響を受けない）。

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
  "GitLab向けのMCPフォールバックは対象外です（DDR 0027）。glab CLIをインストール・認証してください" \
  "$(mcp_tool_hint get_issue)"


# --- provider_from_remote_url（issue #45） ------------------------------------------------
# remote URLの「ホスト部」でプロバイダを判定する純粋関数。ホスト名に `github` を含めばGitHub、
# それ以外はGitLabとみなす（ホスト名に `gitlab` を含まないself-hosted GitLabを弾かないため）。
# `aslead` は社内GitLabの明示ケースでGitHub判定より先に評価される。

assert_eq "provider_from_remote_url: github.com（https）" \
  "github" "$(provider_from_remote_url 'https://github.com/foo/bar.git')"

assert_eq "provider_from_remote_url: github.com（scp形式）" \
  "github" "$(provider_from_remote_url 'git@github.com:foo/bar.git')"

# GHEは慣習的にホスト名へ `github` を含むため、GitLab扱いにしない
assert_eq "provider_from_remote_url: GHE（github.example.com）" \
  "github" "$(provider_from_remote_url 'https://github.example.com/foo/bar.git')"

assert_eq "provider_from_remote_url: gitlab.com（https）" \
  "gitlab" "$(provider_from_remote_url 'https://gitlab.com/foo/bar.git')"

assert_eq "provider_from_remote_url: gitlab.example.co.jp" \
  "gitlab" "$(provider_from_remote_url 'https://gitlab.example.co.jp/foo/bar.git')"

# 以下3件がissue #45の受け入れ条件（ホスト名に `gitlab` を含まないself-hosted GitLab）
assert_eq "provider_from_remote_url: ホスト名にgitlabを含まないself-hosted（scp形式）" \
  "gitlab" "$(provider_from_remote_url 'git@git.example.co.jp:foo/bar.git')"

assert_eq "provider_from_remote_url: localhost:8929" \
  "gitlab" "$(provider_from_remote_url 'http://localhost:8929/root/demo.git')"

assert_eq "provider_from_remote_url: 127.0.0.1:8929" \
  "gitlab" "$(provider_from_remote_url 'http://127.0.0.1:8929/root/demo.git')"

assert_eq "provider_from_remote_url: ポート付きssh形式" \
  "gitlab" "$(provider_from_remote_url 'ssh://git@gitlab.example.com:2222/foo/bar.git')"

# 旧実装はURL文字列全体へ `*github.com*` を先にマッチさせていたため、パスに `github` を含む
# GitLab URLを `github` と誤判定していた（回帰テスト）
assert_eq "provider_from_remote_url: パスにgithubを含むGitLab URL" \
  "gitlab" "$(provider_from_remote_url 'https://gitlab.com/github-mirror/x.git')"

# パス→認証情報→ポートの順に除去する（逆順だとパス中の `@` にマッチしてホスト抽出が壊れる）
assert_eq "provider_from_remote_url: パスに@を含む（抽出順序の検証）" \
  "gitlab" "$(provider_from_remote_url 'https://user@gitlab.com:8080/foo/b@r.git')"

assert_eq "provider_from_remote_url: 社内GitLab（aslead）" \
  "gitlab" "$(provider_from_remote_url 'https://aslead.example.co.jp/foo/bar.git')"

assert_eq "provider_from_remote_url: 社内GitLab（aslead・scp形式）" \
  "gitlab" "$(provider_from_remote_url 'git@aslead-git.corp.local:foo/bar.git')"

# `aslead` の判定を `github` より前に置いているため、両方を含むホストはGitLabになる
assert_eq "provider_from_remote_url: asleadがgithubより優先される" \
  "gitlab" "$(provider_from_remote_url 'https://github.aslead.example.com/foo/bar.git')"

# ホスト名が空のときだけエラー（終了コード1）にする。`set -e` 配下でも確実に終了コードを
# 拾えるよう、`if` の条件式（-e が一時停止される文脈）で判定する
# （.claude/rules/shell-script-style.md「エラー方針」）。
if provider_from_remote_url 'https://' >/dev/null 2>&1; then
  empty_host_status=0
else
  empty_host_status=1
fi
assert_eq "provider_from_remote_url: ホスト名が空なら終了コード1" \
  "1" "$empty_host_status"

# --- split_remote_url ---------------------------------------------------------------------
#
# remote URLをホスト部とパス部へ分解する純粋関数（issue #55）。`provider_from_remote_url` と
# `parse_repo_slug` が共有する土台であり、両者の既存テスト（21件）が引き続き通ることが
# 「共通化しても振る舞いが変わっていない」ことの主たる根拠になる。
#
# 結果はグローバル変数 `REPLY_HOST` / `REPLY_PATH` へ返るため、パイプ（右辺がサブシェルになり
# 代入が呼び出し元へ伝わらない）ではなく直接呼ぶ
# （.claude/rules/shell-script-style.md「`REPLY` へ返す関数はパイプではなく…」）。

split_remote_url 'https://github.com/o/r.git'
assert_eq "split_remote_url: https形式" "github.com|o/r" "$REPLY_HOST|$REPLY_PATH"

split_remote_url 'git@github.com:o/r.git'
assert_eq "split_remote_url: scp形式（:の後ろはパス）" "github.com|o/r" "$REPLY_HOST|$REPLY_PATH"

split_remote_url 'ssh://git@ghe.example.com:2222/o/r.git'
assert_eq "split_remote_url: ポート付きssh（:の後ろは数字＝ポート）" \
  "ghe.example.com|o/r" "$REPLY_HOST|$REPLY_PATH"

# 認証情報 user@ の除去がパス中の `@` へ誤爆しないこと（最初の `/` より前だけを見て判定する）
split_remote_url 'https://user@gitlab.com:8080/foo/b@r.git'
assert_eq "split_remote_url: パスに@を含む" "gitlab.com|foo/b@r" "$REPLY_HOST|$REPLY_PATH"

# ホストのみ小文字化し、パス（owner/repo）の大文字は保つ。`parse_repo_slug` の唯一の
# 振る舞い変更（issue #55）を明示的に固定する
split_remote_url 'https://GitHub.COM/O/R.git'
assert_eq "split_remote_url: ホストは小文字化・パスは保つ" "github.com|O/R" "$REPLY_HOST|$REPLY_PATH"

split_remote_url 'https://github.com'
assert_eq "split_remote_url: パス無し" "github.com|" "$REPLY_HOST|$REPLY_PATH"

# GitLabのネストしたnamespace（group/subgroup/repo）
split_remote_url 'https://gitlab.example.com/g/sub/r.git'
assert_eq "split_remote_url: ネストしたnamespace" \
  "gitlab.example.com|g/sub/r" "$REPLY_HOST|$REPLY_PATH"

# ホスト名が取れなくても失敗させない（エラーにするかは呼び出し側の判断に委ねる）
split_remote_url 'https://'
assert_eq "split_remote_url: ホスト名が空でも失敗しない" "|" "$REPLY_HOST|$REPLY_PATH"

echo "passed=$passed failures=$failures"
[ "$failures" -eq 0 ]
