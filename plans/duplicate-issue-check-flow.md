---
title: issue #68 全体作業計画 — issue起票時の類似・重複issueチェック手順を追加する
type: guide
description: issue #68（起票前の重複チェック手順が無い問題）に対する全体作業計画。Provider.shへの検索関数追加・issue-createスキルの手順追加・MCP対応表更新・テスト・DDRまでの方針を記載する
tags: [issue-create, vcs-provider, workflow, plan]
keywords: [重複チェック, search_issues, issue-create, キーワード抽出, MCPフォールバック, closed, Provider.sh, issue68]
---

# 全体作業計画: issue #68 対応

## Context

issue #68（https://github.com/yuki-matsu783/MR-driven-workflow/issues/68）:
AIエージェントが `issue-create` スキルでissueを代行起票する際、既存issueとの重複を検知する
手順が無い。人間がUIから起票する場合はGitHub/GitLabが入力中に類似issueをサジェストするが、
`create-issue.sh` 経由のAI代行ではそれが働かないため、**本来重複を作りにくいはずのAI経路の
ほうが重複を作りやすい**構造になっている。

現状の確認結果（コード実地確認済み）:

| 対象 | 現状 |
|---|---|
| `.claude/skills/issue-create/SKILL.md` | 実行フローは4手順（5項目を埋める → ユーザー確認 → `create-issue.sh` → 結果提示）。既存issueを参照するステップは無い |
| `.claude/scripts/src/create-issue.sh` | 検証は `test_issue_sections`（4見出しの存在）のみ。本文の形式しか見ていない |
| `.claude/scripts/src/vcs/Provider.sh` | issue関連は `get_issue`（番号指定の単体取得）と `new_issue`（作成）のみ。**一覧取得・検索に相当する関数が無い** |
| `.claude/skills/issue-mr-flow/SKILL.md` MCP対応表 | issue検索に対応する行が無い |

## 実行環境の前提（非対話的セッション）

本作業はClaude Code on the webのリモート実行環境で行う。`gh`/`glab` CLIが存在せず
（`get_vcs_access_mode` → `mcp`）、人間のレビュー往復（flow-id 2-3/2-4, 3-3/3-4, 3-8/3-9,
4-3/4-4, 4-8/4-9）を待てない。したがって:

- issue情報の取得はGitHub MCPツール（`mcp__github__issue_read` 等）で代替する（DDR 0020/0027）。
- レビュー待ちステップの進捗記号は `[]` のまま残し、実施した内容は `HANDOFF.md` の
  「やったこと」で補足する（`.claude/rules/docs-workflow.md` 末尾の非対話的実行環境の規定）。
- 全体作業計画はplanツールではなくWrite/Editで作成する（Planモードを抜けた後のため）。
  ファイル名に `【】` を含めないことで、下位の個別計画と機械的に区別できる状態は保つ。

## フェーズ省略の判断

対象ファイル・期待する動作はissue本文に具体的に列挙されており、追加調査を要する未知は
「既存コードの現状把握」のみで、それは着手前の読解で完了している。したがって
**フェーズ2（調査）は省略**し、フェーズ3（作業）から着手する。

## 設計方針

### 1. キーワード抽出はAIが行い、bashへは実装しない（本作業の最大の判断）

issue本文は日本語主体であり、形態素解析器を持たないbashで実用的なキーワード抽出はできない。
文字クラス（ひらがな・カタカナ・漢字）による分割はロケール依存（git bashで `LANG` が
UTF-8でない場合、`${text:i:1}` はバイト単位になる）で脆く、汎用語の除去もできない。

一方、`issue-create` スキルではAIが直前に自らタイトル・4見出しを組み立てており、
**そのissue固有の語がどれかを最もよく知っているのはAI自身**である。したがって
キーワード抽出はスキル側（AIの責務）に置き、`Provider.sh` 側は「与えられたキーワードで
検索して結果を正規化・統合する」ことに専念する。

issue #68の受け入れ条件は「純粋ロジック部分（キーワード抽出等）の単体テストが追加されている、
**またはテスト不要と判断した理由が記録されている**」であり、この判断はDDRに記録する。
bash側に残る純粋ロジック（プロバイダごとのJSON正規化・複数検索結果のマージ）には
単体テストを付ける。

### 2. `search_issues` はキーワードごとに1回ずつ検索してOR的に統合する

GitHub/GitLabのissue検索はいずれも複数語をAND条件として扱うため、キーワードを増やすほど
ヒットしなくなる。重複チェックで欲しいのは再現率（recall）なので、**キーワード1つにつき
1回検索し、結果を番号で重複排除して統合する**。キーワード数は最大5件までとし、超過分は
標準エラーへ通知したうえで切り捨てる（無言の打ち切りにしない）。

### 3. closedを含める・stateの表記を揃える

過去に見送られた提案の再提出を検知するため、検索対象にclosedを含める（`gh issue list
--state all` / `glab issue list --all`）。GitHub CLIは `OPEN`/`CLOSED`、GitLabは
`opened`/`closed` を返すため、共通形式では `open`/`closed` へ正規化する。

## 変更対象

| # | ファイル | 変更内容 |
|---|---|---|
| 1 | `.claude/scripts/src/vcs/Github.sh` | `github_search_issues` / `github_normalize_issue_search_results`（純粋関数）を追加 |
| 2 | `.claude/scripts/src/vcs/Gitlab.sh` | `gitlab_search_issues` / `gitlab_normalize_issue_search_results`（純粋関数）を追加 |
| 3 | `.claude/scripts/src/vcs/Provider.sh` | `search_issues` ディスパッチャ、`merge_issue_search_results`（純粋関数）、`mcp_tool_hint` への行追加 |
| 4 | `.claude/skills/issue-create/SKILL.md` | 実行フローに重複チェック手順を追加（最終確認の前）、「してはいけないこと」に追記 |
| 5 | `.claude/skills/issue-mr-flow/SKILL.md` | MCPフォールバック対応表に `search_issues` の行を追加 |
| 6 | `tests/test_vcs_provider.sh` | 正規化・マージ・`mcp_tool_hint` のテストを追加 |
| 7 | `.claude/docs/spec/issue-mr-workflow.md` | 提供関数表への追加と、重複チェックの仕様節を追加 |
| 8 | `.claude/docs/ddr/0031-...md` | 判断方針（キーワード抽出をAI側に置く／closedを含める／最終判断は人間）と却下案を記録 |

## issue #59 / #64 との重なり（着手時に確認する）

いずれも未着手（open）で、**同じ `.claude/skills/issue-create/SKILL.md` の実行フローを
変更する予定**。先にマージされた側の変更内容に合わせて手順番号を振り直す必要がある。

| issue | 変更予定箇所 | 本issueとの関係 |
|---|---|---|
| #59 | 手順2（最終確認を `AskUserQuestion` 化）・手順4（同一セッションでの着手導線を削除） | 本issueは手順2の**前**に新しい手順を挿入するため、手順番号が1つずつ後ろへずれる。#59が先にマージされた場合は「`AskUserQuestion` による最終確認」の直前に挿入する |
| #64 | 実行フローに「並列列挙構造の分割提案」チェックを追加 | 同じく起票前の事前チェック。#64が先にマージされた場合、重複チェックと分割提案チェックが並ぶ形になるので、順序（重複チェック → 分割提案、またはその逆）を明示する必要がある |

本作業では、後続issueが手順番号に依存せず挿入位置を判断できるよう、**手順の見出しに
内容を表す名前を併記**する（例:「2. 類似・重複issueをチェックする」）。

## 完了条件（issue #68の受け入れ条件に対応）

- [ ] `Provider.sh` にissue検索関数が追加され、GitHub/GitLab両方の実装を持つ
- [ ] `issue-create/SKILL.md` に検索ステップがあり、「重複と断定して勝手に起票を中止しない」旨が明記されている
- [ ] `issue-mr-flow/SKILL.md` のMCP対応表に新関数の行がある
- [ ] 純粋ロジックの単体テストが追加され、キーワード抽出をテスト対象にしなかった理由が記録されている
- [ ] 判断方針の背景・却下案がDDRとして記録されている
- [ ] issue #59 / #64 との重なりが計画に残されている（本ファイルの上記節）
