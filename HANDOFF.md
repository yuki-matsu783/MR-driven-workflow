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
- PR: [#29](https://github.com/yuki-matsu783/MR-driven-workflow/pull/29)（ユーザーから明示的に
  「作成して」と指示されたため作成。Draftではなく通常PR。作成時点で既にGitHub側に同一ブランチの
  PRが存在していたため、`create_pull_request`は失敗し`update_pull_request`でdescriptionのみ更新）
- push回数: 3

対話的セッションでないため、通常の39ステップの複数ラウンド運用ではなく、設計・実装・設計反映を
1回のpushにまとめて実施した（詳細は個別作業計画「実行環境に関する注記」参照）。下表は目安として
対応するflow-idにチェックを付けている。

進捗記号: `[x]` 完了 / `[]` 未着手・進行中 / `[-]` 今回は実施しない（スキップ）

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
| [x] | 4-6 | 反映計画をもとに作業を進める、反映内容はworklogに更新する（**設計反映**: `plans/` `worklog/` の内容を `.claude/docs/spec/` `.claude/docs/ddr/`（アプリ本体があれば`docs/spec/` `docs/ddr/`）へ反映する／**AIアセット反映**: 作業中に気づいたルール・スキルの不備を `.claude/rules/` `.claude/skills/` `CLAUDE.md` `AGENTS.md` に反映する） | エージェント — spec更新・DDR 0023新設・`directory-structure.md`更新 |
| [x] | 4-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント（3-2と同一push） |
| [] | 4-8 | MRでレビュー・コメントする。レビュー済み連絡をするまで以降の作業は行わない。 | 人間 |
| [] | 4-9 | レビュー内容を取得し、設計・AIアセットの内容を修正する。対応が完了したコメントには対応内容を返信する（4-6〜4-9の反映ループを合意まで繰り返す） | `comments` / `reply` |
| [] | 4-10 | 反映内容をもとにMR descriptionを更新する | `describe` |
| [] | 5-1 | 次タスクのために、`plans/` `worklog/` `reports/` を削除し、`HANDOFF.md` をリセットする。**あわせて `plans/index.jsonl` も削除し、`bash .claude/scripts/src/extract-frontmatter.sh .` で `index.jsonl` 群を再生成する** | エージェント |
| [] | 5-2 | `commit`スキル経由でcommitし、push して Draftを解除する | エージェント |
| [] | 5-3 | マージする（squash merge。ブランチは削除してよい） | 人間 |

詳細についてはworklogを確認してください。

## やったこと

- issue #13対応。`post-push-compact-prompt.sh`（`git push`検知でレビュー依頼メッセージを促すhook）
  へ、MR/差分/コメント一覧の参照リンクを付与した。
- `.claude/scripts/src/vcs/{Github,Gitlab}.sh`に純粋関数を追加し、`Provider.sh`から
  ディスパッチできるようにした。`tests/test_vcs_provider.sh`を新規作成し単体テストした。
- 設計判断を`.claude/docs/ddr/0023-...md`に記録し、`.claude/docs/spec/issue-mr-workflow.md`
  （提供関数表・/compact呼びかけ節・影響範囲・未決定事項）、`.claude/docs/README.md`（DDR一覧）、
  `.claude/rules/directory-structure.md`（`.claude/state/`の説明）を更新した。
- 対話的セッションでないため、設計・実装・設計反映を1回のpushにまとめて実施した
  （詳細は個別作業計画の「実行環境に関する注記」参照）。
- **push2（フォローアップ）**: ユーザーから「gh,glabを使ってフルパスにできる？」という指摘を受け、
  `AskUserQuestion`で意図を確認（「URLの正確性をgh/glabで担保したい」を選択）。push1時点の
  「MR/PRのURL文字列へ`/files`等のsuffixを推測で付け足す」実装を撤回し、`get_repo_url`
  （`gh repo view` / `glab repo view`でリポジトリの正規URLを取得）を土台に、GitHub/GitLab
  いずれも持つ汎用の「Compare」ページ（`/compare/<from>...<to>`）を組み立てる方式へ変更した
  （`get_mr_diff_url`/`get_mr_diff_since_url`のシグネチャ変更を含む）。DDR 0023・spec・
  `tests/test_vcs_provider.sh`も追随して更新済み。
- **push3（PR作成指示）**: ユーザーから「作成して」と指示され、PRを作成しようとしたところ、
  GitHub側に既に同一ブランチのPR #29が存在していた（Claude Code on the webが自動作成したと
  見られる）ため、`update_pull_request`でdescriptionのみ更新。あわせて`main`が既に issue #23
  （PR #24）を取り込んでおり、そちらも独立に`.claude/docs/ddr/0022-...md`を新設していたため
  DDR番号が衝突していたことが判明（PRの`mergeable_state: dirty`で発覚）。自分のDDRを0022→0023へ
  改番し、全参照箇所（spec/plan/worklog/HANDOFF/DDR本文/README）を追随。`origin/main`をmergeし、
  `.claude/docs/README.md`・各`index.jsonl`・`.claude/docs/spec/issue-mr-workflow.md`（影響範囲の
  changelog append）・`.claude/rules/directory-structure.md`・`.gitignore`の6ファイルのコンフリクトを
  解消してpush。PR #29のdescriptionもDDR番号を0023へ修正済み。

## 次にやること

- 人間によるレビュー（PR #29）。
- 実際のGitHub UI上での`get_mr_diff_since_url`（Compareページ）の表示確認、GitLab側の実機検証は
  未実施（spec「未決定事項・懸念点」に記載済み）。

## 判断を迷った内容

- 「前回pushとの差分」判定用の状態ファイルの置き場所（`usage/state/`への相乗り vs 新規分離）。
  → 責務分離のため`.claude/state/review-links/`へ新規分離した（DDR 0023参照）。
- 「コメント一覧(MR画面)」リンクを別URLとして組み立てるか、MRへのリンクをそのまま使うか。
  → GitHubのPRデフォルトビュー（Conversationタブ）がコメント一覧を兼ねるため、MRへのリンクを
  そのまま再掲する設計にした。
- （push2）差分リンクの土台をPR/MRのURL文字列（推測suffix）にするか、`gh`/`glab`で取得した
  リポジトリの正規URL（Compareページ）にするか。→ ユーザーの指摘どおり後者を採用（DDR 0023参照）。

## 未解決の内容

- `get_mr_diff_url`/`get_mr_diff_since_url`のCompareページURL形式（`/compare/<from>...<to>`）は
  ブラウザでの実地検証ができていない（PR作成前から存在する標準機能に基づく実装で、push1時点の
  PRサブタブ形式より確度は上がったと考えているが未検証である点は変わらない）。
- GitLab実装（`gitlab_get_repo_url`/`gitlab_get_compare_url`等）は他の`gitlab_*`関数と同様、
  実機未検証。

## 守るべき条件・触ってはいけない範囲

（無し）
