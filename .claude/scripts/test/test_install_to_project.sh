#!/usr/bin/env bash
# install-to-project.sh の結合テスト（issue #33）。
#
# 対象は issue #33 で追加した配布資産まわりの挙動に絞る。
#   - PR/MRテンプレート・.claude/VERSION が配布先へ配置されること
#   - .gitattributes は丸ごと置き換えず「行追記」で反映されること（配布先の既存設定を壊さない）
#   - 何度適用しても追記行が増えないこと（冪等）
#   - 本家だけの方針である `* text=auto` を配らないこと
#
# 実プロセス（sync-assets.sh / install-to-project.sh）を起動する結合確認のため、
# `passed=N failures=N` を出力し失敗があれば終了コード1を返す規約に従う
# （.claude/rules/shell-script-style.md「テスト」）。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SKILL_SCRIPTS="${REPO_ROOT}/.claude/skills/apply-mr-workflow-to-project/scripts"

passed=0
failures=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    passed=$((passed + 1))
  else
    failures=$((failures + 1))
    printf 'FAIL: %s\n  expected: %s\n  actual  : %s\n' "$label" "$expected" "$actual" >&2
  fi
}

TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# 配布先を1つ作る（Gitリポジトリであることが install-to-project.sh の前提）。
make_dest() {
  local dir="$TMP_DIR/$1"
  mkdir -p "$dir"
  git -C "$dir" init -q .
  printf '%s' "$dir"
}

# 配布物（assets/）を作り直す。ここが失敗するとテスト全体が意味を持たないため、失敗させる。
bash "${SKILL_SCRIPTS}/sync-assets.sh" >/dev/null 2>&1

# --- 1. 新規の配布先 -------------------------------------------------------
dest_new="$(make_dest dest_new)"
bash "${SKILL_SCRIPTS}/install-to-project.sh" "$dest_new" >/dev/null 2>&1

for rel in .github/pull_request_template.md .gitlab/merge_request_templates/Default.md \
           .claude/VERSION .gitattributes; do
  if [ -f "$dest_new/$rel" ]; then found=1; else found=0; fi
  assert_eq "新規配布先へ配置される: $rel" "1" "$found"
done

assert_eq "配布先のVERSIONが本家と一致する" \
  "$(cat "${REPO_ROOT}/.claude/VERSION")" "$(cat "$dest_new/.claude/VERSION")"

assert_eq "PRテンプレートとMRテンプレートの見出しが一致する" \
  "$(grep -E '^(Closes|## )' "$dest_new/.github/pull_request_template.md")" \
  "$(grep -E '^(Closes|## )' "$dest_new/.gitlab/merge_request_templates/Default.md")"

assert_eq "配布先の.gitattributesへ*.shの指定が入る" \
  "1" "$(grep -cFx -- '*.sh text eol=lf' "$dest_new/.gitattributes")"

assert_eq "本家だけの方針である* text=autoは配らない" \
  "0" "$(grep -cFx -- '* text=auto' "$dest_new/.gitattributes" || true)"

# --- 2. 既存の .gitattributes を持つ配布先 ---------------------------------
# 末尾に改行が無い状態を意図的に作る（追記行が直前の行と連結しないことの確認）。
dest_exist="$(make_dest dest_exist)"
printf '%s\n%s\n%s' '# 配布先が元から持っている設定' '*.png binary' '*.md text eol=lf diff=markdown' \
  > "$dest_exist/.gitattributes"
bash "${SKILL_SCRIPTS}/install-to-project.sh" "$dest_exist" >/dev/null 2>&1

assert_eq "配布先の既存3行がすべて残る" \
  "3" "$(grep -cE -- '^(# 配布先が元から|\*\.png binary|\*\.md text)' "$dest_exist/.gitattributes")"
assert_eq "末尾に改行が無くても直前の行と連結しない" \
  "1" "$(grep -cFx -- '*.md text eol=lf diff=markdown' "$dest_exist/.gitattributes")"
assert_eq "全文置換ではないので.bakを作らない" \
  "0" "$([ -f "$dest_exist/.gitattributes.bak" ] && echo 1 || echo 0)"

# --- 3. 冪等性 -------------------------------------------------------------
bash "${SKILL_SCRIPTS}/install-to-project.sh" "$dest_exist" >/dev/null 2>&1
bash "${SKILL_SCRIPTS}/install-to-project.sh" "$dest_exist" >/dev/null 2>&1
assert_eq "3回適用しても*.shの指定は1行のまま" \
  "1" "$(grep -cFx -- '*.sh text eol=lf' "$dest_exist/.gitattributes")"
assert_eq "3回適用してもヘッダコメントは1行のまま" \
  "1" "$(grep -cFx -- '# mr-driven-develop workflow attributes' "$dest_exist/.gitattributes")"

# --- 4. コメントで言及しているだけの配布先 ---------------------------------
# 部分一致で判定していると「もう有る」と誤判定し、必要な指定が入らないまま無言で終わる。
dest_comment="$(make_dest dest_comment)"
printf '%s\n' '# *.sh text eol=lf を入れるか検討中' > "$dest_comment/.gitattributes"
bash "${SKILL_SCRIPTS}/install-to-project.sh" "$dest_comment" >/dev/null 2>&1
assert_eq "コメント中の言及を実設定と誤認しない" \
  "1" "$(grep -cFx -- '*.sh text eol=lf' "$dest_comment/.gitattributes")"

echo "passed=$passed failures=$failures"
[ "$failures" -eq 0 ]
