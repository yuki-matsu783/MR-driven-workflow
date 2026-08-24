---
title: issue-mr-flow 参照: gh/glab CLI不在時のMCPフォールバック
type: skill-reference
description: get_vcs_access_mode が mcp を返す環境で、各サブコマンドの手順に入る前に開く。Provider関数とMCPツールの対応表
tags: [issue-mr-flow, skill-reference, mcp]
keywords: [MCPフォールバック, get_vcs_access_mode, mcp__github__, Provider.sh, 対応表, リモート実行環境]
---

# issue-mr-flow 参照: gh/glab CLI不在時のMCPフォールバック

## `gh`/`glab` CLI不在時のMCPフォールバック

Claude Code on the webのリモート実行環境のように、`gh`/`glab` CLIが存在せず `git`・`jq` しか
使えない環境がある（issue #21対応時に実機確認）。この場合 `Provider.sh` のプロバイダ依存関数は
動かないため、GitHub公式のMCPサーバーツール（`mcp__github__*`）で代替する。**WebFetchツール・
curlへはフォールバックしない**（理由はDDR i0014-01のまま変わらない。経緯: DDR i0034-01）。

### 1. 経路の判定（各サブコマンドの最初に必ず行う）

```bash
source .claude/scripts/src/vcs/Provider.sh
get_vcs_access_mode   # → cli / mcp
```

- `cli`: 各サブコマンドに書かれているとおり `Provider.sh` の関数をそのまま使う。
- `mcp`: 下の対応表に従って読み替える。**その場の判断で別のツールを選ばない。**

判定を忘れてCLI経路の関数を呼んだ場合も、`require_vcs_cli` ガードが
「代替すべきMCPツール名・引数」をstderrへ出して失敗するため、そのメッセージに従えばよい
（`gh: command not found` のような手がかりの乏しい失敗にはならない）。

MCPツールが必須で要求する `owner` / `repo` は、CLIなしで次のように取得する。

```bash
get_repo_slug            # → {"host":...,"owner":...,"repo":...,"path":...,"url":...}
get_repo_slug | jq -r '.owner, .repo'
```

### 2. Provider関数 → MCPツール対応表（GitHubのみ）

| Provider関数（CLI経路） | MCPツール | 引数 | 補足 |
|---|---|---|---|
| `get_issue <n>` | `mcp__github__issue_read` | `method="get"`, `owner`, `repo`, `issue_number=<n>` | 返却JSONの `title`/`body`/`html_url` を、CLI版の `title`/`body`/`url` と読み替える |
| `new_issue <title> <body>` | `mcp__github__issue_write` | `method="create"`, `owner`, `repo`, `title`, `body` | `issue-create` スキル（`create-issue.sh`）の代替。本文は `build_issue_body` 相当の4見出しで組み立てる |
| `search_issues <キーワード...>` | `mcp__github__search_issues` | `query="<キーワード（複数可）>"`, `owner`, `repo` | `issue-create` スキルの起票前重複チェック（issue #68）の代替。**CLI版と違い、キーワードごとに呼び分ける必要はない**（自然言語のセマンティック検索で、既に `is:issue` にスコープされている）。1回の `query` に複数キーワードを平文で並べる。closedのissueも対象にしたいので `state` で絞り込まないこと。返却の `number`/`title`/`state`/`html_url` を、CLI版の `number`/`title`/`state`/`url` と読み替える |
| `new_draft_merge_request <n> <branch> <title> [<base>]` | `mcp__github__create_pull_request` | `owner`, `repo`, `title`, `head=<branch>`, `base=<base>`, `draft=true`, `body="Closes #<n>\n\n(plan作成中。/issue-mr-flow describe で更新する)"` | baseとの差分が無いと失敗する制約はMCP経路でも同じ。失敗したら `source .claude/scripts/src/vcs/Provider.sh && add_empty_commit_for_draft_mr` を実行してから1回だけ再試行する |
| `get_mr_for_branch <branch>` | `mcp__github__list_pull_requests` | `owner`, `repo`, `head="<owner>:<branch>"`, `state="open"` | 結果が空配列ならPRなし。`number`/`html_url`/`draft`/`title` を使う |
| `get_mr_unresolved_comments <n> [true]` | `mcp__github__pull_request_read` | `method="get_review_comments"`, `owner`, `repo`, `pullNumber=<n>` | スレッドごとに `isResolved` が付くので、**既定では `isResolved=false` のスレッドだけを提示する**（CLI版の「解決済みは機械的に除外」に相当）。`all` 指定時は全件。通常コメントは `method="get_comments"` を追加で呼ぶ。**コメントのパーマリンク（CLI版の `url=...`）は返却JSONの `html_url` を使う**（issue #42）。**このツールは `line` も commitのsha も返さないため、CLI版が付ける指摘行前後のソーススライスは作れない**（`path` までは分かる。実測で確認。GitHub MCPサーバー側の制約であり本機構では変えられない。issue #43）。指摘箇所のコードが必要なら、`path` を頼りにReadツール等で**現在のファイル**を読む——**それは断面ではなく現HEADである**点に注意する。**ページネーションの罠は下記「2-b. MCP経路で踏んだ落とし穴」参照** |
| `add_mr_thread_reply <n> <threadId> <body>` | `mcp__github__add_reply_to_pull_request_comment` | `owner`, `repo`, `pullNumber=<n>`, `commentId=<返信先スレッドの先頭コメントの数値ID>`, `body` | **ID体系が違う。** CLI経路はGraphQLのthreadId（`PRRT_...`）を使うが、MCP経路は数値のcommentId（`#discussion_r...` の数字部分）を使う。`get_review_comments` の各スレッドに含まれるコメントのidを使うこと。**投稿した返信のURL（CLI版の戻り値）は、返却JSONの `html_url` を使う**（issue #42） |
| `set_mr_description <n> <file>` | `mcp__github__update_pull_request` | `owner`, `repo`, `pullNumber=<n>`, `body=<ファイルの内容>` | CLI版はファイルパスを渡すが、MCPは文字列で渡す。本文はReadツール等で読んでから渡す |
| `set_mr_ready <n>` | `mcp__github__update_pull_request` | `owner`, `repo`, `pullNumber=<n>`, `draft=false` | `set_mr_description` と同じツールだが渡す引数が違う。`draft=false` が「Draftを解除しレビュー可能にする」の意味（flow-id 5-6。issue #61） |
| `add_mr_comment <n> <file>` | `mcp__github__add_issue_comment` | `owner`, `repo`, `issue_number=<PR番号>`, `body=<ファイルの内容>` | PR番号を `issue_number` に渡す（GitHub APIの仕様上、PRもissueとして扱える） |
| `add_mr_inline_comments <n> <file>` | `mcp__github__pull_request_review_write` | `method="create"` → 指摘ごとに `method="add_comment_to_pending_review"`（`owner`, `repo`, `pullNumber`, `path`, `line`, `side`, `body`）→ `method="submit_pending"`（`event="COMMENT"`） | 敵対的レビュー（issue #77）のインライン投稿。**3段構成で、`submit_pending` まで必ず実行する**（pendingのまま放置すると次回の `create` が失敗し続ける）。途中で失敗したら `method="delete_pending"` で片付ける。CLI版と違い有効行の事前検証が入らないため、diffに含まれない行を指定すると個別に失敗する |
| `add_issue_comment <n> <file>` | `mcp__github__add_issue_comment` | `owner`, `repo`, `issue_number=<通知先のissue番号>`, `body=<ファイルの内容>` | **`add_mr_comment` と同じツールだが、`issue_number` へ渡すのがPR番号ではなく通知先のissue番号である**（flow-id 5-2の関連issue通知。issue #86）。CLI版はファイルパスを渡すが、MCPは文字列で渡すため本文はReadツール等で読んでから渡す |
| `upload_attachment <file> [<content_type>]` | **代替なし** | — | flow-id 5-4 の**層3（統括レポートHTMLの添付）**（issue #111）。**MCPにPR/issueへの添付に相当するツールは無い**（実測で確認）。この関数は `require_vcs_cli` により非0で終え、stderrへ「層3はスキップしてよい」旨を出す。**層1（`wip/reports/` をリモートへ反映）と層2（`add_mr_comment` でのサマリ投稿）だけでレビューは成立するため、スキップして次へ進む** |
| `get_repo_url` | （MCP不要） | — | `git remote get-url origin` の正規化だけでリポジトリの正規URLを導出するプロバイダ非依存の関数のため、MCP経路でもそのまま呼べる（`get_mr_diff_url` / `get_mr_diff_since_url` も同様。issue #44） |
| `new_issue_branch` / `sync_branch` / `get_branch_work_files` / `get_issue_number_from_branch` / `to_slug` / `test_issue_sections` | （MCP不要） | — | git操作・純粋ロジックのみでCLIに依存しないため、MCP経路でもそのまま呼べる |

### 2-b. MCP経路で踏んだ落とし穴

CLI経路には無い、MCPツール固有の挙動。**いずれも失敗ではなく成功として返るため、呼び出し側で
確認しないと気づけない。**

- **`mcp__github__add_reply_to_pull_request_comment` は、`body` に不等号で始まる語が含まれると
  そこで本文を切り捨てて投稿する**（issue #53 の作業中に実測。入力リダイレクトの記号を含む語を
  書いたところ、その手前で本文が終わった状態で投稿された）。**エラーは返らず、`id` と `url` を
  含む正常な結果が返る。**
  - 対処: 投稿後に `mcp__github__pull_request_read`（`method="get_review_comments"`）で
    **本文の末尾を確認する**。切れていたら、記号を避けて書き直した補足を追加で投稿する
    （既に投稿したコメントは編集できないため、消すのではなく足す）。
  - 予防: 本文に記号そのものを書かず、「入力リダイレクト」のように語で説明する。
    コード例が要る場合はフェンス内へ入れる。

- **`mcp__github__pull_request_read`（`method="get_review_comments"`）のページネーション
  パラメータ名は `after`（前ページの `pageInfo.endCursor` の値。`perPage` は最大100、
  ツール定義で確認済みの値）であり `cursor` ではない**（issue #105フェーズ3で実際に2回踏んだ）。
  **`after` 以外のページ送りパラメータを渡すと、ツールがそれを無視して常に1ページ目を返す**
  ため、`hasNextPage: true` のまま同一ページが返り続ける（無限ループ状のハングに見えるため
  気づきにくい）。
  - **「誤ったパラメータ名だから無視される」のではない**（issue #17 で実際に誤読した）。
    このツールは **`page` という正当なパラメータをツール定義に持っており**、
    `perPage` と組み合わせて渡しても**やはり1ページ目が返る**。`page` は
    `get_review_comments` **以外**のメソッド（`get_files` / `get_commits` / `get_reviews` /
    `get_comments`）のためのもので、`get_review_comments` だけがカーソル方式である。
    **ツール定義に載っているパラメータが、そのメソッドで効くとは限らない。**
  - つまり判定材料は「名前が正しいか」ではなく「**そのメソッドがカーソル方式か**」である。
    `get_review_comments` のときだけ `after` を使う。
  - 対処: `after` に前ページの `pageInfo.endCursor` を渡し、`pageInfo.hasNextPage` が偽に
    なるまで繰り返す。
  - 予防: 未返信スレッドの判定（`references/review-loop.md`「レビュー完了合図の確認」
    (1)(2)）は、**全ページを走査できていることが前提**。1ページ目だけで判定を打ち切ると、
    未解決・未返信スレッドを取りこぼしたままループ範囲へ `mark-done` してしまいうる
    （issue #70・#109が防ごうとした状態そのもの）。

### 3. サブコマンドごとの読み替え

| サブコマンド | MCP経路での差分 |
|---|---|
| `start <n>` | 手順1の `get_issue` を `mcp__github__issue_read` に置き換える。`test_issue_sections` はbody文字列を渡せばそのまま使える。手順2のブランチ検索（`git branch --list` / `git ls-remote`）と `new_issue_branch` は変更なし。Draft PR作成のみ `mcp__github__create_pull_request` に置き換える |
| `comments [all]` | MR番号の取得を `mcp__github__list_pull_requests`、コメント取得を `mcp__github__pull_request_read` に置き換える。**未解決のみを既定で提示する絞り込みは、CLI版ではスクリプトが行っていた処理なので、MCP経路では自分で `isResolved` を見て行う。** コメントのパーマリンクは `html_url` から取る（issue #42）。手順6（チャット由来の判断の記録）の `add_mr_comment` は `mcp__github__add_issue_comment` に置き換える。**MCPツールは `body` を文字列で受け取るため一時ファイルは不要だが、`Claude Codeより:` の署名行を先頭に付ける規約はMCP経路でも同じ**（issue #50）。**「レビュー完了合図の確認」(2) の未返信スレッドの判定は、CLI版の `[review ...]` 行の重複ではなく、各スレッドの `comments` 配列が1件かで行う**（issue #109） |
| `reply <threadId> <対応内容>` | 返信先の指定が数値のcommentIdになる（上表の補足参照）。**`Claude Codeより:` の署名行を先頭に付ける規約はMCP経路でも同じ**（MCPサーバーもユーザーの認証情報で動くため、投稿者は人間のアカウントとして表示される）。投稿後に返る `html_url` が返信のパーマリンクで、次のpushのレビュー依頼メッセージへ含める（issue #42） |
| `describe` | descriptionを一時ファイルへ書く手順は同じでよいが、最後は `mcp__github__update_pull_request` の `body` へ文字列として渡す |
| `sync` | 変更なし（git操作のみ） |
| `resume` | サブエージェント（`issue-mr-resume`）はProvider.sh経由でのCLI利用を前提とするため、MCP経路ではissue/PR情報の取得部分が失敗する。その場合はサブエージェントの報告のうちgit・ファイル系（ブランチ・wip/plans・wip/worklogs・HANDOFF.md）を採用し、issue/PR情報は呼び出し元が上表のMCPツールで補う |

### 4. hookの挙動（CLI不在時）

hookはMCPツールを呼べないため、以下のように非侵襲的に縮退する（詳細:
`.claude/docs/spec/issue-mr-workflow.md`）。エージェント側で肩代わりが必要なものはその旨が
メッセージに出る。

| hook | CLI不在時 |
|---|---|
| `session-start.sh` | issue/PR情報の代わりに「経路はMCP」「ブランチ名から抽出したissue番号」「owner/repo」「本節への参照」を注入する |
| `post-push-usage-report.sh` | 集計状態の更新のみ行い、対応工数レポートの自動投稿はスキップする（stderrへ1行） |
| `post-push-compact-prompt.sh` | MRリンクだけを「MCPで取得すること」に差し替え、レビュー依頼メッセージと `/compact` の呼びかけは従来どおり行う。重点レビュー対象ファイルのリンク（issue #42）は `get_repo_url` のローカル組み立てとgit操作だけで作れるため、CLI不在時もそのまま供給される |
| `post-issue-create-notice.sh` | 縮退しない。CLI経路（`create-issue.sh` の実行）に加えMCP経路（`mcp__github__issue_write` の `method="create"`）も検知するため、CLI不在時も同じ注意喚起が出る（issue #39） |

### 5. GitLabは対象外

`glab` 不在時のGitLab向けMCP代替は**対象外**とする（このリポジトリでGitLab MCPサーバーの
利用実績が無く、ツール名・引数を検証できないため。未検証の対応表は誤誘導になりうる）。
GitLabリポジトリで `glab` が無い場合、`require_vcs_cli` はその旨を明示して失敗する。
`glab` をインストール・認証して使うこと。将来GitLab MCPサーバーを実機検証できた時点で、
本節に同じ形式の対応表を追加してよい（DDR i0034-01）。
