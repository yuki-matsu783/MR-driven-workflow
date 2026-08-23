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

- issue: #184 `.claude\state`はwipディレクトリで管理する
- ブランチ: claude/state-wip-directory-xj93sb
- PR: #190（Draft） https://github.com/yuki-matsu783/MR-driven-workflow/pull/190
- push回数: 2
- 現在のループ: 3-6〜3-9 の1周目（進行中）
- 未返信スレッド: 0
- 追従監視: 購読あり（subscribe_pr_activity / PR #190）＋ 定期チェックイン

| 進捗 | flow-id | ステップ |
|---|---|---|
| [x] | 1-1 | issueを起票する |
| [x] | 1-2 | issueの内容を取得する |
| [x] | 1-3 | featureブランチとDraft MRを作成する |
| [x] | 1-4 | 全体作業計画を作成する |
| [] | 1-5 | 全体作業計画に合意する |
| [x] | 1-6 | 全体作業計画をもとにHANDOFF.mdを更新する |
| [-] | 2-1 | 個別調査計画を作成する |
| [-] | 2-2 | commit・push してレビュー依頼 |
| [-] | 2-3 | 調査計画をレビュー・コメントする |
| [-] | 2-4 | レビュー内容を取得し調査計画を修正する |
| [-] | 2-5 | 調査計画をもとにMR descriptionを更新する |
| [-] | 2-6 | 調査を実施し結果をreports/へ記録する |
| [-] | 2-7 | commit・push してレビュー依頼 |
| [-] | 2-8 | 調査結果をレビュー・コメントする |
| [-] | 2-9 | レビュー内容を取得し調査結果を修正する |
| [-] | 2-10 | 調査結果をもとにMR descriptionを更新する |
| [x] | 3-1 | 個別作業計画を作成する |
| [x] | 3-2 | commit・push してレビュー依頼 |
| [] | 3-3 | 作業計画をレビュー・コメントする |
| [] | 3-4 | レビュー内容を取得し作業計画を修正する |
| [-] | 3-5 | 作業計画をもとにMR descriptionを更新する |
| [] | 3-6 | 作業を実施し結果をreports/へ記録する |
| [] | 3-7 | commit・push してレビュー依頼 |
| [] | 3-8 | 作業内容をレビュー・コメントする |
| [] | 3-9 | レビュー内容を取得し実装・ドキュメントを修正する |
| [] | 3-10 | 作業内容をもとにMR descriptionを更新する |
| [] | 4-1 | 個別反映計画を作成する（反映対象の洗い出し） |
| [] | 4-2 | commit・push してレビュー依頼 |
| [] | 4-3 | 反映計画をレビュー・コメントする |
| [] | 4-4 | レビュー内容を取得し反映計画を修正する |
| [] | 4-5 | 反映計画をもとにMR descriptionを更新する |
| [] | 4-6 | 設計反映・AIアセット反映・実装反映を実施する |
| [] | 4-7 | commit・push してレビュー依頼 |
| [] | 4-8 | 反映内容をレビュー・コメントする |
| [] | 4-9 | レビュー内容を取得し設計・AIアセットを修正する |
| [] | 4-10 | 反映内容をもとにMR descriptionを更新する |
| [] | 5-1 | defaultブランチとのコンフリクトを検知・解消する |
| [] | 5-2 | 関連issueへマージ前通知を行う |
| [] | 5-3 | .claude/ を .gemini/ へ変換同期する |
| [] | 5-4 | 最終統括レポートを作成しPRへ反映する |
| [] | 5-5 | plans/ worklog/ reports/ を片付けHANDOFF.mdをリセットする |
| [] | 5-6 | commit・push してDraftを解除する |
| [] | 5-7 | マージする（人間） |

## やったこと

- flow-id 1-2: issue #184 をMCP（`mcp__github__issue_read`）で取得した。この実行環境には
  `gh`/`glab` CLIが無いため、`references/mcp-fallback.md` に従いMCP経路を使っている。
- **issue #184 は本文が空だった**（タイトルと、マージ前通知のコメント1件のみ）。着手前に
  `AskUserQuestion` で次の2点を確認し、回答を全体作業計画の前提として固定した。
  - 「wipディレクトリ」の位置 → **ルート直下 `wip/state/`**（#165 が新設予定の `wip/` を先に作る）
  - 移動対象の範囲 → **`.claude/state/` のみ**（`usage/` は対象外）
- flow-id 1-4: 全体作業計画 `plans/wispy-drifting-lantern.md` と同名の `.html` を作成した。
- flow-id 1-3: Draft PR #190 を作成し、`subscribe_pr_activity` で追従監視を開始した。
- flow-id 2-x: フェーズ2〈調査〉は実施しないと判断した（`[-]`）。
- flow-id 3-1: 個別作業計画 `plans/【実装】【テスト】stateの保存先をwip-stateへ移す.md`（＋`.html`）と
  worklog（push2）を作成した。
- flow-id 3-6: 保存先パスの置き換えを実施した。実装5ファイル（`.gitignore` /
  `dist-layers.json` / `post-push-compact-prompt.sh` / `adversarial-review-count.sh` /
  `sync-gemini-assets.sh`）とテスト3ファイル。検証は
  `check-dist-coverage.sh`「結果: OK」、単体テスト3本すべて `failures=0`（22 / 91 / 99 件）、
  `git check-ignore -v wip/state/.probe` が `/wip/state/` にマッチ。結果は
  `reports/20260823_wispy-drifting-lantern_stateのwip-stateへの移設.md`（＋`.html`）。
  - **作業中に、旧パス `/.claude/state/` の除外行を残す必要があると分かった**（差し替えるだけだと
    既存の残骸が `git status` に現れ、誤ってコミットされる）。計画・レポート・worklogへ反映済み。

## 次にやること

- flow-id 4-1 以降: 反映対象を洗い出し、rules・spec 4本の更新とDDR `i0184-01` の新規作成を行う。
- flow-id 5-3: `.gemini/` の変換同期（`.claude/` 側を変更したため必須）。

## 判断を迷った内容

- **フェーズ2〈調査〉を実施しないと判断した**（全体作業計画の「フェーズ2〈調査〉」節に理由を記載）。
  `.claude/state` の全出現箇所と、そのうちどれが「現在の状態の説明」でどれが「過去changelog／
  DDR本文」かは着手前の確認で判別済みであり、調べる問いが残っていないため。
- **ブランチ名がこのリポジトリの命名規則（`feature-<issue番号>-<slug>`）に従っていない。**
  実行基盤（ハーネス）が `claude/state-wip-directory-xj93sb` を指定しており、他ブランチへの
  pushを禁じているため、そちらを優先した。

## 未解決の内容

- **人間のレビュー往復（flow-id 1-5・2-3/2-4・3-3/3-4・3-8/3-9・4-3/4-4・4-8/4-9）は、この
  セッションでは実施できない。** 該当ループ範囲の進捗記号は `[]` のまま残し、実際に行った作業は
  本ファイルの「やったこと」で補足する（`.claude/rules/docs-workflow.md`「非対話的実行環境」）。

## 守るべき条件・触ってはいけない範囲

- **DDR本文と、spec内の過去changelog（point-in-timeの記録として書かれた節）は書き換えない。**
  一括 `sed` を使わず、現在の状態を説明する節だけを個別に直す
  （`.claude/rules/docs-workflow.md`）。既存DDR `i0013-01` `i0039-01` は旧パス表記のまま残す。
- **`.gemini/` は直接編集しない。** `.claude/` からの変換生成物であり、flow-id 5-3 で
  `bash .claude/scripts/src/sync-gemini-assets.sh` を流して追随させる。
- **`usage/` と、`plans/` `worklog/` `reports/` の移動は本issueの範囲外**（前者はユーザー確認で
  対象外、後者は #165 の担当）。
