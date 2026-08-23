#!/usr/bin/env bash
# .claude/scripts/src/check-doc-references.sh の単体テスト（issue #171）。
# 前半: 外部コマンド呼び出しを伴わない純粋関数（is_excluded_target_path /
# is_placeholder_candidate / is_fence_delimiter_line / compute_fenced_linenos_to_reply /
# split_concatenated_candidates_to_reply / extract_ddr_candidates_to_reply）を対象とする。
# 後半: mainを実際のgit操作込みで通す統合テスト（使い捨てのtmpリポジトリを使い、
# 実リポジトリを汚さない。.claude/rules/shell-script-style.md「テスト」「純粋関数の単体
# テストは、その関数へ至る呼び出し経路を何も保証しない」を踏まえ、経路を通す検証も含める）。
# 規約: passed=N failures=N を標準出力へ出し、失敗があれば終了コード1。
# 実行: bash .claude/scripts/test/test_check_doc_references.sh
set -euo pipefail

script_dir="${BASH_SOURCE[0]%/*}"
[[ "$script_dir" == "${BASH_SOURCE[0]}" ]] && script_dir="."
repo_root="$(cd "$script_dir/../../.." && pwd)"
target_script="$repo_root/.claude/scripts/src/check-doc-references.sh"

# shellcheck source=../../../.claude/scripts/src/check-doc-references.sh
source "$target_script"

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

REPLY_FENCE_MARKER=""; REPLY_FENCE_LEN=""
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

is_fence_delimiter_line '````bash'
assert_eq "is_fence_delimiter_line: 4連以上のバッククォートも認識しマーカー長を返す" "4" "$REPLY_FENCE_LEN"
assert_eq "is_fence_delimiter_line: マーカー種別はバッククォート" '`' "$REPLY_FENCE_MARKER"

# --- compute_fenced_linenos_to_reply ------------------------------------------

REPLY_FENCED_LINENOS=()
compute_fenced_linenos_to_reply $'本文1\n```\n参照: .claude/docs/ddr/i9999-99-架空.md\n```\n本文2'
assert_eq "compute_fenced: 閉じたフェンス内の行番号(2,3,4)を返す" "1" "${REPLY_FENCED_LINENOS[2]:-0}"
assert_eq "compute_fenced: フェンス内3行目も含む" "1" "${REPLY_FENCED_LINENOS[3]:-0}"
assert_eq "compute_fenced: フェンス外1行目は含まない" "0" "${REPLY_FENCED_LINENOS[1]:-0}"
assert_eq "compute_fenced: フェンス外5行目は含まない" "0" "${REPLY_FENCED_LINENOS[5]:-0}"

REPLY_FENCED_LINENOS=()
compute_fenced_linenos_to_reply $'本文1\n```\n参照: .claude/docs/ddr/i9999-99-架空.md\n本文2'
assert_eq "compute_fenced: フェンスが未閉鎖（奇数回）なら1件も除外しない（安全側）" \
  "0" "${#REPLY_FENCED_LINENOS[@]}"

# フェンス内に別種・別長のフェンス風の行が現れても、開始フェンスと同種・同じ長さ以上の
# 閉じ記号が来るまでは閉じたとみなさない（issue #171 敵対的レビューで発見した false negative
# の再現ケース: ```text / ~~~ / ``` / 参照 / ~~~ という並びで、旧実装は偶数回トグルにより
# 本文行を無言でフェンス内と誤認していた）
REPLY_FENCED_LINENOS=()
compute_fenced_linenos_to_reply $'```text\n~~~\n```\n参照切れ: .claude/docs/ddr/i9999-98-架空2.md\n~~~'
assert_eq "compute_fenced: 種別違いのフェンス風行に惑わされず4行目(参照)を除外しない" \
  "0" "${REPLY_FENCED_LINENOS[4]:-0}"

# --- split_concatenated_candidates_to_reply -----------------------------------

REPLY_SPLIT_CANDIDATES=()
split_concatenated_candidates_to_reply ".claude/docs/ddr/i0001-01-a.md"
assert_eq "split: 単一パスは1件のまま" "1" "${#REPLY_SPLIT_CANDIDATES[@]}"
assert_eq "split: 単一パスの内容が変わらない" \
  ".claude/docs/ddr/i0001-01-a.md" "${REPLY_SPLIT_CANDIDATES[0]:-}"

REPLY_SPLIT_CANDIDATES=()
split_concatenated_candidates_to_reply ".claude/docs/ddr/i0001-01-a.md、.claude/docs/ddr/i0002-01-b.md"
assert_eq "split: 全角読点で連結された2パスは2件に分割される" "2" "${#REPLY_SPLIT_CANDIDATES[@]}"
assert_eq "split: 1件目は末尾の区切り文字を含まずに.mdで終わる" \
  ".claude/docs/ddr/i0001-01-a.md" "${REPLY_SPLIT_CANDIDATES[0]:-}"
assert_eq "split: 2件目" \
  ".claude/docs/ddr/i0002-01-b.md" "${REPLY_SPLIT_CANDIDATES[1]:-}"

REPLY_SPLIT_CANDIDATES=()
split_concatenated_candidates_to_reply ".claude/docs/ddr/i0001-01-a.md、.claude/docs/ddr/i0002-01-b.md。.claude/docs/ddr/i0003-01-c.md"
assert_eq "split: 3件連結も正しく3件に分割される" "3" "${#REPLY_SPLIT_CANDIDATES[@]}"
assert_eq "split: 3件連結の3件目" \
  ".claude/docs/ddr/i0003-01-c.md" "${REPLY_SPLIT_CANDIDATES[2]:-}"

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

# --- main（統合テスト。使い捨てのtmpリポジトリで実行し、実リポジトリは汚さない） -----------

run_main_in_tmp_repo() {
  # $1: セットアップ用関数名（tmpリポジトリのカレントディレクトリでファイルを作る）
  # 戻り値: REPLY_MAIN_STDOUT / REPLY_MAIN_STDERR / REPLY_MAIN_STATUS
  # 呼び出し元がset -e配下でも安全なよう、このヘルパー自身は常に0を返す
  # （終了コードの受け方は.claude/rules/shell-script-style.md「テスト」の
  # 「終了コードを検査するテストで"$(func; echo $?)"の形を使わない」に従いifで受ける）。
  local setup_fn="$1"
  local tmp_repo stderr_file out status
  tmp_repo="$(mktemp -d)"
  stderr_file="$(mktemp)"
  (
    cd "$tmp_repo"
    git init -q
    git config user.email test@example.com
    git config user.name test
    "$setup_fn"
    git add -A
  )
  if out="$(cd "$tmp_repo" && bash "$target_script" 2>"$stderr_file")"; then
    status=0
  else
    status=$?
  fi
  REPLY_MAIN_STDOUT="$out"
  REPLY_MAIN_STDERR="$(cat "$stderr_file")"
  REPLY_MAIN_STATUS="$status"
  rm -f "$stderr_file"
  rm -rf "$tmp_repo"
}

setup_broken_reference() {
  mkdir -p .claude/docs/ddr
  cat > doc.md <<'EOF'
line1
参照: .claude/docs/ddr/i9999-99-架空.md
EOF
}

REPLY_MAIN_STDOUT=""; REPLY_MAIN_STDERR=""; REPLY_MAIN_STATUS=0
run_main_in_tmp_repo setup_broken_reference
assert_eq "main: 壊れた参照1件があれば終了コード1" "1" "$REPLY_MAIN_STATUS"
assert_eq "main: 壊れた参照の報告行が出力される" \
  "doc.md:2:.claude/docs/ddr/i9999-99-架空.md" "$REPLY_MAIN_STDOUT"

setup_valid_reference() {
  mkdir -p .claude/docs/ddr
  touch .claude/docs/ddr/i0001-01-実在.md
  cat > doc.md <<'EOF'
参照: .claude/docs/ddr/i0001-01-実在.md
EOF
}

REPLY_MAIN_STDOUT=""; REPLY_MAIN_STDERR=""; REPLY_MAIN_STATUS=0
run_main_in_tmp_repo setup_valid_reference
assert_eq "main: 参照が実在すれば終了コード0" "0" "$REPLY_MAIN_STATUS"
assert_eq "main: 参照が実在すれば報告行は空" "" "$REPLY_MAIN_STDOUT"

setup_excluded_dir_reference() {
  # 除外ディレクトリ外にも1件対象ファイルを置く（除外対象しか無いと「対象ファイルが
  # 1件も無い」ケースと区別が付かなくなるため）
  mkdir -p .claude/docs/ddr plans
  echo '本文のみ' > other.md
  cat > "plans/【調査】foo.md" <<'EOF'
参照: .claude/docs/ddr/i9999-97-除外対象.md
EOF
}

REPLY_MAIN_STDOUT=""; REPLY_MAIN_STDERR=""; REPLY_MAIN_STATUS=0
run_main_in_tmp_repo setup_excluded_dir_reference
assert_eq "main: 除外ディレクトリ(plans/)配下は無視され終了コード0" "0" "$REPLY_MAIN_STATUS"
assert_eq "main: 除外ディレクトリ配下の参照切れは報告されない" "" "$REPLY_MAIN_STDOUT"

setup_line_number_after_fence() {
  mkdir -p .claude/docs/ddr
  cat > doc.md <<'EOF'
line1
```
echo hi
```
line5
参照: .claude/docs/ddr/i9999-96-フェンス後.md
EOF
}

REPLY_MAIN_STDOUT=""; REPLY_MAIN_STDERR=""; REPLY_MAIN_STATUS=0
run_main_in_tmp_repo setup_line_number_after_fence
assert_eq "main: フェンス後の参照切れは実ファイルの行番号(6)で報告される" \
  "doc.md:6:.claude/docs/ddr/i9999-96-フェンス後.md" "$REPLY_MAIN_STDOUT"

setup_unbalanced_fence_marker_mismatch() {
  mkdir -p .claude/docs/ddr
  cat > doc.md <<'EOF'
```text
~~~
```
参照切れ: .claude/docs/ddr/i9999-95-種別違い.md
~~~
EOF
}

REPLY_MAIN_STDOUT=""; REPLY_MAIN_STDERR=""; REPLY_MAIN_STATUS=0
run_main_in_tmp_repo setup_unbalanced_fence_marker_mismatch
assert_eq "main: 種別違いのフェンス風行があっても参照切れを無言で見逃さない" \
  "doc.md:4:.claude/docs/ddr/i9999-95-種別違い.md" "$REPLY_MAIN_STDOUT"

setup_no_target_files() {
  echo "hello" > README.txt
}

REPLY_MAIN_STDOUT=""; REPLY_MAIN_STDERR=""; REPLY_MAIN_STATUS=0
run_main_in_tmp_repo setup_no_target_files
assert_eq "main: 対象ファイルが1件も無ければ終了コード1（空振り緑を許さない）" "1" "$REPLY_MAIN_STATUS"

echo "passed=$passed failures=$failures"
[[ "$failures" -eq 0 ]]
