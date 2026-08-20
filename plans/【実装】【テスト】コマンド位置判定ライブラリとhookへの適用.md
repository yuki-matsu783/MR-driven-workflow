---
title: 【実装】【テスト】コマンド位置判定ライブラリとhookへの適用
type: plan
description: コマンド位置判定を純粋関数のライブラリへ切り出し、3つのhookへ適用する個別作業計画
tags: [plan, 実装, テスト, hooks, issue-53]
keywords: [CommandPosition, 正規化, トークン走査, フォールバック, 単体テスト, block-direct-git-commit, post-push]
---

# 【実装】【テスト】コマンド位置判定ライブラリとhookへの適用

- issue: [#53](https://github.com/yuki-matsu783/MR-driven-workflow/issues/53)
- 全体作業計画: `plans/hook-command-position-detection.md`
- 調査結果: `reports/2026-08-20_hook-command-position-detection_調査結果.md`
- フェーズ: 3〈作業〉（flow-id 3-1）

**`【実装】` と `【テスト】` を併記する**のは、テストを実装と同時に書き、まとめて1回で合意を
取る単位だからである（`.claude/skills/issue-mr-flow/SKILL.md`「種別を複数併記する場合／分ける場合」）。
判定ロジックとその期待値表は不可分で、分けると同じ内容を2つの計画へ書くことになる。

## 目的

調査で採用した案 (c)（クォート追跡＋正規化）を実装し、3つのhookの判定を差し替える。

## 変更対象

| ファイル | 変更 |
|---|---|
| `.claude/hooks/lib/CommandPosition.sh` | **新規**。判定ロジック本体（外部コマンドを呼ばない純粋関数） |
| `.claude/scripts/test/test_command_position.sh` | **新規**。上の単体テスト |
| `.claude/hooks/block-direct-git-commit.sh` | 判定を差し替え。`source` 時に本体が走らないガードを追加 |
| `.claude/hooks/post-push-usage-report.sh` | 判定を差し替え |
| `.claude/hooks/post-push-compact-prompt.sh` | 判定を差し替え |

## 方針

### 公開する関数

| 関数 | 役割 |
|---|---|
| `normalize_shell_command_to_reply <cmd>` | クォート・コメント・ヒアドキュメント本文をプレースホルダへ潰し、`REPLY` へ返す |
| `command_invokes_git_subcommand <cmd> <sub>` | `git <sub>` がコマンド位置にあるかを判定する（`0`=該当） |

`*_to_reply` という命名と `REPLY` への返却は `.claude/rules/shell-script-style.md`
「外部プロセス起動のコスト」の規約に従う（コマンド置換で受けるとforkするため）。

### 判定の線引き

- **コマンド位置**とは、文字列先頭・改行直後・`;` `&&` `||` `|` `(` `)` `{` `}` `` ` `` の直後。
- 変数代入（`FOO=bar`）と透過的なラッパー（`sudo` `env` `time` `exec` 等・シェルの予約語）の後は、
  **次のセパレータまで**コマンド位置を保つ（`sudo -u alice git commit` へ対応するため）。
- `git` の直後は、`-` で始まるトークンを読み飛ばして最初の非オプショントークンを見る
  （`-c` / `-C` は値を1つ取るので2つ飛ばす）。

### 素通りを増やさないための保守的フォールバック

位置判定で一致しなかった場合でも、**コード文字列を受け取りうる実行系**がコマンド位置にあり、
かつ従来の部分一致が成立するならブロックする。

- 無条件: `eval` `xargs` `find` `ssh` `watch` `flock` `parallel`
- コード指定オプション（`-c` `-e` `-E` `--command` 等）と併用時のみ: `bash` `sh` `python` `perl` 等

### hook側の差し替え

- ライブラリは `${BASH_SOURCE[0]%/*}/lib/CommandPosition.sh` から `source` する
  （`CLAUDE_PROJECT_DIR` は push検知hookでは判定より後に解決されるため、hook自身の位置を使う）。
- **ライブラリを読めない場合は、従来どおりの部分一致へ落とす。** 検知そのものが無効になるより、
  誤検知が残るほうがましである。

## やらないこと

- **`.claude/settings.json` の `if` フィルタは緩めない。** 発火が増える方向の変更で、本issue
  （誤検知を減らす）とは向きが逆。
- **jq呼び出しの1回化はしない。** 別の関心事（性能）であり、レビュー面を混ぜない
  （調査結果 6 節。別issueとして起票するのが妥当）。
- **`post-issue-create-notice.sh` は対象外。** 同じclassの誤検知を持つが、issue #53 が
  名指ししていない。
- 意図的な文字列分割による回避への対策（DDR `i0000-09`）。

## テスト

`.claude/scripts/test/test_command_position.sh`（`passed=N failures=N` を出力し、失敗時は
終了コード1という既存規約に従う）。

**issue #53 の受け入れ条件は「`tests/` 配下に」と書いているが、`.claude/scripts/test/` へ置く。**
issue #63 以降この機構のテスト置き場はそちらで、`tests/` はリポジトリに存在しないため
（`.claude/rules/directory-structure.md`）。この読み替えはフェーズ4で記録する。

観点は次の4群。

1. ブロックすべき（単体実行・`&&` の右辺・改行の2行目・パイプ・`;`・サブシェル・変数代入前置・
   `sudo`・`if` の条件部・大文字・`git -C` / `git -c`・CR混入・ヒアドキュメントを閉じた後）
2. ブロックすべきでない（ヒアドキュメント本文3種・クォート内・地の文・`grep`・コメント2種・
   ファイル名の一部・別サブコマンド・空文字列）
3. 素通りさせたくない（`bash -c` / `sh -c` / `eval` / `"$( )"` / ``"` `"`` / `find -exec` / `xargs`）
4. 正規化そのもの（クォート・コメント・`#` の語中／語頭・ヒアストリング `<<<`・
   ヒアドキュメント本文・閉じないヒアドキュメント）と、大きな入力での所要時間

## 検証手順

- `bash -n` で5ファイルの構文を確認する。
- `bash .claude/scripts/test/test_command_position.sh` が `failures=0` になること。
- **`.claude/scripts/test/` の全テストが `failures=0` のままであること**（回帰の確認）。
- hookへ直接JSONを流す20ケースの表で、変更前後を突き合わせる。
- CRを付与するスタブ `jq` をPATHの先頭へ置いて、同じ20ケースの結果が変わらないこと。
