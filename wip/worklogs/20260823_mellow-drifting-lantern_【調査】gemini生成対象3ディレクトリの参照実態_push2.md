---
title: "worklog: 【調査】gemini生成対象3ディレクトリの参照実態 push2"
type: log
description: issue #172 のフェーズ2〈調査〉における試行錯誤の詳細ログ
tags: [worklog, gemini, 調査]
keywords: [worklog, 調査, grep, 対照, 参照件数, 相対リンク, sync-gemini-assets]
---

# worklog: 【調査】gemini生成対象3ディレクトリの参照実態

対象: `.gemini/hooks/` `.gemini/scripts/` `.gemini/docs/` を生成対象から外すかの判断材料集め（2026-08-23）。
全体作業計画: `wip/plans/mellow-drifting-lantern.md`
個別作業計画: `wip/plans/【調査】gemini生成対象3ディレクトリの参照実態.md`
push回数: 2

## 試したこと

- flow-id 1-4 の事前調査として、`.gemini/settings.json` の hook `command` が指すパスを確認した
  （`grep -o '\.claude/hooks/[a-z-]*\.sh' .gemini/settings.json`）。5本すべてが `.claude/hooks/…` を
  指しており、`.gemini/` を指す参照は0件だった（`grep -c '\.gemini/' .gemini/settings.json` が 0）。
  これは issue #172 本文の見立てと一致するが、**フェーズ2で対照付きに測り直す**。

## うまくいったこと

- 全体作業計画・個別調査計画のHTMLビューを、テンプレートの `<style>` ブロックだけを機械的に
  取り出して本文を差し替える形で組み立てた。プレースホルダ残数0・外部依存0・md/HTMLの `##`/`<h2>`
  見出し一致・表のセル数揃いを、その場でスクリプト検査した。

## ダメだったこと

- `SKILL.md` の全体フロー表から進捗表を機械生成しようとしたが、ステップ列を最初の句点で切ると
  括弧が閉じない行が出た。進捗表は手で短く書き直した。

## 次の一歩

- flow-id 2-2 の敵対的レビューを受けてから、flow-id 2-6 で Q1〜Q6 を実測する。

---
