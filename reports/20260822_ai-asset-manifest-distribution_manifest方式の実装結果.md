---
title: manifest方式の配布機構の実装結果
type: report
description: issue #26 フェーズ3の実装結果。層分け定義・網羅性チェック・2パス構成のインストーラ・AGENTS.md分割と、受け入れ条件1〜10の充足状況
tags: [distribution, manifest, report, issue-26]
keywords: [dist-layers, asset-manifest, core, seed, merge, local, exclude, install-to-project, check-dist-coverage, setup-gemini-links, lines-marker, json-keys, CRLF, 冪等]
---

# manifest方式の配布機構の実装結果（issue #26 フェーズ3）

対応する計画: `plans/【設計】【実装】【テスト】manifest方式の配布機構.md`、
`plans/【AIアセット作成】配布ドキュメントとAGENTS分割.md`

## 結論

**受け入れ条件1〜10をすべて実装し、実際に動かして確認した**（11はフェーズ4のDDR）。
全17テストファイル・**1084件**の表明が通っている（敵対的レビュー2回目の反映後）。

新方式では、旧実装の中間生成物（`assets/`）とビルド工程（`.skill`）が丸ごと不要になり、
**配る内容の定義が本家の実状態そのもの**（`.claude/dist-layers.json` と、マーカーで囲まれた
`.gitignore` / `.gitattributes` の実行）になった。写しを持たないので、実状態とずれようがない。

## 成果物

### 新規

| ファイル | 役割 |
|---|---|
| `.claude/dist-layers.json` | 層分け定義（42エントリ）。**何をどう配るかの単一の正** |
| `.claude/scripts/src/check-dist-coverage.sh` | 網羅性チェック（4種） |
| `.claude/rules/agent-common.md` | `AGENTS.md` から切り出した共通ルール9項目 |
| `.claude/skills/apply-mr-workflow-to-project/assets/AGENTS.md.template` | `seed` の汎用雛形 |
| `.claude/skills/apply-mr-workflow-to-project/assets/REVIEW-POINTS.local.md.template` | 配布先所有の観点表の空雛形 |
| `.claude/skills/apply-mr-workflow-to-project/assets/HANDOFF.md.template` | `seed` の雛形。`cleanup-task.sh` の `HANDOFF_TEMPLATE` と同一 |
| `.claude/skills/apply-mr-workflow-to-project/assets/index.md.template` | `seed` の雛形（Repository Map。配布先固有の節は空欄） |
| `.claude/scripts/test/test_check_dist_coverage.sh` | 26件 |
| `.claude/scripts/test/test_setup_gemini_links.sh` | 24件 |

### 変更・削除

| ファイル | 内容 |
|---|---|
| `install-to-project.sh` | **全面書き直し**（2パス構成・manifest・5層） |
| `sync-assets.sh` | **削除**（受け入れ条件10） |
| `setup-gemini-links.sh` | 実体コピーへのフォールバックと同期を追加 |
| `collect-review-points.sh` | `.local` の収集。**スキップの単位をディレクトリからファイルへ** |
| `cleanup-task.sh` | `REVIEW-POINTS.local.md` を削除対象から除外 |
| `.gitignore` | マーカー化。`/build/` と `assets/` の行を削除 |
| `AGENTS.md` / `CLAUDE.md` / `GEMINI.md` | 分割・ポインタ化 |
| `DEVELOPERS.md` / `apply-mr-workflow-to-project/SKILL.md` | `.skill` 手順を配布手順へ置き換え |
| `.claude/rules/` 3件・`commit/SKILL.md` | `.local` の運用と `ai-asset:` の線引き |
| `index.md` / `directory-structure.md` | `build/` を削除し `dist-layers.json` を追加 |

## 設計の要点

### 層分け定義（`.claude/dist-layers.json`）

- `path` は**git pathspec** として `git ls-files -z -- "$path"` に評価させる（globの意味論を
  bashで再実装しない）。
- **後に書いたエントリが勝つ**（`.gitignore` と同じ規約）。`.claude` を広く `core` にし、
  `settings.json`（`merge`）と `apply-mr-workflow-to-project`（`exclude`）を後ろに書くだけで
  例外が表せる。**この形のおかげで、今回追加した新規ファイル7件も自動的に被覆された**。
- `source` は「配布先へ置く内容が本家の実ファイルと違う `seed`」のためのフィールド。
  これにより (a) 本家に意味の無い空の `REVIEW-POINTS.local.md` を4つ置かずに済み、
  (b) `AGENTS.md` から本家固有の3行を落として配れる。
- `gitignorePattern` は `local` 専用。追跡されないパス（実行時生成物）を表す。
- `header` は `lines-marker` 専用。配布先へ付ける由来のコメント（旧実装の挙動を引き継ぐ）。

### 網羅性チェック（4種）

| 検査 | 結果 |
|---|---|
| 1. 追跡ファイル全件の分類 | 184 / 184 件 |
| 2. `.gitignore` の全行の被覆 | 12 / 12 行 |
| 3. 空振りエントリ | 0 件 |
| 4. `layer` / `strategy` の妥当性 | 不正 0 件 |

- **配布先では検査自体をスキップする**（定義に `upstream` の印が無い場合）。配布先の自前ソースを
  全件「未分類」と報告しても意味が無いため。無言のスキップにはせず件数を出す。
- **検出が効くことをテストで確かめている**。定義から意図的に1件落とした一時ツリーで、
  4種それぞれが実際に落ちることを確認した（`test_check_dist_coverage.sh`）。

### インストーラ（2パス構成）

受け入れ条件4「上書きの**前に**警告と一覧を出す」は1パスでは満たせないため、
**走査 → 提示 → 配置**の3段にした。副次的に、旧実装の欠陥#4（`HAS_WARNED` が
`safe_copy_dir` のサブシェル外へ伝わらない）が構造的に消えた。

`merge` の2方式:

| strategy | 対象 | 処理 |
|---|---|---|
| `lines-marker` | `.gitignore` `.gitattributes` | マーカー間のコメント・空行を除く行を、行全体一致で無ければ追記 |
| `json-keys` | `.claude/settings.json` | 指定キーのみ更新。**値が配列なら和集合、それ以外は全置換** |

`json-keys` で「配列なら和集合」という規則を採ったことで、`permissions.deny`（配布先が足した
行を消さない）と `hooks`（本家で全置換）の両方が**1つの規則で**満たせた。

## 受け入れ条件の充足（実測）

| # | 条件 | 確認方法 | 結果 |
|---|---|---|---|
| 1 | 層分け定義が全パスを分類 | `check-dist-coverage.sh` | 184/184 件 OK |
| 2 | 未適用リポジトリへ core/seed/merge を配置し manifest を生成、`local` は触らない | 一時配布先へ実適用 | core 155 / seed 8 / merge 3、manifest 166件。`index.jsonl` 0件・`.claude/state/` 無し・`usage/` 無し |
| 3 | 編集した `HANDOFF.md` を再適用で上書きしない | 編集 → 再適用 | 内容が保持された |
| 4 | 編集した `core` は上書き**前**に警告＋一覧 | `--dry-run` と実適用 | 警告・一覧が出て、`.bak` が残った |
| 5 | manifest の commit + sha256 で変更を判定 | 書き換え有無で比較 | 書き換え時のみ列挙、無変更なら0件 |
| 6 | 本家が dirty なら中断 | `--allow-dirty` 無しで実行 | 終了コード非0で中断 |
| 7 | リンクを作れない環境で実体コピー＋終了コード0 | `ln`/`cmd.exe` のスタブ | 終了コード0、実体コピー、その旨を全対象で出力 |
| 8 | 実体コピーの再適用で最新へ一致 | 追加・変更・削除の3種 | 3種とも反映。**`.claude/` 側は無傷** |
| 9 | `AGENTS.md` = import + 概要、共通ルールは `.claude/rules/` | 項目数を両側で数える | `agent-common.md` 9件 / `AGENTS.md` 0件 |
| 10 | `sync-assets.sh` と `.skill` 手順を削除、`DEVELOPERS.md` を更新 | `git grep` | 追跡ファイルの参照 0件（point-in-time の記録4行を除く） |

## 実装中に見つけた不具合（すべて修正済み）

**書いたものを実際に流したことで見つかったものばかりである。**

| # | 症状 | 原因 |
|---|---|---|
| 1 | 定義の列がずれ `git ls-files -- /usage/` が `fatal` | 区切りに**タブ**を使った。タブはIFSの空白文字なので、空の列があると `read` が連続タブを畳む。`\u001f` へ変更 |
| 2 | 網羅性チェックが未分類を**検出できない**のに検証は通る | プローブを `.claude/` 配下に置き、広域の `core` エントリに被覆されていた。ルート直下へ変更 |
| 3 | `printf: --: invalid option` | 書式文字列が `--` で始まりオプションと解釈された。本文を引数側へ |
| 4 | manifest 生成で `jq: object and string cannot be divided` | `getpath(. / ".")` の `.` が期待した文字列ではなくパイプ元のオブジェクトを指していた |
| 5 | ソースに**生の制御文字**（0x1F）が3箇所混入 | `\u001f` と書いたつもりが実体で書かれていた。エスケープ表記へ置換し、バイト数比較で検査 |
| 6 | **CRLF の配布先で行が3回追記される**（既存欠陥#1の再発） | 配布先のCRを落とさずに `grep -Fx` で比較していた。CR除去後の写しと突き合わせるよう修正 |
| 7 | `cygpath: command not found` が標準エラーへ漏れる | `cmd.exe` の存在だけを確認していた |

**#6 は、旧実装が既に直していた欠陥を作り直しで再発させたもの**である。棚卸し表に基づいて
引き継いだテスト（「CRLFの配布先でも1行のまま」）が捕まえた。**受け入れ条件だけを見て
テストを書き直していたら、無言で退行していた。**

## 意図的に落とした挙動

| 旧実装 | 判断 |
|---|---|
| `plans/.gitkeep` `worklog/.gitkeep` の作成 | **落とす。** 両ディレクトリは `local` になり「何もしない」対象。空ディレクトリの維持は配布先の関心事 |
| Goプロジェクト自動検知（`go.mod` 検知・`AGENTS.md` への追記・`go-applications.md` の削除） | **廃止。** `AGENTS.md` は `seed` になるため、追記が受け入れ条件3と衝突する。`go-applications.md` は本リポジトリに存在せず、削除処理は既に空振りしていた |
| `.gitattributes` のヘッダコメント | **引き継ぐ**（定義の `header` フィールドへ移した）。落とすと配布先に由来の分からない行だけが残る |

いずれもテストで「作られないこと」「残ること」を表明している。

## 敵対的レビュー2回目の反映（flow-id 3-9）

diff全体に対する2回目の敵対的レビューで**14件**の指摘を得た。うち**10件をPR #154 へ
インライン投稿**し、4件は会話へ報告した。1周目で11件を反映して2件はユーザー判断を仰ぎ、
**2周目で判断が下りた分を反映して、最終的に13件を反映・1件を見送り**とした。

### 反映した内容

| 指摘 | 重大度 | 直し方 |
|---|---|---|
| 壊れた配布先 `settings.json` を0バイトへ破壊し、成功として終了 | blocker | マージ前に配布先JSONを検証（**空文字列の検査を `jq -e .` より先に**）。加えて `jq` の終了コードを見てから書き戻す |
| `func \|\| return 1` が `set -e` を関数内部まで一時停止 | major | `main` は `if [ ... ]; then main "$@"; fi` の**then節**から呼ばれているので、**`\|\| return 1` を外すだけ**で `set -e` が正しく効く |
| `upstream: true` がそのまま配布され、配布先スキップが無効 | major | 配布時に `jq 'del(.upstream)'` で印を落とす（対象は定数 `DEF_REL` で判定） |
| 網羅性チェックがcwd依存で、本家ルート以外から起動すると必ず中断 | major | 定義ファイルを絶対パスで渡し、`check-dist-coverage.sh` 側が**定義ファイルの置かれたリポジトリ**へ `cd` する（git管理外の定義なら従来どおり cwd） |
| `--force` のとき「`.bak` として残します」と嘘をつく | minor | 判定不能側の警告も `--force` で出し分け、退避されずに失われる旨を明示 |
| `--allow-dirty` で常に `-dirty` が付く | minor | `UPSTREAM_DIRTY` を導入し、**実際に未コミットの変更があったときだけ**付ける |
| マーカーENDの欠落を検出できず全行が配られる | minor | 戻り値を `found_begin && inside == 0` にした |
| 雛形が実物のレビュー観点表として収集される | minor | `templates/{AGENTS.md,REVIEW-POINTS.local.md}` を `.template` 付きへ改名し、定義の `source` を追随 |
| `--help` の末尾に `set -euo pipefail` が混ざる | minor | 行番号での切り出しをやめ、「コメントでない最初の行」の手前まで `awk` で取る |
| dirtyガードが未追跡ファイルを見ない | minor | エントリの `path`（ディレクトリのまま）を pathspec にして**件数を出す**（中断はしない）。`exclude` 層は `:(exclude)` で除く |
| 候補行ごとに `grep` を起動 | nit | 既存行を連想配列へ1回で読み込み、forkをゼロにした |

### ユーザー判断が下りた4件（2周目で反映）

| 指摘 | 下りた判断 | 反映内容 |
|---|---|---|
| `set -e` の直し方 | **サブシェル化できない関数は、内部の各コマンドの終了コードを明示的に検査するほうへ倒す** | `run_or_fail <説明> <コマンド...>` を追加し、`cp` / `mkdir` の9箇所へ適用。`git status` / `git rev-parse` / `tr` の失敗も個別に検査。呼び出し側の素の呼び出し（`set -e` が効く形）はそのまま残し、多重防御にした |
| `HANDOFF.md` / `index.md` の `seed` | **`templates/HANDOFF.md` を追加して `source` で指す** | `HANDOFF.md.template` / `index.md.template` を追加し、定義の `source` で指した。前者は `cleanup-task.sh` の `HANDOFF_TEMPLATE` と**同一である必要がある**ため、本文とバイト数の一致を `test_cleanup_task.sh` が表明する |
| 削除・改名された `core` の追従 | **一覧の提示のみ**（削除は人間） | 前回manifestの `core` パス − 今回の `PLAN_PATHS` を `SCAN_CORE_REMOVED` として洗い出し、提示とサマリへ出す。**配布先のファイルは消さない。** `SKILL.md` にも「配布元で削除・改名されたファイルは、配布先に残る」節を追加 |
| 回帰テストが blocker を単体で検出できない件 | **この形のままでよい** | 変更なし（多重防御のどちらか一方が生きていれば通る表明として維持） |

### 2周目で併せて塞いだ穴（指摘されていないが同類型）

**`build_plan` が配布対象0件でも成功していた。** `read_entries_records` はプロセス置換の中で
走るため、jq が失敗しても `while` が0回まわるだけで、以降は「core を 0 件配置しました」と
成功で終わる。「失敗が成功として報告される」という blocker と同じ類型なので併せて塞いだ。

### 見送り

| 指摘 | 扱い |
|---|---|
| `gitignorePattern` が「配る行／配らない行」を区別できない | **見送り**。定義のスキーマ変更（`distributed` 相当のフィールド追加）と検査2の双方向化を伴うため、フェーズ4のspecで未決定事項として扱う |

### テスト

`test_install_to_project.sh` へ節C（7ケース・17表明）と節D（3ケース・14表明）、
`test_check_dist_coverage.sh` へcwd非依存の2表明、`test_cleanup_task.sh` へ雛形の同期2表明を
追加した。**全17ファイル・1084件が通過**（1049件から+35）。

**節Cはどれも受け入れ条件1〜11に現れない挙動である。** 条件だけを見てテストを書くと
抜け落ちる種類のものなので、指摘ごとに1件ずつ表明を残した。

**検出が効くことは、修正を実際に戻して確かめた。** ただし blocker については、
**`set -e` の修正だけで「中断する」「0バイトにしない」の両方が満たされてしまう**ため、
blocker修正を単体で戻しても落ちない。**両方を戻して初めて `actual: 0`（0バイト）で落ちた。**
テストは多重防御のどちらか一方が生きていれば通る表明として、この形のまま残している。

## mainのマージで生じた食い違いの解消（2026-08-23）

レビュー合意の直後に `origin/main` が PR #156（issue #54）・#158（issue #103）で進んでいたため、
`resolve-conflict` の**監視モード**で取り込んだ。gitがコンフリクトとして報告したのは
`.gitignore` と `DEVELOPERS.md` の2件だけだったが、**gitが競合と見なさない食い違いが2件あった**。

| # | 食い違い | なぜgitが気づかないか | 解消 |
|---|---|---|---|
| 1 | issue #54 が「スキルのバンドルリソースに `templates/` を使わない」というルールをmainへ入れた一方、こちらは同じ回に `apply-mr-workflow-to-project/templates/` を**新設**していた | 追加したファイル名が両ブランチで異なる（`canvas-report/templates/` と `apply-mr-workflow-to-project/templates/`） | mainの新ルールに従い `assets/` へ改名。`dist-layers.json` の `source` 4種とテスト2本の参照を追随 |
| 2 | `directory-structure.md` が「`apply-mr-workflow-to-project/assets/` は `sync-assets.sh` が生成する `.gitignore` 対象のビルド用一時ディレクトリ」と書いていた | main側だけが触った行で、こちらは触っていない | issue #26 で `sync-assets.sh` を廃止済みのため、現状（Git管理下の恒久のバンドルリソース）へ書き換え。`scripts/` の実例も `install-to-project.sh` へ差し替え |

**2件目を放置すると、新設した `assets/` が「Git管理外」だと読める**ドキュメントが残る。
実際 `.gitignore` の該当行はこちらのブランチが既に削除済みで、
`git check-ignore` でも無視されないことを確認した。

- **`.template` の接尾辞は残す。** `assets/` へ移しても、`collect-review-points.sh` と
  `extract-frontmatter.sh` に拾われないという理由は変わらない
  （main側の `reports.template.html` は `.html` なのでこの制約を受けない）。
- **`.gitignore` へ増えた `/.claude/settings.local.json`（issue #103）に対応する `local`
  エントリを層分け定義へ追加した**（無いと検査2が落ちる）。**マージのたびに層分け定義の
  更新が要る**という、この方式の運用コストが初めて実地で現れた例である。
- **マージ途中に `check-dist-coverage.sh` を流すと、追跡ファイル数が水増しされる**（実測: 208 →
  解消後 204）。`git ls-files` は未マージのパスをステージ1〜3の**3回**返すため。検査自体は
  通るので実害は無いが、件数を根拠に判断しないこと。

検証は `resolve-conflict` の Step 5 をすべて実施した（マーカー0件・未マージ0件・`bash -n`・
生成物の再生成・**全17テスト 1084件が通過**・DDR識別子の重複なし・網羅性チェックOK・
`git diff HEAD -- HANDOFF.md` が0行）。

## 敵対的レビュー3回目の反映（flow-id 3-9 の3周目）

フェーズ3の敵対的レビューを3回目（上限）まで実施し、**16件の指摘のうち10件をPR #154 へ
インライン投稿**した。ユーザーの判断は「3周目のレビュー往復で直す」で、**投稿した10件と、
基準未満で会話報告に留めた6件のうち5件を、この周で直した**（残り1件はフェーズ4へ回す）。

### 配布先を壊していた1件（major）

`test_check_dist_coverage.sh` が**配布先で必ず `passed=11 failures=15` になっていた**。
`.claude/scripts/test/` は core として丸ごと配られるのに、スキップ判定が
「対象ファイルが存在するか」だったためである。配布先にも `check-dist-coverage.sh` と
`dist-layers.json`（`upstream` を落としたもの）は届くので、**スキップに入らないまま
本家でしか成立しない期待値を検査していた**。

判定を `jq -e '.upstream == true'` へ変え、配布先ではスキップするようにした。
**配布して実際に流し、17本すべてが緑になることを確認した**（修正前はこの1本だけが赤）。

あわせて、このテストが `git add -N` / `git rm --cached` で**実行先リポジトリのindexを
書き換えていた**のもやめた。`GIT_INDEX_FILE` へindexの写しを渡せば `git ls-files`（検査1の分母）
はその写しを見るので、実リポジトリのindexは1バイトも変わらない。「実リポジトリのindexに
プローブが入っていない」ことも表明に加えた。

### 起動回数をファイル数に比例させない（major）

`install-to-project.sh` が**配布1回あたり外部コマンドを1208回**起動していた（計数スタブでの実測）。
git bashの実測値95ms/回では約115秒で、しかもcore件数（163）に比例して伸びる。4か所を直した。

| 直した箇所 | 前 | 後 |
|---|---|---|
| sha256（`tr`+`sha256sum`+`cut` を1ファイルずつ×2パス） | 564 | 15（`sha256_lf_batch`。CRを含むファイルだけ `grep` 1回で洗い出し、残りは `sha256sum` 1回） |
| manifestのエントリ組み立て（`jq -nc` を1件ずつ） | 196 | 11（区切り付き中間表現＋`jq -R -n` 1回） |
| `mkdir -p`（1ファイルずつ） | 187 | 35（`ensure_dir` でメモ化） |
| `cp`（1ファイルずつ） | 182 | 42（宛先ディレクトリ単位へまとめる） |

**総起動数 1208 → 176**（同じ計数スタブで再実測）。残る最大は `git` 65回だが、これは
エントリ数（42）に比例するもので、リポジトリのファイル数では増えない。

### コマンドライン長の上限（major）

dirty判定が `git status --porcelain -- "${specs[@]}"` へ**187パス・28,319バイト**を渡していた。
Windows の `CreateProcess` の上限は32,767文字で、`.claude/` へ数十ファイル増えれば超え、
**配布が始まる前に止まる**。

本家全体の `git status --porcelain -z --untracked-files=no` を1回だけ取り、配布対象かどうかは
bash側の連想配列で突き合わせる形へ変えた。**`git status` は `--pathspec-from-file` を持たない**
（git 2.43 で実測。レビューの提案どおりには直せなかった）ため、pathspecを渡すのをやめる方向で
解いている。`-z` で受けるので改名エントリ（`XY <新パス>\0<旧パス>\0`）も正しく分解できる。

### `AGENTS.md` 分割の移行漏れ（major）

`AGENTS.md` の共通ルールを `.claude/rules/agent-common.md`（core）へ切り出したが、`AGENTS.md`
自体は `seed` のままだった。**旧方式は本家の `AGENTS.md` 全文を配っていた**ので、既存の配布先には
切り出し前の共通ルール9項目が残り、`agent-common.md` と二重化して恒久的に食い違う。

`AGENTS.md` を `core` にはしない（プロジェクト概要が配布先の所有物であり、`core` にすると
再適用のたびに消える）。代わりに、層分け定義へ**任意キー `requiredLine`** を足した。

- `seed` が既に存在し、`requiredLine` の行を含まないとき、**触らずに一覧で知らせる**
  （`SCAN_CORE_REMOVED` と同じ「提示のみ」）。
- `AGENTS.md` の `requiredLine` は `@./.claude/rules/agent-common.md`。
- `check-dist-coverage.sh` の検査4へ「`requiredLine` は seed 専用」を追加した。
- 旧方式の配布先を模したディレクトリで、実際に注意が出ること・`AGENTS.md` が書き換わらないこと・
  配った直後の配布先では出ないことを表明に加えた。**雛形自身が `requiredLine` を含むこと**も
  表明する（含まないと検知が常に真になり、検証として意味を失うため）。

### 検証が空振りしていた1件（minor）

検査2の `while IFS= read -r line; do ... done < .gitignore` が、**末尾に改行が無い最終行を
読み落として**いた。載せ忘れがあっても「13 / 13 行」と満点で報告する形である。
`|| [ -n "$line" ]` を付け、末尾改行なしの `.gitignore` で最終行が実際にNGとして挙がることを
確かめた。同じファイルを読む `install-to-project.sh` 側は元からこの形で、**同じ入力に対して
2つのスクリプトの読み方が違っていた**。

### 雛形の定型文が観点表へ混ざる（minor）

`REVIEW-POINTS.local.md` の雛形が持つ使い方の説明（HTMLコメント）とプレースホルダが、
`collect-review-points.sh` にそのまま観点として拾われていた。配布直後は4箇所ぶんの定型文が
観点表へ混ざる。

- `strip_frontmatter_and_h1` を `strip_frontmatter_h1_and_comments` へ変え、HTMLコメント
  （1行・複数行の両方）を落とすようにした。
- 雛形のプレースホルダをコメントの中へ移し、**未編集の `.local` は中身が空**になるようにした。
- 中身が空の観点表は**見出しごと出さない**。ただし無言では捨てず、件数を標準エラーへ出す。
- 配布先で実際に収集し、定型文の混入が0件・スキップ2件になることを確認した。

### 計画・レポートのHTMLビューが揃っていなかった（major / minor）

issue #54 が `plans/` `reports/` の各mdへ**同名の `.html`（人間レビュー用ビュー）を併存させる**
ことを必須にしているが、このブランチでは揃っていなかった。

| ファイル | 前 | 後 |
|---|---|---|
| `plans/` 4件（全体1・個別3） | **HTMLが1件も無い** | 4件すべて作成 |
| `reports/…実装結果` | **HTMLが無い** | 作成 |
| `reports/…層分け調査.html` | md側の `## 検証に使ったコマンド` 節が無く、節の順序・見出し文言もずれる。土台がテンプレートではなくTailwind CDN | テンプレートから作り直し、mdの節と1対1へ |

- 土台は `.claude/skills/issue-mr-flow/assets/{plans,reports}.template.html` を使い、
  テンプレートの `<style>` ごと再利用した（CSSを書き写さない）。**外部依存は0件**で、
  Tailwind CDNの参照も無くなった（前は層分け調査のHTMLが読み込んでいた）。
- 検証は3点を全ファイルで確認した。**テンプレートのプレースホルダ（`<!-- ここに書く` ）の残り0件**、
  **外部読み込み（`src="http`・外部CSS・`cdn.`）0件**、**md の `##` 見出しとHTMLの `<h2>` が
  1対1に対応すること**。見出しの照合では、`<h2>` に `<code>` を含む行が
  `<h2>[^<]*</h2>` で拾えず「欠落」に見えたため、タグを除去してから比較している
  （md側にコードブロック内の `##` があるので、そちらは対象外）。

### そのほか（minor / nit）

| 対象 | 直した内容 |
|---|---|
| `install-to-project.sh` の merge 指紋 | 「再適用時の変更検知に使う」というコメントが実態と違った（書くだけで誰も読まない）。**記録のみで判定には使っていない**ことと、記録を残す理由をコメントへ明記 |
| `install-to-project.sh` の空配列展開 | bash 4.4未満の `set -u` で落ちる `"${a[@]}"` を `${a[@]+"${a[@]}"}` へ統一（4か所） |
| `.gitattributes` の説明 | 削除済みの関数 `ensure_gitattributes_rules` を指していた。関数名を書かない形へ（同じ形でまた古くなるため） |
| `setup-gemini-links.sh` の掃除 | 「削除で空になった分だけ」というコメントが実装より狭い保証をしていた。実際の挙動へ書き換え |
| `test_cleanup_task.sh` のコメント | `templates/` → `assets/`（issue #54 のルール上、存在しない語彙） |
| `dist-layers.json` の `.vscode/` の注記 | 「配る行には入れない」だと `local` = 配らない と読めた。マーカーの外にあるから配られない、と実態を書いた |

### bashの罠を1つ踏んだ（記録）

**`${!assoc[@]+"${!assoc[@]}"}` は連想配列のキーの空配列ガードとして使えない。** bashが
`!group[@]+…` を**間接展開**として解釈し、キーではなく値を変数名として扱おうとして
`invalid variable name` で落ちる（最小再現で確認）。インデックス配列の
`${a[@]+"${a[@]}"}` は問題なく、連想配列のキーだけが別物である。件数を先に見る形
（`if [ "${#group[@]}" -gt 0 ]`）へ直した。

### フェーズ4へ回した1件

`.claude/docs/spec/distribution-assets.md` 102行目が、削除済みの `ensure_gitattributes_rules` と
`assets/.gitattributes` を現在の仕様として書いている。specは正史なので設計反映（flow-id 4-6）で
新方式へ書き換える。**同じ記述を持つDDR `i0033-03` は本文なので書き換えない**（point-in-time の記録）。

### 検証

| 検証 | 結果 |
|---|---|
| 単体テスト（本家） | 17ファイル / **passed=1098 failures=0**（3周目で14件増） |
| 単体テスト（配布先で実行） | 17ファイル / 失敗0。修正前は `test_check_dist_coverage.sh` が `passed=11 failures=15` |
| 網羅性チェック | 追跡ファイル 204/204 件・`.gitignore` 13/13 行・空振り0件・不正0件 |
| 外部コマンド起動数 | 1208 → **176**（同一の計数スタブで前後を実測） |
| 新しい表明が本当に検出するか | `requiredLine` を定義から抜くと `test_install_to_project.sh` が `failures=3` になることを確認 |

## 残る未確認事項（フェーズ4でspecの未決定事項へ）

1. **sha256 のLF正規化**が Windows の `core.autocrlf=true` で意図どおり働くか（実機未確認）。
2. **NTFSジャンクションと実体ディレクトリの判別**（`fsutil reparsepoint query`。実機未確認）。
   判定を誤っても `.claude/` 側を壊さないよう、(a) 操作対象を `.gemini/<name>` の**中身**に限る、
   (b) 物理パスが同一なら触らない、の二重の安全網を入れてある。
3. **`AGENTS.md` の `@` import が `.claude/rules/agent-common.md` へ解決するか。** 次セッションの
   開始時にしか確認できない。**Gemini CLI 経路では `.claude/rules/` の自動読込が効かないため、
   担保が `@` import だけになる**（`GEMINI.md` → `AGENTS.md` → `agent-common.md` の入れ子）。
   効かない場合は `GEMINI.md` から直接 import する。
4. `.claude/docs/spec/extract-frontmatter.md` 180行目が `build/` を例に挙げている。`build/` の
   廃止に伴い例として古くなったので、フェーズ4のspec更新で扱う。
5. **`gitignorePattern` が「配る行／配らない行」を区別できない**（敵対的レビュー2回目・見送り）。
   `.vscode/` `*.log` はマーカーの**外**（配らない）、`/usage/` 等は**内**（配る）にあるのに、
   どちらも `layer: local` で表され、別は `note` の散文だけが持っている。検査2は
   「`.gitignore` の各行がどこかの `gitignorePattern` に一致するか」しか見ないため、
   **新しい行をマーカーの内側・外側どちらへ置いても通ってしまう**。定義のスキーマ変更と
   検査2の双方向化が要るため、フェーズ4で扱う。`.gitattributes` に行単位の検査が
   1つも無い点も同じ穴である。
