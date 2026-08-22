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

**根拠の強さを3段階で明示する。** 以下の表の「根拠」列は次の意味である。

| 記号 | 意味 |
|---|---|
| **S**（source） | Gemini CLI のソースコードを読んで確定。**バリデーション実装そのもの**なので、その版では確実 |
| **D**（docs） | 公式ドキュメントの記述。実装と食い違う可能性が残る |
| **M**（measured） | このリポジトリ上で実際にコマンドを流して測った |
| **U**（unverified） | 確かめていない。推測 |

**この調査で U のまま残ったもの**（フェーズ3で潰せないものは受け入れ条件の未達として扱う）:

- 変換後の `.gemini/agents/*.md` を Gemini CLI が実際にロードできること
- 変換後の `.gemini/settings.json` の hook が Gemini CLI 実行時に発火すること
- `model` に与えるべき具体的な Gemini モデル名（ドキュメントに網羅リストが無い）

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

- `search_file_content` は `grep_search` のレガシー別名として**今も受理される**（`TOOL_LEGACY_ALIASES`）。
  ただし**新規に出力する側が別名を使う理由は無い**ので、正名の `grep_search` を出す。
- **対応表に無いClaudeツール名（`Task` / `TodoWrite` / `NotebookEdit` 等）が現れたら、変換スクリプトは
  黙って落とさずエラーにする。** 黙って落とすと、Gemini 側のエージェントが必要な権限を失ったまま
  静かに動く。現行2ファイルは上表の4種しか使っていない（**M**）が、将来増える。

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
- 現行 `.claude/skills/*/SKILL.md` 全9件が `name` を持つことを確認した（**M**）。

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
| matcher | `Bash\|PowerShell` | `run_shell_command\|Bash\|PowerShell` | **正しい**。matcherは正規表現でツール名に照合される。Gemini の実ツール名は `run_shell_command` | D |
| コマンド指定 | `command` + `args[]` | 単一シェル文字列 | **正しい**。Geminiの hook configuration は `type` / `command` / `name` / `timeout` / `description` のみで、**`args` は無い** | D |
| timeout | 秒（`30` / `10` / `20`） | ミリ秒（`30000` / `10000` / `20000`） | **正しい**。「Execution timeout in milliseconds (default: 60000)」 | D |
| 環境変数 | `${CLAUDE_PROJECT_DIR}` | `${GEMINI_PROJECT_DIR}` | **正しい**。ただし**シェル変数**として展開される（`docs/hooks/index.md` L140「`GEMINI_PROJECT_DIR`: The absolute path to the project root」）。設定ファイル側の補間ではなく、`command` がシェルで実行される際の展開である | D |
| plans設定 | `plansDirectory` | `general.plan.directory` | **正しい**。`settingsSchema.ts` の `general`（L186）配下に `plan`（L319）があり、その `directory`（L338） | S |
| `if` 条件 | あり（4エントリ） | **無い**（2エントリへ集約済み） | **正しい**。hook definition は `matcher` / `sequential` / `hooks` のみ。**下記「`if` の畳み込みで落ちるもの」参照** | D |
| `permissions` | `defaultMode` / `deny` | **無い** | **正しい**。Gemini に**コマンド文字列パターンでの拒否**に相当する設定は無い（`excludeTools` はツール単位で、粒度が違う） | S |
| `name` | 無し | あり（`session-start` 等） | **正しい**。`name` は任意フィールド（ログ・CLIでの識別用） | D |
| SessionStart matcher | `startup\|resume\|clear\|compact` | `startup\|resume\|clear` | **正しい**。`source` は `"startup" \| "resume" \| "clear"` の3値のみ。`compact` は無い | D |

**10項目すべてで、現行の手書き `.gemini/settings.json` は正しい。** したがって
**この手書き版を、変換スクリプトの期待値（ゴールデンファイル）としてそのまま単体テストに固定できる。**
これはフェーズ3にとって大きい——「変換規則が正しいか」を人間の判断ではなく差分で確かめられる。

### `if` の畳み込みで落ちるもの（機能等価ではない）

`.claude` 側は `post-push-usage-report.sh` / `post-push-compact-prompt.sh` を
**`if: "Bash(git push*)"` が真のときだけ**起動する。Gemini には `if` が無いため、
**`run_shell_command` のたびに毎回この2本が起動する。**

**ただし実害は限定的である**（**M**: スクリプトを読んで確認）。両スクリプトは自身でも
`tool_input.command` を再チェックしており（`post-push-usage-report.sh` の
`command_invokes_git_subcommand` 呼び出し）、pushでなければ即 `exit 0` する。
スクリプト冒頭のコメントも「`if` フィルタはベストエフォートのため、本スクリプト側でも念のため
command 文字列を再チェックする」と明記している。

**落ちるのは正しさではなく性能である。** シェル呼び出しのたびにプロセスが2つ余分に起動する。
`.claude/rules/shell-script-style.md`「外部プロセス起動のコスト」の実測値（git bashで約95ms/回）を
当てると、**シェル1回あたり約190msの上乗せ**になる。

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

**除外は「`.gitignore` に載っているか」で機械的に決められる。** `git check-ignore` を使えば
除外リストを二重管理せずに済む。

### Git管理下へ置く副作用（**重要**）

| # | 副作用 | 現状 | 対処 |
|---|---|---|---|
| A | `rg` / `grep` / Glob が `.claude` と `.gemini` で**二重ヒット**する | 今は `.gitignore` 対象なので `rg` に出ない | 運用ルールで「`.gemini/` が出たら必ず `.claude/` 側を編集する」と明文化（issue #70 の期待する動作5） |
| B | **`extract-frontmatter.sh` の走査対象がほぼ倍増する** | `git ls-files --cached --others --exclude-standard` で列挙するため、**Git管理下になった瞬間に `.gemini/` 配下も走査対象になる**（**M**: L396） | `.gemini` を明示的に除外する。**これはフェーズ3の必須作業**。除外しないと `.gemini/**/index.jsonl` まで生成される |
| C | `search-frontmatter.sh` の二重ヒット | **既に対処済み**。`SF_EXCLUDED_DIRS='.git node_modules build .gemini'`（**M**: L37） | 除外そのものは正しいまま。**ただし理由のコメント（L32–34「リンクだから」）が嘘になる**ので書き換える |
| D | リポジトリのファイル数・サイズが約2倍 | 148件 / 2.8M | 受け入れる（それが「検索に掛かる」という利点の裏返し） |

> **B は静かに壊れる類の副作用である。** `extract-frontmatter.sh` は失敗しても
> `index.jsonl` が増えるだけで、エラーは出ない。**気づくのは `doc-search` の結果が
> 二重になってからである。**

---

## Q5. 同期の実行位置（flow-id の採番）

### issueの前提が古い

issue #70 は「**現行 flow-id 5-3（片付け）の直前**へ新設」と書くが、**この番号は既にずれている。**
issue #111（最終統括レポート）が 5-3 を占めたため、**現在の片付けは 5-4** である。

| 現行 | ステップ |
|---|---|
| 5-1 | コンフリクト検知・解消 |
| 5-2 | 関連issue通知 |
| 5-3 | **最終統括レポート**（issue #111 で挿入） |
| 5-4 | **片付け**（`cleanup-task.sh`） |
| 5-5 | commit・push・Draft解除 |
| 5-6 | マージ |

issueが見積もった「29ファイル・161箇所」も、この挿入を経て変わっている。**実測した**（**M**）。

```
$ grep -rno "flow-id 5-[3-6]" --include="*.md" . | grep -v "/ddr/" \
    | awk -F: '{print $1}' | sort | uniq -c | sort -rn
     28 ./.claude/skills/issue-mr-flow/SKILL.md
     23 ./.claude/docs/spec/issue-mr-workflow.md
     11 ./.claude/rules/docs-workflow.md
      6 ./.claude/docs/README.md
      5 ./.claude/rules/git-workflow.md
      5 ./.claude/docs/spec/cleanup-task.md
      3 ./.claude/rules/directory-structure.md
      2 ./index.md
      2 ./.claude/rules/markdown-frontmatter.md
      2 ./.claude/docs/spec/update-handoff-progress.md
      2 ./.claude/docs/spec/extract-frontmatter.md
      1 ./reports/REVIEW-POINTS.md
      1 ./.claude/skills/doc-search/SKILL.md
      1 ./.claude/docs/spec/create-commit.md
```

| 指標 | 実測値 |
|---|---|
| `flow-id 5-[3-6]` の出現（DDR除く・本タスクの作業ファイル除く） | **94箇所 / 14ファイル** |
| うちDDR内（**本文不変のため更新対象外**） | 18箇所 |
| `flow-id` 接頭辞の無い裸の `5-3` 等も含めた広い網 | **217箇所** |

**94箇所という数字は下限である。** `HANDOFF.md` の進捗表・`update-handoff-progress.sh` の
`LOOP_RANGES` 定数・`cleanup-task.sh` のコメントなど、`flow-id ` という接頭辞を伴わない参照が
別にある（広い網の217箇所との差がそれを示す）。

### 3案の比較

| 案 | 繰り下げ | 長所 | 短所 |
|---|---|---|---|
| **A. 5-4 の直前へ新規 flow-id** | **発生**（94〜217箇所） | フローの表に同期が明示され、飛ばしにくい | 更新漏れが1箇所でもあると番号が食い違い、**HANDOFF.mdの進捗表と噛み合わなくなる**。過去にissue #112・#111 で2回繰り下げており、DDR `i0028-01` は当時の番号のまま `note` で補足する運用になっている（＝**繰り下げは既に負債を生んでいる**） |
| **B. 片付け（5-4）へ統合** | 無し | 追加コストが最小。`cleanup-task.sh` が既に「タスク終わりの機械的処理」を担う | **責務が違う**。片付けは「タスク固有のファイルを消す」、同期は「`.claude`→`.gemini` を再生成する」。同じスクリプトに入れると、`--dry-run` の意味・失敗時の扱いが混ざる |
| **C. flow-id を増やさない並行手順** | 無し | 既に4つの先例がある（`REVIEW-POINTS.md` 収集・**PR作成後の追従監視**・**作業開始時のベース追従確認**・**敵対的レビュー**）。いずれも「特定の flow-id に属さない並行手順」として `SKILL.md` に節を持つ | 表に出ないぶん、実施を忘れうる。**`--check` をpush前に必ず通す仕組みで補う必要がある** |

### 推奨: **C（並行手順）**

理由は3つ。

1. **このリポジトリには既に確立した前例がある。** `SKILL.md` は「PR作成後のdefaultブランチ追従（監視）」
   節で「**本節は、その間の追従を特定のflow-idに属さない並行手順として定める（flow-idは増やさない）**」と
   明示し、DDR `i0088-01` がその判断を記録している。同じ性質（**タスクの進行と直交する、状態を揃える
   作業**）を持つ本件を、別扱いにする理由が無い。
2. **繰り下げのコストが、得られるものに見合わない。** 94〜217箇所の更新は、1箇所の漏れが
   進捗表の不整合として跳ね返る。issue #70 自身も「繰り下げを避けたい場合の代案」を用意している。
3. **忘れる問題は、番号ではなく `--check` で解く。** 案Aでも「ステップを飛ばす」ことは起きる
   （進捗記号を `[x]` にするのは人間／AIである）。**`--check` を各pushの直後に走らせ、差分が
   あれば非0で落とす**ほうが、番号を1つ増やすより確実である。

**ただしこれは推奨であって決定ではない。** flow-id を増やすかはフローの見え方に関わる判断なので、
**フェーズ3の個別作業計画のレビューで人間の合意を取る。**

---

## Q6. 波及範囲（全件・判定付き）

`.gemini` または `setup-gemini-links` に言及する全ファイルを列挙し、**1件ずつ判定した**（**M**）。
本タスクの作業ファイル（`plans/` `worklog/` `HANDOFF.md`）は除く。

| ファイル | 件数 | 判定 |
|---|---|---|
| `.claude/scripts/src/setup-gemini-links.sh` | 12 | **削除**（リンク運用の廃止） |
| `.claude/scripts/src/search-frontmatter.sh` | 3 | **コメント修正**。`SF_EXCLUDED_DIRS` の `.gemini` は**残す**（二重ヒット防止）。除外理由の説明（L32–34）だけ書き換える |
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
| `.gitignore` | 5行 | **削除**（`/.gemini/{docs,hooks,rules,scripts,skills}`） |
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
ものと見られる。`.gitignore` の該当行は本issueで**削除する**ため1件目は消えるが、**2件目
（`i36-01`）は残る。** 本issueの差分に含めるか別issueにするかは、フェーズ4で判断する。

---

## 設計への反映（フェーズ3で何が決まったか）

| 決まったこと | どこに効くか |
|---|---|
| agents の変換は**ホワイトリスト方式**（許可キーだけ通す） | `sync-gemini-assets.sh` の中核。ブラックリストにすると将来壊れる |
| ツール名は**9種の対応表**で変換し、**未知の名前はエラーにする** | 同上。黙って落とさない |
| `model` は**除去**する（`inherit` へ委ねる） | 同上。要フェーズ3レビュー |
| `tools` は**YAML配列**として出力する | 同上 |
| skills は**変換不要**、コピーのみ | 変換対象を1つ減らせる |
| 現行の手書き `.gemini/settings.json` は**10項目すべて正しい** | **ゴールデンファイルとして単体テストに固定できる** |
| `if` の畳み込みは**機能等価ではない**（性能が落ちる） | specとコメントへ明記する |
| **`extract-frontmatter.sh` に `.gemini` 除外を足す**必要がある | Q4-B。grepでは見つからない、見落としやすい作業 |
| `search-frontmatter.sh` の除外は**残し、理由コメントだけ直す** | Q6 |
| 同期の実行位置は**案C（並行手順）を推奨**、決定はレビューで | Q5 |

## 未確認のまま残ったこと（受け入れ条件の未達候補）

1. **変換後の agents が実際にロードできること**（Gemini CLI が無い）
2. **変換後の settings.json の hook が発火すること**（同上）
3. **`model` に与えるべき具体的なモデル名**（網羅リストが公式ドキュメントに無い。除去で回避する）
4. **issueのエラー添字 `tools.0` と、現行ファイルの `tools` が文字列である事実の食い違い**
   （報告時の環境が不明。方針には影響しない）

**1・2 は「ユーザーのローカル環境での確認」に委ねるか、別issueへ切り出す。**
フェーズ3では、代わりに**変換の入出力を単体テストで固定する**（ゴールデンファイル比較・冪等性・
`--check` の終了コード）。
