---
title: worklog 20260819 cheeky-baking-lantern 【調査】git-addの削除済みパス挙動 push1
type: log
description: issue #60でcreate-commit.shの修正方針を決めるための、git addの実機挙動調査ログ
tags: [issue-60, worklog, create-commit, git-add]
keywords: [git add, -A, pathspec, 削除済みファイル, create-commit, 調査, push1]
---

# worklog: 【調査】git-addの削除済みパス挙動

対象: `create-commit.sh` が削除済みファイルを引数に取れない問題（issue #60）の方針決めのための
git挙動調査（2026-08-19）。
全体作業計画: `plans/cheeky-baking-lantern.md`
個別調査計画: `plans/【調査】git-addの削除済みパス挙動.md`
push回数: 1

## 試したこと

- issue #60 を取得し、標準4見出しが揃っていることを確認した
- `main`（3e3ee03）から `feature-60-accept-deleted-file-paths` を作成、Draft PR #62 を作成した
  - 1回目のPR作成は「No commits between main and ...」で失敗 → 内部で空コミットを積んで自動リトライ
    （DDR 0005 / 0026 に記載された既知の制約どおりの挙動で、こちらでの追加操作は不要だった）
- 全体作業計画を作成し、着手前にフェーズ2の実施要否・テスト作成要否・記録先の広さをユーザーへ確認した
- 個別調査計画 `plans/【調査】git-addの削除済みパス挙動.md` に、実測すべき8項目を整理した

## うまくいったこと

- 調査対象を「`-A` の巻き込み範囲」と「全体を指す pathspec の扱い」の2点に絞り込めた。
  この2点が、issueの受け入れ条件「無制限のステージングは引き続き構造的に不可能」を満たせるかどうかの
  分かれ目になる

## ダメだったこと

- 特になし。

## 次の一歩

- flow-id 2-6: scratchpad配下の一時リポジトリで調査項目1〜8を実測し、本ファイルと個別調査計画の
  「調査結果」節、および `reports/` のHTMLへまとめる

---
