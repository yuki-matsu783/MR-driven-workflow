---
title: worklog 【調査】配布アセットの層分けとmanifest方式 push3
type: log
description: 敵対的レビュー（フェーズ2・1回目）の投稿と、指摘13件の計画への反映・返信の記録
tags: [worklog, distribution, manifest, review]
keywords: [敵対的レビュー, findings, インラインコメント, 層分け, local, dirty, DEVELOPERS, 検証手順, 網羅性]
---

# worklog: 【調査】配布アセットの層分けとmanifest方式

対象: issue #26 の配布方式作り直し（2026-08-22）。
全体作業計画: `plans/ai-asset-manifest-distribution.md`
個別作業計画: `plans/【調査】配布アセットの層分けとmanifest方式.md`
push回数: 3

## 試したこと

- `adversarial-reviewer` サブエージェントで `plans/` の2ファイルを敵対的レビューした
  （フェーズ2・1回目。`adversarial-review-count.sh increment 2` → 1）。findings 13件。
- 選別（確度×重大度、1回あたり10件の上限）を適用し、major 9件 + minor/high 1件の計10件を
  PR #154 へインライン投稿した。MCP経路（`pull_request_review_write` create →
  `add_comment_to_pending_review` ×10 → `submit_pending` event=COMMENT）。
- 投稿しなかった3件も含め、**13件すべてを計画へ反映**した。
- 投稿した10スレッドへ `add_reply_to_pull_request_comment` で個別に返信した
  （本文の先頭に `Claude Codeより:` の署名）。

## うまくいったこと

- **検証手順の欠陥が、実施前に見つかった。** 検証1（既存欠陥の再現）は書いたコマンドでは
  欠陥1しか再現できず、欠陥2・4は発火条件を配布先へ仕込まないと出ない。とくに欠陥4は
  `safe_copy_dir` 経由のファイルでないと再現せず、`HANDOFF.md`（`safe_copy_file` 経由）だと
  ATTENTIONが出てしまい再現にならない、という区別まで指摘で得られた。
- **検証2の分母がそもそも一致しない**ことも判明した（全追跡171件 vs 割り当て表の範囲164件、
  かつ `plans/` `worklog/` `reports/` は調査自身が増やす）。`:(exclude)` で範囲を揃え、
  除外件数も出す形へ直した。
- `local` 層の列挙方法が実行環境依存だという指摘は、この環境で `/usage/` と `.gemini/` 配下が
  1件も現れない（未生成・`setup-gemini-links.sh` 未実行）という実測に裏づけられていた。
  「`.gitignore` のパターンを正とする」へ統一できた。
- 受け入れ条件どうしの衝突が2件見つかった。(1) 受け入れ条件2（`local` は触らない）と
  受け入れ条件8（`.gemini/` の実体コピーを再適用で最新化）、(2) 受け入れ条件1（4層で固定）と
  「第5の層を作るか」という調査2の論点。どちらも調査項目・出口条件として計画へ落とした。
- 受け入れ条件10の後半（`DEVELOPERS.md` の更新）が、どの種別にも割り当たっていなかった。
  フェーズ3の `【AIアセット作成】` へ1箇所で確定させた。

## ダメだったこと

- `update-handoff-progress.sh set-header` の引数を `--push` と書いて失敗した。正しくは
  `--push-count`。エラーメッセージは出るので実害は無いが、他の3コマンドが先に成功していたため、
  1回の実行で一部だけ反映される形になった（順序に注意）。
- 個別調査計画の当初版は「この調査で決めきるのは3点」と要約していたが、実際の調査項目は7件で、
  要約と詳細の粒度が食い違っていた。「とくに合意が要るのは3点」へ改めた。

## 次の一歩

- flow-id 2-5: `describe` でMR descriptionを更新する。
- flow-id 2-6: 調査7項目を実施し、`reports/` のmd・htmlへ記録する。

---
