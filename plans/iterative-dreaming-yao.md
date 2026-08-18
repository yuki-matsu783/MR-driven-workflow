---
title: issue #22 全体作業計画 — issue-mr-flow適用要否の判定基準をAGENTS.mdへ一元化
type: guide
description: issue #22（判定基準の重複記載整理）に対する全体作業計画。対象ファイル・変更方針・フェーズ省略の判断を記載する
tags: [issue-mr-flow, docs, agents-md]
keywords: [判定基準, 一元化, AGENTS.md, SKILL.md, git-workflow.md, 重複記載, issue22]
---

# 全体作業計画: issue #22 対応

## Context

issue-mr-flow（issue駆動MRワークフロー）を使うかどうかの判定基準が、`AGENTS.md`・
`.claude/skills/issue-mr-flow/SKILL.md`・`.claude/rules/git-workflow.md` の3ファイルに
それぞれ独自の言い回しで重複記載されている。この判定は「すべてのタスクの最初に考えること」で
あり、将来判定基準そのもの（「ごく小さな変更」の定義・例示）を変更する際に3箇所を漏れなく
直す必要があり、修正漏れ・食い違いのリスクがある。

issue #22（https://github.com/yuki-matsu783/MR-driven-workflow/issues/22）の要求は、
判定基準の一次情報を `AGENTS.md` の1箇所に集約し、`SKILL.md` と `git-workflow.md` は
`AGENTS.md` への参照のみに変更することで、この重複をなくすこと。

## 現状の重複箇所（確認済み）

| ファイル | 現在の記載 |
|---|---|
| `AGENTS.md` 13行目 | 「ごく小さな変更を除き、全タスクはissueを起点に進める。」— 判定条件の結論のみ、例示なし |
| `.claude/skills/issue-mr-flow/SKILL.md` 13-15行目 | 「ごく小さな変更（誤字修正等。`.claude/rules/git-workflow.md` 参照）を除くあらゆるタスクは、このファイルの手順で進める」— 除外条件の言及とgit-workflow.mdへの参照が混在 |
| `.claude/rules/git-workflow.md`「適用範囲」節（16-19行目） | 「誤字修正・軽微なドキュメント修正等、フロー自体を省略してよいごく小さな変更は、mainへの直接コミットも許容する」— 判定基準の例示と、フロー対象外時の帰結（ブランチ運用）の両方が書かれている |

判定基準の一次情報は実質 `git-workflow.md` にある状態。ここを `AGENTS.md` へ移す。

## フェーズ省略の判断

対象箇所・変更方針はissue本文に明確に記載されており、追加の調査を要する未知の要素が無いため、
**フェーズ2（調査）は省略し、フェーズ3（作業計画）から着手する**。次に作成する個別作業計画は
`plans/【設計】判定基準の一元化.md` とする（ドキュメント整理のみで実装・テストは伴わないため
種別は「設計」1つのみとする）。

## 変更方針（3ファイル）

### 1. `AGENTS.md`（一次情報として集約）

13行目の1文を拡張し、「ごく小さな変更」の例示（誤字修正・軽微なドキュメント修正等）と、
除外時の帰結（mainへの直接コミット許容）をここに集約する。詳細な判定基準・ブランチ運用は
`git-workflow.md`「適用範囲」参照、という導線を追加する。

### 2. `.claude/skills/issue-mr-flow/SKILL.md`（参照のみに変更）

冒頭（10-15行目）の「ごく小さな変更（誤字修正等。...参照）を除く」という判定基準の例示を削り、
「適用要否の判定基準は `AGENTS.md` を参照する」という参照のみに変更する。

### 3. `.claude/rules/git-workflow.md`「適用範囲」節（判定基準を削り帰結のみ残す）

「誤字修正・軽微なドキュメント修正等」という判定基準の例示（=一次情報）を削除し、
「適用要否の判定基準は `AGENTS.md` を参照する」という参照文と、フロー対象外と判定された
場合の帰結（mainへの直接コミット許容というブランチ運用上の扱い）のみを残す。

いずれも既存のYAML frontmatter（`AGENTS.md`・`git-workflow.md`とも既存キーあり。
`git-workflow.md`は`alwaysApply: true`を持つため、対象外ルールにより既存キーは変更せず
必要なら新規キー追記のみに留める）はそのまま維持し、本文のみ変更する。

## 受け入れ条件（issue #22より）

- AGENTS.md・SKILL.md・git-workflow.mdの3ファイルで、判定基準の実体記載が重複していない
  （一次情報はAGENTS.mdの1箇所のみ）
- SKILL.mdとgit-workflow.mdからAGENTS.mdへの参照が適切に設定されている
- 既存の判定基準の意味内容（誤字修正・軽微なドキュメント修正等は除外、それ以外はissue-mr-flow
  必須、除外時はmain直接コミット許容）が変更前後で変わっていない
- `.claude/rules/markdown-frontmatter.md`のfrontmatterルールに違反していない

## 検証方法

- 3ファイルをdiffで見比べ、「誤字修正」「軽微なドキュメント修正」等の例示文言がAGENTS.mdにのみ
  存在し、SKILL.md・git-workflow.mdには参照リンクのみが残っていることを目視確認する。
- `bash .claude/scripts/src/extract-frontmatter.sh .` を実行し `index.jsonl` 群を更新する
  （commit直前に1回）。
- 変更後の3ファイルを通しで読み、判定基準の意味内容（除外対象・帰結）が変更前と一致することを
  確認する。

## 次のステップ

1. 本計画の承認後、`plans/【設計】判定基準の一元化.md`（個別作業計画）を作成しレビュー依頼
   （flow-id 3-1〜3-2、フェーズ2省略のためフェーズ3から開始）
2. レビュー後、3ファイルを編集・commit・push（flow-id 3-6〜3-7）
3. 設計反映（flow-id 4-1〜4-10。今回はドキュメント整理自体が変更対象のため、
   反映計画では主に `HANDOFF.md`・worklogの整理を扱う）
4. クローズ（flow-id 5-1〜5-3）
