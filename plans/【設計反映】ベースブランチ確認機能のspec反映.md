---
title: 【設計反映】ベースブランチ確認機能のspec反映
type: plan
description: issue #15対応。実装済みのベースブランチ確認機能を.claude/docs/spec/issue-mr-workflow.mdへ反映する
tags: [issue-mr-flow, base-branch, spec]
keywords: [new_issue_branch, defaultBaseBranch, AskUserQuestion, 影響範囲, 未決定事項]
---

# 【設計反映】ベースブランチ確認機能のspec反映

個別作業計画: [plans/【設計】【実装】ベースブランチ確認のAskUserQuestion化.md](./【設計】【実装】ベースブランチ確認のAskUserQuestion化.md)
（実装・レビュー済み）

## 反映対象

`.claude/docs/spec/issue-mr-workflow.md` のみ（`SKILL.md`・`Provider.sh`は実装フェーズで
既に更新済みのため対象外。AIアセット反映（`.claude/rules/`等）は本issueでは不要と判断）。

1. 「提供関数」表の `new_issue_branch` 行に `[<base>]`（第3引数、省略可）を追記する。
2. 「影響範囲」changelogの末尾に、issue #15の変更点（新規/変更ファイル）を新規エントリとして追記する
   （既存エントリは変更しない）。
3. 「未決定事項・懸念点」に、既定以外のベースブランチを選んだ場合 `get_branch_work_files`
   （`origin/<defaultBaseBranch>...HEAD` で差分を取る設計）や `resume` のヒューリスティックが
   実際のベースとズレる可能性がある既知の制約を追記する（全体作業計画で識別済みの限界。本issueの
   スコープでは `get_branch_work_files` 自体の改修は行わない）。

## 検証方法

- 追記後、目視で既存の記述と矛盾がないか確認する。
- changelogの過去エントリ（issue #9以前）は一切変更しない（`.claude/rules/docs-workflow.md`の
  「ファイル移動に伴うパス参照の一括置換は...過去changelogエントリを対象に含めない」原則に準じ、
  新規エントリの追記のみに留める）。
