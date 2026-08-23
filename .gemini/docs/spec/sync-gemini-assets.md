---
title: .claude/ から .gemini/ への変換同期（sync-gemini-assets.sh）
type: spec
description: .gemini/ を .claude/ からの変換生成物として再生成するスクリプトの仕様。ツール名の対応表・agents frontmatterのホワイトリスト・settings.jsonの用語変換規則・削除ファイル検出と--force・3モードの動作を定める
tags: [gemini, script, sync, spec]
keywords: [sync-gemini-assets, gemini-cli, agents, settings.json, hooks, invoke_agent, GEMINI_PROJECT_DIR, 削除ファイル検出, force, flow-id-5-3]
---

# `.claude/` から `.gemini/` への変換同期（sync-gemini-assets.sh）

対象: `.claude/scripts/src/sync-gemini-assets.sh`（issue #70）

## 背景・目的

`.gemini/` は当初、`settings.json` 以外を `.claude/` 配下へのローカルリンク（シンボリック
リンク／NTFSジャンクション）として持ち、`setup-gemini-links.sh` が各開発者のマシン上で生成する
設計だった（DDR `i0000-13`）。この方式には2つの問題があった。

1. **リンクでは記法差を吸収できない。** `agents/*.md` の frontmatter も `settings.json` も、
   Claude Code と Gemini CLI で**スキーマが違う**。同じ実体を両方から読ませると、Gemini 側は
   ロードに失敗するか、必要な設定を失ったまま静かに動く。
2. **Git管理下に置けないため、リポジトリを見ても `.gemini/` の中身が分からない。** 配布先で
   リンク生成を忘れると、Gemini CLI からは資産が1つも見えない状態になる。

そこで **`.gemini/` を「手で書く実体」ではなく「`.claude/` から機械的に決まる生成物」へ改め**、
記法差はこのスクリプトが変換で吸収する方式にした（DDR `i0070-01`）。

**編集は必ず `.claude/` 側に対して行い、このスクリプトを流し直す。** `.gemini/` を直接編集しても
次の再生成で失われる。

## 仕様

### 呼び出し

```bash
bash .claude/scripts/src/sync-gemini-assets.sh [--check] [--dry-run] [--force]
```

| 引数 | 動作 |
|---|---|
| （なし） | `.gemini/` を再生成する。**生成物に含まれないファイルがあれば、1バイトも書かずに中断する**（下記「削除ファイル検出と `--force`」） |
| `--check` | 生成せず、一時ディレクトリへ生成して `.gemini/` と突き合わせる。食い違えば非0で終了する |
| `--dry-run` | 何が変わるかだけを出力する（**常に終了コード0**） |
| `--force` | 生成物に含まれないファイルを削除して再生成する（中断しない） |
| `-h` / `--help` | スクリプト冒頭の使い方コメントを出力する |

`--check` は**どのhookにも自動では挿さない**。CI・手動確認用である。

**`jq` が無い場合は、何も書き込まずに非0で終了する**（「生成をスキップして警告」にはしない）。
`jq` は `.gemini/` だけの前提ではなく `.claude/` 機構全体の前提であり（`Provider.sh`・
`extract-frontmatter.sh`・hookが依存）、無ければどのみち動かない。スキップは「インストールが
成功した」という嘘の結果を返すことになる。

### 生成の単位は「丸ごと置き換え」

`.gemini/` は完全な生成物なので、`rm -rf .gemini` してから一時ディレクトリを `mv` する。
差分更新にしないのは、`.claude/` 側で削除・改名されたファイルが `.gemini/` に残り続けるのを
確実に防ぐためである。**この性質が、下記の削除ファイル検出を必要にする。**

### 対象ファイルの列挙

```bash
git -c core.quotepath=false ls-files --cached --others --exclude-standard -z -- .claude
```

- **列挙は git に任せる。** `--exclude-standard` が `.gitignore` 対象（`**/index.jsonl`・
  `.claude/state/`・`skills/apply-mr-workflow-to-project/assets/`）を落とすので、生成物と
  ローカル状態の除外はこれだけで足りる（`git check-ignore` をファイルごとに呼ぶ必要はない）。
- `-z` と `core.quotepath=false` は、日本語を含むパスがクォート＋8進エスケープされるのを
  避けるため（`.claude/rules/shell-script-style.md`「コマンド置換とNULバイト」）。
- **`--cached` は「削除したがまだステージしていない」追跡ファイルも列挙する。** 実体が無いまま
  `cp` へ渡すと落ちるため、`[[ -f ]]` で弾き、**スキップ件数を標準エラーへ出す**（issue #117 と
  同じ罠。無言のスキップは本当の欠落を隠す）。
- **`--others` は未追跡ファイルも列挙する。** 意図した挙動である（`.claude/` へ足したばかりで
  まだコミットしていないファイルも生成物へ載せたい。載らないと flow-id 5-3 の `--check` が
  コミット前に通らない）。**その代わり、各開発者のローカル設定を落とす責任が `.gitignore` に
  移る。** このリポジトリの `/.claude/settings.local.json` がそれにあたり、配布先でも同じ行が
  効くよう `install-to-project.sh` の ignore ルールが配る。
  `COPY_EXCLUDED_PREFIXES` へは足さない（`.gitignore` に入れば `--exclude-standard` が落とすので
  二重になる。**除外の定義が2箇所に分かれるほうが危うい**）。
- **失敗条件は「列挙が0件」であって「コピー対象が0件」ではない**（issue #70）。
  `agents/*.md` と `settings.json` は変換で作るため、その2つしか無い `.claude/` でも生成物と
  しては成立する。0件のときは原因を切り分けてメッセージに出す。

  | 原因 | 判定 | メッセージ |
  |---|---|---|
  | `.claude/` が無い | `[ ! -d .claude ]` | ワークフローが導入されていないリポジトリと思われる旨 |
  | 追跡ファイルが全件、作業ツリーに無い | `skipped > 0` | 削除をステージしていない旨（`git status` を案内） |
  | すべて ignore されている | 上記以外 | `git check-ignore -v .claude/settings.json` を案内 |

  `main` は判定より前に `git rev-parse --show-toplevel` へ `cd` するので、**「リポジトリルート
  以外で実行した」は原因から外れる**（リポジトリ外なら `git rev-parse` の時点で失敗する）。

`.claude/agents/*.md` と `.claude/settings.json` はコピー対象から外し、変換して生成する。
それ以外のファイルは**内容を変えずにコピーする**。

### 用語変換規則1: ツール名の対応表

| Claude Code | Gemini CLI |
|---|---|
| `Read` | `read_file` |
| `Grep` | `grep_search` |
| `Glob` | `glob` |
| `Bash` | `run_shell_command` |
| `Write` | `write_file` |
| `Edit` | `replace` |
| `LS` | `list_directory` |
| `WebFetch` | `web_fetch` |
| `WebSearch` | `google_web_search` |
| `TodoWrite` | `write_todos` |
| `Task` | `invoke_agent` |

出典は gemini-cli の `packages/core/src/tools/definitions/base-declarations.ts` と
`packages/core/src/tools/tool-names.ts`（`ALL_BUILTIN_TOOL_NAMES`）。

**この表は1つだけ持ち、`agents` の `tools` と settings の hook `matcher` の両方で使う**
（2箇所に別の表を持つと、片方だけが古くなる）。

### 用語変換規則2: `agents/*.md` の frontmatter

Gemini 側へ通すキーは**ホワイトリスト**で定める。

```
kind / name / display_name / description / tools / mcp_servers /
temperature / max_turns / timeout_mins
```

- **ホワイトリストにする理由**: gemini-cli の `agentLoader.ts` の `localAgentSchema` に
  `.strict()` が付いており、**未知のキーが1つでも残るとロードが失敗する**。「既知の不要キーを
  除く」ブラックリストにすると、`.claude/rules/markdown-frontmatter.md` にキーが1つ増えるたびに
  Gemini 側が壊れる。
- **`model` は除去する。** スキーマ上は通るが、Claude側の値（`sonnet` / `opus`）は Gemini の
  モデル名ではない。弾かれないぶん危ない。除去すれば既定の `inherit` になる。
- **キーの並びはホワイトリストの順に固定する。** 入力の並びに追随させると、`.claude/` 側の
  並べ替えだけで `.gemini/` 側に差分が出る。
- `tools` は YAMLのフロー配列記法（`[a, b]`）でもカンマ区切り文字列でも同じ扱いにし、
  ブロックシーケンス（`- read_file`）として出力する。
- **本文（frontmatter より後ろ）はそのままコピーする。**

次のいずれかに当たると、**黙って落とさずエラーで停止する**。

| 入力 | 理由 |
|---|---|
| frontmatter が無い／終端の `---` が無い | 変換の前提が崩れている |
| `name` または `description` が空 | Gemini 側の必須キー |
| ホワイトリスト対象キーの値がネスト・複数行 | 未対応。黙って捨てるとGemini側が設定を失ったまま静かに動く |
| 対応表に無いツール名 | 同上。エラーメッセージで `GEMINI_TOOL_PAIRS` への追加を促す |

### 用語変換規則3: `settings.json` のキー対応

| Claude Code | Gemini CLI |
|---|---|
| `plansDirectory` | `general.plan.directory` |
| `hooks.SessionStart` | `hooks.SessionStart` |
| `hooks.PreToolUse` | `hooks.BeforeTool` |
| `hooks.PostToolUse` | `hooks.AfterTool` |

hook 1件（`CommandHookConfig`）の変換規則は次のとおり。

- **`if` は出力しない**（Gemini に無い）。代償は `.claude/hooks/*.sh` 側の前置フィルタが払う。
  push系2本は `raw_hints_at_git_push` を持ち、**判定本体（`command_invokes_git_subcommand`）の
  超集合**であることをテストで固定している。規約・実装の型は
  `.claude/rules/shell-script-style.md`「hookの前置フィルタ」が正。
- `command` と `args[]` を半角スペースで連結する。**こちらではクォートしない**（Gemini 側が
  `escapeShellArg` で代入前にクォート済み。`hookRunner.ts`）。
- `${CLAUDE_PROJECT_DIR}` → `$GEMINI_PROJECT_DIR`。**波括弧を付けない**（Gemini 側の置換が
  `/\$GEMINI_PROJECT_DIR/g` で、波括弧形式に一致しない）。
- `timeout` は秒 → ミリ秒。
- `name` は実行するスクリプトのベース名から `.sh` を除いたもの。
- **パス部分は書き換えない**（`.claude/hooks/` のまま）。同期を忘れても両経路が同じスクリプトを
  実行するようにするため。

`matcher` の扱いはイベントの種類で分かれる。

| イベント | `matcher` の意味 | 変換 |
|---|---|---|
| `PreToolUse` / `PostToolUse` | ツール名に対する**正規表現** | 縦棒区切りの各要素を対応表で変換し、重複を除く。**表に無い要素（`PowerShell` / `mcp__github__*` 等）はそのまま残す**（一致しない要素は正規表現として無害。推測で書き換えると黙って壊れる） |
| `SessionStart` | source の**完全一致**（`hookPlanner.ts` の `matchesContext`） | 下記 |

`SessionStart` の source は `startup` / `resume` / `clear` の3つで、**Claude の `compact` に
相当するものは無い**。完全一致で判定されるため、縦棒つなぎのまま出すとどの source にも一致せず
**hook が一度も発火しない**。したがって次のように変換する。

1. Gemini に無い値（`compact`）は捨てる。
2. 残りが3 source すべてを覆うなら **`matcher` を落とす**（`!matcher` は無条件 true）。
3. 部分集合なら **source ごとにグループを複製する**。
4. 残りが0件ならエラーで停止する。

### 変換しないトップレベルキー

`.claude/settings.json` のトップレベルキーのうち、**意図的に変換しないもの**を
`SETTINGS_IGNORED_KEYS` に理由付きで列挙する。**対応漏れではなく、記録された判断である。**

| キー | 変換しない理由 | 帰結 |
|---|---|---|
| `permissions` | Gemini の相当機能は policy engine（`.gemini/policies/*.toml`）だが、**プロジェクト単位の Workspace 層が現在無効**で、リポジトリへ置いても効果がゼロである（`docs/reference/policy-engine.md` の "(Currently disabled)"、upstream issue #18186） | コミット強制の多重防御が、**Gemini 経路では hook 1枚**になる。Workspace 層が有効化されたら見直す |
| `autoCompactWindow` | Gemini の `model.compressionThreshold` は「コンテキスト使用率の**分数**」（既定 0.5）であり、絶対値である Claude 側の値とは換算できない | 自動compactの閾値は Gemini 側の既定に従う |
| `env` | Gemini CLI の `settings.json` に「プロセス環境変数を注入する」ブロックが**構造として存在しない**（環境変数は `.env` から読み、settings 側にあるのは `advanced.excludedEnvVars` という除外リストだけ）。中身も `CLAUDE_CODE_ENABLE_TELEMETRY` を筆頭に Claude Code 固有で、受け口の `.claude/hooks/otel/listener.pl` が Claude Code の OTel スキーマを前提に振り分けるため、Gemini 側の `telemetry` ブロックへ流すと壊れる | Gemini CLI 経路では、Claude Code由来の `env` ブロックとしてのOTel計測は行われない（issue #70 / #103）。**ただしissue #105により、`env` 変換とは独立した経路（下記「固定値で注入するブロック」節）で `telemetry` ブロックが別途追加されており、`enabled: false` 固定のため現状は無効** |

### 固定値で注入するブロック（issue #105）

上記「変換しないトップレベルキー」は`.claude/settings.json`側のキーを**変換しない**判断だが、
`telemetry`ブロックは`.claude/settings.json`側に対応するキーを持たず、`SETTINGS_JQ_FILTER`が
**常に固定値を注入する**（変換ではなく注入）。

```jq
+ {
  telemetry: {
    enabled: false,
    target: "local",
    outfile: $otelOutfile,
    logPrompts: false
  }
}
```

- `$otelOutfile`は`GEMINI_OTEL_OUTFILE_REL`定数（既定`"usage/gemini-otel.log"`）から`--arg`で
  渡す。**出力先パスの単一の正**であり、読み取り側（`.claude/hooks/lib/UsageTracking.sh`の
  `_usage_otel_resolve_outfile_to_reply`）は`.gemini/settings.json`の`telemetry.outfile`を
  動的に読むため、この定数を変えると読み取り側も自動的に追随する（書き込み側・読み取り側の
  2箇所にハードコードして食い違う事故を防ぐ設計。issue #105フェーズ3敵対的レビュー指摘）。
- `enabled`は`false`固定。**現時点でこれをtrueへ切り替える手段は存在しない**
  （`.claude/settings.json`側に対応するスイッチが無く変換元を持たないため、
  `.gemini/settings.json`を手で書き換えても次回の`sync-gemini-assets.sh`実行で**無言で**
  falseへ戻る。**`--check`はこのフロー上どのhookにも自動では挿さっていない**
  （`issue-mr-flow/SKILL.md`「`.claude/` → `.gemini/` の変換同期（flow-id 5-3）」参照）ため、
  手編集は警告なく失われる。差分の有無を知りたい場合は手動で`--check`を実行する）。
  有効化手段の確立は本issueのスコープ外の未決定事項（DDR
  [i0105-02](../ddr/i0105-02-既定有効化は機微情報未確認のため保留する.md)）。
- `target`は`"local"`固定。outfileへ直接ファイル書き込みするため、`.claude/hooks/otel/`の
  常駐リスナー（OTLPネットワーク受信）は経由しない。
- 機構全体の仕様（バイトオフセットカーソル集計・対応工数レポートへの統合等）は
  [gemini-cli-telemetry.md](gemini-cli-telemetry.md)を参照（本specでは重複記載しない）。

### 未知の入力はエラーにする

**変換が情報を落としていることを、単体テストが永久に緑で通してしまう**のを避けるため、次の3つは
黙って落とさずエラーで停止する。

| 検出対象 | メッセージ |
|---|---|
| `settings.json` の未知のトップレベルキー | 「用語変換規則へ追加するか、`SETTINGS_IGNORED_KEYS` へ理由付きで加えてください」 |
| 未知の hook イベント | 「未知の hook イベントです: …」 |
| 対応表に無いツール名（`agents` の `tools`） | 「`GEMINI_TOOL_PAIRS` へ Gemini 側の名前を追加してください」 |

**`.claude/settings.json` へキーを足したら、このスクリプトも合わせて更新する必要がある。**
実際に issue #103 が `env` を追加した際、変換が停止して発覚した（上表のとおり除外側で解決した）。

### 削除ファイル検出と `--force`

再生成は `.gemini/` の**丸ごと置き換え**なので、そのままでは手で置いたファイルが黙って消える
（配布先が自前の `.gemini/commands/*.toml` や `settings.json` を持っている場合が該当する）。

- 書き込みの**前**に、`.gemini/` に実在して生成物に無いファイル（＝再生成で失われるファイル）を列挙する。
- 1件でもあり `--force` が無ければ、**1バイトも書き込まずに中断する**（該当ファイルを全件
  標準エラーへ出す）。
- `--force` を付けると削除して再生成し、**削除した件数と一覧を標準エラーへ出す**。
- 生成物と同名のファイルは上書きされるだけなので対象外である（内容の差は `--dry-run` が示す）。

このリポジトリの `.gemini/` は全体が生成物なので通常は0件で、その場合の挙動は削除ファイル検出の導入前と
変わらない。**実際に発火した例**: `.claude/skills/canvas-report/templates/` が issue #54 で
`assets/` へ改名された際、`.gemini/` 側に旧パスの生成物が残っていた（改名であることを
`git log --name-status` の `R100` で確認したうえで `--force` を使った）。

### 終了コード

| モード | 0 | 非0 |
|---|---|---|
| （なし） | 再生成した | `jq` 不在／**列挙0件**／変換エラー／削除されるファイルがあり `--force` 無し |
| `--check` | 同期している | 食い違っている／上記の各エラー |
| `--dry-run` | **常に0** | （`jq` 不在等、生成そのものが失敗した場合のみ） |

### 改行コードの扱い

入口と出口の両方で CR を落とす。**片方だけでは足りない**（issue #70）。

| 箇所 | 何が起きるか | 対処 |
|---|---|---|
| 入口: `agents/*.md` の読み込み | `mapfile` は改行だけを区切りにするため、CRLF のファイルでは1行目が `$'---\r'` になり「frontmatter がありません」と誤診する | `mapfile` 直後に全行の行末 CR を落とす（`${lines[i]%$'\r'}`。bash 組み込みなので fork は増えない） |
| 出口: `settings.json` の書き出し | Windows ネイティブの `jq` は標準出力へ CR を付ける。リダイレクトでファイルへ落とすため、`.gemini/settings.json` だけが CRLF になり `--check` が Windows と Linux で食い違う | `convert_settings … \| tr -d '\r' > …` |

`.gitattributes` の配布行（`dist:begin`〜`dist:end`）が `eol=lf` を保証するのは **`.sh` だけ**で
あり、`.md` は配布先の `core.autocrlf` 次第で CRLF になりうる。**配布行を増やして対処しない**
（配布先の `.gitattributes` へ追記される行なので影響がこのリポジトリに閉じない）。スクリプト側で
吸収する。

検証は**スタブ `jq`** で行う（`.claude/rules/shell-script-style.md`「テスト」）。
`sed '$!s/$/\r/'` を通すスタブを `PATH` 先頭へ置けば、Windows 実機が無くても CR 付与を再現できる。

### 性能上の前提

`.claude/rules/shell-script-style.md`「外部プロセス起動のコスト」に従い、**ファイル数に比例して
外部コマンドを起動しない**。

- コピーはファイルごとに `cp` を呼ばず、`printf '%s\0' … | xargs -0 cp --parents -t` で一括する
  （148件 × 約95ms = 十数秒になるため）。`xargs` が引数長の上限に応じて自動で分割するので、
  `.claude/` が大きくなっても `Argument list too long` にならない。
- `cp --parents` は相対パスの階層を再現するため、コピー元へ `cd` した実サブシェルで実行する。
- 削除ファイルの列挙は `find` を1回だけ起動する。
- ツール名の対応表・除外キーは**サイズが固定・小さい**ので `--argjson` で渡してよい
（同ルール「大きなJSONを引数としてjqへ渡さない」の例外条件に当たる）。

### flow-id 5-3 での実行

`.claude/` を変更したら、このスクリプトを流し直す。フローとしては **flow-id 5-3（`.claude/` →
`.gemini/` の変換同期）** が最終ゲートで、そこで生えた差分は直後の flow-id 5-4（最終統括
レポート）のコミットに載る（`.claude/skills/issue-mr-flow/SKILL.md` が正）。

**このステップ自身はコミットを持たない。** 生成と確定の間に他のステップを挟まないため。

## 影響範囲

### issue #70（新規追加・2026-08-23）

- `.claude/scripts/src/sync-gemini-assets.sh` を新規作成し、`setup-gemini-links.sh` を削除した。
- `.gemini/` をGit管理下へ入れた（`.gitignore` から該当9行を削除）。以後 `.gemini/` は**生成物
  だがコミットする**（配布先がリンク生成を忘れても資産が見えるようにするため）。
- `.claude/scripts/src/extract-frontmatter.sh` の走査から `.gemini` を除外した（同じ内容が
  2件ずつ `index.jsonl` に載るため）。
- DDR `i0000-13`（リンク運用）を `status: superseded` にし、`i0070-01` で置き換えた。
- issue-mr-flow に flow-id 5-3 を新設し、以降を1つずつ繰り下げた（42 → 43ステップ）。
- **フェーズ4〈反映〉で、敵対的レビューの指摘4件を取り込んだ**（上記「改行コードの扱い」
  「対象ファイルの列挙」に反映済み）。CR の入口・出口の2箇所、`--others` とローカル設定の
  除外を `.gitignore` へ委ねること（配布先の `.gitignore` へも配る）、失敗条件を
  「コピー対象0件」から「列挙0件」へ狭めたこと。

## 未決定事項・懸念点

- **変換後の `.gemini/` を Gemini CLI が実際にロードできることは未確認である。** Gemini CLI が
  この実行環境にインストールされていない（`command -v gemini` が空）ため、変換規則の根拠は
  すべて **gemini-cli のソースコードを読んだもの**であり、実行時の挙動を観測したものではない。
  issue #70 の受け入れ条件のうち、この1点だけが未達のまま残る。
- **`model` に与えるべき具体的な Gemini モデル名が分からない**（公式ドキュメントに網羅リストが
  無い）。現状は除去して `inherit` に倒しているため実害は無いが、エージェントごとにモデルを
  変えたくなった時点で調べ直す必要がある。
- **policy engine の Workspace 層が有効化されたら、`permissions` の変換を見直す**
  （upstream issue #18186）。「スコープ外だから変換しない」のではなく「今は動かないから変換
  しない」であり、上流が直れば解決しうる課題である。
- `mcp__github__issue_write` のように **Gemini CLI に相当ツールが無いもの**は、matcher に
  そのまま残るが一致しない。**外部の制約であって実装の欠陥ではない**が、Gemini 側で同等の
  制御が必要になった場合の代替手段は決めていない。
