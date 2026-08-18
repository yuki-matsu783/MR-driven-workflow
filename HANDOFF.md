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

- issue: #34 gh/glab CLIが無い環境向けのMCPフォールバック経路をスキル・スクリプトに実装する
- ブランチ: claude/issue-34-sm2mqs
- PR: 未作成（ユーザーからの明示指示待ち）
- push回数: 1

進捗記号: `[x]` 完了 / `[]` 未着手・進行中 / `[-]` 今回は実施しない（スキップ）

| 進捗 | flow-id | ステップ | 担当 |
|----|---|---|---|
| [x] | 1-1 | issueを起票する（`.github/ISSUE_TEMPLATE/task.md` / `.gitlab/issue_templates/task.md` で目的・現状・期待する動作・受け入れ条件を記載） | 人間（AIが代行する場合は `issue-create` スキル） |
| [x] | 1-2 | issueの内容を取得する（`gh` CLI不在のため `mcp__github__issue_read` で取得） | `start <issue番号>` |
| [] | 1-3 | featureブランチとDraft MRを作成する（既にあれば `sync` のみ）。**ブランチ`claude/issue-34-sm2mqs`はClaude Code on the web環境が用意済みで命名規則には従わない。Draft PRはユーザーの明示指示が無いため未作成** | エージェント |
| [x] | 1-4 | **Planモードで「全体作業計画」を作成する** → `plans/steady-bridging-gateway.md`（非対話環境のためplanツールは使わずWrite/Editで作成） | エージェント |
| [] | 1-5 | 全体作業計画に合意する | 人間 |
| [x] | 1-6 | 全体作業計画をもとにHANDOFF.mdを更新する | エージェント |
| [-] | 2-1 | **個別調査計画**（全体作業計画で「対象ファイル・方針が受け入れ条件で確定済み」と判断し調査フェーズは省略） | エージェント |
| [-] | 2-2 | （2-1を省略のため対象外） | エージェント |
| [-] | 2-3 | （同上） | 人間 |
| [-] | 2-4 | （同上） | `comments` / `reply` |
| [-] | 2-5 | （同上） | `describe` |
| [-] | 2-6 | （同上） | エージェント |
| [-] | 2-7 | （同上） | エージェント |
| [-] | 2-8 | （同上） | 人間 |
| [-] | 2-9 | （同上） | `comments` / `reply` |
| [-] | 2-10 | （同上） | `describe` |
| [x] | 3-1 | 個別作業計画`plans/【設計】【実装】gh-glab不在時のMCPフォールバック経路.md`を**planツールを使わず**Write/Editで作成する。worklogも作成 | エージェント |
| [x] | 3-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 3-3 | MRで作業計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。**非対話的実行環境のため未実施** | 人間 |
| [] | 3-4 | レビュー内容を取得し、作業計画を修正する（3-3〜3-4を合意まで繰り返す）。**同上** | `comments` / `reply` |
| [] | 3-5 | 作業計画をもとにMR descriptionを更新する（PR未作成のため未実施） | `describe` |
| [] | 3-6 | 作業計画をもとに作業を進める、作業内容はworklogに更新する。**実作業は完了済み**（Provider.sh・hook3本・SKILL.md 2本・AGENTS.md・テストを変更）。人間レビュー（3-8/3-9）が未実施のためループ範囲は`[]`のまま | エージェント |
| [] | 3-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う。**push実施済み**（同上の理由で記号は`[]`） | エージェント |
| [] | 3-8 | MRでレビュー・コメントする。**非対話的実行環境のため未実施** | 人間 |
| [] | 3-9 | レビュー内容を取得し、実装・ドキュメントを修正する（3-6〜3-9の作業ループを合意まで繰り返す）。**同上** | `comments` / `reply` |
| [] | 3-10 | 作業内容をもとにMR descriptionを更新する（PR未作成のため未実施） | `describe` |
| [x] | 4-1 | **作業結果と`plans/` `worklog/` の内容をもとに**、個別反映計画を作成する → `plans/【設計反映】MCPフォールバック経路の設計反映.md` | エージェント |
| [x] | 4-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 4-3 | MRで反映計画についてレビュー・コメントする。**非対話的実行環境のため未実施** | 人間 |
| [] | 4-4 | レビュー内容を取得し、反映計画を修正する（4-3〜4-4を合意まで繰り返す）。**同上** | `comments` / `reply` |
| [] | 4-5 | 反映計画をもとにMR descriptionを更新する（PR未作成のため未実施） | `describe` |
| [] | 4-6 | 反映計画をもとに作業を進める、反映内容はworklogに更新する。**設計反映（spec更新・DDR 0025新設）は完了済み**。人間レビュー（4-8/4-9）が未実施のためループ範囲は`[]`のまま | エージェント |
| [] | 4-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う。**push実施済み**（同上の理由で記号は`[]`） | エージェント |
| [] | 4-8 | MRでレビュー・コメントする。**非対話的実行環境のため未実施** | 人間 |
| [] | 4-9 | レビュー内容を取得し、設計・AIアセットの内容を修正する（4-6〜4-9の反映ループを合意まで繰り返す）。**同上** | `comments` / `reply` |
| [] | 4-10 | 反映内容をもとにMR descriptionを更新する（PR未作成のため未実施） | `describe` |
| [] | 5-1 | 次タスクのために、`plans/` `worklog/` `reports/` を削除し、`HANDOFF.md` をリセットする。**あわせて `plans/index.jsonl` も削除し、`bash .claude/scripts/src/extract-frontmatter.sh .` で `index.jsonl` 群を再生成する** | エージェント |
| [] | 5-2 | `commit`スキル経由でcommitし、push して Draftを解除する | エージェント |
| [] | 5-3 | マージする（squash merge。ブランチは削除してよい） | 人間 |

詳細についてはworklogを確認してください。

## やったこと

- issue #34の内容取得（`gh` CLIが実行環境に無いため `mcp__github__issue_read` で代替）
- 全体作業計画`plans/steady-bridging-gateway.md`を作成。受け入れ条件で対象と方針が確定しているため
  フェーズ2（調査）は省略と判断
- 個別作業計画`plans/【設計】【実装】gh-glab不在時のMCPフォールバック経路.md`とworklogを作成
- 実装（flow-id 3-6相当）:
  - `Provider.sh`: `get_vcs_access_mode` / `parse_repo_slug` / `get_repo_slug` / `mcp_tool_hint` /
    `require_vcs_cli` を追加。プロバイダ依存の8関数へガードを挿入。`get_repo_url` はMCP経路で
    `git remote` からのローカル組み立てにフォールバック
  - `session-start.sh`: CLI不在時に「経路はMCP」「issue番号」「owner/repo」「手順の参照先」を注入
    （従来は`gh`の失敗を握りつぶし、PRがあっても「PR: なし」と誤表示していた）
  - `post-push-usage-report.sh` / `post-push-compact-prompt.sh`: CLI不在時の縮退を明示化
  - `.claude/skills/issue-mr-flow/SKILL.md`: 「`gh`/`glab` CLI不在時のMCPフォールバック」節を新設
    （経路判定・Provider関数対応表・サブコマンド読み替え・hook挙動・GitLab対象外）
  - `.claude/skills/issue-create/SKILL.md` / `create-issue.sh` / `AGENTS.md`: MCP経路への参照を追加
  - `tests/test_vcs_provider.sh`: `parse_repo_slug`（6件）・`mcp_tool_hint`（4件）のテストを追加。
    全テストスクリプト4本を実行し `failures=0` を確認
- 設計反映（flow-id 4-1/4-6相当）: 個別反映計画を作成し、
  `.claude/docs/spec/issue-mr-workflow.md`（提供関数表・SessionStart節・新節・影響範囲）と
  `.claude/docs/ddr/0025-...md`（新規）へ反映

## 次にやること

- 人間によるレビュー（flow-id 3-3/3-8, 4-3/4-8）。必要ならDraft PRの作成をユーザーが指示する
- レビュー合意後、flow-id 5-1（`plans/` `worklog/` の削除・HANDOFF.mdリセット・`index.jsonl`再生成）

## 判断を迷った内容

- **Draft PRを作成しなかった**: このリモート実行環境のハーネスは「ユーザーが明示的に依頼しない限り
  PRを作成しない」ことを求めるため、flow-id 1-3のDraft MR作成は行わず、ブランチへのpushまでに
  留めた（issue #22対応セッションでは作成していたため、運用差分として記録する）。PRが必要であれば
  ユーザーの指示を受けてから `mcp__github__create_pull_request` で作成する
- **人間レビューのループ範囲の進捗記号**: 非対話的実行環境のため3-3/3-4・3-8/3-9・4-3/4-4・4-8/4-9を
  実施できない。`.claude/rules/docs-workflow.md`の規定に従い、ループ範囲の記号は`[]`のまま残し、
  実施済みの内容（3-6/3-7・4-6/4-7相当）は本セクションの文章で補足している
- **`main`に残っているissue #22の`plans/`・`worklog/`**: flow-id 5-1実施前にPR #30がマージされた
  ためと思われる取り残しがある（`plans/iterative-dreaming-yao.md`等）。
  `.claude/skills/issue-mr-flow/SKILL.md`「PRがflow-id 5-1実施前にマージされてしまった場合の対処」は
  **別のクリーンアップ用ブランチ**での対応を求めているため、本ブランチでは触っていない

## 未解決の内容

- GitLab MCPサーバー経由のフォールバック（`glab`不在時）は対象外とした。実機検証できる環境が
  得られた時点で、SKILL.mdの対応表へGitLab行を追加する（DDR 0025）

## 守るべき条件・触ってはいけない範囲

- `main`に残っているissue #22由来の`plans/`・`worklog/`ファイルは本ブランチでは削除しない（上記）
