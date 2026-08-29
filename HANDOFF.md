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

- issue: #205（https://github.com/yuki-matsu783/MR-driven-workflow/issues/205 ）
- ブランチ: claude/pr-mr-diffview-link-yxim1l
- PR: #206（https://github.com/yuki-matsu783/MR-driven-workflow/pull/206 ）
- push回数: 9
- 現在のループ: 3-6〜3-9 を敵対的レビュー2回目で代替予定（進捗記号は[]のまま）
- 未返信スレッド: 0
- 追従監視: あり（subscribe_pr_activity で PR #206 を購読中。セッション終了で止まるため次セッションは resume で取り直す）

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
| [] | 2-3 | MRで調査計画についてレビュー・コメントする | 人間 |
| [] | 2-4 | レビュー内容を取得し、調査計画を修正する | `comments` / `reply` |
| [] | 2-5 | 調査計画をもとにMR descriptionを更新する | `describe` |
| [] | 2-6 | 調査を実施し、結果をwip/reports/へ記録する | エージェント |
| [] | 2-7 | commitし、pushしてレビュー依頼を行う | エージェント |
| [] | 2-8 | MRで調査結果についてレビュー・コメントする | 人間 |
| [] | 2-9 | レビュー内容を取得し、調査結果を修正する | `comments` / `reply` |
| [x] | 2-10 | 調査結果をもとにMR descriptionを更新する | `describe` |
| [x] | 3-1 | 個別作業計画を作成する | エージェント |
| [] | 3-2 | commitし、pushしてレビュー依頼を行う | エージェント |
| [] | 3-3 | MRで作業計画についてレビュー・コメントする | 人間 |
| [] | 3-4 | レビュー内容を取得し、作業計画を修正する | `comments` / `reply` |
| [] | 3-5 | 作業計画をもとにMR descriptionを更新する | `describe` |
| [] | 3-6 | 作業を進め、結果をwip/reports/へ記録する | エージェント |
| [] | 3-7 | commitし、pushしてレビュー依頼を行う | エージェント |
| [] | 3-8 | MRでレビュー・コメントする | 人間 |
| [] | 3-9 | レビュー内容を取得し、実装・ドキュメントを修正する | `comments` / `reply` |
| [] | 3-10 | 作業内容をもとにMR descriptionを更新する | `describe` |
| [] | 4-1 | 個別反映計画を作成する（反映対象の洗い出し） | エージェント |
| [] | 4-2 | commitし、pushしてレビュー依頼を行う | エージェント |
| [] | 4-3 | MRで反映計画についてレビュー・コメントする | 人間 |
| [] | 4-4 | レビュー内容を取得し、反映計画を修正する | `comments` / `reply` |
| [] | 4-5 | 反映計画をもとにMR descriptionを更新する | `describe` |
| [] | 4-6 | 反映を進め、結果をwip/reports/へ記録する | エージェント |
| [] | 4-7 | commitし、pushしてレビュー依頼を行う | エージェント |
| [] | 4-8 | MRでレビュー・コメントする | 人間 |
| [] | 4-9 | レビュー内容を取得し、設計・AIアセットを修正する | `comments` / `reply` |
| [] | 4-10 | 反映内容をもとにMR descriptionを更新する | `describe` |
| [] | 5-1 | defaultブランチとのコンフリクトを検知・解消する | エージェント |
| [] | 5-2 | 関連issueへマージ前通知を行う | エージェント |
| [] | 5-3 | `.claude/` の変更を `.gemini/` へ変換同期する | エージェント |
| [] | 5-4 | 最終統括レポートを作成しPR/MRへ反映する | エージェント |
| [] | 5-5 | wip/配下を片付け、HANDOFF.mdをリセットする | エージェント |
| [] | 5-6 | commitし、pushしてDraftを解除する | エージェント |
| [] | 5-7 | マージする | 人間 |

## やったこと

- flow-id 1-1/1-2: issue #205 の内容を MCP（`mcp__github__issue_read`）で取得した。
  この実行環境には `gh`/`glab` CLI が無く、`get_vcs_access_mode` は `mcp` を返す。
- flow-id 1-4: 全体作業計画 `wip/plans/diffview-link-switchover.md` と同名の `.html` を作成した。
- flow-id 1-3: Draft PR #206 を `mcp__github__create_pull_request` で作成し、
  `subscribe_pr_activity` で追従監視を開始した。
- flow-id 2-1: 個別調査計画 `wip/plans/【調査】Diffviewリンクの出し分けとMCP経路での解決手段.md`
  （+ `.html`）と worklog を作成した。調査項目は Q1〜Q6。
- **push直後のhookが本issueの問題をそのまま再現した**（「defaultブランチとの差分」が
  Compareページ、MRリンクは「CLI不在のため未取得」）。問題の実在を実測で確認できた。
- flow-id 2-2: 個別調査計画をpushし、**敵対的レビュー（フェーズ2・1回目）を実行**した。
  12件検出（major 9 / minor 3）。うち11件をPR #206 へインライン投稿し、1件は報告のみ。
  **11件すべてに対応し、11スレッドすべてへ返信済み**（未返信スレッド 0）。
  投稿スレッド: https://github.com/yuki-matsu783/MR-driven-workflow/pull/206/files
  （`#discussion_r3840039773` 〜 `r3840043845` の11件）
- 敵対的レビューで判明した重要な点3つ:
  1. 完了条件が「全問『不明』でも合格」する空振りの形だった → **停止条件**を新設。
  2. 上位計画の懸念（refの伝播遅延・fork元PR・GitLabの `?start_sha=`）が個別計画へ
     引き継がれていなかった → Q3表A行を9項目へ、Q4をプロバイダ別へ拡張。
  3. **`gitlab_get_diff_anchor_base_url` は3分岐で、しかも純粋関数ではなく `glab api` を呼ぶ。**
     本issueがMCP経路で `mr_url` を解決すると、これまで分岐(a)で早期returnしていた経路が
     新たに `glab api` を呼ぶ側へ入る（本issueが持ち込む副作用。当初の計画では見えていなかった）。
- **Q3-A（`git ls-remote`）の実測**: `refs/pull/206/head` が push直後のHEADと一致した
  （伝播遅延は観測されず）。コストは約400〜600ms、ベースライン（`git rev-parse`）は4ms。
  **Linux環境の値であり、git bash実機の値ではない。**
- flow-id 2-6: **調査を実施**し、`wip/reports/20260824_diffview-link-switchover_調査結果.md`
  （+ `.html`）へ記録した。決めたことは次の4点。
  1. `get_mr_diff_url` を4引数化（4番目が空ならCompare、あればDiffview）。純粋関数のまま。
  2. MCP経路のPR URL解決は**案A（`git ls-remote` ＋ `GIT_TERMINAL_PROMPT=0`）**を採用。
     案B（`wip/state/`）・案C（`HANDOFF.md`）は**silent staleness／表記依存**を理由に却下。
     **GitHubのみ**（GitLabの `refs/merge-requests` は検証不能のため対象外）。
  3. **差分アンカーの土台を `diff_url` から切り離す**（`compare_url` を別途保持）。
     これを採らないと、未検証のページにアンカーを載せることになり**後退する**。
  4. `get_mr_diff_since_url` は**変更しない**（両プロバイダともCompareのまま）。
- flow-id 2-7: 調査結果をpushし、**敵対的レビュー（フェーズ2・2回目）を実行**した。
  12件検出。うち9件をPR #206 へインライン投稿し、3件は報告のみ。
  **9件すべてに対応し、9スレッドすべてへ返信済み**（未返信スレッド 0）。
  投稿スレッド: `#discussion_r3840113526` 〜 `r3840116599` の9件。
- 2回目のレビューで**設計が変わった点が3つ**ある（1つ目が最も重い）。
  1. **複数一致時に「最大のPR番号を採る」を撤回した。** `refs/pull/*` には閉じた
     （マージ済みの）PRのrefも残るため（実測: `refs/pull/4/head` `refs/pull/85/head` が現存）、
     番号の大小では正しいPRを選べない。**一致がちょうど1件のときだけ採用し、
     0件・2件以上・失敗はすべてCompareへ縮退する。** これを直さないと、案B・Cを却下した理由
     （黙って誤ったURLを出す）が案A自身にも当てはまり、採用の論拠が崩れていた。
  2. **`GIT_TERMINAL_PROMPT=0` を「実測した」という記述を撤回した。** この環境では同変数が
     既に `0` で設定済みのため有無の差を測れていない。対策を `-c credential.helper=`
     `-c core.askPass=` へ広げ、無応答対策として `-c http.lowSpeedLimit` /
     `-c http.lowSpeedTime` を足す（**いずれも未検証**）。
  3. **解決したPR URLの格納先を `mr_url` に決めた。** 結果として `- MR:` 行が実リンクへ変わり、
     2回目以降のpushで `- コメント一覧(MR画面):` 行が新たに出る（**スコープの拡大**のため、
     重点レビュー依頼で承認を求めている）。
- あわせて**md（正文）とHTMLビューの双方向の食い違いを解消**した。md へ4節（重点レビュー依頼／
  設計への反映／想定と異なった点／残課題）を、HTML へ「停止条件の判定」節を補った。

- flow-id 2-10: PR descriptionを調査結果の内容へ更新した（`mcp__github__update_pull_request`）。
- flow-id 3-1: 個別作業計画 `wip/plans/【実装】【テスト】Diffviewリンクの出し分けとMCP経路でのPR URL解決.md`
  （+ `.html`）と worklog を作成した。**mdを先に書きHTMLを後から写す**順序に変えた
  （フェーズ2の指摘の再発防止）。計画HTMLの規約検査（自己完結・埋め忘れ・重複ID・リンク切れ・
  表の列数・md/HTMLの見出し突き合わせ）は**全件パス**。

- flow-id 3-2: 個別作業計画をpushし、**敵対的レビュー（フェーズ3・1回目）を実行**した。
  10件検出（major 7 / minor 3）。**全10件を投稿し、全件へ対応・返信済み**（未返信スレッド 0）。
  投稿スレッド: `#discussion_r3840211250` 〜 `r3840218784` の10件。
- **うち3件は、計画のまま実装すると壊れるものだった。**
  1. 「置き換え前」の `local anchor_compare_url="$diff_url"` が**実在しない行**だった
     （実物は `... file_links_text=""` を兼ねる）。→ 作業3を 3-a/3-b/3-c へ分割し、
     各節に巻き添えの確認を必ず置く形にした。
  2. `http.lowSpeedLimit` / `http.lowSpeedTime` は**HTTPにしか効かない**。SSH remoteでは
     ハング対策が丸ごと無効。→ **remoteが `http(s)://` のときだけ解決を試みる**形にした
     （SSH対応は別issueへ送る）。
  3. `wc -l` の出力を**文字列比較**しており、BSD系 `wc` の先頭空白で**常に空を返す＝機能が
     入らないのにテストは緑**になりうる。→ 件数判定を `awk` へ寄せ、`wc`・`sed` を消した。
- **レビューでは挙がっていない制約を自分で1つ見つけた。** `test_vcs_provider.sh` は220行目付近で
  `get_provider` を全域上書きしており、「依存するテストをこれより後ろへ追加しないこと」と警告して
  いる。今回のディスパッチャ経路テストは該当するため、**上書きより前へ挿入する**と計画へ明記した。

- flow-id 3-6: **実装を完了した**（`Github.sh` / `Gitlab.sh` / `Provider.sh` / `post-push-compact-prompt.sh`
  / `test_vcs_provider.sh` の5ファイル）。結果は
  `wip/reports/20260824_diffview-link-switchover_実装結果.md`（+ `.html`）。
  - **7つの完了条件のうち6つを達成**（残る1つ「2回目以降のpushでコメント一覧行が出る」は
    次の実pushが最初の確認機会）。停止条件はいずれも該当しなかった。
  - `test_vcs_provider.sh` が `passed=225` → **`passed=242`**（+17件）。全21テストファイルで `failures=0`。
  - **この環境でDiffviewリンクが実際に出た**:
    `- defaultブランチとの差分: https://github.com/yuki-matsu783/MR-driven-workflow/pull/206/files`
  - **後退なし**: 差分アンカー付きリンク10本すべてがCompareのまま（10/10で件数一致）。
  - **空振りでない**: 第4引数の受け渡しを一時ツリーで落とすと、`/files` が返らなくなることを確認。

- **flow-id 3-7 の実push（コミット `22a23b7`）で、伝播遅延が実際に発生した。** pushした直後の
  hookは `refs/pull/206/head` がまだ前回pushのSHAを指していたため解決に失敗しCompareへ縮退したが、
  数十秒後に同じコミットへ再実行すると成功した。**フェーズ2調査結果の「本環境では観測されなかった」
  という記述は、計測タイミングがhookの実際の発火（push直後）とずれていたための誤りだった**と判断し、
  調査結果・実装結果の両レポート（mdとhtml）を訂正した。
  - **対策**: `github_resolve_mr_number_for_head` / `resolve_mr_number_for_head` を複数候補SHA
    （今回push・前回push）を受け取る形へ変更し、判定基準も「一致したref数」から「一致したPR番号の
    種類数」へ変えた（複数候補が同じPR番号に一致するのは正常なため）。`Github.sh` / `Provider.sh` /
    `post-push-compact-prompt.sh` を修正。
  - `test_vcs_provider.sh` へ5件追加（`passed=242` → **`passed=247`**）。単体テスト21ファイル
    全件 `failures=0`。空振りでないことも同じ手順（`"$@"` 渡しを1引数へ落として3件が実際に落ちる
    ことを確認）で確かめた。
- **対策のコミット（`61fdf91`）＋ドキュメント訂正コミット（`27786bd`）をpushした直後のhook出力で、
  対策が実際に機能することを確認した。** 「defaultブランチとの差分」が即座に `/pull/206/files` に
  なり、**完了条件6（2回目以降のpushで `- コメント一覧(MR画面):` 行が出る）も確認できた**
  （`- コメント一覧(MR画面): https://github.com/yuki-matsu783/MR-driven-workflow/pull/206`）。
  実装結果レポート（mdとhtml）の完了条件6を「未確認」から「達成」へ更新した。

## 次にやること

- （完了済み）伝播遅延対策（複数候補SHA化）を `commit` スキル経由でコミット・push した
  （flow-id 3-7 の追加分。コミット `61fdf91`・`27786bd`）。push直後のhook出力で対策が
  実際に機能することと、完了条件6（コメント一覧行）を確認済み。
- **敵対的レビュー（フェーズ3・2回目）を実行**し、指摘へ対応・返信する。
- flow-id 4-1: 個別反映計画を作成する（spec「提供関数」表・未決定事項の差し替え、DDR `i0205-01`、
  `references/mcp-fallback.md` への追記。**フェーズ3で追加した「複数候補SHA」設計もspec/DDRへ
  反映対象に含める**）。
- （完了済み）flow-id 3-6 の実装対象:
  1. `get_mr_diff_url` の4引数化（`Provider.sh` / `Github.sh` / `Gitlab.sh`）。純粋関数のまま。
  2. `Provider.sh` へPR URL解決関数を新設（`git ls-remote` ＋ **複数候補SHAで一致したPR番号が
     ちょうど1種類のときだけ採用**）。GitHubのみ。
  3. `post-push-compact-prompt.sh` で `compare_url` と `diff_url` を分離する。
  4. `test_vcs_provider.sh` へ4引数版のアサーションと、**ディスパッチャ経由の経路テスト**を追加する
     （純粋関数テストだけでは引数の受け渡し漏れを検出できない。issue #127 と同型）。
- flow-id 3-6 では、計画の**検証3（第4引数の受け渡しを意図的に落として経路テストが落ちること）**
  まで必ず行う。落ちなければそのテストは空振りであり、フェーズ4へ進まない。**完了済み**
  （伝播遅延対策側でも同じ手順を再実施し、空振りでないことを確認済み）。

## 判断を迷った内容

- **ブランチ名がこのリポジトリの命名規則（`feature-<issue番号>-<slug>`）に一致しない。**
  ハーネス（実行基盤）が `claude/pr-mr-diffview-link-yxim1l` を指定しており、
  「NEVER push to a different branch without explicit permission」という制約があるため、
  ハーネス側の指定に従った。`.claude/rules/git-workflow.md` の命名規則からは外れる。
- **全体作業計画をplanツール（Planモード）で作らなかった。** このリモート実行環境では
  Planモードの承認をユーザーから受け取れず、承認待ちでセッションが停止するため、
  Write で直接作成した。ファイル名もハーネスの自動命名が無いため手で付けた。

## 未解決の内容

- **【要人間判断】GitHubの `/pull/<n>/files` というURL形式を、この環境では一次情報で裏取り
  できなかった。** 計画の停止条件（Q1が不明ならissueへ差し戻す）に字面上は該当するが、
  URL形式は**issue #205 本文でリポジトリ所有者が指定したもの**でありAIの推測ではないため、
  停止条件を適用せず進めている。**差し戻すべきならフェーズ3以降を止める必要がある。**
  調査結果レポートの「重点レビュー依頼」筆頭に置いた。
- GitHubの差分アンカーが `/files` 上で機能するかは未検証（**分離設計により依存しなくなった**）。
- `git ls-remote` のgit bash実機でのコスト、fork元PR・オフライン時の挙動（いずれもCompareへ
  縮退する方向のため実害は無いと見ているが、その見立て自体が未検証）。
- **認証プロンプト・無応答への対策の実効性が未検証。** この環境は `GIT_TERMINAL_PROMPT=0` が
  既に設定済みで有無の差を測れず、ブラックホール状態も作れない。**最悪の失敗はハング
  （非0終了ではない）**であり、`( main ) || true` では救えないため、秒数と `timeout` 併用の
  可否はフェーズ3で決める。
- **【スコープ拡大の承認待ち】GitHubの重点ファイルリンクはCompareのまま残る。** 分離設計の
  帰結で、レビュアーが最も踏むリンクにissue #205 の問題がそのまま残る。「制約が残る」と
  「後退する（未検証のページにアンカーを載せる）」を天秤にかけ前者を選んだ。specの未決定事項へ
  引き継ぐ。

## 守るべき条件・触ってはいけない範囲

- **push先は `claude/pr-mr-diffview-link-yxim1l` のみ。** 他ブランチへpushしない。
- **マージ（flow-id 5-7）は行わない。** ユーザーの明示指示があるまで flow-id 5-6 で止まる。
- **`.gemini/` を直接編集しない**（`.claude/` からの生成物。flow-id 5-3 で再生成する）。
- 非対話セッションのため、人間のレビュー往復（2-3/2-4 等）は成立しない。ループ範囲の進捗記号は
  `[]` のまま残し、実施した内容は「やったこと」へ文章で補足する
  （`.claude/rules/docs-workflow.md` 末尾の規定）。
