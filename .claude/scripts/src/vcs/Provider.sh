#!/usr/bin/env bash
#
# issue駆動MRワークフロー支援の共通レイヤー（bash版）。
# 設計: .claude/docs/spec/issue-mr-workflow.md, .claude/docs/spec/shell-scripts.md
#
# GitHub/GitLabの差異を吸収する共通インターフェースを提供する。呼び出し側
# （.claude/skills/issue-mr-flow/SKILL.md 等）はこのファイルをsourceして使う。
#     source .claude/scripts/src/vcs/Provider.sh
#
# プロバイダ非依存の関数（new_issue_branch, sync_branch 等）はここに実装し、
# プロバイダ依存の関数（get_issue, new_draft_merge_request, get_mr_unresolved_comments,
# set_mr_description 等）は get_provider の判定結果に応じて Github.sh / Gitlab.sh の
# 対応関数（github_xxx / gitlab_xxx）へディスパッチする。
#
# 戻り値の受け渡しはPowerShell版のPSCustomObjectに代えてJSON文字列をstdoutへ出力する形にする
# （呼び出し側はjqでフィールドを取り出す。例: get_issue 6 | jq -r '.title'）。JSONのキー名は
# PowerShell版のPascalCase（Number/Title/...）ではなく、bash/jqのエコシステムに合わせて
# camelCase（number/title/...）に統一している（詳細: .claude/docs/spec/shell-scripts.md）。
#
# 前提: bash, git, jq, gh（GitHubの場合）または glab（GitLabの場合）。
#
# `gh`/`glab` が実行環境に存在しない場合（例: Claude Code on the webのリモート実行環境）は、
# プロバイダ依存の関数は `require_vcs_cli` により「代替すべきMCPツール名」を提示して失敗する。
# 呼び出し側（AIエージェント）はそのメッセージに従いMCPフォールバック経路へ切り替える
# （経路判定は `get_vcs_access_mode`、手順は .claude/skills/issue-mr-flow/SKILL.md
# 「`gh`/`glab` CLI不在時のMCPフォールバック」節。issue #34, DDR 0027）。
#
# 注意（文字コード）: PowerShell版はシステムのANSI/OEMコードページ対策として明示的な
# UTF-8切り替えが必要だったが、git bash + gh/jq の組み合わせではこの問題が発生しない
# （bashの標準入出力・パイプはコードページの影響を受けない）ため、本ファイルには
# 同種の対策は不要（詳細: .claude/docs/spec/shell-scripts.md「文字コード」節）。
#
# 注意（エラー方針）: PowerShell版の `$ErrorActionPreference = "Stop"` に相当する方針として
# `set -euo pipefail` を用いる。個々の関数内で「失敗してもスクリプト全体を止めたくない」箇所は
# `if ! cmd; then ...; fi` の形（`!` 付きコマンドは -e の対象外というbashの仕様）で局所的に握りつぶす。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./Github.sh
source "${SCRIPT_DIR}/Github.sh"
# shellcheck source=./Gitlab.sh
source "${SCRIPT_DIR}/Gitlab.sh"

# issue本文に標準として求める見出し（.claude/docs/spec/issue-mr-workflow.md
# 「Issueテンプレート標準化」参照。.github/ISSUE_TEMPLATE/task.md, .gitlab/issue_templates/task.md と対応）
REQUIRED_ISSUE_SECTIONS=("目的" "現状" "期待する動作" "受け入れ条件")

get_repo_root() {
  git rev-parse --show-toplevel
}

# `.mrworkflow.json` が無い場合のデフォルト値をJSONで返す（あればファイルの内容をそのまま返す）。
get_workflow_config() {
  local config_path
  config_path="$(get_repo_root)/.mrworkflow.json"
  if [ -f "$config_path" ]; then
    cat "$config_path"
    return 0
  fi
  cat <<'EOF'
{
  "branchPrefixTemplate": "feature-{issue}-{slug}",
  "defaultBaseBranch": "main",
  "plansDir": "plans",
  "worklogDir": "worklog",
  "reportsDir": "reports",
  "specDirs": [".claude/docs/spec"],
  "ddrDirs": [".claude/docs/ddr"]
}
EOF
}

# issueタイトル等を英数字・ハイフンのスラッグへ簡易変換する（ブランチ名・ファイル名に使う）
to_slug() {
  local text="$1"
  local slug
  slug="$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  if [ ${#slug} -gt 50 ]; then
    slug="$(printf '%s' "${slug:0:50}" | sed -E 's/-+$//')"
  fi
  if [ -z "$slug" ]; then
    slug="issue"
  fi
  printf '%s' "$slug"
}

# issue本文に標準4見出し（目的・現状・期待する動作・受け入れ条件）が揃っているか確認し、
# 欠けている見出し名を1行1件でstdoutへ出力する（揃っていれば何も出力しない）。プロバイダ非依存。
test_issue_sections() {
  local body="$1"
  local section
  for section in "${REQUIRED_ISSUE_SECTIONS[@]}"; do
    if ! printf '%s\n' "$body" | grep -qE "^##[[:space:]]*${section}[[:space:]]*\$"; then
      printf '%s\n' "$section"
    fi
  done
}

# 標準4見出し（目的・現状・期待する動作・受け入れ条件）に沿ってissue本文を組み立てる
# （`.github/ISSUE_TEMPLATE/task.md`, `.gitlab/issue_templates/task.md` と同じ見出し構成）。
# 外部コマンド呼び出しを伴わない純粋関数。プロバイダ非依存。
build_issue_body() {
  local purpose="$1" current="$2" expected="$3" acceptance="$4"
  printf '## 目的\n\n%s\n\n## 現状\n\n%s\n\n## 期待する動作\n\n%s\n\n## 受け入れ条件\n\n%s\n' \
    "$purpose" "$current" "$expected" "$acceptance"
}

# remote URLからホスト部分を取り出し、プロバイダ名（github / gitlab）を返す純粋関数。
# 外部コマンド呼び出しを伴わないため tests/test_vcs_provider.sh から単体テストできる
# （.claude/rules/shell-script-style.md「テスト」）。
#
# 判定規則: ホスト名に `github` を含めばGitHub、それ以外はGitLabとみなす。本ワークフローが
# 対応するのはGitHub/GitLabの2つだけで、GitHubはSaaS（github.com）・GHEとも慣習的にホスト名へ
# `github` を含むため、「GitHubでなければGitLab」で全ケースを賄える。ホスト名に `gitlab` を
# 含まないself-hosted GitLab（git.example.co.jp / localhost:8929 等）を弾かないことが目的
# （issue #45）。
#
# URL全体ではなくホスト部で判定するのが要点。旧実装は `*github.com*` を先に見ていたため、
# https://gitlab.com/github-mirror/x.git のようにパスへ `github` を含むGitLab URLをGitHubと
# 誤判定していた。
#
# 判定はremote URLの文字列のみに依存し、`gh`/`glab` の認証状態には依存しない（未ログインでも
# 同じ結果になる）。
# 詳細・却下案（glab由来の情報を使う3方式・`.mrworkflow.json`への`provider`キー追加）は
# .claude/docs/ddr/0028-プロバイダ判定はremote-URLのホスト部でgithub以外をgitlabとみなす.md 参照。
#
# 受け入れたトレードオフ: GitHub/GitLabのどちらでもないリモート（Bitbucket等、URLのtypo）にも
# `gitlab` を返すため、旧実装の「サポート対象外のリモートです」という明快なエラーは出なくなり、
# 後続の `glab` 側のエラーに変わる。対応プロバイダが2つしかない以上、self-hostedを弾かずに
# 非対応だけを弾く判定は原理的に書けないため受け入れている（issue #45）。
provider_from_remote_url() {
  local url="$1" host
  # scheme:// があれば除去（無ければそのまま）
  host="${url#*://}"
  # 最初の `/` 以降（パス）を除去。scp形式 git@host:path でも `/` 以降が落ちる
  host="${host%%/*}"
  # 認証情報 user@ を除去。パスを先に落としてからでないと、パスに `@` を含むURLで壊れる
  host="${host#*@}"
  # ポート（:8929）または scp形式のパス区切り（:foo）を除去
  host="${host%%:*}"
  host="${host,,}"

  if [ -z "$host" ]; then
    echo "remote URLからホスト名を取得できませんでした: $url" >&2
    return 1
  fi

  case "$host" in
    # 社内GitLab（Aslead）を明示的に先に判定する。既定規則（github以外はgitlab）でも同じ結果に
    # なるが、ホスト名に `github` と `aslead` が同時に含まれる場合でもGitLabを優先させるため、
    # GitHub判定より前に置く。
    *aslead*) printf 'gitlab\n' ;;
    *github*) printf 'github\n' ;;
    *) printf 'gitlab\n' ;;
  esac
}

# `git remote get-url origin` のホスト名からプロバイダを判定する
get_provider() {
  local url
  url="$(git remote get-url origin)"
  provider_from_remote_url "$url"
}

# --- gh/glab CLI不在環境向けのMCPフォールバック経路（issue #34） --------------------------------
#
# Claude Code on the webのリモート実行環境のように `gh`/`glab` CLIが存在しない環境では、
# 以下の関数群が「どのMCPツールで代替するか」を機械的に決めるための土台になる。
# 手順の正（サブコマンドごとの読み替え）は `.claude/skills/issue-mr-flow/SKILL.md`
# 「`gh`/`glab` CLI不在時のMCPフォールバック」節。WebFetch/curlへはフォールバックしない
# （DDR 0020, DDR 0027）。

# 実行環境に該当プロバイダのCLIがあるかを判定し、`cli`（CLI経路）または `mcp`（MCPフォールバック
# 経路）を標準出力へ返す。AIエージェントは各サブコマンドの冒頭でこれを呼び、経路を決める。
get_vcs_access_mode() {
  local provider cli
  provider="$(get_provider)"
  case "$provider" in
    github) cli="gh" ;;
    gitlab) cli="glab" ;;
    *) cli="" ;;
  esac
  if [ -n "$cli" ] && command -v "$cli" >/dev/null 2>&1; then
    printf 'cli\n'
  else
    printf 'mcp\n'
  fi
}

# リモートURL（https / ssh(scp形式) / ssh:// のいずれも可）から
# {host, owner, repo, path, url} のJSONを組み立てる純粋関数（外部の`gh`/`glab`に依存しない）。
# MCPツールが必須引数として要求する `owner` / `repo` を、CLI不在環境でも機械的に得るために使う。
# GitLabのネストしたnamespace（group/subgroup/repo）では、`owner` に `group/subgroup` が入る。
parse_repo_slug() {
  local url="$1"
  local host path owner repo
  host="$(printf '%s' "$url" | sed -E 's#^[a-zA-Z0-9+.-]+://##; s#^[^/@]+@##; s#^([^/:]+).*$#\1#')"
  path="$(printf '%s' "$url" | sed -E '
    s#^[a-zA-Z0-9+.-]+://##;
    s#^[^/@]+@##;
    s#^[^/:]+[:/]##;
    s#^[0-9]+/##;
    s#\.git$##;
    s#/+$##')"
  owner="${path%/*}"
  repo="${path##*/}"
  jq -nc --arg host "$host" --arg owner "$owner" --arg repo "$repo" --arg path "$path" \
    '{host: $host, owner: $owner, repo: $repo, path: $path, url: ("https://" + $host + "/" + $path)}'
}

# `git remote get-url origin` の値を parse_repo_slug へ渡す（MCPツールの owner/repo 引数用）。
get_repo_slug() {
  parse_repo_slug "$(git remote get-url origin)"
}

# Provider関数名に対応するGitHub MCPツールと主な引数を1行で返す（require_vcs_cli の
# メッセージ用。対応表の正はSKILL.mdの該当節で、ここはその要約）。
# GitLabは対象外（DDR 0027「GitLab側は対象外とする」）。
mcp_tool_hint() {
  local func_name="$1"
  if [ "$(get_provider)" != "github" ]; then
    printf 'GitLab向けのMCPフォールバックは対象外です（DDR 0027）。glab CLIをインストール・認証してください\n'
    return 0
  fi
  case "$func_name" in
    get_issue) printf 'mcp__github__issue_read (method="get", owner, repo, issue_number)\n' ;;
    new_issue) printf 'mcp__github__issue_write (method="create", owner, repo, title, body)\n' ;;
    new_draft_merge_request) printf 'mcp__github__create_pull_request (owner, repo, title, head, base, draft=true, body)\n' ;;
    get_mr_for_branch) printf 'mcp__github__list_pull_requests (owner, repo, head="<owner>:<branch>", state="open")\n' ;;
    get_mr_unresolved_comments) printf 'mcp__github__pull_request_read (method="get_review_comments" / "get_comments", owner, repo, pullNumber)\n' ;;
    add_mr_thread_reply) printf 'mcp__github__add_reply_to_pull_request_comment (owner, repo, pullNumber, commentId=スレッド先頭コメントの数値ID, body)\n' ;;
    set_mr_description) printf 'mcp__github__update_pull_request (owner, repo, pullNumber, body=ファイル内容)\n' ;;
    add_mr_comment) printf 'mcp__github__add_issue_comment (owner, repo, issue_number=PR番号, body=ファイル内容)\n' ;;
    *) printf '対応するMCPツールは .claude/skills/issue-mr-flow/SKILL.md の対応表を参照\n' ;;
  esac
}

# CLI経路が使えない場合に、代替すべきMCPツールを名指ししたメッセージをstderrへ出して失敗する。
# 各Provider関数の先頭で `require_vcs_cli <自関数名> || return 1` の形で呼ぶ。
# 目的は「CLI不在時にAIエージェントが即興でツールを選ぶ」状態をなくすこと（issue #34）。
require_vcs_cli() {
  local func_name="$1"
  if [ "$(get_vcs_access_mode)" = "cli" ]; then
    return 0
  fi
  {
    printf '%s: gh/glab CLIがこの実行環境に存在しないため、CLI経路では実行できません。\n' "$func_name"
    printf '  代替（MCPフォールバック経路）: %s\n' "$(mcp_tool_hint "$func_name")"
    printf '  owner/repo は `get_repo_slug` で取得できます（例: get_repo_slug | jq -r ".owner, .repo"）。\n'
    printf '  手順: .claude/skills/issue-mr-flow/SKILL.md 「`gh`/`glab` CLI不在時のMCPフォールバック」節\n'
    printf '  WebFetchツール・curlへはフォールバックしないこと（DDR 0020, DDR 0027）。\n'
  } >&2
  return 1
}

get_issue() {
  require_vcs_cli get_issue || return 1
  local number="$1"
  case "$(get_provider)" in
    github) github_get_issue "$number" ;;
    gitlab) gitlab_get_issue "$number" ;;
  esac
}

new_issue() {
  require_vcs_cli new_issue || return 1
  local title="$1" body="$2"
  case "$(get_provider)" in
    github) github_new_issue "$title" "$body" ;;
    gitlab) gitlab_new_issue "$title" "$body" ;;
  esac
}

new_draft_merge_request() {
  require_vcs_cli new_draft_merge_request || return 1
  local issue_number="$1" branch="$2" title="$3"
  local base_branch="${4:-$(get_workflow_config | jq -r '.defaultBaseBranch')}"
  case "$(get_provider)" in
    github) github_new_draft_merge_request "$issue_number" "$branch" "$base_branch" "$title" ;;
    gitlab) gitlab_new_draft_merge_request "$issue_number" "$branch" "$base_branch" "$title" ;;
  esac
}

get_mr_unresolved_comments() {
  require_vcs_cli get_mr_unresolved_comments || return 1
  local mr_number="$1" include_resolved="${2:-false}"
  case "$(get_provider)" in
    github) github_get_mr_unresolved_comments "$mr_number" "$include_resolved" ;;
    gitlab) gitlab_get_mr_unresolved_comments "$mr_number" "$include_resolved" ;;
  esac
}

# 指定したレビュースレッドに対応内容を返信する（スレッドの解決＝resolvedはレビュアー側の操作のため
# 行わない）。thread_idは get_mr_unresolved_comments の出力に含まれる threadId=... を使う。
add_mr_thread_reply() {
  require_vcs_cli add_mr_thread_reply || return 1
  local mr_number="$1" thread_id="$2" reply_body="$3"
  case "$(get_provider)" in
    github) github_add_mr_thread_reply "$mr_number" "$thread_id" "$reply_body" ;;
    gitlab) gitlab_add_mr_thread_reply "$mr_number" "$thread_id" "$reply_body" ;;
  esac
}

get_mr_for_branch() {
  require_vcs_cli get_mr_for_branch || return 1
  local branch="$1"
  case "$(get_provider)" in
    github) github_get_mr_for_branch "$branch" ;;
    gitlab) gitlab_get_mr_for_branch "$branch" ;;
  esac
}

set_mr_description() {
  require_vcs_cli set_mr_description || return 1
  local mr_number="$1" body_file="$2"
  case "$(get_provider)" in
    github) github_set_mr_description "$mr_number" "$body_file" ;;
    gitlab) gitlab_set_mr_description "$mr_number" "$body_file" ;;
  esac
}

# リポジトリの正規URL（フルパス）を取得する（issue #13フォローアップ: MR/PRのURL文字列からの
# 推測ではなく`gh repo view`/`glab repo view`で取得し正確性を担保する）。
#
# CLI不在時（issue #34）は、他のプロバイダ依存関数と異なり `require_vcs_cli` で失敗させず、
# `get_repo_slug`（`git remote get-url origin` のパース）から組み立てたURLを返す。リモートURLの
# 取得はローカルのgit操作でありCLI・ネットワークを必要としないため、MCPツールを介す必要が無く、
# これによりURL組み立て系（`get_mr_diff_url` 等）はMCP経路でもそのまま動く。
get_repo_url() {
  if [ "$(get_vcs_access_mode)" != "cli" ]; then
    get_repo_slug | jq -r '.url'
    return 0
  fi
  case "$(get_provider)" in
    github) github_get_repo_url ;;
    gitlab) gitlab_get_repo_url ;;
  esac
}

# MR/PRの「defaultブランチとの差分」を見れるURLを組み立てる（issue #13:
# レビュー依頼メッセージに含める参照リンク用）。`repo_url`は`get_repo_url`で取得したものを渡す。
get_mr_diff_url() {
  local repo_url="$1" base_branch="$2" head_branch="$3"
  case "$(get_provider)" in
    github) github_get_mr_diff_url "$repo_url" "$base_branch" "$head_branch" ;;
    gitlab) gitlab_get_mr_diff_url "$repo_url" "$base_branch" "$head_branch" ;;
  esac
}

# MR/PRの「前回push時点(from_sha)から今回push時点(to_sha)までの差分」を見れるURLを組み立てる
# （issue #13: レビュー指摘対応push時にレビュー依頼メッセージへ追加で含める参照リンク用）。
# `repo_url`は`get_repo_url`で取得したものを渡す。
get_mr_diff_since_url() {
  local repo_url="$1" from_sha="$2" to_sha="$3"
  case "$(get_provider)" in
    github) github_get_mr_diff_since_url "$repo_url" "$from_sha" "$to_sha" ;;
    gitlab) gitlab_get_mr_diff_since_url "$repo_url" "$from_sha" "$to_sha" ;;
  esac
}

# MRへ新規コメントを1件投稿する（スレッド返信ではなく、レビューでもない通常コメント。
# レビュー合否判定には影響しない）。呼び出し元想定: 対応工数レポート（post-push-usage-report.sh）。
add_mr_comment() {
  require_vcs_cli add_mr_comment || return 1
  local mr_number="$1" body_file="$2"
  case "$(get_provider)" in
    github) github_add_mr_comment "$mr_number" "$body_file" ;;
    gitlab) gitlab_add_mr_comment "$mr_number" "$body_file" ;;
  esac
}

# baseとの差分（コミット）が無いブランチでは `gh pr create` / `glab mr create` が失敗するため
# （new_issue_branch直後など。.claude/docs/spec/issue-mr-workflow.md の既知の制約参照）、
# 空コミットを1つ積んでpushすることで回避する。呼び出し元（github_/gitlab_new_draft_merge_request）が
# 失敗を検知した後にこれを呼び、作成を1回だけリトライする。
add_empty_commit_for_draft_mr() {
  git commit --allow-empty -m "chore: Draft PR作成のための空コミット（baseとの差分が無いため）" >/dev/null
  git push >/dev/null
}

# issue番号・スラッグ生成用テキストから `.mrworkflow.json` の branchPrefixTemplate に沿った
# ブランチを作成しcheckout、リモートへpushする（flow-id 1-3: 「issueからMRとブランチを作る」
# 「作成したブランチをfetch, checkout」）。第2引数はslug化対象のテキストであり、生のissueタイトル
# である必要はない（呼び出し元が英語の意訳フレーズ等を渡してよい。`.claude/skills/issue-mr-flow/
# SKILL.md` の `start` サブコマンド参照。issue #22）。第3引数（省略可）でベースブランチを上書き
# できる。省略時は従来どおり `.mrworkflow.json` の `defaultBaseBranch` を使う（issue #15:
# `start` サブコマンドが `AskUserQuestion` で確認した結果を渡す用途）。
new_issue_branch() {
  local issue_number="$1" slug_source="$2"
  local config slug branch base_branch template
  config="$(get_workflow_config)"
  slug="$(to_slug "$slug_source")"
  base_branch="${3:-$(printf '%s' "$config" | jq -r '.defaultBaseBranch')}"
  template="$(printf '%s' "$config" | jq -r '.branchPrefixTemplate')"
  branch="${template//\{issue\}/$issue_number}"
  branch="${branch//\{slug\}/$slug}"

  git fetch origin "$base_branch" >/dev/null
  git switch -c "$branch" "origin/$base_branch" >/dev/null
  git push -u origin "$branch" >/dev/null

  printf '%s\n' "$branch"
}

# 新しいセッションで作業を再開するとき用（flow-id 1-3の再開版）。
# ローカルにブランチが無ければ origin から作成し、あれば最新化する。
sync_branch() {
  local branch="$1"
  git fetch origin
  if git branch --list "$branch" | grep -q .; then
    git checkout "$branch"
    git pull --ff-only origin "$branch"
  else
    git checkout -b "$branch" "origin/$branch"
  fi
}

# ブランチ名を branchPrefixTemplate に照らしてissue番号を抽出する（途中引き継ぎ対応のresumeで使用）。
# {issue}/{slug} を記号を含まないプレースホルダに置換してから正規表現エスケープすることで、
# テンプレートのリテラル部分だけを正しくエスケープしつつプレースホルダを正規表現化する。
# マッチした場合はissue番号をstdoutへ出力し終了コード0、マッチしなければ何も出力せず終了コード1を返す。
get_issue_number_from_branch() {
  local branch="${1:-$(git branch --show-current)}"
  local template tokenized escaped pattern
  template="$(get_workflow_config | jq -r '.branchPrefixTemplate')"
  tokenized="${template//\{issue\}/ZZISSUEZZ}"
  tokenized="${tokenized//\{slug\}/ZZSLUGZZ}"
  escaped="$(printf '%s' "$tokenized" | sed -E 's/[.[\*^$()+?{}|\\]/\\&/g')"
  pattern="${escaped//ZZISSUEZZ/([0-9]+)}"
  pattern="${pattern//ZZSLUGZZ/.+}"

  if [[ "$branch" =~ ^${pattern}$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

# 現在のブランチ固有（<defaultBaseBranch> には無い）の plans/worklog/reports ファイル一覧を返す
# （コミット済み差分＋作業ツリーの未コミット分をマージ・重複排除）。プロバイダ非依存。
#
# 注意（core.quotepath）: gitは既定（core.quotepath=true）で、非ASCII文字を含むパスを
# 8進エスケープ＋ダブルクォートで囲んだ形（例: "plans/\343\200\220..."）で出力する。
# 個別作業計画は `plans/【調査】〜.md` のように日本語を含む命名（issue #9）のため、既定のままだと
# 戻り値が人間にもスクリプトにも使えない文字列になる。`-c core.quotepath=false` を付けて
# 生のパスを出力させる（`git ls-files -z` のようなNUL区切り出力なら元から影響を受けないが、
# ここでは --name-only / --porcelain の行単位出力を使うため明示指定が必要）。
get_branch_work_files() {
  local config plans_dir worklog_dir reports_dir base_branch committed working
  config="$(get_workflow_config)"
  plans_dir="$(printf '%s' "$config" | jq -r '.plansDir')"
  worklog_dir="$(printf '%s' "$config" | jq -r '.worklogDir')"
  reports_dir="$(printf '%s' "$config" | jq -r '.reportsDir')"
  base_branch="$(printf '%s' "$config" | jq -r '.defaultBaseBranch')"

  committed="$(git -c core.quotepath=false diff --name-only "origin/${base_branch}...HEAD" -- "$plans_dir" "$worklog_dir" "$reports_dir" 2>/dev/null || true)"
  working="$(git -c core.quotepath=false status --porcelain -- "$plans_dir" "$worklog_dir" "$reports_dir" | sed -E 's/^...//')"

  printf '%s\n%s\n' "$committed" "$working" | sed '/^$/d' | sort -u
}
