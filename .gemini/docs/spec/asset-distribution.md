---
title: AIアセットの配布機構（manifest方式）
type: spec
description: .claude/dist-layers.json の5層と .claude/.asset-manifest.json による、本家から他プロジェクトへのAIアセット配布機構の仕様
resource: .claude/skills/apply-mr-workflow-to-project/scripts/install-to-project.sh
tags: [spec, distribution, manifest, layers]
keywords: [dist-layers, asset-manifest, core, seed, merge, local, exclude, lines-marker, json-keys, requiredLine, 網羅性チェック, 2パス, pathspec, sha256, dirty]
---

# AIアセットの配布機構（manifest方式）

## 背景・目的

issue #26。このリポジトリのAIアセット（`.claude/` 一式・`.mrworkflow.json`・issueテンプレート等）を
他プロジェクトへ配布する仕組みを、**manifest方式へ作り直した**。

旧方式は「本家 → `assets/`（中間生成物）→ 配布先」の2段構えで、`sync-assets.sh` が配る内容を
`assets/` へ集め、`install-to-project.sh` がそれを配布先へコピーしていた。この形には次の欠陥があった。

- **配る内容の定義がスクリプトの中にあり、本家の実状態と写しがずれる。** 実際に、本家にある
  `REVIEW-POINTS.md` 4件のうち1件しか配られず、`worklog/TEMPLATE.md` は配られていなかった。
- **配布先が手を入れたファイルと、上流が更新したファイルを区別できない。** 「本家と1バイトでも
  違えば改変」という判定しか持てないため、上流が更新しただけの回にも警告と `.bak` が出ていた。
- **配布先のローカル生成物（`index.jsonl` 等）が混入していた。**

新方式は次の2つで解く。

| 仕組み | 解くもの |
|---|---|
| **層分け定義 `.claude/dist-layers.json`** | 何をどう配るかを**本家の実状態そのもの**に対して宣言する（写しを持たない） |
| **manifest `.claude/.asset-manifest.json`** | 「前回どの版の何を配ったか」を配布先へ残し、**上流の更新と配布先の改変を区別する** |

方式選定の経緯・却下案は
[DDR i0026-01](../ddr/i0026-01-AIアセットの配布はmanifest付きの直接コピーとし層はexcludeを含む5つにする.md)。

## 仕様

### 5つの層

| 層 | 意味 | 配布先に既存ファイルがあるとき |
|---|---|---|
| `core` | **本家が所有する。** 常に上書きする | 上書きする。**配布先が適用後に変更していれば `.bak` へ退避**し、一覧で知らせる |
| `seed` | **配布先が所有する。** 初回だけ雛形を置く | **触らない。** ただし `requiredLine` を持つ場合は移行漏れを一覧で知らせる（下記） |
| `merge` | **構造的にマージする** | 上書きしない。戦略ごとに必要な部分だけを足す |
| `local` | **何もしない。** 配布先のローカル作業状態 | 触らない。manifestにも書かない |
| `exclude` | **配らない。** 本家固有 | 触らない。manifestにも書かない |

**`exclude` は暗黙の既定値ではなく、明示指定を必須とする。** 「どのエントリにも一致しない＝配らない」
という設計にすると、網羅性チェック（下記）が**常に通ってしまい**、配り忘れを検出できない。
本家へファイルを足した人に「これは配るのか」を1回考えさせることが、この層の役目である
（DDR i0026-01 の b）。

### 層分け定義 `.claude/dist-layers.json`

```json
{
  "schemaVersion": 1,
  "upstream": true,
  "entries": [
    { "layer": "core", "path": ".claude" },
    { "layer": "merge", "path": ".gitattributes", "strategy": "lines-marker",
      "header": "# mr-driven-develop workflow attributes" },
    { "layer": "seed", "path": "AGENTS.md",
      "requiredLine": "@./.claude/rules/agent-common.md" },
    { "layer": "local", "gitignorePattern": "**/index.jsonl" }
  ]
}
```

| キー | 必須 | 意味 |
|---|---|---|
| `layer` | ○ | 上表の5つのいずれか |
| `path` | △ | **git pathspec**。ディレクトリを書けば配下すべてに一致する |
| `gitignorePattern` | △ | `.gitignore` の行そのもの。`local` エントリが使う（`path` の代わり） |
| `source` | | 配布元のパスが `path` と異なる場合に書く |
| `strategy` | `merge` のみ○ | `lines-marker` / `json-keys` |
| `keys` | `json-keys` のみ | マージ対象のキー（`hooks.PreToolUse` のようなドット区切り） |
| `header` | `lines-marker` のみ | 追記した行の直前へ置くコメント |
| `requiredLine` | | `seed` の移行検知に使う（下記） |
| `note` | | 人間向けの補足 |

**パスはgitに評価させる。** 自前でglobを実装せず、`git ls-files -- <pathspec>` へそのまま渡す。
`.gitignore` に近い記法を独自に解釈すると、本家が実際に追跡しているファイルの集合とずれる。

**例外は「後に書いたエントリが勝つ」で表す**（`.gitignore` と同じ規約）。
`{ "layer": "local", "path": "wip/plans" }` の後ろへ
`{ "layer": "core", "path": "wip/plans/REVIEW-POINTS.md" }` を置けば、`wip/plans/` は配らないが
その中の `REVIEW-POINTS.md` だけは配る、と読める。

`"upstream": true` は**本家にだけ立つ印**である。ただし網羅性チェックは「自分が本家かどうか」を
この印ではなく**定義ファイルの位置**で判断する（下記「網羅性チェック」）。

### manifest `.claude/.asset-manifest.json`

配布先にだけ生成される。**本家には存在しない。**

```json
{
  "schemaVersion": 1,
  "source": { "url": "https://github.com/…", "commit": "0aa9874…", "version": "0.2.0" },
  "appliedAt": "2026-08-23T05:00:00Z",
  "files": [
    { "path": ".claude/rules/agent-common.md", "layer": "core", "sha256": "…" },
    { "path": "AGENTS.md", "layer": "seed", "sha256": "…", "placed": true },
    { "path": ".gitattributes", "layer": "merge", "strategy": "lines-marker", "lines": ["…"] }
  ]
}
```

- **`sha256` はLF正規化した内容に対して取る。** Windows（`core.autocrlf=true`）では配布先の
  作業ツリーがCRLFになるため、生の内容で取ると**配布先が何も触っていなくても毎回「改変済み」**に
  なる。`tr -d '\r'` を通してから `sha256sum` する。
- **記録するのは `core` / `seed` / `merge` だけ。** `local` / `exclude` は書かない
  （書くと「配布した」と誤読される）。
- **`source.commit` に `-dirty` が付くことがある。** 本家のワークツリーに未コミットの変更が
  あり、`--allow-dirty` を付けて実行した場合。判定対象は**配布対象のパスに限る**（本家の
  `wip/plans/` を編集中でも dirty にはならない）。未追跡ファイルは件数の通知のみで dirty と見なさない。
- **再適用時の判定**: 配布先の現在の sha256 と manifest の値を比べる。一致すれば「配布先は
  触っていない」ので黙って上書きし、違えば「配布先が適用後に変更した」として `.bak` を残す。
  manifest 自体が無い（旧方式で適用済みの）配布先では、**改変済みではなく「差分を確認できない
  （移行）」**として一覧へ出し、`.bak` は作る。

### インストーラの2パス構成

```
走査パス → 提示 →（確認）→ 配置パス → manifest 書き出し
```

**受け入れ条件「上書きの前に警告と対象一覧を出す」は、1パスでは満たせない。** 配置しながら
警告を出す形だと、利用者が一覧を読み終える前に上書きが済んでいる。走査パスは配布先を一切
変更せず、`core` を「新規 / 同一 / 改変済み / 移行（判定不能）」へ、`seed` を「配置 / 維持 /
移行漏れ」へ振り分けるだけを行う。

- `--dry-run` は**提示までで止まる**（走査パスの結果を出して終わる）。
- `--force` は改変済み `core` を `.bak` を残さずに上書きする。
- **本家で削除・改名されたファイルは、配布先から削除しない。** 一覧で提示するにとどめる
  （配布先のファイルを消す操作は人間の判断に委ねる）。提示すらしないと、`.claude/rules/*.md` は
  セッション開始時に自動で読み込まれるため、配布先のAIが削除済みのルールを読み続ける。

### `merge` の2戦略

#### `lines-marker`（`.gitignore` / `.gitattributes`）

**配る行の定義を、そのファイル自身がマーカーで持つ。**

```gitattributes
# --- dist:begin ---
*.sh text eol=lf
# --- dist:end ---
```

マーカー間の行（コメント・空行を除く）だけを読み、配布先に無ければ末尾へ足す。

- **冪等**（何度適用しても行が増えない）。
- **行全体の一致で判定する**（`grep -Fxq`）。部分一致だと、配布先がコメントで言及している
  だけでも「もう有る」と誤判定する。
- **判定の前にCRを落とす**（落とさないとWindowsで毎回追記され続ける）。
- **配る行が1件も読めなかった場合は、無言でスキップせず件数付きの警告を出す。**

`.gitattributes` の資産としての仕様（どの行を配りどの行を配らないか）は
[distribution-assets.md](distribution-assets.md) が持つ。ここが持つのは戦略の仕様である。

#### `json-keys`（`.claude/settings.json`）

`keys` に挙げたキーだけを本家の値で上書きし、配布先が足した他のキーは残す。

- **jq の失敗を必ず検査する。** 検査しないと、配布先の `settings.json` を**0バイトにしうる**
  （フェーズ3の敵対的レビューで検出した blocker。`set -e` は条件式の中で一時停止するため、
  `jq ... > "$dst"` の失敗が伝わらないまま空のリダイレクトだけが残る）。
- **`merge` は `.bak` を作らない**（上書きではなくマージなので、退避の対象外）。したがって
  0バイト化は**回復不能**であり、しかも次回以降も同じ経路を通る。

### `requiredLine`（旧形式のまま残った `seed` の検知）

`seed` は「あれば触らない」層だが、**触らないまま放置すると恒久的に食い違うケース**がある。

issue #26 以前は本家の `AGENTS.md` 全文（共通ルールを含む）を配っていた。共通ルールは
`.claude/rules/agent-common.md` へ切り出され、`AGENTS.md` はそれを `@import` するだけになったが、
配布先の `AGENTS.md` は `seed` なので更新されない。結果として**共通ルールが二重化し、以後
`agent-common.md` だけが更新されて食い違い続ける**。

`requiredLine` に `@./.claude/rules/agent-common.md` を指定しておくと、`seed` が既に存在し、
かつその行を含まないときに**一覧で知らせる**。**書き換えは行わない**（`seed` は配布先の
所有物であり、プロジェクト概要など配布先固有の記述が入っているため）。

### 網羅性チェック `check-dist-coverage.sh`

| 検査 | 内容 |
|---|---|
| 1 | **追跡ファイル全件**が、どれか1つ以上のエントリに一致するか |
| 2 | `.gitignore` のコメント・空行を除く全行が、`local` エントリの `gitignorePattern` に一致するか |
| 3 | `source` を持たないエントリが、1件以上の追跡ファイルに一致するか（**空振りエントリの検出**） |
| 4 | `layer` が5種のいずれかで、`merge` が有効な `strategy` を持つか |

- **分母は追跡ファイル全件である。** 「配る対象だけ」を分母にすると、定義から漏れたファイルが
  分母にも入らず、常に100%になる。
- **配布先ではスキップする。** 判定は `upstream` の印ではなく、**定義ファイルが本家の位置に
  あるかどうか**で行う。`.claude/scripts/test/` は `core` として丸ごと配られるため、
  「対象ファイルが存在するか」でスキップを判断すると**配布先で必ず落ちる**
  （フェーズ3の敵対的レビュー3回目で実際にこの形だった）。

### 性能

**外部プロセスの起動回数がファイル数に比例しない形にする。** `core` は現状163件あり、
1ファイルごとに `tr` / `sha256sum` / `jq` を起動すると、起動回数がそのまま所要時間になる
（`.claude/rules/shell-script-style.md`「外部プロセス起動のコスト」）。

| 処理 | 形 |
|---|---|
| sha256 の計算 | CRを含むファイルだけを `grep` 1回で洗い出し、残りは `xargs sha256sum` 1回でまとめる |
| manifest の組み立て | US（jqの表記で `\u001f`）区切りの中間表現を一時ファイルへ書き、最後に `jq` 1回でJSONへ変換する |
| 対象パスの列挙 | pathspec を `git ls-files` へ渡す。**`git status` へ全パスを渡さない**（28KBのコマンドラインはWindowsの上限に達する） |

実測で、配布1回あたりの外部コマンド起動は **1208回 → 176回**になった。

## 影響範囲

### issue #26（2026-08-23）

- 追加: `.claude/dist-layers.json`（42エントリ）、`.claude/scripts/src/check-dist-coverage.sh`、
  `.claude/scripts/test/test_check_dist_coverage.sh`。
- 全面書き換え: `.claude/skills/apply-mr-workflow-to-project/scripts/install-to-project.sh`
  （2パス構成・5層・manifest 書き出し）、同 `SKILL.md`。
- 削除: `.claude/skills/apply-mr-workflow-to-project/scripts/sync-assets.sh` と、中間生成物
  `assets/` を作るビルド工程（`.skill` パッケージ化を含む）。
- 分割: `AGENTS.md` の「ルール」節9項目を `.claude/rules/agent-common.md` へ移し、
  `AGENTS.md` / `CLAUDE.md` / `GEMINI.md` はポインタ化した（`AGENTS.md` を `seed` のまま
  保つため。DDR i0026-01 の c）。
- 更新: [distribution-assets.md](distribution-assets.md)（3資産の層と、解消した未決定事項4件）。

## 未決定事項・懸念点

**いずれもWindows実機（git bash）でしか確認できない。** issue #26 の作業はLinuxコンテナ上で
行われた。[distribution-assets.md](distribution-assets.md) が持つ改行挙動の未確認項目と同根で、
**そちらは「配る資産（`.gitattributes`）の側」、ここは「配布機構の側」**という切り分けで
別々に残している。

- **`.gemini/` のリンクと実体コピーを判別できるか。** NTFSジャンクションは `[ -L ]` で
  シンボリックリンクと区別できない。`setup-gemini-links.sh` は `cd && pwd -P` の一致で
  「同じ実体を指しているか」を見るが、この判定がジャンクションで意図どおり働くかは未確認。
- **sha256 のLF正規化がWindows実機で意図どおり効くか。** `tr -d '\r'` を通す設計は、
  配布先の作業ツリーがCRLFで取り出される前提に立っている。この前提自体がまだ実機で
  確かめられていない。
- **`AGENTS.md` からの `@` import が `.claude/rules/agent-common.md` へ解決するか。**
  Linux上では解決を確認したが、Windowsのパス区切り・大文字小文字の扱いで差が出ないかは未確認。
