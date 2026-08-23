#!/usr/bin/env bash
#
# .gemini/ を .claude/ からの変換生成物として再生成する（issue #70）。
#
# .gemini/ は「手で書く実体」ではなく「.claude/ から機械的に決まる生成物」である。
# 編集は必ず .claude/ 側に対して行い、このスクリプトを流し直すこと。
#
# **生成物に含まれないファイルが .gemini/ にあると、既定では書き込まずにエラーで止まる。**
# 再生成は .gemini/ の丸ごと置き換えなので、そのままでは手で置いたファイルが黙って消える
# （配布先が自前の .gemini/commands/*.toml や settings.json を持っている場合が該当する）。
# 消してよいと分かっている場合だけ --force を付ける。
#
# 使い方:
#     bash .claude/scripts/src/sync-gemini-assets.sh [--check] [--dry-run] [--force]
#
#     （引数なし） .gemini/ を再生成する（生成物に含まれないファイルがあれば中断する）
#     --check      生成せず、一時ディレクトリへ生成して .gemini/ と突き合わせる。
#                  食い違えば非0で終了する（CI・手動確認用。どのhookにも自動では挿さない）
#     --dry-run    何が変わるかだけを出力する（常に終了コード0）
#     --force      生成物に含まれないファイルを削除して再生成する（中断しない）
#
# 規約: .claude/rules/shell-script-style.md
#   （set -euo pipefail / jq前提 / ループ内で外部コマンドを呼ばない）
# 仕様: .claude/docs/spec/sync-gemini-assets.md

set -euo pipefail

# ---------------------------------------------------------------------------
# ツール名の対応表（Claude Code → Gemini CLI）
#
# 出典: gemini-cli の packages/core/src/tools/definitions/base-declarations.ts と
#       packages/core/src/tools/tool-names.ts（ALL_BUILTIN_TOOL_NAMES）。
# agents の `tools` と、settings の hook `matcher` の両方でこの1つの表を使う
# （2箇所に別の表を持つと、片方だけが古くなる）。
#
# **この表に無いツール名が現れたら、黙って落とさずエラーにする。** 落とすと、Gemini側の
# エージェントが必要な権限を失ったまま静かに動く（調査結果 Q1）。
# ---------------------------------------------------------------------------
readonly GEMINI_TOOL_PAIRS=(
  Read read_file
  Grep grep_search
  Glob glob
  Bash run_shell_command
  Write write_file
  Edit replace
  LS list_directory
  WebFetch web_fetch
  WebSearch google_web_search
  TodoWrite write_todos
  Task invoke_agent
)

# agents の frontmatter で Gemini 側へ通すキー（ホワイトリスト）。
#
# 出典: gemini-cli の packages/core/src/agents/agentLoader.ts の localAgentSchema。
# **`.strict()` が付いているため、未知のキーが1つでも残るとロードが失敗する。**
# したがって「既知の不要キーを除く」ブラックリストにはできない
# （.claude/rules/markdown-frontmatter.md にキーが1つ増えるたびに Gemini 側が壊れる）。
#
# `model` はスキーマ上は通るが、Claude側の値（sonnet / opus）は Gemini のモデル名ではない。
# 弾かれないぶん危ないので**除去する**（除去すれば既定の `inherit` になる。調査結果 Q1）。
readonly GEMINI_AGENT_KEYS=(
  kind
  name
  display_name
  description
  tools
  mcp_servers
  temperature
  max_turns
  timeout_mins
)

# .claude/settings.json のトップレベルキーのうち、**意図的に変換しないもの**。
# ここに無く、かつ変換もされないキーが現れたらエラーにする（下記 convert_settings）。
#
#   permissions      … Gemini の相当機能は policy engine（.gemini/policies/*.toml）だが、
#                       プロジェクト単位の Workspace 層が現在無効のため、リポジトリへ置いても
#                       効果がゼロである（docs/reference/policy-engine.md の
#                       "(Currently disabled)"、upstream issue #18186）。
#                       **対応漏れではない。** Workspace 層が有効化されたら見直す。
#   autoCompactWindow … Gemini の model.compressionThreshold は「コンテキスト使用率の分数」
#                       （既定 0.5）であり、絶対値である Claude 側の値とは換算できない。
#   env              … Gemini CLI の settings.json に「プロセス環境変数を注入する」ブロックは
#                       無い（環境変数は .env ファイルから読む。settings 側にあるのは
#                       advanced.excludedEnvVars という除外リストだけ）。**構造として変換先が
#                       無い。** また現在の中身は issue #103 のOTel配線で、
#                       CLAUDE_CODE_ENABLE_TELEMETRY を筆頭に Claude Code 固有である。
#                       Gemini には telemetry ブロックがあるが、受け口
#                       （.claude/hooks/otel/listener.pl）が Claude Code のOTelスキーマを前提に
#                       振り分けるため、そこへGemini由来のテレメトリを流すと壊れる。
#                       **envブロックの変換は行わない。** ただし telemetry ブロックは
#                       envとは別に固定値で注入する（issue #105。下記 SETTINGS_JQ_FILTER の
#                       出力オブジェクト構築部分を参照）。target は "local" 固定で outfile へ
#                       直接ファイル書き込みするため、listener.pl（OTLPネットワーク受信）は
#                       経由しない。
readonly SETTINGS_IGNORED_KEYS=(
  permissions
  autoCompactWindow
  env
)

# Gemini CLI公式テレメトリ（issue #105）の出力先。`.claude/hooks/lib/UsageTracking.sh` の
# 読み取り側（`_usage_otel_resolve_outfile_to_reply`）と共有する唯一の正。ここを変えると
# 読み取り側は`.gemini/settings.json`の`telemetry.outfile`を動的に読むため自動的に追随する
# （読み取り側にもハードコードした2つ目の正を持たない。issue #105フェーズ3敵対的レビュー指摘）。
readonly GEMINI_OTEL_OUTFILE_REL="usage/gemini-otel.log"

# 変換して生成するため、コピー対象から外すパス（リポジトリルートからの相対）。
readonly COPY_EXCLUDED_PREFIXES=(
  '.claude/settings.json'
)

# ---------------------------------------------------------------------------
# 前提チェック
# ---------------------------------------------------------------------------

# jq が無ければ、何も書き込まずに非0で終了する。
#
# **「生成をスキップして警告」にしない。** jq は .gemini/ だけの前提ではなく .claude/ 機構全体の
# 前提であり（Provider.sh・extract-frontmatter.sh・hookが依存）、無ければどのみち動かない。
# スキップは「インストールが成功した」という嘘の結果を返すことになる。
# コマンドを実行し、失敗したら説明を添えて非0で返す。
#
# **`set -e` は条件式（`if`・`||`・`&&`）の中では一時停止し、その一時停止はそこで呼ばれる
# 関数の内部にまで及ぶ**（`.claude/rules/shell-script-style.md`「bashでのtry/catch相当の
# 書き方」）。さらに**プロセス置換 `< <(cmd)` の終了コードは、どこからも見えない**。
# どちらの形で書いても、失敗した事実が呼び出し元へ伝わらないまま処理が続き、
# **失敗が成功として報告される**。外部コマンドの失敗を確実に検知したい箇所はこれを通す
# （`install-to-project.sh` / `setup-gemini-links.sh` と同じ形。issue #26）。
run_or_fail() {
  local desc="$1"
  shift
  if ! "$@"; then
    echo "エラー: ${desc}に失敗しました（コマンド: $*）" >&2
    return 1
  fi
}

require_jq() {
  if command -v jq >/dev/null 2>&1; then
    return 0
  fi
  cat >&2 <<'MSG'
エラー: jq が見つかりません。

このリポジトリの .claude/ 機構は jq を前提にしています（Provider.sh・extract-frontmatter.sh・
各hookが依存しており、jq が無いと .gemini/ の生成以前に機構全体が動きません）。

インストール方法:
  Debian / Ubuntu : sudo apt-get install jq
  RHEL / Fedora   : sudo dnf install jq
  macOS           : brew install jq
  Windows         : winget install jqlang.jq   （または https://jqlang.github.io/jq/download/ ）

インストール後、もう一度このコマンドを実行してください。
MSG
  return 1
}

# ---------------------------------------------------------------------------
# 小さなヘルパー（ホットパスなので REPLY へ返す。コマンド置換でforkしない）
# ---------------------------------------------------------------------------

trim_to_reply() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  REPLY="$s"
}

# 前後のクォートを1組だけ外す。
unquote_to_reply() {
  local s="$1"
  case "$s" in
    \"*\") s="${s#\"}"; s="${s%\"}" ;;
    \'*\') s="${s#\'}"; s="${s%\'}" ;;
  esac
  REPLY="$s"
}

# ---------------------------------------------------------------------------
# agents の変換
# ---------------------------------------------------------------------------

# ツール名1つを Gemini の名前へ変換し REPLY へ返す。表に無ければ非0。
map_tool_name_to_reply() {
  local want="$1" i
  for ((i = 0; i < ${#GEMINI_TOOL_PAIRS[@]}; i += 2)); do
    if [ "${GEMINI_TOOL_PAIRS[i]}" = "$want" ]; then
      REPLY="${GEMINI_TOOL_PAIRS[i + 1]}"
      return 0
    fi
  done
  REPLY=''
  return 1
}

# 与えられたキーが agents のホワイトリストに含まれるか。
is_gemini_agent_key() {
  local want="$1" k
  for k in "${GEMINI_AGENT_KEYS[@]}"; do
    [ "$k" = "$want" ] && return 0
  done
  return 1
}

# `.claude/agents/<name>.md` を Gemini 用へ変換し、REPLY へ全文を返す。
#
# 変換は3つ:
#   1. frontmatter を GEMINI_AGENT_KEYS のホワイトリストで絞る（.strict() 対策）
#   2. `tools` のカンマ区切り文字列を **YAML配列** へ直し、ツール名を対応表で変換する
#   3. `model` を除去する
# 本文（frontmatter より後ろ）は一切変更しない。
convert_agent_to_reply() {
  local src="$1"
  local -a lines=()
  local -a out=()
  local i line key value

  # 読めないファイルを「frontmatter がありません」と誤診しない。この関数は `|| return 1` の
  # 形でも呼ばれうるため、`mapfile` の失敗を `set -e` に頼れない（上の run_or_fail の注記）。
  if [ ! -r "$src" ]; then
    echo "エラー: 読み取れません: $src" >&2
    return 1
  fi
  mapfile -t lines < "$src"
  # CRLF で保存された .md を「frontmatter がありません」と誤診しないよう、行末の CR を落とす。
  # `mapfile` は改行だけを区切りにするため、CRLF のファイルでは 1 行目が `$'---\r'` になり、
  # 下の `!= '---'` に引っかかる。パラメータ展開は bash 組み込みなので fork は増えない。
  for ((i = 0; i < ${#lines[@]}; i++)); do lines[i]="${lines[i]%$'\r'}"; done

  if [ "${#lines[@]}" -eq 0 ] || [ "${lines[0]}" != '---' ]; then
    echo "エラー: frontmatter がありません: $src" >&2
    return 1
  fi

  # 終端の `---` を探す
  local fm_end=-1
  for ((i = 1; i < ${#lines[@]}; i++)); do
    if [ "${lines[i]}" = '---' ]; then
      fm_end=$i
      break
    fi
  done
  if [ "$fm_end" -lt 0 ]; then
    echo "エラー: frontmatter の終端 '---' が見つかりません: $src" >&2
    return 1
  fi

  # --- frontmatter を組み立てる（キーの並びは GEMINI_AGENT_KEYS の順に固定する。
  #     入力の並びに追随させると、.claude 側の並べ替えだけで .gemini 側に差分が出る） ---
  local -A kept=()
  local last_key=''
  for ((i = 1; i < fm_end; i++)); do
    line="${lines[i]}"
    [ -n "$line" ] || continue

    case "$line" in
      [[:space:]]*)
        # インデント行。ホワイトリスト対象キーのネスト値は未対応なので明示的に落とす
        # （黙って捨てると、Gemini側が必要な設定を失ったまま静かに動く）。
        if [ -n "$last_key" ] && is_gemini_agent_key "$last_key"; then
          echo "エラー: '$last_key' の複数行・ネストした値には未対応です: $src" >&2
          return 1
        fi
        continue
        ;;
    esac

    key="${line%%:*}"
    if [ "$key" = "$line" ]; then
      echo "エラー: frontmatter として解釈できない行があります: $src: $line" >&2
      return 1
    fi
    value="${line#*:}"
    trim_to_reply "$value"
    value="$REPLY"
    last_key="$key"

    is_gemini_agent_key "$key" || continue
    kept["$key"]="$value"
  done

  if [ -z "${kept[name]:-}" ] || [ -z "${kept[description]:-}" ]; then
    echo "エラー: 'name' と 'description' は必須です: $src" >&2
    return 1
  fi

  out+=('---')
  for key in "${GEMINI_AGENT_KEYS[@]}"; do
    [ -n "${kept[$key]:-}" ] || continue
    if [ "$key" = 'tools' ]; then
      local tools_raw="${kept[tools]}"
      # YAMLのフロー配列記法（[a, b]）でもカンマ区切り文字列でも同じ扱いにする
      case "$tools_raw" in
        \[*\]) tools_raw="${tools_raw#\[}"; tools_raw="${tools_raw%\]}" ;;
      esac
      out+=('tools:')
      local part
      # IFS を触らずにカンマで分ける（IFS の退避・復元を誤ると、以降の行の解釈まで変わる）。
      while IFS= read -r part; do
        trim_to_reply "$part"
        unquote_to_reply "$REPLY"
        trim_to_reply "$REPLY"
        [ -n "$REPLY" ] || continue
        # 名前を退避してから引く。map_tool_name_to_reply は失敗時に REPLY を空にするため、
        # そのまま参照するとエラーメッセージからツール名が消える。
        local claude_tool="$REPLY"
        if ! map_tool_name_to_reply "$claude_tool"; then
          echo "エラー: 未知のツール名 '$claude_tool' です: $src" >&2
          echo "  .claude/scripts/src/sync-gemini-assets.sh の GEMINI_TOOL_PAIRS へ" >&2
          echo "  Gemini 側の名前を追加してください（黙って落とすと権限を失ったまま静かに動きます）。" >&2
          return 1
        fi
        out+=("  - $REPLY")
      done <<< "${tools_raw//,/$'\n'}"
    else
      out+=("${key}: ${kept[$key]}")
    fi
  done
  out+=('---')

  # --- 本文はそのまま ---
  for ((i = fm_end + 1; i < ${#lines[@]}; i++)); do
    out+=("${lines[i]}")
  done

  printf -v REPLY '%s\n' "${out[@]}"
}

# ---------------------------------------------------------------------------
# settings.json の変換
# ---------------------------------------------------------------------------

# jq フィルタ。引数:
#   $toolMap  ツール名の対応表（Claude名 → Gemini名）
#   $ignored  意図的に変換しないトップレベルキーの配列
#
# **サイズが固定・小さいものだけを --argjson で渡す**
# （.claude/rules/shell-script-style.md「大きなJSONを引数としてjqへ渡さない」）。
readonly SETTINGS_JQ_FILTER='
# Gemini の SessionStart が取りうる source（docs/hooks/reference.md）。
# Claude の "compact" に相当するものは無い。
def session_sources: ["startup", "resume", "clear"];

# 順序を保った重複排除（unique はソートしてしまう）。
def dedupe: reduce .[] as $x ([]; if (index([$x]) == null) then . + [$x] else . end);

def map_tool: $toolMap[.] // .;

# hook 1件を Gemini の CommandHookConfig へ変換する。
#   - `if` は出力しない（Gemini に無い）。代償は .claude/hooks/*.sh 側の前置フィルタが払う
#   - `command` + `args[]` を半角スペースで連結する。**こちらではクォートしない**
#     （Gemini 側が escapeShellArg で代入前にクォート済み。hookRunner.ts L519/L527）
#   - `${CLAUDE_PROJECT_DIR}` → `$GEMINI_PROJECT_DIR`。**波括弧を付けない**
#     （置換の正規表現 /\$GEMINI_PROJECT_DIR/g は波括弧形式に一致しない）
#   - timeout は秒 → ミリ秒
#   - パス部分は書き換えない（.claude/hooks/ のまま）。同期を忘れても両経路が同じ
#     スクリプトを実行するようにするため
def conv_hook:
  ([.command] + (.args // []))                        as $parts
  | ($parts | join(" ") | gsub("\\$\\{CLAUDE_PROJECT_DIR\\}"; "$GEMINI_PROJECT_DIR")) as $cmd
  | (($parts | last) | split("/") | last | sub("\\.sh$"; ""))                         as $name
  | {
      name: $name,
      type: (.type // "command"),
      command: $cmd,
      timeout: ((.timeout // 60) * 1000)
    };

# matcher はツール名に対する正規表現。縦棒区切りの各要素を対応表で変換する。
# 表に無い要素（PowerShell / mcp__github__* 等）はそのまま残す
# （一致しない要素は正規表現として無害。推測で書き換えると黙って壊れる）。
def conv_tool_matcher:
  split("|") | map(map_tool) | dedupe | join("|");

# ライフサイクル系（SessionStart）の matcher は**完全一致**で判定される
# （hookPlanner.ts の matchesContext）。縦棒つなぎはどの source にも一致せず、
# hook が一度も発火しない。したがって:
#   - Gemini に無い値（compact）は捨てる
#   - 残りが全 source を覆うなら matcher を落とす（!matcher は無条件 true）
#   - 部分集合なら source ごとにグループを複製する
def conv_session_group:
  . as $g
  | (($g.matcher // "") | if . == "" then session_sources else split("|") end)
  | map(select(. as $m | session_sources | index($m) != null))
  | dedupe
  | if length == 0 then
      error("SessionStart の matcher が Gemini の source に1つも一致しません: " + ($g.matcher // ""))
    elif (length == (session_sources | length)) then
      [ { hooks: ($g.hooks | map(conv_hook) | dedupe) } ]
    else
      map({ matcher: ., hooks: ($g.hooks | map(conv_hook) | dedupe) })
    end;

def conv_tool_group:
  { matcher: (.matcher | conv_tool_matcher), hooks: (.hooks | map(conv_hook) | dedupe) };

# --- 未知のトップレベルキーを検出する ---
# 黙って落とすと「変換が情報を落としていること」を単体テストが永久に緑で通す。
( ["plansDirectory", "hooks"] + $ignored ) as $known
| ( (keys_unsorted - $known) ) as $unknown
| if ($unknown | length) > 0 then
    error("未知のトップレベルキーです: " + ($unknown | join(", "))
      + "。sync-gemini-assets.sh の用語変換規則へ追加するか、SETTINGS_IGNORED_KEYS へ理由付きで加えてください")
  else . end
| ( (.hooks.SessionStart // []) | map(conv_session_group) | add // [] ) as $sessionStart
| ( (.hooks.PreToolUse   // []) | map(conv_tool_group) )                as $beforeTool
| ( (.hooks.PostToolUse  // []) | map(conv_tool_group) )                as $afterTool
| ( ((.hooks | keys_unsorted) - ["SessionStart", "PreToolUse", "PostToolUse"]) ) as $unknownEvents
| if ($unknownEvents | length) > 0 then
    error("未知の hook イベントです: " + ($unknownEvents | join(", ")))
  else . end
| {
    general: (if has("plansDirectory") then { plan: { directory: .plansDirectory } } else empty end)
  }
  + {
    hooks: (
      {}
      + (if ($sessionStart | length) > 0 then { SessionStart: $sessionStart } else {} end)
      + (if ($beforeTool   | length) > 0 then { BeforeTool:   $beforeTool   } else {} end)
      + (if ($afterTool    | length) > 0 then { AfterTool:    $afterTool    } else {} end)
    )
  }
  # Gemini CLI公式テレメトリ（issue #105）。.claude/settings.json 側には対応するキーが無く、
  # ここでは常に固定値を注入する（.claude/settings.json の値を変換するのではない）。
  #
  # enabled は false 固定。**現時点でこれをtrueへ切り替える手段は存在しない**
  # （.claude/settings.json側に対応するスイッチが無く変換元を持たないため、かつ
  # .gemini/settings.jsonを手で書き換えても次回の`sync-gemini-assets.sh`実行で**無言で**falseへ
  # 戻る。`--check`はこのフロー上どのhookにも自動では挿さっていないため、この上書きに気づく
  # 仕組みも無い）。有効化手段の確立（.claude/settings.json側にスイッチを設ける等）は本issueの
  # スコープ外の未決定事項とする（issue #105フェーズ4で.claude/docs/spec/gemini-cli-telemetry.md・
  # DDR i0105-02へ記録済み）。
  + {
    telemetry: {
      enabled: false,
      target: "local",
      outfile: $otelOutfile,
      logPrompts: false
    }
  }
'

# `.claude/settings.json` を Gemini 用へ変換して標準出力へ書く。
convert_settings() {
  local src="$1" tool_map_json ignored_json

  tool_map_json="$(jq -nc --args '
    $ARGS.positional
    | [ range(0; length; 2) as $i | { key: .[$i], value: .[$i + 1] } ]
    | from_entries' -- "${GEMINI_TOOL_PAIRS[@]}")"
  ignored_json="$(jq -nc --args '$ARGS.positional' -- "${SETTINGS_IGNORED_KEYS[@]}")"

  jq --argjson toolMap "$tool_map_json" \
     --argjson ignored "$ignored_json" \
     --arg otelOutfile "$GEMINI_OTEL_OUTFILE_REL" \
     "$SETTINGS_JQ_FILTER" "$src"
}

# ---------------------------------------------------------------------------
# 生成本体
# ---------------------------------------------------------------------------

# コピー対象かどうか（変換で作るものを除く）。
is_copy_excluded() {
  local rel="$1" p
  case "$rel" in
    .claude/agents/*.md) return 0 ;;
  esac
  for p in "${COPY_EXCLUDED_PREFIXES[@]}"; do
    [ "$rel" = "$p" ] && return 0
  done
  return 1
}

# `.claude/` 一式を $1 のディレクトリへ生成する（$1 は空であること）。
build_into() {
  local dst="$1"
  local work="$2"
  local -a copy_rel=()
  local -a agent_rel=()
  local f rel skipped=0 listed=0

  # **列挙をプロセス置換 `< <(git ls-files …)` で受けない。** その終了コードはどこからも
  # 見えないため、git が失敗すると「1件も無い」と読み替えられ、下の 0 件判定が
  # `.gitignore` を原因として名指しする誤った案内を出す（issue #26）。
  run_or_fail '.claude/ 配下のファイル列挙' \
    git -c core.quotepath=false ls-files --cached --others --exclude-standard -z -- .claude \
    > "$work/claude-files.list" || return 1

  # 列挙は git に任せる。`--exclude-standard` が .gitignore 対象（**/index.jsonl・
  # .claude/state/ ・skills/apply-.../assets/）を落とすので、生成物とローカル状態の除外は
  # これだけで足りる（git check-ignore をファイルごとに呼ぶ必要はない）。
  while IFS= read -r -d '' f; do
    # `--cached` は「削除したがまだステージしていない」追跡ファイルも列挙する。
    # 実体が無いまま cp へ渡すと落ちる（issue #117 と同じ罠）。[[ ]] は組み込みでforkしない。
    if [[ ! -f "$f" ]]; then
      skipped=$((skipped + 1))
      continue
    fi
    listed=$((listed + 1))
    rel="$f"
    case "$rel" in
      .claude/agents/*.md) agent_rel+=("$rel"); continue ;;
    esac
    is_copy_excluded "$rel" && continue
    copy_rel+=("${rel#.claude/}")
  done < "$work/claude-files.list"

  if [ "$skipped" -gt 0 ]; then
    echo "skipped $skipped deleted file(s) not present in the working tree" >&2
  fi
  # 失敗条件は「git が .claude/ 配下のファイルを1件も返さなかった」ことである。
  # **「コピー対象（copy_rel）が0件」を失敗条件にしない。** agents/*.md と settings.json は
  # コピーではなく変換で作るため、その2つしか無い .claude/ でも生成物としては成立する。
  if [ "$listed" -eq 0 ]; then
    # `main` が `git rev-parse --show-toplevel` へ cd 済みなので、ここへ来た時点で
    # 「リポジトリルートに居ない」は原因から外れる。残る原因を切り分けて示す。
    if [ ! -d .claude ]; then
      echo "エラー: このリポジトリに .claude/ がありません（リポジトリルート: $PWD）。" >&2
      echo "  issue駆動MRワークフローが導入されていないリポジトリと思われます" >&2
    elif [ "$skipped" -gt 0 ]; then
      echo "エラー: .claude/ 配下の追跡ファイル $skipped 件が、すべて作業ツリーに存在しません。" >&2
      echo "  削除をステージしていない状態と思われます。git status で確認してください" >&2
    else
      echo "エラー: .claude/ は存在しますが、git から見えるファイルが1件もありません。" >&2
      echo "  .gitignore が .claude/ 配下を丸ごと除外している可能性があります。次で確認できます:" >&2
      echo "    git check-ignore -v .claude/settings.json" >&2
    fi
    return 1
  fi

  mkdir -p "$dst"

  # --- コピー ---
  # ファイルごとに cp を呼ばない（148件 × 約95ms = 十数秒になる）。xargs が引数長の上限に
  # 応じて自動で分割するので、`.claude/` が大きくなっても Argument list too long にならない。
  # `cp --parents` は相対パスの階層を再現するため、コピー元へ cd した実サブシェルで実行する。
  # copy_rel が空になりうる（agents/*.md と settings.json しか無い .claude/）。
  # set -u 配下では空配列の "${arr[@]}" が unbound になる bash があるため、件数で守る。
  if [ "${#copy_rel[@]}" -gt 0 ]; then
    ( cd .claude && printf '%s\0' "${copy_rel[@]}" | xargs -0 cp --parents -t "$dst" -- )
  fi

  # --- agents の変換 ---
  mkdir -p "$dst/agents"
  for rel in ${agent_rel[@]+"${agent_rel[@]}"}; do
    convert_agent_to_reply "$rel" || return 1
    printf '%s' "$REPLY" > "$dst/agents/${rel##*/}"
  done

  # --- settings.json の変換 ---
  # Windows ネイティブの jq は標準出力へ CR を付ける（`.claude/rules/shell-script-style.md`
  # 「文字コード」）。ここはリダイレクトでファイルへ落とすため、混入すると .gemini/ の
  # settings.json だけが CRLF になり、--check が Windows と Linux で食い違う。
  convert_settings .claude/settings.json | tr -d '\r' > "$dst/settings.json"
}

# .gemini/ と $1 の差分を「Only in …」「Files … differ」の形で出力する。差分があれば非0。
diff_against_gemini() {
  local dst="$1"
  mkdir -p .gemini
  diff -r -q .gemini "$dst"
}

# .gemini/ に実在するが $1（生成先）に無いファイルを、1行1件で標準出力へ列挙する。
#
# 再生成は .gemini/ の丸ごと置き換えなので、ここに挙がったファイルは書き込みで失われる。
# 生成物と同名のファイルは上書きされるだけなので対象外である（内容の差は --dry-run が示す）。
# このリポジトリの .gemini/ は全体が生成物なので通常は0件で、その場合の挙動は従来と変わらない。
list_gemini_removed_files() {
  local dst="$1" work="$2" f
  [ -d .gemini ] || return 0
  # find は1回だけ起動する（ファイルごとに外部コマンドを呼ばない）。
  #
  # **プロセス置換 `< <(find …)` で受けない。** その終了コードはどこからも見えないため、
  # find が失敗すると「削除されるファイルは0件」という誤った結論になり、呼び出し元の
  # 削除ガードが**無言で失効して**、直後の丸ごと置き換えが配布先の自前ファイルを消す
  # （issue #26 で実測。issue #70 のレビュー指摘が求めた歯止めが、そのまま外れる）。
  run_or_fail '.gemini/ の走査' find .gemini -type f -print0 \
    > "$work/gemini-files.list" || return 1
  while IFS= read -r -d '' f; do
    [ -e "$dst/${f#.gemini/}" ] && continue
    printf '%s\n' "$f"
  done < "$work/gemini-files.list"
}

main() {
  local mode='write'
  local force=0
  local removed

  while [ $# -gt 0 ]; do
    case "$1" in
      --check)   mode='check'; shift ;;
      --dry-run) mode='dry-run'; shift ;;
      -f|--force) force=1; shift ;;
      -h|--help)
        sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
        return 0
        ;;
      *)
        echo "エラー: 不明な引数です: $1" >&2
        return 1
        ;;
    esac
  done

  require_jq

  local repo_root
  repo_root="$(git rev-parse --show-toplevel)"
  cd "$repo_root"

  local tmp
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" EXIT

  build_into "$tmp/gemini" "$tmp"

  case "$mode" in
    check)
      if diff_against_gemini "$tmp/gemini"; then
        echo ".gemini/ は .claude/ と同期しています。"
        return 0
      fi
      echo "" >&2
      echo ".gemini/ が .claude/ と食い違っています。" >&2
      echo "bash .claude/scripts/src/sync-gemini-assets.sh を実行して再生成してください。" >&2
      return 1
      ;;
    dry-run)
      if diff_against_gemini "$tmp/gemini"; then
        echo "変更はありません。"
      else
        echo ""
        echo "上記が再生成で変わる内容です（--dry-run のため書き込んでいません）。"
      fi
      return 0
      ;;
    write)
      # 丸ごと置き換える前に、生成物へ含まれないファイルを検出する。**書き込みの前に判定する**
      # ため、中断したときは1バイトも変更していない（配布先が自前の .gemini/ を持っている場合に
      # 黙って消さないための歯止め。issue #70 のレビュー指摘）。
      local -a removed_files=()
      # **列挙をプロセス置換で受けない。** 失敗しても「0件」に見えるだけで、この直後の
      # `rm -rf .gemini` がガードをすり抜ける（上の list_gemini_removed_files の注記）。
      run_or_fail '削除されるファイルの列挙' \
        list_gemini_removed_files "$tmp/gemini" "$tmp" > "$tmp/removed.list" || return 1
      while IFS= read -r removed; do
        removed_files+=("$removed")
      done < "$tmp/removed.list"

      if [ "${#removed_files[@]}" -gt 0 ] && [ "$force" -eq 0 ]; then
        echo "エラー: .gemini/ に、生成物へ含まれないファイルが ${#removed_files[@]} 件あります。" >&2
        printf '  %s\n' "${removed_files[@]}" >&2
        echo "" >&2
        echo ".gemini/ は .claude/ からの生成物で、再生成は丸ごとの置き換えです。" >&2
        echo "上のファイルは再生成で失われます。退避するか、消してよければ --force を付けて" >&2
        echo "再実行してください（この実行では1バイトも書き込んでいません）。" >&2
        return 1
      fi

      # .gemini/ は完全な生成物なので、古いファイルを残さないよう丸ごと置き換える。
      rm -rf .gemini
      mv "$tmp/gemini" .gemini
      if [ "${#removed_files[@]}" -gt 0 ]; then
        echo "--force のため、生成物に含まれない ${#removed_files[@]} 件を削除しました。" >&2
        printf '  %s\n' "${removed_files[@]}" >&2
      fi
      echo ".gemini/ を再生成しました。"
      return 0
      ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
