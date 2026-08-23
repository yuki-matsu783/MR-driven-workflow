---
title: 【実装】【テスト】stateの保存先をwip/stateへ移す
type: plan
description: ローカル作業状態の保存先を .claude/state/ から wip/state/ へ変える実装・テスト計画
tags: [plan, workflow, distribution]
keywords: [wip, state, gitignore, dist-layers, post-push-compact-prompt, adversarial-review-count, sync-gemini-assets, テスト]
---

# 【実装】【テスト】stateの保存先を `wip/state` へ移す

- issue: #184 / PR: #190
- 全体作業計画: `plans/wispy-drifting-lantern.md`
- フェーズ3〈作業〉 flow-id 3-1

## 前提（合意状況）

- 上位の計画: `plans/wispy-drifting-lantern.md`（移動先は**ルート直下 `wip/state/`**、
  対象は**`.claude/state/` のみ**。issue本文が空だったため `AskUserQuestion` で確認した回答）。
- フェーズ2〈調査〉は実施しない（同計画の該当節）。出現箇所の列挙と、
  「現在の状態の説明」／「過去changelog・DDR本文」の判別は着手前に済んでいる。

## この計画で何をするか

ローカル作業状態の**保存先パス**を `.claude/state/` から `wip/state/` へ変える。あわせて、
そのパスを名指ししている**現在の状態を説明する記述**を新しいパスへ更新する。

`【実装】`と`【テスト】`を1ファイルに併記するのは、**変更が既存テストの期待値と不可分**である
ため。パスを変える実装と、そのパスを検証しているテストの修正は同時に合意すべきで、フェーズを
分けても得るものが無い。

## 変更対象

### 実装（保存先パスそのもの）

| ファイル | 箇所 | 変更内容 |
|---|---|---|
| `.gitignore` | `dist:begin`〜`dist:end` の**内側** | `/.claude/state/` → `/wip/state/`（コメントも実態に合わせる）。**あわせて旧パス `/.claude/state/` を「移行用の名残」として残す**（下記「方針」） |
| `.claude/dist-layers.json` | `local` の `gitignorePattern` | `/.claude/state/` → `/wip/state/`（`note` も更新） |
| `.claude/hooks/post-push-compact-prompt.sh` | `state_file=` の組み立て・冒頭コメント | `wip/state/review-links/<branch>.txt` |
| `.claude/scripts/src/adversarial-review-count.sh` | `adversarial_review_state_path`・冒頭コメント | `wip/state/adversarial-review/<branch>.json` |
| `.claude/scripts/src/sync-gemini-assets.sh` | 列挙の説明コメント | 除外対象の例示から `.claude/state/` を落とす |

### テスト

| ファイル | 変更内容 |
|---|---|
| `.claude/scripts/test/test_adversarial_review_count.sh` | 期待パスを `wip/state/adversarial-review/…` へ |
| `.claude/scripts/test/test_sync_gemini_assets.sh` | 「gitignore対象は `.gemini/` へ出ない」を確かめるフィクスチャを、`.claude/state` に依存しない形（`.claude/settings.local.json`）へ差し替える |
| `.claude/scripts/test/test_install_to_project.sh` | 「`local` は作られない」の確認対象を `wip/state` へ |

## 方針

- **`git mv` は使わない（使えない）。** `.claude/state/` は `.gitignore` 対象で追跡ファイルが
  1件も無く、gitの履歴上の移動は発生しない。行うのは「これから状態を書く先」の変更である。
- **`wip/` を空ディレクトリとしてコミットしない。** `wip/state/` は実行時に `mkdir -p` で
  作られる（現状の `.claude/state/` と同じ）。`.gitignore` へ `/wip/state/` を書いておけば、
  #165 が後から `wip/plans` 等の**追跡対象**を同じ親へ置いても衝突しない。
- **`.gitignore` のパターンは `/wip/` ではなく `/wip/state/` にする。** `/wip/` にすると
  #165 が `wip/plans` 等の追跡ファイルを置いたときに丸ごと無視されてしまう。
- **旧パス `/.claude/state/` の除外行は残す（移行用の名残）。** パターンを差し替えるだけだと、
  issue #184 より前に作られた既存の状態ファイルが**追跡対象として `git status` に現れる**。
  変更一覧を機械的にコミットへ渡す運用（`.claude/rules/git-workflow.md`「コミット運用」）では
  それが巻き込まれる。行を残す代わりに「手元の `.claude/state/` を消したあとなら削除してよい」
  とコメントで明示する。`dist-layers.json` にも対応する `local` エントリを足す
  （足さないと `check-dist-coverage.sh` の検査2が落ちる）。
- 既存の状態ファイルの**移行処理は書かない**。どちらのファイルも「無ければ初回とみなす」
  フォールバックを既に持つため（`post-push-compact-prompt.sh` は前回push差分の2リンクを省略、
  `adversarial-review-count.sh` は `{}` へフォールバック）、旧パスの残骸は次のブランチ削除で
  自然に消える。移行コードは1回しか効かないのに恒久的に残る。

### 置き換え前・置き換え後

```
# .gitignore（dist:begin〜dist:end の内側）
- /.claude/state/
+ /wip/state/
+ /.claude/state/   ← 移行用の名残として残す（旧パスの残骸が git status に現れないように）

# .claude/dist-layers.json
- { "layer": "local", "gitignorePattern": "/.claude/state/", "note": "前回push時点のHEAD SHA" },
+ { "layer": "local", "gitignorePattern": "/wip/state/", "note": "ワークフローのローカル作業状態（前回push時点のHEAD SHA・敵対的レビューの投稿件数）" },

# .claude/hooks/post-push-compact-prompt.sh
- state_file="${repo_root}/.claude/state/review-links/${safe_branch}.txt"
+ state_file="${repo_root}/wip/state/review-links/${safe_branch}.txt"

# .claude/scripts/src/adversarial-review-count.sh
-   printf '.claude/state/adversarial-review/%s.json' "${branch//\//__}"
+   printf 'wip/state/adversarial-review/%s.json' "${branch//\//__}"
```

`dist-layers.json` の `note` を書き換えるのは、**現在の記述が実態とずれている**ため
（`.claude/state/` は前回push SHAだけでなく敵対的レビューの投稿件数も持つ）。パスを直す
ついでに、そのエントリが何を指すのかを正しくする。

## やらないこと（スコープ外）

- **`usage/` の移動**（ユーザー確認で対象外）。
- **`plans/` `worklog/` `reports/` の `wip/` 配下への集約**（#165 の担当）。`.mrworkflow.json` の
  `plansDir` 等・`.claude/settings.json` の `plansDirectory` は触らない。
- **DDR本文・spec内の過去changelogの書き換え**。旧パス表記のまま残す（意図した挙動）。
  spec の「現在の仕様」節の更新と changelog への新規エントリ追記は**フェーズ4**で行う。
- **旧 `.claude/state/` からの自動移行**（上記「方針」の理由）。

## 検証

```bash
bash -n .claude/hooks/post-push-compact-prompt.sh
bash -n .claude/scripts/src/adversarial-review-count.sh
bash -n .claude/scripts/src/sync-gemini-assets.sh

bash .claude/scripts/test/test_adversarial_review_count.sh
bash .claude/scripts/test/test_sync_gemini_assets.sh
bash .claude/scripts/test/test_install_to_project.sh
bash .claude/scripts/src/check-dist-coverage.sh

# 新パスが .gitignore に効いていること（`wip/state/x` が無視される＝出力があること）
mkdir -p wip/state && : > wip/state/.probe && git check-ignore -v wip/state/.probe ; rm -rf wip
```

合格条件:

1. 3つの単体テストがいずれも `failures=0` かつ終了コード0。
2. `check-dist-coverage.sh` が「結果: OK」で終わる（検査2 = `.gitignore` の全行が
   `local` エントリに被覆されていること）。
3. `git check-ignore` が `wip/state/.probe` を `/wip/state/` の行で無視すると報告する。
4. `.sh` `.json` `.gitignore` に残る `.claude/state` が、**動作に関わらない記述だけ**である
   こと（移行用の除外行と、その由来を述べる説明文。動作に使うパスとしての参照は0件）。
5. 旧パスの残骸が `git status` に現れないこと（`git status --short .claude/state` が空）。

## 比較検討した案

| 案 | 利点 | 採否と理由 |
|---|---|---|
| `.gitignore` を `/wip/state/` にする | #165 が `wip/` 配下へ追跡ファイルを置いても衝突しない | **採用** |
| `.gitignore` を `/wip/` にする | 将来 `wip/` 配下に増える一時状態をまとめて無視できる | 却下。#165 が `wip/plans` `wip/worklogs` `wip/reports` を**追跡対象**として置く予定であり、それらが丸ごと無視される |
| 旧パス `/.claude/state/` の除外行を残す | 既存の作業ツリーに残る状態ファイルが `git status` に現れず、誤ってコミットされない | **採用**。コストは `.gitignore` 1行と `dist-layers.json` 1エントリのみで、削除してよい条件をコメントに明示する |
| 旧パスの除外行を残さない | `.gitignore` が短く保てる | 却下。issue #184 より前に作られた状態ファイルが全開発者・全配布先で追跡対象に現れ、変更一覧を機械的にコミットへ渡す運用で巻き込まれる |
| 旧 `.claude/state/` から自動移行するコードを入れる | 既存ローカル状態が引き継がれる | 却下。両ファイルとも「無ければ初回」のフォールバックを持ち、実害は「前回push差分リンクが1回省略される」程度。1回しか効かないコードが恒久的に残るコストのほうが大きい |
