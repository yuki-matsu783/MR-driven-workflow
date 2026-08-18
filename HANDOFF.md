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

- issue: [#15](https://github.com/yuki-matsu783/MR-driven-workflow/issues/15) issueからMRを作成するときにどれをベースにするかユーザに聞く
- ブランチ: `feature-15-ask-user-for-mr-base-branch`
- Draft PR: [#18](https://github.com/yuki-matsu783/MR-driven-workflow/pull/18)
- push回数: 4
- レビュー依頼中: []

全体作業計画（`plans/woolly-tickling-thimble.md`）の方針により、**フェーズ2（調査）は実施せず、
フェーズ3（設計・実装）から着手する**。

| 進捗 | flow-id | ステップ | 担当 |
|----|---|---|---|
| [x] | 1-1 | issueを起票する（`.github/ISSUE_TEMPLATE/task.md` / `.gitlab/issue_templates/task.md` で目的・現状・期待する動作・受け入れ条件を記載） | 人間（AIが代行する場合は `issue-create` スキル） |
| [x] | 1-2 | issueの内容を取得する | `start <issue番号>` |
| [x] | 1-3 | featureブランチ（`feature-<issue番号>-<slug>`）とDraft MRを作成する（既にあれば `sync` のみ） | `start` |
| [x] | 1-4 | **Planモードで「全体作業計画」を作成する**（このissueをどう進めるか＝何を調査し何を実装するかの全体像。ハーネスが提示するパス `plans/<自動命名>.md` へ出力）。**現在のブランチに既に全体作業計画があれば新規作成せず、既存を読むだけにとどめる**（詳細は下記「計画の2階層構造」） | エージェント |
| [x] | 1-5 | 全体作業計画に合意する | 人間 |
| [x] | 1-6 | 全体作業計画をもとにHANDOFF.mdを更新する。 | エージェント |
| （フェーズ2はスキップ） | 2-1〜2-10 | 個別調査計画〜調査結果反映（全体作業計画の方針によりスキップ） | — |
| [x] | 3-1 | **調査結果をもとに**、個別作業計画`plans/【設計】【実装】〜.md`等を**planツールを使わず**Write/Editで作成する | エージェント |
| [x] | 3-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [x] | 3-3 | MRで作業計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| [x] | 3-4 | レビュー内容を取得し、作業計画を修正する。対応が完了したコメントには対応内容を返信する（3-3〜3-4を合意まで繰り返す） | `comments` / `reply` |
| [x] | 3-5 | 作業計画をもとにMR descriptionを更新する | `describe` |
| [x] | 3-6 | 作業計画をもとに作業を進める、作業内容はworklogに更新する | エージェント |
| [x] | 3-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [x] | 3-8 | MRでレビュー・コメントする。レビュー済み連絡をするまで以降の作業は行わない。 | 人間 |
| [x] | 3-9 | レビュー内容を取得し、実装・ドキュメントを修正する。対応が完了したコメントには対応内容を返信する（3-6〜3-9の作業ループを合意まで繰り返す） | `comments` / `reply` |
| [x] | 3-10 | 作業内容をもとにMR descriptionを更新する | `describe` |
| [x] | 4-1 | **作業結果と`plans/` `worklog/` の内容をもとに**、個別反映計画`plans/【設計反映】【AIアセット反映】〜.md`等を**planツールを使わず**Write/Editで作成する | エージェント |
| [x] | 4-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [x] | 4-3 | MRで反映計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| [x] | 4-4 | レビュー内容を取得し、反映計画を修正する。対応が完了したコメントには対応内容を返信する（4-3〜4-4を合意まで繰り返す） | `comments` / `reply` |
| [x] | 4-5 | 反映計画をもとにMR descriptionを更新する | `describe` |
| [x] | 4-6 | 反映計画をもとに作業を進める、反映内容はworklogに更新する（**設計反映**: `plans/` `worklog/` の内容を `.claude/docs/spec/` `.claude/docs/ddr/`（アプリ本体があれば`docs/spec/` `docs/ddr/`）へ反映する／**AIアセット反映**: 作業中に気づいたルール・スキルの不備を `.claude/rules/` `.claude/skills/` `CLAUDE.md` `AGENTS.md` に反映する） | エージェント |
| [] | 4-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 4-8 | MRでレビュー・コメントする。レビュー済み連絡をするまで以降の作業は行わない。 | 人間 |
| [] | 4-9 | レビュー内容を取得し、設計・AIアセットの内容を修正する。対応が完了したコメントには対応内容を返信する（4-6〜4-9の反映ループを合意まで繰り返す） | `comments` / `reply` |
| [] | 4-10 | 反映内容をもとにMR descriptionを更新する | `describe` |
| [] | 5-1 | 次タスクのために、`plans/` `worklog/` `reports/` を削除し、`HANDOFF.md` をリセットする | エージェント |
| [] | 5-2 | `commit`スキル経由でcommitし、push して Draftを解除する | エージェント |
| [] | 5-3 | マージする（squash merge。ブランチは削除してよい） | 人間 |

詳細についてはworklogを確認してください。

## やったこと

- issue #15を取得し、標準4見出しのうち「現状」「期待する動作」「受け入れ条件」が欠落していることを確認（処理は継続）
- `feature-15-ask-user-for-mr-base-branch` ブランチとDraft MR #18を作成（1回目は既知の制約で失敗、空コミットによる自動リトライで成功）
- Planモードで全体作業計画（`plans/woolly-tickling-thimble.md`）を作成し合意を得た。フェーズ2（調査）はスキップし、フェーズ3（設計・実装）から着手する方針
- 個別作業計画 `plans/【設計】【実装】ベースブランチ確認のAskUserQuestion化.md` を作成し、worklog（push1）を作成した
- commit・pushしてレビュー依頼（push回数1）。人間から「レビューOK」を受け、`comments all`で未解決スレッドが無いことを確認済み（自動投稿の対応工数レポートのみ）
- `describe`でMR descriptionを個別作業計画の内容に更新した
- 実装完了: `Provider.sh`の`new_issue_branch`に第3引数（ベースブランチ上書き、省略可）を追加。
  `SKILL.md`の`start`サブコマンドに、新規ブランチ作成前の`AskUserQuestion`ステップを追加。worklog（push2）に記録
- commit・push（push回数2）。作業中、`.claude/skills/issue-mr-flow/SKILL.md`と`.claude/skills/commit/SKILL.md`に
  ユーザーの並行編集（未コミット）が存在することに気づき、ユーザーに確認のうえ「一緒にコミットする」で合意し反映済み
  （詳細はworklog push2参照）

- push回数2でcommit・pushしレビュー依頼。人間から「レビュー済み」を受け、`comments all`で未解決スレッドが無いことを確認済み（自動投稿の対応工数レポートのみ）
- `describe`でMR descriptionを実装完了内容へ更新した（flow-id 3-10）。フェーズ3完了
- 個別反映計画 `plans/【設計反映】ベースブランチ確認機能のspec反映.md` を作成した（flow-id 4-1）。
  `.claude/docs/spec/issue-mr-workflow.md`の「提供関数」表・「影響範囲」changelog・
  「未決定事項・懸念点」への反映を予定

- commit・push（push回数3）してレビュー依頼。人間から「レビューOK」を受け、`comments all`で未解決スレッドが無いことを確認済み
- `describe`でMR descriptionを更新した（flow-id 4-5）
- `.claude/docs/spec/issue-mr-workflow.md`の3箇所（提供関数表・影響範囲changelog・未決定事項）を反映計画どおり更新（flow-id 4-6）。worklog（push4）に記録

## 次にやること

- flow-id 4-7: `commit`スキル経由でcommitし、pushしてレビュー依頼を行う

## 判断を迷った内容

（無し）

## 未解決の内容

（無し）

## 守るべき条件・触ってはいけない範囲

（無し）
