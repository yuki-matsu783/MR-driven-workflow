---
title: 【設計反映】index.jsonl生成物化の設計反映
type: guide
description: issue #36の実装内容をDDR・specへ反映する個別反映計画（設計反映のみ）
tags: [frontmatter, index-jsonl, ddr, spec]
keywords: [extract-frontmatter, index.jsonl, DDR0024, spec, 却下案, 未決定事項]
---

# 【設計反映】index.jsonl生成物化の設計反映

対象: issue #36 frontmatter index.jsonlをGit管理から外し生成物として扱う（flow-id 4-1、設計反映のみ）。
全体作業計画: `plans/whimsical-launching-reef.md`
前段の個別作業計画: `plans/【設計】【実装】index.jsonl生成物化.md`（flow-id 3-6で実装済み）

## 背景

flow-id 3-6で以下を実装済み（レビュー済み、未解決コメント0件）。

- `.gitignore`に`**/index.jsonl`追加
- 既存15箇所の`index.jsonl`を`git rm --cached`でGit管理から除外
- `.claude/hooks/session-start.sh`に`regenerate_frontmatter_index`関数を追加（fail-open）
- `.claude/rules/markdown-frontmatter.md`の記述更新（実装済み・本計画の対象外）

当初、本計画は「設計反映」「AIアセット反映」を1ファイルに併記していたが、レビューで
「設計反映とAIアセット反映は基本的に別タイミングでやるようにしてほしい。タスクの種類や
人間の認知の種類が大きく異なる」との指摘を受け、`.claude/skills/issue-mr-flow/SKILL.md`
「種別を複数併記する場合／分ける場合」の判断基準（フェーズごとに個別の合意・レビューを
挟みたい場合は分ける）に従い、本ファイル（設計反映）と
`plans/【AIアセット反映】index.jsonl生成物化のAIアセット反映.md`（AIアセット反映）へ分割した。
**実施タイミングも分離し、まず本計画（設計反映）を完了・レビューしてから、
AIアセット反映の計画・実施に着手する。**

本計画では、flow-id 3-6の実装内容を「現在の正史」であるDDR・specへ記録する。

## 設計反映

### 1. 新規DDR `.claude/docs/ddr/0024-frontmatterのindex.jsonlをGit管理から外しSessionStart-hookで生成する.md`

次番号は0024（既存最終番号0023）。構成は既存DDR（0021, 0023）のフォーマットに倣う。

- **背景**: `index.jsonl`をGit管理下に置く運用が抱えていた2つの構造的問題（マージconflict、
  流し忘れによる追加コミット）。`extract-frontmatter.md`の未決定事項に既知の課題として記載済み
  だったことを含める。
- **決定**: `index.jsonl`を`.gitignore`対象化しGit管理から外す。自動再生成は
  `.claude/hooks/session-start.sh`（SessionStart hook）でセッション開始のたびに非侵襲的
  （fail-open）に実行する。トレードオフ（同一セッション内の複数回編集では次回セッション開始まで
  鮮度が古いままになりうる。必要なら手動実行で回避可能）を明記する。
- **却下した案**:
  - `create-commit.sh`（全commitが経由する中核スクリプト）への組み込み: 全commitの実行時間に
    影響を与える上、Git管理から外れた時点で本issueの核心問題（conflict・流し忘れ）は解消済みのため、
    commit経路での機構的強制までは不要と判断
  - 新規の独立pre-commit hookとしての実装: 既存の`session-start.sh`が既に「非侵襲的・fail-open」
    という設計方針を持っており、同じ方針をそのまま踏襲できる`session-start.sh`への追記のほうが
    実装・レビューコストが小さい
  - **DDR 0021却下案4（markdownが無くなったディレクトリの`index.jsonl`をスクリプトが自動削除する）
    の再評価**: 却下維持。理由を更新する。0021時点の却下理由は「Git管理下にあるため、誤って
    スコープ外まで削除するとGit履歴からの復旧に頼ることになり被害が大きい」という趣旨だったが、
    本issueでGit管理から外れたことで「誤削除してもGit履歴に戻れない」という前提も変わった。
    それでもなお却下を維持する理由: 自動削除はスクリプトの実行のたびに「意図しないディレクトリの
    `index.jsonl`を静かに消す」副作用を持ち込むことに変わりはなく、Git管理の有無に関わらず
    「スコープ外のファイルを触らない」という走査スクリプトの安全設計原則に反する。加えて、
    Git管理から外れたことで`flow-id 5-1`の特殊対応（`plans/index.jsonl`の個別削除）自体が
    不要になった（AIアセット反映側で対応）ため、却下案4が解決しようとしていた問題自体の実害が
    なくなっている。

### 2. `.claude/docs/spec/extract-frontmatter.md`の更新

- 「未決定事項・懸念点」の「生成物の自動再生成は未導入」項目を解消済みへ更新する
  （SessionStart hookによる自動再生成を実装し、DDR 0024を参照する形にする。それに伴い
  ネストされた「`index.jsonl`をGit管理下に置いている以上、これは日常的に踏む」という
  サブ項目も、Git管理下でなくなった事実とあわせて除去する）。
- 「影響範囲」に、issue #36のエントリを追記する（`.gitignore`への`**/index.jsonl`追加、
  既存15箇所の`git rm --cached`、`.claude/hooks/session-start.sh`への
  `regenerate_frontmatter_index`関数追加。過去のchangelogエントリ自体は書き換えない）。

### 3. `.claude/docs/README.md`のDDR一覧への追記

既存DDR一覧（0003〜0023）の末尾に0024のリンク行を追記する（新規DDR作成時の既存慣習）。

## 動作確認方法

- `.claude/docs/README.md`のDDR一覧に0024が追記されていることを確認
- DDR本文が既存フォーマット（背景・決定・却下した案）に沿っていることを確認
