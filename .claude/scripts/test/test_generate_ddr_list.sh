#!/usr/bin/env bash
# .claude/scripts/src/generate-ddr-list.sh の単体テスト。issue #135。
#
# 純粋関数（注記・リンク行の組み立て、クォート外し、リンク接頭辞の算出）に加え、
# mktempで作った一時的なgitリポジトリを対象に `main` の生成・置換動作も確認する
# （このリポジトリ自身を対象にすると、マーカー不在・DDR 0件といった異常系を作れないため）。
#
# 最後に**このリポジトリ自身へ `--check` を実行**し、コミット済みのDDR一覧が
# 生成結果と一致していることを検証する（issue #135 の受け入れ条件）。
#
# 規約: passed=N failures=N を標準出力へ出し、失敗があれば終了コード1。
# 実行: bash .claude/scripts/test/test_generate_ddr_list.sh
set -euo pipefail

script_dir="${BASH_SOURCE[0]%/*}"
[[ "$script_dir" == "${BASH_SOURCE[0]}" ]] && script_dir="."
repo_root="$(cd "$script_dir/../../.." && pwd)"
target="$repo_root/.claude/scripts/src/generate-ddr-list.sh"

# shellcheck source=../../../.claude/scripts/src/generate-ddr-list.sh
source "$target"

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

assert_contains() {
  local name="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    passed=$((passed + 1))
  else
    failures=$((failures + 1))
    echo "FAIL: $name"
    echo "  needle  : $needle"
    echo "  haystack: $haystack"
  fi
}

# --- gdl_annotation_to_reply ---------------------------------------------------------

gdl_annotation_to_reply '' '' ''
assert_eq "annotation: 注記が無ければ空" '' "$REPLY"

gdl_annotation_to_reply 'active' '' ''
assert_eq "annotation: status:active は注記を出さない" '' "$REPLY"

gdl_annotation_to_reply 'superseded' '0019' ''
assert_eq "annotation: supersededは置き換え先を含む" \
  ' ── **`status: superseded`（0019により置き換え）**' "$REPLY"

# superseded_by は「条件付き必須」だが、欠けていても一覧の生成自体は止めない
gdl_annotation_to_reply 'superseded' '' ''
assert_eq "annotation: superseded_byが無くても出力する" \
  ' ── **`status: superseded`**' "$REPLY"

gdl_annotation_to_reply 'deprecated' '' ''
assert_eq "annotation: deprecated" ' ── **`status: deprecated`**' "$REPLY"

gdl_annotation_to_reply '' '' 'ただし例外がある'
assert_eq "annotation: noteだけなら全角括弧で囲む" '（ただし例外がある）' "$REPLY"

# 順序を固定しておかないと、片方を足したときに一覧全体が差分になる
gdl_annotation_to_reply 'superseded' '0019' '補足'
assert_eq "annotation: status由来が先でnoteが後" \
  ' ── **`status: superseded`（0019により置き換え）**（補足）' "$REPLY"

# 未知のstatusを黙って捨てると、無効化されたDDRが有効に見えてしまう
gdl_annotation_to_reply 'draft' '' ''
assert_eq "annotation: 未知のstatusもそのまま出す" ' ── **`status: draft`**' "$REPLY"

# --- gdl_link_target_to_reply --------------------------------------------------------

gdl_link_target_to_reply 'ddr/0003-通常のファイル名.md'
assert_eq "link_target: 通常のファイル名はそのまま" 'ddr/0003-通常のファイル名.md' "$REPLY"

# 実在例: 0009 のファイル名は "git checkout復元" を含む。空白を含む宛先は
# CommonMark（GitHubのcmark-gfm）ではリンクとして解釈されず、地の文になる
gdl_link_target_to_reply 'ddr/0009-git checkout復元.md'
assert_eq "link_target: 空白を含む宛先は<>で囲む" '<ddr/0009-git checkout復元.md>' "$REPLY"

gdl_link_target_to_reply 'ddr/0010-括弧(あり).md'
assert_eq "link_target: 括弧を含む宛先は<>で囲む" '<ddr/0010-括弧(あり).md>' "$REPLY"

# --- gdl_list_line_to_reply ----------------------------------------------------------

gdl_list_line_to_reply '0003-x.md' 'ddr/' '' '' ''
assert_eq "list_line: 注記なし" '- [0003-x.md](ddr/0003-x.md)' "$REPLY"

gdl_list_line_to_reply '0009-y.md' 'ddr/' 'superseded' '0019' ''
assert_eq "list_line: superseded注記つき" \
  '- [0009-y.md](ddr/0009-y.md) ── **`status: superseded`（0019により置き換え）**' "$REPLY"

gdl_list_line_to_reply '0022-z.md' 'ddr/' '' '' '詳細は0054'
assert_eq "list_line: note注記つき" '- [0022-z.md](ddr/0022-z.md)（詳細は0054）' "$REPLY"

gdl_list_line_to_reply '0003-x.md' '' '' '' ''
assert_eq "list_line: 接頭辞が空でも壊れない" '- [0003-x.md](0003-x.md)' "$REPLY"

# --- gdl_unquote_to_reply ------------------------------------------------------------

gdl_unquote_to_reply '"0019"'
assert_eq "unquote: ダブルクォート" '0019' "$REPLY"

gdl_unquote_to_reply "'0019'"
assert_eq "unquote: シングルクォート" '0019' "$REPLY"

gdl_unquote_to_reply 'superseded'
assert_eq "unquote: クォート無しはそのまま" 'superseded' "$REPLY"

gdl_unquote_to_reply ''
assert_eq "unquote: 空文字列" '' "$REPLY"

# 片側だけのクォートを外すと、値が1文字欠ける形で壊れる
gdl_unquote_to_reply '"0019'
assert_eq "unquote: 片側だけのクォートは外さない" '"0019' "$REPLY"

gdl_unquote_to_reply '"'
assert_eq "unquote: 1文字のクォートは外さない" '"' "$REPLY"

# 値の中にあるクォートまで外さない（外側の1組だけを対象にする）
gdl_unquote_to_reply '"a"b"'
assert_eq "unquote: 外側の1組だけを外す" 'a"b' "$REPLY"

# --- gdl_link_prefix_to_reply --------------------------------------------------------

gdl_link_prefix_to_reply '.claude/docs/README.md' '.claude/docs/ddr'
assert_eq "link_prefix: 直下のサブディレクトリ" 'ddr/' "$REPLY"

gdl_link_prefix_to_reply '.claude/docs/README.md' '.claude/docs/ddr/sub'
assert_eq "link_prefix: 2階層下" 'ddr/sub/' "$REPLY"

gdl_link_prefix_to_reply 'README.md' 'docs/ddr'
assert_eq "link_prefix: ルート直下のreadme" 'docs/ddr/' "$REPLY"

gdl_link_prefix_to_reply 'ddr/README.md' 'ddr'
assert_eq "link_prefix: 同じディレクトリなら空" '' "$REPLY"

# 誤った相対パスを黙って出さず、--link-prefix の明示を促す（呼び出し側でエラーにする）
if gdl_link_prefix_to_reply '.claude/docs/README.md' 'other/ddr' 2>/dev/null; then
  prefix_status=0
else
  prefix_status=1
fi
assert_eq "link_prefix: 親子でない配置は1を返す" '1' "$prefix_status"

# --- main（一時gitリポジトリでの結合確認） -------------------------------------------

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

# 擬似リポジトリを組み立てる。$1=リポジトリのパス
make_fixture_repo() {
  local root="$1"
  mkdir -p "$root/docs/ddr"
  git -C "$root" init -q
  cat > "$root/.mrworkflow.json" <<'JSON'
{"ddrDirs": ["docs/ddr"]}
JSON

  # 注記なし
  cat > "$root/docs/ddr/0001-最初の決定.md" <<'MD'
---
title: 0001. 最初の決定
type: ddr
description: ふつうのDDR
---

# 0001. 最初の決定

本文中に status: これは本文なので拾ってはいけない と書いてある。
MD

  # status/superseded_by 由来の注記
  cat > "$root/docs/ddr/0002-置き換えられた決定.md" <<'MD'
---
title: 0002. 置き換えられた決定
type: ddr
status: superseded
superseded_by: "0003"
description: 置き換えられたDDR
---

# 0002. 置き換えられた決定
MD

  # note 由来の注記。status も superseded_by も**空**で、区切り文字の畳み込みが
  # 起きると note が status の位置へずれ込む（issue #135 で実際に踏んだ回帰）
  cat > "$root/docs/ddr/0003-注記つきの決定.md" <<'MD'
---
title: 0003. 注記つきの決定
type: ddr
description: 注記つきのDDR
note: 'あとで一部が変わった。詳細は0004'
---

# 0003. 注記つきの決定
MD

  # frontmatterを持たないファイル（列挙からも組み立てからも落ちないこと）
  cat > "$root/docs/ddr/0004-frontmatterなし.md" <<'MD'
# 0004. frontmatterなし

frontmatterが無いDDR。
MD

  cat > "$root/docs/README.md" <<'MD'
# 目次

## ddr

<!-- BEGIN GENERATED: ddr-list -->
- [古い内容.md](ddr/古い内容.md)
<!-- END GENERATED: ddr-list -->

## あとがき

この節は残る。
MD
}

fixture="$tmp_root/repo"
make_fixture_repo "$fixture"

print_out="$(cd "$fixture" && bash "$target" --print)"
expected_print='- [0001-最初の決定.md](ddr/0001-最初の決定.md)
- [0002-置き換えられた決定.md](ddr/0002-置き換えられた決定.md) ── **`status: superseded`（0003により置き換え）**
- [0003-注記つきの決定.md](ddr/0003-注記つきの決定.md)（あとで一部が変わった。詳細は0004）
- [0004-frontmatterなし.md](ddr/0004-frontmatterなし.md)'
assert_eq "main --print: 4件を番号順に組み立てる" "$expected_print" "$print_out"

# 差分がある状態では --check が終了コード2（＝失敗の1とは区別する）
if (cd "$fixture" && bash "$target" --check >/dev/null 2>&1); then
  check_stale_status=0
else
  check_stale_status=$?
fi
assert_eq "main --check: 一覧が古ければ終了コード2" '2' "$check_stale_status"

# --check は書き換えない
assert_contains "main --check: READMEを書き換えない" \
  "$(cat "$fixture/docs/README.md")" '- [古い内容.md](ddr/古い内容.md)'

write_json="$(cd "$fixture" && bash "$target" 2>/dev/null)"
assert_eq "main: 書き換えたらchanged=true" 'true' "$(printf '%s' "$write_json" | jq -r '.changed')"
assert_eq "main: 書き換えたらwritten=true" 'true' "$(printf '%s' "$write_json" | jq -r '.written')"
assert_eq "main: 件数を返す" '4' "$(printf '%s' "$write_json" | jq -r '.count')"
assert_eq "main: link_prefixを導出する" 'ddr/' "$(printf '%s' "$write_json" | jq -r '.linkPrefix')"

readme_after="$(cat "$fixture/docs/README.md")"
assert_contains "main: 生成した行が入る" "$readme_after" '- [0002-置き換えられた決定.md](ddr/0002-置き換えられた決定.md) ── **`status: superseded`（0003により置き換え）**'
assert_contains "main: マーカーは残る" "$readme_after" '<!-- BEGIN GENERATED: ddr-list -->'
assert_contains "main: 終了マーカーも残る" "$readme_after" '<!-- END GENERATED: ddr-list -->'
assert_contains "main: マーカー外の見出しを消さない" "$readme_after" '## あとがき'
assert_contains "main: マーカー外の地の文を消さない" "$readme_after" 'この節は残る。'
assert_eq "main: 古い行は消える" '' \
  "$(printf '%s' "$readme_after" | grep -F '古い内容.md' || true)"

# 2回目は冪等（差分が出ない）
if (cd "$fixture" && bash "$target" --check >/dev/null 2>&1); then
  check_fresh_status=0
else
  check_fresh_status=$?
fi
assert_eq "main --check: 生成直後は終了コード0" '0' "$check_fresh_status"

second_json="$(cd "$fixture" && bash "$target" 2>/dev/null)"
assert_eq "main: 2回目はchanged=false" 'false' "$(printf '%s' "$second_json" | jq -r '.changed')"

# 異常系: マーカーが無ければ、区間を推測せずエラーで止まる
no_marker="$tmp_root/no-marker"
make_fixture_repo "$no_marker"
printf '# 目次\n\nマーカーの無いREADME。\n' > "$no_marker/docs/README.md"
if (cd "$no_marker" && bash "$target" >/dev/null 2>&1); then
  no_marker_status=0
else
  no_marker_status=$?
fi
assert_eq "main: マーカーが無ければ終了コード1" '1' "$no_marker_status"
assert_contains "main: マーカーが無ければREADMEを変えない" \
  "$(cat "$no_marker/docs/README.md")" 'マーカーの無いREADME。'

# 異常系: DDRが1件も無ければエラー（空の一覧で既存を消し飛ばさない）
empty_repo="$tmp_root/empty"
make_fixture_repo "$empty_repo"
rm -f "$empty_repo"/docs/ddr/*.md
if (cd "$empty_repo" && bash "$target" >/dev/null 2>&1); then
  empty_status=0
else
  empty_status=$?
fi
assert_eq "main: DDRが0件なら終了コード1" '1' "$empty_status"
assert_contains "main: DDRが0件ならREADMEを変えない" \
  "$(cat "$empty_repo/docs/README.md")" '- [古い内容.md](ddr/古い内容.md)'

# 異常系: 排他のオプション
if (cd "$fixture" && bash "$target" --check --print >/dev/null 2>&1); then
  both_status=0
else
  both_status=$?
fi
assert_eq "main: --checkと--printの併用は終了コード1" '1' "$both_status"

# --- このリポジトリ自身に対する検証（受け入れ条件） -----------------------------------

if (cd "$repo_root" && bash "$target" --check >/dev/null 2>&1); then
  self_check_status=0
else
  self_check_status=$?
fi
assert_eq "自己検証: コミット済みのDDR一覧が生成結果と一致する" '0' "$self_check_status"

echo "passed=$passed failures=$failures"
[ "$failures" -eq 0 ]
