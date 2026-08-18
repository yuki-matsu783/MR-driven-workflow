#!/usr/bin/env bash
# .claude/scripts/src/extract-frontmatter.sh の純粋ロジック（副作用の無い変換処理）の単体テスト。
# index.jsonl を実際に書き出す main() はテスト対象外（スクリプトをsourceして関数のみ再利用する）。
# 規約: passed=N failures=N を標準出力へ出し、失敗があれば終了コード1
#       （.claude/rules/shell-script-style.md「テスト」）。
# 実行: bash tests/test_extract_frontmatter.sh
set -euo pipefail

script_dir="${BASH_SOURCE[0]%/*}"
[[ "$script_dir" == "${BASH_SOURCE[0]}" ]] && script_dir="."
repo_root="$(cd "$script_dir/.." && pwd)"

# shellcheck source=../.claude/scripts/src/extract-frontmatter.sh
source "$repo_root/.claude/scripts/src/extract-frontmatter.sh"

passed=0
failures=0

fixture_dir="$(mktemp -d)"
cleanup_fixtures() {
  rm -rf "$fixture_dir"
}
trap cleanup_fixtures EXIT

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

# フィクスチャのmarkdownを作り、そのパスを返す
make_md() {
  local name="$1"
  local path="$fixture_dir/$name"
  mkdir -p "${path%/*}"
  cat >"$path"
  printf '%s' "$path"
}

# --- frontmatter_to_json -----------------------------------------------------

f="$(make_md scalar.md <<'MD'
---
title: サンプル
type: spec
---

本文
MD
)"
assert_eq "スカラーのみ" \
  '{"title":"サンプル","type":"spec"}' \
  "$(frontmatter_to_json "$f")"

f="$(make_md flow_array.md <<'MD'
---
title: X
tags: [alpha, beta, gamma]
---
MD
)"
assert_eq "フロー配列（順序保持）" \
  '{"title":"X","tags":["alpha","beta","gamma"]}' \
  "$(frontmatter_to_json "$f")"

f="$(make_md block_array.md <<'MD'
---
title: X
keywords:
  - one
  - two
  - three
type: rule
---
MD
)"
assert_eq "ブロック配列（順序保持・後続キーの位置）" \
  '{"title":"X","keywords":["one","two","three"],"type":"rule"}' \
  "$(frontmatter_to_json "$f")"

f="$(make_md empty_list.md <<'MD'
---
title: X
tags:
type: Y
---
MD
)"
assert_eq "要素0個のリストキーは空配列" \
  '{"title":"X","tags":[],"type":"Y"}' \
  "$(frontmatter_to_json "$f")"

f="$(make_md quoted.md <<'MD'
---
status: superseded
superseded_by: "0019"
---
MD
)"
assert_eq "ダブルクォート付きの値はクォートを外した文字列" \
  '{"status":"superseded","superseded_by":"0019"}' \
  "$(frontmatter_to_json "$f")"

f="$(make_md boolean.md <<'MD'
---
alwaysApply: true
disabled: false
name: X
---
MD
)"
assert_eq "true/falseはJSONの真偽値" \
  '{"alwaysApply":true,"disabled":false,"name":"X"}' \
  "$(frontmatter_to_json "$f")"

f="$(make_md no_frontmatter.md <<'MD'
# 見出しから始まるファイル

frontmatterを持たない。
MD
)"
assert_eq "frontmatter無しはnull" \
  'null' \
  "$(frontmatter_to_json "$f")"

# CRLF改行でもLFと同じ結果になること
crlf="$fixture_dir/crlf.md"
printf -- '---\r\ntitle: X\r\ntags: [a, b]\r\n---\r\n\r\n本文\r\n' >"$crlf"
assert_eq "CRLF改行でもLFと同じJSON" \
  '{"title":"X","tags":["a","b"]}' \
  "$(frontmatter_to_json "$crlf")"

# --- 中間表現（FM_ITEMS）----------------------------------------------------

parse_frontmatter_block <<'MD'
title: X
tags: [a, b]
MD
assert_eq "parse_frontmatter_blockの中間表現" \
  's title X A tags  a tags a a tags b' \
  "${FM_ITEMS[*]}"

assert_eq "frontmatter_items_to_jsonは中間表現からJSONを作る" \
  '{"title":"X","tags":["a","b"]}' \
  "$(frontmatter_items_to_json)"

# --- trim / unquote ----------------------------------------------------------

assert_eq "trimは前後の空白を落とす" "abc" "$(trim '  abc  ')"
assert_eq "unquoteは前後のダブルクォートを落とす" "abc" "$(unquote '"abc"')"

trim_unquote_to_reply '  "abc"  '
assert_eq "trim_unquote_to_replyはREPLYへ返す" "abc" "$REPLY"

unquote_to_reply '"0019"'
assert_eq "unquote_to_replyはREPLYへ返す" "0019" "$REPLY"

# --- resolve_repo_root -------------------------------------------------------

assert_eq "resolve_repo_rootはリポジトリルートを返す" \
  "$(cd "$repo_root" && pwd)" \
  "$(resolve_repo_root "$repo_root/.claude")"

# --- build_index_line --------------------------------------------------------

f="$(make_md line/sample.md <<'MD'
---
title: 行組み立ての確認
type: spec
tags: [x, y]
---
MD
)"
assert_eq "build_index_lineは4キーの1行JSONを返す" \
  '{"concept_id":"docs/sample","directory":"docs","frontmatter":{"title":"行組み立ての確認","type":"spec","tags":["x","y"]},"mtime":"2026-01-02T03:04:05"}' \
  "$(build_index_line "$f" "docs/sample" "docs" "2026-01-02T03:04:05")"

f="$(make_md line/plain.md <<'MD'
frontmatterを持たないファイル。
MD
)"
assert_eq "build_index_lineはfrontmatter無しでnullを埋める" \
  '{"concept_id":"docs/plain","directory":"docs","frontmatter":null,"mtime":"2026-01-02T03:04:05"}' \
  "$(build_index_line "$f" "docs/plain" "docs" "2026-01-02T03:04:05")"

# --- 結果 --------------------------------------------------------------------

echo "passed=$passed failures=$failures"
if [[ $failures -gt 0 ]]; then
  exit 1
fi
