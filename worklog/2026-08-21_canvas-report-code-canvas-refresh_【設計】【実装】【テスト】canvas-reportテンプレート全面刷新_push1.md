---
title: worklog: canvas-reportテンプレート全面刷新 push1
type: log
description: issue #141対応の詳細な試行錯誤ログ（push1）。
tags: [worklog, canvas-report]
keywords: [Code Canvas, セマンティックズーム, 自動レイアウト, Playwright, 検証]
---

# worklog: 【設計】【実装】【テスト】canvas-reportテンプレート全面刷新

対象: canvas-reportテンプレートのCode Canvas全面刷新（2026-08-21）。
全体作業計画: `plans/canvas-report-code-canvas-refresh.md`
個別作業計画: `plans/【設計】【実装】【テスト】canvas-reportテンプレート全面刷新.md`
push回数: 1

## 試したこと

- issue #141本文の不具合表1〜12と現行テンプレート468行を突き合わせて再確認した。
- データモデルを「フラットなnodes配列＋parent参照」とする設計を採用（循環parent検出を
  データ表現として成立させるため。ネスト記法だと循環が原理的に書けず受け入れ条件を満たせない）。

- CDN到達性を実測したところ `cdn.tailwindcss.com`・`cdn.jsdelivr.net` ともプロキシ遮断
  （exit 56）だった。→ エンジン・スタイルを自前CSSで自己完結させ、外部依存を任意の
  mermaid.jsのみに絞る設計へ変更（旧不具合5・6の根本原因もTailwind依存だったため一石二鳥）。
- Playwright（npm install可）＋同梱Chromium（`executablePath: '/opt/pw-browsers/chromium'`。
  バージョン不一致でnpx installは不要かつ不可）で検証ハーネスを構築。テンプレート同梱
  サンプル34項目・不正データ7項目・実データ15項目の機械検証を通した。

## うまくいったこと

- 折りたたみ/展開・エッジ張り替え・集約（太さ＝本数）・上流/下流色分け・検索ジャンプ・
  トグル・エラーパネルまで、初回実装＋修正2件で全項目パス。
- エッジ端点の実測は `offsetTop`（transform非影響のレイアウト値）で取ることで、CSS
  transformとの干渉なしにメンバ行へ正確に張れた。

## ダメだったこと

- 折りたたみボタンを `pointerdown` のパン対象外にしたことで、独自クリック判定
  （移動閾値4px）に到達せずトグルが無反応になった。→ ボタンはネイティブclickで処理する形へ
  修正（検証4項目がNG→okになった）。
- X座標が近い縦並びクラス間のメンバ行エッジが「右から出て左へ回り込む」自己交差ループに
  なった。→ X範囲が重なる場合は両端とも左辺から出入りするブラケット型ルーティングへ修正。

## 次の一歩

- commit/push → Draft PR作成 → 敵対的レビュー（非対話セッションのため自律起動）→ 指摘対応。
