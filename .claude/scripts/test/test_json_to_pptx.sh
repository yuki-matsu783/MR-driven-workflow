#!/usr/bin/env bash
# .claude/skills/pptx-slides/scripts/json-to-pptx.sh の単体テスト（issue #169）。
#
# 対象:
# - 純粋関数: xml_escape_to_reply（5種の特殊文字・日本語・&の一回置換）、
#   resolve_out_path_to_reply（出力パスの既定値導出）。source して直接呼ぶ
#   （main guard により副作用なく関数定義のみが読み込まれる）。
# - 正常系: 8種type全部入りサンプルから .pptx を生成し、機械検証一式
#   （zip整合性・先頭エントリ・ディレクトリエントリ0・全XML well-formed・必須パーツ・
#   Content_Types突合・rels整合・rId重複0・sldIdLst整合・table/comparisonのa:tbl存在・
#   条件7の葉テキスト突合・core.xml/app.xmlのプロパティ）を verify_pptx.py（テスト内で
#   生成するpython検証スクリプト）で検査する。
# - 経路: zip経路とpython経路（`zip` をPATHから隠す）の両方で生成し、経路間突合
#   （エントリ集合の一致＋先頭が [Content_Types].xml＋ディレクトリエントリ0件。
#   順序全体は比較しない——`zip -r` の格納順はFS走査順に依存するため）を行う。
#   さらに「`zip` はあるが失敗する」スタブでのフォールバック、「存在するが実行できない
#   `python3`」スタブでの候補送り（python3→python）、全候補失敗時・全経路不在時の
#   明示エラー、失敗時に出力ファイル・一時ディレクトリを残さないこと（TMPDIR制御）を検査する。
# - 異常系: 不正JSON／type不正／title・meta.title欠落／空slides／入力ファイル無し／
#   出力先がディレクトリ／親ディレクトリ不在。speakerNotes入り入力の警告（rc=0のまま）。
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
# サンプル入力（8種type全部入り・特殊文字・値内改行・入れ子bullets）
# 注意: diagramのnodesにはidとlabelを併記しない（labelが優先されidは<a:t>へ
# 現れないため、葉テキスト突合の対象から外れる形になる。突合を素通りさせない）
# ---------------------------------------------------------------------------
cat > "$T/sample.slides.json" <<'EOF'
{
  "meta": {
    "title": "発表資料 <Q3> & \"計画\"",
    "subtitle": "サブタイトル 'テスト'",
    "date": "2026-08-24",
    "author": "山田 & 太郎",
    "issue": "#169"
  },
  "slides": [
    {"type": "cover", "title": "pptx書き出し機能の紹介"},
    {"type": "section", "title": "第1章 背景 & 目的"},
    {"type": "bullets", "title": "要点一覧", "items": [
      "特殊文字 <&> \" ' を含む項目",
      "二行にわたる\n項目テキスト",
      {"text": "入れ子の親", "items": ["入れ子の子1", "入れ子の子2"]}
    ]},
    {"type": "two-column", "title": "比較の前提",
     "left": ["左カラム1行目", "左カラム2行目"], "right": "右カラムは文字列"},
    {"type": "table", "title": "実測値の表",
     "headers": ["項目", "値"],
     "rows": [["経路zip", "0.9秒"], ["経路python", "1.2秒"]]},
    {"type": "comparison", "title": "代替案の比較", "options": [
      {"name": "案A", "pros": ["速い", "単純"], "cons": "依存が増える", "verdict": "採用"},
      {"name": "案B", "pros": "移植性が高い", "cons": ["遅い"], "verdict": "却下"}
    ]},
    {"type": "diagram", "title": "処理の流れ",
     "nodes": [{"label": "入力JSON"}, {"label": "生成"}, "検証"],
     "edges": [{"from": "入力JSON", "to": "生成", "label": "jq"},
               {"from": "生成", "to": "検証"}],
     "caption": "全体像の図"},
    {"type": "summary", "title": "まとめ", "items": ["編集可能なpptxを生成できる"]}
  ]
}
EOF

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
# 対象外 = meta.title・meta.issue（docProps行き）・speakerNotes（出力しない）・
# slides[].type（構造の判別子で<a:t>に現れない）
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
            or re.match(r"^\.slides\[\d+\]\.(type$|speakerNotes)", path) is not None)
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
report("core.xml: dc:title=meta.title / cp:keywords=meta.issue",
       core.find(DC + "title").text == norm(data["meta"]["title"])
       and (core.find(CP + "keywords").text or "") == norm(data["meta"].get("issue", "")),
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
assert_contains "正常系: 枚数と経路の表示" "$out" "スライド8枚"
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
# 異常系（要素の型・境界値。jq側の検証で明示エラーになること）
# ---------------------------------------------------------------------------
printf '%s\n' '{"meta":{"title":"t"},"slides":[{"type":"table","title":"x","headers":[],"rows":[]}]}' > "$T/emptyhdr.json"
expect_error "空headers" "$T/emptyhdr.json" "headers が空です"

printf '%s\n' '{"meta":{"title":"t"},"slides":[{"type":"comparison","title":"x","options":[]}]}' > "$T/emptyopt.json"
expect_error "空options" "$T/emptyopt.json" "options が空です"

printf '%s\n' '{"meta":{"title":"t"},"slides":[{"type":"table","title":"x","headers":["a"],"rows":["notarray"]}]}' > "$T/badrow.json"
expect_error "rows要素が配列でない" "$T/badrow.json" "rows[0] が配列ではありません"

printf '%s\n' '{"meta":{"title":"t"},"slides":[{"type":"comparison","title":"x","options":["案A"]}]}' > "$T/badopt.json"
expect_error "options要素がオブジェクトでない" "$T/badopt.json" "options[0] がオブジェクトではありません"

printf '%s\n' '{"meta":{"title":"t"},"slides":[{"type":"diagram","title":"x","nodes":["a"],"edges":["notobj"]}]}' > "$T/badedge.json"
expect_error "edges要素がオブジェクトでない" "$T/badedge.json" "edges[0] がオブジェクトではありません"

# 全セルが空の表は、素のbashエラー（ゼロ除算）ではなく明示エラーで止まる
printf '%s\n' '{"meta":{"title":"t"},"slides":[{"type":"table","title":"x","headers":[""],"rows":[[""]]}]}' > "$T/allempty.json"
expect_error "全セル空の表" "$T/allempty.json" "表の列数を決定できません"

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
printf '%s\n' '{"meta":{"title":"t"},"slides":[{"type":"table","title":"x","headers":["h1"],"rows":[["c1","超過セル"],[]]}]}' > "$T/ragged.json"
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
