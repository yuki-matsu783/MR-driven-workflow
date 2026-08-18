---
title: worklog 20260818 【実装】.mrworkflow.jsonキー説明をREADMEに追記 push1
type: log
description: issue #21対応。.mrworkflow.jsonの各キー説明をREADME.mdに追記する作業のworklog
tags: [worklog, mrworkflow-json, readme]
keywords: [mrworkflow, README, branchPrefixTemplate, defaultBaseBranch, plansDir, worklogDir, reportsDir, specDirs, ddrDirs]
---

# worklog: 【実装】.mrworkflow.jsonキー説明をREADMEに追記

対象: issue #21「.mrworkflow.jsonの各キーの説明をREADME等に追記する」（2026-08-18）。
全体作業計画: `plans/playful-napping-finch.md`
個別作業計画: `plans/【実装】.mrworkflow.jsonキー説明をREADMEに追記.md`
push回数: 1

## 試したこと

- Planモード内で`README.md`・`index.md`・`.mrworkflow.json`・`Provider.sh`・
  `.claude/rules/directory-structure.md`・`.claude/rules/docs-workflow.md`・
  `.claude/docs/spec/issue-mr-workflow.md`を調査し、各キーの現状の言及有無・実際の消費状況を洗い出した。
- この環境（Claude Code on the webのリモート実行環境）には`gh`/`glab` CLIが存在しないことを確認。
  `Provider.sh`前提の`start`/`comments`/`reply`/`describe`サブコマンドは動作しないため、
  GitHub MCPサーバーツール（`mcp__github__issue_read`・`mcp__github__create_pull_request`等）で代替した。

## うまくいったこと

- 各キーの「デフォルト値」「用途」「関連関数」の一覧化ができた（詳細は個別作業計画ファイル参照）。
- `specDirs`/`ddrDirs`が現状`Provider.sh`のどの関数からも参照されていないことをコード上確認できた
  （`grep -rn "\.specDirs\|\.ddrDirs" --include="*.sh"`でヒット0件）。実態と齟齬のない説明文にできる。
- `.claude/docs/spec/issue-mr-workflow.md`の「設定項目」節にある`specDirs`/`ddrDirs`のサンプル値が
  移植元プロジェクト当時のもの（`dev-tools/docs/spec`等）のまま未更新で、現行`.mrworkflow.json`の
  実値と食い違っていることを発見。フェーズ4（設計反映）でこの食い違いを解消するかを検討する。

## ダメだったこと

- 特になし。

## 次の一歩

- README.mdのセットアップ節へ、個別作業計画にまとめたテーブルを実際に追記する（flow-id 3-6）。
- 追記後、`.mrworkflow.json`の実値・`Provider.sh`実装との整合を再確認する。

---
