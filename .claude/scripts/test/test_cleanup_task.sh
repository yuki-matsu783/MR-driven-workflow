#!/usr/bin/env bash
# .claude/scripts/src/cleanup-task.sh の単体テスト（issue #28）。
# 外部コマンド呼び出しを伴わない純粋関数（is_safe_relative_dir / is_keep_path /
# is_handoff_template）と、埋め込みテンプレート HANDOFF_TEMPLATE の内容のみを対象とする。
# 実ファイルを削除する main は対象外（.claude/scripts/test/では実リポジトリを汚さない方針。
# test_check_base_conflicts.sh と同じ切り分け）。
# 規約: passed=N failures=N を標準出力へ出し、失敗があれば終了コード1
#       （.claude/rules/shell-script-style.md「テスト」）。
# 実行: bash .claude/scripts/test/test_cleanup_task.sh
set -euo pipefail

script_dir="${BASH_SOURCE[0]%/*}"
[[ "$script_dir" == "${BASH_SOURCE[0]}" ]] && script_dir="."
repo_root="$(cd "$script_dir/../../.." && pwd)"

# shellcheck source=../../../.claude/scripts/src/cleanup-task.sh
source "$repo_root/.claude/scripts/src/cleanup-task.sh"

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

# 終了コードは `if` の条件式で受ける（`"$(func; echo $?)"` は set -e 配下で空文字列になりうる。
# .claude/rules/shell-script-style.md「テスト」）。
status_of() {
  if "$@"; then
    printf '0'
  else
    printf '1'
  fi
}

# --- is_safe_relative_dir -------------------------------------------------

assert_eq "is_safe_relative_dir: 通常の相対パスは安全" "0" "$(status_of is_safe_relative_dir "plans")"
assert_eq "is_safe_relative_dir: ネストした相対パスも安全" "0" "$(status_of is_safe_relative_dir "docs/plans")"
assert_eq "is_safe_relative_dir: 空文字列は不正" "1" "$(status_of is_safe_relative_dir "")"
assert_eq "is_safe_relative_dir: カレント指定は不正" "1" "$(status_of is_safe_relative_dir ".")"
assert_eq "is_safe_relative_dir: 絶対パスは不正" "1" "$(status_of is_safe_relative_dir "/etc")"
assert_eq "is_safe_relative_dir: Windowsの絶対パスは不正" "1" "$(status_of is_safe_relative_dir "C:/tmp")"
assert_eq "is_safe_relative_dir: バックスラッシュ区切りは不正" "1" "$(status_of is_safe_relative_dir 'plans\sub')"
assert_eq "is_safe_relative_dir: 親ディレクトリそのものは不正" "1" "$(status_of is_safe_relative_dir "..")"
assert_eq "is_safe_relative_dir: 先頭の親参照は不正" "1" "$(status_of is_safe_relative_dir "../outside")"
assert_eq "is_safe_relative_dir: 途中の親参照は不正" "1" "$(status_of is_safe_relative_dir "plans/../../etc")"
assert_eq "is_safe_relative_dir: 末尾の親参照は不正" "1" "$(status_of is_safe_relative_dir "plans/..")"
# 「..」で始まるだけの通常のディレクトリ名を巻き込まないこと
assert_eq "is_safe_relative_dir: ..foo は親参照ではない" "0" "$(status_of is_safe_relative_dir "..foo")"

# --- is_keep_path ---------------------------------------------------------

assert_eq "is_keep_path: worklog/TEMPLATE.md は残す" "0" "$(status_of is_keep_path "worklog/TEMPLATE.md")"
assert_eq "is_keep_path: タスク固有のworklogは残さない" "1" "$(status_of is_keep_path "worklog/2026-08-19_計画_個別_push1.md")"
assert_eq "is_keep_path: 別ディレクトリの同名ファイルは残さない" "1" "$(status_of is_keep_path "plans/TEMPLATE.md")"
assert_eq "is_keep_path: 部分一致では残さない" "1" "$(status_of is_keep_path "worklog/TEMPLATE.md.bak")"
# REVIEW-POINTS.md は plans/ reports/ 配下にあっても残す（issue #77。ファイル名で判定する）
assert_eq "is_keep_path: plans/REVIEW-POINTS.md は残す" "0" "$(status_of is_keep_path "plans/REVIEW-POINTS.md")"
assert_eq "is_keep_path: reports/REVIEW-POINTS.md は残す" "0" "$(status_of is_keep_path "reports/REVIEW-POINTS.md")"
assert_eq "is_keep_path: サブディレクトリのREVIEW-POINTS.mdも残す" "0" "$(status_of is_keep_path "reports/sub/REVIEW-POINTS.md")"
assert_eq "is_keep_path: 名前が似ているだけのファイルは残さない" "1" "$(status_of is_keep_path "plans/REVIEW-POINTS.md.bak")"
assert_eq "is_keep_path: 接尾辞が一致するだけのファイルは残さない" "1" "$(status_of is_keep_path "plans/OLD-REVIEW-POINTS.md")"

# --- is_handoff_template --------------------------------------------------

assert_eq "is_handoff_template: テンプレートそのものは真" "0" "$(status_of is_handoff_template "$HANDOFF_TEMPLATE")"
# `$(<file)` は末尾改行をすべて落とすため、その差だけで「リセット必要」と誤判定しないこと
assert_eq "is_handoff_template: 末尾改行が無くても真" "0" "$(status_of is_handoff_template "${HANDOFF_TEMPLATE%$'\n'}")"
assert_eq "is_handoff_template: 末尾改行が増えても真" "0" "$(status_of is_handoff_template "${HANDOFF_TEMPLATE}"$'\n\n')"
assert_eq "is_handoff_template: 作業中の内容は偽" "1" "$(status_of is_handoff_template "${HANDOFF_TEMPLATE}進捗あり")"
assert_eq "is_handoff_template: 空文字列は偽" "1" "$(status_of is_handoff_template "")"

# --- HANDOFF_TEMPLATE の内容 ----------------------------------------------
# 見出し構成は .claude/rules/docs-workflow.md「ドキュメント運用」表の HANDOFF.md 行に対応する。
# 日本語を含む文字列は ${var:0:N} で切り出すとバイト単位で壊れるため、部分一致で確認する
# （.claude/rules/shell-script-style.md「テスト」）。
for heading in \
  "## フロー進捗状況" \
  "## やったこと" \
  "## 次にやること" \
  "## 判断を迷った内容" \
  "## 未解決の内容" \
  "## 守るべき条件・触ってはいけない範囲"
do
  if [[ "$HANDOFF_TEMPLATE" == *"$heading"$'\n'* ]]; then
    passed=$((passed + 1))
  else
    failures=$((failures + 1))
    echo "FAIL: HANDOFF_TEMPLATE に見出し「${heading}」が無い"
  fi
done

assert_eq "HANDOFF_TEMPLATE: frontmatterのtypeはhandoff" "0" \
  "$(status_of test "${HANDOFF_TEMPLATE#*$'type: handoff\n'}" != "$HANDOFF_TEMPLATE")"
assert_eq "HANDOFF_TEMPLATE: 先頭はfrontmatterの区切り" "---" "$(printf '%s' "$HANDOFF_TEMPLATE" | head -1)"
# 末尾改行はちょうど1つ（リセット後のHANDOFF.mdが余分な空行を持たないこと）。
# 日本語を含む文字列は ${var:0:N} / ${var: -N} で切り出すとバイト単位で壊れるため、
# 改行だけをパターンで見る（.claude/rules/shell-script-style.md「テスト」）。
assert_eq "HANDOFF_TEMPLATE: 末尾に改行がある" "0" \
  "$(status_of test "${HANDOFF_TEMPLATE: -1}" = $'\n')"
assert_eq "HANDOFF_TEMPLATE: 末尾の改行は2つ以上にならない" "1" \
  "$(status_of test "${HANDOFF_TEMPLATE: -2}" = $'\n\n')"
# 進捗表はリセット時点では持たない（次タスク着手時にissue-mr-flowが書き起こす）
assert_eq "HANDOFF_TEMPLATE: 進捗表の記号を含まない" "1" \
  "$(status_of test "${HANDOFF_TEMPLATE#*'[x]'}" != "$HANDOFF_TEMPLATE")"

echo "passed=${passed} failures=${failures}"
[[ "$failures" -eq 0 ]]
