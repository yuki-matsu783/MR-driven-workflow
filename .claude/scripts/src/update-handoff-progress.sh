#!/usr/bin/env bash
# HANDOFF.mdの「フロー進捗状況」表の進捗記号・ヘッダ情報を機械的に更新する（issue #20）。
# flow-idが1つ進むごとの手作業更新（記号の書き間違い・更新漏れ）を無くすため、
# .claude/skills/issue-mr-flow/SKILL.md の「flow-idが1つ進むごとに、必ずHANDOFF.mdを更新する」
# 手順をこのスクリプトへ委譲する。
#
# 使い方:
#   update-handoff-progress.sh mark-done <flow-id> [--file <path>]
#   update-handoff-progress.sh mark-skip <flow-id> [<flow-id>...] [--file <path>]
#   update-handoff-progress.sh add-round <flow-id> [--file <path>]
#   update-handoff-progress.sh set-header [--issue <text>] [--branch <text>] [--pr <text>]
#                                          [--push-count <n>] [--file <path>]
#
# 進捗記号: [x] 完了 / [] 未着手・進行中 / [-] 今回は実施しない（スキップ）。
# ループ扱いのflow-id（.claude/rules/docs-workflow.md参照）は往復1回につき[]/[x]を連結して持つ
# （例: [x][x][]）。同じループ範囲内のflow-idは常に同じ個数を保つため、範囲内の1つを操作したら
# 範囲内の全flow-id行へ同じ操作を適用する。
#
# 仕様: .claude/docs/spec/update-handoff-progress.md
set -euo pipefail

# ループ範囲テーブル（.claude/rules/docs-workflow.md「ループステップの`[]`追加ルール」と同一の
# 6範囲）。要素はスペース区切りのflow-id列。範囲・並びを変える場合は同ドキュメントも合わせて
# 更新すること。
readonly -a LOOP_RANGES=(
  "2-3 2-4"
  "2-6 2-7 2-8 2-9"
  "3-3 3-4"
  "3-6 3-7 3-8 3-9"
  "4-3 4-4"
  "4-6 4-7 4-8 4-9"
)

# targetsの中にflow_idが含まれるかを判定する（要素数が小さい前提の線形探索。連想配列は使わない）。
is_target() {
  local flow_id="$1"
  shift
  local t
  for t in "$@"; do
    [[ "$t" == "$flow_id" ]] && return 0
  done
  return 1
}

# 指定flow-idが属するループ範囲（スペース区切り文字列）をREPLYへ返す。属さなければ
# 終了コード1を返す（REPLYは変更しない）。
find_loop_range_to_reply() {
  local flow_id="$1"
  local range id
  for range in "${LOOP_RANGES[@]}"; do
    for id in $range; do
      if [[ "$id" == "$flow_id" ]]; then
        REPLY="$range"
        return 0
      fi
    done
  done
  return 1
}

# 進捗表の1行を解析する。マッチすれば以下をREPLY_*へ設定し終了コード0を返す:
#   REPLY_PREFIX  : 進捗列より前の部分（例: "| "）
#   REPLY_PROGRESS: 進捗列の中身（例: "[x][]"）
#   REPLY_SUFFIX  : 進捗列より後（flow-id列含む）の部分（例: " | 2-4 | ... |"）
#   REPLY_FLOW_ID : flow-id（例: "2-4"）
# マッチしなければ終了コード1を返す（表ヘッダ・区切り行・非テーブル行はここで弾かれる）。
#
# 置換に ${line/pattern/repl} 等のbashパターン置換を使わないのは、進捗記号 "[x]" 等がglob文字
# クラスとして誤解釈される事故を避けるため（後段では常にこの関数で切り出した3区画を単純な
# 文字列連結で再結合する）。
parse_table_row_to_reply() {
  local line="$1"
  if [[ "$line" =~ ^(\|[[:space:]]*)(\[[^\|]*\])([[:space:]]*\|[[:space:]]*([0-9]+-[0-9]+)[[:space:]]*\|.*)$ ]]; then
    REPLY_PREFIX="${BASH_REMATCH[1]}"
    REPLY_PROGRESS="${BASH_REMATCH[2]}"
    REPLY_SUFFIX="${BASH_REMATCH[3]}"
    REPLY_FLOW_ID="${BASH_REMATCH[4]}"
    return 0
  fi
  return 1
}

usage() {
  cat >&2 <<'USAGE'
usage:
  update-handoff-progress.sh mark-done <flow-id> [--file <path>]
  update-handoff-progress.sh mark-skip <flow-id> [<flow-id>...] [--file <path>]
  update-handoff-progress.sh add-round <flow-id> [--file <path>]
  update-handoff-progress.sh set-header [--issue <text>] [--branch <text>] [--pr <text>]
                                         [--push-count <n>] [--file <path>]

  --file <path>   操作対象のHANDOFF.md（省略時 "HANDOFF.md"）
USAGE
}

# ファイル全体を行配列 LINES へ読み込む。
read_lines_to_array() {
  local file="$1"
  mapfile -t LINES <"$file"
}

# 行配列 LINES を一時ファイル経由でファイルへ書き戻す（中断しても既存を壊さない）。
write_lines_from_array() {
  local file="$1"
  local tmp="$file.tmp.$$"
  printf '%s\n' "${LINES[@]}" >"$tmp"
  mv -f "$tmp" "$file"
}

# mark-done <flow-id>: 対象行（ループ範囲なら範囲内の全flow-id行）の進捗列末尾の "[]" を "[x]" に
# 置き換える。末尾が "[]" でない対象行があればエラー終了する。
cmd_mark_done() {
  local file="$1" flow_id="$2"
  local -a targets=("$flow_id")
  if find_loop_range_to_reply "$flow_id"; then
    read -ra targets <<<"$REPLY"
  fi

  read_lines_to_array "$file"
  local i line progress new_progress matched=0
  for ((i = 0; i < ${#LINES[@]}; i++)); do
    line="${LINES[$i]}"
    parse_table_row_to_reply "$line" || continue
    is_target "$REPLY_FLOW_ID" "${targets[@]}" || continue

    progress="$REPLY_PROGRESS"
    if [[ "$progress" != *'[]' ]]; then
      echo "error: flow-id ${REPLY_FLOW_ID} の進捗列 '${progress}' は末尾が [] ではありません（既に完了済みの可能性）" >&2
      return 1
    fi
    new_progress="${progress%'[]'}[x]"
    LINES[$i]="${REPLY_PREFIX}${new_progress}${REPLY_SUFFIX}"
    matched=$((matched + 1))
  done

  if [[ $matched -ne ${#targets[@]} ]]; then
    echo "error: flow-id ${flow_id} に該当する行が想定数（${#targets[@]}）見つかりませんでした（実際: ${matched}）" >&2
    return 1
  fi
  write_lines_from_array "$file"
}

# mark-skip <flow-id> [<flow-id>...]: 指定した各flow-id行の進捗列を "[-]" へ上書きする。
cmd_mark_skip() {
  local file="$1"
  shift
  local -a targets=("$@")

  read_lines_to_array "$file"
  local i line matched=0
  for ((i = 0; i < ${#LINES[@]}; i++)); do
    line="${LINES[$i]}"
    parse_table_row_to_reply "$line" || continue
    is_target "$REPLY_FLOW_ID" "${targets[@]}" || continue

    LINES[$i]="${REPLY_PREFIX}[-]${REPLY_SUFFIX}"
    matched=$((matched + 1))
  done

  if [[ $matched -ne ${#targets[@]} ]]; then
    echo "error: 指定flow-idの一部が見つかりませんでした（想定 ${#targets[@]} 件、実際 ${matched} 件）" >&2
    return 1
  fi
  write_lines_from_array "$file"
}

# add-round <flow-id>: ループ範囲内の全flow-id行の進捗列末尾に新しい "[]" を追記する
# （次の往復が始まったことを表す）。ループでないflow-id、または既に末尾が "[]" の行が
# あればエラー終了する。
cmd_add_round() {
  local file="$1" flow_id="$2"
  if ! find_loop_range_to_reply "$flow_id"; then
    echo "error: flow-id ${flow_id} はループ範囲に属しません（add-roundはループ扱いのflow-id専用）" >&2
    return 1
  fi
  local -a targets
  read -ra targets <<<"$REPLY"

  read_lines_to_array "$file"
  local i line progress new_progress matched=0
  for ((i = 0; i < ${#LINES[@]}; i++)); do
    line="${LINES[$i]}"
    parse_table_row_to_reply "$line" || continue
    is_target "$REPLY_FLOW_ID" "${targets[@]}" || continue

    progress="$REPLY_PROGRESS"
    if [[ "$progress" == *'[]' ]]; then
      echo "error: flow-id ${REPLY_FLOW_ID} の進捗列 '${progress}' は既に末尾が [] です（前回の往復が未完了の可能性）" >&2
      return 1
    fi
    new_progress="${progress}[]"
    LINES[$i]="${REPLY_PREFIX}${new_progress}${REPLY_SUFFIX}"
    matched=$((matched + 1))
  done

  if [[ $matched -ne ${#targets[@]} ]]; then
    echo "error: flow-id ${flow_id} に該当する行が想定数（${#targets[@]}）見つかりませんでした（実際: ${matched}）" >&2
    return 1
  fi
  write_lines_from_array "$file"
}

# set-header: 指定されたオプションの項目のみヘッダ行（"- issue: " 等で始まる1行）を書き換える。
# 未指定の項目は現状維持。ヘッダ各項目は1行である前提（説明の補足等で複数行に折り返している
# 場合、2行目以降は書き換え対象にならず残るので注意）。
cmd_set_header() {
  local file="$1"
  shift
  local issue="" branch="" pr="" push_count=""
  local has_issue=0 has_branch=0 has_pr=0 has_push_count=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --issue)
        issue="$2"
        has_issue=1
        shift 2
        ;;
      --branch)
        branch="$2"
        has_branch=1
        shift 2
        ;;
      --pr)
        pr="$2"
        has_pr=1
        shift 2
        ;;
      --push-count)
        push_count="$2"
        has_push_count=1
        shift 2
        ;;
      *)
        echo "error: set-headerの不明な引数: $1" >&2
        return 1
        ;;
    esac
  done

  read_lines_to_array "$file"
  local i line
  for ((i = 0; i < ${#LINES[@]}; i++)); do
    line="${LINES[$i]}"
    if [[ $has_issue -eq 1 && "$line" =~ ^-[[:space:]]issue: ]]; then
      LINES[$i]="- issue: ${issue}"
    elif [[ $has_branch -eq 1 && "$line" =~ ^-[[:space:]]ブランチ: ]]; then
      LINES[$i]="- ブランチ: ${branch}"
    elif [[ $has_pr -eq 1 && "$line" =~ ^-[[:space:]]PR: ]]; then
      LINES[$i]="- PR: ${pr}"
    elif [[ $has_push_count -eq 1 && "$line" =~ ^-[[:space:]]push回数: ]]; then
      LINES[$i]="- push回数: ${push_count}"
    fi
  done
  write_lines_from_array "$file"
}

main() {
  if [[ $# -eq 0 ]]; then
    usage
    return 1
  fi

  local sub="$1"
  shift

  if [[ "$sub" == "-h" || "$sub" == "--help" ]]; then
    usage
    return 0
  fi

  # --file オプションを引数列から抜き出す（他の引数の並びは保つ）
  local file="HANDOFF.md"
  local -a rest=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file)
        file="$2"
        shift 2
        ;;
      *)
        rest+=("$1")
        shift
        ;;
    esac
  done

  case "$sub" in
    mark-done)
      [[ ${#rest[@]} -eq 1 ]] || {
        usage
        return 1
      }
      cmd_mark_done "$file" "${rest[0]}"
      ;;
    mark-skip)
      [[ ${#rest[@]} -ge 1 ]] || {
        usage
        return 1
      }
      cmd_mark_skip "$file" "${rest[@]}"
      ;;
    add-round)
      [[ ${#rest[@]} -eq 1 ]] || {
        usage
        return 1
      }
      cmd_add_round "$file" "${rest[0]}"
      ;;
    set-header)
      cmd_set_header "$file" "${rest[@]}"
      ;;
    *)
      echo "error: unknown subcommand: $sub" >&2
      usage
      return 1
      ;;
  esac
}

# 単体テスト（tests/test_update_handoff_progress.sh）からsourceして関数のみ再利用できるよう、
# 直接実行された場合のみ main を呼ぶ（extract-frontmatter.shと同じガードパターン）。
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
