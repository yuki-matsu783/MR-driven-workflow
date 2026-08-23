#!/usr/bin/env bash
# .claude/scripts/src/collect-review-points.sh の単体テスト。issue #77。
#
# 純粋関数 `review_points_ancestor_dirs`（祖先ディレクトリ列の算出）に加え、
# `main` の収集・マージ動作も、mktempで作った一時的なgitリポジトリを対象に確認する
# （このリポジトリ自身を対象にすると、ルートの REVIEW-POINTS.md が常に存在するため
#  「観点表が1つも無い場合」を検証できないため）。
#
# 規約: passed=N failures=N を標準出力へ出し、失敗があれば終了コード1。
# 実行: bash .claude/scripts/test/test_collect_review_points.sh
set -euo pipefail

script_dir="${BASH_SOURCE[0]%/*}"
[[ "$script_dir" == "${BASH_SOURCE[0]}" ]] && script_dir="."
repo_root="$(cd "$script_dir/../../.." && pwd)"
target="$repo_root/.claude/scripts/src/collect-review-points.sh"

# shellcheck source=../../../.claude/scripts/src/collect-review-points.sh
source "$target"

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

# --- review_points_ancestor_dirs -----------------------------------------------------

assert_eq "review_points_ancestor_dirs: ルート直下のファイルはルートのみ" \
  '.' \
  "$(review_points_ancestor_dirs 'HANDOFF.md')"

assert_eq "review_points_ancestor_dirs: 深いパスは浅い順に列挙する" \
  $'.\n.claude\n.claude/scripts\n.claude/scripts/src\n.claude/scripts/src/vcs' \
  "$(review_points_ancestor_dirs '.claude/scripts/src/vcs/Github.sh')"

assert_eq "review_points_ancestor_dirs: 先頭の./は無視する" \
  $'.\nplans' \
  "$(review_points_ancestor_dirs './plans/x.md')"

# 日本語を含むパスが壊れないこと（bashの部分文字列展開ではなくパラメータ展開で扱っている）
assert_eq "review_points_ancestor_dirs: 日本語を含むパスを壊さない" \
  $'.\nplans\nplans/【設計】' \
  "$(review_points_ancestor_dirs 'plans/【設計】/計画.md')"

assert_eq "review_points_ancestor_dirs: ..は直前の要素を打ち消す" \
  $'.\na\na/b\na/c' \
  "$(review_points_ancestor_dirs 'a/b/../c/x.sh')"

# 観点表の探索がリポジトリの外へ出ると、無関係なファイルを観点として読み込みかねない
assert_eq "review_points_ancestor_dirs: リポジトリルートより上へ出ない" \
  $'.\netc' \
  "$(review_points_ancestor_dirs '../../etc/passwd')"

assert_eq "review_points_ancestor_dirs: ルート直上の..だけならルートのみ" \
  '.' \
  "$(review_points_ancestor_dirs '../x.md')"

# --- strip_frontmatter_h1_and_comments --------------------------------------------------------

fixture_md="$(mktemp)"
printf '%s\n' '---' 'title: T' 'type: review-points' '---' '' '# 見出し' '' '本文1' '' '## 節' '- 項目' > "$fixture_md"

assert_eq "strip_frontmatter_h1_and_comments: frontmatterとH1と先頭空行を取り除く" \
  $'本文1\n\n## 節\n- 項目' \
  "$(strip_frontmatter_h1_and_comments "$fixture_md")"

printf '%s\n' '本文だけ' '- 項目' > "$fixture_md"
assert_eq "strip_frontmatter_h1_and_comments: frontmatterもH1も無ければそのまま" \
  $'本文だけ\n- 項目' \
  "$(strip_frontmatter_h1_and_comments "$fixture_md")"

# HTMLコメントは観点ではないので落とす（REVIEW-POINTS.local.md の雛形が使い方の説明を持つ）。
printf '%s\n' '<!--' '雛形の説明' 'つづき' '-->' '' '- 本物の観点' > "$fixture_md"
assert_eq "strip_frontmatter_h1_and_comments: 複数行のHTMLコメントを落とす" \
  '- 本物の観点' \
  "$(strip_frontmatter_h1_and_comments "$fixture_md")"

printf '%s\n' '<!-- 1行コメント -->' '- 本物の観点' > "$fixture_md"
assert_eq "strip_frontmatter_h1_and_comments: 1行で閉じるHTMLコメントも落とす" \
  '- 本物の観点' \
  "$(strip_frontmatter_h1_and_comments "$fixture_md")"

# 雛形のまま（説明コメントだけ）なら中身は空になる。
printf '%s\n' '---' 'title: T' '---' '' '# 見出し' '' '<!--' 'ここへ観点を書く' '-->' > "$fixture_md"
assert_eq "strip_frontmatter_h1_and_comments: 雛形のままなら空になる" \
  '' \
  "$(strip_frontmatter_h1_and_comments "$fixture_md")"

# --- main（収集・マージ） -------------------------------------------------------------

fixture_repo="$(mktemp -d)"
cleanup() { rm -rf "$fixture_repo"; }
trap cleanup EXIT

(
  cd "$fixture_repo"
  git init -q .
  mkdir -p a/b c
  printf '%s\n' '---' 'title: R' '---' '' '# ルート' '' '- ルートの観点' > REVIEW-POINTS.md
  printf '%s\n' '---' 'title: A' '---' '' '# a' '' '- aの観点' > a/REVIEW-POINTS.md
  printf '%s\n' '---' 'title: AB' '---' '' '# ab' '' '- abの観点' > a/b/REVIEW-POINTS.md
  : > a/b/deep.sh
  : > c/other.sh
)

collect() { (cd "$fixture_repo" && bash "$target" "$@"); }

assert_eq "collect: 祖先チェーンの観点表を浅い順に出す" \
  $'## REVIEW-POINTS.md\n## a/REVIEW-POINTS.md\n## a/b/REVIEW-POINTS.md' \
  "$(collect a/b/deep.sh | grep '^## ')"

assert_eq "collect: 祖先でない観点表は含めない" \
  '## REVIEW-POINTS.md' \
  "$(collect c/other.sh | grep '^## ')"

# 複数ファイルを渡したときに同じ観点表が重複しないこと（和集合を取る）
assert_eq "collect: 複数ファイルでも同じ観点表は1回だけ" \
  $'## REVIEW-POINTS.md\n## a/REVIEW-POINTS.md\n## a/b/REVIEW-POINTS.md' \
  "$(collect a/b/deep.sh c/other.sh | grep '^## ')"

# 渡す順序が変わっても出力順は「浅い → 深い」で安定していること
assert_eq "collect: 渡す順序によらず浅い順で出す" \
  $'## REVIEW-POINTS.md\n## a/REVIEW-POINTS.md\n## a/b/REVIEW-POINTS.md' \
  "$(collect c/other.sh a/b/deep.sh | grep '^## ')"

assert_eq "collect: 観点表の中身が見出しの下に続く" \
  '- abの観点' \
  "$(collect a/b/deep.sh | grep -- '- abの観点')"

# --- REVIEW-POINTS.local.md（配布先所有の観点表。issue #26） --------------------------

(
  cd "$fixture_repo"
  mkdir -p d/e
  # 本家の観点表がある所へ .local を足す
  printf '%s\n' '---' 'title: AL' '---' '' '# a.local' '' '- aのlocal観点' > a/REVIEW-POINTS.local.md
  # **本家の観点表が無く .local だけ**あるディレクトリ（.local の最も典型的な使い方）
  printf '%s\n' '---' 'title: DL' '---' '' '# d.local' '' '- dのlocal観点' > d/REVIEW-POINTS.local.md
  : > d/e/f.sh
)

assert_eq "collect: .local は同じディレクトリの本家の観点表の直後に出る" \
  $'## REVIEW-POINTS.md\n## a/REVIEW-POINTS.md\n## a/REVIEW-POINTS.local.md\n## a/b/REVIEW-POINTS.md' \
  "$(collect a/b/deep.sh | grep '^## ')"

# 現行実装はディレクトリ単位で `continue` していたため、このケースが丸ごと無視されていた。
assert_eq "collect: 本家の観点表が無く .local だけあるディレクトリも拾う" \
  $'## REVIEW-POINTS.md\n## d/REVIEW-POINTS.local.md' \
  "$(collect d/e/f.sh | grep '^## ')"

assert_eq "collect: .local の中身も見出しの下に続く" \
  '- dのlocal観点' \
  "$(collect d/e/f.sh | grep -- '- dのlocal観点')"

# .local が無いディレクトリで空振りしても失敗しない（存在するのが普通の状態）
assert_eq "collect: .local が無くても終了コード0" '0' \
  "$(if collect c/other.sh >/dev/null 2>&1; then printf 0; else printf 1; fi)"

# 観点表が1つも無い場合は、エラーではなく「無出力・終了コード0」
empty_repo="$(mktemp -d)"
(
  cd "$empty_repo"
  git init -q .
  : > x.sh
)
if (cd "$empty_repo" && bash "$target" x.sh > "$empty_repo/out.txt" 2>/dev/null); then
  empty_status=0
else
  empty_status=1
fi
assert_eq "collect: 観点表が1つも無くても終了コード0" '0' "$empty_status"
assert_eq "collect: 観点表が1つも無ければ無出力" '0' "$(wc -c < "$empty_repo/out.txt")"
rm -rf "$empty_repo"

# --- 中身が空の観点表はスキップする（issue #26） ---------------------------------------
# 配布直後の REVIEW-POINTS.local.md は雛形のままで観点を1つも持たない。見出しだけが並ぶと
# 読み手の手間になるので出さない。ただし**無言では捨てず**、件数を標準エラーへ出す。
empty_rp_repo="$(mktemp -d)"
(
  cd "$empty_rp_repo"
  git init -q .
  printf '%s\n' '---' 'title: T' '---' '' '# 見出し' '' '- 本物の観点' > REVIEW-POINTS.md
  printf '%s\n' '---' 'title: L' '---' '' '# 見出し' '' '<!--' 'ここへ観点を書く' '-->' \
    > REVIEW-POINTS.local.md
  : > x.sh
)
(cd "$empty_rp_repo" && bash "$target" x.sh > "$empty_rp_repo/out.txt" 2> "$empty_rp_repo/err.txt")
assert_eq "collect: 雛形のままの .local は見出しごと出さない" '0' \
  "$(grep -c '^## REVIEW-POINTS.local.md' "$empty_rp_repo/out.txt" || true)"
assert_eq "collect: 中身のある観点表は従来どおり出す" '1' \
  "$(grep -c '^## REVIEW-POINTS.md' "$empty_rp_repo/out.txt" || true)"
assert_eq "collect: スキップは無言にせず件数を標準エラーへ出す" '1' \
  "$(grep -c '観点を1つも持たない観点表を 1 件スキップ' "$empty_rp_repo/err.txt" || true)"
rm -rf "$empty_rp_repo"

# 引数なしは使い方を示して失敗する
if (cd "$fixture_repo" && bash "$target" >/dev/null 2>&1); then
  noarg_status=0
else
  noarg_status=1
fi
assert_eq "collect: 引数なしは終了コード1" '1' "$noarg_status"

echo "passed=$passed failures=$failures"
[ "$failures" -eq 0 ]
