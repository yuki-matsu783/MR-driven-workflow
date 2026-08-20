---
title: 【設計反映】DDR識別子の新方式をspecとDDRへ記録する
type: plan
description: issue #133 の個別反映計画。洗い出した反映対象（spec 1件・DDR 1件新規）と、AIアセットへの反映が作業フェーズ内で完了している旨
tags: [ddr, plan, spec, workflow]
keywords: [設計反映, spec, DDR, check-base-conflicts, 却下案, AIアセット反映, 反映対象]
---

# 【設計反映】DDR識別子の新方式をspecとDDRへ記録する（issue #133）

## 反映対象の洗い出し（flow-id 4-1）

`plans/` `worklog/` `reports/` の内容から、永続ドキュメントへ移すべきものを洗い出した結果は次のとおり。

| 反映先 | 対象 | 要否 |
|---|---|---|
| `.claude/docs/spec/check-base-conflicts.md` | 「検知2」の仕様（受け付ける識別子の形式・判定順・残る重複ケース）と、issue #133 の影響範囲 | **要** |
| `.claude/docs/ddr/`（新規） | 採用理由と却下案（採番の遅延／レンジ分割／ゼロ埋め／検知の廃止）、JSONキーを改名しなかった理由、受け入れたトレードオフ | **要**（新方式の第1号 `i0133-01`） |
| `.claude/rules/markdown-frontmatter.md` | 命名規則 | **作業フェーズ内で完了済み**（規約そのものが今回の成果物のため） |
| `.claude/rules/docs-workflow.md` / `.claude/skills/*` | 運用表・スキルの手順 | **作業フェーズ内で完了済み**（同上） |
| 他のspec（`issue-mr-workflow.md` 等） | 過去issueごとのchangelog | **不要**（point-in-timeの記録は書き換えない） |

**`【AIアセット反映】` を別ファイルに分けていないのは、AIアセット（`.claude/rules/` `.claude/skills/`）の
改訂そのものが本issueの成果物であり、フェーズ3の作業として実施済みだからである。**
「作業中に気づいたルールの不備を後から直す」という通常の反映は、今回は対象が無い。

## 実施内容

1. `.claude/docs/spec/check-base-conflicts.md`
   - 「検知2: DDR番号の重複」→「検知2: DDR識別子の重複」へ。受け付ける2形式の表・不一致となる
     形式・判定順に依存しない理由を追記。
   - 「issue #133以降、この検知が拾うもの」節を追加（残る2つの衝突経路と、対応する類型A-1 / A-2）。
   - 「JSONのキー名を改名していないこと」節を追加。
   - 「影響範囲」へ issue #133 のエントリを追記（**過去エントリは書き換えない**）。
   - 「未決定事項」の「DDR以外の連番リソースは対象外」を、新方式を踏まえた表現へ。
2. `.claude/docs/ddr/i0133-01-DDR識別子はissue番号ベースにし連番採番をやめる.md`（新規）
   - 背景 / 決定7項目 / 却下した案4件 / JSONキーを改名しなかった理由 / 受け入れたトレードオフ。

## 検証

- `bash .claude/scripts/src/extract-frontmatter.sh .` が新DDRを取りこぼさないこと。
- `search-frontmatter.sh --type ddr` から新DDRを引けること（`doc-search` の経路が通ること）。
- `.claude/docs/README.md` のDDR一覧のリンクが実在のファイルを指していること。
