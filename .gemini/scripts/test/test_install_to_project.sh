#!/usr/bin/env bash
# install-to-project.sh の結合テスト（issue #33）。
#
# 対象は issue #33 で追加した配布資産まわりの挙動に絞る。
#   - PR/MRテンプレート・.claude/VERSION が配布先へ配置されること
#   - PR/MRテンプレートの見出しが `describe` サブコマンドの生成物と一致すること
#   - .gitattributes は丸ごと置き換えず「行追記」で反映されること（配布先の既存設定を壊さない）
#   - 何度適用しても追記行が増えないこと（冪等）。**配布先がCRLFの場合も含む**
#   - .claude/VERSION の更新が .bak と警告を生まないこと
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

# **配布先ではこのテストだけが存在し、テスト対象が存在しない**（sync-assets.sh は
# apply-mr-workflow-to-project スキル自身を配布対象から除外する一方、.claude/scripts/test/ は
# 丸ごと配布するため）。対象が無い環境では、規約どおり件数を出したうえでスキップする
# （無言でスキップすると、本当の欠落を隠してしまう）。
if [ ! -f "${SKILL_SCRIPTS}/install-to-project.sh" ]; then
  echo "skipped: ${SKILL_SCRIPTS}/install-to-project.sh が無いためスキップします" \
       "（apply-mr-workflow-to-project スキルは配布対象外のため、配布先ではこの状態が正常です）"
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

# 配布を1回実行する。標準出力だけを捨て、**標準エラーは捨てない**
# （捨てると失敗理由が見えず、無言で落ちる）。
install_to() {
  bash "${SKILL_SCRIPTS}/install-to-project.sh" "$1" >/dev/null
}

# 配布物（assets/）を作り直す。ここが失敗するとテスト全体が意味を持たないため、失敗させる。
bash "${SKILL_SCRIPTS}/sync-assets.sh" >/dev/null

# --- 1. 新規の配布先 -------------------------------------------------------
dest_new="$(make_dest dest_new)"
install_to "$dest_new"

for rel in .github/pull_request_template.md .gitlab/merge_request_templates/Default.md \
           .claude/VERSION .gitattributes; do
  if [ -f "$dest_new/$rel" ]; then found=1; else found=0; fi
  assert_eq "新規配布先へ配置される: $rel" "1" "$found"
done

assert_eq "配布先のVERSIONが本家と一致する" \
  "$(cat "${REPO_ROOT}/.claude/VERSION")" "$(cat "$dest_new/.claude/VERSION")"

# `sync-gemini-assets.sh` の列挙（`git ls-files --cached --others --exclude-standard`）は、
# ローカル設定の除外を配布先の .gitignore へ委ねている（issue #70）。この行が配られないと、
# 各開発者の .claude/settings.local.json が .gemini/ へ焼き込まれてコミットされる。
assert_eq "配布先の.gitignoreへローカル設定の除外が入る" \
  "1" "$(grep -cFx -- '/.claude/settings.local.json' "$dest_new/.gitignore" || true)"

# PR/MRテンプレートの見出しは、`describe` サブコマンドが生成するdescriptionと一致していること。
# **2つのテンプレート同士を比べるだけでは足りない**（両方が同時にずれた場合に通ってしまう）。
# 正である SKILL.md の `describe` 節から見出しを抜き出し、3者で突き合わせる。
describe_headings() {
  # テンプレートは番号付きリストの中にあるため、行頭に空白が付いている。落としてから比較する。
  awk '
    /^### `describe`/ { in_section = 1; next }
    /^### /           { in_section = 0 }
    in_section && /^[[:space:]]*(Closes|## )/ {
      sub(/^[[:space:]]+/, "", $0); print
    }
  ' "${REPO_ROOT}/.claude/skills/issue-mr-flow/SKILL.md"
}
expected_headings="$(describe_headings)"

# 期待値そのものが空になっていないか（SKILL.mdの節名が変わると抽出が空振りし、
# 「空同士の一致」で常に通るテストになる）。
assert_eq "describeの見出しを3行抽出できている" "3" "$(printf '%s\n' "$expected_headings" | grep -c .)"

for rel in .github/pull_request_template.md .gitlab/merge_request_templates/Default.md; do
  assert_eq "describeの生成物と見出しが一致する: $rel" \
    "$expected_headings" "$(grep -E '^(Closes|## )' "$dest_new/$rel")"
done

assert_eq "配布先の.gitattributesへ*.shの指定が入る" \
  "1" "$(grep -cFx -- '*.sh text eol=lf' "$dest_new/.gitattributes")"

assert_eq "本家だけの方針である* text=autoは配らない" \
  "0" "$(grep -cFx -- '* text=auto' "$dest_new/.gitattributes" || true)"

assert_eq "マーカー行自体は配らない" \
  "0" "$(grep -cF -- 'dist:begin' "$dest_new/.gitattributes" || true)"

# --- 2. 既存の .gitattributes を持つ配布先 ---------------------------------
# 末尾に改行が無い状態を意図的に作る（追記行が直前の行と連結しないことの確認）。
dest_exist="$(make_dest dest_exist)"
printf '%s\n%s\n%s' '# 配布先が元から持っている設定' '*.png binary' '*.md text eol=lf diff=markdown' \
  > "$dest_exist/.gitattributes"
install_to "$dest_exist"

assert_eq "配布先の既存3行がすべて残る" \
  "3" "$(grep -cE -- '^(# 配布先が元から|\*\.png binary|\*\.md text)' "$dest_exist/.gitattributes")"
assert_eq "末尾に改行が無くても直前の行と連結しない" \
  "1" "$(grep -cFx -- '*.md text eol=lf diff=markdown' "$dest_exist/.gitattributes")"
assert_eq "全文置換ではないので.bakを作らない" \
  "0" "$([ -f "$dest_exist/.gitattributes.bak" ] && echo 1 || echo 0)"

# --- 3. 冪等性 -------------------------------------------------------------
install_to "$dest_exist"
install_to "$dest_exist"
assert_eq "3回適用しても*.shの指定は1行のまま" \
  "1" "$(grep -cFx -- '*.sh text eol=lf' "$dest_exist/.gitattributes")"
assert_eq "3回適用してもヘッダコメントは1行のまま" \
  "1" "$(grep -cFx -- '# mr-driven-develop workflow attributes' "$dest_exist/.gitattributes")"

# --- 4. 配布先の .gitattributes がCRLFの場合の冪等性 -----------------------
# Git for Windowsの既定（core.autocrlf=true）では配布先の .gitattributes が作業ツリーで
# CRLFになる。CRを落とさずに行全体の一致で判定すると「まだ無い」と誤判定し、適用のたびに
# 同じ行が追記され続ける。
#
# **初回だけCRLFにしても再現しない。** 追記した行はLFのまま残るので、2回目は素直に一致して
# しまう。実際に起きるのは「コミット→チェックアウトのたびにファイル全体がCRLFへ戻る」形なので、
# 適用のたびに全体をCRLFへ正規化して、その状況を作る。
to_crlf() {
  local file="$1" tmp="$1.crlf"
  sed -e 's/\r$//' -e 's/$/\r/' "${file}" > "${tmp}"
  mv "${tmp}" "${file}"
}

dest_crlf="$(make_dest dest_crlf)"
printf '%s\r\n%s\r\n' '# 配布先が元から持っている設定' '*.png binary' > "$dest_crlf/.gitattributes"
install_to "$dest_crlf"; to_crlf "$dest_crlf/.gitattributes"
install_to "$dest_crlf"; to_crlf "$dest_crlf/.gitattributes"
install_to "$dest_crlf"; to_crlf "$dest_crlf/.gitattributes"
assert_eq "CRLFの配布先でも*.shの指定は1行のまま" \
  "1" "$(tr -d '\r' < "$dest_crlf/.gitattributes" | grep -cFx -- '*.sh text eol=lf')"
assert_eq "CRLFの配布先でもヘッダコメントは1行のまま" \
  "1" "$(tr -d '\r' < "$dest_crlf/.gitattributes" | grep -cFx -- '# mr-driven-develop workflow attributes')"

# --- 5. コメントで言及しているだけの配布先 ---------------------------------
# 部分一致で判定していると「もう有る」と誤判定し、必要な指定が入らないまま無言で終わる。
dest_comment="$(make_dest dest_comment)"
printf '%s\n' '# *.sh text eol=lf を入れるか検討中' > "$dest_comment/.gitattributes"
install_to "$dest_comment"
assert_eq "コメント中の言及を実設定と誤認しない" \
  "1" "$(grep -cFx -- '*.sh text eol=lf' "$dest_comment/.gitattributes")"

# --- 6. .claude/VERSION の更新は .bak も警告も生まない ---------------------
# VERSIONは配布元が所有する値であり「配布先のカスタマイズ」ではない。通常の
# 「差分があれば .bak 退避して警告」の対象にすると、版を上げた回は必ず警告が出て、
# 本当に手を入れるべき差分の警告が埋もれる。
dest_ver="$(make_dest dest_ver)"
install_to "$dest_ver"
printf '%s\n' '0.0.1-old' > "$dest_ver/.claude/VERSION"
install_output="$(bash "${SKILL_SCRIPTS}/install-to-project.sh" "$dest_ver")"

assert_eq "版が違っても配布元の値で上書きされる" \
  "$(cat "${REPO_ROOT}/.claude/VERSION")" "$(cat "$dest_ver/.claude/VERSION")"
assert_eq "VERSIONの.bakを作らない" \
  "0" "$([ -f "$dest_ver/.claude/VERSION.bak" ] && echo 1 || echo 0)"
assert_eq "VERSIONについて警告を出さない" \
  "0" "$(printf '%s\n' "$install_output" | grep -cF -- 'VERSION already exists' || true)"

echo "passed=$passed failures=$failures"
[ "$failures" -eq 0 ]
