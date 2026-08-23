---
title: 【全体作業計画】報告HTMLをホストしURLをマージ依頼時に通知する（issue #114）
type: plan
description: reports/配下の報告HTMLをGitLab Review Apps／GitHub Pagesでホストし、マージ依頼時にURLをユーザーへ提示する機能を追加するための全体作業計画。
tags: [issue-mr-flow, hosting, review-apps, github-pages]
keywords: [issue114, flow-id 5-4, flow-id 5-6, reports, 報告HTML, Review Apps, GitHub Pages, Provider.sh, publish, URL通知, gitlab-runner]
---

# 【全体作業計画】報告HTMLをホストしURLをマージ依頼時に通知する（issue #114）

- issue: [#114](https://github.com/yuki-matsu783/MR-driven-workflow/issues/114)
- PR: [#180](https://github.com/yuki-matsu783/MR-driven-workflow/pull/180)（Draft）
- ブランチ: `feature-114-host-report-html-and-notify-url`
- ベースブランチ: `main`（flow-id 1-3 で確認済み）

## 前提（合意状況）

- issue [#114](https://github.com/yuki-matsu783/MR-driven-workflow/issues/114) の本文
  （目的・現状・期待する動作・受け入れ条件の4見出しは充足）
- ベースブランチを `main` とすることは **flow-id 1-3** でユーザーが確認済み
- issue を分割せず1件で進めることは **flow-id 1-4** でユーザーが判断（下記「方針」）
- **ホストするタイミングは案(b)** — 最終統括レポートのステップ（現行 **flow-id 5-4**）でホストし、
  マージ依頼のステップ（現行 **flow-id 5-6**）では**通知のみ**行う。**flow-id 2-4（レビュー
  1周目）でユーザーが判断**（下記「フェーズ2〈調査〉」問い1）
- **まだ合意されていない**: 手段の選定（GitLab / GitHub それぞれ何でホストするか）は未確定で、
  フェーズ2〈調査〉で決める

### issue 起票後に前提が変わっている

**flow-id の番号は #111・#112・#157 の3回で繰り下がっている。** issue 本文および本計画の
flow-id 2-2 時点の記述は、いずれも古い番号を指している。以降は下表の**現行**列を使う。

| 対象のステップ | issue 本文の記述 | 現行 |
|---|---|---|
| 最終統括レポートの作成・commit・push | （issue 起票時は存在しない） | **5-4** |
| `reports/` の削除（片付け） | 5-1 | **5-5** |
| Draft解除＝マージ依頼 | 5-4 | **5-6** |
| （#157 で新設）`.gemini/` への変換同期 | — | 5-3 |

| そのほかの変化 | 内容 |
|---|---|
| **PR/MR上に統括が残るようになった**（#111） | flow-id 5-4 のサマリコメントと、層3の `upload_attachment` によるHTML添付が既にある。**ただし添付は「ダウンロードできる」であって「ブラウザで開ける」ではない**ため、#114 の目的は解消されていない |
| **HTMLビューがテンプレート化された**（#54・#156） | `plans/` にもHTMLビューが付いた。ホスト対象を `reports/` に限るかは設計判断になる（フェーズ2で決める） |

## この計画で何をするか

`reports/日付_<全体計画名>_<内容>.html` をブラウザで開けるURLとして払い出す仕組みを作り、
**最終統括レポートのステップ（flow-id 5-4）でホストし、マージ依頼のステップ（flow-id 5-6）で
そのURLをユーザーへ提示する**。払い出しは `Provider.sh` の共通インターフェースへ載せ、
GitLab / GitHub の差異を吸収する。

> **なぜ必要か**: 報告HTMLは flow-id 5-5 で削除され、squash merge により `main` にも残らない。
> レビュー期間中でさえ、ブラウザで開くには clone するか raw 表示を経由する必要があり、GitHub の
> raw は HTML を `text/plain` で返すためレンダリングされない。**最も読んでほしいタイミングで、
> 最も読みやすい成果物が URL 1つで開けない。**

## 変更対象

全体作業計画のため、ファイル単位ではなく領域の粒度で示す。個別のファイル・行はフェーズごとの
個別計画で確定させる。

| 領域 | 操作 | 何をするか |
|---|---|---|
| `.claude/scripts/src/vcs/`（`Provider.sh` / `Github.sh` / `Gitlab.sh`） | 変更 | 報告HTMLをホストしURLを返す関数を追加する。既存の `upload_attachment` と同じく**失敗を正常系のひとつ**として扱い、非0終了で呼び出し側がスキップできる形にする。MCP経路のヒント（`mcp_tool_hint`）も揃える |
| `.gitlab-ci.yml` / `.github/workflows/` | 新規 | Review Apps / Pages デプロイの定義。どちらもこのリポジトリには現存しない |
| `.claude/skills/apply-mr-workflow-to-project/scripts/` | 変更（見込み） | CI設定を配布資産に**含めない**と決めた場合、`sync-assets.sh` の `.github/` 一括コピーから除外する実装が要る（下記「フェーズ2〈調査〉」問い4） |
| `.claude/skills/issue-mr-flow/SKILL.md` | 変更 | flow-id **5-4** へホスト、**5-6** へ通知を組み込む |
| `.claude/scripts/test/test_vcs_provider.sh` | 変更 | 追加関数の純粋ロジック（対象ファイルの選択・URL組み立て・早期リターン）の単体テスト |
| `.claude/docs/spec/` / `.claude/docs/ddr/` | 変更・新規 | フェーズ4で反映する（下記） |

**最新の報告HTMLの検出**は、既存の `get_branch_work_files`（ブランチ固有の `plans/` `worklog/`
`reports/` を返す。プロバイダ非依存）を再利用できないか最初に確認する。

## 方針

新しい仕組みを独立して足すのではなく、**既存の `Provider.sh` 抽象と flow-id 5-4 の3層
フォールバック構造に合わせる**。ホスティングは外部環境（CI・Pages・Runner）に依存し、配布先で
必ず動くとは限らないため、**失敗してもフローが止まらない**ことを設計の前提に置く。

### この計画で決めた前提（レビューで覆してよい）

| 論点 | 決定 | 合意した flow-id | 根拠 |
|---|---|---|---|
| issue 分割 | **分割せず1件で進める** | **1-4** | 「GitLab / GitHub」は外部連携先の並列列挙に当たるが、先例として #111 の `upload_attachment` も両プロバイダを1 issue で実装している。Provider.sh の抽象は両者が揃って初めて意味を持ち、5フェーズ43ステップの固定費を二重に払う規模ではない |
| ホストするタイミング | **案(b)**: flow-id **5-4** でホスト、**5-6** で通知のみ | **2-4**（レビュー1周目） | 下記「フェーズ2〈調査〉」問い1 |
| 敵対的レビュー | 各フェーズの計画時に1回、作業実施ごとに1回、自動実行しMRへインライン投稿する | **1-4** | ユーザーからの明示指示（下記の注意書きも参照） |
| GitHub 側の実機検証 | GitHub Pages を**有効化して実機検証まで行う** | **1-4** | リポジトリは Public のため有効化可能（現状は未有効で API が404） |
| GitLab 側の実機検証 | GitLab Runner を**立てて実機検証まで行う** | **1-4** | 既存の検証環境（`gitlab-verification-environment.md`）に Runner は含まれていないため、その構築も作業に含める |

> **敵対的レビューの運用は、スキルの既定を本ブランチに限り上書きしている。**
> `.claude/skills/adversarial-review/SKILL.md` は「実行モードの判断（起動ポリシー・絶対ルール）」で
> (1) 対話モードでのAIによる自律起動を禁じ、(2) どちらのモードでも投稿の可否を手順3で毎回確認する
> ことを求めている。本ブランチは**ユーザーの明示指示（flow-id 1-4）**により、(1) を自動起動へ、
> (2) をこの計画への合意1回へ集約する形で上書きする。**恒久化するならスキル側へ例外を書く**
> （フェーズ4の反映候補）。
>
> **上書きしても、実施回数の上限は外れない。** 同スキル手順1は**各フェーズ最大3回**と定め、
> `.claude/scripts/src/adversarial-review-count.sh` が機械的に強制する（カウンタは投稿の成否に
> 関わらず加算される）。レビュー往復が重なって上限に達した場合は、**レビューを実行せずに打ち切り、
> その事実を報告して人間のレビューへ委ねる**。`reset` はAIから提案しない。

## フェーズ2〈調査〉

**実施する。** 実装方針を決めるために解かねばならない問いが、少なくとも4つ残っている。

**問い1: タイミングの矛盾 — 案(b)で確定済み（flow-id 2-4）**

現行のフロー順は **5-4（統括レポート作成・commit・push）→ 5-5（`reports/` 削除）→ 5-6
（commit・push・Draft解除＝マージ依頼）** である。「マージ依頼時にホストする」を素直に実装すると
対象ファイルが既に無い。ユーザーの判断により、次の**案(b)**を採る。

- **(a) 不変パス**: CI が push ごとにデプロイし、デプロイ先をコミットSHA単位の不変パスにする
- **(b) 5-4でホスト**（**採用**）: ホスト自体を flow-id 5-4 で行い、5-6 では**通知のみ**行う
- **(c) SHA指定**: 5-6 で、削除前のコミット（5-4 のSHA）をCIへ明示的に指定してデプロイさせる

調査では**案の選定そのものは行わず**、次の2点だけを確かめる。

1. **案(b)が成立する条件**（5-4 の push を CI がどう捉えるか、5-5 の削除pushが既にホストされた
   内容を壊さないか、5-6 でURLをどう取得するか）
2. **(a)(c) を却下した理由の裏取り**（DDRへ残すため。推測のまま却下理由にしない）

あわせて、**`plans/` のHTMLビューをホスト対象に含めるか**を決める（上位の判断として本フェーズへ
送られている）。

**問い2: GitHub の代替手段の選定**

GitHub Pages（Actions で `pr-<番号>/` サブパスへデプロイ）を第一候補として、次を**一次情報
（公式ドキュメント）で**確認する。

- Pages は1リポジトリ1サイトである制約下で、PRごとの並列プレビューをどう表現するか
- Actions のデプロイ完了をどう待ち、URLをどう取得するか
- fork からのPRで `GITHUB_TOKEN` の書き込み権限が落ちる問題の有無
- Pages 有効化に必要な操作（API で可能か、Web UI が必須か）
- **払い出されるURLの閲覧可能範囲が、リポジトリの可視性設定と一致するか**（private リポジトリで
  何が起きるか。issue の受け入れ条件「プロジェクトの可視性設定に従う」は、**選ぶ手段によっては
  満たせない**要件である）

**却下候補は、却下理由つきで必ず記録する**（後で「なぜそれを使わないのか」を再検討しないため）。

| 却下候補 | 想定される却下理由（調査で裏を取る） |
|---|---|
| raw.githubusercontent.com | HTML を `text/plain` で返しレンダリングされない |
| Actions artifact | ダウンロードのみ。ブラウザで開けない・ログインが要る |
| `upload_attachment`（既存の層3） | 添付はダウンロード用。#114 の「ブラウザで開ける」を満たさない |
| 外部ホスティング（Netlify等） | リポジトリ外のアカウント・シークレットが要り、配布物として成立しない |

**問い3: GitLab Review Apps の必要条件**

- `.gitlab-ci.yml` の `environment.name`（動的環境名）・`environment.url`・`on_stop` の書き方
- **ホストの実体**（GitLab Pages を使うか、Runner 上の静的サーバか）と、それぞれの前提
- **GitLab Runner の構築手順**（executor の選定・Docker版 GitLab CE への登録）
- 払い出された URL を `glab` から取得する方法
- **払い出されるURLの閲覧可能範囲が、プロジェクトの可視性設定と一致するか**。とくに
  「Runner 上の静的サーバ」を選ぶとホスト先がGitLabのアクセス制御の外になり、**private
  プロジェクトの成果物が無認証で公開されうる**

**問い4: 配布物としての扱い**

`.gitlab-ci.yml` / `.github/workflows/*.yml` は Claude Code の plugin 配布（`.claude/` 一式）の
対象外である。**しかし `apply-mr-workflow-to-project` の配布経路では既に配布対象に入りうる**:
`sync-assets.sh` は `cp -R "${PROJECT_ROOT}/.github/"* "${ASSETS_DIR}/.github/"` で `.github/` 配下を
**丸ごと** `assets/` へ集め、`install-to-project.sh` が `safe_copy_dir` で配布先へ展開する。
つまり `.github/workflows/*.yml` を置いた瞬間、**何も設定しなくても配布資産に載る**。

- CI設定を配布資産に**含めるか／含めないか**
- **含めないと決めた場合、`sync-assets.sh` / `install-to-project.sh` のどこで除外するか**
  （「含めない」は何もしなければ実現されない）
- 含める場合、**配布先が既にCI設定を持っているときに壊さない**方法（`.gitattributes` の
  `dist:begin`〜`dist:end` 方式が参考になる）

**成果物**: `reports/日付_binary-soaring-eclipse_ホスティング手段の比較.md`（正文）と同名の
`.html`（土台は `reports.template.html`。選択肢の比較が主題であり要素間の依存関係が主題では
ないため、canvas形式は使わない見込み）。

## フェーズ4〈反映〉

**必ず通る。** 反映対象は flow-id 4-1 で洗い出すため、ここでは候補に留める（確定した反映内容と
して書かない）。

| 反映先 | 候補 |
|---|---|
| `.claude/docs/spec/issue-mr-workflow.md` | 提供関数の表へ追加関数の行、flow-id 5-4／5-6 の節、配布物としてのCI設定の扱い |
| `.claude/docs/spec/gitlab-verification-environment.md` | GitLab Runner の構築手順と、実際に踏んだ落とし穴 |
| `.claude/docs/spec/distribution-assets.md` | CI設定を配布資産に含める／含めない場合の追記 |
| `.claude/skills/adversarial-review/SKILL.md` | 起動ポリシー・投稿可否確認の上書きを恒久化する場合の例外 |
| `.claude/docs/ddr/i0114-01-….md` | ホスティング手段とタイミングの選定、および却下案。**枝番は 01 から。追加したら `bash .claude/scripts/src/generate-ddr-list.sh` を実行し、`.claude/docs/README.md` の差分を同じコミットへ含める** |
| AIアセット（`.claude/rules/` `.claude/skills/` `AGENTS.md`） | 作業中に気づいた不備があれば |

## やらないこと（スコープ外）

- ホストしたHTMLの**公開範囲・寿命の制御**（認証・自動失効等）。issue の受け入れ条件どおり、
  プロジェクトの可視性設定に従う（判断はissue本文で確定済み）。**ただし「可視性設定に従えるか」の
  確認は行う**（問い2・問い3）。制御を追加しないことと、確認しないことは別である
- 既存の flow-id 5-4 層3（`upload_attachment`）の**置き換え**。添付とホスティングは目的が違う
  ため併存させる
- `reports/` の削除タイミング（flow-id 5-5）そのものの変更。案(b)は削除位置を動かさずに成立する
- **`main` 由来の既存テスト失敗3件の修正**（`test_block_direct_git_commit.sh` 1件・
  `test_command_position.sh` 2件）。本issueの変更と無関係であり、別issueへ切り出す

## 検証

issue #114 の受け入れ条件に対応させる。コマンド単位の検証はフェーズごとの個別計画で確定させる。

```bash
# 回帰（追加関数の純粋ロジック）
bash .claude/scripts/test/test_vcs_provider.sh

# 実機（GitHub）: Pages を有効化したうえで、デプロイ結果のURLをブラウザで開く
gh api repos/yuki-matsu783/MR-driven-workflow/pages

# 実機（GitLab）: Docker版 GitLab CE に Runner を登録し、Review Apps の environment URL を開く
docker exec gitlab-runner gitlab-runner list
```

**合格条件**:
(1) GitHub でデプロイされたURLがブラウザで開ける、
(2) GitLab で Review Apps として同じことができる、
(3) flow-id 5-4 でホストされ、5-6 の実行時にURLがユーザーへ提示される、
(4) `test_vcs_provider.sh` が `failures=0`、かつ `.claude/scripts/test/` の既存テストが
**本ブランチ着手時点と同じ結果**（`main` 由来の3件を除き緑）、
(5) 手順が SKILL.md の flow-id 5-4・5-6 と spec/DDR に反映されている、
(6) 認証・自動失効等の追加制御を入れていない。

## issueの受け入れ条件との対応

| 受け入れ条件 | この計画での対応箇所 |
|---|---|
| GitLab運用で flow-id 5-4 を実行すると、`reports/` 配下の最新の報告HTMLが CI/CD Review Apps としてデプロイされ、そのURLがユーザーへ提示される | フェーズ2 問い1・問い3 → 変更対象「CI設定」「フロー定義」。**issue本文の「flow-id 5-4」は現行の 5-6（マージ依頼）を指す。ホスト自体は現行の 5-4 で行う**（上記「issue 起票後に前提が変わっている」） |
| GitHub運用でも代替のホスティング手段により同様にURLが提示される仕組みが用意されている | フェーズ2 問い2 → 変更対象「Provider抽象」「CI設定」 |
| ホスティングの手順が SKILL.md の flow-id 5-4、および関連する spec/ddr に反映されている | 変更対象「フロー定義」＋フェーズ4〈反映〉 |
| 公開範囲・寿命について追加の認証・自動失効等の制御は行わない | 「やらないこと（スコープ外）」に明記。検証の合格条件(6)で確認する |
