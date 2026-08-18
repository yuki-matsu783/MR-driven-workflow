---
title: issue #15 全体作業計画 — issueからMR作成時にベースブランチをAskUserQuestionで確認する
type: plan
description: issue駆動フローのstartサブコマンドで、featureブランチ/Draft MR作成前にベースブランチが既定(.mrworkflow.jsonのdefaultBaseBranch)でよいかAskUserQuestionでユーザに確認する
tags: [issue-mr-flow, base-branch, ask-user-question]
keywords: [start, new_issue_branch, new_draft_merge_request, defaultBaseBranch, AskUserQuestion, Provider.sh, SKILL.md]
---

# 全体作業計画: issue #15 対応

## Context

現状、`issue-mr-flow` の `start` サブコマンドは、featureブランチ・Draft MRの作成先ベースブランチを
常に `.mrworkflow.json` の `defaultBaseBranch`（既定 `main`）に固定しており、ユーザに確認しない。
issue #15 は「issueからMRを作成するときにどれをベースにするか `AskUserQuestion` でユーザに聞く」ことを
求めている（本文は「## 目的」のみで、現状／期待する動作／受け入れ条件の見出しは欠落しているため、
本計画でスコープを明確化する）。

`AskUserQuestion` の選択肢は、他リポジトリへ移植した場合（`defaultBaseBranch` が `main` 以外に
設定されている場合）も一貫させるため、次の3パターンを標準とする。

1. **既定のベースブランチ**（`.mrworkflow.json` の `defaultBaseBranch`。Recommended）
2. **`main`**（`defaultBaseBranch` と異なる場合のみ、明示の選択肢として追加する。一致する場合は
   選択肢が重複するため追加しない）
3. **自由入力**（`AskUserQuestion` が自動提供する「その他」で任意のブランチ名を直接入力する）

このリポジトリでは `defaultBaseBranch` が `main` のため、実際の選択肢は「`main`のまま
（Recommended）」「別のブランチを指定する（自由入力へ誘導）」の2つ＋自動提供の「その他」となる
（`git branch -a` で確認済み。他に長命ブランチは無い）。

## 実施フェーズ

タスク規模が小さく、着手前に必要な調査（関連関数・呼び出し箇所の特定）は本計画作成時点で完了して
いるため、**フェーズ2（調査）は実施せず、フェーズ3（設計・実装）から着手する**。

## 対象範囲（フェーズ3で実施）

1. **`.claude/scripts/src/vcs/Provider.sh` の `new_issue_branch`**: 第3引数（省略可）でベースブランチの
   上書きを受け取れるようにする（現状は `.mrworkflow.json` の `defaultBaseBranch` 固定）。
   `new_draft_merge_request` は既に第4引数 `[<base>]` で上書きに対応済みのため、同じ値をそのまま渡す。
2. **`.claude/skills/issue-mr-flow/SKILL.md` の `start` サブコマンド手順**: 新規ブランチ作成時
   （手順2「見つからない場合」）の直前に、`AskUserQuestion` で「ベースブランチはどれにするか」を
   確認する手順を追加する。選択肢は上記「既定のベースブランチ／`main`（`defaultBaseBranch`と異なる
   場合のみ）／自由入力（自動提供の『その他』）」の3パターン。既定以外（`main`固定選択、または
   自由入力）が選ばれた場合は、その値を `new_issue_branch`・`new_draft_merge_request` に渡す。
   セッション再開（既存ブランチが見つかった場合）はベースブランチ確認済みのため聞き直さない。
3. **`.claude/docs/spec/issue-mr-workflow.md`**: 上記の関数シグネチャ変更・`start`手順変更を正史へ反映
   する（フェーズ4の設計反映で実施）。あわせて、既定以外のベースブランチを選んだ場合
   `get_branch_work_files`（`origin/<defaultBaseBranch>...HEAD` で差分を取る設計）や `resume` の
   ヒューリスティックが実際のベースとズレる可能性がある既知の制約を「未決定事項・懸念点」に追記する
   （既存の「`resume`の『現在地』判定の精度」の記述と同種の限界として扱う。本issueのスコープでは
   `get_branch_work_files`自体の改修は行わない）。

## 検証方法

- `bash -n` で `Provider.sh` の構文チェック。
- 実際に `start` を新規issue番号で呼び出し、`AskUserQuestion` が表示されること・既定を選んだ場合は
  従来どおり `main` ベースで作成されること・別ブランチを選んだ場合はそのブランチがベースになる
  （`git log --oneline --graph` やDraft MRのbase表示で確認）ことを確認する。

## 未確定事項（実装フェーズで判断）

- `defaultBaseBranch` と `main` が一致する場合に選択肢をどう畳み込むか（本計画では「`main`のまま
  （Recommended）」＋「別のブランチを指定する」の2つ＋自動提供の「その他」とする案を採用済みだが、
  実装時の文言・選択肢構成の細部は `【設計】` 計画で確定する）。
- 「別のブランチを指定する」を明示の選択肢として置くか、`AskUserQuestion` 自動提供の「その他」の
  みに委ねるか（本計画では2択+その他を採用したが、選択肢の冗長性を避けるため「その他」のみに
  一本化する案も実装時に再検討してよい）。
