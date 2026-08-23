---
title: push前チェックリスト機構
type: spec
description: pushの前に済ませるべき作業を、pushごとに一意なGit管理下のTSVチェックリストとして持たせ、未完了ならPreToolUse hookがexit code 2でブロックする機構の仕様。
tags: [spec, hook, push, workflow]
keywords: [push前チェックリスト, PreToolUse, PostToolUse, push-checklist, TSV, verify, stale, ブロック, worklog]
---

# push前チェックリスト機構

> **この仕様は flow-id 4-6（設計反映）で完成させる。現時点は実装・ブロックメッセージからの
> 参照先を成立させるための骨組みである**（issue #17 フェーズ3）。
> 内容の正は、フェーズ3の作業結果
> `wip/reports/20260823_steady-guarding-checkpoint_push前チェックリスト機構の実装.md` と
> 調査結果 `wip/reports/20260823_steady-guarding-checkpoint_push前チェックリスト機構の設計調査.md`
> にある（どちらも flow-id 5-5 で削除されるため、フェーズ4でこのファイルへ移す）。

## 背景・目的

push前に済ませるべき作業——worklogの作成・追記、`HANDOFF.md` の進捗表・ヘッダの更新、
frontmatterインデックス（`index.jsonl`）の最新化、`wip/plans/` `wip/reports/` の md と html の
同期、`commit` スキル経由でのコミット——は、いずれもドキュメント上のルールとしてしか
存在しておらず、AIエージェントの遵守に依存していた。実際に、issue #17 の作業中だけでも
「`HANDOFF.md` の `- push回数:` をpushの後に更新し、その1行だけが未コミットで残る」という
形で1度失敗している。

そこで、**pushごとに一意なGit管理下のチェックリスト**を持たせ、未完了のままpushしようとした
場合に PreToolUse hook が **exit code 2** でブロックする。

## 仕様

### 構成要素

| ファイル | 役割 |
|---|---|
| `.claude/scripts/src/push-checklist.sh` | 生成（`new`）・記録（`check` / `skip`）・検証（`verify`）・コミット忘れ検知（`stale`）・パス解決（`path`）の本体 |
| `.claude/hooks/block-unchecked-push.sh` | PreToolUse。`verify` が検証失敗を返したら `exit 2` でブロックする |
| `.claude/hooks/post-push-next-checklist.sh` | PostToolUse。次回分のチェックリストを生成する |

### 使い方（暫定。正式な手順は flow-id 4-6 で `commit` / `issue-mr-flow` の SKILL.md へ書く）

コミットの前に、項目ごとに次のいずれかを実行する。

```bash
bash .claude/scripts/src/push-checklist.sh check <id> "<実施ログ>"
bash .claude/scripts/src/push-checklist.sh skip  <id> "<スキップの理由>"
```

書き換えたチェックリストは、**そのpushのコミットへ必ず含める**（hookはHEADにコミット済みの
断面を読むため、作業ツリーだけ埋めてもブロックは解けない）。

## 影響範囲

（flow-id 4-6 で記述する）

## 設定項目

（flow-id 4-6 で記述する）

## 未決定事項・懸念点

（flow-id 4-6 で記述する）
