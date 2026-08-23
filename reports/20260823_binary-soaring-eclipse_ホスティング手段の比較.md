---
title: 報告HTMLのホスティング手段の比較（調査結果）
type: report
description: reports/配下の報告HTMLをホストしURLを払い出す手段をGitHub/GitLabそれぞれで比較し、案(b)の成立条件・配布物としての扱い・可視性と寿命の制約を確かめた結果。
tags: [issue114, hosting, github-pages, gitlab-pages]
keywords: [GitHub Pages, GitLab Pages, parallel deployments, path_prefix, Review Apps, 可視性, access control, 配布資産, gh-pages, concurrency]
---

# 報告HTMLのホスティング手段の比較（調査結果）

対応する計画: `plans/【調査】報告HTMLのホスティング手段とタイミングの選定.md`（flow-id 2-4 で合意）

## サマリ（結論の一覧）

| # | 問い | 結論 | 根拠の性質 |
|---|---|---|---|
| 1 | GitHub は何でホストするか | **GitHub Pages の「Deploy from a branch」方式**。`gh-pages` ブランチの `pr-<PR番号>/` サブディレクトリへ置く。**`actions/deploy-pages`（artifact方式）は使えない** | ドキュメントの読解＋実測（`raw` のヘッダ） |
| 2 | GitLab は何でホストするか | **GitLab Pages parallel deployments**（`pages.path_prefix`）。ただし **Premium/Ultimate が必要** | **ドキュメントの読解のみ・実機未検証** |
| 3 | 案(b)は成立するか | **成立する。** ただし「**対象HTMLが0件ならデプロイをスキップする**」ガードが必須 | 設計判断・**実機未検証** |
| 4 | URLはどう取得するか | **GitHub は決定的に組み立てられる**（`https://<owner>.github.io/<repo>/pr-<n>/`）。**GitLab はAPIで引く**（`CI_PAGES_URL` はCIジョブ内でしか読めない） | ドキュメントの読解 |
| 5 | 可視性はどうなるか | **GitHub は可視性設定に従わない**（private でも Pages サイトは既定で公開。非公開化は Enterprise Cloud のみ）。**GitLab は従う**（access control が Free tier） | **ドキュメントの読解のみ・実機未検証** |
| 6 | `plans/` も含めるか | **含める**（`pr-<n>/plans/` と `pr-<n>/reports/` に分ける） | 判断 |
| 7 | 配布資産に含めるか | **含めない。** ただし `.github/` は**何もしないと配布される**ため、`sync-assets.sh` 側で `workflows/` を除外する実装が要る | **実装の確認** |
| 8 | 公開範囲・寿命をどうするか | **恒久公開してよい**（flow-id 2-9 でユーザーが判断）。GitLab も `expire_in: never` にして**GitHubと寿命を揃える** | ユーザーの判断 |

**設計へ効く制約が3つある。**

1. **GitHub Pages は「プロジェクトの可視性設定に従う」を満たせない。** private / internal リポジトリ
   でも Pages サイトは既定でインターネットに公開される。**flow-id 2-9 でユーザーが「公開して
   おいてよい」と判断したため、可視性によるガードは入れない**（ただし配布先向けの注意として
   ドキュメントへ残す）。
2. **GitLab の並列デプロイは Premium/Ultimate 限定で、検証環境（GitLab CE ＝ Free）では実機検証
   できない。** flow-id 2-9 でユーザーが「**直列のみ検証でよい**」と判断したため、実装は並列の
   ままとし、**CE で可能な直列（単一デプロイ）までを実機検証**、並列部分は「実機未検証」と明記する。
3. **削除pushと通知は同じ flow-id 5-6 に同居する**（下記「問い1(i)」）。5-5 は push を持たない。

## 実施条件（測った対象・環境）

| 項目 | 値 |
|---|---|
| 実施日 | 2026-08-23 |
| リポジトリ | `yuki-matsu783/MR-driven-workflow`（`visibility: public` / `private: false` / `has_pages: false`） |
| ブランチ / PR | `feature-114-host-report-html-and-notify-url` / PR #180 |
| 参照した一次情報 | 下記「参照した一次情報」の表（URL・参照日つき） |
| 実測に使ったもの | `curl -sSI`（raw のContent-Type）、`gh api`（リポジトリ・Pages の状態）、`wc -c`（HTMLのサイズ）、リポジトリ内スクリプトの読解 |
| **実機検証していないもの** | GitHub Pages の有効化・デプロイ・URLの到達性、GitLab Runner の構築、GitLab Pages の直列／並列デプロイ。**すべてフェーズ3で行う**（計画の「やらないこと」どおり） |

### 参照した一次情報

**いずれも 2026-08-23 に参照した。** 外部ドキュメントは改訂されるため、後日の突き合わせに使う。

| # | ドキュメント | URL | 何の根拠か |
|---|---|---|---|
| A | GitHub Docs「What is GitHub Pages?」 | `https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages` | 1リポジトリ1サイト、プロジェクトサイトのURL形式 |
| B | GitHub Docs「Configuring a publishing source for your GitHub Pages site」 | `https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site` | branch方式はブランチ/フォルダの内容がそのままサイト、artifact方式はartifactがサイト全体 |
| C | GitHub Docs「Controlling permissions for GITHUB_TOKEN」 | `https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/controlling-permissions-for-github_token` | fork からの `pull_request` では write 権限が read へ調整される |
| D | GitHub Enterprise Cloud Docs「Changing the visibility of your GitHub Pages site」 | `https://docs.github.com/en/enterprise-cloud@latest/pages/getting-started-with-github-pages/changing-the-visibility-of-your-github-pages-site` | private/internal でも Pages は既定で公開、非公開化は Enterprise Cloud のみ |
| E | GitLab Docs「GitLab Pages parallel deployments」 | `https://docs.gitlab.com/user/project/pages/parallel_deployments/` | Premium/Ultimate、17.9 GA、`path_prefix` の記法とURL形式、`expire_in` 既定24時間、上限はルートnamespace単位 |
| F | GitLab Docs「GitLab Pages access control」 | `https://docs.gitlab.com/user/project/pages/pages_access_control/` | Free tier で利用可、プロジェクトの可視性に従う、self-managed は管理者の有効化が要る |
| G | GitLab Docs「Review apps」 | `https://docs.gitlab.com/ci/review_apps/` | Free tier、動的環境の記法、**ホストするインフラは自前** |
| H | GitLab Docs「Administer GitLab Pages」 | `https://docs.gitlab.com/administration/pages/` | `pages_external_url` はインスタンスのサブドメイン不可、ワイルドカードDNS、`gitlab_pages['access_control']` |
| I | `actions/deploy-pages` README | `https://github.com/actions/deploy-pages` | 入力・出力（`page_url`）・必要な permissions |

**対象バージョン**: GitLab は 17.9 以降（parallel deployments のGA）を前提に読んだ。検証環境は
`gitlab/gitlab-ce:18.5.4-ce.0`。GitHub Docs はバージョン概念を持たない（参照日で限定する）。

## 実施した内容と結果

### 問い1(i): 案(b)が成立する条件

案(b) ＝ **最終統括レポートのステップでホストし、マージ依頼のステップでは通知のみ行う**。

#### 前提の訂正: 5-5 は push を持たない

**当初この節は「5-4 → 5-5（削除push）→ 5-6（通知）」と書いていたが、誤りである。**
`.claude/skills/issue-mr-flow/SKILL.md` の flow-id 5-5 は「**スクリプトはコミットまでは行わない**
ため、削除・リセットの結果は直後の flow-id 5-6 の `commit` スキル経由でコミットする」と定めている。
実際の順序は次のとおり。

| flow-id | 何が起きるか | ホスティングとの関係 |
|---|---|---|
| 5-4 | 統括レポートを作成し **commit・push** | **ここでホストされる** |
| 5-5 | `cleanup-task.sh` が `plans/` `worklog/` `reports/` を削除（**commitもpushもしない**） | 何も起きない |
| 5-6 | **削除のcommit・push** → `set_mr_ready` → **URLを提示** | **URLを壊しうるpushと、URLの提示が同じステップに同居する** |

**したがって「削除pushの直後に、同じステップの中で到達性を確認してURLを出す」ことになる。**
ガードが要るという結論は変わらないが、**確認のタイミングは「削除pushの後」**である
（前に確認しても、その後のpushで壊れたら意味が無い）。

#### 観点表への回答

| 確認すること | 結果 |
|---|---|
| 5-4 の push を CI がどのトリガで捉えるか | **`push` トリガ（`feature-*` ブランチ）。`paths` フィルタは付けない**（下記「発火条件」） |
| 5-6 の削除pushが、既にホストされた内容を壊さないか | **ガードで無害化する。** branch方式ではサイトの実体が `gh-pages` ブランチの内容なので、ジョブが「**対象HTMLが0件なら何もせず成功終了**」すれば `pr-<n>/` は残る。`actions/deploy-pages`（artifact方式）だとartifactがサイト全体になるため**前回のサブディレクトリごと消える**（参照B） |
| 5-6 でURLをどう取得するか | GitHubは組み立てるだけ。GitLabはAPIで引く（問い1(iv)） |
| CIが無い／失敗する環境でフローが止まらないか | **止めない。** 既存の `upload_attachment`（flow-id 5-4 の層3）と同じ「**失敗は正常系のひとつ**」の形にし、非0終了で呼び出し側がスキップする |
| デプロイ完了を待つ必要があるか | **待つ。** 到達性確認の仕様は下記 |

#### 発火条件（どのpushでジョブを起動し、どの条件でデプロイするか）

**「起動は広く、デプロイは狭く」で統一する。**

| 段 | 条件 |
|---|---|
| **起動** | `on: push: branches: ['feature-*']`。**`paths` フィルタは付けない**（削除pushも `reports/**` に触れるためフィルタでは絞れず、ガードと二重化して読みにくくなるだけである） |
| **デプロイ判定1** | ブランチに紐づく**open な PR が1件だけ**存在するか。0件・2件以上なら**スキップ**（下記「PR番号の取得」） |
| **デプロイ判定2** | `reports/*.html` と `plans/*.html` の**合計が1件以上**あるか。0件なら**スキップ**（これが 5-6 の削除pushを無害化する要） |

**これは却下した案(a)とは別物である。** 案(a)は「pushごとに**別のパスへ**デプロイして積み上げる」
案であり、本案は「pushごとにジョブは起動するが、**デプロイ先は1PRにつき1ディレクトリで固定**、
かつ中身が空なら何もしない」である。増えるのは1PRあたり1ディレクトリで、pushの回数に比例しない。

#### PR番号の取得

`push` イベントのペイロードにPR番号は含まれない。**ジョブ側でブランチ名から引く。**

```bash
gh pr list --head "$GITHUB_REF_NAME" --state open --json number --jq '.[].number'
```

| ケース | 挙動 |
|---|---|
| 1件 | その番号を `pr-<n>/` に使う |
| 0件（PR作成前のpush・PRクローズ後） | **デプロイしない**（スキップして成功終了） |
| 2件以上 | **デプロイしない**（どちらのPRのものか決められないため） |

**呼び出し側（`Provider.sh`）も同じ導出をする。** 食い違うと通知したURLが404になるため、
**両者が使う導出は `get_mr_for_branch`（既存関数）に一本化する**（ジョブ側は `gh pr list` で
同等の結果を得る）。

#### 同時実行制御

branch方式は `gh-pages` へ push するため、**複数の実行が重なると2本目以降が non-fast-forward で
失敗する**。起きうる場面は現実的で、(1) 複数PRが並行して 5-4 を実行する、(2) 同一ブランチで
5-4 と 5-6 のpushが近接する、の2つ。

- ワークフローに `concurrency: { group: gh-pages-deploy, cancel-in-progress: false }` を置く
  （**キャンセルしない**。キャンセルするとデプロイが落ちる）。
- それでも競合しうるため、push を `git pull --rebase && git push` で**最大3回リトライ**する。

#### 到達性確認の仕様

| 項目 | 値 |
|---|---|
| 方法 | 組み立てたURLへHTTPリクエスト（`curl -sS -o /dev/null -w '%{http_code}'`） |
| 間隔・上限 | **5秒間隔・最大90秒**（18回） |
| 200が返った場合 | URLをそのまま提示する |
| 上限まで200にならなかった場合 | **URLは提示するが「まだ反映されていない可能性がある」と注記する。フローは止めない** |
| 確認自体が失敗（ネットワーク不通等） | 同上。**「失敗は正常系のひとつ」の枠に入れる** |

### 問い1(ii): 案(a)(c) を却下した理由

DDR `i0114-01` へ残すため、推測ではなく仕様で確かめた。

| 案 | 却下理由 |
|---|---|
| **(a) 不変パス**（コミットSHA単位のパスへ毎push デプロイ） | **デプロイ物の増加率が、採用案の数倍〜十数倍になる。** GitHub Pages には失効の仕組みが無く（参照E の GitLab とは対照的）、掃除する仕組みもこのフローに無い（`cleanup-task.sh` はワークツリーの `reports/` を消すだけで `gh-pages` には触れない）。**採用案(b)も溜まる点は同じだが、増え方が「1PRにつき1ディレクトリ」に収まる**のに対し、案(a)は「1pushにつき1ディレクトリ」で、本ブランチだけで既に5倍になる |
| **(c) SHA指定**（5-6 で過去SHAを指定してCIを起こす） | **5-4 でホストする案(b)と比べて、得るものが無い。** (1) 5-4 で一度pushしている以上その時点で走らせればよい、(2) 5-6 で起動すると**デプロイ完了を待つ時間が丸ごとマージ依頼の直前に来る**、(3) `workflow_dispatch` はデフォルトブランチのワークフロー定義しか使えないため、機構を配布した直後（ワークフローがまだ default ブランチに無い）は動かない |

### 問い1(iii): `plans/` のHTMLビューをホスト対象に含めるか

**含める。** 判断の根拠は次の3点。

- `plans/` も `reports/` と同じく flow-id 5-5 で削除され、squash merge で `main` に残らない。
  **消える理由が同じなら、残す扱いも同じにするのが一貫している。**
- レビュアーが「計画（合意した内容）」と「結果」を同じURLから行き来できる。
- **サイズが問題にならない。** 本ブランチの計画HTMLの実測は次のとおりで、合計 **49,706 バイト
  （約48.5 KiB）**である。テンプレート由来のHTMLは自己完結で**画像も外部依存も持たない**ため、
  1ファイルあたり20〜30KB程度に収まる。

  | ファイル | バイト数 |
  |---|---|
  | `plans/binary-soaring-eclipse.html` | 29,722 |
  | `plans/【調査】報告HTMLのホスティング手段とタイミングの選定.html` | 19,984 |
  | **合計** | **49,706** |

**配置は `pr-<n>/plans/` と `pr-<n>/reports/` に分ける。** ファイル名が衝突しないうえ、
`pr-<n>/index.html` を自動生成して一覧を出せる。

### 問い1(iv): URLの取得経路

| プロバイダ | 経路 |
|---|---|
| **GitHub** | **組み立てるだけでよい。** `gh api repos/{o}/{r}/pages --jq .html_url` を土台にし（独自ドメインに追随するため）、取得できないときだけ `https://<owner>.github.io/<repo>` へフォールバックする。末尾に `/pr-<n>/` を足す |
| **GitLab** | **APIで引く。** `CI_PAGES_URL` は**CIジョブの中でしか定義されない**定義済み変数であり、ローカルの `Provider.sh` からは読めない。`glab api projects/:id/pages --jq .url` を土台に `/mr-<iid>` を足す。取得できない場合は `glab api projects/:id/environments` の `external_url` へフォールバックする（**どちらも実機未検証**） |

**GitHub の「組み立てるだけでよい」は GitLab には当てはまらない。** GitLab はプロジェクトごとに
ユニークドメインの有無でURL形式が変わる（参照E）ため、組み立てではなくAPIで引く。

### 問い2: GitHub の手段

**採用: GitHub Pages の「Deploy from a branch」方式**（`gh-pages` ブランチ / ルート）。

| 確認項目 | 結果 | 根拠 |
|---|---|---|
| 1リポジトリ1サイトの制約下で並列プレビューをどう表現するか | **サブディレクトリ**。サイトの実体がブランチの内容なので `pr-1/` `pr-2/` … を同居させられる | 参照A・B |
| デプロイ完了の待ち方とURL取得 | URLは決定的。完了はURLへのHTTPリクエストで確認（上記の到達性確認） | 参照A |
| fork PR での `GITHUB_TOKEN` | **`push` トリガで回避する。** 自リポジトリのfeatureブランチへ push するため fork の問題に当たらない。**配布先でfork運用する場合は当たる**ので注記を残す | 参照C |
| Pages 有効化に必要な操作 | **未検証**（フェーズ3）。現状 `gh api repos/{o}/{r}/pages` は 404 で `has_pages: false` | 実測 |
| 可視性設定との一致 | **一致しない。** private/internal でも既定で公開。**ユーザー判断により、これを受け入れてガードを入れない** | 参照D |

#### 却下した手段（却下理由つき）

| 却下候補 | 却下理由 | 裏取り |
|---|---|---|
| **`raw.githubusercontent.com`** | **HTMLがレンダリングされない。** `content-type: text/plain; charset=utf-8` かつ `x-content-type-options: nosniff` で、ブラウザはHTMLとして解釈しない | **実測**（本ブランチのHTMLに対し `curl -sSI`） |
| **`actions/deploy-pages`（artifact方式）** | **1回のデプロイでサイト全体が置き換わる**ため、PRごとの並列プレビューを保てない。案(b)の要が成立しない | 参照B・I |
| **Actions artifact（`actions/upload-artifact`）** | ダウンロード専用でブラウザ表示できない。ログインも要る | 仕様上明らか |
| **`upload_attachment`（既存の層3）** | 添付はダウンロード用であり、#114 の「ブラウザで直接開ける」を満たさない。**置き換えではなく併存させる** | `.claude/docs/spec/issue-mr-workflow.md` |
| **外部ホスティング（Netlify等）** | リポジトリ外のアカウントとシークレットが要り、**配布物として成立しない** | 判断 |

### 問い3: GitLab の手段

**Review Apps（動的環境）は Free tier で使えるが、ホスト先のインフラは自前で用意する必要がある**
（参照G: "you must set up the infrastructure to host and deploy the review apps"）。つまり Review
Apps は**枠組み**であって、ホスティングそのものではない。組み込みで並列プレビューを提供するのは
**GitLab Pages parallel deployments**（`pages.path_prefix`）である。

| 確認項目 | 結果 | 根拠 |
|---|---|---|
| CI記法 | `pages:` ジョブに `path_prefix: "mr-$CI_MERGE_REQUEST_IID"`。動的環境は `environment.name: review/$CI_COMMIT_REF_SLUG` ＋ `environment.url` ＋ `on_stop` / `auto_stop_in` | 参照E・G |
| **パイプライン種別** | **マージリクエストパイプラインに限定する**（下記） | 参照E |
| ホストの実体 | **GitLab Pages**（Runner 上の静的サーバは下記の理由で却下） | 参照G |
| **必要なtier** | **Premium / Ultimate。GitLab 17.9 で GA**（機能フラグ `pages_multiple_versions_setting` は削除済み） | 参照E |
| URL形式 | ユニークドメイン有: `https://project-123456.gitlab.io/<prefix>` ／ 無: `https://<namespace>.gitlab.io/<project>/<prefix>` | 参照E |
| URL取得 | `glab api projects/:id/pages` → フォールバックで environments API（問い1(iv)） | 参照E |
| 失効 | 既定24時間。`expire_in` で変更でき、`expire_in: never` で無効化できる。**本機構は `expire_in: never` を指定してGitHubと寿命を揃える**（下記） | 参照E |
| 並列デプロイ数の上限 | ルートnamespace単位で制限。**具体的な数値はドキュメントに明記が無い** | 参照E |
| 可視性設定との一致 | **一致する。** access control は **Free tier** で利用でき、プロジェクトの可視性に従う。self-managed では管理者が `gitlab_pages['access_control'] = true` を設定する | 参照F・H |
| self-managed の前提 | `gitlab.rb` に `pages_external_url` が要る。**インスタンスのドメインのサブドメインであってはならず**、ワイルドカードDNS（`*.example.io`）が標準 | 参照H |

#### `path_prefix` が空になる罠

**MR関連の定義済み変数（`CI_MERGE_REQUEST_IID` 等）は、マージリクエストパイプラインでのみ
設定される。** ブランチパイプライン（単純なpushで起きるパイプライン）では空になる。

空のまま展開されると `path_prefix` が `mr-` になり、**すべてのMRが同じディレクトリを共有して
上書きし合う**。しかもURLは組み立てられるので、**エラーではなく「別のMRの内容が表示される」**
という形で表面化する。

**対策**: `pages` ジョブに `rules: - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'` を置き、
**マージリクエストパイプライン以外では走らせない**。あわせて、変数が空だった場合はジョブを
失敗させず**スキップ**する（GitHub側のガードと同じ形）。

**GitHub は `push` トリガ、GitLab は MRパイプラインという非対称になる。** 理由は、GitHubが
`pull_request` トリガを避けたのは fork の `GITHUB_TOKEN` 問題（参照C）であり、GitLabのMR
パイプラインにはその制約が無いためである。**この非対称は意図的なので、ドキュメントへ残す。**

#### 寿命を GitHub と揃える（`expire_in: never`）

GitLabの並列デプロイは既定24時間で失効するが、GitHub Pages には失効の仕組みが無い。
**同じ機能なのに、GitHubではURLが永続し、GitLabでは24時間後に死ぬ**——レビューが翌日以降に
なれば、GitLab運用の配布先ではマージ依頼で提示したURLが開けない。

VCS抽象化層は呼び出し元にプロバイダ差を見せないことが目的であるため、**`expire_in: never` を
指定して寿命を揃える**。flow-id 2-9 でユーザーが「公開しておいてよい」と判断したことと整合する。

#### Runner 上の静的サーバを却下した理由

**ホスト先がGitLabのアクセス制御の外に出るため、private プロジェクトの成果物が無認証で
公開されうる。** GitLab側は access control で可視性に従えるのが唯一の利点なので、それを
自ら捨てる選択になる。

#### 実機検証の範囲と、環境構築コストの見積もり

**flow-id 2-9 でユーザーが「直列のみ検証でよい」と判断した。** 実装は受け入れ条件どおり並列
（`path_prefix`）のままとし、**CE で可能な直列（単一デプロイ）までを実機検証**、並列部分は
「実機未検証」と明記する。

| 作業 | 内容 | 見積もり |
|---|---|---|
| GitLab Pages の有効化 | `gitlab.rb` へ `pages_external_url 'http://<別ドメイン>'` を追記し `gitlab-ctl reconfigure`。**インスタンス（`localhost:8929`）のサブドメインにできない**ため、`nip.io` のようなワイルドカードDNSサービスか hosts ファイルで別ドメインを用意する | **1〜2時間**（DNSの解決が最大の不確実要素） |
| GitLab Runner の構築 | `docker run` で `gitlab-runner` を起動 → `gitlab-runner register`（**executor は `docker`**。CEと同一ホスト上のためネットワーク疎通の設定が要る） | **1時間** |
| 直列デプロイの確認 | `pages` ジョブ（`path_prefix` 無し）で `public/` を公開し、`CI_PAGES_URL` が開けることを確認 | **30分** |
| access control の確認 | `gitlab_pages['access_control'] = true` を設定し、private プロジェクトのPagesが未認証で開けないことを確認 | **30分** |
| **並列デプロイ** | **CE（Free）では実施しない。** Premium/Ultimate が必要 | — |

**`pages` は依然としてRunnerが実行するCIジョブである。** 「GitLab Pages を使うから Runner が
不要になる」わけではない。

### 問い4: 配布物としての扱い

**結論: CI設定（`.github/workflows/*.yml` と `.gitlab-ci.yml`）は配布資産に含めない。**
CI設定が**配布先のプラン・インフラ・可視性に強く依存する**ためである。GitLab側は
Premium/Ultimate が要り、GitHub側は private リポジトリで内容が公開される。

**ただし「含めない」は、何もしなければ実現されない。**

| 対象 | 現在の扱い | 根拠 |
|---|---|---|
| `.github/` 配下 | **丸ごと配布される** | `sync-assets.sh:48-52` が `cp -R "${PROJECT_ROOT}/.github/"* "${ASSETS_DIR}/.github/"`、`install-to-project.sh:192-194` が `safe_copy_dir` で展開 |
| `.gitlab/` 配下 | **丸ごと配布される** | `sync-assets.sh:55-59` / `install-to-project.sh:197-199` |
| **`.gitlab-ci.yml`（ルート直下）** | **配布されない** | `sync-assets.sh` のルート直下コピーは明示リスト（`.mrworkflow.json` / `AGENTS.md` / `GEMINI.md` / `CLAUDE.md` / `HANDOFF.md` / `index.md` / `.gitattributes`）のみ |

**つまり非対称である。** `.github/workflows/deploy-pages.yml` を置いた瞬間に配布資産へ載る一方、
`.gitlab-ci.yml` は放っておいても載らない。

- 衝突時の挙動: `safe_copy_file` は内容が異なれば `<dest>.bak` を作って上書きし、警告を出す。
  **配布先が既にワークフローを持っていれば、それが `.bak` へ退避される。**
- **実装方針**: `sync-assets.sh` の `.github/` コピーで `workflows/` を除外する。代わりに**雛形**を
  `.claude/skills/issue-mr-flow/assets/` 配下へ置き（`.claude/` 一式は配布されるため雛形は届く）、
  導入は配布先の判断で手動に委ねる。

## 確かめられなかったこと

**すべて計画の「やらないこと」に沿った意図的な未検証である。** フェーズ3のどの手順で確かめるかを
併記する。

| 未検証の項目 | フェーズ3での確認手順 |
|---|---|
| **GitHub Pages が private リポジトリで公開されること**（参照D。サマリ #5 の根拠） | **ユーザー判断により、この機能は使わない前提になった**ため確認しない。配布先向けの注記に留める |
| **GitLab の並列デプロイが Premium/Ultimate 限定であること**（参照E。サマリ #2 の根拠） | **CE では確認できない。** 「直列のみ検証」の判断により、`path_prefix` を指定したジョブがCEでどう振る舞うか（エラーか無視か）だけを記録する |
| GitHub Pages の有効化操作（APIで足りるか、Web UIが必須か） | `gh api -X POST repos/{o}/{r}/pages -f 'source[branch]=gh-pages' -f 'source[path]=/'` を実行し、失敗したらWeb UIへ切り替える |
| 実際にデプロイされたURLがブラウザで開けるか | `gh-pages` へ push 後、`curl -sSI <URL>` で `content-type: text/html` と 200 を確認し、ブラウザでも開く |
| ビルド・デプロイの所要時間（到達性確認の上限90秒が妥当か） | デプロイ完了までの時間を3回計測し、90秒で足りるかを確認する |
| 5-6 の削除pushでサイトが壊れないこと | `reports/` `plans/` を空にした状態で push し、`pr-<n>/` のURLが200のままであることを確認する |
| `gh-pages` への同時push競合とリトライ | 2つのPRから同時に 5-4 を実行し、両方のデプロイが成功することを確認する |
| GitLab Pages access control が**並列デプロイにも適用されるか** | ドキュメントに記載が無く、**並列自体がCEで動かない**ため確認できない。直列での適用のみ確認する |
| GitLab の並列デプロイ数の上限（具体値） | ドキュメントに明記が無い。**CEでは確認できない** |
| `glab api projects/:id/pages` の応答形 | CE ＋ Pages 有効化後に実行し、`url` フィールドの有無を確認する |
| 配布先が fork 運用の場合の `GITHUB_TOKEN` の挙動 | 本リポジトリでは再現しない。**ドキュメントへの注記に留める** |

## 設計への反映

フェーズ3の個別作業計画（flow-id 3-1）は、この結果だけを読んで書ける。要点は次のとおり。

1. **`Provider.sh` に「報告HTMLをホストしURLを返す」関数と「到達性を確認する」関数を追加する。**
   `upload_attachment` と同じく**失敗は正常系のひとつ**とし、非0終了で呼び出し側がスキップする。
   PR/MR番号の導出は `get_mr_for_branch` に一本化する。
2. **GitHub のワークフロー**: `on: push: branches: ['feature-*']`（`paths` フィルタ無し）、
   branch方式で `gh-pages` の `pr-<n>/` へ書く。
   - デプロイ判定1: openなPRが**ちょうど1件**か（0件・複数件はスキップ）
   - デプロイ判定2: `reports/*.html` ＋ `plans/*.html` が**1件以上**か（0件はスキップ＝削除pushの無害化）
   - `concurrency: { group: gh-pages-deploy, cancel-in-progress: false }` ＋ push の3回リトライ
   - **可視性によるガードは入れない**（ユーザー判断）
3. **GitLab の `.gitlab-ci.yml`**: `pages` ジョブに `path_prefix: "mr-$CI_MERGE_REQUEST_IID"`、
   `expire_in: never`、`rules: - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'`。
   対象HTMLが0件ならスキップ。
4. **`SKILL.md`**: flow-id **5-4** へホスト、**5-6** へ通知を組み込む。**5-6 では削除pushの後に**
   到達性を確認（5秒間隔・最大90秒）し、200にならなくてもURLは注記つきで提示してフローを止めない。
5. **`sync-assets.sh` の `.github/` コピーから `workflows/` を除外する。** 雛形は
   `.claude/skills/issue-mr-flow/assets/` へ置く。
6. **DDR `i0114-01`** に、ホスティング手段とタイミングの選定・却下案（(a)(c) と GitHub側4候補）・
   可視性と寿命の扱い・GitHub/GitLabでトリガが非対称になる理由を残す。

## 想定と異なった点

### flow-id 5-5 に push は無かった

当初「5-4 → 5-5（削除push）→ 5-6（通知）」と書いていたが、5-5 はコミットもpushもしない。
**削除pushと通知は同じ 5-6 に同居する**（上記「前提の訂正」）。到達性確認は削除pushの**後**に
行う必要がある。

### GitLab の実機検証範囲が狭まった

flow-id 1-4 で「GitLab Runner を立てて実機検証する」と合意したが、並列デプロイは
**Premium/Ultimate 限定**で、検証環境（GitLab CE ＝ Free）では実施できない。
**flow-id 2-9 でユーザーが「直列のみ検証でよい」と判断**し、実装は並列のまま・検証は直列まで、
という形に落ち着いた。

### GitHub Pages は「可視性設定に従う」を満たせない

計画では「可視性設定と一致するかを確認する」としていたが、**確認したら一致しなかった**。
private / internal リポジトリでも Pages サイトは既定で公開される。

当初は「public のときだけデプロイする」ガードを設計に含めたが、**flow-id 2-9 でユーザーが
「公開しておいてよい」と判断**したため、ガードは入れない。**配布先が private リポジトリで
使う場合、計画・レポートの中身が公開される**という事実は、ドキュメントへ注記として残す。

## 残課題

- **GitHub Pages の有効化。** フェーズ3の最初に行う。リポジトリ設定を変更するため、
  実行前にユーザーへ知らせる。
- **`gh-pages` ブランチの掃除。** PR単位のディレクトリはマージ後も残り、`expire_in: never` に
  よりGitLab側も残る。**恒久公開してよいという判断を得たので今回は放置する**が、溜まり続けることは
  事実なので、別issueの候補として記録しておく。
- **配布先が private リポジトリの場合の注意喚起**をどこに書くか（`SKILL.md` か spec か）。
  フェーズ4で決める。
