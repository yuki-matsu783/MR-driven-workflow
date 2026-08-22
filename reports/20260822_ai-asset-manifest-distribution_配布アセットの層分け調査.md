---
title: 配布アセットの層分けとmanifest方式の調査結果
type: report
description: issue #26 の調査7項目の実施結果。全パスの層割り当て・REVIEW-POINTSの扱い・定義の形式・manifestの記録項目・既存欠陥の再現と切り分け・AGENTS.mdの分割線・.skill廃止の影響範囲
tags: [report, distribution, manifest, investigation]
keywords: [層分け, core, seed, merge, local, exclude, asset-manifest, sha256, dirty, REVIEW-POINTS, setup-gemini-links, index.jsonl, AGENTS, DEVELOPERS]
---

# 配布アセットの層分けとmanifest方式の調査結果

- issue: #26 / PR: #154
- 個別調査計画: `plans/【調査】配布アセットの層分けとmanifest方式.md`
- フェーズ: 2〈調査〉（flow-id 2-6）
- 実行環境: Claude Code on the web のリモート実行環境（Linuxコンテナ）。`gh`/`glab` CLIは不在。

## 結論の要約

| # | 論点 | 結論 |
|---|---|---|
| 1 | 層分けの網羅性 | 4層では**足りない**。本家固有で配らないパスが4件あり、**明示的な `exclude` カテゴリ**が要る（**ユーザー承認済み**。受け入れ条件1を「4層＋`exclude`」へ更新する） |
| 2 | `REVIEW-POINTS.md` の層 | **`core` ＋ 配布先所有の `REVIEW-POINTS.local.md`（`seed`）の併設**。層は増やさずに済むが、波及先は1箇所ではない（下記） |
| 3 | 定義の置き場所 | **案A（定義ファイル1枚）＋ 網羅性チェック**。案Bはバイナリ・JSONに書けず、案Cは例外を表現できない |
| 4 | manifestの記録項目 | `core`/`seed` は sha256、`merge` は**行の指紋**、`local` は記録しない。dirtyは**配布対象パスに限定**し `--allow-dirty` を持つ |
| 5 | 既存欠陥 | **5件すべて再現**。作り直しで消えるのは**4件**、明示対処が要るのは**1件（#3）**。**加えて未記録の欠陥を3件発見** |
| 6 | `AGENTS.md` の分割線 | 「ルール」節**9項目すべて**が本家所有。`.claude/rules/agent-common.md` へ切り出す |
| 7 | `.skill` 廃止の影響 | 書き換えが要るのは6ファイル、**書き換えてはいけない**のは6箇所（DDR本文・changelog） |

## 調査1: 配布対象パスの全数棚卸しと層の割り当て

### 件数（何を数えたか）

**分母は「配布の検討対象になるパス」であり、この報告自身の増減に左右されない形で定義する。**

| 範囲 | 件数 | 定義 |
|---|---|---|
| **突き合わせに使う分母** | **168** | 追跡ファイルから、`plans/` `worklog/` `reports/` の**タスク単位のファイル**を除いたもの |
| 除いたタスク単位のファイル | 6 | 全体作業計画1・個別計画1・worklog 2・この報告のmd/html 2 |

**`plans/` `worklog/` `reports/` をディレクトリ丸ごと落とさない。** この3ディレクトリには
`plans/REVIEW-POINTS.md` `reports/REVIEW-POINTS.md` `worklog/TEMPLATE.md` という**永続ファイル**が
あり（`.claude/rules/docs-workflow.md` のライフサイクル表が「flow-id 5-4でも削除しない」と定めて
いる）、いずれもこの調査で `core` に割り当てている。丸ごと落とすと、**後述の未記録欠陥#7・#8 で
挙げた「配られていないファイル」がそのまま網羅性検査の対象外になり、定義への載せ忘れを検査が
素通しする**。

```bash
# 分母（範囲外を除き、永続3件は足し戻す）→ 168
{ git ls-files -z -- . ':(exclude)plans' ':(exclude)worklog' ':(exclude)reports'
  git ls-files -z -- plans/REVIEW-POINTS.md reports/REVIEW-POINTS.md worklog/TEMPLATE.md
} | tr '\0' '\n' | grep -c .

# 除いたタスク単位のファイル → 6
git ls-files -z -- plans worklog reports \
  ':(exclude)plans/REVIEW-POINTS.md' ':(exclude)reports/REVIEW-POINTS.md' ':(exclude)worklog/TEMPLATE.md' \
  | tr '\0' '\n' | grep -c .
```

内訳（トップレベル別、上の分母168の内訳）: `.claude/` 148 / ルート直下 12 / `.gitlab/` 2 /
`.github/` 2 / `.gemini/` 1 / 永続3件（`plans/` 1・`reports/` 1・`worklog/` 1）。
`.claude/` の内訳: `docs/` 86 / `scripts/` 31 / `skills/` 12 / `rules/` 7 / `hooks/` 7 / `agents/` 2 /
直下3（`settings.json` `VERSION` `REVIEW-POINTS.md`）。

**アプリ本体を持たないテンプレートリポジトリのため、追跡ファイルはすべて配布の検討対象に入る。**

### 層の割り当て

| パス | 層 | 根拠 |
|---|---|---|
| `.claude/agents/` `.claude/hooks/` `.claude/rules/` `.claude/scripts/` `.claude/docs/spec/` `.claude/docs/ddr/` `.claude/docs/README.md` `.claude/VERSION` | `core` | 機構本体。配布先が書き換えると本家の更新で壊れる |
| `.claude/skills/` のうち `apply-mr-workflow-to-project` を除く**9件**（9スキル） | `core` | 同上。9（core）＋3（exclude）＝12 で `skills/` の12件と閉じる |
| `.claude/settings.json` | `merge` | `hooks` は本家所有、`permissions` / `plansDirectory` / `autoCompactWindow` は配布先所有（下記） |
| `REVIEW-POINTS.md` 4件 | `core` | 中身は機構の観点であり汎用。配布先固有の観点は `REVIEW-POINTS.local.md`（`seed`）へ（調査2） |
| `worklog/TEMPLATE.md` | `core` | issue本文の指定どおり。**現状は配布されていない**（未記録欠陥#8） |
| `.gemini/settings.json` | `core` | リンク運用を前提とした設定。配布先が書き換える理由が無い |
| **`.github/` `.gitlab/` のテンプレート4件** | **`core`** | **ユーザー判断**。見出し構成が `start` の `test_issue_sections`（issue の4見出しの検査）と `describe` の生成する description に**機能的に結合**している。配布先が項目を足したい場合は**別ファイル**で足せる（`.github/ISSUE_TEMPLATE/`・`.gitlab/issue_templates/`・`.gitlab/merge_request_templates/` は複数ファイルを置ける）。GitHubの既定PRテンプレートだけは単一ファイルなので、上書き時の警告＋`.bak`（受け入れ条件4）で受ける |
| **`CLAUDE.md` `GEMINI.md`** | **`core`** | **ユーザー判断**。`seed` だと将来 import の書き方が変わったときに配布先へ届かず、共通ルール一式が**無言で読み込まれなくなる**。`core` なら警告と `.bak` で気づける。**セットで必須の変更**は下記 |
| `.mrworkflow.json` | `seed` | ブランチ命名規則・ディレクトリ位置を配布先が書き換える |
| `AGENTS.md` | `seed` | 分割後は「共通ルールのimport＋プロジェクト概要」。概要は配布先が書く（**雛形化が必要**。調査6） |
| `HANDOFF.md` | `seed` | 受け入れ条件3が明示（再適用で上書きしない） |
| `index.md` | `seed` | Repository Map。配布先の構成を反映する |
| 各 `REVIEW-POINTS.local.md` | `seed` | 空の雛形を1回だけ配置し、以後本家は触らない（調査2） |
| `.gitignore` `.gitattributes` | `merge` | 行追記。`.gitattributes` は既に実装済み（`dist:begin`〜`dist:end`） |
| `plans/` `worklog/` `reports/` のタスク単位ファイル | `local` | タスク単位の作業状態 |
| `usage/` `.claude/state/` `**/index.jsonl` `.claude/docs/.ddr-list.*` `build/` `*.log` `*.stackdump` `.vscode/` | `local` | 実行時生成・配布先固有 |
| `.gemini/{docs,hooks,rules,scripts,skills}` | `local` | 下記のとおり、受け入れ条件8は `setup-gemini-links.sh` が満たす |
| `.claude/skills/apply-mr-workflow-to-project/`（3件） | **`exclude`** | 配ると配布先が本家として再配布でき、版の系譜が分岐する |
| `README.md` `DEVELOPERS.md` `考えたこと.md` | **`exclude`** | 本家（このテンプレート）固有の説明・メモ |

**`exclude` は4件（`apply-mr-workflow-to-project/` を1件と数える）。** `.gitignore` 対象の
`.claude/skills/apply-mr-workflow-to-project/assets/` は、`sync-assets.sh` の生成物であり
**新方式では存在しなくなる**ため、分類の対象に数えない。

#### `CLAUDE.md` / `GEMINI.md` を `core` にする際にセットで必要な変更

現状の2ファイルは末尾が空の見出しで終わっている。

```
## Claude Code固有ルール      ← 中身が空
```

**これは「ここへ書いてください」という誘いであり、`core` のまま残せない**（配布先が素直に書いた
内容が、再適用で警告付きとはいえ消える）。`core` 化と同時に、この節を次のポインタへ置き換える。

> プロジェクト固有のルールは `.claude/rules/<名前>.md` へ置く。

`.claude/rules/` は「ディレクトリごと `core`」ではなく**manifestに載っているファイルだけが `core`**
なので、配布先が新規に足したファイルはインストーラが触らない。かつ `.claude/rules/*.md` が
セッション開始時に自動で読み込まれることは調査6で実測している。

### `local` 層の導出（`.gitignore` のパターンを正とする）

計画どおり、実在ファイルの列挙ではなく `.gitignore` のパターンから導いた。**実測でこの必要性が
裏づけられた**。

- `git status --porcelain --ignored` は25件（先に `sync-assets.sh` を流して `assets/` を作ると26件）を
  返すが、**`.gemini/{docs,hooks,rules,scripts,skills}` は1件も現れない**
  （`setup-gemini-links.sh` 未実行のため実体が無い）。
- `usage/` と `.claude/state/` は**ディレクトリ単位に畳まれて1行になる**（`!! usage/`）。配下の
  ファイルを見るには `--ignored=matching` が要る。この形では「どのファイルが `local` か」を
  取り出せない。

**`usage/` 自体は実在する**（配下7ファイル）。dirty判定（調査4）で「`usage/` は常に存在する」と
書いているのはこの意味であり、両者は矛盾しない。

`.gitignore` のパターンは9群。うち `/.claude/skills/apply-mr-workflow-to-project/assets/` は
`sync-assets.sh` の生成物なので、**新方式では不要になる**（調査7）。

### `.gemini/` 配下 — 受け入れ条件2と8の両立

受け入れ条件2（`local` 層は作成も変更もしない）と受け入れ条件8（実体コピーを再適用で最新化）は、
`.gemini/{docs,...}` を素直に `local` へ入れると衝突する。**所有者を分けることで、層を増やさずに
解消できる。**

- **インストーラ（`install-to-project.sh`）は `.gemini/` 配下に触らない**（＝ `local` のまま）。
- **受け入れ条件8は `setup-gemini-links.sh` が満たす。** インストーラは適用の最後にこれを
  呼び出すだけにする。
- そのために `setup-gemini-links.sh` へ必要な変更は2点。
  1. symlink もジャンクションも作れない環境で**実体コピーへフォールバックし、終了コード0で終わる**
     （受け入れ条件7）。
  2. **対象が実体ディレクトリ（リンクでない）の場合は、中身を最新へ入れ替える**（受け入れ条件8）。
     現行は「既存のリンクがあれば何もしない」なので、実体コピーは古いまま残る。
- リンクと実体の判別は `[ -L "$target" ]` では足りない。NTFSジャンクションはbashからは
  ディレクトリに見えるため、**「実体コピー」と「ジャンクション」を区別できない**。ジャンクションを
  実体コピーとして扱うと本家側の `.claude/` を壊しうるため、Windows環境では
  `fsutil reparsepoint query` 等での確認が要る。**この判別はWindows実機でしか確認できず、
  未確認事項として残す。**

### 受け入れ条件7の再現手段（確立済み）

Linuxでは `ln -s` が常に成功するため、**`ln` のスタブをPATHの先頭へ置く**（`.claude/rules/
shell-script-style.md`「テスト」のスタブ `jq` と同じ手口）。`cmd.exe` はLinuxに存在しないため
ジャンクション経路も自動的に不成立になり、「どちらも作れない環境」をそのまま再現できる。
**現行 `setup-gemini-links.sh` はこの条件下で5件すべて失敗し、終了コード1で終わることを実測した。**

```bash
mkdir -p "$SP/fakebin" && printf '#!/usr/bin/env bash\nexit 1\n' > "$SP/fakebin/ln"
chmod +x "$SP/fakebin/ln"
( export PATH="$SP/fakebin:$PATH"; bash .claude/scripts/src/setup-gemini-links.sh )
```

フェーズ3の単体テストはこの形で書く。

## 調査2: `REVIEW-POINTS.md` の層

### 中身の実測

| ファイル | 行数 | `issue #` を含む行 | `.claude/` を含む行 | 内容 |
|---|---|---|---|---|
| `REVIEW-POINTS.md`（ルート） | 84 | 5 | 6 | 言語・表記／恒久的な参照先／hookの誤検知／ドキュメント構造／frontmatter |
| `.claude/REVIEW-POINTS.md` | 79 | 2 | 4 | bashの既知の罠／スクリプトの作法／テスト／VCS抽象化層／スキル定義 |
| `plans/REVIEW-POINTS.md` | 57 | 3 | 0 | 2階層構造／種別／内容／issue分割／検証手順 |
| `reports/REVIEW-POINTS.md` | 48 | 2 | 4 | 内容の妥当性／HTML版／ライフサイクル |

（件数は `grep -c` による**マッチした行数**であり、出現回数ではない。）

**4件とも、内容は「この機構をどう使うか」の観点であって、本家プロジェクト固有の業務知識ではない。**
issue番号への参照は、観点の**根拠となった実例**として書かれており（「issue #127で実際に踏んだ」）、
配布先でも読み物として意味を持つ。したがって**汎用＝`core` 寄り**である。

### 現状の実測（重大な発見）

**4件のうち配布されているのは `.claude/REVIEW-POINTS.md` の1件だけ**である。ルート・`plans/`・
`reports/` の3件は配布されておらず（`plans/` `worklog/` は `.gitkeep` だけが作られる）、
`reports/` ディレクトリはそもそも作られない。つまり**配布先で敵対的レビューを回すと、4件中1件の
観点表しか適用されない**。

### 結論

**`core` ＋ 配布先所有の `REVIEW-POINTS.local.md`（`seed`）の併設**を採る。第5の層は要らない。

| ファイル | 層 | 所有者 |
|---|---|---|
| `<dir>/REVIEW-POINTS.md` | `core` | 本家。更新は再適用で配布先へ届く |
| `<dir>/REVIEW-POINTS.local.md` | `seed`（空の雛形を1回だけ配置） | 配布先。本家は二度と触らない |

- 却下案「`seed` 単独」: 本家が観点を追加しても配布先へ永久に届かない。観点表は issue #77 以降も
  継続的に増えており（`.claude/REVIEW-POINTS.md` は issue #127 の教訓を取り込んでいる）、
  届かないことの実害が大きい。
- 却下案「`core` 単独」: 配布先が育てた観点が再適用で消える。
- 却下案「`merge` 層として散文をマージ」: markdownの散文に対する構造的マージは、行の重複・
  見出しの重複を機械的に解けない。`.gitattributes` の「行の追記」が成立するのは、1行が独立した
  設定であるためで、観点表には当てはまらない。

### 波及先（**1箇所ではない**）

**この案の成立条件は `cleanup-task.sh` の変更である。** 同スクリプトは
`KEEP_BASENAMES=("REVIEW-POINTS.md")` という**ベース名の完全一致**で残す対象を決めており、
`test_cleanup_task.sh` がその完全一致を明示的に表明している。

```
72: assert_eq "is_keep_path: 名前が似ているだけのファイルは残さない" "1" ... "plans/REVIEW-POINTS.md.bak"
73: assert_eq "is_keep_path: 接尾辞が一致するだけのファイルは残さない" "1" ... "plans/OLD-REVIEW-POINTS.md"
```

したがって、このまま `plans/REVIEW-POINTS.local.md` を置くと **flow-id 5-4 で毎タスク削除される**。
配布先が育てた観点を守るための仕組みが、タスクを1つ回すたびに消える。

| 波及先 | 変更内容 |
|---|---|
| `.claude/scripts/src/cleanup-task.sh` | `KEEP_BASENAMES` へ `REVIEW-POINTS.local.md` を追加（**成立条件**） |
| `.claude/scripts/src/collect-review-points.sh` | 各祖先ディレクトリで `.local` も続けて読む（本家 → 配布先の順） |
| `.claude/scripts/test/test_cleanup_task.sh` / `test_collect_review_points.sh` | 上記に対応するケースを追加 |
| `.claude/rules/markdown-frontmatter.md` | 「typeの値」表の `review-points | **/REVIEW-POINTS.md` |
| `.claude/docs/spec/adversarial-review.md` | 「レビュー観点（REVIEW-POINTS.md）」節 |
| `.claude/rules/docs-workflow.md` / `directory-structure.md` | 「flow-id 5-4で削除しない」の記述 |

## 調査3: 層分け定義の置き場所と形式

| 案 | 判定 | 理由 |
|---|---|---|
| **A: 定義ファイル1枚** | **採用** | 全パスを1箇所で見渡せ、網羅性を機械的に検査できる |
| B: 各ファイルがマーカーで持つ | 却下 | `.mrworkflow.json` `settings.json`（JSON）にコメントを書けない。`.gitkeep` のような空ファイル、将来の画像等にも書けない |
| C: ディレクトリ単位の規約 | 却下 | 例外（`worklog/TEMPLATE.md` が `core` で `worklog/*.md` が `local`、`.claude/skills/` のうち1つだけ `exclude`）を表現できない |

**案Aの弱点（足し忘れが無言で漏れる）は、検査で塞ぐ。**

- `.claude/scripts/src/check-dist-coverage.sh`（仮）: **上記の分母168と同じ範囲**の追跡ファイルと
  `.gitignore` のパターンを、定義ファイルのパターンへ突き合わせ、**どの層にも `exclude` にも
  該当しないパスを列挙して終了コード1**を返す。
- **`exclude` を暗黙の既定値にしない。** 「定義に無い＝配らない」にすると、この検査が
  常に成功する（＝異常が無ければ何も出ない検証になる）。

### `.claude/settings.json` を `merge` にする際の分割線

| キー | 所有者 | 根拠 |
|---|---|---|
| `hooks` | 本家 | 配布したhookスクリプトの登録そのもの。配布先が書き換えると機構が動かない |
| `permissions.deny` の2行（`Bash(git commit*)` / `PowerShell(git commit*)`） | 本家 | コミットをスキル経由へ強制する多重防御の一部（DDR i0000-09） |
| `permissions` のそれ以外 / `plansDirectory` / `autoCompactWindow` | 配布先 | 権限モード・compact窓は配布先の好み |

**したがって `merge` の粒度は「トップレベルのキー単位」では足りず、「キーのパス単位」が要る**
（`permissions` の中で所有者が割れるため）。

## 調査4: manifestの記録項目

### 記録するもの

```jsonc
{
  "schemaVersion": 1,
  "source": { "url": "<本家のリモートURL>", "commit": "<コミットSHA>", "version": "<.claude/VERSION>" },
  "appliedAt": "<ISO8601>",
  "files": [
    { "path": ".claude/rules/git-workflow.md", "layer": "core",  "sha256": "..." },
    { "path": "HANDOFF.md",                   "layer": "seed",  "sha256": "...", "placed": true },
    { "path": ".mrworkflow.json",             "layer": "seed",  "placed": false },
    { "path": ".gitattributes",               "layer": "merge", "lines": ["<配った行のsha256>"] }
  ]
}
```

| 層 | manifestへ書くか | 書く内容 |
|---|---|---|
| `core` | 書く | `sha256`。再適用時に配布先の変更を検出して警告する（受け入れ条件4） |
| `seed` | 書く | `sha256` ＋ **`placed`**（配置したか、既に在ったので触らなかったか）。`placed: false` のファイルは配布先所有なので、以後 sha256 を比較しない |
| `merge` | 書く | ファイル全体の sha256 ではなく**配った行の指紋**。配布後の内容は「本家の行＋配布先の行」になるため、全体のsha256は必ず食い違う |
| `local` | **書かない** | そもそも配布していない。書くと「配布した」と誤読される |
| `exclude` | 書かない | 同上 |

### sha256 の算出（改行コード）

**本家のワークツリーの内容をそのまま取るのではなく、LFへ正規化してから取る。** Windowsで
`core.autocrlf=true` の配布先では作業ツリーがCRLFになり、正規化しないと**全テキストファイルが
「配布先が変更した」と誤検知される**。

- 対象はテキストファイルのみ。バイナリは正規化せずそのまま取る（現状バイナリの配布物は無い）。
- 配布先の `.gitattributes` は配布先が決めるものなので、**インストーラ側は「LF正規化した内容の
  sha256」を一貫して使う**。
- **Windows実機での確認はこの環境（Linuxコンテナ）ではできない。未確認事項として、
  フェーズ4で新方式のspecの「未決定事項・懸念点」へ記載する。**

### dirty の定義（受け入れ条件6）

**配布対象パスに限定した `git status --porcelain` が空であること**を dirty でない条件とする。

| 候補 | 判定 | 理由 |
|---|---|---|
| 追跡ファイルの変更・ステージ済み変更 | **含める** | コミットSHAとワークツリーの内容が食い違うと、manifestのSHAが嘘になる |
| 未追跡ファイル | **含める**（配布対象パス配下のみ） | 未追跡の新規スクリプトは「配るつもりのファイル」でありうる |
| 無視ファイル | **含めない** | `index.jsonl` `usage/` `.claude/state/` は常に存在し、含めると永久に適用できない |
| `plans/` `worklog/` `reports/` のタスク単位ファイル | **含めない** | `local` 層で配布対象外。ここが汚れていても manifest の正しさに影響しない |

**`--allow-dirty` を持たせる。** フェーズ3の実装中、本家のワークツリーは常に dirty であり、
`test_install_to_project.sh` は `install-to-project.sh` を実プロセスとして起動する結合テストなので、
逃げ道が無いとテストが1件も流せない。ただし次の2点を守る。

- `--allow-dirty` を付けた適用では、manifestの `source.commit` に **`<sha>-dirty` の接尾辞**を付ける。
- 逃げ道は**テストとデバッグのためのもの**であり、通常の配布手順には書かない。

## 調査5: 既存欠陥の再現と切り分け

### spec が記録していた5件（すべて再現・確認した）

| # | 欠陥 | 再現結果 | 作り直しで消えるか |
|---|---|---|---|
| 1 | `.gitignore` 追記が非冪等（先頭の空文字列が毎回空行を追記） | **再現**。2回目の適用で空行が1行増える | **消える**（`merge` 層の実装を `.gitattributes` 方式に揃えるため） |
| 2 | 判定が部分一致（`grep -Fq`、`--` 無し） | **再現**。配布先が `# /.claude/session-logs/ は当面不要と判断した` とコメントで書いているだけで「もう有る」と誤判定し、実設定が入らない | **消える**（同上。`grep -Fxq --` を使う） |
| 3 | 配る行が本家の実状態ディレクトリと不一致 | **確認**。配るのは `/.claude/usage-state/` 等の4行。本家の実体は `/usage/` と `/.claude/state/` | **消えない — 明示対処が要る**。配る行の定義を `.gitignore` 自身へ持たせる（`.gitattributes` と同じマーカー方式） |
| 4 | `HAS_WARNED` が `safe_copy_dir` の外へ伝わらない | **再現**。個別の `⚠️ WARNING` は1件出るが、末尾の `ATTENTION` ブロックは0件 | **消える**（作り直しでパイプライン経由のループを使わない） |
| 5 | 配布先へ `.gitignore` 対象のローカル生成物が混入する | **再現**。`index.jsonl` が **18件**、`.claude/state/` が丸ごとコピーされた | **消える**（受け入れ条件2 = `local` 層を配らないことで消える。**根拠は層分け定義であり、実装の副作用ではない**） |

**合計: 消えるのが4件（#1 #2 #4 #5）、明示対処が要るのが1件（#3）。**

**欠陥2の再現条件には順序がある。** コメント行は**1回目の適用より前**に配布先へ無ければならない。
1回目で本物の行が入ってしまうと、2回目は本物に一致するため再現しない（当初の検証手順はこの
順序を誤っており、実測で判明したので計画側を修正した）。

**欠陥4の再現条件はコピー経路に依存する。** `safe_copy_dir` 経由のファイル（`.claude/` 配下）を
改変する必要があり、ルート直下の `HANDOFF.md` は `safe_copy_file` 経由なので `ATTENTION` が出て
しまい再現にならない。

### 新たに見つかった欠陥（specにも issue にも記録が無い）

| # | 欠陥 | 実測 | 受け入れ条件との対応 |
|---|---|---|---|
| 6 | **`HANDOFF.md` が配られ、再適用で上書き対象になる** | 配布先に `HANDOFF.md` が存在し、`safe_copy_file` の対象になっている | **受け入れ条件3が現状では満たされない**。`seed` 層で解消する |
| 7 | **`REVIEW-POINTS.md` が4件中1件しか配られない** | ルート・`plans/`・`reports/` の3件が未配布 | 受け入れ条件1（全パスの分類）で拾う。調査2の結論で解消する |
| 8 | **`worklog/TEMPLATE.md` が配られない** | `worklog/` には `.gitkeep` だけが作られる | issue本文が `core` と指定しているのに未配布。`reports/` ディレクトリ自体も作られない |

## 調査6: `AGENTS.md` の分割線

### 判定（「ルール」節の9項目）

`awk '/^## ルール/{f=1;next} /^## /{f=0} f && /^- /{c++} END{print c}' AGENTS.md` → **9**。

| # | 項目 | 所有者 |
|---|---|---|
| 1 | 応答・対話はすべて日本語 | 本家 |
| 2 | 開発フロー全体は `issue-mr-flow/SKILL.md` を参照 | 本家 |
| 3 | issue起票は着手の指示ではない | 本家 |
| 4 | 実作業前に計画を立てて提示 | 本家 |
| 5 | 計画は `plans/` 配下・2階層 | 本家 |
| 6 | 承認まで書き換え・実行をしない | 本家 |
| 7 | 詳細ルールは `.claude/rules/` を参照 | 本家 |
| 8 | GitHub/GitLab情報は `gh`/`glab` CLI（不在時はMCP） | 本家 |
| 9 | **ドキュメント探索は frontmatterインデックス（`index.jsonl`）の横断検索を第一手段にする**（`doc-search` スキル、issue #38、DDR i0038-01） | 本家 |

**9項目すべてが本家所有である。** 項目9は「ルール」節で最も長い項目（43〜54行）で、
`doc-search` スキルの入口そのものなので、**切り出しから落とすと配布先で全文探索が既定に戻る**。

### 切り出し後の形

- 切り出し先: **`.claude/rules/agent-common.md`**（`type: rule`、`title: AIエージェント共通ルール`）。
- `AGENTS.md` は「共通ルールのimport＋プロジェクト概要＋開発・実行」の3節だけになり、**`seed` 層**に置ける。
- `CLAUDE.md` / `GEMINI.md` は現状どおり `@./AGENTS.md` を保つ（層は `core`。上記）。

### `seed` の雛形にする際の注意

配布先所有になるのは「プロジェクト概要」「開発・実行」の2節だが、**中身は同じではない**。

- `## 開発・実行` は `<!-- TODO: ... -->` のプレースホルダのみ。そのまま `seed` にできる。
- `## プロジェクト概要` は TODOコメントの下に**本家固有の本文が3行ある**（「このリポジトリは、
  issue駆動MRワークフロー機構……のテンプレートです」）。`seed` は「配置後は配布先が所有する
  初期値」なので、このままだと**どの配布先の `AGENTS.md` も本家を名乗った状態から始まる**。
  **`seed` の雛形にする際に汎用の文言へ差し替える**（フェーズ3の作業項目）。

### `@import` の解決（実測と未確認）

- **実測**: このセッションでは `.claude/rules/*.md` の**7件すべて**が「project instructions」として
  読み込まれた。frontmatterに `alwaysApply: true` を持つのは**3件**
  （`directory-structure.md` / `docs-workflow.md` / `git-workflow.md`）だけなので、**読み込みは
  `alwaysApply` の有無に依存していない**。つまり Claude Code では、`.claude/rules/` へ置くだけで
  読み込まれる。
  （`grep -l alwaysApply .claude/rules/*.md` は4件を返すが、4件目 `markdown-frontmatter.md` の
  ヒットは**本文中の表**であり、同ファイルのfrontmatterに `alwaysApply` は無い。）
- **未確認**: Gemini CLI 側の挙動と、`AGENTS.md` から `@./.claude/rules/agent-common.md` と
  相対パスで書いたときの解決基準。**安全側に倒し、`AGENTS.md` からの `@` import も併せて張る**。
  実際の解決可否は、フェーズ3で切り出した直後の**次のセッション開始時**に確認できる。

## 調査7: `.skill` パッケージ廃止の影響範囲

### 書き換えるもの（現在の状態を説明している箇所）

| ファイル | 箇所 | 対応 |
|---|---|---|
| `DEVELOPERS.md` | 43行目・50〜70行目（`.skill` ビルド手順と `gemini skills install`）、60〜61行目（`build/` へのビルド成果物移動） | **書き換える**（受け入れ条件10の後半）。フェーズ3の `【AIアセット作成】`が担当 |
| `.gitignore` | 8〜9行目（`sync-assets.sh` が生成する `assets/` の除外）、6行目（`/build/`） | `assets/` は削除。`/build/` は下記の判断による |
| `.claude/docs/spec/distribution-assets.md` | **6行目**（frontmatter `keywords` の `sync-assets`）、**85〜91行目**（「配布経路での扱い」の表）、**111〜112行目**（下記の仕様変更） | 更新する。**同じファイルの120行目は触らない**（下記） |
| `.claude/scripts/test/test_install_to_project.sh` | 11・23・62〜63行目。**63行目が実際に `sync-assets.sh` を起動している** | 作り直しが必須 |
| `index.md` | 45行目（`./build/` の説明） | `build/` の判断による |
| `.claude/rules/directory-structure.md` | 45行目（ツリー中の `build/`） | 同上 |

**`build/` は `.skill` のビルド成果物の置き場としてのみ存在している。** ビルド工程が無くなるので、
**削除するのか将来の別用途のために残すのかを決めて書く**（決めずに放置すると、次の作業者には
漏れと区別できない。とくに `.claude/rules/directory-structure.md` はセッションごとに読み込まれる
ルールなので、存在しない工程の記述が残り続ける）。

### 書き換えてはいけないもの（point-in-time の記録）

`.claude/rules/docs-workflow.md`「ファイル移動に伴うパス参照の一括置換は…changelogを対象に
含めない」に該当する。

| ファイル | 箇所 | 理由 |
|---|---|---|
| `.claude/docs/ddr/i0033-01` `i0033-02` `i0033-03` `i0063-01` | 本文中の `sync-assets.sh` への言及 | DDRは本文を一度マージしたら変更しない |
| `.claude/docs/spec/issue-mr-workflow.md` 2304行目 | issue #63 のchangelogエントリ内 | 当時の判断の記録 |
| **`.claude/docs/spec/distribution-assets.md` 120行目** | **`## 影響範囲 / ### issue #33（初版）` の中** | 同上。**同じファイルに「直す行」と「触ってはいけない行」が混在する**ため、`sed` の一括置換をこのファイルへかけない |

`.claude/rules/directory-structure.md` 110行目の `assets/` は**スキルのバンドルリソース一般**の話で、
`sync-assets.sh` の `assets/` とは無関係。対象外。

### `.gitattributes` の配る行の読み出し元（仕様変更を伴う）

現行は `install-to-project.sh` が `${ASSETS_DIR}/.gitattributes`（294行目）から読んでいる。
新方式では `assets/` が無くなるため、**本家のワークツリー（clone先）の `.gitattributes` を直接読む**
形へ移す。issue #26 のコメント（PR #136）が「移設漏れで静かに空振りする」と指摘した箇所である。

**あわせて、マーカーが1行も見つからなかった場合の扱いを「警告」から「失敗」へ変える**。これは
**仕様変更**であり、現行specの明文と食い違う。

```
.claude/docs/spec/distribution-assets.md:111-112
- **配る行が1件も読めなかった場合は、無言でスキップせず件数付きの警告を出す**（マーカーの
  書き間違いで配布が静かに空振りするのを防ぐため）。
```

方向は現行specと同じ（空振りを無言で通さない）だが、**明文が変わるので フェーズ4で
`distribution-assets.md` 111〜112行目も更新する**。

なお `.gitignore` も同じマーカー方式へ揃えることで、欠陥3（配る行が実状態と不一致）が
構造的に解消する（配る行の定義が `.gitignore` 自身に来るため、本家の状態と自動的に一致する）。

## ユーザーの判断（flow-id 2-6 の結果に対して、チャットで受けたもの）

| # | 論点 | 判断 |
|---|---|---|
| 1 | `exclude` カテゴリの新設 | **承認**。受け入れ条件1を「4層＋`exclude`」へ更新する。**issue本文は書き換えず、flow-id 5-2 の関連issue通知でissue #26 へコメントとして記録する**（起票時点の条件が読めなくなるのを避けるため） |
| 2 | `.github/` `.gitlab/` テンプレート4件 | **`core`**（ユーザー提案。根拠は上記の割り当て表） |
| 3 | `CLAUDE.md` / `GEMINI.md` | **`core`**。空の「固有ルール」見出しを `.claude/rules/` へのポインタへ差し替えることとセット |

## 残る未確認事項（フェーズ4で新方式のspecへ残す）

- **sha256のLF正規化がWindows実機で意図どおり効くか**（この環境では確認できない）。
- **`.gemini/` のリンクと実体コピーの判別**。NTFSジャンクションは `[ -L ]` で区別できない。
- **`AGENTS.md` からの `@` import が `.claude/rules/` 配下へ解決するか**（フェーズ3の切り出し直後、
  次のセッション開始時に確認できる）。

## 検証に使ったコマンド

```bash
# 分母168（範囲外を除き、永続3件は足し戻す）と、除いたタスク単位ファイル6件
{ git ls-files -z -- . ':(exclude)plans' ':(exclude)worklog' ':(exclude)reports'
  git ls-files -z -- plans/REVIEW-POINTS.md reports/REVIEW-POINTS.md worklog/TEMPLATE.md
} | tr '\0' '\n' | grep -c .
git ls-files -z -- plans worklog reports \
  ':(exclude)plans/REVIEW-POINTS.md' ':(exclude)reports/REVIEW-POINTS.md' ':(exclude)worklog/TEMPLATE.md' \
  | tr '\0' '\n' | grep -c .

# skills の内訳（9 core + 3 exclude = 12）
git ls-files -- .claude/skills | wc -l
git ls-files -- .claude/skills/apply-mr-workflow-to-project | wc -l

# AGENTS.md「ルール」節の項目数（→ 9）
awk '/^## ルール/{f=1;next} /^## /{f=0} f && /^- /{c++} END{print c}' AGENTS.md

# frontmatterに alwaysApply を持つファイル（→ 3。grep -l だと本文中の言及を拾って4になる）
grep -H 'alwaysApply' .claude/rules/*.md

# 既存欠陥の再現（順序が重要。欠陥2の仕込みは1回目の適用より前）
tmp="$(mktemp -d)"; git init "$tmp" >/dev/null
bash .claude/skills/apply-mr-workflow-to-project/scripts/sync-assets.sh
printf '# %s は当面不要と判断した\n' '/.claude/session-logs/' > "$tmp/.gitignore"
bash .claude/skills/apply-mr-workflow-to-project/scripts/install-to-project.sh "$tmp"
grep -Fxq -- '/.claude/session-logs/' "$tmp/.gitignore" || echo '欠陥2を再現'
cp "$tmp/.gitignore" "$tmp/.gitignore.1st"
printf '\n<!-- 配布先で改変 -->\n' >> "$tmp/.claude/rules/git-workflow.md"
bash .claude/skills/apply-mr-workflow-to-project/scripts/install-to-project.sh "$tmp" > "$tmp/2nd.log" 2>&1
diff "$tmp/.gitignore.1st" "$tmp/.gitignore"; grep -c WARNING "$tmp/2nd.log"; grep -c ATTENTION "$tmp/2nd.log"
find "$tmp" -name index.jsonl -not -path '*/.git/*' | wc -l
```

**片付け**: 検証で生成した `.claude/skills/apply-mr-workflow-to-project/assets/` は
`rm -rf` で削除済み（`.gitignore` 対象だが、本家のワークツリーへ残さない）。
