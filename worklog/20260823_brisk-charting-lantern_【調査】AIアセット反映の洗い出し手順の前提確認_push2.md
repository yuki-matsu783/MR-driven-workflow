---
title: worklog 20260823 【調査】AIアセット反映の洗い出し手順の前提確認 push2
type: log
description: issue #155 フェーズ2〈調査〉の試行錯誤ログ（push2時点）。
tags: [worklog, issue-mr-flow, ai-asset]
keywords: [worklog, 調査, doc-search, SKILL.md, flow-id 4-1, flow-id 4-6, 敵対的レビュー]
---

# worklog: 【調査】AIアセット反映の洗い出し手順の前提確認

対象: issue #155「AIアセット反映の対象を洗い出す手順を定義する（flow-id 4-1・4-6）」（2026-08-23）。
全体作業計画: `plans/brisk-charting-lantern.md`
個別作業計画: `plans/【調査】AIアセット反映の洗い出し手順の前提確認.md`
push回数: 2

## 試したこと

- flow-id 1-3: `mcp__github__create_pull_request` でDraft PRを作成しようとしたところ、
  1回目は `PullRequest.head (invalid)` で失敗した。ブランチとmainの差分が0のため。
  空コミット（`add_empty_commit_for_draft_mr`）で無理に通さず、全体作業計画のコミットを
  先にリモートへ反映してから再実行したところ成功した（PR #175）。
- flow-id 2-1: 個別調査計画を作成した。HTMLビューはテンプレートの `<style>` を機械的に取り込む
  スクリプト（`/tmp/.../gen_plan_html.py`）を用意し、本文だけを書く形にした。

## うまくいったこと

- HTMLビューの検査（プレースホルダ0件・外部読み込み0件・md/HTMLの見出し一致）を、
  生成のたびに同じコマンド列で流せるようにした。

## ダメだったこと

- md側の見出しを「変更対象（領域の粒度）」、HTML側を「変更対象」と書き、突き合わせ検査で
  不一致になった。md側を「変更対象」へ揃えた（`plans/REVIEW-POINTS.md`「HTML版」の観点）。

## 次の一歩

- 敵対的レビュー（フェーズ2・計画に対して1回）を実施し、指摘へ対応する。
- flow-id 2-6: Q1〜Q6の調査を実施し `reports/` へ記録する。

---
