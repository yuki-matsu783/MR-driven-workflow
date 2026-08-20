---
title: worklog 20260820 issue43 調査（push1）
type: log
description: issue #43 のレビューコメント出力仕様見直しにおける、調査フェーズの試行錯誤ログ
tags: [worklog, investigation, vcs]
keywords: [diffHunk, GraphQL, discussions, shallow, blob, スライス, 断面]
---

# worklog: 【調査】レビューコメント取得APIの返却フィールドと断面

対象: issue #43 レビューコメント取得の出力仕様見直し（2026-08-20）。
全体作業計画: `plans/issue43-review-comment-source-slice.md`
個別作業計画: `plans/【調査】レビューコメント取得APIの返却フィールドと断面.md`
push回数: 1

## 試したこと

- `get_vcs_access_mode` を実行して経路を確認 → `mcp`（`gh`/`glab` CLI不在）。
- `check-base-sync.sh` で `main` への追従を確認 → `isBehind: false` / `isShallow: true`。
  **この環境は shallow clone である**ため、コメント時点の sha の blob がローカルに無い可能性が高い。
  調査項目Cの前提として重要。
- `add_empty_commit_for_draft_mr` が `git push`（upstream未設定）で失敗した。ブランチが
  リモートに存在していても、ローカルに upstream 追跡設定が無いと失敗する。
  `git push -u origin <branch>` で解消した。

- 調査項目E: `get_mr_unresolved_comments` の消費者を洗い出した。`session-start.sh:169` が
  `grep -oE '^\[review unresolved threadId=[^ ]+'` で**行頭の書式**に依存している。
  → **出力書式の先頭は変えられない**という制約が確定した。
- 調査項目A: `mcp__github__pull_request_read (method="get_review_comments")` を PR #37 へ実行し、
  返却JSONのキーを実測した。
- 調査項目C: `git rev-parse --is-shallow-repository` / `git cat-file -e <sha>:<path>` を
  過去4commitに対して実行した。
- 調査項目D: `sed -n "${s},${e}p" | wc -c` で、指摘行を変えながら ±10行のバイト数を実測した。

## うまくいったこと

- 空コミット＋pushの後、`mcp__github__create_pull_request` で Draft PR #131 を作成できた
  （baseとの差分が無い状態では作成できない制約は、MCP経路でもCLI経路と同じだった）。
- **shallow clone でも過去commitのblobが引けた**（4commit中4件OK）。「shallowだからローカルでは
  断面を切れない」という当初の見立ては誤りで、切断点より新しいcommitなら解決できる。
  ただし保証は無いのでフォールバックは残す。
- **行数指定が上限として機能しないことを実測で示せた**（同一ファイルの ±10行で 684B〜8,971B、
  13.1倍）。issue本文の 5,107B という値も同じ範囲に収まっており、issueの主張の裏が取れた。
- **副次的な不具合を1つ見つけた**: 行頭ラベルが GitHub `[review unresolved ...]` /
  GitLab `[unresolved ...]` と非対称で、GitLabリポジトリでは `session-start.sh` の未解決件数が
  常に0件になる。整形の共通化で副次的に直る。

## ダメだったこと

- **GitHub GraphQL の実フィールドを実行検証できなかった。** この環境に `gh` が無い。
  代替として MCP の `get_review_comments` を叩いたが、こちらは **`line` も sha も返さない**
  別APIで、GraphQLのフィールド有無の裏取りにはならなかった。公開スキーマに基づく設計とし、
  実装は null 耐性を持たせる方針へ切り替えた（【未検証】として明示する）。
- `git cat-file -e` の失敗メッセージが
  `fatal: path '...' exists on disk, but not in '<sha>'` となり、**「ワーキングツリーにはある」
  ことを先に言う**ため、一瞬「成功したのか？」と読み違えた。判定は終了コードで行うこと。

## 次の一歩

- flow-id 2-7（commit・push）→ 3-1（個別作業計画）へ進む。
