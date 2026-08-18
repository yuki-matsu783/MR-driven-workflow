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

- issue: [#9 最初に全体作業計画を立て、その後、個別作業計画を立て、合意を得ながら進める](https://github.com/yuki-matsu783/MR-driven-workflow/issues/9)
- ブランチ: `feature-9-stabilize-plan-tool-usage-flow`
- Draft PR: [#10](https://github.com/yuki-matsu783/MR-driven-workflow/pull/10)
- push回数: 1

| 進捗 | flow-id | ステップ | 担当 |
|----|---|---|---|
| [x] | 1 | issueを起票する（`.github/ISSUE_TEMPLATE/task.md` / `.gitlab/issue_templates/task.md` で目的・現状・期待する動作・受け入れ条件を記載） | 人間（AIが代行する場合は `issue-create` スキル） |
| [x] | 2 | issueの内容を取得する | `start <issue番号>` |
| [x] | 3 | featureブランチ（`feature-<issue番号>-<slug>`）とDraft MRを作成する（既にあれば `sync` のみ） | `start` |
| [x] | 4 | Planモードで**調査計画**を作成する（`plans/<plan名>.md`の「調査」章へ出力・コミット。このタイミングで `worklog/日付_<plan名>.md` を作成） | エージェント |
| [x] | 5 | 調査計画に合意する | 人間 |
| [x] | 6 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 7 | MRで調査計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| [] | 8 | レビュー内容を取得し、調査計画を修正する。対応が完了したコメントには対応内容を返信する（7〜8を合意まで繰り返す） | `comments` / `reply` |
| [] | 9 | 調査計画をもとにMR descriptionを更新する | `describe` |
| [] | 10 | **調査を実施**し、結果を`plans/<plan名>.md`の「調査」章・worklogに記録する。あわせて調査結果を視覚的に分かりやすくまとめた自己完結HTML（TailwindCSS CDN方式）を`reports/<plan名>.html`として作成する（調査結果が複数要素間の関連・依存関係を主題とする場合は、`.claude/skills/canvas-report/SKILL.md`のcanvas形式テンプレートの利用を検討する） | エージェント |
| [] | 11 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 12 | 調査結果をもとにMR descriptionを更新する | `describe` |
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

- flow-id 1〜3: issue #9 を起点にブランチ `feature-9-stabilize-plan-tool-usage-flow` と Draft PR #10 を作成。
- flow-id 4〜5: 調査計画 `plans/crispy-conjuring-canyon.md` を作成し、ユーザー承認を得た。
- flow-id 6: worklog `worklog/20260818_crispy-conjuring-canyon_push1.md` を作成し、commit・push（本push）。

## 次にやること

- flow-id 7: 人間によるMRレビュー待ち（調査計画について）。
- flow-id 9: レビュー合意後 `describe` でMR descriptionを更新。
- flow-id 10: 調査1〜7を実施（`plans/crispy-conjuring-canyon.md` の「調査」章参照）。

## 判断を迷った内容

- issue #9 の「全体作業計画／個別作業計画」が現行33ステップのどこに対応するかが本文から一意に
  読めなかったため、AskUserQuestionで確認した。結果:
  - **全体作業計画** = issue全体の進め方（planツール、セッション冒頭1回のみ）
  - **個別作業計画** = 各フェーズ（`plans/[タスク種別]xxx.md`、planツール不使用）
  - 既存のre-entry対策（`plan-mode-safety.md`規則6・`archive-reentrant-plan.sh`・DDR 0009）は
    **不要になれば廃止してよい**

## 未解決の内容

- `[タスク種別]` の値の集合が未定（調査3）。ファイル名の角括弧 `[]` はbashのglob特殊文字であり、
  `archive-reentrant-plan.sh` の worklog探索globなどに影響しうるため実機確認が必要。
- 個別計画が複数になった場合、worklog（`日付_<plan名>_push<N>.md`）・reports（`<plan名>.html`）を
  何に紐づけるかが未定（調査2）。
- 複数セッションにまたがる作業で、新セッションではハーネスが新しいplanファイルパスを提示する点を
  どう扱うか（調査5の最大の論点）。

## 守るべき条件・触ってはいけない範囲

- **本タスク自体の進行は現行の33ステップフローに従う**（新フローの適用は、変更がマージされた
  次のタスクから）。
- `.claude/docs/ddr/0009` の本文は変更しない（DDRは一度マージしたら追記のみ）。
- 実装（ルール・SKILL.md・スクリプトの実変更）は flow-id 15 の作業計画で扱う。調査フェーズ
  （flow-id 10）では実変更を行わない。
