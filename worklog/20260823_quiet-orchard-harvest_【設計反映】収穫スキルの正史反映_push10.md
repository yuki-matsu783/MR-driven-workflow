---
title: 'worklog: 【設計反映】収穫スキルの正史反映（push10）'
type: log
description: issue #27 フェーズ4の敵対的レビュー6回目（対象=反映一式）の指摘14件の反映ログ（push10）
tags: [worklog, harvest]
keywords: [敵対的レビュー, フェイルクローズ, merge3, T21b, shell-scripts, REVIEW-POINTS, 縮退モード, upstreamDeleted]
---

# worklog: 【設計反映】収穫スキルの正史反映（push10）

対象: issue #27 フェーズ4・敵対的レビュー6回目の指摘反映（2026-08-23）。
push回数: 12

## 試したこと

- 敵対的レビュー6回目（フェーズ4・対象=反映一式。カウンタ 2/3）の findings 14件
  （major 5・minor 9。インライン12・PR diff 外の2件はサマリ報告）をすべて反映した。
- **実装の修正（最重要）**: merge3 の層判定フェイルクローズに穴があった——manifest は
  読めるが当該パスの記録が無く、dist-layers.json でも解決できない場合、層未確定のまま
  3-way が走り exit 0 を返していた（レビュアが seed 層 AGENTS.md で再現）。層が確定しなければ
  exit 3 で止める形へ修正し、T21b で固定した（89→91 アサーション、passed=91 failures=0）。
- **旧前提の残存2箇所を訂正**: `spec/shell-scripts.md`「設計方針」の try/catch 節と
  `.claude/REVIEW-POINTS.md`「スクリプトの作法」の観点が、「フォークされた側では set -e が
  正しく機能する」という否定済みの前提を保持していた。いずれも2機構の書き分けへ訂正。
- spec `harvest-from-projects.md` の実装との齟齬7点を訂正（縮退条件へ dist-layers 不読を
  追加・条件付き出力キーの明記・removedUpstream と upstreamDeleted の情報源分離・conflict
  判定の dist-layers 除外・git 起動の cat-file/ls-files 追記・`--upstream`/`-h` の記載・
  フェイルクローズの境界明記）。SKILL.md はスキーマ・終了コードの重複を spec への
  リンクへ置き換え（正を1箇所へ）。
- 反映結果レポート（md/html）の検証を「リポジトリ横断の旧前提 grep ＋全ヒット仕分け」へ
  改め、検証9種として更新した。

## うまくいったこと

- 「異常が無ければ何も出ない検証は、パターンが実データに合っていないと常に成功する」の
  実例を自分の検証3で踏んでいたことがレビューで判明し、横断 grep へ改めたことで規範として
  旧前提を述べる記述が 0 件であることを確認できた。

## ダメだったこと

- フェイルクローズを「manifest と dist-layers の両方が読めないとき」だけ実装し、
  「manifest は読めるが当該パスの記録が無い」ケースを見落としていた（spec・DDR には
  正しい意図を書いたのに、実装がそれより狭かった）。仕様文書を先に書いた場合も、
  実装との突き合わせは境界ケース単位で行うこと。

## 次の一歩

- commit・リモート反映 → 12スレッドへ返信・未返信0へ → フェーズ5
  （5-1 コンフリクト検知は報告まで・5-3 gemini同期・5-4 統括レポート・5-5 片付け・
  5-6 Draft解除）。

---
