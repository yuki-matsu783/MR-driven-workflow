---
title: worklog 【設計】【実装】gh/glab CLI不在時のMCPフォールバック経路
type: log
description: issue #34（MCPフォールバック経路の実装）のpush1時点の作業ログ。経路判定・ガード・hook縮退の実装で試したこと
tags: [worklog, mcp, provider, issue34]
keywords: [get_vcs_access_mode, require_vcs_cli, parse_repo_slug, session-start, post-push, sed, jq, テスト]
---

# worklog: 【設計】【実装】gh/glab CLI不在時のMCPフォールバック経路

対象: issue #34（`gh`/`glab` CLI不在環境向けのMCPフォールバック経路）（2026-08-18）。
全体作業計画: `plans/steady-bridging-gateway.md`
個別作業計画: `plans/【設計】【実装】gh-glab不在時のMCPフォールバック経路.md`
push回数: 1

## 試したこと

- 本セッションの実行環境（Claude Code on the webのリモート実行環境）で `command -v gh glab` を
  確認 → **どちらも存在せず、`jq`・`git` のみ**。issue本文の記述どおりであることを実機で再確認した。
- `Provider.sh` へ経路判定（`get_vcs_access_mode`）・リモートURLパース（`parse_repo_slug` /
  `get_repo_slug`）・MCPツール名の提示（`mcp_tool_hint`）・ガード（`require_vcs_cli`）を追加し、
  プロバイダ依存の8関数（`get_issue` / `new_issue` / `new_draft_merge_request` /
  `get_mr_unresolved_comments` / `add_mr_thread_reply` / `get_mr_for_branch` /
  `set_mr_description` / `add_mr_comment`）の先頭へ `require_vcs_cli <自関数名> || return 1` を挿入。
- MCPツールの引数名は記憶で書かず、実際のツール定義（`mcp__github__*` のJSONSchema）を参照して
  対応表を作成した。特に以下は定義を見なければ間違えていた点:
  - `add_reply_to_pull_request_comment` は **数値の `commentId`** を取り、GraphQLのthreadId
    （`PRRT_...`）は使えない（CLI経路の `add_mr_thread_reply` はthreadIdを渡す設計なので、
    ID体系がそのまま置き換えられない）。
  - `add_issue_comment` はPR番号を `issue_number` に渡す。
  - 未解決スレッドの絞り込みは、CLI経路ではスクリプト側（jqの `select`）でやっていたが、
    MCP経路では呼び出し側が `isResolved` を見て自分で行う必要がある。
- 実機確認: `get_vcs_access_mode` → `mcp`、`get_repo_slug` → owner/repoが取れること、
  `get_issue 34` がMCPツール名入りのメッセージを出して終了コード1で失敗すること。
- `session-start.sh` をMCP経路対応にし、`bash .claude/hooks/session-start.sh <<< '{}'` で
  実際の注入内容を確認。
- `post-push-compact-prompt.sh` を、pushを模したhook入力（`tool_input.command` に該当コマンド）で
  実行し、MRリンク行がMCP取得指示に差し替わり、Compare URLが従来どおり出ることを確認。
- `tests/test_vcs_provider.sh` に `parse_repo_slug`（6ケース）・`mcp_tool_hint`（4ケース）を追加。
  全テスト（4ファイル）を実行して `failures=0` を確認。

## うまくいったこと

- **CLI不在を「失敗させたうえで代替手段を名指しする」設計**にしたのが良かった。単に対応表を
  ドキュメントへ書くだけだと、エージェントが手順を読まずCLIを呼んだ場合に
  `gh: command not found` で終わり、結局その場の判断に戻ってしまう。ガードにより、
  どの経路から入っても同じ案内へ収束する。
- `get_repo_url` だけはガードの例外とし、`git remote get-url origin` のパースへフォールバックした。
  これにより `get_mr_diff_url` / `get_mr_diff_since_url` がMCP経路でも動き、
  `post-push-compact-prompt.sh` のレビュー依頼メッセージ（Compare URL）を残せた。
  「CLIが無いと何も出ない」から「MRリンクだけ欠ける」へ縮退の度合いを下げられた。
- `session-start.sh` の既存挙動が **`gh` の失敗を握りつぶして「PR: なし」と表示していた**
  （PRがあっても無いと伝わる）ことに気づけた。誤情報を注入するより悪いことは無いので、
  「未取得（PRなしという意味ではない）」へ変更した。

## ダメだったこと

- `parse_repo_slug` の最初の実装（`${var#...}` によるパラメータ展開だけで組む案）は、
  scp形式（`git@host:o/r.git`）とhttps形式でホスト部の区切りが `:` と `/` で異なるため、
  同じ順序の展開では両方を正しく処理できなかった（scp形式で `owner` が欠落する）。
  `sed -E` の連続置換に切り替えて解決。ポート付き `ssh://host:2222/o/r` も
  `s#^[0-9]+/##` の1行で吸収した。
- `require_vcs_cli` のメッセージ組み立てで `printf '...: %s' "$(mcp_tool_hint ...)"` と書いたところ、
  コマンド置換が末尾の改行を落とすため次の行と繋がって表示された。書式側を `%s\n` にして修正。

## 次の一歩

- フェーズ4（設計反映）: `.claude/docs/spec/issue-mr-workflow.md` への反映とDDR 0025の新設。
- GitLab MCPサーバーを実機検証できる環境が得られたら、SKILL.mdの対応表にGitLab行を追加する
  （現時点では対象外と明記）。

---
