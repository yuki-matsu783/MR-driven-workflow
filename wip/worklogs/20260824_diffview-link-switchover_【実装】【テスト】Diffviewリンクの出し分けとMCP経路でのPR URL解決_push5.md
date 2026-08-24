---
title: worklog: 【実装】【テスト】Diffviewリンクの出し分けとMCP経路でのPR URL解決
type: log
description: issue #205 フェーズ3の作業ログ。個別作業計画の作成から実装・テスト追加まで
tags: [worklog, implementation, issue-mr-flow]
keywords: [get_mr_diff_url, git ls-remote, compare_url, diff_url, ディスパッチャ, 経路テスト, 空振り]
---

# worklog: 【実装】【テスト】Diffviewリンクの出し分けとMCP経路でのPR URL解決

対象: issue #205「defaultブランチとの差分リンクをPR/MRのDiffviewへ変更する」（2026-08-24）。
全体作業計画: `wip/plans/diffview-link-switchover.md`
個別作業計画: `wip/plans/【実装】【テスト】Diffviewリンクの出し分けとMCP経路でのPR URL解決.md`
push回数: 5

## 試したこと

- flow-id 3-1: 個別作業計画を作成した。**mdを先に書き、HTMLを後から写した**
  （フェーズ2の敵対的レビュー1回目で「HTMLにしか無い記述がある」と指摘された順序の逆をやる）。
- 計画HTMLに対して `wip/plans/REVIEW-POINTS.md` の検査を全件実行した。
  - 自己完結（外部を読みに行く記述）: 0件
  - テンプレートの埋め忘れ（`<!-- ここに書く`）: 0件
  - 重複ID・リンク切れ: いずれも無し
  - 表の `td`/`th` の列数: 全表で揃っている
  - md/HTMLの見出し突き合わせ: **完全一致**（片側にしか無い節が0）
- **HTML生成時に、コードブロック中の `*` を `[*]` へ置換しかけて戻した。** MCPツールの本文で
  アスタリスクが失われる事象（フェーズ2で観測）を意識しすぎたためだが、**この置換が要るのは
  MCPツールへ渡す本文だけ**で、Git管理下のファイルには不要である。置換したままだと
  md（素の `*`）とHTML（`[*]`）が食い違い、まさに直したばかりの同期漏れを再発させていた。

## うまくいったこと

- 計画へ**巻き添えの確認**を明示的に書けた。実装のスケッチをそのまま書くと
  `current_sha: unbound variable` になることに、コードを読んだ段階で気づけた
  （`current_sha` の算出が挿入位置より後ろにある）。計画に「置き換え前後の形を両方書く」という
  `wip/plans/REVIEW-POINTS.md` の観点が効いた。
- **`get_mr_diff_since_url` を触らない**という調査結果の判断のおかげで、変更範囲が
  4ファイル（Github.sh / Gitlab.sh / Provider.sh / post-push-compact-prompt.sh）＋テスト1ファイルに収まった。

## ダメだったこと

- 上記の `[*]` 置換（自分で入れて自分で戻した）。

## 次の一歩

- flow-id 3-2 の直後に敵対的レビュー（フェーズ3・1回目）を実行する。
- flow-id 3-6: 作業1〜4を実装し、**検証3（意図的に壊してテストが落ちることの確認）**まで行う。

---
