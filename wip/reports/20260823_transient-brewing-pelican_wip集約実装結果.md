---
title: wip集約とworklogs改名 実装結果
type: report
description: issue #165フェーズ3。plans/worklog/reportsをwip/plans, wip/worklogs, wip/reportsへ移動し、設定・スクリプト・約50ファイルのドキュメント参照を更新した実装結果
tags: [issue-mr-flow, directory-structure, migration]
keywords: [wip, plans, worklog, worklogs, reports, git mv, cleanup-task, install-to-project, KEEP_PATHS, 実装結果]
---

# wip集約とworklogs改名 実装結果

対象: issue #165 フェーズ3（作業実施）。
全体作業計画: `wip/plans/transient-brewing-pelican.md`
個別作業計画: `wip/plans/【設計】【実装】【テスト】wip集約とworklogs改名.md`

## 結論

個別作業計画に沿って、`plans/` `worklog/` `reports/` を `wip/plans` `wip/worklogs` `wip/reports` へ
`git mv` で移動し、これらを参照する設定・スクリプト・ドキュメント（約50ファイル）を更新した。
影響を受ける単体テスト8本はすべて `passed=N failures=0`、DDR本文・spec changelogへの意図しない
書き換えは無い（分岐点SHA基準の`git diff`で確認）。issueの受け入れ条件8件のうち7件を満たし、
残る1件（wip/命名判断のDDR記録）はフェーズ4へ送る（計画どおり）。

## 実施した内容

### 1. KEEP_PATHSの動的化（cleanup-task.sh）

個別作業計画の方針1のとおり、`readonly -a KEEP_PATHS=("worklog/TEMPLATE.md")` を
`KEEP_PATHS=()`（トップレベル・空配列・`readonly`外し）へ変更し、`main()` 内で
`dirs_tsv` → `target_dirs` を読み込んだ直後に `KEEP_PATHS=("${target_dirs[1]}/TEMPLATE.md")`
を代入する形にした。`declare` は使わず素の代入文にすることで、`main()` を経由しない
`test_cleanup_task.sh` の直接呼び出し（`is_keep_path` の単体テスト）からも正しく見えることを
確認した。

`test_cleanup_task.sh` には次の2点を追加した。

1. 既存の `is_keep_path` 直接呼び出しテストの直前に `KEEP_PATHS=("worklog/TEMPLATE.md")` を
   明示的にセットする行（`main()`を経由しない単体テストが動くようにするため）。
2. `.mrworkflow.json` で `worklogDir: "wip/worklogs"` を指定する新規フィクスチャ
   （`setup_ct_repo_wip`）による結合テスト2件（`--dry-run`でのkeptPaths確認、実行後に
   `wip/worklogs/TEMPLATE.md`が誤削除されないことの確認）。既存フィクスチャは
   `.mrworkflow.json`を持たず常にフォールバック既定値で走るため、この配線を一度も検証
   できていなかった（フェーズ3計画レビューの指摘）。

`Provider.sh`・`cleanup-task.sh:224`のjqフォールバック既定値（`plans`/`worklog`/`reports`）は、
計画どおり**変更していない**。`.mrworkflow.json`を持たない配布先（未移行の既存導入先）が
旧レイアウトのままである前提を保つため。

`test_cleanup_task.sh` は67件すべて合格（新規9件を含む）。実リポジトリでも
`bash .claude/scripts/src/cleanup-task.sh --dry-run` の `targetDirs` が
`["wip/plans","wip/worklogs","wip/reports"]`、`keptPaths` が `["wip/worklogs/TEMPLATE.md"]`
になることを直接確認した。

### 2. ディレクトリ移動

計画の方針2のとおり、`mkdir -p wip` の後、移動先3つがいずれも存在しないことを`if`文で確認して
から`git mv plans wip/plans && git mv worklog wip/worklogs && git mv reports wip/reports`を
実行した（1周目レビューで指摘されたガード無効化の欠陥を修正した形）。`git status`は
13件すべてを`R`（rename）として認識しており、`git log --follow`でファイル履歴を追える
（コミット後に確認）。

### 3. 設定・スクリプトの変更

計画の「変更対象」表のとおり、次のファイルを変更した。

| ファイル | 変更内容 |
|---|---|
| `.mrworkflow.json` | `plansDir: "wip/plans"`, `worklogDir: "wip/worklogs"`, `reportsDir: "wip/reports"` |
| `.claude/settings.json` | `plansDirectory: "./wip/plans"` |
| `.gemini/settings.json` | `general.plan.directory: "./wip/plans"`（実機未検証。フェーズ2の限定条件のまま） |
| `.claude/scripts/src/cleanup-task.sh` | KEEP_PATHS動的化（上記1.） |
| `.claude/skills/apply-mr-workflow-to-project/scripts/install-to-project.sh` | `mkdir -p`対象・`.gitkeep`配置を`wip/plans` `wip/worklogs` `wip/reports`の3つへ |

`install-to-project.sh`は実際に新規の使い捨てgitリポジトリへ向けて実行し、
`wip/plans/.gitkeep` `wip/worklogs/.gitkeep` `wip/reports/.gitkeep`が作られることを確認した
（`test_install_to_project.sh`はこの挙動を検証していないため、手動確認で補った）。

### 4. ドキュメント更新

`git grep -lI -e plans -e worklog -e reports`（拡張子を絞らない対称パターン。計画レビューの
指摘で当初案の非対称性を修正）を起点に、DDR本文とspec内のpoint-in-time changelog節を除外して
約45ファイルを更新した。並行して複数の担当（サブエージェント）へファイル群を分担し、それぞれに
「現在の状態を説明する箇所のみ更新し、過去のissue対応を時系列で記録した文は触らない」という
判断基準を明示して進めた。

主な更新箇所:

- `.claude/rules/directory-structure.md`: ディレクトリツリー図を `wip/` の下に `plans/`
  （`REVIEW-POINTS.md`含む）・`worklogs/`（`TEMPLATE.md`含む）がぶら下がる形へ再構成。
- `.claude/rules/docs-workflow.md`・`.claude/rules/markdown-frontmatter.md`: ライフサイクル表・
  `type`値対応表のファイルパスパターンを新パスへ。
- `.claude/skills/issue-mr-flow/SKILL.md`（唯一の実装フロー定義）: 全体フロー表・「計画の2階層
  構造」節・「計画・レポートのHTMLビュー」節など64行を更新。テンプレートファイル自体のパス
  （`assets/plans.template.html`等）は変更していない。
- `.claude/docs/spec/issue-mr-workflow.md`: `## 影響範囲`配下の過去issueごとのchangelog小節
  （1819〜3084行目付近、50以上の小節）は一切変更せず、「現在の状態」を説明する`## 設定項目`等の
  節のみ更新した。
- `index.md`（Repository Map）・`.mrworkflow.json`・`AGENTS.md`・`README.md`・
  `REVIEW-POINTS.md`（ルート直下）を含む root直下のファイル。
- 移動先3ディレクトリ自身の恒久ファイル（`wip/plans/REVIEW-POINTS.md`・
  `wip/reports/REVIEW-POINTS.md`・`wip/worklogs/TEMPLATE.md`）本文中の旧パス参照
  （フェーズ3計画レビューで追加された対象）。
- `.claude/hooks/otel/`配下の`.pl`/`.pm`3ファイル: コメント中の`plans/`/`reports/`ファイル
  参照を、issue番号（#103）または`.claude/docs/spec/otel-listener.md`への参照へ書き換えた
  （`.claude/rules/docs-workflow.md`「コード・スクリプト内のコメントから`plans/` `worklog/`
  `reports/`のファイルを参照しない」という既存ルールへの違反を、この移動を機に解消）。

**触らなかったもの**（意図的）:

- `.claude/docs/ddr/*.md`本文（不変）。
- `.claude/docs/spec/*.md`のpoint-in-time changelog節（各specファイルの`## 影響範囲`配下等）。
- `.claude/docs/spec/cleanup-task.md`の「未決定事項」節。KEEP_PATHSの動的化によりこの節の記述
  「`.mrworkflow.json`からは読まない」が事実と食い違うが、これはフェーズ4（設計反映）で扱う。
- `.claude/skills/apply-mr-workflow-to-project/assets/`（`sync-assets.sh`が生成するビルド成果物）。
- `.claude/scripts/test/`配下の6テストファイル（`test_check_base_sync.sh`等）: フィクスチャ内で
  `plans`/`worklog`/`reports`という文字列を使っている箇所はあるが、いずれも
  `.mrworkflow.json`の設定値に依存しない独立したテストデータであることを、対象関数を実際に
  辿って確認した上で変更しないと判断した。

## 検証結果

```
bash .claude/scripts/test/test_cleanup_task.sh          -> passed=67 failures=0
bash .claude/scripts/test/test_search_frontmatter.sh    -> passed=114 failures=0
bash .claude/scripts/test/test_vcs_provider.sh          -> passed=219 failures=0
bash .claude/scripts/test/test_install_to_project.sh    -> passed=22 failures=0
bash .claude/scripts/test/test_check_base_sync.sh       -> passed=55 failures=0
bash .claude/scripts/test/test_collect_review_points.sh -> passed=17 failures=0
bash .claude/scripts/test/test_extract_frontmatter.sh   -> passed=32 failures=0
bash .claude/scripts/test/test_session_start.sh         -> passed=51 failures=0
perl .claude/hooks/otel/test/test_otel_registry.pl      -> 12/12 ok (TAP)
```

変更したすべての`.sh`（7ファイル）を`bash -n`で構文チェックし、全てOK。変更した`.pl`/`.pm`
（3ファイル）を`perl -c`で構文チェックし、全てOK。`.claude/settings.json`・`.gemini/settings.json`・
`.mrworkflow.json`を`jq .`で構文チェックし、全てOK。

```
git diff $(git merge-base main HEAD) -- .claude/docs/ddr/    -> 0行（意図しない書き換え無し）
```

`.claude/docs/spec/`の差分は、`issue-mr-workflow.md`を含む全specファイルについて、変更行が
すべて`## 影響範囲`等のchangelog小節の外（「現在の状態」を説明する節）にあることを、diffの
hunk位置とファイル構造を突き合わせて確認した。

移動後の実在確認:

```
[ -f wip/plans/REVIEW-POINTS.md ] && [ -f wip/reports/REVIEW-POINTS.md ] && [ -f wip/worklogs/TEMPLATE.md ]
-> OK（3ファイルとも存在）
```

`cleanup-task.sh --dry-run`の実リポジトリでの直接確認:

```
targetDirs: ["wip/plans", "wip/worklogs", "wip/reports"]
keptPaths:  ["wip/worklogs/TEMPLATE.md"]
```

`cleanup-task.sh --help`の出力末尾は仕様書へのポインタで正常に終わっており、`usage()`の
`sed -n '2,42p'`が参照する範囲（KEEP_PATHSの初期化は50行目以降にあるため範囲外）は崩れていない。

## 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| ドキュメント参照は約58/44/39ファイル（フェーズ2実測） | 本ブランチ上で数え直すと数え方により48〜70の幅で変動し、計画の数値と正確には一致しなかった | 個別計画レビューの指摘どおり、固定値ではなく`git grep`コマンドそのものを検証手段とし、実測件数の完全一致にはこだわらなかった |
| ドキュメント更新は手作業で1ファイルずつ | ファイル数が多いため、複数の担当（サブエージェント）へ「現在の状態を説明する箇所のみ更新し、過去の記録は触らない」という同一の判断基準を明示して分担した | 各担当の完了報告を確認し、DDR/spec changelogの除外が正しく機能していることを、分岐点SHA基準の`git diff`で最終確認した |
| `install-to-project.sh`の変更確認はtest_install_to_project.shの既存合格で足りる想定 | 既存テストは`plans`/`worklog`/`reports`ディレクトリ作成を検証していなかった（変更前後どちらも） | 新規の使い捨てgitリポジトリへ実際に実行し、`wip/plans/.gitkeep`等3件が作られることを手動確認した |

## 確かめられなかったこと

- `.gemini/settings.json`の`general.plan.directory`が`./wip/plans`で実際に機能するかは、
  Gemini CLI自体が本実行環境に無いため未検証（フェーズ2から持ち越し）。
- `wip/plans`ディレクトリが事前に存在しない状態でのPlanモードの挙動（フェーズ2から持ち越し）。

## 設計への反映（フェーズ4で対応）

1. `wip/`という名前の採用理由（`flow/` `tasks/` `work/` `scratch/`を採らなかった判断）をDDRとして
   記録する（受け入れ条件7）。
2. `.claude/docs/spec/cleanup-task.md`の「未決定事項」節を、KEEP_PATHSが`.mrworkflow.json`から
   動的に組み立てられるようになった事実に合わせて更新する。
3. `.claude/VERSION`のMAJORインクリメントを提案する（配置場所の変更は
   `.claude/docs/spec/distribution-assets.md`が定めるMAJORの目安に該当するため）。
4. 既に`apply-mr-workflow-to-project`で導入済みの配布先が`plans/` `worklog/`を残したまま
   `wip/`が追加される移行手順の記述先を決め、記述する。
