---
title: HANDOFF
type: handoff
description: セッション間・作業者間の引継ぎメモ（現在地・次回やること等）
tags: [handoff, workflow]
keywords: [フロー進捗, worklog, 引き継ぎ, plan, レビュー]
---

# HANDOFF

<!--
AI⇔AI/AI⇔人間の状況引継ぎメモ。常に「このブランチの現状」を表現する
-->

## フロー進捗状況

- issue: #28（flow-id 5-1 後片付けタスク自動化スクリプト（cleanup-task.sh）の実装）
- ブランチ: `claude/cleanup-task-automation-9zk72n`（ハーネス指定。`feature-<issue番号>-<slug>`
  規則ではない）
- PR: 未作成（ハーネスが「ユーザーの明示依頼が無い限りPRを作成しない」と指示する環境のため。
  `.claude/rules/git-workflow.md`「ハーネスがPR作成を制限する環境での扱い」）
- 追従監視: なし（PRが無いため。PR作成後に `subscribe_pr_activity` で取り直す）
- push回数: 1
- 現在のループ: なし

**非対話的なリモート実行環境（Claude Code on the web）のため、人間のレビュー往復を待つ
ステップ（flow-id 2-3/2-4, 3-3/3-4, 3-8/3-9, 4-3/4-4, 4-8/4-9 等）を省略し、スクリプト1本＋
単体テスト＋spec/DDRへ圧縮して実施した。**そのため40ステップの進捗表は作成していない（実施内容は
下記「やったこと」を参照）。`plans/` `worklog/` `reports/` も作成していない。

## やったこと

- issue #28 の調査: flow-id 5-1 の4操作（`plans/` `reports/` の削除／`worklog/` のタスク固有
  ファイルの削除／`index.jsonl` の再生成／`HANDOFF.md` のリセット）と、過去に手作業で実施した
  flow-id 5-1（コミット `6dd6627`）の実結果を確認した。`main` 上で `plans/` `worklog/` `reports/`
  に存在する追跡対象ファイルは `worklog/TEMPLATE.md` だけであり、これは消してはいけない
  （worklogの雛形）ことを確認した。
- `.claude/scripts/src/cleanup-task.sh` を新規実装した（`--dry-run` / `--skip-index` / `--help`、
  実行内容のJSONをstdoutへ・進捗ログをstderrへ、冪等）。
- `.claude/scripts/test/test_cleanup_task.sh` を新規追加（純粋関数3つと埋め込みテンプレートの
  検証。32アサーション、`passed=32 failures=0`）。既存の単体テスト7本もすべて通ることを確認した。
- 一時ディレクトリのフィクスチャリポジトリで、dry-run／実行／2回目の冪等性／
  `extract-frontmatter.sh` 不在・異常終了／不正な引数／不正な設定（`plansDir: "../outside"`）の
  各経路を実機確認した。日本語ファイル名（`plans/【調査】〜.md`）も正しく削除されることを確認済み。
- リセット後の `HANDOFF.md` が、過去に手作業で実施した flow-id 5-1 の結果とバイト単位で一致する
  ことを `diff` で確認した（651バイト）。
- `.claude/docs/spec/cleanup-task.md` と
  `.claude/docs/ddr/0045-flow-id5-1の後片付けはスクリプト化しコミットは含めない.md` を新規作成し、
  `.claude/docs/README.md` の spec一覧・DDR一覧へ追記した。
- `.claude/skills/issue-mr-flow/SKILL.md` の flow-id 5-1 行を本スクリプトの実行へ差し替え、
  `.claude/rules/docs-workflow.md` の該当注記にもスクリプトへの参照を追加した。

## 次にやること

- （人間）PRを作成してよいか判断する。AIエージェントはこの環境ではPRを作成しない
  （`.claude/rules/git-workflow.md`「ハーネスがPR作成を制限する環境での扱い」）。
- （人間）レビュー。
- **マージ前に flow-id 5-1 を実施する**: `bash .claude/scripts/src/cleanup-task.sh`
  （このブランチでは `plans/` `worklog/` `reports/` のタスク固有ファイルは作っていないが、
  `HANDOFF.md` のリセットは必要）。結果は `commit` スキル経由でコミットする。
- （人間）マージ。AIエージェントは明示指示があるまでマージしない
  （`.claude/rules/git-workflow.md`「PR・マージ」）。

## 判断を迷った内容

- 削除対象を `Provider.sh` の `get_branch_work_files`（ブランチ差分）で決めるか、ディレクトリ配下
  の全ファイルから明示的な「残すパス」を除く形にするか。後者を採った（残す／消すの境界はブランチ
  差分ではなくファイルの役割で決まり、未追跡ファイルの取りこぼしも無いため）。却下案は DDR 0045。
- `HANDOFF.md` のテンプレートを別ファイルにするか、スクリプトへ埋め込むか。埋め込みを採った
  （人間が編集する雛形ではなくスクリプトの出力そのものであり、別ファイルにすると `index.jsonl`
  への混入・frontmatterの `type` 判断・相対パス解決が増えるため）。同じく DDR 0045。
- `extract-frontmatter.sh` の失敗でスクリプト全体を失敗させるか。警告に留めた（削除と
  `HANDOFF.md` のリセットは既に成功しており、`index.jsonl` はSessionStart hookが再生成する生成物
  のため）。同じく DDR 0045。

## 未解決の内容

- `cleanup-task.sh` の `main` に対する結合テストは常設していない（`.claude/scripts/test/` は実
  リポジトリを汚さない方針のため、フィクスチャでの手動確認で代えた）。常設するかは未決定
  （`.claude/docs/spec/cleanup-task.md`「未決定事項・懸念点」）。

## 守るべき条件・触ってはいけない範囲

- `worklog/TEMPLATE.md` は削除しない（`cleanup-task.sh` の `KEEP_PATHS` で保護している）。
