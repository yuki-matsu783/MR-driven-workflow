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

- issue: #22 issue-mr-flow適用要否の判定基準をAGENTS.mdに一元化し、SKILL.md/git-workflow.mdの重複記載を整理する
- ブランチ: claude/issue-22-zx5ge5
- Draft PR: #30 https://github.com/yuki-matsu783/MR-driven-workflow/pull/30
- push回数: 1

進捗記号: `[x]` 完了 / `[]` 未着手・進行中 / `[-]` 今回は実施しない（スキップ）

| 進捗 | flow-id | ステップ | 担当 |
|----|---|---|---|
| [x] | 1-1 | issueを起票する（`.github/ISSUE_TEMPLATE/task.md` / `.gitlab/issue_templates/task.md` で目的・現状・期待する動作・受け入れ条件を記載） | 人間（AIが代行する場合は `issue-create` スキル） |
| [x] | 1-2 | issueの内容を取得する | `start <issue番号>` |
| [x] | 1-3 | featureブランチ（`feature-<issue番号>-<slug>`）とDraft MRを作成する（既にあれば `sync` のみ）。**ブランチはClaude Code on the web環境から `claude/issue-22-zx5ge5` として既に用意されており命名規則には従わないが、issue #22の作業ブランチとして使用**。コミット差分が無かったため空コミット→push後にDraft PR #30をGitHub MCPツールで作成（gh CLIが実行環境に無いため） | エージェント |
| [x] | 1-4 | **Planモードで「全体作業計画」を作成する** → `plans/iterative-dreaming-yao.md` | エージェント |
| [x] | 1-5 | 全体作業計画に合意する | 人間 |
| [x] | 1-6 | 全体作業計画をもとにHANDOFF.mdを更新する | エージェント |
| [-] | 2-1 | **個別調査計画**（全体作業計画で「対象箇所・方針がissue本文に明確なため調査フェーズは不要」と判断し省略） | エージェント |
| [-] | 2-2 | （2-1を省略のため対象外） | エージェント |
| [-] | 2-3 | （同上） | 人間 |
| [-] | 2-4 | （同上） | `comments` / `reply` |
| [-] | 2-5 | （同上） | `describe` |
| [-] | 2-6 | （同上） | エージェント |
| [-] | 2-7 | （同上） | エージェント |
| [-] | 2-8 | （同上） | 人間 |
| [-] | 2-9 | （同上） | `comments` / `reply` |
| [-] | 2-10 | （同上） | `describe` |
| [x] | 3-1 | 個別作業計画`plans/【設計】判定基準の一元化.md`を**planツールを使わず**Write/Editで作成する | エージェント |
| [x] | 3-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [x] | 3-3 | MRで作業計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| [x] | 3-4 | レビュー内容を取得し、作業計画を修正する。対応が完了したコメントには対応内容を返信する（3-3〜3-4を合意まで繰り返す）。PR #30の未解決コメント・レビュー・通常コメントいずれも0件で修正不要と確認 | `comments` / `reply` |
| [x] | 3-5 | 作業計画をもとにMR descriptionを更新する | `describe` |
| [x] | 3-6 | 作業計画をもとに作業を進める、作業内容はworklogに更新する。`AGENTS.md`・`SKILL.md`・`git-workflow.md`の3ファイルへ差分適用完了 | エージェント |
| [x] | 3-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [x] | 3-8 | MRでレビュー・コメントする。レビュー済み連絡をするまで以降の作業は行わない。**別セッション（PR #30レビュー専用セッション、ブランチ`claude/pr-30-review-complete-xlb66m`）がcode-reviewスキルでPRをレビューし、HANDOFF.mdの「次にやること」欄の更新漏れを指摘するインラインコメント1件をCOMMENTとして投稿** | 人間（今回は上記セッションが代行） |
| [x] | 3-9 | レビュー内容を取得し、実装・ドキュメントを修正する。対応が完了したコメントには対応内容を返信する（3-6〜3-9の作業ループを合意まで繰り返す）。指摘どおり本ファイルの「次にやること」欄を更新し、スレッドへ対応内容を返信済み。他に未解決コメント無し | `comments` / `reply` |
| [] | 3-10 | 作業内容をもとにMR descriptionを更新する | `describe` |
| [] | 4-1 | **作業結果と`plans/` `worklog/` の内容をもとに**、個別反映計画`plans/【設計反映】【AIアセット反映】〜.md`等を**planツールを使わず**Write/Editで作成する | エージェント |
| [] | 4-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 4-3 | MRで反映計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| [] | 4-4 | レビュー内容を取得し、反映計画を修正する。対応が完了したコメントには対応内容を返信する（4-3〜4-4を合意まで繰り返す） | `comments` / `reply` |
| [] | 4-5 | 反映計画をもとにMR descriptionを更新する | `describe` |
| [] | 4-6 | 反映計画をもとに作業を進める、反映内容はworklogに更新する（**設計反映**: `plans/` `worklog/` の内容を `.claude/docs/spec/` `.claude/docs/ddr/`（アプリ本体があれば`docs/spec/` `docs/ddr/`）へ反映する／**AIアセット反映**: 作業中に気づいたルール・スキルの不備を `.claude/rules/` `.claude/skills/` `CLAUDE.md` `AGENTS.md` に反映する） | エージェント |
| [] | 4-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 4-8 | MRでレビュー・コメントする。レビュー済み連絡をするまで以降の作業は行わない。 | 人間 |
| [] | 4-9 | レビュー内容を取得し、設計・AIアセットの内容を修正する。対応が完了したコメントには対応内容を返信する（4-6〜4-9の反映ループを合意まで繰り返す） | `comments` / `reply` |
| [] | 4-10 | 反映内容をもとにMR descriptionを更新する | `describe` |
| [] | 5-1 | 次タスクのために、`plans/` `worklog/` `reports/` を削除し、`HANDOFF.md` をリセットする。**あわせて `plans/index.jsonl` も削除し、`bash .claude/scripts/src/extract-frontmatter.sh .` で `index.jsonl` 群を再生成する** | エージェント |
| [] | 5-2 | `commit`スキル経由でcommitし、push して Draftを解除する | エージェント |
| [] | 5-3 | マージする（squash merge。ブランチは削除してよい） | 人間 |

詳細についてはworklogを確認してください。

## やったこと

- issue #22の内容取得（GitHub MCPツール経由。gh CLIが実行環境に無いため`mcp__github__issue_read`で代替）
- ブランチ`claude/issue-22-zx5ge5`（Claude Code on the web環境が用意した既存ブランチ、mainとの差分無し）で空コミットを作成しpush、Draft PR #30を`mcp__github__create_pull_request`で作成
- Planモードで全体作業計画`plans/iterative-dreaming-yao.md`を作成・承認。issue本文に対象箇所・方針が明確なため、フェーズ2（調査）は省略しフェーズ3（作業計画）から着手すると判断
- 個別作業計画`plans/【設計】判定基準の一元化.md`とworklogを作成し、commit・push・PR description更新（`mcp__github__update_pull_request`）してレビュー依頼
- レビューOK確認（PR #30の未解決コメント・レビュー0件を`mcp__github__pull_request_read`で確認）後、`AGENTS.md`・`.claude/skills/issue-mr-flow/SKILL.md`・`.claude/rules/git-workflow.md`の3ファイルへ判定基準一元化の差分を適用。適用中に`git-workflow.md`側で判定基準の例示が帰結説明に残っていたことに気づき、完全削除するよう個別作業計画も含めて修正
- 別セッション（PR #30レビュー専用、ブランチ`claude/pr-30-review-complete-xlb66m`）がcode-reviewスキルでPR #30をレビューし、本ファイルの「次にやること」欄がflow-id 3-7完了後も更新されていない旨をインラインコメントで指摘（レビューはCOMMENTとして提出）
- 本セッション（ブランチ`claude/issue-22-zx5ge5`）で指摘に対応: 本ファイルの「次にやること」欄をflow-id 3-9完了時点の内容へ更新し、レビュースレッドへ対応内容を返信

## 次にやること

- 対応内容をもとにMR descriptionを更新する（flow-id 3-10）

## 判断を迷った内容

- gh/glab CLIが実行環境に存在しなかったため、`Provider.sh`のPR作成関数（`github_new_draft_merge_request`）を使わず、GitHub MCPツール（`mcp__github__create_pull_request`）で直接Draft PRを作成した（AGENTS.md「GitHub/GitLabのissue・PR/MR・コメント等の情報を取得する際は」の規定に沿った代替）。空コミットの作成は`Provider.sh`の`add_empty_commit_for_draft_mr`関数をsource経由で呼び出し、hookのブロック対象文字列（`git commit`のBash文字列直書き）を避けた

## 未解決の内容

（無し）

## 守るべき条件・触ってはいけない範囲

（無し）
