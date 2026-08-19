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

（次タスク着手時に記入する）

## やったこと

（無し）

## 次にやること

（無し）

## 判断を迷った内容

（次タスク着手時に記入する。以下は flow-id 5-2 でのmainマージ時の統合判断の記録。issue #44 の
マージ後に削除してよい）

- **DDR番号の衝突**: 本ブランチの `0035-リポジトリURLは…` を **0036** へ繰り下げた（main側に
  issue #41 の 0035〈PR/MR作成はAIエージェントに委ねる〉が既に入っていたため）。ファイル名・
  frontmatterの `title`・本文見出し・`.claude/docs/README.md` のDDR一覧・spec内の参照2箇所
  （新節のリンクと影響範囲エントリ）・`Provider.sh` と `post-push-compact-prompt.sh` の
  コメント内参照を更新した。
- **spec `## 影響範囲`**: issue #41（先にmainへマージ済み）→ issue #44 の順で両エントリを残した。
  一括置換で main 側 issue #41 エントリの「DDR一覧へ0035を追加」まで 0036 へ書き換えてしまい、
  過去changelogの改変にあたるため元へ戻した（`.claude/rules/docs-workflow.md`
  「ファイル移動に伴うパス参照の一括置換は…過去changelogを対象に含めない」）。
  **DDR改番時の一括置換は、置換対象を自分のエントリだけに限定すること。**
- **`HANDOFF.md`**: main側は issue #41（PR #82）の作業状態が flow-id 5-1 未実施のまま残っていた
  ため、本ブランチ側の内容を採用した（HANDOFFは常に「このブランチの現状」を表すため）。
- **main が残した issue #41 の `plans/` `worklog/`**: flow-id 5-1 が未実施のままマージされて
  いたため、本ブランチの flow-id 5-1 で自分のファイルとまとめて削除した（issue #64 で
  issue #63 の残置ファイルを処理したときと同じ扱い）。
- **2回目のマージ（issue #42 / PR #83）**: Draft解除の直後に main がさらに進んだため、もう一度
  取り込んだ。issue #42 は `Provider.sh` と `post-push-compact-prompt.sh` という本ブランチと
  同じファイルを触っており、以下を統合した。
  - `Provider.sh`: 本ブランチが `get_provider` の直前へ追加した2関数
    （`build_repo_url_from_reply` / `repo_url_from_remote_url`）と、main側の `get_provider`
    メモ化（`_PROVIDER_CACHE`）は目的が独立しているため両方を残した。`get_repo_url` 本体は
    本ブランチ側（プロバイダ非依存）が正。
  - `post-push-compact-prompt.sh`: `build_links_text` のコメントで、本ブランチの
    「ローカル導出」という表現と、main側が足した `since_url` の説明の両方を残した。
  - spec `## 影響範囲`: issue #42（先にマージ済み）→ issue #44 の順で両エントリを残した。
  - `HANDOFF.md`: main側は issue #42 の作業状態が flow-id 5-1 未実施のまま残っていたため、
    本ブランチのリセット済みの内容を採用した（1回目と同じ判断）。
- **3回目のマージ（issue #32 / PR #85）**: またも main が進んだため取り込んだ。main が 0036 を
  取ったので本ブランチのDDRを **0036 → 0037** へ再度繰り下げた（ファイル名・frontmatter・
  本文見出し・DDR一覧・spec内の参照・`Provider.sh` / `post-push-compact-prompt.sh` の
  コメント内参照）。spec `## 影響範囲` は issue #32 → issue #44 の順で両方を残した。
  **短時間に複数PRが並行マージされる状況では、DDR番号は「マージ直前に確定する」前提で扱うこと**
  （番号を先に決め打ちしてドキュメントへ埋め込むと、マージのたびに追従作業が発生する）。
- 検証: コンフリクトマーカー無し／unmerged無し／DDR番号の重複無し／単体テスト6本すべて
  `failures=0`／`check-base-conflicts.sh` の `hasConflict` が `false`／CR混入なし。

## 未解決の内容

（無し）

## 守るべき条件・触ってはいけない範囲

（無し）
