---
title: worklog: 反映（issue #53）
type: log
description: issue #53のフェーズ4〈反映〉での試行錯誤ログ
tags: [worklog, 反映, hooks, issue-53]
keywords: [設計反映, AIアセット反映, command-position, DDR, note, assets, MCP, truncate]
---

# worklog: 反映（issue #53）

対象: hookの検知をコマンド位置ベースにする（2026-08-21）。
全体作業計画: `plans/hook-command-position-detection.md`
個別作業計画: `plans/【設計反映】コマンド位置判定のspecとDDRを整備する.md`,
`plans/【AIアセット反映】hook誤検知の回避策を実装に合わせて見直す.md`
push回数: 3

## 試したこと

- 反映対象の洗い出しを `grep -rn '部分一致' --include='*.md' .` から始めた。
  ヒット件数が想定の倍あり、半分が
  `.claude/skills/apply-mr-workflow-to-project/assets/.claude/` 配下だった。
- `assets/` の実体を確認した（`git ls-files` が空・`.gitignore` の9行目に
  `/.claude/skills/apply-mr-workflow-to-project/assets/`）。
- `diff -q` で本体と `assets/` のコピーを比較した。

## うまくいったこと

- **`assets/` は `sync-assets.sh` が生成するビルド成果物で、Git管理下に無い。**
  今回の hook 変更を手で二重反映する必要は無く、既に同期済み（`diff -q` で差分なし）。
  反映対象の一覧からは除外してよい。
- 洗い出しの結果、実体側の反映対象は spec 4件（うち1件は新規）・DDR 3件（うち2件は新規、
  1件は `note` のみ）・rules 4件・skills 1件に収まった。
- **`【設計反映】` と `【AIアセット反映】` を別ファイルへ分けた。** 前者は「正史へ何を記録するか」、
  後者は「回避策をどこまで残すか」で、判断の性質が違う。
- AIアセット側の結論が「回避策の削除」ではなく「**いつ必要かを書き分ける**」になった。
  `if` フィルタを変えていないこと・縮退時に部分一致へ落ちることから、回避策が必要な状況は
  依然として残るため。

## ダメだったこと

- **敵対的レビューへの返信が1件、投稿時に途中で切り捨てられた。**
  `mcp__github__add_reply_to_pull_request_comment` の本文に `<` で始まる語
  （入力リダイレクトの記号を含む語）を書いたところ、そこで本文が終わった状態で投稿された。
  **エラーにならず成功として返る**ため、投稿後に `get_review_comments` で末尾を確認するまで
  気づかなかった。記号を避けた補足を追加で投稿して対処した。
  → `.claude/skills/issue-mr-flow/SKILL.md` のMCPフォールバック節へ記録する（AIアセット反映）。
- （記録）フェーズ3の敵対的レビューで、**旧実装が検知していた入力を新実装が取りこぼす**という
  機能後退を2件出していた。自分の20ケース表は「変更前に誤検知していたもの」を中心に組んで
  おり、**「変更前に正しく検知できていたもの」の側が薄かった**。回帰の観点は、直したい側だけ
  でなく壊しうる側から先に組むべきだった。

## 次の一歩

- flow-id 4-6: 2つの個別反映計画に沿って反映を実施する（設計反映 → AIアセット反映の順）。
- `.claude/VERSION` の更新はAIから提案するに留め、決定は人間に委ねる。
