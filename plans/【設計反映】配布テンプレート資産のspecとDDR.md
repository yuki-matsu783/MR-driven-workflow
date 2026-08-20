---
title: 【設計反映】配布テンプレート資産のspecとDDR
type: plan
description: issue #33の個別反映計画（設計反映）。spec新設と3件のDDRの作成範囲を定める
tags: [plan, design-reflection, ddr, spec]
keywords: [distribution-assets, VERSION, LICENSE, gitattributes, DDR, spec, 版管理, 却下案]
---

# 【設計反映】配布テンプレート資産のspecとDDR

全体作業計画: `plans/配布テンプレート資産の整備.md`（issue #33）
反映元: `reports/20260820_配布テンプレート資産の整備_配布経路と追加資産の調査.md`、
`reports/20260820_配布テンプレート資産の整備_実装結果.md`、`worklog/` の2ファイル

`.claude/rules/docs-workflow.md` に従い、`【AIアセット反映】` とはファイルを分ける
（正史ドキュメントへの記録と、運用ルールの改訂は評価軸が異なるため）。

## 反映対象の洗い出し

| 反映先 | 反映する内容 | 種別 |
|---|---|---|
| `.claude/docs/spec/distribution-assets.md`（新設） | 配布テンプレート資産（PR/MRテンプレート・`.gitattributes`・`.claude/VERSION`）の仕様と、配布経路上の扱い | spec |
| `.claude/docs/ddr/0061-…` | 配布物の版はVERSIONファイル1つで表し、CHANGELOGを持たない | DDR |
| `.claude/docs/ddr/0062-…` | 配布テンプレートにLICENSEを同梱しない | DDR |
| `.claude/docs/ddr/0063-…` | `.gitattributes` は丸ごと配らず必要な行だけを追記する | DDR |
| `.claude/docs/README.md` | DDR一覧へ3件を追記 | guide |

**DDR番号は0061から始める。** 0059・0060は main 側（PR #131 / #134）で既に使われており、
このブランチへ取り込み済みであることを確認した（`.claude/docs/ddr/` の実物で確認）。

## specに書くこと

1. 背景・目的（issue #33。配布先が必要とする基本資産が欠けていた）
2. 仕様
   - PR/MRテンプレートの構成と、`describe` に全文置換される前提
   - `.gitattributes`: 本家の内容と、**配布するのは `*.sh text eol=lf` の1行だけ**という線引き
   - `.claude/VERSION`: 位置・形式・更新規則（誰が・いつ・どの粒度で上げるか）
3. 影響範囲（`sync-assets.sh` / `install-to-project.sh` / 新規の結合テスト）
4. 未決定事項・懸念点
   - Windows実機での改行挙動が未確認であること
   - issue #26 の層分け・manifest方式へ移行する際に、この仕様のどこが引き継がれるか

## DDRに書くこと（共通）

各DDRには**却下案とその理由**を必ず含める。調査結果に比較表があるので、そこから移す。

- 0061（版管理）: 却下案＝CHANGELOG併用／ルート `VERSION`／`.mrworkflow.json` のキー。
  採用理由と、issue #26 の manifest（コミットSHA）との役割分担。
- 0062（LICENSE）: **ユーザーが種別「なし」を選択したという事実**と、その帰結
  （明示的な許諾が無いため既定の著作権保護下に置かれ、第三者による再配布の可否が不明確になる）。
  将来追加する場合の入口も書く。
- 0063（`.gitattributes`）: 却下案＝全文コピー／配らない。行全体一致（`grep -Fxq`）で判定する
  理由（部分一致だと「無言で入らない」側へ倒れる）。

## この計画で決めないこと

- issue #26 の層分け定義ファイルの中身（#26 の担当）。
- ルール文書（`.claude/rules/`）・`index.md`・`README.md` 等の更新は
  `plans/【AIアセット反映】ルールとリポジトリマップの更新.md` の担当。

## 検証

- `bash .claude/scripts/src/extract-frontmatter.sh .` が新規markdownを取り込み、`failed=0` になること。
- DDR番号の重複が無いこと（`ls .claude/docs/ddr/ | grep -c '^006[123]'` が 3 であること）。
- `.claude/docs/README.md` のDDR一覧に3件が載っていること。
