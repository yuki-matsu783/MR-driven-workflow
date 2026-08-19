#!/usr/bin/env bash
#
# GitLab固有の処理（`glab` CLIラッパー、bash版）。
# 設計: .claude/docs/spec/issue-mr-workflow.md, .claude/docs/spec/shell-scripts.md
#
# 単体でsourceせず、必ず .claude/scripts/src/vcs/Provider.sh 経由で使う
# （Provider.sh が get_provider の判定結果に応じてこのファイルの関数へディスパッチする）。
# 前提: `glab` CLIがインストール・認証済み（`glab auth login`）であること。
#
# 検証状況（issue #48）: ローカルに立てたGitLab CE 18.5.4（Docker）に対し、`glab` 1.114.0から
# 全13関数を実機実行して動作を確認済み。この検証で見つかった3件の不具合（システムノートの混入・
# `glab mr note --message`の非推奨・空コミットフォールバックの前提誤り）は修正済み。
# 以前あった「remoteがGitHubのみのため全関数が未検証」という制約は解消している。
#
# ただし次の3点は依然として未検証。詳細は
# .claude/docs/spec/issue-mr-workflow.md の「未決定事項・懸念点」を参照。
#   - `Provider.sh`経由のディスパッチ: `get_provider`がself-hostedのGitLab URLを判定できない
#     （issue #45、未修正）ため、検証は`gitlab_*`関数を直接呼ぶ形で行った。
#   - バージョン・エディション: 確認したのはCE 18.5.4のみ。gitlab.com（SaaS）・他バージョンは未確認。
#   - プロジェクト構成: 単一プロジェクトでしか確認しておらず、サブグループ・ネストした
#     namespaceでの`glab`のプロジェクト解決は未確認。

gitlab_get_issue() {
  local number="$1"
  local issue title slug
  issue="$(glab issue view "$number" --output json)"
  title="$(printf '%s' "$issue" | jq -r '.title')"
  slug="$(to_slug "$title")"
  printf '%s' "$issue" | jq --arg slug "$slug" \
    '{number: .iid, title: .title, body: .description, url: .web_url, slug: $slug}'
}

# タイトル・本文からissueを新規作成する。作成後は `gitlab_get_issue` で正規化した
# JSON（number/title/body/url/slug）を返す（get_issueと同じ形にすることで呼び出し側の扱いを揃える）。
gitlab_new_issue() {
  local title="$1" body="$2"
  local url number
  url="$(glab issue create --title "$title" --description "$body" --yes)"
  number="$(printf '%s' "$url" | grep -oE '[0-9]+$')"
  if [ -z "$number" ]; then
    echo "glab issue create の出力からissue番号を取得できませんでした: $url" >&2
    return 1
  fi
  gitlab_get_issue "$number"
}

gitlab_new_draft_merge_request() {
  local issue_number="$1" branch="$2" base_branch="$3" title="$4"
  local description
  description="$(printf 'Closes #%s\n\n(plan作成中。/issue-mr-flow describe で更新する)' "$issue_number")"

  if ! glab mr create --draft --source-branch "$branch" --target-branch "$base_branch" \
      --title "$title" --description "$description" --yes >/dev/null; then
    # 差分（コミット）が無いブランチで`glab mr create`が失敗するかどうかは、プロバイダによって
    # 異なる。issue #48でGitLab CE 18.5.4に対し実機確認したところ、targetブランチと同一SHAの
    # ブランチでもMR作成は成功し、この分岐には到達しなかった。差分ゼロで失敗するのは
    # `gh pr create`（GitHub）側の制約である（issue #48対応時、実際に
    # `No commits between main and feature-48-...`が発生しフォールバックが動作した。
    # 設計: .claude/docs/ddr/0005-DraftPR作成失敗時は空コミットで自動リトライする.md）。
    #
    # したがってこの分岐はGitLabでは通常到達しない安全網である。削除せず残しているのは、
    # 実機確認できたのが18.5.4の1バージョンのみで、他バージョン・他設定でも必ず成功すると
    # 言い切れないため。`glab`本体のエラーはそのまま表示した上で、想定内でありこれから
    # 空コミットにフォールバックする旨を明示する（失敗として扱わせないため）。
    echo "glab mr create が失敗しましたが、baseとの差分が無いことによる既知の制約です。空コミットを1つ積んでリトライします" >&2
    add_empty_commit_for_draft_mr
    if ! glab mr create --draft --source-branch "$branch" --target-branch "$base_branch" \
        --title "$title" --description "$description" --yes >/dev/null; then
      echo "glab mr create に失敗しました（空コミットでのリトライ後も失敗）" >&2
      return 1
    fi
  fi
  glab mr view "$branch" --output json --jq '.iid'
}

# discussion内のnoteを整形して返す純粋関数（`glab`呼び出しを伴わないため単体テストできる。
# .claude/rules/shell-script-style.md「テスト」）。第1引数はGitLab REST APIの
# `projects/:id/merge_requests/<n>/discussions` が返すJSON配列そのもの。
#
# GitLabは「説明を変更した」等の操作履歴を、レビューコメントと同じdiscussions APIから
# `system: true` のnoteとして返す（issue #48で実機確認: `changed the description`）。
# レビュー往復の完了判定を狂わせるため機械的に除外する。GitHub側（github_get_mr_unresolved_comments）は
# GraphQLの`reviewThreads`を使っておりシステムイベントを返さないため、同種の問題は無い。
#
# 既定では resolved: false（未解決）のnoteのみを対象とし、対応済み（解決済み）は機械的に除外する。
# include_resolved=true 指定時は解決済みも含めた全件を返す。
# 個人メモ（individual_note）等 resolvable でないnoteは常に含める。
gitlab_format_discussion_notes() {
  local discussions="$1" include_resolved="${2:-false}"

  printf '%s' "$discussions" | jq -r --argjson includeResolved "$include_resolved" '
    [
      .[] as $d
      | $d.notes[]
      | . as $n
      | select($n.system | not)
      | ($n.resolvable and $n.resolved) as $isResolved
      | select(($isResolved | not) or $includeResolved)
      | "[" + (if $isResolved then "resolved" else "unresolved" end)
        + " threadId=" + ($d.id | tostring) + "] " + $n.author.username + ": " + $n.body
    ] | join("\n\n")
  ' | tr -d '\r'
}

gitlab_get_mr_unresolved_comments() {
  local mr_number="$1" include_resolved="${2:-false}"
  local discussions
  discussions="$(glab api "projects/:id/merge_requests/${mr_number}/discussions")"
  gitlab_format_discussion_notes "$discussions" "$include_resolved"
}

# 指定したdiscussion（スレッド）に対応内容を返信する。スレッドの解決（resolved）はレビュアー側の
# 操作のためここでは行わない。
gitlab_add_mr_thread_reply() {
  local mr_number="$1" thread_id="$2" reply_body="$3"
  glab api "projects/:id/merge_requests/${mr_number}/discussions/${thread_id}/notes" \
    -X POST -f "body=${reply_body}" >/dev/null
}

# 指定ブランチに紐づくMRのJSONを返す（無ければ何も出力せず終了コード0）。途中引き継ぎ対応（resume）と、
# comments/describeサブコマンドでの「現在のブランチのMR番号取得」の共通実装として使う。
gitlab_get_mr_for_branch() {
  local branch="$1"
  local json
  if ! json="$(glab mr view "$branch" --output json 2>/dev/null)"; then
    return 0
  fi
  printf '%s' "$json" | jq '{number: .iid, url: .web_url, isDraft: .work_in_progress, title: .title}'
}

gitlab_set_mr_description() {
  local mr_number="$1" body_file="$2"
  local description
  description="$(cat "$body_file")"
  glab mr update "$mr_number" --description "$description" >/dev/null
}

# リポジトリの正規URL（フルパス）を取得する（issue #13フォローアップ: MRのURL文字列からの
# 推測ではなく`glab`で取得し正確性を担保する）。
# GitLab REST APIの
# project オブジェクトが持つ `web_url` フィールドに基づく（`glab repo view`は内部的にこのAPIを
# ラップしている）。
gitlab_get_repo_url() {
  glab repo view --output json --jq '.web_url'
}

# 2つのref（ブランチ名・SHAいずれも可）間の差分を見れる「Compare」ページのURLを組み立てる
# （純粋関数。`glab`呼び出しを伴わない）。GitLabの`/-/compare/<from>...<to>`はMR作成前から
# 使われている汎用の比較ページ。issue #13フォローアップ。
gitlab_get_compare_url() {
  local repo_url="$1" from="$2" to="$3"
  printf '%s/-/compare/%s...%s\n' "$repo_url" "$from" "$to"
}

# MRの「defaultブランチとの差分」を見れるURLを組み立てる（純粋関数）。issue #13。
gitlab_get_mr_diff_url() {
  local repo_url="$1" base_branch="$2" head_branch="$3"
  gitlab_get_compare_url "$repo_url" "$base_branch" "$head_branch"
}

# MRの「前回push時点(from_sha)から今回push時点(to_sha)までの差分」を見れるURLを組み立てる
# （純粋関数）。issue #13。
gitlab_get_mr_diff_since_url() {
  local repo_url="$1" from_sha="$2" to_sha="$3"
  gitlab_get_compare_url "$repo_url" "$from_sha" "$to_sha"
}

# MRへ新規コメントを1件投稿する（スレッド返信・レビューではない通常コメント）。
gitlab_add_mr_comment() {
  local mr_number="$1" body_file="$2"
  local body
  body="$(cat "$body_file")"
  # 安定版のREST APIを直接叩く（`glab mr note --message`はglab 1.114.0で非推奨警告を出し、
  # 代替の`glab mr note create`はEXPERIMENTAL扱いのため採用しない。issue #48）。
  # 同ファイルの gitlab_add_mr_thread_reply と実装方式が揃う。
  glab api "projects/:id/merge_requests/${mr_number}/notes" \
    -X POST -f "body=${body}" >/dev/null
}
