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

- issue: #176
- ブランチ: `claude/reflection-plan-criteria-tnhfvs`
- PR: #196（Draft・https://github.com/yuki-matsu783/MR-driven-workflow/pull/196 ）
- push回数: 4
- 現在のループ: 2-6〜2-9 の1周目（進行中）
- 未返信スレッド: 8
- 追従監視: あり（PRイベント購読 + 定期チェックイン。Claude Code on the web セッション）

| 進捗 | flow-id | ステップ | 担当 |
|---|---|---|---|
| [x] | 1-1 | issueを起票する | 人間 |
| [x] | 1-2 | issueの内容を取得する | `start` |
| [x] | 1-3 | featureブランチとDraft MRを作成する | `start`（エージェント） |
| [x] | 1-4 | 全体作業計画を作成する | エージェント |
| [] | 1-5 | 全体作業計画に合意する | 人間 |
| [x] | 1-6 | 全体作業計画をもとにHANDOFF.mdを更新する | エージェント |
| [x] | 2-1 | 個別調査計画を作成する | エージェント |
| [x] | 2-2 | commitし、pushしてレビュー依頼を行う | エージェント |
| [x] | 2-3 | MRで調査計画についてレビュー・コメントする | 人間 |
| [x] | 2-4 | レビュー内容を取得し、調査計画を修正する | `comments` / `reply` |
| [x] | 2-5 | 調査計画をもとにMR descriptionを更新する | `describe` |
| [] | 2-6 | 調査を実施し、結果を記録する | エージェント |
| [] | 2-7 | commitし、pushしてレビュー依頼を行う | エージェント |
| [] | 2-8 | MRで調査結果についてレビュー・コメントする | 人間 |
| [] | 2-9 | レビュー内容を取得し、調査結果を修正する | `comments` / `reply` |
| [] | 2-10 | 調査結果をもとにMR descriptionを更新する | `describe` |
| [] | 3-1 | 個別作業計画を作成する | エージェント |
| [] | 3-2 | commitし、pushしてレビュー依頼を行う | エージェント |
| [] | 3-3 | MRで作業計画についてレビュー・コメントする | 人間 |
| [] | 3-4 | レビュー内容を取得し、作業計画を修正する | `comments` / `reply` |
| [] | 3-5 | 作業計画をもとにMR descriptionを更新する | `describe` |
| [] | 3-6 | 作業計画をもとに作業を進める | エージェント |
| [] | 3-7 | commitし、pushしてレビュー依頼を行う | エージェント |
| [] | 3-8 | MRでレビュー・コメントする | 人間 |
| [] | 3-9 | レビュー内容を取得し、実装・ドキュメントを修正する | `comments` / `reply` |
| [] | 3-10 | 作業内容をもとにMR descriptionを更新する | `describe` |
| [] | 4-1 | 個別反映計画を作成する | エージェント |
| [] | 4-2 | commitし、pushしてレビュー依頼を行う | エージェント |
| [] | 4-3 | MRで反映計画についてレビュー・コメントする | 人間 |
| [] | 4-4 | レビュー内容を取得し、反映計画を修正する | `comments` / `reply` |
| [] | 4-5 | 反映計画をもとにMR descriptionを更新する | `describe` |
| [] | 4-6 | 反映計画をもとに作業を進める | エージェント |
| [] | 4-7 | commitし、pushしてレビュー依頼を行う | エージェント |
| [] | 4-8 | MRでレビュー・コメントする | 人間 |
| [] | 4-9 | レビュー内容を取得し、設計・AIアセットの内容を修正する | `comments` / `reply` |
| [] | 4-10 | 反映内容をもとにMR descriptionを更新する | `describe` |
| [] | 5-1 | defaultブランチとのコンフリクトを検知し、あれば解消する | エージェント |
| [] | 5-2 | 関連issueへマージ前通知を行う | エージェント |
| [] | 5-3 | `.claude/` の変更を `.gemini/` へ変換同期する | エージェント |
| [] | 5-4 | 最終統括レポートを作成しPR/MRへ反映する | エージェント |
| [] | 5-5 | 次タスクのための片付けとHANDOFF.mdリセット | エージェント |
| [] | 5-6 | commitし、pushしてDraftを解除する | エージェント |
| [] | 5-7 | マージする | 人間 |

## やったこと

- flow-id 1-2: issue #176 の本文とコメント1件（issue #155 / PR #175 からの前提変更通知）を取得した。
- flow-id 1-3: ブランチ `claude/reflection-plan-criteria-tnhfvs` をリモートへ反映し、Draft PR #196 を作成した。PRイベントの購読を開始した。
- flow-id 1-4: 全体作業計画 `wip/plans/reflection-split-criteria.md`（＋同名 `.html`）を作成した。フェーズ2〈調査〉・フェーズ4〈反映〉の節を含む。
- flow-id 1-6: 本ファイルへ進捗表・ヘッダを記入した。
- flow-id 2-1: 個別調査計画 `wip/plans/【調査】反映対象の切り出し判断基準.md`（＋`.html`）と worklog `wip/worklogs/20260823_reflection-split-criteria_【調査】反映対象の切り出し判断基準_push2.md` を作成した。調べる問いは6問。
- **敵対的レビュー（フェーズ2・1/3回目）**: `wip/plans/` の計画2本＋HTMLビュー＋`HANDOFF.md` を対象に実施。指摘12件。振り分け表を通った6件をPR #196 へインライン投稿し、残り6件（minor/medium）はレビュー本文へ記載。投稿スレッド: [#1](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#discussion_r3839433337) / [#2](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#discussion_r3839433850) / [#3](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#discussion_r3839434276) / [#4](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#discussion_r3839434773) / [#5](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#discussion_r3839435180) / [#6](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#discussion_r3839435574)
- flow-id 2-3〜2-4（1周目・完了）: 12件すべてに対応し、6スレッドへ返信・報告のみ6件は[まとめコメント](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#issuecomment-5388152010)で返した。主な修正は (a) 背景の「切り出しに触れているのは1文だけ」を実測10行・うち基準を指すのは3箇所へ訂正し、うち2箇所は別の判定（issue粒度）としてスコープ外に明示、(b) 置換前後の形をmd正文へ移し md↔HTML を11節で同期、(c) status確認のjqの空振り（`.status` → `.frontmatter.status`）を修正、(d) Q4から主判定の文言を外し自己追認を回避、(e) 検証を受け入れ条件ごとの grep へ変えベースラインを実測（0/1/失敗/0）。

- flow-id 2-6: 6問の調査を実施し、結果を `wip/reports/2026-08-23_reflection-split-criteria_調査結果.md`（＋`.html`）へ書いた。
- **敵対的レビュー（フェーズ2・2/3回目）**: flow-id 2-6 の調査結果（md＋html）と worklog を対象に実施。指摘11件。振り分け表と `select-adversarial-findings.sh` を通った8件をPR #196 へインライン投稿し、残り3件（minor/medium）はレビュー本文へ記載。**11件すべてを自分のコマンドで裏取りし、全件が正しい指摘であることを確認した。** 投稿スレッド: [#1](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#discussion_r3839506738) / [#2](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#discussion_r3839507173) / [#3](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#discussion_r3839507632) / [#4](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#discussion_r3839508118) / [#5](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#discussion_r3839508430) / [#6](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#discussion_r3839508784) / [#7](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#discussion_r3839509229) / [#8](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#discussion_r3839509552)
- flow-id 2-6（修正後）: **Q4 の母数の作り方に誤りがあり、作り直した。** `grep -rln -- '別issue'` が `個別issue` にも一致していたため2件が偽陽性で混入しており、**その2件がちょうど「時期尚早」類型のすべてだった**。除外を3段階（E1 部分一致／E2 語の用法／E3 判断の性質）へ明示し **13件→7件**とした。結果は **7/7 で一致、No の理由は3種（規模2・スコープ2・価値2）**。あわせて**対案（規模基準）を同じ母数へ当てて 3/7** という比較を追加し、母数の偏り・`status`/`note` の実測・出口(3)の起票主体の制約・測定時点のスナップショットを記録した。

## 次にやること

- flow-id 2-9: 投稿した8スレッドへ返信し、報告のみ3件をまとめコメントで返す。その後 `set-header --unreplied 0` → ループ範囲 2-6〜2-9 を `mark-done`。
- flow-id 2-10: 調査結果をもとにMR descriptionを更新する。
- flow-id 3-1: 個別作業計画 `wip/plans/【AIアセット作成】…` を作成する。フェーズ3で決めることは5件（主判定の文面／No のときの3つの出口／`【AIアセット反映】` 側から指す文面／flow-id 4-6 の参照列／#64 節との相互参照の1行）。

## 判断を迷った内容

- **flow-id 1-5（人間による全体作業計画の合意）は非対話セッションのため成立しない。** 進捗記号は `[]` のまま残し、代わりに敵対的レビューでレビューの空白を埋める（`.claude/rules/docs-workflow.md`「非対話的実行環境」）。
- **受け入れ条件の「SKILL.md に節がある」の解釈。** issue #160 で SKILL.md の詳細節は `references/` 配下へ切り出されているため、そのまま SKILL.md 本体へ書くと構造に反する。フェーズ2の問い1で結論を出す。
- **敵対的レビューの指摘1（切り出しに触れる箇所が3つある）への対応方針。** 3箇所のうち2箇所（`SKILL.md:76`・`references/planning.md:246`）は**判定している対象が違う**（issueそのものの粒度）ため、新節へ寄せず #64 のままにした。相互参照の1行を置くことで読み手の迷いを消す方針を採ったが、これが十分かはフェーズ3のレビューで再確認する。

## 未解決の内容

- **Q4 の母数に構造的な偏りがある。** 母数は「切り出し・見送りに言及したDDR」であり、**偽陰性（切り出すべきだったのに切り出されなかった事例）は原理的に見えない**。7/7 は上限の推定であって「基準が実証された」とは読めない。MRのレビュー往復まで遡っていない点も同じ。調査結果の「確かめられなかったこと」に明記済み。
- **出口(1)「このMRでやる（極小）」は本調査では裏付けられていない。** 母数が見送り事例に偏っているため。issue #64 節からの引き継ぎとして扱う。
- **`grep` の部分一致で母数を作る罠が `.claude/rules/shell-script-style.md` に無い。** `--` の付け忘れ（先頭ハイフン）は書かれているが、`別issue` ⊂ `個別issue` のような部分一致そのものは扱われていない。フェーズ4の `【AIアセット反映】` 候補。
- **flow-id 4-6 の参照列に `references/planning.md` を足すか未定。** 読み込み量のトレードオフがあり、フェーズ3で判断する。

## 守るべき条件・触ってはいけない範囲

- ブランチは `claude/reflection-plan-criteria-tnhfvs` 固定（ハーネス指定。`.mrworkflow.json` の
  `feature-<issue番号>-<slug>` 規則とは異なるが、ハーネス側の指定を優先する）。
- DDR本文・spec内の過去changelog（point-in-time の記録）は書き換えない。特に `i0064-01:25`・`i0092-01:52` の「5フェーズ40ステップ」は当時の値であり、43へ書き換えない。
- **planツールを使えない実行環境のため、全体作業計画は Write で作成しファイル名は内容から付けた**（`wip/plans/REVIEW-POINTS.md` の「ハーネスの提示した自動命名のまま」からの逸脱）。worklog・reports のファイル名もこの名前に揃えてある。
- `SKILL.md:76`（flow-id 2-6）の切り出し記述は変更しない（issue粒度の判定であり issue #64 の担当）。
- **調査結果の行番号はコミット `90477a2` 時点のもの**で、フェーズ3で `references/planning.md` に新節を足すと必ずずれる。後から参照するときは見出し名で辿る（レポート冒頭に明記済み）。
- **worklog は push 5 以降、規則どおり `_push<N>.md` で分ける。** `_push2.md` は push 2〜4 をまとめて記録しており、その逸脱は当該ファイルの冒頭に明記した。
