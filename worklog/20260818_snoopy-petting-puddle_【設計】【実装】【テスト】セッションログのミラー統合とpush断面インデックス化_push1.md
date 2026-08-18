---
title: worklog 20260818 セッションログのミラー統合とpush断面インデックス化 push1
type: log
description: issue #23のフェーズ3 push1のworklog。計画作成時点までの調査根拠と設計判断を記録する
tags: [worklog, usage-report, session-logs]
keywords: [push-index, session-logs, compact, prefix検証, Gemini CLI, ミラー統合, 誤検知, UsageTracking]
---

# worklog: 【設計】【実装】【テスト】セッションログのミラー統合とpush断面インデックス化

対象: `logs/` と `usage/session-logs/` の重複解消と、push断面の行番号インデックス化（2026-08-18）。
全体作業計画: `plans/snoopy-petting-puddle.md`
個別作業計画: `plans/【設計】【実装】【テスト】セッションログのミラー統合とpush断面インデックス化.md`
push回数: 1

## 試したこと

### 1. 対応工数レポートの仕様確認から重複に気づいた

`spec/issue-mr-workflow.md`「対応工数レポート」節と `spec/session-log-hooks.md` を読み比べ、
`logs/push-<N>/` と `usage/session-logs/` が同じtranscriptを別々にコピーしていることを把握した。

### 2. `/compact` がtranscriptを破壊するかを実データで確認した

「compactするとログが消えるのでは」という懸念に対し、別セッション（`8f1e0ff9`）で実際に
`/compact` を実行してもらい、transcriptを調べた。

```
$ grep -n 'isCompactSummary\|compactMetadata\|compact_file_reference' <transcript>
570: {"type":"system","subtype":"compact_boundary","content":"Conversation compacted",
      "compactMetadata":{"trigger":"manual","preTokens":251995,"postTokens":15679,
      "cumulativeDroppedTokens":236316,...}}
571: {"type":"user","message":{..."This session is being continued from..."},
      "isCompactSummary":true,...}
578,579: {"type":"attachment","attachment":{"type":"compact_file_reference",...}}
```

- compactは境界行と要約行を**追記**するだけで、570行目より前の行は削除されていなかった。
- `preTokens: 251995 → postTokens: 15679` は「次回以降モデルへ送るコンテキスト」の圧縮であり、
  ディスク上のファイルの話ではない。
- 同セッションのカーソル（`session-cursors/8f1e0ff9….json`）は `lastLineCount: 698` まで進んでおり、
  compact境界（570行目）を問題なく通過していた。

### 3. push断面が冗長であることをバイト単位で検証した

```
$ for n in 7 8 9 10 11; do
    L=$(wc -l < "logs/push-$n/<session>.jsonl")
    head -n "$L" <現物transcript> | cmp -s - "logs/push-$n/<session>.jsonl" && echo "push-$n ($L行) prefix一致"
  done
push-7  (253行) prefix一致
push-8  (476行) prefix一致
push-9  (545行) prefix一致
push-10 (553行) prefix一致
push-11 (698行) prefix一致
（現物: 883行）
```

**push-10（553行）はcompact境界570行目より前の断面**であり、compact後の現物とも完全一致した。
これがcompact非破壊性の最も強い証拠になった。

### 4. `logs/` に読み手が存在しないことを確認した

```
$ grep -rn 'logs/push\|logs_dest_dir\|post-push-save-logs' --include='*.sh' --include='*.json' --include='*.md' .
```
ヒットしたのは `post-push-save-logs.sh` 自身・その仕様書・他hookのコメント内言及のみで、
`logs/` を**読む**コードは存在しなかった（write-only）。

### 5. 容量とレイアウトのズレを測った

- `logs/` 14MB（13断面）／`usage/session-logs/` 13MB → 計27MB。実質1セッション約1MBの重複。
- `logs/` は push回数に比例して増える。
- issue #37でカーソルは `session-cursors/<sessionId>.json` とブランチ非依存へ移行済みなのに、
  ミラーは `usage/session-logs/<safeBranch>/<sessionId>/` とブランチ単位のまま残っていた。

## うまくいったこと

- **「追記専用」という性質を根拠に、push断面を行番号2つへ還元する設計に到達した。**
  スナップショットの全文コピーは、ミラー1本＋`{from, to}` で完全に代替できる。
- **Gemini分を `subagents/<session_id>/` という1階層下へ置く**ことで、集計側の glob
  `subagents/agent-*.jsonl` に構造的にマッチしなくなり、「保存はするが集計はしない」という
  スコープ境界をガード条件なしで表現できた。
- `_usage_sync_session_logs` から `branch` 引数を落とせることを確認した。この関数は `branch` を
  コピー先パスの組み立てにしか使っておらず、集計側のブランチフィルタは別関数が独立に持っている。

## ダメだったこと

- **issue起票コマンド自体でpush検知hookを誤発火させた。** `create-issue.sh` へ渡したissue本文
  （heredoc）の地の文に該当語が含まれていたため、実際にはpushしていないのにhookが3本とも発火し、
  `logs/push-13/` が生成されカーソルが進んだ（MRへの誤投稿は `sinceLastPush` の条件で回避された）。
  - `.claude/rules/git-workflow.md` にはcommit側の同種の注記があるが、push側には無かった。
  - さらに `spec/issue-mr-workflow.md` は検知を「前方一致マッチ」と説明しているが、
    `cd ...` で始まるコマンドで発火した以上、**実際は部分一致**として動作していることになる。
    この記述は「スクリプト経由のpushは検知されない」という制約の根拠になっているため、
    フェーズ3で実挙動を確認しフェーズ4で仕様書を正す。
  - issue #23 にコメントとして記録済み（issuecomment-5328101261）。
  - 以降、この件を扱うコマンドはファイル経由（`gh issue comment --body-file`）に切り替えて回避した。
- `post-push-usage-report.sh` のコメントが `tests/test_usage_tracking.sh` を参照しているが、
  実際には存在しなかった（`tests/` は issue #11 で新設され、`test_extract_frontmatter.sh` のみ）。
  本issueで新設する。

## 次の一歩

- flow-id 3-2: 計画・worklogをcommitしpushしてレビュー依頼（push1）。
- レビュー合意後、flow-id 3-6 で実装に入る。実装順は個別作業計画の「実装手順」に従う。
