---
title: 【実装】【テスト】ハイフン始まりfrontmatter要素のjq失敗修正
type: log
description: extract-frontmatter.shがハイフン始まりのfrontmatter要素でjqに失敗しindex.jsonlから欠落する不具合（issue #69）の修正計画
tags: [extract-frontmatter, jq, index-jsonl, bugfix]
keywords: [frontmatter, jq, --args, ハイフン, index.jsonl, 位置引数, 終了コード, 回帰テスト, yq, rawfile]
---

# 【実装】【テスト】ハイフン始まりfrontmatter要素のjq失敗修正

対象: issue #69。`.claude/scripts/src/extract-frontmatter.sh` の `run_fm_jq` が、frontmatterの
中間表現を `jq --args` の位置引数として渡す際、`-A` のようにハイフンで始まる要素をjqが
オプションとして解釈して失敗し、該当ファイルが `index.jsonl` から無言で欠落する。

## 現状の把握（実機で再現済み）

```
$ jq -nc --args 'def items: $ARGS.positional; items' 'a' '-A' 'b'
jq: Unknown option -A            # 終了コード2
```

スクリプト全体を流すと、`keywords: [git add, -A, pathspec]` を持つファイルの行が空行になり、
それでも **終了コードは0**、標準エラーに `jq: Unknown option -A` が出るだけで完了する。
原因は `run_fm_jq` が `jq ...` の直後に `return 0` を書いており、jqの終了コードを
握りつぶしていること。

## 方針

1. **`--` の追加（本丸）**: `jq -nc "$@" --args "<フィルタ>" -- "${FM_ITEMS[@]}"` とし、
   `--` 以降をすべて位置引数として扱わせる。issue本文に記載の確認どおり、jq 1.7で
   `["a","-A","b"]` が得られることを実機確認済み。要素が0個でも `[]` になり、要素自体が
   `--` であっても2つ目以降はそのまま位置引数として扱われることも確認した。
2. **終了コードを握りつぶさない**: `run_fm_jq` は `status=0; jq ... || status=$?; return "$status"`
   の形でjqの終了コードを伝播する（`--rawfile` 側も同様。`rm` の終了コードで上書きされていた）。
3. **失敗を可視化する**: `main()` は `build_index_line` の失敗を検知したら、
   **空行を書かずにスキップ**し `error: failed to build index line: <パス>` を標準エラーへ出す。
   サマリへ `failed=<数>` を加え、1件でも失敗があれば非ゼロ終了する。
   （`index.jsonl` 自体は生成できた分だけ書き出す＝1ファイルの失敗で全体が止まらない。
   SessionStart hookは `regenerate_frontmatter_index || true` でfail-openのため影響しない）

### 検討したが採らなかった案

- **常に `--rawfile` 経路を通す**: ハイフン問題は消えるが、`mktemp` の分だけ外部プロセス起動が
  1ファイルあたり1回増える。git bashでは約95ms/回と重く、`.claude/rules/shell-script-style.md`
  「外部プロセス起動のコスト」の方針に反する。
- **要素側をエスケープする（先頭に印を付けてjq側で剥がす）**: 変換・復元の両方に手が入り、
  中間表現の仕様が複雑になる。`--` で足りるため採らない。

## やること

- [x] `run_fm_jq` に `--` を追加し、終了コードを伝播させる
- [x] `main()` に失敗時のスキップ・`failed=`・非ゼロ終了を追加する
- [x] `.claude/scripts/test/test_extract_frontmatter.sh` に回帰テストを追加する
  - フロー配列 `[git add, -A, pathspec]` / ブロック配列 `- -A` `- --force` `- -` / スカラー `title: -A`
  - `--rawfile` 経路（引数長上限超え）でもハイフン始まり要素が保持されること
  - `run_fm_jq` がjqの失敗を非ゼロで返すこと
  - `yq` の有無で結果が変わらないこと（jq/mktempのみを置いたディレクトリをPATHにして再現）
- [x] 修正を戻すとテストが落ちることを確認する（テストが回帰を実際に検知できること）
- [x] リポジトリ全体を `--force` で再生成し、既存の `index.jsonl` の内容が変わらないこと（回帰なし）

## 受け入れ条件との対応（issue #69）

| 受け入れ条件 | 対応 |
|---|---|
| ハイフン始まり要素を含むファイルが `index.jsonl` に出力される | 方針1 |
| `yq` の有無にかかわらず同じ結果になる | 自前パーサー側のみの修正。テストでPATHを差し替えて両経路を確認 |
| `--rawfile` フォールバック経路の挙動が変わらない | 位置引数を使わない経路のため無変更。テストで確認 |
| 既存ファイルのインデックス内容が変わらない（回帰なし） | 全体再生成の前後diff |
| `bash -n` が通る | 実施 |
