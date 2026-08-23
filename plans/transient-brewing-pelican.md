---
title: 全体作業計画 - plans/worklog/reportsをwip/へ集約しworklogをworklogsへ改名する
type: plan
description: issue #165対応。タスク単位で作られマージ前に消える3ディレクトリ(plans/ worklog/ reports/)をwip/へ集約し、worklogをworklogsへ改名する全体作業計画
tags: [issue-mr-flow, directory-structure, migration]
keywords: [wip, plans, worklog, worklogs, reports, plansDirectory, cleanup-task, install-to-project]
---

# 全体作業計画: plans/worklog/reports を wip/ 配下へ集約し worklog を worklogs へ改名する（issue #165）

## Context

`plans/` `worklog/` `reports/` は、いずれも flow-id 5-1 で一括削除され squash merge により
`main` に残らないという同一の寿命を持つが、リポジトリルート直下に並列で置かれており、その
共通性がディレクトリ構造に表れていない。また `worklog` だけ単数形で `plans` `reports` と
表記が揃っていない。`apply-mr-workflow-to-project` による他プロジェクトへの導入時も、ルートを
2ディレクトリ（`plans/` `worklog/`。`reports/` は未作成）占有している。

この3ディレクトリを `wip/`（Work In Progress）という1つの親ディレクトリへ集約し、
`wip/plans` `wip/worklogs` `wip/reports` へ改名する。`wip` という名前自体が「flow-id 5-1で
削除されmainに残らない」という寿命を表すため、永続ドキュメントを誤って置く事故を名前で防げる。

**ブランチ名について**: 本来 `.mrworkflow.json` の命名規則に従うと `feature-165-...` になるが、
本セッションは実行環境（ハーネス）から `claude/consolidate-wip-directories-ps6f9a` を指定されて
おり、この指定を優先する（環境固有の制約であり、issue-mr-flowのブランチ命名規則からの逸脱は
`HANDOFF.md` に記録する）。

## 事前調査（軽め）で分かったこと

- `.mrworkflow.json`: `plansDir`/`worklogDir`/`reportsDir` で既に外部化されている（既定値
  `"plans"`/`"worklog"`/`"reports"`）。
- `.claude/scripts/src/vcs/Provider.sh` 65-67行目: `.mrworkflow.json` が無い場合のフォールバック
  既定値としても同じ3キーを持つ（`get_workflow_config`）。
- `.claude/scripts/src/cleanup-task.sh`: 212行目付近でこの3キーを読んで削除対象ディレクトリを
  決定している。**ただし `KEEP_PATHS=("worklog/TEMPLATE.md")` は設定値から組み立てられておらず
  ハードコードされたリテラルパス**。`worklogDir` を `wip/worklogs` に変えると、このパスは
  実際のファイルパス `wip/worklogs/TEMPLATE.md` と一致しなくなり、**TEMPLATE.mdが誤って
  削除される**。ここは動的化（`"${worklog_dir}/TEMPLATE.md"`のように組み立てる）が必要。
  `REVIEW-POINTS.md` はどの階層でもファイル名一致で除外する設計（`KEEP_BASENAMES`）のため、
  こちらは変更不要と見込まれる。
- `.claude/settings.json` の `plansDirectory: "./plans"`、`.gemini/settings.json` の
  `general.plan.directory: "./plans"` が、Planモードの出力先を決めている。**ネストしたパス
  （`./wip/plans`）が実際に機能するかは未検証**であり、受け入れ条件1が要求する実機検証が必要
  （フェーズ2の最優先タスク）。
- `.claude/skills/apply-mr-workflow-to-project/scripts/install-to-project.sh`:
  140-141行目付近で導入先ルートへ `plans/` `worklog/` を直接 `mkdir -p`、165-166行目付近で
  `.gitkeep` を置いている。`reports/` は作成されていない。ここを `wip/` 1つの作成＋配下3つの
  構成へ変更する。
- `.claude/skills/apply-mr-workflow-to-project/assets/` はGit管理外のビルド生成物
  （`sync-assets.sh` が `.claude`/`.gemini` から都度再生成）であり、本タスクで直接手を入れる
  対象ではない。
- ドキュメント側の参照はファイル数ベースで確認済み: `plans/` が55ファイル、`worklog`が
  約40ファイル、`reports/`が約38ファイル（重複あり）。**うち `.claude/docs/ddr/` 配下
  （21ファイル前後）は本文を変更しない**（DDR本文は不変。`.claude/rules/docs-workflow.md`）。
  **`.claude/docs/spec/` 配下（7ファイル前後）は「現在の状態を説明する節」と「point-in-time の
  changelog節」が同居しているため、節単位で見て前者のみ更新する**。それ以外
  （`.claude/rules/*.md`, `.claude/skills/*/SKILL.md`, `.claude/scripts/`配下, ルート直下の
  `README.md`/`AGENTS.md`等, `.github/`/`.gitlab/`テンプレート）は「現在の状態」の記述なので
  素直に新パスへ更新してよい。

## フェーズ構成

### フェーズ2〈調査〉

**最優先**: 受け入れ条件1の実機検証。`.claude/settings.json`の`plansDirectory`を一時的に
`"./wip/plans"`へ変更し、Planモードでダミーの全体作業計画を作成して実際の出力先を確認する。
`.gemini/settings.json`の`general.plan.directory`も同様に検証する（Gemini CLI自体は本実行環境に
無いため、設定ファイルの記法・ドキュメント上の裏付けで代替検証する可能性がある。裏付けが取れない
場合はその旨をDDRに明記する）。ネストパスが通らない場合は設計を見直す（`plans`だけルートに残す等）。
検証結果と結論はDDRとして記録する（フェーズ4で正式反映、フェーズ2時点ではworklogへ記録）。

あわせて、上記「事前調査」で洗い出した参照ファイル一覧をより正確に棚卸しし、DDR/spec-changelogの
除外境界（節単位）を個別作業計画に落とし込めるレベルまで具体化する。

### フェーズ3〈作業〉（設計・実装・テスト）

1. **設定・スクリプトの変更**（実装の核）
   - `.mrworkflow.json`: `plansDir: "wip/plans"`, `worklogDir: "wip/worklogs"`,
     `reportsDir: "wip/reports"`
   - `.claude/scripts/src/vcs/Provider.sh`: `get_workflow_config`のフォールバック既定値を同期
   - `.claude/scripts/src/cleanup-task.sh`: `KEEP_PATHS`を設定値から動的に組み立てる形へ修正
     （ハードコード除去）。`is_safe_relative_dir`がネストしたパス（`wip/plans`のような`/`を含む
     相対パス）を正しく安全と判定できるかも確認する。
   - `.claude/settings.json`: `plansDirectory: "./wip/plans"`
   - `.gemini/settings.json`: `general.plan.directory: "./wip/plans"`
   - `.claude/skills/apply-mr-workflow-to-project/scripts/install-to-project.sh`:
     `mkdir -p`対象を`wip/` `wip/plans` `wip/worklogs` `wip/reports`へ、`.gitkeep`配置も見直す
2. **ディレクトリ移動**: `git mv plans wip/plans` `git mv worklog wip/worklogs`
   `git mv reports wip/reports`（履歴を追える形にする。受け入れ条件6）
3. **ドキュメント更新**: 上記の棚卸しに従い、DDR本文・spec changelogを除外しつつ「現在の状態」を
   説明する箇所を新パスへ更新する（`.claude/rules/directory-structure.md`のツリー構造・
   `index.md`（Repository Map）を含む。受け入れ条件8）。一括`sed`は使わない（受け入れ条件5）。
4. **テスト**: `test_cleanup_task.sh` / `test_search_frontmatter.sh` / `test_vcs_provider.sh`を
   新パス前提で実行・必要なら更新（受け入れ条件2, 3）。`install-to-project.sh`の動作確認
   （受け入れ条件4）。

### フェーズ4〈反映〉

- **設計反映**: フェーズ2の実機検証結果・フェーズ3の設計判断（`wip/`という名前を採用し
  `flow/` `tasks/` `work/` `scratch/`を採らなかった理由。特に`flow/`は「フロー」という語が
  このリポジトリで一貫して手順そのもの（`issue-mr-flow/SKILL.md`）を指すため誤誘導になる、という
  判断を含む）をDDRとして記録する（受け入れ条件7）。`.claude/docs/spec/`該当箇所の更新。
- **AIアセット反映**: 作業中に気づいたルール・スキルの不備があれば反映。
- **実装反映**: フェーズ3のレビューで持ち越した不具合があれば対応。

## 敵対的レビューの実施方針（ユーザー指示）

このセッションは非対話的実行環境（Claude Code on the webのリモート実行環境）であり、ユーザーから
「各フェーズでの計画時に一度、作業実施毎に一度ずつ、敵対的レビューを自動で行い、指摘に対する修正を
行いながら進める」よう明示的な指示を受けている。`.claude/skills/issue-mr-flow/SKILL.md`の
「敵対的レビューの位置づけ」節が定める非対話セッションでの自律起動の例外、および
`.claude/rules/docs-workflow.md`の非対話的実行環境での人間レビュー待ちステップ省略規定に従い、
各フェーズの計画確定後・各フェーズの作業実施後（commit/push相当のタイミング）に
`adversarial-review`スキル相当のレビュー（`adversarial-reviewer`サブエージェント）を実施し、
指摘への対応（対応または理由を添えた見送り）を行ってから次フェーズへ進む。人間のレビュー待ち
ループ（2-3/2-4等）はスキップし、その旨を`HANDOFF.md`に記録する。

## 検証方法

- `bash .claude/scripts/test/test_cleanup_task.sh`
- `bash .claude/scripts/test/test_search_frontmatter.sh`
- `bash .claude/scripts/test/test_vcs_provider.sh`
- `bash -n`によるスクリプトの構文チェック（変更した`.sh`全て）
- `.claude/settings.json`の`plansDirectory`変更後、実際にPlanモードでの出力先を確認
- `grep -rn "^plans/\|[^a-zA-Z0-9_.-]plans/\|worklog\|reports/"` 等で新パスへの更新漏れ・
  DDR本文への意図しない書き換えが無いことを確認
