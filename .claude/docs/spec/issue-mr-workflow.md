---
title: issue駆動MRワークフロー支援
type: spec
description: AIエージェントがissue起点で開発を進める際の定型作業（issue取得・ブランチ/MR作成・レビュー往復等）を支援する仕組みの仕様
tags: [issue-mr-flow, workflow, spec]
keywords: [provider-sh, github連携, gitlab連携, セッション開始hook, 使用量集計, draft-pr, 途中引き継ぎ]
---

# issue駆動MRワークフロー支援

## 背景・目的

AIエージェント（Claude Code）がissueを起点に開発を進める際、以下の定型作業を毎回人手で組み立てているとコストが高い。

- issueの内容取得
- ブランチ・MR（Pull Request / Merge Request）の作成
- plan〜レビュー往復（人間のコメント取得→plan修正）の繰り返し
- 作業内容に応じたMR descriptionの更新
- 設計反映（`plans/` `worklog/` の内容を `docs/spec/` `docs/ddr/` へ反映）後のクリーンアップ

これをGitHub・GitLabどちらのリポジトリでも同じ手順で回せるように、ステップ単位で呼び出す
Claude Codeスキルと、その裏側でGitHub/GitLabの差異を吸収するスクリプト群を整備する。

当初は「既存の実装フロー（`docs-workflow.md`, `git-workflow.md`）を踏襲し、本機能はその起点と
MRとのやり取りだけを自動化する薄い層」として設計したが、PR #4のレビューを経て方針を変更した。
`docs-workflow.md` の「実装フロー（必須）」と `git-workflow.md` の手順（ブランチ運用・worklogと
設計反映・PR・マージ）の**順序立ったフロー部分**を `.claude/skills/issue-mr-flow/SKILL.md` に統合し、
そちらを**唯一の実装フロー定義**とした。今後はごく小さな変更を除くあらゆるタスクをissue起点で
進める前提とする。`docs-workflow.md` / `git-workflow.md` はドキュメントの置き場所・ライフサイクルや
ブランチ命名規則といった参照情報のみを残す。詳細は
[.claude/scripts/docs/ddr/0002-issue-mr-flowへの実装フロー統合.md](../ddr/0002-issue-mr-flowへの実装フロー統合.md) 参照。

## 仕様

### 実行モデル

ユーザー要望どおり、ステップ単位のスラッシュコマンド（Claude Codeスキル）として提供する。
常駐エージェントによる自動ポーリング・自動承認は行わない。各ステップは人間が意図したタイミングで
明示的に呼び出す（「合意まで繰り返す」の終了判定＝レビューを打ち切って次工程に進む判断は、常に人間が行う）。

### コンポーネント構成

```
.mrworkflow.json                    # リポジトリ固有設定（他リポジトリへ移植する際はこれだけ差し替える）
.github/ISSUE_TEMPLATE/
└── task.md                         # GitHub用issueテンプレート（目的・現状・期待する動作・受け入れ条件）
.gitlab/issue_templates/
└── task.md                         # GitLab用issueテンプレート（同上）
.claude/scripts/src/vcs/
├── Provider.sh                     # git remote からGitHub/GitLabを判定し、共通関数をディスパッチ
├── Github.sh                       # gh CLIラッパー
└── Gitlab.sh                       # glab CLIラッパー
.claude/skills/issue-mr-flow/
└── SKILL.md                        # ステップ実行のオーケストレーション手順書
.claude/agents/
└── issue-mr-resume.md              # 途中引き継ぎ用の状態調査サブエージェント（resumeから起動）
.claude/hooks/
├── session-start.sh                 # セッション開始時のissue/MR状態自動注入（SessionStart hook）
├── post-push-usage-report.sh        # git push検知時のトークン使用量集計＋MR自動コメント投稿（PostToolUse hook）
├── post-push-compact-prompt.sh      # git push検知時に/compact実施を促すメッセージ注入（PostToolUse hook）
└── lib/
    └── UsageTracking.sh              # 集計ロジック（sync_usage_state）
```

上記は全てbash製（`.sh`）。issue #6でPowerShell版（`.ps1`）から移行し、issue #24で
`dev-tools/`（AI・人間共用の開発補助ツール置き場）から`.claude/scripts/`（AI専用スクリプト置き場）へ
移動した。設計方針・移行の経緯・git bash特有の注意点は [shell-scripts.md](shell-scripts.md) を参照。

- **`Provider.sh`**: `git remote get-url origin` から**ホスト部を抽出**してプロバイダを判定し、
  共通インターフェース関数を `Github.sh` / `Gitlab.sh` の対応関数へディスパッチする。呼び出し側
  （スキル・他スクリプト）はプロバイダを意識しない。関数はJSON文字列をstdoutへ出力し、呼び出し側は
  `jq` でフィールドを取り出す設計（例: `get_issue 6 | jq -r '.title'`）。
  判定規則は「ホスト名に `aslead` を含めばGitLab（社内GitLabの明示ケース）、`github` を含めばGitHub、
  それ以外はGitLab」で、ホスト抽出と判定は純粋関数 `provider_from_remote_url` に切り出してある
  （`get_provider` はその薄いラッパー）。**判定は `gh`/`glab` の認証状態に依存しない**。
  詳細・却下案は
  [0028-プロバイダ判定はremote-URLのホスト部でgithub以外をgitlabとみなす.md](../ddr/0028-プロバイダ判定はremote-URLのホスト部でgithub以外をgitlabとみなす.md)
  参照（issue #45。それ以前はURL文字列全体への部分一致だったため、ホスト名に `gitlab` を含まない
  self-hosted GitLabを弾いていた）。
- **`.mrworkflow.json`**（リポジトリ直下、Git管理下）: ブランチ命名規則やパス（`plans/` 等）など
  プロジェクト固有の値を切り出す。他リポジトリへ移植する場合はこのファイルの値を書き換えるだけで済む
  ようにする。
- **`.claude/skills/issue-mr-flow/SKILL.md`**: issue起票からマージまでの**唯一の実装フロー定義**。
  現在のブランチ・issue番号・`plans/` `worklog/` `reports/` の有無・MRの有無などから「今どの段階か」を判定し、
  次に何をすべきかをAIエージェントに指示する。実処理は `Provider.sh` 経由のスクリプト呼び出しに
  委譲

### 提供関数（`Provider.sh` 経由の共通インターフェース）

| 関数 | 内容 | GitHub実装 | GitLab実装 |
|---|---|---|---|
| `get_issue <n>` | issueのtitle/body/labelsを取得（JSON） | `gh issue view` | `glab issue view` |
| `new_issue_branch <n> <slugSource> [<base>]` | `<branchPrefixTemplate>` に従いブランチを作成しcheckout、リモートpush。`<slugSource>` はslug化対象のテキストであり、生issueタイトルである必要はない（`.claude/skills/issue-mr-flow/SKILL.md` の `start` サブコマンドではAIエージェントが生成した英語の意訳フレーズを渡す。詳細: [0010-ブランチslugの意訳生成はAIエージェントが行う.md](../ddr/0010-ブランチslugの意訳生成はAIエージェントが行う.md)）。`<base>`（省略可）でベースブランチを上書きできる。省略時は `.mrworkflow.json` の `defaultBaseBranch` を使う（issue #15: `start` サブコマンドが `AskUserQuestion` で確認した結果を渡す） | `git switch -c` + `git push` | 同左 |
| `new_draft_merge_request <n> <branch> <title> [<base>]` | issueに紐づくDraft PR/MRを作成（bodyは仮テンプレート、後続の `set_mr_description` で上書き前提。`<title>` はissueタイトルをそのまま渡す） | `gh pr create --draft` | `glab mr create --draft` |
| `get_mr_unresolved_comments <n> [true]` | レビューコメント／スレッドを取得しテキストへ整形（スレッドID・ファイルパス・行番号・diffを含む）。既定（第2引数省略）では未解決のスレッドのみを返し、対応済み（解決済み）スレッドは機械的に除外する。第2引数に `true` を渡すと解決済みも含めた全件を返す。GitLabはdiscussions APIが操作履歴を `system: true` のnoteとして同じ配列で返すため、これも機械的に除外する（issue #48） | `gh api graphql` (review threads) | `glab api` (discussions) |
| `add_mr_thread_reply <n> <threadId> <text>` | 指定スレッドに対応内容を返信する（スレッドの解決＝resolvedはレビュアー側の操作のため本関数では行わない） | `gh api graphql`（reply mutation） | `glab api`（note追加） |
| `set_mr_description <n> <bodyFile>` | PR/MRのdescriptionを指定ファイル内容で上書き | `gh pr edit --body-file` | `glab mr update --description` |
| `set_mr_ready <n>` | Draft PR/MRのDraft状態を解除し、レビュー・マージ可能な状態にする（全体フロー flow-id 5-3。Draft作成側の `new_draft_merge_request` に対応する解除側。issue #61） | `gh pr ready` | `glab mr update --ready` |
| `add_mr_comment <n> <bodyFile>` | PR/MRへ新規コメントを1件投稿（スレッド返信・レビューではない通常コメント） | `gh pr comment --body-file` | `glab api`（notes追加） |
| `sync_branch <branch>` | 現在のブランチをfetch、必要ならcheckout（新しいセッションでの再開用） | `git fetch` + `git checkout` | 同左 |
| `test_issue_sections <body>` | issue本文に「目的／現状／期待する動作／受け入れ条件」の4見出しが揃っているか確認し、欠けている見出し名を1行1件でstdoutへ出力する（プロバイダ非依存） | — | — |
| `get_issue_number_from_branch [<branch>]` | ブランチ名を `branchPrefixTemplate` に照らしてissue番号を抽出する（省略時は現在のブランチ）。マッチすればstdoutへ出力し終了コード0、マッチしなければ終了コード1（プロバイダ非依存） | — | — |
| `get_mr_for_branch <branch>` | 指定ブランチに紐づくPR/MRの番号・URL・タイトル・Draft状態を取得する（JSON。無ければ何も出力せず終了コード0） | `gh pr view <branch>` | `glab mr view <branch>` |
| `get_repo_url` | リポジトリの正規URL（フルパス）を取得する。MR/PRのURL文字列からの推測ではなく`gh`/`glab`で取得することで正確性を担保する（issue #13フォローアップ） | `gh repo view --json url` | `glab repo view --output json`（`.web_url`） |
| `get_mr_diff_url <repoUrl> <baseBranch> <headBranch>` | MR/PRの「defaultブランチとの差分」を見れるURLを組み立てる（純粋関数。`repoUrl`は`get_repo_url`の戻り値を渡す。issue #13） | `<repoUrl>/compare/<baseBranch>...<headBranch>` | `<repoUrl>/-/compare/<baseBranch>...<headBranch>` |
| `get_mr_diff_since_url <repoUrl> <fromSha> <toSha>` | MR/PRの「前回push時点(`fromSha`)から今回push時点(`toSha`)までの差分」を見れるURLを組み立てる（純粋関数。issue #13） | `<repoUrl>/compare/<fromSha>...<toSha>` | `<repoUrl>/-/compare/<fromSha>...<toSha>` |
| `get_branch_work_files` | 現在のブランチ固有（`<defaultBaseBranch>` に無い）の `plans/` `worklog/` `reports/` ファイル一覧を返す（プロバイダ非依存）。日本語を含むパスをそのまま返すため `-c core.quotepath=false` を指定している（issue #9。詳細は「計画の2階層構造」節） | — | — |
| `build_issue_body <purpose> <current> <expected> <acceptance>` | 標準4見出し（目的・現状・期待する動作・受け入れ条件）に沿ってissue本文を組み立てる（プロバイダ非依存。issue #25） | — | — |
| `new_issue <title> <body>` | タイトル・本文からissueを新規作成し、`get_issue`と同じ形（number/title/body/url/slug）のJSONを返す（issue #25） | `gh issue create` → URLから番号抽出 → `github_get_issue` | `glab issue create` → URLから番号抽出 → `gitlab_get_issue` |
| `search_issues <キーワード...>` | キーワードで既存issueを検索し `[{number, title, state, url}]` のJSON配列を返す（起票前の重複チェック用。issue #68）。**closedも対象**。キーワードごとに1回ずつ検索して統合する（最大5キーワード。超過分は標準エラーへ通知して切り捨て）。`state` は `open`/`closed` へ正規化する | `gh issue list --search`（キーワードごと） | `glab issue list --search`（キーワードごと） |
| `get_vcs_access_mode` | 実行環境に該当プロバイダのCLIがあるかを判定し、`cli`（CLI経路）／`mcp`（MCPフォールバック経路）を返す（issue #34） | `command -v gh` | `command -v glab` |
| `parse_repo_slug <remoteUrl>` | リモートURL（https / ssh(scp形式) / `ssh://`）から `{host, owner, repo, path, url}` のJSONを組み立てる（純粋関数。MCPツールが要求する `owner`/`repo` をCLIなしで得るため。issue #34） | — | — |
| `get_repo_slug` | `git remote get-url origin` の値を `parse_repo_slug` へ渡す（issue #34） | — | — |
| `mcp_tool_hint <funcName>` | Provider関数名に対応するGitHub MCPツールと主な引数を1行で返す（GitLabは対象外である旨を返す。issue #34） | — | — |
| `require_vcs_cli <funcName>` | CLI経路が使えない場合に、代替すべきMCPツールを名指ししたメッセージをstderrへ出して終了コード1を返す。プロバイダ依存の各関数の先頭で呼ぶ（issue #34） | — | — |

上表は `Provider.sh` 経由で公開する共通インターフェースであり、プロバイダ固有ファイル
（`Github.sh` / `Gitlab.sh`）の内部ヘルパーは含まない。issue #48で追加した
`gitlab_format_discussion_notes`（discussions APIのJSONを受け取り整形済みテキストを返す純粋関数）は
後者にあたる。`gitlab_get_mr_unresolved_comments` は `glab api` 呼び出しとこの関数の薄いラッパーで、
外部コマンドを呼ばない整形ロジックだけを切り離すことで `.claude/scripts/test/test_vcs_provider.sh` から
単体テストできるようにしている（`.claude/rules/shell-script-style.md`「テスト」）。
issue #45で追加した `provider_from_remote_url`（remote URL文字列からプロバイダ名を返す純粋関数）も
同じ位置づけで、`Provider.sh` 内にあるが上表には載らない。`get_provider` が
`git remote get-url origin` の結果をこの関数へ渡すだけの薄いラッパーになっており、切り出しの目的も
上と同じく単体テスト可能にすることである。ホスト部の抽出そのものは、issue #55以降は次の
`split_remote_url` へ委譲している。

issue #55で追加した `split_remote_url <remoteUrl>` も同じく上表に載らない内部ヘルパーで、remote URLを
**ホスト部とパス部へ分解する**パラメータ展開のみの純粋関数である。`provider_from_remote_url`
（ホスト部のみ使用）と `parse_repo_slug`（両方を使用）が、共通の土台としてこれを呼ぶ。それ以前は
scheme除去・認証情報（`user@`）除去・ポート除去・scp形式（`git@host:path`）対応という同じ規則が、
前者ではパラメータ展開・後者では `sed` 2回という**別々の方法で二重に実装**されており、片方だけ直すと
もう片方とずれる状態だった（issue #34とissue #45が並行して進んだ結果生まれた重複）。
この関数には次の2つの設計上の制約がある。

- **結果を標準出力ではなくグローバル変数 `REPLY_HOST` / `REPLY_PATH` へ返す。** 標準出力にすると
  呼び出し側がコマンド置換を強いられ、`provider_from_remote_url` の「1回あたりのプロセス起動ゼロ」
  （DDR 0028の制約。12個のディスパッチャが `case "$(get_provider)" in` の形で呼ぶためメモ化が
  効かない）を壊してしまう。**関数呼び出しはコマンド置換ではないため、これで起動数は増えない。**
  返す値が2つあるため `REPLY` ではなく2変数に分けている
  （`.claude/rules/shell-script-style.md`「ホットパスの小さなヘルパー関数は…`REPLY` へ返す」）。
- **ホスト名が取れなくても失敗させない。** エラーとするかは呼び出し側の判断に委ねる。これにより
  `provider_from_remote_url`（ホストが空なら終了コード1）と `parse_repo_slug`（空のままJSONを返す）
  それぞれの従来の振る舞いを変えずに共通化できている。

scp形式（`git@host:o/r.git`）とポート付きURL（`host:2222/o/r.git`）の区別は、`:` の後ろが
**数字だけかどうか**で行う。これがパラメータ展開だけで書ける唯一の分岐点である。

issue #68で追加した3つの関数も同じく内部ヘルパーである。`github_normalize_issue_search_results` /
`gitlab_normalize_issue_search_results`（`gh issue list --json` / `glab issue list --output json` の
出力を共通形式 `{number, title, state, url}` へ正規化する）はプロバイダ固有ファイル側に、
`merge_issue_search_results`（複数キーワードぶんの検索結果を `number` で重複排除し番号の降順で
統合する）は `Provider.sh` 側にある。いずれも `gh`/`glab` を呼ばずjqだけで完結するため、
`gitlab_format_discussion_notes` と同じ理由で切り出して単体テストの対象にしている。公開されているのは
`search_issues` の方である。

**`Provider.sh` 内の関数がすべて公開インターフェースとは限らない点に注意する。** 上表に載るのは
呼び出し側（スキル・他スクリプト）が直接使う関数のみで、`provider_from_remote_url` のように
`Provider.sh` にありながら内部実装であるものも、`github_get_compare_url` / `gitlab_get_compare_url`
のようにプロバイダ固有ファイル側の内部ヘルパーとしてのみ存在し `Provider.sh` にディスパッチャを
持たないものもある（後者について公開されているのは `get_mr_diff_url` /
`get_mr_diff_since_url` の方であり、これは意図した設計である）。

### 全体フロー

issue起票からマージまでの詳細な手順（担当・順序）は
[.claude/skills/issue-mr-flow/SKILL.md](../../skills/issue-mr-flow/SKILL.md)（唯一の実装フロー定義）
に一本化した。本specとの内容重複・ドリフトを避けるため、ここでは表を持たない
（詳細は[0002-issue-mr-flowへの実装フロー統合.md](../ddr/0002-issue-mr-flowへの実装フロー統合.md)参照）。

`/issue-mr-flow` のサブコマンドは `start` `comments` `reply` `describe` `sync` `resume` の6つに絞り、
設計ドキュメント作成・plan作成・実装・設計反映・AIアセット反映そのものは
`.claude/skills/issue-mr-flow/SKILL.md` の該当ステップに委ねる。

### 計画の2階層構造（issue #9）

Claude Code / Gemini CLI は**セッションごとに1つのplanファイルしか割り当てない**
（`.claude/settings.json` の `plansDirectory`、`.gemini/settings.json` の `general.plan.directory`。
いずれも `./plans` を指す）。従来のフローは調査計画と作業計画の2箇所でPlanモードを使う設計だった
ため、同一セッションで作業すると2つ目の計画が1つ目のファイルへ書き込まれ、計画が混ざっていた。

この構造的な衝突を解消するため、計画を2階層に分離した。

| 種類 | 作り方 | ファイル名 | 単位 |
|---|---|---|---|
| **全体作業計画** | **planツール**（Planモード）で作成 | ハーネス提示パス `plans/<自動命名>.md` | **issue（ブランチ）につき1回**（flow-id 1-4） |
| **個別調査計画／個別作業計画／個別反映計画** | **planツールを使わない**（Write/Editで直接作成） | `plans/【種別】タスク内容.md` | フェーズ2・3・4ごと・必要な数だけ（flow-id 2-1・3-1・4-1） |

- **タスク種別**は `【調査】` `【設計】` `【実装】` `【テスト】` `【設計反映】` `【AIアセット反映】`
  の6種。1ファイルへの複数併記を認める。併記するか分けるかの判断基準は
  「その計画に対して人間の合意を1回で取るか、フェーズごとに分けて取るか」であり、迷ったら分ける
  （詳細: `.claude/skills/issue-mr-flow/SKILL.md`「種別を複数併記する場合／分ける場合」）。
- **囲み文字は全角 `【】` を使う**。ASCIIの `[]` はbashのglobで**文字クラス**として解釈されるため、
  `plans/[調査]*.md` が意図どおりマッチしない（実機確認済み）。全角はglob特殊文字ではないため、
  未クォートでも正しくマッチする。
- **`plans/【*.md` で下位の個別計画（調査・作業・反映）のみを機械的に列挙でき、それ以外が全体作業計画**になる。
  この区別を、flow-id 1-4 の「既に全体作業計画があるか」の判定に使う。
- **全体作業計画が既にあればPlanモードで新規作成しない**。新しいセッションではハーネスが新しい
  planファイルパスを提示するため、これを規定しないとセッションを跨ぐたびに全体作業計画が増える。
  `"defaultMode": "plan"` により新セッションは必ずPlanモードで始まるが、それは新規作成の理由に
  ならない。
- これに伴い全体フローの先頭に全体作業計画の作成・合意を追加した（issue #9時点では33→35ステップ。
  現在のflow-idは `<フェーズ番号>-<ステップ番号>` 形式の5フェーズ・40ステップで、最新の定義は
  `.claude/skills/issue-mr-flow/SKILL.md`「全体フロー」を正とする）。worklogは
  `worklog/日付_<全体計画名>_<個別計画名>_push<N>.md`、reportsは
  `reports/日付_<全体計画名>_<内容を簡潔に>.html` へ命名を変更し、reportsは調査結果専用ではなく
  設計・実装・AIアセット反映等の報告にも使える位置づけへ拡張した。
- **廃止**: 従来のre-entry対策（`.claude/rules/plan-mode-safety.md` 規則6、
  `archive-reentrant-plan.sh`）は、planツールの利用が1回に限定されたことで不要になったため削除した。
  経緯・却下案は
  [0019-planツール利用を全体作業計画に限定し個別計画をファイル分離する.md](../ddr/0019-planツール利用を全体作業計画に限定し個別計画をファイル分離する.md)
  を参照。

**日本語ファイル名を扱う際の注意（`core.quotepath`）**: gitは既定（`core.quotepath=true`）で
非ASCII文字を含むパスを8進エスケープ＋ダブルクォートで囲んで出力する。`get_branch_work_files` は
`git diff --name-only` / `git status --porcelain` の行単位出力を使うため、**`-c core.quotepath=false`
の明示指定が必要**（指定しないと戻り値が使えない文字列になり `resume` が機能しない）。
`git ls-files -z` のようなNUL区切り出力は元から影響を受けない（実装例:
`.claude/scripts/src/extract-frontmatter.sh`）。

### レビューコメントへの返信

対応が完了したレビューコメントに対して、対応内容を返信する。スレッドの解決（resolved）は
レビュアー側が行う操作のため、本機能では行わない。

- `add_mr_thread_reply <n> <threadId> <text>` で、指定スレッドへ対応内容を
  返信する。`threadId` は `get_mr_unresolved_comments` の出力に含まれるスレッドIDを使う。
- `get_mr_unresolved_comments` は既定（第2引数省略）で未解決スレッドのみを返す（レビュアーが
  解決済みにしたものは機械的に除外される）。再確認等で解決済みも含めた全件が必要な場合は
  第2引数に `true` を指定する。
- `/issue-mr-flow` 側では、`comments` サブコマンドに `all` 引数を追加して `true` を
  指定できるようにし、対応完了時に呼ぶ `reply <threadId> <対応内容>` サブコマンドを新設する。
- **完了合図の確認**: 人間から「レビューOK」等の完了合図を受けても、それだけを根拠に次のステップへ
  進まない。`comments all`（`get_mr_unresolved_comments <n> true`）で全スレッドを再取得し、`unresolved` が残っていれば
  人間に再確認を取ってから次に進む（`reply` は返信のみで解決は行わないため、返信済みでも
  `unresolved` のまま残ることがある）。詳細は `.claude/skills/issue-mr-flow/SKILL.md` の
  「レビュー完了合図の確認」節を参照。

### 途中引き継ぎ対応（resume）

`start <issue番号>` / `sync <branch>` はどちらも「このセッションで既に現在地確認が済んでいる」
ことが前提のコマンドであり、別の人（別セッション）が途中から作業を引き継ぐ場合、AIエージェント
自身が「今どのissue／ブランチ／PRの、どの段階か」を特定する手段が無かった（PR #4レビュー指摘）。
`git branch --show-current` でブランチ名自体は機械的に取得できてしまうため、「情報の既知・未知」
を発動条件にすると読み手によって解釈がぶれる（実際に、ブランチ名が判明していることを理由に
resumeを省略してしまう事故が発生した）。そのため発動条件は「このセッションで現在地確認
（`resume`/`start`）を済ませたか」という機械的な基準で判定する。

`resume`（引数なし）は、専用サブエージェント `.claude/agents/issue-mr-resume.md` を起動し、
現在チェックアウトされているブランチだけを手がかりに以下を機械的に収集・報告させる
（情報収集・突き合わせは調査作業であり、その過程（試行錯誤・大量の生ログ）でメイン会話の
コンテキストを汚さないよう、読み取り専用の別エージェントに分離する）。

1. `git branch --show-current` で現在のブランチ名を取得する（`<defaultBaseBranch>` 上、または
   ブランチが特定できない場合は、その旨を伝えて `start <issue番号>` を促し終了する）。
2. `get_issue_number_from_branch` でブランチ名からissue番号を抽出し、`get_issue` でissue内容を取得する
   （抽出できなければ「命名規則に一致しないブランチです」と警告しつつ以降を続行する）。
3. `get_mr_for_branch` で対応するPR/MRの有無・番号・URL・Draft状態を取得する。
4. PR/MRがあれば `get_mr_unresolved_comments <n> true` で全件取得し、未解決件数を集計する。
5. `get_branch_work_files` で、このブランチ固有の `plans/` `worklog/` `reports/` ファイルを列挙する
   （`<defaultBaseBranch>` との差分から求めるため、削除済み＝設計反映済みの判別にも使える）。
6. `HANDOFF.md` の内容を読む。
7. 1〜6を「現在地サマリ」としてまとめ、呼び出し元（メインのAIエージェント）に返す。**HANDOFF.mdの
   記述と実際の状態（PR有無・未解決コメント件数等）に矛盾があれば、それも指摘する**
   （例: HANDOFF.mdは「PR未作成」と書いてあるが実際はPRが存在する、等）。

呼び出し元は、このサマリをもとに全体フロー（5フェーズ・40ステップ）のうちどこから再開すべきかを判断し、
人間に提案する（この判断自体はサブエージェントの役割ではなく、呼び出し元が行う）。

`comments` / `describe` サブコマンドの「現在のブランチに紐づくMR番号を取得する」手順は、
重複実装を避けるため `get_mr_for_branch` に統一する。

### マージ後の取り残しクリーンアップ

人間がレビュー後にそのままMR/PRをマージするなど、flow-id 5-1（`plans/` `worklog/`の削除・
`HANDOFF.md`のリセット）の実施前にマージが完了してしまうことがある（issue #28, PR #29の
セッションで実際に発生）。この場合、タスク固有の`plans/`・`worklog/`ファイルと作業途中のままの
`HANDOFF.md`が`main`へ残ってしまい、`docs-workflow.md`の運用（`worklog/`はsquash mergeで
`main`に残さない設計）と矛盾する。

この状態に気づいた場合、`main`への直接コミットではなく、新しいクリーンアップ用ブランチと
PRで対処する（`main`はレビューを経ないままの直接変更を避ける対象のため）。issue番号を持たない
一回限りの対応のため、`.mrworkflow.json`のブランチ命名規則には従わず`chore/cleanup-<説明>`
のような名前を使ってよい。手順の詳細は
`.claude/skills/issue-mr-flow/SKILL.md`の「PRがflow-id 5-1実施前にマージされてしまった場合の対処」
節を参照。

### セッション開始時の自動コンテキスト注入（SessionStart hook）

`resume` は人間・AIエージェントが明示的に呼び出す必要があり、機械的に実行されない
（issue #5指摘）。これをClaude CodeのSessionStart hookとして自動化し、セッション開始・
resume・clear時に毎回、現在ブランチのissue/MR状態をコンテキストへ自動注入する。

- **コンポーネント**: `.claude/hooks/session-start.sh`（bash版。issue #6でPowerShell版から移行）＋
  `.claude/settings.json` の `hooks.SessionStart` 設定。
- **matcher**: `startup|resume|clear|compact`。`fork` は対象外（fork時は親セッションの
  コンテキストがそのまま引き継がれ、要約による情報欠落が起きないため）。`compact` は当初
  「コンテキスト圧縮のたびに`gh` API呼び出しが走るのを避ける」という理由で除外していたが、
  **compactは要約内容を指定できず、作業継続に必須の現在地が要約の精度次第で失われる**ため、
  issue #57 で追加した。除外理由の再評価（compactの発生頻度・MCP経路ではAPI呼び出しが
  そもそも発生しないこと）と却下案は
  [0032-compact後もSessionStart-hookで作業コンテキストを再注入する.md](../ddr/0032-compact後もSessionStart-hookで作業コンテキストを再注入する.md)
  参照。
- **実行シェル**: exec form（`args`指定）で `"bash"` を呼ぶ（フルパス直書きはしない。他環境への
  移植性を優先）。ただしこのマシンではPATHの優先順位次第で素の`"bash"`がWSL起動用スタブ
  （`C:\Windows\System32\bash.exe`）に解決されてしまうため、システム環境変数（`Machine`スコープ）
  の`Path`へgit bashの`bin`をSystem32より前に来る位置で追加するセットアップが別途必要
  （ユーザー環境変数に追加するだけでは効果が無い。詳細:
  [shell-scripts.md](shell-scripts.md)「Claude Code hookの起動コマンド」）。
- **サブエージェントでの抑止**: 公式ドキュメント上、SessionStart hookはTask tool経由の
  サブエージェント内でも発火する（`agent_id`/`agent_type`がstdin JSONに追加される場合のみ
  判別可能）。そのためmatcherでは実現できず、スクリプト冒頭でstdinの`agent_id`の有無を見て
  即終了する実装とした（受け入れ条件「サブエージェント起動時には実行されず」に対応）。
- **情報収集**: `resume`（`issue-mr-resume`サブエージェント）と同じ`Provider.sh`の関数
  （`get_issue_number_from_branch` / `get_issue` / `get_mr_for_branch` / `get_mr_unresolved_comments`）を
  再利用する。hookはサブエージェントを起動できないため、同種の情報収集ロジックを持つ独立スクリプト
  として実装した。表示内容は「ブランチ／issue／PR（Draft状態含む）／未解決レビューコメント件数」
  ＋「ブランチ固有の作業ファイル一覧（`get_branch_work_files`。**ファイル名のみ**）」
  ＋「`HANDOFF.md` の『## 次にやること』節」。**ファイルの中身は注入しない**（`HANDOFF.md` も
  「次にやること」節だけを抜き出し、全文・進捗表・「やったこと」等は含めない）。
  当初は後ろ2項目を`resume`の役割として除外していたが、compactをmatcherへ加えた際に
  「compactはセッション途中で自動的に起こり、その直後に`resume`が呼ばれる保証が無い」ため
  最小限の現在地はhook側が持つ必要があると判断し、issue #57 で追加した（範囲の線引き・却下案:
  [DDR 0032](../ddr/0032-compact後もSessionStart-hookで作業コンテキストを再注入する.md)）。
  この拡張は起動要因によらず常に行う（要因ごとに内容を分岐させない）。
- **出力形式**: `{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"<text>"}}`
  形式のJSONをstdoutへ返す。
- **フォールバック方針**: `main`ブランチ上（作業ブランチ未チェックアウト）では注入しない。
  `gh`未認証・API失敗等、情報収集に失敗した場合もセッション開始をブロックせず、短い失敗メッセージ
  のみを返す（best-effort。詳細な原因調査は人間が手動で行う）。作業ファイル一覧・`HANDOFF.md`
  抜粋の取得に失敗した場合は、**その行自体を出さずに他の項目の注入を続ける**（fail-open。
  追加項目の失敗がブランチ・issue・PR情報の注入を妨げてはならない）。
- **注入量の肥大化検知（issue #57）**: 組み立てた`additionalContext`の**バイト数**
  （文字数ではない。日本語はUTF-8で1文字3バイトのため3倍ずれる）を測り、しきい値
  `CONTEXT_SIZE_WARN_BYTES`（既定8000バイト。環境変数で上書き可能）を**超えた場合のみ**、
  末尾へ「ユーザーへ肥大化を警告し`HANDOFF.md`・`plans/`の整理を促すこと」という指示文を
  追記する。**切り詰めは行わず全量を注入する**（切り詰めると、この機構が守ろうとしている現在地
  そのものを失い、かつ失ったことがエージェント側から分からないため）。しきい値の根拠・
  却下案は[DDR 0032](../ddr/0032-compact後もSessionStart-hookで作業コンテキストを再注入する.md)参照。
- **構造とテスト（issue #57）**: 本体処理は`main`にまとめ、ファイル末尾の
  `[ "${BASH_SOURCE[0]}" = "${0}" ]` ガードで直接実行時のみ呼ぶ。これにより
  `.claude/scripts/test/test_session_start.sh` から`source`して、副作用の無い純粋関数
  （`context_text_bytes` / `append_size_warning` / `extract_handoff_next_steps`）を単体テストできる
  （ガードが無いと`source`時に`raw="$(cat)"`でstdin待ちのままハングする）。
- **`gh`/`glab` CLI自体が無い環境での挙動（issue #34）**: 上記の一般的な失敗と区別し、
  `get_vcs_access_mode` が `mcp` を返す場合は専用の内容を注入する。具体的には
  「VCS情報取得経路: MCP」「ブランチ名から抽出したissue番号（本文・タイトルはMCPで取得すること）」
  「MCPツールに渡す owner/repo」「`.claude/skills/issue-mr-flow/SKILL.md`『`gh`/`glab` CLI不在時の
  MCPフォールバック』節の参照とWebFetch・curlを使わない旨」の4点で、issue/PRの実データは取得しない
  （hookはMCPツールを呼べないため）。**PR欄は「なし」ではなく「未取得」と表現する**: 変更前は
  `gh` の失敗を握りつぶしていたため、PRが存在していても「PR: なし」と誤った情報が注入されていた。

### `gh`/`glab` CLI不在時のMCPフォールバック経路（issue #34）

Claude Code on the webのリモート実行環境のように、`gh`/`glab` CLIが存在せず `git`・`jq` しか
使えない実行環境がある（issue #21対応時に実機確認。issue #34対応時にも再確認）。`AGENTS.md` は
以前からこの場合にGitHub/GitLab公式のMCPサーバーツールで代替してよいと定めていたが、**具体的な
対応手順が実装・文書化されておらず、AIエージェントが都度その場の判断でツールを選ぶ状態**だった。

- **経路の判定**: `get_vcs_access_mode`（`cli` / `mcp`）。`.claude/skills/issue-mr-flow/SKILL.md`
  の各サブコマンドは、手順に入る前にこれを呼んで経路を決める。
- **手順の正**: Provider関数・サブコマンドごとのMCPツールと引数の対応表は
  `.claude/skills/issue-mr-flow/SKILL.md`「`gh`/`glab` CLI不在時のMCPフォールバック」節に置く
  （本specは仕組みの説明に留め、対応表を二重管理しない）。`issue-create` スキル
  （`create-issue.sh`）についても同スキル側に読み替え手順を書く。
- **機構的な誘導**: プロバイダ依存の8関数（`get_issue` / `new_issue` /
  `new_draft_merge_request` / `get_mr_unresolved_comments` / `add_mr_thread_reply` /
  `get_mr_for_branch` / `set_mr_description` / `add_mr_comment`）は先頭で `require_vcs_cli` を
  呼び、CLI不在時は「代替すべきMCPツール名と引数」「`get_repo_slug` で owner/repo を得る方法」
  「SKILL.mdの該当節」「WebFetch・curlへはフォールバックしないこと」をstderrへ出して失敗する。
  手順を読まずにCLI経路を呼んだ場合でも、同じ案内へ収束させることが狙い。
- **例外（`get_repo_url`）**: リモートURLの取得は `git remote get-url origin` というローカル操作で
  済むため、MCP経路では `get_repo_slug` から組み立てたURLを返す（失敗させない）。これにより
  `get_mr_diff_url` / `get_mr_diff_since_url` がMCP経路でも動作する。
- **hookの縮退**: hookはMCPツールを呼べないため、以下のように縮退する。
  - `session-start.sh`: 上記「セッション開始時の自動コンテキスト注入」節の記載どおり。
  - `post-push-usage-report.sh`: 集計状態の更新までは行い、MRコメントの自動投稿はスキップして
    その旨をstderrへ1行出す。`sinceLastPush`はリセットしないため、CLIのある環境で次にpushした
    ときにまとめて投稿される。
  - `post-push-compact-prompt.sh`: MR/PRのURLだけを「MCPツールで取得すること」という指示に
    差し替え、Compare系リンク・レビュー依頼メッセージ・`/compact`の呼びかけは従来どおり行う。
- **GitLabは対象外**: `glab` 不在時のGitLab向けMCP代替は対象外とする（利用実績が無く、ツール名・
  引数を実機検証できないため）。判定・失敗メッセージの枠組みのみ共通で、`mcp_tool_hint` は
  GitLabに対して「対象外」である旨を返す。詳細・却下案は
  [0027-gh_glab-CLI不在時はMCPフォールバック経路へ機構的に誘導する.md](../ddr/0027-gh_glab-CLI不在時はMCPフォールバック経路へ機構的に誘導する.md)
  参照。

### Draft PR作成失敗時の自動リトライ

`new_draft_merge_request` は `new_issue_branch` 直後（baseとの差分がまだ無い状態）で呼ぶと
PR/MR作成が失敗することがある。失敗を検知した場合、共通処理 `add_empty_commit_for_draft_mr`
（空コミット+リモートへの反映）を実行してから1回だけ自動リトライする（それでも失敗すれば
エラーを返す）。詳細・却下案は
[0005-DraftPR作成失敗時は空コミットで自動リトライする.md](../ddr/0005-DraftPR作成失敗時は空コミットで自動リトライする.md)
参照。

**この制約はGitHub（`gh pr create`）固有である**（issue #48で判明）。issue #48の対応時に、
GitHubとGitLabの双方を同一セッション内で実測した。

| プロバイダ | targetブランチと同一SHA（差分ゼロ）のブランチでのPR/MR作成 |
|---|---|
| GitHub（`gh pr create`） | **失敗する**（`No commits between main and feature-48-...`）。フォールバックが動作した |
| GitLab CE 18.5.4（`glab mr create`） | **成功する**。フォールバックに到達しない |

GitLab側の分岐を削除していないのは、実機確認できたのが CE 18.5.4 の1バージョンのみで、
他バージョン・他設定でも必ず成功すると言い切れないため。GitLabでは通常到達しない安全網という
位置づけになる。詳細・却下案は
[0026-空コミットフォールバックはGitHub固有の制約として残す.md](../ddr/0026-空コミットフォールバックはGitHub固有の制約として残す.md)
参照。

### 対応工数レポート（PostToolUse hook, git push検知）

issue #15「作業にかかったトークンなどの情報をMRのコメントに記載する」への対応として、
Claude Codeの対応工数（モデル別トークン数・ツール実行回数・assistant応答回数・稼働時間）をMRへ
自動投稿する。issue #28で、稼働時間（かかった時間）の記録・表示を追加した。

- **投稿トリガー**: `git push` 成功時に、前回投稿からの差分をMRへ新規コメントとして投稿する
  （毎ターン投稿やコメントのupsertではない）。
- **記録範囲**: モデル別トークン数（input/output/cache write/cache read。**既知の過小カウント要因
  あり**。詳細は「未決定事項・懸念点」参照）＋ツール実行回数＋assistant応答回数＋稼働時間
  （`activeSeconds`。下記「稼働時間の算出方法」参照）＋skill呼び出し・Agent呼び出し・
  ユーザーへの質問の詳細テーブル（issue #37で追加。下記「呼び出し・質問の詳細記録」参照）。
  推定コスト(USD)・ファイルdiff・プロンプト本文（Agent呼び出しの`prompt`列を除く）は対象外。
  - **ツール実行回数は「実際に呼び出されたツールの集計」であり、利用可能な全ツール種別の固定
    カタログではない**（PR #29レビュー指摘）。[ツールリファレンス](https://code.claude.com/docs/en/tools-reference)
    に載っている多数のツールのうち、そのpush間隔で一度も呼び出されなかったツールは単純に
    行として現れない（0件のツールを列挙する設計にはしていない。トークン数のモデル別テーブルで
    全項目0の行を表示しないようにした対応と同じ考え方）。
  - **直接の子（depth 1）サブエージェント（`Task`/`Agent`ツール等で起動される別セッション）の
    使用量は別集計として反映する**（PR #29レビュー指摘。当初は対象外としていたが後日追加対応した。
    詳細は下記「サブエージェントの使用量記録」参照）。サブエージェントがさらに起動するネストした
    サブエージェント（depth 2以降）は対象外。
- **稼働時間の算出方法（gapベースのidle検出＋tail buffer）**: 単純な「セッション開始〜最終メッセージ」
  の経過時間では、`AskUserQuestion`等での人間の回答待ちや応答終了後の次指示待ちのような
  「作業していない時間」を含んでしまう（PR #29レビュー指摘）。同種の課題を扱う参考実装
  （`claude-work-timer`, `claude-code-time-tracking`。いずれもClaude Code transcriptから実働時間を
  算出するOSS）を調査し、共通して採用されている「gapベースのidle検出＋セグメント末尾のtail buffer」
  方式を採用した。
  - `IDLE_GAP_THRESHOLD_SECONDS`（既定300秒=5分）: 集計対象entry（`gitBranch`一致・assistant）を
    時系列順に走査し、直前entryとの`.timestamp`差（gap）がこの閾値**未満**なら稼働時間へそのまま
    加算する。閾値**以上**（ちょうど閾値も含む）のgapは「人間の入力待ち」とみなし、gap自体は
    加算しない（区間＝セグメントが1つ閉じる）。
  - `TAIL_BUFFER_SECONDS`（既定30秒。`claude-work-timer`の既定値を踏襲）: セグメントが閉じるたびに
    末尾へこの秒数を加算する（応答を読む・確認する等、次のgapとしては現れない実作業時間の補完）。
    走査完了時点で、集計対象entryが1件以上あれば「現在末尾の（まだ閉じていない）セグメント」に対し
    同様に1回加算する。これにより、entryが1件しかないセッションでも稼働時間が0にならない。
    - この「末尾セグメントの暫定クローズ」による加算は、次回pushで同じセッションのtranscriptが
      伸びて再集計されると「実際のgap＋新しい末尾へのtail buffer」に置き換わる。置き換え後の値は
      常に元の値以上になるため、`activeSeconds`（セッション開始からの累計稼働秒数）は再集計を
      繰り返しても単調非減少であり続け、既存の累計差分パターン（後述）に影響しない。
  - **`fromdateiso8601`は使わない**（開発機のjq（Windowsネイティブ版jq 1.6）が`strptime`/`mktime`を
    実装しておらず`strptime/1 not implemented on this platform`で失敗するため。実機確認済み）。
    代わりに`strptime`/`mktime`に依存しない自前実装（`days_from_civil`アルゴリズムによる
    四則演算のみのISO8601→epoch秒変換、`UsageTracking.sh`の`epoch_from_iso8601`）を使う。
    一般的な注意事項として`.claude/rules/shell-script-style.md`「JSON操作」節にも追記した。
  - **既知の制約（目安であることの根拠）**: 閾値未満の短い待機（人間がすぐ返信した場合等）は
    稼働時間に混入しうる、閾値以上の長時間ツール実行（大きめのビルド等）は稼働時間から漏れうる、
    tail bufferは固定値のため実際の読了時間との過不足がありうる。「目安」である旨をレポート・
    このドキュメントに明記する（既存のトークン集計と同じ扱い）。
  - **`activeSeconds`は、issue #37で他フィールドが新規行diff方式（後述）へ移行した後も、
    唯一「累計値 - 前回スナップショット」という差分計算方式のまま残っている**（`current -
    prevSession値`、前回スナップショット無しなら`current - 0`、下限0）。セッションごとの永続状態
    （`sessions[<sessionId>]`）には`lastActiveSeconds`のみを保存する（`turns`等、他フィールドの
    旧スナップショット`lastTokens`/`lastTools`/`lastAssistantCount`はissue #37で新規行diff方式へ
    移行したのに伴い不要になり削除した）。
  - 複数セッション・複数プロジェクトが同時進行した場合の区間重複除去（overlap dedup。参考実装が
    持つ機能）は、本対応のスコープ外（単一ブランチ・単一セッションの範囲で完結する対応工数レポート
    のため）。将来必要になった場合に別issueで検討する。
- **サブエージェントの使用量記録**（PR #29レビュー指摘）: `Task`/`Agent`ツール等で起動される
  サブエージェント（直接の子、depth 1）のトークン・ツール使用量を、メインセッションとは独立した
  レポートセクションとして記録する。
  - **発見方法**: 実機調査により、サブエージェントを起動したセッションでは、メインtranscript
    （`<sessionId>.jsonl`）と同階層に**同名ディレクトリ**（`<sessionId>/`）が作られ、その中の
    `subagents/agent-<agentId>.jsonl`（＋同名`.meta.json`。`agentType`等を含む）にメインtranscript
    と同一スキーマ（`type`, `gitBranch`, `message.usage`, `message.content[].type=="tool_use"`,
    `timestamp`）でサブエージェントの活動が記録されていることを確認した。`${transcript_path%.jsonl}/subagents/`
    を列挙することで発見する。
  - **session-logsローカルコピー方式**（PR #29レビュー指摘）: 集計対象を毎回`~/.claude/projects`
    配下の外部パスから直接読むのではなく、`git push`検知のたびにメイン・サブエージェント両方の
    transcriptを`usage/session-logs/<sessionId>/`（gitignore対象）へコピーしてから、
    そのローカルコピーを対象に集計する。`~/.claude/projects`という非公開・ユーザープロファイル配下の
    揮発性のあるパスへ直接依存し続けるのを避け、pushのたびにリポジトリ内へスナップショットを
    退避しておくことで、調査・デバッグ時に状態ファイル（`usage/state/`）と同じ場所で
    生ログを参照できるようにする狙い。
    - **コピー先はセッション単位**（issue #23で変更）: 当初は
      `usage/session-logs/<safeBranch>/<sessionId>/`とブランチ単位だったが、issue #37でカーソル
      （`session-cursors/<sessionId>.json`）がブランチ非依存のセッション単位へグローバル化された
      のに対し、ミラーだけがブランチ単位のまま残っていた。同一セッションが別ブランチへresumeされる
      たびに全文コピーがブランチ数だけ増殖するため、カーソルのキー設計へ揃えた。これに伴い
      `_usage_sync_session_logs`から`branch`引数を廃止した（この関数は`branch`をコピー先パスの
      組み立てにしか使っておらず、集計側のブランチフィルタは`_usage_aggregate_new_lines`/
      `_usage_aggregate_transcript`がそれぞれ独立に`branch`を受け取って行うため）。
  - **`usage/`ディレクトリへの移設**（issue #37）: `session-logs`/状態ファイルは元々`.claude/`配下
    （`.claude/session-logs/`, `.claude/usage-state/`）に置いていたが、`.claude/`はAIエージェント
    自体の設定・ルール置き場という性格が強く、対応工数レポートのローカル作業状態を置くのは
    筋が悪いという指摘を受け、プロジェクトルート直下の新規`usage/`ディレクトリ
    （`usage/session-logs/`, `usage/state/`）へ移設した。`.gitignore`も旧2行から`/usage/`1行へ統合。
  - **行オフセットベースの差分パースへの移行（issue #37）**: 当初（PR #29時点）は「全件再パース＋
    スナップショット差分方式そのものは変更しない」（`activeSeconds`のgapベースtail buffer計算・
    単調性保証が「毎回全件を時系列で走査し直す」ことを前提にしており、オフセット方式にすると
    単調性証明が崩れるリスクが大きいと判断したため）としていたが、issue #37でこの判断を一部覆した。
    詳細は下記「新規行diff方式への移行（issue #37）」および
    [DDR 0006の追記](../ddr/0006-対応工数レポートはtranscript自前パースで実装する.md)を参照。
  - **`agentId`単位のスナップショット・表示**（issue #34で変更）: 累計スナップショットは`agentId`
    単位で状態ファイルの`agents[<agentId>]`に保存し、既存の`sessions[<sessionId>]`と全く同じ
    「current - prevSnapshot（下限0）」ロジックを適用する（バックグラウンドで複数pushをまたいで
    追記され続けるサブエージェントがあっても二重計上・過小計上が起きない）。
    `sinceLastPush.subagents[<agentId>]`も同じく`agentId`単位で差分を保持し、レポートにも
    `agentId`ごとに1行を表示する。
    - **当初は`agentType`単位で合算していたが、issue #34で`agentId`単位（起動したagentごとに1行）
      へ変更した**: 同じ`agentType`（例: `Explore`）を複数回起動した場合に合算されてしまい、
      「どのagentがどれだけ使ったか」が見えないというフィードバックを受けたため。`agents[<agentId>]`・
      `sinceLastPush.subagents[<agentId>]`のいずれにも、表示ラベル用に`agentType`と`description`
      （`meta.json`の`description`フィールド。サブエージェント起動時の説明文）を付与して保存する。
    - **差分0のagentはレポートに表示しない**（issue #34の追加指示）: `_usage_filter_nonzero_subagents`
      で、`tokensByModel`・`toolCalls`・`activeSeconds`のいずれも差分0のagentIdをレポート表示直前に
      除外する（表示用フィルタであり、状態ファイル側の`agents`/`sinceLastPush.subagents`自体からは
      削除しない）。同じ考え方で、ツール実行回数の集計（メイン・サブエージェント双方）も差分0の
      ツールはキーごと表示しないようにしている（元々「記録範囲」節で意図していた挙動だが、
      `_usage_merge_state`のtoolCalls集計が過去に一度でも使われたツールなら差分0でもキーを作る
      実装だったため、意図通りに動いていなかった不具合がissue #34で見つかり修正した）。
  - **稼働時間はメインの「対応工数」行には合算しない**: サブエージェント自身のgapベース稼働時間は
    メインの`activeSeconds`とは別集計とし、レポートには参考値として別行で表示する（Taskツールの
    完了待ち区間とサブエージェント内の稼働区間が重複しうるため、単純合算するとwall clock時間より
    過大になりうる。この重複除去自体は未対応、詳細は「未決定事項・懸念点」参照）。
  - **ネストしたサブエージェント（depth 2以降）は対象外**: `meta.json`に`spawnDepth`フィールドが
    存在し理論上ネストがありうるが、実データでは`depth 1`のみ観測され、ネスト時のディレクトリ構造・
    スキーマも未確認のため対象外とした。
- **新規行diff方式への移行（issue #37）**: 「利用したツール数が明らかにずれている」という報告を
  受け、原因調査（実データのjq調査）で、同一セッションが複数回・複数ブランチにわたってresumeされると
  transcript JSONL上に同一行が複数回（異なる`gitBranch`ラベル付きで）出現することを確認した。
  従来の「毎回全件を再パースし、前回累計との差分（引き算）を計上する」方式では、セッションが
  新しいブランチで初めてpushされた際に前回スナップショットが存在せず、蓄積済みの全件がその新
  ブランチの初回差分として計上されてしまう不具合があった。
  - **採用方針**: `tokens`/`tools`/`turns`（assistant応答回数）/`skillCalls`/`agentCalls`/
    `askUserQuestions`は、**セッション単位でグローバルなカーソル**
    （`usage/state/session-cursors/<sessionId>.json`の`lastLineCount`。サブエージェントは
    `<agentId>.json`）が指す「前回処理済み行数以降の新規行のみ」を対象に集計し、そのまま
    `sinceLastPush`へ**単純加算**する（引き算方式は廃止）。カーソルは**ブランチに紐付けず**
    セッション単位で管理するため、セッションが別ブランチへresumeされても取りこぼし・二重計上が
    起きない。新規行が無ければ、session-logsへのコピー・状態更新自体をスキップする
    （issue本文が当初提案していた「差分がなければコピーしない」設計）。
  - **意図的に行わないこと（既知の限界）**: この方式は行の中身（重複かどうか・どの`gitBranch`
    ラベルが「正しい」か）を一切詮索せず、「一度数えた範囲は二度と数え直さない」という機械的な
    原則だけで動く。そのため、**resumeによってtranscript行が新しい物理位置に再度書き出された
    場合、その重複行自体は「新規行」としてそのまま計上されうる**（内容が重複していることを
    検出して除外する仕組みではない）。カーソル方式が確実に防ぐのは「同じ行を同じ位置から二重に
    読むこと」のみである。設計判断の経緯（uuidベースの重複排除案を検討したが、`uuid`は
    `parentUuid`チェーン上のノード識別子であり重複自体は異常ではないという判断で不採用とした
    こと）はDDR 0006の追記を参照。
  - **`activeSeconds`のみ従来方式を維持**: 上記「稼働時間の算出方法」に記載の通り、
    `activeSeconds`はgapベースの単調非減少性が「毎回全件を時系列で走査し直す」ことを前提にして
    いるため、新規行diffには移行せず、既存の全件再パース＋スナップショット差分方式のまま維持した。
    1回のpushで「新規行diffの集計」と「全件再パースによる`activeSeconds`算出」の両方を行う
    ハイブリッド構成になる。
- **push断面の記録（`usage/state/push-index.jsonl`）**（issue #23）: そのpushで新たに記録された
  行の範囲を、1push1行のJSONLとして追記する。
  ```json
  {"push":1,"at":"2026-08-18T12:53:19Z","branch":"feature-23-...","sessionId":"ba52539d-...",
   "engine":"claude","main":{"from":441,"to":692},"agents":{"<agentId>":{"from":1,"to":7}}}
  ```
  - **背景**: 以前は`post-push-save-logs.sh`という独立したhookが、pushのたびにtranscript全文を
    `logs/push-<N>/`へコピーしていた。しかし**transcriptは追記専用**であり、各push断面が現物
    transcriptの先頭N行とバイト単位で完全一致すること（`/compact`を挟んでも成立すること）が
    実データで確認されたため、全文コピーを廃止し「1本のミラー＋行範囲の記録」へ置き換えた。
    詳細・却下案は
    [0022-push断面の全文コピーをやめ行番号インデックスで表現する.md](../ddr/0022-push断面の全文コピーをやめ行番号インデックスで表現する.md)
    を参照。
  - **行番号は1始まり・両端含む**。基準は既存の集計と同じ「**空行を除いた**行数」
    （`_usage_aggregate_new_lines`の`select(length > 0)`）に揃えており、
    `from = 前回カーソル値 + 1`、`to = totalLines`となる。
  - `push`番号は行数ではなく既存エントリの`push`の**最大値+1**を使う（手動編集や末尾改行の欠落が
    あっても壊れないようにするため）。
  - **新規行が無いpushでは追記しない**（session-logsへのコピー・状態更新をスキップする既存の
    早期リターンと同じ扱い）。
  - `agents`には、そのpushで実際に集計したサブエージェント（新規行があったもの）の行範囲のみが
    入る。この情報を得るため`_usage_aggregate_and_merge_subagents`の戻り値を
    `{state, agents: {<agentId>: {from, to}}}`へ変更した。
- **エンジン判定（Gemini CLI / Claude Code）**: hook入力の`tool_name`で実行中のエンジンを判定する。
  両エンジンの`tool_name`の値集合は重複しないため、これだけで機械的に一意判定できる。

  | `tool_name` | エンジン |
  |---|---|
  | `run_shell_command` | Gemini CLI |
  | `Bash` / `PowerShell` | Claude Code |
  | 上記以外 | 対象外として即終了 |

  プロジェクトルートは`${GEMINI_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-}}`で取得する（どちらも
  未設定なら終了）。この判定パターンは`post-push-usage-report.sh`・`post-push-compact-prompt.sh`が
  共通で使う（issue #7で両対応にした。それ以前は`CLAUDE_PROJECT_DIR`必須・`tool_name`が
  `Bash`/`PowerShell`限定のガードのみで、Gemini CLI実行時は処理冒頭で必ず終了していた）。
  判定結果の`engine_label`はMRコメント末尾の署名（「${engine_label}より」）にも使う。
  `post-push-compact-prompt.sh`は絞り込みにのみ使い、`engine`/`engine_label`変数は保持しない
  （メッセージ文言自体はエンジンによらず共通のため）。
  - **`engine`は`sync_usage_state`の第5引数として渡す**（issue #23。既定値は`claude`で、既存の
    4引数呼び出しも壊れない）。サブエージェントログの探索方法の分岐と、上記push-indexへの記録に使う。

    | engine | 探索元 | ミラー内のコピー先 |
    |---|---|---|
    | `claude` | `${transcript_path%.jsonl}/subagents/agent-*.jsonl`（＋対応する`.meta.json`） | `subagents/`直下 |
    | `gemini` | `$(dirname "$transcript_path")/<session_id>/`（ディレクトリごと） | `subagents/<session_id>/` |

  - **Gemini CLIはミラーへの保存のみ対応し、対応工数の集計対象には含めない**（issue #23）。
    集計側`_usage_aggregate_and_merge_subagents`のglobは`subagents/agent-*.jsonl`であり、
    Gemini分を`subagents/<session_id>/`という1階層下へ置くことで**構造的にマッチしない**。
    追加のガード条件を書かずにスコープ境界が保証される（この不一致は
    `.claude/scripts/test/test_usage_tracking.sh`で明示的に検証している）。
- **Gemini CLIのhook登録**: `.gemini/settings.json`の`hooks`キー配下（`SessionStart`/`BeforeTool`/
  `AfterTool`）に`.claude/hooks/*.sh`一式を登録する。`BeforeTool`/`AfterTool`の`matcher`は
  `"run_shell_command|Bash|PowerShell"`という両エンジンの`tool_name`を含む形にしている
  （各hookスクリプト内部で`tool_name`により絞り込むため、マッチャーを広めに取っても誤発火はしない）。
  `command`フィールドは単一のシェル文字列（`args`配列に相当するフィールドはGemini CLI側に無い）で、
  `${GEMINI_PROJECT_DIR}`はダブルクォートで囲む。`.gemini/settings.json`の既存キー
  （`general.plan.directory`）はそのまま維持する。採用経緯は
  [0018-gemini-settings.jsonのhooksはレビュー提示スニペットのhooksセクションのみ採用する.md](../ddr/0018-gemini-settings.jsonのhooksはレビュー提示スニペットのhooksセクションのみ採用する.md)
  参照。
- **呼び出し・質問の詳細記録**（issue #37）: 上記の新規行diff方式への移行と合わせて、
  メインセッションのtranscriptの新規行から以下3種の詳細情報を抽出し、`sinceLastPush`へ配列として
  追記する（サブエージェント自身が呼び出した分・ネストしたサブエージェントは対象外）。
  - `skillCalls`: `Skill` tool_useブロックから`{id, skill, args}`を抽出する。
  - `agentCalls`: `Agent` tool_useブロックから`{id, subagentType, description, prompt}`を抽出する
    （呼び出し時点の記録であり、対応するサブエージェントが完了しているかどうかは問わない。
    上記「サブエージェントの使用量記録」＝トークン/稼働時間の実績テーブルとは別集計）。
  - `askUserQuestions`: `type=="user"`エントリのtool_result本文（`"Your questions have been
    answered: \"Q\"=\"A\", ..."`形式。実データで確認済み）から、`"([^"]*)"="([^"]*)"`パターンで
    質問=回答ペアを正規表現抽出する。質問・回答の文字列自体にこのパターンと一致する部分文字列が
    含まれる場合は誤抽出しうる既知の制約（レアケースとして許容）。
  - レポートには、各配列が1件以上ある場合のみ「### skill呼び出し」「### Agent呼び出し」
    「### ユーザーへの質問」のテーブルとして表示する（0件セクションは表示しない、既存の
    トークンテーブル・ツール実行回数と同じ方針）。各セルはパイプ（`|`）をエスケープし改行は
    半角スペースへ変換する（表が崩れないようにするため。`description`列と同じ扱い）。
    `agentCalls`の`prompt`列は長文になりうるため300文字を超える場合は末尾を`…`で省略する。
- **コンポーネント**:
  - `.claude/hooks/lib/UsageTracking.sh`（共有ライブラリ、bash版。issue #6でPowerShell版から移行。
    issue #37で新規行diff方式へ全面的に書き換え）:
    `sync_usage_state <repoRoot> <branch> <sessionId> <transcriptPath>` が集計本体。まず
    `_usage_read_cursor`でセッション横断カーソル（`usage/state/session-cursors/<sessionId>.json`の
    `lastLineCount`）を読み、`_usage_aggregate_new_lines(transcriptPath, lastLineCount, branch)`
    （**常にtranscriptをファイルパスとして受け取り、jq内部で`inputs`によりファイル内容を読む**。
    詳細は下記の「重要な追加バグ修正」参照）が、カーソル位置以降の新規行のみを対象に
    `totalLines`（空行除く全行数）、`message.usage`（モデル別トークン数）、
    `message.content[].type=="tool_use"`（ツール名別呼び出し回数、および`Skill`/`Agent`ブロックからの
    `skillCalls`/`agentCalls`抽出）、該当エントリ件数（assistant応答回数）、`type=="user"`エントリの
    tool_result本文からの`askUserQuestions`抽出を1回のjq呼び出しの中で完結させて返す
    （`.gitBranch == <branch>` で絞り込み。詳細は上記「新規行diff方式への移行」
    「呼び出し・質問の詳細記録」参照）。`totalLines <= lastLineCount`（新規行が無い）なら、
    session-logsへのコピー・状態更新をスキップし既存状態をそのまま返す。新規行があれば、
    `_usage_sync_session_logs`で対象transcriptを`usage/session-logs/`へコピーしたうえで、
    `totalLines`以外のフィールドをそのまま「新規分（差分）」として使う。
    `_usage_merge_state`は引き算せずブランチ単位の状態ファイル（`usage/state/<branch>.json`、
    gitignore対象）の`sinceLastPush`へ単純加算・追記する。`activeSeconds`のみ別途
    `_usage_aggregate_transcript`（全件再パース。下記参照）で算出し、従来通り
    `sessions[sessionId].lastActiveSeconds`との差分（下限0）を計上する。**`.agents`
    （サブエージェントの累計スナップショット）は`_usage_merge_state`が管理するフィールドではないが、
    出力へそのまま引き継ぐ（issue #34で修正）。落とすと後続の`_usage_aggregate_and_merge_subagents`が
    毎回「前回スナップショット無し」として扱い、サブエージェント分の差分が常に全量再計上される
    不具合になる**。続けて`_usage_aggregate_and_merge_subagents`が`subagents/agent-*.jsonl`を
    列挙し、1ファイルずつ`agentId`単位のカーソル（`_usage_read_cursor`/`_usage_write_cursor`。
    メインと同じ`usage/state/session-cursors/`配下）を使って同じ`_usage_aggregate_new_lines`で
    新規行を集計し（新規行が無いagentはスキップ）、`_usage_merge_agent_state`（`agentId`単位の
    差分を`sinceLastPush.subagents[agentId]`へ保持しつつ、`activeSeconds`のみ
    `_usage_aggregate_transcript`の全件再パースで別途算出。`agentType`・`description`は
    `meta.json`から取得）で畳み込む。最後にメイン・サブエージェント両方のカーソルを
    `_usage_write_cursor`で更新する。投稿成功後のリセットは`_usage_reset_since_last_push`が担い
    （`sinceLastPush`をゼロ初期化。`skillCalls`/`agentCalls`/`askUserQuestions`も空配列へ、
    `agents`スナップショットは保持）、レポート表示直前の0件除外は`_usage_filter_nonzero_subagents`が
    担う（いずれもissue #34でテスト容易性のため関数化した）。`_usage_aggregate_transcript`
    （全件再パース）自体はissue #37以降`activeSeconds`算出専用として無改造のまま維持している
    （呼び出し元は戻り値のうち`.activeSeconds`のみを使う）。`_usage_safe_branch_name`はブランチ名の
    サニタイズ（状態ファイル名・session-logsディレクトリ名に使用）を担う共通ヘルパー。
    - **重要な追加バグ修正（issue #37、PR #47マージ前に発覚）**: `_usage_aggregate_new_lines`は
      当初、新規行の切り出し（別関数`_usage_read_new_lines`）とその集計を2段階に分け、切り出した
      パース済みJSON配列をシェル変数へ格納したうえで`--argjson`のコマンドライン引数としてjqへ
      渡す設計だった。しかしtranscriptの各行にはtool_use/tool_resultの生の入出力（Read/Bashの
      出力、Editの差分等）がそのまま含まれるため、新規行がわずか32件（約120KB）程度でもこの
      引数が肥大化し、Windowsのプロセス生成時のコマンドライン長上限（実測でおよそ32KB程度）を
      超えて`jq`の起動自体が`Argument list too long`（終了コード126）で失敗することが実データで
      判明した（対応工数レポートが投稿されなくなる不具合の直接原因）。両関数を1つに統合し、
      `_usage_aggregate_transcript`と同じ安全なパターン（ファイルパスを渡し`inputs`で読ませる）に
      統一して解消した。一般的な注意事項として
      [`.claude/rules/shell-script-style.md`「JSON操作」節](../../rules/shell-script-style.md)
      にも追記した。
    - **付随して見つかったバグ2件**: (1) userメッセージの`message.content`は、人間が直接入力した
      シンプルなテキストの場合は content-blockの配列ではなく単一の文字列のまま格納されることが
      実データで確認された。`.[]`でイテレートする既存コードはこの場合`Cannot iterate over string`で
      例外になるため、配列の場合のみ中身を返すjqヘルパー`content_blocks`を追加して防いだ。
      (2) 状態ファイル（`usage/state/<branch>.json`）が空／不正なJSONに壊れた状態のまま
      `_usage_merge_state`の`--argjson existing`へ渡ると、`jq`が不正なJSONとして必ず失敗し、
      **一度壊れると以降ずっと投稿できなくなる**（実際に0バイトの状態ファイルとカーソルだけが
      進んだ状態を確認した）。`sync_usage_state`が状態ファイルを読む箇所で内容の妥当性を
      （空文字列チェック→`jq -e .`の順で）検証し、無効なら`{}`（状態なし）へフォールバックする
      自己回復ロジックを追加した。詳細な経緯は
      [DDR 0006の追記](../ddr/0006-対応工数レポートはtranscript自前パースで実装する.md)を参照。
  - `.claude/hooks/post-push-usage-report.sh`（`PostToolUse` hook、bash版）: `.claude/settings.json` の
    matcher `Bash|PowerShell` と `if: "Bash(git push*)"` / `if: "PowerShell(git push*)"` により
    `git push` を含むコマンド実行後のみ発火する（マッチしなければプロセス起動自体が行われず、
    通常のBash/PowerShell利用への性能影響は無い）。投稿要否判定の前に自分で `sync_usage_state` を
    呼んで状態を最新化してから投稿する（ターンの途中でのpushでも記録漏れが起きないようにするため）。
    `sinceLastPush` が全て0（メイン＋サブエージェント双方のトークン合計で判定）なら投稿しない。
    `get_mr_for_branch` でMRが無ければ投稿しない。投稿成功後のみ `_usage_reset_since_last_push`で
    `sinceLastPush` をリセットする（失敗時は次回pushへ繰り越す。git push自体はブロックしない）。
    hookの起動コマンドは`"bash"`（PATH解決に依存。詳細: [shell-scripts.md](shell-scripts.md)）。
    コメント本文には`fmt_duration`（秒→`H時間M分`/`M分`形式）で整形した「対応工数（目安・入力待ち
    時間を除く）」の行、`skillCalls`/`agentCalls`/`askUserQuestions`がそれぞれ1件以上あれば
    「### skill呼び出し」「### Agent呼び出し」「### ユーザーへの質問」の詳細テーブル（issue #37。
    詳細は上記「呼び出し・質問の詳細記録」参照）、および`_usage_filter_nonzero_subagents`適用後の
    サブエージェント分が1件以上あれば「### サブエージェント」セクション（`agentId`×モデルの
    1行テーブル。エージェント種別・説明・モデル別トークン、ツール実行回数合計、稼働時間参考値）を
    含める。テーブル描画で`agentId`・モデル名・配列インデックス等をfor変数として使うループには、
    Windowsネイティブjqのコマンド置換CR混入対策（`.claude/rules/shell-script-style.md`
    「文字コード」節参照）として`tr -d '\r'`を挟む。
  - `.claude/scripts/src/show-push-log.sh`（issue #23で新設）: `usage/state/push-index.jsonl`の
    行範囲を使って、push断面のログを取り出すCLI。引数なしでpush一覧、`<push番号>`でそのpushの
    メインログ範囲、`--agents`を付けるとサブエージェント分もあわせて出力する。
    行番号の基準が「空行を除いた行数」であるため、物理行番号で切る素の`sed -n 'N,Mp'`は使えず、
    先に空行を落としてから範囲を取る（`extract_range`）。ミラーはgitignore対象のローカル状態の
    ため、別マシンで記録されたpushは切り出せない（その旨をstderrへ出して終了コード1）。
  - `.claude/settings.json`: `hooks.PostToolUse` を追加。
  - `.gitignore`: `/usage/`（issue #37で`/.claude/usage-state/`, `/.claude/session-logs/`の2行から
    統合。詳細は上記「`usage/`ディレクトリへの移設」参照。issue #23で、旧`post-push-save-logs.sh`が
    使っていた`/logs/`も廃止し`/usage/`へ一本化した）。
- **`Stop` hookは使わない**: 当初は `Stop`（1ターン完了時に発火）でも同じ集計処理を呼び、
  ターン数カウント専用の役割を持たせていたが、(1) `post-push-usage-report.sh` 自身が呼ぶだけで
  十分、(2) `Stop`依存のカウントは「そのターンのStopがまだ発火していない状態でのpush」で
  過少カウントになる、ことが分かったため廃止した。代わりに「assistant応答回数」を
  トークン・ツール回数と同じtranscript差分方式で算出する。
- **投稿内容の位置づけ**: コメント本文冒頭に「このレポートはレビューの合否判定には使用しないでください。」と明記する（`add_mr_comment` は通常コメントであり
  レビューではないため、そもそも承認状態に影響しない。issue #15の受け入れ条件に対応）。
- **フッターの免責事項説明文は初回投稿のみ表示**（issue #28, PR #29レビュー指摘）: 集計方法や
  既知の過小カウント要因（トークン数の項参照）を説明する詳しめのフッター文（`Claude Codeより:
  自動投稿（post-push-usage-report.sh による集計。...）`の段落）は、同じMRへ毎回のpushで
  繰り返し投稿されると冗長になるため、そのブランチ（MR）に対して**過去に投稿成功したことがあるか**
  （状態ファイルの`lastPostedAt`の有無、投稿前時点の値で判定）で分岐し、初回投稿時のみ表示する。
  冒頭の「レビューの合否判定には使用しないでください」という短い注記は、投稿ごとの判別のために
  必要なため毎回表示する。
- **制約: 検知は`tool_input.command`の文字列マッチに依存する**: 投稿トリガーの判定は、
  Bash/PowerShellツールへ渡された`tool_input.command`文字列に`git push`という語が現れるか
  どうかに依存する（`.claude/settings.json`の`if: "Bash(git push*)"` /
  `if: "PowerShell(git push*)"`によるフィルタと、各hookスクリプト内の
  `grep -qiE 'git[[:space:]]+push'`による再チェック）。この文字列依存から、方向の異なる2つの
  制約が生じる。
  - **検知漏れ（pushしたのに発火しない）**: `git push`をラップしたスクリプト（`bash deploy.sh`等）や、
    gitのエイリアス、他言語のsubprocess経由でpushした場合は`tool_input.command`自体に該当語が
    現れず、hookプロセスが起動されないため検知できない。**そのため、pushをラップしたスクリプトを
    作成することや、検知条件にHITしない形式でpushコマンドを実行することを禁止する。**
    投稿対象は使用量レポート（参考情報）のみでpush自体をブロックする機能ではないため、影響は
    該当push分の投稿が漏れることに留まる（次回、検知条件に一致するpush時に`sinceLastPush`が
    繰り越されて投稿される）。
  - **誤検知（pushしていないのに発火する）**: `if`フィールドは**前方一致ではなく部分一致**として
    動作する（issue #23対応時に実機で計3回確認。`cd /c/Users/... && ...`のようにコマンドが該当語で
    始まっていないケースや、heredocで渡すissue本文・MR descriptionの**地の文**に該当語が
    含まれるだけのケースで発火した）。発火するとhookは実際のpushの有無を確認しないため、
    対応工数の集計・カーソル前進・`/compact`促しが走る。実害は限定的だが、
    **長文をコマンド文字列へ直接埋め込まずファイル経由で渡す**ことで回避できる
    （`gh issue comment --body-file <file>`、`set_mr_description <n> <file>`。実機で発火しないことを
    確認済み）。AIエージェント向けの一般的な注意は`.claude/rules/git-workflow.md`を参照。

  より厳密な検知（`PreToolUse`と`PostToolUse`のペアでref状態を比較する等）も検討可能だが、
  全Bash/PowerShell呼び出しへ処理が追加され性能影響とのトレードオフになるため、対応しない。
- **設計判断の詳細・却下案**（`transcript` JSONL自前パースの採用理由、`gitBranch` フィルタの理由、
  `Stop` hookを廃止した経緯）は
  [0006-対応工数レポートはtranscript自前パースで実装する.md](../ddr/0006-対応工数レポートはtranscript自前パースで実装する.md)
  参照。

### /compact実施の呼びかけ（PostToolUse hook, git push検知）

issue #11「git pushイベントを検知してcompactする」への対応として、MRレビュー待ちに入るタイミング
（`git push`後）でコンテキストが肥大化しがちという課題に対し、`/compact`実施のタイミングを
逃さないよう気づきを与える。

- **検知ロジック**: 「対応工数レポート」節の`post-push-usage-report.sh`と同一パターン
  （`agent_id`/`tool_name`/`tool_input.command`の`git[[:space:]]+push`判定、
  `CLAUDE_PROJECT_DIR`確認、`get_workflow_config`でbase branch上のpushを除外、
  `get_mr_for_branch`でMRが無いブランチ（レビュー対象が無い）を除外）を流用する。
- **伝達手段は対応工数レポートと異なる**: 投稿先がMRコメントの対応工数レポートに対し、本機能は
  「セッション開始時の自動コンテキスト注入（SessionStart hook）」節の`session-start.sh`と同じ
  `hookSpecificOutput.additionalContext`方式（stdoutへJSON出力→コンテキストへ注入→エージェントが
  応答に反映）を使い、対話中のユーザーへ直接呼びかける。出力形式:
  `{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"<text>"}}`。
- **参照リンクの付与（issue #13）**: レビュー依頼メッセージにMRへのリンクが無いと、レビュアーが
  見に行くまでに1段階ハードルがあるという指摘への対応として、`additionalContext`に固定文だけでなく
  `get_mr_for_branch`/`get_repo_url`/`get_mr_diff_url`/`get_mr_diff_since_url`（「提供関数」表参照）
  で組み立てた具体的なURLを含める。
  - 常に含める: MRへのリンク（`get_mr_for_branch`の`url`）、defaultブランチとの差分
    （`get_mr_diff_url`）へのリンク。
  - このブランチで2回目以降のpush（＝レビュー指摘対応のpush）の場合のみ追加: 前回push時点から
    今回push時点までの差分（`get_mr_diff_since_url`）へのリンク、コメント一覧（MR画面。MRへの
    リンクと同一URL）へのリンク。
  - **URL組み立ての方針（issue #13フォローアップ）**: 当初はMR/PRのURL文字列に`/files`等のsuffixを
    推測で付け足す実装だったが、「gh/glabでURLの正確性を担保したい」という指摘を受け、
    `get_repo_url`（`gh repo view --json url` / `glab repo view --output json`の`.web_url`）で
    取得したリポジトリの正規URLを土台に、GitHub/GitLabいずれも持つ汎用の「Compare」ページ
    （`/compare/<from>...<to>` / `/-/compare/<from>...<to>`。PR/MR作成前から存在する標準機能で、
    PR個別のサブタブより広く安定）を組み立てる方式へ変更した。`from`/`to`にはブランチ名・SHAの
    どちらも指定できるため、「defaultブランチとの差分」（ブランチ名同士）・「前回pushとの差分」
    （SHA同士）のいずれも同じ`get_compare_url`系ヘルパー（`github_get_compare_url` /
    `gitlab_get_compare_url`）で組み立てられる。詳細な却下案は
    [0023-レビュー依頼メッセージの参照リンクは前回pushSHAをローカル状態で保持して組み立てる.md](../ddr/0023-レビュー依頼メッセージの参照リンクは前回pushSHAをローカル状態で保持して組み立てる.md)
    参照。
  - 「前回push時点」の判定は、`post-push-compact-prompt.sh`自身が`.claude/state/review-links/
    <safeBranch>.txt`へ直前pushのHEAD SHA（`git rev-parse HEAD`）を保存し、次回push時に読み出す
    形で行う。ファイルが無ければ「このブランチでの初回push」とみなし、前回pushとの差分・コメント
    一覧の2リンクは省略する。状態ファイルは`usage/`と同じ「ブランチ横断・非コミット対象のローカル
    作業状態」だが、責務分離のため対応工数レポート側（`usage/state/`）とは別ディレクトリ
    （`.claude/state/review-links/`）に置く（`.gitignore`に`/.claude/state/`を追加）。
    ブランチ名のファイル名サニタイズは`_usage_safe_branch_name`と同じ正規表現
    （`[^a-zA-Z0-9_-]`を`_`へ置換）だが、`UsageTracking.sh`をsourceして共有はせず本スクリプト内に
    複製している（1行の変換ロジックのために責務の異なるファイルへ依存を作らないため）。
- **`post-push-usage-report.sh`とは別ファイル**（`.claude/hooks/post-push-compact-prompt.sh`）とし、
  責務を混在させない（使用量集計とcompact促しは関心事が異なる）。`.claude/settings.json`の
  `hooks.PostToolUse[0].hooks`へ、既存の対応工数レポート用エントリと並べて2エントリ
  （`if: "Bash(git push*)"` / `"PowerShell(git push*)"`）を追加した。
- **エラー方針・実行シェルは既存hookと同様**: `main`関数＋`( main ) || true`＋`exit 0`
  （git push自体をブロックしない）、起動コマンドは`"bash"`（PATH解決に依存する制約は
  「セッション開始時の自動コンテキスト注入」節と同じ）。
- **`PostToolUse`での`additionalContext`実地検証**: このリポジトリで`additionalContext`方式の
  前例は`SessionStart`のみだったため実装後に実地検証した。実際の`git push`実行により、次のターンで
  `<system-reminder>PostToolUse:Bash hook additional context: ...</system-reminder>`が注入され
  期待通り動作することを確認済み（issue #11対応セッション）。
- **制約は「対応工数レポート」節と共通**: 「検知は`tool_input.command`の文字列マッチに依存する」
  制約（検知漏れ・誤検知の両方向）が同様に適用される（検知ロジックを流用しているため）。

### ブランチ命名

`<branchPrefixTemplate>`（既定 `feature-{issue}-{slug}`）に従い、issue番号をそのまま連番として使う
（別途の採番管理はしない）。`{slug}` はissueタイトルを英数字・ハイフンへ簡易変換したもの。

### Issueテンプレート標準化

issue本文の書き方を標準化し、ワークフローの起点（flow-id 1-1・1-2）の情報の粒度を揃える。人間がissueを
作る際は、以下4項目を見出し（`## `）付きで記載することを標準とする。

- **目的**: このissueで解決したい課題・達成したいこと
- **現状**: 現在の状態・困っていること
- **期待する動作**: 対応後にどうなっていてほしいか
- **受け入れ条件**: このissueが「完了」と判断できる具体的な条件（箇条書き）

これをGitHub/GitLab双方のissueテンプレート機能で起票時に差し込む。

- **`.github/ISSUE_TEMPLATE/task.md`**: GitHubの[Issueテンプレート（Markdown形式）](https://docs.github.com/ja/communities/using-templates-to-encourage-useful-issues-and-pull-requests/manually-creating-a-single-issue-template-for-your-repository)。
  YAML front matter（`name` / `about`）＋4見出しの記入欄で構成する。GitHubのissue作成画面で
  テンプレートとして選択できる。
- **`.gitlab/issue_templates/task.md`**: GitLabの[Description templates](https://docs.gitlab.com/user/project/description_templates/)。
  front matter無しの同内容のMarkdown。GitLabのissue作成画面の「Choose a template」から選択できる。
- どちらもMarkdownテンプレートであり、必須項目としての強制はできない（GitHub Issue Formsの
  ような`required`指定は使わない。見出しごと削除して起票することも可能）。強制ではなく
  「標準の見出しを用意して迷わず書けるようにする」ことが目的。

`/issue-mr-flow start` 側の対応: `get_issue` で取得したissue本文に4見出し
（`## 目的` / `## 現状` / `## 期待する動作` / `## 受け入れ条件`）が揃っているかを
`Provider.sh` の `test_issue_sections` でチェックし、欠けている見出しがあれば警告として提示する
（処理は止めない。テンプレートを使わず手動で作られた既存issueにも同じチェックが働く）。

### issue作成（AIエージェント代行・スクリプト実行）（issue #25）

issueはGitHubのUIからしか作成できず、標準4見出し（目的・現状・期待する動作・受け入れ条件）に
沿ったissueを、スクリプト実行やAIエージェント経由で作成する手段が無かった。「Issueテンプレート
標準化」節で定めた4見出しの**作成**側を、既存の`get_issue`（取得）と対称的な構造で追加した。

- **`build_issue_body`**: 4見出しでissue本文を組み立てる純粋関数（外部コマンド呼び出し無し）。
  `test_issue_sections`と組み合わせて使うことで、組み立てた本文が常に4見出しを満たすことを
  スクリプト内で検証できる。
- **`new_issue` / `github_new_issue` / `gitlab_new_issue`**: `new_draft_merge_request`等と同じ
  ディスパッチパターンで実装。`gh issue create` / `glab issue create`はissue番号を含んだJSONを
  直接返さずissue URLのみを出力するため、出力URL末尾から`grep -oE '[0-9]+$'`で番号を抽出し、
  `github_get_issue`/`gitlab_get_issue`を呼んで`get_issue`と同じ形（number/title/body/url/slug）に
  正規化する（呼び出し側が取得・作成のどちらの戻り値も同じ形で扱えるようにするため）。番号抽出に
  失敗した場合はエラーメッセージを出して`return 1`する。
- **`.claude/scripts/src/create-issue.sh`（新規CLIスクリプト）**: `--title`/`--purpose`/`--current`/
  `--expected`/`--acceptance`の5フラグ（すべて必須）を受け取り、`build_issue_body`→
  `test_issue_sections`（安全網）→`new_issue`の順に呼び出す。標準出力に作成結果のJSONを返す。
  人間が直接実行することも、AIエージェントが呼び出すことも想定する。
- **`.claude/skills/issue-create/SKILL.md`（新規スキル）**: `issue-mr-flow`のflow-id 1-1
  （issue起票、本来は人間の担当）をAIエージェントが代行するための独立スキル。ユーザーの依頼内容から
  5項目（タイトル＋4見出し）を埋め、内容が不足していれば質問で補い（勝手に創作しない）、ユーザーに
  提示して明示的な確認を得たうえで`create-issue.sh`を実行する。issue作成後のブランチ・Draft MR
  作成（flow-id 1-2〜1-3）は対象外とし、`/issue-mr-flow start <issue番号>`に委ねる。
  `issue-mr-flow/SKILL.md`のflow-id 1-1担当セルに、このスキルへの導線を一言追記した。
  `issue-mr-flow`のサブコマンドとして追加しなかった理由・却下案は
  [0011-issue作成は独立スキルとして新設する.md](../ddr/0011-issue作成は独立スキルとして新設する.md)
  参照。
- **GitHub/GitLab両実装**: GitLab側（`gitlab_new_issue`）は、当初このリポジトリのremoteがGitHubのみで
  実機未検証だったが、issue #48でローカルGitLab CE 18.5.4に対して実機確認済み（残る制約は
  「未決定事項・懸念点」の「GitLab側の動作未検証」を参照）。
- **実機検証（GitHub）**: `create-issue.sh`を実際に実行してissue #38を作成し、4見出し構成で
  正しく作成されることを確認した。検証用issueのため確認後にクローズ済み。

### 起票前の類似・重複issueチェック（issue #68）

上記のissue作成（AI代行）には、既存issueとの重複を起票前に検知する手順が無かった。人間が
GitHub/GitLabのUIから起票する場合は入力中に類似issueがサジェストされるが、`create-issue.sh`
経由のAI代行ではそれが働かない。結果として、**本来重複を作りにくいはずのAI経路のほうが重複を
作りやすい**構造になっていた。1 issue = 1ブランチ = 1 MR という単位を保つため、
`issue-create` スキルの最終確認の前に検索ステップを設けた。

#### 責務の分割

| 層 | 担当 |
|---|---|
| `issue-create` スキル（AIエージェント） | 検索キーワードの選定（3〜5個）、結果の提示、`AskUserQuestion` によるユーザーへの判断委譲 |
| `Provider.sh`（`search_issues`） | 与えられたキーワードでの検索、プロバイダ差の吸収（キー名・`state` の表記）、複数結果の統合 |

**キーワード抽出をスクリプト側へ実装していない**のが本機能の中心的な判断である。日本語主体の
issueから意味のある語を選ぶには形態素解析が要り、bashの文字種判定はロケール依存で静かに劣化する。
一方、`issue-create` スキルではAIが直前に自らタイトル・4見出しを組み立てており、そのissue固有の
語がどれかを判断できる。詳細・却下案は
[0033-issue起票前の重複チェックは検索をProvider層へ置きキーワード抽出はAIに委ねる.md](../ddr/0033-issue起票前の重複チェックは検索をProvider層へ置きキーワード抽出はAIに委ねる.md)
を参照。

#### `search_issues` の仕様

- 戻り値は `[{number, title, state, url}]` のJSON配列。該当が無ければ空配列 `[]`
  （何も出力しない、ではない。呼び出し側が `jq 'length'` で件数を判定できるようにするため）。
- **closedのissueも対象に含める。** 過去に見送られた提案の再提出を検知するため。
- `state` は `open` / `closed` の2値へ正規化する。GitHub CLIは `OPEN`/`CLOSED`、GitLabは
  `opened`/`closed` を返すため、そのままでは呼び出し側が両方の表記を知る必要がある。
- **キーワードごとに1回ずつ検索し、結果を統合する。** GitHub/GitLabのissue検索は複数語を
  AND条件として扱うため、1回にまとめると語が増えるほどヒットしなくなる。重複チェックで欲しいのは
  再現率のため、OR相当の挙動になるよう `merge_issue_search_results` で統合する
  （`number` で重複排除し、番号の降順で返す）。
- キーワードは最大5件（`SEARCH_ISSUES_MAX_KEYWORDS`）。CLI起動＝ネットワークI/Oの回数を
  有界にするためで、超過分は**標準エラーへ通知したうえで**切り捨てる。
- 1キーワードあたりの取得件数は20件（`SEARCH_ISSUES_LIMIT`）。

#### 最終判断は人間が行う

AIは候補を提示するに留め、**重複と断定して勝手に起票を中止しない**（スキルの
「してはいけないこと」に明記）。似ているだけで粒度・観点が異なる別issueであることは珍しくなく、
誤って中止した場合はユーザーが候補を見る機会そのものを失う。候補があった場合は
`AskUserQuestion` で「新規に起票する／既存issueへコメントする／やめる」を選ばせる。
候補が0件のときも「類似issueは見つかりませんでした」と明示する（検索したこと自体を黙らせない）。

#### MCP経路での差分

`gh`/`glab` CLIが無い環境では `mcp__github__search_issues`（`query`, `owner`, `repo`）へ
読み替える。このMCPツールは自然言語のセマンティック検索で、既に `is:issue` にスコープされて
いるため、CLI経路のようにキーワードごとに呼び分ける必要が無く、1回の `query` に複数キーワードを
平文で並べればよい。検索の仕組みが異なるため同じ入力でも候補の並びは一致しないが、
候補の提示が目的で件数・順序に依存した自動判断は行わないため許容している。

## 影響範囲

新規:
- `dev-tools/src/vcs/Provider.ps1`
- `dev-tools/src/vcs/Github.ps1`
- `dev-tools/src/vcs/Gitlab.ps1`
- `.mrworkflow.json`（リポジトリ直下）
- `.claude/skills/issue-mr-flow/SKILL.md`
- `.github/ISSUE_TEMPLATE/task.md`（GitHub用issueテンプレート）
- `.gitlab/issue_templates/task.md`（GitLab用issueテンプレート）
- `dev-tools/docs/spec/issue-mr-workflow.md`（本ドキュメント）

変更:
- `dev-tools/docs/README.md`（本機能のspecへのリンクを追加。設計反映時）
- `dev-tools/src/vcs/Provider.ps1`（`Test-IssueSections` 追加、`Github.ps1`のgraphqlクエリ修正）
- `.claude/skills/issue-mr-flow/SKILL.md`（`start` サブコマンドに標準4項目の警告ステップを追加。
  その後、docs-workflow.md/git-workflow.mdの実装フロー統合により全体フローの唯一の定義に変更）
- `.claude/rules/docs-workflow.md` / `.claude/rules/git-workflow.md`（実装フロー部分を削除し、
  参照情報のみを残す形に縮小）
- `AGENTS.md`（issue-mr-flow/SKILL.mdへのポインタを追加）

新規（追加分）:
- `dev-tools/docs/ddr/0002-issue-mr-flowへの実装フロー統合.md`

変更（追加分）:
- `dev-tools/src/vcs/Provider.ps1`（`Add-MrThreadReply` 追加、`Get-MrUnresolvedComments` に
  `-IncludeResolved` 追加）
- `dev-tools/src/vcs/Github.ps1` / `Gitlab.ps1`（返信のmutation/API呼び出しを追加）
- `.claude/skills/issue-mr-flow/SKILL.md`（`comments` に `all` 引数、`reply` サブコマンドを新設。
  「レビュー完了合図の確認」節を追加）

新規（設計反映時）:
- `dev-tools/docs/ddr/0003-レビュースレッド解決は自動化しない.md`

新規（追加分・途中引き継ぎ対応）:
- `.claude/agents/issue-mr-resume.md`（状態調査サブエージェント）

変更（追加分・途中引き継ぎ対応）:
- `dev-tools/src/vcs/Provider.ps1`（`Get-IssueNumberFromBranch`, `Get-MrForBranch`,
  `Get-BranchWorkFiles` を追加）
- `dev-tools/src/vcs/Github.ps1` / `Gitlab.ps1`（`GitHub-GetMrForBranch` / `GitLab-GetMrForBranch` を追加）
- `.claude/skills/issue-mr-flow/SKILL.md`（`resume` サブコマンドを新設。`comments` / `describe` の
  MR番号取得手順を `Get-MrForBranch` に統一）

新規（追加分・issue #5 SessionStart hook対応）:
- `.claude/hooks/session-start.ps1`（セッション開始時の自動コンテキスト注入スクリプト）

変更（追加分・issue #5 SessionStart hook対応）:
- `.claude/settings.json`（`hooks.SessionStart` を追加）
- `dev-tools/docs/spec/issue-mr-workflow.md`（本セクション追加）
- `.claude/skills/issue-mr-flow/SKILL.md`（全体フローを再構成。`docs/spec/`への設計ドキュメント
  作成・承認を独立ステップとして持つのをやめ、Planモードでの実行手順作成に一本化。plan合意〜実装
  着手の間にコンテキスト削減のためのセッションclearステップを新設。ステップ数は23のまま。
  「フローが進むごとにHANDOFF.mdに現在の状況を反映する」運用ルールを追加）

新規（追加分・issue #5 レビュー対応時の文字コード修正）:
- `.claude/rules/powershell-encoding.md`（PowerShellスクリプト・コマンドの文字コード注意事項）

変更（追加分・issue #5 レビュー対応時の文字コード修正）:
- `dev-tools/src/vcs/Provider.ps1`（dot-source直後にコンソール入出力エンコーディングをUTF-8へ切り替え）
- `.claude/skills/issue-mr-flow/SKILL.md`（「詳細ルールへのポインタ」に
  `.claude/rules/powershell-encoding.md` を追加）

新規（追加分・issue #15 Draft PR自動リトライ＋対応工数レポート）:
- `.claude/hooks/lib/UsageTracking.ps1`（集計ロジック）
- `.claude/hooks/post-push-usage-report.ps1`（PostToolUse hook）
- `dev-tools/docs/ddr/0005-DraftPR作成失敗時は空コミットで自動リトライする.md`
- `dev-tools/docs/ddr/0006-対応工数レポートはtranscript自前パースで実装する.md`

変更（追加分・issue #15 Draft PR自動リトライ＋対応工数レポート）:
- `dev-tools/src/vcs/Provider.ps1`（`Add-EmptyCommitForDraftMr`, `Add-MrComment` を追加）
- `dev-tools/src/vcs/Github.ps1` / `Gitlab.ps1`（`New-DraftMergeRequest` 実装に失敗時リトライを追加、
  `GitHub-AddMrComment` / `GitLab-AddMrComment` を追加）
- `.claude/settings.json`（`hooks.PostToolUse` を追加）
- `.gitignore`（`/.claude/usage-state/` を追加）
- `.claude/rules/directory-structure.md`（`.claude/hooks/` `.claude/hooks/lib/` をツリーに追加、
  hookスクリプトのBOM要件を配置の指針に追記）
- `.claude/rules/powershell-encoding.md`（新規`.ps1`作成時のBOM変換・構文検証コマンド例を追記）

新規（追加分・issue #6 スクリプトのbash化）:
- `dev-tools/src/vcs/Provider.sh` `Github.sh` `Gitlab.sh`
- `dev-tools/src/build.sh`
- `.claude/hooks/session-start.sh` `.claude/hooks/post-push-usage-report.sh`
- `.claude/hooks/lib/UsageTracking.sh`
- `tests/test_external_command_server.sh`
- `tests/test_vcs_provider.sh`（bash版Provider.shの純粋ロジックに対する単体テスト。新設）
- `dev-tools/docs/spec/shell-scripts.md`（bash化の設計方針）
- `.claude/rules/shell-script-style.md`（bashスクリプトの規約）

変更（追加分・issue #6 スクリプトのbash化）:
- 上記に対応する全`.ps1`ファイルを削除（`dev-tools/src/vcs/{Provider,Github,Gitlab}.ps1`,
  `dev-tools/src/build.ps1`, `.claude/hooks/session-start.ps1`,
  `.claude/hooks/post-push-usage-report.ps1`, `.claude/hooks/lib/UsageTracking.ps1`,
  `tests/test_external_command_server.ps1`）
- `.claude/settings.json`（hookの`command`を`powershell.exe`から`bash`へ変更。PATH解決に依存する
  ため、開発機ごとに「PATHへのgit bash追加＋順序調整」のセットアップが別途必要）
- `.claude/skills/issue-mr-flow/SKILL.md`（コード例・関数名をbash/snake_case版に更新、
  前提に`jq`を追加）
- `dev-tools/docs/spec/distribution.md`（`build.ps1`→`build.sh`）
- `tests/README.md`（対象スクリプトの更新、単体テストの追加）
- `.claude/rules/directory-structure.md`（`.sh`配置ルール・jq前提を追記）
- `.claude/rules/powershell-encoding.md`（「PowerShellを直接書く場合のみ適用」である旨を明確化）

新規（追加分・issue #28 対応工数レポートの稼働時間記録）:
- `tests/test_usage_tracking.sh`（`UsageTracking.sh`の`_usage_aggregate_transcript`/
  `_usage_merge_state`に対する単体テスト。新設）

変更（追加分・issue #28 対応工数レポートの稼働時間記録）:
- `.claude/hooks/lib/UsageTracking.sh`（`IDLE_GAP_THRESHOLD_SECONDS`/`TAIL_BUFFER_SECONDS`定数、
  gapベースの`activeSeconds`集計ロジック、`strptime`/`mktime`に依存しない自前実装
  `epoch_from_iso8601`を追加）
- `.claude/hooks/post-push-usage-report.sh`（`fmt_duration`、レポート本文への
  「対応時間（入力待ち時間を除く）」行を追加。レビュー往復で、トークン数の既知の過小カウント
  要因を説明するフッター文の追加、および`is_first_post`判定によるフッター表示の初回投稿限定化も追加）
- `dev-tools/docs/spec/issue-mr-workflow.md`（本セクション「稼働時間の算出方法」を追加、
  「未決定事項・懸念点」に稼働時間の誤差要因・overlap dedup未対応・トークン数の過小カウント要因を
  追記、「投稿内容の位置づけ」にフッター初回投稿限定の挙動を追記）
- `dev-tools/docs/ddr/0006-対応工数レポートはtranscript自前パースで実装する.md`（マージ済みDDRの
  ため既存内容は変更せず、トークン数の過小カウント問題に関する「追記」セクションを追加）
- `tests/README.md`（`test_usage_tracking.sh`の行を追加）
- `.claude/rules/shell-script-style.md`（Windowsネイティブjqの`strptime`/`mktime`未実装という
  一般的な制約を「JSON操作」節に追記）
- `.claude/hooks/post-push-usage-report.sh`（レビュー往復で、モデル別トークンテーブルから
  `<synthetic>`等の全項目0の行を除外する対応を追加）
- `dev-tools/docs/spec/issue-mr-workflow.md`（本セクション「記録範囲」に、ツール実行回数が
  「実際に呼び出されたツールのみの集計」であり全ツール種別の固定カタログではない旨、および
  サブエージェント内部の呼び出しは含まれない旨を追記）

新規（追加分・PR #29レビュー指摘: サブエージェント使用量記録＋session-logsコピー方式）:
- `.claude/session-logs/`（`git push`検知時にメイン・サブエージェントtranscriptをコピーする先。
  gitignore対象のためリポジトリには含まれない）

変更（追加分・PR #29レビュー指摘: サブエージェント使用量記録＋session-logsコピー方式）:
- `.claude/hooks/lib/UsageTracking.sh`（`_usage_safe_branch_name`ヘルパー切り出し、
  `_usage_sync_session_logs`（メイン・サブエージェントtranscriptのローカルコピー）、
  `_usage_merge_agent_state`（`agentId`単位のスナップショット差分を`agentType`単位で集約）、
  `_usage_aggregate_and_merge_subagents`（コピー済みディレクトリからの集計・マージ）を追加。
  `_usage_aggregate_transcript`/`_usage_merge_state`本体は無改造のまま再利用）
- `.claude/hooks/post-push-usage-report.sh`（投稿要否判定の`total`計算にサブエージェント分を
  含める、「### サブエージェント」セクションの追加、`sinceLastPush`リセット時の
  `subagentsByType: {}`追加）
- `.gitignore`（`/.claude/session-logs/`を追加）
- `tests/test_usage_tracking.sh`（`_usage_merge_agent_state`/`_usage_sync_session_logs`/
  `_usage_aggregate_and_merge_subagents`の単体テストを追加。疑似`~/.claude/projects`ツリーを
  `$TMPDIR`配下に自作して検証、実ホームディレクトリには触れない）
- `tests/README.md`（対象関数の追記）
- `dev-tools/docs/spec/issue-mr-workflow.md`（本セクション「記録範囲」の更新、新規サブセクション
  「サブエージェントの使用量記録」追加、「コンポーネント」の関数一覧更新、「未決定事項・懸念点」の
  追記）
- `dev-tools/docs/ddr/0006-対応工数レポートはtranscript自前パースで実装する.md`（マージ済みDDRの
  ため既存内容は変更せず、session-logsコピー方式・`agentId`/`agentType`二段設計に関する
  「追記」セクションを追加）

新規（追加分・issue #11 /compact実施の呼びかけ）:
- `.claude/hooks/post-push-compact-prompt.sh`（PostToolUse hook）

変更（追加分・issue #11 /compact実施の呼びかけ）:
- `.claude/settings.json`（`hooks.PostToolUse[0].hooks`へ`post-push-compact-prompt.sh`用の
  2エントリを追加。既存の対応工数レポート用エントリは維持）
- `dev-tools/docs/spec/issue-mr-workflow.md`（本セクション「/compact実施の呼びかけ」を追加、
  「コンポーネント構成」ツリーに`post-push-compact-prompt.sh`を追加）
- `dev-tools/src/vcs/Provider.sh`（`new_issue_branch`内の`git fetch`/`git switch`/`git push`の
  標準出力を`/dev/null`へ捨てるよう修正。従来は`git push -u`の出力が呼び出し元の
  `branch="$(new_issue_branch ...)"`という`$(...)`キャプチャへ混入し、branch変数が複数行文字列に
  なる不具合があった（本issue対応セッションで実際に踏み、手動リカバリ済み。`add_empty_commit_for_draft_mr`
  と同じ`>/dev/null`パターンで解消。flow-id 17のAIアセット改善で対応））

変更（追加分・issue #34: サブエージェント使用量記録のpush差分バグ修正・agent単位表示化）:
- `.claude/hooks/lib/UsageTracking.sh`
  - `_usage_merge_state`の戻り値に`.agents`のpassthroughを追加（push差分バグ本体の修正。
    詳細は本ファイル「サブエージェントの使用量記録」節参照）。
  - `_usage_merge_agent_state`のスキーマを`agentType`合算（`sinceLastPush.subagentsByType`）から
    `agentId`単位（`sinceLastPush.subagents`、`description`引数を追加）へ変更。
  - `_usage_reset_since_last_push`（投稿成功後のリセット処理の切り出し）、
    `_usage_filter_nonzero_subagents`（差分0のagent除外）を新規追加。
- `.claude/hooks/post-push-usage-report.sh`
  - サブエージェントテーブルを`agentType`合算の1行から`agentId`単位の1行（エージェント種別・
    説明・モデル別トークン）表示へ変更。表示直前に`_usage_filter_nonzero_subagents`を適用。
  - メイン・サブエージェント双方のツール実行回数表示に`map(select(.value > 0))`を追加し、
    差分0のツールをキーごと非表示化（レビュー往復で判明した追加のユーザー指示への対応）。
  - リセット処理を`_usage_reset_since_last_push`呼び出しに置き換え。
  - 主トークンテーブル・サブエージェントagentId/モデルの3ループに`tr -d '\r'`を追加
    （Windowsネイティブjqのコマンド置換CR混入バグの回避。実装時に新規発見）。
- `tests/test_usage_tracking.sh`（新スキーマに合わせて`_usage_merge_agent_state`関連テストを
  書き換え、`_usage_reset_since_last_push`/`_usage_filter_nonzero_subagents`の単体テスト、
  `sync_usage_state`を通しで呼ぶpush差分の回帰テスト（push→リセット→次pushは差分0→追記後は
  差分のみ）を追加。25件→39件）
- `.claude/rules/shell-script-style.md`（「文字コード」節に、Windowsネイティブjqのコマンド置換
  経由でのCR混入について追記。ファイルリダイレクト時の既知の挙動と同根だが、
  `for x in $(... | jq -r ...)`のようなループで2件以上の要素があると最後の要素以外にCRが
  付いたまま渡ることを新たに確認したもの）
- `dev-tools/docs/spec/issue-mr-workflow.md`（本セクション「サブエージェントの使用量記録」
  「コンポーネント」を`agentId`単位表示・関数構成の変更に合わせて更新。本エントリを追加）

新規（追加分・issue #25 issue作成スクリプト・スキル）:
- `dev-tools/src/create-issue.sh`（標準4見出しでissueを作成するCLIスクリプト）
- `.claude/skills/issue-create/SKILL.md`（issue起票をAIエージェントが代行する独立スキル）

変更（追加分・issue #25 issue作成スクリプト・スキル）:
- `dev-tools/src/vcs/Provider.sh`（`build_issue_body`、`new_issue`ディスパッチを追加）
- `dev-tools/src/vcs/Github.sh`（`github_new_issue`を追加）
- `dev-tools/src/vcs/Gitlab.sh`（`gitlab_new_issue`を追加。未検証）
- `.claude/skills/issue-mr-flow/SKILL.md`（flow-id 1担当セルに`issue-create`スキルへの導線を追記）
- `tests/test_vcs_provider.sh`（`build_issue_body`の単体テストを追加）
- `dev-tools/docs/spec/issue-mr-workflow.md`（「提供関数」に`build_issue_body`/`new_issue`を追加、
  新規サブセクション「issue作成（AIエージェント代行・スクリプト実行）」を追加、本エントリを追加）

新規（追加分・issue #37 対応工数レポートの集計ロジック修正・詳細テーブル追加）:
- `usage/`（`.claude/session-logs/`・`.claude/usage-state/`の移設先。`usage/session-logs/`,
  `usage/state/`（`usage/state/session-cursors/`にセッション横断カーソルを保持）。gitignore対象の
  ためリポジトリには含まれない）

変更（追加分・issue #37 対応工数レポートの集計ロジック修正・詳細テーブル追加）:
- `.claude/hooks/lib/UsageTracking.sh`（全面書き換え。`_usage_read_new_lines`/
  `_usage_aggregate_new_lines`（新規行diff集計、`skillCalls`/`agentCalls`/`askUserQuestions`抽出）、
  `_usage_read_cursor`/`_usage_write_cursor`（セッション横断カーソル管理）を追加。
  `_usage_merge_state`をdelta加算＋`activeSeconds`のみ差分方式へ変更。`_usage_merge_agent_state`/
  `_usage_aggregate_and_merge_subagents`も`agentId`単位のカーソル管理を組み込んで書き換え。
  `_usage_aggregate_transcript`自体は`activeSeconds`算出専用として無改造のまま維持）
- `.claude/hooks/post-push-usage-report.sh`（「### skill呼び出し」「### Agent呼び出し」
  「### ユーザーへの質問」の3テーブルを追加。`state_dir`のパスを`usage/state`へ更新）
- `.gitignore`（`/.claude/usage-state/`, `/.claude/session-logs/`の2行を`/usage/`1行へ統合）
- `tests/test_usage_tracking.sh`（新方式に合わせて全面書き換え。66件）
- `dev-tools/docs/ddr/0006-対応工数レポートはtranscript自前パースで実装する.md`（マージ済みDDRの
  ため既存内容は変更せず、行オフセットベースの差分パースへの移行・`usage/`ディレクトリ移設に関する
  「追記」セクションを追加）
- `.claude/rules/directory-structure.md`（ツリーへ`usage/`を追加）
- `dev-tools/docs/spec/issue-mr-workflow.md`（本セクション「記録範囲」「稼働時間の算出方法」
  「session-logsローカルコピー方式」を更新、新規サブセクション「新規行diff方式への移行」
  「呼び出し・質問の詳細記録」を追加、「コンポーネント」の関数一覧を更新、本エントリを追加）

変更（追加分・issue #37 続き: PR #47マージ前に発覚したjq argv長制限バグの修正）:
- `.claude/hooks/lib/UsageTracking.sh`（`_usage_read_new_lines`/`_usage_aggregate_new_lines`の
  2関数構成を1関数（常にtranscriptをファイルパスとして受け取りjq内で`inputs`により読む設計）へ
  統合し、大きな新規行データをコマンドライン引数として渡すことによる`Argument list too long`
  失敗を解消。あわせて、userメッセージの`message.content`が配列でなく文字列の場合に
  `Cannot iterate over string`で例外になる別のバグ（jqヘルパー`content_blocks`で修正）、
  および状態ファイルが破損（空／不正なJSON）した場合に恒久的に集計不能になる問題
  （`sync_usage_state`に自己回復ロジックを追加）も同時に修正）
- `tests/test_usage_tracking.sh`（新シグネチャに合わせて既存テストを書き換え、巨大ペイロード・
  文字列content・状態ファイル破損の3件の回帰テストを追加。71件）
- `.claude/rules/shell-script-style.md`（「JSON操作」節に、大きなJSONを`--argjson`等の
  コマンドライン引数としてjqへ渡さない一般的な注意事項を追記）
- `dev-tools/docs/spec/issue-mr-workflow.md`（本セクション「コンポーネント」に本バグ修正の
  詳細を追記、本エントリを追加）
- `dev-tools/docs/ddr/0006-対応工数レポートはtranscript自前パースで実装する.md`（マージ済みDDRの
  ため既存内容は変更せず、本バグ修正に関する追記セクションを追加）

変更（追加分・issue #43 開発フローに「調査」サイクルを追加）:
- `.claude/skills/issue-mr-flow/SKILL.md`（全体フローを23ステップから33ステップへ再構成。
  Planモードでの実行手順作成（旧flow-id 4）の前段に、作業サイクルと対称な「調査」サイクル
  （調査計画作成→合意→commit→レビュー→ループ→describe→調査実施→commit→describe→レビュー→
  ループ、新flow-id 4〜14）を新設し、以降を「調査結果をもとに」作業計画を作る形に書き換えて
  新flow-id 15以降へスライドさせた。調査計画・調査結果は別ファイルに分けず、既存の
  `plans/<plan名>.md`に章立てで含める（後述のDDR参照）。あわせて`start`/`resume`サブコマンドの
  案内文言、`flow-id 21実施前にマージされてしまった場合の対処`見出し・本文（→`flow-id 31`）、
  「レビュー完了合図の確認」見出しの対象flow-id列挙（→8・14・19・25・30）を更新）
- `HANDOFF.md`（「注」の誤記（35→33ステップ）を修正。フロー進捗状況テーブル自体の33行化は、
  本タスクが旧23ステップの運用下で進行中のため、次タスクへのリセット時（新flow-id 31）に行う）
- `.claude/rules/docs-workflow.md`（「フロー進捗状況」表の対応ステップ数（23→33）、ループ範囲の
  例示（7〜8, 11〜15, 16〜20 →7〜8, 10〜14, 18〜19, 21〜25, 26〜30）、同一ループ内ステップの
  組み合わせ例（14と15→13と14）を更新）
- `.claude/rules/git-workflow.md`（コミット運用節のcommitポイントflow-id列挙を
  「6/12/18/22」→「6/11/17/22/28/32」に更新）
- `.claude/skills/commit/SKILL.md`（frontmatter `description` および本文中のcommitポイント
  flow-id列挙を「6/12/18/22」→「6/11/17/22/28/32」に更新。2箇所）
- `dev-tools/docs/spec/issue-mr-workflow.md`（本セクション「全体フロー23ステップ」表現・
  `flow-id 21`参照（→`flow-id 31`）を更新、本エントリを追加）

変更（issue #24 dev-toolsをAI専用/人間専用に分離）:
- AIエージェントが能動的に利用するスクリプト・設計書一式を `dev-tools/` から `.claude/scripts/` へ
  移動した（`git mv`で履歴保持）。
  - `.claude/scripts/src/`: `vcs/Provider.sh` `Github.sh` `Gitlab.sh`, `create-commit.sh`,
    `create-issue.sh`, `archive-reentrant-plan.sh`, `extract-frontmatter.sh`
  - `.claude/scripts/docs/spec/`: `issue-mr-workflow.md`（本ドキュメント）, `shell-scripts.md`,
    `extract-frontmatter.md`
  - `.claude/scripts/docs/ddr/`: `0002`〜`0012`
  - `dev-tools/`には人間専用のexe配布ビルド関連（`src/build.sh`, `docs/spec/distribution.md`,
    `docs/ddr/0001-*.md`）のみ残した。
- 上記移動に伴い、本ドキュメント・`.claude/skills/*/SKILL.md`・`.claude/hooks/*.sh`・
  `.claude/rules/*.md`・`tests/*.sh`内のパス参照を新パスへ一括更新した（「## 仕様」節の現在の
  記述のみ更新し、本「## 影響範囲」節の過去エントリは変更当時の記録として書き換えていない）。
  `.mrworkflow.json`のデフォルト値（`specDirs`/`ddrDirs`）に`.claude/scripts/docs/{spec,ddr}`を追加。
- `.claude/rules/directory-structure.md`（`dev-tools/`の説明を「人間専用の開発補助ツール」に修正、
  ツリー図に`.claude/scripts/`を追加）
- `.claude/rules/markdown-frontmatter.md`（`ddr`/`spec`/`guide`行に`.claude/scripts/docs/`配下の
  新パスを追加）
- `.claude/agents/issue-mr-resume.md`（旧PowerShell版`Provider.ps1`前提の記述を、現行bash版
  `Provider.sh`のsnake_case関数へ全面書き換え）
- `DEVELOPERS.md`（`build.ps1`→`build.sh`の実行コマンド表記を修正）
- `.claude/rules/powershell-encoding.md`（既に現存しない`Provider.ps1`の仕組みを説明していた節を削除）
- 詳細な調査・作業計画は `plans/delegated-gathering-frog.md` 参照。

変更（追加分・issue #48 調査結果をmarkdownとhtmlで作る）:
- `.claude/skills/issue-mr-flow/SKILL.md`（flow-id 10に調査結果のHTML版
  （`reports/<plan名>.html`、TailwindCSS CDN方式の自己完結HTML）作成を追記、flow-id 14に
  reportsの同期更新を追記、flow-id 31の削除対象に`reports/`を追加。「PRがflow-id 31実施前に
  マージされてしまった場合の対処」節も同様に`reports/`を反映）
- `.claude/rules/docs-workflow.md`（「ドキュメント運用」表に`reports/<plan名>.html`の行を追加）
- `.claude/rules/directory-structure.md`（ツリー図に`reports/`を追加）
- `.mrworkflow.json`・`.claude/scripts/src/vcs/Provider.sh`の`get_workflow_config`既定値
  （`"reportsDir": "reports"`を追加）
- `.claude/scripts/src/vcs/Provider.sh`の`get_branch_work_files`（`reports_dir`を`plans_dir`/
  `worklog_dir`と対称に扱うよう改修。`resume`サブコマンドが検知するブランチ固有ファイルに
  `reports/`が含まれるようになる）
- `.claude/scripts/docs/spec/issue-mr-workflow.md`（「仕様」節の`SKILL.md`概要文・「提供関数」表の
  `get_branch_work_files`説明、「途中引き継ぎ対応（resume）」節の手順5を更新、本エントリを追加）
- `.claude/agents/issue-mr-resume.md`（手順6・手順8の説明ラベルに`reports`を追加）
- 詳細な調査・作業計画は `plans/drifting-sniffing-clover.md` 参照。

新規（追加分・issue #9 計画の2階層構造への再編）:
- `.claude/docs/ddr/0019-planツール利用を全体作業計画に限定し個別計画をファイル分離する.md`

変更（追加分・issue #9 計画の2階層構造への再編）:
- `.claude/skills/issue-mr-flow/SKILL.md`（全体フロー表を33→35ステップへ再構成。先頭に
  「全体作業計画をPlanモードで作成」「合意」の2ステップを追加し、旧flow-id N（N≧4）を新N+2へ
  スライドさせた。「計画の2階層構造」節・「種別を複数併記する場合／分ける場合」節を新設。
  `describe`/`comments`サブコマンドの手順を単一plan前提から複数計画対応へ変更。ループ範囲・
  commitポイント（→8/13/19/24/30/34）・レビュー完了合図（→10・16・21・27・32）・
  「PRがflow-id 33実施前にマージされてしまった場合の対処」のflow-id参照を更新）
- `.claude/rules/plan-mode-safety.md`（**全面改訂**。冒頭に「planツールを使う場面」節を新設し、
  規則6（re-entry時のarchiveスクリプト手順）を削除して「廃止した対処（履歴）」節へ経緯を移した。
  規則2のarchive例外記述も削除）
- `.claude/scripts/src/archive-reentrant-plan.sh`（**削除**。詳細はDDR 0019）
- `.claude/scripts/src/vcs/Provider.sh`（`get_branch_work_files`の`git diff`/`git status`へ
  `-c core.quotepath=false`を追加。日本語ファイル名が8進エスケープで返り`resume`が機能しなくなる
  既存バグの修正）
- `.claude/rules/docs-workflow.md`（ドキュメント運用表の`plans/`行を全体作業計画・個別作業計画の
  2行へ分割、`worklog/`・`reports/`の命名を更新、`HANDOFF.md`行の更新タイミングを
  「作業が終わるごと」から「flow-idが1つ進むごと・同じcommitに含める」へ具体化。ステップ数
  （33→35）・ループ範囲の例示を更新）
- `.claude/rules/directory-structure.md`・`index.md`（`plans/`の説明を2階層構造へ、`worklog/`・
  `reports/`の命名を更新）
- `.claude/rules/git-workflow.md`・`.claude/skills/commit/SKILL.md`（commitポイントのflow-id列挙を
  「6/11/17/22/28/32」→「8/13/19/24/30/34」に更新）
- `.claude/skills/canvas-report/SKILL.md`（`reports/`の命名を更新。「調査結果報告用」から
  設計・実装・AIアセット反映等も含む「報告用」へ位置づけを拡張）
- `.claude/skills/apply-mr-workflow-to-project/SKILL.md`（配布対象リストから
  `archive-reentrant-plan.sh`を除去）
- `.claude/agents/issue-mr-resume.md`（手順6で全体作業計画と個別作業計画を分けて列挙・報告する
  よう変更。全体作業計画の有無がflow-id 4の判定に直結するため）
- `AGENTS.md`（「計画はplansディレクトリ配下にセッション単位で保存する」を2階層構造の説明へ変更）
- `worklog/TEMPLATE.md`（ヘッダコメント・見出しを新命名へ）
- `.claude/docs/spec/issue-mr-workflow.md`（本ファイル。「計画の2階層構造」節を新設、
  「提供関数」表の`get_branch_work_files`に`core.quotepath`の注記を追加、本エントリを追加）
- 詳細な調査・作業計画は `plans/crispy-conjuring-canyon.md` 参照。

変更（追加分・issue #15 ベースブランチ確認のAskUserQuestion化）:
- `.claude/scripts/src/vcs/Provider.sh`（`new_issue_branch`に第3引数`[<base>]`（ベースブランチ
  上書き、省略可）を追加。省略時は従来どおり`defaultBaseBranch`を使う）
- `.claude/skills/issue-mr-flow/SKILL.md`（`start`サブコマンド手順2「見つからない場合（新規作成）」の
  先頭に、`AskUserQuestion`でベースブランチを確認する手順を追加。選択肢は「既定のベースブランチ
  （Recommended）／`main`（既定と異なる場合のみ）／自由入力（自動提供の『その他』）」の3パターン。
  既存のブランチslug用フレーズ生成・`new_issue_branch`/`new_draft_merge_request`呼び出し手順は
  番号を繰り下げて維持）
- `.claude/docs/spec/issue-mr-workflow.md`（本ファイル。「提供関数」表の`new_issue_branch`行を更新、
  「未決定事項・懸念点」に既定以外のベースブランチを選んだ場合の既知の制約を追加、本エントリを追加）
- 詳細な調査・作業計画は `plans/woolly-tickling-thimble.md` 参照。

新規（追加分・issue #23 セッションログの一本化とpush断面のインデックス化）:
- `.claude/scripts/src/show-push-log.sh`（push断面のログを参照するCLI）
- `tests/test_usage_tracking.sh`（`post-push-usage-report.sh`のコメントが参照していたが実在
  しなかったため新設。33件）
- `.claude/docs/ddr/0022-push断面の全文コピーをやめ行番号インデックスで表現する.md`

変更（追加分・issue #23 セッションログの一本化とpush断面のインデックス化）:
- `.claude/hooks/lib/UsageTracking.sh`（`_usage_sync_session_logs`のコピー先を
  `usage/session-logs/<sessionId>/`へセッション単位化し`branch`引数を廃止、`engine`引数を追加して
  Gemini CLI向けサブエージェント探索を旧`post-push-save-logs.sh`から移植。
  `_usage_append_push_index`を新規追加。`_usage_aggregate_and_merge_subagents`の戻り値を
  `{state, agents}`へ変更。`sync_usage_state`に`engine`（第5引数・既定`claude`）を追加し
  push-index追記を組み込み）
- `.claude/hooks/post-push-usage-report.sh`（`sync_usage_state`へ`engine`を引き渡し）
- `.claude/hooks/post-push-compact-prompt.sh`（削除した`post-push-save-logs.sh`への参照を
  コメントから解消）
- `.claude/settings.json`（`hooks.PostToolUse`から`post-push-save-logs.sh`の2エントリを削除）
- `.gemini/settings.json`（`AfterTool`から`post-push-save-logs`エントリを削除）
- `.gitignore`（`/logs/`を削除し`/usage/`へ一本化）
- `.claude/rules/git-workflow.md`（push検知hookの誤検知に関するAIエージェント向け注記を追加。
  commit側には既にあったがpush側には無かった）
- `.claude/rules/directory-structure.md`（動的作成ディレクトリの記述から`logs/`を削除、
  `usage/`の説明を更新、ツリーへ`tests/`を追加）
- `.claude/rules/shell-script-style.md`（bashの二重引用符内でのパラメータ既定値のバックスラッシュ
  残り・CR検査での`grep`パターンの落とし穴を追記）
- `.claude/docs/README.md`（DDR一覧へ0022を追加）
- `.claude/docs/spec/issue-mr-workflow.md`（本ファイル。`session-log-hooks.md`の内容を統合＝
  「エンジン判定」「Gemini CLIのhook登録」小節を新設、「session-logsローカルコピー方式」を更新、
  「push断面の記録」小節を追加、「コンポーネント」へ`show-push-log.sh`を追加、
  「制約」節を実挙動（部分一致）に合わせて全面改稿、「未決定事項・懸念点」へcompact検証結果と
  Gemini関連の懸念を移設・追加、本エントリを追加）

削除（追加分・issue #23 セッションログの一本化とpush断面のインデックス化）:
- `.claude/hooks/post-push-save-logs.sh`
- `.claude/docs/spec/session-log-hooks.md`（内容を本ファイルへ統合したため）

変更（追加分・issue #13 レビュー依頼メッセージへの参照リンク付与）:
- `.claude/scripts/src/vcs/Github.sh` / `Gitlab.sh`（`github_get_mr_diff_url` /
  `github_get_mr_diff_since_url` / `gitlab_get_mr_diff_url` / `gitlab_get_mr_diff_since_url`を
  純粋関数として追加）
- `.claude/scripts/src/vcs/Provider.sh`（`get_mr_diff_url` / `get_mr_diff_since_url`
  ディスパッチャを追加）
- `.claude/hooks/post-push-compact-prompt.sh`（固定文だったメッセージに、MRへのリンク・
  defaultブランチとの差分リンクを常に、前回push時との差分リンク・コメント一覧リンクを
  レビュー指摘対応push時のみ追加。`.claude/state/review-links/`に前回pushのHEAD SHAを保存）
- `.gitignore`（`/.claude/state/`を追加）
- `tests/test_vcs_provider.sh`（新規。上記の純粋関数の単体テスト）
- `.claude/docs/spec/issue-mr-workflow.md`（本ファイル。「提供関数」表に2関数を追加、
  「/compact実施の呼びかけ」節を参照リンク付与の設計に更新、本エントリを追加）

変更（追加分・issue #13 続き: gh/glabでURLの正確性を担保する方式へ変更）:
- `.claude/scripts/src/vcs/Github.sh` / `Gitlab.sh`（`github_get_repo_url` /
  `gitlab_get_repo_url`（`gh repo view` / `glab repo view`でリポジトリの正規URLを取得）と
  `github_get_compare_url` / `gitlab_get_compare_url`（汎用の「Compare」ページURLを組み立てる
  純粋関数）を新設。`github_get_mr_diff_url` / `github_get_mr_diff_since_url` /
  `gitlab_get_mr_diff_url` / `gitlab_get_mr_diff_since_url`は、MR/PRのURL文字列へ`/files`等の
  suffixを推測で付け足す実装から、`get_compare_url`系ヘルパーを呼ぶ実装へ変更）
- `.claude/scripts/src/vcs/Provider.sh`（`get_repo_url`ディスパッチャを追加。`get_mr_diff_url` /
  `get_mr_diff_since_url`の第1引数を`mrUrl`から`repoUrl`（`get_repo_url`の戻り値）へ変更、
  `get_mr_diff_url`に`baseBranch`/`headBranch`引数を追加）
- `.claude/hooks/post-push-compact-prompt.sh`（`get_repo_url`を呼び出し、`build_links_text`へ
  `repo_url`を渡すよう変更）
- `tests/test_vcs_provider.sh`（新設した`get_compare_url`系関数のテストへ更新。`get_repo_url`は
  `gh`/`glab`呼び出しを伴うため対象外のまま）
- `.claude/docs/spec/issue-mr-workflow.md`（本ファイル。「提供関数」表・「/compact実施の呼びかけ」節・
  「未決定事項・懸念点」を更新、本エントリを追加）
- `.claude/docs/ddr/0023-...md`（「決定」節に方式変更を追記、「却下した案」に当初のsuffix推測方式を追加）

新規（追加分・issue #48 GitLab実機検証で判明した3件の不具合修正）:
- `.claude/docs/ddr/0026-空コミットフォールバックはGitHub固有の制約として残す.md`

変更（追加分・issue #48 GitLab実機検証で判明した3件の不具合修正）:
- `.claude/scripts/src/vcs/Gitlab.sh`
  - `gitlab_format_discussion_notes` を純粋関数として新設（discussions APIのJSONを受け取り
    整形済みテキストを返す）。jqフィルタへ `select($n.system | not)` を追加し、GitLabが自動生成する
    システムノート（`changed the description` 等）をレビューコメントから除外。あわせてjq出力の
    CRを `tr -d '\r'` で除去
  - `gitlab_get_mr_unresolved_comments` を、`glab api` 呼び出しと上記関数の薄いラッパーへ変更
  - `gitlab_add_mr_comment` を、非推奨の `glab mr note --message` から安定版REST API
    （`glab api "projects/:id/merge_requests/<n>/notes" -X POST -f "body=..."`）へ置き換え
  - `gitlab_new_draft_merge_request` の空コミットフォールバックのコメントを、GitHub固有の制約で
    あることが分かる内容へ書き換え（コードは変更なし）
- `tests/test_vcs_provider.sh`（`gitlab_format_discussion_notes` の単体テストを5件追加。
  実レスポンス形状のフィクスチャで、システムノートの除外・解決済みの扱い・CR非混入を確認）
- `.claude/docs/spec/issue-mr-workflow.md`（本ファイル。「Draft PR作成失敗時の自動リトライ」節を
  GitHub固有の制約として訂正、「提供関数」表の `add_mr_comment` GitLab実装欄と
  `get_mr_unresolved_comments` の説明を更新し内部ヘルパーに関する注記を追加、
  「issue作成（AIエージェント代行・スクリプト実行）」節のGitLab未検証注記を更新、
  「決定済み事項」へGitLabのシステムノートの扱いを追加、「未決定事項・懸念点」の
  「GitLab側の動作未検証」を部分解消の内容へ書き換え、本エントリを追加）
- `.claude/docs/README.md`（DDR一覧に0027を追加）
変更（追加分・issue #34 gh/glab CLI不在時のMCPフォールバック経路）:
- `.claude/scripts/src/vcs/Provider.sh`（`get_vcs_access_mode` / `parse_repo_slug` /
  `get_repo_slug` / `mcp_tool_hint` / `require_vcs_cli` を追加。プロバイダ依存の8関数の先頭へ
  `require_vcs_cli` ガードを挿入。`get_repo_url` はMCP経路で `get_repo_slug` から組み立てる
  フォールバックを追加）
- `.claude/hooks/session-start.sh`（CLI不在時に「経路はMCP」「ブランチ名から抽出したissue番号」
  「owner/repo」「手順の参照先」を注入する分岐を追加。従来は`gh`の失敗を握りつぶし
  「PR: なし」と誤表示していた）
- `.claude/hooks/post-push-usage-report.sh`（CLI不在時はMRコメント投稿をスキップし、その旨を
  stderrへ出力）
- `.claude/hooks/post-push-compact-prompt.sh`（CLI不在時はMRリンク行をMCPでの取得指示に差し替え、
  Compare系リンクとレビュー依頼メッセージは従来どおり出力）
- `.claude/scripts/src/create-issue.sh`（CLI不在時の挙動をヘッダコメントへ明記）
- `.claude/skills/issue-mr-flow/SKILL.md`（「`gh`/`glab` CLI不在時のMCPフォールバック」節を新設。
  サブコマンド節冒頭・「前提」節から参照）
- `.claude/skills/issue-create/SKILL.md`（手順3にMCP経路での読み替えを追加）
- `AGENTS.md`（MCP代替の記述から、対応表の正であるSKILL.mdの該当節への参照を追加）
- `tests/test_vcs_provider.sh`（`parse_repo_slug` / `mcp_tool_hint` の単体テストを追加）
- `.claude/docs/spec/issue-mr-workflow.md`（本ファイル。「提供関数」表へ5関数を追加、
  「セッション開始時の自動コンテキスト注入」のフォールバック方針を更新、
  「`gh`/`glab` CLI不在時のMCPフォールバック経路」節を新設、本エントリを追加）
- `.claude/docs/ddr/0027-gh_glab-CLI不在時はMCPフォールバック経路へ機構的に誘導する.md`（新規）

新規（追加分・issue #45 get_providerのホスト判定化）:
- `.claude/docs/ddr/0028-プロバイダ判定はremote-URLのホスト部でgithub以外をgitlabとみなす.md`

変更（追加分・issue #45 get_providerのホスト判定化）:
- `.claude/scripts/src/vcs/Provider.sh`
  - `provider_from_remote_url` を純粋関数として新設（remote URL文字列からホスト部を抽出し
    プロバイダ名を返す。パラメータ展開のみで外部コマンド呼び出し・コマンド置換を伴わない）
  - `get_provider` を上記関数の薄いラッパーへ変更。URL文字列全体への部分一致をやめたことで、
    ホスト名に `gitlab` を含まないself-hosted GitLab（`git@git.example.co.jp:...`、
    `http://localhost:8929/...`）を判定できるようになった。副次的に、パスへ `github` を含む
    GitLab URL（`https://gitlab.com/github-mirror/x.git`）の誤判定も解消
  - 従来の「サポート対象外のリモートです」エラーは、ホスト名が空の場合のみ到達する
    メッセージへ変更（受け入れたトレードオフ。DDR 0028参照）
- `tests/test_vcs_provider.sh`（`Provider.sh` のsourceを追加し、`provider_from_remote_url` の
  単体テストを15件追加。GHE・scp形式・ポート付きssh・パスに `@` を含むURL・`aslead` の優先順位・
  ホスト名が空のときの終了コードを含む。`passed=26 failures=0`）
- `.claude/docs/spec/issue-mr-workflow.md`（本ファイル。「コンポーネント」の `Provider.sh` の説明を
  新しい判定方式へ更新、「提供関数」表直後の段落へ `provider_from_remote_url` と
  「`Provider.sh` 内の関数がすべて公開インターフェースとは限らない」旨を追記、「決定済み事項」へ
  プロバイダ判定の規則を追加、「未決定事項・懸念点」の「GitLab側の動作未検証」から
  `Provider.sh` 経由のディスパッチの項目を解消、本エントリを追加）
- `.claude/docs/README.md`（DDR一覧に0027を追加）

変更（追加分・issue #55 remote URLのホスト抽出の共通化）:
- `.claude/scripts/src/vcs/Provider.sh`
  - `split_remote_url` を純粋関数として新設（remote URLをホスト部・パス部へ分解し
    `REPLY_HOST` / `REPLY_PATH` へ返す。パラメータ展開のみで、外部コマンド呼び出し・
    コマンド置換・パイプを一切伴わない。上記「提供関数」表直後の段落を参照）
  - `provider_from_remote_url` をホスト抽出のみ `split_remote_url` へ委譲する形へ変更。
    判定規則（`aslead` → gitlab ／ `github` → github ／ それ以外 → gitlab の順序と結果）・
    エラーメッセージ・終了コードはいずれも変更なし。**1回あたりのプロセス起動ゼロも維持**
    （DDR 0028の制約。空関数をベースラインにした200回計測で、空関数80ms に対し
    `split_remote_url` 93ms・`provider_from_remote_url` 132ms。同条件で `jq` は1回138ms）
  - `parse_repo_slug` から `sed` 2回を除去し `split_remote_url` へ委譲。外部プロセス起動が
    3回 → 1回（`jq` のみ）になり、実測で 415ms/回 → 105ms/回（74%削減）。
    返すJSONのキー・構造（`{host, owner, repo, path, url}`）は変更なし。ホストを小文字化する
    ようになった点のみ振る舞いが変わる（上記「決定済み事項」参照）
- `tests/test_vcs_provider.sh`（`split_remote_url` の単体テストを8件追加。https形式・scp形式・
  ポート付きssh・パスに `@` を含むURL・大文字ホスト・パス無し・ネストしたnamespace・
  ホスト名が取れない場合を含む。**既存36件は1件も変更していない**。`passed=44 failures=0`）
- `.claude/docs/spec/issue-mr-workflow.md`（本ファイル。「提供関数」表直後の段落へ
  `split_remote_url` を追記し `provider_from_remote_url` の説明を新しい関係へ更新、
  「決定済み事項」へ`parse_repo_slug`が返すホストの小文字化を追加、本エントリを追加）

新規（追加分・issue #46 defaultブランチとのコンフリクト検知・解消フロー）:
- `.claude/scripts/src/check-base-conflicts.sh`（テキストコンフリクト＋DDR番号重複の検知。
  仕様: `.claude/docs/spec/check-base-conflicts.md`）
- `tests/test_check_base_conflicts.sh`（純粋関数の単体テスト。`passed=13 failures=0`）
- `.claude/skills/resolve-conflict/SKILL.md`（コンフリクト解消の標準手順。類型A〜E）
- `.claude/docs/spec/check-base-conflicts.md`（検知スクリプトの仕様）
- `.claude/docs/ddr/0029-defaultブランチとのコンフリクトは検知を機構化し解消手順をスキル化する.md`

変更（追加分・issue #46）:
- `.claude/skills/issue-mr-flow/SKILL.md`（**flow-id 5-2としてコンフリクト検知・解消ステップを
  新設し、旧5-2→5-3・旧5-3→5-4へ繰り下げ。全39→40ステップ**。「defaultブランチとの
  コンフリクト検知・解消（flow-id 5-2）」節を追加）
- `.claude/skills/commit/SKILL.md` / `.claude/rules/git-workflow.md`（コミットを行うflow-idの
  一覧を `5-2` → `5-3` へ更新）
- `.claude/rules/docs-workflow.md`（ステップ数を40へ、コミットのflow-idを `5-3` へ更新）
- `.claude/skills/apply-mr-workflow-to-project/SKILL.md` / `index.md`（新規スクリプト・
  スキルを一覧へ追加）
- `.gitignore`（`index.jsonl` の除外理由コメントが参照するDDR番号を `0024` → `0025` へ修正。
  issue #36の改番時の更新漏れで、存在しないDDRを指したままになっていた。本issueが対象とする
  「改番時の参照更新漏れ」の実例）
- `.claude/docs/README.md`（spec一覧に `check-base-conflicts.md`、DDR一覧に0029を追加）
- `.claude/docs/spec/issue-mr-workflow.md`（本ファイル。全体フローのステップ数を40へ更新、
  本エントリを追加）

変更（issue #63 機構自身の単体テストを`.claude/`配下へ移動）:
- 単体テスト4本を `tests/` から `.claude/scripts/test/` へ `git mv` で移動（履歴保持）。
  リポジトリ直下の `tests/` は廃止した
  - `test_extract_frontmatter.sh` / `test_update_handoff_progress.sh` /
    `test_usage_tracking.sh` / `test_vcs_provider.sh`
  - 各ファイルの変更は `repo_root` 算出（`$script_dir/..` → `$script_dir/../../..`）と、
    冒頭コメントの実行コマンド・`shellcheck source=` の相対パスのみ。アサーションは無変更で、
    移動前後とも `passed` は 17 / 15 / 33 / 36（計101件）・`failures=0`
  - 目的は、`apply-mr-workflow-to-project` の配布単位（`.claude/`）へテストを収めること。
    `sync-assets.sh` は `.claude/` 配下をそのままコピーするため**スクリプト側の変更は不要**で、
    かつ導入先プロジェクト本体の `tests/` と場所を取り合わなくなる（DDR 0031）
- `.claude/scripts/src/extract-frontmatter.sh` / `update-handoff-progress.sh` /
  `vcs/Provider.sh` / `.claude/hooks/post-push-usage-report.sh`（テストを指すコメントのパスを更新）
- `.claude/rules/directory-structure.md`（ツリーの `tests/` を `.claude/scripts/test/` へ移動、
  「配置の指針」へ `test/` の役割を追記）
- `.claude/rules/shell-script-style.md`（「テスト」節の配置先を新パスへ）
- `index.md`（Directory Structure へ `./.claude/scripts/test/` を追加）
- `.claude/docs/spec/update-handoff-progress.md`・`shell-scripts.md`（「## 仕様」節内の
  現在の状態を説明するパス参照のみ更新）
- `.claude/docs/ddr/0031-機構自身の単体テストは.claude_scripts_test配下へ置く.md`（新規）
- `.claude/docs/README.md`（DDR一覧に0031を追加）
- mainマージ時の追随（issue #46・#60 が本ブランチと並行してマージされたため）
  - `.claude/scripts/test/test_check_base_conflicts.sh`（issue #46 が `tests/` へ新規追加した
    5本目のテスト。同じ規則で `.claude/scripts/test/` へ移し `repo_root` を調整）
  - `.claude/skills/resolve-conflict/SKILL.md`（検証手順のテスト実行パス）
  - `.claude/scripts/src/check-base-conflicts.sh`・`.claude/docs/spec/check-base-conflicts.md`
    （テストを指す現在の記述のパス）

なお、DDR本文および本「## 影響範囲」節の過去エントリは、変更当時の記録として書き換えていない
（`.claude/rules/docs-workflow.md` の規定）。`tests/test_external_command_server.sh` を指す記述も、
このリポジトリに実在せず移動していないため触れていない。

### issue #61（Draft解除をProvider.sh経由にする）

flow-id 5-3「Draftを解除する」が、`Provider.sh` に対応する関数を持たないため、AIエージェントが
`gh pr ready` を直接呼ぶ運用になっていた（issue #55 のクローズ時に実際にそうした）。Draft **作成**側
（`new_draft_merge_request`）だけが抽象化され**解除**側が欠けている非対称を解消し、GitLab環境と
CLI不在時のMCPフォールバック経路（issue #34）の双方でクローズ工程が通るようにした。

- `.claude/scripts/src/vcs/Provider.sh`
  - `set_mr_ready <n>` を追加（先頭で `require_vcs_cli` を呼び、`get_provider` の結果で委譲する。
    命名は既存の `set_mr_description` に倣った）
  - `mcp_tool_hint` に `set_mr_ready` の分岐を追加
- `.claude/scripts/src/vcs/Github.sh`（`github_set_mr_ready`。`gh pr ready <n>`）
- `.claude/scripts/src/vcs/Gitlab.sh`（`gitlab_set_mr_ready`。`glab mr update <n> --ready`。
  ヘッダの検証状況コメントへ、本関数だけが実機未検証である旨を追記）
- `.claude/scripts/test/test_vcs_provider.sh`（`mcp_tool_hint set_mr_ready` の1件を追加。mainのissue #68分と統合した結果54件）
- `.claude/skills/issue-mr-flow/SKILL.md`
  - flow-id 5-3 を、CLIを直接叩くのではなく `set_mr_ready` を使う記述へ更新
  - 「`gh`/`glab` CLI不在時のMCPフォールバック」節の対応表へ `set_mr_ready` 行を追加
- `.claude/docs/spec/issue-mr-workflow.md`（本ドキュメント。「提供関数」表・本節・「未決定事項・懸念点」）

**flow-idの番号について**: issue #61 の起票時点では対象を「flow-id 5-2」と記載しているが、
issue #46 でコンフリクト検知のステップが 5-2 として挿入された結果、Draft解除は現在 **5-3** である
（`.claude/docs/ddr/0029-defaultブランチとのコンフリクトは検知を機構化し解消手順をスキル化する.md`
「全39→40ステップ」）。本対応では現行の番号である 5-3 を更新した。

### issue #57（compact後の作業コンテキスト再注入と注入量の肥大化検知）

`/compact` 後に SessionStart hook が発火せず、ブランチ・issue/PR情報が再注入されなかった問題への
対応。あわせて注入対象を広げ、注入量が膨らんだ場合の自己検知を追加した。

- `.claude/settings.json`（`hooks.SessionStart` の matcher へ `compact` を追加）
- `.claude/hooks/session-start.sh`
  - 本体処理を `main()` へ移し、`[ "${BASH_SOURCE[0]}" = "${0}" ]` ガードで直接実行時のみ呼ぶ
    構造へ変更（単体テストから `source` できるようにするため）
  - `context_text_bytes` / `append_size_warning` / `extract_handoff_next_steps` /
    `build_work_context` を追加
  - 注入内容へ「ブランチ固有の作業ファイル一覧（ファイル名のみ）」と
    「`HANDOFF.md` の『## 次にやること』節」を追加（CLI経路・MCP経路の双方）
  - 組み立てた `additionalContext` がしきい値（既定8000バイト）を超えた場合のみ、末尾へ
    整理を促す指示文を追記（切り詰めはしない）
- `.claude/scripts/test/test_session_start.sh`（新規。35件）
- `.claude/docs/ddr/0032-compact後もSessionStart-hookで作業コンテキストを再注入する.md`（新規）
- `.claude/docs/README.md`（DDR一覧に0032を追加）

本節より前の「セッション開始時の自動コンテキスト注入」節では、matcher・情報収集・
フォールバック方針の**現在の状態を説明する記述のみ**を更新しており、過去エントリは変更していない。

### issue #51（`worklog/` `reports/` の削除タイミングの記述統一）

`.claude/rules/docs-workflow.md` の運用表が、`worklog/` `reports/` の削除を「PR作成前の設計反映で
まとめて削除」と書いており、唯一の実装フロー定義（`.claude/skills/issue-mr-flow/SKILL.md`）の
flow-id 5-1（次タスクのための片付け）と食い違っていた。issue #48 の作業中、反映計画を書く段階で
どちらに従うか迷ったという実害が出たため、**SKILL.md を正として参照側の記述を揃えた**。
同じ食い違いがリポジトリ内の他の4箇所にも波及していたため、あわせて修正した。

- `.claude/rules/docs-workflow.md`
  - `worklog/` `reports/` 行の「寿命」を「push単位」から「タスク（issue／ブランチ）単位
    （flow-id 5-1でまとめて削除）」へ変更し、「運用」欄の削除タイミングも flow-id 5-1 へ改めた
    （`worklog/` はファイル自体がpushごとに `_push<N>` で分かれる点を「寿命」欄に併記して、
    「作成の単位」と「削除の単位」が別であることを明示した）
  - 表の直後へ、`plans/` `worklog/` `reports/` の3つがまとめて flow-id 5-1 で削除されること、
    設計反映（flow-id 4-6）で行うのは**内容**の spec/ddr への反映でありファイル削除ではないことを
    示す注記を追加（`plans/` 行は既に flow-id 5-1 と整合していたため行自体は変更せず、3つの
    ライフサイクルが同じであることを表の外の1段落で揃えた）
  - `spec`/`ddr` 行の「plans／worklogの内容をMR作成時に反映する」を「flow-id 4-6（設計反映）で
    反映する」へ変更（Draft MRの作成は flow-id 1-3 であり、反映のタイミングではない）
  - 「コード・スクリプト内のコメントから参照しない」節の「push単位・タスク単位で削除される」を
    「タスク単位（flow-id 5-1）で削除される」へ変更
- `.claude/rules/git-workflow.md`（「PR・マージ」節の「設計反映時にworklogファイルを削除しておく
  ことで」を「flow-id 5-1で`plans/` `worklog/` `reports/`を削除しておくことで」へ変更）
- `index.md`（`worklog/` の説明を、内容の反映（flow-id 4-6）とファイルの削除（flow-id 5-1）に
  分けた記述へ変更）
- `.claude/skills/canvas-report/SKILL.md`（markdown事前変換の理由に書かれた `reports/` の
  ライフサイクル「squash merge後は削除される」を「flow-id 5-1でタスクごとに削除される」へ変更。
  実際には削除はマージ前に完了している）
- `.claude/docs/spec/issue-mr-workflow.md`（本ドキュメント。本節）

`.claude/docs/ddr/0004` `0006` の本文にも「設計反映時に削除」という記述があるが、DDRの本文は
不変（`.claude/rules/docs-workflow.md`）であり、かつ当時の状況を記録した point-in-time の記述の
ため変更していない。

## 設定項目

`.mrworkflow.json`

```jsonc
{
  "branchPrefixTemplate": "feature-{issue}-{slug}",
  "defaultBaseBranch": "main",
  "plansDir": "plans",
  "worklogDir": "worklog",
  "reportsDir": "reports",
  "specDirs": [".claude/docs/spec"],
  "ddrDirs": [".claude/docs/ddr"]
}
```

各キーの意味・デフォルト値・用途はREADME.md「セットアップ」節を参照（issue #21）。
`specDirs`/`ddrDirs`は現時点で`Provider.sh`のどの関数からも読み出されておらず、ドキュメント上の
配置場所指定（アプリ本体追加時の拡張ポイント）としてのみ使われる。

## 決定済み事項（旧・未決定事項）

- **issueとMRのリンク方法**: GitHub/GitLab双方とも `New-DraftMergeRequest` の本文に
  `Closes #<issue番号>` をそのまま使う（両プロバイダとも同じキーワード構文で自動クローズに対応するため、
  差異吸収は不要だった）。
- **未解決コメントの判定基準**: GitHubは `reviewThreads.isResolved`、GitLabは
  `discussion.notes[].resolved`（`resolvable` なnoteのみ対象）をそれぞれ真偽値として使う。
  `Get-MrUnresolvedComments` はこれを既定の除外条件、`-IncludeResolved` で無視する条件として使う。
- **（issue #48）GitLabのシステムノートの扱い**: GitLabは「説明を変更した」等の操作履歴を、
  レビューコメントと同じ discussions API から `system: true` のnoteとして返す（実機確認:
  `changed the description`）。これをレビューコメントとして扱うと、未解決件数が実際より増え
  レビュー往復の完了判定が狂うため、`resolvable`/`resolved` とは**別に** `system` で機械的に
  除外する。`include_resolved=true`（全件取得）でも除外する（操作履歴はレビュー対象ではないため）。
  GitHub側はGraphQLの `reviewThreads` を使っておりシステムイベントを返さないため、同種の対処は不要。
- **返信本文のテンプレート**: `Add-MrThreadReply` の `-ReplyBody` は呼び出し側（AIエージェント）が
  組み立てた自由文をそのまま渡す。関数側で定型の接頭辞等は付けない。
- **スレッドの解決（resolved）操作**: `Add-MrThreadReply` は返信のみ行い、解決マークは付けない
  （レビュアー側の操作という位置づけ）。かわりに、人間からの完了合図を受けた際は
  `Get-MrUnresolvedComments -IncludeResolved` で再確認してから次のステップへ進む運用にした。
  背景・却下案は
  [.claude/scripts/docs/ddr/0003-レビュースレッド解決は自動化しない.md](../ddr/0003-レビュースレッド解決は自動化しない.md)
  参照。
- **AI返信のアイデンティティ表示**: `Add-MrThreadReply` の投稿者アカウントはAI/人間で分離できない
  （`gh`/`glab` CLIは人間の認証情報を使うため）。かわりに返信本文の先頭に `Claude Codeより:` の
  署名行を必ず付ける運用ルールを `reply` サブコマンド手順に追加した。botアカウントによる
  投稿者分離は規模超過のため見送り。背景・却下案は
  [.claude/scripts/docs/ddr/0004-AI返信は署名で識別しbotアカウント分離は見送る.md](../ddr/0004-AI返信は署名で識別しbotアカウント分離は見送る.md)
  参照。
- **SessionStart hookの実装言語はPowerShell**（issue #6で覆した過去の決定）: issue #5対応時点では
  Bashスクリプトへの置き換え（`gh`/`git`/`jq`がUTF-8をそのまま扱えるため、Windows PowerShell 5.1
  特有のコードページ問題を根本的に回避できる）も検討したが、`Provider.ps1`が持つGitHub/GitLab差異
  吸収ロジックを別言語で二重実装するコストが見合わないと判断し却下していた。issue #6で
  `Provider.ps1`自体を`Provider.sh`へbash化したことで二重実装の懸念が解消され、`session-start.ps1`
  含む全スクリプトをbash化した（詳細: [shell-scripts.md](shell-scripts.md)）。コードページ問題は
  bash化により根本的に発生しなくなった（当時`Provider.ps1`側で行っていた対策は`Provider.sh`では不要）。
- **SessionStart hookでのサブエージェント抑止方法**: 公式ドキュメント確認の結果、SessionStart hookは
  matcher（`startup`/`resume`/`clear`等）で区別してもTask tool経由のサブエージェント内で発火する
  ことが判明した。そのためmatcherでの抑止は不可能と判断し、スクリプト側でstdin JSONの`agent_id`
  フィールドの有無を見て早期終了する実装とした。
- **SessionStart hookのmatcher範囲**（issue #57で`compact`の扱いを覆した過去の決定）:
  `startup|resume|clear` に限定し、`compact`（頻度が高く`gh` API
  呼び出しのコストが無視できない）と `fork`（今回のissueのスコープ外）は対象外とした。
  issue #57で`compact`を追加した（compactは要約内容を指定できず現在地が失われるため。
  コスト面の再評価は[DDR 0032](../ddr/0032-compact後もSessionStart-hookで作業コンテキストを再注入する.md)）。
  `fork`は引き続き対象外。
- **Windows PowerShell 5.1の文字コード対策はルールでなくスクリプト側で強制する**（issue #6で
  `Provider.ps1`自体が`Provider.sh`へ置き換わったため、本項の対策は過去のものとなった。教訓・
  判断基準としての記録として残す）: issue #5対応中に、
  日本語Windowsのシステムコードページ（cp932）起因の文字化け・構文エラーを2種類実機で確認した
  （`gh`出力の誤読によるJSON構文エラー、`Get-Content`のエンコーディング未指定によるレビュー返信の
  文字化け）。当初は「呼び出し側が`-Encoding UTF8`を書く」という運用ルールでの対応を考えたが、
  書き忘れに依存する対策は同じ事故を再発させかねないとの指摘を受け、`Provider.ps1`側で機械的に
  保証する方式に変更した。`Provider.ps1`のdot-source直後に、(1) `[Console]::OutputEncoding`/
  `InputEncoding`をUTF-8へ切り替え（外部コマンドとのI/Oを保護）、(2) `$PSDefaultParameterValues`で
  `Get-Content`/`Set-Content`/`Add-Content`/`Out-File`の既定エンコーディングをUTF-8へ切り替え
  （呼び出し側が`-Encoding`を省略しても安全）を行う。ワイルドカード`'*:Encoding'`は他コマンドレットの
  `-Encoding`パラメータ定義と衝突し警告が出たため、対象コマンドレットを個別に指定した。
  `Provider.ps1`をdot-sourceしない独立スクリプト（`.claude/hooks/session-start.ps1`等）向けの
  注意事項のみ、`.claude/rules/powershell-encoding.md` に残した。
- **`New-DraftMergeRequest` はbaseとの差分（コミット）が無いブランチでは失敗する→空コミットで
  自動リトライする**: `New-IssueBranch`直後はbaseとの差分がまだ無いため`gh pr create` /
  `glab mr create`が失敗する（issue #5対応時に実機確認、当初は手動回避のみでissue #15対応まで
  未解消だった）。`$LASTEXITCODE`で失敗を検知し、空コミット+pushで1回だけ自動リトライする方式で
  解消した。背景・却下案は
  [0005-DraftPR作成失敗時は空コミットで自動リトライする.md](../ddr/0005-DraftPR作成失敗時は空コミットで自動リトライする.md)
  参照。
- **対応工数のトークン集計方式**: transcript JSONLの自前パース以外に確実な取得手段が
  無いことを確認した上で採用した。非公開フォーマットへの依存リスクは、失敗の握りつぶし・
  「目安」である旨の明記で吸収する。`entry.gitBranch`でのフィルタにより、複数ブランチを跨いだ
  セッションでの他ブランチ分混入を防ぐ。詳細・却下案は
  [0006-対応工数レポートはtranscript自前パースで実装する.md](../ddr/0006-対応工数レポートはtranscript自前パースで実装する.md)
  参照。
- **対応工数の集計方式（tools/tokens/turns）はセッション横断カーソルによる新規行diff方式**
  （issue #37）: 「毎回全件再パース＋前回累計との引き算」方式が抱えていた「セッションが新しい
  ブランチで初めてpushされた際の過去分の再計上」バグへの対応として、当初検討したuuidベースの
  重複排除案（不採用）を経て、セッション単位でグローバルなカーソル（ブランチに紐付けない
  `usage/state/session-cursors/<sessionId>.json`）による新規行diff＋単純加算方式を採用した。
  `activeSeconds`のみ単調非減少性を保つため従来の全件再パース方式を維持する。設計判断の経緯・
  却下案は
  [0006-対応工数レポートはtranscript自前パースで実装する.md](../ddr/0006-対応工数レポートはtranscript自前パースで実装する.md)
  の追記を参照。
- **push断面の保存はtranscript全文のコピーではなく行範囲の記録で表現する**（issue #23）:
  transcriptが追記専用であること（`/compact`を挟んでも各push断面が現物の先頭N行とバイト単位で
  一致すること）を実データで確認したうえで、`logs/push-<N>/`への全文コピーを廃止し、
  `usage/state/push-index.jsonl`の行範囲＋セッション単位のミラー1本へ統合した。設計判断の経緯・
  却下案は
  [0022-push断面の全文コピーをやめ行番号インデックスで表現する.md](../ddr/0022-push断面の全文コピーをやめ行番号インデックスで表現する.md)
  参照。
- **プロバイダ判定はremote URLの「ホスト部」で行い、GitHubでなければGitLabとみなす**（issue #45）:
  `get_provider`はかつて`git remote get-url origin`の**URL文字列全体**への部分一致
  （`*github.com*` / `*gitlab*`）で判定しており、ホスト名に`gitlab`を含まないself-hosted GitLab
  （`git@git.example.co.jp:...`、`http://localhost:8929/...`）を「サポート対象外のリモートです」と
  して弾いていた。ホスト部を抽出したうえで「`aslead`を含めばGitLab（社内GitLabの明示ケース。
  GitHub判定より前に評価する）／`github`を含めばGitHub／それ以外はGitLab」と判定する方式へ変更した。
  本ワークフローの対応プロバイダがGitHub/GitLabの2つに限られること、GitHubはSaaS（`github.com`）・
  GHEとも慣習的にホスト名へ`github`を含むことが前提。**判定は`gh`/`glab`を呼ばないため認証状態に
  依存しない**（未ログインでも同じ結果になる）。副次的に、パスへ`github`を含むGitLab URL
  （`https://gitlab.com/github-mirror/x.git`）の誤判定も解消した。却下案（`glab auth status`等の
  glab由来の情報を使う3方式・`.mrworkflow.json`への`provider`キー追加）と、受け入れたトレードオフ
  （GitHub/GitLabのどちらでもないリモートにも`gitlab`を返すため、旧実装の明快なエラーが出なくなる）は
  [0028-プロバイダ判定はremote-URLのホスト部でgithub以外をgitlabとみなす.md](../ddr/0028-プロバイダ判定はremote-URLのホスト部でgithub以外をgitlabとみなす.md)
  参照。
- **（issue #55）`parse_repo_slug`が返すホストの大文字小文字**: 小文字へ正規化する。ホスト抽出を
  `split_remote_url`へ共通化した際、`provider_from_remote_url`（元から小文字化していた）と
  `parse_repo_slug`（入力のまま返していた）で挙動が割れていたため、**正規化する側へ揃えた**。
  ホスト名はDNS上case-insensitiveであり、小文字化はURLの正規化として安全である。
  これが本対応で**唯一の、外部から見た振る舞いの変更**にあたる。
  - 具体例: `https://GitHub.COM/O/R.git` に対し `.host` が `GitHub.COM` → `github.com`、
    `.url` が `https://GitHub.COM/O/R` → `https://github.com/O/R` へ変わる。
  - **`.owner` / `.repo` / `.path` は小文字化しない**（上記例では `O` / `R` / `O/R` のまま）。
    GitHub/GitLabともパス部はcase-sensitiveに扱われうるため、リポジトリ名・ネームスペース名の
    大文字は保つ必要がある。
  - 消費側（`.claude/hooks/session-start.sh`・`get_repo_url`）は`.owner`/`.repo`/`.url`しか
    使わず、いずれも実リポジトリのホストは元から小文字のため実害はない。
  - `.claude/scripts/test/test_vcs_provider.sh`（issue #63以前は `tests/test_vcs_provider.sh`）に
    「ホストは小文字化・パスは保つ」ケースを追加して明示的に固定した。

### issue #68（起票前の類似・重複issueチェック）

新規:
- `.claude/docs/ddr/0033-issue起票前の重複チェックは検索をProvider層へ置きキーワード抽出はAIに委ねる.md`

更新:
- `.claude/scripts/src/vcs/Provider.sh`（`search_issues` ディスパッチャ、`merge_issue_search_results`、
  `SEARCH_ISSUES_LIMIT` / `SEARCH_ISSUES_MAX_KEYWORDS`、`mcp_tool_hint` への `search_issues` 行）
- `.claude/scripts/src/vcs/Github.sh`（`github_search_issues` / `github_normalize_issue_search_results`）
- `.claude/scripts/src/vcs/Gitlab.sh`（`gitlab_search_issues` / `gitlab_normalize_issue_search_results`）
- `.claude/skills/issue-create/SKILL.md`（実行フローに手順2「類似・重複issueをチェックする」を追加し
  以降を繰り下げ。各手順に内容名を併記。「してはいけないこと」に2項目追加）
- `.claude/skills/issue-mr-flow/SKILL.md`（MCPフォールバック対応表に `search_issues` の行）
- `.claude/scripts/test/test_vcs_provider.sh`（正規化・統合・`mcp_tool_hint` のテスト9件追加。`passed=53 failures=0`）
- `.claude/docs/spec/issue-mr-workflow.md`（提供関数表・「起票前の類似・重複issueチェック」節・本項）
- `.claude/docs/README.md`（DDR一覧に0033）

## 未決定事項・懸念点

- **（issue #61）`gitlab_set_mr_ready` は実機未検証**: 本対応の実行環境（Claude Code on the web の
  リモート実行環境）には `gh`・`glab` のいずれも存在せず、issue #48 で使ったローカルGitLab CE も
  再現できなかったため、`glab mr update <id> --ready` を実際に実行した確認はできていない。
  実装の根拠にしたのは次の2つで、いずれも `--ready` フラグの存在と意味が一致している。
  - 公式ドキュメント `docs/source/mr/update.md`（gitlab-org/cli, main）: `--ready` は
    「Mark merge request as ready to be reviewed and merged.」、用例として `glab mr update 23 --ready`
    が記載されている。
  - 実装ソース `internal/commands/mr/update/mr_update.go`（同 main）: `--ready` 指定時に
    `(?i)^(\s*(?:draft:|wip:)\s*)*` でタイトル先頭の `Draft:` / `WIP:` を除去した新タイトルを
    更新APIへ送る（GitLabがDraftをタイトル接頭辞で表現するため）。接頭辞が無いMRに対しては
    タイトルが変わらないだけでエラーにならず、冪等に呼べる。

  あわせて、GitHub側の `github_set_mr_ready`（`gh pr ready`）も本環境では実行できていない。
  確認できたのは、`Provider.sh` 経由の `set_mr_ready` が (a) CLI不在時に `require_vcs_cli` で
  正しいMCPツール名（`mcp__github__update_pull_request` の `draft=false`）を提示して失敗すること、
  (b) プロバイダ判定に応じて `github_set_mr_ready` / `gitlab_set_mr_ready` へ正しく委譲すること、
  の2点である（後者はプロバイダ固有関数をスタブへ差し替えて確認した）。
  `gh`/`glab` が使えるローカル環境で実PRに対して実行し、確認できた時点で本項目を削除する。

- **（issue #57）`.gemini/settings.json` の SessionStart matcher は `startup|resume|clear` のまま**:
  `.claude/settings.json` 側には `compact` を追加したが、Gemini CLI の SessionStart matcher が
  `compact` という値を解釈するかを実機で確認できていないため、あえて揃えていない。未検証の
  設定値を持ち込んで既存の動いている設定を壊さないという、[DDR 0018](../ddr/0018-gemini-settings.jsonのhooksはレビュー提示スニペットのhooksセクションのみ採用する.md)
  と同じ判断による。Gemini CLI 側の対応値が確認でき次第、追加を検討する。
- **（issue #57）注入量のしきい値8000バイトは実測1件（1,222バイト）に基づく暫定値**:
  「通常運用では鳴らず、数倍に膨らめば鳴る」水準として置いたもので、他プロジェクトへ機構を
  展開した際に適切かは未検証。`CONTEXT_SIZE_WARN_BYTES` 環境変数で上書きできるようにしてある。
- **（issue #57）警告文が実際にユーザーへ伝わるかはエージェントの応答に依存する**:
  `additionalContext` はエージェントへの指示であり、警告の表示を機構的に強制するものではない
  （hookが直接UIへ出す手段が無いため、`post-push-compact-prompt.sh` と同じ制約）。
- **（issue #68）`search_issues`のCLI経路が実機未検証**: 本対応はClaude Code on the webの
  リモート実行環境（`gh`/`glab` CLIが存在しない）で行ったため、`gh issue list --search ...
  --state all --json number,title,state,url` と `glab issue list --search ... --all --per-page
  ... --output json` を実際に実行しての確認ができていない。検証済みなのは、
  (1) `require_vcs_cli`が`search_issues`に対し`mcp__github__search_issues`を名指しして失敗すること、
  (2) 正規化・統合の純粋関数がCLI出力形式を模したフィクスチャに対して期待どおり動くこと
  （`.claude/scripts/test/test_vcs_provider.sh`）の2点のみ。**特にGitLab側の`--all`フラグ
  （opened/closed両方を対象にする指定）は`glab`のバージョンによって名称が異なる可能性がある**ため、
  `glab`が使える環境での最初の利用時に確認すること。

- **（issue #13）`get_mr_diff_url`/`get_mr_diff_since_url`のURL形式は実機（ブラウザ）で未検証**:
  GitHub実装（`<repoUrl>/compare/<from>...<to>`）はPR作成前から存在する汎用の「Compare changes」
  ページの標準URL形式に基づいており、PR個別のサブタブ形式（当初案の`/files/<from>..<to>`）より
  安定していると考えられるが、本対応ではブラウザでの表示確認まではできていない。GitLab実装
  （`<repoUrl>/-/compare/<from>...<to>`）についても、issue #48のGitLab実機検証で確認したのは
  API経由の動作のみで、ブラウザでのCompareページ表示は確認していない。
- **（issue #48・#45で部分解消）GitLab側の動作未検証**: かつては「このリポジトリの実remoteはGitHubのみ」を
  理由に`Gitlab.sh`全体が未検証だったが、issue #48でローカルにGitLab CE 18.5.4（Docker）を立て、
  `glab` 1.114.0から**全13関数を実機実行して動作を確認した**（`gitlab_get_mr_unresolved_comments`の
  解決済み含む分岐、`gitlab_add_mr_thread_reply`を含む）。この検証で3件の不具合が見つかり修正済み。
  ただしissue #48の時点では`get_provider`がself-hostedのGitLab URLを判定できなかったため、検証は
  `gitlab_*`関数を直接呼ぶ形で迂回しており、ディスパッチャ経由の経路が未検証のまま残っていた。
  **issue #45でこの判定を修正し、同じ環境で`Provider.sh`経由のディスパッチが通ることを確認した**
  （`get_provider` / `get_repo_url` / `get_issue` / `get_mr_for_branch` /
  `get_mr_unresolved_comments` / `add_mr_comment` / `set_mr_description` / `add_mr_thread_reply` /
  `get_mr_diff_url` / `get_mr_diff_since_url` / `get_workflow_config` /
  `get_issue_number_from_branch`）。残る未検証範囲は次の2点。
  - **バージョン・エディション**: 確認したのはCE 18.5.4の1バージョンのみ。gitlab.com（SaaS）・
    他バージョンでの挙動は未検証。
  - **プロジェクト構成**: 単一プロジェクト（`root/issue45-verify`）でしか確認しておらず、
    サブグループ・ネストしたnamespaceでの`glab`のプロジェクト解決は未検証。
- **他リポジトリへの移植性の検証**: `.mrworkflow.json` による切り出しで足りるか、実際に他リポジトリへ
  導入してみないと確認できない。
- **（issue #22で対応済み）全角文字のみのissueタイトルのスラッグ化**: `to_slug`（旧
  `ConvertTo-Slug`）はASCII英数字のみを残す簡易実装のため、「開発フローを変える」のような全角文字
  のみのタイトルは空文字となり `issue` にフォールバックしていた（実機確認: issue #3 で確認済み）。
  `to_slug`自体は変更せず、`start`サブコマンド実行時にAIエージェントがissueタイトルの意味を汲んだ
  英語の意訳フレーズを生成し`new_issue_branch`へ渡す方式で対応した（詳細:
  [0010-ブランチslugの意訳生成はAIエージェントが行う.md](../ddr/0010-ブランチslugの意訳生成はAIエージェントが行う.md)）。
- **`resume` の「現在地」判定の精度**: `get_branch_work_files` は `<defaultBaseBranch>` との差分で
  plan/worklogファイルを推定するヒューリスティックであり、複数issueを1ブランチで扱う等の
  変則的な運用では正しく機能しない可能性がある。本プロジェクトの通常運用（1ブランチ1issue）を
  前提とする。
- **（issue #15）`AskUserQuestion`で既定以外のベースブランチを選んだ場合の`get_branch_work_files`/
  `resume`とのズレ**: `new_issue_branch`は`start`サブコマンドの`AskUserQuestion`確認結果を
  ベースブランチとして受け取れるようになった（上記「提供関数」表参照）が、`get_branch_work_files`は
  常に`.mrworkflow.json`の`defaultBaseBranch`（設定ファイル固定値）との差分でplan/worklogファイルを
  推定する設計のままである。そのため、あるブランチが`defaultBaseBranch`以外をベースに作成された
  場合、`get_branch_work_files`（延いては`resume`のヒューリスティック）が実際のベースとズレた
  差分を返す可能性がある。本issueのスコープでは`get_branch_work_files`自体の改修は行っておらず、
  既定以外のベースブランチを選ぶ運用は上記の限界を許容できる場合に限る（今後の課題）。
- **（issue #6でbash化に伴い解消）`github_get_issue` は `gh` 失敗時に分かりにくい例外を出す**:
  PowerShell版（`GitHub-GetIssue`）では `gh issue view` が失敗した場合の`$LASTEXITCODE`チェックが無く、
  `ConvertFrom-Json` に空入力が渡って`$issue`が`$null`のまま`ConvertTo-Slug -Text $issue.title`が
  呼ばれ、`ParameterBindingValidationException`という原因の分かりにくい例外になっていた
  （issue #5対応時のSessionStart hook検証で実機確認）。bash版は`set -euo pipefail`により
  `gh issue view`自体の失敗時点で`gh`の元のエラーメッセージのまま関数が終了するため、この問題は
  発生しない。
- **SessionStart hookの実機（新規Claude Codeセッション）での動作確認が未実施**: 疑似stdin JSONを
  使った単体テストでは期待通りの挙動を確認したが、実際のセッション開始時にコンテキストへ反映される
  ことは本対応内では未確認。次回以降のセッション開始時に確認する。
- **新規行diff方式（issue #37）は、resumeによって新しい物理位置に再度書き出された重複行までは
  除外しない**: セッション横断カーソルが確実に防ぐのは「同じ行を同じ位置から二重に読むこと」のみで
  あり、「重複した内容が新しい位置（カーソルより後ろ）に現れること」までは防げない（意図的な設計。
  上記「新規行diff方式への移行」参照）。実際にどの程度の頻度・規模で重複が発生するかは実データでの
  継続観測が必要。
- **（issue #23で検証済み）`/compact`はtranscript JSONLを破壊しない**: カーソル方式・push断面の
  行範囲記録は「transcriptが追記専用であること」を前提にしているため、`/compact`がディスク上の
  ファイルを切り詰めるなら前提が崩れる。実機検証の結果、compactは
  `{"type":"system","subtype":"compact_boundary","compactMetadata":{...}}`という境界行と、
  要約本文を持つ`isCompactSummary: true`の行を**追記**するだけで、それより前の行を削除しないこと
  を確認した。`compactMetadata`の`preTokens`/`postTokens`は「次回以降**モデルへ送る**コンテキスト」
  の圧縮量であって、ディスク上のファイルサイズの話ではない。compact境界より前に記録されたpush断面が、
  compact後の現物transcriptの先頭N行とバイト単位で一致することも確認済み。詳細は
  [0022-push断面の全文コピーをやめ行番号インデックスで表現する.md](../ddr/0022-push断面の全文コピーをやめ行番号インデックスで表現する.md)
  参照。
- **Gemini CLI側のサブエージェント探索の前提が実態と合っていない可能性**（issue #3で判明、
  issue #23で`UsageTracking.sh`へ移植した際も未検証のまま引き継いだ）: Gemini CLI本体の
  [Issue #20258](https://github.com/google-gemini/gemini-cli/issues/20258)によれば、現行
  バージョンのGemini CLIではサブエージェントが親と同じセッションIDで動作するとの報告がある。
  これが事実であれば、「`transcript_path`のあるディレクトリ配下に`session_id`名のディレクトリで
  サブエージェントログが格納される」という前提と実際の挙動がズレている可能性がある。既存の保存動作を
  変更しない方針のため、この懸念への対応は見送っている。なおGemini分は対応工数の集計対象では
  ないため（上記「エンジン判定」節参照）、ズレていてもレポートの数値には影響しない。
- **`.gemini/settings.json`のスキーマは限定的にしか検証していない**: `hooks`セクションの内容は
  PRレビューで提示された実物を採用したが、Gemini CLI公式ドキュメント側の記載
  （[Hooks reference](https://geminicli.com/docs/hooks/reference/)）は`command`フィールドが
  `args`配列を持つか等、一部未文書化の挙動がある。実際にGemini CLI上での動作確認はできていない
  （Claude Code環境での実装のため）。issue #7で移植した`post-push-usage-report.sh`/
  `post-push-compact-prompt.sh`のGemini CLI実機検証も同様に未実施で、コードレビューベースの確認
  （`bash -n`構文チェック・パターン一致確認）に留まっている。
- **transcript JSONLの非公開フォーマット依存**: 対応工数レポート機能は、Claude Code非公開の
  内部フォーマットである`transcript_path`のJSONLを自前パースしている。将来のバージョンで形式が
  変わった場合、集計が0件になる（ベストエフォート設計のため実害は対応工数が記録されなく
  なるのみ）。詳細は
  [0006-対応工数レポートはtranscript自前パースで実装する.md](../ddr/0006-対応工数レポートはtranscript自前パースで実装する.md)
  参照。
- **トークン数（`tokensByModel`）は既知の過小カウント要因を持つ**（PR #29レビュー指摘、issue #28）:
  外部調査（[Claude Code JSONL logs undercount tokens](https://gille.ai/en/blog/claude-code-jsonl-logs-undercount-tokens/)）
  によると、Claude Codeのtranscript JSONLはストリーミング応答の開始時点で`usage.input_tokens`等に
  プレースホルダー値（0または1）を書き込み、応答完了後もその値を実際のトークン数へ更新しない
  ケースがあり、結果としてinput側で最大100〜174倍、output側で最大10〜17倍の過小カウントが
  観測されたと報告されている（キャッシュ関連フィールドはAPIレスポンス初期段階で確定するため
  影響を受けにくいとされる）。本機能はこの`transcript_path`を唯一の情報源として自前パースしている
  ため、同じ制約をそのまま引き継ぐ。稼働時間（`activeSeconds`）はトークン数ではなく
  `.timestamp`の差分のみを使うため、この過小カウント問題の影響を受けない（トークン数とは独立した
  精度特性を持つ）。回避策は確立されていない（ステータスバー等、他の情報源を使う代替案は
  transcriptの自前パースという設計方針自体を変えることになり、本機能のスコープ外）。レポート・
  ドキュメント双方で「目安」である旨を明記することで対応する（下記コンポーネント節、
  および`post-push-usage-report.sh`のコメント本文フッター参照）。
- **セッション（transcriptファイル）を跨いだ集計は未対応**: `/resume`等で新しいtranscriptファイルに
  切り替わった場合、旧セッション分の使用量との合算は行わない（新しい`session_id`として
  ゼロから集計が始まる）。
- **状態ファイル書き込みの排他制御が無い**: 複数のClaude Codeセッションが同一ブランチに対して
  同時にhookを発火させた場合、`usage/state/<branch>.json`（issue #37で`.claude/usage-state/`から
  移設）への読み書きにロックが無いため、一方の更新が失われる可能性がある（レースコンディション）。
  単一開発者が同一作業ディレクトリで複数セッションを同時実行する運用は想定しにくいため許容している。
- **ネストしたサブエージェント（depth 2以降）は未対応・未検証**（PR #29レビュー指摘）:
  サブエージェントの`meta.json`には`spawnDepth`フィールドが存在し、理論上サブエージェントが
  さらにサブエージェントを起動するネストがありうるが、このリポジトリの実データでは`depth 1`のみ
  観測され、ネスト時のディレクトリ構造・スキーマ自体が未確認のため対象外とした。将来ネストした
  構造が実際に使われるようになった場合、`_usage_aggregate_and_merge_subagents`の再帰的な拡張を
  別途検討する。
- **サブエージェントの`activeSeconds`はメインと別集計であり重複除去はしていない**（PR #29レビュー
  指摘）: サブエージェント自身のgapベース稼働時間と、メインセッション側の「Taskツール完了待ち」の
  区間（閾値未満なら稼働時間としてそのまま加算される）が時間的に重複しうる。単純合算するとwall
  clock時間より過大になるため、レポート上は両者を合算せず、サブエージェント分は参考値として
  別行に表示するに留めている。
- **（issue #6でbash化に伴い解消）投稿コメント本文へのBOM混入**: PowerShell版では`Add-MrComment`が
  読む一時ファイルを`Set-Content -Encoding UTF8`（Windows PowerShell 5.1既定でBOM付与）で書き出して
  いたため、GitHub上のコメント本文先頭に不可視のBOM文字が入っていた（表示上の実害は無く許容して
  いた）。bash版（`add_mr_comment`）はheredoc/printfでファイルを書き出しBOMが付与されないため、
  この問題は発生しない。
- **稼働時間（`activeSeconds`）は目安であり、2方向の誤差要因がある**（issue #28）:
  `IDLE_GAP_THRESHOLD_SECONDS`（既定300秒）未満の短い待機（人間がすぐ返信した場合等）は稼働時間に
  混入しうる一方、閾値以上の長時間ツール実行（大きめのビルド等）は逆に稼働時間から漏れる。
  加えて`TAIL_BUFFER_SECONDS`（既定30秒）は固定値のため、実際の読了・確認時間との過不足が生じる。
  いずれもgapベースの閾値判定という設計上の単純化によるもので、トークン集計と同様「目安」として
  扱う（レポート本文のラベルにも明記）。
- **複数セッション・複数プロジェクト同時進行時の稼働時間の重複除去（overlap dedup）は未対応**
  （issue #28）: 参考実装（`claude-work-timer`/`claude-code-time-tracking`）は複数セッションが
  並行した場合の区間重複を除去する機能を持つが、本対応のスコープ（単一ブランチ・単一セッション）
  では扱わない。仮に同一ブランチで複数セッションを並行実行した場合、それぞれの`activeSeconds`が
  単純合算され、実際の稼働時間より過大になりうる。
- **（issue #48で解消）（issue #25で追加した`gitlab_new_issue`にも従来からの制約が引き継がれる）GitLab側の動作未検証**:
  `gitlab_new_issue`はissue #48でローカルGitLab CE 18.5.4に対し実機確認済み（issueが実際に作成され、
  `get_issue`と同じ形のJSON（number/title/body/url/slug）が返ることを確認した）。
