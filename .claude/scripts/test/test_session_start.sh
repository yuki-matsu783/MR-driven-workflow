#!/usr/bin/env bash
# .claude/hooks/session-start.sh の単体テスト（issue #57で新設）。
# gh/git・ネットワークを伴わない純粋関数（context_text_bytes / append_size_warning /
# extract_handoff_next_steps / issue_mr_flow_branch_reason / format_skill_reload_instruction）と、
# 「sourceしても本体が実行されない」ことを検証する。
# 規約: passed=N failures=N を標準出力へ出し、失敗があれば終了コード1
#       （.claude/rules/shell-script-style.md「テスト」。.claude/scripts/test/test_update_handoff_progress.sh を雛形にした）。
# 実行: bash .claude/scripts/test/test_session_start.sh
set -euo pipefail

script_dir="${BASH_SOURCE[0]%/*}"
[[ "$script_dir" == "${BASH_SOURCE[0]}" ]] && script_dir="."
repo_root="$(cd "$script_dir/../../.." && pwd)"

# source した時点で本体（stdin読み取り・コンテキスト注入）が走らないことが前提。
# 走ってしまう場合、ここでstdin待ちのままハングするか、JSONが標準出力へ漏れる。
# shellcheck source=../../../.claude/hooks/session-start.sh
source "$repo_root/.claude/hooks/session-start.sh"

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

assert_not_contains() {
  local name="$1" haystack="$2" needle="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    passed=$((passed + 1))
  else
    failures=$((failures + 1))
    echo "FAIL: $name"
    echo "  expected NOT to contain: $needle"
    echo "  actual                : $haystack"
  fi
}

assert_success() {
  local name="$1" status="$2"
  if [[ "$status" -eq 0 ]]; then
    passed=$((passed + 1))
  else
    failures=$((failures + 1))
    echo "FAIL: $name (expected success, got exit code $status)"
  fi
}

assert_failure() {
  local name="$1" status="$2"
  if [[ "$status" -ne 0 ]]; then
    passed=$((passed + 1))
  else
    failures=$((failures + 1))
    echo "FAIL: $name (expected failure, got exit code 0)"
  fi
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

# 警告文に必ず含まれる特徴的な語（警告の有無の判定に使う）
WARNING_MARKER='しきい値'

# --- source時に本体が実行されない ------------------------------------------

# ここまで到達している時点で「sourceしてもstdin待ちにならない」ことは確認できている。
# 関数として定義されていることを明示的に確認する。
assert_eq "sourceしてもmainは実行されず関数として定義されるだけ" \
  "function" "$(type -t main)"
assert_eq "build_contextが関数として定義される" \
  "function" "$(type -t build_context)"

# --- context_text_bytes: 文字数ではなくバイト数を返す ------------------------

assert_eq "ASCIIのみは文字数と一致する" "5" "$(context_text_bytes 'abcde')"
assert_eq "空文字列は0バイト" "0" "$(context_text_bytes '')"
# 「あいう」は3文字だがUTF-8では9バイト。文字数で数えていればここで3が返り失敗する。
assert_eq "日本語はバイト数で数える（文字数ではない）" "9" "$(context_text_bytes 'あいう')"
# $'...' で書く（コマンド置換は末尾の改行を落とすため、末尾改行の検証に使えない）
assert_eq "改行もバイト数に含まれる" "4" "$(context_text_bytes $'a\nb\n')"

# --- append_size_warning: しきい値以下では追記されない ------------------------

short_text='短い注入テキスト'
result="$(append_size_warning "$short_text" 8000)"
assert_eq "しきい値以下なら入力がそのまま返る" "$short_text" "$result"
assert_not_contains "しきい値以下なら警告文が追記されない" "$result" "$WARNING_MARKER"

# 境界値: ちょうどしきい値ぴったり（-le 判定のため追記されない）
exact_text="$(printf 'a%.0s' $(seq 1 100))"
assert_eq "境界値テキストは100バイト" "100" "$(context_text_bytes "$exact_text")"
result="$(append_size_warning "$exact_text" 100)"
assert_eq "しきい値ちょうどなら追記されない（境界値）" "$exact_text" "$result"

# --- append_size_warning: しきい値超過で警告文が末尾へ追記される --------------

long_text="$(printf 'a%.0s' $(seq 1 101))"
result="$(append_size_warning "$long_text" 100)"
assert_contains "しきい値超過なら警告文が追記される" "$result" "$WARNING_MARKER"
assert_contains "超過時も元テキストは保持される（切り詰めない）" "$result" "$long_text"
assert_eq "超過時は元テキストが先頭にある" "$long_text" "${result:0:${#long_text}}"
assert_contains "警告文に実測バイト数が含まれる" "$result" "101 バイト"
assert_contains "警告文にしきい値が含まれる" "$result" "100 バイト"
assert_contains "警告文が整理対象のファイルを名指しする" "$result" "HANDOFF.md"

# 日本語で構成されたテキストも、文字数ではなくバイト数で判定される
# （30文字=90バイト。しきい値80なら「文字数判定なら超えない／バイト判定なら超える」）
ja_text="$(printf 'あ%.0s' $(seq 1 30))"
assert_eq "日本語テキストは90バイト" "90" "$(context_text_bytes "$ja_text")"
result="$(append_size_warning "$ja_text" 80)"
assert_contains "日本語テキストもバイト数で超過判定される" "$result" "$WARNING_MARKER"

# 第2引数を省略した場合は既定値 CONTEXT_SIZE_WARN_BYTES が使われる
saved_limit="$CONTEXT_SIZE_WARN_BYTES"
CONTEXT_SIZE_WARN_BYTES=10
result="$(append_size_warning 'abcdefghijk')"
assert_contains "引数省略時は既定値のしきい値が使われる（超過側）" "$result" "$WARNING_MARKER"
CONTEXT_SIZE_WARN_BYTES=8000
result="$(append_size_warning 'abcdefghijk')"
assert_not_contains "引数省略時は既定値のしきい値が使われる（非超過側）" "$result" "$WARNING_MARKER"
CONTEXT_SIZE_WARN_BYTES="$saved_limit"

# --- extract_handoff_next_steps: 「次にやること」節のみを抜き出す --------------

write_handoff_fixture() {
  cat >"$1" <<'FIXTURE'
# HANDOFF

## フロー進捗状況

| 進捗 | flow-id |
|----|---|
| [x] | 1-1 |

## やったこと

- これは抜き出されてはいけない

## 次にやること

- 個別作業計画のレビュー
- 設計反映

## 判断を迷った内容

- これも抜き出されてはいけない
FIXTURE
}

fixture="$TMP_DIR/handoff.md"
write_handoff_fixture "$fixture"
section="$(extract_handoff_next_steps "$fixture")"
assert_contains "見出し行を含めて抜き出す" "$section" "## 次にやること"
assert_contains "節の中身が含まれる" "$section" "- 個別作業計画のレビュー"
assert_contains "節の中身が最後まで含まれる" "$section" "- 設計反映"
assert_not_contains "前の節（やったこと）は混ざらない" "$section" "## やったこと"
assert_not_contains "前の節の中身は混ざらない" "$section" "これは抜き出されてはいけない"
assert_not_contains "次の節（判断を迷った内容）は混ざらない" "$section" "## 判断を迷った内容"
assert_not_contains "次の節の中身は混ざらない" "$section" "これも抜き出されてはいけない"
assert_not_contains "フロー進捗状況の表は混ざらない" "$section" "flow-id"

# 最終節（後続の ## が無い）でも末尾まで抜き出せる
fixture="$TMP_DIR/handoff_last.md"
cat >"$fixture" <<'FIXTURE'
## やったこと

- 済み

## 次にやること

- 最終行まで読むこと
FIXTURE
section="$(extract_handoff_next_steps "$fixture")"
assert_contains "最終節でも中身を抜き出せる" "$section" "- 最終行まで読むこと"
assert_not_contains "最終節でも前の節は混ざらない" "$section" "## やったこと"

# 「次にやること」節が無いファイル
fixture="$TMP_DIR/handoff_none.md"
cat >"$fixture" <<'FIXTURE'
## やったこと

- 済み
FIXTURE
if extract_handoff_next_steps "$fixture" >/dev/null 2>&1; then
  status=0
else
  status=1
fi
assert_failure "節が無いファイルでは失敗を返す" "$status"

# 見出しだけで中身が空の場合も「無い」とみなす
fixture="$TMP_DIR/handoff_empty.md"
cat >"$fixture" <<'FIXTURE'
## 次にやること

## 判断を迷った内容

- あり
FIXTURE
if extract_handoff_next_steps "$fixture" >/dev/null 2>&1; then
  status=0
else
  status=1
fi
assert_failure "見出しだけで中身が空なら失敗を返す" "$status"

# 存在しないファイル
if extract_handoff_next_steps "$TMP_DIR/not_exist.md" >/dev/null 2>&1; then
  status=0
else
  status=1
fi
assert_failure "存在しないファイルでは失敗を返す" "$status"

# 実物の HANDOFF.md でも抜き出せる（合成フィクスチャのみで完了としない。
# .claude/rules/shell-script-style.md「テスト」の実データ確認）
if [ -f "$repo_root/HANDOFF.md" ]; then
  if section="$(extract_handoff_next_steps "$repo_root/HANDOFF.md")"; then
    status=0
  else
    status=1
  fi
  assert_success "実物のHANDOFF.mdから抜き出せる" "$status"
  assert_eq "実物からの抜粋は見出し行で始まる" \
    "## 次にやること" "$(printf '%s' "$section" | head -1)"
fi

# --- issue_mr_flow_branch_reason: issue-mr-flow対象ブランチの判定 --------------

# 判定材料が両方とも無い＝issue-mr-flowに乗せていないブランチ（軽微な変更を直接進めている等）。
# ここで「対象」と判定されると、対象外ブランチへ不要な指示が注入されることになる（issue #113の
# 受け入れ条件「既存の挙動を壊さない」に対応）。
if reason="$(issue_mr_flow_branch_reason '' '')"; then
  status=0
else
  status=1
fi
assert_failure "issue番号も作業ファイルも無ければ対象外" "$status"
assert_eq "対象外のときは何も出力しない" "" "$(issue_mr_flow_branch_reason '' '' || true)"

# ブランチ名だけが根拠になるケース（フロー序盤。plans/ をまだ作っていない flow-id 1-3 直後）
reason="$(issue_mr_flow_branch_reason '113' '')"
assert_contains "issue番号だけでも対象と判定する" "$reason" "issue命名規則"
assert_contains "根拠にissue番号が入る" "$reason" "#113"
assert_not_contains "作業ファイルが無ければその根拠は挙げない" "$reason" "作業ファイル"

# 作業ファイルだけが根拠になるケース（ブランチ名が命名規則から外れている場合。
# 例: Claude Code on the web が自動生成する claude/<slug> 形式のブランチ）
reason="$(issue_mr_flow_branch_reason '' 'plans/【実装】x.md')"
assert_contains "作業ファイルだけでも対象と判定する" "$reason" "作業ファイル"
assert_not_contains "issue番号が無ければその根拠は挙げない" "$reason" "issue命名規則"

# 両方そろう場合は両方を根拠として挙げる
reason="$(issue_mr_flow_branch_reason '113' 'plans/【実装】x.md')"
assert_contains "両方そろえば1つ目の根拠が入る" "$reason" "issue命名規則"
assert_contains "両方そろえば2つ目の根拠が入る" "$reason" "作業ファイル"

# 改行しか無い入力を「作業ファイルあり」と誤判定しないこと（get_branch_work_files は
# 該当が無ければ空文字列を返すが、呼び出し側の変更で改行だけが残る事故を防ぐ）。
# ここでは -n 判定の仕様として「改行1文字も非空」であることを明示的に固定する。
assert_contains "改行のみでも非空として扱われる（-n の仕様を明示）" \
  "$(issue_mr_flow_branch_reason '' $'\n')" "作業ファイル"

# --- format_skill_reload_instruction: SKILL.md再読み込みの指示文 ---------------

instruction="$(format_skill_reload_instruction 'テスト用の根拠')"
assert_eq "指示文は見出し行で始まる" \
  "## issue-mr-flowの手順（SKILL.md）を読み直すこと" \
  "$(printf '%s' "$instruction" | head -1)"
assert_contains "読み直すファイルのパスを明示する" \
  "$instruction" ".claude/skills/issue-mr-flow/SKILL.md"
assert_contains "判定根拠が本文へ埋め込まれる" "$instruction" "テスト用の根拠"
# compact対策の要は「既に読んだつもりでも読み直す」ことを明示する点にある（issue #113）
assert_contains "既読でも読み直すよう明示する" "$instruction" "既に読んでいる場合も読み直すこと"
assert_contains "compactが原因であることに触れる" "$instruction" "compact"

# 指示文はしきい値（8000バイト）に対して十分小さい。注入量の肥大化検知（DDR i0057-01）を
# この追加だけで誤って発火させないことを、実測値で固定しておく。
instruction_bytes="$(context_text_bytes "$instruction")"
if [ "$instruction_bytes" -lt 1000 ]; then
  status=0
else
  status=1
fi
assert_success "指示文は1000バイト未満（しきい値8000に対して十分小さい）" "$status"

# --- current_flow_id_to_reply: 現在地flow-idの解決（issue #160） -----------------

# TMP_DIR（冒頭の trap が EXIT/INT/TERM で削除する）の配下へ掘る。独立に mktemp -d して
# trap を張り直すと、bashのtrapは上書きのため TMP_DIR 側の後片付けが無効になる。
tmp_handoff_dir="$TMP_DIR/handoff"
mkdir -p "$tmp_handoff_dir"

# ケース1: 進捗表なし（ファイル自体が無い）→ 空（fail-open）
current_flow_id_to_reply "$tmp_handoff_dir/no-such-file.md"
assert_eq "現在地解決: ファイルが無ければ空を返す" "" "$REPLY"

# ケース2: 全行 [] → 最初の行
cat > "$tmp_handoff_dir/fresh.md" <<'H'
| 進捗 | flow-id | ステップ | 担当 |
|---|---|---|---|
| [] | 1-1 | issueを起票する | 人間 |
| [] | 1-2 | issueの内容を取得する | `start` |
H
current_flow_id_to_reply "$tmp_handoff_dir/fresh.md"
assert_eq "現在地解決: 全行 [] なら最初の行" "1-1" "$REPLY"

# ケース3: 穴あき・[-] 混在 → 最後の [x]/[-] より後の最初の []
#（1-5 が [] のまま残っていても、後続の [x] があれば現在地は先へ進む。
#  「最初の [] を採る」方式では 1-5 を返し続けてしまう）
cat > "$tmp_handoff_dir/skip.md" <<'H'
| 進捗 | flow-id | ステップ | 担当 |
|---|---|---|---|
| [x] | 1-4 | 全体作業計画 | エージェント |
| [] | 1-5 | 合意 | 人間 |
| [x] | 1-6 | HANDOFF更新 | エージェント |
| [-] | 2-1 | 個別調査計画 | エージェント |
| [] | 2-2 | commit/push | エージェント |
| [] | 2-3 | レビュー | 人間 |
H
current_flow_id_to_reply "$tmp_handoff_dir/skip.md"
assert_eq "現在地解決: 最後の [x]/[-] の次の [] を採る（1-5 に留まらない）" "2-2" "$REPLY"

# ケース4: 書式が想定と違う（進捗表の行が1つも無い）→ 空（fail-open）
cat > "$tmp_handoff_dir/broken.md" <<'H'
# HANDOFF
進捗表はまだ無い。
H
current_flow_id_to_reply "$tmp_handoff_dir/broken.md"
assert_eq "現在地解決: 進捗表の行が無ければ空を返す" "" "$REPLY"

# 全行 [x]（末尾まで完了）→ 空
cat > "$tmp_handoff_dir/done.md" <<'H'
| 進捗 | flow-id | ステップ | 担当 |
|---|---|---|---|
| [x] | 5-5 | Draft解除 | エージェント |
| [x] | 5-6 | マージ | 人間 |
H
current_flow_id_to_reply "$tmp_handoff_dir/done.md"
assert_eq "現在地解決: 全行完了なら空を返す" "" "$REPLY"

# 旧表記（周回数を記号の個数で表す [x][x][]）が混ざる表 → 空（fail-open）。
# *x* の部分一致で読むと進行中のループ範囲を完了扱いにし、誤った現在地（5-1）を注入してしまう。
cat > "$tmp_handoff_dir/legacy.md" <<'H'
| 進捗 | flow-id | ステップ | 担当 |
|---|---|---|---|
| [x] | 4-5 | HANDOFF更新 | エージェント |
| [x][x][] | 4-6 | 反映実施 | エージェント |
| [] | 5-1 | コンフリクト検知 | エージェント |
H
current_flow_id_to_reply "$tmp_handoff_dir/legacy.md"
assert_eq "現在地解決: 旧表記 [x][x][] が混ざる表では空を返す（fail-open）" "" "$REPLY"

# --- refs_for_flow_id_to_reply: 参照列の抽出（issue #160） ------------------------

cat > "$tmp_handoff_dir/skill.md" <<'H'
| フェーズ | 範囲 | 内容 |
|---|---|---|
| 1 | 1-1〜1-6 | 起点 |

| flow-id | ステップ | 担当 | 参照 |
|---|---|---|---|
| 1-1 | issueを起票する | 人間 | — |
| 3-6 | 作業を進める | エージェント | `references/deliverables.md` |
H
refs_for_flow_id_to_reply "$tmp_handoff_dir/skill.md" "3-6"
assert_eq "参照抽出: 指定flow-idの参照列を返す" '`references/deliverables.md`' "$REPLY"
refs_for_flow_id_to_reply "$tmp_handoff_dir/skill.md" "1-1"
assert_eq "参照抽出: 参照が不要な行は — を返す" "—" "$REPLY"
refs_for_flow_id_to_reply "$tmp_handoff_dir/skill.md" "9-9"
assert_eq "参照抽出: 存在しないflow-idでは空を返す（fail-open）" "" "$REPLY"
refs_for_flow_id_to_reply "$tmp_handoff_dir/no-such-file.md" "1-1"
assert_eq "参照抽出: ファイルが無ければ空を返す（fail-open）" "" "$REPLY"

# セル内の \|（markdownの表で正当なパイプのエスケープ）で awk のフィールドがずれる行 →
# 別の列の値（担当列の「エージェント」等）を参照として返さず、空を返す（fail-open）
cat > "$tmp_handoff_dir/skill-escaped-pipe.md" <<'H'
| flow-id | ステップ | 担当 | 参照 |
|---|---|---|---|
| 3-6 | `a \| b` を実行する | エージェント | `references/deliverables.md` |
H
refs_for_flow_id_to_reply "$tmp_handoff_dir/skill-escaped-pipe.md" "3-6"
assert_eq "参照抽出: セル内に \\| がありフィールドがずれた行では空を返す（fail-open）" "" "$REPLY"

# 参照が2つ併記される行はそのまま返る（検証の正規表現が ` / ` 区切りの列挙を通すこと）
cat > "$tmp_handoff_dir/skill-two-refs.md" <<'H'
| flow-id | ステップ | 担当 | 参照 |
|---|---|---|---|
| 2-1 | 個別調査計画を作る | エージェント | `references/planning.md` / `references/deliverables.md` |
H
refs_for_flow_id_to_reply "$tmp_handoff_dir/skill-two-refs.md" "2-1"
assert_eq '参照抽出: 「 / 」区切りで2つ併記された参照はそのまま返す' \
  '`references/planning.md` / `references/deliverables.md`' "$REPLY"

# --- ROW_RE: update-handoff-progress.sh 側と同一リテラルであること（issue #160） --
# source で共有できない（あちらの冒頭で宣言される set -euo pipefail がhookへも効き、
# fail-open 設計が壊れる）ため複製しており、ズレをここで機械検出する。
row_re_hook="$(grep '^ROW_RE=' "$repo_root/.claude/hooks/session-start.sh")"
row_re_script="$(grep '^ROW_RE=' "$repo_root/.claude/scripts/src/update-handoff-progress.sh")"
assert_eq "ROW_RE: hook側とupdate-handoff-progress.sh側のリテラルが完全一致する" \
  "$row_re_script" "$row_re_hook"
assert_contains "ROW_RE: 空定義ではない（grepが実際に定義行を取れている）" \
  "$row_re_hook" "ROW_RE='^"

# --- format_skill_reload_instruction: 参照行の出し分け（issue #160） --------------

instruction_with_refs="$(format_skill_reload_instruction 'テスト用の根拠' '現在地 flow-id 3-6 の実行前に開く参照: `references/deliverables.md`')"
assert_contains "指示文: 第2引数の参照行が末尾へ付く" \
  "$instruction_with_refs" '現在地 flow-id 3-6 の実行前に開く参照'
assert_eq "指示文: 参照行が最終行に置かれる" \
  '現在地 flow-id 3-6 の実行前に開く参照: `references/deliverables.md`' \
  "$(printf '%s' "$instruction_with_refs" | tail -1)"
instruction_no_refs="$(format_skill_reload_instruction 'テスト用の根拠')"
assert_not_contains "指示文: 参照行なしでは『現在地』の行を出さない" \
  "$instruction_no_refs" "現在地"

# 「末尾に空行が残らない」はコマンド置換経由では検証できない（置換が末尾の改行を全て
# 落とすため、実装が空行を出しても常に成功する）。ファイルへ書き、最後の2バイトを直接見る。
# 末尾が「非改行文字＋改行1つ」なら $(tail -c 2) は非空、空行が残っていれば「\n\n」で空になる。
format_skill_reload_instruction 'テスト用の根拠' > "$tmp_handoff_dir/instr_no_refs.txt"
assert_eq "指示文: 参照行なしでも末尾に空行が残らない" "1" \
  "$([ -n "$(tail -c 2 "$tmp_handoff_dir/instr_no_refs.txt")" ] && echo 1)"
format_skill_reload_instruction 'テスト用の根拠' \
  '現在地 flow-id 3-6 の実行前に開く参照: `references/deliverables.md`' \
  > "$tmp_handoff_dir/instr_refs.txt"
assert_eq "指示文: 参照行ありでも末尾に空行が残らない" "1" \
  "$([ -n "$(tail -c 2 "$tmp_handoff_dir/instr_refs.txt")" ] && echo 1)"

# --- 実データ回帰: 実HANDOFF.md・実SKILL.mdに対する検証（issue #160） -------------
# 合成フィクスチャだけではヘッダ改名・表の追加・セル内エスケープ等の実ファイル側の変化を
# 検出できない（`.claude/rules/shell-script-style.md`「テスト」の「合成フィクスチャのテスト
# だけで完了としない」）。

real_skill="$repo_root/.claude/skills/issue-mr-flow/SKILL.md"

# 実HANDOFF.mdから現在地が解決できる（cleanup-task.sh がリセットした直後のテンプレートでも
# 全行 [] のため必ず解決できる。形式は N-N）
current_flow_id_to_reply "$repo_root/HANDOFF.md"
real_flow_id="$REPLY"
if [[ "$real_flow_id" =~ ^[0-9]+-[0-9]+$ ]]; then
  status=0
else
  status=1
fi
assert_success "実データ: 実HANDOFF.mdから現在地flow-idが解決できる" "$status"

# その現在地で実SKILL.mdの参照列が引ける（— か references/*.md の列挙で、空ではない）
refs_for_flow_id_to_reply "$real_skill" "$real_flow_id"
if [ -n "$REPLY" ]; then
  status=0
else
  status=1
fi
assert_success "実データ: 現在地flow-idの参照列が実SKILL.mdから引ける" "$status"

# 実SKILL.mdの全体フロー表の全行について、参照列が引けること（値の形の検証を通ること）と、
# 名指しされた参照ファイルが実在することを表明する
missing=0
rows=0
while IFS= read -r fid; do
  rows=$((rows + 1))
  refs_for_flow_id_to_reply "$real_skill" "$fid"
  if [ -z "$REPLY" ]; then
    missing=$((missing + 1))
    continue
  fi
  [ "$REPLY" = "—" ] && continue
  while IFS= read -r p; do
    [ -f "$repo_root/.claude/skills/issue-mr-flow/$p" ] || missing=$((missing + 1))
  done < <(printf '%s\n' "$REPLY" | grep -oE 'references/[A-Za-z0-9._-]+\.md')
done < <(grep -oE '^\| [0-9]+-[0-9]+ \|' "$real_skill" | grep -oE '[0-9]+-[0-9]+')
assert_eq "実データ: 全体フロー表は42行ある" "42" "$rows"
assert_eq "実データ: 全行で参照列が引け、名指しされた参照ファイルが実在する（欠落0）" "0" "$missing"

echo "passed=$passed failures=$failures"
[ "$failures" -eq 0 ]
