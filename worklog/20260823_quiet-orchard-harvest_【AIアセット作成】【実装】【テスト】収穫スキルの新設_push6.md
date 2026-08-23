---
title: 'worklog: 【AIアセット作成】【実装】【テスト】収穫スキルの新設（push6）'
type: log
description: issue #27 敵対的レビュー4回目（対象=実装一式）の指摘15件の反映ログ（push6）
tags: [worklog, harvest]
keywords: [core.quotepath, --no-renames, errexit, サブシェル, git archive, フェイルクローズ, T16〜T23, passed=89]
---

# worklog: 【AIアセット作成】【実装】【テスト】収穫スキルの新設（push6）

対象: issue #27 敵対的レビュー4回目の指摘反映（2026-08-23）。
全体作業計画: `plans/quiet-orchard-harvest.md`
個別作業計画: `plans/【AIアセット作成】【実装】【テスト】収穫スキルの新設.md`
push回数: 8

## 試したこと

- 敵対的レビュー4回目（フェーズ3・対象=実装一式。カウンタ 2/3）。findings 15件のうち
  13件をインライン投稿・2件（PR diff 外の index.md・rev-list の nit）をサマリで報告。
- 15件すべてを修正した（スクリプト・SKILL.md・テスト・index.md・レポート md/html）。

## うまくいったこと

- 指摘の要である「`( f ) || rc=$?` では errexit の一時停止がサブシェル内部へ伝播して
  内部失敗が素通りする」を、修正前に自分の環境（bash 5.2.21）で実測して確認した。
  `set +e; ( set -e; f ); rc=$?; set -e` の形なら内部失敗で即座に止まり rc に出ることも
  実測してから書き換えた。
- 非ASCIIパス（`core.quotepath`）・改名（`--no-renames`）・tar 失敗・manifest 空・
  フェイルクローズを、いずれも合成フィクスチャの拡張（日本語ファイル名・`git mv`・
  tar スタブ・`files: []` manifest・層情報なし配布先）で再現させ、テストへ固定した
  （T16〜T23。66→89アサーション、全緑）。

## ダメだったこと

- Edit ツールで `join("")` を含む長い塊を一度に置換しようとして2回失敗した。
  エスケープ表記を含む行はツール経由の一致が不安定なので、バックスラッシュを含む行に
  触れない小さな編集単位へ分けるのが確実（`shell-script-style.md` の「エスケープを含む
  修正はヒアドキュメント経由」と同根の教訓）。
- `.claude/rules/shell-script-style.md`「エラー方針」の「コマンド置換・明示サブシェルなら
  set -e が正しく機能する」という記述は、この環境の実測（`$(f)` を if で受けても素通り）と
  食い違う。規約自体の訂正が要る——フェーズ4の反映対象へ積む。

## 次の一歩

- commit・リモート反映 → 投稿済み13スレッドへ対応内容を返信 → unreplied 0 →
  フェーズ4（個別反映計画）へ。

---
