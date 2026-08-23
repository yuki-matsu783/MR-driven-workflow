#!/usr/bin/env bash
# install-to-project.sh の結合テスト（issue #33 → issue #26 でmanifest方式へ作り直し）。
#
# 2つの系統を持つ。
#   A. issue #33 から**引き継いだ表明**（受け入れ条件には現れないが落としてはいけない挙動）
#      - PR/MRテンプレート・.claude/VERSION が配布先へ配置される
#      - PR/MRテンプレートの見出しが `describe` サブコマンドの生成物と一致する
#      - .gitattributes は丸ごと置き換えず「行追記」で反映される（.bak を作らない）
#      - 末尾に改行が無くても連結しない
#      - 何度適用しても追記行が増えない（**配布先がCRLFの場合も含む**）
#      - コメント中の言及を実設定と誤認しない
#      - .claude/VERSION の更新が .bak と警告を生まない
#   B. issue #26 の受け入れ条件2〜6
#
# 実プロセスを起動する結合確認のため、`passed=N failures=N` を出力し失敗があれば終了コード1を
# 返す規約に従う（.claude/rules/shell-script-style.md「テスト」）。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SKILL_SCRIPTS="${REPO_ROOT}/.claude/skills/apply-mr-workflow-to-project/scripts"

passed=0
failures=0

# **配布先ではこのテストだけが存在し、テスト対象が存在しない**（apply-mr-workflow-to-project は
# layer=exclude で配布対象外の一方、.claude/scripts/test/ は core として丸ごと配布されるため）。
# 対象が無い環境では、規約どおり件数を出したうえでスキップする
# （無言でスキップすると、本当の欠落を隠してしまう）。
if [ ! -f "${SKILL_SCRIPTS}/install-to-project.sh" ]; then
  echo "skipped: ${SKILL_SCRIPTS}/install-to-project.sh が無いためスキップします" \
       "（apply-mr-workflow-to-project スキルは配布対象外のため、配布先ではこの状態が正常です）"
  echo "passed=0 failures=0"
  exit 0
fi

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    passed=$((passed + 1))
  else
    failures=$((failures + 1))
    printf 'FAIL: %s\n  expected: %s\n  actual  : %s\n' "$label" "$expected" "$actual" >&2
  fi
}

exists() { [ -e "$1" ] && echo 1 || echo 0; }

TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

make_dest() {
  local dir="$TMP_DIR/$1"
  mkdir -p "$dir"
  git -C "$dir" init -q .
  printf '%s' "$dir"
}

# **すべての適用呼び出しに --allow-dirty を付ける。** このテストが走るのは機構自身を開発して
# いる最中であり、本家のワークツリーはほぼ常に dirty だからである。dirty ガードそのものを
# 確かめるケースだけ、付けずに終了コードを見る（下記 B-6）。
install_to() {
  bash "${SKILL_SCRIPTS}/install-to-project.sh" --allow-dirty "$@" >/dev/null
}

# =========================================================================
# A. issue #33 から引き継いだ表明
# =========================================================================

dest_new="$(make_dest dest_new)"
install_to "$dest_new"

for rel in .github/pull_request_template.md .gitlab/merge_request_templates/Default.md \
           .claude/VERSION .gitattributes; do
  assert_eq "新規配布先へ配置される: $rel" "1" "$(exists "$dest_new/$rel")"
done

assert_eq "配布先のVERSIONが本家と一致する" \
  "$(cat "${REPO_ROOT}/.claude/VERSION")" "$(cat "$dest_new/.claude/VERSION")"

# PR/MRテンプレートの見出しは、`describe` サブコマンドが生成するdescriptionと一致していること。
# **2つのテンプレート同士を比べるだけでは足りない**（両方が同時にずれた場合に通ってしまう）。
# 正である SKILL.md の `describe` 節から見出しを抜き出し、3者で突き合わせる。
describe_headings() {
  awk '
    /^### `describe`/ { in_section = 1; next }
    /^### /           { in_section = 0 }
    in_section && /^[[:space:]]*(Closes|## )/ {
      sub(/^[[:space:]]+/, "", $0); print
    }
  ' "${REPO_ROOT}/.claude/skills/issue-mr-flow/SKILL.md"
}
expected_headings="$(describe_headings)"

# 期待値そのものが空になっていないか（SKILL.mdの節名が変わると抽出が空振りし、
# 「空同士の一致」で常に通るテストになる）。
assert_eq "describeの見出しを3行抽出できている" "3" "$(printf '%s\n' "$expected_headings" | grep -c .)"

for rel in .github/pull_request_template.md .gitlab/merge_request_templates/Default.md; do
  assert_eq "describeの生成物と見出しが一致する: $rel" \
    "$expected_headings" "$(grep -E '^(Closes|## )' "$dest_new/$rel")"
done

assert_eq "配布先の.gitattributesへ*.shの指定が入る" \
  "1" "$(grep -cFx -- '*.sh text eol=lf' "$dest_new/.gitattributes")"
assert_eq "本家だけの方針である* text=autoは配らない" \
  "0" "$(grep -cFx -- '* text=auto' "$dest_new/.gitattributes" || true)"
assert_eq "マーカー行自体は配らない" \
  "0" "$(grep -cF -- 'dist:begin' "$dest_new/.gitattributes" || true)"
assert_eq "本家のコメント（issue番号等）は配らない" \
  "0" "$(grep -cF -- 'issue #33' "$dest_new/.gitattributes" || true)"

# --- 既存の .gitattributes を持つ配布先 ---
# 末尾に改行が無い状態を意図的に作る（追記行が直前の行と連結しないことの確認）。
dest_exist="$(make_dest dest_exist)"
printf '%s\n%s\n%s' '# 配布先が元から持っている設定' '*.png binary' '*.md text eol=lf diff=markdown' \
  > "$dest_exist/.gitattributes"
install_to "$dest_exist"

assert_eq "配布先の既存3行がすべて残る" \
  "3" "$(grep -cE -- '^(# 配布先が元から|\*\.png binary|\*\.md text)' "$dest_exist/.gitattributes")"
assert_eq "末尾に改行が無くても直前の行と連結しない" \
  "1" "$(grep -cFx -- '*.md text eol=lf diff=markdown' "$dest_exist/.gitattributes")"
assert_eq "全文置換ではないので.bakを作らない" \
  "0" "$(exists "$dest_exist/.gitattributes.bak")"

# --- 冪等性 ---
install_to "$dest_exist"
install_to "$dest_exist"
assert_eq "3回適用しても*.shの指定は1行のまま" \
  "1" "$(grep -cFx -- '*.sh text eol=lf' "$dest_exist/.gitattributes")"
assert_eq "3回適用してもヘッダコメントは1行のまま" \
  "1" "$(grep -cFx -- '# mr-driven-develop workflow attributes' "$dest_exist/.gitattributes")"

# --- 配布先の .gitattributes がCRLFの場合の冪等性 ---
# Git for Windowsの既定（core.autocrlf=true）では配布先の .gitattributes が作業ツリーで
# CRLFになる。CRを落とさずに行全体の一致で判定すると「まだ無い」と誤判定し、適用のたびに
# 同じ行が追記され続ける。
#
# **初回だけCRLFにしても再現しない。** 追記した行はLFのまま残るので、2回目は素直に一致して
# しまう。実際に起きるのは「コミット→チェックアウトのたびにファイル全体がCRLFへ戻る」形なので、
# 適用のたびに全体をCRLFへ正規化して、その状況を作る。
to_crlf() {
  local file="$1" tmp="$1.crlf"
  sed -e 's/\r$//' -e 's/$/\r/' "${file}" > "${tmp}"
  mv "${tmp}" "${file}"
}

dest_crlf="$(make_dest dest_crlf)"
printf '%s\r\n%s\r\n' '# 配布先が元から持っている設定' '*.png binary' > "$dest_crlf/.gitattributes"
install_to "$dest_crlf"; to_crlf "$dest_crlf/.gitattributes"
install_to "$dest_crlf"; to_crlf "$dest_crlf/.gitattributes"
install_to "$dest_crlf"; to_crlf "$dest_crlf/.gitattributes"
assert_eq "CRLFの配布先でも*.shの指定は1行のまま" \
  "1" "$(tr -d '\r' < "$dest_crlf/.gitattributes" | grep -cFx -- '*.sh text eol=lf')"
assert_eq "CRLFの配布先でもヘッダコメントは1行のまま" \
  "1" "$(tr -d '\r' < "$dest_crlf/.gitattributes" | grep -cFx -- '# mr-driven-develop workflow attributes')"

# --- コメントで言及しているだけの配布先 ---
# 部分一致で判定していると「もう有る」と誤判定し、必要な指定が入らないまま無言で終わる。
dest_comment="$(make_dest dest_comment)"
printf '%s\n' '# *.sh text eol=lf を入れるか検討中' > "$dest_comment/.gitattributes"
install_to "$dest_comment"
assert_eq "コメント中の言及を実設定と誤認しない" \
  "1" "$(grep -cFx -- '*.sh text eol=lf' "$dest_comment/.gitattributes")"

# 同じ検査を .gitignore にも行う（新方式で .gitignore も lines-marker になったため）。
dest_ign="$(make_dest dest_ign)"
printf '%s\n' '# /usage/ を無視するか検討中' > "$dest_ign/.gitignore"
install_to "$dest_ign"
assert_eq ".gitignore でもコメント中の言及を実設定と誤認しない" \
  "1" "$(grep -cFx -- '/usage/' "$dest_ign/.gitignore")"
install_to "$dest_ign"; install_to "$dest_ign"
assert_eq ".gitignore も3回適用して行が増えない" \
  "1" "$(grep -cFx -- '/usage/' "$dest_ign/.gitignore")"
assert_eq ".gitignore にも由来のヘッダコメントが1行だけ入る" \
  "1" "$(grep -cFx -- '# mr-driven-develop workflow ignores' "$dest_ign/.gitignore")"
assert_eq "配布先の好みである.vscode/は配らない" \
  "0" "$(grep -cFx -- '.vscode/' "$dest_ign/.gitignore" || true)"

# --- .claude/VERSION の更新は .bak も警告も生まない ---
# VERSIONは配布元が所有する値であり「配布先のカスタマイズ」ではない。
# 新方式では manifest の sha256 と一致するため「変更なし」に分類され、警告の対象にならない。
dest_ver="$(make_dest dest_ver)"
install_to "$dest_ver"
install_output="$(bash "${SKILL_SCRIPTS}/install-to-project.sh" --allow-dirty "$dest_ver" 2>/dev/null)"
assert_eq "再適用でVERSIONは本家の値のまま" \
  "$(cat "${REPO_ROOT}/.claude/VERSION")" "$(cat "$dest_ver/.claude/VERSION")"
assert_eq "VERSIONの.bakを作らない" "0" "$(exists "$dest_ver/.claude/VERSION.bak")"
assert_eq "VERSIONについて警告を出さない" \
  "0" "$(printf '%s\n' "$install_output" | grep -cF -- '.claude/VERSION' || true)"

# =========================================================================
# B. issue #26 の受け入れ条件
# =========================================================================

# --- B-2: core/seed/merge が配置され manifest が生成される。local は1件も作らない ---
manifest="$dest_new/.claude/.asset-manifest.json"
assert_eq "B-2: manifest が生成される" "1" "$(exists "$manifest")"
assert_eq "B-2: manifest が有効なJSON" "0" \
  "$(if jq -e . "$manifest" >/dev/null 2>&1; then printf 0; else printf 1; fi)"
assert_eq "B-2: manifest に source.commit がある" "1" \
  "$(jq -r '.source.commit | length > 0' "$manifest" | grep -c true)"
assert_eq "B-2: local / exclude は manifest に書かない" "0" \
  "$(jq '[.files[] | select(.layer=="local" or .layer=="exclude")] | length' "$manifest")"

assert_eq "B-2: local の index.jsonl が作られない" "0" "$(find "$dest_new" -name index.jsonl | wc -l)"
assert_eq "B-2: local の .claude/state/ が作られない" "0" "$(exists "$dest_new/.claude/state")"
assert_eq "B-2: local の usage/ が作られない" "0" "$(exists "$dest_new/usage")"
# `.gemini/{docs,…}` は local だが**唯一の例外**として手順7が作る。ここでは列挙せず、
# 「作られること」を下の B-7 で確かめる。

# 旧実装が作っていた .gitkeep は、plans/ worklog/ が local になったため意図的に落とした。
assert_eq "B-2: plans/.gitkeep を作らない（旧挙動を意図的に落とした）" \
  "0" "$(exists "$dest_new/plans/.gitkeep")"
assert_eq "B-2: worklog/.gitkeep を作らない（同上）" \
  "0" "$(exists "$dest_new/worklog/.gitkeep")"

assert_eq "B-2: exclude の README.md は配らない" "0" "$(exists "$dest_new/README.md")"
assert_eq "B-2: exclude の apply-mr-workflow-to-project は配らない" \
  "0" "$(exists "$dest_new/.claude/skills/apply-mr-workflow-to-project")"

assert_eq "B-2: core の REVIEW-POINTS.md が4件とも配られる" "4" \
  "$(find "$dest_new" -name 'REVIEW-POINTS.md' | wc -l)"
assert_eq "B-2: core の worklog/TEMPLATE.md が配られる" "1" "$(exists "$dest_new/worklog/TEMPLATE.md")"
assert_eq "B-2: seed の REVIEW-POINTS.local.md が4件とも置かれる" "4" \
  "$(find "$dest_new" -name 'REVIEW-POINTS.local.md' | wc -l)"

# --- B-7: .gemini/ が用意される（local を触らない原則の唯一の例外） ---
assert_eq "B-7: .gemini/rules が用意される" "1" \
  "$([ -e "$dest_new/.gemini/rules" ] || [ -L "$dest_new/.gemini/rules" ] && echo 1 || echo 0)"

# --- B-3: 編集した seed は再適用で上書きされない ---
printf '%s\n' '配布先が書いた内容' > "$dest_new/HANDOFF.md"
install_to "$dest_new"
assert_eq "B-3: 編集した HANDOFF.md(seed) を上書きしない" \
  '配布先が書いた内容' "$(cat "$dest_new/HANDOFF.md")"

# --- B-4: 編集した core は「上書きの前に」警告と一覧を出し、.bak を残す ---
printf '%s\n' '配布先が勝手に変えた' >> "$dest_new/.claude/rules/git-workflow.md"
dry_out="$(bash "${SKILL_SCRIPTS}/install-to-project.sh" --allow-dirty --dry-run "$dest_new" 2>/dev/null)"
assert_eq "B-4: --dry-run が警告を出す" "1" \
  "$(printf '%s\n' "$dry_out" | grep -c '適用後に配布先で変更されています' || true)"
assert_eq "B-4: --dry-run が対象ファイル名を列挙する" "1" \
  "$(printf '%s\n' "$dry_out" | grep -cF -- '- .claude/rules/git-workflow.md' || true)"
assert_eq "B-4: --dry-run では上書きしない" \
  '配布先が勝手に変えた' "$(tail -1 "$dest_new/.claude/rules/git-workflow.md")"

install_to "$dest_new"
assert_eq "B-4: 適用すると .bak が残る" "1" \
  "$(exists "$dest_new/.claude/rules/git-workflow.md.bak")"
assert_eq "B-4: .bak に配布先の内容が入っている" \
  '配布先が勝手に変えた' "$(tail -1 "$dest_new/.claude/rules/git-workflow.md.bak")"
assert_eq "B-4: 本体は本家の内容へ戻る" \
  "$(tr -d '\r' < "${REPO_ROOT}/.claude/rules/git-workflow.md" | sha256sum | cut -d' ' -f1)" \
  "$(tr -d '\r' < "$dest_new/.claude/rules/git-workflow.md" | sha256sum | cut -d' ' -f1)"

# --force なら .bak を作らない
rm -f "$dest_new/.claude/rules/git-workflow.md.bak"
printf '%s\n' 'また変えた' >> "$dest_new/.claude/rules/git-workflow.md"
bash "${SKILL_SCRIPTS}/install-to-project.sh" --allow-dirty --force "$dest_new" >/dev/null 2>&1
assert_eq "B-4: --force では .bak を作らない" "0" \
  "$(exists "$dest_new/.claude/rules/git-workflow.md.bak")"

# --- B-5: 書き換えなければ「変更された」は0件 ---
clean_out="$(bash "${SKILL_SCRIPTS}/install-to-project.sh" --allow-dirty --dry-run "$dest_new" 2>/dev/null)"
assert_eq "B-5: 書き換えなければ警告が出ない" "0" \
  "$(printf '%s\n' "$clean_out" | grep -c '適用後に配布先で変更されています' || true)"

# --- B-6: 本家が dirty なら中断する ---
# このテストは本家のワークツリーが dirty な状態で走る前提なので、--allow-dirty を外して見る。
# 万一クリーンな状態で走った場合に「中断しないこと」を失敗と数えないよう、先に dirty か調べる。
if [ -n "$(git -C "$REPO_ROOT" status --porcelain -- .claude .github .gitlab AGENTS.md CLAUDE.md)" ]; then
  if bash "${SKILL_SCRIPTS}/install-to-project.sh" --dry-run "$dest_new" >/dev/null 2>&1; then
    dirty_status=0
  else
    dirty_status=1
  fi
  assert_eq "B-6: 本家が dirty なら中断する" "1" "$dirty_status"
else
  echo "note: 本家がクリーンなため B-6（dirty ガード）はスキップしました（1件）"
fi

# --- json-keys のマージ（配布先所有のキーが残り、本家所有が更新される） ---
dest_json="$(make_dest dest_json)"
install_to "$dest_json"
jq '.plansDirectory = "my-plans" | .permissions.deny += ["Bash(rm -rf /)"] | .myOwnKey = 1' \
  "$dest_json/.claude/settings.json" > "$dest_json/tmp.json"
mv "$dest_json/tmp.json" "$dest_json/.claude/settings.json"
install_to "$dest_json"
assert_eq "json-keys: 配布先所有の plansDirectory が残る" "my-plans" \
  "$(jq -r '.plansDirectory' "$dest_json/.claude/settings.json")"
assert_eq "json-keys: 配布先が足した独自キーが残る" "1" \
  "$(jq -r '.myOwnKey' "$dest_json/.claude/settings.json")"
assert_eq "json-keys: 配列の deny は和集合になる" "1" \
  "$(jq '[.permissions.deny[] | select(. == "Bash(rm -rf /)")] | length' "$dest_json/.claude/settings.json")"
assert_eq "json-keys: 本家の deny も残る" "1" \
  "$(jq '[.permissions.deny[] | select(. == "Bash(git commit*)")] | length' "$dest_json/.claude/settings.json")"
assert_eq "json-keys: hooks は本家の値になる" \
  "$(jq -cS '.hooks' "${REPO_ROOT}/.claude/settings.json")" \
  "$(jq -cS '.hooks' "$dest_json/.claude/settings.json")"

# --- 配布先が本家と同じ場合は中断する ---
if bash "${SKILL_SCRIPTS}/install-to-project.sh" --allow-dirty --dry-run "$REPO_ROOT" >/dev/null 2>&1; then
  self_status=0
else
  self_status=1
fi
assert_eq "配布先が本家と同じなら中断する" "1" "$self_status"

# --- gitリポジトリでない配布先は中断する ---
not_git="$TMP_DIR/not_git"
mkdir -p "$not_git"
if bash "${SKILL_SCRIPTS}/install-to-project.sh" --allow-dirty --dry-run "$not_git" >/dev/null 2>&1; then
  notgit_status=0
else
  notgit_status=1
fi
assert_eq "gitリポジトリでない配布先は中断する" "1" "$notgit_status"

# =========================================================================
# C. 敵対的レビュー（フェーズ3・2回目）の指摘に対する回帰テスト
#
# **どれも受け入れ条件1〜11には現れない挙動である。** 条件だけを見てテストを書くと
# 抜け落ちる種類のものなので、指摘ごとに1件ずつ表明を残す。
# =========================================================================

# --- C-1: --help の出力にシェルのコード行が混ざらない ----------------------
# 行番号で切り出していたため、冒頭コメントの増減で `set -euo pipefail` が出ていた。
help_out="$(bash "${SKILL_SCRIPTS}/install-to-project.sh" --help)"
assert_eq "--help にシェルのコード行が混ざらない" "0" \
  "$(printf '%s\n' "$help_out" | grep -c '^set -')"
assert_eq "--help に使い方の行は出る" "1" \
  "$(printf '%s\n' "$help_out" | grep -c 'install-to-project.sh \[オプション\]')"

# --- C-2: 配布した層分け定義から upstream の印が落ちている -----------------
# 付いたまま配ると、配布先で網羅性チェックが「本家のもの」として走り、配布先の自前ソースを
# 全件未分類として報告する（install-to-project.sh 自身も手順2cで中断する）。
assert_eq "配布した層分け定義に upstream の印が無い" "null" \
  "$(jq -r '.upstream // "null"' "$dest_new/.claude/dist-layers.json")"
assert_eq "本家の定義には upstream の印が残っている" "true" \
  "$(jq -r '.upstream' "${REPO_ROOT}/.claude/dist-layers.json")"
cov_out="$(cd "$dest_new" && bash .claude/scripts/src/check-dist-coverage.sh)"
assert_eq "配布先では網羅性チェックがスキップされる" "1" \
  "$(printf '%s\n' "$cov_out" | grep -c '^スキップ:')"

# --- C-3: 配布先をカレントディレクトリにしても適用できる -------------------
# 網羅性チェックが相対パスの定義と cwd 基準の git ls-files を見ていたため、必ず中断していた。
dest_cwd="$(make_dest dest_cwd)"
if (cd "$dest_cwd" && bash "${SKILL_SCRIPTS}/install-to-project.sh" --allow-dirty . >/dev/null 2>&1)
then cwd_status=0; else cwd_status=1; fi
assert_eq "配布先をカレントにしても適用できる" "0" "$cwd_status"
assert_eq "そのとき manifest も作られる" "1" "$(exists "$dest_cwd/.claude/.asset-manifest.json")"

# --- C-4: 壊れた配布先 settings.json でファイルを破壊しない ----------------
# jq の終了コードを見ずに書き戻していたため、0バイトへ潰したうえで成功として終了していた。
# merge 層は .bak を作らないので、これは回復不能な破壊だった。
dest_broken="$(make_dest dest_broken)"
install_to "$dest_broken"
printf '%s' '{ "hooks": ' > "$dest_broken/.claude/settings.json"
broken_before="$(wc -c < "$dest_broken/.claude/settings.json")"
if install_to "$dest_broken" 2>/dev/null; then broken_status=0; else broken_status=1; fi
assert_eq "壊れた配布先settings.jsonでは中断する" "1" "$broken_status"
assert_eq "中断してもファイルを0バイトにしない" "$broken_before" \
  "$(wc -c < "$dest_broken/.claude/settings.json")"

# --- C-5: --force のとき、判定不能の警告が .bak を約束しない ---------------
# 実際には --force では .bak を作らないのに「元の内容は .bak として残します」と出ていた。
dest_force="$(make_dest dest_force)"
install_to "$dest_force"
rm -f "$dest_force/.claude/.asset-manifest.json"   # 旧方式からの移行（判定不能）を模す
force_out="$(bash "${SKILL_SCRIPTS}/install-to-project.sh" \
  --allow-dirty --force --dry-run "$dest_force" 2>&1)"
assert_eq "判定不能の警告自体は出る" "1" \
  "$(printf '%s\n' "$force_out" | grep -c 'manifest が無いため差分を確認できません')"
assert_eq "--force のとき .bak を約束しない" "0" \
  "$(printf '%s\n' "$force_out" | grep -c '元の内容は .bak として残します')"
assert_eq "--force のとき退避されないことを明示する" "1" \
  "$(printf '%s\n' "$force_out" | grep -c '退避されずに失われます')"

# --- クリーンな本家を用意する（C-6 / C-7 で使う） --------------------------
# このリポジトリは機構自身の開発中ほぼ常に dirty なので、作業ツリーの写しから
# 1コミットだけのクリーンなリポジトリを作り、そこを本家として実行する。
# 写しは tar 1回で取る。ファイルごとに mkdir と cp を起動すると、186ファイルで
# 370回以上のforkになる（.claude/rules/shell-script-style.md「外部プロセス起動のコスト」）。
clean_up="$TMP_DIR/clean_upstream"
mkdir -p "$clean_up"
clean_list="$TMP_DIR/clean_files"
: > "$clean_list"
# **未追跡（gitignore対象でない）ファイルも含める。** 追跡ファイルだけを写すと、
# まだコミットしていない新規ファイル（雛形の追加等）がフィクスチャから抜け、
# 「配布元がありません」で落ちる。テストしたいのは作業ツリーの現在の状態である。
while IFS= read -r -d '' f; do
  # `git ls-files` はindexの内容を返すので、削除したが未ステージの追跡ファイルも含む。
  # そのまま tar へ渡すと落ちる（.claude/rules/shell-script-style.md）。
  [ -f "$REPO_ROOT/$f" ] || continue
  printf '%s\0' "$f" >> "$clean_list"
done < <(git -C "$REPO_ROOT" ls-files -z --cached --others --exclude-standard)
tar -C "$REPO_ROOT" -c --null -T "$clean_list" -f - | tar -C "$clean_up" -x -f -
git -C "$clean_up" init -q .
git -C "$clean_up" add -A
git -C "$clean_up" -c user.name=t -c user.email=t@example.com \
  -c commit.gpgsign=false commit -q -m 'fixture'
clean_installer="$clean_up/.claude/skills/apply-mr-workflow-to-project/scripts/install-to-project.sh"

# --- C-6: クリーンな本家からの配布では -dirty を付けない -------------------
# オプションの有無だけを見ていたため、--allow-dirty を常用すると常に -dirty が付き、
# 「この配布先はこのコミットで再現できるか」が判定できなくなっていた。
dest_clean="$(make_dest dest_clean)"
bash "$clean_installer" --allow-dirty "$dest_clean" >/dev/null
assert_eq "クリーンな本家なら -dirty を付けない" "0" \
  "$(jq -r '.source.commit' "$dest_clean/.claude/.asset-manifest.json" | grep -c -- '-dirty')"
assert_eq "commit はSHAとして記録される" "1" \
  "$(jq -r '.source.commit' "$dest_clean/.claude/.asset-manifest.json" | grep -cE '^[0-9a-f]{40}$')"
# 逆向きの表明: 実際に dirty なら付くこと（付かないだけの実装でも通ってしまわないように）。
printf '\n# dirty にする\n' >> "$clean_up/.gitattributes"
dest_dirty="$(make_dest dest_dirty)"
bash "$clean_installer" --allow-dirty "$dest_dirty" >/dev/null
assert_eq "実際に dirty なら -dirty を付ける" "1" \
  "$(jq -r '.source.commit' "$dest_dirty/.claude/.asset-manifest.json" | grep -c -- '-dirty')"

# --- D-1: HANDOFF.md / index.md は雛形から配られる -------------------------
# source を持たない seed だと本家の作業中の内容がそのまま配られ、seed なので二度と
# 訂正されない。**「雛形と一致する」だけでなく「本家の内容が漏れていない」も見る**
# （雛形を本家のコピーにしてしまうと前者だけでは通ってしまうため）。
# dest_new は受け入れ条件3の確認で HANDOFF.md を編集済みなので、専用の配布先を使う。
TPL="${REPO_ROOT}/.claude/skills/apply-mr-workflow-to-project/assets"
dest_seed="$(make_dest dest_seed)"
install_to "$dest_seed"
assert_eq "配布された HANDOFF.md は雛形と一致する" \
  "$(cat "${TPL}/HANDOFF.md.template")" "$(cat "$dest_seed/HANDOFF.md")"
assert_eq "配布された HANDOFF.md に本家のissue/PR番号が漏れていない" "0" \
  "$(grep -cE '^- (issue|PR): #[0-9]+' "$dest_seed/HANDOFF.md" || true)"
assert_eq "配布された HANDOFF.md の push回数は0" "1" \
  "$(grep -cFx -- '- push回数: 0' "$dest_seed/HANDOFF.md")"
assert_eq "配布された index.md は雛形と一致する" \
  "$(cat "${TPL}/index.md.template")" "$(cat "$dest_seed/index.md")"
assert_eq "配布された index.md に本家固有の記述が漏れていない" "0" \
  "$(grep -c 'そのものを配布するテンプレート' "$dest_seed/index.md" || true)"
# 本家側は雛形で上書きされていないこと（source は配布先の内容だけを決める）。
assert_eq "本家の HANDOFF.md は雛形になっていない" "1" \
  "$(grep -cE '^- issue: #[0-9]+' "${REPO_ROOT}/HANDOFF.md")"

# --- D-2: 本家から削除された core は一覧提示のみで、配布先から消さない -----
# 「一覧の提示のみ（削除は人間）」という選択の表明。提示すらしないと、
# .claude/rules/*.md は自動読込なので配布先のAIが古いルールを読み続ける。
dest_del="$(make_dest dest_del)"
bash "$clean_installer" --allow-dirty "$dest_del" >/dev/null
victim='.claude/rules/markdown-frontmatter.md'
assert_eq "前提: 1回目の適用で配られている" "1" "$(exists "$dest_del/$victim")"
# **index からも消す。** 作業ツリーだけ消すと `git ls-files` には残るため、
# 「本家から削除された」状態にならず、配置時の `cp` が失敗するだけになる。
git -C "$clean_up" rm -q -- "$victim"
del_out="$(bash "$clean_installer" --allow-dirty "$dest_del" 2>&1)"
assert_eq "削除された core をパス付きで一覧に出す" "1" \
  "$(printf '%s\n' "$del_out" | grep -cF -- "  - $victim")"
assert_eq "削除しないことを明示する" "1" \
  "$(printf '%s\n' "$del_out" | grep -c '配布先のファイルを削除しません')"
assert_eq "サマリにも件数を出す" "1" \
  "$(printf '%s\n' "$del_out" | grep -c '本家から削除・改名された core が 1 件')"
assert_eq "**配布先のファイルは消さない**" "1" "$(exists "$dest_del/$victim")"
# 逆向き: 削除が無ければ一覧も出ない（常に出る実装でも通ってしまわないように）。
dest_nodel="$(make_dest dest_nodel)"
bash "$clean_installer" --allow-dirty "$dest_nodel" >/dev/null
nodel_out="$(bash "$clean_installer" --allow-dirty "$dest_nodel" 2>&1)"
assert_eq "削除が無ければ一覧は出ない" "0" \
  "$(printf '%s\n' "$nodel_out" | grep -c '配布先のファイルを削除しません')"

# --- C-7: マーカーENDの欠落を検出して中断する ------------------------------
# BEGIN しか必須にしていなかったため、END を消すと BEGIN 以降の全行が配られていた。
# コメントは落ちるので、出力を目視しても異常だと気づけない。
sed -i '/^# --- dist:end ---$/d' "$clean_up/.gitattributes"
dest_noend="$(make_dest dest_noend)"
if bash "$clean_installer" --allow-dirty "$dest_noend" >/dev/null 2>&1
then noend_status=0; else noend_status=1; fi
assert_eq "マーカーENDが無ければ中断する" "1" "$noend_status"
assert_eq "中断したので本家固有の行を配っていない" "0" \
  "$([ -f "$dest_noend/.gitattributes" ] && grep -c 'text=auto' "$dest_noend/.gitattributes" || echo 0)"

# --- D-3: 定義から配布対象を1件も読めなければ中断する ----------------------
# `read_entries_records` はプロセス置換の中で走るため、jq が失敗しても while が0回まわる
# だけで、「core を 0 件配置しました」と成功で終わってしまっていた。
# **この確認は clean_up の定義を壊すので、他の clean_up 利用より後に置くこと。**
jq '.entries = []' "$clean_up/.claude/dist-layers.json" > "$TMP_DIR/empty_def.json"
cp "$TMP_DIR/empty_def.json" "$clean_up/.claude/dist-layers.json"
dest_empty="$(make_dest dest_empty)"
if bash "$clean_installer" --allow-dirty "$dest_empty" >/dev/null 2>&1
then empty_status=0; else empty_status=1; fi
assert_eq "定義から1件も読めなければ中断する" "1" "$empty_status"
assert_eq "中断したので manifest を作らない" "0" "$(exists "$dest_empty/.claude/.asset-manifest.json")"

echo "passed=$passed failures=$failures"
[ "$failures" -eq 0 ]
