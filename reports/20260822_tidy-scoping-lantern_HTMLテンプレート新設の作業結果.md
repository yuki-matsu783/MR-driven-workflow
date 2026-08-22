---
title: 計画・レポートHTMLテンプレート新設の作業結果
type: report
description: issue #54 フェーズ3で実施した、HTMLビューのテンプレート2本の新設・参照の整備・canvas-reportの改名の作業結果。
tags: [report, issue-54, html-template, ai-asset]
keywords: [plans.template.html, reports.template.html, assets, canvas-report, 自己完結, 外部依存, 埋め忘れ, 敵対的レビュー, テンプレート, 必須セクション]
---

# 計画・レポートHTMLテンプレート新設の作業結果（issue #54 / フェーズ3）

## サマリ（結論の一覧）

1. **テンプレート2本を `.claude/skills/issue-mr-flow/assets/` へ新設した**
   （`plans.template.html` / `reports.template.html`）。どちらも自己完結HTMLで、
   外部を読みに行く記述を1つも持たない。
2. **`canvas-report/templates/` を `assets/` へ改名した**。これで
   `.claude/rules/directory-structure.md` が定める3語彙（`assets/` / `scripts/` / `references/`）に
   リポジトリ内の実体が揃い、`templates/` という名前のバンドルディレクトリは0件になった。
3. **参照側6ファイルを改訂した**（`issue-mr-flow/SKILL.md`・`canvas-report/SKILL.md`・
   `rules/docs-workflow.md`・`rules/directory-structure.md`・`rules/markdown-frontmatter.md`・
   `index.md`）。SKILL.mdは**見出し構成を列挙せず、テンプレートを参照する**形にした
   （issue #54 の受け入れ条件）。
4. **`plans/` にもHTMLビューを置くルールを新設し、REVIEW-POINTS 2本へ観点を足した**。
   本計画自身のHTMLビューを `plans.template.html` から起こし、テンプレートの実地検証を兼ねた。
5. **敵対的レビュー（フェーズ3の1回目）の指摘13件すべてに対応した**（投稿9件＋報告4件）。
   最も重かったのは「自己完結の検査 `grep -c 'https\?://' が 0` が、正しい成果物を必ず
   不合格にする」という誤りで、検査を実際に外部を読みに行く記述だけに限定した。

## 実施条件（測った対象・環境）

- 実行環境: Claude Code on the web のリモート実行環境（Linux 6.18.44 / コンテナ）。
  **外部通信は遮断されている**（CDNへは到達できない）。
- 対象: このリポジトリの `claude/plan-report-html-template-024l0t` ブランチ（`6e77122` 時点）。
- ブラウザ: 同梱Chromium（`/opt/pw-browsers/chromium-1194/chrome-linux/chrome`）を
  `--headless --screenshot` で使用。ライト／ダークの2回。
- 実施日: 2026-08-22。
- **1環境・1ブラウザの観測である。** Windows（git bash）・他ブラウザでの確認は行っていない
  （下記「確かめられなかったこと」）。

## 実施した内容と結果

### 1. テンプレート2本の新設

| ファイル | 必須セクション | 任意セクション |
|---|---|---|
| `plans.template.html` | この計画で何をするか／変更対象／方針／やらないこと／検証 | 前提（合意状況）／目次／issueの受け入れ条件との対応／比較検討した案 |
| `reports.template.html` | サマリ／実施した内容と結果／確かめられなかったこと／設計への反映 | 目次／実施条件（実測を含むなら必須）／想定と異なった点／残課題 |

- 必須／任意の区別は、各 `<section>` の直前のHTMLコメント（`[必須]` / `[任意]` /
  `[全体作業計画のみ必須]`）で示す。
- **プレースホルダはHTMLコメント**（`<!-- ここに書く: … -->`）で統一した。HTMLはYAML
  frontmatterを持てないため、使い方・必須／任意の区別・埋め忘れの検査方法は
  **ファイル冒頭のHTMLコメント**に置いている。
- スタイルはCSSカスタムプロパティ＋`prefers-color-scheme` で、ライト／ダーク両方に対応する。

### 2. `plans.template.html` に全体作業計画向けの節を足した

初版は個別計画（flow-id 2-1・3-1・4-1）の粒度しか持っておらず、**全体作業計画（1-4）に
SKILL.mdが要求するフェーズ2〈調査〉・フェーズ4〈反映〉の節が無かった**（敵対的レビューの指摘）。
`[全体作業計画のみ必須]` の2セクションを新設し、冒頭コメントへ次の読み替えを書いた。

- この2セクションは、**実施しない判断をした場合も節ごと削らず**「実施しない」と理由を書く
  （枠を残すことで、後から必要だと分かったときに拾い直せる。issue #92 の目的）。
- 「変更対象」は全体作業計画では**ファイル群・領域の粒度**で書く（個別のファイル・行は個別計画側）。
- 「検証」は全体作業計画では**issue全体の完了条件**を書く（コマンド単位の検証は個別計画側）。

### 3. 自己完結の検査を「実際に外部を読みに行く記述」へ限定した

当初の検査（`grep -c 'https\?://' <ファイル>` が 0）は、次の実測どおり**正しい成果物を
必ず不合格にする**ものだった。

| 対象 | `grep -c 'https\?://'` | 内訳 |
|---|---|---|
| `reports/20260822_…_HTMLビュー前提調査.html` | 3 | すべて `<pre><code>` 内のURL引用（外部依存ではない） |
| `.claude/skills/canvas-report/assets/canvas-report.html` | 6 | mermaid CDN 1件＋`http://www.w3.org/2000/svg` 5件（`createElementNS` の名前空間） |

改めた検査は次のとおり（`plans/REVIEW-POINTS.md`・`reports/REVIEW-POINTS.md`・
計画mdの検証節を揃えた）。

```bash
grep -nE '(src|href)="https?://|url\(https?://' <ファイル>   # 0件であること
```

canvas形式でmermaidを使う場合は `<script src>` が1本入るため、明示的に対象外とした。

### 4. 埋め忘れの検査パターンを揃えた

`grep -c 'ここに書く'` は、**テンプレート自身を説明する計画・レポート**（地の文で「ここに書く」に
触れる成果物）を必ず誤検知する。実測で、本計画のHTMLは3件ヒットした。
`grep -c '<!-- ここに書く'` へ改め、SKILL.md・REVIEW-POINTS 2本・テンプレート2本・計画md/htmlの
**6箇所すべてを同じパターンに揃えた**（初版はSKILL.mdと計画md/htmlだけが旧式で取り残されていた）。

### 5. 検証結果

| # | 確認項目 | 手段 | 結果 |
|---|---|---|---|
| 1 | HTMLの構文が壊れていない | `html.parser` でパース | パース成功（3ファイル） |
| 2 | 新設2本が外部を読みに行かない | `grep -nE '(src\|href)="https?://\|url\(https?://'` | 0件 |
| 2-b | 計画のmdとHTMLで節見出しが一致 | `##`/`###` と `<h2>`/`<h3>` の `diff` | 差分なし |
| 3 | ブラウザ実機で崩れない | 同梱Chromium `--headless --screenshot`（ライト／ダーク） | 崩れなし |
| 4 | `templates/` という名前のバンドルディレクトリが残っていない | `find .claude/skills -type d -name templates` | 0件 |
| 5 | 改名に伴うパス置換がDDR本文へ及んでいない | `git diff <分岐点> -- .claude/` の削除行 | 0行 |
| 6 | frontmatterインデックスが再生成できる | `extract-frontmatter.sh .` | `failed=0` |

## 確かめられなかったこと

- **Windows（git bash）実機での確認は行っていない。** この作業はすべて Claude Code on the web の
  Linuxリモート実行環境で行った。HTMLの表示・`grep` の挙動はプラットフォーム非依存だが、
  ユーザーの常用環境での見た目は確認できていない。
- **CDN方式との見た目の比較はできない。** この環境は外部通信が遮断されており、
  TailwindCSS CDNを読む形のHTMLは**1度も表示を確認できない**。したがって
  「自己完結CSSとCDN版のどちらが読みやすいか」は比較していない（方式の選択理由は下記）。
- **人間のレビューを受けていない。** 本セッションは非対話で進めており、flow-id 3-3/3-4/3-8 の
  人間レビューは `adversarial-review` スキルで代替している。テンプレートの
  「読みやすさ・使いやすさ」という主観的な品質は、この代替では検証できていない。
- **全体作業計画（flow-id 1-4）へテンプレートを適用した実例が無い。** 遡って作らない方針
  （計画のスコープ外）にしたため、`[全体作業計画のみ必須]` の2セクションが実運用で
  過不足ないかは、次のissueで初めて確かめられる。

## 設計への反映

1. **`.claude/docs/spec/issue-mr-workflow.md`**: `:677` 付近の暫定記述（テンプレートが無い前提の
   代替手段の提示）を解除し、テンプレート2本を前提とした仕様節を新設する（フェーズ4）。
2. **`.claude/docs/ddr/i0054-01-計画レポートのHTMLビューはassets配下のテンプレートへ切り出す.md`**
   を、**このファイル名で**新規作成する（`issue-mr-flow/SKILL.md` が既にこの名前で参照している。
   記録する決定は (a) レポートHTMLの方式をTailwindCSS CDNから自己完結CSSへ変えたこと、
   (b) バンドルリソースの語彙を `assets/` に統一し `templates/` を使わないこと）。
3. **既存DDRへの `note` 追加**: `i0000-11`（CDN方式を採った決定）と `i0141-01`（canvas形式を
   自己完結にした決定）へ、issue #54 で前提が変わった旨の `note` を足す。
   **`status: superseded` は使わない**（どちらも決定の一部だけが変わったため）。
   追加後に `bash .claude/scripts/src/generate-ddr-list.sh` を再実行する。
4. **`.claude/VERSION` の増分を提案する**（配布対象アセットが増えたため）。
   **決めるのは人間**であり、AIが独断で上げない（`.claude/docs/spec/distribution-assets.md`）。

## 想定と異なった点

- **テンプレートを自分で使うと、テンプレート自身の欠陥が出た。** 本計画のHTMLビューを
  `plans.template.html` から起こす過程で、埋め忘れ検査の誤検知（地の文の「ここに書く」）が
  判明した。**テンプレートを説明する成果物は、そのテンプレートにとって最悪の入力になる**という
  形で、実地検証が効いた。
- **「自己完結」という語が2つの意味で使われていた。** 「外部を読みに行かない」と
  「URLを1文字も含まない」は別物で、後者の意味で検査を書くと `http://www.w3.org/2000/svg`
  （SVGの名前空間）で必ず落ちる。検査を書くときは前者だけを見る。

## 残課題

- フェーズ4での反映（上記「設計への反映」の4項目）。
- ~~`reports.template.html` の外部依存方式について、ユーザーの判断を待っている。~~
  **決着した（2026-08-22、チャットで受領）。「自己完結CSSで良い」。** issue #54 本文は
  「TailwindCSS CDN通常版」と書いているが、CDN方式を採ったDDR `i0000-11` の根拠（トークン量と
  表現力の釣り合い）が**テンプレート化すると成り立たなくなる**という判断が承認された。
  テンプレート2本の書き換えは不要。この判断はMRへ記録した。
- **`.claude/VERSION` の増分も決着した（同上）。「`0.1.2` で良い」。** AIからは `0.2.0`（MINOR）を
  提案したが、据え置きとなった。したがってフェーズ4でも `.claude/VERSION` は変更しない。
