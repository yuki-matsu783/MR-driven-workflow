---
title: 【調査】DDR参照切れの網羅調査と検出方式の検討
type: plan
description: リポジトリ全体でDDRファイルパス形式の参照が実在するファイルを指しているかを網羅的に調査し、同種の参照切れを機械的に検出する方式を検討する個別調査計画
tags: [gitignore, ddr, doc-references, issue-171]
keywords: [DDR識別子, ゼロ埋め, 参照切れ, 検出スクリプト, check-base-conflicts, generate-ddr-list]
---

# 【調査】DDR参照切れの網羅調査と検出方式の検討（issue #171）

## 前提（合意状況）

- 上位の計画: `plans/sequential-purring-tulip.md`（全体作業計画、flow-id 1-5で合意）

## 目的

1. `.gitignore`の2箇所（28行目・40行目）以外に、DDRファイルパス形式の参照切れが無いことを
   件数付きの検索結果で確認する。
2. 同種の参照切れを検出する仕組みの実装方式（置き場所・判定ロジック・実行タイミング）を決める。

## 調査すること

- リポジトリ全体（`git ls-files`、バイナリ除く）を対象に、`.claude/docs/ddr/i<番号>-<枝番>-`
  という**パス形式**の文字列を正規表現で抽出し、各候補について対応する実ファイルが
  `.claude/docs/ddr/`配下に存在するかを1件ずつ確認する。
  - パス形式に限定する理由: `i133-01`のような裸の識別子はゼロ埋め規約の説明文中の例示に
    多用されており、単純な`i[0-9]+-[0-9]{2}`検索では大量の誤検知を生む（事前調査で
    `i0133-01-...md`本文・`.claude/docs/README.md`・`.claude/rules/markdown-frontmatter.md`・
    `test_check_base_conflicts.sh`などで例示的ヒットを確認済み）。`.claude/docs/ddr/`という
    ディレクトリプレフィックスを伴う文字列に絞ることで、「実ファイルを指す意図の参照」だけを
    拾える。
- 既存スクリプト（`check-base-conflicts.sh`の`ddr_identifier_to_reply`、`generate-ddr-list.sh`）の
  実装を読み、識別子の正規表現・ファイル一覧の取得方法を確認し、新規スクリプトでも同じ表現を
  再利用できるか確認する。
- 検出方式の選択肢を比較する。
  - (a) 新規スクリプト `.claude/scripts/src/check-doc-references.sh` として独立させ、
    `.claude/scripts/test/test_check_doc_references.sh` で単体テストする
  - (b) `check-base-conflicts.sh`（コンフリクト検知の一部）へ検証ステップとして追記する
  - (c) `generate-ddr-list.sh`（DDR一覧生成）へ検証ステップとして追記する
- 実行タイミングを検討する。候補: 手動実行のみ／flow-id 5-1（コンフリクト解消。既に
  `resolve-conflict`スキルからの実行動線がある）に合流／`generate-ddr-list.sh`実行時に自動で
  合わせて実行。
- `.claude/rules/shell-script-style.md`の規約（外部プロセス起動コスト・NULバイト・jq引数長上限等）
  に照らして、実装方針（`git ls-files`の使い方、ループ内で外部コマンドを呼ばない設計）を
  確認する。

## 現時点で分かっていること（事前調査からの引き継ぎ）

- `.gitignore`の28行目は`i00-13`、40行目は`i36-01`を参照しており、実ファイルはそれぞれ
  `i0000-13-gemini配下は…md`、`i0036-01-frontmatterのindex.jsonlを…md`。
- issue本文は「`i00-13`参照はissue #70で既に消えた」としているが、これは誤り（現に残っている）。

## 検証（この調査が完了したと言える条件）

- リポジトリ全体のDDRパス形式参照の総数と、そのうち実ファイルが存在しない件数を、
  `reports/`へ件数付きで記録できている。
- 検出方式・置き場所・実行タイミングについて、採用案とその理由を`reports/`へ記録できている。
