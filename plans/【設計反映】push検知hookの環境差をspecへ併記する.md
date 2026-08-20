---
title: 個別反映計画 push検知hookの環境差をspecへ併記する
type: plan
description: issue #47 の調査で得た「push検知hookの if が地の文で発火しなかった」という観測を、issue #23 の既存記録を消さずに環境差として spec/issue-mr-workflow.md へ併記する設計反映計画
tags: [plan, spec, hook, issue-47]
keywords: [設計反映, spec, issue-mr-workflow, push検知, hook, if, 部分一致, 環境差, issue-23, changelog]
---

# 個別反映計画: push検知hookの環境差をspecへ併記する（flow-id 4-1）

- issue: [#47](https://github.com/yuki-matsu783/MR-driven-workflow/issues/47)
- 反映元: `reports/20260820_prancy-prancing-dewdrop_ルール読込条件と前方一致の調査.md`（調査3・恒久知見#1）
- 対になる計画: `plans/【AIアセット反映】ルール運用の3点を反映する.md`（**先にこちらの設計反映を完了・
  レビューしてからAIアセット反映へ着手する**。`SKILL.md`「種別を複数併記する場合／分ける場合」）

## 目的

フェーズ2の調査で、`.claude/docs/spec/issue-mr-workflow.md` に記録された**issue #23 時点の観測と
逆の結果**を得た。この食い違いを正史へ残す。**issue #23 の記録を上書きしない**形にすることが
本計画の要点である。

## 反映対象

| ファイル | 箇所 | 内容 |
|---|---|---|
| `.claude/docs/spec/issue-mr-workflow.md` | 「誤検知（pushしていないのに発火する）」の項（1052行付近） | issue #47 での逆の観測を**環境差として併記** |
| 同上 | changelog（末尾） | issue #47 のエントリを追加（既存の慣習に合わせる） |

## 何を書くか

### 併記する内容

既存の記述（`if` は前方一致ではなく部分一致。issue #23 対応時に実機で計3回確認。`cd ...` で
始まるケースと、heredocの地の文のケースで発火した）は**1文字も変更しない**。その直後へ、
次の内容を持つ段落を足す。

- **issue #47 の調査（Claude Code on the web / Linux、2026-08-20）では、同じ構成で発火しなかった。**
  測ったのは3ケース＋heredocの追試1ケースの計4ケース。
- **どちらが現行かを決める材料は無い。** Claude Codeのバージョン差かプラットフォーム差かの
  切り分けもできていない。
- **したがって回避策（長文をファイル経由で渡す）は変えない。** 発火しない環境があることは、
  発火する環境で回避策が不要になる理由にはならない。

### 書き方の制約

- **issue #23 の記録を「訂正」しない。** 実測4ケースは1環境・1バージョンの観測にすぎず、
  既存記録を上書きできる根拠が無い（フェーズ3の敵対的レビュー指摘）。
- **どちらの観測にも、環境（Windows / git bash か Claude Code on the web / Linux か）と
  issue番号を明記する。** どちらの記録かを後から辿れるようにする。
- **既存の「誤検知」項は、末尾が節全体にかかる地の文（回避策とAIエージェント向け注記への誘導）で
  終わっている。** 併記する段落をその地の文より前へ差し込むと係り先が壊れるため、
  **項の末尾（次の箇条書きの直前）へ置く**（`.claude/rules/docs-workflow.md`「既存ドキュメントへ
  新しい見出しを差し込むとき」）。

### changelogへの追記

既存エントリ（`- .claude/docs/README.md（DDR一覧へ00NN を追加）` の形）に倣って、issue #47 の
エントリを1つ足す。**過去のissueごとのchangelogエントリには一切手を触れない**
（point-in-time記録のため。`.claude/rules/docs-workflow.md`）。

## やらないこと

- **`.claude/rules/git-workflow.md` への反映**。これはAIアセット反映であり、対になる計画の担当。
- **どちらが現行かの切り分け**（Windows実機が無いため本セッションでは不可能）。未確定として残す。
- **回避策そのものの変更**。上記のとおり変えない。
- 新しいDDRの作成。**DDR 0059 は既に「照合の実挙動は環境・バージョンで変わりうる」を判断4の
  根拠として記録済み**であり、同じ内容で番号を消費しない。

## 検証

**結果は `reports/20260820_prancy-prancing-dewdrop_反映結果.md` へ書く**（この計画へは書かない）。

1. **既存記述が1文字も変わっていないこと。**

   ```bash
   # 期待値: issue #23 の記述を含む行が、差分の削除側に現れない
   git diff -- .claude/docs/spec/issue-mr-workflow.md | grep '^-' | grep -v '^---'
   ```

2. **両方の観測が、環境とissue番号つきで読めること。** 該当箇所を表示して目視で確認する。

   ```bash
   sed -n '/誤検知（pushしていないのに発火する）/,/^  より厳密な検知/p' .claude/docs/spec/issue-mr-workflow.md
   ```

3. **差し込み位置の前後で、空行が2つ連続していないこと・次の見出しの直前に空行が1つあること**
   （`.claude/rules/docs-workflow.md`）。上と同じ表示で確認する。

4. **過去のchangelogエントリが変わっていないこと。** 1の差分で、追加行以外が出ないことを見る。
