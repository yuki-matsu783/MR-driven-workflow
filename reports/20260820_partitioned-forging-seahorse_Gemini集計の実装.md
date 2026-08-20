---
title: Gemini CLIセッションログ集計の実装結果（issue #97 フェーズ3）
type: report
description: Gemini CLIのJSONLセッションログを対応工数レポートの集計対象へ加えた実装とテストの結果・確認事項
tags: [usage-report, gemini-cli, hooks, test]
keywords: [_usage_gemini_fold, _usage_gemini_merge_state, build_usage_report_body, gemini-totals, needsReset, diffAllZero, 二重計上, バイト一致, テスト]
---

# 実装結果: Gemini CLIセッションログの集計を追加する（issue #97 フェーズ3）

- issue: [#97](https://github.com/yuki-matsu783/MR-driven-workflow/issues/97)
- PR: [#101](https://github.com/yuki-matsu783/MR-driven-workflow/pull/101)（Draft）
- 個別作業計画: `plans/【実装】【テスト】Gemini CLIセッションログの集計を追加する.md`

## 結論

**計画どおり実装し、検証手順の全項目が通った。** Gemini CLIのセッションログから
ツール実行回数・ツールエラー回数・応答回数・使用モデル・稼働時間・トークンを集計し、
対応工数レポートへ出せる状態になった。Claude Code経路は**集計結果・レポート本文とも変化しない**
ことを機械的に確認した。

| 受け入れ条件 | 担保 |
|---|---|
| Gemini CLIでも対応工数レポートが投稿される | 投稿ガードを engine=gemini のときだけ「トークン合計・ツール実行回数・応答回数のいずれか > 0」へ広げた |
| 同じ範囲を二重計上しない | テスト「同じスナップショットの再突合は差分0」「ブランチ切替後も新ブランチへ再計上しない」 |
| トークンが取れない場合に空テーブル・0の羅列にしない | テスト「モデル行が0件ならテーブルのヘッダごと出さない」 |
| Claude Codeの集計結果・レポート内容が変化しない | 旧テスト33ケースが新ライブラリで `failures=0` ／ レポート本文が旧実装と**バイト一致** |

## 変更したもの

| ファイル | 変更 |
|---|---|
| `.claude/hooks/lib/UsageTracking.sh` | `_usage_gemini_fold` / `_usage_gemini_merge_state` / `_usage_read_gemini_totals` / `_usage_write_gemini_totals` / `_sync_usage_state_gemini` を新設し、`sync_usage_state` へ分岐を1つ追加 |
| `.claude/hooks/post-push-usage-report.sh` | 本文組み立てを `build_usage_report_body` へ切り出し、`BASH_SOURCE` ガードを追加。トークン列をデータで切り替え、使用モデル行・ツールエラー行・ブランチ帰属の注記を追加、投稿ガードを拡張 |
| `.claude/scripts/test/test_usage_tracking.sh` | ケースを48件追加（33 → 81）。**既存33ケースのアサーションは1行も変更していない** |

Claude Code用の集計関数（`_usage_aggregate_new_lines` / `_usage_aggregate_transcript` /
`_usage_merge_state` / `_usage_read_cursor` / `_usage_write_cursor` /
`_usage_aggregate_and_merge_subagents`）は**1行も変更していない**。

## 計画から変えた点（実装中に判明したもの）

### 1. `sync_usage_state` の分岐を「関数呼び出し1行」にした

計画では「`sync_usage_state` へ engine 分岐を1つ追加」としていたが、Gemini経路の処理を
`sync_usage_state` の中へ直接書くと、Claude Code経路の行が下へずれて差分が読みにくくなる。
分岐先を `_sync_usage_state_gemini` として独立させ、`sync_usage_state` 側の追加を
**5行（分岐と委譲のみ）**に留めた。Claude Code経路の既存行は1行も動いていない。

### 2. 3桁区切りを jq の `commafy` で行った（`fmt_num` を行全体へ適用しない）

トークンテーブルを jq 側で組み立てる形にしたため、当初は組み上がった行全体へ `sed` で3桁区切りを
入れていた。**これはモデル名に含まれる数字列を壊す**（`claude-3-5-sonnet-20241022` →
`claude-3-5-sonnet-20,241,022`）。実装中に気づき、jq内に `def commafy` を定義して
**数値セルにだけ**適用する形へ直した。テスト
「3桁区切りが入りモデル名の数字は区切られない」で回帰を防いでいる。

### 3. `def epoch_from_iso8601` は複製した（計画の第一候補どおり）

`_usage_aggregate_transcript` の中の同名defはjqプログラム内の定義でシェルから呼べないため、
`_usage_gemini_fold` 側へ複製した。共通化すると `_usage_aggregate_transcript` へ手を入れることに
なり、「Claude Code側は無改造」という担保が弱くなる。複製である旨と理由はコード側のコメントに
残した。

### 4. `_usage_append_push_index` はGemini経路で呼ばないことにした

計画では「実装時に決める」としていた論点。**呼ばない。** `from`/`to` は
「空行を除いた行番号の範囲」という意味を持つが、Gemini経路では行番号が「まだ数えていない量」を
表さない（同じidが再送されるため）。同じキー名に別の意味の値を入れると、`push-index.jsonl` を
読む側が区別できない。記録を見送り、代わりに前回累計を
`usage/state/gemini-totals/<sessionId>.json` に持つ形とした。

## 実装中に見つけて直した不具合（自分の実装）

**未完了ステータスのツール呼び出しを実行回数に数えていた。** 最初の実装は `toolCalls[]` を
status に関係なく数えており、`awaiting_approval`（＝ユーザーの承認待ちで、まだ実行されていない）が
実行回数へ入っていた。決定H「未完了はどちらにも入れない」に反する。完了扱いの status を
`success` / `error` / `cancelled` の3つに限定して修正し、テスト
「未完了(awaiting_approval)は実行回数に入れない」を追加した。

合成フィクスチャを1本作って実際に走らせたことで気づいた。**仕様を読み直すのではなく、
各statusを1つずつ含むフィクスチャを流したことが発見につながっている。**

## 検証結果

| # | 手順 | 結果 |
|---|---|---|
| 1 | `bash -n` （変更した3ファイル） | すべてOK |
| 2 | `bash .claude/scripts/test/test_usage_tracking.sh` | **passed=81 failures=0** |
| 2' | 変更前のテストファイルを**新しいライブラリに対して**実行 | **passed=33 failures=0**（Claude Code側の集計結果が変わっていないことの直接の確認） |
| 3 | `.claude/scripts/test/test_*.sh` を全実行（11ファイル） | `test_post_issue_create_notice.sh` の `failures=1` のみ。これは既存の失敗（issue #94）で本MRとは無関係 |
| 4 | CR混入の検査（バイト数比較） | 3ファイルともCRなし |
| 5 | レポート本文の**旧実装との比較** | Claude形式のstate（サブエージェント・skill呼び出し・ユーザーへの質問を含む）で `diff` が**完全一致** |
| 6 | `source` してもhookのmainが走らないこと | ハングせず関数だけ読み込まれることを確認 |

### 手順3の全結果

```
test_adversarial_review_count.sh    passed=22  failures=0
test_check_base_conflicts.sh        passed=13  failures=0
test_cleanup_task.sh                passed=37  failures=0
test_collect_review_points.sh       passed=17  failures=0
test_extract_frontmatter.sh         passed=23  failures=0
test_post_issue_create_notice.sh    passed=13  failures=1   ← 既存の失敗（issue #94）
test_search_frontmatter.sh          passed=114 failures=0
test_session_start.sh               passed=35  failures=0
test_update_handoff_progress.sh     passed=45  failures=0
test_usage_tracking.sh              passed=81  failures=0
test_vcs_provider.sh                passed=131 failures=0
```

### レビュー指摘の回帰テスト

敵対的レビューで指摘された3つの設計上の欠陥について、回帰テストが通ることを確認した。

| 指摘 | テスト | 結果 |
|---|---|---|
| ブランチ切り替えで全累計を再計上する | `sync(gemini): ブランチ切替後も新ブランチへ再計上しない` | 通過（新ブランチの状態ファイルが作られない＝差分0） |
| 消失検知時に早期リターンして計上が止まる | `sync(gemini): 消失検知後は前回累計が新しい値へ上書きされる` / `消失後も次の断面から計上が再開する` | 通過 |
| レポート内容の担保が無い | `report(claude): 列構成が現行のまま` ほか(a)群 ＋ 旧実装との `diff` | 通過（バイト一致） |

## 未検証として残る範囲

**Gemini CLI実機でのエンドツーエンド検証は行っていない**（開発機に `~/.gemini` が存在しない）。
合成フィクスチャでの検証にとどまるため、次の点は実機で初めて確かめられる。

- hookが実際に渡す `transcript_path` が、想定どおり `chats/session-<TIMESTAMP>-<sessionId先頭8文字>.jsonl`
  の実ファイルを指すか（設計判断B。フェーズ2の調査時点の想定）。
- `tokens` フィールドが実データでどの程度の頻度で付くか（付かないリビジョンばかりのセッションが
  現実に起きるか）。
- `models` に `unknown` が混ざる頻度。
- Gemini CLI のバージョン差（v0.39.0未満の旧 `.json` 形式は決-1により対象外）。

これらはフェーズ4で `.claude/docs/spec/issue-mr-workflow.md` の「未決定事項・懸念点」へ記録する。
