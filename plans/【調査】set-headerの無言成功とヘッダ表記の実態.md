---
title: 【調査】set-headerの無言成功とヘッダ表記の実態
type: plan
description: issue #66の個別調査計画。set-headerが無言で成功する条件と、HANDOFF.mdヘッダ行の表記・位置の実態を確認する
tags: [plan, update-handoff-progress, handoff]
keywords: [set-header, 再現, ヘッダ行, 表記ゆらぎ, 挿入位置, cleanup-task, issue140, 調査]
---

# 【調査】set-headerの無言成功とヘッダ表記の実態

対象issue: [#66](https://github.com/yuki-matsu783/MR-driven-workflow/issues/66)（flow-id 2-1）

**この計画には結果を書かない。** 結果は `reports/2026-08-20_set-header-silent-failure_調査結果.md`
（正文）と同名の `.html`（視覚化）へ書く。

## 調べること

### 調査1: 無言成功の再現

**実物と同じ形**のHANDOFF.md（`## フロー進捗状況` 見出しの下にヘッダ行が並び、PR行が
`- Draft PR:` 表記）に対して `set-header --pr` を実行し、次を確認する。

- 終了コードが0であること
- ファイルが1バイトも変わっていないこと（`diff` で確認する）

再現できたら、`cmd_set_header` のどの構造がそれを許しているかをコードで特定する。

### 調査2: ヘッダ行の表記・並び順・位置の実態

git履歴上のHANDOFF.mdを対象に、次を数える。

- PR行の表記（`- PR:` / `- Draft PR:` / その他）の分布
- ヘッダ項目の並び順
- **ヘッダブロックがファイルのどこにあるか**（`## フロー進捗状況` 見出しの前か後か）

3点目を含めるのは、`set_loop_header_in_lines`（`- 現在のループ:` 行の挿入位置判定）が
「見出しより前にあるヘッダ項目」だけを挿入位置の基準にしているためである。実物が見出しの
**後**にヘッダを置いているなら、挿入位置が実物と噛み合っていない可能性がある。

### 調査3: 同じ前提を置いている他の箇所の洗い出し

ヘッダ行の表記・位置を前提にしている箇所を列挙し、表記を1つに定めたときに何を直す必要があるかを
確定する。少なくとも次を見る。

- `.claude/scripts/src/update-handoff-progress.sh`（`cmd_set_header` / `set_loop_header_in_lines`）
- `.claude/scripts/src/cleanup-task.sh`（`HANDOFF_TEMPLATE`）
- `.claude/agents/issue-mr-resume.md`（現在地サマリの項目）
- `.claude/rules/docs-workflow.md` / `.claude/docs/spec/update-handoff-progress.md` /
  `.claude/docs/spec/issue-mr-workflow.md`（`- 追従監視:` 行の扱い）

### 調査4: issue #140 を本issueへ取り込むかの判断材料

issue #140 のコメントが「スクリプト全体の方針として1本立てるなら #66 と #140 を1つにまとめる
判断もあり得る」と書いているため、次を整理する。

- 両者が「同じ形の欠陥」と言えるか（無言で成功する／不整合を作る、の違い）
- #140 が要求している作業（3案の比較検討・インターフェースの意味の変更）が、#66 のスコープに
  収まるか
- まとめない場合に、#66 側で何を残せば #140 の検討材料になるか

## 調べないこと

- `mark-done` / `add-round` / `mark-skip` の**進捗記号**そのものの挙動（本issueはヘッダ行が対象）。
  ただしヘッダ行（`- 現在のループ:`）を触る経路は調査対象に含める。
- HANDOFF.md以外のファイルのフォーマット。

## 進め方

いずれも読み取りと使い捨てファイルへの再現のみで、リポジトリ内のファイルは変更しない。
再現に使う一時ファイルはスクラッチパッドへ置く。
