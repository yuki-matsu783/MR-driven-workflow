---
title: worklog: 【調査】hook検知の誤検知類型と判定方式
type: log
description: issue #53のフェーズ2〈調査〉の試行錯誤ログ
tags: [worklog, 調査, hooks, issue-53]
keywords: [誤検知, コマンド位置, ヒアドキュメント, クォート, CR, fork, 判定方式]
---

# worklog: 【調査】hook検知の誤検知類型と判定方式

対象: hookのコマンド文字列検知をコマンド位置ベースへ置き換えるための調査（2026-08-20）。
全体作業計画: `plans/hook-command-position-detection.md`
個別作業計画: `plans/【調査】hook検知の誤検知類型と判定方式.md`
push回数: 1

## 試したこと

- issue #53 の本文と3件のコメントをMCP経路で取得した（`gh` CLIがこの実行環境に無いため）。
  - issue #94 からの申し送り: 位置ベースにするならCRの扱いを再判定すること。
  - issue #47 の実測: この環境（Claude Code on the web / Linux）では push検知hookは
    「地の文だけ」では発火しなかった。コミット側は `if` を経由しないため必ず発火する。
  - issue #133: 本文が参照する DDR 0012 は `i0000-09` へ改番済み。
- 4hookの検知箇所を `grep -n 'tool_input.command'` で洗い出した。

## うまくいったこと

- （調査の実施で追記する）

## ダメだったこと

- （調査の実施で追記する）

## 次の一歩

- flow-id 2-6: 調査を実施して `reports/` へ記録する。
