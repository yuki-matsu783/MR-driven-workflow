---
title: 開発者向けドキュメント
type: guide
description: このリポジトリの開発に参加する人向けの関連ドキュメントへの入り口をまとめたガイド
tags: [developers, guide]
keywords: [issue-mr-flow, ディレクトリ構成, mrworkflow, claude-code, gemini-cli]
---

# AIアセット開発者向けガイド

## 対象読者 (Intended Audience)

* AIエージェントのメンテナー (AI Agent Maintainers)
* AI関連スクリプトの開発者 (AI-related Script Developers)
* AIワークフローの改善担当者 (AI Workflow Improvement Specialists)

## 開発指針 (Development Principles)

* **慎重な変更 (Careful Modifications):** AIアシスタント（Claude, Gemini）の設定は、各自の環境で十分にテストし、変更は慎重に行ってください。AIの振る舞いに直接影響します。
* **テストの重視 (Emphasis on Testing):** 開発ツール（`/.claude/`）のスクリプトに機能追加や変更を行う際は、必ず対応するテストを追加または更新してください。
* **適切な配置とドキュメント (Proper Placement and Documentation):** 新しいAI関連資産を追加する際は、適切なディレクトリに配置し、関連する`README.md`やその他のドキュメントを更新してください。
* **規約の遵守 (Adherence to Conventions):** 変更を行う際は、[AGENTS.md](AGENTS.md)や`.claude/rules/`に記載されている共通ルールおよび規約を遵守してください。

## 主要なディレクトリと役割 (Key Directories and Roles)

各ディレクトリの役割説明は [index.md](index.md)（Repository Map）を正とする
（重複記載による陳腐化を避けるため、本ファイルでは個別のディレクトリ一覧を持たない。
詳細は [.claude/rules/directory-structure.md](.claude/rules/directory-structure.md) 参照）。

## 開発ワークフロー (Development Workflow)

* **issue-mr-flow:** 新機能開発や大きな変更を行う際は、[.claude/skills/issue-mr-flow/SKILL.md](.claude/skills/issue-mr-flow/SKILL.md)に記載されているフローに従って進めてください。
* **計画と合意形成:** 実装に入る前に必ず計画を立て、ユーザーや他の開発者と合意形成を行ってください。

## テストと品質保証 (Testing and Quality Assurance)

* **既存テストの確認:** コードに変更を加える際は、既存のテストが全てパスすることを確認してください。
* **新規テストの追加:** 必要に応じて、変更内容をカバーする新しいテストを追加してください。
* **AI動作確認:** AIアシスタントの設定変更は、実際の対話を通じてその動作が意図通りであることを確認してください。

## 他リポジトリへの配布 (Distribution)

本リポジトリのAIアセット（`.claude/` 一式・issue/MRテンプレート・ルート設定）は、
**インストーラを直接実行する**ことで他のリポジトリへ配布する。ビルド（`.skill` パッケージ）は
不要である（issue #26 で廃止した）。

```bash
# 配布先を指定して実行するだけでよい。まず --dry-run で何が起きるかを確認する。
bash .claude/skills/apply-mr-workflow-to-project/scripts/install-to-project.sh --dry-run /path/to/target-repo
bash .claude/skills/apply-mr-workflow-to-project/scripts/install-to-project.sh /path/to/target-repo
```

### 何がどう配られるか

配布対象と扱いは `.claude/dist-layers.json`（層分け定義）が**単一の正**として持つ。

| 層 | 扱い | 例 |
|---|---|---|
| `core` | 常に上書きする（配布元所有） | `.claude/rules/` `.claude/scripts/` `REVIEW-POINTS.md` |
| `seed` | 配布先に無ければ置く。あれば触らない（配布先所有） | `AGENTS.md` `HANDOFF.md` `.mrworkflow.json` `REVIEW-POINTS.local.md` |
| `merge` | 構造的にマージする | `.gitignore` `.gitattributes`（行追記）・`.claude/settings.json`（キー単位） |
| `local` | 何もしない | `plans/` `worklog/` `reports/` `usage/` |
| `exclude` | 配らない | `README.md` `DEVELOPERS.md` `apply-mr-workflow-to-project/` |

配布結果は配布先の `.claude/.asset-manifest.json` へ記録される（配布元のコミットSHA・版・
ファイルごとの sha256）。再適用時はこれと突き合わせて、**配布先が適用後に変更した `core`
ファイル**を上書き前に警告し、元の内容を `.bak` として残す。

### 主なオプション

| オプション | 意味 |
|---|---|
| `--dry-run` | 何も変更せず、配置・警告の内容だけを出力する |
| `--force` | 改変済みの `core` を `.bak` を残さず上書きする |
| `--allow-dirty` | 配布元のワークツリーが dirty でも続行する（manifest の commit へ `-dirty` が付く） |

### 層分け定義を変えたとき

追跡ファイルを追加・移動したら、**必ず網羅性チェックを流す**（未分類が1件でもあれば、
インストーラは配布を始める前に中断する）。

```bash
bash .claude/scripts/src/check-dist-coverage.sh
```

### 配布先での初期セットアップ

インストーラが `.gemini/` のリンク作成まで行う。symlink も NTFS ジャンクションも作れない環境では
**実体コピーへフォールバックする**（再適用のたびに `.claude/` 側の最新へ入れ替わる）。
