---
title: 'worklog: 【調査】収穫スキルの前提調査（push3）'
type: log
description: issue #27 敵対的レビュー2回目（対象=調査結果レポート）の反映ログ（push3）
tags: [worklog, harvest]
keywords: [敵対的レビュー, gitignorePattern, pathspec照合, merge層, del(.upstream), 終了コード, 255]
---

# worklog: 【調査】収穫スキルの前提調査（push3）

対象: issue #27 敵対的レビュー2回目（フェーズ2・対象=調査結果レポート）の反映（2026-08-23）。
全体作業計画: `plans/quiet-orchard-harvest.md`
個別作業計画: `plans/【調査】収穫スキルの前提調査.md`
push回数: 5

## 試したこと

- 敵対的レビュー2回目を実施。findings 14件（major/high 8・minor/high 4・minor/medium 2）。
  12件をインライン投稿、2件（実行検証4の転写・テスト置き場の文言食い違い）は報告のみに
  区分し、修正は14件すべて反映した。
- 追加の実行検証: `git merge-file` のエラー時終了コード（入力不在で255）と `-p` の非破壊性
  （実行前後で3入力の sha256 不変）を実測。`create-issue.sh` の引数不足時の終了コード=1 も
  記録した（hook はスクリプト名一致の過剰検知で、起票は行われていない）。
- `dist-layers.json` の全エントリを列挙し、「path 付きエントリはすべてディレクトリ名か
  ファイルパスそのもの（glob 無し）」「gitignorePattern のみの local エントリは9件」を確認
  （added 判定の照合規則2本立ての根拠）。

## うまくいったこと

- レビューが設計の重大な穴を4つ塞いだ: (1) gitignorePattern エントリは path の層解決に
  参加しないため added 判定に別途パターン照合が要る、(2) build_plan の層解決（本家の
  git ls-files 展開）は added 候補に適用できず自前の pathspec 照合が要る、(3) merge 層と
  dist-layers.json は `git show <記録SHA>:<path>` の base が成立しない（前者は3-way対象外、
  後者は del(.upstream) を base に）、(4) merge-file の終了コードは 0／1〜127／≧128 の
  3分岐が必須（255をそのまま衝突数と読むと誤分類）。
- フェーズ3計画の merge3 終了コード仕様も、衝突数の露出をやめ 0/1/2/3 の正規化した信号へ
  変更した（縮退=2 と衝突数=2 の数値域の重なりをレビュー反映中に自分で発見した）。

## ダメだったこと

- 調査結果の初版は Q8 の判定表を「sha256比較」と層をまたいで丸めており、Q1 の自分の記述
  （merge レコードに sha256 キーは無い）と矛盾していた。表へ要約する際に情報を落とす癖に注意。
- HTML の Q3 コードブロックを md の実測転写ではなく作文で書いていた（実測に見える例示は
  レビュー観点の evidence-mismatch に該当）。HTMLはmdの転写から作る。

## 次の一歩

- 12スレッドへの返信（対応内容）→ 未返信0 → フェーズ3計画の敵対的レビュー →
  収穫スキル実装へ。

---
