---
title: 【AIアセット作成】【実装】【テスト】収穫スキルの新設
type: plan
description: issue #27 収穫（逆輸入）スキルの SKILL.md・収穫スクリプト・単体テスト・配布先DDR規約を作る個別作業計画
tags: [plan, harvest, implementation]
keywords: [harvest-from-projects, SKILL.md, 収穫スクリプト, 単体テスト, dist-layers, exclude, DDR規約, 出口レベル]
---

# 【AIアセット作成】【実装】【テスト】収穫スキルの新設 — issue #27

## 前提（合意状況）

- 依拠する調査結果: `reports/2026-08-23_quiet-orchard-harvest_調査結果.md`（flow-id 2-6 で作成。
  敵対的レビュー1〜2回目の指摘を反映済み）。
- 上位計画: `plans/quiet-orchard-harvest.md`（flow-id 1-4 で作成）。
- **flow-id 1-5・2-8（人間の合意・レビュー）は未実施**（非対話セッションのため保留のまま
  進行中。全体作業計画「非対話セッションでの進め方」参照）。人間レビューで方針が変われば
  本計画も変わりうる。

## 種別の併記について

`【AIアセット作成】`（SKILL.md・DDR規約明文化）・`【実装】`（収穫スクリプト・dist-layers
エントリ）・`【テスト】`（単体テスト）を併記する。スクリプトはスキルの実行に必須のバンドル
リソースで、テストは実装と同時に書いてまとめて1回で合意を取るのが自然なため（分けても合意の
単位が変わらず記述が重複するだけ）。

## この計画で何をするか

収穫（逆輸入）スキル一式を新設する。構成は「読み取り専用の分析スクリプト＋AIエージェントの
手順（SKILL.md）＋既存フロー（issue-create）への接続」。

## 変更対象

| ファイル | 操作 | 何をするか |
|---|---|---|
| `.claude/skills/harvest-from-projects/SKILL.md` | 新規 | 収穫スキルの手順定義（下記） |
| `.claude/skills/harvest-from-projects/scripts/harvest-from-projects.sh` | 新規 | 読み取り専用の差分分析スクリプト（下記） |
| `.claude/scripts/test/test_harvest_from_projects.sh` | 新規 | 単体・結合テスト（`passed=N failures=N` 規約。配布先でスクリプト不在ならスキップ——`test_install_to_project.sh` と同型） |
| `.claude/dist-layers.json` | 変更 | `exclude` エントリ追加（`apply-mr-workflow-to-project` エントリの直後） |
| `.claude/rules/markdown-frontmatter.md` | 変更 | 「DDRの識別子」節配下へ「配布先プロジェクトでの機構DDRの扱い」を追記 |

## 方針

### スクリプト `harvest-from-projects.sh`

- **読み取り専用**: 本家のワークツリー・配布先のワークツリーのどちらも変更しない。書き込みは
  `mktemp -d` の一時領域のみ。gitへの操作は `show` / `cat-file` / `ls-files` / `log` /
  `rev-list` / `merge-file`（`-p` で標準出力へ）に限る。
- インターフェース:

  ```bash
  bash harvest-from-projects.sh [--upstream <dir>] scan <配布先パス>...
  bash harvest-from-projects.sh [--upstream <dir>] diff <配布先パス> <相対パス>
  bash harvest-from-projects.sh [--upstream <dir>] merge3 <配布先パス> <相対パス>
  ```

  - `scan`: 配布先ごとに manifest を読み、`core`/`merge` の modified / added / deleted と
    衝突有無・判断材料を **JSON 1つ**で標準出力へ返す（複数配布先を一度に受け取る。
    受け入れ条件）。manifest が無い配布先は `"degraded": true` として2-wayの差分一覧
    （変更ありファイルの列挙）へ縮退する。
  - `diff`: 指定ファイルの 2-way 差分（本家HEAD vs 配布先現在。LF正規化後）を表示する。
  - `merge3`: 指定ファイルの 3-way マージ結果（`git merge-file -p`。3入力ともLF正規化）を
    標準出力へ出す。**終了コードは衝突数をそのまま返さず、正規化して返す**（0=衝突なし／
    1=衝突あり／2=base 取得不可のため `diff` 相当へ縮退（stderrへ理由を出す）／3=その他エラー）。
    `git merge-file` 自体の終了コードは 0／1〜127（衝突数）／≧128（エラー。実測255）の
    3分岐で解釈する（「0以外は衝突」と実装するとエラーが衝突に誤分類される。調査結果 Q3）。
    衝突数を露出させないのは、縮退・エラーの信号と数値域が重なるため。
    **merge 層と `.claude/dist-layers.json` は `merge3` の対象外**（前者は base が本家のどの
    コミットにも無い、後者は `del(.upstream)` 済みの内容が配布されるため。指定されたら
    その旨をstderrへ出し終了コード2で縮退する。dist-layers.json の2-way比較では本家側へ
    `del(.upstream)` を掛けてから比べる。調査結果 Q3）。
  - `--upstream` は既定でスクリプト位置から導出した本家ルート。テストが合成本家を差し込む
    ための上書きオプション（`install-to-project.sh` に無い引数だが、収穫は「本家＝自分」を
    書き換えないため安全に公開できる）。
- `scan` の JSON 形（1配布先ぶん）:

  ```json
  { "path": "/abs/dest", "manifestExists": true, "degraded": false,
    "sourceCommit": "abc123", "sourceCommitDirty": false, "baseResolvable": true,
    "files": [
      { "path": ".claude/rules/x.md", "layer": "core", "status": "modified",
        "conflict": "clean|conflict|unknown",
        "aiAssetCommits": 2, "changeCount": 5,
        "upstreamHasPath": true }
    ] }
  ```

  - `status`: modified / added / deleted（判定は調査結果 Q8 の表のとおり。modified の比較は
    層・strategy 別——core は LF正規化 sha256、merge/lines-marker は全体 sha256、
    merge/json-keys はキーごとの `jq -c getpath` 出力の sha256。deleted は core/merge に限る。
    added は**自前の pathspec 照合**（完全一致＋ディレクトリ前方一致・エントリ順の後勝ち。
    `build_plan` の `git ls-files` 展開は本家に無いパスへ適用できないため流用しない）で
    `core` に解決され、**かつ gitignorePattern を持つ local エントリ9件との照合でも除外
    されない**パスに限定する（照合は gitignore 規則のサブセットを自前実装し、配布先が git
    リポジトリなら `git check-ignore` を優先する。調査結果 Q8）。`upstreamHasPath` で本家の
    削除漏れとの区別材料を添える。
  - `conflict`: 3-way の事前判定（core 層かつ base 解決可のときだけ。`-dirty`・未到達なら
    `unknown`。**merge 層は 3-way 対象外**のため常に `unknown` とし、modified 判定のみ行う）。
  - 判断材料: `aiAssetCommits`（`ai-asset:` prefix コミット数）・`changeCount`
    （`rev-list --count`）。配布先が git リポジトリでない場合は `null`（取得不可を明示）。
    `aiAssetCommits` は SKILL.md の提示側で「0件＝改善なし」と読ませない（commit スキルは
    `.claude/scripts/` を ai-asset の対象外にしており、スクリプト類は規約どおりでも常に0件。
    調査結果 Q7）。
  - `merge` 層は記録済み指紋（lines-marker はファイル全体 sha256・json-keys はキーごと）との
    比較で modified を判定する（読む側の初実装。指紋の意味は調査結果 Q1）。
- 実装規約: `set -euo pipefail`・jq 起動はループ内で行わない（ファイル群の sha256 は
  `sha256sum` 一括、レコードはUS区切り中間表現→jq 1回）・`main` ガード（`BASH_SOURCE` 比較）で
  `source` 可能にし、純粋関数（pathspec照合の層解決・gitignoreパターン照合・分類・`-dirty` 除去・
  LF正規化比較）を単体テスト可能にする。

### SKILL.md（AIエージェントの手順）

1. 配布先パス（複数可）をユーザーから受け取り `scan` を実行する。
2. 結果を層・分類・衝突・判断材料つきの表で提示する（プロジェクト固有語の判定は AI が
   `diff` を読んで行う——スクリプトの責務にしない。調査結果 Q7）。
3. `AskUserQuestion` で取り込む差分を選択してもらう。
4. `AskUserQuestion` で出口レベルを確認する（a. issue起票のみ／b. issue起票＋個別作業計画の
   草案作成）。
5. 選択された差分ごとに `diff` / `merge3` で内容を確認し、issue本文（目的・現状・期待する
   動作・受け入れ条件）を組み立て、**`issue-create` スキルの手順**で起票する（重複チェック
   込み。CLI不在時は既存のMCPフォールバック規約に従う）。
6. 出口レベル b のときは、個別作業計画の草案を**セッションの scratchpad**（一時領域）へ書き、
   パスと内容を提示して停止する（本家の `plans/` へは置かない——進行中の別タスクの計画と
   混ざるため。取り込み実装は起票した issue の issue-mr-flow で行う）。
7. **どのレベルでも本家の `.claude/rules/` `.claude/skills/` `.claude/docs/` を直接編集しない**
   （受け入れ条件）。「してはいけないこと」節で明文化する。

### DDR規約の明文化（`markdown-frontmatter.md`）

「DDRの識別子」節の末尾へ小節「配布先プロジェクトでの機構DDRの扱い（issue #27）」を追加:
配布先では機構（`.claude/` 一式）に関するDDRを書かず、本家へ issue を起票する（収穫スキルの
出口と同じ経路）。理由: 配布先のDDR識別子は本家と衝突しうる・機構の意思決定の正史は本家に
一元化する。プロジェクト固有のDDR（アプリ本体の意思決定）は従来どおり配布先で書いてよい、
という線引きも明記する。

### dist-layers.json

`apply-mr-workflow-to-project` の `exclude` エントリ直後へ追加:

```json
{ "layer": "exclude", "path": ".claude/skills/harvest-from-projects",
  "note": "収穫（逆輸入）スキルは本家専用。配ると配布先が配布先自身を収穫する誤用と、本家と配布先の役割の分岐を招く" }
```

### テスト `test_harvest_from_projects.sh`

一時ディレクトリに**合成本家**（git init・最小の dist-layers.json・core ファイル数件・
2コミット）と**合成配布先**（git init・manifest 捏造）を作り、`--upstream` で差し込んで固定する。

| # | ケース | 期待 |
|---|---|---|
| T1 | core ファイルを配布先で変更 | `status=modified` として列挙（受け入れ条件1） |
| T2 | 同一ファイルを本家側も変更（base≠ours≠theirs） | `conflict=conflict`。T1（本家未変更）は `clean` と区別（受け入れ条件2） |
| T3 | 配布先で core 対象ディレクトリへ新規ファイル追加 | `status=added`（受け入れ条件3） |
| T4 | manifest 記録済みファイルを配布先で削除 | `status=deleted`（受け入れ条件4） |
| T5 | manifest 無しの配布先 | `degraded=true` で差分一覧が出る（受け入れ条件5） |
| T6 | 配布先2つを一度に指定 | 両方の結果が返る（受け入れ条件6） |
| T7 | `local` 相当のファイルを配布先へ追加（(a) path エントリで除外されるパス、(b) gitignorePattern だけで除外されるパス——`index.jsonl` 相当——の両方） | どちらも added に**現れない**（Q8。(b) は path の層解決では除外できないケース） |
| T8 | 記録SHAが `-dirty` 付き | `baseResolvable=false`・`conflict=unknown`、`merge3` は縮退（終了コード2） |
| T9 | theirs が CRLF（内容は同一） | modified に**ならない**（LF正規化。sha一致） |
| T10 | 純粋関数の単体（pathspec照合の後勝ち・gitignoreパターン照合・`-dirty` 除去） | source して直接検証 |
| T11 | スクリプトが読み取り専用であること | 実行前後で合成本家・合成配布先の `git status --porcelain` が不変 |

- 出力規約: `passed=N failures=N`・失敗時終了コード1。
- 冒頭で対象スクリプト不在ならスキップ（配布先で正常。`test_install_to_project.sh` と同型）。

## やらないこと（スコープ外）

- 本家正史への取り込みの自動実行（出口は issue 起票まで。以降は通常の issue-mr-flow）。
- GitLab MCP 対応・リモート配布先・merge 層の自動マージ逆適用（modified の提示まで）。
- spec / DDR の作成（フェーズ4の `【設計反映】` で行う）。
- `.gemini/` への変換同期（flow-id 5-3 でまとめて行う）。

## 検証

```bash
bash -n .claude/skills/harvest-from-projects/scripts/harvest-from-projects.sh
bash .claude/scripts/test/test_harvest_from_projects.sh   # passed=N failures=0・終了コード0
bash .claude/scripts/src/check-dist-coverage.sh           # exclude エントリ追加後も4検査が通る
bash .claude/scripts/src/extract-frontmatter.sh . >/dev/null  # 新規mdのfrontmatterが読める
```

合格条件: 上記がすべて成功し、T1〜T11 が issue #27 の受け入れ条件（複数配布先・縮退・
分類・衝突区別）を1件以上のアサーションで固定していること。

## issueの受け入れ条件との対応

| 受け入れ条件 | 対応 |
|---|---|
| core 層変更が列挙される | scan の modified＋T1 |
| 本家側変更と衝突ありの区別 | conflict 判定＋T2 |
| 新規追加が候補列挙 | added＋T3（T7 で誤検出防止） |
| 削除が列挙 | deleted＋T4 |
| manifest 無しの縮退モード | degraded＋T5 |
| 複数配布先パス | scan 引数設計＋T6 |
| 出口レベル確認・停止・正史不変更 | SKILL.md 手順3〜7＋スクリプトの読み取り専用設計（T11） |
| issue-create 経由の起票 | SKILL.md 手順5 |
| DDR規約が配布物のルールに記載 | markdown-frontmatter.md への追記（core 層） |
