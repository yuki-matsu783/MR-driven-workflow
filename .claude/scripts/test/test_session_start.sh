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

# 実HANDOFF.mdの状態はタスクの進行度で2通りある——(1) 進捗表がある（タスク進行中）、
# (2) 進捗表が無い（cleanup-task.sh のリセット直後。表は「（進捗表は次タスク着手時に
# 記入する）」の1行に置き換わり、行そのものが無い）。(2) では現在地は解決できないのが
# 正しい挙動（fail-open）なので、表の有無で期待を分岐する。どちらの状態でも意味のある
# 表明になるため、mainへマージされた直後（=リセット済みHANDOFF）でもこのテストは通る。
if grep -qE "$ROW_RE" "$repo_root/HANDOFF.md"; then
  # 進捗表がある: 現在地が N-N 形式で解決できること
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
else
  # 進捗表が無い（リセット直後）: 解決は空を返す（fail-open）こと
  current_flow_id_to_reply "$repo_root/HANDOFF.md"
  if [ -z "$REPLY" ]; then
    status=0
  else
    status=1
  fi
  assert_success "実データ: 進捗表の無いHANDOFF.mdでは現在地を解決しない（fail-open）" "$status"

  # 表が無い状態でも、参照列の検証は代表flow-id（1-1）で実SKILL.mdに対して行う
  refs_for_flow_id_to_reply "$real_skill" "1-1"
  if [ -n "$REPLY" ]; then
    status=0
  else
    status=1
  fi
  assert_success "実データ: 参照列が実SKILL.mdから引ける（代表flow-id 1-1）" "$status"
fi

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
assert_eq "実データ: 全体フロー表は43行ある" "43" "$rows"
assert_eq "実データ: 全行で参照列が引け、名指しされた参照ファイルが実在する（欠落0）" "0" "$missing"

# --- UserUtteranceSelect.jq: ユーザー発言の抽出・選定・整形（issue #151） -----------
# 設計の正: wip/plans/【設計】【実装】【テスト】ユーザー発言抽出・再注入の実装.md

filter_path="$repo_root/.claude/hooks/lib/UserUtteranceSelect.jq"

# jqフィルタを直接呼ぶ（transcriptのJSONLファイルを渡す）
run_filter() {
  local branch="$1" ack_raw="$2" head_count="$3" tail_count="$4" max_bytes="$5" jsonl_file="$6"
  jq -R -n -f "$filter_path" \
    --arg branch "$branch" \
    --arg ack_words_raw "$ack_raw" \
    --argjson head_count "$head_count" \
    --argjson tail_count "$tail_count" \
    --argjson max_bytes "$max_bytes" \
    < "$jsonl_file"
}

# transcript 1行分（母集団条件を満たす形）を組み立てて標準出力へ返す
# $1=uuid $2=text $3=gitBranchのJSON表現（null または "\"名前\""） $4=origin.kindのJSON表現
# $5=isSidechain（既定false） $6=userType（既定external） $7=type（既定user）
mkrow() {
  local uuid="$1" text="$2" branch_json="$3" origin_kind_json="$4"
  local is_sidechain="${5:-false}" user_type="${6:-external}" row_type="${7:-user}"
  jq -nc --arg uuid "$uuid" --arg text "$text" --arg type "$row_type" --arg userType "$user_type" \
    --argjson isSidechain "$is_sidechain" --argjson originKind "$origin_kind_json" \
    --argjson branch "$branch_json" \
    '{type:$type, message:{content:$text}, userType:$userType, isSidechain:$isSidechain,
      origin:{kind:$originKind}, uuid:$uuid, gitBranch:$branch}'
}

utterance_tmp="$TMP_DIR/utterance"
mkdir -p "$utterance_tmp"

# 母集団カウント: N=0/1/2/3/5/10
fixture="$utterance_tmp/pop0.jsonl"
: > "$fixture"
result="$(run_filter '' '' 3 7 6000 "$fixture")"
assert_eq "母集団0件: populationCountが0" "0" "$(printf '%s' "$result" | jq -r '.populationCount')"
assert_eq "母集団0件: sectionTextが空" "" "$(printf '%s' "$result" | jq -r '.sectionText')"

for n in 1 2 3 5 10; do
  fixture="$utterance_tmp/pop_${n}.jsonl"
  : > "$fixture"
  for ((i = 1; i <= n; i++)); do
    mkrow "uuid-${n}-${i}" "発言その${i}" null '"human"' >> "$fixture"
  done
  result="$(run_filter '' '' 3 7 6000 "$fixture")"
  assert_eq "母集団${n}件: populationCountが一致" "$n" \
    "$(printf '%s' "$result" | jq -r '.populationCount')"
done

# origin.kind によるフィルタ（肯定形での確認。issue #151の設計判断: 否定形にしない）
fixture="$utterance_tmp/origin.jsonl"
: > "$fixture"
mkrow "u1" "人間発言" null '"human"' >> "$fixture"
mkrow "u2" "エージェント発言" null '"agent"' >> "$fixture"
mkrow "u3" "origin無し" null 'null' >> "$fixture"
result="$(run_filter '' '' 3 7 6000 "$fixture")"
assert_eq "origin.kind!=humanの行は母集団から除外される" "1" \
  "$(printf '%s' "$result" | jq -r '.populationCount')"

# isSidechain の回帰テスト（jqの `//` はfalseもfalsyとして書き換えるため `// null` を使うと
# 全件が母集団から漏れる。issue #151フェーズ3実装時に実際に踏んだ）
fixture="$utterance_tmp/sidechain.jsonl"
: > "$fixture"
mkrow "u1" "本流の発言" null '"human"' false >> "$fixture"
mkrow "u2" "サイドチェーンの発言" null '"human"' true >> "$fixture"
result="$(run_filter '' '' 3 7 6000 "$fixture")"
assert_eq "isSidechain=falseの行のみ母集団に入る（false-as-falsy回帰防止）" "1" \
  "$(printf '%s' "$result" | jq -r '.populationCount')"

# ブランチ絞り: 一致/不一致（全件フォールバック）/gitBranch欠落（Gemini CLI相当・全件フォールバック）
fixture="$utterance_tmp/branch.jsonl"
: > "$fixture"
mkrow "u1" "Aの発言1" '"feature-a"' '"human"' >> "$fixture"
mkrow "u2" "Aの発言2" '"feature-a"' '"human"' >> "$fixture"
mkrow "u3" "Bの発言" '"feature-b"' '"human"' >> "$fixture"
result="$(run_filter 'feature-a' '' 3 7 6000 "$fixture")"
assert_eq "ブランチ一致: 一致する行だけに絞る" "2" \
  "$(printf '%s' "$result" | jq -r '.populationCount')"
result="$(run_filter 'feature-z' '' 3 7 6000 "$fixture")"
assert_eq "ブランチ不一致（全行がgitBranchを持つが1件も一致しない）: フォールバックせず0件" "0" \
  "$(printf '%s' "$result" | jq -r '.populationCount')"

fixture="$utterance_tmp/branch_absent.jsonl"
: > "$fixture"
mkrow "u1" "発言1" null '"human"' >> "$fixture"
mkrow "u2" "発言2" null '"human"' >> "$fixture"
result="$(run_filter 'feature-a' '' 3 7 6000 "$fixture")"
assert_eq "gitBranch欠落（Gemini CLI相当）: 全件へフォールバック" "2" \
  "$(printf '%s' "$result" | jq -r '.populationCount')"

# uuidによる重複除去
fixture="$utterance_tmp/dedup.jsonl"
: > "$fixture"
mkrow "dup-1" "同じ発言" null '"human"' >> "$fixture"
mkrow "dup-1" "同じ発言" null '"human"' >> "$fixture"
mkrow "u2" "別の発言" null '"human"' >> "$fixture"
result="$(run_filter '' '' 3 7 6000 "$fixture")"
assert_eq "同一uuidは重複除去され1件になる" "2" \
  "$(printf '%s' "$result" | jq -r '.populationCount')"

# 辞書の完全一致除外（正規化: 前後の句読点を除去してから比較）
fixture="$utterance_tmp/dict.jsonl"
: > "$fixture"
mkrow "u1" "はい" null '"human"' >> "$fixture"
mkrow "u2" "はい。" null '"human"' >> "$fixture"
mkrow "u3" "了解です" null '"human"' >> "$fixture"
mkrow "u4" "本題の発言" null '"human"' >> "$fixture"
result="$(run_filter '' $'はい\nありがとう' 3 7 6000 "$fixture")"
assert_eq "母集団カウントは除外前の件数のまま" "4" \
  "$(printf '%s' "$result" | jq -r '.populationCount')"
assert_eq "辞書完全一致（句読点除去後）は2件除外される" "2" \
  "$(printf '%s' "$result" | jq '[.excludedEvents[] | select(.word == "はい")] | length')"
dict_sel_text="$(printf '%s' "$result" | jq -r '.sectionText')"
assert_not_contains "辞書一致した発言はsectionTextに現れない" "$dict_sel_text" "「はい」"
assert_contains "部分一致に留まる語は除外されない（「了解です」は辞書「了解」と完全一致しない）" \
  "$dict_sel_text" "了解です"
assert_contains "本題の発言は残る" "$dict_sel_text" "本題の発言"

# 辞書が空/未指定なら除外は一切起きない
result="$(run_filter '' '' 3 7 6000 "$fixture")"
assert_eq "辞書が空なら除外は起きない" "0" "$(printf '%s' "$result" | jq '.excludedEvents | length')"
assert_contains "辞書無効時は「はい」も残る" "$(printf '%s' "$result" | jq -r '.sectionText')" "「はい」"

# 引数無しスラッシュコマンドのみ除外（引数ありは除外されない）
fixture="$utterance_tmp/slash.jsonl"
: > "$fixture"
mkrow "u1" "/compact" null '"human"' >> "$fixture"
mkrow "u2" "/issue-mr-flow start 151" null '"human"' >> "$fixture"
result="$(run_filter '' '' 3 7 6000 "$fixture")"
slash_sel_text="$(printf '%s' "$result" | jq -r '.sectionText')"
assert_contains "引数ありスラッシュコマンドは除外されない" "$slash_sel_text" "/issue-mr-flow start 151"
assert_not_contains "引数無しスラッシュコマンドは除外される" "$slash_sel_text" "/compact"

# `<command-name>`等タグ始まりの行は除外される
fixture="$utterance_tmp/tag.jsonl"
: > "$fixture"
mkrow "u1" "<command-name>compact</command-name>" null '"human"' >> "$fixture"
mkrow "u2" "通常の発言" null '"human"' >> "$fixture"
result="$(run_filter '' '' 3 7 6000 "$fixture")"
tag_sel_text="$(printf '%s' "$result" | jq -r '.sectionText')"
assert_contains "通常発言は残る" "$tag_sel_text" "通常の発言"
assert_not_contains "タグ始まりの行は除外される" "$tag_sel_text" "command-name"

# 採り方: 先頭3+末尾7（重複なし・最大10件）。15件から選ぶと中間（4〜8件目）は落ちる
fixture="$utterance_tmp/sizing.jsonl"
: > "$fixture"
for ((i = 1; i <= 15; i++)); do
  mkrow "sz-${i}" "発言${i}" null '"human"' >> "$fixture"
done
result="$(run_filter '' '' 3 7 6000 "$fixture")"
sizing_sel_text="$(printf '%s' "$result" | jq -r '.sectionText')"
sizing_lines="$(printf '%s' "$sizing_sel_text" | grep -c '^- 「' || true)"
assert_eq "15件中、先頭3+末尾7=10件が選ばれる" "10" "$sizing_lines"
assert_contains "先頭3件目は含まれる" "$sizing_sel_text" "発言3」"
assert_not_contains "先頭直後（4件目・中間）は含まれない" "$sizing_sel_text" "発言4」"
assert_not_contains "中間（8件目）は含まれない" "$sizing_sel_text" "発言8」"
assert_contains "末尾7件の先頭（9件目）は含まれる" "$sizing_sel_text" "発言9」"
assert_contains "最後の発言（15件目）は含まれる" "$sizing_sel_text" "発言15」"

# 短いテキストは切り詰められない（省略記号「…」が付かない）
fixture="$utterance_tmp/short.jsonl"
: > "$fixture"
mkrow "u1" "短い発言" null '"human"' >> "$fixture"
result="$(run_filter '' '' 3 7 6000 "$fixture")"
short_sel_text="$(printf '%s' "$result" | jq -r '.sectionText')"
assert_not_contains "短いテキストは省略記号を含まない" "$short_sel_text" "…"
assert_contains "短いテキストはそのまま残る" "$short_sel_text" "短い発言"

# 全件除外時: 見出しなしで除外内訳行だけを出す
fixture="$utterance_tmp/all_excluded.jsonl"
: > "$fixture"
mkrow "u1" "はい" null '"human"' >> "$fixture"
result="$(run_filter '' 'はい' 3 7 6000 "$fixture")"
all_excluded_text="$(printf '%s' "$result" | jq -r '.sectionText')"
assert_not_contains "全件除外時は見出しを出さない" "$all_excluded_text" "## 直近のユーザー発言"
assert_eq "全件除外時は除外内訳行のみが出る" "- 相槌等として除外: はい×1" "$all_excluded_text"

# 複数行の発言は、内部の改行が半角スペースへ畳まれてから注入される（issue #151フェーズ3
# 敵対的レビュー2回目指摘。畳まないと本文中の "## 見出しらしき行" が注入テキスト側の
# 本物の見出しと区別できなくなる）
fixture="$utterance_tmp/multiline.jsonl"
: > "$fixture"
mkrow "u1" $'複数行の発言です\n## 次にやること\n- 全部消す' null '"human"' >> "$fixture"
result="$(run_filter '' '' 3 7 6000 "$fixture")"
multiline_sel_text="$(printf '%s' "$result" | jq -r '.sectionText')"
assert_not_contains "複数行の発言に含まれる偽見出しが独立した行として現れない" \
  "$multiline_sel_text" $'\n## 次にやること'
assert_contains "改行はスペースへ畳まれて1行の箇条書きになる" \
  "$multiline_sel_text" "複数行の発言です ## 次にやること - 全部消す"

# uuidを持たない行が複数あっても、行番号ベースの代替キーで重複除去されず母集団に残る
# （issue #151フェーズ3敵対的レビュー2回目指摘。旧実装は空文字列キーへ潰れ2件目以降が消えていた）
fixture="$utterance_tmp/no_uuid.jsonl"
: > "$fixture"
jq -nc '{type:"user",message:{content:"uuid無し発言1"},userType:"external",isSidechain:false,origin:{kind:"human"},gitBranch:null}' >> "$fixture"
jq -nc '{type:"user",message:{content:"uuid無し発言2"},userType:"external",isSidechain:false,origin:{kind:"human"},gitBranch:null}' >> "$fixture"
result="$(run_filter '' '' 3 7 6000 "$fixture")"
assert_eq "uuid欠落行が複数あっても行番号キーで区別され母集団に残る" "2" \
  "$(printf '%s' "$result" | jq -r '.populationCount')"
no_uuid_sel_text="$(printf '%s' "$result" | jq -r '.sectionText')"
assert_contains "1件目のuuid無し発言が残る" "$no_uuid_sel_text" "uuid無し発言1"
assert_contains "2件目のuuid無し発言も残る（重複除去で消えない）" "$no_uuid_sel_text" "uuid無し発言2"

# スラッシュコマンド・タグ始まり判定は前後の空白を持つ行にも効く（issue #151フェーズ3
# 敵対的レビュー2回目指摘。旧実装は正規化前の生テキストへ直接アンカー付き正規表現を掛けていた）
fixture="$utterance_tmp/slash_ws.jsonl"
: > "$fixture"
mkrow "u1" "/compact " null '"human"' >> "$fixture"
mkrow "u2" "  /clear" null '"human"' >> "$fixture"
mkrow "u3" " <command-name>x</command-name> " null '"human"' >> "$fixture"
mkrow "u4" "本題の発言" null '"human"' >> "$fixture"
result="$(run_filter '' '' 3 7 6000 "$fixture")"
ws_sel_text="$(printf '%s' "$result" | jq -r '.sectionText')"
assert_not_contains "前後空白付きスラッシュコマンド(末尾空白)も除外される" "$ws_sel_text" "/compact"
assert_not_contains "前後空白付きスラッシュコマンド(先頭空白)も除外される" "$ws_sel_text" "/clear"
assert_not_contains "前後空白付きタグ始まり行も除外される" "$ws_sel_text" "command-name"
assert_contains "通常発言は残る" "$ws_sel_text" "本題の発言"

# バイト予算の判定は除外内訳行を含めた節全体で行う（issue #151フェーズ3敵対的レビュー2回目指摘。
# 旧実装は箇条書き本文だけで判定しており、除外内訳行を足した結果が上限を超えるケースを
# 見逃していた）
fixture="$utterance_tmp/budget_with_excl.jsonl"
: > "$fixture"
mkrow "h1" "先頭発言" null '"human"' >> "$fixture"
mkrow "d1" "はい" null '"human"' >> "$fixture"
mkrow "t1" "末尾テキスト1" null '"human"' >> "$fixture"
result="$(run_filter '' 'はい' 1 1 110 "$fixture")"
budget_excl_text="$(printf '%s' "$result" | jq -r '.sectionText')"
assert_contains "先頭枠は残る" "$budget_excl_text" "先頭発言"
assert_contains "除外内訳行は残る（先頭枠と合わせて予算判定に使われる）" \
  "$budget_excl_text" "相槌等として除外"
assert_not_contains "除外内訳行込みで予算超過した末尾枠は落とされる" \
  "$budget_excl_text" "末尾テキスト1"

# --- build_user_utterance_context: hook側のラッパー関数（issue #151） -----------------
# 実ファイル（フィルタ本体・辞書）を最小構成のテスト用プロジェクトディレクトリへコピーし、
# CLAUDE_PROJECT_DIR をそこへ向けて呼ぶ（本物の wip/state/ を汚さないため）。

utterance_proj="$utterance_tmp/proj"
mkdir -p "$utterance_proj/.claude/hooks/lib"
cp "$filter_path" "$utterance_proj/.claude/hooks/lib/UserUtteranceSelect.jq"
cp "$repo_root/.claude/hooks/session-start-ack-words.txt" \
  "$utterance_proj/.claude/hooks/session-start-ack-words.txt"

saved_claude_project_dir="${CLAUDE_PROJECT_DIR:-}"
export CLAUDE_PROJECT_DIR="$utterance_proj"

# transcript_path未指定・ファイル不在はいずれもfail-open（何も出力せず正常終了）
if out="$(build_user_utterance_context 'branch-x' '')"; then status=0; else status=1; fi
assert_success "transcript_path未指定でも失敗しない（fail-open）" "$status"
assert_eq "transcript_path未指定なら出力は空" "" "$out"

if out="$(build_user_utterance_context 'branch-x' "$utterance_tmp/not-exist.jsonl")"; then
  status=0
else
  status=1
fi
assert_success "transcriptファイル不在でも失敗しない（fail-open）" "$status"
assert_eq "存在しないtranscriptなら出力は空" "" "$out"

# 通常のtranscript: 見出し・センチネル行・累積状態ファイルの新規作成
transcript1="$utterance_tmp/transcript1.jsonl"
: > "$transcript1"
mkrow "e1" "はい" null '"human"' >> "$transcript1"
mkrow "e2" "本題の発言その1" null '"human"' >> "$transcript1"
mkrow "e3" "本題の発言その2" null '"human"' >> "$transcript1"

out="$(build_user_utterance_context 'branch-x' "$transcript1")"
assert_contains "通常のtranscriptではセクション見出しが出る" "$out" "## 直近のユーザー発言"
assert_contains "出力末尾にセンチネル行が付く" "$out" "__USER_UTTERANCE_BYTES__:"

state_file="$utterance_proj/wip/state/session-start-ack-exclusion-counts.json"
if [ -f "$state_file" ]; then status=0; else status=1; fi
assert_success "累積状態ファイルが初回実行で新規作成される" "$status"
assert_eq "初回実行: 累積カウントに1件反映される" "1" \
  "$(jq -r '.counts["はい"] // 0' "$state_file")"

# 同一セッション内での再実行（同じuuid）はカウントを二重加算しない
build_user_utterance_context 'branch-x' "$transcript1" >/dev/null
assert_eq "同一uuidの再走査はカウントを二重加算しない" "1" \
  "$(jq -r '.counts["はい"] // 0' "$state_file")"

# 新しいuuidの除外は累積へ加算される
transcript2="$utterance_tmp/transcript2.jsonl"
: > "$transcript2"
mkrow "e4" "はい" null '"human"' >> "$transcript2"
mkrow "e5" "別の本題" null '"human"' >> "$transcript2"
build_user_utterance_context 'branch-x' "$transcript2" >/dev/null
assert_eq "新しいuuidの除外は累積へ加算される" "2" \
  "$(jq -r '.counts["はい"] // 0' "$state_file")"

# 累積状態ファイルの破損からの自己回復
transcript3="$utterance_tmp/transcript3.jsonl"
: > "$transcript3"
mkrow "e6" "はい" null '"human"' >> "$transcript3"
printf 'not valid json {{{' > "$state_file"
build_user_utterance_context 'branch-x' "$transcript3" >/dev/null
assert_eq "壊れた累積状態ファイルは既定値へ自己回復してから加算する" "1" \
  "$(jq -r '.counts["はい"] // 0' "$state_file")"
if jq -e . "$state_file" >/dev/null 2>&1; then status=0; else status=1; fi
assert_success "自己回復後のファイルは有効なJSON" "$status"

# 構文は正しいが形が違うJSON（配列・null・countsが配列）でも自己回復する（issue #151フェーズ3
# 敵対的レビュー2回目指摘。`jq -e .`は構文の妥当性しか見ないため、これらを素通りさせると
# 後続のマージが「Cannot index array with string」で失敗し続ける）
for malformed in '[]' 'null' '{"counts":[]}' '"just a string"' '123'; do
  transcript_shape="$utterance_tmp/transcript_shape.jsonl"
  : > "$transcript_shape"
  mkrow "shape-$RANDOM" "はい" null '"human"' >> "$transcript_shape"
  printf '%s' "$malformed" > "$state_file"
  if out_shape="$(build_user_utterance_context 'branch-x' "$transcript_shape")"; then
    status=0
  else
    status=1
  fi
  assert_success "壊れた形のJSON（${malformed}）でも失敗しない（fail-open）" "$status"
  if jq -e 'type == "object" and (.counts | type) == "object" and (.countedUuids | type) == "array"' \
    "$state_file" >/dev/null 2>&1; then
    status=0
  else
    status=1
  fi
  assert_success "壊れた形のJSON（${malformed}）は既定値の形へ自己回復する" "$status"
done

# バイト予算超過時のトリミング（先頭枠は必ず残り、末尾枠は古い側から間引かれる）
saved_head_count="$USER_UTTERANCE_HEAD_COUNT"
saved_tail_count="$USER_UTTERANCE_TAIL_COUNT"
saved_max_bytes="$USER_UTTERANCE_MAX_BYTES"
USER_UTTERANCE_HEAD_COUNT=1
USER_UTTERANCE_TAIL_COUNT=5
USER_UTTERANCE_MAX_BYTES=150
transcript_budget="$utterance_tmp/transcript_budget.jsonl"
: > "$transcript_budget"
mkrow "bh1" "先頭発言" null '"human"' >> "$transcript_budget"
for i in 1 2 3 4 5; do
  mkrow "bt${i}" "末尾テキスト${i}" null '"human"' >> "$transcript_budget"
done
out_budget="$(build_user_utterance_context 'branch-x' "$transcript_budget")"
assert_contains "バイト予算超過時も先頭枠は残る" "$out_budget" "先頭発言"
assert_not_contains "バイト予算超過時は古い末尾から間引かれる（最古が落ちる）" "$out_budget" "末尾テキスト1」"
assert_contains "バイト予算超過時も新しい末尾は残る" "$out_budget" "末尾テキスト5」"
USER_UTTERANCE_HEAD_COUNT="$saved_head_count"
USER_UTTERANCE_TAIL_COUNT="$saved_tail_count"
USER_UTTERANCE_MAX_BYTES="$saved_max_bytes"

# 辞書ファイル自体が無い/読めない場合も除外なしで動く（クラッシュしない）
utterance_proj_nodict="$utterance_tmp/proj_nodict"
mkdir -p "$utterance_proj_nodict/.claude/hooks/lib"
cp "$filter_path" "$utterance_proj_nodict/.claude/hooks/lib/UserUtteranceSelect.jq"
CLAUDE_PROJECT_DIR="$utterance_proj_nodict"
transcript_nodict="$utterance_tmp/transcript_nodict.jsonl"
: > "$transcript_nodict"
mkrow "nd1" "はい" null '"human"' >> "$transcript_nodict"
out_nodict="$(build_user_utterance_context 'branch-x' "$transcript_nodict")"
assert_contains "辞書ファイル不在でもクラッシュせず「はい」が残る" "$out_nodict" "「はい」"
CLAUDE_PROJECT_DIR="$utterance_proj"

# フィルタ本体（UserUtteranceSelect.jq）が無い場合もfail-open（何も出力せず正常終了）
utterance_proj_nofilter="$utterance_tmp/proj_nofilter"
mkdir -p "$utterance_proj_nofilter/.claude/hooks/lib"
CLAUDE_PROJECT_DIR="$utterance_proj_nofilter"
if out_nofilter="$(build_user_utterance_context 'branch-x' "$transcript1")"; then
  status=0
else
  status=1
fi
assert_success "フィルタ本体が無くても失敗しない（fail-open）" "$status"
assert_eq "フィルタ本体が無ければ出力は空" "" "$out_nofilter"
CLAUDE_PROJECT_DIR="$utterance_proj"

# --- strip_utterance_sentinel_to_reply: センチネル行の抽出・除去（issue #151） --------------

strip_utterance_sentinel_to_reply $'## 直近のユーザー発言（SessionStart hook）\n- 「x」\n__USER_UTTERANCE_BYTES__:42'
assert_eq "センチネル行はREPLYから取り除かれる" \
  $'## 直近のユーザー発言（SessionStart hook）\n- 「x」' "$REPLY"
assert_eq "センチネル行のバイト数がREPLY_BYTESへ入る" "42" "$REPLY_BYTES"

strip_utterance_sentinel_to_reply "## 現在の作業ブランチ情報 (SessionStart hook)"
assert_eq "センチネル行が無ければ入力をそのまま返す" \
  "## 現在の作業ブランチ情報 (SessionStart hook)" "$REPLY"
assert_eq "センチネル行が無ければREPLY_BYTESは0のまま" "0" "$REPLY_BYTES"

# --- build_work_context: 実運用の呼び出し経路（issue #151フェーズ3敵対的レビュー2回目指摘） ---
# 純粋関数を直接呼ぶテストだけでは、main→build_context→build_work_context→
# build_user_utterance_context という実運用の結線（transcript_pathの下方向への受け渡し・
# 出力位置の順序）が壊れても検知できない（review-points「実運用の呼び出し経路を通すテストが
# あるか（issue #127）」）。ここでは build_work_context を実引数付きで直接呼び、HANDOFF.mdの
# 「次にやること」節とユーザー発言節の両方が現れ、かつ順序（次にやること→ユーザー発言、
# 個別作業計画「出力位置」節の要件）が正しいことを表明する。

bw_proj="$utterance_tmp/proj_build_work_context"
mkdir -p "$bw_proj/.claude/hooks/lib"
cp "$filter_path" "$bw_proj/.claude/hooks/lib/UserUtteranceSelect.jq"
cp "$repo_root/.claude/hooks/session-start-ack-words.txt" "$bw_proj/.claude/hooks/session-start-ack-words.txt"
cat > "$bw_proj/HANDOFF.md" <<'H'
## 次にやること

- テスト用の次にやること
H
bw_transcript="$utterance_tmp/bw_transcript.jsonl"
: > "$bw_transcript"
mkrow "bw1" "本題の発言" null '"human"' >> "$bw_transcript"

CLAUDE_PROJECT_DIR="$bw_proj"
bw_out="$(build_work_context 'test-branch' "$bw_transcript")"
if [ -n "$saved_claude_project_dir" ]; then
  CLAUDE_PROJECT_DIR="$saved_claude_project_dir"
else
  unset CLAUDE_PROJECT_DIR
fi

assert_contains "build_work_context: 次にやること節が現れる" "$bw_out" "テスト用の次にやること"
assert_contains "build_work_context: ユーザー発言節が現れる" "$bw_out" "本題の発言"
assert_contains "build_work_context: センチネル行が現れる" "$bw_out" "__USER_UTTERANCE_BYTES__:"
next_pos="$(printf '%s' "$bw_out" | grep -n '次にやること' | head -1 | cut -d: -f1)"
utterance_pos="$(printf '%s' "$bw_out" | grep -n '## 直近のユーザー発言' | head -1 | cut -d: -f1)"
assert_success "build_work_context: 次にやることブロックがユーザー発言節より前に現れる（出力位置節の要件）" \
  "$([ "$next_pos" -lt "$utterance_pos" ] && echo 0 || echo 1)"

# --- append_size_warning: 第3引数（除外バイト数）の反映（issue #151） -----------------

result="$(append_size_warning "$(printf 'a%.0s' $(seq 1 200))" 100 100)"
assert_not_contains "除外バイト数を差し引くと実質しきい値以下になり警告が出ない" "$result" "$WARNING_MARKER"
result="$(append_size_warning "$(printf 'a%.0s' $(seq 1 200))" 100 50)"
assert_contains "除外バイト数を差し引いても超過していれば警告が出る" "$result" "$WARNING_MARKER"
assert_contains "警告文に除外後の判定バイト数（150）が含まれる" "$result" "150 バイト"

echo "passed=$passed failures=$failures"
[ "$failures" -eq 0 ]
