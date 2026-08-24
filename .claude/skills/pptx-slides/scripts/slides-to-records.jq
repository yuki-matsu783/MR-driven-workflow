# 構成案JSON → フラットなレコードストリーム（US区切り・1行1レコード）への変換。
# json-to-pptx.sh から `jq -r -f` で1回だけ呼ばれる（ループ内でjqを起動しないための集約。
# .claude/rules/shell-script-style.md「外部プロセス起動のコスト」）。
#
# レコード種別（先頭フィールド）:
#   ERR      <メッセージ>                 入力検証エラー（1件でもあれば他のレコードは出さない）
#   HDR      <meta.title> <author> <issue> docProps用のヘッダ値（未エスケープの生値）
#   NOTEWARN <件数>                        speakerNotes付きスライドの件数（0なら出さない）
#   SLIDE    <n> <type>                    スライド開始（nは1始まり）
#   TITLE    <行>                          スライド見出しの段落（改行は複数レコードに分割済み）
#   SUB      <行>                          coverのサブタイトル行（subtitle・date・author）
#   BUL      <lvl> <行>                    箇条書き段落（lvl=0/1）
#   COL      <L|R> <行>                    2カラムの段落
#   TROW     <H|D> <セル>...               表の行（セル内改行は空白へ潰す）
#
# 値の正規化: CR除去・XML 1.0が許さないC0制御文字（TAB/LF/CR以外。US=0x1Fを含む）は
# 空白へ・改行は段落分割（TROWのセルのみ空白化）。
# XMLエスケープはここでは行わない（bash側の xml_escape_to_reply が唯一の実装）。

def u: "\u001f";
def clean: tostring | gsub("\r"; "") | gsub("[\u0000-\u0008\u000b\u000c\u000e-\u001f]"; " ");
def plines: clean | split("\n") | map(select(. != ""));
def cell: clean | gsub("\n"; " ");
def joined: if type == "array" then map(cell) | join(" / ") elif . == null then "" else cell end;
def node_text: if type == "object" then (.label // .id // "") else . end;
def item_text: if type == "object" then (.text // .label // "") else . end;

["cover","section","bullets","two-column","diagram","table","comparison","summary"] as $types

| . as $d
| ($d.slides) as $slides

# ---- 入力検証（必須キー表。上流/独自の別は調査レポートQ2の表が正） ----
| (
    [ (if ($d.meta | type) != "object" or (($d.meta.title? | type) != "string") or ($d.meta.title == "")
       then "meta.title（文字列・必須）がありません" else empty end),
      (if ($slides | type) != "array" or ($slides | length) == 0
       then "slides（配列・1件以上・必須）がありません" else empty end) ]
    + ( if ($slides | type) == "array" then
          [ $slides | to_entries[] | .key as $i | .value as $s |
            ( if ($s | type) != "object" then "slides[\($i)] がオブジェクトではありません"
              else (
                (if (($s.type? | type) != "string") or (($types | index($s.type)) == null)
                 then "slides[\($i)].type が8種enum（\($types | join("/"))）にありません" else empty end),
                (if (($s.title? | type) != "string") or ($s.title == "")
                 then "slides[\($i)].title（文字列・必須。全型必須）がありません" else empty end),
                (if ($s.type == "bullets" or $s.type == "summary") and (($s.items? | type) != "array")
                 then "slides[\($i)].items（配列・必須）がありません" else empty end),
                (if $s.type == "two-column" and (($s.left? == null) or ($s.right? == null))
                 then "slides[\($i)].left / .right（必須）がありません" else empty end),
                (if $s.type == "table" and ((($s.headers? | type) != "array") or (($s.rows? | type) != "array"))
                 then "slides[\($i)].headers / .rows（配列・必須）がありません" else empty end),
                # 要素の型まで検証する（配列であることしか見ないと、bash側の実行時に
                # jqがエラー終了して内容の欠落・ゼロ除算として表面化する）
                (if $s.type == "table" and (($s.headers? | type) == "array") and (($s.headers | length) == 0)
                 then "slides[\($i)].headers が空です（1件以上必要）" else empty end),
                (if $s.type == "table" and (($s.rows? | type) == "array")
                 then ($s.rows | to_entries[] | select(.value | type != "array")
                       | "slides[\(($i | tostring))].rows[\(.key)] が配列ではありません") else empty end),
                (if $s.type == "comparison" and (($s.options? | type) != "array")
                 then "slides[\($i)].options（配列・必須）がありません" else empty end),
                (if $s.type == "comparison" and (($s.options? | type) == "array") and (($s.options | length) == 0)
                 then "slides[\($i)].options が空です（1件以上必要）" else empty end),
                (if $s.type == "comparison" and (($s.options? | type) == "array")
                 then ($s.options | to_entries[] | select(.value | type != "object")
                       | "slides[\(($i | tostring))].options[\(.key)] がオブジェクトではありません") else empty end),
                (if $s.type == "diagram" and (($s.nodes? | type) != "array")
                 then "slides[\($i)].nodes（配列・必須。edgesは任意）がありません" else empty end),
                (if $s.type == "diagram" and ($s.edges? != null) and (($s.edges | type) != "array")
                 then "slides[\($i)].edges が配列ではありません" else empty end),
                (if $s.type == "diagram" and (($s.edges? | type) == "array")
                 then ($s.edges | to_entries[] | select(.value | type != "object")
                       | "slides[\(($i | tostring))].edges[\(.key)] がオブジェクトではありません") else empty end)
              ) end )
          ]
        else [] end )
  ) as $errs

| if ($errs | length) > 0 then $errs[] | "ERR" + u + .
  else (
    # docProps行きの値は1行の意味を持つため、改行も空白へ潰す（cell）。
    # clean のままだと値内の改行でHDRレコード自体が行分割され、2行目以降が捨てられる
    ( "HDR" + u + ($d.meta.title | cell)
            + u + (($d.meta.author // "") | cell)
            + u + (($d.meta.issue // "") | cell) ),
    ( [$slides[] | select(has("speakerNotes"))] | length
      | if . > 0 then "NOTEWARN" + u + tostring else empty end ),
    ( $slides | to_entries[] | (.key + 1) as $n | .value as $s | $s.type as $t |
      ( "SLIDE" + u + ($n | tostring) + u + $t ),
      ( $s.title | plines[] | "TITLE" + u + . ),
      ( if $t == "cover" then
          ( ($d.meta.subtitle // "") | plines[] | "SUB" + u + . ),
          ( ($d.meta.date // "") | plines[] | "SUB" + u + . ),
          ( ($d.meta.author // "") | plines[] | "SUB" + u + . )
        elif $t == "bullets" or $t == "summary" then
          ( $s.items[] |
            if type == "object" then
              ( item_text | plines[] | "BUL" + u + "0" + u + . ),
              ( ((.items // .children // [])[]) | item_text | plines[] | "BUL" + u + "1" + u + . )
            else plines[] | "BUL" + u + "0" + u + . end )
        elif $t == "two-column" then
          ( $s.left  | (if type == "array" then .[] else . end) | plines[] | "COL" + u + "L" + u + . ),
          ( $s.right | (if type == "array" then .[] else . end) | plines[] | "COL" + u + "R" + u + . )
        elif $t == "table" then
          ( "TROW" + u + "H" + u + ([$s.headers[] | cell] | join(u)) ),
          ( $s.rows[] | "TROW" + u + "D" + u + ([.[] | cell] | join(u)) )
        elif $t == "comparison" then
          ( "TROW" + u + "H" + u + (([""] + [$s.options[] | (.name // .label // "") | cell]) | join(u)) ),
          ( "TROW" + u + "D" + u + ((["利点"] + [$s.options[] | (.pros // .advantages) | joined]) | join(u)) ),
          ( "TROW" + u + "D" + u + ((["欠点"] + [$s.options[] | (.cons // .disadvantages) | joined]) | join(u)) ),
          ( "TROW" + u + "D" + u + ((["採否"] + [$s.options[] | (.verdict // .decision) | joined]) | join(u)) )
        elif $t == "diagram" then
          ( $s.nodes[] | node_text | plines[] | "BUL" + u + "0" + u + . ),
          ( ($s.edges // [])[] |
            ( ((.from // "") | clean) + " → " + ((.to // "") | clean)
              + (if (.label // "") != "" then "（" + (.label | clean) + "）" else "" end) )
            | "BUL" + u + "0" + u + . ),
          ( ($s.caption // "") | plines[] | "BUL" + u + "0" + u + . )
        else empty end )
    )
  ) end
