---
title: worklog: 【調査】pptx書き出しの前提調査（push2）
type: log
description: issue #169 フェーズ2〈調査〉の調査実施（flow-id 2-6）の詳細な試行錯誤ログ
tags: [worklog, pptx, research]
keywords: [worklog, pptx, OOXML, 最小構成, zip, LibreOffice, cover, 実測]
---

# worklog: 【調査】pptx書き出しの前提調査（push2）

対象: 調査実施（flow-id 2-6）と結果レポート作成（2026-08-23）。
全体作業計画: `wip/plans/json-to-pptx-export-plan.md`
個別作業計画: `wip/plans/【調査】pptx書き出しの前提調査.md`
push回数: 2

## 試したこと

- Q1: `command -v` による所在実測（zip 3.0 / unzip 6.00 / python3 3.11.15 / jar / soffice）。
  python-pptx はimport失敗で不在を確認。
- Q3: 13パーツの最小構成pptxをscratchpadで手組みし、`zip -X -r` で梱包 →
  `unzip -t`・`zipfile.testzip()`・全XML well-formed・Content_Types突合・rels整合の5検査全合格。
- Q1代替経路: python3 zipfile で同じ展開ディレクトリから生成 → 検査合格・エントリ集合/先頭/
  区切りが zip 経路と一致することを突合。
- Q2: PR #194 ブランチを再fetchし、フェーズ3計画
  `wip/plans/【AIアセット作成】HTMLスライドスキル一式の作成.md` を精読。
  **表紙のtype名が title → cover へ改名されたことを検出**し、当方の写像を追従させた。

## うまくいったこと

- 最小構成の実生成が一発で機械検証を通った（theme1.xml のfmtSchemeフルセットが要る点は
  既知の構造として最初から含めた）。
- 依存元（PR #194）の再確認を調査実施中に行ったことで、type名の改名を早期検出できた。

## ダメだったこと

- LibreOffice（soffice 24.2.7.2）はこの環境ではフィルタ欠落により、pptxどころか .txt すら
  `--convert-to pdf` できない（フレッシュプロファイルでも同じ）。独立フルパーサでの開封検証は
  断念し、標準ライブラリでの構造検査で代替した。

## 次の一歩

- push2 → 敵対的レビュー（フェーズ2の2回目・対象は調査レポート）→ 指摘対応・返信 →
  describe（2-10）→ フェーズ3の個別作業計画（3-1）。

---
