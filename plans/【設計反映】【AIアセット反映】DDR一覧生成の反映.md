---
title: 【設計反映】【AIアセット反映】DDR一覧生成の反映
type: plan
description: issue #135 の実装内容をspec/ddrおよびルール・スキルへ反映するための個別反映計画（反映対象の洗い出し結果）
tags: [ddr, docs, reflection, plan]
keywords: [設計反映, AIアセット反映, generate-ddr-list, note, resolve-conflict, docs-workflow, markdown-frontmatter]
---

# 【設計反映】【AIアセット反映】DDR一覧生成の反映

issue #135 / 全体作業計画: `plans/ddr-list-generation.md`

**このファイルには結果を書かない**（結果は `reports/20260820_ddr-list-generation_DDR一覧生成スクリプトの実装結果.md`）。

## 反映対象の洗い出し

### 設計反映（spec / ddr）

| 対象 | 反映内容 |
|---|---|
| `.claude/docs/spec/generate-ddr-list.md`（新規） | オプション・終了コード・マーカー・並び順・注記の組み立て規則・性能上の制約 |
| `.claude/docs/ddr/0061-…md`（新規） | 「生成物だがGit管理下へ残す」判断と却下案6件 |
| `.claude/docs/README.md` のspec一覧 | 上記specへのリンクを追加 |

### AIアセット反映（rules / skills）

| 対象 | 反映内容 |
|---|---|
| `.claude/rules/markdown-frontmatter.md` | `note` キーの定義（キー定義表＋「DDRのnote」節）。`status` 更新時に再生成する手順 |
| `.claude/rules/docs-workflow.md` | DDR行へ「一覧は手書きしない・生成して同じコミットに含める」を追加 |
| `.claude/skills/resolve-conflict/SKILL.md` | DDR一覧を類型C→類型Bへ移動。類型Aの改番手順・Step 5の検証手順へ再生成を追加 |

### 反映しないもの

- `.claude/skills/issue-mr-flow/SKILL.md` … DDR追加はフロー上 flow-id 4-6 の中の作業であり、
  手順の粒度としては `docs-workflow.md` 側に置くのが適切。フロー表そのものは変わらない。
- `AGENTS.md` / `CLAUDE.md` … 新しい横断ルールではなく、既存ルールの詳細化にとどまるため。

## 反映時に確認すること

- 見出しを差し込む位置の直前が「節全体にかかる地の文」で終わっていないか
  （`.claude/rules/docs-workflow.md`）。
- 一覧が生成物になったことで**古くなる既存の記述**が無いか（手書き前提の案内が残っていないか）。
