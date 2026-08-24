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

- **敵対的レビュー（フェーズ2・1回目）を実行**。12件検出（major 9 / minor 3）、11件を
  PR #206 へインライン投稿、全11スレッドへ返信、計画へ反映した。
- Q1〜Q6の調査を実施し、`wip/reports/20260824_diffview-link-switchover_調査結果.md`
  （+ `.html`）へ記録した。

## うまくいったこと（追記）

- **`git ls-remote origin 'refs/pull/*/head'` でPR番号を解決できた。** push直後に
  `refs/pull/206/head` が現在のHEADと一致し、伝播遅延は観測されなかった。
  MCPツールを一切使わず、gitだけで完結する。
- **敵対的レビューの指摘が、実際に設計を変えた。** とくにQ5について、当初は「土台が二重に
  決まらないかの整理」程度に考えていたが、レビューが `gitlab_get_diff_anchor_base_url` の
  3分岐と `glab api` 呼び出しを突いたことで、**素直に実装すると差分アンカーが壊れる（後退する）**
  ことに気づけた。土台と `diff_url` を分離する設計はこの指摘の産物である。

## ダメだったこと（追記）

- **GitHubの `/pull/<n>/files` というURL形式を、一次情報で裏取りできなかった。**
  試したのは4手段（リポジトリ内の読解／GitHub MCPツールの返却値／ブラウザ目視／WebFetch・curl）。
  MCPツールが返す `html_url` はPR本体（`/pull/206`）までで、`/files` を含むURLは返らない。
  ブラウザはこの環境に無く、WebFetch・curlはDDR i0014-01・i0034-01 により使わない。
- **計画で立てた停止条件（Q1が不明ならissueへ差し戻す）に、字面上は該当した。**
  それでも進めたのは、URL形式がAIの推測ではなく**issue #205 本文でリポジトリ所有者が指定した
  もの**だからである。判断の根拠は調査結果レポートの章1に記録し、
  **重点レビュー依頼の筆頭に置いて人間の確認を求めている。**
- **`mcp__github__create_pull_request` に渡した本文中の `refs/pull/*/head` が、投稿後に
  `refs/pull//head` になっていた**（アスタリスク2文字が消失）。バックティックで囲んだ
  インラインコード内でも消える。`references/mcp-fallback.md` の「不等号で始まる語で本文が
  切り捨てられる」と同種の無言の本文改変。インラインコメント投稿では山括弧を全角へ置換して
  回避し、11件すべてで切り捨ては起きなかった。

## 次の一歩

- 調査結果に対する敵対的レビュー（フェーズ2・2回目）を実行し、指摘へ対応する。
- flow-id 3-1: 調査結果をもとに `【実装】【テスト】` の個別作業計画を作成する。
