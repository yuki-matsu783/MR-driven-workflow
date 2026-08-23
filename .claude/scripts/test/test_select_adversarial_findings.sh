#!/usr/bin/env bash
# .claude/scripts/src/select-adversarial-findings.sh の単体テスト（issue #182）。
#
# 選別ロジック（blocker全件投稿・層単位追加・層追加しきい値10・ハードシーリング20・
# 層内切り捨て順序）を、境界ケースを含めて検証する。
#
# `main` はファイル引数の検証しか行わないため対象外で、`select_adversarial_findings`
# （findings JSONファイルを受け取りjqへ委譲する関数）を直接呼ぶ。
# `if [ "${BASH_SOURCE[0]}" = "${0}" ]` のガードによりsourceしても実行されない
# （.claude/rules/shell-script-style.md「テスト」）。
#
# 規約: passed=N failures=N を標準出力へ出し、失敗があれば終了コード1。
# 実行: bash .claude/scripts/test/test_select_adversarial_findings.sh
set -euo pipefail

script_dir="${BASH_SOURCE[0]%/*}"
[[ "$script_dir" == "${BASH_SOURCE[0]}" ]] && script_dir="."
repo_root="$(cd "$script_dir/../../.." && pwd)"

# shellcheck source=../../../.claude/scripts/src/select-adversarial-findings.sh
source "$repo_root/.claude/scripts/src/select-adversarial-findings.sh"

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

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

# findings JSON文字列を一時ファイルへ書き出し、選別関数を実行して結果JSONを返す。
run_select() {
  local json="$1" file="$tmp_dir/input.json"
  printf '%s' "$json" > "$file"
  select_adversarial_findings "$file"
}

# 指定件数・重大度・確度のfindings配列を1回のjq呼び出しで生成する（テストフィクスチャ）。
# pathはゼロ埋めの連番にし、文字列としての辞書順と数値の昇順を一致させる
# （"m10" が "m2" より前に来るような文字列比較の罠を避ける）。
make_layer() {
  local severity="$1" count="$2" prefix="$3" confidence="${4:-high}"
  jq -n -c \
    --arg sev "$severity" --arg prefix "$prefix" --arg conf "$confidence" --argjson n "$count" '
    [range(0; $n) | {
      path: ($prefix + (("0" + (. | tostring))[-2:]) + ".sh"),
      line: 1,
      severity: $sev,
      confidence: $conf,
      category: "x",
      title: "t",
      body: "b"
    }]'
}

concat_findings() {
  jq -c -s '{findings: (map(.) | add // [])}'
}

count_posted() {
  jq -r '.posted.findings | length' <<<"$1"
}
count_reported() {
  jq -r '.reported.findings | length' <<<"$1"
}

# --- 0件 ------------------------------------------------------------------

result="$(run_select '{"findings":[]}')"
assert_eq "0件: postedが0件" "0" "$(count_posted "$result")"
assert_eq "0件: reportedが0件" "0" "$(count_reported "$result")"

# --- ちょうど10件（層追加のしきい値の境界。層を丸ごと追加できる） -------------

major10="$(make_layer major 10 m)"
input="$(printf '%s\n' "$major10" | concat_findings)"
result="$(run_select "$input")"
assert_eq "ちょうど10件: 全件投稿される" "10" "$(count_posted "$result")"
assert_eq "ちょうど10件: reportedは0件" "0" "$(count_reported "$result")"

# --- 層跨ぎ: blocker1 + major13 + minor5 → blocker+majorの14件を投稿 --------

blocker1="$(make_layer blocker 1 b)"
major13="$(make_layer major 13 m)"
minor5="$(make_layer minor 5 n)"
input="$(printf '%s\n%s\n%s\n' "$blocker1" "$major13" "$minor5" | concat_findings)"
result="$(run_select "$input")"
assert_eq "層跨ぎ: posted=14（blocker1+major13）" "14" "$(count_posted "$result")"
assert_eq "層跨ぎ: reported=5（minor全件）" "5" "$(count_reported "$result")"
assert_eq "層跨ぎ: reportedは全てminor" \
  '["minor","minor","minor","minor","minor"]' \
  "$(jq -c '[.reported.findings[].severity]' <<<"$result")"

# --- blocker単独で20件超（下位層は追加されない） ---------------------------

blocker25="$(make_layer blocker 25 b)"
major5="$(make_layer major 5 m)"
input="$(printf '%s\n%s\n' "$blocker25" "$major5" | concat_findings)"
result="$(run_select "$input")"
assert_eq "blocker単独20件超: blocker全25件が投稿される" "25" "$(count_posted "$result")"
assert_eq "blocker単独20件超: majorは全件reportedへ" "5" "$(count_reported "$result")"
assert_eq "blocker単独20件超: postedは全てblocker" \
  "0" \
  "$(jq -r '[.posted.findings[].severity] | map(select(. != "blocker")) | length' <<<"$result")"

# --- 20件シーリングを跨ぐ層の層内切り捨て順序 -------------------------------
# major: confidence=high 12件 + confidence=medium 13件 = 25件（層追加は成立するが
# 20件シーリングを超えるため層内で切る）。確度降順→パス昇順の順で20件まで残るはずなので、
# high全12件 + medium先頭8件（m00〜m07）が posted、medium末尾5件（m08〜m12）が reported。

majorHigh="$(make_layer major 12 h high)"
majorMedium="$(make_layer major 13 m medium)"
input="$(printf '%s\n%s\n' "$majorHigh" "$majorMedium" | concat_findings)"
result="$(run_select "$input")"
assert_eq "ハードシーリング跨ぎ: postedは20件" "20" "$(count_posted "$result")"
assert_eq "ハードシーリング跨ぎ: reportedは5件" "5" "$(count_reported "$result")"
assert_eq "ハードシーリング跨ぎ: reportedはconfidence=mediumの末尾5件（パス昇順で切る）" \
  '["m08.sh","m09.sh","m10.sh","m11.sh","m12.sh"]' \
  "$(jq -c '[.reported.findings[].path] | sort' <<<"$result")"
assert_eq "ハードシーリング跨ぎ: postedにconfidence=lowは含まれない" \
  "0" \
  "$(jq -r '[.posted.findings[] | select(.confidence == "low")] | length' <<<"$result")"

# --- 防御: 上流の確度×重大度表で本来除外されるはずのnitが紛れ込んでも、
#     予算を消費せずreportedへ回る ------------------------------------------

blocker1b="$(make_layer blocker 1 b)"
nit3="$(make_layer nit 3 z)"
input="$(printf '%s\n%s\n' "$blocker1b" "$nit3" | concat_findings)"
result="$(run_select "$input")"
assert_eq "nit混入: blocker1件のみpostedへ" "1" "$(count_posted "$result")"
assert_eq "nit混入: nit3件はreportedへ" "3" "$(count_reported "$result")"

echo "passed=$passed failures=$failures"
[ "$failures" -eq 0 ]
