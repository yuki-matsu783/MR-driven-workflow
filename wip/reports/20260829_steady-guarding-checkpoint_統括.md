---
title: 20260829. push前チェックリスト機構（issue #17）最終統括レポート
type: report
description: issue #17「hookを使ってpush時にしてほしいことを実現する」の全フェーズ（調査・実装・反映・クローズ）を1枚にまとめた最終統括レポート。
tags: [push-checklist, hook, workflow, 統括レポート]
keywords: [push前チェックリスト, PreToolUse, PostToolUse, block-unchecked-push, post-push-next-checklist, 敵対的レビュー, DDR, VERSION, gemini同期]
---

# 20260829. push前チェックリスト機構（issue #17）最終統括レポート

## 何を変えたか

- **push前チェックリスト機構**を新設した。`worklogDir`配下へpush単位でユニークなTSVファイル
  （`<日付>_<ブランチスラッグ>_push<N>_checklist.tsv`）をGit管理下に作り、AIエージェントが
  commit前に5項目（`worklog`/`handoff`/`frontmatter-index`/`plan-report-sync`/`commit-skill`）を
  `check`（実施ログ付き）または`skip`（理由付き）で記録する。
- **PreToolUse hook（`block-unchecked-push.sh`）** が、未完了項目が残っている状態でのpushと
  チェックリストのコミット忘れ（`stale`）の両方を **exit code 2** でブロックする。
  未完了項目名・`check`/`skip`の使い方・参照すべきルールファイルのパスをメッセージへ含める。
- **PostToolUse hook（`post-push-next-checklist.sh`）** が、push成功後に次回push用のチェックリストを
  自動生成する（HEADが公開済み・同じHEAD SHAで二重生成しない・タスク成果物が残っている、の
  3条件をすべて満たすときだけ）。
- **push検知は自前で書かず**、`.claude/hooks/lib/CommandPosition.sh`の`command_invokes_git_subcommand`
  へ委譲した（issue #17のコメントによる指示）。縮退時（同ライブラリを読めない場合）のフォールバックは
  専用関数`command_hints_at_git_push_degraded`を用意し、回復コマンド自身（`push-checklist.sh check`）が
  誤ってブロックされないようにした。
- **既存のpush系hook2本（`post-push-usage-report.sh`/`post-push-compact-prompt.sh`）のロジックは
  1バイトも変更していない。**
- 関連ドキュメント（spec・DDR・`commit`/`issue-mr-flow`のSKILL.md・一覧系ドキュメント・
  `shell-script-style.md`等）を追随させ、`.claude/` → `.gemini/`の変換同期も実施した。

## なぜそうしたか

- **push成否の判定は `HEAD == @{upstream}` ではなく `git branch --remotes --contains HEAD`。**
  一時リポジトリでの実測により、当初案が両方向へ誤ることを確認した。
- **ブロック条件は否定形（「通してよい」と確認できたときだけ通す）にした。** 肯定形（「ブロック
  条件に当たったら止める」）は取りこぼしに弱い。
- **コミット忘れ（`stale`）も exit 2 でブロックする。** 当初 exit 1（警告）だったが、本機構の動機
  そのもの（更新のcommit漏れ）に当たる経路が唯一ブロックされないままだった（フェーズ3の敵対的
  レビューで blocker として指摘）。
- **`--tags` / `--delete` のような現在のブランチを送らないpushも一律ブロックする。** 引数を解釈する
  判定は書かず、機構が既に持つ `skip`（理由がGit管理下のdiffに残る）で解く方針を採った。環境変数等の
  無効化スイッチは作らなかった（`block-direct-git-commit.sh`が持たないのと揃え、`skip`との違いを
  「迂回した事実がレビュアーに見えるかどうか」に保つため）。詳細・却下案は
  DDR `i0017-01`「6. pushの引数を解釈せず、一律でブロックする」。
- **縮退時のフォールバックに前置フィルタをそのまま流用しない。** 過剰検知がそのまま `exit 2` になり、
  回復のために叩く `push-checklist.sh check` 自身がパスに`push`を含むため必ずブロックされ、縮退環境
  から自力で回復できなくなるため。**ただしこの禁止はブロック判定に限る**——`post-push-next-checklist.sh`
  （生成するだけで過剰検知が冪等に吸収される）は前置フィルタをそのまま流用しており、この非対称は
  DDR `i0017-01`「4. 縮退時のフォールバックに、前置フィルタを流用しない」に明記した
  （フェーズ4の敵対的レビュー2回目で、この条件が規約に明記されていないと指摘され追記）。
- **`commit-skill`項目は「単一コミットで完結するpushでは`skip`する」と明記した。** 文言が完了形
  （「commitスキル経由でコミットした」）のため、Step 3.5時点ではそのコミット自体が存在せず原理的に
  `done`にできない構造だった（フェーズ4の敵対的レビュー2回目で発覚。`commit`スキルSKILL.mdへ分岐を
  追記して解消）。
- **`.claude/VERSION`は本issueでは動かさなかった。** フェーズ5の先行確認で、`main`（PR #194）が
  既に同じ値まで上げていたと判明したため（issue #155に同型の前例あり）。

## 検証結果

- 単体テスト: **24ファイル・1,739アサーション・失敗0**（`test_install_to_project.sh`のdirtyガード
  により作業ツリー状態で±1変動する既知の性質。不変なのは`failures=0`）。
- `check-doc-references.sh`: 参照切れ **0件**。
- `generate-ddr-list.sh --check`: DDR一覧に差分なし。
- `sync-gemini-assets.sh --check`: `.gemini/`が`.claude/`と同期していることを確認。
- 実運用での自己適用確認: **このPR自身が、push1〜21回すべてで本機構のチェックリストを埋めて
  進んだ**（生成→未完了でexit 2ブロック→埋めて通過→次回分の生成、の一巡を実地確認済み）。
- `main`取り込み後の統合検証（flow-id 5-1）: 4ファイルのテキストコンフリクトを解消し、単体テストが
  失敗0であることを確認してコミット（`aee879d`）。

## spec・DDRへの反映先

- `.claude/docs/spec/push-checklist.md`（新規）: 背景・目的、構成要素、ファイル形式、サブコマンドと
  終了コード、ブロック・生成の条件、push検知の委譲先、縮退時フォールバックの扱い、`skip`による逃げ道、
  未決定事項・懸念点。
- `.claude/docs/ddr/i0017-01-push前チェックリストはGit管理下のTSVで持ちPreToolUseで一律ブロックする.md`
  （新規）: 8つの決定（TSV形式・作業ツリー/HEAD非対称・push検知の委譲・縮退時フォールバック・
  `stale`のブロック化・引数一律ブロック・`HEAD==@{upstream}`不採用・チェック項目の非外部化）と
  却下案。
- `.claude/rules/docs-workflow.md`: push前チェックリストのライフサイクルを運用表へ追記。
- `.claude/skills/commit/SKILL.md`（Step 3.5）・`.claude/skills/issue-mr-flow/SKILL.md`: チェック
  リスト記入手順の明記。
- `.claude/rules/shell-script-style.md`: 実装中に得た3件の知見（`${N-既定}`と`${N:-既定}`の違い・
  縮退時フォールバックへの前置フィルタ流用の適用条件）。
- `wip/reports/REVIEW-POINTS.md`・`wip/plans/REVIEW-POINTS.md`: レビュー観点の追加。
- `.claude/skills/issue-mr-flow/references/mcp-fallback.md`: MCPページネーションの罠（実測範囲の
  明確化）。

## 残課題

- **hookの誤ブロックの再現条件が未特定。** 実装中に長いコマンドが2回`stale`でexit 2された事象を、
  `command_invokes_git_subcommand`単体（8ケース）・hook実プロセス（6ケース）・ANSI-Cクォート仮説
  （3ケース）のいずれでも再現できず、判定の誤りだったのか当時`stale`が真だったのかも切り分けられて
  いない。再現条件が不明なため実装は変更せず、仕様の「未決定事項」として明記した。再発時は`stale`
  メッセージが出す実際の値から追うこと。
- **人間の承認をまだ得ていない判断が2件ある**（非対話セッションのため独断で決めている）。
  1. 敵対的レビューの回数配分（フェーズ4を2種別まとめて1回・予備1回で実施）。
  2. `--tags` / `--delete` を一律ブロックのままにしたこと。
- **`--tags` / `--delete`の引数解釈による選択的ブロックは実装していない。** 一律ブロック＋`skip`で
  解く方針のため。配布先で頻発する場合の次の手（`.claude/settings.json`からのhook登録除外）はspecへ
  明記済み。
- **マージ（flow-id 5-7）は、ユーザーの明示的な指示があるまで行わない。**
