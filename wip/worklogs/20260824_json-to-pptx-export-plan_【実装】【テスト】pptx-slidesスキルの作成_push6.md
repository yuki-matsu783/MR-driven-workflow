---
title: worklog: 【実装】【テスト】pptx-slidesスキルの作成（push6）
type: log
description: issue #169 フェーズ3〈作業〉の実装（flow-id 3-6）の詳細な試行錯誤ログ。スキル一式・単体テスト49件の作成と、実装中に踏んだ罠の記録
tags: [worklog, pptx, implementation]
keywords: [worklog, pptx-slides, json-to-pptx, patsub_replacement, 制御文字, jq, 単体テスト, zip経路]
---

# worklog: 【実装】【テスト】pptx-slidesスキルの作成（push6）

対象: フェーズ3の実装（flow-id 3-6。2026-08-23〜2026-08-24）。
個別作業計画: `wip/plans/【実装】【テスト】pptx-slidesスキルの作成.md`
結果の正文: `wip/reports/2026-08-24_json-to-pptx-export-plan_実装.md`
push回数: 6

## 試したこと

- 雛形 `assets/pptx-template/`（静的7パーツ）を配置 → `scripts/slides-to-records.jq`
  （入力検証＋US区切りレコードストリーム、実行あたりjq1回）→ `scripts/json-to-pptx.sh`
  （type別写像・連動5箇所・zip経路試行・自己検証）→ `SKILL.md` → 単体テスト
  `test_json_to_pptx.sh`（49アサーション）の順で作成。
- 8種type全部入りサンプル（scratchpad）でのスモークテスト → 単体テスト作成 →
  既存機構への影響確認（既存テスト22本・check-dist-coverage・extract-frontmatter）。

## うまくいったこと

- 最初の単体テスト実行が実バグ2件（下記）を即検出した。「純粋関数を source して直接呼ぶ」
  「最初に機械検証一式を流す」という構成が効いた。
- 経路系のテスト（フォールバック・候補送り・全滅・両不在・後始末）は、実コマンドへの
  シンボリックリンクだけを持つ合成bin＋失敗スタブで全ケース再現できた。

## ダメだったこと（踏んだ罠）

- **bash 5.2 の `patsub_replacement`（既定ON）で `${s//</&lt;}` が `<lt;` になる**。
  置換文字列中の `&` がマッチ全体へ展開される、sedと同じ罠がパラメータ展開にもあった
  （計画は「sed/awkを避けてパラメータ展開なら安全」という前提だったが、bash 5.2では
  成り立たない）。core.xmlのプレースホルダ置換もエスケープ済み値の `&` で同様に壊れる。
  → スクリプト冒頭に `shopt -u patsub_replacement 2>/dev/null || true`（5.2未満には
  shopt自体が無い）。テストの期待値が再発を固定。
- **HDRレコードの値内改行**: `meta.title` に改行が入るとjqの出す1行レコードが割れ、
  2行目が未知タグとして無言で捨てられる（`dc:title` が先頭行だけになる）。
  → docProps行きの3値（title/author/issue）は jq 側で `cell`（改行→空白）を適用。
- **`PATH=... bash "$target"` は一時代入のPATHで `bash` 自体を探す**ため、合成binに
  `bash` を含めないと 127 で落ちる（テスト側の話）。→ 合成binへ `bash` のリンクを追加。
- （push6以前・実装初期）jqフィルタへ生の 0x1F 制御バイトを書いてしまいBashツールの
  コマンド検査で弾かれた → `""` エスケープ表記へ（shell-script-style.md の
  既存ルールどおり）。`else (` の閉じ括弧不足によるjq構文エラーは、python の括弧深さ
  追跡（文字列リテラル除外）で特定。EXIT trap が参照する `tmp` を `local` にしていて
  `set -u` で落ちる罠も踏んだ（trapはmainを抜けた後に走る）→ localを外し理由コメント。

## 結果

- `bash .claude/scripts/test/test_json_to_pptx.sh` → `passed=49 failures=0`
- 既存テスト22本全件 rc=0・failures=0／`check-dist-coverage.sh` OK（484/484）／
  `extract-frontmatter.sh .` エラーなし
- 詳細と生の出力は結果レポート（md+html）を参照。
