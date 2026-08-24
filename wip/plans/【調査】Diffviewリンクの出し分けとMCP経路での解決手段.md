---
title: 【調査】Diffviewリンクの出し分けとMCP経路での解決手段
type: plan
description: issue #205 の個別調査計画。URL形式の裏取り、MCP経路でのMR/PR URL解決3案の評価、既存機構との整合を調べる
tags: [plan, research, issue-mr-flow]
keywords: [Diffview, files, diffs, git ls-remote, refs/pull, wip/state, HANDOFF, 差分アンカー, get_mr_diff_since_url, フォールバック]
---

# 【調査】Diffviewリンクの出し分けとMCP経路での解決手段（issue #205 / flow-id 2-1）

- 全体作業計画: `wip/plans/diffview-link-switchover.md`
- PR: #206

## この計画で何を調べるか

実装（フェーズ3）に入る前に決めなければならない**未決事項**は次の2つである。

1. **Diffview URLの形式が推測でなく裏取りできるか。** DDR i0013-01 は「MR/PRのURL文字列へ
   suffixを推測で付け足す」案を一度却下している。同じ轍を踏まないための根拠が要る。
2. **MCP経路（`gh`/`glab` CLI不在）で、hookがMR/PR URLをどう解決するか。** hookはシェル
   プロセスでありMCPツールを呼べないため、ローカルで参照できる情報から導く必要がある。

上記に付随して、既存機構との整合（差分アンカー・`get_mr_diff_since_url`）も確認する。

## 調査項目（問いの形）

### Q1. GitHub `/pull/<n>/files` は「レビューコメントを付けられるビュー」か。URL形式の根拠は何か

- 根拠として何が使えるか（GitHub APIが返す `html_url` からの導出か、公式ドキュメントか、
  リポジトリ内の既存の実機確認済み記述か）。
- GitLab `/-/merge_requests/<n>/diffs` は `gitlab_get_diff_anchor_base_url` が既に採用済み。
  その採用時の根拠（実機確認の記録）が本issueへ流用できるか。

### Q2. DDR i0013-01 が却下した案と、本issueがやろうとしていることの違いは何か

- 却下の理由が本issueにも当てはまるのか、当てはまらないならなぜか。
- **当てはまるなら本issueの前提そのものが崩れる**ため、最初に確認する。

### Q3. MCP経路でMR/PR URLを解決する3案のうち、どれが成立するか

| 案 | 検証すること |
|---|---|
| A. `git ls-remote origin 'refs/pull/*/head'` | **この実行環境で実際に実行し**、PR #206 が引けるか。所要時間。HEADのSHAと突き合わせられるか。GitLabの `refs/merge-requests/*/head` に相当物があるか |
| B. `wip/state/` の状態ファイル | 書く契機をフローのどこへ置けるか。`wip/state/review-links/` と同じ形にできるか。書き忘れたときの縮退先 |
| C. `HANDOFF.md` のヘッダ `- PR:` 行 | 表記の安定性（`update-handoff-progress.sh` の `set-header` が生成する形は決まっているか）。パースの堅牢性 |

- 単独ではなく**チェーン（安い順に試す）**にする価値があるか。
- **hookはpushのたびに走る**ため、各案のコスト（外部プロセス起動・ネットワークI/O）を測る。

### Q4. `get_mr_diff_since_url`（前回push〜今回pushの差分）もDiffviewへ寄せるべきか

- GitHubのPR `/files` に「特定のSHA範囲だけを見る」口があるか。
- 無い場合、`since_url` はCompareのまま残すのが妥当か。**2つのリンクの意味が食い違わないか**。

### Q5. 差分アンカーの土台（`get_diff_anchor_base_url`）と二重にならないか

- `diff_url` がDiffviewになると、`anchor_compare_url` に渡る値も変わる。
- GitHubのアンカー `#diff-<sha256>` は**PRの `/files` ページでも機能するか**（Compareページ
  でのみ確認されている）。機能しないならアンカーが壊れる——**これは後退である**。
- GitLab側は `gitlab_get_diff_anchor_base_url` が既に `<mrUrl>/diffs` を返すため、
  `diff_url` と土台が同じ値になる。重複した組み立てにならないか。

### Q6. 影響を受ける既存のテスト・spec記述はどれか

- `test_vcs_provider.sh` の該当アサーション。
- `.claude/docs/spec/issue-mr-workflow.md` の「提供関数」表・レビュー依頼メッセージの節・
  changelog（**過去のchangelogエントリは書き換えない**）。
- `references/mcp-fallback.md` のhook縮退表。

## 調べ方

- **Q1・Q2・Q5・Q6は、リポジトリ内のドキュメントとコードを読んで答える。**
  ドキュメント探索は `doc-search`（frontmatterインデックス）を第一手段にする。
- **Q3の案Aは、この実行環境で実際にコマンドを実行して測る。** 机上で「できるはず」と
  書かない。
- **Q4のうちGitHubのURL仕様は、確定的な根拠が得られなければ「不明」と記録する。**
  推測を結論として書かない。

## やらないこと（スコープ外）

- 実装そのもの（フェーズ3）。この計画では方針の材料を集めるだけで、コードは変更しない。
- GitLabの実機確認。この環境にGitLabが無く、GitLab CE への実機確認は issue #127 の記録を
  参照するに留める（新たな実機確認が必要と分かった場合は、その事実を結果へ書く）。
- ブラウザでの目視確認。この環境にブラウザが無いため、**「実際にコメントが付けられるか」は
  目視では確認できない**。この制約自体を結果へ明記する。

## 検証（この調査が完了したと言える条件）

- Q1〜Q6のすべてに、**根拠付きの答えか「不明」のいずれか**が書かれていること。
- Q3について、採用する案（またはチェーン）が1つに決まっていること。
- 結果が `wip/reports/20260824_diffview-link-switchover_調査結果.md` と同名の `.html` に
  記録されていること。
