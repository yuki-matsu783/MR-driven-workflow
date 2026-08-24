---
title: 全体作業計画: defaultブランチとの差分リンクをPR/MRのDiffviewへ変更する
type: plan
description: issue #205 の全体作業計画。get_mr_diff_url系をPR/MR Diffviewページへ出し分け、MCP経路でも成立させる
tags: [plan, issue-mr-flow, review-links]
keywords: [get_mr_diff_url, Diffview, Compare, files, diffs, MCP経路, post-push-compact-prompt, レビューコメント, Provider.sh, フォールバック]
---

# 全体作業計画: defaultブランチとの差分リンクをPR/MRのDiffviewへ変更する（issue #205）

- issue: #205
- ブランチ: `claude/pr-mr-diffview-link-yxim1l`

## 目的・背景

pushのたびに `post-push-compact-prompt.sh` が送るレビュー依頼メッセージの「defaultブランチとの
差分」リンクは、現在 GitHub/GitLab いずれも**汎用のCompareページ**（`/compare/base...head` /
`/-/compare/base...head`）を指している。このページはPR/MRに紐づいていないため、開いた先で
**レビューコメント（インラインコメント）を付けられない**。

レビュー依頼メッセージの目的は「ここを見てレビューしてほしい」と示すことなので、リンク先は
コメントを付けられるビュー（GitHub: PRの `/files`、GitLab: MRの `/diffs`）であるべきである。

## 変更対象

| 領域 | 変更の見込み |
|---|---|
| `.claude/scripts/src/vcs/Github.sh` / `Gitlab.sh` | `*_get_mr_diff_url` / `*_get_mr_diff_since_url` がMR/PR URLの有無で出し分ける |
| `.claude/scripts/src/vcs/Provider.sh` | 上記ディスパッチャの引数追加、MR/PR URLのCLI非依存な解決手段 |
| `.claude/hooks/post-push-compact-prompt.sh` | 解決したMR/PR URLを差分リンクの組み立てへ渡す配線 |
| `.claude/scripts/test/test_vcs_provider.sh` | 新仕様の単体テスト（出し分けの両分岐） |
| `.claude/docs/spec/issue-mr-workflow.md` / `.claude/docs/ddr/` | 仕様と意思決定の記録 |

## 方針

1. **`get_mr_diff_url` 系は純粋関数のまま**にし、MR/PR URLを**引数で受け取る**形へ拡張する
   （関数の中でCLI・APIを呼ばない）。渡されなければ現行のCompareページを返す。
   既存の `get_diff_anchor_base_url`（issue #127）が同じ形（`mr_url` が空ならCompareへ縮退）を
   既に採っているため、設計を揃える。
2. **MR/PR URLの解決手段は呼び出し元（hook）側の責務**とする。CLI経路は現行どおり
   `get_mr_for_branch`。**MCP経路（`gh`/`glab` 不在）でどう解決するかを本issueの調査で決める**。
3. **後退させない**。MR/PR URLをどうしても解決できない場合は現行のCompareページのまま送る。

### ユーザーからの追加要望（MCP経路でも成立させる）

issueの受け入れ条件は「MCP経路ではCompareのままでよい（後退しないこと）」だが、ユーザーから
**「mcpツールのみの環境でもやりようはあると思うので検討してほしい」**という追加要望がある。

hookはMCPツールを呼べない（hookはAIエージェントではなくシェルプロセスである）ため、
「hookがMCPを叩く」という解法は成立しない。**hookがローカルで参照できる情報からMR/PR URLを
導けないか**を調査する。候補は次の3つで、フェーズ2で評価する。

| 案 | 概要 | 懸念 |
|---|---|---|
| A. `git ls-remote` | GitHubは `refs/pull/<n>/head` を、GitLabは `refs/merge-requests/<n>/head` を公開している。HEADのSHAと突き合わせてPR番号を得る | pushのたびに1往復のネットワークI/O。refの伝播遅延。fork元PRの扱い |
| B. ローカル状態ファイル | AIエージェントがMCPで得たPR番号を `wip/state/` へ保存し、hookが読む | エージェントが書き忘れると効かない。書く契機の定義が要る |
| C. `HANDOFF.md` のヘッダ | 既存の `- PR: #146（URL ）` 行を読む | HANDOFF.mdの表記ゆれに弱い。フォーマットへの依存が増える |

**単一案に決め打ちせず、組み合わせ（安いものから順に試すチェーン）も選択肢に含める。**

## やらないこと

- `get_mr_diff_since_url`（前回push〜今回pushの差分）の意味論そのものの変更。ただし
  Diffviewへの出し分けは同じ問題を持つため、対象に含めるかはフェーズ2で判断する。
- 差分アンカー（`#diff-<hash>`）の算出方法の変更。土台URLが変わればアンカーの効き方も
  変わりうるため、**整合の確認は行う**が算出ロジックには手を入れない。
- GitLab MCPサーバー対応（`.claude/skills/issue-mr-flow/references/mcp-fallback.md` 第5節のとおり対象外）。

## フェーズ2〈調査〉

**実施する。** 方針2（MCP経路でのMR/PR URL解決）が未決であり、これを決めないと実装に入れない。

調査項目:

1. `git ls-remote` によるPR番号解決の実現可能性（この実行環境で実測する）。
   コスト（所要時間）・伝播遅延・fork元PRでの挙動。
2. GitHub `/pull/<n>/files` / GitLab `/-/merge_requests/<n>/diffs` の妥当性（URL形式の裏取り）。
3. `get_mr_diff_since_url` をDiffviewへ寄せられるか（GitHubは `/files` に範囲指定の口があるか、
   GitLabは `?start_sha=` があるか）。
4. 差分アンカー（`get_diff_anchor_base_url`）との重複・整合。土台が二重に決まらないか。
5. 影響を受ける既存テスト・spec記述の洗い出し。

## フェーズ3〈作業〉

調査結果をもとに `【実装】【テスト】` の個別計画を立てて実装する。

## フェーズ4〈反映〉

**実施する（4-1の洗い出しまでは必ず通る）。** 見込みは次のとおりで、確定は flow-id 4-1 で行う。

- `.claude/docs/spec/issue-mr-workflow.md` の「提供関数」表（`get_mr_diff_url` の行）と
  レビュー依頼メッセージの節。
- DDR新規（MCP経路でのMR/PR URL解決方式の選定と却下案）。issue番号ベースで `i0205-01`。
- `.claude/skills/issue-mr-flow/references/mcp-fallback.md`（hookの縮退表・Provider関数対応表）。

## 検証

- `bash .claude/scripts/test/test_vcs_provider.sh` が `failures=0` で通ること。
- CLI経路・MCP経路の両方で、レビュー依頼メッセージの「defaultブランチとの差分」リンクが
  期待どおり出し分けられること（実測できない経路は、関数単位のテストで担保する）。
- 既存の全単体テストが通ること（回帰が無いこと）。

## リスク

- **URL形式の推測**: DDR i0013-01 は「MR/PRのURL文字列へsuffixを推測で付け足す」案を却下している。
  本issueはその判断を部分的に覆すことになるため、**なぜ今なら妥当なのか**をDDRへ明記する必要がある
  （`get_diff_anchor_base_url` が既に `<mrUrl>/diffs` を実機確認済みで採用している前例がある）。
- **hookの実行コスト**: `post-push-compact-prompt.sh` はpushのたびに走る。ネットワークI/Oを
  足すと体感に響く（git bashの外部プロセス起動は約95ms/回）。
