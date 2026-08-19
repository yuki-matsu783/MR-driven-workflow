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
- **flow-id 2-6**: scratchpad配下に一時リポジトリを4本作り、計36ケースを実測した
  - probe1: 削除済みパス・`-A`・スコープ・サブディレクトリ・ディレクトリ指定・`.`/`:/`・存在しないパス・`git rm`の失敗モード
  - probe2: flow-id 5-1 の片付けを模した構成（`plans/`＋`worklog/`＋`reports/`＋日本語ファイル名＋
    `.gitignore`対象の`index.jsonl`）でのフルセット指定・ディレクトリ指定・未展開glob・未追跡削除
  - probe3: パス表記の揺れ（8進エスケープ・Windows形式区切り・`./`付き・絶対パス）と、
    **既に削除をステージ済みのパスを再度渡すケース**
  - probe4: 空pathspecの挙動と、分類ロジック（`git ls-files -z` / `git ls-tree -r -z --name-only HEAD`）の試作

## うまくいったこと

- 調査対象を「`-A` の巻き込み範囲」と「全体を指す pathspec の扱い」の2点に絞り込めた。
  この2点が、issueの受け入れ条件「無制限のステージングは引き続き構造的に不可能」を満たせるかどうかの
  分かれ目になる
- **真の失敗条件を特定できた**（probe3 の [M]）。`git rm` で削除を先にステージしたパスを再度
  `git add --` へ渡すと rc=128 になる。**issueが「回避策」と呼んでいる2段構えの手順そのものが、
  fatal を生む条件だった**。回避策を編み出すたびに同じ失敗を踏み直していたことになる
- 分類ロジックの試作が想定どおり動いた（ADD 2件 / SKIP 1件 / UNKNOWN 1件に正しく分類、
  pathspec 外の巻き込み無し、日本語パスも8進エスケープされずそのまま扱えた）
- 「計測は必ずベースラインを取る」と同じ発想で、**issueの前提そのものを最初に再現確認する項目を
  1番に置いた**のが効いた。ここを飛ばして `-A` へ書き換えていたら、症状が直らないまま
  「直った」と誤認する実装をマージしていた（5-1の片付けは必ず通る工程なので、次の片付けで再発した）

## ダメだったこと

- **issue本文の前提「削除済みパスを渡すと fatal」は、追跡済みファイルの削除では再現しなかった。**
  `git add -- <追跡済みの削除パス>` は rc=0 で正常に `D` をステージする（git 2.39.2.windows.1）。
  ディレクトリごと消えた `reports/` をディレクトリ指定で渡しても成功する
- **issueの実装案 `git add -A -- "${files[@]}"` は症状を直さない。** 失敗する3ケースは `-A` を
  付けても同じく rc=128 で失敗し、成功するケースは `-A` なしでも成功する。
  さらに引数が空のとき `git add -A --` は**リポジトリ全体をステージする**（`git add --` は
  "Nothing specified, nothing added." で何もしない）ため、安全側の性質を1つ失う。採用しない
- 代替案の `git rm` 併用は失敗モードが増える（`git rm -- <変更済みで存在する>` は rc=1、
  `git rm --cached -- <未追跡>` は rc=128）。分類してから `git add` に一本化する方が素直

## 次の一歩

- flow-id 2-7: 調査結果をcommitし、リモートへ反映してレビュー依頼を行う
- flow-id 2-8: **issueの実装案（`-A`）を採用しない**方針についてレビューで合意を取る
- flow-id 3-1以降: パス3分類（ADD / SKIP / UNKNOWN）の実装

---
