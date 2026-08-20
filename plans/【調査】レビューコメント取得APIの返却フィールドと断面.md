---
title: 【調査】レビューコメント取得APIの返却フィールドと断面
type: plan
description: diffHunk廃止後の出力を組み立てるために必要な、GitHub GraphQL/GitLab discussionsの返却フィールドとソース断面の取得可否を調べる個別調査計画
tags: [plan, investigation, vcs, review]
keywords: [GraphQL, reviewThreads, originalLine, isOutdated, discussions, position, head_sha, shallow, blob, フォールバック]
---

# 個別調査計画: レビューコメント取得APIの返却フィールドと断面

全体作業計画: `plans/issue43-review-comment-source-slice.md`（issue #43）

## 目的

`get_mr_unresolved_comments` の出力を「正規化JSON → 共通の後段ロジック → 行番号付きソース
スライス」という構成へ作り替えるにあたり、**プロバイダ層が何を返せるか**を確定させる。
ここが確定しないと、共通層のインターフェース（正規化JSONのキー）を決められない。

## 調べること

### A. GitHub GraphQL `reviewThreads` の返却フィールド

1. `PullRequestReviewThread` が `originalLine` / `isOutdated` / `startLine` /
   `originalStartLine` / `subjectType` を持つか。
2. `PullRequestReviewComment` が `commit { oid }` / `originalCommit { oid }` / `outdated` を持つか。
3. outdatedなスレッドで `line` が null になったとき、**どのフィールドの組で位置が復元できるか**
   （issue本文の「本リポジトリの既存スレッドは全件 `line=null` / `isOutdated=true`」の裏取り）。
4. `subjectType: FILE`（ファイル全体への指摘）のとき `path` はあるが `line` が無いケースの扱い。

### B. GitLab `discussions` の `position`

1. `position` が持つキー（`head_sha` / `base_sha` / `start_sha` / `new_path` / `new_line` /
   `old_path` / `old_line` / `position_type`）。
2. 削除行への指摘（`new_line` が無く `old_line` のみ）で、どの sha のどの path を切るべきか。
3. GitLab に「解決済みスレッド」の概念が note 単位（`resolvable` / `resolved`）である点が、
   スレッド単位の正規化とどう噛み合うか。

### C. ソース断面の取得可否

1. この実行環境が shallow clone であるか、任意の sha の blob をローカルで解決できるか
   （`git cat-file -e <sha>:<path>`）。
2. ローカルで解決できない場合のプロバイダ別ファイル取得API（GitHub `contents` API /
   GitLab `repository/files/.../raw`）の呼び出し形。
3. 現HEADへフォールバックしたときに、出力上どう区別を明示するか。

### D. 上限制御の実測

1. `.claude/rules/docs-workflow.md` の任意の行の ±10行が何バイトになるか（issue本文の 5,107B の
   裏取り）。
2. 行数上限だけでは制御にならないことを、実測値で示す。
3. 既定値（前後行数・バイト上限）の妥当な水準を決める。

### E. 現行実装の棚卸し

1. `github_get_mr_unresolved_comments` / `gitlab_get_mr_unresolved_comments` /
   `gitlab_format_discussion_notes` の呼び出し元をすべて洗い出す（後方互換を壊す範囲の確定）。
2. `.claude/hooks/session-start.sh` がこの出力をどう使っているか。
3. MCP経路（`mcp__github__pull_request_read`）は `Provider.sh` を通らないため、今回の変更の
   影響外であることの確認。

## 調べないこと

- `gh` / `glab` を実際に起動しての検証。この実行環境にCLIが無い（`get_vcs_access_mode` が `mcp`）。
  A・B は **GitHub GraphQL の公開スキーマ・MCPツールの返却JSON・既存コードの読解**で確定させ、
  実機で確認していない項目は【未検証】と明示する。
- GitLab の実機検証。remote が GitHub のみで、既存の【未検証】運用を踏襲する（issue #128 が
  ローカルGitLab CEでの実機検証を担当している）。

## 進め方

1. E（既存コードの棚卸し）→ A/B（APIフィールド）→ C（断面）→ D（実測）の順で進める。
   E を先に置くのは、変更範囲が確定しないと A/B で何を確認すべきかが決まらないため。
2. C・D は `git` と実ファイルだけで確認できるため、この環境でも実測できる。
3. A は MCP の `mcp__github__pull_request_read`（`method="get_review_comments"`）を
   PR #131 および過去PRに対して実行し、返却JSONのキーを実測する。GraphQL とは別APIだが、
   同じ REST の review comments を見ることで `original_line` / `commit_id` /
   `original_commit_id` / `line` の実値を確認できる。

## 成果物

- `reports/2026-08-20_issue43_レビューコメント出力仕様の調査.md`（正文）
- `reports/2026-08-20_issue43_レビューコメント出力仕様の調査.html`（視覚化）

## 完了条件

- 正規化JSONのキー一覧（プロバイダ層が返すもの）が、GitHub/GitLab 双方で埋められることを
  根拠付きで示せている。
- 断面の取得フォールバック段階が、この環境での実測に基づいて確定している。
- 上限制御の既定値（前後行数・バイト上限）が実測値を根拠に決まっている。
