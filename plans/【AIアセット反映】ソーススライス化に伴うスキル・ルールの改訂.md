---
title: 【AIアセット反映】ソーススライス化に伴うスキル・ルールの改訂
type: plan
description: issue #43 の作業中に気づいたルール・スキルの不備を .claude/skills/ と .claude/rules/ へ反映する個別反映計画
tags: [plan, ai-asset, rule, skill]
keywords: [SKILL, rules, REPLY, 制御文字, MCPフォールバック, comments, ソーススライス]
---

# 個別反映計画: ソーススライス化に伴うスキル・ルールの改訂

全体作業計画: `plans/issue43-review-comment-source-slice.md`（issue #43）
作業結果: `reports/2026-08-20_issue43-review-comment-source-slice_ソーススライス化の実装結果.md`

**`【設計反映】` と分けている**（`.claude/skills/issue-mr-flow/SKILL.md`「種別を複数併記する
場合／分ける場合」）。設計反映を完了・レビューしてから、こちらに着手する。

## 反映対象

### 1. `.claude/skills/issue-mr-flow/SKILL.md`

| 箇所 | 反映内容 |
|---|---|
| `comments` サブコマンド 手順2 | 「（ファイルパス・行番号・スレッドID・**該当diff**を含む）」→「**指摘行前後のソーススライス（絶対行番号付き）**を含む」。スライスがスレッドにつき1回であることも書く |
| MCPフォールバック対応表 `get_mr_unresolved_comments` の行 | **MCP経路は `line` も commitのsha も返さないため、ソーススライスを作れない**（`path` までは分かる）ことを明記する。実測で確認済み |

**なぜスキルへ書くか**: `comments` を呼ぶのはAIエージェントであり、出力に何が含まれるかの
説明が古いままだと「diffが出るはず」と思って探す。MCP経路の制約も、書いていないと
「取得に失敗した」と誤認して再試行することになる。

### 2. `.claude/rules/shell-script-style.md`

| 節 | 追記内容 |
|---|---|
| 「外部プロセス起動のコスト」の `REPLY` の項 | **`REPLY` へ返す形が要るのは性能のためだけではない**。戻り値が複数ある関数（内容＋メタ情報）をコマンド置換で受けると、**サブシェルへforkするため副次的なグローバルが呼び出し元へ伝わらない**。issue #43 で `REVIEW_SOURCE_REF: unbound variable` として実際に踏んだ |
| 「AIエージェント向け注記」（文字コード節） | **jqのフィルタへ生の制御文字を書かない**（`startswith("<0x1F>")` はjqとしては動くが、ツール経由のコマンド組み立てで弾かれ、diffでも見えない）。`"\u001f"` のエスケープを使う。issue #43 で実際に踏んだ |

**なぜルールへ書くか**: どちらも「一度踏むまで気づけず、踏んだときの症状が原因から遠い」型の
失敗である。`REPLY` の項は既に存在するが**動機が性能としてしか書かれておらず**、戻り値が
複数ある場面では読み手が「ホットパスではないから標準出力でよい」と判断してしまう。

## やらないこと

- `.claude/rules/docs-workflow.md` / `.claude/rules/git-workflow.md` の変更（今回の作業で
  不備は見つかっていない）。
- `.claude/agents/issue-mr-resume.md` の変更。未解決件数の数え方は行頭書式に依存しているが、
  **その書式を変えていない**ため記述は正しいまま。
- 新しいスキルの追加。

## 検証

- `bash .claude/scripts/src/extract-frontmatter.sh .` が通る。
- SKILL.md の該当箇所を読み直し、「出力に何が含まれるか」の説明が実装と一致していること。
- ルール追記の前後3行を目視し、空行が2つ続いていないか・次の見出しの直前に空行が1つあるかを
  確認する（`.claude/rules/docs-workflow.md`「既存ドキュメントへ新しい見出しを差し込むとき」）。
