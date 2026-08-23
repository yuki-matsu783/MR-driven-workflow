---
title: 'worklog: 【調査】コミットメッセージ規約の現状と本文許容の可否'
type: log
description: issue #185 フェーズ2の調査中の試行錯誤ログ（push1）
tags: [worklog, commit, 調査]
keywords: [1行のみ, 本文, create-commit, squash, grep, 調査]
---

# worklog: 【調査】コミットメッセージ規約の現状と本文許容の可否

対象: issue #185「1行コミットログが後から見てもあまり参考にならない形になっているので修正する」（2026-08-23）。
全体作業計画: `wip/plans/keen-charting-lantern.md`
個別作業計画: `wip/plans/【調査】コミットメッセージ規約の現状と本文許容の可否.md`
push回数: 1

## 試したこと

- flow-id 1-3: `add_empty_commit_for_draft_mr` で空コミットを置いてからDraft PR #192 を作成した。
  `gh` CLIが無い環境のため、PR作成は `mcp__github__create_pull_request` で行った
  （`get_vcs_access_mode` は `mcp` を返す）。
- flow-id 1-6: `HANDOFF.md` の進捗表43行を、`SKILL.md` の全体フロー表から `awk` で機械生成した
  （手書きすると flow-id・担当の写し間違いが混ざるため）。

## うまくいったこと

- 進捗表の機械生成。`| [] | <flow-id> | <ステップ> | <担当> |` の形は
  `.claude/scripts/test/test_update_handoff_progress.sh` のフィクスチャが正で、
  `update-handoff-progress.sh mark-done` がそのまま動くことを確認した。

## ダメだったこと

- `git fetch origin main <branch>` を1コマンドで実行したところ、存在しないブランチ側で
  `fatal: couldn't find remote ref` になり、**`main` の取得ごと失敗**した。
  取得できていないのに `origin/main` との差分だけは表示されるため、
  「30コミット先行・446ファイル差分」という誤った現在地を一度信じかけた。
  ブランチを分けて `git fetch origin main` だけを実行し直したところ、実際は 0/0（同一）だった。

## 次の一歩

- flow-id 2-2（commit・push）と敵対的レビュー1回目。
- 調査Q1〜Q5の実施。

---
