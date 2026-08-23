---
title: worklog 20260823 SKILL.md分割のspec・DDR反映（push8）
type: log
description: issue #160 フェーズ4（設計反映）の試行錯誤ログ
tags: [worklog, issue-mr-flow, phase4]
keywords: [設計反映, spec, DDR, i0160-01, issue-mr-workflow, generate-ddr-list]
---

# worklog: SKILL.md分割のspec・DDR反映（issue #160 フェーズ4）

## flow-id 4-1（個別反映計画）

- `plans/【設計反映】SKILL.md分割のspec・DDR反映.md`（＋同名`.html`）を作成。
- 反映対象は A: `issue-mr-workflow.md`（hook節の更新＋影響範囲の新規エントリ）、
  B: `update-handoff-progress.md`（ROW_RE複製の注意）、C: DDR `i0160-01` 新規、
  D: `generate-ddr-list.sh` によるREADME再生成、の4点。
- フェーズ3で前倒し済みの項目（frontmatter type表・directory-structure.md・index.md）は
  対象から除外した（再変更しない）。
