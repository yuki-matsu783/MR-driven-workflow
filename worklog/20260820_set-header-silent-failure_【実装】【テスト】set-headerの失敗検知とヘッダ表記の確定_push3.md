---
title: worklog 【実装】【テスト】set-headerの失敗検知とヘッダ表記の確定 push3
type: log
description: issue #66の実装フェーズの試行錯誤ログ（push3）
tags: [worklog, update-handoff-progress, handoff]
keywords: [set-header, 一致件数, ヘッダブロック, 挿入位置, HANDOFF_TEMPLATE, 実装追認, 敵対的レビュー]
---

# worklog: 【実装】【テスト】set-headerの失敗検知とヘッダ表記の確定

対象: issue #66（`set-header` が対象行を書き換えられなくても無言で成功する）（2026-08-20）。
全体作業計画: `plans/set-header-silent-failure.md`
個別作業計画: `plans/【実装】【テスト】set-headerの失敗検知とヘッダ表記の確定.md`
push回数: 3

## 試したこと

- `cmd_set_header` へ項目ごとの一致件数（`n_issue` / `n_branch` / `n_pr` / `n_push_count`）を持たせ、
  1件でないものを列挙してエラー終了する形にした。
- ヘッダ行の探索範囲を求める `resolve_header_block_to_reply` を新設し、`cmd_set_header` と
  `set_loop_header_in_lines` の両方から使うようにした。
- `set_loop_header_in_lines` の挿入位置を「見出しの直前」から「ヘッダブロック内の最後のヘッダ項目の
  直後（無ければ見出しの直後）」へ変更した。
- `cleanup-task.sh` の `HANDOFF_TEMPLATE` へヘッダ行の雛形6行を追加した。
- 新規テストを追加したうえで、**修正前のスクリプトへ差し替えて流し直し**、落ちることを確かめた。

## うまくいったこと

- 修正前のスクリプトでは `test_update_handoff_progress.sh` が15件、`test_cleanup_task.sh` が8件
  失敗し、修正後はどちらも `failures=0` になった。**新しいテストが変更後の実装をなぞっただけに
  なっていない**ことを、この差で確認できた。
- `.claude/scripts/test/` の全14スクリプトが `failures=0`。
- テストを書く途中で、**自分のテストヘルパー `get_header` がファイル全体を `grep` していて
  本文中の引用行まで拾う**ことに気づいた。これは今回直している欠陥とまったく同じ形で、
  探索範囲を限定する必要性を裏づける事例になった（該当のアサーションは行位置での比較へ変更した）。

## ダメだったこと

- テストへ `status_of_contains` という補助関数を使うつもりで書き始めたが、
  `test_update_handoff_progress.sh` にはその関数が無かった。終了コードを文字列として受け渡す形は
  `.claude/rules/shell-script-style.md`「テスト」が避けるよう求めている書き方に近いため、
  `assert_contains` を新設する形へ変えた。
- `test_cleanup_task.sh` へ一時ファイルを作る際、後段の結合テストが `trap ... EXIT` を張り替えて
  いることに気づかず `TMP_DIR`（存在しない変数）を参照しかけた。`mktemp` で1ファイルだけ作り、
  使い終えたその場で消す形にした。

## 次の一歩

- `adversarial-review` スキルで敵対的レビューを受ける（人間のレビュー往復の代替）。
- flow-id 4-1: 反映対象（spec / rules / DDR）を洗い出す。
