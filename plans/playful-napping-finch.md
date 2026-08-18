---
title: issue #21 全体作業計画 — .mrworkflow.jsonの各キー説明をREADME等に追記する
type: guide
description: .mrworkflow.jsonの各キー（branchPrefixTemplate/defaultBaseBranch/plansDir/worklogDir/reportsDir/specDirs/ddrDirs）の意味・用途をREADME.mdに追記する全体作業計画
tags: [docs, mrworkflow-json, readme]
keywords: [mrworkflow, branchPrefixTemplate, defaultBaseBranch, plansDir, worklogDir, reportsDir, specDirs, ddrDirs, README]
---

# issue #21 全体作業計画

## Context

`README.md`のセットアップ手順には「リポジトリ固有のブランチ命名規則・`plans/`等の場所は
`.mrworkflow.json`を参照・編集する」という導線のみがあり、各キーの意味・デフォルト値・用途を
説明する記述が存在しない。利用者がキーの意味を知るには実質`.claude/scripts/src/vcs/Provider.sh`の
実装を読む必要があり、設定ファイルの意図を理解しにくい。issue #21はこれを解消するため、
README.md（または適切なドキュメント）に各キーの一覧説明を追加することを求めている。

## 調査結果（Planモード内で完了。フェーズ2の個別調査計画は作成せず、本ファイルに要点を記録する）

- `README.md`には`.mrworkflow.json`への言及が2箇所あるのみで、キーごとの説明はゼロ。
- `index.md`・`.claude/rules/directory-structure.md`・`.claude/rules/docs-workflow.md`には
  `specDirs`/`ddrDirs`について「アプリ追加時に追記を検討する」という用途の言及があるが、
  他のキー（`branchPrefixTemplate`等）への言及はない。
- `Provider.sh`での実際の消費状況:
  - `branchPrefixTemplate`: `new_issue_branch`（ブランチ名生成）、
    `get_issue_number_from_branch`（ブランチ名からissue番号を逆抽出する正規表現生成）で使用。
  - `defaultBaseBranch`: `new_draft_merge_request`・`new_issue_branch`・`get_branch_work_files`で
    デフォルトのベースブランチとして使用。
  - `plansDir`/`worklogDir`/`reportsDir`: `get_branch_work_files`で、ブランチ固有ファイルの
    検出対象パスとして使用。
  - `specDirs`/`ddrDirs`: **現状どの関数からも参照されていない**（`get_workflow_config`の
    デフォルト値定義に含まれるのみ。ドキュメント上の配置場所指定・将来拡張用の位置づけ）。
- `.claude/docs/spec/issue-mr-workflow.md`の「設定項目」節に近い記載があるが、`specDirs`/`ddrDirs`
  のサンプル値が移植元プロジェクト当時のもの（`dev-tools/docs/spec`等）のまま未更新で、現行の
  `.mrworkflow.json`の実値（`.claude/docs/spec`/`.claude/docs/ddr`のみ）と食い違っている。
  README追記では現行の実値を正として書く。

## 方針

このissueはドキュメント追記のみで完結する小規模タスクのため、**フェーズ2（個別調査計画）を
別立てせず、フェーズ3（個別実装計画）から直接進める**（`.claude/skills/issue-mr-flow/SKILL.md`
「フェーズ2,3はどちらかのみ実施する計画となることがありうる」に基づく判断）。調査は本ファイルの
「調査結果」節に集約済み。

フェーズ3では`plans/【実装】.mrworkflow.jsonキー説明をREADMEに追記.md`を作成し、以下を実施する。

1. `README.md`の「セットアップ」節に、`.mrworkflow.json`の各キー（`branchPrefixTemplate`/
   `defaultBaseBranch`/`plansDir`/`worklogDir`/`reportsDir`/`specDirs`/`ddrDirs`）を一覧化した
   説明（キー名・デフォルト値・用途）を追記する。`specDirs`/`ddrDirs`は現状スクリプトから未消費で
   ある旨も明記し、実態との齟齬を避ける。
2. 追記内容が`.mrworkflow.json`の実値・`Provider.sh`の実装と整合していることを確認する。

フェーズ4（反映）では、本調査・実装の要点を`.claude/docs/spec/issue-mr-workflow.md`の「設定項目」節
（現状値が古いまま）に反映するかどうかを検討する（既存の食い違いを併せて修正する好機だが、
spec docの更新範囲はフェーズ3の実装後に個別反映計画で判断する）。

## 完了の定義

README.md等を読むだけで、`.mrworkflow.json`の各キーが何のために使われるか理解できる状態になって
いること（issue #21の受け入れ条件）。
