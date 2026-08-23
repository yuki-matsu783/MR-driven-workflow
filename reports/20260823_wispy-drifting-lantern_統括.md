---
title: 統括 — .claude/state を wip/state へ移す（issue #184）
type: report
description: issue #184 の全フェーズを通した最終統括レポート。何を変えたか・どう検証したか・レビューで見てほしい点
tags: [report, workflow, distribution]
keywords: [統括, wip, state, gitignore, dist-layers, DDR, i0184-01, issue184, issue165]
---

# 統括 — `.claude/state` を `wip/state` へ移す（issue #184）

- issue: #184 / PR: #190
- ブランチ: `claude/state-wip-directory-xj93sb`
- フェーズ5〈クローズ〉 flow-id 5-4 / 2026-08-23

## 何をしたか

`.gitignore` 対象のローカル作業状態を `.claude/state/` から、リポジトリルート直下の
`wip/state/` へ移した。

| 状態 | 旧 | 新 |
|---|---|---|
| 参照リンク組み立て用の前回push SHA | `.claude/state/review-links/<branch>.txt` | `wip/state/review-links/<branch>.txt` |
| 敵対的レビューの投稿件数 | `.claude/state/adversarial-review/<branch>.json` | `wip/state/adversarial-review/<branch>.json` |

**動機は `.claude/` を「配る資産だけ」にすること。** `.claude/` は配布単位であり
（`apply-mr-workflow-to-project` が一式を配り、`sync-gemini-assets.sh` が `.gemini/` へ変換する）、
その中に配布先のローカル状態が同居していると、配る側の仕組みのどちらにも除外の設定が要る。
`wip/`（issue #165 が定義する、mainに残らない作業用の親ディレクトリ）へ出せば、
「範囲に入れない」で済む。

## issueの前提を補完したこと

**issue #184 は本文が空だった**（タイトルと、マージ前通知のコメント1件のみ）。着手前に
`AskUserQuestion` で2点を確認し、その回答を全体作業計画の前提として固定している。

| 確認事項 | 回答 |
|---|---|
| 「wipディレクトリ」の位置 | ルート直下 `wip/state/`（#165 が新設予定の `wip/` をこのissueで先に作る） |
| 移動対象の範囲 | `.claude/state/` のみ（`usage/` は対象外） |

## 変更したファイル（計16件）

| 区分 | ファイル |
|---|---|
| 保存先パス | `.gitignore` / `.claude/dist-layers.json` / `.claude/hooks/post-push-compact-prompt.sh` / `.claude/scripts/src/adversarial-review-count.sh` / `.claude/scripts/src/sync-gemini-assets.sh` |
| テスト | `test_adversarial_review_count.sh` / `test_install_to_project.sh` / `test_sync_gemini_assets.sh` |
| 設計反映 | `.claude/rules/directory-structure.md` / `.claude/docs/spec/issue-mr-workflow.md` / `adversarial-review.md` / `sync-gemini-assets.md` |
| DDR | `.claude/docs/ddr/i0184-01-….md`（新規）／ `.claude/docs/README.md`（一覧の再生成） |
| AIアセット反映 | `.claude/rules/git-workflow.md` / `.claude/rules/shell-script-style.md` |
| 変換生成物 | `.gemini/` 配下（`sync-gemini-assets.sh` が再生成） |

## 判断したこと（DDR `i0184-01`）

1. **移設先を `wip/state/` にした。** `.claude/wip/state/`（`.claude/` 内に留める）と
   `usage/state/` への統合は却下。前者は移す動機を満たさず、後者は DDR `i0013-01` の
   責務分離の判断を覆すため。
2. **`.gitignore` のパターンを `/wip/` へ広げない。** #165 が置く `wip/plans` 等は
   **追跡対象**であり、丸ごと無視される。
3. **旧パス `/.claude/state/` の除外行を移行用に残した。** 差し替えるだけだと、既存の作業ツリーに
   残る状態ファイルが `git status` に現れる（**作業中に実際に踏んだ**）。削除条件をコメントへ明記。
4. **旧→新の自動移行コードは書かない。** 両ファイルとも「無ければ初回」のフォールバックを持ち、
   実害は1回分の情報欠落に留まる。1回しか効かないコードが恒久的に残るコストのほうが大きい。

## 検証（すべて実行済み）

```
bash .claude/scripts/test/test_adversarial_review_count.sh → passed=22 failures=0
bash .claude/scripts/test/test_sync_gemini_assets.sh       → passed=91 failures=0
bash .claude/scripts/test/test_install_to_project.sh       → passed=99 failures=0
bash .claude/scripts/src/check-dist-coverage.sh            → 結果: OK（4種すべて通過。検査2は 10/10 行）
bash .claude/scripts/src/check-doc-references.sh           → 参照切れ数=0（候補247件）
bash .claude/scripts/src/generate-ddr-list.sh              → 86件へ更新（i0184-01 の行が入った）
bash .claude/scripts/src/check-base-conflicts.sh           → hasConflict: false
bash -n（変更した .sh 3本）                                 → 構文OK

git check-ignore -v wip/state/.probe → .gitignore:26:/wip/state/
git diff 4be448a -- .claude/docs/ddr/ | grep -c '^-[^-]' → 0（既存DDR本文の削除行ゼロ）
```

## レビューで特に見てほしい点

1. **`.gitignore` の3行**（`/wip/state/` と、移行用に残した `/.claude/state/`、およびそのコメント）。
   移行用の行を残す判断そのものと、削除条件の書き方。
2. **`.claude/dist-layers.json` の `local` エントリ2件**。`note` を実態
   （前回push SHA＋敵対的レビューの投稿件数）へ直している。
3. **`test_sync_gemini_assets.sh` のフィクスチャ差し替え**。`.claude/state/last-push-sha` →
   `.claude/settings.local.json`。`wip/state/` にすると `-- .claude` の列挙範囲外になり、
   テストが**常に成功する空振り**へ変わるため、`.claude/` 配下に残る `.gitignore` 対象へ替えている。
4. **`.claude/docs/spec/issue-mr-workflow.md`**。現在の仕様（「/compact実施の呼びかけ」節）だけを
   直し、**issue #13 の過去changelog（2301〜2302行目）は無変更のまま**で、末尾に issue #184 の
   新規エントリを足している。
5. **`.claude/rules/` への追記2件**（`git-workflow.md` / `shell-script-style.md`）。
   いずれも作業中に踏んだ罠を (c)「アセットはあったが罠が書かれていなかった」と判定して
   既存節へ追記したもの。常時読込のアセットを新規に増やしていない。

## このセッションで実施できなかったこと

- **人間のレビュー往復**（flow-id 1-5・3-3/3-4・3-8/3-9・4-3/4-4・4-8/4-9）。
  該当ループ範囲の進捗記号は `[]` のままにしてある
  （`.claude/rules/docs-workflow.md`「非対話的実行環境」）。
- **git bash（Windows）実機での確認。** 実行環境がLinuxのため。今回の変更は文字列としてのパスの
  差し替えのみで、パス変換・改行コード・外部プロセス起動には触れていない。
- **`.claude/VERSION` の更新。** 据え置いている（判断は人間に委ねる）。

## 関連

- **issue #165**（`plans/worklog/reports` を `wip/` 配下へ集約）へ、マージ前通知を投稿済み
  （`wip/` を先に作ったこと・`/wip/` へ広げてはいけないこと・旧パスの除外行が残っていること）。
- **DDR `i0013-01`**（参照リンクの状態をローカルに持つ判断）と **`i0039-01`** は、
  旧パス表記のまま残している（DDR本文は変更しない運用）。
