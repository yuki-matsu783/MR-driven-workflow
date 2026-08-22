---
title: 【実装】【テスト】sync-gemini-assetsと周辺スクリプトの改修
type: plan
description: .claude/から.gemini/を生成するsync-gemini-assets.shの新規実装と、周辺スクリプト・.gitignoreの改修およびその単体テストの計画
tags: [plan, gemini, 実装, テスト, issue-70]
keywords: [sync-gemini-assets, setup-gemini-links, extract-frontmatter, search-frontmatter, gitignore, ゴールデンファイル, 冪等性, 単体テスト]
---

# 【実装】【テスト】sync-gemini-assetsと周辺スクリプトの改修

対象: issue #70 / PR #157 / フェーズ3（flow-id 3-1〜）
前提となる調査結果: `reports/20260822_nimble-syncing-lantern_gemini同期方式の調査.md`
**前提となる設計合意**: `plans/【設計】gemini変換規則とsettings写像の確定.md`

**実装と単体テストを1つの計画に併記する**のは、変換規則の正しさが**テストでしか固定できない**
ためである（Gemini CLI がこの環境に無く、実行して確かめられない）。テストを別合意にすると
「実装は合意したがテストは未合意」という状態が生まれ、**唯一の検証手段が後回しになる。**

## 目的

`.gemini/` を `.claude/` からの変換生成物にするスクリプトを実装し、リンク運用の痕跡を除去する。

## 変更対象（全11件）

| # | ファイル | 操作 | 内容 |
|---|---|---|---|
| 1 | `.claude/scripts/src/sync-gemini-assets.sh` | **新規** | 本体。変換・コピー・除外・`--check` |
| 2 | `.claude/scripts/src/setup-gemini-links.sh` | **削除** | リンク運用の廃止 |
| 3 | `.claude/scripts/src/extract-frontmatter.sh` | **修正** | `.gemini` を走査対象から除外する（**grepでは見つからない作業**） |
| 4 | `.claude/scripts/src/search-frontmatter.sh` | **修正** | 除外は残し、**理由コメント L32–L36 のみ**書き換え |
| 5 | `.gitignore` | **修正** | **9行削除**（L26–L29 のコメントブロック＋L30–L34 のパス5行） |
| 6 | `.gemini/settings.json` | **性格の変更** | 手書きの実体 → 生成物（Git管理下には残す） |
| 7 | `.claude/scripts/test/test_sync_gemini_assets.sh` | **新規** | 1 の単体テスト |
| 8 | `.claude/scripts/test/test_search_frontmatter.sh` | **要確認** | `.gemini` 除外のテストが「リンクだから」を前提にしていないか |
| 9 | `.claude/skills/apply-mr-workflow-to-project/scripts/sync-assets.sh` | **修正** | `.gemini/` の収集をやめる（配布物へ含めない） |
| 10 | 同上 `scripts/install-to-project.sh` | **修正** | `.gemini/` のコピーをやめ、**配布先で生成**する |
| 11 | 同上 `SKILL.md` | **修正** | `.gemini/` を「配布する資産」として説明している4箇所 |

**9〜11 は当初スコープ外にしていたが、2026-08-22のレビューで「配布先で生成する」と決着した
ため本計画へ取り込んだ**（下記「6. 配布アセット」）。外していた理由が「配布先で生成するか、
生成済みを配るかという別の判断を含むため」だったので、その判断が付いた時点で保留の理由が消えた。
**フェーズ4へ持ち越すと拾い忘れの穴になる**ため、関連するスクリプト改修と同じ計画で扱う。

## 方針

### 1. `sync-gemini-assets.sh`（新規）

```
使い方: bash .claude/scripts/src/sync-gemini-assets.sh [--check] [--dry-run]
```

| 引数 | 挙動 |
|---|---|
| （なし） | `.gemini/` を再生成する |
| `--check` | 生成せず、**一時ディレクトリへ生成して `.gemini/` と突き合わせ**、食い違えば非0で終了 |
| `--dry-run` | 何が作られ・消えるかだけを出力する |

処理は3系統に分ける（調査結果 Q4「除外には性質の違う2種類がある」に対応）。

| 系統 | 対象 | 扱い |
|---|---|---|
| **変換** | `.claude/agents/*.md` | ホワイトリスト方式でfrontmatterを絞り、ツール名を11種の対応表で変換し、`tools` をYAML配列で出力。`model` は除去。**対応表に無いツール名はエラーで落とす** |
| **変換** | `.claude/settings.json` | Q3の写像表に従って `.gemini/settings.json` を生成 |
| **コピー** | `docs/` `rules/` `hooks/` `scripts/` `skills/` | そのまま。**skills は変換不要**（Q2） |
| **除外** | `**/index.jsonl` `.claude/state/` | 生成物・ローカル状態 |

**`.claude/scripts/test/` `VERSION` `REVIEW-POINTS.md` は「コピーする」で確定する。**
除くと `.gemini/scripts/` だけ構成が食い違い、`.gemini/` を見た人が「なぜここだけ欠けているのか」を
毎回調べることになる。**「配布先で生成する」と決まったことがこれを補強する**——生成先が
配布先にも増える以上、`.gemini/` の中身が「`.claude/` から機械的に決まる」ほど説明が短くて済む。
除外するのは**生成物とローカル状態だけ**（`index.jsonl` / `state/`）という単純な規則を保つ。

#### 性能の制約（このリポジトリ固有）

`.claude/` 配下は148件（うち `.md` 105件）。**ファイルごとに `jq` や `git check-ignore` を
呼ばない**（`.claude/rules/shell-script-style.md`「外部プロセス起動のコスト」。git bash では
外部プロセス起動が約95ms/回のため、148件×数回で容易に十数秒に達する）。

- 除外判定は `git check-ignore --stdin` へ**まとめて渡す**
- frontmatterの変換は**1ファイル1回の `jq` 呼び出し**に抑える（`extract-frontmatter.sh` の
  前例に倣う）
- ホットパスの小さなヘルパーは `REPLY` へ返す（コマンド置換でforkしない）

### 2. `setup-gemini-links.sh`（削除）

`git rm` で削除する。**削除したパスは他の変更と同じように `commit` スキルへ渡してよい**
（`.claude/rules/git-workflow.md`「コミット運用」）。

### 3. `extract-frontmatter.sh`（`.gemini` 除外の追加）

**この作業は `.gemini` への言及をgrepしても出てこない**（現状0件）。列挙は L396 の

```bash
git ls-files --cached --others --exclude-standard -z -- "$target_rel"
```

で行われており、**`.gemini/` がGit管理下になった瞬間に走査対象へ入る**。pathspecの
除外指定（`:(exclude).gemini/**`）を足す方針とし、**`$target_rel` が `.gemini` 配下自身を
指して呼ばれた場合の挙動**（除外して0件にするのか、明示指定なら通すのか）も決める。

> **この副作用は静かに壊れる。** 除外しないと `.gemini/**/index.jsonl` が生成され、エラーは
> 出ない。気づくのは `doc-search` の結果が二重になってからである。

### 4. `search-frontmatter.sh`（コメントのみ修正）

`SF_EXCLUDED_DIRS` の `.gemini` は**残す**（実体が2つある以上、二重ヒットは変わらず起きる）。
L32–L36 の理由コメントが「ローカルリンクだから」「ジャンクションは find から通常のディレクトリに
見えるため」と書いており、**リンク運用の廃止で前提ごと成り立たなくなる**。
「**実体が2つあるため**二重にヒットする」へ書き換える。

### 5. `.gitignore`（9行削除）

**パス5行（L30–L34）だけでなく、その上のコメントブロック4行（L26–L29）も消す。**
コメントは廃止した `setup-gemini-links.sh` の実行を案内しており、残すと嘘の手順になる。
**副産物として、存在しないDDR名 `i00-13` を指す参照も同時に消える**（`i36-01` の方は
別ブロックに残る。扱いはフェーズ4で判断）。

### 6. 配布アセット（`apply-mr-workflow-to-project`）— 配布先で生成する

**2026-08-22のレビューで「配布先で生成する」と確定した。** 生成済みの `.gemini/` を配るのではなく、
配布先が `.claude/` を受け取ってから `sync-gemini-assets.sh` を走らせる。

| ファイル | 現状 | 変更後 |
|---|---|---|
| `scripts/sync-assets.sh` | `PROJECT_ROOT/.gemini/` を `ASSETS_DIR/.gemini/` へ収集する（L42–L61） | **収集ブロックごと削除**。生成物を配布物へ焼き込まない |
| `scripts/install-to-project.sh` | `mkdir -p .gemini` / `safe_copy_dir .gemini` / 非Goプロジェクトでの `rm .gemini/rules/go-applications.md` | **削除**し、`.claude/` の配置後に `sync-gemini-assets.sh` を実行する |
| 同上（`.gitignore` 追記） | `/.gemini/usage-state/` `/.gemini/session-logs/` を追記する | **削除**（このリポジトリの現行パスは `/usage/` であり、そもそも実在しないパスを配っている） |
| `SKILL.md` | 「`.claude/scripts/`, `.gemini/scripts/`」のように**併記**して配布資産として説明（4箇所） | `.gemini/` は `.claude/` からの生成物である旨へ書き換える |

**`sync-gemini-assets.sh` 自体は `.claude/scripts/src/` にあるため、既存の `.claude/` 配布に
自動で乗る**（配布リストへの追加は不要）。ただし配布先での実行は `jq` に依存するため、
**`jq` が無い環境では生成をスキップして警告する**（インストール全体を失敗させない）。

**SKILL.md の書き換えを本計画に含める理由**: この3ファイルは1つのまとまった変更であり、
skill文書だけを `【AIアセット作成】` 側へ分けると、**スクリプトと説明が食い違う期間ができる**。
`【AIアセット作成】` 側の繰り下げで `.claude/scripts/` の参照を巻き取ったのと同じ判断である。

## やらないこと

- **flow-id 5-3 の新設と繰り下げ** → `plans/【AIアセット作成】…` が扱う
- **配布先での実際のインストール検証**（別リポジトリへ `install-to-project.sh` を流す）→
  この環境では配布先を用意できない。`bash -n` と、変更箇所の読み合わせまでとする
- **spec・DDR・README・`index.md` の更新** → フェーズ4
- **Gemini CLI での実行検証** → CLI が無いため実施しない

## テスト計画

`.claude/scripts/test/test_sync_gemini_assets.sh` を新規作成する。規約は
「`passed=N failures=N` を出力し、失敗があれば終了コード1」。

| # | 何を固定するか | なぜ要るか |
|---|---|---|
| T1 | **agents変換のゴールデンファイル比較** | 変換規則が壊れたことを検出する唯一の手段 |
| T2 | **ツール名対応表の網羅性** | 「表に無い＝Geminiに無い」ではない。**表そのものをテストで固定する** |
| T3 | **未知のツール名でエラーになること**（終了コード） | 黙って落とす実装への退行を防ぐ |
| T4 | **`tools` がYAML配列で出力されること** | issue #70 の症状そのもの |
| T5 | **`title`/`type`/`tags`/`keywords` が除去されること** | `localAgentSchema` が `.strict()` のため |
| T6 | **冪等性**（2回流して差分が出ないこと） | `--check` が意味を持つ前提 |
| T7 | **`--check` の終了コード**（一致=0／不一致=非0） | 検査として機能しているか |
| T8 | **除外対象（`index.jsonl` / `state/`）が出力に含まれないこと** | Q4 |
| T9 | **`settings.json` のゴールデンファイル比較** | Q3の写像表の固定 |

### テストの書き方で守ること（既知の罠）

- **終了コードの検査に `"$(func; echo $?)"` を使わない**（`set -e` 配下でサブシェルが
  `echo` に到達しない）。`if func; then st=0; else st=1; fi` で受ける。
- **既存関数を再定義して差し替える場合は、サブシェルへ閉じ込める**（`unset -f` は
  実定義そのものを消す）。**アサーションはサブシェルの外**で行う（中で行うと `failures` が
  加算されず、失敗しても緑になる）。
- **CR混入の検査に `grep -c $'\r'` を使わない**。除去前後のバイト数比較で行う。
- **合成フィクスチャだけで完了としない。** 実際の `.claude/agents/*.md` 全件に対して
  変換を流し、エラーが出ないことを確認する。

### `test_search_frontmatter.sh` の確認

`.gemini` 除外に関する既存テスト（11箇所の言及）が、**「リンクだから除外する」という前提に
依存していないか**を読む。前提の記述だけなら期待値は変わらない。**依存していた場合は期待値を
書き換える**（除外そのものは残るため、失敗するのはコメント・変数名に依存した箇所に限られるはず）。

## 検証手順（この計画の完了条件）

1. `bash -n` が全変更ファイルで通ること。
2. `bash .claude/scripts/test/test_sync_gemini_assets.sh` が `failures=0` を返すこと。
3. `bash .claude/scripts/test/test_search_frontmatter.sh` が `failures=0` を返すこと
   （変更前に一度流して**現状の基準値を取ってから**変更する）。
4. `bash .claude/scripts/src/sync-gemini-assets.sh` を実行し、続けて `--check` が 0 を返すこと。
5. **`bash .claude/scripts/src/extract-frontmatter.sh .` を実行し、
   `.gemini/**/index.jsonl` が1件も生成されていないこと**を確認する
   （`git status --porcelain -z` で `.gemini` 配下の新規ファイルが出ないこと）。
6. `git status` に**意図しない生成物が現れていない**こと（`.stackdump` 等の新種の副産物は
   `.gitignore` と `commit` スキルの除外リストの**両方**へ追加する）。
7. **配布アセットに `.gemini` への言及が残っていないこと**（生成物である旨の説明を除く）。

   ```bash
   grep -rn '\.gemini' .claude/skills/apply-mr-workflow-to-project/ \
     --include='*.sh' --include='*.md' | grep -v index.jsonl
   ```

   `sync-assets.sh` / `install-to-project.sh` は**0件**、`SKILL.md` は生成物としての説明のみ。
8. `bash -n` が配布アセットの2スクリプトで通ること（実行はしない）。
