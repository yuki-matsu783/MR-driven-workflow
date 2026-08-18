---
title: worklog 20260818 extract-frontmatter高速化と中断耐性 push3
type: log
description: issue #11 レビュー指摘（一時ファイルもjsonl対象・gitignoreは除外）への対応記録（push3）
tags: [worklog, extract-frontmatter, gitignore]
keywords: [index.jsonl, plans, worklog, gitignore, git-ls-files, exclude-standard, 一時ファイル, flow-id 5-1]
---

# worklog: 【設計】【実装】【テスト】extract-frontmatter高速化と中断耐性

対象: レビュー指摘への対応（2026-08-18）。
全体作業計画: `plans/lexical-stirring-peach.md`
個別作業計画: `plans/【設計】【実装】【テスト】extract-frontmatter高速化と中断耐性.md`
push回数: 3

## 試したこと

### レビュー指摘

> フェーズ途中の一時ファイルについてはjsonl作成の対象にしちゃっていいよ。.gitignoreは除いてほしいけど

> マージリクエスト直前にpushするときはもちろんindex.jsonlも消すよ

push2で「`plans/index.jsonl`（新規）と `worklog/index.jsonl` は flow-id 5-1 で削除される一時ファイルを
指すが、どう扱うか」を判断依頼していた件への回答。**作業中は対象に含めてよく、flow-id 5-1（MR直前）で
`plans/index.jsonl` も一緒に削除する**、という運用で確定した。

### `.gitignore` 対象が除外されることの実機確認

`.gitignore` で除外されているディレクトリ（`/logs/`・`/build/`）にfrontmatter付きmarkdownを
置いてから、リポジトリルート指定で実行した。

```
files=47 built=0 reused=47        ← 走査対象が増えていない
logs/index.jsonl, build/index.jsonl は作られない
git status もクリーン（後片付け前）
```

→ `.gitignore` 対象は**列挙自体が発生しない**ことを確認した。走査に
`git ls-files --cached --others --exclude-standard` を使っているためで、issue #54 の走査方式変更
（`.claude/docs/ddr/0016-frontmatterスクリプトの走査方式にgit-ls-filesを採用する.md`）で既に
担保されている性質。今回の改修でもこの方式は維持している。

## うまくいったこと

- **指摘の要求は現行実装のままで満たされている**ため、スクリプトの変更は不要と判断した。
  - 一時ファイル（`plans/` `worklog/`）→ **jsonl作成の対象のまま**（`plans/index.jsonl` と
    `worklog/index.jsonl` をコミット済み）。
  - `.gitignore` 対象 → **除外済み**（上記の実機確認）。
- これにより「クリーンな作業ツリーで `extract-frontmatter.sh .` を実行しても差分が出ない」という
  不変条件も維持できる（冪等性は実機確認済み: 2回連続実行して全 `index.jsonl` のmd5が不変）。

## ダメだったこと

- 特になし。

## 次の一歩

- flow-id 3-10: MR descriptionを更新する。
- **フェーズ4（AIアセット反映）で対応する確定事項**（レビューで合意済み）: flow-id 5-1
  （`plans/` `worklog/` `reports/` の削除）で、**`plans/index.jsonl` も一緒に削除する**。
  `plans/*.md` を全削除しても、本スクリプトは「markdownが直下に存在するディレクトリ」だけを
  出力対象にする仕様のため、markdownが無くなったディレクトリの `index.jsonl` は再生成の対象外と
  なり、削除済みplanを指す陳腐化した状態でそのまま残ってしまう（スクリプト側で「markdownが
  無くなったディレクトリの `index.jsonl` を削除する」挙動は、スコープ外のファイルを消しうるため
  今回は入れず、フロー手順側で担保する）。
  `.claude/skills/issue-mr-flow/SKILL.md` の flow-id 5-1 と `.claude/rules/docs-workflow.md` に、
  「`plans/index.jsonl` も削除し、`index.jsonl` 群を再生成してから commit する」手順を追記する
  （`worklog/` は `TEMPLATE.md` が残るため、再生成すれば正しい状態になる）。
- フェーズ4（設計反映）: spec更新・DDR新設・`.claude/rules/shell-script-style.md` への
  「ループ内でjq等を起動しない」「コマンド置換もforkコストを持つ」ルール追記。

---
