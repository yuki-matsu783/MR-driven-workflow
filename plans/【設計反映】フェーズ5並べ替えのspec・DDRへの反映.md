---
title: 【設計反映】フェーズ5並べ替えのspec・DDRへの反映
type: plan
description: issue #112 の個別反映計画。フェーズ5の並べ替えを .claude/docs/spec/ と新規DDRへ反映する範囲と、書き換えてはいけない過去の記録の線引き。
tags: [plan, design-reflection, ddr, spec]
keywords: [設計反映, DDR0057, issue-mr-workflow, cleanup-task, check-base-conflicts, 影響範囲, changelog, issue108]
---

# 【設計反映】フェーズ5並べ替えのspec・DDRへの反映（issue #112）

全体作業計画: `plans/tidy-closing-cascade.md`

## 反映対象

| ファイル | 反映内容 |
|---|---|
| `.claude/docs/spec/issue-mr-workflow.md` | 仕様側（`## 仕様` 配下）の flow-id 参照を新番号へ。`## 影響範囲` の末尾へ issue #112 のエントリを**追記**する |
| `.claude/docs/spec/cleanup-task.md` | タイトル・description・keywords・H1・背景の flow-id を 5-3 へ。issue #28 のissue名は当時の番号のままとし、注記で対応づける |
| `.claude/docs/spec/check-base-conflicts.md` | keywords と「実行タイミング」の flow-id を 5-1 へ |
| `.claude/docs/spec/create-commit.md` / `extract-frontmatter.md` / `update-handoff-progress.md` | 現在の状態を説明する記述の flow-id を 5-3 へ |
| `.claude/docs/ddr/0057-…md`（新規） | 並べ替えの理由・却下案・DDR 0044/0048 との関係・issue #108 との前後関係 |
| `.claude/docs/README.md` | spec一覧の説明文、DDR一覧へ 0057 を追加、0048 のファイル名が旧番号である旨の注記 |

## 書き換えない対象（線引き）

- **DDR本文**（0044・0048 ほか）。`.claude/rules/docs-workflow.md` の「本文は追記のみ」に従う。
  0048 はファイル名にも `flow-id5-1` を含むが、リンク切れを避けるためリネームしない。
- **specの `## 影響範囲` 配下の過去issueごとのエントリ**（point-in-timeの記録）。
- `.claude/scripts/src/vcs/Provider.sh` の「当時の flow-id 5-3」のように、**明示的に当時の番号だと
  書かれている記述**。

## AIアセット反映との切り分け

`.claude/rules/` `.claude/skills/` `index.md` の更新は、本タスクでは成果物そのもの
（フェーズ3の `【実装】` で実施済み）であり、この反映計画には含めない。

## 検証

```bash
grep -rn "flow-id 5-" --include='*.md' --include='*.sh' . | grep -v '/ddr/' | grep -v '影響範囲'
bash .claude/scripts/src/extract-frontmatter.sh . >/dev/null && echo 'frontmatter index ok'
```
