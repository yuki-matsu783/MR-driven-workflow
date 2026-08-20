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

**出典列の読み方**: `2-6` は**調査担当（AI）が調査結果として出した結論**で、flow-id 2-8 の
レビューで「レビューOK」を受けて合意済みになったもの。`2-4` は**個別調査計画のレビュー往復で
ユーザーが明示的に判断したもの**（個別調査計画の 決-N に対応）。前者はフェーズ3のレビューで
根拠を伴えば蒸し返してよいが、後者は蒸し返さない。

| # | 決定 | 出典 |
|---|---|---|
| C | 差分は**ファイル全体をid単位で畳んで、前回累計との差分**として取る（行カーソル方式は二重計上する） | flow-id 2-6（調査結論）→ 2-8で合意 |
| S | 切り詰めへの対応は**不要**（Cが本質的に耐性を持つ）。**消失のみ負値で検知しリセット**する | flow-id 2-6（調査結論）→ 2-8で合意 |
| O | 行カーソル・`push-index.jsonl` は差分計算に**使わない**。早期リターンは差分が全て0かで判定する | flow-id 2-6（調査結論）→ 2-8で合意 |
| D | `$rewindTo` は集計から**外さない**（レコードを読み飛ばすだけ） | flow-id 2-6（調査結論）→ 2-8で合意 |
| E | ブランチ帰属は断面時点の `git branch --show-current`。`directories` は使えない | flow-id 2-6（調査結論）→ 2-8で合意 |
| F | トークン列はGemini専用構成（Cache Write を出さず、Thoughts・Tool を出す） | flow-id 2-6（調査結論）→ 2-8で合意 |
| G | 投稿ガードは「トークン合計・ツール実行回数・応答回数のいずれかが0より大きい」 | flow-id 2-6（調査結論）→ 2-8で合意 |
| H | `status == "error"` のみエラー。`cancelled` は実行回数に含めエラーにしない。未完了はどちらにも入れない | flow-id 2-6（調査結論）→ 2-8で合意 |
| I | サブエージェントは**保存のみ**（集計しない） | flow-id 2-6（調査結論）→ 2-8で合意 |
| K | `sync_usage_state` に分岐を1つ足し、Gemini専用関数を2つ新設。**`UsageTracking.sh` のClaude Code側の関数は無改造** | flow-id 2-6（調査結論）→ 2-8で合意 |
| Q | `activeSeconds` の閾値定数（`IDLE_GAP_THRESHOLD_SECONDS` / `TAIL_BUFFER_SECONDS`）と算出方式はClaude Code経路と同一にする | flow-id 2-6（調査結論）→ 2-8で合意 |
| A-1 | `toolCalls[].status` の値集合は `validating/scheduled/executing/awaiting_approval/success/error/cancelled` | flow-id 2-6（実測） |
| B | hookの `transcript_path` は実ファイルのフルパス（代替探索は不要） | flow-id 2-6（実測） |
| 決-1 | 旧 `.json` 形式には対応しない（新形式のみ） | flow-id 2-4（ユーザー判断） |
| 決-5 | `.gemini/settings.json` は変更しない（テレメトリは issue #105） | flow-id 2-4（ユーザー判断） |
| 決-6 | issue #97 の本文は編集しない | flow-id 2-4（ユーザー判断） |

**決定Kの適用範囲**: 「無改造」の対象は `UsageTracking.sh` のClaude Code用集計関数である。
`post-push-usage-report.sh` は変更対象ファイルであり、**レポート本文の組み立てを関数へ切り出す
リファクタは行う**（下記「4.」）。ただし**Claude Code経路の出力バイト列は変わらない**ことを
テストで担保する。

## 変更対象ファイル

| ファイル | 変更内容 |
|---|---|
| `.claude/hooks/lib/UsageTracking.sh` | `_usage_gemini_fold` / `_usage_gemini_merge_state` を**新設**し、`sync_usage_state` へ engine 分岐を1つ追加する |
| `.claude/hooks/post-push-usage-report.sh` | 本文の組み立てを `build_usage_report_body` へ切り出して `source` 可能にし（実行ガードを追加）、トークンテーブルの列構成をデータで切り替え、ツールエラー行・使用モデル行を追加し、投稿ガードを広げる |
| `.claude/scripts/test/test_usage_tracking.sh` | Gemini用のケースとレポート本文のケースを追加する（**既存33ケースのアサーションは1行も変更しない**） |

新規に作られるディレクトリ: `usage/state/gemini-totals/`（`.gitignore` 対象の `usage/` 配下。
下記「2.」）。

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
| `activeSeconds` | **畳み込み後のメッセージを `timestamp` 昇順に並べ直してから**隣接gapを積む。gapが `IDLE_GAP_THRESHOLD_SECONDS`（既定300）以上なら `TAIL_BUFFER_SECONDS`（既定30）を積む。負のgapは捨てる。**走査後、対象メッセージが1件以上あれば末尾の未クローズなセグメントを閉じる分として `TAIL_BUFFER_SECONDS` をもう1回加算する**（決定Q） |

**`activeSeconds` の末尾加算を省略しないこと。** 既存 `_usage_aggregate_transcript` は隣接gapの
積算に加えて、走査完了後に「集計対象が1件以上あれば `TAIL_BUFFER_SECONDS` をもう1回加算する」
処理を持つ（同関数のコメント「走査完了後、集計対象entryが1件以上あれば…」）。これを落とすと
(a) メッセージ1件のセッションが常に0秒になり、(b) 同じ時系列でもGemini側が常に
`TAIL_BUFFER_SECONDS` 分だけ小さくなる。決定Qが要求する「Claude Code経路と同一の算出方式」に
反するため、**末尾加算まで含めて移植する**（テストケース9で担保する）。

**実装上の制約（`.claude/rules/shell-script-style.md`）**

- **jqへはファイルパスを渡して `-R -n` + `inputs` で読ませる**。ファイル内容を `--argjson` /
  `--arg` で渡さない（`Argument list too long` になる）。
- jqの起動は**1回**にまとめる。ループ内でjqを呼ばない。
- jqの出力をシェル変数・ファイルへ受けるときは `tr -d '\r'` を通す。
- Windows版jqでは `fromdateiso8601` / `strptime` が**使えない**。`timestamp` をエポック秒へ
  変換する必要がある場合は、`_usage_aggregate_transcript` のjqプログラム内に定義されている
  `def epoch_from_iso8601`（`days_from_civil` による四則演算のみの自前実装）を使う。

### 2. 前回累計の置き場所（**ブランチ非依存**にする）

**前回累計 `lastGeminiTotals` を、ブランチ別の状態ファイル `usage/state/<safeBranch>.json` へ
置いてはいけない。** セッション単位の独立したファイル
`usage/state/gemini-totals/<sessionId>.json` に持つ。

理由: 同じGeminiセッションのままブランチAで数回断面を取り、その後ブランチBで初めて断面を取ると、
Bの状態ファイルには当該sessionIdの前回累計が存在しない。差分＝スナップショット全量となり、
**Aで計上済みの範囲がまるごとBの初回差分として再計上される**。これは issue #37 が
`UsageTracking.sh` 冒頭コメントに記録している既知の不具合そのもので、同issueはこれを避けるために
カーソルを `usage/state/session-cursors/<sessionId>.json`（ブランチ非依存）へグローバル化した。
ブランチ別に置くと、その修正をGemini経路で作り直すことになり、issue #97 の受け入れ条件
**「同じ範囲を二重計上しない」に抵触する**。

- 決定Eが認めている限界は「差分を**どのブランチへ帰属させるか**」の不正確さであって、同じ範囲を
  2つのブランチへ二重に載せてよいという意味ではない。この点でEは免責にならない。
- **既存の `session-cursors/<sessionId>.json` へ相乗りしない。** あのファイルは `lastLineCount`
  という行カーソルの置き場であり、決定Oで「行カーソルは使わない」と決めた対象そのものである。
  同じファイルに別の意味の値を同居させると、読み手が「結局カーソルを使っているのか」と誤読する。
- 置き場所は `usage/`（`.gitignore` 対象）配下なのでコミットされない。ディレクトリが無ければ作る。
- Claude Code側が使う `sessions[<sessionId>].lastActiveSeconds`（ブランチ別状態ファイル内）は
  **一切触らない**。

ファイルの形は次のとおり（`_usage_gemini_fold` の出力からレポート用の派生値を除いたもの）。

```
{"totalLines": N, "turns": N, "activeSeconds": N,
 "tokens": {"<model>": {input, output, cached, thoughts, tool}},
 "tools": {"<toolName>": N},
 "toolErrors": {"<toolName>": N}}
```

### 3. `_usage_gemini_merge_state <existing> <snapshot> <prev_totals> <session_id> <branch>` （新設）

累計スナップショットと前回累計（上記ファイルの内容。無ければ `{}`）を突き合わせ、差分を
`sinceLastPush` へ加算した新しい状態を返す。**前回累計を `existing` から読まない**（引数で受ける）。

**返り値の形**

```
{state: {branch, sessions, sinceLastPush, lastPostedAt?, agents?},
 needsReset: <true|false>,
 diffAllZero: <true|false>}
```

`state` は既存 `_usage_merge_state` と同じ形（`lastPostedAt` / `agents` があれば引き継ぐ。
既存キーの意味は変えない）。**`needsReset` / `diffAllZero` を `state` の中へ混ぜない**
（状態ファイルへ書かれる内容と、呼び出し元への制御情報を分けるため）。

**差分の取り方**

- 差分 = `snapshot - prev_totals` を**全指標について**取る（既存 `_usage_merge_state` の
  `[0, (cur - prev)] | max` を全指標へ拡張する）。
- **`diffAllZero`**: **クランプ前（raw）の差分**がすべて0のとき `true`。
- **`needsReset`**: raw差分に**1指標でも負値**があるとき `true`（セッションファイルの消失。決定S）。
  負値は0へクランプしてから加算するため、`sinceLastPush` は負にならない。
- 上の2つは**排他**である（負値があれば `diffAllZero` は `false`）。この排他性が、下記
  「4.」の早期リターンとリセットの取り違えを防ぐ。

**`needsReset` の消費者**（立てただけで誰も読まないフラグにしない）

| 誰が | 何をするか |
|---|---|
| `sync_usage_state`（下記4.） | **早期リターンせず、`gemini-totals/<sessionId>.json` を今回のスナップショットで必ず上書きする**（次の断面から計上し直せる状態にする） |
| `sync_usage_state` | 検知した旨を**stderrへ1行**出す（レポート本文へは出さない。読み手はレポートではなくhookの出力で気づく） |
| テストケース6 | 返り値の `needsReset` が `true` であること、`sinceLastPush` が負にならないことを検証する |

下ろす操作は無い（1回の呼び出しごとに計算し直す値であり、状態として持ち越さない）。

**`sinceLastPush` へのGemini固有の載せ方**

| キー | 扱い |
|---|---|
| `tokensByModel[<model>]` | 既存の `{input, output, cacheCreate, cacheRead}` に `thoughts` / `tool` を**追加**する。Geminiでは `cacheCreate` は常に0、`cached` は `cacheRead` へ入れる |
| `toolCalls[<name>]` | 既存キーをそのまま使う |
| `toolErrors[<name>]` | **新設**。Claude Code経路では書かれない（キー自体が現れない） |
| `models` | **新設**。`_usage_gemini_fold` が返す `models` の**和集合**を保持する（既存値との `unique`）。Claude Code経路では書かれない |
| `turns` / `activeSeconds` | 既存キーをそのまま使う |
| `skillCalls` / `agentCalls` / `askUserQuestions` | Gemini経路では**加算しない**（対応する概念が無い。空のまま） |

**`models` を捨てないこと。** レポート上の「使用モデル」はトークンテーブルのモデル列で代表される
が、その行は全項目0だとスキップされるため、**`tokens` が付かないリビジョンばかりのセッション
（決定Gが想定している状況）ではモデル名がレポートから完全に消える**。issue #97 の期待する動作2
（使用モデルを集計する）を満たすため、`sinceLastPush.models` を独立に持ち、レポートへ1行出す
（下記「5.」）。

- **既存の状態ファイル（Claude Code分）を読み書きしても壊れないこと**を、追加キーのみに
  留めることで担保する。

### 4. `sync_usage_state` への分岐追加

`engine = gemini` のときだけ別経路を通す。Claude Code経路の行は**1行も動かさない**
（差分を読んだときに「既存経路は変わっていない」と一目で分かる形にする）。

```
engine = claude → 現行のまま（行カーソル → _usage_aggregate_new_lines → _usage_merge_state → …）
engine = gemini → 下記
```

1. `_usage_sync_session_logs`（**既存のGemini分岐をそのまま使う**）でミラーし、`log_dir` を得る。
2. `_usage_gemini_fold "${log_dir}/main.jsonl"` で累計スナップショットを得る。
3. ブランチ別の状態ファイルを読む（**空文字列・不正JSONなら `{}` へフォールバックする既存の
   自己回復ロジックを同じ形で使う**）。
4. `usage/state/gemini-totals/<sessionId>.json` を読む（**同じ自己回復ロジックを適用する**。
   無ければ `{}`）。
5. `_usage_gemini_merge_state` を呼び、`{state, needsReset, diffAllZero}` を得る。
6. **書き込みの分岐**（下表）。
7. `_usage_read_cursor` / `_usage_write_cursor` は**呼ばない**（決定O）。
8. `_usage_aggregate_and_merge_subagents` は**呼ばない**（決定I）。

| 条件 | `gemini-totals/<sessionId>.json` | ブランチ別状態ファイル | 返り値 |
|---|---|---|---|
| `needsReset == true` | **必ず今回のスナップショットで上書きする** | 書く | 新しい状態 |
| `needsReset == false` かつ `diffAllZero == true` | 書かない（前回累計と同値のため） | **書かない**（早期リターン。決定O） | 既存状態をそのまま |
| 上記以外（通常の増分） | 今回のスナップショットで上書きする | 書く | 新しい状態 |

**早期リターンの条件を `needsReset` と混同しないこと。** セッションファイルが消失した直後は
**全指標の差分が負→クランプ後すべて0**になる。「クランプ後の差分が0か」で早期リターンを判定すると
この経路が引っかかり、前回累計が古い（大きい）値のまま残る。以後、新しいセッションの累計が旧累計を
超えるまで毎回「差分0・書き込みなし」が続き、**Gemini分の工数が無言で欠落し続ける**（決定Sが
狙った「次の断面から計上し直す」が成立しない）。判定に使うのは
**クランプ前（raw）の差分＝`diffAllZero`** であり、`needsReset` が立っている場合は
**早期リターンしない**。

**早期リターンの位置がClaude Code経路と違う点に注意する。** Claude Code経路は「新規行が無ければ
ミラーもスキップ」だが、Gemini経路は内容ベースでしか判定できないため**ミラー → 畳み込み →
差分判定**の順になる。ミラーは冪等な上書きコピーなので実害は無い。この差はコメントとして残す。

**`_usage_append_push_index` の扱いは実装時に決める**（下記「実装時に決めること」1）。

### 5. `post-push-usage-report.sh`

#### 5-a. レポート本文の組み立てを関数へ切り出す（テスト可能にするため）

現状、本文は `main` の中の `{ echo …; } > "$tmp_file"` という無名ブロックで組み立てられており、
**外から呼べないためレポート内容を検証するテストが1件も書けない**。次の2点を行う。

1. 本文組み立てを `build_usage_report_body <usage_json> <branch> <is_first_post> <subagent_usage>`
   （標準出力へ本文を書く）として切り出す。**中身は下記5-bの変更を除き、現行コードをそのまま移す。**
2. ファイル末尾の `( main ) || true` を
   `if [ "${BASH_SOURCE[0]}" = "${0}" ]; then ( main ) || true; fi` のガードで包む
   （`.claude/rules/shell-script-style.md`「テスト」節。現状は `source` した時点で `main` が走り、
   `raw="$(cat)"` でstdin待ちのままハングするためテストから読み込めない）。

**この切り出しは決定Kの「無改造」に反しない**（Kが対象にしているのは `UsageTracking.sh` の
Claude Code用集計関数である。上記「前提」の注記）。Claude Code経路の出力が1バイトも変わらない
ことは、テストケース13で担保する。

#### 5-b. 本文の変更点

| 箇所 | 変更 |
|---|---|
| トークンテーブルの列構成 | **engineではなくデータで決める**（下記「列構成をengineで決めない理由」）。全バケットが `thoughts`/`tool` を持たない → `Input / Output / Cache Write / Cache Read`（**現行のまま**）。全バケットが持つ → `Input / Output / Cache Read / Thoughts / Tool`（決定F）。**混在 → 両者の和集合** `Input / Output / Cache Write / Cache Read / Thoughts / Tool`（欠けている列は0） |
| モデル行のスキップ判定 | 「**そのバケットが持つ数値項目がすべて0なら表示しない**」へ一般化する。Claudeのバケットはキーがちょうど4つなので**現行式と同値**であり、出力は変わらない。現行の4項目固定のままだと、`thoughts` や `tool` だけが正の値を持つGeminiのモデル行が「全項目0」とみなされて消える |
| **モデル行が0件のとき** | **ヘッダ行・区切り行を含めてテーブルごと出力しない。** 現行はヘッダ2行を無条件に出しており、行が1つも残らないと**ヘッダだけの空テーブル**になる。issue #97 の受け入れ条件「トークン情報が取得できない場合に、空のトークンテーブルや0の羅列にならない」に抵触する |
| 使用モデル | `sinceLastPush.models` があり、かつ空でないとき `- 使用モデル: <カンマ区切り>` を「assistant応答回数」の次の行に出す。Claude Code経路では `models` キー自体が無いため出ない |
| ツールエラー | `toolErrors` があるとき、`**ツール実行回数**` の直後に `**ツールエラー回数**: <name>: <n>, …` を出す。**0のキーは表示しない**（既存の `toolCalls` と同じ扱い） |
| 投稿要否ガード | Gemini経路では「トークン合計・ツール実行回数・応答回数の**いずれか**が0より大きければ投稿」へ広げる。**Claude Code側の判定式は変更しない** |
| ブランチ帰属の注記 | Gemini経路のレポートに、「1つのセッション内でブランチを切り替えた場合、切り替え前の分もこのブランチへ計上される」旨を1行入れる（決定Eの限界の明示） |
| サブエージェント節 | Gemini経路では出さない（決定I。`agents` が空なので現行のロジックで自然に出ない見込みだが、確認する） |

**空テーブル抑止がClaude Code経路の出力を変えないこと**: Claude Code経路では投稿ガード
（トークン合計 > 0）を先に通るため、モデル行が0件になる状態では**そもそも投稿されない**。
したがってこの抑止がClaude Code経路で発火することはない。

**列構成をengineで決めない理由**: 状態ファイルはブランチ単位（`usage/state/<safeBranch>.json`）で、
`sinceLastPush` は**投稿に成功するまで繰り越される**（`gh`/`glab` 不在環境では投稿がスキップされ、
繰り越される経路が実在する。issue #34）。このリポジトリは `.gemini/` を `.claude/` へリンクして
両エンジンで使う前提なので、**同じブランチの `tokensByModel` にGemini由来のモデルとClaude由来の
モデルが同時に載りうる**。この状態で「今回のengine」だけで列を決めると、最後がClaude Codeなら
Gemini分の `thoughts`/`tool` が、最後がGeminiならClaude分の Cache Write が、いずれも**無言で
表から消える**。

### 6. テスト（`.claude/scripts/test/test_usage_tracking.sh`）

既存の型（`source` → 一時ディレクトリへフィクスチャ → 関数を直接呼ぶ → `assert_eq` →
`passed=N failures=N`）に合わせて追加する。

| # | ケース | 検証すること |
|---|---|---|
| 1 | 同じファイルを2回畳んで差分を取る | 差分がすべて0（**二重計上しない**ことの直接の裏付け＝受け入れ条件） |
| 2 | リビジョン再送（`tokens: null` → 値あり、`executing` → `success`） | 後勝ちマージでtokensが消えない・ツールが1回だけ数えられる |
| 3 | `$set.messages` による全メッセージ再送 | 二重計上しない |
| 4 | `$rewindTo` を含む | メッセージが削られない |
| 5 | 切り詰め（行数の減少） | 累計が一致し差分0 |
| 6 | セッションファイル消失（累計が減る） | `needsReset` が `true`・`diffAllZero` が `false`・`sinceLastPush` が負にならない |
| 7 | 空ファイル / 不正JSON行の混入 | 落ちない。不正行だけを捨てる |
| 8 | ツールの `status` | `error` のみエラー、`cancelled` は実行回数のみ、未完了はどちらにも入らない |
| 9 | `activeSeconds` | timestampが前後するフィクスチャで並べ直して算出される。**メッセージ1件のフィクスチャで `TAIL_BUFFER_SECONDS` になる**（末尾加算の担保） |
| 10 | `sync_usage_state` を `engine=gemini` で通す結合ケース | 状態ファイルと `gemini-totals/<sessionId>.json` が書かれ、2回目の呼び出しで早期リターンになる |
| 11 | **同一sessionIdでブランチを A → B へ切り替える** | Bの初回で**累計全量が再計上されない**（`sinceLastPush` がA分を含まない）。指摘1の回帰テスト |
| 12 | **消失検知の翌回** | 消失回に `gemini-totals` が新しい値へ**上書きされている**こと、続く呼び出しで新セッション分が正しく計上されること（早期リターンで止まらない）。指摘2の回帰テスト |
| 13 | **`build_usage_report_body` の出力**（`post-push-usage-report.sh` を `source` して呼ぶ） | (a) Claude形式のstateで**現行と同一の本文**が出る、(b) Gemini形式でThoughts/Tool列と `**ツールエラー回数**` 行と `- 使用モデル:` 行が出る、(c) 両者混在で**6列すべて**が出る、(d) `tokensByModel` が空／全項目0のときテーブルのヘッダごと出ない、(e) `thoughts` だけが正の行がスキップされない |

- **既存33ケースは1行も変更しない。**
- **ケース13の(a)が、「Claude Codeでのレポート内容が変化しない」ことの担保である。**
  既存33ケースは `UsageTracking.sh`（集計側）のテストであり、レポート本文は1ケースも通っていない。
  列構成の分岐を入れる以上、レポート側の担保はケース13で別途取る必要がある。
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
2. `def epoch_from_iso8601` を、`_usage_aggregate_transcript` から**共通のjqスニペットとして
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
- 受け入れ条件「Claude Codeでの既存の集計結果・レポート内容が変化しないこと」は、次の**2つ**で
  担保する。**既存33ケースだけでは足りない**（あれは `UsageTracking.sh` の集計側のテストであり、
  レポート本文を1ケースも通っていないため）。

  | 担保するもの | 担保する手段 |
  |---|---|
  | 既存の**集計結果**が変わらない | 手順2で既存33ケースが `failures=0` のまま（アサーションを1行も変更しない） |
  | 既存の**レポート内容**が変わらない | 新規テストケース13の(a)（Claude形式のstateで本文が現行と一致する） |

## 記録先

- 詳細な試行錯誤: `worklog/日付_partitioned-forging-seahorse_【実装】【テスト】Gemini CLIセッションログの集計を追加する_push<N>.md`
- 実施結果（正文）: `reports/日付_partitioned-forging-seahorse_Gemini集計の実装.md`（＋同名の `.html`）
