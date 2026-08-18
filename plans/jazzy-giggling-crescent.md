---
title: post-push-save-logs.shのGemini CLI/Claude Code自動判定化
type: plan
description: post-push-save-logs.shが実行中のCLI(Gemini CLI/Claude Code)を自動判定し、Claude Codeのセッションログもlogsディレクトリへ保存できるようにするための調査計画
tags: [hooks, session-logs, gemini-cli, claude-code]
keywords: [post-push-save-logs, tool_name, run_shell_command, transcript_path, subagents, logs, gitignore, settings.json]
---

# post-push-save-logs.shのGemini CLI/Claude Code自動判定化

対応issue: [#3](https://github.com/yuki-matsu783/MR-driven-workflow/issues/3)

## Context

`.claude/hooks/post-push-save-logs.sh` は「輸入」コミットで追加されたばかりの、`git push`検知時に
セッションログ（メイン＋サブエージェント）を`logs/push-<N>/`へ保存するhookスクリプト。ヘッダコメント上は
「Gemini CLI専用」だが、中身は既に`tool_name`（`run_shell_command`=Gemini CLI、`Bash`/`PowerShell`=
Claude Code）で判定を分岐できる下地がある。しかし：

- セッションログの保存先探索ロジックはGemini CLI固有のディレクトリ構造
  （`transcript_path`のあるディレクトリ配下に`session_id`ディレクトリでサブエージェントログが
  格納される構造）専用になっており、Claude Code固有の構造（`transcript_path`本体がメインログ、
  `${transcript_path%.jsonl}/subagents/agent-*.jsonl` ＋ `.meta.json`がサブエージェントログ。
  `.claude/hooks/lib/UsageTracking.sh`の`_usage_sync_session_logs`が参考実装）には対応していない。
- どちらのCLIのhooksにもまだ登録されておらず（`.claude/settings.json`にも`.gemini/settings.json`にも
  記載なし）、現状発火しない。
- 保存先`logs/`は`.gitignore`に含まれていないが、`commit`スキルのジャンクファイル除外リストには
  既に`*.log`, `logs/`が含まれている（想定はローカル作業状態としてコミット対象外）。

ユーザーからの依頼は「起動しているのがGemini CLIかClaude Codeかを自動で判断し、Claude Codeの場合の
セッションログもlogsディレクトリに保存する」こと。これに向けた調査計画を立てる。

## 調査

### 調査の目的

実装（作業計画）に着手する前に、以下を確定させる。

1. **エンジン判定の方式**: `tool_name`（`run_shell_command` vs `Bash`/`PowerShell`）と環境変数
   （`GEMINI_PROJECT_DIR`/`CLAUDE_PROJECT_DIR`）のどちらを一次判定に使うか、フォールバックの
   組み合わせ方を確定する。既存の`session-start.sh`/`post-push-usage-report.sh`が
   `CLAUDE_PROJECT_DIR`の有無をガードに使っているパターンとの整合性を確認する。
2. **Claude Code側のログ収集ロジック**: `UsageTracking.sh`の`_usage_sync_session_logs`が実装済みの
   「メインtranscriptコピー＋`${transcript_path%.jsonl}/subagents/agent-*.jsonl`列挙」パターンを
   そのまま流用できるか、`logs/push-<N>/`向けに調整が必要な差分（ディレクトリ命名・meta.jsonの扱い等）
   を洗い出す。
3. **Claude Code側のhook登録**: `.claude/settings.json`の`PostToolUse`（`Bash|PowerShell`マッチャー、
   `if`フィルタで`git push*`）へ、既存2エントリ（`post-push-usage-report.sh`,
   `post-push-compact-prompt.sh`）と同じパターンで追加登録できるか確認する。
4. **Gemini CLI側のhook登録可否**: `.gemini/settings.json`に現状hooks定義が無く、Gemini CLIの
   実際のhook設定スキーマ（イベント名が`AfterTool`か等）がこのリポジトリ内で未検証であることを
   確認したうえで、今回のissueの受け入れ条件（「Gemini CLI上での既存の保存動作に回帰がないこと」）
   の範囲でどこまで対応するかを見極める（Gemini CLI側の新規配線は情報が不足していれば別issueとして
   切り出す前提で調査する）。
5. **`logs/`の`.gitignore`扱い**: `/usage/`と同様に`.gitignore`へ追記すべきか、`commit`スキルの
   除外リストのみで足りているかを確認する。
6. **検証方法**: このリポジトリには`tests/`ディレクトリが存在しない（アプリ本体を持たないテンプレート
   のため）。hookスクリプトへの疑似JSON入力（`echo '{...}' | bash post-push-save-logs.sh`）による
   手動シミュレーションと`bash -n`構文チェックで代替できるか、新規に`tests/`を設けて
   `.claude/rules/shell-script-style.md`の「テスト」節に沿った単体テストを追加すべきかを判断する。

### 調査しないこと（対象外）

- Gemini CLI・Claude Code以外のCLI（将来対応する可能性のあるツール）への対応は行わない。
- `usage/session-logs/`（対応工数レポート用の既存の別系統のログ保存）の仕組み自体の変更は行わない
  （参考にするのみ）。

### 調査方法

- `.claude/hooks/post-push-save-logs.sh`, `.claude/hooks/lib/UsageTracking.sh`,
  `.claude/hooks/post-push-usage-report.sh`, `.claude/hooks/session-start.sh`,
  `.claude/settings.json`, `.gemini/settings.json`, `.gitignore`, `.claude/skills/commit/SKILL.md`
  を読み込み、既存パターンを突き合わせる（Read/Grep。今回のセッションで既に大部分実施済みのため、
  flow-id 10ではその内容を`plans/jazzy-giggling-crescent.md`の「調査結果」節・
  `worklog/`へ整理して記録する）。
- Gemini CLIの実際のhook設定スキーマ（イベント名・マッチャー形式）について、リポジトリ内に
  確証が無いため、WebSearch/WebFetchで一次情報を確認する。確認できない場合はその旨を調査結果に
  明記し、対応範囲から切り離す判断根拠とする。
- 疑似hook入力JSONを使い、現状のスクリプトを実際に手元で実行して動作を確認する
  （`GEMINI_PROJECT_DIR`/`CLAUDE_PROJECT_DIR`を設定した2パターン）。

## 調査結果

### 1. エンジン判定の方式

`tool_name`を一次判定に使う（`run_shell_command`=Gemini CLI、`Bash`/`PowerShell`=Claude Code）。
これはhookイベントのペイロードに必ず含まれ、どちらのCLIが呼び出したかを機械的に一意に決定できる
（両CLIの `tool_name` の値集合は重複しない）。環境変数（`GEMINI_PROJECT_DIR`/`CLAUDE_PROJECT_DIR`）は
プロジェクトルート特定のためのフォールバックとして併用する（既存コードの
`"${GEMINI_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-}}"` パターンを踏襲）。`session-start.sh`/
`post-push-usage-report.sh` は `CLAUDE_PROJECT_DIR` の有無だけをガードに使っており
（Claude Code専用スクリプトのため判定不要）、本スクリプトは両対応のため`tool_name`分岐が必須という
差分がある。

### 2. Claude Code側のログ収集ロジック

`UsageTracking.sh`の`_usage_sync_session_logs`（`.claude/hooks/lib/UsageTracking.sh:316-339`）が
実装済みのパターンをそのまま転用できる：

- メインログ: `transcript_path`自体をコピー
- サブエージェントログ: `${transcript_path%.jsonl}/subagents/agent-*.jsonl` を列挙し、対応する
  `<agentId>.meta.json`（存在すれば）も一緒にコピー

`usage/session-logs/`向けの実装は「`<safeBranch>/<sessionId>/`」という2階層ディレクトリだが、
`post-push-save-logs.sh`は`push-<N>`という連番ディレクトリ1階層のみを使う設計のため、コピー先の
ディレクトリ構造は流用元と合わせず、既存のGemini CLI分岐と同じ`push_dir`直下に
`main.jsonl`＋`subagents/`を置く形に揃える（Gemini側の`cp -R "$subagents_dir" "$push_dir/"`と
並びが取れるように）。

### 3. Claude Code側のhook登録

`.claude/settings.json`の`hooks.PostToolUse`は配列で、既存2エントリ（`post-push-usage-report.sh`,
`post-push-compact-prompt.sh`）と全く同じ形（`matcher: "Bash|PowerShell"`、`if`フィールドで
`"Bash(git push*)"` / `"PowerShell(git push*)"`をそれぞれ指定、`command: "bash"`,
`args: ["${CLAUDE_PROJECT_DIR}/.claude/hooks/post-push-save-logs.sh"]`）で
2エントリ追加すればよい。他のhookと同様、失敗してもgit push自体はブロックしない設計
（`( main ) || true; exit 0`）が既にスクリプト側にある。

### 4. Gemini CLI側のhook登録

WebSearch/WebFetchでGemini CLI公式ドキュメント（[Hooks reference](https://geminicli.com/docs/hooks/reference/),
[Writing hooks](https://geminicli.com/docs/hooks/writing-hooks/),
[Shell tool](https://geminicli.com/docs/tools/shell/)）を確認した結果、以下が判明した。

- `.gemini/settings.json`の`hooks.AfterTool`配列に、`matcher: "run_shell_command"`、
  `hooks: [{type: "command", command: "<shellコマンド文字列>", name, timeout, description}]`
  という形で登録できる（Claude Code側の`matcher`+`if`の2段フィルタと異なり、Gemini CLI側は
  `matcher`（正規表現、ツール名に対して照合）のみで、コマンド内容でのフィルタは無い。
  `post-push-save-logs.sh`内部の`git push`文字列チェックが唯一のフィルタになる）。
- `command`フィールドは単一のシェルコマンド文字列であり、Claude Code側のような`args`配列に
  相当するフィールドはドキュメント上確認できなかった。公式サンプルが
  `"command": "$GEMINI_PROJECT_DIR/.gemini/hooks/hook-script.sh"`という形で環境変数展開を
  前提にしていることから、`"command": "bash \"$GEMINI_PROJECT_DIR/.claude/hooks/post-push-save-logs.sh\""`
  のような1本の文字列で登録できると見込む（`.gemini/hooks`は`.claude/hooks`へのローカルリンクのため
  どちらのパスでも実体は同じ）。
- `run_shell_command`の`tool_input.command`フィールド名は[Shell tool doc](https://geminicli.com/docs/tools/shell/)で
  確認済みで、既存スクリプトの`jq -r '.tool_input.command // empty'`と一致している（変更不要）。
- **未検証・懸念点として残すこと**: [Issue #20258](https://github.com/google-gemini/gemini-cli/issues/20258)
  （「Subagents spawn with same session ID as parent session」）の記述から、現行バージョンの
  Gemini CLIではサブエージェントが親と同じセッションIDで動作し、既存スクリプトが前提とする
  「`${chats_dir}/${session_id}/`配下にサブエージェント専用の別ディレクトリがある」という構造が
  実際の挙動と一致しない可能性がある。ただしこれは**既存のGemini CLI分岐のロジック自体の問題**であり、
  今回のissueのスコープ（Claude Code対応の追加）には含めない。動作を変更せずそのまま残し、
  スクリプトのコメントに「未検証の既知の懸念」として記録するに留める。
- 上記を踏まえ、**Gemini CLI側の`.gemini/settings.json`への登録も今回のissueのスコープに含める**
  （受け入れ条件「Gemini CLI上での既存の保存動作に回帰がないこと」を検証可能にするには、実際に
  発火させて確認する必要があるため）。

### 5. `logs/`の`.gitignore`扱い

`/usage/`（対応工数レポートのローカル作業状態）と同じ性質のローカル生成物であるため、
`.gitignore`に`/logs/`を追記する。`commit`スキルのジャンクファイル除外リストは
「ステージングしてしまった場合の保険」であり、`.gitignore`と両方揃えることで
`git status`のnoiseも防げる（`/usage/`が両方に存在するのと同じパターンに揃える）。

### 6. 検証方法

`tests/`ディレクトリは本リポジトリに存在しない（アプリ本体を持たないテンプレートのため）。
今回は新規に`tests/`を設けるほどの複雑な純粋ロジックは無い（エンジン判定は`tool_name`の
文字列比較のみ）ため、以下の手動検証に留める。

- `bash -n .claude/hooks/post-push-save-logs.sh` で構文チェック
- 疑似hook入力JSON（`tool_name`/`tool_input.command`/`transcript_path`/`session_id`等を含む）を
  `echo '...' | GEMINI_PROJECT_DIR=... bash .claude/hooks/post-push-save-logs.sh` の形で2パターン
  （Gemini CLI相当・Claude Code相当）流し込み、`logs/push-<N>/`配下に期待通りのファイルが
  生成されることを確認する。
