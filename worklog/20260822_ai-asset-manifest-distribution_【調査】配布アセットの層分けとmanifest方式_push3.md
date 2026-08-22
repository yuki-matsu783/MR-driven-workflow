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

- flow-id 2-7: commit・pushしてレビュー依頼を出す（敵対的レビュー2回目）。

## 追記: flow-id 2-5・2-6の実施

### 試したこと（続き）

- flow-id 2-5: PR #154 のdescriptionを全面差し替えした（MCP経路 `update_pull_request`）。
- flow-id 2-6: 調査7項目を実施し、`reports/` のmd・htmlへ記録した。

### うまくいったこと（続き）

- **改訂した検証1で欠陥4が再現した**（WARNING=1 / ATTENTION=0）。`safe_copy_dir` 経由の
  ファイルを改変するという条件が正しかったことを実測で確かめられた。
- **配布先の実際の中身を `ls -1a` で棚卸ししたところ、issue にも spec にも記録が無い欠陥が
  3件見つかった**（`HANDOFF.md` が上書き対象／`REVIEW-POINTS.md` が4件中1件しか配られない／
  `worklog/TEMPLATE.md` が配られず `reports/` ディレクトリも作られない）。
  「何が配られているか」ではなく「**何が配られていないか**」を見たことで出てきた。
- 受け入れ条件2（`local` を触らない）と8（`.gemini/` の実体コピーを最新化）の衝突は、
  **所有者を分ける**（インストーラは `.gemini/` に触らず、`setup-gemini-links.sh` が責任を持つ）
  ことで、層を増やさずに解消できると整理できた。
- `REVIEW-POINTS.md` も同様に、`core` ＋ `REVIEW-POINTS.local.md`（`seed`）の併設で層を
  増やさずに済んだ。必要な変更は `collect-review-points.sh` の1箇所だけだと確認した
  （現行は各祖先ディレクトリの `REVIEW-POINTS.md` だけを見ている）。

### ダメだったこと（続き）

- **改訂した検証1のうち、欠陥2の再現手順が間違っていた。** コメント行を「1回目の適用の後」に
  仕込む書き方にしていたが、1回目で本物の行が入るため2回目は本物に一致してしまい再現しない。
  **1回目より前**に仕込む必要がある（実測で判明し、計画側を修正した）。
  敵対的レビューの指摘を受けて直した手順が、直した先でまた別の順序の誤りを含んでいた形。
- `.gemini/` のリンク／実体の判別は `[ -L ]` だけでは足りない可能性が残った。NTFSジャンクションは
  bashからはディレクトリに見えるため、実体コピーと区別できない。**Windows実機でしか確認できず、
  未確認事項として残す**。

---
