---
title: 【設計反映】【AIアセット反映】報告サイトのホストとURL通知
type: plan
description: issue #114 フェーズ4の個別反映計画。報告HTMLのホスト機構をspec・DDR・AIアセットへ反映するための、反映先ごとの具体的な変更内容を定める。
tags: [issue-mr-flow, reflection, spec, ddr]
keywords: [issue114, フェーズ4, 設計反映, AIアセット反映, DDR, i0114-01, issue-mr-workflow, gitlab-verification-environment, distribution-assets, shell-scripts, GitHub Pages, GitLab Pages]
---

# 【設計反映】【AIアセット反映】報告サイトのホストとURL通知

- issue: [#114](https://github.com/yuki-matsu783/MR-driven-workflow/issues/114)
- PR: [#180](https://github.com/yuki-matsu783/MR-driven-workflow/pull/180)（Draft）
- 全体作業計画: `plans/binary-soaring-eclipse.md`
- 対象フェーズ: **フェーズ4〈反映〉**（flow-id 4-1〜4-10）

## 前提（合意状況）

- **フェーズ3〈作業〉は完了済み**（flow-id 3-6〜3-9 の1周目を完了、3-10 で MR description を更新）。
  実装・CI設定・テスト・実機検証の結果は
  `reports/20260823_binary-soaring-eclipse_ホスト機構の実装.md` が正文である。
- 敵対的レビューは**フェーズ3で2回**実施し（上限3回）、13件すべてを反映済み。
  **フェーズ4でも計画時1回・作業実施ごと1回、自動実行してMRへ投稿する**（全体作業計画 flow-id 1-4 の合意）。
- **反映のうち1件はフェーズ3から明示的に送られている**——`index.md` と
  `.claude/rules/directory-structure.md` への `.github/workflows/` `.gitlab-ci.yml` の追加
  （フェーズ3の敵対的レビュー指摘）。
- **種別を2つ併記した**のは、spec/DDRへの反映（設計反映）と `rules/` `index.md` への反映
  （AIアセット反映）が、どちらも「issue #114 で決めたことを恒久ドキュメントへ移す」という
  1つの作業だからである。合意の単位が分かれない。**`【実装反映】` は付けない**（実装は
  フェーズ3で完了しており、この反映で変わるコードは無い）。

## この計画で何をするか

issue #114 で決めたこと・作ったもの・踏んだ罠を、**タスク単位で消える成果物**（`plans/`
`worklog/` `reports/`）から、**永続するドキュメント**（`.claude/docs/spec/` `.claude/docs/ddr/`
`.claude/rules/` `index.md`）へ移す。

> **なぜ必要か**: `reports/` は flow-id 5-5 で削除され、squash merge により `main` にも残らない。
> 「なぜ `projects/:id` なのか」「なぜ `exit 0` がガードにならないのか」「なぜ `${v//a/b}` を
> 使わないのか」は、**次に同じ場所へ触る人が最も知りたい情報**でありながら、何もしなければ
> このMRのマージと同時に消える。

## 変更対象

| # | 反映先 | 操作 | 何を書くか |
|---|---|---|---|
| 1 | `.claude/docs/ddr/i0114-01-….md` | **新規** | ホスティング手段とタイミングの選定、および却下案 |
| 2 | `.claude/docs/README.md` | 変更（**生成**） | `generate-ddr-list.sh` の再実行結果 |
| 3 | `.claude/docs/spec/issue-mr-workflow.md` | 変更 | 提供関数の表に2行／新節「報告サイトのホストとURL通知」／`影響範囲` へ issue #114 のエントリ |
| 4 | `.claude/docs/spec/gitlab-verification-environment.md` | 変更 | **GitLab Runner の構築手順**と、そこで踏んだ落とし穴 |
| 5 | `.claude/docs/spec/distribution-assets.md` | 変更 | CI設定を配布しない判断／生成物・ローカル状態の一括除去 |
| 6 | `.claude/docs/spec/shell-scripts.md` | 変更 | `curl` 依存の追記 |
| 7 | `.claude/rules/shell-script-style.md` | 変更 | **bash 5.2 の `patsub_replacement`** の罠 |
| 8 | `.claude/rules/directory-structure.md` | 変更 | `.github/workflows/` と `.gitlab-ci.yml` をツリーへ |
| 9 | `index.md` | 変更 | 同上（Repository Map の行を追加） |
| 10 | `.claude/skills/adversarial-review/SKILL.md` | **変更しない**（下記「やらないこと」） | — |

### 1. DDR `i0114-01`（新規）

**識別子**: `i0114-01`（issue番号4桁ゼロ埋め＋枝番2桁。このissueで作るDDRは1件）。

| 節 | 書く内容 |
|---|---|
| 決定 | 報告HTMLは**CIでPR/MR単位のサブパスへデプロイし、flow-id 5-4 でホスト・5-6 で通知する**。GitHubは `gh-pages` の `pr-<n>/`、GitLabは Pages parallel deployments の `mr-<iid>/` |
| なぜタイミングが 5-4 なのか | 5-5 で `reports/` が消えるため、5-6 の時点では対象ファイルが無い。**案(a) 不変パス・案(c) SHA指定**を却下した理由も書く |
| なぜその手段なのか | 却下案4つ（raw.githubusercontent.com／Actions artifact／`upload_attachment`／外部ホスティング）と、それぞれの却下理由 |
| 受け入れた代償 | (1) private リポジトリでも GitHub Pages は**公開される**（Enterprise Cloud 以外にアクセス制御が無い）、(2) fork からのPRでは動かない、(3) `gh-pages` の掃除を持たない、(4) GitLab の並列デプロイは Premium/Ultimate 限定 |
| 失敗を正常系として扱う設計 | `upload_attachment` と同じ扱いにした理由 |

**本文には「実装がどうなっているか」を書かない**（それは spec の担当）。書くのは
**なぜそれを選び、何を捨てたか**である。

### 2. `.claude/docs/README.md`（生成）

```bash
bash .claude/scripts/src/generate-ddr-list.sh
```

**手書きしない。** 出た差分を同じコミットへ含める。

### 3. `.claude/docs/spec/issue-mr-workflow.md`

| 箇所 | 変更 |
|---|---|
| `### 提供関数` の表 | `get_report_site_url [<n>]` と `wait_for_report_site <url> [<上限秒>] [<間隔秒>]` の2行。GitHub実装／GitLab実装の列も埋める。**`wait_for_report_site` はプロバイダ非依存（`—`）であり、`require_vcs_cli` を通らない**ことを明記する |
| 新節 `### 報告サイトのホストとURL通知（issue #114）` | 「最終統括レポートとPR/MRへの反映（issue #111）」の**直後**へ置く（flow-id 5-4 の話が続くため）。CI設定の置き場・デプロイ先のパス規約・0件ガード・失敗を正常系とする扱い・配布先での設定・**実機検証で確かめた範囲と確かめていない範囲** |
| `## 影響範囲` | `### issue #114（報告サイトのホストとURL通知）` を**新規エントリとして追記**する。**既存のエントリは1行も書き換えない**（point-in-time の記録であるため） |

**`SKILL.md` との重複に注意する。** 手順の正は `SKILL.md`、仕組みと判断の正は spec、という
現行の切り分けを崩さない（`SKILL.md` の記述をコピーしない）。

### 4. `.claude/docs/spec/gitlab-verification-environment.md`

**`## 手順` のコードブロックへ、Runner の登録を追記する**（現在は 1〜5 のみで Runner が無い）。

| 追記する内容 |
|---|
| `gitlab-net` ネットワークの作成と、GitLab コンテナの接続 |
| `gitlab/gitlab-runner` コンテナの起動（`-v //var/run/docker.sock:/var/run/docker.sock`。**`MSYS_NO_PATHCONV=1` をサブシェルへ閉じ込める**） |
| `POST /user/runners`（`runner_type=project_type`）による認証トークンの取得 |
| `config.toml` への `clone_url` 追記（コンテナ間はホスト名 `gitlab` で解決するため） |

`## 実際に踏んだ落とし穴` へは次を足す。

- **`docker run -v /var/run/docker.sock:…` が `mkdir C:\Program Files\Git\var: Access is denied` になる**
  （MSYSのパス変換）。`//var/run/…` と `MSYS_NO_PATHCONV=1` の使い分け。
- **`glab api` が `wsarecv: An existing connection was forcibly closed` で断続的に落ちる**
  （`localhost` → `[::1]`）。`127.0.0.1` を明示する回避。
- **`projects/<group>/<repo>` は存在しないルートである**（`%2F` が要る）。**404のレスポンスの形が
  2種類ある**（`{"message":…}` はリソースが無い／`{"error":…}` はルートが無い）ことを、
  切り分けの道具として書く。

### 5. `.claude/docs/spec/distribution-assets.md`

| 箇所 | 変更 |
|---|---|
| `### 配布経路での扱い` | **CI設定（`.github/workflows/` `.gitlab-ci.yml`）は配布しない**という判断と理由。雛形を `.claude/skills/issue-mr-flow/assets/` へ置き、`.claude/` ごと配ることで代替している点 |
| 同上 | **生成物・ローカル作業状態は、集め終えたあとに一括で除去する**（`index.jsonl` ／ `.claude/state/`）。**コピーの各所で個別に弾く形は取りこぼす**という教訓 |
| `## 影響範囲` | `### issue #114` を新規エントリとして追記 |

### 6. `.claude/docs/spec/shell-scripts.md`

`### 前提（新規追加）` へ **`curl`** を足す。「`wait_for_report_site` のみ。無い場合は到達性確認を
スキップする」という限定と、**`AGENTS.md` の「curlへフォールバックしない」の対象外である理由**
（API情報取得ではないため）を併記する。

### 7. `.claude/rules/shell-script-style.md`

**`## 文字コード` の近く**（`sed`/`awk` のエスケープの罠が既にある場所）へ、次を足す。

> **bash の `${v//a/b}` の置換文字列に `&` を書かない。** bash 5.2 から `&` が
> 「マッチした文字列全体」へ展開される（`patsub_replacement`、既定で有効）。`\&` での退避は
> 5.1 以前と互換でない。**`sed` を使う**（`&` の意味も `\&` での退避も処理系をまたいで定まっている）。

実例（`esc="${esc//</&lt;}"` が `<lt;` になる）と、CI の shell が bash とも限らない点を添える。

### 8・9. `.claude/rules/directory-structure.md` と `index.md`

`.github/workflows/`（GitHub Actions ワークフロー）と `.gitlab-ci.yml`（GitLab CI 設定）を、
それぞれのツリー／Repository Map へ追加する。**どちらも「雛形は
`.claude/skills/issue-mr-flow/assets/` 側にあり、実ファイルとバイト一致する」**ことに触れる
（片方だけ直すと、次に読んだ人がどちらが正か分からない）。

## 方針

- **反映先ごとに「正はどこか」を先に決めてから書く。** 同じことを2箇所へ書かない。
  手順は `SKILL.md`、仕組みと判断は `spec`、選定の経緯と却下案は `DDR`、コーディング上の罠は
  `rules`、という現行の切り分けに従う。
- **`## 影響範囲` の既存エントリと DDR の本文は1行も書き換えない。** どちらも point-in-time の
  記録であり、`.claude/rules/docs-workflow.md` が書き換えを禁じている。追記のみ行う。
- **`reports/` の文章をそのまま貼らない。** レポートは「このタスクで何が起きたか」の記録、
  spec は「いま何がどうなっているか」の記述で、時制も主語も違う。

## やらないこと（スコープ外）

- **`.claude/skills/adversarial-review/SKILL.md` の起動ポリシーの恒久化。** 全体作業計画は
  反映候補に挙げているが、**本ブランチでの上書きはユーザーの明示指示による1回限りの判断**で
  あり、恒久ルールにしてよいかは別途合意が要る。**この判断自体を `HANDOFF.md` の
  「判断を迷った内容」へ残し、別issueの候補とする。**
- **`gh-pages` の掃除の仕組み**（残課題として記録済み。別issue候補）。
- **GitLab の Pages 配信・`path_prefix`・`expire_in: never` の実機検証。** 前者はコンテナの
  作り直しが要り、後の2つは Premium/Ultimate 限定である。**spec には「確かめていない」と書く**
  （確かめたかのように書かない）。
- **`main` 由来の既存テスト失敗3件の修正**（全体作業計画でスコープ外と合意済み）。

## 検証

```bash
# DDRを足したら一覧を再生成し、差分を同じコミットへ含める
bash .claude/scripts/src/generate-ddr-list.sh

# frontmatterインデックスの再生成（新規DDRが載ることの確認）
bash .claude/scripts/src/extract-frontmatter.sh .

# DDR識別子の重複が無いこと
bash .claude/scripts/test/test_check_base_conflicts.sh

# 反映で壊していないこと（フェーズ3と同じ基準）
bash .claude/scripts/test/test_vcs_provider.sh
```

**合格条件**:
(1) DDR `i0114-01` が存在し、frontmatter の `title` / 本文冒頭の見出し / ファイル名の識別子が揃っている、
(2) `.claude/docs/README.md` の DDR 一覧が**生成物として**更新されている（手書きの行が無い）、
(3) 上表 3〜9 の反映が入っている、
(4) **`## 影響範囲` の既存エントリと既存DDRの本文に差分が無い**
（`git diff <分岐点> -- .claude/docs/ddr/` の削除行がゼロ）、
(5) `test_vcs_provider.sh` が `failures=0`、他のテストが着手時点と同じ結果、
(6) 敵対的レビュー（フェーズ4）の指摘へ対応・返信済みで、返信ゼロのスレッドが0件。

## 比較検討した案

| 論点 | 採用 | 却下した案と理由 |
|---|---|---|
| DDRの粒度 | **1件（`i0114-01`）にまとめる** | 「手段の選定」と「タイミングの選定」で2件に分ける案。**この2つは独立して決められない**（5-5 で消えるという制約が手段の選択肢を絞り、手段の性質がタイミングの可否を決める）ため、分けると片方だけ読んでも判断が再現できない |
| `index.md` / `directory-structure.md` の扱い | **フェーズ4で反映する** | フェーズ3で直す案。**ディレクトリ構成の記述はAIアセットであり、反映はフェーズ4の担当**という現行の切り分けに従った（フェーズ3で直すと、反映の一覧がどこにも残らない） |
| 敵対的レビューの起動ポリシー | **恒久化しない** | `adversarial-review/SKILL.md` へ例外を書く案。**1ブランチでの運用実績しかない**段階で既定を変えると、次のissueが暗黙にこの運用を引き継ぐ。判断は `HANDOFF.md` へ残して別issueにする |
