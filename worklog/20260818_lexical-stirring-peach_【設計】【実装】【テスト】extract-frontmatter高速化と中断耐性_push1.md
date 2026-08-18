---
title: worklog 20260818 extract-frontmatter高速化と中断耐性 push1
type: log
description: issue #11 extract-frontmatter.shの高速化・中断耐性対応の試行錯誤ログ（push1）
tags: [worklog, extract-frontmatter, performance]
keywords: [extract-frontmatter, index.jsonl, jq, プロセス起動, 95ms, mtime, キャッシュ, 原子的更新, ベースライン計測]
---

# worklog: 【設計】【実装】【テスト】extract-frontmatter高速化と中断耐性

対象: `.claude/scripts/src/extract-frontmatter.sh` のリポジトリルート一括実行の高速化と中断耐性（2026-08-18）。
全体作業計画: `plans/lexical-stirring-peach.md`
個別作業計画: `plans/【設計】【実装】【テスト】extract-frontmatter高速化と中断耐性.md`
push回数: 1

## 試したこと

### 全体作業計画（flow-id 1-4）作成時のボトルネック実測

- git bash上での外部プロセス起動コストを計測した。

  ```bash
  time (for i in $(seq 1 50); do jq -nc '1' >/dev/null; done)
  # real 0m4.730s → 94.6ms/回
  ```

- 現行実装の1ファイルあたりの外部コマンド起動回数を数えた。

  | 箇所 | 回数 |
  |---|---|
  | `frontmatter_block_to_json` のキー・配列要素ごとの `jq`（`json=$(jq -c ... <<<"$json")`） | 約20〜30 |
  | 最終行を組み立てる `jq -nc` ＋ `tr -d '\r'` | 2 |
  | `realpath` / `dirname`×2 / `stat` / `date` | 5 |

- 対象markdownは43ファイル（`git ls-files --cached --others --exclude-standard` で確認）。
  43 × 約30 × 95ms ≈ **約2分**となり、issue #11 に報告された症状（ルート指定でタイムアウト、
  `.claude/docs/ddr` 15ファイル単体で44秒）と数字が一致した。

### 既知バグ（specの未決定事項）の事前確認

`git ls-files --cached --others --exclude-standard` の出力に重複が無いか、ルート `index.jsonl` に
重複行が無いかを確認した。

```
総数 43 / ユニーク 43（重複0件）
ルート index.jsonl の concept_id 重複: 0件
```

→ **現在のクリーンな作業ツリーでは再現しない**。実装フェーズで再現手順の確立から行う。

## うまくいったこと

- **ボトルネックがアルゴリズムではなく「外部プロセス起動回数」であると実測で特定できた**。
  これにより、フェーズ2（調査）を正式に挟まずフェーズ3から着手する判断ができた（ユーザ合意済み）。
- 回帰検証の方法が定まった。**現在コミット済みの `index.jsonl` 群が現行実装の出力そのもの**のため、
  改修後に `--force` で全再生成して `git diff -- '*index.jsonl'` が空であることを確認すれば、
  「生成内容が現行実装と同一」という受け入れ条件の直接的な証拠になる。

## ダメだったこと

- 既知バグ（スコープ外 `index.jsonl` への影響・重複行）は、クリーンな作業ツリーでは再現できなかった。
  現時点では原因を特定できていない。

## 次の一歩

- flow-id 3-2: 個別作業計画・worklog・HANDOFF.mdをcommit（`commit`スキル経由）してpushし、レビュー依頼する。
- レビュー合意後、flow-id 3-6で実装に着手する。着手時の最初の作業は次の2つ。
  1. 改修前のベースライン計測（`.claude/docs/ddr` 単体・ルート指定。計測後は
     `git checkout -- '*index.jsonl'` で必ず復元する）
  2. 既知バグの再現確認（`extract-frontmatter.sh .claude/rules` 実行後の `git status` 観測）

---
