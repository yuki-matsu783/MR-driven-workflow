---
title: 'worklog: 【AIアセット作成】【実装】【テスト】収穫スキルの新設（push4）'
type: log
description: issue #27 フェーズ3計画の敵対的レビュー（3回目）の反映ログ（push4）
tags: [worklog, harvest]
keywords: [敵対的レビュー, baseApproximate, upstreamDeleted, cat-file --batch, schemaVersion, T12, T15]
---

# worklog: 【AIアセット作成】【実装】【テスト】収穫スキルの新設（push4）

対象: issue #27 敵対的レビュー3回目（フェーズ3・対象=個別作業計画）の反映（2026-08-23）。
全体作業計画: `plans/quiet-orchard-harvest.md`
個別作業計画: `plans/【AIアセット作成】【実装】【テスト】収穫スキルの新設.md`
push回数: 6

## 試したこと

- 敵対的レビュー3回目を実施。findings 20件（major 13・minor 7）。選別スクリプトの結果、
  major 13件をインライン投稿・minor 7件は報告のみ（サマリコメントへ内訳記載）。
  修正は20件すべて計画 md/html へ反映した。

## うまくいったこと

- 設計の重大な後退を2つ検出できた: (1) `-dirty` を一律 base 解決不可としたのは調査結果 Q3
  の縮退順序（-dirty を落として解決を試みる）からの逸脱で、`--allow-dirty` 配布の配布先で
  衝突判定が全滅する。`baseApproximate` という第3の状態を導入して解消。(2) `upstreamHasPath`
  だけでは「本家の削除漏れ」と「配布先の新規追加」を区別できない（Q8 の
  `git log --diff-filter=D` 材料を落としていた）。`upstreamDeleted` を追加し、deleted 側にも
  持たせて「本家でも削除済み」の別枠を新設。
- added の除外に「機構自身の生成物」（manifest 自身・*.bak）という盲点があることが判明。
  dist-layers にも gitignore にも載らないため、主経路で毎回必ず誤検出される構造だった。
- check-ignore 併用案は「正が2つ」になる（dist-layers の gitignorePattern と配布先の実
  .gitignore は参照データが違う）ため廃し、自前照合のみに一本化した。
- テスト表を T15 まで拡張（merge層指紋 T12/T13・merge3 終了コード T14・非git配布先 T15・
  T2a/T2b 分割・T8/T8b 分割・T6 のエラー隔離）。「読む側の初実装」なのにテストが1件も
  無かった merge 層指紋が最大の穴だった。

## ダメだったこと

- 計画初版は lines-marker の指紋を「全体 sha256」と書き、LF正規化を落としていた（記録側
  merge_fingerprint_json は tr -d '\r' 済み）。調査結果に書いた「json-keys だけ正規化なし」を
  計画へ写す際に対比を丸めた。要約時の情報落ちはフェーズ2と同じ失敗パターン。
- 終了コードの数値域の重なりを自分で指摘しながら、正規化後の「2」を base取得不可と
  3-way対象外で多重定義していた。4 を新設して分離。

## 次の一歩

- 13スレッドへの返信 → 未返信0 → 収穫スキルの実装（flow-id 3-6 相当）へ。

---
