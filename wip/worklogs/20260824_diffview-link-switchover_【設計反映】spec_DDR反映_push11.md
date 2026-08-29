---
title: worklog: 【設計反映】Diffviewリンク出し分けのspec/DDR反映
type: log
description: issue #205 フェーズ4の作業ログ。個別反映計画の作成からspec/DDR/mcp-fallback参照資料への反映まで
tags: [worklog, phase4, issue-mr-flow]
keywords: [spec, DDR, 提供関数表, 未決定事項, mcp-fallback, get_mr_diff_url, resolve_mr_number_for_head]
---

# worklog: 【設計反映】Diffviewリンク出し分けのspec/DDR反映

対象: issue #205「defaultブランチとの差分リンクをPR/MRのDiffviewへ変更する」（2026-08-24）。
全体作業計画: `wip/plans/diffview-link-switchover.md`
個別作業計画: `wip/plans/【設計反映】Diffviewリンク出し分けのspec_DDR反映.md`
push回数: 11〜

## 試したこと

- flow-id 4-1: 個別反映計画を作成した。実装結果・調査結果の両レポートから、spec「提供関数」表・
  未決定事項・新規DDR・`references/mcp-fallback.md`の4箇所を反映対象として洗い出した。
- **md執筆時に、係り先が変わる事故を自分で作りかけた。** 「完了条件」の項目4が
  「`references/mcp-fallback.md`への追記」という詳細節を指す文になっていたが、その詳細節
  （`### 4.`見出し）を**完了条件の後ろ**へ書いてしまい、「反映対象（洗い出し）」節の下に並ぶ
  はずの項目1〜3から浮いていた。`.claude/rules/docs-workflow.md`が警告する「既存の記述を
  残したまま周囲を編集したときの係り先崩れ」と同じ形の事故で、今回は新規執筆時に自分で
  混入させた。HTML側を先に正しい順序（反映対象の下に1〜4を並べる）で書いていたため、
  md/html突き合わせで気づき、mdの`### 4.`ブロックを正しい位置（DDR節の直後）へ移動して
  修正した。**HTMLを後から書く運用にしていたら、この崩れはHTML側にも複製されて
  見逃していた可能性がある。**

## うまくいったこと

- HTML作成時に見出し構造（h2/h3）をmdと突き合わせて確認する手順が、上記の係り先崩れを
  実際に検出した。

## ダメだったこと

- 特になし。

## 次の一歩

- 個別反映計画の敵対的レビュー（フェーズ4・1回目、計画時）を実行する。
- 指摘へ対応後、spec「提供関数」表・未決定事項・DDR `i0205-01`・`references/mcp-fallback.md`
  への反映を実施する。

---
