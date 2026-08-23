---
title: 【設計】【実装】【テスト】wip集約とworklogs改名
type: plan
description: issue #165フェーズ3。plans/worklog/reportsをwip/plans, wip/worklogs, wip/reportsへ集約し、設定・スクリプト・ドキュメントの参照を更新する実装計画
tags: [issue-mr-flow, directory-structure, migration]
keywords: [wip, plans, worklog, worklogs, reports, git mv, cleanup-task, install-to-project, KEEP_PATHS]
---

# 【設計】【実装】【テスト】wip集約とworklogs改名

## 前提（合意状況）

- 全体作業計画: `plans/transient-brewing-pelican.md`（flow-id 1-5でユーザー承認済み）
- フェーズ2調査結果: `reports/20260823_transient-brewing-pelican_plansDirectoryネストパス検証.md`
  （`.claude/settings.json`の`plansDirectory: "./wip/plans"`は実際に機能することを実機確認済み。
  対照実験はインフラ一時停止のため保留中で、結果が出次第この計画・DDRへ反映する）

## この計画で何をするか

`plans/` `worklog/` `reports/` を `wip/plans` `wip/worklogs` `wip/reports` へ移動し、
それを参照する設定・スクリプト・ドキュメントをすべて新パスへ更新する。

## 変更対象

| 領域 | 操作 | 何をするか |
|---|---|---|
| `.mrworkflow.json` | 変更 | `plansDir: "wip/plans"`, `worklogDir: "wip/worklogs"`, `reportsDir: "wip/reports"` |
| `.claude/scripts/src/vcs/Provider.sh` | 変更 | `get_workflow_config`のフォールバック既定値（65-67行目）を同期 |
| `.claude/scripts/src/cleanup-task.sh` | 変更 | `KEEP_PATHS`のハードコード除去（設定値から動的に組み立てる） |
| `.claude/settings.json` | 変更 | `plansDirectory: "./wip/plans"` |
| `.gemini/settings.json` | 変更 | `general.plan.directory: "./wip/plans"` |
| `.claude/skills/apply-mr-workflow-to-project/scripts/install-to-project.sh` | 変更 | `mkdir -p`対象（162-163行目）・`.gitkeep`配置（187-188行目）を`wip/`1つ＋配下3構成へ |
| `plans/` `worklog/` `reports/` 実体 | 移動（git mv） | `wip/plans` `wip/worklogs` `wip/reports` へ |
| ドキュメント参照（約58/44/39ファイル、DDR・spec changelogを除く） | 変更 | 現在の状態を説明する箇所のみ新パスへ |
| `.claude/scripts/test/`配下の該当テスト | 変更 | 新パス前提での動作確認・必要な修正 |
| `.claude/VERSION` | 変更（提案） | MAJORインクリメント（フェーズ4で最終決定） |

## 方針

### 1. KEEP_PATHSの動的化（最優先で対処する既知の欠陥）

`cleanup-task.sh`の`KEEP_PATHS=("worklog/TEMPLATE.md")`はハードコードされたリテラルパスであり、
`worklogDir`を`wip/worklogs`に変えると実際のファイルパス`wip/worklogs/TEMPLATE.md`と一致しなくなり
`TEMPLATE.md`が誤削除される。

**既存の記述を置き換える場合の置換前後（コード上の対応箇所）**

置換前:
```bash
readonly -a KEEP_PATHS=(
  "worklog/TEMPLATE.md"
)
```

置換後（`main`関数内で`worklog_dir`を読んだ後にKEEP_PATHSを構築する形へ変更。`readonly`配列の
即時初期化ができなくなるため、`main`内で`declare -a KEEP_PATHS=("${worklog_dir}/TEMPLATE.md")`の
ように書き換え、以降の関数（`is_keep_path`等）はグローバル変数として同じ配列を参照し続ける
既存の設計を保つ）:
```bash
# トップレベルの readonly 初期化を削除し、main() 内で dirs_tsv 読み込み後に以下を追加
KEEP_PATHS=("${target_dirs[1]}/TEMPLATE.md")   # target_dirs[1] は worklogDir
```
`is_safe_relative_dir`のテスト・`is_keep_path`のテストが、この変更後も同じ入出力になることを
`test_cleanup_task.sh`で確認する。

### 2. ディレクトリ移動

1. `mkdir -p wip` で親ディレクトリを先に作成する（`git mv`は中間ディレクトリを作らないため）。
2. 移動先が存在しないことを確認してから移動する:
   ```bash
   [ ! -e wip/plans ] && [ ! -e wip/worklogs ] && [ ! -e wip/reports ]
   git mv plans wip/plans
   git mv worklog wip/worklogs
   git mv reports wip/reports
   ```
3. 移動後、`wip/plans/REVIEW-POINTS.md` `wip/reports/REVIEW-POINTS.md`
   `wip/worklogs/TEMPLATE.md`が存在することを確認する。

### 3. 設定・スクリプトの変更

上記「変更対象」表のとおり。`install-to-project.sh`は162-163行目の`mkdir -p`を
`mkdir -p "${DEST_DIR}/wip/plans" "${DEST_DIR}/wip/worklogs" "${DEST_DIR}/wip/reports"`へ、
187-188行目の`.gitkeep`を`wip/plans/.gitkeep` `wip/worklogs/.gitkeep` `wip/reports/.gitkeep`へ
変更する（`reports`にも`.gitkeep`を新設。現状reportsは作られていないため受け入れ条件4を満たす）。

### 4. ドキュメント更新

対象は`git grep -lI 'plans/\|worklog\|reports/' -- '*.md' '*.sh' '*.json' '*.html'`の結果を起点に、
以下の除外規則を適用する。

| 対象 | 扱い |
|---|---|
| `.claude/docs/ddr/*.md` | **本文は変更しない**（不変。frontmatterの`status`等のみ更新可能） |
| `.claude/docs/spec/*.md` | 節単位で判断。「現在の状態を説明する節」は更新、「point-in-time changelog節」（過去issueごとの影響範囲・変更履歴として書かれた節）は変更しない |
| それ以外（`.claude/rules/`, `.claude/skills/*/SKILL.md`・`assets/`, `.claude/scripts/`, `.claude/hooks/`, `.claude/agents/`, ルート直下, `.github/`, `.gitlab/`） | 現在の状態を説明する記述として、新パスへ更新する |

一括`sed`は使わない。ファイルごとに内容を確認しながらEdit/Writeで更新する。
`.claude/rules/directory-structure.md`のツリー構造・`index.md`（Repository Map）も対象に含める
（受け入れ条件8）。

### 5. テスト

少なくとも以下を実行し、`passed=N failures=0`を確認する。

```
bash .claude/scripts/test/test_cleanup_task.sh
bash .claude/scripts/test/test_search_frontmatter.sh
bash .claude/scripts/test/test_vcs_provider.sh
bash .claude/scripts/test/test_install_to_project.sh
bash .claude/scripts/test/test_check_base_sync.sh
bash .claude/scripts/test/test_collect_review_points.sh
bash .claude/scripts/test/test_extract_frontmatter.sh
bash .claude/scripts/test/test_session_start.sh
```

変更した`.sh`全てに`bash -n`で構文チェックを行う。

## やらないこと（スコープ外）

- DDR本文の書き換え（不変）
- `.claude/docs/spec/`内のpoint-in-time changelog節の書き換え
- `.claude/skills/apply-mr-workflow-to-project/assets/`への直接編集（生成物。`sync-assets.sh`が
  `.claude`/`.gemini`から再生成する）
- 既に`apply-mr-workflow-to-project`で導入済みの他プロジェクトの実際の移行作業
- `.claude/VERSION`の最終インクリメント（提案はフェーズ4で行うが、確定は人間の判断とする）

## 検証

```bash
bash .claude/scripts/test/test_cleanup_task.sh
bash .claude/scripts/test/test_search_frontmatter.sh
bash .claude/scripts/test/test_vcs_provider.sh
bash .claude/scripts/test/test_install_to_project.sh
bash .claude/scripts/test/test_check_base_sync.sh
bash .claude/scripts/test/test_collect_review_points.sh
bash .claude/scripts/test/test_extract_frontmatter.sh
bash .claude/scripts/test/test_session_start.sh
git diff $(git merge-base main HEAD) -- .claude/docs/ddr/   # 空であること
```

合格条件: 上記すべてのテストが`passed=N failures=0`。`wip/plans` `wip/worklogs` `wip/reports`が
実在し`REVIEW-POINTS.md`・`TEMPLATE.md`を含む。`git mv`による移動なのでファイル履歴が
`git log --follow`で追える。DDR本文への意図しない書き換えが無い。

## issueの受け入れ条件との対応

| 受け入れ条件 | この計画での対応箇所 |
|---|---|
| 1. plansDirectoryのネストパス対応の実機検証 | フェーズ2で完了（本計画の前提） |
| 2. test_cleanup_task.shが新パスで通る | 方針1・5 |
| 3. test_search_frontmatter.sh / test_vcs_provider.shが通る | 方針5 |
| 4. install-to-project.shがwip/1つ＋配下3構成を作る | 方針3 |
| 5. DDR本文・spec changelogを書き換えない | 方針4 |
| 6. git mvで移動する | 方針2 |
| 7. wip/命名判断をDDRとして記録 | フェーズ4（本計画のスコープ外） |
| 8. directory-structure.md・index.mdが新構成を反映 | 方針4 |
