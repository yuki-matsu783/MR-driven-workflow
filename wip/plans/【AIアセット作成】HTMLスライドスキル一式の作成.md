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
- **スライド型8種**（issue #168）: 表紙（`cover`）／章扉（`section`）／箇条書き（`bullets`）／
  2カラム（`two-column`）／図解（`diagram`）／表（`table`）／比較（`comparison`）／まとめ（`summary`）。
  各型は `<section class="slide" data-type="...">` の1要素で、使わない型はsectionごと削除する方式
  （既存テンプレートの「使わないセクションは削除」と同じ運用）。
  **型名は調査Q5のenum（1件目 `title`）から表紙のみ `cover` へ改める**。各スライド要素の必須
  フィールド名 `title`（見出し文字列）と `type: "title"` が同名になると、スキーマ・エージェント間の
  受け渡しで意味の衝突（型名なのか見出しなのか）を招くため。**この8種の文字列を、テンプレートの
  `data-type`・スキーマのenum・エージェント2本の受け渡し契約の3箇所で完全に同一に使う**
  （1箇所でも違えば `slide-html-generator` の差し戻し条件に該当する）。
- **ページ送り**: 方向キー（←→）・Space・Home/End・クリック（左右領域）で前後移動。JSは数十行の
  素朴な実装（現在番号の状態1つ＋`transform`または表示切替）。`nnn/NNN` の進行表示を常設する。
- **印刷**: `@media print` で1スライド=1ページ（`page-break-after: always` 相当＋操作UI非表示）。
  ヘッドレスChromiumの `page.pdf()` でスライド枚数とPDFページ数が一致することを実測済みの方式。
- **図解型はCSSのみで表現**（矢印・ボックスのフロー図程度。外部画像・Mermaid等は使わない。
  自己完結・外部参照ゼロの規約を守るため）。

### スキーマ（slide-outline.schema.json）

- JSON Schema draft-07相当。トップレベルは調査Q5の結論どおり
  `{meta: {title, subtitle, date, author, issue}, slides: [...]}` とし、各スライド要素は
  `{type, ...型ごとのフィールド, speakerNotes}`（`speakerNotes`・`issue` は .pptx 書き出しの
  ノート・ドキュメントプロパティに対応する項目。落とさない）。`type` はテンプレートの8種と
  同名のenum（表紙のみQ5の `title` から `cover` へ改める。理由は上記テンプレート節）。
- 将来の .pptx 書き出しの入力になることを想定し、**表示スタイルではなく内容**（見出し・箇条書き・
  表のセル・比較軸）だけを持たせる。
- jqでの構造検査が書ける形にする。調査Q5で4入力（正常・type不正・必須キー欠落・空ファイル）を
  実測したフィルタは `meta.title` の存在確認＋`type` のenum判定の形であり、この構造を保つ限り
  そのまま流用できる（enumの `title`→`cover` の1語だけ差し替える）。`[ -s ]` の空チェックを
  jqより先に置く（空入力は `jq -e` が検知できないことがある実機観測のため）。`.` の束縛の罠は
  `.claude/rules/shell-script-style.md` の規約に従い変数束縛で回避する。

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
  `name`/`description`/`tools`/`model` ＋ OKF側 `title`/`type: agent`/`tags`/`keywords`
  （`model` は既存2本と同じ値にする。Gemini側では変換時に除去される）。
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

実行できるコマンドと合格条件（パスはシェル変数へ束縛して使う）:

```bash
TPL=.claude/skills/html-slides/assets/slides.template.html
SCHEMA=.claude/skills/html-slides/references/slide-outline.schema.json
out="$SP/sample.slides.html"       # SP=scratchpad。サンプル生成物
outline="$SP/sample.slides.json"   # サンプル構成案
bad="$SP/bad.slides.json"          # typeを不正値にした異常サンプル

# 1. テンプレートの自己完結性（外部参照ゼロ。2種とも0件が合格）
grep -nE "(src|href)=['\"]?(https?:)?//" "$TPL" || echo EXT_REF_NONE
grep -nE "(url\(|@import[[:space:]]+)['\"]?(https?:)?//" "$TPL" || echo EXT_CSS_NONE

# 2. スライド型8種が「相異なる名前で」揃っている（1つ目は8が合格。冒頭コメントの型一覧を
#    数えないよう要素までマッチさせる）。2つ目は期待8種との突き合わせ（出力が空、が合格）
grep -oE '<section class="slide" data-type="[^"]+"' "$TPL" | sed 's/.*data-type="//; s/"$//' | sort -u | wc -l
comm -3 <(grep -oE '<section class="slide" data-type="[^"]+"' "$TPL" | sed 's/.*data-type="//; s/"$//' | sort -u) \
        <(printf '%s\n' bullets comparison cover diagram section summary table two-column | sort)

# 2b. ページ送り・印刷の静的検査（いずれも1以上が合格。必須）
grep -c '@media print' "$TPL"
grep -cE "addEventListener\('keydown'|ArrowRight" "$TPL"

# 3. スキーマが空でなく妥当なJSONである（両方成功＝終了コード0が合格。
#    [ -s ] の空チェックを jq -e より先に置く——空入力を jq -e が検知できない実機観測のため）
[ -s "$SCHEMA" ] && jq -e . "$SCHEMA" >/dev/null

# 4. サンプル構成案JSONがスキーマの構造検査を通る。フィルタの骨子は調査Q5の実測形
#    （[ -s ] の空チェック → meta.title の存在 → type のenum判定。enumは title→cover の
#    1語だけ差し替えて流用し、正式版はSKILL.mdへ記載してここと同一にする）。
#    正常サンプルで終了コード0、異常サンプルで非0、の両方を確かめて空振りを排除する
[ -s "$outline" ] && jq -e 'has("meta") and (.meta|has("title")) and
  (["cover","section","bullets","two-column","diagram","table","comparison","summary"] as $known
   | [.slides[].type] | all(. as $t | ($known | index($t)) != null))' "$outline" >/dev/null; echo "ok=$?"
[ -s "$bad" ] && jq -e 'has("meta") and (.meta|has("title")) and
  (["cover","section","bullets","two-column","diagram","table","comparison","summary"] as $known
   | [.slides[].type] | all(. as $t | ($known | index($t)) != null))' "$bad" >/dev/null; echo "bad=$?"

# 5. サンプル生成物のプレースホルダ残存ゼロ（0が合格）・重複IDゼロ（出力なしが合格）
grep -c '<!-- ここに書く' "$out"
grep -oE 'id="[^"]+"' "$out" | sort | uniq -d

# 6. frontmatterがインデックスへ載る（skills側1件・agents側2件が合格。
#    || true や 2>/dev/null は付けない——ファイルが無ければ失敗として観測する）
bash .claude/scripts/src/extract-frontmatter.sh . >/dev/null
grep -c '"concept_id":".claude/skills/html-slides/SKILL"' .claude/skills/html-slides/index.jsonl
grep -cE 'slide-outline-designer|slide-html-generator' .claude/agents/index.jsonl

# 7. sync-gemini-assets.sh の変換が新規agents 2本で失敗しない
#    （--dry-run は常に終了コード0のため、終了コードだけでは判定しない。終了コード0かつ
#    出力に新規agents 2本が現れる＝2が合格。.gemini/ との同期状態そのもの（--check）は
#    flow-id 5-3 の後に単体で見る——このフローでは5-3まで .gemini/ は未同期のため正常でも落ちる）
bash .claude/scripts/src/sync-gemini-assets.sh --dry-run | grep -cE 'slide-outline-designer|slide-html-generator'

# 8. 動的検証（この実行環境のみ・任意。Chromium 1種の観測であることを制約として結果に添える）
#    playwrightはグローバル配置のみのため絶対パスでrequireする（調査Q8の制約）
node -e '
  const {chromium}=require("/opt/node22/lib/node_modules/playwright");
  (async()=>{const b=await chromium.launch();const p=await b.newPage();
    await p.goto("file://"+process.argv[1]);
    await p.keyboard.press("ArrowRight");
    console.log(await p.evaluate(()=>document.querySelector(".progress").textContent));
    await p.pdf({path:process.argv[1]+".pdf"});await b.close();})()' "$out"
# 合格: キー送出で進行表示が進む・PDFのページ数がスライド枚数と一致する。
# 実行できない環境ではスキップし、件数（未実施1件）と代替（検証2bの静的検査）を報告へ明記する
```

合格条件: **1〜7（2b含む）がすべて必須で合格**。8はこの環境で実施し、結果をレポートへ記録する。

### レビュー依頼で人間に確認してもらう項目（調査Q8の結論）

機械検査では代替できない次の3項目を、flow-id 3-7 のレビュー依頼メッセージへ明記する。

1. 見た目の品質（文字の大きさ・投影時の視認性）
2. 実プリンタでの印刷（1スライド1ページに収まるか）
3. Chromium以外のブラウザでの表示・ページ送り

## issueの受け入れ条件との対応

上位計画（`wip/plans/html-slides-skill-plan.md`「検証」節）の10項目と1対1・同じ文言・同じ並び。

| 受け入れ条件（issue #168） | この計画での対応箇所 |
|---|---|
| テンプレートが外部依存ゼロで8種の見本が表示される | 検証1（外部参照ゼロ）・検証2（8種の一意性と名前の突き合わせ） |
| キーボード・クリックのページ送りと進行表示 | 「方針」テンプレート節・検証2b（keydownハンドラ）・検証8 |
| 印刷プレビューで1スライド1ページ | 「方針」テンプレート節・検証2b（`@media print`）・検証8（PDFページ数） |
| SKILL.md の手順どおりでスライドHTMLが1本完成する | 「検証用サンプル」節（一連の生成を実走）・検証5 |
| サブエージェント①の入出力形式と「HTML生成は行わない」境界の明記 | 「方針」サブエージェント節（slide-outline-designer） |
| 構成案JSONスキーマが定義され .pptx 書き出しの入力にできる | 「方針」スキーマ節（`meta`・`speakerNotes`・`issue` を保持）・検証3〜4 |
| サブエージェント②の入力と「構成を作り直さない」境界・差し戻し条件の明記 | 「方針」サブエージェント節（slide-html-generator） |
| プレースホルダ残存チェックの方法が SKILL.md に書かれている | 「方針」SKILL.md節 手順(5)・検証5 |
| directory-structure.md のツリーへ追記 | フェーズ4へ送る（スコープ外節） |
| 新規mdのfrontmatterが規約に沿い index.jsonl に載る | 検証6 |
