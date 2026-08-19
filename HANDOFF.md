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

- issue: #46 マージ依頼前にdefaultブランチとのコンフリクトを検知・解消するフローを整備する
- ブランチ: claude/default-branch-conflict-detection-jdsimt
- Draft PR: 未作成（非対話的実行環境のため、PR作成はユーザーの指示を待つ）
- push回数: 1

進捗記号: `[x]` 完了 / `[]` 未着手・進行中 / `[-]` 今回は実施しない（スキップ）

**注記**: 本タスクは非対話的実行環境（Claude Code on the webのリモートセッション）で実施したため、
人間担当のレビュー往復ステップ（2-3/2-4, 3-3/3-4, 3-8/3-9, 4-3/4-4, 4-8/4-9）と `describe` は
実施できていない。`.claude/rules/docs-workflow.md` の方針に従い、該当ループ範囲の記号は `[]` の
まま残し、実際に行った内容は「やったこと」に記載する。

| 進捗 | flow-id | ステップ | 担当 |
|----|---|---|---|
| [x] | 1-1 | issueを起票する（issue #46。人間が起票済み） | 人間（AIが代行する場合は `issue-create` スキル） |
| [x] | 1-2 | issueの内容を取得する（`mcp__github__issue_read`。標準4見出しすべて揃っている） | `start <issue番号>` |
| [-] | 1-3 | featureブランチとDraft MRを作成する（ハーネスが `claude/default-branch-conflict-detection-jdsimt` を指定済みのため新規作成しない。命名規則 `feature-46-*` からは外れる） | `start` |
| [x] | 1-4 | 全体作業計画 `plans/steady-merging-lantern.md`（Planモード非対話のため、planツールを使わずWrite/Editで作成） | エージェント |
| [] | 1-5 | 全体作業計画に合意する | 人間 |
| [x] | 1-6 | 全体作業計画をもとにHANDOFF.mdを更新する | エージェント |
| [-] | 2-1 | **個別調査計画**（過去実績の調査は計画作成時に実測で完了したため、フェーズ2を丸ごと省略） | エージェント |
| [-] | 2-2 | （2-1を省略のため対象外） | エージェント |
| [-] | 2-3 | （同上） | 人間 |
| [-] | 2-4 | （同上） | `comments` / `reply` |
| [-] | 2-5 | （同上） | `describe` |
| [-] | 2-6 | （同上） | エージェント |
| [-] | 2-7 | （同上） | エージェント |
| [-] | 2-8 | （同上） | 人間 |
| [-] | 2-9 | （同上） | `comments` / `reply` |
| [-] | 2-10 | （同上） | `describe` |
| [x] | 3-1 | 個別作業計画 `plans/【実装】【テスト】【設計反映】【AIアセット反映】コンフリクト検知スクリプトとresolve-conflictスキル.md` を作成 | エージェント |
| [x] | 3-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 3-3 | MRで作業計画についてレビュー・コメントする | 人間 |
| [] | 3-4 | レビュー内容を取得し、作業計画を修正する（3-3〜3-4を合意まで繰り返す） | `comments` / `reply` |
| [] | 3-5 | 作業計画をもとにMR descriptionを更新する | `describe` |
| [] | 3-6 | 作業計画をもとに作業を進める、作業内容はworklogに更新する（**実施済み。非対話環境のためレビュー往復と対になっておらず記号は `[]` のまま**） | エージェント |
| [] | 3-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う（**実施済み・同上**） | エージェント |
| [] | 3-8 | MRでレビュー・コメントする | 人間 |
| [] | 3-9 | レビュー内容を取得し、実装・ドキュメントを修正する（3-6〜3-9の作業ループを合意まで繰り返す） | `comments` / `reply` |
| [] | 3-10 | 作業内容をもとにMR descriptionを更新する | `describe` |
| [x] | 4-1 | 個別反映計画（同一ファイルへ `【設計反映】【AIアセット反映】` を併記） | エージェント |
| [x] | 4-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 4-3 | MRで反映計画についてレビュー・コメントする | 人間 |
| [] | 4-4 | レビュー内容を取得し、反映計画を修正する（4-3〜4-4を合意まで繰り返す） | `comments` / `reply` |
| [] | 4-5 | 反映計画をもとにMR descriptionを更新する | `describe` |
| [] | 4-6 | 反映計画をもとに作業を進める（**実施済み。設計反映=spec+DDR 0029、AIアセット反映=flow-id繰り下げ**） | エージェント |
| [] | 4-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う（**実施済み・同上**） | エージェント |
| [] | 4-8 | MRでレビュー・コメントする | 人間 |
| [] | 4-9 | レビュー内容を取得し、設計・AIアセットの内容を修正する（4-6〜4-9の反映ループを合意まで繰り返す） | `comments` / `reply` |
| [] | 4-10 | 反映内容をもとにMR descriptionを更新する | `describe` |
| [] | 5-1 | 次タスクのために、`plans/` `worklog/` `reports/` を削除し、`HANDOFF.md` をリセットする | エージェント |
| [] | 5-2 | **defaultブランチとのコンフリクトを検知し、あれば解消する**（本issueで新設したステップ。このブランチ自身が最初の適用対象になる） | エージェント（`resolve-conflict` スキル） |
| [] | 5-3 | `commit`スキル経由でcommitし、push して Draftを解除する | エージェント |
| [] | 5-4 | マージする（squash merge。ブランチは削除してよい） | 人間 |

詳細についてはworklogを確認してください。

## やったこと

- **過去の発生実績を棚卸しした。** issueに挙がっていた2件（PR #29, #37）ではなく**4件**
  （PR #29 / #37 / #49 / #52）あり、**4件すべてでDDR番号が衝突**していた。解消方向・
  取り込み方法（merge、rebaseではない）も4件すべてで一致していた。
- **DDR番号の衝突をgitが検知できないことを実証した。** PR #52の両親コミットに対して
  `git merge-tree --write-tree` を実行すると、`README.md` と `test_vcs_provider.sh` の
  コンフリクトは報告されるが、両側が別名で追加した `0027-*.md` については何も報告されない。
  → 「`git merge` を試してコンフリクトが出るか見る」という手順では最頻の衝突を取りこぼすため、
  専用の検知スクリプトを作る方針を決めた。
- **`.claude/scripts/src/check-base-conflicts.sh` を新規実装**（テキストコンフリクト＋DDR番号重複。
  作業ツリー非破壊。判定はJSONで返し終了コードには載せない）。PR #52・PR #37の断面で、
  当時のコンフリクトが再現することを確認した。
- **`tests/test_check_base_conflicts.sh` を新規追加**（純粋関数13件。既存4テストと合わせて全件パス）。
- **`.claude/skills/resolve-conflict/SKILL.md` を新規作成**（検知→AskUserQuestion→merge→
  類型A〜Eの解消→検証→commit→報告の7ステップ）。
- **`issue-mr-flow` に flow-id 5-2 を新設**し、旧5-2→5-3・旧5-3→5-4へ繰り下げ（39→40ステップ）。
  flow-idを参照している `commit`スキル・`git-workflow.md`・`docs-workflow.md`・
  `spec/issue-mr-workflow.md` も更新した。
- **設計反映**: `.claude/docs/spec/check-base-conflicts.md`（新規）、
  `.claude/docs/ddr/0029-…md`（新規）、`.claude/docs/README.md`（spec/DDR一覧）、
  `spec/issue-mr-workflow.md` の「影響範囲」へissue #46のエントリを追記。
- **AIアセット反映**: `.gitignore` の `index.jsonl` 除外理由コメントが参照するDDR番号を
  `0024` → `0025` へ修正（issue #36の改番時の更新漏れで、存在しないDDRを指したままだった）。
  `index.md` と `apply-mr-workflow-to-project/SKILL.md` のスキル・スクリプト一覧も更新。

## 次にやること

- 人間によるレビュー（flow-id 3-3/3-8, 4-3/4-8）。非対話的実行環境のため未実施。
- PRの作成（ユーザーからの明示的な指示待ち。`.claude/rules/git-workflow.md` の原則どおり）。
- flow-id 5-1（plans/worklog削除・HANDOFF.mdリセット）→ 5-2（新設したコンフリクト検知を
  このブランチ自身に適用）→ 5-3（Draft解除）。

## 判断を迷った内容

- **flow-idを新設するか、既存の5-2へ追記するか。** issueの受け入れ条件は「flow-id 5-2
  （またはその直前）に…ステップが追加されている」で、どちらでも満たせる。**新設**を選んだ理由は、
  「Draft解除の直前に必ず通る」ことを独立したステップとして表現したかったため。代償として
  ステップ数の繰り下げ（39→40）が発生し、flow-idを参照する5ファイルの更新が必要になった。
- **検知をpush検知hookで自動化するか。** 「読まれなければ機能しない」対策を避けたいという
  DDR 0012/0027の考え方からは自動化が筋だが、push検知hookには部分一致による誤発火の既知問題があり
  （`.claude/rules/git-workflow.md`）、その上に `git fetch` を伴う判定を積むと誤発火のたびに
  不要な通信が走る。コンフリクトはマージ依頼の直前にだけ確認できればよいため、
  flow-id 5-2という「必ず通る手順」として明示する方式にした（DDR 0029の却下案に記載）。
- **DDR番号を連番からタイムスタンプ/UUIDへ変えて衝突自体を無くす案**は、既存28件のDDRと
  相互参照の全面書き換えが必要でissueの範囲を大きく超えるため却下した（DDR 0029に記載）。
  将来、衝突頻度が改番コストに見合わなくなった時点で再検討してよい。

## 未解決の内容

- **ブランチ名がリポジトリの命名規則から外れている。** ハーネスが指定した
  `claude/default-branch-conflict-detection-jdsimt` で作業しており、`.mrworkflow.json` の
  `branchPrefixTemplate`（`feature-46-<slug>`）に一致しない。このため
  `get_issue_number_from_branch` はissue番号を抽出できず、SessionStart hookも「issue: 特定できず」
  と表示する。過去にも同種のブランチ（`claude/issue-34-sm2mqs` 等）でマージされた実績があるため
  そのまま進めたが、命名規則との整合は未解決のままである。
- **`resolve-conflict` スキルは実運用でまだ1度も使われていない。** 検知側は過去2件の断面で
  再現確認済みだが、解消手順（類型A〜E）は過去実績からの抽出であり、実際にこのスキルを通して
  解消した実績はまだ無い。次にコンフリクトが起きたときが最初の適用機会になる。

## 守るべき条件・触ってはいけない範囲

- **DDR 0001〜0028の本文は変更しない**（`.claude/rules/docs-workflow.md`）。frontmatterの
  `status`/`superseded_by` のみ後から更新してよい。
- **`.claude/scripts/src/update-handoff-progress.sh` の `LOOP_RANGES` は変更しない。**
  フェーズ2〜4のループ範囲のみを扱っており、今回追加したフェーズ5のステップはループではない。
- **既存テスト（`tests/test_*.sh`）を落とさない。** 変更のたびに全件実行して確認すること。
