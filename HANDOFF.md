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

- issue: #45 Provider.shのget_providerがself-hosted GitLabを判定できない
- ブランチ: feature-45-detect-gitlab-provider-for-self-hosted
- Draft PR: #52 https://github.com/yuki-matsu783/MR-driven-workflow/pull/52
- push回数: 1

進捗記号: `[x]` 完了 / `[]` 未着手・進行中 / `[-]` 今回は実施しない（スキップ）

| 進捗 | flow-id | ステップ | 担当 |
|----|---|---|---|
| [x] | 1-1 | issueを起票する。issue #48対応の前段（2026-08-19以前）に起票済み | 人間（AIが代行する場合は `issue-create` スキル） |
| [x] | 1-2 | issueの内容を取得する。4見出しすべて揃っており警告なし。本文の`glab api`に関する誤記をissueへコメントで訂正した | `start <issue番号>` |
| [x] | 1-3 | featureブランチとDraft MRを作成する。`origin/main`(307ed1f)から分岐、Draft PR #52作成。空コミットフォールバックが発動（DDR 0026どおりGitHub固有の制約） | `start` |
| [x] | 1-4 | **Planモードで「全体作業計画」を作成する** → `plans/mutable-beaming-leaf.md` | エージェント |
| [x] | 1-5 | 全体作業計画に合意する | 人間 |
| [x] | 1-6 | 全体作業計画をもとにHANDOFF.mdを更新する | エージェント |
| [-] | 2-1 | **個別調査計画**（判定方式の比較を計画作成時に実測で完了したため、フェーズ2を丸ごと省略） | エージェント |
| [-] | 2-2 | （2-1を省略のため対象外） | エージェント |
| [-] | 2-3 | （同上） | 人間 |
| [-] | 2-4 | （同上） | `comments` / `reply` |
| [-] | 2-5 | （同上） | `describe` |
| [-] | 2-6 | （同上） | エージェント |
| [-] | 2-7 | （同上） | エージェント |
| [-] | 2-8 | （同上） | 人間 |
| [-] | 2-9 | （同上） | `comments` / `reply` |
| [-] | 2-10 | （同上） | `describe` |
| [] | 3-1 | 個別作業計画`plans/【実装】【テスト】get_providerのホスト判定化.md`を**planツールを使わず**Write/Editで作成する | エージェント |
| [] | 3-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 3-3 | MRで作業計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| [] | 3-4 | レビュー内容を取得し、作業計画を修正する。対応が完了したコメントには対応内容を返信する（3-3〜3-4を合意まで繰り返す） | `comments` / `reply` |
| [] | 3-5 | 作業計画をもとにMR descriptionを更新する | `describe` |
| [] | 3-6 | 作業計画をもとに作業を進める、作業内容はworklogに更新する | エージェント |
| [] | 3-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 3-8 | MRでレビュー・コメントする。レビュー済み連絡をするまで以降の作業は行わない。 | 人間 |
| [] | 3-9 | レビュー内容を取得し、実装・ドキュメントを修正する。対応が完了したコメントには対応内容を返信する（3-6〜3-9の作業ループを合意まで繰り返す） | `comments` / `reply` |
| [] | 3-10 | 作業内容をもとにMR descriptionを更新する | `describe` |
| [] | 4-1 | **作業結果と`plans/` `worklog/` の内容をもとに**、個別反映計画`plans/【設計反映】〜.md`・`plans/【AIアセット反映】〜.md`を**planツールを使わず**Write/Editで作成する | エージェント |
| [] | 4-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 4-3 | MRで反映計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| [] | 4-4 | レビュー内容を取得し、反映計画を修正する。対応が完了したコメントには対応内容を返信する（4-3〜4-4を合意まで繰り返す） | `comments` / `reply` |
| [] | 4-5 | 反映計画をもとにMR descriptionを更新する | `describe` |
| [] | 4-6 | 反映計画をもとに作業を進める、反映内容はworklogに更新する（設計反映とAIアセット反映は分けて2周回す） | エージェント |
| [] | 4-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 4-8 | MRでレビュー・コメントする。レビュー済み連絡をするまで以降の作業は行わない。 | 人間 |
| [] | 4-9 | レビュー内容を取得し、設計・AIアセットの内容を修正する。対応が完了したコメントには対応内容を返信する（4-6〜4-9の反映ループを合意まで繰り返す） | `comments` / `reply` |
| [] | 4-10 | 反映内容をもとにMR descriptionを更新する | `describe` |
| [] | 5-1 | 次タスクのために、`plans/` `worklog/` `reports/` を削除し、`HANDOFF.md` をリセットする | エージェント |
| [] | 5-2 | `commit`スキル経由でcommitし、push して Draftを解除する | エージェント |
| [] | 5-3 | マージする（squash merge。ブランチは削除してよい） | 人間 |

詳細についてはworklogを確認してください。

## やったこと

- issue #48（PR #49）がマージ済み。その成果として`Gitlab.sh`の全13関数がローカルGitLab CE 18.5.4で
  検証済みになっており、**残る障害は`get_provider`の判定のみ**であることが分かっている。
- issue #45本文の誤記（「`glab api`はremoteを参照せず既定ホストへ接続する。`GITLAB_HOST`の明示が必要」）を
  issueへコメントで訂正した。認証済みホストなら`glab api`もremoteから解決するため、
  **`GITLAB_HOST`対応は不要**。
- 判定方式の候補を実測で比較し（`glab auth status`=14.5秒／`glab config get token --host`=0.55〜0.9秒／
  `config.yml`直読み=0.1秒だがOS依存パス）、**追加forkゼロの「remote URLのホスト部で判定」を採用**した。
- ユーザー確認により`.mrworkflow.json`への`provider`キー追加は見送り（全ディスパッチで約190ms増のため）。
- 未認証時の挙動を確認し、**本方式は認証状態に依存しない**（却下した3方式はいずれも
  「glabに登録済みのホストか」を見るため未ログインでは判定できない）ことを計画に明記した。

## 次にやること

- flow-id 3-1: 個別作業計画`plans/【実装】【テスト】get_providerのホスト判定化.md`とworklogを作成する。
- flow-id 3-2: `commit`スキル経由でcommitし、リモートへ反映して作業計画のレビューを依頼する。
- flow-id 3-3: 人間による作業計画のレビュー待ち。合意が取れるまで実装（flow-id 3-6）へ進まない。

## 判断を迷った内容

- **`.mrworkflow.json`に`provider`キーを追加するか**: issue本文の案だったが見送った。
  `get_workflow_config`が`git rev-parse`と`jq`を呼ぶため、12箇所のディスパッチすべてで
  約190msずつ増える。ホスト判定だけで受け入れ条件を全て満たせるため、コストに見合わないと判断した。
- **glabの登録済みホスト情報を判定に使うか**: 使わない。速度（`glab auth status`は14.5秒）と
  OS依存パス（`%LOCALAPPDATA%/glab-cli/config.yml`）の問題に加え、**未ログイン時に判定できなくなる**
  のが決定的だった。
- **非対応リモートのエラーが分かりにくくなる点**: 「`github`を含まなければGitLab」とみなすため、
  Bitbucket等やURLのtypoに対する`サポート対象外のリモートです`という明快なメッセージが出なくなり、
  glab側のエラーに変わる。対応プロバイダが2つしかない以上ホスト名だけでは区別できず、
  self-hostedが使えない実害の方が大きいため**受け入れたトレードオフ**として扱う。

## 未解決の内容

- `to_slug`が日本語タイトルを潰す挙動（`検証用issue`→slug `issue`）。GitHub/GitLab共通コードのため
  本issueの範囲外。未起票。
- issue #50（チャットで受けたレビュー判断をMRコメントとして残す）・#51（worklog削除タイミングの
  記述矛盾）は起票済みで未着手。

## 守るべき条件・触ってはいけない範囲

- **`.claude/docs/spec/issue-mr-workflow.md`の「影響範囲」節にある過去issueのchangelogエントリを
  書き換えない。** issue #48分のエントリも含め、追記のみとする（`.claude/rules/docs-workflow.md`）。
- **DDR 0005・0026は変更しない。** 空コミットフォールバックの判断は本issueと独立しており現在も有効。
- **`Gitlab.sh` / `Github.sh`は原則変更しない。** 本issueの対象は`Provider.sh`の判定ロジックであり、
  issue #48で検証済みのプロバイダ固有実装には手を入れない。
- 検証環境のDockerコンテナ`gitlab`は停止状態で保持されている。flow-id 3-6の実機確認時に
  `docker start gitlab`で再開する。`docker exec`を使う際は`export MSYS_NO_PATHCONV=1`が必要。
