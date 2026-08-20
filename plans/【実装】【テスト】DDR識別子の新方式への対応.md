---
title: 【実装】【テスト】DDR識別子の新方式への対応
type: plan
description: issue #133 の個別作業計画。命名規則の規約化・check-base-conflicts.shの識別子抽出の一般化・単体テスト追加・スキル/一覧の更新
tags: [ddr, plan, conflict, workflow]
keywords: [DDR, 識別子, 命名規則, check-base-conflicts, 単体テスト, resolve-conflict, README, 類型A, 枝番]
---

# 【実装】【テスト】DDR識別子の新方式への対応（issue #133）

調査結果（`reports/2026-08-20_ddr-identifier-issue-based_調査結果.md`）で決めた
`i<issue番号>-<枝番2桁>` 方式を、規約・実装・テスト・スキルへ反映する。

**実装とテストを1ファイルへ併記する**のは、テストが実装（正規表現の分岐）と一体で、分けても
合意の単位が変わらないため（`.claude/skills/issue-mr-flow/SKILL.md`「種別を複数併記する場合」）。

## 作業項目

| # | 対象 | 内容 |
|---|---|---|
| 1 | `.claude/rules/markdown-frontmatter.md` | 「DDRの識別子」節を新設し、新方式の命名・枝番・`title`・`superseded_by` の書式と、既存連番の扱いを明記する |
| 2 | `.claude/scripts/src/check-base-conflicts.sh` | `ddr_number_to_reply` → `ddr_identifier_to_reply` へ改名し、`^([0-9]{4})-` に加えて `^(i[0-9]+-[0-9]{2})-` を受け付ける。`find_duplicate_ddr_numbers` → `find_duplicate_ddr_identifiers`。**JSONのキー名は据え置く** |
| 3 | `.claude/scripts/test/test_check_base_conflicts.sh` | 関数名の追従に加え、新方式単独・新旧混在・不正形式（枝番なし・枝番1桁・大文字 `I`）のケースを追加する |
| 4 | `.claude/skills/resolve-conflict/SKILL.md` | 類型Aを「新方式では衝突しない」「重複が出るのは既存連番と、同一issueを別ブランチで並行作業した場合」「既存連番は従来どおり改番する」の3点が分かる形へ書き換える |
| 5 | `.claude/docs/README.md` | DDR一覧を「連番（新規追加しない）」と「issue番号ベース（新規はこちら）」の2ブロックへ分け、後者はissue番号の数値順に並べる |
| 6 | `.claude/rules/docs-workflow.md` | ドキュメント運用表のDDR行のファイル名例・「連番で管理し」の記述を更新する |
| 7 | `.claude/skills/issue-mr-flow/SKILL.md` | 監視の類型A行と flow-id 5-1 節の説明を、新方式を踏まえた表現へ更新する |

## 検証

- `bash -n` で変更した `.sh` の構文チェック。
- `bash .claude/scripts/test/test_check_base_conflicts.sh` が `passed=N failures=0`。
- 他の単体テストが道連れで壊れていないこと（`.claude/scripts/test/test_*.sh` を全件実行）。
- `bash .claude/scripts/src/check-base-conflicts.sh --no-fetch | jq` が正常なJSONを返し、
  `hasDuplicateDdrNumber` が `false` であること。
- `bash .claude/scripts/src/extract-frontmatter.sh .` が新方式のDDRを取りこぼさないこと。

## やらないこと

- 既存55件のDDRの改番・本文変更・参照更新。
  → **この項目は後から覆った。** ユーザーの判断で全件改番することになり、別の個別作業計画
  `plans/【実装】既存DDRの全件改番.md` として立てている（本計画の作業項目5・
  「やらないこと」のこの行は、その時点で上書きされる）。
- `duplicateDdrNumbers` / `hasDuplicateDdrNumber` というJSONキーの改名（調査結果 第5節）。
- `search-frontmatter.sh` の日付判定の正規表現（DDRとは無関係）。
