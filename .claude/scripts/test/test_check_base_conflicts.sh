#!/usr/bin/env bash
# .claude/scripts/src/check-base-conflicts.sh の単体テスト（issue #46）。
# 外部コマンド呼び出しを伴わない純粋関数（ddr_identifier_to_reply / find_duplicate_ddr_identifiers）
# のみを対象とする。issue #133でissue番号ベースの識別子（i<issue>-<枝番2桁>）へ対応したため、
# 新方式単独・新旧混在・不正形式のケースも含める。git操作を伴うmainは対象外
# （.claude/scripts/test/では実リポジトリを汚さない方針）。
# 規約: passed=N failures=N を標準出力へ出し、失敗があれば終了コード1
#       （.claude/rules/shell-script-style.md「テスト」。.claude/scripts/test/test_update_handoff_progress.sh を雛形にした）。
# 実行: bash .claude/scripts/test/test_check_base_conflicts.sh
set -euo pipefail

script_dir="${BASH_SOURCE[0]%/*}"
[[ "$script_dir" == "${BASH_SOURCE[0]}" ]] && script_dir="."
repo_root="$(cd "$script_dir/../../.." && pwd)"

# shellcheck source=../../../.claude/scripts/src/check-base-conflicts.sh
source "$repo_root/.claude/scripts/src/check-base-conflicts.sh"

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

# --- ddr_identifier_to_reply -------------------------------------------------

REPLY=""
ddr_identifier_to_reply ".claude/docs/ddr/0027-プロバイダ判定はremote-URLのホスト部で.md"
assert_eq "ddr_identifier_to_reply: 連番（旧方式）は4桁を取り出す" "0027" "$REPLY"

REPLY=""
ddr_identifier_to_reply "0001-first.md"
assert_eq "ddr_identifier_to_reply: ディレクトリ無しのパスも扱える" "0001" "$REPLY"

# 終了コードは `if` の条件式で受ける（`"$(func; echo $?)"` は set -e 配下で空文字列になりうる。
# .claude/rules/shell-script-style.md「テスト」）。
if ddr_identifier_to_reply ".claude/docs/ddr/index.jsonl"; then
  index_status=0
else
  index_status=1
fi
assert_eq "ddr_identifier_to_reply: DDR命名でなければ終了コード1" "1" "$index_status"
assert_eq "ddr_identifier_to_reply: DDR命名でなければREPLYは空" "" "$REPLY"

if ddr_identifier_to_reply ".claude/docs/ddr/027-三桁は対象外.md"; then
  three_digit_status=0
else
  three_digit_status=1
fi
assert_eq "ddr_identifier_to_reply: 連番3桁は対象外" "1" "$three_digit_status"

# --- find_duplicate_ddr_identifiers -----------------------------------------

no_dup="$(find_duplicate_ddr_identifiers "$(printf '%s\n' \
  '.claude/docs/ddr/0026-a.md' \
  '.claude/docs/ddr/0027-b.md' \
  '.claude/docs/ddr/0028-c.md')")"
assert_eq "find_duplicate_ddr_identifiers: 重複が無ければ何も出力しない" "" "$no_dup"

# 実際にPR #52で起きた形（両ブランチが別名で同じ0027を追加した）を再現する。
# ファイル名が異なるためgit自身はコンフリクトと見なさない点が本テストの主眼。
one_dup="$(find_duplicate_ddr_identifiers "$(printf '%s\n' \
  '.claude/docs/ddr/0026-a.md' \
  '.claude/docs/ddr/0027-gh_glab-CLI不在時はMCPフォールバック経路へ機構的に誘導する.md' \
  '.claude/docs/ddr/0027-プロバイダ判定はremote-URLのホスト部でgithub以外をgitlabとみなす.md')")"
assert_eq "find_duplicate_ddr_identifiers: 同一連番の別名2件を検出する" \
  ".claude/docs/ddr/0027-gh_glab-CLI不在時はMCPフォールバック経路へ機構的に誘導する.md	.claude/docs/ddr/0027-プロバイダ判定はremote-URLのホスト部でgithub以外をgitlabとみなす.md" \
  "$(printf '%s' "$one_dup" | cut -f2-)"
assert_eq "find_duplicate_ddr_identifiers: 出力の1列目は識別子" "0027" "$(printf '%s' "$one_dup" | cut -f1)"
assert_eq "find_duplicate_ddr_identifiers: 重複1件なら1行のみ" "1" "$(printf '%s\n' "$one_dup" | grep -c .)"

multi_dup="$(find_duplicate_ddr_identifiers "$(printf '%s\n' \
  '.claude/docs/ddr/0024-x.md' \
  '.claude/docs/ddr/0024-y.md' \
  '.claude/docs/ddr/0025-z.md' \
  '.claude/docs/ddr/0027-p.md' \
  '.claude/docs/ddr/0027-q.md')")"
assert_eq "find_duplicate_ddr_identifiers: 複数の識別子の重複を検出する" "2" "$(printf '%s\n' "$multi_dup" | grep -c .)"
assert_eq "find_duplicate_ddr_identifiers: 検出順は入力の出現順" \
  "$(printf '0024\n0027')" "$(printf '%s\n' "$multi_dup" | cut -f1)"

same_path="$(find_duplicate_ddr_identifiers "$(printf '%s\n' \
  '.claude/docs/ddr/0027-a.md' \
  '' \
  '.claude/docs/ddr/index.jsonl')")"
assert_eq "find_duplicate_ddr_identifiers: 空行・非DDRファイルは無視する" "" "$same_path"

dup_path="$(find_duplicate_ddr_identifiers "$(printf '%s\n' \
  '.claude/docs/ddr/0027-a.md' \
  '.claude/docs/ddr/0027-a.md')")"
assert_eq "find_duplicate_ddr_identifiers: 同一パスの重複入力は重複と見なさない" "" "$dup_path"

# --- ddr_identifier_to_reply: issue番号ベース（新方式。issue #133） ----------

REPLY=""
ddr_identifier_to_reply ".claude/docs/ddr/i133-01-DDR識別子はissue番号ベースにし連番採番をやめる.md"
assert_eq "ddr_identifier_to_reply: 新方式から i<issue>-<枝番> を取り出す" "i133-01" "$REPLY"

REPLY=""
ddr_identifier_to_reply ".claude/docs/ddr/i7-03-短いissue番号.md"
assert_eq "ddr_identifier_to_reply: issue番号は桁数を問わない" "i7-03" "$REPLY"

REPLY=""
ddr_identifier_to_reply ".claude/docs/ddr/i1234-12-四桁のissue番号.md"
assert_eq "ddr_identifier_to_reply: 4桁のissue番号でも連番と混同しない" "i1234-12" "$REPLY"

# 枝番はちょうど2桁。1桁・3桁の揺れを別の識別子として通すと、同じDDRが二重に採番されうる。
if ddr_identifier_to_reply ".claude/docs/ddr/i133-1-枝番が1桁.md"; then
  branch_one_digit_status=0
else
  branch_one_digit_status=1
fi
assert_eq "ddr_identifier_to_reply: 枝番1桁は対象外" "1" "$branch_one_digit_status"

REPLY="dirty"
if ddr_identifier_to_reply ".claude/docs/ddr/i133-001-枝番が3桁.md"; then
  branch_three_digit_status=0
else
  branch_three_digit_status=1
fi
assert_eq "ddr_identifier_to_reply: 枝番3桁は対象外" "1" "$branch_three_digit_status"
assert_eq "ddr_identifier_to_reply: 枝番3桁は先頭2桁だけを識別子にしない" "" "$REPLY"

if ddr_identifier_to_reply ".claude/docs/ddr/i133-タイトルのみ.md"; then
  no_branch_status=0
else
  no_branch_status=1
fi
assert_eq "ddr_identifier_to_reply: 枝番が無ければ対象外" "1" "$no_branch_status"

if ddr_identifier_to_reply ".claude/docs/ddr/I133-01-大文字接頭辞.md"; then
  upper_status=0
else
  upper_status=1
fi
assert_eq "ddr_identifier_to_reply: 大文字の接頭辞Iは対象外" "1" "$upper_status"

if ddr_identifier_to_reply ".claude/docs/ddr/issue133-01-別の接頭辞.md"; then
  other_prefix_status=0
else
  other_prefix_status=1
fi
assert_eq "ddr_identifier_to_reply: 接頭辞issueは対象外" "1" "$other_prefix_status"

# --- find_duplicate_ddr_identifiers: 新方式・新旧混在（issue #133） ----------

# 別issue同士は、同じ枝番を持っていても衝突しない（本方式が衝突を無くす仕組みそのもの）。
cross_issue="$(find_duplicate_ddr_identifiers "$(printf '%s\n' \
  '.claude/docs/ddr/i133-01-a.md' \
  '.claude/docs/ddr/i134-01-b.md' \
  '.claude/docs/ddr/i135-01-c.md')")"
assert_eq "find_duplicate_ddr_identifiers: 別issueなら同じ枝番でも重複しない" "" "$cross_issue"

# 同一issueを別ブランチで並行作業した場合だけは、新方式でも枝番がぶつかりうる。
same_issue="$(find_duplicate_ddr_identifiers "$(printf '%s\n' \
  '.claude/docs/ddr/i133-01-a.md' \
  '.claude/docs/ddr/i133-02-b.md' \
  '.claude/docs/ddr/i133-02-c.md')")"
assert_eq "find_duplicate_ddr_identifiers: 同一issue内の枝番重複は検出する" "i133-02" \
  "$(printf '%s' "$same_issue" | cut -f1)"
assert_eq "find_duplicate_ddr_identifiers: 同一issue内の枝番重複は2件を並べる" \
  ".claude/docs/ddr/i133-02-b.md	.claude/docs/ddr/i133-02-c.md" \
  "$(printf '%s' "$same_issue" | cut -f2-)"

# 既存の連番DDRと新方式が同じディレクトリに混在しても、互いを取り違えない。
mixed="$(find_duplicate_ddr_identifiers "$(printf '%s\n' \
  '.claude/docs/ddr/0058-a.md' \
  '.claude/docs/ddr/0059-b.md' \
  '.claude/docs/ddr/i133-01-c.md' \
  '.claude/docs/ddr/i133-02-d.md')")"
assert_eq "find_duplicate_ddr_identifiers: 新旧混在で重複が無ければ何も出さない" "" "$mixed"

mixed_dup="$(find_duplicate_ddr_identifiers "$(printf '%s\n' \
  '.claude/docs/ddr/0027-a.md' \
  '.claude/docs/ddr/0027-b.md' \
  '.claude/docs/ddr/i133-01-c.md' \
  '.claude/docs/ddr/i133-01-d.md')")"
assert_eq "find_duplicate_ddr_identifiers: 新旧それぞれの重複を両方検出する" \
  "$(printf '0027\ni133-01')" "$(printf '%s\n' "$mixed_dup" | cut -f1)"

# 4桁のissue番号を持つ新方式が、同じ数字の連番DDRと同一視されないこと。
digit_clash="$(find_duplicate_ddr_identifiers "$(printf '%s\n' \
  '.claude/docs/ddr/0133-連番の0133.md' \
  '.claude/docs/ddr/i133-01-issue133のDDR.md')")"
assert_eq "find_duplicate_ddr_identifiers: 0133 と i133-01 は別の識別子" "" "$digit_clash"


echo "passed=$passed failures=$failures"
[[ "$failures" -eq 0 ]]
