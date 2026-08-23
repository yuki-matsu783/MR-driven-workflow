---
title: 全体作業計画 - plans/worklog/reportsをwip/へ集約しworklogをworklogsへ改名する
type: plan
description: issue #165対応。タスク単位で作られマージ前に消える3ディレクトリ(plans/ worklog/ reports/)をwip/へ集約し、worklogをworklogsへ改名する全体作業計画
tags: [issue-mr-flow, directory-structure, migration]
keywords: [wip, plans, worklog, worklogs, reports, plansDirectory, cleanup-task, install-to-project]
---

# 全体作業計画: plans/worklog/reports を wip/ 配下へ集約し worklog を worklogs へ改名する（issue #165）

## Context

`plans/` `worklog/` `reports/` は、いずれも flow-id 5-4（次タスクのための片付け）で一括削除され
squash merge により `main` に残らないという同一の寿命を持つが、リポジトリルート直下に並列で
置かれており、その共通性がディレクトリ構造に表れていない。また `worklog` だけ単数形で
`plans` `reports` と表記が揃っていない。`apply-mr-workflow-to-project` による他プロジェクトへの
導入時も、ルートを2ディレクトリ（`plans/` `worklog/`。`reports/` は未作成）占有している。

この3ディレクトリを `wip/`（Work In Progress）という1つの親ディレクトリへ集約し、
`wip/plans` `wip/worklogs` `wip/reports` へ改名する。`wip` という名前自体が「flow-id 5-4で
削除されmainに残らない」という寿命を表すため、永続ドキュメントを誤って置く事故を名前で防げる。

**ブランチ名について**: 本来 `.mrworkflow.json` の命名規則に従うと `feature-165-...` になるが、
本セッションは実行環境（ハーネス）から `claude/consolidate-wip-directories-ps6f9a` を指定されて
おり、この指定を優先する（環境固有の制約であり、issue-mr-flowのブランチ命名規則からの逸脱は
`HANDOFF.md` に記録する）。

## フェーズ2で確認する事項（結果は reports/ 側の正文へ記録する）

- `.claude/settings.json` の `plansDirectory: "./plans"`、`.gemini/settings.json` の
  `general.plan.directory: "./plans"` にネストしたパス（`./wip/plans`）を設定した場合、
  Planモードの出力が実際にそこへ向くか（受け入れ条件1・最優先）。
- `.claude/scripts/src/cleanup-task.sh` の `KEEP_PATHS=("worklog/TEMPLATE.md")` が
  設定値から組み立てられておらずハードコードされている問題（`worklogDir` を `wip/worklogs` に
  変えると `TEMPLATE.md` が誤削除される）への対処方法。
- `.claude/skills/apply-mr-workflow-to-project/scripts/install-to-project.sh` の
  `mkdir -p "${DEST_DIR}/plans"` `mkdir -p "${DEST_DIR}/worklog"`（162-163行目）、
  `touch "${DEST_DIR}/plans/.gitkeep"` `touch "${DEST_DIR}/worklog/.gitkeep"`（187-188行目）を
  `wip/` 1つ＋配下3構成へどう変更するか。
- ドキュメント側の参照ファイルの正確な棚卸し（フェーズ3の個別作業計画に落とし込むレベルまで）。
  `git grep -lI 'plans/' -- '*.md' '*.sh' '*.json'` 等、3ディレクトリ自身を除いた実測件数は
  `plans/`参照58ファイル・`worklog`参照44ファイル・`reports/`参照39ファイル
  （うち `.claude/docs/ddr/*.md` 26ファイルは本文変更しない、`.claude/docs/spec/*.md` 8ファイルは
  節単位の判断が必要）。この数はフェーズ2時点の実測であり、フェーズ3実施直前に同じコマンドで
  数え直す。

## フェーズ構成

### フェーズ2〈調査〉

**最優先**: 受け入れ条件1の実機検証。**同一セッション内での`.claude/settings.json`書き換え→
`EnterPlanMode`再入という方式は使わない**（下記「調べ方についての決定」参照）。かわりに
**新規の別セッション**（`mcp__Claude_Code_Remote__create_session`等）でこのブランチをチェックアウト
させ、そのセッションでPlanモードに入った際の実際の出力先を確認する。加えて対照実験として、
存在しない別のフラットなパス（例 `./plans2`）へ変更した場合に提示パスが変わるかも確認し、
「ネストパス非対応」と「設定変更がそもそも読み込まれていない」を区別できるようにする。

`.gemini/settings.json`の`general.plan.directory`も同様に検証する（Gemini CLI自体は本実行環境に
無いため、設定ファイルの記法・ドキュメント上の裏付けで代替検証する可能性がある。裏付けが取れない
場合はその旨をDDRに明記する）。

**ネストパスが機能しないと判明した場合は、実装を進めず停止する。** 代替案（`plans`のみルートに
残す等）を人間へ提示し、PRコメントまたはissueコメントで判断を仰いでから再開する（AIが独断で
受け入れ条件を変更した設計へ進まない）。

検証結果は `reports/日付_transient-brewing-pelican_plansDirectoryネストパス検証.md` へ記録する
（結果の正文はreports側。試行錯誤の詳細はworklogへ）。結論は最終的にDDRとして記録する
（フェーズ4で正式反映）。

あわせて、上記「フェーズ2で確認する事項」で洗い出した参照ファイル一覧をより正確に棚卸しし、
DDR/spec-changelogの除外境界（節単位）を個別作業計画に落とし込めるレベルまで具体化する。

#### 調べ方についての決定

計画レビュー（敵対的レビュー1周目）で、同一セッション内での設定書き換え→Planモード再入という
当初の検証方法には2つの欠陥が指摘された。

1. ハーネスが計画ファイルのパスをセッション開始時点で決めている場合、ネストパスが完全に対応して
   いても提示パスは変わらず「失敗」と誤判定しうる（偽陰性）。
2. 検証のためのPlanモード再入が、DDR `i0009-01`（planツールの利用は全体作業計画に限定し
   issue（ブランチ）につき1回）に反し、承認済みの全体作業計画を上書きする・2つ目の全体作業計画を
   作ってしまう恐れがある（DDR `i0000-06` が記録する「同一セッション内の再入ではハーネスが
   1回目のパスを提示し続ける」という既知の挙動とも整合する）。

実際にこのセッション内で試したところ、まさに(1)(2)が起きた（既存の
`plans/transient-brewing-pelican.md` がそのまま提示され、設定変更は反映されなかった）。
このため、クリーンな検証は新規セッションで行う方針へ切り替えた。

## フェーズ3〈作業〉（設計・実装・テスト）

1. **設定・スクリプトの変更**（実装の核）
   - `.mrworkflow.json`: `plansDir: "wip/plans"`, `worklogDir: "wip/worklogs"`,
     `reportsDir: "wip/reports"`
   - `.claude/scripts/src/vcs/Provider.sh`: `get_workflow_config`のフォールバック既定値
     （65-67行目）を同期
   - `.claude/scripts/src/cleanup-task.sh`: `KEEP_PATHS`を設定値から動的に組み立てる形へ修正
     （ハードコード除去）。`is_safe_relative_dir`がネストしたパス（`wip/plans`のような`/`を含む
     相対パス）を正しく安全と判定できるかも確認する。空になった `wip/plans` 自体が
     `cleanup-task.sh`によってディレクトリごと削除される（`REVIEW-POINTS.md`・`TEMPLATE.md`を
     持たない配布先で起きうる）点も踏まえ、`install-to-project.sh`側の`.gitkeep`配置を検討する。
   - `.claude/settings.json`: `plansDirectory: "./wip/plans"`（フェーズ2の検証結果が
     肯定的だった場合のみ適用）
   - `.gemini/settings.json`: `general.plan.directory: "./wip/plans"`
   - `.claude/skills/apply-mr-workflow-to-project/scripts/install-to-project.sh`:
     162-163行目の`mkdir -p`対象を`wip/` `wip/plans` `wip/worklogs` `wip/reports`へ、
     187-188行目の`.gitkeep`配置も見直す
2. **ディレクトリ移動**: **先に`mkdir -p wip`で親ディレクトリを作る**（`git mv`は中間ディレクトリを
   作らないため、`wip/`が無い状態での`git mv plans wip/plans`は`fatal: renaming 'plans' failed:
   No such file or directory`で失敗する）。続けて `git mv plans wip/plans`
   `git mv worklog wip/worklogs` `git mv reports wip/reports`を、**移動先が存在しないことを
   `[ ! -e wip/plans ]`等で確認してから**実行する（移動先が既存ディレクトリの場合、`git mv`は
   エラーにならず配下へ入れてしまう＝`wip/plans/plans`のような二重ネストが無言で発生するため。
   履歴を追える形にする。受け入れ条件6）。
3. **ドキュメント更新**: 上記の棚卸しに従い、DDR本文・spec changelogを除外しつつ「現在の状態」を
   説明する箇所を新パスへ更新する（`.claude/rules/directory-structure.md`のツリー構造・
   `index.md`（Repository Map）・`.claude/hooks/session-start.sh`・`.claude/hooks/otel/session-start.sh`・
   `.claude/agents/issue-mr-resume.md`・`.claude/skills/issue-mr-flow/assets/plans.template.html`・
   `.claude/skills/issue-mr-flow/assets/reports.template.html`・
   `.claude/skills/canvas-report/assets/canvas-report.html`を含む。受け入れ条件8）。
   一括`sed`は使わない（受け入れ条件5）。対象ファイルの列挙は手書きではなく
   `git grep -lI 'plans/\|worklog\|reports/' -- '*.md' '*.sh' '*.json' '*.html'`の結果を起点にする。
4. **テスト**: 少なくとも `test_cleanup_task.sh` / `test_search_frontmatter.sh` /
   `test_vcs_provider.sh` / `test_install_to_project.sh` / `test_check_base_sync.sh` /
   `test_collect_review_points.sh` / `test_extract_frontmatter.sh` / `test_session_start.sh` を
   新パス前提で実行・必要なら更新する（受け入れ条件2, 3, 4）。対象は
   `git grep -lI 'plans/\|worklog\|reports/' -- '.claude/scripts/test/*.sh'` で機械的に洗い出す。

## フェーズ4〈反映〉

- **設計反映**: フェーズ2の実機検証結果・フェーズ3の設計判断（`wip/`という名前を採用し
  `flow/` `tasks/` `work/` `scratch/`を採らなかった理由。特に`flow/`は「フロー」という語が
  このリポジトリで一貫して手順そのもの（`issue-mr-flow/SKILL.md`）を指すため誤誘導になる、という
  判断を含む）をDDRとして記録する（受け入れ条件7）。`.claude/docs/spec/`該当箇所の更新。
- **AIアセット反映**: 作業中に気づいたルール・スキルの不備があれば反映。
- **実装反映**: フェーズ3のレビューで持ち越した不具合があれば対応。
- **`.claude/VERSION`の増分提案**: `.claude/docs/spec/distribution-assets.md`は、配布先に手作業を
  要求する非互換変更（配置場所の変更等）を`MAJOR`の目安としている。本タスクはまさに配置場所の
  変更に当たるため、`MAJOR`インクリメントを提案しDDR/報告へ記録する（最終決定は人間）。
  あわせて、既に`apply-mr-workflow-to-project`で導入済みの配布先が`plans/` `worklog/`を残したまま
  `wip/`が追加される（`install-to-project.sh`は上流で消えたファイルを配布先から削除しない）
  移行手順の記述先（specかREADMEか）を決め、記述する。

## この計画で決めないこと（スコープ外）

- DDR本文の書き換え（不変。frontmatterの`status`/`superseded_by`のみ更新可能）
- `.claude/docs/spec/`内のpoint-in-time changelog節の書き換え
- `.claude/skills/apply-mr-workflow-to-project/assets/`への直接編集（`sync-assets.sh`が
  `.claude`/`.gemini`から再生成するビルド生成物のため）
- 既に`apply-mr-workflow-to-project`で導入済みの他プロジェクトの実際の移行作業（本タスクでは
  移行手順の記述先を決めるところまでとし、実際の移行は各プロジェクト側の作業とする）

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

**計画フェーズ1周目のレビューで実際に指摘された欠陥**（本計画へ反映済み）: 上記「調べ方についての
決定」の2件（同一セッション内Planモード再入の危険性）に加え、flow-id 5-1/5-4の誤記、`wip/`親
ディレクトリの作成漏れ、検証コマンドが分岐点SHAとの差分になっていない点、影響を受けるテストの
列挙漏れ、`.claude/VERSION`増分の検討漏れ、ドキュメント棚卸しの漏れ（hooks/agents/assets配下）。

## 検証方法

- `bash .claude/scripts/test/test_cleanup_task.sh` / `test_search_frontmatter.sh` /
  `test_vcs_provider.sh` / `test_install_to_project.sh` / `test_check_base_sync.sh` /
  `test_collect_review_points.sh` / `test_extract_frontmatter.sh` / `test_session_start.sh`
  （いずれも `passed=N failures=0` を確認。フェーズ3実施直前に対象を再度 `git grep -l` で洗い出す）
- `bash -n`によるスクリプトの構文チェック（変更した`.sh`全て）
- `.claude/settings.json`の`plansDirectory`変更後、**新規セッション**で実際にPlanモードでの
  出力先を確認（同一セッション内の再入では確認しない。上記「調べ方についての決定」参照）
- 「DDR本文・spec changelogを書き換えていない」ことの検証は、分岐点SHAを基準に固定して行う:
  `git diff $(git merge-base main HEAD) -- .claude/docs/ddr/` が空であること、
  `git diff $(git merge-base main HEAD) -- .claude/docs/spec/` の差分が「現在の状態を説明する節」
  のみに限られることを確認する
