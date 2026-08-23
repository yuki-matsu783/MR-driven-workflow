#!/usr/bin/env bash
# .claude/scripts/src/select-adversarial-findings.sh の単体テスト（issue #182）。
#
# 選別ロジック（blocker全件投稿・層単位追加・層追加しきい値10・ハードシーリング20・
# 層内切り捨て順序）を、境界ケースを含めて検証する。
#
# 選別ロジック本体は `select_adversarial_findings` を直接呼んで検証し、入力検証
# （空ファイル・findingsキー欠如・トップレベル配列等）は `main` を直接呼んで検証する。
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

# --- 確度優先のタイブレーク（パスの辞書順ではなく確度が先に効くことを確認） -----
# high側のパス接頭辞を "z"、medium側を "a" にする（辞書順だけならmedium=aが先に残る
# はずだが、確度が優先されるためhigh=z側が全件残らなければならない）。

majorHighZ="$(make_layer major 12 z high)"
majorMediumA="$(make_layer major 13 a medium)"
input="$(printf '%s\n%s\n' "$majorHighZ" "$majorMediumA" | concat_findings)"
result="$(run_select "$input")"
assert_eq "確度優先のタイブレーク: postedは20件" "20" "$(count_posted "$result")"
assert_eq "確度優先のタイブレーク: postedにconfidence=mediumはa00〜a07の8件のみ" \
  '["a00.sh","a01.sh","a02.sh","a03.sh","a04.sh","a05.sh","a06.sh","a07.sh"]' \
  "$(jq -c '[.posted.findings[] | select(.confidence == "medium") | .path] | sort' <<<"$result")"
assert_eq "確度優先のタイブレーク: reportedはconfidence=mediumの末尾5件(a08〜a12)" \
  '["a08.sh","a09.sh","a10.sh","a11.sh","a12.sh"]' \
  "$(jq -c '[.reported.findings[].path] | sort' <<<"$result")"

# --- 行番号タイブレーク（同一パス・同一確度で line 昇順に切る） -------------
# 同一パス・confidence=highのfindings 25件を、line降順（25→1）で入力する。
# sort_keyの第3要素（line）が効いていなければ、入力順のまま先頭25件が残ってしまう。

majorSamePath="$(jq -n -c '[range(25; 0; -1) | {
  path: "same.sh", line: ., severity: "major", confidence: "high",
  category: "x", title: "t", body: "b"
}]')"
input="$(printf '%s\n' "$majorSamePath" | concat_findings)"
result="$(run_select "$input")"
assert_eq "行番号タイブレーク: postedは20件" "20" "$(count_posted "$result")"
assert_eq "行番号タイブレーク: postedはline1〜20（昇順で残る）" \
  "[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20]" \
  "$(jq -c '[.posted.findings[].line] | sort' <<<"$result")"
assert_eq "行番号タイブレーク: reportedはline21〜25" \
  "[21,22,23,24,25]" \
  "$(jq -c '[.reported.findings[].line] | sort' <<<"$result")"

# --- minorがpostedへ入る経路（major→minorの順で層を追加する分岐そのものの確認） ---

major3="$(make_layer major 3 m)"
minor4="$(make_layer minor 4 n)"
input="$(printf '%s\n%s\n' "$major3" "$minor4" | concat_findings)"
result="$(run_select "$input")"
assert_eq "minorがpostedへ入る: posted=7（major3+minor4）" "7" "$(count_posted "$result")"
assert_eq "minorがpostedへ入る: reportedは0件" "0" "$(count_reported "$result")"

# --- ちょうど20件（ハードシーリングの境界。層を丸ごと追加できる） -----------

major20="$(make_layer major 20 m)"
input="$(printf '%s\n' "$major20" | concat_findings)"
result="$(run_select "$input")"
assert_eq "ちょうど20件: 全件投稿される" "20" "$(count_posted "$result")"
assert_eq "ちょうど20件: reportedは0件" "0" "$(count_reported "$result")"

# --- blockerがハードシーリングの枠を消費すること（blocker5+major15=ちょうど20件） ---

blocker5="$(make_layer blocker 5 b)"
major15="$(make_layer major 15 m)"
input="$(printf '%s\n%s\n' "$blocker5" "$major15" | concat_findings)"
result="$(run_select "$input")"
assert_eq "blocker5+major15=20件: 全件投稿される" "20" "$(count_posted "$result")"
assert_eq "blocker5+major15=20件: reportedは0件" "0" "$(count_reported "$result")"

# --- blockerがハードシーリングの枠を消費し、下位層が層内で切られる境界 -------
# blocker9件（全件投稿・打ち切り判定10件未満なのでmajorも追加対象）+ major15件。
# 20件の枠のうちblockerが9件を消費するため、majorは残り11件までしか入らない。

blocker9="$(make_layer blocker 9 b)"
major15b="$(make_layer major 15 m)"
input="$(printf '%s\n%s\n' "$blocker9" "$major15b" | concat_findings)"
result="$(run_select "$input")"
assert_eq "blocker9+major15: postedは20件（blocker9+major11）" "20" "$(count_posted "$result")"
assert_eq "blocker9+major15: reportedは4件（majorの残り）" "4" "$(count_reported "$result")"

# --- 防御: 上流の確度×重大度表で本来除外されるはずのnitが紛れ込んでも、
#     予算を消費せずreportedへ回る ------------------------------------------

blocker1b="$(make_layer blocker 1 b)"
nit3="$(make_layer nit 3 z)"
input="$(printf '%s\n%s\n' "$blocker1b" "$nit3" | concat_findings)"
result="$(run_select "$input")"
assert_eq "nit混入: blocker1件のみpostedへ" "1" "$(count_posted "$result")"
assert_eq "nit混入: nit3件はreportedへ" "3" "$(count_reported "$result")"

# --- main の入力検証 --------------------------------------------------------

if main "$tmp_dir/nonexistent.json" >/dev/null 2>&1; then
  status=0
else
  status=$?
fi
assert_eq "main: 存在しないファイルは終了コード1" "1" "$status"

empty_file="$tmp_dir/empty.json"
: > "$empty_file"
if main "$empty_file" >/dev/null 2>&1; then
  status=0
else
  status=$?
fi
assert_eq "main: 空ファイルは終了コード1" "1" "$status"

no_findings_key="$tmp_dir/no_findings_key.json"
printf '{}' > "$no_findings_key"
if main "$no_findings_key" >/dev/null 2>&1; then
  status=0
else
  status=$?
fi
assert_eq "main: findingsキーが無いJSONは終了コード1" "1" "$status"

array_input="$tmp_dir/array.json"
printf '[]' > "$array_input"
if main "$array_input" >/dev/null 2>&1; then
  status=0
else
  status=$?
fi
assert_eq "main: トップレベルが配列は終了コード1" "1" "$status"

valid_input="$tmp_dir/valid.json"
printf '{"findings":[]}' > "$valid_input"
if main "$valid_input" >/dev/null 2>&1; then
  status=0
else
  status=$?
fi
assert_eq "main: 有効な入力は終了コード0" "0" "$status"

echo "passed=$passed failures=$failures"
[ "$failures" -eq 0 ]
