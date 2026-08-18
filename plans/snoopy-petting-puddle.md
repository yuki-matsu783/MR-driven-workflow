---
title: issue #23 全体作業計画 — セッションログのミラー統合とpush断面の行番号インデックス化
type: plan
description: logs/とusage/session-logs/の重複を解消し、push断面スナップショットをpush-index.jsonlの行番号記録へ置き換えるissue #23の全体作業計画
tags: [usage-report, session-logs, hooks, refactoring]
keywords: [push-index, session-logs, UsageTracking, post-push-save-logs, ミラー統合, 行番号カーソル, Gemini CLI, compact, 追記専用, show-push-log]
---

# issue #23 全体作業計画

セッションログのミラー統合とpush断面の行番号インデックス化

- issue: #23 https://github.com/yuki-matsu783/MR-driven-workflow/issues/23
- ブランチ: `feature-23-unify-session-log-mirrors`（base: main）
- Draft PR: #24

## Context（なぜこの変更を行うか）

`git push` のたびにセッションログを保存する仕組みが2系統に分かれており、同じtranscriptの重複コピーが
蓄積している。

| | `logs/` | `usage/session-logs/` |
|---|---|---|
| 所有hook | `post-push-save-logs.sh` | `post-push-usage-report.sh`（`UsageTracking.sh`） |
| 単位 | pushごとに全文（現在11断面） | セッションごとに1本（上書き） |
| サイズ | 14MB | 13MB |
| 増え方 | push回数に比例 | 一定 |
| 読み手 | **なし**（write-only） | 集計処理 |
| 仕様書 | `spec/session-log-hooks.md` | `spec/issue-mr-workflow.md` |

計27MBが、実質1セッション約1MBの一次データの重複である。

### 前提となる実測結果（本issueの根拠）

issue起票前の調査で、以下を実データで確認済み（フェーズ2の調査は実質完了しているとみなす）。

1. **transcriptは追記専用**である。`logs/push-7/8/9/10/11`（253/476/545/553/698行）はいずれも、
   現物transcript（883行）の先頭N行と**バイト単位で完全一致**した。
2. **`/compact` はこの性質を壊さない**。push-10（553行）はcompact境界（570行目）より前の断面だが、
   compact後の現物とも完全一致した。compactは「モデルへ送るコンテキストの圧縮」であって
   ディスク上のtranscriptの削除・切り詰めではない。実際、compact境界は
   `{"type":"system","subtype":"compact_boundary","compactMetadata":{...}}` として
   **追記**され、要約本文が `isCompactSummary: true` の行として続くだけだった。
3. 対応工数レポートのカーソル（`session-cursors/<sessionId>.json` の `lastLineCount`）は、
   compact境界を問題なく通過して進んでいた（698行時点で記録あり）。

つまり **push断面は「1本のミラー＋行番号2つ」で完全に代替できる**。全文コピーは不要である。

### 併せて解消する設計のズレ

issue #37でカーソルは `session-cursors/<sessionId>.json` と**ブランチ非依存**へグローバル化されたが、
ミラーのパスは `usage/session-logs/<safeBranch>/<sessionId>/` と**ブランチ単位のまま**残っている。
セッションが別ブランチへresumeされると全文コピーがブランチ数だけ増殖する。カーソルの設計思想と
噛み合っていない残骸であり、今回あわせてセッション単位へ揃える。

## 進め方（フェーズ構成）

| フェーズ | 実施 | 内容 |
|---|---|---|
| 1 | 実施 | 起点（issue #23起票済み・ブランチ/Draft PR #24作成済み・本計画） |
| 2 | **省略** | 調査。上記「前提となる実測結果」で完了済みのため個別調査計画は作らない |
| 3 | 実施 | 設計・実装・テスト |
| 4 | 実施 | 設計反映・AIアセット反映 |
| 5 | 実施 | 片付け・Draft解除 |

フェーズ3の個別作業計画は `plans/【設計】【実装】【テスト】セッションログのミラー統合とpush断面インデックス化.md`
として1ファイルに併記する（設計・実装・テストが一体で判断でき、合意を分ける必要がないため）。

## 実装方針

### 1. ミラーをセッション単位の1系統へ統合

`.claude/hooks/lib/UsageTracking.sh` の `_usage_sync_session_logs` を変更する。

- コピー先を `usage/session-logs/<safeBranch>/<sessionId>/` → `usage/session-logs/<sessionId>/` へ変更
  （`branch` 引数が不要になる）。
- 引数に `engine`（`claude` / `gemini`）を追加し、サブエージェント探索を分岐する。

| engine | サブエージェント探索 | コピー先 |
|---|---|---|
| `claude` | `${transcript_path%.jsonl}/subagents/agent-*.jsonl` ＋ 対応する `.meta.json` | `subagents/` 直下 |
| `gemini` | `$(dirname "$transcript_path")/<session_id>/` を `cp -R` | `subagents/<session_id>/` |

Gemini分を `subagents/<session_id>/` という1階層下へ置くことで、集計側
（`_usage_aggregate_and_merge_subagents` の glob `subagents/agent-*.jsonl`）には**マッチしない**。
「Geminiのログは保存するが集計対象にはしない」という本issueのスコープが、追加のガードなしに
構造だけで保証される。

### 2. engineの引き渡し

`post-push-usage-report.sh` は既に `engine` 変数を持っている（issue #7）。これを
`sync_usage_state repo_root branch session_id transcript_path [engine]` の第5引数として渡す。
省略時は `claude` を既定とし、既存のテスト・呼び出しを壊さない。

### 3. push断面を `usage/state/push-index.jsonl` へ記録

新規関数 `_usage_append_push_index` を追加し、新規行があったpushでのみ1行を追記する。

```json
{"push":12,"at":"2026-08-18T12:34:56Z","branch":"feature-23-...","sessionId":"8f1e0ff9-...","engine":"claude","main":{"from":699,"to":883},"agents":{"a2f64f10a7c680386":{"from":1,"to":120}}}
```

- `push` は既存行数+1。ファイルが無ければ1。
- `from`/`to` は**1始まり・両端含む**の行範囲（`from = 前回カーソル値 + 1`, `to = totalLines`）。
  行の基準は既存の集計と同じ「空行を除いた行数」に揃える。
- `agents` を埋めるため、`_usage_aggregate_and_merge_subagents` の戻り値を
  `{state: <状態JSON>, agents: {<agentId>: {from, to}}}` へ変更する（呼び出しは
  `sync_usage_state` の1箇所のみ）。

### 4. `logs/` 系統の廃止

- `.claude/hooks/post-push-save-logs.sh` を削除
- `.claude/settings.json` の `hooks.PostToolUse` から該当2エントリを削除
- `.gemini/settings.json` の `AfterTool` から `post-push-save-logs` エントリを削除
- `.gitignore` から `/logs/` を削除
- 既存のローカル状態（`logs/` 全体・`usage/session-logs/<safeBranch>/` の旧レイアウト）を削除する。
  いずれもgitignore対象の再生成可能なキャッシュであり、`logs/` には読み手が存在しない。

### 5. 参照用ヘルパー `.claude/scripts/src/show-push-log.sh`

`push-index.jsonl` から指定push番号の行範囲を引き、`usage/session-logs/<sessionId>/main.jsonl` の
該当範囲を出力する。引数なしでpush一覧を表示する。

## 対象ファイル

変更:
- `.claude/hooks/lib/UsageTracking.sh`（中核。`_usage_sync_session_logs` のパス・engine分岐、
  `_usage_append_push_index` 追加、`_usage_aggregate_and_merge_subagents` の戻り値変更、
  `sync_usage_state` の引数追加）
- `.claude/hooks/post-push-usage-report.sh`（`engine` の引き渡し）
- `.claude/settings.json` / `.gemini/settings.json` / `.gitignore`

新規:
- `.claude/scripts/src/show-push-log.sh`
- `tests/test_usage_tracking.sh`（`post-push-usage-report.sh` のコメントが参照しているが**実在しない**
  ため、本issueで新設する）

削除:
- `.claude/hooks/post-push-save-logs.sh`
- `.claude/docs/spec/session-log-hooks.md`（内容は `issue-mr-workflow.md` へ統合）

フェーズ4（反映）で扱う:
- `.claude/docs/spec/issue-mr-workflow.md`（session-log-hooks.mdの統合、compact検証結果の反映、
  下記「push検知の実挙動」の修正）
- 新規DDR（push断面の全文コピーを行番号インデックスへ置き換えた判断・却下案）
- `.claude/rules/git-workflow.md`（下記「push検知の誤検知」の注記追加）

## 併せて検証・修正する事項（issue #23 のコメントに記録済み）

本issueの起票作業自体で、`create-issue.sh` のコマンド文字列の地の文に該当語が含まれていたため、
実際にはpushしていないのにpush検知hookが3本とも発火した（`logs/push-13/` が生成され、カーソルが
進んだ。MRへの誤投稿は発生せず）。

1. `spec/issue-mr-workflow.md` は検知を「**前方一致マッチ**」と説明し、それを根拠に
   「スクリプト経由のpushは検知されない」という制約を導いているが、`cd ...` で始まるコマンドで
   発火した以上、**実際は部分一致として動作している**。実挙動を検証して記述を正す。
2. `.claude/rules/git-workflow.md` にはcommit側の誤検知注記があるが、push側には無い。追記する。

## 検証方法

1. **単体テスト**: `bash tests/test_usage_tracking.sh`（`mktemp -d` のフィクスチャ＋`trap`、
   `passed=N failures=N` を出力し失敗時に終了コード1。`tests/test_extract_frontmatter.sh` と同じ規約）。
   対象: `_usage_append_push_index` の連番・行範囲、`_usage_sync_session_logs` のパスとengine分岐、
   `_usage_aggregate_and_merge_subagents` の新しい戻り値形。
2. **構文チェック**: 変更・新規の `.sh` すべてに `bash -n`。
3. **実データでの回帰確認**: 本ブランチで実際にpushし、
   - `usage/session-logs/<sessionId>/main.jsonl` が作られる（ブランチ階層が無い）
   - `usage/state/push-index.jsonl` に行範囲が追記される
   - `logs/` が再生成されない
   - PR #24 への対応工数レポートが従来と同じ体裁で投稿される
4. **ヘルパーの一致確認**: `show-push-log.sh <N>` の出力が、`push-index.jsonl` の範囲に対する
   `sed -n 'from,top'` と一致する。
5. **Gemini分岐**: 実機検証は困難なため、移植前後で探索ロジックが等価であることをコード上で確認し、
   フィクスチャによる単体テストで `subagents/<session_id>/` へコピーされることを確認する。

## やらないこと（スコープ外）

- Geminiのサブエージェントを**対応工数の集計対象に含める**こと（現行も集計されていない。
  `spec/session-log-hooks.md` が「Gemini本体の挙動と整合しない可能性・未検証」と認めている前提の
  検証から必要になり、別issueの規模）。
- ネストしたサブエージェント（depth 2以降）への対応。
- `activeSeconds` の算出方式の変更（全件再パース＋スナップショット差分を維持）。
- `usage/session-logs/` の保持期間・自動削除ポリシーの導入。
