#!/usr/bin/env bash
#
# .gemini/ を .claude/ からの変換生成物として再生成する（issue #70）。
#
# .gemini/ は「手で書く実体」ではなく「.claude/ から機械的に決まる生成物」である。
# 編集は必ず .claude/ 側に対して行い、このスクリプトを流し直すこと。
# **.gemini/ 配下へ手で置いたファイルは、再生成時に削除される。**
#
# 使い方:
#     bash .claude/scripts/src/sync-gemini-assets.sh [--check] [--dry-run]
#
#     （引数なし） .gemini/ を再生成する
#     --check      生成せず、一時ディレクトリへ生成して .gemini/ と突き合わせる。
#                  食い違えば非0で終了する（CI・手動確認用。どのhookにも自動では挿さない）
#     --dry-run    何が変わるかだけを出力する（常に終了コード0）
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

# .claude/settings.json のトップレベルキーのうち、**意図的に写像しないもの**。
# ここに無く、かつ写像もされないキーが現れたらエラーにする（下記 convert_settings）。
#
#   permissions      … Gemini の相当機能は policy engine（.gemini/policies/*.toml）だが、
#                       プロジェクト単位の Workspace 層が現在無効のため、リポジトリへ置いても
#                       効果がゼロである（docs/reference/policy-engine.md の
#                       "(Currently disabled)"、upstream issue #18186）。
#                       **対応漏れではない。** Workspace 層が有効化されたら見直す。
#   autoCompactWindow … Gemini の model.compressionThreshold は「コンテキスト使用率の分数」
#                       （既定 0.5）であり、絶対値である Claude 側の値とは換算できない。
readonly SETTINGS_IGNORED_KEYS=(
  permissions
  autoCompactWindow
)

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

  mapfile -t lines < "$src"

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
#   $ignored  意図的に写像しないトップレベルキーの配列
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
      + "。sync-gemini-assets.sh の写像規則へ追加するか、SETTINGS_IGNORED_KEYS へ理由付きで加えてください")
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
  local -a copy_rel=()
  local -a agent_rel=()
  local f rel skipped=0

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
    rel="$f"
    case "$rel" in
      .claude/agents/*.md) agent_rel+=("$rel"); continue ;;
    esac
    is_copy_excluded "$rel" && continue
    copy_rel+=("${rel#.claude/}")
  done < <(git -c core.quotepath=false ls-files --cached --others --exclude-standard -z -- .claude)

  if [ "$skipped" -gt 0 ]; then
    echo "skipped $skipped deleted file(s) not present in the working tree" >&2
  fi
  if [ "${#copy_rel[@]}" -eq 0 ]; then
    echo "エラー: .claude/ 配下にコピー対象が1件もありません（リポジトリルートで実行していますか）" >&2
    return 1
  fi

  mkdir -p "$dst"

  # --- コピー ---
  # ファイルごとに cp を呼ばない（148件 × 約95ms = 十数秒になる）。xargs が引数長の上限に
  # 応じて自動で分割するので、`.claude/` が大きくなっても Argument list too long にならない。
  # `cp --parents` は相対パスの階層を再現するため、コピー元へ cd した実サブシェルで実行する。
  ( cd .claude && printf '%s\0' "${copy_rel[@]}" | xargs -0 cp --parents -t "$dst" -- )

  # --- agents の変換 ---
  mkdir -p "$dst/agents"
  for rel in "${agent_rel[@]}"; do
    convert_agent_to_reply "$rel" || return 1
    printf '%s' "$REPLY" > "$dst/agents/${rel##*/}"
  done

  # --- settings.json の変換 ---
  convert_settings .claude/settings.json > "$dst/settings.json"
}

# .gemini/ と $1 の差分を「Only in …」「Files … differ」の形で出力する。差分があれば非0。
diff_against_gemini() {
  local dst="$1"
  mkdir -p .gemini
  diff -r -q .gemini "$dst"
}

main() {
  local mode='write'

  while [ $# -gt 0 ]; do
    case "$1" in
      --check)   mode='check'; shift ;;
      --dry-run) mode='dry-run'; shift ;;
      -h|--help)
        sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
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

  build_into "$tmp/gemini"

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
      # .gemini/ は完全な生成物なので、古いファイルを残さないよう丸ごと置き換える。
      rm -rf .gemini
      mv "$tmp/gemini" .gemini
      echo ".gemini/ を再生成しました。"
      return 0
      ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
