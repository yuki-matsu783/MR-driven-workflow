---
title: 【設計反映】起票前重複チェックの仕様とDDR
type: guide
description: issue #68の個別反映計画。specの提供関数表・新規節への追記内容と、DDR 0033に記録する判断・却下案の骨子を定める
tags: [spec, ddr, issue-create, plan]
keywords: [設計反映, DDR0033, 提供関数表, 未決定事項, search_issues, キーワード抽出]
---

# 個別反映計画: 起票前重複チェックの仕様とDDR（issue #68）

全体作業計画: `plans/duplicate-issue-check-flow.md`
個別作業計画: `plans/【実装】【テスト】類似issue検索関数と起票前チェック手順.md`

`【AIアセット反映】` と分けない理由: 本issueの成果物そのものが `.claude/skills/` と
`.claude/scripts/` の改訂であり、実装（フェーズ3）で既に反映済みである。
別途「作業中に気づいたルール・スキルの不備」は見つかっていないため、`【設計反映】` のみとする。

## 1. `.claude/docs/spec/issue-mr-workflow.md`

### 1-1. 「提供関数（`Provider.sh` 経由の共通インターフェース）」表

`new_issue` の行の下に `search_issues` の行を追加する。GitHub実装は
`gh issue list --search`（キーワードごと）、GitLab実装は `glab issue list --search`。

あわせて表の下の解説（内部ヘルパーは表に載らない旨）に、
`github_normalize_issue_search_results` / `gitlab_normalize_issue_search_results` /
`merge_issue_search_results` が同じ位置づけであることを追記する。

### 1-2. 「issue作成（AIエージェント代行・スクリプト実行）（issue #25）」節の直後に新節

`### 起票前の類似・重複issueチェック（issue #68）` を新設し、次を記載する。

- 背景（UIのサジェストがAI経路では働かず、AI経路のほうが重複を作りやすい構造だった）
- `search_issues` の仕様（closedを含む・キーワードごとに検索して統合・最大5キーワード・
  `state` を `open`/`closed` へ正規化）
- 責務分割（キーワード抽出＝スキル側／検索・正規化・統合＝`Provider.sh` 側）
- 最終判断は人間が行う原則
- MCP経路での差分（`mcp__github__search_issues` は1回の `query` で足りる）

### 1-3. 「影響範囲」

issue #68 の変更ファイルを新規/更新に分けて追記する（過去issueのchangelogエントリは
書き換えず、新規エントリの追記に留める。`.claude/rules/docs-workflow.md` の規定）。

### 1-4. 「未決定事項・懸念点」

CLI経路（`gh issue list --search` / `glab issue list --search`）が実機未検証である旨を追記する。

## 2. `.claude/docs/ddr/0033-...md`（新規）

ファイル名: `0033-issue起票前の重複チェックは検索をProvider層へ置きキーワード抽出はAIに委ねる.md`
（`Provider.sh` と `issue-create/SKILL.md` から既にこのパスを参照しているため、名前を変えない）。

記載する決定:

1. キーワード抽出はAI（スキル側）が行い、bashへ実装しない
2. 検索はキーワードごとに1回ずつ行い、結果をOR的に統合する
3. closedのissueも対象に含める
4. 重複かどうかの最終判断は人間が行い、AIは候補提示に留める

却下案:

- ひらがな区切り／文字クラスによるbash実装（ロケール依存で静かに劣化する）
- ストップワードリスト方式（保守が必要で、固有語かどうかは文脈依存）
- 全キーワードを1回のAND検索で渡す（語が増えるほどヒットしなくなる）
- `create-issue.sh` 側で重複を検知したら起票を中止する（判断を機械に委ねることになる）
- `gh search issues` の利用（`--repo` 指定とPR除外が必要で、`gh issue list --search` より複雑）

## 3. `.claude/docs/README.md`

DDR一覧に0033の行を追加する。

## 4. `HANDOFF.md`

flow-idの進捗表を更新する。非対話的実行環境のため、人間担当のレビュー待ちステップ
（2-3/2-4, 3-3/3-4, 3-8/3-9, 4-3/4-4, 4-8/4-9）の記号は `[]` のまま残し、実施内容は
「やったこと」で補足する（`.claude/rules/docs-workflow.md` 末尾の規定）。
