---
title: i0165-02. タスク単位ディレクトリの集約名はwip/を採用しflow/tasks/work/scratchを採らない
type: ddr
description: plans/worklog/reportsを1つの親ディレクトリへ集約する際、候補名flow/tasks/work/scratchではなくwip/（Work In Progress）を採用した理由を記録する決定
tags: [ddr, wip, naming, directory-structure]
keywords: [wip, flow, tasks, work, scratch, 命名, ディレクトリ構成, issue-mr-flow, 寿命]
---

# i0165-02. タスク単位ディレクトリの集約名はwip/を採用しflow/tasks/work/scratchを採らない

## 背景

issue #165で、タスク単位（issue／ブランチ単位）の作業ドキュメント置き場である`plans/` `worklog/`
`reports/`を、1つの親ディレクトリへ集約することにした。この3ディレクトリはいずれも
flow-id 5-5（次タスクのための片付け）で一括削除され、squash mergeにより`main`へは残らないという
同一の寿命を持つが、リポジトリルート直下に並列で置かれており、その共通性がディレクトリ構造に
表れていなかった。

集約先の親ディレクトリ名として、`wip/` `flow/` `tasks/` `work/` `scratch/`の5候補を比較検討した。

## 決定

**`wip/`（Work In Progress）を採用する。**

## 理由

- **`wip/`は「未完了・一時的で正史ではない」という寿命をそのまま表す、広く認知された慣用語である。**
  多くのプロジェクトで「作業中のブランチ・ドキュメント」を指す語として定着しており、初見でも
  意味を推測しやすい。既存の`.claude/`語彙（`issue-mr-flow`・`spec`・`ddr`等）とも衝突しない。
- **`flow/`を採らない理由**: 「フロー」という語は本リポジトリで一貫して手順そのもの
  （`.claude/skills/issue-mr-flow/SKILL.md`）を指す。`flow/`という名前のディレクトリを見た人は
  「フローの手順定義」を連想しやすく、実際には「フローが生成する一時ファイル」であるという実体と
  食い違う。
- **`tasks/`を採らない理由**: 汎用的すぎて「タスク管理（TODO・issue管理）」の含意と衝突しうる。
  「flow-id 5-5で削除される」という寿命の短さが名前から伝わらない。
- **`work/`を採らない理由**: 最も汎用的な語であり、導入先プロジェクトが独自に持つ「作業用
  ディレクトリ」（ビルド成果物置き場・一時出力先等）と衝突しやすい。寿命の短さも名前から伝わらない。
- **`scratch/`を採らない理由**: 「使い捨てのメモ」という含意が強すぎる。`wip/plans/` `wip/reports/`
  は人間のレビュー（flow-idごとのレビュー往復）を経る正式な成果物であり、「使い捨て」ではなく
  「一時的だが正式」という性質を持つ。`scratch/`はこの性質とズレる。

## 却下案

上記「理由」で述べたとおり、`flow/` `tasks/` `work/` `scratch/`の4案はいずれも却下した。

## 未決定事項の引き取り

`i0165-01`（フォールバック既定値の後方互換）の「未決定事項」節が委譲していた2論点を、
本DDRの反映作業の一部として引き取った。**うち移行手順は解消したが、`.claude/VERSION`の
増分は未解消のまま残っている**（下記「未決定事項」参照）。

- **移行手順**（既存導入先が旧`plans/` `worklog/`を残したまま`wip/`が追加される場合の対処）は
  `.claude/docs/spec/asset-distribution.md`「移行」小節（恒久の一般手順）と、
  `.claude/docs/spec/distribution-assets.md`「影響範囲 > issue #165」エントリ（今回固有の
  具体的手順）の2箇所に分けて記述し、**解消した**。
- **`.claude/VERSION`の増分**は、非対話的実行環境における例外規定
  （`distribution-assets.md`「増分の決め方」の「例外（非対話的セッション）」節。issue #160が
  先例）に従い、AIエージェントが`MAJOR`（`0.3.0`→`1.0.0`）の**適用を試みたが、実行環境の
  権限クラシファイアにより`.claude/VERSION`への書き込みそのものがブロックされ、値の変更は
  実施できなかった**。**解消していない**（下記「未決定事項」参照）。根拠と、適用できず
  提案のみに留まった事実は`distribution-assets.md`「影響範囲 > issue #165」エントリへ記録した。

## 未決定事項

- **`.claude/VERSION`（および`.gemini/VERSION`）のMAJOR増分（`0.3.0`→`1.0.0`）が未適用のまま
  残っている。** 上記のとおりAIエージェントによる適用は実行環境の制約でブロックされたため、
  人間が別経路（ローカル環境・GitHub UIでの直接編集等）で適用するか、このまま「提案のみ」で
  進めるかを、人間が判断する必要がある。判断が付くまで、`.claude/VERSION`は`0.3.0`のまま
  据え置かれ、issue #165が含む非互換な配置場所変更（`plans/`→`wip/plans/`等）は
  `distribution-assets.md`「増分の決め方」が目安とするMAJOR表示を伴わずに配布されうる。

## 影響範囲

- リポジトリ全体のディレクトリ構成: `plans/` `worklog/` `reports/` → `wip/plans/` `wip/worklogs/`
  `wip/reports/`（改名は本DDRの対象外で、issue #165実装フェーズ（flow-id 3-6）で実施済み）。
- `.claude/docs/spec/asset-distribution.md`「移行」小節・`.claude/docs/spec/distribution-assets.md`
  「影響範囲 > issue #165」エントリ（本DDRの反映作業として新設）。
