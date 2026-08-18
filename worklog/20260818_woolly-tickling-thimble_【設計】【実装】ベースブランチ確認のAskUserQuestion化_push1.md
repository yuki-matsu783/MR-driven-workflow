---
title: worklog 20260818 【設計】【実装】ベースブランチ確認のAskUserQuestion化 push1
type: log
description: issue #15対応。startサブコマンドのベースブランチ確認をAskUserQuestion化する設計・実装のworklog
tags: [worklog, issue-mr-flow, base-branch]
keywords: [start, new_issue_branch, new_draft_merge_request, defaultBaseBranch, AskUserQuestion, Provider.sh, SKILL.md]
---

# worklog: 【設計】【実装】ベースブランチ確認のAskUserQuestion化

対象: issue #15「issueからMRを作成するときにどれをベースにするかユーザに聞く」対応（2026-08-18）。
全体作業計画: `plans/woolly-tickling-thimble.md`
個別作業計画: `plans/【設計】【実装】ベースブランチ確認のAskUserQuestion化.md`
push回数: 1

## 試したこと

- issue #15の本文（「## 目的」のみ、他3見出し欠落）をもとに、要件を「`start`サブコマンドの新規
  ブランチ作成前にベースブランチをAskUserQuestionで確認する」と解釈しスコープを確定した。
- 既存実装を調査: `new_issue_branch`（`Provider.sh`）はベースブランチを常に
  `.mrworkflow.json`の`defaultBaseBranch`から取得し上書き手段が無かった。一方
  `new_draft_merge_request`は既に第4引数`[<base>]`で上書きに対応済みだった。
- `git branch -a`でこのリポジトリの長命ブランチが`main`のみであることを確認。
- `AskUserQuestion`の選択肢構成をユーザにレビューしてもらったところ、「デフォルトブランチ・
  mainブランチ・自由入力」の3パターンを標準とする設計へ修正した（`defaultBaseBranch`と`main`が
  一致する場合は選択肢の重複を避けるため2択+自動提供の「その他」に畳み込む）。

## うまくいったこと

- `new_issue_branch`に第3引数（ベースブランチ上書き、省略可）を追加する方針で、
  `new_draft_merge_request`の既存パターンと一貫性を保てた。
- 選択肢の組み立てを「`defaultBaseBranch`と`main`が一致するかどうか」で条件分岐させることで、
  他リポジトリへ移植した場合（`defaultBaseBranch`が`main`以外）にも自然に対応できる設計にできた。

## ダメだったこと

- 特になし。

## 次の一歩

- `.claude/scripts/src/vcs/Provider.sh`の`new_issue_branch`を実装（第3引数追加）
- `.claude/skills/issue-mr-flow/SKILL.md`の`start`サブコマンド手順にAskUserQuestionステップを追加
- `bash -n`で構文チェック

---
