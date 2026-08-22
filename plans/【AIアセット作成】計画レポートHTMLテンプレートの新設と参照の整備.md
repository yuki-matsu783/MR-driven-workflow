---
title: 【AIアセット作成】計画・レポートHTMLテンプレートの新設と参照の整備
type: plan
description: issue #54の個別作業計画。assets/配下へHTMLテンプレート2本を新設し、SKILL.md・rules・canvas-reportの参照を整える。
tags: [issue-mr-flow, plan, template, html]
keywords: [plans.template.html, reports.template.html, assets, canvas-report, 改名, docs-workflow, directory-structure, markdown-frontmatter, flow-id]
---

# 【AIアセット作成】計画・レポートHTMLテンプレートの新設と参照の整備（issue #54 / フェーズ3）

全体作業計画: `plans/tidy-scoping-lantern.md`

## 前提（合意状況）

- 依拠する調査結果: `reports/20260822_tidy-scoping-lantern_HTMLビュー前提調査.md`（flow-id 2-6）。
  本計画の方針はすべて同レポートの「設計への反映」に対応する。
- **flow-id 1-5・2-8 の人間合意は得ていない。** 本セッションは非対話的に進めており、結果確認
  工程は `adversarial-review` スキルで代替している。
- 種別を `【AIアセット作成】` としたのは、このissueの**主たる成果物**がAIアセット
  （スキルのバンドルリソースと、それを参照するスキル定義・ルール）だからである。作業の
  **副産物**として気づいた改善を反映する `【AIアセット反映】`（フェーズ4）とは区別する。

## この計画で何をするか

`.claude/skills/issue-mr-flow/assets/` へHTMLテンプレートを2本新設し、
`plans/` と `reports/` の人間レビュー用HTMLビューの**記述の型の正**をそこへ一本化する。
あわせて `.claude/skills/canvas-report/templates/` を `assets/` へ改名し、リポジトリ内の
バンドルリソースの語彙を1つに揃える。

**markdownテンプレートは作らない。** `plans/*.md` `reports/*.md` の見出し構成は引き続き
規定しない（issue #54 本文が明示的に除外）。

## 変更対象

| # | ファイル | 操作 | 何をするか |
|---|---|---|---|
| 1 | `.claude/skills/issue-mr-flow/assets/plans.template.html` | 新規 | 計画のHTMLビューの土台 |
| 2 | `.claude/skills/issue-mr-flow/assets/reports.template.html` | 新規 | レポートのHTMLビューの土台 |
| 3 | `.claude/skills/canvas-report/templates/canvas-report.html` | 改名 | `assets/canvas-report.html` へ `git mv` |
| 4 | `.claude/skills/canvas-report/SKILL.md` | 変更 | コピー元パス（123行目）と、HTMLの方式の記述（description・30・157-160行目） |
| 5 | `.claude/skills/issue-mr-flow/SKILL.md` | 変更 | 全体フロー表 2-6・3-6・4-6、`start` 手順3、1-4・2-1・3-1・4-1、「計画と実施結果の分離」、flow-id 5-3 の暫定記述の解除 |
| 6 | `.claude/rules/docs-workflow.md` | 変更 | ライフサイクル表へ `plans/*.html` の行を新設、`reports/*.html` 行の方式の記述、**および 31-34行目の段落**（「`.html` が必須なのは flow-id 2-6 だけ」。3-6・4-6 も必須化するため正面から矛盾する） |
| 7 | `.claude/rules/directory-structure.md` | 変更 | ツリーへ `assets/`、`reports/` の説明（74行目）、「配置の指針」（108-109行目）を `assets/` 既定へ |
| 8 | `.claude/rules/markdown-frontmatter.md` | 変更 | `plans/*.html` `reports/*.html` がfrontmatter対象外である旨を明記 |
| 9 | `reports/REVIEW-POINTS.md` | 変更 | 「TailwindCSS CDN以外の外部依存が無いか」をテンプレート基準の表現へ。埋め忘れ（`ここに書く`）の検査も足す |
| 10 | `plans/REVIEW-POINTS.md` | 変更 | **`## HTML版` 節を新設**（`plans/` にもHTMLビューが増えるため。`reports/` 側にしか無いと、計画のHTMLがレビュー観点を1つも持たない） |
| — | `cleanup-task.sh` / `extract-frontmatter.sh` / `.gitignore` / `sync-assets.sh` | **変更しない** | 調査（Q6・Q7・Q9）で不要と確認済み |

**触らない**（調査 Q5-2 の8箇所）: DDR本文（`i0141-01` `i0000-11` `i0087-01` `i0032-01`
`i0111-01:145`）と `.claude/docs/spec/issue-mr-workflow.md` の `## 影響範囲` 配下の過去changelog
（2049・2652・**3280**行目）。point-in-time の記録であり、書き換えると当時の事実が失われる。

**`spec/issue-mr-workflow.md:677` は改訂対象だが、このフェーズでは触らない。** 同じ
「issue #54 の成果物。未作成の間は手書きへフォールバックする」という暫定記述だが、
`spec/` への反映は flow-id 4-6（設計反映）の担当である。**同じファイルの 3280行目とは扱いが
逆になる**（677は `## 仕様` 配下＝現在の設計の説明、3280は `## 影響範囲` 配下＝当時の記録）。
分かれ目は `## 影響範囲`（1754行）より下かどうかであって、issue番号でも文面の似かたでもない。

## 方針

### テンプレート2本の中身

- **外部依存を1つも持たない自己完結CSS**（調査 Q1）。`<style>` へ直書きし、CDN・外部フォント・
  画像を参照しない。**2ファイルのCSSは同一の内容を持たせる**（共有CSSファイルへ切り出すと
  「自己完結」でなくなるため、重複を許容する）。
- **共通ヘッダ帯**に issue番号・ブランチ・PR番号・フェーズ（flow-id）・push回数・作成日・
  「正文は同名の .md」を置く（issue #54 本文の要求）。値の無い項目は `li` ごと削除してよい。
- **見出し・表・コードブロック・注意ボックス**のスタイルを持たせる。注意ボックスは
  `info` / `ok` / `warn` / `stop` の4種。
- **必須／任意セクションを区別する。** 各 `<section>` の直前のHTMLコメントへ `[必須]` `[任意]` を
  書き、任意は「不要なら `<section>` ごと削除する」と明記する。
- **プレースホルダはHTMLコメントで書く**（`worklog/TEMPLATE.md` と同じ方式）。文言は
  「ここに書く: …」で統一し、`grep -c 'ここに書く' <出力>` が 0 であることを埋め忘れの検査に使う。
- ライト／ダーク両対応（`prefers-color-scheme`）。表は `.tablewrap` の中で横スクロールさせ、
  ページ本体を横スクロールさせない。

#### セクション構成の根拠

調査 Q2 のとおり、次の**3つ**から起こす。

1. **既存の実物2件に共通する要素**（PR #80 の issue #77 分、PR #128 の issue #127 分。
   マージ済みPRのコミット断面をMCPで取得して全文を読んだ）。共通していたのは
   ヘッダ帯（issue / PR / flow-id / 日付）・h1＋1文のリード・結論のサマリ（カード数枚）・
   表主体の詳細・次にやること／引き渡すこと・範囲外と未完了の明示・正文mdへの参照（footer）。
2. `plans/REVIEW-POINTS.md` / `reports/REVIEW-POINTS.md` のレビュー観点（レビュアーが実際に
   確認する項目）
3. `.claude/skills/issue-mr-flow/SKILL.md`「計画と実施結果の分離」の表（計画＝目的・変更対象・
   方針・やらないこと・検証手順／結果＝実施した内容と、その結論・根拠・確認結果）

**3つが食い違った箇所が1つある。** 実例2件はいずれも「確かめられなかったこと」を独立した節に
していない（#128 は footer の「未完了（範囲内・引き継ぐ）」がそれに当たる）。一方
`reports/REVIEW-POINTS.md` は確認できなかったことの明示を観点に挙げている。**レビュー観点を
優先して必須セクションとして立てる**（実例が持っていないのは、まさにテンプレートが無かった
ために書き落とされやすい項目だからだと解釈した）。

**`plans/*.html` の実例は1件も無い**（本issueが新設するもの）。plans側の必須／任意は
2・3 だけを根拠に持ち、実例による裏付けが無い。

| | `plans.template.html` | `reports.template.html` |
|---|---|---|
| **必須** | この計画で何をするか／変更対象／方針／やらないこと（スコープ外）／検証 | サマリ（結論の一覧）／実施した内容と結果／確かめられなかったこと／設計への反映 |
| **任意** | 前提（合意状況）／issueの受け入れ条件との対応／比較検討した案／目次 | 実施条件（測った対象・環境。実測を含むなら必須）／想定と異なった点／残課題／目次 |

### ファイル名規則（`plans/` のHTMLビュー）

対応する `.md` と**同じベース名で拡張子だけ `.html`**（調査 Q3）。全体作業計画のHTMLも
ハーネスが提示した自動命名をそのまま使い、AIが別名を付け直さない。

### SKILL.md の改訂方針

- **HTMLビューの見出し構成をSKILL.mdへ列挙しない**（issue #54 の受け入れ条件）。
  「テンプレートの構成に従う」と参照するだけにする。
- テンプレートを**読んでから書く**手順を、次の各所へ明記する（置くだけでは読まれないため）。
  - `start` サブコマンドの手順3
  - flow-id 1-4・2-1・3-1・4-1（計画のHTMLビュー）
  - flow-id 2-6・3-6・4-6（レポートのHTMLビュー）
- **HTMLレポートを 2-6 に加えて 3-6・4-6 でも作成する**ことを全体フロー表へ反映する。
  現行は **3-6 が「結果を視覚的にまとめる必要があれば同名の `.html` も作成する」（任意）**、
  **4-6 はHTMLへの言及そのものが無い**（調査 Q4）。3-6 は任意→必須へ、4-6 は新規に追記する。
  なお実例（PR #128）では**1つのHTMLがフェーズをまたいで育っていた**ため、この変更は
  「フェーズごとに別ファイルを作れ」という意味ではない。**md が増えれば html も増える**
  （md 1本に html 1本）というだけである。
- **flow-id 5-3 の暫定記述を解除する。**

  置き換え前（現行。`SKILL.md` の flow-id 5-3 の節）:

  > HTMLは `.claude/skills/issue-mr-flow/assets/reports.template.html` を土台にする。
  > **このテンプレートは issue #54 の成果物であり、まだ存在しない。存在しない間は、従来どおり
  > TailwindCSS CDN方式の自己完結HTMLを手書きしてよい**（`.claude/skills/canvas-report/SKILL.md` の
  > 判断基準は統括レポートにも当てはまる）。テンプレートが入った時点で、土台をそちらへ移す。

  置き換え後（案）:

  > HTMLは `.claude/skills/issue-mr-flow/assets/reports.template.html` を土台にする
  > （`.claude/skills/canvas-report/SKILL.md` の判断基準は統括レポートにも当てはまる）。

  **置き換え対象の3文が兼ねていた役割は「テンプレートが無い間の代替手段の提示」だけであり、
  他の役割を兼ねていない**（canvas-report への参照は置き換え後も残す）。

### `docs-workflow.md` のライフサイクル表への追加行（案）

`plans/【種別】タスク内容.md` の行の直後へ、次の1行を足す。

| 列 | 値 |
|---|---|
| ファイル | `plans/<全体作業計画・個別計画と同名>.html` |
| 対象 | 人間＋AI |
| 寿命 | 同上（タスク単位。flow-id 5-4でまとめて削除） |
| 内容 | 上記mdの内容を視覚的にまとめた自己完結HTML（人間レビュー用ビュー）。**計画の正文はmd側であり、HTMLはその視覚化** |
| 運用 | flow-id 1-4・2-1・3-1・4-1で作成し、md側の内容と同期して更新する。土台は `.claude/skills/issue-mr-flow/assets/plans.template.html`。**削除はflow-id 5-4**。`.gitignore`には加えない |

### `directory-structure.md`「配置の指針」の改訂（案）

置き換え前（108-110行目）:

> 各`.claude/skills/<name>/`は`SKILL.md`単体が基本だが、スキルの実行に必須のバンドルリソース
> （テンプレート・補助スクリプト等）がある場合は`.claude/skills/<name>/templates/`のような
> サブディレクトリを追加してよい（実例: `canvas-report/templates/canvas-report.html`）。他に
> `scripts/`・`references/`・`assets/`等、用途に応じた名前を使ってよい。

置き換え後（案）: `assets/`（出力に使うもの）・`scripts/`（実行するもの）・`references/`
（AIが読むもの）の3語彙を示し、**`templates/` は使わない**ことを明記する。実例を
`issue-mr-flow/assets/reports.template.html` と `canvas-report/assets/canvas-report.html` に
差し替える。あわせて、**`apply-mr-workflow-to-project/assets/` だけは
`sync-assets.sh` が生成するビルド用一時ディレクトリで `.gitignore` 対象**であり、
スキル配下の恒久リソースとしての `assets/` とは別物であることを1文で区別する（調査 Q9）。

## やらないこと（スコープ外）

- **markdownテンプレートの新設**（issue #54 本文が明示的に除外）。
- **最終統括レポート専用のテンプレート**（同上）。統括レポートは `reports.template.html` を
  土台にするので、専用テンプレートは要らない。
- **`HANDOFF.md` のテンプレート外だし**（調査 Q8。DDR `i0028-01` を覆さない）。
- **`.mrworkflow.json` への設定項目追加**（issue #54 本文が明示的に除外。テンプレートはパス固定）。
- **canvas形式テンプレートの中身の変更**（改名のみ）。
- **`.claude/VERSION` の更新**。配布対象アセットに変更があるため増分の**提案**はフェーズ4
  （flow-id 4-6）で行うが、**決めるのは人間**であり、AIが独断で上げない
  （`.claude/docs/spec/distribution-assets.md`）。
- **spec/DDRへの反映**。フェーズ4（flow-id 4-6）で行う。

## 検証

```bash
# 1. HTMLの構文が壊れていないこと（パースできること）
python3 - <<'PY'
import html.parser, io
class P(html.parser.HTMLParser): pass
for f in ['.claude/skills/issue-mr-flow/assets/plans.template.html',
          '.claude/skills/issue-mr-flow/assets/reports.template.html',
          '.claude/skills/canvas-report/assets/canvas-report.html']:
    P().feed(io.open(f, encoding='utf-8').read()); print('parse ok:', f)
PY

# 2. 外部依存が無いこと（http/https を参照する行が0であること）
grep -c 'https\?://' .claude/skills/issue-mr-flow/assets/plans.template.html
grep -c 'https\?://' .claude/skills/issue-mr-flow/assets/reports.template.html

# 3. ブラウザ実機で崩れないこと（同梱Chromiumでライト/ダーク両方をスクリーンショット）
/opt/pw-browsers/chromium-1194/chrome-linux/chrome --headless --disable-gpu --no-sandbox \
  --window-size=1200,900 --screenshot=<出力先> file://<テンプレートの絶対パス>

# 4. リポジトリ内に templates/ という名前のバンドルディレクトリが残っていないこと
find .claude/skills -type d -name templates

# 5. 改名に伴うパス置換がDDR本文へ及んでいないこと（削除行が0であること）
git diff <ブランチ分岐点のSHA> -- .claude/docs/ddr/ | grep -c '^-[^-]'

# 6. index.jsonl が壊れていないこと（frontmatterインデックスの再生成が通ること）
bash .claude/scripts/src/extract-frontmatter.sh .
```

合格条件: 1〜3が通り、4が0件、5の削除行が0、6が非0で終わらないこと。

### とくに気をつけること（実際に踏んだ）

**テンプレート冒頭の使い方コメントの中に `-->` を書かない。** HTMLコメントはネストできず、
`<!-- [必須] -->` のような例をコメント内へ書くとそこでコメントが閉じ、以降の説明文が**ページ本文
として表示される**（下書き段階のレンダリング確認で実際に発生した）。検証3のブラウザ確認は
この種の崩れを見つけるために必ず行う。

## issueの受け入れ条件との対応

| 受け入れ条件 | 対応 |
|---|---|
| `assets/plans.template.html` と `assets/reports.template.html` が存在し、`SKILL.md` と `docs-workflow.md` から参照されている | 変更対象 1・2・5・6 |
| markdownのテンプレートファイルが新設されていない | スコープ外に明記 |
| `SKILL.md` にHTMLビューの見出し構成の重複記載がない | 方針「SKILL.md の改訂方針」 |
| flow-id 1-4・2-1・3-1・4-1 と 2-6・3-6・4-6 にテンプレートを読む手順が明記されている | 変更対象 5 |
| HTMLレポートを 2-6・3-6・4-6 で作成することが全体フロー表に反映されている | 変更対象 5 |
| `plans/` のHTMLビューが `docs-workflow.md`・`directory-structure.md` に記載され、片付けで削除されることが確認されている | 変更対象 6・7（削除は調査 Q6 で確認済み。**issue本文の「flow-id 5-1」は現行 5-4**） |
| 必須／任意セクションが区別され、プレースホルダがHTMLコメントで書かれている | 方針「テンプレート2本の中身」 |
| `markdown-frontmatter.md` に `plans/*.html` の扱いが記載されている | 変更対象 8 |
| 置き場所が `templates/` ではなく `assets/` になっている | 変更対象 1・2 |
| `canvas-report/templates/` が `assets/` へ改名され、参照が更新されている（`templates/` が残っていない） | 変更対象 3・4・7、検証4 |
