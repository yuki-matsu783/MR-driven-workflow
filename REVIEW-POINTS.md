---
title: レビュー観点（リポジトリ全体）
type: review-points
description: リポジトリ配下すべてのファイルに適用されるレビュー観点。
tags: [review, review-points]
keywords: [レビュー観点, 日本語, hook誤検知, 恒久参照, frontmatter, 二重管理, 見出し, point-in-time]
---

# レビュー観点（リポジトリ全体）

この観点表は**リポジトリ配下すべて**に適用される。より深いディレクトリに `REVIEW-POINTS.md` が
あれば、そちらの観点も併せて適用する（収集: `.claude/scripts/src/collect-review-points.sh`）。

## 言語・表記

- ユーザーへの応答・ドキュメント・コミットメッセージが日本語で書かれているか。
- 囲み文字に全角 `【】` を使っているか（ASCIIの `[]` はbashのglobで文字クラス扱いになる）。

## 恒久的な参照先

- コード・スクリプト内のコメントから `plans/` `worklog/` `reports/` のファイルを参照していないか。
  これらは寿命が短く、参照が切れる。**恒久的に参照してよいのはissue番号と
  `.claude/docs/spec/` `.claude/docs/ddr/` 配下のファイルだけ**。

## hookの誤検知を招く書き方

- コマンド文字列・コミットメッセージ・PR description・スクリプトのコメントで、
  `git` と `commit` / `push` を半角スペース区切りで**連続させていない**か。
  PreToolUse hookは部分文字列マッチのため、地の文でも誤って発火・ブロックされる。
- 長文をコマンド文字列へ直接埋め込まず、`--body-file` のようにファイル経由で渡しているか。

## ドキュメントの構造

- 新しい見出しの挿入位置が、**直前の節の「節全体にかかる地の文」の係り先を壊していない**か。
  挿入するなら節の末尾（次の見出しの直前）へ回す。
- 同じ内容が複数ファイルに重複して書かれていないか（参照で済ませられないか）。
- ファイル移動に伴うパスの一括置換が、**DDR本文**や**specの過去changelog**のような
  point-in-time記録まで書き換えていないか。

## frontmatter

- 新規markdownに `title` / `type` / `description` / `tags` / `keywords` があるか。
  `type` の値は `.claude/rules/markdown-frontmatter.md` の表にあるものか。
- DDRの本文を変更していないか（frontmatterの `status` / `superseded_by` のみ更新可）。
