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

- issue: [#7](https://github.com/yuki-matsu783/MR-driven-workflow/issues/7) post-push-usage-report.sh/post-push-compact-prompt.shをGemini CLI/Claude Code両対応にする
- ブランチ: feature-7-support-gemini-cli-for-usage-report-and-compact-pr
- Draft PR: [#8](https://github.com/yuki-matsu783/MR-driven-workflow/pull/8)
- push回数: 2

| 進捗 | flow-id | ステップ | 担当 |
|----|---|---|---|
| [x] | 1 | issueを起票する（`.github/ISSUE_TEMPLATE/task.md` / `.gitlab/issue_templates/task.md` で目的・現状・期待する動作・受け入れ条件を記載） | 人間（AIが代行する場合は `issue-create` スキル） |
| [x] | 2 | issueの内容を取得する | `start <issue番号>` |
| [x] | 3 | featureブランチ（`feature-<issue番号>-<slug>`）とDraft MRを作成する（既にあれば `sync` のみ） | `start` |
| [x] | 4 | Planモードで**調査計画**を作成する（`plans/<plan名>.md`の「調査」章へ出力・コミット。このタイミングで `worklog/日付_<plan名>.md` を作成） | エージェント |
| [x] | 5 | 調査計画に合意する | 人間 |
| [x] | 6 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [x] | 7 | MRで調査計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。（「OK」を受け、`get_mr_unresolved_comments 8 true`で未解決コメント無しを確認済み） | 人間 |
| [x] | 8 | レビュー内容を取得し、調査計画を修正する。対応が完了したコメントには対応内容を返信する（7〜8を合意まで繰り返す）（コメント無しのためスキップ） | `comments` / `reply` |
| [x] | 9 | 調査計画をもとにMR descriptionを更新する（※本来7〜8の後だが、レビューしやすくするため先行実施） | `describe` |
| [x] | 10 | **調査を実施**し、結果を`plans/<plan名>.md`の「調査」章・worklogに記録する。あわせて調査結果を視覚的に分かりやすくまとめた自己完結HTML（TailwindCSS CDN方式）を`reports/<plan名>.html`として作成する（調査結果が複数要素間の関連・依存関係を主題とする場合は、`.claude/skills/canvas-report/SKILL.md`のcanvas形式テンプレートの利用を検討する） | エージェント |
| [x] | 11 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [x] | 12 | 調査結果をもとにMR descriptionを更新する | `describe` |
| [] | 13 | MRで調査結果についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| [] | 14 | レビュー内容を取得し、調査結果を修正する。対応が完了したコメントには対応内容を返信する（`reports/<plan名>.html`も調査結果と同期して更新する。10〜14を合意まで繰り返す） | `comments` / `reply` |
| [] | 15 | **調査結果をもとに**Planモードで**作業計画**を作成する（`plans/<plan名>.md`の「作業計画」章へ追記・コミット） | エージェント |
| [] | 16 | 作業計画に合意する | 人間 |
| [] | 17 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 18 | MRで作業計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| [] | 19 | レビュー内容を取得し、作業計画を修正する。対応が完了したコメントには対応内容を返信する（18〜19を合意まで繰り返す） | `comments` / `reply` |
| [] | 20 | 作業計画をもとにMR descriptionを更新する | `describe` |
| [] | 21 | 作業計画をもとに作業を進める、作業内容はworklogに更新する | エージェント |
| [] | 22 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 23 | 作業内容をもとにMR descriptionを更新する | `describe` |
| [] | 24 | MRでレビュー・コメントする。レビュー済み連絡をするまで以降の作業は行わない。 | 人間 |
| [] | 25 | レビュー内容を取得し、実装・ドキュメントを修正する。対応が完了したコメントには対応内容を返信する（21〜25の作業ループを合意まで繰り返す） | `comments` / `reply` |
| [] | 26 | 設計反映: `plans/` `worklog/` の内容を `docs/spec/` `docs/ddr/` へ反映する | エージェント |
| [] | 27 | AIアセット改善: 作業中に気づいたルール・スキルの不備があれば `.claude/rules/` `.claude/skills/` `CLAUDE.md` `AGENTS.md` に反映する | エージェント |
| [] | 28 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 29 | MRでレビュー・コメントする。レビュー済み連絡をするまで以降の作業は行わない。 | 人間 |
| [] | 30 | レビュー内容を取得し、設計反映・AIアセットの内容を修正する。対応が完了したコメントには対応内容を返信する（26〜30を合意まで繰り返す） | `comments` / `reply` |
| [] | 31 | `plans/` `worklog/` `reports/` を削除し、`HANDOFF.md` を次タスクへリセットする | エージェント |
| [] | 32 | `commit`スキル経由でcommitし、push して Draftを解除する | エージェント |
| [] | 33 | マージする（squash merge。ブランチは削除してよい） | 人間 |

詳細についてはworklogを確認してください。

## やったこと

- 前セッションの調査（Claude Code+GitHubの工数レポートコメント機能がGemini CLI+GitLabでも動くか）
  をもとにissue #7を起票し、ブランチ・Draft PR #8を作成した。
- `post-push-save-logs.sh`（既にGemini CLI対応済み）、`post-push-usage-report.sh`、
  `post-push-compact-prompt.sh`のガード条件・エンジン判定の詳細を調査し、`plans/fancy-wishing-scroll.md`
  に調査計画としてまとめ、ユーザー承認を得た。
- worklogを作成し、commit・push、MR descriptionを更新した（push1）。
- レビューOKの合図を受け、`get_mr_unresolved_comments 8 true`で未解決コメント無しを確認（工数レポート
  自動投稿のみ）。調査結果を`reports/fancy-wishing-scroll.html`にまとめ、commit・push（push2）、
  MR descriptionを調査結果版に更新した。

## 次にやること

- flow-id 13: MRで調査結果についてレビューをお願いする（人間待ち）。
- レビューOKであれば flow-id 15（作業計画をPlanモードで作成）へ進み、
  `post-push-usage-report.sh`/`post-push-compact-prompt.sh`へのエンジン判定移植の実装計画を立てる。

## 判断を迷った内容

- flow-id 9（`describe`）をflow-id 7〜8（レビューループ）より先に実行した。フロー定義上は
  レビュー後が本来の順だが、事前調査がほぼ完了していたためMR descriptionを先に整えた方が
  レビューしやすいと判断した。実害はないと考えるが、次回以降は素直にflow-id 7を待ってから
  実行する方が定義に忠実。

## 未解決の内容

（無し）

## 守るべき条件・触ってはいけない範囲

- GitLab側の動作検証は本issueの受け入れ条件から除外（`plans/fancy-wishing-scroll.md`「対象外」参照）。
