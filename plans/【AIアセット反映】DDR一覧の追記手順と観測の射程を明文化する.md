---
title: 個別反映計画 DDR一覧の追記手順と観測の射程を明文化する
type: plan
description: issue #47 の作業中に見つかったAIアセットの不備2点（DDR追加時の目次追記が手順に無い／実測の射程を超えた一般化を防ぐ観点が無い）を .claude/rules/ と REVIEW-POINTS.md へ反映する計画
tags: [plan, ai-asset, rule, issue-47]
keywords: [AIアセット反映, docs-workflow, REVIEW-POINTS, DDR一覧, 目次, 手動維持, 射程, 一般化, 観測, issue-47]
---

# 個別反映計画: DDR一覧の追記手順と観測の射程を明文化する（flow-id 4-1）

- issue: [#47](https://github.com/yuki-matsu783/MR-driven-workflow/issues/47)
- 反映元: `reports/20260820_prancy-prancing-dewdrop_ルール本文とDDRの作成結果.md`「恒久的に残すべき知見」#2・#3
- 対になる計画: `plans/【設計反映】push検知hookの環境差をspecへ併記する.md`
  （**そちらを完了・レビューしてから本計画に着手する**。`SKILL.md`「種別を複数併記する場合／分ける場合」）

## 目的

issue #47 の作業中に、**このワークフロー機構そのものの不備**を2つ踏んだ。どちらもタスク固有では
なく、次に同じことをする人／AIが同じ失敗をする性質のものなので、AIアセットへ反映する。

| # | 踏んだ失敗 | 反映先 |
|---|---|---|
| 1 | DDRを追加したのに `.claude/docs/README.md` のDDR一覧へ追記しておらず、気づかずマージされうる状態だった | `.claude/rules/docs-workflow.md` |
| 2 | 実測した対象（`deny`）の射程を超えて結論（`permissions` 全体）を書き、同じclassの誤りを1タスク内で2回繰り返した | `reports/REVIEW-POINTS.md` |

## 反映対象

| ファイル | 箇所 | 内容 |
|---|---|---|
| `.claude/rules/docs-workflow.md` | 「ドキュメント運用」表のDDRの行 | **DDRを追加したら `.claude/docs/README.md` のDDR一覧へも追記する**ことを明記 |
| `reports/REVIEW-POINTS.md` | 「内容の妥当性」節 | **結論の主語が、実際に測った対象と一致しているか**という観点を追加 |

## 何を書くか

### 反映1: DDR一覧への追記を手順として明記する

**現状の問題**: `.claude/docs/README.md` のDDR一覧は 0001〜 を網羅列挙する**手動維持**の目次だが、
「DDRを追加したら追記する」と書いたルールがどこにも無い。実際には `spec/issue-mr-workflow.md` の
changelogに `- .claude/docs/README.md（DDR一覧へ00NN を追加）` というエントリが繰り返し現れており、
**慣習としては確立しているのに明文化されていない**。`markdown-frontmatter.md` は
`status: superseded` の注記についてのみ言及している（新規追加については触れていない）。

**書く内容**（`docs-workflow.md` のDDRの行の「運用」列へ足す）:

- DDRを新規作成したら、`.claude/docs/README.md` のDDR一覧へ**番号順**に1行追記する。
- **`extract-frontmatter.sh` / `index.jsonl` は目次の欠落を検出しない。** frontmatterのインデックスに
  載っていても目次からは漏れうるので、件数の確認では代替できない。
- flow-id 5-1 でDDR番号が繰り下がった場合は、**リンクのファイル名とテキストの両方**を追随させる
  （既に `.claude/skills/resolve-conflict/SKILL.md` が扱っているので、そちらへ参照を張る）。

**書かないこと**: 追記手順を `issue-mr-flow/SKILL.md` の全体フロー表へ新しいステップとして足すこと。
flow-idを増やすほどの粒度ではなく、`docs-workflow.md` の運用表がドキュメントのライフサイクルを
持つ場所であるため、そこへ書くのが筋である。

### 反映2: 結論の主語と実測対象の一致を観点にする

**現状の問題**: `reports/REVIEW-POINTS.md` は「確かめられなかったことが、確かめたことと区別して
書かれているか」という観点を持つが、**確かめたことの射程そのもの**を問う観点が無い。本タスクでは
この隙間で2回失敗した。

| 回 | 測った対象 | 書いた結論の主語 |
|---|---|---|
| 1回目 | `hooks[].if` | `permissions`（別の仕組み） |
| 2回目 | `permissions.deny` | `permissions` 全体（`allow` を含む） |

どちらも「書式が同じだから同じ挙動だろう」という推測を、実測の顔をして書いた形である。
**「区別して書く」だけでは防げない**（本人は区別したつもりで書いているため）。

**書く内容**（`reports/REVIEW-POINTS.md`「内容の妥当性」へ足す）:

- **結論の主語が、実際に測った対象と一致しているか。** `deny` を測ったなら結論の主語は `deny`。
  名前の似た別の仕組み（`hooks[].if` と `permissions`）や、同じ設定の別のキー（`deny` と `allow`）へ
  そのまま広げていないか。
- **測った環境が結論に添えられているか。** 1環境・1バージョンの観測を、全環境の事実として
  書いていないか。**`reports/` はflow-id 5-3で削除されるため、`.claude/docs/` や `.claude/rules/` へ
  転記するときに限定が落ちやすい。**

## やらないこと

- **`.claude/rules/markdown-frontmatter.md` の `alwaysApply` の説明を書き換えること。**
  新規ファイルでの読み込み実測が取れるまで保留（フェーズ3の判断を維持）。
- **`.claude/docs/README.md` のDDR一覧そのものへの 0059 の追記。** これはフェーズ3で実施済み。
  本計画で足すのは**手順の明文化**だけである。
- **`.claude/rules/git-workflow.md` の push検知hookの記述の訂正。** 対になる設計反映計画の判断
  （環境差の併記にとどめ、issue #23 の記録を消さない）が確定してから、同じ方針で追随させる。
  **本計画では触らない**（同じ食い違いを2つの計画で別々に扱うと、結論が割れる）。
- 新しいDDRの作成。どちらも「不備を埋める」変更であり、選択肢を比較して決めた設計判断ではない。

## 検証

**結果は `reports/20260820_prancy-prancing-dewdrop_反映結果.md` へ書く**（この計画へは書かない。
対になる設計反映計画と同じファイルにまとめる）。

1. **反映1が、実際に手順として読めること。** DDRを追加する人が `docs-workflow.md` だけを読んで
   目次追記に辿り着けるかを確認する。

   ```bash
   sed -n '/000N-タイトル.md/,/REVIEW-POINTS/p' .claude/rules/docs-workflow.md
   ```

2. **反映2が観点表に載ったこと。**

   ```bash
   # 期待値: 「主語」を含む行が1行以上
   grep -n '主語' reports/REVIEW-POINTS.md
   ```

3. **`collect-review-points.sh` が新しい観点を拾うこと**（観点表は収集されて初めて効く）。

   ```bash
   # 期待値: 出力に反映2の観点が含まれる
   bash .claude/scripts/src/collect-review-points.sh reports/20260820_prancy-prancing-dewdrop_ルール本文とDDRの作成結果.md | grep -n '主語'
   ```

4. **既存の観点・運用表の記述を壊していないこと。**

   ```bash
   git diff -- .claude/rules/docs-workflow.md reports/REVIEW-POINTS.md
   ```

   追加行以外が差分に出ないことを見る（表の他の行・他の観点に手を入れていない）。

5. **差し込み位置の前後で、空行が2つ連続していないこと・次の見出しの直前に空行が1つあること**
   （`.claude/rules/docs-workflow.md`「既存ドキュメントへ新しい見出しを差し込むとき」）。
