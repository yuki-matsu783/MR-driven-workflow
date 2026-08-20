---
title: 【AIアセット反映】get_branch_work_filesの改名対応
type: plan
description: issue #115で得た知見をルール（shell-script-style.md）へ一般化して反映する個別反映計画。
tags: [plan, ai-asset, rules, workflow]
keywords: [AIアセット反映, shell-script-style, porcelain, -z, NUL, ルール, 再発防止]
---

# 【AIアセット反映】`get_branch_work_files` の改名対応

全体作業計画: `plans/rename-aware-work-files.md`
対象issue: #115
フェーズ: 4〈反映〉（flow-id 4-1）

`【設計反映】` と分けている理由: 正史ドキュメントへの記録（設計反映）と、今後のAIの書き方を縛る
運用ルールの改訂（AIアセット反映）は要求される判断が異なるため（`.claude/rules/docs-workflow.md`）。

## 反映対象の洗い出し

| 対象 | 反映するか | 内容 |
|---|---|---|
| `.claude/rules/shell-script-style.md`「コマンド置換とNULバイト」 | **する** | 「`git status --porcelain` からパスを取り出すときは `-z` を付ける」を項目として追加。悪い例／良い例と、分解を純粋関数へ切り出して単体テストを書く指針を添える |
| `AGENTS.md` / `CLAUDE.md` | **しない** | 個別のシェル実装上の注意であり、共通ルールの階層に上げる粒度ではない |
| `.claude/skills/issue-mr-flow/SKILL.md` | **しない** | フロー定義に影響しない |
| `.claude/rules/git-workflow.md` | **しない** | ブランチ・コミット運用の話ではない |

## この反映で狙うこと

`shell-script-style.md` には既に「NUL区切り出力を `$(...)` で受けない」「`git ls-files` には
クォート回避のため `-z` を付ける」という項目がある。今回踏んだのは**同じ「gitの行単位出力を
信用した」系統の失敗**であり、既存項目の並びへ追加するのが自然。**`git ls-files` の項目だけを
読んで `git status` は対象外だと解釈してしまう**のを防ぐ意図がある。

「行単位形式は後段でどれだけ丁寧に分解しても曖昧」という点を明記し、`-> ` の位置で分割する
自作パーサへ流れないようにする。

## 反映しないと決めたこと

- 「`git` の機械可読出力は原則 `-z`」という一般則としてのルール化。`git diff --name-only` のように
  行単位でも曖昧にならないサブコマンドまで縛ると、既存コードとの整合が取れなくなる。
  今回は `status --porcelain` に限定して書く。

## 検証

```bash
bash .claude/scripts/src/extract-frontmatter.sh .   # frontmatterの再インデックス（任意）
```

追加したコード例が実際に動くことを、一時リポジトリで実行して確認する（ルールに載せる例が
動かないと、そのまま真似されて再発するため）。
