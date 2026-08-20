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

- issue: #135 .claude/docs/README.md のDDR一覧を生成スクリプト化し、手書き更新をやめる
- ブランチ: claude/ddr-list-generation-script-58hl6j
- PR: #139 (Draft) https://github.com/yuki-matsu783/MR-driven-workflow/pull/139
- push回数: 3
- 現在のループ: なし（非対話セッションのためレビュー往復は未実施）
- 追従監視: あり（PR #139 のイベント購読 + 定期チェックイン。セッション終了で止まるため次セッションは resume で取り直す）

## フロー進捗状況

| 進捗 | flow-id | ステップ | 担当 |
|----|---|---|---|
| [x] | 1-1 | issueを起票する | 人間 |
| [x] | 1-2 | issueの内容を取得する | start |
| [x] | 1-3 | featureブランチとDraft MRを作成する | start |
| [x] | 1-4 | Planモードで全体作業計画を作成する | エージェント |
| [] | 1-5 | 全体作業計画に合意する | 人間 |
| [x] | 1-6 | 全体作業計画をもとにHANDOFF.mdを更新する | エージェント |
| [-] | 2-1 | 個別調査計画を作成する（worklogもここで作成） | エージェント |
| [-] | 2-2 | commit・pushしてレビュー依頼 | エージェント |
| [-] | 2-3 | MRで調査計画をレビュー | 人間 |
| [-] | 2-4 | レビュー内容を取得し調査計画を修正 | comments / reply |
| [-] | 2-5 | 調査計画をもとにMR descriptionを更新 | describe |
| [-] | 2-6 | 調査を実施しreports/へ記録 | エージェント |
| [-] | 2-7 | commit・pushしてレビュー依頼 | エージェント |
| [-] | 2-8 | MRで調査結果をレビュー | 人間 |
| [-] | 2-9 | レビュー内容を取得し調査結果を修正 | comments / reply |
| [-] | 2-10 | 調査結果をもとにMR descriptionを更新 | describe |
| [x] | 3-1 | 個別作業計画を作成する | エージェント |
| [x] | 3-2 | commit・pushしてレビュー依頼 | エージェント |
| [] | 3-3 | MRで作業計画をレビュー | 人間 |
| [] | 3-4 | レビュー内容を取得し作業計画を修正 | comments / reply |
| [] | 3-5 | 作業計画をもとにMR descriptionを更新 | describe |
| [] | 3-6 | 作業を実施しreports/へ記録 | エージェント |
| [] | 3-7 | commit・pushしてレビュー依頼 | エージェント |
| [] | 3-8 | MRでレビュー | 人間 |
| [] | 3-9 | レビュー内容を取得し実装・ドキュメントを修正 | comments / reply |
| [] | 3-10 | 作業内容をもとにMR descriptionを更新 | describe |
| [x] | 4-1 | 個別反映計画を作成する | エージェント |
| [] | 4-2 | commit・pushしてレビュー依頼 | エージェント |
| [] | 4-3 | MRで反映計画をレビュー | 人間 |
| [] | 4-4 | レビュー内容を取得し反映計画を修正 | comments / reply |
| [] | 4-5 | 反映計画をもとにMR descriptionを更新 | describe |
| [] | 4-6 | 設計反映・AIアセット反映を実施しreports/へ記録 | エージェント |
| [] | 4-7 | commit・pushしてレビュー依頼 | エージェント |
| [] | 4-8 | MRでレビュー | 人間 |
| [] | 4-9 | レビュー内容を取得し設計・AIアセットを修正 | comments / reply |
| [] | 4-10 | 反映内容をもとにMR descriptionを更新 | describe |
| [] | 5-1 | defaultブランチとのコンフリクトを検知・解消 | エージェント |
| [] | 5-2 | 関連issueへマージ前通知（承認必須） | エージェント |
| [] | 5-3 | plans/worklog/reportsを削除しHANDOFF.mdをリセット | エージェント |
| [] | 5-4 | commit・pushしてDraftを解除 | エージェント |
| [] | 5-5 | マージする（squash merge） | 人間 |

## やったこと

issue #135（DDR一覧の生成スクリプト化）を、**フェーズ3〈実装〉とフェーズ4〈反映〉を1パスで**実施した。

- `.claude/scripts/src/generate-ddr-list.sh` を新設（マーカー区間の置換・`--check`・`--print`）。
- `.claude/scripts/test/test_generate_ddr_list.sh` を新設（`passed=48 failures=0`）。既存の
  単体テスト12本も全て `failures=0` で退行なし。
- `.claude/docs/spec/generate-ddr-list.md`（仕様）・`.claude/docs/ddr/0061-…md`（意思決定・却下案6件）
  を追加。
- `.claude/rules/markdown-frontmatter.md`（`note` キー新設）・`.claude/rules/docs-workflow.md`
  （手書き禁止）・`.claude/skills/resolve-conflict/SKILL.md`（類型C→類型Bへ移動、検証手順追加）を更新。
- 実施結果の正文は `reports/20260820_ddr-list-generation_DDR一覧生成スクリプトの実装結果.md`。
- **DDR番号を 0060 → 0061 へ繰り下げた**（main側が先に0060を取ったため。類型Aのルールに従い
  main側の番号を正とした。参照8ファイルを更新し一覧を再生成）。
- **Draft PR #139 を作成した**（ユーザーからの明示指示による）。

**非対話セッションのため、人間のレビュー往復（3-3/3-4・3-6〜3-9・4-3/4-4・4-6〜4-9）は実施していない。**
ループ範囲の進捗記号は `[]` のまま残しているが、**3-6（作業実施）・3-7（commit/push）・
4-6（設計反映・AIアセット反映）に相当する作業自体は完了している**。
フェーズ2〈調査〉は、着手前の事前調査で個別作業計画を書くのに足りたため丸ごと省略した（`[-]`）。

## 次にやること

1. **人間によるレビュー**（PR #139）。
2. 申し送り事項（下記「判断を迷った内容」の0048の注記）の可否を決める。
3. **`origin/main` の取り込み**（`.claude/docs/README.md` がテキストコンフリクト中。ユーザー承認待ち）。
   解消は新しい手順（片側を採ってから `generate-ddr-list.sh` で再生成）で済む。
4. レビュー完了後、flow-id 5-1〜5-4（コンフリクト確認 → 関連issue通知 → 片付け → Draft解除）。

## 判断を迷った内容

- **0009のリンクを従来どおり `<>` 無しにするか、囲んで直すか。**
  受け入れ条件は「既存55件と等価」だが、従来の書き方はCommonMark上リンクとして成立しておらず
  （実測確認済み）、そのまま固定するのは害が大きいと判断して**直す方**を選んだ。
  結果、55行中この1行だけが手書き時代と異なる。
- **`0048` の `note` にある「DDR 0056 参照」は、内容から見て「0058」の誤りに見える**
  （フェーズ5の並べ替えを決めたのは0058）。等価性を優先して**文言は変更していない**。
  修正する場合は `0048-…md` の frontmatter の `note` を書き換えて再生成する（1行）。
- **`main` の取り込み（マージコミット `b0d3f57`）で `.claude/docs/README.md` がコンフリクトした。**
  監視モードの規則（類型A〜Dは承認を待たず解消）に従い、類型Bとして
  `git checkout --ours` → `generate-ddr-list.sh` の再生成で解消した。
  **どちら側を採るかは結果に影響しない**（一覧はDDRファイルの集合から決まるため）。
  マーカー外（spec一覧・由来の注記）が両側で変わっていないことを事前に確認したうえで `--ours` を使った。
  結果は57件で、main側の0060と本ブランチの0061がどちらも載っている。
- **`git diff --cached --name-only` は非ASCIIパスをクォート＋8進エスケープして返すため、
  そのまま `create-commit.sh` へ渡すと「gitが把握していません」で失敗する。**
  `-z` と `while IFS= read -r -d ''` で取り直す必要がある
  （`.claude/rules/shell-script-style.md` の既知の罠。`resolve-conflict` スキルの
  「想定される失敗と対処」表はこの点に触れていない）。
- 個別反映計画（`plans/【設計反映】…md`）は、反映作業と同じパスで作成した。フロー上は
  flow-id 4-1 が先だが、非対話セッションで往復を挟めないため一体で進めた。

## 未解決の内容

- **`--check` をCIから自動で呼ぶ仕組みは入れていない**（実行忘れの検出手段はあるが、
  強制はされない）。SessionStart hookでの警告等は spec の「未決定事項」に記載した。
- spec一覧（README上部）の生成は issue #135 のスコープ外のまま。

## 守るべき条件・触ってはいけない範囲

- **DDRの本文は変更しない。** `0022` / `0048` へ加えたのは frontmatter の `note` キーのみ。
- **`.claude/docs/README.md` のマーカー区間を手で編集しない**（次の生成で消える）。
  マーカー行 `<!-- BEGIN GENERATED: ddr-list -->` / `<!-- END GENERATED: ddr-list -->` 自体も消さない。
- **DDRを追加・変更したら `bash .claude/scripts/src/generate-ddr-list.sh` を実行し、
  差分を同じコミットへ含める。**
- 生成結果は **Git管理下のまま**にする（`.gitignore` へ加えない）。
