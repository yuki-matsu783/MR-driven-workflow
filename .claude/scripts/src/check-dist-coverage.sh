#!/usr/bin/env bash
# 層分け定義（.claude/dist-layers.json）の網羅性を検査する。
# 仕様: .claude/docs/spec/distribution-assets.md（issue #26）
set -euo pipefail

readonly DEFAULT_DEF='.claude/dist-layers.json'
readonly VALID_LAYERS=' core seed merge local exclude '
readonly VALID_STRATEGIES=' lines-marker json-keys '

usage() {
  cat <<'USAGE'
使い方: check-dist-coverage.sh [--def <定義ファイル>]

  --def <path>  層分け定義ファイル（既定: .claude/dist-layers.json）
  -h, --help    このヘルプ

検査1: 追跡ファイル全件が、どれか1つ以上のエントリに一致するか
検査2: .gitignore のコメント・空行を除く全行が、local エントリの gitignorePattern に一致するか
検査3: source を持たないエントリが、1件以上の追跡ファイルに一致するか
検査4: layer が5種のいずれかで、merge が有効な strategy を持つか

未分類が1件でもあれば終了コード1。
USAGE
}

# 定義ファイルを読み、1エントリ1行のレコードを標準出力へ出す。
# jqの起動は1回だけに抑える（.claude/rules/shell-script-style.md「外部プロセス起動のコスト」）。
# 列: idx / layer / path / source / strategy / gitignorePattern
#
# 区切りに**タブを使わない**。タブはIFSの空白文字なので、bashの `read` は連続するタブを1つに
# 畳んでしまい、空の列があると以降の列がずれる（実際に踏んだ: gitignorePattern の値が path へ
# 入り `git ls-files -- /usage/` が fatal になった）。空白でない `\u001f`（US）を使う。
# ソースコードへ生の制御文字は書かない（.claude/rules/shell-script-style.md）。
read_entries_records() {
  local def="$1"
  jq -r '
    .entries
    | to_entries[]
    | [ (.key | tostring),
        (.value.layer // ""),
        (.value.path // ""),
        (.value.source // ""),
        (.value.strategy // ""),
        (.value.gitignorePattern // "") ]
    | join("\u001f")
  ' "$def" | tr -d '\r'
}

# 定義ファイルが「本家のもの」かを返す。配布先では検査自体が意味を持たないため。
is_upstream() {
  local def="$1" v
  v="$(jq -r '.upstream // false' "$def" | tr -d '\r')"
  [ "$v" = 'true' ]
}

main() {
  local def="$DEFAULT_DEF"
  while [ $# -gt 0 ]; do
    case "$1" in
      --def) def="${2:-}"; shift 2 ;;
      -h|--help) usage; return 0 ;;
      *) printf 'エラー: 不明な引数 %s\n' "$1" >&2; usage >&2; return 2 ;;
    esac
  done

  if [ ! -f "$def" ]; then
    printf 'エラー: 定義ファイルが見つかりません: %s\n' "$def" >&2
    return 2
  fi
  if ! jq -e . "$def" > /dev/null 2>&1; then
    printf 'エラー: 定義ファイルが有効なJSONではありません: %s\n' "$def" >&2
    return 2
  fi

  # 配布先では、この検査は「配布先の自前ソースが全件未分類」と報告してしまうだけなので流さない。
  # 無言でスキップせず、対象件数を出す（.claude/rules/shell-script-style.md「異常が無ければ何も
  # 出ない検証にしない」と同じ考え方）。
  if ! is_upstream "$def"; then
    local n_files
    n_files="$(git ls-files | wc -l)"
    printf 'スキップ: %s は upstream ではありません（配布先。追跡ファイル %s 件は検査対象外）\n' \
      "$def" "$n_files"
    return 0
  fi

  local -a idxs=() layers=() paths=() sources=() strategies=() ignpats=()
  local idx layer path source strategy ignpat
  while IFS=$'\037' read -r idx layer path source strategy ignpat; do
    [ -n "$idx" ] || continue
    idxs+=("$idx"); layers+=("$layer"); paths+=("$path")
    sources+=("$source"); strategies+=("$strategy"); ignpats+=("$ignpat")
  done < <(read_entries_records "$def")

  local total_entries="${#idxs[@]}"
  local failures=0

  # ---- 検査4: layer / strategy の妥当性 ----------------------------------
  local -a bad_layers=()
  local i
  for ((i = 0; i < total_entries; i++)); do
    if [[ "$VALID_LAYERS" != *" ${layers[i]} "* ]]; then
      bad_layers+=("entry[${idxs[i]}] layer='${layers[i]}'")
      continue
    fi
    if [ "${layers[i]}" = 'merge' ]; then
      if [[ "$VALID_STRATEGIES" != *" ${strategies[i]} "* ]]; then
        bad_layers+=("entry[${idxs[i]}] merge に有効な strategy がない: '${strategies[i]}'")
      fi
    fi
    if [ -z "${paths[i]}" ] && [ -z "${ignpats[i]}" ]; then
      bad_layers+=("entry[${idxs[i]}] path も gitignorePattern も無い")
    fi
    if [ -n "${ignpats[i]}" ] && [ "${layers[i]}" != 'local' ]; then
      bad_layers+=("entry[${idxs[i]}] gitignorePattern は local 専用（layer='${layers[i]}'）")
    fi
  done

  # ---- エントリごとの一致ファイルを集める --------------------------------
  # 一致判定は git pathspec としてgitに評価させる（globの意味論を再実装しない）。
  # -z はNULを保持したいからではなく、非ASCIIパスがクォートされるのを避けるため
  # （.claude/rules/shell-script-style.md「コマンド置換とNULバイト」）。
  local -A matched=()
  local -a entries_without_match=() bad_paths=()
  local f n_match
  local tmp_ls
  tmp_ls="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f '$tmp_ls'" EXIT
  for ((i = 0; i < total_entries; i++)); do
    [ -n "${paths[i]}" ] || continue
    # 一度ファイルへ受けてから読む。コマンド置換はNULを保持できず、プロセス置換では
    # git の終了コードを拾えないため（pathspecの打ち間違いを検査3ではなく git の
    # `fatal:` として素通りさせないための受け口）。
    if ! git ls-files -z -- "${paths[i]}" > "$tmp_ls" 2>/dev/null; then
      bad_paths+=("entry[${idxs[i]}] path='${paths[i]}' は pathspec として解釈できない")
      continue
    fi
    n_match=0
    while IFS= read -r -d '' f; do
      matched["$f"]=1
      n_match=$((n_match + 1))
    done < "$tmp_ls"
    # 検査3: source を持つエントリは、配布元が別ファイルなので本家に実体が無くてよい。
    if [ "$n_match" -eq 0 ] && [ -z "${sources[i]}" ]; then
      entries_without_match+=("entry[${idxs[i]}] path='${paths[i]}'")
    fi
  done

  # ---- 検査1: 追跡ファイル全件が分類されているか -------------------------
  local -a unclassified=()
  local n_tracked=0
  while IFS= read -r -d '' f; do
    n_tracked=$((n_tracked + 1))
    [ -n "${matched[$f]+x}" ] || unclassified+=("$f")
  done < <(git ls-files -z)

  # ---- 検査2: .gitignore の全行が local エントリに載っているか -----------
  local -a uncovered_ignores=()
  local n_ignore_lines=0 line
  if [ -f .gitignore ]; then
    while IFS= read -r line; do
      line="${line//$'\r'/}"
      case "$line" in ''|'#'*) continue ;; esac
      n_ignore_lines=$((n_ignore_lines + 1))
      local found=0
      for ((i = 0; i < total_entries; i++)); do
        if [ -n "${ignpats[i]}" ] && [ "${ignpats[i]}" = "$line" ]; then
          found=1
          break
        fi
      done
      [ "$found" -eq 1 ] || uncovered_ignores+=("$line")
    done < .gitignore
  fi

  # ---- 報告 --------------------------------------------------------------
  printf '定義: %s（エントリ %s 件）\n' "$def" "$total_entries"

  printf '検査1 追跡ファイルの分類: %s / %s 件\n' \
    "$((n_tracked - ${#unclassified[@]}))" "$n_tracked"
  if [ "${#unclassified[@]}" -gt 0 ]; then
    failures=$((failures + 1))
    printf '  NG: 未分類 %s 件（全件を列挙する）\n' "${#unclassified[@]}"
    printf '    %s\n' "${unclassified[@]}"
  fi

  printf '検査2 .gitignore の行の被覆: %s / %s 行\n' \
    "$((n_ignore_lines - ${#uncovered_ignores[@]}))" "$n_ignore_lines"
  if [ "${#uncovered_ignores[@]}" -gt 0 ]; then
    failures=$((failures + 1))
    printf '  NG: local エントリに無いパターン %s 件\n' "${#uncovered_ignores[@]}"
    printf '    %s\n' "${uncovered_ignores[@]}"
  fi

  printf '検査3 空振りエントリ: %s 件（うち pathspec として不正 %s 件）\n' \
    "${#entries_without_match[@]}" "${#bad_paths[@]}"
  if [ "${#entries_without_match[@]}" -gt 0 ]; then
    failures=$((failures + 1))
    printf '  NG: 1件も一致しないエントリ（打ち間違い・定義の残骸）\n'
    printf '    %s\n' "${entries_without_match[@]}"
  fi
  if [ "${#bad_paths[@]}" -gt 0 ]; then
    failures=$((failures + 1))
    printf '    %s\n' "${bad_paths[@]}"
  fi

  printf '検査4 layer / strategy の妥当性: 不正 %s 件\n' "${#bad_layers[@]}"
  if [ "${#bad_layers[@]}" -gt 0 ]; then
    failures=$((failures + 1))
    printf '    %s\n' "${bad_layers[@]}"
  fi

  if [ "$failures" -gt 0 ]; then
    printf '結果: NG（%s 種の検査が失敗）\n' "$failures"
    return 1
  fi
  printf '結果: OK（4種すべて通過）\n'
  return 0
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
