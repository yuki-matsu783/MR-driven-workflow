#!/usr/bin/env bash
#
# GitHub固有の処理（`gh` CLIラッパー、bash版）。
# 設計: .claude/docs/spec/issue-mr-workflow.md, .claude/docs/spec/shell-scripts.md
#
# 単体でsourceせず、必ず .claude/scripts/src/vcs/Provider.sh 経由で使う
# （Provider.sh が get_provider の判定結果に応じてこのファイルの関数へディスパッチする）。
# 前提: `gh` CLIがインストール・認証済み（`gh auth login`）であること。

github_get_issue() {
  local number="$1"
  local issue title slug
  issue="$(gh issue view "$number" --json number,title,body,url)"
  title="$(printf '%s' "$issue" | jq -r '.title')"
  slug="$(to_slug "$title")"
  printf '%s' "$issue" | jq --arg slug "$slug" \
    '{number: .number, title: .title, body: .body, url: .url, slug: $slug}'
}

# タイトル・本文からissueを新規作成する。作成後は `github_get_issue` で正規化した
# JSON（number/title/body/url/slug）を返す（get_issueと同じ形にすることで呼び出し側の扱いを揃える）。
github_new_issue() {
  local title="$1" body="$2"
  local url number
  url="$(gh issue create --title "$title" --body "$body")"
  number="$(printf '%s' "$url" | grep -oE '[0-9]+$')"
  if [ -z "$number" ]; then
    echo "gh issue create の出力からissue番号を取得できませんでした: $url" >&2
    return 1
  fi
  github_get_issue "$number"
}

# `gh issue list --search` の出力を共通形式（number/title/state/url）へ正規化する（issue #68）。
# `gh` を呼ばない純粋関数（jqのみ）のため .claude/scripts/test/test_vcs_provider.sh から単体テストできる
# （.claude/rules/shell-script-style.md「テスト」）。
#
# `state` はGitHub CLIが `OPEN`/`CLOSED` を返すのに対しGitLabは `opened`/`closed` を返すため、
# 共通形式では小文字の `open`/`closed` へ揃える（呼び出し側がプロバイダごとの表記を知らずに
# 判定できるようにするため）。
github_normalize_issue_search_results() {
  local raw="$1"
  printf '%s' "$raw" | jq -c '[.[] | {number: .number, title: .title, state: (.state | ascii_downcase), url: .url}]'
}

# キーワードで既存issueを検索する（issue #68: 起票前の重複チェック用）。
# 第1引数は1キーワードあたりの取得件数、第2引数以降が検索キーワード。
#
# **キーワードごとに1回ずつ検索する。** GitHubのissue検索は複数語をAND条件として扱うため、
# キーワードを並べて1回で検索すると、語が増えるほどヒットしなくなる。重複チェックで欲しいのは
# 再現率のため、1語ずつ検索して結果を `merge_issue_search_results` で統合する（OR相当）。
#
# `gh search issues` ではなく `gh issue list --search` を使うのは、後者がカレントリポジトリに
# 限定され、かつPRを含まないため（`--repo` 指定もPR除外も不要）。`--state all` で
# closedのissueも対象にする（過去に見送られた提案の再提出を検知するため）。
github_search_issues() {
  local limit="$1"
  shift
  local keyword results=()
  for keyword in "$@"; do
    results+=("$(github_normalize_issue_search_results \
      "$(gh issue list --search "$keyword" --state all --limit "$limit" --json number,title,state,url)")")
  done
  merge_issue_search_results "${results[@]}"
}

github_new_draft_merge_request() {
  local issue_number="$1" branch="$2" base_branch="$3" title="$4"
  local body
  body="$(printf 'Closes #%s\n\n(plan作成中。/issue-mr-flow describe で更新する)' "$issue_number")"

  if ! gh pr create --draft --base "$base_branch" --head "$branch" --title "$title" --body "$body" >/dev/null; then
    # baseとの差分（コミット）が無いブランチでは `gh pr create` が失敗する既知の制約
    # （.claude/docs/spec/issue-mr-workflow.md参照）。`gh`本体のエラーはそのまま表示した上で、
    # これは想定内でありこれから空コミットにフォールバックする旨を明示する（失敗として
    # 扱わせないため）。
    echo "gh pr create が失敗しましたが、baseとの差分が無いことによる既知の制約です。空コミットを1つ積んでリトライします" >&2
    add_empty_commit_for_draft_mr
    if ! gh pr create --draft --base "$base_branch" --head "$branch" --title "$title" --body "$body" >/dev/null; then
      echo "gh pr create に失敗しました（空コミットでのリトライ後も失敗）" >&2
      return 1
    fi
  fi
  gh pr view "$branch" --json number --jq '.number'
}

# --- レビューコメント取得（issue #43） -----------------------------------------------------
#
# 出力仕様の見直しにより、この層は**正規化JSONを返すだけ**になった（テキスト整形と、指摘行
# 前後のソース切り出しは `Provider.sh` の共通の後段ロジックが行う）。GitHub固有の `diffHunk` へ
# 依存するのをやめ、`(path, line, sha)` だけをプロバイダ間の共通項として渡す
# （詳細: .claude/docs/spec/issue-mr-workflow.md「レビューコメントのソーススライス」）。

# GraphQLの返却JSON（文字列）を、プロバイダ非依存の正規化JSONへ変換する純粋関数
# （`gh` を呼ばないため .claude/scripts/test/test_vcs_provider.sh から単体テストできる。
# `.claude/rules/shell-script-style.md`「テスト」。issue #43 以前、GitHub側の整形には
# 単体テストが1件も無く、issue #94 のCR混入をテストで検知できなかった）。
#
# 位置と断面の解決はこの層で済ませ、共通層へは解決後の `line` / `sha` だけを渡す
#   - `line`: `.line` が非nullならそれ、nullなら `.originalLine`（outdatedスレッドはこちらしか
#     値を持たない。issue #43 の「現状」6）
#   - `sha`: `line` 側に合わせて `commit.oid` / `originalCommit.oid` を選ぶ
# いずれも取得できなければ `null` を返し、共通層はソース無しへ縮退する。
github_normalize_review_threads() {
  local raw="$1" include_resolved="${2:-false}"
  printf '%s' "$raw" | jq -c --argjson includeResolved "$include_resolved" '
    def norm_comment:
      {author: (.author.login // "(unknown)"), body: (.body // ""), url: (.url // null)};
    {
      threads: [
        (.data.repository.pullRequest.reviewThreads.nodes // [])[]
        | select((.isResolved | not) or $includeResolved)
        | . as $t
        | (($t.comments.nodes // [])[0] // {}) as $c0
        | (($t.line // null) != null) as $useCurrent
        | {
            threadId: $t.id,
            isResolved: ($t.isResolved // false),
            isOutdated: ($t.isOutdated // false),
            path: ($t.path // null),
            line: (if $useCurrent then $t.line else ($t.originalLine // null) end),
            sha: (if $useCurrent
                    then ($c0.commit.oid // $c0.originalCommit.oid // null)
                    else ($c0.originalCommit.oid // $c0.commit.oid // null) end),
            comments: [ ($t.comments.nodes // [])[] | norm_comment ]
          }
      ],
      comments: [ (.data.repository.pullRequest.comments.nodes // [])[] | norm_comment ]
    }
  ' | tr -d '\r'
}

# レビュースレッド＋通常のissueコメントを正規化JSONで返す。既定では未解決（isResolved: false）の
# スレッドのみを対象とし、対応済み（解決済み）は機械的に除外する。include_resolved=true 指定時は
# 解決済みスレッドも含めた全件を返す。resolved/unresolvedの概念を持たない通常コメントは常に含める。
github_get_mr_review_threads() {
  local mr_number="$1" include_resolved="${2:-false}"
  local query result

  # gh api graphqlの{owner}/{repo}プレースホルダはクエリ文字列中には展開されず、
  # -F フィールドの値としてのみ機能する（`gh api graphql --help` のGraphQL例を参照）。
  # そのため owner/repo もGraphQL変数として宣言し、-F 経由で渡す。
  query="$(cat <<'EOF'
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          originalLine
          comments(first: 50) {
            nodes {
              author { login }
              body
              url
              commit { oid }
              originalCommit { oid }
            }
          }
        }
      }
      comments(first: 100) { nodes { author { login } body url } }
    }
  }
}
EOF
)"

  result="$(gh api graphql -F "owner={owner}" -F "repo={repo}" -F "number=$mr_number" -f "query=$query")"
  github_normalize_review_threads "$result" "$include_resolved"
}

# 指定したcommit時点のファイル内容を標準出力へ返す（ローカルにblobが無い場合のフォールバック。
# issue #43）。`Provider.sh` の `read_file_at_ref` が、ローカルの `git show` に失敗したときだけ
# ここへ落ちてくる。取得できなければ何も出力せず終了コード1を返す。
#
# GitHubの `contents` APIはファイル本体をbase64で返す（`.content`）。改行を含むbase64が返るため
# `tr -d` で詰めてからデコードする。
github_read_file_at_ref() {
  local sha="$1" path="$2"
  local encoded content
  url_encode_path_to_reply "$path"
  encoded="$REPLY"
  if ! content="$(gh api "repos/{owner}/{repo}/contents/${encoded}?ref=${sha}" --jq '.content' 2>/dev/null)"; then
    return 1
  fi
  [ -n "$content" ] || return 1
  printf '%s' "$content" | tr -d '\r\n' | base64 -d 2>/dev/null
}

# 指定したレビュースレッドに対応内容を返信する。スレッドの解決（resolved）はレビュアー側の
# 操作のためここでは行わない。mr_numberはプロバイダ間のインターフェース統一のため受け取るが、
# GitHub実装ではスレッドIDがグローバルに一意なため未使用。
#
# 投稿した返信自身のパーマリンク（`.../pull/<n>#discussion_r<id>`）を標準出力へ返す（issue #42:
# レビュー依頼メッセージへ「前回の指摘にどう返信したか」のリンクを載せるため）。mutationの戻り値を
# `comment { id }` から `comment { url }` へ変更している（`id`は呼び出し元で使っていなかった）。
github_add_mr_thread_reply() {
  local mr_number="$1" thread_id="$2" reply_body="$3"
  local mutation
  mutation="$(cat <<'EOF'
mutation($threadId: ID!, $body: String!) {
  addPullRequestReviewThreadReply(input: {pullRequestReviewThreadId: $threadId, body: $body}) {
    comment { url }
  }
}
EOF
)"
  gh api graphql -F "threadId=$thread_id" -F "body=$reply_body" -f "query=$mutation" \
    | jq -r '.data.addPullRequestReviewThreadReply.comment.url // empty' | tr -d '\r'
}

# 指定ブランチに紐づくPRのJSONを返す（無ければ何も出力せず終了コード0）。途中引き継ぎ対応（resume）と、
# comments/describeサブコマンドでの「現在のブランチのMR番号取得」の共通実装として使う。
github_get_mr_for_branch() {
  local branch="$1"
  local json
  if ! json="$(gh pr view "$branch" --json number,url,isDraft,title 2>/dev/null)"; then
    return 0
  fi
  printf '%s' "$json" | jq '{number: .number, url: .url, isDraft: .isDraft, title: .title}'
}

github_set_mr_description() {
  local mr_number="$1" body_file="$2"
  gh pr edit "$mr_number" --body-file "$body_file" >/dev/null
}

# Draft PR/MRのDraft状態を解除し、レビュー・マージ可能な状態にする（flow-id 5-5）。
# `gh pr ready <number>` は、openかつDraftでないPRに対しては警告を出すだけで終了コード0を返す
# （＝冪等に呼べる）。closed/mergedのPRに対してのみ失敗する（`gh`本体のソース
# `pkg/cmd/pr/ready/ready.go` で確認）。
# 成否のメッセージは`gh`が標準エラーへ出すため、`>/dev/null`（標準出力のみ）でも呼び出し側に見える。
github_set_mr_ready() {
  local mr_number="$1"
  gh pr ready "$mr_number" >/dev/null
}

# 2つのref（ブランチ名・SHAいずれも可）間の差分を見れる「Compare changes」ページのURLを
# 組み立てる（純粋関数。`gh`呼び出しを伴わない）。GitHubの`/compare/<from>...<to>`は
# PR作成前から使われている汎用の比較ページであり、PR個別のサブタブ（Files changed等）より
# 広く安定して存在する標準機能。issue #13フォローアップ。
github_get_compare_url() {
  local repo_url="$1" from="$2" to="$3"
  printf '%s/compare/%s...%s\n' "$repo_url" "$from" "$to"
}

# PRの「defaultブランチとの差分」を見れるURLを組み立てる（純粋関数）。issue #13。
github_get_mr_diff_url() {
  local repo_url="$1" base_branch="$2" head_branch="$3"
  github_get_compare_url "$repo_url" "$base_branch" "$head_branch"
}

# PRの「前回push時点(from_sha)から今回push時点(to_sha)までの差分」を見れるURLを組み立てる
# （純粋関数）。issue #13。
github_get_mr_diff_since_url() {
  local repo_url="$1" from_sha="$2" to_sha="$3"
  github_get_compare_url "$repo_url" "$from_sha" "$to_sha"
}

# 特定ファイルの「そのref時点の本体」を開くblobページのURLを組み立てる（純粋関数）。issue #42。
# `ref`はブランチ名・SHAどちらも指定できるが、レビュー依頼メッセージでは「該当push時点」を
# 固定したいためSHAを渡す想定。`path`は呼び出し側でpercent-encode済みのものを渡す
# （`url_encode_path_to_reply`）。
github_get_blob_url() {
  local repo_url="$1" ref="$2" path="$3"
  printf '%s/blob/%s/%s\n' "$repo_url" "$ref" "$path"
}

# Compareページ内の特定ファイルの差分位置を指すアンカー付きURLを組み立てる（純粋関数）。issue #42。
# GitHubの差分アンカーは `#diff-<パス文字列のsha256>`。この算出方法はGitHubの非公開内部仕様のため、
# 実機で確認して採用した（Compareページが差分本体を遅延読込する
# `/<owner>/<repo>/compare/file-list?range=<from>...<to>` の断片HTMLに、
# `id="diff-<sha256(パス)>"` が出力されることを本リポジトリで確認済み）。
github_get_diff_anchor_url() {
  local compare_url="$1" path_hash="$2"
  printf '%s#diff-%s\n' "$compare_url" "$path_hash"
}

# 差分アンカーのハッシュ算出に使うアルゴリズム名を返す（純粋関数）。issue #42。
github_diff_anchor_algo() {
  printf 'sha256\n'
}

# MRへ新規コメントを1件投稿する（スレッド返信・レビューではない通常コメント）。
github_add_mr_comment() {
  local mr_number="$1" body_file="$2"
  gh pr comment "$mr_number" --body-file "$body_file" >/dev/null
}

# --- 敵対的レビュー: インラインコメントの投稿（issue #77） ---
#
# GitHubのレビュー投稿は原子的で、1件でも不正な行があるとレビュー全体が422で失敗する。
# そのため「投稿できる行かどうか」を投稿前に判定する必要があり、その判定を純粋関数として
# 切り出している（.claude/scripts/test/test_vcs_provider.sh でテストする）。

# `repos/{owner}/{repo}/pulls/<n>/files` の出力（標準入力）から、ファイルごとの
# 「新ファイル側の有効行」を範囲の配列 {path: [[start,end],...]} として返す（純粋関数）。
#
# hunkヘッダ `@@ -a,b +c,d @@` の `+c,d` が新ファイル側の範囲で、コメントを付けられるのは
# この範囲内の行（追加行・コンテキスト行）に限られる。`d` を省略した `@@ -a,b +c @@` は1行を意味する。
# 純粋な削除hunk（`d` が0）は新ファイル側に行を持たないため除外する。
#
# 行を1つずつ列挙せず**範囲**で持つのは、jqへ渡すデータ量を差分の大きさに比例させないため
# （.claude/rules/shell-script-style.md「大きなJSONを--argjson等でjqへ渡さない」）。
github_valid_ranges_from_files_json() {
  jq -c '
    [
      .[]
      | {
          key: .filename,
          value: [
            (.patch // "")
            | split("\n")[]
            | select(startswith("@@"))
            | capture("[+](?<s>[0-9]+)(,(?<c>[0-9]+))?")
            | {s: (.s | tonumber), c: (.c // "1" | tonumber)}
            | select(.c > 0)
            | [.s, (.s + .c - 1)]
          ]
        }
    ] | from_entries
  ' | tr -d '\r'
}

# findings（標準入力）を、有効行の範囲マップ（第1引数のファイル）と突き合わせて
# {"post": [...], "summary": [...]} へ振り分ける（純粋関数）。
#
#   - `line` 未指定のfinding（ファイル全体にかかる指摘）は、そのファイルの**有効行の最小値**へ
#     割り当てる。新規追加ファイルはhunkが `@@ -0,0 +1,N @@` になるため、これは1行目に一致する。
#   - 有効行を持たないファイル（diffに現れない・`patch` が省略された）の指摘は summary へ回す。
#     特別扱いのコードは書かず、有効行が空であることから自動的にそうなる。
#   - `side` の既定は "RIGHT"。
github_filter_findings_by_valid_lines() {
  local ranges_file="$1"
  jq -c --slurpfile rangesArr "$ranges_file" '
    ($rangesArr[0] // {}) as $ranges
    | def in_ranges($lines; $n): any($lines[]; .[0] <= $n and $n <= .[1]);
      def resolve($f):
        ($ranges[$f.path] // []) as $lines
        | if ($lines | length) == 0 then null
          elif ($f.line // null) == null
            then ($f + {line: ([$lines[][0]] | min), side: ($f.side // "RIGHT")})
          elif in_ranges($lines; $f.line)
            then ($f + {side: ($f.side // "RIGHT")})
          else null
          end;
      reduce (.findings // [])[] as $f ({post: [], summary: []};
        (resolve($f)) as $r
        | if $r == null then .summary += [$f] else .post += [$r] end)
  ' | tr -d '\r'
}

# 投稿するfindingsの配列（標準入力）とレビュー本文（第1引数のファイル）から、
# `pulls/<n>/reviews` へ渡すレビューJSONを組み立てる（純粋関数）。
# 投稿対象が0件でも `body` だけのレビューとして成立する。
github_build_review_payload() {
  local body_file="$1"
  jq -c --rawfile reviewBody "$body_file" '
    {
      event: "COMMENT",
      body: $reviewBody,
      comments: [
        .[]
        | {
            path: .path,
            line: .line,
            side: (.side // "RIGHT"),
            body: ("Claude Codeより（敵対的レビュー）:\n\n"
                   + "**[" + (.severity // "minor") + " / 確度: " + (.confidence // "medium")
                   + (if .category then " / " + .category else "" end) + "]** "
                   + (.title // "") + "\n\n" + (.body // ""))
          }
      ]
    }
  ' | tr -d '\r'
}

# findings JSONファイルの指摘を、PRへ1回のレビューとしてインライン投稿する。
# 投稿できなかった指摘はレビュー本文（サマリ）へ回す。結果を {"posted":N,"summarized":M} で返す。
github_add_mr_inline_comments() {
  local mr_number="$1" findings_file="$2"
  local tmpdir posted summarized
  tmpdir="$(mktemp -d)"

  gh api "repos/{owner}/{repo}/pulls/${mr_number}/files" --paginate > "$tmpdir/files.json"
  github_valid_ranges_from_files_json < "$tmpdir/files.json" > "$tmpdir/ranges.json"
  github_filter_findings_by_valid_lines "$tmpdir/ranges.json" < "$findings_file" > "$tmpdir/filtered.json"

  jq -c '.summary' "$tmpdir/filtered.json" | format_findings_summary > "$tmpdir/body.md"
  jq -c '.post' "$tmpdir/filtered.json" | github_build_review_payload "$tmpdir/body.md" > "$tmpdir/payload.json"

  gh api "repos/{owner}/{repo}/pulls/${mr_number}/reviews" --input "$tmpdir/payload.json" >/dev/null

  posted="$(jq -r '.post | length' "$tmpdir/filtered.json")"
  summarized="$(jq -r '.summary | length' "$tmpdir/filtered.json")"
  rm -rf "$tmpdir"
  jq -nc --argjson posted "$posted" --argjson summarized "$summarized" \
    '{posted: $posted, summarized: $summarized}'
}

# 任意のissueへ新規コメントを1件投稿する（flow-id 5-2: マージ前の関連issue通知。issue #86。当時のflow-idは 5-3。issue #112 でフェーズ5を並べ替え）。
# 宛先がPR/MRである `github_add_mr_comment` とは別関数。`gh pr comment` はPRにしか投げられず、
# 「今回のMRが影響する他のissue」へ通知する用途に使えないため。
github_add_issue_comment() {
  local issue_number="$1" body_file="$2"
  gh issue comment "$issue_number" --body-file "$body_file" >/dev/null
}

# --- 最終統括レポートの添付（flow-id 5-3・層3。issue #111） ---
#
# **警告: このエンドポイントはGitHubの未ドキュメントな内部APIである。**
# `uploads.github.com/user-attachments/assets` は Web UI のドラッグ＆ドロップが使う経路で、
# 公式のREST APIリファレンスに存在しない。`gh` CLIにも添付用のフラグは無く、要望は2020年から
# 複数回上がって「プラットフォームAPI待ち」でクローズされ続けている
# （https://github.com/cli/cli/issues/12960 ）。**予告なく壊れる前提で扱うこと。**
# 以前はPATでは422になりCookieセッションが必須だったという報告もある
# （https://github.com/cli/cli/issues/13256 ）。
#
# **この不安定さを引き受けてよいのは層3だけである。** 層1（reports/ をリモートへ反映）と
# 層2（サマリのMarkdownコメント）は公式APIだけで完結しており、この関数が失敗しても
# レビューは成立する（.claude/docs/ddr/i0111-01-統括レポートの添付は任意層に置きフローを止めない.md）。
#
# 成功: {"url":"...","markdown":"...","provider":"github"} をstdoutへ / 終了コード0
# 失敗: 理由をstderrへ / 終了コード非0（呼び出し側はスキップする）
github_upload_attachment() {
  local file="$1" content_type="$2"
  local token repo_id name response url

  # `gh auth token` はCLIが認証済みであることを前提とする。`require_vcs_cli` を通っている
  # 時点でCLIは存在するが、認証が切れている場合はここで空文字になる。
  if ! token="$(gh auth token 2>/dev/null)" || [ -z "$token" ]; then
    echo "github_upload_attachment: gh auth token を取得できません（gh auth login が必要）" >&2
    return 1
  fi
  if ! repo_id="$(gh api "repos/{owner}/{repo}" --jq '.id' 2>/dev/null)" || [ -z "$repo_id" ]; then
    echo "github_upload_attachment: リポジトリIDを取得できません" >&2
    return 1
  fi

  name="${file##*/}"
  # クエリ文字列へ入れるためURLエンコードする（日本語を含むレポート名を想定。
  # `REPLY` へ返す規約は .claude/rules/shell-script-style.md「外部プロセス起動のコスト」）。
  url_encode_path_to_reply "$name"
  local encoded_name="$REPLY"
  # `--data-binary @<path>` はファイルの中身をそのまま送る（コマンド文字列へ本文を載せない）。
  # `--fail-with-body` を付けず、HTTPステータスは呼び出し後にレスポンスの形で判定する
  # （このエンドポイントは失敗時にHTMLを返すことがあり、jqが落ちるより先に判定したい）。
  if ! response="$(curl -sS \
      "https://uploads.github.com/user-attachments/assets?name=${encoded_name}&content_type=${content_type}&repository_id=${repo_id}" \
      -X POST \
      -H "Authorization: Bearer ${token}" \
      -H "Accept: application/json" \
      --data-binary "@${file}" 2>&1)"; then
    printf 'github_upload_attachment: アップロードに失敗しました（未ドキュメントAPI。層3はスキップしてよい）: %s\n' "$response" >&2
    return 1
  fi

  # 期待するレスポンスは `href`（署名付きの参照URL）を持つJSON。JSONでなければ失敗として扱う。
  if ! url="$(printf '%s' "$response" | jq -r '.href // empty' 2>/dev/null)" || [ -z "$url" ]; then
    printf 'github_upload_attachment: レスポンスからURLを取得できませんでした（未ドキュメントAPIの仕様変更の可能性。層3はスキップしてよい）\n' >&2
    return 1
  fi

  # GitHubは埋め込み用のmarkdownを返さないため、こちらで組み立てる。
  jq -nc --arg url "$url" --arg name "$name" \
    '{url: $url, markdown: ("[" + $name + "](" + $url + ")"), provider: "github"}'
}
