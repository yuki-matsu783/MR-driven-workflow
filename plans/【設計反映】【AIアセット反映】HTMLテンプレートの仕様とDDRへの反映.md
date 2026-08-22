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
- 種別を `【設計反映】【AIアセット反映】` の**併記**にしたのは、2つの反映先へ**1回で合意を取る**
  ためである。分量が小さく（spec 1節＋DDR 3件＋rules 1箇所）、判断も独立していない
  （DDRが記録する方針変更が、そのままrules側の注意書きの前提になる）。

## この計画で何をするか

フェーズ2〈調査〉・フェーズ3〈作業〉で得た知見のうち、**恒久的に残すべきもの**を
`.claude/docs/spec/` `.claude/docs/ddr/` `.claude/rules/` へ反映する。

**新規に決めることはしない。** すべて既に決まったこと（テンプレート2本の存在・方式の変更・
`assets` 語彙の統一・検査コマンドの誤り）の記録である。唯一の例外が `.claude/VERSION` で、
これは**増分の提案のみ**を行い、値を上げるかどうかは人間が決める。

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
| 8 | `.claude/rules/git-workflow.md` | 変更 | 「コミット運用」節へ、`create-commit.sh` が既にステージ済みの変更も一緒にコミットする挙動を注意として足す |
| — | `.claude/VERSION` | **変更しない** | 増分の**提案のみ**行う（下記「方針」）。決めるのは人間 |

**触らない**（point-in-time の記録）: `.claude/docs/spec/issue-mr-workflow.md:2049` と `:3280`
（どちらも `## 影響範囲`（1754行）より下）、および既存DDRの**本文**。#5・#6 で触るのは
frontmatter の `note` キーだけで、これは `.claude/rules/markdown-frontmatter.md` が明示的に
許している（`status` / `superseded_by` と同じ扱い）。

## 方針

### spec へ新設する節の中身（#1）

`### 全体作業計画に必ず含めるフェーズ（issue #92）` の直後へ置く。**SKILL.md の内容を写さず**、
仕様として決まったことだけを書く。

1. **テンプレートは2本で、置き場は `.claude/skills/issue-mr-flow/assets/`**（`plans.template.html`
   / `reports.template.html`）。md 側のテンプレートは**持たない**。
2. **記述の型の正はテンプレート側**にあり、SKILL.md は見出し構成を列挙せず参照するだけにする。
3. **作成タイミング**: 計画は flow-id 1-4・2-1・3-1・4-1、レポートは 2-6・3-6・4-6・5-3。
   **md を作るなら html も作る**（md 1本に html 1本）。
4. **必須／任意の3値**（`[必須]` / `[任意]` / `[全体作業計画のみ必須]`）と、任意セクションは
   節ごと削除するという扱い。
5. **外部依存を持たない**（自己完結CSS）。**検査は「実際に外部を読みに行く記述」に限る**
   （`https://` を含む行を数える形にしない理由も1行で）。
6. **ライフサイクル**は md と同じ（flow-id 5-4 でまとめて削除、frontmatter の対象外）。

### 暫定記述の解除（#2）

置き換え前（677行目）:

> | HTMLの土台 | `.claude/skills/issue-mr-flow/assets/reports.template.html`（**issue #54 の成果物。未作成の間は手書きへフォールバックする**） |

置き換え後（案）:

> | HTMLの土台 | `.claude/skills/issue-mr-flow/assets/reports.template.html`（必須セクションの読み替えは同テンプレートの使い方コメントを参照） |

**この行は `## 仕様` 配下（`### 最終統括レポートとPR/MRへの反映（issue #111）`）にあり、
現在の設計を説明する記述である。** 同じ文面が `:3280` にもあるが、そちらは `## 影響範囲` 配下の
changelog なので**触らない**。分かれ目は 1754行目より下かどうかであって、issue番号でも文面の
似かたでもない（フェーズ3の計画にも同じ注意を書いている）。

### 新規DDR `i0054-01` に記録する決定（#4）

**1件にまとめる。** 2件へ分けない（`SKILL.md` が `i0054-01` という名前で既に参照しており、
分けると参照が無言で切れる。フェーズ3の敵対的レビューの指摘）。記録する決定は2つある。

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

### `.claude/VERSION` の増分提案（変更しない）

現在 `0.1.2`。AIからは **`0.2.0`（MINOR）を提案した**（`.claude/docs/spec/distribution-assets.md`
の表で `MINOR` は「資産の追加・フローの拡張」であり、今回は配布対象へテンプレート2本が**増え**、
flow-id 3-6・4-6 でのHTML作成が**必須になった**ため）。

**ユーザーの判断は「`0.1.2` で良い」**（チャットで受領。2026-08-22）。したがって
**`.claude/VERSION` は変更しない。** この判断はMRへ記録する
（`.claude/skills/issue-mr-flow/SKILL.md`「チャットで受けたレビュー判断の記録」）。

### `git-workflow.md` への追記（#8）

「コミット運用」節へ、次の趣旨を数行で足す。

> `create-commit.sh` は、**渡したパスに加えて、既にステージ済みの変更も一緒にコミットする**
> （`git add -- <files>` のあと、パス指定なしで gitのコミットコマンドを実行するため）。
> 意図しない変更が混ざらないよう、呼ぶ前に `git status` でステージ済みのものが無いかを見る。

issue #54 のフェーズ3で実際に踏んだ（`git mv` でステージ済みだった改名が、別のコミットへ
混ざった）。同一ブランチかつsquash mergeのため実害は無かったが、コミットメッセージと中身が
食い違った。

## やらないこと（スコープ外）

- **`.claude/VERSION` の値の変更**（提案のみ。決めるのは人間）。
- **`create-commit.sh` の挙動の変更**。ルールへ注意を書くに留める（挙動を変えると、削除の
  ステージ済みパスを吸収する `i0060-01` の設計と衝突しうるため、それ自体が独立した意思決定になる）。
- **DDR本文の変更**（`note` の追加のみ）。
- **`spec/issue-mr-workflow.md:2049` `:3280` の変更**（point-in-time の記録）。
- **markdownテンプレートの新設**（issue #54 本文が明示的に除外。全フェーズ共通のスコープ外）。

## 検証

```bash
# 1. DDRのファイル名・title・見出しが識別子の規約に沿っていること
ls .claude/docs/ddr/ | grep '^i0054-01-'
head -20 .claude/docs/ddr/i0054-01-*.md

# 2. SKILL.md が参照しているDDRが実在すること（フェーズ3の指摘への最終確認）
test -f "$(grep -o '\.claude/docs/ddr/i0054-01-[^)]*\.md' .claude/skills/issue-mr-flow/SKILL.md | head -1)"

# 3. DDR一覧が生成物として最新であること（再生成して差分が出ないこと）
bash .claude/scripts/src/generate-ddr-list.sh
git diff --stat -- .claude/docs/README.md

# 4. 既存DDRの本文を変更していないこと（frontmatterのみの差分であること）
git diff -- .claude/docs/ddr/i0000-11-*.md .claude/docs/ddr/i0141-01-*.md

# 5. specの過去changelogを書き換えていないこと（削除行が0であること）
git diff <ブランチ分岐点のSHA> -- .claude/docs/spec/ | grep -c '^-[^-]'

# 6. frontmatterインデックスが再生成できること
bash .claude/scripts/src/extract-frontmatter.sh .
```

合格条件: 1・2 が通り、3 の差分が0（生成済み）、4 が frontmatter の行だけ、5 が0、
6 が `failed=0` であること。
