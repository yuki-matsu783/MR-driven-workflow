---
title: "worklog: 【設計反映】【実装反映】スキーマ確定への追従とspec・DDR作成（push10）"
type: log
description: issue #169 フェーズ4〈反映〉の実施（flow-id 4-6）の詳細な試行錯誤ログ。スキーマ追従の実装・spec/DDR/rules作成と、実施中に踏んだ罠の記録
tags: [worklog, pptx, reflection]
keywords: [worklog, pptx-slides, スキーマ追従, schema_check, 生制御バイト, jq, パイプ差し替わり, VERSION]
---

# worklog: 【設計反映】【実装反映】スキーマ確定への追従とspec・DDR作成（push10）

対象: フェーズ4の反映実施（flow-id 4-6。2026-08-24）。
個別反映計画: `wip/plans/【設計反映】【実装反映】スキーマ確定への追従とspec-DDR作成.md`
結果の正文: `wip/reports/2026-08-24_json-to-pptx-export-plan_反映.md`
push回数: 10

## 試したこと

- 計画の作業項目順に実施: `slides-to-records.jq` 全面改修 → `json-to-pptx.sh` 受け側
  （CHAP/COLH/PARAハンドラ・CUR_CHAPバッファ・section分岐の描画）→ スキーマ適合サンプルでの
  スモークテスト → SKILL.md 語彙更新 → 単体テスト書き換え（サンプル・verify_pptx.py・
  個別アサーション・jqスキーマ適合チェック・境界値）→ spec/DDR/rules/index.md → 検証一式。
- スモークテストで写像を実測確認: cover1=metaフォールバック（スモーク発表/メタ副題）、
  cover2=自前値優先、section=第1章+背景、diagram=「入力 → 変換 → 出力」+「変換: jq 1回」、
  comparison=ヘッダ「案X（採用寄り）/案Y（却下寄り）/案Z（中立）」+points転置（不足空埋め）、
  summary=takeaway太字段落。

## うまくいったこと

- 「レコード形式と受け側の対応を対で計画に書く」（敵対的レビューAR-4-09の反映）が効き、
  受け側の変更が迷いなく済んだ。実装では計画より簡素化できた（COLH/PARAはjqの出力順が
  順序を保証するため既存バッファへの追記で足り、新設は CUR_CHAP のみ。takeaway は
  PARA の太字フラグ b|n で表現）。
- jqによるスキーマ適合チェック（`schema_check.jq`）は draft-07 の基本語彙
  （$ref・type・enum・const・required・additionalProperties・minItems/maxItems・items・
  oneOf枝選択）の範囲で約60行に収まり、不適合サンプル（余剰キー＋enum違反）で
  ちょうど2件検出されることまで固定できた。

## ダメだったこと（踏んだ罠）

- **Writeツールで `slides-to-records.jq` を書いた際、jqのUnicodeエスケープ表記
  （バックスラッシュ＋u001f等の6文字）がツール呼び出しのJSONデコードで生の制御バイトへ
  解決され、7バイト混入した**（このタスクで4回目。過去3回はGitHubコメント2回・Bash検証1回で、
  Writeツールでは初）。書いた直後のバイト数比較（`wc -c` vs `tr -d '\000-\037'` 後）で検出し、
  pythonの `replace`（python側は `'\\u001f'` と二重エスケープで書く）で修復した。
  **エスケープ表記を含むファイルはWrite直後に必ずバイト数比較で検査する。**
  同じ罠を結果レポートmdの執筆でも踏み（説明文中にエスケープ表記を書いた箇所が生バイト化・
  2バイト）、同様に検出・修復した。説明文では「u001f」のようにバックスラッシュ抜きで書くか
  言葉で説明するのが安全。
- **jqの「パイプ右辺で `.` が差し替わる」罠**（`shell-script-style.md` 記載済み）を
  `schema_check.jq` の `select(($v | has(.)) | not)` で踏んだ（`has(.)` の `.` が `$v` に
  なり "Cannot check whether object has a object key"）。`. as $k` の束縛で解消。
- 敵対的レビューP4R1の指摘AR-4-02のとおり、`import jsonschema` は `ModuleNotFoundError`
  （計画修正時に実測済み）。jq決定的チェックへ倒す計画変更が正しかった。

## 結果

- `bash .claude/scripts/test/test_json_to_pptx.sh` → `passed=88 failures=0`
- 既存テスト22本全件 rc=0・`check-dist-coverage.sh` OK（501/501）・
  `extract-frontmatter.sh .` files=182 failed=0・`generate-ddr-list.sh` 差分1行・
  `check-doc-references.sh` 参照切れ0
- 詳細と判断の根拠は結果レポート（md+html）を参照。
