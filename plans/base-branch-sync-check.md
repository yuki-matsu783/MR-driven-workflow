---
title: 【全体作業計画】作業開始・再開時のベースブランチ追従確認をフローへ追加する（issue #67）
type: plan
description: issue #67 の全体作業計画。作業開始・再開時にベースブランチの最新を取り込めているかを確認するステップを、検知スクリプト・フロー定義・resumeサブエージェントの3層で追加する。
tags: [plan, issue-mr-flow, base-branch, sync]
keywords: [ベースブランチ, 追従確認, behind, resume, start, check-base-sync, コンフリクト, issue67, フロー, 全体作業計画]
---

# 全体作業計画: 作業開始・再開時のベースブランチ追従確認（issue #67）

- issue: [#67](https://github.com/yuki-matsu783/MR-driven-workflow/issues/67)
- ブランチ: `claude/base-branch-sync-check-17vdvq`（ハーネス指定。`feature-<issue番号>-<slug>` の
  命名規則の対象外）
- ベースブランチ: `main`

## このissueが解こうとしていること

featureブランチでの作業を開始・再開する前に、ベースブランチ（既定 `main`）の最新がその
ブランチへ取り込まれているかを必ず確認し、**古いベースブランチを前提にした実装・レビュー**を
防ぐ。

実例（issue本文より）: issue #60 対応中のセッションで、ローカルの `origin/main` が10コミット
古いまま作業していた。未取得分には `.claude/rules/shell-script-style.md` へのルール追記が
含まれており、作業中のルール判断に影響しうる状態だった。

## 既存の3つの機構との役割の違い（重複させない）

| 機構 | いつ | 何を見るか | issue |
|---|---|---|---|
| flow-id 5-2 コンフリクト検知（`check-base-conflicts.sh`） | マージ依頼の直前 | **衝突するか**（テキスト競合・DDR番号重複） | #46 |
| PR作成後のdefaultブランチ追従（監視） | PR作成〜マージの間、随時 | 同上（衝突の有無） | #88 |
| **本issue** | **作業を開始・再開する時点** | **遅れているか**（behindコミット数・未取り込みの変更ファイル） | #67 |

**「衝突しないこと」と「最新であること」は別である。** ベースブランチ側でルール・仕様だけが
追記された場合、コンフリクトは1件も起きないが、作業ブランチはそのルールを知らないまま実装・
レビューを進めることになる。既存の2機構はどちらも `hasConflict` を判定軸にしているため、
この状態を検知できない。本issueはこの空白を埋める。

## 方針（比較検討した案）

| 案 | 内容 | 判断 |
|---|---|---|
| A: `sync_branch()` を拡張し、ベースブランチを自動でマージする | 追従漏れが構造的に起きなくなる | **却下**。issueの受け入れ条件が「無断で取り込まない」ことを求めている。`sync_branch` は `start`/`sync`/`resume` から呼ばれる低レベル関数で、副作用としてマージが走ると作業ツリーが予期せず変わる |
| B: `check-base-conflicts.sh` に behind 判定を相乗りさせる | 新規ファイルが増えない | **却下**。同スクリプトの責務は「衝突するか」であり、判定軸が違う。出力JSONに別軸のキーを足すと、呼び出し側が `hasConflict` だけを見て安心する現在の使い方と噛み合わない |
| **C: 専用の検知スクリプト `check-base-sync.sh` を新設する（採用）** | 作業ツリーを変更せずJSONで状態だけを返し、取り込むかどうかの判断は呼び出し側（AIエージェント→ユーザー確認）へ委ねる | **採用**。`check-base-conflicts.sh` と同じ「検知はスクリプト・判断は人間」の形にそろう |

取り込み方（merge / rebase）は `AskUserQuestion` で選ばせる。ただしこのリポジトリは
`resolve-conflict` スキル・`.claude/rules/git-workflow.md` で **rebase を使わない方針**を
明示しているため、既定の推奨は merge とする。

## フェーズ2〈調査〉

- `sync_branch()` / `check-base-conflicts.sh` / `resume`（`issue-mr-resume` エージェント）が
  現状ベースブランチの遅れをどこまで見ているかを確認する
- 追従確認を差し込む地点（`start` の既存ブランチ検出時・`resume`・`sync`）と、それぞれで
  何が既に fetch 済みかを確認する
- behind コミット数・未取り込み変更ファイルを求める git コマンドの選定（`rev-list --count` /
  `diff --name-only` の3点リーダ記法）と、その境界条件（ベースブランチのリモート追跡が無い場合、
  fetch 前後で結果が変わる場合）を確認する
- 結果は `reports/` のmd（正文）とHTMLへ記録する

## フェーズ3〈作業〉

1. `.claude/scripts/src/check-base-sync.sh` を新設する（作業ツリーを変更しない。JSONを1つ出力）
2. `.claude/scripts/test/test_check_base_sync.sh` を新設する（副作用の無い純粋ロジックの単体テスト）
3. `.claude/skills/issue-mr-flow/SKILL.md` に「作業開始・再開時のベースブランチ追従確認」節を
   追加し、`start`（既存ブランチ検出時）・`resume`・`sync` の各手順から参照させる
4. `.claude/agents/issue-mr-resume.md` の調査手順と現在地サマリへ「ベースブランチとの差分」を追加する

## フェーズ4〈反映〉

反映対象は flow-id 4-1 で洗い出す。現時点の見込みは次のとおり（確定ではない）。

- **設計反映**: `.claude/docs/spec/check-base-sync.md`（新規）・`.claude/docs/spec/issue-mr-workflow.md`
  の影響範囲への追記・DDR（採用理由と却下案A/B）
- **AIアセット反映**: `.claude/rules/git-workflow.md`（追従確認の入口の1行）

## フェーズ5〈クローズ〉

`cleanup-task.sh` → コンフリクト検知（flow-id 5-2）→ 関連issue通知（5-3）→ Draft解除（5-4）。
マージ（5-5）はユーザーの明示指示を待つ。

## 承認記録

- 2026-08-19 ユーザーより、本セッションでの Draft PR 作成の承認を得た（flow-id 1-3。ハーネスが
  PR作成を制限する環境のため `AskUserQuestion` で1回確認した）
- 2026-08-19 ユーザーより、「フェーズごとに自動で敵対的レビューをすること」は**本セッションの
  進め方の指示**であり、`adversarial-review` スキルの起動ポリシー（対話セッションでは自律起動
  しない）自体を恒久的に変更するものではない、との回答を得た

## 本セッションの制約

- Claude Code on the web のリモート実行環境であり、`gh`/`glab` CLI が無い（MCP経路）
- 人間のレビュー往復（flow-id 2-3/2-8, 3-3/3-8, 4-3/4-8）を待てないため、該当ステップの進捗
  記号は `[]` のまま残し、実施内容は `HANDOFF.md` の「やったこと」で補足する
- 各フェーズのpush直後に `adversarial-review` スキルを自動起動する（ユーザーの明示指示による）
