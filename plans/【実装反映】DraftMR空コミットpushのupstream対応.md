---
title: 【実装反映】DraftMR空コミットpushのupstream対応
type: plan
description: issue #170フェーズ4の個別反映計画（実装反映）。Provider.shのadd_empty_commit_for_draft_mrがupstream未設定ブランチでpushに失敗する不具合の修正と、specへの書き戻し
tags: [usecase-docs, plan, impl-reflect]
keywords: [実装反映, Provider.sh, add_empty_commit_for_draft_mr, upstream, git push, Draft PR, 空コミット, 自動リトライ]
---

# 【実装反映】DraftMR空コミットpushのupstream対応

- issue: #170 / PR: #173
- 全体作業計画: `plans/usecase-atlas.md`
- 作成日: 2026-08-23

## 前提（合意状況）

- 依拠する事実: flow-id 1-3 で実際に発生した不具合（worklog push1「ダメだったこと」）。
  `add_empty_commit_for_draft_mr`（`.claude/scripts/src/vcs/Provider.sh` 1134〜1137行目、
  2026-08-23時点）が引数なしの `git push` を呼んでおり、**upstream未設定の新規ブランチ**
  （リモート実行環境の `new_issue_branch` を経ないブランチ等）では終了コード128で失敗する。
- 上位の全体作業計画は flow-id 1-5 未合意のまま先行中。フェーズ3のレビューループ内では扱わないと
  計画に明記して持ち越した（`【実装反映】` の定義どおり）。

## 反映対象（洗い出しの結果）

1. **実装修正**: `add_empty_commit_for_draft_mr` の `git push` を
   `git push -u origin HEAD` へ変更する（全体作業計画の反映候補どおり）。upstreamの有無に
   依存せず、コマンド置換のforkを増やさない（`.claude/rules/shell-script-style.md`
   「外部プロセス起動のコスト」）。`git push -u origin "$(git branch --show-current)"` とする
   案は、forkが1回増えるうえ detached HEAD で空文字列になり別のエラーで落ちるため採らない。
   なお `-u` はupstreamを `origin/<同名ブランチ>` へ上書きするため、別リモート・別名への
   upstreamは書き換わるが、このリポジトリのブランチ作成（`new_issue_branch`）は
   `git push -u origin "$branch"` であり整合する。
2. **単体テストの追加**: `test_vcs_provider.sh` の既存スタブ方式（`glab()` をシェル関数で
   差し替える形）に倣い、`git()` をスタブして `add_empty_commit_for_draft_mr` が `push` へ
   渡す引数に `-u origin HEAD` が含まれることを表明するテストを追加する。
3. **specへの書き戻し**: `.claude/docs/spec/issue-mr-workflow.md`「Draft PR作成失敗時の
   自動リトライ」節へ、upstream未設定でも動くこと（issue #170で実不具合として検出・修正）を
   追記する（過去のchangelogは書き換えない。現在の仕様の節のみ）。
4. **別issue起票はしない**: 1関数1行の修正で、このissueのフロー内（flow-id 1-3）で実際に
   踏んだ不具合のため、`【実装反映】` の範囲で完結する。

## やらないこと（スコープ外）

- `.gemini/` 配下の同名ファイルの手動更新（生成物。flow-id 5-3 の `sync-gemini-assets.sh` が
  変換同期する）。
- `new_draft_merge_request` 側のリトライ構造の変更（不具合はpushのupstream指定のみ）。

## 検証（実行できるコマンドと合格条件）

```bash
# 2の3行は grep -c が0件のとき終了コード1を返すため、set -e 配下でまとめて流す場合は
# `|| true` を付ける（ここでは個別実行を前提に素の形で書く）
# 1. 構文（終了コード0で合格）
bash -n .claude/scripts/src/vcs/Provider.sh
# 2. 当該関数の抽出が空でない・引数なしの `git push` が残っていない・修正が入っている
#    （順に 4程度/0/1 で合格。実施前の実測は 4/1/0。1つ目が0なら関数名変更・sedパターンずれ
#    による抽出失敗で、2つ目の「0で合格」は空振りのため信用しない）
body="$(sed -n '/^add_empty_commit_for_draft_mr()/,/^}/p' .claude/scripts/src/vcs/Provider.sh)"
printf '%s\n' "$body" | wc -l
printf '%s\n' "$body" | grep -cE 'git push *(>|$)'
printf '%s\n' "$body" | grep -c -- '-u origin'
# 3. 単体テスト（passed=N failures=0 で合格。反映対象2で追加する `git` スタブの
#    新規テストが passed に含まれること）
bash .claude/scripts/test/test_vcs_provider.sh | tail -1
```

- 実リモートへの空コミットpushを伴う結合確認は行わない。渡す引数の正しさは反映対象2の
  `git` スタブ単体テストで表明し、`-u origin HEAD` で回復することは flow-id 1-3 の実発生時に
  手動実行で確認済みのため、残る未確認は「実リモートとの疎通」だけであり、それはこの修正で
  変わる部分ではない（upstream未設定状態自体は `git init --bare` のローカルリモートでも再現
  できるが、スタブテストで引数を固定すれば足りるため行わない）。
