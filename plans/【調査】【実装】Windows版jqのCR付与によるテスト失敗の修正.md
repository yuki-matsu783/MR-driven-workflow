---
title: 【調査】【実装】Windows版jqのCR付与によるテスト失敗の修正
type: plan
description: issue #94。native jqのCR付与で失敗する単体テストを直し、同種の取りこぼしを横断確認する
tags: [shell-script, test, windows, jq]
keywords: [jq, CR, 改行コード, コマンド置換, tr, Windows, git bash, 単体テスト, 横断確認, issue94]
---

# 【調査】【実装】Windows版jqのCR付与によるテスト失敗の修正

対象: issue #94

## 目的

`.claude/scripts/test/test_post_issue_create_notice.sh` がWindows（git bash）環境で常に
`passed=13 failures=1` になる状態を解消し、全テストが `failures=0` で終わるようにする。あわせて、
同じ罠を踏んでいる箇所が他に無いかを横断的に確認する。

## 調査でやること

1. 失敗の機構を、Linux上で**再現できる形**に落とす（Windows実機が無いため）。
   - Windowsネイティブjqの性質「stdoutをテキストモードで開き、各行末へCRを付与する」と、
     MSYS bashのコマンド置換の性質「末尾の `\r\n` はまとめて落ちる」の**合成**が、実際に
     観測される値である。この合成を再現するスタブjq（最終行以外の行末にCRを付ける）を作り、
     `PATH` の先頭へ置いてテストを流す。
   - issueが報告している `passed=13 failures=1` が再現できれば、機構の理解が正しいと確認できる。
2. `jq` の結果をコマンド置換で受けている箇所を洗い出し、**取り出す値が複数行になりうるか**で
   絞り込む（単一行の値は、末尾のCRがコマンド置換ごと落ちるため表面化しない。issue #94の
   コメントで実測済みの基準）。
3. 絞り込んだ結果のうち、`tr -d '\r'` が無い箇所を修正対象とする。

## 実装でやること

- 修正対象へ `| tr -d '\r'` を挟む（既存規約どおりの対処。新しい仕組みは導入しない）。
- ホットパス（毎ツール呼び出しで発火するhook）については、fork1回のコストと得られる効果を
  比較して判断する（`.claude/rules/shell-script-style.md`「外部プロセス起動のコスト」）。
- 判定基準（複数行かどうか）を `.claude/rules/shell-script-style.md` へ追記し、次に同じ調査を
  する人が95箇所を機械的に直さずに済むようにする。

## 検証

- 通常jq・スタブjqの両方で `.claude/scripts/test/test_*.sh` を全件流し、`failures=0` を確認する。
- CR混入の確認は `grep -c $'\r'` を使わず、`tr -d '\r'` 前後のバイト数比較で行う
  （`.claude/rules/shell-script-style.md`「テスト」）。
- `bash -n` で構文チェックする。

## 触らない範囲

- hook本体の出力仕様・判定ロジックは変更しない（挙動を変える修正ではない）。
- 単一行の値しか扱わない `jq -r` 箇所（大多数）は変更しない。
