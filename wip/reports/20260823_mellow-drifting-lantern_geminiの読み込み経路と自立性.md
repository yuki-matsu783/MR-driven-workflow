---
title: Gemini CLI の読み込み経路と .gemini/ に残すもの（調査結果）
type: report
description: Q7・Q8・Q10・Q11 の実測結果。Gemini CLI の読み込み経路を公式ドキュメントで確定し、4ディレクトリを外した場合に切れるリンクが1件だけであることを実測した
tags: [report, gemini, sync-gemini-assets, 調査]
keywords: [読み込み経路, skills, agents, agents-skills, 壊れたリンク, 1件, 依存の明示, GEMINI.md, 配布, 実測]
---

# Gemini CLI の読み込み経路と .gemini/ に残すもの（調査結果）

計画: `wip/plans/【調査】geminiの読み込み経路と自立性.md`（issue #172 / PR #193 / フェーズ2の2回目）。
**この調査では判断も実装もしていない。** 判断はフェーズ3。

## サマリ（結論の一覧）

| # | 結論 | 根拠の性質 |
|---|---|---|
| 1 | **Gemini CLI が `.gemini/` から読むのは `settings.json` `skills/` `agents/` `commands/*.toml` `sandbox-*` の5種。** `rules/` `docs/` `hooks/` `scripts/` は公式ドキュメントに記載が無い | 公式ドキュメントの読解（Q7） |
| 2 | **`.agents/skills/` エイリアスは Claude Code 側が対応していない。** Gemini CLI は見るが、Claude Code の公式ドキュメントには**0件**の言及しかなく、探索先は `~/.claude/skills/` `.claude/skills/` `<plugin>/skills/` の3つと明記されている | 公式ドキュメントの読解（Q7） |
| 3 | **現在の `.gemini/skills/` は Gemini CLI の要件を満たす。** 9件すべてが `name`・`description` を持ち、`name` はディレクトリ名と一致する（9/9） | 実測（Q8） |
| 4 | **`.gemini/agents/` も変換済みで要件を満たす。** `tools` が Gemini CLI の語彙（`read_file` 等）へ変換され、Claude Code 固有キー（`model`・`type`・`tags` 等）は落ちている | 実測（Q8） |
| 5 | **4ディレクトリ（`hooks/` `scripts/` `docs/` `rules/`）を外すと、壊れたリンクは1件だけになる。** 3つだけ外す場合の18件から**17件減る** | 実測（Q10） |
| 6 | **その1件は `.gemini/skills/apply-mr-workflow-to-project/SKILL.md` → `../../docs/spec/sync-gemini-assets.md`** で、**Gemini CLI が実際に読むファイルの中**にある | 実測（Q10） |
| 7 | **4ディレクトリは 184ファイル・2,676,979バイト**（`.gemini/` 全体の85.6% / 84.7%）。`rules/` は8ファイル・189,256バイトで、1回目は測っていなかった | 実測（Q10） |
| 8 | **依存を明示する記録先として、配布先の Gemini CLI セッションへ実際に届くのは `GEMINI.md` だけ。** `README.md`・`DEVELOPERS.md` は `layer: exclude` で配布されず、spec は配布されるが実行時には読まれない | 実測（Q10） |
| 9 | **`install-to-project.sh` に `.gemini/` の生成をスキップするオプションは無い。** Claude Code しか使わない配布先でも常に生成される | 実測（Q11） |
| 10 | **Gemini CLI しか使わない配布先でも `.claude/` は消せない。** `.claude` は `layer: core`、`AGENTS.md` は `seed` で、どちらも常に配られる | 実測（Q11） |
| 11 | **すべて公式ドキュメントの読解と生成物の実測であり、Gemini CLI 実機は一度も動かしていない** | 制約 |

## 実施条件（測った対象・環境）

- 実行環境: Claude Code on the web（Linux）／2026-08-23。**git bash（Windows）実機では未計測**。
- 対象リビジョン: ブランチ `claude/gemini-exclude-decision-yp5p70` の **f98860b**（ベース `origin/main` = 0a9169c）。
- 公式ドキュメントの取得元: `https://raw.githubusercontent.com/google-gemini/gemini-cli/main/docs/…`（main ブランチ）と
  `https://code.claude.com/docs/en/skills`。**取得時点は 2026-08-23**で、以降の変更は追随していない。
  `google-gemini.github.io` は egress proxy にブロックされたため raw 経由で取得した。
- **1回目の調査（`…参照実態.md`）の値のうち、Q4（3ディレクトリ除去時の18件）は本調査で再現できた**
  （下記 Q10）。同じ数え方で4ディレクトリ版を測っているので、両者は直接比較できる。

## 実施した内容と結果

### Q7: Gemini CLI の読み込み経路

**`.gemini/` から読むもの**（`docs/reference/configuration.md`・`docs/cli/skills.md`・
`docs/cli/custom-commands.md`・`docs/reference/commands.md`）:

| パス | 根拠（引用） |
|---|---|
| `.gemini/settings.json` | 「Project settings are located at `.gemini/settings.json` within your project's root directory」 |
| `.gemini/skills/` | 「**Workspace skills**: Located in `.gemini/skills/` or the `.agents/skills/` alias.」 |
| `.gemini/agents/` | 「Rescans agent directories (`~/.gemini/agents` and `.gemini/agents`) and reloads the registry.」 |
| `.gemini/commands/*.toml` | 「**Project commands:** Located in `<your-project-root>/.gemini/commands/`」 |
| `.gemini/sandbox-*.sb` / `sandbox.Dockerfile` | 「a project's `.gemini` directory can contain other project-specific files … `.gemini/sandbox-macos-custom.sb`, `.gemini/sandbox.Dockerfile`」 |

**`rules/` `docs/` `hooks/` `scripts/` は、上記4ファイルのどこにも現れない。**

#### skills の探索と注入のされ方

`docs/cli/skills.md`「How it works」より。

1. **Discovery**: セッション開始時に、**name と description だけ**をシステムプロンプトへ注入する
2. **Activation**: description に合致するタスクで `activate_skill` を呼ぶ
3. **Consent**: ユーザーへ確認プロンプトが出る
4. **Injection**: 承認後、**`SKILL.md` の本文とフォルダ構成**が会話履歴へ入り、そのディレクトリが読み取り許可へ加わる

**つまり `.gemini/skills/` は「置いてあるだけ」ではなく、毎セッション必ず一部が読まれる。**

#### `.agents/skills/` エイリアス（論点3）

- **Gemini CLI 側は対応している。** 「You can use `.agents/skills` as an alternative to
  `.gemini/skills`. This alias is compatible with other AI agent tools following the
  Agent Skills standard.」（`docs/cli/creating-skills.md`）。同一ティア内では
  **`.agents/skills/` が `.gemini/skills/` より優先**される。
- **Claude Code 側は対応していない。** 公式ドキュメント（`code.claude.com/docs/en/skills`）を
  取得して `.agents` を検索した結果は**0件**。探索先は次の3つと明記されている。

  | レベル | パス |
  |---|---|
  | Personal | `~/.claude/skills/<skill-name>/SKILL.md` |
  | Project | `.claude/skills/<skill-name>/SKILL.md` |
  | Plugin | `<plugin>/skills/<skill-name>/SKILL.md` |

**したがって「`.agents/skills/` へ一本化して二重管理をやめる」は成立しない。** そこへ移すと
Claude Code からスキルが見えなくなる。**ただしこれは「ドキュメントに記載が無い」ことによる
判断であり、未文書の対応がある可能性は否定できない**（記載が無い機能に依存はできない、という
形の結論である）。

#### `context.fileName` で `AGENTS.md` を直接読ませられるか

`docs/reference/configuration.md` の `context.fileName` は「The name of the context file or
files to load into memory. Accepts either a single string or an array of strings.」で、
**既定は `undefined`（＝`GEMINI.md`）**。`["AGENTS.md", "GEMINI.md"]` のような配列を
設定すれば `GEMINI.md` を介さずに `AGENTS.md` を読ませられる。
探索は `context.memoryBoundaryMarkers`（既定 `[".git"]`）で上方向に止まる。

### Q8: 現在の `.gemini/skills/` `.gemini/agents/` はそのまま使えるか

**SKILL.md の必須 frontmatter は `name` と `description` の2つ**（`docs/cli/creating-skills.md`
「Metadata and triggers」。`name` は「This should match the directory name」）。

| 検査 | 結果 |
|---|---|
| `name` を持つ | **9/9** |
| `description` を持つ | **9/9** |
| `name` がディレクトリ名と一致 | **9/9** |

**追加の変換は不要。** `.claude/skills/*/SKILL.md` は Claude Code 用の追加キー
（`title`・`type`・`tags`・`keywords`）を持つが、Gemini CLI は必須2キーを見るだけなので、
余分なキーがあっても問題にならない（`sync-gemini-assets.sh` が skills を**素通しでコピー**して
いるのは、この意味で妥当である）。

`.gemini/agents/*.md`（2本）は変換済みで、`tools` が Gemini CLI の語彙へ置き換わっている。

```
.claude/agents/adversarial-reviewer.md   tools: Read, Grep, Glob, Bash   + model/title/type/tags/keywords
.gemini/agents/adversarial-reviewer.md   tools: [read_file, grep_search, glob, run_shell_command]
```

### Q10: 依存の明示と、読まれない複製の扱い（主軸）

#### Q10-1: `.gemini/` の内訳（`rules/` とトップレベルを新規に実測）

| 対象 | ファイル数 | バイト数 |
|---|---:|---:|
| `hooks/` | 14 | 217,308 |
| `scripts/` | 47 | 813,984 |
| `docs/` | 115 | 1,456,431 |
| **`rules/`（新規）** | **8** | **189,256** |
| `skills/` | 24 | 448,686 |
| `agents/` | 2 | 18,532 |
| **トップレベル（新規）** | **5** | **15,751** |
| **合計** | **215** | **3,159,948** |

`.gemini/` 全体の直接計測（215 / 3,159,948）と一致する。トップレベルの内訳は
`REVIEW-POINTS.md`(7,406)・`dist-layers.json`(6,341)・`settings.json`(1,841)・
`settings.local.json.example`(157)・`VERSION`(6)。

| 除去する範囲 | 外れるファイル数 | 割合 | 外れるバイト数 | 割合 |
|---|---:|---:|---:|---:|
| 3ディレクトリ（`hooks/` `scripts/` `docs/`） | 176 | 81.9% | 2,487,723 | 78.7% |
| **4ディレクトリ（＋ `rules/`）** | **184** | **85.6%** | **2,676,979** | **84.7%** |
| 読まれるものだけ残す（`settings.json`＋`skills/`＋`agents/`） | 188 | 87.4% | 2,690,889 | 85.2% |

#### Q10-2: 4ディレクトリを外した場合に切れるリンク（再測定）

1回目の Q4 は**3つ**を外した場合の値なので使えない。同じ数え方で両方を測り直した。

| 除去する範囲 | 解決先が除去対象のリンク総数 | **壊れたリンクとして残る**（リンク元が生き残る） |
|---|---:|---:|
| 3ディレクトリ | 304 | **18**（`rules/`→`docs/` 17、`skills/`→`docs/` 1） |
| **4ディレクトリ** | 314 | **1**（`skills/`→`docs/` のみ） |

**1回目の18件（内訳 `rules/` 17・`skills/` 1）を正確に再現した**ので、両者は同じ尺度である。

**計画の見立ては正しかった。** `rules/` を外すと、その17件は**リンク元ごと消える**ので
「壊れたリンク」ではなくなる。**4つ外すほうが3つ外すより軸2の被害が小さい**（18 → 1）。

残る1件は次の1箇所である。

```
.gemini/skills/apply-mr-workflow-to-project/SKILL.md
  → ../../docs/spec/sync-gemini-assets.md
```

**この1件は性質が違う。** リンク元の `.gemini/skills/` は Gemini CLI が実際に読む
（Q7）ので、**「誰も読まないファイルの中の壊れたリンク」ではなく「読まれるファイルの中の
壊れたリンク」**である。1回目・フェーズ3で18件を一括で「読まれないファイルの中」と
扱っていた前提は、この1件には当てはまらない。

#### Q10-3: 依存を明示する記録先の候補

「Gemini CLI 利用時も `.claude/` は必須」をどこへ書くか。**配布されるか**と
**Gemini CLI セッションで読まれるか**の2軸で並べる。

| 候補 | 層 | 配布先へ配られるか | Gemini CLI が読むか |
|---|---|---|---|
| **`GEMINI.md`** | `core` | **配られる** | **読まれる**（ルートの context file） |
| `AGENTS.md` | `seed` | 配られる | `GEMINI.md` の `@./AGENTS.md` 経由で読まれる |
| `.claude/docs/spec/sync-gemini-assets.md` | `core`（`.claude` 配下） | 配られる | **読まれない**（実行時の経路が無い） |
| `.gemini/` 側の案内ファイル | — | 生成される | **読まれない**（`skills/` `agents/` `settings.json` 以外は経路が無い） |
| `README.md` / `DEVELOPERS.md` | **`exclude`** | **配られない** | 読まれない |
| `index.md` | `seed` | 配られる | 読まれない |

**配布先の Gemini CLI セッションへ実際に届くのは `GEMINI.md`（と、その import 先の
`AGENTS.md`）だけである。** spec は「後から読む人」には届くが、実行時には届かない。
`README.md` は `layer: exclude` なので**配布先には存在しない**——ここへ書いても本家しか読めない。

現在の `GEMINI.md` は「プロジェクト固有のルールは `.claude/rules/<名前>.md` へ置く」と
書いており、**`.claude/` の存在を暗に前提にしているが、依存そのものは明示していない**。

### Q11: 配布への影響

#### Q11-1: ルート直下ファイルの帰属

| ファイル | 層 | どの配布先へ配られるか |
|---|---|---|
| `CLAUDE.md` | `core` | **常に** |
| `GEMINI.md` | `core` | **常に** |
| `AGENTS.md` | `seed` | **常に**（初回のみ、以降は配布先所有） |
| `.claude` | `core` | **常に** |
| `.gemini` | `exclude` | **配られない**（配布先で生成する） |
| `index.md` `.mrworkflow.json` `HANDOFF.md` | `seed` | 常に |
| `README.md` `DEVELOPERS.md` | `exclude` | 配られない |

**CLI ごとの出し分けは存在しない。** Claude Code しか使わない配布先にも `GEMINI.md` が配られ、
Gemini CLI しか使わない配布先にも `CLAUDE.md` と `.claude/` 一式が配られる。

#### Q11-2: 片方のCLIしか使わない配布先

| 方向 | 成立するか | 根拠 |
|---|---|---|
| **Claude Code のみ** | **`.gemini/` を生成しない選択肢は無い** | `install-to-project.sh` のオプションは `--dry-run` `--force` `--allow-dirty` `-h` の4つだけで、手順7は無条件に `sync-gemini-assets.sh` を呼ぶ。手で消しても再適用のたびに再生成される |
| **Gemini CLI のみ** | **`.claude/` は消せない** | `.claude` が `layer: core`、`AGENTS.md` が `seed` で常に配られる。加えて `.gemini/settings.json` の hook 6本が `$GEMINI_PROJECT_DIR/.claude/hooks/…` を指し、`GEMINI.md` → `@./AGENTS.md` → `@./.claude/rules/agent-common.md` を辿る |

#### Q11-3: 手順7の失敗時の挙動（1回目の結論7の再確認）

`install-to-project.sh:905-923` を読み直した。**失敗しても中断しない設計は意図的**で、
その理由がコメントに記録されている（「ここに到達した時点で core / seed / merge の配置は済んで
おり、`.gemini/` が無いこと以外は完了している。中途半端な状態で止めるほうが害が大きい」）。
警告は標準エラーへ出るが、**installer の終了コードは 0 のまま**である。

## 確かめられなかったこと

- **Gemini CLI 実機の挙動は一度も観測していない。** Q7 はすべて公式ドキュメントの読解である。
  ドキュメントと実装が食い違う可能性は残る。
- **`.agents/skills/` を Claude Code が本当に読まないかは、実機で確かめていない。**
  公式ドキュメントに記載が無いことを確認しただけである（記載が無い＝未対応、とは論理的には
  言えないが、**未文書の挙動に依存する設計は採れない**）。
- **`.gemini/rules/` が読まれないことは、依然として「記載が無い」だけ**で、読まれないという
  証拠ではない。`hooks/` `scripts/` `docs/` も同じ性質である。
- **配布先での再適用は実行していない。** Q11 は `install-to-project.sh` と `dist-layers.json` を
  読んで導いた。
- **git bash（Windows）実機での確認はしていない。** 件数・バイト数は Linux 1環境のものである。
- **`commands/*.toml` を持つ配布先が実在するかは調べていない。** 1回目の結論7が挙げた
  「自前の `.gemini/commands/*.toml`」は仕様上ありうるという話で、実例は確認していない。

## 設計への反映

**この調査では判断していない。** フェーズ3で次を決める。

1. **論点2（読まれない4ディレクトリの扱い）。** 材料は結論5〜7。**4つ外すほうが3つ外すより
   軸2の被害が小さい（18→1）**という、フェーズ3の判断を変えうる結果が出ている。
2. **論点3（`.agents/skills/`）。** 結論2により**成立しない**。この根拠を記録して閉じる。
3. **依存の明示先。** 結論8により `GEMINI.md` が唯一の実効的な経路である。

フェーズ4では次を記録する。

4. **論点1の決着（自立化しない理由）**を spec と新規DDR `i0172-01` へ。
5. **フェーズ3レポートの訂正3件**（結論5-2・結論6・軸2の18件の性質）。
6. **`install-to-project.sh` に `.gemini/` 生成のスキップ手段が無いこと**を、現行の制約として
   記録するか別issueにするか。

---

正文はこの md 側。人間レビュー用のビューは同名の `.html`。issue #172 / PR #193。
