#!/usr/bin/env bash
#
# issue駆動MRワークフロー機構のAIアセットを、他プロジェクトへ配布する（manifest方式。issue #26）。
#
# 何をどう配るかは本家の .claude/dist-layers.json が定める（5層）。
#   core    … 常に上書きする（本家所有）
#   seed    … 配布先に無ければ置く。あれば触らない（配布先所有）
#   merge   … 構造的にマージする（lines-marker / json-keys）
#   local   … 何もしない（配布先のローカル作業状態）
#   exclude … 配らない（本家固有）
#
# 配布結果は配布先の .claude/.asset-manifest.json へ記録し、次回の再適用で
# 「配布先が適用後に変更したファイル」を判定する材料にする。
#
# 使い方:
#     bash install-to-project.sh [オプション] <配布先ディレクトリ>
#
#     --dry-run       配置せず、何が起きるかだけを出力する
#     --force         改変済み core を .bak を残さず上書きする
#     --allow-dirty   本家のワークツリーが dirty でも続行する
#                     （このとき manifest の commit へ -dirty が付く）
#
# **2パス構成**である。受け入れ条件4が「上書きの**前に**警告と対象一覧を出す」ことを求めており、
# 配置しながら警告を出す1パスの形では満たせない。走査パス（手順4）→ 提示（手順5）→
# 配置パス（手順6）の順で進む。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPSTREAM_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
readonly DEF_REL='.claude/dist-layers.json'
readonly DEF_FILE="${UPSTREAM_ROOT}/${DEF_REL}"
readonly MANIFEST_REL='.claude/.asset-manifest.json'
readonly MARKER_BEGIN='# --- dist:begin ---'
readonly MARKER_END='# --- dist:end ---'

OPT_DRY_RUN=0
OPT_FORCE=0
OPT_ALLOW_DIRTY=0
DEST_DIR=''

usage() {
  # 行番号で切り出すと、冒頭のコメントを1行足しただけでずれる（実際に `set -euo pipefail` が
  # ヘルプ末尾へ出ていた）。3行目から「コメントでない最初の行」の手前までを取る。
  awk 'NR >= 3 { if ($0 !~ /^#/) exit; sub(/^# ?/, ""); print }' "${BASH_SOURCE[0]}"
}

# ---- 小さなヘルパー --------------------------------------------------------

# LF正規化した内容の sha256 を REPLY へ返す。
# 正規化するのは、Windowsの core.autocrlf=true で全ファイルが「配布先が変更した」と
# 誤検知されるのを防ぐため（**Windows実機では未確認**。フェーズ4でspecの未決定事項へ残す）。
sha256_lf_to_reply() {
  local file="$1"
  REPLY="$(tr -d '\r' < "$file" | sha256sum | cut -d' ' -f1)"
}

log_section() {
  printf '\n=== %s ===\n' "$1"
}

# ---- 定義の読み込み --------------------------------------------------------

# 定義を1エントリ1行のレコードへ落とす（jqの起動は1回）。
# 区切りはタブではなく `\u001f`（US）。タブはIFSの空白文字で、空の列があると
# bashの `read` が連続タブを畳んで列がずれる（.claude/rules/shell-script-style.md）。
read_entries_records() {
  jq -r '
    .entries[]
    | [ (.layer // ""),
        (.path // ""),
        (.source // ""),
        (.strategy // ""),
        ((.keys // []) | join(",")),
        (.header // "") ]
    | join("\u001f")
  ' "$DEF_FILE" | tr -d '\r'
}

# 配布計画を組み立てる。**後に書いたエントリが勝つ**（.gitignore と同じ規約）ので、
# 定義の順に上書きしていくだけで例外が表現できる。
declare -A PLAN_LAYER=() PLAN_SRC=() PLAN_STRATEGY=() PLAN_KEYS=() PLAN_HEADER=()
declare -a PLAN_PATHS=()
# dirty 判定に使う「配布対象のパス」。PLAN_PATHS（追跡ファイルの完全パス）では未追跡ファイルを
# 拾えないため、エントリの path をディレクトリのまま持っておく。
declare -a DIST_PATHSPECS=() DIST_EXCLUDESPECS=()
# 本家が実際に dirty だったか（--allow-dirty を付けたかどうかとは別）。
UPSTREAM_DIRTY=0

build_plan() {
  local layer path source strategy keys header f tmp_ls
  local -A seen=()
  tmp_ls="$(mktemp)"

  while IFS=$'\037' read -r layer path source strategy keys header; do
    [ -n "$layer" ] || continue

    if [ -n "$path" ]; then
      case "$layer" in
        core|seed|merge) DIST_PATHSPECS+=("$path") ;;
        exclude) DIST_EXCLUDESPECS+=(":(exclude)${path}") ;;
      esac
    fi

    if [ -n "$path" ]; then
      if ! git -C "$UPSTREAM_ROOT" ls-files -z -- "$path" > "$tmp_ls" 2>/dev/null; then
        printf 'エラー: pathspec として解釈できません: %s\n' "$path" >&2
        rm -f "$tmp_ls"
        return 1
      fi
      local n=0
      while IFS= read -r -d '' f; do
        n=$((n + 1))
        PLAN_LAYER["$f"]="$layer"
        PLAN_SRC["$f"]="${source:-$f}"
        PLAN_STRATEGY["$f"]="$strategy"
        PLAN_KEYS["$f"]="$keys"
        PLAN_HEADER["$f"]="$header"
        [ -n "${seen[$f]+x}" ] || { seen["$f"]=1; PLAN_PATHS+=("$f"); }
      done < "$tmp_ls"

      if [ -n "$source" ] && [ "$n" -gt 1 ]; then
        printf 'エラー: source を持つエントリが複数ファイルに一致しました: %s\n' "$path" >&2
        rm -f "$tmp_ls"
        return 1
      fi
      # 本家に実体が無い seed（REVIEW-POINTS.local.md 等）は、path を配布先のパスとして扱う。
      if [ "$n" -eq 0 ] && [ -n "$source" ]; then
        PLAN_LAYER["$path"]="$layer"
        PLAN_SRC["$path"]="$source"
        PLAN_STRATEGY["$path"]="$strategy"
        PLAN_KEYS["$path"]="$keys"
        PLAN_HEADER["$path"]="$header"
        [ -n "${seen[$path]+x}" ] || { seen["$path"]=1; PLAN_PATHS+=("$path"); }
      fi
    fi
  done < <(read_entries_records)

  rm -f "$tmp_ls"
  return 0
}

# ---- 前提検証 --------------------------------------------------------------

# 配る内容がコミットと一致しない状態で配らないための判定（受け入れ条件6）。
# 対象は core / seed（source 側パスを含む）/ merge のみ。exclude は配布先へ1バイトも
# 配られないので、編集中でも manifest の再現性は損なわれない。
check_upstream_clean() {
  local -a specs=()
  local p
  for p in "${PLAN_PATHS[@]}"; do
    case "${PLAN_LAYER[$p]}" in
      core|seed|merge) ;;
      *) continue ;;
    esac
    specs+=("$p")
    [ "${PLAN_SRC[$p]}" = "$p" ] || specs+=("${PLAN_SRC[$p]}")
  done

  # **未追跡ファイルは specs では拾えない。** specs は `git ls-files` 由来の「既存の追跡ファイルの
  # 完全パス」なので、`??` のエントリに一致しようがない。本家で新規作成してコミットしていない
  # ルール・スクリプトは配布計画（build_plan も `git ls-files`）にも入らないため、警告もサマリも
  # 無いまま配布先へ届かない。中断はしないが、件数は必ず出す（無言のスキップにしない）。
  local untracked=0
  if [ "${#DIST_PATHSPECS[@]}" -gt 0 ]; then
    untracked="$(git -C "$UPSTREAM_ROOT" status --porcelain --untracked-files=all \
      -- "${DIST_PATHSPECS[@]}" ${DIST_EXCLUDESPECS[@]+"${DIST_EXCLUDESPECS[@]}"} 2>/dev/null \
      | grep -c -- '^??' || true)"
  fi
  if [ "$untracked" -gt 0 ]; then
    printf '%s\n' "注意: 配布対象のパスに未追跡ファイルが ${untracked} 件あります（配布対象外です。配るならコミットしてください）" >&2
  fi

  local out n
  out="$(git -C "$UPSTREAM_ROOT" status --porcelain -- "${specs[@]}")"
  [ -n "$out" ] || return 0
  UPSTREAM_DIRTY=1

  n="$(printf '%s\n' "$out" | grep -c .)"
  if [ "$OPT_ALLOW_DIRTY" -eq 1 ]; then
    # 一覧までは出さない（--allow-dirty は承知のうえで進める指定であり、毎回全件を出すと
    # 本当に読むべき警告が埋もれる）。件数だけを出して、追えるようにはしておく。
    # 書式文字列が `--` で始まると bash の printf がオプションとして解釈するため、
    # 本文は引数側へ回す（.claude/rules/shell-script-style.md の「先頭がハイフンの値」と同種）。
    printf '%s\n' "注意: 本家に未コミットの変更が ${n} 件あります（--allow-dirty のため続行。manifest の commit へ -dirty を付けます）" >&2
    return 0
  fi
  printf '本家のワークツリーに未コミットの変更が %s 件あります（配布対象のパスに限定して判定）:\n' "$n" >&2
  printf '%s\n' "$out" >&2
  printf '%s\n' 'コミットしてから再実行するか、--allow-dirty を付けてください。' >&2
  return 1
}

# ---- merge の2方式 ---------------------------------------------------------

# 本家のファイルから、マーカーで囲まれた「配る行」（コメント・空行を除く）を標準出力へ出す。
# **マーカーが1行も見つからない場合は失敗させる**（旧実装は警告のみで無言の空振りになっていた）。
# **BEGIN だけでなく END の欠落でも失敗させる。** `inside=1` のままEOFに達すると、BEGIN以降の
# 全行（コメント・空行を除く）が配布対象になってしまい、しかもコメントが落ちるので出力を
# 目視しても異常だと気づけない。
extract_marker_lines() {
  local file="$1" line inside=0 found_begin=0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line//$'\r'/}"
    if [ "$line" = "$MARKER_BEGIN" ]; then inside=1; found_begin=1; continue; fi
    if [ "$line" = "$MARKER_END" ]; then inside=0; continue; fi
    [ "$inside" -eq 1 ] || continue
    case "$line" in ''|'#'*) continue ;; esac
    printf '%s\n' "$line"
  done < "$file"
  [ "$found_begin" -eq 1 ] && [ "$inside" -eq 0 ]
}

# 配布先のファイルへ、未収録の行だけを追記する（冪等・行全体一致・末尾改行の補完）。
# 追記した行数を REPLY へ返す。
append_missing_lines() {
  local src="$1" dst="$2" header="${3:-}" line added=0
  local -a to_add=() candidates=()

  # 配布先の読み手が「この行がどこから来たか」を追えるよう、先頭にヘッダコメントを置く
  # （旧実装が持っていた挙動。落とすと配布先には由来の分からない行だけが残る）。
  # 同じ「行全体一致で無ければ追記」の判定を通すので、再適用しても増えない。
  [ -z "$header" ] || candidates+=("$header")
  while IFS= read -r line; do
    candidates+=("$line")
  done < <(extract_marker_lines "$src")

  # **配布先のCRを落としてから突き合わせる。** Git for Windows の既定（core.autocrlf=true）では
  # 配布先のファイルが作業ツリーでCRLFになり、行全体一致（grep -Fx）が必ず外れる。落とさないと
  # 適用のたびに同じ行が追記され続ける（issue #33 の既存欠陥#1。作り直しで再発させたのを
  # test_install_to_project.sh の「CRLFの配布先でも1行のまま」が捕まえた）。
  local existing
  existing="$(mktemp)"
  if [ -f "$dst" ]; then
    tr -d '\r' < "$dst" > "$existing"
  else
    : > "$existing"
  fi

  # 既存行は連想配列へ1回で読み込む。候補ごとに `grep` を起動すると行数に比例して
  # 外部プロセスが増える（git bashでは1回あたり約95ms。
  # .claude/rules/shell-script-style.md「外部プロセス起動のコスト」）。
  local -A have=()
  while IFS= read -r line || [ -n "$line" ]; do
    have["$line"]=1
  done < "$existing"
  rm -f "$existing"

  for line in "${candidates[@]}"; do
    [ -z "${have[$line]+x}" ] || continue
    to_add+=("$line")
  done

  if [ "${#to_add[@]}" -gt 0 ]; then
    # 末尾に改行が無いファイルへ追記すると行が連結されるため、先に補う。
    if [ -s "$dst" ] && [ "$(tail -c1 "$dst" | wc -l)" -eq 0 ]; then
      printf '\n' >> "$dst"
    fi
    printf '%s\n' "${to_add[@]}" >> "$dst"
    added="${#to_add[@]}"
  fi
  REPLY="$added"
}

# 指定したキーパスだけを本家の値で更新する。
# 値が配列なら**和集合**（配布先が足した行を消さない）、それ以外は**全置換**。
# permissions.deny が配列、hooks がオブジェクトなので、この規則だけで両方の要件を満たす。
merge_json_keys() {
  local src="$1" dst="$2" keys_csv="$3" key tmp
  # **マージ前に配布先のファイルを検証する。** 無効なJSONのまま jq へ渡すと jq が失敗し、
  # リダイレクトで空になった一時ファイルをそのまま書き戻して配布先を**0バイトへ破壊する**。
  # `merge` 層は .bak を作らないので回復不能で、しかも0バイトになると次回以降も同じ経路で
  # 失敗し続ける（.claude/rules/shell-script-style.md「上記の失敗が別の関数へ波及して
  # 恒久化するケース」そのもの）。
  # **空文字列の検査を `jq -e .` より先に行う**（`jq -e .` は空入力に対して成功を返すことがある）。
  if [ ! -s "$dst" ] || ! jq -e . "$dst" > /dev/null 2>&1; then
    printf 'エラー: 配布先が空、または有効なJSONではありません: %s\n' "$dst" >&2
    printf '       手で修復するか退避してから再実行してください（このファイルは変更していません）。\n' >&2
    return 1
  fi
  tmp="$(mktemp)"
  local IFS=','
  # shellcheck disable=SC2206
  local -a keys=($keys_csv)
  unset IFS

  for key in "${keys[@]}"; do
    [ -n "$key" ] || continue
    jq --slurpfile up "$src" --arg key "$key" '
      ($key | split(".")) as $p
      | ($up[0] | getpath($p)) as $v
      | if $v == null then .
        elif ($v | type) == "array" then
          setpath($p; ((getpath($p) // []) + $v | unique))
        else setpath($p; $v)
        end
    ' "$dst" > "$tmp" || {
      # jq の終了コードを見てから書き戻す。見ないと、空になった $tmp で $dst を上書きする。
      printf 'エラー: %s のキー %s の更新に失敗しました\n' "$dst" "$key" >&2
      rm -f "$tmp"
      return 1
    }
    tr -d '\r' < "$tmp" > "$dst"
  done
  rm -f "$tmp"
}

# manifest へ記録する merge の指紋を返す（再適用時の変更検知に使う）。
merge_fingerprint_json() {
  local dst="$1" strategy="$2" keys_csv="$3"
  if [ "$strategy" = 'lines-marker' ]; then
    local h
    h="$(tr -d '\r' < "$dst" | sha256sum | cut -d' ' -f1)"
    jq -nc --arg s "$strategy" --arg h "$h" '{strategy:$s, lines:$h}'
  else
    # キーごとに値を取り出して sha256 を取る（値そのもの（例: hooks）は数KBになるため、
    # manifest へは指紋だけを載せる）。キーは高々数個なので起動回数も抑えられる。
    local key h
    local -a pairs=()
    local IFS=','
    # shellcheck disable=SC2206
    local -a keys=($keys_csv)
    unset IFS
    for key in "${keys[@]}"; do
      [ -n "$key" ] || continue
      h="$(jq -c --arg key "$key" 'getpath($key | split("."))' "$dst" | sha256sum | cut -d' ' -f1)"
      pairs+=("$key" "$h")
    done
    # 位置引数はフィルタの直後の `--` 以降へ置く（先頭がハイフンの値をオプションと
    # 解釈させないため。.claude/rules/shell-script-style.md）。
    jq -nc --arg s "$strategy" --args '
      {strategy:$s,
       keys: ( $ARGS.positional
               | [ range(0; length; 2) as $i | { ($ARGS.positional[$i]): $ARGS.positional[$i+1] } ]
               | add // {} )}
    ' -- "${pairs[@]}"
  fi
}

# ---- 走査パス（ファイルを一切変更しない） ----------------------------------

declare -a SCAN_CORE_NEW=() SCAN_CORE_SAME=() SCAN_CORE_MODIFIED=() SCAN_CORE_UNKNOWN=()
declare -a SCAN_SEED_PLACE=() SCAN_SEED_KEEP=() SCAN_MERGE=()
MANIFEST_EXISTS=0

scan_pass() {
  local manifest="${DEST_DIR}/${MANIFEST_REL}"
  local -A prev_sha=()
  local p dst_path src_abs recorded

  if [ -f "$manifest" ] && jq -e . "$manifest" > /dev/null 2>&1; then
    MANIFEST_EXISTS=1
    local line f h
    while IFS=$'\037' read -r f h; do
      [ -n "$f" ] || continue
      prev_sha["$f"]="$h"
    done < <(jq -r '.files[]? | select(.sha256) | [.path, .sha256] | join("\u001f")' "$manifest" | tr -d '\r')
  fi

  for p in "${PLAN_PATHS[@]}"; do
    dst_path="${DEST_DIR}/${p}"
    src_abs="${UPSTREAM_ROOT}/${PLAN_SRC[$p]}"
    case "${PLAN_LAYER[$p]}" in
      core)
        if [ ! -e "$dst_path" ]; then
          SCAN_CORE_NEW+=("$p")
        else
          sha256_lf_to_reply "$dst_path"
          recorded="${prev_sha[$p]:-}"
          if [ -z "$recorded" ]; then
            # 旧方式で適用済み・manifest を持たない配布先の初回再適用。
            # 「改変済み」ではなく「差分を確認できない（移行）」として一覧へ出し、.bak は作る。
            SCAN_CORE_UNKNOWN+=("$p")
          elif [ "$REPLY" = "$recorded" ]; then
            SCAN_CORE_SAME+=("$p")
          else
            SCAN_CORE_MODIFIED+=("$p")
          fi
        fi
        ;;
      seed)
        if [ -e "$dst_path" ]; then
          SCAN_SEED_KEEP+=("$p")
        else
          [ -f "$src_abs" ] || { printf 'エラー: seed の配布元がありません: %s\n' "$src_abs" >&2; return 1; }
          SCAN_SEED_PLACE+=("$p")
        fi
        ;;
      merge)
        SCAN_MERGE+=("$p")
        ;;
    esac
  done
  return 0
}

# ---- 一覧の提示（受け入れ条件4・5） ----------------------------------------

present_plan() {
  log_section '配布計画'
  printf '本家: %s\n配布先: %s\n' "$UPSTREAM_ROOT" "$DEST_DIR"
  printf 'manifest: %s\n' \
    "$([ "$MANIFEST_EXISTS" -eq 1 ] && echo '既存あり（差分を判定します）' || echo '無し（初回、または旧方式からの移行）')"

  printf '\ncore  : 新規 %s / 変更なし %s / **適用後に変更された %s** / 判定不能 %s\n' \
    "${#SCAN_CORE_NEW[@]}" "${#SCAN_CORE_SAME[@]}" "${#SCAN_CORE_MODIFIED[@]}" "${#SCAN_CORE_UNKNOWN[@]}"
  printf 'seed  : 新規に置く %s / 既にあるので触らない %s\n' \
    "${#SCAN_SEED_PLACE[@]}" "${#SCAN_SEED_KEEP[@]}"
  printf 'merge : %s\n' "${#SCAN_MERGE[@]}"

  if [ "${#SCAN_CORE_MODIFIED[@]}" -gt 0 ]; then
    printf '\n警告: 次の core ファイルは適用後に配布先で変更されています。上書きします。\n'
    printf '      （%s）\n' \
      "$([ "$OPT_FORCE" -eq 1 ] && echo '--force のため .bak を作りません' || echo '元の内容は .bak として残します')"
    printf '  - %s\n' "${SCAN_CORE_MODIFIED[@]}"
  fi
  if [ "${#SCAN_CORE_UNKNOWN[@]}" -gt 0 ]; then
    printf '\n警告: 次の core ファイルは manifest が無いため差分を確認できません（旧方式からの移行）。\n'
    printf '      上書きします。（%s）\n' \
      "$([ "$OPT_FORCE" -eq 1 ] && echo '--force のため .bak を作りません。配布先の変更は退避されずに失われます' || echo '元の内容は .bak として残します')"
    printf '  - %s\n' "${SCAN_CORE_UNKNOWN[@]}"
  fi
  if [ "${#SCAN_SEED_KEEP[@]}" -gt 0 ]; then
    printf '\n触らない seed（配布先所有）:\n'
    printf '  - %s\n' "${SCAN_SEED_KEEP[@]}"
  fi
  if [ "${#SCAN_MERGE[@]}" -gt 0 ]; then
    printf '\nマージ対象:\n'
    local p
    for p in "${SCAN_MERGE[@]}"; do
      printf '  - %s（%s）\n' "$p" "${PLAN_STRATEGY[$p]}"
    done
  fi
}

# ---- 配置パス --------------------------------------------------------------

declare -a APPLIED_BAK=()
MERGE_ADDED_TOTAL=0

apply_pass() {
  local p dst_path src_abs
  local -a overwrite=()
  overwrite+=("${SCAN_CORE_NEW[@]}" "${SCAN_CORE_SAME[@]}" "${SCAN_CORE_MODIFIED[@]}" "${SCAN_CORE_UNKNOWN[@]}")

  for p in "${overwrite[@]}"; do
    [ -n "$p" ] || continue
    dst_path="${DEST_DIR}/${p}"
    src_abs="${UPSTREAM_ROOT}/${PLAN_SRC[$p]}"
    mkdir -p "$(dirname "$dst_path")"
    # 改変済み・判定不能なら .bak を残す（--force のときは残さない）。
    if [ -e "$dst_path" ] && [ "$OPT_FORCE" -eq 0 ]; then
      if _in_list "$p" "${SCAN_CORE_MODIFIED[@]}" || _in_list "$p" "${SCAN_CORE_UNKNOWN[@]}"; then
        cp "$dst_path" "${dst_path}.bak"
        APPLIED_BAK+=("${p}.bak")
      fi
    fi
    if [ "$p" = "$DEF_REL" ]; then
      # **配布先では `upstream` の印を落とす。** 付いたまま配ると、配布先で網羅性チェックが
      # 「本家のもの」として走り、配布先の自前ソースを全件未分類として報告する。
      # install-to-project.sh 自身も手順2cでこの検査を通すため、配布先をカレントにした
      # 再適用が始まらなくなる。
      local def_tmp
      def_tmp="$(mktemp)"
      jq 'del(.upstream)' "$src_abs" > "$def_tmp" || {
        printf 'エラー: 層分け定義から upstream を落とせませんでした: %s\n' "$src_abs" >&2
        rm -f "$def_tmp"
        return 1
      }
      tr -d '\r' < "$def_tmp" > "$dst_path"
      rm -f "$def_tmp"
    else
      cp "$src_abs" "$dst_path"
    fi
  done

  for p in "${SCAN_SEED_PLACE[@]}"; do
    [ -n "$p" ] || continue
    dst_path="${DEST_DIR}/${p}"
    mkdir -p "$(dirname "$dst_path")"
    cp "${UPSTREAM_ROOT}/${PLAN_SRC[$p]}" "$dst_path"
  done

  for p in "${SCAN_MERGE[@]}"; do
    [ -n "$p" ] || continue
    dst_path="${DEST_DIR}/${p}"
    src_abs="${UPSTREAM_ROOT}/${PLAN_SRC[$p]}"
    case "${PLAN_STRATEGY[$p]}" in
      lines-marker)
        if ! extract_marker_lines "$src_abs" > /dev/null; then
          printf 'エラー: %s に %s が見つかりません（配る行を特定できません）\n' \
            "${PLAN_SRC[$p]}" "$MARKER_BEGIN" >&2
          return 1
        fi
        [ -e "$dst_path" ] || { mkdir -p "$(dirname "$dst_path")"; : > "$dst_path"; }
        append_missing_lines "$src_abs" "$dst_path" "${PLAN_HEADER[$p]}"
        MERGE_ADDED_TOTAL=$((MERGE_ADDED_TOTAL + REPLY))
        printf '  %s: %s 行を追記\n' "$p" "$REPLY"
        ;;
      json-keys)
        if [ ! -e "$dst_path" ]; then
          mkdir -p "$(dirname "$dst_path")"
          cp "$src_abs" "$dst_path"
          printf '  %s: 新規に配置\n' "$p"
        else
          merge_json_keys "$src_abs" "$dst_path" "${PLAN_KEYS[$p]}"
          printf '  %s: キー %s を更新\n' "$p" "${PLAN_KEYS[$p]}"
        fi
        ;;
      *)
        printf 'エラー: 未知の strategy: %s（%s）\n' "${PLAN_STRATEGY[$p]}" "$p" >&2
        return 1
        ;;
    esac
  done
  return 0
}

_in_list() {
  local needle="$1"; shift
  local x
  for x in "$@"; do [ "$x" = "$needle" ] && return 0; done
  return 1
}

# ---- manifest の書き出し ---------------------------------------------------

write_manifest() {
  local commit version url entries_file p dst_path
  commit="$(git -C "$UPSTREAM_ROOT" rev-parse HEAD)"
  # オプションの有無ではなく、**実際に未コミットの変更があったか**で付ける。
  # --allow-dirty を常用する運用でも、クリーンなコミットからの配布はそう記録される。
  [ "$UPSTREAM_DIRTY" -eq 0 ] || commit="${commit}-dirty"
  version="$(tr -d '\r\n' < "${UPSTREAM_ROOT}/.claude/VERSION" 2>/dev/null || echo 'unknown')"
  url="$(git -C "$UPSTREAM_ROOT" remote get-url origin 2>/dev/null || echo '')"

  entries_file="$(mktemp)"
  for p in "${PLAN_PATHS[@]}"; do
    dst_path="${DEST_DIR}/${p}"
    case "${PLAN_LAYER[$p]}" in
      core)
        sha256_lf_to_reply "$dst_path"
        jq -nc --arg p "$p" --arg h "$REPLY" '{path:$p, layer:"core", sha256:$h}'
        ;;
      seed)
        [ -e "$dst_path" ] || continue
        sha256_lf_to_reply "$dst_path"
        jq -nc --arg p "$p" --arg h "$REPLY" --argjson placed \
          "$(_in_list "$p" "${SCAN_SEED_PLACE[@]}" && echo true || echo false)" \
          '{path:$p, layer:"seed", sha256:$h, placed:$placed}'
        ;;
      merge)
        merge_fingerprint_json "$dst_path" "${PLAN_STRATEGY[$p]}" "${PLAN_KEYS[$p]}" \
          | jq -c --arg p "$p" '{path:$p, layer:"merge"} + .'
        ;;
      # local / exclude は書かない（書くと「配布した」と誤読される）。
    esac
  done > "$entries_file"

  mkdir -p "$(dirname "${DEST_DIR}/${MANIFEST_REL}")"
  # ファイル一覧は件数が可変なので、コマンドライン引数ではなくファイル経由でjqへ渡す
  # （.claude/rules/shell-script-style.md「大きなJSONを引数として渡さない」）。
  jq -s --arg commit "$commit" --arg version "$version" --arg url "$url" \
        --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
    { schemaVersion: 1,
      source: { url: $url, commit: $commit, version: $version },
      appliedAt: $at,
      files: . }
  ' "$entries_file" | tr -d '\r' > "${DEST_DIR}/${MANIFEST_REL}"
  rm -f "$entries_file"
}

# ---- 本体 ------------------------------------------------------------------

main() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) OPT_DRY_RUN=1; shift ;;
      --force) OPT_FORCE=1; shift ;;
      --allow-dirty) OPT_ALLOW_DIRTY=1; shift ;;
      -h|--help) usage; return 0 ;;
      -*) printf 'エラー: 不明なオプション %s\n' "$1" >&2; usage >&2; return 2 ;;
      *) DEST_DIR="$1"; shift ;;
    esac
  done

  if [ -z "$DEST_DIR" ]; then
    printf 'エラー: 配布先ディレクトリを指定してください\n' >&2
    usage >&2
    return 2
  fi
  DEST_DIR="$(cd "$DEST_DIR" 2>/dev/null && pwd)" || {
    printf 'エラー: 配布先が存在しません\n' >&2; return 2; }

  # 手順2a: 配布先がgitリポジトリか
  if ! git -C "$DEST_DIR" rev-parse --git-dir > /dev/null 2>&1; then
    printf 'エラー: 配布先がgitリポジトリではありません: %s\n' "$DEST_DIR" >&2
    return 2
  fi
  if [ "$DEST_DIR" = "$UPSTREAM_ROOT" ]; then
    printf 'エラー: 配布先が本家と同じです\n' >&2
    return 2
  fi
  [ -f "$DEF_FILE" ] || { printf 'エラー: 層分け定義がありません: %s\n' "$DEF_FILE" >&2; return 2; }

  # **これらを `func || return 1` の形で呼ばないこと。** `||` の左辺は条件式であり、bashは
  # 条件式として評価される関数の**内部にまで** `set -e` の一時停止を及ぼす。そうすると関数内の
  # `jq` / `cp` / `mkdir` が失敗しても処理が先へ進み、戻り値は「最後に実行したコマンドの
  # 終了コード」になる（.claude/rules/shell-script-style.md「エラー方針」）。
  # これらの関数はいずれもグローバル変数へ結果を書くためサブシェルで包めないので、素で呼んで
  # `set -e` に任せる（各関数は中断前に自分でエラーメッセージを出す）。

  # 手順3: 定義の読み込み（dirty判定の対象を決めるため、検証より先に行う）
  build_plan

  # 手順2b: 本家の dirty 判定（受け入れ条件6）
  check_upstream_clean

  # 手順2c: 網羅性チェック（受け入れ条件1）
  # **定義ファイルを絶対パスで渡す。** check-dist-coverage.sh は既定で相対パスの定義と
  # cwd 基準の `git ls-files` を見るため、渡さないと「起動時のカレントディレクトリのリポジトリ」を
  # 検査してしまう（配布先を cwd にして実行すると必ず中断していた）。
  if ! bash "${UPSTREAM_ROOT}/.claude/scripts/src/check-dist-coverage.sh" --def "$DEF_FILE" \
       > /dev/null 2>&1; then
    printf 'エラー: 層分け定義の網羅性チェックに失敗しました。次を実行して内容を確認してください:\n' >&2
    printf '  bash %s --def %s\n' \
      "${UPSTREAM_ROOT}/.claude/scripts/src/check-dist-coverage.sh" "$DEF_FILE" >&2
    return 1
  fi

  # 手順4: 走査パス
  scan_pass

  # 手順5: 提示
  present_plan
  if [ "$OPT_DRY_RUN" -eq 1 ]; then
    printf '\n--dry-run のためここで終了します（何も変更していません）。\n'
    return 0
  fi

  # 手順6: 配置パス
  log_section '配置'
  apply_pass

  # 手順7: 配布先で .gemini/ のリンクを作る（「local は触らない」の唯一の例外）
  log_section '.gemini/ のセットアップ'
  bash "${DEST_DIR}/.claude/scripts/src/setup-gemini-links.sh" || {
    printf '警告: .gemini/ のセットアップに失敗しました。配布先で手動実行してください。\n' >&2; }

  # 手順8: manifest
  write_manifest

  # 手順9: サマリ
  log_section 'サマリ'
  printf 'core を %s 件配置しました（うち .bak を残した %s 件）。\n' \
    "$((${#SCAN_CORE_NEW[@]} + ${#SCAN_CORE_SAME[@]} + ${#SCAN_CORE_MODIFIED[@]} + ${#SCAN_CORE_UNKNOWN[@]}))" \
    "${#APPLIED_BAK[@]}"
  printf 'seed を %s 件配置し、%s 件は既存を残しました。\n' \
    "${#SCAN_SEED_PLACE[@]}" "${#SCAN_SEED_KEEP[@]}"
  printf 'merge %s 件（追記した行の合計 %s）。\n' "${#SCAN_MERGE[@]}" "$MERGE_ADDED_TOTAL"
  printf 'manifest: %s\n' "${DEST_DIR}/${MANIFEST_REL}"
  if [ "${#APPLIED_BAK[@]}" -gt 0 ]; then
    printf '\n配布先で変更されていたファイルの元の内容は次に残しました:\n'
    printf '  - %s\n' "${APPLIED_BAK[@]}"
  fi
  printf '\n次にやること:\n'
  printf '  1. AGENTS.md の「プロジェクト概要」「開発・実行」を、このプロジェクトの内容で埋める。\n'
  printf '  2. .mrworkflow.json のブランチ命名規則・ディレクトリ位置を確認する。\n'
  printf '  3. 各ディレクトリの REVIEW-POINTS.local.md へ、このプロジェクト固有の観点を書く。\n'
  return 0
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
