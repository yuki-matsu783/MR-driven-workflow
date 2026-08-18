---
title: 計画ツール利用ルールの安定化（全体作業計画＋個別作業計画への再編）
type: plan
description: Planモード（planツール）の利用を「issue全体の作業計画1回」に限定し、以降のフェーズ別計画をplans/配下の個別ファイルへ分離するための調査計画
tags: [plan-mode, issue-mr-flow, workflow, plans]
keywords: [planツール, ExitPlanMode, 全体作業計画, 個別作業計画, タスク種別, re-entry, archive-reentrant-plan, worklog命名, 33ステップ]
---

# 計画ツール利用ルールの安定化（全体作業計画＋個別作業計画への再編）

対応issue: [#9](https://github.com/yuki-matsu783/MR-driven-workflow/issues/9)

## Context

planツール（Claude CodeのPlanモード＝`EnterPlanMode`/`ExitPlanMode`）の利用箇所がまちまちで、
挙動が安定していない。現状、計画の作られ方に少なくとも3系統が混在する。

- planツールで計画を立てる（ハーネスが提示するパスへ書く）
- `plans/` 配下に新しい計画ファイルを直接作る
- planツールで作成したファイルを後から `Edit` で更新する

根本原因は、**Claude Code / Gemini CLI がセッションごとに1つのplanファイルしか割り当てない**仕様に
ある。現行の33ステップフローは flow-id 4（調査計画）と flow-id 15（作業計画）の**2回** Planモードを
使う設計のため、同一セッションで作業すると2つ目の計画がハーネス提示パス（＝1つ目の計画ファイル）へ
書き込まれ、計画が混ざる。この構造的な衝突に対して、これまでは回避策を積み増してきた。

- `.claude/rules/plan-mode-safety.md` 規則6（re-entry時の手順）
- `.claude/scripts/src/archive-reentrant-plan.sh`（旧計画を `_pushN` へ退避）
- `.claude/docs/ddr/0009-Planモードre-entry時はgit checkout復元でなくarchiveスクリプトで対処する.md`

issue #9 が求めるのは、この回避策の積み増しではなく**構造そのものの是正**である。

- **全体作業計画**: planツールで作成する。issue全体をどう進めるか（何を調査し何を実装するか）の
  全体像であり、**セッション冒頭の1回のみ**。
- **個別作業計画**: `plans/` 配下に `[タスク種別]タスク内容.md` という命名の個別ファイルとして
  作成する。**planツールは使わない**（Editで直接作る）。

この形にできれば、planツールの利用が1セッション1回に限定され、re-entry問題は構造的に消える。
ユーザー確認により、既存のre-entry対策（規則6・archiveスクリプト・DDR 0009）は
**不要になれば廃止してよい**方針が確定している。

受け入れ条件「各ユースケースごとに規定した流れで作業が進むこと」を満たすには、単に命名規則を
決めるだけでは足りず、**どのユースケースでどの計画がいつ作られ誰が合意するか**をフローとして
規定し直す必要がある。影響は `issue-mr-flow/SKILL.md`・`.claude/rules/` 4ファイル・
`HANDOFF.md`・`AGENTS.md`・spec/DDR・スクリプト・テストに及ぶ広範な変更になるため、実装に
着手する前に調査で論点を潰す。

## 調査

### 調査の目的

作業計画（flow-id 15）に着手する前に、以下を確定させる。

1. 変更対象となる「plan」言及箇所の全体像と、その分類
2. plan名を基準にした命名連鎖（worklog/reports）を、個別計画が複数ある前提でどう再設計するか
3. `[タスク種別]` として許す値の集合と、ファイル命名の技術的な安全性
4. 再編後の33ステップフローの形（ステップの増減・各ステップの担当）
5. ユースケースごとの計画作成フロー（受け入れ条件に直結）
6. 既存re-entry対策を廃止した場合の残存リスク
7. Gemini CLI・他プロジェクト展開への波及

### 調査項目

#### 調査1: 「plan」言及箇所の棚卸しと分類

リポジトリ内で `plan` に言及するGit管理下ファイルは37件ある。これらを、語が指す対象で3分類し、
変更要否を判定する。分類しないまま一括置換すると、無関係な箇所（`.claude/hooks/` 内の
`transcript_path` 等の偶然の一致）まで巻き込む。

- **A. planツール機構**（Planモード・`ExitPlanMode`・re-entry）: `plan-mode-safety.md`,
  `CLAUDE.md`, `AGENTS.md`, `archive-reentrant-plan.sh`, DDR 0009
- **B. `plans/` ディレクトリ・計画ファイル**: `docs-workflow.md`, `directory-structure.md`,
  `index.md`, `.mrworkflow.json`, `Provider.sh`（`plansDir`/`get_branch_work_files`）,
  `issue-mr-resume.md`, `worklog/TEMPLATE.md`
- **C. フロー上の「計画」という概念**: `issue-mr-flow/SKILL.md`（flow-id 4/5/15/16 等）,
  `HANDOFF.md` の進捗表

**成果物**: 対象ファイル×分類×変更要否の一覧表。

#### 調査2: plan名を基準にした命名連鎖の依存関係

現行は `plans/<plan名>.md` が**1タスク1ファイル**である前提に立ち、そのファイル名が他の成果物の
命名基準になっている。個別計画が複数ファイルになるとこの前提が崩れるため、依存箇所を洗い出し、
何を基準に命名し直すかを決める。

| 依存先 | 現行の命名・参照 |
|---|---|
| `worklog/` | `日付_<plan名>_push<N>.md`（`docs-workflow.md`, `git-workflow.md`, `TEMPLATE.md`） |
| `reports/` | `<plan名>.html`（`docs-workflow.md`, SKILL.md flow-id 10/14） |
| `archive-reentrant-plan.sh` | `<base>_pushN.md`・worklogの `*_<base>.md` glob |
| `describe` サブコマンド | 「現在のブランチに対応する `plans/<plan名>.md` を読む」 |
| `get_branch_work_files`（`Provider.sh:251-262`） | ディレクトリ単位（ファイル名非依存のため影響小の見込み） |
| `issue-mr-resume` エージェント | ブランチ固有のplans/worklog/reportsファイルを列挙 |

**確定させる論点**: worklog・reportsを紐づける基準を「全体作業計画名」「個別計画名」
「ブランチ名」のどれにするか。個別計画ごとにworklogを分けるか、ブランチで1本にまとめるか。

#### 調査3: タスク種別の定義とファイル命名の技術的安全性

- `[タスク種別]` に許す値の集合を、現行フローのフェーズ（調査／実装／設計反映／レビュー対応 等）
  から導出する。値を固定列挙にするか、ガイドラインに留めるか。
- **ファイル名に角括弧 `[]` と日本語を使うことの技術的影響を実機確認する**。
  - bashのglob（`[]` は文字クラスとして解釈される。`find_worklog_file` の
    `"${worklog_dir}"/*"_${base}.md"` のようなパターン、`get_branch_work_files` の
    `git diff --name-only` 等）
  - `git`・`jq`・Windowsパス・GitHub上でのURL表示
  - この確認を怠ると、命名規則を決めた後にglob由来の不具合を踏む。

#### 調査4: 再編後のフロー設計案

現行33ステップに「全体作業計画」をどう組み込むかを設計する。

- 全体作業計画ステップの位置（flow-id 4の置き換えか、その前段に新設か）
- 現行の調査サイクル（flow-id 4〜14）・作業サイクル（flow-id 15〜25）と個別計画の対応関係
- 個別計画が複数になった場合、レビュー合意（flow-id 5/16）とMR descriptionの更新（`describe`）を
  どの単位で回すか
- ステップ数の増減と、`HANDOFF.md` 進捗表・`docs-workflow.md` のループ範囲記述への波及

**成果物**: 再編後のフロー表（案）と、現行33ステップとの対応表。

#### 調査5: ユースケース洗い出し（受け入れ条件に直結）

受け入れ条件「各ユースケースごとに規定した流れで作業が進むこと」に対応する。想定ユースケースを
洗い出し、それぞれで「どの計画が・いつ・誰の合意で」作られるかを表にする。

- 新機能追加（調査あり）／バグ修正（調査省略可）／調査のみで終わるタスク
- ごく小さな変更（フロー自体を省略してよいもの。`git-workflow.md` の適用範囲）
- レビュー指摘対応で計画の変更が必要になった場合
- 複数セッションにまたがる作業（`resume` での再開時、既存の全体作業計画をどう扱うか。
  **新セッションではハーネスが新しいplanファイルパスを提示するため、ここが最大の論点**）

#### 調査6: 既存re-entry対策を廃止した場合の残存リスク

- 規則6・`archive-reentrant-plan.sh`・`tests/test_archive_reentrant_plan.sh`・DDR 0009 の去就
- **ハーネスの実挙動確認**: Planモードへ再突入した際に本当に同じパスが提示され続けるか、
  新セッションでは新しいパスが割り当てられるかを、実際の挙動として確認する
  （DDR 0009 は issue #7 時点の観測。ツール仕様は変わりうる）
- 廃止した場合に「うっかりre-entryした」ケースで何が起きるか（既存の全体作業計画が失われるか）

#### 調査7: Gemini CLI・他プロジェクト展開への波及

- **Gemini CLIにPlanモード相当の機構があるか**。無い場合、「全体作業計画をplanツールで作る」という
  規定をGemini CLI側でどう読み替えるか（`.gemini/settings.json`・`GEMINI.md`）
- `apply-mr-workflow-to-project` スキル・`install-to-project.sh`（他プロジェクトへの展開）が
  plan関連ファイルをどう扱っているか

### 調査方法

- 上記A/B/C分類は `git ls-files` + `grep` による全件走査で洗い出す
- ファイル名の技術的安全性（調査3）は、scratchpad上に実際のファイルを作って実機検証する
  （glob・git・jqの挙動は推測せず実行して確かめる）
- ハーネス挙動（調査6）は、公式ドキュメント参照と、このセッション自身の観測記録の両面で確認する

### 成果物

- 本ファイル `plans/crispy-conjuring-canyon.md` の「調査」章へ調査結果を追記
- `reports/crispy-conjuring-canyon.html`（自己完結HTML）。本調査は「ルール・スキル・スクリプト
  相互の参照・依存関係」が主題であるため、`.claude/skills/canvas-report/SKILL.md` の
  **canvas形式**（ノード・エッジ表現）の利用を第一候補とする
- `worklog/<日付>_crispy-conjuring-canyon.md` へ試行錯誤を記録

### 調査結果

#### 結果1: 「plan」言及箇所の棚卸し（37ファイル）

`git ls-files | xargs grep -ril plan` の全件を分類した結果、**実際に変更が必要なのは13ファイル**で、
残りは「削除済みplanファイルへの設計コメント参照」など変更不要なものだった。

| 分類 | ファイル | 変更要否 |
|---|---|---|
| **A. planツール機構** | `.claude/rules/plan-mode-safety.md`（30件）, `.claude/scripts/src/archive-reentrant-plan.sh`（30件）, `tests/test_archive_reentrant_plan.sh`, `CLAUDE.md`, `AGENTS.md`, DDR 0009, `.claude/docs/README.md` | **要**（廃止・改訂の主対象） |
| **B. plans/ディレクトリ** | `.claude/settings.json`（`plansDirectory`）, `.gemini/settings.json`（`general.plan.directory`）, `.claude/rules/docs-workflow.md`, `directory-structure.md`, `index.md`, `.mrworkflow.json`, `Provider.sh`, `worklog/TEMPLATE.md` | **要** |
| **C. フロー上の概念** | `.claude/skills/issue-mr-flow/SKILL.md`（22件）, `HANDOFF.md`, `.claude/agents/issue-mr-resume.md`, `.claude/docs/spec/issue-mr-workflow.md` | **要** |
| **D. 偶然の一致・過去参照** | `.claude/hooks/*.sh` の設計コメント（`# 設計: plans/xxx.md`）, `Github.sh`/`Gitlab.sh` の`(plan作成中)`定型文, `canvas-report`, `extract-frontmatter.md`, 各`index.jsonl` | 原則不要 |

**副次的な発見（D分類）**: `.claude/hooks/*.sh` のヘッダコメントは
`# 設計: plans/jazzy-giggling-crescent.md（issue #3）` のように**flow-id 31で削除済みのplanファイル**を
参照しており、参照先が既に存在しない。planの寿命（push単位で削除）と、コード内の恒久的な参照が
噛み合っていない既存の運用矛盾。今回のスコープ外だが、AIアセット改善（flow-id 27）の候補。

#### 結果2: plan名を基準にした命名連鎖

`plans/<plan名>.md` が1タスク1ファイルである前提が、以下に波及していることを確認した。

| 依存先 | 実装箇所 | 個別計画が複数になった場合の影響 |
|---|---|---|
| `worklog/` | `日付_<plan名>_push<N>.md` | **要再設計**。個別計画ごとに分けるか、ブランチで1本にまとめるか |
| `reports/` | `<plan名>.html` | **要再設計**（同上） |
| `archive-reentrant-plan.sh` | worklog探索glob `*"_${base}.md"` | 廃止すれば影響消滅 |
| `describe` | 「`plans/<plan名>.md` を読む」 | **要改訂**（複数ファイルを読む必要） |
| `get_branch_work_files` | `Provider.sh:261-262` | ディレクトリ単位のため**ファイル名非依存**。ただし結果3の別問題あり |
| `issue-mr-resume` | 上記の出力を列挙 | 同上 |

#### 結果3: ファイル命名の実機検証（最重要）

scratchpadに `plans/[調査]既存plan運用の棚卸し.md` 等を実際に作成して検証した。

**(a) bashのglob — 角括弧 `[]` は使わず全角囲み文字を採用する（レビュー指摘で確定）**

| パターン | 結果 |
|---|---|
| `for f in plans/*.md` | ✅ 正常にマッチ |
| `matches=(worklog/*"_${base}.md")`（変数がクォート済み。`find_worklog_file`の実装） | ✅ 正常にマッチ（1件） |
| `for f in plans/[調査]*.md`（**未クォート**） | ❌ **マッチせず、パターン文字列がそのまま返る** |
| `for f in plans/'[調査]'*.md`（クォート済み） | ✅ 正常にマッチ |
| `for f in plans/【調査】*.md`（**未クォート**） | ✅ **正常にマッチ** |
| `for f in plans/（調査）*.md`（**未クォート**） | ✅ **正常にマッチ** |

ASCIIの `[調査]` はglobの**文字クラス**（`調` または `査` の1文字）として解釈されるため、
タスク種別で絞り込むglobを直感的に書くと動かない。

**→ レビュー指摘（PR #10）により、角括弧 `[]` ではなく全角の囲み文字を使う方針に決定した。**
全角文字はbashのglob特殊文字ではないため、**未クォートのまま `plans/【調査】*.md` と書いても
正しくマッチする**（実機確認済み）。これにより、クォート忘れという落とし穴自体が構造的に消える。

採用する囲み文字は **`【】`（隅付き括弧）** を推奨する。`（）`（全角丸括弧）も同様に動作するが、
全角丸括弧は文中の補足表現としても使われるため、種別ラベルとしての識別性は `【】` の方が高い。
最終的な字種と種別の値の集合は作業計画で確定させる。

**(b) gitのパス出力 — 既存実装が壊れる**

`core.quotepath` の既定値が `true` のため、gitは日本語ファイル名を8進エスケープ＋ダブルクォートで
返す。

```
$ git status --porcelain -- plans
"plans/\343\200\220\350\252\277\346\237\273\343\200\221...md"          ← 使えない
$ git -c core.quotepath=false status --porcelain -- plans
plans/【調査】既存plan運用の棚卸し.md                                     ← 正常
```

**この問題は囲み文字を全角へ変えても解消しない**（原因は角括弧ではなく「非ASCII文字を含むこと」
そのもののため）。全角括弧版でも同じ8進エスケープが起きることを実機で確認済み。したがって
`core.quotepath` 対応は、囲み文字の選択とは独立に必要である。

**`get_branch_work_files`（`Provider.sh:261-262`）は `-c core.quotepath=false` を付けていない**ため、
日本語ファイル名を導入すると、この関数の戻り値が人間にもスクリプトにも使えない文字列になる。
`resume`・`issue-mr-resume`エージェントが依存しているため影響は大きい。**作業計画での修正必須**。

対照的に `extract-frontmatter.sh:206` は `git ls-files -z`（NUL区切り）を使っており、`-z` 指定時は
gitがクォートしない仕様のため**元から安全**。同一リポジトリ内に安全な実装例がある。

**(c) jq — 安全**。`--arg` 経由で角括弧・日本語とも正しく扱えた（`length=19`）。

#### 結果4・5: フロー設計案とユースケース（作業計画で確定させる論点）

**最大の論点＝複数セッションにまたがる場合**。新セッションではハーネスが**新しい**planファイルパスを
提示するため、「全体作業計画はセッション冒頭1回」と規定すると、セッションを跨いだだけで
全体作業計画が2つできてしまう。issue #9の方式でもこれは自動解決しない。

**→ レビュー（PR #10）で以下の方針が承認された。**

**「全体作業計画は*セッション*につき1回」ではなく「*issue（ブランチ）*につき1回」と規定する。**
判定基準は明快で、**現在のブランチに既に全体作業計画があればPlanモードを利用しない**。

- 2セッション目以降は `resume` で既存の全体作業計画を読み、**ハーネスが新たに提示するplanパスは
  使わない**（＝Planモードで新規ファイルを作らない）。
- 既存の全体作業計画の有無は `get_branch_work_files`（ブランチ固有のplansファイルを列挙）で
  機械的に判定できる。
- `.claude/settings.json` の `"defaultMode": "plan"` により新セッションは必ずPlanモードで
  始まるため、「Planモードで始まっても、全体作業計画が既にあれば計画ファイルを作らずに抜ける」
  という運用をルールとして明文化する必要がある。

#### 結果6: 既存re-entry対策の去就

- `.claude/settings.json` の `plansDirectory: "./plans"`、`.gemini/settings.json` の
  `general.plan.directory: "./plans"` により、**両CLIともplanファイルを `plans/` へ生成する**。
  個別作業計画を同じ `plans/` に置くと、ハーネス自動生成ファイルと同居することになる
  （命名で区別は可能）。
- **ハーネス挙動の再確認は flow-id 15 で行う**: 本セッションでは初回`EnterPlanMode`で
  `plans/crispy-conjuring-canyon.md`（新規名）が提示されたところまでを観測済み。再突入時に
  同じパスが提示され続けるか（DDR 0009 のissue #7時点の観測が現在も有効か）は、flow-id 15で
  作業計画を作る際に自然に再突入するため、そこで実地確認して記録する。

#### 結果7: Gemini CLI・他プロジェクト展開

- **Gemini CLIにもplan機構がある**（`.gemini/settings.json` の `general.plan.directory`）。
  Claude Code と同じ前提でルールを書ける見込み。
- `apply-mr-workflow-to-project`: `install-to-project.sh:140,165` が `plans/` と `.gitkeep` を作成。
  `SKILL.md:63` が `archive-reentrant-plan.sh` を配布対象として明記しているため、**廃止する場合は
  この2ファイルの更新も必要**。

## 対象外（この調査計画のスコープ外）

- 実装（ルール・SKILL.md・スクリプトの実変更）は flow-id 15 の作業計画で扱う
- 本タスク自体の進行は**現行の33ステップフロー**に従う（新フローの適用は、変更がマージされた
  次のタスクから）
- `.claude/docs/ddr/0009` の本文修正（DDRは不変。廃止する場合は追記または新規DDRで記録する）

## 検証方法（この調査の完了条件）

- 調査1〜7すべてに結論または「次の作業計画で決める論点」としての整理がついていること
- 調査4のフロー設計案が、調査5で洗い出した全ユースケースを破綻なく通せること
- 調査3のファイル命名について、実機確認の結果（glob等の挙動）が記録されていること
- 上記が `plans/crispy-conjuring-canyon.md` の「調査」章と `reports/` のHTMLに反映され、
  MRレビュー（flow-id 13）で合意されること
