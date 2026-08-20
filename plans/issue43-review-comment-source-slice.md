---
title: issue #43 全体作業計画 — レビューコメント取得の出力仕様見直し
type: plan
description: diffHunkを廃止し、(path, line, sha)から共通ロジックで指摘行前後のソースを切り出す方式へ移行するための全体作業計画
tags: [plan, workflow, vcs, review]
keywords: [diffHunk, ソーススライス, レビューコメント, Provider, GraphQL, discussions, 断面, originalLine, バイト上限, フォールバック]
---

# 全体作業計画: レビューコメント取得の出力仕様を見直す（issue #43）

- issue: #43 https://github.com/yuki-matsu783/MR-driven-workflow/issues/43
- ブランチ: `claude/issue-43-snhmw7`（セッション指定のブランチ。`branchPrefixTemplate` の
  `feature-43-*` ではなく、ハーネスが指定した名前をそのまま使う）
- PR: #131 https://github.com/yuki-matsu783/MR-driven-workflow/pull/131（Draft）

> **注記**: 本ファイルは planツール（Planモード）ではなく Write で作成した。この実行環境
> （Claude Code on the web）はセッション開始時点で既にPlanモードを抜けており、planツールの
> 出力先を取得できないため。`plans/` 直下で `【` で始まらない唯一のファイルであり、
> flow-id 1-4 の判定（`.claude/skills/issue-mr-flow/SKILL.md`「計画の2階層構造」）上は
> 全体作業計画として扱われる。

## 1. このissueで何を達成するか

`get_mr_unresolved_comments` の出力から GitHub 固有の `diffHunk` を取り除き、代わりに
**`(path, line, sha)` から共通ロジックが切り出した「指摘行前後のソース（絶対行番号付き）」**を
出力する。目的はコンテキスト量の予測可能化と、GitHub/GitLab 実装の非対称の解消。

受け入れ条件（issue本文より）を作業単位へ割り付けると次のとおり。

| # | 受け入れ条件 | 主に対応するフェーズ |
|---|---|---|
| 1 | diffHunkを除去し、行番号付きソーススライスを出力する | 3 |
| 2 | ソーススライスはスレッド単位で1回だけ | 3 |
| 3 | 行数とバイト数の両方で上限制御する | 3 |
| 4 | `line` が null のスレッドで `originalLine` へフォールバックする | 2（API調査）→ 3 |
| 5 | GitLab実装も `path`/`line`/`sha` を出力し、同じ後段ロジックを使う | 3（実機検証は対象外・【未検証】注記を維持） |
| 6 | 「断面（コメント時点のcommit）か現HEADか」の設計判断をDDRへ記録する | 4 |
| 7 | ローカルにblobが無い場合のフォールバック経路を実装する | 2（経路の洗い出し）→ 3 |

## 2. 方針（現時点の見立て。フェーズ2の結果で更新しうる）

### 2.1 層の切り分け

```
Provider.sh
  get_mr_unresolved_comments <n> [true]        ← 共通の後段ロジック（スライス付与＋整形）
    ├─ github_get_mr_review_threads <n> [true] ← 正規化JSONを返すだけ（gh api graphql）
    ├─ gitlab_get_mr_review_threads <n> [true] ← 正規化JSONを返すだけ（glab api）
    ├─ build_review_source_slices <正規化JSON>  ← (path,line,sha) → 行番号付きスライス
    └─ format_review_comments <正規化JSON> <スライスJSON>  ← 純粋関数（jqのみ・単体テスト対象）
```

**プロバイダ層は正規化JSONだけを返し、テキスト整形を持たない**（現状は GitHub / GitLab が
それぞれ別々に整形しており、CR除去の有無のような非対称が生まれていた。issue #43 へのマージ前
通知コメント参照）。整形を1箇所へ寄せることで、`.claude/scripts/test/test_vcs_provider.sh` から
**GitHub側の整形もテストできる**ようになる（現状 `github_get_mr_unresolved_comments` は
`gh` 依存のため単体テストが1件も無い）。

### 2.2 断面（どのcommitのソースを切るか）

**コメント時点のsha（GitHub: `originalCommit.oid` / `commit.oid`、GitLab: `position.head_sha`）を
優先し、取得できない場合に現HEADへフォールバックする**（ユーザー承認済み。DDRへ記録する）。
レビュアーが実際に見た内容と一致させるため。フォールバック時は「現HEAD時点である」旨を
出力へ明示する。

### 2.3 ソース取得のフォールバック段階

1. ローカルに blob がある: `git cat-file -e <sha>:<path>` → `git show <sha>:<path>`
2. 無い（shallow clone 等）: プロバイダ別のファイル取得API
   （GitHub `gh api repos/{owner}/{repo}/contents/...?ref=<sha>` / GitLab `glab api ... /raw?ref=<sha>`）
3. それも失敗: 現HEAD（`git show HEAD:<path>`。断面が違う旨を明示）
4. 全て失敗: ソース無しで出力（コメント本文だけは必ず出す）

### 2.4 上限制御

- 行数: 指摘行の前後 N 行（既定 10）
- バイト数: スライス全体の上限 B バイト（既定 2000）。超えたら指摘行を中心に削って切り詰め、
  切り詰めた旨を明示する。
- どちらも環境変数で上書き可能にする（既定値はスクリプト内の定数）。

## 3. フェーズ2〈調査〉

**実施する。** 実装方針が API の返却フィールドに強く依存しており、以下は現物を確認しないと
決められないため。

- GitHub GraphQL `reviewThreads` が `originalLine` / `isOutdated` / `comments.nodes[].commit.oid` /
  `originalCommit.oid` を返すか（本リポジトリの既存スレッドは全件 `line=null` と issue に記載あり）
- GitLab `discussions` の `position` が持つキー（`head_sha` / `base_sha` / `start_sha` /
  `new_path` / `new_line` / `old_path` / `old_line`）
- ローカルに blob が無いケースの実際の発生条件（この実行環境は shallow clone）
- 現行出力のどこが何バイトを占めているかの再確認（issue本文の実測値の裏取り）

**制約**: この実行環境に `gh` / `glab` CLI が無い（`get_vcs_access_mode` が `mcp` を返す）。
GraphQL の実機実行はできないため、調査は **MCPツールの返却JSON・GitHub GraphQL の公開スキーマ・
既存コードの読解**で行い、実機未確認の項目は【未検証】と明示する。

成果物は `reports/2026-08-20_issue43_レビューコメント出力仕様の調査.md`（正文）と同名 `.html`。

## 4. フェーズ3〈作業〉

個別作業計画 `plans/【実装】【テスト】レビューコメント出力のソーススライス化.md` を作り、
上記 2.1 の構成で実装する。

- `.claude/scripts/src/vcs/Github.sh`: `github_get_mr_review_threads` を新設（GraphQLクエリから
  `diffHunk` を外し、`originalLine` / `isOutdated` / commit oid を追加）。
  `github_get_mr_unresolved_comments` は廃止する。
- `.claude/scripts/src/vcs/Gitlab.sh`: `gitlab_get_mr_review_threads` を新設。
  `gitlab_format_discussion_notes` は共通の `format_review_comments` へ統合する。
- `.claude/scripts/src/vcs/Provider.sh`: 共通の後段ロジック（スライス生成・整形）を追加し、
  `get_mr_unresolved_comments` をその合成に置き換える。
- `.claude/scripts/test/test_vcs_provider.sh`: 純粋関数（正規化JSON→テキスト、スライス生成）の
  単体テストを追加する。GitHub側の整形にテストが付くのは本issueが初。

**やらないこと**

- `gh` / `glab` の実機実行を伴う検証（この環境にCLIが無い。GitLabは remote が GitHub のみのため
  そもそも対象外で、既存の【未検証】注記の運用を踏襲する）
- MCP経路（`mcp__github__pull_request_read`）側の出力仕様変更。こちらは AI が直接ツールを呼ぶ
  経路であり、`Provider.sh` の整形を通らない。SKILL.md の対応表への注記追加に留める。

## 5. フェーズ4〈反映〉

反映対象は flow-id 4-1 で洗い出す。現時点の見込みは次のとおり（確定ではない）。

- `.claude/docs/spec/issue-mr-workflow.md`: 提供関数表の `get_mr_unresolved_comments` の行、
  および内部ヘルパーに関する記述
- `.claude/docs/ddr/0059-*.md`: 断面をコメント時点のshaにする判断（受け入れ条件6）
- `.claude/skills/issue-mr-flow/SKILL.md`: `comments` サブコマンドの説明（「該当diffを含む」を
  「ソーススライスを含む」へ）、MCPフォールバック対応表の注記
- `.claude/rules/shell-script-style.md`: 実装中に得た知見があれば

DDR番号は `0059` を予定（`main` の最新は `0058`）。フェーズ5のコンフリクト検知で番号衝突を
再確認する。

## 6. issueの分割について

**分割しない。** 受け入れ条件は7項目あるが、同型の成果物の並列列挙ではなく、
**1つの関数の出力仕様を作り替える単一の変更**である。プロバイダ層・共通層・テストは同時に
変えないと壊れるため、`.claude/skills/issue-mr-flow/SKILL.md`「分割しない条件」の
**横断的変更**に該当する。

## 7. 本セッションの制約

- `gh` / `glab` CLI が無い（MCP経路）。VCS操作は `mcp__github__*` で代替する。
- ハーネスがPR作成を制限する環境のため、Draft PR #131 はユーザーの承認（AskUserQuestion）を
  得てから作成した。
- 人間のレビュー往復（flow-id 2-3/2-8/3-3/3-8/4-3/4-8）を待ち切れないため、該当ループ範囲の
  進捗記号は `[]` のまま残し、実施内容は HANDOFF.md の「やったこと」へ文章で残す。
