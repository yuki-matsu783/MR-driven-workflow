---
title: wip集約とworklogs改名 統括レポート
type: report
description: issue #165の全体統括。plans/worklog/reportsをwip/plans, wip/worklogs, wip/reportsへ集約・改名し、関連する設定・スクリプト・約100ファイルのドキュメントを更新した。VERSIONは人間の判断で0.3.0据え置き
tags: [issue-mr-flow, directory-structure, migration, summary]
keywords: [wip, plans, worklog, worklogs, reports, plansDirectory, cleanup-task, install-to-project, DDR, VERSION, 統括レポート]
---

# wip集約とworklogs改名 統括レポート

対象: issue #165（`plans/worklog/reports を wip/ 配下へ集約し worklog を worklogs へ改名する`）。
PR: #178。全体作業計画: `wip/plans/transient-brewing-pelican.md`。

## 結論

`plans/` `worklog/` `reports/` という寿命の短い3ディレクトリを `wip/`（Work In Progress）1つの
親ディレクトリへ集約し、`wip/plans` `wip/worklogs` `wip/reports` へ改名した。関連する設定
（`.mrworkflow.json`・`.claude/settings.json`・`.gemini/settings.json`）・スクリプト
（`cleanup-task.sh`・`Provider.sh`・`install-to-project.sh`）・約100ファイルのドキュメント参照を
更新し、DDR2件（`i0165-01`・`i0165-02`）として設計判断を記録した。issueの受け入れ条件はすべて
満たしている。`.claude/VERSION`のMAJOR増分は、AIエージェントによる適用が実行環境の制約で
できなかった事実を人間へ報告し、「0.3.0で良い」との回答を得て据え置きが確定した。

## 何を変えたか

- **ディレクトリ改名**: `git mv plans wip/plans`・`git mv worklog wip/worklogs`・
  `git mv reports wip/reports`（先に`mkdir -p wip`で親を作成）。
- **設定・スクリプトの追従**:
  - `.mrworkflow.json`の`plansDir`/`worklogDir`/`reportsDir`を新パスへ変更。
  - `.claude/settings.json`の`plansDirectory: "./wip/plans"`（**ネストしたパスが実際に機能する
    ことを新規セッションでの実機検証で確認**。詳細は下記「検証結果」）。
  - `.gemini/settings.json`の`general.plan.directory`も同様に変更。
  - `.claude/scripts/src/cleanup-task.sh`の`KEEP_PATHS`をハードコードから
    `.mrworkflow.json`由来の動的組み立てへ変更（`worklogDir`変更後も`TEMPLATE.md`が誤削除
    されないようにするため）。
  - `.claude/scripts/src/vcs/Provider.sh`（`get_workflow_config`）のフォールバック既定値は
    **意図的に変更しなかった**（DDR `i0165-01`。既存配布先との後方互換のため）。
  - `.claude/skills/apply-mr-workflow-to-project/scripts/install-to-project.sh`の
    ディレクトリ生成・`.gitkeep`配置対象を`wip/`3構成へ変更。
- **ドキュメント更新**: `.claude/rules/directory-structure.md`のツリー構造・`index.md`
  （Repository Map）・`.claude/hooks/session-start.sh`・`.claude/skills/issue-mr-flow/SKILL.md`
  他約100ファイルの`plans/` `worklog/` `reports/`表記を`wip/`配下の新パスへ更新（DDR本文・
  spec changelogの過去エントリは対象外。一括`sed`は使わず個別確認）。
- **DDR記録**: `i0165-01`（コード側フォールバック既定値は後方互換のため変更しない）、
  `i0165-02`（集約先の親ディレクトリ名は`wip/`を採用し`flow/`/`tasks/`/`work/`/`scratch/`を
  却下した理由）。
- **移行手順の文書化**: `.claude/docs/spec/asset-distribution.md`「移行（本家の配置場所が
  変わった場合）」節（恒久の一般手順）と、`.claude/docs/spec/distribution-assets.md`の
  issue #165エントリ（今回固有の具体的手順。dist-layers.jsonのcore 3件・seed 2件、
  `.mrworkflow.json`の3キー、`.claude/settings.json`の`plansDirectory`）。
- **usecase文書の更新**: `この機構を他プロジェクトへ導入する.md`へ「配置場所の改名は自動追従の
  対象外」の注記を追加。

## なぜそうしたか

- **`wip/`という名前を採用した理由**: 「未完了・一時的で正史ではない」という寿命をそのまま
  表す広く認知された慣用語であるため。`flow/`（このリポジトリで「フロー＝手順」を指す語と
  衝突）・`tasks/`（TODO/issue管理の含意と衝突）・`work/`（最も汎用的で導入先の作業用
  ディレクトリと衝突しやすい）・`scratch/`（「使い捨て」の含意が強すぎ、人間レビューを経る
  正式な成果物という性質とズレる）はいずれも却下した（DDR `i0165-02`）。
- **コード側フォールバック既定値を変更しなかった理由**: 既にこの機構を導入済みの配布先が
  `.mrworkflow.json`で3キーを明示していない場合、既定値を`wip/*`へ変更すると配布先の実際の
  ディレクトリ構成（`plans/`のまま）と食い違い、作業ファイルの列挙・片付け対象の判定が
  無言で壊れる。据え置く実害は配布先のみに留まり、本リポジトリ自身は3キーを明示しているため
  影響を受けない（DDR `i0165-01`）。
- **`.claude/VERSION`を`0.3.0`のまま据え置いた理由**: 非対話的セッション例外規定
  （`distribution-assets.md`、issue #160が先例）に従いAIエージェントがMAJOR（`1.0.0`）の
  適用を試みたが、実行環境の権限クラシファイアにより`Bash`・`Write`両ツールでの書き込みが
  拒否された。この事実を人間へ報告したところ「0.3.0で良い」との回答を得て、現状維持が
  人間の判断として確定した（人間によるレビュー否認とは別種の、技術的制約が起点である点を
  DDR・spec changelogへ明記した）。

## 検証結果

- **`plansDirectory`のネストパス（`./wip/plans`）が実際に機能することを、新規セッション
  （session_01A48PeEHLHrnXihSbMdmvnw）での`EnterPlanMode`実行で確認した。** 提示された
  計画ファイルパスは`wip/plans/<自動命名>.md`であり、フラットな`plans/`へのフォールバックは
  発生しなかった。対照実験（フラットな新規パス`./plans2`での比較検証）はインフラの一時停止で
  5回連続失敗し未完了のまま保留した（マージ判断への影響は無い。受け入れ条件の主要部分＝
  ネストパス自体が機能することは確認済み）。
- **影響を受ける単体テスト20本すべて `passed=N failures=0`**（`test_cleanup_task.sh`・
  `test_search_frontmatter.sh`・`test_vcs_provider.sh`・`test_install_to_project.sh`・
  `test_check_base_sync.sh`・`test_collect_review_points.sh`・`test_extract_frontmatter.sh`・
  `test_session_start.sh`他）。
- **`git diff <分岐点SHA> -- .claude/docs/ddr/`は変更行数0**（DDR本文は不変の原則が保たれている
  ことを分岐点SHA基準で確認）。
- **`bash .claude/scripts/src/check-doc-references.sh`で参照切れ0件。**
- **`bash .claude/scripts/src/generate-ddr-list.sh --check`でDDR一覧が最新（86件）であることを
  確認。DDR識別子の重複は無し。**
- **`.gemini/`は`sync-gemini-assets.sh`で`.claude/`の全変更を反映済み**（flow-id 5-3）。
- **`bash .claude/scripts/src/check-base-conflicts.sh`で`origin/main`との新たなコンフリクトが
  無いことを確認**（flow-id 5-1）。
- ブランチ全体で30コミット、`origin/main`との差分は108ファイル（`wip/plans` `wip/worklogs`
  `wip/reports`を除く。+1548/-845行）。

## spec・DDRへの反映先

- `.claude/docs/ddr/i0165-01-wip集約時のコード側フォールバック既定値は変更せず後方互換を優先する.md`:
  コード側フォールバック既定値を変更しない決定。
- `.claude/docs/ddr/i0165-02-タスク単位ディレクトリの集約名はwip-を採用しflow-tasks-work-scratchを採らない.md`:
  `wip/`命名の採用理由・`.claude/VERSION`据え置きの最終判断。
- `.claude/docs/spec/asset-distribution.md`: 「移行（本家の配置場所が変わった場合）」恒久節を新設。
- `.claude/docs/spec/distribution-assets.md`: issue #165のchangelogエントリ（VERSION対応の経緯と
  最終判断）を追加。
- `.claude/docs/spec/cleanup-task.md`: `KEEP_PATHS`動的化後の記述へ更新。

## PR作成後のdefaultブランチ追従（監視）

PR作成後、`main`が4回進み、そのたびに`resolve-conflict`スキルの監視モードで検知・解消した
（issue #157: `.gemini/`生成物化・フェーズ5再編、issue #154: AIアセット配布manifest方式化、
issue #160/#171/#182: SKILL.md分割・DDR参照切れ検出・敵対的レビュー選別、issue #170/#143/#155:
usecase文書新設・flow-id並べ替え手順・REVIEW-POINTS除外漏れ対策）。いずれも承認を待たず
機械的に解消し、解消のたびにPRコメントで報告した。詳細は`HANDOFF.md`「判断を迷った内容」参照。

## マージ前の関連issue通知

差分（`wip/plans` `wip/worklogs` `wip/reports`を除外、`REVIEW-POINTS.md`は含む）から抽出した
キーワードで`search_issues`を実施。issue #87・#54・#2はclosed、issue #27（AIアセット逆輸入
スキル）はレイヤー/manifestベース設計で本件と直接の依存が薄いため対象外と判断した。
**issue #108**（HANDOFF.mdのタスク単位化）は「前提が変わる」に該当すると判断し、人間の承認を
得たうえで通知コメントを投稿した（想定していた着手順序が逆転し#165が先行完了したこと、
HANDOFF.mdをwip/配下へ置くかの判断について#165はルート直下据え置きと判断したことの2点）。

## 残課題

なし。issueの受け入れ条件はすべて満たしている。対照実験（`./plans2`）の未完了は既知の限界として
`wip/reports/20260823_transient-brewing-pelican_plansDirectoryネストパス検証.md`
「確かめられなかったこと」に記録済みで、マージ判断への影響は無い。
