#!/usr/bin/env bash
# .claude/scripts/src/update-handoff-progress.sh の単体テスト（issue #20）。
# 実ファイルI/Oを伴うため、簡略版HANDOFF.mdフィクスチャを一時ファイルへ都度作成し、
# スクリプトの関数を直接sourceして呼ぶ（外部プロセスとしての起動は行わない）。
# 規約: passed=N failures=N を標準出力へ出し、失敗があれば終了コード1
#       （.claude/rules/shell-script-style.md「テスト」。.claude/scripts/test/test_vcs_provider.sh を雛形にした）。
# 実行: bash .claude/scripts/test/test_update_handoff_progress.sh
set -euo pipefail

script_dir="${BASH_SOURCE[0]%/*}"
[[ "$script_dir" == "${BASH_SOURCE[0]}" ]] && script_dir="."
repo_root="$(cd "$script_dir/../../.." && pwd)"

# shellcheck source=../../../.claude/scripts/src/update-handoff-progress.sh
source "$repo_root/.claude/scripts/src/update-handoff-progress.sh"

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

assert_success() {
  local name="$1" status="$2"
  if [[ "$status" -eq 0 ]]; then
    passed=$((passed + 1))
  else
    failures=$((failures + 1))
    echo "FAIL: $name (expected success, got exit code $status)"
  fi
}

assert_failure() {
  local name="$1" status="$2"
  if [[ "$status" -ne 0 ]]; then
    passed=$((passed + 1))
  else
    failures=$((failures + 1))
    echo "FAIL: $name (expected failure, got exit code 0)"
  fi
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

# 簡略版HANDOFF.mdフィクスチャを新規作成する（ヘッダ4行＋単発ステップ・ループ範囲・
# スキップ対象を1つずつ含む最小限のテーブル）。
write_fixture() {
  local file="$1"
  cat >"$file" <<'FIXTURE'
- issue: （未着手）
- ブランチ: （未着手）
- PR: （未着手）
- push回数: 0

| 進捗 | flow-id | ステップ | 担当 |
|----|---|---|---|
| [] | 1-1 | 単発ステップ | 人間 |
| [] | 2-3 | ループ範囲1 | 人間 |
| [] | 2-4 | ループ範囲2 | エージェント |
| [] | 5-1 | スキップ対象 | エージェント |
FIXTURE
}

get_row() {
  local file="$1" flow_id="$2"
  grep -F "| $flow_id |" "$file"
}

get_header() {
  local file="$1" prefix="$2"
  # 先頭が "-" の検索パターンをgrepがオプションと誤認識しないよう "--" を挟む
  grep -F -- "- $prefix:" "$file"
}

# --- mark-done: 単発ステップ ------------------------------------------------

fixture="$TMP_DIR/handoff1.md"
write_fixture "$fixture"
cmd_mark_done "$fixture" "1-1"
assert_eq "mark-done: 単発ステップが[x]になる" \
  "| [x] | 1-1 | 単発ステップ | 人間 |" "$(get_row "$fixture" 1-1)"

# --- mark-done: ループ範囲は両方の行が更新される ----------------------------

fixture="$TMP_DIR/handoff2.md"
write_fixture "$fixture"
cmd_mark_done "$fixture" "2-3"
assert_eq "mark-done: ループ範囲2-3が[x]になる" \
  "| [x] | 2-3 | ループ範囲1 | 人間 |" "$(get_row "$fixture" 2-3)"
assert_eq "mark-done: 同じループ範囲の2-4も[x]になる" \
  "| [x] | 2-4 | ループ範囲2 | エージェント |" "$(get_row "$fixture" 2-4)"

# --- mark-done: 末尾が[]でない行に対してはエラー終了する --------------------

fixture="$TMP_DIR/handoff3.md"
write_fixture "$fixture"
cmd_mark_done "$fixture" "1-1"
set +e
cmd_mark_done "$fixture" "1-1" >/dev/null 2>&1
status=$?
set -e
assert_failure "mark-done: 完了済み行への再適用はエラー" "$status"

# --- mark-skip: 単発・複数指定 ----------------------------------------------

fixture="$TMP_DIR/handoff4.md"
write_fixture "$fixture"
cmd_mark_skip "$fixture" "5-1"
assert_eq "mark-skip: 単発ステップが[-]になる" \
  "| [-] | 5-1 | スキップ対象 | エージェント |" "$(get_row "$fixture" 5-1)"

fixture="$TMP_DIR/handoff5.md"
write_fixture "$fixture"
cmd_mark_skip "$fixture" "1-1" "5-1"
assert_eq "mark-skip: 複数指定その1(1-1)が[-]になる" \
  "| [-] | 1-1 | 単発ステップ | 人間 |" "$(get_row "$fixture" 1-1)"
assert_eq "mark-skip: 複数指定その2(5-1)が[-]になる" \
  "| [-] | 5-1 | スキップ対象 | エージェント |" "$(get_row "$fixture" 5-1)"

# --- add-round: 正常系（ループ範囲の全行に[]が追記される） ------------------

fixture="$TMP_DIR/handoff6.md"
write_fixture "$fixture"
cmd_mark_done "$fixture" "2-3"
cmd_add_round "$fixture" "2-3"
assert_eq "add-round: 2-3が[x][]になる" \
  "| [x][] | 2-3 | ループ範囲1 | 人間 |" "$(get_row "$fixture" 2-3)"
assert_eq "add-round: 同じ範囲の2-4も[x][]になる" \
  "| [x][] | 2-4 | ループ範囲2 | エージェント |" "$(get_row "$fixture" 2-4)"

# --- add-round: ループでないflow-idはエラー ----------------------------------

fixture="$TMP_DIR/handoff7.md"
write_fixture "$fixture"
set +e
cmd_add_round "$fixture" "1-1" >/dev/null 2>&1
status=$?
set -e
assert_failure "add-round: 単発ステップへの適用はエラー" "$status"

# --- add-round: 末尾が既に[]の行への適用はエラー ------------------------------

fixture="$TMP_DIR/handoff8.md"
write_fixture "$fixture"
set +e
cmd_add_round "$fixture" "2-3" >/dev/null 2>&1
status=$?
set -e
assert_failure "add-round: 前回往復が未完了(末尾[])な状態での適用はエラー" "$status"

# --- set-header: 指定項目のみ更新され、他は現状維持 --------------------------

fixture="$TMP_DIR/handoff9.md"
write_fixture "$fixture"
cmd_set_header "$fixture" --issue "#20 テストissue" --push-count "3"
assert_eq "set-header: issue行が更新される" \
  "- issue: #20 テストissue" "$(get_header "$fixture" issue)"
assert_eq "set-header: push回数行が更新される" \
  "- push回数: 3" "$(get_header "$fixture" push回数)"
assert_eq "set-header: 未指定のブランチ行は現状維持" \
  "- ブランチ: （未着手）" "$(get_header "$fixture" ブランチ)"
assert_eq "set-header: 未指定のPR行は現状維持" \
  "- PR: （未着手）" "$(get_header "$fixture" PR)"

echo "passed=$passed failures=$failures"
[ "$failures" -eq 0 ]
