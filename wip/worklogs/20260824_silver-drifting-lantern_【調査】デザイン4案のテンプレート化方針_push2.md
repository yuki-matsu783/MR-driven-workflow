---
title: worklog 【調査】デザイン4案のテンプレート化方針 push2
type: log
description: issue #203 フェーズ2の調査における試行錯誤ログ
tags: [worklog, issue-mr-flow, template]
keywords: [Tailwind, DOM比較, 検査コマンド, 節対応, design-samples, issue203]
---

# worklog: 【調査】デザイン4案のテンプレート化方針

対象: issue #203 のフェーズ2〈調査〉（2026-08-24）。
全体作業計画: `wip/plans/silver-drifting-lantern.md`
個別作業計画: `wip/plans/【調査】デザイン4案のテンプレート化方針.md`
push回数: 2

## 試したこと

- `origin/claude/report-template-design-0bpul1` を fetch し、`git show FETCH_HEAD:<path>` で
  サンプル06・10・12・13・16 をscratchpadへ取り出した（作業ブランチへは持ち込まない）。
- 全体作業計画・調査計画のHTMLビューを、`plans.template.html` の `<style>` ブロックを
  `awk '/^<style>/,/^<\/style>/'` で抜き出して再利用する形で組み立てた。

## うまくいったこと

- **`<style>` ブロックの抜き出し＋本文の差し替え**という組み立て方で、テンプレートのスタイルを
  1バイトも変えずにHTMLビューを作れた。手で書き写すと、テンプレート側の更新に追随できなくなる。
- 4検査（プレースホルダ・リンク破断・重複ID・外部依存）を、HTMLを書いた直後に流す運用にした。
  外部依存検査は現行テンプレートのコメントには無いが、`grep -nE 'https?://|<script|<img|@import|url\('`
  で機械的に確認できる。**ただし `&lt;script` のようにエスケープされた地の文にも当たる**ため、
  ヒットしたら中身を見て判断する必要がある（実際に全体作業計画で1件ヒットし、Tailwind CDNへの
  言及であることを確認した）。

## ダメだったこと

- 特になし（この時点までは）。

## 次の一歩

- 敵対的レビュー1回目（調査計画に対して）を実施し、指摘へ対応する。
- Q1〜Q5の調査を実施する（flow-id 2-6）。
