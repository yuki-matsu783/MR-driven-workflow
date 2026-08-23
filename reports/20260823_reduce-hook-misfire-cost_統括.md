---
title: 20260823 hookの空振り起動コスト削減 統括（issue #159）
type: report
description: block-direct-git-commit.sh / post-issue-create-notice.sh へ前置フィルタを追加しjq呼び出し前の空振り起動コストを削減した、issue #159 / PR #162 全体の最終統括レポート
tags: [report, hooks, 前置フィルタ, 性能, issue-159, 統括]
keywords: [前置フィルタ, 超集合, execve, clone, jq, 敵対的レビュー, DDR, command-position, issue-149]
---

# 20260823 hookの空振り起動コスト削減 統括（issue #159）

## 何を変えたか

- `.claude/hooks/block-direct-git-commit.sh`（PreToolUse）と
  `.claude/hooks/post-issue-create-notice.sh`（PostToolUse）の `main()` 冒頭へ、jqを一切呼ばない
  **前置フィルタ**（純粋関数 `raw_hints_at_git_commit` / `raw_hints_at_issue_create`）を追加した。
  対象外ペイロード（commit/起票と無関係なコマンド）では、判定材料の取り出し（`jq`起動）そのものが
  発生しなくなる。
- 判定本体（`command_invokes_git_subcommand` / `is_issue_create_call`）のロジックは一切変更して
  いない。前置フィルタは、判定本体が検知する入力を1件も取りこぼさない「超集合」として設計した
  （超集合でなければ、安全側のhookのガードが無言で無効化されるため）。
- `.claude/scripts/test/test_block_direct_git_commit.sh`（新規、27件）・
  `.claude/scripts/test/test_post_issue_create_notice.sh`（追記、31件）で、前置フィルタの
  純粋関数テストと、スタブjq（呼ばれたら失敗する）による「対象外ペイロードでjqが1度も
  呼ばれないこと」の結合テストを追加した。

## なぜそうしたか

issue #70（PR #157、未マージ）が push系hook2本（`post-push-usage-report.sh` /
`post-push-compact-prompt.sh`）へ導入した「`IFS= read -r -d '' raw || true` + `case`」という
bash組み込みのみの前置フィルタパターンを、本issueが対象とする2本のhookへ同様に適用した。

設計判断の核心は「前置フィルタが精密判定の超集合であり続けるための正規化」で、2回の敵対的
レビューを通じて次の2つの反例が実機で見つかり、いずれも修正した（詳細・却下案は
[`.claude/docs/ddr/i0159-01-hookの前置フィルタは純粋関数によるバックスラッシュ除去と大文字小文字非依存比較で超集合を保つ.md`](../.claude/docs/ddr/i0159-01-hookの前置フィルタは純粋関数によるバックスラッシュ除去と大文字小文字非依存比較で超集合を保つ.md)）。

1. **シェルレベルのバックスラッシュエスケープ**: `CommandPosition.sh` は `\x`（xが
   `[A-Za-z0-9_./-]`）のバックスラッシュを落としてxだけを残すため、`git com\mit` は判定本体では
   「commit」として検知されるが、単純な `*commit*` 部分一致では素通りしていた（1回目の敵対的
   レビューで検出）。対策: 比較前にバックスラッシュを一括除去する。
2. **JSONエンコード層のエスケープ**: 前置フィルタが受け取るのは、hookへの入力そのもの
   （**jqがデコードする前の生JSON文字列**）である。実コマンド中の1文字（改行等）はJSON
   エンコードされると2文字のエスケープ列（`\n`等）になるため、バックスラッシュ1文字だけを
   除去すると2文字目が単独の文字として残り、語の分割位置に紛れ込んで超集合が壊れる（実例:
   `git com\<改行>mit`（行継続）はJSON化すると`com\\\nmit`になり、単純なバックスラッシュ除去では
   `comnmit`になって一致しなくなる。commit直前の作業結果に対する2回目の敵対的レビューで検出、
   実機でend-to-endのブロック解除まで確認済み）。対策: JSON文字列エスケープの2文字シーケンス
   （`\\` `\"` `\n` `\t` `\r` `\/` `\b` `\f`）を丸ごと除去してから、残ったバックスラッシュを落とす。

比較の大文字小文字非依存化には `${var,,}`（bash 4.0以降専用）ではなくブラケット式
（`[Cc][Oo][Mm]...`）を採用した。両hookは元々bash 4.3未満への部分一致フォールバックを持つ
設計で、`${var,,}` をそのフォールバックより前段（前置フィルタ）に置くと、フォールバックへ
到達する前に展開エラーでhookプロセスごと落ちてしまうため（1回目の敵対的レビューで検出）。

## 検証結果

```
$ bash .claude/scripts/test/test_command_position.sh
passed=75 failures=0
$ bash .claude/scripts/test/test_post_issue_create_notice.sh
passed=31 failures=0
$ bash .claude/scripts/test/test_block_direct_git_commit.sh
passed=27 failures=0
```

execve/clone回数の実測（strace, Linux。git bash実機とは環境が異なる。詳細は各作業結果レポート
参照）:

| hook | 変更前 execve | 変更前 clone | 最終版 execve | 最終版 clone |
|---|---|---|---|---|
| `block-direct-git-commit.sh` | 5 | 10 | 1 | 0 |
| `post-issue-create-notice.sh` | 7 | 17 | 1 | 1（前置フィルタと無関係な既存の実サブシェル分） |

スタブjq（呼ばれたら失敗する）を使い、対象外ペイロードで実際にjqが1度も呼ばれないことを
確認した（時間計測ではなく呼び出し有無そのもので判定）。

一方、`IFS= read -r -d '' raw` は入力サイズに比例したread(2)回数になる（1バイト単位）ため、
大きな`tool_input.command`（ヒアドキュメント等）では削減したexecve/clone以上のシステムコール
増加になりうる特性がある。git bash実機が無く実測できなかったため、実装は変更せず
`.claude/rules/shell-script-style.md`へ注記するに留めた（残課題参照）。

## spec・DDRへの反映先

- `.claude/docs/ddr/i0159-01-hookの前置フィルタは純粋関数によるバックスラッシュ除去と大文字小文字非依存比較で超集合を保つ.md`（新規）:
  前置フィルタの設計判断（超集合の要件・2つの反例と対策・issue #149との関係・却下案）を記録。
- `.claude/docs/spec/command-position.md`「利用元」節・「未決定事項・懸念点」節: 前置フィルタの
  存在と、issue #149着手時に超集合関係を再確認すべき旨を追記。
- `.claude/rules/shell-script-style.md`「外部プロセス起動のコスト」節「hookの前置フィルタ」小節:
  hook向け前置フィルタパターンを一般化して追記（超集合の要件・JSONエスケープの扱い・
  bash互換性・read(2)コストの注意点）。issue #70のpush系2本は本ドキュメント時点で未実装
  （PR #157未マージ）である旨も明記。

## 残課題

- push系2本のhook（`post-push-usage-report.sh` / `post-push-compact-prompt.sh`）は本issueの
  スコープ外（issue #70/PR #157の範囲）。
- `post-issue-create-notice.sh`の判定本体（`is_issue_create_call`）のコマンド位置判定化は
  issue #149の範囲。本issueの前置フィルタは#149の変更後も超集合であり続ける設計にしたが、
  無条件の保証ではないため、#149の着手時に再確認が必要（issue #149へ通知済み）。
- `IFS= read -r -d ''`のread(2)回数が大きな入力で増加する特性は、git bash実機での実測ができて
  いない。大きな`tool_input.command`を扱う可能性がある他のhookへこのパターンを適用する際は、
  この特性を踏まえた検証を行うこと（`.claude/rules/shell-script-style.md`に注記済み）。
- クォート断片の連結による意図的な文字列分割（例: `git 'com''mit'`）への対応は、精密判定
  （`CommandPosition.sh`）自体が対象外としているため、前置フィルタも対応しない（スコープ外として
  明示。意図的な回避への対策ではなく既定動作を確実な方向へ倒す仕組みであるため）。
