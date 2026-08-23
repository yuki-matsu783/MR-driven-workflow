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

## 敵対的レビュー（2回目・実装レビュー）で判明した実装バグと修正

diff全体（`CommandPosition.sh`・`post-issue-create-notice.sh`・テスト2本）を対象に、実装
そのものの正しさを重視したレビューを実施し、8件の指摘（major 3件・minor 4件・nit 1件）を
受けた。すべて実機で再現を確認したうえで修正した（詳細は
`worklog/…push3.md`）。

| # | 重大度 | 指摘 | 対応 |
|---|---|---|---|
| 1 | major | prefix語（sudo/timeout等）が値を取るオプションを持つと、値を実コマンドと誤認し検知漏れする（`timeout 60 bash <path>`がmiss） | `_CP_PREFIX_OPTS_WITH_VALUE`・`_CP_PREFIX_WORDS_WITH_LEADING_VALUE`を追加し、値トークンを読み飛ばすよう修正 |
| 2 | major | クォート付きパス（`bash "$VAR/create-issue.sh"`）が検知できず、旧・部分一致実装に対する機能後退になっている | インタプリタ直後の引数がプレースホルダ`_`に潰れている場合、保守的フォールバック（部分一致）の対象にするよう修正。**既知の制約からは削除**（下記） |
| 3 | major | トップレベルでのsourceが前置フィルタより前に毎回走り、issue #159の最適化を一部戻している（実測+35%/+1.0ms） | `_pin_cli_match`の初期化を初回呼び出しまで遅延させる形に変更（関数の存在はトップレベルのまま） |
| 4 | minor | `bash -n <script>`（構文チェックのみ）を実行とみなして誤検知する | シェル系インタプリタ限定で`-n`を検知対象から除外 |
| 5 | minor | target一致判定が変数代入判定より前にあり、`SCRIPT=<path>/create-issue.sh`を実行と誤認する | 判定順序を入れ替え |
| 6 | minor | ヘッダコメント「見逃しだけ」の記述が実装と食い違う（過検知も残る） | コメントを書き直し、`find`等による過検知の残存を明記。回帰テストを追加 |
| 7 | minor | 3段ガードのフォールバック経路（ライブラリ非存在時）を検証するテストが無い | `lib/`無しの一時ディレクトリでサブプロセス起動するテストを追加 |
| 8 | nit | 新規テスト名が既存git側ケースと重複 | 「script判定: 」接頭辞へ改名 |

## 既知の制約（受容し回帰テストで固定）

- **PowerShell経路でのバックスラッシュ区切りパス**（`.claude\scripts\src\create-issue.sh`）は
  検知できない。`CommandPosition.sh`の正規化がバックスラッシュをbashのエスケープとして解決し、
  パス区切りごと失われるため。`block-direct-git-commit.sh`も共有する既存の制約であり、
  本issueが新たに生んだ後退ではない。

**クォートで囲まれたスクリプトパスは、上記2回目レビューの対応により検知できるようになった**
（インタプリタ直後の引数がプレースホルダに潰れている場合の保守的フォールバック）。ただし
これは位置判定そのものがクォート内容を読めるようになったわけではなく、インタプリタを介さない
起動形式では依然として見逃しうる。

**誤検知（過検知）も残ることが2回目レビューで判明した。** コードを文字列として受け取りうる
実行系（`eval`/`xargs`/`find`/`ssh`/`watch`/`flock`等）がコマンド位置にある場合は保守的に
部分一致へ倒すため、`find . -name create-issue.sh`のような検索コマンドでも発火する。本hookは
ブロックではなく注意喚起の注入のみのため、見逃し・過検知のどちらへ倒れても実害は限定的だが、
「必ず見逃し側に倒れる」という当初の説明は不正確だったため、ヘッダコメントを訂正した。

## 検証結果

1回目レビュー反映時点（push2）:

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

2回目レビュー反映時点（push3。上記「敵対的レビュー（2回目・実装レビュー）」節の8件を反映後）:

```
$ bash -n .claude/hooks/lib/CommandPosition.sh && echo OK
OK
$ bash -n .claude/hooks/post-issue-create-notice.sh && echo OK
OK
$ bash .claude/scripts/test/test_command_position.sh
passed=118 failures=0
$ bash .claude/scripts/test/test_post_issue_create_notice.sh
passed=38 failures=0
$ bash .claude/scripts/test/test_block_direct_git_commit.sh
passed=27 failures=0
$ git diff <ブランチ分岐点> -- .claude/hooks/lib/CommandPosition.sh | grep -E '^-[^-]' | wc -l
0
# _cp_scan_tokens / command_invokes_git_subcommand（git専用・既存）がbyte-identicalであることも確認済み
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

- spec更新（フェーズ4で実施。`command-position.md`4箇所・`issue-mr-workflow.md`「既知の
  トレードオフ」）。
- フェーズ3の敵対的レビューは2回実施済み（最大3回）。3回目を追加で回すかは、今回の修正が
  レビュー指摘への対応（新規設計要素の追加ではない）であることを踏まえて判断する。
