---
title: Geminiセッションログの調査結果（issue #97 フェーズ2）
type: report
description: Gemini CLIのJSONLセッションログを対応工数レポートへ取り込むための、形式・hookペイロード・既存経路・設計判断の調査結果
tags: [report, gemini-cli, usage-report, session-log]
keywords: [JSONL, chatRecordingTypes, toolCalls, tokens, rewindTo, 畳み込み, 二重計上, 累計差分, 切り詰め, CoreToolCallStatus]
---

# 調査結果: Gemini CLIのセッションログの形式（issue #97 フェーズ2）

- issue: [#97](https://github.com/yuki-matsu783/MR-driven-workflow/issues/97) / PR: [#101](https://github.com/yuki-matsu783/MR-driven-workflow/pull/101)
- 個別調査計画: `plans/【調査】Gemini CLIのセッションログの形式.md`（調査項目 A〜K・N〜S。L・M・Pは欠番）
- 実施: flow-id 2-6

## 参照した一次情報の版

| 項目 | 値 |
|---|---|
| 実体 | `参考ディレクトリ/gemini-cli`（Git管理外） |
| version | `0.56.0-nightly.20260806.g761f604c1`（`package.json`） |
| 取得時点 | 2026-08-20（決-4） |

以下、`gemini-cli/` からの相対パスで該当箇所を示す。**`参考ディレクトリ/` はGit管理外のため、
本レポートに事実を書き写している。**

---

## 1. 事実確認

### A. セッションログの形式 — 確定

| 項目 | 確定内容 | 根拠 |
|---|---|---|
| 保存先 | `~/.gemini/tmp/<project_hash>/chats/` | `docs/cli/session-management.md:18-22` |
| `project_hash` | **プロジェクトルートの絶対パスの sha256（hex）** | `packages/core/src/config/storage.ts:215` (`crypto.createHash('sha256').update(filePath).digest('hex')`) |
| ファイル名（メイン） | `session-<TIMESTAMP>-<sessionId先頭8文字>.jsonl`（`TIMESTAMP` は ISO文字列の先頭16文字の `:` を `-` へ置換） | `chatRecordingService.ts:499-519` |
| ファイル名（サブエージェント） | `<完全なsessionId>.jsonl`（接頭辞・タイムスタンプ無し）。`chats/<親sessionId>/` 配下 | `chatRecordingService.ts:484-495, 511-513` |
| 1行目 | メタデータ `{sessionId, projectHash, startTime, lastUpdated, kind, directories}` | `chatRecordingService.ts:530-539` |
| 2行目以降 | ①メッセージ ②`{"$set": Partial<ConversationRecord>}` ③`{"$rewindTo": "<messageId>"}` | `chatRecordingTypes.ts:123-129` |

**メッセージのキー項目**（`chatRecordingTypes.ts:41-83`）:

```
BaseMessageRecord: id, timestamp, content, displayContent?
type: 'user' | 'info' | 'error' | 'warning'   … 追加フィールド無し
type: 'gemini'                                 … toolCalls?, thoughts?, tokens?, model?
ToolCallRecord: id, name, args, result?, status, timestamp, agentId?
                （＋UI用 displayName?, description?, resultDisplay?, renderOutputAsMarkdown?）
TokensSummary:  input, output, cached, thoughts?, tool?, total
```

#### A-1. `toolCalls[].status` の値集合 — **参考にしたRustパーサの想定と違っていた**

`status` の型は `Status = ToolCall['status']`（`scheduler/types.ts:187`）で、実体は
`CoreToolCallStatus` enum（`scheduler/types.ts:26-34`）である。

| 実際の値（確定） | Rustパーサが想定していた値 |
|---|---|
| `validating` / `scheduled` / `executing` / `awaiting_approval` / `success` / `error` / `cancelled` | `success` / `error`\|`failed` / `pending`\|`running` |

- **`failed` `pending` `running` は存在しない。** これらで判定を書くと、該当ケースが常に外れる。
- **`cancelled` が存在する**（Rustパーサの想定に無い）。ユーザーが承認を拒否した・中断した
  ツール呼び出しがこれに当たる。
- `status` は必須フィールド（`ToolCallRecord.status: Status`）であり、欠落を前提にした
  フォールバック（`result` が空なら pending とみなす）は**不要**。

**設計への反映**: Hの判定は `error` のみをエラーとして数え、`cancelled` は「実行されなかったもの」
として**エラーに含めない**。未完了（`validating`/`scheduled`/`executing`/`awaiting_approval`）も
計上しない。

#### A-2. ファイルが再書き出し・パス変更されうる経路 — 2つある

| 経路 | いつ走るか | ファイルへの影響 | 根拠 |
|---|---|---|---|
| **レガシー移行** | `.json` セッションをresumeしたとき | `conversationFile` が `<同名>.json` → `<同名>.jsonl` へ切り替わり、メタデータ＋全 `messages` を新ファイルへ**追記し直す**。**元の `.json` は削除されない** | `chatRecordingService.ts:436-459` |
| **`rewriteConversationFile`** | resume時に `loadConversationRecord` が **null を返した**とき（ファイル欠損・メタデータ破損・I/Oエラー）だけ | 一時ファイル + `rename` でファイル全体を置換。**同一idのリビジョンが1行へ畳まれるため行数が減る**。既存ファイルは `<file>.unreadable-<ts>` へ退避される | `chatRecordingService.ts:464-474, 580-640` |

- **`rewriteConversationFile` は例外経路であり、通常運転では走らない。** 呼び出し元は1箇所のみ。
- **書き直しでメッセージが欠落することはない。** resume経路の `loadConversationRecord` は
  `options` 無しで呼ばれており（`chatRecordingService.ts:429`）、`maxMessages` による
  切り詰め（`chatRecordingService.ts:236-237`）は適用されない。`maxMessages` を渡すのは
  一覧表示（`sessionUtils.ts:256`）・メモリ抽出（`memoryService.ts:606`）・
  サマリ生成（`sessionSummaryUtils.ts:380`）だけで、いずれも記録側ではない。
- **副産物のファイルが同じディレクトリに残る**: `<file>.unreadable-<ts>` と、rename失敗時の
  `<file>.tmp-<pid>`。ディレクトリをグロブする実装は、これらを拾わないよう
  `session-*.jsonl` で絞る必要がある。

### B. hookペイロード — 確定（**実機不要で確定できた**）

`HookInput` の共通フィールド（`docs/hooks/reference.md:48-58`, `packages/core/src/hooks/types.ts:143`）:

```
session_id, transcript_path, cwd, hook_event_name, timestamp
```

組み立ては `hookEventHandler.ts:371-385`:

```typescript
const transcriptPath =
  this.context.geminiClient?.getChatRecordingService()?.getConversationFilePath() ?? '';
return {
  session_id: this.context.config.getSessionId(),
  transcript_path: transcriptPath,
  cwd: this.context.config.getWorkingDir(),
  ...
};
```

| 問い | 答え |
|---|---|
| `transcript_path` は渡されるか | **渡される** |
| それは `chats/session-*.jsonl` を指すか | **指す**（`ChatRecordingService.getConversationFilePath()` そのもの＝実ファイルのフルパス） |
| `session_id` は渡されるか | **渡される** |
| グロブ照合の代替探索は要るか | **不要** |

- **ただし `?? ''` により空文字列になりうる**（`ChatRecordingService` 未初期化時）。既存
  `post-push-usage-report.sh` は `[ -n "$session_id" ] && [ -n "$transcript_path" ]` で
  ガードしており、この場合は状態同期がスキップされるだけで害はない。
- `AfterTool` は追加で `tool_name` / `tool_input` / `tool_response` を持つ
  （`docs/hooks/reference.md:118-122`）。既存hookの `tool_input.command` 参照はそのまま成立する。
- **`cwd` も渡される。** ただし対応工数レポートは既に hook 内で `git branch --show-current` を
  使っており、ブランチ判定に `cwd` は要らない（下記E参照）。

---

## 2. 既存経路（K・N）

### K. engine分岐が要る関数

`.claude/hooks/lib/UsageTracking.sh` の13関数のうち、Gemini対応で触る必要があるものは次のとおり。

| 関数 | Gemini対応 | 理由 |
|---|---|---|
| `sync_usage_state` | **分岐を追加** | engineで集計経路を振り分ける唯一の場所にする |
| `_usage_aggregate_new_lines` | **触らない** | Claude Code専用。行カーソル方式はGeminiに使わない（下記O） |
| `_usage_aggregate_transcript` | **触らない** | 同上（`activeSeconds` 専用の全件再パース） |
| `_usage_merge_state` | **触らない** | tokens/toolsを「delta」として受け取る前提。Geminiは累計差分（下記C）なので別関数にする |
| `_usage_read_cursor` / `_usage_write_cursor` | **触らない**（Geminiでは使わない） | 行数カーソルはGeminiの差分計算に使わない |
| `_usage_sync_session_logs` | **既に分岐済み**（`engine = gemini`） | ミラー保存はそのまま流用できる |
| `_usage_append_push_index` | 流用可（値の意味に注意） | 下記O |
| `_usage_aggregate_and_merge_subagents` | **触らない** | glob が `subagents/agent-*.jsonl` でGeminiのディレクトリにマッチしない（下記I） |
| `_usage_reset_since_last_push` / `_usage_filter_nonzero_subagents` / `_usage_safe_branch_name` | **触らない** | engine非依存 |

**新設する関数は2つで足りる**（いずれもGemini専用）。

1. `_usage_gemini_fold` — セッションJSONLをid単位で畳み、**累計スナップショット**を返す
2. `_usage_gemini_merge_state` — 累計スナップショットと状態ファイルの前回累計を突き合わせ、
   差分を `sinceLastPush` へ加算した新しい状態を返す

**Claude Code側の関数を1つも変更しないため、「既存の集計結果が変わらない」ことが構造で担保される**
（受け入れ条件「Claude Codeでの既存の集計結果・レポート内容が変化せず」）。

### N. 既存テストの型

`.claude/scripts/test/test_usage_tracking.sh`（233行）は、`source` でライブラリを読み込み、
一時ディレクトリへフィクスチャを書いて関数を直接呼び、`assert_eq` で検証したうえで
`passed=N failures=N` を出力し、失敗時に終了コード1を返す。Gemini用ケースも同じ形で追加できる。

**追加すべきケース**（本レポートの検証1〜5に対応）: リビジョン再送 / `$set` スナップショット /
`$rewindTo` / 切り詰め / ファイル消失 / 空ファイル / 不正JSON行の混入。

---

## 3. 設計判断

### C. 差分の取り方 — **(a) 全体をid単位で畳んで、前回累計との差分を取る**を採用

| 案 | 判断 | 理由 |
|---|---|---|
| **(a) 毎回ファイル全体を畳んで累計を作り、状態が持つ前回累計との差分を取る** | **採用** | 下記のとおり、リビジョン再送・`$set`・`$rewindTo`・**行数の減少**のすべてに対して正しく振る舞うことを実測で確認した。既存 `activeSeconds` が同じパターンを採っており、コードベースとも一貫する |
| (b) 計上済みidの集合を状態ファイルへ持つ | 却下 | idの集合はセッションが伸びるほど無制限に膨らむ。状態ファイルが肥大化し、`jq --argjson` の引数長上限（`.claude/rules/shell-script-style.md`）に近づく。加えて「同一idの後続リビジョンでtokensが後埋めされる」ため、id単位の済/未だけでは後埋め分を取りこぼす |
| (c) 行カーソル（Claude Code式） | 却下 | **二重計上する**（同一idが複数行に現れる・`$set` が全メッセージを再送する）。加えて行数が減る経路がある（A-2） |

**(a) の計算コストは、ファイルが伸びるほど毎回の再パースが重くなる**という欠点を持つが、
Claude Code側の `_usage_aggregate_transcript`（`activeSeconds` のために毎回全件再パースする）が
既に同じコストを払っており、新たに悪化させるものではない。

### O. 行カーソル / `push-index.jsonl` の扱い — **差分計算には使わない**

| 用途 | Gemini経路での扱い |
|---|---|
| 差分計算 | **使わない**（Cの(a)が内容ベースで差分を取るため不要） |
| 「新規行なし＝早期リターン」の判定 | **使わない。** 行数は減りうる（A-2）ため `totalLines <= lastLineCount` が誤発火する。代わりに**畳み込み後の差分がすべて0なら早期リターン**する |
| `push-index.jsonl` への push断面の記録 | **記録してよいが、意味が変わる**。Claude Code側の `from`/`to` は「そのpushで新たに記録された行範囲」だが、Geminiでは行番号が内容と1対1に対応しないため、**そのpush時点の総行数のスナップショット**という意味になる。混同を避けるため、Gemini分は行範囲ではなく畳み込み後のメッセージ数を記録するか、記録自体を見送るかを実装時に決める |

### S. 消失・切り詰め時の挙動 — **切り詰めは対応不要と判明。消失のみ検知してリセット**

**実測（検証3）**: `rewriteConversationFile` 相当の書き直し（10行 → 6行）を行っても、
**畳み込み後の累計は完全に一致した**。

```
before: {"turns":4,"activeSeconds":310,"toolCalls":{"read_file":1,"run_shell_command":1,"write_file":1}}
after : {"turns":4,"activeSeconds":310,"toolCalls":{"read_file":1,"run_shell_command":1,"write_file":1}}
差分  : {"needsReset":false,"raw":{"turns":0,"activeSeconds":0}}
```

- **決-3（切り詰めは機械的に対応可能であれば対応する）への回答: 対応は不要である。**
  Cの(a)は行番号ではなく内容を基準にするため、書き直しによる行数の減少が集計へ影響しない。
  「対応しない」のではなく「**アプローチの選択によって問題自体が消えている**」。
- **消失は検知できる（検証4）**: セッションファイルが失われて新しいセッションが始まると、
  累計が前回累計を下回る。差分に**負値が1つでも出たら消失とみなし**、`needsReset` を立てる。

```
{"needsReset":true,"raw":{"turns":-3,"activeSeconds":-280},"clamped":{"turns":0}}
```

- 決-2 に従い、**検知した時点で前回累計をリセット**し、次のpush断面から計上し直す。
  負値は0へクランプしてから加算するため、`sinceLastPush` が負になることはない。
- **この検知が無いと、静かに欠落する。** 既存 `_usage_merge_state` の `[0, (cur - prev)] | max`
  は負値を黙って0にするだけで、リセットを行わない。Gemini側では `needsReset` を明示的に見る。

### D. `$rewindTo` の扱い — **集計から外さない**

- 理由: `/rewind` は会話の見え方を巻き戻すだけで、**それまでのAPI呼び出しの課金とツール実行は
  既に起きている**。対応工数レポートは「どれだけ手間がかかったか」を表すものなので、
  巻き戻した分も含めるのが目的に合う。
- 実装: `$rewindTo` レコードは読み飛ばす（メッセージを削らない）。
- **却下案**: CLI本体の会話再構成（`chatRecordingService.ts:176`）に合わせて切り詰める。
  会話の再現には正しいが、工数の実態を過小評価する。

### E. ブランチ帰属 — **hook実行時点のブランチに帰属させる。限界を明示する**

- **セッションログにブランチ情報は無い。** Claude Codeの `.gitBranch` に相当するフィールドは
  メッセージにもメタデータにも存在しない。
- **1行目の `directories` は使えない。** 型定義のコメントは
  `Workspace directories added during the session via /dir add`（`chatRecordingTypes.ts:97`）で、
  **cwdではなく `/dir add` で追加されたワークスペースディレクトリ**である。
  （全体作業計画の flow-id 1-4 時点では「セッション単位でプロジェクトのディレクトリが分かる
  可能性がある」と書いたが、**この見込みは外れた**。）
- `projectHash` はプロジェクトルートのsha256（storage.ts:215）なので、逆算はできないが
  「候補パスをハッシュして一致を見る」ことはできる。ただし**プロジェクト単位までしか分からず、
  ブランチは分からない**。
- **採用する方針**: 既存hookと同じく、push時点の `git branch --show-current` をブランチとし、
  **「前回pushからの差分を、そのpush時点のブランチの作業として扱う」**。
- **限界（明示する）**: 1つのGeminiセッションの中でブランチを切り替えて作業した場合、
  切り替え前の分も切り替え後のブランチへ計上される。Claude Code側はエントリ単位の
  `gitBranch` で正確に振り分けられるため、**同じレポートでもエンジンによって精度が違う**。

### F. トークン列の対応づけ — Gemini専用の列構成にする

| Geminiの `TokensSummary` | 既存テーブルの列 | 判断 |
|---|---|---|
| `input` | Input | そのまま |
| `output` | Output | そのまま |
| `cached` | Cache Read | `cachedContentTokenCount` の意味（型定義のコメント）と一致する |
| （該当なし） | Cache Write | **相当する値が無い。** 列自体を出さない |
| `thoughts?` | — | **新しい列 Thoughts として出す**（Claude Codeには無い指標） |
| `tool?` | — | **新しい列 Tool として出す**（同上） |
| `total` | — | 計上しない（内訳の合計であり、足すと二重計上になる） |

- **エンジンごとにテーブルの列構成を変える。** 共通の4列へ無理に押し込むと、Cache Write が
  常に0で埋まり、`thoughts`/`tool` が捨てられる。issueの受け入れ条件「0の羅列にしない」に反する。
- **リビジョンで `tokens` が `null` になる場合、先行リビジョンの値を消してはいけない。**
  実測（検証1のフィクスチャ m1）で、`tokens: null` の版が先に来て後から値の入った版が来る
  パターンを確認済み。畳み込みでは「新しい版の `tokens` が null なら前の版の値を引き継ぐ」。

### Q. 稼働時間の算出方式

- **畳み込み後のメッセージを `timestamp` で昇順に並べ直してから**、隣接するgapを積む。
  ファイル出現順のまま積むと、リビジョン再送・`$set` により時刻が前後して負のgapが多発する。
- `IDLE_GAP_THRESHOLD_SECONDS`（既定300）・`TAIL_BUFFER_SECONDS`（既定30）は**そのまま流用する**
  （issueの期待する動作2の指定どおり）。gapが閾値以上なら `TAIL_BUFFER_SECONDS` を積む。
- 負のgapは捨てる（既存 `_usage_aggregate_transcript` と同じ）。並べ替えにより実際にはほぼ生じない。
- `$rewindTo` の区間も**そのまま含める**（Dの判断と一貫させる）。
- **単調非減少性は保たれる。** 畳み込みはメッセージを減らさないため、累計 `activeSeconds` は
  push を重ねるごとに増えるだけである（消失時を除き、それはSで検知する）。

### R. 応答回数・使用モデルの定義

- **応答回数 = 畳み込み後の `type == "gemini"` のメッセージ数**（＝ユニークな id の数）。
  行数で数えるとリビジョン再送の分だけ水増しされる。実測（検証1）でも、8行のファイルから
  `turns: 3` が得られている（m1が3回・m2が2回現れる）。
- **使用モデル = 畳み込み後のメッセージの `model` の集合**。トークンテーブルのキーとしても使う。
  `model` を持たないメッセージは `unknown` に寄せる（Claude Code側と同じ扱い）。

### H. ツールエラーの計上方法

- **`status == "error"` のみをエラーとして数える**（A-1で確定した値集合に基づく）。
- **`cancelled` はエラーに含めない**（ユーザーが止めたものであり、失敗ではない）。
  ただしツール実行回数には含める（呼び出しは発生している）。
- 未完了（`validating` / `scheduled` / `executing` / `awaiting_approval`）は**どちらにも計上しない**。
  畳み込みで最新リビジョンが採られるため、完了済みの版があればそちらが残る（検証1で確認）。
- エラーは**ツール名ごとに数える**（どのツールで詰まったかが分かるようにする）。

### G. 投稿要否のガード

- 現行は「`tokensByModel` の合計が0なら投稿しない」。**Geminiでもトークンは取れるため、
  この判定はそのまま使える。**
- ただし**トークンだけを見る形は残さない**。テレメトリ無効時など `tokens` が付かない
  リビジョンばかりのセッションがありうるため、**トークン合計・ツール実行回数・応答回数の
  いずれかが0より大きければ投稿する**へ広げる。Claude Code側の判定式は変更せず、
  Gemini経路の判定として追加する。

### I. サブエージェントの扱い — **今回は保存のみに留める**

- 本体はサブエージェントを `chats/<親sessionId>/<完全なsessionId>.jsonl` へネストする
  （`chatRecordingService.ts:484-495, 511-513`）。既存 `_usage_sync_session_logs` の
  Gemini分岐（`$(dirname "$transcript_path")/<session_id>/` をディレクトリごとコピー）と**一致する**。
- `ToolCallRecord.agentId?` があるため、親側のツール呼び出しからサブエージェントを辿ることもできる。
- **今回は集計対象に含めない。** 理由:
  1. issueの受け入れ条件はメイン分の集計を求めており、サブエージェント分は必須ではない。
  2. 親と子で同じツール実行が二重に現れないかを確かめる材料が無い（実機が無い）。
  3. Claude Code側の `_usage_aggregate_and_merge_subagents` は `subagents/agent-*.jsonl` を
     globしており、Geminiのディレクトリ構造にマッチしない。**この非対称を今回は保ったままにする**。
- **spec の既存の懸念は解消できる**: 「Gemini CLIのサブエージェントは親と同じセッションIDで
  動作するのではないか」という未検証の懸念（`.claude/docs/spec/issue-mr-workflow.md`
  「未決定事項・懸念点」）は、**サブエージェントが自分の `sessionId` をファイル名に持つ**
  （`chatRecordingService.ts:511-513`）ことから否定される。

---

## 4. 検証（合成フィクスチャ＋jqプロトタイプ）

実機（Gemini CLI）が無いため、**一次情報どおりの合成JSONLを作り、jqのプロトタイプで
結論を実際に確かめた**。プロトタイプはフェーズ3のフィクスチャの原型になる。

フィクスチャ（8行）に含めたもの: 1行目メタデータ / 同一idのリビジョン再送（`tokens: null` →
値あり、`executing` → `success`）/ userメッセージ / `error` と `cancelled` のツール /
`$set.messages` による全メッセージ再送 / `$rewindTo` / 別モデルのメッセージ。

| # | 検証 | 期待 | 結果 |
|---|---|---|---|
| 1 | 同じファイルを2回畳んだ差分 | すべて0 | **0**（`needsReset: false`） |
| 2 | 追記（m2のリビジョン再送＋新規m4）後の差分 | 新規分のみ | **`turns:+1`, `activeSeconds:+60`, ツール実行回数は±0, flashのtokensのみ+7/+3** |
| 3 | 切り詰め（10行→6行の書き直し）後の差分 | 累計が一致し差分0 | **累計完全一致・差分0・`needsReset: false`** |
| 4 | セッションファイル消失後の差分 | 負値を検知 | **`needsReset: true`（`turns:-3`, `activeSeconds:-280`）。クランプ後は0** |
| 5 | 空ファイル / 不正JSON行の混入 | 落ちない | 空: `{totalLines:0, turns:0}` / 不正行混入: 不正行のみ捨てて `turns:4` |

**検証1・2が「同じ範囲を二重計上しない」という受け入れ条件の直接の裏付けである。**
フィクスチャでは m1 が3回・m2 が2回現れるが、いずれも1回だけ計上された
（`toolCalls: {read_file:1, run_shell_command:1, write_file:1}`）。

### 既存の状態を壊していないことの確認

```
$ bash .claude/scripts/test/test_usage_tracking.sh   → passed=33 failures=0
$ bash -n .claude/hooks/lib/UsageTracking.sh          → 構文エラーなし
```

（このフェーズでは実装を変更していないため、この2つは「下限の確認」である。調査の結論そのものの
検証は上表の検証1〜5が担う。）

---

## 5. 確かめられなかったこと（未検証）

| 項目 | 状態 | 確定させる方法 |
|---|---|---|
| Gemini CLI実機でのエンドツーエンド動作 | **未検証**。この開発機に `~/.gemini` が存在しない | Gemini CLIをインストールし、featureブランチ上で実際にリモートへ反映してレポートが投稿されることを確認する |
| hookが実際にこのペイロードで発火するか | **未検証**（型定義・組み立てコードでは確定。実行時の値は未確認） | 同上。`AfterTool` hookで受け取ったJSONをそのまま保存して突き合わせる |
| `$set.messages` が実際に出る条件 | **未検証**。型と読み込み側（`chatRecordingService.ts:251-260`）の存在は確認したが、書き出し側で `messages` を含む `$set` を出す箇所は特定できていない（`updateMetadata` 経由の `$set` はメタデータ更新が主） | 実データで確認する。なお**出ても出なくても畳み込みは正しく動く**（検証1で確認済み）ため、設計上のリスクは無い |
| 別バージョンでの形式の安定性 | **未検証**。`0.56.0-nightly` の1点のみで確認 | 形式変更に備え、パースに失敗しても集計が0になるだけで壊れないこと（検証5）を保証しておく |

**issue #97 の受け入れ条件「実機（Gemini CLI）での検証ができない範囲は『未検証』として明示し、
spec の『未決定事項・懸念点』へ記録する」に対応する内容が本節である。** フェーズ4でspecへ反映する。

---

## 6. 調査項目ごとの結論一覧

| # | 項目 | 結論 |
|---|---|---|
| A | 形式の裏取り | 確定。`status` の値集合が参考実装の想定と違っていた（A-1）。再書き出し経路は2つあり、いずれもメッセージを失わない（A-2） |
| B | hookペイロード | 確定。`transcript_path` は実ファイルのフルパス。代替探索は不要 |
| C | 差分の取り方 | **(a) 全体をid単位で畳んで前回累計との差分**を採用 |
| D | `$rewindTo` | 集計から**外さない** |
| E | ブランチ帰属 | push時点の `git branch --show-current`。**`directories` は使えない**。限界を明示する |
| F | トークン列 | Gemini専用の列構成（Cache Write を出さず、Thoughts・Tool を出す） |
| G | 投稿要否ガード | トークン・ツール実行回数・応答回数のいずれかが0より大きければ投稿 |
| H | ツールエラー | `error` のみ。`cancelled` は実行回数に含めるがエラーにしない |
| I | サブエージェント | **今回は保存のみ**（集計に含めない）。specの既存の懸念は解消できる |
| K | 既存経路の分岐点 | `sync_usage_state` に分岐を1つ足し、Gemini専用関数を2つ新設。**Claude Code側は無改造** |
| N | 既存テストの型 | `source` + 一時ディレクトリ + `assert_eq` + `passed=N failures=N`。同じ形で追加できる |
| O | 行カーソル / push-index | 差分計算には**使わない**。早期リターンは畳み込み後の差分が0かで判定する |
| Q | 稼働時間 | **timestampで並べ直してから**gapを積む。閾値定数は流用 |
| R | 応答回数・使用モデル | 畳み込み後のユニークid数 / `model` の集合 |
| S | 消失・切り詰め | **切り詰めは対応不要**（(a)が本質的に耐性を持つ）。消失は負値で検知しリセット |

## 7. フェーズ3への申し送り

- 新設する関数は `_usage_gemini_fold` と `_usage_gemini_merge_state` の2つ。**既存関数は
  `sync_usage_state` の分岐追加以外は触らない。**
- `_usage_gemini_merge_state` は、既存 `_usage_merge_state` の `[0, (cur - prev)] | max` パターンを
  **全指標へ拡張**しつつ、負値が出たことを `needsReset` として上位へ返す点が異なる。
- レポート組み立て（`post-push-usage-report.sh`）は、**エンジンごとにトークンテーブルの列構成を
  切り替える**必要がある。
- ディレクトリをグロブする実装を入れる場合は `session-*.jsonl` で絞り、
  `*.unreadable-*` `*.tmp-*` を拾わないこと。
- DDRに残すべき判断: C（差分の取り方）・D（`$rewindTo`）・E（ブランチ帰属と限界）・
  F（トークン列）・I（サブエージェントの非対称）・S（切り詰めが問題にならない理由）。
