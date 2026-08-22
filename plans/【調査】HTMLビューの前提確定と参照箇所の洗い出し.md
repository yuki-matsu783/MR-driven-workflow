---
title: 【調査】HTMLビューの前提確定と参照箇所の洗い出し
type: plan
description: issue #54の個別調査計画。HTMLの外部依存方式・assets語彙の衝突・plans側HTMLの命名規則・改訂対象箇所・削除/インデックスの挙動を実測で確定する。
tags: [issue-mr-flow, plan, 調査, html]
keywords: [TailwindCSS, CDN, 自己完結, plans.template.html, reports.template.html, flow-id, cleanup-task, index.jsonl, canvas-report, assets]
---

# 【調査】HTMLビューの前提確定と参照箇所の洗い出し（issue #54 / フェーズ2）

全体作業計画: `plans/tidy-scoping-lantern.md`

## 前提（合意状況）

- 全体作業計画は **flow-id 1-4** で作成した。
- **flow-id 1-5（人間による合意）は得ていない。** 本セッションはユーザーの指示により非対話的に
  進めており、結果確認工程は `adversarial-review` スキルで代替する。したがって本計画の前提は
  **すべてAIの提案段階**であり、人間がスコープを見直した場合は 1-4 まで巻き戻しうる。
- 下記「やらないこと」のうち、markdownテンプレート・最終統括レポート用テンプレート・
  `.mrworkflow.json` への設定追加の3項目は **issue #54 本文が明示的に除外**したものである
  （AIの判断ではない）。`HANDOFF.md` のテンプレート外だしだけは、issue #28 のマージ前通知が
  「突き合わせること」と求めた論点で、**本計画がQ8として調査したうえで判断する**。

## 目的

テンプレートを書き始める前に、**issue #54 本文が前提としている事実のうち、その後の変更で
動いた可能性があるもの**を確定させる。実装（フェーズ3）で方針が揺れないようにすることが狙い
であり、テンプレートの中身そのものはここでは書かない。

## 調べること（調査項目）

| # | 問い | 確認方法 | この調査で出す成果 |
|---|---|---|---|
| Q1 | 新設テンプレートの外部依存は TailwindCSS CDN方式 と 自己完結CSS のどちらを採るべきか | 下記「Q1の決定規則」に従う | どちらを採るかの結論と根拠。採らなかった側の理由 |
| Q2 | `reports/*.html` の既存の実物を参照できるか | 下記「Q2の探索範囲の明示」に従う | 参照できるか否か。**できない場合、それが「存在しない」のか「この作業ツリーから見えない」のかの区別**と、必須／任意セクションの根拠をどこへ置くか |
| Q3 | `plans/` 側HTMLのファイル名規則をどう決めるか | `plans/` のmdが持つ2つの命名体系（全体作業計画＝自動命名／個別計画＝`【種別】〜`）と、`cleanup-task.sh`・`.gitignore`・`index.jsonl` の挙動を突き合わせる | 命名規則の決定と、その規則が既存機構を壊さない根拠 |
| Q4 | issue本文の flow-id はどれだけ現行とずれているか | issue本文の flow-id と現行 `SKILL.md` の全体フロー表を突き合わせる | 読み替え表（issue本文の番号 → 現行番号） |
| Q5 | 改訂が必要な参照箇所はどこか（全数） | 下記「Q5の検索パターン」の各パターンを流す | **2列の一覧**（「改訂する箇所」と「ヒットするが改訂しない箇所」）とパターンごとのヒット件数 |
| Q6 | `cleanup-task.sh` は `plans/*.html` を削除するか | 下記「Q6・Q7の実行確認」に従う | **削除対象に入るか否か**と、入らない場合に必要な変更 |
| Q7 | `extract-frontmatter.sh` / `index.jsonl` は `.html` を拾うか | 下記「Q6・Q7の実行確認」に従う | **拾うか否か**と、`plans/*.html` のfrontmatterの扱いをどう書くか |
| Q8 | `HANDOFF.md` のテンプレート外だしを本issueへ含めるべきか（issue #28 のマージ前通知） | **DDR `i0028-01`**（`flow-id5-1の後片付けはスクリプト化しコミットは含めない`）の却下案(b)と `cleanup-task.sh` の設計を読む | **本issueへ含めるか否かの結論と理由** |
| Q9 | `assets` という語は、このリポジトリの既存用法と衝突しないか | 下記「Q9の確認方法」に従う | 衝突の有無と、衝突する場合に語彙を分ける必要があるか |

**想定と異なる結果が出た場合の扱い**: Q6・Q7 が想定と異なれば、必要な変更をフェーズ3の
個別作業計画へ追加する（この調査では変更しない）。Q8 が「覆すべき」となった場合は、
**本issueでは扱わず別issueの起票を提案する**（DDRの決定を覆す判断は、それ自体が独立した
意思決定であるため）。Q9 が衝突と出た場合は、語彙の選択を全体作業計画へ差し戻す。

### Q1の決定規則

**CDNへの到達性そのものを主根拠にしない。** 到達不可という事実は DDR `i0141-01` が既に記録して
おり、**それを知ったうえで同DDRは `reports/` の通常HTMLをCDN方式に据え置いている**。同じ事実から
逆の結論を出すことになるため、判断軸を次の2つに置く。

1. **`i0000-11`（`reports/*.html` にCDNを選んだDDR）の根拠が、テンプレート化後も成り立つか。**
   同DDRの根拠は (a) ビルドステップ不要 (b) 出力トークン量と表現力のバランス、の2つである。
   → (b) が成り立たないなら、CDNを選ぶ根拠が1つ失われる。
2. **`i0141-01` が canvas を分けた実際の理由（ユーティリティクラスの適用範囲外の描画・
   実行時まで気づけない誤り・検証不能）が、新設テンプレートにも当てはまるか。**

**決定規則**: 1 と 2 の**いずれかが「CDN不利」と出たら自己完結CSSを採る**。どちらも成り立つ
（CDNの根拠が保たれ、canvas固有の事情も当てはまらない）なら、現行の標準方式であるCDNを維持する。

到達性の実測も行うが、**結論の主語を「この実行環境のプロキシ経由での到達性」に限定**し、
補強材料として扱う（`reports/REVIEW-POINTS.md`「結論の主語が、実際に測った対象と一致しているか」）。

### Q2の探索範囲の明示

`git log --all` は**この作業ツリーが持つrefと履歴の範囲しか見ない**。0件だったときに
「存在しない」と書けるかは、探索範囲に依る。実行前に次を採り、レポートへ残す。

```bash
git rev-parse --is-shallow-repository
git for-each-ref --format='%(refname)'
```

浅いクローンだった場合、`git log` の0件から「存在しない」は導けない。その場合は
**区別できないことを結論へ明記する**（代替手段としてクローズ済みPRのdiffをMCPで参照する案も
あるが、削除済みブランチの断面は取得できないため、本調査では追わない）。

### Q5の検索パターン

**パターンを列挙し、各パターンのヒット件数を0件も含めてレポートへ残す。** 除外は `.git/`・
`usage/`（セッションログのミラー。自分の検索結果自体が混ざる）・`index.jsonl`・`plans/`
（この計画自身）に限り、`--include` による拡張子の絞り込みは行わない。

| # | パターン | 目的 |
|---|---|---|
| P1 | `canvas-report/templates` | 改名で書き換える参照 |
| P2 | `templates/` | 改名の取りこぼし（`ISSUE_TEMPLATE` 等の無関係語を目視で除く） |
| P3 | `canvas-report.html` | テンプレート本体への参照 |
| P4 | `TailwindCSS\|tailwindcss` | HTMLの方式を書いている箇所 |
| P5 | `自己完結HTML` | 同上 |
| P6 | `reports/日付` | レポートHTMLの作成手順を書いている箇所 |
| P7 | `assets` | Q9の判断材料 |

**一覧は2列に分ける。**

- **改訂する箇所**
- **ヒットするが改訂しない箇所** — DDR本文（`.claude/rules/docs-workflow.md`・
  `markdown-frontmatter.md` により変更不可。更新してよいのはfrontmatterの
  `status`/`superseded_by`/`note` のみ）と、`.claude/docs/spec/*.md` の
  `## 影響範囲` 配下の過去issueのchangelog（point-in-timeの記録）。

フェーズ3では、改名に伴うパス置換がこれらへ及んでいないことを
`git diff <ブランチ分岐点のSHA> -- .claude/docs/ddr/` の**削除行が0**であることで確認する
（`.claude/rules/docs-workflow.md` の該当節）。

### Q6・Q7の実行確認

**どちらも読むだけで終えず、probeファイルを置いて実行で確かめる。** probeは追跡外のファイルを
Git管理下のディレクトリへ作るため、**後始末を `trap` で保証する**（残骸が次のcommitへ混入すると
`.claude/rules/git-workflow.md`「`git status` の出力を機械的に全件 `commit` スキルへ渡さない」で
警告されている事故になる）。

```bash
(
  trap 'rm -f plans/__probe__.html reports/__probe__.html' EXIT
  printf '<!-- probe -->\n' > plans/__probe__.html
  printf '<!-- probe -->\n' > reports/__probe__.html
  bash .claude/scripts/src/cleanup-task.sh --dry-run          # Q6
  bash .claude/scripts/src/extract-frontmatter.sh plans       # Q7
  grep -c '__probe__' plans/index.jsonl || true               # Q7: 0件なら .html は拾われない
)
git status --porcelain -- plans reports    # 残骸が無いことを確認する
```

Q7の実装確認をgrepで補う場合は、走査箇所を直接指す語で絞る
（`grep -n 'ls-files' .claude/scripts/src/extract-frontmatter.sh`）。
`grep -n '\.md'` のような広いパターンは、コメント中のファイル名を大量に拾って該当行を埋もれさせる。

### Q9の確認方法

```bash
grep -rn 'assets' --exclude-dir=.git --exclude-dir=usage --exclude=index.jsonl .
git check-ignore -v .claude/skills/issue-mr-flow/assets/x.html   # 何にも当たらなければ終了コード1
```

見るのは次の3点。

1. `apply-mr-workflow-to-project` の `sync-assets.sh` / `install-to-project.sh` が使う
   `assets/` の意味（配布アセットの集約先）と衝突しないか。
2. `.gitignore` の除外行が新設ディレクトリに当たらないか。
3. `.claude/rules/directory-structure.md`「配置の指針」が定める語彙（現在は `templates/` を
   実例に挙げている）を、規約として書き換えることになるという認識が持てているか。

## やらないこと（この調査のスコープ外）

- **テンプレートの見出し構成の確定**。必須／任意セクションの具体的な列挙は、調査結果を踏まえて
  フェーズ3の個別作業計画で決める（この調査では「何を根拠に決めるか」までを出す）。
- **HTMLの実装・ブラウザ実機検証**。フェーズ3で行う。
- **canvas形式テンプレートの中身の変更**。本issueは `templates/` → `assets/` の改名のみを扱う。

## 検証（この調査自身の確からしさをどう担保するか）

- Q1 の実測は**このセッションの実行環境1つ**での観測であることを明記し、結論の主語を
  そこへ限定する。他環境でCDNが通る可能性は否定しない。
- Q2 は探索範囲（浅いクローンか・持っているrefは何か）を先に採り、レポートへ残す。
- Q5 の網羅性は、上表P1〜P7の**各パターンのヒット件数**（0件を含む）で示す。
- Q6・Q7 は上記のとおり実行で確かめ、probeの後始末を `git status --porcelain` で確認する。

## 成果物

- `reports/20260822_tidy-scoping-lantern_HTMLビュー前提調査.md`（正文）
- `reports/20260822_tidy-scoping-lantern_HTMLビュー前提調査.html`（視覚化）

本調査は「複数要素間の関連・依存関係」ではなく**問いごとの結論の一覧**が主題のため、
canvas形式ではなく一覧・表形式のHTMLで表現する（`canvas-report/SKILL.md`「いつcanvasを選ぶか」）。

**このレポート自身のHTMLは、外部依存を持たない自己完結CSSで書く。** Q1の結論を先取りするので
はなく、**この実行環境ではCDNが遮断されており、CDN方式で書くと表示を1度も確認できないまま
「視覚化した」と称することになる**ため（現行ルールからの逸脱にあたるので、レポート本文へ
その旨を明記する）。Q1がCDN維持と結論した場合は、フェーズ3でこのレポートのHTMLもCDN方式へ
書き換える。
