---
title: "worklog: 【設計反映】【実装反映】スキーマ確定への追従とspec・DDR作成（push8）"
type: log
description: issue #169 フェーズ4〈反映〉の個別反映計画作成（flow-id 4-1）の試行錯誤ログ。PR #194マージ検出とスキーマ突合の経緯を記録
tags: [worklog, pptx, reflection]
keywords: [worklog, pptx-slides, スキーマ突合, slide-outline, PR194, 反映計画, フェーズ4]
---

# worklog: 【設計反映】【実装反映】スキーマ確定への追従とspec・DDR作成（push8）

対象: フェーズ4の個別反映計画作成（flow-id 4-1。2026-08-24）。
個別反映計画: `wip/plans/【設計反映】【実装反映】スキーマ確定への追従とspec-DDR作成.md`
push回数: 8

## 試したこと

- フェーズ3を締めた直後（3-10完了後）、依存元 PR #194 の状態を再確認したところ、
  **2026-08-24T00:33Z にマージ済み（人間の操作）**であることを検出した。構成案JSONスキーマ
  `.claude/skills/html-slides/references/slide-outline.schema.json` が main で確定した。
- 当ブランチは main から4コミット behind だが、PR #199 の mergeable_state は clean
  （コンフリクトなし）。ベース取り込みは `AskUserQuestion` 承認が必要で非対話セッションでは
  得られないため取り込まず、スキーマは `git show origin/main:<path>` で参照した。
- 確定スキーマと現実装（push7時点）の入力仕様を type ごとに突合し、差分表を作成
  （結果は反映計画の「スキーマ突合の結果」節が正）。

## うまくいったこと

- 突合により重大差分を漏れなく特定できた。要点: two-column は `left`/`right` ではなく
  `columns[2]{heading,items}`／table は `headers` ではなく `columns`／comparison は
  `options[]` ではなく `sides[2..3]{name,points,tone}`／cover の `title` は任意
  （`meta.title` フォールバック）／section に `chapter`（任意）／diagram は
  `nodes[]{label,note}` のみで `edges`・`caption` は存在しない／summary に `takeaway`（任意）／
  `meta.issue` は integer。**現実装はスキーマ適合入力を拒否する**（two-column/table/comparison
  で必須キー検査エラー）ため、フェーズ4【実装反映】での追従が必須と判断した。
- フェーズ2調査時点のスキーマは方針レベル（8種 type enum のみ確定）であり、型別フィールドの
  想定が外れたのは想定内のリスク（HANDOFF「未解決の内容」に記録済み）だった。依存範囲を
  「jqの必須キー検査」に閉じてスキーマファイル本体へ依存しない設計にしていたため、
  追従は jq 検証・写像・テストサンプルの書き換えで完結する。

## ダメだったこと（踏んだ罠）

- 特になし（このステップは計画作成のみ。ファイル編集での躓きは無かった）。

## 判断の記録

- 種別を【設計反映】【実装反映】と併記した（合意を1回で取るため。非対話セッションで
  レビュー往復を待てないことと、両者が「スキーマ確定と実装完了」という同じ根から出ている
  ことが理由）。
- `.claude/VERSION` の増分（0.5.0→0.6.0）は flow-id 5-1 の main 取り込み後に行う
  （当ブランチの値は分岐時点の 0.4.0 のため、今書き換えると必ずコンフリクトする）。
- `directory-structure.md` の skills ツリーは main 側で `html-slides` が追記済みのため、
  5-1 の取り込みで同じ箇所のコンフリクトが起きうる。**解消時は両方の行を残す。**
- 条件7突合の対象外リストへ `slides[].sides[].tone` を追加予定（4つ→5つ）。tone は
  見た目の色分け指示子で、値そのもの（pro/con/neutral）は日本語注記へ写像され
  `<a:t>` に現れないため（`slides[].type` と同じ扱い）。

## 結果

- 反映計画（md+同名html）を作成。HTML検査合格（プレースホルダ0・重複ID 0・目次リンク
  破断0・制御文字混入0バイト）。
- 次: commit/push（push8）→ 敵対的レビュー（フェーズ4の1回目・対象=反映計画）→
  指摘反映・返信 → describe（4-5）→ 反映実施（4-6）。

## 敵対的レビュー（フェーズ4の1回目・対象=反映計画＝push8）

- 指摘11件（major6・minor5）。確度×重大度の1次振り分けで9件を投稿候補とし、
  `select-adversarial-findings.sh` の選別で9件全件をPR #199へインライン投稿（unreplied=9を
  記録。スレッドURLはHANDOFF「やったこと」）。主要な修正（計画md+HTMLを同期）:
  - **併記理由の差し替え**（AR-4-03 major）: 「非対話で合意を1回で取る」は合意自体が発生せず
    不成立 → spec入力仕様節が実装追従後でないと書けない**一方向の依存**を理由として明記。
  - **meta.issue integer化の巻き添え**（AR-4-01 major）: `verify_pptx.py` の issue 参照を
    `norm(str(...))` 相当へ修正するタスクを追加。`walk()` が int の葉を拾わず対象外指定が
    実質デッドな点はspecへ明記。
  - **スキーマ適合検証の縮退**（AR-4-02 major）: `import jsonschema` が
    `ModuleNotFoundError`（python 3.11.15）とこの環境で実測 → jqによる決定的な適合チェック
    （required／余剰キー／型／minItems・maxItems／enum）をテストへ組み込む形へ変更。
    目視は完了条件から除外。
  - **index.md の欠落**（AR-4-04 major）: Repository Map の skills 列挙への追記を作業項目4へ
    追加。5-1 コンフリクト注意を2ファイル（directory-structure.md・index.md）へ拡大。
  - **VERSION 据え置きの記録義務**（AR-4-05 major）: distribution-assets.md のchangelogへ
    据え置きエントリを4-6で追加するタスクと、5-1で書けなかった場合の代替を計画へ明記。
    HANDOFF「判断を迷った内容」へも記載。
  - **cover.subtitle 上書き時の条件7**（AR-4-06 major）: サンプルへ cover を2枚置く設計
    （1枚目=metaフォールバック・2枚目=自前値）を明記。
  - **フェーズ2確定範囲の転記誤り**（AR-4-08 minor）: 「8種enumも未確定」→「enum・metaは
    確定、型別フィールドは暫定」へ調査レポートの区分どおりに修正。
  - **入れ子bullets のデッドコード化**（AR-4-11 minor）: 突合表 bullets 行を「維持」から
    「スキーマへ揃え入れ子分岐を削除」へ変更（diagram の `.id` フォールバック等も同様）。
  - **既存テスト維持の具体化**（AR-4-07 minor）: 維持／新語彙へ書き換え／削除（edges要素型・
    入れ子bullets。理由を結果レポートへ残す）の3分類を明記。
- **報告のみ（1次振り分けで minor×medium）2件**。いずれも計画の質の問題のため、投稿は
  しないが計画へは反映した:
  1. 新レコード CHAP/COLH の受け側（json-to-pptx.sh）仕様の欠落（AR-4-09）→ レコード形式・
     受け側バッファ・描画位置・reset_slide_buffers への追加・diagram用 PARA レコード新設を
     「写像の変更」へ明記。
  2. tone を条件7対象外にすると新設写像が無検証になる（AR-4-10）→ tone注記3種と
     cover省略側の meta.title/meta.subtitle 出現の個別アサーションをテスト欄へ追加。
