---
title: '作業結果: 収穫スキルの新設'
type: report
description: issue #27 収穫（逆輸入）スキル一式（SKILL.md・分析スクリプト・テスト・dist-layers・DDR規約）の実装結果と検証記録
tags: [report, harvest, implementation]
keywords: [harvest-from-projects, scan, merge3, gitignore照合, baseApproximate, removedUpstream, T14, passed=66]
---

# 作業結果: 収穫スキルの新設 — issue #27

個別作業計画 `plans/【AIアセット作成】【実装】【テスト】収穫スキルの新設.md`（敵対的レビュー
3回目の指摘20件を反映済みの版）に基づく実装の結果。

## 作成・変更したファイル

| ファイル | 操作 | 内容 |
|---|---|---|
| `.claude/skills/harvest-from-projects/SKILL.md` | 新規 | 収穫スキルの手順定義（Step 1〜6・してはいけないこと・制約） |
| `.claude/skills/harvest-from-projects/scripts/harvest-from-projects.sh` | 新規 | 読み取り専用の差分分析スクリプト（scan / diff / merge3。768行） |
| `.claude/scripts/test/test_harvest_from_projects.sh` | 新規 | 単体・結合テスト（T1〜T23。アサーション89件・スキップガード付き） |
| `.claude/dist-layers.json` | 変更 | `harvest-from-projects` の `exclude` エントリを追加 |
| `.claude/rules/markdown-frontmatter.md` | 変更 | 「DDRの識別子」節配下へ「配布先プロジェクトでの機構DDRの扱い（issue #27）」を追記 |
| `index.md` | 変更 | Repository Map のスキル一覧へ `/harvest-from-projects` を追記（敵対的レビュー4回目の指摘） |

## 実装の要点（計画からの確定事項）

- **scan の出力**は `{"schemaVersion":1,"targets":[...]}`。配布先単位のエラー隔離
  （読めない配布先は `{"path":...,"error":...}`）を実装した。manifest の検証は
  `[ -s ]`→`jq -e '(.schemaVersion == 1) and ((.files | length) > 0)'` の順で行い、**妥当な
  JSON でも `.files` が空・形式違いでレコードを1件も読めない場合は縮退へ倒す**（通常経路へ
  進むと added 判定が全件素通りし、配布先の全ファイルを added と誤報するため。敵対的レビュー
  4回目の指摘）。
- **エラー隔離の実装形**: `( scan_one_dest ) || rc=$?` は使わない。bash は `||` による
  errexit の一時停止を**サブシェルの内部まで伝播させる**ため、関数内の途中失敗が素通りする
  （実測: bash 5.2.21 で `( f ) || rc=$?` は f 内の false の後も実行が続き rc=0。
  `.claude/rules/shell-script-style.md`「エラー方針」の記述はこの実測と食い違っており、
  フェーズ4で訂正が要る）。代わりに**条件文脈の外でサブシェルを実行し、内側で `set -e` を
  掛け直す**形（`set +e; ( set -e; scan_one_dest ); rc=$?; set -e`）にした（実測で
  内部失敗の即時中断と rc への伝播を確認済み）。
- **分類**: modified は層・strategy 別（core=LF正規化sha256／merge/lines-marker=LF正規化後の
  全体sha256／merge/json-keys=キーごとの `jq -c getpath` 出力のsha256。**strategy は明示分岐し、
  未知・欠落・keys 空は「変更あり」側へ倒す**——フェイルオープンにすると改変が無言で候補から
  落ちるため。敵対的レビュー4回目の指摘）。deleted は core/merge 限定で、**本家HEADにも無い
  ものは `removedUpstream`**（収穫対象外の別枠）として status 値ごと分けた。added は配布先の
  dist-layers.json による自前 pathspec 照合（完全一致＋ディレクトリ前方一致・後勝ち）＋
  gitignorePattern 照合（自前サブセット実装のみ。`git check-ignore` 不使用）＋機構生成物
  （manifest 自身・`*.bak`）の明示除外。縮退モードのレコードも `emit_record` 経由で出し、
  **配布先が git なら判断材料（`aiAssetCommits` / `changeCount`）が通常経路と同じに埋まる**。
- **conflict**: core かつ base 解決可のときだけ `git merge-file` で事前判定
  （0=clean／1〜127=conflict／それ以外=unknown）。`-dirty` 付き記録SHAは **-dirty を落として
  解決を試み、3-way を実行したうえで `baseApproximate: true`** を立てる（一律 unknown に
  しない）。merge 層と `.claude/dist-layers.json` は 3-way 対象外（後者の diff は本家側へ
  `del(.upstream)` を掛けて比較する）。
- **merge3 の終了コード**: 0=衝突なし／1=衝突あり／2=base取得不可で 2-way へ縮退／
  3=その他エラー（**層を判定できない場合のフェイルクローズを含む**）／4=3-way の対象外
  （merge 層・**seed 層**・dist-layers.json）。層の判定は **manifest の `.files[].layer` を
  第一情報源**にし、無ければ dist-layers.json の照合で解決する。どちらも読めなければ
  実行せず 3 で止める（敵対的レビュー4回目の指摘: 無言のスキップは「exit 0=そのまま
  取り込める」の誤読を招く）。
- **git 起動の一括化**: 本家パス集合は `ls-tree -r` 1回・削除履歴は
  `log --no-renames --diff-filter=D --name-only` 1回・配布先の判断材料は
  `log --format='%x01%s' --name-only` 1回を awk で畳み込み・縮退モードの本家HEAD展開は
  `git archive | tar -x` 1回（**パイプラインの終了コードと展開結果の非空を明示検査**し、
  失敗を「差分なし」と混同しない）。ファイル数に比例する git 起動は「core かつ modified」に
  限定した `git show`（base/ours の実体化）と `git merge-file` のみ。
  **2本の `git log` には `-c core.quotepath=false` を付ける**（無いと非ASCIIパスが8進
  エスケープでクォートされ、実パスとの突き合わせが全件空振りする。DDR等の日本語ファイル名が
  主要な対象）。削除履歴は `--no-renames` で改名（`git mv`）の旧パスも D として拾う
  （いずれも敵対的レビュー4回目の指摘）。
- **読み取り専用**: 書き込みは `mktemp` の一時領域のみ。git は show / cat-file / ls-files /
  ls-tree / log / rev-parse / archive / merge-file に限定（すべて読み取り専用）。
- **awk の件名マーカー判定**は `\x01` の正規表現エスケープ（処理系依存）を避け、POSIX の
  8進文字列 `"\001"` と `substr` の比較で書いた。
- jq フィルタ内の US 区切りは生バイトではなくエスケープ表記 `\u001f` で書いた
  （`shell-script-style.md`「ソースコードへ生の制御文字を書かない」。初版で生バイトを
  書いてしまい、バイト数比較（`tr -d '\037'` 前後）で検出して置換した）。

## 検証の記録

計画の「検証」節のコマンドの実行結果（Claude Code on the web の Linux 環境／2026-08-23）。

1. **構文チェック**（合格）

   ```
   $ bash -n .claude/skills/harvest-from-projects/scripts/harvest-from-projects.sh
   （出力なし・終了コード0）
   ```

2. **テスト T1〜T23**（合格。敵対的レビュー4回目の反映で T16〜T23・23アサーションを追加）

   ```
   $ bash .claude/scripts/test/test_harvest_from_projects.sh
   passed=89 failures=0
   ```

   初回実装時（T1〜T15・66件）は `T10: /usage/ はルート以外に一致しない` の1件が失敗した
   （`passed=65 failures=1`）。原因は `gitignore_matches` で、`/usage/` のようにアンカーを
   剥がすとスラッシュが残らないパターンが「任意階層のセグメント照合」へ流れ、`src/usage/` にも
   一致していた。アンカー付きはルート直下のセグメントにだけ一致させる分岐をセグメント照合の
   前へ追加して解消（テストが設計どおり境界を検出した実例）。

   追加分の内訳: T16=非ASCII（日本語）ファイル名の upstreamDeleted・判断材料の突き合わせ／
   T17=本家で改名（`git mv`）された旧パスの upstreamDeleted／T18=2件目の lines-marker
   （`.gitattributes`）の指紋比較／T19=存在しない配布先の error レコードと隔離・
   T19b=`git archive | tar` 失敗時に「差分なし」でなく error になること（tar スタブで再現）／
   T20=`files: []` の manifest が縮退へ倒れること／T21=層を判定できない merge3 の
   フェイルクローズ（exit 3）／T22=未知 strategy・keys 空が「変更あり」側へ倒れること／
   T23=usage に3サブコマンドすべてが出ること。あわせて T5 に「縮退でも git 配布先なら
   判断材料が埋まる」、T14 に dist-layers.json と manifest レコード由来の exit 4 を追加した。

3. **層分け定義の網羅性**（合格。`git add` 後に実行——検査3が `git ls-files` で判定するため）

   ```
   $ bash .claude/scripts/src/check-dist-coverage.sh
   検査1 追跡ファイルの分類: 458 / 458 件
   検査2 .gitignore の行の被覆: 9 / 9 行
   検査3 空振りエントリ: 0 件（うち pathspec として不正 0 件）
   検査4 layer / strategy の妥当性: 不正 0 件
   結果: OK（4種すべて通過）
   ```

4. **frontmatter のインデックス実問い合わせ**（合格）

   ```
   $ bash .claude/scripts/src/extract-frontmatter.sh . >/dev/null
   $ jq -e 'select(.concept_id == ".claude/skills/harvest-from-projects/SKILL") | .frontmatter.type == "skill"' \
       .claude/skills/harvest-from-projects/index.jsonl
   true
   ```

   計画に書いた問い合わせ（`.path` / `endswith`）は index.jsonl の実スキーマ
   （`concept_id` / `frontmatter.type`）と合っておらず
   `endswith() requires string inputs` で失敗した。実スキーマに合わせた上記の形へ修正して
   検証した（検証コマンド自体も「実データで空振りしないか」の確認が要るという教訓）。

## 受け入れ条件との対応（実測）

| 受け入れ条件 | 実装 | 固定するテスト |
|---|---|---|
| core 層変更が列挙される | scan の modified | T1 |
| 本家側変更と衝突ありの区別 | conflict=clean/conflict/unknown | T2a/T2b |
| 新規追加が候補列挙 | added（3段の除外付き） | T3（T7 で誤検出防止4種、T16/T17 で非ASCII・改名旧パス） |
| 削除が列挙 | deleted / removedUpstream | T4 / T4b |
| manifest 無しの縮退モード | degraded・status="differs" | T5（T19b/T20 で失敗時の縮退・error） |
| 複数配布先パス | scan 可変長引数＋エラー隔離 | T6 / T19 |
| 出口レベル確認・停止・正史不変更 | SKILL.md Step 3〜6＋読み取り専用設計 | T11 |
| issue-create 経由の起票 | SKILL.md Step 5 | —（手順であり機械検証の対象外） |
| DDR規約が配布物のルールに記載 | markdown-frontmatter.md へ追記（core 層） | —（検査3の分類で core を確認） |

## 確かめられなかったこと

- **実在の配布先プロジェクトでの動作**（テストは合成配布先6種による。実配布先での
  試運転は本 PR のマージ後、実際の収穫の初回で行う）。
- **Windows（git bash）実機での挙動**（`git archive | tar` 経路・`find -print0` を含む。
  フェーズ4で spec の未決定事項として引き継ぐ）。
- **SKILL.md の対話手順（AskUserQuestion・issue-create 接続）の通し実行**（非対話セッション
  のため。手順はドキュメントとしてのみ検証した）。
- 実測は本リポジトリ（Claude Code on the web の Linux リモート実行環境／2026-08-23）での
  1環境の観測である。
