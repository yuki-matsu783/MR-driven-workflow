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

## 敵対的レビュー（フェーズ2の2回目・対象=調査レポート）

- 指摘15件。13件を `select-adversarial-findings.sh` の選別でPR #199へインライン投稿
  （unreplied=13を記録）。主要な指摘と対応:
  - **zip経路の「エントリ一致」が不正確**（zip経路のみディレクトリエントリ11件を含んでいた）
    → `zip -X -D -r` を採用し、python経路と**全エントリ完全一致**で再実測・合格。
  - **rId採番が未定義で、雛形の並び（rId2=slide1/rId3=theme）はスライド2枚目でthemeと
    衝突する** → 採番規則を定義（rId1=slideMaster・rId2=theme予約、スライドはrId3から連番。
    `presentation.xml.rels` は生成スクリプトが丸ごと所有）し、**2枚構成15パーツ**で再実測。
    rId重複0・rels整合の検査を追加して合格。
  - **受け入れ条件7の「完全一致の集合包含」は写像の合成テキスト（エッジ「A → B（ラベル）」等）で
    必ず失敗する** → 「入力JSONの葉テキスト値ごとの部分一致」へ定義を修正（対象外リスト付き）。
  - その他: 能力ベース検出（Windowsの `python3` 不在・Storeスタブ）、title全型必須（上流準拠）、
    theme必須性の未検証の明示、事実と理解の分離、完了条件の一部未達（OOXMLフルパーサ）の開示、
    再現手順（検証スクリプト全文）の追記、`jar tf` を第3の独立zip実装として追加。
- **報告のみに留めた2件**（いずれもレポートへ反映済み）:
  1. [minor/medium] Q5のnotesSlide連動の見積り（「各1箇所」）が過小 → 連動は
     スライド枚数に比例する2種類（Content_TypesのnotesSlide毎Override・notesSlide毎rels）＋
     固定2箇所と書き直し、notesMaster入り最小構成は未実生成で見積りの実測rootが無いことを明記。
  2. [minor/medium] 「OPCにはmimetype相当の制約が無い」が出典なしの断定 → 外部Web不使用のため
     裏取りしていない「未確認の理解」であることを明示し、先頭配置・`-D` は保険であって
     必須性を主張しない、へ書き直し。
- レポートmd・htmlの両方を改稿で同期した（初版の誤りは「想定と異なった点」に記録）。

## 次の一歩

- 指摘反映のcommit/push（push3）→ 13スレッドへ対応返信 → describe（2-10）→
  フェーズ3の個別作業計画（3-1）。

---
