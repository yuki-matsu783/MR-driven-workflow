---
title: worklog 20260819 【調査】インラインコメント投稿APIとセッション種別判定 push2
type: log
description: issue #77 フェーズ2の作業ログ（push2）。調査1（GitHubインライン投稿）・3（AUTOMATION）・4（MCP経路）・2（GitLab）の実施記録。
tags: [worklog, issue-mr-flow, research]
keywords: [worklog, issue77, インラインコメント, reviews API, AUTOMATION, CLAUDE_CODE_ENTRYPOINT, MCP, GitLab, discussions]
---

# worklog: 【調査】インラインコメント投稿APIとセッション種別判定（push2）

対象: issue #77 MRへの敵対的レビューを行うスキル・専任サブエージェントを追加する（2026-08-19）。
全体作業計画: `plans/prancy-herding-kahan.md`
個別作業計画: `plans/【調査】インラインコメント投稿APIとセッション種別判定.md`
push回数: 2

## 試したこと

### 調査3: 実行モードの判定（`AUTOMATION`）

- このセッション（VSCode拡張＝対話）で `echo "AUTOMATION=${AUTOMATION:-unset}"` → `unset`。
- `env | grep -iE 'claude|automation|ci|term|agent'` で、Claude Codeが実際に設定している変数を
  洗い出した（`CLAUDECODE=1` / `CLAUDE_CODE_ENTRYPOINT=claude-vscode` /
  `AI_AGENT=claude-code_2-1-235_agent` / `CLAUDE_CODE_CHILD_SESSION=1` など）。
- 非対話経路を実機で再現するため、親から継承した `CLAUDE_CODE_*` 系を `env -u` で消したうえで
  `claude -p "<Bashで env を出力させるプロンプト>" --model haiku --allowedTools Bash` を実行した。
- 同じ形で `AUTOMATION=1 env -u ... claude -p ...` も実行し、環境変数が子セッションの
  Bashツールまで伝播するかを確かめた。
- TTY判定が使えるかも確認した（`[ -t 0 ]` / `[ -t 1 ]`）。

### 調査1: GitHubのインラインコメント投稿（PR #80 上で実機）

`gh api repos/{owner}/{repo}/pulls/80/reviews --input <file>` を5パターン試した。

1. 有効な2件（ASCIIパス＋日本語パス、いずれも新規ファイル）を1レビューに同梱
2. 有効1件＋PRで変更していないファイル（`README.md`）を同梱
3. 変更ファイル内だがhunk外の行（`HANDOFF.md:5`）を単独指定
4. hunk内のコンテキスト行（変更されていない行。`HANDOFF.md:15`）を単独指定
5. `start_line`〜`line` の複数行指定

あわせて、`subject_type: "file"`（行を特定しないファイル単位コメント）を
`pulls/80/reviews` と `pulls/80/comments` の両方で試した。
投稿後は `get_mr_unresolved_comments 80` で既存の `comments` サブコマンドから見えるかを確認し、
`patch` のhunkヘッダから「投稿可能な行番号の集合」をawkで算出して実機の成否と突き合わせた。

### 調査4: MCP経路

- `ToolSearch` でこの実行環境に `mcp__github__*` が無いことを確認（＝実機検証は不可）。
- `github/github-mcp-server` の README・`pkg/github/pullrequests.go` を参照し、
  レビュー系ツール名と `method` / `subjectType` の許容値を確認した。

### 調査2: GitLabのインラインコメント投稿（docker上のGitLab CEで実機）

- issue #48 で構築済みのコンテナ（`gitlab/gitlab-ce:18.5.4-ce.0`、`external_url http://localhost:8929`）が
  停止状態で残っていたため、イメージのpullをせずに `docker start gitlab` で再利用した
  （healthyまで約8分。バックグラウンドの `until` ループで待った）。
- `glab` は `--hostname localhost:8929` を受け付けない（`invalid hostname`）ため、
  `GITLAB_HOST=localhost:8929` を環境変数で渡した。トークンはOSのkeyringに残っていた。
- gitのcloneをせず、Repository Files API と Merge Requests API だけで検証データを作った。
  `sample.txt`（10行）を `main` へ作成 → ブランチ `issue77-inline-test` を切る →
  「1行変更・1行削除・1行追加」して更新 → MR `!3` を作成。
- `discussions` へ `position` 付きで、新規行（`new_line` のみ）・削除行（`old_line` のみ）・
  コンテキスト行（両方）の3ケースを投稿した。あわせて、存在しない行（`new_line: 999`）・
  存在しないパスの2ケースと、`-F 'position={...}'` でネストを渡す方式も試した。

## うまくいったこと

- **複数指摘を1レビューにまとめられる**（`comments[]` に並べて1リクエスト）。レビュアーへの
  通知も1回に収まる。日本語を含むパスもそのまま通り、`files` APIの `filename` も
  percent-encodeされずに返る。
- **hunk内のコンテキスト行（変更されていない行）にも投稿できる**。「変更行しか指せない」
  という制約ではなく、「diffに現れる行なら指せる」が正しい。
- **`patch` のhunkヘッダから投稿可能な行を機械的に算出できる**。`HANDOFF.md` では 14〜107 の
  94行が有効と算出され、実機の結果（`line=5` は422、`line=15` は成功）と一致した。
- **複数行指定（`start_line` + `line`）も投稿できる**。
- 投稿したスレッドは `get_mr_unresolved_comments`（GraphQL `reviewThreads`）に
  **`unresolved` として現れる**。既存の `comments` サブコマンドがそのまま指摘一覧として使える。
- **`AUTOMATION=1` は子セッションのBashツールまで伝播する**（`AUTOMATION=1 claude -p ...` →
  子の `echo` で `AUTOMATION=1`）。「非対話で起動する側が明示的に設定する」という運用契約が
  技術的に成立する。
- **`CLAUDE_CODE_ENTRYPOINT` が対話／非対話で明確に変わる**（VSCode拡張=`claude-vscode`、
  `claude -p`=`sdk-cli`）。補助材料として使える。
- **MCP経路でもインライン投稿は可能**。`pull_request_review_write(method="create")` →
  `add_comment_to_pending_review`（`path`/`line`/`side`/`startLine`/`startSide`/`subjectType`）→
  `pull_request_review_write(method="submit_pending", event="COMMENT")` の3段構成。
  `method` の許容値は `create` / `submit_pending` / `delete_pending` / `resolve_thread` /
  `unresolve_thread`、`subjectType` は `FILE` / `LINE`。

- **GitLabの `position` は `diff_refs` の3つのsha（`base_sha`/`start_sha`/`head_sha`）を
  そのまま展開すれば足りる**。`versions` APIは不要だった。新規行・削除行・コンテキスト行の
  3ケースとも投稿できた。
- 投稿したDiffNoteは `resolvable: true` / `resolved: false` となり、既存の
  `gitlab_format_discussion_notes` から **`unresolved` として拾えた**（改修なしで
  `comments` サブコマンドに乗る）。
- 検証データはgitのcloneなしに、Repository Files API と Merge Requests API だけで作れた。

## ダメだったこと

- **1件でも不正な指摘が混ざると、レビュー全体が422で失敗する**（原子的）。有効な指摘まで
  投稿されないことを、失敗後に `pulls/80/comments` が2件のまま（＝有効分も未投稿）である
  ことで確認した。**投稿前に行の妥当性を検証する処理が必須**。
  - エラーメッセージは原因で分かれる。存在しない／diff対象外のファイル →
    `Path could not be resolved`、変更ファイル内のhunk外の行 → `Line could not be resolved`。
- **提出済みレビューは削除できない**（`DELETE .../reviews/<id>` →
  `Can not delete a non-pending pull request review`）。インラインコメント個別は
  `DELETE /pulls/comments/<id>` で消せるが、レビューのサマリ本文は `PUT` で書き換えるしかない。
  テスト投稿の後片付けが完全にはできないため、**本番でも「投稿は取り消せない」前提で
  承認モデルを設計する必要がある**。
- **`pulls/<n>/reviews` の `comments[]` は `subject_type` 非対応**
  （`Field is not defined on DraftPullRequestReviewComment` かつ `position` 必須）。
  ファイル単位コメントは `POST /pulls/<n>/comments` に `subject_type=file` と `commit_id` を
  渡す別経路でのみ可能で、レビューへまとめられない（＝通知が個別に飛ぶ）。
- **TTYの有無は判定材料にならない**。対話セッションのBashツールでも `stdin`/`stdout` とも
  非TTYだった。
- `AUTOMATION` はClaude Codeが自動で設定する変数**ではない**。非対話（`sdk-cli`）でも未設定
  だったため、**「`AUTOMATION=1` があれば非対話」は成立するが、その逆（非対話なら必ず
  `AUTOMATION=1`）は成立しない**。計画どおり「未設定＝対話モード＝AIからの起動禁止」へ倒す。
- `gh` CLIの引数順に注意が要る。`--allowedTools` は可変長引数のため、
  `claude -p --allowedTools Bash "<プロンプト>"` と書くとプロンプトが `--allowedTools` に
  吸収され `Input must be provided either through stdin or as a prompt argument` になる。
  プロンプトは `-p` の直後に置く。

- **`glab api --input <file>` はContent-Typeヘッダを付けない。** そのままPOSTすると
  HTTP 415（`The provided content-type '' is not supported.`）になる。
  **`-H "Content-Type: application/json"` の明示が必須**。`gh api --input` との差なので、
  `Gitlab.sh` 側の実装で取り違えやすい。
- **`-F 'position={...}'` でネストしたオブジェクトを渡す方式は使えない**（400
  `line_code can't be blank`）。`--input` でボディ全体をJSONとして渡す一択。
- **MR作成直後は `diff_refs` が `null`**（diffが非同期に計算される）。作成のレスポンスを
  そのまま使うとpositionを組み立てられない。数秒待って再取得する必要がある。
- **GitLabは不正な行と存在しないパスを区別しない**。どちらも同じ400
  （`Note {:line_code=>["can't be blank", "must be a valid line code"]}`）で、
  エラーメッセージから原因を切り分けられない。
- 起動直後のGitLabはAPIが不安定で、`wsarecv: An existing connection was forcibly closed` が
  2回発生した。`healthy` になっても即座に安定するわけではないため、検証スクリプトは
  リトライ前提で書く必要がある（このとき `$(...)` の中身が空になり、後続の
  `jq --argjson` が `invalid JSON text` で失敗するという形で表面化した。
  `.claude/rules/shell-script-style.md` の「外部状態を `--argjson` へ渡す前に検証する」
  と同じ構図）。
- 既存の `gitlab_format_discussion_notes` は **ファイルパス・行番号を出力していない**
  （GitHub版は `path:line` を出す）。インライン投稿を入れるとこの差が実害になる。

## 次の一歩

- `reports/` のHTMLに調査結果をまとめ、flow-id 2-7（commit・リモートへ反映・レビュー依頼）へ進む。
- フェーズ3の作業計画に、`gitlab_format_discussion_notes` へ `position` を出力する改修を含める。
- GitLabコンテナは停止済み（削除していない）。フェーズ3の実装確認で `docker start gitlab` から再開する。
