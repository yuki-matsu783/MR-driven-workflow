---
title: 反映結果 ベースブランチ追従確認の設計反映・AIアセット反映
type: report
description: issue #67 のフェーズ4の反映結果。spec・DDRの新規作成と、git-workflow.md への追記の記録。
tags: [report, base-branch, spec, ddr, ai-asset]
keywords: [反映結果, 設計反映, AIアセット反映, check-base-sync, DDR0050, git-workflow, rebase, 影響範囲]
---

# 反映結果: 設計反映・AIアセット反映（issue #67 フェーズ4）

- 個別反映計画（設計反映）: `plans/【設計反映】check-base-syncの仕様とDDRを正史へ反映する.md`
- 個別反映計画（AIアセット反映）: `plans/【AIアセット反映】追従確認の入口とrebase方針をルールへ書く.md`
- 実施日: 2026-08-19

## flow-id 4-1: 反映対象の洗い出し（結果は空ではない）

`plans/` `worklog/` `reports/` の内容のうち恒久的に残すべきものを洗い出した結果、5ファイルが
対象になった。**空ではないためフェーズ4は省略していない。**

## 設計反映

| ファイル | 種別 | 反映した内容 |
|---|---|---|
| `.claude/docs/spec/check-base-sync.md` | **新規** | 背景・目的（「衝突しないこと」と「最新であること」は別）／仕様（引数・出力JSON全キー・判定順序・実装上の注意）／判定が信頼できないことを示す3つのキー／影響範囲／設定項目／未決定事項5件 |
| `.claude/docs/ddr/0050-作業開始時のベースブランチ追従確認は専用スクリプトで検知しユーザー確認を挟む.md` | **新規** | 決定4点と、却下案A（`sync_branch` 拡張）・案B（`check-base-conflicts.sh` へ相乗り）／`fetchOk` を出す理由／flow-idを増やさない理由／rebaseを推奨しない理由 |
| `.claude/docs/README.md` | 変更 | spec一覧へ `check-base-sync.md`、DDR一覧へ 0050 |
| `.claude/docs/spec/issue-mr-workflow.md` | 変更 | 「影響範囲」節へ issue #67 のエントリを**追記**（既存エントリは1文字も変更していない） |

**DDR番号は 0050 を採った。** `main` が PR #104（issue #38）で 0049 を使用済みであることを、
このブランチへ `main` を取り込んだ時点で確認している。`check-base-conflicts.sh` の
`duplicateDdrNumbers` が空であることも確認済み。

## AIアセット反映

| ファイル | 反映した内容 |
|---|---|
| `.claude/rules/git-workflow.md` | 「ブランチ運用」節へ2項目。(1) 作業開始・再開時の追従確認の**入口**（3地点・`isBehind`・承認まで取り込まない・詳細は `SKILL.md` が正）。(2) **取り込みは `git merge` で行い `git rebase` は使わない**という方針 |

**手順そのものは書いていない。** 判定基準を複数ファイルへ再掲せず、`SKILL.md` の該当節を正とした
（`.claude/REVIEW-POINTS.md`「スキル・ルール・エージェント定義」）。

**rebase方針をルール側へ書いた理由**: 調査で `.claude/rules/` 配下に `rebase` の語が
**1件も無い**ことが分かった（方針を明示していたのは `.claude/skills/resolve-conflict/SKILL.md`
だけ）。全体作業計画が当初「`git-workflow.md` で明示している」と書いていたが事実ではなく、
敵対的レビューの指摘で判明した。追従確認の選択肢に `rebase` を出す場面で根拠を辿れるよう、
結論と参照先だけを1項目置いた。

## 検証

```
$ bash .claude/scripts/src/extract-frontmatter.sh .
（正常終了。新規2ファイルのfrontmatterが取り込まれた）

$ bash .claude/scripts/src/check-base-conflicts.sh | jq -c '{hasConflict,duplicateDdrNumbers}'
{"hasConflict":false,"duplicateDdrNumbers":[]}

$ ls .claude/docs/ddr/ | grep -c '^0050'
1

$ grep -c 'rebase' .claude/rules/git-workflow.md
1
```

- **挿入位置の前後を目視で確認した。** `git-workflow.md` の「ブランチ運用」節は箇条書きだけで
  構成されており、節全体にかかる地の文は無い。空行の重複・次の見出し（`## コミット運用`）への
  密着も起きていない。
- `issue-mr-workflow.md` の「影響範囲」への追記は、**既存エントリの下・`## 未決定事項・懸念点` の
  直前**へ新規エントリとして置いた。過去issueのchangelogは point-in-time の記録であり、
  1文字も書き換えていない（`.claude/rules/docs-workflow.md`）。

## スコープ外にしたもの

| 項目 | 理由 |
|---|---|
| `resolve-conflict` スキル本体の変更 | rebaseを使わない方針は既に書かれており、変える理由が無い |
| `AGENTS.md` / `CLAUDE.md` への追記 | `git-workflow.md` が既に参照されており、階層を増やさない |
| `.claude/REVIEW-POINTS.md` への観点追加 | 今回新しく踏んだ罠は「ヘッダコメントを増やしたら `--help` の行範囲も直す」程度で、汎用の観点にするには弱い（specの「未決定事項」へ記録した） |
| 未決定事項の解消（git bash実機確認等） | specの「未決定事項・懸念点」へ記録するに留めた |
