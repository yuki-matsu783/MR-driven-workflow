---
title: 【設計】【実装】【テスト】extract-frontmatter.shの高速化と中断耐性
type: plan
description: extract-frontmatter.shのjq起動をファイルあたり1回へ削減し、mtimeキャッシュ・原子的更新・単体テストを導入する個別作業計画
tags: [extract-frontmatter, performance, atomic-write, test]
keywords: [extract-frontmatter, index.jsonl, jq, プロセス起動, mtime, キャッシュ, 原子的更新, trap, xargs, stat, 単体テスト]
---

# 【設計】【実装】【テスト】extract-frontmatter.shの高速化と中断耐性

全体作業計画: `plans/lexical-stirring-peach.md`（issue #11 / PR #19）
対象ファイル: `.claude/scripts/src/extract-frontmatter.sh`（改修）、`tests/test_extract_frontmatter.sh`（新規）

## 種別を併記した理由

設計・実装・テストを分けても合意の単位が変わらず記述が重複するだけのため、1ファイルに併記する
（`.claude/skills/issue-mr-flow/SKILL.md`「種別を複数併記する場合／分ける場合」の判断基準による）。
テストは実装と同時に書き、まとめて1回で合意する。

## 設計

### 現行の構造と問題点

`main()` はmarkdown 1ファイルごとに次を行っている。

```
realpath(1) → dirname(2) → frontmatter_to_json(キー/配列要素ごとにjq ≒20-30) → stat(1) → date(1) → jq(1) → tr(1)
```

git bashでは外部プロセス起動が**約95ms/回**（実測: `jq -nc '1'` × 50回 = 4.73秒）のため、
1ファイル約30回 × 43ファイル ≈ 2分に達する。加えて `: >"$out_file"` で**走査中に既存ファイルを
truncateしてから1行ずつ追記**するため、中断すると不完全な `index.jsonl` が残る。

### 改修後の構造

```
main
 ├ 1. 引数解析（--force / -f を追加）
 ├ 2. resolve_repo_root → target_rel を算出 → cd "$repo_root"
 ├ 3. ファイル列挙（git ls-files ... | grep -z '\.md$' | sort -z -u）→ 配列 files
 ├ 4. mtimeを一括取得（xargs -0 stat -c '%Y'）→ 連想配列 file_epoch
 ├ 5. 出力先ごとに既存 index.jsonl を読み、キャッシュを構築（bashのみ・起動0回）
 ├ 6. ファイルごと: キャッシュヒット → 既存行を再利用 / ミス → build_index_line（jq 1回）
 └ 7. 出力先ごと: 内容が変わったものだけ tmp へ書き mv -f で差し替え（trapでtmpを掃除）
```

### 関数構成（責務の分離）

`frontmatter_to_json` の**公開シグネチャと出力は現状のまま維持**する（既存の呼び出し・テスト互換）。
内部を「解析」と「JSON化」に分け、JSON化を1回のjq呼び出しに集約する。

| 関数 | 責務 | 外部プロセス起動 |
|---|---|---|
| `trim` / `unquote` / `extract_frontmatter_block` | **変更なし** | 0 |
| `parse_frontmatter_block`（新規） | stdinのfrontmatter本文を解析し、中間表現をグローバル配列 `FM_ITEMS` に詰める。**行の正規表現・`trim`/`unquote`の呼び方は現行 `frontmatter_block_to_json` と完全に同じ** | 0 |
| `frontmatter_items_to_json`（新規） | `FM_ITEMS` を **jq 1回**でJSONオブジェクト化する | 1 |
| `frontmatter_block_to_json`（既存・内部を置換） | `parse_frontmatter_block` → `frontmatter_items_to_json` の薄いラッパー | 1 |
| `frontmatter_to_json`（既存・変更最小） | yq優先パスはそのまま。フォールバック時に上記を呼ぶ | 1 |
| `build_index_line`（新規） | 1ファイル分の出力行（`concept_id`/`directory`/`frontmatter`/`mtime`）を **jq 1回**で組み立てる。`main` はこちらを使う | 1 |

`frontmatter_items_to_json` と `build_index_line` は同じjqプログラム片（中間表現→オブジェクトへの
`reduce`）を使うため、シェル変数 `JQ_FM_DEF` に定義を1箇所だけ持ち、両者で参照する。

### 中間表現（`FM_ITEMS`）

3要素で1組。`jq --args` の positional 引数としてそのまま渡す。

| 種別 | 意味 | jq側の処理 |
|---|---|---|
| `s` | スカラー（文字列） | `.[$key] = $value` |
| `b` | 真偽値 | `.[$key] = ($value == "true")` |
| `A` | 空配列の初期化（要素0個のリストキー） | `.[$key] = (.[$key] // [])` |
| `a` | 配列要素の追加 | `.[$key] = ((.[$key] // []) + [$value])` |

現行実装の値の扱い（`true`/`false` のみ真偽値、他はすべて文字列、リストは順序保持、要素0個なら
`[]`）と**1対1で対応**させる。jqのオブジェクトは挿入順を保持するため、キーの出現順も現行と一致する。

### 引数長上限への配慮

`.claude/rules/shell-script-style.md` の「大きなJSONを `--arg`/`--argjson` で渡さない」に従い、
`--args` へ渡す総バイト数を組み立て時に見積もり、**閾値（24KB）を超える場合は一時ファイル経由
（`jq --slurpfile` / `--rawfile`）へフォールバック**する。通常のfrontmatterは数百バイトのため
このパスには入らないが、異常に長いfrontmatterでも「起動自体が失敗して原因が見えない」事故
（同ルールに記録済み）を防ぐ。

### mtimeキャッシュ

- 出力先 `index.jsonl` を1行ずつ読み、bashの正規表現で `"concept_id":"..."` と `"mtime":"..."` を
  取り出して連想配列に持つ（jq不使用・起動0回）。読んだ内容は「書き換え要否の判定」にも再利用する。
- 対象ファイルの現在のmtime文字列が既存行の `mtime` と一致すれば、**既存行をそのまま再利用**する。
- **キャッシュの自動無効化**: `extract-frontmatter.sh` 自身のmtimeが `index.jsonl` より新しい場合、
  そのディレクトリはキャッシュを使わず全再生成する（解析ロジックを直したのに古い行が残る事故を防ぐ）。
- `--force` / `-f` 指定時はキャッシュを一切使わない。
- 対象ファイル一覧に無い `concept_id` の既存行は**引き継がない**（削除・リネームされたmarkdownの行が
  残らない。現行の全上書き挙動と同じ結果になる）。

### 原子的更新

- 生成した行は連想配列 `out_lines[<出力先>]` に溜め、**全走査完了後**にまとめて書き出す。
- 書き出しは同一ディレクトリの `index.jsonl.tmp.<PID>` へ行い、`mv -f` で差し替える。
- `trap cleanup EXIT INT TERM` で、中断時に一時ファイルを必ず削除する。
- 既存内容と**完全に一致する場合は書き換えない**（`unchanged: <path>` を標準エラーへ出力）。
  不要なmtime更新・git差分ノイズを防ぐ。
- 現行の `: >"$out_file"`（走査中のtruncate）は**削除**する。

### 起動回数の見積もり

| | 現行 | 改修後（キャッシュ無効） | 改修後（差分なし） |
|---|---|---|---|
| 起動回数 | 約1,300 | 約60（jq 43 + mv/stat/ls-files等） | 約5 |
| 所要時間（95ms/回換算） | **約2分（タイムアウト）** | **約6秒** | **1秒未満** |

## 実装手順

1. **ベースライン計測**: 改修前の `.claude/docs/ddr` 単体・リポジトリルート指定の所要時間を計測し
   worklogへ記録する（ルート指定はタイムアウトする想定のため、`timeout` を付けて打ち切る）。
   計測で `index.jsonl` が変化した場合は `git checkout -- '*index.jsonl'` で必ず復元してから次へ進む。
2. **既知バグの再現確認**: 作業ツリーがクリーンな状態で
   `bash .claude/scripts/src/extract-frontmatter.sh .claude/rules` を実行し、`git status` で
   スコープ外の `index.jsonl` が変更されるか・重複行が生じるかを観測する。結果（再現有無と条件）を
   worklogへ記録する。再現しない場合は「再現せず」を記録し、改修後に同じ手順で再確認する。
3. **改修の実装**: 上記「設計」に沿って `.claude/scripts/src/extract-frontmatter.sh` を書き換える。
   `set -euo pipefail`・BOM無しUTF-8・LF改行・`#!/usr/bin/env bash` を維持する。
   `bash -n` で構文チェックする。
4. **単体テストの新規作成**: `tests/test_extract_frontmatter.sh` を作成する（下記「テスト」参照）。
5. **回帰・性能・中断耐性の検証**: 下記「検証」の手順をすべて実施し、結果をworklogへ記録する。
6. **既知バグの再確認**: 手順2と同じ操作を改修後の実装で行い、解消したかを判定する。

## テスト

`tests/test_extract_frontmatter.sh` を新規作成する。`.claude/rules/shell-script-style.md`「テスト」の
規約に従い、`passed=N failures=N` を標準出力へ出し、失敗があれば終了コード1で終わる。
対象は副作用の無い純粋ロジックに限定し、`index.jsonl` を書き出す処理はテストしない
（スクリプトを `source` し、`main` は呼ばない）。

| # | 対象 | 入力 | 期待 |
|---|---|---|---|
| 1 | `frontmatter_to_json` | スカラーのみ（`title` / `type`） | 各キーが文字列として出る |
| 2 | 〃 | フロー配列 `tags: [a, b, c]` | 3要素の配列。順序保持 |
| 3 | 〃 | ブロック配列（`keywords:` の次行以降に `  - item`） | 要素順を保持した配列 |
| 4 | 〃 | 要素0個のリストキー | `[]`（空配列） |
| 5 | 〃 | ダブルクォート付きの値（`superseded_by: "0019"`） | クォートが外れた文字列 |
| 6 | 〃 | 真偽値（`alwaysApply: true`） | JSONの `true`（文字列ではない） |
| 7 | 〃 | frontmatter無しのファイル | 文字列 `null` |
| 8 | 〃 | CRLF改行のファイル | LFの場合と同じJSON |
| 9 | `resolve_repo_root` | リポジトリ内のディレクトリ | 既存 `.git` を持つディレクトリを返す |
| 10 | `build_index_line` | 一時ディレクトリ上のmarkdown | `concept_id`/`directory`/`frontmatter`/`mtime` の4キーを持つ1行JSON |

テストは一時ディレクトリ（`mktemp -d`）にフィクスチャを作り、終了時に `trap` で削除する。

## 検証（issueの受け入れ条件との対応）

| 受け入れ条件 | 手順 | 合格基準 |
|---|---|---|
| ルート指定の実行が完了する | `time bash .claude/scripts/src/extract-frontmatter.sh .`（`--force` 有／無の2回） | どちらも完走。`--force` 有で概ね10秒以内、無しで数秒以内 |
| 中断しても既存が壊れない | クリーンな状態で `--force` 実行を開始直後に `SIGINT` で中断 → `git status` | `index.jsonl` に差分が無く、`*.tmp.*` が残っていない |
| 生成内容が現行と同一（回帰なし） | クリーンな状態から `--force` で全再生成 → `git diff -- '*index.jsonl'` | 差分が**空** |
| 差分スキップが効く | `touch .claude/docs/ddr/0003-*.md` → 再実行 | 該当ディレクトリのみ `wrote:`、他は `unchanged:`。所要時間が短い |
| 単体テスト | `bash tests/test_extract_frontmatter.sh` | `failures=0`・終了コード0 |
| 構文チェック | `bash -n` を変更した `.sh` 全てに実行 | エラーなし |

回帰検証が最重要。**現在コミット済みの `index.jsonl` 群が現行実装の出力そのもの**であるため、
`git diff` が空であることが「現行と同一の出力」の直接的な証拠になる。

## やらないこと

- `index.jsonl` のスキーマ・フォーマット変更（回帰なしが受け入れ条件のため）。
- frontmatter解析ロジック自体の仕様変更（対応するYAML文法を増やす等）。
- `yq` 優先パスの実機検証（開発機に `yq` が無い状態は変えない）。
- 全ファイルを1回のjqで処理する方式（解析結果の受け渡しに独自エスケープが必要になり、回帰リスクが
  引き合わない。フェーズ4のDDRで却下案として記録する）。
- `index.jsonl` 自動再生成（git hook等）の導入。
