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

- issue: [#20](https://github.com/yuki-matsu783/MR-driven-workflow/issues/20) HANDOFF.mdの進捗更新をスクリプトで自動化する
- ブランチ: claude/github-issue-20-85bvts（Claude Code on the webが自動作成。`feature-<issue>-<slug>`
  命名規則とは異なるが、既に本ブランチで開発するよう指示されているためそのまま使用）
- PR: [#31](https://github.com/yuki-matsu783/MR-driven-workflow/pull/31)（Draft）
- push回数: 5

なお、着手時点で前issue #13（PR #29, squash mergeで既にmain合流済み）のflow-id 5-1未実施分
（`plans/` `worklog/` の残骸・`HANDOFF.md`未リセット）が本ブランチに残っていたため、
本題着手前にこのブランチ上で片付けを実施した（コミット`chore: 前issue #13分のplans/worklogを
削除しHANDOFF.mdを次タスク向けへリセット`）。

進捗記号: `[x]` 完了 / `[]` 未着手・進行中 / `[-]` 今回は実施しない（スキップ）

| 進捗 | flow-id | ステップ | 担当 |
|----|---|---|---|
| [x] | 1-1 | issueを起票する（`.github/ISSUE_TEMPLATE/task.md` / `.gitlab/issue_templates/task.md` で目的・現状・期待する動作・受け入れ条件を記載） | 人間（AIが代行する場合は `issue-create` スキル） |
| [x] | 1-2 | issueの内容を取得する | `start <issue番号>` |
| [x] | 1-3 | featureブランチ（`feature-<issue番号>-<slug>`）とDraft MRを作成する（既にあれば `sync` のみ） | `start` — ブランチは`claude/github-issue-20-85bvts`として既に用意されていたため`new_issue_branch`は未使用。Draft PR #31は`gh`/`glab`が実行環境に無いためGitHub MCPツールで代替作成 |
| [x] | 1-4 | **Planモードで「全体作業計画」を作成する**（このissueをどう進めるか＝何を調査し何を実装するかの全体像。ハーネスが提示するパス `plans/<自動命名>.md` へ出力）。**現在のブランチに既に全体作業計画があれば新規作成せず、既存を読むだけにとどめる**（詳細は下記「計画の2階層構造」） | エージェント |
| [x] | 1-5 | 全体作業計画に合意する | 人間 |
| [x] | 1-6 | 全体作業計画をもとにHANDOFF.mdを更新する | エージェント |
| [-] | 2-1 | **個別調査計画**`plans/【調査】〜.md`を**planツールを使わず**Write/Editで作成する。このタイミングで `worklog/日付_<全体計画名>_<個別計画名>_push<N>.md` を作成 | エージェント — 全体作業計画の方針どおりフェーズ2は省略（Exploreエージェントによる調査で代替） |
| [-] | 2-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [-] | 2-3 | MRで調査計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| [-] | 2-4 | レビュー内容を取得し、調査計画を修正する。対応が完了したコメントには対応内容を返信する（2-3〜2-4を合意まで繰り返す） | `comments` / `reply` |
| [-] | 2-5 | 調査計画をもとにMR descriptionを更新する | `describe` |
| [-] | 2-6 | **調査を実施**し、結果を個別調査計画・worklogに記録する。あわせて結果を視覚的に分かりやすくまとめた自己完結HTML（TailwindCSS CDN方式）を`reports/日付_<全体計画名>_<内容を簡潔に>.html`として作成する（複数要素間の関連・依存関係が主題の場合は、`.claude/skills/canvas-report/SKILL.md`のcanvas形式テンプレートの利用を検討する） | エージェント |
| [-] | 2-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [-] | 2-8 | MRで調査結果についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| [-] | 2-9 | レビュー内容を取得し、調査結果を修正する。対応が完了したコメントには対応内容を返信する（`reports/`のHTMLも調査結果と同期して更新する。2-6〜2-9を合意まで繰り返す） | `comments` / `reply` |
| [-] | 2-10 | 調査結果をもとにMR descriptionを更新する | `describe` |
| [x] | 3-1 | **調査結果をもとに**、個別作業計画`plans/【設計】【実装】〜.md`等を**planツールを使わず**Write/Editで作成する | エージェント — `plans/【設計】【実装】【テスト】HANDOFF進捗自動更新スクリプト.md`を作成 |
| [x] | 3-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 3-3 | MRで作業計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| [] | 3-4 | レビュー内容を取得し、作業計画を修正する。対応が完了したコメントには対応内容を返信する（3-3〜3-4を合意まで繰り返す） | `comments` / `reply` |
| [x] | 3-5 | 作業計画をもとにMR descriptionを更新する | `describe` |
| [] | 3-6 | 作業計画をもとに作業を進める、作業内容はworklogに更新する | エージェント — 実装・テスト自体は完了（下記「やったこと」参照）。ループ範囲(3-6〜3-9)は3-8/3-9（人間レビュー）が非対話的環境のため未実施であり、範囲全体としては`[]`のまま残す（往復1回=ループ範囲全体の完了、という記号ルールに忠実にするため。詳細はworklog参照） |
| [] | 3-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント — 本push（push2）で実施済み |
| [] | 3-8 | MRでレビュー・コメントする。レビュー済み連絡をするまで以降の作業は行わない。 | 人間 |
| [] | 3-9 | レビュー内容を取得し、実装・ドキュメントを修正する。対応が完了したコメントには対応内容を返信する（3-6〜3-9の作業ループを合意まで繰り返す） | `comments` / `reply` |
| [x] | 3-10 | 作業内容をもとにMR descriptionを更新する | `describe` |
| [x] | 4-1 | **作業結果と`plans/` `worklog/` の内容をもとに**、個別反映計画`plans/【設計反映】【AIアセット反映】〜.md`等を**planツールを使わず**Write/Editで作成する | エージェント |
| [] | 4-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 4-3 | MRで反映計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| [] | 4-4 | レビュー内容を取得し、反映計画を修正する。対応が完了したコメントには対応内容を返信する（4-3〜4-4を合意まで繰り返す） | `comments` / `reply` |
| [] | 4-5 | 反映計画をもとにMR descriptionを更新する | `describe` |
| [] | 4-6 | 反映計画をもとに作業を進める、反映内容はworklogに更新する（**設計反映**: `plans/` `worklog/` の内容を `.claude/docs/spec/` `.claude/docs/ddr/`（アプリ本体があれば`docs/spec/` `docs/ddr/`）へ反映する／**AIアセット反映**: 作業中に気づいたルール・スキルの不備を `.claude/rules/` `.claude/skills/` `CLAUDE.md` `AGENTS.md` に反映する） | エージェント — 設計反映・AIアセット反映自体は完了（下記「やったこと」参照）。ループ範囲(4-6〜4-9)は4-8/4-9（人間レビュー）が非対話的環境のため未実施であり、範囲全体としては`[]`のまま残す（3-6と同じ理由。詳細はworklog参照） |
| [] | 4-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 4-8 | MRでレビュー・コメントする。レビュー済み連絡をするまで以降の作業は行わない。 | 人間 |
| [] | 4-9 | レビュー内容を取得し、設計・AIアセットの内容を修正する。対応が完了したコメントには対応内容を返信する（4-6〜4-9の反映ループを合意まで繰り返す） | `comments` / `reply` |
| [] | 4-10 | 反映内容をもとにMR descriptionを更新する | `describe` |
| [] | 5-1 | 次タスクのために、`plans/` `worklog/` `reports/` を削除し、`HANDOFF.md` をリセットする。**あわせて `plans/index.jsonl` も削除し、`bash .claude/scripts/src/extract-frontmatter.sh .` で `index.jsonl` 群を再生成する** | エージェント |
| [] | 5-2 | `commit`スキル経由でcommitし、push して Draftを解除する | エージェント |
| [] | 5-3 | マージする（squash merge。ブランチは削除してよい） | 人間 |

詳細についてはworklogを確認してください。

## やったこと

- issue #20の内容を取得（`.claude/scripts/src/vcs/Provider.sh`の`gh`が実行環境に無いため、
  AGENTS.mdの規定に従いGitHub MCPツール（`mcp__github__issue_read`等）で代替）。
- 着手前に、前issue #13分の未リセット状態（`plans/` `worklog/`の残骸・`HANDOFF.md`未リセット）を
  片付け（本ブランチ上で先に単独コミット）。
- ブランチをpushし、Draft PR #31を作成（`create_pull_request`はGitHub MCPツールで代替）。
- 全体作業計画（`plans/shiny-puzzling-umbrella.md`）を作成し承認を得た。
  - 方針: フェーズ2（個別調査計画）は独立して設けず、既存のコードベース調査（Exploreエージェント
    による`HANDOFF.md`構造・`Provider.sh`/`create-commit.sh`/`extract-frontmatter.sh`の実装
    パターン・`docs-workflow.md`の記号規約調査）をもってフェーズ3（設計・実装・テスト）から
    開始する。

- 個別作業計画に基づき `.claude/scripts/src/update-handoff-progress.sh`
  （`mark-done`/`mark-skip`/`add-round`/`set-header`の4サブコマンド）を実装。
  `tests/test_update_handoff_progress.sh`を実装し`passed=15 failures=0`を確認。
- 実際の`HANDOFF.md`に対して動作確認中、ループ範囲（3-6〜3-9等）の一括適用ロジックが
  意図通りエラーを検知し、前issue #13のHANDOFF.mdが実は「同じループ範囲内は同じ個数の[]を持つ」
  というルールに反する手作業更新をしていたことが判明した（詳細はworklog「ダメだったこと」参照）。
  このスクリプトはまさにこの種の書き間違いを防ぐためのものであり、正しく機能した。
- MR #31 descriptionを更新（flow-id 3-5相当）。

- 個別反映計画（`plans/【設計反映】【AIアセット反映】HANDOFF進捗自動更新スクリプト.md`）を作成。
- 反映作業を実施: 新規spec`.claude/docs/spec/update-handoff-progress.md`、
  `.claude/rules/docs-workflow.md`への`[-]`記号規約・非対話的環境でのループ範囲運用ルールの明文化、
  `.claude/skills/issue-mr-flow/SKILL.md`のHANDOFF更新手順委譲、DDR 0024の新設、
  `.claude/docs/README.md`への参照追加。
- **再度同じ罠を踏んだ**: `mark-done 4-6`を実行したところ、4-6はループ範囲(`4-6 4-7 4-8 4-9`)に
  属するため4-7/4-8/4-9も一括で`[x]`になってしまった（3-6のときと同じ、今回はエラーにならず
  黙って一括適用された）。4-7(commit)・4-8/4-9(人間レビュー)は未実施のため、4件とも`[]`へ手動で
  戻した。この教訓もworklogへ記録した。

## 次にやること

- flow-id 4-7: 反映内容をcommit・pushしてレビュー依頼を行う。
- その後flow-id 4-10相当: MR descriptionを更新し、flow-id 5-1（片付け・HANDOFF.mdリセット）へ
  進む。

## 判断を迷った内容

- 前issue #13分の後始末（`plans/` `worklog/` 削除・`HANDOFF.md` リセット）を、
  `.claude/skills/issue-mr-flow/SKILL.md` の推奨どおり専用の `chore/cleanup-*` ブランチで行うか、
  issue #20用ブランチ内で先に片付けるか。→ 今回はissue #20専用ブランチが既に外部から用意されており
  セッション1つでissue #20に対応する前提のため、別ブランチを新規に立てず、本ブランチの最初の
  コミットとして片付けた（全体作業計画「副次的に発見した状態」参照）。

## 未解決の内容

- 本実行環境（Claude Code on the webのリモート実行環境）には `gh`/`glab` CLIが存在しないため、
  `Provider.sh` 経由のissue取得・PR作成が動作しない。AGENTS.mdの規定どおりGitHub MCPツールで
  代替しているが、`comments`/`reply`/`describe`サブコマンド相当の操作も同様にMCPツールでの
  代替が必要になる見込み。

## 守るべき条件・触ってはいけない範囲

（無し）
