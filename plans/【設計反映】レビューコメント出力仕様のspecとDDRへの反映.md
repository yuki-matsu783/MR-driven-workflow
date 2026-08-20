---
title: 【設計反映】レビューコメント出力仕様のspecとDDRへの反映
type: plan
description: issue #43 の実装内容を .claude/docs/spec/ と .claude/docs/ddr/ へ反映する個別反映計画
tags: [plan, docs, spec, ddr]
keywords: [spec, DDR, 断面, ソーススライス, changelog, 影響範囲, 提供関数表]
---

# 個別反映計画: レビューコメント出力仕様のspecとDDRへの反映

全体作業計画: `plans/issue43-review-comment-source-slice.md`（issue #43）
作業結果: `reports/2026-08-20_issue43-review-comment-source-slice_ソーススライス化の実装結果.md`

**`【AIアセット反映】` と分けている**（`.claude/skills/issue-mr-flow/SKILL.md`「種別を複数併記する
場合／分ける場合」）。正史ドキュメントへの記録と、運用ルールの改訂は要求される判断の種類が違う。

## 反映対象の洗い出し（flow-id 4-1）

| # | ファイル | 反映内容 | 種別 |
|---|---|---|---|
| 1 | `.claude/docs/spec/issue-mr-workflow.md` | 提供関数表の `get_mr_unresolved_comments` 行の書き換え、`get_mr_review_threads` / `read_file_at_ref` の追加 | 設計反映 |
| 2 | 同上 | 内部ヘルパーの説明（`gitlab_format_discussion_notes` → `gitlab_normalize_discussions` / `github_normalize_review_threads` / `format_review_comments` / `slice_source_lines` / `truncate_bytes_to_reply`） | 設計反映 |
| 3 | 同上 | **新節「レビューコメントのソーススライス」**（正規化JSONの形・出力書式・断面のフォールバック4段階・上限の既定値と根拠） | 設計反映 |
| 4 | 同上 | 「影響範囲」へ issue #43 のchangelogエントリを**追記**する | 設計反映 |
| 5 | `.claude/docs/ddr/0059-*.md` | 断面をコメント時点のshaにする判断（issue受け入れ条件6） | 設計反映 |
| 6 | `.claude/docs/README.md` | DDR一覧へ 0059 を追記 | 設計反映 |
| 7 | `.claude/docs/spec/adversarial-review.md` | 現在の状態を説明する箇所の関数名（`gitlab_format_discussion_notes` → `gitlab_normalize_discussions`）と、投稿したスレッドの取得例の書式 | 設計反映 |
| 8 | `.claude/skills/issue-mr-flow/SKILL.md` | `comments` サブコマンドの「該当diffを含む」→「ソーススライスを含む」、MCP対応表へ「MCP経路はスライスを作れない」注記 | **AIアセット反映**（別計画） |
| 9 | `.claude/rules/shell-script-style.md` | 「`REPLY` へ返す」の動機に**戻り値が複数ある場合**を追記、jqフィルタへ生の制御文字を書かない注記 | **AIアセット反映**（別計画） |

**フェーズ4は省略しない**（反映対象が7件ある）。

## やること（この計画の範囲は #1〜#7）

### spec: 提供関数表（#1）

```
| `get_mr_unresolved_comments <n> [true]` | レビューコメント／スレッドを取得し、
  **指摘行前後のソーススライス（絶対行番号付き）を添えて**テキストへ整形する。… |
| `get_mr_review_threads <n> [true]` | レビュースレッド＋通常コメントを**正規化JSON**で返す |
| `read_file_at_ref <sha> <path>` | 指定commit時点のファイル内容をプロバイダのAPIから読む |
```

### spec: 新節（#3）

`## 仕様` 配下へ置く。既存の「セッション開始時の自動コンテキスト注入」等と同じ粒度で、
次を書く。

- 正規化JSONのスキーマと、`line` / `sha` を**プロバイダ層で解決する**理由
- 出力書式（行頭は変えない・スライスはスレッドにつき1回・見出しの注記）
- 断面のフォールバック4段階
- 上限の既定値（10行 / 2,000B）と、**バイトを併用する根拠**（実測の13.1倍のばらつき）
- MCP経路ではスライスを作れないこと（GitHub MCPサーバー側の制約）

### DDR 0059（#5）

タイトル案: `0059-レビューコメントのソース断面はコメント時点のshaを優先し現HEADへ縮退する.md`

- 決定: コメント時点のsha優先、取れなければ現HEADへ縮退し**その旨を出力へ明示する**
- 却下案: (a) 常に現HEAD（実装は単純だがレビュアーが見た内容とずれる）、
  (b) 常にコメント時点のshaで、取れなければソースを出さない（shallow cloneで無出力になりうる）
- 併せて記録する判断: diffHunkを捨てて `(path, line, sha)` を共通項にしたこと、
  上限をバイトでも掛けること

## やらないこと

- **過去のchangelogエントリ（`## 影響範囲` 配下の issue #48 / #42 / #77 の節）の書き換え**。
  `gitlab_format_discussion_notes` という名前がそこに残るのは正しい（当時の記録であり、
  `.claude/rules/docs-workflow.md`「ファイル移動に伴うパス参照の一括置換は…changelogを対象に
  含めない」と同じ理由）。名前を直すのは**現在の状態を説明する節**だけにする。
- DDRの既存本文の変更（追記のみ可）。
- AIアセット（`.claude/skills/` `.claude/rules/`）の変更。別計画で行う。

## 検証

- `bash .claude/scripts/src/extract-frontmatter.sh .` が通り、新規DDRがインデックスへ載る。
- `bash .claude/scripts/src/search-frontmatter.sh --type ddr` で 0059 が引ける。
- DDR番号 0059 が `main` 側と衝突していないこと（flow-id 5-1 で再確認する）。
- 相互参照（spec ↔ DDR ↔ SKILL.md）のリンク切れが無いこと。
