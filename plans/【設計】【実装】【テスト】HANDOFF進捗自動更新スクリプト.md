---
title: 【設計】【実装】【テスト】HANDOFF進捗自動更新スクリプト
type: guide
description: update-handoff-progress.shの詳細設計・実装・テストの個別作業計画
tags: [handoff, automation, shell-script]
keywords: [update-handoff-progress, flow-id, 進捗表, ループ範囲, ヘッダ情報, テスト]
---

# 【設計】【実装】【テスト】HANDOFF進捗自動更新スクリプト

全体作業計画: `plans/shiny-puzzling-umbrella.md`

種別を併記する理由: 設計が小規模（既存の`HANDOFF.md`テキスト構造をそのまま書き換えるだけで、
新規のデータ形式やアーキテクチャ上の選択肢は無い）で、実装方針と一体で判断できるため
（`.claude/skills/issue-mr-flow/SKILL.md`「種別を複数併記する場合／分ける場合」）。

## 対象ファイル

- 新規: `.claude/scripts/src/update-handoff-progress.sh`
- 新規: `tests/test_update_handoff_progress.sh`

## 設計

### HANDOFF.mdの構造（前提）

- ヘッダ部: `- issue: <text>` / `- ブランチ: <text>` / `- PR: <text>` / `- push回数: <n>` の4行。
- 進捗表: `| 進捗 | flow-id | ステップ | 担当 |` ヘッダ＋区切り行＋各flow-idにつき1データ行。
  データ行形式: `| <進捗記号> | <flow-id> | <ステップ説明> | <担当> |`。
- 進捗記号は `[x]`（完了）/ `[]`（未着手・進行中）/ `[-]`（今回は実施しない）。ループ扱いの
  flow-id（後述）は往復回数分 `[]`/`[x]` を連結して持つ（例: `[x][x][]`）。

### ループ範囲テーブル

`.claude/rules/docs-workflow.md` に列挙された6範囲をスクリプト内定数として持つ。

```
2-3 2-4
2-6 2-7 2-8 2-9
3-3 3-4
3-6 3-7 3-8 3-9
4-3 4-4
4-6 4-7 4-8 4-9
```

同じ範囲内のflow-idは常に同じ個数の `[]`/`[x]` を持つ（ドキュメントの既存ルールどおり）ため、
範囲内の1つを操作したら、範囲内の全flow-id行に同じ操作を適用する。

### サブコマンド仕様

- **`mark-done <flow-id>`**: 対象行（ループ範囲に属する場合は同じ範囲の全flow-id行）の進捗列の
  **末尾の `[]`** を `[x]` に置き換える。末尾が `[]` でない行（既に `[x]`/`[-]` で終わっている）が
  あればエラー終了する（意図しない二重操作を防ぐ）。
- **`mark-skip <flow-id> [<flow-id>...]`**: 指定した各flow-idの行の進捗列全体を `[-]` に置き換える
  （既存の内容は問わず上書き）。複数指定可（フェーズ丸ごとスキップ用）。
- **`add-round <flow-id>`**: 対象flow-idがループ範囲に属さなければエラー終了する。属する場合、
  同じ範囲の全flow-id行の進捗列**末尾に新しい `[]` を追記**する（次の往復が始まったことを表す）。
  末尾が既に `[]` の行があればエラー終了する（前の往復が完了していない状態での追加操作を防ぐ）。
- **`set-header [--issue <text>] [--branch <text>] [--pr <text>] [--push-count <n>]`**: 指定された
  オプションの項目のみ該当するヘッダ行を書き換える（未指定の項目は現状維持）。
- **`--file <path>`**（全サブコマンド共通、省略時 `HANDOFF.md`）: 操作対象ファイルを切り替える。
  テストからフィクスチャファイルを指定するために使う。
- **`-h`/`--help`**: 使い方を表示する。

### 実装方式

- `mapfile -t lines < "$file"` で全行を配列に読み込み、各行を
  `[[ $line =~ ^\|[[:space:]]*(\[[^\|]*\])[[:space:]]*\|[[:space:]]*([0-9]+-[0-9]+)[[:space:]]*\| ]]`
  で正規表現マッチし、進捗列（`${BASH_REMATCH[1]}`）とflow-id列（`${BASH_REMATCH[2]}`）を取り出す
  （jqは使わない。Markdownテーブル行の文字列置換であり、JSON操作ではないため）。
- 対象flow-idにマッチした行だけ進捗列を書き換え、非対象行はそのまま配列に残す。
- 全行処理後、一時ファイルへ書き出してから `mv` で置換する（`extract-frontmatter.sh` と同様の
  中断耐性パターン）。
- `set-header` は `- issue: ` 等のprefixで始まる行を正規表現で特定し、該当箇所のみ置換する。
- シバン `#!/usr/bin/env bash`、`set -euo pipefail`、BOM無しUTF-8・LF改行
  （`.claude/rules/shell-script-style.md` 準拠）。
- `extract-frontmatter.sh` と同様、ファイル直接実行時のみ `main "$@"` を呼ぶガード
  （`[[ "${BASH_SOURCE[0]}" == "${0}" ]]` 等）を設け、`tests/` から関数をsourceして再利用できる
  構成にする。

### テスト設計

`tests/test_update_handoff_progress.sh`:

- 一時ディレクトリに、ヘッダ部＋代表的な数行（単発ステップ1つ・ループ範囲1つ・スキップ対象1つ）
  のみを持つ簡略版HANDOFF.mdフィクスチャを作る（39行フルセットは不要）。
- `--file <フィクスチャパス>` 経由で各サブコマンドを呼び、結果の該当行を `assert_eq` で検証する。
- カバーするケース: `mark-done`（単発・ループ範囲の同時更新）、`mark-skip`（単発・複数指定）、
  `add-round`（正常系・ループでないflow-idへのエラー・末尾が`[]`でない時のエラー）、
  `set-header`（一部項目のみ更新）。
- `.claude/rules/shell-script-style.md`「テスト」の `passed=N failures=N` 規約に従う
  （`tests/test_vcs_provider.sh` を雛形にする）。

## 検証方法

- `bash -n .claude/scripts/src/update-handoff-progress.sh` で構文チェック。
- `bash tests/test_update_handoff_progress.sh` を実行し `passed=N failures=0` を確認。
- 実際の `HANDOFF.md` に対して `mark-done`/`add-round`/`set-header` を試し、`git diff` で意図通りの
  変更か確認する。
