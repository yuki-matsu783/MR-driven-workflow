---
title: 【全体作業計画】DDR識別子をissue番号ベースへ変更する
type: plan
description: issue #133 の全体作業計画。DDRの識別子を連番からissue番号ベースへ変更し、並行開発時の番号衝突を原理的に無くすまでの進め方
tags: [ddr, workflow, plan, conflict]
keywords: [DDR, 識別子, issue番号, 枝番, 連番, 番号衝突, semantic conflict, check-base-conflicts, resolve-conflict, 命名規則]
---

# 全体作業計画: DDR識別子をissue番号ベースへ変更する（issue #133）

## 対象issue

[#133 DDRの識別子を連番からissue番号ベースへ変更し、並行開発時の番号衝突を原理的に無くす](https://github.com/yuki-matsu783/MR-driven-workflow/issues/133)

## 背景（issueの要約）

- DDRは `.claude/docs/ddr/NNNN-タイトル.md` の連番で識別している。分散したブランチ上で共有の
  単調増加カウンタを採番しているため、2つのブランチが同時に新しいDDRを追加すると必ず同じ番号になる。
- ファイル名が異なるためgitはコンフリクトと見なさない（semantic conflict）。
  `check-base-conflicts.sh` の `hasDuplicateDdrNumber` で検知し、`resolve-conflict` スキルの
  類型Aとして作業ブランチ側を繰り下げ改番している。過去4回（PR #29 / #37 / #49 / #52）すべてこの形。
- 改番はファイル名だけでなく、frontmatterの `title`・本文冒頭の見出し・`.claude/docs/README.md` の
  DDR一覧・他ファイルからの参照に及ぶ。実際にissue #36の改番で `.gitignore` のコメントが
  古い番号のまま残り、issue #46で修正するまで存在しないDDRを指していた。

## ゴール

**採番の方式そのものを変え、衝突を「検知して直す」から「起きない」へ移す。** 具体的には、
新規DDRの識別子を中央で採番されるissue番号ベースにする。既存の連番DDRは改番しない。

## フェーズ2〈調査〉

**実施する（軽量）。** issue本文が現状分析まで済ませているため、調査は「変更対象の洗い出しと、
新方式が既存の機構と衝突しないことの確認」に限る。

- 新方式の命名規則の候補を比較し、1案へ決める（区別可能性・可読性・ソート順・参照のしやすさ）。
- 4桁連番の形式を前提にしているコード・ドキュメントを全数洗い出す
  （`check-base-conflicts.sh` の正規表現、その単体テスト、spec、`resolve-conflict` スキル、
  `markdown-frontmatter.md`、`docs-workflow.md`、`.claude/docs/README.md`）。
- 既存58件のDDRへの参照（リポジトリ全体で約107箇所）が**変わらない**ことを確認する。

結果は `reports/2026-08-20_DDR識別子をissue番号ベースへ変更する_調査結果.md` に記録する。

## フェーズ3〈作業〉

1. 命名規則の確定と規約への明記（`.claude/rules/markdown-frontmatter.md`）。
2. `check-base-conflicts.sh` の識別子抽出・重複判定を新旧両方式に対応させる。
3. `.claude/scripts/test/test_check_base_conflicts.sh` に新旧混在のケースを追加する。
4. `resolve-conflict` スキルの類型Aを、新方式では衝突が起きないこと・既存連番DDRは従来どおり
   改番することが分かる形へ書き換える。
5. `.claude/docs/README.md` のDDR一覧を、新旧が破綻なく並ぶ構成へ整える。

## フェーズ4〈反映〉

反映対象は flow-id 4-1 で洗い出す。現時点の見込みは次のとおり（確定ではない）。

- spec: `.claude/docs/spec/check-base-conflicts.md`（検知2の仕様を新方式へ）。
- DDR: 採用理由と却下案（連番維持＋採番のマージ直前への遅延／番号レンジの担当者別分割）を記録する
  DDRを**新方式の第1号として**追加する。
- AIアセット: `.claude/rules/docs-workflow.md` のDDR行、`issue-mr-flow` スキルの類型A記述。

## フェーズ5〈クローズ〉

コンフリクト検知 → 関連issue通知 → 片付け → Draft解除まで通す。マージは人間が行う。

## 守るべき条件・触ってはいけない範囲

- **既存58件のDDRのファイル名・本文・他ファイルからの参照を変更しない。**
- DDRの「本文は一度マージしたら変更しない」原則を守る（frontmatterのみ後から更新可）。
- spec/DDRの過去changelog（point-in-timeの記録）を書き換えない。
