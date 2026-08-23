---
title: worklog 20260823 【調査】残置テキストの係り先ルールの射程と重複を洗い出す push1
type: log
description: issue #142 フェーズ2の調査における試行錯誤ログ（push1）
tags: [worklog, research, docs-workflow]
keywords: [係り先, 残置テキスト, 射程, 重複, DDR, 敵対的レビュー, issue142]
---

# worklog: 【調査】残置テキストの係り先ルールの射程と重複を洗い出す

対象: `.claude/rules/docs-workflow.md` の「見出しの差し込み時に係り先を確認する」ルールの一般化（2026-08-23）。
全体作業計画: `plans/brisk-weaving-lantern.md`
個別作業計画: `plans/【調査】残置テキストの係り先ルールの射程と重複を洗い出す.md`
push回数: 1

## 試したこと

- issue #142 本文とコメント2件を MCP（`mcp__github__issue_read`）で取得した。CLI（`gh`）は
  この実行環境に無く、`get_vcs_access_mode` が `mcp` を返す。
- Draft PR 作成時、ブランチと `main` の差分が0だったため `create_pull_request` が失敗する見込みだった。
  `add_empty_commit_for_draft_mr` で空コミットを作ってから作成した。
- 計画HTMLは、テンプレート（`assets/plans.template.html`）の DOCTYPE〜`/head` を切り出して
  body を差し込む使い捨てスクリプトを scratchpad へ置いて生成した（`.claude/rules/ai-command-style.md`
  「切り出し先の選び方」に従い、使い捨てなので `.claude/scripts/src/` へは置かない）。
- md と HTML の同期確認は、md の `##`/`###` と HTML の `h2`/`h3` を正規化して突き合わせる
  Python スクリプトで行った（バッククォートと `code` タグの差を落としてから比較する）。
- 表の列ずれ検査は、各 `table` の `td`/`th` の数が全行で揃っているかで見た。
- flow-id 2-6 の調査:
  - Q2 は「係り先」で2件しか返らず、「地の文」は43件と主題がばらばらだった。**「見出し」と「地の文」を
    同一行に持つ行**へ絞る（7件）ことで、1件ずつ主題を判定できる粒度にした。
  - Q4 は `search-frontmatter.sh --type ddr --text '見出し'` が `matched=0`（frontmatterのキーしか見ないため）。
    本文検索 `grep -rln '係り先\|地の文' .claude/docs/ddr/` へフォールバックし、6件を `description` で判定した。
  - Q5 は `collect-review-points.sh` を `.claude/rules/docs-workflow.md` に対して実際に流し、出力に
    `rules` 由来の行が1つも無いことを確認した（実装の `for base in "REVIEW-POINTS.md" "REVIEW-POINTS.local.md"` と一致）。
  - 検証コマンドの空振り確認は、対象ファイルを `cp` でバックアップ → `sed -i` で実例行を削除 → コマンド実行 →
    復元、の順で2回行った。最後に `git status --porcelain` が空であることを確かめた。

## うまくいったこと

- 同型の事故が **4件**（issue #64 / #109 / PR #139 / issue #155）あることを、issue本文と
  通知コメント2件だけで確定できた。**発掘のための横断調査が要らない**と判断できたため、
  調査項目からその作業を外した（スコープ外へ明記）。

## ダメだったこと

- **暫定案の「構造変更全般」という言い換えでは issue #155 を取りこぼす。** 「構造変更」自体が操作の
  分類であり、「箇条書きへ項を1つ足す」を含むかどうかが読み手に委ねられる。**発動条件を操作の側では
  なくリスクの側（残置テキストの周囲が変わったか）で書く**必要がある——これが調査で得た最大の収穫。
- **上位計画と個別計画で「壊れた位置」の軸がずれていた。** 上位計画は「分割点から見た位置」
  （#109 は「(1) の直後」）、個別計画は「新しく書いた部分から見た位置」（#109 は「前」）で書いており、
  同じ事例が前とも後ろとも読めた。敵対的レビューが検出。**新しく書いた部分から見た軸へ統一**した。
  皮肉なことに、これはこのissueが扱っている「係り先の食い違い」そのものである。
- **全体作業計画の md と html が同期していなかった。** 検証コマンドと「変更対象」節が html に
  しか無く、正文（md）側が `plans/REVIEW-POINTS.md` の観点を満たしていなかった。md を正として
  html を作り直し、見出しの突き合わせスクリプトで一致を確認する運用にした。

## 次の一歩

- flow-id 2-7: commit・push・敵対的レビュー（フェーズ2の調査結果に対する2回目）。
