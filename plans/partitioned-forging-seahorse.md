---
title: 対応工数レポートのGemini CLIセッションログ対応（issue #97）全体作業計画
type: plan
description: Gemini CLIのJSONLセッションログを対応工数レポートの集計対象に加えるための、調査〜実装〜反映までの全体作業計画
tags: [usage-report, gemini-cli, hooks, workflow]
keywords: [対応工数レポート, Gemini CLI, UsageTracking, JSONL, toolCalls, カーソル, 二重計上, ブランチ帰属, トークン, rewind, DDR]
---

# 全体作業計画: 対応工数レポートをGemini CLIのセッションログにも対応させる（issue #97）

- issue: [#97](https://github.com/yuki-matsu783/MR-driven-workflow/issues/97)
- ブランチ: `feature-97-support-gemini-cli-usage-report`
- PR: [#101](https://github.com/yuki-matsu783/MR-driven-workflow/pull/101)（Draft）
- ベースブランチ: `main`

## Context（なぜこの変更を行うか）

Gemini CLIで作業しても、対応工数レポートがMR/PRへ一切投稿されない。

issue #7 でhook側のエンジン判定（`tool_name` → gemini/claude）は済んでおり、issue #23 で
Geminiのセッションログは `usage/session-logs/<sessionId>/subagents/<session_id>/` へミラー
保存されるようになった。しかし**集計側（`.claude/hooks/lib/UsageTracking.sh`）はClaude Codeの
transcript JSONL専用**である。結果として集計値はすべて0になり、
[post-push-usage-report.sh](.claude/hooks/post-push-usage-report.sh) の「合計が0なら投稿しない」
ガードで投稿自体がスキップされる。仕様にも「Gemini CLIはミラーへの保存のみ対応し、対応工数の
集計対象には含めない」と明記されている（[.claude/docs/spec/issue-mr-workflow.md:839](.claude/docs/spec/issue-mr-workflow.md#L839)）。

**この変更で目指す結果**: Gemini CLIで作業したときも、ツール実行回数・ツールエラー回数・応答回数・
使用モデル・稼働時間・トークンを集計した対応工数レポートがMR/PRへ投稿される。Claude Code側の
集計結果・レポート内容は一切変えない。

## 着手時点で判明した、issue本文の前提のズレ

**issue #97 の本文は、参考実装 `参考ディレクトリ/gemini-insights`（旧形式パーサ）を根拠に
「単一のJSONオブジェクト」「トークン相当フィールドは無い」と書いているが、これは Gemini CLI の
旧形式に基づく記述である。** ユーザーによるウェブ調査・[cc-switch#2347](https://github.com/farion1231/cc-switch/issues/2347)・
提示された現行形式パーサ実装（Rust）により、次が判明した。

Gemini CLI **v0.39.0**（google-gemini/gemini-cli PR #23749）で、チャットセッションの記録が
**単一JSONの全書き換え → 追記型JSON Lines** へ移行した。

| 項目 | 内容 | 出典（gemini-cli） |
|---|---|---|
| 保存先 | `~/.gemini/tmp/<project_hash>/chats/`（`project_hash` はプロジェクトルートパスから算出） | `docs/cli/session-management.md` |
| ファイル名（メイン） | **`session-<TIMESTAMP>-<sessionIdの先頭8文字>.jsonl`**（`TIMESTAMP` は ISO文字列の先頭16文字の `:` を `-` へ置換したもの） | `chatRecordingService.ts:499-519` |
| ファイル名（サブエージェント） | **`<完全なsessionId>.jsonl`**（`session-` 接頭辞もタイムスタンプも付かない）。`chats/<親sessionId>/` 配下へネストされる | `chatRecordingService.ts:484-495, 499-519` |
| 1行目のメタデータ | `{sessionId, projectHash, startTime, lastUpdated, kind, directories}` | `chatRecordingService.ts:530-539` |
| 新旧両対応 | 読み込み処理が `.json` / `.jsonl` の**両形式をサポート**（レガシーの `.json` は pretty-printed） | `sessionUtils.ts` |
| 保持期間 | `sessionRetention` 設定を超えた古いセッションは自動削除される | `sessionCleanup` |

- **ファイル名に含まれるのは `sessionId` の先頭8文字だけ**である。hookが渡す `session_id`
  （完全なUUID想定）とファイル名は**完全一致しない**ため、ファイルを自力で探す経路が必要に
  なった場合はグロブ照合が要る。
- **サブエージェントのネスト構造は、既存 `_usage_sync_session_logs` の Gemini 分岐
  （`$(dirname "$transcript_path")/<session_id>/` をディレクトリごとコピー）と一致する。**
  issue #23 時点の未検証の想定が、本体実装側から裏付けられた。あわせて spec
  「未決定事項・懸念点」に残っている「サブエージェントが親と同じセッションIDで動作するのでは
  ないか」という懸念も、**サブエージェントは自分の `sessionId` をファイル名に持つ**ことから
  解消できる見込みである。
- **1行目のメタデータに `directories` がある。** Rustパーサのコメントは「Gemini CLI は `cwd` を
  記録しない」としていたが、メッセージ単位ではなく**セッション単位**でならプロジェクトの
  ディレクトリが分かる可能性がある。ブランチ帰属の判断材料としてフェーズ2で確認する。
- **`sessionRetention` による自動削除がある**ため、集計対象のセッションファイルが後から消える
  ことがありうる（ミラー済みのログは残るが、再集計はできなくなる）。

### 新旧の差分は「入れ物」と「制御レコード」だけで、メッセージ1件のキー項目は同一

| | 旧 `.json`（`ConversationRecord`） | 新 `.jsonl` |
|---|---|---|
| 全体 | `{sessionId, projectHash, startTime, lastUpdated, messages[], summary?, memoryScratchpad?, directories?, kind?}` | **1行目**が同じ構造から `messages` を除いたもの（`startTime`/`lastUpdated` は必須→任意）、**2行目以降**がレコード |
| レコード種別 | なし（配列1本） | ①メッセージ本体 ②`{"$set": {...}}`（メタデータの部分更新） ③`{"$rewindTo": "<messageId>"}`（`/rewind` の記録） |
| 同一メッセージ | 書き出し時にマージ済みで1件1エントリ | **同じ `id` が複数行現れる**（トークンの後埋め・ツールの `status` 遷移）。id をキーに後勝ちマージが要る |
| `/rewind` | 配列を切り詰めて保存（**ファイル上に痕跡が残らない**） | `$rewindTo` レコードとして残る |

**メッセージのキー項目は新旧で変更なし**（`MessageRecord`: `id` / `timestamp` / `content` /
`displayContent?`。`type: 'user' \| 'info' \| 'error' \| 'warning'` は追加フィールド無し、
`type: 'gemini'` のときだけ `toolCalls?` / `thoughts?` / `tokens?` / `model?` が付く）。
`ToolCallRecord` は `id, name, args, result?, status, timestamp, agentId?` ＋UI用の
`displayName?, description?, resultDisplay?, renderOutputAsMarkdown?`。
`tokens` は `input / output / cached / thoughts? / tool? / total`。
（フィールド一覧の出典は現行 main の `packages/core/src/services/chatRecordingTypes.ts`。
**この周辺は変更が速いため、バージョンを固定して実ファイルで突き合わせる**こと。）

### この差分がissueの受け入れ条件へ与える影響

- **「トークン数はレポートから省略する」（期待する動作3）は前提が変わる。** `tokens` が実在する
  ため、issue本文の但し書き「取得できるフィールドが実在すれば計上する」に従い計上する方向で検討する。
  **issue #97 の本文自体は修正しない**（flow-id 2-4 でユーザーが決定。個別調査計画の 決-6）。
  前提が覆っている事実はこの節とMRの記録コメントに残す。
- **`ToolCallRecord.agentId?` が存在する**ため、サブエージェント分の帰属（期待する動作6）は
  ディレクトリ構造ではなくこのフィールドで判定できる可能性がある。
- **旧 `.json` 形式は Gemini CLI 本体側にフォールバックが残っている**（アップグレードしても履歴は
  失われない）。したがって手元に両形式が混在しうる。当初は「拡張子でディスパッチして両対応」を
  検討したが、**flow-id 2-4 で「新形式のみを扱う」と決定した**（個別調査計画の 決-1）。
  `参考ディレクトリ/gemini-insights` は、メッセージ1件のキー項目が新旧で同一のため、
  実装リファレンスとしては引き続き有効。
- **ブランチ帰属は取れない**（`gitBranch` に相当するものが無く、Gemini CLI は `cwd` をログへ
  記録しない）。期待する動作5の裏付け。

### 混同しやすい別系統（対象外）

| パス／機能 | 実体 | 本issueでの扱い |
|---|---|---|
| `~/.gemini/tmp/<hash>/logs.json` | プロセスレベルのユーザー入力ログ。今も `.json` で `chats/` とは別系統（セッションIDがズレる既知の不具合あり） | **対象外** |
| `gemini -p --output-format stream-json` | ヘッドレス実行時の標準出力のイベントストリーム。JSONLだが**スキーマが別物** | **対象外** |

## スコープから外した要件: Gemini CLIのテレメトリのローカル出力・push毎集計

**このMRでは扱わない**（flow-id 2-4・レビュー1周目でユーザーが決定）。**別issueとして
[#105](https://github.com/yuki-matsu783/MR-driven-workflow/issues/105) を起票済み。**

経緯: issue #97 の本文には無いこの要件を、着手時のチャットで追加で受けて一度スコープへ入れたが、
レビュー1周目で「テレメトリのスコープ追加はこのMRには含めない」「別issueで起票」との判断を受け、
本MRから外して #105 へ切り出した。判断はMRへ記録済み。

なお、Claude Code側の同種の機構は
[#103](https://github.com/yuki-matsu783/MR-driven-workflow/issues/103)（OTLP/HTTPを受ける
ローカルの常駐リスナー）が扱っており、#105 は**出力先の配置・機微情報の扱い・ローテーション
方針を #103 と揃える**ことを受け入れ条件に持つ。

以下は**調査済みの事実として残す**（#105 の作業でそのまま使えるため）。**本MRの
フェーズ2〜4では扱わない。**

Gemini CLI には、セッションログ（`chats/*.jsonl`）とは**別系統**の OpenTelemetry ベースの
テレメトリがあり、これを**ローカルファイルへ出力させて `usage/` 配下で管理し、push毎に集計して
対応工数レポートへ加える**、という要件だった。

| 項目 | 内容 |
|---|---|
| 有効化 | `.gemini/settings.json` の `telemetry.enabled: true` / `target: "local"` / `outfile: <パス>`（環境変数 `GEMINI_TELEMETRY_*` が設定を上書きする） |
| 既定値 | `enabled` は **`false`**（既定では何も出力されない）。`target` の既定は `local` |
| 出力先の決定 | `outfile` 指定時は `FileSpanExporter`/`FileLogExporter`/`FileMetricExporter` でそのファイルへ書き出す（`outfile` は `otlpEndpoint` より優先） |
| 得られる指標 | イベント `gemini_cli.api_response`（属性: `model` / `input_token_count` / `output_token_count` / `cached_content_token_count` / `thoughts_token_count` / `tool_token_count` / `total_token_count` / `duration_ms` / `status_code` 等）、メトリクス `gemini_cli.token.usage`・`gen_ai.client.token.usage` ほか |

**#105 で決めるべきこと（本MRでは決めない）**

- **出力先パス**: `usage/` 配下（`.gitignore` 対象なのでコミットされない）へ置く。既存の
  `usage/session-logs/` `usage/state/` との責務分離をどうするか。
- **`logPrompts` の扱い**: 既定が **`true`** で、**プロンプト本文がローカルファイルへ書き出される**。
  `usage/` は `.gitignore` 対象とはいえ、意図せず機微な内容が平文で残るため、**`false` を既定に
  する**方向で検討する。
- **`target` を必ず `local` にする**（`gcp` はGoogle Cloudへ直接送信されるため、既定で有効化しない）。
- **トークンの情報源の二重化**: セッションログ（`tokens`）とテレメトリ（`api_response`）の
  両方からトークンが取れる。**どちらをレポートの正とするか**、あるいは併記するかを決める。
- **ファイル形式と差分の取り方**: `outfile` が追記型かどうか、1行1JSONかを確認し、push毎の差分を
  取るカーソルを設計する（セッションログ側と同じ仕組みを流用できるか）。
- **有効化を本リポジトリの既定にしてよいか**: `.gemini/settings.json` は本リポジトリで唯一
  Git管理下にある `.gemini/` 配下のファイルであり、ここを変えると**利用者全員のGemini CLIの
  挙動が変わる**。既定で有効にするか、任意設定として案内するに留めるかを決める。

## issueの分割判定（flow-id 1-4）

**分割は提案しない。** issueの受け入れ条件は複数項目に分かれているが、いずれも
`UsageTracking.sh` の同じ集計経路（カーソル・ブランチ帰属・状態マージ・レポート組み立て）へ
同時に効くもので、単独でマージすると集計が中途半端な状態になる。`.claude/skills/issue-mr-flow/SKILL.md`
「issueが大きすぎる場合の分割提案」の**分割しない条件「横断的変更」**に該当する。

## フェーズ2〈調査〉

issue本文の前提が着手時点で覆っており、**上記の裏取りと、それを踏まえた設計選択肢の整理が必要**な
ため、調査フェーズを実施する想定である（最終判断は flow-id 2-1）。

**個別調査計画（flow-id 2-1）では、`参考ディレクトリ/gemini-insights` を参照対象として明示する**
（旧 `.json` 形式のパーサ実装であり、メッセージ1件のキー項目は新形式と同一のため、`toolCalls` の
扱い・エラー分類・稼働時間の考え方がそのまま参考になる）。

調査したいこと:

1. **形式の確定と裏取り**
   - `参考ディレクトリ/gemini-insights/gemini_insights/collect.py`（`parse_session_file`）と、
     現行形式パーサ（Rust）・`chatRecordingTypes.ts` を突き合わせ、新旧で共通のキー項目と
     JSONL固有の制御レコードを確定する。
   - `$set` / `$rewindTo` が**いつ出るか**（セッション要約の生成・`/rewind` 操作）を確認する。
   - `toolCalls[].status` の値集合（`success` / `error`\|`failed` / `pending`\|`running` / 欠落）と、
     欠落時の判定（`result` が空なら pending）を確定する。
2. **hookペイロードの前提確認**
   - Gemini CLIのAfterTool hookが `transcript_path` / `session_id` を渡すか、渡すとして
     それが `chats/session-<TIMESTAMP>-<sessionId先頭8文字>.jsonl` を指すか（未検証。
     spec「未決定事項・懸念点」に記録済み）。
   - 渡さない場合の代替（`~/.gemini/tmp/<hash>/chats/` をグロブで探索し、`session_id` の
     先頭8文字で照合する）が要るかを判断する。
   - `sessionRetention` による自動削除がミラー・再集計に与える影響を確認する。
3. **既存集計経路の分岐点の特定**
   - `sync_usage_state` / `_usage_aggregate_new_lines` / `_usage_aggregate_transcript` /
     `_usage_read_cursor` / `_usage_write_cursor` / `_usage_append_push_index` /
     `_usage_sync_session_logs` / `_usage_merge_state` のうち、engine分岐が要るものを列挙する。
   - **同じ追記型JSONLでも「新規行だけを足す」方式が使えない**点の影響範囲を洗い出す（下記）。
4. **設計上の選択肢の整理**（issueの期待する動作4〜6に対応）

   | 論点 | 検討する選択肢 |
   |---|---|
   | 差分の取り方（**最大の論点**） | 同一idのリビジョン再送・`$set` があるため、Claude Code式の「新規行のみ加算」は**二重計上する**。(a) 毎回ファイル全体をid単位で畳んで累計スナップショットを作り、状態が持つ前回累計との**差分**を取る（`activeSeconds` が既に採っているパターン）／(b) 計上済みidの集合を状態に持つ／(c) その他 |
   | `$rewindTo` の扱い | (a) 会話としては切り詰められるが**課金・ツール実行は起きている**ので集計からは外さない（提示されたRustパーサの方針）／(b) CLI本体の再構成に合わせて切り詰める。**対応工数レポートの目的に照らすと(a)が有力**だが、明示的に決めてDDRへ残す |
   | 行カーソル・`push-index.jsonl` | 追記型なので行番号自体は意味を持つ。差分計算に使わない場合も、push断面の記録・「新規行なし＝早期リターン」の判定には流用できるか |
   | ブランチ帰属 | `cwd`/`gitBranch` が無いため、「前回push時点からの差分を、そのpush時点のブランチの作業として扱う」等。**限界（ブランチを跨いで作業した分が混ざる）を明示する** |
   | トークン | `{input, output, cached, thoughts, tool, total}` を既存テーブル（Input/Output/Cache Write/Cache Read）へどう対応づけるか。`cached`→Cache Read は自然だが **Cache Write 相当が無い**。`thoughts`/`tool` を別列にするか、Gemini用に別テーブルにするか。リビジョンで `tokens` が `null` になる場合に先行リビジョンの値を消さないこと |
   | 投稿要否のガード | 現行は「トークン合計0なら投稿しない」。トークンが取れるなら現行のままでよいか、ツール実行回数等も見るべきか |
   | ツールエラー | `status == "error"\|"failed"` を計上。`pending`/`running` の扱い（未完了として計上しない）を決める |
   | サブエージェント | 現行は `subagents/<session_id>/` へ保存のみ（構造的に集計外）。本体側が親セッションIDのディレクトリ配下へネストする仕様であることが裏付けられたため、そのネストを辿って集計するか、`ToolCallRecord.agentId` で親側から辿るか |
   | 旧 `.json` 形式 | **flow-id 2-4 で「新形式のみ」と決定済み**（個別調査計画の 決-1）。論点としては閉じている |

5. **既存テストの把握**
   - `.claude/scripts/test/test_usage_tracking.sh` のフィクスチャの作り方・アサーションの型を確認し、
     Gemini用フィクスチャ（リビジョン再送・`$set`・`$rewindTo`・切り詰め）を追加する形を決める。

成果物: `reports/日付_partitioned-forging-seahorse_Geminiセッションログ調査.md`（正文）と同名の `.html`。

## フェーズ3〈作業〉

調査結果を受けて確定するが、現時点の見込みは次のとおり。

1. `UsageTracking.sh` にGemini用の集計関数を追加し、`sync_usage_state` から engine で分岐させる
   （**Claude Code側の関数には手を入れない**＝既存の集計結果を変えないことを構造で担保する）。
2. 差分の取り方を上記の決定に従って実装する（id単位の後勝ちマージ・`$set`・`$rewindTo` の扱いを含む）。
3. `post-push-usage-report.sh` のレポート組み立てを、Gemini側の指標（ツールエラー回数等）と
   トークン列の対応づけに合わせる。**トークンが取れない場合でも空テーブル・0の羅列にしない。**
4. `.claude/scripts/test/test_usage_tracking.sh` にGeminiフィクスチャの単体テストを追加する
   （`passed=N failures=N` 形式。**同じ範囲を二重計上しないこと**の検証を必ず含む）。
5. Claude Code側の既存テストが通ることを確認する。

## フェーズ4〈反映〉

反映対象は **flow-id 4-1 で洗い出す**。現時点では確定させない。見込みの候補は次のとおり。

- `.claude/docs/spec/issue-mr-workflow.md`
  - 「エンジン判定」節の「Gemini CLIはミラーへの保存のみ対応し、対応工数の集計対象には含めない」
    という現行記述の更新
  - 「対応工数レポート」節へのGemini経路の追記
  - 「未決定事項・懸念点」へ、実機検証できなかった範囲・Gemini CLIのバージョン依存の明示。
    あわせて「サブエージェントが親と同じセッションIDで動作するのではないか」という既存の懸念が
    解消できていれば「決定済み事項」へ移す
- `.claude/docs/ddr/` へのDDR新規作成（差分の取り方・`$rewindTo` の扱い・ブランチ帰属・
  トークン列の対応づけ・サブエージェントの扱い・稼働時間の算出方式・行カーソルの扱い・
  セッションファイル消失時の挙動）
  - **DDR番号は flow-id 4-6 の直前に `main` の最新を見て採番する**（`main` が進むと衝突するため）
- AIアセット反映（`.claude/rules/` 等）の要否は 4-1 で判断する

## 検証方法

- `bash .claude/scripts/test/test_usage_tracking.sh` が `passed=N failures=0` で通ること
  （Gemini用の新規ケース・Claude Code用の既存ケースの両方）
- `bash -n` で変更した `.sh` の構文チェック
- Claude Code側の集計結果が変わらないこと（既存テストのアサーションを変更しないことで担保する）
- **実機（Gemini CLI）での検証は本リポジトリの開発機では行えない**（`~/.gemini` が存在しないことを
  確認済み）。合成フィクスチャでの検証にとどまるため、未検証の範囲は reports と spec の
  「未決定事項・懸念点」へ明示する。

## やらないこと

- Claude Code側の集計ロジック・レポート内容の変更
- Gemini CLI実機での動作確認（環境が無い。未検証として明示する）
- **テレメトリ関連一式**（ローカル出力・push毎集計・`.gemini/settings.json` の変更）。flow-id 2-4でスコープ外と決定し、issue #105 へ切り出した（上記「スコープから外した要件」）
- `logs.json`・`--output-format stream-json` への対応（別系統。上記「混同しやすい別系統」）
- GitLab向けの追加対応（本issueの対象外）
- 参考実装（gemini-insights / 提示されたRustパーサ）のコードそのものの移植（**形式の情報源として
  参照するのみ**で、実装はbash+jqで本リポジトリの規約に沿って書く）
