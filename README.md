---
title: MR-driven-workflow
type: guide
description: issue起票からマージまでをAIエージェント（Claude Code / Gemini CLI）が支援するMR駆動開発ワークフローのテンプレート
tags: [readme, template, workflow]
keywords: [issue-mr-flow, claude-code, gemini-cli, github, gitlab, テンプレート]
---

# MR-driven-workflow

issueの起票からfeatureブランチ・Draft PR/MRの作成、レビュー往復、マージまでを、AIエージェント
（Claude Code / Gemini CLI）が一貫して支援する、**issue駆動MRワークフロー機構のテンプレート**
リポジトリです。`.claude/` 一式・`.gemini/`（`.claude/`からの変換生成物）・
`.mrworkflow.json`・GitHub/GitLab issueテンプレートなど、ワークフローに必要なAI資産一式を含みます。

現時点ではアプリ本体（`src/`等）を持たず、他プロジェクトへこのワークフロー機構だけを展開して
使うテンプレートとして構成されています（展開方法は[DEVELOPERS.md](DEVELOPERS.md)の
`apply-mr-workflow-to-project`スキルの節を参照）。

## 使い方

- 開発フロー全体（issue起票〜マージ）の唯一の実装フロー定義は
  [.claude/skills/issue-mr-flow/SKILL.md](.claude/skills/issue-mr-flow/SKILL.md)。
- AIエージェント共通ルール・プロジェクト概要は [AGENTS.md](AGENTS.md)（Claude Code固有ルールは
  [CLAUDE.md](CLAUDE.md)、Gemini CLI固有ルールは[GEMINI.md](GEMINI.md)から、それぞれ`AGENTS.md`を
  参照する構成になっている）。
- リポジトリのディレクトリ構成は [index.md](index.md)（Repository Map）を正とする。
- このワークフロー機構自体の開発（ルール・スキル・スクリプトの変更）に参加する場合は
  [DEVELOPERS.md](DEVELOPERS.md) を参照。

## セットアップ

1. `gh` CLI（GitHubの場合）または `glab` CLI（GitLabの場合）、および `jq` をインストール・
   認証済みにする（`.claude/scripts/src/vcs/Provider.sh` がissue/PR/MR情報の取得に使う）。
2. Gemini CLIも使う場合は `bash .claude/scripts/src/sync-gemini-assets.sh` を1回実行し、
   `.gemini/` を再生成する。**`.gemini/` は `.claude/` からの変換生成物**で、`agents/*.md` の
   frontmatter と `settings.json` の記法差をこのスクリプトが吸収する（`.gemini/` を直接編集
   しないこと。以後も `.claude/` を変更したら流し直す。詳細:
   [.claude/docs/spec/sync-gemini-assets.md](.claude/docs/spec/sync-gemini-assets.md)）。
3. 導入した資産の版は [.claude/VERSION](.claude/VERSION)（SemVer 1行）で確認できる。配布時は
   この値がそのまま配布先へ入るため、「どの版の資産を導入したか」を配布先から判別できる
   （更新規則・配布経路の詳細は
   [.claude/docs/spec/distribution-assets.md](.claude/docs/spec/distribution-assets.md)）。
4. リポジトリ固有のブランチ命名規則・`wip/plans/`等の場所は [.mrworkflow.json](.mrworkflow.json) を
   参照・編集する。各キーの意味・**本リポジトリの設定値**・用途は以下の通り。

   | キー | 本リポジトリの設定値 | 用途 |
   |---|---|---|
   | `branchPrefixTemplate` | `"feature-{issue}-{slug}"` | issueブランチの命名規則テンプレート。`{issue}`はissue番号、`{slug}`はタイトル等をスラッグ化した文字列に置換される |
   | `defaultBaseBranch` | `"main"` | Draft PR/MR作成・ブランチ作成・差分検出のデフォルトベースブランチ |
   | `plansDir` | `"wip/plans"` | 計画ファイル（全体作業計画・個別計画）の格納ディレクトリ |
   | `worklogDir` | `"wip/worklogs"` | 実装中の試行錯誤ログの格納ディレクトリ |
   | `reportsDir` | `"wip/reports"` | 報告用自己完結HTMLの格納ディレクトリ |
   | `specDirs` | `[".claude/docs/spec"]` | 正史仕様ドキュメントの格納ディレクトリ一覧（アプリ本体追加時の拡張ポイント。現時点ではスクリプトからは読み出されておらず、ドキュメント上の配置場所指定として使う） |
   | `ddrDirs` | `[".claude/docs/ddr"]` | 意思決定ログ（DDR）の格納ディレクトリ一覧（同上） |

   **上表は「本リポジトリが`.mrworkflow.json`に明示している値」であり、キーを省略した場合に
   コードが使う既定値（フォールバック）とは異なる。** `plansDir`/`worklogDir`/`reportsDir`の
   フォールバックは`"plans"`/`"worklog"`/`"reports"`のまま（issue #165でも変更していない。
   未移行の既存配布先との後方互換のため。詳細:
   [DDR i0165-01](.claude/docs/ddr/i0165-01-wip集約時のコード側フォールバック既定値は変更せず後方互換を優先する.md)）。
   `.mrworkflow.json`にこれら3キーを持たないプロジェクトへ本機構を導入する場合は、
   `wip/plans`等ではなく`plans`等が使われる点に注意する。
