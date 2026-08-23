---
title: 作業結果 — stateの保存先をwip/stateへ移した
type: report
description: ローカル作業状態の保存先を .claude/state/ から wip/state/ へ移した作業の結果と検証記録
tags: [report, workflow, distribution]
keywords: [wip, state, gitignore, dist-layers, check-dist-coverage, sync-gemini-assets, adversarial-review-count, 検証, issue184]
---

# 作業結果 — stateの保存先を `wip/state` へ移した

- issue: #184 / PR: #190
- 全体作業計画: `plans/wispy-drifting-lantern.md`
- 個別作業計画: `plans/【実装】【テスト】stateの保存先をwip-stateへ移す.md`
- フェーズ3〈作業〉 flow-id 3-6 / push2 / 2026-08-23

## サマリ（結論の一覧）

| # | やったこと | 結論 | 根拠の性質 |
|---|---|---|---|
| 1 | 保存先パスを `.claude/state/` → `wip/state/` へ変更 | 実装5ファイル・テスト3ファイルの計8ファイルで完了 | 実装の確認 |
| 2 | `.gitignore` のパターンを差し替え | `git check-ignore -v` が `wip/state/.probe` を `/wip/state/` の行で無視すると報告 | 実測 |
| 3 | 層分け定義（`dist-layers.json`）の追従 | `check-dist-coverage.sh` が「結果: OK（4種すべて通過）」 | 実測 |
| 4 | 既存の単体テスト3本 | いずれも `failures=0`（22 / 91 / 99 件） | 実測 |
| 5 | 旧パスからの自動移行コード | **入れない**と決めた（両ファイルとも「無ければ初回」のフォールバックを持つ） | 実装の確認 |
| 6 | 旧パス `/.claude/state/` の除外行 | **残した**（移行用の名残）。差し替えるだけだと既存の残骸が `git status` に現れる | 実測 |
| 7 | `.sh` `.json` `.gitignore` からの旧パス除去 | 動作に使うパスとしての参照は0件（残るのは移行用の除外行と由来の説明のみ） | 実測 |

## 実施条件

- 実行環境: Claude Code on the web のリモート実行環境（Linux）。**git bash（Windows）実機での
  確認は行っていない**（下記「確かめられなかったこと」）。
- 実行日: 2026-08-23
- ベース: `origin/main` = `4be448a`（`behind 0` / `ahead 0` を確認して着手）

## 実施した内容と結果

### 1. 保存先パスの変更（実装）

| ファイル | 変更 |
|---|---|
| `.gitignore` | `/.claude/state/` → `/wip/state/`。コメントを「内訳（review-links と adversarial-review の2つ）」「issue #184 で移した理由」「**パターンを `/wip/` へ広げないこと**」まで書く形へ改めた |
| `.claude/dist-layers.json` | `local` の `gitignorePattern` を `/wip/state/` へ。`note` も「前回push時点のHEAD SHA」から「ワークフローのローカル作業状態（前回push時点のHEAD SHA・敵対的レビューの投稿件数）」へ改めた |
| `.claude/hooks/post-push-compact-prompt.sh` | `state_file` の組み立てと冒頭コメント（計2箇所） |
| `.claude/scripts/src/adversarial-review-count.sh` | `adversarial_review_state_path` と冒頭コメント（計2箇所） |
| `.claude/scripts/src/sync-gemini-assets.sh` | 列挙の説明コメント。除外対象の例示を `.claude/state/` から `.claude/settings.local.json` へ差し替え、「ローカル作業状態は `wip/state/` へ移したため、そもそも `-- .claude` の列挙範囲に入らない」を明記 |

**`dist-layers.json` の `note` は、パスを直すついでに実態へ合わせた。** 元の
「前回push時点のHEAD SHA」は `post-push-compact-prompt.sh` の分しか指しておらず、
`adversarial-review-count.sh` が同じディレクトリへ書く投稿件数が漏れていた。

### 2. 旧パス `/.claude/state/` の除外行を残した（作業中に判明）

**計画時点では見落としていた。** パターンを `/wip/state/` へ差し替えた直後、`git status` に
`?? .claude/state/` が現れた。このセッションのpush1でhookが旧パスへ書いた状態ファイルが、
`.gitignore` の対象から外れたためである。

同じことは**既存の全開発者・全配布先で起きる**。issue #184 より前に作られた状態ファイルは
どの作業ツリーにも残っており、変更一覧を機械的にコミットへ渡す運用
（`.claude/rules/git-workflow.md`「コミット運用」）では巻き込まれる。

対処として、旧パスの除外行を**移行用の名残**として残し、`dist-layers.json` にも対応する
`local` エントリを足した（足さないと `check-dist-coverage.sh` の検査2が落ちる）。
`.gitignore` のコメントに「手元の `.claude/state/` を消したあとであれば、この行は削除してよい」
と削除条件を明示している。

### 3. `.gitignore` のパターンを `/wip/` へ広げなかった

`/wip/` にすると `wip/` 配下すべてが無視される。**#165 は `wip/plans` `wip/worklogs`
`wip/reports` を追跡対象として同じ親へ置く予定**であり、それらが丸ごと無視されて
「コミットしたはずのものが入らない」という最も気づきにくい壊れ方をする。
`.gitignore` のコメントにもこの禁止事項を残した。

### 4. テストの追従

| ファイル | 変更 | 結果 |
|---|---|---|
| `test_adversarial_review_count.sh` | 期待パス3件を `wip/state/adversarial-review/…` へ | `passed=22 failures=0` |
| `test_sync_gemini_assets.sh` | 除外確認のフィクスチャを `.claude/state/last-push-sha` から `.claude/settings.local.json` へ差し替え | `passed=91 failures=0` |
| `test_install_to_project.sh` | 「`local` は作られない」の確認対象を `wip/state` へ | `passed=99 failures=0` |

**`test_sync_gemini_assets.sh` のフィクスチャ差し替えには理由がある。** このT8は
「`.gitignore` 対象のファイルが `.gemini/` へ出ないこと」を確かめるテストである。
`sync-gemini-assets.sh` の列挙は `git ls-files … -- .claude` に限られるため、
`wip/state/` を新しいフィクスチャにすると**`.gitignore` の効果と無関係に列挙対象外**になり、
テストが**常に成功する空振り**へ変わってしまう。`.claude/` 配下に残る `.gitignore` 対象の
実在パス（`/.claude/settings.local.json`）を使うことで、検証したい性質を保った。

### 5. 検証（実行したコマンドと結果）

```
bash -n .claude/hooks/post-push-compact-prompt.sh          → 構文OK
bash -n .claude/scripts/src/adversarial-review-count.sh    → 構文OK
bash -n .claude/scripts/src/sync-gemini-assets.sh          → 構文OK

bash .claude/scripts/test/test_adversarial_review_count.sh → passed=22 failures=0
bash .claude/scripts/test/test_sync_gemini_assets.sh       → passed=91 failures=0
bash .claude/scripts/test/test_install_to_project.sh       → passed=99 failures=0

bash .claude/scripts/src/check-dist-coverage.sh
  検査1 追跡ファイルの分類: 445 / 445 件
  検査2 .gitignore の行の被覆: 10 / 10 行
  検査3 空振りエントリ: 0 件（うち pathspec として不正 0 件）
  検査4 layer / strategy の妥当性: 不正 0 件
  結果: OK（4種すべて通過）

mkdir -p wip/state && : > wip/state/.probe && git check-ignore -v wip/state/.probe
  → .gitignore:26:/wip/state/    wip/state/.probe
```

`grep -rn '\.claude/state' --include='*.sh' --include='*.json' --include='.gitignore' .`
（`.gemini/` を除く）の残存は、**移行用の除外行（`.gitignore` と `dist-layers.json` の各1件）と、
その由来を述べる説明文のみ**。動作に使うパスとしての参照は0件。
`git status --short .claude/state` も空（旧パスの残骸が追跡対象に現れない）。

## 確かめられなかったこと

- **git bash（Windows）実機での動作。** この実行環境はLinuxである。ただし今回の変更は
  文字列としてのパスの差し替えだけで、パス変換・改行コード・外部プロセス起動の
  いずれにも触れていないため、環境差が結果を変える経路は無いと考えている。
- **hookの実挙動（`post-push-compact-prompt.sh` が新パスへ状態を書くこと）。**
  このセッションのpushでhookは実際に発火しており、参照リンクの供給も動いているが、
  `wip/state/review-links/` が `.gitignore` 対象のためファイルの中身は成果物に残らない。
  構文チェックと、パスを組み立てている行の目視でのみ確認している。
- **旧 `.claude/state/` に既存の状態ファイルを持つ環境で、状態が引き継がれないことの実害。**
  この作業ツリーにも push1 のhookが書いた `.claude/state/review-links/` が残っているが、
  移行が要らないという判断はコードの読解（両ファイルとも「無ければ初回」のフォールバックを
  持つ）に依っており、「引き継がれなくても実害が無い」ことを実行して確かめてはいない。

## 設計への反映（フェーズ4の候補）

| 反映先 | 反映する内容 |
|---|---|
| `.claude/rules/directory-structure.md` | ツリー直後の注記（80行目）と `.claude/state/` の説明段落（119〜122行目） |
| `.claude/docs/spec/issue-mr-workflow.md` | 「/compact実施の呼びかけ」節（現在の仕様）＋ changelog への**新規エントリ追記**。**2299〜2300行目の過去changelogは触らない** |
| `.claude/docs/spec/adversarial-review.md` | 状態ファイルのパス（100〜101行目） |
| `.claude/docs/spec/sync-gemini-assets.md` | 除外対象の説明（67行目） |
| `.claude/docs/ddr/i0184-01-….md` | 移動先を `wip/state/` にした判断と却下案（`.claude/wip/` 案・`usage/state/` への統合案・`/wip/` で無視する案） |
| `.claude/docs/README.md` | `generate-ddr-list.sh` によるDDR一覧の再生成 |
| `.claude/docs/usecase/` | 影響の有無を確認する |

既存DDR `i0013-01` `i0039-01` は**旧パス表記のまま残す**（本文は変更しない）。

## 想定と異なった点

- **issue #184 の本文が空だった。** `mcp__github__issue_read` の `get` は `body` を返さず、
  `search_issues` / `list_issues` に `fields: ["body"]` を付けても `null` だった。同じ手順で
  issue #165 の本文は取得できたため、MCPの制限ではなく本文が実際に空だと判断し、
  `AskUserQuestion` で方針を確認したうえで着手した。
- **旧パスの除外行を消すと、既存の残骸が `git status` に現れる。** 計画では「パターンを
  差し替える」としか書いておらず、差し替えた直後に `?? .claude/state/` が出て初めて気づいた。
  ローカル状態のパスを変える作業では、**新しいパスを ignore するだけでなく、古いパスの
  ignore を残すかどうかを必ず判断する**必要がある。
- **`dist-layers.json` に `.claude/state` の `path` エントリは無かった。** issueのコメントは
  「`path` と `gitignorePattern` の2箇所」と述べていたが、実際にあったのは
  `gitignorePattern` の1箇所だけだった。`.claude/state` は追跡ファイルを1件も持たないため、
  検査1・検査3（いずれも追跡ファイルが分母）には現れず、`path` エントリを置く必要が無い。
  結果として、直す箇所はコメントの見立てより1つ少なかった。

## 残課題

- **フェーズ4〈反映〉**: 上表のドキュメント更新とDDRの新規作成。
- **flow-id 5-3**: `.gemini/` の変換同期（`.claude/` 側を変更したため）。
