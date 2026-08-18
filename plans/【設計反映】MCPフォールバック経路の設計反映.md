---
title: 【設計反映】gh/glab CLI不在時のMCPフォールバック経路の設計反映
type: guide
description: issue #34対応の個別反映計画。specへの反映箇所とDDR新設の内容、AIアセット反映の要否を定義する
tags: [issue-mr-flow, mcp, spec, ddr]
keywords: [設計反映, spec, DDR0025, 影響範囲, AIアセット反映, AGENTS.md, SKILL.md, issue34]
---

# 【設計反映】gh/glab CLI不在時のMCPフォールバック経路の設計反映

対象: issue #34。全体作業計画: `plans/steady-bridging-gateway.md`、
個別作業計画: `plans/【設計】【実装】gh-glab不在時のMCPフォールバック経路.md`。

## 設計反映（`.claude/docs/spec/` / `.claude/docs/ddr/`）

| 反映先 | 内容 |
|---|---|
| `.claude/docs/spec/issue-mr-workflow.md`「提供関数」表 | `get_vcs_access_mode` / `parse_repo_slug` / `get_repo_slug` / `mcp_tool_hint` / `require_vcs_cli` の5行を追加 |
| 同「セッション開始時の自動コンテキスト注入」節 | CLI不在時の挙動（受け入れ条件3）を「フォールバック方針」の次の項目として明記。従来「PR: なし」と誤表示していた点も記録する |
| 同 新節「`gh`/`glab` CLI不在時のMCPフォールバック経路（issue #34）」 | 経路判定・手順の正の置き場所（SKILL.md）・ガードの狙い・`get_repo_url`の例外・hook3本の縮退・GitLab対象外を記載 |
| 同「影響範囲」 | issue #34のエントリを追記（既存の過去エントリは書き換えない） |
| `.claude/docs/ddr/0025-...md`（新規） | 採用した方式（判定関数＋ガードによる機構的誘導）と却下案4件、DDR 0020との整合、GitLab対象外の理由 |

**対応表そのものはspecへ書かない**（SKILL.mdの該当節を正とし、specからは参照のみ）。
ライフサイクルが同じ2箇所に同じ表を置くと、MCPツールの引数変更時に片方だけ古くなるため。

## AIアセット反映（`.claude/rules/` `.claude/skills/` `CLAUDE.md` `AGENTS.md`）

| 反映先 | 要否 | 内容 |
|---|---|---|
| `.claude/skills/issue-mr-flow/SKILL.md` | 実施済み（フェーズ3で実施） | 新節の追加・サブコマンド節冒頭・「前提」節からの参照 |
| `.claude/skills/issue-create/SKILL.md` | 実施済み（同上） | 手順3のMCP読み替え |
| `AGENTS.md` | 実施済み（同上） | 対応表の正であるSKILL.md該当節への参照を追加 |
| `.claude/rules/shell-script-style.md` | **不要** | 今回追加したbashコードは既存規約（`set -euo pipefail`・snake_case・jq利用・ループ内で外部コマンドを呼ばない）の範囲内で、新しい落とし穴の知見は無い |
| `.claude/rules/git-workflow.md` / `docs-workflow.md` | **不要** | ブランチ運用・ドキュメント運用に変更は無い |
| `CLAUDE.md` | **不要** | `AGENTS.md` を@importする構造のため、AGENTS.md側の更新で足りる |

フェーズ3で既にAIアセット（skills/AGENTS.md）へ反映済みのため、フェーズ4では
`.claude/docs/spec/` `.claude/docs/ddr/` への反映と、上表の「不要」判断の記録のみを行う。
