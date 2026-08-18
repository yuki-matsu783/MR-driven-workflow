---
alwaysApply: true
title: ディレクトリ構成
type: rule
description: リポジトリのディレクトリ構成と配置方針を定めたルール
tags: [directory-structure, rule]
keywords: [ディレクトリ構成, claude, gemini, 配置方針, plans, worklog, mrworkflow, always-apply]
---

# ディレクトリ構成

各ディレクトリの役割説明は [index.md](../../index.md)（Repository Map）を正とする。本ファイルは
ツリー構造・配置ルールを扱う（ディレクトリの役割説明を重複記載しない）。

```
./
├── .claude/
│   ├── docs/                  # issue駆動MRワークフロー機構自体の設計ドキュメント
│   │   ├── README.md         # .claude/docs配下の目次
│   │   ├── spec/              # 機能ごとの正史仕様
│   │   └── ddr/                # 意思決定ログ（DDR）
│   ├── rules/                  # AI向け詳細ルール（コーディング規約・ドキュメント運用等）
│   ├── skills/                 # `/issue-mr-flow`（唯一の実装フロー定義）等のスキル定義
│   ├── agents/                 # サブエージェント定義（issue-mr-flow途中引き継ぎ等）
│   ├── scripts/                # AIエージェントが`.claude/skills/*`経由で能動的に実行するスクリプト一式
│   │   └── src/
│   │       └── vcs/            # GitHub/GitLabの差異を吸収するVCS抽象化層（Provider.sh）
│   ├── hooks/                  # SessionStart/PostToolUse等のClaude Code hookスクリプト
│   │   └── lib/                # 複数hookスクリプトで使い回す共通ロジック
│   └── settings.json
├── .gemini/                    # Gemini CLI向け設定。settings.jsonのみGit管理。docs/hooks/rules/
│   │                            # scripts/skillsは.claude配下へのローカルリンクで.gitignore対象
│   └── settings.json
├── .github/
│   └── ISSUE_TEMPLATE/          # GitHub用issueテンプレート（目的・現状・期待する動作・受け入れ条件）
├── .gitlab/
│   └── issue_templates/         # GitLab用issueテンプレート（同上）
├── build/                      # ビルド成果物の出力先。`.gitignore`対象でコミットしない（通常は空）
├── plans/                      # AIエージェントのplanモードが出力する計画ファイル。タスクごとに
│                                #   新規生成しそのままコミットして履歴として残す
├── worklog/                    # 実装中の詳細な試行錯誤ログ（`日付_<planファイル名>_push<N>.md`）
│   └── TEMPLATE.md             # worklog作成時にコピーして使うテンプレート
├── .gitignore
├── .mrworkflow.json            # リポジトリ固有設定（ブランチ命名規則・plans/等の場所）
├── AGENTS.md                   # AIエージェント共通ルール・プロジェクト概要・開発実行方法
├── CLAUDE.md                   # Claude Code固有ルールへのポインタ（AGENTS.mdを@import）
├── DEVELOPERS.md                # 開発者向けドキュメントの入り口
├── GEMINI.md                    # Gemini CLI固有ルールへのポインタ（AGENTS.mdを@import）
├── HANDOFF.md                   # セッション間・作業者間の軽量な引継ぎメモ
├── index.md                     # Repository Map
└── README.md
```

`reports/<plan名>.html`（`.claude/skills/canvas-report/SKILL.md`参照）・`usage/`（対応工数レポートの
ローカル作業状態）は、いずれもワークフロー実行中に動的に作成されるディレクトリのため、初期スケルトン
には含まれない（作成・削除のタイミングは `.claude/rules/docs-workflow.md`・
`.claude/skills/issue-mr-flow/SKILL.md` を参照）。`logs/`（`post-push-save-logs.sh`が`git push`時に
保存するセッションログ。詳細: `.claude/docs/spec/session-log-hooks.md`）も同様に動的作成・
`.gitignore`対象（`/logs/`）で、初期スケルトンには含まれない。

## 配置の指針

- 開発フロー全体（issue起票〜マージ）は `.claude/skills/issue-mr-flow/SKILL.md`
  （唯一の実装フロー定義）に従う。詳細は `AGENTS.md` を参照。
- **AIエージェントが`.claude/skills/*`経由で能動的に実行するスクリプト**は `.claude/scripts/`
  配下に置く。`.claude/scripts/src/` にスクリプト本体、`.claude/scripts/docs/` ではなく
  `.claude/docs/` に関連ドキュメント（`spec/`・`ddr/`）を置く（このリポジトリは移植元と異なり
  アプリ本体を持たないため、`dev-tools/` 等の人間専用ツール置き場との分離は行っていない。将来
  アプリ本体を追加する場合は、そのアプリ専用の `docs/spec/` `docs/ddr/`（または人間専用ツール用の
  `dev-tools/docs/`）を新設し、`.mrworkflow.json` の `specDirs`/`ddrDirs` に追記することを検討する）。
  Claude Codeのplugin配布は`.claude/`配下一式をパッケージ化する想定のため、AIが実行時に必要とする
  スクリプト・設計書は`.claude/`の外に置かない。
- 各`.claude/skills/<name>/`は`SKILL.md`単体が基本だが、スキルの実行に必須のバンドルリソース
  （テンプレート・補助スクリプト等）がある場合は`.claude/skills/<name>/templates/`のような
  サブディレクトリを追加してよい（実例: `canvas-report/templates/canvas-report.html`）。他に
  `scripts/`・`references/`・`assets/`等、用途に応じた名前を使ってよい。
- `.gemini/` は `settings.json` のみGit管理下に置く。`docs/`・`hooks/`・`rules/`・`scripts/`・
  `skills/` は `.claude/` 配下の同名ディレクトリへのローカルリンク（可能ならシンボリックリンク、
  Windowsで作成できない環境ではNTFSジャンクション）とし、**Git管理下には置かない**
  （`.gitignore`で除外。Gemini CLIとClaude Code間でルール・スキル・スクリプトの内容を二重管理
  しないための仕組みだが、NTFSジャンクションはGitがリンクとして認識できず中身をそのまま複製して
  コミットしてしまうため、リンク自体はGitに載せず各開発者のマシン上でローカルに生成する方針とした。
  詳細: `.claude/docs/ddr/0017-gemini配下はGit管理下に置かずセットアップスクリプトで生成する.md`）。
  リンクの作成・再作成は `bash .claude/scripts/src/setup-gemini-links.sh` を実行する
  （clone直後に1回実行すればよい。既存のリンクがあれば何もしない）。実体は常に `.claude/` 側を編集する。
- `.claude/hooks/` 配下のスクリプトは現在すべてbash（`.sh`）。新規`.ps1`を作成する場合のみ
  **BOM付きUTF-8で保存する**こと（BOM無しだとWindows PowerShell 5.1でパースエラーになる。詳細:
  `.claude/rules/powershell-encoding.md`）。`.sh`はBOM無しUTF-8・LF改行で保存する
  （詳細: `.claude/rules/shell-script-style.md`）。複数hookスクリプトで使い回すロジックは
  `.claude/hooks/lib/` に切り出す。
- 開発補助スクリプト（`.claude/scripts/src/`, `.claude/hooks/`配下のシェルスクリプト等）は
  git bash経由で実行可能な範囲でbash（`.sh`）を使う。bash化できない場合のみPowerShell（`.ps1`）
  とする。bashスクリプトは`jq`（JSON操作）を前提とする。詳細な判断基準・規約は
  `.claude/docs/spec/shell-scripts.md`, `.claude/rules/shell-script-style.md` を参照。
