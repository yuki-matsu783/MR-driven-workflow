---
title: 【設計反映】【AIアセット反映】前置フィルタパターンの記録
type: plan
description: フェーズ3で確定した前置フィルタパターン（バックスラッシュ除去・大文字小文字非依存比較で超集合を保つ）をDDR・spec・ルールへ反映する個別反映計画（issue #159）
tags: [plan, hooks, 前置フィルタ, ddr, issue-159]
keywords: [設計反映, AIアセット反映, DDR, command-position, shell-script-style, 超集合]
---

# 【設計反映】【AIアセット反映】前置フィルタパターンの記録

## 前提

- 上位の計画: `plans/reduce-hook-misfire-cost.md`（全体作業計画。flow-id 1-4「フェーズ4〈反映〉」節）
- 依拠する作業結果: `reports/20260823_reduce-hook-misfire-cost_前置フィルタ実装.md`
  （フェーズ3の実装結果。敵対的レビュー1回目の指摘を反映済み）
- **本計画は、フェーズ3の実装作業と同一セッション内で連続して作成した。** 設計反映・AIアセット
  反映の内容は、フェーズ3の敵対的レビューで発見された設計判断（超集合の反例・issue #149との
  整合性の修正）と直接つながっているため、間を空けずに反映する。

## この計画で何をするか

フェーズ3で確定した前置フィルタパターンの意思決定を、`.claude/docs/ddr/` へDDRとして記録し、
関連するspecドキュメント（`command-position.md`）を最新化する（**設計反映**）。あわせて、
このパターンが再利用可能であることを `.claude/rules/shell-script-style.md` へ反映する
（**AIアセット反映**）。

**併記する理由**: 両者は同じ実装（前置フィルタの最終形）を異なる読み手（意思決定の経緯を追う人＝
DDR、次に同じパターンを使う人＝ルール）向けに記録するだけであり、評価軸・確認内容が重複する。
フェーズごとに分けて合意を取る必要が無い（`.claude/skills/issue-mr-flow/SKILL.md`「種別を
複数併記する場合」の基準）。

## 変更対象

| ファイル | 操作 | 何をするか |
|---|---|---|
| `.claude/docs/ddr/i0159-01-hookの前置フィルタは純粋関数によるバックスラッシュ除去と大文字小文字非依存比較で超集合を保つ.md` | 新規 | 前置フィルタパターンの意思決定記録（背景・決定・理由・却下案・影響） |
| `.claude/docs/README.md` | 変更 | `generate-ddr-list.sh`によるDDR一覧の再生成（生成物） |
| `.claude/docs/spec/command-position.md` | 変更 | 「利用元」節へ前置フィルタの存在を追記。「未決定事項・懸念点」節のpost-issue-create-notice.sh行へ、前置フィルタとissue #149の関係を追記 |
| `.claude/rules/shell-script-style.md` | 変更 | 「外部プロセス起動のコスト」節へ「hookの前置フィルタ」小節を新設 |

## 方針

- DDRの範囲は本issueが実際に変更する2本のhookに限定し、push系2本（issue #70/PR #157が担当。
  本計画作成時点で未マージ）の実装内容までは代弁しない（敵対的レビューで指摘された懸念への対応）。
- `command-position.md`は判定本体（`CommandPosition.sh`）の仕様書であるため、前置フィルタの
  詳細な設計判断（バックスラッシュ除去の理由等）までは書かず、「前置フィルタが存在すること」
  「判定本体が受け取る入力集合は変わらないこと」「詳細はDDR参照」という要約に留める
  （spec文書としての一貫した抽象度を保つため）。
- `shell-script-style.md`への追記は、他のhookが同じ状況（`if`を持てない・持たない）に
  直面したときに再利用できる一般化した記述にする（issue #159固有の事情ではなく、パターンとして
  書く）。

## やらないこと（スコープ外）

- `.claude/docs/spec/issue-mr-workflow.md`の更新: 同ファイルは対象2本のhookをアーキテクチャ
  概要レベルで言及するのみで、内部の判定メカニズムを記述していないため、更新は不要と判断した
  （フェーズ3のreportsで確認済み）。
- push系2本のhookへのDDR適用（issue #70/PR #157の範囲）。

## 検証

```bash
bash .claude/scripts/src/generate-ddr-list.sh
git diff --stat .claude/docs/README.md   # 生成物の差分が1行のみであること
grep -c '前置フィルタ' .claude/rules/shell-script-style.md  # 新設した小節が存在すること
```

合格条件: DDR一覧が再生成され差分が反映されている。`command-position.md`・
`shell-script-style.md`の追記箇所が、実際のhook実装（`raw_hints_at_git_commit` /
`raw_hints_at_issue_create`）の内容と食い違わない。

## issueの受け入れ条件との対応

本個別計画は「フェーズ4〈反映〉」に対応し、issue #159の受け入れ条件そのものはフェーズ3の
個別計画で対応済み。本計画が追加で対応するのは、全体作業計画のフェーズ4節（設計反映・
AIアセット反映）である。
