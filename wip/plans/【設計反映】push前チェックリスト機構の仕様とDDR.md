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
| `i0017-01-…`（`.claude/docs/ddr/` 配下） | 新規 | 採用した方式と**却下案**（下記「DDRに残す却下案」） |
| `.claude/docs/README.md` | 変更 | **手書きのspec一覧**へ1行追加（DDR一覧と違い生成物ではない）。DDR一覧は `generate-ddr-list.sh` の実行で追随させる |
| `.claude/docs/spec/issue-mr-workflow.md` | 変更 | 「コンポーネント構成」のhook・scripts一覧へ**新設3本**（`block-unchecked-push.sh` / `post-push-next-checklist.sh` / `push-checklist.sh`）を追加する。**現在この一覧に1本も載っていない**（`grep -c push-checklist` = 0） |
| `.claude/docs/usecase/` | 確認（必要なら変更） | 既存のユースケース文書への影響。**`新しい機能開発を始める.md` が「フローの途中のコミットはすべて `commit` スキル経由で行われ」と手順を要約しており、commit前にチェックリストを埋める手順が入る本変更の射程に入る**。影響が無いと判断した場合もその旨を反映結果へ書く（flow-id 4-6 の定義が確認を求めている。issue #170） |
| `.claude/rules/docs-workflow.md` | 変更 | ライフサイクル運用表へ、チェックリスト（`wip/worklogs/*_checklist.tsv`）の行を追加 |
| `.claude/rules/directory-structure.md` | 変更 | `wip/worklogs/` の説明。**`.md` 以外（`.tsv`）が置かれるようになる**ためツリーの注記が古くなる |
| `index.md` | 変更 | Repository Map の該当行 |
| `.claude/skills/commit/SKILL.md` | 変更 | commitの**前に** `check`/`skip` を実行し、チェックリストを同じcommitへ含める手順 |
| `.claude/skills/issue-mr-flow/SKILL.md`（または `references/` 配下） | 変更 | 同上をフロー側からも辿れるようにする。**節を増やすか参照1行に留めるかは、SKILL.md の分量方針に従う** |
| `.claude/VERSION` | 変更 | MINOR を増分する。**増分の根拠に数えるのは、`【AIアセット反映】` 側で書き換える配布層 core の資産（`shell-script-style.md` / `mcp-fallback.md`）も含めた両計画の合算**である（`distribution-assets.md` は更新タイミングを flow-id 4-6 と規定しており、2つの計画が同じフェーズにあるため）。**版を持つのは本計画1つに固定する**（両方が触ると二重に上がる）。**非対話セッションの例外条件を満たすこと**——(1) 適用した事実と根拠を **spec のchangelog と `HANDOFF.md`「判断を迷った内容」の両方**へ残す、(2) レビューで人間が否認したら元の値へ戻す（`.claude/docs/spec/distribution-assets.md`） |

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

**着手前に、変更前のツリーで全件を実行し、期待どおり非0（または期待と違う値）になることを確かめる。**
敵対的レビュー1回目で、変更前から通る空振りが2件見つかったため（旧3・旧4）。

| # | 何を確かめるか | コマンド | 変更前 | 期待 |
|---|---|---|---|---|
| 1 | DDR一覧へ `i0017-01` の行が入った | `bash .claude/scripts/src/generate-ddr-list.sh` 後に `git diff -- .claude/docs/README.md \| grep -c '^+.*i0017-01'` | 0 | **1以上** |
| 2 | DDRの参照切れが無い | `bash .claude/scripts/src/check-doc-references.sh` の `参照切れ数=` | 0 | **0** |
| 3 | 新規DDRのfrontmatterがインデックスへ載る | `bash .claude/scripts/src/extract-frontmatter.sh .` 後に `bash .claude/scripts/src/search-frontmatter.sh --text 'i0017-01' --type ddr --format count` | **matched=0** | **matched=1** |
| 4 | spec骨組みのプレースホルダが残っていない | `grep -c 'flow-id 4-6 で記述する' .claude/docs/spec/push-checklist.md` | **3** | **0** |
| 5 | spec冒頭の骨組み宣言が残っていない | `grep -c '骨組みである' .claude/docs/spec/push-checklist.md` | **1** | **0** |
| 6 | 既存テストの回帰 | `.claude/scripts/test/test_*.sh` を全件実行し `passed=`/`failures=` を合計 | 23本・1,630・0 | **失敗0**（本数と合計も出す） |
| 7 | 過去の記録を書き換えていない | `git fetch origin main` 後に `git diff "$(git merge-base origin/main HEAD)" -- .claude/docs/ddr/ \| grep -c '^-[^-]'` | 0 | **0行** |

**変更前の値は、着手時に実測して埋める**（上表の「変更前」列は2026-08-24 時点の実測値である）。

- **6・7は「異常が無ければ何も出ない」形なので、件数を必ず出す。**
- 7の分岐点SHAは `git fetch origin main` の直後に `git merge-base` で**その場で求める**
  （値を書き写すと、defaultブランチを取り込んだあとに誤検出へ変わる）。
- **`check-dist-coverage.sh` は検証に入れない。** `.claude/dist-layers.json` が
  `{"layer":"core","path":".claude"}` というディレクトリ単位のエントリを持つため、
  `.claude/` 配下へ何を足しても検査1は必ず被覆され、**成功以外を返しえない**
  （変更前のツリーで実行して `結果: OK（4種すべて通過）` を確認済み）。
  **この結論はフェーズ3の worklog「検証コマンドが検証になっていなかった3件」で既に得ていたのに、
  反映計画で同じ空振りを作り直していた**（敵対的レビュー1回目の指摘）。`.gitignore` へ行を
  足す場合は検査2が意味を持つので、そのときだけ入れる。


## issueの受け入れ条件との対応

| 受け入れ条件 | 本計画で満たすもの |
|---|---|
| 「仕様が `.claude/docs/spec/` に記載されている」 | 変更対象の `.claude/docs/spec/push-checklist.md`（本文化） |
| 「DDRが作成されている」 | 変更対象の `i0017-01-…` |
| 「ライフサイクルが `.claude/rules/docs-workflow.md` に記録されている」 | 変更対象の `.claude/rules/docs-workflow.md` |
| 「更新手順が `issue-mr-flow` / `commit` スキルに記載されている」 | 変更対象の `.claude/skills/commit/SKILL.md` と `.claude/skills/issue-mr-flow/SKILL.md` |
| 「誤ブロックしない条件が定められている」 | 方針の「守れない範囲」と「縮退時の非対称」 |

**対応はファイル名で指す**（行番号で書くと、変更対象表へ行を足すたびにずれる。実際に
敵対的レビュー1回目で1行ずれていた）。

## 比較検討した案

### `git push --tags` / `git push origin --delete <branch>` の扱い

現在の実装は、**現在のブランチを送らないpushもチェックリスト未完了なら一律でブロックする**
（フェーズ3の敵対的レビュー2回目・報告のみ1件）。

**前提として、逃げ道は既に1つ存在する。** `push-checklist.sh` は全項目に `skip <id> <理由>` を
提供しており、`verify` の合格条件は「全行が done **または skip**」である。つまり
**項目単位の文書化された迂回路は最初からある**（フェーズ3の作業結果レポートにも
「緊急時の抜け道は現状『全項目を `skip` する』しかなく、それはspecにもブロックメッセージにも
書かれていない」と書いてあった）。案の比較はこの事実の上に立つ。

| 案 | 内容 | 評価 |
|---|---|---|
| **A（採用）** | 一律ブロックのままにし、**詰まったときは `skip` で解く**ことをspecとブロックメッセージへ明記する | pushの**引数**を解釈する必要が無い。逃げ道を新設せず、既にあるものを使う |
| B | `--tags` / `--delete` / 明示的なrefspecを判定して通す | **却下**。refspec・`--all` / `--mirror`・`push.default` の設定まで解釈しないと正しく判定できず、判定の面積がpush検知本体より大きくなる。issue #17 のコメントが「push検知を自前で書くな」と指示した理由と同種のリスク |
| C | 環境変数等による**新しい**無効化スイッチを用意する | **却下**。`skip` で足りるものを二重に作ることになる。`block-direct-git-commit.sh` が無効化スイッチを持っていないのとも揃わない |

**AとCの違いは「新設するか、既にあるものを使うか」だけである。** Cを却下しながらAを採るのは、
`skip` が**項目ごとに理由を書かせ、その理由がGit管理下のdiffに残る**——つまり迂回した事実が
レビュアーに見える——のに対し、環境変数のスイッチは何も残さないためである。

**Aを採る決め手は、誤りの向きの非対称である。** Bが誤ると**通してはいけないpushを通す**
（ガードが黙って効かなくなる）。Aの誤りは**通すべきpushを止める**だけで、その場で見えるうえ
必ず解ける（縮退時に解けなくなる経路は敵対的レビュー2回目で塞いだ）。

**Aのコストは0ではない。** 正確には次のとおりで、specへもこの形で書く。

- **本リポジトリの現時点のフローでは0**（`--tags` も `--delete` も行わない）。
- 詰まった場合の実コストは「全項目を `skip` で埋めて**1コミット積む**」ことである
  （`verify` はHEAD断面を読むので、作業ツリーだけ埋めても解けない）。
- **この機構は配布層 `core` として他プロジェクトへ配られる。** タグpushを日常的に行う配布先では
  このコストが繰り返し発生する。**配布先が困った場合の第一手は `skip`、次の手は
  `.claude/settings.json` から本hookの登録を外すこと**である旨をspecへ書く。
