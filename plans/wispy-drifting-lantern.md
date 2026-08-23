---
title: 全体作業計画 — .claude/state を wip/state へ移す（issue #184）
type: plan
description: ローカル作業状態 .claude/state/ を、寿命を名前で示す wip/ 配下（wip/state/）へ移すための全体作業計画
tags: [plan, workflow, distribution]
keywords: [wip, state, dist-layers, gitignore, ローカル作業状態, post-push-compact-prompt, adversarial-review-count, 配布, issue184]
---

# 全体作業計画 — `.claude/state` を `wip/state` へ移す（issue #184）

- issue: #184 `.claude\state`はwipディレクトリで管理する
- ブランチ: `claude/state-wip-directory-xj93sb`
- 作成日: 2026-08-23

## この計画で何をするか

`.gitignore` 対象のローカル作業状態である `.claude/state/` を、リポジトリルート直下の
`wip/state/` へ移す。あわせて、`.claude/state` を名指ししている**現在の状態を説明する記述**
（`.gitignore`・層分け定義・スクリプト・単体テスト・spec・rules）を新しいパスへ更新する。

## 前提（issueの補完）

**issue #184 は本文が空である**（タイトルと、マージ前通知のコメント1件のみ）。このため
着手前に `AskUserQuestion` で次の2点をユーザーへ確認し、回答を得た。

| 確認事項 | 回答 |
|---|---|
| 「wipディレクトリ」の位置 | **ルート直下 `wip/state/`**（#165 が新設予定の `wip/` を、このissueで先に作る） |
| 移動対象の範囲 | **`.claude/state/` のみ**（`usage/` は今回の対象外） |

この2点を本計画の前提として固定する。

## なぜ移すか

`.claude/` は**配布単位**である（`apply-mr-workflow-to-project` が `.claude/` 一式を他プロジェクトへ
配る。`.claude/docs/spec/asset-distribution.md`）。その中に「配ってはいけない・そもそも配布先の
ローカル状態」である `state/` が同居していると、配布・変換同期のたびに**除外の設定が1つ必要になる**。
実際、`sync-gemini-assets.sh`（`.claude/` → `.gemini/` の変換同期）と `install-to-project.sh`
（配布）はいずれも `.claude/state/` を除外対象として扱っている。

`wip/`（#165 が定義する「main には残らない作業用の親ディレクトリ」）配下へ出せば、
`.claude/` は「配る資産だけ」になり、除外は「`wip/` は配らない」の1行に集約できる。

## 変更対象

| ファイル | 操作 | 何をするか |
|---|---|---|
| `.gitignore` | 変更 | `dist:begin`〜`dist:end` の内側で `/.claude/state/` → `/wip/state/` |
| `.claude/dist-layers.json` | 変更 | `local` の `gitignorePattern` を `/.claude/state/` → `/wip/state/`（`note` も実態に合わせる） |
| `.claude/hooks/post-push-compact-prompt.sh` | 変更 | 状態ファイルのパスと、冒頭コメントの説明 |
| `.claude/scripts/src/adversarial-review-count.sh` | 変更 | 状態ファイルのパスと、冒頭コメントの説明 |
| `.claude/scripts/src/sync-gemini-assets.sh` | 変更 | 除外の説明コメント（`.claude/state/` が `.claude/` 配下から消えるため） |
| `.claude/scripts/test/test_adversarial_review_count.sh` | 変更 | 期待パスを `wip/state/...` へ |
| `.claude/scripts/test/test_sync_gemini_assets.sh` | 変更 | 「gitignore対象は `.gemini/` へ出ない」を確かめるフィクスチャを、`.claude/state` に依存しない形へ |
| `.claude/scripts/test/test_install_to_project.sh` | 変更 | 「local は作られない」の対象を `wip/state` へ |
| `.claude/rules/directory-structure.md` | 変更 | 現在の状態を説明する2箇所 |
| `.claude/docs/spec/issue-mr-workflow.md` | 変更 | 「/compact実施の呼びかけ」節（現在の仕様）。**過去changelogは触らない** |
| `.claude/docs/spec/adversarial-review.md` | 変更 | 状態ファイルのパス |
| `.claude/docs/spec/sync-gemini-assets.md` | 変更 | 除外対象の説明 |
| `.claude/docs/ddr/i0184-01-….md` | 新規 | 移動先を `wip/state/` にした判断と却下案 |
| `.claude/docs/README.md` | 変更 | DDR一覧（`generate-ddr-list.sh` の生成結果） |

## 方針

- **`git mv` は使わない**（使えない）。`.claude/state/` は `.gitignore` 対象で**追跡ファイルが
  1件も無い**ため、gitの履歴上の移動は発生しない。行うのは「これから状態を書く先」の変更である。
- **`wip/` は空のディレクトリとしてコミットしない**。`wip/state/` は実行時に `mkdir -p` で
  作られる（現状の `.claude/state/` と同じ）。`.gitignore` へ `/wip/state/` を書くことで、
  #165 が後から `wip/plans` 等の**追跡対象**を同じ親へ置いても衝突しない。
- **DDR本文と spec 内の過去changelogは書き換えない**（`.claude/rules/docs-workflow.md`）。
  一括 `sed` を使わず、現在の状態を説明する節だけを個別に直す。移動の事実は spec の
  changelog へ**新規エントリとして追記**する。
- `.gemini/` は `.claude/` からの変換生成物なので、flow-id 5-3 で `sync-gemini-assets.sh` を
  流して追随させる（手で編集しない）。

### 置き換え前・置き換え後

| | 前 | 後 |
|---|---|---|
| `.gitignore` の行 | `/.claude/state/` | `/wip/state/` |
| `dist-layers.json` | `{ "layer": "local", "gitignorePattern": "/.claude/state/", … }` | `{ "layer": "local", "gitignorePattern": "/wip/state/", … }` |
| 参照リンク状態 | `.claude/state/review-links/<branch>.txt` | `wip/state/review-links/<branch>.txt` |
| 敵対的レビュー件数 | `.claude/state/adversarial-review/<branch>.json` | `wip/state/adversarial-review/<branch>.json` |

## フェーズ2〈調査〉

**実施しない。** 調べる問いが残っていないため。

- `.claude/state` の全出現箇所は、着手前の `grep` で列挙済みである（`.md` `.sh` `.json`
  `.gitignore` を対象に14ファイル）。どれが「現在の状態の説明」でどれが「過去changelog／DDR
  本文」かも、該当箇所の前後を読んで判別済みである。
- `check-dist-coverage.sh` の検査1〜4のうち、この変更が触るのは検査2（`.gitignore` の行の被覆）
  だけであることを、スクリプトの `usage()` と実装で確認済みである（`.claude/state` は追跡
  ファイルを持たないため、`path` エントリは元々存在せず、検査1・検査3には現れない）。
- 残る不確実性は「変更後に既存テストが通るか」だけであり、これは調査ではなくフェーズ3の
  検証で確かめるべきものである。

## フェーズ4〈反映〉

反映対象は flow-id 4-1 で洗い出す。現時点の見込みは次のとおり（確定ではない）。

- **spec**: `issue-mr-workflow.md`（「/compact実施の呼びかけ」節＋changelog新規エントリ）、
  `adversarial-review.md`、`sync-gemini-assets.md`
- **rules**: `directory-structure.md`（ツリー直後の注記・`.claude/state/` の説明段落）
- **ddr**: `i0184-01`（移動先の選定理由と却下案）＋ `generate-ddr-list.sh` によるDDR一覧の再生成
- **usecase**: 影響の有無を確認する（`.claude/docs/usecase/`）

## やらないこと（スコープ外）

- **`usage/` の移動**（ユーザー確認で対象外と決定）。
- **`plans/` `worklog/` `reports/` の `wip/` 配下への集約と `worklog` → `worklogs` 改名**。
  これは #165 の担当である。本issueは `wip/` という親ディレクトリを先に作るだけで、
  `.mrworkflow.json` の `plansDir` 等は触らない。
- **既存DDR（`i0013-01` `i0039-01`）の本文の書き換え**。旧パス表記のまま残す（意図した挙動）。
- **`.claude/settings.json` の `plansDirectory` の変更**。#165 の受け入れ条件1が扱う。

## 検証

```bash
bash .claude/scripts/src/check-dist-coverage.sh
bash .claude/scripts/test/test_adversarial_review_count.sh
bash .claude/scripts/test/test_sync_gemini_assets.sh
bash .claude/scripts/test/test_install_to_project.sh
bash .claude/scripts/src/check-doc-references.sh
bash -n .claude/hooks/post-push-compact-prompt.sh
```

合格条件: `check-dist-coverage.sh` が「結果: OK」で終わり、各テストが `failures=0` で終了
コード0。`grep -rn '\.claude/state' --include='*.sh' --include='*.json' .` の残存が0件
（`.md` 側は DDR本文・過去changelog のみが残る）。

## 比較検討した案

| 案 | 利点 | 採否と理由 |
|---|---|---|
| ルート直下 `wip/state/` | `.claude/` が「配る資産だけ」になる。#165 の `wip/` と親を共有できる | **採用**（ユーザー確認の回答） |
| `.claude/wip/state/` | ルート直下のディレクトリが増えない | 却下。`.claude/` 内に残るため配布・変換同期での除外が消えず、移す動機を満たさない。`wip/` が2箇所に並ぶ |
| `usage/state/` へ統合 | ローカル状態が1箇所になる | 却下。DDR `i0013-01` が責務分離のために別ディレクトリにした判断を覆すことになり、本issueの範囲を超える |
