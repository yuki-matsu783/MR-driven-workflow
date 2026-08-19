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

- issue: #67 作業開始・再開時にベースブランチの最新を取り込めているか確認するステップをフローへ追加する
- ブランチ: claude/base-branch-sync-check-17vdvq
- PR: #107 (Draft) https://github.com/yuki-matsu783/MR-driven-workflow/pull/107
- push回数: 4
- 現在のループ: 3-6〜3-9 の1周目（進行中。人間レビューを待てない非対話セッションのため記号は[]のまま）
- 追従監視: 購読あり（web。`subscribe_pr_activity` + セッション終了前に `send_later` で自己チェックインを予約）

## フロー進捗状況

進捗記号: `[x]` 完了 / `[]` 未着手・進行中 / `[-]` 今回は実施しない（スキップ）

| 進捗 | flow-id | ステップ | 担当 |
|----|---|---|---|
| [x] | 1-1 | issueを起票する（issue #67 として起票済み） | 人間 |
| [x] | 1-2 | issueの内容を取得する（`gh` CLI不在のためMCP経路 `mcp__github__issue_read` で取得。標準4見出しはすべて揃っている） | `start <issue番号>` |
| [x] | 1-3 | featureブランチとDraft MRを作成する（ブランチはハーネス指定の `claude/base-branch-sync-check-17vdvq`。PR作成はユーザーの承認済み） | `start`（エージェント） |
| [x] | 1-4 | **全体作業計画**を作成する（`plans/base-branch-sync-check.md`。Planモードの割り当てが無いセッションのためWriteで作成） | エージェント |
| [] | 1-5 | 全体作業計画に合意する | 人間 |
| [x] | 1-6 | 全体作業計画をもとにHANDOFF.mdを更新する | エージェント |
| [x] | 2-1 | **個別調査計画**`plans/【調査】〜.md`とworklogを作成する | エージェント |
| [x] | 2-2 | `commit`スキル経由でcommitし、リモートへ反映してレビュー依頼を行う | エージェント |
| [] | 2-3 | MRで調査計画についてレビュー・コメントする | 人間 |
| [] | 2-4 | レビュー内容を取得し、調査計画を修正する（2-3〜2-4を合意まで繰り返す） | `comments` / `reply` |
| [x] | 2-5 | 調査計画をもとにMR descriptionを更新する | `describe` |
| [] | 2-6 | **調査を実施**し、結果を`reports/`のmd・htmlとworklogに記録する | エージェント |
| [] | 2-7 | `commit`スキル経由でcommitし、リモートへ反映してレビュー依頼を行う | エージェント |
| [] | 2-8 | MRで調査結果についてレビュー・コメントする | 人間 |
| [] | 2-9 | レビュー内容を取得し、調査結果を修正する（2-6〜2-9を合意まで繰り返す） | `comments` / `reply` |
| [x] | 2-10 | 調査結果をもとにMR descriptionを更新する | `describe` |
| [x] | 3-1 | 調査結果をもとに個別作業計画`plans/【実装】【テスト】〜.md`を作成する | エージェント |
| [x] | 3-2 | `commit`スキル経由でcommitし、リモートへ反映してレビュー依頼を行う | エージェント |
| [] | 3-3 | MRで作業計画についてレビュー・コメントする | 人間 |
| [] | 3-4 | レビュー内容を取得し、作業計画を修正する（3-3〜3-4を合意まで繰り返す） | `comments` / `reply` |
| [x] | 3-5 | 作業計画をもとにMR descriptionを更新する | `describe` |
| [] | 3-6 | 作業計画をもとに作業を進める（結果は`reports/`のmdへ、試行錯誤はworklogへ） | エージェント |
| [] | 3-7 | `commit`スキル経由でcommitし、リモートへ反映してレビュー依頼を行う | エージェント |
| [] | 3-8 | MRでレビュー・コメントする | 人間 |
| [] | 3-9 | レビュー内容を取得し、実装・ドキュメントを修正する（3-6〜3-9を合意まで繰り返す） | `comments` / `reply` |
| [x] | 3-10 | 作業内容をもとにMR descriptionを更新する | `describe` |
| [x] | 4-1 | 個別反映計画`plans/【設計反映】〜.md`等を作成する（まず反映対象を洗い出す） | エージェント |
| [] | 4-2 | `commit`スキル経由でcommitし、リモートへ反映してレビュー依頼を行う | エージェント |
| [] | 4-3 | MRで反映計画についてレビュー・コメントする | 人間 |
| [] | 4-4 | レビュー内容を取得し、反映計画を修正する（4-3〜4-4を合意まで繰り返す） | `comments` / `reply` |
| [] | 4-5 | 反映計画をもとにMR descriptionを更新する | `describe` |
| [] | 4-6 | 反映計画をもとに設計反映・AIアセット反映を進める | エージェント |
| [] | 4-7 | `commit`スキル経由でcommitし、リモートへ反映してレビュー依頼を行う | エージェント |
| [] | 4-8 | MRでレビュー・コメントする | 人間 |
| [] | 4-9 | レビュー内容を取得し、設計・AIアセットの内容を修正する（4-6〜4-9を合意まで繰り返す） | `comments` / `reply` |
| [] | 4-10 | 反映内容をもとにMR descriptionを更新する | `describe` |
| [] | 5-1 | `cleanup-task.sh`で`plans/` `worklog/` `reports/`を削除し`HANDOFF.md`をリセットする | エージェント |
| [] | 5-2 | defaultブランチとのコンフリクトを検知し、あれば解消する | エージェント（`resolve-conflict` スキル） |
| [] | 5-3 | 今回のMRが影響する関連issueを特定し、承認を得てから通知する | エージェント |
| [] | 5-4 | `commit`スキル経由でcommitし、リモートへ反映してDraftを解除する | エージェント |
| [] | 5-5 | マージする（squash merge） | 人間 |

詳細についてはworklogを確認してください。

<!-- 直前タスク（issue #38 / PR #104）のflow-id 5-1〜5-4は完了済み。マージは人間が行う。 -->

## やったこと

- flow-id 1-2: issue #67 の内容をMCP経路（`mcp__github__issue_read`）で取得した。標準4見出し
  （目的・現状・期待する動作・受け入れ条件）はすべて揃っている。issue #86 のマージ前通知
  コメントにより、フローが40→41ステップになっている前提を確認した。
- flow-id 1-4: 全体作業計画 `plans/base-branch-sync-check.md` を作成した。Planモードの
  plan割り当てが無いセッションのため、planツールではなくWriteで作成している（ファイル名は
  `【` で始まらないため、位置づけは全体作業計画）。
- ユーザーへ2点確認した（`AskUserQuestion`）。
  - 「フェーズごとに自動で敵対的レビューをすること」は**本セッションの進め方の指示**であり、
    `adversarial-review` スキルの起動ポリシーを恒久的に変更する依頼ではない。
  - issue #67 用の Draft PR を作成してよい（ハーネスがPR作成を制限する環境のため確認した）。
- flow-id 1-3: 計画・HANDOFF.mdをコミットしてリモートへ反映し、Draft PR #107 を作成した。
  あわせて `subscribe_pr_activity` でPRイベントの購読を開始した（追従監視）。
- flow-id 2-1: 個別調査計画 `plans/【調査】ベースブランチ追従確認の差し込み地点と検知方法.md` と
  worklog を作成した。フェーズ2は省略しない（gitコマンドの境界条件・既存機構の守備範囲を
  実物で確かめる必要があるため）。
- flow-id 2-2 の直後に **敵対的レビュー（フェーズ2・1回目）** を実施した（本セッションでは
  ユーザーの指示により各フェーズのpush直後に自動実施する）。指摘9件のうち4件をPR #107 へ
  インライン投稿し、5件は報告に留めた。**投稿した4件のうち3件は実機で裏取りが取れた**
  （このリポジトリがshallow cloneであること・`.claude/rules/` に `rebase` の語が0件であること・
  `issue-mr-resume` に `git fetch` が0件であること）。指摘はすべて計画・レポートへ反映済み。
- flow-id 2-6: 調査を実施し、結果を `reports/20260819_base-branch-sync-check_調査結果.md`
  （正文）と同名の `.html` へ記録した。使い捨てのgitリポジトリを作って境界条件を実測し、
  確認後に削除した。主な結論は次の4点。
  - 「コンフリクトは無いが遅れている」を検知する機構はこのリポジトリに1つも無い（前提は成立）
  - behind・ahead は `git rev-list --left-right --count origin/<base>...HEAD` 1回で取れる
  - 未取り込みファイルは3ドット記法必須。**merge-baseが無いと3ドットdiffは終了コード128で落ちる**
  - **`issue-mr-resume` がサマリを組み立てる時点では未fetch**のため、fetchの責務は新スクリプト側へ置く
- flow-id 2-5・2-10: MR description を更新した（受け入れ条件との対応表・調査で確定した設計上の
  要点を含む）。
- flow-id 2-7 の直後に **敵対的レビュー（フェーズ2・2回目）** を実施した。指摘12件のうち7件を
  インライン投稿。**うち2件は実装そのものを変えた**（fetch失敗を握りつぶさず `fetchOk` を出す／
  single-branch clone をrefspec形fetchで自動的に扱う）。「3点リーダ」が `A...B` の呼称として
  誤りである指摘も受け、`3ドット記法` へ統一した。
- flow-id 3-1: 個別作業計画
  `plans/【実装】【テスト】ベースブランチ追従確認の検知スクリプトとフローへの組み込み.md` を作成した。
- flow-id 3-6 相当（**実作業は完了済み。人間レビューを挟めずループが1周していないため
  3-6〜3-9 の記号は `[]` のまま**）:
  - `.claude/scripts/src/check-base-sync.sh`（新規）と
    `.claude/scripts/test/test_check_base_sync.sh`（新規・29件）を実装した。
  - `.claude/skills/issue-mr-flow/SKILL.md` へ「作業開始・再開時のベースブランチ追従確認」節を
    新設し、`start`（既存ブランチ検出時）・`resume`・`sync` から参照させた。**flow-idは増やして
    いない**（issue #88 と同じ「並行手順」の扱い）。
  - `.claude/agents/issue-mr-resume.md` へ手順7を新設し、現在地サマリへ
    `- ベースブランチとの差分:` を追加した。
  - 使い捨ての別リポジトリで6ケースを実測し、リポジトリ全体の単体テスト399件も通ることを
    確認した。結果は `reports/20260819_base-branch-sync-check_実装結果.md` が正文。
- **進捗表の記号を一度誤って付けた**。`mark-done 2-6` を呼んだところループ範囲 2-6〜2-9 が
  まとめて `[x]` になり、人間のレビュー（2-8）まで完了扱いになったため `[]` へ戻した
  （非対話セッションで人間レビューを省略する場合の扱いは `.claude/rules/docs-workflow.md` が正）。

- **`main` の進行（PR #104 / issue #38）を検知し、取り込んだ**。検知したのは今回作った
  `check-base-sync.sh` 自身（`behind: 1`）。`HANDOFF.md` の競合を作業ブランチ側で解消し、
  **`main` が DDR 0049 を使用済み**であることが分かったため、今回のDDRは 0050 で起こした。
- flow-id 3-7 の直後に **敵対的レビュー（フェーズ3・1回目）** を起動した。
- flow-id 4-1: 個別反映計画を2つ作成した（`【設計反映】` と `【AIアセット反映】` は分ける方針）。
  反映対象を洗い出した結果は空ではないため、フェーズ4は省略していない。
- flow-id 4-6 相当（**実作業は完了済み。人間レビューを挟めずループが1周していないため
  4-6〜4-9 の記号は `[]` のまま**）:
  - **設計反映**: `.claude/docs/spec/check-base-sync.md`（新規）・
    `.claude/docs/ddr/0050-…md`（新規）・`.claude/docs/README.md`・
    `.claude/docs/spec/issue-mr-workflow.md`「影響範囲」への追記。
  - **AIアセット反映**: `.claude/rules/git-workflow.md`「ブランチ運用」へ、追従確認の入口と
    **rebaseを使わない方針**を追記（調査で `.claude/rules/` 配下に `rebase` の語が0件だと判明）。
  - 結果は `reports/20260819_base-branch-sync-check_反映結果.md` が正文。

## 次にやること

- flow-id 5-1: `bash .claude/scripts/src/cleanup-task.sh` で `plans/` `worklog/` `reports/` を
  片付け、`HANDOFF.md` をリセットする。
- flow-id 5-2〜5-4: コンフリクト検知 → 関連issue通知（承認必須）→ Draft解除。
- flow-id 5-5（マージ）は**ユーザーの明示指示があるまで実行しない**。

## 判断を迷った内容

- **`main` の進行（PR #104 / issue #38）を取り込んだ際、`HANDOFF.md` が競合した**。`main` 側は
  直前タスク（issue #38）の「やったこと」を持っていたが、`HANDOFF.md` は「常にこのブランチの
  現状を表現する」ファイルであるため、**作業ブランチ側（ours）を採用**し `main` 側のエントリは
  取り込まなかった（他ファイルはすべて自動マージ）。解消方法が一意に決まるため、レビュー待ちを
  挟まず解消している（`.claude/skills/issue-mr-flow/SKILL.md`「PR作成後のdefaultブランチ追従」）。
- **`main` 側が DDR 0049 を使用済み**（`0049-ドキュメント探索はfrontmatterインデックス検索を
  第一手段にする.md`）。フェーズ4で新規DDRを起こす際は **0050 以降**を使う。

- **ブランチ名が命名規則（`feature-<issue番号>-<slug>`）に一致しない**。ハーネスが
  `claude/base-branch-sync-check-17vdvq` を指定しており、これを変更するとpush先の指示に反する
  ため、そのまま使う。`get_issue_number_from_branch` はこのブランチ名からissue番号を抽出
  できないため、issue番号は手動で補っている。

## 未解決の内容

（無し）

## 守るべき条件・触ってはいけない範囲

- `adversarial-review` スキル・`issue-mr-flow` SKILL.md の**起動ポリシー（対話セッションでは
  AIから自律起動しない）は変更しない**。本セッションでの自動実施はユーザーからの個別指示による
  ものであり、フロー定義の恒久的な変更ではない。
- 既存の `check-base-conflicts.sh`（flow-id 5-2・issue #46）の責務・出力JSONは変更しない。
