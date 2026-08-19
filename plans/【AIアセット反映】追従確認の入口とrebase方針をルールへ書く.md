---
title: 【AIアセット反映】追従確認の入口とrebase方針をルールへ書く
type: plan
description: issue #67 の個別反映計画（AIアセット反映）。作業開始・再開時の追従確認の入口と、rebaseを使わない方針を .claude/rules/git-workflow.md へ書く。
tags: [plan, ai-asset, git-workflow, base-branch]
keywords: [AIアセット反映, git-workflow, rebase, 追従確認, ルール, 入口]
---

# 【AIアセット反映】追従確認の入口とrebase方針をルールへ書く（issue #67）

- 全体作業計画: `plans/base-branch-sync-check.md`
- 設計反映の計画（先に完了させる）: `plans/【設計反映】check-base-syncの仕様とDDRを正史へ反映する.md`

**`【設計反映】` とは分けている**（`.claude/skills/issue-mr-flow/SKILL.md`）。設計反映を完了・
レビューしてからこちらに着手する。

## 反映対象

| # | ファイル | 内容 |
|---|---|---|
| 1 | `.claude/rules/git-workflow.md` | 「作業開始・再開時のベースブランチ追従確認」の**入口の数行**（詳細は `SKILL.md` が正）。既存の「PR作成後のdefaultブランチ追従（issue #88）」節と並べる |
| 2 | 同上 | **rebaseを使わない方針の明記** |

## 1. 追従確認の入口

`.claude/rules/git-workflow.md` の「ブランチ運用」節へ数行を足す。**手順は書かない**
（`SKILL.md`「作業開始・再開時のベースブランチ追従確認」が正であり、判定基準を複数ファイルへ
再掲しない。`.claude/REVIEW-POINTS.md`「スキル・ルール・エージェント定義」）。

書くのは次の3点に留める。

- 作業を開始・再開するとき（`start` の既存ブランチ検出時・`resume`・`sync`）は、ベースブランチの
  最新を取り込めているかを `check-base-sync.sh` で確認する
- 遅れがある場合は**ユーザー確認を挟み、無断で取り込まない**
- 詳細は `SKILL.md` の該当節が正

**挿入位置に注意する。** 直前の節が「節全体にかかる地の文」で終わっていないかを確認し、
終わっている場合は節の末尾（次の見出しの直前）へ回す（`.claude/rules/docs-workflow.md`）。
挿入後に前後3行を目視で確認する。

## 2. rebaseを使わない方針

**調査で、`.claude/rules/` 配下に `rebase` の語が1件も無いことを確認した**
（`grep -rn "rebase" .claude/rules/` が0件）。方針を明示しているのは
`.claude/skills/resolve-conflict/SKILL.md` だけである。

- 全体作業計画が当初「`.claude/rules/git-workflow.md` で rebase を使わない方針を明示している」と
  書いていたが、**これは事実ではなかった**（敵対的レビューの指摘で判明し、計画側は訂正済み）。
- ルール側にも1行置いておくと、追従確認の選択肢に `rebase` を出す場面で根拠を辿れる。
- **`resolve-conflict` スキルの記述を丸写ししない。** ルール側は「rebaseは使わずmergeで取り込む」
  という結論と、詳細の参照先だけにする。

## この計画で決めないこと（スコープ外）

- `resolve-conflict` スキル本体の変更（方針そのものは既に書かれており、変える理由が無い）
- `AGENTS.md` `CLAUDE.md` への追記（`git-workflow.md` が既に参照されており、階層を増やさない）
- `.claude/REVIEW-POINTS.md` への観点追加（今回の作業で新しく踏んだ罠は
  「ヘッダコメントを増やしたら `--help` の行範囲も直す」程度で、汎用の観点にするには弱い）

## 検証

```bash
grep -n 'rebase' .claude/rules/git-workflow.md          # 方針が書かれたこと
sed -n '<挿入位置の前後>p' .claude/rules/git-workflow.md  # 空行の重複・見出しの密着が無いこと
bash .claude/scripts/src/extract-frontmatter.sh .
```
