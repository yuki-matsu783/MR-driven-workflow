---
title: worklog 20260820 【AIアセット反映】REVIEW-POINTSの運用ルールとshellの落とし穴 push13
type: log
description: issue #77 のAIアセット反映（2セット目）の作業ログ。push13時点。rules 4ファイルとSKILL.mdへの反映を記録する。
tags: [worklog, ai-asset, rules, review-points]
keywords: [AIアセット反映, REVIEW-POINTS, docs-workflow, directory-structure, markdown-frontmatter, MSYS_NO_PATHCONV, jq, Writeツール]
---

# worklog: 【AIアセット反映】REVIEW-POINTSの運用ルールとshellの落とし穴

対象: issue #77 で気づいたルール・スキルの不備を `.claude/rules/` `.claude/skills/` へ反映する（2026-08-20）。
全体作業計画: `plans/prancy-herding-kahan.md`
個別反映計画: `plans/【AIアセット反映】REVIEW-POINTSの運用ルールとshellの落とし穴.md`
push回数: 13

## 試したこと

- flow-id 4-3のレビューで指摘1件。「恒久的なファイルじゃなくてフローのファイルなのでこれで良いよ」の
  あとに訂正コメント「間違えた。REVIEW-POINTS.mdは消えると困るな。REVIEW-POINTS.mdだけ削除しないように
  してほしい」が付いた。**計画の記載どおり**だったため計画は変更せず、スレッドへ返信した
  （flow-id 4-4）。
- flow-id 4-6として5ファイルへ反映した。
  - `.claude/rules/docs-workflow.md`: ライフサイクル表へ `<ディレクトリ>/REVIEW-POINTS.md` の行を追加し、
    「3つはflow-id 5-1でまとめて削除する」の段落の直後へ**唯一の例外**である旨の段落を追加。
  - `.claude/skills/issue-mr-flow/SKILL.md`: flow-id 5-1の行へ但し書きを追記（詳細はdocs-workflow側が正）。
  - `.claude/rules/directory-structure.md`: ツリー図へ3か所（`.claude/`・`plans/`・ルート直下）と、
    「配置の指針」へ配置の意味を1項目。
  - `.claude/rules/markdown-frontmatter.md`: `type` の値の表へ `review-points`。
  - `.claude/rules/shell-script-style.md`: `MSYS_NO_PATHCONV=1` とネイティブjqの相互作用、
    ツール経由でバックスラッシュが潰れる件、長文生成はWriteツールで行う件。

## うまくいったこと

- **最初のレビューコメントの「消すときに反映されていることの確認はしても良い」を捨てずに拾えた。**
  訂正で結論は覆ったが、この一文自体はflow-id 5-1の実施手順として有用なので、返信で
  「5-1で削除する前に spec/ddr・rules へ反映済みであることを確認してから消す」と受け止めを明示した。
- **`sed` の置換文字列に `\n` を書かない件は、追記が不要だと分かった。** 既存の記述
  （`awk`/`sed`の置換文字列で `\r` を含むシェルコードを生成しない）が、本文で
  「処理系によって`\r`・`\n`・`\t`がエスケープとして解釈される」と既に `\n` を含めて書いていた。
  計画では「1文追記」としていたが、**実物を読んで不要と判断**した。ルールを増やさずに済んだ。
- **`MSYS_NO_PATHCONV=1` の副作用を、既存の推奨と同じ節に書けた。** 別の節に書くと、
  推奨だけを読んだ人が同じ罠を踏む。「規約どおりに書いて壊れる」形の不整合を1か所で解消できた。

## ダメだったこと

- **`python` で一括編集しようとして失敗した。** この環境の `python` はPython 2で、
  日本語を含むヒアドキュメントが `SyntaxError: Non-ASCII character` になった。
  結局いつもの `{ sed -n ...; cat part.md; sed -n ...; }` の連結に戻した。**このリポジトリの
  編集手段はbashの連結に統一されており、そこから外れる必要は無かった。**

## 検証

```
extract-frontmatter.sh .   → files=95 built=9 reused=86 failed=0
単体テスト9本              → test_post_issue_create_notice.sh のみ failures=1
                             （main由来の既存不具合。issue #94。他8本は failures=0）
grep -c REVIEW-POINTS      → docs-workflow.md:3 / directory-structure.md:7 /
                             markdown-frontmatter.md:1 / issue-mr-flow/SKILL.md:2
```

## 次の一歩

- flow-id 4-7（commit・push）→ 4-8（人間のレビュー）。
- 合意後フェーズ5へ。5-1で `plans/` `worklog/` `reports/` を削除する（**`REVIEW-POINTS.md` は残す**。
  削除前に spec/ddr・rules へ反映済みであることを確認する）。

---
