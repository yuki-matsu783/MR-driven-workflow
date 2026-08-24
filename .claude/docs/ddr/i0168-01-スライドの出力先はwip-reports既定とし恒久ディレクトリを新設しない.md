---
title: i0168-01. スライドの出力先はwip-reports既定とし恒久ディレクトリを新設しない
type: ddr
description: html-slidesスキルの成果物（.slides.html/.slides.json）の既定出力先をwip/reports/とし、恒久ディレクトリ新設・gitignore対象ローカルを却下した意思決定
tags: [ddr, slides, directory, lifecycle]
keywords: [html-slides, wip, reports, 出力先, 寿命, squash-merge, cleanup-task, 恒久保存, issue168]
---

# i0168-01. スライドの出力先はwip-reports既定とし恒久ディレクトリを新設しない

## 背景

html-slidesスキル（issue #168）の成果物は、スライドHTML（`.slides.html`）と構成案JSON
（`.slides.json`）の対である。このリポジトリは「squash merge後のmainはコード＋spec/ddrのみ」
という運用を持ち、`wip/` 配下の成果物は flow-id 5-5 でまとめて削除される。スライドを
どこへ出力するかは、この寿命の扱いをどうするかの決定である。

## 決定

**既定の出力先は `wip/reports/日付_<全体計画名>_<内容を簡潔に>.slides.html`（＋同ベース名の
`.slides.json`）とする。恒久ディレクトリは新設しない。**

- スライドはMRのレビュー・発表の期間中に使う成果物であり、レポートHTMLビューと同じ寿命
  （flow-id 5-5 で削除、ブランチ履歴にのみ残る）を受け入れる。
- 接尾辞 `.slides.html` により、レポートのHTMLビュー（mdと同名の `.html`）と衝突しない。
- 発表後も恒久的に残したい場合は、呼び出し時に依頼元が `wip/` の外の置き場所を明示指定する
  （SKILL.md に明記。その場合の追跡・配布の扱いは指定者の判断）。

## 理由

- 既定を `wip/reports/` にすると、`.gitignore`・`dist-layers.json`・`cleanup-task.sh`・
  `directory-structure.md` のいずれにも構造変更が要らない（issue #168 フェーズ2調査Q4で実測
  確認。根拠: `.gitignore` は `wip/` 配下を `/wip/state/` しか無視していないため追跡される・
  `dist-layers.json` は既存の `layer=local` エントリ `wip/reports` が配下を被覆済みで
  新たな層判断が不要・`cleanup-task.sh` は
  `wip/reports/` 配下を保持リスト（REVIEW-POINTS等）以外**拡張子を問わず**全削除するため
  新拡張子でも追加設定なしで寿命どおりに片付く）。リモートに乗るためレビュー・共有もできる。
- 必要なのはドキュメント側の追記（「mdとhtmlの2種類」と述べる既存記述への例外の明記、
  `wip/reports/REVIEW-POINTS.md` の適用範囲の線引き）だけで、これはフェーズ4で実施した。

## 却下案

| 案 | 却下理由 |
|---|---|
| 恒久ディレクトリ新設（例 `slides/`） | mainに残せるが、「squash merge後のmainはコード＋spec/ddrのみ」という運用と衝突する。`dist-layers.json` の層判断・`directory-structure.md` ツリー・`cleanup-task.sh` の除外追加も必要になる |
| `.gitignore` 対象のローカルディレクトリ | リモートに乗らずレビュー・共有ができない。`check-dist-coverage.sh` の検査2のため `dist-layers.json` へ `local` エントリも必要になる |
