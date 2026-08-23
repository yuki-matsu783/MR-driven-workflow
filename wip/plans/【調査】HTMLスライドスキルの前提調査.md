---
title: 【調査】HTMLスライドスキルの前提調査
type: plan
description: issue #168 のスキル・テンプレート・サブエージェント2本を設計するために必要な既存規約・置き場所・命名の調査計画
tags: [plan, research, slides]
keywords: [調査計画, テンプレート規約, サブエージェント規約, スキル名, 出力先, JSONスキーマ, dist-layers, sync-gemini-assets]
---

# 【調査】HTMLスライドスキルの前提調査

- issue: #168 / PR: #194
- フェーズ: 2〈調査〉 flow-id 2-1
- 上位計画: `wip/plans/html-slides-skill-plan.md`

## 目的

フェーズ3で作る4点（スライドテンプレート・SKILL.md・サブエージェント2本・構成案JSONスキーマ）の
設計を確定するために、既存の規約・実例・影響範囲を調べ、個別作業計画（flow-id 3-1）が
書ける状態にする。

## 調査項目（問いの形）

| # | 問い | 調べ方 | 何が分かれば次へ進めるか |
|---|---|---|---|
| Q1 | 既存テンプレート3本（`plans.template.html` / `reports.template.html` / `canvas-report.html`）の冒頭コメント・スタイル変数・ダークモード対応・プレースホルダ検査はどう作られているか | 3本を読み、共通する構成要素を表にする | `slides.template.html` が踏襲すべき要素の一覧（冒頭コメントの構成・`--bg` 等のCSS変数・`prefers-color-scheme`・`grep -c` 検査） |
| Q2 | サブエージェント定義（`.claude/agents/` 既存2本）のfrontmatter・本文構成・ツール制限はどう書かれているか | `adversarial-reviewer.md` / `issue-mr-resume.md` を読む | 新規エージェント2本のfrontmatterキー（`name`/`description`/`tools`等）と本文の見出し構成の型 |
| Q3 | スキル名は何にするか | 既存スキル名（`canvas-report` 等）の命名傾向を確認し、候補を比較する | ディレクトリ名（`.claude/skills/<スキル名>/`）の確定 |
| Q4 | スライドHTMLの出力先ディレクトリの既定はどこにするか | `wip/reports/` の寿命（flow-id 5-5で削除）・`.gitignore`・`directory-structure.md` を確認し、選択肢（`wip/reports/`／恒久ディレクトリ新設／その他）を比較する | 既定の出力先と、その寿命・`.gitignore` 上の扱いの確定（issue #168「期待する動作 4.」） |
| Q5 | 構成案JSONスキーマはどこに・どの形式で置くか | `directory-structure.md` の `assets/`・`references/`・`scripts/` の語彙定義を確認する。スキーマの検証手段（jq）も確認する | スキーマファイルの置き場所・形式（JSON Schema）・SKILL.md/エージェント定義からの参照方法 |
| Q6 | 新規ファイルは配布・同期・インデックスの仕組みにどう影響するか | `dist-layers.json` の層分け定義・`check-dist-coverage.sh` の検査対象・`sync-gemini-assets.sh` の変換対象・`extract-frontmatter.sh` の走査対象を確認する | 追加が必要な設定変更の一覧（無ければ「変更不要」の根拠） |
| Q7 | ドキュメントへの追記はどこに必要か | `directory-structure.md` のツリー・`markdown-frontmatter.md` の type 表を確認する | フェーズ4で追記すべき箇所の一覧（`type: skill` / `type: agent` は既存値で足りるかを含む） |

## やらないこと

- テンプレート・スキル・エージェントの実装（フェーズ3）
- 出力先ディレクトリ以外の新規ディレクトリ提案
- 既存テンプレート3本の変更

## 検証

- 調査結果を `wip/reports/2026-08-23_html-slides-skill-plan_前提調査.md`（+同名.html）に記録し、
  Q1〜Q7 のすべてに答えが書かれていること。
- Q3・Q4・Q5 は選択肢の比較（利点・欠点・採否）を含むこと（採用案はフェーズ3の計画の前提になる）。
