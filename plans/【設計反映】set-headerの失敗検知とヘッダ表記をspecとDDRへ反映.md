---
title: 【設計反映】set-headerの失敗検知とヘッダ表記をspecとDDRへ反映
type: plan
description: issue #66の個別反映計画（設計反映）。spec 2件の更新とDDR 1件の新設、DDR一覧の再生成
tags: [plan, update-handoff-progress, spec, ddr]
keywords: [設計反映, spec, DDR, i0066-01, generate-ddr-list, ヘッダ行, 無言の失敗, issue140]
---

# 【設計反映】set-headerの失敗検知とヘッダ表記をspecとDDRへ反映

対象issue: [#66](https://github.com/yuki-matsu783/MR-driven-workflow/issues/66)（flow-id 4-1）
実装結果: `reports/2026-08-20_set-header-silent-failure_実装結果.md`

**この計画には結果を書かない。** 結果は
`reports/2026-08-20_set-header-silent-failure_反映結果.md` へ書く。

`【AIアセット反映】` とは分ける（原則併記しない。評価軸が混ざるため）。

## 洗い出した反映対象

| ファイル | 反映する内容 |
|---|---|
| `.claude/docs/spec/update-handoff-progress.md` | **「HANDOFF.mdのヘッダ行」節を新設**（表記の定義。issueの受け入れ条件3）／サブコマンド表の `set-header` のエラー条件を更新／`- 現在のループ:` 行の挿入位置の記述を更新／**スクリプト全体の方針**（書き換え対象が見つからなければ書き戻さず非0で終了する。#140 の射程はここに含まれないことも明記）／「影響範囲」へ issue #66 のエントリを追記 |
| `.claude/docs/spec/cleanup-task.md` | `HANDOFF_TEMPLATE` がヘッダ行の雛形6行を持つようになったこと |
| `.claude/docs/ddr/i0066-01-*.md`（新規） | 採用案と却下案（別名 `- Draft PR:` を受け付ける案／見つからないヘッダ行を自動挿入する案／#140 と1つにまとめる案） |
| `.claude/docs/README.md` | DDR一覧。**手書きせず `bash .claude/scripts/src/generate-ddr-list.sh` で再生成**する（issue #135） |

## 反映しないもの（と、その理由）

- `.claude/docs/spec/issue-mr-workflow.md` の `- 追従監視:` に関する記述。今回は変更していない
  （`set-header` の対象外という扱いのまま）。
- **DDRの本文・過去changelogのpoint-in-time記録**。「影響範囲」節へは**新規エントリを追記**する
  だけで、既存エントリの記述は書き換えない（`REVIEW-POINTS.md`「ファイル移動に伴うパスの一括置換が
  point-in-time記録まで書き換えていないか」）。

## DDRに書くこと

識別子は `i0066-01`（issue #66 の1件目）。`.claude/rules/markdown-frontmatter.md`「DDRの識別子」に従う。

採用: **表記を1つに定め、見つからなければ非0で失敗する。**

却下案として少なくとも次の3つを、却下理由つきで書く。

1. **`- Draft PR:` を別名として受け付ける**（issueの「期待する動作」1の前半）。表記のゆらぎを
   仕様として抱え込み、次に別の別名が現れたときに同じ判断を繰り返すことになる。
2. **見つからないヘッダ行を `set-header` が自動で挿入する。** 誤記のヘッダ行を残したまま正しい行が
   増える状態を作る（`- Draft PR:` と `- PR:` が並ぶ）。
3. **issue #140 と1つにまとめる。** 判断は flow-id 2-6 の調査で済んでおり、その結論と理由を
   DDRへ残す。

## 検証手順

```bash
bash .claude/scripts/src/generate-ddr-list.sh
git diff --stat .claude/docs/README.md
bash .claude/scripts/test/test_generate_ddr_list.sh
bash .claude/scripts/src/extract-frontmatter.sh .
```

- 新規DDRのfrontmatter（`title` / `type: ddr` / `description` / `tags` / `keywords`）が揃っていること。
- **DDR識別子がdefaultブランチと衝突していないこと**を `check-base-conflicts.sh` で確認する
  （flow-id 5-1 でも通るが、DDRを足した直後にも見る）。
