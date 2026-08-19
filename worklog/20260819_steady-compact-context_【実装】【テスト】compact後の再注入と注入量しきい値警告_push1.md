---
title: worklog compact後の再注入と注入量しきい値警告
type: log
description: issue #57 の実装・テストの試行錯誤ログ（matcher拡張・session-start.shの関数分割・しきい値警告・単体テスト）
tags: [worklog, session-start-hook, compact, unit-test]
keywords: [compact, matcher, additionalContext, しきい値, バイト数, HANDOFF, awk, source, BASH_SOURCE, 単体テスト]
---

# worklog: 【実装】【テスト】compact後の再注入と注入量しきい値警告

対象: issue #57 compact後にSessionStart hookが発火せずブランチ・issue/PR情報が再注入されない（2026-08-19）。
全体作業計画: `plans/steady-compact-context.md`
個別作業計画: `plans/【実装】【テスト】compact後の再注入と注入量しきい値警告.md`
push回数: 1

## 試したこと

### 1. matcherへの `compact` 追加

`.claude/settings.json` の `hooks.SessionStart[0].matcher` を
`"startup|resume|clear"` → `"startup|resume|clear|compact"` へ変更した。`jq -e .` でJSONとして
妥当なことを確認。`fork` は追加していない。

### 2. `session-start.sh` のテスト可能化

変更前はトップレベルに「stdin読み取り → `agent_id` 判定 → index.jsonl再生成 → `build_context` →
出力」が直書きされており、**`source` すると `raw="$(cat)"` でstdin待ちのままハングする**ため
単体テストできなかった。本体を `main()` へ移し、末尾を
`if [ "${BASH_SOURCE[0]}" = "${0}" ]; then main; fi` にした。

- hookとして `bash session-start.sh` で起動される場合は `BASH_SOURCE[0] == $0` で `main` が走る。
- テストから `source` された場合は一致せず、関数定義だけが読み込まれる。
- テストスクリプトの冒頭コメントに「ここでハングするなら本体が走っている」と書き残した
  （このガードが壊れたときに、テストが**タイムアウトという分かりにくい形**で失敗するため）。

### 3. 追加した純粋関数

| 関数 | 実装上の判断 |
|---|---|
| `context_text_bytes` | `wc -c` で**バイト数**を測る。日本語はUTF-8で3バイト/文字のため `${#s}`（文字数）では実際の注入量と3倍ずれる |
| `append_size_warning` | しきい値超過時のみ末尾へ指示文を追記。`-le` 判定なので「しきい値ちょうど」は追記しない |
| `extract_handoff_next_steps` | `awk` で `## 次にやること` 節（見出し行含む）を次の `## ` 見出しの手前まで抜き出す |
| `build_work_context` | 作業ファイル一覧＋HANDOFF抜粋を組み立てて標準出力へ返す |

### 4. 動作確認（実データ）

実際のhook起動と同じ形（stdinへJSON）で確認した。

- 通常起動: `additionalContext` に従来の4項目＋作業ファイル一覧＋HANDOFF「次にやること」が出た。
  **実測1,222バイト**（しきい値8,000の約15%）。
- `agent_id` 付き（サブエージェント相当）: 出力0バイト（受け入れ条件どおり）。
- `CONTEXT_SIZE_WARN_BYTES=100` で起動: 末尾に警告文が追記され、実測バイト数（1221）と
  しきい値（100）が本文に入ることを確認した。

## うまくいったこと

- **注入内容の「範囲」を設計時に絞る方針**（HANDOFF全文ではなく「次にやること」節のみ、
  plans/worklogは中身ではなくファイル名のみ）。これにより、実測1.2KBとしきい値8KBの間に
  十分な余裕ができ、「警告のみ・切り詰めなし」を安全に選べるようになった。
- 全単体テスト6本（13/17/35/15/33/44 = 157件）が `failures=0`。既存5本のアサーションは未変更。

## ダメだったこと

- **テスト側で2件のミスをした**（いずれも実装ではなくテストの誤り）。
  - `"$(context_text_bytes "$(printf 'a\nb\n')")"` を4バイトと期待したが3が返った。
    **コマンド置換が末尾の改行を落とす**ため。`$'a\nb\n'` に書き換えて解決。
    `.claude/rules/shell-script-style.md`「テスト」に既出の「`"$(func; echo $?)"` を使わない」と
    同根の落とし穴（コマンド置換の性質にテストの期待値が依存している）。
  - `"${section:0:20}"` で先頭20文字を切り出して見出しと比較したが、**この環境では
    バイト単位で切られ**、日本語が途中で欠けて `## 次にやるこ<壊れた文字>` になった。
    `head -1` による行単位の比較へ変更した。
- `local -n`（nameref）で配列へ追記する実装を最初に書いたが、bash 4.3+ 依存かつ
  「呼び出し側の変数名と衝突すると循環参照になる」という落とし穴があるため、
  **標準出力へ返して呼び出し側で `lines+=(...)` する形**へ書き換えた（他の関数と同じ流儀）。

## 次の一歩

- 特になし（フェーズ3完了）。フェーズ4（spec・DDRへの反映）へ進む。
