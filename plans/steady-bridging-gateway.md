---
title: issue #34 全体作業計画 — gh/glab CLI不在環境向けMCPフォールバック経路の実装
type: guide
description: issue #34（gh/glab不在環境でissue-mr-flowが機能するようMCPフォールバック経路を実装・文書化する）に対する全体作業計画
tags: [issue-mr-flow, mcp, provider, fallback]
keywords: [MCPフォールバック, gh, glab, Provider.sh, session-start, issue-mr-flow, 経路判定, issue34]
---

# 全体作業計画: issue #34 対応

## Context

issue #34（https://github.com/yuki-matsu783/MR-driven-workflow/issues/34）。

`AGENTS.md` は「`gh`/`glab` CLIが実行環境に存在しない場合はGitHub/GitLab公式のMCPサーバーツールで
代替してよい」と定めているが、`.claude/skills/`・`.claude/hooks/`・`.claude/scripts/` にはMCPへの
言及が1件も無く、代替の具体手順が実装・文書化されていない。実際にClaude Code on the webの
リモート実行環境には `gh`/`glab` が無く（`jq`・`git` のみ）、AIエージェントが毎回その場の判断で
MCPツールを選んでいる（issue #22対応セッションで実際に発生し、`HANDOFF.md`にその旨が記録されている）。

## フェーズ省略の判断

対象ファイル（`Provider.sh`・`SKILL.md`・`issue-create/SKILL.md`・`session-start.sh`・
post-push系hook2本）と方針はissue本文の受け入れ条件でほぼ確定しており、未知の調査要素は
「各Provider関数に対応するMCPツールと引数の実際のスキーマ」のみで、これはツール定義の参照で
即座に確定する。よって**フェーズ2（調査）は省略**し、フェーズ3（作業計画→実装）から着手する。

## 方針（受け入れ条件との対応）

| 受け入れ条件 | 対応方針 |
|---|---|
| 各サブコマンドにMCPツールと引数の対応が記載されている | `SKILL.md` に「`gh`/`glab` CLI不在時のMCPフォールバック」節を新設し、Provider関数 → MCPツール・引数の対応表と、サブコマンドごとの読み替えを記載する。`issue-create/SKILL.md` にも `create-issue.sh` の代替手順を追記する |
| 経路を機械的に決められる判定方法が定義されている | `Provider.sh` に `get_vcs_access_mode`（`cli` / `mcp` を返す）を追加し、各サブコマンドの手順1で必ずこれを呼ぶ形にする。加えて各Provider関数の先頭に `require_vcs_cli` ガードを置き、CLI不在時は「どのMCPツールで代替するか」を名指ししたメッセージを出して失敗させる（AIエージェントの即興判断を排除する） |
| `session-start.sh` の挙動をspecに明記する | CLI不在時は「取得に失敗しました」ではなく、経路がMCPであること・ブランチ名から取れるissue番号・MCPでの取得方法を注入する形へ変更し、specの該当節へ明記する |
| DDRに採用案と却下案を記録する | DDR 0025を新設。DDR 0020（WebFetch/curlへはフォールバックしない）と矛盾しないことを明記する |
| GitLab側の対応可否を明記する | GitLab MCPサーバーはこのリポジトリのセッションで利用実績が無く検証できないため、**判定と失敗メッセージの枠組みだけ共通化し、具体的なツール名対応表はGitHubのみを対象とする**（GitLabは対象外である旨をSKILL.md・DDRに明記する） |

## 個別計画

`plans/【設計】【実装】gh-glab不在時のMCPフォールバック経路.md`（設計＝対応表とガードの仕様、
実装＝スクリプト変更とテスト追加を1回の合意で進めるため併記する）。

## 補足（本セッションの制約）

Claude Code on the webのリモート実行環境（＝まさに本issueが対象とする `gh`/`glab` 不在環境）で
作業しているため、人間のレビュー往復を待つステップ（3-3/3-4, 3-8/3-9等）は実施できない。
`.claude/rules/docs-workflow.md` の非対話的実行環境向けの規定に従い、該当ループの進捗記号は
`[]` のまま残し、実施済みの内容は「やったこと」欄に文章で補足する。なお全体作業計画である本ファイルも、
planツール（Planモード）ではなくWrite/Editで作成している（同じ理由による例外）。
