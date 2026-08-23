---
title: worklog: 【調査】pptx書き出しの前提調査
type: log
description: issue #169 フェーズ2〈調査〉の詳細な試行錯誤ログ（push1）
tags: [worklog, pptx, research]
keywords: [worklog, pptx, OOXML, zip, 調査, 試行錯誤]
---

# worklog: 【調査】pptx書き出しの前提調査

対象: 構成案JSONから編集可能な .pptx を書き出す機能の前提調査（2026-08-23）。
全体作業計画: `wip/plans/json-to-pptx-export-plan.md`
個別作業計画: `wip/plans/【調査】pptx書き出しの前提調査.md`
push回数: 1

## 敵対的レビュー（フェーズ2の1回目・対象=計画ファイル）

- 指摘14件（major3・minor10・nit1）。確度×重大度の1次振り分けで7件を投稿候補とし、
  `select-adversarial-findings.sh` の選別で7件全件をPR #199へインライン投稿（サマリ0件）。
- **報告のみに留めた7件**（1次振り分けで「報告」区分。すべて計画へ反映済み）:
  1. [minor/medium] python-pptxの扱いが上位計画と食い違う → Q3へ「生成では却下・検証では
     既在の場合のみ併用（新規インストールしない）」の線引きを明記（Q6と同一の線引きと注記）。
  2. [minor/medium] フェーズ4候補に `.claude/VERSION` が無い → 全体計画のフェーズ4候補へ
     「増分の提案（資産追加=MINOR）または据え置きの記録」を追加。
  3. [minor/medium] Q5のtype名の出典が無くQ2に先行 → 「Q2で確定したtype集合を前提とする」
     とし、出典（PR #194調査レポートQ5）を明記。
  4. [minor/medium] 依存の根拠がPR #194のwip/reports/にあり消える／依存が崩れた場合の停止条件が
     無い → Q2へ「こちら側レポートへの転記」と「差分発生時・#194クローズ時の分岐」を追加。
  5. [minor/medium] issue分割判定の痕跡が無い → 全体計画へ「issue分割の判定」節を追加
     （分割しない理由: 6型は単一スクリプト内の分岐で横断的変更。最終判断は人間）。
  6. [minor/medium] planツール逸脱が計画本体に書かれていない → 全体計画冒頭へ「planツールを
     使わずWriteで作成・このファイルが唯一の全体作業計画」を明記。
  7. [nit/high] 括弧の全角/半角揺れ・「実測root」という語 → 全角へ統一し「実測して記録する項目」
     の表現へ書き直し。
- 投稿した7件も同コミットで計画（md+HTML両方）へ反映した。

## 試したこと

- issue #169・PR #194（依存元）の状況確認。PR #194 はフェーズ2〈調査〉完了直後のDraft。
  スキーマは方針レベル（8種type enum・meta・型別フィールド・speakerNotes）まで。
- この実行環境の実測: `zip`(/usr/bin/zip)・`unzip`(/usr/bin/unzip)・`python3`(/usr/local/bin/python3)・
  `node`(/opt/node22/bin/node) の所在を確認。
- Draft PR #199 を作成し、`subscribe_pr_activity` で追従監視を開始。

## うまくいったこと

- ベースブランチ追従確認（check-base-sync.sh）: behind 0 で取り込み不要。

## ダメだったこと

- 特になし。

## 次の一歩

- 調査計画のpush → 敵対的レビュー（フェーズ2の1回目）→ 指摘対応 → 調査実施（Q1〜Q6）。

---
