---
title: 統括レポート（issue #26 AIアセット配布のmanifest方式化）
type: report
description: 配布方式をmanifest付きの直接コピーへ作り直し、何をどう配るかの単一の正として5層の層分け定義を新設したブランチ全体の統括
tags: [report, 統括, distribution, manifest]
keywords: [dist-layers, asset-manifest, 5層, exclude, requiredLine, install-to-project, check-dist-coverage, 敵対的レビュー, sync-gemini-assets, 失敗握りつぶし]
---

# 統括: AIアセット配布のmanifest方式化（issue #26 / PR #154）

flow-id 5-4。このブランチで何を変え、なぜそうしたか、何を検証し、どこへ反映したかを1枚にまとめる。
`plans/` `worklog/` `reports/` は flow-id 5-5 で削除されるため、**この内容はPR #154 のコメントとしても残す**。

## 1行で言うと

**「何をどう配るか」を `.claude/dist-layers.json` という1つのファイルへ集約し、配布結果を
manifest（sha256）で記録することで、上流の更新と配布先の改変を区別できるようにした。**

## 何を変えたか

### 新設したもの

| 成果物 | 役割 |
|---|---|
| `.claude/dist-layers.json`（37エントリ） | **何をどう配るかの単一の正**。5層 × git pathspec、last-match-wins |
| `.claude/.asset-manifest.json`（**配布先にだけ生成**） | 配ったファイルのLF正規化sha256と、配布元のコミットSHA・版 |
| `.claude/scripts/src/check-dist-coverage.sh` | 層分け定義の網羅性検査（追跡ファイル全件・`.gitignore` 全行が分母） |
| `.claude/rules/agent-common.md` | `AGENTS.md` から切り出した共通ルールの実体（`AGENTS.md`/`CLAUDE.md`/`GEMINI.md` が `@import`） |
| `.claude/docs/spec/asset-distribution.md` | 配布**機構**の仕様 |
| `.claude/docs/ddr/i0026-01-….md` | 方式選定・`exclude` の明示必須・`requiredLine` の3つの判断 |
| `apply-mr-workflow-to-project/assets/*.template` 4本 | `seed` の雛形（`AGENTS.md` / `index.md` / `HANDOFF.md` / `REVIEW-POINTS.local.md`） |

### 作り直したもの

- **`install-to-project.sh` を2パス構成へ**（走査 → 提示 → 配置）。受け入れ条件4「何が起きるかを
  事前に提示する」は1パスでは満たせない。
- **`sync-assets.sh` を廃止**。配る内容の写しを `assets/` へ集める旧方式は、実状態とずれても誰も
  気づけなかった。**本家の実状態そのものを正**にした。

### 廃止した仕組み

| 廃止したもの | なぜ要らなくなったか |
|---|---|
| `ALWAYS_OVERWRITE_RELPATHS` | manifest のsha256と比べるので、版を上げた回に誤検知しなくなった |
| `safe_copy_dir` / `HAS_WARNED` | 走査パスで件数を集計する形になった |
| `sync-assets.sh` と `assets/.gitignore` の写し | `.gitignore` に `dist:begin`〜`dist:end` のマーカーを置き、実状態から配る行を取る |

## なぜそうしたか

### 層を5つにした（受け入れ条件1の修正）

起票時の条件は4層（`core`/`seed`/`merge`/`local`）だったが、**`exclude` を加えた5層**にした。
4層のままだと「配らない」が**暗黙の既定値**になり、**配り忘れと意図的な除外が区別できない**。
明示指定にしたことで、網羅性チェックが「全件がいずれかの層に分類されている」を保証できる。
（DDR `i0026-01` の b。issue #26 へコメントで記録済み。**issue本文は編集していない**）

### `AGENTS.md` を `core` へ昇格させず `requiredLine` にした

`AGENTS.md` は「プロジェクト概要」という**配布先の所有物**を含むため、`core` にすると再適用の
たびにそれが消える（受け入れ条件3に反する）。代わりに `seed` 専用の任意キー `requiredLine` を
新設し、**指定の行を含まない `seed` を、触らずに一覧で知らせる**形にした。
（DDR `i0026-01` の c）

### 本家で削除されたファイルを自動削除しない

一覧提示のみで、削除は人間に委ねる。`.claude/rules/*.md` は自動読込なので消し忘れの影響が
大きいが、**配布先のファイルを消す操作をインストーラに持たせない**ほうを優先した。

## 検証結果

| 検証 | 結果 |
|---|---|
| 単体テスト | 18ファイル / **`passed=1231 failures=0`** |
| 層分けの網羅性 | 追跡ファイル **427/427** 件・`.gitignore` **9/9** 行・空振り0件・不正0件 |
| DDR一覧 | `--check` が最新（**78件**）／識別子の重複0件 |
| `.gemini/` | `--check` が `.claude/` と同期 |
| 実配布 | 空リポジトリへ配布し、配布先で17本の単体テストが全て緑になることを確認 |

**テストは「異常があるときに本当に落ちるか」まで確かめている。** 新規に足した表明は、
いずれも修正前の実装へ戻して**実際に落ちることを先に確認**してから書いた。

## 敵対的レビューで見つかった重い欠陥

フェーズ2・3で各3回（上限）実施。とくに重いものを挙げる。**いずれもAIの自己確認では出て
こなかった**。

| 欠陥 | 症状 |
|---|---|
| `merge_json_keys` | 配布先の `settings.json` が不正JSONだと**0バイトへ破壊し、成功メッセージを出して終了コード0**。`merge` 層なので `.bak` も無く回復不能 |
| `func \|\| return 1` を4箇所 | **条件式の中なので `set -e` が関数内部まで一時停止**し、`cp`/`jq` の失敗が握りつぶされる（上の欠陥の直接の原因） |
| 外部コマンド起動 **1208回** | git bashの95ms/回を当てると約115秒。core の件数に比例して伸びる → **176回**へ |
| dirty判定のpathspec **28,319バイト** | Windowsの `CreateProcess` 上限32,767文字に迫る。超えると配布が始まる前に止まる |
| `test_check_dist_coverage.sh` | **配布先で必ず `failures=15`**（スキップ判定がファイル存在だった）。かつ実行先リポジトリのindexを書き換えていた |
| 本家の削除・改名が配布先に残る | `.claude/rules/*.md` は自動読込なので、削除したはずのルールを配布先のAIが読み続ける |

## `main` の取り込み

作業中に `main` が3回進み、そのつど取り込んだ。**うち1回は構造的な衝突**だった。

- **issue #70（PR #157）**: `.gemini/` が `.claude/` からの**変換生成物**になりGit管理下へ入った
  （176ファイル）。本ブランチの層分け定義と正面から衝突したため、類型Eとして判断を仰いだうえで
  **`exclude` の1エントリへ畳んだ**（配らず、配布先で `sync-gemini-assets.sh` が生成する）。
  あわせてフェーズ5が6→**7ステップ**に増えた。
- **`.gitignore`（`585a6b3`）**: `参考ディレクトリ` を有効なパターンとして末尾へ移す変更と、
  本ブランチの `dist:end` マーカーが同じ位置で衝突。**マーカーの外**へ置いた（このリポジトリ固有の
  除外であり、配布先へ配る理由が無い）。

**マージが持ち込んだ食い違いは、いずれも既存のテストが検出した。** 配布用の
`HANDOFF.md.template` が `cleanup-task.sh` の定数に追随していなかった件（`test_cleanup_task.sh`）と、
インストーラ手順7が `sync-gemini-assets.sh` を**本家のカレントディレクトリのまま**呼んでいた件
（`test_install_to_project.sh` B-7。本家の `.gemini/` を作り直し、配布先には何も作らない状態だった）。

### `【実装反映】` の移植

`main` が `setup-gemini-links.sh` を削除したため、`【実装反映】` の修正対象そのものが消えた。
**捨てずに、同じ類型の穴が後継スクリプトに無いかを調べて移植する**判断が下り、3件見つけて直した。

| 箇所 | 症状 |
|---|---|
| `list_gemini_removed_files` の `find` | 走査が失敗すると**削除ガードが無言で失効し、配布先の自前ファイルを終了コード0のまま消す** |
| `build_into` の `git ls-files` | 列挙の失敗が「列挙0件」と区別できず、`.gitignore` を原因として名指しする誤った案内 |
| `convert_agent_to_reply` の `mapfile` | 読めないファイルを「frontmatter がありません」と誤診 |

`setup-gemini-links.sh` は条件式（`func || fail=1`）、`sync-gemini-assets.sh` はプロセス置換
（`while … done < <(cmd)`）と形は違うが、**どちらも失敗が呼び出し元へ届かない**という同じ原因である。

## spec / ddr への反映先

| 反映先 | 内容 |
|---|---|
| `.claude/docs/spec/asset-distribution.md`（**新設**） | 5層・`dist-layers.json`・manifest・2パス構成・`merge` の2戦略・`requiredLine`・網羅性チェック・性能 |
| `.claude/docs/spec/distribution-assets.md` | 「配布経路での扱い」を層ベースへ全面書き換え／未決定事項5件のうち4件を削除し解消先を changelog へ |
| `.claude/docs/spec/sync-gemini-assets.md` | 移植した3件と、削除ガードが列挙の失敗でも失効してはならないこと |
| `.claude/docs/ddr/i0026-01-….md`（**新設**） | 方式選定（受け入れ条件11）・`exclude` の明示必須・`requiredLine` |
| `.claude/rules/directory-structure.md` / `index.md` | `agent-common.md`・`check-dist-coverage.sh`・`.asset-manifest.json` の位置づけ |
| `.claude/skills/commit/SKILL.md` | `ai-asset:` prefix の規約 |

**`.claude/VERSION` は `0.2.0` のまま据え置いた**（増分を決めるのは人間。flow-id 4-4 のレビューで
確定）。AIは `1.0.0` を提案したが採用されなかった。据え置いた事実と実害（配布先は同じ版のまま
配布の仕組みごと入れ替わった `.claude/` を受け取る）は `distribution-assets.md` の changelog に
記録してある。**ただし issue #26 で manifest が入ったため、機械可読な同一性は manifest 側で
判別できる**——VERSIONだけが手掛かりだった issue #54 の据え置きとは、この点が異なる。

## 残課題

| 項目 | 扱い |
|---|---|
| **Windows実機での改行挙動が未確認** | spec の「未決定事項」に残した。sha256のLF正規化・`.gitattributes` の配布・`.gemini/` の判定の3つが同根 |
| `.claude/VERSION` と manifest の役割 | 両方を持ち続けるかは未決。spec の「未決定事項」に論点として残した |
| `merge` 層の指紋が読まれていない | manifest へ記録はするが判定には使っていない。コメントに明記済み（逆輸入・issue #27 で使える） |
| 本家の削除・改名の追従 | 一覧提示のみ。自動削除は意図的にスコープ外 |
| 関連issueへ通知済み | #153 漂白／#27 逆輸入／#108 HANDOFF雛形／#167 SKILL.md frontmatter／#171 `.gitignore` の参照切れ／#165・#184 wip集約 |
