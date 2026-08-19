---
title: 【設計反映】create-commitの仕様とパス分類方針の記録
type: plan
description: create-commit.shのspec新規作成とDDR 0029で、失敗時分類方式の採用と-A案の却下理由を記録する個別反映計画
tags: [issue-60, 設計反映, create-commit, ddr]
keywords: [spec, DDR 0029, create-commit, pathspec, 削除ステージ済み, git add -A, 却下案, README]
---

# 【設計反映】create-commitの仕様とパス分類方針の記録

- issue: [#60](https://github.com/yuki-matsu783/MR-driven-workflow/issues/60)
- 全体作業計画: `plans/cheeky-baking-lantern.md`
- 対象flow-id: 4-6（1周目）

## 目的

フェーズ2の調査結果とフェーズ3の実装内容を、`.claude/docs/spec/` `.claude/docs/ddr/` へ
「現在の正史」「意思決定の記録」として反映する。

**`.claude/docs/spec/create-commit.md` の作成は必須である。** 実装したエラーメッセージが
`詳細: .claude/docs/spec/create-commit.md` と出力するため、これが無いと参照先の無いメッセージに
なる（同一PR内で揃える必要がある）。

## 作業内容

### 1. `.claude/docs/spec/create-commit.md` を新規作成する

`commit` スキル専用ラッパーの正史仕様。構成は既存の
`.claude/docs/spec/update-handoff-progress.md` に倣う。

| 節 | 内容 |
|---|---|
| 背景・目的 | PreToolUse hook（`block-direct-git-commit.sh`）を正規経路だけ迂回するためのラッパーであること（DDR 0012からの引き継ぎ）。issue #60で削除を含むコミットが完結しなかったこと |
| 仕様 | 引数（`--message` 必須・`--` 以降1件以上必須）／終了コード／`--amend` `--no-verify` 等を持たない理由 |
| パスの扱い | **削除済みパスはそのまま渡してよい**。`git add` を先に試し、失敗したときだけ add / skip / unknown に分類する。分類の判定条件（worktree・index・HEAD のどこにあるか）と、それぞれの出力 |
| 失敗条件 | 「worktree にも index にも無いパス」が唯一の失敗条件であること。想定される原因（削除を先にステージした／未追跡のまま削除した／綴り誤り・8進エスケープ表記のコピー）を**ここに集約する**（エラーメッセージ側には書かない） |
| 設計判断 | 正常系のコードを変えない構造にした理由、pathspec解釈をgitへ委ねる理由、`git add` のpathspec検証が原子的であること |
| 影響範囲 | issue #60 の変更点をchangelogエントリとして記載 |

**フェーズ2で実測した git の挙動のうち、仕様の根拠になるものを明記する**
（`git add --` は追跡済みファイルの削除をそのままステージする／pathspecは worktree と index の
両方に対して照合される／pathspecが1件でも不一致なら何もステージしない）。バージョン
（git 2.39.2.windows.1 / git bash）も併記する。

### 2. `.claude/docs/ddr/0029-...md` を新規作成する

タイトル案: `0029-create-commitは削除ステージ済みパスをgit-addの失敗時分類で吸収する.md`

記録する意思決定と却下案:

| | 内容 |
|---|---|
| 採用 | `git add` を先に試し、**失敗したときだけ**パスを3分類して回復する |
| 却下1 | **issue本文が提案していた `git add -A -- "${files[@]}"`** — 症状（削除ステージ済みパスの失敗）を直さないうえ、pathspecが空のときリポジトリ全体をステージする副作用がある。フェーズ2の実測値を根拠として残す |
| 却下2 | **常に分類してから `git add` へ渡す**（フェーズ3の当初案） — 分類をパス文字列で行うため、ディレクトリごと削除された `reports/` をディレクトリ指定で渡すと UNKNOWN になり機能後退する |
| 却下3 | **2段構えの回避策を明文化するだけ**（コード変更なし） — 正規経路で完結しないという問題の本質が残る |

**issueの提案をそのまま実装しなかった判断であるため、DDRとして残す価値が高い**。
「issue本文の前提（削除済みパスは渡せない）自体が再現しなかった」ことも明記する。

### 3. `.claude/docs/README.md` を更新する

- spec一覧に `create-commit.md` の行を追加する
- DDR一覧に `0029-...` の行を追加する

## 検証

- 新規2ファイルにOKF frontmatter（`title`/`type`/`description`/`tags`/`keywords`）を付ける
  （`type` は `spec` / `ddr`）
- `bash .claude/scripts/src/extract-frontmatter.sh .` が通ること（必須ではないが確認する）
- `create-commit.sh` のエラーメッセージが参照するパスと、実際に作成したファイルのパスが一致すること
- DDR番号 0029 が `main` 側で先に使われていないこと（マージ順によっては繰り下げる）

## やらないこと

- `.claude/skills/commit/SKILL.md` `.claude/rules/git-workflow.md` の更新
  （`plans/【AIアセット反映】削除済みパスの扱いをcommitスキル・git-workflowへ反映.md` で扱う）
- DDR 0012（コミットはcommitスキル経由を機構的に強制する）の本文変更
  （DDRの本文は不変。今回の決定はその制約下での実装詳細であり、0012を無効化しない）
