---
title: Gemini CLIの記法と.gemini同期方式の調査結果
type: report
description: issue #70 のフェーズ2調査結果。Gemini CLIのagents/skills/hooksスキーマをソースコードから確定し、.gemini/を変換生成物へ改めるための変換規則・実行位置・波及範囲をまとめる
tags: [gemini, 調査, sync, report]
keywords: [gemini-cli, agentLoader, strict, isValidToolName, run_shell_command, skillLoader, hooks, timeout, flow-id, 冪等]
---

# 調査結果: Gemini CLIの記法と `.gemini/` 同期方式

個別調査計画: `plans/【調査】gemini-cli記法と同期方式の確定.md`
全体作業計画: `plans/nimble-syncing-lantern.md`（issue #70 / PR #157）

## この調査の根拠と、その限界（最初に読むこと）

**Gemini CLI はこの実行環境にインストールされていない**（`command -v gemini` が空）。したがって
**「Gemini CLI を起動して確かめた」結論は1件も無い。**

代わりに、**Gemini CLI のソースコードそのもの**を取得して読んだ。公式ドキュメントより強い根拠だが、
**実行時の挙動を観測したものではない**。

| 項目 | 値 |
|---|---|
| 取得元 | `https://github.com/google-gemini/gemini-cli`（shallow clone） |
| コミット | `5411f113cafae26161b4969b0237b8e1e024e2c2`（2026-08-21T16:16:56+00:00） |
| package version | `0.56.0-nightly.20260806.g761f604c1` |
| **M（実測）の測定環境** | Linux 6.18.44-fc-v21 / bash 5.2.21 / jq-1.7 / git 2.43.0（2026-08-22 実行）。**Windows git bash ではない** |

**根拠の強さを3段階で明示する。** 以下の表の「根拠」列は次の意味である。

| 記号 | 意味 |
|---|---|
| **S**（source） | Gemini CLI のソースコードを読んで確定。**バリデーション実装そのもの**なので、その版では確実 |
| **D**（docs） | 公式ドキュメントの記述。実装と食い違う可能性が残る |
| **R**（repo source） | **このリポジトリのソース**を読んで確定。実行して観測したものではない |
| **M**（measured） | このリポジトリ上で実際に**コマンドを流して測った**（測定環境は上表） |
| **U**（unverified） | 確かめていない。推測 |

**この調査で U のまま残ったもの**（フェーズ3で潰せないものは受け入れ条件の未達として扱う）:

- 変換後の `.gemini/agents/*.md` を Gemini CLI が実際にロードできること
- 変換後の `.gemini/settings.json` の hook が Gemini CLI 実行時に発火すること
- `model` に与えるべき具体的な Gemini モデル名（ドキュメントに網羅リストが無い）
- **SessionStart の `matcher` に `startup|resume|clear` という縦棒つなぎが有効か。**
  `docs/hooks/reference.md` L30 は matcher を「A regex (for tools) or **exact string (for lifecycle)**」と
  定義しており、lifecycleイベントでは完全一致の可能性がある。有効でなければ hook が一度も発火しない
- **`settings.json` 中の `${GEMINI_PROJECT_DIR}` が未解決だったときの挙動。**
  解決されること自体は `docs/reference/configuration.md` L63–L71 に明記があるが、
  変数が存在しない場合に空へ潰れるのかリテラルで残るのかは読めていない
- **`general.plan.directory` にカスタム値を置く場合、policy の追加が要るか。**
  `settingsSchema.ts` L338 の description が「A custom directory requires a policy to allow
  write access in Plan Mode.」と書いている

---

## Q1. `agents/*.md` frontmatter スキーマ（本issueの本題）

### 結論: 症状の原因は `tools` だけではない。**現行ファイルは3系統の理由で必ず弾かれる。**

バリデーションは `packages/core/src/agents/agentLoader.ts` の `localAgentSchema` が行う（**S**）。

```ts
const localAgentSchema = z
  .object({
    kind: z.literal('local').optional().default('local'),
    name: nameSchema,                       // /^[a-z0-9-_]+$/
    description: z.string().min(1),
    display_name: z.string().optional(),
    tools: z
      .array(                               // ← 配列であることが必須
        z.string().refine(
          (val) => isValidToolName(val, { allowWildcards: true }),
          { message: 'Invalid tool name' }, // ← issueのエラー文言はここ
        ),
      )
      .optional(),
    mcp_servers: z.record(mcpServerSchema).optional(),
    model: z.string().optional(),
    temperature: z.number().optional(),
    max_turns: z.number().int().positive().optional(),
    timeout_mins: z.number().int().positive().optional(),
  })
  .strict();                                // ← 未知キーを拒否する
```

（`agentLoader.ts` L91–L116。`.strict()` は L116）

現行 `.claude/agents/issue-mr-resume.md` の frontmatter を**実際にYAMLパースして型を測った**（**M**）。

```
$ python3 -c "import yaml; ..."
name: type=str
description: type=str
tools: type=str value=Read, Grep, Glob, Bash     ← 配列ではなく文字列
model: type=str value=sonnet
title: type=str                                   ← スキーマに無い
type: type=str                                    ← スキーマに無い
tags: type=list                                   ← スキーマに無い
keywords: type=list                               ← スキーマに無い
```

したがって弾かれる理由は次の3系統である。**issue #70 が把握していたのは (1) だけ**である。

| # | 理由 | 根拠 | 現行の値 |
|---|---|---|---|
| 1 | **ツール名が Gemini の語彙でない** | S | `Read` / `Grep` / `Glob` / `Bash` |
| 2 | **`tools` が配列でなくカンマ区切り文字列** | S+M | `tools: Read, Grep, Glob, Bash` はYAMLではスカラー文字列。`z.array()` を満たさない |
| 3 | **`.strict()` が未知キーを拒否する** | S | `title` / `type` / `tags` / `keywords` の4キー（`.claude/rules/markdown-frontmatter.md` 由来）が該当 |

> **(3) は本issueが見落としていた欠陥である。** ツール名だけを変換しても、`title` 等が残っている限り
> ロードは失敗し続ける。**変換規則は「置換」ではなく「許可キーだけを通すホワイトリスト」でなければ
> ならない。** ブラックリスト（既知の不要キーを除く）にすると、`.claude/rules/markdown-frontmatter.md`
> にキーが1つ増えるたびに Gemini 側が壊れる。

> **`tools.0` というエラー添字について。** issue #70 が引用したエラーは `tools.0: Invalid tool name`
> で、**`tools` が配列として解釈されたうえで0番目が不正**だったことを示す。上の (2) が正しければ
> 出るのは型エラーのはずで、食い違う。考えられるのは、報告時の環境では `tools` が
> YAMLの配列記法（`tools:` に続く `- Read` の並び、または `[Read, Grep]`）で書かれていた、という
> ことである。**この食い違いは実機が無いため確定できない（U）。** ただし**どちらであっても
> 上記3系統の変換は必要**であり、方針は変わらない。

### ツール名の対応表（**S**）

`isValidToolName` は `ALL_BUILTIN_TOOL_NAMES` との一致・レガシー別名・`discovered_tool_` 接頭辞・
MCP命名規約（`mcp_<server>_<tool>`）・ワイルドカードのみを通す
（`packages/core/src/tools/tool-names.ts`）。定数の実値は
`packages/core/src/tools/definitions/base-declarations.ts` にある。

| Claude Code | Gemini CLI | 定数 | 行 |
|---|---|---|---|
| `Read` | `read_file` | `READ_FILE_TOOL_NAME` | L51 |
| `Grep` | `grep_search` | `GREP_TOOL_NAME` | L33 |
| `Glob` | `glob` | `GLOB_TOOL_NAME` | L30 |
| `Bash` | `run_shell_command` | `SHELL_TOOL_NAME` | L56 |
| `Write` | `write_file` | `WRITE_FILE_TOOL_NAME` | L61 |
| `Edit` | `replace` | `EDIT_TOOL_NAME` | L65 |
| `LS` | `list_directory` | `LS_TOOL_NAME` | L47 |
| `WebFetch` | `web_fetch` | `WEB_FETCH_TOOL_NAME` | L82 |
| `WebSearch` | `google_web_search` | `WEB_SEARCH_TOOL_NAME` | L72 |
| `TodoWrite` | `write_todos` | `WRITE_TODOS_TOOL_NAME` | L76 |
| `Task` | `invoke_agent` | `AGENT_TOOL_NAME` | `tool-names.ts` L191 |

- `search_file_content` は `grep_search` のレガシー別名として**今も受理される**（`TOOL_LEGACY_ALIASES`）。
  ただし**新規に出力する側が別名を使う理由は無い**ので、正名の `grep_search` を出す。
- **対応表に無いClaudeツール名（`NotebookEdit` 等、Gemini 側に相当が見当たらないもの）が現れたら、
  変換スクリプトは黙って落とさずエラーにする。** 黙って落とすと、Gemini 側のエージェントが必要な
  権限を失ったまま静かに動く。現行2ファイルは上表のうち4種（`Read` / `Grep` / `Glob` / `Bash`）しか
  使っていない（**M**）が、将来増える。
- **上表は「Claude側の現行2ファイルが使う4種」を起点に広げたもので、Gemini側の語彙を網羅した
  結果ではない。** 当初は `TodoWrite` / `Task` を「相当が無いのでエラーになる例」として挙げていたが、
  `ALL_BUILTIN_TOOL_NAMES`（L248–L276）に対応先があったため表へ移した（敵対的レビューの指摘による）。
  **「表に無い」は「Geminiに無い」を意味しない。** フェーズ3では `ALL_BUILTIN_TOOL_NAMES` の側から
  突き合わせ直し、対応表の網羅性そのものを単体テストで固定する。

### `model` の扱い

- スキーマ上は `model: z.string().optional()` なので、**`sonnet` / `opus` は
  バリデーションを通ってしまう**（**S**）。**弾かれないぶん、かえって危ない**——実行時に
  未知のモデル名として扱われる。
- ドキュメントは既定を `inherit` とし、例として `gemini-3-preview` 等を挙げるが、
  **有効なモデル名の網羅リストは無い**（**D**）。
- **したがって `model` は「変換」ではなく「除去」する**のが安全である。除去すれば
  `inherit`（既定）になり、ユーザーが Gemini CLI で選んだモデルに従う。Claude 側の
  `sonnet` / `opus` という**強さの意図**は落ちるが、**誤ったモデル名を書くよりは落とすほうがよい**。
  この判断はフェーズ3の設計で確定させる。

---

## Q2. Gemini CLI は `skills/` を読むか

### 結論: **読む。かつ、変換は不要（そのままコピーでよい）。**

- 置き場所は `.gemini/skills/<name>/SKILL.md`（**D**: `docs/cli/creating-skills.md`）。
- ローダは `packages/core/src/skills/skillLoader.ts` の `parseFrontmatter`（**S**）。
  **agents とは対照的に、寛容である。**

  ```ts
  const parsed = load(content);
  const { name, description } = parsed as Record<string, unknown>;
  if (typeof name === 'string' && typeof description === 'string') {
    return { name, description };
  }
  // 失敗時は行単位の簡易パーサへフォールバック
  ```

  **`name` と `description` だけを取り出し、他のキーは無視する。`.strict()` に相当する検査は無い。**
- 現行 `.claude/skills/*/SKILL.md` 全9件が **`name` と `description` の両方**を持つことを確認した
  （**M**）。ローダは両方が揃って初めてスキルとして成立させ、片方でも欠けると簡易パーサへ落ち、
  そこでも取れなければ `null`（そのスキルは丸ごと捨てられる）になる。**片方だけの確認では
  「コピーのみでよい」の根拠にならない。**

  ```bash
  for f in .claude/skills/*/SKILL.md; do
    fm="$(awk 'NR>1 && /^---$/{exit} NR>1' "$f")"
    printf '%s' "$fm" | grep -qE '^name:' && printf '%s' "$fm" | grep -qE '^description:' \
      || echo "不足: $f"
  done
  # → 出力なし（9件中9件が両方を持つ）
  ```

| | agents | skills |
|---|---|---|
| スキーマ | `zod` + `.strict()` | 手書き（`name`/`description`のみ抽出） |
| 未知キー | **拒否** | **無視** |
| 変換 | **必要** | **不要**（コピーのみ） |

> **この非対称は覚えておく価値がある。** 「Gemini は Claude の記法を受け付けない」と一括りに
> するのは誤りで、**厳しいのは agents だけ**である。skills まで変換対象に含めると、情報を落とす
> だけで得るものが無い。

---

## Q3. `settings.json` の写像

issue #70 が挙げた10項目を、**現行2ファイルの実物**と**Gemini CLI のソース／ドキュメント**の
両方に突き合わせた。

| 観点 | `.claude` の実値 | `.gemini` の実値（手書き） | 検証 | 根拠 |
|---|---|---|---|---|
| hookイベント名 | `SessionStart` / `PreToolUse` / `PostToolUse` | `SessionStart` / `BeforeTool` / `AfterTool` | **正しい**。Geminiのイベントは `BeforeTool`/`AfterTool`/`BeforeAgent`/`AfterAgent`/`BeforeModel`/`BeforeToolSelection`/`AfterModel`/`SessionStart`/`SessionEnd`/`Notification`/`PreCompress` | D（`docs/hooks/reference.md`） |
| matcher（PostToolUse 第1グループ） | `Bash\|PowerShell` | `run_shell_command\|Bash\|PowerShell` | **正しい**。matcherは正規表現でツール名に照合される。Gemini の実ツール名は `run_shell_command` | D |
| matcher（PostToolUse 第2グループ） | `Bash\|PowerShell\|mcp__github__issue_write` | （第1グループへ併合され、**`mcp__github__issue_write` が落ちている**） | **誤り**。`.claude/settings.json` の `PostToolUse` は**2グループ**あり、2つ目（`post-issue-create-notice.sh`）だけ matcher が違う。**下記「`if` の畳み込みで落ちるもの」参照** | R（`.claude/settings.json`） |
| コマンド指定 | `command` + `args[]` | 単一シェル文字列 | **正しい**。Geminiの hook configuration は `type` / `command` / `name` / `timeout` / `description` のみで、**`args` は無い** | D |
| timeout | 秒（`30` / `10` / `20`） | ミリ秒（`30000` / `10000` / `20000`） | **正しい**。「Execution timeout in milliseconds (default: 60000)」 | D |
| 環境変数 | `${CLAUDE_PROJECT_DIR}` | `${GEMINI_PROJECT_DIR}` | **置換しなくても動く可能性が高い**。`docs/hooks/index.md` L144 に **`CLAUDE_PROJECT_DIR: (Alias) Provided for compatibility.`** がある。また `settings.json` の文字列値は**設定の読み込み時に**環境変数が解決される（`docs/reference/configuration.md` L63–L71、実装は `settings.ts` L804 の `resolveEnvVarsInObject`）。**「シェル実行時の展開である」という当初の断定は誤りだったので撤回する**。**未解決時の挙動は2026-08-22に確定**: `packages/cli/src/utils/envVarResolver.ts` の `resolveEnvVarsInString` は、未定義かつ既定値なしのとき `return match;`、すなわち**プレースホルダの文字列がそのまま残る**（空文字にはならず、ルート相対パスへ暴走しない）。さらに `${VAR:-DEFAULT}` 記法が使えるため `${GEMINI_PROJECT_DIR:-.}` と書ける。なお hook 実行時は `hookRunner.ts` L350 が `GEMINI_PROJECT_DIR: input.cwd` を渡し、L527 が `$GEMINI_PROJECT_DIR` をエスケープ済みcwdへ置換するため、**未定義になる経路は実質無い** | D / **S**（未解決時の挙動） |
| plans設定 | `plansDirectory` | `general.plan.directory` | **キーの写像としては正しい**。`settingsSchema.ts` の `general`（L186）配下に `plan`（L319）があり、その `directory`（L338）。**ただし同じ L338 の description が「A custom directory requires a policy to allow write access in Plan Mode.」と書いており、`"./plans"` はカスタム値に当たる。**policy が要るかどうか自体は依然 U**（description 以上の裏取りが取れていない）。ただし **2026-08-22に判明した制約により、要ったとしてもリポジトリからは配れない**: policy engine の **Workspace 層（プロジェクト単位の `.gemini/policies`）は現在無効**で、置いても効果がゼロである（`docs/reference/policy-engine.md` L126–L130 の WARNING、優先度表 L144 の **(Currently disabled)**、upstream issue #18186）。**必要な場合の受け皿は User/Admin 層しかなく、それは利用者の手作業になる** | S（キー） / U（policyの要否） / **S**（Workspace層が無効であること） |
| `if` 条件 | あり（4エントリ） | **無い**（2エントリへ集約済み） | **正しい**。hook definition は `matcher` / `sequential` / `hooks` のみ。**下記「`if` の畳み込みで落ちるもの」参照** | D |
| `permissions` | `defaultMode` / `deny` | **無い** | **誤り。相当機能はある**（当初「無い」と断定していたのを訂正する）。`deny` 相当は **policy engine** で、`docs/reference/policy-engine.md` に `commandRegex = "git (commit\|push)"`（L325）＋ `decision = "deny"`（L33）があり、**`run_shell_command` のコマンド文字列に対する正規表現での拒否がそのまま書ける**。同 L112–L123 は「`deny` がツール除外の推奨手段であり `excludeTools` は内部的にdenyルールへ変換される」とも書いている。`defaultMode` 相当は `settingsSchema.ts` L228 の `defaultApprovalMode`（`'plan'` を値に持つ。L244）。**ただし置き場所は `settings.json` ではなく `.gemini/policies/*.toml`**。**そして2026-08-22に、その置き場所が現在は機能しないことが確定した**: Workspace 層は **(Currently disabled)** であり（`docs/reference/policy-engine.md` L126–L130・L144、upstream issue #18186）、リポジトリへ `.gemini/policies/*.toml` を置いても**効果がゼロ**である。**したがって `permissions` を policy engine へ写像しないのは「選ばなかった」からではなく「今は動かない」から**である | D（policy engine） / S（`defaultApprovalMode`） / **S**（Workspace層が無効であること） |
| `name` | 無し | あり（`session-start` 等） | **正しい**。`name` は任意フィールド（ログ・CLIでの識別用） | D |
| SessionStart matcher（`compact` の除去） | `startup\|resume\|clear\|compact` | `startup\|resume\|clear` | **正しい**。`source` は `"startup" \| "resume" \| "clear"` の3値のみで、`compact` は無い（`docs/hooks/reference.md` L249） | D |
| SessionStart matcher（縦棒つなぎの有効性） | — | `startup\|resume\|clear` | **誤り（2026-08-22に一次ソースで確定）**。`hookPlanner.ts` の `matchesContext` は、`context.toolName` があれば `new RegExp(matcher).test(toolName)`（正規表現）、`context.trigger` があれば `matcher === trigger`（**完全一致**）と判定を使い分ける。SessionStart は `fireSessionStartEvent` が `{ trigger: source }` を渡す（`hookEventHandler.ts` L183）ため**完全一致**であり、縦棒つなぎはどの `source` にも一致せず**hookが一度も発火しない**。**対処は `matcher` を省略すること**（`!entry.matcher` は無条件 `true` = 全ソースで発火）。Claude側が全4値＝全ソースを覆っているため、省略が等価かつ最短である | **S** |

**issue #70 が挙げた10観点のうち8つでは、現行の手書き `.gemini/settings.json` は正しかった。**
残る2つ（`permissions` / SessionStart matcher の縦棒つなぎ）は上表のとおり**どちらも誤り**である（縦棒つなぎは当初「未確認」としていたが、2026-08-22に一次ソースで**無効**と確定した。下記「5・6・7 の結果」）。

**「10観点で正しい」から「ゴールデンファイルにできる」へは、そのままでは進めない。** 前者は
issue #70 が列挙した観点の網羅であり、後者は**変換元の全キーが写像先に説明できていること**を
要求する別の主張だからである。実際、次の3つは10観点の外にあり未判定のまま残っている。

| 10観点の外にあるもの | 状態 |
|---|---|
| `.claude/settings.json` の `autoCompactWindow: 600000` | 表のどの行にも現れず、`.gemini` 側にも無い。落としてよいのか、Gemini に相当設定があるのかが**未判定** |
| `PostToolUse` の**グループ構造**（2グループ → 1グループへの併合） | `mcp__github__issue_write` が落ちている（上表） |
| `.gemini` 側 `AfterTool` の**エントリ数**（3） | `if` 行の「2エントリへ集約済み」という記述と数が合わない |

**したがってフェーズ3では、ゴールデンファイルとして採用する前に「`.claude/settings.json` の
全キーを写像先へ対応づけた表」をキー単位で作り、網羅を確かめる。** 期待値が正しいことに全面依存
する方式なので、未判定を抱えたまま固定すると、**変換スクリプトが情報を落としていることを
単体テストが永久に緑で通す。**

### `if` の畳み込みで落ちるもの（機能等価ではない）

`.claude` 側は `post-push-usage-report.sh` / `post-push-compact-prompt.sh` を
**`if: "Bash(git push*)"` が真のときだけ**起動する。Gemini には `if` が無いため、
**`run_shell_command` のたびに毎回この2本が起動する。**

**ただし実害は限定的である**（**R**: スクリプトを読んで確認）。両スクリプトは自身でも
`tool_input.command` を再チェックしており（`post-push-usage-report.sh` の
`command_invokes_git_subcommand` 呼び出し）、pushでなければ即 `exit 0` する。
スクリプト冒頭のコメントも「`if` フィルタはベストエフォートのため、本スクリプト側でも念のため
command 文字列を再チェックする」と明記している。

**落ちるのは正しさではなく性能である。** ただし当初「シェル1回あたり約190ms」と見積もっていたのは
**hook 1本＝プロセス1つと数えた誤り**だった（敵対的レビューの指摘により訂正）。早期returnの経路でも、
各hookは `exit` へ到達する前にコマンド置換とjqを回す。`.claude/rules/shell-script-style.md` は
**「コマンド置換 `$(...)`・パイプもサブシェルをforkするため同じコストを持つ」**と明記している。

| 毎回起動するhook | 早期returnまでの外部プロセス | 内訳 |
|---|---|---|
| `post-push-usage-report.sh` | 5 | `$(cat)` L306 / `jq -c .` L310 / `jq -r .agent_id` L314 / `jq -r .tool_name` L323 / `jq -r .tool_input.command` L332 |
| `post-push-compact-prompt.sh` | 5 | 同じ形（L212–L235） |
| `post-issue-create-notice.sh` | 要計測 | **当初の見積もりに入れていなかった3本目。** `.gemini` 側では同じ `AfterTool` グループに同居する |

**したがって上乗せは「2プロセス」ではなく「10プロセス超」の桁**になる。`.claude/rules/shell-script-style.md`
の実測 `jq -nc '1'` = 94.6ms/回（**Windows git bash での値**。この調査環境の値ではない）を当てると、
シェル1回あたり**1秒近く**になりうる。**正確な値はフェーズ3で実測する**（見積もりのまま spec へ
転記しない）。

> **この事実は変換スクリプトのコメントとspecへ必ず書く。** 「等価な変換」と書いてしまうと、
> 将来スクリプト側の自己チェックを外した人が、Gemini 側だけ静かに壊す。

---

## Q4. コピー対象・除外対象と、Git管理下へ置く副作用

### 現状の規模（**M**）

| 指標 | 値 |
|---|---|
| `.claude` 配下のGit管理下ファイル | 148件 |
| うち `.md` | 105件 |
| リポジトリ全体の `.md` | 124件 |
| `.claude` のディスクサイズ | 2.8M |
| `extract-frontmatter.sh .` の所要（差分なし） | 0.603s |

### 除外すべきもの

| 対象 | 扱い | 理由 |
|---|---|---|
| `**/index.jsonl` | **除外** | `.gitignore` 対象の生成物。`.claude/agents/index.jsonl` 等、各ディレクトリに散在する（**M**） |
| `.claude/state/` | **除外** | `.gitignore` 対象のローカル作業状態 |
| `.claude/settings.json` | **コピーしない**（変換して生成する） | Q3の写像対象 |
| `.claude/agents/*.md` | **変換** | Q1 |
| `.claude/skills/` | **コピー** | Q2（変換不要） |
| `.claude/docs/` `rules/` `hooks/` `scripts/` | **コピー** | 現行 `setup-gemini-links.sh` の `TARGETS` と同じ |
| `.claude/scripts/test/` | **要判断**（フェーズ3） | 機構自身の単体テスト。Gemini 実行時には不要だが、除くと `.gemini/scripts/` だけ構成が食い違う |
| `.claude/VERSION` `REVIEW-POINTS.md` | **要判断**（フェーズ3） | 現行のリンク運用では対象外だった |

**除外には性質の違う2種類があり、`.gitignore` だけでは決まらない。** 上表8行のうち
`.gitignore` で決まるのは `**/index.jsonl` と `.claude/state/` の2行だけである。

| 除外の種類 | 対象 | 決め方 |
|---|---|---|
| **生成物・ローカル状態** | `**/index.jsonl` / `.claude/state/` | `.gitignore`（`git check-ignore` で判定可） |
| **役割上の除外** | `settings.json`（変換して生成）/ `agents/*.md`（変換） | 変換規則の側で決める。`.gitignore` とは無関係 |
| **要判断** | `scripts/test/` / `VERSION` / `REVIEW-POINTS.md` | フェーズ3で決める |

**「`git check-ignore` に通せば済む」と読んではいけない。** `.claude/settings.json` は
gitignore対象ではないので、機械的にコピーすると**手書きの正しい写像をコピーが上書きする。**
なお `git check-ignore` をファイルごとに呼ぶとファイル数に比例してforkする
（`.claude/rules/shell-script-style.md`「外部プロセス起動のコスト」）ため、まとめて渡す。

### Git管理下へ置く副作用（**重要**）

| # | 副作用 | 現状 | 対処 |
|---|---|---|---|
| A | `rg` / `grep` / Glob が `.claude` と `.gemini` で**二重ヒット**する | 今は `.gitignore` 対象なので `rg` に出ない | 運用ルールで「`.gemini/` が出たら必ず `.claude/` 側を編集する」と明文化（issue #70 の期待する動作5） |
| B | **`extract-frontmatter.sh` の走査対象がほぼ倍増する** | `git ls-files --cached --others --exclude-standard` で列挙するため、**Git管理下になった瞬間に `.gemini/` 配下も走査対象になる**（**R**: L396） | `.gemini` を明示的に除外する。**これはフェーズ3の必須作業**。除外しないと `.gemini/**/index.jsonl` まで生成される |
| C | `search-frontmatter.sh` の二重ヒット | **既に対処済み**。`SF_EXCLUDED_DIRS='.git node_modules build .gemini'`（**R**: L37） | 除外そのものは正しいまま。**ただし理由のコメント（L32–L36）が嘘になる**ので書き換える。とくに L35–L36 の「ジャンクションは find からは通常のディレクトリに見えるため二重にヒットする」は、リンク運用の廃止で前提ごと成り立たなくなる（**実体が2つあるから二重ヒットする**へ書き換える） |
| D | リポジトリのファイル数・サイズが約2倍 | 148件 / 2.8M | 受け入れる（それが「検索に掛かる」という利点の裏返し） |

> **B は静かに壊れる類の副作用である。** `extract-frontmatter.sh` は失敗しても
> `index.jsonl` が増えるだけで、エラーは出ない。**気づくのは `doc-search` の結果が
> 二重になってからである。**

---

## Q5. 同期の実行位置（flow-id の採番）

### issueの前提が古かった（**決着済み**）

issue #70 は「**現行 flow-id 5-3（片付け）の直前**へ新設」と書くが、**この番号は既にずれていた。**
issue #111（最終統括レポート）が 5-3 を占めたため、調査時点の片付けは 5-4 だった。

**この論点はチャットでのレビューで決着した**（2026-08-22）。ユーザーの指示は
**「flow-id は issue #111 に合わせて」**、続けて**「最終統括レポートの前が良いな」**である。
すなわち、

- 方式は **案A（新規 flow-id を新設し、以降を繰り下げる）**。issue #111 が統括レポートを
  追加したときとまったく同じやり方を採る（当初の推奨だった案Cは**取り下げる**）。
- 挿入位置は **「最終統括レポートの直前」**。issue #70 本文の「5-3（片付け）の直前」は、
  #111 以降の番号へ読み替えたうえで**さらに1つ手前**になる。

| 変更前 | 変更後 | ステップ |
|---|---|---|
| 5-1 | 5-1 | defaultブランチとのコンフリクト検知・解消 |
| 5-2 | 5-2 | 関連issueへのマージ前通知 |
| — | **5-3（新設）** | **`.claude/` → `.gemini/` 変換同期** |
| 5-3 | 5-4 | 最終統括レポート作成とPR/MRへの反映 |
| 5-4 | 5-5 | 片付けとHANDOFF.mdリセット |
| 5-5 | 5-6 | commit・push してDraft解除 |
| 5-6 | 5-7 | マージ |

### この位置を採る理由

1. **生成の直後に確定が来る。** 旧 5-3（統括レポート）は自前で commit・push するステップなので、
   同期で生えた `.gemini/**` はその commit に載る。**同期ステップ自体は commit を持たず、次の
   ステップの commit・push が確定を担う**（片付け → commit と同じ既存パターン）。
   片付けの直前へ挿す案では、生成と commit の間に片付けが挟まっていた。
2. **統括レポートが最終形を記述できる。** `.gemini/` を再生成してからレポートを書くので、
   「このブランチで何が変わったか」に同期結果が含まれる。
3. **5-1 のコンフリクト解消で main から入った `.claude/` の変更を、確実に拾える。**

**この位置は issue #112 の制約を壊さない。** SKILL.md は片付けについて「**このステップを commit の
直前へ置く**のは、生成と確定の間に他のステップを挟まないため」と定めているが、新設ステップは
片付けより前にあるため、片付けと commit は隣接したままである。

> **依存関係**: 同期を片付け（`cleanup-task.sh`）より前に置く以上、**Q4-B の
> 「`extract-frontmatter.sh` に `.gemini` 除外を足す」は必須の前提条件になる。** 片付けは
> `index.jsonl` を再生成するため、除外が無いとその最中に `.gemini/**/index.jsonl` が生える。

### 繰り下げの作業量（**M**）

繰り下げ対象は `5-3` / `5-4` / `5-5` / `5-6` の**4つ**である（片付けの直前へ挿す場合の3つより
1つ多い）。**実測した**（測定環境は冒頭の表）。

```
$ grep -rno "flow-id 5-[3-6]" --include="*.md" --include="*.sh" --include="*.json" . \
    | grep -vE "^\./(\.git|usage|plans|reports|worklog)/|/ddr/|index\.jsonl" \
    | awk -F: '{print $1}' | sort | uniq -c | sort -rn
     28 ./.claude/skills/issue-mr-flow/SKILL.md
     23 ./.claude/docs/spec/issue-mr-workflow.md
     11 ./.claude/rules/docs-workflow.md
      7 ./.claude/scripts/src/vcs/Provider.sh
      6 ./.claude/docs/README.md
      5 ./.claude/rules/git-workflow.md
      5 ./.claude/docs/spec/cleanup-task.md
      3 ./.claude/scripts/src/cleanup-task.sh
      3 ./.claude/rules/directory-structure.md
      2 ./index.md
      2 ./.claude/scripts/src/vcs/Gitlab.sh
      2 ./.claude/scripts/src/vcs/Github.sh
      2 ./.claude/rules/markdown-frontmatter.md
      2 ./.claude/docs/spec/update-handoff-progress.md
      2 ./.claude/docs/spec/extract-frontmatter.md
      1 ./HANDOFF.md
      1 ./.claude/skills/doc-search/SKILL.md
      1 ./.claude/scripts/test/test_vcs_provider.sh
      1 ./.claude/scripts/test/test_update_handoff_progress.sh
      1 ./.claude/scripts/src/update-handoff-progress.sh
      1 ./.claude/docs/spec/create-commit.md
```

**接頭辞 `flow-id ` を伴わない裸の参照**（`HANDOFF.md` の進捗表、`update-handoff-progress.sh` の
`LOOP_RANGES` 定数、`cleanup-task.sh` のコメント等）も数える。数え方を変えただけなので、
**同じ除外条件で `\b5-[3-6]\b` に広げた**。

| 指標 | 実測値 | 数え方 |
|---|---|---|
| `flow-id 5-[3-6]` の出現 | **109箇所 / 21ファイル** | 上のコマンドそのもの |
| 裸の `5-3`〜`5-6` を含む | **226箇所 / 23ファイル** | 上のコマンドの `"flow-id 5-[3-6]"` を `-oE '\b5-[3-6]\b'` に替えたもの |
| うちDDR本文（**変更対象外**） | 84箇所 | 上の除外から `/ddr/` を外したときの増分 |

> **当初この節には「94箇所 / 14ファイル」「広い網 217箇所」と書いていたが、どちらも撤回する**
> （敵対的レビューの指摘による）。前者は直上に貼った実出力の合計（92）と一致せず、後者は
> 数え方を示すコマンドが無く再現できなかった。上の表は**貼ったコマンドの出力から機械的に出る値**に
> 揃えてある。

参考として、issue #111（PR #144 / `e33b468`）は同じ形の繰り下げを**28ファイル**の変更で完了して
いる。今回の規模はこれと同程度である。

### 3案の比較（決定の経緯として残す）

| 案 | 繰り下げ | 長所 | 短所 | 結果 |
|---|---|---|---|---|
| **A. 新規 flow-id** | **発生**（109〜226箇所） | フローの表に同期が明示され、飛ばしにくい。issue #111 に前例があり、やり方が確立している | 更新漏れが1箇所でもあると番号が食い違い、HANDOFF.mdの進捗表と噛み合わなくなる | **採用** |
| B. 片付けへ統合 | 無し | 追加コストが最小 | **責務が違う**。片付けは「タスク固有のファイルを消す」、同期は「`.claude`→`.gemini` を再生成する」。同じスクリプトに入れると `--dry-run` の意味・失敗時の扱いが混ざる | 不採用 |
| C. flow-id を増やさない並行手順 | 無し | 先例が3つある（**PR作成後の追従監視**・**作業開始時のベース追従確認**・**敵対的レビュー**）。いずれも「特定の flow-id に属さない並行手順」として `SKILL.md` に節を持つ | 表に出ないぶん、実施を忘れうる | 不採用（調査時点の推奨だったが、レビューで案Aに決定） |

> 案Cの先例は、当初「4つ」として `REVIEW-POINTS.md` 収集も数えていたが、これは独立した先例では
> なく**敵対的レビューの一部**（`SKILL.md` の敵対的レビュー節から `review-points` スキルへ委譲されて
> いるだけ）だったため、**3つへ訂正した**（敵対的レビューの指摘による）。

### 繰り下げを安全に行うための条件（フェーズ3で守る）

1. **`.claude/docs/ddr/` の本文は書き換えない**（84箇所）。DDRは本文不変であり、当時の番号のまま
   `note` で補足する運用が既にある（`i0028-01` が実例）。
2. **`spec/` の過去issueごとの記録節（changelog）も書き換えない。** `.claude/rules/docs-workflow.md`
   が禁じており、issue #47 では実際に `sed` の一括置換で過去の記録を壊しかけている。
3. **置換後に `git diff <ブランチ分岐点のSHA> -- .claude/` の削除行を確認する**（同ルールが定める
   検証手順）。引数なしの `git diff` は作業ツリー比較のため使わない。

### `--check` の実行位置は未決（フェーズ3の論点）

`--check`（`.claude/` と `.gemini/` が食い違っていたら非0で落とす）を設ける方針は変わらないが、
**どこで走らせるかは決まっていない。**

| 案 | 効果 |
|---|---|
| push前（`create-commit.sh` 等の関門） | 差分があれば**止められる** |
| push後（PostToolUse hook） | 止められないので**気づかせるだけ** |

調査時点の記述はこの2つが同じ節の中で食い違っていた（敵対的レビューの指摘による）。
**flow-id 5-3 が新設されたことで `--check` は「忘れ防止の主役」ではなく補助になった**ため、
どちらを採るかはフェーズ3の個別作業計画で決める。

---

## Q6. 波及範囲（全件・判定付き）

`.gemini` または `setup-gemini-links` に言及する全ファイルを列挙し、**1件ずつ判定した**（**M**）。
本タスクの作業ファイル（`plans/` `worklog/` `HANDOFF.md`）は除く。

**個別調査計画（L129–L133）が定めた検証条件は「判定を書いていない行が無いこと」である。**
初回はその出力に含まれる `.gemini/settings.json`（5件）を表へ入れておらず、**自分で定めた合格条件を
満たしていなかった**（敵対的レビューの指摘により追加）。現在は検証コマンドの出力**19ファイル中19件**を
表がカバーしている。

| ファイル | 件数 | 判定 |
|---|---|---|
| `.claude/scripts/src/setup-gemini-links.sh` | 12 | **削除**（リンク運用の廃止） |
| `.gemini/settings.json` | 5 | **性格が変わる唯一のファイル**。手書きの実体 → 変換の生成物。フェーズ3で次の3点を分けて決める: (1) Git管理下に残すか（残す想定）(2) `--check` の比較対象をどう取るか（**出力とGit管理下の実体が同じファイルだと、`--check` が自分自身を比較する構造になる**）(3) ゴールデンファイルを別に置くか |
| `.claude/scripts/src/search-frontmatter.sh` | 3 | **コメント修正**。`SF_EXCLUDED_DIRS` の `.gemini` は**残す**（二重ヒット防止）。除外理由の説明（**L32–L36**）だけ書き換える |
| `.claude/scripts/test/test_search_frontmatter.sh` | 11 | **要確認**。`.gemini` 除外のテストが「リンクだから」を前提にしていないか。前提だけなら期待値は変わらない |
| `.claude/scripts/src/extract-frontmatter.sh` | 0 | **変更が必要**（言及は無いが、Q4-B のとおり `.gemini` 除外を**新規に**足す）。**言及の grep では出てこないので見落としやすい** |
| `.claude/hooks/post-push-usage-report.sh` | 1 | 変更不要（Gemini CLI経路の集計に関する記述） |
| `.claude/hooks/post-push-compact-prompt.sh` | 1 | 変更不要（同上） |
| `.claude/skills/apply-mr-workflow-to-project/scripts/sync-assets.sh` | 10 | **要変更**。`.gemini/` を丸ごと配布アセットへコピーしている。生成物になるなら**配布先で生成する**か、生成済みを配るかを決める |
| `.claude/skills/apply-mr-workflow-to-project/scripts/install-to-project.sh` | 5 | **要変更**。`safe_copy_dir` で `.gemini` を配置し、`.gitignore` へ `/.gemini/usage-state/` 等を書く |
| `.claude/skills/apply-mr-workflow-to-project/SKILL.md` | 4 | **要変更**（上2件に追随） |
| `.claude/docs/spec/distribution-assets.md` | 1 | **要変更**（配布行の定義） |
| `.claude/docs/spec/issue-mr-workflow.md` | 9 | **要変更**（フロー仕様。Q5の結論に追随） |
| `.claude/docs/spec/search-frontmatter.md` | 2 | **要変更**（除外理由） |
| `.claude/rules/directory-structure.md` | 3 | **要変更**（`.gemini/` の位置づけを「リンク」から「生成物」へ） |
| `README.md` | 3 | **要変更**（clone後の手順） |
| `index.md` | 2 | **要変更**（Repository Map） |
| `.gitignore` | 9行 | **削除**。パス5行（L30–L34 `/.gemini/{docs,hooks,rules,scripts,skills}`）**だけでなく、その上のコメントブロック4行（L26–L29）も消す。** コメントは廃止した `setup-gemini-links.sh` の実行を案内しており、残すと嘘の手順になる |
| `.claude/docs/ddr/i0000-13-…` | 17 | **frontmatterのみ**（`status: superseded` / `superseded_by: "i0070-01"`）。**本文は変更しない** |
| `.claude/docs/ddr/i0003-01-…` | 7 | **変更しない**（本文不変。`.gemini/settings.json` のhooks方針を決めたDDR。内容は今も有効） |
| `.claude/docs/ddr/i0023-01 / i0038-01 / i0057-01 / i0063-01 / i0097-01 / i0097-03 / i0097-05` | 各1〜2 | **変更しない**（本文不変） |

### `.gitignore` に潜んでいた別の欠陥（**M**。本issueのスコープ外）

`.gitignore` のコメントが**存在しないDDRファイル名**を指している。

```
# .claude/docs/ddr/i00-13-gemini配下は…       ← 実際は i0000-13-
# .claude/docs/ddr/i36-01-frontmatterの…      ← 実際は i0036-01-
```

issue #133 の一括改番（4桁ゼロ埋め）のときに、コメント内の参照が**ゼロ埋め前の形で取り残された**
ものと見られる。

**当初「1件目（`i00-13`）は `.gitignore` の該当行を消すので自動的に消える」と書いていたが、これは
誤りだった**（敵対的レビューの指摘により訂正）。`i00-13` を含むのは L26–L29 の**コメントブロック**で
あって、削除対象に挙げていたパス5行（L30–L34）ではない。上の表の判定を**9行削除**へ直したことで、
1件目は実際に消えるようになった。**2件目（`i36-01`）は残る。** 本issueの差分に含めるか別issueに
するかは、フェーズ4で判断する。

---

## 設計への反映（フェーズ3で何が決まったか）

| 決まったこと | どこに効くか |
|---|---|
| agents の変換は**ホワイトリスト方式**（許可キーだけ通す） | `sync-gemini-assets.sh` の中核。ブラックリストにすると将来壊れる |
| ツール名は**11種の対応表**で変換し、**未知の名前はエラーにする** | 同上。黙って落とさない。**対応表の網羅性そのものを単体テストで固定する**（表に無い＝Geminiに無い、ではないため） |
| `model` は**除去**する（`inherit` へ委ねる） | 同上。要フェーズ3レビュー |
| `tools` は**YAML配列**として出力する | 同上 |
| skills は**変換不要**、コピーのみ | 変換対象を1つ減らせる |
| 現行の手書き `.gemini/settings.json` は **issue #70 の10観点のうち8つで正しい**（`permissions` と SessionStart matcher の**2つが誤り**。後者は2026-08-22に確定） | **そのままではゴールデンファイルにできない。** 先に `.claude/settings.json` の全キーを写像先へ対応づける |
| `permissions.deny` に**相当する機能は Gemini にもある**（policy engine の `commandRegex` + `decision = "deny"`）。**ただし置き場所である Workspace 層は現在無効**（2026-08-22確定。upstream issue #18186） | 写像しない理由は「選ばなかった」ではなく**「リポジトリに置いても動かない」**と書く。コミット強制の多重防御がGemini経路だけ1枚になる点は変わらない |
| `if` の畳み込みは**機能等価ではない**（性能が落ちる） | specとコメントへ明記する |
| **`extract-frontmatter.sh` に `.gemini` 除外を足す**必要がある | Q4-B。grepでは見つからない、見落としやすい作業 |
| `search-frontmatter.sh` の除外は**残し、理由コメントだけ直す** | Q6 |
| 同期の実行位置は**新規 flow-id 5-3（最終統括レポートの直前）**。案A（繰り下げ）で決着 | Q5。チャットでのレビューで決定済み |

## 未確認のまま残ったこと（受け入れ条件の未達候補）

1. **変換後の agents が実際にロードできること**（Gemini CLI が無い）
2. **変換後の settings.json の hook が発火すること**（同上）
3. **`model` に与えるべき具体的なモデル名**（網羅リストが公式ドキュメントに無い。除去で回避する）
4. **issueのエラー添字 `tools.0` と、現行ファイルの `tools` が文字列である事実の食い違い**
   （報告時の環境が不明。方針には影響しない）
5. ~~**SessionStart の `matcher` で縦棒つなぎが有効か**~~ → **決着（2026-08-22）。無効。**
   `matcher` を省略する（下記「5・6・7 の結果」）
6. ~~**`${GEMINI_PROJECT_DIR}` が未解決だったときの挙動**~~ → **決着（2026-08-22）。プレースホルダが
   そのまま残る**（空文字にならない）。かつ実運用では未定義になる経路が実質無い（同上）
7. ~~**`general.plan.directory` のカスタム値に policy が要るか**~~ → **半分決着（2026-08-22）。**
   policy の要否そのものは未確認のままだが、**要ったとしてもリポジトリからは配れない**ことが
   確定した（Workspace 層が無効。同上）
8. **policy engine を変換範囲に含めるか**（`.gemini/policies/*.toml` は `settings.json` の外にあり、
   本issueのスコープに入れるかどうかがフェーズ3の論点）

**1・2 は「ユーザーのローカル環境での確認」に委ねるか、別issueへ切り出す。**
フェーズ3では、代わりに**変換の入出力を単体テストで固定する**（ゴールデンファイル比較・冪等性・
`--check` の終了コード）。

### 5・6・7 の結果（フェーズ3・flow-id 3-6 で追加取得。2026-08-22）

既存クローン（`5411f113`）の sparse-checkout へ `packages/core/src/hooks` と
`packages/cli/src/utils` を追加して確認した。**クローンし直していない**（本レポートが引用して
いる行番号がずれるため）。**3件とも一次ソースで確定した（S）。うち2件は見立てと違った。**

| # | 結論 | 一次ソース |
|---|---|---|
| 5 | **縦棒つなぎは無効。** ライフサイクル系イベントの matcher は完全一致（`matcher === trigger`）で、ツール系だけが正規表現。**対処は「単一値で複数エントリ登録」ではなく `matcher` の省略**（無指定は全ソースで発火し、Claude側の4値＝全ソースと等価） | `hookPlanner.ts` の `matchesContext` / `matchesToolName` / `matchesTrigger`、`hookEventHandler.ts` L183、`types.ts` L607 |
| 6 | **未解決ならプレースホルダの文字列がそのまま残る**（空文字にならず、ルート相対パスへ暴走しない）。`${VAR:-DEFAULT}` 記法も使える。加えて hook 実行時は `GEMINI_PROJECT_DIR` が必ず注入されるため、**未定義になる経路は実質無い** | `packages/cli/src/utils/envVarResolver.ts` の `resolveEnvVarsInString`、`hookRunner.ts` L350・L527 |
| 7 | **policy の要否そのものは未確認のまま。** ただし **Workspace 層（プロジェクト単位の `.gemini/policies`）が現在無効**であることが確定したため、**要ったとしてもリポジトリからは配れない**。受け皿は User/Admin 層＝利用者の手作業しかない | `docs/reference/policy-engine.md` L126–L130 の WARNING、優先度表 L144、upstream issue #18186 |

**取得先の見立てが1件外れていた。** 6 の取得先を「`packages/core/src/config/settings.ts` の
`resolveEnvVarsInObject`」と書いていたが、`settings.ts` は `packages/cli/src/config/` にあり、
実体は `packages/cli/src/utils/envVarResolver.ts` だった。

#### 5 の結果が写像表に与えた影響

**当初のフォールバック案（`matcher` を単一値で複数エントリ登録）は採らない。** `matcher` の省略で
足りるうえ、Gemini がソースを増やしても追随が要らないためである。ただし**変換規則としては
一般形で書く**: Claude の `matcher` を `|` で分割し、Gemini の enum 値の集合と突き合わせて、
**全体を覆うなら `matcher` を落とし、部分集合なら値ごとにエントリを複製する**。今回は前者に当たる。

#### 7 の結果が B（policy engine の扱い）に与えた影響

**B-1（本issueのスコープ外とする）の根拠が変わる。** 「変換しないと決めた」のではなく
**「今のGemini CLIでは、リポジトリに置いた policy が動かない」**が正確である。フェーズ4で
spec へ理由を書く際は、upstream issue #18186 を根拠として書く。

**8（policy engine を変換範囲に含めるか）は引き続きフェーズ3の論点として残す**（こちらは
一次情報の不足ではなく、スコープの判断のため）。
