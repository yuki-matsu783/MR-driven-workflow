---
title: 20260823 humming-mapping-pie OTelリスナー機構の設計反映
type: report
description: issue #103のフェーズ4設計反映結果。DDR2件・spec1件の新設とDDR一覧再生成の記録
tags: [otel, telemetry, ddr, spec]
keywords: [DDR, spec, i0103, generate-ddr-list, 設計反映]
---

# OTelリスナー機構の設計反映（issue #103・フェーズ4〈反映〉結果・設計反映分）

対象: issue #103。全体作業計画 `plans/humming-mapping-pie.md` のフェーズ4。
前提: `plans/【設計反映】OTelリスナー機構のDDR_spec新設.md`（個別反映計画、レビューで承認済み）。

## 反映した内容

### DDR新規作成（2件）

| ファイル | 内容 |
|---|---|
| `.claude/docs/ddr/i0103-01-perlを常駐プロセス実装の選択肢に加える理由.md` | `HTTP::Daemon`（コア添付でない）ではなく`IO::Socket::INET`の自前HTTP/1.1最小パーサを採用した理由。`shell-script-style.md`の既存方針に「常駐プロセスが必要な場合はperl」の枝を追加する判断として記録 |
| `.claude/docs/ddr/i0103-02-OTelエンドポイント設定をsettings.local.jsonへ分離する理由.md` | issue期待する動作5（環境ごとに別ポート）とプロジェクトスコープ`.claude/settings.json`（単一・共有）の両立が不可能だったため、環境依存の値だけを`.claude/settings.local.json`（Git管理外）へ分離した判断。期待する動作6（リポジトリ内で完結）との整合性も明記 |

計画段階の想定どおり2件で確定した（分割・統合の変更は無し）。

### spec新規作成（1件）

`.claude/docs/spec/otel-listener.md`: OTelリスナー機構の仕様。背景・目的（既存の対応工数
レポートDDR i0000-04との関係を含む）・仕組み・配置・設定項目・出力形式・多重起動防止/
デタッチ起動・ベストエフォート方針・既知の制限・導入手順（DEVELOPERS.mdへの参照）・
影響範囲・未決定事項を記載。

### README.md更新

- `.claude/docs/README.md`「spec（機能仕様）」節へ`otel-listener.md`の行を追加（手動管理のため）。
- `bash .claude/scripts/src/generate-ddr-list.sh`を実行し、DDR一覧を再生成した
  （73件、`i0103-01`/`i0103-02`の2件が追加された差分のみ）。

## 検証結果

| 検証項目 | 結果 |
|---|---|
| DDR識別子の命名規則（`i<issue番号4桁>-<枝番2桁>-<タイトル>.md`） | `i0103-01`/`i0103-02`とも準拠を確認 |
| `generate-ddr-list.sh`実行後のREADME.md差分 | 2行追加のみ（既存のchangelogエントリ・過去の記述は変更なし） |
| frontmatter抽出（`extract-frontmatter.sh`） | DDR・spec両ディレクトリともfailed=0で成功 |

## フェーズ4への持ち越し事項

- AIアセット反映（`plans/【AIアセット反映】OTelリスナー機構のルール反映.md`）は未着手。
  設計反映（本レポート）の完了・レビュー後に着手する（`docs-workflow.md`の方針）。
