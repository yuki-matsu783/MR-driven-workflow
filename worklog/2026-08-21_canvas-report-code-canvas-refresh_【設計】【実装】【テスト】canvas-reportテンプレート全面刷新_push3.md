---
title: worklog: canvas-reportテンプレート全面刷新 push3（敵対的レビュー対応）
type: log
description: issue #141対応の詳細な試行錯誤ログ（push3。敵対的レビュー1回目の指摘対応）。
tags: [worklog, canvas-report, adversarial-review]
keywords: [敵対的レビュー, jumpTo, LOD, 実測レイアウト, エスケープ, 進捗表, 反証]
---

# worklog: 【設計】【実装】【テスト】canvas-reportテンプレート全面刷新 push3

対象: 敵対的レビュー1回目（フェーズ3・diff全体）の指摘対応（2026-08-21）。
全体作業計画: `plans/canvas-report-code-canvas-refresh.md`
個別作業計画: `plans/【設計】【実装】【テスト】canvas-reportテンプレート全面刷新.md`
push回数: 3

## 試したこと

- adversarial-reviewスキルの手順どおり実施（回数1/3・観点表収集済み・サブエージェント
  独立コンテキスト）。14件検出、確度×重大度マトリクスで10件投稿・4件報告のみ。
- 全14件へ対応し、Playwright検証（テンプレート34・不正データ7・実データ16項目）を再実行。

## うまくいったこと

- jumpTo/fitを「scale確定→applyLevels→測定」の順へ直したことで、検索ジャンプの着地精度
  （画面中央±150px）を機械検証に追加できた。
- レイアウトを「概算で仮配置→DOM実測→再配置」の2パスにし、ラベル折り返しによる
  見積もり超過での重なりリスクを解消した。

## ダメだったこと

- 指摘のうち1件（world幅1560はWRAP_W定数の書き写しという指摘）は、再現計算が座標上書き
  パスの `cls.x + CLASS_W + WORLD_PAD` 項を見落としたもので、ブラウザ実測は修正前後とも
  1560だった。反証を確認して棄却（返信で説明）。敵対的レビューの指摘も鵜呑みにせず
  実測で突き合わせるのが正しい、という実例になった。

## 次の一歩

- commit/push → スレッド返信 → flow-id 5系（片付け・Draft解除）。
