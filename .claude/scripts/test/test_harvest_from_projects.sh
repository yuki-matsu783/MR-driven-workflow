#!/usr/bin/env bash
# harvest-from-projects.sh の単体・結合テスト（issue #27）。
# 一時ディレクトリに合成本家（git リポジトリ）と複数の合成配布先を作り、--upstream で
# 差し込んで T1〜T23 を固定する。出力規約: passed=N failures=N・失敗時終了コード1。
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../../.."
SCRIPT='.claude/skills/harvest-from-projects/scripts/harvest-from-projects.sh'

# 対象スクリプト不在ならスキップ（収穫スキルは exclude 層で配布されないため、配布先で
# このテストだけが配られた状態は正常。test_install_to_project.sh と同型のガード）
if [ ! -f "$SCRIPT" ]; then
  printf 'skipped: %s が存在しません（配布先では正常）\n' "$SCRIPT"
  printf 'passed=0 failures=0\n'
  exit 0
fi
SCRIPT="$(pwd)/$SCRIPT"

passed=0
failures=0
assert_eq() { # $1=名前 $2=期待 $3=実際
  if [ "$2" = "$3" ]; then
    passed=$((passed + 1))
  else
    failures=$((failures + 1))
    printf 'NG: %s\n  期待: %s\n  実際: %s\n' "$1" "$2" "$3"
  fi
}
assert_contains() { # $1=名前 $2=部分文字列 $3=全体
  if [[ "$3" == *"$2"* ]]; then
    passed=$((passed + 1))
  else
    failures=$((failures + 1))
    printf 'NG: %s\n  含まれるべき: %s\n  実際: %s\n' "$1" "$2" "$3"
  fi
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

git_c() { # $1=リポジトリ 以降=git引数（テスト用の身元設定込み）
  git -C "$1" -c user.name=test -c user.email=test@example.com -c commit.gpgsign=false "${@:2}"
}

sha_lf() { # $1=ファイル
  tr -d '\r' < "$1" | sha256sum | cut -d' ' -f1
}

# ---- 合成本家 --------------------------------------------------------------

UP="$WORK/upstream"
mkdir -p "$UP/.claude/rules"
cat > "$UP/.claude/dist-layers.json" <<'JSON'
{ "schemaVersion": 1, "upstream": true,
  "entries": [
    { "layer": "core", "path": ".claude" },
    { "layer": "merge", "path": ".claude/settings.json", "strategy": "json-keys", "keys": ["hooks"] },
    { "layer": "core", "path": "CLAUDE.md" },
    { "layer": "merge", "path": ".gitignore", "strategy": "lines-marker", "header": "# t" },
    { "layer": "merge", "path": ".gitattributes", "strategy": "lines-marker", "header": "# t" },
    { "layer": "local", "path": "plans" },
    { "layer": "local", "gitignorePattern": "**/index.jsonl" },
    { "layer": "local", "gitignorePattern": "/usage/" },
    { "layer": "local", "gitignorePattern": "*.stackdump" }
  ] }
JSON
printf 'L1\nL2\nL3\nL4\nL5\nL6\nL7\nL8\nL9\nL10\n' > "$UP/.claude/rules/a.md"
printf 'M1\nM2\nM3\nM4\nM5\nM6\nM7\nM8\nM9\nM10\nM11\nM12\n' > "$UP/.claude/rules/b.md"
printf 'C1\nC2\n' > "$UP/.claude/rules/c.md"
printf 'G1\nG2\n' > "$UP/.claude/rules/gone.md"
printf 'D1\nD2\n' > "$UP/.claude/rules/d.md"
printf 'K1\nK2\n' > "$UP/.claude/rules/crlf.md"
printf 'R1\nR2\n' > "$UP/.claude/rules/ren-old.md"
printf 'J1\nJ2\n' > "$UP/.claude/rules/日本語.md"
printf 'root\n' > "$UP/CLAUDE.md"
printf '{ "hooks": { "a": 1 }, "own": "up" }\n' > "$UP/.claude/settings.json"
printf 'ig1\nig2\n' > "$UP/.gitignore"
printf 'at1\nat2\n' > "$UP/.gitattributes"
git_c "$UP" init -q
git_c "$UP" add -A
git_c "$UP" commit -q -m 'chore: base'
BASE_SHA="$(git -C "$UP" rev-parse HEAD)"
# 本家HEADを進める: a.md の2行目・b.md の2行目を変更し、gone.md・日本語.md を削除、
# ren-old.md を改名する（改名は既定の改名検出で R になり D に出ないケースの再現）
sed -i 's/^L2$/L2-up/' "$UP/.claude/rules/a.md"
sed -i 's/^M2$/M2-up/' "$UP/.claude/rules/b.md"
git_c "$UP" rm -q .claude/rules/gone.md
git_c "$UP" rm -q .claude/rules/日本語.md
git_c "$UP" mv .claude/rules/ren-old.md .claude/rules/ren-new.md
git_c "$UP" add -A
git_c "$UP" commit -q -m 'chore: head'

# ---- 合成配布先の共通部品 --------------------------------------------------

# 配布時点（BASE）の内容を配布先へ写し、manifest を捏造する
make_dest() { # $1=配布先パス $2=manifestへ書く source.commit（空=manifestを作らない）
  local dest="$1" commit="$2"
  mkdir -p "$dest/.claude/rules"
  git -C "$UP" show "$BASE_SHA:.claude/rules/a.md" > "$dest/.claude/rules/a.md"
  git -C "$UP" show "$BASE_SHA:.claude/rules/b.md" > "$dest/.claude/rules/b.md"
  git -C "$UP" show "$BASE_SHA:.claude/rules/c.md" > "$dest/.claude/rules/c.md"
  git -C "$UP" show "$BASE_SHA:.claude/rules/gone.md" > "$dest/.claude/rules/gone.md"
  git -C "$UP" show "$BASE_SHA:.claude/rules/d.md" > "$dest/.claude/rules/d.md"
  git -C "$UP" show "$BASE_SHA:.claude/rules/crlf.md" > "$dest/.claude/rules/crlf.md"
  git -C "$UP" show "$BASE_SHA:CLAUDE.md" > "$dest/CLAUDE.md"
  git -C "$UP" show "$BASE_SHA:.claude/settings.json" > "$dest/.claude/settings.json"
  git -C "$UP" show "$BASE_SHA:.gitignore" > "$dest/.gitignore"
  git -C "$UP" show "$BASE_SHA:.gitattributes" > "$dest/.gitattributes"
  jq 'del(.upstream)' "$UP/.claude/dist-layers.json" > "$dest/.claude/dist-layers.json"
  [ -n "$commit" ] || return 0
  local hooks_hash lines_hash attr_hash
  hooks_hash="$(jq -c 'getpath(["hooks"])' "$dest/.claude/settings.json" | sha256sum | cut -d' ' -f1)"
  lines_hash="$(sha_lf "$dest/.gitignore")"
  attr_hash="$(sha_lf "$dest/.gitattributes")"
  jq -n --arg commit "$commit" \
    --arg a "$(sha_lf "$dest/.claude/rules/a.md")" \
    --arg b "$(sha_lf "$dest/.claude/rules/b.md")" \
    --arg c "$(sha_lf "$dest/.claude/rules/c.md")" \
    --arg gone "$(sha_lf "$dest/.claude/rules/gone.md")" \
    --arg d "$(sha_lf "$dest/.claude/rules/d.md")" \
    --arg k "$(sha_lf "$dest/.claude/rules/crlf.md")" \
    --arg root "$(sha_lf "$dest/CLAUDE.md")" \
    --arg dl "$(sha_lf "$dest/.claude/dist-layers.json")" \
    --arg hooks "$hooks_hash" --arg lines "$lines_hash" --arg attr "$attr_hash" '
    { schemaVersion: 1,
      source: { url: "", commit: $commit, version: "test" },
      appliedAt: "2026-08-23T00:00:00Z",
      files: [
        { path: ".claude/rules/a.md", layer: "core", sha256: $a },
        { path: ".claude/rules/b.md", layer: "core", sha256: $b },
        { path: ".claude/rules/c.md", layer: "core", sha256: $c },
        { path: ".claude/rules/gone.md", layer: "core", sha256: $gone },
        { path: ".claude/rules/d.md", layer: "core", sha256: $d },
        { path: ".claude/rules/crlf.md", layer: "core", sha256: $k },
        { path: "CLAUDE.md", layer: "core", sha256: $root },
        { path: ".claude/dist-layers.json", layer: "core", sha256: $dl },
        { path: ".claude/settings.json", layer: "merge", strategy: "json-keys", keys: { hooks: $hooks } },
        { path: ".gitignore", layer: "merge", strategy: "lines-marker", lines: $lines },
        { path: ".gitattributes", layer: "merge", strategy: "lines-marker", lines: $attr }
      ] }
  ' > "$dest/.claude/.asset-manifest.json"
}

# ---- 配布先A: 主経路（git あり・クリーンな記録SHA） ------------------------

A="$WORK/destA"
make_dest "$A" "$BASE_SHA"
sed -i 's/^L2$/L2-dest/' "$A/.claude/rules/a.md"      # T1/T2a: 本家と同じ行を変更
sed -i 's/^M10$/M10-dest/' "$A/.claude/rules/b.md"    # T2b: 本家（M2）から十分離れた行を変更
rm "$A/.claude/rules/d.md"                             # T4: 本家HEADに残るファイルの削除
rm "$A/.claude/rules/gone.md"                          # T4b: 本家でも削除済みファイルの削除
printf 'N1\n' > "$A/.claude/rules/new-skill.md"        # T3: 新規追加
printf 'J1\nJ2\n' > "$A/.claude/rules/日本語.md"       # T16: 本家で削除済みの日本語名（非ASCII）
printf 'R1\nR2\n' > "$A/.claude/rules/ren-old.md"      # T17: 本家で改名された旧パス
mkdir -p "$A/plans"
printf 'p\n' > "$A/plans/x.md"                         # T7a: local（path）
printf 'i\n' > "$A/.claude/index.jsonl"                # T7b: local（gitignorePattern）
printf 'b\n' > "$A/.claude/rules/x.md.bak"             # T7d: 機構の退避ファイル
sed -i 's/"own": "up"/"own": "dest"/' "$A/.claude/settings.json"  # T13: 対象外キーのみ変更
sed -i 's/$/\r/' "$A/.gitignore"                       # T12: CRLF化のみ（内容同一）
git_c "$A" init -q
git_c "$A" add -A
git_c "$A" commit -q -m 'chore: init'
printf 'L11\n' >> "$A/.claude/rules/a.md"
printf 'J3\n' >> "$A/.claude/rules/日本語.md"          # T16: 非ASCIIパスの ai-asset 集計
git_c "$A" add -A
git_c "$A" commit -q -m 'ai-asset: a.mdを改善'

# ---- 配布先B: -dirty 付き記録SHA（T8/T12/T13の modified 側） ---------------

B="$WORK/destB"
make_dest "$B" "${BASE_SHA}-dirty"
sed -i 's/^L2$/L2-destB/' "$B/.claude/rules/a.md"
printf 'ig3\n' >> "$B/.gitignore"                      # T12: lines-marker の変更
printf 'at3\n' >> "$B/.gitattributes"                  # T18: 2件目の lines-marker の変更
sed -i 's/"a": 1/"a": 2/' "$B/.claude/settings.json"   # T13: 対象キー（hooks）の変更
git_c "$B" init -q
git_c "$B" add -A
git_c "$B" commit -q -m 'chore: init'

# ---- 配布先C: 実在しない記録SHA（T8b） -------------------------------------

C="$WORK/destC"
make_dest "$C" 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef'
sed -i 's/^L2$/L2-destC/' "$C/.claude/rules/a.md"
git_c "$C" init -q
git_c "$C" add -A
git_c "$C" commit -q -m 'chore: init'

# ---- 配布先D: manifest 無し（T5 縮退） -------------------------------------

D="$WORK/destD"
make_dest "$D" ''
sed -i 's/^L3$/L3-destD/' "$D/.claude/rules/a.md"
# T5: 縮退モードでも配布先が git なら判断材料（changeCount 等）が埋まることを見るため git 化する
git_c "$D" init -q
git_c "$D" add -A
git_c "$D" commit -q -m 'chore: init'

# ---- 配布先E: git リポジトリでない（T15） ----------------------------------

E="$WORK/destE"
make_dest "$E" "$BASE_SHA"
sed -i 's/^L2$/L2-destE/' "$E/.claude/rules/a.md"
printf 'i\n' > "$E/.claude/index.jsonl"

# ---- 配布先F: 壊れた manifest（0バイト。T6 のエラー隔離） ------------------

F="$WORK/destF"
make_dest "$F" ''
: > "$F/.claude/.asset-manifest.json"

# ---- T11: 読み取り専用の表明（実行前の断面） -------------------------------

up_before="$(git -C "$UP" status --porcelain)"
a_before="$(git -C "$A" status --porcelain)"

# ---- scan 実行 -------------------------------------------------------------

scan_json="$WORK/scan.json"
bash "$SCRIPT" --upstream "$UP" scan "$A" "$B" "$F" > "$scan_json"

qa() { jq -r "$1" "$scan_json"; }

# T1: core の変更が modified として列挙される
assert_eq 'T1: a.md が modified' 'modified' \
  "$(qa '.targets[0].files[] | select(.path==".claude/rules/a.md") | .status')"

# T2a/T2b: 同一行の変更は conflict、離れた行は clean
assert_eq 'T2a: 同じ行の変更は conflict' 'conflict' \
  "$(qa '.targets[0].files[] | select(.path==".claude/rules/a.md") | .conflict')"
assert_eq 'T2b: 離れた行の変更は clean' 'clean' \
  "$(qa '.targets[0].files[] | select(.path==".claude/rules/b.md") | .conflict')"

# T3: 新規追加が added として列挙される（本家に無いパス）
assert_eq 'T3: new-skill.md が added' 'added' \
  "$(qa '.targets[0].files[] | select(.path==".claude/rules/new-skill.md") | .status')"
assert_eq 'T3: added の upstreamHasPath は false' 'false' \
  "$(qa '.targets[0].files[] | select(.path==".claude/rules/new-skill.md") | .upstreamHasPath')"

# T4: 本家HEADに在るファイルの削除は deleted、本家でも削除済みは removedUpstream の別枠
assert_eq 'T4: d.md が deleted' 'deleted' \
  "$(qa '.targets[0].files[] | select(.path==".claude/rules/d.md") | .status')"
assert_eq 'T4b: gone.md は removedUpstream' 'removedUpstream' \
  "$(qa '.targets[0].files[] | select(.path==".claude/rules/gone.md") | .status')"
assert_eq 'T4b: gone.md の upstreamDeleted は true' 'true' \
  "$(qa '.targets[0].files[] | select(.path==".claude/rules/gone.md") | .upstreamDeleted')"

# T6: 複数配布先＋壊れた1件（0バイト manifest）が隔離される
assert_eq 'T6: targets が3件返る' '3' "$(qa '.targets | length')"
assert_eq 'T6: 壊れた配布先は manifestExists=false' 'false' "$(qa '.targets[2].manifestExists')"
assert_eq 'T6: 壊れた配布先は degraded=true' 'true' "$(qa '.targets[2].degraded')"
assert_eq 'T6: 正常な配布先Bの結果も返る' 'modified' \
  "$(qa '.targets[1].files[] | select(.path==".claude/rules/a.md") | .status')"

# T7: local 相当・機構生成物は added に現れない（added は意図した3件だけ）
assert_eq 'T7: added は new-skill/ren-old/日本語 の3件のみ' \
  '.claude/rules/new-skill.md,.claude/rules/ren-old.md,.claude/rules/日本語.md' \
  "$(qa '[.targets[0].files[] | select(.status=="added") | .path] | join(",")')"

# T16: 非ASCII（日本語）ファイル名でも upstreamDeleted・判断材料が正しく突き合う
# （core.quotepath=false が無いと8進エスケープでキーが化け、全件 false / 0 になる）
assert_eq 'T16: 日本語.md の upstreamDeleted は true' 'true' \
  "$(qa '.targets[0].files[] | select(.path==".claude/rules/日本語.md") | .upstreamDeleted')"
assert_eq 'T16: 日本語.md の aiAssetCommits は1' '1' \
  "$(qa '.targets[0].files[] | select(.path==".claude/rules/日本語.md") | .aiAssetCommits')"
assert_eq 'T16: 日本語.md の changeCount は2' '2' \
  "$(qa '.targets[0].files[] | select(.path==".claude/rules/日本語.md") | .changeCount')"

# T17: 本家で改名（git mv）された旧パスも upstreamDeleted=true になる
# （既定の改名検出では R に分類され --diff-filter=D に出ない。--no-renames で拾う）
assert_eq 'T17: ren-old.md の upstreamDeleted は true' 'true' \
  "$(qa '.targets[0].files[] | select(.path==".claude/rules/ren-old.md") | .upstreamDeleted')"
assert_eq 'T17: ren-old.md の upstreamHasPath は false' 'false' \
  "$(qa '.targets[0].files[] | select(.path==".claude/rules/ren-old.md") | .upstreamHasPath')"

# T18: 2件目の lines-marker（.gitattributes）の指紋比較
assert_eq 'T18: 変更なしの .gitattributes は listed されない' '' \
  "$(qa '.targets[0].files[] | select(.path==".gitattributes") | .path')"
assert_eq 'T18: 行を足した .gitattributes は modified' 'modified' \
  "$(qa '.targets[1].files[] | select(.path==".gitattributes") | .status')"

# T8: -dirty 付きでも 3-way が動き、近似フラグが立つ
assert_eq 'T8: destB は baseResolvable=true' 'true' "$(qa '.targets[1].baseResolvable')"
assert_eq 'T8: destB は baseApproximate=true' 'true' "$(qa '.targets[1].baseApproximate')"
assert_eq 'T8: destB の a.md は conflict が算出される' 'conflict' \
  "$(qa '.targets[1].files[] | select(.path==".claude/rules/a.md") | .conflict')"

# T9: CRLF 化のみ（内容同一）の core は modified にならない
assert_eq 'T9: crlf.md は listed されない' '' \
  "$(qa '.targets[0].files[] | select(.path==".claude/rules/crlf.md") | .path')"

# T12: merge/lines-marker の指紋比較（LF正規化）
assert_eq 'T12: CRLF化のみの .gitignore は modified にならない' '' \
  "$(qa '.targets[0].files[] | select(.path==".gitignore") | .path')"
assert_eq 'T12: 行を足した .gitignore は modified' 'modified' \
  "$(qa '.targets[1].files[] | select(.path==".gitignore") | .status')"
assert_eq 'T12: merge層の conflict は unknown' 'unknown' \
  "$(qa '.targets[1].files[] | select(.path==".gitignore") | .conflict')"

# T13: merge/json-keys の指紋比較（対象キーのみ）
assert_eq 'T13: 対象外キーのみの settings.json は modified にならない' '' \
  "$(qa '.targets[0].files[] | select(.path==".claude/settings.json") | .path')"
assert_eq 'T13: hooks を変えた settings.json は modified' 'modified' \
  "$(qa '.targets[1].files[] | select(.path==".claude/settings.json") | .status')"

# 判断材料: ai-asset コミットの集計
assert_eq '判断材料: a.md の aiAssetCommits は1' '1' \
  "$(qa '.targets[0].files[] | select(.path==".claude/rules/a.md") | .aiAssetCommits')"
assert_eq '判断材料: a.md の changeCount は2' '2' \
  "$(qa '.targets[0].files[] | select(.path==".claude/rules/a.md") | .changeCount')"

# ---- T8b: 実在しない記録SHA ------------------------------------------------

scan_c="$WORK/scan_c.json"
bash "$SCRIPT" --upstream "$UP" scan "$C" > "$scan_c"
assert_eq 'T8b: baseResolvable=false' 'false' "$(jq -r '.targets[0].baseResolvable' "$scan_c")"
assert_eq 'T8b: baseApproximate=false' 'false' "$(jq -r '.targets[0].baseApproximate' "$scan_c")"
assert_eq 'T8b: conflict は unknown' 'unknown' \
  "$(jq -r '.targets[0].files[] | select(.path==".claude/rules/a.md") | .conflict' "$scan_c")"

# ---- T5: manifest 無しの縮退モード -----------------------------------------

scan_d="$WORK/scan_d.json"
bash "$SCRIPT" --upstream "$UP" scan "$D" > "$scan_d"
assert_eq 'T5: degraded=true' 'true' "$(jq -r '.targets[0].degraded' "$scan_d")"
assert_eq 'T5: a.md が differs で列挙される' 'differs' \
  "$(jq -r '.targets[0].files[] | select(.path==".claude/rules/a.md") | .status' "$scan_d")"
assert_eq 'T5: 縮退時のレコードは conflict キーを持たない' 'false' \
  "$(jq -r '.targets[0].files[] | select(.path==".claude/rules/a.md") | has("conflict")' "$scan_d")"
assert_eq 'T5: 縮退でも git 配布先なら changeCount が埋まる' '1' \
  "$(jq -r '.targets[0].files[] | select(.path==".claude/rules/a.md") | .changeCount' "$scan_d")"
assert_eq 'T5: 縮退でも git 配布先なら aiAssetCommits が埋まる' '0' \
  "$(jq -r '.targets[0].files[] | select(.path==".claude/rules/a.md") | .aiAssetCommits' "$scan_d")"

# ---- T19: エラーレコードと配布先単位の隔離 ---------------------------------

scan_err="$WORK/scan_err.json"
bash "$SCRIPT" --upstream "$UP" scan "$WORK/no-such-dest" "$B" > "$scan_err"
assert_eq 'T19: 存在しない配布先は error レコードになる' 'true' \
  "$(jq -r '.targets[0] | has("error")' "$scan_err")"
assert_eq 'T19: 隣の配布先の結果は通常どおり返る' 'false' \
  "$(jq -r '.targets[1] | has("error")' "$scan_err")"

# T19b: 縮退モードの展開（git archive | tar）が失敗したら「差分なし」ではなく error になる
STUB_BIN="$WORK/stub-bin"
mkdir -p "$STUB_BIN"
printf '#!/usr/bin/env bash\nexit 1\n' > "$STUB_BIN/tar"
chmod +x "$STUB_BIN/tar"
scan_tar="$WORK/scan_tar.json"
PATH="$STUB_BIN:$PATH" bash "$SCRIPT" --upstream "$UP" scan "$D" > "$scan_tar"
assert_eq 'T19b: tar 失敗の配布先は error レコードになる（偽の全クリアにしない）' 'true' \
  "$(jq -r '.targets[0] | has("error")' "$scan_tar")"

# ---- T20: manifest からレコードを1件も読めない場合は縮退へ倒す --------------

G="$WORK/destG"
make_dest "$G" ''
printf '{ "schemaVersion": 1, "files": [] }\n' > "$G/.claude/.asset-manifest.json"
scan_g="$WORK/scan_g.json"
bash "$SCRIPT" --upstream "$UP" scan "$G" > "$scan_g"
assert_eq 'T20: files が空の manifest は degraded=true（全件 added の誤報にしない）' 'true' \
  "$(jq -r '.targets[0].degraded' "$scan_g")"

# ---- T15: git リポジトリでない配布先 ---------------------------------------

scan_e="$WORK/scan_e.json"
bash "$SCRIPT" --upstream "$UP" scan "$E" > "$scan_e"
assert_eq 'T15: scan が完走し modified が出る' 'modified' \
  "$(jq -r '.targets[0].files[] | select(.path==".claude/rules/a.md") | .status' "$scan_e")"
assert_eq 'T15: aiAssetCommits は null' 'null' \
  "$(jq -r '.targets[0].files[] | select(.path==".claude/rules/a.md") | .aiAssetCommits' "$scan_e")"
assert_eq 'T15: changeCount は null' 'null' \
  "$(jq -r '.targets[0].files[] | select(.path==".claude/rules/a.md") | .changeCount' "$scan_e")"
assert_eq 'T15: 非gitでも gitignorePattern の除外が効く' '' \
  "$(jq -r '.targets[0].files[] | select(.path==".claude/index.jsonl") | .path' "$scan_e")"

# ---- T14: merge3 の終了コード正規化 ----------------------------------------

m_out="$WORK/m_out" m_err="$WORK/m_err"
rc=0
bash "$SCRIPT" --upstream "$UP" merge3 "$A" .claude/rules/b.md > "$m_out" 2> "$m_err" || rc=$?
assert_eq 'T14: 衝突しない差分は exit 0' '0' "$rc"
assert_contains 'T14: マージ結果に両方の変更が入る' 'M2-up' "$(cat "$m_out")"
assert_contains 'T14: マージ結果に配布先の変更が入る' 'M10-dest' "$(cat "$m_out")"

rc=0
bash "$SCRIPT" --upstream "$UP" merge3 "$A" .claude/rules/a.md > "$m_out" 2> "$m_err" || rc=$?
assert_eq 'T14: 同一行の差分は exit 1' '1' "$rc"
assert_contains 'T14: 衝突マーカーが出る' '<<<<<<<' "$(cat "$m_out")"

rc=0
bash "$SCRIPT" --upstream "$UP" merge3 "$A" .gitignore > "$m_out" 2> "$m_err" || rc=$?
assert_eq 'T14: merge 層の指定は exit 4' '4' "$rc"

rc=0
bash "$SCRIPT" --upstream "$UP" merge3 "$A" .claude/dist-layers.json > "$m_out" 2> "$m_err" || rc=$?
assert_eq 'T14: dist-layers.json の指定は exit 4' '4' "$rc"

rc=0
bash "$SCRIPT" --upstream "$UP" merge3 "$A" .gitattributes > "$m_out" 2> "$m_err" || rc=$?
assert_eq 'T14: manifest の layer=merge レコードでも exit 4（第一情報源）' '4' "$rc"

# T21: 層を判定できない配布先（manifest も dist-layers.json も無い）はフェイルクローズで exit 3
H="$WORK/destH"
mkdir -p "$H/.claude/rules"
git -C "$UP" show "$BASE_SHA:.claude/rules/a.md" > "$H/.claude/rules/a.md"
rc=0
bash "$SCRIPT" --upstream "$UP" merge3 "$H" .claude/rules/a.md > "$m_out" 2> "$m_err" || rc=$?
assert_eq 'T21: 層を判定できないときは exit 3（無言で 3-way しない）' '3' "$rc"
assert_contains 'T21: stderr に理由が出る' '層を判定できません' "$(cat "$m_err")"

# T21b: manifest は読めるが当該パスの記録が無く、dist-layers.json も無い場合も exit 3
# （敵対的レビュー6回目の指摘: 以前は層未確定のまま 3-way が走り exit 0 を返していた）
printf '{"schemaVersion":1,"source":{"commit":"%s"},"files":[{"path":"other.md","layer":"core"}]}\n' \
  "$BASE_SHA" > "$H/.claude/.asset-manifest.json"
rc=0
bash "$SCRIPT" --upstream "$UP" merge3 "$H" .claude/rules/a.md > "$m_out" 2> "$m_err" || rc=$?
assert_eq 'T21b: manifest 未記録＋dist-layers 無しでも exit 3（層未確定で 3-way しない）' '3' "$rc"
assert_contains 'T21b: stderr に理由が出る' '層を判定できません' "$(cat "$m_err")"
rm -f "$H/.claude/.asset-manifest.json"

rc=0
bash "$SCRIPT" --upstream "$UP" merge3 "$A" .claude/rules/nope.md > "$m_out" 2> "$m_err" || rc=$?
assert_eq 'T14: 存在しない相対パスは exit 3' '3' "$rc"

rc=0
bash "$SCRIPT" --upstream "$UP" merge3 "$C" .claude/rules/a.md > "$m_out" 2> "$m_err" || rc=$?
assert_eq 'T8b: 未到達SHAの merge3 は exit 2（縮退）' '2' "$rc"
assert_contains 'T8b: stderr に理由が出る' 'base 取得不可' "$(cat "$m_err")"

rc=0
bash "$SCRIPT" --upstream "$UP" merge3 "$B" .claude/rules/a.md > "$m_out" 2> "$m_err" || rc=$?
assert_eq 'T8: -dirty でも merge3 が動く（衝突で exit 1）' '1' "$rc"
assert_contains 'T8: stderr に近似の注意が出る' '近似' "$(cat "$m_err")"

# ---- diff ------------------------------------------------------------------

diff_out="$(bash "$SCRIPT" --upstream "$UP" diff "$A" .claude/rules/a.md)"
assert_contains 'diff: 配布先側の変更が見える' '+L2-dest' "$diff_out"

# ---- T10: 純粋関数の単体（source して直接呼ぶ） ----------------------------

# shellcheck disable=SC1090
source "$SCRIPT"

strip_dirty_to_reply 'abc123-dirty'
assert_eq 'T10: -dirty 除去' 'abc123' "$REPLY"
assert_eq 'T10: -dirty フラグ' '1' "$REPLY_WAS_DIRTY"
strip_dirty_to_reply 'abc123'
assert_eq 'T10: -dirty 無しはそのまま' 'abc123' "$REPLY"
assert_eq 'T10: -dirty 無しのフラグ' '0' "$REPLY_WAS_DIRTY"

LAYER_ENTRY_PATHS=('.claude' '.claude/skills/x' 'CLAUDE.md')
LAYER_ENTRY_LAYERS=('core' 'exclude' 'core')
resolve_layer_to_reply '.claude/rules/y.md'
assert_eq 'T10: ディレクトリ前方一致で core' 'core' "$REPLY"
resolve_layer_to_reply '.claude/skills/x/SKILL.md'
assert_eq 'T10: 後勝ちで exclude' 'exclude' "$REPLY"
resolve_layer_to_reply 'CLAUDE.md'
assert_eq 'T10: 完全一致' 'core' "$REPLY"
resolve_layer_to_reply 'CLAUDE.md.bak'
assert_eq 'T10: 前方一致は/区切りのみ（部分文字列不一致）' '' "$REPLY"

if gitignore_matches '**/index.jsonl' '.claude/docs/index.jsonl'; then r=0; else r=1; fi
assert_eq 'T10: **/index.jsonl が任意階層で一致' '0' "$r"
if gitignore_matches '/usage/' 'usage/state/x.json'; then r=0; else r=1; fi
assert_eq 'T10: /usage/ がアンカー付きディレクトリで一致' '0' "$r"
if gitignore_matches '/usage/' 'src/usage/x.json'; then r=0; else r=1; fi
assert_eq 'T10: /usage/ はルート以外に一致しない' '1' "$r"
if gitignore_matches '*.stackdump' '.claude/bash.exe.stackdump'; then r=0; else r=1; fi
assert_eq 'T10: *.stackdump が任意階層で一致' '0' "$r"
if gitignore_matches '/.claude/settings.local.json' '.claude/settings.local.json'; then r=0; else r=1; fi
assert_eq 'T10: アンカー付きファイルパスが一致' '0' "$r"
if gitignore_matches '.vscode/' '.vscode/settings.json'; then r=0; else r=1; fi
assert_eq 'T10: ディレクトリパターンが配下に一致' '0' "$r"
if gitignore_matches '.vscode/' 'x/.vscode'; then r=0; else r=1; fi
assert_eq 'T10: ディレクトリパターンはファイル名に一致しない' '1' "$r"

if is_harvest_infra_path '.claude/.asset-manifest.json'; then r=0; else r=1; fi
assert_eq 'T10: manifest 自身は機構パス' '0' "$r"
if is_harvest_infra_path '.claude/rules/x.md.bak'; then r=0; else r=1; fi
assert_eq 'T10: .bak は機構パス' '0' "$r"
if is_harvest_infra_path '.claude/rules/x.md'; then r=0; else r=1; fi
assert_eq 'T10: 通常ファイルは機構パスではない' '1' "$r"

# T22: merge の指紋比較は未知 strategy・keys 空を「変更あり」側へ倒す（フェイルオープン防止）
if merge_fingerprint_unchanged "$UP/.gitignore" 'unknown-strategy' '' '{}'; then r=0; else r=1; fi
assert_eq 'T22: 未知 strategy は変更あり側へ倒れる' '1' "$r"
if merge_fingerprint_unchanged "$UP/.gitignore" '' '' '{}'; then r=0; else r=1; fi
assert_eq 'T22: strategy 欠落は変更あり側へ倒れる' '1' "$r"
if merge_fingerprint_unchanged "$UP/.claude/settings.json" 'json-keys' '' '{}'; then r=0; else r=1; fi
assert_eq 'T22: keys 空の json-keys は変更あり側へ倒れる' '1' "$r"

# T23: usage に3サブコマンドすべての書式が出る（行範囲固定のずれで欠けない）
usage_out="$(bash "$SCRIPT" --help)"
assert_contains 'T23: usage に scan が出る' ' scan ' "$usage_out"
assert_contains 'T23: usage に diff が出る' ' diff ' "$usage_out"
assert_contains 'T23: usage に merge3 が出る' ' merge3 ' "$usage_out"

# ---- T11: 読み取り専用の表明（実行後の断面と比較） -------------------------

assert_eq 'T11: 合成本家のワークツリーが不変' "$up_before" "$(git -C "$UP" status --porcelain)"
assert_eq 'T11: 合成配布先Aのワークツリーが不変' "$a_before" "$(git -C "$A" status --porcelain)"

printf 'passed=%s failures=%s\n' "$passed" "$failures"
[ "$failures" -eq 0 ]
