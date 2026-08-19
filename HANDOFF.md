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

- issue: #86 マージ前に今回のMRが影響する関連issueを特定し通知するステップを追加する
- ブランチ: claude/mr-merge-issue-notification-ev5rht
- PR: 未作成（ハーネスがPR作成を制限する環境のため、ユーザーの明示指示待ち）
- push回数: 1
- 追従監視: 未開始（PR未作成のため）

## フロー進捗状況

進捗記号: `[x]` 完了 / `[]` 未着手・進行中 / `[-]` 今回は実施しない（スキップ）

| 進捗 | flow-id | ステップ | 担当 |
|----|---|---|---|
| [x] | 1-1 | issueを起票する（`.github/ISSUE_TEMPLATE/task.md` / `.gitlab/issue_templates/Default.md` で目的・現状・期待する動作・受け入れ条件を記載）（issue #86 として起票済み） | 人間（AIが代行する場合は `issue-create` スキル） |
| [x] | 1-2 | issueの内容を取得する（`gh` CLI不在のためMCP経路（`mcp__github__issue_read`）で取得。4見出しすべて揃っている） | `start <issue番号>` |
| [x] | 1-3 | featureブランチ（`feature-<issue番号>-<slug>`）とDraft MRを作成する（既にあれば `sync` のみ）。**Draft MRの作成に都度の明示指示は要らない**（下記「PR/MR作成・マージの担当」。ハーネスがPR作成を制限する環境での例外も同節）。**作成後は「PR作成後のdefaultブランチ追従（監視）」節に従って追従監視を開始する**（ブランチはハーネス指定の `claude/mr-merge-issue-notification-ev5rht`（`feature-<issue番号>-<slug>` 命名規則の対象外）。**PRは未作成**（ハーネスがPR作成を制限する環境のため、ユーザーの明示指示待ち。`.claude/rules/git-workflow.md`「ハーネスがPR作成を制限する環境での扱い」）） | `start`（エージェント） |
| [-] | 1-4 | **Planモードで「全体作業計画」を作成する**（このissueをどう進めるか＝何を調査し何を実装するかの全体像。ハーネスが提示するパス `plans/<自動命名>.md` へ出力）。**現在のブランチに既に全体作業計画があれば新規作成せず、既存を読むだけにとどめる**（詳細は下記「計画の2階層構造」）。**作成前に、issueが大きすぎないか（同型の成果物が並列に列挙されていないか）を判定し、該当すれば分割を提案する**（下記「issueが大きすぎる場合の分割提案」）（非対話的なリモート実行セッションでPlanモードでの合意が取れないため省略し、issue #86 の「期待する動作」「受け入れ条件」を全体作業計画として扱った） | エージェント |
| [-] | 1-5 | 全体作業計画に合意する（1-4を省略のため対象外） | 人間 |
| [x] | 1-6 | 全体作業計画をもとにHANDOFF.mdを更新する（本ファイル） | エージェント |
| [-] | 2-1 | **個別調査計画**`plans/【調査】〜.md`を**planツールを使わず**Write/Editで作成する。このタイミングで `worklog/日付_<全体計画名>_<個別計画名>_push<N>.md` を作成（調査はissue本文と既存コード・ドキュメントの読み取りで完結したため、フェーズ2を丸ごと省略） | エージェント |
| [-] | 2-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [-] | 2-3 | MRで調査計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| [-] | 2-4 | レビュー内容を取得し、調査計画を修正する。対応が完了したコメントには対応内容を返信する（2-3〜2-4を合意まで繰り返す） | `comments` / `reply` |
| [-] | 2-5 | 調査計画をもとにMR descriptionを更新する | `describe` |
| [-] | 2-6 | **調査を実施**し、結果を`reports/日付_<全体計画名>_<内容を簡潔に>.md`とworklogに記録する。**個別調査計画には結果を書かない**（下記「計画と実施結果の分離」）。あわせて結果を視覚的に分かりやすくまとめた自己完結HTML（TailwindCSS CDN方式）を`reports/日付_<全体計画名>_<内容を簡潔に>.html`として作成する（mdが結果の正文、HTMLはその視覚化。複数要素間の関連・依存関係が主題の場合は、`.claude/skills/canvas-report/SKILL.md`のcanvas形式テンプレートの利用を検討する）。**ここで初めて規模が判明した場合は、未着手範囲を別issueへ切り出すことを検討する**（下記「issueが大きすぎる場合の分割提案」） | エージェント |
| [-] | 2-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [-] | 2-8 | MRで調査結果についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| [-] | 2-9 | レビュー内容を取得し、調査結果を修正する。対応が完了したコメントには対応内容を返信する（修正先は`reports/`のmdであり、個別調査計画ではない。`reports/`のHTMLもmdと同期して更新する。2-6〜2-9を合意まで繰り返す） | `comments` / `reply` |
| [-] | 2-10 | 調査結果をもとにMR descriptionを更新する | `describe` |
| [x] | 3-1 | **調査結果をもとに**、個別作業計画`plans/【設計】【実装】〜.md`等を**planツールを使わず**Write/Editで作成する（`plans/【設計】【実装】マージ前の関連issue通知ステップを追加する.md`） | エージェント |
| [x] | 3-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う（commitは実施。pushはこのcommitの直後に行う） | エージェント |
| [] | 3-3 | MRで作業計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。（非対話セッションのため未実施） | 人間 |
| [] | 3-4 | レビュー内容を取得し、作業計画を修正する。対応が完了したコメントには対応内容を返信する（3-3〜3-4を合意まで繰り返す） | `comments` / `reply` |
| [-] | 3-5 | 作業計画をもとにMR descriptionを更新する（PR未作成のため対象外） | `describe` |
| [] | 3-6 | 作業計画をもとに作業を進める。作業の詳細な試行錯誤はworklogに更新し、**作業結果は`reports/日付_<全体計画名>_<内容を簡潔に>.md`に記録する**（**個別作業計画には結果を書かない**。下記「計画と実施結果の分離」）。結果を視覚的にまとめる必要があれば同名の`.html`も作成する（**実作業は完了済み**（`add_issue_comment` の新設・flow-id 5-3の追加・繰り下げ）。結果は `reports/20260819_mr-merge-issue-notification_関連issue通知ステップの追加.md`。人間レビューを挟めずループが1周していないため記号は `[]` のまま） | エージェント |
| [] | 3-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う（commit・pushは実施済み） | エージェント |
| [] | 3-8 | MRでレビュー・コメントする。レビュー済み連絡をするまで以降の作業は行わない。（非対話セッションのため未実施） | 人間 |
| [] | 3-9 | レビュー内容を取得し、実装・ドキュメントを修正する。対応が完了したコメントには対応内容を返信する（結果側の記述の修正先は`reports/`のmdであり、個別作業計画ではない。3-6〜3-9の作業ループを合意まで繰り返す） | `comments` / `reply` |
| [-] | 3-10 | 作業内容をもとにMR descriptionを更新する（PR未作成のため対象外） | `describe` |
| [-] | 4-1 | **作業結果と`plans/` `worklog/` の内容をもとに**、個別反映計画`plans/【設計反映】【AIアセット反映】〜.md`等を**planツールを使わず**Write/Editで作成する（個別反映計画を独立ファイルにせず、実装と同じ回でspec・DDRへ反映した） | エージェント |
| [-] | 4-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [-] | 4-3 | MRで反映計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| [-] | 4-4 | レビュー内容を取得し、反映計画を修正する。対応が完了したコメントには対応内容を返信する（4-3〜4-4を合意まで繰り返す） | `comments` / `reply` |
| [-] | 4-5 | 反映計画をもとにMR descriptionを更新する（PR未作成のため対象外） | `describe` |
| [] | 4-6 | 反映計画をもとに作業を進める。詳細な試行錯誤はworklogに更新し、**反映結果は`reports/日付_<全体計画名>_<内容を簡潔に>.md`に記録する**（**個別反映計画には結果を書かない**。下記「計画と実施結果の分離」）。作業の内訳は次のとおり（**設計反映**: `plans/` `worklog/` の内容を `.claude/docs/spec/` `.claude/docs/ddr/`（アプリ本体があれば`docs/spec/` `docs/ddr/`）へ反映する／**AIアセット反映**: 作業中に気づいたルール・スキルの不備を `.claude/rules/` `.claude/skills/` `CLAUDE.md` `AGENTS.md` に反映する）（**設計反映の実作業は完了済み**（spec「マージ前の関連issue通知（issue #86）」節・提供関数表・影響範囲・未決定事項、DDR 0041、`.claude/docs/README.md`）。AIアセット反映（`.claude/rules/git-workflow.md` の担当表へ flow-id 5-3 の行を追加等）も同時に実施。人間レビューを挟めずループが1周していないため記号は `[]` のまま） | エージェント |
| [] | 4-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う（commit・pushは実施済み） | エージェント |
| [] | 4-8 | MRでレビュー・コメントする。レビュー済み連絡をするまで以降の作業は行わない。（非対話セッションのため未実施） | 人間 |
| [] | 4-9 | レビュー内容を取得し、設計・AIアセットの内容を修正する。対応が完了したコメントには対応内容を返信する（結果側の記述の修正先は`reports/`のmdであり、個別反映計画ではない。4-6〜4-9の反映ループを合意まで繰り返す） | `comments` / `reply` |
| [-] | 4-10 | 反映内容をもとにMR descriptionを更新する（PR未作成のため対象外） | `describe` |
| [-] | 5-1 | 次タスクのために、`plans/` `worklog/` `reports/`（md・htmlの両方）を削除し、`HANDOFF.md` をリセットする（本ブランチの `plans/` `worklog/` `reports/` はレビュー前のため未削除。次タスク着手前に実施する） | エージェント |
| [-] | 5-2 | **defaultブランチとのコンフリクトを検知し、あれば解消する**（`bash .claude/scripts/src/check-base-conflicts.sh` で判定 → `hasConflict` が真なら `AskUserQuestion` でユーザーに確認 → 承認されたら `resolve-conflict` スキルで解消。詳細は下記「defaultブランチとのコンフリクト検知・解消」節）。PR作成後の継続的な追従（下記「PR作成後のdefaultブランチ追従（監視）」節）を行っていても、**このステップは最終ゲートとして必ず通る**（PR未作成のため未実施。Draft解除（5-4）の前に必ず通す） | エージェント（`resolve-conflict` スキル） |
| [x] | 5-3 | **今回のMRが影響する関連issueを特定し、承認を得てから当該issueへ通知する**（差分からキーワードを抽出 → `search_issues` で候補提示 → `AskUserQuestion` で対象issueとコメント本文の承認 → `add_issue_comment` で投稿）。**影響先が無ければスキップしてよい**。詳細は下記「マージ前の関連issue通知（flow-id 5-3）」節（**新設した本ステップを自ら実行した**。候補5件を3類型で判定して1件へ絞り、`AskUserQuestion` で承認を得たうえで issue #67 へ1件投稿（MCP経路。https://github.com/yuki-matsu783/MR-driven-workflow/issues/67#issuecomment-5344871722 ）） | エージェント |
| [] | 5-4 | `commit`スキル経由でcommitし、push して Draftを解除する（解除は `source .claude/scripts/src/vcs/Provider.sh && set_mr_ready <MR番号>` で行う。`gh pr ready` / `glab mr update --ready` を直接呼ばない。MR番号は `get_mr_for_branch` で取得できる）。**AIエージェントはここで止まる**（マージへは進まない）（PR未作成のため未実施） | エージェント |
| [] | 5-5 | マージする（squash merge。ブランチは削除してよい）。**AIエージェントは、ユーザーから明示的に指示された場合に限り実行してよい**（下記「PR/MR作成・マージの担当」）（人間が実施） | 人間 |

## やったこと

- **`add_issue_comment <issue番号> <bodyFile>` を新設**した（`Provider.sh` のディスパッチャ、
  `Github.sh` の `gh issue comment --body-file`、`Gitlab.sh` の
  `glab api projects/:id/issues/<iid>/notes`）。`add_mr_comment` は宛先がPR/MRで流用できないため別関数。
  `mcp_tool_hint` にも行を追加した。
- **フェーズ5へ flow-id 5-3「関連issueの特定・通知」を新設**し、旧5-3（Draft解除）→5-4、
  旧5-4（マージ）→5-5へ繰り下げた（**全40→41ステップ**）。SKILL.md へ手順の正となる節
  「マージ前の関連issue通知（flow-id 5-3）」を追加。
- flow-idとステップ数の参照を全ファイルで更新した（`SKILL.md` / `commit/SKILL.md` /
  `resolve-conflict/SKILL.md` / `git-workflow.md` / `docs-workflow.md` / `spec/issue-mr-workflow.md` /
  `Provider.sh` `Github.sh` `Gitlab.sh` のコードコメント）。**`docs/ddr/*.md` 本文と
  `docs/spec/*.md` の「影響範囲」節（point-in-timeの記録）は意図的に更新していない。**
- 設計判断を **DDR 0041** として記録し、spec へ「マージ前の関連issue通知（issue #86）」節・
  提供関数表の行・影響範囲・未決定事項を追加した。
- **新ステップを自ら実行した（ドッグフーディング）。** 候補5件を3類型で判定して1件へ絞り、
  `AskUserQuestion` で承認を得たうえで issue #67 へ1件投稿した（MCP経路での実機検証を兼ねる）。
- 単体テストを2件追加し `passed=98 failures=0`。結果の正文は
  `reports/20260819_mr-merge-issue-notification_関連issue通知ステップの追加.md`。

## 次にやること

- **PRの作成**（ユーザーの明示指示が必要。この実行環境はハーネスがPR作成を制限している）。
- PR作成後: 追従監視の開始（`subscribe_pr_activity` / `send_later`）と `HANDOFF.md` の
  `- 追従監視:` 行の更新。
- 人間によるレビュー（flow-id 3-3/3-8・4-3/4-8）と、その結果に応じた修正・返信。
- flow-id 5-1（`plans/` `worklog/` `reports/` の削除・本ファイルのリセット）→ 5-2（コンフリクト検知）
  → 5-4（Draft解除）。

## 判断を迷った内容

- **新ステップの挿入位置**（5-1の前／5-2の前／5-2と旧5-3の間／マージ後）。「通知内容が確定するのは
  5-2を終えた時点」「5-1の削除と5-2のbase取り込みの後でないと差分がマージされる内容と一致しない」
  「マージ後はセッションが生きていない」の3点から、5-2と旧5-3の間に決めた（DDR 0041「理由」）。
- **`add_mr_comment` の拡張（第3引数で宛先種別を指定）と別関数の新設**。関数名と実際の宛先が
  矛盾すること・GitHub実装側で結局分岐が要ることから、別関数にした（DDR 0041「却下した案」）。

## 未解決の内容

- **`add_issue_comment` のCLI経路（`gh issue comment` / `glab api`）が実機未検証。** 本セッションの
  実行環境に `gh`・`glab` のいずれも存在しないため。MCP経路のみ実機確認済み。spec の
  「未決定事項・懸念点」へ項目として残してある。
- **`search_issues`（MCP版）だけでは候補を取りこぼした。** 実際に影響のある issue #67 は
  `mcp__github__search_issues` の結果に現れず、openのissue一覧との突き合わせで見つけた。SKILL.md の
  手順は `search_issues` を起点として書いているが、実務上は一覧にも目を通すのが確実。手順の改訂は
  本issueの範囲を超えるため行っていない（必要なら別issueで扱う）。

## 守るべき条件・触ってはいけない範囲

- **`docs/ddr/*.md` の本文と、`docs/spec/*.md` の過去issueごとの「影響範囲」節は、flow-idの改番に
  合わせて書き換えない**（`.claude/rules/docs-workflow.md`）。今回も
  `spec/check-base-conflicts.md`「issue #46」の「旧5-2→5-3、旧5-3→5-4。全39→40ステップ」等は
  当時の記録としてそのまま残している。
- `add_mr_comment` の既存挙動（宛先はPR/MR）は変更しない。呼び出し元は
  `post-push-usage-report.sh` の対応工数レポート。
- **flow-id 5-3 の投稿は、`AskUserQuestion` での承認なしに行わない**（DDR 0041 の中核。
  この規約を破る実装・運用へ変えない）。
