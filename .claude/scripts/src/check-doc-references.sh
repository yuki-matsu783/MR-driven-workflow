#!/usr/bin/env bash
# DDRファイルパス形式の参照が実在するファイルを指しているかを検出する（issue #171）。
# 恒久的な参照先はissue番号のみとする（.claude/rules/docs-workflow.md「恒久的な参照先」。
# plans/ 等の短命ファイルへの参照はflow-id 5-4で消えるため書かない）。
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

# DDRパス候補を抽出する正規表現（bashの[[ =~ ]]・grep -Eのどちらからも同じ文字列を使う。
# 抽出経路が2つに分かれても正規表現が食い違わないよう、この変数を唯一の定義元にする）。
# 終端文字は半角の空白・実際のタブ文字・) ] " ' ` ( のみとする（ASCII文字に限定する）。
#
# 全角の句読点・括弧類（、。「」（）等）は終端文字に含めない。同一行に2つのDDRパスが
# 全角読点だけで区切られて並ぶ場合（「（詳細: A.md、経緯: B.md）」等）、貪欲マッチが
# 2つ目のパスの.mdまで飲み込み1本の架空パスへ誤って結合される問題は既知だが、対処は
# 正規表現の文字クラスへ全角文字を追加する方法を取らない。**この環境（LANG未設定、
# POSIXロケール）ではPOSIX ERE のブラケット式に多バイト文字を含めると、grep・bashの
# [[ =~ ]] のどちらも該当行に一切マッチしなくなる（ロケール依存の既知の罠として実機確認
# 済み。LC_ALL=C.UTF-8等のUTF-8対応ロケールを明示すれば動くが、git bash実機を含む配布先の
# ロケールを制御できない前提のため採用しない）。** 代わりに、抽出後の候補文字列に対して
# 全角文字を問わずASCII構造（`.claude/docs/ddr/`という接頭辞が候補の先頭以外にも現れるか）
# だけで連結を検知し分割する後処理（split_concatenated_candidates_to_reply）で対処する。
CHECK_DOC_REFERENCES_TAB=$'\t'
CHECK_DOC_REFERENCES_REGEX="\\.claude/docs/ddr/i[0-9]+-[0-9]+-[^]) \"'\`(${CHECK_DOC_REFERENCES_TAB}]*\\.md"
CHECK_DOC_REFERENCES_PATH_MARKER=".claude/docs/ddr/"

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

# 1行が、コードフェンスの開始/終了を表す行（行頭が3個以上の`または~。インデント可）かどうかを
# 判定する。該当する場合、マーカー種別をREPLY_FENCE_MARKER、長さをREPLY_FENCE_LENへ返す。
is_fence_delimiter_line() {
  local line="$1"
  if [[ "$line" =~ ^[[:space:]]*(\`\`\`+|~~~+) ]]; then
    local marker="${BASH_REMATCH[1]}"
    REPLY_FENCE_MARKER="${marker:0:1}"
    REPLY_FENCE_LEN="${#marker}"
    return 0
  fi
  return 1
}

# 複数行のテキスト（$'\n'区切り）を読み、コードフェンスで囲まれた範囲の行番号の集合を
# REPLY_FENCED_LINENOSへ返す（キーが行番号の連想配列。値は1）。
# 開始フェンスと同じ種別（`または~）・同じ長さ以上の閉じ記号でのみ閉じたとみなす
# （CommonMarkのフェンス規則を簡略化して踏襲。単純な「```行ならトグル」だと、フェンス内に
# コードのサンプルとして```や~~~が現れるだけで領域がずれ、偶数回トグルになった場合は未閉鎖
# 検知（安全側フォールバック）も働かないまま本文行を無言でフェンス内と誤認する。詳細は
# フェーズ3実装後の敵対的レビュー対応worklog）。
# 開いたフェンスが最後まで閉じなかった場合は、そのフェンス開始以降を一切フェンス扱いにしない
# （安全側＝偽陽性が出る方向へ倒す。偽陰性＝無言の見逃しにしない）。
compute_fenced_linenos_to_reply() {
  local content="$1"
  REPLY_FENCED_LINENOS=()
  local in_fence=0
  local open_marker="" open_len=0
  local lineno=0
  local -a pending_fence_linenos=()
  local line
  while IFS= read -r line; do
    lineno=$((lineno + 1))
    if [[ "$in_fence" -eq 0 ]]; then
      if is_fence_delimiter_line "$line"; then
        in_fence=1
        open_marker="$REPLY_FENCE_MARKER"
        open_len="$REPLY_FENCE_LEN"
        pending_fence_linenos+=("$lineno")
      fi
    else
      pending_fence_linenos+=("$lineno")
      if is_fence_delimiter_line "$line" \
        && [[ "$REPLY_FENCE_MARKER" == "$open_marker" ]] \
        && [[ "$REPLY_FENCE_LEN" -ge "$open_len" ]]; then
        in_fence=0
      fi
    fi
  done <<< "$content"

  if [[ "$in_fence" -eq 0 ]]; then
    local n
    for n in "${pending_fence_linenos[@]:-}"; do
      [[ -z "$n" ]] && continue
      REPLY_FENCED_LINENOS["$n"]=1
    done
  fi
  # in_fence -eq 1（未閉鎖）のときはREPLY_FENCED_LINENOSを空のまま返す（安全側）。
}

# 候補文字列の中に、終端文字集合では区切れなかった別のDDRパス（.claude/docs/ddr/で始まる
# 部分文字列）が2件目以降として埋め込まれていれば分割し、REPLY_SPLIT_CANDIDATESへ
# 1件以上の候補配列を返す（全角句読点等での連結対策。上記CHECK_DOC_REFERENCES_REGEXの
# コメント参照）。3件以上の連結にもループで対応する。各ピースは、末尾に連結の区切り文字が
# 残っている場合があるため、最後の".md"の直後で切り詰めて返す。
split_concatenated_candidates_to_reply() {
  local candidate="$1"
  local marker="$CHECK_DOC_REFERENCES_PATH_MARKER"
  REPLY_SPLIT_CANDIDATES=()
  local current="$candidate"
  local tail before_extra before after piece
  while true; do
    tail="${current#?}"
    case "$tail" in
      *"$marker"*)
        before_extra="${tail%%"$marker"*}"
        before="${current:0:1}${before_extra}"
        after="${marker}${tail#*"$marker"}"
        piece="${before%.md*}.md"
        REPLY_SPLIT_CANDIDATES+=("$piece")
        current="$after"
        ;;
      *)
        piece="${current%.md*}.md"
        REPLY_SPLIT_CANDIDATES+=("$piece")
        break
        ;;
    esac
  done
}

# 1行からDDRパス形式の候補をすべて抽出し、REPLY_CANDIDATES配列へ返す。
# main()の実走査はgrep（後述）で行うが、この関数はCHECK_DOC_REFERENCES_REGEXの単体テスト用に
# 用意する（grepとbashの[[ =~ ]]は同じregexを使うため、ここでの検証がgrep側の挙動も裏付ける）。
extract_ddr_candidates_to_reply() {
  local line="$1"
  REPLY_CANDIDATES=()
  local rest="$line"
  local match
  while [[ "$rest" =~ $CHECK_DOC_REFERENCES_REGEX ]]; do
    match="${BASH_REMATCH[0]}"
    REPLY_CANDIDATES+=("$match")
    rest="${rest#*"$match"}"
  done
}

main() {
  cd "$(git rev-parse --show-toplevel)"

  local scanned_files=0
  local excluded_dir=0
  local skipped_missing=0
  local total_candidates=0
  local excluded_placeholder=0
  local excluded_fence=0
  local missing=0
  local -a missing_lines=()

  local -a files=()
  local f
  while IFS= read -r -d '' f; do
    if is_excluded_target_path "$f"; then
      excluded_dir=$((excluded_dir + 1))
      continue
    fi
    if [[ ! -f "$f" ]]; then
      # git ls-filesはindexの内容を返すため、削除済み未ステージのファイルが混ざりうる。
      skipped_missing=$((skipped_missing + 1))
      continue
    fi
    files+=("$f")
  done < <(git ls-files -z -- '*.md' '*.sh' '.gitignore')

  scanned_files=${#files[@]}
  if [[ "$scanned_files" -eq 0 ]]; then
    echo "対象ファイルが1件も見つかりませんでした（走査対象のパターン・除外設定を確認してください）" >&2
    return 1
  fi

  # 候補行の抽出はgrep一括で行う（外部コマンドはgit ls-filesと合わせて2回のみ。
  # ファイルごとにbashの[[ =~ ]]で1行ずつ処理するより大幅に速く、grep -nが返す行番号は
  # 元ファイルそのものの行番号なので、フェンス除外による行番号のずれも生じない）。
  # -H でファイル名を強制する（対象が1件だけのときGNU grepは既定でファイル名列を省略し、
  # file:lineno:match の3分割を前提とする下記のパースが壊れるため）。
  local grep_out=""
  grep_out="$(printf '%s\0' "${files[@]}" \
    | xargs -0 grep -nHoE -- "$CHECK_DOC_REFERENCES_REGEX" 2>/dev/null || true)"

  # ファイルごとに候補をグルーピングしつつ、フェンス範囲を1ファイル1回だけ計算する。
  # grep -noEの出力は入力ファイル順にまとまって出るため（GNU grepの仕様）、直前と同じ
  # ファイルの間は再計算せず使い回す。
  local -A fenced_current=()
  local current_file=""
  local line file_part rest lineno_part candidate
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    file_part="${line%%:*}"
    rest="${line#*:}"
    lineno_part="${rest%%:*}"
    candidate="${rest#*:}"

    if [[ "$file_part" != "$current_file" ]]; then
      current_file="$file_part"
      local content
      content="$(<"$file_part")"
      compute_fenced_linenos_to_reply "$content"
      fenced_current=()
      local k
      for k in "${!REPLY_FENCED_LINENOS[@]}"; do
        fenced_current["$k"]=1
      done
    fi

    if [[ -n "${fenced_current[$lineno_part]:-}" ]]; then
      excluded_fence=$((excluded_fence + 1))
      continue
    fi

    split_concatenated_candidates_to_reply "$candidate"
    local piece
    for piece in "${REPLY_SPLIT_CANDIDATES[@]}"; do
      if is_placeholder_candidate "$piece"; then
        excluded_placeholder=$((excluded_placeholder + 1))
        continue
      fi

      total_candidates=$((total_candidates + 1))
      if [[ ! -f "$piece" ]]; then
        missing=$((missing + 1))
        missing_lines+=("${file_part}:${lineno_part}:${piece}")
      fi
    done
  done <<< "$grep_out"

  {
    printf '走査ファイル数=%d（除外ディレクトリ配下=%d、削除済み未ステージのためスキップ=%d）\n' \
      "$scanned_files" "$excluded_dir" "$skipped_missing"
    printf '候補数=%d（フェンス内除外=%d、省略記法による除外=%d）\n' \
      "$total_candidates" "$excluded_fence" "$excluded_placeholder"
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
