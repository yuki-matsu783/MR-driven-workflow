---
title: worklog: 【AIアセット作成】HTMLスライドスキル一式の作成 push1
type: log
description: issue #168 フェーズ3（AIアセット作成）の試行錯誤ログ
tags: [worklog, slides, skill, agents]
keywords: [worklog, HTMLスライド, テンプレート, html-slides, サブエージェント, スキーマ, 実装]
---

# worklog: 【AIアセット作成】HTMLスライドスキル一式の作成

対象: issue #168 フェーズ3。スライドテンプレート・SKILL.md・スキーマ・サブエージェント2本の新規作成（2026-08-23）。
全体作業計画: `wip/plans/html-slides-skill-plan.md`
個別作業計画: `wip/plans/【AIアセット作成】HTMLスライドスキル一式の作成.md`
push回数: 7〜

## 試したこと

- 個別作業計画（md+html）を作成（flow-id 3-1）。HTMLビューの機械検査
  （プレースホルダ0・外部参照なし2種・リンク破断なし・重複IDなし）は全て合格。
- 計画の前提として `GEMINI_TOOL_PAIRS` に `Write` が含まれることを実測確認
  （`slide-html-generator` の tools に Write を持たせても flow-id 5-3 の変換が通る）。

## うまくいったこと

- 敵対的レビュー（フェーズ3の1回目・対象は個別作業計画）で12件の指摘（major 7・minor 4・nit 1）。
  1次振り分けで9件を投稿（PR #194 のインラインレビュー）、3件は報告のみ。
- 報告のみ3件の内訳（MRには出していない。いずれも検証節の書き直しで反映済み）:
  (1) 検証3が `[ -s ]` の空チェックを先に置いておらず計画自身の記述と食い違う【minor/medium】→
  `[ -s ] && jq -e` の順へ修正、
  (2) 検証4に実行できるコマンドが無く未作成のSKILL.mdを参照する循環【minor/medium】→
  調査Q5の実測フィルタの骨子を検証4へ直接記載し、正常0・異常非0の2本立てへ、
  (3) 検証5の `<サンプル出力.slides.html>` はそのまま実行するとbashの構文エラー【nit/high】→
  シェル変数 `$out` へ束縛する形へ修正。
- 投稿9件もすべて計画へ反映:
  型名の契約を確定（表紙はQ5の `title` から `cover` へ改め、理由と3箇所同一使用を明記）・
  スキーマ構造をQ5準拠（`meta`ネスト・`speakerNotes`・`issue` 保持）へ戻す・
  受け入れ条件表を上位計画10項目と1対1へ・検証2を一意性＋期待リスト突き合わせへ・
  検証2b（`@media print`・keydownの静的検査）を必須合格条件へ追加・
  検証6を実在パス（skills/html-slides/index.jsonl・agents/index.jsonl）＋握りつぶし排除へ・
  検証7を `--dry-run` 単体＋出力2件の判定へ・検証8に実行コマンドと代替を明記・
  「レビュー依頼で人間に確認してもらう項目」（Q8の3項目）を新設・HTMLビューを全面同期。
- 検証4のjqフィルタは修正時に3入力（正常0・type不正1・空1）で実測し、空振りが無いことを確認した。

## ダメだったこと

- 計画の初版は、調査レポートで確定した契約（型名enum・スキーマ構造）を書き写す段階で
  独自に変えてしまっていた（cover/titleの不一致・metaの平坦化）。調査結果を計画へ引くときは
  「結論の文言をそのまま引用し、変える場合は変更点と理由を明示する」形にする。

## 作業実施（flow-id 3-6）

- AIアセット5ファイルを新規作成: `slides.template.html`（型8種・進行表示・keydown＋クリック・
  `@media print`）・`SKILL.md`（手順6段・境界表）・`slide-outline.schema.json`（draft-07・
  meta/speakerNotes保持）・エージェント2本（`slide-outline-designer` / `slide-html-generator`）。
- 計画の検証スイート: 1（外部参照0）・2（型8種一意・comm空）・2b（@media print 2件・
  keydown|ArrowRight 2件）・3（SCHEMA_OK）・4（正常0/異常1/空1）・5（プレースホルダ0・重複ID
  なし・枚数8=8）・6（skills側1件・agents側2件）・7（dry-run終了0・新規2本=2件）すべて合格。
- 検証8（動的）: ヘッドレスChromiumで 1/8→2/8→8/8→1/8（キー）・2/8→1/8（左右クリック）・
  PDF8ページ=スライド8枚を実測。
- 検証2の初回実行が9を返した（テンプレート冒頭コメントの記法例が検査に数えられた）。
  コメント表現を変えて8を確認。検査が異常を検出できることの実例（レポート「想定と異なった点」）。
- 作業結果レポート md+html を作成（機械検査5種合格）。サブエージェント2本の実運転は未実施で、
  レポートの◆重点レビュー依頼へ明示した。

## 敵対的レビュー（フェーズ3の2回目・対象は実装＋レポート）

- 8件の指摘（major 1・minor 7、全件confidence high）を全てPR #194へインライン投稿
  （報告のみ0件）。カウンタは2/3。
- 8件すべてを反映:
  1. **JSガード欠如（major）**: IIFE冒頭へ `if (!slides.length) { return; }`、`progress` 更新を
     `if (progress)` で包む。冒頭コメントへ「.progress / .nav-hint は消してもページ送りは
     止まらない」を明記。
  2. **手順3が無出力**: `; echo "ok=$?"` を復元（実測 正常0/type不正1/空1/0枚1）。
  3. **型8種の再掲**: 手順3・5の型名をスキーマから導出
     （`jq -c '[.properties.slides.items.oneOf[]."$ref" | sub(".*/";"")]'`）へ変更。
  4. **0枚が合格**: フィルタへ `(.slides | length) > 0` を追加。
  5. **重複ID検査が空振り**: 出力data-typeとスキーマ由来リストの `comm -23` 照合へ置き換え。
  6. **手順5の未定義 `$outline`**: ブロック内で `outline`/`SCHEMA` を定義し、枚数一致は
     `COUNT_OK` の1行判定へ。
  7. **あふれの無言切り落とし**: `.slide` へ `justify-content: safe center` を追加し、
     動的検証へ「scrollHeight > clientHeight のスライド0枚」を追加。
  8. **comparison.tone の転記先未定義**: 見本コメントへ tone→クラス対応
     （pro→`.side.pro` / con→`.side.con` / neutral→`.side`）を明記し、`.side` 単体の既定
     スタイル（`border-top: var(--line)`）を追加。
- 指摘の敷衍として同時に実施: `@media print` で `:root` をライトへ上書き（ダークモード印刷対策）・
  cover へ任意の `title`/`subtitle` を追加（省略時は meta）・SKILL.md成果物表へ flow-id 5-5 の
  寿命注記・レポートへ「調査Q5からの変更点」表を新設（Q5準拠と言い切っていた記述の訂正）。
- 修正後にサンプルを再生成し検証スイートを全て再実測: 静的（外部参照0・型8種照合・
  プレースホルダ0・data-type照合差分なし・COUNT_OK）・スキーマ4入力（0/1/1/1）・動的
  （キー/クリック・PDF8ページ×ライト/ダーク・あふれ0枚・ダーク印刷背景=白・.progress削除版と
  0枚版でページエラー0）・index.jsonl（1件/2件）・gemini dry-run（終了0・新規2本）。

## 次の一歩

- 修正commit/push → 8スレッドへ返信 → describe（3-10）→ フェーズ4。
