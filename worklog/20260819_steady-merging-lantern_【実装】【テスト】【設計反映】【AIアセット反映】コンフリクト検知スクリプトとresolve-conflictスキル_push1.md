---
title: worklog issue #46 コンフリクト検知スクリプトとresolve-conflictスキル
type: log
description: issue #46（defaultブランチとのコンフリクト検知・解消フロー整備）の実装ログ
tags: [worklog, conflict, issue-46]
keywords: [check-base-conflicts, merge-tree, DDR番号, resolve-conflict, flow-id-5-2, semantic conflict]
---

# worklog: 【実装】【テスト】【設計反映】【AIアセット反映】コンフリクト検知スクリプトとresolve-conflictスキル

対象: issue #46 マージ依頼前にdefaultブランチとのコンフリクトを検知・解消するフローを整備する（2026-08-19）。
全体作業計画: `plans/steady-merging-lantern.md`
個別作業計画: `plans/【実装】【テスト】【設計反映】【AIアセット反映】コンフリクト検知スクリプトとresolve-conflictスキル.md`
push回数: 1

## 試したこと

### 過去の発生実績の棚卸し

`git log --merges` と `git log --grep='コンフリクト\|改番\|マージ'` で過去の解消コミットを洗った。
issueには2件（PR #29, #37）と書かれていたが、実際は**4件**あった。

| コミット | PR | issue | メッセージ |
|---|---|---|---|
| c2bb66f | #29 | #13 | `docs: PR #29作成・main合流によるDDR番号衝突解消をHANDOFFへ記録` |
| 60065ed | #37 | #36 | `chore: mainをマージしDDR番号を0026へ繰り下げてindex.jsonl生成物化との競合を解消` |
| e1bd892 | #49 | #48 | `chore: mainをマージしDDR番号を0027へ繰り下げてissue #48の変更と統合` |
| 90355b0 | #52 | #45 | `chore: mainをマージしDDR番号を0028へ繰り下げてissue #45の変更と統合` |

**4件すべてでDDR番号が衝突している**。解消方向もすべて「作業ブランチ側を繰り下げる」で一致していた。
取り込み方法もすべて `git merge`（rebaseは1件も無い）。

### DDR番号衝突をgitが検知できないことの確認

PR #52の両親コミットに対して直接 `merge-tree` を実行した。

```
$ git merge-tree --write-tree --name-only --no-messages 20289b0 47b1d93
exit=1
10b8be83652d109d168a23c927f75a3fa1e6d9f2
.claude/docs/README.md
tests/test_vcs_provider.sh
```

両ツリーのDDR一覧を見ると、branch側に `0027-プロバイダ判定は…`、main側に
`0027-gh_glab-CLI不在時は…` があり、**両方とも0027なのにコンフリクト一覧に出てこない**。
ファイル名が異なるため、gitにとっては「それぞれ別のファイルが追加された」だけである。

→ 「`git merge` を試して出るか見る」という素朴な検知手順では、このリポジトリで最も頻発する
衝突を100%取りこぼす。これが本issueの中心的な発見であり、検知スクリプトを作る根拠になった。

### 実装した検知スクリプトでの再現

`.claude/scripts/src/check-base-conflicts.sh` を実装し、過去2件の断面で再現確認した。

PR #52（head=20289b0, base=47b1d93）:
```json
{"hasConflict":true,"hasTextualConflict":true,"hasDuplicateDdrNumber":true,
 "textualConflictFiles":[".claude/docs/README.md","tests/test_vcs_provider.sh"],
 "duplicateDdrNumbers":["0027"]}
```

PR #37（head=da9809c, base=366695c）:
```json
{"hasTextualConflict":true,
 "textualConflictFiles":[".claude/docs/README.md",".claude/docs/ddr/index.jsonl",
   ".claude/docs/index.jsonl",".claude/docs/spec/index.jsonl",".claude/rules/docs-workflow.md",
   ".claude/rules/index.jsonl",".claude/skills/issue-mr-flow/index.jsonl","HANDOFF.md","index.jsonl"],
 "dups":["0024"]}
```

issueの記述（「index.jsonlをGit管理から外す変更をしたブランチが…deleted by us形式のコンフリクトが
複数発生」「docs-workflow.mdなど複数ファイルで両ブランチの変更を人手で統合」）と完全に一致した。

検証には `git update-ref refs/remotes/origin/cbc-test-base <sha>` で一時的なリモート追跡refを
作る方法を使った（作業ツリーを一切触らずに任意の断面を再現できる）。

## うまくいったこと

- **`git merge-tree --write-tree` による非破壊の検知**。`git merge` → `git merge --abort` 方式と
  違い、インデックス・作業ツリーに一切触れないため、途中で中断されてもリポジトリが壊れた状態に
  残らない。git 2.38以降が必要（実機は 2.43.0）。
- **DDR番号の重複判定を、テキストコンフリクトとは独立した第2の検知として持たせた**こと。
  過去4件すべてを検知できる。
- **終了コードでコンフリクトの有無を表さず、JSONの `hasConflict` で返す設計**。呼び出し元は
  `set -euo pipefail` 配下のスキル手順・テストであり、「コンフリクトがある」という正常な結果で
  スクリプト全体が停止するのを避けられる。
- 純粋関数（`ddr_number_to_reply` / `find_duplicate_ddr_numbers`）を分離し、
  `tests/test_check_base_conflicts.sh` で13件の単体テストにした。既存4テストも含め全件パス
  （`passed=13/17/15/33/36 failures=0`）。
- 解消手順を類型A〜Eに分解できた。過去4件は A（4件）・B（1件）・C（複数件）の組み合わせで
  説明でき、その場の判断が必要なのはD・Eだけに絞れた。

## ダメだったこと

- **`if ! cmd; then merge_status=$?; fi` で終了コードを取り違えた。** bashは `!` で反転済みの値を
  返すため、`merge-tree` の「1＝コンフリクト有り」が `$?` では0として読まれ、**検知が常に
  「テキストコンフリクト無し」になった**。PR #52の断面で `hasTextualConflict: false` が返って
  初めて気づいた（DDR番号の重複だけは正しく検知できていたため、一見それらしい結果に見えたのが
  たちが悪い）。`cmd || status=$?` の形へ修正。この知見は
  `.claude/docs/spec/check-base-conflicts.md`「実装上の注意」へ残した。
- **JSON組み立ての区切りに制御文字（`\x1e`）を使おうとして、Bashツールに拒否された**
  （「command contains control characters that would be hidden in the approval dialog」）。
  承認ダイアログで目視できない文字は使えない。`@@CBC-SPLIT@@` という通常の文字列へ変更した。
- **コミットブロックhookとpush検知hookの誤発火を両方踏んだ。** `resolve-conflict/SKILL.md` の
  heredoc本文に「gitのコミットコマンド」を説明する語句と `git push -u origin` の例が含まれており、
  `.claude/rules/git-workflow.md` に記録済みの既知の誤検知がそのまま再現した。前者は文面を
  言い換えて回避（ルールに書かれているとおりの対処）、後者は無害なため通した。
  **ルールを読んで知っていても、実際に長いドキュメントを書くときには防げなかった**点が示唆的で、
  スキル定義のように「gitの操作そのものを説明する文書」を書く場面では特に踏みやすい。
- `find_duplicate_ddr_numbers` の初版が、同じパスが2度渡された場合を重複と誤判定しうる実装
  だった（`main` 側で `sort -u` しているため実害は無かったが）。タブ区切りの完全一致による
  重複除去を入れ、テストケースも足した。

## 次の一歩

- 特になし（実装・テスト・設計反映・AIアセット反映まで完了）。
- 非対話的実行環境のため、人間のレビュー往復（flow-id 3-3/3-4, 3-8/3-9, 4-3/4-4, 4-8/4-9）と
  MR descriptionの更新（`describe`）は未実施。進捗記号は `[]` のままにしてある
  （`.claude/rules/docs-workflow.md` の非対話的実行環境の方針どおり）。
- flow-id 5-1（plans/worklogの削除・HANDOFF.mdのリセット）と 5-2（新設したコンフリクト検知）は、
  レビュー後に実施する。**新設した検知ステップを、このブランチ自身で最初に通すことになる。**
