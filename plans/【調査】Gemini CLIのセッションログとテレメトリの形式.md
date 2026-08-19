---
title: 【調査】Gemini CLIのセッションログとテレメトリの形式
type: plan
description: 対応工数レポートをGemini CLIへ対応させるための、セッションログJSONL・テレメトリ出力・既存集計経路の調査計画
tags: [調査, gemini-cli, usage-report, telemetry]
keywords: [セッションログ, JSONL, chatRecordingTypes, toolCalls, tokens, rewindTo, テレメトリ, outfile, UsageTracking, 二重計上]
---

# 【調査】Gemini CLIのセッションログとテレメトリの形式

- issue: [#97](https://github.com/yuki-matsu783/MR-driven-workflow/issues/97)
- 全体作業計画: `plans/partitioned-forging-seahorse.md`（flow-id 1-5でユーザー承認済み）
- flow-id: 2-1（個別調査計画）

## 目的

`.claude/hooks/lib/UsageTracking.sh` をGemini CLIへ対応させる**実装方針を、フェーズ3の個別作業計画
（flow-id 3-1）が書ける粒度まで確定させる**こと。

このissueは着手時点で**issue本文の前提が2点覆っている**（全体作業計画「着手時点で判明した、
issue本文の前提のズレ」節。flow-id 1-4で記録・1-5で承認済み）。

1. セッションログは単一JSONではなく、Gemini CLI v0.39.0以降は**追記型JSONL**である。
2. **トークン相当のフィールドは実在する**（`tokens: {input, output, cached, thoughts, tool, total}`）。

したがって本調査は「形式が何か」を一から調べるのではなく、**上記の裏取り**と、**それを踏まえた
設計上の分岐点の決定**が主眼である。

## 参照する情報源

| 情報源 | 位置づけ |
|---|---|
| `参考ディレクトリ/gemini-insights/gemini_insights/collect.py` | **旧 `.json` 形式のパーサ実装**。メッセージ1件のキー項目は新形式と同一のため、`toolCalls` の扱い・ツールエラーの分類・稼働時間の考え方がそのまま参考になる（ユーザーの明示指示により必ず参照する） |
| google-gemini/gemini-cli の `packages/core/src/services/chatRecordingTypes.ts` / `chatRecordingService.ts` / `packages/cli/src/utils/sessionUtils.ts` | **形式の一次情報**。フィールド定義・ファイル名規則・新旧両対応の読み込み処理 |
| google-gemini/gemini-cli の `docs/cli/telemetry.md` / `packages/core/src/telemetry/sdk.ts` | テレメトリの設定項目・出力先決定ロジック・イベント属性 |
| 提示された現行形式パーサ（Rust） | JSONLのイベント畳み込み（id後勝ち・`$set`・`$rewindTo`）の実装例 |
| `.claude/hooks/lib/UsageTracking.sh` / `post-push-usage-report.sh` / `.claude/scripts/test/test_usage_tracking.sh` | 変更対象の既存実装 |

## 調査項目

issueの受け入れ条件との対応を右列に示す。

| # | 調査項目 | 対応する受け入れ条件 |
|---|---|---|
| A | **形式の裏取り**: 1行目メタデータ・メッセージレコード・`$set`・`$rewindTo` の構造、`toolCalls[].status` の値集合、`tokens` の各フィールドを、一次情報と `collect.py` で突き合わせて確定する | 集計できること全般 |
| B | **hookペイロードの前提確認**: Gemini CLIのAfterTool hookが `transcript_path` / `session_id` を渡すか。渡すならそれが `chats/session-*.jsonl` を指すか。渡さない場合の代替探索（`sessionId` 先頭8文字でのグロブ照合）の要否 | 「合計0で早期終了しない」 |
| C | **差分の取り方の決定**: 同一idのリビジョン再送・`$set` があるため「新規行のみ加算」は二重計上する。候補(a)全体をid単位で畳んで前回累計との差分／(b)計上済みidの集合を保持／(c)その他 から選び、根拠を示す | 「同じ範囲を二重計上しない」 |
| D | **`$rewindTo` の扱いの決定**: 集計から外すか残すか | 二重計上・妥当性 |
| E | **ブランチ帰属の決定**: `gitBranch` 相当が無い。1行目メタデータの `directories` が使えるかを含めて方針を決め、**限界を明示する** | 期待する動作5 |
| F | **トークン列の対応づけの決定**: `{input, output, cached, thoughts, tool, total}` を既存テーブル（Input/Output/Cache Write/Cache Read）へどう載せるか。`cached`→Cache Read は自然だが Cache Write 相当が無い | 期待する動作3・「0の羅列にしない」 |
| G | **投稿要否ガードの決定**: 現行「トークン合計0なら投稿しない」をそのまま使えるか | 「合計0で早期終了しない」 |
| H | **ツールエラーの計上方法の決定**: `status == "error"\|"failed"` を計上。`pending`/`running` の扱い | 期待する動作2 |
| I | **サブエージェントの扱いの決定**: 本体側は `chats/<親sessionId>/<完全なsessionId>.jsonl` へネストする。集計対象に含めるか、保存のみに留めるか | 期待する動作6 |
| J | **旧 `.json` 形式の対応可否の決定**: 拡張子ディスパッチで両対応にするか、新形式のみか | 移行時の実害 |
| K | **既存集計経路の分岐点の特定**: `sync_usage_state` ほか各関数のうち engine 分岐が要るものを列挙し、**Claude Code側に手を入れずに済む構成**を示す | 「Claude Code側が変化しない」 |
| L | **テレメトリ出力の形式確認**（スコープ追加分）: `outfile` へ書かれるファイルが1行1JSONか・追記型か・spans/logs/metricsが混在するか。`gemini_cli.api_response` から何を取り出すか | スコープ追加分 |
| M | **テレメトリ有効化の判断材料の整理**（スコープ追加分）: 出力先パス・`logPrompts` の既定・`target` の固定・**`.gemini/settings.json` を変えることの影響範囲** | スコープ追加分 |
| N | **既存テストの型の把握**: `test_usage_tracking.sh` のフィクスチャ・アサーションの書き方を確認し、Gemini用ケース（リビジョン再送・`$set`・`$rewindTo`・テレメトリ）の追加方法を決める | 「単体テストで検証できる」 |

## 進め方

1. まず **A・B・L**（事実確認）を済ませる。ここが揺れると以降の決定がすべて揺れるため。
2. 次に **K**（既存経路の分岐点）を確定し、変更範囲の輪郭を決める。
3. そのうえで **C〜J・M**（設計判断）を、選択肢と却下理由の形で整理する。**C が最大の論点**であり、
   他の判断はCの結論に依存しうるためCから着手する。
4. 最後に **N** を確認し、フェーズ3で書くテストの形を決める。

## この計画で決めないこと（スコープ外）

- **実装そのもの**（関数の追加・シグネチャ・jqフィルタの中身）。フェーズ3（flow-id 3-1）で計画する。
- `logs.json`・`gemini -p --output-format stream-json` への対応（別系統。全体作業計画「混同しやすい
  別系統」）。
- テレメトリの `target: "gcp"` 対応、OTLPコレクター（Jaeger等）の構築。
- GitLab向けの追加対応。
- 参考実装（gemini-insights / Rustパーサ）のコードそのものの移植。**形式の情報源として参照するのみ**。

## 検証（この調査が完了したと言える条件）

調査結果は `reports/20260820_partitioned-forging-seahorse_Geminiセッションログとテレメトリの調査.md`
（正文）と同名の `.html` に記録する。**個別調査計画（本ファイル）には結果を書かない**
（`.claude/skills/issue-mr-flow/SKILL.md`「計画と実施結果の分離」）。

- 調査項目 A〜N のすべてに、結論（または「決められなかった理由と次にどこで決めるか」）が
  reports のmdに書かれている。
- **決定（C〜J・M）には、採用案・却下案・根拠**が添えられている（そのままDDRの素材になる形）。
- 実機確認ができない項目は「**未検証**」と明記され、何を確認すれば確定するかが書かれている。
- 次のコマンドが通ることを確認する（既存の状態を壊していないことの確認）。

  ```bash
  bash .claude/scripts/test/test_usage_tracking.sh
  bash -n .claude/hooks/lib/UsageTracking.sh
  ```

- 実機（Gemini CLI）での確認は**行えない**（この開発機に `~/.gemini` が存在しないことを
  flow-id 1-4 で確認済み）。合成フィクスチャと一次情報の突き合わせで代替する。
