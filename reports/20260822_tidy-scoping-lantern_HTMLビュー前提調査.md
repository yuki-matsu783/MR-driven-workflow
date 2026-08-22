---
title: 【調査結果】HTMLビューの前提確定と参照箇所の洗い出し
type: report
description: issue #54のフェーズ2調査結果。HTMLの外部依存方式・assets語彙の衝突・plans側HTMLの命名規則・改訂対象箇所・削除/インデックスの挙動を実測で確定した。
tags: [issue-mr-flow, report, 調査, html]
keywords: [TailwindCSS, CDN, 自己完結CSS, assets, plans.template.html, reports.template.html, cleanup-task, index.jsonl, flow-id, 命名規則]
---

# 【調査結果】HTMLビューの前提確定と参照箇所の洗い出し（issue #54 / フェーズ2）

- 全体作業計画: `plans/tidy-scoping-lantern.md`
- 個別調査計画: `plans/【調査】HTMLビューの前提確定と参照箇所の洗い出し.md`
- 実施日: 2026-08-22
- 実行環境: **Claude Code on the web のリモート実行環境（Linux、`gh`/`glab` CLI 無し、
  作業ツリーは浅いクローン）**

## サマリ（結論の一覧）

| # | 問い | 結論 | 根拠の性質 |
|---|---|---|---|
| Q1 | 外部依存は TailwindCSS CDN か 自己完結CSS か | **自己完結CSS を採る**（issue本文の前提から変更） | 既存DDRの根拠の再検証（到達性実測は補強材料） |
| Q2 | `reports/*.html` の既存実物を参照できるか | **参照できない。ただし「存在しない」ことは言えない**（浅いクローン） | 探索範囲の実測 |
| Q3 | `plans/` 側HTMLの命名規則 | **対応する `.md` と同じベース名＋拡張子 `.html`** | 既存機構の実測 |
| Q4 | issue本文の flow-id のずれ | **「5-1（片付け）」は現行 5-4**。他はずれなし | 現行SKILL.mdとの突き合わせ |
| Q5 | 改訂が必要な参照箇所 | 改訂する **11箇所**／ヒットするが改訂しない **6箇所** | パターン7本のgrep（件数を下記に掲載） |
| Q6 | `cleanup-task.sh` は `plans/*.html` を削除するか | **削除する。スクリプト変更は不要** | probeを置いた `--dry-run` の実行 |
| Q7 | `index.jsonl` は `.html` を拾うか | **拾わない**（`.md` のみ） | probeを置いた実行＋実装 |
| Q8 | `HANDOFF.md` のテンプレート外だしを含めるか | **含めない**（DDR `i0028-01` を覆さない） | DDR本文 |
| Q9 | `assets` は既存用法と衝突しないか | **実害のある衝突は無い。ただし語の意味が2つになるため、規約側で書き分ける** | grep＋`git check-ignore` |

---

## Q1. 外部依存方式: TailwindCSS CDN か、自己完結CSSか

### 判断軸（決定規則）

**CDNへの到達性そのものは主根拠にしない。** 到達不可という事実は DDR `i0141-01` が既に記録して
おり、それを知ったうえで同DDRは `reports/` の通常HTMLをCDN方式に据え置いている。同じ事実から
逆の結論を出すことになるため、個別調査計画では判断軸を次の2つに置いた。

1. `i0000-11`（`reports/*.html` にCDNを選んだDDR）の根拠が、**テンプレート化後も成り立つか**。
2. `i0141-01` が canvas を分けた実際の理由（ユーティリティクラスの適用範囲外の描画・
   実行時まで気づけない誤り・検証不能）が、**新設テンプレートにも当てはまるか**。

**決定規則**: 1・2 のいずれかが「CDN不利」と出たら自己完結CSSを採る。どちらも成り立つなら
現行の標準方式（CDN）を維持する。

### 軸1: `i0000-11` の根拠はテンプレート化後も成り立つか

`i0000-11` がCDNを選んだ根拠は2つある。

| `i0000-11` の根拠 | テンプレート化後 |
|---|---|
| (a) ビルドステップ無しで整形できる（Nodeのツールチェーンを持ち込まない） | **成り立つ。ただし自前CSSでも同じ**。`<style>` に直書きするだけでビルドは要らない。`i0000-11` が却下したのは「Tailwindを**ビルドして**同梱する」案であって、CSSを手で書く案ではない |
| (b) 出力トークン量と表現力のバランスが良い | **成り立たない**。テンプレート化後、CSSを書くのは**テンプレートを1回作るとき**だけで、生成側はコピーして本文を差し替える。生成のたびに節約されるトークンは無い |

**根拠(b)が失われる。** 一方、CDN依存のコスト（オフライン・遮断環境で崩れる、
`reports/REVIEW-POINTS.md` が求める「自己完結」を毎回外部依存で満たせない）は生成のたびに残る。
→ **軸1は「CDN不利」。**

なお `i0000-11` は「テンプレート化は行わず、複数件運用してから判断する」とも決めている。
本issueはその保留を解く作業であり、**保留していた判断の中に方式の再確認が含まれる**。

### 軸2: canvas を分けた理由は新設テンプレートにも当てはまるか

`i0141-01` が挙げた3つの理由のうち、新設テンプレートに当てはまるのは1つである。

| `i0141-01` の理由 | 新設テンプレートでの成否 |
|---|---|
| ユーティリティクラスの適用範囲外のスタイル制御（動的z-index・カスタムkeyframes・属性セレクタ）が主体 | **当てはまらない**。一覧・表形式は見出し・表・コードブロック・注意ボックスが中心で、Tailwindの守備範囲に収まる |
| 存在しないクラスが黙って無視され、実行時まで誤りに気づけない | **当てはまる**。テンプレートは一度作れば長く使われるため、この性質は不利に働く |
| CDN遮断環境ではブラウザ実機検証ができない | **当てはまる**（下記の実測） |

→ **軸2も「CDN不利」**（2つが当てはまる）。

### 補強材料: CDN到達性の実測

```
$ curl -sS -o /dev/null -w '%{http_code}\n' --max-time 15 https://cdn.tailwindcss.com
curl: (56) CONNECT tunnel failed, response 403
000
$ curl -sS -o /dev/null -w '%{http_code}\n' --max-time 15 https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js
curl: (56) CONNECT tunnel failed, response 403
000
```

**この結論の主語は「この実行環境のプロキシ経由での到達性」であり、`cdn.tailwindcss.com` の
可用性ではない。** 403 を返しているのはエージェントプロキシである。測った環境は Claude Code
on the web のリモート実行環境1つ（2026-08-22）で、ユーザーの常用環境（Windows / git bash）や、
レビュアーがGitHub上でHTMLを開くブラウザからの到達性は、この測定からは言えない。
同じ遮断は issue #141 対応時にも観測されているので、**この環境では再現性がある**。

### 結論

**新設する2テンプレートは、外部依存を持たない自己完結CSSで作る**（軸1・軸2ともCDN不利）。

- 併せて、`reports/*.html` の方式を「TailwindCSS CDN方式」と書いている既存記述（Q5-2）を、
  テンプレートを正とする書き方へ改める。**方式の正はテンプレートの中身であり、文章側で方式名を
  重複して持たない**（issue #54 が求める「記述の型の正をテンプレートへ一本化する」と同じ考え方）。
- `i0141-01` が置いた限定（「通常の一覧・表形式HTMLは引き続きCDN方式」）は、本issueで上書き
  される。`i0141-01` 自体は canvas 形式についての決定であり、その決定は覆らない。

### 確かめられなかったこと

- **他環境でCDNが到達可能かどうか。** 到達可能な環境が存在すること自体は否定していない。
  本結論は「到達できない環境が実在し、そこで検証も閲覧もできなくなる」ことを軸2の一部として
  用いており、「どこからも到達できない」ことを根拠にしていない。
- **自己完結CSSにした場合の見た目の水準。** テンプレートを書いてブラウザで確認するのは
  フェーズ3の作業である。

### issue本文との差異（要確認事項）

issue #54 本文「期待する動作」は `reports.template.html` を「TailwindCSS CDN通常版」と
書いている。**本調査の結論はこれと異なる。** 受け入れ条件には方式の指定が無いため受け入れ
条件は満たせるが、本文の記述からは外れるため、レビューで差し戻しがあれば方式を戻す。

---

## Q2. 既存の実物レポート

### 探索範囲（先に採った）

```
$ git rev-parse --is-shallow-repository
true
$ git for-each-ref --format='%(refname)'
refs/heads/claude/plan-report-html-template-024l0t
refs/heads/main
refs/remotes/origin/claude/plan-report-html-template-024l0t
refs/remotes/origin/main
```

### 結果

```
$ git log --all --diff-filter=A --name-only -- 'reports/*.html'
（出力なし。件数 0）
```

### 結論

**この作業ツリーからは参照できない。ただし「存在しない」とは言えない。**

- 作業ツリーは**浅いクローン**で、`--all` が走査できるrefは `main` と本ブランチの
  ローカル/リモート計4本しか無い。履歴も切り詰められている。
- したがって0件の原因は、(a) squash merge と flow-id 5-4 の削除により `main` に入らなかった、
  (b) 浅いクローンで見えないだけ、の**どちらとも決められない**。
- 代替手段（クローズ済みPRのdiffをMCPで参照する）は、対象ブランチが削除済みで断面を取得できない
  ため本調査では追わなかった。

**帰結**: テンプレートの必須／任意セクションを「既存3件の共通部分」から導くことはできない。
代わりに、次の2つを根拠に置く。

1. **`reports/REVIEW-POINTS.md` / `plans/REVIEW-POINTS.md` のレビュー観点**。レビュアーが
   実際に確認する項目がそのまま列挙されており、「レビュアーが見るべき場所へ直行できる」という
   issue #54 の狙い2と直接対応する。
2. **`.claude/skills/issue-mr-flow/SKILL.md`「計画と実施結果の分離」の表**（計画＝目的・変更
   対象・方針・やらないこと・検証手順／結果＝実施した内容と結論・根拠・確認結果）。
   フロー定義が既に「何を書くか」を規定しており、テンプレートはそれを見出しへ写せばよい。

---

## Q3. `plans/` 側HTMLのファイル名規則

**結論: 対応する `.md` と同じベース名で、拡張子だけ `.html` にする。**

| md | html |
|---|---|
| `plans/<自動命名>.md`（全体作業計画） | `plans/<自動命名>.html` |
| `plans/【種別】タスク内容.md`（個別計画） | `plans/【種別】タスク内容.html` |

根拠。

- **`reports/` が既にこの規則である**（`reports/日付_…md` と同名 `.html`）。同じ
  「md＝正文／html＝視覚化」の関係に別の命名体系を持ち込む理由が無い。
- **`cleanup-task.sh` は拡張子もファイル名も見ない**（Q6）。
- **`index.jsonl` は `.md` しか拾わない**（Q7）ので、`.html` の名前がインデックスへ影響しない。
- **`.gitignore` に `plans/*.html` を除外する行は無い**（実測）。
- 全角 `【】` を含むファイル名は既に `plans/*.md` で運用されており、`.html` でも同じ制約
  （bashのglobでの文字クラス扱いを避ける）がそのまま当てはまる。

**フェーズ3で守ること**: 全体作業計画のHTMLも「ハーネスが提示した自動命名」に従う。
**AIが別名を付け直さない**（`plans/REVIEW-POINTS.md` の該当観点はHTML側にも効く）。

---

## Q4. issue本文の flow-id と現行フローのずれ

| issue本文の記述 | 現行 `SKILL.md` |
|---|---|
| 「flow-id 5-1 の削除対象に含める」 | **flow-id 5-4**（片付け）。issue #112 の並べ替えと issue #111 の統括レポート追加で繰り下がった |
| 「作成タイミングは flow-id 1-4・2-1・3-1・4-1」 | ずれなし |
| 「HTMLレポートは 2-6 に加えて 3-6・4-6 でも作成する」 | ずれなし |
| 「`start` サブコマンドの手順3」 | ずれなし |

---

## Q5. 改訂が必要な参照箇所（全数）

### パターンごとのヒット件数

除外は `.git/`・`usage/`（セッションログのミラー）・`index.jsonl`・`plans/`（計画自身）。
拡張子による絞り込みはしていない。`reports/` の本レポート自身と `worklog/`・`HANDOFF.md` の
ヒットは、いずれも本作業で生じたもので改訂対象ではない。

| # | パターン | ヒット件数 | 備考 |
|---|---|---|---|
| P1 | `canvas-report/templates` | 3 | 改名で直接効く参照 |
| P2 | `templates/` | 38 | 大半は `.gitlab/issue_templates/` 等の無関係語 |
| P3 | `canvas-report\.html` | 3 | P1と同じ3ファイル |
| P4 | `TailwindCSS\|tailwindcss` | 40 | 内訳は下表 |
| P5 | `自己完結HTML` | 20 | 同上 |
| P6 | `reports/日付` | 20 | レポート作成手順の記述箇所 |
| P7 | `assets` | 57 | Q9の判断材料 |

**0件だったパターンは無い。**

### Q5-1. 改訂する箇所（11箇所）

| # | 箇所 | 理由 |
|---|---|---|
| 1 | `.claude/skills/canvas-report/SKILL.md:123` | テンプレートのコピー元パス（改名） |
| 2 | `.claude/skills/canvas-report/SKILL.md` description・30行目・157-160行目 | HTMLの方式の記述 |
| 3 | `.claude/rules/directory-structure.md:108-109` | バンドルリソースの配置例（`assets/` を既定の例へ） |
| 4 | `.claude/rules/directory-structure.md:74` | `reports/*.html` の説明（方式） |
| 5 | `.claude/rules/docs-workflow.md:26` | ライフサイクル表の `reports/*.html` 行（方式）＋ `plans/*.html` の行を新設 |
| 6 | `.claude/skills/issue-mr-flow/SKILL.md:67`（flow-id 2-6） | 方式＋テンプレート参照 |
| 7 | `.claude/skills/issue-mr-flow/SKILL.md:77`（flow-id 3-6）・`:87`（flow-id 4-6） | HTMLの作成をこの2ステップでも行う旨＋テンプレート参照 |
| 8 | `.claude/skills/issue-mr-flow/SKILL.md:341,356`（計画と実施結果の分離） | 方式 |
| 9 | `.claude/skills/issue-mr-flow/SKILL.md:1232-1235`（flow-id 5-3） | **暫定記述の解除**（下記） |
| 10 | `reports/REVIEW-POINTS.md:31` | 「TailwindCSS CDN以外の外部依存が無いか」 |
| 11 | `.claude/rules/markdown-frontmatter.md` | `plans/*.html` がfrontmatter対象外である旨の明記 |

`index.md:48` と `README.md:50` も `自己完結HTML` を含むが、いずれも方式名を書いていない
（「報告用の自己完結HTML」「報告用自己完結HTMLの格納ディレクトリ」）ため**改訂不要**である。

### Q5-2. ヒットするが改訂しない箇所（6箇所）

**point-in-time の記録であり、書き換えると当時の事実が失われる。**

| # | 箇所 | 種別 |
|---|---|---|
| 1 | `.claude/docs/ddr/i0141-01-…:15,18,29,37` | DDR本文（変更不可。更新してよいのはfrontmatterの `status`/`superseded_by`/`note` のみ） |
| 2 | `.claude/docs/ddr/i0000-11-…:35,57,65` | 同上 |
| 3 | `.claude/docs/ddr/i0087-01-…` | 同上 |
| 4 | `.claude/docs/ddr/i0032-01-…:38` | 同上（GitLab公式ドキュメントのURL。そもそも無関係） |
| 5 | `.claude/docs/spec/issue-mr-workflow.md:2049` | `## 影響範囲` 配下の過去issueのchangelog |
| 6 | `.claude/docs/spec/issue-mr-workflow.md:2652` | 同上 |

**フェーズ3での確認手段**: 改名に伴うパス置換がこれらへ及んでいないことを、
`git diff <ブランチ分岐点のSHA> -- .claude/docs/ddr/` の**削除行が0**であることで確認する
（`.claude/rules/docs-workflow.md` の該当節。issue #24・#47 で実際に起きた事故の再発防止）。

### 重要な発見: flow-id 5-3 が既に本issueの成果物を予約している

`.claude/skills/issue-mr-flow/SKILL.md`（flow-id 5-3 の節）に、次の記述が**既にある**。

> HTMLは `.claude/skills/issue-mr-flow/assets/reports.template.html` を土台にする。
> **このテンプレートは issue #54 の成果物であり、まだ存在しない。存在しない間は、従来どおり
> TailwindCSS CDN方式の自己完結HTMLを手書きしてよい**…テンプレートが入った時点で、土台を
> そちらへ移す。

- **パスまで含めて本issueの成果物と一致している**（`assets/reports.template.html`）。
- **issue #54 本文の「最終統括レポートは作らない」と矛盾しない。** 本文が除外しているのは
  「統括レポート専用のテンプレートを作ること」であって、統括レポートが
  `reports.template.html` を土台にすることは妨げていない（統括レポートも `reports/` 配下の
  レポートの一種である）。
- **フェーズ3の作業に、この暫定記述の解除を必ず含める。** 解除し忘れると、テンプレートが
  存在するのに「まだ存在しない」と書かれた記述が `main` に残る。

---

## Q6. `cleanup-task.sh` は `plans/*.html` を削除するか

probeファイルを置いて `--dry-run` を実行した（後始末は `trap ... EXIT` で保証し、実行後に
`git status --porcelain -- plans reports` で残骸が無いことを確認した）。

```
削除予定: plans/__probe__.html
削除予定: reports/__probe__.html
…
"keptPaths": ["worklog/TEMPLATE.md"], "keptBasenames": ["REVIEW-POINTS.md"]
```

**結論: 削除される。スクリプト自体の変更は不要。** 残すのは `worklog/TEMPLATE.md` と
ベース名 `REVIEW-POINTS.md` のみで、拡張子による分岐は持たない。

---

## Q7. `index.jsonl` は `.html` を拾うか

同じ probe を置いた状態で `bash .claude/scripts/src/extract-frontmatter.sh plans` を実行し、
生成された `plans/index.jsonl` を確認した。

```
plans/index.jsonl 内の __probe__ 件数: 0
```

実装上も、走査対象は `.md` に限られている（`.claude/scripts/src/extract-frontmatter.sh:396`）。

```bash
done < <(git ls-files --cached --others --exclude-standard -z -- "$target_rel" | grep -z '\.md$' | sort -z -u)
```

**結論: 拾わない。** したがって `plans/*.html` は `reports/*.html` と同じく**frontmatter対象外**
であり、`.claude/rules/markdown-frontmatter.md`「typeの値」表への行追加は不要で、対象外である
ことを明記するだけでよい（issue本文の受け入れ条件どおり）。

---

## Q8. `HANDOFF.md` のテンプレート外だしを本issueへ含めるか

issue #28 のマージ前通知（issue #54 へのコメント）が突き合わせを求めていた論点。

DDR **`i0028-01`**「flow-id 5-1の後片付けはスクリプト化しコミットは含めない」の
**却下案 (b)「HANDOFF.mdのテンプレートを別ファイルとして持つ」**が、次の3点を理由に
埋め込みを選んでいる。

1. frontmatterの `type` をどう与えるかという新しい判断が増える
2. `index.jsonl` にテンプレート自身が載る
3. スクリプトからの相対パス解決が要る

**結論: 覆さない（本issueの対象に含めない）。**

決定的な違いは、`i0028-01` が「このテンプレートは**人間が編集して使う雛形ではなく、スクリプトが
書き出す出力そのもの**である」と述べている点にある。本issueが作る2つのHTMLテンプレートは逆で、
**導入先プロジェクトが中身を差し替えて使う雛形**（issue #54 の狙い1「導入先プロジェクトの
拡張点を分離する」）であり、AIエージェントがコピーして本文を埋める。

上記3つの副作用も、HTMLテンプレートには当てはまらない。

| `i0028-01` の副作用 | HTMLテンプレートでの成否 |
|---|---|
| (1) frontmatterの `type` の判断が増える | **当てはまらない**。HTMLはfrontmatterを持たない（Q7） |
| (2) `index.jsonl` に載る | **当てはまらない**（Q7） |
| (3) スクリプトからの相対パス解決が要る | **当てはまらない**。読むのはスクリプトではなくAIエージェントで、SKILL.mdから固定パスで参照する |

---

## Q9. `assets` は既存用法と衝突しないか

### 実測

```
$ git check-ignore -v .claude/skills/issue-mr-flow/assets/x.html
（何にも当たらず終了コード1）
```

`assets` を含む箇所は57件。主な既存用法は次のとおり。

| 箇所 | `assets` の意味 |
|---|---|
| `.claude/skills/apply-mr-workflow-to-project/scripts/sync-assets.sh:12`・`install-to-project.sh:11` | `ASSETS_DIR="${SKILL_DIR}/assets"`。**配布アセットの集約先（ビルド用の一時ディレクトリ）** |
| `.gitignore:9` | 上記を除外（`/.claude/skills/apply-mr-workflow-to-project/assets/`） |
| `.claude/docs/spec/distribution-assets.md` | 配布資産の仕様。用語としての「アセット」 |

### 結論

**実害のある衝突は無い。ただし語の意味が2つになるため、規約側で書き分ける。**

- `.gitignore` の除外行は**先頭スラッシュでパスを固定**しており、
  `.claude/skills/issue-mr-flow/assets/` には当たらない（`git check-ignore` で確認）。
- ただし将来この行が `assets/` のような相対パターンへ書き換えられると、**新設テンプレートが
  無言でGit管理から外れる**。`.claude/rules/directory-structure.md` の改訂で、
  「スキル配下の `assets/` はGit管理下の恒久リソース」「`apply-mr-workflow-to-project/assets/`
  は生成物で `.gitignore` 対象」の2つを**区別して書く**。
- `.claude/rules/directory-structure.md:108-109` は「バンドルリソースは `templates/` のような
  サブディレクトリでよい（実例: `canvas-report/templates/canvas-report.html`）」と**規約として**
  書いている。今回の変更はパス参照の更新ではなく**規約そのものの変更**であり、DDRに残す。
- 配布スクリプトは `cp -R` でスキルディレクトリごとコピーするため、`assets/` の新設で
  `sync-assets.sh` の変更は要らない（実装を確認）。

---

## 設計への反映（フェーズ3で決めること）

1. **テンプレートは自己完結CSS**で書く（Q1）。`<style>` に直書きし、外部リソースを1つも
   参照しない。2ファイルで見た目を揃えるため、CSSは同一の内容を両方へ持たせる
   （共有CSSファイルへ切り出すと「自己完結」でなくなるため、重複を許容する）。
2. **必須／任意セクションの根拠**は `REVIEW-POINTS.md` とSKILL.md「計画と実施結果の分離」の
   表に置く（Q2）。実物の共通部分からは導けない。
3. **`plans/` 側HTMLは md と同名**（Q3）。
4. **flow-id は 5-4 と書く**（Q4）。
5. **改訂対象は Q5-1 の11箇所。Q5-2 の6箇所には触れない。** 改名後に
   `git diff <分岐点SHA> -- .claude/docs/ddr/` の削除行が0であることを確認する。
6. **flow-id 5-3 の暫定記述（「まだ存在しない」）の解除を忘れない**（Q5 の重要な発見）。
7. **`assets` の語を2つの意味で使うことを、`directory-structure.md` で書き分ける**（Q9）。
8. `cleanup-task.sh`・`extract-frontmatter.sh`・`.gitignore`・`sync-assets.sh` は
   **いずれも変更不要**（Q6・Q7・Q9）。

## この調査自身の限界

- Q1 の実測は**この実行環境1つ**での観測であり、結論の主語をそこへ限定している。
- Q2 は**浅いクローン**のため「存在しない」ことを示せていない。
- Q5 の網羅性は**7本のパターンの範囲**である。パターンに現れない言い回し
  （例: 方式名を書かずに「CDN」とだけ書いた箇所）は拾えていない可能性がある。
- **このレポートの `.html` 自体は、現行ルール（CDN方式）から逸脱して自己完結CSSで書いている。**
  この実行環境ではCDNが遮断されており、CDN方式で書くと表示を1度も確認できないまま「視覚化した」
  と称することになるためである。Q1がCDN維持と結論していたら、フェーズ3で書き換える必要があった。
