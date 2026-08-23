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

- flow-id 2-2 の敵対的レビュー（フェーズ2・1回目）を実施。findings 11件のうち、確度×重大度の
  1次振り分けで投稿候補7件 → `select-adversarial-findings.sh` が7件すべてを投稿対象と判定し、
  同一行の1件を併記して**6スレッド**としてPR #193へ投稿した。

## 敵対的レビューで「報告のみ」に留めた4件と、その扱い

MRへは投稿していないが、いずれも妥当だったのでこの push で修正した（内容がMRに残らないため
ここへ書き出す）。

| # | 指摘（要旨） | 確度/重大度 | 対応 |
|---|---|---|---|
| 7 | `HANDOFF.md` の `push回数: 1` と計画HTML・worklog の `push回数 2` が食い違う。正が2つある | minor/medium | 計画HTMLのメタから `push回数` を落とし、`HANDOFF.md` を唯一の正にした |
| 8 | 3ディレクトリという同型項目の並列列挙に対し、issue分割しない判断の記録が計画にも `HANDOFF.md` にも無い | minor/medium | 全体作業計画の方針節と `HANDOFF.md`「判断を迷った内容」へ「分割しない」と理由を記録した |
| 9 | Q6 の「配布物のサイズ」は、`.gemini` が `dist-layers.json` で `layer: exclude` である事実と食い違う | minor/medium | 「配布先で生成される `.gemini/` のサイズ」へ言い換え、全体計画と個別計画のQ6の文言も揃えた |
| 11 | 全体作業計画がplanツール製でなくファイル名も自動命名ではない。記録が `HANDOFF.md` にしか無く flow-id 5-5 で消える | nit/high | 全体作業計画 md の冒頭（とHTML）へ逸脱の事実と理由を残した |

指摘9は `.claude/dist-layers.json:13-14` を確認して裏を取った（`{ "layer": "exclude", "path": ".gemini" }`）。

## うまくいったこと

- 全体作業計画・個別調査計画のHTMLビューを、テンプレートの `<style>` ブロックだけを機械的に
  取り出して本文を差し替える形で組み立てた。プレースホルダ残数0・外部依存0・md/HTMLの `##`/`<h2>`
  見出し一致・表のセル数揃いを、その場でスクリプト検査した。

## ダメだったこと

- `SKILL.md` の全体フロー表から進捗表を機械生成しようとしたが、ステップ列を最初の句点で切ると
  括弧が閉じない行が出た。進捗表は手で短く書き直した。

- 敵対的レビューの指摘「Q3/Q4 はリテラル文字列のgrepでは原理的に0件になる」が、この計画自身が
  方針節で警戒していた空振りそのものだった。**自分で警戒を書いた箇所ほど、検証手順の側で
  同じ罠を踏んでいないかを別途確かめる**必要がある。

## 次の一歩

- flow-id 2-6 で Q1〜Q6 を実測し `wip/reports/` へ記録する。書き直した検証手順
  （リンク解決による判定・「元」側での件数・残るファイル基準のQ4）に従うこと。

---
