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
#                                          [--push-count <n>] [--loop <text>] [--file <path>]
#
# 進捗記号: [x] 完了 / [] 未着手・進行中 / [-] 今回は実施しない（スキップ）。
# ループ扱いのflow-id（.claude/rules/docs-workflow.md参照）は往復1回につき[]/[x]を連結して持つ
# （例: [x][x][]）。同じループ範囲内のflow-idは常に同じ個数を保つため、範囲内の1つを操作したら
# 範囲内の全flow-id行へ同じ操作を適用する。
#
# ヘッダの "- 現在のループ:" 行（issue #58）は、記号を数えずに周回数を読めるようにするための
# 冗長な表現であり、値は常に進捗表から導出する（別カウンタは持たない）。add-round と
# ループ範囲へのmark-doneはこの行を自動で追従させる。
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

# 進捗列（例 "[x][x][]"）の周回数（"[" の個数）をREPLYへ返す。
# ホットパスではないが、外部コマンド・コマンド置換を使わずbashの文字走査だけで数える
# （.claude/rules/shell-script-style.md「外部プロセス起動のコスト」）。進捗列はASCIIのみのため
# ${var:i:1} のバイト単位切り出しでも文字が壊れない。
count_rounds_to_reply() {
  local progress="$1"
  local i n=0
  for ((i = 0; i < ${#progress}; i++)); do
    [[ "${progress:i:1}" == '[' ]] && n=$((n + 1))
  done
  REPLY="$n"
}

# ループ範囲と進捗列から "- 現在のループ:" 行の値を組み立ててREPLYへ返す。
# 例: range="3-6 3-7 3-8 3-9", progress="[x][x][]" → "3-6〜3-9 の3周目（進行中）"
# 状態は進捗列の末尾で決める（"[]" なら進行中、それ以外は完了）。ループ範囲全体が "[-]"
# （スキップ）の場合、mark-done/add-roundはそもそもエラーになるためここへは到達しない。
format_loop_status_to_reply() {
  local range="$1" progress="$2"
  local -a ids
  read -ra ids <<<"$range"
  local rounds state
  count_rounds_to_reply "$progress"
  rounds="$REPLY"
  if [[ "$progress" == *'[]' ]]; then
    state='進行中'
  else
    state='完了'
  fi
  REPLY="${ids[0]}〜${ids[$((${#ids[@]} - 1))]} の${rounds}周目（${state}）"
}

# 行配列 LINES 内の "- 現在のループ:" 行を text で置き換える（読み込み・書き戻しは呼び出し側）。
# 行が無い場合は、既存ヘッダ項目（issue/ブランチ/PR/push回数）のうち最後の行の直後へ挿入する。
# ヘッダ項目が1つも無ければ "## フロー進捗状況" 見出しの直前へ、後ろに空行を1つ添えて挿入する
# （flow-id 5-1でリセットした直後のHANDOFF.mdはヘッダ項目を持たないため）。
# どちらの基準も見つからない場合は、メッセージを出さずに終了コード1を返す（扱いは呼び出し側が決める）。
set_loop_header_in_lines() {
  local text="$1"
  local i last_header=-1 heading=-1
  for ((i = 0; i < ${#LINES[@]}; i++)); do
    if [[ "${LINES[$i]}" =~ ^-[[:space:]]現在のループ: ]]; then
      LINES[$i]="- 現在のループ: ${text}"
      return 0
    fi
    # 見出し以降に現れる "- issue: " 等（本文中の引用など）を挿入位置の基準にしない
    if [[ $heading -lt 0 && "${LINES[$i]}" =~ ^-[[:space:]](issue|ブランチ|PR|push回数): ]]; then
      last_header=$i
    fi
    if [[ $heading -lt 0 && "${LINES[$i]}" == '## フロー進捗状況'* ]]; then
      heading=$i
    fi
  done

  local at
  local -a insert=("- 現在のループ: ${text}")
  if [[ $last_header -ge 0 ]]; then
    at=$((last_header + 1))
  elif [[ $heading -ge 0 ]]; then
    at=$heading
    insert+=("")
  else
    return 1
  fi
  LINES=("${LINES[@]:0:$at}" "${insert[@]}" "${LINES[@]:$at}")
}

# ループ範囲の進捗列に合わせてヘッダの "- 現在のループ:" 行を追従させる。
# 挿入位置が見つからない等で書けなかった場合も、進捗表の更新まで巻き戻さないよう警告のみに留める
# （記号更新が主目的であり、ヘッダ行はそれを読みやすくするための冗長な表現であるため）。
follow_loop_header_in_lines() {
  local range="$1" progress="$2"
  format_loop_status_to_reply "$range" "$progress"
  set_loop_header_in_lines "$REPLY" ||
    echo "warning: 「- 現在のループ:」行の挿入位置（ヘッダ項目／「## フロー進捗状況」見出し）が見つからないため、進捗表のみ更新します" >&2
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
                                         [--push-count <n>] [--loop <text>] [--file <path>]

  --file <path>   操作対象のHANDOFF.md（省略時 "HANDOFF.md"）
  --loop <text>   ヘッダの "- 現在のループ:" 行を <text> で書き換える（行が無ければ挿入する）。
                  例: --loop 'なし' / --loop '3-6〜3-9 の2周目（進行中）'
                  add-round・ループ範囲へのmark-doneは、この行を自動で追従させる
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
  local loop_range=""
  if find_loop_range_to_reply "$flow_id"; then
    loop_range="$REPLY"
    read -ra targets <<<"$loop_range"
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
  # ループ範囲の1周が完了したので、ヘッダの周回数表示を「完了」へ追従させる（単発ステップでは触らない）
  if [[ -n "$loop_range" ]]; then
    follow_loop_header_in_lines "$loop_range" "$new_progress"
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
  local loop_range="$REPLY"
  local -a targets
  read -ra targets <<<"$loop_range"

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
  # 新しい周回に入ったので、ヘッダの周回数表示を1つ進める（手作業での更新漏れを防ぐ）
  follow_loop_header_in_lines "$loop_range" "$new_progress"
  write_lines_from_array "$file"
}

# set-header: 指定されたオプションの項目のみヘッダ行（"- issue: " 等で始まる1行）を書き換える。
# 未指定の項目は現状維持。ヘッダ各項目は1行である前提（説明の補足等で複数行に折り返している
# 場合、2行目以降は書き換え対象にならず残るので注意）。
cmd_set_header() {
  local file="$1"
  shift
  local issue="" branch="" pr="" push_count="" loop=""
  local has_issue=0 has_branch=0 has_pr=0 has_push_count=0 has_loop=0
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
      --loop)
        loop="$2"
        has_loop=1
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
  # "- 現在のループ:" だけは行が存在しないHANDOFF.mdもあるため、置換ではなく専用関数へ委ねる
  if [[ $has_loop -eq 1 ]]; then
    set_loop_header_in_lines "$loop" || {
      echo "error: ヘッダ項目も「## フロー進捗状況」見出しも見つからないため「- 現在のループ:」行を挿入できません" >&2
      return 1
    }
  fi
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

# 単体テスト（.claude/scripts/test/test_update_handoff_progress.sh）からsourceして関数のみ再利用できるよう、
# 直接実行された場合のみ main を呼ぶ（extract-frontmatter.shと同じガードパターン）。
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
