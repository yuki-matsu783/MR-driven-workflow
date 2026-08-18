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

- issue: #21（.mrworkflow.jsonの各キーの説明をREADME等に追記する）
- ブランチ: claude/issue-21-bf7mnd（注: `.mrworkflow.json`の`branchPrefixTemplate`規則`feature-<issue番号>-<slug>`とは異なるが、
  Claude Code on the web環境が指定したブランチ名のためこのまま使用する）
- Draft PR: #25 https://github.com/yuki-matsu783/MR-driven-workflow/pull/25
- push回数: 1

| 進捗 | flow-id | ステップ | 担当 |
|----|---|---|---|
| [x] | 1-1 | issueを起票する（`.github/ISSUE_TEMPLATE/task.md` / `.gitlab/issue_templates/task.md` で目的・現状・期待する動作・受け入れ条件を記載） | 人間（AIが代行する場合は `issue-create` スキル） |
| [x] | 1-2 | issueの内容を取得する | `start <issue番号>` |
| [x] | 1-3 | featureブランチ（`feature-<issue番号>-<slug>`）とDraft MRを作成する（既にあれば `sync` のみ） | `start` |
| [x] | 1-4 | **Planモードで「全体作業計画」を作成する**（このissueをどう進めるか＝何を調査し何を実装するかの全体像。ハーネスが提示するパス `plans/<自動命名>.md` へ出力）。**現在のブランチに既に全体作業計画があれば新規作成せず、既存を読むだけにとどめる**（詳細は下記「計画の2階層構造」） | エージェント |
| [x] | 1-5 | 全体作業計画に合意する | 人間 |
| [x] | 1-6 | 全体作業計画をもとにHANDOFF.mdを更新する | エージェント |
| skip | 2-1 | **個別調査計画**`plans/【調査】〜.md`を**planツールを使わず**Write/Editで作成する。このタイミングで `worklog/日付_<全体計画名>_<個別計画名>_push<N>.md` を作成 | エージェント |
| skip | 2-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| skip | 2-3 | MRで調査計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| skip | 2-4 | レビュー内容を取得し、調査計画を修正する。対応が完了したコメントには対応内容を返信する（2-3〜2-4を合意まで繰り返す） | `comments` / `reply` |
| skip | 2-5 | 調査計画をもとにMR descriptionを更新する | `describe` |
| skip | 2-6 | **調査を実施**し、結果を個別調査計画・worklogに記録する。あわせて結果を視覚的に分かりやすくまとめた自己完結HTML（TailwindCSS CDN方式）を`reports/日付_<全体計画名>_<内容を簡潔に>.html`として作成する（複数要素間の関連・依存関係が主題の場合は、`.claude/skills/canvas-report/SKILL.md`のcanvas形式テンプレートの利用を検討する） | エージェント |
| skip | 2-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| skip | 2-8 | MRで調査結果についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| skip | 2-9 | レビュー内容を取得し、調査結果を修正する。対応が完了したコメントには対応内容を返信する（`reports/`のHTMLも調査結果と同期して更新する。2-6〜2-9を合意まで繰り返す） | `comments` / `reply` |
| skip | 2-10 | 調査結果をもとにMR descriptionを更新する | `describe` |
| [x] | 3-1 | **調査結果をもとに**、個別作業計画`plans/【設計】【実装】〜.md`等を**planツールを使わず**Write/Editで作成する | エージェント |
| [x] | 3-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| skip | 3-3 | MRで作業計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| skip | 3-4 | レビュー内容を取得し、作業計画を修正する。対応が完了したコメントには対応内容を返信する（3-3〜3-4を合意まで繰り返す） | `comments` / `reply` |
| [x] | 3-5 | 作業計画をもとにMR descriptionを更新する | `describe` |
| [x] | 3-6 | 作業計画をもとに作業を進める、作業内容はworklogに更新する | エージェント |
| [x] | 3-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 3-8 | MRでレビュー・コメントする。レビュー済み連絡をするまで以降の作業は行わない。 | 人間 |
| [] | 3-9 | レビュー内容を取得し、実装・ドキュメントを修正する。対応が完了したコメントには対応内容を返信する（3-6〜3-9の作業ループを合意まで繰り返す） | `comments` / `reply` |
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
| [] | 5-1 | 次タスクのために、`plans/` `worklog/` `reports/` を削除し、`HANDOFF.md` をリセットする | エージェント |
| [] | 5-2 | `commit`スキル経由でcommitし、push して Draftを解除する | エージェント |
| [] | 5-3 | マージする（squash merge。ブランチは削除してよい） | 人間 |

詳細についてはworklogを確認してください。

## やったこと

- issue #21の内容を取得（GitHub MCPツール `mcp__github__issue_read` 経由。この環境には`gh`/`glab`
  CLIが存在しないため、`Provider.sh`が前提とするCLI経由の取得は行えず、GitHub MCPツールで代替した）。
- ブランチ`claude/issue-21-bf7mnd`（outer harnessが用意済み。`.mrworkflow.json`の命名規則とは
  異なるがそのまま使用）で作業。Draft PRは未作成（次のステップでMCPツール経由で作成予定）。
- Planモードで全体作業計画を作成し承認を得た（`plans/playful-napping-finch.md`）。
  フェーズ2（個別調査計画）は別立てせず、全体作業計画内に調査結果を集約しフェーズ3から直接進める
  方針で合意済み。

## 次にやること

1. Draft PR/MRを作成する（`gh`/`glab` CLI不在のためGitHub MCPツール
   `mcp__github__create_pull_request`で代替）。
2. `plans/【実装】.mrworkflow.jsonキー説明をREADMEに追記.md`（個別作業計画）を作成する（flow-id 3-1）。
3. `commit`スキル経由でcommit・pushしレビュー依頼（flow-id 3-2）。
4. README.mdへの実際の追記作業（flow-id 3-6）。

## 判断を迷った内容

- **この環境に`gh`/`glab` CLIが存在しない**（`.claude/rules/`群は`Provider.sh`経由でのCLI利用を
  前提としているが、Claude Code on the webのリモート実行環境では代わりにGitHub MCPサーバーツール
  （`mcp__github__*`）の使用が指示されている）。issue/PR取得・Draft PR作成・コメント取得・返信・
  MR description更新など、本来`Provider.sh`のサブコマンド（`start`/`comments`/`reply`/`describe`）
  が担う処理は、このセッションではGitHub MCPツールで代替する。将来的にAIアセット反映（フェーズ4）で、
  この環境差異について`.claude/skills/issue-mr-flow/SKILL.md`等へ注記を追加するか検討する。
- **フェーズ2（個別調査計画）を作成せず全体作業計画に調査結果を集約した**判断は、issue #21が
  ドキュメント追記のみで完結する小規模タスクであり、Planモードの探索で必要な調査が完了した
  ことを根拠にしている（詳細は`plans/playful-napping-finch.md`の「方針」節）。
- **flow-id 3-3/3-4（作業計画レビュー）をskipし、計画から実装まで一気に進めた**判断について:
  本セッションはissueをトリガーに起動した非対話的なリモートセッションで、実装内容が
  README.mdの1テーブル追記のみと小さく・可逆であり、内容も全体作業計画（人間承認済み）の
  「方針」節に既に具体的に記載済みだったため、計画単体でのMR往復レビューを待たず実装まで進めた。
  実装後の差分自体は通常どおりDraft PR #25でレビュー可能な状態にしてあり、flow-id 3-8以降の
  レビューループはスキップしていない。

## 未解決の内容

（無し）

## 守るべき条件・触ってはいけない範囲

（無し）
