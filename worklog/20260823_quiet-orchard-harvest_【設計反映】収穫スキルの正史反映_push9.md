---
title: 'worklog: 【設計反映】収穫スキルの正史反映（push9）'
type: log
description: issue #27 フェーズ4の反映実施（flow-id 4-6。spec/DDR/usecase新規・README・directory-structure・SKILL.md・VERSION・shell-script-style訂正）のログ（push9）
tags: [worklog, harvest]
keywords: [flow-id 4-6, spec, i0027-01, i0027-02, usecase, VERSION, shell-script-style, generate-ddr-list, check-dist-coverage]
---

# worklog: 【設計反映】収穫スキルの正史反映（push9）

対象: issue #27 フェーズ4・flow-id 4-6（2026-08-23）。
個別反映計画: `plans/【設計反映】収穫スキルの正史反映.md`・
`plans/【AIアセット反映】エラー方針の規約訂正.md`
push回数: 11

## 試したこと

- 【設計反映】: spec `harvest-from-projects.md`・DDR `i0027-01`/`i0027-02`・usecase
  `配布先の改善を本家へ収穫する.md` を新規作成。README は `generate-ddr-list.sh` の再生成
  （85→87件）＋ spec 節・usecase 節へ手書き各1行。directory-structure.md は
  `scripts/test` に触れる3箇所（ツリーのコメント・配置の指針・otel 例外段落）だけを
  最小差分で拡張。SKILL.md の予告文を spec への実リンクへ差し替え。VERSION 0.3.0→0.4.0
  （MINOR。適用記録は spec changelog と HANDOFF「判断を迷った内容」の両方へ）。
- 【AIアセット反映】: shell-script-style.md「エラー方針」を2機構の書き分け＋推奨パターン
  2形へ差し替え、「テスト」節の `"$(func; echo $?)"` の理由付けを訂正（結論は維持）。
- 検証は計画どおり7種を実行し全合格（frontmatter 4件・DDR一覧の冪等性・DDR重複なし・
  check-dist-coverage 472/472・README grep・errexit 5ケース再実測・制御文字混入なし）。
  結果の正文は `reports/2026-08-23_quiet-orchard-harvest_反映結果.md`（＋.html）。

## うまくいったこと

- 計画の検証節を「実行可能なコマンド＋期待値」へ書き換えておいた（レビュー5回目の反映）
  おかげで、検証がコピペ実行だけで済み、判定も終了コードで機械的にできた。

## ダメだったこと

- （特になし。制御文字の混入も今回はバイト数比較の事前検査で0件だった）

## 次の一歩

- commit・リモート反映（4-7 相当）→ 敵対的レビュー6回目（フェーズ4・対象=反映一式。
  カウンタ 2/3）→ 指摘の投稿・修正・返信 → フェーズ5。

---
