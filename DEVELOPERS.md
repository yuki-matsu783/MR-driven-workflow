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

## カスタムスキルの開発とパッケージング (Custom Skill Development & Packaging)

本リポジトリには、ワークフロー全体を他のリポジトリへ自動展開するための専用スキル `apply-mr-workflow-to-project` などが定義されています。これらのカスタムスキルはビルド（コンパイル）して配布用バイナリ `.skill` パッケージを生成する必要があります。

### 1. 同期とビルドの流れ (Sync & Build Flow)

開発時、本リポジトリのコアアセット（ルール、設定、フック等）を変更した後は、以下のコマンド群を用いてスキルにアセットを同期させ、配布パッケージをローカルビルドします。

```bash
# 1. 変更したコアアセットをスキル一時アセットディレクトリに同期（assets/ は .gitignore 対象）
#    .claude/ 一式・.github/ .gitlab/ のテンプレート・ルート設定に加え、.gitattributes も対象。
#    .gitattributes は配布先へ丸ごとコピーされず、`# --- dist:begin ---` 〜 `# --- dist:end ---`
#    の間の行だけが配布先の .gitattributes へ追記される
#    （詳細: .claude/docs/spec/distribution-assets.md）。
bash .claude/skills/apply-mr-workflow-to-project/scripts/sync-assets.sh

# 2. スキルフォルダをビルドして .skill バイナリをコンパイル
node /usr/local/lib/node_modules/@google/gemini-cli/bundle/builtin/skill-creator/scripts/package_skill.cjs .claude/skills/apply-mr-workflow-to-project

# 3. ビルド成果物を出力ディレクトリに整理（build/ は .gitignore 対象）
mkdir -p build && mv apply-mr-workflow-to-project.skill build/
```

### 2. 配布と他リポジトリへの適用方法

ビルドした `.skill` パッケージを任意のリポジトリへ持ち運び、ワークフローを即座に自動展開することができます。

```bash
# 対象のリポジトリのルートで Gemini CLI を使い、ビルドしたパッケージファイルをインポートして発動
gemini skills install /path/to/apply-mr-workflow-to-project.skill
```

インポート完了後、AIエージェントが自律的に対象リポジトリへ `mr-driven-develop` のセットアップを完了させます。

## OpenTelemetryリスナーの導入 (OpenTelemetry Listener Setup)

Claude Code公式のOTLPテレメトリをローカルで受信し、`<ワークスペース>/usage/`配下へ
セッション単位で振り分け保存する機構（`.claude/hooks/otel/`。仕様の詳細:
`.claude/docs/spec/otel-listener.md`）を使うには、以下の手順でローカル環境ごとの設定を行う。

### 前提

* `perl`（コアモジュール `IO::Socket::INET` / `JSON::PP` / `Test::More` のみに依存。追加の
  CPANパッケージのインストールは不要）。Windows側git bash（MSYS）・WSL側Linux、いずれも
  同梱のperlで動作を確認済み。
* `perl -v`でバージョンを確認できればよい。コアモジュールの有無は
  `perl -MIO::Socket::INET -MJSON::PP -e 'print "ok\n"'` で確認できる。

### 手順

1. `.claude/settings.local.json.example` を `.claude/settings.local.json`
   （リポジトリルート直下。Git管理外、`.gitignore`対象）としてコピーする。
2. 実行環境に応じて `env.OTEL_EXPORTER_OTLP_ENDPOINT` / `env.OTEL_RESOURCE_ATTRIBUTES` /
   `env.OTEL_USAGE_PORT` を設定する（Windows/WSLで同じリポジトリを開く場合、双方の値を
   同時には持てないため、実際に起動する側の値を書く）。**3つとも同じ環境の値で揃える**こと
   （`OTEL_USAGE_PORT`だけ既定値のままだと、送信先とリスナーの待受ポートが食い違い結線できない）。

   | 環境 | `OTEL_EXPORTER_OTLP_ENDPOINT` | `OTEL_RESOURCE_ATTRIBUTES` | `OTEL_USAGE_PORT` |
   |---|---|---|---|
   | Windows（git bash） | `http://localhost:4318` | `host.env=win` | `4318` |
   | WSL/Linux | `http://localhost:4319` | `host.env=wsl` | `4319` |

   ポートを分けているのは、WindowsとWSLが127.0.0.1を共有しつつも別プロセス空間で動くため、
   同じポートで両方のリスナーを同時に立てられないことによる。
3. Claude Codeのセッションを開始（または`/clear`・`/compact`）すると、`SessionStart`
   フック（`.claude/hooks/otel/session-start.sh`）が自動的に対応表への追記とリスナーの
   起動判定を行う。手動での起動操作は不要。
4. 動作確認は以下の順で行うと切り分けやすい。
   * リスナーが立っているか: `.claude-otel/listener.log`（Windowsは
     `%USERPROFILE%\.claude-otel\`、WSL/Linuxは`~/.claude-otel/`）を確認する。
   * 疎通確認: `curl -X POST http://localhost:4318/v1/logs -d '{}'` を実行し、共有位置の
     `unrouted-YYYYMMDD.jsonl`に1行増えることを確認する。
   * 結線確認: Claude Codeでプロンプトを1回実行し、
     `<ワークスペース>/usage/claude-otel-YYYYMMDD.jsonl`に行が追記されることを確認する
     （メトリクスは`OTEL_METRIC_EXPORT_INTERVAL`で指定した間隔後に出力される）。

### 単体テストの実行

```bash
perl .claude/hooks/otel/test/test_session_id_finder.pl
perl .claude/hooks/otel/test/test_otel_registry.pl
```

`Test::More`によるTAP形式で結果が出力される（bash版の`passed=N failures=N`形式への
変換は行わない。理由: `.claude/rules/shell-script-style.md`）。

### 既知の制限

詳細・最新版は `.claude/docs/spec/otel-listener.md`「既知の制限」を正とする（本節では要点のみ）。

* セッション開始直後の数秒間は、リスナー起動前のエクスポートを取りこぼす。
* セッション中に`cwd`が変わっても対応表は追従しない。
* 出力ファイル（`usage/claude-otel-YYYYMMDD.jsonl`）は日次ローテーションのみで、
  古いファイルの自動削除は行わない。
* リスナーは受信の読み取りタイムアウトを持たないため、応答しないクライアントからの接続が
  1本でもあるとacceptループごと停止しうる（回復にはリスナープロセスの手動終了が必要）。