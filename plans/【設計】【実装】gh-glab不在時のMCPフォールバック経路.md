---
title: 【設計】【実装】gh/glab CLI不在時のMCPフォールバック経路
type: guide
description: issue #34対応の個別作業計画。経路判定関数・CLI不在時ガード・MCPツール対応表・hookの挙動変更の具体仕様を定義する
tags: [issue-mr-flow, mcp, provider, fallback]
keywords: [get_vcs_access_mode, require_vcs_cli, parse_repo_slug, mcp_tool_hint, session-start, post-push, 対応表, issue34]
---

# 【設計】【実装】gh/glab CLI不在時のMCPフォールバック経路

対象: issue #34。全体作業計画（`plans/steady-bridging-gateway.md`）参照。

## 設計

### 1. 経路判定（受け入れ条件2）

`Provider.sh` に以下を追加する。

| 関数 | 役割 |
|---|---|
| `get_vcs_access_mode` | `get_provider` の結果に応じて `gh`（github）/ `glab`（gitlab）の存在を `command -v` で確認し、あれば `cli`、無ければ `mcp` を標準出力へ返す |
| `parse_repo_slug <remote-url>` | リモートURL（https / ssh / scp形式）から `{host, owner, repo, path, url}` のJSONを組み立てる純粋関数。MCPツールが必須引数として要求する `owner` / `repo` を、CLIなしで機械的に得るために使う |
| `get_repo_slug` | `git remote get-url origin` の値を `parse_repo_slug` へ渡す |
| `mcp_tool_hint <関数名>` | Provider関数名に対応するGitHub MCPツールと引数の要約文字列を返す（GitLabは「対象外」を返す） |
| `require_vcs_cli <関数名>` | `get_vcs_access_mode` が `cli` でなければ、`mcp_tool_hint` の内容とSKILL.mdの該当節を名指ししたメッセージをstderrへ出して終了コード1を返す |

各Provider関数（`get_issue` / `new_issue` / `new_draft_merge_request` /
`get_mr_unresolved_comments` / `add_mr_thread_reply` / `get_mr_for_branch` /
`set_mr_description` / `add_mr_comment`）の先頭に `require_vcs_cli <自関数名> || return 1` を置く。
これにより、CLI不在環境では `gh: command not found` という手がかりの乏しい失敗ではなく、
「どのMCPツールをどの引数で呼べばよいか」が必ず提示される。

`get_repo_url` のみ例外とし、MCP経路では `get_repo_slug` から組み立てたURLを返す
（`git remote` はローカル操作でありCLI・ネットワークを必要としないため、失敗させる必要が無い。
これにより `get_mr_diff_url` 等のURL組み立て系はMCP経路でもそのまま動く）。

### 2. MCPツール対応表（受け入れ条件1・GitHubのみ）

| Provider関数 | MCPツール | 主な引数 |
|---|---|---|
| `get_issue <n>` | `mcp__github__issue_read` | `method="get"`, `owner`, `repo`, `issue_number` |
| `new_issue` | `mcp__github__issue_write` | `method="create"`, `owner`, `repo`, `title`, `body` |
| `new_draft_merge_request` | `mcp__github__create_pull_request` | `owner`, `repo`, `title`, `head`, `base`, `draft=true`, `body` |
| `get_mr_for_branch <branch>` | `mcp__github__list_pull_requests` | `owner`, `repo`, `head="<owner>:<branch>"`, `state="open"` |
| `get_mr_unresolved_comments <n>` | `mcp__github__pull_request_read` | `method="get_review_comments"`（スレッド・`isResolved`付き）／`method="get_comments"`（通常コメント）, `owner`, `repo`, `pullNumber` |
| `add_mr_thread_reply <n> <threadId> <body>` | `mcp__github__add_reply_to_pull_request_comment` | `owner`, `repo`, `pullNumber`, `commentId`（**スレッド内の先頭コメントの数値ID**。GraphQLのthreadId `PRRT_...` は使えない）, `body` |
| `set_mr_description <n> <file>` | `mcp__github__update_pull_request` | `owner`, `repo`, `pullNumber`, `body`（ファイル内容を読んで文字列で渡す） |
| `add_mr_comment <n> <file>` | `mcp__github__add_issue_comment` | `owner`, `repo`, `issue_number`（＝PR番号）, `body` |
| `get_repo_url` | （MCP不要） | `get_repo_slug` で組み立てる |

`threadId`／`commentId` の差異は、CLI経路（GraphQLのthreadIdで返信）とMCP経路（REST由来の数値
commentIdで返信）で概念が異なるため、`reply` サブコマンドの手順に明記する。

### 3. hookの挙動（受け入れ条件3）

| hook | CLI不在時の挙動（変更後） |
|---|---|
| `session-start.sh` | 「(issue/MR情報の取得に失敗しました)」ではなく、`- VCS情報取得経路: MCP（gh/glab CLIが無い環境）` と、ブランチ名から抽出できたissue番号、MCPで取得する旨の指示を注入する。**PR欄を「なし」と誤って表示しない**（現状は `gh` の失敗を握りつぶすため、PRがあっても「PR: なし」と出てしまう） |
| `post-push-usage-report.sh` | 状態同期（`sync_usage_state`）までは従来どおり行い、MRコメント投稿の直前で経路を判定し、MCP経路ならスキップした旨をstderrへ1行出して終了する（`git push` はブロックしない） |
| `post-push-compact-prompt.sh` | MR URLは取得できないため、`get_repo_url`（ローカル組み立て）由来のCompare URLのみでレビュー依頼メッセージを組み立て、MRリンクはMCPで取得するよう促す1行を添える |

### 4. GitLab（受け入れ条件5）

`glab` 不在時の判定・失敗メッセージの枠組みは共通化するが、**対応表はGitHubのみを対象とし、
GitLabは対象外**とする。理由: このリポジトリのセッションではGitLab公式MCPサーバーの利用実績が無く、
ツール名・引数を実機で検証できないため（未検証の対応表を書くと、CLI不在時に誤った手順へ
誘導することになり、issue #34が解決しようとしている「その場の即興判断」より悪化しうる）。
`glab` 不在のGitLabリポジトリでは、その旨を明示して失敗させる。

## 実装タスク

1. `.claude/scripts/src/vcs/Provider.sh`: 上記5関数の追加・各Provider関数へのガード挿入・
   `get_repo_url` のMCP経路フォールバック
2. `.claude/hooks/session-start.sh`: MCP経路の分岐
3. `.claude/hooks/post-push-usage-report.sh` / `post-push-compact-prompt.sh`: MCP経路の分岐
4. `.claude/skills/issue-mr-flow/SKILL.md`: 「`gh`/`glab` CLI不在時のMCPフォールバック」節の新設、
   各サブコマンド・「前提」節からの参照
5. `.claude/skills/issue-create/SKILL.md`: `create-issue.sh` のMCP代替手順
6. `AGENTS.md`: MCP代替の記述からSKILL.mdの該当節への参照を追加
7. `tests/test_vcs_provider.sh`: `parse_repo_slug` / `mcp_tool_hint` の単体テスト追加
8. `.claude/docs/spec/issue-mr-workflow.md` / `.claude/docs/ddr/0025-*.md`（フェーズ4で反映）

## テスト観点

- `parse_repo_slug`: https / ssh(scp形式) / `ssh://` / `.git`無し / GitLabのネストnamespace / ポート付き
- `mcp_tool_hint`: 主要関数名でツール名が返る、未知の関数名でも空にならない
- `bash -n` による構文チェック（変更した全 `.sh`）
- 実環境（本セッション＝`gh`不在）で `get_vcs_access_mode` が `mcp` を返し、
  `get_issue 34` がMCPツール名入りのメッセージを出して失敗すること
