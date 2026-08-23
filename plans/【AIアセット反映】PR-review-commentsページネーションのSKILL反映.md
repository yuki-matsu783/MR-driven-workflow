---
title: 【AIアセット反映】PR review-commentsページネーションのSKILL反映
type: plan
description: issue #105フェーズ4の個別反映計画。gh/glab CLI不在時のMCPフォールバックで実際に踏んだページネーションパラメータの罠を、issue-mr-flow/SKILL.mdへ反映する
tags: [ai-asset, mcp, github, issue-105]
keywords: [pull_request_read, get_review_comments, cursor, after, ページネーション]
---

# 【AIアセット反映】PR review-commentsページネーションのSKILL反映

## 前提（合意状況）

- 上位の計画: `plans/squishy-painting-coral.md`（全体作業計画、flow-id 1-5で合意）。
- 本計画はフェーズ3のレビュー往復（flow-id 3-9）で**このセッション自身が実際に踏んだ**
  AIアセットの不備を反映する「作業中に気づいたルール・スキルの不備」（flow-id 4-6の
  「AIアセット反映」に相当する作業）の計画。

## この計画で何をするか

`mcp__github__pull_request_read`（method="get_review_comments"）のページネーションで、
2回連続して**誤ったパラメータ名`cursor`**を使い、`hasNextPage: true`のまま同一ページが
返り続ける現象を実際に踏んだ（正しいパラメータ名は`after`）。この罠を
`.claude/skills/issue-mr-flow/SKILL.md`「`gh`/`glab` CLI不在時のMCPフォールバック」節へ
注記として追記し、次のセッションが同じ回り道をしないようにする。

## 変更対象

| ファイル | 種別 | 内容 |
|---|---|---|
| `.claude/skills/issue-mr-flow/SKILL.md` | 変更 | 「`gh`/`glab` CLI不在時のMCPフォールバック」節の`get_review_comments`対応行へ、正しいページネーションパラメータ名（`after`。`cursor`ではない）を注記する |

## 方針

1. 対応表（Provider関数・サブコマンドごとのMCPツール対応表）の`comments`サブコマンド関連の行を
   探し、`get_review_comments`のページネーションに関する既存の記載を確認する。
2. パラメータ名の注記を追加する。**「`after`が正、`cursor`は誤り」という否定形ではなく、
   「ページネーションは`after`パラメータ（`perPage`と併用可、最大100）を使う。誤ったパラメータ名を
   渡すと`hasNextPage: true`のまま同一ページが返り続ける」という実際に踏んだ症状を含めて書く**
   （症状を書くことで、次に踏んだ人が「あ、これだ」と気づける）。
3. 併せて、`get_reviews`で全レビュー本文を横断確認する手法（自分の投稿と人間の投稿を、
   本文パターンで判別する）も、`get_review_comments`だけでは判別しづらい場面の代替手段として
   一言だけ触れる（過度な詳述はしない。SKILL.mdの簡潔さを保つため）。

## やらないこと（スコープ外）

- 他のMCPツール（`add_comment_to_pending_review`等）の網羅的な再検証。今回実際に問題が
  起きたのは`get_review_comments`のページネーションのみ。
- `Provider.sh`本体への変更（`gh`/`glab` CLIが使える環境では発生しない問題のため、
  MCPフォールバック節のみの注記で足りる）。

## 検証

```bash
grep -n 'after\|cursor' .claude/skills/issue-mr-flow/SKILL.md
```

- 合格条件: 上記コマンドの出力に、`get_review_comments`のページネーションパラメータが
  `after`であることの記載が含まれていること。
