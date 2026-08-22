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
全17テストファイル・**1049件**の表明が通っている。

新方式では、旧実装の中間生成物（`assets/`）とビルド工程（`.skill`）が丸ごと不要になり、
**配る内容の定義が本家の実状態そのもの**（`.claude/dist-layers.json` と、マーカーで囲まれた
`.gitignore` / `.gitattributes` の実行）になった。写しを持たないので、実状態とずれようがない。

## 成果物

### 新規

| ファイル | 役割 |
|---|---|
| `.claude/dist-layers.json` | 層分け定義（41エントリ）。**何をどう配るかの単一の正** |
| `.claude/scripts/src/check-dist-coverage.sh` | 網羅性チェック（4種） |
| `.claude/rules/agent-common.md` | `AGENTS.md` から切り出した共通ルール9項目 |
| `.claude/skills/apply-mr-workflow-to-project/templates/AGENTS.md` | `seed` の汎用雛形 |
| `.claude/skills/apply-mr-workflow-to-project/templates/REVIEW-POINTS.local.md` | 配布先所有の観点表の空雛形 |
| `.claude/scripts/test/test_check_dist_coverage.sh` | 24件 |
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
