---
title: worklog 【調査】push前チェックリスト機構の設計調査
type: log
description: issue #17 の設計調査（8つの問い）を進める間の試行錯誤ログ。
tags: [worklog, issue-mr-flow, hook, push]
keywords: [worklog, 調査, push前チェックリスト, PreToolUse, PostToolUse, CommandPosition, cleanup-task, TSV]
---

# worklog: 【調査】push前チェックリスト機構の設計調査

対象: issue #17「hookを使って、push時にしてほしいことを実現する」の設計調査（2026-08-23）。
全体作業計画: `wip/plans/steady-guarding-checkpoint.md`
個別作業計画: `wip/plans/【調査】push前チェックリスト機構の設計調査.md`
push回数: 2

## 試したこと

- flow-id 1-2: issue #17 の本文とコメントをMCP経路（`mcp__github__issue_read`）で取得した。
  `gh` CLIがこの実行環境に無いため、`Provider.sh` のCLI経路は使えない。
- flow-id 1-3: `check-base-sync.sh` で `main` が1コミット先行していることを検知し、
  `AskUserQuestion` の承認を得て `git merge origin/main` で取り込んだ（PR #174）。
  マージはコンフリクト無しで完了。

- flow-id 2-3（敵対的レビュー1回目）: `adversarial-reviewer` サブエージェントへ4ファイル（計画md/html
  各2本）を渡し、14件のfindingsを得た。確度・重大度の1次振り分けで10件を投稿候補とし、
  `select-adversarial-findings.sh` が10件すべてを投稿対象に選別。MCP経路
  （`pull_request_review_write` → `add_comment_to_pending_review` ×10 → `submit_pending`）で投稿した。
- flow-id 2-4: 10件すべてへ修正のうえ返信した。報告のみに留めた4件のうち3件も、ついでに直している
  （検証コマンドの実効性・`<新規>` プレースホルダ・issue分割の判断の記録）。
- flow-id 2-6（調査実施）: 8つの問いへ答えを出し、`wip/reports/` へmd・htmlで記録した。
- flow-id 2-8（敵対的レビュー2回目）: 調査結果（md/html）を渡して14件のfindingsを得た。
  そのうち12件を投稿し、flow-id 2-9 ですべて修正のうえ返信した。
- flow-id 2-9: `@{upstream}` の意味論を確かめるため、**一時リポジトリ**を作って
  `upstream-probe.sh` / `upstream-probe2.sh` / `contains-probe.sh` の3本を走らせた。
  実際に `git push` を実行する検証なので、コマンド位置に該当語が立つ。
  scratchpadへ `.sh` として書き出し `bash <path>` で実行した（`.claude/rules/ai-command-style.md`
  「切り出し先の選び方」に従い、使い捨てなのでscratchpadを選んだ）。

## うまくいったこと

- 全体作業計画・個別調査計画のHTMLビューを、テンプレートの `<!DOCTYPE html>`〜`</style>`（52〜152行）
  だけを `sed` で引き継ぎ、body以降を自前で書く方法で生成できた。プレースホルダの残留
  （`grep -c '<!-- ここに書く'`）・重複ID・アンカー破断の3点を機械的に検査している。

- 敵対的レビューが**自分では気づけない誤り**を実際に拾った。特に効いたのは次の3件。
  - `git log --oneline` の `(#178)` を**issue番号として引き写していた**（実際はsquash mergeのPR番号で、
    issueは #165）。同じ誤りが4ファイルへ伝播しており、放置すればspec・DDRまで届いていた。
  - 検証コマンド `for t in …; do bash "$t"; done` が**原理的に失敗しない**こと。
  - 「未生成ならブロックしない」という方針が、**生成済みチェックリストのコミット忘れ**という
    最も起きやすい経路で機構を無言で無効化すること。→ exit code 1 の警告を足す設計へ変えた。

- 敵対的レビュー2回目も同じ質の指摘を返した。設計を差し替えることになった重いものが3件。
  - **`HEAD == @{upstream}` が両方向に誤る。** 一時リポジトリで実測して確認できた
    （up-to-date な再pushを「成功」と読み、`git push origin HEAD:other` の成功を「失敗」と読み、
    upstream未設定では `rev-parse` が非0で `set -e` 配下のhookごと落ちる）。
    `git branch --remotes --contains HEAD` へ差し替え、5ケースで正しく振る舞うことを測った。
  - **ブロック条件が肯定形（`pending` が1件以上）で fail-open だった。** 状態列のタイプミス・
    空ファイル・列ずれ・行の削除がすべて素通りする。「縮退時はブロック側へ倒す」という自分の
    方針と正反対だった。否定形（全行が `done`/`skip` かつ想定5件のidが揃うときだけ通す）へ反転させた。
  - **flow-id 5-5 の片付け直後の 5-6 のpushで、次回分が再生成されてしまう。** 片付けたはずの
    `wip/worklogs/` に未追跡ファイルが1本残ってタスクが終わる。生成条件3（HEADにタスク成果物が
    残っていること）を足して止めた。

## ダメだったこと

- **`grep -n "grep -z" extract-frontmatter.sh` を「`.tsv` が載らないこと」の検証として書いていた。**
  走査対象の拡張子が何であっても1行ヒットするので検証になっていない（敵対的レビューで指摘）。
  実際にダミーの `.tsv` を置いて `extract-frontmatter.sh` を走らせ、`index.jsonl` に現れないこと
  （`grep -c` が0）まで確かめる形へ直した。
- **`cleanup-task.sh --help` を検証コマンドに入れていたが、確かめたいのは削除対象・除外対象の実装**
  だった。`--dry-run` の実行（`deletedFiles` に `.tsv` が入ること・`targetDirs` が設定値由来で
  あること）へ置き換えた。
- **「最大値+1 は冪等」と書いていたが誤りだった。** チェックリスト自身がファイル数を増やすため、
  同じ断面で2回走れば2本目が生える。冪等性はヘッダの `# generated-for: <SHA>` が担保している。
  同じ誤りが、却下案の却下理由にも紛れていた。
- **`grep` の実行結果として、実際とは違う出力を貼っていた**（1行だけ書いていたが実際は3行）。
  引用は実行して貼り直した。
- **3本目のhookを足すと `test_sync_gemini_assets.sh` のT11が古くなることを見落としていた。**
  T11は2本に決め打ちされており、3本目の写経がドリフトしても緑のままになる。T11の更新を
  実装単位へ入れた。

## 次の一歩

- flow-id 2-10: 調査結果をもとにMR descriptionを更新する。
- flow-id 3-1: 個別作業計画（`【実装】【テスト】…`）を作成する。

---
