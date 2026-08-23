#!/usr/bin/env bash
# DDRファイルパス形式の参照が実在するファイルを指しているかを検出する（issue #171）。
# 設計: plans/【実装】【テスト】.gitignoreのDDR参照修正と検出スクリプトの追加.md（v2）
set -euo pipefail

# 対象から除外するディレクトリ（先頭一致）。
#   .claude/scripts/test/ … フィクスチャに架空のDDRパスを含むため
#   plans/ reports/ worklog/ … タスク単位で削除される短命ファイル。.html除外と同じ理由
CHECK_DOC_REFERENCES_EXCLUDED_DIRS=(
  ".claude/scripts/test/"
  "plans/"
  "reports/"
  "worklog/"
)

# 1つのファイルパスが除外対象ディレクトリ配下かどうかを判定する。
is_excluded_target_path() {
  local path="$1" dir
  for dir in "${CHECK_DOC_REFERENCES_EXCLUDED_DIRS[@]}"; do
    case "$path" in
      "$dir"*) return 0 ;;
    esac
  done
  return 1
}

# 候補文字列が省略記法（...または…）を含むかどうかを判定する。
is_placeholder_candidate() {
  local candidate="$1"
  case "$candidate" in
    *"..."*|*"…"*) return 0 ;;
    *) return 1 ;;
  esac
}

# 1行が、コードフェンスの開始/終了を表す行（行頭が ``` または ~~~。インデント可）かどうかを
# 判定する。
is_fence_delimiter_line() {
  local line="$1"
  [[ "$line" =~ ^[[:space:]]*(\`\`\`|~~~) ]]
}

# 複数行のテキスト（$'\n'区切り）から、Markdownコードフェンスで囲まれた範囲の行を除いた
# テキストをREPLYへ返す。
# フェンス区切り行が奇数個で、開いたまま閉じずに終わった場合は、安全側（偽陰性＝無言の
# 見逃しにしない）に倒し、除外を一切行わず入力をそのまま返す。
strip_fenced_lines_to_reply() {
  local text="$1"
  local in_fence=0
  local toggles=0
  local out=""
  local line
  while IFS= read -r line; do
    if is_fence_delimiter_line "$line"; then
      in_fence=$((1 - in_fence))
      toggles=$((toggles + 1))
      continue
    fi
    if [[ "$in_fence" -eq 0 ]]; then
      out+="$line"$'\n'
    fi
  done <<< "$text"

  if (( toggles % 2 != 0 )); then
    # 未閉鎖: フェンス除外を行わなかったことにする（安全側）
    REPLY="$text"
  else
    REPLY="$out"
  fi
}

# 1行からDDRパス形式の候補をすべて抽出し、REPLY_CANDIDATES配列へ返す。
# 終端文字は空白・実際のタブ文字・) ] " ' ` ( とする（\tというエスケープ表記は使わない。
# ブラケット式内では\tがバックスラッシュとtの2文字として解釈され、tが終端文字になって
# しまうため。詳細: 上記計画「v1からの訂正点」）。
extract_ddr_candidates_to_reply() {
  local line="$1"
  local tab=$'\t'
  local re="\\.claude/docs/ddr/i[0-9]+-[0-9]+-[^]) \"'\`(${tab}]*\\.md"
  REPLY_CANDIDATES=()
  local rest="$line"
  local match
  while [[ "$rest" =~ $re ]]; do
    match="${BASH_REMATCH[0]}"
    REPLY_CANDIDATES+=("$match")
    # 直前の一致より後ろだけを残して次の候補を探す
    rest="${rest#*"$match"}"
  done
}

main() {
  cd "$(git rev-parse --show-toplevel)"

  local scanned_files=0
  local excluded_dir=0
  local unclosed_fence_files=0
  local total_candidates=0
  local excluded_placeholder=0
  local missing=0
  local file
  local -a missing_lines=()

  while IFS= read -r -d '' file; do
    if is_excluded_target_path "$file"; then
      excluded_dir=$((excluded_dir + 1))
      continue
    fi
    [[ -f "$file" ]] || continue
    scanned_files=$((scanned_files + 1))

    local content
    content="$(<"$file")"

    local fence_toggles
    fence_toggles=0
    local probe_line
    while IFS= read -r probe_line; do
      is_fence_delimiter_line "$probe_line" && fence_toggles=$((fence_toggles + 1))
    done <<< "$content"
    if (( fence_toggles % 2 != 0 )); then
      unclosed_fence_files=$((unclosed_fence_files + 1))
    fi

    strip_fenced_lines_to_reply "$content"
    local stripped="$REPLY"

    local lineno=0
    local line
    while IFS= read -r line; do
      lineno=$((lineno + 1))
      extract_ddr_candidates_to_reply "$line"
      local candidate
      for candidate in "${REPLY_CANDIDATES[@]:-}"; do
        [[ -z "$candidate" ]] && continue
        if is_placeholder_candidate "$candidate"; then
          excluded_placeholder=$((excluded_placeholder + 1))
          continue
        fi
        total_candidates=$((total_candidates + 1))
        if [[ ! -f "$candidate" ]]; then
          missing=$((missing + 1))
          missing_lines+=("${file}:${lineno}:${candidate}")
        fi
      done
    done <<< "$stripped"
  done < <(git ls-files -z -- '*.md' '*.sh' '.gitignore')

  {
    printf '走査ファイル数=%d（除外ディレクトリ配下=%d）\n' "$scanned_files" "$excluded_dir"
    printf '候補数=%d（省略記法による除外=%d）\n' "$total_candidates" "$excluded_placeholder"
    printf 'フェンス未閉鎖ファイル数=%d（安全側のため除外なし）\n' "$unclosed_fence_files"
    printf '参照切れ数=%d\n' "$missing"
  } >&2

  local ml
  for ml in "${missing_lines[@]:-}"; do
    [[ -z "$ml" ]] && continue
    printf '%s\n' "$ml"
  done

  [[ "$missing" -eq 0 ]]
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main
fi
