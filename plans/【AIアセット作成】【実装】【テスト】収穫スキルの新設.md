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
  `rev-list` / `rev-parse`（配布先が git リポジトリかの判定）/ `merge-file`（`-p` で標準出力へ）
  に限る（いずれも読み取り専用。書き込み系サブコマンド——`add`/`commit`/`checkout`/`clean`/
  `stash` 等——は使わない）。
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
    - **配布先単位のエラー隔離**: 1件の配布先が読めなくても全体を中断しない。存在しない
      パス等は `{"path":..., "error":"<理由>"}` のレコードを返して次の配布先へ進む。
      manifest は `[ -s ]`（空でない）→`jq -e .`（有効なJSON）の**順**で検証し（`jq -e .` は
      空入力に成功を返すことがあるため空チェックが先。shell-script-style.md）、無効なら
      `manifestExists: false` の縮退へフォールバックする。
  - `diff`: 指定ファイルの 2-way 差分（本家HEAD vs 配布先現在。LF正規化後）を表示する。
  - `merge3`: 指定ファイルの 3-way マージ結果（`git merge-file -p`。3入力ともLF正規化）を
    標準出力へ出す。**終了コードは衝突数をそのまま返さず、意味ごとに正規化して返す**
    （0=衝突なし／1=衝突あり／2=base 取得不可のため `diff` 相当へ縮退（stderrへ理由を出す）／
    3=その他エラー／4=3-way の対象外（下記））。
    `git merge-file` 自体の終了コードは 0／1〜127（衝突数）／≧128（エラー。実測255）の
    3分岐で解釈する（「0以外は衝突」と実装するとエラーが衝突に誤分類される。調査結果 Q3）。
    衝突数を露出させないのは、縮退・エラーの信号と数値域が重なるため。**2（base取得不可）と
    4（対象外）を分けるのは、呼び出し元（SKILL.md）がユーザーへ出すメッセージを stderr の
    文言に頼らず選べるようにするため。**
    **merge 層と `.claude/dist-layers.json` は `merge3` の対象外**（前者は base が本家のどの
    コミットにも無い、後者は `del(.upstream)` 済みの内容が配布されるため。指定されたら
    その旨をstderrへ出し終了コード4で終わる。dist-layers.json の2-way比較では本家側へ
    `del(.upstream)` を掛けてから比べる。調査結果 Q3）。
  - `--upstream` は既定でスクリプト位置から導出した本家ルート。テストが合成本家を差し込む
    ための上書きオプション（`install-to-project.sh` に無い引数だが、収穫は「本家＝自分」を
    書き換えないため安全に公開できる）。
- `scan` の JSON 形。**トップレベルは `{"schemaVersion":1,"targets":[...]}`** で、`targets[]` の
  各要素が1配布先ぶん（配布先が読めない場合の要素は `{"path":..., "error":"<理由>"}`）:

  ```json
  { "schemaVersion": 1, "targets": [
    { "path": "/abs/dest", "manifestExists": true, "degraded": false,
      "sourceCommit": "abc123", "sourceCommitDirty": false,
      "baseResolvable": true, "baseApproximate": false,
      "files": [
        { "path": ".claude/rules/x.md", "layer": "core", "status": "modified",
          "conflict": "clean|conflict|unknown",
          "aiAssetCommits": 2, "changeCount": 5,
          "upstreamHasPath": true, "upstreamDeleted": false }
      ] }
  ] }
  ```

  - `status`: modified / added / deleted（判定は調査結果 Q8 の表のとおり。modified の比較は
    層・strategy 別——core は LF正規化 sha256、**merge/lines-marker は LF正規化後の**ファイル
    全体 sha256（記録側 `merge_fingerprint_json` は `tr -d '\r'` を通してから sha256 を取る。
    同一の式で比較しないと CRLF の配布先で常に modified になる）、merge/json-keys はキーごとの
    `jq -c getpath` 出力の sha256（**こちらだけ正規化なし**）。deleted は core/merge に限る。
    added は**自前の pathspec 照合**（完全一致＋ディレクトリ前方一致・エントリ順の後勝ち。
    `build_plan` の `git ls-files` 展開は本家に無いパスへ適用できないため流用しない）で
    `core` に解決され、**かつ gitignorePattern を持つ local エントリ9件との照合でも除外
    されない**パスに限定する。**除外の正は配布先の `.claude/dist-layers.json` の1つだけ**:
    層解決・gitignorePattern 照合のどちらも**配布先へ配布された定義**（`del(.upstream)` 済み）を
    読む（本家側の定義で解くと「配布当時は core だったファイル」が層変更で対象外になり結果が
    揺れる。定義が配布先に無い／壊れている場合は manifest 無しと同じ縮退扱い）。パターン照合は
    gitignore 規則のサブセット（先頭 `/`・末尾 `/`・`*`・`**/`）を**自前実装のみ**で行い、
    `git check-ignore` は**使わない**（check-ignore が見るのは配布先の実 `.gitignore` で、
    参照データが違う。git の有無で added の集合が変わる「正が2つ」の状態を避ける）。
    さらに**配布機構自身の生成物を明示的に除外する**: manifest ファイル自身
    （`.claude/.asset-manifest.json`）と `*.bak`（install-to-project.sh が改変済み core を
    上書きする際の退避ファイル）は added に含めない。
  - `upstreamHasPath` / `upstreamDeleted`: added・deleted の両方のレコードに持たせる。
    `upstreamDeleted` は本家の `git log --diff-filter=D -- <path>` に削除履歴があるか
    （調査結果 Q8 の区別材料。`upstreamHasPath: false` だけでは「配布先の新規追加」と
    「本家の削除漏れ」を区別できないため）。**deleted のうち本家HEADにも存在しないもの
    （本家でも削除済み）は、配布先の削除として提示せず「本家でも削除済み（収穫対象外）」の
    別枠にする**（install-to-project.sh の SCAN_CORE_REMOVED の案内に従って手で消した配布先を
    毎回候補に出さないため）。
  - `conflict`: 3-way の事前判定（core 層かつ base 解決可のときだけ。**merge 層は 3-way
    対象外**のため常に `unknown` とし、modified 判定のみ行う）。**記録SHAが `-dirty` 付きの
    場合は、`-dirty` を落として解決を試み、解決できれば 3-way を実行して conflict を算出した
    うえで `baseApproximate: true` を立てる**（base が配布物と一致しない可能性の注釈。
    調査結果 Q3 の縮退順序1。一律 unknown にすると `--allow-dirty` 配布の配布先で衝突区別が
    丸ごと死ぬ）。SHA が真に未到達（squash merge 後・shallow 等）のときだけ
    `baseResolvable: false`・`conflict: unknown` になる。
  - **縮退時（degraded: true）の `files[]` は別の形**: `status` は確定分類ではなく
    `"differs"` 固定とし、`conflict` キーは出さない（調査結果 Q4 の「確定分類は成立しない」を
    出力形でも区別する）。
  - 判断材料: `aiAssetCommits`（`ai-asset:` prefix コミット数）・`changeCount`
    （`rev-list --count`）。配布先が git リポジトリでない場合は `null`（取得不可を明示。
    空文字や 0 への縮退は「改善なし」と誤読されるため不可）。
    `aiAssetCommits` は SKILL.md の提示側で「0件＝改善なし」と読ませない（commit スキルは
    `.claude/scripts/` を ai-asset の対象外にしており、スクリプト類は規約どおりでも常に0件。
    調査結果 Q7）。
  - `merge` 層は記録済み指紋（lines-marker はLF正規化後の全体 sha256・json-keys はキーごと）
    との比較で modified を判定する（読む側の初実装。指紋の意味は調査結果 Q1）。
- 実装規約: `set -euo pipefail`・jq 起動はループ内で行わない（ファイル群の sha256 は
  `sha256sum` 一括、レコードはUS区切り中間表現→jq 1回）・**git の起動もファイル数に比例
  させない**（git bash では約95ms/回のため。判断材料は `git log --format='%H%x1f%s' --name-only`
  を配布先ごと1回で取得してファイル別に集計する。本家HEAD・記録SHAの内容取得は
  `git cat-file --batch` を1プロセスで使い回す。`git merge-file` の起動は「core かつ modified」と
  確定した件数だけに限定する。縮退モードの全件比較も `cat-file --batch`＋`sha256sum` 一括で
  行い、`git show` をファイルごとに呼ばない）・`main` ガード（`BASH_SOURCE` 比較）で
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
| T2a | **同じ行**を本家側も変更（base≠ours≠theirs・同一ハンク） | `conflict=conflict`（受け入れ条件2） |
| T2b | 本家と配布先が**十分離れた行**（間に数行以上）を変更 | `conflict=clean`（自動マージ可能。「base≠ours なら常に conflict」の実装を弾く） |
| T3 | 配布先で core 対象ディレクトリへ新規ファイル追加 | `status=added`（受け入れ条件3） |
| T4 | manifest 記録済みファイルを配布先で削除（本家HEADには存在） | `status=deleted`（受け入れ条件4） |
| T5 | manifest 無しの配布先 | `degraded=true`・`files[].status="differs"`・`conflict` キー無し（受け入れ条件5） |
| T6 | 配布先2つを一度に指定＋**3つ目に壊れた配布先**（0バイト manifest） | 正常2件の結果が返り、壊れた1件は `manifestExists=false` の縮退（全体は中断しない） |
| T7 | `local` 相当・機構生成物を配布先へ追加（(a) path エントリで除外されるパス、(b) gitignorePattern だけで除外されるパス——`index.jsonl` 相当、(c) `.claude/.asset-manifest.json` 自身、(d) `.claude/rules/x.md.bak`） | いずれも added に**現れない**（Q8。(b) は path の層解決では除外できないケース） |
| T8 | 記録SHAが `-dirty` 付き（SHA自体は到達可能） | `-dirty` を落として 3-way が動き `conflict` が算出され、`baseApproximate=true` が立つ |
| T8b | 記録SHAが実在しない40桁（真に未到達） | `baseResolvable=false`・`conflict=unknown`、`merge3` は縮退（終了コード2・stderr に理由） |
| T9 | theirs が CRLF（内容は同一） | modified に**ならない**（LF正規化。sha一致） |
| T10 | 純粋関数の単体（pathspec照合の後勝ち・gitignoreパターン照合・`-dirty` 除去） | source して直接検証 |
| T11 | スクリプトが読み取り専用であること | 実行前後で合成本家・合成配布先の `git status --porcelain` が不変 |
| T12 | merge/lines-marker の指紋比較（読む側の初実装） | 配布直後と一致→modified に**ならない**／1行足す→modified に**なる**／CRLF化のみ（内容同一）→modified に**ならない**（LF正規化） |
| T13 | merge/json-keys の指紋比較 | 対象キーの値を変える→modified に**なる**／対象外キーだけ変える→modified に**ならない** |
| T14 | merge3 の終了コード正規化 | 衝突しない差分→exit 0／同一行の差分→exit 1＋標準出力に衝突マーカー／merge 層の指定→exit 4／存在しない相対パス→exit 3 |
| T15 | **git リポジトリでない配布先**（git init しない合成配布先） | scan が落ちず、`aiAssetCommits`/`changeCount` が JSON の `null`。(b) の gitignorePattern 除外も効く（自前照合のみで成立） |

- 出力規約: `passed=N failures=N`・失敗時終了コード1。
- 冒頭で対象スクリプト不在ならスキップ（配布先で正常。`test_install_to_project.sh` と同型）。
- 合成配布先の manifest には `lines` / `keys` 形の merge レコードも捏造して置く（T12/T13 用）。

## やらないこと（スコープ外）

- 本家正史への取り込みの自動実行（出口は issue 起票まで。以降は通常の issue-mr-flow）。
- GitLab MCP 対応・リモート配布先・merge 層の自動マージ逆適用（modified の提示まで）。
- spec / DDR の作成（フェーズ4の `【設計反映】` で行う）。
- `.claude/VERSION` の増分（配布対象アセットが増えるため対象になるが、増分判断は
  flow-id 4-6 の反映計画で行い、判断根拠を spec の changelog へ残す）。
- `.gemini/` への変換同期（flow-id 5-3 でまとめて行う）。

## 検証

```bash
bash -n .claude/skills/harvest-from-projects/scripts/harvest-from-projects.sh
bash .claude/scripts/test/test_harvest_from_projects.sh   # passed=N failures=0・終了コード0

# 網羅性チェックは新規ファイルを git add（または commit）した後に実行する
# （検査3は git ls-files で判定するため、未ステージだと exclude エントリが空振り扱いで必ず失敗する）
bash .claude/scripts/src/check-dist-coverage.sh           # exclude エントリ追加後も4検査が通る

# frontmatter はインデックスへの実問い合わせで検証する（走査が通るだけでは空振り）
bash .claude/scripts/src/extract-frontmatter.sh . >/dev/null
jq -e 'select(.path | endswith("harvest-from-projects/SKILL.md")) | .type == "skill"' \
  .claude/skills/harvest-from-projects/index.jsonl   # 1件ヒットし true が出ること
```

合格条件: 上記がすべて成功し、T1〜T15 が issue #27 の受け入れ条件（複数配布先・縮退・
分類・衝突区別）と本計画の設計判断（指紋の層別比較・終了コード正規化・非git配布先・
エラー隔離）を1件以上のアサーションで固定していること。

## issueの受け入れ条件との対応

| 受け入れ条件 | 対応 |
|---|---|
| core 層変更が列挙される | scan の modified＋T1 |
| 本家側変更と衝突ありの区別 | conflict 判定＋T2a/T2b |
| 新規追加が候補列挙 | added＋T3（T7 で誤検出防止） |
| 削除が列挙 | deleted＋T4 |
| manifest 無しの縮退モード | degraded＋T5 |
| 複数配布先パス | scan 引数設計＋T6 |
| 出口レベル確認・停止・正史不変更 | SKILL.md 手順3〜7＋スクリプトの読み取り専用設計（T11） |
| issue-create 経由の起票 | SKILL.md 手順5 |
| DDR規約が配布物のルールに記載 | markdown-frontmatter.md への追記（core 層） |
