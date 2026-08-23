---
title: 収穫（逆輸入）スキルの分析スクリプト
type: spec
description: 配布先プロジェクトで改善されたAIアセットを本家へ収穫するharvest-from-projectsスキルと分析スクリプト（scan/diff/merge3）の正史仕様
resource: .claude/skills/harvest-from-projects/scripts/harvest-from-projects.sh
tags: [harvest, distribution, manifest, spec]
keywords: [収穫, 逆輸入, harvest-from-projects, asset-manifest, dist-layers, scan, merge3, 縮退モード, removedUpstream, baseApproximate, フェイルクローズ, 読み取り専用]
---

# 収穫（逆輸入）スキルの分析スクリプト

## 背景・目的

issue #27。`apply-mr-workflow-to-project` スキル（配布。issue #26 の manifest 方式）の対向として、
**配布先プロジェクトで改善されたAIアセットを本家へ取り込む「収穫（逆輸入）」の起点**を作る。

- 分析はバンドルスクリプト `harvest-from-projects.sh` が行い、**本家・配布先のどちらの
  ワークツリーも変更しない**（書き込みは一時領域のみ）。
- **出口は issue 起票（＋任意で個別作業計画の草案）まで。** 本家の正史
  （`.claude/rules/` `.claude/skills/` `.claude/docs/`）への取り込み自体は、起票した issue を
  起点とする通常の issue-mr-flow が行う（issue #27 受け入れ条件。経緯・却下案:
  [DDR i0027-01](../ddr/i0027-01-収穫スキルは読み取り専用分析とissue起票までを出口にする.md)）。
- 手順（人間との対話・issue-create への接続）は
  [SKILL.md](../../skills/harvest-from-projects/SKILL.md) が正。本仕様書はスクリプトの
  入出力・分類規則・終了コードを正として持つ。

## 仕様

### サブコマンド

```bash
bash .claude/skills/harvest-from-projects/scripts/harvest-from-projects.sh scan <配布先パス>...
bash .claude/skills/harvest-from-projects/scripts/harvest-from-projects.sh diff <配布先パス> <相対パス>
bash .claude/skills/harvest-from-projects/scripts/harvest-from-projects.sh merge3 <配布先パス> <相対パス>
```

### scan の出力スキーマ

`{"schemaVersion":1,"targets":[...]}` の JSON 1つ。`targets[]` は配布先ごとに:

| キー | 意味 |
|---|---|
| `path` | 配布先パス |
| `manifestExists` / `degraded` | manifest（`.claude/.asset-manifest.json`）の有無と縮退モードか |
| `sourceCommit` / `sourceCommitDirty` | manifest が記録する配布元コミットSHAと `-dirty` 付きだったか |
| `baseResolvable` / `baseApproximate` | 3-way の base（配布時点の内容）を本家履歴から解決できたか。`baseApproximate: true` は `-dirty` 付き記録SHAから `-dirty` を落として解決した近似 |
| `files[]` | 下記レコード |
| `error` | 読めなかった配布先はこのキーを持つレコードになる（**配布先単位のエラー隔離**。他の配布先の結果は返る） |

`files[]` の各レコード: `path`・`layer`・`status`（modified / added / deleted /
removedUpstream。縮退モードでは differs）・`conflict`（clean / conflict / unknown）・
判断材料（`aiAssetCommits` / `changeCount`。配布先が git リポジトリでないときは `null`）・
`upstreamHasPath` / `upstreamDeleted`。

### 分類規則

- **modified**: 層・strategy 別の指紋比較。core=LF正規化 sha256／merge/lines-marker=LF正規化後の
  全体 sha256／merge/json-keys=キーごとの `jq -c getpath` 出力の sha256。**strategy は明示分岐し、
  未知・欠落・keys 空は「変更あり」側へ倒す**（フェイルオープンにすると改変が無言で候補から
  落ちるため）。
- **deleted / removedUpstream**: core/merge 層限定。配布先から消えたファイルのうち、
  **本家HEADにも無いものは `removedUpstream`**（本家でも削除済み＝収穫対象外の別枠）として
  status 値ごと分ける。本家の削除履歴は `git log --no-renames --diff-filter=D --name-only`
  1回で取得する（`--no-renames` により改名の旧パスも D として拾う）。
- **added**: 3段の除外を通ったものだけを候補にする——(1) 配布先の dist-layers.json
  （`del(.upstream)` 済み）による自前 pathspec 照合（完全一致＋ディレクトリ前方一致・後勝ち）で
  core に解決されるパスに限定、(2) gitignorePattern 照合（自前サブセット実装のみ。
  `git check-ignore` は使わない——除外の正を2つにしないため。DDR i0027-01）、(3) 機構生成物
  （manifest 自身・`*.bak`）の明示除外。

### conflict 判定（3-way の事前判定）

- core 層かつ base 解決可のときだけ `git merge-file -p` で判定する
  （0=clean／1〜127=conflict／それ以外=unknown）。3入力にはLF正規化を掛ける
  （CRLF入力は内容同一でも衝突するため）。
- `-dirty` 付き記録SHAは `-dirty` を落として解決を試み、3-way を実行したうえで
  `baseApproximate: true` を立てる（一律 unknown にしない。結果は近似として読む）。
- `conflict: unknown` は「衝突が無い」ではなく「判定できない」（merge 層・base 未解決・
  merge-file のエラー）。

### 縮退モード（degraded）

manifest が無い・壊れている・レコードを1件も読めない配布先は縮退モードになり、`files[]` は
確定分類ではなく `status: "differs"`（本家HEADとの2-way差分あり）の一覧になる。

- manifest の検証は `[ -s ]` → `jq -e '(.schemaVersion == 1) and ((.files | length) > 0)'` の
  順で行う。**妥当な JSON でも `.files` が空なら縮退へ倒す**（通常経路へ進むと added 判定が
  全件素通りし、配布先の全ファイルを added と誤報するため）。
- 縮退モードのレコードも通常経路と同じ生成関数を通し、**配布先が git なら判断材料
  （`aiAssetCommits` / `changeCount`）が通常経路と同じに埋まる**。
- 本家HEADの展開は `git archive | tar -x` 1回で行い、**パイプラインの終了コードと展開結果の
  非空を明示検査**する（失敗を「差分なし」と混同せず error レコードにする）。

### merge3 の終了コード

| 終了コード | 意味 |
|---|---|
| 0 | 衝突なし |
| 1 | 衝突あり |
| 2 | base 取得不可で 2-way へ縮退 |
| 3 | その他エラー（**層を判定できない場合のフェイルクローズを含む**） |
| 4 | 3-way の対象外（merge 層・seed 層・`.claude/dist-layers.json`） |

- 層の判定は **manifest の `.files[].layer` を第一情報源**にし、無ければ配布先の
  dist-layers.json の照合で解決する。どちらも読めなければ実行せず 3 で止める
  （無言のスキップは「exit 0=そのまま取り込める」の誤読を招くため）。
- merge 層（`.gitignore` / `.gitattributes` / `.claude/settings.json`）は配布直後の内容が
  本家のどのコミットにも存在しないため base が成立しない。seed 層は配布元が別パスの雛形。
  `.claude/dist-layers.json` は `del(.upstream)` を掛けた内容が配布される（`diff` は本家側へ
  同じ変換を掛けてから比較する）。

### 読み取り専用の保証

- 書き込みは `mktemp` の一時領域のみ。
- git は show / cat-file / ls-files / ls-tree / log / rev-parse / archive / merge-file に
  限定する（すべて読み取り専用のサブコマンド）。

### git 起動の一括化

ファイル数に比例する外部プロセス起動を避けるため（`shell-script-style.md`
「外部プロセス起動のコスト」）、次を各1回に集約する——本家パス集合は `ls-tree -r`・
削除履歴は `log --no-renames --diff-filter=D --name-only`・配布先の判断材料は
`log --format='%x01%s' --name-only` を awk で畳み込み・縮退モードの本家HEAD展開は
`git archive | tar -x`。ファイル数に比例する起動は「core かつ modified」に限定した
`git show`（base/ours の実体化）と `git merge-file` のみ。
**2本の `git log` には `-c core.quotepath=false` を付ける**（無いと非ASCIIパスが8進
エスケープでクォートされ、実パスとの突き合わせが全件空振りする）。

### エラー隔離

配布先単位の隔離は `set +e; ( set -e; scan_one_dest ); rc=$?; set -e` の形で行う
（`( f ) || rc=$?` は条件文脈の errexit 一時停止がサブシェル内側へ伝播して途中失敗が
素通りするため使わない。実測・却下案:
[DDR i0027-02](../ddr/i0027-02-エラー隔離は条件文脈の外のサブシェルでset-eを掛け直して行う.md)）。

## 影響範囲

- 新規: `.claude/skills/harvest-from-projects/`（SKILL.md＋`scripts/harvest-from-projects.sh`）・
  `.claude/scripts/test/test_harvest_from_projects.sh`（T1〜T23・89アサーション）。
- 変更: `.claude/dist-layers.json`（`harvest-from-projects` の `exclude` エントリ）・
  `.claude/rules/markdown-frontmatter.md`（「配布先プロジェクトでの機構DDRの扱い」の明文化）・
  `index.md`（スキル一覧）。
- **配布物への影響**: スキル本体（`.claude/skills/harvest-from-projects/`）は `exclude` 層で
  配布されない（本家専用）。一方、**本仕様書・DDR・usecase・README・rules の変更分は
  dist-layers.json の `.claude` core エントリに包含され、すべて配布対象**である。
  exclude スキルの spec/DDR を core で配ることは**許容する**と明示的に判断した——機構の正史は
  本家の `.claude/docs/` に一元化する方針（markdown-frontmatter.md「配布先プロジェクトでの
  機構DDRの扱い」）のとおり正史ドキュメントは層を分けず一体で配るのが現行設計であり、
  配布先にとっても「機構DDRを本家へ起票する」規約の背景を読める利点がある。

### changelog

- issue #27（2026-08-23）: 本仕様の初版。`.claude/VERSION` は `0.3.0` → `0.4.0`（MINOR。
  資産の追加・フローの拡張に該当）。非対話セッションのため distribution-assets.md の例外規定に
  沿ってAIエージェントが増分を適用した（適用の事実と根拠はここと `HANDOFF.md`
  「判断を迷った内容」の両方へ記録。レビューで人間が否認したら元の値へ戻す）。

## 設定項目

なし（配布先パスは実行時引数で受け取る。本家側の層定義は `.claude/dist-layers.json`、
配布先側の判定材料は配布先の `.claude/.asset-manifest.json` と dist-layers.json をそのまま読む）。

## 未決定事項・懸念点

- **Windows（git bash）実機での動作は未検証**（`git archive | tar` 経路・`find -print0` を
  含む。実測は Claude Code on the web の Linux リモート実行環境／2026-08-23 の1環境のみ）。
- **実在の配布先プロジェクトでの試運転は未実施**（テストは合成配布先による。マージ後の
  実際の収穫の初回で確かめる）。
- **SKILL.md の対話手順（AskUserQuestion・issue-create 接続）の通し実行は未検証**
  （非対話セッションで実装したため。手順はドキュメントとしてのみ検証した）。
