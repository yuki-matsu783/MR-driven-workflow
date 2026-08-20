---
title: 実装結果: コマンド位置判定ライブラリとhookへの適用
type: report
description: CommandPosition.shの実装と3つのhookへの適用、単体テスト・回帰確認の結果
tags: [report, 実装, hooks, issue-53]
keywords: [CommandPosition, 正規化, トークン走査, フォールバック, 単体テスト, 回帰, CR, 受け入れ条件]
---

# 実装結果: コマンド位置判定ライブラリとhookへの適用

- issue: [#53](https://github.com/yuki-matsu783/MR-driven-workflow/issues/53)
- 個別作業計画: `plans/【実装】【テスト】コマンド位置判定ライブラリとhookへの適用.md`
- 調査結果: `reports/2026-08-20_hook-command-position-detection_調査結果.md`

## 変更したファイル

| ファイル | 変更 |
|---|---|
| `.claude/hooks/lib/CommandPosition.sh` | 新規（約300行）。判定ロジック本体 |
| `.claude/scripts/test/test_command_position.sh` | 新規。単体テスト54件 |
| `.claude/hooks/block-direct-git-commit.sh` | 判定を差し替え。`source` ガードを追加。冒頭コメントを実装に合わせて更新 |
| `.claude/hooks/post-push-usage-report.sh` | 判定を差し替え |
| `.claude/hooks/post-push-compact-prompt.sh` | 判定を差し替え |

## 受け入れ条件との対応

| issue #53 の受け入れ条件 | 結果 |
|---|---|
| 判定ロジックを外部コマンド呼び出しを伴わない純粋関数として切り出し、単体テストを追加する | **満たした。** `.claude/hooks/lib/CommandPosition.sh` は外部コマンドを1つも呼ばない（コマンド置換・パイプも含まない）。テストは `.claude/scripts/test/test_command_position.sh`（54件） |
| ブロックされること: 単体実行／`cd src && …`／改行の2行目 | **満たした**（B01・B02・B03） |
| ブロックされないこと: ヒアドキュメント本文／クォート内／地の文／該当文字列を検索する `grep` | **満たした**（A01〜A06。変更前はいずれもブロックされていた） |
| push検知hookにも同じ判定を適用する | **適用した**（2本とも）。ただし `.claude/settings.json` の `if` フィルタは変えていない（下記） |
| 素通りリスクが改善効果を上回るなら対応せずクローズしてよい | **上回らないと判断した**（下記「素通りリスクの評価」） |

**テストの置き場所は `tests/` ではなく `.claude/scripts/test/` にした。** 受け入れ条件の文言は
`tests/` だが、issue #63 以降この機構のテストは `.claude/scripts/test/` へ置くことになっており
（`.claude/rules/directory-structure.md`）、`tests/` はリポジトリに存在しない。issue本文が書かれた
時点の記述が古かったものとみなし、現行のルールに合わせた。

## 素通りリスクの評価

受け入れ条件5は「誤ってブロックを素通りさせるリスクが改善効果を上回ると判断した場合は、
対応せずクローズしてよい」としている。**上回らないと判断した。** 根拠は次の3点である。

1. **クォート除外で新たに開く抜け道を、実装前に列挙して塞いだ。** `bash -c` / `eval` /
   `"$( )"` / ``"` `"`` / `xargs` / `find -exec` の6形。20ケースの実測で、変更前後とも
   すべてブロックされることを確認した（N01〜N05 と単体テスト）。
2. **検知漏れがむしろ1件減った。** `git -C /repo commit` は変更前は素通りしていた（B06）。
   `git` の直後の非オプショントークンで判定する形にしたことで塞がった。
3. **ライブラリを読めない場合は従来の部分一致へ落ちる。** ファイルの欠落・配布漏れで
   検知そのものが無効になることはない。

残る素通りは、**意図的な文字列分割**（`git "commit"` のように、クォートで語を割る形）である。
これは issue #53 の本文・DDR `i0000-09` がともに「対策しない」と明示している範囲であり、
今回の変更で新たに生じたものではない（変更前も `git "commit"` は部分一致に当たらず素通りしていた）。

## push検知hookへの適用（`if` フィルタは変えない）

判定は2本とも差し替えたが、`.claude/settings.json` の `if: "Bash(git push*)"` は**変えていない**。

- `if` を緩めると、いまは届いていない入力までhookが起動するようになる。**発火が増える方向**の
  変更で、誤検知を減らすという本issueの向きと逆である。
- `if` の照合規則（前方一致か部分一致か）は issue #47 が両論併記のまま残しており、本issueでも
  切り分けていない。**未解明の挙動を前提に設定を変えない。**

結果として push側は「`if` で絞ってから、スクリプト内でコマンド位置判定」という二段構えになる。
`if` が届かせた入力のうち、地の文・クォート内・ヒアドキュメント本文しか該当語を含まないものは、
スクリプト側で落ちるようになった。

## 検証結果

### 単体テスト

```
bash .claude/scripts/test/test_command_position.sh
passed=54 failures=0
```

### 回帰（既存テスト全件）

`.claude/scripts/test/` の15ファイルすべてで `failures=0`。合計 829 件。

| テスト | 結果 |
|---|---|
| test_adversarial_review_count.sh | passed=22 failures=0 |
| test_check_base_conflicts.sh | passed=31 failures=0 |
| test_check_base_sync.sh | passed=55 failures=0 |
| test_cleanup_task.sh | passed=53 failures=0 |
| test_collect_review_points.sh | passed=17 failures=0 |
| test_command_position.sh | passed=54 failures=0 |
| test_extract_frontmatter.sh | passed=32 failures=0 |
| test_generate_ddr_list.sh | passed=52 failures=0 |
| test_install_to_project.sh | passed=22 failures=0 |
| test_post_issue_create_notice.sh | passed=14 failures=0 |
| test_search_frontmatter.sh | passed=114 failures=0 |
| test_session_start.sh | passed=51 failures=0 |
| test_update_handoff_progress.sh | passed=45 failures=0 |
| test_usage_tracking.sh | passed=90 failures=0 |
| test_vcs_provider.sh | passed=177 failures=0 |

### hookへ直接JSONを流す20ケース

変更前は7件が期待と食い違っていた（誤検知6・検知漏れ1）。**変更後は20件すべて期待どおり**。
内訳は調査結果の表を参照。

### CR混入下での再実測

`.claude/rules/shell-script-style.md`「テスト」節のスタブ `jq`（最終行以外の行末へCRを付ける）を
PATHの先頭へ置いて同じ20ケースを流し、**CRなしのときと1件も結果が変わらないこと**を確認した。
`tr -d '\r'` は足していない（forkを増やさずに済んでいる）。

### push検知hookの健全性

`CLAUDE_PROJECT_DIR` を与えない状態で push を含むペイロードを流し、2本とも `exit 0` で
標準エラーへ何も出さずに終わることを確認した（判定部分で `set -u` 由来のエラー等が出ていない）。

### 性能

判定部分だけの比較（200回あたり、同一セッション・空関数をベースライン）:

| 入力 | 空関数 | 旧（`printf \| grep`） | 新（純粋bash） |
|---|---|---|---|
| 短い1行（31バイト） | 4ms | 432ms | 98ms |
| ヒアドキュメント（18225バイト） | 23ms | 480ms | 1450ms |

hook全体（該当語を含まない通常のコマンド、50回）は 865ms → 833ms。残りはjqの3回呼び出しが
支配している。**Windows / git bash では未実測**（fork回数が 2 → 0 になることはコードから
確定するが、所要時間の比は測れていない）。

## 実装中に踏んだこと

| 症状 | 原因 | 対処 |
|---|---|---|
| バックスラッシュが文字集合から落ちる | ブラケット式をダブルクォートの中へ直接書くと、`\\` と `\'` の解釈がシェルとパターン照合で二重にかかる | パターンを `$'...'` で組み立てた変数に置き、**クォートせず**に展開する |
| `<<<"str"` をヒアドキュメントと誤認 | `<` を1文字ずつ返していたため、残った `<<` を次の走査が拾った | `<<<` は3文字まとめて消費する |
| 受け入れ条件の A02 が落ちる | `bash` を無条件のフォールバック対象にしていた | コード指定オプション（`-c` 等）と併用時のみ対象にする |
| `sudo -u alice git commit` が素通り | 透過的なラッパーの直後1トークンだけをコマンド位置扱いにしていた | 次のセパレータまでコマンド位置を保つ（sticky）形へ変更 |
| `echo "$(git commit)"` が素通り | ダブルクォート内から入ったコード区間の開始が、セパレータとして出力されていなかった | `$(` の突入時に `(` を、`` ` `` の突入時に `` ` `` を出力する |

**この作業の最中に2回、自分でブロックを踏んだ。** デバッグ用スクリプトのコメントと、修正パッチの
説明コメントに該当語が地の文として含まれていただけである（issue本文が挙げた「hookの仕組み自体を
説明する文章を書く場面で踏みやすい」の再現）。回避は既存ルールどおり「本文をファイルへ書いてから
実行する」で、**この変更が入ったあとは、同じ書き方をしてもブロックされなくなる**。

## 確かめられなかったこと

- **Windows / git bash 実機での動作と性能。** ロジックは純粋bashでプラットフォーム依存の
  構文を使っていないが、実機確認はしていない。
- **`.claude/settings.json` の `if` フィルタの照合規則**（issue #47 から未解明のまま）。
- 実運用の中での誤検知の残存。20ケースは代表例であって網羅ではない。
