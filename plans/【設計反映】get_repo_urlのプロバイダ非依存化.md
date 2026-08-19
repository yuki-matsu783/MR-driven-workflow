---
title: 【設計反映】get_repo_urlのプロバイダ非依存化
type: log
description: issue #44の個別反映計画。specの提供関数表・新節とDDR 0035へ反映する内容の割り当て
tags: [plan, spec, ddr]
keywords: [設計反映, DDR 0035, 提供関数, リスクケース, insteadOf, カスタムポート, DDR 0023]
---

# 【設計反映】get_repo_urlのプロバイダ非依存化

全体作業計画: `plans/issue44-repo-url-from-git-remote.md`

## 反映先と内容

| 反映先 | 内容 |
|---|---|
| `.claude/docs/spec/issue-mr-workflow.md`「提供関数」表 | `get_repo_url` 行をプロバイダ非依存（GitHub/GitLab実装欄は `—`）へ更新し、`repo_url_from_remote_url` 行を追加 |
| 同「リポジトリURLの導出（issue #44）」節（新設） | 置き換えの背景・効果、正規化の規則、`parse_repo_slug` との整合、DDR 0023との関係、リスクケース表 |
| 同「`gh`/`glab` CLI不在時のMCPフォールバック経路」節 | 「例外（`get_repo_url`）」の記述を、経路ごとの分岐から一本化後の内容へ更新 |
| 同「/compact実施の呼びかけ」節 | issue #13フォローアップの「`gh repo view` で取得した」という記述から、CLI名を除く |
| 同「影響範囲」 | issue #44 のエントリを追加（**過去エントリは変更しない**。issue #13 のエントリに残る `github_get_repo_url` 等の記述はpoint-in-timeの記録として保持する） |
| `.claude/docs/ddr/0035-...md`（新設） | 却下案4件（現状維持／CLIとの突き合わせ／設定ファイル化／ずれ検知でフォールバック）と、受け入れたトレードオフ（リスクケース表） |
| `.claude/docs/README.md` | DDR一覧へ 0035 を追加 |
| `.claude/skills/issue-mr-flow/SKILL.md` | MCP対応表の `get_repo_url` 行の説明を「フォールバック」から「プロバイダ非依存」へ |

## 注意

- DDR番号は 0035（mainの最新が 0034）。マージ前に main が進んでいた場合は flow-id 5-2 で
  番号衝突を確認する。
- specの過去changelogエントリ（issue #13 等）へは、機械的なパス・関数名の一括置換をかけない
  （`.claude/rules/docs-workflow.md`）。
