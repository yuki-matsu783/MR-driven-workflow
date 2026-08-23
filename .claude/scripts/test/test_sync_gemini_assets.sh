#!/usr/bin/env bash
# .claude/scripts/src/sync-gemini-assets.sh の単体テスト（issue #70）。
#
# **Gemini CLI がこの実行環境に無いため、変換規則の正しさを固定できる手段はこのテストしかない。**
# 「変換した結果を Gemini がロードできるか」は実機でしか確かめられないので、ここで固定するのは
# 「設計で合意した規則どおりに変換されているか」である。
#
# 対象は3層。
#   1. 外部コマンドを呼ばない純粋関数（convert_agent_to_reply / map_tool_name_to_reply）と
#      対応表そのもの（GEMINI_TOOL_PAIRS）
#   2. settings.json の変換（jqフィルタ）。フィクスチャ入力 → ゴールデン比較
#   3. main の結合テスト。mktemp -d + git init の使い捨てリポジトリで**実プロセスとして起動**し、
#      冪等性・--check の終了コード・除外・jq不在時の挙動を見る
#      （合成フィクスチャだけで完了としない。.claude/rules/shell-script-style.md「テスト」）
#
# ゴールデンファイルは `fixtures/sync-gemini-assets/` に置く。**リポジトリ実体の
# `.gemini/settings.json` を流用しない**（出力と期待値が同じだと、変換が壊れたときに両方同時に
# 壊れて検出できない。plans/【設計】… の D-1）。
#
# **agents のフィクスチャは `.md` で終わらせない**（`.md.fixture` / `.md.expected`）。
# `extract-frontmatter.sh` は `.md` を無条件に走査するため、`.md` で置くとフィクスチャの
# frontmatter がドキュメント索引に載り、`doc-search` の結果へ混ざる（実際に一度そうなった）。
#
# 規約: passed=N failures=N を標準出力へ出し、失敗があれば終了コード1
# 実行: bash .claude/scripts/test/test_sync_gemini_assets.sh
set -euo pipefail

script_dir="${BASH_SOURCE[0]%/*}"
[[ "$script_dir" == "${BASH_SOURCE[0]}" ]] && script_dir="."
repo_root="$(cd "$script_dir/../../.." && pwd)"
fixtures="$repo_root/.claude/scripts/test/fixtures/sync-gemini-assets"
target="$repo_root/.claude/scripts/src/sync-gemini-assets.sh"

# shellcheck source=../src/sync-gemini-assets.sh
source "$target"

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

# 終了コードは `if` の条件式で受ける（`"$(func; echo $?)"` は set -e 配下で空文字列になりうる。
# .claude/rules/shell-script-style.md「テスト」）。
status_of() {
  if "$@" >/dev/null 2>&1; then echo 0; else echo 1; fi
}

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

# =========================================================================
# T2: ツール名の対応表そのものを固定する
#
# 「表に無い＝Geminiに無い」ではない（調査結果 Q1）。表は Gemini 側の語彙から突き合わせて
# 作ったものなので、**表の中身自体をテストで固定する**。減った・名前が変わったら落ちる。
# =========================================================================

expected_pairs='Read=read_file
Grep=grep_search
Glob=glob
Bash=run_shell_command
Write=write_file
Edit=replace
LS=list_directory
WebFetch=web_fetch
WebSearch=google_web_search
TodoWrite=write_todos
Task=invoke_agent'

actual_pairs=''
for ((i = 0; i < ${#GEMINI_TOOL_PAIRS[@]}; i += 2)); do
  actual_pairs+="${GEMINI_TOOL_PAIRS[i]}=${GEMINI_TOOL_PAIRS[i + 1]}"$'\n'
done
actual_pairs="${actual_pairs%$'\n'}"

assert_eq "T2: ツール名対応表が期待どおり（11件）" "$expected_pairs" "$actual_pairs"
assert_eq "T2: 対応表の要素数は偶数（キーと値の対）" "0" "$((${#GEMINI_TOOL_PAIRS[@]} % 2))"
assert_eq "T2: map_tool_name_to_reply は表の名前を引ける" "0" "$(status_of map_tool_name_to_reply 'Bash')"
map_tool_name_to_reply 'Bash'
assert_eq "T2: Bash → run_shell_command" "run_shell_command" "$REPLY"
assert_eq "T2: 表に無い名前は非0" "1" "$(status_of map_tool_name_to_reply 'NotebookEdit')"

# =========================================================================
# T1 / T4 / T5: agents 変換のゴールデン比較
#
# T1 変換規則が壊れたことを検出する唯一の手段
# T4 `tools` が YAML配列で出ること（issue #70 の症状そのもの）
# T5 `title`/`type`/`tags`/`keywords`/`model` が落ちること（localAgentSchema は .strict()）
# =========================================================================

# 比較は両辺ともコマンド置換で受ける（末尾の改行が落ちるのは両辺同じなので比較が成立する）。
# 末尾改行そのものは下で別に表明する（.claude/rules/shell-script-style.md「テスト」）。
convert_agent_to_reply "$fixtures/agent-comma.md.fixture"
assert_eq "T1: カンマ区切りtoolsのゴールデン比較" \
  "$(cat "$fixtures/agent-comma.md.expected")" "$(printf '%s' "$REPLY")"
comma_out="$REPLY"
# 末尾改行の検証にコマンド置換を使わない（末尾の改行がすべて落ちるため意図どおりにならない。
# .claude/rules/shell-script-style.md「テスト」）。ANSI-Cクォートで直接比べる。
nl=$'\n'
if [ "${comma_out: -1}" = "$nl" ] && [ "${comma_out: -2:1}" != "$nl" ]; then tail_ok=1; else tail_ok=0; fi
assert_eq "T1: 出力は改行1つで終わる" "1" "$tail_ok"

convert_agent_to_reply "$fixtures/agent-flow.md.fixture"
assert_eq "T1: フロー配列tools（クォート付き）のゴールデン比較" \
  "$(cat "$fixtures/agent-flow.md.expected")" "$(printf '%s' "$REPLY")"
flow_out="$REPLY"

# ゴールデン比較だけだと「両方まとめて間違った」ときに気づけないので、症状を直接名指しでも見る。
assert_eq "T4: toolsがYAML配列（キー行だけの行が出る）" "1" \
  "$(printf '%s' "$comma_out" | grep -cx -- 'tools:')"
assert_eq "T4: toolsの要素が - 始まりで並ぶ" "4" \
  "$(printf '%s' "$comma_out" | grep -cE '^  - ')"
assert_eq "T4: カンマ区切りのままの行が残っていない" "0" \
  "$(printf '%s' "$comma_out" | grep -cE '^tools:.*,' || true)"

for key in title type tags keywords model; do
  assert_eq "T5: '${key}' が除去される" "0" \
    "$(printf '%s' "$comma_out" | sed -n '2,/^---$/p' | grep -cE "^${key}:" || true)"
done
assert_eq "T5: ホワイトリスト内の display_name は残る" "1" \
  "$(printf '%s' "$flow_out" | grep -cE '^display_name: ')"

# 本文（frontmatter より後ろ）は1バイトも変えない
assert_eq "T1: 本文はそのまま" \
  "$(sed -n '/^---$/,$p' "$fixtures/agent-comma.md.fixture" | sed -n '2,$p' | sed -n '/^---$/,$p')" \
  "$(printf '%s' "$comma_out" | sed -n '/^---$/,$p' | sed -n '2,$p' | sed -n '/^---$/,$p')"

# =========================================================================
# T3: 未知のツール名でエラーになること
#
# 黙って落とす実装への退行を防ぐ。落とすと、Gemini側のエージェントが必要な権限を失ったまま
# 静かに動く。
# =========================================================================

assert_eq "T3: 表に無いツール名は非0で終了する" "1" \
  "$(status_of convert_agent_to_reply "$fixtures/agent-unknown.md.fixture")"
assert_eq "T3: エラーメッセージにツール名が出る" "1" \
  "$(convert_agent_to_reply "$fixtures/agent-unknown.md.fixture" 2>&1 >/dev/null | grep -c 'NotebookEdit' || true)"

# =========================================================================
# 実データ: 実際の .claude/agents/*.md 全件が変換を通ること
#
# 合成フィクスチャだけで完了としない（.claude/rules/shell-script-style.md「テスト」）。
# =========================================================================

real_agent_failures=0
real_agent_count=0
for f in "$repo_root"/.claude/agents/*.md; do
  [ -f "$f" ] || continue
  real_agent_count=$((real_agent_count + 1))
  convert_agent_to_reply "$f" >/dev/null 2>&1 || real_agent_failures=$((real_agent_failures + 1))
done
assert_eq "実データ: .claude/agents/*.md が1件以上ある" "0" "$((real_agent_count == 0 ? 1 : 0))"
assert_eq "実データ: 実 agents 全件が変換を通る（失敗0件）" "0" "$real_agent_failures"

# =========================================================================
# T9: settings.json のゴールデン比較
#
# ゴールデンは設計（plans/【設計】… の Q3変換表・`if` の変換・`args` の連結規則）と
# 目視で突き合わせたうえで固定している。次の6点が同時に確かめられる。
#   - permissions / autoCompactWindow が落ちること（意図的に変換しない2件）
#   - plansDirectory → general.plan.directory
#   - SessionStart: 全sourceを覆う matcher は省略、部分集合は source ごとに複製
#   - PreToolUse→BeforeTool / PostToolUse→AfterTool、Bash→run_shell_command
#   - `if` を落としたうえで同一内容のエントリを1つへ畳むこと（2→1）
#   - args の連結（波括弧なしの $GEMINI_PROJECT_DIR・こちらではクォートしない）と timeout の秒→ミリ秒
# =========================================================================

assert_eq "T9: settings.json のゴールデン比較" \
  "$(cat "$fixtures/settings-expected.json")" \
  "$(convert_settings "$fixtures/settings-input.json")"

assert_eq "T9: 未知のトップレベルキーは非0で終了する" "1" \
  "$(status_of convert_settings "$fixtures/settings-unknown-key.json")"
assert_eq "T9: エラーメッセージに未知のキー名が出る" "1" \
  "$(convert_settings "$fixtures/settings-unknown-key.json" 2>&1 >/dev/null \
     | grep -c 'brandNewSetting' || true)"

# =========================================================================
# main の結合テスト（使い捨てgitリポジトリ）
#
# 冪等性・--check の終了コード・除外・jq不在時の挙動は main にしか無い。
# 実リポジトリの .gemini/ を書き換えずに済むよう、専用のリポジトリを作って実プロセスで起動する。
# =========================================================================

scratch="$tmp_root/scratch"
mkdir -p "$scratch/.claude/agents" "$scratch/.claude/rules" \
         "$scratch/.claude/docs" "$scratch/.claude/scripts/src"
git -C "$scratch" init -q 2>/dev/null || git -C "$scratch" init >/dev/null 2>&1

# ローカル状態は issue #184 で .claude/ の外（wip/state/）へ出たため、`.claude/` 配下に
# 残る .gitignore 対象の代表として settings.local.json を使う（`-- .claude` の列挙範囲に
# 入るものでなければ、除外されることの確認にならない）。
cat > "$scratch/.gitignore" <<'EOF'
**/index.jsonl
/.claude/settings.local.json
EOF
cp "$fixtures/settings-input.json" "$scratch/.claude/settings.json"
cp "$fixtures/agent-comma.md.fixture" "$scratch/.claude/agents/comma-agent.md"
printf -- '---\ntitle: ルール\ntype: rule\n---\n\n本文\n' > "$scratch/.claude/rules/a.md"
# 除外されるべきもの（生成物とローカル状態）
printf '{"concept_id":"x"}\n' > "$scratch/.claude/docs/index.jsonl"
printf '{"env":{"OTEL_EXPORTER_OTLP_ENDPOINT":"http://127.0.0.1:4318"}}\n' \
  > "$scratch/.claude/settings.local.json"
cp "$target" "$scratch/.claude/scripts/src/sync-gemini-assets.sh"

run_sync() { ( cd "$scratch" && bash .claude/scripts/src/sync-gemini-assets.sh "$@" ); }

assert_eq "main: 生成が成功する" "0" "$(status_of run_sync)"

# --- T8: 除外対象が出力に含まれないこと --------------------------------------
assert_eq "T8: index.jsonl は出力に含まれない" "0" \
  "$(find "$scratch/.gemini" -name index.jsonl | wc -l | tr -d ' ')"
assert_eq "T8: settings.local.json は出力に含まれない" "0" \
  "$(find "$scratch/.gemini" -name 'settings.local.json' | wc -l | tr -d ' ')"
assert_eq "T8: 変換対象の .claude/settings.json はコピーされず生成される" "1" \
  "$(find "$scratch/.gemini" -maxdepth 1 -name settings.json | wc -l | tr -d ' ')"
assert_eq "T8: settings.json は変換後の内容（general.plan.directory を持つ）" "./plans" \
  "$(jq -r '.general.plan.directory' "$scratch/.gemini/settings.json" | tr -d '\r')"
assert_eq "T8: コピー対象（rules）は含まれる" "1" \
  "$(find "$scratch/.gemini/rules" -name 'a.md' | wc -l | tr -d ' ')"

# --- T1（結合）: 生成された agents がゴールデンと一致すること -----------------
assert_eq "T1: 生成された agents がゴールデンと一致" \
  "$(cat "$fixtures/agent-comma.md.expected")" \
  "$(cat "$scratch/.gemini/agents/comma-agent.md")"

# --- T7: --check の終了コード ------------------------------------------------
assert_eq "T7: 生成直後の --check は0" "0" "$(status_of run_sync --check)"

printf '\n' >> "$scratch/.gemini/settings.json"
assert_eq "T7: 食い違いがあれば --check は非0" "1" "$(status_of run_sync --check)"
assert_eq "T7: --dry-run は食い違っていても0で終わる" "0" "$(status_of run_sync --dry-run)"
assert_eq "T7: --dry-run は書き込まない（食い違いが残ったまま）" "1" "$(status_of run_sync --check)"

# --- T6: 冪等性 ---------------------------------------------------------------
run_sync >/dev/null
cp -R "$scratch/.gemini" "$tmp_root/gemini-1"
run_sync >/dev/null
assert_eq "T6: 2回生成しても差分が出ない" "0" \
  "$(status_of diff -r "$tmp_root/gemini-1" "$scratch/.gemini")"
assert_eq "T6: 再生成後の --check は0" "0" "$(status_of run_sync --check)"

# --- T13: 生成物に含まれないファイルは、既定では消さずに中断すること ----------
#
# 再生成は .gemini/ の丸ごと置き換えなので、配布先が自前で置いたファイル
# （.gemini/commands/*.toml 等）が黙って消えうる。既定で中断し、--force のときだけ消す。
printf 'stale\n' > "$scratch/.gemini/stale-file.md"
mkdir -p "$scratch/.gemini/commands"
printf 'name = "mine"\n' > "$scratch/.gemini/commands/mine.toml"

stale_out="$(run_sync 2>&1 || true)"
assert_eq "T13: 生成物に含まれないファイルがあれば非0で終わる" "1" "$(status_of run_sync)"
assert_eq "T13: 中断時に既存ファイルを消さない（stale-file.md）" "1" \
  "$(find "$scratch/.gemini" -name 'stale-file.md' | wc -l | tr -d ' ')"
assert_eq "T13: 中断時に既存ファイルを消さない（commands/mine.toml）" "1" \
  "$(find "$scratch/.gemini" -name 'mine.toml' | wc -l | tr -d ' ')"
assert_eq "T13: エラーメッセージに該当パスが出る" "1" \
  "$(printf '%s' "$stale_out" | grep -cF -- '.gemini/commands/mine.toml' || true)"
assert_eq "T13: エラーメッセージが --force を案内する" "1" \
  "$(printf '%s' "$stale_out" | grep -cF -- '--force' || true)"

# --- T13: --force なら消して再生成すること ------------------------------------
assert_eq "T13: --force なら0で終わる" "0" "$(status_of run_sync --force)"
assert_eq "T13: --force は生成物に無いファイルを消す（stale-file.md）" "0" \
  "$(find "$scratch/.gemini" -name 'stale-file.md' | wc -l | tr -d ' ')"
assert_eq "T13: --force は生成物に無いファイルを消す（commands/mine.toml）" "0" \
  "$(find "$scratch/.gemini" -name 'mine.toml' | wc -l | tr -d ' ')"

# --- T13: 削除されるファイルが無いときは従来どおり素通りすること（--force 不要） ------------
assert_eq "T13: 削除されるファイルが無ければ --force なしで0で終わる" "0" "$(status_of run_sync)"
assert_eq "T13: 削除されるファイルが無ければ再生成後も --check は0" "0" "$(status_of run_sync --check)"

# --- T3（結合）: 未知のツール名があると .gemini/ を書き換えないこと ------------
cp "$fixtures/agent-unknown.md.fixture" "$scratch/.claude/agents/unknown-agent.md"
assert_eq "T3: 未知のツール名があると生成は非0で終わる" "1" "$(status_of run_sync)"
assert_eq "T3: 失敗時に .gemini/ は書き換わらない（古い内容のまま）" "0" \
  "$(find "$scratch/.gemini/agents" -name 'unknown-agent.md' | wc -l | tr -d ' ')"
rm -f "$scratch/.claude/agents/unknown-agent.md"

# --- T10: jq が無いとき非0で終了し、何も生成しないこと ------------------------
#
# PATH を、必要なコマンドだけを張った偽のbinへ差し替える（jq だけ張らない）。
fake_bin="$tmp_root/bin"
mkdir -p "$fake_bin"
for c in bash git find sed grep cp mv rm mkdir mktemp diff xargs printf cat dirname basename sort wc tr; do
  p="$(command -v "$c" 2>/dev/null || true)"
  [ -n "$p" ] && ln -sf "$p" "$fake_bin/$c"
done
rm -rf "$scratch/.gemini"
if ( cd "$scratch" && PATH="$fake_bin" bash .claude/scripts/src/sync-gemini-assets.sh ) >/dev/null 2>&1; then
  nojq_status=0
else
  nojq_status=1
fi
assert_eq "T10: jq が無ければ非0で終了する" "1" "$nojq_status"
assert_eq "T10: jq が無ければ .gemini/ を作らない" "0" \
  "$(find "$scratch" -maxdepth 1 -name '.gemini' | wc -l | tr -d ' ')"
nojq_msg="$( ( cd "$scratch" && PATH="$fake_bin" bash .claude/scripts/src/sync-gemini-assets.sh ) 2>&1 || true )"
assert_eq "T10: エラーメッセージにインストール方法が含まれる" "1" \
  "$(printf '%s' "$nojq_msg" | grep -c 'apt-get install jq' || true)"

# =========================================================================
# T11 / T12: hookスクリプトの前置フィルタ
#
# `.gemini/settings.json` から `if` を落とす代償（空振り起動）を消すためのもの。
# =========================================================================

# shellcheck source=../../hooks/lib/CommandPosition.sh
source "$repo_root/.claude/hooks/lib/CommandPosition.sh"

readonly PREFILTER_LINE='  raw_hints_at_git_push "$raw" || exit 0'
for h in post-push-usage-report post-push-compact-prompt; do
  assert_eq "T11: ${h}.sh が前置フィルタの行を持つ" "1" \
    "$(grep -cFx -- "$PREFILTER_LINE" "$repo_root/.claude/hooks/${h}.sh" || true)"
  assert_eq "T11: ${h}.sh は \$(cat) をやめている（forkする受け口が残っていない）" "0" \
    "$(grep -cF -- 'raw="$(cat)"' "$repo_root/.claude/hooks/${h}.sh" || true)"
  # 判定は純粋関数へ切り出す（`.claude/rules/shell-script-style.md`「hookの前置フィルタ」）。
  # source して直接呼べる形であることが、下の超集合テストの前提でもある。
  assert_eq "T11: ${h}.sh が raw_hints_at_git_push を関数として定義している" "1" \
    "$(grep -cFx -- 'raw_hints_at_git_push() {' "$repo_root/.claude/hooks/${h}.sh" || true)"
done

# **実装そのもの**を source して呼ぶ（テスト側で写経すると、実装が変わっても気づけない）。
# 2本は同じ関数を持つので、片方を読み込めば足りる（同一であることは次で表明する）。
# shellcheck source=../../hooks/post-push-usage-report.sh
source "$repo_root/.claude/hooks/post-push-usage-report.sh"
assert_eq "T11: 2本の raw_hints_at_git_push が同一実装である" \
  "$(sed -n '/^raw_hints_at_git_push() {/,/^}/p' "$repo_root/.claude/hooks/post-push-usage-report.sh")" \
  "$(sed -n '/^raw_hints_at_git_push() {/,/^}/p' "$repo_root/.claude/hooks/post-push-compact-prompt.sh")"

prefilter_passes() {
  raw_hints_at_git_push "$1"
}

# **超集合であること**を確かめる。取りこぼす（精密判定=真なのに前置フィルタ=偽）と、機能が
# 黙って死ぬ。逆（前置フィルタ=真、精密判定=偽）は後段が落とすので無害である。
# `git -C /x push` のように **`git push` が連続しない形**を必ず含める
# （`git[[:space:]]+push` へ縮めると、ここで落ちる）。
superset_violations=0
overmatch_count=0
prefilter_cases=(
  'git push'
  'git push -u origin main'
  'git -C /x push'
  'git --no-pager push origin HEAD'
  'cd /tmp/x && git push -u origin feature-70'
  'git push 2>&1 | tee /tmp/log'
  # バックスラッシュ入り。**JSON化すると `pu\\sh` になり、生JSONへ `*push*` を当てると
  # 取りこぼす**（精密判定はバックスラッシュを落として push と読む）。issue #159 と同型の罠。
  'git pu\sh'
  'git pus\h'
  'git \push'
  # バックスラッシュ＋改行（行継続）。JSON化すると `pu\\\nsh`（バックスラッシュ2つ＋n）に
  # なるため、**バックスラッシュ1文字だけを除去すると `punsh` になって取りこぼす**。
  # 2文字シーケンスをまとめて落とす実装であることを、このケースだけが確かめる。
  $'git pu\\\nsh -u origin main'
  'echo pushkin'
  'git commit -m "x"'
  'ls -la'
  'bash .claude/scripts/src/create-commit.sh --message "chore: 反映"'
)
for cmd in "${prefilter_cases[@]}"; do
  payload="$(jq -nc --arg c "$cmd" '{tool_name: "Bash", tool_input: {command: $c}}')"
  if command_invokes_git_subcommand "$cmd" push; then
    precise=1
  else
    precise=0
  fi
  if prefilter_passes "$payload"; then
    pre=1
  else
    pre=0
  fi
  if [ "$precise" = "1" ] && [ "$pre" = "0" ]; then
    superset_violations=$((superset_violations + 1))
    echo "  取りこぼし: $cmd"
  fi
  [ "$precise" = "0" ] && [ "$pre" = "1" ] && overmatch_count=$((overmatch_count + 1))
done
assert_eq "T11: 前置フィルタは精密判定の超集合（取りこぼし0件）" "0" "$superset_violations"
# 「緩い側へ倒している」ことも表明しておく（0件だと、実は厳しすぎる判定に差し替わっていても
# 上のテストだけでは気づけない）。`echo pushkin` と heredoc 相当がここに入る。
assert_eq "T11: 過検知は存在する（緩い側へ倒している証拠）" "1" \
  "$((overmatch_count > 0 ? 1 : 0))"

# --- T12: 足切りされるペイロードで jq が1回も呼ばれないこと -------------------
#
# 「forkしていない」ことの決定的な検証。時間計測に頼らず、**呼ばれたら分かるスタブ**を置く。
stub_bin="$tmp_root/stub-bin"
mkdir -p "$stub_bin"
marker="$tmp_root/jq-was-called"
cat > "$stub_bin/jq" <<STUB
#!/usr/bin/env bash
echo called >> "$marker"
exit 1
STUB
chmod +x "$stub_bin/jq"

non_push_payload='{"tool_name":"Bash","tool_input":{"command":"ls -la"}}'
for h in post-push-usage-report post-push-compact-prompt; do
  rm -f "$marker"
  if printf '%s' "$non_push_payload" \
      | PATH="$stub_bin:$PATH" bash "$repo_root/.claude/hooks/${h}.sh" >/dev/null 2>&1; then
    hook_status=0
  else
    hook_status=1
  fi
  assert_eq "T12: ${h}.sh は非pushペイロードで0終了する" "0" "$hook_status"
  assert_eq "T12: ${h}.sh は非pushペイロードで jq を1回も呼ばない" "0" \
    "$( [ -f "$marker" ] && wc -l < "$marker" | tr -d ' ' || echo 0 )"
done

# =========================================================================
# T14: CRLF で保存された agents/*.md を誤診しないこと（issue #70 フェーズ4）
#
# `mapfile` は改行だけを区切りにするため、CRLF のファイルでは1行目が `$'---\r'` になり、
# CR を落とさないと「frontmatter がありません」で落ちる。`.gitattributes` の配布行は
# `*.sh` しか eol=lf にしないので、`.md` は配布先の core.autocrlf 次第で CRLF になりうる。
# =========================================================================

crlf_src="$tmp_root/agent-crlf.md"
sed 's/$/\r/' "$fixtures/agent-comma.md.fixture" > "$crlf_src"
assert_eq "T14: フィクスチャが実際にCRLFである" "1" \
  "$( [ "$(wc -c < "$crlf_src")" != "$(tr -d '\r' < "$crlf_src" | wc -c)" ] && echo 1 || echo 0 )"

if convert_agent_to_reply "$crlf_src" >/dev/null 2>&1; then
  crlf_status=0
else
  crlf_status=1
fi
assert_eq "T14: CRLF の agents/*.md でも変換が成功する" "0" "$crlf_status"

convert_agent_to_reply "$crlf_src" >/dev/null 2>&1 || true
# `$(cat …)` は末尾の改行を落とすので、比較する側も同じ形に揃える（`$REPLY` は末尾の改行を持つ）。
assert_eq "T14: CRLF 入力でも出力はゴールデンと一致" \
  "$(cat "$fixtures/agent-comma.md.expected")" "$(printf '%s' "$REPLY")"
# 末尾の改行を落とす比較だけだと、最終行のCRを見逃しうる。バイト数でも表明する。
crlf_reply_file="$tmp_root/agent-crlf.out"
printf '%s' "$REPLY" > "$crlf_reply_file"
assert_eq "T14: 出力にCRが1バイトも残らない" \
  "$(wc -c < "$crlf_reply_file" | tr -d ' ')" \
  "$(tr -d '\r' < "$crlf_reply_file" | wc -c | tr -d ' ')"

# =========================================================================
# T15: Windows ネイティブ jq の CR 付与を再現しても settings.json にCRが混入しないこと
#
# 実機（Windows）が無いので、`sed '$!s/$/\r/'` を通すスタブ jq を PATH 先頭へ置いて再現する
# （.claude/rules/shell-script-style.md「テスト」の手法）。**最終行以外**へCRが付くのが、
# native jq とMSYSのコマンド置換を合わせた実測に一致する形である。
# =========================================================================

crjq_bin="$tmp_root/crjq"
mkdir -p "$crjq_bin"
real_jq="$(command -v jq)"
cat > "$crjq_bin/jq" <<CRJQ
#!/usr/bin/env bash
set -o pipefail
"$real_jq" "\$@" | sed '\$!s/\$/\r/'
CRJQ
chmod +x "$crjq_bin/jq"

rm -rf "$scratch/.gemini"
( cd "$scratch" && PATH="$crjq_bin:$PATH" bash .claude/scripts/src/sync-gemini-assets.sh ) >/dev/null 2>&1
crjq_settings="$scratch/.gemini/settings.json"
assert_eq "T15: スタブ jq 下でも settings.json が生成される" "1" \
  "$( [ -f "$crjq_settings" ] && echo 1 || echo 0 )"
# CRの検査はバイト数の比較で行う（`grep -c $'\r'` は環境により全行にマッチする）。
assert_eq "T15: 生成された settings.json にCRが混入しない" \
  "$(wc -c < "$crjq_settings" | tr -d ' ')" \
  "$(tr -d '\r' < "$crjq_settings" | wc -c | tr -d ' ')"
# スタブが実際にCRを付ける（＝この検査に検出力がある）ことを、同じスタブで表明しておく。
assert_eq "T15: スタブ jq は複数行出力へ実際にCRを付ける" "1" \
  "$( [ "$(PATH="$crjq_bin:$PATH" jq -n '{a:1,b:2}' | wc -c)" \
      != "$(PATH="$crjq_bin:$PATH" jq -n '{a:1,b:2}' | tr -d '\r' | wc -c)" ] && echo 1 || echo 0 )"
run_sync >/dev/null 2>&1

# =========================================================================
# T16: .gitignore にあるローカル設定が .gemini/ へ焼き込まれないこと
#
# 列挙が `--others` を含むため、未追跡ファイルもコピー対象になる。除外は .gitignore に
# 委ねている（COPY_EXCLUDED_PREFIXES へは足さない）ので、その委譲が効いていることを固定する。
# =========================================================================

printf '{"env":{"OTEL_EXPORTER_OTLP_ENDPOINT":"http://127.0.0.1:4318"}}\n' \
  > "$scratch/.claude/settings.local.json"
printf 'untracked\n' > "$scratch/.claude/rules/untracked.md"
printf '/.claude/settings.local.json\n' >> "$scratch/.gitignore"
run_sync >/dev/null 2>&1
assert_eq "T16: .gitignore にある settings.local.json は .gemini/ へ出ない" "0" \
  "$(find "$scratch/.gemini" -name 'settings.local.json' | wc -l | tr -d ' ')"
# 「除外できている」だけでは、そもそも未追跡が全部落ちているのか区別できない。
# 未追跡でも ignore されていないファイルは載ることを併せて表明する（--others の意図した挙動）。
assert_eq "T16: ignore されていない未追跡ファイルは .gemini/ へ載る（--others の意図）" "1" \
  "$(find "$scratch/.gemini" -name 'untracked.md' | wc -l | tr -d ' ')"
# 後片付け。untracked.md を消すと .gemini/ 側が「生成物に含まれないファイル」になるため、
# ここは --force で戻す（削除ファイル検出が意図どおり働いていることの裏返しでもある）。
rm -f "$scratch/.claude/settings.local.json" "$scratch/.claude/rules/untracked.md"
assert_eq "T16: 元ファイルを消すと .gemini/ 側が削除対象として検出される（--force なしは非0）" "1" \
  "$(status_of run_sync)"
run_sync --force >/dev/null 2>&1

# =========================================================================
# T17: 0件判定は「コピー対象0件」ではなく「列挙0件」であること
#
# agents/*.md と settings.json は変換で作るので、その2つしか無い .claude/ でも生成物として
# 成立する。以前は「コピー対象0件」を失敗条件にしていたため、この構成が誤って落ちていた。
# **契約の変更なので、テストの期待値もここで置き換えている。**
# =========================================================================

minimal="$tmp_root/minimal"
mkdir -p "$minimal/.claude/agents"
git -C "$minimal" init -q 2>/dev/null || git -C "$minimal" init >/dev/null 2>&1
cp "$fixtures/settings-input.json" "$minimal/.claude/settings.json"
cp "$fixtures/agent-comma.md.fixture" "$minimal/.claude/agents/comma-agent.md"
run_minimal() { ( cd "$minimal" && bash "$target" "$@" ); }
assert_eq "T17: agents と settings.json しか無くても生成は成功する" "0" "$(status_of run_minimal)"
assert_eq "T17: その場合も agents は変換されて出力される" "1" \
  "$(find "$minimal/.gemini/agents" -name 'comma-agent.md' | wc -l | tr -d ' ')"
assert_eq "T17: その場合も settings.json は生成される" "1" \
  "$(find "$minimal/.gemini" -maxdepth 1 -name 'settings.json' | wc -l | tr -d ' ')"

# --- T17: .claude/ が無ければ原因を名指しして落ちること -----------------------
noclaude="$tmp_root/noclaude"
mkdir -p "$noclaude"
git -C "$noclaude" init -q 2>/dev/null || git -C "$noclaude" init >/dev/null 2>&1
printf 'x\n' > "$noclaude/README.md"
run_noclaude() { ( cd "$noclaude" && bash "$target" "$@" ); }
assert_eq "T17: .claude/ が無ければ非0で終わる" "1" "$(status_of run_noclaude)"
noclaude_msg="$( run_noclaude 2>&1 || true )"
assert_eq "T17: .claude/ が無いことをメッセージが名指しする" "1" \
  "$(printf '%s' "$noclaude_msg" | grep -cF -- 'このリポジトリに .claude/ がありません' || true)"

# --- T17: 全ファイルが ignore されていれば、その原因を案内すること -------------
allignored="$tmp_root/allignored"
mkdir -p "$allignored/.claude/rules"
git -C "$allignored" init -q 2>/dev/null || git -C "$allignored" init >/dev/null 2>&1
printf -- '---\ntitle: x\n---\n' > "$allignored/.claude/rules/a.md"
printf '/.claude/\n' > "$allignored/.gitignore"
run_allignored() { ( cd "$allignored" && bash "$target" "$@" ); }
assert_eq "T17: 全ファイルが ignore されていれば非0で終わる" "1" "$(status_of run_allignored)"
allignored_msg="$( run_allignored 2>&1 || true )"
assert_eq "T17: ignore が原因であることを check-ignore で案内する" "1" \
  "$(printf '%s' "$allignored_msg" | grep -cF -- 'git check-ignore -v' || true)"

# =========================================================================
# T18: 列挙の失敗を「0件」として握りつぶさないこと（issue #26）
#
# `while … done < <(cmd)` というプロセス置換の終了コードは、**どこからも見えない**
# （`set -e` も `pipefail` も届かない）。この形で書かれていた2箇所は、外部コマンドが
# 失敗すると「対象は0件」という誤った結論になっていた。とくに削除ガードの側は、
# **配布先が自前で置いた .gemini/ のファイルを、終了コード0のまま消していた**
# （issue #70 のレビュー指摘が入れた歯止めが、そのまま外れる）。
#
# `【実装反映】` で setup-gemini-links.sh に直したのと同じ「失敗が成功として報告される」
# 類型で、同じ `run_or_fail` の形で直している。**修正前の実装では下の4件が落ちる**
# （実際に修正前へ戻して確認済み）。
# =========================================================================

# PATH の先頭へ置くと、その外部コマンドだけが必ず失敗するスタブ。
make_failing_stub() { # $1=ディレクトリ $2=コマンド名
  mkdir -p "$1"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$1/$2"
  chmod +x "$1/$2"
}

guard="$tmp_root/guard"
mkdir -p "$guard/.claude/agents"
git -C "$guard" init -q 2>/dev/null || git -C "$guard" init >/dev/null 2>&1
cp "$fixtures/settings-input.json" "$guard/.claude/settings.json"
cp "$fixtures/agent-comma.md.fixture" "$guard/.claude/agents/comma-agent.md"
run_guard() { ( cd "$guard" && bash "$target" "$@" ); }
run_guard >/dev/null

# 配布先が自前で置いたファイル（削除ガードが守るべきもの）
mkdir -p "$guard/.gemini/commands"
printf 'name = "mine"\n' > "$guard/.gemini/commands/mine.toml"

make_failing_stub "$tmp_root/stub-find" find
run_guard_nofind() { ( cd "$guard" && PATH="$tmp_root/stub-find:$PATH" bash "$target" "$@" ); }

assert_eq "T18: .gemini/ の走査が失敗したら非0で終わる" "1" "$(status_of run_guard_nofind)"
assert_eq "T18: 走査が失敗しても配布先の自前ファイルを消さない" "1" \
  "$(find "$guard/.gemini/commands" -name 'mine.toml' | wc -l | tr -d ' ')"
guard_msg="$( run_guard_nofind 2>&1 || true )"
assert_eq "T18: 走査の失敗を原因として名指しする" "1" \
  "$(printf '%s' "$guard_msg" | grep -cF -- '.gemini/ の走査に失敗しました' || true)"

# --- T18: .claude/ 側の列挙が失敗したときも、原因を取り違えないこと ------------
#
# 以前は git ls-files の失敗が「列挙0件」と区別できず、`.gitignore` が .claude/ を丸ごと
# 除外している、という**誤った案内**を出していた（原因が2つあるのに分岐が1つしか無い）。
mkdir -p "$tmp_root/stub-git"
cat > "$tmp_root/stub-git/git" <<'STUBEOF'
#!/usr/bin/env bash
# ls-files だけを失敗させ、他のサブコマンドは実物へ通す
case " $* " in *' ls-files '*) exit 1 ;; esac
exec "$REAL_GIT" "$@"
STUBEOF
chmod +x "$tmp_root/stub-git/git"
real_git="$(command -v git)"
run_guard_nogit() { ( cd "$guard" && REAL_GIT="$real_git" PATH="$tmp_root/stub-git:$PATH" bash "$target" "$@" ); }

assert_eq "T18: .claude/ の列挙が失敗したら非0で終わる" "1" "$(status_of run_guard_nogit)"
nogit_msg="$( run_guard_nogit 2>&1 || true )"
assert_eq "T18: 列挙の失敗を原因として名指しする" "1" \
  "$(printf '%s' "$nogit_msg" | grep -cF -- '.claude/ 配下のファイル列挙に失敗しました' || true)"
assert_eq "T18: 列挙の失敗を .gitignore のせいにしない" "0" \
  "$(printf '%s' "$nogit_msg" | grep -cF -- 'git check-ignore -v' || true)"

# --- T18: 読めない agents/*.md を「frontmatter がありません」と誤診しないこと ---
#
# convert_agent_to_reply は `|| return 1` の形で呼ばれるため、関数の内部では `set -e` が
# 一時停止している。mapfile の失敗が止められず、空の配列のまま次の判定へ落ちて
# **実際とは違う原因**を報告していた。
assert_eq "T18: 存在しない agents/*.md は非0" "1" \
  "$(status_of convert_agent_to_reply "$tmp_root/no-such-agent.md")"
missing_msg="$( convert_agent_to_reply "$tmp_root/no-such-agent.md" 2>&1 || true )"
assert_eq "T18: 読めないことを名指しする（frontmatter のせいにしない）" "1" \
  "$(printf '%s' "$missing_msg" | grep -cF -- '読み取れません' || true)"

echo "passed=$passed failures=$failures"
[ "$failures" -eq 0 ]
