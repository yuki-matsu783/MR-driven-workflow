---
title: hookによるpush前チェックリストの強制（issue #17）
type: plan
description: push前チェックリストをGit管理下のTSVとして持ち、PreToolUse hookで未完了pushをブロックする機構を作る全体作業計画。
tags: [issue-mr-flow, hook, push, checklist]
keywords: [push前チェックリスト, PreToolUse, PostToolUse, exit code 2, CommandPosition, TSV, worklogs, ライフサイクル, 誤ブロック, DDR]
---

# hookによるpush前チェックリストの強制（issue #17）

## 前提（合意状況）

- 依拠するissue: #17（目的・現状・期待する動作・受け入れ条件）
- issue #17 へのコメント（2026-08-21）で、issue #53 により hook の検知が
  **コマンド位置ベース**（`.claude/hooks/lib/CommandPosition.sh` の
  `command_invokes_git_subcommand`）へ変わったことが通知されている。**判定を自前で書かず、
  このライブラリを使う**。
- 本セッションは非対話（Claude Code on the web のリモート実行環境）である。人間のレビュー往復
  （flow-id 2-3/2-8/3-3/3-8/4-3/4-8）は成立しないため、**各フェーズの計画時に1回・作業実施時に
  1回、`adversarial-review` スキルによる敵対的レビューを自動実施し、その指摘へ対応する**
  （ユーザーからの明示指示）。
- ブランチ名は `.mrworkflow.json` の `branchPrefixTemplate`（`feature-{issue}-{slug}`）に従わない
  `claude/hook-implementation-17-vjhppj` である。**ハーネスがこのブランチでの開発を指定している**
  ため、命名規則より指定を優先する。

## この計画で何をするか

**push前チェックリスト**をGit管理下のTSVファイルとして持ち、

1. AIエージェントがcommit前に各項目を記録し、同じcommitへ含める、
2. **PreToolUse hook** が未完了項目の残る状態でのpushを exit code 2 でブロックする、
3. **PostToolUse hook** がpush成功後に次回push用のチェックリストを生成する、

という3点を機構として成立させる。あわせて仕様（`.claude/docs/spec/`）・設計判断（DDR）・
ライフサイクル（`.claude/rules/docs-workflow.md`）・フロー定義（`issue-mr-flow` / `commit`
スキル）へ反映する。

## 変更対象

全体作業計画の粒度のため、**ファイル群・領域**で示す（個々のファイル・行はフェーズ3・4の
個別計画で確定させる）。

| 領域 | 操作 | 何をするか |
|---|---|---|
| `.claude/scripts/src/` | 新規 | チェックリストの生成・チェック記録・検証を行うスクリプト（1本） |
| `.claude/hooks/` | 新規 | pushをブロックするPreToolUse hook、次回分を用意するPostToolUse hook |
| `.claude/scripts/test/` | 新規 | 上記の単体テスト（`passed=N failures=N` 規約） |
| `.claude/settings.json` | 変更 | 新規hookの登録 |
| `.claude/VERSION` | 変更 | 配布資産の追加に伴う版の増分（目安 MINOR）、または据え置き |
| `.claude/docs/spec/` | 新規 | push前チェックリストの仕様 |
| `.claude/docs/ddr/` | 新規 | 配置場所・拡張子・ブロック方式の設計判断（`i0017-NN`） |
| `.claude/rules/docs-workflow.md` | 変更 | ライフサイクル運用表への行追加 |
| `.claude/skills/issue-mr-flow/`・`.claude/skills/commit/` | 変更 | commit前のチェックリスト更新手順の明記 |
| `.claude/docs/README.md`・`index.md`・`.claude/rules/directory-structure.md` | 変更 | **手書きのspec一覧への行追加**（`generate-ddr-list.sh` の生成対象ではない）・DDR一覧の再生成・Repository Map・ディレクトリ構成の追随 |
| `.gemini/` | 生成 | flow-id 5-3 の `sync-gemini-assets.sh` で変換同期 |

## 方針

- **判定ロジックを自前で書かない。** pushの検知は `CommandPosition.sh` の
  `command_invokes_git_subcommand "$command" push` に委譲し、bash 4.3未満・ライブラリ不在時の
  縮退は既存hook（`block-direct-git-commit.sh`）と同じ形で持つ。
- **前置フィルタを置く。** PreToolUse hookは、既存の `block-direct-git-commit.sh` と同じく
  **判定が単純な文字列一致に収まらない**ため `if` を使わず自前判定する（＝全Bash/PowerShell
  呼び出しで起動する）。**「PreToolUseでは `if` を使えない」という制約があるわけではない**
  （`.claude/rules/shell-script-style.md`「hookの前置フィルタ」が言う「持てない」はGemini CLIの
  hook設定のこと。`if` の可否そのものはフェーズ2 Q6で確かめる）。したがって`.claude/rules/shell-script-style.md`「hookの前置フィルタ」の型
  （bash組み込みのみ・ゼロfork・判定本体の**超集合**）を独立した純粋関数として実装する。
- **誤ブロックを避ける側へ倒す（暫定。確定はフェーズ2 Q5）。** チェックリストが存在しない＝
  フロー対象外とみなし、ブロックしない。ブロックするのは「チェックリストが存在し、かつ未完了
  項目が残る」場合に限る。**ただしこの方針は、生成済みのチェックリストをコミットし忘れると
  機構が無言で無効化される経路を作る**ため、素通りしたことを（ブロックせずに）通知する縮退を
  置くかどうかをQ5で併せて判断する。
- **既存のpush系hook 2本（`post-push-usage-report.sh`・`post-push-compact-prompt.sh`）と
  責務を分離する。** 既存2本は「push後に情報を伝える」もので、本機構は「pushの可否を検査する」
  ものである。既存ファイルへ処理を足さず、新規ファイルとして持つ。
- **拡張子は `.md` にしない。** `wip/worklogs/` へ `.md` を増やすと `extract-frontmatter.sh` の
  走査対象になり、`index.jsonl` が毎push書き換わる（issue #36 が外した競合を作り直す）。

## フェーズ2〈調査〉

**実施する。** 設計を確定させるために答えを出す問いは次のとおり。

1. チェックリストの**置き場所と命名**をどうするか。issue本文は `worklog/…_push_checklist.tsv`
   と書いているが、issue #165 で `worklog/` は `wip/worklogs/` へ改名されている（根拠:
   `.claude/docs/spec/cleanup-task.md`「issue #165」節。`#178` はその squash merge の PR番号）。push単位で
   ユニークにする命名（`_push<N>`）と、全体計画名・個別計画名をどう取り出すか。
2. **項目（何をチェックさせるか）**をどう定義するか。固定リストか、flow-idに応じて可変か。
   固定するなら、どの粒度なら「常に実施すべき」と言えるか。
3. **チェック済みの表現**をTSVのどの列で持つか。実施ログをどこまで書かせるか。
4. **PreToolUse hookがどの時点のファイルを読むか**（作業ツリーか、HEADか、index か）。
   「チェックリスト自体をそのcommitに含める」という要件と、pushの直前という実行タイミングの関係。
5. **誤ブロックしない条件**の具体化。チェックリスト未生成・フロー対象外のpush・`--dry-run`・
   `git push` 以外のリモート反映手段をどう扱うか。CommandPosition.sh が縮退する場面
   （8192バイト超・`eval`・bash 4.3未満）でどちら側へ倒すか。
6. **PostToolUse hookの次回分生成**が、既存の `post-push-*.sh` 2本と競合しないか
   （実行順・`if` フィルタ・状態ファイルの持ち方）。
7. **ライフサイクル**（issue本文は flow-id 4-6 での削除を求めるが、現行フローの片付けは
   flow-id 5-5 の `cleanup-task.sh` が担う）。どちらへ寄せるか。
8. 既存hookの**単体テストの型**（`test_block_direct_git_commit.sh`）を、本機構でどう再利用するか。

## フェーズ4〈反映〉

**実施する。** 反映先と内容は次のとおり。

- `.claude/docs/spec/<機能名>.md`: 本機構の仕様（チェックリストの形式・hookの起動条件・
  ブロック条件・誤ブロックしない条件・ライフサイクル）。
- `.claude/docs/ddr/i0017-NN-….md`: 設計判断（配置場所・拡張子・ブロック方式）。issue #17 の
  受け入れ条件が明示的に要求している。DDR追加後は `generate-ddr-list.sh` を実行する。
- `.claude/rules/docs-workflow.md`: ライフサイクル運用表への行追加（issue #17 の受け入れ条件）。
- `.claude/rules/directory-structure.md`・`index.md`: 新規ファイルの配置とRepository Mapの追随。
- `.claude/docs/README.md`: **手書きのspec一覧へ新設specの行を追加**する（DDR一覧は
  `generate-ddr-list.sh` の再生成で追随するが、spec一覧は誰も再生成しない）。
- `.claude/skills/issue-mr-flow/SKILL.md`（および `references/`）・`.claude/skills/commit/SKILL.md`:
  commit前にチェックリストを更新し同じcommitへ含める手順の明記（issue #17 の受け入れ条件）。
- `.claude/settings.json`: hookの登録（`.gemini/settings.json` は flow-id 5-3 で変換生成）。
- `.claude/VERSION`: 本変更は `.claude/` 配下（配布層 `core`）へ資産を追加するため、
  `.claude/docs/spec/distribution-assets.md` の規則に従い**増分（目安 MINOR）を適用するか据え置くかを
  判断し、いずれの場合も根拠を spec の changelog と `HANDOFF.md`「判断を迷った内容」の両方へ残す**
  （非対話セッションでは「何もしない」という選択肢は無い）。
- `.claude/docs/usecase/`: 既存文書への影響を確認し、必要なら更新する。

## やらないこと（スコープ外）

- **issueの分割**。受け入れ条件は「PreToolUse hookがブロックする」「PostToolUse hookが次回分を
  用意する」という同型の成果物（hook）を並列に列挙しており、`wip/plans/REVIEW-POINTS.md` の
  「issue分割のトリガー」に該当する。判定基準「各項目が単独でマージされてもシステムが壊れないか」
  に照らすと、**PostToolUseの生成が無ければPreToolUseの検査対象が存在せず、単独マージでは機能が
  成立しない**ため、**分割しない**と判断した。
- **チェック済み状態の真正性の検証**（AIが実施せずにチェックだけ付けることの防止）。本機構は
  敵対的な安全境界ではなく「既定動作を確実な方向へ倒す仕組み」である
  （`.claude/docs/ddr/i0000-09-…` と同じ立場）。
- **`.claude/settings.json` の `if` フィルタの照合規則の解明**（issue #47 から未解明のまま。
  PreToolUse hookは `if` を使わず自前判定するため、本issueでは触らない）。
- 既存2本のpush系hook（`post-push-usage-report.sh`・`post-push-compact-prompt.sh`）の
  ロジック変更。
- **Gemini CLI経路での動作確認**（`.gemini/` は変換生成物として同期するが、実機確認は行わない）。
- **git bash（Windows）実機での性能計測**（本セッションはLinuxであり、fork単価が桁違いのため
  計測結果を持ち込めない。`.claude/rules/shell-script-style.md` の計測手順に従い、必要性だけを
  記録する）。

## 検証

**ファイル名が `<新規>` のままの行は、フェーズ3の個別作業計画で名前を確定させた時点で本節を
書き換える。** 確定前でも実行できる形（分岐点からの差分に含まれる `.sh` を総なめする）を
併記しておく。

```bash
# 新規スクリプト・hookの構文チェック（名前が確定したら直接指定へ置き換える）
base="$(git merge-base origin/main HEAD)"
git diff --name-only --diff-filter=d "$base"...HEAD -- '*.sh' | while IFS= read -r f; do bash -n "$f"; done

# 単体テスト（passed=N failures=N を出力し、failures=0 であること）
bash .claude/scripts/test/test_<新規>.sh

# 既存テストの回帰（失敗を終了コードへ伝播させ、実行本数も出す。
# 素朴な `for ...; do bash "$t"; done` はループ全体の終了コードが最後の1本のものになり、
# 中間の failures=1 を検出できない）
fail=0; n=0
for t in .claude/scripts/test/test_*.sh; do
  n=$((n + 1))
  bash "$t" || { echo "NG: $t"; fail=1; }
done
echo "実行本数=$n"
[ "$n" -gt 0 ] && [ "$fail" = 0 ]

# 配布定義の網羅性
bash .claude/scripts/src/check-dist-coverage.sh

# DDR一覧の再生成・参照切れ検査
bash .claude/scripts/src/generate-ddr-list.sh
bash .claude/scripts/src/check-doc-references.sh

# .gemini/ の変換同期（flow-id 5-3）
bash .claude/scripts/src/sync-gemini-assets.sh --check
```

合格条件: issue #17 の受け入れ条件（下表）が全件満たされ、上記の各コマンドが失敗しないこと。

## issueの受け入れ条件との対応

| 受け入れ条件 | この計画での対応箇所 |
|---|---|
| チェックリストがpush単位のユニークな命名でGit管理下に作成され、ブランチ間でconflictしない | フェーズ2 問い1 → フェーズ3 実装 |
| レビュアーがPRの差分からチェックリストの実施内容を確認できる | フェーズ2 問い1・3（Git管理下・TSV） |
| commit前にチェックリストを更新し同じcommitに含める手順がルールに明記されている | フェーズ4（`issue-mr-flow` / `commit` スキル） |
| PreToolUse hookが未チェック項目の残る状態のpushを exit code 2 でブロックする | フェーズ2 問い4・5 → フェーズ3 実装 |
| ブロック時のエラーメッセージに未完了項目と参照すべきルールファイルのパスが含まれる | フェーズ3 実装 |
| PostToolUse hookが、push成功後に次回push用のチェックリストを用意する | フェーズ2 問い6 → フェーズ3 実装 |
| チェックリストのライフサイクルが `.claude/rules/docs-workflow.md` の運用表に追記されている | フェーズ2 問い7 → フェーズ4 |
| フロー対象外のpush・チェックリスト未生成で誤ってブロックしない条件が定義されている | フェーズ2 問い5 → フェーズ3・4 |
| 既存のpush hook 2本と責務が分離されている | 方針（新規ファイルとして持つ） |
| 仕様が `.claude/docs/spec/` に、設計判断がDDRとして記録されている | フェーズ4 |

## 比較検討した案

確定はフェーズ2の調査結果を待つが、現時点で見えている選択肢を記録する。

| 案 | 利点 | 採否と理由 |
|---|---|---|
| チェックリストを新規スクリプト＋新規hook 2本で持つ | 既存hookの責務を汚さない。受け入れ条件「責務が分離されている」を直接満たす | **採用（暫定）** |
| 既存 `post-push-*.sh` へ次回分生成を相乗りさせる | ファイル数が増えない | **却下（暫定）** 受け入れ条件に反する。既存2本は「push後に伝える」責務で、生成は別関心 |
| チェックリストを `.gitignore` 対象のローカル状態（`wip/state/`）として持つ | 毎pushのdiffノイズが無い | **却下** 受け入れ条件「レビュアーがPRの差分から確認できる」を満たせない |
| 拡張子を `.md` にする | 既存のworklogと揃う | **却下** `extract-frontmatter.sh` の走査対象になり `index.jsonl` が毎push書き換わる（issue #36 の競合の作り直し） |
