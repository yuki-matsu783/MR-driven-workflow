---
title: worklog 20260819 ベースブランチ追従確認（敵対的レビュー指摘の反映）
type: log
description: issue #67 のフェーズ3・フェーズ4の敵対的レビューで挙がった指摘への対応記録。rebase選択肢の削除、作業ツリー汚れの扱い、結合テストの追加など。
tags: [worklog, issue-mr-flow, adversarial-review, base-branch]
keywords: [worklog, 敵対的レビュー, rebase, 作業ツリー, 結合テスト, merge-base, isShallow, 重複実行, frontmatter]
---

# worklog: 敵対的レビュー指摘の反映（フェーズ3・フェーズ4）

対象: issue #67（2026-08-19）。
全体作業計画: `plans/base-branch-sync-check.md`
push回数: 5

フェーズ3（実装）で11件、フェーズ4（spec/DDR/rules）で8件の指摘が返った。
投稿の振り分けは `.claude/skills/adversarial-review/SKILL.md` の「確度 × 重大度」マトリクスに従い、
フェーズ3で5件、フェーズ4で5件をPR #107 へインライン投稿した。

## 試したこと・直したこと

| 指摘 | 重大度 | 対応 |
|---|---|---|
| `AskUserQuestion` の選択肢に `rebase で取り込む` が残っている | major/high | 選択肢から削除し2択にした。理由は地の文の注記へ。DDR 0050 の該当節も「選択肢として出さない理由」へ書き換えた |
| 作業ツリーが汚れている場合の扱いが無い | major/medium | 手順5を新設。`git status --porcelain` が空でなければ取り込まない。**`git stash` を独断で実行しない**を明記 |
| `resume` 1回で検知が3回走る | minor/high | 「実施タイミング」へ重複実行の注意を追加。`resume` 手順4・5を「再実行しない」と書き換え |
| `resume` 手順2の項目列挙が未更新 | minor/high | 列挙をやめ、`issue-mr-resume.md` の報告フォーマットを正とする参照へ置き換えた |
| `check-base-sync.sh` が資産一覧に無い | minor/high | `apply-mr-workflow-to-project/SKILL.md` へ1行追加 |
| `--base` に値が無いと `$2: unbound variable` | minor/high | `[ $# -ge 2 ] && [ -n "$2" ]` で検証（`$#` を先に見るのが要点。`$2` を直接書くと検証自体が同じエラーで落ちる） |
| 非0終了時にサブエージェントが何を報告するか未定義 | minor/medium | 「判定できなかった（stderrの1行目）」として報告し、**追従済みとは書かない**を明記 |
| `hasCommonHistory: false` は `isBehind: true` 側で表面化する | minor/medium | 手順2を新設し、取り込みを提案せず止まる。`--allow-unrelated-histories` を使わないことも明記 |
| `isShallow: true` はweb環境で常に真で警告が意味を失う | minor/medium | 単体では警告条件にしない、と SKILL.md・spec・エージェント定義の3箇所をそろえた |
| `main` の結合テストが1件も無い | minor/medium | 使い捨てgitリポジトリに対する結合テスト26件を追加（29→55件） |
| spec の「途中引き継ぎ対応（resume）」節が未更新 | major/high | 手順一覧へ追加し番号を繰り下げ。「1〜6をまとめ」も実態へ |
| spec と SKILL.md で同じ表を再掲し `isShallow` の指示が食い違う | minor/high | 対比表は SKILL.md へ寄せ、3キー表は「意味＝spec／対応＝SKILL」と分担を明記 |
| 非0終了の具体例が仕様に無い | minor/high | 「終了コード」節へ代表ケースの表を追加（`--head` は未検証で128になることも明記） |
| `git-workflow.md` の frontmatter が未更新 | minor/high | `description`・`keywords` へ `ベースブランチ` `追従確認` `rebase` `check-base-sync` を追加 |
| `check-base-conflicts.md` から本スクリプトが辿れない | minor/high | 相互参照エントリを追加。`\|\| true` が意図的であることも書いた |
| spec の影響範囲表が2ファイル落としている | minor/medium | 実際の変更ファイルへそろえた |
| DDR の却下案が同じ軸の2案のみ | minor/low | 案C（スクリプトを作らず手順書へ直書き）を追加 |

## うまくいったこと

- **同じ欠陥がフェーズ3とフェーズ4で独立に挙がった**（rebase選択肢の矛盾）。片方はSKILL.md側から、
  もう片方は `alwaysApply: true` のルール側から見ており、**独立コンテキストのレビューが2回とも
  同じ結論に達した**ことで、修正の判断に迷いが無くなった。
- 結合テストの追加で、コメントが「ここを分けないと落ちる」と書いていた merge-base 不在の分岐が
  実際に守られるようになった。orphanブランチのケースは実測でも `behind=2 / changedFiles=0` になり、
  「取り込みを提案してはいけない」根拠がテストとして残った。

## ダメだったこと

- **テスト用ヘルパーの `mkdir -p "$dir/${f%/*}"` が、スラッシュを含まないファイル名のときに
  ファイル名そのもののディレクトリを作っていた**（`README.md/` が出来て `Is a directory` で失敗）。
  `${f%/*}` はパターンが一致しないと文字列全体を返す。`[[ "$f" == */* ]]` で分岐して解決。
- 敵対的レビューの指摘のうち1件は根拠が事実と違った（「同じブランチで `search-frontmatter.sh` の
  行が追加されている」→ 実際は `main` 由来）。**指摘の結論が正しくても根拠は検証する**必要がある。
  PRのレビュー本文にもその旨を書いた。

## 次の一歩

- flow-id 5-1: `cleanup-task.sh` で `plans/` `worklog/` `reports/` を片付ける。
- flow-id 5-2〜5-4: コンフリクト検知 → 関連issue通知（承認必須）→ Draft解除。

---
