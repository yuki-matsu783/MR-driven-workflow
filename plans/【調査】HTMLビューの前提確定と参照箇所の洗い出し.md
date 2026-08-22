---
title: 【調査】HTMLビューの前提確定と参照箇所の洗い出し
type: plan
description: issue #54の個別調査計画。HTMLの外部依存方式・plans側HTMLの命名規則・改訂対象箇所・削除/インデックスの挙動を実測で確定する。
tags: [issue-mr-flow, plan, 調査, html]
keywords: [TailwindCSS, CDN, 自己完結, plans.template.html, reports.template.html, flow-id, cleanup-task, index.jsonl, canvas-report, assets]
---

# 【調査】HTMLビューの前提確定と参照箇所の洗い出し（issue #54 / フェーズ2）

全体作業計画: `plans/tidy-scoping-lantern.md`

## 目的

テンプレートを書き始める前に、**issue #54 本文が前提としている事実のうち、その後の変更で
動いた可能性があるもの**を確定させる。実装（フェーズ3）で方針が揺れないようにすることが狙い
であり、テンプレートの中身そのものはここでは書かない。

## 調べること（調査項目）

| # | 問い | 確認方法 | この調査で出す成果 |
|---|---|---|---|
| Q1 | 新設テンプレートの外部依存は TailwindCSS CDN方式 と 自己完結CSS のどちらを採るべきか | `curl` でCDN到達性を実測（本セッションの実行環境）／DDR `i0141-01` の適用範囲を読む／`reports/REVIEW-POINTS.md` の「自己完結しているか」の観点を読む | どちらを採るかの結論と根拠。採らなかった側の理由 |
| Q2 | `reports/*.html` の既存の実物はどうなっているか | `git log --all --diff-filter=A -- 'reports/*.html'` で履歴を検索。squash mergeとflow-id 5-4の削除により残っていない可能性がある | 実例を参照できるか否か。参照できない場合、必須／任意セクションの根拠を何に置くか |
| Q3 | `plans/` 側HTMLのファイル名規則をどう決めるか | `plans/` のmdが持つ2つの命名体系（全体作業計画＝自動命名／個別計画＝`【種別】〜`）と、`cleanup-task.sh`・`.gitignore`・`index.jsonl` の挙動を突き合わせる | 命名規則の決定と、その規則が既存機構を壊さない根拠 |
| Q4 | issue本文の flow-id はどれだけ現行とずれているか | issue本文の flow-id と現行 `SKILL.md` の全体フロー表を突き合わせる | 読み替え表（issue本文の番号 → 現行番号） |
| Q5 | 改訂が必要な参照箇所はどこか（全数） | `grep` で `templates/` の参照・`reports/` のHTML作成手順の記述箇所を洗う（`doc-search` でドキュメントの当たりを付けてから本文検索する） | 改訂対象ファイルと箇所の一覧 |
| Q6 | `cleanup-task.sh` は `plans/*.html` を削除するか（受け入れ条件） | スクリプト本文の残すパス定義を読み、`--dry-run` で実際に確かめる | 「スクリプト自体の変更は不要」の確認結果 |
| Q7 | `extract-frontmatter.sh` / `index.jsonl` は `.html` を拾うか | 走査対象の拡張子の実装を読む | `plans/*.html` をfrontmatter対象外と明記する根拠 |
| Q8 | `HANDOFF.md` のテンプレート外だしを本issueへ含めるべきか（issue #28 のマージ前通知） | 該当DDRと `cleanup-task.sh` の設計を読む | 「含めない」ことの結論と理由 |

## やらないこと（この調査のスコープ外）

- **テンプレートの見出し構成の確定**。必須／任意セクションの具体的な列挙は、調査結果を踏まえて
  フェーズ3の個別作業計画で決める（この調査では「何を根拠に決めるか」までを出す）。
- **HTMLの実装・ブラウザ実機検証**。フェーズ3で行う。
- **canvas形式テンプレートの中身の変更**。本issueは `templates/` → `assets/` の改名のみを扱う。

## 検証（この調査自身の確からしさをどう担保するか）

- Q1 は**このセッションの実行環境1つでの実測**であることを明記する。他環境（ローカルの
  git bash等）でCDNが通る可能性は否定しない。結論はこの限定付きで書く
  （`reports/REVIEW-POINTS.md`「測った環境が結論に添えられているか」）。
- Q5 の網羅性は、`grep` の対象を「リポジトリ全体（`.git` を除く）」とし、ヒット件数を
  レポートへ残す（0件だったパターンも残す）。
- Q6 は読んだだけで終えず、`bash .claude/scripts/src/cleanup-task.sh --dry-run` を
  **ダミーの `plans/*.html` を置いた状態で**実行して、削除対象に入ることを実際に確認する。

```bash
# Q1
curl -sS -o /dev/null -w '%{http_code}\n' --max-time 15 https://cdn.tailwindcss.com
# Q2
git log --all --diff-filter=A --name-only --format='%h %ad %s' --date=short -- 'reports/*.html'
# Q5
grep -rn 'templates/' --include='*.md' --include='*.sh' --include='*.json' . | grep -v '^./.git/'
# Q6
printf '<!-- dummy -->\n' > plans/__probe__.html
bash .claude/scripts/src/cleanup-task.sh --dry-run
rm -f plans/__probe__.html
# Q7
grep -n 'md\b\|\.html' .claude/scripts/src/extract-frontmatter.sh
```

## 成果物

- `reports/20260822_tidy-scoping-lantern_HTMLビュー前提調査.md`（正文）
- `reports/20260822_tidy-scoping-lantern_HTMLビュー前提調査.html`（視覚化）

本調査は「複数要素間の関連・依存関係」ではなく**問いごとの結論の一覧**が主題のため、
canvas形式ではなく一覧・表形式のHTMLで表現する（`canvas-report/SKILL.md`「いつcanvasを選ぶか」）。
