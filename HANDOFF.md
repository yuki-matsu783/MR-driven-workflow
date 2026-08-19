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

- issue: #68 issue起票時に類似・重複issueをチェックする手順が無い
- ブランチ: claude/issue-duplicate-check-process-ek26ho
- Draft PR: #74 https://github.com/yuki-matsu783/MR-driven-workflow/pull/74
- push回数: 3

進捗記号: `[x]` 完了 / `[]` 未着手・進行中 / `[-]` 今回は実施しない（スキップ）

**この作業はClaude Code on the webのリモート実行環境（非対話的セッション）で行っている。**
人間担当のレビュー往復ステップ（2-3/2-4, 3-3/3-4, 3-8/3-9, 4-3/4-4, 4-8/4-9）は待てないため、
進捗記号は`[]`のまま残し、実際に実施した内容は「やったこと」で補足する
（`.claude/rules/docs-workflow.md`末尾の非対話的実行環境の規定）。

| 進捗 | flow-id | ステップ | 担当 |
|----|---|---|---|
| [x] | 1-1 | issueを起票する | 人間 |
| [x] | 1-2 | issueの内容を取得する（`gh` CLI不在のため`mcp__github__issue_read`で代替） | `start <issue番号>` |
| [x] | 1-3 | featureブランチとDraft MRを作成する。**ブランチはリモート実行環境から `claude/issue-duplicate-check-process-ek26ho` として用意済みで命名規則には従わないが、issue #68の作業ブランチとして使用**。Draft PR #74 は実装・設計反映の完了後に `mcp__github__create_pull_request` で作成（`gh` CLI不在のため） | エージェント |
| [x] | 1-4 | **全体作業計画**を作成する → `plans/duplicate-issue-check-flow.md`（Planモードを抜けた後のためplanツールではなくWrite/Editで作成） | エージェント |
| [] | 1-5 | 全体作業計画に合意する（非対話的セッションのため未実施） | 人間 |
| [x] | 1-6 | 全体作業計画をもとにHANDOFF.mdを更新する | エージェント |
| [-] | 2-1 | **個別調査計画**（対象ファイル・期待する動作がissue本文に具体的に列挙されており、着手前の読解で足りたためフェーズ2は省略） | エージェント |
| [-] | 2-2 | （2-1を省略のため対象外） | エージェント |
| [-] | 2-3 | （同上） | 人間 |
| [-] | 2-4 | （同上） | `comments` / `reply` |
| [-] | 2-5 | （同上） | `describe` |
| [-] | 2-6 | （同上） | エージェント |
| [-] | 2-7 | （同上） | エージェント |
| [-] | 2-8 | （同上） | 人間 |
| [-] | 2-9 | （同上） | `comments` / `reply` |
| [-] | 2-10 | （同上） | `describe` |
| [x] | 3-1 | 個別作業計画 `plans/【実装】【テスト】類似issue検索関数と起票前チェック手順.md` を作成する | エージェント |
| [x] | 3-2 | `commit`スキル経由でコミットし、リモートへ反映してレビュー依頼を行う | エージェント |
| [] | 3-3 | MRで作業計画についてレビュー・コメントする（非対話的セッションのため未実施） | 人間 |
| [] | 3-4 | レビュー内容を取得し、作業計画を修正する（同上） | `comments` / `reply` |
| [] | 3-5 | 作業計画をもとにMR descriptionを更新する（PR #74 作成時のdescriptionに計画・実装状況をまとめて記載済み） | `describe` |
| [] | 3-6 | 作業計画をもとに作業を進める（**実施済み。** 詳細は「やったこと」。レビュー往復が無いためループ範囲としては`[]`のまま） | エージェント |
| [] | 3-7 | `commit`スキル経由でコミットし、リモートへ反映する（**実施済み。** 同上） | エージェント |
| [] | 3-8 | MRでレビュー・コメントする（非対話的セッションのため未実施） | 人間 |
| [] | 3-9 | レビュー内容を取得し、実装・ドキュメントを修正する（同上） | `comments` / `reply` |
| [] | 3-10 | 作業内容をもとにMR descriptionを更新する（同上） | `describe` |
| [x] | 4-1 | 個別反映計画 `plans/【設計反映】起票前重複チェックの仕様とDDR.md` を作成する | エージェント |
| [x] | 4-2 | `commit`スキル経由でコミットし、リモートへ反映する | エージェント |
| [] | 4-3 | MRで反映計画についてレビュー・コメントする（非対話的セッションのため未実施） | 人間 |
| [] | 4-4 | レビュー内容を取得し、反映計画を修正する（同上） | `comments` / `reply` |
| [] | 4-5 | 反映計画をもとにMR descriptionを更新する（同上） | `describe` |
| [] | 4-6 | 反映計画をもとに設計反映を進める（**実施済み。** spec・DDR 0033・README。レビュー往復が無いためループ範囲としては`[]`のまま） | エージェント |
| [] | 4-7 | `commit`スキル経由でコミットし、リモートへ反映する（**実施済み。** 同上） | エージェント |
| [] | 4-8 | MRでレビュー・コメントする（非対話的セッションのため未実施） | 人間 |
| [] | 4-9 | レビュー内容を取得し、設計の内容を修正する（同上） | `comments` / `reply` |
| [] | 4-10 | 反映内容をもとにMR descriptionを更新する（同上） | `describe` |
| [] | 5-1 | 次タスクのために、`plans/` `worklog/` `reports/` を削除し、`HANDOFF.md` をリセットする | エージェント |
| [x] | 5-2 | defaultブランチとのコンフリクトを検知し、あれば解消する | エージェント |
| [] | 5-3 | `commit`スキル経由でコミットし、リモートへ反映して Draftを解除する | エージェント |
| [] | 5-4 | マージする（squash merge。ブランチは削除してよい） | 人間 |

詳細についてはworklogを確認してください。

## やったこと

issue #68（起票前の類似・重複issueチェック）の実装・設計反映まで、1セッションで通しで実施した。

- **issue内容の取得**: `gh` CLIが実行環境に無いため `mcp__github__issue_read` で代替（DDR 0027）。
  あわせて、変更箇所が重なるissue #59 / #64 の内容も取得して重なりを整理した
  （`plans/duplicate-issue-check-flow.md`「issue #59 / #64 との重なり」節）。
- **実装（flow-id 3-6相当）**:
  - `Provider.sh`: `search_issues <キーワード...>` ディスパッチャ、`merge_issue_search_results`
    （純粋関数）、`SEARCH_ISSUES_LIMIT` / `SEARCH_ISSUES_MAX_KEYWORDS`、`mcp_tool_hint` への行追加。
  - `Github.sh` / `Gitlab.sh`: `*_search_issues` と `*_normalize_issue_search_results`（純粋関数）。
  - `issue-create/SKILL.md`: 実行フローに手順2「類似・重複issueをチェックする」を挿入し、
    以降を繰り下げ。各手順に内容名を併記（後続issueが番号でなく名前で位置を指せるようにするため）。
    「してはいけないこと」に「重複と断定して勝手に起票を中止しない」「手順2を省略しない」を追加。
  - `issue-mr-flow/SKILL.md`: MCPフォールバック対応表に `search_issues` の行を追加。
- **テスト（flow-id 3-6相当）**: `.claude/scripts/test/test_vcs_provider.sh` に9件追加し `passed=53 failures=0`。
  他の4テストスクリプトも実行し全て成功（合計131件）。
- **設計反映（flow-id 4-6相当）**: `.claude/docs/spec/issue-mr-workflow.md` に提供関数表の行・
  「起票前の類似・重複issueチェック」節・影響範囲・未決定事項を追記。
  DDR 0033 を新規作成し `.claude/docs/README.md` の一覧へ追加。

## 次にやること

- **人間によるレビュー**（本セッションでは実施できていない）。特に次の2点は判断が分かれうる。
  - キーワード抽出をbashへ実装せずAI（スキル側）の責務にした判断（DDR 0033の中心的な決定）
  - `search_issues` がキーワードごとにCLIを起動する設計（最大5回。再現率と起動回数の
    トレードオフ）
- `gh` CLIが使える環境での `search_issues` の実機確認（specの「未決定事項・懸念点」に記録済み）。
- flow-id 5-1（`plans/` `worklog/` の削除とHANDOFF.mdのリセット）は、レビュー完了後・
  マージ前に実施する。本セッションでは未実施のため、これらのファイルはブランチ上に残っている。

## 判断を迷った内容

- **キーワード抽出をbashへ実装するか**: issue #68の受け入れ条件が「純粋ロジック部分
  （キーワード抽出等）の単体テスト」と書いていたため、当初は実装する前提で検討した。しかし
  bashでの日本語分割はロケール依存で静かに劣化するため、同条件の「またはテスト不要と判断した
  理由が記録されている」を選び、DDR 0033に理由を残す形にした。
- **HANDOFF.mdのループ範囲の記号**: 3-6/3-7・4-6/4-7は実際に作業を行ったが、同じループ範囲に
  人間のレビュー（3-8/3-9・4-8/4-9）が含まれ「1周完了」とは言えないため、`[x]`にせず`[]`のまま
  残し、実施内容を「やったこと」で補足した（`.claude/rules/docs-workflow.md`末尾の規定に従った）。

- **mainマージ時のコンフリクト解消（flow-id 5-2）**: 3種類を解消した。
  - **DDR番号の衝突（類型A）**: main側に issue #63 の `0031-機構自身の単体テストは.claude_scripts_test配下へ置く.md`
    と issue #57 の `0032-...` が入っていたため、当ブランチのDDRを **0031 → 0033** へ繰り下げた
    （mainが共有の正史であり、マージ済みの番号は動かさない）。ファイル名・frontmatterの`title`・
    本文見出し・`.claude/docs/README.md` の一覧に加え、`Provider.sh` / `test_vcs_provider.sh` /
    `issue-create/SKILL.md` / spec / plans / HANDOFF.md からの参照も更新した。**spec内の
    issue #63のchangelogにある「DDR 0031」は main 由来の別物なので変更していない。**
  - **README・specの近接行（類型C）**: `.claude/docs/README.md` のDDR一覧は両方の行を残して番号順に、
    `.claude/docs/spec/issue-mr-workflow.md` の「未決定事項・懸念点」は main側（issue #57の3件）を
    先に、当ブランチ側（issue #68の1件）を後に置いて統合した。
  - **テストの移動先への追従**: main が `tests/` を `.claude/scripts/test/` へ移動済み（issue #63）
    だったため、当ブランチのテスト追加分はgitのrename検知によって移動先へ自動マージされた。
    あわせて、当ブランチで新規に書いた箇所（spec・plans・worklog・HANDOFF・`Provider.sh` 等の
    コメント）のパス参照を新しい場所へ更新した。**過去issueのchangelogにある `tests/...` の記載は
    point-in-timeの記録なので変更していない。**

## 未解決の内容

- CLI経路（`gh issue list --search` / `glab issue list --search`）が実機未検証。特にGitLabの
  `--all` フラグは `glab` のバージョンによって名称が異なる可能性がある。
- issue #59 / #64 が同じ `issue-create/SKILL.md` の実行フローを変更する予定。先にマージされた
  側に合わせて手順番号を振り直す必要がある（重なりの整理は全体作業計画に記載済み）。

## 守るべき条件・触ってはいけない範囲

- **`create-issue.sh` は変更していない**（重複チェックはスキル側の手順として実装した）。
  スクリプト側で重複を検知して起票を中止する形は、判断を機械に委ねることになるため却下した
  （DDR 0033）。
- DDRの本文は一度マージしたら変更しない（frontmatterのみ後から更新可）。
- コミットは必ず `commit` スキル経由で行う（gitのコミット操作を直接実行するとPreToolUse hookで
  ブロックされる）。
