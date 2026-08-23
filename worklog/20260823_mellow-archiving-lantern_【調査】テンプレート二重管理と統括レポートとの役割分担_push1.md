---
title: worklog: 【調査】テンプレート二重管理と統括レポートとの役割分担
type: log
description: issue #145 フェーズ2（調査）の試行錯誤ログ（push1）
tags: [worklog, issue-mr-flow, template]
keywords: [調査, 二重管理, describe, 統括レポート, dist-layers, 非対話セッション]
---

# worklog: 【調査】テンプレート二重管理と統括レポートとの役割分担

対象: MR/PRテンプレートをアーカイブとして再設計する（2026-08-23）。
全体作業計画: `plans/mellow-archiving-lantern.md`
個別作業計画: `plans/【調査】テンプレート二重管理と統括レポートとの役割分担.md`
push回数: 1

## 試したこと

- `get_vcs_access_mode` を実行し、この実行環境が `mcp` 経路であることを確認した
  （`gh`/`glab` CLIが無い。`references/mcp-fallback.md` の読み替えに従う）。
- Draft PRの作成: ブランチがbaseと完全に同一（ahead 0 / behind 0）だったため、
  `mcp__github__create_pull_request` をそのまま呼ぶと「No commits between」で失敗する状態だった。
  `add_empty_commit_for_draft_mr` で空コミットを1つ積んでからPRを作成し、PR #187 を得た。
- HTMLビューの生成手順: テンプレートの `<!DOCTYPE html>` 〜 `</head>` を `sed -n` で切り出し、
  `<title>` だけを差し替えてから本文をヒアドキュメントで追記する形にした。スクラッチパッドへ
  `mkhtml.sh` として置き、後続の計画・レポートでも使い回す。

## うまくいったこと

- 上記の `mkhtml.sh` により、テンプレートの `<style>` を1バイトも触らずにHTMLビューを作れる
  （自己完結性・ダークモード対応がテンプレートのまま保たれる）。
- 生成後の検査を3本（プレースホルダ残存・`src`/`href` の外部参照・`url()`/`@import` の外部参照）
  そのまま実行できる形にした。いずれも0件を確認。

## ダメだったこと

- `mkhtml.sh` の初版で `printf '\-\->\n'` と書いたところ、bashの `printf` が `-->` を
  **オプションとして解釈**して `printf: --: invalid option` で失敗した。
  `printf '%s\n' '-->'` へ書き換えて解消した。
  （`.claude/rules/shell-script-style.md`「JSON操作」が `jq --args` / `grep` について書いている
  「ハイフンで始まる値」の問題と同根。**`printf` でも同じことが起きる**。）

## 次の一歩

- flow-id 2-2（commit・push）のあと、敵対的レビュー（フェーズ2・1回目）を計画に対して実施する。
