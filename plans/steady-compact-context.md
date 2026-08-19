---
title: compact後のコンテキスト再注入と注入量の肥大化検知（全体作業計画）
type: plan
description: issue #57 の全体作業計画。SessionStart hookのmatcherへcompactを追加し、注入内容の拡張としきい値警告を設計・実装・テストする
tags: [plan, session-start-hook, compact, context-injection]
keywords: [compact, SessionStart, additionalContext, しきい値, HANDOFF, 注入量, hook, matcher, DDR, 単体テスト]
---

# 【全体作業計画】issue #57 compact後のコンテキスト再注入

> **注記**: 本ファイルは本来planツール（Planモード）で作成する「全体作業計画」だが、本セッションは
> 非対話的なリモート実行環境であり、Planモードでの承認往復を待てないため、Write/Editで作成した。
> 内容・役割は通常の全体作業計画と同じ（issueにつき1つ）。

## 対象issue

[#57 compact後にSessionStart hookが発火せずブランチ・issue/PR情報が再注入されない](https://github.com/yuki-matsu783/MR-driven-workflow/issues/57)

## 課題（issueの要約）

1. `.claude/settings.json` の `hooks.SessionStart` matcherが `startup|resume|clear` で、`compact` が
   含まれていない。compact後は要約に残ったぶんしか作業コンテキストが参照できない。
2. compact後に特に失われては困る情報（`HANDOFF.md` の現在地・次にやること、ブランチ固有の
   `plans/【*.md` 等）を注入対象へ含めるかを設計判断する必要がある。
3. 注入テキストが肥大化した場合に、スクリプト自身がサイズを測って警告を出す仕組みが無い。

## 調査で確認済みの事実（フェーズ2は省略し、計画作成時に実測で完了）

- `.claude/settings.json` の matcher は `startup|resume|clear`。`compact` は含まれていない。
- `.claude/docs/spec/issue-mr-workflow.md` L287-288 に、compactを**意図的に外した理由**が
  「コンテキスト圧縮のたびに `gh` API呼び出しが走るのを避ける」として明記されている。
  → 今回はこの決定を覆すことになるため、**理由の再評価をDDRへ残す必要がある**。
- 同spec L302-304 に、hookは「ブランチ／issue／PR／未解決レビューコメント件数」に絞り、
  `get_branch_work_files` や `HANDOFF.md` の内容表示は `resume` の役割として**含めない**と
  明記されている。→ 今回はこの線引きも見直す。
- `session-start.sh` は現在、関数定義と本体処理がトップレベルに混在しており、
  **sourceすると本体（stdin読み取り）まで走ってしまうため単体テストできない**。
- 単体テストの置き場は issue #63（DDR 0031）で `tests/` → `.claude/scripts/test/` へ移動済み。
  **issue本文の「`tests/` 配下」は移動前の記述であり、実際の配置先は `.claude/scripts/test/`**。
- `Provider.sh` に `get_branch_work_files`（ブランチ固有のplans/worklog/reports一覧）が既にある。

## 方針

| # | 論点 | 決定 |
|---|---|---|
| A | matcherへの `compact` 追加 | 追加する。`fork` は従来どおりスコープ外 |
| B | HANDOFF.md の注入 | **「## 次にやること」節のみ**を注入する（全文は注入しない） |
| C | plans/worklog の注入 | **ファイル名の一覧のみ**（`get_branch_work_files`）。中身は注入しない |
| D | 注入対象の拡張をcompact時だけにするか | **しない**（起動要因によらず常に同じ内容を注入する） |
| E | しきい値超過時の挙動 | **警告のみ・全量注入**（切り詰めはしない） |
| F | しきい値の値 | 8000バイト（既定値。環境変数で上書き可能） |
| G | テスト可能性 | `session-start.sh` を「関数定義＋`main`」構造へ変更し、source時は本体を実行しない |

## 作業ステップ

1. **フェーズ3（実装・テスト）**
   1. `.claude/settings.json` の matcher を `startup|resume|clear|compact` へ変更。
   2. `session-start.sh` をリファクタ（トップレベル処理を `main` へ、source時ガードを追加）。
   3. 純粋関数を追加: `context_text_bytes` / `append_size_warning` /
      `extract_handoff_next_steps` / `format_work_files_line`。
   4. `build_context` から上記を呼び、HANDOFF「次にやること」・作業ファイル一覧を注入内容へ追加。
   5. `.claude/scripts/test/test_session_start.sh` を新設（`passed=N failures=N` 規約）。
   6. 既存テスト5本の回帰確認・`bash -n` 構文チェック。
2. **フェーズ4（設計反映）**
   1. `.claude/docs/spec/issue-mr-workflow.md`「セッション開始時の自動コンテキスト注入」節を
      現在の仕様へ更新し、「## 影響範囲」へ issue #57 のエントリを追記。
   2. DDR を1本追加（matcherへのcompact追加・注入範囲・しきい値・警告のみ採用の理由と却下案）。
   3. `.claude/docs/README.md` のDDR一覧へ追加。
3. **フェーズ5**: 人間のレビュー・マージ。

## 守るべき条件

- **DDR本文・spec の「## 影響範囲」過去エントリは変更しない**（追記のみ）。
- hookは**非侵襲的（fail-open）**であること。追加処理の失敗でセッション開始をブロックしない。
- サブエージェント内では従来どおり `agent_id` 判定で何もしない（受け入れ条件）。
- 既存テスト5本のアサーションを変更しない。
