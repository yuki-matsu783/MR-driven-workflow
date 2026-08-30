#!/usr/bin/env bash
# レポート用HTMLビューテンプレート（.claude/skills/issue-mr-flow/assets/reports-*.template.html）の
# 不変条件を検査する（issue #203）。
#
# DDR i0203-01 が「<style> を除いた残りが4本でバイト単位に完全一致する」を不変条件として宣言して
# いるが、共有パーツと生成スクリプトはリポジトリに置いていない（作業用の一時物だった）。
# 冒頭コメントを直すたびに人手で4ファイルへ同じ差分を当てる運用であり、1本でも取りこぼすと
# 不変条件は無言で壊れる。**宣言した不変条件は機械で守る。**
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../../.." && pwd)"
assets_dir="$repo_root/.claude/skills/issue-mr-flow/assets"

passed=0
failures=0

assert_eq() { # $1=説明 $2=期待値 $3=実際値
  if [ "$2" = "$3" ]; then
    passed=$((passed + 1))
  else
    failures=$((failures + 1))
    printf 'FAIL: %s\n  期待: %s\n  実際: %s\n' "$1" "$2" "$3"
  fi
}

# 対象は新4本のみ。現行 reports.template.html は節構成が異なるため対象外（DDR i0203-01）。
designs=(clean neobrutal mono paper)

# --- T1: 4本すべてが存在する ---
present=0
for d in "${designs[@]}"; do
  [ -f "$assets_dir/reports-$d.template.html" ] && present=$((present + 1))
done
assert_eq "新4本がすべて存在する" "4" "$present"

if [ "$present" -ne 4 ]; then
  printf 'passed=%s failures=%s\n' "$passed" "$failures"
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for d in "${designs[@]}"; do
  sed '/^<style>$/,/^<\/style>$/d' "$assets_dir/reports-$d.template.html" > "$tmp/$d.nostyle"
done

# --- T2: 空振りガード（<style> の除去が効きすぎて中身が消えていないか） ---
# これが無いと、抽出が全滅したときに「4本とも空で一致」が合格として通る。
short=0
for d in "${designs[@]}"; do
  [ "$(wc -l < "$tmp/$d.nostyle")" -lt 100 ] && short=$((short + 1))
done
assert_eq "抽出結果がどれも100行以上ある（空振りガード）" "0" "$short"

# --- T3: <style> を除いた残りが4本で完全一致する（本体の不変条件） ---
kinds="$(md5sum "$tmp"/*.nostyle | awk '{print $1}' | sort -u | wc -l)"
assert_eq "<style>を除いた残りのハッシュが1種類" "1" "$kinds"

# --- T4: 各テンプレートの <style> はちょうど1つ（検査6と同じ条件） ---
# **コメントを先に除いてから数える**（一般則1）。除かないと、冒頭コメントの地の文で
# <style> に触れているだけの箇所を数えてしまう（このテンプレート自身がそうである）。
# 行頭に固定する形（^<style>）はインデントされた重複を取りこぼすため使わない。
count_style_to_reply() { # $1=ファイル $2=open|close → REPLY へ件数
  local nc
  nc="$(perl -0pe 's/<!--.*?-->//gs' "$1")"
  if [ "$2" = "open" ]; then
    REPLY="$(printf '%s' "$nc" | grep -c '<style' || true)"
  else
    REPLY="$(printf '%s' "$nc" | grep -c '</style>' || true)"
  fi
}

bad_style=0
for d in "${designs[@]}"; do
  f="$assets_dir/reports-$d.template.html"
  count_style_to_reply "$f" open;  o="$REPLY"
  count_style_to_reply "$f" close; c="$REPLY"
  { [ "$o" = 1 ] && [ "$c" = 1 ]; } || bad_style=$((bad_style + 1))
done
assert_eq "各テンプレートの<style>がちょうど1つ" "0" "$bad_style"

# --- T4b: 負のコントロール（T4が重複を本当に検出できるか） ---
# インデントされた <style> を1つ足したコピーで open=2 になること。
# 行頭固定の検査ならここで見逃す（この検査が必要な理由がそのまま示せる）。
cp "$assets_dir/reports-clean.template.html" "$tmp/dup-style.html"
printf '  <style>\n  </style>\n' >> "$tmp/dup-style.html"
count_style_to_reply "$tmp/dup-style.html" open
assert_eq "<style>を1つ足すとopen=2になる（負のコントロール）" "2" "$REPLY"

# --- T5: 負のコントロール（T3の検査が実際に差分を検出できるか） ---
# 「ハッシュが1種類」は、抽出が壊れていても同じく成立しうる。意図的に1本だけ変えて確かめる。
cp "$tmp/clean.nostyle" "$tmp/broken.nostyle"
printf '<!-- 意図的に壊した行 -->\n' >> "$tmp/broken.nostyle"
broken_kinds="$(md5sum "$tmp/neobrutal.nostyle" "$tmp/mono.nostyle" "$tmp/paper.nostyle" "$tmp/broken.nostyle" \
  | awk '{print $1}' | sort -u | wc -l)"
assert_eq "1本を壊すとハッシュが2種類になる（負のコントロール）" "2" "$broken_kinds"

# --- T6: 外部依存を持たない（検査4・5。合格条件は0件） ---
dep=0
for d in "${designs[@]}"; do
  f="$assets_dir/reports-$d.template.html"
  n1="$(grep -cE "(src|href)=['\"]?(https?:)?//" "$f" || true)"
  n2="$(grep -cE "(url\(|@import[[:space:]]+)['\"]?(https?:)?//" "$f" || true)"
  dep=$((dep + n1 + n2))
done
assert_eq "外部依存が0件" "0" "$dep"

# --- T7: テンプレート本体はプレースホルダを持つ（成果物とは逆の合格条件） ---
no_placeholder=0
for d in "${designs[@]}"; do
  [ "$(grep -c '<!-- ここに書く' "$assets_dir/reports-$d.template.html")" -eq 0 ] && no_placeholder=$((no_placeholder + 1))
done
assert_eq "テンプレート本体がプレースホルダを持つ" "0" "$no_placeholder"

printf 'passed=%s failures=%s\n' "$passed" "$failures"
[ "$failures" -eq 0 ] || exit 1
