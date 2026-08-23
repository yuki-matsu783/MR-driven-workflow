---
title: '統括: 収穫（逆輸入）スキルの新設'
type: report
description: issue #27 / PR #189 のブランチ全体の最終統括レポート（何を変えたか・なぜそうしたか・検証結果・spec/DDRへの反映先・残課題）
tags: [report, harvest, summary]
keywords: [統括, 収穫, 逆輸入, harvest-from-projects, i0027-01, i0027-02, VERSION, 敵対的レビュー, フェイルクローズ]
---

# 統括: 収穫（逆輸入）スキルの新設 — issue #27 / PR #189

## 何を変えたか

- **収穫スキル `harvest-from-projects` を新設した**（本家専用・exclude 層）。配布先の
  `.claude/.asset-manifest.json` を読み、変更・追加・削除・上流削除を層解決付きで分類し、
  本家側変更との衝突有無を読み取り専用で分析する（`scan` / `diff` / `merge3` の3サブコマンド）。
  出口は issue 起票（＋任意で個別作業計画の草案）までで、本家の正史はスキルからは変更しない。
- **配布先での機構DDRの扱いを明文化した**（`markdown-frontmatter.md`）: 配布先では機構の
  DDRを書かず、本家へ issue を起票する。収穫はその差分を回収する経路になる。
- **正史を新設・更新した**: spec `harvest-from-projects.md`・DDR `i0027-01`/`i0027-02`・
  usecase `配布先の改善を本家へ収穫する.md`・README（spec節/usecase節/DDR一覧87件）・
  `directory-structure.md`（`.claude/scripts/test/` の対象拡張）・`index.md` スキル一覧。
- **`shell-script-style.md`「エラー方針」「テスト」節を実測に基づき訂正した**（波及先の
  `spec/shell-scripts.md`・`.claude/REVIEW-POINTS.md` も同時に訂正）。
- **`.claude/VERSION` を 0.3.0 → 0.4.0（MINOR）へ増分した**（非対話適用。記録は spec
  changelog と HANDOFF の両方。人間が否認したら元へ戻す）。

## なぜそうしたか

- **出口を issue 起票までに限定**: どの改善をいつ取り込むかの判断を人間が握るため
  （issue #39 と同根）。自動で正史を書き換える案・PR 自動作成案は却下
  （DDR `i0027-01`。added 判定の除外の正を dist-layers.json 1本にする判断・フェイルクローズ・
  `removedUpstream` 別枠も同DDR）。
- **エラー隔離は「フォークされる側の内側で `set -e` を掛け直す」2形を採用**: 従来規約の
  「フォークされた側では `set -e` が正しく機能する」は bash 5.2.21 の実測で不成立
  （機構1: 条件文脈の errexit 一時停止がサブシェル内側へ伝播／機構2: コマンド置換は
  `inherit_errexit` 既定オフのため `-e` を継承しない）。`shopt -s inherit_errexit` 常時オン・
  `set -E`+`trap ERR`・個別検査は却下（DDR `i0027-02`）。

## 検証結果

- `bash -n`（構文）: 合格。
- 単体・結合テスト `test_harvest_from_projects.sh`: T1〜T23＋T21b、**passed=91 failures=0**
  （合成配布先8種。非ASCIIパス・改名旧パス・tar 失敗・`files:[]` manifest・層未確定の
  フェイルクローズ等の境界を固定）。
- `check-dist-coverage.sh`: 4検査すべて OK（追跡ファイル 472/472 分類・空振り0・不正0）。
- frontmatter インデックス実問い合わせ: 新規4ドキュメントすべて `jq -e` true。
- DDR一覧の冪等性（生成→ステージ→再生成で差分ゼロ）・DDR識別子の重複なし: 合格。
- errexit 5ケースの実測が訂正後の規約本文と全ケース一致。旧前提の残存はリポジトリ横断
  grep で規範として 0 件。
- 敵対的レビューを6回実施（フェーズ2×2・フェーズ3×2・フェーズ4×2）。指摘計86件を
  すべて反映し、全スレッドへ返信済み（レビュー6回目では merge3 のフェイルクローズの穴
  ——manifest 未記録＋dist-layers 不読で exit 0——を実装修正し T21b で固定）。

## spec・DDRへの反映先

- `.claude/docs/spec/harvest-from-projects.md`: scan の出力スキーマ（条件付きキー含む）・
  分類規則・conflict 判定・縮退モード条件・merge3 終了コード5値・読み取り専用の保証・
  git 起動の一括化・エラー隔離・`--upstream`。影響範囲に core 層包含の判断と VERSION 適用の
  changelog。
- `.claude/docs/ddr/i0027-01-収穫スキルは読み取り専用分析とissue起票までを出口にする.md`
- `.claude/docs/ddr/i0027-02-エラー隔離は条件文脈の外のサブシェルでset-eを掛け直して行う.md`
- `.claude/docs/usecase/配布先の改善を本家へ収穫する.md`（README の usecase 節から逆引き）

## 残課題

- **ベースブランチ（main）が behind 4**（`wip/` 再配置 #178/#190・HTMLレポート #191・
  Geminiテレメトリ #174）。取り込みはユーザー承認必須のため未実施
  （`check-base-conflicts.sh` 実測: textualConflictFiles 26件・DDR識別子の重複0件。大半は
  本ブランチの plans/worklog/reports と main 側の再配置の重なりで、flow-id 5-5 の片付けで
  縮小する見込み）。マージ前に取り込みの承認と解消が必要。
- **関連issue通知（flow-id 5-2）**: 影響先候補は #153（他プロジェクトに導入するように
  漂白する——「exclude スキルの spec/DDR を core で配ることを許容」の明示判断が漂白の前提に
  関わる。類型: 前提が変わる）。投稿前の人間承認が必須のため非対話セッションでは投稿して
  いない。
- **VERSION 0.4.0 の人間による追認**（非対話適用。否認されたら元へ戻す）。
- Windows（git bash）実機・実在配布先での試運転・SKILL.md 対話手順の通し実行は未検証
  （spec の未決定事項に記載。マージ後の初回収穫で確かめる）。
