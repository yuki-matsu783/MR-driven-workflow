---
title: worklog 【設計】【実装】【テスト】HANDOFF進捗自動更新スクリプト push3
type: log
description: update-handoff-progress.shの実装・テスト作業ログ
tags: [worklog, handoff, automation]
keywords: [update-handoff-progress, flow-id, 進捗表, テスト, worklog]
---

# worklog: 【設計】【実装】【テスト】HANDOFF進捗自動更新スクリプト

対象: issue #20対応。`.claude/scripts/src/update-handoff-progress.sh`の新規実装と
`tests/test_update_handoff_progress.sh`によるテスト（2026-08-18）。
全体作業計画: `plans/shiny-puzzling-umbrella.md`
個別作業計画: `plans/【設計】【実装】【テスト】HANDOFF進捗自動更新スクリプト.md`
push回数: 3

## 試したこと

- `.claude/scripts/src/update-handoff-progress.sh` を個別作業計画どおりに実装
  （`mark-done` / `mark-skip` / `add-round` / `set-header` の4サブコマンド）。
- `tests/test_update_handoff_progress.sh` を実装し `passed=15 failures=0` を確認。
- 実際の `HANDOFF.md` に対して `mark-done`/`mark-skip`/`set-header` を試し、動作確認した。

## うまくいったこと

- 進捗列の書き換えに `${line/pattern/repl}` のようなbashパターン置換を使うと、`[x]`のような
  進捗記号がglobの文字クラスとして誤解釈される危険があると気づき、正規表現でprefix/progress/
  suffixの3区画へ分解してから単純な文字列連結で再結合する設計にした（`parse_table_row_to_reply`）。
- `[[ "$progress" != *'[]' ]]` のように、globパターンの一部だけをクォートすることで、`*`は
  ワイルドカードのまま `'[]'` 部分だけをリテラル一致にできる（bashの仕様どおり動作を確認）。

## ダメだったこと

- **重要な発見**: 実際の`HANDOFF.md`で動作確認中、`mark-skip 3-8 3-9`（人間レビュー待ちステップの
  スキップ）を実行した直後に`mark-done 3-6`を呼んだところ、`add-round`/`mark-done`のループ範囲
  一括適用ロジックにより、同じループ範囲（`3-6 3-7 3-8 3-9`）に属する3-8が対象に含まれ、
  「末尾が[]でない（既に[-]のため）」でエラーになった。
  - これは実装のバグではなく、`.claude/rules/docs-workflow.md`の「同じループ範囲内のステップは
    常に同じ個数の[]を持つ」という既存ルールを忠実に実装した結果であり、**むしろ意図通りの
    ガード**だった。
  - この過程で、前issue #13のHANDOFF.md（725015bコミット時点）は、3-6/3-7だけを個別に`[x]`にし
    3-8/3-9を`[]`のまま残す、というループ範囲ルールに反する運用をしていたことが判明した
    （手作業更新だったため、まさに本issueが解消しようとしている「書き間違い」の実例）。
  - 対応: `mark-skip 3-3 3-4 3-8 3-9 4-3 4-4 4-8 4-9`を取り消し（Editツールで`[]`へ手動復元）、
    ループ範囲（3-6〜3-9, 4-6〜4-9）は「1周（レビュー往復1回）が完全に完了して初めて`[x]`にする」
    という設計思想に忠実に、`[]`のまま残す方針へ変更した。3-6/3-7で実施した内容自体は
    「やったこと」セクションの文章で表現する。
- この発見は、非対話的実行環境（Claude Code on the webのリモート実行環境）でレビューステップを
  意図的に省略する運用と、ループ範囲の記号ルールが本質的に相容れないことを示している。
  今回は「やったこと」欄での補足に留めたが、恒久的な運用ルールとして
  `.claude/skills/issue-mr-flow/SKILL.md`または`.claude/rules/docs-workflow.md`へ明文化する
  価値がある（フェーズ4で検討）。

- **再発**: フェーズ4の反映作業完了後、`mark-done 4-6`を実行したところ、上記と全く同じ理由
  （4-6がループ範囲`4-6 4-7 4-8 4-9`に属する）で4-7/4-8/4-9まで一括`[x]`になってしまった。
  今回は`mark-skip`で先に一部を`[-]`にしていなかったため`mark-done`はエラーにならず**黙って**
  一括適用され、気づくのに一手遅れた。3-6のときに教訓を得ていたにもかかわらず踏んだのは、
  「操作対象のflow-idがループ範囲に属するかどうかを事前に確認する」という運用側の注意が
  仕組みとして徹底されていなかったため。`.claude/docs/spec/update-handoff-progress.md`の
  「制約・設計判断」に明記したので、今後はこの仕様書を確認してから`mark-done`/`add-round`を
  呼ぶこと。

## 次の一歩

- 反映作業（spec/ルール/スキル/DDR）自体は完了。次はflow-id 4-7（commit・push）→
  4-10相当（describe）→ flow-id 5-1（片付け・HANDOFF.mdリセット）へ進む。

---
