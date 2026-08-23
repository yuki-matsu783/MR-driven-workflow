#!/usr/bin/env bash
# .claude/scripts/src/check-dist-coverage.sh の単体テスト（issue #26）。
#
# 検査するのは次の2つ。
#   1. **このリポジトリの実際の定義**（.claude/dist-layers.json）で4種の検査が通ること。
#   2. **異常を実際に検出できること**。「異常が無ければ何も出ない検証」にしないための、
#      検出側のテストである（`.claude/rules/shell-script-style.md`）。定義から意図的に
#      1件落とした一時ツリーを作り、そこで落ちることまで確かめる。
#
# 規約: passed=N failures=N を標準出力へ出し、失敗があれば終了コード1
#       （.claude/rules/shell-script-style.md「テスト」）。
# 実行: bash .claude/scripts/test/test_check_dist_coverage.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
TARGET="${REPO_ROOT}/.claude/scripts/src/check-dist-coverage.sh"
DEF="${REPO_ROOT}/.claude/dist-layers.json"

passed=0
failures=0

# **配布先ではこのテストだけが存在し、対象が存在しないことがある**（配布先が
# .claude/dist-layers.json を持たない場合）。無言でスキップせず件数を出す。
if [ ! -f "$TARGET" ] || [ ! -f "$DEF" ]; then
  echo "skipped: check-dist-coverage.sh または dist-layers.json が無いためスキップします"
  echo "passed=0 failures=0"
  exit 0
fi

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    passed=$((passed + 1))
  else
    failures=$((failures + 1))
    printf 'FAIL: %s\n  expected: %s\n  actual  : %s\n' "$label" "$expected" "$actual" >&2
  fi
}

# 終了コードは `if` で受ける（`"$(cmd; echo $?)"` は set -e 配下で空文字列になりうる）。
status_of() {
  if "$@" > /dev/null 2>&1; then printf '0'; else printf '1'; fi
}

TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

run_here() { (cd "$REPO_ROOT" && bash "$TARGET" "$@"); }

# --- 1. 実際の定義で通ること ------------------------------------------------

assert_eq "実際の定義で4種すべて通る" "0" "$(status_of run_here)"

out="$(run_here)"
assert_eq "結果行を出す" "1" "$(printf '%s\n' "$out" | grep -c '^結果: OK')"
# 「異常が無ければ何も出ない」形にしないため、4種すべてが件数付きで出ること。
for n in 1 2 3 4; do
  assert_eq "検査${n}の件数を出す" "1" "$(printf '%s\n' "$out" | grep -c "^検査${n} ")"
done
assert_eq "分母は追跡ファイル全件" \
  "$(git -C "$REPO_ROOT" ls-files | wc -l)" \
  "$(printf '%s\n' "$out" | sed -n 's#^検査1 .*/ \([0-9]*\) 件$#\1#p')"

# --- 2. 異常を実際に検出できること ------------------------------------------

# 2-a. 定義に無い追跡ファイルを検出する。
#      プローブは**ルート直下**へ置く。`.claude/` 配下だと広域の core エントリに被覆され、
#      「検出できないのに検証は通る」状態になる（実際に踏んだ）。
probe="${REPO_ROOT}/__coverage_probe__.md"
: > "$probe"
git -C "$REPO_ROOT" add -N -- "$probe" > /dev/null
assert_eq "定義に無い追跡ファイルを検出する" "1" "$(status_of run_here)"
assert_eq "未分類のパスを列挙する" "1" \
  "$(run_here 2>/dev/null | grep -cF -- '__coverage_probe__.md' || true)"

# 検出が偶然でないことの確認: 同じ状態でも、定義へ足せば通る。
def_with_probe="${TMP_DIR}/with_probe.json"
jq '.entries += [{"layer":"exclude","path":"__coverage_probe__.md","note":"テスト用"}]' \
  "$DEF" > "$def_with_probe"
assert_eq "定義へ足せば被覆できる" "0" "$(status_of run_here --def "$def_with_probe")"

git -C "$REPO_ROOT" rm -q --cached -- "$probe" > /dev/null
rm -f "$probe"
assert_eq "後片付け後は元どおり通る" "0" "$(status_of run_here)"

# 2-b. 検査2（.gitignore の行の被覆）が落ちること。
#      定義から gitignorePattern を1つ落とす。
def_no_pat="${TMP_DIR}/no_pattern.json"
jq '.entries |= map(select(.gitignorePattern != "/usage/"))' "$DEF" > "$def_no_pat"
assert_eq "gitignorePatternの載せ忘れを検出する" "1" "$(status_of run_here --def "$def_no_pat")"
assert_eq "被覆できていないパターンを列挙する" "1" \
  "$(run_here --def "$def_no_pat" 2>/dev/null | grep -cFx -- '    /usage/' || true)"

# 2-c. 検査3（空振りエントリ）が落ちること。
def_typo="${TMP_DIR}/typo.json"
jq '.entries += [{"layer":"core","path":"存在しないパス.md"}]' "$DEF" > "$def_typo"
assert_eq "1件も一致しないエントリを検出する" "1" "$(status_of run_here --def "$def_typo")"

# 2-d. 検査4（layer / strategy の妥当性）が落ちること。
def_bad_layer="${TMP_DIR}/bad_layer.json"
jq '.entries += [{"layer":"typo-layer","path":"README.md"}]' "$DEF" > "$def_bad_layer"
assert_eq "未知のlayerを検出する" "1" "$(status_of run_here --def "$def_bad_layer")"

def_bad_merge="${TMP_DIR}/bad_merge.json"
jq '.entries += [{"layer":"merge","path":"README.md"}]' "$DEF" > "$def_bad_merge"
assert_eq "strategyの無いmergeを検出する" "1" "$(status_of run_here --def "$def_bad_merge")"

def_bad_ign="${TMP_DIR}/bad_ign.json"
jq '.entries += [{"layer":"core","gitignorePattern":"*.tmp"}]' "$DEF" > "$def_bad_ign"
assert_eq "gitignorePatternがlocal以外なら検出する" "1" "$(status_of run_here --def "$def_bad_ign")"

# --- 3. 配布先での振る舞い（upstream の印が無ければスキップして0で終わる） --

def_downstream="${TMP_DIR}/downstream.json"
jq 'del(.upstream)' "$DEF" > "$def_downstream"
assert_eq "配布先では終了コード0で終わる" "0" "$(status_of run_here --def "$def_downstream")"
down_out="$(run_here --def "$def_downstream")"
assert_eq "配布先ではスキップと分かる出力を出す" "1" \
  "$(printf '%s\n' "$down_out" | grep -c '^スキップ:')"
# 無言のスキップにしない（件数を必ず出す）。
assert_eq "スキップ時も件数を出す" "1" \
  "$(printf '%s\n' "$down_out" | grep -c '追跡ファイル [0-9]* 件')"

# --- 3-b. 検査対象は「定義ファイルの置かれたリポジトリ」で決まる -------------
# 既定の相対パスと cwd 基準の `git ls-files` のままだと、別ディレクトリから起動したときに
# 「起動時のカレントディレクトリのリポジトリ」を検査してしまう（install-to-project.sh が
# 配布先を cwd にして呼ばれると必ず中断していた）。
run_outside() { (cd "$TMP_DIR" && bash "$TARGET" "$@"); }

assert_eq "本家ルート以外から起動しても通る" "0" "$(status_of run_outside --def "$DEF")"
# 通るだけでは「別のリポジトリを検査して偶然通った」場合と区別できないので、分母まで見る。
assert_eq "別cwdでも分母は本家の追跡ファイル数" \
  "$(git -C "$REPO_ROOT" ls-files | wc -l)" \
  "$(run_outside --def "$DEF" | sed -n 's#^検査1 .*/ \([0-9]*\) 件$#\1#p')"

# --- 4. 引数の扱い ----------------------------------------------------------

assert_eq "定義ファイルが無ければ失敗する" "1" "$(status_of run_here --def "${TMP_DIR}/no_such.json")"
printf '%s' 'これはJSONではない' > "${TMP_DIR}/broken.json"
assert_eq "定義が壊れたJSONなら失敗する" "1" "$(status_of run_here --def "${TMP_DIR}/broken.json")"
assert_eq "不明な引数は失敗する" "1" "$(status_of run_here --unknown-option)"
assert_eq "--help は成功する" "0" "$(status_of run_here --help)"

echo "passed=$passed failures=$failures"
[ "$failures" -eq 0 ]
