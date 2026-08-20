---
title: worklog 【調査】set-headerの無言成功とヘッダ表記の実態 push1
type: log
description: issue #66の調査フェーズの試行錯誤ログ（push1）
tags: [worklog, update-handoff-progress, handoff]
keywords: [set-header, 再現, 挿入位置, 現在のループ, Draft PR, 無言の失敗]
---

# worklog: 【調査】set-headerの無言成功とヘッダ表記の実態

対象: issue #66（`set-header` が対象行を書き換えられなくても無言で成功する）（2026-08-20）。
全体作業計画: `plans/set-header-silent-failure.md`
個別作業計画: `plans/【調査】set-headerの無言成功とヘッダ表記の実態.md`
push回数: 1

## 試したこと

- 実物と同じ形のHANDOFF.md（`## フロー進捗状況` 見出しの下にヘッダ行、PR行は `- Draft PR:`）を
  スクラッチパッドへ作り、`set-header --pr '#999'` を実行した。
- 同じフィクスチャに対して `mark-done 2-3` を実行し、`- 現在のループ:` 行がどこへ挿入されるかを
  見た。

## うまくいったこと

- 無言成功をそのまま再現できた（終了コード0・`diff` で差分なし）。
- **調査計画には無かった2件目の欠陥を、同じ再現手順の中で見つけた**。実物のレイアウトでは
  `- 現在のループ:` 行が `## フロー進捗状況` 見出しの**上**へ挿入され、他のヘッダ項目から離れる。
  既存テストのフィクスチャは見出しを持たない（またはヘッダ項目を持たない）ため、この経路が
  一度も通っていなかった。

## ダメだったこと

- 特になし。

## 次の一歩

- 調査結果を `reports/2026-08-20_set-header-silent-failure_調査結果.md` へ書き、視覚化を
  同名の `.html` として作る（flow-id 2-6）。
