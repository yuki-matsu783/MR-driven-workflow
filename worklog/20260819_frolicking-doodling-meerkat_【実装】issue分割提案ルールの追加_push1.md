---
title: worklog 【実装】issue分割提案ルールの追加 push1
type: log
description: issue #64（issue分割提案ルールの追加）の作業ログ。push1は計画作成まで
tags: [worklog, issue-mr-flow, issue-create]
keywords: [issue分割, 並列列挙, flow-id 1-4, 個別作業計画, 挿入位置, 見出しの係り先, HANDOFF]
---

# worklog: 【実装】issue分割提案ルールの追加

対象: issueが大きすぎる場合に分割を提案するルールの追加（2026-08-19）。
全体作業計画: `plans/frolicking-doodling-meerkat.md`
個別作業計画: `plans/【実装】issue分割提案ルールの追加.md`
push回数: 1

## 試したこと

- issue #64 を `get_issue` で取得し、`test_issue_sections` で標準4見出しの過不足を確認した
  （欠落なし）。
- 既存ブランチの有無を `git branch --list "feature-64-*"` / `git ls-remote --heads origin
  "feature-64-*"` で確認（いずれも無し）。ベースを `main` として新規に作成した。
- `.claude/skills/issue-mr-flow/SKILL.md` の見出し構造を `grep -n '^### \|^## '` で洗い出し、
  新節の挿入位置を検討した。
- 現行のDDR最大番号を `ls .claude/docs/ddr/` で確認した（`0031`。次番は `0032`）。

## うまくいったこと

- **新節の挿入位置を「`## サブコマンド` の直前（＝`## 全体フロー` 節の末尾）」に決めた。**
  当初は内容の近さから `### 計画の2階層構造（issue #9）` の直後に置く想定だったが、実ファイルを
  読むと、その直後の L147〜163 は「compactの扱い」「`resume` から入る原則」「HANDOFFの更新」
  という**全体フロー節全体にかかる地の文**だった。ここへ新しい `###` を差し込むと、これらの
  地の文が新節の配下に入り、見出しの係り先が変わってしまう。末尾に置けば既存の構造を一切
  動かさずに済む。
- HANDOFF.md の進捗表を、`update-handoff-progress.sh` の `mark-done` / `mark-skip` で機械的に
  更新できた（1-1〜1-6 を `[x]`、2-1〜2-10 を `[-]`）。

## ダメだったこと

- 特になし。

## 気づき（フェーズ4で扱うか判断する）

- **main に issue #63（PR #71）の後片付け漏れがあった**。`plans/` 3ファイル・`worklog/` 1ファイルと、
  作業途中の `HANDOFF.md` が main へ入っていた。SKILL.md「PRがflow-id 5-1実施前にマージされて
  しまった場合の対処」に該当する。ユーザー合意のうえ、本ブランチの flow-id 5-1 でまとめて削除する。
- **issue本文の「5フェーズ39ステップ」は現行と食い違う。** SKILL.md の現行定義は 1-1〜5-4 の
  40ステップ（issue #46 で 5-2 が追加された）。新設する節では 40 と書く。
- **`.claude/docs/spec/update-handoff-progress.md` も「進捗表は39行」のまま**で、同じ追随漏れが
  ある。本issueのスコープ外だが、フェーズ4で触れるか判断する。
- **issue #63 のHANDOFF進捗表は 5-1/5-2/5-3 の3行しか持っていなかった**（5-2 追加前の旧構成）。
  本ブランチでは 5-1〜5-4 の40行で作り直した。

## 次の一歩

- flow-id 3-2: 計画をcommit・リモートへ反映し、レビュー依頼を行う。
- レビュー合意後、flow-id 3-6 で作業1〜3（SKILL.md 2ファイルの改訂）を実施する。

---
