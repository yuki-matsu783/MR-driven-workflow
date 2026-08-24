#!/usr/bin/env bash
# 構成案JSON（issue #168 のスキーマと同じ入力）から編集可能な .pptx を生成する。
# 使い方: bash json-to-pptx.sh <入力.json> [出力.pptx]
# 設計: issue #169 → .claude/docs/spec/pptx-slides.md（フェーズ4で作成）
#
# 構造: 入力検証 → 一時ディレクトリへ雛形コピー → slideN.xml生成（type別写像）→
#       連動5箇所の生成 → zip梱包（経路試行: zip → python zipfile → 明示エラー）→ 自己検証。
# スライド内容の組み立ては slides-to-records.jq の1回のjq呼び出しへ集約し、
# ループ内で外部コマンドを起動しない（.claude/rules/shell-script-style.md）。

set -euo pipefail

# bash 5.2以降の patsub_replacement を無効化する（既定ONで、パラメータ展開の置換文字列中の
# `&` がsedと同じくマッチ全体へ展開され、xml_escape_to_reply の `&lt;` が `<lt;` になる・
# core.xml のプレースホルダ置換でエスケープ済み値の `&` が再解釈される。5.2未満には
# このshopt自体が無いため失敗を握りつぶす）
shopt -u patsub_replacement 2>/dev/null || true

SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
[ "$SCRIPT_DIR" = "${BASH_SOURCE[0]}" ] && SCRIPT_DIR="."
TEMPLATE_DIR="$SCRIPT_DIR/../assets/pptx-template"
RECORDS_JQ="$SCRIPT_DIR/slides-to-records.jq"

US=$'\037'

# レイアウト定数（EMU。16:9 = 12192000 x 6858000）
readonly MARGIN_X=838200
readonly FULL_W=10515600
readonly COL_W=5107940
readonly COL_R_X=6245860
readonly ROW_H=370840

err() { printf 'json-to-pptx: エラー: %s\n' "$*" >&2; }
warn() { printf 'json-to-pptx: 警告: %s\n' "$*" >&2; }

# XMLエスケープ（5種）。このスクリプトで唯一のエスケープ実装（jq側では行わない）。
xml_escape_to_reply() {
  local s="$1" sq="'"
  s="${s//&/&amp;}"
  s="${s//</&lt;}"
  s="${s//>/&gt;}"
  s="${s//\"/&quot;}"
  s="${s//$sq/&apos;}"
  REPLY="$s"
}

# 出力パスの既定値: 入力と同じディレクトリの <ベース名>.pptx
# （<ベース名>.slides.json は .slides も落とす。拡張子なしは <入力名>.pptx）
resolve_out_path_to_reply() {
  local in="$1" dir base
  dir="${in%/*}"
  [ "$dir" = "$in" ] && dir="."
  base="${in##*/}"
  base="${base%.json}"
  base="${base%.slides}"
  REPLY="$dir/$base.pptx"
}

# ---- 段落・図形のXML組み立て（純粋関数。forkしない） ----

para_title_to_reply() { # $1=text $2=sz
  xml_escape_to_reply "$1"
  REPLY="<a:p><a:r><a:rPr lang=\"ja-JP\" sz=\"$2\" b=\"1\"/><a:t>$REPLY</a:t></a:r></a:p>"
}

para_plain_to_reply() { # $1=text $2=sz
  xml_escape_to_reply "$1"
  REPLY="<a:p><a:r><a:rPr lang=\"ja-JP\" sz=\"$2\"/><a:t>$REPLY</a:t></a:r></a:p>"
}

para_bullet_to_reply() { # $1=lvl(0/1) $2=text
  local lvl="$1" sz ch
  if [ "$lvl" = "1" ]; then sz=1800 ch="–"; else sz=2000 ch="•"; fi
  xml_escape_to_reply "$2"
  REPLY="<a:p><a:pPr lvl=\"$lvl\"><a:buFont typeface=\"Arial\"/><a:buChar char=\"$ch\"/></a:pPr><a:r><a:rPr lang=\"ja-JP\" sz=\"$sz\"/><a:t>$REPLY</a:t></a:r></a:p>"
}

table_cell_to_reply() { # $1=text $2=bold(0/1)
  local b=""
  [ "$2" = "1" ] && b=' b="1"'
  xml_escape_to_reply "$1"
  REPLY="<a:tc><a:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr lang=\"ja-JP\"$b/><a:t>$REPLY</a:t></a:r></a:p></a:txBody><a:tcPr/></a:tc>"
}

sp_to_reply() { # $1=id $2=name $3=x $4=y $5=w $6=h $7=paras
  REPLY="<p:sp><p:nvSpPr><p:cNvPr id=\"$1\" name=\"$2\"/><p:cNvSpPr txBox=\"1\"/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x=\"$3\" y=\"$4\"/><a:ext cx=\"$5\" cy=\"$6\"/></a:xfrm><a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom></p:spPr><p:txBody><a:bodyPr wrap=\"square\"><a:normAutofit/></a:bodyPr><a:lstStyle/>$7</p:txBody></p:sp>"
}

# ---- スライド1枚のXMLを組み立てて書き出す ----
# 入力はグローバルのスライドバッファ（CUR_*）。
flush_slide() {
  [ -n "$CUR_N" ] || return 0
  local shapes="" id=2 paras sz

  case "$CUR_TYPE" in
    cover)
      if [ -n "$CUR_TITLE" ]; then
        sp_to_reply "$id" "Title" "$MARGIN_X" 2133600 "$FULL_W" 1600200 "$CUR_TITLE"
        shapes+="$REPLY"; id=$((id + 1))
      fi
      if [ -n "$CUR_SUB" ]; then
        sp_to_reply "$id" "Subtitle" "$MARGIN_X" 3886200 "$FULL_W" 1371600 "$CUR_SUB"
        shapes+="$REPLY"; id=$((id + 1))
      fi
      ;;
    section)
      if [ -n "$CUR_TITLE" ]; then
        sp_to_reply "$id" "Section Title" "$MARGIN_X" 2857500 "$FULL_W" 1143000 "$CUR_TITLE"
        shapes+="$REPLY"; id=$((id + 1))
      fi
      ;;
    *)
      if [ -n "$CUR_TITLE" ]; then
        sp_to_reply "$id" "Title" "$MARGIN_X" 365760 "$FULL_W" 1143000 "$CUR_TITLE"
        shapes+="$REPLY"; id=$((id + 1))
      fi
      if [ -n "$CUR_BODY" ]; then
        sp_to_reply "$id" "Body" "$MARGIN_X" 1717040 "$FULL_W" 4700000 "$CUR_BODY"
        shapes+="$REPLY"; id=$((id + 1))
      fi
      if [ -n "$CUR_COL_L" ]; then
        sp_to_reply "$id" "Left Column" "$MARGIN_X" 1717040 "$COL_W" 4700000 "$CUR_COL_L"
        shapes+="$REPLY"; id=$((id + 1))
      fi
      if [ -n "$CUR_COL_R" ]; then
        sp_to_reply "$id" "Right Column" "$COL_R_X" 1717040 "$COL_W" 4700000 "$CUR_COL_R"
        shapes+="$REPLY"; id=$((id + 1))
      fi
      if [ "${#CUR_TBL_KINDS[@]}" -gt 0 ]; then
        # 列数は全行の最大セル数（TROW受信時に確定済み）。不足セルは空で埋め、
        # 超過セルを切り捨てない（無言のデータ欠落を作らないため）
        if [ "$CUR_TBL_NCOLS" -le 0 ]; then
          err "表の列数を決定できません（全行のセルが空です）: スライド$CUR_N"
          exit 1
        fi
        local ncols="$CUR_TBL_NCOLS" grid="" i colw frame_h rows_xml="" ri kind bold cells
        local -a RC
        colw=$((FULL_W / ncols))
        for ((i = 0; i < ncols; i++)); do grid+="<a:gridCol w=\"$colw\"/>"; done
        for ((ri = 0; ri < ${#CUR_TBL_KINDS[@]}; ri++)); do
          kind="${CUR_TBL_KINDS[$ri]}"
          bold=0
          if [ "$kind" = "H" ]; then bold=1; fi
          IFS="$US" read -r -a RC <<<"${CUR_TBL_CELLS[$ri]}"
          cells=""
          for ((i = 0; i < ncols; i++)); do
            table_cell_to_reply "${RC[$i]-}" "$bold"
            cells+="$REPLY"
          done
          rows_xml+="<a:tr h=\"$ROW_H\">$cells</a:tr>"
        done
        frame_h=$((ROW_H * ${#CUR_TBL_KINDS[@]}))
        shapes+="<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id=\"$id\" name=\"Table\"/><p:cNvGraphicFramePr><a:graphicFrameLocks noGrp=\"1\"/></p:cNvGraphicFramePr><p:nvPr/></p:nvGraphicFramePr><p:xfrm><a:off x=\"$MARGIN_X\" y=\"1717040\"/><a:ext cx=\"$FULL_W\" cy=\"$frame_h\"/></p:xfrm><a:graphic><a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/table\"><a:tbl><a:tblPr firstRow=\"1\"><a:tableStyleId>{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}</a:tableStyleId></a:tblPr><a:tblGrid>$grid</a:tblGrid>$rows_xml</a:tbl></a:graphicData></a:graphic></p:graphicFrame>"
        id=$((id + 1))
      fi
      ;;
  esac

  printf '%s\n%s\n' \
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' \
    "<p:sld xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\"><p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/><a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>$shapes</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>" \
    > "$WORK/ppt/slides/slide$CUR_N.xml"

  printf '%s\n%s\n' \
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' \
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/></Relationships>' \
    > "$WORK/ppt/slides/_rels/slide$CUR_N.xml.rels"
}

reset_slide_buffers() {
  CUR_N="" CUR_TYPE="" CUR_TITLE="" CUR_SUB="" CUR_BODY="" CUR_COL_L="" CUR_COL_R=""
  CUR_TBL_KINDS=() CUR_TBL_CELLS=() CUR_TBL_NCOLS=0
}

# ---- zip経路 ----

# 実行可能なpythonコマンドを能力（import zipfile の成否）で探す。
# Windowsでは python3 という名前が無い構成・実行できないStoreスタブがある構成の
# 両方がありうるため、存在確認では判定しない。
detect_python_to_reply() {
  local cand
  for cand in "python3" "python" "py -3"; do
    # shellcheck disable=SC2086  # "py -3" は語分割して実行する
    if $cand -c 'import zipfile' >/dev/null 2>&1; then
      REPLY="$cand"
      return 0
    fi
  done
  REPLY=""
  return 1
}

pack_with_zip() { # $1=作業dir $2=出力zip（絶対パス）
  (cd "$1" && zip -q -X -D -r "$2" '[Content_Types].xml' _rels docProps ppt)
}

pack_with_python() { # $1=pythonコマンド $2=作業dir $3=出力zip
  # shellcheck disable=SC2086
  $1 - "$2" "$3" <<'PYEOF'
import os, sys, zipfile
src, dst = sys.argv[1], sys.argv[2]
entries = []
for root, dirs, files in os.walk(src):
    for f in files:
        rel = os.path.relpath(os.path.join(root, f), src).replace(os.sep, "/")
        entries.append(rel)
entries.sort()
entries.remove("[Content_Types].xml")
entries.insert(0, "[Content_Types].xml")
with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as z:
    for rel in entries:
        z.write(os.path.join(src, rel), rel)
PYEOF
}

# 生成物の自己検証: zip整合性＋必須パーツの存在。python（能力検出済みなら）では
# 全XMLパーツのwell-formed検査まで行う（入力へ紛れた不正バイト等で壊れたXMLを
# 「成功」として出さないため）。
# 検証手段はpython → unzip の順で、可能な最良を使う。
# どちらも無い場合は検証できない旨を警告し、必須パーツ検査だけ zip -sf で行う。
verify_pptx() { # $1=pptxパス $2=スライド枚数
  local pptx="$1" n="$2" listing="" i part
  local required=('[Content_Types].xml' '_rels/.rels' 'docProps/core.xml' 'docProps/app.xml'
    'ppt/presentation.xml' 'ppt/_rels/presentation.xml.rels'
    'ppt/slideMasters/slideMaster1.xml' 'ppt/slideLayouts/slideLayout1.xml' 'ppt/theme/theme1.xml')
  for ((i = 1; i <= n; i++)); do
    required+=("ppt/slides/slide$i.xml" "ppt/slides/_rels/slide$i.xml.rels")
  done

  if [ -n "$PY_CMD" ]; then
    # shellcheck disable=SC2086
    if ! listing="$($PY_CMD - "$pptx" <<'PYEOF'
import sys, zipfile
import xml.etree.ElementTree as ET
z = zipfile.ZipFile(sys.argv[1])
bad = z.testzip()
if bad is not None:
    sys.exit("broken entry: " + bad)
for n in z.namelist():
    if n.endswith(".xml") or n.endswith(".rels"):
        try:
            ET.fromstring(z.read(n))
        except ET.ParseError as e:
            sys.exit("not well-formed: %s: %s" % (n, e))
print("\n".join(z.namelist()))
PYEOF
    )"; then
      return 1
    fi
  elif command -v unzip >/dev/null 2>&1; then
    warn "pythonが無いため、XMLパーツのwell-formed検査は省略した（zip整合性と必須パーツのみ確認する）"
    if ! unzip -t -qq "$pptx" >/dev/null 2>&1; then
      return 1
    fi
    listing="$(unzip -Z1 "$pptx" 2>/dev/null)" || return 1
  elif command -v zip >/dev/null 2>&1; then
    warn "unzip・pythonが無いため、zip整合性の検査は省略した（必須パーツの存在のみ確認する）"
    listing="$(zip -sf "$pptx" 2>/dev/null)" || return 1
  else
    return 1
  fi

  for part in "${required[@]}"; do
    if [[ "$listing" != *"$part"* ]]; then
      err "生成物に必須パーツ $part がありません"
      return 1
    fi
  done
  return 0
}

main() {
  if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    err "使い方: bash json-to-pptx.sh <入力.json> [出力.pptx]"
    exit 1
  fi
  local in="$1"

  # ---- 入力の存在・構文検査 ----
  if [ ! -f "$in" ]; then
    err "入力ファイルがありません: $in"
    exit 1
  fi
  local jq_err=""
  if ! jq_err="$(jq empty "$in" 2>&1)"; then
    err "入力がJSONとして不正です: $in"
    printf '%s\n' "$jq_err" >&2
    exit 1
  fi

  # ---- 出力先の決定と検査 ----
  local out="${2:-}"
  if [ -z "$out" ]; then
    resolve_out_path_to_reply "$in"
    out="$REPLY"
  fi
  if [ -d "$out" ]; then
    err "出力先がディレクトリです: $out"
    exit 1
  fi
  local out_dir="${out%/*}"
  if [ "$out_dir" != "$out" ] && [ ! -d "$out_dir" ]; then
    err "出力先の親ディレクトリがありません: $out_dir"
    exit 1
  fi

  # ---- 一時作業ディレクトリ（雛形の実体には触れない。異常終了時も残さない） ----
  # trapはmainを抜けた後に走るため、tmpはlocalにしない（set -u で未定義になる）
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  WORK="$tmp/work"
  mkdir -p "$WORK/ppt/slides/_rels"
  cp -R "$TEMPLATE_DIR/." "$WORK/"

  # ---- レコードストリームを1回のjqで得て、スライドXMLを組み立てる ----
  # レコードは一時ファイルへ落としてから読む。プロセス置換 < <(jq ...) だと jq の終了コードが
  # 呼び出し元へ伝わらず、途中失敗が「内容の欠けた .pptx を成功として出力する」形になるため
  # （敵対的レビューで実測）。コマンド置換で受けないのはレコードが入力サイズに比例するため
  if ! jq -r -f "$RECORDS_JQ" "$in" > "$tmp/records"; then
    err "入力の変換に失敗しました: $in（上のjqエラーを参照。$RECORDS_JQ の検証を通過したのに変換で失敗した場合は、このスキルの不具合として報告してください）"
    exit 1
  fi

  local meta_title="" meta_author="" meta_issue=""
  local overrides="" sldids="" slide_rels="" nslides=0
  local -a errors=()
  reset_slide_buffers

  local tag f1 f2 rest line
  local -a F
  while IFS= read -r line; do
    IFS="$US" read -r -a F <<<"$line"
    tag="${F[0]-}"
    case "$tag" in
      ERR)
        errors+=("${F[1]-}")
        ;;
      HDR)
        meta_title="${F[1]-}" meta_author="${F[2]-}" meta_issue="${F[3]-}"
        ;;
      NOTEWARN)
        warn "入力に speakerNotes 付きスライドが ${F[1]-0} 件ありますが、このスキルは speakerNotes を出力しません（.pptx には含まれません）"
        ;;
      SLIDE)
        flush_slide
        reset_slide_buffers
        CUR_N="${F[1]}" CUR_TYPE="${F[2]}"
        nslides=$((nslides + 1))
        ;;
      TITLE)
        case "$CUR_TYPE" in
          cover) para_title_to_reply "${F[1]-}" 4000 ;;
          section) para_title_to_reply "${F[1]-}" 3600 ;;
          *) para_title_to_reply "${F[1]-}" 3200 ;;
        esac
        CUR_TITLE+="$REPLY"
        ;;
      SUB)
        para_plain_to_reply "${F[1]-}" 2000
        CUR_SUB+="$REPLY"
        ;;
      BUL)
        para_bullet_to_reply "${F[1]}" "${F[2]-}"
        CUR_BODY+="$REPLY"
        ;;
      COL)
        para_plain_to_reply "${F[2]-}" 2000
        if [ "${F[1]}" = "L" ]; then CUR_COL_L+="$REPLY"; else CUR_COL_R+="$REPLY"; fi
        ;;
      TROW)
        # ここではバッファへ溜めるだけ。列数は全行の最大セル数で確定するため、
        # 行のXML化は flush_slide で行う（先頭行基準だとゼロ除算・超過セルの切り捨てが起きる）
        local ncells=$(( ${#F[@]} - 2 )) joined="" ci
        for ((ci = 2; ci < ${#F[@]}; ci++)); do joined+="${F[$ci]}$US"; done
        CUR_TBL_KINDS+=("${F[1]}")
        CUR_TBL_CELLS+=("$joined")
        if [ "$ncells" -gt "$CUR_TBL_NCOLS" ]; then CUR_TBL_NCOLS="$ncells"; fi
        ;;
    esac
  done < "$tmp/records"

  if [ "${#errors[@]}" -gt 0 ]; then
    err "入力の検証に失敗しました（$in）:"
    printf '  - %s\n' "${errors[@]}" >&2
    exit 1
  fi
  if [ "$nslides" -eq 0 ]; then
    # 検証済み入力なら必ず1件以上のSLIDEレコードが出る。ここに来るのはjq自体の失敗
    err "内部エラー: スライドレコードが得られませんでした（$RECORDS_JQ の実行に失敗した可能性）"
    exit 1
  fi
  flush_slide

  # ---- 連動5箇所の生成 ----
  # (1) スライド毎rels は flush_slide が出力済み
  # (2) [Content_Types].xml
  local i
  for ((i = 1; i <= nslides; i++)); do
    overrides+="<Override PartName=\"/ppt/slides/slide$i.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>"
    # (3) sldIdLst: id は256から、r:id はrId3から連番（rId1=slideMaster, rId2=theme 予約）
    sldids+="<p:sldId id=\"$((255 + i))\" r:id=\"rId$((i + 2))\"/>"
    slide_rels+="<Relationship Id=\"rId$((i + 2))\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide$i.xml\"/>"
  done

  printf '%s\n%s\n' \
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' \
    "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/ppt/presentation.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml\"/><Override PartName=\"/ppt/slideMasters/slideMaster1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml\"/><Override PartName=\"/ppt/slideLayouts/slideLayout1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml\"/><Override PartName=\"/ppt/theme/theme1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.theme+xml\"/>$overrides<Override PartName=\"/docProps/core.xml\" ContentType=\"application/vnd.openxmlformats-package.core-properties+xml\"/><Override PartName=\"/docProps/app.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.extended-properties+xml\"/></Types>" \
    > "$WORK/[Content_Types].xml"

  # (4) presentation.xml と ppt/_rels/presentation.xml.rels（生成スクリプトが丸ごと所有）
  printf '%s\n%s\n' \
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' \
    "<p:presentation xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\"><p:sldMasterIdLst><p:sldMasterId id=\"2147483648\" r:id=\"rId1\"/></p:sldMasterIdLst><p:sldIdLst>$sldids</p:sldIdLst><p:sldSz cx=\"12192000\" cy=\"6858000\"/><p:notesSz cx=\"6858000\" cy=\"9144000\"/></p:presentation>" \
    > "$WORK/ppt/presentation.xml"

  mkdir -p "$WORK/ppt/_rels"
  printf '%s\n%s\n' \
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' \
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster\" Target=\"slideMasters/slideMaster1.xml\"/><Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme\" Target=\"theme/theme1.xml\"/>$slide_rels</Relationships>" \
    > "$WORK/ppt/_rels/presentation.xml.rels"

  # (5) docProps/app.xml（枚数）
  printf '%s\n%s\n' \
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' \
    "<Properties xmlns=\"http://schemas.openxmlformats.org/officeDocument/2006/extended-properties\" xmlns:vt=\"http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes\"><Application>pptx-slides</Application><Slides>$nslides</Slides></Properties>" \
    > "$WORK/docProps/app.xml"

  # docProps/core.xml のプレースホルダ置換（sed/awkは使わない。&の再解釈の罠を避ける）
  local core created
  core="$(<"$WORK/docProps/core.xml")"
  created="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  xml_escape_to_reply "$meta_title";  core="${core//__PPTX_TITLE__/$REPLY}"
  xml_escape_to_reply "$meta_author"; core="${core//__PPTX_AUTHOR__/$REPLY}"
  xml_escape_to_reply "$meta_issue";  core="${core//__PPTX_KEYWORDS__/$REPLY}"
  core="${core//__PPTX_CREATED__/$created}"
  printf '%s\n' "$core" > "$WORK/docProps/core.xml"

  # ---- zip梱包（経路試行）。検証用のpythonは経路に関係なく先に検出しておく ----
  PY_CMD=""
  if detect_python_to_reply; then PY_CMD="$REPLY"; fi

  local tmp_pptx="$tmp/out.pptx" packed="" route
  local -a tried=()
  for route in zip python; do
    case "$route" in
      zip)
        command -v zip >/dev/null 2>&1 || { tried+=("zip(コマンドなし)"); continue; }
        rm -f "$tmp_pptx"
        if pack_with_zip "$WORK" "$tmp_pptx" && verify_pptx "$tmp_pptx" "$nslides"; then
          packed="zip"
          break
        fi
        # 途中経路の失敗はフォールバック（出力を削除して次の経路へ）
        rm -f "$tmp_pptx"
        tried+=("zip(生成または検証に失敗)")
        ;;
      python)
        [ -n "$PY_CMD" ] || { tried+=("python3/python/py -3(import zipfile が通る候補なし)"); continue; }
        rm -f "$tmp_pptx"
        if pack_with_python "$PY_CMD" "$WORK" "$tmp_pptx" && verify_pptx "$tmp_pptx" "$nslides"; then
          packed="python($PY_CMD)"
          break
        fi
        rm -f "$tmp_pptx"
        tried+=("python($PY_CMD)(生成または検証に失敗)")
        ;;
    esac
  done

  if [ -z "$packed" ]; then
    rm -f "$tmp_pptx"
    err "zip梱包に使える経路がありません（試行: ${tried[*]:-なし}）。zip コマンドか、zipfile モジュールを持つ python3 / python / py -3 のいずれかをインストールしてください"
    exit 1
  fi

  mv "$tmp_pptx" "$out"
  printf 'json-to-pptx: %s を生成しました（スライド%d枚・経路=%s）\n' "$out" "$nslides" "$packed"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
