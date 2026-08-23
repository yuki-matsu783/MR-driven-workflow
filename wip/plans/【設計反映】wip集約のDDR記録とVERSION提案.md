---
title: 個別反映計画 - wip集約のDDR記録とVERSION提案
type: plan
description: issue #165フェーズ4。wip/命名理由のDDR化・.claude/VERSION MAJOR増分の提案・既存導入先向け移行手順の記述先決定と記述の3点を反映する個別計画
tags: [issue-mr-flow, ddr, distribution-assets, wip]
keywords: [wip, ddr, VERSION, MAJOR, 移行手順, install-to-project, distribution-assets, cleanup-task]
---

# 個別反映計画: wip集約のDDR記録とVERSION提案（issue #165 フェーズ4）

## 対象（`wip/reports/20260823_transient-brewing-pelican_wip集約実装結果.md`「設計への反映」より）

`.claude/docs/spec/cleanup-task.md`の未決定事項更新（項目2）は、mainマージ解消の過程で既に
`i0165-01`（DDR）とあわせて対応済み（「解消・issue #165」と明記）。本計画は残る3項目を扱う。

1. **`wip/`という名前の採用理由をDDRとして記録する**（受け入れ条件7）。`flow/` `tasks/` `work/`
   `scratch/`を採らなかった理由を含む。
2. **`.claude/VERSION`のMAJORインクリメントを提案する**（実際の値変更は行わない。人間の判断が
   必要——`.claude/docs/spec/distribution-assets.md`「AIが独断で上げない」）。
3. **既存導入先向けの移行手順**（`plans/` `worklog/`を残したまま`wip/`が追加される状態への対処）の
   記述先を決め、記述する。`i0165-01`「未決定事項」が本タスクへ委譲している論点。

## 方針

### 1. DDR新規作成

`.claude/docs/ddr/i0165-02-タスク単位ディレクトリの集約名はwip-を採用しflow-tasks-work-scratchを採らない.md`
として新規作成する（issue #165の2件目のDDRのため枝番02。既存`i0165-01`は上記のとおり別論点
「フォールバック既定値の後方互換」を扱うため独立させる）。

理由（草案）:
- **`wip/`（Work In Progress）**: 「未完了・一時的で正史ではない」という寿命をそのまま表す、
  広く認知された慣用語。既存の`.claude/`語彙と衝突しない。
- `flow/`を採らない理由: 「フロー」という語は本リポジトリで一貫して手順そのもの
  （`.claude/skills/issue-mr-flow/SKILL.md`）を指すため、`flow/`ディレクトリは「フローの
  ドキュメント」ではなく「フローが生成する一時ファイル」と誤読される。
- `tasks/`を採らない理由: 汎用的すぎて「タスク管理（TODO・issue管理）」の含意と衝突しうる。
  「flow-id 5-5で削除される」という寿命の短さが名前から伝わらない。
- `work/`を採らない理由: 最も汎用的で、導入先プロジェクトが独自に持つ「作業用ディレクトリ」
  （ビルド成果物置き場等）と衝突しやすい。寿命の短さも名前から伝わらない。
- `scratch/`を採らない理由: 「使い捨てのメモ」という含意が強すぎる。`wip/plans/` `wip/reports/`は
  人間のレビューを経る正式な成果物であり、「使い捨て」ではなく「一時的だが正式」という性質と
  ズレる。

### 2. `.claude/VERSION`のMAJOR増分提案

`.claude/docs/spec/distribution-assets.md`のMAJOR目安（配布先に手作業を要求する非互換変更）に
該当するかを確認し、該当するなら提案として明記する（**AIが独断で値を書き換えない**）。
提案は本計画の実施結果（`wip/reports/…md`）とPRのdescription/コメントへ記載し、人間の判断を待つ。

### 3. 既存導入先向け移行手順

`.claude/docs/spec/asset-distribution.md`（配布機構の仕様書）に「移行」小節を新設し、
`plans/` `worklog/`を残したまま`.claude/`が更新された配布先が取るべき手順（手動での
`git mv`ディレクトリ移動、または放置してもinstall-to-project.sh側が壊れない設計かどうかの
説明）を記述する。記述先を`asset-distribution.md`にする理由: 配布機構自体の仕様書であり、
`install-to-project.sh`の動作説明と同じ文脈にあるため。

## この計画で決めないこと

- `.claude/VERSION`の実際の値変更（人間の判断）
- 移行手順の実行そのもの（各配布先の作業であり、本リポジトリのタスクではない）

## 検証方法

- 新規DDRのfrontmatter・識別子形式（`i0165-02`）・ファイル名が
  `.claude/rules/markdown-frontmatter.md`「DDRの識別子」規則に一致すること
- `bash .claude/scripts/src/generate-ddr-list.sh`実行後、`--check`が通ること
- `bash .claude/scripts/src/check-doc-references.sh`でDDR参照切れが無いこと
- 単体テスト全件`passed=N failures=0`
