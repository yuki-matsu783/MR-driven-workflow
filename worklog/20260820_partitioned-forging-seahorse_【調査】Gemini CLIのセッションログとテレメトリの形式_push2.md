---
title: worklog 【調査】Gemini CLIのセッションログとテレメトリの形式 push2
type: log
description: issue #97 の調査フェーズにおける試行錯誤の記録（push2時点）
tags: [worklog, gemini-cli, usage-report]
keywords: [セッションログ, JSONL, テレメトリ, 前提のズレ, gemini-insights, chatRecordingTypes]
---

# worklog: 【調査】Gemini CLIのセッションログとテレメトリの形式

対象: 対応工数レポートのGemini CLI対応（issue #97）（2026-08-20）。
全体作業計画: `plans/partitioned-forging-seahorse.md`
個別作業計画: `plans/【調査】Gemini CLIのセッションログとテレメトリの形式.md`
push回数: 2

## 試したこと

- **`~/.gemini` の存在確認**: `ls -la ~/.gemini` → `No such file or directory`。この開発機では
  Gemini CLIを使っていないため、実データでの検証はできない。
- **参考実装の把握**: `参考ディレクトリ/gemini-insights/gemini_insights/collect.py` の
  `parse_session_file` を読み、旧形式（単一JSON）が `sessionId` / `projectHash` / `startTime` /
  `lastUpdated` / `messages[]` を持ち、`messages[].type` が `user` / `gemini`、`gemini` 側に
  `model` と `toolCalls[]{name, status, args, resultDisplay}` を持つことを確認した。
- **既存集計経路の把握**: `.claude/hooks/lib/UsageTracking.sh` の関数一覧（13関数）と、
  `sync_usage_state` の流れ（カーソル読取 → 新規行集計 → session-logsミラー →
  `_usage_aggregate_transcript` で activeSeconds の累計 → 状態マージ → サブエージェント集計 →
  push-index追記 → カーソル書込）を追った。
- **`_usage_sync_session_logs` の Gemini 分岐の確認**: `$(dirname "$transcript_path")/<session_id>/`
  をディレクトリごとコピーし、`subagents/<session_id>/` へ置く。集計側のglobが
  `subagents/agent-*.jsonl` なので構造的にマッチせず、「保存はするが集計しない」が担保されている。

## うまくいったこと

- **issue本文の前提が2点覆っていることを、着手時点（flow-id 1-4）で発見できた。**
  - ユーザーの指摘「geminiCLIもJSONLになっているはず」→ cc-switch#2347 の確認 →
    gemini-cli PR #23749（v0.39.0）で単一JSON → 追記型JSONL へ移行済みと判明。
  - 同時に **`tokens: {input, output, cached, thoughts, tool, total}` が実在する**ことも判明
    （issue本文の「使用量フィールドは扱っておらず」は旧形式の話だった）。
- **一次情報のファイル名まで特定できた**（`chatRecordingTypes.ts` / `chatRecordingService.ts` /
  `sessionUtils.ts` / `telemetry/sdk.ts`）。フェーズ2の裏取りはここを当たればよい。
- **既存の未検証の懸念が1つ解消できる見込みが立った。** spec「未決定事項・懸念点」にある
  「Gemini CLIのサブエージェントは親と同じセッションIDで動作するのではないか」という懸念は、
  本体実装が**サブエージェントのファイル名を `<完全なsessionId>.jsonl`** とし
  `chats/<親sessionId>/` 配下へネストすることから、別IDであると言える。
- **`_usage_sync_session_logs` の Gemini 分岐（issue #23 時点では未検証の想定）が、本体実装の
  ネスト構造と一致していることが裏付けられた。**

## ダメだったこと

- **最初の全体作業計画は、issue本文の前提（単一JSON・トークン無し）をそのまま採用して書いてしまい、
  ユーザーの指摘で全面的に書き直した。** issue本文が参照している参考実装（gemini-insights）自体が
  旧形式向けであることに、本文を読んだ時点では気づけなかった。
  - **教訓**: 外部ツールの内部フォーマットに依存する調査では、issue本文の記述も「起票時点の
    スナップショット」であり、**着手時に一次情報で再確認する**必要がある。とくに参照している
    参考実装の更新日・対象バージョンを見ること。
- 当初「トークンが取れないのでレポートから省略する」という前提でフェーズ3の見込みを書いていたが、
  これも前提が変わったため書き直した。

## 次の一歩

- 個別調査計画 `plans/【調査】Gemini CLIのセッションログとテレメトリの形式.md` の調査項目
  A〜N を、A・B・L（事実確認）→ K（分岐点）→ C〜J・M（設計判断）→ N の順で実施する。
- 結果は `reports/20260820_partitioned-forging-seahorse_Geminiセッションログとテレメトリの調査.md`
  へ記録する（本worklogと計画ファイルには結果を書かない）。

---

# 追記: 敵対的レビューとレビュー1周目の反映（flow-id 2-4）

## 試したこと

- **敵対的レビュー**（人間が `/adversarial-review` を明示的に呼んだ。フェーズ2の実施回数 1/3）を
  個別調査計画1ファイルに対して実施した。9件の指摘のうち8件をPR #101 へインライン投稿、
  1件（minor×medium）は会話への報告に留めた。
- レビュー返信を `get_mr_unresolved_comments` で取得した。**出力が60KBに達し**、8スレッド分の
  diffが繰り返し含まれるため、返信本文の抽出には `gh api .../pulls/101/comments` の
  `in_reply_to_id` を使うほうが確実だった。

## うまくいったこと

- **敵対的レビューが、自己確認では出てこない欠陥を実際に見つけた。** とくに次の3つは、
  全体作業計画には論点として存在したのに個別調査計画へ引き継げていなかったもので、
  「書かれていないことは欠けている」という敵対的レビューの立場でなければ拾えなかった。
  - 行カーソル・`push-index.jsonl` の扱い（`rewriteConversationFile` で行数が減る）
  - トークンの情報源の二重化（セッションログ対テレメトリ）
  - `sessionRetention` によるファイル消失の影響
- **サブエージェントが `参考ディレクトリ/gemini-cli`（Gemini CLI本体の完全なチェックアウト、
  `0.56.0-nightly.20260806.g761f604c1`）を発見した。** 呼び出し元（メインエージェント）は
  セッション開始時の `ls` で `gemini-insights` しか見ておらず、その後に追加されたことに
  気づいていなかった。これにより「実機が無いので未検証」としていた項目の多くが机上で確定できる
  見込みになった（`docs/hooks/reference.md:53` に `transcript_path` の定義があることを確認済み）。
- 調査項目を A〜N（14項目）から A〜S（18項目）へ拡張し、期待する動作2の5指標それぞれに
  対応先を割り付けた。

## ダメだったこと

- **`get_mr_unresolved_comments` の出力は、スレッド数が増えると返信本文を読むのに向かない。**
  各スレッドに95行のdiffが丸ごと付くため、8スレッドで60KBになった。返信が付いたスレッドは
  同じ threadId が2回現れる形で判別できるが、2件目の本文が出力から読み取れないケースがあった。
- 最初に書いた個別調査計画は、**全体作業計画に書いてあった論点を取りこぼしていた**（上記3点）。
  全体作業計画から個別計画へ落とすときに、論点の突き合わせをしていなかったことが原因。
  **教訓: 個別計画を書いたら、全体作業計画の該当節と1対1で突き合わせる。**

## 次の一歩

- flow-id 2-5（MR description更新）→ flow-id 2-6（調査の実施）へ進む。
- 調査は A・B・L（事実確認）→ K（既存経路）→ C → O・S → D → 残り → N の順で進める。
- 検証は合成フィクスチャ＋jqのプロトタイプで、C・D・O・S の結論が二重計上しないことを実際に確かめる。
