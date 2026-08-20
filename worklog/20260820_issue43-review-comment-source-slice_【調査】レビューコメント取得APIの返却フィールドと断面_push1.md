---
title: worklog 20260820 issue43 調査（push1）
type: log
description: issue #43 のレビューコメント出力仕様見直しにおける、調査フェーズの試行錯誤ログ
tags: [worklog, investigation, vcs]
keywords: [diffHunk, GraphQL, discussions, shallow, blob, スライス, 断面]
---

# worklog: 【調査】レビューコメント取得APIの返却フィールドと断面

対象: issue #43 レビューコメント取得の出力仕様見直し（2026-08-20）。
全体作業計画: `plans/issue43-review-comment-source-slice.md`
個別作業計画: `plans/【調査】レビューコメント取得APIの返却フィールドと断面.md`
push回数: 1

## 試したこと

- `get_vcs_access_mode` を実行して経路を確認 → `mcp`（`gh`/`glab` CLI不在）。
- `check-base-sync.sh` で `main` への追従を確認 → `isBehind: false` / `isShallow: true`。
  **この環境は shallow clone である**ため、コメント時点の sha の blob がローカルに無い可能性が高い。
  調査項目Cの前提として重要。
- `add_empty_commit_for_draft_mr` が `git push`（upstream未設定）で失敗した。ブランチが
  リモートに存在していても、ローカルに upstream 追跡設定が無いと失敗する。
  `git push -u origin <branch>` で解消した。

## うまくいったこと

- 空コミット＋pushの後、`mcp__github__create_pull_request` で Draft PR #131 を作成できた
  （baseとの差分が無い状態では作成できない制約は、MCP経路でもCLI経路と同じだった）。

## ダメだったこと

- 特になし（現時点）。

## 次の一歩

- 調査項目 E（既存実装の棚卸し）から着手する。
