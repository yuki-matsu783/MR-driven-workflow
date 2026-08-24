#!/usr/bin/env bash
# .claude/scripts/src/vcs/{Github,Gitlab,Provider}.sh の純粋ロジック（`gh`/`glab`呼び出しを
# 伴わないURL組み立て・JSON整形・文字列判定関数）の単体テスト。issue #13対応で追加した
# `github_get_compare_url` / `github_get_mr_diff_url` / `github_get_mr_diff_since_url` /
# `gitlab_get_compare_url` / `gitlab_get_mr_diff_url` / `gitlab_get_mr_diff_since_url` が対象。
# Provider.sh経由のディスパッチは、既定ではGithub.sh/Gitlab.sh の関数を直接呼ぶ形でテストする
# （`get_provider` が `git remote get-url origin` を呼ぶため）。ただし **`get_provider` をサブシェル
# 内でスタブすれば外部コマンドなしでディスパッチそのものを覆える**ため、issue #205 で
# `get_mr_diff_url` の引数の受け渡しについては経路テストを追加した（純粋関数のテストは、その関数へ
# 至る呼び出し経路を何も保証しないため。`.claude/rules/shell-script-style.md`「テスト」・issue #127）。
# issue #44で `get_repo_url` をプロバイダ非依存化した際に切り出した `repo_url_from_remote_url`
# （remote URLからリポジトリの正規URLを導出）も対象。`get_repo_url` 本体は
# `git remote get-url origin` を呼ぶため対象外で、URL文字列を受け取る純粋関数側をテストしている。
# issue #48対応で追加した discussions JSONの整形は、issue #43で `gitlab_normalize_discussions`
# （discussions JSON → 正規化JSON）と共通層の `format_review_comments`（正規化JSON＋スライス
# → テキスト）へ分割された。あわせてGitHub側の `github_normalize_review_threads`（GraphQL JSON
# → 正規化JSON）と、`slice_source_lines` / `truncate_bytes_to_reply`（指摘行前後の切り出しと
# バイト上限の適用）も対象。**GitHub側の整形に単体テストが付いたのはissue #43が初**である
# （それまでは `gh` 依存で切り出せておらず、issue #94のCR混入をテストで検知できなかった）。
# issue #45対応で追加した `provider_from_remote_url`（remote URLのホスト部からプロバイダを判定）も
# 対象。`get_provider` 本体は `git remote get-url origin` を呼ぶため対象外で、URL文字列を
# 受け取る純粋関数側を切り出してテストしている。
# あわせてissue #34で追加した `parse_repo_slug`（リモートURLのパース）と `mcp_tool_hint`
# （CLI不在時に提示するMCPツール名）も対象とする。後者は `get_provider` をテスト内で上書きして
# プロバイダを固定する。
# issue #42で追加した `github_get_blob_url` / `github_get_diff_anchor_url` /
# `github_diff_anchor_algo` / `gitlab_get_blob_url` / `gitlab_get_diff_anchor_url` /
# `gitlab_diff_anchor_algo` / `gitlab_get_mr_url` / `gitlab_get_note_url` / `url_encode_path_to_reply`
# と、`hash_paths`（差分アンカー用にパス文字列のハッシュをまとめて計算する）も対象。
# `hash_paths` だけは `sha256sum`/`sha1sum` を起動するが、`gh`/`glab` に依存せず入力から出力が
# 一意に決まるため単体テストの対象に含めている。
# issue #86で追加した `add_issue_comment`（任意のissueへのコメント投稿）は `gh`/`glab` を呼ぶため
# 関数本体は対象外で、`mcp_tool_hint` が返す代替ツール名のみを対象とする。
# issue #111で追加した `content_type_from_path_to_reply`（拡張子からContent-Typeを推定）も対象。
# `upload_attachment` 本体・`github_upload_attachment` / `gitlab_upload_attachment` は
# `gh`/`glab`・ネットワークを呼ぶため対象外で、引数検証の早期リターンと `mcp_tool_hint` が返す
# 「MCPには代替が無い」という案内のみを対象とする。
# issue #68で追加した `github_normalize_issue_search_results` /
# `gitlab_normalize_issue_search_results`（CLIのissue検索出力を共通形式へ正規化）と
# `merge_issue_search_results`（複数キーワードぶんの結果を重複排除して統合）も対象。
# issue #121で追加した `gitlab_summary_post_kind`
# （サマリを `discussions`（スレッド）と `notes`（単発note）のどちらで投稿するかの判定）も対象。
# `gitlab_add_mr_thread` 本体は `glab` を呼ぶため対象外で、投稿先を決める純粋関数側をテストする。
# issue #115で追加した `porcelain_z_to_paths`（`git status --porcelain -z` の出力を1行1パスへ
# 変換し、改名・コピーの旧パスを捨てる）も対象。`get_branch_work_files` 本体は `git` を起動する
# ため対象外で、その未コミット分の解釈を担う純粋関数側を切り出してテストしている。
# issue #170で追加した `add_empty_commit_for_draft_mr` の引数検証も対象。`git` を起動する
# 非純粋関数だが、`git` をシェル関数でスタブして呼ぶため外部プロセス・ネットワークを使わない
# （ファイル末尾のブロック参照）。
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

# 長い案内文の一部だけを固定したいとき用（issue #111）。文言の全文を期待値に置くと、
# 語尾の推敲のたびにテストが壊れるだけで、守りたい性質（何を案内しているか）は守れない。
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

# --- github_get_compare_url / github_get_mr_diff_url / github_get_mr_diff_since_url -------

assert_eq "github_get_compare_url: リポジトリURLに/compare/<from>...<to>を付与" \
  "https://github.com/o/r/compare/main...aaa111" \
  "$(github_get_compare_url "https://github.com/o/r" "main" "aaa111")"

assert_eq "github_get_mr_diff_url: defaultブランチとの比較URL（ブランチ名指定）" \
  "https://github.com/o/r/compare/main...feature-13-x" \
  "$(github_get_mr_diff_url "https://github.com/o/r" "main" "feature-13-x")"

# issue #205: 第4引数（MR/PR URL）を渡すとDiffview（Files changedタブ）を返す。
# 渡さない／空を渡した場合は従来どおりCompareページ（＝CLI不在環境で後退しない）。
assert_eq "github_get_mr_diff_url: MR/PR URLを渡すとFiles changedタブのURLを返す" \
  "https://github.com/o/r/pull/206/files" \
  "$(github_get_mr_diff_url "https://github.com/o/r" "main" "feature-13-x" "https://github.com/o/r/pull/206")"

assert_eq "github_get_mr_diff_url: 第4引数が空文字ならCompareページのまま" \
  "https://github.com/o/r/compare/main...feature-13-x" \
  "$(github_get_mr_diff_url "https://github.com/o/r" "main" "feature-13-x" "")"

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

# issue #205: GitHubと同型。GitLabはDiffsタブ（`/diffs`）。
assert_eq "gitlab_get_mr_diff_url: MR URLを渡すとDiffsタブのURLを返す" \
  "https://gitlab.example.com/o/r/-/merge_requests/206/diffs" \
  "$(gitlab_get_mr_diff_url "https://gitlab.example.com/o/r" "main" "feature-13-x" "https://gitlab.example.com/o/r/-/merge_requests/206")"

assert_eq "gitlab_get_mr_diff_url: 第4引数が空文字ならCompareページのまま" \
  "https://gitlab.example.com/o/r/-/compare/main...feature-13-x" \
  "$(gitlab_get_mr_diff_url "https://gitlab.example.com/o/r" "main" "feature-13-x" "")"

assert_eq "gitlab_get_mr_diff_since_url: 前回push〜今回pushのSHA範囲の比較URL" \
  "https://gitlab.example.com/o/r/-/compare/aaa111...bbb222" \
  "$(gitlab_get_mr_diff_since_url "https://gitlab.example.com/o/r" "aaa111" "bbb222")"

# --- レビューコメントの正規化と整形（issue #48, #77, #43） ---------------------------------
# issue #43 で出力仕様を作り替え、プロバイダ層は「正規化JSONを返す」だけになった。
# テキスト整形は共通層の `format_review_comments` が担う（GitHub/GitLab 双方が通る）。
#
# `format_review_comments` は正規化JSONとスライスJSONを**ファイルパス**で受け取る
# （大きなJSONを `--argjson` で渡すと `jq: Argument list too long` になるため。
# `.claude/rules/shell-script-style.md`「JSON操作」）。テストからは次のヘルパー経由で呼ぶ。
render_comments() { # $1=正規化JSON $2=スライスJSON（省略時は空）
  local normalized="$1" slices="${2:-}" tmp
  # 既定値にバックスラッシュを書かない（`"${2:-\{\}}"` は `\{\}` という文字列になる。issue #23）
  [ -n "$slices" ] || slices='{}'
  tmp="$(mktemp -d)"
  printf '%s' "$normalized" > "$tmp/n.json"
  printf '%s' "$slices" > "$tmp/s.json"
  format_review_comments "$tmp/n.json" "$tmp/s.json"
  rm -rf "$tmp"
}

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

# issue #43: 行頭のラベルは GitHub/GitLab で共通の `[review ...]` になった。
# それ以前はGitLab側だけ `[unresolved ...]` で、`.claude/hooks/session-start.sh` の
# `^\[review unresolved threadId=` に一致せず、**未解決件数が常に0件**と表示されていた。
assert_eq "format_review_comments(GitLab): 既定では未解決のみ返し、システムノートと解決済みを除外する" \
  "[review unresolved threadId=d1] reviewer: ここは修正してください

[review unresolved threadId=d4] root: 通常コメント" \
  "$(render_comments "$(gitlab_normalize_discussions "$gitlab_discussions_fixture")")"

assert_eq "format_review_comments(GitLab): include_resolved=trueでは解決済みを含むがシステムノートは除外する" \
  "[review unresolved threadId=d1] reviewer: ここは修正してください

[review resolved threadId=d2] reviewer: 対応済みの指摘

[review unresolved threadId=d4] root: 通常コメント" \
  "$(render_comments "$(gitlab_normalize_discussions "$gitlab_discussions_fixture" true)")"

assert_eq "gitlab_normalize_discussions: システムノートのbodyは全件取得時も出力に現れない" \
  "0" \
  "$(gitlab_normalize_discussions "$gitlab_discussions_fixture" true | grep -c 'changed the description' || true)"

# issue #42: 第3引数にMRのURLを渡すと、各noteの公式パーマリンクを url= として行に含める。
assert_eq "format_review_comments(GitLab): mr_urlを渡すとnoteのパーマリンクをurl=として含める" \
  "[review unresolved threadId=d1 url=https://gitlab.example.com/o/r/-/merge_requests/42#note_1] reviewer: ここは修正してください

[review unresolved threadId=d4 url=https://gitlab.example.com/o/r/-/merge_requests/42#note_4] root: 通常コメント" \
  "$(render_comments "$(gitlab_normalize_discussions "$gitlab_discussions_fixture" false \
    "https://gitlab.example.com/o/r/-/merge_requests/42")")"

assert_eq "gitlab_normalize_discussions: mr_urlが空ならurlはnull（従来どおりurl=が付かない）" \
  "$(render_comments "$(gitlab_normalize_discussions "$gitlab_discussions_fixture")")" \
  "$(render_comments "$(gitlab_normalize_discussions "$gitlab_discussions_fixture" false "")")"

# resolvableでないnote（individual_note等）は resolved 扱いにせず常に含める。
assert_eq "gitlab_normalize_discussions: resolvableでないnoteはunresolvedとして扱う" \
  "[review unresolved threadId=d4] root: 通常コメント" \
  "$(render_comments "$(gitlab_normalize_discussions '[{"id":"d4","individual_note":true,"notes":[{"id":4,"body":"通常コメント","author":{"username":"root"},"system":false,"resolvable":false}]}]')")"

# Windowsネイティブjqは出力行末にCRを付与するため、関数側で除去している
# （.claude/rules/shell-script-style.md「文字コード」）。CRの検査はバイト数比較で行う
# （`grep -c $'\r'` は環境によって空パターン扱いになり全行にマッチするため使わない）。
# issue #43 以前、この検査はGitLab側にしか無く、GitHub側の同種の混入（issue #94）は
# テストでは検知できなかった。整形が共通化されたことで両プロバイダがこの1件でカバーされる。
gitlab_notes_output="$(render_comments "$(gitlab_normalize_discussions "$gitlab_discussions_fixture" true)")"
assert_eq "format_review_comments: 出力にCRが混入しない" \
  "$(printf '%s' "$gitlab_notes_output" | wc -c)" \
  "$(printf '%s' "$gitlab_notes_output" | tr -d '\r' | wc -c)"

gitlab_normalized_output="$(gitlab_normalize_discussions "$gitlab_discussions_fixture" true)"
assert_eq "gitlab_normalize_discussions: 正規化JSONにCRが混入しない" \
  "$(printf '%s' "$gitlab_normalized_output" | wc -c)" \
  "$(printf '%s' "$gitlab_normalized_output" | tr -d '\r' | wc -c)"

# --- Provider.sh のディスパッチ経路（issue #205） ----------------------------------------
#
# `get_mr_diff_url` が第4引数（MR/PR URL）を下位のプロバイダ関数へ渡していることを確かめる。
# **純粋関数側（`github_get_mr_diff_url` 等）のテストだけでは、ここが漏れても全部緑のまま**で、
# hookは黙って従来のCompareを返し続ける（issue #127 と同型の失敗）。
#
# `get_provider` の差し替えは**サブシェルへ閉じ込める**。`unset -f` で戻す形にすると、bashの関数
# 定義はスタックしないため実定義そのものが消える。またサブシェルの中で `assert_eq` を呼ぶと
# `failures` の加算が呼び出し元へ伝わらず、失敗しても緑になるので、値だけを持ち出して外で判定する。
#
# **この位置（下の `get_provider` 全域上書きより前）へ置くこと。** 下のブロックは
# 「この上書きは以降のテスト全体に効く」と宣言しており、そこより後ろへ置くと、何を固定している
# テストなのかが変わってしまう。

assert_eq "get_mr_diff_url: 第4引数をgithub実装へ渡す" \
  "https://github.com/o/r/pull/206/files" \
  "$( get_provider() { printf 'github\n'; }; \
      get_mr_diff_url 'https://github.com/o/r' 'main' 'feat' 'https://github.com/o/r/pull/206' )"

assert_eq "get_mr_diff_url: 第4引数を省略するとgithubのCompareページ" \
  "https://github.com/o/r/compare/main...feat" \
  "$( get_provider() { printf 'github\n'; }; \
      get_mr_diff_url 'https://github.com/o/r' 'main' 'feat' )"

assert_eq "get_mr_diff_url: 第4引数をgitlab実装へ渡す" \
  "https://gitlab.example.com/o/r/-/merge_requests/206/diffs" \
  "$( get_provider() { printf 'gitlab\n'; }; \
      get_mr_diff_url 'https://gitlab.example.com/o/r' 'main' 'feat' 'https://gitlab.example.com/o/r/-/merge_requests/206' )"

assert_eq "get_mr_diff_url: 第4引数を省略するとgitlabのCompareページ" \
  "https://gitlab.example.com/o/r/-/compare/main...feat" \
  "$( get_provider() { printf 'gitlab\n'; }; \
      get_mr_diff_url 'https://gitlab.example.com/o/r' 'main' 'feat' )"

# 差し替えがサブシェルに閉じており、実定義が残っていることを表明する
# （`declare -F` は名前だけを出力する。代入の形にすると未定義時に `set -e` でスクリプトごと落ちる）
assert_eq "get_providerの実定義が残っている" "get_provider" \
  "$(declare -F get_provider >/dev/null && echo get_provider)"

# --- github_resolve_mr_number_for_head（issue #205） --------------------------------------
#
# `git` をシェル関数で差し替えて、`ls-remote` の出力ごとの戻り値を確かめる。
# **最も重要なのは「一致がちょうど1件のときだけ返す」ことと、「失敗しても空＋終了コード0」**である。
# 後者は、非0が漏れると呼び出し元（`set -euo pipefail` 配下のhook）が途中終了し、レビュー依頼
# メッセージが1行も出なくなるため（現行より明確な後退になる）。

# 1件だけ一致 → その番号を返す
assert_eq "resolve: HEADに一致するrefが1件ならPR番号を返す" \
  "206" \
  "$( git() {
        case "$1" in
          remote) printf 'https://github.com/o/r.git\n' ;;
          *) printf 'aaa111\trefs/pull/206/head\nbbb222\trefs/pull/85/head\n' ;;
        esac
      }
      github_resolve_mr_number_for_head 'aaa111' )"

# 0件 → 空（Compareへ縮退する）
assert_eq "resolve: 一致するrefが無ければ空を返す" \
  "" \
  "$( git() {
        case "$1" in
          remote) printf 'https://github.com/o/r.git\n' ;;
          *) printf 'bbb222\trefs/pull/85/head\n' ;;
        esac
      }
      github_resolve_mr_number_for_head 'aaa111' )"

# 2件以上一致 → 空（番号の大小では正しいPRを選べないため、諦めてCompareへ縮退する）
assert_eq "resolve: 2件以上一致したら諦めて空を返す" \
  "" \
  "$( git() {
        case "$1" in
          remote) printf 'https://github.com/o/r.git\n' ;;
          *) printf 'aaa111\trefs/pull/206/head\naaa111\trefs/pull/207/head\n' ;;
        esac
      }
      github_resolve_mr_number_for_head 'aaa111' )"

# SSH remote → ls-remote を起動せずに空を返す
# （`http.*` のタイムアウトもプロンプト抑止もsshには効かず、hookが無応答になりうるため）
assert_eq "resolve: scp形式のremoteでは解決を試みない" \
  "" \
  "$( git() {
        case "$1" in
          remote) printf 'git@github.com:o/r.git\n' ;;
          *) printf 'aaa111\trefs/pull/206/head\n' ;;
        esac
      }
      github_resolve_mr_number_for_head 'aaa111' )"

assert_eq "resolve: ssh://形式のremoteでは解決を試みない" \
  "" \
  "$( git() {
        case "$1" in
          remote) printf 'ssh://git@github.com/o/r.git\n' ;;
          *) printf 'aaa111\trefs/pull/206/head\n' ;;
        esac
      }
      github_resolve_mr_number_for_head 'aaa111' )"

# ls-remote が失敗 → 空。**かつ終了コードは0**（最も起きやすい経路）
assert_eq "resolve: ls-remoteが失敗したら空を返す" \
  "" \
  "$( git() {
        case "$1" in
          remote) printf 'https://github.com/o/r.git\n' ;;
          *) return 128 ;;
        esac
      }
      github_resolve_mr_number_for_head 'aaa111' )"

if ( git() {
       case "$1" in
         remote) printf 'https://github.com/o/r.git\n' ;;
         *) return 128 ;;
       esac
     }
     github_resolve_mr_number_for_head 'aaa111' >/dev/null ); then
  resolve_fail_status=0
else
  resolve_fail_status=1
fi
assert_eq "resolve: ls-remoteが失敗しても終了コードは0" "0" "$resolve_fail_status"

# `git` の実定義（外部コマンド）がシェル関数として残っていないことを表明する
assert_eq "gitがシェル関数として残っていない" "" \
  "$(declare -F git >/dev/null && echo git)"

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

assert_eq "mcp_tool_hint: search_issues（GitHub。issue #68）" \
  "mcp__github__search_issues (query, owner, repo)" \
  "$(mcp_tool_hint search_issues)"

# issue #61で追加したDraft解除の関数。`set_mr_description` と同じ `update_pull_request` を使うが、
# 渡す引数が `body` ではなく `draft=false`（＝ready for review）である点が異なる
assert_eq "mcp_tool_hint: set_mr_ready（GitHub）" \
  "mcp__github__update_pull_request (owner, repo, pullNumber, draft=false)" \
  "$(mcp_tool_hint set_mr_ready)"

# issue #86で追加した関連issue通知の関数。`add_mr_comment` と同じ
# `mcp__github__add_issue_comment` を使うが、`issue_number` へ渡すのがPR番号ではなく
# **通知先のissue番号**である点が違うため、その差分がヒント文に出ることを固定する
assert_eq "mcp_tool_hint: add_issue_comment（GitHub。issue #86）" \
  "mcp__github__add_issue_comment (owner, repo, issue_number=通知先issue番号, body=ファイル内容)" \
  "$(mcp_tool_hint add_issue_comment)"

assert_eq "mcp_tool_hint: add_mr_comment はPR番号を渡す旨のまま（add_issue_commentと混同しない）" \
  "mcp__github__add_issue_comment (owner, repo, issue_number=PR番号, body=ファイル内容)" \
  "$(mcp_tool_hint add_mr_comment)"

# issue #111で追加した添付関数。**MCPに代替が存在しない唯一の分岐**であり、他の関数のように
# 読み替え先のツール名を返せない。代わりに「スキップしてよい」ことを名指しで返す
# （層1・層2だけでレビューが成立する設計であるため）
upload_hint="$(mcp_tool_hint upload_attachment)"
assert_contains "mcp_tool_hint: upload_attachment はMCPに代替が無いと明示する（issue #111）" \
  "$upload_hint" "対応するMCPツールはありません"
assert_contains "mcp_tool_hint: upload_attachment はスキップしてよいと案内する（issue #111）" \
  "$upload_hint" "スキップしてよい"
assert_contains "mcp_tool_hint: upload_attachment は層1・層2で成立する旨を添える（issue #111）" \
  "$upload_hint" "層1・層2"

assert_eq "mcp_tool_hint: 未知の関数名でも空にならず対応表（references/mcp-fallback.md）へ誘導する" \
  "対応するMCPツールは .claude/skills/issue-mr-flow/references/mcp-fallback.md の対応表を参照" \
  "$(mcp_tool_hint unknown_function)"

# require_vcs_cli の出力検証（issue #160で新設。従来はどのテストも373行目の出力を見ておらず、
# 案内先を変え忘れても全テストが緑のまま通った。調査 D-3）。
# 差し替えはサブシェルへ閉じ込め、assert_* はサブシェルの外で行う（unset -f は実定義を消す）。
require_vcs_cli_output="$( get_vcs_access_mode() { printf 'mcp\n'; }; require_vcs_cli get_issue 2>&1 || true )"
assert_contains "require_vcs_cli: MCPフォールバックの手順の場所（references/mcp-fallback.md）を案内する" \
  "$require_vcs_cli_output" ".claude/skills/issue-mr-flow/references/mcp-fallback.md"
assert_contains "require_vcs_cli: WebFetch・curlへ逃げない旨を案内する（DDR i0014-01）" \
  "$require_vcs_cli_output" "WebFetch"
if ( get_vcs_access_mode() { printf 'mcp\n'; }; require_vcs_cli get_issue >/dev/null 2>&1 ); then
  require_vcs_cli_status=0
else
  require_vcs_cli_status=1
fi
assert_eq "require_vcs_cli: mcp経路では失敗（終了コード1）を返す" "1" "$require_vcs_cli_status"

get_provider() { printf 'gitlab\n'; }

assert_eq "mcp_tool_hint: GitLabは対象外である旨を返す" \
  "GitLab向けのMCPフォールバックは対象外です（DDR i0034-01）。glab CLIをインストール・認証してください" \
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

# scheme・ポートも返す（issue #44。`repo_url_from_remote_url` がWeb URLを組み立てる際に、
# 「httpは維持する」「ポートはhttp/httpsのときだけ引き継ぐ」を判断するために使う）
split_remote_url 'https://gitlab.example.com:8443/o/r.git'
assert_eq "split_remote_url: httpsのschemeとポート" \
  "https|8443" "$REPLY_SCHEME|$REPLY_PORT"

split_remote_url 'ssh://git@ghe.example.com:2222/o/r.git'
assert_eq "split_remote_url: ssh://のschemeとポート" "ssh|2222" "$REPLY_SCHEME|$REPLY_PORT"

# scp形式は `://` を持たずポートも表現できない
split_remote_url 'git@github.com:o/r.git'
assert_eq "split_remote_url: scp形式はscheme・ポートとも空" "|" "$REPLY_SCHEME|$REPLY_PORT"

split_remote_url 'https://github.com/o/r.git'
assert_eq "split_remote_url: ポート指定が無ければ空" "https|" "$REPLY_SCHEME|$REPLY_PORT"

# schemeは小文字化する（ホスト名と同じくURLの正規化として安全）
split_remote_url 'HTTPS://github.com/o/r.git'
assert_eq "split_remote_url: schemeは小文字化" "https|github.com" "$REPLY_SCHEME|$REPLY_HOST"

# --- repo_url_from_remote_url（issue #44: リポジトリURLをgit remoteから導出） ---------------
#
# `gh repo view --json url` / `glab repo view --output json`（`.web_url`）の代わりに、
# remote URLの正規化だけでリポジトリの正規URLを得る純粋関数。CLI・ネットワークに依存しないため
# そのままテストできる。

assert_eq "repo_url_from_remote_url: https形式（.git付き）" \
  "https://github.com/o/r" \
  "$(repo_url_from_remote_url 'https://github.com/o/r.git')"

assert_eq "repo_url_from_remote_url: https形式（.git無し）" \
  "https://github.com/o/r" \
  "$(repo_url_from_remote_url 'https://github.com/o/r')"

assert_eq "repo_url_from_remote_url: 末尾スラッシュを除去" \
  "https://github.com/o/r" \
  "$(repo_url_from_remote_url 'https://github.com/o/r/')"

assert_eq "repo_url_from_remote_url: scp形式SSHはhttpsへ変換" \
  "https://github.com/o/r" \
  "$(repo_url_from_remote_url 'git@github.com:o/r.git')"

assert_eq "repo_url_from_remote_url: ssh://形式もhttpsへ変換" \
  "https://github.com/o/r" \
  "$(repo_url_from_remote_url 'ssh://git@github.com/o/r.git')"

# 本リポジトリの実際のremote URL。`gh repo view --json url --jq '.url'` の出力と一致すること
# （issue #44の受け入れ条件。実機で確認済み）
assert_eq "repo_url_from_remote_url: 本リポジトリのremote URL" \
  "https://github.com/yuki-matsu783/MR-driven-workflow" \
  "$(repo_url_from_remote_url 'https://github.com/yuki-matsu783/MR-driven-workflow.git')"

# ホスト名は小文字化し、パス（owner/repo）の大文字は保つ（`split_remote_url` の規則をそのまま継ぐ）
assert_eq "repo_url_from_remote_url: ホストは小文字化・パスは保つ" \
  "https://github.com/O/R" \
  "$(repo_url_from_remote_url 'https://GitHub.COM/O/R.git')"

# GitLabのネストしたnamespaceはパスをそのまま保つ
assert_eq "repo_url_from_remote_url: ネストしたnamespace" \
  "https://gitlab.example.com/g/sub/r" \
  "$(repo_url_from_remote_url 'https://gitlab.example.com/g/sub/r.git')"

# SSHのポートはWeb UIのポートではないため引き継がない（引き継ぐとリンクが壊れる）
assert_eq "repo_url_from_remote_url: ssh://のポートは引き継がない" \
  "https://ghe.example.com/o/r" \
  "$(repo_url_from_remote_url 'ssh://git@ghe.example.com:2222/o/r.git')"

# http/httpsのポートはWeb UIのポートなので引き継ぐ（self-hosted GitLabのdocker構成等）
assert_eq "repo_url_from_remote_url: httpsのポートは引き継ぐ" \
  "https://gitlab.example.com:8443/o/r" \
  "$(repo_url_from_remote_url 'https://gitlab.example.com:8443/o/r.git')"

# plain httpのself-hosted GitLabは http のままにする（httpsへ寄せるとリンクが壊れる）
assert_eq "repo_url_from_remote_url: httpはhttpのまま・ポートも保つ" \
  "http://localhost:8929/g/r" \
  "$(repo_url_from_remote_url 'http://localhost:8929/g/r.git')"

# 認証情報 user@ は落とす（パス中の `@` へ誤爆しないことは split_remote_url 側でも固定済み）
assert_eq "repo_url_from_remote_url: 認証情報は落とす" \
  "https://gitlab.com:8080/foo/b@r" \
  "$(repo_url_from_remote_url 'https://user@gitlab.com:8080/foo/b@r.git')"

# ホスト・パスが取れない入力は `https:///` のような壊れたURLを返さず失敗させる。
# 終了コードの検査は `$(func; echo $?)` ではなく `if` で受ける
# （.claude/rules/shell-script-style.md「テスト」）
if repo_url_from_remote_url 'https://' >/dev/null 2>&1; then
  empty_repo_url_status=0
else
  empty_repo_url_status=1
fi
assert_eq "repo_url_from_remote_url: ホスト名が空なら終了コード1" "1" "$empty_repo_url_status"

if repo_url_from_remote_url 'https://github.com' >/dev/null 2>&1; then
  no_path_status=0
else
  no_path_status=1
fi
assert_eq "repo_url_from_remote_url: パスが空なら終了コード1" "1" "$no_path_status"

# `parse_repo_slug` の `.url` は同じ組み立て規則を共有する（両者が食い違わないこと。issue #44）
assert_eq "parse_repo_slug: .url は repo_url_from_remote_url と一致する（scp形式）" \
  "$(repo_url_from_remote_url 'git@github.com:o/r.git')" \
  "$(parse_repo_slug 'git@github.com:o/r.git' | jq -r '.url')"

assert_eq "parse_repo_slug: .url は repo_url_from_remote_url と一致する（http・ポート付き）" \
  "$(repo_url_from_remote_url 'http://localhost:8929/g/r.git')" \
  "$(parse_repo_slug 'http://localhost:8929/g/r.git' | jq -r '.url')"

# --- issue検索結果の正規化・統合（issue #68: 起票前の重複チェック） ------------------------
# `github_search_issues` / `gitlab_search_issues` / `search_issues` 本体は `gh`/`glab` と
# `get_provider` に依存するため対象外とし、CLI出力を受け取るだけの純粋関数
# （`*_normalize_issue_search_results`）と、その結果を統合する `merge_issue_search_results` を
# テストする（`gitlab_format_discussion_notes` と同じ切り出し方）。
#
# キーワード抽出の関数は実装していないため、その単体テストも存在しない（抽出は
# `issue-create` スキル側でAIエージェントが行う。理由:
# .claude/docs/ddr/i0068-01-issue起票前の重複チェックは検索をProvider層へ置きキーワード抽出はAIに委ねる.md）。

# GitHub CLIの `OPEN`/`CLOSED` を小文字へ揃え、キーを number/title/state/url に正規化する
assert_eq "github_normalize_issue_search_results: stateを小文字化しキーを揃える" \
  '[{"number":68,"title":"重複チェック","state":"open","url":"https://github.com/o/r/issues/68"},{"number":5,"title":"旧提案","state":"closed","url":"https://github.com/o/r/issues/5"}]' \
  "$(github_normalize_issue_search_results '[{"number":68,"title":"重複チェック","state":"OPEN","url":"https://github.com/o/r/issues/68"},{"number":5,"title":"旧提案","state":"CLOSED","url":"https://github.com/o/r/issues/5"}]')"

assert_eq "github_normalize_issue_search_results: 該当0件は空配列のまま" \
  '[]' \
  "$(github_normalize_issue_search_results '[]')"

# GitLabは iid / web_url / opened というキー・値を返すため読み替える
assert_eq "gitlab_normalize_issue_search_results: iid・web_url・openedを読み替える" \
  '[{"number":7,"title":"検索関数の追加","state":"open","url":"https://gitlab.example.com/g/r/-/issues/7"}]' \
  "$(gitlab_normalize_issue_search_results '[{"iid":7,"title":"検索関数の追加","state":"opened","web_url":"https://gitlab.example.com/g/r/-/issues/7"}]')"

assert_eq "gitlab_normalize_issue_search_results: closedはそのまま" \
  '[{"number":3,"title":"x","state":"closed","url":"https://gitlab.example.com/g/r/-/issues/3"}]' \
  "$(gitlab_normalize_issue_search_results '[{"iid":3,"title":"x","state":"closed","web_url":"https://gitlab.example.com/g/r/-/issues/3"}]')"

# 複数キーワードぶんの検索結果を、numberで重複排除しつつ番号の降順で統合する
assert_eq "merge_issue_search_results: 連結・重複排除・番号の降順" \
  '[{"number":68,"title":"b","state":"open","url":"u68"},{"number":12,"title":"c","state":"closed","url":"u12"},{"number":5,"title":"a","state":"open","url":"u5"}]' \
  "$(merge_issue_search_results \
    '[{"number":5,"title":"a","state":"open","url":"u5"},{"number":68,"title":"b","state":"open","url":"u68"}]' \
    '[{"number":68,"title":"b","state":"open","url":"u68"},{"number":12,"title":"c","state":"closed","url":"u12"}]')"

# 引数0個で `printf '%s\n' "$@"` の空行がjqのパースエラーになるのを防いでいること
assert_eq "merge_issue_search_results: 引数0個なら空配列" \
  '[]' \
  "$(merge_issue_search_results)"

assert_eq "merge_issue_search_results: 空配列だけを渡しても空配列" \
  '[]' \
  "$(merge_issue_search_results '[]' '[]')"

assert_eq "merge_issue_search_results: 1件だけでもそのまま配列で返す" \
  '[{"number":68,"title":"b","state":"open","url":"u68"}]' \
  "$(merge_issue_search_results '[{"number":68,"title":"b","state":"open","url":"u68"}]')"

# --- 敵対的レビュー（issue #77）: インラインコメント投稿の純粋関数 ---

fixture_files_json='[
  {"filename":"new.sh","patch":"@@ -0,0 +1,3 @@\n+a\n+b\n+c"},
  {"filename":"multi.md","patch":"@@ -1,5 +14,7 @@ ctx\n ...\n@@ -30,2 +100,3 @@\n x"},
  {"filename":"binary.png"},
  {"filename":"deleted-only.txt","patch":"@@ -1,2 +1,0 @@\n-x"},
  {"filename":"one-line.txt","patch":"@@ -5 +7 @@\n-a\n+b"}
]'

assert_eq "github_valid_ranges_from_files_json: 新規ファイルは1行目から有効" \
  '[[1,3]]' \
  "$(printf '%s' "$fixture_files_json" | github_valid_ranges_from_files_json | jq -c '.["new.sh"]')"

assert_eq "github_valid_ranges_from_files_json: 複数hunkを連結する" \
  '[[14,20],[100,102]]' \
  "$(printf '%s' "$fixture_files_json" | github_valid_ranges_from_files_json | jq -c '.["multi.md"]')"

assert_eq "github_valid_ranges_from_files_json: patchが無いファイルは空" \
  '[]' \
  "$(printf '%s' "$fixture_files_json" | github_valid_ranges_from_files_json | jq -c '.["binary.png"]')"

# 純粋な削除hunk（新ファイル側の行数が0）は、RIGHT側にコメントできる行を持たない
assert_eq "github_valid_ranges_from_files_json: 新ファイル側0行のhunkは除外" \
  '[]' \
  "$(printf '%s' "$fixture_files_json" | github_valid_ranges_from_files_json | jq -c '.["deleted-only.txt"]')"

# `@@ -a +c @@` のように行数を省略した形は1行を意味する
assert_eq "github_valid_ranges_from_files_json: 行数省略形は1行として扱う" \
  '[[7,7]]' \
  "$(printf '%s' "$fixture_files_json" | github_valid_ranges_from_files_json | jq -c '.["one-line.txt"]')"

assert_eq "github_valid_ranges_from_files_json: 空配列なら空オブジェクト" \
  '{}' \
  "$(printf '%s' '[]' | github_valid_ranges_from_files_json)"

ranges_file="$(mktemp)"
printf '%s' '{"new.sh":[[1,3]],"multi.md":[[14,20],[100,102]],"binary.png":[]}' > "$ranges_file"

assert_eq "github_filter_findings_by_valid_lines: findingsが0件なら両方空" \
  '{"post":[],"summary":[]}' \
  "$(printf '%s' '{"findings":[]}' | github_filter_findings_by_valid_lines "$ranges_file")"

assert_eq "github_filter_findings_by_valid_lines: 有効行内なら投稿対象" \
  '2' \
  "$(printf '%s' '{"findings":[{"path":"new.sh","line":2}]}' | github_filter_findings_by_valid_lines "$ranges_file" | jq -r '.post[0].line')"

assert_eq "github_filter_findings_by_valid_lines: sideの既定はRIGHT" \
  'RIGHT' \
  "$(printf '%s' '{"findings":[{"path":"new.sh","line":2}]}' | github_filter_findings_by_valid_lines "$ranges_file" | jq -r '.post[0].side')"

# ファイル全体にかかる指摘（line未指定）は、そのファイルの有効行の最小値へ寄せる。
# 新規追加ファイルではhunkが `@@ -0,0 +1,N @@` になるため1行目に一致する。
assert_eq "github_filter_findings_by_valid_lines: line未指定は有効行の最小値へ寄る" \
  '1' \
  "$(printf '%s' '{"findings":[{"path":"new.sh"}]}' | github_filter_findings_by_valid_lines "$ranges_file" | jq -r '.post[0].line')"

assert_eq "github_filter_findings_by_valid_lines: 既存ファイルのline未指定は1ではなく最小有効行" \
  '14' \
  "$(printf '%s' '{"findings":[{"path":"multi.md"}]}' | github_filter_findings_by_valid_lines "$ranges_file" | jq -r '.post[0].line')"

assert_eq "github_filter_findings_by_valid_lines: 有効行外はサマリ行き" \
  '1' \
  "$(printf '%s' '{"findings":[{"path":"multi.md","line":5}]}' | github_filter_findings_by_valid_lines "$ranges_file" | jq -r '.summary | length')"

assert_eq "github_filter_findings_by_valid_lines: 2つ目のhunk内なら投稿対象" \
  '101' \
  "$(printf '%s' '{"findings":[{"path":"multi.md","line":101}]}' | github_filter_findings_by_valid_lines "$ranges_file" | jq -r '.post[0].line')"

assert_eq "github_filter_findings_by_valid_lines: diffに無いパスはサマリ行き" \
  '0 1' \
  "$(printf '%s' '{"findings":[{"path":"not-in-diff.md","line":1}]}' | github_filter_findings_by_valid_lines "$ranges_file" | jq -r '"\(.post | length) \(.summary | length)"')"

assert_eq "github_filter_findings_by_valid_lines: 有効行が空のファイルはサマリ行き" \
  '0 1' \
  "$(printf '%s' '{"findings":[{"path":"binary.png"}]}' | github_filter_findings_by_valid_lines "$ranges_file" | jq -r '"\(.post | length) \(.summary | length)"')"

assert_eq "github_filter_findings_by_valid_lines: findingsキーが無くても落ちない" \
  '{"post":[],"summary":[]}' \
  "$(printf '%s' '{}' | github_filter_findings_by_valid_lines "$ranges_file")"

review_body_file="$(mktemp)"
printf 'レビュー本文' > "$review_body_file"

assert_eq "github_build_review_payload: 投稿0件でも本文だけのレビューになる" \
  'COMMENT 0 レビュー本文' \
  "$(printf '%s' '[]' | github_build_review_payload "$review_body_file" | jq -r '"\(.event) \(.comments | length) \(.body)"')"

assert_eq "github_build_review_payload: マルチバイトのパスをそのまま保つ" \
  'plans/【設計】計画.md' \
  "$(printf '%s' '[{"path":"plans/【設計】計画.md","line":1,"title":"T","body":"B"}]' | github_build_review_payload "$review_body_file" | jq -r '.comments[0].path')"

# gh/glab CLIは人間のアカウントで認証されているため、投稿者名では誰が書いたか判別できない。
# 本文側に署名を入れる（issue-mr-flow の `reply` サブコマンド手順2と同じ理由）。
assert_eq "github_build_review_payload: 本文の先頭にAIの署名を付ける" \
  'Claude Codeより（敵対的レビュー）:' \
  "$(printf '%s' '[{"path":"a.sh","line":1,"title":"タイトル","body":"本文"}]' | github_build_review_payload "$review_body_file" | jq -r '.comments[0].body' | head -1)"

assert_eq "github_build_review_payload: 重大度・確度・カテゴリを署名の次の段落へ付ける" \
  '**[major / 確度: high / shell-pitfall]** タイトル' \
  "$(printf '%s' '[{"path":"a.sh","line":1,"severity":"major","confidence":"high","category":"shell-pitfall","title":"タイトル","body":"本文"}]' | github_build_review_payload "$review_body_file" | jq -r '.comments[0].body' | sed -n '3p')"

assert_eq "format_findings_summary: 0件でも本文は空にしない" \
  'すべての指摘をインラインコメントで示しています。' \
  "$(printf '%s' '[]' | format_findings_summary | tail -1)"

assert_eq "format_findings_summary: 件数を見出しに出す" \
  '### インラインで示せなかった指摘（2件）' \
  "$(printf '%s' '[{"path":"a.sh","title":"T1"},{"path":"b.sh","title":"T2"}]' | format_findings_summary | sed -n '3p')"

# --- GitLab: サマリの投稿先（スレッド or 単発note） ---

assert_eq "gitlab_summary_post_kind: 指摘を含むサマリはスレッドで投稿する" \
  'thread' \
  "$(gitlab_summary_post_kind 1)"

assert_eq "gitlab_summary_post_kind: 複数件でもスレッドで投稿する" \
  'thread' \
  "$(gitlab_summary_post_kind 5)"

assert_eq "gitlab_summary_post_kind: 0件の通知はスレッドにしない（未解決一覧に残るため）" \
  'note' \
  "$(gitlab_summary_post_kind 0)"

# --- GitLab: position付き投稿 ---

gitlab_refs='{"base_sha":"b1","start_sha":"s1","head_sha":"h1"}'

assert_eq "gitlab_build_discussion_body: 新規行への指摘はnew_lineのみ" \
  '{"base_sha":"b1","start_sha":"s1","head_sha":"h1","position_type":"text","old_path":"a.sh","new_path":"a.sh","new_line":10}' \
  "$(gitlab_build_discussion_body '{"path":"a.sh","line":10}' "$gitlab_refs" | jq -c '.position')"

assert_eq "gitlab_build_discussion_body: 削除行への指摘はold_lineのみ" \
  '{"base_sha":"b1","start_sha":"s1","head_sha":"h1","position_type":"text","old_path":"a.sh","new_path":"a.sh","old_line":3}' \
  "$(gitlab_build_discussion_body '{"old_path":"a.sh","old_line":3}' "$gitlab_refs" | jq -c '.position')"

assert_eq "gitlab_build_discussion_body: コンテキスト行への指摘は両方" \
  '10 8' \
  "$(gitlab_build_discussion_body '{"path":"a.sh","line":10,"old_line":8}' "$gitlab_refs" | jq -r '"\(.position.new_line) \(.position.old_line)"')"

assert_eq "gitlab_build_discussion_body: 本文の先頭にAIの署名を付ける" \
  'Claude Codeより（敵対的レビュー）:' \
  "$(gitlab_build_discussion_body '{"path":"a.sh","line":1,"title":"タイトル","body":"本文"}' "$gitlab_refs" | jq -r '.body' | head -1)"

assert_eq "gitlab_build_discussion_body: 本文の形式をGitHub版と揃える" \
  '**[major / 確度: high / shell-pitfall]** タイトル' \
  "$(gitlab_build_discussion_body '{"path":"a.sh","line":1,"severity":"major","confidence":"high","category":"shell-pitfall","title":"タイトル","body":"本文"}' "$gitlab_refs" | jq -r '.body' | sed -n '3p')"

# position から path / line / sha を解決すること（issue #77 で位置出力を追加、issue #43 で
# 断面 sha の解決を追加）。位置が出ないと「どのファイルの何行目への指摘か」がレビュー対応時に
# 分からない。
gitlab_notes_fixture='[
  {"id":"abc","notes":[{"id":11,"system":false,"resolvable":true,"resolved":false,"author":{"username":"u1"},"body":"新規行","position":{"new_path":"a.sh","new_line":10,"old_path":"a.sh","head_sha":"aaaaaaa1111","base_sha":"bbbbbbb2222"}}]},
  {"id":"def","notes":[{"id":12,"system":false,"resolvable":true,"resolved":false,"author":{"username":"u2"},"body":"削除行","position":{"old_path":"b.sh","old_line":3,"new_path":"b.sh","new_line":null,"head_sha":"aaaaaaa1111","base_sha":"bbbbbbb2222"}}]},
  {"id":"ghi","notes":[{"id":13,"system":false,"resolvable":false,"author":{"username":"u3"},"body":"通常コメント"}]},
  {"id":"jkl","notes":[{"id":14,"system":true,"author":{"username":"u4"},"body":"changed the description"}]},
  {"id":"mno","notes":[{"id":15,"system":false,"resolvable":true,"resolved":true,"author":{"username":"u5"},"body":"解決済み"}]}
]'

assert_eq "format_review_comments(GitLab): position付きはpath:lineを出す" \
  '[review unresolved threadId=abc a.sh:10] u1: 新規行' \
  "$(render_comments "$(gitlab_normalize_discussions "$gitlab_notes_fixture")" | sed -n '1p')"

assert_eq "format_review_comments(GitLab): 削除行はold_path:old_lineを出す" \
  '[review unresolved threadId=def b.sh:3] u2: 削除行' \
  "$(render_comments "$(gitlab_normalize_discussions "$gitlab_notes_fixture")" | sed -n '3p')"

# position を持たないスレッド（MR全体へのコメント等）には位置を出さない。issue #43 以前の
# GitHub実装は `(場所不明)` と出していたが、GitLabでは position が無いのが正常なため誤解を招く。
assert_eq "format_review_comments(GitLab): position無しの通常コメントには位置を出さない" \
  '[review unresolved threadId=ghi] u3: 通常コメント' \
  "$(render_comments "$(gitlab_normalize_discussions "$gitlab_notes_fixture")" | sed -n '5p')"

assert_eq "gitlab_normalize_discussions: systemノートと解決済みは除外されたまま" \
  '3' \
  "$(render_comments "$(gitlab_normalize_discussions "$gitlab_notes_fixture")" | grep -c 'threadId=')"

assert_eq "gitlab_normalize_discussions: include_resolved=trueなら解決済みも出る" \
  '4' \
  "$(render_comments "$(gitlab_normalize_discussions "$gitlab_notes_fixture" true)" | grep -c 'threadId=')"

# issue #43: 追加・変更行への指摘は head_sha、削除行への指摘は base_sha を断面にする
# （削除された行は head_sha 側に存在しないため）。
assert_eq "gitlab_normalize_discussions: 追加行への指摘の断面は head_sha" \
  'a.sh|10|aaaaaaa1111' \
  "$(gitlab_normalize_discussions "$gitlab_notes_fixture" | jq -r '.threads[] | select(.threadId=="abc") | [.path,(.line|tostring),.sha] | join("|")')"

assert_eq "gitlab_normalize_discussions: 削除行への指摘の断面は base_sha" \
  'b.sh|3|bbbbbbb2222' \
  "$(gitlab_normalize_discussions "$gitlab_notes_fixture" | jq -r '.threads[] | select(.threadId=="def") | [.path,(.line|tostring),.sha] | join("|")')"

assert_eq "gitlab_normalize_discussions: 通常コメント（comments）は常に空（threadsへ寄せる）" \
  '0' \
  "$(gitlab_normalize_discussions "$gitlab_notes_fixture" true | jq '.comments | length')"

# CLI不在時に提示するMCPツール名（mcp_tool_hint）へ、新しい関数を追加したか
get_provider() { printf 'github\n'; }
assert_eq "mcp_tool_hint: add_mr_inline_comments はレビュー作成ツールを案内する" \
  '1' \
  "$(mcp_tool_hint add_mr_inline_comments | grep -c 'pull_request_review_write')"

# --- issue #42: blobリンク・差分アンカーリンク・パーマリンクの組み立て --------------------

assert_eq "github_get_blob_url: リポジトリURLに/blob/<ref>/<path>を付与" \
  "https://github.com/o/r/blob/aaa111/.claude/scripts/src/vcs/Github.sh" \
  "$(github_get_blob_url "https://github.com/o/r" "aaa111" ".claude/scripts/src/vcs/Github.sh")"

assert_eq "github_get_diff_anchor_url: CompareページURLに#diff-<hash>を付与" \
  "https://github.com/o/r/compare/main...aaa111#diff-645d26f1" \
  "$(github_get_diff_anchor_url "https://github.com/o/r/compare/main...aaa111" "645d26f1")"

assert_eq "github_diff_anchor_algo: GitHubの差分アンカーはパスのsha256" \
  "sha256" "$(github_diff_anchor_algo)"

assert_eq "gitlab_get_blob_url: リポジトリURLに/-/blob/<ref>/<path>を付与" \
  "https://gitlab.example.com/o/r/-/blob/aaa111/src/main.go" \
  "$(gitlab_get_blob_url "https://gitlab.example.com/o/r" "aaa111" "src/main.go")"

assert_eq "gitlab_get_diff_anchor_url: CompareページURLに#<hash>を付与（diff-接頭辞は付かない）" \
  "https://gitlab.example.com/o/r/-/compare/main...aaa111#8ec9a00b" \
  "$(gitlab_get_diff_anchor_url "https://gitlab.example.com/o/r/-/compare/main...aaa111" "8ec9a00b")"

assert_eq "gitlab_diff_anchor_algo: GitLabの差分アンカーはパスのsha1" \
  "sha1" "$(gitlab_diff_anchor_algo)"

assert_eq "gitlab_get_mr_url: リポジトリURLとMR番号からMRページURLを組み立てる" \
  "https://gitlab.example.com/o/r/-/merge_requests/42" \
  "$(gitlab_get_mr_url "https://gitlab.example.com/o/r" "42")"

assert_eq "gitlab_get_note_url: MRページURLとnote idからコメントのパーマリンクを組み立てる" \
  "https://gitlab.example.com/o/r/-/merge_requests/42#note_12345" \
  "$(gitlab_get_note_url "https://gitlab.example.com/o/r/-/merge_requests/42" "12345")"

# --- url_encode_path_to_reply（issue #42） ----------------------------------------------
# 結果は標準出力ではなく REPLY へ返るため、コマンド置換ではなく呼び出し後に $REPLY を読む。

url_encode_path_to_reply ".claude/scripts/src/vcs/Github.sh"
assert_eq "url_encode_path_to_reply: unreserved文字と/はそのまま残す" \
  ".claude/scripts/src/vcs/Github.sh" "$REPLY"

url_encode_path_to_reply "docs/a b.md"
assert_eq "url_encode_path_to_reply: 空白は%20へ変換する" "docs/a%20b.md" "$REPLY"

url_encode_path_to_reply "a#b?c"
assert_eq "url_encode_path_to_reply: URL上で意味を持つ記号を変換する" "a%23b%3Fc" "$REPLY"

url_encode_path_to_reply "plans/【実装】x.md"
assert_eq "url_encode_path_to_reply: 日本語はUTF-8のバイト単位で%XXへ変換する" \
  "plans/%E3%80%90%E5%AE%9F%E8%A3%85%E3%80%91x.md" "$REPLY"

url_encode_path_to_reply ""
assert_eq "url_encode_path_to_reply: 空文字列は空文字列のまま" "" "$REPLY"

# --- hash_paths（issue #42） -------------------------------------------------------------
# 期待値のうちsha256の2件は、GitHubのCompareページが遅延読込する
# `/compare/file-list?range=<from>...<to>` の断片HTMLに出力される `id="diff-<hash>"` と
# 一致することを本リポジトリで実機確認済み（issue #42の受け入れ条件）。

assert_eq "hash_paths: sha256でパス文字列（ファイルの中身ではない）のハッシュを返す" \
  "645d26f1a0efff8ca3cef055f31fd35cb9b6659de3c37add0dd34de217c74631" \
  "$(hash_paths sha256 ".claude/scripts/src/vcs/Gitlab.sh")"

assert_eq "hash_paths: sha1も選べる" \
  "8ec9a00bfd09b3190ac6b22251dbb1aa95a0579d" \
  "$(hash_paths sha1 "README.md")"

assert_eq "hash_paths: 複数パスを渡すと引数と同じ順序で1行ずつ返す" \
  "645d26f1a0efff8ca3cef055f31fd35cb9b6659de3c37add0dd34de217c74631
b78bc8687755aab014029bb3c31f93b23b4c9dd0124f9a4b7ad9fd5d08501650" \
  "$(hash_paths sha256 ".claude/scripts/src/vcs/Gitlab.sh" ".claude/scripts/src/vcs/Github.sh")"

assert_eq "hash_paths: 空白・日本語を含むパスもそのままハッシュする" \
  "46211776bb9388ae1f90d789ff6bb48b4cfa876d77b886425c0f840d20c79dd0
4bc97450a8e98a31d5f7e6d1212a21eac9a0f6a8e25631ff77a7ecde56f3686c" \
  "$(hash_paths sha256 "a b/c.md" "plans/【実装】x.md")"

assert_eq "hash_paths: 引数が無ければ何も出力しない" "" "$(hash_paths sha256)"

# 未知のアルゴリズムは失敗させる（`if` で受けるのは set -e 下でのサブシェル終了を避けるため。
# .claude/rules/shell-script-style.md「テスト」節）
if hash_paths md5 "README.md" >/dev/null 2>&1; then
  unknown_algo_status=0
else
  unknown_algo_status=1
fi
assert_eq "hash_paths: 未知のアルゴリズム名は終了コード1で失敗する" "1" "$unknown_algo_status"

# --- porcelain_z_to_paths（issue #115） ---------------------------------------------------
# `git status --porcelain -z` の出力を模したフィクスチャを標準入力へ流し、「1行＝1つの実在する
# パス」へ変換されることを確認する。gitは起動しない（純粋関数のため）。
# フィクスチャはNULを含むため `$'...'`（bashの文字列はNULを保持できない）ではなく `printf` で
# 都度書き出す。改名・コピーのエントリは `-z` 形式では `XY <新パス>\0<旧パス>\0` の順になる
# （実機確認: git 2.x。行単位形式の `<旧パス> -> <新パス>` とは順序が逆）。

# ステージ済みの改名（`R `）・改名＋未ステージ変更（`RM`）・通常の変更／追加／削除／未追跡を混ぜる
porcelain_z_fixture() {
  printf 'RM plans/ascii-new.md\0plans/ascii-old.md\0'
  printf 'R  plans/【調査】新.md\0plans/【調査】旧.md\0'
  printf ' M plans/keep.md\0'
  printf 'A  reports/2026-08-20_x_調査結果.md\0'
  printf ' D worklog/2026-08-20_x_y_push1.md\0'
  printf '?? plans/【実装】未追跡.md\0'
}

assert_eq "porcelain_z_to_paths: 改名は新パスのみを1行として返し、旧パスは返さない" \
  "plans/ascii-new.md
plans/【調査】新.md
plans/keep.md
reports/2026-08-20_x_調査結果.md
worklog/2026-08-20_x_y_push1.md
plans/【実装】未追跡.md" \
  "$(porcelain_z_fixture | porcelain_z_to_paths)"

assert_eq "porcelain_z_to_paths: 出力に \" -> \" を含む行が現れない" \
  "0" \
  "$(porcelain_z_fixture | porcelain_z_to_paths | grep -c -F -- ' -> ' || true)"

assert_eq "porcelain_z_to_paths: 非ASCIIのパスをそのまま返す（8進エスケープしない）" \
  "1" \
  "$(porcelain_z_fixture | porcelain_z_to_paths | grep -c -F -- 'plans/【調査】新.md')"

assert_eq "porcelain_z_to_paths: 未ステージ側の桁に改名（\` R\`）が来ても新パスを返す" \
  "plans/new.md" \
  "$(printf ' R plans/new.md\0plans/old.md\0' | porcelain_z_to_paths)"

assert_eq "porcelain_z_to_paths: コピー（C）も改名と同様に旧パスを読み捨てる" \
  "plans/copy.md
plans/next.md" \
  "$(printf 'C  plans/copy.md\0plans/src.md\0 M plans/next.md\0' | porcelain_z_to_paths)"

# パス自体が ` -> ` を含む場合、行単位形式では区切りを一意に決められないが、-z形式なら壊れない
assert_eq "porcelain_z_to_paths: パスに\" -> \"が含まれていても新パスを正しく返す" \
  "plans/a -> b.md" \
  "$(printf 'R  plans/a -> b.md\0plans/old -> name.md\0' | porcelain_z_to_paths)"

assert_eq "porcelain_z_to_paths: 未追跡（??）は改名扱いせず次のエントリを読み捨てない" \
  "plans/x.md
plans/y.md" \
  "$(printf '?? plans/x.md\0?? plans/y.md\0' | porcelain_z_to_paths)"

assert_eq "porcelain_z_to_paths: 入力が空なら何も出力しない" \
  "" \
  "$(printf '' | porcelain_z_to_paths)"

# 旧パスのフィールドが欠けた壊れた入力でも、無限ループせず読めたところまでを返す
assert_eq "porcelain_z_to_paths: 改名エントリの旧パスが欠けていても新パスまでは返す" \
  "plans/new.md" \
  "$(printf 'R  plans/new.md\0' | porcelain_z_to_paths)"


# --- github_normalize_review_threads（issue #43） ------------------------------------------
# GraphQLの返却JSONを正規化JSONへ変換する純粋関数。issue #43 以前、GitHub側の整形には単体
# テストが1件も無く（`gh` 依存だったため）、issue #94 のCR混入をテストで検知できなかった。
github_threads_fixture='{"data":{"repository":{"pullRequest":{
  "reviewThreads":{"nodes":[
    {"id":"PRRT_a","isResolved":false,"isOutdated":false,"path":"a.sh","line":12,"originalLine":9,
     "comments":{"nodes":[
       {"author":{"login":"alice"},"body":"ここ直して","url":"https://x/#discussion_r1",
        "commit":{"oid":"1111111aaaa"},"originalCommit":{"oid":"2222222bbbb"}},
       {"author":{"login":"bob"},"body":"了解","url":"https://x/#discussion_r2",
        "commit":{"oid":"1111111aaaa"},"originalCommit":{"oid":"2222222bbbb"}}]}},
    {"id":"PRRT_b","isResolved":true,"isOutdated":true,"path":"a.sh","line":null,"originalLine":3,
     "comments":{"nodes":[
       {"author":{"login":"alice"},"body":"outdatedな指摘","url":"https://x/#discussion_r3",
        "commit":null,"originalCommit":{"oid":"2222222bbbb"}}]}},
    {"id":"PRRT_c","isResolved":false,"isOutdated":false,"path":null,"line":null,"originalLine":null,
     "comments":{"nodes":[
       {"author":null,"body":"作者が削除されたコメント","url":null,
        "commit":null,"originalCommit":null}]}}]},
  "comments":{"nodes":[{"author":{"login":"dave"},"body":"通常コメント","url":"https://x/#issuecomment-1"}]}
}}}}'

assert_eq "github_normalize_review_threads: 既定は未解決スレッドのみ（通常コメントは常に含む）" \
  'PRRT_a PRRT_c' \
  "$(github_normalize_review_threads "$github_threads_fixture" | jq -r '[.threads[].threadId] | join(" ")')"

assert_eq "github_normalize_review_threads: include_resolved=trueなら解決済みも含む" \
  'PRRT_a PRRT_b PRRT_c' \
  "$(github_normalize_review_threads "$github_threads_fixture" true | jq -r '[.threads[].threadId] | join(" ")')"

# `line` が非nullならそれを使い、断面は `commit.oid`
assert_eq "github_normalize_review_threads: lineがあればlineとcommit.oidを採る" \
  '12|1111111aaaa' \
  "$(github_normalize_review_threads "$github_threads_fixture" | jq -r '.threads[] | select(.threadId=="PRRT_a") | [(.line|tostring),.sha] | join("|")')"

# outdatedスレッドは `line` が null で `originalLine` にしか値が無い（issue #43 の「現状」6）。
# 断面も `originalCommit.oid` へ切り替える。
assert_eq "github_normalize_review_threads: lineがnullならoriginalLineとoriginalCommit.oidへ落ちる" \
  '3|2222222bbbb|true' \
  "$(github_normalize_review_threads "$github_threads_fixture" true | jq -r '.threads[] | select(.threadId=="PRRT_b") | [(.line|tostring),.sha,(.isOutdated|tostring)] | join("|")')"

assert_eq "github_normalize_review_threads: 位置も断面も無ければnullのまま" \
  'null|null|null' \
  "$(github_normalize_review_threads "$github_threads_fixture" | jq -r '.threads[] | select(.threadId=="PRRT_c") | [(.path|tostring),(.line|tostring),(.sha|tostring)] | join("|")')"

# 退会・削除されたユーザーでは GraphQL の `author` が null になる
assert_eq "github_normalize_review_threads: authorがnullでも落とさず(unknown)にする" \
  '(unknown)' \
  "$(github_normalize_review_threads "$github_threads_fixture" | jq -r '.threads[] | select(.threadId=="PRRT_c") | .comments[0].author')"

assert_eq "github_normalize_review_threads: reviewThreadsが空でも壊れない" \
  '0|0' \
  "$(github_normalize_review_threads '{"data":{"repository":{"pullRequest":{}}}}' | jq -r '[(.threads|length|tostring),(.comments|length|tostring)] | join("|")')"

github_normalized_output="$(github_normalize_review_threads "$github_threads_fixture" true)"
assert_eq "github_normalize_review_threads: 正規化JSONにCRが混入しない" \
  "$(printf '%s' "$github_normalized_output" | wc -c)" \
  "$(printf '%s' "$github_normalized_output" | tr -d '\r' | wc -c)"

# --- format_review_comments（issue #43） ---------------------------------------------------
# ソーススライスは**スレッドにつき1回**だけ出す。issue #43 以前のGitHub実装は
# スレッド内のコメントごとに diffHunk を出しており、返信が付いたスレッドで重複していた。
github_slices_fixture='{"PRRT_a":{"ref":"1111111","note":"","text":"   11 | before\n>>> 12 | target\n   13 | after"}}'

assert_eq "format_review_comments: ソーススライスはスレッドにつき1回だけ出る" \
  '1' \
  "$(render_comments "$(github_normalize_review_threads "$github_threads_fixture")" "$github_slices_fixture" \
     | grep -c -- '--- source ')"

assert_eq "format_review_comments: スレッド内の各コメントは行頭書式で出る（2件）" \
  '2' \
  "$(render_comments "$(github_normalize_review_threads "$github_threads_fixture")" "$github_slices_fixture" \
     | grep -c '^\[review unresolved threadId=PRRT_a ')"

assert_eq "format_review_comments: スライスは全コメントの後ろに1回だけ置かれる" \
  "[review unresolved threadId=PRRT_a a.sh:12 url=https://x/#discussion_r1] alice: ここ直して

[review unresolved threadId=PRRT_a a.sh:12 url=https://x/#discussion_r2] bob: 了解

--- source a.sh @ 1111111 ---
   11 | before
>>> 12 | target
   13 | after" \
  "$(render_comments "$(github_normalize_review_threads "$github_threads_fixture")" "$github_slices_fixture" \
     | sed -n '1,9p')"

assert_eq "format_review_comments: スライスが無いスレッドはコメント行だけを出す" \
  '[review unresolved threadId=PRRT_c] (unknown): 作者が削除されたコメント' \
  "$(render_comments "$(github_normalize_review_threads "$github_threads_fixture")" "$github_slices_fixture" \
     | grep 'threadId=PRRT_c')"

assert_eq "format_review_comments: 通常コメントは [comment ...] で末尾に出る" \
  '[comment url=https://x/#issuecomment-1] dave: 通常コメント' \
  "$(render_comments "$(github_normalize_review_threads "$github_threads_fixture")" "$github_slices_fixture" | tail -1)"

assert_eq "format_review_comments: outdatedスレッドの見出しへ (outdated) が付く" \
  '--- source a.sh @ 2222222 (outdated) (断面 2222222 を取得できず現HEADを表示) ---' \
  "$(render_comments "$(github_normalize_review_threads "$github_threads_fixture" true)" \
     '{"PRRT_b":{"ref":"2222222","note":"(断面 2222222 を取得できず現HEADを表示)","text":">>> 3 | x"}}' \
     | grep -- '--- source ')"

assert_eq "format_review_comments: 出力にdiffHunkの見出しが残っていない" \
  '0' \
  "$(render_comments "$(github_normalize_review_threads "$github_threads_fixture" true)" "$github_slices_fixture" \
     | grep -c -- '--- diff ---' || true)"

# --- truncate_bytes_to_reply / slice_source_lines（issue #43） ------------------------------
# 上限をバイトで見るのは、行数だけでは制御にならないため（issue #43 の実測: 同一ファイルの
# ±10行が 684B〜8,971B と13.1倍ばらついた）。
truncate_bytes_to_reply 'abcdef' 10
assert_eq "truncate_bytes_to_reply: 上限以下ならそのまま返す" 'abcdef' "$REPLY"

truncate_bytes_to_reply 'abcdef' 3
assert_eq "truncate_bytes_to_reply: 上限を超えたら切り詰める" 'abc' "$REPLY"

# 3バイト/文字のUTF-8を8バイトで切ると2文字目の途中に当たる。文字境界まで戻すこと
# （戻さないと壊れたバイト列が出力へ混ざる）。
truncate_bytes_to_reply 'あいう' 8
assert_eq "truncate_bytes_to_reply: UTF-8の文字境界まで戻す（壊れた文字を残さない）" 'あい' "$REPLY"
assert_eq "truncate_bytes_to_reply: 戻した結果は上限以下のバイト数になる" '6' \
  "$(printf '%s' "$REPLY" | wc -c)"

truncate_bytes_to_reply 'あいう' 2
assert_eq "truncate_bytes_to_reply: 1文字も入らなければ空になる" '' "$REPLY"

slice_source_lines 5 2 100000 <<'SLICE_SRC'
l1
l2
l3
l4
l5
l6
l7
l8
SLICE_SRC
assert_eq "slice_source_lines: 指摘行の前後を絶対行番号付きで切り出し >>> で示す" \
  "    3 | l3
    4 | l4
>>> 5 | l5
    6 | l6
    7 | l7" "$REPLY"
assert_eq "slice_source_lines: 上限内なら切り詰めフラグは立たない" '0' "$REVIEW_SLICE_TRUNCATED"

slice_source_lines 1 3 100000 <<'SLICE_SRC'
a
b
c
SLICE_SRC
assert_eq "slice_source_lines: ファイル先頭では前が足りなくても破綻しない" \
  ">>> 1 | a
    2 | b
    3 | c" "$REPLY"

# 行番号の桁が変わる境界（9→10）で桁揃えが崩れないこと
slice_source_lines 10 2 100000 <<'SLICE_SRC'
line1
line2
line3
line4
line5
line6
line7
line8
line9
line10
line11
SLICE_SRC
assert_eq "slice_source_lines: 行番号は最大行の桁数で右揃えされる" \
  "     8 | line8
     9 | line9
>>> 10 | line10
    11 | line11" "$REPLY"

# 上限を超えたら指摘行から遠い側から落とす（指摘行は必ず残る）
slice_source_lines 5 4 60 <<'SLICE_SRC'
aaaaaaaaaa
bbbbbbbbbb
cccccccccc
dddddddddd
eeeeeeeeee
ffffffffff
gggggggggg
hhhhhhhhhh
iiiiiiiiii
SLICE_SRC
assert_eq "slice_source_lines: バイト上限を超えたら指摘行を中心に削る" \
  "    4 | dddddddddd
>>> 5 | eeeeeeeeee
    6 | ffffffffff" "$REPLY"
assert_eq "slice_source_lines: 切り詰めたらフラグが立つ" '1' "$REVIEW_SLICE_TRUNCATED"

# 1行だけになってもなお超える場合は、その行自体をUTF-8境界で切り詰める
slice_source_lines 1 0 20 <<'SLICE_SRC'
あいうえおかきくけこ
SLICE_SRC
assert_eq "slice_source_lines: 1行が上限超なら行自体を切り詰める（バイト数は上限以下）" '1' \
  "$([ "$(printf '%s' "$REPLY" | wc -c)" -le 20 ] && echo 1 || echo 0)"
assert_eq "slice_source_lines: 行を切り詰めてもUTF-8として壊れない" '>>> 1 | あいう' "$REPLY"

# 断面が現HEADへ縮退すると、行数が減っていて指摘行が末尾を超えることがある
slice_source_lines 99 1 100000 <<'SLICE_SRC'
a
b
c
SLICE_SRC
assert_eq "slice_source_lines: 指摘行がファイル範囲外なら範囲内へ丸める" \
  "    2 | b
>>> 3 | c" "$REPLY"

# 空入力は終了コード1（呼び出し側はソース無しへ縮退する）
if slice_source_lines 1 2 100 </dev/null; then
  slice_empty_status=0
else
  slice_empty_status=1
fi
assert_eq "slice_source_lines: 入力が空なら終了コード1" '1' "$slice_empty_status"


# --- content_type_from_path_to_reply / upload_attachment（issue #111: 統括レポートの添付） ---
#
# 添付は flow-id 5-4 の**任意層**であり、失敗が正常系のひとつである。ここでテストするのは
# 「ネットワークへ出る前に落ちること」と「落ち方が呼び出し側にとって扱えること」である。

content_type_from_path_to_reply 'reports/20260821_x_統括.html'
assert_eq "content_type: .html は text/html" 'text/html' "$REPLY"

content_type_from_path_to_reply 'a.htm'
assert_eq "content_type: .htm も text/html" 'text/html' "$REPLY"

content_type_from_path_to_reply 'reports/20260821_x_統括.md'
assert_eq "content_type: .md は text/markdown" 'text/markdown' "$REPLY"

# 大文字の拡張子（Windows由来のファイル名で普通に起きる）
content_type_from_path_to_reply 'REPORT.HTML'
assert_eq "content_type: 拡張子は大文字でも判定する" 'text/html' "$REPLY"

# 拡張子なし。`${base##*.}` はドットが無いとファイル名全体を返すため、
# 判定を挟まないと `README` という拡張子として扱われてしまう
content_type_from_path_to_reply 'README'
assert_eq "content_type: 拡張子が無ければ octet-stream" 'application/octet-stream' "$REPLY"

# ディレクトリ名にだけドットがあるケース（拡張子と誤認しないこと）
content_type_from_path_to_reply '.claude/docs/README'
assert_eq "content_type: ディレクトリ側のドットを拡張子と誤認しない" 'application/octet-stream' "$REPLY"

# 日付を含むレポート名のようにドットが複数あるケースは、最後のドット以降を採る
content_type_from_path_to_reply 'reports/2026.08.21_x.md'
assert_eq "content_type: ドットが複数あれば最後のドット以降を採る" 'text/markdown' "$REPLY"

content_type_from_path_to_reply 'x.unknown'
assert_eq "content_type: 未知の拡張子は octet-stream（ここで失敗させない）" 'application/octet-stream' "$REPLY"

# 引数の検証は `require_vcs_cli`（＝CLIの有無）より**前**に行う。CLIがある環境でも無い環境でも
# 同じ理由で落ちてほしいため（CLIの有無で失敗理由が変わると、呼び出し側が原因を誤読する）
if upload_attachment >/dev/null 2>&1; then
  upload_noarg_status=0
else
  upload_noarg_status=1
fi
assert_eq "upload_attachment: 引数なしは非0で終える" '1' "$upload_noarg_status"

upload_noarg_stderr="$(upload_attachment 2>&1 >/dev/null || true)"
assert_contains "upload_attachment: 引数なしの理由がstderrに出る" \
  "$upload_noarg_stderr" "ファイルのパスを指定してください"

if upload_attachment '/nonexistent/path/to/report.html' >/dev/null 2>&1; then
  upload_missing_status=0
else
  upload_missing_status=1
fi
assert_eq "upload_attachment: 存在しないファイルは非0で終える" '1' "$upload_missing_status"

upload_missing_stderr="$(upload_attachment '/nonexistent/path/to/report.html' 2>&1 >/dev/null || true)"
assert_contains "upload_attachment: 存在しないファイルの理由がstderrに出る" \
  "$upload_missing_stderr" "ファイルが見つかりません"

# --- 差分アンカーの土台URL（issue #127） ---------------------------------------------------
# 同じハッシュでも土台にするページによってアンカーが効くかが変わるため、土台の決定を
# プロバイダへ委ねている。GitHubは従来どおりCompareページ、GitLabはMRの差分ページ。
anchor_compare_url='https://github.com/o/r/compare/aaa...bbb'
anchor_mr_url='http://gl.example/o/r/-/merge_requests/7'

assert_eq "github_get_diff_anchor_base_url: compare_urlをそのまま返す（従来の挙動を変えない）" \
  "$anchor_compare_url" \
  "$(github_get_diff_anchor_base_url "$anchor_compare_url" "$anchor_mr_url" 7 'aaa111')"

assert_eq "github_get_diff_anchor_base_url: since_shaが空でもcompare_urlをそのまま返す" \
  "$anchor_compare_url" \
  "$(github_get_diff_anchor_base_url "$anchor_compare_url" "$anchor_mr_url" 7 '')"

# `glab` をシェル関数で差し替え、MRバージョン一覧を固定値にする（外部プロセス・ネットワークを
# 使わない）。同名のシェル関数は実行ファイルより優先されるため、実装側に手を入れずに検証できる。
glab() {
  case "$*" in
    'api projects/:id/merge_requests/7/versions')
      printf '%s' '[{"id":11,"head_commit_sha":"aaa111"},{"id":10,"head_commit_sha":"bbb222"}]'
      ;;
    'api projects/:id/merge_requests/7/discussions')
      printf '%s' "$gitlab_discussions_fixture"
      ;;
    *) return 1 ;;
  esac
}

assert_eq "gitlab_get_diff_anchor_base_url: mr_urlが空ならcompare_urlへ縮退する（MCP経路）" \
  "$anchor_compare_url" \
  "$(gitlab_get_diff_anchor_base_url "$anchor_compare_url" '' 7 'aaa111')"

assert_eq "gitlab_get_diff_anchor_base_url: since_shaが空ならMR全体の差分ページ（初回push）" \
  "${anchor_mr_url}/diffs" \
  "$(gitlab_get_diff_anchor_base_url "$anchor_compare_url" "$anchor_mr_url" 7 '')"

assert_eq "gitlab_get_diff_anchor_base_url: since_shaがバージョンheadならstart_shaで絞り込む" \
  "${anchor_mr_url}/diffs?start_sha=aaa111" \
  "$(gitlab_get_diff_anchor_base_url "$anchor_compare_url" "$anchor_mr_url" 7 'aaa111')"

# バージョンheadでないSHAを渡すとGitLabはHTTP 200のまま0ファイルを返す（無言で空の差分ページに
# なる）ため、付けずにMR全体の差分ページへ縮退する
assert_eq "gitlab_get_diff_anchor_base_url: since_shaがバージョンheadでなければ縮退する" \
  "${anchor_mr_url}/diffs" \
  "$(gitlab_get_diff_anchor_base_url "$anchor_compare_url" "$anchor_mr_url" 7 'zzz999')"

assert_eq "gitlab_get_diff_anchor_base_url: mr_numberが空なら検証できないので縮退する" \
  "${anchor_mr_url}/diffs" \
  "$(gitlab_get_diff_anchor_base_url "$anchor_compare_url" "$anchor_mr_url" '' 'aaa111')"

assert_eq "gitlab_mr_has_version_head: バージョンheadなら成功する" \
  "0" \
  "$(if gitlab_mr_has_version_head 7 'bbb222'; then echo 0; else echo 1; fi)"

assert_eq "gitlab_mr_has_version_head: APIが失敗したら偽を返す（存在しないMR番号）" \
  "1" \
  "$(if gitlab_mr_has_version_head 999 'aaa111'; then echo 0; else echo 1; fi)"

# --- MR/noteのURL組み立て（issue #127でディスパッチャを追加） -------------------------------
assert_eq "github_get_mr_url: PRのページURLを組み立てる" \
  "https://github.com/o/r/pull/7" \
  "$(github_get_mr_url 'https://github.com/o/r' 7)"

# 形式はGitHubのAPIが実際に返す値と一致する（本リポジトリのPR #128 の実コメントで確認済み）
assert_eq "github_get_note_url: レビューコメントのパーマリンクを組み立てる" \
  "https://github.com/o/r/pull/7#discussion_r3821657827" \
  "$(github_get_note_url 'https://github.com/o/r/pull/7' 3821657827)"

# --- 呼び出し経路のテスト（issue #127） ----------------------------------------------------
# 静的検出（後述）は「定義があるか」しか見ないため、引数の受け渡しが壊れている形は拾えない。
# `gitlab_get_mr_unresolved_comments` が実際にMRのURLを組み立ててコメントへ埋め込むところまでを、
# `glab` と `get_repo_url` を差し替えて通す。
# `get_repo_url` も差し替えるのは、この関数が `git remote get-url origin` を起動するため
# （差し替えないと origin の無いチェックアウトで落ち、かつ本リポジトリのoriginはGitHubなので
# 実在しないGitLab形式のURLで通ってしまい、検証として意味を成さない）。
# **`get_repo_url` の差し替えはサブシェルへ閉じ込める。** bashの関数定義はスタックしないため、
# ここで再定義してから `unset -f` すると、スタブではなく `Provider.sh` の**実定義そのもの**が
# 消える（以降のケースが `command not found` で落ち、原因が「前のテストが消したこと」だと
# 気づきにくい失敗になる）。`glab` は元々関数ではないのでこの問題は無いが、揃えて閉じ込める。
# issue #43 で `gitlab_get_mr_unresolved_comments` は `gitlab_get_mr_review_threads`（正規化JSONを
# 返す）＋ `format_review_comments` の2段へ分かれた。**このケースが見ているのは整形結果ではなく
# 「MRのURLを組み立ててnoteのパーマリンクへ届くか」という経路**なので、上の
# `gitlab_normalize_discussions` を直接呼ぶケース群（mr_urlを引数で渡す）では代替できない。
assert_eq "gitlab_get_mr_review_threads: noteのパーマリンクが完全な形で出力に入る" \
  "[review unresolved threadId=d1 url=http://gl.example/o/r/-/merge_requests/7#note_1] reviewer: ここは修正してください

[review unresolved threadId=d4 url=http://gl.example/o/r/-/merge_requests/7#note_4] root: 通常コメント" \
  "$(
    get_repo_url() { printf 'http://gl.example/o/r\n'; }
    render_comments "$(gitlab_get_mr_review_threads 7)"
  )"

assert_eq "テストの後片付け: get_repo_url の実定義が残っている（スタブで消していない）" \
  "get_repo_url" \
  "$(declare -F get_repo_url >/dev/null && echo get_repo_url)"

unset -f glab

# --- 未定義の github_* / gitlab_* 呼び出しの静的検出（issue #127） --------------------------
# issue #42（呼び出しの追加）と issue #44（定義の削除）が並行ブランチで行われ、gitがコンフリクト
# と見なさなかったために `gitlab_get_repo_url` が未定義のまま呼ばれ続けていた。同じ形の混入を
# 機械的に検出する。
#
# 注意: 修正後は「未定義0件」が恒久的な期待値になるため、抽出パターンが実データに合わなくなっても
# 結果は同じ「0件」になる（常に成功する検証になってしまう）。参照件数・定義件数も併せて表明し、
# さらに下で「意図的に壊した木では実際に検出できる」ことを確かめて空振りを潰す。
vcs_identifiers() {
  # 行頭・行末どちらのコメントも落としてから識別子を拾う（`foo  # gitlab_bar` を参照と誤認しない）
  sed -E 's/#.*$//' "$1/Provider.sh" "$1/Github.sh" "$1/Gitlab.sh"
}

vcs_defined_names() {
  vcs_identifiers "$1" | grep -oE '^(github|gitlab)_[a-z0-9_]+\(\)' | sed 's/()$//' | sort -u
}

vcs_referenced_names() {
  # `github__list_pull_requests` のようなMCPツール名（アンダースコア2つ）は関数名ではないので除く
  # （`mcp_tool_hint` が文字列として持っている）。これを除かないと未定義の関数として検出される。
  vcs_identifiers "$1" \
    | grep -oE '(github|gitlab)_[a-z0-9_]+' \
    | grep -vE '^(github|gitlab)__' \
    | sort -u
}

vcs_undefined_names() {
  comm -23 <(vcs_referenced_names "$1") <(vcs_defined_names "$1")
}

vcs_dir="$repo_root/.claude/scripts/src/vcs"

# 抽出そのものが空振りしていないことを先に確かめる（0件なら検出は常に成功してしまう）
assert_eq "静的検出: 定義を1件以上抽出できている" \
  "yes" \
  "$([ "$(vcs_defined_names "$vcs_dir" | grep -c .)" -gt 0 ] && echo yes || echo no)"

assert_eq "静的検出: 参照を1件以上抽出できている" \
  "yes" \
  "$([ "$(vcs_referenced_names "$vcs_dir" | grep -c .)" -gt 0 ] && echo yes || echo no)"

assert_eq "静的検出: 定義の無い github_* / gitlab_* の呼び出しが存在しない" \
  "" \
  "$(vcs_undefined_names "$vcs_dir")"

# 空振り防止: 意図的に未定義呼び出しを1件戻した木では、実際にその1件だけを検出できること
vcs_broken_dir="$(mktemp -d)"
cp "$vcs_dir/Provider.sh" "$vcs_dir/Github.sh" "$vcs_dir/Gitlab.sh" "$vcs_broken_dir/"
sed -i '0,\|get_repo_url 2>/dev/null|s||gitlab_get_repo_url 2>/dev/null|' "$vcs_broken_dir/Gitlab.sh"

assert_eq "静的検出: 未定義呼び出しを1件戻した木では、その1件を検出できる" \
  "gitlab_get_repo_url" \
  "$(vcs_undefined_names "$vcs_broken_dir")"

rm -rf "$vcs_broken_dir"


# `github_*` / `gitlab_*` の接頭辞を持たない**共有関数**（`Provider.sh` 側に定義があり、
# provider実装から呼ばれるもの）は、上の検出の対象外である。しかし issue #127 の不具合2は
# まさにこの形（`Gitlab.sh` が `Provider.sh` の関数を呼ぶ）へ**修正した**ため、同型の再発
# ——`Provider.sh` 側で改名・削除され、`2>/dev/null` に `command not found` が吸われて
# 無言で縮退する——を落とせない。呼び出し側の握りつぶしは意図的に残しているので、ここで表明する。
#
# 一覧を明示にしているのは、jqのフィールド名（`new_path` / `head_sha` 等）とシェル関数呼び出しを
# 静的に区別できないため（機械的に拾うと十数件の偽陽性が混ざる）。**provider実装から新しく
# `Provider.sh` の関数を呼ぶときは、この一覧へ追加する。**
vcs_shared_functions=(
  to_slug
  get_repo_url
  add_empty_commit_for_draft_mr
  merge_issue_search_results
  format_findings_summary
)

vcs_provider_impl_text="$(sed -E 's/#.*$//' \
  "$repo_root/.claude/scripts/src/vcs/Github.sh" "$repo_root/.claude/scripts/src/vcs/Gitlab.sh")"

for shared_fn in "${vcs_shared_functions[@]}"; do
  # 一覧が実態から乖離していないこと（呼ばれなくなった関数が残り続けると表明が形骸化する）
  assert_eq "共有関数の一覧: $shared_fn は実際にprovider実装から呼ばれている" \
    "yes" \
    "$(case "$vcs_provider_impl_text" in *"$shared_fn"*) echo yes ;; *) echo no ;; esac)"
  # 定義が消えていないこと（issue #127 の不具合2と同型の再発を落とす）
  assert_eq "共有関数の定義: $shared_fn が定義されている" \
    "$shared_fn" \
    "$(declare -F "$shared_fn" >/dev/null && echo "$shared_fn")"
done

# `git` をシェル関数で差し替え、add_empty_commit_for_draft_mr が git へ渡す引数を検証する
# （issue #170。upstream未設定のブランチでは引数なしの `git push` が終了コード128で失敗する
# 実不具合があったため、`-u origin HEAD` の明示を表明する）。関数内の出力は >/dev/null で
# 捨てられるため、スタブは引数をグローバル変数へ蓄積する（コマンド置換では受けられない）。
empty_commit_git_calls=""
git() {
  empty_commit_git_calls="${empty_commit_git_calls}${empty_commit_git_calls:+ / }$*"
  return 0
}
# スタブが効いていることを、副作用のある関数を呼ぶ「前」に表明する
assert_eq "add_empty_commit_for_draft_mr: gitスタブが有効（実gitを呼ばない）" \
  "git" \
  "$(declare -F git >/dev/null && echo git)"
# 万一シャドウイングが外れても実リポジトリ・実リモートへ届かないよう、存在しないGIT_DIRを
# 指して呼ぶ（実gitなら "not a git repository" で必ず即失敗し、無言の空コミット・pushには
# 決してならない。スタブが効いていれば環境変数は参照されない）
GIT_DIR="/nonexistent-isolated-repo/.git" add_empty_commit_for_draft_mr
unset -f git

# commit→push の順序・回数・引数を完全一致で表明する（部分一致だと余計な呼び出しを見逃す）
assert_eq "add_empty_commit_for_draft_mr: commit --allow-empty → push -u origin HEAD の順で2回だけ呼ぶ" \
  "commit --allow-empty -m chore: Draft PR作成のための空コミット（baseとの差分が無いため） / push -u origin HEAD" \
  "$empty_commit_git_calls"
# 後片付けの表明（スタブが残ると以降のテスト・呼び出し元のgit操作が握り潰される）
assert_eq "add_empty_commit_for_draft_mr: gitスタブが解除されている" \
  "" \
  "$(declare -F git || true)"

echo "passed=$passed failures=$failures"
[ "$failures" -eq 0 ]
