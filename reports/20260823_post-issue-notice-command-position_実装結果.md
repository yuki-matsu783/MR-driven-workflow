---
title: post-issue-create-notice.shのコマンド位置判定化 実装結果
type: report
description: issue #149。CommandPosition.shへcommand_invokes_scriptを追加し、post-issue-create-notice.shのCLI経路検知をコマンド位置判定へ差し替えた実装結果
tags: [hook, command-position, issue-149]
keywords: [command_invokes_script, CommandPosition, 敵対的レビュー, テスト結果]
---

# post-issue-create-notice.shのコマンド位置判定化 実装結果

対象: issue #149 / 個別作業計画
`plans/【設計】【実装】【テスト】post-issue-create-noticeコマンド位置判定化.md`

## 実施内容

1. `.claude/hooks/lib/CommandPosition.sh` へ次の2関数を追加した。
   - `_cp_scan_tokens_for_script`（内部）: 正規化済み文字列をトークン走査し、指定した
     スクリプトのbasenameがコマンド位置（単体実行／インタプリタ経由）で現れるかを判定する。
   - `command_invokes_script`（公開）: 上記に、極端に長い行への部分一致縮退・保守的
     フォールバック（`eval`/`bash -c`等）・引数の表記ゆれ吸収（パス付き・大文字混じり）を
     加えた公開インターフェース。
2. `.claude/hooks/post-issue-create-notice.sh` の `is_issue_create_call` のCLI経路判定を、
   トップレベルで確定させた `_pin_cli_match`（`command_invokes_script`を呼ぶ。ライブラリを
   使えない場合は従来の部分一致へ縮退）へ差し替えた。ヘッダコメント（検知対象・既知の
   トレードオフ・前置フィルタ節）も実装内容に合わせて更新した。
3. `.claude/scripts/test/test_command_position.sh` へ33件、
   `.claude/scripts/test/test_post_issue_create_notice.sh` へ5件のテストケースを追加した。

## 敵対的レビュー（1回目・計画レビュー）で判明した設計変更

初版の計画は次の欠陥を持っていた（詳細は個別作業計画「敵対的レビュー（1回目）を踏まえた
設計改訂」節）。

- **sticky（`_CP_PREFIX_WORDS`）が次のセパレータまで解除されず、`sudo cat <path>` /
  `if grep -q x <path>; then...` / `timeout 5 grep -rn x <path>` のような、無関係な
  コマンドの引数に現れるだけのケースで誤発火する。**
  → prefix word通過後は「次の非オプション・非代入トークンを実コマンドとして1回だけ判定し、
  そこでコマンド位置を終える」設計へ変更した。
- **`${VAR}/path` のようなパラメータ展開の直後で誤発火する**（`{`/`}` を人工的な空白挿入の
  対象に含めていたため、`}` の直後がコマンド位置と誤認識されていた）。
  → `_cp_scan_tokens_for_script` の人工的な空白挿入から `{`/`}` を除外した（ブレースグループ
  `{ cmd; }` は素の空白分割で判定できるため、検知は失われない。既存の`_cp_scan_tokens`
  （git専用）は変更していない）。
- **`eval`/`bash -c` 経由の保守的フォールバックが設計に無く、既存の部分一致より検知が
  後退する。** → `command_invokes_git_subcommand` と同じ `_CP_OPAQUE_FOUND` フォールバックを
  追加した。
- **3段ガードを `main()` 内で定義する案は、`source`して`main()`を実行せず
  `is_issue_create_call`を直接呼ぶ既存テスト4件を落とす。** → トップレベルで一度だけ
  確定させる設計へ変更した。

## 既知の制約（受容し回帰テストで固定）

- **クォートで囲まれたスクリプトパス**（`bash "$VAR/create-issue.sh"` 等）は検知できない。
  クォート内容は正規化でプレースホルダへ潰れるため（issue #53のクォート内非発火の設計と
  表裏一体の構造的制約）。
- **PowerShell経路でのバックスラッシュ区切りパス**（`.claude\scripts\src\create-issue.sh`）は
  検知できない。`CommandPosition.sh`の正規化がバックスラッシュをbashのエスケープとして解決し、
  パス区切りごと失われるため。`block-direct-git-commit.sh`も共有する既存の制約であり、
  本issueが新たに生んだ後退ではない。

いずれも「発火しない（見逃す）」側に倒れるだけで、本hookはブロックではなく注意喚起の注入
のみのため実害は小さい。

## 検証結果

```
$ bash -n .claude/hooks/lib/CommandPosition.sh && echo OK
OK
$ bash -n .claude/hooks/post-issue-create-notice.sh && echo OK
OK
$ bash .claude/scripts/test/test_command_position.sh
passed=108 failures=0
$ bash .claude/scripts/test/test_post_issue_create_notice.sh
passed=36 failures=0
$ bash .claude/scripts/test/test_block_direct_git_commit.sh
passed=27 failures=0
$ git diff <ブランチ分岐点0aa9874> -- .claude/hooks/lib/CommandPosition.sh | grep -E '^-[^-]'
（削除行なし。既存関数への影響が無いことを確認）
```

## issueの受け入れ条件との対応

| 受け入れ条件 | 結果 |
|---|---|
| 発火しないこと（cat/grep/ドキュメント編集、コメント内、ヒアドキュメント本文内の言及） | 満たす（テストで確認） |
| 発火すること（単体実行、`cd … && …`、改行区切りの2行目、`bash <パス>` 形式） | 満たす（テストで確認） |
| `CommandPosition.sh` を再利用し、任意のスクリプト名を判定する公開関数を足す | `command_invokes_script` を追加 |
| bashバージョン・`source`の成否・`declare -F`の3段ガードで、満たさない場合は部分一致へ縮退 | `_pin_cli_match`（トップレベル）で実装 |
| `test_post_issue_create_notice.sh`へケース追加、全件`failures=0` | 満たす |
| `command-position.md`「未決定事項・懸念点」・`issue-mr-workflow.md`「既知のトレードオフ」の更新 | 未実施（フェーズ4で対応） |

## 残課題

- spec更新（フェーズ4で実施）。
- 敵対的レビュー（実装レビュー・2回目）の結果反映（本レポート作成時点で結果待ち）。
