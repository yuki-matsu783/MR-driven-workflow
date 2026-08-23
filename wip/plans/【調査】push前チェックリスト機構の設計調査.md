---
title: 【調査】push前チェックリスト機構の設計調査
type: plan
description: issue #17 のpush前チェックリスト機構を実装するために、置き場所・項目定義・hookの起動条件・誤ブロック条件・ライフサイクルを確定させる個別調査計画。
tags: [issue-mr-flow, hook, push, checklist]
keywords: [調査計画, push前チェックリスト, PreToolUse, PostToolUse, CommandPosition, TSV, 誤ブロック, ライフサイクル, cleanup-task, 単体テスト]
---

# 【調査】push前チェックリスト機構の設計調査

## 前提（合意状況）

- 上位の計画: `wip/plans/steady-guarding-checkpoint.md`（全体作業計画。flow-id 1-4 で作成。
  **flow-id 1-5 の人間の合意は非対話セッションのため得られておらず、敵対的レビューで代替する**）。
- 依拠するissue: #17 と、そのコメント（issue #53 によるコマンド位置判定への変更通知）。

## この計画で何をするか

全体作業計画「フェーズ2〈調査〉」に挙げた **8つの問い**へ答えを出し、フェーズ3の実装が
「設計を決めながら書く」ことにならないようにする。**調査結果はこの計画へ書かず**、
`wip/reports/20260823_steady-guarding-checkpoint_push前チェックリスト機構の設計調査.md` へ記録する。

## 変更対象

調査フェーズのため、成果物は結果ファイルのみである。実装ファイルは触らない。

| ファイル | 操作 | 何をするか |
|---|---|---|
| `wip/reports/20260823_steady-guarding-checkpoint_push前チェックリスト機構の設計調査.md` | 新規 | 調査結果の正文 |
| `wip/reports/20260823_steady-guarding-checkpoint_push前チェックリスト機構の設計調査.html` | 新規 | 上記の人間レビュー用HTMLビュー |
| `wip/worklogs/20260823_steady-guarding-checkpoint_【調査】push前チェックリスト機構の設計調査_push2.md` | 新規 | 試行錯誤ログ |

## 方針

**すべての問いに「リポジトリ内の実物を読んで確かめた根拠」を添える。** 既存hook・既存スクリプト・
既存specの実装を読み、推測で答えない。実行して確かめられるもの（`extract-frontmatter.sh` の走査
対象・`cleanup-task.sh` の削除対象・hookの起動順）は**実際に実行して**確かめる。

問いごとに「答え」「根拠（ファイルパス・行・実行結果）」「採らなかった案と理由」の3点を書く。
**採らなかった案は、フェーズ4でDDRの「却下案」へそのまま移せる粒度で書く。**

## 調査項目（8つの問い）

### Q1. チェックリストの置き場所と命名

- issue本文は `worklog/日付_<全体計画名>_<個別計画名>_push_checklist.tsv` と書くが、issue #165 で
  `worklog/` は `wip/worklogs/` へ改名されている（根拠: `.claude/docs/spec/cleanup-task.md`
  「issue #165」節。`#178` はその squash merge の PR番号）。現行のディレクトリ構成でどこへ置くか。
- push単位でユニークにする命名（`_push<N>`）で、`N` をどこから取るか
  （`HANDOFF.md` の `- push回数:` か、既存ファイルの数え上げか、`usage/state/` か）。
- 全体計画名・個別計画名を機械的に取り出せるか（取り出せない場合の縮退はどうするか）。
- **置き場所を `.mrworkflow.json` の `worklogDir` から解決するか、パスをハードコードするか。**
  設定が無い配布先でのフォールバックは何か。`cleanup-task.sh` は issue #165 で `worklogDir`
  設定値から動的に組み立てる形へ変わっているため、そちらへ揃えられるか（揃えないと、配布先が
  `worklogDir` を変えたときに**チェックリストだけが片付かずに残る**）。
- **ブランチ間でconflictしないこと**（受け入れ条件）を、命名だけで保証できるか。

### Q2. 項目（何をチェックさせるか）の定義

- 固定リストか、flow-idに応じて可変か。
- 「常に実施すべき」と言える粒度は何か（worklogの作成・追記、`HANDOFF.md` の更新、
  `index.jsonl` の最新化、`.gemini/` 変換同期 等の候補から選ぶ）。
- 項目定義をどこに持つか（スクリプト内の定数か、外部の定義ファイルか）。
  **配布先が項目を足せる必要があるか**も併せて判断する。

### Q3. チェック済みの表現とTSVの列構成

- 列は何か（id / 項目 / 状態 / 実施ログ）。状態の値は何か。
- 実施ログをどこまで書かせるか（自由記述か、最低限の形式を課すか）。
- TSVのエスケープ（タブ・改行を含む値）をどう扱うか。
- **`git diff` でレビュアーが読めるか**（受け入れ条件）を、列順と1行の長さで確かめる。

### Q4. PreToolUse hookが読む断面

- 作業ツリー／`git show HEAD:`／index のどれを読むか。
- 「チェックリスト自体をそのcommitに含める」という要件と、pushの直前という実行タイミングの関係。
  **未コミットのチェックリストを見て通すと、pushされる内容と食い違う**のではないか。
- ブランチのHEADに存在しないチェックリストをどう扱うか。
- **どのref（どのブランチ）に対するpushかをコマンドから読み取るか、現在のブランチ固定でよいか。**
  `git push origin HEAD:other`・複数refspec・`git push --all`・タグのみのpushでは、「現在の
  ブランチのHEAD」と実際にpushされる内容が一致しない。読み取れない形はブロック側と素通り側の
  どちらへ倒すか。

### Q5. 誤ブロックしない条件

- チェックリスト未生成のとき（フロー対象外のpush、機構の導入直後、ブランチ初回push）。
  **素通りさせるだけでよいか、それとも「チェックリストが無いまま素通りした」ことを
  （ブロックせずに）通知する縮退を置くか。** 生成済みのチェックリストをコミットし忘れた場合、
  素通りだけだと機構が**無言で無効化**され、しかも「ブロックされないので正常に見える」。
- `git push --dry-run` / `git push --delete` / `git push` 以外のリモート反映手段。
- `CommandPosition.sh` が**部分一致へ縮退する場面**（1行8192バイト超・`eval`/`bash -c` など
  静的に読めない実行体・bash 4.3未満・ライブラリ不在）で、**ブロック側と素通り側のどちらへ
  倒すか**。`block-direct-git-commit.sh` はブロック側へ倒しているが、本hookでも同じでよいか
  （commitと違い、pushは「止まると作業が進まない」度合いが大きい）。
- 前置フィルタ（`raw_hints_at_git_push` 相当）を、判定本体の**超集合**として書けるか。
  既存2本（`post-push-*.sh`）が同型の実装を持つはずなので、それを再利用できるか確かめる。

### Q6. PostToolUse hookの次回分生成と既存hookとの競合

- 既存 `post-push-usage-report.sh` / `post-push-compact-prompt.sh` との**実行順**と、
  `additionalContext` を複数hookが返したときの合成のされ方。
- `if: "Bash(git push*)"` を付けるか、付けずに自前判定するか（既存2本は付けている）。
- **pushが失敗したときにPostToolUseが走るか**。走るなら「push成功後」という要件をどう満たすか。
- 状態ファイル（`wip/state/`）を持つ必要があるか。持たずに済むか。

### Q7. ライフサイクル

- issue本文は flow-id 4-6 での削除を求めるが、現行フローの片付けは flow-id 5-5 の
  `cleanup-task.sh` が担い、`wip/plans/` `wip/worklogs/` `wip/reports/` をまとめて消す。
  **どちらへ寄せるか**（issue本文どおり4-6にすると、4-7以降のpushでチェックリストが無くなる）。
- `cleanup-task.sh` の削除対象・除外対象（`TEMPLATE.md`・`REVIEW-POINTS.md`）の実装を読み、
  チェックリストが**自動的に削除対象へ入るか**を確かめる。
- `.claude/rules/docs-workflow.md` の運用表へ足す行の内容（対象・寿命・内容・運用）。

### Q8. 単体テストの型

- `test_block_direct_git_commit.sh` を読み、(1) 純粋関数の直接テスト、(2) サブプロセス起動＋
  スタブ `jq` による「空振りで外部コマンドが呼ばれないこと」の結合テスト、の2種がどう書かれて
  いるかを確かめ、本機構でどう再利用するか決める。
- 前置フィルタが**超集合であること**を固定するテストをどう書くか
  （`test_sync_gemini_assets.sh` のT11が同型の表明を持つはずなので参照する）。

## やらないこと（スコープ外）

- **実装（スクリプト・hookの作成）**。この計画は答えを出すところまでで、実装は flow-id 3-1 の
  個別作業計画へ送る。
- **git bash（Windows）実機での性能計測**（本セッションはLinux。`.claude/rules/shell-script-style.md`
  の計測手順に従い、必要性の有無だけを記録する）。
- **Gemini CLI経路での実機確認**（`.gemini/` は flow-id 5-3 の変換同期で追随させる）。
- **チェック済み状態の真正性の検証方式**（全体作業計画でスコープ外と決めた）。

## 検証

```bash
# Q1: extract-frontmatter.sh の走査対象が .md だけであること（.tsv が載らないこと）。
# ソースの目視だけでは「拡張子が何であっても1行ヒットする」ため検証にならない。実際に
# ダミーの .tsv を置いて走らせ、index.jsonl に現れないことまで確かめる
touch wip/worklogs/_probe.tsv
bash .claude/scripts/src/extract-frontmatter.sh .
grep -c '_probe\.tsv' wip/worklogs/index.jsonl   # 0 であること
rm -f wip/worklogs/_probe.tsv

# Q6: hookの登録順と if フィルタ
jq '.hooks.PostToolUse' .claude/settings.json

# Q7: cleanup-task.sh の削除対象・除外対象
grep -n "TEMPLATE.md\|REVIEW-POINTS\|collect_files_under" .claude/scripts/src/cleanup-task.sh

# Q8: 既存テストの型
bash .claude/scripts/test/test_block_direct_git_commit.sh
```

合格条件: 8つの問いすべてに「答え」「根拠」「採らなかった案と理由」が揃い、
flow-id 3-1 の個別作業計画が**設計判断を持ち越さずに**書ける状態になること。
