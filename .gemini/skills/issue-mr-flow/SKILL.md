---
name: issue-mr-flow
description: このプロジェクトの開発フロー全体（issue起票〜マージ）の唯一の実装フロー定義。新機能追加・既存動作の変更など、あらゆるタスクをissue起点で進めるときに使う。issue取得、feature-<issue番号>-<内容>ブランチとDraft MRの作成、レビューコメント取得、MR description更新をサブコマンドで行いつつ、設計ドキュメント作成・plan・実装・設計反映・AIアセット反映までの全ステップをこのファイルが定義する。
title: issue駆動 開発フロー
type: skill
tags: [issue-mr-flow, workflow, skill]
keywords: [start, resume, sync, comments, reply, describe, draft-pr, issue分割, 並列列挙, 実装フロー, squash-merge, レビュー返信, 着手確認, レビュー判断, 判断記録, add_mr_comment, レビュー依頼, AskUserQuestion, compact]
---

# issue駆動 フロー（唯一のフロー定義）

このファイルは `.claude/docs/spec/issue-mr-workflow.md` の実装であり、このプロジェクトにおける
**issue起票からマージまでの唯一のフロー定義**である。適用要否の判定基準（除外してよい
「ごく小さな変更」の定義）は `AGENTS.md` を参照する。対象となるタスクは、このファイルの
手順で進める。

裏側の実処理は `.claude/scripts/src/vcs/Provider.sh`（GitHub/GitLabの差異を吸収する共通関数群。bash版。
設計: `.claude/docs/spec/shell-scripts.md`）に実装されている。各ステップの手順内で、必要に応じて
Bashツールで以下のようにsourceして使う。

```bash
source .claude/scripts/src/vcs/Provider.sh
```

各関数はJSON文字列をstdoutへ出力する設計のため、`jq`でフィールドを取り出す
（例: `get_issue 6 | jq -r '.title'`）。

プロジェクト固有のパス設定（ブランチ命名規則・`wip/plans/` 等の場所）はリポジトリ直下の `.mrworkflow.json`
から読む（`get_workflow_config`）。他リポジトリへ移植する場合はこのファイルの値を書き換えるだけでよい。

## 全体フロー

担当列: 「人間」＝人間の作業／「サブコマンド」＝`/issue-mr-flow <名前>`（共通の前提は
`references/start-resume.md`「サブコマンド」節。`start`/`resume`/`sync` は同ファイル、
`comments`/`reply`/`describe` は `references/review-loop.md` が定義する）／
「エージェント」＝AIエージェントの通常操作（git操作・ファイル編集等）。

参照列: そのステップの**実行前に開く**参照ファイル（SessionStart hookが現在地のflow-idから
この列を読み出してセッション冒頭へ注入する）。`—` は追加の参照なしを表す。
**`references/mcp-fallback.md` は参照列では指さない**（設計）。`gh`/`glab` CLIの有無は
flow-idではなく実行環境で決まるため、hookが経路判定の結果MCP経路だったときに限り、
参照列とは別の行で同ファイルを名指しで注入する。

flow-idは `<フェーズ番号>-<ステップ番号>` 形式で、全5フェーズ・43ステップからなる。

| フェーズ | 範囲 | 内容 |
|---|---|---|
| 1 | 1-1〜1-6 | 起点（issue起票・ブランチ/Draft MR作成・全体作業計画） |
| 2 | 2-1〜2-10 | 調査（調査計画 → レビュー → 調査実施 → レビュー） |
| 3 | 3-1〜3-10 | 作業（作業計画 → レビュー → 設計・実装 → レビュー） |
| 4 | 4-1〜4-10 | 反映（反映計画 → レビュー → 設計反映・AIアセット反映 → レビュー） |
| 5 | 5-1〜5-7 | クローズ（コンフリクト解消・関連issue通知・**`.gemini/` 変換同期**・最終統括レポート・片付け・Draft解除・マージ） |

フェーズ2〜4は「計画 → commit/push → レビュー → 実施 → commit/push → レビュー →
MR description更新」という同じ形を繰り返す。
フェーズ2,3はどちらかのみ実施する計画となることがありうるが、
フェーズ1,4,5についてはこのフローを利用する際は必ず実施する（フェーズ4は flow-id 4-1 で反映対象を
洗い出すところまでを必ず通る。そこから先をスキップしてよい条件は
`references/planning.md`「全体作業計画に必ず含めるフェーズ」が正）。
**ただし、省略の判断は全体作業計画（flow-id 1-4）ではなく各フェーズの直前で行う**。詳細は
`references/planning.md`「全体作業計画に必ず含めるフェーズ」。

| flow-id | ステップ | 担当 | 参照 |
|---|---|---|---|
| 1-1 | issueを起票する（`.github/ISSUE_TEMPLATE/task.md` / `.gitlab/issue_templates/Default.md` で目的・現状・期待する動作・受け入れ条件を記載） | 人間（AIが代行する場合は `issue-create` スキル） | — |
| 1-2 | issueの内容を取得する | `start <issue番号>` | `references/start-resume.md` |
| 1-3 | featureブランチ（`feature-<issue番号>-<slug>`）とDraft MRを作成する（既にあれば `sync` のみ）。**Draft MRの作成に都度の明示指示は要らない**（下記「PR/MR作成・マージの担当」。ハーネスがPR作成を制限する環境での例外も同節）。**作成後は `references/base-branch-followup.md`「PR作成後のdefaultブランチ追従（監視）」節に従って追従監視を開始する** | `start`（エージェント） | `references/start-resume.md` / `references/base-branch-followup.md` |
| 1-4 | **Planモードで「全体作業計画」を作成する**（このissueをどう進めるか＝何を調査し何を実装するかの全体像。ハーネスが提示するパス `wip/plans/<自動命名>.md` へ出力）。**現在のブランチに既に全体作業計画があれば新規作成せず、既存を読むだけにとどめる**（詳細は`references/planning.md`「計画の2階層構造」）。**作成前に、issueが大きすぎないか（同型の成果物が並列に列挙されていないか）を判定し、該当すれば分割を提案する**（`references/planning.md`「issueが大きすぎる場合の分割提案」）。**フェーズ2〈調査〉・フェーズ4〈反映〉の節を必ず含める。この段階の事前調査は軽めでよい**（`references/planning.md`「全体作業計画に必ず含めるフェーズ」）。**あわせて同名の `.html`（人間レビュー用ビュー）を作成する**（`references/deliverables.md`「計画・レポートのHTMLビュー」） | エージェント | `references/planning.md` / `references/deliverables.md` |
| 1-5 | 全体作業計画に合意する | 人間 | — |
| 1-6 | 全体作業計画をもとにHANDOFF.mdを更新する | エージェント | `references/planning.md` |
| 2-1 | **個別調査計画**`wip/plans/【調査】〜.md`を**planツールを使わず**Write/Editで作成する。このタイミングで `wip/worklogs/日付_<全体計画名>_<個別計画名>_push<N>.md` を作成。**フェーズ2を省略してよいと判断できるのはこの時点以降**（`references/planning.md`「全体作業計画に必ず含めるフェーズ」）。**あわせて同名の `.html`（人間レビュー用ビュー）を作成する**（`references/deliverables.md`「計画・レポートのHTMLビュー」） | エージェント | `references/planning.md` / `references/deliverables.md` |
| 2-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント | `references/review-loop.md` |
| 2-3 | MRで調査計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 | — |
| 2-4 | レビュー内容を取得し、調査計画を修正する。対応が完了したコメントには対応内容を返信する（2-3〜2-4を合意まで繰り返す）。チャットで受けた判断はMRへ記録する（`references/review-loop.md`「チャットで受けたレビュー判断の記録」節）。**「レビューOK」の合図を受けても、`references/review-loop.md`「レビュー完了合図の確認」節の(1)(2)(3)を通るまでループを閉じない**（未返信スレッドが残っていると`mark-done`が拒否する。issue #70） | `comments` / `reply` | `references/review-loop.md` |
| 2-5 | 調査計画をもとにMR descriptionを更新する | `describe` | `references/review-loop.md` |
| 2-6 | **調査を実施**し、結果を`wip/reports/日付_<全体計画名>_<内容を簡潔に>.md`とwip/worklogsに記録する。**個別調査計画には結果を書かない**（`references/deliverables.md`「計画と実施結果の分離」）。あわせて結果を視覚的に分かりやすくまとめた自己完結HTMLを`wip/reports/日付_<全体計画名>_<内容を簡潔に>.html`として作成する（mdが結果の正文、HTMLはその視覚化。土台は`.claude/skills/issue-mr-flow/assets/reports.template.html`。複数要素間の関連・依存関係が主題の場合は、`.claude/skills/canvas-report/SKILL.md`のcanvas形式テンプレートの利用を検討する。`references/deliverables.md`「計画・レポートのHTMLビュー」）。**ここで初めて規模が判明した場合は、未着手範囲を別issueへ切り出すことを検討する**（`references/planning.md`「issueが大きすぎる場合の分割提案」） | エージェント | `references/deliverables.md` / `references/planning.md` |
| 2-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント | `references/review-loop.md` |
| 2-8 | MRで調査結果についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 | — |
| 2-9 | レビュー内容を取得し、調査結果を修正する。対応が完了したコメントには対応内容を返信する（修正先は`wip/reports/`のmdであり、個別調査計画ではない。`wip/reports/`のHTMLもmdと同期して更新する。2-6〜2-9を合意まで繰り返す）。チャットで受けた判断はMRへ記録する（`references/review-loop.md`「チャットで受けたレビュー判断の記録」節）。**「レビューOK」の合図を受けても、`references/review-loop.md`「レビュー完了合図の確認」節の(1)(2)(3)を通るまでループを閉じない**（未返信スレッドが残っていると`mark-done`が拒否する。issue #70） | `comments` / `reply` | `references/review-loop.md` / `references/deliverables.md` |
| 2-10 | 調査結果をもとにMR descriptionを更新する | `describe` | `references/review-loop.md` |
| 3-1 | **調査結果をもとに**、個別作業計画`wip/plans/【設計】【実装】〜.md`等を**planツールを使わず**Write/Editで作成する。**あわせて同名の `.html`（人間レビュー用ビュー）を作成する**（`references/deliverables.md`「計画・レポートのHTMLビュー」） | エージェント | `references/planning.md` / `references/deliverables.md` |
| 3-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント | `references/review-loop.md` |
| 3-3 | MRで作業計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 | — |
| 3-4 | レビュー内容を取得し、作業計画を修正する。対応が完了したコメントには対応内容を返信する（3-3〜3-4を合意まで繰り返す）。チャットで受けた判断はMRへ記録する（`references/review-loop.md`「チャットで受けたレビュー判断の記録」節）。**「レビューOK」の合図を受けても、`references/review-loop.md`「レビュー完了合図の確認」節の(1)(2)(3)を通るまでループを閉じない**（未返信スレッドが残っていると`mark-done`が拒否する。issue #70） | `comments` / `reply` | `references/review-loop.md` |
| 3-5 | 作業計画をもとにMR descriptionを更新する | `describe` | `references/review-loop.md` |
| 3-6 | 作業計画をもとに作業を進める。作業の詳細な試行錯誤はwip/worklogsに更新し、**作業結果は`wip/reports/日付_<全体計画名>_<内容を簡潔に>.md`に記録する**（**個別作業計画には結果を書かない**。`references/deliverables.md`「計画と実施結果の分離」）。**あわせて同名の`.html`（人間レビュー用ビュー）を作成する**（土台は`.claude/skills/issue-mr-flow/assets/reports.template.html`。`references/deliverables.md`「計画・レポートのHTMLビュー」） | エージェント | `references/deliverables.md` |
| 3-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント | `references/review-loop.md` |
| 3-8 | MRでレビュー・コメントする。レビュー済み連絡をするまで以降の作業は行わない。 | 人間 | — |
| 3-9 | レビュー内容を取得し、実装・ドキュメントを修正する。対応が完了したコメントには対応内容を返信する（結果側の記述の修正先は`wip/reports/`のmdであり、個別作業計画ではない。3-6〜3-9の作業ループを合意まで繰り返す）。チャットで受けた判断はMRへ記録する（`references/review-loop.md`「チャットで受けたレビュー判断の記録」節）。**「レビューOK」の合図を受けても、`references/review-loop.md`「レビュー完了合図の確認」節の(1)(2)(3)を通るまでループを閉じない**（未返信スレッドが残っていると`mark-done`が拒否する。issue #70） | `comments` / `reply` | `references/review-loop.md` / `references/deliverables.md` |
| 3-10 | 作業内容をもとにMR descriptionを更新する | `describe` | `references/review-loop.md` |
| 4-1 | **作業結果と`wip/plans/` `wip/worklogs/` の内容をもとに**、個別反映計画`wip/plans/【設計反映】【AIアセット反映】【実装反映】〜.md`等を**planツールを使わず**Write/Editで作成する。**まず反映対象を洗い出す**（AIアセットの洗い出し手順は`references/planning.md`「AIアセット反映の対象の洗い出し」）。**洗い出した結果が`references/planning.md`「全体作業計画に必ず含めるフェーズ」のスキップ条件を満たす場合に限り、この時点でフェーズ4の残りをスキップしてよい**（判定条件の正はあちらの1箇所で、ここには書かない）。**洗い出した項目は全件、`references/planning.md`「反映対象をこのMRでやるか切り出すかの判断」の主判定へ通す**（判定条件・出口・起票主体の正もあちらの1箇所で、ここには書かない）。**スキップしない場合は、あわせて同名の `.html`（人間レビュー用ビュー）を作成する**（`references/deliverables.md`「計画・レポートのHTMLビュー」） | エージェント | `references/planning.md` / `references/deliverables.md` |
| 4-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント | `references/review-loop.md` |
| 4-3 | MRで反映計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 | — |
| 4-4 | レビュー内容を取得し、反映計画を修正する。対応が完了したコメントには対応内容を返信する（4-3〜4-4を合意まで繰り返す）。チャットで受けた判断はMRへ記録する（`references/review-loop.md`「チャットで受けたレビュー判断の記録」節）。**「レビューOK」の合図を受けても、`references/review-loop.md`「レビュー完了合図の確認」節の(1)(2)(3)を通るまでループを閉じない**（未返信スレッドが残っていると`mark-done`が拒否する。issue #70） | `comments` / `reply` | `references/review-loop.md` |
| 4-5 | 反映計画をもとにMR descriptionを更新する | `describe` | `references/review-loop.md` |
| 4-6 | 反映計画をもとに作業を進める。詳細な試行錯誤はwip/worklogsに更新し、**反映結果は`wip/reports/日付_<全体計画名>_<内容を簡潔に>.md`に記録し、あわせて同名の`.html`（人間レビュー用ビュー）を作成する**（**個別反映計画には結果を書かない**。`references/deliverables.md`「計画と実施結果の分離」。HTMLの土台は`.claude/skills/issue-mr-flow/assets/reports.template.html`。`references/deliverables.md`「計画・レポートのHTMLビュー」）。作業の内訳は次のとおり（**設計反映**: `wip/plans/` `wip/worklogs/` の内容を `.claude/docs/spec/` `.claude/docs/ddr/`（アプリ本体があれば`docs/spec/` `docs/ddr/`）へ反映する。**DDRを追加・変更したら `bash .claude/scripts/src/generate-ddr-list.sh` を実行し、`.claude/docs/README.md` のDDR一覧の差分を同じコミットへ含める**（一覧は生成物。手書きで行を足さない。issue #135。仕様: `.claude/docs/spec/generate-ddr-list.md`）。あわせて、変更が `.claude/docs/usecase/` のユースケース文書に影響するか（記述・リンクが古くならないか）を確認し、影響があれば更新する（issue #170）／**AIアセット反映**: 作業中に気づいたアセットの不備を反映する。対象の洗い出し・反映先の一覧・形態の選び方は`references/planning.md`「AIアセット反映の対象の洗い出し」が正／**実装反映**: フェーズ3のレビュー往復ループ（3-6〜3-9）では解消しきれず持ち越した不具合について、記録（spec/ddr等）への書き戻しと、実装コード・テストコードの修正をあわせて行う）。**この作業中に新たに気づいた反映対象も、4-1 と同じく`references/planning.md`「反映対象をこのMRでやるか切り出すかの判断」の主判定へ通す**（規模が小さいという理由で判定を飛ばさない） | エージェント | `references/deliverables.md` |
| 4-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント | `references/review-loop.md` |
| 4-8 | MRでレビュー・コメントする。レビュー済み連絡をするまで以降の作業は行わない。 | 人間 | — |
| 4-9 | レビュー内容を取得し、設計・AIアセットの内容を修正する。対応が完了したコメントには対応内容を返信する（結果側の記述の修正先は`wip/reports/`のmdであり、個別反映計画ではない。4-6〜4-9の反映ループを合意まで繰り返す）。チャットで受けた判断はMRへ記録する（`references/review-loop.md`「チャットで受けたレビュー判断の記録」節）。**「レビューOK」の合図を受けても、`references/review-loop.md`「レビュー完了合図の確認」節の(1)(2)(3)を通るまでループを閉じない**（未返信スレッドが残っていると`mark-done`が拒否する。issue #70） | `comments` / `reply` | `references/review-loop.md` / `references/deliverables.md` |
| 4-10 | 反映内容をもとにMR descriptionを更新する | `describe` | `references/review-loop.md` |
| 5-1 | **defaultブランチとのコンフリクトを検知し、あれば解消する**（`bash .claude/scripts/src/check-base-conflicts.sh` で判定 → `hasConflict` が真なら `AskUserQuestion` でユーザーに確認 → 承認されたら `resolve-conflict` スキルで解消。詳細は`references/base-branch-followup.md`「defaultブランチとのコンフリクト検知・解消」節）。PR作成後の継続的な追従（`references/base-branch-followup.md`「PR作成後のdefaultブランチ追従（監視）」節）を行っていても、**このステップは最終ゲートとして必ず通る** | エージェント（`resolve-conflict` スキル） | `references/base-branch-followup.md` |
| 5-2 | **今回のMRが影響する関連issueを特定し、承認を得てから当該issueへ通知する**（差分からキーワードを抽出 → `search_issues` で候補提示 → `AskUserQuestion` で対象issueとコメント本文の承認 → `add_issue_comment` で投稿）。**キーワードの抽出時は `wip/plans/` `wip/worklogs/` `wip/reports/` を差分から除外する**（片付けは flow-id 5-5 で行うため、この時点ではこれらの計画・ログ・レポートがまだ差分に含まれる）。**影響先が無ければスキップしてよい**（その場合も「影響先なし」と判断した事実を、リセット前の `HANDOFF.md` へ1行残す）。詳細は`references/phase5-close.md`「マージ前の関連issue通知（flow-id 5-2）」節 | エージェント | `references/phase5-close.md` |
| 5-3 | **`.claude/` の変更を `.gemini/` へ変換同期する**（`bash .claude/scripts/src/sync-gemini-assets.sh` を実行する。`.gemini/` は `.claude/` からの**生成物**であり、手で編集しない。**このステップ自身はcommitを持たない**——生えた差分は直後のflow-id 5-4（最終統括レポート）のcommitに載る。詳細は`references/phase5-close.md`「`.claude/` → `.gemini/` の変換同期（flow-id 5-3）」節） | エージェント | `references/phase5-close.md` |
| 5-4 | **最終統括レポートを作成し、PR/MRへサマリコメントとして反映する**（`wip/reports/日付_<全体計画名>_統括.md` を正文として作成 → `commit` スキル経由でcommit・push → （**任意**）HTMLを `upload_attachment` で添付し、**失敗したら警告のみでスキップ** → サマリを `add_mr_comment` でPR/MRへ1回投稿する）。**反映は3層のフォールバック構造**で、層3が壊れても層1・層2でレビューは成立する。詳細は`references/phase5-close.md`「最終統括レポートとPR/MRへの反映（flow-id 5-4）」節 | エージェント | `references/phase5-close.md` / `references/deliverables.md` / `references/review-loop.md` |
| 5-5 | 次タスクのために、`wip/plans/` `wip/worklogs/` `wip/reports/`（md・htmlの両方）を削除し、`HANDOFF.md` をリセットする（**`bash .claude/scripts/src/cleanup-task.sh` を実行する**。何を消し何を残すか（`wip/worklogs/TEMPLATE.md` と `REVIEW-POINTS.md` は残す。後者はタスク単位の成果物ではなく、そのディレクトリに対する永続のレビュー観点であるため。詳細は `.claude/rules/docs-workflow.md` が正）・`index.jsonl` の再生成・HANDOFF.mdのテンプレートはスクリプトが持つ。先に対象を確認したい場合は `--dry-run` を付ける。仕様: `.claude/docs/spec/cleanup-task.md`）。**スクリプトはコミットまでは行わない**ため、削除・リセットの結果は直後の flow-id 5-6 の `commit` スキル経由でコミットする（**このステップを commit の直前へ置く**のは、生成と確定の間に他のステップを挟まないため。issue #112） | エージェント | `references/phase5-close.md` |
| 5-6 | `commit`スキル経由でcommitし、push して Draftを解除する（解除は `source .claude/scripts/src/vcs/Provider.sh && set_mr_ready <MR番号>` で行う。`gh pr ready` / `glab mr update --ready` を直接呼ばない。MR番号は `get_mr_for_branch` で取得できる）。**AIエージェントはここで止まる**（マージへは進まない） | エージェント | `references/phase5-close.md` / `references/review-loop.md` |
| 5-7 | マージする（squash merge。ブランチは削除してよい）。**AIエージェントは、ユーザーから明示的に指示された場合に限り実行してよい**（下記「PR/MR作成・マージの担当」） | 人間 | — |

## PR/MR作成・マージの担当（flow-id 1-3・5-6・5-7）

**PR/MRの作成・更新はAIエージェントが実施してよい。マージのみユーザーの明示指示を必須とする**
（issue #41）。判断の根拠は「取り消せるか」で、PR/MRの作成・Draft解除・description更新はいつでも
取り消せて `main` を変えないのに対し、マージは `main` の正史を書き換える不可逆な操作である。

| 操作 | 担当 |
|---|---|
| Draft PR/MRの作成（flow-id 1-3）・description更新・レビュー依頼・レビュー返信・Draft解除（flow-id 5-6） | **AIエージェント**（都度の明示指示は不要） |
| マージ（flow-id 5-7） | **人間**。AIエージェントは明示的に指示された場合に限り実行してよい |

flow-id 5-6 を終えたAIエージェントは、フロー上マージが次の一手であっても**そこで止まる**。
「レビューが終わった」「Draftを解除した」「コンフリクトを解消した」はいずれもマージの指示ではない。

**ハーネス（実行基盤）のシステムプロンプトに「ユーザーが明示的に依頼しない限りPRを作成しない」
旨の指示がある環境**（Claude Code on the web のリモート実行環境等）では、ハーネス側の指示が優先
される。その場合の flow-id 1-3 の振る舞い（ブランチ作成まで進め、作成の可否を `AskUserQuestion` で
1回だけ確認する。応答を待てない非対話的セッションではPRを作成せず、その事実を最終応答へ明示する）は
`.claude/rules/git-workflow.md`「ハーネスがPR作成を制限する環境での扱い」が正である。

## 詳細ルールへのポインタ

全体フローの各ステップに関わる詳細は、以下の既存ルールを参照する（このファイルは順序立った
フローの定義に専念し、内容の重複は避ける）。

- ドキュメントの置き場所・ライフサイクル（`wip/plans/` `wip/worklogs/` `wip/reports/` `.claude/docs/spec/` `.claude/docs/ddr/` `HANDOFF.md`）:
  `.claude/rules/docs-workflow.md` の「ドキュメント運用」表
- ブランチ命名規則・squash mergeの方針・コミット運用（`commit`スキル必須使用・PreToolUse hookに
  よる技術的強制）・PR/MR作成とマージの担当（ハーネスがPR作成を制限する環境での扱いを含む）:
  `.claude/rules/git-workflow.md`
- bashスクリプトの規約（`set -euo pipefail`・jq前提・改行/エンコーディング等）:
  `.claude/rules/shell-script-style.md`
- `Provider.sh`の設計・スクリプト言語選定方針（bash化できる/できない判断基準）:
  `.claude/docs/spec/shell-scripts.md`

## 前提

- `gh` CLI（GitHubの場合）または `glab` CLI（GitLabの場合）、および `jq` がインストール・認証済みであること。認証情報自体は各CLIの既存ログイン状態に依存し、本スキル側では管理しない。
  **CLIが存在しない実行環境（Claude Code on the webのリモート実行環境等）では、GitHubに限り
  MCPサーバーツールで代替できる**（`references/mcp-fallback.md`。GitLabは対象外）。
- リポジトリ直下に `.mrworkflow.json` があること（無い場合は `.claude/scripts/src/vcs/Provider.sh` の既定値が使われる）。
- issueは `.github/ISSUE_TEMPLATE/task.md`（GitHub）/ `.gitlab/issue_templates/Default.md`（GitLab）のテンプレートに沿って「目的・現状・期待する動作・受け入れ条件」を記載しておくことが望ましい
  （必須ではなく、`start` サブコマンドが欠落を警告する）。
- Claude Code/GeminiCLIのセッションとMRの関係性については、多:1の関係を許容する（1つのMRに対して複数セッションを切り替えて作業してもよい）。
  ただし、1:多は想定しない。つまり、同一セッション内で複数MRを同時に扱うことはできない（`resume` は1つのMRに対してのみ現在地確認を行うため）。

## 旧節名→新しい場所の対応表（issue #160）

issue #160 で本ファイルの詳細節を `references/` 配下へ切り出した。**DDR本文・specの過去
changelog（point-in-time の記録）は書き換えない**運用（`.claude/rules/docs-workflow.md`）のため、
そこから旧来の節名で参照されている読み手は、この表で新しい場所を辿ること。節名そのものは
切り出し後も変えていない（表では `（issue #NN）` の接尾辞を省いて載せる。手順名・引用句の
参照は、その手順を含む節の行で辿る）。ただし次の2点は切り出しに伴う調整である:
`references/review-loop.md` へ導入用の節「サブコマンド（レビュー往復系）」を**新設**した。
`references/planning.md` と `references/deliverables.md` では、元がH3/H4だった節の
**見出しレベルを1段上げた**（節名の文字列は変えていない）。

| 節名 | 現在の場所 |
|---|---|
| 「全体フロー」（43行テーブル） | 本ファイル（SKILL.md）に残る |
| 「PR/MR作成・マージの担当」 | 本ファイル（SKILL.md）に残る |
| 「詳細ルールへのポインタ」 | 本ファイル（SKILL.md）に残る |
| 「前提」 | 本ファイル（SKILL.md）に残る |
| 「全体作業計画に必ず含めるフェーズ」 | `references/planning.md` |
| 「計画の2階層構造」（「種別を複数併記する場合／分ける場合」を含む） | `references/planning.md` |
| 「issueが大きすぎる場合の分割提案」 | `references/planning.md` |
| 「計画と実施結果の分離」 | `references/deliverables.md` |
| 「計画・レポートのHTMLビュー」 | `references/deliverables.md` |
| 「サブコマンド」（導入・共通の前提） | `references/start-resume.md` |
| 「`start`」「`sync`」「`resume`」の各サブコマンド | `references/start-resume.md` |
| 「作業開始・再開時のベースブランチ追従確認」 | `references/start-resume.md` |
| 「敵対的レビューの位置づけ」 | `references/review-loop.md` |
| 「`comments`」「`reply`」「`describe`」の各サブコマンド | `references/review-loop.md` |
| 「チャットで受けたレビュー判断の記録」 | `references/review-loop.md` |
| 「レビュー依頼メッセージ」 | `references/review-loop.md` |
| 「レビュー完了合図の確認」 | `references/review-loop.md` |
| 「PR作成後のdefaultブランチ追従（監視）」 | `references/base-branch-followup.md` |
| 「defaultブランチとのコンフリクト検知・解消」 | `references/base-branch-followup.md` |
| 「`gh`/`glab` CLI不在時のMCPフォールバック」 | `references/mcp-fallback.md` |
| 「マージ前の関連issue通知」 | `references/phase5-close.md` |
| 「最終統括レポートとPR/MRへの反映」 | `references/phase5-close.md` |
| 「PRがflow-id 5-5実施前にマージされてしまった場合の対処」 | `references/phase5-close.md` |
| 「`.claude/` → `.gemini/` の変換同期」（issue #70でSKILL.mdへ追加された節） | `references/phase5-close.md` |

## flow-idを並べ替える・挿入する作業を行う場合（issue #143）

flow-idの並べ替え・新規ステップの挿入（過去の実例: issue #112「フェーズ5並べ替え」・issue #111
「統括レポート追加」・issue #70「gemini変換同期ステップ追加」）を行う際は、
`.claude/rules/docs-workflow.md` `.claude/skills/issue-mr-flow/SKILL.md`本体の変更を終えた後、
**変更作業の最後に**次を確認する。

1. **まず、今回変更した番号（旧番号→新番号）を先に列挙し、その旧番号だけを固定文字列で
   横断grepする**（例: 旧番号が`5-4`なら`git grep -n -- '5-4'`）。次に、取りこぼしが無いかの
   補助確認として、`[0-9]-[0-9]`という数字パターン全体（`flow-id`の接頭辞が付かないもの——
   `2-3〜2-4`のような範囲表記・`flow-id 2-2/2-7/…`のようなスラッシュ連結表記を含む）も横断grepする。
   ```bash
   git -c core.quotePath=false grep -nE '[0-9]-[0-9]' -- \
     '*.md' '*.sh' '*.html' ':(exclude)wip/plans/*' ':(exclude)wip/worklogs/*' ':(exclude)wip/reports/*' \
     'wip/plans/REVIEW-POINTS.md' 'wip/reports/REVIEW-POINTS.md'
   ```
   このパターンは日付（`2026-08-23`等）にもヒットし、リポジトリ全体で2000行規模・SKILL.md単体でも
   150件規模になりうる。**1件ずつ確認するのは現実的ではない**ため、この全体走査は手順1前段の
   固定文字列grepで拾いきれなかった取りこぼしの有無を確かめる補助に位置づける
   （`core.quotePath=false`を付けないと、`wip/plans/` `wip/worklogs/`配下の日本語ファイル名が
   ダブルクォート＋8進エスケープで出力され、下記2の除外パススペックに一致しなくなる点に注意する）。
2. `wip/plans/` `wip/worklogs/` `wip/reports/`配下はタスク単位で削除される成果物のため走査対象から
   除外してよいが、**除外はファイル単位で判断する**（理由・実例は`.claude/rules/docs-workflow.md`
   「flow-idの繰り下げのような横断的な棚卸しでは」の段落が正——本節では重複説明しない）。
   上記1のコマンド例は`wip/plans/REVIEW-POINTS.md` `wip/reports/REVIEW-POINTS.md`を明示的に
   除外対象から戻している。
3. ヒットした記述が**現在の状態を説明しているか、過去の記録（point-in-time）か**で判断する
   （ファイルの種類では判断しない）。`.claude/docs/spec/*.md` `.claude/docs/ddr/*.md`の過去
   changelog・DDR本文だけでなく、`.claude/scripts/`配下のコメントも対象になる。ただし
   `.claude/scripts/`配下のコメントは、**同じ1行に現在値と経緯が同居している**ことが多い点に
   注意する（例: `cleanup-task.sh`冒頭「flow-id 5-5（次タスクのための片付け）を自動化する
   （issue #28。当時のflow-idは 5-1。issue #112 の並べ替えで 5-3 になり、issue #111 の統括
   レポート追加で 5-4、issue #70 の変換同期の新設で現在は 5-5）」）。**経緯部分（「当時は〜」
   「issue #NNで〜になった」）は書き換えず、現在値部分（「現在は5-5」等）だけを新しい番号へ
   更新する**。ファイル全体を「書き換えない」と
   一律に扱うと、この種のコメントの現在値が古いまま残る。
4. 確認した結果（何件見つかり、どう対処したか）を、**コミットメッセージへ必ず残す**。
   `wip/reports/`はタスク単位の作業記録としてブランチ上でのみ参照でき、flow-id 5-5（次タスクのための
   片付け）で削除されmainには残らないため、恒久的に参照したい内容（新たな落とし穴の発見等）は
   spec/DDRへ書く。
   件名の書き方は`.claude/skills/commit/SKILL.md`「コミットメッセージの内容規約」が正で、
   **「件数だけ」で終わる件名は不合格**である（issue #185）。

背景・却下案は `.claude/docs/ddr/i0143-01-flow-id並べ替え時の確認手順をSKILL.mdへ明記しDDRで記録する.md` を参照。
