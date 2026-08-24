---
title: i0169-01. pptx書き出しは雛形展開ディレクトリとzip再梱包で実装し外部依存を持たない
type: ddr
description: 構成案JSONから編集可能な.pptxを生成する手段として「展開ディレクトリ形式のOOXML雛形＋slideN.xml生成＋zip再梱包」を採用し、クリップボード経由・python-pptx・XMLゼロから生成・バイナリ.pptx雛形・PowerShell Compress-Archiveの5案を却下した理由を記録する
tags: [ddr, pptx, ooxml, 外部依存]
keywords: [pptx-slides, json-to-pptx, 雛形, 展開ディレクトリ, zip, python-pptx, クリップボード, Compress-Archive, バイナリ雛形, OOXML]
---

# i0169-01. pptx書き出しは雛形展開ディレクトリとzip再梱包で実装し外部依存を持たない

## 背景

issue #169 は、スライド構成案JSON（issue #168 のスキーマ）から**テキスト・表がPowerPointで
編集可能な** `.pptx` を書き出す機能を求めた（受け入れ条件8が「採用・却下案をDDRへ記録する」）。
実装手段には複数の候補があり、前提調査（フェーズ2）でこの環境（Claude Code on the web の
リモート実行環境・Linux）の実測に基づいて比較した。仕様の正史は
`.claude/docs/spec/pptx-slides.md`。

## 決定

**「展開ディレクトリ形式のOOXML雛形（静的パーツをテキストのままGit管理）＋
`ppt/slides/slideN.xml` と連動5箇所の生成＋zip再梱包（`zip` → python zipfile の経路試行）」で
実装する。** 新規の外部依存（pipパッケージ等）を持たず、リポジトリの既存前提（bash＋jq）の
範囲で完結させる。

## 理由

- 雛形のXMLがテキストとしてGit管理され、**差分レビューが可能**（バイナリを持たないため
  `.gitattributes` の追記も不要）。
- 生成スクリプトの仕事が「雛形コピー＋生成したXMLを足してzip」に収まり、見た目の調整は
  雛形側のXML差し替えで済む。将来のPowerPoint製雛形への差し替え余地も残る
  （前処理条件は spec の「PowerPoint製雛形への差し替え」節）。
- zipの可用性は経路試行（`zip` → `python3`/`python`/`py -3` の zipfile を能力ベース検出 →
  明示エラー）で吸収でき、Windows git bash（`zip` 非同梱の構成がある）でも動く。

## 却下案（5件。却下理由は前提調査レポート「設計への反映」の原文を引き継ぐ）

1. **クリップボード経由の貼り付け**: ブラウザがクリップボードへ書ける形式は
   `text/plain`/`text/html`/`image/png` に限られ、PowerPointが図形として読むネイティブ形式
   （`Art::GVML ClipFormat`）を書き込めないため、貼り付けが1つのテキストボックスへの
   流し込みになりレイアウトが失われる（issue #169 本文の記載を却下根拠として採用）。
2. **python-pptx（生成手段として）**: 新規の外部依存（pipインストール）が要り、git bash実機に
   存在する保証が無い。このリポジトリのスクリプト規約（bash＋jq前提。
   `.claude/docs/spec/shell-scripts.md`）とも不揃い。実測でもこの環境に不在だった。
3. **XMLをゼロから組む（雛形なしで毎回全パーツを生成）**: マスター・レイアウト・テーマまで
   生成コードに埋まり、見た目の調整のたびにスクリプト修正が要る。雛形方式ならXML差し替えだけで
   済む。
4. **バイナリ .pptx 雛形（リポジトリへ同梱し生成時に差し替え）**: 差分レビュー不能。バイナリの
   Git管理（`.gitattributes`・配布）に追加の配慮が要る。更新にはPowerPointか展開・再圧縮の
   往復が要り、展開ディレクトリ方式に対する利点が「PowerPoint製の保証」しか無い。
   その保証も、この環境にPowerPointが無い以上「機械検証＋人間の実機確認」で代替するしかなく、
   展開ディレクトリ方式と変わらない。
5. **PowerShell `Compress-Archive`（zip経路のフォールバックとして）**: この環境（Linux）では
   実挙動を検証できない。**検証できない手段を自動フォールバックへ入れない**という方針により
   却下（Compress-Archive はOOXMLが要求する格納順・無圧縮先頭エントリ等の制御にも難がある）。

## 補足（この決定に付随して固定した設計）

- 入力検証はjqの必須キー・要素型検査で行い、スキーマファイル本体へ実行時依存しない
  （スキーマとの同期は単体テストのjq適合チェックが固定する）。
- 失敗時は明示エラー・非0終了で壊れた `.pptx` を残さない（jqの途中失敗も一時ファイル経由で
  検知。自己検証はzip整合性＋必須パーツ＋python検出時のXML well-formed）。
- 実装中に検出した bash 5.2 `patsub_replacement` の罠（パラメータ展開の置換文字列中の `&` が
  マッチ全体へ展開される）は `.claude/rules/shell-script-style.md` へ規約として記録した。
