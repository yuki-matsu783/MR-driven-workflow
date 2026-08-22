---
title: 【AIアセット作成】flow-id5-3の新設と以降の繰り下げ
type: plan
description: フェーズ5へ「.claude/→.gemini/変換同期」をflow-id 5-3として新設し、以降の5-4〜5-7を繰り下げる計画
tags: [plan, flow-id, 繰り下げ, issue-70]
keywords: [flow-id, 5-3, 繰り下げ, SKILL.md, HANDOFF, update-handoff-progress, LOOP_RANGES, DDR本文, changelog]
---

# 【AIアセット作成】flow-id5-3の新設と以降の繰り下げ

対象: issue #70 / PR #157 / フェーズ3（flow-id 3-1〜）
前提となる調査結果: `reports/20260822_nimble-syncing-lantern_gemini同期方式の調査.md`「Q5」

## 目的

`.claude/` → `.gemini/` の変換同期を、フローの表に現れる**独立したステップ**として新設する。
**採番は2026-08-22のレビューで決着済み**（PR #157 に記録）。本計画は**決まった採番を、
どう安全に反映するか**だけを扱う。

| 変更前 | 変更後 | ステップ |
|---|---|---|
| 5-1 | 5-1 | defaultブランチとのコンフリクト検知・解消 |
| 5-2 | 5-2 | 関連issueへのマージ前通知 |
| — | **5-3（新設）** | **`.claude/` → `.gemini/` 変換同期** |
| 5-3 | 5-4 | 最終統括レポート作成とPR/MRへの反映 |
| 5-4 | 5-5 | 片付けとHANDOFF.mdリセット |
| 5-5 | 5-6 | commit・push してDraft解除 |
| 5-6 | 5-7 | マージ |

全ステップ数は **42 → 43** になる。

## なぜ別計画に分けたか

**この作業は機械的で、判断をほとんど含まない**（採番は決着済み）。一方で**波及が広く、
1箇所の漏れが番号の食い違いとして残る**。設計判断を含む他の2計画と混ぜると、レビューで
「番号の網羅性」と「変換規則の妥当性」という**性質の違う確認を同時にさせる**ことになる。

## 変更対象（実測。フェーズ2の調査で確定済み）

| 指標 | 件数 |
|---|---|
| `flow-id 5-[3-6]` の出現 | **109箇所 / 21ファイル** |
| 裸の `5-3`〜`5-6` を含む | **226箇所 / 23ファイル** |
| うちDDR本文（**変更対象外**） | 84箇所 |

主な変更先（件数順）:

- `.claude/skills/issue-mr-flow/SKILL.md`（28）— **新設ステップの行そのものもここへ足す**
- `.claude/docs/spec/issue-mr-workflow.md`（23）
- `.claude/rules/docs-workflow.md`（11）
- `.claude/scripts/src/vcs/Provider.sh`（7）
- `.claude/docs/README.md`（6）
- `.claude/rules/git-workflow.md`（5）/ `.claude/docs/spec/cleanup-task.md`（5）
- `.claude/scripts/src/cleanup-task.sh`（3）/ `.claude/rules/directory-structure.md`（3）
- 以下、`index.md` `Gitlab.sh` `Github.sh` `markdown-frontmatter.md`
  `update-handoff-progress.md` `extract-frontmatter.md` `HANDOFF.md`
  `doc-search/SKILL.md` `test_vcs_provider.sh` `test_update_handoff_progress.sh`
  `update-handoff-progress.sh` `create-commit.md`

## 方針

### 1. 新設ステップの内容（SKILL.md へ足す行）

| flow-id | ステップ | 担当 |
|---|---|---|
| 5-3 | **`.claude/` の変更を `.gemini/` へ変換同期する**（`bash .claude/scripts/src/sync-gemini-assets.sh` を実行する。生成物であり手で編集しない。差分は直後の flow-id 5-4 の commit に載る） | エージェント |

**この位置を採る理由**（調査結果 Q5 より、要点のみ再掲）:

1. **生成の直後に確定が来る。** 旧5-3（統括レポート）は自前で commit・push するため、
   同期で生えた `.gemini/**` はその commit に載る。**同期ステップ自体は commit を持たない。**
2. 統括レポートが**同期後の最終形**を記述できる。
3. 5-1 のコンフリクト解消で main から入った `.claude/` の変更を確実に拾える。

**issue #112 の制約（片付けは commit の直前）は壊れない**——新設ステップは片付けより前にあり、
片付け（新5-5）と commit（新5-6）は隣接したままである。

### 2. 依存関係（先に済ませる必要がある作業）

> **`extract-frontmatter.sh` への `.gemini` 除外は、本計画の前提条件である。**
> 同期（新5-3）は片付け（新5-5）より前にあり、**片付けは `index.jsonl` を再生成する**。
> 除外が無いと、その最中に `.gemini/**/index.jsonl` が生える。
> 実装は `plans/【実装】【テスト】…` が担うが、**順序として先に完了している必要がある。**

### 3. 置換の手順

**一括 `sed` で当てない。** 過去に2回、機械的な一括置換で記録を壊しかけている
（issue #24・issue #47）。

1. **先に除外対象を確定する**（下記「触ってはいけない範囲」）。
2. **降順に置換する**（`5-6`→`5-7` → `5-5`→`5-6` → `5-4`→`5-5` → `5-3`→`5-4`）。
   昇順だと、置換した結果が次の置換の対象になり**多重に繰り下がる**。
3. 置換後に**新設 5-3 の行を足す**（先に足すと、その行自身が置換対象になる）。
4. `.claude/scripts/src/update-handoff-progress.sh` の**ループ範囲定数・flow-id一覧**を確認する
   （フェーズ5にループ範囲は無いが、**全flow-idの一覧を持っている場合は 5-7 の追加が要る**）。
5. `HANDOFF.md` の進捗表テンプレート（`cleanup-task.sh` が持つ雛形）へ**新設行を足す**。

### 4. 触ってはいけない範囲

| 範囲 | 件数 | 理由 |
|---|---|---|
| `.claude/docs/ddr/` の**本文** | 84 | DDRは本文不変。当時の番号のまま `note` で補足する運用が既にある（`i0028-01` が実例） |
| `.claude/docs/spec/*.md` の**過去issueごとの記録節（changelog）** | — | point-in-time の記録。`.claude/rules/docs-workflow.md` が禁じている |
| 過去の記録として書かれた番号（当時のコミットメッセージの引用等） | — | 書き換えると当時何が起きたか読めなくなる |

**`note` での補足が要るDDRを、置換の過程で洗い出す。** 番号がずれるDDR
（`i0028-01` `i0111-01` `i0112-01` 等、片付け・統括レポートの位置を決めたもの）は
**frontmatterの `note` へ「現在は 5-N」と添える**（frontmatterの更新は本文不変の原則に反しない）。
**`note` を足したら `bash .claude/scripts/src/generate-ddr-list.sh` を実行し、
`.claude/docs/README.md` の差分を同じコミットへ含める。**

## やらないこと

- **`sync-gemini-assets.sh` の実装** → `plans/【実装】【テスト】…`
- **変換規則の決定** → `plans/【設計】…`
- **DDR `i0070-01` の新規作成・`i0000-13` の `superseded` 化** → フェーズ4（flow-id 4-6）
  （ただし上記「`note` での補足」は番号の整合性の問題なので本計画で行う）

## 検証手順（この計画の完了条件）

1. **削除行がゼロであること**（`.claude/rules/docs-workflow.md` が定める検証手順）。

   ```bash
   git diff <ブランチ分岐点のSHA> -- .claude/ | grep '^-' | grep -v '^---'
   ```

   **引数なしの `git diff` は使わない**（作業ツリー比較のため、その実行以降のコミットを見ない）。
2. **旧番号が残っていないこと**を、調査で使ったのと同じコマンドで確認する。

   ```bash
   grep -rno "flow-id 5-[3-7]" --include="*.md" --include="*.sh" --include="*.json" . \
     | grep -vE "^\./(\.git|usage|plans|reports|worklog)/|/ddr/|index\.jsonl" \
     | awk -F: '{print $1}' | sort | uniq -c | sort -rn
   ```

   **件数が置換前と一致すること**（新設行のぶんだけ増える）。減っていたら取りこぼしではなく
   **消してしまった**ことを疑う。
3. **DDR本文の差分がゼロ**であること（`git diff <分岐点SHA> -- .claude/docs/ddr/` の変更行が
   frontmatter だけであること）。
4. `bash .claude/scripts/test/test_update_handoff_progress.sh` と
   `bash .claude/scripts/test/test_vcs_provider.sh` が `failures=0` を返すこと。
5. **`cleanup-task.sh` が生成する `HANDOFF.md` の雛形に新設行があること**
   （`bash .claude/scripts/src/cleanup-task.sh --dry-run` では雛形が出ないため、雛形を持つ
   箇所をソース上で確認する）。
