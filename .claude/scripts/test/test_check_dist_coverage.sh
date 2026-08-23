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

# **このテストは配布先へも届く**（.claude/scripts/test/ は core として丸ごと配られる）。
# 以下の期待値は本家（dist-layers.json に `upstream: true` がある側）でしか成立しないため、
# 本家でなければ実行せずに終える。**判定を「対象ファイルがあるか」で行わないこと。**
# 配布先にも check-dist-coverage.sh と dist-layers.json（upstream を落としたもの）は
# 存在するので、ファイルの有無で見るとスキップに入らず一斉に落ちる（配布先で
# passed=11 failures=15 になることを実測。issue #26 のフェーズ3・敵対的レビュー3回目）。
# 無言でスキップせず、理由と件数を出す。
if [ ! -f "$TARGET" ] || [ ! -f "$DEF" ]; then
  echo "skipped: check-dist-coverage.sh または dist-layers.json が無いためスキップします"
  echo "passed=0 failures=0"
  exit 0
fi
if ! jq -e '.upstream == true' "$DEF" > /dev/null 2>&1; then
  echo "skipped: 本家ではない（dist-layers.json に upstream の印が無い）ためスキップします"
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
#
#      **このリポジトリのindexを書き換えない。** `git add -N` を実リポジトリへ当てると、
#      テストが途中で止まったときに intent-to-add のエントリが残る。indexの写しを
#      `GIT_INDEX_FILE` で差し替えれば、`git ls-files`（検査1の分母）はその写しを見るので、
#      実リポジトリのindexは1バイトも変わらない。
probe="${REPO_ROOT}/__coverage_probe__.md"
: > "$probe"
alt_index="${TMP_DIR}/alt-index"
cp "$(git -C "$REPO_ROOT" rev-parse --git-path index)" "$alt_index"
GIT_INDEX_FILE="$alt_index" git -C "$REPO_ROOT" add -N -- "$probe" > /dev/null
run_probe() { (cd "$REPO_ROOT" && GIT_INDEX_FILE="$alt_index" bash "$TARGET" "$@"); }

assert_eq "定義に無い追跡ファイルを検出する" "1" "$(status_of run_probe)"
assert_eq "未分類のパスを列挙する" "1" \
  "$(run_probe 2>/dev/null | grep -cF -- '__coverage_probe__.md' || true)"

# 検出が偶然でないことの確認: 同じ状態でも、定義へ足せば通る。
def_with_probe="${TMP_DIR}/with_probe.json"
jq '.entries += [{"layer":"exclude","path":"__coverage_probe__.md","note":"テスト用"}]' \
  "$DEF" > "$def_with_probe"
assert_eq "定義へ足せば被覆できる" "0" "$(status_of run_probe --def "$def_with_probe")"

# 差し替えたindexを使っていたことの表明（実リポジトリのindexに残っていないこと）。
assert_eq "実リポジトリのindexにプローブが入っていない" "0" \
  "$(git -C "$REPO_ROOT" ls-files -- '__coverage_probe__.md' | wc -l)"

rm -f "$probe" "$alt_index"
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

# requiredLine は seed 専用（core は毎回上書きされるので、古い形式が残りようがない）。
def_bad_req="${TMP_DIR}/bad_required.json"
jq '.entries += [{"layer":"core","path":"README.md","requiredLine":"なにか"}]' "$DEF" > "$def_bad_req"
assert_eq "requiredLineがseed以外なら検出する" "1" "$(status_of run_here --def "$def_bad_req")"
assert_eq "requiredLineの不正を件数付きで列挙する" "1" \
  "$(run_here --def "$def_bad_req" 2>/dev/null | grep -c 'requiredLine は seed 専用' || true)"

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
