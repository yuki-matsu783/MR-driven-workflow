#!/usr/bin/env bash
# 収穫（逆輸入）スキルの分析スクリプト（issue #27）。
# 配布先プロジェクトの AI アセット改変（modified / added / deleted）を、本家を1バイトも
# 変更せずに分析して JSON で報告する。取り込みの判断・issue 起票は SKILL.md 側の手順が担う。
#
# 読み取り専用の保証: 本家・配布先のワークツリーを変更しない。書き込みは mktemp -d の
# 一時領域のみ。git 操作は show / cat-file / ls-files / ls-tree / log / rev-parse /
# archive / merge-file（-p で標準出力へ）に限る（いずれも読み取り専用。add / checkout /
# clean / stash 等の書き込み系サブコマンドは使わない）。
#
# 使い方:
#   bash harvest-from-projects.sh [--upstream <dir>] scan <配布先パス>...
#   bash harvest-from-projects.sh [--upstream <dir>] diff <配布先パス> <相対パス>
#   bash harvest-from-projects.sh [--upstream <dir>] merge3 <配布先パス> <相対パス>
#
# merge3 の終了コード（git merge-file の 0／1〜127（衝突数）／≧128（エラー）をそのまま
# 露出させず、意味ごとに正規化する）:
#   0=衝突なし / 1=衝突あり / 2=base 取得不可のため 2-way へ縮退 /
#   3=その他エラー（層を判定できない場合のフェイルクローズを含む） /
#   4=3-way の対象外（merge 層・seed 層・.claude/dist-layers.json）
set -euo pipefail

readonly MANIFEST_REL='.claude/.asset-manifest.json'
readonly DIST_LAYERS_REL='.claude/dist-layers.json'

UPSTREAM_ROOT=''
TMP_DIR=''

usage() {
  # 冒頭コメントブロック（2行目〜コメントでない最初の行の手前）をそのまま出す。
  # 行番号の固定値はコメント追記のたびにずれるため使わない（install-to-project.sh と同型）
  awk 'NR >= 2 { if ($0 !~ /^#/) exit; sub(/^# ?/, ""); print }' "${BASH_SOURCE[0]}"
}

cleanup_tmp() {
  [ -z "$TMP_DIR" ] || rm -rf "$TMP_DIR"
}

ensure_tmp() {
  if [ -z "$TMP_DIR" ]; then
    TMP_DIR="$(mktemp -d)"
    trap cleanup_tmp EXIT
  fi
}

# ---- 純粋関数（source して単体テスト可能） ---------------------------------

# 記録SHAから -dirty 接尾辞を除去する。REPLY=素のSHA / REPLY_WAS_DIRTY=1|0
strip_dirty_to_reply() {
  local sha="$1"
  REPLY="$sha"
  REPLY_WAS_DIRTY=0
  if [ "${sha%-dirty}" != "$sha" ]; then
    REPLY="${sha%-dirty}"
    REPLY_WAS_DIRTY=1
  fi
}

# 層解決: path を持つエントリとの直接照合（完全一致＋ディレクトリ前方一致）で、
# エントリ順の後勝ち。build_plan の git ls-files 展開は「本家に無いパス」（added 候補）へ
# 適用できないため、pathspec 文字列との直接照合を自前で行う（調査結果 Q8。
# dist-layers.json の path は現状すべてディレクトリ名かファイルパスそのもので glob を含まない）。
# 入力: $1=候補相対パス。グローバル LAYER_ENTRY_PATHS / LAYER_ENTRY_LAYERS を参照。
# 出力: REPLY=解決された層（どのエントリにも一致しなければ空）
resolve_layer_to_reply() {
  local candidate="$1" i entry
  REPLY=''
  for ((i = 0; i < ${#LAYER_ENTRY_PATHS[@]}; i++)); do
    entry="${LAYER_ENTRY_PATHS[$i]}"
    if [ "$candidate" = "$entry" ] || [[ "$candidate" == "$entry"/* ]]; then
      REPLY="${LAYER_ENTRY_LAYERS[$i]}"
    fi
  done
}

# gitignore 規則のサブセット照合（一致なら終了コード0）。
# 対応: 先頭 `/`（ルート相対アンカー）・末尾 `/`（ディレクトリ）・`**/`（任意階層）・
# スラッシュ無しパターン（任意階層のセグメント一致）。dist-layers.json の gitignorePattern
# 9件を配布先の実ファイルへ当てるための限定実装で、git check-ignore は使わない
# （check-ignore が見るのは配布先の実 .gitignore で参照データが違い、除外の「正」が
# 2つになるため。除外の正は配布先の dist-layers.json の1つだけ）。
gitignore_matches() {
  local pat="$1" cand="$2" dir=0 anchored=0
  [ -n "$pat" ] || return 1
  case "$pat" in */) dir=1; pat="${pat%/}" ;; esac
  case "$pat" in /*) anchored=1; pat="${pat#/}" ;; esac
  case "$pat" in '**/'*) pat="${pat#\*\*/}"; anchored=0 ;; esac
  if [[ "$pat" != */* ]]; then
    # アンカー付き（元が /usage/ のような形）はルート直下のセグメントにだけ一致させる
    if [ "$anchored" -eq 1 ]; then
      if [ "$dir" -eq 1 ]; then
        # shellcheck disable=SC2254
        case "$cand" in $pat/*) return 0 ;; esac
      else
        # shellcheck disable=SC2254
        case "$cand" in $pat | $pat/*) return 0 ;; esac
      fi
      return 1
    fi
    # スラッシュ無し: 任意階層のセグメントと照合する（ディレクトリパターンは
    # 「最終セグメント以外」＝ディレクトリにのみ一致させる）
    local IFS='/'
    # shellcheck disable=SC2206
    local -a segs=($cand)
    unset IFS
    local n="${#segs[@]}" i
    for ((i = 0; i < n; i++)); do
      # shellcheck disable=SC2254
      case "${segs[$i]}" in
        $pat)
          if [ "$dir" -eq 1 ]; then
            [ "$i" -lt "$((n - 1))" ] && return 0
          else
            return 0
          fi
          ;;
      esac
    done
    return 1
  fi
  # スラッシュを含むパターン
  if [ "$anchored" -eq 1 ]; then
    # shellcheck disable=SC2254
    case "$cand" in $pat | $pat/*) return 0 ;; esac
    return 1
  fi
  # shellcheck disable=SC2254
  case "$cand" in $pat | $pat/* | */$pat | */$pat/*) return 0 ;; esac
  return 1
}

# added 候補から機構自身の生成物を除外する（一致なら終了コード0=除外）。
# manifest 自身と *.bak（install-to-project.sh が改変済み core を上書きする際の退避）は、
# dist-layers のどのエントリにも当たらないのに全配布先へ必ず存在するため明示的に弾く。
is_harvest_infra_path() {
  local cand="$1"
  [ "$cand" = "$MANIFEST_REL" ] && return 0
  case "$cand" in *.bak) return 0 ;; esac
  return 1
}

# ---- LF 正規化 sha256 の一括計算（install-to-project.sh と同型） -----------

declare -A SHA_RESULT=()
sha256_lf_batch() {
  SHA_RESULT=()
  [ "$#" -gt 0 ] || return 0
  local list nocr f line h path
  local -A has_cr=()
  list="$(mktemp)"
  nocr="$(mktemp)"
  printf '%s\0' "$@" > "$list"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    has_cr["$f"]=1
  done < <(xargs -0 grep -lU -e $'\r' -- < "$list" 2>/dev/null || true)
  for f in "$@"; do
    if [ -n "${has_cr[$f]+x}" ]; then
      h="$(tr -d '\r' < "$f" | sha256sum)"
      SHA_RESULT["$f"]="${h%% *}"
    else
      printf '%s\0' "$f" >> "$nocr"
    fi
  done
  if [ -s "$nocr" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      h="${line%% *}"
      path="${line#* }"
      path="${path# }"
      SHA_RESULT["$path"]="$h"
    done < <(xargs -0 sha256sum -- < "$nocr")
  fi
  rm -f "$list" "$nocr"
  if [ "${#SHA_RESULT[@]}" -ne "$#" ]; then
    printf 'エラー: sha256 の一括計算で件数が合いません（要求 %s 件 / 取得 %s 件）\n' \
      "$#" "${#SHA_RESULT[@]}" >&2
    return 1
  fi
}

# ---- 配布先の層分け定義の読み込み ------------------------------------------

# 除外の正は配布先へ配布された dist-layers.json（del(.upstream) 済み）の1つだけ。
# 本家側の定義で解くと「配布当時は core だったファイル」が後の層変更で対象外になり
# 配布先ごとに結果が揺れる（敵対的レビュー3回目の指摘）。
declare -a LAYER_ENTRY_PATHS=() LAYER_ENTRY_LAYERS=() LOCAL_IGNORE_PATTERNS=()
load_dest_layers() { # $1=配布先ルート。読めなければ非0
  local dest="$1" file="$1/${DIST_LAYERS_REL}" line
  LAYER_ENTRY_PATHS=()
  LAYER_ENTRY_LAYERS=()
  LOCAL_IGNORE_PATTERNS=()
  [ -s "$file" ] || return 1
  jq -e . "$file" > /dev/null 2>&1 || return 1
  while IFS=$'\037' read -r kind a b; do
    case "$kind" in
      P)
        LAYER_ENTRY_PATHS+=("$a")
        LAYER_ENTRY_LAYERS+=("$b")
        ;;
      G) LOCAL_IGNORE_PATTERNS+=("$a") ;;
    esac
  done < <(jq -r '
    .entries[]
    | if .path then ["P", .path, .layer] else ["G", (.gitignorePattern // ""), .layer] end
    | join("\u001f")
  ' "$file" | tr -d '\r')
  [ "${#LAYER_ENTRY_PATHS[@]}" -gt 0 ]
}

# ---- 本家側の情報（対象ごとに1回だけ取得） ---------------------------------

declare -A UP_HAS_PATH=() UP_DELETED_PATH=()
load_upstream_path_sets() {
  UP_HAS_PATH=()
  UP_DELETED_PATH=()
  local p
  while IFS= read -r -d '' p; do
    [ -n "$p" ] || continue
    UP_HAS_PATH["$p"]=1
  done < <(git -C "$UPSTREAM_ROOT" ls-tree -r --name-only -z HEAD)
  # 本家の履歴上で一度でも「無くなった」パス。改名（git mv）は既定の改名検出で R に
  # 分類され D に現れないため、--no-renames で削除＋新規追加として数える（改名の旧パスも
  # 拾う。実例: issue #133 のDDR一括改名）。core.quotepath=false を付けないと非ASCIIパスが
  # 8進エスケープでクォートされ、実パスとの突き合わせが全件空振りする（DDR等の日本語
  # ファイル名が主要な対象なので必須）。1回の git 起動で全件取り、「配布先の新規追加」と
  # 「本家の削除漏れ」の区別材料にする（調査結果 Q8）。
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    UP_DELETED_PATH["$p"]=1
  done < <(git -C "$UPSTREAM_ROOT" -c core.quotepath=false log --no-renames --diff-filter=D --name-only --format= 2>/dev/null | tr -d '\r' | sort -u)
}

# ---- 判断材料（配布先の git 履歴。1回の git 起動で全ファイルぶん集計） -----

declare -A DEST_CHANGE_COUNT=() DEST_AI_COUNT=()
DEST_IS_GIT=0
load_dest_history() { # $1=配布先ルート
  local dest="$1" line p cnt ai
  DEST_CHANGE_COUNT=()
  DEST_AI_COUNT=()
  DEST_IS_GIT=0
  git -C "$dest" rev-parse --git-dir > /dev/null 2>&1 || return 0
  DEST_IS_GIT=1
  # コミットごとの件名とファイル一覧を1回で取り、awk 1回でファイル別に畳み込む
  # （ファイルごとに git log を起動しない。git bash では起動回数が所要時間を決めるため）。
  # core.quotepath=false を付けないと非ASCIIパスが8進エスケープでクォートされ、
  # 畳み込みキーが実パスと一致せず件数が全件0へ落ちる（load_upstream_path_sets と同根）。
  while IFS=$'\037' read -r p cnt ai; do
    [ -n "$p" ] || continue
    DEST_CHANGE_COUNT["$p"]="$cnt"
    DEST_AI_COUNT["$p"]="$ai"
  done < <(git -C "$dest" -c core.quotepath=false log --format='%x01%s' --name-only 2>/dev/null | tr -d '\r' | awk '
    # 件名行の目印は %x01 の生バイト。awk 側は POSIX の8進文字列 "\001" で比較する
    # （正規表現の \x エスケープは処理系依存のため使わない）
    substr($0, 1, 1) == "\001" { ai = (substr($0, 2) ~ /^ai-asset:/) ? 1 : 0; next }
    NF { cnt[$0]++; if (ai) aic[$0]++ }
    END { for (p in cnt) printf "%s\037%d\037%d\n", p, cnt[p], aic[p] + 0 }
  ')
}

# ---- merge 層の指紋比較 ----------------------------------------------------

# $1=配布先の実ファイル $2=strategy $3=記録済み lines（lines-marker） $4=記録済み keys JSON
# 一致（変更なし）なら終了コード0。merge レコードは sha256 キーを持たないため、
# core と同じ読み方をすると null になり全件が片側へ無言で倒れる（調査結果 Q1/Q8）。
merge_fingerprint_unchanged() {
  local file="$1" strategy="$2" rec_lines="$3" rec_keys_json="$4"
  if [ "$strategy" = 'lines-marker' ]; then
    # 記録側 merge_fingerprint_json と同一の式（LF正規化後のファイル全体 sha256）。
    local h
    h="$(tr -d '\r' < "$file" | sha256sum)"
    [ "${h%% *}" = "$rec_lines" ]
    return
  fi
  # strategy は明示的に分岐する。未知・欠落は「変更なし」ではなく「変更あり」側へ倒す
  # （フェイルオープンにすると配布先の改変が無言で候補から落ち、出力からは異常が読めない。
  # install-to-project.sh の apply_pass が未知 strategy で止めるのと同じ向き）
  [ "$strategy" = 'json-keys' ] || return 1
  # 記録された keys が空なら比較対象が無く判定不能＝「変更あり」側へ倒す
  case "$rec_keys_json" in '' | '{}' | 'null') return 1 ;; esac
  # json-keys: キーごとの jq -c getpath 出力の sha256（この経路だけ正規化なし。記録側と同一）
  local key rec_h cur_h
  while IFS=$'\037' read -r key rec_h; do
    [ -n "$key" ] || continue
    cur_h="$(jq -c --arg key "$key" 'getpath($key | split("."))' "$file" | sha256sum)"
    [ "${cur_h%% *}" = "$rec_h" ] || return 1
  done < <(printf '%s' "$rec_keys_json" | jq -r 'to_entries[] | [.key, .value] | join("\u001f")' | tr -d '\r')
  return 0
}

# ---- base の解決 -----------------------------------------------------------

# 記録SHAの解決。REPLY=解決できたSHA（空=未到達）/ REPLY_BASE_APPROX=1|0
# -dirty 付きは「落として解決を試み、解決できたら近似フラグを立てる」（調査結果 Q3 の
# 縮退順序1。一律 base 取得不可にすると --allow-dirty 配布の配布先で衝突区別が丸ごと死ぬ）。
resolve_base_sha_to_reply() {
  local recorded="$1"
  strip_dirty_to_reply "$recorded"
  local sha="$REPLY"
  REPLY_BASE_APPROX="$REPLY_WAS_DIRTY"
  REPLY=''
  [ -n "$sha" ] || return 0
  if git -C "$UPSTREAM_ROOT" cat-file -e "${sha}^{commit}" 2>/dev/null; then
    REPLY="$sha"
  else
    REPLY_BASE_APPROX=0
  fi
}

# 指定リビジョンのファイル内容をLF正規化して一時ファイルへ書く。REPLY=一時ファイルパス（空=取得不可）
materialize_upstream_to_reply() { # $1=リビジョン $2=相対パス
  local rev="$1" rel="$2" out
  ensure_tmp
  out="$(mktemp -p "$TMP_DIR")"
  REPLY=''
  if [ "$rel" = "$DIST_LAYERS_REL" ]; then
    # dist-layers.json は del(.upstream) を掛けた内容が配布されるため、本家側にも同じ
    # 変換を掛けないと upstream キーぶんの差分が常に出る（調査結果 Q3）。
    if git -C "$UPSTREAM_ROOT" show "${rev}:${rel}" 2>/dev/null | tr -d '\r' | jq 'del(.upstream)' > "$out" 2>/dev/null \
      && [ -s "$out" ]; then
      REPLY="$out"
    fi
    return 0
  fi
  if git -C "$UPSTREAM_ROOT" show "${rev}:${rel}" 2>/dev/null | tr -d '\r' > "$out"; then
    # git show は存在しないパスで空出力＋非0になるが、パイプ越しでは検知が甘くなるため
    # 存在確認を別に行う
    if git -C "$UPSTREAM_ROOT" cat-file -e "${rev}:${rel}" 2>/dev/null; then
      REPLY="$out"
    fi
  fi
  return 0
}

# ---- scan ------------------------------------------------------------------

# 1配布先ぶんの target JSON を組み立てて $TARGETS_FILE へ追記する
declare TARGETS_FILE=''

emit_error_target() { # $1=path $2=理由
  jq -nc --arg p "$1" --arg e "$2" '{path: $p, error: $e}' >> "$TARGETS_FILE"
}

scan_one_dest() { # $1=配布先パス
  local dest="$1"
  if [ ! -d "$dest" ]; then
    emit_error_target "$dest" '配布先ディレクトリが存在しません'
    return 0
  fi
  dest="$(cd "$dest" && pwd)"

  local manifest="$dest/$MANIFEST_REL" manifest_ok=0
  # 妥当な JSON であるだけでは足りない: .files が空（または形式違いで1件も読めない）状態で
  # 通常経路へ進むと、added 判定が全件素通りして配布先の全ファイルを added と誤報する。
  # schemaVersion の不一致（install 側の将来の形式変更）も同じ形で壊れるため、ここで縮退へ倒す
  if [ -s "$manifest" ] \
    && jq -e '(.schemaVersion == 1) and ((.files | length) > 0)' "$manifest" > /dev/null 2>&1; then
    manifest_ok=1
  fi
  local layers_ok=0
  if load_dest_layers "$dest"; then
    layers_ok=1
  fi

  load_upstream_path_sets
  load_dest_history "$dest"

  ensure_tmp
  local records
  records="$(mktemp -p "$TMP_DIR")"

  if [ "$manifest_ok" -ne 1 ] || [ "$layers_ok" -ne 1 ]; then
    scan_degraded "$dest" "$records"
    build_target_json "$dest" "$([ "$manifest_ok" -eq 1 ] && echo true || echo false)" true '' false false false "$records"
    rm -f "$records"
    return 0
  fi

  # --- manifest を読む（core/merge/seed のレコードを1回の jq で展開） ---
  local -A MAN_LAYER=() MAN_SHA=() MAN_STRATEGY=() MAN_LINES=() MAN_KEYS=()
  local layer p sha strategy lines keys
  while IFS=$'\037' read -r layer p sha strategy lines keys; do
    [ -n "$p" ] || continue
    MAN_LAYER["$p"]="$layer"
    MAN_SHA["$p"]="$sha"
    MAN_STRATEGY["$p"]="$strategy"
    MAN_LINES["$p"]="$lines"
    MAN_KEYS["$p"]="$keys"
  done < <(jq -r '
    .files[]?
    | [.layer, .path, (.sha256 // ""), (.strategy // ""), (.lines // ""), ((.keys // {}) | tojson)]
    | join("\u001f")
  ' "$manifest" | tr -d '\r')

  # 防御の二重化: 上の jq 検査を通っても、path 欠落等の形式違いでレコードが1件も
  # 読めなければ通常経路は成立しない（added の全件誤報になる）。縮退へ倒す
  if [ "${#MAN_LAYER[@]}" -eq 0 ]; then
    scan_degraded "$dest" "$records"
    build_target_json "$dest" true true '' false false false "$records"
    rm -f "$records"
    return 0
  fi

  local source_commit
  source_commit="$(jq -r '.source.commit // ""' "$manifest" | tr -d '\r')"
  local source_dirty=false
  case "$source_commit" in *-dirty) source_dirty=true ;; esac

  resolve_base_sha_to_reply "$source_commit"
  local base_sha="$REPLY" base_approx_flag="$REPLY_BASE_APPROX"
  local base_resolvable=false base_approximate=false
  if [ -n "$base_sha" ]; then
    base_resolvable=true
    [ "$base_approx_flag" -eq 1 ] && base_approximate=true
  fi

  # --- core: 現在の sha を一括で取り、modified / deleted を分類 ---
  local -a core_existing=() core_paths=()
  local -a modified_core=()
  for p in "${!MAN_LAYER[@]}"; do
    [ "${MAN_LAYER[$p]}" = 'core' ] || continue
    core_paths+=("$p")
    [ -f "$dest/$p" ] && core_existing+=("$dest/$p")
  done
  SHA_RESULT=()
  if [ "${#core_existing[@]}" -gt 0 ]; then
    sha256_lf_batch "${core_existing[@]}"
  fi
  # 空配列の "${a[@]}" は bash 4.4 未満の set -u で unbound variable になるためガードを付ける
  # （install-to-project.sh の apply_pass と同じ回避。以降の配列展開も同型）
  for p in ${core_paths[@]+"${core_paths[@]}"}; do
    if [ ! -f "$dest/$p" ]; then
      emit_missing_record "$records" "$p" core
      continue
    fi
    if [ "${SHA_RESULT[$dest/$p]}" != "${MAN_SHA[$p]}" ]; then
      modified_core+=("$p")
    fi
  done

  # --- merge: strategy 別の指紋比較（読む側の初実装。3-way は対象外で conflict は常に unknown） ---
  for p in "${!MAN_LAYER[@]}"; do
    [ "${MAN_LAYER[$p]}" = 'merge' ] || continue
    if [ ! -f "$dest/$p" ]; then
      emit_missing_record "$records" "$p" merge
      continue
    fi
    local unchanged=0
    if merge_fingerprint_unchanged "$dest/$p" "${MAN_STRATEGY[$p]}" "${MAN_LINES[$p]}" "${MAN_KEYS[$p]}"; then
      unchanged=1
    fi
    if [ "$unchanged" -eq 0 ]; then
      emit_record "$records" "$p" merge modified unknown
    fi
  done

  # --- core modified の衝突事前判定（merge-file の起動は modified な core に限定） ---
  for p in ${modified_core[@]+"${modified_core[@]}"}; do
    local conflict=unknown
    if [ "$base_resolvable" = true ] && [ "$p" != "$DIST_LAYERS_REL" ]; then
      materialize_upstream_to_reply "$base_sha" "$p"
      local base_file="$REPLY"
      materialize_upstream_to_reply HEAD "$p"
      local ours_file="$REPLY"
      if [ -n "$base_file" ] && [ -n "$ours_file" ]; then
        local theirs_file rc=0
        theirs_file="$(mktemp -p "$TMP_DIR")"
        tr -d '\r' < "$dest/$p" > "$theirs_file"
        git merge-file -p "$ours_file" "$base_file" "$theirs_file" > /dev/null 2>&1 || rc=$?
        # 0=衝突なし / 1〜127=衝突数 / それ以外（実測255）=エラー→判定不能（調査結果 Q3）
        if [ "$rc" -eq 0 ]; then
          conflict=clean
        elif [ "$rc" -ge 1 ] && [ "$rc" -le 127 ]; then
          conflict=conflict
        fi
      fi
    fi
    emit_record "$records" "$p" core modified "$conflict"
  done

  # --- added: 配布対象ディレクトリ配下の実ファイルから判定 ---
  local -a roots=()
  local i
  for ((i = 0; i < ${#LAYER_ENTRY_PATHS[@]}; i++)); do
    case "${LAYER_ENTRY_LAYERS[$i]}" in core | merge) roots+=("${LAYER_ENTRY_PATHS[$i]}") ;; esac
  done
  local root cand rel
  local -A seen_cand=()
  for root in ${roots[@]+"${roots[@]}"}; do
    if [ -f "$dest/$root" ]; then
      seen_cand["$root"]=1
    elif [ -d "$dest/$root" ]; then
      while IFS= read -r -d '' cand; do
        rel="${cand#"$dest"/}"
        seen_cand["$rel"]=1
      done < <(find "$dest/$root" -type f -not -path '*/.git/*' -print0)
    fi
  done
  for rel in "${!seen_cand[@]}"; do
    [ -z "${MAN_LAYER[$rel]+x}" ] || continue
    is_harvest_infra_path "$rel" && continue
    resolve_layer_to_reply "$rel"
    [ "$REPLY" = 'core' ] || continue
    local matched=0 pat
    for pat in ${LOCAL_IGNORE_PATTERNS[@]+"${LOCAL_IGNORE_PATTERNS[@]}"}; do
      if gitignore_matches "$pat" "$rel"; then
        matched=1
        break
      fi
    done
    [ "$matched" -eq 0 ] || continue
    emit_record "$records" "$rel" core added ''
  done

  build_target_json "$dest" true false "$source_commit" "$source_dirty" "$base_resolvable" "$base_approximate" "$records"
  rm -f "$records"
}

# manifest に載っているのに配布先に実体が無いレコード。
# 本家HEADにも無いもの（本家でも削除済み）は deleted と分けて removedUpstream として出す
# （SCAN_CORE_REMOVED の案内に従って手で消した配布先を毎回候補に出さないため）。
emit_missing_record() { # $1=records $2=path $3=layer
  local records="$1" p="$2" layer="$3" status=deleted
  [ -n "${UP_HAS_PATH[$p]+x}" ] || status=removedUpstream
  emit_record "$records" "$p" "$layer" "$status" ''
}

# レコード1行を中間表現（US区切り）で追記する。JSON 化は最後に jq 1回で行う。
emit_record() { # $1=records $2=path $3=layer $4=status $5=conflict（空=キー自体を出さない）
  local records="$1" p="$2" layer="$3" status="$4" conflict="$5"
  local up_has=false up_del=false ai=null cnt=null
  [ -n "${UP_HAS_PATH[$p]+x}" ] && up_has=true
  [ -n "${UP_DELETED_PATH[$p]+x}" ] && up_del=true
  if [ "$DEST_IS_GIT" -eq 1 ]; then
    ai="${DEST_AI_COUNT[$p]:-0}"
    cnt="${DEST_CHANGE_COUNT[$p]:-0}"
  fi
  printf '%s\037%s\037%s\037%s\037%s\037%s\037%s\037%s\n' \
    "$p" "$layer" "$status" "$conflict" "$ai" "$cnt" "$up_has" "$up_del" >> "$records"
}

# 縮退モード: 本家HEADの core/merge 全ファイルと配布先の現在を 2-way 比較し、
# 差分のあるファイルを status="differs" で列挙する（確定分類は成立しない。調査結果 Q4）。
scan_degraded() { # $1=配布先 $2=records
  local dest="$1" records="$2"
  # 本家の層分け定義から core/merge の追跡ファイルを後勝ちで確定する（本家側で実行する
  # ため git ls-files は本家の追跡ファイルに対して評価される。エントリ数ぶんの起動で
  # ファイル数には比例しない）
  local -A file_layer=()
  local entry_path entry_layer f
  while IFS=$'\037' read -r entry_path entry_layer; do
    [ -n "$entry_path" ] || continue
    while IFS= read -r -d '' f; do
      [ -n "$f" ] || continue
      file_layer["$f"]="$entry_layer"
    done < <(git -C "$UPSTREAM_ROOT" ls-files -z -- "$entry_path" 2>/dev/null)
  done < <(jq -r '.entries[] | select(.path) | [.path, .layer] | join("\u001f")' \
    "$UPSTREAM_ROOT/$DIST_LAYERS_REL" | tr -d '\r')

  # 本家HEADの内容を1回の git archive で一時領域へ展開する（git show をファイルごとに呼ばない）
  ensure_tmp
  local up_snap="$TMP_DIR/degraded-upstream"
  mkdir -p "$up_snap"
  # 展開の失敗を「差分なし」と混同しない: パイプラインの終了コードを明示的に検査し、
  # 空展開（tar が何も出さなかった）も失敗として扱う（set -e はこの関数が条件文脈から
  # 呼ばれた場合に無効化されるため、暗黙の中断へ頼らない）
  local archive_rc=0
  git -C "$UPSTREAM_ROOT" archive HEAD | tar -x -C "$up_snap" || archive_rc=$?
  if [ "$archive_rc" -ne 0 ]; then
    printf 'エラー: 本家HEADの展開に失敗しました（git archive | tar rc=%s）\n' "$archive_rc" >&2
    return 1
  fi
  if [ -z "$(find "$up_snap" -mindepth 1 -print -quit)" ]; then
    printf 'エラー: 本家HEADの展開結果が空です（git archive | tar）\n' >&2
    return 1
  fi

  local -a compare_up=() compare_dest=() compare_rel=()
  for f in "${!file_layer[@]}"; do
    case "${file_layer[$f]}" in core | merge) ;; *) continue ;; esac
    [ -f "$dest/$f" ] || continue
    [ -f "$up_snap/$f" ] || continue
    compare_rel+=("$f")
    compare_up+=("$up_snap/$f")
    compare_dest+=("$dest/$f")
  done
  [ "${#compare_rel[@]}" -gt 0 ] || return 0

  # dist-layers.json は del(.upstream) を掛けた内容が配布されるため、本家側にも同じ変換を
  # 掛けてから比べる（upstream キーぶんの差分が常に出るのを防ぐ。調査結果 Q3）
  if [ -f "$up_snap/$DIST_LAYERS_REL" ]; then
    jq 'del(.upstream)' "$up_snap/$DIST_LAYERS_REL" > "$up_snap/$DIST_LAYERS_REL.tmp" \
      && mv "$up_snap/$DIST_LAYERS_REL.tmp" "$up_snap/$DIST_LAYERS_REL"
  fi

  sha256_lf_batch "${compare_up[@]}" "${compare_dest[@]}"
  local i
  for ((i = 0; i < ${#compare_rel[@]}; i++)); do
    if [ "${SHA_RESULT[${compare_up[$i]}]}" != "${SHA_RESULT[${compare_dest[$i]}]}" ]; then
      # emit_record 経由で出すことで、配布先が git リポジトリなら判断材料
      # （aiAssetCommits / changeCount）も通常経路と同じに埋まる（null 決め打ちにすると
      # 「配布先が git ではない」とSKILL.mdの説明どおりに誤読される）
      emit_record "$records" "${compare_rel[$i]}" "${file_layer[${compare_rel[$i]}]}" differs ''
    fi
  done
}

# 中間表現から target JSON を組み立てて追記する
build_target_json() { # $1=path $2=manifestExists $3=degraded $4=sourceCommit $5=sourceCommitDirty $6=baseResolvable $7=baseApproximate $8=records
  jq -R -n --arg path "$1" --argjson manifestExists "$2" --argjson degraded "$3" \
    --arg sourceCommit "$4" --argjson sourceCommitDirty "$5" \
    --argjson baseResolvable "$6" --argjson baseApproximate "$7" '
    def torec:
      split("\u001f") as $f
      | { path: $f[0], layer: $f[1], status: $f[2] }
        + (if $f[3] == "" then {} else { conflict: $f[3] } end)
        + { aiAssetCommits: ($f[4] | if . == "null" then null else tonumber end),
            changeCount: ($f[5] | if . == "null" then null else tonumber end),
            upstreamHasPath: ($f[6] == "true"), upstreamDeleted: ($f[7] == "true") };
    { path: $path, manifestExists: $manifestExists, degraded: $degraded }
    + (if $degraded then {} else
        { sourceCommit: $sourceCommit, sourceCommitDirty: $sourceCommitDirty,
          baseResolvable: $baseResolvable, baseApproximate: $baseApproximate } end)
    + { files: [ inputs | select(length > 0) | torec ] | sort_by(.path) }
  ' "$8" >> "$TARGETS_FILE"
}

cmd_scan() {
  [ "$#" -ge 1 ] || {
    printf 'エラー: scan には配布先パスを1つ以上指定してください\n' >&2
    return 3
  }
  ensure_tmp
  TARGETS_FILE="$(mktemp -p "$TMP_DIR")"
  local dest rc
  for dest in "$@"; do
    # 1件の失敗で全体を落とさない（配布先単位のエラー隔離）。
    # `( f ) || rc=$?` の形は使わない: bash は `||` による errexit の一時停止を
    # サブシェルの内部まで伝播させるため、関数内の途中失敗が素通りして最後まで走り、
    # 「壊れた分析結果」が正常な target として出力される（実測: bash 5.2.21 で
    # `set -e; f(){ false; echo X; }; ( f ) || rc=$?` は X を出力し rc=0）。
    # 代わりに条件文脈の外でサブシェルを実行し、その内側で set -e を掛け直す
    # （この形なら内部の失敗で即座にサブシェルごと終了し、rc に現れる。実測済み。
    # 出力は TARGETS_FILE への追記なのでサブシェルでも失われない。TMP_DIR は直前の
    # ensure_tmp で確定済みのため、サブシェル内で新たな trap は仕掛からない）
    set +e
    (
      set -e
      scan_one_dest "$dest"
    )
    rc=$?
    set -e
    if [ "$rc" -ne 0 ]; then
      emit_error_target "$dest" "分析に失敗しました（内部エラー rc=${rc}）"
    fi
  done
  jq -s '{schemaVersion: 1, targets: .}' "$TARGETS_FILE"
}

# ---- diff ------------------------------------------------------------------

cmd_diff() {
  [ "$#" -eq 2 ] || {
    printf 'エラー: diff <配布先パス> <相対パス>\n' >&2
    return 3
  }
  local dest="$1" rel="$2"
  [ -d "$dest" ] || {
    printf 'エラー: 配布先が存在しません: %s\n' "$dest" >&2
    return 3
  }
  dest="$(cd "$dest" && pwd)"
  [ -f "$dest/$rel" ] || {
    printf 'エラー: 配布先にファイルがありません: %s\n' "$rel" >&2
    return 3
  }
  materialize_upstream_to_reply HEAD "$rel"
  local up_file="$REPLY"
  [ -n "$up_file" ] || {
    printf 'エラー: 本家HEADに %s がありません\n' "$rel" >&2
    return 3
  }
  ensure_tmp
  local theirs
  theirs="$(mktemp -p "$TMP_DIR")"
  tr -d '\r' < "$dest/$rel" > "$theirs"
  # 差分の有無は出力で分かる。diff の終了コード1（差分あり）は正常系として扱う
  diff -u --label "upstream/${rel}" --label "dest/${rel}" "$up_file" "$theirs" || true
}

# ---- merge3 ----------------------------------------------------------------

cmd_merge3() {
  [ "$#" -eq 2 ] || {
    printf 'エラー: merge3 <配布先パス> <相対パス>\n' >&2
    return 3
  }
  local dest="$1" rel="$2"
  [ -d "$dest" ] || {
    printf 'エラー: 配布先が存在しません: %s\n' "$dest" >&2
    return 3
  }
  dest="$(cd "$dest" && pwd)"
  [ -f "$dest/$rel" ] || {
    printf 'エラー: 配布先にファイルがありません: %s\n' "$rel" >&2
    return 3
  }

  # 3-way の対象外: merge 層（base が本家のどのコミットにも無い）・seed 層（配布元は
  # 別パスの雛形で base が本家の履歴に無い）・dist-layers.json（del(.upstream) 済みの
  # 内容が配布される）。指紋比較・2-way の diff で確認する。
  if [ "$rel" = "$DIST_LAYERS_REL" ]; then
    printf '対象外: %s は del(.upstream) 済みの内容が配布されるため 3-way の base が成立しません（diff を使ってください）\n' "$rel" >&2
    return 4
  fi

  # 層の判定（フェイルクローズ）: 第一情報源は manifest の .files[].layer（merge/seed の
  # レコードがそのまま入っている）。manifest に無いパスは dist-layers.json の照合で解決する。
  # どちらの情報源からも層が確定しないときは、merge/seed を誤って 3-way してしまう恐れが
  # あるため実行せずエラーで止める（無言のスキップは「exit 0=そのまま取り込める」の誤読を招く）
  local manifest="$dest/$MANIFEST_REL" rel_layer='' manifest_readable=0
  if [ -s "$manifest" ] && jq -e . "$manifest" > /dev/null 2>&1; then
    manifest_readable=1
    rel_layer="$(jq -r --arg p "$rel" '[.files[]? | select(.path == $p) | .layer] | last // ""' "$manifest" | tr -d '\r')"
  fi
  if [ -z "$rel_layer" ] && load_dest_layers "$dest"; then
    resolve_layer_to_reply "$rel"
    rel_layer="$REPLY"
  fi
  if [ -z "$rel_layer" ]; then
    printf 'エラー: 層を判定できません（manifest の記録にも dist-layers.json の照合にも %s の層がありません）。merge/seed 層を誤って 3-way しないため実行を中止します\n' "$rel" >&2
    return 3
  fi
  case "$rel_layer" in
    merge)
      printf '対象外: %s は merge 層（配布直後の内容が本家のどのコミットにも無い）のため 3-way できません（diff を使ってください）\n' "$rel" >&2
      return 4
      ;;
    seed)
      printf '対象外: %s は seed 層（配布元は別パスの雛形で base が本家の履歴に無い）のため 3-way できません（diff を使ってください）\n' "$rel" >&2
      return 4
      ;;
  esac

  local base_sha='' base_approx=0
  if [ "$manifest_readable" -eq 1 ]; then
    local source_commit
    source_commit="$(jq -r '.source.commit // ""' "$manifest" | tr -d '\r')"
    resolve_base_sha_to_reply "$source_commit"
    base_sha="$REPLY"
    base_approx="$REPLY_BASE_APPROX"
  fi

  local base_file=''
  if [ -n "$base_sha" ]; then
    materialize_upstream_to_reply "$base_sha" "$rel"
    base_file="$REPLY"
  fi
  if [ -z "$base_file" ]; then
    printf 'base 取得不可（manifest 無し・記録SHA未到達・当該コミットにファイル無しのいずれか）。2-way の差分へ縮退します\n' >&2
    cmd_diff "$dest" "$rel"
    return 2
  fi
  if [ "$base_approx" -eq 1 ]; then
    printf '注意: 記録SHAは -dirty 付きでした。base は配布された内容と一致しない可能性があります（近似）\n' >&2
  fi

  materialize_upstream_to_reply HEAD "$rel"
  local ours_file="$REPLY"
  [ -n "$ours_file" ] || {
    printf 'エラー: 本家HEADに %s がありません\n' "$rel" >&2
    return 3
  }
  ensure_tmp
  local theirs_file rc=0
  theirs_file="$(mktemp -p "$TMP_DIR")"
  tr -d '\r' < "$dest/$rel" > "$theirs_file"
  git merge-file -p "$ours_file" "$base_file" "$theirs_file" || rc=$?
  if [ "$rc" -eq 0 ]; then
    return 0
  fi
  if [ "$rc" -ge 1 ] && [ "$rc" -le 127 ]; then
    return 1
  fi
  printf 'エラー: git merge-file が異常終了しました（rc=%s）\n' "$rc" >&2
  return 3
}

# ---- main ------------------------------------------------------------------

main() {
  # 既定の本家ルートはスクリプト位置（.claude/skills/harvest-from-projects/scripts/）から導出
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  UPSTREAM_ROOT="$(cd "$script_dir/../../../.." && pwd)"

  local -a rest=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --upstream)
        [ "$#" -ge 2 ] || {
          printf 'エラー: --upstream には値が必要です\n' >&2
          return 3
        }
        UPSTREAM_ROOT="$(cd "$2" && pwd)"
        shift 2
        ;;
      -h | --help)
        usage
        return 0
        ;;
      *)
        rest+=("$1")
        shift
        ;;
    esac
  done
  [ "${#rest[@]}" -ge 1 ] || {
    usage >&2
    return 3
  }
  git -C "$UPSTREAM_ROOT" rev-parse --git-dir > /dev/null 2>&1 || {
    printf 'エラー: 本家ルートが git リポジトリではありません: %s\n' "$UPSTREAM_ROOT" >&2
    return 3
  }

  local sub="${rest[0]}"
  case "$sub" in
    scan) cmd_scan "${rest[@]:1}" ;;
    diff) cmd_diff "${rest[@]:1}" ;;
    merge3) cmd_merge3 "${rest[@]:1}" ;;
    *)
      printf 'エラー: 不明なサブコマンド: %s\n' "$sub" >&2
      usage >&2
      return 3
      ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
