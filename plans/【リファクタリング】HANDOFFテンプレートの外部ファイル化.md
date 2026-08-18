---
title: 【リファクタリング】HANDOFFテンプレートの外部ファイル化
type: log
description: cleanup-task.shに埋め込まれたHANDOFF.mdテンプレートを外部ファイル化し、SKILL.mdからも参照できるようにする
keywords: [template, handoff, refactoring, cleanup-task, single-source]
---

## 背景

`cleanup-task.sh` に HANDOFF.md テンプレート（150行以上のヒアドキュメント）が直接埋め込まれており、
以下の問題がある（issue #28実装のレビューで指摘）。

- スクリプトが肥大化し、実際のロジック（削除・再生成処理）が埋もれる
- テンプレートが `cleanup-task.sh` 内にしかなく、`.claude/skills/issue-mr-flow/SKILL.md` を読んでいる
  人・エージェントからテンプレートの実体が見えない
- SKILL.md 側で全体フローを変更した場合、`cleanup-task.sh` 内のテンプレートを手動で同期する必要が
  あり、変更箇所が分散する

## 方針

テンプレートを独立ファイルへ切り出し、`cleanup-task.sh` と `SKILL.md` の両方から**同じファイルを
参照**する（テンプレート内容の単一ソース化）。

## 実装内容

### 1. テンプレートファイルの新規作成

**ファイル**: `.claude/scripts/templates/HANDOFF.md.template`

- 現在 `cleanup-task.sh` 内の `handoff_template` 変数に埋め込まれている内容をそのまま移動
- `.claude/scripts/src/` 配下ではなく `.claude/scripts/templates/` を新設する
  （`.claude/skills/canvas-report/templates/` に前例がある命名パターンに合わせる）

### 2. `cleanup-task.sh` の修正

- ヒアドキュメント文字列 (`handoff_template="..."`) を削除
- テンプレートファイルをコピーする方式に変更：
  ```bash
  template_file="${script_dir}/../templates/HANDOFF.md.template"
  cp "$template_file" HANDOFF.md
  ```
- スクリプト行数が大幅に削減され、削除・再生成ロジックが見やすくなる

### 3. `SKILL.md` からの参照を追加

**修正対象**: `.claude/skills/issue-mr-flow/SKILL.md`

- flow-id 1-6（「全体作業計画をもとにHANDOFF.mdを更新する」）または flow-id 5-1 の説明部分に、
  テンプレートファイルへのパス参照を追記
- 「詳細ルールへのポインタ」節にも `HANDOFF.md.template` への参照を追加

### 4. `docs-workflow.md` の更新

- 前回追加した「HANDOFF.md と SKILL.md の役割分担」節に、テンプレートファイルの場所を追記
- 「HANDOFF.md のテーブルは `.claude/scripts/templates/HANDOFF.md.template` として実体化されている」
  ことを明記

### 5. `directory-structure.md` の更新

- ツリー図の `.claude/scripts/` 配下に `templates/` を追記
- 「配置の指針」節に、スキルのバンドルリソース用 `templates/` パターンを scripts にも適用した旨を
  記載（既存の `canvas-report/templates/` と同じ考え方であることを明示）

## 影響ファイル

- 新規: `.claude/scripts/templates/HANDOFF.md.template`
- 修正: `.claude/scripts/src/cleanup-task.sh`
- 修正: `.claude/skills/issue-mr-flow/SKILL.md`
- 修正: `.claude/rules/docs-workflow.md`
- 修正: `.claude/rules/directory-structure.md`

## 検証方法

1. `bash .claude/scripts/src/cleanup-task.sh --dry-run` でテンプレートファイルパスが正しく解決されるか確認
2. `bash .claude/scripts/src/cleanup-task.sh` を実行し、HANDOFF.md が想定通りテンプレート化されるか確認
3. `bash -n .claude/scripts/src/cleanup-task.sh` で構文チェック
4. SKILL.md / docs-workflow.md からテンプレートファイルへのリンクが正しいパスになっているか確認
