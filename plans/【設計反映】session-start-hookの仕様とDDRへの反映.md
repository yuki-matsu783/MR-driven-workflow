---
title: 【設計反映】session-start hookの仕様とDDRへの反映
type: plan
description: issue #113の実装内容をspec・DDR・docs READMEへ反映する個別反映計画
tags: [plan, docs, spec, ddr]
keywords: [issue113, 設計反映, spec, DDR0059, README, 影響範囲, AIアセット反映]
---

# 【設計反映】session-start hookの仕様とDDRへの反映

全体作業計画: `plans/breezy-humming-lantern.md`
対象issue: #113

## 反映対象の洗い出し（flow-id 4-1）

| 反映先 | 反映するもの | 要否 |
|---|---|---|
| `.claude/docs/spec/issue-mr-workflow.md`「セッション開始時の自動コンテキスト注入」節 | 対象判定の2材料と「いずれか一方でも成り立てば対象」、指示文の要点、対象外では足さないこと、起動要因で分岐しないこと、注入量への影響 | **要** |
| 同 「構造とテスト」の純粋関数一覧 | `issue_mr_flow_branch_reason` / `format_skill_reload_instruction` を追加 | **要** |
| 同 「影響範囲」 | issue #113 のエントリ（新規・変更ファイルの一覧、matcherを変更していないこと） | **要** |
| `.claude/docs/ddr/0059-….md`（新規） | 判定材料の選び方・指示文を末尾へ置く理由・DDR 0032との整合・却下案5件 | **要** |
| `.claude/docs/README.md` | DDR一覧へ 0059 を追加 | **要** |
| `.claude/rules/` `.claude/skills/`（AIアセット反映） | — | **不要**（下記） |
| `.gemini/settings.json` | — | **不要**（下記） |

## AIアセット反映を不要と判断した理由

今回の作業で新しく判明した規約違反・ルールの不備が無かった。踏んだ落とし穴は
`.claude/rules/shell-script-style.md` に既出のものだけである。

- コミットhook・push検知hookの部分文字列マッチによる誤検知（結合確認用のスクリプトで
  実際に1回踏んだ）→ 「git運用」節・「push検知hookの誤検知」節に既に記載がある。
- `set -e` 配下でのコマンド置換・`|| true` の扱い → 「エラー方針」節に既に記載がある。
- 日本語を含む文字列の比較で `${var:0:N}` を使わない → 「テスト」節に既に記載がある。

既存ルールで説明できる範囲のため、追記すると同じ内容の重複になる。

## spec側で気をつけること

- 「セッション開始時の自動コンテキスト注入」節は**現在の状態を説明する節**のため、新しい仕様を
  そのまま書き足してよい。
- 「影響範囲」の**過去issueごとのエントリは書き換えない**（point-in-timeの記録。
  `.claude/rules/docs-workflow.md`）。issue #113 は新規エントリとして末尾（`## 設定項目` の直前）へ
  追加する。
- 差し込み位置の直前の節が「節全体にかかる地の文」で終わっていないかを確認する
  （`.claude/rules/docs-workflow.md`）。issue #112 のエントリ末尾はDDRの本文を書き換えない旨の
  段落で、次の見出しは `## 設定項目`。issue #113 のエントリはその間へ独立した `###` として入る
  ため、係り先は変わらない。

## DDRに残すこと

「何を決めたか」だけでなく「なぜ他の案ではないか」を残す。少なくとも次の5件を却下案として書く。

1. SKILL.mdの中身（または要約）を注入する
2. ブランチによらず常に注入する（判定を持たない）
3. 判定を `HANDOFF.md` の進捗表の有無で行う
4. `compact` のときだけ注入する
5. `AGENTS.md`／`CLAUDE.md` に書くだけにする（要約対象に入るため同じ問題が残る）

## 検証

- `bash .claude/scripts/src/extract-frontmatter.sh .` で新規mdのfrontmatterがインデックスへ入ること。
- DDR番号 0059 が重複していないこと（`.claude/docs/ddr/` の一覧と `.claude/docs/README.md`）。
- specへ追加したリンクのパスが実在すること。
