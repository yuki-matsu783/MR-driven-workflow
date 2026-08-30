#!/usr/bin/env bash
# .claude/skills/pptx-slides/scripts/json-to-pptx.sh の単体テスト（issue #169）。
#
# 対象:
# - 純粋関数: xml_escape_to_reply（5種の特殊文字・日本語・&の一回置換）、
#   resolve_out_path_to_reply（出力パスの既定値導出）。source して直接呼ぶ
#   （main guard により副作用なく関数定義のみが読み込まれる）。
# - スキーマ適合: サンプルJSONが構成案JSONスキーマ（slide-outline.schema.json）に適合する
#   ことを、jqによる決定的チェック（required・additionalProperties:false・型・minItems/
#   maxItems・enum・const。oneOfはtypeのconstで枝を選ぶ）で機械検証する（pythonの
#   jsonschema はこの環境に無いことを実測済み・issue #169）。チェック自体の空振りは、
#   意図的に不適合なJSON（余剰キー）が検出されることで排除する。
# - 正常系: スキーマ適合の8種type全部入りサンプル（coverは2枚: metaフォールバック側と
#   自前title/subtitle側）から .pptx を生成し、機械検証一式
#   （zip整合性・先頭エントリ・ディレクトリエントリ0・全XML well-formed・必須パーツ・
#   Content_Types突合・rels整合・rId重複0・sldIdLst整合・table/comparisonのa:tbl存在・
#   条件7の葉テキスト突合・core.xml/app.xmlのプロパティ）を verify_pptx.py（テスト内で
#   生成するpython検証スクリプト）で検査する。tone注記・coverのmetaフォールバックの写像は
#   個別アサーションで固定する（tone・cover省略側は条件7の突合から漏れるため）。
# - 経路: zip経路とpython経路（`zip` をPATHから隠す）の両方で生成し、経路間突合
#   （エントリ集合の一致＋先頭が [Content_Types].xml＋ディレクトリエントリ0件。
#   順序全体は比較しない——`zip -r` の格納順はFS走査順に依存するため）を行う。
#   さらに「`zip` はあるが失敗する」スタブでのフォールバック、「存在するが実行できない
#   `python3`」スタブでの候補送り（python3→python）、全候補失敗時・全経路不在時の
#   明示エラー、失敗時に出力ファイル・一時ディレクトリを残さないこと（TMPDIR制御）を検査する。
# - 異常系: 不正JSON／type不正／title・meta.title欠落／空slides／入力ファイル無し／
#   出力先がディレクトリ／親ディレクトリ不在。speakerNotes入り入力の警告（rc=0のまま）。
#   境界値は確定スキーマの語彙（columns/sides/nodes）で検査する。旧語彙（headers/options/
#   left/right）・edges・入れ子bulletsのテストはスキーマ確定への追従（issue #169 フェーズ4）で
#   削除した（スキーマが持たない形のため。検証・分岐ごと削除）。
#
# 前提: python3（zipfile・xml.etree）が使えること（この環境で実測済み。検証スクリプトが使う）。
# PATH制限テストは jq/cp/mkdir/mv/date/rm/mktemp だけの合成binを作って行う。
# 規約: passed=N failures=N を標準出力へ出し、失敗があれば終了コード1
#       （.claude/rules/shell-script-style.md「テスト」）。
# 実行: bash .claude/scripts/test/test_json_to_pptx.sh
set -euo pipefail

script_dir="${BASH_SOURCE[0]%/*}"
[[ "$script_dir" == "${BASH_SOURCE[0]}" ]] && script_dir="."
repo_root="$(cd "$script_dir/../../.." && pwd)"
target="$repo_root/.claude/skills/pptx-slides/scripts/json-to-pptx.sh"

passed=0
failures=0

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    passed=$((passed + 1))
  else
    failures=$((failures + 1))
    echo "FAIL: $name"
    echo "  expected: $expected"
    echo "  actual  : $actual"
  fi
}

assert_contains() {
  local name="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    passed=$((passed + 1))
  else
    failures=$((failures + 1))
    echo "FAIL: $name"
    echo "  expected to contain: $needle"
    echo "  actual            : $haystack"
  fi
}

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

# ---------------------------------------------------------------------------
# 純粋関数（source して直接呼ぶ）
# ---------------------------------------------------------------------------
# shellcheck source=../../skills/pptx-slides/scripts/json-to-pptx.sh
source "$target"

xml_escape_to_reply 'A&B<C>D"E'\''F日本語'
assert_eq "xml_escape: 5種の特殊文字と日本語" \
  'A&amp;B&lt;C&gt;D&quot;E&apos;F日本語' "$REPLY"

xml_escape_to_reply '&lt;'
assert_eq "xml_escape: &を最初に置換し二重エスケープしない" '&amp;lt;' "$REPLY"

resolve_out_path_to_reply "dir/deck.slides.json"
assert_eq "resolve_out_path: .slides.json は両方落とす" "dir/deck.pptx" "$REPLY"
resolve_out_path_to_reply "deck.json"
assert_eq "resolve_out_path: ディレクトリ無しは ./ 扱い" "./deck.pptx" "$REPLY"
resolve_out_path_to_reply "noext"
assert_eq "resolve_out_path: 拡張子なしはそのまま .pptx を付ける" "./noext.pptx" "$REPLY"
resolve_out_path_to_reply "/abs/path/x.slides.json"
assert_eq "resolve_out_path: 絶対パス" "/abs/path/x.pptx" "$REPLY"

# ---------------------------------------------------------------------------
# サンプル入力（スキーマ適合・8種type全部入り・特殊文字・値内改行）
# coverは2枚: 1枚目はtitle/subtitle省略でmetaフォールバックを、2枚目は自前の
# title/subtitleで上書き側を検証する（meta.title/meta.subtitleは1枚目の<a:t>へ
# 現れるため、条件7の突合対象のままで通るサンプル設計。issue #169 フェーズ4）
# ---------------------------------------------------------------------------
cat > "$T/sample.slides.json" <<'EOF'
{
  "meta": {
    "title": "発表資料 <Q3> & \"計画\"",
    "subtitle": "サブタイトル 'テスト'",
    "date": "2026-08-24",
    "author": "山田 & 太郎",
    "issue": 169
  },
  "slides": [
    {"type": "cover"},
    {"type": "cover", "title": "pptx書き出し機能の紹介", "subtitle": "表紙の自前サブタイトル"},
    {"type": "section", "chapter": "第1章", "title": "背景 & 目的"},
    {"type": "bullets", "title": "要点一覧", "items": [
      "特殊文字 <&> \" ' を含む項目",
      "二行にわたる\n項目テキスト",
      "三つ目の項目"
    ]},
    {"type": "two-column", "title": "比較の前提", "columns": [
      {"heading": "現状", "items": ["左カラム1行目", "左カラム2行目"]},
      {"heading": "あるべき姿", "items": ["右カラム1行目"]}
    ]},
    {"type": "table", "title": "実測値の表",
     "columns": ["項目", "値"],
     "rows": [["経路zip", "0.9秒"], ["経路python", "1.2秒"]]},
    {"type": "comparison", "title": "代替案の比較", "sides": [
      {"name": "案A", "points": ["速い", "単純"], "tone": "pro"},
      {"name": "案B", "points": ["移植性が高い"], "tone": "con"},
      {"name": "案C", "points": ["中間の性質"], "tone": "neutral"}
    ]},
    {"type": "diagram", "title": "処理の流れ",
     "nodes": [{"label": "入力JSON"}, {"label": "生成", "note": "jq 1回"}, {"label": "検証"}]},
    {"type": "summary", "title": "まとめ", "items": ["編集可能なpptxを生成できる"],
     "takeaway": "構成案JSONがそのままPowerPointになる"}
  ]
}
EOF

# ---------------------------------------------------------------------------
# スキーマ適合の機械検証（jqによる決定的チェック）。
# スキーマの正はワーキングツリー（flow-id 5-1 のmain取り込み後に存在する）。
# 取り込み前のブランチでは origin/main から読む。どちらからも得られなければ失敗として数える
# （目視へ縮退させない）
# ---------------------------------------------------------------------------
schema_path=".claude/skills/html-slides/references/slide-outline.schema.json"
if [ -f "$repo_root/$schema_path" ]; then
  cp "$repo_root/$schema_path" "$T/schema.json"
else
  git -C "$repo_root" show "origin/main:$schema_path" > "$T/schema.json" 2>/dev/null || true
fi

cat > "$T/schema_check.jq" <<'EOF'
# 構成案JSONスキーマ（draft-07の基本語彙のみ使用）に対する決定的な適合チェック。
# 検査: $ref解決（#/definitions/のみ）・type（integer含む）・enum・const・required・
# additionalProperties:false の余剰キー・properties再帰・minItems/maxItems・items再帰・
# oneOf（properties.type.const で枝を1つ選ぶ。この形はslides items専用）。
# 出力: エラーメッセージの配列（空なら適合）
def deref($s; $root):
  if ($s | has("$ref")) then $root.definitions[($s["$ref"] | ltrimstr("#/definitions/"))]
  else $s end;
def errors($v; $s; $path; $root):
  deref($s; $root) as $sc
  | if ($sc | has("oneOf")) then
      ([$sc.oneOf[] | deref(.; $root)]) as $branches
      | ([$branches[] | select(.properties.type.const == ($v.type? // null))]) as $m
      | if ($m | length) == 1 then errors($v; $m[0]; $path; $root)
        else ["\($path): oneOfのどの枝にも一致しません（type=\($v.type? // "無し")）"] end
    else
      ( if ($sc.type? != null) then
          ($v | type) as $vt
          | if $sc.type == "integer"
            then (if ($vt == "number") and ($v == ($v | floor)) then [] else ["\($path): integerが必要（実際: \($vt)）"] end)
            else (if $vt == $sc.type then [] else ["\($path): \($sc.type)が必要（実際: \($vt)）"] end) end
        else [] end )
      + ( if ($sc.enum? != null) then
            (if ($sc.enum | index($v)) != null then [] else ["\($path): enum \($sc.enum | join("/")) にありません"] end)
          else [] end )
      + ( if ($sc.const? != null) then
            (if $v == $sc.const then [] else ["\($path): const \($sc.const) と一致しません"] end)
          else [] end )
      + ( if (($v | type) == "object") and ($sc.required? != null) then
            # `.` はパイプで差し替わるため先に $k へ束縛する（shell-script-style.md「JSON操作」）
            [ $sc.required[] | . as $k | select(($v | has($k)) | not)
              | "\($path).\($k) がありません（required）" ]
          else [] end )
      + ( if (($v | type) == "object") and ($sc.additionalProperties? == false) then
            [ ($v | keys[]) | . as $k | select((($sc.properties // {}) | has($k)) | not)
              | "\($path).\($k) は余剰キーです（additionalProperties: false）" ]
          else [] end )
      + ( if (($v | type) == "object") and ($sc.properties? != null) then
            ([ ($sc.properties | to_entries[]) | .key as $k
               | select($v | has($k)) | errors($v[$k]; .value; "\($path).\($k)"; $root) ] | add // [])
          else [] end )
      + ( if (($v | type) == "array") then
            ( if ($sc.minItems? != null) and (($v | length) < $sc.minItems)
              then ["\($path): minItems \($sc.minItems) 未満（\($v | length)件）"] else [] end )
            + ( if ($sc.maxItems? != null) and (($v | length) > $sc.maxItems)
                then ["\($path): maxItems \($sc.maxItems) 超過（\($v | length)件）"] else [] end )
            + ( if ($sc.items? != null) then
                  ([ ($v | to_entries[]) | errors(.value; $sc.items; "\($path)[\(.key)]"; $root) ] | add // [])
                else [] end )
          else [] end )
    end;
$schema[0] as $root | errors($doc[0]; $root; ""; $root)
EOF

if [ -s "$T/schema.json" ]; then
  verrs="$(jq -n -c --slurpfile schema "$T/schema.json" --slurpfile doc "$T/sample.slides.json" -f "$T/schema_check.jq")"
  assert_eq "スキーマ適合: サンプルが確定スキーマに適合する" "[]" "$verrs"
  # 空振り排除: 意図的に不適合（余剰キー・enum違反）を作ると検出されること
  jq '.slides[0].bogus = "x" | .slides[6].sides[0].tone = "maybe"' "$T/sample.slides.json" > "$T/nonconform.json"
  nerrs="$(jq -n -c --slurpfile schema "$T/schema.json" --slurpfile doc "$T/nonconform.json" -f "$T/schema_check.jq" | jq 'length')"
  assert_eq "スキーマ適合: 不適合サンプルで2件検出（空振り排除）" "2" "$nerrs"
else
  failures=$((failures + 1))
  echo "FAIL: スキーマ適合: スキーマ（$schema_path）をワーキングツリーからも origin/main からも取得できない"
fi

# ---------------------------------------------------------------------------
# 機械検証スクリプト（python）。1つの .pptx に対する検証一式
# ---------------------------------------------------------------------------
cat > "$T/verify_pptx.py" <<'EOF'
import json, posixpath, re, sys, zipfile
import xml.etree.ElementTree as ET

pptx, injson = sys.argv[1], sys.argv[2]
ok = fail = 0
def report(name, cond, detail=""):
    global ok, fail
    if cond:
        ok += 1
        print("OK: " + name)
    else:
        fail += 1
        print("FAIL: " + name + ((": " + detail) if detail else ""))

z = zipfile.ZipFile(pptx)
names = z.namelist()

report("zip整合性(testzip)", z.testzip() is None)
report("先頭が[Content_Types].xmlかつディレクトリエントリ0件",
       names[0] == "[Content_Types].xml" and not any(n.endswith("/") for n in names),
       repr(names[:3]))

bad = []
for n in names:
    if n.endswith(".xml") or n.endswith(".rels"):
        try:
            ET.fromstring(z.read(n))
        except ET.ParseError as e:
            bad.append(n + ": " + str(e))
report("全XMLパーツがwell-formed", not bad, "; ".join(bad))

data = json.load(open(injson, encoding="utf-8"))
nslides = len(data["slides"])

required = ["[Content_Types].xml", "_rels/.rels", "docProps/core.xml", "docProps/app.xml",
            "ppt/presentation.xml", "ppt/_rels/presentation.xml.rels",
            "ppt/slideMasters/slideMaster1.xml", "ppt/slideLayouts/slideLayout1.xml",
            "ppt/theme/theme1.xml"]
for i in range(1, nslides + 1):
    required += ["ppt/slides/slide%d.xml" % i, "ppt/slides/_rels/slide%d.xml.rels" % i]
missing = [p for p in required if p not in names]
report("必須パーツが全て存在", not missing, "; ".join(missing))

NS_CT = "{http://schemas.openxmlformats.org/package/2006/content-types}"
ct = ET.fromstring(z.read("[Content_Types].xml"))
overrides = [e.get("PartName") for e in ct.findall(NS_CT + "Override")]
ov_missing = [p for p in overrides if p.lstrip("/") not in names]
slide_ov = [p for p in overrides if re.match(r"^/ppt/slides/slide\d+\.xml$", p or "")]
report("Content_Types突合（Override全実在＋スライドOverride枚数一致）",
       not ov_missing and len(slide_ov) == nslides,
       "missing=%s slide_ov=%d" % (ov_missing, len(slide_ov)))

NS_R = "{http://schemas.openxmlformats.org/package/2006/relationships}"
bad_target, rid_dup, rels_ids = [], [], {}
for n in names:
    if not n.endswith(".rels"):
        continue
    root = ET.fromstring(z.read(n))
    base = posixpath.dirname(posixpath.dirname(n))  # x/_rels/y.rels -> x
    ids = []
    for rel in root.findall(NS_R + "Relationship"):
        ids.append(rel.get("Id"))
        tgt = rel.get("Target")
        resolved = posixpath.normpath(posixpath.join(base, tgt) if base else tgt)
        if resolved not in names:
            bad_target.append(n + " -> " + tgt)
    if len(ids) != len(set(ids)):
        rid_dup.append(n)
    rels_ids[n] = ids
report("rels整合（全Targetのパーツが実在）", not bad_target, "; ".join(bad_target))
report("rId重複0（全relsファイル）", not rid_dup, "; ".join(rid_dup))

NS_P = "{http://schemas.openxmlformats.org/presentationml/2006/main}"
NS_REL = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}"
NS_A = "{http://schemas.openxmlformats.org/drawingml/2006/main}"
pres = ET.fromstring(z.read("ppt/presentation.xml"))
sldids = pres.findall(NS_P + "sldIdLst/" + NS_P + "sldId")
rids = [e.get(NS_REL + "id") for e in sldids]
sids = [e.get("id") for e in sldids]
pres_ids = rels_ids.get("ppt/_rels/presentation.xml.rels", [])
report("sldIdLst整合（枚数・r:id解決・id/r:id重複なし）",
       len(sldids) == nslides and all(r in pres_ids for r in rids)
       and len(set(sids)) == len(sids) and len(set(rids)) == len(rids),
       "rids=%s ids=%s" % (rids, sids))

bad_tbl = []
for i, s in enumerate(data["slides"], 1):
    if s["type"] in ("table", "comparison"):
        root = ET.fromstring(z.read("ppt/slides/slide%d.xml" % i))
        if root.find(".//" + NS_A + "tbl") is None:
            bad_tbl.append(i)
report("table/comparisonスライドにa:tblが存在", not bad_tbl, str(bad_tbl))

# 条件7突合: 入力JSONの葉テキスト値ごとの部分一致（全<a:t>連結文字列へ）。
# 対象外5つ = meta.title・meta.issue（docProps行き。issueはintegerのため文字列の葉と
# しても現れない）・speakerNotes（出力しない）・slides[].type（構造の判別子で<a:t>に
# 現れない）・slides[].sides[].tone（値そのものは日本語注記へ写像され<a:t>に現れない。
# 注記の出力は個別アサーションで固定する）
texts = []
for i in range(1, nslides + 1):
    root = ET.fromstring(z.read("ppt/slides/slide%d.xml" % i))
    texts += [t.text or "" for t in root.iter(NS_A + "t")]
concat = "\n".join(texts)
leaves = []
def walk(v, path):
    if isinstance(v, str):
        leaves.append((path, v))
    elif isinstance(v, list):
        for i, x in enumerate(v):
            walk(x, path + "[%d]" % i)
    elif isinstance(v, dict):
        for k, x in v.items():
            walk(x, path + "." + k)
walk(data, "")
def excluded(path):
    return (path in (".meta.title", ".meta.issue")
            or re.match(r"^\.slides\[\d+\]\.(type$|speakerNotes|sides\[\d+\]\.tone$)", path) is not None)
not_found = []
for path, v in leaves:
    if excluded(path):
        continue
    v = v.replace("\r", "").replace("\x1f", " ")
    for line in [l for l in v.split("\n") if l]:
        if line not in concat:
            not_found.append(path + ": " + line)
report("条件7: 対象の葉テキスト全てが<a:t>へ現れる", not not_found, "; ".join(not_found[:5]))

def norm(s):
    return s.replace("\r", "").replace("\x1f", " ").replace("\n", " ")
core = ET.fromstring(z.read("docProps/core.xml"))
DC = "{http://purl.org/dc/elements/1.1/}"
CP = "{http://schemas.openxmlformats.org/package/2006/metadata/core-properties}"
# meta.issue はスキーマ確定で integer になったため str() を通す（.replace は文字列専用）
report("core.xml: dc:title=meta.title / cp:keywords=meta.issue",
       core.find(DC + "title").text == norm(data["meta"]["title"])
       and (core.find(CP + "keywords").text or "") == norm(str(data["meta"].get("issue", ""))),
       repr(core.find(DC + "title").text))

app = ET.fromstring(z.read("docProps/app.xml"))
EP = "{http://schemas.openxmlformats.org/officeDocument/2006/extended-properties}"
report("app.xml: Slides枚数", app.find(EP + "Slides").text == str(nslides))

print("VERIFY_RESULT ok=%d fail=%d" % (ok, fail))
sys.exit(1 if fail else 0)
EOF

# 経路間突合: エントリ集合の一致＋両方とも先頭が[Content_Types].xml＋ディレクトリエントリ0件
cat > "$T/compare_routes.py" <<'EOF'
import sys, zipfile
a, b = zipfile.ZipFile(sys.argv[1]), zipfile.ZipFile(sys.argv[2])
na, nb = a.namelist(), b.namelist()
problems = []
if set(na) != set(nb):
    problems.append("entry sets differ: only-a=%s only-b=%s" % (set(na) - set(nb), set(nb) - set(na)))
for label, n in (("a", na), ("b", nb)):
    if n[0] != "[Content_Types].xml":
        problems.append(label + " first entry: " + n[0])
    if any(x.endswith("/") for x in n):
        problems.append(label + " has directory entries")
if problems:
    print("; ".join(problems))
    sys.exit(1)
print("ROUTES_MATCH")
EOF

# ---------------------------------------------------------------------------
# 正常系: zip経路（この環境の既定）で生成し、機械検証一式にかける
# ---------------------------------------------------------------------------
zip_pptx="$T/out-zip.pptx"
rc=0
out="$(bash "$target" "$T/sample.slides.json" "$zip_pptx" 2>&1)" || rc=$?
assert_eq "正常系: 生成が成功する(rc=0)" "0" "$rc"
assert_contains "正常系: 枚数と経路の表示" "$out" "スライド9枚"
if [ -f "$zip_pptx" ]; then exists=1; else exists=0; fi
assert_eq "正常系: 出力ファイルが存在する" "1" "$exists"

rc=0
unzip -t -qq "$zip_pptx" >/dev/null 2>&1 || rc=$?
assert_eq "正常系: unzip -t が通る" "0" "$rc"

rc=0
vout="$(python3 "$T/verify_pptx.py" "$zip_pptx" "$T/sample.slides.json" 2>&1)" || rc=$?
assert_eq "正常系: 機械検証一式(verify_pptx.py)が全て通る" "0" "$rc"
assert_contains "正常系: 機械検証が完走している" "$vout" "VERIFY_RESULT ok="
if [ "$rc" -ne 0 ]; then printf '%s\n' "$vout"; fi

# ---------------------------------------------------------------------------
# 個別アサーション: 条件7の突合から漏れる写像を固定する
# （tone は対象外リスト入り・cover 省略側の meta フォールバックは対象外の meta.title を使う）
# ---------------------------------------------------------------------------
mapped="$(python3 - "$zip_pptx" <<'EOF'
import re, sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
def texts(n):
    return re.findall(r"<a:t>([^<]*)</a:t>", z.read("ppt/slides/slide%d.xml" % n).decode("utf-8"))
all_texts = "\n".join(t for n in range(1, 10) for t in texts(n))
print("TONE_PRO" if "案A（採用寄り）" in all_texts else "NO_TONE_PRO")
print("TONE_CON" if "案B（却下寄り）" in all_texts else "NO_TONE_CON")
print("TONE_NEU" if "案C（中立）" in all_texts else "NO_TONE_NEU")
s1 = "\n".join(texts(1))
print("COVER_META_TITLE" if "発表資料 <Q3>" in s1 else "NO_COVER_META_TITLE")
print("COVER_META_SUB" if "サブタイトル 'テスト'" in s1 else "NO_COVER_META_SUB")
s2 = "\n".join(texts(2))
print("COVER_OWN" if ("pptx書き出し機能の紹介" in s2 and "表紙の自前サブタイトル" in s2
                      and "サブタイトル 'テスト'" not in s2) else "NO_COVER_OWN")
EOF
)"
assert_contains "tone注記: pro→（採用寄り）が現れる" "$mapped" "TONE_PRO"
assert_contains "tone注記: con→（却下寄り）が現れる" "$mapped" "TONE_CON"
assert_contains "tone注記: neutral→（中立）が現れる" "$mapped" "TONE_NEU"
assert_contains "cover省略側: meta.titleが見出しへ現れる" "$mapped" "COVER_META_TITLE"
assert_contains "cover省略側: meta.subtitleがサブタイトルへ現れる" "$mapped" "COVER_META_SUB"
assert_contains "cover自前側: 自前title/subtitleが優先されmeta.subtitleは出ない" "$mapped" "COVER_OWN"

# 個別アサーション: 条件7突合をすり抜ける4つの写像（連結・位置・太字）を固定する
# （AR-4-20。条件7は<a:t>連結文字列への部分一致しか見ないため、diagramのlabelが
# 別々の段落に出ても・chapterが見出しの下に出ても・COLH/takeawayが太字でなくても
# 検出できない）
mapped2="$(python3 - "$zip_pptx" <<'EOF'
import re, sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
def raw(n):
    return z.read("ppt/slides/slide%d.xml" % n).decode("utf-8")
# slide8=diagram: labelを「 → 」で連結した1つの段落として出ているか（別々の段落へ
# 分割されていると、各labelは条件7を通るがこの1文字列としては現れない）
print("DIAGRAM_CHAIN" if "入力JSON &#8594; 生成 &#8594; 検証" in raw(8)
      or "入力JSON → 生成 → 検証" in raw(8) else "NO_DIAGRAM_CHAIN")
# slide3=section: Chapter図形（第1章）がSection Title図形（背景 & 目的）より前に出るか
s3 = raw(3)
chap_pos = s3.find('name="Chapter"')
title_pos = s3.find('name="Section Title"')
print("CHAP_BEFORE_TITLE" if -1 < chap_pos < title_pos else "NO_CHAP_BEFORE_TITLE")
# slide5=two-column: heading（現状/あるべき姿）を含む段落が太字（b="1"）か
s5 = raw(5)
paras = re.findall(r"<a:p>.*?</a:p>", s5)
def bold_para_for(text):
    for p in paras:
        if ("<a:t>%s</a:t>" % text) in p:
            return 'b="1"' in p
    return False
print("COLH_BOLD" if bold_para_for("現状") and bold_para_for("あるべき姿") else "NO_COLH_BOLD")
# slide9=summary: takeawayを含む段落が太字（b="1"）か
s9 = raw(9)
paras9 = re.findall(r"<a:p>.*?</a:p>", s9)
def bold9(text):
    for p in paras9:
        if ("<a:t>%s</a:t>" % text) in p:
            return 'b="1"' in p
    return False
print("TAKEAWAY_BOLD" if bold9("構成案JSONがそのままPowerPointになる") else "NO_TAKEAWAY_BOLD")
EOF
)"
assert_contains "diagram: labelが「 → 」連結の1段落として現れる" "$mapped2" "DIAGRAM_CHAIN"
assert_contains "section: Chapter段落がSection Title図形より前に出る" "$mapped2" "CHAP_BEFORE_TITLE"
assert_contains "two-column: heading段落が太字(b=1)である" "$mapped2" "COLH_BOLD"
assert_contains "summary: takeaway段落が太字(b=1)である" "$mapped2" "TAKEAWAY_BOLD"

# ---------------------------------------------------------------------------
# PATH制限用の合成bin（テスト対象が必要とする外部コマンドだけを実体へリンクする）
# ---------------------------------------------------------------------------
mkbin() { # $1=作成先dir 残り=リンクするコマンド名
  local dir="$1" c p
  mkdir -p "$dir"
  for c in "${@:2}"; do
    p="$(command -v "$c")"
    ln -s "$p" "$dir/$c"
  done
}
mkstub() { # $1=dir $2=コマンド名（呼ばれたら必ず失敗するスタブ）
  mkdir -p "$1"
  printf '#!/bin/sh\nexit 1\n' > "$1/$2"
  chmod +x "$1/$2"
}
# bash も含める: `PATH=... bash "$target"` の形は、一時代入のPATHが bash 自体の
# コマンド探索にも使われるため、含めないと 127 (command not found) になる
base_bin="$T/bin-base"
mkbin "$base_bin" jq cp mkdir mv date rm mktemp bash

# ---------------------------------------------------------------------------
# 経路: zipをPATHから隠すとpython経路（python3）で成功する
# ---------------------------------------------------------------------------
py_bin="$T/bin-py"
mkbin "$py_bin" python3
py_pptx="$T/out-py.pptx"
rc=0
out="$(PATH="$py_bin:$base_bin" bash "$target" "$T/sample.slides.json" "$py_pptx" 2>&1)" || rc=$?
assert_eq "python経路: zip不在でも生成が成功する(rc=0)" "0" "$rc"
assert_contains "python経路: 経路表示がpython(python3)" "$out" "経路=python(python3)"

rc=0
vout="$(python3 "$T/verify_pptx.py" "$py_pptx" "$T/sample.slides.json" 2>&1)" || rc=$?
assert_eq "python経路: 機械検証一式が全て通る" "0" "$rc"
if [ "$rc" -ne 0 ]; then printf '%s\n' "$vout"; fi

rc=0
cout="$(python3 "$T/compare_routes.py" "$zip_pptx" "$py_pptx" 2>&1)" || rc=$?
assert_eq "経路間突合: 集合一致＋先頭固定＋ディレクトリエントリ0件" "0" "$rc"
if [ "$rc" -ne 0 ]; then printf '%s\n' "$cout"; fi

# ---------------------------------------------------------------------------
# 経路: 「zipはあるが失敗する」スタブでpython経路へフォールバックする
# ---------------------------------------------------------------------------
zipfail_bin="$T/bin-zipfail"
mkstub "$zipfail_bin" zip
mkbin "$zipfail_bin" python3
rc=0
out="$(PATH="$zipfail_bin:$base_bin" bash "$target" "$T/sample.slides.json" "$T/out-fallback.pptx" 2>&1)" || rc=$?
assert_eq "zip失敗フォールバック: rc=0" "0" "$rc"
assert_contains "zip失敗フォールバック: python経路で成功する" "$out" "経路=python(python3)"

# ---------------------------------------------------------------------------
# 経路: 「存在するが実行できないpython3」スタブで候補送り（python3→python）が働く
# （能力ベース検出が存在確認と違う挙動をする、という採用理由そのものの検証）
# ---------------------------------------------------------------------------
fwd_bin="$T/bin-forward"
mkstub "$fwd_bin" python3
ln -s "$(command -v python3)" "$fwd_bin/python"
rc=0
out="$(PATH="$fwd_bin:$base_bin" bash "$target" "$T/sample.slides.json" "$T/out-forward.pptx" 2>&1)" || rc=$?
assert_eq "候補送り: 実行できないpython3を飛ばしてpythonで成功する(rc=0)" "0" "$rc"
assert_contains "候補送り: 経路表示がpython(python)" "$out" "経路=python(python)"

# ---------------------------------------------------------------------------
# 経路: 全候補（python3/python/py）が実行できない場合は明示エラー
# ---------------------------------------------------------------------------
allfail_bin="$T/bin-allfail"
mkstub "$allfail_bin" python3
mkstub "$allfail_bin" python
mkstub "$allfail_bin" py
rc=0
out="$(PATH="$allfail_bin:$base_bin" bash "$target" "$T/sample.slides.json" "$T/never1.pptx" 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then nz=1; else nz=0; fi
assert_eq "全候補失敗: 非0終了" "1" "$nz"
assert_contains "全候補失敗: 明示エラー" "$out" "zip梱包に使える経路がありません"

# ---------------------------------------------------------------------------
# 経路: zip・python両不在の明示エラー＋出力・一時ディレクトリを残さない（TMPDIR制御）
# ---------------------------------------------------------------------------
watch="$T/tmpwatch"
mkdir -p "$watch"
rc=0
out="$(TMPDIR="$watch" PATH="$base_bin" bash "$target" "$T/sample.slides.json" "$T/never2.pptx" 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then nz=1; else nz=0; fi
assert_eq "両経路不在: 非0終了" "1" "$nz"
assert_contains "両経路不在: 明示エラー" "$out" "zip梱包に使える経路がありません"
if [ -e "$T/never2.pptx" ]; then left=1; else left=0; fi
assert_eq "両経路不在: 出力ファイルを残さない" "0" "$left"
leftovers="$(find "$watch" -mindepth 1 | wc -l | tr -d ' ')"
assert_eq "両経路不在: 一時ディレクトリを残さない" "0" "$leftovers"

# ---------------------------------------------------------------------------
# 異常系（入力・出力先起因）
# ---------------------------------------------------------------------------
expect_error() { # $1=テスト名 $2=入力パス $3=出力に含むべき文字列 [$4=出力パス]
  local rc=0 out
  out="$(bash "$target" "$2" "${4:-$T/e.pptx}" 2>&1)" || rc=$?
  local nz=0
  if [ "$rc" -ne 0 ]; then nz=1; fi
  assert_eq "$1: 非0終了" "1" "$nz"
  assert_contains "$1: 明示エラー" "$out" "$3"
}

printf '{ broken' > "$T/broken.json"
rc=0
out="$(bash "$target" "$T/broken.json" "$T/e.pptx" 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then nz=1; else nz=0; fi
assert_eq "不正JSON: 非0終了" "1" "$nz"
assert_contains "不正JSON: 明示エラー" "$out" "入力がJSONとして不正です"
assert_contains "不正JSON: エラーへ入力パスを含む" "$out" "$T/broken.json"

printf '%s\n' '{"meta":{"title":"t"},"slides":[{"type":"pie","title":"x"}]}' > "$T/badtype.json"
expect_error "type不正" "$T/badtype.json" "8種enum"

printf '%s\n' '{"meta":{"title":"t"},"slides":[{"type":"bullets","items":["a"]}]}' > "$T/notitle.json"
expect_error "スライドtitle欠落" "$T/notitle.json" "slides[0].title"

printf '%s\n' '{"meta":{},"slides":[{"type":"section","title":"x"}]}' > "$T/nometa.json"
expect_error "meta.title欠落" "$T/nometa.json" "meta.title"

printf '%s\n' '{"meta":{"title":"t"},"slides":[]}' > "$T/empty.json"
expect_error "空slides" "$T/empty.json" "slides（配列・1件以上・必須）"

expect_error "入力ファイル無し" "$T/nofile.json" "入力ファイルがありません"

printf '%s\n' '{"meta":{"title":"t"},"slides":[{"type":"section","title":"x"}]}' > "$T/mini.json"
mkdir -p "$T/outdir"
expect_error "出力先がディレクトリ" "$T/mini.json" "出力先がディレクトリです" "$T/outdir"
expect_error "出力先の親ディレクトリ不在" "$T/mini.json" "出力先の親ディレクトリがありません" "$T/nodir/x.pptx"

# 入力検証エラー時も出力ファイルを残さない
if [ -e "$T/e.pptx" ]; then left=1; else left=0; fi
assert_eq "異常系: 出力ファイルを残さない" "0" "$left"

# ---------------------------------------------------------------------------
# 異常系（要素の型・境界値。jq側の検証で明示エラーになること。語彙は確定スキーマ準拠）
# ---------------------------------------------------------------------------
printf '%s\n' '{"meta":{"title":"t"},"slides":[{"type":"table","title":"x","columns":[],"rows":[["a"]]}]}' > "$T/emptycol.json"
expect_error "空columns(table)" "$T/emptycol.json" "columns（配列・1件以上・必須）"

printf '%s\n' '{"meta":{"title":"t"},"slides":[{"type":"table","title":"x","columns":["a"],"rows":["notarray"]}]}' > "$T/badrow.json"
expect_error "rows要素が配列でない" "$T/badrow.json" "rows[0] が配列ではありません"

printf '%s\n' '{"meta":{"title":"t"},"slides":[{"type":"comparison","title":"x","sides":[{"name":"a","points":["p"]}]}]}' > "$T/oneside.json"
expect_error "sidesが1件" "$T/oneside.json" "sides（配列・2〜3件・必須）"

printf '%s\n' '{"meta":{"title":"t"},"slides":[{"type":"comparison","title":"x","sides":[{"name":"a"},{"name":"b","points":["p"]}]}]}' > "$T/badside.json"
expect_error "sides要素にpointsが無い" "$T/badside.json" "sides[0] は name（文字列）と points（配列・1件以上）"

printf '%s\n' '{"meta":{"title":"t"},"slides":[{"type":"diagram","title":"x","nodes":[{"label":"a"}]}]}' > "$T/onenode.json"
expect_error "nodesが1件" "$T/onenode.json" "nodes（配列・2件以上・必須）"

printf '%s\n' '{"meta":{"title":"t"},"slides":[{"type":"diagram","title":"x","nodes":["a",{"label":"b"}]}]}' > "$T/badnode.json"
expect_error "nodes要素がオブジェクトでない" "$T/badnode.json" "nodes[0] は label（文字列）を持つオブジェクト"

printf '%s\n' '{"meta":{"title":"t"},"slides":[{"type":"two-column","title":"x","columns":[{"heading":"h","items":["i"]}]}]}' > "$T/onecol.json"
expect_error "two-columnのcolumnsが1件" "$T/onecol.json" "columns（配列・ちょうど2件・必須）"

printf '%s\n' '{"meta":{"title":"t"},"slides":[{"type":"two-column","title":"x","columns":[{"heading":"h"},{"heading":"h2","items":["i"]}]}]}' > "$T/badcol.json"
expect_error "columns要素にitemsが無い" "$T/badcol.json" "columns[0] は heading（文字列）と items（配列・1件以上）"

printf '%s\n' '{"meta":{"title":"t"},"slides":[{"type":"bullets","title":"x","items":["a",{"text":"入れ子"}]}]}' > "$T/nesteditem.json"
expect_error "items要素が文字列でない（入れ子は受け付けない）" "$T/nesteditem.json" "items[1] が文字列ではありません"

printf '%s\n' '{"meta":{"title":"t"},"slides":[{"type":"cover","title":123}]}' > "$T/covertitle.json"
expect_error "coverのtitleが文字列でない" "$T/covertitle.json" "title が文字列ではありません"

# トップレベルが非オブジェクトのJSONは、jqがエラー終了する前に明示エラーで弾く（AR-4-13）
printf '[1,2]' > "$T/toparray.json"
expect_error "トップレベルが配列" "$T/toparray.json" "入力のトップレベルがオブジェクトではありません"
printf '"str"' > "$T/topstring.json"
expect_error "トップレベルが文字列" "$T/topstring.json" "入力のトップレベルがオブジェクトではありません"
printf '123' > "$T/topnumber.json"
expect_error "トップレベルが数値" "$T/topnumber.json" "入力のトップレベルがオブジェクトではありません"

# 要素型の検証漏れ（AR-4-15）: two-column/table/comparison/diagramでも
# 非文字列の要素をJSON表現のまま出力せず、bullets/summaryと同じ明示エラーで弾く
printf '%s\n' '{"meta":{"title":"t"},"slides":[{"type":"two-column","title":"x","columns":[{"heading":"h","items":[{"k":1}]},{"heading":"h2","items":["i"]}]}]}' > "$T/colitemtype.json"
expect_error "two-columnのitems要素が文字列でない" "$T/colitemtype.json" "columns[0].items[0] が文字列ではありません"
printf '%s\n' '{"meta":{"title":"t"},"slides":[{"type":"table","title":"x","columns":["h1"],"rows":[[{"k":1}]]}]}' > "$T/cellnonstring.json"
expect_error "tableのセルが文字列でない" "$T/cellnonstring.json" "rows[0][0] が文字列ではありません"
printf '%s\n' '{"meta":{"title":"t"},"slides":[{"type":"comparison","title":"x","sides":[{"name":"A","points":[1]},{"name":"B","points":["b"]}]}]}' > "$T/pointtype.json"
expect_error "comparisonのpoints要素が文字列でない" "$T/pointtype.json" "sides[0].points[0] が文字列ではありません"
printf '%s\n' '{"meta":{"title":"t"},"slides":[{"type":"diagram","title":"x","nodes":[{"label":"a","note":1},{"label":"b"}]}]}' > "$T/notetype.json"
expect_error "diagramのnoteが文字列でない" "$T/notetype.json" "nodes[0].note が文字列ではありません"

# titleの空文字列はスキーマ上 {"type":"string"} に適合するため拒否しない（AR-4-14）
printf '%s\n' '{"meta":{"title":"t"},"slides":[{"type":"bullets","title":"","items":["a"]}]}' > "$T/emptytitle.json"
rc=0
out="$(bash "$target" "$T/emptytitle.json" "$T/emptytitle.pptx" 2>&1)" || rc=$?
assert_eq "空文字列titleは拒否されない: rc=0" "0" "$rc"

# 全セルが空文字列の表は、1列1行として正しく生成される（columnsが1件以上あれば
# 列数は1以上であり「列数を決定できない」異常系ではない。AR-4-18修正前は末尾セルが
# 空だと read -a が区切り1つ分を落として列数を1つ少なく数え、このケースが偶然
# セル数0と誤判定されエラーになっていた。「表の列数を決定できません」ガード自体は
# 防御的に残すが、columns（配列・1件以上・必須）検証を通過した入力からは
# 到達しなくなった）
printf '%s\n' '{"meta":{"title":"t"},"slides":[{"type":"table","title":"x","columns":[""],"rows":[[""]]}]}' > "$T/allempty.json"
rc=0
out="$(bash "$target" "$T/allempty.json" "$T/allempty.pptx" 2>&1)" || rc=$?
assert_eq "全セル空文字列の表: rc=0" "0" "$rc"
allempty_info="$(python3 - "$T/allempty.pptx" <<'EOF'
import sys, zipfile
import xml.etree.ElementTree as ET
z = zipfile.ZipFile(sys.argv[1])
root = ET.fromstring(z.read("ppt/slides/slide1.xml"))
ns = "{http://schemas.openxmlformats.org/drawingml/2006/main}"
grid = root.findall(".//" + ns + "tblGrid/" + ns + "gridCol")
rows = root.findall(".//" + ns + "tr")
print("cols=%d rows=%s" % (len(grid), [len(r.findall(ns + "tc")) for r in rows]))
EOF
)"
assert_contains "全セル空文字列の表: 列数は1" "$allempty_info" "cols=1"
assert_contains "全セル空文字列の表: 2行（ヘッダ+データ）とも1セル" "$allempty_info" "rows=[1, 1]"

# 末尾セルが空文字列の行は、他行より多いセル数（末尾の空セルを含む）で正しく数えられる
# （AR-4-18の再現ケース。columns=1件だがrowsの末尾セルが空なので列数は3のはず）
printf '%s\n' '{"meta":{"title":"t"},"slides":[{"type":"table","title":"x","columns":["h1"],"rows":[["a","b",""]]}]}' > "$T/trailingempty.json"
rc=0
out="$(bash "$target" "$T/trailingempty.json" "$T/trailingempty.pptx" 2>&1)" || rc=$?
assert_eq "末尾セルが空文字列の表: rc=0" "0" "$rc"
trailing_info="$(python3 - "$T/trailingempty.pptx" <<'EOF'
import sys, zipfile
import xml.etree.ElementTree as ET
z = zipfile.ZipFile(sys.argv[1])
root = ET.fromstring(z.read("ppt/slides/slide1.xml"))
ns = "{http://schemas.openxmlformats.org/drawingml/2006/main}"
grid = root.findall(".//" + ns + "tblGrid/" + ns + "gridCol")
rows = root.findall(".//" + ns + "tr")
print("cols=%d rows=%s" % (len(grid), [len(r.findall(ns + "tc")) for r in rows]))
EOF
)"
assert_contains "末尾セルが空文字列の表: 列数は3（末尾の空セルを含む）" "$trailing_info" "cols=3"
assert_contains "末尾セルが空文字列の表: 全行が3セルへパディングされる" "$trailing_info" "rows=[3, 3]"

# ---------------------------------------------------------------------------
# jqが途中で失敗した場合: 非0終了・明示エラー・出力を残さない
# （構文検査(empty)だけ実jqへ委譲し、変換ではレコードを途中まで吐いて失敗するstub jq）
# ---------------------------------------------------------------------------
jqfail_bin="$T/bin-jqfail"
mkdir -p "$jqfail_bin"
real_jq="$(command -v jq)"
printf '#!/bin/sh\nif [ "$1" = "empty" ]; then exec %s "$@"; fi\nprintf "SLIDE\\0371\\037section\\nTITLE\\037x\\n"\nexit 1\n' "$real_jq" > "$jqfail_bin/jq"
chmod +x "$jqfail_bin/jq"
rc=0
out="$(PATH="$jqfail_bin:$base_bin" bash "$target" "$T/mini.json" "$T/never3.pptx" 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then nz=1; else nz=0; fi
assert_eq "jq途中失敗: 非0終了（内容の欠けた成功にしない）" "1" "$nz"
assert_contains "jq途中失敗: 明示エラー" "$out" "入力の変換に失敗しました"
if [ -e "$T/never3.pptx" ]; then left=1; else left=0; fi
assert_eq "jq途中失敗: 出力ファイルを残さない" "0" "$left"

# ---------------------------------------------------------------------------
# 制御文字入りの入力: 空白へ置換して生成を継続し、全XMLパーツはwell-formedのまま
# ---------------------------------------------------------------------------
python3 - "$T/ctrl.json" <<'EOF'
import json, sys
open(sys.argv[1], "w", encoding="utf-8").write(json.dumps(
    {"meta": {"title": "t"}, "slides": [
        {"type": "bullets", "title": "x", "items": ["a" + chr(1) + "b"]}]}))
EOF
rc=0
out="$(bash "$target" "$T/ctrl.json" "$T/ctrl.pptx" 2>&1)" || rc=$?
assert_eq "制御文字入力: rc=0（空白へ置換して生成継続）" "0" "$rc"
ctrl_text="$(python3 - "$T/ctrl.pptx" <<'EOF'
import sys, zipfile
import xml.etree.ElementTree as ET
z = zipfile.ZipFile(sys.argv[1])
for n in z.namelist():
    if n.endswith(".xml") or n.endswith(".rels"):
        ET.fromstring(z.read(n))
root = ET.fromstring(z.read("ppt/slides/slide1.xml"))
ns = "{http://schemas.openxmlformats.org/drawingml/2006/main}"
print("|".join(t.text or "" for t in root.iter(ns + "t")))
EOF
)"
assert_contains "制御文字入力: 0x01は空白へ置換されXMLはwell-formed" "$ctrl_text" "a b"

# ---------------------------------------------------------------------------
# 不揃いな表: 列数は全行の最大・不足セルは空埋め・超過セルは捨てない
# ---------------------------------------------------------------------------
printf '%s\n' '{"meta":{"title":"t"},"slides":[{"type":"table","title":"x","columns":["h1"],"rows":[["c1","超過セル"],[]]}]}' > "$T/ragged.json"
rc=0
out="$(bash "$target" "$T/ragged.json" "$T/ragged.pptx" 2>&1)" || rc=$?
assert_eq "不揃いな表: rc=0" "0" "$rc"
ragged_info="$(python3 - "$T/ragged.pptx" <<'EOF'
import sys, zipfile
import xml.etree.ElementTree as ET
z = zipfile.ZipFile(sys.argv[1])
root = ET.fromstring(z.read("ppt/slides/slide1.xml"))
ns = "{http://schemas.openxmlformats.org/drawingml/2006/main}"
grid = root.findall(".//" + ns + "tblGrid/" + ns + "gridCol")
rows = root.findall(".//" + ns + "tr")
texts = "|".join(t.text or "" for t in root.iter(ns + "t"))
print("cols=%d rows=%s texts=%s" % (len(grid), [len(r.findall(ns + "tc")) for r in rows], texts))
EOF
)"
assert_contains "不揃いな表: 列数は全行の最大（2列）" "$ragged_info" "cols=2"
assert_contains "不揃いな表: 全行が同じセル数へパディングされる" "$ragged_info" "rows=[2, 2, 2]"
assert_contains "不揃いな表: 超過セルが捨てられない" "$ragged_info" "超過セル"

# ---------------------------------------------------------------------------
# speakerNotes入り入力: 標準エラーへ件数付き警告を出し、処理は成功する（rc=0）
# ---------------------------------------------------------------------------
printf '%s\n' '{"meta":{"title":"t"},"slides":[{"type":"section","title":"x","speakerNotes":"メモ"},{"type":"summary","title":"y","items":["a"],"speakerNotes":"メモ2"}]}' > "$T/notes.json"
rc=0
nerr="$(bash "$target" "$T/notes.json" "$T/notes.pptx" 2>&1 >/dev/null)" || rc=$?
assert_eq "speakerNotes: 終了コードは0のまま" "0" "$rc"
assert_contains "speakerNotes: 件数付き警告が標準エラーへ出る" "$nerr" "speakerNotes 付きスライドが 2 件"
if [ -f "$T/notes.pptx" ]; then exists=1; else exists=0; fi
assert_eq "speakerNotes: 生成自体は行われる" "1" "$exists"

# ---------------------------------------------------------------------------
# 改行・特殊文字入りmeta.titleがcore.xmlのdc:titleへ1行へ潰れて入る
# （HDRレコードが値内改行で行分割されないことの検証）
# ---------------------------------------------------------------------------
cat > "$T/nl.json" <<'EOF'
{"meta": {"title": "一行目\n二行目 & <特殊>"}, "slides": [{"type": "section", "title": "章"}]}
EOF
rc=0
out="$(bash "$target" "$T/nl.json" "$T/nl.pptx" 2>&1)" || rc=$?
assert_eq "改行入りmeta.title: 生成が成功する" "0" "$rc"
core_title="$(python3 - "$T/nl.pptx" <<'EOF'
import sys, zipfile
import xml.etree.ElementTree as ET
z = zipfile.ZipFile(sys.argv[1])
root = ET.fromstring(z.read("docProps/core.xml"))
print(root.find("{http://purl.org/dc/elements/1.1/}title").text)
EOF
)"
assert_eq "改行入りmeta.title: dc:titleが1行＋エスケープ経由で復元される" \
  "一行目 二行目 & <特殊>" "$core_title"

echo "passed=$passed failures=$failures"
if [ "$failures" -gt 0 ]; then exit 1; fi
