---
title: worklog 20260818 【設計】【実装】ベースブランチ確認のAskUserQuestion化 push2
type: log
description: issue #15対応。startサブコマンドのベースブランチ確認をAskUserQuestion化する実装のworklog
tags: [worklog, issue-mr-flow, base-branch]
keywords: [start, new_issue_branch, new_draft_merge_request, defaultBaseBranch, AskUserQuestion, Provider.sh, SKILL.md]
---

# worklog: 【設計】【実装】ベースブランチ確認のAskUserQuestion化（実装）

対象: issue #15「issueからMRを作成するときにどれをベースにするかユーザに聞く」対応（2026-08-18）。
全体作業計画: `plans/woolly-tickling-thimble.md`
個別作業計画: `plans/【設計】【実装】ベースブランチ確認のAskUserQuestion化.md`
push回数: 2

## 試したこと

- `Provider.sh`の`new_issue_branch`に第3引数（ベースブランチ上書き、省略可）を追加し、
  `base_branch="${3:-$(...)}"`の形で従来の`defaultBaseBranch`フォールバックを維持した。
- `SKILL.md`の`start`サブコマンド手順2「見つからない場合（新規作成）」の先頭に、ベースブランチを
  `AskUserQuestion`で確認する手順（a.）を追加し、既存の英語フレーズ作成・ブランチ作成手順を
  b./c.へ繰り下げた。

## 作業中に起きたこと（本タスクとは別件）

- コミット直前、`.claude/skills/issue-mr-flow/SKILL.md`と`.claude/skills/commit/SKILL.md`に、
  ユーザーがエディタ上で並行編集中の未コミット変更（前者はフェーズ2/3の実施要否に関する記述の
  修正、後者は`ai-asset` prefixの追加）が既にステージング済みで存在することに気づいた。
  当初は自分の変更だけをパッチで分離してコミットする案を提示したが、ユーザーから「一緒に
  コミットする」との回答を得たため、分離は行わず通常のcommitスキルのフロー（prefixごとの
  自動分割）に従って一緒にコミットした。
- 結果として、1つ目のコミット（`feat: new_issue_branchにベースブランチ上書き用の第3引数を追加`）に、
  `create-commit.sh`が`git add -- <指定ファイル>`の後に`git commit`（インデックス全体をコミット）
  する実装のため、その時点で既にステージングされていた`commit/SKILL.md`のai-asset追加と
  `issue-mr-flow/SKILL.md`のユーザー編集分（の一部）が意図せず同梱された。実害は無い
  （内容の欠落・破壊は無く、全て正しくコミットされている）が、コミットメッセージの粒度が
  やや不正確になった点は次回以降の注意点として記録する。

## うまくいったこと

- `Provider.sh`の`bash -n`構文チェックはコミット前後ともにOK。
- ユーザーの並行編集内容を一切失うことなく、全ての変更が最終的に正しくコミットされた
  （`git status --porcelain`が空になることを確認済み）。

## ダメだったこと

- 特になし。

## 次の一歩

- flow-id 3-7: `commit`スキル経由でcommitし、push してレビュー依頼を行う
- flow-id 3-8〜3-9: レビュー完了の連絡を待つ

---
