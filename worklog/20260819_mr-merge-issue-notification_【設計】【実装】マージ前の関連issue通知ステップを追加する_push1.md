---
title: worklog 20260819 マージ前の関連issue通知ステップの追加 push1
type: log
description: issue #86でadd_issue_comment新設とflow-id 5-3追加を行った際の試行錯誤ログ
tags: [worklog, issue-mr-flow, notification]
keywords: [add_issue_comment, flow-id, 繰り下げ, 差し込み位置, changelog, mcp_tool_hint, 8関数, ドッグフーディング]
---

# worklog: 【設計】【実装】マージ前の関連issue通知ステップを追加する

対象: issue #86「マージ前に今回のMRが影響する関連issueを特定し通知するステップを追加する」（2026-08-19）。
全体作業計画: 無し（非対話的セッションのためflow-id 1-4/1-5を省略）
個別作業計画: `plans/【設計】【実装】マージ前の関連issue通知ステップを追加する.md`
push回数: 1

## 試したこと

- flow-idの繰り下げ対象を洗い出すため、`5-3` `5-4` `40ステップ` `全体フロー` をリポジトリ全体で
  grepした。ヒットは11ファイル。うち `docs/ddr/*.md` 本文と `docs/spec/*.md` の「影響範囲」節は
  point-in-timeの記録のため除外対象と判断した。
- 節の差し込み位置の検討。`## defaultブランチとのコンフリクト検知・解消（flow-id 5-2）` の直後へ
  入れる案を採った。直前の節の末尾は「gitが検知できない衝突がある」というその節固有の説明で
  終わっており、係り先が変わる問題は起きない（docs-workflow.mdのルール）。
- 新ステップの手順を、実際に本対応の差分に対して回してみた（ドッグフーディング）。
- 実機投稿の検証を、MCP経路（`mcp__github__add_issue_comment`）で issue #67 に対して行った。

## うまくいったこと

- `add_issue_comment` を `add_mr_comment` の**別関数**として追加する方針。MCP経路では両者とも
  `mcp__github__add_issue_comment` に収束するが、`issue_number` へ渡す値がPR番号か通知先issue番号かで
  意味が違う。対応表でこの差を表現するには関数を分ける必要があった。テストでも
  「`add_mr_comment` のヒント文が `PR番号` のままであること」を明示的に固定して、将来の混同を防いだ。
- 差し込み後、python側で `'\n'.join(lines[:i])` の末尾要素が空文字列だったため**空行が1つ食われて**
  見出しが直前の段落へ密着した。前後3行を目視確認するルール（docs-workflow.md）どおりに確認して
  すぐ気づけた。ルールが実際に機能した実例。
- ドッグフーディングで3類型の判定が候補を5件→1件に絞った。「キーワードが一致しただけのissueへ
  機械的に投稿しない」という設計意図が実際に効くことを確認できた。

## ダメだったこと

- **`search_issues` のMCP版（`mcp__github__search_issues`）だけでは候補が3件しか返らず、
  実際に影響のある #67 が漏れた。** セマンティック検索が「flow-id」「Draft解除」等の語に強く
  引っ張られたためと思われる。openのissue一覧（`list_issues`）と突き合わせて初めて #67 に
  気づいた。SKILL.mdの手順では `search_issues` を候補の起点として書いているが、**取りこぼしうる**
  ことは記録しておく（検索結果だけを鵜呑みにせず、openのissue一覧にも目を通すのが実務上は確実）。
  手順の改訂まではしていない（本issueの範囲を超えるため。必要なら別issue）。
- **spec のMCPフォールバック節が「プロバイダ依存の8関数」と書いていたが、実際は10関数だった。**
  issue #68・issue #61 で関数を増やした際の更新漏れ。`grep 'require_vcs_cli .* || return 1'` で
  実数を数えて11（本対応分を含む）へ修正した。**「N関数」のように数を本文へ書くと、増減のたびに
  更新が要る**という一般的な問題の実例。

## 次の一歩

- CLI経路（`gh issue comment` / `glab api .../issues/<iid>/notes`）の実機確認。`gh`/`glab` のある
  ローカル環境で実施し、確認できたら spec の「未決定事項・懸念点」から該当項目を削除する。
- 人間のレビュー往復（flow-id 3-3/3-4・3-8/3-9・4-3/4-4・4-8/4-9）。
