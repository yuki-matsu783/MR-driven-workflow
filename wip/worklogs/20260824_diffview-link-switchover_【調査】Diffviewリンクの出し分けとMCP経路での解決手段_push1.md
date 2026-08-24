---
title: worklog: 【調査】Diffviewリンクの出し分けとMCP経路での解決手段
type: log
description: issue #205 フェーズ2（調査）の試行錯誤ログ
tags: [worklog, issue-mr-flow, research]
keywords: [Diffview, git ls-remote, refs/pull, MCP経路, 敵対的レビュー, 調査]
---

# worklog: 【調査】Diffviewリンクの出し分けとMCP経路での解決手段

対象: issue #205 のフェーズ2〈調査〉（2026-08-24）。
全体作業計画: `wip/plans/diffview-link-switchover.md`
個別作業計画: `wip/plans/【調査】Diffviewリンクの出し分けとMCP経路での解決手段.md`
push回数: 1

## 試したこと

- flow-id 1-2: `mcp__github__issue_read` で issue #205 を取得。この環境は `gh`/`glab` CLI が
  無く `get_vcs_access_mode` は `mcp` を返すため、以降のVCS操作はすべてMCP経路。
- flow-id 1-3: `mcp__github__create_pull_request` で Draft PR #206 を作成。
  `subscribe_pr_activity` で追従監視を開始。
- flow-id 1-4: 全体作業計画（md+html）を作成。HTMLはテンプレートの `<!DOCTYPE>` 〜 `</head>`
  をそのまま流用し、body だけ書き下ろす形にした（リンク破断・重複IDの検査は0行で合格）。
- **push直後のhookが、本issueが直そうとしている問題をそのまま再現した。**
  レビュー依頼メッセージの「defaultブランチとの差分」は
  `https://github.com/.../compare/main...claude/pr-mr-diffview-link-yxim1l` という
  Compareページで、MRリンクは「CLI不在のため未取得」だった。**問題の実在を実測で確認できた。**

## うまくいったこと

- HANDOFF.md の進捗表を手書きで組み立てたところ、`update-handoff-progress.sh mark-done` が
  そのまま動いた（行判定の正規表現 `ROW_RE` が要求する
  `| [記号] | <flow-id> | …` の形に合っていた）。

## ダメだったこと

- 進捗表のステップ名を `awk` で SKILL.md から自動抽出しようとしたところ、
  **mawk の `substr`/`sub` がバイト単位で切るため日本語が壊れた**
  （`.claude/rules/shell-script-style.md`「日本語を含む文字列の先頭を切り出して比較しない」に
  記録済みの罠と同型）。手書きのラベルへ切り替えた。

## 次の一歩

- 個別調査計画に対する敵対的レビュー（1回目）を実行し、指摘へ対応する。
- Q1〜Q6の調査を実施し、`wip/reports/` へ結果を記録する。
