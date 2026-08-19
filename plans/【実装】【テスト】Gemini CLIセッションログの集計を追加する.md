---
title: 【実装】【テスト】Gemini CLIセッションログの集計を追加する
type: plan
description: フェーズ2の調査結論に沿って、Gemini CLIのJSONLセッションログを対応工数レポートの集計対象へ加える実装とテストの計画
tags: [usage-report, gemini-cli, hooks, test]
keywords: [UsageTracking, sync_usage_state, 畳み込み, 累計差分, toolCalls, needsReset, トークン列, フィクスチャ, jq, 二重計上]
---

# 個別作業計画: Gemini CLIセッションログの集計を追加する（issue #97 フェーズ3）

- issue: [#97](https://github.com/yuki-matsu783/MR-driven-workflow/issues/97)
- PR: [#101](https://github.com/yuki-matsu783/MR-driven-workflow/pull/101)（Draft）
- 全体作業計画: `plans/partitioned-forging-seahorse.md`
- 前提となる調査結果: `reports/20260820_partitioned-forging-seahorse_Geminiセッションログの調査.md`

**本ファイルには「これから何をするか」だけを書く。実施結果は
`reports/日付_partitioned-forging-seahorse_Gemini集計の実装.md` へ記録する**
（`.claude/skills/issue-mr-flow/SKILL.md`「計画と実施結果の分離」）。

## 目的

Gemini CLIで作業したときにも、ツール実行回数・ツールエラー回数・応答回数・使用モデル・稼働時間・
トークンを集計した対応工数レポートがMR/PRへ投稿されるようにする。**Claude Code側の集計結果・
レポート内容は1バイトも変えない。**

## 前提（フェーズ2で確定済み・本計画では蒸し返さない）

| # | 決定 |
|---|---|
| C | 差分は**ファイル全体をid単位で畳んで、状態が持つ前回累計との差分**として取る（行カーソル方式は二重計上する） |
| S | 切り詰めへの対応は**不要**（Cが本質的に耐性を持つ）。**消失のみ負値で検知しリセット**する |
| O | 行カーソル・`push-index.jsonl` は差分計算に**使わない**。早期リターンは差分が全て0かで判定する |
| D | `$rewindTo` は集計から**外さない**（レコードを読み飛ばすだけ） |
| E | ブランチ帰属は push時点の `git branch --show-current`。`directories` は使えない |
| F | トークン列はGemini専用構成（Cache Write を出さず、Thoughts・Tool を出す） |
| G | 投稿ガードは「トークン合計・ツール実行回数・応答回数のいずれかが0より大きい」 |
| H | `status == "error"` のみエラー。`cancelled` は実行回数に含めエラーにしない。未完了はどちらにも入れない |
| I | サブエージェントは**保存のみ**（集計しない） |
| K | `sync_usage_state` に分岐を1つ足し、Gemini専用関数を2つ新設。**Claude Code側の関数は無改造** |
| A-1 | `toolCalls[].status` の値集合は `validating/scheduled/executing/awaiting_approval/success/error/cancelled` |
| B | hookの `transcript_path` は実ファイルのフルパス（代替探索は不要） |

## 変更対象ファイル

| ファイル | 変更内容 |
|---|---|
| `.claude/hooks/lib/UsageTracking.sh` | `_usage_gemini_fold` / `_usage_gemini_merge_state` を**新設**し、`sync_usage_state` へ engine 分岐を1つ追加する |
| `.claude/hooks/post-push-usage-report.sh` | トークンテーブルの列構成を engine で切り替え、ツールエラー行を追加し、投稿ガードを広げる |
| `.claude/scripts/test/test_usage_tracking.sh` | Gemini用のケースを追加する（**既存33ケースのアサーションは1行も変更しない**） |

**上記以外のファイルは触らない。** 特に `_usage_aggregate_new_lines` /
`_usage_aggregate_transcript` / `_usage_merge_state` / `_usage_read_cursor` /
`_usage_write_cursor` / `_usage_aggregate_and_merge_subagents` は変更対象外である。

## 実装方針

### 1. `_usage_gemini_fold <jsonl_path>` （新設）

セッションJSONLを読み、**累計スナップショット**をJSONで標準出力へ返す。

**入出力**

```
入力: ミラー済みのセッションログのパス（usage/session-logs/<sessionId>/main.jsonl）
出力: {totalLines, turns, activeSeconds,
       tokens: {"<model>": {input, output, cached, thoughts, tool}},
       tools: {"<toolName>": <回数>},
       toolErrors: {"<toolName>": <回数>},
       models: ["<model>", ...]}
```

**レコードの振り分け**

| レコード | 扱い |
|---|---|
| 1行目のメタデータ（`sessionId`/`projectHash` を持ち `id` を持たない） | スキップ |
| `{"$rewindTo": "<messageId>"}` | **読み飛ばす**（メッセージを削らない。決定D） |
| `{"$set": {...}}` に `messages` がある | 配列の各要素をメッセージとして畳み込みへ流す |
| `{"$set": {...}}` の上記以外（メタデータの部分更新） | 無視 |
| メッセージ本体（`id` を持つ） | 畳み込みへ流す |
| パースできない行 | **捨てる**（`fromjson?`。処理は止めない） |

**畳み込み（id をキーに後勝ちマージ）**

- 同じ `id` が複数回現れたら、**後に現れた版で上書きする**。
- **例外: 新しい版の `tokens` が `null`／欠落なら、前の版の `tokens` を引き継ぐ**
  （実測で「`tokens: null` の版が先、値ありの版が後」だけでなく逆順もありうるため。決定F）。

**集計**

| 指標 | 算出 |
|---|---|
| `turns` | 畳み込み後の `type == "gemini"` のメッセージ数（ユニークid数） |
| `models` | 畳み込み後のメッセージの `model` の集合。欠落は `unknown` へ寄せる |
| `tokens` | model別に `input`/`output`/`cached`/`thoughts`/`tool` を加算する。**`total` は加算しない**（内訳の合計であり二重計上になる） |
| `tools` | 各メッセージの `toolCalls[]` を `name` ごとに数える（`cancelled` も含む。決定H） |
| `toolErrors` | `status == "error"` のものだけを `name` ごとに数える |
| `activeSeconds` | **畳み込み後のメッセージを `timestamp` 昇順に並べ直してから**隣接gapを積む。gapが `IDLE_GAP_THRESHOLD_SECONDS`（既定300）以上なら `TAIL_BUFFER_SECONDS`（既定30）を積む。負のgapは捨てる（決定Q） |

**実装上の制約（`.claude/rules/shell-script-style.md`）**

- **jqへはファイルパスを渡して `-R -n` + `inputs` で読ませる**。ファイル内容を `--argjson` /
  `--arg` で渡さない（`Argument list too long` になる）。
- jqの起動は**1回**にまとめる。ループ内でjqを呼ばない。
- jqの出力をシェル変数・ファイルへ受けるときは `tr -d '\r'` を通す。
- Windows版jqでは `fromdateiso8601` / `strptime` が**使えない**。`timestamp` をエポック秒へ
  変換する必要がある場合は、`_usage_aggregate_transcript` のjqプログラム内に定義されている
  `def epoch_from_iso8601`（`days_from_civil` による四則演算のみの自前実装）を使う。

### 2. `_usage_gemini_merge_state <existing> <snapshot> <session_id> <branch>` （新設）

累計スナップショットと状態ファイルの前回累計を突き合わせ、差分を `sinceLastPush` へ加算した
新しい状態JSONを返す。

- 前回累計は `existing.sessions[<sessionId>].lastGeminiTotals` に持つ
  （Claude Code側が使う `lastActiveSeconds` とはキーを分ける。**同じセッションIDが両エンジンで
  衝突することは無いが、キーを分けることで取り違えを構造的に防ぐ**）。
- 差分 = `snapshot - lastGeminiTotals` を**全指標について**取る。
  既存 `_usage_merge_state` の `[0, (cur - prev)] | max` を全指標へ拡張する。
- **1指標でも負値が出たら `needsReset` を立てる**（セッションファイルの消失。決定S）。
  - 負値は0へクランプしてから加算する（`sinceLastPush` が負にならない）。
  - `lastGeminiTotals` は**今回のスナップショットで置き換える**（次のpush断面から計上し直す）。
- 返す形は既存 `_usage_merge_state` と同じ `{branch, sessions, sinceLastPush}` に、
  `lastPostedAt` / `agents` があれば引き継ぐ。**既存キーの意味は変えない。**
- `sinceLastPush` へのGemini固有の載せ方:

  | キー | 扱い |
  |---|---|
  | `tokensByModel[<model>]` | 既存の `{input, output, cacheCreate, cacheRead}` に `thoughts` / `tool` を**追加**する。Geminiでは `cacheCreate` は常に0、`cached` は `cacheRead` へ入れる |
  | `toolCalls[<name>]` | 既存キーをそのまま使う |
  | `toolErrors[<name>]` | **新設**。Claude Code経路では書かれない（キー自体が現れない） |
  | `turns` / `activeSeconds` | 既存キーをそのまま使う |
  | `skillCalls` / `agentCalls` / `askUserQuestions` | Gemini経路では**加算しない**（対応する概念が無い。空のまま） |

- **既存の状態ファイル（Claude Code分）を読み書きしても壊れないこと**を、追加キーのみに
  留めることで担保する。

### 3. `sync_usage_state` への分岐追加

`engine = gemini` のときだけ別経路を通す。Claude Code経路の行は**1行も動かさない**
（差分を読んだときに「既存経路は変わっていない」と一目で分かる形にする）。

```
engine = claude → 現行のまま（行カーソル → _usage_aggregate_new_lines → _usage_merge_state → …）
engine = gemini → 下記
```

1. `_usage_sync_session_logs`（**既存のGemini分岐をそのまま使う**）でミラーし、`log_dir` を得る。
2. `_usage_gemini_fold "${log_dir}/main.jsonl"` で累計スナップショットを得る。
3. 状態ファイルを読む（**空文字列・不正JSONなら `{}` へフォールバックする既存の自己回復ロジックを
   同じ形で使う**）。
4. `_usage_gemini_merge_state` で新しい状態を作る。
5. **差分がすべて0なら、状態ファイルを書かず既存状態をそのまま返して終了する**（決定O）。
6. 状態ファイルへ書き、標準出力へ返す。
7. `_usage_read_cursor` / `_usage_write_cursor` は**呼ばない**（決定O）。
8. `_usage_aggregate_and_merge_subagents` は**呼ばない**（決定I）。

**早期リターンの位置がClaude Code経路と違う点に注意する。** Claude Code経路は「新規行が無ければ
ミラーもスキップ」だが、Gemini経路は内容ベースでしか判定できないため**ミラー → 畳み込み →
差分0判定**の順になる。ミラーは冪等な上書きコピーなので実害は無い。この差はコメントとして残す。

**`_usage_append_push_index` の扱いは実装時に決める**（下記「実装時に決めること」1）。

### 4. `post-push-usage-report.sh`

| 箇所 | 変更 |
|---|---|
| トークンテーブルのヘッダ・行 | engine で列構成を切り替える。`claude`: `Input / Output / Cache Write / Cache Read`（現行のまま）。`gemini`: `Input / Output / Cache Read / Thoughts / Tool` |
| ツールエラー | `toolErrors` があるとき、`**ツール実行回数**` の直後に `**ツールエラー回数**: <name>: <n>, …` を出す。**0のキーは表示しない**（既存の `toolCalls` と同じ扱い） |
| 投稿要否ガード | Gemini経路では「トークン合計・ツール実行回数・応答回数の**いずれか**が0より大きければ投稿」へ広げる。**Claude Code側の判定式は変更しない** |
| ブランチ帰属の注記 | Gemini経路のレポートに、「1つのセッション内でブランチを切り替えた場合、切り替え前の分もこのブランチへ計上される」旨を1行入れる（決定Eの限界の明示） |
| サブエージェント節 | Gemini経路では出さない（決定I。`agents` が空なので現行のロジックで自然に出ない見込みだが、確認する） |

### 5. テスト（`.claude/scripts/test/test_usage_tracking.sh`）

既存の型（`source` → 一時ディレクトリへフィクスチャ → 関数を直接呼ぶ → `assert_eq` →
`passed=N failures=N`）に合わせて追加する。

| # | ケース | 検証すること |
|---|---|---|
| 1 | 同じファイルを2回畳んで差分を取る | 差分がすべて0（**二重計上しない**ことの直接の裏付け＝受け入れ条件） |
| 2 | リビジョン再送（`tokens: null` → 値あり、`executing` → `success`） | 後勝ちマージでtokensが消えない・ツールが1回だけ数えられる |
| 3 | `$set.messages` による全メッセージ再送 | 二重計上しない |
| 4 | `$rewindTo` を含む | メッセージが削られない |
| 5 | 切り詰め（行数の減少） | 累計が一致し差分0 |
| 6 | セッションファイル消失（累計が減る） | `needsReset` が立ち、`sinceLastPush` が負にならない |
| 7 | 空ファイル / 不正JSON行の混入 | 落ちない。不正行だけを捨てる |
| 8 | ツールの `status` | `error` のみエラー、`cancelled` は実行回数のみ、未完了はどちらにも入らない |
| 9 | `activeSeconds` | timestampが前後するフィクスチャで、並べ直して算出される |
| 10 | `sync_usage_state` を `engine=gemini` で通す結合ケース | 状態ファイルが書かれ、2回目の呼び出しで差分0の早期リターンになる |

- **既存33ケースは1行も変更しない**（変更しないこと自体が「Claude Code側の集計結果が変わらない」
  ことの担保になる）。
- **テストで `jq -r` の結果を `assert_eq` へ渡すときは `tr -d '\r'` を通す**
  （Windows版jqがCRを付与する。issue #94 と同じ罠を新規テストで踏まないため）。
- **終了コードを検査するケースでは `"$(func; echo $?)"` の形を使わない**（`set -e` 配下では
  空文字列になる。`if func; then … else … fi` で受ける）。

## やらないこと

- **Claude Code側の集計関数・レポート内容の変更**（既存テストのアサーションを変更しないことで担保）
- **サブエージェント分の集計**（決定I。保存のみ）
- **テレメトリ関連一式**（issue #105 の担当）
- **旧 `.json` 形式への対応**（決-1）
- **Gemini CLI実機でのエンドツーエンド検証**（環境が無い。未検証としてフェーズ4でspecへ記録する）
- **`.gemini/settings.json` の変更**（決-5）
- **issue #97 本文の編集**（決-6）
- GitLab向けの追加対応

## 実装時に決めること（この計画では確定させない）

1. **`_usage_append_push_index` をGemini経路で呼ぶか。** 呼ぶ場合、`from`/`to` は行範囲ではなく
   「畳み込み後のメッセージ数のスナップショット」という別の意味になる（決定O）。
   意味の取り違えを避けられる形にできなければ**記録を見送る**。
2. **`toolErrors` をレポートのどこへ置くか**（`**ツール実行回数**` の直後を第一候補とする）。
3. `def epoch_from_iso8601` を、`_usage_aggregate_transcript` から**共通のjqスニペットとして
   切り出して両者で共有するか、`_usage_gemini_fold` 側へ複製するか**。切り出しは
   `_usage_aggregate_transcript` に手を入れることになるため（「Claude Code側は無改造」に抵触
   しうる）、**複製を第一候補**とし、複製した旨と出典をコメントで示す。

## 検証手順

コミット前に以下をすべて実行し、1つでも落ちたらコミットしない。

```bash
# 1. 構文チェック（変更した .sh すべて）
bash -n .claude/hooks/lib/UsageTracking.sh
bash -n .claude/hooks/post-push-usage-report.sh
bash -n .claude/scripts/test/test_usage_tracking.sh

# 2. 対象テスト（新規ケース＋既存33ケース）
bash .claude/scripts/test/test_usage_tracking.sh          # passed=N failures=0

# 3. 他のテストへの巻き添えが無いこと
for t in .claude/scripts/test/test_*.sh; do echo "== $t"; bash "$t"; done

# 4. CR混入の検査（バイト数比較。grep -c $'\r' は使わない）
for f in .claude/hooks/lib/UsageTracking.sh .claude/hooks/post-push-usage-report.sh \
         .claude/scripts/test/test_usage_tracking.sh; do
  [ "$(wc -c < "$f")" = "$(tr -d '\r' < "$f" | wc -c)" ] && echo "OK  $f" || echo "CR! $f"
done
```

- **`test_post_issue_create_notice.sh` の `failures=1` は既存の失敗**であり（issue #94）、
  本MRの変更とは無関係である。手順3でこの1件だけが失敗することを確認する。
- 手順2の「既存33ケースが `failures=0` のまま」が、受け入れ条件
  「Claude Codeでの既存の集計結果・レポート内容が変化しないこと」の担保である。

## 記録先

- 詳細な試行錯誤: `worklog/日付_partitioned-forging-seahorse_【実装】【テスト】Gemini CLIセッションログの集計を追加する_push<N>.md`
- 実施結果（正文）: `reports/日付_partitioned-forging-seahorse_Gemini集計の実装.md`（＋同名の `.html`）
