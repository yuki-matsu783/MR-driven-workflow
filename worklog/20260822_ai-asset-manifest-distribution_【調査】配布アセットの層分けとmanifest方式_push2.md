---
title: worklog 【調査】配布アセットの層分けとmanifest方式
type: log
description: issue #26 の調査フェーズの試行錯誤ログ（push2）
tags: [worklog, distribution, manifest]
keywords: [層分け, manifest, install-to-project, sync-assets, REVIEW-POINTS, sha256, AGENTS]
---

# worklog: 【調査】配布アセットの層分けとmanifest方式

対象: issue #26 AIアセット配布のmanifest方式化（2026-08-22）。
全体作業計画: `plans/ai-asset-manifest-distribution.md`
個別作業計画: `plans/【調査】配布アセットの層分けとmanifest方式.md`
push回数: 2

## 試したこと

- issue #26 の本文とコメント5件をMCP経路で取得した（`gh`/`glab` CLI不在のため
  `mcp__github__issue_read`）。本文は起票時点（2026-08-18）のもので、その後のマージにより
  前提が5件動いていることを確認した。
- 現行の配布経路（`sync-assets.sh` → `assets/` → `install-to-project.sh`）を読み、
  層の概念がどこにも無いこと、`ALWAYS_OVERWRITE_RELPATHS` が事実上 `core` 層の
  1ファイル限定の先行実装になっていることを確認した。

## うまくいったこと

- `.gitattributes` の `dist:begin`/`dist:end` マーカー方式が、issue #26 の `merge` 層が満たすべき
  4性質（冪等／行全体一致／CR除去／末尾改行）を既に満たしていると分かった。層分け定義の形式を
  決める際の比較対象（案B）として使える。

## ダメだったこと

- 特になし。

## 次の一歩

- 調査1（配布対象パスの全数棚卸し）から着手する。
