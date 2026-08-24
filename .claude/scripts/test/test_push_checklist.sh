#!/usr/bin/env bash
# .claude/scripts/src/push-checklist.sh の単体テスト（issue #17）。
# 2部構成。
#   1. 外部コマンド呼び出しを伴わない純粋関数（branch_slug_to_reply / split_tsv_line /
#      normalize_log_to_reply / checklist_number_to_reply / max_checklist_to_reply /
#      verify_stream / item_text_for）。
#   2. サブコマンドの結合テスト。**実リポジトリは汚さない**——`mktemp -d` + `git init` の
#      使い捨てリポジトリの中で実プロセスとして起動する（test_cleanup_task.sh と同じ切り分け）。
#      公開済み判定は `git update-ref refs/remotes/origin/main` でリモート追跡refを直接作る
#      （実際にリモートへ送らずに `git branch --remotes --contains HEAD` を成立させる）。
# 規約: passed=N failures=N を標準出力へ出し、失敗があれば終了コード1
#       （.claude/rules/shell-script-style.md「テスト」）。
# 実行: bash .claude/scripts/test/test_push_checklist.sh
set -euo pipefail

script_dir="${BASH_SOURCE[0]%/*}"
[[ "$script_dir" == "${BASH_SOURCE[0]}" ]] && script_dir="."
repo_root="$(cd "$script_dir/../../.." && pwd)"
pc_script="$repo_root/.claude/scripts/src/push-checklist.sh"

# shellcheck source=../src/push-checklist.sh
source "$pc_script"

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
    echo "  「$needle」を含むはずが含まれていない"
    echo "  actual  : $haystack"
  fi
}

# 終了コードは `if` の条件式で受ける（`"$(func; echo $?)"` は set -e 配下で空文字列に
# なりうる。.claude/rules/shell-script-style.md「テスト」）。
status_of() {
  if "$@"; then
    printf '0'
  else
    printf '1'
  fi
}

# --- 1. 純粋関数 ------------------------------------------------------------

# branch_slug_to_reply
branch_slug_to_reply 'claude/hook-implementation-17-vjhppj'
assert_eq "branch_slug: スラッシュはアンダースコアへ" 'claude_hook-implementation-17-vjhppj' "$REPLY"
branch_slug_to_reply 'feature-17-push前チェックリスト'
assert_eq "branch_slug: 非ASCIIは1バイトずつアンダースコアへ" \
  "feature-17-push$(printf '_%.0s' $(seq 1 $(printf '前チェックリスト' | wc -c)))" "$REPLY"
branch_slug_to_reply ''
assert_eq "branch_slug: 空文字列は空文字列" '' "$REPLY"

# split_tsv_line: 行末タブを落とさない（IFS=$'\t' read -a との違いがここに出る）
split_tsv_line "$(printf 'a\tb\tpending\t')"
assert_eq "split_tsv_line: 行末タブでも4フィールド" "4" "${#TSV_FIELDS[@]}"
assert_eq "split_tsv_line: 4列目は空文字列" "" "${TSV_FIELDS[3]}"
split_tsv_line "$(printf 'a\t\t\t')"
assert_eq "split_tsv_line: 連続タブを畳まない" "4" "${#TSV_FIELDS[@]}"
split_tsv_line 'a'
assert_eq "split_tsv_line: タブが無ければ1フィールド" "1" "${#TSV_FIELDS[@]}"
split_tsv_line "$(printf 'a\tb\tc')"
assert_eq "split_tsv_line: 3フィールドは3のまま" "3" "${#TSV_FIELDS[@]}"

# normalize_log_to_reply
normalize_log_to_reply "$(printf '  a\tb\nc\r  ')"
assert_eq "normalize_log: タブ・改行・CRを空白へ潰し前後を刈る" 'a b c' "$REPLY"
normalize_log_to_reply '   '
assert_eq "normalize_log: 空白だけなら空になる" '' "$REPLY"

# checklist_number_to_reply
assert_eq "checklist_number: 正常なファイル名" "0" \
  "$(status_of checklist_number_to_reply '20260823_claude_br_push3_checklist.tsv' 'claude_br')"
checklist_number_to_reply '20260823_claude_br_push3_checklist.tsv' 'claude_br'
assert_eq "checklist_number: 番号を取り出す" "3" "$REPLY"
assert_eq "checklist_number: 別ブランチのものは弾く" "1" \
  "$(status_of checklist_number_to_reply '20260823_other_push3_checklist.tsv' 'claude_br')"
assert_eq "checklist_number: 拡張子が違えば弾く" "1" \
  "$(status_of checklist_number_to_reply '20260823_claude_br_push3.tsv' 'claude_br')"
assert_eq "checklist_number: _push が無ければ弾く" "1" \
  "$(status_of checklist_number_to_reply '20260823_claude_br_checklist.tsv' 'claude_br')"
assert_eq "checklist_number: 番号が数字でなければ弾く" "1" \
  "$(status_of checklist_number_to_reply '20260823_claude_br_pushX_checklist.tsv' 'claude_br')"
# ブランチ名自体が `push` で終わる場合も取り違えない
checklist_number_to_reply '20260823_feature-1-push_push2_checklist.tsv' 'feature-1-push'
assert_eq "checklist_number: ブランチ名がpushで終わっても正しく分解する" "2" "$REPLY"
# パス付きでも動く
checklist_number_to_reply 'wip/worklogs/20260823_claude_br_push7_checklist.tsv' 'claude_br'
assert_eq "checklist_number: パス付きでも番号を取り出す" "7" "$REPLY"

# **接尾辞一致にしないこと**（issue #17 フェーズ3の敵対的レビュー2回目で指摘した反例）。
# `claude/hook-impl-17` と `hook-impl-17` のように、片方のスラッグがもう片方の `_` 区切りの
# 接尾辞になっている組では、別ブランチのチェックリストを自分のものとして採用してしまう。
assert_eq "checklist_number: スラッグが別スラッグの接尾辞でも弾く（接頭辞付きブランチの反例）" "1" \
  "$(status_of checklist_number_to_reply '20260823_claude_hook-impl-17_push3_checklist.tsv' 'hook-impl-17')"
assert_eq "checklist_number: 逆向き（自分のほうが長い）も弾く" "1" \
  "$(status_of checklist_number_to_reply '20260823_hook-impl-17_push3_checklist.tsv' 'claude_hook-impl-17')"
assert_eq "checklist_number: 完全一致は通す" "0" \
  "$(status_of checklist_number_to_reply '20260823_claude_hook-impl-17_push3_checklist.tsv' 'claude_hook-impl-17')"
assert_eq "checklist_number: 日付が2フィールドに割れていたら弾く" "1" \
  "$(status_of checklist_number_to_reply '2026_0823_br_push3_checklist.tsv' 'br')"

# max_checklist_to_reply
max_checklist_to_reply "$(printf '%s\n' \
  'w/20260823_br_push2_checklist.tsv' \
  'w/20260823_br_push10_checklist.tsv' \
  'w/20260823_br_push9_checklist.tsv')" 'br'
assert_eq "max_checklist: 10 > 9 を数値として比較する" "10" "$REPLY_N"
assert_eq "max_checklist: 最大のパスを返す" 'w/20260823_br_push10_checklist.tsv' "$REPLY"
max_checklist_to_reply '' 'br'
assert_eq "max_checklist: 空一覧ならパスは空" '' "$REPLY"
assert_eq "max_checklist: 空一覧なら番号は0" "0" "$REPLY_N"
# 08 を8進数と読まない
max_checklist_to_reply 'w/20260823_br_push08_checklist.tsv' 'br'
assert_eq "max_checklist: ゼロ埋めを8進数と読まない" "8" "$REPLY_N"

# item_text_for
assert_eq "item_text_for: handoffの文言" \
  'HANDOFF.md の進捗表・ヘッダを更新した（commitより前・同じcommitに含めた）' \
  "$(item_text_for handoff)"
assert_eq "item_text_for: 未知のidは空" '' "$(item_text_for nosuch)"
assert_eq "item_text_for: 定数の件数は5件" "5" "${#CHECKLIST_IDS[@]}"
assert_eq "item_text_for: idと項目の件数が一致する" "${#CHECKLIST_IDS[@]}" "${#CHECKLIST_ITEMS[@]}"
assert_eq "item_text_for: テンプレートと項目の件数が一致する" \
  "${#CHECKLIST_ITEM_TEMPLATES[@]}" "${#CHECKLIST_ITEMS[@]}"

# **本リポジトリ固有のディレクトリ名を決め打ちしない**（issue #17 フェーズ3の敵対的レビュー
# 2回目で指摘）。テンプレート側はプレースホルダを持ち、init_context が設定値で埋める。
pc_hardcoded=0
for pc_item in "${CHECKLIST_ITEM_TEMPLATES[@]}"; do
  case "$pc_item" in *wip/*) pc_hardcoded=$((pc_hardcoded + 1)) ;; esac
done
assert_eq "項目テンプレートにリポジトリ固有のディレクトリ名を含まない" "0" "$pc_hardcoded"
assert_eq "項目テンプレートは plansDir のプレースホルダを持つ" "1" \
  "$(printf '%s\n' "${CHECKLIST_ITEM_TEMPLATES[@]}" | grep -cF -- '{plansDir}')"
assert_eq "項目テンプレートは reportsDir のプレースホルダを持つ" "1" \
  "$(printf '%s\n' "${CHECKLIST_ITEM_TEMPLATES[@]}" | grep -cF -- '{reportsDir}')"

# --- verify_stream（否定形の4条件それぞれを、意図的に壊して確かめる）---------

# 正常系（全行 done、実施ログあり）を組み立てるヘルパ
make_tsv() {
  # $1 = 状態（省略時 done） $2 = 実施ログ（**省略時**のみ 'やった'）
  # `${2-...}` であって `${2:-...}` ではない。後者は空文字列も「未指定」として既定値へ
  # 倒すため、「実施ログが空のとき 1 になる」ケースが空振りする（実際に空振りした）。
  local state="${1:-done}" log="${2-やった}" i
  printf '# generated-for: %s\n' 'deadbeef'
  printf '# id\t項目\t状態\t実施ログ\n'
  for ((i = 0; i < ${#CHECKLIST_IDS[@]}; i++)); do
    printf '%s\t%s\t%s\t%s\n' "${CHECKLIST_IDS[$i]}" "${CHECKLIST_ITEMS[$i]}" "$state" "$log"
  done
}

assert_eq "verify_stream: 全行doneなら0" "0" "$(status_of eval 'make_tsv | verify_stream >/dev/null')"
assert_eq "verify_stream: 全行skipでも0" "0" \
  "$(status_of eval 'make_tsv skip 該当なし | verify_stream >/dev/null')"

# 条件3: pending が残っている
vs_out="$(make_tsv pending '' | verify_stream || true)"
assert_contains "verify_stream: pendingを未完了として報告する" "$vs_out" '未完了: worklog'
assert_eq "verify_stream: pendingがあれば1" "1" "$(status_of eval 'make_tsv pending "" | verify_stream >/dev/null')"

# 条件3: 状態のタイプミス
vs_out="$(make_tsv Done やった | verify_stream || true)"
assert_contains "verify_stream: 状態のタイプミスを形式異常として報告する" "$vs_out" '形式異常'
assert_eq "verify_stream: 状態のタイプミスは1" "1" "$(status_of eval 'make_tsv Done やった | verify_stream >/dev/null')"

# 条件4: 実施ログが空
vs_out="$(make_tsv done '' | verify_stream || true)"
assert_contains "verify_stream: 空の実施ログを報告する" "$vs_out" '実施ログが空です'
assert_eq "verify_stream: 空の実施ログは1" "1" "$(status_of eval 'make_tsv done "" | verify_stream >/dev/null')"
# 空白だけのログも空とみなす
assert_eq "verify_stream: 空白だけの実施ログも1" "1" \
  "$(status_of eval 'make_tsv done "   " | verify_stream >/dev/null')"

# 条件1: フィールド数が4でない
vs_broken="$(make_tsv | sed -E '3s/\t[^\t]*$//')"
vs_out="$(printf '%s\n' "$vs_broken" | verify_stream || true)"
assert_contains "verify_stream: 3フィールドの行を形式異常として報告する" "$vs_out" 'フィールド数が 3'
assert_eq "verify_stream: フィールド数が4でなければ1" "1" \
  "$(status_of eval 'printf "%s\n" "$vs_broken" | verify_stream >/dev/null')"

# 条件2: 行が足りない
vs_missing="$(make_tsv | sed '3d')"
vs_out="$(printf '%s\n' "$vs_missing" | verify_stream || true)"
assert_contains "verify_stream: 欠けた行を報告する" "$vs_out" '行が足りません: worklog'
assert_eq "verify_stream: 行が足りなければ1" "1" \
  "$(status_of eval 'printf "%s\n" "$vs_missing" | verify_stream >/dev/null')"

# 条件2: 想定外のid
vs_extra="$(
  make_tsv
  printf 'nosuch\t項目\tdone\tログ\n'
)"
vs_out="$(printf '%s\n' "$vs_extra" | verify_stream || true)"
assert_contains "verify_stream: 想定外のidを報告する" "$vs_out" '想定外です'

# 条件2: idの重複
vs_dup="$(
  make_tsv
  printf 'worklog\t項目\tdone\tログ\n'
)"
vs_out="$(printf '%s\n' "$vs_dup" | verify_stream || true)"
assert_contains "verify_stream: idの重複を報告する" "$vs_out" '重複しています'

# 空ファイルは「行が足りない」で1（素通りさせない）
vs_out="$(printf '' | verify_stream || true)"
assert_contains "verify_stream: 空ファイルは行不足として報告する" "$vs_out" '行が足りません'
assert_eq "verify_stream: 空ファイルは1" "1" "$(status_of eval 'printf "" | verify_stream >/dev/null')"

# CRLFでも通る（行末のCRを状態の一部と読まない）
assert_eq "verify_stream: CRLFでも0" "0" \
  "$(status_of eval "make_tsv | sed 's/\$/\r/' | verify_stream >/dev/null")"

# --- 2. サブコマンドの結合テスト --------------------------------------------

fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT
pc_repo="$fixture_dir/repo"

# 使い捨てリポジトリを作り直す。$1 を渡すと `.mrworkflow.json` を置かない（既定値の確認用）。
setup_pc_repo() {
  local no_config="${1:-}"
  rm -rf "$pc_repo"
  mkdir -p "$pc_repo/wip/plans" "$pc_repo/wip/worklogs"
  git -C "$pc_repo" init -q -b feature-17-checklist >/dev/null 2>&1 ||
    git -C "$pc_repo" init -q >/dev/null 2>&1
  git -C "$pc_repo" config user.email 'test@example.com'
  git -C "$pc_repo" config user.name 'test'
  if [ -z "$no_config" ]; then
    printf '%s\n' \
      '{"defaultBaseBranch":"main","plansDir":"wip/plans","worklogDir":"wip/worklogs","reportsDir":"wip/reports"}' \
      >"$pc_repo/.mrworkflow.json"
  fi
  printf '個別計画\n' >"$pc_repo/wip/plans/【実装】テスト.md"
}

# 実プロセスとして起動する。cd はサブシェルへ閉じ込め、テスト側のカレントを動かさない。
run_pc() { (cd "$pc_repo" && bash "$pc_script" "$@" 2>"$fixture_dir/pc-stderr.txt"); }
run_pc_status() {
  local st=0
  run_pc "$@" >"$fixture_dir/pc-stdout.txt" || st=$?
  printf '%s' "$st"
}

pc_commit_all() {
  git -C "$pc_repo" add -A >/dev/null 2>&1
  git -C "$pc_repo" commit -q -m "$1" >/dev/null 2>&1
}

# HEADを「公開済み」にする（実際に送らずリモート追跡refだけを作る）
pc_publish() {
  git -C "$pc_repo" update-ref refs/remotes/origin/main "$(git -C "$pc_repo" rev-parse HEAD)"
}

pc_checklists() {
  local f n=0
  for f in "$pc_repo"/wip/worklogs/*_checklist.tsv; do
    [ -f "$f" ] || continue
    n=$((n + 1))
  done
  printf '%s' "$n"
}

# unborn branch（コミットが1つも無い）でも落ちずに 3 を返す
setup_pc_repo
assert_eq "verify: unborn branch では3（ブロックしない）" "3" "$(run_pc_status verify)"
assert_eq "stale: unborn branch では1（コミット忘れ無し）" "1" "$(run_pc_status stale)"
assert_eq "new: unborn branch では何もせず0" "0" "$(run_pc_status new)"

# HEADはあるがチェックリストが無い
pc_commit_all 'init'
assert_eq "verify: HEADにチェックリストが無ければ3" "3" "$(run_pc_status verify)"
assert_eq "path: 作業ツリーに無ければ1" "1" "$(run_pc_status path)"

# 条件1（公開済み）を満たさないうちは生成しない
assert_eq "new: 未公開なら何もせず0" "0" "$(run_pc_status new)"
assert_eq "new: 未公開ならファイルを作らない" "0" "$(pc_checklists)"

# 3条件が揃えば生成する
pc_publish
assert_eq "new: 3条件が揃えば0" "0" "$(run_pc_status new)"
assert_eq "new: チェックリストが1本できる" "1" "$(pc_checklists)"
pc_path="$(run_pc path)"
assert_contains "path: 生成したファイルを指す" "$pc_path" '_push1_checklist.tsv'
assert_contains "new: ファイル名にブランチスラッグを含む" "$pc_path" '_feature-17-checklist_push1'
assert_eq "new: 1行目は generated-for（HEADのSHA）" \
  "# generated-for: $(git -C "$pc_repo" rev-parse HEAD)" \
  "$(head -1 "$pc_repo/$pc_path")"

# 生成直後のデータ行は常に4フィールド（pending 行も4列目を空で持つ）
pc_bad_fields=0
while IFS= read -r pc_line; do
  case "$pc_line" in '#'* | '') continue ;; esac
  split_tsv_line "$pc_line"
  [ "${#TSV_FIELDS[@]}" -eq 4 ] || pc_bad_fields=$((pc_bad_fields + 1))
done <"$pc_repo/$pc_path"
assert_eq "new: 生成直後の全データ行が4フィールド" "0" "$pc_bad_fields"
assert_eq "new: 生成直後のデータ行は5件" "5" "$(grep -cv -e '^#' -e '^$' "$pc_repo/$pc_path")"

# 条件2（冪等）: 同じHEADに対して2度目は生成しない
assert_eq "new: 同じHEADでは2度目を生成しない（終了コード0）" "0" "$(run_pc_status new)"
assert_eq "new: 同じHEADでは本数が増えない" "1" "$(pc_checklists)"

# check / skip
assert_eq "check: 未知のidは1" "1" "$(run_pc_status check nosuch 'ログ')"
assert_eq "check: 実施ログが空なら1" "1" "$(run_pc_status check worklog '')"
assert_eq "check: 正常に記録できる" "0" "$(run_pc_status check worklog 'push1の試行錯誤を追記した')"
assert_contains "check: 状態がdoneになる" "$(grep -E '^worklog\b' "$pc_repo/$pc_path")" \
  "$(printf 'done\tpush1の試行錯誤を追記した')"
assert_eq "skip: 正常に記録できる" "0" "$(run_pc_status skip frontmatter-index 'frontmatterを変更していない')"
assert_contains "skip: 状態がskipになる" "$(grep -E '^frontmatter-index\b' "$pc_repo/$pc_path")" \
  "$(printf 'skip\tfrontmatterを変更していない')"

# 実施ログのタブは空白へ潰し、4フィールドを保つ
run_pc check handoff "$(printf 'a\tb')" >/dev/null
split_tsv_line "$(grep -E '^handoff\b' "$pc_repo/$pc_path")"
assert_eq "check: ログ中のタブを潰して4フィールドを保つ" "4" "${#TSV_FIELDS[@]}"
assert_eq "check: ログ中のタブは空白になる" 'a b' "${TSV_FIELDS[3]}"

# 未完了のままコミットすると verify は 1（ブロック）
run_pc check plan-report-sync 'mdとhtmlを同期した' >/dev/null
pc_commit_all 'checklist（1件だけ未完了）'
pc_publish
assert_eq "verify: 未完了が残っていれば1" "1" "$(run_pc_status verify)"
assert_contains "verify: 未完了の項目名を出す" "$(cat "$fixture_dir/pc-stdout.txt")" '未完了: commit-skill'
assert_contains "verify: 対象ファイルのパスを出す" "$(cat "$fixture_dir/pc-stdout.txt")" '_push1_checklist.tsv'

# 全件埋めてコミットすれば verify は 0
run_pc check commit-skill 'create-commit.sh 経由でコミットした' >/dev/null
pc_commit_all 'checklist（全件完了）'
assert_eq "verify: 全件完了なら0" "0" "$(run_pc_status verify)"

# stale: 作業ツリーとHEADが一致していれば「コミット忘れ無し」
assert_eq "stale: 差が無ければ1" "1" "$(run_pc_status stale)"

# stale: 2回目以降のコミット忘れ（HEAD push1 / 作業ツリー push2）も拾う
pc_publish
run_pc new >/dev/null
assert_eq "new: 新しいHEADなら push2 を生成する" "2" "$(pc_checklists)"
assert_eq "stale: 2回目以降のコミット忘れを拾う（0=あり）" "0" "$(run_pc_status stale)"
assert_contains "stale: 番号の比較を報告する" "$(cat "$fixture_dir/pc-stdout.txt")" 'push2 > HEAD push1'
# このとき verify は「HEADの最新（push1・全件完了）」を見て 0 を返す。
# **verify だけでは新しいチェックリストのコミット忘れを検知できない**ことの固定。
assert_eq "verify: HEADの最大Nだけを見るので0のまま" "0" "$(run_pc_status verify)"

# stale: 初回push（HEADに無く作業ツリーにある = 0 -> 1）も同じ条件で拾う
setup_pc_repo
pc_commit_all 'init'
pc_publish
run_pc new >/dev/null
assert_eq "stale: 初回pushのコミット忘れを拾う（0=あり）" "0" "$(run_pc_status stale)"

# 条件3: HEADにタスク成果物が無ければ生成しない（flow-id 5-5 の片付け後）
setup_pc_repo
pc_commit_all 'init'
git -C "$pc_repo" rm -q -r wip/plans >/dev/null 2>&1
printf '雛形\n' >"$pc_repo/wip/worklogs/TEMPLATE.md"
pc_commit_all 'cleanup'
pc_publish
assert_eq "new: 片付け後は生成しない（終了コード0）" "0" "$(run_pc_status new)"
assert_eq "new: 片付け後はファイルを作らない" "0" "$(pc_checklists)"

# CRLF: 作業ツリーのチェックリストがCRLFでも generated-for の比較が壊れない
setup_pc_repo
pc_commit_all 'init'
pc_publish
run_pc new >/dev/null
pc_path="$(run_pc path)"
# 実ファイルをCRLFへ変換してから、同じHEADで new を呼ぶ（再生成されてはいけない）
sed -i 's/$/\r/' "$pc_repo/$pc_path"
assert_eq "new: CRLFでも同じHEADなら再生成しない（終了コード0）" "0" "$(run_pc_status new)"
assert_eq "new: CRLFでも本数が増えない" "1" "$(pc_checklists)"

# `.mrworkflow.json` が無い配布先では既定値（worklog）を使う。
# **`cleanup-task.sh:232` と同じ文字列であること**が要点で、ここがずれると生成側と削除側が
# 別のディレクトリを見る（issue #17 フェーズ3の敵対的レビュー1回目で指摘）。
setup_pc_repo no-config
mkdir -p "$pc_repo/plans"
printf '個別計画\n' >"$pc_repo/plans/【実装】テスト.md"
pc_commit_all 'init'
pc_publish
assert_eq "new: 設定ファイルが無くても0" "0" "$(run_pc_status new)"
assert_eq "new: 既定値の worklog/ へ生成する" "0" \
  "$(status_of test -d "$pc_repo/worklog")"

# `worklogDir` キーだけが無い場合も既定値へ倒れる（null/ を作らない）。
setup_pc_repo no-config
printf '%s\n' '{"defaultBaseBranch":"main","plansDir":"wip/plans"}' >"$pc_repo/.mrworkflow.json"
pc_commit_all 'init'
pc_publish
run_pc new >/dev/null
assert_eq "new: worklogDirキーが無くても null/ を作らない" "1" \
  "$(status_of test -e "$pc_repo/null")"
assert_eq "new: worklogDirキーが無ければ worklog/ へ生成する" "0" \
  "$(status_of test -d "$pc_repo/worklog")"

echo "passed=$passed failures=$failures"
[ "$failures" -eq 0 ]
