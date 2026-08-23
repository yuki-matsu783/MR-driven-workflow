---
title: worklog: 【実装】【テスト】pptx-slidesスキルの作成（push4）
type: log
description: issue #169 フェーズ3〈作業〉の個別作業計画作成（flow-id 3-1）の詳細な試行錯誤ログ
tags: [worklog, pptx, implementation]
keywords: [worklog, pptx-slides, json-to-pptx, 作業計画, speakerNotes, 仮決め]
---

# worklog: 【実装】【テスト】pptx-slidesスキルの作成（push4）

対象: フェーズ3の個別作業計画の作成（flow-id 3-1。2026-08-23）。
全体作業計画: `wip/plans/json-to-pptx-export-plan.md`
個別作業計画: `wip/plans/【実装】【テスト】pptx-slidesスキルの作成.md`
push回数: 4

## 試したこと

- フェーズ2の締め: 敵対的レビュー2回目の指摘13スレッドすべてへ対応返信（commit 83bf6e8 を参照）、
  `set-header --unreplied 0`、describe（2-10）でMR descriptionをフェーズ2完了の内容へ全文更新。
- 個別作業計画【実装】【テスト】を作成。調査レポートの◆3件（雛形方針・speakerNotes採否・
  完了条件未達のままの進行可否）は人間の回答を得られないため、計画の「前提」節で仮決めを
  表にして明示した（speakerNotesは**出力しない**を仮決め。レビューで覆れば計画ごと修正）。

## うまくいったこと

- 種別は【実装】【テスト】の併記とした（非対話セッションでフェーズごとに合意を挟めないため、
  1回で合意を取る形。planning.md「種別を複数併記する場合／分ける場合」の基準どおり）。

## ダメだったこと

- 特になし。

## 敵対的レビュー（フェーズ3の1回目・対象=個別作業計画）

- 指摘14件（major8・minor6）。確度×重大度の1次振り分けで11件を投稿候補とし、
  `select-adversarial-findings.sh` の選別で11件全件をPR #199へインライン投稿（サマリ0件。
  unreplied=11を記録）。主要な指摘と対応:
  - **metaの写像と条件7突合の矛盾**（meta.title/author が対象外リストに無いのにdocProps行きで、
    正常系テストが設計上必ず落ちる。meta.subtitle が写像に現れない）→ meta.subtitle/date/author
    は cover の `<a:t>` へ出す写像へ改め、対象外リストを meta.title・meta.issue・speakerNotes
    の3つに固定。
  - **SKILL.md から wip/reports/ を参照する指示**（5-5で削除・配布先に不存在）→ 突合手順の正は
    フェーズ4で作る spec へ書き、SKILL.md は spec と issue番号のみ参照する形へ修正。
  - **speakerNotes の無警告な切り捨て** → 入力にあれば標準エラーへ件数付き警告（rc 0）を
    決めごとへ追加、テストも追加。
  - **経路1失敗時の挙動が未定義** → 「途中経路の検証失敗=出力削除してフォールバック、
    全経路失敗=明示エラー・非0終了」の2段階に分離。
  - **能力ベース検出の核心ケース（存在するが実行できないpython3）のテスト欠落** →
    非0終了スタブでの候補送り・全候補失敗・zip失敗時フォールバックのテストを追加。
  - **雛形の実体を直接置換する読み** → mktemp -d へコピー→加工、trap EXIT で後始末を明記。
  - **包括承認の過大解釈** → 「未回答のまま暫定で進める（承認は得ていない）」へ表現を改め、
    ◆3件をHANDOFFの「判断を迷った内容」「未解決の内容」へ転記、Draft解除前の人間回答を必須化。
  - **実機確認ゲートの欠落** → 「実機確認の結果が返るまで 5-6 へ進まない」を完了条件へ明記。
  - その他: 不正JSON・出力先境界の異常系追加、種別ラベルの整理（SKILL.mdは【実装】に含める
    判断を前提へ記載）、HTMLビューの同期。
- **報告のみに留めた3件**（いずれも計画へ反映済み）:
  1. [minor/medium] プレースホルダ置換の手段が未指定（sedだと `&` の再解釈で壊れる）→
     bashのパラメータ展開で行うと明記し、`&` 混在タイトルのテストを追加。
  2. [minor/medium] 「既存テストへの影響が無い」の判定が自己申告で空振りしうる →
     実行コマンドを名指し（`.claude/scripts/test/` 全件・check-dist-coverage.sh・
     extract-frontmatter.sh）で固定。
  3. [minor/medium] 経路間突合の一致条件（順序を含むか）が未定義で `zip -r` の走査順に依存 →
     「集合一致＋先頭＋ディレクトリエントリ0件。順序全体は比較しない」で確定。

## 次の一歩

- 指摘反映のcommit/push（push5）→ 11スレッドへ対応返信 → describe（3-5）→
  実装（3-6）: 雛形 → 生成スクリプト → SKILL.md → 単体テスト → 結果レポート。

---
