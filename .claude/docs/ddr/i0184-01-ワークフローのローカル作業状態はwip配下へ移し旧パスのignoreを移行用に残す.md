---
title: i0184-01. ワークフローのローカル作業状態はwip配下へ移し旧パスのignoreを移行用に残す
type: ddr
description: .claude/state/ を wip/state/ へ移した理由（.claude/ を配布資産だけにする）と、.gitignore のパターンを /wip/ へ広げず旧パスの行を移行用に残した判断を記録したDDR
tags: [ddr, workflow, distribution, gitignore]
keywords: [wip, state, gitignore, dist-layers, 配布単位, 移行, review-links, adversarial-review, issue184, issue165]
---

# i0184-01. ワークフローのローカル作業状態はwip配下へ移し旧パスのignoreを移行用に残す

## 背景

`post-push-compact-prompt.sh`（前回push時点のHEAD SHA）と `adversarial-review-count.sh`
（敵対的レビューの投稿件数）は、いずれも `.gitignore` 対象のローカル作業状態を
`.claude/state/` 配下へ保存していた（DDR `i0013-01`）。

一方 `.claude/` は**配布単位**である。`apply-mr-workflow-to-project` が `.claude/` 一式を
他プロジェクトへ配り（`.claude/docs/spec/asset-distribution.md`）、`sync-gemini-assets.sh` が
`.claude/` を `.gemini/` へ変換同期する（`.claude/docs/spec/sync-gemini-assets.md`）。
その中に「そもそも配布先が各自で持つローカル状態」が同居していると、**配る側の仕組みの
どちらにも除外の設定が要る**。

issue #165 は、同じく「mainに残らない作業用の成果物」である `plans/` `worklog/` `reports/` を
`wip/` 配下へ集約することを決めている。ローカル作業状態も寿命の性質はこれに近い。

## 決定

**ワークフローのローカル作業状態を `.claude/state/` から、リポジトリルート直下の
`wip/state/` へ移す。**

| 状態 | 旧 | 新 |
|---|---|---|
| 参照リンク組み立て用の前回push SHA | `.claude/state/review-links/<branch>.txt` | `wip/state/review-links/<branch>.txt` |
| 敵対的レビューの投稿件数 | `.claude/state/adversarial-review/<branch>.json` | `wip/state/adversarial-review/<branch>.json` |

あわせて次の2点を決めた。

1. **`.gitignore` のパターンは `/wip/` ではなく `/wip/state/` にする。**
2. **旧パス `/.claude/state/` の除外行は、移行用の名残として残す。**

`wip/` 自体は空ディレクトリとしてコミットしない（`wip/state/` は実行時に `mkdir -p` で作られる）。
旧パスから新パスへの自動移行コードは書かない。

## 理由

### なぜ `wip/` 配下なのか

`.claude/` を**配る資産だけ**にできる。ローカル状態が外に出ていれば、`sync-gemini-assets.sh` の
列挙（`git ls-files -- .claude`）にも `install-to-project.sh` の配布対象にも、そもそも入らない。
「除外を設定して落とす」より「範囲に入れない」ほうが、設定の書き忘れで壊れる余地が無い。

issue #165 が `wip/` を新設する前だが、**このissueが先に `wip/` を作っても衝突しない**。
`wip/state/` は `.gitignore` 対象で、#165 が置く `wip/plans` 等は追跡対象であり、同じ親の下に
並ぶだけである。

### なぜ `/wip/` で無視しないのか

**#165 が `wip/` 配下へ置く `plans` `worklogs` `reports` は追跡対象である。** `/wip/` で無視すると
それらが丸ごと `.gitignore` にかかり、「コミットしたはずのものが入らない」という気づきにくい
壊れ方をする。将来 `wip/` 配下に別のローカル状態が増えたら、そのときに行を足す。

### なぜ旧パスの ignore を残すのか

パターンを差し替えるだけだと、**issue #184 より前に作られた `.claude/state/` の中身が、
追跡対象として `git status` に現れる**（本issueの作業中に実際に `?? .claude/state/` が出た）。
このリポジトリは「`git status` の出力を機械的に `commit` スキルへ渡さない」ことを規約で
求めているが（`.claude/rules/git-workflow.md`「コミット運用」）、それは人間・AIの注意に
依存する防御である。除外行1つで機械的に防げるなら、そちらのほうが安い。

`.gitignore` のコメントに「手元の `.claude/state/` を消したあとであれば、この行は削除してよい」
と削除条件を明示し、恒久的な負債にしない。`dist-layers.json` にも対応する `local` エントリを
足す（足さないと `check-dist-coverage.sh` の検査2——`.gitignore` の全行が被覆されているか——が
落ちる）。

### なぜ自動移行コードを書かないのか

どちらの状態ファイルも「無ければ初回とみなす」フォールバックを既に持つ
（`post-push-compact-prompt.sh` は前回push差分の2リンクを省略、`adversarial-review-count.sh` は
`{}` へフォールバックする）。引き継がれなかった場合の実害は「前回push差分のリンクが1回省略される」
「敵対的レビューの実行回数が1回分リセットされる」程度である。**1回しか効かないコードが恒久的に
残る**コストのほうが大きい。

## 却下した案

| 案 | 却下の理由 |
|---|---|
| `.claude/wip/state/` へ移す（`.claude/` 内に留める） | `.claude/` 内に残るため、配布・変換同期での除外が消えない。移す動機そのものを満たさない。加えて `wip/` が2箇所（ルートと `.claude/` 配下）に並び、どちらを指すのかが読み手に伝わらない |
| `usage/state/` へ統合する | DDR `i0013-01` が「責務分離のため対応工数レポート側とは別ディレクトリにする」と決めた判断を覆すことになり、issue #184 の範囲を超える。`usage/` は対応工数レポート機能の状態であり、レビュー参照リンク・敵対的レビューの件数とは持ち主が違う |
| `.gitignore` を `/wip/` にする | issue #165 が置く追跡対象（`wip/plans` `wip/worklogs` `wip/reports`）が丸ごと無視される（上記「理由」） |
| 旧パスの除外行を残さない | 既存の全開発者・全配布先で、旧パスの状態ファイルが追跡対象に現れる（上記「理由」） |
| 旧パスから新パスへ自動移行するコードを入れる | 1回しか効かないコードが恒久的に残る（上記「理由」） |
| issue #165 の完了を待ってから着手する | `wip/` は「作れば在る」だけのディレクトリで、先に作っても #165 の作業を妨げない。待つ理由が無い |

## 影響範囲

- `.gitignore` / `.claude/dist-layers.json`
- `.claude/hooks/post-push-compact-prompt.sh` / `.claude/scripts/src/adversarial-review-count.sh`
- `.claude/scripts/src/sync-gemini-assets.sh`（除外の説明コメント）
- `.claude/scripts/test/test_adversarial_review_count.sh` / `test_install_to_project.sh` /
  `test_sync_gemini_assets.sh`
- `.claude/rules/directory-structure.md` / `.claude/docs/spec/issue-mr-workflow.md` /
  `adversarial-review.md` / `sync-gemini-assets.md`

**既存のDDR（`i0013-01` `i0039-01`）は旧パス表記のまま残す**（本文は変更しない、という運用に従う。
`.claude/rules/docs-workflow.md`）。
