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

- issue: #58 HANDOFF.mdの進捗表でループの周回数をヘッダ行に数字で明示する
- ブランチ: claude/handoff-loop-count-header-mwxais
- PR: #93 (Draft) https://github.com/yuki-matsu783/MR-driven-workflow/pull/93
- push回数: 4
- 現在のループ: 3-6〜3-9 の1周目（進行中）
- 追従監視: 購読あり（web。subscribe_pr_activity + 定期的な自己チェックイン）

## フロー進捗状況

進捗記号: `[x]` 完了 / `[]` 未着手・進行中 / `[-]` 今回は実施しない（スキップ）

| 進捗 | flow-id | ステップ | 担当 |
|----|---|---|---|
| [x] | 1-1 | issueを起票する。issue #58 として起票済み | 人間（AIが代行する場合は `issue-create` スキル） |
| [x] | 1-2 | issueの内容を取得する。`gh` CLI不在のため `mcp__github__issue_read` で取得（4見出しすべて揃っている） | `start <issue番号>` |
| [x] | 1-3 | featureブランチを作成する。ブランチはハーネス指定の `claude/handoff-loop-count-header-mwxais`（`feature-<issue番号>-<slug>` 命名規則の対象外）。Draft PR #93 をユーザーの明示指示を受けて作成し、追従監視を開始した | `start` |
| [-] | 1-4 | **Planモードで「全体作業計画」を作成する**（非対話的セッションでPlanモードの承認往復が取れないため省略し、issue #58の「期待する動作」「受け入れ条件」を全体計画として扱った） | エージェント |
| [-] | 1-5 | 全体作業計画に合意する（1-4を省略のため対象外） | 人間 |
| [x] | 1-6 | HANDOFF.mdを更新する | エージェント |
| [-] | 2-1 | **個別調査計画**（対象が既存スクリプト1本とその仕様書に限られ、実装前に読み切れたためフェーズ2を丸ごと省略） | エージェント |
| [-] | 2-2 | （2-1を省略のため対象外） | エージェント |
| [-] | 2-3 | （同上） | 人間 |
| [-] | 2-4 | （同上） | `comments` / `reply` |
| [-] | 2-5 | （同上） | `describe` |
| [-] | 2-6 | （同上） | エージェント |
| [-] | 2-7 | （同上） | エージェント |
| [-] | 2-8 | （同上） | 人間 |
| [-] | 2-9 | （同上） | `comments` / `reply` |
| [-] | 2-10 | （同上） | `describe` |
| [x] | 3-1 | 個別作業計画 `plans/【設計】【実装】HANDOFF進捗表のループ周回数をヘッダ行へ明示する.md` を**planツールを使わず**Write/Editで作成する | エージェント |
| [x] | 3-2 | `commit`スキル経由でcommitし、リモートへ反映してレビュー依頼を行う | エージェント |
| [] | 3-3 | MRで作業計画についてレビュー・コメントする（非対話セッションのため未実施） | 人間 |
| [] | 3-4 | レビュー内容を取得し、作業計画を修正する（3-3〜3-4を合意まで繰り返す） | `comments` / `reply` |
| [-] | 3-5 | 作業計画をもとにMR descriptionを更新する（PR未作成のため対象外） | `describe` |
| [] | 3-6 | 作業計画をもとに作業を進める、作業内容はworklogに更新する（**実作業は完了済み**。PR #93 のレビュー指摘に対応して方針変更・再実装まで実施。1周が完了していないため記号は`[]`のまま。下記「やったこと」参照） | エージェント |
| [] | 3-7 | `commit`スキル経由でcommitし、リモートへ反映してレビュー依頼を行う（commit・反映は実施済み） | エージェント |
| [] | 3-8 | MRでレビュー・コメントする（非対話セッションのため未実施） | 人間 |
| [] | 3-9 | レビュー内容を取得し、実装・ドキュメントを修正する（3-6〜3-9の作業ループを合意まで繰り返す） | `comments` / `reply` |
| [-] | 3-10 | 作業内容をもとにMR descriptionを更新する（PR未作成のため対象外） | `describe` |
| [-] | 4-1 | **個別反映計画**（今回は反映先が`.claude/docs/spec/update-handoff-progress.md`・`.claude/rules/docs-workflow.md`・`.claude/skills/issue-mr-flow/SKILL.md`・`.claude/agents/issue-mr-resume.md`に限られ、個別作業計画の「実装内容3. ドキュメント」に含めて合意できる粒度のため、独立ファイルにはしなかった） | エージェント |
| [-] | 4-2 | （4-1を省略のため対象外） | エージェント |
| [-] | 4-3 | （同上） | 人間 |
| [-] | 4-4 | （同上） | `comments` / `reply` |
| [-] | 4-5 | （同上） | `describe` |
| [] | 4-6 | 設計反映・AIアセット反映を行う（**実作業は完了済み**。spec・rules・SKILL・agentへ反映した。人間レビューを挟めずループが1周していないため記号は`[]`のまま） | エージェント |
| [] | 4-7 | `commit`スキル経由でcommitし、リモートへ反映してレビュー依頼を行う（commit・反映は実施済み） | エージェント |
| [] | 4-8 | MRでレビュー・コメントする（非対話セッションのため未実施） | 人間 |
| [] | 4-9 | レビュー内容を取得し、設計・AIアセットの内容を修正する（4-6〜4-9の反映ループを合意まで繰り返す） | `comments` / `reply` |
| [-] | 4-10 | 反映内容をもとにMR descriptionを更新する（PR未作成のため対象外） | `describe` |
| [] | 5-1 | 次タスクのために、`plans/` `worklog/` `reports/` を削除し、`HANDOFF.md` をリセットする | エージェント |
| [] | 5-2 | defaultブランチとのコンフリクトを検知し、あれば解消する | エージェント（`resolve-conflict` スキル） |
| [] | 5-3 | `commit`スキル経由でcommitし、リモートへ反映してDraftを解除する | エージェント |
| [] | 5-4 | マージする（squash merge） | 人間 |

## やったこと

- issue #58 の内容を取得し、既存の `.claude/scripts/src/update-handoff-progress.sh`・
  `.claude/docs/spec/update-handoff-progress.md`・`.claude/scripts/test/test_update_handoff_progress.sh` を読んだ。
  issue本文が挙げている `tests/test_update_handoff_progress.sh` はissue #63で
  `.claude/scripts/test/` へ移動済みだったため、実在するパスの側を更新した。
- 個別作業計画 `plans/【設計】【実装】HANDOFF進捗表のループ周回数をヘッダ行へ明示する.md` を作成した。
- `update-handoff-progress.sh` へ以下を追加した（進捗表側のロジックは変更していない）。
  - `count_rounds_to_reply` / `format_loop_status_to_reply` / `set_loop_header_in_lines` /
    `follow_loop_header_in_lines`
  - `add-round` とループ範囲への `mark-done` から、ヘッダ `- 現在のループ:` 行を自動追従させる処理
  - `set-header --loop <text>`
- `.claude/scripts/test/test_update_handoff_progress.sh` へヘッダ追従のテストを18件追加し、
  `passed=35 failures=0` を確認した。リポジトリ内の他の単体テスト6本も併せて実行し、いずれも
  `failures=0` であることを確認した。
- 設計反映・AIアセット反映として、`.claude/docs/spec/update-handoff-progress.md`（仕様・制約・影響範囲）・
  `.claude/rules/docs-workflow.md`（ヘッダ行の運用）・`.claude/skills/issue-mr-flow/SKILL.md`
  （周回数はヘッダ行を読む）・`.claude/agents/issue-mr-resume.md`（現在地サマリへ追加）を更新した。
- Draft PR #93 を作成し、defaultブランチの追従監視（`subscribe_pr_activity` + 自己チェックイン）を
  開始した。`check-base-conflicts.sh` は `hasConflict: false`。
- **PR #93 のレビュー指摘を受けて方針を変更した**（push3）。「`[x][x][]` の連結表記そのものを
  やめて、今なんループ目かを記録したい」という指摘。ユーザーの判断を仰いだうえで次のとおり変更した。
  - 進捗表は**どの行も記号1つ**（`[]`/`[x]`/`[-]`）になり、連結表記を廃止した。
  - 周回数の記録場所は**ヘッダの `- 現在のループ:` 行だけ**。`add-round` が+1して記号を `[]` へ戻し、
    ループ範囲への `mark-done` は周回数据え置きで記号を `[x]`・状態を（完了）にする。
  - 旧表記のHANDOFF.mdは、次の `add-round`／`mark-done` で**自動移行**する（記号の個数を周回数として
    ヘッダへ移し、進捗列を記号1つへ畳む）。
  - `.claude/rules/docs-workflow.md` のループ記号ルールを全面的に書き換え、spec・SKILL・resumeエージェント・
    テスト（45件・`failures=0`）・issue #58 本文・PR #93 の説明も更新した。
- **mainの進行に追従した**（push4）。追従監視の定期確認で `hasConflict: true` を検知し、
  `resolve-conflict` スキルで解消した（詳細は「判断を迷った内容」）。
- mainがissue #87で導入した「個別計画には結果を書かず`reports/…md`へ分離する」ルールに合わせ、
  作業結果の正文を `reports/20260819_issue58_ループ周回数のヘッダ集約.md` として作成した。
- 詳細な試行錯誤は `worklog/` の `_push1.md` と `_push3.md` に記録した。

## 次にやること

- （人間）Draft PR #93 で実装・ドキュメントのレビュー（flow-id 3-8 / 4-8 相当）。
- レビュー合意後、flow-id 5-1（`plans/` `worklog/` の削除とHANDOFF.mdのリセット）→ 5-2
  （コンフリクト検知・解消）→ 5-3（Draft解除）へ進む。**5-3より前にDraftを解除しない。**

## 判断を迷った内容

- **mainマージ時のコンフリクト解消（類型C: 同じ表の近接行）。** `.claude/rules/docs-workflow.md` の
  運用表で、main側（issue #87）が `plans/【種別】〜.md` 行へ「実施結果は`reports/…md`へ分離する」を
  追記し、作業ブランチ側が `HANDOFF.md` 行のヘッダ情報へ「現在のループ」を加えていた。**両方の行を
  それぞれの変更側から採って統合**し、どちらの意図も落としていない（片側採用はしていない）。
  追従監視モードのため、類型Cの規則どおり承認を待たずに解消した。検証（マーカー残存なし・単体
  テスト7本すべて `failures=0`・DDR番号の重複なし・`hasConflict: false`）は省略していない。
- **レビュー指摘とissue本文の受け入れ条件が矛盾していた。** 指摘（連結表記の廃止）は issue #58 の
  「進捗表の記号・行構成に差分が出ない」と正面から衝突するため、実装を進める前にユーザーへ確認し、
  指摘側（＋issue本文の更新）を採った。**受け入れ条件と食い違う指摘は、勝手に解釈せず確認する。**
- 周回数の読み取りで、ヘッダ行が無いときの扱い。「常に1周目から始める」ではなく
  **「進捗列の記号の個数を読む」**を採用した。前者だと既存の `[x][x][]` が次の操作で1周目へ
  巻き戻るが、後者はそれがそのまま旧表記からの自動移行経路になる。
- ヘッダ行の追従に失敗したとき（挿入位置の基準となるヘッダ項目も `## フロー進捗状況` 見出しも
  持たない変則的なHANDOFF.md）に、`mark-done`/`add-round` 自体をエラーにするか、警告に留めて
  進捗表の更新だけ書き戻すかで迷った。**警告に留める**方を採用した。
  `set-header --loop` はユーザーが明示的にその行を求めているので、こちらはエラーのままにしている。

## 未解決の内容

- 人間担当のレビュー往復（flow-id 3-3/3-4, 3-8/3-9, 4-8/4-9）は未実施のまま。
- **Draft解除（flow-id 5-3）は未実施。** flow-id 5-1（`plans/` `worklog/` の削除）・5-2
  （コンフリクト検知）を通る前であり、人間のレビューも未着手のため。
- 追従監視の状態: `check-base-conflicts.sh` を実行し `hasConflict: false`（base `main` は
  `1da5f98`）。購読・自己チェックインは**このセッションに紐づく**ため、セッションが変われば
  `resume` で取り直すこと。

## 守るべき条件・触ってはいけない範囲

- **進捗表の記号は、どの行も常に1つ。** 連結（`[x][x][]`）へ戻さない。`LOOP_RANGES` の定義も変更しない。
- **周回数は進捗表に持たせない。** 記録場所は `- 現在のループ:` 行だけであり、手で書き換えず
  `add-round`／ループ範囲への `mark-done` に任せる（ループ範囲の外にいることを示す場合だけ
  `set-header --loop 'なし'`）。
- 旧表記のHANDOFF.mdを壊さないこと（次の操作で自動移行する経路を維持する）。
- `- 追従監視:` 行（issue #88）は `set-header` の対象外という扱いを維持する。
