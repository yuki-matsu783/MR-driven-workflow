---
title: 調査結果: HTMLスライドスキルの前提調査
type: report
description: issue #168 のスキル・テンプレート・サブエージェント2本の設計を確定するための前提調査（Q1〜Q8）の結果
tags: [report, research, slides]
keywords: [調査結果, テンプレート規約, サブエージェント規約, スキル名, 出力先, JSONスキーマ, dist-layers, sync-gemini-assets, Playwright]
---

# 調査結果: HTMLスライドスキルの前提調査

- issue: #168 / PR: #194
- フェーズ: 2〈調査〉 flow-id 2-6
- 個別調査計画: `wip/plans/【調査】HTMLスライドスキルの前提調査.md`
- 実施日: 2026-08-23。一次情報はリポジトリ内のファイル・issue本文・実行環境の実測のみ（外部Web不使用）

## 重点レビュー依頼

- ◆特に見てほしい（判断に困っている）
  - **Q4. 出力先の既定を `wip/reports/`（タスク単位で削除される寿命）とした点**。恒久保存の需要が
    強いなら結論が変わる。既定のままでよいかを決めてほしい。
- ◇承認が欲しい（方針は決めたので確認してほしい）
  - Q3. スキル名 `html-slides`。
  - Q5. スキーマの置き場所 `references/slide-outline.schema.json` と「HTML固有の表現を含めない」方針。
- ・細かいレビューは不要（ほぼ確実）
  - Q1・Q2（既存ファイルの読解）、Q6・Q7（実装・設定の実測で「変更不要」を確認済み）。

## サマリ（結論の一覧）

| # | 問い | 結論 |
|---|---|---|
| Q1 | 既存テンプレートの規約 | 冒頭コメント構成・CSS変数・ダークモード・プレースホルダ検査を踏襲する（詳細は下記） |
| Q2 | エージェント定義の規約 | frontmatter 8キー＋「立場→入力→手順→出力→してはいけないこと」の本文構成を踏襲する |
| Q3 | スキル名 | **`html-slides`** を採用 |
| Q4 | 出力先の既定 | **`wip/reports/`** を採用（`<ベース名>.slides.html`。タスク単位の寿命を受け入れる） |
| Q5 | スキーマの置き場所・内容 | **`references/slide-outline.schema.json`**（JSON Schema形式）。保持すべき情報は下記 |
| Q6 | 配布・同期への影響 | **設定変更は一切不要**（.claude 全体が layer=core 等。根拠は下記） |
| Q7 | ドキュメント追記先 | `directory-structure.md` のツリーのみ追記が必要。`markdown-frontmatter.md` は変更不要 |
| Q8 | ページ送り・印刷の実装と検証 | 単一 `<script>`＋`@media print`。**この環境のヘッドレスChromium（Playwright）で実機検証可能** |

## 実施条件（測った対象・環境）

- 実行環境: Claude Code on the web のリモート実行環境（Linux）。node v22.22.2・
  Playwright CLI 1.56.1・Chromium（`/opt/pw-browsers/chromium`）・Python 3.11.15 を実測確認。
- 対象: リポジトリの現HEAD（PR #194 のブランチ）。実施日: 2026-08-23。
- 1環境の観測であり、git bash（Windows）実機での挙動は本調査の対象外。

## Q1. 既存テンプレート3本の規約

3本（`plans.template.html` / `reports.template.html` / `canvas-report.html`）の共通構成と、
`slides.template.html` が踏襲すべき要素。

| 要素 | 内容 | slides.template.html での扱い |
|---|---|---|
| 冒頭HTMLコメント | 使い方（コピー→埋める→任意節削除→検査→冒頭コメント差し替え）・必須/任意の別・検査コマンド | **踏襲**（スライド型8種の一覧・型の選び方・検査方法を持たせる。見出し構成の正はテンプレート側＝issue本文の要求どおり） |
| プレースホルダ検査 | `grep -c '<!-- ここに書く' <出力>` が0（`<!--` まで含めて数える） | **踏襲**（同じ文言・同じ検査） |
| CSS変数 | `:root` に `--bg --panel --ink --muted --line --accent --accent-soft --ok --warn --stop --code-bg --radius` | **踏襲**（命名を揃える。スライド固有の変数は追加してよい） |
| ダークモード | `@media (prefers-color-scheme: dark)` で `:root` を再定義 | **踏襲**。ただし投影用の既定はライト基調とし、印刷は常にライト |
| 自己完結 | CDN・外部フォント・画像を参照しない（canvasのみ任意のmermaid CDN） | **踏襲**（外部依存ゼロ。受け入れ条件1） |
| 正文の所在 | 計画・レポートは「mdが正文、HTMLは視覚化」 | **相違点**: スライドは対応mdを持たない。機械可読の対は構成案JSON（Q5） |
| リンク破断・重複ID検査 | `reports.template.html` 冒頭コメントの `comm -23` / `uniq -d` | **踏襲**（目次スライド等でアンカーを使う場合のみ） |
| script | plans/reports は `<script>` 0件。canvas のみJSエンジン内蔵 | **相違点**: スライドはページ送りに `<script>` が必須（Q8）。canvas が「単一ファイル内に自己完結JSを持つ」前例 |
| `@media print` | 3本とも0件（実測: `grep -c '@media print'` → いずれも0） | **新規要素**（前例なし。Q8で方式を確定） |

## Q2. サブエージェント定義の規約

既存2本（`adversarial-reviewer.md` / `issue-mr-resume.md`）の実測。

- **frontmatter**: `name` / `description` / `tools` / `model` / `title` / `type: agent` / `tags` / `keywords` の8キー。
  `description` はClaude Codeがサブエージェント選択に実際に使うキーで、**OKF用の要約を重複追加せず
  このキーを流用する**（`markdown-frontmatter.md`「対象外・特殊対応ファイル」表）。
- **tools による境界の強制**: 両者とも `tools: Read, Grep, Glob, Bash` で Write/Edit を持たせないことで
  「読み取り専用」を機構的に強制している。本文にも「Write/Editツールを持っていません」と明記。
- **model**: 役割の重さで選ぶ（reviewer=opus、resume=sonnet）。
- **本文構成**: 二人称で役割を宣言 → 立場（何をしない存在か）→ 入力（呼び出し元から渡されるもの・
  自分から探しに行かないもの）→ 手順 → 出力（スキーマをコードブロックとキー表で定義）→
  してはいけないこと。
- **新規2本への適用**:
  - ①構成設計（`slide-outline-designer`）: `tools: Read, Grep, Glob, Bash`（読み取り専用。HTML生成をしない
    境界をツールでも強制）。出力は構成案JSON（スキーマは Q5 のファイルが正。エージェント定義には再掲しない）。
  - ②HTML生成（`slide-html-generator`）: `tools: Read, Grep, Glob, Bash, Write`（ファイル1本を書き出すため
    Writeが必要。Editを持たせず「新規書き出しのみ」に寄せる）。構成の再設計をしない境界と差し戻し条件を本文へ明記。

## Q3. スキル名

既存スキル名は kebab-case の機能名詞（`canvas-report` `doc-search` `issue-create` `commit` 等）。

| 候補 | 利点 | 採否 |
|---|---|---|
| **`html-slides`** | issueタイトル「HTMLスライド」を直接表す。成果物が名前から即分かる | **採用** |
| `slide-report` | `canvas-report` と命名が揃う | 却下: スライドの用途はreports配下の報告に限らない（issue本文は「調査結果・設計内容・issue対応の報告」と幅を持たせている）のに、reportに限定して見える |
| `slides` | 短い | 却下: HTML形式であることが伝わらず、将来の .pptx 書き出しスキルと紛れる |

## Q4. 出力先ディレクトリの既定

| 候補 | 寿命・影響 | 採否 |
|---|---|---|
| **`wip/reports/`** | タスク単位（`cleanup-task.sh` が flow-id 5-5 で削除。削除除外は `TEMPLATE.md`・`REVIEW-POINTS.md`・`REVIEW-POINTS.local.md` のみ＝**スライドは必ず消える**）。`.mrworkflow.json` の `reportsDir` がそのまま使える。`.gitignore`・`dist-layers.json`・`directory-structure.md` の変更が**一切不要** | **採用** |
| 恒久ディレクトリ新設（例 `slides/`） | mainに残せるが、「squash merge後のmainはコード＋spec/ddrのみ」という運用と衝突。`dist-layers.json` の層判断・`directory-structure.md` ツリー・`cleanup-task.sh` の除外追加が必要 | 却下（既定としては採らない） |
| `.gitignore` 対象のローカルディレクトリ | リモートに乗らずレビュー・共有ができない。`check-dist-coverage.sh` の検査2のため `dist-layers.json` へ `local` エントリも必要 | 却下 |

- **既定の位置づけ**: スライドはMRのレビュー・発表の期間中に使う成果物であり、レポートHTMLビューと同じ
  寿命（flow-id 5-5 で削除、ブランチ履歴にのみ残る）を受け入れる。
- **命名**: `wip/reports/日付_<全体計画名>_<内容を簡潔に>.slides.html`。レポートのHTMLビュー
  （mdと同名の `.html`）と衝突しない接尾辞 `.slides.html` で区別する。構成案JSONは同ベース名の
  `.slides.json` として併存させ、.pptx 書き出し（別issue）の入力として取り出せる形にする。
- **恒久保存したい場合**: 呼び出し時にユーザーが出力先を明示指定する（SKILL.md に明記する。
  その場合の追跡・配布の扱いは指定者の判断。既定では新規ディレクトリを作らない）。

## Q5. 構成案JSONスキーマの置き場所・形式・内容

**置き場所の比較**（`directory-structure.md` の語彙: assets=出力に使うもの／scripts=実行するもの／
references=AIが読むもの）:

| 候補 | 判定 |
|---|---|
| **`references/slide-outline.schema.json`** | **採用**: スキーマは①②のエージェントとSKILL.mdが「読む」契約定義であり、出力物でも実行物でもない |
| `assets/` | 却下: assetsは「出力に使うもの（テンプレート等）」。スキーマ自体は成果物へコピーされない |
| `scripts/` | 却下: 実行可能物ではない |

- 上位計画は `assets/`/`references/` の2択で書いたが、語彙が3つあるため `scripts/` も比較した
  （差分の理由は個別調査計画Q5に記載済み）。
- **形式**: JSON Schema（draft-07 互換の記法。`$schema` 宣言を持つ）。リポジトリに完全なJSON Schema
  検証器は無いため、**構造検査は jq による必須キー確認**で行う（SKILL.md へ検査フィルタを載せる。
  `jq -e` で構文＋必須キーの存在を機械判定できる）。
- **スキーマが最低限保持すべき情報**（受け入れ条件6「.pptx 書き出しがそのまま入力にできる」のため）:
  - `meta`: タイトル・サブタイトル・日付・作成者・issue番号（表紙とpptxのドキュメントプロパティに対応）
  - `slides[]`: 各要素が `type`（8種のenum: `title` `section` `bullets` `two-column` `diagram` `table` `comparison` `summary`）と `title` を必須で持つ
  - 型ごとの固有フィールド（例: `bullets` は `items[]`（入れ子1段まで）、`two-column` は `left`/`right`、
    `table` は `headers[]`/`rows[][]`、`comparison` は `options[]`（名前・利点・欠点・採否）、
    `diagram` は `nodes[]`/`edges[]` のテキスト表現＋`caption`）
  - `speakerNotes`（任意。pptxのノートに対応）
  - **HTML固有の表現（色・レイアウト座標・CSSクラス）を含めない**（HTMLからの逆変換を避けるという
    issue本文の要求。pptx側はtype→スライドレイアウトの対応だけで変換できる粒度に保つ）
- **参照方法**: SKILL.md・エージェント①②の定義からパスで参照する（スキーマの中身を各mdへ再掲しない。
  正はスキーマファイル1箇所）。

## Q6. 配布・同期・インデックスへの影響 — 設定変更は不要

| 仕組み | 実測root根拠 | 影響 |
|---|---|---|
| `dist-layers.json` | `{"layer":"core","path":".claude"}` が丸ごと core（例外は settings.json と apply-mr-workflow-to-project のみ） | 新規スキル・エージェントは自動的に core で配布対象。**追記不要** |
| `check-dist-coverage.sh` | 検査対象は追跡ファイル全件と `.gitignore` の被覆 | `.claude/` 配下の新規は core で被覆済み。Q4で `wip/reports/` を採るため `.gitignore` 変更もなし。**変更不要** |
| `sync-gemini-assets.sh` | `.claude/agents/*.md` は frontmatter 変換（ホワイトリスト）、skills 等はコピー（実装 470・508行目のワイルドカード） | 新規もパターンで自動対象。flow-id 5-3 の実行だけでよい。**変更不要** |
| `extract-frontmatter.sh` / `index.jsonl` | 走査対象は `git ls-files` の `*.md` のみ | SKILL.md・エージェント2本のmdは自動で載る（受け入れ条件10）。`.schema.json`・`.template.html` は対象外（仕様どおり） |

## Q7. ドキュメント追記先

- **`directory-structure.md` のツリー**: `.claude/skills/` の節に `html-slides/assets/`（テンプレート）と
  `html-slides/references/`（スキーマ）の行を追記する（受け入れ条件9。既存の
  `issue-mr-flow/assets/`・`canvas-report/assets/` の行と同じ粒度）。フェーズ4で実施。
- **`markdown-frontmatter.md`**: 変更不要。
  - type表: `skill`（`.claude/skills/*/SKILL.md`）・`agent`（`.claude/agents/*.md`）が既存。新値は不要。
  - 「対象外・特殊対応ファイル」表: SKILL.md・agents は `description` を**新規追加せず流用**する規定が
    既にある → 新規作成では frontmatter に `description` を1つだけ書く（それがClaude Code用でもOKF用でもある）。
  - `slides.template.html`・`slide-outline.schema.json` は md でないため frontmatter 対象外（HTMLビューを
    対象外とする既存の節と同じ扱い。表への行追加も不要）。

## Q8. ページ送り・進行表示・印刷の実装方式と検証

**実装方式**（既存3本に前例が無いため新規に定める。外部依存ゼロは維持）:

- **ページ送り**: 単一ファイル内の `<script>`（DOM操作のみ。fetch・外部リソース不使用のため
  `file://` で開くだけで動く）。`keydown`（`ArrowLeft`/`ArrowRight`/`Space`/`Home`/`End`）と
  クリック（ナビボタン。誤操作を避けるため画面全域クリックでは送らない）で
  `.slide` の表示を切り替える。
- **進行表示**: 「n / N」のテキストと下辺のプログレスバー（現在位置/枚数から算出）。
- **印刷**: `@media print` でナビUIを隠し、全スライドを順に表示して各スライドへ
  `break-after: page`（旧記法 `page-break-after: always` を併記）を当てる。`@page { size: 297mm 167mm; margin: 0 }`
  相当で16:9の1スライド1ページに割り付ける（受け入れ条件3）。スクリーン表示は1枚ずつ・印刷は全枚、
  という切り替えを CSS だけで行う（JSに依存させない＝JS無効環境でも印刷は成立する）。

**検証の切り分け**（当初「ブラウザの無い環境」を前提としていたが、実測で覆った）:

| 検証項目 | 手段 | 実測root根拠 |
|---|---|---|
| 機械検証（静的） | プレースホルダgrep・外部参照grep 2種・`@media print` とキーハンドラの存在grep・8種の型のsection存在確認 | grepのみで可能 |
| **機械検証（動的）** | **この実行環境はヘッドレスChromiumで実機検証できる**: node v22.22.2・Playwright CLI 1.56.1・`/opt/pw-browsers/chromium` を実測確認。キーイベント送出→進行表示の変化、クリック→ページ遷移、`page.pdf()`→ページ数=スライド枚数の一致、を自動テストできる | `node --version` / `npx playwright --version` / `ls /opt/pw-browsers` |
| 人間の実機確認に残る項目 | 見た目の品質（文字の大きさ・投影時の視認性）・実プリンタでの印刷・Chromium以外のブラウザ | PRレビューで依頼する（フェーズ3のレビュー依頼メッセージに明記） |

- **受け入れ条件4**（SKILL.mdの手順どおりで1本完成する）の確認: フェーズ3のテストで、SKILL.md の
  手順に従いサンプル構成案JSONから実際に1本生成し、上記の機械検証（静的＋動的）を通す。

## 設計への反映

1. フェーズ3の個別作業計画（flow-id 3-1）へ: スキル名 `html-slides`・出力先既定 `wip/reports/`
   （`.slides.html`/`.slides.json` 命名）・スキーマの置き場所と保持情報（Q5）・実装方式（Q8）を
   前提として反映する。
2. フェーズ3のテストへ: Playwrightによる動的検証（キー操作・クリック・`page.pdf()` のページ数一致）と
   静的grep検査を検証手順に組み込む。
3. フェーズ4へ: `directory-structure.md` ツリーへの追記（Q7）と、出力先の意思決定のDDR記録
   （Q4の比較表が材料になる）。

## 確かめられなかったこと

- 実プリンタでの印刷結果・Chromium以外のブラウザ（Firefox/Safari）での表示・キー操作
  （この環境にはChromiumしか無い。PDF化の検証はChromiumの印刷エンジンと同一のため代表性は高いが、
  ブラウザ差は人間の実機確認に残る）。
- Gemini CLI経路での新規エージェント定義の実動作（`sync-gemini-assets.sh` の変換対象になることまでは
  実装から確認済み。変換結果の実行はflow-id 5-3後の確認事項）。

## 残課題（フェーズ3へ送るもの）

- スライド型8種それぞれの見本コンテンツの設計（テンプレートに埋め込むサンプル）。
- 構成案JSONスキーマの具体的なフィールド定義（Q5の「保持すべき情報」を JSON Schema に落とす）。
- エージェント②の差し戻し条件の具体化（例: 要点が1枚に収まらない・型に無いフィールドが来た場合）。
