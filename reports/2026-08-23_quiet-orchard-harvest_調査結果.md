---
title: 調査結果: 収穫スキルの前提調査
type: report
description: issue #27 収穫（逆輸入）スキル実装に先立つ配布機構・接続先の調査結果（Q1〜Q8への回答）
tags: [report, research, harvest]
keywords: [asset-manifest, dist-layers, install-to-project, git merge-file, 縮退モード, create-issue, merge指紋, 3-way]
---

# 調査結果: 収穫スキルの前提調査 — issue #27

個別調査計画 `plans/【調査】収穫スキルの前提調査.md` の Q1〜Q8 への回答。
根拠は `install-to-project.sh`（issue #26 時点の実装）の読解と、このリポジトリ上での
コマンド実行検証による（実行検証の生出力は末尾「実行検証の記録」）。

## Q1: manifest の形式と merge 層の指紋

`.claude/.asset-manifest.json`（配布先にのみ存在）の `files[]` は層ごとに次の形を持つ
（`install-to-project.sh` の `write_manifest`・`merge_fingerprint_json`）。

| 層 | レコード形 |
|---|---|
| `core` | `{path, layer:"core", sha256}` |
| `seed` | `{path, layer:"seed", sha256, placed:true/false}` |
| `merge`（lines-marker） | `{path, layer:"merge", strategy:"lines-marker", lines:"<sha256>"}` |
| `merge`（json-keys） | `{path, layer:"merge", strategy:"json-keys", keys:{"<キー>":"<sha256>", ...}}` |

- `sha256` は **LF正規化（`tr -d '\r'`）後の内容**に対する値。収穫側の比較も同じ正規化を
  通さないと、CRLF環境の配布先で全件が「改変あり」になる。
- **merge 層の指紋は「配布直後のマージ結果」に対する値**である。lines-marker は
  マージ後ファイル全体の sha256（キー名 `lines` だがマーカー行だけのハッシュではない）、
  json-keys は対象キーの値ごとの sha256。**読む側は現状どこにも無い**（`merge_fingerprint_json`
  冒頭のコメントで明言。scan_pass が読むのは `select(.sha256)` に一致する core/seed のみ）。
  収穫スキルがこの指紋の最初の読み手になる。
- `source.commit` は配布時の本家HEAD。本家が dirty のまま `--allow-dirty` で配布した場合は
  `-dirty` サフィックスが付く（3-way の base 解決時に落とす必要がある。Q3）。
- `local` / `exclude` 層のファイルは manifest に載らない。**収穫対象の層判定は manifest の
  `layer` キーで足りる**（issue #27 が対象とする `core` / `merge` はどちらも載る）。

## Q2: 収穫スクリプト・単体テストの置き場所

- スクリプト本体: `.claude/skills/<収穫スキル>/scripts/` 配下。前例は
  `apply-mr-workflow-to-project/scripts/install-to-project.sh`（スキルの実行に必須の
  バンドルリソースは `scripts/` サブディレクトリへ置く規約。
  `.claude/rules/directory-structure.md`「配置の指針」）。
- 単体テスト: `.claude/scripts/test/test_install_to_project.sh` が **スキル配下のスクリプトの
  テストを `.claude/scripts/test/` に置く前例**になっている（`passed=N failures=N` 規約）。
  収穫スクリプトも `.claude/scripts/test/test_harvest_from_projects.sh` とする。
- 層分け: `apply-mr-workflow-to-project` は `exclude`（「配ると配布先が本家として再配布でき、
  版の系譜が分岐する」）。収穫スキルは**本家でしか意味を持たない**（配布先の manifest を読み、
  本家HEADと比較する）ため、同じ理由＋誤用防止で `exclude` にする。
  `dist-layers.json` へのエントリ追加が必要（追加しないと `.claude` 全体が `core` に一致し
  配布されてしまう。網羅性チェックは `.claude` エントリで通ってしまうため気づけない）。

## Q3: 3-way突き合わせの実装手段と縮退

- **`git merge-file -p <ours> <base> <theirs>`** を使う（このリポジトリ上で実行検証済み）。
  終了コードが衝突数（0=衝突なし、正=衝突あり、負=エラー）で、「衝突なし／衝突あり」の
  仕分けにそのまま使える。`-p` で標準出力へマージ結果を出し、入力ファイルを変更しない
  （読み取り専用の要件に合う）。
- base は `git show <記録SHA>:<path>` で取得する。**取得できない場合**は次の順で縮退する。
  1. 記録SHAの `-dirty` サフィックスを落としてから解決を試みる。
  2. `git cat-file -e <SHA>^{commit}` が失敗する場合（shallow clone で届かない・squash merge
     で本家履歴に残っていない・配布後に本家で force push 等）は、**3-way を諦めて 2-way**
     （本家HEAD と配布先現在の差分表示）へ落とし、「base 取得不可（理由）」を明示する。
  - 補足: 記録SHAはブランチ上のコミットでも、squash merge 後にオブジェクトが直ちに消える
    わけではないが、GC・shallow の事情で恒久保証は無い。縮退経路は必須。
- 「本家も同じ箇所を変更済み＝衝突あり」の判定は、`git merge-file` の衝突検出そのもので
  表現できる（base→ours の変更と base→theirs の変更が同一・近接ハンクに重なると衝突）。
  検証で、隣接行の変更（3行ファイルで ours が2行目・theirs が3行目）も衝突扱いになることを
  確認した。ハンクが十分離れていれば自動マージされ「衝突なし」になる。
- **3-way の3入力（base/ours/theirs）には、manifest の sha256 と同じLF正規化
  （`tr -d '\r'`）を掛けてから突き合わせる。** 実行検証で、theirs だけを CRLF にすると
  内容が同一でも衝突（衝突マーカー1件）になることを確認した（下記「実行検証の記録」2）。
  正規化しないと、CRLF の配布先で sha256 比較（LF正規化済み）は「変更なし」なのに 3-way が
  全行衝突を報告する、という矛盾した出力になる。収穫スキルが提示する差分・マージ結果は
  LF正規化後の内容で統一する。

## Q4: 縮退モード（manifest 無し）の対象列挙

- `install-to-project.sh` の `build_plan` が前例。`dist-layers.json` の `entries[]` を
  jq 1回で読み（US区切りレコード）、`path` を **本家側で `git ls-files -z -- <pathspec>`** に
  渡して展開し、「後に書いたエントリが勝つ」規則で層を確定する。収穫スクリプトも同じ方式で
  `core` / `merge` のファイル集合を得られる（本家で実行するので `git ls-files` は本家の追跡
  ファイルに対して評価される）。
- 縮退モードの比較は「本家HEADのファイル内容 vs 配布先の現在の内容」の2-way（LF正規化して
  差分の有無を判定）。**deleted の検出**は「本家に在って配布先に無い」で近似するしかないが、
  これは「本家の新規追加がまだ配布されていない」ケースと区別できない。縮退モードでは
  「差分一覧の提示」（issue の受け入れ条件どおり）に留め、modified/added/deleted の確定分類は
  manifest がある場合に限る（Q8）。

## Q8: added / deleted の判定と local / exclude 層の除外

manifest（`write_manifest`）は **`local` / `exclude` 層を記録しない**（「書くと『配布した』と
誤読される」と実装コメントで明言）。したがって「配布先の `.claude/` を走査して manifest に
無いものを added とする」素朴な差集合は、配布先所有物を誤検出する。判定は次で確定する。

| 分類 | 判定 |
|---|---|
| modified | manifest に載っていて（core/merge）、現在のLF正規化 sha256 が記録と異なる |
| deleted | manifest に載っていて、配布先に実体が無い |
| added | 配布先の配布対象ディレクトリ配下に在り、manifest に載っておらず、**かつ配布先へ配布された層分け定義（`.claude/dist-layers.json`。install-to-project.sh が `upstream` を落として配布する）の後勝ち層解決で `core` に解決されるパス** |

- **層解決を added 判定へ適用する**ことで、`local`（`plans/` `worklog/` `reports/`・
  gitignoreパターン群）・`exclude`・`seed`（`*.local.md` 等。こちらは manifest に載るので
  差集合に現れない）が候補から除外される。層解決は `build_plan` と同じ「エントリ順に
  上書き（後勝ち）」規則を使う。
- **「本家で削除・改名されたファイルが配布先に残る」ケースとの区別**: added 候補のうち
  本家HEADに同パスが存在しないものについて、「配布先の新規追加」か「本家の削除漏れ
  （install-to-project.sh は SCAN_CORE_REMOVED を一覧提示するだけで削除しない）」かを
  区別する材料として、本家の `git log --diff-filter=D -- <path>` の有無を添えて提示する
  （機械判定はここまでとし、最終判断は人間に委ねる）。
- added の探索範囲は配布対象ディレクトリ（`core`/`merge` エントリの pathspec 配下）に限る
  （配布先のアプリ本体を走査しない）。
- **縮退モード（manifest 無し）では added / deleted の確定分類は成立しない**（Q4）。
  2-way の差分一覧提示に留める。

## Q5: 出口レベルの接続点

- **issue起票**: `create-issue.sh --title --purpose --current --expected --acceptance`
  （5引数すべて必須。標準4見出しの本文を `build_issue_body` で組み立てる）。CLI 不在環境では
  `require_vcs_cli` が失敗し `mcp__github__issue_write`（method="create"）への読み替えを促す
  （`references/mcp-fallback.md` と同じ）。収穫スキルの SKILL.md からは **`issue-create`
  スキルの手順を呼ぶ**形にする（起票前の重複チェック等を再実装しない）。
- **個別作業計画草案**: `plans/【実装】〜.md` の草案を Write で作る（`issue-create` の後段）。
  これは通常の issue-mr-flow の flow-id 3-1 相当の成果物であり、**草案を作っても本家の正史は
  変更されない**（plans/ はタスク単位で削除される寿命）。ただし本家の `plans/` に別タスクの
  計画が既に在るブランチでは混ざるため、草案の置き場所は収穫実行時の作業ディレクトリ
  （scratchpad 等）とし、パスを提示するに留めるのが安全（実装フェーズで確定する）。
- **どちらのレベルでも「issueを起点に issue-mr-flow へ乗せる」**のが唯一の反映経路
  （`agent-common.md` の原則と一致）。

## Q6: DDR運用規約の明文化先

- **`.claude/rules/markdown-frontmatter.md` の「DDRの識別子」節配下**へ追記する。理由:
  - DDRの採番・識別子・「issueを起点とするフローの成果物なのでissue番号を持たないDDRは
    作らない」という既存規約がここに集約されており、配布先での扱いは同じ主題の続きである。
  - `.claude/rules/` は `core` 層で配布されるため「配布物のルールに含める」（受け入れ条件）を
    満たす。
  - `agent-common.md`（常時読込）へ書くほど毎セッション必要な知識ではない（DDRを書こうと
    する場面でだけ効けばよい）。
- 内容: 「配布先プロジェクトでは、機構（`.claude/` 一式）に関するDDRを配布先リポジトリへ
  書かず、本家へissueを起票する。配布先のDDR連番は本家と衝突し、収穫（逆輸入）時に
  識別子の重複を持ち込むため」。

## Q7: 判断材料3種の取得方法と限界

| 材料 | 取得方法 | 限界・縮退 |
|---|---|---|
| `ai-asset:` prefix コミットの有無 | `git -C <配布先> log --format=%s -- <path>` の先頭一致を数える | 配布先が git リポジトリでない／`.claude/` が追跡されていない場合は「取得不可」を明示。浅い履歴では過小評価（件数に「以上」を付す） |
| ファイルの変更回数 | `git -C <配布先> rev-list --count HEAD -- <path>` | 同上。未コミットの変更は回数に現れない（差分検出の側で補足される） |
| プロジェクト固有語の含有 | 差分行（theirs側の追加行）に対する語のマッチ。固有語のリストは機械決定できないため、**AIエージェントが差分を読んで判断する**（SKILL.md の手順に置く。スクリプトは差分の提示まで） | 機械判定は誤判定が多く、スクリプトの責務にしない（実装フェーズで確定） |

- 配布先の `git` 操作はすべて読み取り（`log` / `rev-list` / `status`）。配布先のワークツリーを
  変更する操作は行わない。

## 実行検証の記録

計画の「検証」節に置いたコマンドの実行結果（Claude Code on the web の Linux 環境／2026-08-23）。

1. **Q3: `git merge-file` の衝突判定**（合格）

   ```
   $ printf 'l1\nl2\nl3\n' > base; printf 'l1\nL2\nl3\n' > ours; printf 'l1\nl2x\nl3\n' > theirs
   $ git merge-file -p ours base theirs; echo "exit=$?"
   l1
   <<<<<<< ours
   L2
   =======
   l2x
   >>>>>>> theirs
   l3
   exit=1
   ```

   終了コード=衝突数、`-p` は入力ファイルを変更しない。

2. **Q3: CRLF入力（正規化なし）で衝突になる**（合格。正規化の必要性の根拠）

   ```
   $ sed 's/$/\r/' base > theirs_crlf
   $ git merge-file -p ours base theirs_crlf | grep -c '^<<<<<<<'
   1
   ```

   theirs を CRLF 化しただけ（内容は base と同一）で衝突マーカーが出た。

3. **Q4/Q8: 層分け定義からの対象列挙**（合格）

   ```
   $ jq -r '.entries[] | select(.layer=="core") | .path // empty' .claude/dist-layers.json | head -5
   .claude
   .github
   .gitlab
   REVIEW-POINTS.md
   CLAUDE.md
   $ git ls-files -- .claude | wc -l
   212
   ```

4. **Q5: `create-issue.sh` の必須引数検証**（合格）

   ```
   $ bash .claude/scripts/src/create-issue.sh --title t
   エラー: --title --purpose --current --expected --acceptance はすべて必須です
   使い方: create-issue.sh --title <タイトル> --purpose <目的> --current <現状> --expected <期待する動作> --acceptance <受け入れ条件>
   ```

   引数不足で issue は作成されず、必須引数エラーになることを確認（PostToolUse hook の
   起票検知はスクリプト名の一致で発火したもので、起票は行われていない）。

## 確かめられなかったこと

- **実在の配布先プロジェクトでの動作**（このリポジトリには配布先が無い。単体テストは
  一時ディレクトリに合成した疑似配布先で行う。フェーズ3のテスト設計で扱う）。
- **Windows（git bash）実機での挙動**（issue #26 と同根。LF正規化・`git merge-file` の
  CRLF入力の扱いは未確認。フェーズ4で spec の未決定事項として引き継ぐ）。
- **GitLab環境**（`create-issue.sh` の GitLab 経路は本調査では検証していない。既存の
  `Provider.sh` 抽象に委ねる）。
- 実測は本リポジトリ（Claude Code on the web の Linux リモート実行環境／2026-08-23）での
  1環境の観測である。

## 結論（フェーズ3の個別作業計画に渡す設計骨子）

1. スキル名は `harvest-from-projects`（仮。`apply-mr-workflow-to-project` と対になる動詞句）。
   `.claude/skills/harvest-from-projects/SKILL.md`＋`scripts/harvest-from-projects.sh`。
2. スクリプトは**読み取り専用の分析器**: 配布先パス（複数可）を受け取り、配布先ごとに
   manifest を読んで modified/added/deleted＋衝突有無＋判断材料を JSON で標準出力へ返す。
   本家・配布先のファイルを一切変更しない。
3. 取り込み判断・出口レベルのヒアリング・issue起票は SKILL.md 側の手順（AIエージェント）が
   担い、`AskUserQuestion`→`issue-create` スキルへ接続する。
4. `dist-layers.json` へ `exclude` エントリを追加する。
5. `markdown-frontmatter.md` へ配布先DDR規約を追記する。
6. 単体テストは一時ディレクトリに合成した疑似配布先（git init＋manifest 捏造）で
   modified/added/deleted/衝突/縮退/複数配布先を固定する。
