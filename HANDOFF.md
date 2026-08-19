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

- issue: #58 HANDOFF.mdの進捗表でループの周回数をヘッダ行に数字で明示する
- ブランチ: claude/handoff-loop-count-header-mwxais
- PR: 未作成（ハーネスがPR作成を制限する非対話的セッションのため。詳細は「未解決の内容」）
- push回数: 1
- 現在のループ: 3-6〜3-9 の1周目（進行中）
- 追従監視: なし（PR未作成のため対象外）

## フロー進捗状況

進捗記号: `[x]` 完了 / `[]` 未着手・進行中 / `[-]` 今回は実施しない（スキップ）

| 進捗 | flow-id | ステップ | 担当 |
|----|---|---|---|
| [x] | 1-1 | issueを起票する。issue #58 として起票済み | 人間（AIが代行する場合は `issue-create` スキル） |
| [x] | 1-2 | issueの内容を取得する。`gh` CLI不在のため `mcp__github__issue_read` で取得（4見出しすべて揃っている） | `start <issue番号>` |
| [x] | 1-3 | featureブランチを作成する。ブランチはハーネス指定の `claude/handoff-loop-count-header-mwxais`（`feature-<issue番号>-<slug>` 命名規則の対象外）。PRは未作成 | `start` |
| [-] | 1-4 | **Planモードで「全体作業計画」を作成する**（非対話的セッションでPlanモードの承認往復が取れないため省略し、issue #58の「期待する動作」「受け入れ条件」を全体計画として扱った） | エージェント |
| [-] | 1-5 | 全体作業計画に合意する（1-4を省略のため対象外） | 人間 |
| [x] | 1-6 | HANDOFF.mdを更新する | エージェント |
| [-] | 2-1 | **個別調査計画**（対象が既存スクリプト1本とその仕様書に限られ、実装前に読み切れたためフェーズ2を丸ごと省略） | エージェント |
| [-] | 2-2 | （2-1を省略のため対象外） | エージェント |
| [-] | 2-3 | （同上） | 人間 |
| [-] | 2-4 | （同上） | `comments` / `reply` |
| [-] | 2-5 | （同上） | `describe` |
| [-] | 2-6 | （同上） | エージェント |
| [-] | 2-7 | （同上） | エージェント |
| [-] | 2-8 | （同上） | 人間 |
| [-] | 2-9 | （同上） | `comments` / `reply` |
| [-] | 2-10 | （同上） | `describe` |
| [x] | 3-1 | 個別作業計画 `plans/【設計】【実装】HANDOFF進捗表のループ周回数をヘッダ行へ明示する.md` を**planツールを使わず**Write/Editで作成する | エージェント |
| [x] | 3-2 | `commit`スキル経由でcommitし、リモートへ反映してレビュー依頼を行う | エージェント |
| [] | 3-3 | MRで作業計画についてレビュー・コメントする（非対話セッションのため未実施） | 人間 |
| [] | 3-4 | レビュー内容を取得し、作業計画を修正する（3-3〜3-4を合意まで繰り返す） | `comments` / `reply` |
| [-] | 3-5 | 作業計画をもとにMR descriptionを更新する（PR未作成のため対象外） | `describe` |
| [] | 3-6 | 作業計画をもとに作業を進める、作業内容はworklogに更新する（**実作業は完了済み**。人間レビューを挟めずループが1周していないため記号は`[]`のまま。下記「やったこと」参照） | エージェント |
| [] | 3-7 | `commit`スキル経由でcommitし、リモートへ反映してレビュー依頼を行う（commit・反映は実施済み） | エージェント |
| [] | 3-8 | MRでレビュー・コメントする（非対話セッションのため未実施） | 人間 |
| [] | 3-9 | レビュー内容を取得し、実装・ドキュメントを修正する（3-6〜3-9の作業ループを合意まで繰り返す） | `comments` / `reply` |
| [-] | 3-10 | 作業内容をもとにMR descriptionを更新する（PR未作成のため対象外） | `describe` |
| [-] | 4-1 | **個別反映計画**（今回は反映先が`.claude/docs/spec/update-handoff-progress.md`・`.claude/rules/docs-workflow.md`・`.claude/skills/issue-mr-flow/SKILL.md`・`.claude/agents/issue-mr-resume.md`に限られ、個別作業計画の「実装内容3. ドキュメント」に含めて合意できる粒度のため、独立ファイルにはしなかった） | エージェント |
| [-] | 4-2 | （4-1を省略のため対象外） | エージェント |
| [-] | 4-3 | （同上） | 人間 |
| [-] | 4-4 | （同上） | `comments` / `reply` |
| [-] | 4-5 | （同上） | `describe` |
| [] | 4-6 | 設計反映・AIアセット反映を行う（**実作業は完了済み**。spec・rules・SKILL・agentへ反映した。人間レビューを挟めずループが1周していないため記号は`[]`のまま） | エージェント |
| [] | 4-7 | `commit`スキル経由でcommitし、リモートへ反映してレビュー依頼を行う（commit・反映は実施済み） | エージェント |
| [] | 4-8 | MRでレビュー・コメントする（非対話セッションのため未実施） | 人間 |
| [] | 4-9 | レビュー内容を取得し、設計・AIアセットの内容を修正する（4-6〜4-9の反映ループを合意まで繰り返す） | `comments` / `reply` |
| [-] | 4-10 | 反映内容をもとにMR descriptionを更新する（PR未作成のため対象外） | `describe` |
| [] | 5-1 | 次タスクのために、`plans/` `worklog/` `reports/` を削除し、`HANDOFF.md` をリセットする | エージェント |
| [] | 5-2 | defaultブランチとのコンフリクトを検知し、あれば解消する | エージェント（`resolve-conflict` スキル） |
| [] | 5-3 | `commit`スキル経由でcommitし、リモートへ反映してDraftを解除する | エージェント |
| [] | 5-4 | マージする（squash merge） | 人間 |

## やったこと

- issue #58 の内容を取得し、既存の `.claude/scripts/src/update-handoff-progress.sh`・
  `.claude/docs/spec/update-handoff-progress.md`・`.claude/scripts/test/test_update_handoff_progress.sh` を読んだ。
  issue本文が挙げている `tests/test_update_handoff_progress.sh` はissue #63で
  `.claude/scripts/test/` へ移動済みだったため、実在するパスの側を更新した。
- 個別作業計画 `plans/【設計】【実装】HANDOFF進捗表のループ周回数をヘッダ行へ明示する.md` を作成した。
- `update-handoff-progress.sh` へ以下を追加した（進捗表側のロジックは変更していない）。
  - `count_rounds_to_reply` / `format_loop_status_to_reply` / `set_loop_header_in_lines` /
    `follow_loop_header_in_lines`
  - `add-round` とループ範囲への `mark-done` から、ヘッダ `- 現在のループ:` 行を自動追従させる処理
  - `set-header --loop <text>`
- `.claude/scripts/test/test_update_handoff_progress.sh` へヘッダ追従のテストを18件追加し、
  `passed=35 failures=0` を確認した。リポジトリ内の他の単体テスト6本も併せて実行し、いずれも
  `failures=0` であることを確認した。
- 設計反映・AIアセット反映として、`.claude/docs/spec/update-handoff-progress.md`（仕様・制約・影響範囲）・
  `.claude/rules/docs-workflow.md`（ヘッダ行の運用）・`.claude/skills/issue-mr-flow/SKILL.md`
  （周回数はヘッダ行を読む）・`.claude/agents/issue-mr-resume.md`（現在地サマリへ追加）を更新した。
- 詳細な試行錯誤は
  `worklog/20260819_issue58_【設計】【実装】HANDOFF進捗表のループ周回数をヘッダ行へ明示する_push1.md` に記録した。

## 次にやること

- （人間）実装・ドキュメントのレビュー（flow-id 3-8 / 4-8 相当）。
- PRが必要であれば、その旨を指示する（このセッションではPRを作成していない。下記「未解決の内容」）。
- レビュー合意後、flow-id 5-1（`plans/` `worklog/` の削除とHANDOFF.mdのリセット）へ進む。

## 判断を迷った内容

- ヘッダ行の追従に失敗したとき（挿入位置の基準となるヘッダ項目も `## フロー進捗状況` 見出しも
  持たない変則的なHANDOFF.md）に、`mark-done`/`add-round` 自体をエラーにするか、警告に留めて
  進捗表の更新だけ書き戻すかで迷った。**警告に留める**方を採用した。issue #58の受け入れ条件
  「既存の `mark-done`/`mark-skip`/`add-round` の挙動は不変」を満たすため。
  `set-header --loop` はユーザーが明示的にその行を求めているので、こちらはエラーのままにしている。
- 周回数をヘッダと進捗表の二重管理にすること自体の是非。**表を正とし、ヘッダは毎回表から導出する**
  ことで、人手の更新漏れで食い違う経路を無くした（詳細は
  `.claude/docs/spec/update-handoff-progress.md`「制約・設計判断」）。

## 未解決の内容

- **PRを作成していない。** このセッションはClaude Code on the webの非対話的なリモート実行環境で、
  ハーネスのシステムプロンプトが「ユーザーが明示的に依頼しない限りPRを作成しない」ことを求めており、
  かつ `AskUserQuestion` の応答を待てないため、`.claude/rules/git-workflow.md`
  「ハーネスがPR作成を制限する環境での扱い」の3番目（PRを作成せずに止め、その旨を明示する）に従った。
  PRが必要な場合は明示的に指示すること。
- 人間担当のレビュー往復（flow-id 3-3/3-4, 3-8/3-9, 4-8/4-9）は未実施のまま。

## 守るべき条件・触ってはいけない範囲

- 進捗表の行構成・進捗記号（`[x]`/`[]`/`[-]`）・`LOOP_RANGES` の定義は変更しない（issue #58の
  受け入れ条件「進捗表の記号・行構成に差分が出ない」）。
- `- 追従監視:` 行（issue #88）は `set-header` の対象外という扱いを維持する。
- `- 現在のループ:` 行は手で書き換えず、`add-round`／ループ範囲への `mark-done` の自動追従に任せる
  （ループ範囲の外にいることを示す場合だけ `set-header --loop 'なし'`）。
