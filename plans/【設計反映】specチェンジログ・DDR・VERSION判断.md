---
title: 【設計反映】specチェンジログ・DDR・VERSION判断
type: plan
description: issue #186 の成果（テンプレート視覚改修）をspecのchangelog・DDR 2本へ反映し、.claude/VERSION の増分を判断する反映計画
tags: [plan, design-reflection, reports-template]
keywords: [issue-mr-workflow.md, changelog, DDR, i0186-01, i0186-02, VERSION, generate-ddr-list, 視覚語彙, リンク破断検査]
---

# 【設計反映】specチェンジログ・DDR・VERSION判断（issue #186 / フェーズ4）

## 前提（合意状況）

- 上位の計画: `plans/vivid-report-canvas.md`（flow-id 1-5 で包括指示を承認とみなし合意）
- 入力: `reports/20260823_vivid-report-canvas_作業結果.md`「設計への反映」の項目1・3、
  および調査結果・worklog・PR #191 のレビュー往復（敵対的レビュー4回・計36件）

## この計画で何をするか

フェーズ3で確定した設計判断のうち、**恒久に残すべきもの**を `.claude/docs/spec/`・
`.claude/docs/ddr/` へ反映し、配布物の版（`.claude/VERSION`）の増分を判断する。
実装・テストコードの修正は伴わないため種別は`【設計反映】`（`【実装反映】`は対象なし）。

## 変更対象

| ファイル | 操作 | 何をするか |
|---|---|---|
| `.claude/docs/spec/issue-mr-workflow.md` | 変更 | changelogへ「issue #186」の新規エントリを**追記**（節順・結論カード・重点レビュー依頼・色/記号の軸分離・リンク破断/重複ID検査の要約と、正の所在がテンプレート冒頭コメントであることを記す）。**生きた記述（「計画・レポートのHTMLビュー」節）は変更しない**（必須節の列挙はテンプレートへ委譲済みで、issue #186 でも構成は変わらないことを確認済み） |
| `.claude/docs/ddr/i0186-01-レポートの視覚語彙は結論の性質とレビューの重みで軸を分ける.md` | 新規 | 決定: 結論の性質＝色相（青/黄/赤）＋記号＋文字、レビューの重み＝アクセント1色相の濃度・枠の太さ＋記号（◆◇・）。却下案: 重みへの赤黄流用（性質の色と混線）・`--muted-soft` 新設（トークン増に見合わない）・緑を「良かった」に使う案（`.box.ok` と衝突） |
| `.claude/docs/ddr/i0186-02-リンク破断検査はID抽出をタグ内に限定し重複ID検査を併設する.md` | 新規 | 決定: ID定義側の抽出は開きタグ内の `id` 属性に限定し、重複ID検査（`uniq -d`）を併設。却下案: 無限定grep（コメント・code内の文字列を定義に数え、破断してもすり抜けることを変異テストで実証）・検査前のコメント除去前処理（1行コマンドに収まらず伝承しにくい） |
| `.claude/docs/README.md` | 再生成 | `bash .claude/scripts/src/generate-ddr-list.sh` でDDR一覧を再生成（手書きしない） |
| `.claude/VERSION` | 変更（判断） | 下記「方針」の判断基準で増分を適用 |

## 方針

- **specは追記のみ**。過去のchangelogエントリ（issue #54 等）とpoint-in-time記録には触れない
  （`.claude/rules/docs-workflow.md` の制限）。
- **DDRはissue番号ベースの識別子**（`i0186-01`・`i0186-02`。枝番は01から連番、4桁ゼロ埋め）。
  frontmatter（type: ddr・title・description・tags・keywords）を付与する。
- **VERSION の判断基準**（`.claude/docs/spec/distribution-assets.md`「`.claude/VERSION`」が正）:
  配布対象アセット（core層の `reports.template.html`）の後方互換な機能変更のため
  **MINOR増分（0.3.0 → 0.4.0）を適用**する。非対話セッションのため例外規定に従い
  AIエージェントが適用し、(1) 根拠を本issueのspecのchangelogエントリと `HANDOFF.md`
  「判断を迷った内容」の両方へ残し、(2) レビューで否認されたら元へ戻す。
- DDRの改名・移動・削除は行わない（新規追加のみ）ため、`check-doc-references.sh` は必須では
  ないが、追加した2本の参照が正しいことの確認として実行する。

## やらないこと（スコープ外）

- 生きたspec本文の書き換え（上記のとおり変更不要を確認済み）。
- `reports/REVIEW-POINTS.md` への観点追加（`plans/【AIアセット反映】洗い出しとREVIEW-POINTS観点追加.md` が担当）。
- `.gemini/` 配下の更新（flow-id 5-3 の `sync-gemini-assets.sh` 再生成で追随）。
- CHANGELOGファイルの新設（DDR i0033-01 で「持たない」と決定済み）。

## 検証

```bash
# 1. changelogエントリが追記されたこと（1件以上）
grep -c 'issue #186' .claude/docs/spec/issue-mr-workflow.md

# 2. DDR 2本が存在し、識別子の形式が正しいこと（2行出力）
ls .claude/docs/ddr/ | grep -E '^i0186-0[12]-'

# 3. DDR一覧が再生成され、i0186-01/-02 が載っていること（2件）
grep -c 'i0186-0' .claude/docs/README.md

# 4. VERSIONがSemVer 1行であること
cat .claude/VERSION

# 5. 参照切れが無いこと（エラーなし）
bash .claude/scripts/src/check-doc-references.sh

# 6. 過去のchangelog・生きた記述を壊していないこと（specの差分が追記のみ＝削除行0）
git diff --numstat -- .claude/docs/spec/issue-mr-workflow.md
```

- 空振りの排除: 検証1の `issue #186` は現時点のspecに**0件**であることを実測してから追記する
  （4-6実施時にまず数える）。検証6は削除行が0であることを見る（2列目が0）。

## issueの受け入れ条件との対応

- 受け入れ条件(f)「deliverables.md等との無矛盾」の恒久化: 本計画のspec changelog追記で
  「なぜ矛盾しないか（節名全維持・正の所在の委譲）」を記録する。他の条件はフェーズ3で対応済み。
