---
title: post-push-usage-report.sh/post-push-compact-prompt.shのGemini CLI対応 調査計画
type: log
description: issue #7対応。post-push-usage-report.sh/post-push-compact-prompt.shをpost-push-save-logs.shと同様にGemini CLI/Claude Code両対応にするための調査計画
tags: [issue-7, gemini-cli, usage-report, compact-prompt, hooks]
keywords: [post-push-usage-report, post-push-compact-prompt, post-push-save-logs, tool_name, GEMINI_PROJECT_DIR, CLAUDE_PROJECT_DIR, UsageTracking, エンジン判定]
---

## Context

issue #7「post-push-usage-report.sh/post-push-compact-prompt.shをGemini CLI/Claude Code両対応にする」への対応。
前セッションの調査（工数レポート機能のGitHub/GitLab・Claude Code/Gemini CLI対応状況調査。
経緯は[plans/fancy-wishing-scroll_act1.md](./fancy-wishing-scroll_act1.md)に退避済み）により、
`post-push-usage-report.sh`と`post-push-compact-prompt.sh`はClaude Code専用のガード条件
（`CLAUDE_PROJECT_DIR`必須・`tool_name`が`Bash`/`PowerShell`限定）を持つため、Gemini CLI実行時は
処理の冒頭で必ず`exit 0`となり、工数レポート・コンパクトプロンプトの投稿機能自体が動作しないことが
判明している。一方`post-push-save-logs.sh`は同種のガードに`tool_name`によるエンジン判定
（`run_shell_command`→gemini、`Bash`/`PowerShell`→claude）と
`${GEMINI_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-}}`によるプロジェクトルート取得フォールバックを
既に実装済みで、対応パターンの手本として使える。本タスクはこのパターンを他2スクリプトへ移植する。

## 調査（flow-id 4〜10、Exploreエージェントによる事実確認結果）

### 1. `post-push-save-logs.sh` の参考実装（既存の正しいパターン）

- 41〜49行目: `tool_name`によるエンジン判定
  ```bash
  case "$tool_name" in
    run_shell_command) engine="gemini"; engine_label="Gemini CLI" ;;
    Bash|PowerShell) engine="claude"; engine_label="Claude Code" ;;
    *) exit 0 ;;
  esac
  ```
- 59〜60行目: プロジェクトルート取得フォールバック
  ```bash
  local project_dir="${GEMINI_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-}}"
  [ -n "$project_dir" ] || exit 0
  ```
- 判定結果`engine`/`engine_label`は74行目・108行目・136行目で後段の分岐（サブエージェントログ探索方式、
  完了メッセージ表示）に使われる。
- `.claude/docs/spec/session-log-hooks.md`「エンジン判定」節（30〜42行目）に同パターンが文書化済み。

### 2. `post-push-usage-report.sh` の現状（対応が必要な箇所）

- 66行目: `[ -n "${CLAUDE_PROJECT_DIR:-}" ] || exit 0` — `GEMINI_PROJECT_DIR`未対応
- 68〜72行目: `tool_name`が`Bash`/`PowerShell`以外なら`exit 0` — `run_shell_command`未対応
- 80行目: `cd "$CLAUDE_PROJECT_DIR"` — フォールバック値を使っていない
- 82行目: `UsageTracking.sh`を`"${CLAUDE_PROJECT_DIR}/..."`固定パスでsource
- 89〜91行目: `session_id`/`transcript_path`をhook入力から取得し、102行目で
  `sync_usage_state "$repo_root" "$branch" "$session_id" "$transcript_path"`へ渡す
  （`UsageTracking.sh` 455〜456行目の引数仕様と一致）。この2フィールドはtool_name分岐と無関係に
  hook入力から取得しているため、Gemini CLI側でも同名フィールドが提供される前提であれば
  変更不要と考えられる（ただし本リポジトリ内にGemini CLI hook入力の全フィールド一覧を明記した
  資料は無く、この前提は`post-push-save-logs.sh`側も同様に無検証で置いている暗黙の前提）。

### 3. `post-push-compact-prompt.sh` の現状

- 47〜64行目: `agent_id`→`CLAUDE_PROJECT_DIR`→`tool_name`→`git push`コマンド検知、の順で
  `post-push-usage-report.sh`と完全に同一パターンのガードを持つ（11行目コメントで同一パターンと明記）。
- `UsageTracking.sh`はsourceしない（`Provider.sh`のみ）。MRコメントではなく
  `hookSpecificOutput.additionalContext`形式のJSONをstdoutへ出力しClaude Codeのコンテキストへ
  注入する方式（78行目）。状態ファイルの読み書きは無い。

### 4. hook登録設定の差分（`.claude/settings.json` vs `.gemini/settings.json`）

| 項目 | Claude Code | Gemini CLI |
|---|---|---|
| hookイベント名 | `PostToolUse` | `AfterTool` |
| matcher | `Bash\|PowerShell` | `run_shell_command\|Bash\|PowerShell` |
| コマンド絞り込み | `if`フィールドで`git push*`のみ起動 | 絞り込み無し（スクリプト内部の検知のみに依存） |
| timeout単位 | 秒（20） | ミリ秒（20000） |

いずれも3スクリプト（usage-report/compact-prompt/save-logs）が登録済みで、設定側は既に
両対応の体裁を整えている。実装側（スクリプト本体）だけが save-logs 以外未対応、という状態。

### 5. 未検証事項（対応方針に影響しうる懸念点）

- `session-log-hooks.md`「未決定事項・懸念点」に、Gemini CLI側の`hooks`セクションのスキーマ自体が
  実機未検証と明記されている。本issueの対応も同様にGitHub上での実機確認に限定し、GitLab側の検証は
  受け入れ条件から除外する（issue本文の受け入れ条件と一致）。
- Gemini CLIのhook入力JSONが`session_id`/`transcript_path`/`agent_id`を Claude Codeと同名・同形式で
  提供するかは本リポジトリ内に明記が無い暗黙の前提。`post-push-save-logs.sh`が既にこの前提で
  動作している実績があるため、本issueでも同じ前提を踏襲する（新たな検証は行わない）。

## 対象外

- GitLab側の動作検証（issue受け入れ条件で明示的に対象外）。
- Gemini CLI hook入力JSON構造そのものの网羅的な仕様調査（`post-push-save-logs.sh`の既存の前提を踏襲する）。
- `Stop`/`SessionEnd`等、他のhookイベントへの対応拡張。

## 作業計画（flow-id 15相当、概略）

1. `post-push-usage-report.sh`に`post-push-save-logs.sh`と同じ`tool_name`分岐
   （`run_shell_command`→gemini、`Bash`/`PowerShell`→claude、それ以外は`exit 0`）を追加し、
   66行目のガードを`${GEMINI_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-}}`によるフォールバック取得へ置換する。
   80行目の`cd`・82行目のsourceパスもこのフォールバック変数ベースに修正する。
2. `post-push-compact-prompt.sh`に同様の修正を適用する（47〜64行目のガード部分）。
3. `.claude/docs/spec/session-log-hooks.md`に、この2スクリプトも同じエンジン判定パターンに
   対応した旨を追記する（対象スクリプトの一覧を更新する形を想定。詳細は実装時に確定）。
4. 可能であればGitHub remote環境で実際にGemini CLIから`git push`をトリガーし、工数レポート・
   コンパクトプロンプトがそれぞれ想定通り動作するか確認する（受け入れ条件2）。

## 検証方法

- 修正した`.sh`ファイルは`bash -n <file>`で構文チェックする。
- 可能な範囲でGemini CLI実行環境からのgit push契機の動作確認を行う（受け入れ条件2）。困難な場合は
  コードレビューベースでの確認に留め、その旨をworklog・PR descriptionに明記する。
