---
title: worklog 20260819 cheeky-baking-lantern 【設計反映】create-commitの仕様とパス分類方針の記録 push5
type: log
description: create-commit.shのspec新規作成とDDR 0029作成に関する作業ログ
tags: [issue-60, worklog, 設計反映, ddr]
keywords: [spec, DDR 0029, create-commit, 却下案, README, frontmatter, push5]
---

# worklog: 【設計反映】create-commitの仕様とパス分類方針の記録

対象: `.claude/docs/spec/create-commit.md` の新規作成と、DDR 0029 による採用方針・却下案の記録
（issue #60、2026-08-19）。
全体作業計画: `plans/cheeky-baking-lantern.md`
個別反映計画: `plans/【設計反映】create-commitの仕様とパス分類方針の記録.md`
push回数: 5

## 試したこと

- flow-id 3-8: レビューOKを受け、`comments all` で未解決スレッドが無いことを確認した
  （残っていたのは自動投稿の対応工数レポートのみ）
- flow-id 3-10: 実装結果を反映してMR descriptionを更新した（調査・実装・検証10ケースの表を含む）
- flow-id 4-1: 個別反映計画を**設計反映とAIアセット反映の2ファイルに分けて**作成した
  （`.claude/skills/issue-mr-flow/SKILL.md`「種別を複数併記する場合／分ける場合」の方針どおり）
- flow-id 4-5: 反映計画の内容をMR descriptionへ反映した
- flow-id 4-6（1周目・設計反映）: `.claude/docs/spec/create-commit.md` を新規作成し、
  DDR 0029 と `.claude/docs/README.md` の一覧を更新した

## うまくいったこと

- 全体作業計画の時点で想定していた「ラッパー内部のパス限定 `-A` は絶対ルールの例外」という
  注記が、`-A` を採用しなかったことで**丸ごと不要になった**。調査を先に回したことで、
  ドキュメント側の複雑さも減った
- specに「根拠にした git の挙動」節を設け、フェーズ2の実測値（削除のステージ／pathspecの照合先／
  検証の原子性／空pathspecの差）を表で残した。将来この分類ロジックを触る人が、
  **実測をやり直さずに前提を確認できる**
- UNKNOWNの想定原因はspecへ集約し、エラーメッセージ側は事実のみに保った。8進エスケープ表記の
  回避策（`git -c core.quotepath=false status`）まで書けたのは、メッセージではなくspecだったから

## ダメだったこと

- HANDOFF.mdの進捗表で、単発ステップの 2-2 / 3-2 が `[]` のまま取り残されていた
  （ループ範囲の記号を手で戻した際、隣接する単発ステップまで巻き込んで戻していた）。
  **ループ範囲の記号を手で戻すときは、範囲外の行を巻き込んでいないか必ず確認する**
- **`extract-frontmatter.sh` の既存バグを踏んだ（issue #60の範囲外）。**
  `plans/【調査】git-addの削除済みパス挙動.md` の `keywords` に `-A` という単独要素があると、
  `run_fm_jq` が `jq -nc ... --args <items...>` で渡す位置引数の中でjqがこれをオプションとして
  解釈し、`jq: Unknown option -A` で失敗する。その結果、**当該ファイルのindex.jsonlの行が空に
  なり、インデックスから丸ごと欠落する**（`plans/index.jsonl` は5行あるが有効なのは4行）。
  - `yq` がある環境では yq 経路を通るため表面化しない。この環境には `yq` が無い
  - スクリプトは終了コード0で完了し、警告以外に異常が見えないため気づきにくい
  - 再現用のキーワードを消すと証拠も消えるため、`【調査】` ファイルはそのまま残した
    （flow-id 5-1で削除される）
- 検証のために `extract-frontmatter.sh <単一ファイル>` を実行したが、このスクリプトは
  ディレクトリのみを受け付けるため「no markdown files found」で終了しており、
  **エラー件数0という結果を一度誤読した**。`|| true` と `grep -c` を組み合わせると、
  実行自体が失敗しても「0件」に見える

## 次の一歩

- flow-id 4-7: 設計反映をcommitし、リモートへ反映してレビュー依頼を行う
- flow-id 4-6（2周目・AIアセット反映）: 設計反映のレビュー完了後に着手する
- `extract-frontmatter.sh` の件は本issueの範囲外のため、**別issueとして起票を提案する**

---
