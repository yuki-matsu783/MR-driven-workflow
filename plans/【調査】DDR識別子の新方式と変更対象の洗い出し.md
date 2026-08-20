---
title: 【調査】DDR識別子の新方式と変更対象の洗い出し
type: plan
description: issue #133 の個別調査計画。DDR識別子の命名規則案を比較し、4桁連番を前提にしているコード・ドキュメントを全数洗い出す
tags: [ddr, plan, conflict, workflow]
keywords: [DDR, 識別子, 命名規則, 枝番, check-base-conflicts, 正規表現, 変更対象, 洗い出し, 参照更新]
---

# 【調査】DDR識別子の新方式と変更対象の洗い出し（issue #133）

## この調査で答えを出すこと

1. **新しい識別子の命名規則をどうするか。** 候補を出し、次の観点で比較して1案へ決める。
   - 既存の4桁連番と**機械的に区別できる**か（正規表現1本で判別できるか）
   - 別ブランチ同士で**同じ識別子が生まれないことが構造的に保証される**か
   - 1つのissueが複数のDDRを生む場合の**枝番の採番が同一ブランチ内で閉じる**か
   - 人間が読んで意味が分かるか・grepしやすいか・ソート順が破綻しないか
2. **4桁連番の形式を前提にしている箇所はどこか。** コード・テスト・ドキュメントを全数洗い出す。
3. **既存DDRへの参照が何箇所あり、今回それを変更しなくて済むことを確認できるか。**

## 調査の進め方

| # | 手段 | 目的 |
|---|---|---|
| 1 | `ls .claude/docs/ddr/` と番号の重複チェック | 現行DDRの件数・番号の欠番・重複の有無を確定する（issue本文の件数と突き合わせる） |
| 2 | `grep -rn 'ddr_number_to_reply\|find_duplicate_ddr_numbers\|duplicateDdrNumbers\|hasDuplicateDdrNumber'` | 検知ロジックとその利用側（スキル・spec）を漏れなく列挙する |
| 3 | `grep -rn '[0-9]\{4\}-'`（日付形式を除く） | 番号参照の総量を数え、「改番に伴う参照更新」のコストを定量化する |
| 4 | `.claude/scripts/src/` `.claude/hooks/` の全 `.sh` を対象に4桁の正規表現を検索 | `check-base-conflicts.sh` 以外に形式を前提にしたスクリプトが無いことを確認する |
| 5 | `.claude/rules/markdown-frontmatter.md` `.claude/rules/docs-workflow.md` `.claude/docs/README.md` を通読 | 規約側で命名・`superseded_by` の書式がどう定義されているかを確認する |

## 調査しないと決めたこと（範囲外）

- **既存58件（実測55件）のDDRの改番**。issueの期待する動作として「改番しない」と決まっているため、
  改番の手順・影響は調査しない。
- **DDR以外の連番リソース**。現状このリポジトリで連番を持つのはDDRのみ（`check-base-conflicts.md`
  の未決定事項に記載のとおり）。

## 成果物

- `reports/2026-08-20_ddr-identifier-issue-based_調査結果.md`（結果の正文）
- `reports/2026-08-20_ddr-identifier-issue-based_調査結果.html`（上記の視覚化）
