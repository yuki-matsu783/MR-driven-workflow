---
title: 全体作業計画 issue #46 defaultブランチとのコンフリクト検知・解消フロー整備
type: log
description: issue #46（マージ依頼前のdefaultブランチとのコンフリクト検知・解消フロー整備）の全体作業計画
tags: [plan, conflict, workflow]
keywords: [issue-46, コンフリクト, DDR番号, check-base-conflicts, resolve-conflict, flow-id-5-2]
---

# 全体作業計画: issue #46 マージ依頼前のコンフリクト検知・解消フロー整備

## 前提（この計画の作成条件）

**非対話的実行環境（Claude Code on the webのリモートセッション）で実施している。** 人間の
レビュー往復（flow-id 2-3/2-4, 3-3/3-4, 3-8/3-9, 4-3/4-4, 4-8/4-9）を待てないため、
planツールによる全体作業計画の提示・合意も取れない。`.claude/rules/docs-workflow.md` の
「非対話的実行環境で人間担当のレビュー待ちステップを省略する場合」の方針に従い、
該当するループ範囲の進捗記号は `[]` のまま残し、実施内容はHANDOFF.mdの「やったこと」で補う。

## issueの要求

- flow-id 5-2（またはその直前）にdefaultブランチとのコンフリクト有無を確認するステップを追加
- コンフリクトがあれば `AskUserQuestion` で確認したうえで、新設のコンフリクト解消スキルを実行
- 解消の標準手順（DDR番号衝突時の改番ルール／Git管理外化した生成物の扱い／複数ブランチで
  変更された同一ドキュメント行の統合方針）を `.claude/skills/` 配下の新規スキルとして文書化
- 過去の対応実績（PR #29, #37）を踏まえた内容にする

## 調査で分かったこと（フェーズ2相当。計画作成時に実測で完了）

1. **過去の発生は2件ではなく4件**（PR #29 / #37 / #49 / #52）。`git log --merges` と
   `chore: mainをマージし…` 形式のコミットメッセージから特定した。
2. **4件すべてでDDR番号が衝突していた**（0024 / 0026 / 0027 と、PR #29の1件）。
3. **DDR番号の衝突をgitは検知できない。** PR #52の両親コミット（20289b0 / 47b1d93）に対して
   `git merge-tree --write-tree` を実行したところ、`.claude/docs/README.md` と
   `tests/test_vcs_provider.sh` のコンフリクトは報告されたが、両側が別名で追加した
   `0027-*.md` については何も報告されなかった。ファイル名が異なるためgitは衝突と見なさない。
4. PR #37は `index.jsonl` の "deleted by us" が7件。再現確認済み。
5. 解消は過去4件ともすべて `git merge`（rebaseではない）で、説明的な日本語コミットメッセージ
   （`chore: mainをマージしDDR番号を0028へ繰り下げて…`）が付いている。

→ **「`git merge` を試してコンフリクトが出るか見る」という素朴な手順では、このリポジトリで
最も頻発する衝突を取りこぼす。検知は専用スクリプトで機構化する必要がある。**

## 方針

| # | やること | 成果物 |
|---|---|---|
| 1 | 検知の機構化（テキスト＋DDR番号重複） | `.claude/scripts/src/check-base-conflicts.sh` |
| 2 | 純粋関数の単体テスト | `tests/test_check_base_conflicts.sh` |
| 3 | 解消手順のスキル化（類型A〜E） | `.claude/skills/resolve-conflict/SKILL.md` |
| 4 | フローへの組み込み（flow-id 5-2新設・以降繰り下げ） | `.claude/skills/issue-mr-flow/SKILL.md` ほか |
| 5 | 設計反映 | `.claude/docs/spec/check-base-conflicts.md`, DDR 0029 |
| 6 | AIアセット反映 | `commit`スキル・`git-workflow.md`・`docs-workflow.md` のflow-id更新、`.gitignore`のDDR参照修正 |

## 判断のポイント

- **flow-idを新設するか、既存5-2に追記するか** → 新設する。「Draft解除の直前に必ず通る位置」を
  独立したステップとして表現したい。ステップ数は39→40。
- **rebase か merge か** → merge。レビューコメントがコミットSHAに紐づいており、履歴書き換えは
  レビュアーのチェックアウトとMR上の参照リンクを壊す。過去実績も全件merge。
- **検知を hook で自動化するか** → しない。push検知hookは部分一致で誤発火する既知の問題があり
  （`.claude/rules/git-workflow.md`）、その上に `git fetch` を伴う判定を積むのはコストに合わない。
