---
title: 【AIアセット作成】HTMLスライドスキル一式の作成
type: plan
description: issue #168 フェーズ3。スライドテンプレート・SKILL.md・サブエージェント2本・構成案JSONスキーマを新規作成する個別作業計画
tags: [plan, slides, skill, agents]
keywords: [HTMLスライド, テンプレート, html-slides, サブエージェント, 構成設計, HTML生成, スキーマ, ページ送り, 印刷, プレースホルダ]
---

# 【AIアセット作成】HTMLスライドスキル一式の作成

## 前提（合意状況）

- 上位の計画: `wip/plans/html-slides-skill-plan.md`（flow-id 1-4 で作成。本セッションは非対話のため
  flow-id 1-5 の人間合意は未実施。ユーザーの当初指示を包括的な承認として進めることをHANDOFF.mdへ記録済み）
- 依拠する調査結果: `wip/reports/2026-08-23_html-slides-skill-plan_前提調査.md`（flow-id 2-6〜2-9相当。
  敵対的レビュー2回・計21件の指摘を反映済み。人間合意は未実施のため進捗記号は `[]` のまま）
- 調査で確定した前提: スキル名 `html-slides`／出力先既定 `wip/reports/*.slides.html`＋同名`.slides.json`／
  スキーマは `references/slide-outline.schema.json`／dist-layers.json・.gitignore・sync-gemini-assets.sh・
  extract-frontmatter.sh の設定変更は不要／エージェント定義はホワイトリスト対象キー1行値・
  `tools` は `GEMINI_TOOL_PAIRS` 内の名前（`Write` は対応表に有り）という変換制約に従う

## この計画で何をするか

issue #168 の主たる成果物であるAIアセット4点＋検証用サンプルを新規作成する。

1. スライドテンプレート `.claude/skills/html-slides/assets/slides.template.html`
2. スキル定義 `.claude/skills/html-slides/SKILL.md`
3. 構成案JSONスキーマ `.claude/skills/html-slides/references/slide-outline.schema.json`
4. サブエージェント2本 `.claude/agents/slide-outline-designer.md`（構成設計）・
   `.claude/agents/slide-html-generator.md`（HTML生成）

## 変更対象

| ファイル | 操作 | 何をするか |
|---|---|---|
| `.claude/skills/html-slides/assets/slides.template.html` | 新規 | 自己完結スライドテンプレート。スライド型8種・ページ送り・進行表示・印刷対応 |
| `.claude/skills/html-slides/SKILL.md` | 新規 | コピー→型選択→穴埋め→残存チェックの手順定義。サブエージェント2本の使い分けも記載 |
| `.claude/skills/html-slides/references/slide-outline.schema.json` | 新規 | 構成案JSONのスキーマ（JSON Schema draft-07相当） |
| `.claude/agents/slide-outline-designer.md` | 新規 | 構成設計エージェント（読み取り専用。構成案JSONを返す） |
| `.claude/agents/slide-html-generator.md` | 新規 | HTML生成エージェント（構成案に忠実に穴埋め。食い違いは差し戻す） |

ドキュメント本体（directory-structure.md・docs-workflow.md・index.md・usecase・
wip/reports/REVIEW-POINTS.md）への追記はフェーズ4（【AIアセット反映】等）で行い、本計画には含めない。

## 方針

### テンプレート（slides.template.html）

- **既存テンプレート2本（plans/reports）の共通規約を踏襲する**: 冒頭HTMLコメントに使い方・
  プレースホルダ検査コマンド・外部依存なしの宣言／`:root` CSS変数＋`prefers-color-scheme: dark`／
  日本語フォントスタック／`<!-- ここに書く: … -->` プレースホルダ形式（既存の検査 `grep -c '<!-- ここに書く'`
  がそのまま使える）。
- **スライド型8種**（issue #168）: 表紙（cover）／章扉（section）／箇条書き（bullets）／
  2カラム（two-column）／図解（diagram）／表（table）／比較（comparison）／まとめ（summary）。
  各型は `<section class="slide" data-type="...">` の1要素で、使わない型はsectionごと削除する方式
  （既存テンプレートの「使わないセクションは削除」と同じ運用）。
- **ページ送り**: 方向キー（←→）・Space・Home/End・クリック（左右領域）で前後移動。JSは数十行の
  素朴な実装（現在番号の状態1つ＋`transform`または表示切替）。`nnn/NNN` の進行表示を常設する。
- **印刷**: `@media print` で1スライド=1ページ（`page-break-after: always` 相当＋操作UI非表示）。
  ヘッドレスChromiumの `page.pdf()` でスライド枚数とPDFページ数が一致することを実測済みの方式。
- **図解型はCSSのみで表現**（矢印・ボックスのフロー図程度。外部画像・Mermaid等は使わない。
  自己完結・外部参照ゼロの規約を守るため）。

### スキーマ（slide-outline.schema.json）

- JSON Schema draft-07相当。トップレベルは `{title, date, author, slides[]}`、各要素は
  `{type, ...型ごとのフィールド}`。`type` はテンプレートの8種と同名のenum。
- 将来の .pptx 書き出しの入力になることを想定し、**表示スタイルではなく内容**（見出し・箇条書き・
  表のセル・比較軸）だけを持たせる。
- jqでの構造検査（`[ -s ]`の空チェック→typeのenum判定→必須キー判定）が書ける形にする
  （調査で4入力の実測済み。`.` の束縛の罠は `.claude/rules/shell-script-style.md` の規約に従い
  変数束縛で回避する）。

### SKILL.md

- frontmatterは既存スキルの型（`name`/`description` ＋ OKF側 `title`/`type: skill`/`tags`/`keywords`。
  `description` はClaude Codeの実キーを流用し重複させない）。
- 手順: (1) テンプレートを出力先へコピー → (2) 構成案JSONを作る（`slide-outline-designer` へ委譲可）→
  (3) スキーマ検査 → (4) 穴埋め（`slide-html-generator` へ委譲可）→ (5) プレースホルダ残存・
  外部参照・重複IDの機械検査 → (6) 任意の動的検証（この実行環境のみ。node/Playwright不在なら
  件数を出してスキップ）。
- 見出し構成の正はテンプレート側に置き、SKILL.md では再掲しない（issue #168 の受け入れ条件）。

### サブエージェント2本

- frontmatterは既存2本（adversarial-reviewer / issue-mr-resume）の型に合わせる:
  `name`/`description`/`tools`/`model: inherit` ＋ OKF側 `title`/`type: agent`/`tags`/`keywords`。
  **ホワイトリスト対象キーの値は必ず1行**（sync-gemini-assets.sh の変換制約）。
- `slide-outline-designer`: `tools: Read, Grep, Glob, Bash`（読み取り専用）。入力（発表テーマ・
  元資料パス・目安枚数）から構成案JSONだけを返す。HTMLは生成しない。スキーマへの適合を自分で
  確認してから返す。
- `slide-html-generator`: `tools: Read, Grep, Glob, Bash, Write`（Editは持たせない。テンプレートの
  コピーから作るためWriteで足りる）。渡された構成案JSONに**忠実に**穴埋めし、構成の再設計はしない。
  構成案とテンプレートの型が食い違う場合は生成せず呼び出し元へ差し戻す。生成後に機械検査
  （プレースホルダ0・外部参照0・重複ID0）を自分で実行する。

### 検証用サンプル

- scratchpadに構成案JSONのサンプルを作り、スキーマ検査→テンプレート穴埋め→機械検査→動的検証
  （ページ送り・PDFページ数）まで一連で通す。**サンプルはリポジトリへコミットしない**
  （wip/reports/ へ置くと本物の成果物と紛れるため。検証結果はworklogと作業結果レポートへ記録する）。

## やらないこと（スコープ外）

- **.pptx 書き出しの実装**（issue #168 が明示的に対象外。スキーマを入力に使える形にするまで）
- **既存テンプレート3本の変更**（守るべき条件。スライドはコピーで独立させる）
- **ドキュメント追記**（directory-structure.md・docs-workflow.md・index.md・usecase・
  wip/reports/REVIEW-POINTS.md への追記はフェーズ4へ送る。調査レポートQ7の5点）
- **`.claude/scripts/test/` への動的検証テスト追加**（調査で「この環境のみの任意検証」と位置づけ済み。
  配布先で必ず失敗するテストを layer=core で配らない）
- **DDR作成**（出力先ディレクトリ等の意思決定の記録はフェーズ4の【設計反映】で行う）

## 検証

実行できるコマンドと合格条件:

```bash
# 1. テンプレートの自己完結性（外部参照ゼロ。2種とも0件が合格）
grep -nE "(src|href)=['\"]?(https?:)?//" .claude/skills/html-slides/assets/slides.template.html || echo EXT_REF_NONE
grep -nE "(url\(|@import[[:space:]]+)['\"]?(https?:)?//" .claude/skills/html-slides/assets/slides.template.html || echo EXT_CSS_NONE

# 2. テンプレートにスライド型8種が揃っている（8が合格）
grep -c 'data-type="' .claude/skills/html-slides/assets/slides.template.html

# 3. スキーマが妥当なJSONである（終了コード0が合格）
jq -e . .claude/skills/html-slides/references/slide-outline.schema.json >/dev/null

# 4. サンプル構成案JSONがスキーマの構造検査を通る（jqフィルタ。OKが合格）
#    （検査フィルタはSKILL.mdに記載のものを使う）

# 5. サンプル生成物のプレースホルダ残存ゼロ（0が合格）・重複IDゼロ
grep -c '<!-- ここに書く' <サンプル出力.slides.html>
grep -oE 'id="[^"]+"' <サンプル出力.slides.html> | sort | uniq -d

# 6. frontmatterがインデックスへ載る（SKILL.md・agents 2本の3件が合格）
bash .claude/scripts/src/extract-frontmatter.sh . >/dev/null
grep -c 'html-slides\|slide-outline-designer\|slide-html-generator' .claude/index.jsonl .claude/agents/index.jsonl .claude/skills/index.jsonl 2>/dev/null || true

# 7. sync-gemini-assets.sh の変換が新規agents 2本で失敗しない（終了コード0が合格）
bash .claude/scripts/src/sync-gemini-assets.sh --check || bash .claude/scripts/src/sync-gemini-assets.sh --dry-run

# 8. 動的検証（この実行環境のみ・任意）: ヘッドレスChromiumでサンプルを駆動し、
#    キー送出で進行表示が進むこと・page.pdf() のページ数がスライド枚数と一致することを確認
```

合格条件: 1〜7がすべて合格（8はこの環境で実施し、結果をレポートへ記録する）。

## issueの受け入れ条件との対応

| 受け入れ条件（issue #168） | この計画での対応箇所 |
|---|---|
| テンプレートが自己完結HTML | 検証1（外部参照ゼロ） |
| スライド型8種 | 検証2・「方針」テンプレート節 |
| キーボード/クリックのページ送り・進行表示 | 「方針」テンプレート節・検証8 |
| `@media print` で1スライド1ページ | 「方針」テンプレート節・検証8（PDFページ数） |
| SKILL.md の手順定義（見出し構成はテンプレートが正） | 「方針」SKILL.md節 |
| 構成設計エージェント（読み取り専用・構成案JSONのみ） | 「方針」サブエージェント節 |
| HTML生成エージェント（忠実・差し戻し） | 「方針」サブエージェント節 |
| 構成案JSONスキーマ（.pptx入力を想定） | 「方針」スキーマ節・検証3〜4 |
| frontmatter/index.jsonl 準拠 | 検証6 |
| directory-structure.md ツリー追記 | フェーズ4へ送る（スコープ外節） |
