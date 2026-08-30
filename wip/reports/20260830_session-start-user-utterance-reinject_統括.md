---
title: 20260830 session-start-user-utterance-reinject 統括
type: report
description: issue #151（compact後のユーザー発言再注入）の最終統括レポート。何を変えたか・なぜそうしたか・検証結果・spec/DDRへの反映先・残課題
tags: [session-start, user-utterance, compact, handoff]
keywords: [SessionStart hook, transcript, UserUtteranceSelect.jq, 育てる辞書, ブランチ絞り, DDR i0151-01, Gemini CLI, issue 151]
---

# 20260830 session-start-user-utterance-reinject 統括

<!--
このファイルはflow-id 5-4（最終統括レポート）の正文である。wip/plans/ wip/worklogs/ wip/reports/は
flow-id 5-5で削除されsquash mergeによりmainへは残らないため、本レポートの要旨はPR #197への
通常コメント（層2）としても投稿する。
-->

## 何を変えたか

issue #151「compact後もユーザーの直近発言（頭N文字×最大20件）をSessionStart hookで再注入する」を実装した。

- **`.claude/hooks/session-start.sh`**: `build_work_context`内に`build_user_utterance_context`を新設し、
  「次にやること」直後・SKILL.md再読み込み指示の手前へ「直近のユーザー発言」区画を挿入する。
  `transcript_path`を`main`→`build_context`→`build_work_context`→`build_user_utterance_context`と
  下方向へ渡し、再注入バイト数はセンチネル行`__USER_UTTERANCE_BYTES__:<N>`で上方向へ返す設計にした。
  累積除外カウント（`read_ack_exclusion_state_to_reply`/`update_ack_exclusion_counts`）と
  `append_size_warning`の第3引数（`excluded_bytes`）も新設した。
- **`.claude/hooks/lib/UserUtteranceSelect.jq`**（新規）: transcriptから`origin.kind=="human"`等
  5条件を満たすユーザー発言を抽出し、ブランチ絞り（Claude Codeのみ・`gitBranch`欠落時は全体走査へ
  フォールバック）→uuid重複除去→選定（先頭3件＋直近7件・最大10件）→整形（頭120+末尾40字／
  頭80+末尾30字のclip、除外内訳行の付与）までを1回のjq呼び出しへ集約した。
- **`.claude/hooks/session-start-ack-words.txt`**（新規）: 相槌等の除外辞書（10語、プレーンテキスト
  1行1語）。実測を経て`ok`/`OK`は除外対象から外した（合意そのものを消してしまうため）。
  「毎回のユーザ入力を見ながら育てる」運用とし、除外実績を注入テキストへ1行（`- 相槌等として除外:
  ok×1`）として可視化し、累積カウントは`wip/state/`（gitignore対象）で持つ。
- **`.claude/docs/spec/issue-mr-workflow.md`**「セッション開始時の自動コンテキスト注入」節へ、
  上記の設計（注入順序・母集団の抽出条件・選定式・除外規則・サイズ管理6000B上限・性能しきい値
  500ms・fail-open）を追記した。
- **`.claude/docs/ddr/i0151-01-...md`**（新規）: 採用判断15項目・却下案11項目・スコープ外4項目
  （Gemini CLI経路／過去transcript走査／AskUserQuestion回答の漏れ／辞書の配布層）・未確認事項3項目
  を記録した。
- **`.claude/rules/shell-script-style.md`**: 実装中に踏んだ2つの罠（jqの`|`は`or`/`and`/`,`より
  優先順位が低い／`grep`のパイプ内マッチ0件が`pipefail`下で無言に呼び出し元を中断させる）を
  AIアセットとして追記した。
- `.gitattributes`・`.gitignore`・`.claude/rules/directory-structure.md`（`wip/state/`・
  `session-start-ack-words.txt`の列挙）も実装に合わせて更新した。
- `.claude/scripts/test/test_session_start.sh`へ回帰テストを追加し、`passed=159 failures=0`
  （既存103件＋新規56件）を確認した。既存6箇所の`append_size_warning`呼び出しは無変更で通過。
- `.claude/`の全変更を`sync-gemini-assets.sh`で`.gemini/`へ変換同期した（flow-id 5-3）。

## なぜそうしたか

- **選定方針「先頭3件＋直近7件・最大10件」はユーザー提案を採用した。** 実transcript（約9時間・
  compact2回のセッション）では真の発言が7件で上限に届かない規模であり、この方針は「全件採用」と
  同義になるケースが多いことも実測で確認した。
- **ブランチ絞りはClaude Codeのみ実装し、Gemini CLIは対象外（issue #201へ切り出し）とした。**
  Gemini CLIのセッションログに`gitBranch`相当のフィールドが無いため（issue #97フェーズ2調査で
  確認済み）。さらに`session-start.sh`自体がGemini CLI経路で発火しない・`compact`起動要因が
  無い、という2つの手前の壁があることも判明し、これらもissue #201へまとめて記録した。
- **除外辞書は固定リストではなく「育てる」運用にした。** ユーザーから「辞書は毎回のユーザの入力を
  見ながら育てて行きたい」との指示を受け、初期辞書10語＋可視化（除外内訳行・累積カウント）＋
  記録先（辞書ファイル自体のgit履歴）の設計にとどめ、辞書の配布層（`core`のままだと配布先が
  育てた内容を再適用で上書きされる）はスコープ外としてissue #207へ切り出した。
- **性能しきい値は当初200msで設計したが、実測でgit bash見積もり約208msが超過**したため、
  ユーザー判断で500msへ改定した（現在は208msで42%、走査方式は全走査のまま採用）。
- **母集団の抽出条件は当初issue本文のヒューリスティックで足りると想定していたが、実データで
  `origin.kind=="task-notification"`（機械生成のユーザーターン）が`userType=="external"`等の
  条件をすり抜けることが判明**し、`.origin.kind=="human"`条件を追加した。

## 検証結果

- `bash .claude/scripts/test/test_session_start.sh` → `passed=159 failures=0`（既存103件＋新規56件、
  flow-id 4-6/4-9反映後の回帰なしを含む）。
- `bash .claude/scripts/src/check-doc-references.sh` → 新規参照切れ0件。
- `bash .claude/scripts/src/extract-frontmatter.sh .` → index.jsonl再生成、エラーなし。
- `bash .claude/scripts/src/generate-ddr-list.sh` → DDR一覧へi0151-01の1行追加を確認。
- `bash .claude/scripts/src/sync-gemini-assets.sh --check` → 再生成後「同期しています」で終了コード0。
- `bash .claude/scripts/src/check-base-conflicts.sh` → `hasConflict: false`（flow-id 5-1）。
- 実transcript（本セッション自身）に対する手動実行: populationCount=11・辞書一致除外0件・
  sectionText 558B・実行時間0.201秒（Linux、フィルタ単体。実運用経路全体・git bash実機は未計測）。
- 敵対的レビューは全4フェーズ（計画時×4＋作業実施時×2＋通算カウンタ対象3周）を実施し、
  findings合計 18+12+16+14+19+12=91件（フェーズ1のみカウンタ対象外）をすべて検算のうえ反映した。

## spec・DDRへの反映先

- `.claude/docs/spec/issue-mr-workflow.md`「セッション開始時の自動コンテキスト注入」節: 「ユーザー
  発言の抽出・再注入（issue #151）」項目として設計仕様を追記。
- `.claude/docs/ddr/i0151-01-compact後のユーザー発言再注入はorigin.kind条件・育てる辞書・全走査
  （しきい値500ms）で実装する.md`: 採用判断・却下案・スコープ外・未確認事項を記録。
- `.claude/rules/shell-script-style.md`「エラー方針」「JSON操作」節: jq演算子優先順位・grepの
  pipefail依存中断の2教訓を追記。

## 残課題

- **issue #201**: Gemini CLI経路（`session-start.sh`のGEMINI_PROJECT_DIR両対応・圧縮後再注入）。
  本issueからスコープ外として切り出し済み。
- **issue #207**: 「育てる」辞書の配布層（`core`のままだと配布先の育てた内容が再適用で上書きされる）。
  本issueからスコープ外として切り出し済み。
- **git bash実機での走査コスト**: しきい値500ms判定はLinux実測＋git bash見積もりに基づく暫定値。
  実機再測はDDR i0151-01「未確認事項」に記録し、確定した場合の反映先はspec側とする
  （DDR本文は原則不変のため）。
- **issue #198・#164への影響**: flow-id 5-2でマージ前通知を投稿済み（本PRの変更で両issueの
  「現状」節の前提が変わるため）。
