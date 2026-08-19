---
title: 【設計反映】check-base-syncの仕様とDDRを正史へ反映する
type: plan
description: issue #67 の個別反映計画（設計反映）。check-base-sync.sh の仕様を spec へ、判断の経緯を DDR へ反映する。
tags: [plan, 設計反映, base-branch, spec, ddr]
keywords: [設計反映, spec, ddr, check-base-sync, fetchOk, 却下案, DDR番号, 0050]
---

# 【設計反映】check-base-syncの仕様とDDRを正史へ反映する（issue #67）

- 全体作業計画: `plans/base-branch-sync-check.md`
- 実装結果（正文）: `reports/20260819_base-branch-sync-check_実装結果.md`
- 調査結果（正文）: `reports/20260819_base-branch-sync-check_調査結果.md`

**`【AIアセット反映】` とは分けている**（`.claude/skills/issue-mr-flow/SKILL.md`「種別を複数併記
する場合／分ける場合」。正史ドキュメントへの記録と運用ルールの改訂は、要求される人間の認知の
種類が違うため）。

## 反映対象の洗い出し（flow-id 4-1）

`plans/` `worklog/` `reports/` の内容のうち、**恒久的に残すべきもの**を次のとおり洗い出した。
洗い出した結果は空ではないため、フェーズ4は省略しない。

| # | 反映先 | 種別 | 反映する内容 |
|---|---|---|---|
| 1 | `.claude/docs/spec/check-base-sync.md` | **新規** | 背景・目的／仕様（引数・出力JSON・判定順序・境界条件）／影響範囲／設定項目／未決定事項 |
| 2 | `.claude/docs/ddr/0050-作業開始時のベースブランチ追従確認は専用スクリプトで検知しユーザー確認を挟む.md` | **新規** | 案A（`sync_branch` 拡張）・案B（`check-base-conflicts.sh` へ相乗り）を却下し案C（専用スクリプト）を採った理由。fetchの失敗を握りつぶさない理由 |
| 3 | `.claude/docs/README.md` | 変更 | DDR一覧・spec一覧へ追記 |
| 4 | `.claude/docs/spec/issue-mr-workflow.md` | 変更 | 「影響範囲」節へ issue #67 のエントリを**追記**（既存エントリは書き換えない） |

**DDR番号は 0050 を使う。** `main` が PR #104（issue #38）で **0049 を使用済み**であることを
確認済み（`.claude/docs/ddr/0049-ドキュメント探索はfrontmatterインデックス検索を第一手段にする.md`）。

## spec に書くこと（`.claude/docs/spec/check-base-sync.md`）

`.claude/docs/spec/check-base-conflicts.md` の構成にそろえる。

1. **背景・目的**: 「衝突しないこと」と「最新であること」は別であり、既存2機構（issue #46 の
   flow-id 5-2・issue #88 の追従監視）はどちらも `hasConflict` を判定軸にしているため
   「遅れているが衝突しない」状態を検知できない。
2. **仕様**: 引数（`--base` / `--head` / `--no-fetch`）・出力JSONの全キー・判定順序
   （fetch → ベースref確認 → `rev-list --left-right --count` → **merge-base の有無を先に判定** →
   3ドット記法のdiff）・終了コードの規約。
3. **判定が信頼できないことを示す3つのキー**（`fetchOk` / `isShallow` / `hasCommonHistory`）と、
   呼び出し側が取るべき対応。
4. **影響範囲**: `SKILL.md` の新節・`issue-mr-resume` の手順7・単体テスト。
5. **未決定事項・懸念点**: git bash実機未確認／巨大リポジトリでの所要時間未実測／merge-baseが
   shallow境界の外にある場合の挙動が再現できていない／50件という上限が暫定値であること。

## DDR に書くこと（0050）

- **決定**: 作業開始・再開時のベースブランチ追従確認は、専用スクリプト `check-base-sync.sh` で
  **検知だけ**を行い、取り込むかどうかは `AskUserQuestion` でユーザーへ確認する。
- **却下案A**: `sync_branch()` を拡張してベースブランチを自動マージする。→ issueの受け入れ条件が
  「無断で取り込まない」ことを求めており、かつ低レベル関数の副作用として作業ツリーが変わる。
- **却下案B**: `check-base-conflicts.sh` へ behind 判定を相乗りさせる。→ 判定軸が違う。出力JSONへ
  別軸のキーを足すと、呼び出し側が `hasConflict` だけを見て安心する現在の使い方と噛み合わない。
- **fetchの失敗を握りつぶさない理由**: `check-base-conflicts.sh` が `|| true` を許容できるのは
  flow-id 5-2 で必ずもう一度通るためだが、本スクリプトは検知そのものが目的で、見逃しが後段で
  拾われない。`fetchOk` を出して呼び出し側が識別できるようにした。
- **flow-idを増やさない理由**: issue #88（DDR 0039）と同じ扱い。サブコマンドの手順の一部であって
  フローの新しい段ではない。

## この計画で決めないこと（スコープ外）

- `.claude/rules/git-workflow.md` への追記（**`【AIアセット反映】` の担当**。別ファイルで計画する）
- `check-base-conflicts.sh` の変更
- 未決定事項の解消（git bash実機確認等）。specの「未決定事項」へ記録するに留める

## 検証

```bash
bash .claude/scripts/src/extract-frontmatter.sh .    # frontmatterの取り込み確認
ls .claude/docs/ddr/ | grep '^0050'                  # DDR番号の重複が無いこと
bash .claude/scripts/src/check-base-conflicts.sh | jq -c '{hasConflict,duplicateDdrNumbers}'
```
