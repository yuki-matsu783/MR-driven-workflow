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
   `git push -u origin "$(git branch --show-current)"` 相当へ変更する（upstreamの有無に
   依存しない形。既にupstreamがある場合も同じ結果になり冪等）。
2. **specへの書き戻し**: `.claude/docs/spec/issue-mr-workflow.md`「Draft PR作成失敗時の
   自動リトライ」節へ、upstream未設定でも動くこと（issue #170で実不具合として検出・修正）を
   追記する（過去のchangelogは書き換えない。現在の仕様の節のみ）。
3. **別issue起票はしない**: 1関数1行の修正で、このissueのフロー内（flow-id 1-3）で実際に
   踏んだ不具合のため、`【実装反映】` の範囲で完結する。

## やらないこと（スコープ外）

- `.gemini/` 配下の同名ファイルの手動更新（生成物。flow-id 5-3 の `sync-gemini-assets.sh` が
  変換同期する）。
- `new_draft_merge_request` 側のリトライ構造の変更（不具合はpushのupstream指定のみ）。

## 検証（実行できるコマンドと合格条件）

```bash
# 1. 構文（終了コード0で合格）
bash -n .claude/scripts/src/vcs/Provider.sh
# 2. 引数なしの `git push` が当該関数に残っていない（出力0で合格）
sed -n '/^add_empty_commit_for_draft_mr()/,/^}/p' .claude/scripts/src/vcs/Provider.sh | \
  grep -cE 'git push *(>|$)'
# 3. 単体テスト（passed=N failures=0 で合格）
bash .claude/scripts/test/test_vcs_provider.sh | tail -1
```

- 実リモートへの空コミットpushを伴う結合確認は行わない（このPRブランチ自体が「upstream設定済み」
  になっており、未設定状態の再現にはリモートへの新規ブランチ作成が必要になるため。挙動の根拠は
  `git push -u origin <branch>` が flow-id 1-3 の実発生時に手動実行で回復した実績）。
