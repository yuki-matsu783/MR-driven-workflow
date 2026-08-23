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
注記として追記する。あわせて、同SKILL.mdの「レビュー完了合図の確認 (2)」節（MCP経路での
未返信スレッド判定手順）が全ページ走査を暗黙の前提にしていることへも注記する（後述「方針」参照）。
`get_reviews`による横断確認の追記は行わない（下記「やらないこと」参照）。

## 変更対象

| ファイル | 種別 | 内容 |
|---|---|---|
| `.claude/skills/issue-mr-flow/SKILL.md` | 変更 | (a) 「`gh`/`glab` CLI不在時のMCPフォールバック」節の`get_review_comments`対応行へ、正しいページネーションパラメータ名（`after`。`cursor`ではない）を注記する。(b) 「レビュー完了合図の確認 (2)」節のMCP経路の記述へ、`hasNextPage`が偽になるまで`after`で全ページを走査してから未返信判定を行う旨を追記する |

## 方針

1. 対応表（Provider関数・サブコマンドごとのMCPツール対応表）の`comments`サブコマンド関連の行を
   探し、`get_review_comments`のページネーションに関する既存の記載を確認する。
2. パラメータ名の注記を追加する。**「`after`が正、`cursor`は誤り」という否定形ではなく、
   「ページネーションは`after`パラメータ（`perPage`と併用可、最大100件/回。ツール定義に明記されて
   いる値）を使う。誤ったパラメータ名を渡すと`hasNextPage: true`のまま同一ページが返り続ける」
   という実際に踏んだ症状を含めて書く**（症状を書くことで、次に踏んだ人が「あ、これだ」と気づける。
   `perPage`の上限100はこのセッションでMCPツールのスキーマを直接確認した値であり、未検証の
   伝聞ではない）。
3. **「レビュー完了合図の確認 (2)」節への波及も併せて直す**（このページネーションの罠が実害を
   持つ本質的な理由）。同節のMCP経路は「各スレッドの`comments`配列が1件かどうか」で未返信を
   判定するが、この判定は**全スレッドを取得できていること**が前提になっている。今回は「同じ
   ページが返り続ける」という目立つ形で表面化したが、より危険なのは2ページ目以降を取らずに
   判定を終える場合で、未返信スレッドを取りこぼしたまま`set-header --unreplied 0`を書き、
   ループ範囲へ`mark-done`できてしまう（issue #70・#109が防ごうとした状態そのもの）。
   同節のMCP経路の箇条書きへ「`hasNextPage`が偽になるまで`after`で全ページを走査してから
   判定する」ことを追記する。

## やらないこと（スコープ外）

- 他のMCPツール（`add_comment_to_pending_review`等）の網羅的な再検証。今回実際に問題が
  起きたのは`get_review_comments`のページネーションのみ。
- `Provider.sh`本体への変更（`gh`/`glab` CLIが使える環境では発生しない問題のため、
  MCPフォールバック節のみの注記で足りる）。
- `get_reviews`で全レビュー本文を横断確認する手法の追記。今回このセッションで代替手段として
  実際に使ったが、目的（ページネーションの罠の注記）から外れる別トピックであり、追記先・
  合格条件を定義すると計画が肥大化するため見送る。必要になった時点で別途反映する。

## 検証

```bash
grep -n 'after\|cursor' .claude/skills/issue-mr-flow/SKILL.md
grep -n 'hasNextPage' .claude/skills/issue-mr-flow/SKILL.md
```

- 合格条件: 1つ目のコマンドの出力に、`get_review_comments`のページネーションパラメータが
  `after`であることの記載が含まれていること。2つ目のコマンドの出力に、「レビュー完了合図の
  確認 (2)」節のMCP経路が全ページ走査を前提とする旨の記載が含まれていること。
