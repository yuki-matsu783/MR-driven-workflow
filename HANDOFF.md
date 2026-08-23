---
title: HANDOFF
type: handoff
description: セッション間・作業者間の引継ぎメモ（現在地・次回やること等）
tags: [handoff, workflow]
keywords: [フロー進捗, worklog, 引き継ぎ, plan, レビュー]
---

# HANDOFF

<!--
AI⇔AI/AI⇔人間の状況引継ぎメモ。常に「このブランチの現状」を表現する
-->

## フロー進捗状況

- issue: #27 他プロジェクトで改善されたAIアセットを本家へ収穫（逆輸入）するスキルを新設する
- ブランチ: claude/ai-asset-reverse-import-skill-g4qa9s
- PR: #189 https://github.com/yuki-matsu783/MR-driven-workflow/pull/189（Draft）
- push回数: 9
- 現在のループ: なし
- 未返信スレッド: 0
- 追従監視: なし

| 進捗 | flow-id | ステップ | 担当 |
|---|---|---|---|
| [x] | 1-1 | issueを起票する | 人間 |
| [x] | 1-2 | issueの内容を取得する | サブコマンド |
| [x] | 1-3 | featureブランチとDraft MRを作成する | エージェント |
| [x] | 1-4 | 全体作業計画を作成する | エージェント |
| [] | 1-5 | 全体作業計画に合意する | 人間 |
| [x] | 1-6 | HANDOFF.mdを更新する | エージェント |
| [x] | 2-1 | 個別調査計画を作成する | エージェント |
| [x] | 2-2 | commitしpushしてレビュー依頼 | エージェント |
| [] | 2-3 | 調査計画をレビューする | 人間 |
| [] | 2-4 | レビューを反映する | サブコマンド |
| [x] | 2-5 | MR descriptionを更新する | サブコマンド |
| [] | 2-6 | 調査を実施しreportsへ記録する | エージェント |
| [] | 2-7 | commitしpushしてレビュー依頼 | エージェント |
| [] | 2-8 | 調査結果をレビューする | 人間 |
| [] | 2-9 | レビューを反映する | サブコマンド |
| [] | 2-10 | MR descriptionを更新する | サブコマンド |
| [x] | 3-1 | 個別作業計画を作成する | エージェント |
| [] | 3-2 | commitしpushしてレビュー依頼 | エージェント |
| [] | 3-3 | 作業計画をレビューする | 人間 |
| [] | 3-4 | レビューを反映する | サブコマンド |
| [] | 3-5 | MR descriptionを更新する | サブコマンド |
| [] | 3-6 | 作業を実施しreportsへ記録する | エージェント |
| [] | 3-7 | commitしpushしてレビュー依頼 | エージェント |
| [] | 3-8 | レビューする | 人間 |
| [] | 3-9 | レビューを反映する | サブコマンド |
| [] | 3-10 | MR descriptionを更新する | サブコマンド |
| [x] | 4-1 | 個別反映計画を作成する（反映対象の洗い出し） | エージェント |
| [] | 4-2 | commitしpushしてレビュー依頼 | エージェント |
| [] | 4-3 | 反映計画をレビューする | 人間 |
| [] | 4-4 | レビューを反映する | サブコマンド |
| [] | 4-5 | MR descriptionを更新する | サブコマンド |
| [] | 4-6 | 反映を実施しreportsへ記録する | エージェント |
| [] | 4-7 | commitしpushしてレビュー依頼 | エージェント |
| [] | 4-8 | レビューする | 人間 |
| [] | 4-9 | レビューを反映する | サブコマンド |
| [] | 4-10 | MR descriptionを更新する | サブコマンド |
| [] | 5-1 | defaultブランチとのコンフリクトを検知・解消する | エージェント |
| [] | 5-2 | 関連issueへ通知する | エージェント |
| [] | 5-3 | .claude/の変更を.gemini/へ変換同期する | エージェント |
| [] | 5-4 | 最終統括レポートを作成しPRへ反映する | エージェント |
| [] | 5-5 | plans/worklog/reportsを削除しHANDOFF.mdをリセットする | エージェント |
| [] | 5-6 | commitしpushしてDraftを解除する | エージェント |
| [] | 5-7 | マージする | 人間 |

## やったこと

- flow-id 1-2〜1-3: issue #27 の内容を取得し、ブランチ
  `claude/ai-asset-reverse-import-skill-g4qa9s`（ハーネス指定名）をpush、Draft PR #189 を作成した
  （ユーザーから「PR作って進めて」の明示指示あり）。
- flow-id 1-4: 全体作業計画 `plans/quiet-orchard-harvest.md`（＋同名.html）を作成した。
- 非対話セッションのため、flow-id 1-5（人間の合意）は待たずに進む（ユーザーの当初指示
  「PRを作って進めて。各フェーズ計画時と作業実施毎に敵対的レビューを自動実施」に基づく）。
  記号は `[]` のまま残す。
- flow-id 2-1: 個別調査計画 `plans/【調査】収穫スキルの前提調査.md`（＋.html）と
  worklog（push1）を作成した。
- flow-id 2-2直後: 敵対的レビュー1回目（フェーズ2・対象=調査計画）を実施。findings 8件の
  うち7件をインライン投稿（下記URL）、1件（変更対象の「のみ」表現・minor/medium）は
  報告のみ。修正は8件すべて反映した（計画へ前提・方針・Q8・検証コマンドを追加）。
  - https://github.com/yuki-matsu783/MR-driven-workflow/pull/189#discussion_r3838553264 （前提合意の明記）
  - https://github.com/yuki-matsu783/MR-driven-workflow/pull/189#discussion_r3838553759 （-dirty SHA）
  - https://github.com/yuki-matsu783/MR-driven-workflow/pull/189#discussion_r3838554061 （検証コマンド）
  - https://github.com/yuki-matsu783/MR-driven-workflow/pull/189#discussion_r3838554457 （added/deleted Q8）
  - https://github.com/yuki-matsu783/MR-driven-workflow/pull/189#discussion_r3838554718 （LF正規化の粒度差）
  - https://github.com/yuki-matsu783/MR-driven-workflow/pull/189#discussion_r3838554982 （HTML要約で情報欠落）
  - https://github.com/yuki-matsu783/MR-driven-workflow/pull/189#discussion_r3838555266 （方針節の欠落）
- flow-id 2-6: 調査を実施し `reports/2026-08-23_quiet-orchard-harvest_調査結果.md`（＋.html）へ
  Q1〜Q8 の回答と実行検証の記録を書いた。
- 敵対的レビュー1回目の7スレッドすべてへ対応内容を返信し、`- 未返信スレッド:` を 0 へ戻した
  （返信URLは各スレッド r3838566603〜r3838568259）。describe で MR description を更新した。
- flow-id 3-1: 個別作業計画
  `plans/【AIアセット作成】【実装】【テスト】収穫スキルの新設.md`（＋.html）を作成した。
- 敵対的レビュー2回目（フェーズ2・対象=調査結果レポート）を実施。findings 14件のうち
  12件をインライン投稿（サマリコメントに報告のみ2件の内訳を記載）、修正は14件すべて
  調査結果 md/html とフェーズ3計画 md/html へ反映した（gitignorePattern照合・自前pathspec
  照合・merge層/dist-layers.json の base 例外・merge-file 終了コード3分岐・DDR文案の
  現行方式化・スキップガード等）。
- 敵対的レビュー2回目の12スレッドすべてへ対応内容を返信し、`- 未返信スレッド:` を 0 へ
  戻した（返信URLは各スレッド r3838709929〜r3838713139。修正コミット b086125）。
  MR description は内容の骨子が変わらないため更新を省略した（flow-id 2-10 は `[]` のまま。
  次の describe 実行時にまとめて反映する）。フェーズ2のループ範囲 2-6〜2-9・2-3〜2-4 は
  非対話セッションのため記号 `[]` のまま（2-6〈調査実施〉・2-7〈commit/push〉相当は実施済み。
  実施内容は上記のとおり）。

- 敵対的レビュー3回目（フェーズ3・対象=個別作業計画。カウンタ 1/3）を実施。findings 20件の
  うち major 13件をインライン投稿（サマリコメントに報告のみ minor 7件の内訳を記載）、修正は
  20件すべて計画 md/html へ反映した（-dirty は baseApproximate の第3状態へ・upstreamDeleted
  追加と「本家でも削除済み」別枠・manifest自身と*.bak の added 除外・check-ignore 廃止で
  自前照合へ一本化・merge3 に exit 4 新設・git 起動の一括化規約・scan の schemaVersion 付き
  全体形とエラー隔離・T2a/T2b・T8/T8b・T12〜T15 追加等）。
- 敵対的レビュー3回目の13スレッドすべてへ対応内容を返信し、`- 未返信スレッド:` を 0 へ
  戻した（返信URLは各スレッド r3838762517〜r3838766374。修正コミット 142b664）。
- flow-id 3-6 相当: 収穫スキル一式を実装した——`.claude/skills/harvest-from-projects/`
  （SKILL.md＋scripts/harvest-from-projects.sh）・`.claude/scripts/test/
  test_harvest_from_projects.sh`・dist-layers の exclude エントリ・
  markdown-frontmatter.md の配布先DDR規約。検証4種（bash -n・テスト・
  check-dist-coverage 4検査・frontmatter 実問い合わせ）すべて合格。
  結果は `reports/2026-08-23_quiet-orchard-harvest_作業結果.md`（＋.html）。
- 敵対的レビュー4回目（フェーズ3・対象=実装一式。カウンタ 2/3）を実施。findings 15件の
  うち13件をインライン投稿（PR diff 外の index.md と rev-list の nit はサマリで報告）、
  修正は15件すべて反映した——`git log` 2本への `core.quotepath=false`・削除履歴の
  `--no-renames`・エラー隔離を `set +e; ( set -e; f ); rc=$?; set -e` の形へ作り直し
  （`( f ) || rc=$?` は errexit 停止がサブシェル内部へ伝播することを実測で確認）・
  `git archive | tar` 失敗の error 化・`files: []` manifest の縮退・merge3 の層判定
  フェイルクローズ（exit 3）と seed 対象外（exit 4）・strategy 明示分岐・縮退時の
  判断材料充填・usage の awk 化・空配列ガード・index.md スキル一覧追記・SKILL.md の
  非対話決め打ち。テストは T16〜T23 を追加し 66→89 アサーション（passed=89 failures=0）。
- 敵対的レビュー4回目の13スレッドすべてへ対応内容を返信し、`- 未返信スレッド:` を 0 へ
  戻した（返信URLは各スレッド r3838880125〜r3838884069。修正コミット 55dd094）。
- flow-id 4-1: 個別反映計画2本（＋各.html）を作成した——
  `plans/【設計反映】収穫スキルの正史反映.md`（spec 新規・DDR `i0027-01`/`i0027-02`・
  directory-structure.md 文言・usecase 新規・DDR一覧再生成・VERSION minor 増分の提案）と
  `plans/【AIアセット反映】エラー方針の規約訂正.md`（shell-script-style.md「エラー方針」の
  実測に基づく訂正。洗い出し手順1〜2の記録込み）。種別は規約どおり併記せず分けた。

## 次にやること

- flow-id 4-2（commit/push）→ 敵対的レビュー5回目（フェーズ4・対象=反映計画2本。カウンタ
  1/3）→ 指摘の投稿・修正・返信 → 4-5（describe）→ 4-6（反映実施。
  generate-ddr-list.sh 実行込み）→ 4-7（commit/push）→ 敵対的レビュー6回目（反映後）。

## 判断を迷った内容

- ブランチ名がリポジトリ命名規則 `feature-27-<slug>` ではなくハーネス指定の
  `claude/ai-asset-reverse-import-skill-g4qa9s` である（ハーネスの指示が優先。別ブランチへの
  push は禁止されているためこのまま進める）。

## 未解決の内容

（無し）

## 守るべき条件・触ってはいけない範囲

- 収穫スキルは本家の `.claude/rules/` `.claude/skills/` `.claude/docs/` を直接書き換えない
  設計にする（issue #27 受け入れ条件）。
- マージ（flow-id 5-7）はユーザーの明示指示があるまで実行しない。
