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
- push回数: 11
- 現在のループ: なし
- 未返信スレッド: 9
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
| [x] | 2-6 | 調査を実施し、結果を記録する | エージェント |
| [x] | 2-7 | commitし、pushしてレビュー依頼を行う | エージェント |
| [x] | 2-8 | MRで調査結果についてレビュー・コメントする | 人間 |
| [x] | 2-9 | レビュー内容を取得し、調査結果を修正する | `comments` / `reply` |
| [x] | 2-10 | 調査結果をもとにMR descriptionを更新する | `describe` |
| [x] | 3-1 | 個別作業計画を作成する | エージェント |
| [x] | 3-2 | commitし、pushしてレビュー依頼を行う | エージェント |
| [x] | 3-3 | MRで作業計画についてレビュー・コメントする | 人間 |
| [x] | 3-4 | レビュー内容を取得し、作業計画を修正する | `comments` / `reply` |
| [x] | 3-5 | 作業計画をもとにMR descriptionを更新する | `describe` |
| [x] | 3-6 | 作業計画をもとに作業を進める | エージェント |
| [x] | 3-7 | commitし、pushしてレビュー依頼を行う | エージェント |
| [x] | 3-8 | MRでレビュー・コメントする | 人間 |
| [x] | 3-9 | レビュー内容を取得し、実装・ドキュメントを修正する | `comments` / `reply` |
| [x] | 3-10 | 作業内容をもとにMR descriptionを更新する | `describe` |
| [x] | 4-1 | 個別反映計画を作成する | エージェント |
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
- flow-id 2-6（修正後）: **Q4 の母数の作り方に誤りがあり、作り直した。** `grep -rln -- '別issue'` が `個別issue` にも一致していたため2件が偽陽性で混入しており、**その2件がちょうど「時期尚早」類型のすべてだった**。除外を3段階（E1 部分一致／E2 語の用法／E3 判断の性質）へ明示し **13件→7件**とした。結果は **7/7 で一致、No の理由は3種（規模2・スコープ2・価値2）**。あわせて**対案（規模基準）を同じ母数へ当てて 3/7** という比較を追加し、母数の偏り・`status`/`note` の実測・出口「別issueへ切り出す」の起票主体の制約・測定時点のスナップショットを記録した。

- flow-id 2-9: 投稿した8スレッドすべてへ返信し、報告のみ3件は[まとめコメント](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#issuecomment-5388329188)で返した。
- flow-id 2-10: 調査結果をもとにMR description を全文更新した（Q1〜Q6 の結論・基準の欠落・敵対的レビュー2回分の記録・確かめられなかったこと）。

- flow-id 3-1: 個別作業計画 `wip/plans/【AIアセット作成】反映対象の切り出し判断基準の新節.md`（＋`.html`）と worklog（push6）を作成した。**変更対象は6箇所**（`references/planning.md` 4箇所・`SKILL.md` 2箇所）。**主判定の文言はこの計画では確定させず、候補A（`main` の整合性・7/7）と候補B（規模・3/7）を持ち込んで 3-6 で決める形にした**（計画側で固定すると 3-6 が自分の文言を追認するため）。あわせて **flow-id 4-1 の参照列は既に `references/planning.md` を含む**ことを実測し、残課題4は「4-6 の参照列は触らず、行の本文へ1行足す」で決着させた。

- **敵対的レビュー（フェーズ3・1/3回目）**: flow-id 3-1 の個別作業計画（md＋html）を対象に実施。指摘13件。9件をPR #196 へインライン投稿し、4件（minor/medium）はレビュー本文へ。**13件すべてを自分のコマンドで裏取りし、全件が正しい指摘であることを確認した。**
- flow-id 3-1（修正後）: **計画に書いた4本の検証のうち、機能していたのは1本だけだった。** 主な修正は (a) 検証4が新節の見出し行を範囲に含むため対象3を忘れても合格する空振りだった（`head -n -1` を追加）、(b) 「置換前・置換後」の節に**置換後の文が無かった**ので書いた、(c) 置換対象を行範囲 `92-94` から**文単位**へ変えた（92行目の前半は別の文の末尾だった）、(d) 全体作業計画が「個別作業計画へ記録する」と指示していた実測3本を記録し、独自の4本との関係を明記、(e) **新節の見出し名を計画で確定**（検証3本が依存するため）、(f) 対象4の挿入位置を手順2末尾→**手順4末尾**へ（手順2末尾は条件付きの地の文の直後）、(g) `SKILL.md` 本文へ `|` を混入させない制約と事後確認（追5）を追加。
- **フェーズ2の調査結果 Q5 も訂正した。** 複製箇所を `grep -rn -- '5フェーズ'` で数えて6箇所としていたが、「5フェーズ」を伴わない2箇所（`start-resume.md:107`・`usecase/途中の作業を再開・引き継ぐ.md:24`）を取りこぼしており、正しくは**8箇所**。md・html の両方を直した。

- flow-id 3-4: 投稿した9スレッドすべてへ返信し、報告のみ4件は[まとめコメント](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#issuecomment-5388474691)で返した。
- flow-id 3-5: 作業計画をもとにMR description を全文更新した（変更6箇所の表・新節の構造・敵対的レビュー3回分の記録・Q5 の 6→8 箇所の訂正）。
- flow-id 3-9: 投稿した13スレッドすべてへ返信し、報告のみ2件は[まとめコメント](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#issuecomment-5389288497)で返した（報告のみの2件も対応済み）。
- flow-id 3-10: 作業内容をもとにMR description を全文更新した（変更6箇所・新節の構造と出口の判定順・検証11本の実測・敵対的レビュー4回分・同型不具合4回の内訳）。**フェーズ3完了。**

- flow-id 4-1: 個別反映計画 `wip/plans/【設計反映】切り出し判断基準の記録.md`（＋`.html`）と worklog（push10）を作成した。**フェーズ3で作った新節の主判定を、このMR自身の反映対象10件へ初めて適用した。**
- **ユーザーから2点の変更指示が入り、新節と判定をやり直した。** (1) 非対話セッションでも止めて入力を待つ（出口(1) の退避経路を廃止）、(2) あまり止まらないよう「大きくて今回のissueとは関連しないものだけ」切り出す（出口(1) の条件を **OR から AND** へ）。**2つは対になっている**——止まる場所を作る代わりに、止まる条件を絞る。
- **痕跡の確認もやり直した。** 前回の段階2は `grep` の対象を `.claude/docs` `.claude/rules` に限っており、**4つの `REVIEW-POINTS.md` を含めていなかった**（フェーズ4の敵対的レビューの指摘）。範囲を広げて全件やり直した結果、**10件のうち4件（#5・#6・#8・#10）で類型が変わった**。#4・#7 は段階1（再現性1回のみ）で打ち切り、#6 は既に2箇所へ記述があり対象外。
- **判定結果: 反映対象 7件。主判定 Yes 2件（DDR・spec）/ No 5件。No の5件はすべて出口(3)「このMRでやる」に当たり、出口(1) は0件。したがってこのフェーズでは止まらない。** 変更前の OR 条件なら5件すべてが「スコープが外」の片方だけで (1) に落ち、**人間の応答を待って5回止まる**ところだった。AND 条件の効果がそのまま出た形である。
- **`.claude/VERSION` を `0.4.0` → `0.5.0`（MINOR）へ上げると判定した**（配布対象アセットの機能追加・後方互換を壊さない）。版の決定は本来人間が行うため、根拠を spec の changelog と本ファイルの「判断を迷った内容」へ記録し、レビューで否とされたら戻す。

- flow-id 3-6: **変更対象6箇所すべてを適用した。** `references/planning.md` へ新節「反映対象をこのMRでやるか切り出すかの判断（issue #176）」（69行・5見出し）を追加し、`【実装反映】` 定義の参照差し替え・#64 節への相互参照・手順4 末尾への接続・`SKILL.md` の flow-id 4-1 / 4-6 の本文追記を行った。**主判定は「この反映を見送ってマージした場合、`main` は今回の変更と矛盾・不整合な状態になるか。」に確定**（却下案3件を作業結果へ記録）。**出口「このMRでやる」（極小の反映）だけは過去事例の裏付けが無い**ため、新節本文へ限界として明示した。結果は `wip/reports/2026-08-23_reflection-split-criteria_作業結果.md`（＋`.html`）。
- flow-id 3-6（検証）: 計画の8本すべてが期待値どおり。**ただし追3が一度 0 を返した** — 検索語 `反映対象をこのMRでやるか切り出すかの判断` が段落内の改行で2行に割れており `grep` が一致しなかった。文書側の折り返しを直して解消（**このissueで3回目の「検索語と実データの形が食い違う」不具合**）。`check-doc-references.sh` 参照切れ0、`extract-frontmatter.sh` failed=0。
- **敵対的レビュー（フェーズ3・2/3回目）**: flow-id 3-6 の成果物（`references/planning.md` の新節・`SKILL.md` 2箇所・作業結果 md/html・worklog・`HANDOFF.md`）を対象に実施。指摘15件。13件をPR #196 へインライン投稿し、2件（minor/medium）はレビュー本文へ。**15件すべてを自分のコマンドで裏取りし、全件が正しい指摘であることを確認した**（3回連続）。投稿スレッド: [#1](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#discussion_r3839946263) / [#2](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#discussion_r3839946655) / [#3](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#discussion_r3839947037) / [#4](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#discussion_r3839947487) / [#5](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#discussion_r3839947794) / [#6](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#discussion_r3839948266) / [#7](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#discussion_r3839948835) / [#8](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#discussion_r3839949488) / [#9](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#discussion_r3839949985) / [#10](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#discussion_r3839950461) / [#11](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#discussion_r3839950882) / [#12](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#discussion_r3839951308) / [#13](https://github.com/yuki-matsu783/MR-driven-workflow/pull/196#discussion_r3839951795)
- flow-id 3-6（修正後）: **15件すべてへ対応した。** 主な修正は (a) **全1 が空振り検査だった** — 計画の定義（`見送ってマージ`、変更前0→変更後1）を `判断基準` へ差し替えており、変更前後とも4ファイルで**新節を1行も書かなくても合格**していた（計画自身がこの語を名指しで禁じていた）、(b) **HTMLにしか無い節があった**（重点レビュー依頼・サマリ）ため md へ追加し、必須節「確かめられなかったこと」「設計への反映」も両方へ追加、(c) 3つの出口の条件が排他でないため**上から順に見て最初に当たった出口を採る**形へ組み替え、(d) 出口「別issueへ切り出す」で起票されなかった場合は (2) へ落とす退避経路を追加、(e) 判定の検算を `洗い出しN + 4-6追加M = 判定済み(N+M)` へ、(f) `HANDOFF.md` は5-5で削除ではなく**リセット**である旨へ訂正、(g) `SKILL.md` 4-1 から出口一覧・人間決定ルールの再掲を削除。
- **同型の不具合を4回踏んだ。** `別issue` ⊂ `個別issue` / `5フェーズ` を伴わない `43ステップ` / 検索語の改行分断 / **検査語を計画の定義から差し替え**。**4回目だけは「計画に検証コマンドを書き基準値を実測する」規律では見つからない**（検査が期待どおりの値を返すため）。対策は「計画に書いた検査コマンドは文字列としてそのまま流す」。

## 次にやること

- flow-id 4-2: `commit` スキル経由でコミットし、リモートへ反映する。
- flow-id 4-4: フェーズ4の敵対的レビュー1回目で投稿した9スレッドへ返信する（`- 未返信スレッド:` を0にする）。
- flow-id 4-6: DDR `i0176-01` を書き、`generate-ddr-list.sh` を実行して `.claude/docs/spec/issue-mr-workflow.md` へ反映する。あわせて反映対象 #3・#5・#8・#9・#10 を `.claude/rules/` と3つの `REVIEW-POINTS.md` へ入れ、`.claude/VERSION` を `0.5.0` にする。

## 判断を迷った内容

- **`.claude/VERSION` の版を AI が決めてよいか。** 配布対象アセット（`.claude/rules/` 2本・3つの `REVIEW-POINTS.md`・`references/planning.md`・`SKILL.md`）が変わるため更新が要るが、**版の決定は本来人間が行う**。非対話セッションのため `.claude/docs/spec/distribution-assets.md` の目安表に沿って **`0.4.0` → `0.5.0`（MINOR）** を適用した（後方互換を壊す変更は無く、機能の追加にあたる）。**レビューで否とされたら戻す。**
- **flow-id 1-5（人間による全体作業計画の合意）は非対話セッションのため成立しない。** 進捗記号は `[]` のまま残し、代わりに敵対的レビューでレビューの空白を埋める（`.claude/rules/docs-workflow.md`「非対話的実行環境」）。
- **受け入れ条件の「SKILL.md に節がある」の解釈。** issue #160 で SKILL.md の詳細節は `references/` 配下へ切り出されているため、そのまま SKILL.md 本体へ書くと構造に反する。フェーズ2の問い1で結論を出す。
- **敵対的レビューの指摘1（切り出しに触れる箇所が3つある）への対応方針。** 3箇所のうち2箇所（`SKILL.md:76`・`references/planning.md:246`）は**判定している対象が違う**（issueそのものの粒度）ため、新節へ寄せず #64 のままにした。相互参照の1行を置くことで読み手の迷いを消す方針を採ったが、これが十分かはフェーズ3のレビューで再確認する。

## 未解決の内容

- **Q4 の母数に構造的な偏りがある。** 母数は「切り出し・見送りに言及したDDR」であり、**偽陰性（切り出すべきだったのに切り出されなかった事例）は原理的に見えない**。7/7 は上限の推定であって「基準が実証された」とは読めない。MRのレビュー往復まで遡っていない点も同じ。調査結果の「確かめられなかったこと」に明記済み。
- **出口「このMRでやる」（極小の反映）は本調査では裏付けられていない。** 母数が見送り事例に偏っているため。issue #64 節からの引き継ぎとして扱う。
- ~~**束A・束Bの起票の可否は、次セッションで人間に確認する。**~~ **ユーザー指示で出口(1) が AND 条件になったため、この8件は再判定で全件が出口(3)「このMRでやる」へ移った**（規模がいずれも小さく AND が成立しない）。**起票の確認は不要になり、束A・束Bという切り出し単位も消えた。** DDR `i0176-02` も作らない。
- **`grep` の部分一致で母数を作る罠が `.claude/rules/shell-script-style.md` に無い。** `--` の付け忘れ（先頭ハイフン）は書かれているが、`別issue` ⊂ `個別issue` のような部分一致そのものは扱われていない。**フェーズ4の `【AIアセット反映】` 候補**として、新節の主判定へ通して可否を決める（規模が小さいことを理由に判定を飛ばさない）。
- ~~**主判定の文言が未確定。**~~ **flow-id 3-6 で確定した**（「この反映を見送ってマージした場合、`main` は今回の変更と矛盾・不整合な状態になるか。」）。却下案3件とその理由は `wip/reports/…作業結果.md` に記録済み。**ただし当てた候補は計4案で、網羅的に比較したわけではない**点は残る。
- ~~**出口「このMRでやる」（極小の反映）の裏付けの弱さを新節と DDR のどちらに書くか未定。**~~ **flow-id 3-6 で新節本文へ書くと決めた**（その出口を選ぼうとしている人の導線上に置くため）。DDR 側（フェーズ4）にも母数の偏りとして重ねて記録する。
- **出口「このMRでやる」（極小の反映）そのものは、依然として実例の裏付けを持たない。** 母数の性質上このissueでは取れない。将来、極小の反映をこのMRで済ませた事例が溜まった時点で見直す。

## 守るべき条件・触ってはいけない範囲

- ブランチは `claude/reflection-plan-criteria-tnhfvs` 固定（ハーネス指定。`.mrworkflow.json` の
  `feature-<issue番号>-<slug>` 規則とは異なるが、ハーネス側の指定を優先する）。
- DDR本文・spec内の過去changelog（point-in-time の記録）は書き換えない。特に `i0064-01:25`・`i0092-01:52` の「5フェーズ40ステップ」は当時の値であり、43へ書き換えない。
- **planツールを使えない実行環境のため、全体作業計画は Write で作成しファイル名は内容から付けた**（`wip/plans/REVIEW-POINTS.md` の「ハーネスの提示した自動命名のまま」からの逸脱）。worklog・reports のファイル名もこの名前に揃えてある。
- `SKILL.md:76`（flow-id 2-6）の切り出し記述は変更しない（issue粒度の判定であり issue #64 の担当）。
- **調査結果の行番号はコミット `90477a2` 時点のもの**で、フェーズ3で `references/planning.md` に新節を足すと必ずずれる。後から参照するときは見出し名で辿る（レポート冒頭に明記済み）。
- **worklog は push 5 以降、規則どおり `_push<N>.md` で分ける。** `_push2.md` は push 2〜4 をまとめて記録しており、その逸脱は当該ファイルの冒頭に明記した。
- **`grep` の行単位マッチが意図した範囲を覆っていない不具合を、このissueで4回踏んでいる**（(1) `別issue` ⊂ `個別issue` / (2) `5フェーズ` を伴わない `43ステップ` / (3) 検索語が段落内の改行で分断 / (4) 検査語を計画の定義から差し替え）。件数を書く前に、数えたい対象**そのものの語**で数え直すこと。**節名のような固有名詞を文書内で参照するときは、改行で割らずに1行へ収めること**（grepだけでなく人間の目視検索・エディタ検索でも引っかからなくなる）。
- **計画に書いた検査コマンドは、文字列としてそのまま流すこと**（読みやすさや語感で書き換えない）。書き換えるなら計画側の定義も同時に直し、**変更前のツリーで基準値を測り直す**。上記(4)がこれで、**「計画に検証コマンドを書き基準値を実測する」規律では原理的に見つからない**（検査そのものは期待どおりの値を返すため）。
