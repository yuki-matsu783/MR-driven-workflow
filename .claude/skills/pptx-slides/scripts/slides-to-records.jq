# 構成案JSON → フラットなレコードストリーム（US区切り・1行1レコード）への変換。
# json-to-pptx.sh から `jq -r -f` で1回だけ呼ばれる（ループ内でjqを起動しないための集約。
# .claude/rules/shell-script-style.md「外部プロセス起動のコスト」）。
# 入力仕様の正: .claude/skills/html-slides/references/slide-outline.schema.json（issue #168）。
#
# レコード種別（先頭フィールド）:
#   ERR      <メッセージ>                 入力検証エラー（1件でもあれば他のレコードは出さない）
#   HDR      <meta.title> <author> <issue> docProps用のヘッダ値（未エスケープの生値）
#   NOTEWARN <件数>                        speakerNotes付きスライドの件数（0なら出さない）
#   SLIDE    <n> <type>                    スライド開始（nは1始まり）
#   TITLE    <行>                          スライド見出しの段落（coverは title // meta.title）
#   SUB      <行>                          coverのサブタイトル行（subtitle // meta.subtitle・date・author）
#   CHAP     <行>                          sectionの章番号段落（chapter があるときだけ）
#   BUL      <lvl> <行>                    箇条書き段落（items は文字列のみのため lvl は常に0）
#   COLH     <L|R> <行>                    2カラムのカラム見出し（columns[0]→L, columns[1]→R）
#   COL      <L|R> <行>                    2カラムの段落
#   PARA     <b|n> <行>                    箇条書き記号の付かない本文段落（b=太字。diagramのフロー
#                                          表現・noteの行は n、summaryのtakeawayは b）
#   TROW     <H|D> <セル数> <セル>...       表の行（セル内改行は空白へ潰す。comparisonはヘッダ=
#                                          name＋tone注記、データ行=各sideのpointsの転置。
#                                          セル数を明示するのは、末尾セルが空だと
#                                          read -a が区切り1つ分を落とすため。AR-4-18）
#
# 値の正規化: CR除去・XML 1.0が許さないC0制御文字（TAB/LF/CR以外。US=0x1Fを含む）は
# 空白へ・改行は段落分割（TROWのセルのみ空白化）。
# XMLエスケープはここでは行わない（bash側の xml_escape_to_reply が唯一の実装）。

def u: "\u001f";
# XML 1.0のCharが許さない範囲: C0制御文字（TAB/LF/CR以外）に加え、U+FFFE・U+FFFFも対象
# （AR-4-12。JSON文字列としては正当だがXML化できず生成が壊れるため、ここで正規化する）。
def clean: tostring | gsub("\r"; "") | gsub("[\u0000-\u0008\u000b\u000c\u000e-\u001f\ufffe\uffff]"; " ");
def plines: clean | split("\n") | map(select(. != ""));
def cell: clean | gsub("\n"; " ");
def tone_note: if . == "pro" then "（採用寄り）"
  elif . == "con" then "（却下寄り）"
  elif . == "neutral" then "（中立）"
  else "" end;

["cover","section","bullets","two-column","diagram","table","comparison","summary"] as $types

| . as $d
# トップレベルが非オブジェクトだと $d.slides の評価自体がjqのエラー終了になる（AR-4-13）。
# それより前に型チェックを行い、明示エラーへ落とす。
| if ($d | type) != "object" then "ERR" + u + "入力のトップレベルがオブジェクトではありません"
  else (
($d.slides) as $slides

# ---- 入力検証（確定スキーマの必須キー・要素型に揃える。スキーマファイル自体は読まない） ----
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
                # title は cover のみ任意（省略時 meta.title を採る）。他の7型は必須。
                # スキーマは title を {"type":"string"} としか定めず空文字列も適合するため
                # 空文字列は拒否しない（AR-4-14）。
                (if ($s.type != "cover") and (($s.title? | type) != "string")
                 then "slides[\($i)].title（文字列・必須。cover以外は必須）がありません" else empty end),
                (if ($s.type == "cover") and ($s | has("title")) and (($s.title | type) != "string")
                 then "slides[\($i)].title が文字列ではありません" else empty end),
                (if ($s.type == "bullets" or $s.type == "summary")
                    and ((($s.items? | type) != "array") or (($s.items | length) == 0))
                 then "slides[\($i)].items（配列・1件以上・必須）がありません" else empty end),
                (if ($s.type == "bullets" or $s.type == "summary") and (($s.items? | type) == "array")
                 then ($s.items | to_entries[] | select(.value | type != "string")
                       | "slides[\(($i | tostring))].items[\(.key)] が文字列ではありません") else empty end),
                (if $s.type == "two-column"
                    and ((($s.columns? | type) != "array") or (($s.columns | length) != 2))
                 then "slides[\($i)].columns（配列・ちょうど2件・必須）がありません" else empty end),
                (if $s.type == "two-column" and (($s.columns? | type) == "array")
                 then ($s.columns | to_entries[] | .key as $ci | .value as $c |
                       if ($c | type) != "object"
                          or (($c.heading? | type) != "string")
                          or (($c.items? | type) != "array") or (($c.items | length) == 0)
                       then "slides[\(($i | tostring))].columns[\($ci)] は heading（文字列）と items（配列・1件以上）を持つオブジェクトが必要です"
                       else empty end) else empty end),
                # 要素の型まで検証する（AR-4-15。bullets/summary の items[] と同様、
                # 非文字列の要素をtostringで素通しするとJSON表現がそのままスライド本文になる）
                (if $s.type == "two-column" and (($s.columns? | type) == "array")
                 then ($s.columns | to_entries[] | .key as $ci | .value as $c |
                       if ($c | type) == "object" and (($c.items? | type) == "array")
                       then ($c.items | to_entries[] | select(.value | type != "string")
                             | "slides[\(($i | tostring))].columns[\($ci)].items[\(.key)] が文字列ではありません")
                       else empty end) else empty end),
                (if $s.type == "table"
                    and ((($s.columns? | type) != "array") or (($s.columns | length) == 0))
                 then "slides[\($i)].columns（配列・1件以上・必須）がありません" else empty end),
                (if $s.type == "table" and (($s.rows? | type) != "array")
                 then "slides[\($i)].rows（配列・必須）がありません" else empty end),
                # 要素の型まで検証する（配列であることしか見ないと、bash側の実行時に
                # jqがエラー終了して内容の欠落・ゼロ除算として表面化する）
                (if $s.type == "table" and (($s.rows? | type) == "array")
                 then ($s.rows | to_entries[] | select(.value | type != "array")
                       | "slides[\(($i | tostring))].rows[\(.key)] が配列ではありません") else empty end),
                (if $s.type == "table" and (($s.rows? | type) == "array")
                 then ($s.rows | to_entries[] | .key as $ri | .value as $row |
                       if ($row | type) == "array"
                       then ($row | to_entries[] | select(.value | type != "string")
                             | "slides[\(($i | tostring))].rows[\($ri)][\(.key)] が文字列ではありません")
                       else empty end) else empty end),
                (if $s.type == "comparison"
                    and ((($s.sides? | type) != "array") or (($s.sides | length) < 2) or (($s.sides | length) > 3))
                 then "slides[\($i)].sides（配列・2〜3件・必須）がありません" else empty end),
                (if $s.type == "comparison" and (($s.sides? | type) == "array")
                 then ($s.sides | to_entries[] | .key as $si | .value as $o |
                       if ($o | type) != "object"
                          or (($o.name? | type) != "string")
                          or (($o.points? | type) != "array") or (($o.points | length) == 0)
                       then "slides[\(($i | tostring))].sides[\($si)] は name（文字列）と points（配列・1件以上）を持つオブジェクトが必要です"
                       else empty end) else empty end),
                (if $s.type == "comparison" and (($s.sides? | type) == "array")
                 then ($s.sides | to_entries[] | .key as $si | .value as $o |
                       if ($o | type) == "object" and (($o.points? | type) == "array")
                       then ($o.points | to_entries[] | select(.value | type != "string")
                             | "slides[\(($i | tostring))].sides[\($si)].points[\(.key)] が文字列ではありません")
                       else empty end) else empty end),
                (if $s.type == "diagram"
                    and ((($s.nodes? | type) != "array") or (($s.nodes | length) < 2))
                 then "slides[\($i)].nodes（配列・2件以上・必須）がありません" else empty end),
                (if $s.type == "diagram" and (($s.nodes? | type) == "array")
                 then ($s.nodes | to_entries[] | .key as $ni | .value as $nd |
                       if ($nd | type) != "object" or (($nd.label? | type) != "string")
                       then "slides[\(($i | tostring))].nodes[\($ni)] は label（文字列）を持つオブジェクトが必要です"
                       else empty end) else empty end),
                (if $s.type == "diagram" and (($s.nodes? | type) == "array")
                 then ($s.nodes | to_entries[] | .key as $ni | .value as $nd |
                       if ($nd | type) == "object" and ($nd | has("note")) and (($nd.note | type) != "string")
                       then "slides[\(($i | tostring))].nodes[\($ni)].note が文字列ではありません"
                       else empty end) else empty end)
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
      # cover の見出しは title // meta.title（スキーマ: 省略時は meta の値を表示する）
      ( (if $t == "cover" then ($s.title // $d.meta.title) else $s.title end)
        | plines[] | "TITLE" + u + . ),
      ( if $t == "cover" then
          ( (($s.subtitle // $d.meta.subtitle) // "") | plines[] | "SUB" + u + . ),
          ( ($d.meta.date // "") | plines[] | "SUB" + u + . ),
          ( ($d.meta.author // "") | plines[] | "SUB" + u + . )
        elif $t == "section" then
          ( ($s.chapter // "") | plines[] | "CHAP" + u + . )
        elif $t == "bullets" then
          ( $s.items[] | plines[] | "BUL" + u + "0" + u + . )
        elif $t == "summary" then
          ( $s.items[] | plines[] | "BUL" + u + "0" + u + . ),
          ( ($s.takeaway // "") | plines[] | "PARA" + u + "b" + u + . )
        elif $t == "two-column" then
          ( $s.columns[0] | ( (.heading | plines[] | "COLH" + u + "L" + u + . ),
                             ( .items[] | plines[] | "COL" + u + "L" + u + . ) ) ),
          ( $s.columns[1] | ( (.heading | plines[] | "COLH" + u + "R" + u + . ),
                             ( .items[] | plines[] | "COL" + u + "R" + u + . ) ) )
        elif $t == "table" then
          # セル数をフィールドとして明示する（AR-4-18）。bash側の read -a は区切り1つ分の
          # 末尾空フィールドを落とすため、行末セルが空だと ${#F[@]} からの逆算が過小評価する。
          ( "TROW" + u + "H" + u + ($s.columns | length | tostring)
            + u + ([$s.columns[] | cell] | join(u)) ),
          ( $s.rows[] | "TROW" + u + "D" + u + (length | tostring) + u + ([.[] | cell] | join(u)) )
        elif $t == "comparison" then
          # 列 = 各side（ヘッダ=name＋tone注記）、行 = points の転置（不足セルは空埋め）
          ( "TROW" + u + "H" + u + ($s.sides | length | tostring)
            + u + ([$s.sides[] | ((.name | cell) + (.tone | tone_note))] | join(u)) ),
          ( ($s.sides | map(.points)) as $cols
            | ($cols | map(length) | max) as $nr
            | range(0; $nr) as $ri
            | "TROW" + u + "D" + u + ($cols | length | tostring)
              + u + ([$cols[] | ((.[$ri] // "") | cell)] | join(u)) )
        elif $t == "diagram" then
          # フロー表現: label を「 → 」で連結した1段落＋noteを持つノードごとに「label: note」
          ( "PARA" + u + "n" + u + ([$s.nodes[].label | cell] | join(" → ")) ),
          ( $s.nodes[] | select((.note // "") != "")
            | "PARA" + u + "n" + u + ((.label | cell) + ": " + (.note | cell)) )
        else empty end )
    )
  ) end
) end
