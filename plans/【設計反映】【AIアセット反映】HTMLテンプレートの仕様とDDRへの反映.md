---
title: 【設計反映】【AIアセット反映】HTMLテンプレートの仕様とDDRへの反映
type: plan
description: issue #54の個別反映計画。specへ仕様節を新設し暫定記述を解除、DDR i0054-01を新規作成、既存DDR2件へnoteを添える。
tags: [issue-mr-flow, plan, spec, ddr]
keywords: [i0054-01, note, generate-ddr-list, issue-mr-workflow, VERSION, git-workflow, 暫定記述, 設計反映, AIアセット反映]
---

# 【設計反映】【AIアセット反映】HTMLテンプレートの仕様とDDRへの反映（issue #54 / フェーズ4）

全体作業計画: `plans/tidy-scoping-lantern.md`

## 前提（合意状況）

- 依拠する作業結果: `reports/20260822_tidy-scoping-lantern_HTMLテンプレート新設の作業結果.md`
  （flow-id 3-6）の「設計への反映」4項目。
- **flow-id 1-5・3-3・3-8 の人間合意は得ていない。** 本セッションは非対話的に進めており、
  結果確認工程は `adversarial-review` スキルで代替している。
- **ただし、DDR `i0054-01` が記録する決定1（自己完結CSS）は人間の承認を得ている**
  （2026-08-22、チャットで受領。「自己完結CSSで良い」）。**DDR本文はマージ後に変更できない**ため、
  未合意のまま恒久記録することは避ける必要があり、この承認が `i0054-01` を作る前提条件である。
  判断はMRのコメントとして記録済み（`.claude/skills/issue-mr-flow/SKILL.md`
  「チャットで受けたレビュー判断の記録」）。決定2（`assets` 語彙）は issue #54 本文が
  Agent Skills の語彙を根拠として示しているため、本文の範囲内である。
- 種別を `【設計反映】【AIアセット反映】` の**併記**にした理由は、**分量が小さいこと1点である**
  （spec 2ファイル＋DDR 3件＋rules 1箇所）。**2つの反映先の判断は独立している**
  （`【AIアセット反映】` の実体は `create-commit.sh` の挙動注意であり、HTMLテンプレートの方式変更とは
  無関係な話である）。観点表は原則として分けることを求めているので、**分けずに1回で合意を取ってよいかは
  人間が判断する**。分けるべきという判断であれば、`【AIアセット反映】` 側（変更対象 #8・#9）を
  別の個別計画へ切り出す。

## この計画で何をするか

フェーズ2〈調査〉・フェーズ3〈作業〉で得た知見のうち、**恒久的に残すべきもの**を
`.claude/docs/spec/` `.claude/docs/ddr/` `.claude/rules/` へ反映する。

**新規に決めることはしない。** すべて既に決まったこと（テンプレート2本の存在・方式の変更・
`assets` 語彙の統一・検査コマンドの誤り）の記録である。**方式の変更については、上記のとおり
人間の承認を得たうえで記録する**（未合意のままDDRへ書かない）。`.claude/VERSION` も
人間の判断（据え置き）を受けており、値は変更しない。

## 変更対象

| # | ファイル | 操作 | 何をするか |
|---|---|---|---|
| 1 | `.claude/docs/spec/issue-mr-workflow.md` | 変更 | `### 計画・レポートのHTMLビュー（issue #54）` を `## 仕様` 配下へ新設（`### 全体作業計画に必ず含めるフェーズ（issue #92）` の直後） |
| 2 | `.claude/docs/spec/issue-mr-workflow.md:677` | 変更 | 暫定記述「**issue #54 の成果物。未作成の間は手書きへフォールバックする**」を解除する |
| 3 | `.claude/docs/spec/issue-mr-workflow.md` | 変更 | `## 影響範囲` 配下へ `### issue #54（…）` のchangelogエントリを**新規追記**する |
| 4 | `.claude/docs/ddr/i0054-01-計画レポートのHTMLビューはassets配下のテンプレートへ切り出す.md` | 新規 | **このファイル名で**作る（`issue-mr-flow/SKILL.md` が既にこの名前で参照している） |
| 5 | `.claude/docs/ddr/i0000-11-調査結果のhtml版は自己完結htmlのコミットで作る.md` | 変更 | frontmatterへ `note` を1行足す（**本文は変更しない**） |
| 6 | `.claude/docs/ddr/i0141-01-canvasテンプレートはTailwind非依存の自己完結CSSにする.md` | 変更 | 同上 |
| 7 | `.claude/docs/README.md` | 変更 | `bash .claude/scripts/src/generate-ddr-list.sh` の**再生成結果**を同じコミットへ含める（手書きしない） |
| 8 | `.claude/docs/spec/create-commit.md` | 変更 | **挙動の正史**として「渡していないステージ済み変更も同じコミットへ入る」を仕様へ書き、`## 影響範囲` へchangelogを追記する |
| 9 | `.claude/rules/git-workflow.md` | 変更 | 「コミット運用」節へ**運用上の注意**を1〜2行足し、詳細は #8 を指す（仕様を二重に書かない） |
| — | `.claude/VERSION` | **変更しない** | 人間の判断で `0.1.2` に据え置き（下記「方針」） |

**触らない**（point-in-time の記録）: `.claude/docs/spec/issue-mr-workflow.md:2049` と
`:3280-3282`（どちらも `## 影響範囲`（1754行）より下）、および既存DDRの**本文**。#5・#6 で触るのは
frontmatter の `note` キーだけで、これは `.claude/rules/markdown-frontmatter.md` が明示的に
許している（`status` / `superseded_by` と同じ扱い）。

## 方針

### spec へ新設する節の中身（#1）

`### 全体作業計画に必ず含めるフェーズ（issue #92）` の直後へ置く。

**運用の詳細（見出し構成・必須／任意・作成タイミング・検査コマンド）は書かない。** それらは既に
`.claude/skills/issue-mr-flow/SKILL.md:363-395`「計画・レポートのHTMLビュー」とテンプレート本体の
冒頭コメントにあり、spec へ同じことを書くと**正が2つになる**。隣接する
`### 全体作業計画に必ず含めるフェーズ（issue #92）` が末尾で「判断基準そのものの正は SKILL.md で
あり、本節はその位置づけの記録にとどめる」と書いているのと同じ形にする。

**正の所在**（新設節はこれを1つの表で示すことを主目的にする）:

| 何の正か | どこ |
|---|---|
| 記述の型（見出し構成・必須／任意の区別・埋め忘れの検査） | **テンプレート本体**（`assets/plans.template.html` / `reports.template.html`）の冒頭コメント |
| いつ作るか・作った後どう扱うか（flow-idごとの手順） | **`issue-mr-flow/SKILL.md`**「計画・レポートのHTMLビュー」 |
| レビュー時に何を見るか | **`plans/REVIEW-POINTS.md` / `reports/REVIEW-POINTS.md`** |
| ライフサイクル（いつ削除するか・frontmatterの対象外） | **`.claude/rules/docs-workflow.md`** のライフサイクル表 |

そのうえで、**spec 側にしか書けないこと**を書く。

1. **なぜテンプレートファイルへ切り出したのか**（記述の型の正が SKILL.md の散文に散っており、
   導入先プロジェクトが自分の型へ差し替えるときに手を入れる場所が定まらなかった）。
2. **なぜ2本なのか**（`plans/` と `reports/` で必須セクションが異なるため。md側のテンプレートは
   持たない——型を固定する価値があるのは人間が繰り返し目を通すHTMLビューの側だけ）。
3. **外部依存を持たない方式を採ったこと**と、その決定の経緯は DDR `i0054-01` にあること。

### 暫定記述の解除（#2）

置き換え前（677行目）:

> | HTMLの土台 | `.claude/skills/issue-mr-flow/assets/reports.template.html`（**issue #54 の成果物。未作成の間は手書きへフォールバックする**） |

置き換え後（案）:

> | HTMLの土台 | `.claude/skills/issue-mr-flow/assets/reports.template.html`（必須セクションの読み替えは同テンプレートの使い方コメントを参照） |

**この行は `## 仕様` 配下（`### 最終統括レポートとPR/MRへの反映（issue #111）`）にあり、
現在の設計を説明する記述である。** **類似の記述が 3280-3282行**（`## 影響範囲` 配下のchangelog）
にもあるが、そちらは**触らない**。なお両者は同じ文面ではない（3280行は「受け入れ条件のうち…は
部分達成である」で始まり、「無ければ手書きへフォールバックする形にした」は3281-3282行に跨る
別の言い回しである）。**文字列一致で探すと見つからないので、行番号の範囲で押さえる。**
分かれ目は 1754行目より下かどうかであって、issue番号でも文面の似かたでもない
（フェーズ3の計画にも同じ注意を書いている）。

### 新規DDR `i0054-01` に記録する決定（#4）

**1件にまとめる。** 2件へ分けない（`SKILL.md` が `i0054-01` という名前で既に参照しており、
分けると参照が無言で切れる。フェーズ3の敵対的レビューの指摘）。記録する決定は2つある。

**ファイル名は決定2（`assets` への切り出し）しか表していない**が、`SKILL.md` の既存参照に
縛られるため変更しない。代わりに **`description` と `keywords` へ決定1（TailwindCSS CDN →
自己完結CSS への方式変更）を必ず含める**。DDR一覧はファイル名で並ぶので、これが無いと
「方式変更の決定」が一覧・`doc-search` から見つからない（`SKILL.md:388-390` がこのDDRを引いて
いるのは、まさに「外部依存を持たせない」の経緯としてである）。

| # | 決定 | 却下案 |
|---|---|---|
| 1 | レポート・計画のHTMLビューは**自己完結CSS**で書く（TailwindCSS CDN方式をやめる） | (a) CDN方式を維持する（issue本文の字面どおり）。(b) 共有CSSファイルへ切り出して2本から読む |
| 2 | スキル配下のバンドルリソースの語彙を **`assets/`** に統一する（`templates/` を使わない） | (a) `templates/` を使う。(b) `resources/` 等の第3の語彙を作る |

決定1の理由の核は「**`i0000-11` がCDNを選んだ根拠(b)（出力トークン量と表現力の釣り合い）が、
テンプレート化すると成り立たなくなる**」こと。CSSを書くのがテンプレート作成の1回だけになるため。
到達性（CDNが遮断されていること）は**主根拠にしない**——`i0141-01` は到達不可を知ったうえで
`reports/` をCDN方式に据え置いており、同じ事実から逆の結論は出せない。

却下案 (b)（共有CSS）を採らない理由も書く: 共有ファイルを読むと「自己完結」でなくなり、
`reports/` が flow-id 5-4 で削除されたときにHTMLだけが残ると開けなくなる。2本のCSSの重複は
許容する。

### 既存DDRへ添える `note`（#5・#6）

**`status: superseded` は使わない。** どちらも決定の**一部だけ**が変わっており、決定全体が
置き換えられたわけではないため（`.claude/rules/markdown-frontmatter.md`「DDRのnote」の類型
「決定の一部だけが後で変わった」に当たる）。

| DDR | `note` に書くこと |
|---|---|
| `i0000-11` | 「html版を自己完結HTMLのコミットで作る」という決定自体は有効。**方式のみ** issue #54 でTailwindCSS CDNから自己完結CSSへ変わった。詳細は `i0054-01` |
| `i0141-01` | canvas形式をTailwind非依存にした決定は有効。issue #54 で**一覧・表形式も**自己完結になったため、「canvas形式だけが例外」という前提は成り立たない。詳細は `i0054-01` |

**`description` は書き換えない**（元の決定内容が読み取れなくなるため）。

**`note` の値は必ずシングルクォートで囲む。** `generate-ddr-list.sh` は非クォートのスカラーに
対して `sub(/[[:space:]]+#.*$/, "", value)` で行内コメントを落とすため、**値に含まれる ` #54` の
手前で打ち切られる**。上の2件はどちらも「issue #54 で」という語を含むので、素で書くと
「詳細は `i0054-01`」という肝心のポインタが消えたREADMEが生成される（再現確認済み）。
`.claude/rules/markdown-frontmatter.md`「DDRのnote」の例も `note: '…'` の形になっている。

```yaml
# 悪い例（値が「… **方式のみ** issue」で切れる）
note: 「html版を…」という決定自体は有効。**方式のみ** issue #54 で…
# 良い例
note: '「html版を…」という決定自体は有効。**方式のみ** issue #54 で…'
```

**この誤りは検証3（差分を見るだけ）では気づけない。** 生成物としては正常に出来上がるためである。

### `.claude/VERSION` の増分提案（変更しない）

現在 `0.1.2`。AIからは **`0.2.0`（MINOR）を提案した**（`.claude/docs/spec/distribution-assets.md`
の表で `MINOR` は「資産の追加・フローの拡張」であり、今回は配布対象へテンプレート2本が**増え**、
flow-id 3-6・4-6 でのHTML作成が**必須になった**ため）。

**ユーザーの判断は「`0.1.2` で良い」**（チャットで受領。2026-08-22）。したがって
**`.claude/VERSION` は変更しない。** この判断はMRへ記録する
（`.claude/skills/issue-mr-flow/SKILL.md`「チャットで受けたレビュー判断の記録」）。

### `create-commit.sh` の挙動の記録（#8・#9）

**仕様の正は `.claude/docs/spec/create-commit.md` に置き、`rules/git-workflow.md` はそこを指す。**
運用注意だけを rules へ書くと、スクリプトの仕様書を読んだ人は誤った理解のまま残る。

`create-commit.sh:124` は `git commit -m "$message"` を**パス指定なしで**実行するため、
**渡したパスに加えて、既にステージ済みの変更も同じコミットへ入る**。現行の仕様書は、削除済み
パスがSKIPされる事例に触れているだけで、この挙動そのものを書いていない。

| ファイル | 書くこと |
|---|---|
| `spec/create-commit.md` | 「実行方法」に挙動を1段落。あわせて `## 影響範囲` へ issue #54 のchangelogを追記する |
| `rules/git-workflow.md` | 「コミット運用」節へ**運用上の注意**を1〜2行（呼ぶ前に `git status` でステージ済みのものが無いかを見る）。詳細は spec を指す |

issue #54 のフェーズ3で実際に踏んだ（`git mv` でステージ済みだった改名が、別のコミットへ
混ざった）。同一ブランチかつsquash mergeのため実害は無かったが、コミットメッセージと中身が
食い違った。

## やらないこと（スコープ外）

- **`.claude/VERSION` の値の変更**。AIから `0.2.0`（MINOR）を提案したが、**ユーザーの判断で
  `0.1.2` に据え置き**となった（MRへ記録済み）。
- **`create-commit.sh` の挙動の変更**。ルールへ注意を書くに留める（挙動を変えると、削除の
  ステージ済みパスを吸収する `i0060-01` の設計と衝突しうるため、それ自体が独立した意思決定になる）。
- **DDR本文の変更**（`note` の追加のみ）。
- **`spec/issue-mr-workflow.md:2049` と `:3280-3282` の変更**（point-in-time の記録）。
- **markdownテンプレートの新設**（issue #54 本文が明示的に除外。全フェーズ共通のスコープ外）。

## 検証

```bash
# 分岐点のSHAを取る（以降の「変えていないこと」の検証はすべてこれを基準にする）
base=$(git merge-base origin/main HEAD)

# 1. DDRのファイル名・title・見出しが識別子の規約に沿っていること
ls .claude/docs/ddr/ | grep '^i0054-01-'
head -20 .claude/docs/ddr/i0054-01-*.md

# 2. SKILL.md が参照しているDDRが実在すること（フェーズ3の指摘への最終確認）
test -f "$(grep -o '\.claude/docs/ddr/i0054-01-[^)]*\.md' .claude/skills/issue-mr-flow/SKILL.md | head -1)"

# 3. DDR一覧が生成物として最新であること（--check は差分なし=0 / 差分あり=2）
bash .claude/scripts/src/generate-ddr-list.sh --check; echo "exit=$?"

# 3-b. noteがREADMEへ最後まで載っていること（行内コメント落ちの検出）
grep -c -- 'i0054-01' .claude/docs/README.md

# 4. 既存DDR2件の変更がfrontmatterのnote行だけであること（本文を変えていないこと）
git diff "$base" -- .claude/docs/ddr/i0000-11-*.md .claude/docs/ddr/i0141-01-*.md \
  | grep -E '^[-+][^-+]' | grep -vc '^+note:'

# 5. specの過去changelogを書き換えていないこと
#    削除行は「677行の表セル1行のみ」が期待値。0ではない（#2 が置き換えのため）
git diff "$base" -- .claude/docs/spec/ | grep -- '^-[^-]'

# 5-b. .claude/ 全体でも、意図しない削除が無いこと（内容を目視する）
git diff "$base" -- .claude/ | grep -- '^-[^-]' | grep -v 'HTMLの土台'

# 6. 暫定記述が仕様側から消え、changelog側には残っていること
awk 'NR<1754'  .claude/docs/spec/issue-mr-workflow.md | grep -c -- '未作成の間は手書きへフォールバック'
awk 'NR>=1754' .claude/docs/spec/issue-mr-workflow.md | grep -c -- 'フォールバックする形にした'

# 7. 新設した節の見出しがちょうど1件であること
grep -c -- '^### 計画・レポートのHTMLビュー（issue #54）' .claude/docs/spec/issue-mr-workflow.md

# 8. create-commit.md の仕様追記と、git-workflow.md からの参照があること
grep -c -- 'ステージ済み' .claude/docs/spec/create-commit.md
grep -c -- 'create-commit.md' .claude/rules/git-workflow.md

# 9. frontmatterインデックスが再生成できること
bash .claude/scripts/src/extract-frontmatter.sh .
```

| # | 期待値 |
|---|---|
| 1・2 | 通ること（`i0054-01-` が1件・`test -f` が成功） |
| 3 | `exit=0`（再生成しても差分が出ない） |
| 3-b | **1以上**（`note` が途中で切れていれば0になる） |
| 4 | **0**（追加された `note:` 行を除くと、増減した行が1つも無い） |
| 5 | **`-| HTMLの土台 | …` の1行だけ**が出ること（件数ではなく中身を読む） |
| 5-b | **何も出ない**こと（677行の置き換え以外に削除が無い） |
| 6 | 1つ目が **0**、2つ目が **1**（仕様側から消え、changelog側は残っている） |
| 7 | **1** |
| 8 | どちらも **1以上** |
| 9 | `failed=0` |

**「何も出なければ成功」で済ませているのは 5-b だけで、それも 5 で中身を読んだうえでの二重確認
である。** 他はすべて件数か終了コードを出す形にしてある（観点表「異常が無ければ何も出ない検証は
常に成功する」）。
