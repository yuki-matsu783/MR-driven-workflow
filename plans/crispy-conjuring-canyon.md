---
title: 計画ツール利用ルールの安定化（全体作業計画＋個別作業計画への再編）
type: plan
description: Planモード（planツール）の利用を「issue全体の作業計画1回」に限定し、以降のフェーズ別計画をplans/配下の個別ファイルへ分離するための調査計画・作業計画
tags: [plan-mode, issue-mr-flow, workflow, plans]
keywords: [planツール, ExitPlanMode, 全体作業計画, 個別作業計画, タスク種別, re-entry, archive-reentrant-plan, worklog命名, 35ステップ, core.quotepath]
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
- **ハーネス挙動を実地確認し、DDR 0009 の観測が現在も有効であることを確定した**（flow-id 15で観測）。
  本セッションで2回目の `EnterPlanMode` を実行したところ、ハーネスは**1回目と同じパス**
  （`plans/crispy-conjuring-canyon.md`）を提示し、新しいパスは割り当てられなかった。
  issue #7 時点の観測はツール仕様変更後の現在も有効である。
- **ただし、現行フローではこの制約が実害になっていない**という重要な事実も判明した。
  issue #43 で「調査計画・調査結果・作業計画は別ファイルに分けず、既存の `plans/<plan名>.md` に
  **章立てで含める**」と決めたため、flow-id 4 と flow-id 15 は**そもそも同じファイルへの追記**で
  あり、ハーネス提示パスと追記先が完全に一致する。つまり `archive-reentrant-plan.sh` が
  本当に必要なのは「**同一セッションで別タスクの計画を新規に立てる**」場合に限られる。
  今回の再編で「全体作業計画はブランチにつき1回」と規定すれば、そのケース自体が発生しなくなる。

#### 結果7: Gemini CLI・他プロジェクト展開

- **Gemini CLIにもplan機構がある**（`.gemini/settings.json` の `general.plan.directory`）。
  Claude Code と同じ前提でルールを書ける見込み。
- `apply-mr-workflow-to-project`: `install-to-project.sh:140,165` が `plans/` と `.gitkeep` を作成。
  `SKILL.md:63` が `archive-reentrant-plan.sh` を配布対象として明記しているため、**廃止する場合は
  この2ファイルの更新も必要**。

## 作業計画

### 確定事項

調査結果とレビュー・ユーザー確認により、以下が確定した。

| 項目 | 確定内容 |
|---|---|
| **全体作業計画** | planツール（Planモード）で作成。**issue（ブランチ）につき1回**。判定基準は「現在のブランチに既に全体作業計画があればPlanモードを利用しない」。ファイル名はハーネス自動命名のまま（例: `plans/crispy-conjuring-canyon.md`） |
| **個別作業計画** | `plans/【種別】タスク内容.md`。**planツールは使わず**Write/Editで作成 |
| **タスク種別** | `【調査】`『`【設計】`』`【実装】`『`【テスト】`』`【設計反映】`『`【AIアセット改善】`』の6種。**複数併記可**（例: `【実装】【テスト】XXX.md`） |
| **囲み文字** | 全角 `【】`。ASCII `[]` は不採用（glob文字クラス解釈でマッチしないため） |
| **worklog命名** | `worklog/日付_全体計画名_個別計画名_push<N>.md` |
| **reports命名** | `reports/日付_全体計画名_<内容を簡潔に>.html`。調査結果専用ではなく、設計・実装・AIアセット反映等の報告にも使える位置づけへ拡張 |
| **フロー構造** | 33 → **35ステップ**（先頭に全体作業計画の作成・合意の2ステップを追加。commitは既存ステップに相乗り） |
| **re-entry対策** | 廃止（`plan-mode-safety.md`規則6・`archive-reentrant-plan.sh`）。DDRは本文不変のため新規DDRで記録 |

**個別計画の機械的な判別**: `plans/【*.md` で個別作業計画のみを抽出でき、それ以外（`【`で始まらない
ファイル）が全体作業計画になる。この区別は実機検証済みで、`get_branch_work_files` の結果に対して
そのまま適用できる。

### 新フロー（35ステップ）の対応関係

先頭に2ステップを挿入するため、**旧flow-id N（N≧4）は新flow-id N+2 へスライド**する。

| 新flow-id | ステップ | 担当 |
|---|---|---|
| 1〜3 | （変更なし）issue起票 → 取得 → ブランチ・Draft MR作成 | 人間 / `start` |
| **4** | **【新設】全体作業計画をPlanモードで作成**（ブランチに既存があれば作成せずPlanモードを抜け、既存を読む） | エージェント |
| **5** | **【新設】全体作業計画に合意** | 人間 |
| 6 (旧4) | 個別作業計画 `plans/【調査】〜.md` を**Write/Editで**作成（planツール不使用）。worklogもここで作成 | エージェント |
| 7〜16 (旧5〜14) | 調査サイクル（合意 → commit → レビュー → describe → 調査実施 → …） | — |
| 17 (旧15) | 個別作業計画 `plans/【設計】【実装】〜.md` を**Write/Editで**作成 | エージェント |
| 18〜35 (旧16〜33) | 作業サイクル → 設計反映 → クリーンアップ → マージ | — |

これに伴い、各所のflow-id参照を機械的に更新する必要がある。

- ループ範囲: 7〜8→**9〜10**、10〜14→**12〜16**、18〜19→**20〜21**、21〜25→**23〜27**、26〜30→**28〜32**
- commitポイント: 6/11/17/22/28/32 → **8/13/19/24/30/34**
- レビュー完了合図の確認: 8・14・19・25・30 → **10・16・21・27・32**
- 「PRがflow-id 31実施前にマージされた場合の対処」→ **flow-id 33**

### 実装ステップ

#### ステップ1: フロー定義の改訂

- `.claude/skills/issue-mr-flow/SKILL.md`（**主対象**）
  - 全体フロー表を35ステップへ再構成（上表のとおり）
  - 新flow-id 4に「**既にブランチ上に全体作業計画があればPlanモードで新規作成しない**」判定を明記
  - flow-id 6/17 を「planツールを使わずWrite/Editで `plans/【種別】〜.md` を作成」へ書き換え
  - flow-id 12/16 のreports記述を新命名・新位置づけ（調査専用でない）へ更新
  - flow-id 33 のクリーンアップ対象・「マージされてしまった場合の対処」節のflow-id更新
  - 上記のループ範囲・レビュー完了合図の確認節のflow-id列挙を更新

#### ステップ2: ルール群の更新

| ファイル | 変更内容 |
|---|---|
| `.claude/rules/plan-mode-safety.md` | **全面改訂**。規則6（re-entry手順）を削除し、「planツールは全体作業計画にのみ使う／ブランチに既存があれば使わない」という新方針へ。規則2の archive例外記述も削除 |
| `.claude/rules/docs-workflow.md` | ドキュメント運用表の `plans/` `worklog/` `reports/` の行を新命名・新定義へ。ループ範囲の例示と「33ステップ」→「35ステップ」 |
| `.claude/rules/directory-structure.md` | ツリー内の `plans/` `worklog/` の説明を新命名へ |
| `.claude/rules/git-workflow.md` | commitポイントのflow-id列挙 |
| `.claude/skills/commit/SKILL.md` | frontmatter `description` と本文のflow-id列挙（2箇所） |
| `.claude/skills/canvas-report/SKILL.md` | `reports/<plan名>.html` → 新命名。「調査結果報告用」という限定を拡張 |
| `worklog/TEMPLATE.md` | ヘッダコメント・`plan:` 行を新命名へ |
| `AGENTS.md` | 「計画はplansディレクトリ配下にセッション単位で保存する」→ 全体/個別の2階層構造の説明へ |
| `index.md` | `plans/` `worklog/` の説明 |

#### ステップ3: スクリプト修正とre-entry対策の廃止

- **`.claude/scripts/src/vcs/Provider.sh`（必須のバグ修正）**: `get_branch_work_files`
  （261-262行）の `git diff --name-only` / `git status --porcelain` に
  **`-c core.quotepath=false` を付ける**。日本語ファイル名が8進エスケープで返り、
  `resume` / `issue-mr-resume` が壊れるのを防ぐ。安全な実装例は
  `.claude/scripts/src/extract-frontmatter.sh:206` の `git ls-files -z`
- `.claude/scripts/src/archive-reentrant-plan.sh` を**削除**
  （`tests/` はこのテンプレートリポジトリに同梱されていないため、テスト削除は不要）
- `.claude/skills/apply-mr-workflow-to-project/SKILL.md:63` から `archive-reentrant-plan.sh` を除去
- `.claude/docs/README.md` のDDR 0009 の行に、廃止された旨の注記を検討

#### ステップ4: HANDOFF.md の扱い（注意）

`HANDOFF.md` のフロー進捗表（現在33行）の**35行化は、本タスクのクリーンアップ時
（新flow-id 33）に行う**。本タスク自身が現行33ステップ運用で進行中のため、途中で表を
差し替えると自分の進捗と食い違うため（issue #43 が旧23→33ステップ化で採った措置と同じ）。

#### ステップ5: 設計反映（flow-id 28で実施）

- `.claude/docs/spec/issue-mr-workflow.md` に新方式を反映
- **新規DDR**を追加（`0019`〜）: 「planツール利用を全体作業計画1回に限定し、個別計画はファイル分離する」
  という決定と、DDR 0009 の方式を廃止した経緯を記録する。**DDR 0009 の本文は変更しない**

### 検証方法

実行可能なコードの変更は `Provider.sh` のみのため、検証は以下で行う。

1. **`Provider.sh` の構文チェック**: `bash -n .claude/scripts/src/vcs/Provider.sh`
2. **`get_branch_work_files` の実機確認**: 全角種別を含むダミーファイル
   （`plans/【調査】検証用.md` 等）を作業ツリーに置き、修正前は8進エスケープ・修正後は生パスが
   返ることを実際に比較する（scratchpadではなく本リポジトリで一時的に作成し、確認後に削除）
3. **ドキュメント整合性**: 新旧flow-id対応表をもとに、`grep -rn "flow-id"` で全参照箇所を洗い出し、
   更新漏れがないことを確認する
4. **`archive-reentrant-plan.sh` の参照残り確認**: `grep -rn "archive-reentrant"` で、削除後に
   参照が残っていないことを確認する（DDR 0009 本文は不変のため残るのが正しい）

## 対象外（このタスクのスコープ外）

- **本タスク自体の進行は現行の33ステップフローに従う**（新35ステップフローの適用は、変更が
  マージされた次のタスクから）。`HANDOFF.md` の進捗表の35行化もクリーンアップ時に行う
- `.claude/docs/ddr/0009` の**本文修正**（DDRは一度マージしたら不変。廃止の経緯は新規DDRで記録する）
- `.claude/hooks/*.sh` のヘッダコメントが削除済みplanファイルを参照している運用矛盾（調査1の
  副次的発見）。別issueとして扱う
- `tests/` の整備（このテンプレートリポジトリには同梱されていない）

## 完了条件

- 調査1〜7に結論がついていること（**完了**。flow-id 13〜14 のレビューで合意済み）
- 上記「作業計画」のステップ1〜3が実装され、「検証方法」の4項目を満たすこと
- 設計反映（新規DDR・spec更新）が flow-id 28 で行われること
