---
title: 【設計反映】【AIアセット反映】セッションログ統合の仕様反映とpush検知の記述修正
type: plan
description: issue #23の個別反映計画。spec/session-log-hooks.mdをissue-mr-workflow.mdへ統合し、compact検証結果とpush検知の実挙動を反映、DDR 0022を新設する
tags: [usage-report, session-logs, spec, ddr, ai-asset]
keywords: [設計反映, AIアセット反映, session-log-hooks, push-index, compact, 前方一致, 部分一致, DDR0022, directory-structure, tests]
---

# 【設計反映】【AIアセット反映】セッションログ統合の仕様反映とpush検知の記述修正

- issue: #23 / Draft PR: #24
- 全体作業計画: `plans/snoopy-petting-puddle.md`
- 直前の個別作業計画: `plans/【設計】【実装】【テスト】セッションログのミラー統合とpush断面インデックス化.md`

種別を1ファイルに併記した理由: 設計反映とAIアセット反映がいずれも「今回の実装で判明した事実を
恒久ドキュメントへ落とす」という同じ作業であり、合意を分ける必要がないため。

## 設計反映

### 1. `.claude/docs/spec/session-log-hooks.md` を `issue-mr-workflow.md` へ統合し削除する

`session-log-hooks.md` は `post-push-save-logs.sh`（本issueで削除）の仕様書であり、
スクリプトが無くなった以上ファイル単体では存在意義が無い。ただし**以下の内容は今も生きている**
ため、`issue-mr-workflow.md` へ移してから削除する。

| 移す内容 | 移し先 |
|---|---|
| エンジン判定表（`run_shell_command`→Gemini CLI / `Bash`・`PowerShell`→Claude Code、それ以外は即終了） | 「対応工数レポート」節に「エンジン判定」小節として新設 |
| プロジェクトルート取得（`${GEMINI_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-}}`） | 同上 |
| Gemini CLIのhook登録方法（`.gemini/settings.json` の `hooks` キー・matcherの書き方・`command`が単一シェル文字列であること） | 同上 |
| Gemini側サブエージェント探索の**未検証の懸念**（gemini-cli issue #20258 との不整合の可能性） | 「未決定事項・懸念点」へ移設 |
| `.gemini/settings.json` のスキーマを限定的にしか検証していない懸念 | 同上 |

**注意（`.claude/rules/docs-workflow.md` の禁止事項）**: `issue-mr-workflow.md` の「影響範囲」節に
ある**過去issueごとのchangelogエントリは書き換えない**（point-in-timeの記録のため）。
`session-log-hooks.md` への参照が過去エントリに含まれていても、そのまま残す。今回の変更は
**新規エントリの追記**として記録する。

### 2. `.claude/docs/spec/issue-mr-workflow.md`「対応工数レポート」節の更新

| 対象 | 変更内容 |
|---|---|
| session-logsのパス | `usage/session-logs/<safeBranch>/<sessionId>/` → `usage/session-logs/<sessionId>/`。カーソルのキー設計（ブランチ非依存）へ揃えた理由を明記 |
| push断面 | `usage/state/push-index.jsonl` の新設（スキーマ・行番号は1始まり両端含む・基準は「空行を除いた行数」）を追記 |
| engine | `sync_usage_state` の第5引数として引き渡すこと、サブエージェント探索の分岐に使うこと、Gemini分は `subagents/<session_id>/` へ置くため集計globに掛からないことを追記 |
| コンポーネント構成ツリー | `post-push-save-logs.sh` を削除、`.claude/scripts/src/show-push-log.sh` を追加 |
| `.gitignore` | `/usage/` に一本化（`/logs/` の廃止） |

### 3. 「制約: スクリプト経由の`git push`は検知されない」節の記述を実挙動に合わせる

現在の記述は検知を「**前方一致マッチ**」と説明し、それを根拠に制約を導いている。しかし本issueの
作業中に**計3回**、前方一致では発火しないはずのコマンドで発火した（`cd ...` で始まるコマンド、
heredoc本文に語が含まれるだけのコマンド）。

- `.claude/settings.json` の `if` フィールドの実挙動を確認し、記述を**部分一致**として正す。
- 「スクリプト経由のpushは検知されない」という制約自体は、`tool_input.command` に語が現れない
  ケース（ラッパースクリプト実行等）については依然として成立するため、根拠の書き方のみ修正する。
- 逆方向の既知の挙動（**pushしていなくても語が含まれるだけで発火する**）を新たに明記する。

### 4. 新規DDR `0022-push断面の全文コピーをやめ行番号インデックスで表現する.md`

既存の最大番号は0021のため0022を採る。記載内容:

- **背景**: 2系統の重複（計27MB）、`logs/` に読み手が無いこと、カーソルとミラーのキー設計のズレ。
- **決定の根拠となった実測**: push断面が現物transcriptのprefixとバイト一致すること、
  `/compact` がtranscriptを破壊しないこと（compact境界行・`isCompactSummary` 行の追記のみ、
  `preTokens`/`postTokens` は送信コンテキストの話であってディスクの話ではないこと）。
- **決定**: ミラーを1本に統合し、push断面は `push-index.jsonl` の行範囲で表現する。
- **却下案**:
  - `logs/` を単純廃止（push境界の情報が完全に失われる）
  - 現状維持＋保持世代数の上限のみ（責務の重複と「どちらを見るか」問題が残る）
  - ミラー自体をやめて `~/.claude/projects` を直接読む（PR #29で退けた揮発性の問題が再燃するため
    採らない）
- **Gemini対応の扱い**: 保存は維持し集計はスコープ外とした理由、`subagents/<session_id>/` の
  1階層下へ置くことでガード条件なしにスコープ境界を表現した設計。
- **既知の限界**: 行番号の基準が「空行を除いた行数」であること、別マシンで記録されたpushは
  ミラーが無いため `show-push-log.sh` で再現できないこと。

### 5. `.claude/docs/README.md` の更新

- DDR一覧へ 0022 を追加する。
- **spec一覧に `session-log-hooks.md` が元々載っていなかった**（今回の調査で判明）。削除に伴う
  修正は不要だが、一覧の網羅性が崩れていた事実は、今後同じ漏れが起きないよう
  AIアセット反映側（下記7）で扱う。

## AIアセット反映

### 6. `.claude/rules/git-workflow.md` — push検知の誤検知注記を追加

同ファイルには既に「`git`＋`commit` を地の文に書くとPreToolUse hookが誤検知する」という
AIエージェント向け注記があるが、**push検知側には同種の注記が無い**。本issueで計3回踏んだため追記する。

- 現象: コマンド文字列に該当語が含まれるだけで、実際にpushしなくてもPostToolUse hookが発火する
  （対応工数レポートの集計・カーソル前進・compact促しが走る）。
- 回避策: issue本文・MR description等の長文を渡すときは**ファイル経由**にする
  （`gh issue comment --body-file`、`set_mr_description <n> <file>`）。実際にこの方法で
  発火しないことを確認済み。

### 7. `.claude/rules/directory-structure.md` — ツリーと動的ディレクトリ記述の更新

- 動的作成ディレクトリの説明から `logs/`（`post-push-save-logs.sh`）の記述を削除し、
  `usage/` の説明を「セッションログのミラー・集計状態・push断面インデックス」へ更新する。
- **`tests/` がツリーに載っていない**（issue #11で新設されたが追記漏れ）。今回あわせて追加する。
- `.claude/scripts/src/` の説明に `show-push-log.sh` のような参照系スクリプトも含まれることを確認する。

### 8. `.claude/rules/shell-script-style.md` — 実装中に踏んだbashの落とし穴を追記

いずれも本issueで実際に踏み、原因特定に時間を要したもの。

- **`"${N:-\{\}}"` は既定値にバックスラッシュが残る**: bashの二重引用符内では `\{` の
  バックスラッシュが除去されないため、JSONの既定値を与えるつもりが不正な文字列になる。
  代入後に `[ -n "$v" ] || v='{}'` で補う。
- **`grep -c $'\r'` は環境によりパターンが空文字として渡り全行にマッチする**: CR混入の検査には
  `wc -c` と `tr -d '\r' | wc -c` の比較を使う。
- 既存の「文字コード」節（WindowsネイティブjqのCR付与）と関連づけて記載する。

## 実施順

1. DDR 0022 を新規作成する（他ドキュメントから参照されるため最初に作る）
2. `issue-mr-workflow.md` を更新する（統合・パス・push-index・engine・制約の記述修正・
   未決定事項・影響範囲への新規changelogエントリ追記）
3. `session-log-hooks.md` を削除する
4. `.claude/docs/README.md` を更新する
5. `.claude/rules/` 3ファイルを更新する（git-workflow / directory-structure / shell-script-style）
6. `bash .claude/scripts/src/extract-frontmatter.sh .` で `index.jsonl` 群を再生成する
7. worklog push3 に反映内容を記録する

## 検証

- `grep -rn 'session-log-hooks\|logs/push\|/logs/' --include='*.md' .` で、`plans/` `worklog/`
  （寿命の短いファイル）と DDR本文（変更禁止）以外に参照が残っていないことを確認する。
- `docs-workflow.md` の禁止事項どおり、`issue-mr-workflow.md` の過去changelogエントリと
  DDR本文が書き換わっていないことを `git diff` で確認する。
- `index.jsonl` の再生成差分が、削除・新規・更新したファイルと一致することを確認する。

## やらないこと

- DDR本文の変更（`0018` が `session-log-hooks.md` を参照しているが、DDRは本文不変のため触らない）。
- `spec/issue-mr-workflow.md` の過去issueごとのchangelogエントリの書き換え。
- Gemini CLI実機での動作検証（未検証の懸念は懸念として記録を引き継ぐ）。
