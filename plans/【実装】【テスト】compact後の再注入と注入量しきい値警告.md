---
title: 【実装】【テスト】compact後の再注入と注入量しきい値警告
type: plan
description: issue #57 の個別作業計画。settings.jsonのmatcher拡張・session-start.shの関数分割と注入内容の拡張・しきい値警告・単体テストの追加を扱う
tags: [plan, session-start-hook, unit-test, context-injection]
keywords: [compact, matcher, additionalContext, しきい値, HANDOFF, 次にやること, get_branch_work_files, main関数, source, 単体テスト]
---

# 【実装】【テスト】compact後の再注入と注入量しきい値警告

全体作業計画: `plans/steady-compact-context.md`（issue #57）

## 1. `.claude/settings.json`

`hooks.SessionStart[0].matcher` を `"startup|resume|clear"` → `"startup|resume|clear|compact"` へ。

`fork` は追加しない（issue #34以前からのスコープ外判断を維持。fork時は親のコンテキストが
そのまま引き継がれるため、再注入の必要性が薄い）。

## 2. `session-start.sh` の構造変更（テスト可能化）

現状はトップレベルに「stdin読み取り → `agent_id` 判定 → index.jsonl再生成 → `build_context` →
出力」が直書きされており、`source` すると本体まで走ってしまう。

- 本体処理をすべて `main()` へ移す。
- 末尾を `if [ "${BASH_SOURCE[0]}" = "${0}" ]; then main; fi` にする。
  - hookとして `bash session-start.sh` で起動された場合は `BASH_SOURCE[0] == $0` となり `main` が走る。
  - テストから `source` された場合は一致しないため、関数定義だけが読み込まれる。
- `main` 内では従来どおり `exit` を使う（トップレベル実行時のみ呼ばれるため意味は変わらない）。

## 3. 追加する純粋関数（テスト対象）

| 関数 | 責務 |
|---|---|
| `context_text_bytes <text>` | 注入テキストのバイト数を返す。日本語を含むため**文字数ではなくバイト数**で測る |
| `append_size_warning <text> [limit]` | バイト数が `limit` を超えたときだけ、末尾へ整理を促す指示文を追記して返す。超えなければ入力をそのまま返す |
| `extract_handoff_next_steps <file>` | `HANDOFF.md` から `## 次にやること` 節（見出し行を含み、次の `## ` 見出しの手前まで）を抜き出す。末尾の空行は落とす。節が無い／ファイルが無い場合は失敗（非ゼロ）を返す |

しきい値の既定値は `CONTEXT_SIZE_WARN_BYTES`（既定 `8000`）。環境変数で上書きできるようにして
おき、テストからは引数で明示的に渡す。

### 警告文の内容

しきい値超過時に `additionalContext` の末尾へ足す指示文。**エージェントへの指示**として書く
（issueの「ユーザーへ警告し、対象ファイルの整理を促すこと」という要求に対応）。実測バイト数と
しきい値を含め、どのファイルを整理すればよいかを名指しする。

## 4. `build_context` の拡張

既存の4項目（ブランチ／issue／PR／未解決レビューコメント件数）の後ろへ、以下を追加する。

1. `- 個別作業計画・worklog: <ファイル名の一覧（カンマ区切り）>`
   （`get_branch_work_files` の結果。**中身は注入せず、ファイル名だけ**。0件なら行自体を出さない）
2. `## HANDOFF.md「次にやること」` 見出しと、その節の中身
   （`extract_handoff_next_steps` の結果。取得できなければ行自体を出さない）

いずれも**取得に失敗してもブランチ情報の注入は続行する**（fail-open）。
MCP経路（`gh`/`glab` 不在）でも同じ内容を足す（どちらもローカル操作のみで得られるため）。

最後に `append_size_warning` を通してから `write_additional_context` へ渡す。

## 5. 単体テスト `.claude/scripts/test/test_session_start.sh`

`.claude/scripts/test/test_update_handoff_progress.sh` を雛形にする（`passed=N failures=N` を出力し、
失敗があれば終了コード1）。`session-start.sh` を `source` して関数を直接呼ぶ。

検証項目:

- `context_text_bytes`
  - ASCIIのみのテキストが文字数と一致する
  - 日本語を含むテキストが**文字数ではなくバイト数**（UTF-8で3バイト/文字）になる
- `append_size_warning`
  - しきい値以下: 入力とまったく同じ文字列が返る（警告文が**含まれない**）
  - しきい値ちょうど: 追記されない（境界値。`-le` 判定）
  - しきい値超過: 元テキストが先頭に保たれたまま、末尾へ警告文が追記される
  - 超過時の警告文に実測バイト数としきい値が含まれる
  - 既定値（引数省略）でも動作する
- `extract_handoff_next_steps`
  - 「次にやること」節だけが抜き出される（前後の節が混ざらない）
  - 節が最終節（後続の `## ` が無い）でも末尾まで抜き出せる
  - 節が存在しないファイルでは失敗（非ゼロ）を返す
  - 存在しないファイルでは失敗（非ゼロ）を返す
- source時に本体が実行されない（`main` が定義されているだけであること）

**注意**: 終了コードの検査は `"$(func; echo $?)"` 形式を使わず `if func; then ... else ... fi` で
受ける（`.claude/rules/shell-script-style.md`「テスト」）。

## 6. 回帰確認

- 既存テスト5本（`test_vcs_provider` / `test_extract_frontmatter` / `test_update_handoff_progress` /
  `test_usage_tracking` / `test_check_base_conflicts`）を実行し `failures=0` を確認。
- `bash -n` で変更した `.sh` の構文チェック。
- `session-start.sh` を実際にhookと同じ形（stdinへJSONを与える）で起動し、
  `additionalContext` が正しいJSONで出ることを確認する。
- サブエージェント相当（`agent_id` 付きJSON）で何も出力しないことを確認する。
