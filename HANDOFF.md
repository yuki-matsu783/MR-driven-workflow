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

- issue: #142
- ブランチ: `claude/docs-workflow-heading-rule-mi3krb`
- PR: #188（Draft, https://github.com/yuki-matsu783/MR-driven-workflow/pull/188 ）
- push回数: 6
- 現在のループ: 2-6〜2-9 の1周目（完了）
- 未返信スレッド: 0
- 追従監視: あり（`subscribe_pr_activity` でPR #188 を購読中。セッション終了で止まるため、次セッションは `resume` で取り直す）

| 進捗 | flow-id | ステップ | 担当 |
|---|---|---|---|
| [x] | 1-1 | issueを起票する | 人間 |
| [x] | 1-2 | issueの内容を取得する | サブコマンド |
| [x] | 1-3 | featureブランチとDraft MRを作成する | サブコマンド/エージェント |
| [x] | 1-4 | 全体作業計画を作成する | エージェント |
| [-] | 1-5 | 全体作業計画に合意する | 人間 |
| [x] | 1-6 | 全体作業計画をもとにHANDOFF.mdを更新する | エージェント |
| [x] | 2-1 | 個別調査計画を作成する | エージェント |
| [x] | 2-2 | commitしpushしてレビュー依頼 | エージェント |
| [x] | 2-3 | 調査計画をレビュー・コメント | 人間 |
| [x] | 2-4 | レビュー内容を取得し調査計画を修正 | サブコマンド |
| [x] | 2-5 | 調査計画をもとにMR descriptionを更新 | サブコマンド |
| [x] | 2-6 | 調査を実施しreportsへ記録 | エージェント |
| [x] | 2-7 | commitしpushしてレビュー依頼 | エージェント |
| [x] | 2-8 | 調査結果をレビュー・コメント | 人間 |
| [x] | 2-9 | レビュー内容を取得し調査結果を修正 | サブコマンド |
| [x] | 2-10 | 調査結果をもとにMR descriptionを更新 | サブコマンド |
| [x] | 3-1 | 個別作業計画を作成する | エージェント |
| [] | 3-2 | commitしpushしてレビュー依頼 | エージェント |
| [] | 3-3 | 作業計画をレビュー・コメント | 人間 |
| [] | 3-4 | レビュー内容を取得し作業計画を修正 | サブコマンド |
| [] | 3-5 | 作業計画をもとにMR descriptionを更新 | サブコマンド |
| [] | 3-6 | 作業を進めreportsへ記録 | エージェント |
| [] | 3-7 | commitしpushしてレビュー依頼 | エージェント |
| [] | 3-8 | レビュー・コメント | 人間 |
| [] | 3-9 | レビュー内容を取得し修正 | サブコマンド |
| [] | 3-10 | 作業内容をもとにMR descriptionを更新 | サブコマンド |
| [] | 4-1 | 個別反映計画を作成する | エージェント |
| [] | 4-2 | commitしpushしてレビュー依頼 | エージェント |
| [] | 4-3 | 反映計画をレビュー・コメント | 人間 |
| [] | 4-4 | レビュー内容を取得し反映計画を修正 | サブコマンド |
| [] | 4-5 | 反映計画をもとにMR descriptionを更新 | サブコマンド |
| [] | 4-6 | 反映作業を進めreportsへ記録 | エージェント |
| [] | 4-7 | commitしpushしてレビュー依頼 | エージェント |
| [] | 4-8 | レビュー・コメント | 人間 |
| [] | 4-9 | レビュー内容を取得し修正 | サブコマンド |
| [] | 4-10 | 反映内容をもとにMR descriptionを更新 | サブコマンド |
| [] | 5-1 | defaultブランチとのコンフリクト検知・解消 | エージェント |
| [] | 5-2 | 関連issueへのマージ前通知 | エージェント |
| [] | 5-3 | `.claude/` を `.gemini/` へ変換同期 | エージェント |
| [] | 5-4 | 最終統括レポートを作成しPRへ反映 | エージェント |
| [] | 5-5 | plans/worklog/reportsを削除しHANDOFF.mdをリセット | エージェント |
| [] | 5-6 | commitしpushしてDraft解除 | エージェント |
| [] | 5-7 | マージする | 人間 |

## やったこと

- flow-id 1-2: issue #142 の本文と、通知コメント2件（PR #139 由来・issue #155 由来）を取得した。
  同型の事故が **4件**（issue #64 / #109 / PR #139 / issue #155）あることを確認した。
- flow-id 1-3: ハーネス指定ブランチ `claude/docs-workflow-heading-rule-mi3krb` で Draft PR #188 を
  作成し、`subscribe_pr_activity` で追従監視を開始した。
- flow-id 1-4: 全体作業計画 `plans/brisk-weaving-lantern.md`（＋同名 `.html`）を作成した。
- flow-id 1-5 は `[-]`。**非対話的セッション**のため人間の合意を待てない。ユーザーからの指示
  「各フェーズの計画時に一度、作業実施ごとに一度、敵対的レビューを自動で行い、指摘に対する修正を
  行いながら進めること」をもって着手の合意とみなす。
- flow-id 2-1: 個別調査計画 `plans/【調査】残置テキストの係り先ルールの射程と重複を洗い出す.md`
  （＋`.html`）と worklog を作成した。
- flow-id 2-2: commit・push（push 1）。HANDOFF.mdのヘッダ更新で push 2。
- flow-id 2-3〜2-4（1周目、敵対的レビューで代替）: 計画に対する敵対的レビューを実施し、
  **7件をインライン投稿・2件を報告のみ**とした。7件すべてへ対応し返信済み（未返信スレッド 0）。
  - 投稿したスレッド:
    - https://github.com/yuki-matsu783/MR-driven-workflow/pull/188#discussion_r3838550549 （md/html非同期）
    - https://github.com/yuki-matsu783/MR-driven-workflow/pull/188#discussion_r3838551127 （#109の壊れた位置の軸が食い違い）
    - https://github.com/yuki-matsu783/MR-driven-workflow/pull/188#discussion_r3838551519 （Q2が`.gemini/`を数える）
    - https://github.com/yuki-matsu783/MR-driven-workflow/pull/188#discussion_r3838551929 （検証が1実例・1ファイル）
    - https://github.com/yuki-matsu783/MR-driven-workflow/pull/188#discussion_r3838552346 （Q3の循環依存）
    - https://github.com/yuki-matsu783/MR-driven-workflow/pull/188#discussion_r3838552762 （Q4が識別子だけで判定）
    - https://github.com/yuki-matsu783/MR-driven-workflow/pull/188#discussion_r3838553202 （合格条件が空振り）
  - 報告のみの2件（`.gemini/`が変更対象に無い／前提にflow-idが無い）も、あわせて計画へ反映した。
  - 敵対的レビューの実施回数: フェーズ2は 1/3。
- flow-id 2-5: MR description を `mcp__github__update_pull_request` で更新した。
- flow-id 2-6: Q1〜Q5 の調査を実施し、`reports/20260823_brisk-weaving-lantern_係り先ルールの射程調査.md`
  （＋`.html`）へ記録した。主な結論:
  - **Q5: `.claude/rules/` は敵対的レビューへ渡らない**（`collect-review-points.sh` は `REVIEW-POINTS.md` /
    `REVIEW-POINTS.local.md` しか集めない）。規約だけに書いても、4件を検出してきた唯一の経路には届かない。
    → ルート `REVIEW-POINTS.md` の観点も一般化する。
  - **Q3: 暫定案の「構造変更全般」では issue #155 を取りこぼす。** 発動条件を操作の側ではなく
    **残置テキストの側**（既存の記述を残したまま、その周囲を編集したとき）で書く。
  - **Q4: 追記先になりうる既存DDRは0件** → フェーズ4で新規DDRを作る。
  - 検証コマンドの空振り確認済み（実例を1つずつ削ると、それぞれ `1` を返す）。

- flow-id 2-7: commit・push（push 5）。
- flow-id 2-8〜2-9（1周目、敵対的レビューで代替）: 調査結果に対する敵対的レビューを実施し、
  **9件をインライン投稿・2件を報告のみ**とした。9件すべてへ対応し返信済み（未返信スレッド 0）。
  - 投稿したスレッド:
    - https://github.com/yuki-matsu783/MR-driven-workflow/pull/188#discussion_r3838691487 （「4件とも敵対的レビューが検出」は事実でない）
    - https://github.com/yuki-matsu783/MR-driven-workflow/pull/188#discussion_r3838691867 （検証のpathspecがルート`REVIEW-POINTS.md`を含まない）
    - https://github.com/yuki-matsu783/MR-driven-workflow/pull/188#discussion_r3838692381 （Q3が暫定案5項目ではなく合成した1文を判定）
    - https://github.com/yuki-matsu783/MR-driven-workflow/pull/188#discussion_r3838692836 （Q2の`# → 2`が実際の出力`4`と不一致）
    - https://github.com/yuki-matsu783/MR-driven-workflow/pull/188#discussion_r3838693250 （Q4が3語のうち「構造」を欠く）
    - https://github.com/yuki-matsu783/MR-driven-workflow/pull/188#discussion_r3838693641 （#155を外す理由が採用案と数で矛盾）
    - https://github.com/yuki-matsu783/MR-driven-workflow/pull/188#discussion_r3838694143 （空振り確認が1行のみ・判定語が非特異）
    - https://github.com/yuki-matsu783/MR-driven-workflow/pull/188#discussion_r3838694493 （基準SHAが未記録で断面を再現できない）
    - https://github.com/yuki-matsu783/MR-driven-workflow/pull/188#discussion_r3838694884 （レポートのmd/htmlが非同期）
  - 報告のみの2件（Q2とQ5の緊張関係／4件の出典が無い）も、あわせて調査結果へ反映した。
  - 敵対的レビューの実施回数: フェーズ2は 2/3。
  - この往復で**結論が1つ変わった**。Q3の判定を暫定案5項目へ逐条で当て直した結果、
    **穴は項目1（「構造変更全般」という言い換え自体が操作の分類である）** だと分かった。
    フェーズ3では**トリガーを残置テキスト側から書く**。

- flow-id 2-10: MR description を更新した（調査で確定した Q1〜Q5 の結論と、
  「構造変更全般では #155 を取りこぼす」という最大の発見を反映）。
- flow-id 3-1: 個別作業計画 `plans/【AIアセット作成】残置テキストの係り先ルールを一般化する.md`
  （＋`.html`）を作成した。書き換え先2箇所を A（規約・正）／B（観点表・敵対的レビューが読む唯一の経路）
  として分け、**Bをポインタで済ませない**ことを明記した。
  **A-4 として「この書き換えで自分が PR #139 と同じ罠を踏まない」条件**（直後の `HANDOFF.md` の
  段落を新しい見出しの配下へ入れない）を計画へ入れている。

## 次にやること

- flow-id 3-2: commit・push し、個別作業計画に対する敵対的レビュー（フェーズ3の1回目）を実施する。
- その後 flow-id 3-6 で書き換えを実施する。書き換え先は
  `.claude/rules/docs-workflow.md`（104〜114行）とルート `REVIEW-POINTS.md`（47〜48行）の2箇所。

## 判断を迷った内容

- **ブランチ名がリポジトリの命名規則（`feature-<issue番号>-<slug>`）と異なる。** ハーネスが
  `claude/docs-workflow-heading-rule-mi3krb` を指定しており、他ブランチへのプッシュを禁じているため、
  ハーネスの指定を優先した。
- **flow-id 1-5（人間の合意）の扱い。** 非対話的セッションでは待てないため `[-]`（今回は実施しない）と
  した。人間のレビュー往復（2-3/2-4・2-8/2-9・3-3/3-4・3-8/3-9・4-3/4-4・4-8/4-9）は、ユーザーの指示に
  従い敵対的レビューで代替する。**代替したループ範囲の記号は `[]` のまま残す**
  （`.claude/rules/docs-workflow.md`「非対話的実行環境で人間担当のレビュー待ちステップを省略する場合」）。

## 未解決の内容

- （無し）

## 守るべき条件・触ってはいけない範囲

- **issue #64 由来の既存の実例2件を消さない**（受け入れ条件。`計画の2階層構造` の位置の話と、
  「同じ節名でもファイルごとに結論が変わる」話）。
- **ルールの適用対象を、操作の種類の列挙で書かない**（issue #155 の3例目が、列挙した4操作の
  どれにも入らなかったため）。
- マージ（flow-id 5-7）は行わない。AIエージェントは flow-id 5-6 で止まる。
