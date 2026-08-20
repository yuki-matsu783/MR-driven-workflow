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

- issue: #133 DDRの識別子を連番からissue番号ベースへ変更し、並行開発時の番号衝突を原理的に無くす
- ブランチ: claude/ddr-identifier-issue-based-vpskgp
- PR: #137 (Draft) https://github.com/yuki-matsu783/MR-driven-workflow/pull/137
- push回数: 2
- 現在のループ: 4-6〜4-9 の1周目（完了）
- 追従監視: 購読あり（web。subscribe_pr_activity + 定期チェックイン）

## フロー進捗状況

| 進捗 | flow-id | ステップ |
|---|---|---|
| [x] | 1-1 | issueを起票する |
| [x] | 1-2 | issueの内容を取得する |
| [x] | 1-3 | featureブランチとDraft PRを作成する |
| [x] | 1-4 | 全体作業計画を作成する |
| [] | 1-5 | 全体作業計画に合意する |
| [x] | 1-6 | 全体作業計画をもとにHANDOFF.mdを更新する |
| [x] | 2-1 | 個別調査計画を作成する |
| [] | 2-2 | commit / push してレビュー依頼 |
| [] | 2-3 | 調査計画をレビューする（人間） |
| [] | 2-4 | レビュー内容を取得し調査計画を修正する |
| [] | 2-5 | MR descriptionを更新する |
| [x] | 2-6 | 調査を実施する |
| [x] | 2-7 | commit / push してレビュー依頼 |
| [x] | 2-8 | 調査結果をレビューする（人間） |
| [x] | 2-9 | レビュー内容を取得し調査結果を修正する |
| [] | 2-10 | MR descriptionを更新する |
| [x] | 3-1 | 個別作業計画を作成する |
| [] | 3-2 | commit / push してレビュー依頼 |
| [] | 3-3 | 作業計画をレビューする（人間） |
| [] | 3-4 | レビュー内容を取得し作業計画を修正する |
| [] | 3-5 | MR descriptionを更新する |
| [x] | 3-6 | 作業を進める |
| [x] | 3-7 | commit / push してレビュー依頼 |
| [x] | 3-8 | 作業結果をレビューする（人間） |
| [x] | 3-9 | レビュー内容を取得し実装・ドキュメントを修正する |
| [] | 3-10 | MR descriptionを更新する |
| [x] | 4-1 | 個別反映計画を作成する |
| [] | 4-2 | commit / push してレビュー依頼 |
| [] | 4-3 | 反映計画をレビューする（人間） |
| [] | 4-4 | レビュー内容を取得し反映計画を修正する |
| [] | 4-5 | MR descriptionを更新する |
| [x] | 4-6 | 設計反映・AIアセット反映を進める |
| [x] | 4-7 | commit / push してレビュー依頼 |
| [x] | 4-8 | 反映結果をレビューする（人間） |
| [x] | 4-9 | レビュー内容を取得し設計・AIアセットを修正する |
| [] | 4-10 | MR descriptionを更新する |
| [] | 5-1 | defaultブランチとのコンフリクトを検知・解消する |
| [] | 5-2 | 関連issueへ通知する |
| [] | 5-3 | plans/ worklog/ reports/ を片付けHANDOFF.mdをリセットする |
| [] | 5-4 | commit / push してDraftを解除する |
| [] | 5-5 | マージする（人間） |

## やったこと

- issue #133 の内容を取得し、全体作業計画 `plans/ddr-identifier-issue-based.md` を作成した。
- 本ブランチは非対話的な実行環境（Claude Code on the web）で進めているため、人間のレビュー
  往復（flow-id 2-3/2-4, 2-8/2-9, 3-3/3-4, 3-8/3-9, 4-3/4-4, 4-8/4-9）は実施できない。
  該当ループ範囲の進捗記号は `[]` のまま残し、実施した内容はこのセクションへ文章で補足する
  （`.claude/rules/docs-workflow.md` の末尾の規定に従う）。
- flow-id 1-3: Draft PR #137 を作成した。
- flow-id 2-1/2-6: 個別調査計画を作り、調査を実施した。結果は
  `reports/2026-08-20_ddr-identifier-issue-based_調査結果.md`（正文）と同名の `.html`（視覚化）。
  新方式の識別子を `i<issue番号>-<枝番2桁>` に決め、4桁連番を前提にしている実装が
  `check-base-conflicts.sh` の1箇所だけであることを確認した。
- flow-id 3-1/3-6: 個別作業計画を作り、規約・スクリプト・単体テスト・スキル・DDR一覧を更新した。
  結果は `reports/2026-08-20_ddr-identifier-issue-based_作業結果.md`。
- flow-id 4-1/4-6: 反映対象を洗い出し（spec 1件・DDR 1件新規）、
  `.claude/docs/spec/check-base-conflicts.md` の更新と
  `.claude/docs/ddr/i133-01-DDR識別子はissue番号ベースにし連番採番をやめる.md` の新規作成を行った。
  AIアセット（`.claude/rules/` `.claude/skills/`）の改訂は本issueの成果物そのもののため、
  フェーズ3の作業として実施済み。
- 検証: 単体テスト全12件が `failures=0`（合計664アサーション。うち
  `test_check_base_conflicts.sh` は 13→28 アサーション）。`check-base-conflicts.sh --no-fetch` が
  `hasConflict=false`。`extract-frontmatter.sh` / `search-frontmatter.sh` から新DDRを引ける。

## 次にやること

- flow-id 5-1: defaultブランチとのコンフリクトを検知・解消する。
- flow-id 5-2: 関連issueへ通知する（承認が必要）。
- flow-id 5-3〜5-4: 片付け → commit / push → Draft解除。**マージは人間が行う。**

## 判断を迷った内容

- **`check-base-conflicts.sh` のJSON出力キー（`duplicateDdrNumbers` / `hasDuplicateDdrNumber`）を
  改名するか。** 値が「番号」ではなく「識別子」になるため名前は実態とずれるが、複数のスキル・
  specから参照される公開インターフェースであり、改名は「参照の追従漏れ」というこのissueが
  無くそうとしているリスクを自ら作る。**内部の純粋関数名だけを改名し、JSONキーは据え置く**と
  決めた（根拠は調査結果レポートの第5節）。
- **issue件数の食い違い。** issue #133 本文は既存DDRを「58件」「54件」と2通りに書いているが、
  実測は55件（0003〜0059、欠番4つ）。**実測を正**として記述している。
- **枝番の桁数を固定するか可変にするか。** `i133-1-` `i133-001-` のような揺れを許すと、同じDDRが
  二重に採番されうるため、**ちょうど2桁に固定**して揺れたものは「DDRではない」として弾く形にした。
- **`--help` の行番号直書き（`sed -n '2,30p'`）を直すかどうか。** 本issueの範囲外にも見えるが、
  今回のコメント追記で実際にヘルプが途中で切れたため、範囲指定ごと `awk` へ直した。

## 未解決の内容

- **`main` が1コミット進んでおり（behind=1）、そこで連番DDR `0060` が新規追加されている。**
  テキストコンフリクトもDDR識別子の重複も無い（`check-base-conflicts.sh` は `hasConflict=false`）
  が、`main` の取り込みには `.claude/rules/git-workflow.md` に従いユーザーの承認が要るため
  **未取得**。件数の直書きはこの1件で陳腐化するため、規約・spec・README側からは件数を外し、
  「一覧（`.claude/docs/README.md`）が正」とする形へ直した（DDR本文だけは作成時点の観測値として
  55件を残している）。
- **同一issueへの追加作業を2つのブランチで並行して行った場合、枝番（`i133-03` 等）はなお衝突しうる。**
  新方式でも消えない唯一の経路であり、`check-base-conflicts.sh` の検知と `resolve-conflict`
  スキルの類型A-2で受けている（改番して先へ進む前に、並行作業自体の是非を人間へ確認する）。
- 非対話的な実行環境のため、人間によるレビュー往復（2-3/2-4, 2-8/2-9, 3-3/3-4, 3-8/3-9,
  4-3/4-4, 4-8/4-9）は未実施。該当ループ範囲の進捗記号は `[]` のまま。

## 守るべき条件・触ってはいけない範囲

- **既存の連番DDR（0003〜0059）のファイル名・本文・他ファイルからの参照を変更しない。**
  リポジトリ全体に約107箇所ある番号参照は、今回の変更対象ではない。
- DDRの「本文は一度マージしたら変更しない」原則を守る（frontmatterのみ後から更新可）。
- spec / DDR の過去changelog（point-in-timeの記録）を書き換えない。
