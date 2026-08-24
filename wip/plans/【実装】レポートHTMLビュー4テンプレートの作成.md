---
title: 【実装】レポートHTMLビュー4テンプレートの作成
type: plan
description: issue #203 フェーズ3の個別作業計画。調査結果をもとに共通DOM＋4通りのstyleでレポートHTMLビューのテンプレート4本を作る
tags: [plan, issue-mr-flow, reports, template]
keywords: [reports-clean, reports-neobrutal, reports-mono, reports-paper, 共通DOM, セマンティッククラス, 検査, color-scheme, issue203]
---

# 【実装】レポートHTMLビュー4テンプレートの作成（issue #203 / flow-id 3-1）

## 前提（合意状況）

- 上位の計画: `wip/plans/silver-drifting-lantern.md`（全体作業計画。flow-id 1-4）
- 依拠する調査結果: `wip/reports/20260824_silver-drifting-lantern_デザイン4案のテンプレート化方針.md`
  （flow-id 2-6。Q1〜Q8のすべてに結論と根拠がある）
- **人間のレビューは非対話セッションのため未実施。** 合意の代わりに敵対的レビュー1回目
  （12件、全件対応済み）を通している。**Q5（サンプルブランチの後始末）とQ6（ファイル名・既定）は
  PR #204 のコメントでユーザーへ判断・承認を依頼中**であり、この計画はその回答を待たずに
  進められる範囲を対象とする。

## この計画で何をするか

調査結果の「設計への反映」9項目を、実際のファイルとして作る。

**共通DOMを1つ設計し、`<style>` だけを4通り差し替えた4本のテンプレート**を
`.claude/skills/issue-mr-flow/assets/` へ置く。

## 変更対象

| ファイル | 操作 | 何をするか |
|---|---|---|
| `.claude/skills/issue-mr-flow/assets/reports-clean.template.html` | 新規 | 案06。**既定**。ライト／ダーク両対応 |
| `.claude/skills/issue-mr-flow/assets/reports-neobrutal.template.html` | 新規 | 案10。太い黒枠＋ハードシャドウ。ライト単一 |
| `.claude/skills/issue-mr-flow/assets/reports-mono.template.html` | 新規 | 案12。色を持つのは意味論を担う要素だけ。ライト／ダーク両対応 |
| `.claude/skills/issue-mr-flow/assets/reports-paper.template.html` | 新規 | 案13。書類風。印刷向け。ライト単一 |
| `.claude/skills/issue-mr-flow/assets/reports.template.html` | **変更しない** | 現行を据え置く（Q3・Q6で併存と決めた） |

**`plans.template.html` は触らない**（issue #203 の対象外）。

## 方針

### 1. 節構成（現行8節を落とさない）

調査Q3の対応表に従う。**サンプル06をそのまま写さない。**

| 節（id） | 必須／任意 | 新構成での形 |
|---|---|---|
| サイドバー | 必須 | 目次・結論件数チップ・メタ情報。常時表示 |
| `overview` | 必須 | 総括1文＋KPIタイル3つ＋重点レビュー依頼カード3枚 |
| `unverified` | 必須 | 確かめられなかったこと（前半に置く） |
| `conditions` | 任意（実測なら必須） | **独立した `<section>`**（サンプルの `<li>` から戻す） |
| `findings` | 必須 | タイムライン。章は `f1`…`fN` |
| `next` | 必須 | **独立した `<section>`**（サンプルの `<li>` から戻す） |
| `surprises` | 任意 | **新設**（サンプルに対応先が無かった） |
| `todo` | 任意 | **新設**（同上） |

**`next` と `conditions` をタイムラインの外へ出すのが要点。** `<li>` のままだと
「任意セクションは `<section>` ごと削除する」という規約が働かない（`<li>` は `<section>` ではない）。
見た目のつながりはCSSで作る。

### 2. セマンティッククラス（現行の語彙を再利用し、新構造ぶんだけ足す）

**現行から引き継ぐ**: `.chip.good/.warn/.stop` / `.focus.must/.want/.skip` /
`.box.info/.ok/.warn/.stop` / `.verdict` / `.meta` / `.tablewrap` / `.wrap`

**新しく足す**: `.sidebar` / `.tl` / `.tl-item` / `.tl-dot`（`.good .warn .stop .neutral .next`）/
`.kpi`（`.good .warn .stop`）/ `.hl`

**`.hl` はDOM共有のために要る。** 案10だけが `<mark>` で強調しているが、タグの違いとして持つと
4案でDOMが分岐する。`<strong class="hl">` に統一し、案10の `<style>` だけが背景色を与える。

### 3. 色と記号の意味論（issue #186。変えない）

- 結論の性質は**3色＋記号＋文字**（◎良=青／△注意=黄／✕問題=赤）。色だけに意味を持たせない。
- 緑（`--ok` / `.box.ok`）は**決めたこと・手順の成功専用**。結論の性質には使わない。
- 重点レビュー依頼の3段階（◆◇・）は**色相を使わない**。
- **案12だけは `.box.ok` に色を与えず、太い左罫＋「決定」ラベルで表す**（Q7。12は緑系を持たない。
  12の「色が見えたら結論の性質」という方針とはむしろ整合する）。

### 4. テーマ

| テンプレート | テーマ | 実装 |
|---|---|---|
| `reports-clean`（既定） | ライト／ダーク | `@media (prefers-color-scheme: dark)` でCSS変数を再定義 |
| `reports-mono` | ライト／ダーク | 同上 |
| `reports-neobrutal` | **ライト単一** | `color-scheme: light` を明示（ブラウザの強制ダーク化を防ぐ） |
| `reports-paper` | **ライト単一** | 同上 |

### 5. 冒頭コメント（テンプレートの「仕組み」の実体）

現行 `reports.template.html` の冒頭コメント（約120行）が持つ次の内容を、**4本すべてに同じものを
持たせる**（DOMを共有できるので、書き分けない）。デザイン固有の説明だけを1〜2行足す。

- 使い方（コピー → 埋める → 任意節を削る → プレースホルダを残さない → 冒頭コメントを置き換える）
- 節の並び順と、変えない理由
- 色・記号の使い分け（issue #186 の意味論）
- 重点レビュー依頼の書き方（3段階。書くことが無い枠も削除しない）
- アンカーと**検査手順**（下記）
- 必須／任意の区別
- フェーズごとの読み替え（2-6 / 3-6 / 4-6 / 5-4）
- 計画を書かないこと／正文はmd側であること／canvas形式との使い分け／外部依存なし

### 6. 検査（5種。**3種→5種へ増やす**）

| 検査 | 合格条件 |
|---|---|
| プレースホルダ | `grep -c '<!-- ここに書く'` が 0 |
| リンク破断 | `comm -23`（href集合 − id集合）が0行 |
| 重複ID | `sort \| uniq -d` が出力なし |
| **外部依存1** | `grep -nE "(src\|href)=['\"]?(https?:)?//"` |
| **外部依存2** | `grep -nE "(url\(\|@import[[:space:]]+)['\"]?(https?:)?//"` |

**外部依存検査は0件を機械的な合格条件にしない。** エスケープ済みの地の文（`<code>` 内の引用等）
にも当たるため、ヒットしたら中身を見て判断する——この注意を使い方コメントへ書く
（現行がプレースホルダ検査について書いている注意と同じ性質）。

## やらないこと（スコープ外）

- 現行 `reports.template.html` の変更・削除（併存と決めた。Q3・Q6）
- `plans.template.html` の再デザイン（issue #203 の対象外）
- `deliverables.md` 等の参照ドキュメントの更新（**フェーズ4で行う**。ここではテンプレート本体だけを作る）
- `wip/design-samples/` の取り込み・ブランチ削除（Q5。取り込まないと決定済み／削除は指示待ち）

## 検証

各テンプレートは**プレースホルダを持ったままの雛形**なので、プレースホルダ検査だけは
「0件」ではなく「**意図した数だけ存在する**」ことを確認する（テンプレート本体は埋める前の状態）。

```bash
cd .claude/skills/issue-mr-flow/assets
for F in reports-clean reports-neobrutal reports-mono reports-paper; do
  f="$F.template.html"
  echo "--- $f ---"
  # プレースホルダ: テンプレートなので0ではなく「存在する」ことを見る
  grep -c '<!-- ここに書く' "$f"
  # リンク破断（0行が合格）
  comm -23 <(grep -oE 'href="#[A-Za-z0-9_-]+"' "$f" | sed 's/^href="#//;s/"$//' | sort -u) \
           <(grep -oE '<[a-z][^>]*[[:space:]]id="[A-Za-z0-9_-]+"' "$f" | sed 's/.*id="//;s/"$//' | sort -u)
  # 重複ID（出力なしが合格）
  grep -oE '<[a-z][^>]*[[:space:]]id="[A-Za-z0-9_-]+"' "$f" | sed 's/.*id="//;s/"$//' | sort | uniq -d
  # 外部依存（ヒットしたら中身を見る）
  grep -nE "(src|href)=['\"]?(https?:)?//" "$f"
  grep -nE "(url\(|@import[[:space:]]+)['\"]?(https?:)?//" "$f"
done
```

**あわせて、4本のDOMが本当に共通であることを機械的に確かめる**（この計画の中心的な主張なので、
主張したまま検証しないことはしない）。

```bash
for F in reports-clean reports-neobrutal reports-mono reports-paper; do
  # <style>〜</style> を除いた本文のタグ構造（開閉タグ両方）
  sed '/^<style>/,/^<\/style>/d' "$F.template.html" | grep -oE '</?[a-z][a-z0-9]*' > "/tmp/dom-$F.txt"
done
diff /tmp/dom-reports-clean.txt /tmp/dom-reports-neobrutal.txt   # 差分0行が合格
```

合格条件:

- 5種の検査が上記の基準を満たす（外部依存はヒット0件、またはヒットの中身が地の文の引用だと確認済み）
- **4本のDOM（`<style>` を除く）が完全に一致する**
- 4本すべてに、現行と同等の冒頭コメント（使い方・節順・意味論・検査手順・フェーズ読み替え）がある
- 必須8節がすべて存在し、任意節に `[任意]` の印がある

## issueの受け入れ条件との対応

| 受け入れ条件 | この計画での対応 |
|---|---|
| (1) 4デザインが `assets/` に存在し flow-id 2-6/3-6/4-6/5-4 から参照できる | 「変更対象」の4ファイル。**参照側の更新はフェーズ4** |
| (2) 外部依存ゼロ | 「検証」の外部依存検査2本 |
| (3) プレースホルダ・3種の検査手順・フェーズ読み替えが引き継がれている | 「方針5」の冒頭コメント＋「方針6」（3種→5種へ拡張） |
| (4) 選択基準（既定はどれか）がドキュメント化されている | 調査Q6で確定済み。**文書への反映はフェーズ4** |
| (5) 現行の扱いと `wip/design-samples/` の後始末 | 現行は据え置き（この計画の「やらないこと」）。後始末は調査Q5で決定済み |
