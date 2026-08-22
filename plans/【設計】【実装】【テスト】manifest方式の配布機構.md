---
title: manifest方式の配布機構の設計・実装・テスト（issue #26）
type: plan
description: 層分け定義ファイル・manifest・インストーラ作り直し・関連スクリプト改修と、その単体/結合テストの個別作業計画
tags: [plan, distribution, manifest, implementation]
keywords: [dist-layers, asset-manifest, install-to-project, check-dist-coverage, setup-gemini-links, cleanup-task, collect-review-points, dirty, sha256, seed, merge]
---

# 【設計】【実装】【テスト】manifest方式の配布機構

- issue: #26 / PR: #154 / フェーズ: 3〈作業〉（flow-id 3-1）
- 全体作業計画: `plans/ai-asset-manifest-distribution.md`
- 調査結果（この計画の入力）: `reports/20260822_ai-asset-manifest-distribution_配布アセットの層分け調査.md`
- 対になる計画: `plans/【AIアセット作成】配布ドキュメントとAGENTS分割.md`

**この計画には実施結果を書かない**（結果は `reports/…md` へ。issue #87）。

## この計画の範囲

配布機構の**動くもの**（定義ファイル・スクリプト・テスト）を作る。ドキュメント・
`AGENTS.md` の分割・`SKILL.md`/`DEVELOPERS.md` の書き換えは対の計画が担当する。
`【設計】【実装】【テスト】` を1ファイルに併記するのは、**設計判断がそのままスクリプトの構造で
あり、テストが受け入れ条件の写像になる**ため、3つを1回の合意で取るのが妥当と判断したことによる
（ユーザー確認済み。`【AIアセット作成】` とは分ける）。

### この計画で決めないこと（スコープ外）

| 事項 | どこで決めるか |
|---|---|
| `AGENTS.md` の共通ルール切り出し、`CLAUDE.md`/`GEMINI.md` の見出し差し替え | 対の `【AIアセット作成】` |
| `apply-mr-workflow-to-project/SKILL.md`・`DEVELOPERS.md` の書き換え | 同上 |
| 方式選定のDDR（受け入れ条件11）、新方式のspec、`distribution-assets.md` の更新 | **フェーズ4**（flow-id 4-1 で洗い出す） |
| `.claude/VERSION` を上げるかどうか | フェーズ4 |
| 収穫（逆輸入）スキル | **本issueの範囲外**（後続issue） |

## 前提（確定済み。いつ決まったか）

| # | 前提 | 決まった場所 |
|---|---|---|
| 1 | 層は `core` / `seed` / `merge` / `local` ＋ **`exclude`**（明示。暗黙の既定値にしない） | flow-id 2-6 の調査3 ＋ **ユーザー承認**（flow-id 2-9 でMRへ記録済み） |
| 2 | `REVIEW-POINTS.md` は `core`、配布先所有は `REVIEW-POINTS.local.md`（`seed`） | flow-id 2-6 の調査2 |
| 3 | `.github/` `.gitlab/` テンプレート4件と `CLAUDE.md` `GEMINI.md` は `core` | ユーザー判断（flow-id 2-9 で記録済み） |
| 4 | `.gemini/{docs,…}` は `local`。ただし**「`local` は触らない」の唯一の例外**として、インストーラは最後に `setup-gemini-links.sh` を**呼ぶ**（インストーラ自身は `.gemini/` を直接書かない）。受け入れ条件8が「再適用で `.gemini/` が最新の `.claude/` に一致する」ことを求める以上、インストーラ経由でしか満たせないため | flow-id 2-6 の調査1 ＋ **敵対的レビュー1回目**（前提4と手順7の矛盾として検出） |
| 5 | dirty ＝「配布対象パスに限定した `git status --porcelain` が空でない」。`--allow-dirty` を持つ | flow-id 2-6 の調査4 |
| 6 | 定義の形式は案A（定義ファイル1枚）＋網羅性チェック | flow-id 2-6 の調査3 |
| 7 | 既存欠陥は5件中4件が作り直しで消え、**#3（配る行が実状態と不一致）だけ明示対処が要る** | flow-id 2-6 の調査5 |

---

# 【設計】

## 1. 層分け定義ファイル `.claude/dist-layers.json`

### 形式

```jsonc
{
  "schemaVersion": 1,
  "entries": [
    { "layer": "local", "path": "plans",  "note": "タスク単位の作業状態" },
    { "layer": "core",  "path": "plans/REVIEW-POINTS.md", "note": "観点表は本家所有" },
    { "layer": "seed",  "path": "plans/REVIEW-POINTS.local.md",
      "source": ".claude/skills/apply-mr-workflow-to-project/templates/REVIEW-POINTS.local.md" },
    { "layer": "merge", "path": ".gitattributes", "strategy": "lines-marker" },
    { "layer": "merge", "path": ".claude/settings.json", "strategy": "json-keys",
      "keys": ["hooks", "permissions.deny"] },
    { "layer": "local", "gitignorePattern": "/usage/" },
    { "layer": "exclude", "path": "README.md", "note": "本家固有の説明" }
  ]
}
```

- `path` は**本家のワークツリーで評価するgit pathspec**。列挙は `git ls-files -z -- "$path"` に
  任せる（globやディレクトリ指定の意味論をbashで再実装しない）。
- **後に書いたエントリが勝つ**（`.gitignore` / `.gitattributes` と同じ規約）。上の例のように
  「`plans` は `local`、ただし `plans/REVIEW-POINTS.md` は `core`」という例外を、順序だけで表せる。
- `source` は、**配布先へ置く内容が本家の実ファイルと違う `seed`** のためのフィールド
  （`REVIEW-POINTS.local.md` の空雛形、`AGENTS.md` の汎用雛形）。省略時は `path` 自身が配布元。
- `gitignorePattern` は `local` 専用。**追跡されていないパス**（実行時生成物）を表す。
  `path` と併記してよい（`plans` のように追跡ファイルと生成物の両方を含む場合）。
- JSONにしてコメントを持てない代わりに `note` を持たせる。読み出しは**jq 1回**で
  `layer<TAB>path…` のTSVへ落とし、以降はbashで扱う（`.claude/rules/shell-script-style.md`
  「外部プロセス起動のコスト」）。

### 却下した形式

調査3のとおり、案B（各ファイルがマーカーで持つ／JSON・空ファイルに書けない）と
案C（ディレクトリ単位の規約／例外を表現できない）は却下済み。ここでは再検討しない。

## 2. 網羅性チェック `.claude/scripts/src/check-dist-coverage.sh`

**「異常が無ければ何も出ない検証」にしない**（`.claude/rules/shell-script-style.md`）。件数を必ず出す。

| # | 検査 | 失敗の意味 |
|---|---|---|
| 1 | **追跡ファイル全件**が、どれか1つ以上のエントリに一致するか | 定義への載せ忘れ |
| 2 | `.gitignore` の**コメント・空行を除く全行**が、どれかの `local` エントリの `gitignorePattern` に一致するか | 新しい生成物を `local` へ載せ忘れた |
| 3 | `source` を持たないエントリが、**1件以上の追跡ファイルに一致**するか | パスの打ち間違い・定義の残骸 |
| 4 | `layer` の値が5種のいずれかか。`merge` は `strategy` を持つか | 誤記 |

- 検査1の分母は**追跡ファイル全件**である。調査結果の「168」は調査時に範囲外を手で除いた数だが、
  この設計では `plans` `worklog` `reports` を `local` エントリとして定義に載せるため、
  **除外を定義側へ寄せて分母を素直な全件にできる**（除外条件がスクリプトと定義の2箇所に
  散らばるのを避ける）。
- 終了コードは、1件でも未分類があれば1。未分類のパスを**すべて列挙**する（先頭N件で打ち切らない）。

## 3. manifest `.claude/.asset-manifest.json`（配布先に置く）

```jsonc
{
  "schemaVersion": 1,
  "source": { "url": "<本家のリモートURL>", "commit": "<SHA>", "version": "<.claude/VERSION>" },
  "appliedAt": "<ISO8601>",
  "files": [
    { "path": ".claude/rules/git-workflow.md", "layer": "core",  "sha256": "..." },
    { "path": "HANDOFF.md",       "layer": "seed",  "sha256": "...", "placed": true },
    { "path": ".mrworkflow.json", "layer": "seed",  "placed": false },
    { "path": ".gitattributes",   "layer": "merge", "strategy": "lines-marker", "lines": ["<行のsha256>"] },
    { "path": ".claude/settings.json", "layer": "merge", "strategy": "json-keys",
      "keys": { "hooks": "<sha256>", "permissions.deny": "<sha256>" } }
  ]
}
```

- `local` / `exclude` は**書かない**（書くと「配布した」と誤読される）。
- `sha256` は**LF正規化してから**取る（Windowsの `core.autocrlf=true` で全ファイルが
  「配布先が変更した」と誤検知されるのを防ぐ）。**Windows実機では未確認**であり、フェーズ4で
  新方式のspecの「未決定事項」へ残す。
- `seed` の `placed: false` は「既に在ったので触らなかった」を表す。以後 sha256 を比較しない
  （配布先所有だから）。
- `--allow-dirty` を付けた適用では `source.commit` を `<sha>-dirty` にする。

**受け入れ条件5の達成**: 再適用時（および `--dry-run`）に、manifestの `sha256` と配布先の実ファイルの
sha256 を突き合わせ、食い違うものを「適用後に変更された」として列挙する。

**manifest を持たない配布先（旧 `install-to-project.sh` で適用済み）の初回再適用**（敵対的レビュー
1回目）: 比較対象が無いため、素直に実装すると全 `core` が「改変済み」に倒れて `.bak` が大量発生するか、
「新規」に倒れて改変を無警告で踏み潰すかのどちらかになる。**前者へ倒す**が、警告文を分ける
——「改変済み」ではなく「**manifest 不在のため差分を確認できない（移行）**」として一覧提示し、
`.bak` は作る。受け入れ条件4（上書きの前に警告と一覧）は満たしたうえで、初回だけ理由が違うことを
読み手へ示す。

## 4. インストーラの処理順序（`install-to-project.sh`）

**2パス構成にする。** 受け入れ条件4が「上書きの**前に**警告と一覧を出す」ことを求めており、
1パスで配置しながら警告を出す現行の形では満たせない。

```
1. 引数解析（--force / --allow-dirty / --dry-run / dest）
2. 前提検証
   2a. dest が git リポジトリか（現行どおり）
   2b. 本家ワークツリーの dirty 判定 → dirty なら中断（--allow-dirty で継続）   … 受け入れ条件6
   2c. check-dist-coverage.sh を実行 → 未分類があれば中断                        … 受け入れ条件1
3. 定義の読み込み（jq 1回でTSV化）→ 層ごとの配布元ファイル一覧を確定
4. 走査パス（ファイルを一切変更しない）
   - 既存 manifest があれば読む
   - core: 配布先の実 sha256 と manifest の sha256 を比較 → 改変済みリストへ
   - seed: 配布先に存在するか → 存在すれば「触らない」リストへ                   … 受け入れ条件3
   - merge: 追記/マージが必要な差分の有無
5. 一覧の提示（改変済み core の一覧・触らない seed の一覧・merge の予定）        … 受け入れ条件4
   --dry-run はここで終了（受け入れ条件5の判定結果がそのまま出力になる）
6. 配置パス
   - core: 上書き（改変済みなら .bak を残す。--force なら .bak も作らない）
   - seed: 存在しなければ置く。存在すれば触らない
   - merge: strategy ごとの処理（下記）
   - local / exclude: **何もしない**（唯一の例外は手順7。前提4）                  … 受け入れ条件2
7. dest で setup-gemini-links.sh を実行                                          … 受け入れ条件7・8
8. manifest の書き出し
9. サマリ（警告の有無を含む）
```

- **`HAS_WARNED` が伝わらない欠陥（既存#4）は、この構造で消える。** 警告はサブシェルの中の変数では
  なく、走査パスで作った配列（手順4）を手順5・9で読むだけになるため。
- 手順7は配布先の `.claude/scripts/src/setup-gemini-links.sh` を呼ぶ（同スクリプトは自身の位置から
  3つ上をリポジトリルートとするので、配布先で実行すれば配布先の `.gemini/` を対象にする）。

### `merge` の2方式

| strategy | 対象 | 処理 |
|---|---|---|
| `lines-marker` | `.gitattributes` `.gitignore` | 本家の当該ファイルの `# --- dist:begin ---` 〜 `# --- dist:end ---` の間の**コメント・空行を除く行**だけを、配布先の同名ファイルへ**行全体一致で無ければ追記**する |
| `json-keys` | `.claude/settings.json` | `keys` に挙げたキーパスだけを本家の値で更新する。それ以外のキーは配布先の値を保つ |

- `lines-marker` は現行 `ensure_gitattributes_rules` の一般化。満たすべき4性質（冪等／行全体一致
  （`grep -Fxq --`）／CR除去／末尾改行の補完）は現行実装が既に持っているので**引き継ぐ**。
- **読み出し元を `${ASSETS_DIR}/.gitattributes` から本家ワークツリーの `.gitattributes` へ移す**
  （`assets/` が無くなるため。PR #136 が「移設漏れで静かに空振りする」と指摘した箇所）。
- **マーカーが1行も見つからない場合を「警告」から「失敗（中断）」へ変える。** これは**仕様変更**で
  あり、`.claude/docs/spec/distribution-assets.md` 111〜112行目の明文と食い違う。**specの更新は
  フェーズ4**で行う（この計画では実装だけを変える）。
- `json-keys` の粒度が「トップレベルのキー」では足りない理由は調査3のとおり
  （`permissions` の中で `deny` だけが本家所有）。`permissions.deny` は**和集合**にする
  （配布先が足した deny 行を消さない）。`hooks` は本家で**全置換**する（配布したhookの登録そのもの）。

### dirty の判定（受け入れ条件6）

```
git -C <本家> status --porcelain -z -- <core / seed（source側パスを含む）/ merge エントリのpath...>
```

- 既定の `--untracked-files=normal` で未追跡ファイルは含まれ、無視ファイルは含まれない。
  これが調査4で決めた定義とそのまま一致する。
- `plans/` `worklog/` `reports/` は `local` エントリなので pathspec に入らず、タスク作業中でも
  dirty にならない。
- **`exclude` 層も pathspec に入れない**（敵対的レビュー1回目）。`exclude` は配布先へ1バイトも
  配られないので、編集中でも manifest の再現性（`source.commit` と配布内容の対応）は損なわれない。
  入れてしまうと `README.md` を書きかけただけで `--allow-dirty` が要る運用になる。受け入れ条件6の
  趣旨は「**配る内容が**コミットと一致しない状態で配らない」ことである。

---

# 【実装】

## 変更するファイル

| # | ファイル | 種別 | 内容 |
|---|---|---|---|
| 1 | `.claude/dist-layers.json` | 新規 | 上記の層分け定義。**調査1の割り当て表を写す** |
| 2 | `.claude/scripts/src/check-dist-coverage.sh` | 新規 | 網羅性チェック（検査4種） |
| 3 | `.claude/skills/apply-mr-workflow-to-project/templates/REVIEW-POINTS.local.md` | 新規 | `.local` の空雛形（見出しと「ここへ配布先固有の観点を書く」の1文だけ） |
| 4 | `.claude/skills/apply-mr-workflow-to-project/templates/AGENTS.md` | 新規 | `seed` の汎用雛形（本文は対の計画が用意する。**このファイルの新設と定義への登録だけがこちらの担当**） |
| 5 | `.claude/skills/apply-mr-workflow-to-project/scripts/install-to-project.sh` | 全面書き直し | 上記の処理順序 |
| 6 | `.claude/skills/apply-mr-workflow-to-project/scripts/sync-assets.sh` | **削除** | 受け入れ条件10 |
| 7 | `.claude/scripts/src/setup-gemini-links.sh` | 改修 | 下記2点 |
| 8 | `.claude/scripts/src/cleanup-task.sh` | 1行追加 | 下記 |
| 9 | `.claude/scripts/src/collect-review-points.sh` | 改修 | 下記 |
| 10 | `.gitignore` | 改修 | マーカーの導入と `assets/` 行の削除 |
| 11 | `.gitattributes` | 変更なし | マーカーは既にある |

### 新規追加するファイル自身の層（敵対的レビュー1回目）

検査1は**追跡ファイル全件**がどれかのエントリに一致することを要求するので、この計画が新規追加する
4ファイルにも必ず層が要る。**定義への登録を忘れると、追加した瞬間に検査1が落ちる。**

| 追加するファイル | 層 | 配布先での振る舞い |
|---|---|---|
| `.claude/dist-layers.json` | `core` | 配られる。**配布先で `check-dist-coverage.sh` を流すと、配布先の自前ソースが全件「未分類」になる** → 下記の但し書きで対処 |
| `.claude/scripts/src/check-dist-coverage.sh` | `core` | 同上 |
| `.claude/scripts/test/test_check_dist_coverage.sh` | `core` | 対象が本家前提のためスキップしうる |
| `.claude/scripts/test/test_setup_gemini_links.sh` | `core` | 配布先でもそのまま意味がある |

- **`check-dist-coverage.sh` は「本家（`dist-layers.json` を所有するリポジトリ）でのみ意味を持つ検査」
  である。** 配布先で流したときに「未分類が大量にある」と報告するのは誤りなので、
  **`.claude/dist-layers.json` に本家を示す印**（例: `"upstream": true`）を持たせ、印が無ければ
  「このリポジトリは配布先なので検査をスキップした」と**件数付きで**出して終了コード0で終わる。
  無言のスキップにはしない。
- 新テスト2本にも、既存 `test_install_to_project.sh` の27〜32行目と同じ
  **「対象が無い配布先ではスキップし、件数を出す」ガード**を持たせる。

### Goプロジェクト自動検知の扱い（敵対的レビュー1回目）

現行 `install-to-project.sh` は3箇所でGo検知を持つが、上記の処理順序には現れていなかった。
**引き継がず、廃止する。**

| 現行の行 | 処理 | 廃止の理由 |
|---|---|---|
| 151〜152 | `go.mod` を検知 | 下記2つが無くなるので不要 |
| 193〜195 | `AGENTS.md` へ `go-applications.md` への参照行を追記 | `AGENTS.md` は `seed`。**受け入れ条件3（配布先が編集した seed を触らない）と衝突する** |
| 199〜200 | 非Goプロジェクトで `go-applications.md` を削除 | `.claude/rules/go-applications.md` は**本リポジトリに存在しない**（`ls .claude/rules/` で0件）。現状すでに空振りしている |
| 319 | Next Steps でGo向けの分岐を出す | 上記が無くなるため |

- **対の計画（`【AIアセット作成】…`）の作業3の表が「Goプロジェクト自動検知 ｜ 現状の記述を維持する」と
  書いているので、そちらも同時に直す**（SKILL.mdに機能として残ったまま実装から消えると食い違う）。
  この相互依存は下記「自己点検」にも記す。
- 配布先がGo規約を要るなら、`.claude/rules/` へ自分で置き、`AGENTS.md`（`seed`）へ自分で参照を
  書けばよい。**配布先所有のファイルを本家が書き換える形をやめる**、というのがこの廃止の趣旨である。

## 個別の指示（置き換え前後）

### 8. `cleanup-task.sh`（この案の**成立条件**）

`REVIEW-POINTS.local.md` を足しても、これを直さないと **flow-id 5-4 で毎タスク削除される**。

```bash
# 置き換え前（58〜60行目）
readonly -a KEEP_BASENAMES=(
  "REVIEW-POINTS.md"
)
# 置き換え後
readonly -a KEEP_BASENAMES=(
  "REVIEW-POINTS.md"
  "REVIEW-POINTS.local.md"
)
```

**`is_keep_path` のロジックは変えない。** ベース名の完全一致という性質は
`test_cleanup_task.sh:72-73` が明示的に表明しており（`REVIEW-POINTS.md.bak` と
`OLD-REVIEW-POINTS.md` は残さない）、そこは維持したまま候補を1つ増やすだけで足りる。

### 9. `collect-review-points.sh`

**104〜106行目だけの置き換えでは実現できない**（敵対的レビュー1回目）。104〜106行目は `rel` への
代入にすぎず、`.local` を出力するには**出力を担う108〜112行目まで含めて**書き換える必要がある。

```bash
# 置き換え前（102〜113行目）
  while IFS= read -r dir; do
    if [ "$dir" = "." ]; then
      rel="REVIEW-POINTS.md"
    else
      rel="$dir/REVIEW-POINTS.md"
    fi
    [ -f "$rel" ] || continue
    found=1
    printf '## %s\n\n' "$rel"
    strip_frontmatter_and_h1 "$rel"
    printf '\n'
  done < <( ... )
# 置き換え後（本家 → 配布先の順で、同じディレクトリの2ファイルを続けて出す）
  while IFS= read -r dir; do
    if [ "$dir" = "." ]; then
      prefix=""
    else
      prefix="$dir/"
    fi
    for base in "REVIEW-POINTS.md" "REVIEW-POINTS.local.md"; do
      rel="${prefix}${base}"
      [ -f "$rel" ] || continue
      found=1
      printf '## %s\n\n' "$rel"
      strip_frontmatter_and_h1 "$rel"
      printf '\n'
    done
  done < <( ... )
```

- **`continue` の単位がディレクトリからファイルへ変わる**のがこの書き換えの要点である。現行は
  `REVIEW-POINTS.md` が無いと**ディレクトリごとスキップ**するため、**本家の観点表が無く `.local`
  だけあるディレクトリ**（配布先が `src/` `internal/` 等へ自分の観点を置く、`.local` の**最も典型的な
  使い方**）が丸ごと無視される（敵対的レビュー1回目）。
- 同じディレクトリでは `REVIEW-POINTS.md` → `REVIEW-POINTS.local.md` の順に読む
  （祖先方向の「浅い→深い」の順序は変えない）。
- **`.local` が無いディレクトリで空振りしても失敗にしない**（存在するのが普通の状態）。
- **`rel` は出力にファイルパスとして現れる**ので、`.local` 側も同じ形式で出す
  （読み手がどちらの観点かを区別できるようにする）。

### 10. `.gitignore`

配る行を `.gitignore` 自身に持たせる（**既存欠陥#3 の明示対処**。配る行の定義が本家の実状態と
自動的に一致するようになる）。

- 削除: 8〜9行目（`sync-assets.sh` が生成する `assets/` の除外。生成元が無くなる）。
- 追加: `# --- dist:begin ---` 〜 `# --- dist:end ---`。**中に入れる**のは
  `/usage/` `/.claude/state/` `**/index.jsonl` `*.stackdump` `.claude/docs/.ddr-list.*`
  `/.gemini/docs` `/.gemini/hooks` `/.gemini/rules` `/.gemini/scripts` `/.gemini/skills`。
- **入れない**のは `.vscode/`・`*.log`（配布先の好み）。
- **`/build/` は行ごと削除する**（`build/` を廃止するという対の計画の作業5の判断に対応する、
  実際の編集。**どちらの計画にも削除の指示が無い状態だった**ため、こちらへ寄せた。
  敵対的レビュー1回目で検出）。

  ```
  # 置き換え前（5〜6行目）
  # ビルド成果物
  /build/

  # 置き換え後（2行とも削除。直後の空行も1つに詰める）
  ```

  `build/` への参照のうち `.claude/docs/ddr/i0032-01-….md` 75〜76行目と
  `.claude/docs/spec/issue-mr-workflow.md` 2559〜2560行目は**point-in-timeの記録**なので触らない。
- 既存のコメント（各行の由来を説明している段落）は**マーカーの中に残してよい**。
  `lines-marker` はコメント行と空行を落として配るため、配布先へは行だけが届く。
- **既存の行の並び順を大きく動かさない。** マーカーで囲むために必要な最小限の移動に留める
  （並べ替えるとレビューで「何が変わったか」が読めなくなる）。

### 7. `setup-gemini-links.sh`

| 変更 | 内容 | 受け入れ条件 |
|---|---|---|
| a | symlink もジャンクションも作れないとき、**実体コピーへフォールバックして終了コード0**で終わる | 7 |
| b | 対象が**実体ディレクトリ**のときは、中身を最新へ入れ替える（現行は「既に存在すればスキップ」） | 8 |

- 変更bには**リンクと実体の判別**が要る。`[ -L ]` ではNTFSジャンクションを実体と区別できない。
  **Windows実機でしか確認できないため、ジャンクションかどうかの判定は次の順で安全側へ倒す**。
  1. `[ -L "$target" ]` が真 → symlink。何もしない。
  2. `cygpath` が使える環境（＝Windows）で、`fsutil reparsepoint query` が成功 → ジャンクション。
     何もしない。
  3. それ以外の実体ディレクトリ → 実体コピーとみなして中身を入れ替える。
- **判定を誤って `.claude/` 側を壊さないため、入れ替えは「`.gemini/<name>` を削除して
  `.claude/<name>` からコピーし直す」ではなく、`.gemini/<name>` の中だけを対象にする**
  （リンクを辿って本家側を消す事故を構造的に避ける）。
- 変更aで実体コピーになった場合は、**その旨を出力に明示する**（利用者が「リンクになっている」と
  誤解したまま `.gemini/` を編集するのを防ぐ）。

---

# 【テスト】

## 現行テストの表明の棚卸し（引き継ぐもの）

`test_install_to_project.sh` は受け入れ条件には現れない保証を持っている。**作り直しで落とさない。**

| # | 現行の表明 | 新テストでの扱い |
|---|---|---|
| 1 | PR/MRテンプレート・`.claude/VERSION` が配布先へ配置される | 引き継ぐ（`core`） |
| 2 | PR/MRテンプレートの見出しが `describe` の生成物と一致する（**SKILL.md から抽出した3行との3者突き合わせ**） | 引き継ぐ。**抽出が空振りしていないことの表明（3行取れている）も含めて引き継ぐ** |
| 3 | `.gitattributes` は丸ごと置換しない（配布先の3行が残る／`.bak` を作らない） | 引き継ぐ |
| 4 | 末尾に改行が無くても連結しない | 引き継ぐ |
| 5 | 3回適用しても行が増えない（**配布先がCRLFの場合を含む**） | 引き継ぐ。`.gitignore` にも同じケースを足す |
| 6 | コメント中の言及を実設定と誤認しない | 引き継ぐ。`.gitignore` にも足す（**既存欠陥#2 の回帰テスト**） |
| 7 | `.claude/VERSION` の更新が `.bak` と警告を生まない | 引き継ぐ |
| 8 | 対象スクリプトが無い配布先ではスキップし、**件数を出す** | 引き継ぐ |
| 9 | `sync-assets.sh` を起動する（63行目） | **落とす**（スクリプトごと削除するため） |

**旧テストを新実装に対しても1度流し、9番以外が通ることを確かめてから書き直す**
（受け入れ条件に対応するケースだけで書き直すと、上の保証が無言で失われる）。

### テストが表明していない現行挙動（敵対的レビュー1回目）

全面書き直しで失われるのは**テストのある挙動だけではない**。上の表はアサーションだけを対象に
していたので、テストの無い生成物についても引き継ぎ判断を書く。

| 現行の行 | 挙動 | 扱い |
|---|---|---|
| 160〜163 | `.claude` `.gemini` `plans` `worklog` を `mkdir -p` | `plans` `worklog` は新設計では `local`（「何もしない」）。**捨てる** |
| 187〜188 | `plans/.gitkeep` `worklog/.gitkeep` を作成 | **捨てる。** 空ディレクトリの維持は配布先の関心事で、`local` を触らない方針と両立しない |

- ルート `REVIEW-POINTS.md` の観点「既存の挙動を変えないはずの書き直しで、変えていないことを
  機械的に確かめているか」に対応するため、**旧実装と新実装の生成物を突き合わせる**手順を検証節
  （検証5b）へ入れる。上表の2つは意図的な差分なので、**期待する差分として**先に書いておく。

## 新規・追加するテスト

| ファイル | ケース | 受け入れ条件 |
|---|---|---|
| `test_check_dist_coverage.sh`（新規） | 未分類が0件であること／**定義から1件わざと落とした一時ツリーで実際に検出できること**／`.gitignore` に未分類パターンを足すと落ちること | 1 |
| `test_install_to_project.sh`（作り直し） | 新規配布先で `core`/`seed`/`merge` が配置され manifest が生成される／`local` のファイルが**1件も作られない**（`index.jsonl` 0件・`.claude/state/` 無し・`usage/` 無し）。**`.gemini/{docs,…}` はこの列挙に含めない**（前提4の例外。作られることは受け入れ条件7・8のケースで確かめる） | 2 |
| 〃 | `HANDOFF.md` を編集して再適用しても**上書きされない**（`seed`） | 3 |
| 〃 | `plans/.gitkeep` `worklog/.gitkeep` が**作られない**（旧挙動を意図的に落としたことの表明） | 2 |
| 〃 | `core` を編集して再適用すると、**上書きの前に**警告と対象ファイル一覧が出る／`.bak` が残る | 4 |
| 〃 | 適用後にファイルを書き換えると `--dry-run` が「変更された」と列挙する／書き換えなければ0件 | 5 |
| 〃 | 本家が dirty なら中断する（終了コード非0）／`--allow-dirty` で継続し `source.commit` に `-dirty` が付く | 6 |
| 〃 | `.claude/settings.json` の `json-keys` マージ（配布先の `plansDirectory` が残る／`hooks` が本家の値になる／`deny` が和集合になる） | 2 |
| `test_setup_gemini_links.sh`（新規） | **`ln` のスタブをPATH先頭へ置く**と実体コピーへフォールバックし**終了コード0**で終わる | 7 |
| 〃 | 実体コピー状態で再実行すると、`.claude/` 側の変更が `.gemini/` へ反映される | 8 |
| `test_cleanup_task.sh`（追加） | `REVIEW-POINTS.local.md` が削除されない／`REVIEW-POINTS.local.md.bak` は削除される（**完全一致の維持**） | — |
| `test_collect_review_points.sh`（追加） | `.local` が本家の観点の**後**に出る／`.local` が無くても失敗しない | — |

- `install-to-project.sh` のテストは**本家のワークツリーが dirty な状態で流れる**必要がある
  （フェーズ3の実装中は常に dirty）。すべての適用呼び出しに `--allow-dirty` を付ける。
  dirty ガード自体を確かめるケースだけ、付けずに終了コードを見る。
- 終了コードの検査は `"$(func; echo $?)"` の形にしない（`set -e` 配下でサブシェルが `echo` に
  到達しないことがある。`.claude/rules/shell-script-style.md`「テスト」）。`if` で受ける。

## 検証（この計画の完了判定に実際に流すコマンド）

```bash
# 1. 構文チェック（新規・変更したすべての .sh）
for f in .claude/scripts/src/check-dist-coverage.sh \
         .claude/scripts/src/setup-gemini-links.sh \
         .claude/scripts/src/cleanup-task.sh \
         .claude/scripts/src/collect-review-points.sh \
         .claude/skills/apply-mr-workflow-to-project/scripts/install-to-project.sh; do
  bash -n "$f" && echo "syntax OK: $f"
done

# 2. 定義ファイルが有効なJSONで、網羅性チェックが通る
jq -e . .claude/dist-layers.json > /dev/null && echo 'dist-layers.json OK'
bash .claude/scripts/src/check-dist-coverage.sh

# 3. 網羅性チェックが「実際に検出できる」ことの確認（異常が無ければ何も出ない検証にしない）
#    実物の .claude/dist-layers.json は書き換えない（中断すると壊れた定義が作業ツリーに残り、
#    手順2bの dirty 判定の材料にもなってしまうため）。落とす対象も、実在保証の無い既存エントリ名
#    ではなく、この検証が自分で足したファイル／エントリにする。
tmp_def="$(mktemp)"
#    プローブは**ルート直下**へ置く。`.claude/` 配下だと広域の core エントリに被覆され、
#    「未分類を検出できない」のに検証は通る（実際に踏んだ）。
: > __coverage_probe__.md
git add -N __coverage_probe__.md
if bash .claude/scripts/src/check-dist-coverage.sh > /dev/null 2>&1; then
  echo 'NG: 定義に無いファイルを未分類として検出できていない'
else
  echo 'OK: 未分類を検出した'
fi
jq '.entries += [{"layer":"exclude","path":"__coverage_probe__.md","note":"検証3の使い捨て"}]' \
  .claude/dist-layers.json > "$tmp_def"
if bash .claude/scripts/src/check-dist-coverage.sh --def "$tmp_def" > /dev/null 2>&1; then
  echo 'OK: 定義へ足せば被覆できた（検出が偶然でないことの確認）'
else
  echo 'NG: 定義に書いたのに未分類と言われた'
fi
git rm -q --cached __coverage_probe__.md
rm -f __coverage_probe__.md

# 4. 単体テスト・結合テスト（規約どおり passed=N failures=N を見る）
for t in test_check_dist_coverage test_install_to_project test_setup_gemini_links \
         test_cleanup_task test_collect_review_points; do
  echo "--- $t"; bash ".claude/scripts/test/$t.sh"
done

# 5. 旧テストの引き継ぎ確認（棚卸し表1〜8が新実装でも通ること）
#    旧テストは63行目で sync-assets.sh を set -e 配下で無条件に呼ぶため、削除後はその行で即死し
#    以降のアサーションが1件も走らない。63行目を除いた写しを作って流す。
#    || true は付けない（付けると何も検査されていないのに通ったように見える）。
base="$(git merge-base HEAD origin/main)"
old_test="$(mktemp)"
#    `grep -v 'sync-assets'` では11・23行目の**コメント2行まで**落ちる（実際に確認: 3行一致）。
#    実行行だけを固定文字列で落とす。
git show "$base:.claude/scripts/test/test_install_to_project.sh" \
  | grep -vF 'bash "${SKILL_SCRIPTS}/sync-assets.sh"' > "$old_test"
bash "$old_test"   # 規約どおり passed=N failures=N を見る。failures=0 であること

# 5b. テストが表明していない生成物の引き継ぎ確認（棚卸しの後半表に対応）
#    新実装を空の一時配布先へ適用し、意図的に落とした生成物が「無い」ことを確かめる。
d="$(mktemp -d)"; (cd "$d" && git init -q .)
bash .claude/skills/apply-mr-workflow-to-project/scripts/install-to-project.sh --allow-dirty "$d"
for f in plans/.gitkeep worklog/.gitkeep; do
  [ -e "$d/$f" ] && echo "NG: $f が作られている（落とすと決めた生成物）" || echo "OK: $f は作られない"
done

# 6. sync-assets.sh への参照が残っていないか（DDR本文・changelogはmdなので対象外）
#    grep -rn は usage/state/*.json（対応工数レポートのローカル状態。サブエージェントへの
#    プロンプト全文が入っている）を必ず拾うため、永久に「参照なし」を出さない。追跡ファイルに限定する。
git grep -n 'sync-assets' -- '*.sh' '*.json' || echo '参照なし'
#    期待: 0件（test_install_to_project.sh の63行目を消したあと）
```

## この計画の中で互いの前提を崩していないか（自己点検）

- **項目9（`collect-review-points.sh`）と項目8（`cleanup-task.sh`）はセットである。** 片方だけ
  入れると、観点表を読む仕組みだけができて、その観点表が毎タスク消える状態になる。
- **項目10（`.gitignore` のマーカー化）と項目5（インストーラ）はセットである。** 現行インストーラの
  `ignore_rules` 配列を消してマーカー読み出しへ移すため、片方だけ入れると `.gitignore` の
  更新が空振りする（**マーカー0件は失敗にする**という決めがこれを検出する）。
- **Goプロジェクト自動検知の廃止は、対の計画の作業3とセットである。** こちらが実装から落とし、
  対の計画がSKILL.mdの記述を落とす。片方だけだと「SKILL.mdにある機能が動かない」か
  「動く機能が文書化されていない」のどちらかになる（敵対的レビュー1回目で検出）。
- **`.gitignore` の `/build/` 行の削除は、この計画（項目10）が実施する。** 対の計画の作業5は
  「削除する」という判断だけを持ち、実際の編集はこちらに寄せてある。**どちらの計画にも削除の
  指示が無い状態だった**ため、項目10へ明記した（敵対的レビュー1回目で検出）。
- **項目4（`templates/AGENTS.md`）の中身は対の計画が用意する。** こちらは定義への登録までを行う。
  対の計画が先にマージされる想定ではないので、**空の雛形を置いて定義を通し、中身は対の計画で
  埋める**（網羅性チェックは `source` を持つエントリに追跡ファイルの一致を要求しないため、
  中身が空でも検査は通る）。
