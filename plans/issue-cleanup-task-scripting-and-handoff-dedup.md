---
title: 後片付けタスクスクリプト化 & HANDOFF.md重複排除
type: log
description: flow-id 5-1の手動作業をスクリプト化し、HANDOFF.mdとSKILL.mdの重複を解消する
keywords: [cleanup, automation, handoff, duplicate-management, issue-mr-workflow]
---

## 背景

### 現状の問題点

1. **後片付けタスク（flow-id 5-1）**
   - 現在、エージェントが手動で実行している操作：
     - `plans/` `worklog/` `reports/` ディレクトリ削除
     - `plans/index.jsonl` 削除
     - `bash .claude/scripts/src/extract-frontmatter.sh .` 実行
     - `HANDOFF.md` をテンプレート版へリセット
   - **スクリプト化により** 自動化可能 → issue-mr-flowの「エージェント自動実行」に組み込める

2. **HANDOFF.md と SKILL.md の重複管理**
   - **SKILL.md**（`.claude/skills/issue-mr-flow/SKILL.md`）
     - 全39ステップの唯一のフロー定義
     - 各行：flow-id | ステップ詳細 | 担当
   - **HANDOFF.md**
     - SKILL.mdのテーブルを手動コピー＋チェックボックス追加
     - flow-id 5-1行で **差異あり**（`plans/index.jsonl` 削除や`extract-frontmatter.sh`実行が記載されていない）
   - **影響**: 両ドキュメント非同期編集で、バージョンズレが発生し、5-1の手順が不完全になるリスク

### 実装効果

- **スクリプト化**: 次タスク開始時の後片付けを完全自動化 → エージェントのPull Request作成直前に自動実行可能
- **重複排除**: HANDOFF.mdの役割を「進捗記録」に限定 → マスター定義（SKILL.md）との同期ズレを防止

---

## 実装計画

### **フェーズ1: 後片付けタスク自動化スクリプトの作成**

#### タスク 1-1: `cleanup-task.sh` 実装

**ファイル**: `.claude/scripts/src/cleanup-task.sh`

**機能**:
```bash
#!/usr/bin/env bash
# flow-id 5-1 の後片付けタスク自動化
# 使用法: bash .claude/scripts/src/cleanup-task.sh [--dry-run]
#
# 処理内容：
# 1. plans/, worklog/, reports/ ディレクトリ削除
# 2. plans/index.jsonl 削除
# 3. index.jsonl 群を再生成（extract-frontmatter.sh実行）
# 4. HANDOFF.md をテンプレート版へリセット
```

**実装内容**:
- エラーハンドリング（`set -euo pipefail`）
- `--dry-run` オプション（削除前にシミュレーション表示）
- ログ出力（何を削除したか明示）
- HANDOFF.mdテンプレート埋め込み

**テスト**: `.claude/skills/issue-mr-flow/SKILL.md` の「flow-id 5-1」直前で実行、正常完了確認

---

### **フェーズ2: HANDOFF.md と SKILL.md の重複構造改善**

#### タスク 2-1: `.claude/rules/docs-workflow.md` 更新

**目的**: HANDOFF.mdの役割を明確化

**修正内容**:
- 既存テーブル行「`HANDOFF.md`」を拡張
- HANDOFF.mdが**進捗記録専用**であり、flow-idテーブルそのものではなく「チェックボックス＋記録欄」であることを明記
- flow-idテーブルのマスター定義は SKILL.md のみであることを強調

#### タスク 2-2: HANDOFF.md のテンプレート修正

**修正対象**: `HANDOFF.md`

**修正内容**:
- 現在の完全なflow-idテーブル（51行相当）を削除
- 代わりに簡潔な「現在位置」セクション：
  ```markdown
  ## 進捗状況
  
  **現在位置**: flow-id 1-1（新issue起票）
  **詳細フロー定義**: `.claude/skills/issue-mr-flow/SKILL.md` を参照
  
  ### チェックリスト
  [ ] 1-1 ... (以下、選択したflow-idのみチェック記載)
  ```
- フロー全体参照が必要な場合は`.claude/skills/issue-mr-flow/SKILL.md`へ誘導

#### タスク 2-3: `.claude/skills/issue-mr-flow/SKILL.md` の flow-id 5-1行を明確化

**修正対象**: SKILL.md の flow-id 5-1行の説明

**修正内容**:
- 削除対象・再生成処理を完全列挙（`plans/index.jsonl` 削除を明記）
- HANDOFF.mdテンプレートリセット手順を参照可能にする

---

## 優先度・実行順序

| # | タスク | 優先度 | 理由 |
|---|---|---|---|
| 1 | **2-3**: SKILL.md flow-id 5-1を明確化 | **最高** | 後片付けタスク手順の正式版を確立してから、スクリプト・テンプレート化する |
| 2 | **1-1**: `cleanup-task.sh` 実装 | **高** | flow-id 5-1の手順が確定したらスクリプト化 |
| 3 | **2-2**: HANDOFF.md テンプレート修正 | **中** | スクリプト完成後、テンプレート内容を統一 |
| 4 | **2-1**: `docs-workflow.md` 更新 | **低** | 参照ドキュメント更新（最後の整理） |

---

## 検証方法

1. **SKILL.md 更新後**:
   - flow-id 5-1行を読み、必要な全操作が記載されているか確認

2. **cleanup-task.sh 完成後**:
   - テスト実行: `bash .claude/scripts/src/cleanup-task.sh --dry-run`
   - 削除予定ファイル一覧が正しく表示される
   - 実行: `bash .claude/scripts/src/cleanup-task.sh`
   - plans/, worklog/, reports/, plans/index.jsonl が削除される
   - HANDOFF.md がテンプレート版に初期化される
   - index.jsonl が再生成される

3. **HANDOFF.md テンプレート修正後**:
   - 新しいissue開始時にテンプレートをコピー、チェックボックスが正しく表示される

---

## 関連issue

このタスクで作成すべき新規issue:
- **タイトル**: `flow-id 5-1 後片付けタスク自動化スクリプト（cleanup-task.sh）の実装`
- **説明**: 本計画の「フェーズ1」を実行するissue
