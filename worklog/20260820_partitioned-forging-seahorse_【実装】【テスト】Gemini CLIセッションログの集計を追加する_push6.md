---
title: worklog 【実装】【テスト】Gemini CLIセッションログの集計を追加する push6
type: log
description: Gemini CLIのJSONLセッションログ集計を実装した際の試行錯誤ログ（push6分）
tags: [worklog, usage-report, gemini-cli, hooks]
keywords: [_usage_gemini_fold, _usage_gemini_merge_state, build_usage_report_body, gemini-totals, jq, needsReset, diffAllZero, テスト, 二重計上]
---

# worklog: 【実装】【テスト】Gemini CLIセッションログの集計を追加する

対象: Gemini CLIのJSONLセッションログを対応工数レポートの集計対象へ加える実装とテスト（2026-08-20）。
全体作業計画: `plans/partitioned-forging-seahorse.md`
個別作業計画: `plans/【実装】【テスト】Gemini CLIセッションログの集計を追加する.md`
push回数: 6

## 試したこと

- 実装前に既存コードを精読し、計画の前提が実装と合っているかを確認した。
  - `_usage_aggregate_transcript`（L108〜）: `def days_from_civil` / `def epoch_from_iso8601` が
    jqプログラム内のdefとして定義されていることを確認。**シェル関数ではない**ため、
    `_usage_gemini_fold` 側へは複製する（計画「実装時に決めること」2の第一候補どおり）。
  - 末尾の `(if .assistantCount > 0 then .activeSeconds += $tailBuffer else . end)` を確認。
    レビュー指摘8のとおり末尾加算が実在するので、Gemini側にも同じ形で入れる。
  - `_usage_merge_state`（L275〜）: 返り値は `{branch, sessions, sinceLastPush}` ＋
    `lastPostedAt`/`agents` の引き継ぎ。`sessions[sessionId].lastActiveSeconds` は
    **ブランチ別状態ファイル**に入る。レビュー指摘1のとおり、ここへGeminiの累計を置くと
    ブランチ切り替えで再計上になる。
  - `sync_usage_state`（L554〜）: Claude Code経路は「カーソル読み → 新規行集計 →
    新規行が無ければ早期リターン → ミラー → …」の順。Gemini経路は内容ベースでしか判定
    できないため順序が変わる（計画どおり）。
  - `post-push-usage-report.sh`: 本文は `main` 内の `{ … } > "$tmp_file"` という無名ブロック。
    末尾は `( main ) || true` で、`source` すると `main` が走り `raw="$(cat)"` で止まる。
    レビュー指摘5のとおり、切り出しとガードの両方が要る。

- 実装のたびに合成フィクスチャで直接呼んで確かめた（テストを書く前に、まず1本のJSONLを作って
  `_usage_gemini_fold` を素で叩く）。**この段階で `awaiting_approval` の数え間違いが見つかった。**
- レポート本文が旧実装と一致するかを、`git show HEAD:` で取り出した旧スクリプトの本文ブロックを
  一時的な関数 `old_body` へ包み、同じ引数で呼んで `diff` する形で確かめた。

## うまくいったこと

- **`sync_usage_state` の分岐を「委譲1行」に留めた。** Gemini経路の処理を
  `_sync_usage_state_gemini` として独立させたことで、Claude Code経路の既存行が1行も動かない。
  差分を見た人が「既存経路は触っていない」と一目で確認できる。
- **旧実装との `diff` による担保。** レビュー指摘5への対応として本文を関数へ切り出したが、
  切り出しそのものが出力を変えていないことを、旧実装をラップして `diff` を取ることで確認できた
  （完全一致）。「テストを足した」だけでは切り出し時点の劣化を検出できないので、この比較は
  1回きりでも価値があった。
- **旧テストファイルを新ライブラリに対して実行した。**
  `git show HEAD:.claude/scripts/test/test_usage_tracking.sh` を一時ファイルへ出して実行し、
  `passed=33 failures=0` を確認。「既存アサーションを変更していない」ことを目視ではなく機械的に
  示せる。

## ダメだったこと

- **3桁区切りを行全体へ `sed` で適用しようとした。** トークンテーブルをjqで組み立てる形にした
  流れで、組み上がった行に `sed -E ':a; s/([0-9])([0-9]{3})...'` をかけた。**モデル名の数字列が
  壊れる**（`claude-3-5-sonnet-20241022` → `claude-3-5-sonnet-20,241,022`）。書いた直後に気づいて
  jq内の `def commafy` へ移した。**数値の整形は「数値であると分かっている場所」でやる**、という
  当たり前のことを、出力の形（markdownの行）に引きずられて忘れかけた。
- **未完了ステータスのツール呼び出しを実行回数に数えていた。** 決定Hを読んだうえで実装したのに、
  `toolCalls[]` をstatus無関係に数えるコードを書いた。フィクスチャに
  `awaiting_approval` を1件入れておいたおかげで、最初のスモークテストで露見した。
  **各statusを1件ずつ含むフィクスチャを最初に作ったことが効いた。**
- **テスト側のアサーションを4件間違えた**（実装ではなくテストのバグ）。
  - `grep -cF '- 使用モデル:'` … 先頭の `-` をgrepがオプションと解釈して失敗。`--` が要る。
  - `grep -F 'gemini-2.5-flash'` … 使用モデル行とテーブル行の2行にマッチ。`| gemini-2.5-flash |`
    のように区切りを含めて絞る必要があった。
  - `$rewindTo` のケースで期待値を取り違えた（inputとoutputの混同）。
- **`perl -0pi -e "..."` でテストファイルを直そうとして失敗した。** ダブルクォートで囲んだため、
  置換文字列の中の `$(printf ...)` をシェルが先に展開してしまい、jqのエラーが出た。
  小さな修正はEditツールで行うべきだった（`.claude/rules/shell-script-style.md` の
  「文字列がもう1段解釈される」系の罠と同根）。

## 次の一歩

- flow-id 3-7（commit・リモートへ反映してレビュー依頼）。
- フェーズ4でDDR化する判断: C・D・E・F・I・S に加え、レビューで決まった
  「前回累計はブランチ非依存に持つ」「トークン列の構成はengineではなくデータで決める」、
  実装で決めた「`_usage_append_push_index` はGemini経路で呼ばない」。
