---
name: harvest-from-projects
description: 本家（このリポジトリ）から他プロジェクトへ配布したAIアセット（.claude/ 一式等）が配布先で改善されたとき、その差分を読み取り専用で分析し、本家へ取り込む候補として issue 起票へ接続する収穫（逆輸入）スキル。配布先の .claude/.asset-manifest.json を読んで modified / added / deleted と衝突有無を分類する。「配布先の改善を本家へ還流したい」「他プロジェクトで直した .claude/ の変更を回収したい」ときに使用する。本家専用（層は exclude。配布されない）。
title: 他プロジェクトからの収穫スキル
type: skill
tags: [harvest, distribution, manifest, skill]
keywords: [逆輸入, 収穫, asset-manifest, dist-layers, scan, diff, merge3, 3-way, 縮退モード, issue-create, 出口レベル]
---

# 他プロジェクトで改善されたAIアセットを本家へ収穫する

## 概要

配布先プロジェクト（`apply-mr-workflow-to-project` スキルで配布した先）でAIアセットが
改善されたとき、その差分を本家へ「収穫（逆輸入）」する起点を作る。

**このスキルの出口は issue 起票（＋任意で個別作業計画の草案）まで**である。本家の正史への
取り込み自体は、起票した issue を起点とする通常の issue-mr-flow で行う（`agent-common.md`
「全タスクはissueを起点に進める」の原則どおり）。

分析はバンドルスクリプトが行い、**本家・配布先のどちらのワークツリーも変更しない**
（書き込みは一時領域のみ。git 操作は読み取り専用のサブコマンドに限る）。

## 前提条件

1. 本家（このリポジトリ）で実行すること（このスキルは `exclude` 層で配布先には配られない）。
2. 配布先のパスがローカルファイルシステムから読めること（リモートは対象外）。
3. `jq` が使えること。

## 手順

### Step 1: 配布先を分析する

配布先パス（複数可）をユーザーから受け取り、`scan` を実行する。

```bash
bash .claude/skills/harvest-from-projects/scripts/harvest-from-projects.sh scan /path/to/projectA /path/to/projectB
```

出力は `{"schemaVersion":1,"targets":[...]}` の JSON 1つ。配布先ごとに:

- `manifestExists` / `degraded`: manifest（`.claude/.asset-manifest.json`）が無い・壊れている
  配布先は `degraded: true` の**縮退モード**になり、`files[]` は確定分類ではなく
  `status: "differs"`（本家HEADとの2-way差分あり）の一覧になる。
- `sourceCommit` / `sourceCommitDirty` / `baseResolvable` / `baseApproximate`: 3-way の base
  （配布時点の内容）が解決できたか。`baseApproximate: true` は記録SHAが `-dirty` 付きで、
  base が配布された内容と一致しない可能性がある（結果は近似として読む）。
- `files[]`: `status`（modified / added / deleted / removedUpstream。縮退モードでは
  differs）・`conflict`（clean / conflict / unknown）・判断材料（`aiAssetCommits` /
  `changeCount`。配布先が git リポジトリでないときは `null`。縮退モードでも配布先が
  git なら埋まる）・`upstreamHasPath` / `upstreamDeleted`。
- 読めなかった配布先は `{"path":..., "error":...}` になる（他の配布先の結果は返る）。

### Step 2: 結果を表で提示する

ユーザーへ、配布先ごとに次の表で提示する。

| パス | 層 | 分類 | 衝突 | ai-asset | 変更回数 | 備考 |
|---|---|---|---|---|---|---|

提示時の注意:

- **`aiAssetCommits` の 0 件を「改善なし」と読ませない。** `commit` スキルは `ai-asset:` の
  対象を「AIが読むもの」に限定し `.claude/scripts/` 配下を対象外（feat/fix/refactor）として
  いるため、スクリプト類は規約どおりの配布先でも常に 0 件になる。規約に従っていない配布先も
  0 件になる。「ai-asset該当なし（スクリプト類・規約未準拠では常に0）」のような表現にする。
- `status: "removedUpstream"`（本家でも削除済み）は**収穫対象外の別枠**として提示する
  （配布元が削除案内したファイルを配布先が手で消した跡。候補に混ぜない）。
- `conflict: unknown` は「衝突が無い」ではなく「判定できない」（merge 層・base 未解決・
  merge-file のエラー）。`baseApproximate: true` のときは衝突判定が近似である旨を添える。
- **プロジェクト固有語の判定は AI がこの後の `diff` を読んで行う**（スクリプトの責務に
  しない）。配布先のプロジェクト名・固有のパス・アプリ固有の文脈が差分に含まれるものは
  「そのままでは収穫できない（一般化が要る）」と注記する。

### Step 3: 取り込む差分を選択してもらう

`AskUserQuestion` で、収穫候補のうちどれを本家へ取り込むかを選択してもらう
（multiSelect。1件も選ばれなければここで終了する）。

**非対話セッション（応答を待てない実行環境）では、選択を求めず Step 2 の表と候補一覧を
提示して停止する**（以降の Step へ進まない。起票には明示指示が要ることを最終応答へ明示する。
`.claude/rules/git-workflow.md`「ハーネスがPR作成を制限する環境での扱い」と同じ
「振る舞いを決め打ちにする」方針）。

### Step 4: 出口レベルを確認する

`AskUserQuestion` で出口レベルを確認する。

- **a. issue起票のみ**（既定）
- **b. issue起票＋個別作業計画の草案作成**

（非対話セッションは Step 3 の決め打ちにより、そもそもここへ到達しない。）

### Step 5: 内容を確認して issue を起票する

選択された差分ごとに内容を確認し、issue 本文を組み立てて **`issue-create` スキルの手順**で
起票する（重複チェック込み。`gh`/`glab` CLI 不在の環境では issue-create 側の既存の
MCP フォールバック規約に従う）。

```bash
# 2-way 差分（本家HEAD vs 配布先現在。LF正規化後）
bash .claude/skills/harvest-from-projects/scripts/harvest-from-projects.sh diff /path/to/projectA .claude/rules/x.md

# 3-way マージ結果の事前確認
# （終了コード: 0=衝突なし/1=衝突あり/2=base取得不可で2-wayへ縮退/
#   3=エラー（層を判定できない場合のフェイルクローズを含む）/4=対象外（merge層・seed層・dist-layers.json））
bash .claude/skills/harvest-from-projects/scripts/harvest-from-projects.sh merge3 /path/to/projectA .claude/rules/x.md
```

issue 本文は標準4見出し（目的・現状・期待する動作・受け入れ条件）で書き、次を含める:

- どの配布先の・どのファイルの・どんな改善か（`diff` の要点）
- 衝突有無（`merge3` の結果）と、プロジェクト固有語の一般化が要るか
- 収穫元の情報（配布先パス・`sourceCommit`）

### Step 6: 出口レベル b の場合は草案を作って停止する

個別作業計画の草案を**セッションの scratchpad（一時領域）へ書き**、パスと内容を提示して
停止する。**本家の `plans/` へは置かない**（進行中の別タスクの計画と混ざる。取り込みの実装は
起票した issue の issue-mr-flow が担い、その flow-id 3-1 で正式な個別作業計画を作る）。

## してはいけないこと

- **本家の `.claude/rules/` `.claude/skills/` `.claude/docs/` を直接編集すること**
  （issue #27 受け入れ条件）。どの出口レベルでも、本家の正史の変更は issue 起票までとする。
- 配布先のワークツリーを変更すること（分析は読み取り専用。`.bak` の整理等も配布先の作業）。
- `scan` の分類を縮退モード（`degraded: true`）の配布先で確定情報として提示すること
  （縮退時は「差分がある」ことしか言えない。manifest を作り直すには配布先で
  `apply-mr-workflow-to-project` の再適用を案内する）。
- issue を起票したことを根拠に、同じセッションで取り込み実装へ進むこと
  （`issue-create` スキルの「してはいけないこと」と同じ。着手判断は人間が握る）。

## 制約・かかわり

- **merge 層（`.gitignore` / `.gitattributes` / `.claude/settings.json`）は 3-way の対象外**
  （配布直後の内容が本家のどのコミットにも存在しないため base が成立しない）。modified の
  検知は manifest の strategy 別指紋との比較で行い、内容の確認は `diff` で行う。
- **`.claude/dist-layers.json` も 3-way の対象外**（`del(.upstream)` を掛けた内容が配布される
  ため）。`diff` は本家側へ同じ変換を掛けてから比較する。
- **seed 層（`AGENTS.md` / `HANDOFF.md` / `index.md` / `REVIEW-POINTS.local.md` 等）も 3-way の
  対象外**（配布元は別パスの雛形で、base が本家の履歴に無い）。層を判定できない配布先
  （manifest も dist-layers.json も読めない）では `merge3` は実行されず終了コード 3 で止まる
  （フェイルクローズ）。
- 仕様の詳細（分類規則・縮退条件・終了コード）は
  [.claude/docs/spec/harvest-from-projects.md](../../docs/spec/harvest-from-projects.md) が正
  （経緯・却下案は DDR `i0027-01`・`i0027-02`）。
