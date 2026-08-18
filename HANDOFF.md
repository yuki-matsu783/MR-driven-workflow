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

- issue: #14 gitlab/githubの情報についてはwebfetchではなくgh,glabを利用して情報取得することを明記
  (https://github.com/yuki-matsu783/MR-driven-workflow/issues/14)
- ブランチ: feature-14-prefer-gh-glab-over-webfetch
- Draft PR: #16 (https://github.com/yuki-matsu783/MR-driven-workflow/pull/16)
- push回数: 0（フェーズ3の個別作業計画・worklog作成後にpush1からカウント開始）

**このissueで実施するフェーズ**（全体作業計画 `plans/elegant-puzzling-quasar.md` 参照）:
フェーズ2（調査）は全体作業計画のContextで完了済みのため個別調査計画は作らず省略。
フェーズ3（作業）で `【実装】【設計反映】` を1個別計画に併記して実施し、フェーズ4は
フェーズ3に統合済み（下表のflow-id 4-*は該当なしとして扱う）。

| 進捗 | flow-id | ステップ | 担当 |
|----|---|---|---|
| [x] | 1-1 | issueを起票する（`.github/ISSUE_TEMPLATE/task.md` / `.gitlab/issue_templates/task.md` で目的・現状・期待する動作・受け入れ条件を記載） | 人間（AIが代行する場合は `issue-create` スキル） |
| [x] | 1-2 | issueの内容を取得する | `start <issue番号>` |
| [x] | 1-3 | featureブランチ（`feature-<issue番号>-<slug>`）とDraft MRを作成する（既にあれば `sync` のみ） | `start` |
| [x] | 1-4 | **Planモードで「全体作業計画」を作成する**（このissueをどう進めるか＝何を調査し何を実装するかの全体像。ハーネスが提示するパス `plans/<自動命名>.md` へ出力）。**現在のブランチに既に全体作業計画があれば新規作成せず、既存を読むだけにとどめる**（詳細は下記「計画の2階層構造」） | エージェント |
| [x] | 1-5 | 全体作業計画に合意する | 人間 |
| [x] | 1-6 | 全体作業計画をもとにHANDOFF.mdにワークフローのどのstepを実施するか記載する | エージェント |
| （省略） | 2-1〜2-10 | 個別調査。本issueは全体作業計画のContextで調査完了済みのため省略 | — |
| [] | 3-1 | **個別作業計画**`plans/【実装】【設計反映】〜.md`を**planツールを使わず**Write/Editで作成する。このタイミングで `worklog/日付_<全体計画名>_<個別計画名>_push<N>.md` を作成 | エージェント |
| [] | 3-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 3-3 | MRで作業計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| [] | 3-4 | レビュー内容を取得し、作業計画を修正する。対応が完了したコメントには対応内容を返信する（3-3〜3-4を合意まで繰り返す） | `comments` / `reply` |
| [] | 3-5 | 作業計画をもとにMR descriptionを更新する | `describe` |
| [] | 3-6 | 作業計画をもとに作業を進める（AGENTS.mdへのルール追記・DDR新設・index.jsonl再生成）、作業内容はworklogに更新する | エージェント |
| [] | 3-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 3-8 | MRでレビュー・コメントする。レビュー済み連絡をするまで以降の作業は行わない。 | 人間 |
| [] | 3-9 | レビュー内容を取得し、実装・ドキュメントを修正する。対応が完了したコメントには対応内容を返信する（3-6〜3-9の作業ループを合意まで繰り返す） | `comments` / `reply` |
| [] | 3-10 | 作業内容をもとにMR descriptionを更新する | `describe` |
| （省略） | 4-1〜4-10 | 個別反映。本issueはフェーズ3の個別作業計画（【実装】【設計反映】併記）に統合済みのため省略 | — |
| [] | 5-1 | 次タスクのために、`plans/` `worklog/` `reports/` を削除し、`HANDOFF.md` をリセットする | エージェント |
| [] | 5-2 | `commit`スキル経由でcommitし、push して Draftを解除する | エージェント |
| [] | 5-3 | マージする（squash merge。ブランチは削除してよい） | 人間 |

詳細についてはworklogを確認してください。

## やったこと

- issue #14を取得し、`feature-14-prefer-gh-glab-over-webfetch`ブランチとDraft PR #16を作成した
  （flow-id 1-2/1-3）。
- ブランチ作成直後はbaseとの差分が無く`gh pr create`が1回目失敗する既知の制約（DDR 0005）に、
  Provider.sh側の自動リトライで対処済みだったが、標準エラー出力だけを見て誤って失敗と判断し
  一度ユーザーに手動対応を依頼してしまった。ユーザー指摘を受けて訂正し、副次対応として
  `Github.sh`/`Gitlab.sh`のフォールバックメッセージを分かりやすく改善し、`SKILL.md`の`start`
  サブコマンド節にも注記を追加（コミット`3db75ca`, `e49bcaf`）。
- 全体作業計画（`plans/elegant-puzzling-quasar.md`）を作成しユーザーの承認を得た（flow-id 1-4/1-5）。

## 次にやること

- flow-id 3-1: 個別作業計画`plans/【実装】【設計反映】〜.md`とworklogを作成する
  （フェーズ2調査は全体作業計画のContextで完了済みのため省略、フェーズ4はフェーズ3に統合）。
  内容はAGENTS.mdへのルール追記（GitHub/GitLab情報取得はgh/glab CLI経由、WebFetch/curlは使わない）と
  DDR 0020の新設。

## 判断を迷った内容

- Draft MR作成時の「gh pr create失敗」の標準エラーを、エラーごと隠す（2>/dev/null）か、
  そのまま見せてフォールバック中である旨を追加で明示するかで一度ユーザーに確認した。
  → **見せたまま説明を添える方針**を採用（隠すと本当の別要因の失敗時に情報が消えるため）。

## 未解決の内容

（無し）

## 守るべき条件・触ってはいけない範囲

（無し）
