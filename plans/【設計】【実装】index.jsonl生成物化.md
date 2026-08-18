---
title: 【設計】【実装】index.jsonl生成物化
type: guide
description: index.jsonlをGit管理から外しSessionStart hookで自動再生成する個別作業計画
tags: [frontmatter, index-jsonl, session-start, gitignore]
keywords: [extract-frontmatter, index.jsonl, gitignore, SessionStart, git rm --cached, DDR0024, flow-id5-1]
---

# 【設計】【実装】index.jsonl生成物化

issue #36 / 全体作業計画: `plans/whimsical-launching-reef.md`

## 設計（詰める論点の結論）

全体作業計画に列挙した6つの論点を以下のとおり確定する。

### 1. 実装場所

`.claude/hooks/session-start.sh` に、既存の `build_context`（issue/PR情報のコンテキスト注入）とは別の独立した関数 `regenerate_frontmatter_index` を追加する。責務が異なる（`build_context` はhook出力＝追加コンテキストの生成、こちらはファイルシステムへの副作用のみ）ため関数を分離する。

**重要な実装上の注意**: SessionStart hookの標準出力は `write_additional_context` が出力するJSON1行のみが期待される契約になっている。`extract-frontmatter.sh` は `wrote: ...` 等をstdoutへ出すため、そのまま呼ぶとhookの出力契約を壊す。**`regenerate_frontmatter_index` 内で `extract-frontmatter.sh` の標準出力・標準エラー出力は両方 `/dev/null` へ捨てる**（失敗してもコンテキスト注入自体は継続する非侵襲的設計を貫くため、エラーメッセージをコンテキストに含めることもしない）。

呼び出し位置: `agent_id` チェック・`CLAUDE_PROJECT_DIR` チェックの後、`build_context` の呼び出しとは独立に（成否に関わらず）実行する。

### 2. 失敗時の挙動

fail-open。`extract-frontmatter.sh` が失敗してもセッション開始・コンテキスト注入はブロックしない（既存の `session-start.sh` 全体の非侵襲的方針を踏襲）。戻り値は無視する。

### 3. `.gitignore` パターンの書き方

`**/index.jsonl` の一括パターンを採用する。個別列挙（15箇所）は、新規ディレクトリにfrontmatter付きmdが増えるたびに追記が必要になり、本issueが解消しようとしている「流し忘れ」と同種のリスクを`.gitignore`側に移すだけになるため採用しない。理由コメント（issue #36・DDR 0024への参照）を付す。

### 4. DDR 0021却下案4（自動削除）の再評価

**却下を維持する。理由を更新する。** 従来の却下理由は「スコープ外ファイルを消しうる」だったが、Git管理下から外れたことで「陳腐化したindex.jsonlがコミットに残り続ける」という実害は消える一方、**誤ったディレクトリ指定でindex.jsonlを削除した場合、Git履歴からの復旧手段が無くなる**（`.gitignore`対象のためコミットに存在しない）という新しいリスクが生じる。このリスクを踏まえ、スクリプトによる自動削除は今回も導入しない（据え置き）。新DDR 0024にこの再評価の経緯を明記する。

### 5. 既存15箇所の移行手順

1. `.gitignore` に `**/index.jsonl` パターンを追加
2. 15箇所の `index.jsonl` を `git rm --cached` でGit管理から除外（ワーキングツリー上のファイルは残す。`--cached` オプションにより物理削除はされない）
3. 上記2点を1つのcommitにまとめる（`.gitignore` 追加だけでは既存の追跡中ファイルは自動的にuntrackedにならないため、`git rm --cached` と対で行う必要がある）

対象15ファイル: `index.jsonl`（ルート）, `.claude/agents/index.jsonl`, `.claude/docs/index.jsonl`, `.claude/docs/ddr/index.jsonl`, `.claude/docs/spec/index.jsonl`, `.claude/rules/index.jsonl`, `.claude/skills/apply-mr-workflow-to-project/index.jsonl`, `.claude/skills/canvas-report/index.jsonl`, `.claude/skills/commit/index.jsonl`, `.claude/skills/issue-create/index.jsonl`, `.claude/skills/issue-mr-flow/index.jsonl`, `.github/ISSUE_TEMPLATE/index.jsonl`, `.gitlab/issue_templates/index.jsonl`, `plans/index.jsonl`, `worklog/index.jsonl`

### 6. `flow-id 5-1` の特殊対応の要否

**完全に不要になるため、関連記述を除去する。** Git管理下から外れる以上、「`plans/index.jsonl` を削除してコミットに含める」という操作自体が成立しない（もともとコミット対象にならない）。以下を変更する。

- `.claude/skills/issue-mr-flow/SKILL.md`:
  - 全体フロー表 flow-id 5-1 の行から「あわせて `plans/index.jsonl` も削除し、`bash .claude/scripts/src/extract-frontmatter.sh .` で `index.jsonl` 群を再生成する」を削除し、「次タスクのために、`plans/` `worklog/` `reports/` を削除し、`HANDOFF.md` をリセットする」のみに簡略化
  - 「## flow-id 5-1での `index.jsonl` の扱い」見出しごと削除
  - 「## PRがflow-id 5-1実施前にマージされてしまった場合の対処」節内の「`plans/index.jsonl`の削除と`index.jsonl`群の再生成も含む」という言及を削除
- `.claude/rules/docs-workflow.md`: `plans/` 行の「**flow-id 5-1では`plans/*.md`とあわせて`plans/index.jsonl`も削除し、`index.jsonl`群を再生成する**（...）」という括弧書きを削除

## 実装内容

### 変更ファイル

| ファイル | 変更内容 |
|---|---|
| `.gitignore` | `**/index.jsonl` パターンを理由コメント付きで追加 |
| 15箇所の `index.jsonl` | `git rm --cached` |
| `.claude/hooks/session-start.sh` | `regenerate_frontmatter_index` 関数を追加し、非侵襲的に `extract-frontmatter.sh .` を実行 |
| `.claude/skills/issue-mr-flow/SKILL.md` | 上記「6.」のとおり |
| `.claude/rules/docs-workflow.md` | 上記「6.」のとおり |
| `.claude/rules/markdown-frontmatter.md` | 「`index.jsonl` はGit管理下にあるため、commitの直前に1回流す」という記述を、SessionStart自動化後の説明へ書き換え（Git管理下でなくなった旨・自動再生成の仕組みを明記） |

`.claude/docs/spec/extract-frontmatter.md`・DDR新規作成・`.claude/rules/directory-structure.md`の確認は、設計判断の記録という性質上フェーズ4（反映）で行う（全体作業計画のフェーズ3/4区分に従う）。

### 動作確認

- `bash -n .claude/hooks/session-start.sh` で構文チェック
- ローカルで `regenerate_frontmatter_index` 相当の処理を単体実行し、`index.jsonl` が再生成されることを確認
- `git status` で15箇所の `index.jsonl` が完全に無視されること（`git status --ignored` で `.gitignore` に捕捉されていることも確認）
- `tests/test_extract_frontmatter.sh` が既存どおりパスすること
