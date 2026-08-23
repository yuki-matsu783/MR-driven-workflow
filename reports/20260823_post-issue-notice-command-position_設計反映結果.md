---
title: post-issue-create-notice.shコマンド位置判定化 設計反映結果
type: report
description: issue #149。実装内容をcommand-position.md・issue-mr-workflow.md・DDR i0149-01・shell-script-style.mdへ反映した結果（フェーズ4）
tags: [spec, ddr, issue-149, 設計反映]
keywords: [command-position.md, issue-mr-workflow.md, DDR, i0149-01, 敵対的レビュー, spec反映]
---

# post-issue-create-notice.shコマンド位置判定化 設計反映結果

対象: issue #149 / 個別反映計画
`plans/【設計反映】post-issue-create-noticeコマンド位置判定化のspec反映.md`

## 実施内容

1. `.claude/docs/spec/command-position.md` を更新した（利用元・公開インターフェース表・
   判定の3段〈§1縮退判定式の違い・§3相違点リスト・§4保守的フォールバック〉・呼び出し側の
   責務節〈3段ガードの2つの型、型A/型B〉・既知の制約表・未決定事項・影響範囲・frontmatter）。
2. `.claude/docs/spec/issue-mr-workflow.md` の「検知の条件」表・「既知のトレードオフ」節を
   現在の実装に合わせて更新した。
3. `.claude/docs/ddr/i0149-01-post-issue-create-notice.shの検知をコマンド位置判定へ移行する.md`
   を新規作成し、`generate-ddr-list.sh`で`.claude/docs/README.md`のDDR一覧へ反映した。
4. `.claude/rules/shell-script-style.md`へAIアセット反映（create-issue.shの部分一致例が
   縮退経路限定になった旨）を行った。
5. `.claude/hooks/lib/CommandPosition.sh`のコメント誤字を1箇所修正した（ロジックは無変更）。

## 敵対的レビュー（フェーズ4・1回目・計画レビュー）で判明した計画の過小評価

初版計画（command-position.md 4箇所・issue-mr-workflow.md 1箇所のみ）に対し13件の指摘
（blocker 1件・major 8件・minor 3件・nit 1件）を受けた。主な指摘は次のとおり。

- issue-mr-workflow.mdの「検知の条件」表・判定説明が移行前の記述のまま反映対象に無い（blocker）。
- 「呼び出し側（hook）の責務」節が3段ガードの2つの型（型A/型B）を説明していない（major）。
- §3の相違点リストだけでなく§1（縮退判定式）・§4（保守的フォールバック）もgit版と異なる（major）。
- インタプリタ経由の肯定的検知（主検知経路）が相違点リストに無い（major）。
- DDR新設の要否が計画に無い（major）。
- `shell-script-style.md`への反映（AIアセット反映）が計画の根拠なく「無い」とされている（major）。

これらをすべて計画へ反映し、反映対象をcommand-position.md 9箇所・issue-mr-workflow.md 2箇所・
DDR新設・AIアセット反映1件へ拡大した（詳細: 個別反映計画「敵対的レビュー（1回目・計画レビュー）を
踏まえた改訂」節）。

## 敵対的レビュー（フェーズ4・2回目・実装レビュー）で判明した反映内容の不備と修正

flow-id 4-6の反映結果に対し9件の指摘（major 1件・minor 6件・nit 2件）を受け、すべて実機・
実文書で確認のうえ修正した。

| # | 重大度 | 指摘 | 対応 |
|---|---|---|---|
| 1 | major | 既知の制約表のクォートパス行が「インタプリタを介さない直接起動は依然として見逃す」ことを書いていない | 行を2つに分割し、直接起動形式の既知の制約を明記 |
| 2 | minor | DDR「理由5」の「検知漏れを解消した」が実装より強い（インタプリタ経由の形にしか及ばない） | 「インタプリタ経由の形について」と限定し、却下案表も整合 |
| 3 | minor | `_CP_PREFIX_OPTS_WITH_VALUE`の一律適用による検知漏れ（`sudo -n`等）が書かれていない | 既知の制約表へ新規行を追加 |
| 4 | minor | 前置フィルタの超集合性の根拠（既存テストケース）が主張を支えていない | 根拠を差し替え、突き合わせテスト不在を明記 |
| 5 | minor | テストのコメントが古い記述（型A前提）のまま | 型B（遅延初期化）に合わせて2箇所書き換え |
| 6 | minor | 変数代入チェックの順序差が相違点リストに漏れている | リストへ1項目追加 |
| 7 | minor | issue-mr-workflow.mdが型Bの理由を重複して書いている（4箇所目） | command-position.mdへの参照のみに整理 |
| 8 | minor | 「+35%」に測定条件が添えられていない | 性能節へ測定条件を追記 |
| 9 | nit | 既知の制約表を行番号で指している | 類型名で指す表現へ書き換え |
| 10 | nit | DDRのファイル名とtitle・本文見出しが不一致（`.sh`の有無） | ファイル名をtitleへ合わせて改名 |

## 検証結果

```
$ bash -n .claude/hooks/lib/CommandPosition.sh && echo OK
OK
$ bash -n .claude/hooks/post-issue-create-notice.sh && echo OK
OK
$ bash -n .claude/scripts/test/test_post_issue_create_notice.sh && echo OK
OK
$ bash .claude/scripts/test/test_command_position.sh
passed=118 failures=0
$ bash .claude/scripts/test/test_post_issue_create_notice.sh
passed=38 failures=0
$ bash .claude/scripts/test/test_block_direct_git_commit.sh
passed=27 failures=0
$ bash .claude/scripts/src/generate-ddr-list.sh
DDR一覧を更新しました（76件）: .claude/docs/README.md
```

過去のDDR本文・changelogエントリ（issue #53・#39時点の記述）は書き換えていない（新規追記のみ）。

## issueの受け入れ条件との対応

| 受け入れ条件 | 結果 |
|---|---|
| `command-position.md`「未決定事項・懸念点」の更新 | 満たす（issue #149で適用済みへ書き換え、型B・測定条件・超集合性の再確認結果を追記） |
| `issue-mr-workflow.md`「既知のトレードオフ」の更新 | 満たす（検知の条件表・既知のトレードオフ節を更新） |

## 残課題

- フェーズ4の敵対的レビューは2回実施済み（最大3回）。今回の修正はレビュー指摘への対応であり
  新規の反映対象追加を伴わないため、3回目は見送りフェーズ5（クローズ）へ進む。
