---
title: 【設計反映】【AIアセット反映】.mrworkflow.json関連ドキュメントの整合
type: guide
description: issue #21対応で判明した.claude/docs/spec/issue-mr-workflow.mdの設定項目節の値の陳腐化、および本セッションでgh/glab CLIが不在だった環境差異をAGENTS.mdへ反映する個別反映計画
tags: [docs, ddr, mrworkflow-json, ai-asset]
keywords: [specDirs, ddrDirs, issue-mr-workflow, gh, glab, MCP, 設定項目]
---

# 【設計反映】【AIアセット反映】.mrworkflow.json関連ドキュメントの整合

全体作業計画: `plans/playful-napping-finch.md`（issue #21）
個別作業計画: `plans/【実装】.mrworkflow.jsonキー説明をREADMEに追記.md`

## 対象1（設計反映）: `.claude/docs/spec/issue-mr-workflow.md`「設定項目」節の値の陳腐化

調査（`plans/playful-napping-finch.md`）で判明した事実: 同spec doc L984-998の「設定項目」節にある
`.mrworkflow.json`のサンプルJSONは、`specDirs`/`ddrDirs`の値が移植元プロジェクト当時のもの
（`["docs/spec", "dev-tools/docs/spec", ".claude/scripts/docs/spec"]`等）のまま残っており、
現行の実際の`.mrworkflow.json`（`specDirs: [".claude/docs/spec"]`, `ddrDirs: [".claude/docs/ddr"]`）
と食い違っている。

**方針**: `docs-workflow.md`の「現在の状態を説明する節は移動時に更新してよい」という運用に基づき
（「設定項目」節はpoint-in-timeのchangelogではなく現在の設定値を説明する節）、この節のJSONサンプルを
現行の実値に修正する。DDR本文の不変ルールとは異なる（このファイルはspecであり、`## 仕様`相当の
現在状態説明節にあたる）。

## 対象2（AIアセット反映）: `gh`/`glab` CLI不在の実行環境への対応をAGENTS.mdへ注記

本セッション（Claude Code on the webのリモート実行環境）では`gh`/`glab` CLIが利用できず、
`AGENTS.md`が前提とする「GitHub/GitLabの情報取得は`gh`/`glab` CLI経由」というルールが実行不能だった。
実際にはGitHub MCPサーバーツール（`mcp__github__*`）で代替した。今後同様の環境でこの前提が
崩れて手戻りするのを防ぐため、`AGENTS.md`の該当ルールに一言、フォールバック指針を追記する。

## 変更内容

1. `.claude/docs/spec/issue-mr-workflow.md`の「設定項目」節のJSONサンプルを、現行の`.mrworkflow.json`
   の実値に合わせて修正する。
2. `AGENTS.md`の「GitHub/GitLabのissue・PR/MR・コメント等の情報を取得する際は...`gh`/`glab` CLI...を
   使う」という一文の末尾に、`gh`/`glab` CLIが利用できない実行環境（例: Claude Code on the webの
   リモート実行環境）では、同等のGitHub/GitLab API・MCPツールで代替してよい旨を追記する。

## 確認方法

- `.claude/docs/spec/issue-mr-workflow.md`の修正後の値と、実際の`.mrworkflow.json`の内容が一致する
  ことを`diff`的に目視確認する。
- `AGENTS.md`の追記が、既存ルールの意図（原則`gh`/`glab` CLIを優先する）を変更せず、例外時の
  フォールバックのみを明記していることを確認する。
