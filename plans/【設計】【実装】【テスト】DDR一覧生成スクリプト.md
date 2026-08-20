---
title: 【設計】【実装】【テスト】DDR一覧生成スクリプト
type: plan
description: generate-ddr-list.shの入出力・注記の扱い・マーカー方式・単体テスト範囲を定めた個別作業計画（issue #135）
tags: [ddr, script, test, plan]
keywords: [generate-ddr-list, マーカー, note, superseded, awk, 単体テスト, --check, README, frontmatter]
---

# 【設計】【実装】【テスト】DDR一覧生成スクリプト

issue #135 / 全体作業計画: `plans/ddr-list-generation.md`

**このファイルには結果を書かない**（結果は `reports/20260820_ddr-list-generation_DDR一覧生成スクリプトの実装結果.md`）。

## 1. スクリプトの仕様

`.claude/scripts/src/generate-ddr-list.sh`

```
generate-ddr-list.sh [--check] [--print] [--ddr-dir <パス>] [--readme <パス>]
                     [--link-prefix <文字列>] [-h|--help]
```

- 既定動作: `.claude/docs/README.md` のマーカー区間を、生成した一覧で置き換える。
- `--check`: 書き換えず、再生成すると差分が出るかだけを判定する（差分ありで終了コード1）。
- `--print`: 書き換えず、生成した一覧を**そのまま**stdoutへ出す（JSONは出さない）。
- 既定・`--check` ではstdoutへJSONサマリを出す（`cleanup-task.sh` と同じ規約）。
  人間向けの進捗ログはstderr。

### マーカー

READMEに次のHTMLコメントを置き、**その間だけ**を置き換える。マーカーが片方でも無ければ
エラーで停止する（区間を推測しない）。

```
<!-- BEGIN GENERATED: ddr-list -->
<!-- END GENERATED: ddr-list -->
```

### 対象ファイルと並び順

- `.mrworkflow.json` の `ddrDirs[0]` 配下の `*.md` すべて。
- 並び順は**ファイル名の昇順**（`LC_ALL=C`）。現在の4桁ゼロ埋め連番ではこれが番号順と一致する。

### 出力する行

```
- [<ファイル名>](<link-prefix><ファイル名>)<注記>
```

`<注記>` は次を**この順**で連結する（無ければ何も付けない）。

| 由来 | 出力 |
|---|---|
| `status: superseded` + `superseded_by: "NNNN"` | 半角スペース＋`──`＋太字で `status: superseded`（NNNNにより置き換え） |
| `status: deprecated` | 同上の体裁で `status: deprecated` のみ |
| `note: <散文>` | `（<散文>）` |

### 散文注記（`note`）

現在READMEにしか無い2件をDDRのfrontmatterへ移す。frontmatterのみの更新はDDR本文不変の
運用に反しない（`.claude/rules/markdown-frontmatter.md`）。

- `0022-…` … 「うち『Gemini CLI対応の扱い』は、issue #97で…詳細は0054」
- `0048-…` … 「ファイル名の `flow-id5-1` は当時の番号。…DDR 0056 参照」

**本文は1文字も変えない。既存の注記文言も変えない**（等価性が受け入れ条件のため）。

### 性能

frontmatterの抽出は**awk 1回**で全ファイルを処理する（`.claude/rules/shell-script-style.md`
「外部プロセス起動のコスト」。ファイル数に比例して外部コマンドを起動しない）。

## 2. テスト

`.claude/scripts/test/test_generate_ddr_list.sh`

- 純粋関数（注記の組み立て・リンク行の組み立て・マーカー区間の探索）を `source` して直接呼ぶ。
- 一時ディレクトリに擬似DDRを置き、`main` の生成結果を検証する。
- **このリポジトリ自身に対して `--check` を実行し、差分が出ないこと**を検証する
  （＝生成結果が現在のREADMEと等価であること。issue #135 の受け入れ条件1）。
- 規約どおり `passed=N failures=N` を出力し、失敗時は終了コード1。

## 3. 実施順

1. スクリプト実装 → `bash -n` で構文チェック
2. 0022・0048 のfrontmatterへ `note` 追加
3. READMEへマーカー挿入
4. `--print` の出力を、変更前のREADME区間とdiffして**完全一致**を確認
5. テスト作成 → 実行
