#!/usr/bin/env bash
# flow-id 5-1 の後片付けタスク自動化
# 次タスク開始前に、plans/, worklog/, reports/ ディレクトリと関連ファイルを削除し、
# index.jsonl を再生成し、HANDOFF.md をテンプレート版へリセットする
#
# 使用法:
#   bash .claude/scripts/src/cleanup-task.sh [--dry-run]
#
# オプション:
#   --dry-run    削除予定ファイルを表示し、実際には削除しない
#
# HANDOFF.md のテンプレート本体は .claude/scripts/templates/HANDOFF.md.template に
# 外部ファイルとして持つ（.claude/skills/issue-mr-flow/SKILL.md からも同じファイルを
# 参照する。詳細: .claude/rules/docs-workflow.md「HANDOFF.md と SKILL.md の役割分担」）

set -euo pipefail

# スクリプトの親ディレクトリ（.claude/scripts/src）を基準に、リポジトリルートを特定
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../../../" && pwd)"
handoff_template_file="$(cd "${script_dir}/../templates" && pwd)/HANDOFF.md.template"

cd "${repo_root}"

# オプション解析
dry_run=false
if [[ ${1:-} == "--dry-run" ]]; then
  dry_run=true
fi

# 削除対象
targets=(
  "plans"
  "worklog"
  "reports"
  "plans/index.jsonl"
)

# 削除対象の確認・ログ出力
echo "=== flow-id 5-1 後片付けタスク ==="
echo

if [[ "$dry_run" == true ]]; then
  echo "[DRY RUN] 削除予定ファイル:"
  for target in "${targets[@]}"; do
    if [[ -e "$target" ]]; then
      if [[ -d "$target" ]]; then
        echo "  [DIR]  $target"
      else
        echo "  [FILE] $target"
      fi
    fi
  done
  echo
  echo "[DRY RUN] 実行コマンド (実際には実行されません):"
  echo "  rm -rf plans/ worklog/ reports/"
  echo "  rm -f plans/index.jsonl"
  echo "  bash .claude/scripts/src/extract-frontmatter.sh ."
  echo "  cp ${handoff_template_file#${repo_root}/} HANDOFF.md"
  echo
  exit 0
fi

# 実際の削除処理
echo "削除を実行します..."
echo

# plans/, worklog/, reports/ を削除
for dir in "plans" "worklog" "reports"; do
  if [[ -d "$dir" ]]; then
    echo "削除: $dir/"
    rm -rf "$dir"
  else
    echo "スキップ: $dir/ （存在しません）"
  fi
done

# plans/index.jsonl を削除（対象ディレクトリが削除されていても念のため）
if [[ -f "plans/index.jsonl" ]]; then
  echo "削除: plans/index.jsonl"
  rm -f "plans/index.jsonl"
fi

echo

# index.jsonl 群を再生成
echo "frontmatter インデックスを再生成しています..."
if bash .claude/scripts/src/extract-frontmatter.sh . >/dev/null 2>&1; then
  echo "✓ index.jsonl 群を再生成しました"
else
  echo "⚠ extract-frontmatter.sh の実行中に警告がありました（詳細はコマンドで確認してください）"
fi

echo

# HANDOFF.md をテンプレート版へリセット
echo "HANDOFF.md をテンプレート版へリセットしています..."

if [[ ! -f "$handoff_template_file" ]]; then
  echo "✗ テンプレートファイルが見つかりません: $handoff_template_file" >&2
  exit 1
fi

cp "$handoff_template_file" HANDOFF.md
echo "✓ HANDOFF.md をテンプレート版へリセットしました"

echo
echo "=== 後片付けタスク完了 ==="
echo "次のステップ:"
echo "  - flow-id 5-2: \`commit\` スキル経由でcommitし、push"
echo "  - flow-id 5-3: MRをマージする（squash merge）"
