---
title: フェーズ5のステップ順の並べ替え 実施結果
type: report
description: issue #112 の実施結果。フェーズ5を 5-1コンフリクト解消 / 5-2関連issue通知 / 5-3片付け / 5-4commit へ並べ替えた範囲、書き換えなかった過去の記録の線引き、受け入れ条件との対応、検証結果。
tags: [report, workflow, phase5, issue-mr-flow]
keywords: [flow-id, 並べ替え, SKILL.md, DDR0057, cleanup-task, check-base-conflicts, HANDOFF, 除外, 受け入れ条件, 単体テスト]
---

# 実施結果: フェーズ5のステップ順の並べ替え（issue #112）

全体作業計画: `plans/tidy-closing-cascade.md`
個別計画: `plans/【実装】フェーズ5のステップ順の並べ替え.md` /
`plans/【設計反映】フェーズ5並べ替えのspec・DDRへの反映.md`

## 結論

フェーズ5を次の順序へ並べ替えた。**ステップの内容・総数（41）は変えていない。**
5-4（commit・push・Draft解除）・5-5（マージ）は番号・内容とも変更なし。

| 新flow-id | 内容 | 旧flow-id |
|---|---|---|
| 5-1 | defaultブランチとのコンフリクトを検知し、あれば解消する | 5-2 |
| 5-2 | 今回のMRが影響する関連issueを特定し、承認を得てから通知する | 5-3 |
| 5-3 | `plans/` `worklog/` `reports/` を削除し `HANDOFF.md` をリセットする | 5-1 |
| 5-4 | commit・push して Draft を解除する | 5-4 |

## 調査で分かったこと

1. **動くのは 5-1〜5-3 の3ステップだけ**である。5-4・5-5 の番号が変わらないため、
   `commit` スキルの `2-2/2-7/…/5-4` の列挙、`git-workflow.md` の担当表のDraft解除・マージ行、
   `Provider.sh` の `set_mr_ready` 周辺は**触る必要が無い**。
2. **`update-handoff-progress.sh` の `LOOP_RANGES` はフェーズ2〜4の6範囲のみ**で、フェーズ5を
   含まない。並べ替えでロジック・テーブルを変える必要はなく、コメント2箇所の修正で足りた
   （受け入れ条件「flow-id・ループ範囲のテーブルが新しい順序と整合している」への回答）。
3. **`HANDOFF.md` のフロー進捗表には独立したテンプレートファイルが存在しない。**
   全ステップを列挙した表はリポジトリ内で `.claude/skills/issue-mr-flow/SKILL.md` の全体フロー表
   だけ（`grep -rln "4-10"` の結果が同ファイル1件）で、`cleanup-task.sh` が持つ `HANDOFF.md` の
   テンプレートは `## フロー進捗状況` の見出しと「（次タスク着手時に記入する）」のみを持つ。
   したがって進捗表側の整合は、SKILL.md の全体フロー表の更新で満たされる。
4. **`.claude/docs/spec/adversarial-review.md` に flow-id 5-x の参照は0件**（issue #112 の
   コメントの報告どおり）。受け入れ条件が挙げている同ファイルは実質的に対象外である。
5. `.claude/scripts/test/test_update_handoff_progress.sh` のフィクスチャに現れる `5-1` は、
   行を識別するための値でしかない（ステップ名も「単発ステップ」「スキップ対象」という汎用の
   ダミー）。フィクスチャ自体は変更せず、その旨をコメントで明示した。

## 変更したもの

| 区分 | ファイル |
|---|---|
| フロー定義 | `.claude/skills/issue-mr-flow/SKILL.md`（全体フロー表の並べ替え、フェーズ一覧の語順、フェーズ5の3節の見出しと本文、監視節の最終ゲート表、`AskUserQuestion` 例外の列挙） |
| ルール | `.claude/rules/docs-workflow.md` / `directory-structure.md` / `markdown-frontmatter.md` / `git-workflow.md` |
| スキル・目次 | `.claude/skills/resolve-conflict/SKILL.md` / `canvas-report/SKILL.md` / `doc-search/SKILL.md` / `index.md` / `.claude/docs/README.md` |
| スクリプト（コメントのみ） | `cleanup-task.sh` / `check-base-conflicts.sh` / `update-handoff-progress.sh` / `vcs/Provider.sh` / `vcs/Github.sh` / `vcs/Gitlab.sh` |
| テスト | `.claude/scripts/test/test_update_handoff_progress.sh`（コメントのみ） |
| spec | `issue-mr-workflow.md` / `cleanup-task.md` / `check-base-conflicts.md` / `create-commit.md` / `extract-frontmatter.md` / `update-handoff-progress.md` |
| DDR（新規） | `0057-フェーズ5は片付けをcommit直前へ移した順序に並べ替える.md` |

**スクリプトのロジックは1行も変えていない**（変更はすべてコメント）。

### 関連issue通知（新5-2）への追記

新順序では `plans/` `worklog/` `reports/` がまだ削除されていないため、キーワード抽出の差分から
これらを除外する旨を手順へ明記した。

```bash
git diff --stat "origin/${base}...HEAD" -- . ':(exclude)plans' ':(exclude)worklog' ':(exclude)reports'
```

このpathspecは実機で動作を確認した（除外あり16ファイル / 除外なし19ファイル）。

## 書き換えなかったもの（意図的）

- **DDR本文**（0044・0048 ほか）。`.claude/rules/docs-workflow.md`「本文は追記のみ」に従う。
  DDR 0048 はファイル名にも `flow-id5-1` を含むが、リンク切れを避けるためリネームしていない。
  現在の番号との対応は DDR 0057 と `.claude/docs/spec/cleanup-task.md`「背景・目的」、
  `.claude/docs/README.md` のDDR一覧の注記で示した。
- **spec の `## 影響範囲` 配下の過去issueごとのエントリ**（point-in-timeの記録）。今回分は
  末尾へ `### issue #112` として**追記**した。
- `.claude/scripts/src/vcs/Provider.sh` の「当時の flow-id 5-3」のように、明示的に当時の番号だと
  書かれている記述。
- `.claude/docs/spec/cleanup-task.md` の「過去に手作業で実施した flow-id 5-1（コミット `6dd6627`）」
  （特定のコミットを指す過去の記録のため）。

## 受け入れ条件との対応

| 受け入れ条件 | 対応 |
|---|---|
| SKILL.md の全体フロー表と各節の flow-id 参照 | 済（表の並べ替え＋3節の見出し・本文・監視節・例外列挙） |
| `HANDOFF.md` の進捗表テンプレートと `update-handoff-progress.sh` のテーブル | 済（進捗表の実体はSKILL.mdの全体フロー表のみ。`LOOP_RANGES` はフェーズ5を含まないため変更不要であることを確認し、コメントと単体テストの注記を更新） |
| `docs-workflow.md` / `directory-structure.md` / `cleanup-task.md` / `adversarial-review.md` 等 | 済（`adversarial-review.md` は参照0件のため変更なし。他は上表のとおり） |
| 差分から `plans/` `worklog/` `reports/` を除外する旨 | 済（新5-2の手順1・2、フロー表の5-2行） |
| 並べ替えの理由と却下案のDDR | 済（DDR 0057。却下案4件を記録） |
| issue #108 との関係の整理 | 済（DDR 0057 に専用の節。#112 が先に入るのが望ましい理由と、#108 側が使うべき番号） |

## 検証結果

```
bash -n <変更した6スクリプト>                        すべてOK
.claude/scripts/test/ の11本                          passed=541 failures=0（内訳は下記）
```

| テスト | 結果 |
|---|---|
| test_adversarial_review_count.sh | passed=22 failures=0 |
| test_check_base_conflicts.sh | passed=13 failures=0 |
| test_cleanup_task.sh | passed=37 failures=0 |
| test_collect_review_points.sh | passed=17 failures=0 |
| test_extract_frontmatter.sh | passed=23 failures=0 |
| test_post_issue_create_notice.sh | passed=14 failures=0 |
| test_search_frontmatter.sh | passed=114 failures=0 |
| test_session_start.sh | passed=35 failures=0 |
| test_update_handoff_progress.sh | passed=45 failures=0 |
| test_usage_tracking.sh | passed=90 failures=0 |
| test_vcs_provider.sh | passed=131 failures=0 |

旧番号の残存確認は `grep -rn "flow-id 5-"` を全ファイルへ実行し、ヒットした行を1件ずつ
「現在の状態の記述（更新済み）」「過去の記録（意図的に据え置き）」へ仕分けて確認した。
