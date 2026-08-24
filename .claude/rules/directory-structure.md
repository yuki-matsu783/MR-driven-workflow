---
alwaysApply: true
title: ディレクトリ構成
type: rule
description: リポジトリのディレクトリ構成と配置方針を定めたルール
tags: [directory-structure, rule]
keywords: [ディレクトリ構成, claude, gemini, 配置方針, wip, plans, worklogs, mrworkflow, always-apply]
---

# ディレクトリ構成

各ディレクトリの役割説明は [index.md](../../index.md)（Repository Map）を正とする。本ファイルは
ツリー構造・配置ルールを扱う（ディレクトリの役割説明を重複記載しない）。

```
./
├── .claude/
│   ├── docs/                  # issue駆動MRワークフロー機構自体の設計ドキュメント
│   │   ├── README.md         # .claude/docs配下の目次
│   │   ├── usecase/           # 「やりたいこと」起点の逆引きユースケース文書（issue #170）
│   │   ├── spec/              # 機能ごとの正史仕様
│   │   └── ddr/                # 意思決定ログ（DDR）
│   ├── rules/                  # AI向け詳細ルール（コーディング規約・ドキュメント運用等）
│   │   └── agent-common.md    # AIエージェント共通ルール。`AGENTS.md`/`CLAUDE.md`/`GEMINI.md`が
│   │                            #   `@import`する実体（issue #26。配布層はcore）
│   ├── skills/                 # `/issue-mr-flow`（唯一の実装フロー定義）等のスキル定義
│   │   ├── issue-mr-flow/assets/  # 計画・レポートのHTMLビューのテンプレート2本（issue #54）
│   │   ├── issue-mr-flow/references/  # SKILL.mdから切り出した参照資料7本（issue #160）
│   │   ├── canvas-report/assets/  # canvas形式レポートのテンプレート
│   │   ├── html-slides/assets/    # 発表用HTMLスライドのテンプレート（issue #168）
│   │   └── html-slides/references/  # スライド構成案JSONのスキーマ（slide-outline.schema.json）
│   ├── agents/                 # サブエージェント定義（issue-mr-flow途中引き継ぎ・スライド構成設計/HTML生成等）
│   ├── scripts/                # AIエージェントが`.claude/skills/*`経由で能動的に実行するスクリプト一式
│   │   ├── src/
│   │   │   ├── check-dist-coverage.sh  # 層分け定義の網羅性検査（追跡ファイル全件が分母。issue #26）
│   │   │   └── vcs/            # GitHub/GitLabの差異を吸収するVCS抽象化層（Provider.sh）
│   │   └── test/               # 副作用の無い純粋ロジックの単体テスト（`test_<対象>.sh`）。
│   │                            #   `passed=N failures=N`を出力し失敗時は終了コード1
│   │                            #   （詳細: `.claude/rules/shell-script-style.md`「テスト」）
│   ├── hooks/                  # SessionStart/PostToolUse等のClaude Code hookスクリプト
│   │   ├── lib/                # 複数hookスクリプトで使い回す共通ロジック
│   │   └── otel/                # OTelリスナー機構（常駐プロセス。詳細: `.claude/docs/spec/otel-listener.md`）
│   │       ├── lib/            # リスナー・フックで使い回す共通ロジック（perlモジュール）
│   │       └── test/           # 本機構専用の単体テスト（下記「配置の指針」参照）
│   ├── REVIEW-POINTS.md       # `.claude/`配下に適用するレビュー観点（`type: review-points`）
│   ├── VERSION                 # 配布物の版（SemVer 1行）。更新規則は`.claude/docs/spec/distribution-assets.md`
│   ├── dist-layers.json        # 配布アセットの層分け定義（core/seed/merge/local/exclude）。**何をどう配るかの単一の正**
│   └── settings.json
├── .gemini/                    # Gemini CLI向け資産。**全体が`.claude/`からの変換生成物**で、
│   │                            # `sync-gemini-assets.sh`が生成する（直接編集しない。Git管理下）
│   ├── agents/                 # frontmatterをGemini CLIのlocalAgentSchemaへ変換したもの
│   ├── docs/ hooks/ rules/ scripts/ skills/  # `.claude/`配下の同名ディレクトリをそのままコピー
│   └── settings.json           # `.claude/settings.json`をGemini CLIの記法へ変換したもの
├── .github/
│   ├── ISSUE_TEMPLATE/          # GitHub用issueテンプレート（目的・現状・期待する動作・受け入れ条件）
│   └── pull_request_template.md # GitHub用PRテンプレート（`describe`が生成するdescriptionと同一構成）
├── .gitlab/
│   ├── issue_templates/         # GitLab用issueテンプレート（同上）
│   └── merge_request_templates/ # GitLab用MRテンプレート（`Default.md`。PRテンプレートと同一内容）
├── wip/                        # タスク単位の作業中ドキュメント（計画・ログ・報告）置き場（issue #165）。
│                                #   `.gitignore`対象のローカル作業状態`state/`もここへ置く（issue #184）
│   ├── plans/                  # 計画ファイル。全体作業計画（planツールが出力する`<自動命名>.md`、
│   │                            #   issueにつき1つ）と個別作業計画（`【種別】タスク内容.md`、
│   │                            #   planツールを使わずWrite/Editで作成）の2階層。タスクごとに
│   │                            #   新規生成しそのままコミットして履歴として残す。各mdには
│   │                            #   同名の`.html`（人間レビュー用ビュー）を併存させる（issue #54）
│   │   └── REVIEW-POINTS.md    # `wip/plans/`配下に適用するレビュー観点。**flow-id 5-5で削除しない**
│   └── worklogs/                # 実装中の詳細な試行錯誤ログ（`日付_<全体計画名>_<個別計画名>_push<N>.md`）
│       └── TEMPLATE.md         # worklog作成時にコピーして使うテンプレート
├── .gitattributes              # 改行コードの正規化。`*.sh text eol=lf`が`.sh`のLFを保証する
│                                #   （`dist:begin`〜`dist:end`の行のみ配布先へも追記される）
├── .gitignore
├── .mrworkflow.json            # リポジトリ固有設定（ブランチ命名規則・wip/plans/等の場所）
├── AGENTS.md                   # AIエージェント共通ルール・プロジェクト概要・開発実行方法
├── CLAUDE.md                   # Claude Code固有ルールへのポインタ（AGENTS.mdを@import）
├── DEVELOPERS.md                # 開発者向けドキュメントの入り口
├── GEMINI.md                    # Gemini CLI固有ルールへのポインタ（AGENTS.mdを@import）
├── HANDOFF.md                   # セッション間・作業者間の軽量な引継ぎメモ
├── index.md                     # Repository Map
├── README.md
└── REVIEW-POINTS.md            # リポジトリ全体に適用するレビュー観点
```

`wip/reports/`・`usage/`・`wip/state/`は、いずれもワークフロー実行中に動的に作成されるディレクトリの
ため、初期スケルトンには含まれない（作成・削除のタイミングは `.claude/rules/docs-workflow.md`・
`.claude/skills/issue-mr-flow/SKILL.md` を参照）。

**`.claude/.asset-manifest.json` は上のツリーに含まれない。** これは配布先にだけ生成されるファイルで、
本家（このリポジトリ）には実体が無いためである（ツリーへ載せると本家にも在ると誤読される）。
配布先では「どの版の何を配ったか」を記録し、再適用時に**上流の更新と配布先の改変を区別する**材料に
なる（仕様: `.claude/docs/spec/asset-distribution.md`。issue #26）。

`wip/reports/` には**mdとhtmlの2種類**を置く。`wip/reports/日付_<全体計画名>_<内容を簡潔に>.md` が調査結果・
作業結果・反映結果の**正文**で（個別計画へ結果を書かないための分離先。issue #87。詳細:
`.claude/skills/issue-mr-flow/references/deliverables.md`「計画と実施結果の分離」）、
`wip/reports/日付_<全体計画名>_<内容を簡潔に>.html` はその内容を視覚的にまとめた自己完結HTMLである
（土台は`.claude/skills/issue-mr-flow/assets/reports.template.html`。関連・依存関係が主題の場合は
`.claude/skills/canvas-report/SKILL.md` のcanvas形式）。両者は併存させ、flow-id 5-5でまとめて削除する。
**例外として、`html-slides` スキルの成果物 `*.slides.html`＋`*.slides.json` も `wip/reports/` へ置かれる**
（issue #168）。スライドは対応するmdを持たず、機械可読の対は構成案JSON（`.slides.json`）である。
寿命は他のreports成果物と同じ（flow-id 5-5で削除。詳細: `.claude/docs/spec/html-slides.md`）。

**`wip/plans/` も同じくmdとhtmlの2種類を置く**（issue #54）。`wip/plans/` の各計画（全体作業計画・個別計画）に
対応するHTMLビューを、**mdと同じベース名で拡張子だけ`.html`**にして併存させる（土台は
`.claude/skills/issue-mr-flow/assets/plans.template.html`）。mdが正文でHTMLはその視覚化という関係も、
flow-id 5-5でまとめて削除される寿命も`wip/reports/`と同じである。

`usage/` は対応工数レポート機能のローカル作業状態で、`.gitignore`対象（`/usage/`）。内訳は
`usage/session-logs/<sessionId>/`（セッションログのミラー）・`usage/state/<branch>.json`（集計状態）・
`usage/state/session-cursors/<sessionId>.json`（処理済み行数カーソル。Claude Code経路のみ）・
`usage/state/gemini-totals/<sessionId>.json`（**Gemini CLI経路の前回累計。ブランチ非依存**。
issue #97。ブランチ別に持つと、同じセッションのままブランチを切り替えたときに蓄積済みの全件が
新ブランチの初回差分として再計上されるため。詳細:
`.claude/docs/ddr/i0097-01-Gemini集計の差分はファイル全体の畳み込みと前回累計の差分で取る.md`）・
`usage/state/push-index.jsonl`（push断面の行範囲。Claude Code経路のみ）。issue #23以前は、これとは別に
`logs/push-<N>/` へpushのたびにセッションログ全文を保存する系統があったが、transcriptが追記専用で
あることを確認したうえで廃止し `usage/` へ一本化した（詳細:
`.claude/docs/ddr/i0023-01-push断面の全文コピーをやめ行番号インデックスで表現する.md`）。

`usage/`配下には、上記の対応工数レポート状態とは別に、OTelリスナー機構
（`.claude/hooks/otel/`）が振り分け保存する`usage/claude-otel-YYYYMMDD.jsonl`も生成される
（Claude Code公式のOpenTelemetryエクスポートをローカル受信したテレメトリの生データ。詳細:
`.claude/docs/spec/otel-listener.md`）。こちらもワークフロー実行中に動的に作成されるファイルで、
`/usage/`の`.gitignore`対象に含まれる。

同様に、Gemini CLI公式テレメトリ機構（issue #105）が`usage/gemini-otel.log`（Gemini CLIが
`outfile`設定に従い直接追記するテレメトリの生データ）・
`usage/state/gemini-otel/cursor.json`（バイトオフセットカーソル状態）を生成する。**後者は
上記の`usage/state/gemini-totals/<sessionId>.json`等と異なり、ブランチにもセッションにも
紐づかないグローバルな単一ファイル**である（詳細:
`.claude/docs/spec/gemini-cli-telemetry.md`）。いずれも`/usage/`の`.gitignore`対象に含まれる。

`wip/state/`はワークフローのローカル作業状態で、`.gitignore`対象（`/wip/state/`）。内訳は
`wip/state/review-links/<branch>.txt`（`post-push-compact-prompt.sh`がレビュー依頼メッセージの
参照リンク組み立てに使う、前回push時点のHEAD SHA）と
`wip/state/adversarial-review/<branch>.json`（`adversarial-review-count.sh`が持つ敵対的レビューの
実行回数）。責務分離のため`usage/`とは別ディレクトリにしている（詳細:
`.claude/docs/spec/issue-mr-workflow.md`「/compact実施の呼びかけ」節、
`.claude/docs/spec/adversarial-review.md`、
`.claude/docs/ddr/i0013-01-レビュー依頼メッセージの参照リンクは前回pushSHAをローカル状態で保持して組み立てる.md`）。

**issue #184 以前、この状態は`.claude/state/`に置かれていた。** `.claude/`は配布単位
（`apply-mr-workflow-to-project`が`.claude/`一式を配る）であり、その中に配布先のローカル状態が
同居していると、配布・変換同期のたびに除外の設定が要る。`wip/`（issue #165 が
`plans/` `worklogs/` `reports/`の集約先として定義した、mainに残らない作業用の親ディレクトリ）へ
出すことで、`.claude/`を「配る資産だけ」にした（詳細:
`.claude/docs/ddr/i0184-01-ワークフローのローカル作業状態はwip配下へ移し旧パスのignoreを移行用に残す.md`）。
`.gitignore`には旧パス`/.claude/state/`の行も**移行用の名残**として残っている（既存の作業ツリーに
残る状態ファイルが追跡対象に現れないようにするため。手元の`.claude/state/`を消したあとであれば
削除してよい）。

**`.gitignore`のパターンを`/wip/`へ広げてはいけない。** issue #165 が`wip/`配下へ置いた
`plans` `worklogs` `reports`は**追跡対象**であり、丸ごと無視される。

## 配置の指針

- 開発フロー全体（issue起票〜マージ）は `.claude/skills/issue-mr-flow/SKILL.md`
  （唯一の実装フロー定義）に従う。詳細は `AGENTS.md` を参照。
- **AIエージェントが`.claude/skills/*`経由で能動的に実行するスクリプト**は `.claude/scripts/`
  配下に置く。`.claude/scripts/src/` にスクリプト本体、`.claude/scripts/test/` に
  その単体テスト、`.claude/scripts/docs/` ではなく
  `.claude/docs/` に関連ドキュメント（`spec/`・`ddr/`）を置く（このリポジトリは移植元と異なり
  アプリ本体を持たないため、`dev-tools/` 等の人間専用ツール置き場との分離は行っていない。将来
  アプリ本体を追加する場合は、そのアプリ専用の `docs/spec/` `docs/ddr/`（または人間専用ツール用の
  `dev-tools/docs/`）を新設し、`.mrworkflow.json` の `specDirs`/`ddrDirs` に追記することを検討する）。
  Claude Codeのplugin配布は`.claude/`配下一式をパッケージ化する想定のため、AIが実行時に必要とする
  スクリプト・設計書は`.claude/`の外に置かない。
- **`.claude/hooks/`配下の常駐プロセス（`otel/`等）の単体テストは、`.claude/scripts/test/`ではなく
  そのプロセス自身の配下（例: `.claude/hooks/otel/test/`）に置く**。`.claude/scripts/test/`は
  上記のとおり「`.claude/scripts/src/`配下スクリプトの単体テスト」専用であり、Claude Codeの
  hookから自動起動される常駐プロセスはこれに当たらない。テスト形式（TAP出力か
  `passed=N failures=N`出力か等）は実装言語の慣習に合わせてよく、`.claude/scripts/test/`の
  規約（`passed=N failures=N`）へ揃える必要はない。
- 各`.claude/skills/<name>/`は`SKILL.md`単体が基本だが、スキルの実行に必須のバンドルリソース
  がある場合はサブディレクトリを追加してよい。**名前はAgent Skillsの語彙に揃え、次の3つから選ぶ**
  （issue #54。`templates/`は使わない。リポジトリ内で同じ役割に2つの語彙が並立するのを避けるため、
  issue #54で`canvas-report/templates/`を`assets/`へ改名した）。

  | ディレクトリ | 用途 | 実例 |
  |---|---|---|
  | `assets/` | **出力に使うもの**（テンプレート等） | `issue-mr-flow/assets/reports.template.html`, `canvas-report/assets/canvas-report.html` |
  | `scripts/` | **実行するもの**（補助スクリプト） | `apply-mr-workflow-to-project/scripts/install-to-project.sh` |
  | `references/` | **AIが読むもの**（参照資料） | `issue-mr-flow/references/planning.md` 等7本（SKILL.mdから切り出した詳細節。issue #160） |

  **issue #26以前、`apply-mr-workflow-to-project/assets/` だけは意味が異なり、`sync-assets.sh`が
  配布前に生成する`.gitignore`対象のビルド用一時ディレクトリだった。** issue #26で`.skill`
  パッケージ化と`sync-assets.sh`を廃止したため、この例外は無くなり、現在は上表どおり
  **Git管理下に置く恒久のバンドルリソース**（配布先へ置く雛形一式）である。
  `.gitignore`の除外行を相対パターン（`assets/`）へ広げると、これらが無言でGit管理から外れる。
- **`.gemini/` は全体が `.claude/` からの変換生成物である**（issue #70）。`agents/*.md` の
  frontmatter と `settings.json` は Claude Code と Gemini CLI でスキーマが違うため、
  `bash .claude/scripts/src/sync-gemini-assets.sh` が記法差を変換で吸収して生成する。
  **`.gemini/` を直接編集しない**（次の再生成で失われる）。編集は常に `.claude/` 側へ行い、
  このスクリプトを流し直す（フロー上の最終ゲートは flow-id 5-3）。
  **生成物だがGit管理下へ置きコミットする**（配布先で再生成を忘れても資産が見えるようにするため。
  `index.jsonl` をGit管理外にしている判断とはここが分かれる）。変換規則・`--check`/`--dry-run`/
  `--force`・削除ファイル検出の詳細は `.claude/docs/spec/sync-gemini-assets.md`、方式を選んだ経緯・却下案は
  `.claude/docs/ddr/i0070-01-gemini配下はclaudeからの変換生成物にしGit管理下へ置く.md` を参照
  （issue #70 以前はローカルリンク運用で、`setup-gemini-links.sh` が各開発者のマシン上でリンクを
  生成していた。当時の経緯は DDR `i0000-13`。**現在は superseded**）。
- `.claude/hooks/` 配下のスクリプトは現在すべてbash（`.sh`）。新規`.ps1`を作成する場合のみ
  **BOM付きUTF-8で保存する**こと（BOM無しだとWindows PowerShell 5.1でパースエラーになる。詳細:
  `.claude/rules/powershell-encoding.md`）。`.sh`はBOM無しUTF-8・LF改行で保存する
  （詳細: `.claude/rules/shell-script-style.md`）。複数hookスクリプトで使い回すロジックは
  `.claude/hooks/lib/` に切り出す。
- 開発補助スクリプト（`.claude/scripts/src/`, `.claude/hooks/`配下のシェルスクリプト等）は
  git bash経由で実行可能な範囲でbash（`.sh`）を使う。bash化できない場合のみPowerShell（`.ps1`）
  とする。bashスクリプトは`jq`（JSON操作）を前提とする。詳細な判断基準・規約は
  `.claude/docs/spec/shell-scripts.md`, `.claude/rules/shell-script-style.md` を参照。
- **レビュー観点表 `REVIEW-POINTS.md` は、観点を適用したいディレクトリの直下に置く**（issue #77）。
  1つの `REVIEW-POINTS.md` は**そのディレクトリ配下すべて（孫以下を含む）**に適用され、収集時は
  対象ファイルのディレクトリからリポジトリルートまで祖先を遡って集めてマージする（浅い→深い）。
  一般的な観点ほど上位へ置き、下位で重複して書かない。現在の配置はルート直下・`.claude/`・
  `wip/plans/`・`wip/reports/` の4つ。**同じディレクトリの `REVIEW-POINTS.local.md` は配布先が所有する**
  （`REVIEW-POINTS.md` は配布元所有の `core`、`.local` は `seed`。issue #26）。収集時は
  `REVIEW-POINTS.md` → `REVIEW-POINTS.local.md` の順に連結され、**`REVIEW-POINTS.md` が無い
  ディレクトリに `.local` だけを置いてもよい**。収集アルゴリズム・frontmatterの詳細は
  `.claude/docs/spec/adversarial-review.md`「レビュー観点（REVIEW-POINTS.md）」を参照する。
  **`wip/plans/REVIEW-POINTS.md` と `wip/reports/REVIEW-POINTS.md` は、それらのディレクトリを片付ける
  flow-id 5-5でも削除しない**（`.claude/rules/docs-workflow.md` のライフサイクル表が正）。
