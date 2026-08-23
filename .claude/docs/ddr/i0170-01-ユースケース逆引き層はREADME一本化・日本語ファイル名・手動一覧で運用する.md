---
title: i0170-01. ユースケース逆引き層はREADME一本化・日本語ファイル名・手動一覧で運用する
type: ddr
description: .claude/docs/usecase/ の新設にあたり、配置・type新設・一覧の持ち方・ファイル名・鮮度維持の5つの設計判断と却下案を記録したDDR
tags: [ddr, usecase, docs, workflow]
keywords: [ユースケース, 逆引き, README一本化, 日本語ファイル名, 手動一覧, type新設, 生成物化, 再検討条件, flow-id 4-6, 鮮度維持]
---

# i0170-01. ユースケース逆引き層はREADME一本化・日本語ファイル名・手動一覧で運用する

## 背景

リポジトリのドキュメントは機能起点（spec: この機能の仕様は何か）と決定起点（ddr: なぜこう
決めたか）で整理されており、「やりたいこと」起点で入る読み手（例:「途中の作業を再開したい」）が
どの機能・スキルへ辿ればよいかの逆引きが無かった。issue #170 で `.claude/docs/usecase/` を
新設し、場面起点の逆引き文書8本を置いた。その際の設計判断を記録する
（調査の全容はフェーズ2調査結果、実装の結果はフェーズ3作業結果が持っていたが、いずれも
flow-id 5-5 で削除される寿命のため、残すべき判断をここへ移す）。

## 決定

1. **配置は `.claude/docs/usecase/`**（spec・ddrと並ぶ独立ディレクトリ）。plugin配布単位で
   ある `.claude/` の中に置くことで、機構の配布先でも逆引き層が一緒に届く。
2. **frontmatter `type: usecase` を新設**する（`.claude/rules/markdown-frontmatter.md` の
   「typeの値」表へ追加）。`doc-search` スキルで `--type usecase` と絞れることが、
   「やりたいこと起点で探す」という当のユースケースの成立条件になる。
3. **一覧の正は `.claude/docs/README.md` のusecase節1箇所**。usecase文書を追加・改名・削除
   したら、READMEのusecase節を**同じコミットで**更新する。
4. **ファイル名は場面を表す日本語**（例: `途中の作業を再開・引き継ぐ.md`）。
5. **一覧は手動更新**とし、DDR一覧（`generate-ddr-list.sh`）のような生成物化はしない。
   **再検討条件: 手動更新の漏れ（README一覧と実ファイルの不一致）が実際に起きたとき。**
6. **鮮度維持は flow-id 4-6（設計反映）への組み込みで担保**する。機能の追加・変更時に、
   既存usecase文書への影響（記述・リンクが古くならないか）を確認する1行を
   `issue-mr-flow/SKILL.md` の 4-6 と `docs-workflow.md` のライフサイクル表が持つ。

## 却下案

- **配置: `.claude/docs/` 直下への平置き・リポジトリルート** — 直下平置きはspec/ddrとの種別の
  境目が消え、READMEの目次構造とも揃わない。ルートは plugin 配布単位（`.claude/` 一式）の外に
  なり、配布先へ届かない。
- **type: 既存の `spec` / `guide` への相乗り** — specは「機能ごとの正史仕様」（機能起点）、
  guideは「永続の案内」（README等の入り口）で、「やりたいこと起点の逆引き」という検索軸が
  どちらとも異なる。相乗りすると `--type` での絞り込みが成立しない。
- **一覧: `usecase/` 直下の独立README** — 一覧の置き場が `.claude/docs/README.md`（docs全体の
  目次）と2箇所になり、片方だけが更新されて食い違う（正は1箇所の原則）。
- **ファイル名: 英語kebab-case・番号プレフィックス** — このリポジトリの読み手・応答言語は
  日本語であり、逆引きの入り口であるファイル名は場面の言葉そのままが最も探しやすい。番号は
  並び順の意図を持たせられる代わりに、挿入のたびに繰り下げが要る（DDRが連番を廃止したのと
  同じ理由で採らない）。
- **一覧の生成物化（`generate-ddr-list.sh` 同様の仕組み）** — 8件規模ではスクリプトの導入・
  保守コストが手動更新の手間を上回る。DDR一覧（77件・2ブランチ同時追加で毎回コンフリクト）とは
  規模も更新頻度も異なる。上記「再検討条件」を満たしたら改めて検討する。

## 影響範囲

- 新設: `.claude/docs/usecase/`（8本）
- 更新: `.claude/rules/markdown-frontmatter.md`（typeの値表）・`.claude/docs/README.md`
  （usecase節）・`.claude/rules/docs-workflow.md`（ライフサイクル表）・
  `.claude/rules/directory-structure.md`・`index.md`・`.claude/REVIEW-POINTS.md`（usecase観点）・
  `.claude/skills/issue-mr-flow/SKILL.md`（flow-id 4-6）
