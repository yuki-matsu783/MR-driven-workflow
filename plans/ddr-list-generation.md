---
title: DDR一覧の生成スクリプト化（issue #135）
type: plan
description: .claude/docs/README.md のDDR一覧を手書き維持からスクリプト生成へ移し、追加時の手書き更新と並行開発時のマージ統合を無くすための全体作業計画
tags: [ddr, docs, script, workflow]
keywords: [DDR一覧, 生成スクリプト, generate-ddr-list, コンフリクト, frontmatter, note, superseded, README, 再生成]
---

# DDR一覧の生成スクリプト化（issue #135）

対象issue: [#135](https://github.com/yuki-matsu783/MR-driven-workflow/issues/135)
ブランチ: `claude/ddr-list-generation-script-58hl6j`

## 目的

`.claude/docs/README.md` のDDR一覧（55件）を生成物にし、

- DDR追加のたびの手書き更新を無くす
- 並行開発時に毎回起きる一覧のテキストコンフリクトを「片側を捨てて再生成」で終わらせる
- 上記2つに費やしていたAIエージェントの出力トークンを削減する

## フェーズ2〈調査〉

**実施する**（軽量）。着手前の事前調査で次を確認済み。

- DDR一覧は `.claude/docs/README.md` の54〜108行。DDRファイルは55件で一覧の件数と一致する。
- **一覧には `superseded` 注記のほかに、issueが把握していない散文の注記が2件ある**（0022・0048）。
  これらはfrontmatterに存在せず、READMEにしか無い情報である。等価な再生成にはこの2件の
  受け皿が要る（下記「決めること」）。
- DDRを列挙しているのはリポジトリ内でこの1箇所だけ（`grep` で確認済み）。

残りの調査はフェーズ3の実装と一体で進められる規模のため、独立した調査フェーズは立てない。

## フェーズ3〈設計・実装〉

1. `.claude/scripts/src/generate-ddr-list.sh` を新設する。
2. `.claude/docs/README.md` のDDR一覧を、生成マーカーで囲んだ区間にする。
3. 散文注記2件（0022・0048）をDDRのfrontmatterへ退避する。
4. `.claude/scripts/test/test_generate_ddr_list.sh` を新設する。

## フェーズ4〈反映〉

**実施する**。反映対象は次のとおり（flow-id 4-1 で確定）。

- 設計反映: `.claude/docs/spec/generate-ddr-list.md`（新規）・DDR（新規）
- AIアセット反映: `.claude/rules/docs-workflow.md`・`.claude/rules/markdown-frontmatter.md`・
  `.claude/skills/resolve-conflict/SKILL.md`・`.claude/docs/README.md` のspec一覧

## 決めること（issueの「設計フェーズで決めること」への回答）

| 論点 | 採用案 | 却下案 |
|---|---|---|
| 生成先 | **README内の一区間をマーカーで囲んで置換** | 別ファイルへ分離しREADMEからリンク（GitHub上で目次を開く手数が1つ増える） |
| 実行方法 | **AIが明示的に実行**（`--check` で検証可能） | SessionStart hookで自動生成（出力がGit管理下のため、無関係な差分が勝手に生まれる） |
| 散文注記の置き場 | **DDRのfrontmatterへ `note` キーを新設** | 別ファイル（サイドカー）で持つ（同期の手間とコンフリクトが戻る）／注記を捨てる（情報欠落） |

## 受け入れ条件との対応

issue #135 の受け入れ条件7項目すべてをフェーズ3・4で満たす。
