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

- issue: #47
- ブランチ: `claude/multiline-command-japanese-comments-k8c2pr`
- PR: #132（https://github.com/yuki-matsu783/MR-driven-workflow/pull/132 ）
- push回数: 2
- 現在のループ: 2-3〜2-4 の1周目（進行中）
- 追従監視: 購読あり（web。subscribe_pr_activity + 定期チェックイン）

<!--
本ブランチは Claude Code on the web のセッションで進めており、ユーザーの指示により
人間のレビュー往復（flow-id 2-3/2-8, 3-3/3-8, 4-3/4-8）を敵対的レビュー
（.claude/skills/adversarial-review/SKILL.md）で代替する。該当ループ範囲の記号は
人間のレビューが済むまで `[]` のままとし、実施内容は「やったこと」に文章で残す
（.claude/rules/docs-workflow.md の非対話的実行環境に関する規定に従う）。
-->

| 進捗 | flow-id | ステップ | 担当 |
|---|---|---|---|
| [x] | 1-1 | issueを起票する | 人間 |
| [x] | 1-2 | issueの内容を取得する | `start <issue番号>` |
| [x] | 1-3 | featureブランチとDraft MRを作成する | `start` |
| [x] | 1-4 | **Planモードで「全体作業計画」を作成する** | エージェント |
| [x] | 1-5 | 全体作業計画に合意する | 人間 |
| [x] | 1-6 | 全体作業計画をもとにHANDOFF.mdを更新する | エージェント |
| [x] | 2-1 | **個別調査計画**`plans/【調査】〜.md`を**planツールを使わず**Write/Editで作成する | エージェント |
| [] | 2-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 2-3 | MRで調査計画についてレビュー・コメントする | 人間 |
| [] | 2-4 | レビュー内容を取得し、調査計画を修正する | `comments` / `reply` |
| [] | 2-5 | 調査計画をもとにMR descriptionを更新する | `describe` |
| [] | 2-6 | **調査を実施**し、結果を`reports/日付_<全体計画名>_<内容を簡潔に>.md`とworklogに記録する | エージェント |
| [] | 2-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 2-8 | MRで調査結果についてレビュー・コメントする | 人間 |
| [] | 2-9 | レビュー内容を取得し、調査結果を修正する | `comments` / `reply` |
| [] | 2-10 | 調査結果をもとにMR descriptionを更新する | `describe` |
| [] | 3-1 | **調査結果をもとに**、個別作業計画`plans/【設計】【実装】〜.md`等を**planツールを使わず**Write/Editで作成する | エージェント |
| [] | 3-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 3-3 | MRで作業計画についてレビュー・コメントする | 人間 |
| [] | 3-4 | レビュー内容を取得し、作業計画を修正する | `comments` / `reply` |
| [] | 3-5 | 作業計画をもとにMR descriptionを更新する | `describe` |
| [] | 3-6 | 作業計画をもとに作業を進める | エージェント |
| [] | 3-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 3-8 | MRでレビュー・コメントする | 人間 |
| [] | 3-9 | レビュー内容を取得し、実装・ドキュメントを修正する | `comments` / `reply` |
| [] | 3-10 | 作業内容をもとにMR descriptionを更新する | `describe` |
| [] | 4-1 | **作業結果と`plans/` `worklog/` の内容をもとに**、個別反映計画`plans/【設計反映】【AIアセット反映】〜.md`等を**planツールを使わず**Write/Editで作成する | エージェント |
| [] | 4-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 4-3 | MRで反映計画についてレビュー・コメントする | 人間 |
| [] | 4-4 | レビュー内容を取得し、反映計画を修正する | `comments` / `reply` |
| [] | 4-5 | 反映計画をもとにMR descriptionを更新する | `describe` |
| [] | 4-6 | 反映計画をもとに作業を進める | エージェント |
| [] | 4-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 4-8 | MRでレビュー・コメントする | 人間 |
| [] | 4-9 | レビュー内容を取得し、設計・AIアセットの内容を修正する | `comments` / `reply` |
| [] | 4-10 | 反映内容をもとにMR descriptionを更新する | `describe` |
| [] | 5-1 | **defaultブランチとのコンフリクトを検知し、あれば解消する** | エージェント |
| [] | 5-2 | **今回のMRが影響する関連issueを特定し、承認を得てから当該issueへ通知する** | エージェント |
| [] | 5-3 | 次タスクのために `plans/` `worklog/` `reports/` を削除しHANDOFF.mdをリセットする | エージェント |
| [] | 5-4 | `commit`スキル経由でcommitし、push して Draftを解除する | エージェント |
| [] | 5-5 | マージする | 人間 |

## やったこと

issue #47（AIがBash/PowerShellツールへ渡すコマンド文字列の規約を `.claude/rules/` へ追加する）に
フェーズ1まで着手した。

- **flow-id 1-2**: `mcp__github__issue_read` でissue #47を取得。標準4見出し（目的・現状・期待する
  動作・受け入れ条件）は揃っており、`test_issue_sections` も警告なし。
- **flow-id 1-3**: ハーネス指定ブランチ `claude/multiline-command-japanese-comments-k8c2pr` を
  使用（リポジトリ規約の `feature-47-<slug>` ではない。理由は「守るべき条件」節）。baseとの差分が
  0だったため `add_empty_commit_for_draft_mr` で空コミットを積んでからDraft PR #132 を作成した。
  `subscribe_pr_activity` で追従監視を開始済み。
- **flow-id 1-4/1-5**: 全体作業計画 `plans/prancy-prancing-dewdrop.md` を作成し、承認を得た。
  issue分割は不要と判定した（受け入れ条件7項目は「1つのルール文書に何を書くか」の内訳であり、
  同型の成果物の並列列挙ではないため）。
- **軽めの事前調査で分かったこと**（フェーズ2で裏取りする）:
  - `.claude/rules/` の6ファイル中 `alwaysApply: true` を持つのは3ファイルだけだが、本セッションでは
    6ファイルすべてがコンテキストへ読み込まれている。`AGENTS.md` / `CLAUDE.md` は
    `.claude/rules/*.md` を `@import` していない。読み込み条件の切り分けが要る。
  - `.claude/settings.json` の `permissions.deny` には、コミット操作をprefixで拒否するパターンが
    実際に登録されている。issue本文が言う「1行目コメントで前方一致が外れる」の裏付け対象。
  - `.claude/hooks/block-direct-git-commit.sh` は `tool_input.command` 全体を正規表現で検査して
    おり、コメント行も検査対象に入る。
- **本セッション自体でhookの誤検知を再現した**: HANDOFF.mdの地の文へ上記のdenyパターンを
  そのまま書いてBashツールへ渡したところ、PreToolUse hookがブロックした。issue #47が扱う論点の
  実例として記録しておく。

### 敵対的レビュー（フェーズ2・1回目）

flow-id 2-2 のpush直後に `adversarial-review` スキルを起動した（ユーザーの明示指示による。
`SKILL.md`「敵対的レビューの位置づけ」の原則に対する例外である点は全体作業計画に明記した）。
**進捗表は動かしていない**（敵対的レビューはflow-idを持たないため）。

- 実施回数: フェーズ2で1回目（上限3回。`adversarial-review-count.sh` が強制）。
- 指摘13件。確度×重大度の基準で**5件をPR #132 へインライン投稿**し、8件は投稿せず記録に留めた
  （投稿分の一覧はPRのレビューサマリにある）。
- **13件すべてを計画へ反映した。** 主なもの:
  - 検証節が存在しないオプション（`--query`）を使っており必ず失敗する → `--text` へ修正し、
    さらに「`--text` が見るのはfrontmatterだけで本文は見ない」ことを実測で確かめて注記した。
  - **hookの `if` の発火実績を `permissions` の前方一致の根拠に使う計画になっていた** →
    別物として扱うと明記し、無害なパターンでの実測手順へ置き換えた。自分がこの往復の直前に
    出していた実測の解釈も、射程を広げすぎていたのでworklogで訂正した。
  - 受け入れ条件1（読み込まれることを確認できている）を満たす手段が計画に無かった →
    新規ファイルでの実測ステップを、個別調査計画とフェーズ3の検証の両方へ置いた。
  - 敵対的レビューの回数上限が計画に無く、額面どおり進めると途中で実行不能になる →
    上限到達時の切り替え方を明記した。

## 次にやること

1. **flow-id 2-5**: `describe` で調査計画をもとにMR descriptionを更新する。**代替対象は人間担当の
   ステップ（2-3/2-8等）だけであり、2-4・2-5 はエージェント担当なので飛ばさない。**
2. **flow-id 2-6**: `plans/【調査】ルール自動読込条件とコマンド文字列の前方一致.md` の調査項目
   1〜4を実施し、結果を `reports/20260820_prancy-prancing-dewdrop_ルール読込条件と前方一致の調査.md`
   （正文）と同名 `.html`（視覚化）へ記録する。
   - 調査1は**新規ルールファイルが実際に読み込まれるか**の実測まで含む（既存ファイルの観測では
     受け入れ条件1を満たさない）。本セッションで確かめられなければユーザーへ確認を依頼する。
   - 調査2は `.claude/settings.local.json` へ無害なパターンを一時的に置く実測を試みる。
     **実行後に必ず削除し、コミットしない。**

## 判断を迷った内容

- **ブランチ名がリポジトリ規約と異なる**。`.mrworkflow.json` の `branchPrefixTemplate` は
  `feature-<issue番号>-<slug>` だが、ハーネスが `claude/multiline-command-japanese-comments-k8c2pr`
  を指定しており、そちらを優先した。`get_issue_number_from_branch` はこのブランチ名から
  issue番号を抽出できないため、SessionStart hookの注入では「issue: 特定できず」になる。
- **進捗表をこのブランチで新規に組み立てた**。`cleanup-task.sh` が書き戻すHANDOFF.mdのテンプレートは
  進捗表を持たず「（次タスク着手時に記入する）」となっているため、`SKILL.md` のフロー表から機械的に
  生成した（手写しの転記ミスを避けるため）。ステップ列は最初の句点・括弧までに縮めている。

## 未解決の内容

- issue本文が根拠とする「`description` はコンソール上1行しか表示されない」は**issue起票時の実機
  確認**であり、本セッションでは再現確認できない（リモート実行環境にコンソール表示が無いため）。
  ルール本文には「issue #47 起票時の実機確認」と出典を明記する形で扱う予定。
- 「1行目コメントで `permissions.allow` / `deny` の前方一致が外れる」の裏付けが取れるかは未確定。
  取れなかった場合の記述の落とし方はフェーズ2で決める。

## 守るべき条件・触ってはいけない範囲

- **push先はハーネス指定ブランチ `claude/multiline-command-japanese-comments-k8c2pr` のみ**。
  他ブランチへpushしない。
- **マージ（flow-id 5-5）は行わない**。ユーザーの明示指示があるまで flow-id 5-4 で止まる。
- コミットは必ず `commit` スキル（`.claude/scripts/src/create-commit.sh`）経由で行う。
- DDR番号は `main` の進行で重複しうる。flow-id 5-1 の `check-base-conflicts.sh` を必ず通す。
