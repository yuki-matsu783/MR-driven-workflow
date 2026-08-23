---
title: 【全体作業計画】報告HTMLをホストしURLをマージ依頼時に通知する（issue #114）
type: plan
description: reports/配下の報告HTMLをGitLab Review Apps／GitHub Pagesでホストし、マージ依頼時にURLをユーザーへ提示する機能を追加するための全体作業計画。
tags: [issue-mr-flow, hosting, review-apps, github-pages]
keywords: [issue114, flow-id 5-5, reports, 報告HTML, Review Apps, GitHub Pages, Provider.sh, publish, URL通知, gitlab-runner]
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
- **まだ合意されていない前提**: ホスティング手段の選定・ホストするタイミングは未確定で、
  フェーズ2〈調査〉で決める

### issue 起票後に前提が変わっている

| 変化 | 内容 |
|---|---|
| **flow-id の番号がずれている** | issue 本文の「flow-id 5-4（Draft解除・マージ依頼）」は現在の **5-5**、「flow-id 5-1 で削除される」は現在の **5-4**（#111・#112 の並べ替えによる） |
| **PR/MR上に統括が残るようになった**（#111） | flow-id 5-3 のサマリコメントと、層3の `upload_attachment` によるHTML添付が既にある。**ただし添付は「ダウンロードできる」であって「ブラウザで開ける」ではない**ため、#114 の目的は解消されていない |
| **HTMLビューがテンプレート化された**（#54・#156） | `plans/` にもHTMLビューが付いた。ホスト対象を `reports/` に限るかは設計判断になる |

## この計画で何をするか

`reports/日付_<全体計画名>_<内容>.html` をブラウザで開けるURLとして払い出す仕組みを作り、
マージ依頼のタイミング（現行 flow-id **5-5**）でそのURLをユーザーへ提示する。払い出しは
`Provider.sh` の共通インターフェースへ載せ、GitLab / GitHub の差異を吸収する。

> **なぜ必要か**: 報告HTMLは flow-id 5-4 で削除され、squash merge により `main` にも残らない。
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
| `.claude/skills/issue-mr-flow/SKILL.md` | 変更 | ホストと通知を flow-id のどこへ置くかを組み込む（5-3 と 5-5 の分担は調査1の結論次第） |
| `.claude/scripts/test/test_vcs_provider.sh` | 変更 | 追加関数の純粋ロジック（対象ファイルの選択・URL組み立て・早期リターン）の単体テスト |
| `.claude/docs/spec/` / `.claude/docs/ddr/` | 変更・新規 | フェーズ4で反映する（下記） |

**最新の報告HTMLの検出**は、既存の `get_branch_work_files`（ブランチ固有の `plans/` `worklog/`
`reports/` を返す。プロバイダ非依存）を再利用できないか最初に確認する。

## 方針

新しい仕組みを独立して足すのではなく、**既存の `Provider.sh` 抽象と flow-id 5-3 の3層
フォールバック構造に合わせる**。ホスティングは外部環境（CI・Pages・Runner）に依存し、配布先で
必ず動くとは限らないため、**失敗してもフローが止まらない**ことを設計の前提に置く。

### この計画で決めた前提（レビューで覆してよい）

| 論点 | 決定 | 根拠 |
|---|---|---|
| issue 分割 | **分割せず1件で進める** | 「GitLab / GitHub」は外部連携先の並列列挙に当たるが、先例として #111 の `upload_attachment` も両プロバイダを1 issue で実装している。Provider.sh の抽象は両者が揃って初めて意味を持ち、5フェーズ42ステップの固定費を二重に払う規模ではない |
| 敵対的レビュー | 各フェーズの計画時に1回、作業実施ごとに1回、自動実行しMRへインライン投稿する | ユーザーからの明示指示。`adversarial-review` スキル手順3の投稿可否確認は、この計画への合意をもって1回に集約する |
| GitHub 側の実機検証 | GitHub Pages を**有効化して実機検証まで行う** | ユーザー判断。リポジトリは Public のため有効化可能（現状は未有効で API が404） |
| GitLab 側の実機検証 | GitLab Runner を**立てて実機検証まで行う** | ユーザー判断。既存の検証環境（`gitlab-verification-environment.md`）に Runner は含まれていないため、その構築も作業に含める |

## フェーズ2〈調査〉

**実施する。** 実装方針を決めるために解かねばならない問いが、少なくとも4つ残っている。

**問い1（最重要）: タイミングの矛盾をどう解くか**

flow-id **5-4 で `reports/` は削除され**、その後の **5-5 が Draft解除＝マージ依頼**である。
「マージ依頼時にホストする」を素直に実装すると、**ホストすべきファイルが既に存在しない**。

- (a) CI が push ごとにデプロイし、デプロイ先を**コミットSHA単位の不変パス**にする。5-4 の削除
  pushは新しい空デプロイを作るだけで、5-3 時点のデプロイは残る。5-5 では「最後に中身のあった
  デプロイ」のURLを提示する
- (b) ホスト自体を **flow-id 5-3**（統括レポートのcommit・push）で行い、5-5 では**通知のみ**行う
- (c) 5-5 で、削除前のコミット（5-3 のSHA）をCIへ明示的に指定してデプロイさせる

**問い2: GitHub の代替手段の選定**

GitHub Pages（Actions で `pr-<番号>/` サブパスへデプロイ）を第一候補として、
(i) 「1リポジトリ1サイト」制約下でPRごとの並列プレビューをどう表現するか、
(ii) デプロイ完了をどう待ちURLをどう取得するか、
(iii) fork からのPRで `GITHUB_TOKEN` の権限が落ちる問題の有無、を確認する。
**却下候補（raw は `text/plain`、Actions artifact はダウンロードのみ、`upload_attachment` も
同様）は却下理由つきで記録する。**

**問い3: GitLab Review Apps の必要条件**

`environment.url` と `on_stop` の書き方、動的環境名の付け方、**GitLab Runner の構築手順**
（executor の選定・Docker版 GitLab CE への登録）、ホストの実体（GitLab Pages か Runner 上の
静的サーバか）。

**問い4: 配布物としての扱い**

このリポジトリは `.claude/` 一式を他プロジェクトへ配布するテンプレートである。`.gitlab-ci.yml` /
`.github/workflows/*.yml` は `.claude/` の外に置かれるため、`distribution-assets.md` の配布資産に
含めるべきかを決める（`.gitattributes` の `dist:begin`〜`dist:end` 方式が参考になる）。
**配布先が既にCI設定を持っている場合に壊さない**方法もここで決める。

**成果物**: `reports/日付_binary-soaring-eclipse_ホスティング手段の比較.md`（正文）と同名の
`.html`（土台は `reports.template.html`。選択肢の比較が主題であり要素間の依存関係が主題では
ないため、canvas形式は使わない見込み）。

## フェーズ4〈反映〉

**必ず通る。** 反映対象は flow-id 4-1 で洗い出すため、ここでは候補に留める（確定した反映内容と
して書かない）。

| 反映先 | 候補 |
|---|---|
| `.claude/docs/spec/issue-mr-workflow.md` | 提供関数の表へ追加関数の行、flow-id 5-3／5-5 の節、配布物としてのCI設定の扱い |
| `.claude/docs/spec/gitlab-verification-environment.md` | GitLab Runner の構築手順と、実際に踏んだ落とし穴 |
| `.claude/docs/spec/distribution-assets.md` | CI設定を配布資産に含める場合の追記 |
| `.claude/docs/ddr/i0114-01-….md` | ホスティング手段の選定と却下案。**枝番は 01 から。追加したら `bash .claude/scripts/src/generate-ddr-list.sh` を実行し、`.claude/docs/README.md` の差分を同じコミットへ含める** |
| AIアセット（`.claude/rules/` `.claude/skills/` `AGENTS.md`） | 作業中に気づいた不備があれば |

## やらないこと（スコープ外）

- ホストしたHTMLの**公開範囲・寿命の制御**（認証・自動失効等）。issue の受け入れ条件どおり、
  プロジェクトの可視性設定に従う（判断はissue本文で確定済み）
- 既存の flow-id 5-3 層3（`upload_attachment`）の**置き換え**。添付とホスティングは目的が違う
  ため併存させる
- `reports/` の削除タイミング（flow-id 5-4）そのものの変更。タイミングの矛盾は削除位置を
  動かさずに解く（判断は flow-id 2-6 へ送る）
- `plans/` のHTMLビューをホスト対象に含めるかどうか（判断は flow-id 2-6 へ送る）

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
(3) flow-id 5-5 の実行時にURLがユーザーへ提示される、
(4) `test_vcs_provider.sh` が `failures=0`、かつ `.claude/scripts/test/` の既存テストが緑、
(5) 手順が SKILL.md の flow-id 5-x と spec/DDR に反映されている、
(6) 認証・自動失効等の追加制御を入れていない。

## issueの受け入れ条件との対応

| 受け入れ条件 | この計画での対応箇所 |
|---|---|
| GitLab運用で flow-id 5-4 を実行すると、`reports/` 配下の最新の報告HTMLが CI/CD Review Apps としてデプロイされ、そのURLがユーザーへ提示される | フェーズ2 問い1・問い3 → 変更対象「CI設定」「フロー定義」。**flow-id は現行番号の 5-5（マージ依頼）へ読み替える** |
| GitHub運用でも代替のホスティング手段により同様にURLが提示される仕組みが用意されている | フェーズ2 問い2 → 変更対象「Provider抽象」「CI設定」 |
| ホスティングの手順が SKILL.md の flow-id 5-4、および関連する spec/ddr に反映されている | 変更対象「フロー定義」＋フェーズ4〈反映〉 |
| 公開範囲・寿命について追加の認証・自動失効等の制御は行わない | 「やらないこと（スコープ外）」に明記。検証の合格条件(6)で確認する |
