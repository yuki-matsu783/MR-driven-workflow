---
title: worklog 20260819 index.jsonl生成物化のドキュメント反映 push1
type: log
description: issue #36対応（フェーズ4反映）の作業ログ
tags: [worklog, frontmatter, index-jsonl, ddr]
keywords: [DDR0024, extract-frontmatter, docs-workflow, SKILL.md, flow-id5-1]
---

# worklog: 【設計反映】【AIアセット反映】index.jsonl生成物化のドキュメント反映

対象: issue #36 frontmatter index.jsonlをGit管理から外し生成物として扱う（2026-08-19）。
全体作業計画: `plans/whimsical-launching-reef.md`
個別反映計画: `plans/【設計反映】【AIアセット反映】index.jsonl生成物化のドキュメント反映.md`
push回数: 1

## 試したこと

- flow-id 3-8〜3-9: 人間から「レビューOK」の合図を受け、ルールどおり`comments all`
  （`get_mr_unresolved_comments 37 true`）で未解決コメントを確認。対応工数レポート自動投稿
  2件のみで、レビュー指摘は0件だったため修正不要と判断
- `.claude/rules/directory-structure.md`・`.claude/rules/docs-workflow.md`・
  `.claude/skills/issue-mr-flow/SKILL.md`をgrepし、`index.jsonl`への言及箇所をすべて洗い出した

## うまくいったこと

- `directory-structure.md`には`index.jsonl`への直接言及が無い（ヒットしたのは無関係の
  `usage/state/push-index.jsonl`のみ）ことを確認し、矛盾なし・変更不要と結論できた
- DDR 0021・0023の既存フォーマットを読み、新規DDR 0024の構成（背景・決定・却下した案）を
  同じスタイルで設計できた。特にDDR 0021却下案4（自動削除）の再評価は、「Git管理下から外れた
  ことで却下理由の前提は変わったが、スクリプトの安全設計原則という別の理由で却下維持」という
  形で整理できた
- 個別反映計画`plans/【設計反映】【AIアセット反映】index.jsonl生成物化のドキュメント反映.md`を
  作成（flow-id 4-1）。設計反映（DDR新規作成・spec更新）とAIアセット反映（SKILL.md・
  docs-workflow.md・README.mdの更新）の対象箇所・変更内容を具体的な差分レベルで確定した

## ダメだったこと

- 特になし。

## 次の一歩

- commit・push・レビュー依頼（flow-id 4-2）
- レビュー後、計画に従いDDR 0024の新規作成・spec更新・SKILL.md/docs-workflow.md/README.mdの
  更新を実施（flow-id 4-6）

## 追記（flow-id 4-3〜4-4: レビュー対応）

- レビューで「設計反映とAIアセット反映は基本的に別タイミングでやるようにしてほしい。タスクの
  種類や人間の認知の種類が大きく異なる」との指摘を受けた
  （threadId=PRRT_kwDOT7UgWc6aS9t8）
- `.claude/skills/issue-mr-flow/SKILL.md`「種別を複数併記する場合／分ける場合」の判断基準
  （フェーズごとに個別の合意・レビューを挟みたい場合は分ける）に従い、併記していた
  `plans/【設計反映】【AIアセット反映】index.jsonl生成物化のドキュメント反映.md`を削除し、
  以下の2ファイルへ分割した
  - `plans/【設計反映】index.jsonl生成物化の設計反映.md`（DDR 0024新規作成・spec更新・
    README.md DDR一覧追記）
  - `plans/【AIアセット反映】index.jsonl生成物化のAIアセット反映.md`（SKILL.md・
    docs-workflow.md更新。directory-structure.mdは変更不要と結論）
- **実施タイミングも分離**: まず設計反映のみを完了・レビューしてから、AIアセット反映の実施へ
  着手する方針とした（AIアセット反映側の計画ファイルに「着手タイミング」として明記）

---
