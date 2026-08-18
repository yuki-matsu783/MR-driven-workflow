# AI Asset Management Project

## 概要 (Overview)

このリポジトリは、AI開発プロジェクトに関連する資産（設定ファイル、スクリプト、ドキュメントなど）を一元管理するためのものです。
アプリケーションのソースコードや一般的なプロジェクトドキュメントは含まれていません。

This repository is for centrally managing assets related to AI development projects, such as configuration files, scripts, and documents.
It does not include application source code or general project documentation.

## ディレクトリ構造 (Directory Structure)

* `/.claude/`, `/.gemini/`: AIアシスタント（Claude, Gemini）用の設定ファイル (Configuration files for AI assistants (Claude, Gemini)).
* `/.github/`, `/.gitlab/`: CI/CDやIssueテンプレートなどのGitホスティングサービス向け設定 (Settings for Git hosting services, such as CI/CD and issue templates).
* `/assets/`: アイコンなどの静的アセット (Static assets like icons).
* `/.claude/`: 開発を補助するためのツールやスクリプト群 (A collection of tools and scripts to support development).
* `/tests/`: `.claude`内のスクリプトに対応するテストコード (Test codes corresponding to the scripts in `.claude`).
* `/worklog/`: 作業記録や調査メモなどを格納するディレクトリ (A directory for storing work logs, investigation notes, etc.).