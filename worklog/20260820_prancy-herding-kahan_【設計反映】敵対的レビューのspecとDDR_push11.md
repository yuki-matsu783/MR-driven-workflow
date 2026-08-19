---
title: worklog 20260820 【設計反映】敵対的レビューのspecとDDR push11
type: log
description: issue #77 の設計反映の作業ログ。push11時点。specとDDR3件の執筆（flow-id 4-6）を記録する。
tags: [worklog, spec, ddr, adversarial-review]
keywords: [設計反映, spec, DDR, 0040, 0041, 0042, 却下案, 影響範囲, 相互参照, index.jsonl]
---

# worklog: 【設計反映】敵対的レビューのspecとDDR

対象: issue #77 の成果を正史（`.claude/docs/spec/` `.claude/docs/ddr/`）へ反映する（2026-08-20）。
全体作業計画: `plans/prancy-herding-kahan.md`
個別反映計画: `plans/【設計反映】敵対的レビューのspecとDDR.md`
push回数: 11

## 試したこと

- flow-id 4-5: MR descriptionへ「フェーズ4（反映）」節と「`main` の取り込み」節を追加した。
  追記位置を素朴に末尾へ足すと、フェーズ4の話が `## 実装状況` 配下の `###` になってしまったため、
  `## Plan` 配下（フェーズ3の直後）へ移し替えた。
- flow-id 4-6: 計画どおり spec 1件・DDR 3件を書いた。
  - `.claude/docs/spec/adversarial-review.md`（新規）
  - `0040-敵対的レビューは専任サブエージェントで独立コンテキストに切り出す.md`
  - `0041-レビュー観点はディレクトリごとのREVIEW-POINTSへ外だしする.md`
  - `0042-インラインコメントの位置指定はプロバイダごとの制約に合わせて縮退させる.md`
- あわせて `.claude/docs/README.md` の spec一覧・DDR一覧へ4件を追加し、
  `.claude/docs/spec/issue-mr-workflow.md` の提供関数の表へ `add_mr_inline_comments` の行と、
  `## 影響範囲` へ issue #77 のchangelogエントリを追加した。

## うまくいったこと

- **`issue-mr-workflow.md` への相互参照を「1行」に収める方針が機能した。** 敵対的レビューの仕様を
  そちらへ書くと二重管理になるため、提供関数の表の1行から新specへリンクする形にした。表は
  「`Provider.sh` 経由の共通インターフェース」の一覧であり、`add_mr_inline_comments` はそこに
  載るべき関数なので、相互参照のためだけの不自然な追記にならずに済んだ。
- **却下案を「なぜ却下したか」まで書けた。** 特に `line` 未指定の扱いは、フェーズ2のレビューで
  「1行目でよい」と合意していたものを実装時に「有効行の最小値」へ変えている。specだけでは
  この変更の理由が残らないため、DDR 0042 に「既存ファイルの部分変更では1行目がdiffに含まれず、
  GitHubのレビューはアトミックなので全体が422になる」と経緯ごと残した。
- `extract-frontmatter.sh` は `built=4 reused=88 failed=0`。新規4ファイルだけが再構築され、
  DDR番号 0040〜0042 が index.jsonl から正しく引けることを確認した。

## ダメだったこと

- 特になし。

## 次の一歩

- flow-id 4-7（commit・push）→ 4-8（人間のレビュー）。
- 設計反映の合意後、2セット目として `【AIアセット反映】` を 4-1 から回す。

---
