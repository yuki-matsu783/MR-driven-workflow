---
name: issue-create
description: issueをAIエージェントが起票（作成）したいときに使う。issue-mr-flowのflow-id 1-1（人間による起票）をAIが代行する手段。ユーザーからの依頼内容をもとに目的・現状・期待する動作・受け入れ条件の4見出しを組み立て、ユーザーの確認を得たうえで.claude/scripts/src/create-issue.shを呼び出しGitHub/GitLab上にissueを作成する。issueをUIを使わずAIから起票したい場合に使う。
title: issue起票（AI代行）
type: skill
tags: [issue, automation, github, gitlab]
keywords: [issue作成, create-issue.sh, 目的, 現状, 期待する動作, 受け入れ条件, テンプレート, issue-mr-flow]
---

# issue起票（AI代行）

`.claude/skills/issue-mr-flow/SKILL.md`（唯一の実装フロー定義）のflow-id 1-1「issueを起票する」は
本来人間の担当だが、本スキルはAIエージェントがそれを代行するための手順を定義する。issue取得後の
ブランチ・Draft MR作成（flow-id 1-2〜1-3）は対象外であり、そこから先は通常どおり
`/issue-mr-flow start <issue番号>` を使う。

## 実行フロー

1. ユーザーの依頼内容から、issueに必要な5項目（タイトル・目的・現状・期待する動作・受け入れ条件）
   を埋められるか確認する。`.github/ISSUE_TEMPLATE/task.md` / `.gitlab/issue_templates/task.md`
   と同じ4見出し構成に対応する。情報が不足している場合は、AskUserQuestionまたは通常のチャットで
   ユーザーに質問して補う。**依頼内容から読み取れない項目を勝手に創作しない。**
2. 組み立てたタイトルと4項目の内容をユーザーに提示し、issueとして作成してよいか確認を取る
   （GitHub/GitLab上に公開される操作のため、他のissue-mr-flowサブコマンド同様、明示的な合図を
   待ってから実行する）。
3. 承認を得たら、以下の形で `.claude/scripts/src/create-issue.sh` を実行する。

   ```bash
   .claude/scripts/src/create-issue.sh \
     --title "<タイトル>" \
     --purpose "<目的>" \
     --current "<現状>" \
     --expected "<期待する動作>" \
     --acceptance "<受け入れ条件>"
   ```

   標準出力に作成されたissueのJSON（`number`/`title`/`body`/`url`/`slug`）が返る。

   **`gh`/`glab` CLIが無い実行環境（Claude Code on the webのリモート実行環境等）では、
   `create-issue.sh` は内部の `new_issue` が失敗するため使えない**（issue #34）。
   `source .claude/scripts/src/vcs/Provider.sh && get_vcs_access_mode` が `mcp` を返す場合は、
   次のように読み替える（GitHubのみ。GitLabは対象外。詳細:
   `.claude/skills/issue-mr-flow/SKILL.md`「`gh`/`glab` CLI不在時のMCPフォールバック」節）。

   1. `get_repo_slug | jq -r '.owner, .repo'` で `owner` / `repo` を得る。
   2. 本文は `build_issue_body "<目的>" "<現状>" "<期待する動作>" "<受け入れ条件>"` で組み立てる
      （4見出しの構成をスクリプトと揃えるため。この関数はCLIに依存しない）。
   3. `mcp__github__issue_write`（`method="create"`, `owner`, `repo`, `title`, `body`）で作成する。
   4. WebFetchツール・curlへはフォールバックしない（DDR 0020, DDR 0025）。

4. 結果（issue番号・URL）をユーザーに提示する。続けてそのissueに着手するかどうかをユーザーに確認し、
   着手する場合は `/issue-mr-flow start <issue番号>` に進む。

## してはいけないこと

- ユーザーの明示的な確認なしに、いきなり `create-issue.sh` を実行しない。
- 4見出しの内容を、ユーザーの依頼から読み取れる範囲を超えて創作しない。
