#!/usr/bin/env bash
set -euo pipefail

# ロケールを UTF-8 に固定（日本語などのマルチバイトファイル名文字化け防止）
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

# Determine script and skill directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ASSETS_DIR="${SKILL_DIR}/assets"

# Output usage instruction
show_usage() {
  echo "Usage: $0 [-f|--force] [destination-directory]"
  echo "Applies the mr-driven-develop workflow assets to the specified repository."
  echo "Options:"
  echo "  -f, --force    Forcefully overwrite existing files without warnings or backups."
}

FORCE=false
DEST_DIR=""
HAS_WARNED=false

while [ $# -gt 0 ]; do
  case "$1" in
    -f|--force)
      FORCE=true
      shift
      ;;
    -h|--help)
      show_usage
      exit 0
      ;;
    -*)
      echo "❌ Error: Unknown option $1"
      show_usage
      exit 1
      ;;
    *)
      if [ -z "${DEST_DIR}" ]; then
        DEST_DIR="$1"
      else
        echo "❌ Error: Multiple destination directories specified."
        show_usage
        exit 1
      fi
      shift
      ;;
  esac
done

if [ -z "${DEST_DIR}" ]; then
  DEST_DIR="."
fi
DEST_DIR="$(cd "${DEST_DIR}" && pwd)"

echo "=== Applying mr-driven-develop Workflow to Project ==="
echo "Target directory: ${DEST_DIR}"
if [ "${FORCE}" = true ]; then
  echo "Force overwrite mode: Enabled"
fi

# 配布元が所有し、配布先でのカスタマイズを想定しないファイル（配布先ルートからの相対パス）。
# 内容が違っても .bak 退避・警告を行わず常に上書きする（issue #33）。
# `.claude/VERSION` は配布物の版そのもので、配布先が書き換える値ではない。ここを通常の
# 「差分があれば .bak 退避して警告」の対象にすると、**版を上げた回は必ず**警告と .bak が出て、
# 本当に手を入れるべき差分（AGENTS.md 等）の警告が埋もれる。
declare -a ALWAYS_OVERWRITE_RELPATHS=(
  ".claude/VERSION"
)

# コピー先が ALWAYS_OVERWRITE_RELPATHS に該当するかを判定する（外部コマンドを呼ばない）。
is_always_overwrite() {
  local rel="${1#${DEST_DIR}/}"
  local path
  for path in "${ALWAYS_OVERWRITE_RELPATHS[@]}"; do
    [ "${rel}" = "${path}" ] && return 0
  done
  return 1
}

# 比較およびバックアップ付きコピー
# ファイル比較・バックアップ付きコピー関数: safe_copy_file <コピー元> <コピー先>
safe_copy_file() {
  local src="$1"
  local dest="$2"

  if [ ! -f "${src}" ]; then
    return 0
  fi

  # コピー先の親ディレクトリが確実に存在するように作成
  mkdir -p "$(dirname "${dest}")"

  if [ -f "${dest}" ]; then
    if cmp -s "${src}" "${dest}"; then
      # 内容が完全に同一の場合は何もしない
      return 0
    fi

    # 内容が異なる場合
    if [ "${FORCE}" = true ]; then
      echo "🔄  Overwriting ${dest} (force option enabled)..."
      cp -f "${src}" "${dest}"
    elif is_always_overwrite "${dest}"; then
      # 配布元が所有する値。配布先のカスタマイズではないので .bak も警告も出さない
      cp -f "${src}" "${dest}"
    else
      local backup="${dest}.bak"
      echo "⚠️  WARNING: ${dest} already exists and differs from the template."
      echo "   Saving existing file to ${backup}"
      cp -f "${dest}" "${backup}"

      echo "✅  Applying template to ${dest} (existing customization preserved in ${backup})."
      cp -f "${src}" "${dest}"
      HAS_WARNED=true
    fi
  else
    # 新規ファイル作成
    cp -f "${src}" "${dest}"
  fi
}

# ディレクトリ配下のファイルを安全に一括コピーする関数: safe_copy_dir <コピー元ディレクトリ> <コピー先ディレクトリ>
safe_copy_dir() {
  local src_dir="$1"
  local dest_dir="$2"

  if [ ! -d "${src_dir}" ]; then
    return 0
  fi

  # コピー元ディレクトリ配下のすべてのファイルを検索して安全にコピー（ヌル区切りで文字化けやスペース割れを完全防止）
  find "${src_dir}" -type f -print0 | while IFS= read -r -d '' src_file; do
    local rel_path="${src_file#${src_dir}/}"
    local dest_file="${dest_dir}/${rel_path}"
    safe_copy_file "${src_file}" "${dest_file}"
  done
}

# 1. Validation
if [ ! -d "${DEST_DIR}/.git" ]; then
  echo "❌ Error: Target directory is not a Git repository (.git directory not found)."
  echo "Git repository is required to use the Issue/MR driven workflow."
  exit 1
fi

# Detect configurations for specific environments
IS_GO_PROJECT=false
if [ -f "${DEST_DIR}/go.mod" ]; then
  echo "🔍  Go project configuration (go.mod) detected."
  IS_GO_PROJECT=true
fi

# 2. Copy core workflow assets from skill's assets
echo "Installing core configuration files..."

# Ensure target directories exist
mkdir -p "${DEST_DIR}/.claude"
mkdir -p "${DEST_DIR}/.gemini"
mkdir -p "${DEST_DIR}/wip/plans"
mkdir -p "${DEST_DIR}/wip/worklogs"
mkdir -p "${DEST_DIR}/wip/reports"

# Copy configuration and rules safely
safe_copy_dir "${ASSETS_DIR}/.claude" "${DEST_DIR}/.claude"
safe_copy_dir "${ASSETS_DIR}/.gemini" "${DEST_DIR}/.gemini"
safe_copy_file "${ASSETS_DIR}/.mrworkflow.json" "${DEST_DIR}/.mrworkflow.json"
safe_copy_file "${ASSETS_DIR}/AGENTS.md" "${DEST_DIR}/AGENTS.md"
safe_copy_file "${ASSETS_DIR}/GEMINI.md" "${DEST_DIR}/GEMINI.md"
safe_copy_file "${ASSETS_DIR}/CLAUDE.md" "${DEST_DIR}/CLAUDE.md"
safe_copy_file "${ASSETS_DIR}/HANDOFF.md" "${DEST_DIR}/HANDOFF.md"
safe_copy_file "${ASSETS_DIR}/index.md" "${DEST_DIR}/index.md"

# Copy git provider templates if they exist in assets safely
if [ -d "${ASSETS_DIR}/.github" ]; then
  echo "Setting up GitHub issue templates..."
  safe_copy_dir "${ASSETS_DIR}/.github" "${DEST_DIR}/.github"
fi

if [ -d "${ASSETS_DIR}/.gitlab" ]; then
  echo "Setting up GitLab issue templates..."
  safe_copy_dir "${ASSETS_DIR}/.gitlab" "${DEST_DIR}/.gitlab"
fi

# Create placeholders for wip/plans, wip/worklogs, wip/reports if they do not exist
touch "${DEST_DIR}/wip/plans/.gitkeep"
touch "${DEST_DIR}/wip/worklogs/.gitkeep"
touch "${DEST_DIR}/wip/reports/.gitkeep"

# 3. Inject Language-specific rules if detected
if [ "${IS_GO_PROJECT}" = true ]; then
  echo "Injecting Go-specific rules..."
  # If AGENTS.md exists, append reference to go-applications.md
  if ! grep -q "go-applications.md" "${DEST_DIR}/AGENTS.md"; then
    echo -e "\n- Goアプリケーションの開発規約については、 [.claude/rules/go-applications.md](.claude/rules/go-applications.md) を参照し、それに従うこと " >> "${DEST_DIR}/AGENTS.md"
  fi
else
  # Clean up Go-specific files on non-Go projects
  rm -f "${DEST_DIR}/.claude/rules/go-applications.md" \
        "${DEST_DIR}/.gemini/rules/go-applications.md" || true
fi

# 4. Update destination .gitignore
echo "Updating .gitignore..."
GITIGNORE="${DEST_DIR}/.gitignore"
touch "${GITIGNORE}"

declare -a ignore_rules=(
  ""
  "# mr-driven-develop workflow ignores"
  "/.claude/usage-state/"
  "/.claude/session-logs/"
  "/.gemini/usage-state/"
  "/.gemini/session-logs/"
)

for rule in "${ignore_rules[@]}"; do
  if [ -z "${rule}" ]; then
    echo "" >> "${GITIGNORE}"
  elif ! grep -Fq "${rule}" "${GITIGNORE}"; then
    echo "${rule}" >> "${GITIGNORE}"
  fi
done

# 5. Update destination .gitattributes（issue #33）
# 配布先の .gitattributes は**丸ごと置き換えない**。配布先が自前の正規化・diff/merge driver 設定
# （例: `*.png binary`）を持つ場合、全文置換するとバイナリのテキスト化のような、履歴に残る形の
# 破損を招くため。.gitattributes は後に書いた行が優先されるので、末尾への追記であれば
# 「配布先の既定を尊重しつつ、配布したスクリプトに必要な指定だけを上書きする」形になる。
#
# **配る行の定義はこのスクリプトが持たない。** 本家の .gitattributes に置かれた
# `# --- dist:begin ---` 〜 `# --- dist:end ---` の間の行だけを読んで配る（定義を1箇所に持たせ、
# 本家を編集すれば配布内容も変わるようにするため）。
echo "Updating .gitattributes..."
GITATTRIBUTES="${DEST_DIR}/.gitattributes"
readonly GITATTRIBUTES_HEADER="# mr-driven-develop workflow attributes"

# 配布対象の .gitattributes 行（マーカーの間の、コメントと空行を除いた行）を標準出力へ返す。
# WindowsネイティブのGitでチェックアウトされた場合に備え、CRを落としてから返す。
read_dist_attribute_rules() {
  local src="$1"
  [ -f "${src}" ] || return 0
  awk '
    /^# --- dist:begin ---/ { in_block = 1; next }
    /^# --- dist:end ---/   { in_block = 0; next }
    in_block && $0 !~ /^[[:space:]]*#/ && NF { print }
  ' "${src}" | tr -d '\r'
}

# 指定した行が無ければ .gitattributes の末尾へ追記する（何度実行しても増えない）。
ensure_gitattributes_rules() {
  local file="$1"
  shift
  local rule existing

  [ -f "${file}" ] || : > "${file}"

  # 判定の前にCRを落とす。Git for Windowsの既定（core.autocrlf=true）では配布先の
  # .gitattributes が作業ツリーでCRLFになり、行全体の一致が `*.sh text eol=lf\r` と食い違う。
  # 落とさないと「まだ無い」と判定され、適用のたびに同じ行が追記され続ける（issue #33）。
  existing="$(tr -d '\r' < "${file}")"

  for rule in "$@"; do
    # 行全体の一致（-x）で判定する。部分一致にすると、配布先が `# *.sh text eol=lf を検討中` の
    # ようにコメントとして言及しているだけの場合にも「もう有る」と誤判定し、必要な指定が
    # 入らないまま無言で終わる（配布したスクリプトがCRLFで壊れても気づけない）。
    if printf '%s\n' "${existing}" | grep -Fxq -- "${rule}"; then
      continue
    fi

    # 末尾が改行で終わっていない場合、追記した行が直前の行と連結してしまうため改行を補う。
    # コマンド置換は末尾の改行をすべて落とすので、最後の1バイトが改行なら結果は空文字列になる。
    if [ -s "${file}" ] && [ -n "$(tail -c 1 "${file}")" ]; then
      printf '\n' >> "${file}"
    fi

    if ! printf '%s\n' "${existing}" | grep -Fxq -- "${GITATTRIBUTES_HEADER}"; then
      # 既存の内容があるときだけ、区切りの空行を挟む
      if [ -s "${file}" ]; then
        printf '\n' >> "${file}"
      fi
      printf '%s\n' "${GITATTRIBUTES_HEADER}" >> "${file}"
      existing="${existing}"$'\n'"${GITATTRIBUTES_HEADER}"
    fi

    printf '%s\n' "${rule}" >> "${file}"
    existing="${existing}"$'\n'"${rule}"
  done
}

declare -a attribute_rules=()
while IFS= read -r line; do
  [ -n "${line}" ] && attribute_rules+=("${line}")
done < <(read_dist_attribute_rules "${ASSETS_DIR}/.gitattributes")

if [ "${#attribute_rules[@]}" -eq 0 ]; then
  echo "⚠️  WARNING: ${ASSETS_DIR}/.gitattributes に配布対象行（# --- dist:begin --- 〜 # --- dist:end ---）が"
  echo "   見つかりませんでした。.gitattributes の更新をスキップします（0 rules）。"
else
  ensure_gitattributes_rules "${GITATTRIBUTES}" "${attribute_rules[@]}"
  echo "   ${#attribute_rules[@]} rule(s) ensured in ${GITATTRIBUTES}"
fi

echo "=== Setup Completed Successfully! ==="
echo "The mr-driven-develop workflow assets have been applied to your repository."
echo ""

if [ "${HAS_WARNED}" = true ]; then
  echo "⚠️  ATTENTION: Some existing files differed from the template."
  echo "   Their previous contents have been saved with a '.bak' extension."
  echo "   Please review the differences and consult with your AI assistant to import"
  echo "   or merge your prior customizations."
  echo ""
fi

echo "Next Steps:"
echo "1. Check and customize '.mrworkflow.json' if needed."
if [ "${IS_GO_PROJECT}" = true ]; then
  echo "2. Verify that '.claude/rules/go-applications.md' exists in your project."
  echo "3. Run your tests with 'go test ./...' and linter with 'golangci-lint run' to make sure your local environment is set up."
  echo "4. Create an issue, then run '/issue-mr-flow start <issue-number>' to begin!"
else
  echo "2. Create an issue, then run '/issue-mr-flow start <issue-number>' to begin!"
fi