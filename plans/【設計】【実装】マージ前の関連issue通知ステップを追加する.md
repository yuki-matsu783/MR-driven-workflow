---
title: 【設計】【実装】マージ前の関連issue通知ステップを追加する
type: plan
description: issue #86。Provider.shへadd_issue_commentを追加し、issue-mr-flowのフェーズ5へ関連issue通知ステップ（新5-3）を新設する計画
tags: [issue-mr-flow, provider, notification, plan]
keywords: [add_issue_comment, flow-id, 関連issue, 通知, AskUserQuestion, MCPフォールバック, 繰り下げ, 41ステップ]
---

# 【設計】【実装】マージ前の関連issue通知ステップを追加する

対象: issue #86「マージ前に今回のMRが影響する関連issueを特定し通知するステップを追加する」

本ファイルは**これから何をするか**のみを記載する。実施した結果は
`reports/20260819_mr-merge-issue-notification_関連issue通知ステップの追加.md` へ書く
（`.claude/skills/issue-mr-flow/SKILL.md`「計画と実施結果の分離」）。

## 目的

MRがマージされても、その変更で前提が変わる・一部が解決される・記述が矛盾する他のissueには
何も残らない。マージ前（Draft解除の直前）に影響先issueを特定し、人間の承認を得たうえで
当該issueへコメントを残せるようにする。

## 方針（設計）

### 1. `add_issue_comment <issue番号> <bodyFile>` を新設する

- 既存の `add_mr_comment <n> <bodyFile>` は宛先がPR/MRで、GitHub実装が `gh pr comment` の
  ため他のissueへは投げられない。**別関数として追加**し、既存関数の意味は変えない。
- **本文はファイル経由**（`add_mr_comment` / `set_mr_description` と同じインターフェース）。
  コマンド文字列へ長文を埋め込むと push検知hook を誤発火させるため
  （`.claude/rules/git-workflow.md`「push検知hookの誤検知」）。
- 実装
  - `Provider.sh`: `require_vcs_cli add_issue_comment` → プロバイダ別ディスパッチ。
  - `Github.sh`: `gh issue comment "$n" --body-file "$file"`。
  - `Gitlab.sh`: `glab api "projects/:id/issues/<iid>/notes" -X POST -f "body=..."`
    （`gitlab_add_mr_comment` と同じREST直叩き方式に揃える。`glab issue note --message` は
    `glab mr note --message` と同様に非推奨のため使わない）。
  - `mcp_tool_hint` に `add_issue_comment` → `mcp__github__add_issue_comment` の行を追加。

### 2. フェーズ5へ新しいステップを挿入する

- 位置は **5-2（コンフリクト解消）と旧5-3（Draft解除）の間**。
  - 旧 5-3（commit・push・Draft解除）→ **5-4**
  - 旧 5-4（マージ）→ **5-5**
  - 全 **40 → 41ステップ**（issue #46 が 5-2 を挿入したときと同じ扱い）。
- 手順（SKILL.md へ新設する節に書く）
  1. MRの差分（`git diff <base>...HEAD --stat` 等）から、AIが検索キーワードを最大5件抽出する。
  2. `search_issues` で候補を検索する（closedも対象。**自issue・自PRは除外**）。
  3. AIが候補ごとに影響の種類（前提が変わる／一部が解決される／記述が矛盾する）を判定し、
     投稿先とコメント本文案をユーザーへ提示する。
  4. **`AskUserQuestion` で対象issueとコメント本文の承認を得る。承認なしに投稿しない。**
  5. 承認された分だけ `add_issue_comment` で投稿する。本文の先頭には `reply` と同じ
     `Claude Codeより:` の署名行を付ける（CLI/MCPとも人間のアカウントで投稿されるため）。
  6. **影響先が無ければスキップしてよい**（HANDOFF.md へ「影響先なし」と記録して 5-4 へ進む）。

### 3. `gh`/`glab` CLI不在時のMCPフォールバック

- 対応表へ `add_issue_comment <n> <file>` → `mcp__github__add_issue_comment`
  （`owner`, `repo`, `issue_number=<issue番号>`, `body=<ファイルの内容>`）を追加する。
- `add_mr_comment` と同じツールだが、`issue_number` に渡すのがPR番号ではなく**issue番号**である
  点が違う。この差分を対応表の補足へ明記する。

## 変更対象ファイル

| ファイル | 変更内容 |
|---|---|
| `.claude/scripts/src/vcs/Provider.sh` | `add_issue_comment` ディスパッチャ・`mcp_tool_hint` の行を追加 |
| `.claude/scripts/src/vcs/Github.sh` | `github_add_issue_comment` を追加 |
| `.claude/scripts/src/vcs/Gitlab.sh` | `gitlab_add_issue_comment` を追加 |
| `.claude/scripts/test/test_vcs_provider.sh` | `mcp_tool_hint` の新行に対するテストを追加 |
| `.claude/skills/issue-mr-flow/SKILL.md` | 全体フロー表へ新5-3を追加し旧5-3/5-4を繰り下げ、ステップ数41へ、新節「マージ前の関連issue通知（flow-id 5-3）」、MCPフォールバック対応表 |
| `.claude/skills/commit/SKILL.md` | コミットを行うflow-id一覧 `5-3` → `5-4` |
| `.claude/skills/resolve-conflict/SKILL.md` | 「5-2の次は5-3」の記述を 5-3（新設ステップ）へ更新 |
| `.claude/rules/git-workflow.md` | Draft解除 5-3→5-4、マージ 5-4→5-5、コミットflow-id一覧 |
| `.claude/rules/docs-workflow.md` | ステップ数41、コミットflow-id一覧 |
| `.claude/docs/spec/issue-mr-workflow.md` | 提供関数表へ `add_issue_comment`、MCPフォールバック節、ステップ数41、flow-id参照、影響範囲（issue #86）、未決定事項 |
| `.claude/docs/ddr/0041-…md` | 新規（挿入位置と人間承認必須の設計判断） |
| `.claude/docs/README.md` | DDR一覧へ0041 |

## 触ってはいけない範囲

- **`.claude/docs/spec/*.md` の過去issueごとのchangelog（「影響範囲」節）と `.claude/docs/ddr/*.md`
  の本文は、flow-id の改番に合わせて書き換えない**（`.claude/rules/docs-workflow.md`）。
  例: `.claude/docs/spec/check-base-conflicts.md`「影響範囲 / issue #46」の「旧5-2→5-3、
  旧5-3→5-4。全39→40ステップ」は**当時の記録**であり、そのまま残す。
- `add_mr_comment` の既存挙動（宛先はPR/MR）は変更しない。

## 検証

1. `bash -n` で全変更 `.sh` の構文チェック。
2. `bash .claude/scripts/test/test_vcs_provider.sh` が `failures=0` であること。
3. `require_vcs_cli` 経由で `add_issue_comment` が正しいMCPツール名を提示して失敗すること
   （この実行環境には `gh`/`glab` が無いため、CLI経路そのものは実行できない）。
4. プロバイダ固有関数をスタブへ差し替え、`add_issue_comment` が
   `github_add_issue_comment` / `gitlab_add_issue_comment` へ正しく委譲すること。
5. MCP経路（`mcp__github__add_issue_comment`）で実際に1件投稿できることの確認は、
   **ユーザーの承認を得てから**行う（承認なしに外部へ投稿しないという本ステップの方針を、
   検証自体でも守る）。CLI経路の実機確認は未検証として spec の「未決定事項・懸念点」へ残す。
