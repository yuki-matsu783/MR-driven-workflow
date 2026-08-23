---
title: worklog 【実装】【テスト】push前チェックリスト機構の実装
type: log
description: issue #17 のpush前チェックリスト機構をフェーズ3で実装する間の試行錯誤ログ。
tags: [worklog, issue-mr-flow, hook, push]
keywords: [worklog, 実装, push前チェックリスト, PreToolUse, PostToolUse, 前置フィルタ, T11, TSV]
---

# worklog: 【実装】【テスト】push前チェックリスト機構の実装

対象: issue #17「hookを使って、push時にしてほしいことを実現する」フェーズ3（2026-08-23）。
全体作業計画: `wip/plans/steady-guarding-checkpoint.md`
個別作業計画: `wip/plans/【実装】【テスト】push前チェックリスト機構の実装.md`
push回数: 5

## 試したこと

- flow-id 2-10: MR descriptionを `describe` の型（`Closes` / `## Plan` / `## 実装状況`）で全文
  置換した。フェーズ2の8つの結論を表にし、設計を差し替えた3件を明記している。
- flow-id 3-1: 個別作業計画（md＋html）を作成した。実装単位・順序・検証コマンド・
  未確定事項を書いている。

## うまくいったこと

- **計画作成のために実装を読み直したところ、調査結果の誤りを1件見つけた。**
  Q1に「設定・キーが無い場合のフォールバックは `wip/worklogs`」と書いていたが、実際は
  `cleanup-task.sh:232` が `.worklogDir // "worklog"`、`Provider.sh:66` の
  `get_workflow_config` も `"worklogDir": "worklog"` で、**どちらも issue #165 より前の値**
  だった。`wip/worklogs` を採ると、`.mrworkflow.json` が無い配布先で生成側が `wip/worklogs/`、
  削除側が `worklog/` を見ることになり、**まさにQ1が避けようとした食い違いを自分で作る**。
  調査結果のmd・htmlを訂正し、計画には「自前で `// "..."` を書かず `get_workflow_config` を
  呼んで既定値を共有する」と書いた。
  - 教訓: **「〜に合わせる」と書いた相手の実装値を、実際に読んで確かめる。**
    合わせる意図を書いただけでは合っていない。

- **計画を書く過程で、調査結果の「3本」という数え方の食い違いにも気づいた。**
  T11の対象は `raw_hints_at_git_push` を持つhookの本数だが、新規hookは PreToolUse・PostToolUse の
  **2本ともこれを持つ**ため、実際は4本になる可能性が高い。計画の「未確定事項」へ入れ、
  実装時に確定させることにした。

## ダメだったこと

- **push回数の更新をpushの後に行い、その1行だけが未コミットで残った。**
  `.claude/rules/docs-workflow.md` は「更新はcommitより前に行い、同じcommitに含める」と
  定めており、手順を守れていなかった。`HANDOFF.md` の「次にやること」へ注意書きを残した。
  - **これはまさに本issueが機構化しようとしている失敗そのもの**である
    （push前にやるべきことを、pushの後に思い出す）。チェックリストの項目に
    「`HANDOFF.md` の進捗表・ヘッダを更新した（commitより前・同じcommitに含めた）」という
    括弧書きが入っているのは、この失敗を名指しするためだと実感した。

## 次の一歩

- flow-id 3-2: commit・pushし、敵対的レビュー（フェーズ3・1回目）を実施する。
- flow-id 3-6: 計画に沿って実装する（`push-checklist.sh` → hook2本 → T11改修 → `settings.json`）。

---
