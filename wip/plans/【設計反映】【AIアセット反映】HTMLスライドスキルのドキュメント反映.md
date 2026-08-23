---
title: 【設計反映】【AIアセット反映】HTMLスライドスキルのドキュメント反映
type: plan
description: issue #168 フェーズ4の個別反映計画。spec新設・DDR2件・VERSION増分と既存ドキュメント9点への追記、および洗い出しで確定したAIアセット反映1件を行う
tags: [plan, slides, docs, ddr]
keywords: [反映計画, 設計反映, AIアセット反映, spec, DDR, VERSION, directory-structure, docs-workflow, index, REVIEW-POINTS, usecase]
---

# 【設計反映】【AIアセット反映】HTMLスライドスキルのドキュメント反映

- issue: #168 ／ フェーズ4（flow-id 4-6 の個別反映計画。作成は 4-1）
- 上位計画: `wip/plans/html-slides-skill-plan.md`「フェーズ4〈反映〉」
- 入力: `wip/reports/2026-08-23_html-slides-skill-plan_前提調査.md`（Q4・Q7）・
  `wip/reports/2026-08-23_html-slides-skill-plan_AIアセット作成結果.md`（「設計への反映」ほか）・
  worklog 3本・PR #194 のレビュー往復（計38スレッド）
- 種別を併記する理由: 分ける場合の基準（評価軸の混在。`references/planning.md`）に照らして
  判断した。本計画の【AIアセット反映】は洗い出しの結果1件（下記）で、その追記内容は
  【設計反映】側で確定する契約・経緯（調査結論の転記の忠実さ）に従属しており、単独でレビュー
  しても評価軸が変わらない。分けると個別計画・レポート・レビュー往復が1件のために倍になる
  ため併記した（レビューで一部差し戻しになった場合は、その時点でファイルを分割する）。

## この計画で何をするか

フェーズ2・3で確定した意思決定と成果物を、永続ドキュメント（spec・DDR・rules・index・
REVIEW-POINTS・VERSION）へ反映する。反映しないと、(1) 出力先・型名の決定理由がwip削除
（flow-id 5-5）とともに失われ、(2) 「wip/reports/にはmdとhtmlの2種類」等の既存記述
（後述のとおり5ファイルにある）が事実と食い違ったままmainへマージされ、(3) 配布対象アセットを
追加したのに `.claude/VERSION` が無言で据え置かれる。

## 変更対象

### 設計反映（spec・DDR・配布版数と、主成果物に付随する既存ドキュメントの整合）

新スキルの追加に伴う既存ドキュメントの説明更新（5〜12）は、作業の副産物ではなく**主たる成果物に
付随する整合作業**のため、【AIアセット反映】（副産物限定。`references/planning.md`）ではなく
こちらに含める。

| # | ファイル | 内容 |
|---|---|---|
| 1 | `.claude/docs/spec/html-slides.md`（新設） | html-slidesスキルの正史仕様。背景・目的／仕様（成果物と置き場所・型8種とスキーマ契約・検査群・サブエージェント境界・動的検証の位置づけ）／影響範囲／設定項目（無し）／未決定事項（.pptx書き出し・サブエージェント実運転）。「検査対象の文字列をテンプレートのコメント・説明文へ書くと検査が誤検知する」（検証2の9件事例）も仕様の注意として記録する |
| 2 | `.claude/docs/ddr/i0168-01-スライドの出力先はwip-reports既定とし恒久ディレクトリを新設しない.md`（新設） | 出力先の意思決定。却下案: 恒久ディレクトリ新設・.gitignore対象ローカル（調査Q4の比較表が根拠。DDR単独で読める分量まで書き写す） |
| 3 | `.claude/docs/ddr/i0168-02-表紙スライドの型名はtitleでなくcoverにする.md`（新設） | 型名の意思決定。却下案: 調査Q5素案の `title`（フィールド名 `title` との衝突・3箇所同一使用の契約が根拠） |
| 4 | `.claude/docs/README.md` | DDR一覧は `bash .claude/scripts/src/generate-ddr-list.sh` で再生成（手書きしない）。**「## spec（機能仕様）」は手書きの一覧**なので `- [html-slides.md](spec/html-slides.md)` の行を追記する（実測: spec実体19件に対し掲載18件で、既に `command-position.md` の1件が漏れている。この既存の漏れの修正は本タスクと無関係な変更のため**対象外**とし、反映結果レポートに事実だけを記録する） |
| 5 | `.claude/VERSION` | **MINOR増分を適用する（0.4.0 → 0.5.0）**。`.claude/skills/html-slides/`・`.claude/agents/slide-*.md` は `dist-layers.json` の layer=core に含まれる配布対象アセットの追加であり、`distribution-assets.md` の目安表で MINOR に当たる。非対話セッションでAIが増分を適用するため、適用した事実と根拠を `.claude/docs/spec/html-slides.md` のchangelogと `HANDOFF.md`「判断を迷った内容」の両方へ残す（同specの定めどおり） |
| 6 | `.claude/rules/directory-structure.md` | ツリーへ `skills/html-slides/`（`assets/`・`references/` の内訳）と agents 2本の追記。「`wip/reports/` には**mdとhtmlの2種類**を置く」の段落へ `.slides.html`・`.slides.json`（スキル成果物。対応mdを持たない）を追記 |
| 7 | `.claude/rules/docs-workflow.md` | ライフサイクル表の `wip/reports/` 関連行の近くへ、`wip/reports/*.slides.html`＋`.slides.json`（html-slidesスキルの成果物。寿命は他のreports成果物と同じ、flow-id 5-5で削除）を追記 |
| 8 | `.claude/skills/issue-mr-flow/references/deliverables.md` | 「`wip/plans/` `wip/reports/` のいずれにも、mdとHTMLを併存させる」の節へ、`*.slides.html`/`*.slides.json` は例外（対応mdを持たない対のスキル成果物）である旨を追記。docs-workflow.md・directory-structure.md が「詳細はこれが正」と指す参照先のため、ここを直さないと正の側が古いまま残る |
| 9 | `index.md`（Repository Map） | スキル列挙へ `/html-slides` を追加。`.claude/agents/` の説明（現状「issue-mr-flow途中引き継ぎ用」）をスライド用2本を含む記述へ更新。`wip/reports/` の説明（「`.md` が正文で、同名の `.html` はその視覚化」）へ `.slides.*` の例外を追記 |
| 10 | `.claude/docs/spec/issue-mr-workflow.md` | 「計画・レポートのHTMLビュー」節（**現在の状態を述べる節**）へ `.slides.*` の例外を追記する。**changelog（過去issueごとの記録）は書き換えない**。この1点に限り「既存specの本文変更をしない」の例外とする（現在状態の節の追記は docs-workflow.md が認める運用） |
| 11 | `.claude/rules/markdown-frontmatter.md` | 「HTMLビューは対象外」節のテンプレート本体の列挙へ `.claude/skills/html-slides/assets/slides.template.html` を追記（調査Q7は「変更不要」と結論したが、この節はパスを明示列挙する形式のため、新設テンプレートが列挙から漏れる。この差分理由を反映結果レポートへ記録する） |
| 12 | `wip/reports/REVIEW-POINTS.md` | 適用範囲の注記を追加: `*.slides.html`・`*.slides.json` はスライド成果物であり、reports.template.html 前提の観点（結論カード・md同期等）は適用しない。スライドへ適用する検査は `.claude/skills/html-slides/SKILL.md` 手順5・6が正 |
| 13 | `.claude/docs/usecase/*.md`（8本） | 影響確認のみ（flow-id 4-6 の定め）。html-slidesに触れるべき既存記述・リンク切れが無いかを確認し、影響があれば更新、無ければ「影響なし」を反映結果レポートへ件数付きで記録 |

- 新規spec作成は本来「人間承認が必須」（docs-workflow.md）。非対話セッションのため、ユーザーの
  当初指示を包括承認として作成し、レビュー依頼（敵対的レビュー＋PR description）で明示する。
- DDRの識別子は issue #168 → `i0168-01`・`i0168-02`（4桁ゼロ埋め・枝番01から）。

### AIアセット反映（副産物の洗い出し。planning.md 手順1〜3を実施済み）

**手順1（起点の列挙）**: worklog 3本の「ダメだったこと」・reports 2本の「想定と異なった点／
確かめられなかったこと／残課題／重点レビュー依頼」・PR #194 のレビュー往復（フェーズ2: 15スレッド、
フェーズ3: 17スレッド、フェーズ4: 6スレッド）を走査し、**候補4件**を列挙した。

**手順2（4類型への分類）と手順3（痕跡の確認）**:

| 候補 | 分類 | 判断根拠 |
|---|---|---|
| (1) 調査結論を計画へ転記する際に独自に変えてしまった（cover/title不一致・metaの平坦化。フェーズ3計画初版とレポートの「Q5準拠」過小表現で**同一MR内2回**） | **(c) 追記** | 痕跡確認: `doc-search --text '転記'` → matched=0、`grep -rn '転記\|そのまま引用' .claude/rules .claude/skills/issue-mr-flow/references` → 該当0件（2段判定）。既存アセットにこの罠の記述は無い |
| (2) 「異常が無ければ何も出ない検査」の空振り（重複ID検査） | 反映対象ではない | 既存記述あり（`shell-script-style.md`「テスト」節・ルート `REVIEW-POINTS.md`）。敵対的レビューがその観点で検出しており、**アセットは機能した**（(b)〜(d)のどれでもない） |
| (3) 検証2がテンプレート冒頭コメントの記法例を数えて9件になった | 反映対象ではない（設計反映側で記録） | スキル固有の注意であり、汎用アセットではなく新設spec（変更対象1）の仕様の注意として記録する |
| (4) `adversarial-review-count.sh increment` へフェーズ番号でなく上限値を渡した実行ミス | 反映対象ではない | スクリプトヘッダ・`adversarial-review/SKILL.md` の用例はいずれも `increment <phase>` と正しく記載済み（アセットは正しく、参照を怠った1回きりの実行ミス。(a)の再現性なし） |

| # | ファイル | 内容 |
|---|---|---|
| 14 | `wip/plans/REVIEW-POINTS.md` | 候補(1)の(c)追記: 「依拠する調査・レポートの結論を計画へ引くとき、結論の文言をそのまま引用しているか。変える場合は変更点と理由が明示されているか」の観点を追加 |

## 方針

- **調査・作業の結論を転記するときは文言をそのまま引用し、変える場合は変更点と理由を明示する**
  （フェーズ3のレビューで学んだ再発防止策。これ自体を変更対象14で観点化する）。specの契約記述は
  作業結果レポートの対照表を正とする。
- DDRの本文は「検討したが✕✕を採用した」の型で、調査レポートの比較表（Q4・Q5）から根拠を引く。
  レポートはflow-id 5-5で消えるため、**DDR本文が単独で読める分量まで根拠を書き写す**。
- 過去の記録（specのchangelog・DDR本文）への機械的一括置換はしない（docs-workflow.mdの制限。
  変更対象10は現在状態の節への追記に限る）。
- frontmatterは `markdown-frontmatter.md` の規約どおり（spec: type spec / ddr: type ddr）。
- 各mdの追記位置は、直前の節の地の文の係り先が変わらない位置を選ぶ（docs-workflow.mdの注意）。

## やらないこと（スコープ外）

- .pptx 書き出しの設計・実装（別issue。specの未決定事項として記録するに留める）
- `.gemini/` への変換同期（flow-id 5-3 で実施）
- wip配下の削除・HANDOFFリセット（flow-id 5-5）
- 既存DDRの本文変更・既存specのchangelog変更（変更対象10の「現在の状態を述べる節への追記」だけを
  例外として行う）
- `.claude/docs/README.md` spec一覧の既存の漏れ（`command-position.md`）の修正（本タスクと
  無関係な変更のため。事実の記録のみ）

## 検証

```bash
# 1. DDR一覧の再生成後、作業ツリーの差分が意図したファイルに限られること
#    （pathspecで絞らず全体を見る。README以外に想定外の差分が無いことを件数と一覧で確認する）
bash .claude/scripts/src/generate-ddr-list.sh
git status --porcelain

# 2. DDR参照の破断検査（このツールの守備範囲は「.claude/docs/ddr/i<番号>-<枝番>-….md という
#    絶対パス形式のDDR参照」に限られる。相対リンクは検査対象外なので3で別途確かめる）。
#    基準値: 反映前の現時点では本計画が書く未作成DDRパス2件が検出される（参照切れ数=2）。
#    反映後に0件へ落ちることをもって合格とする（空振りでないことの確認を兼ねる）
bash .claude/scripts/src/check-doc-references.sh

# 3. 新設・更新したmdが張る相対リンクの実在確認（各リンク先で [ -f ] が真）
#    対象: html-slides.md・i0168-01/02・README追記行のリンク先
for f in .claude/docs/spec/html-slides.md \
         .claude/docs/ddr/i0168-01-スライドの出力先はwip-reports既定とし恒久ディレクトリを新設しない.md \
         .claude/docs/ddr/i0168-02-表紙スライドの型名はtitleでなくcoverにする.md; do
  [ -f "$f" ] && echo "EXISTS: $f"
done

# 4. 新設3ファイルが frontmatter インデックスへ載ること（spec 1件・ddr 2件）
bash .claude/scripts/src/extract-frontmatter.sh .
grep -c '"concept_id":".claude/docs/spec/html-slides"' .claude/docs/spec/index.jsonl
grep -cE '"concept_id":".claude/docs/ddr/i0168-0[12]-' .claude/docs/ddr/index.jsonl   # 2

# 5. 追記が実際に入っていること（各1件以上）
grep -c 'html-slides' .claude/rules/directory-structure.md
grep -c 'slides' .claude/rules/docs-workflow.md
grep -c 'slides' .claude/skills/issue-mr-flow/references/deliverables.md
grep -c 'html-slides' index.md
grep -c 'slides' .claude/rules/markdown-frontmatter.md
grep -c 'slides' wip/reports/REVIEW-POINTS.md
grep -c 'slides' wip/plans/REVIEW-POINTS.md
grep -c '0.5.0' .claude/VERSION   # 1

# 6. HTMLビューの機械検査（対象: 本計画のhtml、および flow-id 4-6 で作る反映結果レポートのhtml）
tgt="<対象HTMLのパス>"
grep -c '<!-- ここに書く' "$tgt"                                     # 0 が合格
grep -nE "(src|href)=['\"]?(https?:)?//" "$tgt" || echo EXT_REF_NONE  # 0件 が合格
grep -nE "(url\(|@import[[:space:]]+)['\"]?(https?:)?//" "$tgt" || echo EXT_CSS_NONE  # 0件 が合格
```

合格条件: 1は差分一覧に想定外のファイルが無いこと・2は反映後0件（反映前の基準値2件から減る）・
3は3件全てEXISTS・4はspec1件/ddr2件・5は全行1以上・6は md/html 作成のたびに実施し全て合格。
usecase影響確認（変更対象13）は結果（影響なし／更新内容）を反映結果レポートへ件数付きで記録する。

## レビュー依頼で人間に確認してもらう項目

1. 新規spec `.claude/docs/spec/html-slides.md` の新設可否（本来は人間承認必須。包括承認で進めた）
2. DDR 2件の採用理由・却下案の妥当性、および `.claude/VERSION` のMINOR増分（0.4.0→0.5.0）の判断
3. `wip/reports/REVIEW-POINTS.md` の適用範囲の線引き（スライドへ既存観点を適用しない判断）と、
   変更対象10（既存spec現在状態節への追記を例外とした線引き）
