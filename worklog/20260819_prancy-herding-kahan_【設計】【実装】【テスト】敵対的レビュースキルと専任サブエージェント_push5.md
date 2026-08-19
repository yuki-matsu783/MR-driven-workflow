---
title: worklog 20260819 【設計】【実装】【テスト】敵対的レビュースキルと専任サブエージェント push5
type: log
description: issue #77 フェーズ3の作業ログ（push5）。フェーズ2の完了と個別作業計画の作成までを記録する。
tags: [worklog, issue-mr-flow, design]
keywords: [worklog, issue77, 作業計画, add_mr_inline_comments, 有効行, カウンタ, サブエージェント, position]
---

# worklog: 【設計】【実装】【テスト】敵対的レビュースキルと専任サブエージェント

対象: issue #77 MRへの敵対的レビューを行うスキル・専任サブエージェントを追加する（2026-08-19）。
全体作業計画: `plans/prancy-herding-kahan.md`
個別作業計画: `plans/【設計】【実装】【テスト】敵対的レビュースキルと専任サブエージェント.md`
push回数: 5

## 試したこと

- flow-id 2-8〜2-9（2周目の締め）: 未解決スレッド2件は人間がresolve済みであることを
  `get_mr_unresolved_comments 80 true` で確認した。resolve時に追加された
  「このリポジトリ実装の欠陥であれば修正すること」という指示を拾い、修正時期を
  `AskUserQuestion` で確認した（回答: **フェーズ3で実施する**）。
- flow-id 2-10: 調査結果をもとにMR descriptionを更新した（経路ごとの比較表・確定した事実・
  フェーズ3以降の成果物一覧）。
- flow-id 3-1: 個別作業計画を作成するにあたり、実装先の既存形式を読み直した。
  - `Provider.sh` のディスパッチ形式（先頭で `require_vcs_cli <自関数名> || return 1` →
    `case "$(get_provider)"`）と `mcp_tool_hint` の関数名→ツール名テーブル。
  - `.claude/agents/issue-mr-resume.md` のfrontmatter（`name`/`description`/`tools`/`model` ＋
    OKFキー）と読み取り専用の書きぶり。
  - `.claude/scripts/test/test_vcs_provider.sh` の冒頭コメント（どの関数がなぜ対象／対象外か）と
    `passed=N failures=N` 規約。

## うまくいったこと

- 個別作業計画の種別を `【設計】【実装】【テスト】` の**併記**とした。調査で外部APIの制約
  （投稿単位・失敗の粒度・判定材料）が確定しており、設計方針と実装方式を分けて合意する必要が
  無いため。テストも純粋関数の切り出し方と表裏一体で、実装と同時に書く。
- 全体作業計画のfindings JSONスキーマ案から、**`line`・`side`を任意へ変更**した。flow-id 2-9で
  決めた「ファイル全体にかかる指摘は有効行の最小値へ寄せる」を表現するには、`line`未指定の
  findingを受け付ける必要があるため。
- 「`patch`が省略されたファイル」「diffに現れないファイル」は、有効行集合が空になることで
  **自動的にサマリへ回る**設計にできた（特別扱いの分岐を書かずに済む）。
- 実装順序を「純粋関数・スクリプト（1〜3）→ AIアセット（4〜6）」に固定した。逆順だと、
  スキル本文が未実装の関数を参照する時間が生じるため。

## ダメだったこと

- 特になし。

## 次の一歩

- flow-id 3-2: 個別作業計画・worklog・HANDOFF.md をcommitし、リモートへ反映してレビュー依頼を行う。
- レビュー合意後、flow-id 3-6 で成果物1〜6を順に実装する。
