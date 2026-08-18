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

set -euo pipefail

# スクリプトの親ディレクトリ（.claude/scripts/src）を基準に、リポジトリルートを特定
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../../../" && pwd)"

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
  echo "  HANDOFF.md をテンプレート版へリセット"
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

if [[ -f "HANDOFF.md" ]]; then
  # テンプレート内容を生成
  handoff_template="---
title: MR駆動ワークフロー進捗トラッキング
type: handoff
description: issue・MR駆動開発フロー全体（5フェーズ・39ステップ）の進捗管理
---

## セッション情報

- **セッション日時**:
- **対応issue**:
- **ブランチ**:
- **PR/MR**:

## 現在地

**flow-id**: （未開始）

**詳細フロー定義**: [.claude/skills/issue-mr-flow/SKILL.md](./.claude/skills/issue-mr-flow/SKILL.md) を参照

## フロー進捗状況

### フェーズ1: Issue起票
- [] 1-1 新規issue作成
- [] 1-2 issueの内容を取得する
- [] 1-3 計画作成準備

### フェーズ2: 調査（計画フェーズ）
- [] 2-1 調査計画を立てる
- [] 2-2 実装するcommitし、pushしてレビュー依頼
- [] 2-3 レビューを取得し、計画を修正する
- [] 2-4 レビュー結果が合意に達した
- [] 2-5 全体作業計画を確定する
- [] 2-6 調査報告書を作成する
- [] 2-7 実装するcommitし、pushしてレビュー依頼
- [] 2-8 レビューを取得し、計画を修正する
- [] 2-9 レビュー結果が合意に達した

### フェーズ3: 実装（計画フェーズ）
- [] 3-1 実装計画を立てる
- [] 3-2 実装するcommitし、pushしてレビュー依頼
- [] 3-3 レビューを取得し、計画を修正する
- [] 3-4 レビュー結果が合意に達した
- [] 3-5 全体作業計画を確定する
- [] 3-6 実装を進める
- [] 3-7 実装するcommitし、pushしてレビュー依頼
- [] 3-8 レビューを取得し、計画を修正する
- [] 3-9 レビュー結果が合意に達した

### フェーズ4: 設計反映（計画フェーズ）
- [] 4-1 反映計画を立てる
- [] 4-2 実装するcommitし、pushしてレビュー依頼
- [] 4-3 レビューを取得し、計画を修正する
- [] 4-4 レビュー結果が合意に達した
- [] 4-5 反映計画をもとにMR descriptionを更新する
- [] 4-6 反映を進める
- [] 4-7 実装するcommitし、pushしてレビュー依頼
- [] 4-8 レビューを取得し、計画を修正する
- [] 4-9 レビュー結果が合意に達した
- [] 4-10 反映内容をもとにMR descriptionを更新する

### フェーズ5: マージ
- [] 5-1 後片付けタスク実行（cleanup-task.sh）
- [] 5-2 実装するcommitし、pushしてDraftを解除
- [] 5-3 マージする（squash merge）

## やったこと

（このセッションで実施した内容を記載。次セッションで削除）

## 次にやること

（次のステップを記載。次セッションで削除）

## 判断を迷った内容

（意思決定待ちの内容を記載。解決したら削除）

## 守るべき条件・触ってはいけない範囲

（実装中の前提条件・制約を記載。必要に応じて記載）
"

  printf '%s' "$handoff_template" > HANDOFF.md
  echo "✓ HANDOFF.md をテンプレート版へリセットしました"
else
  echo "⚠ HANDOFF.md が存在しません（スキップ）"
fi

echo
echo "=== 後片付けタスク完了 ==="
echo "次のステップ:"
echo "  - flow-id 5-2: \`commit\` スキル経由でcommitし、push"
echo "  - flow-id 5-3: MRをマージする（squash merge）"
