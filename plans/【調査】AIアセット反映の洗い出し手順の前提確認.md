---
title: 【調査】AIアセット反映の洗い出し手順の前提確認
type: plan
description: SKILL.mdへ「AIアセット反映の対象の洗い出し」節を新設するにあたり、置き換え対象の現行文言・既存定義との整合・doc-searchの入出力を先に確かめるための個別調査計画。
tags: [plan, issue-mr-flow, ai-asset, research]
keywords: [調査計画, flow-id 4-1, flow-id 4-6, 洗い出し, 置換前後, doc-search, REVIEW-POINTS, 反映先形態, スキップ条件]
---

# 【調査】AIアセット反映の洗い出し手順の前提確認

- issue: #155
- PR: #175
- 全体作業計画: `plans/brisk-charting-lantern.md`（flow-id 1-4 で作成）
- フェーズ: 2〈調査〉 flow-id 2-1
- 作成日: 2026-08-23

## 前提（合意状況）

- 上位の計画: `plans/brisk-charting-lantern.md`。**flow-id 1-5（人間による合意）は未了**である。
  このセッションは人間のレビュー往復が成立しないため、敵対的レビューで代替する（HANDOFF.md
  「守るべき条件・触ってはいけない範囲」）。
- 全体作業計画の「フェーズ2〈調査〉」節に挙げた6問を、この計画の調査項目としてそのまま引き継ぐ。

## この計画で何をするか

フェーズ3で `.claude/skills/issue-mr-flow/SKILL.md` へ新設する「AIアセット反映の対象の洗い出し」節が、
**既存の記述・仕組みと矛盾しない形で書けるか**を先に確かめる。確かめるのは次の6問である。

| # | 問い | 何が分かれば十分か |
|---|---|---|
| Q1 | flow-id 4-1・4-6 の行と「全体作業計画に必ず含めるフェーズ」節は、新節を参照させるとき**どこをどう置き換える**ことになるか | 置換前の原文（行番号つき）と置換後の形が両方書けること |
| Q2 | フェーズ4をスキップしてよい条件（現行「反映するものが無いと確認できた場合」）は、洗い出し手順の**どの段階が終わった状態**を指すか | 「洗い出しの手順Nまでを実施し、結果が空だったとき」と言い換えられること |
| Q3 | 反映先の形態（`rules` / `skills` / `scripts` / `hooks` / `REVIEW-POINTS.md` / `agents`）は、既存ドキュメント上どこで定義され、置き場のルールは何か | 各形態の定義元ファイルと、2軸の説明が既存定義と矛盾しないことの確認 |
| Q4 | `doc-search` スキルは何を入力に何を返すか。証拠集めの打ち切り条件として書ける形か | 実際に1回実行し、返る項目（`type`/`title`/`description`/`tags`/`keywords`/パス）を確認すること |
| Q5 | `【AIアセット作成】`（フェーズ3）と `【AIアセット反映】`（フェーズ4）の既存の使い分け（issue #110）と、新設する洗い出し手順が矛盾しないか | 「成果物か副産物か」という既存の判断基準を、洗い出しの起点が壊していないこと |
| Q6 | `plans/REVIEW-POINTS.md` の既存の観点と、追加する `【AIアセット反映】` の観点が重複しないか。**SKILL.mdの新節との間で「正が2つ」にならない境界を引けるか** | 既存の「種別」節との重複箇所の有無と、「観点表は何を見るかだけを持ち、定義・手順はSKILL.mdを指す」という境界が1行で言えること |
| Q7 | 反映先の形態として `.claude/scripts/` `.claude/hooks/` を**含めるか外すか**。含めるなら flow-id 4-6 の反映先の列挙と `【AIアセット作成】` の除外規定を**どう書き換えるか** | 置換前の原文（行番号つき）と置換後の形が両方書けること。外す場合は issue #155 が挙げる6形態との差の説明 |
| Q8 | 削除・統合を手順に含めたとき、配布経路（`install-to-project.sh` は上流の削除を配布先へ伝播しない）で何が起きるか。手順側に何を書けば実害を打ち消せるか | `.claude/docs/spec/distribution-assets.md` の該当記述を引用し、手順へ書き足す1〜2行が決まること |

## 調査方法

- **Q1・Q2・Q5・Q6・Q7**: `.claude/skills/issue-mr-flow/SKILL.md` と `plans/REVIEW-POINTS.md` を
  `grep -n` で該当箇所を特定し、原文を行番号つきで引用する（置換前後を両方書くため。
  `plans/REVIEW-POINTS.md`「内容」の観点）。
- **Q3・Q8**: 先にスキル `doc-search`（実体は `bash .claude/scripts/src/search-frontmatter.sh`）で
  該当ドキュメントを探し、見つかったファイルだけを開く（`AGENTS.md` のルール。全文探索を
  第一手段にしない）。
- **Q4**: スキル `doc-search` の実体である `bash .claude/scripts/src/search-frontmatter.sh` を
  **実際に実行**し、返る項目を実測で確かめる（公式ドキュメントの記述だけを根拠にしない。
  `reports/REVIEW-POINTS.md`「内容の妥当性」）。**`--format json` をパイプの途中で切ると
  frontmatterのネストが見えず、スクリプト側もSIGPIPEで終了コード141になるため、`--format detail`
  （1件ずつ全項目を出す）を使う。**

## 変更対象

| ファイル | 操作 | 何をするか |
|---|---|---|
| `reports/20260823_brisk-charting-lantern_AIアセット反映の洗い出し手順の前提確認.md` | 新規 | 調査結果の正文（Q1〜Q6の回答と根拠） |
| `reports/20260823_brisk-charting-lantern_AIアセット反映の洗い出し手順の前提確認.html` | 新規 | 上記の人間レビュー用HTMLビュー |
| `worklog/20260823_brisk-charting-lantern_【調査】AIアセット反映の洗い出し手順の前提確認_push2.md` | 新規 | 試行錯誤の詳細ログ |

**この計画ファイルには結果を書かない**（`reports/` へ分ける。SKILL.md「計画と実施結果の分離」）。

## やらないこと（スコープ外）

- **4類型・2軸の中身を確定させること。** それはフェーズ3（個別作業計画 flow-id 3-1）で決める。
  この調査が出すのは「どこへどう書けるか」という器の確認であって、書く内容そのものではない。
- **過去MRを遡って実際のAIアセット反映事例を網羅的に集めること。** 網羅探索をしないことは
  今回定義する手順そのものの方針であり（全体作業計画「方針」）、調査でそれをやると自己矛盾する。
  Q4の確認に必要な範囲（`doc-search` を1回実行する）に留める。
- **`.claude/docs/spec/issue-mr-workflow.md` の入口文言の確定。** 判断は flow-id 4-1 へ送る。
- **Q7・Q8で決めた内容の実装（SKILL.mdの書き換え）。** この調査は置換前後の形を確定させるまでで、
  実際に書き換えるのはフェーズ3（flow-id 3-6）である。

## 検証

問いごとに照合コマンドを持たせる。**`grep -n 'AIアセット反映' SKILL.md` のような広い検索は使わない**
（現在のツリーで7行にヒットし、置換対象が一意に定まらない）。

```bash
# Q1: flow-id 4-1 と 4-6 の行、および「全体作業計画に必ず含めるフェーズ」の表を一意に特定する
grep -n 'まず反映対象を洗い出し' .claude/skills/issue-mr-flow/SKILL.md          # 期待1件（4-1行）
grep -n '作業中に気づいたルール・スキルの不備' .claude/skills/issue-mr-flow/SKILL.md  # 期待1件（4-6行）

# Q2: スキップ条件の原文
grep -n '反映するものが無いと確認できた' .claude/skills/issue-mr-flow/SKILL.md   # 期待1件（4-1行）

# Q3: 反映先の形態の置き場のルール
grep -n '配置の指針' .claude/rules/directory-structure.md

# Q4: doc-searchが実際に返す項目（ネストを潰さず全項目を出す）
bash .claude/scripts/src/search-frontmatter.sh --type ddr --path i0110 --format detail

# Q5: 【AIアセット作成】の除外規定
grep -n '対象に含めない' .claude/skills/issue-mr-flow/SKILL.md

# Q6: 観点表側の既存の記述
grep -n '【AIアセット反映】' plans/REVIEW-POINTS.md                              # 期待3件（既存の「種別」節）

# Q7: 書き換え候補の2箇所（Q1・Q5と同じ行を指すことの確認）
grep -n '`.claude/rules/` `.claude/skills/` `CLAUDE.md` `AGENTS.md`' .claude/skills/issue-mr-flow/SKILL.md

# Q8: 配布経路が削除を伝播しないという記述
grep -n '配布先から削除しない' .claude/docs/spec/distribution-assets.md
```

合格条件: Q1〜Q8のすべてに、実行したコマンドと返ってきた出力を根拠として添えた回答が
`reports/…md` に書かれていること。**期待ヒット数を書いた行は、実際の件数が一致すること**
（一致しなければ置換対象の見立てが誤っている）。確かめられなかった問いがある場合は、確かめたことと
区別して書かれていること。
