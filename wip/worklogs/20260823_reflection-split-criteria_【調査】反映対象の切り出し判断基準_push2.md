---
title: worklog 20260823 【調査】反映対象の切り出し判断基準 push2
type: log
description: issue #176 フェーズ2〈調査〉の詳細な試行錯誤ログ（push2）
tags: [worklog, issue-mr-flow, research]
keywords: [調査, 切り出し, 反映対象, 4類型, DDR, 固定費, 記録先, 敵対的レビュー]
---

# worklog: 【調査】反映対象の切り出し判断基準

対象: フェーズ4の反映対象に対する「このMRで対応するか別issueへ切り出すか」の判断基準を書くための調査（2026-08-23）。
全体作業計画: `wip/plans/reflection-split-criteria.md`
個別作業計画: `wip/plans/【調査】反映対象の切り出し判断基準.md`
push回数: 3

## 試したこと

- flow-id 1-2〜1-6: issue #176 の本文・コメントを MCP（`mcp__github__issue_read`）で取得した。
  `gh` CLI が不在の実行環境のため、`Provider.sh` の CLI 経路は使わず MCP フォールバック
  （`references/mcp-fallback.md`）を採った。
- 全体作業計画・個別調査計画を作成し、いずれも同名 `.html` を
  `plans.template.html` から生成した。**プレースホルダ残存 0 件・アンカー破断 0 件**を
  スクリプトで確認した（テンプレート冒頭コメントが求める検査）。

- 敵対的レビュー（フェーズ2・1/3回目）を `adversarial-review` スキルの手順どおり実施した。
  観点表は `collect-review-points.sh` でルート＋`wip/plans/` の2枚をマージ（191行）。
  findings 12件を確度×重大度の表で1次振り分け（投稿候補6件／報告6件）し、投稿件数は
  `select-adversarial-findings.sh` へ委ねて決定的に選別した（6件すべて投稿）。
- 指摘の裏取りに `grep -rn -- '別issue' .claude/skills .claude/rules` を実行し、**10行**
  （うち #64 の基準を指すのは3箇所）を確認した。指摘の件数を鵜呑みにせず自分で数え直す、という
  `review-loop.md` の指示どおりの手順。

## うまくいったこと

- HTMLビューの生成を「テンプレートの `<!DOCTYPE>`〜`<body>` をそのまま流用し、body だけを
  書き下ろす」形にした。`<style>` を触らないため、テンプレートが保証する自己完結性
  （外部依存なし）が自動的に保たれる。

- **検証コマンドを「着手前に変更前のツリーで実行する」を実際にやった。** 1本目=0／2本目=1／
  3本目の `ls`=失敗かつ `grep`=0 で、いずれも期待どおり。**この実測をやったからこそ、
  1本目の `grep -rc` がファイルごとの件数を出す形で `wc -l` の当てが外れていることに気づけた**
  （`grep -rl … | wc -l` へ直した）。机上で書いたままなら合格条件の読み方がずれていた。

## ダメだったこと

- 最初の `git fetch origin main claude/reflection-plan-criteria-tnhfvs` が
  `fatal: couldn't find remote ref claude/…` で落ち、**同じコマンドに含めた `main` の
  fetch も反映されなかった**（`origin/main` が古いまま残り、`git rev-list --left-right`
  が「HEAD が 32 コミット進んでいる」という誤った読みを返した）。ブランチを個別に fetch し
  直して解消した。**複数refspecの fetch は、1つでも存在しないと他も巻き添えになる。**
- **`search-frontmatter.sh --format jsonl` の出力形を確かめずにjqフィルタを書いた。**
  `select(.status)` と書いたが、実際のレコードは `concept_id` / `directory` / `frontmatter` /
  `mtime` の4キーで、`status` も `title` も `frontmatter` の下にある。トップレベルの `.status` は
  常に null なので**superseded が何件あっても0件を返す**——つまりガードとして一切機能しない
  空振りだった。敵対的レビューが指摘し、実測（2件返る）で確認して直した。
  **`references/planning.md`「手順3」が `--format jsonl` を勧めながらレコードの形を書いて
  いない**ことに起因するので、フェーズ4の `【AIアセット反映】` の候補として拾う。
- **計画の背景に、issue本文の要約をそのまま書き写した。** 「切り出しに触れているのは1文だけ」
  「issue #64 は着手前のissue粒度を判定する基準」の2つがいずれも不正確で、敵対的レビューに
  指摘された。**issue本文は起票時点の理解であって、裏取り済みの事実ではない。**

## 次の一歩

- flow-id 2-1 の敵対的レビュー（フェーズ2・1回目）を実施する。
- flow-id 2-6: 6問の調査を実施し、結果を `wip/reports/` へ書く。
