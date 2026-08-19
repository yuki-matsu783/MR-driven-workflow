---
title: 調査結果 インラインコメント投稿APIとセッション種別判定
type: report
description: issue #77 フェーズ2（flow-id 2-6）の調査結果。GitHub/GitLabのインラインコメント投稿API・非対話セッション判定・MCP経路での縮退を実機で確かめた記録。
tags: [issue-mr-flow, research, review, api]
keywords: [インラインコメント, pulls reviews, discussions, position, diff_refs, AUTOMATION, 非対話, MCP, GitLab, 調査結果]
---

# 調査結果: インラインコメント投稿APIとセッション種別判定

- 対象: issue #77 / PR #80（実施日: 2026-08-19、flow-id 2-6）
- 調査計画: `plans/【調査】インラインコメント投稿APIとセッション種別判定.md`
- 詳細な試行錯誤: `worklog/20260819_prancy-herding-kahan_【調査】インラインコメント投稿APIとセッション種別判定_push2.md`
- 視覚的なまとめ: `reports/20260819_prancy-herding-kahan_インラインコメント投稿APIとセッション種別判定.html`

## 調査1: GitHubのインラインコメント投稿（PR #80 上で実機確認）

| 確認項目 | 結果 |
|---|---|
| 複数指摘を1レビューにまとめられるか | **できる**。`comments[]` に並べて `pulls/<n>/reviews` へ1リクエスト。通知も1回 |
| 1件でも不正なときの巻き添え | **レビュー全体が422で失敗し、有効な指摘も投稿されない**（原子的） |
| 失敗時のエラー | diff対象外のファイル → `Path could not be resolved`／変更ファイル内のhunk外の行 → `Line could not be resolved` |
| 投稿できる行の範囲 | **diffに現れる行すべて**。変更行だけでなく**hunk内のコンテキスト行**（`HANDOFF.md:15`）にも付けられた |
| 複数行指定 | `start_line` + `start_side` + `line` + `side` で**できる** |
| 日本語パス | **そのまま通る**。`pulls/<n>/files` の `filename` もpercent-encodeされずに返る |
| `comments` サブコマンドからの見え方 | GraphQL `reviewThreads` に **`unresolved` として現れる**。既存の `get_mr_unresolved_comments` がそのまま指摘一覧として使える |
| ペイロードの渡し方 | `gh api ... --input <ファイル>` で渡せる（コマンドライン引数へ埋め込まない） |
| 投稿の取り消し | **インラインコメントは `DELETE /pulls/comments/<id>` で消せるが、提出済みレビュー本体は消せない**（`Can not delete a non-pending pull request review`）。サマリ本文は `PUT` での書き換えのみ |
| ファイル単位コメント | `pulls/<n>/reviews` の `comments[]` は `subject_type` **非対応**。`POST /pulls/<n>/comments` に `subject_type=file` + `commit_id` を渡す**別経路でのみ可能**（レビューにまとめられず通知が個別に飛ぶ） |

**設計への反映**:

- **投稿前に「その行がdiffに含まれるか」を必ず検証する**。`pulls/<n>/files` の `patch` から
  hunkヘッダを読んで新ファイル側の有効行集合を算出できることを実機で確認した
  （`HANDOFF.md` で 14〜107 の94行と算出され、`line=5` が422・`line=15` が成功という実機結果と一致）。
  検証は純粋関数として切り出し、単体テストの対象にする。
- 行が特定できない指摘・有効行の外にある指摘は、**レビュー本文（サマリ）へ集約する**
  （ファイル単位コメントの別経路は、通知が分散するうえ経路が二重になるため採らない）。
- **投稿は取り消せない**。承認モデル（起動時1回の承認）と投稿上限は、この前提で設計する。
- `patch` はファイルが大きい場合にAPIから省略されることがある。その場合は有効行を算出できない
  ため、当該ファイルの指摘はサマリへ回す。

## 調査2: GitLabのインラインコメント投稿

docker上のGitLab CE 18.5.4（issue #48で構築したコンテナを再利用。`external_url http://localhost:8929`）で、
テスト用MR（`root/issue45-verify` !3、`sample.txt` を「1行変更・1行削除・1行追加」した差分）に対して
`projects/:id/merge_requests/<iid>/discussions` を実際に叩いた。

| 確認項目 | 結果 |
|---|---|
| `position` の必須項目 | `base_sha` / `start_sha` / `head_sha` / `old_path` / `new_path` / `position_type: "text"` ＋ 行指定 |
| 取得元 | **MR JSONの `diff_refs` だけで足りる**（`versions` APIは不要）。3つのshaをそのまま展開して使える |
| `diff_refs` の取得タイミング | **MR作成直後は `null`**（diffが非同期に計算される）。取得できるまで数秒待って再取得する必要がある |
| 新規行（`new_line` のみ） | **投稿できる** |
| 削除行（`old_line` のみ） | **投稿できる** |
| コンテキスト行（両方指定） | **投稿できる** |
| `glab api` でのネストしたパラメータ | **`-F 'position={...}'` は不可**（`line_code can't be blank` で400）。**`--input <ファイル>` を使う** |
| `--input` の落とし穴 | **`-H "Content-Type: application/json"` を明示しないとHTTP 415**（`The provided content-type '' is not supported.`）。`glab api --input` はContent-Typeを自動で付けない |
| 不正な行・存在しないパス | いずれも同じ400（`Note {:line_code=>["can't be blank", "must be a valid line code"]}`）。**GitHubと違い原因が区別できない** |
| 巻き添え | **無い**（1リクエスト1指摘のため、GitHubのような原子的失敗が起きない。裏を返すと通知は指摘ごとに飛ぶ） |
| `comments` サブコマンドからの見え方 | 投稿したDiffNoteは `resolvable: true` / `resolved: false` となり、既存の `gitlab_format_discussion_notes` から **`unresolved` として拾える** |

**設計への反映**:

- `gitlab_add_mr_inline_comments` は **findings JSONファイルを受け取り、1件ずつ `--input` で
  POSTする**実装にする（`-H "Content-Type: application/json"` を必ず付ける）。`diff_refs` は
  関数の先頭で1回だけ取得し、取得できなければ数秒待って1回再取得する。
- **GitHubとGitLabで失敗の粒度が違う**（GitHub＝全件巻き添え／GitLab＝当該1件のみ失敗）。
  共通インターフェースの戻り値は「投稿できた件数／できなかった指摘の一覧」に揃え、
  呼び出し側がこの差を意識せずに済むようにする。
- **投稿前の行検証はGitLab側でも必要**。エラーメッセージから原因を切り分けられないため、
  400が返った時点では「パスが違うのか行が違うのか」を利用者へ説明できない。
- 既存の `gitlab_format_discussion_notes` は **ファイルパス・行番号を出力していない**
  （GitHub版は `path:line` を出す）。インライン投稿を導入するとこの差が実害になるため、
  `position` から `new_path:new_line`（削除行なら `old_path:old_line`）を出力へ含める改修を
  フェーズ3の作業計画に含める。
- 検証環境はフェーズ3の実装確認でも使い回せるよう、**コンテナは停止のみ（削除しない）**とし、
  テスト用MR `!3` とブランチ `issue77-inline-test` も残した。テスト投稿したdiscussionは削除済み。

## 調査3: 非対話セッションの判定（`AUTOMATION` 環境変数）

| 確認項目 | 結果 |
|---|---|
| 対話セッション（VSCode拡張）の `AUTOMATION` | **`unset`** |
| 非対話（`claude -p`）の `AUTOMATION` | **`unset`**（Claude Codeが自動設定する変数ではない） |
| `AUTOMATION=1` を明示した場合の伝播 | **子セッションのBashツールまで正しく伝播する**（`AUTOMATION=1 claude -p ...` → 子で `AUTOMATION=1`） |
| `CLAUDE_CODE_ENTRYPOINT` | 対話（VSCode拡張）= **`claude-vscode`** ／ 非対話（`claude -p`）= **`sdk-cli`** |
| TTYの有無 | **判定材料にならない**（対話セッションのBashツールでも stdin/stdout とも非TTY） |

**結論**: **`AUTOMATION=1` を非対話モードの唯一の判定材料とする。** Claude Codeが自動で設定する
変数ではないため「非対話なら必ず `AUTOMATION=1`」は成立しないが、**逆向き（`AUTOMATION=1` なら
非対話として扱ってよい）は運用契約として成立する**。未設定・他の値はすべて対話モード
（＝AIからの自律起動を禁止）へ倒す。判定を誤ったときに「勝手に動く」側ではなく「動かない」側へ
倒れるため、この非対称性は許容できる。

`CLAUDE_CODE_ENTRYPOINT` は補助材料として記録に留め、**判定には使わない**（値の網羅性を
こちらで保証できず、将来増えた値を「対話」と誤認する危険があるため）。

## 調査4: MCP経路でのインライン投稿

**MCP経路でもインライン投稿は可能**。ただしCLI経路と手順・失敗の粒度が異なる。

| | CLI経路（`gh api`） | MCP経路（`mcp__github__*`） |
|---|---|---|
| 手順 | `pulls/<n>/reviews` へ1リクエスト | `pull_request_review_write(method="create")` → `add_comment_to_pending_review` を指摘ごとに → `pull_request_review_write(method="submit_pending", event="COMMENT", body=...)` |
| 不正な行の扱い | **レビュー全体が失敗**（原子的） | **その指摘の追加だけが失敗**し、他はpendingに残る |
| ファイル単位コメント | 不可（別経路が必要） | `subjectType="FILE"` で**可能** |

`method` の許容値は `create` / `submit_pending` / `delete_pending` / `resolve_thread` /
`unresolve_thread`、`subjectType` は `FILE` / `LINE`。`add_comment_to_pending_review` の引数は
`owner` / `repo` / `pullNumber` / `body` / `path` / `subjectType`（必須）と
`line` / `side` / `startLine` / `startSide`（任意）。

**設計への反映**: 対応表へ3ツールを追記する。**pending reviewを作ったまま提出せずに終わると
中途半端な状態が残る**ため、MCP経路では「`create` → 全件追加 → 必ず `submit_pending` まで
実行する（途中で失敗したら `delete_pending` で片付ける）」を手順として明記する。
なお、この実行環境には `mcp__github__*` が無く実機検証はできていない（公式リポジトリの
README・`pkg/github/pullrequests.go` の記述に基づく）。
