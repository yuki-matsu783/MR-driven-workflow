---
title: 【設計反映】push前チェックリスト機構の仕様とDDR
type: plan
description: issue #17 のフェーズ4のうち、spec本体・DDR i0017-01・一覧系ドキュメント・SKILL.md・VERSION への設計反映を行う個別反映計画。
tags: [issue-mr-flow, plan, spec, ddr]
keywords: [設計反映, push-checklist, DDR, spec, docs-workflow, directory-structure, VERSION, 却下案]
---

# 【設計反映】push前チェックリスト機構の仕様とDDR

## 前提（合意状況）

- 上位: 全体作業計画 `wip/plans/steady-guarding-checkpoint.md`（フェーズ4〈反映〉の節）。
- フェーズ2・3は完了している。反映の元になる正文は次の2本。
  - 調査結果 `wip/reports/20260823_steady-guarding-checkpoint_push前チェックリスト機構の設計調査.md`（Q1〜Q8）
  - 作業結果 `wip/reports/20260823_steady-guarding-checkpoint_push前チェックリスト機構の実装.md`
- `.claude/docs/spec/push-checklist.md` は**骨組みだけが既に存在する**（flow-id 3-6 で、
  ブロックメッセージからの参照先を成立させるために置いた）。本計画はこれを本文で埋める。
- **本セッションは非対話**のため、人間のレビュー（flow-id 4-3・4-8）は `adversarial-review`
  スキルで代替する。フェーズ4の敵対的レビューは**上限3回**である。

## この計画で何をするか

issue #17 で作った機構の**正史**（`.claude/docs/spec/` と `.claude/docs/ddr/`）を書き、
そこから辿れるように一覧系ドキュメントとフロー定義（SKILL.md）を追随させる。

**この計画はドキュメントだけを扱う。** 実装コード・テストコードは1行も変更しない
（変更が要るなら、それは `【実装反映】` の担当であり、本計画のスコープ外）。

## 変更対象

| ファイル | 操作 | 何を書くか |
|---|---|---|
| `.claude/docs/spec/push-checklist.md` | **本文化** | 骨組みを本文で置き換える。背景・目的／仕様（構成要素・TSV書式・サブコマンド・生成条件・ブロック条件・縮退時の挙動）／影響範囲／設定項目／未決定事項・懸念点 |
| `.claude/docs/ddr/i0017-01-<タイトル>.md` | 新規 | 採用した方式と**却下案**（下記「DDRに残す却下案」） |
| `.claude/docs/README.md` | 変更 | **手書きのspec一覧**へ1行追加（DDR一覧と違い生成物ではない）。DDR一覧は `generate-ddr-list.sh` の実行で追随させる |
| `.claude/rules/docs-workflow.md` | 変更 | ライフサイクル運用表へ、チェックリスト（`wip/worklogs/*_checklist.tsv`）の行を追加 |
| `.claude/rules/directory-structure.md` | 変更 | `wip/worklogs/` の説明。**`.md` 以外（`.tsv`）が置かれるようになる**ためツリーの注記が古くなる |
| `index.md` | 変更 | Repository Map の該当行 |
| `.claude/skills/commit/SKILL.md` | 変更 | commitの**前に** `check`/`skip` を実行し、チェックリストを同じcommitへ含める手順 |
| `.claude/skills/issue-mr-flow/SKILL.md`（または `references/` 配下） | 変更 | 同上をフロー側からも辿れるようにする。**節を増やすか参照1行に留めるかは、SKILL.md の分量方針に従う** |
| `.claude/VERSION` | 変更 | 配布資産（スクリプト1・hook2・spec1・DDR1）の追加に伴い MINOR を増分 |

## 方針

- **specは「今どうなっているか」だけを書く。** 経緯・却下案はDDRが持つ。両者へ同じことを
  書かない（二重管理を避ける）。
- **`wip/reports/` を参照先にしない。** flow-id 5-5 で削除されるため、恒久の参照先になれない
  （`.claude/rules/docs-workflow.md`）。specから辿れるのは issue番号と `.claude/docs/` 配下だけ。
- **specに必ず書く「守れない範囲」**（調査結果「設計への反映」4 が挙げたもの）。
  1. `git push` 以外のリモート反映手段（IDEのGUI等、Bashツールを通らない経路）は守れない。
  2. `.claude/settings.json` の `if` フィルタの照合規則は未解明である。
  3. `tool_response` を当てにしていない。
  4. **チェック状態はAIエージェントの自己申告である**。`check` は状態を `done` にするだけで、
     その項目が実際に行われたかは検証しない。防ぐのは「やるべきことの存在を忘れる」ことで
     あって、「やったと偽る」ことではない。
- **specに必ず書く「縮退時の非対称」**（フェーズ3の敵対的レビュー2回目の blocker）。
  PreToolUse は専用の絞り込み（`command_hints_at_git_push_degraded`）を使い、PostToolUse は
  前置フィルタを流用する。**この非対称は意図的**で、生成は冪等だがブロックは1度でも誤ると
  作業が止まるためである。
- **`--tags` / `--delete` は一律ブロックのままとし、逃げ道を実装しない**（下記「比較検討した案」）。
  この判断と理由をspecの「未決定事項・懸念点」ではなく**「仕様」として**書く（未決定ではなく
  決めた結果であるため）。
- **既知の性質を隠さない**。specへ書く既知の性質は次の2つ。
  1. 生成条件3（HEADにタスク成果物が残っているか）が**チェックリスト自身を成果物に数えている**。
     `cleanup-task.sh` はチェックリストも同じディレクトリごと消すため実害は無いが、
     「チェックリストだけが残っている」状態を作れば生成が続く。
  2. **pushの直後には、必ず未コミットのチェックリストが1本存在する**（issue #17 の
     フェーズ4で気づいた）。PostToolUse が新しいHEADのSHAに対して次回分を生成するため、
     「作業ツリーがクリーンかつリモートと一致」という状態は**pushの直後の一瞬しか成立しない**。
     さらに、その1本をpendingのままコミットすると、今度は `verify` の対象がそれになるため
     **埋めるまでpushできない**（＝pendingでコミットしてから中身を埋めるまでの間、
     ローカルに未pushのコミットが残る）。いずれも運用どおりの姿だが、
     「未コミット・未pushを常にゼロに保つ」種の別の仕組みとは**構造的に両立しない**ので、
     仕様として明記する。

### DDRに残す却下案

| 却下案 | 却下した理由 |
|---|---|
| **チェック項目の実施そのものを機械判定する** | worklogの有無・`index.jsonl` の鮮度は判定できるが、`HANDOFF.md` の内容が正しいかは判定できない。一部だけ機械判定にすると「機械判定された項目だけが信頼できる」という非対称を、仕様の読み手が読み取れない |
| **flow-idに応じて項目を可変にする** | 現在のflow-idを機構が知る手段が `HANDOFF.md` の解析しかなく、チェックリストの正しさが `HANDOFF.md` の正しさに依存する（`HANDOFF.md` の更新漏れこそがこの機構の防ぎたい失敗の1つ） |
| **`.gitignore` 対象の `wip/state/` へ置く** | 受け入れ条件が「レビュアーがPRのdiffで見られること」を求めている。Git管理外では満たせない |
| **縮退時のブロック判定に前置フィルタを流用する** | 実際に実装して踏んだ blocker。「push」を含む全コマンドが `exit 2` になり、**ブロックを解くための `push-checklist.sh check` 自身が止まって回復不能**になる |
| **push成否を `HEAD == @{upstream}` で判定する** | 一時リポジトリでの実測により両方向へ誤ることを確認した（フェーズ2の敵対的レビュー2回目）。`git branch --remotes --contains HEAD` を採用 |
| **`--tags` / `--delete` に逃げ道を実装する** | 下記「比較検討した案」 |

## やらないこと（スコープ外）

- **実装コード・テストコードの変更**（`.claude/scripts/src/` `.claude/hooks/` `.claude/scripts/test/`）。
- **AIアセット（`.claude/rules/` `REVIEW-POINTS.md` `references/`）への副産物の反映。**
  これは `【AIアセット反映】` の担当で、別の個別計画が扱う。
  **ただし `.claude/skills/commit/SKILL.md` と `issue-mr-flow` は本計画に含める**——
  これらは「この機構をどう使うか」という**主たる成果物の手順**であって、作業の副産物ではない。
- `.gemini/` の変換同期（flow-id 5-3 の担当）。
- 統括レポート・片付け（フェーズ5）。

## 検証

| # | 何を確かめるか | コマンド | 期待 |
|---|---|---|---|
| 1 | DDR一覧が生成物として整合している | `bash .claude/scripts/src/generate-ddr-list.sh` の実行後に `git diff --stat -- .claude/docs/README.md` | i0017-01 の行が増える差分だけが出る |
| 2 | DDRの参照切れが無い | `bash .claude/scripts/src/check-doc-references.sh` | 参照切れ0件 |
| 3 | frontmatterがインデックスへ載る | `bash .claude/scripts/src/extract-frontmatter.sh .` の後 `bash .claude/scripts/src/search-frontmatter.sh --text 'push前チェックリスト' --format count` | `matched` が1以上 |
| 4 | 配布層の網羅性が壊れていない | `bash .claude/scripts/src/check-dist-coverage.sh` | `結果: OK` |
| 5 | 既存テストの回帰 | `.claude/scripts/test/test_*.sh` を全件実行 | 全件 `failures=0` |
| 6 | 過去の記録を書き換えていない | `git diff $(git merge-base origin/main HEAD) -- .claude/docs/ddr/` の削除行 | **0行**（DDR本文は追記のみ。分岐点SHAは実行時に求める） |

**5・6は「異常が無ければ何も出ない」形なので、件数を必ず出す。**
6の分岐点SHAは、`git fetch origin main` の直後に `git merge-base` で**その場で求める**
（値を書き写すと、defaultブランチを取り込んだあとに誤検出へ変わる）。

## issueの受け入れ条件との対応

| 受け入れ条件 | 本計画で満たすもの |
|---|---|
| 「仕様が `.claude/docs/spec/` に記載されている」 | 変更対象1行目（spec本体） |
| 「DDRが作成されている」 | 変更対象2行目（`i0017-01`） |
| 「ライフサイクルが `.claude/rules/docs-workflow.md` に記録されている」 | 変更対象4行目 |
| 「更新手順が `issue-mr-flow` / `commit` スキルに記載されている」 | 変更対象8・9行目 |
| 「誤ブロックしない条件が定められている」 | 方針の「守れない範囲」と「縮退時の非対称」 |

## 比較検討した案

### `git push --tags` / `git push origin --delete <branch>` の扱い

現在の実装は、**現在のブランチを送らないpushもチェックリスト未完了なら一律でブロックする**
（フェーズ3の敵対的レビュー2回目・報告のみ1件）。

| 案 | 内容 | 評価 |
|---|---|---|
| **A（採用）** | 一律ブロックのままにし、**そういう仕様であることと、必要になったときの対処**をspecへ明記する | pushの**引数**を解釈する必要が無い |
| B | `--tags` / `--delete` / 明示的なrefspecを判定して通す | **却下**。refspec・`--all` / `--mirror`・`push.default` の設定まで解釈しないと正しく判定できず、判定の面積がpush検知本体より大きくなる。issue #17 のコメントが「push検知を自前で書くな」と指示した理由と同種のリスクである |
| C | 環境変数等による一時的な無効化スイッチを用意する | **却下**。文書化された迂回路は迂回路であり、`block-direct-git-commit.sh` が同じ判断（悪意ある回避への対策は行わない＝既定を確実な方向へ倒すだけの仕組み）で無効化スイッチを持っていないのと揃える |

**Aを採る決め手は、誤りの向きの非対称である。** Bが誤ると**通してはいけないpushを通す**
（ガードが黙って効かなくなる）。Aの誤りは**通すべきpushを止める**だけで、その場で見えるうえ、
チェックリストを埋めれば必ず解ける（縮退時に解けなくなる経路は、敵対的レビュー2回目で塞いだ）。
本フローは `git push --tags` も `--delete` も行わないため、Aのコストは現時点で0である。
