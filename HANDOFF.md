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

- issue: #13 レビュー依頼にMRへのリンクをつける
- ブランチ: claude/issue-13-ne7acm（Claude Code on the webが自動作成。`feature-<issue>-<slug>`
  命名規則とは異なるが、既に本ブランチで開発するよう指示されているためそのまま使用）
- Draft PR: 未作成（人間から明示的な指示があるまでAIエージョンはPR作成操作を行わない方針
  `.claude/rules/git-workflow.md`のため。ブランチへのpushのみ実施）
- push回数: 1（予定）

対話的セッションでないため、通常の39ステップの複数ラウンド運用ではなく、設計・実装・設計反映を
1回のpushにまとめて実施した（詳細は個別作業計画「実行環境に関する注記」参照）。下表は目安として
対応するflow-idにチェックを付けている。

| 進捗 | flow-id | ステップ | 担当 |
|----|---|---|---|
| [x] | 1-1 | issueを起票する（`.github/ISSUE_TEMPLATE/task.md` / `.gitlab/issue_templates/task.md` で目的・現状・期待する動作・受け入れ条件を記載） | 人間（AIが代行する場合は `issue-create` スキル） |
| [x] | 1-2 | issueの内容を取得する | `start <issue番号>` |
| [] | 1-3 | featureブランチ（`feature-<issue番号>-<slug>`）とDraft MRを作成する（既にあれば `sync` のみ） | `start` — ブランチは`claude/issue-13-ne7acm`として既に用意されていたため`new_issue_branch`は未使用。Draft PRも未作成（上記フロー進捗状況参照） |
| [] | 1-4 | **Planモードで「全体作業計画」を作成する**（このissueをどう進めるか＝何を調査し何を実装するかの全体像。ハーネスが提示するパス `plans/<自動命名>.md` へ出力）。**現在のブランチに既に全体作業計画があれば新規作成せず、既存を読むだけにとどめる**（詳細は下記「計画の2階層構造」） | エージェント |
| [] | 1-5 | 全体作業計画に合意する | 人間 |
| [] | 1-6 | 全体作業計画をもとにHANDOFF.mdを更新する | エージェント |
| [] | 2-1 | **個別調査計画**`plans/【調査】〜.md`を**planツールを使わず**Write/Editで作成する。このタイミングで `worklog/日付_<全体計画名>_<個別計画名>_push<N>.md` を作成 | エージェント |
| [] | 2-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 2-3 | MRで調査計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| [] | 2-4 | レビュー内容を取得し、調査計画を修正する。対応が完了したコメントには対応内容を返信する（2-3〜2-4を合意まで繰り返す） | `comments` / `reply` |
| [] | 2-5 | 調査計画をもとにMR descriptionを更新する | `describe` |
| [] | 2-6 | **調査を実施**し、結果を個別調査計画・worklogに記録する。あわせて結果を視覚的に分かりやすくまとめた自己完結HTML（TailwindCSS CDN方式）を`reports/日付_<全体計画名>_<内容を簡潔に>.html`として作成する（複数要素間の関連・依存関係が主題の場合は、`.claude/skills/canvas-report/SKILL.md`のcanvas形式テンプレートの利用を検討する） | エージェント |
| [] | 2-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 2-8 | MRで調査結果についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| [] | 2-9 | レビュー内容を取得し、調査結果を修正する。対応が完了したコメントには対応内容を返信する（`reports/`のHTMLも調査結果と同期して更新する。2-6〜2-9を合意まで繰り返す） | `comments` / `reply` |
| [] | 2-10 | 調査結果をもとにMR descriptionを更新する | `describe` |
| [x] | 3-1 | **調査結果をもとに**、個別作業計画`plans/【設計】【実装】〜.md`等を**planツールを使わず**Write/Editで作成する | エージェント — 調査フェーズ（2-x）は小規模変更のため省略し、直接`plans/【設計】【実装】【設計反映】レビュー依頼メッセージへの参照リンク付与.md`を作成 |
| [x] | 3-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント — 3-2/3-7/4-2/4-7を1回のpushに統合（下記「やったこと」参照） |
| [] | 3-3 | MRで作業計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| [] | 3-4 | レビュー内容を取得し、作業計画を修正する。対応が完了したコメントには対応内容を返信する（3-3〜3-4を合意まで繰り返す） | `comments` / `reply` |
| [] | 3-5 | 作業計画をもとにMR descriptionを更新する | `describe` |
| [x] | 3-6 | 作業計画をもとに作業を進める、作業内容はworklogに更新する | エージェント |
| [x] | 3-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント（3-2と同一push） |
| [] | 3-8 | MRでレビュー・コメントする。レビュー済み連絡をするまで以降の作業は行わない。 | 人間 |
| [] | 3-9 | レビュー内容を取得し、実装・ドキュメントを修正する。対応が完了したコメントには対応内容を返信する（3-6〜3-9の作業ループを合意まで繰り返す） | `comments` / `reply` |
| [] | 3-10 | 作業内容をもとにMR descriptionを更新する | `describe` |
| [x] | 4-1 | **作業結果と`plans/` `worklog/` の内容をもとに**、個別反映計画`plans/【設計反映】【AIアセット反映】〜.md`等を**planツールを使わず**Write/Editで作成する | エージェント — 個別作業計画に反映内容も併記（種別を複数併記する基準どおり、1回の合意で済むため） |
| [x] | 4-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント（3-2と同一push） |
| [] | 4-3 | MRで反映計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| [] | 4-4 | レビュー内容を取得し、反映計画を修正する。対応が完了したコメントには対応内容を返信する（4-3〜4-4を合意まで繰り返す） | `comments` / `reply` |
| [] | 4-5 | 反映計画をもとにMR descriptionを更新する | `describe` |
| [x] | 4-6 | 反映計画をもとに作業を進める、反映内容はworklogに更新する（**設計反映**: `plans/` `worklog/` の内容を `.claude/docs/spec/` `.claude/docs/ddr/`（アプリ本体があれば`docs/spec/` `docs/ddr/`）へ反映する／**AIアセット反映**: 作業中に気づいたルール・スキルの不備を `.claude/rules/` `.claude/skills/` `CLAUDE.md` `AGENTS.md` に反映する） | エージェント — spec更新・DDR 0022新設・`directory-structure.md`更新 |
| [x] | 4-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント（3-2と同一push） |
| [] | 4-8 | MRでレビュー・コメントする。レビュー済み連絡をするまで以降の作業は行わない。 | 人間 |
| [] | 4-9 | レビュー内容を取得し、設計・AIアセットの内容を修正する。対応が完了したコメントには対応内容を返信する（4-6〜4-9の反映ループを合意まで繰り返す） | `comments` / `reply` |
| [] | 4-10 | 反映内容をもとにMR descriptionを更新する | `describe` |
| [] | 5-1 | 次タスクのために、`plans/` `worklog/` `reports/` を削除し、`HANDOFF.md` をリセットする | エージェント |
| [] | 5-2 | `commit`スキル経由でcommitし、push して Draftを解除する | エージェント |
| [] | 5-3 | マージする（squash merge。ブランチは削除してよい） | 人間 |

詳細についてはworklogを確認してください。

## やったこと

- issue #13対応。`post-push-compact-prompt.sh`（`git push`検知でレビュー依頼メッセージを促すhook）
  へ、MR/差分/コメント一覧の参照リンクを付与した。
- `.claude/scripts/src/vcs/{Github,Gitlab}.sh`に純粋関数（`github_get_mr_diff_url`等）を追加し、
  `Provider.sh`から`get_mr_diff_url` / `get_mr_diff_since_url`としてディスパッチできるようにした。
- `tests/test_vcs_provider.sh`を新規作成し、上記の純粋関数を単体テストした（4件passed）。
- 設計判断を`.claude/docs/ddr/0022-...md`に記録し、`.claude/docs/spec/issue-mr-workflow.md`
  （提供関数表・/compact呼びかけ節・影響範囲・未決定事項）、`.claude/docs/README.md`（DDR一覧）、
  `.claude/rules/directory-structure.md`（`.claude/state/`の説明）を更新した。
- 対話的セッションでないため、設計・実装・設計反映を1回のpushにまとめて実施した
  （詳細は個別作業計画の「実行環境に関する注記」参照）。

## 次にやること

- 人間によるレビュー（Draft PR作成含む）。AIエージェントはPR作成操作を明示的な指示無く行わない
  方針のため、レビューを希望する場合はPR作成を指示してください。
- 実際のGitHub UI上での`get_mr_diff_since_url`（コミット範囲URL）の表示確認、GitLab側の実機検証は
  未実施（spec「未決定事項・懸念点」に記載済み）。

## 判断を迷った内容

- 「前回pushとの差分」判定用の状態ファイルの置き場所（`usage/state/`への相乗り vs 新規分離）。
  → 責務分離のため`.claude/state/review-links/`へ新規分離した（DDR 0022参照）。
- 「コメント一覧(MR画面)」リンクを別URLとして組み立てるか、MRへのリンクをそのまま使うか。
  → GitHubのPRデフォルトビュー（Conversationタブ）がコメント一覧を兼ねるため、MRへのリンクを
  そのまま再掲する設計にした。

## 未解決の内容

- `get_mr_diff_since_url`のGitHub URL形式（`/pull/<n>/files/<from>..<to>`）はブラウザでの実地
  検証ができていない（既知のURL形式に基づく実装）。
- GitLab実装（`gitlab_get_mr_diff_since_url`）は他の`gitlab_*`関数と同様、実機未検証。

## 守るべき条件・触ってはいけない範囲

（無し）
