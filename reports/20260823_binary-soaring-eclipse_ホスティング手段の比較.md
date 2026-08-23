---
title: 報告HTMLのホスティング手段の比較（調査結果）
type: report
description: reports/配下の報告HTMLをホストしURLを払い出す手段をGitHub/GitLabそれぞれで比較し、案(b)の成立条件・配布物としての扱い・可視性の制約を確かめた結果。
tags: [issue114, hosting, github-pages, gitlab-pages]
keywords: [GitHub Pages, GitLab Pages, parallel deployments, path_prefix, Review Apps, 可視性, access control, 配布資産, gh-pages, deploy-pages]
---

# 報告HTMLのホスティング手段の比較（調査結果）

対応する計画: `plans/【調査】報告HTMLのホスティング手段とタイミングの選定.md`（flow-id 2-4 で合意）

## サマリ（結論の一覧）

| # | 問い | 結論 | 確度 |
|---|---|---|---|
| 1 | GitHub は何でホストするか | **GitHub Pages の「Deploy from a branch」方式**。`gh-pages` ブランチの `pr-<PR番号>/` サブディレクトリへ置く。**`actions/deploy-pages`（artifact方式）は使えない** | 高（一次情報＋実測） |
| 2 | GitLab は何でホストするか | **GitLab Pages parallel deployments（`pages.path_prefix`）**。ただし **Premium/Ultimate が必要** | 高（一次情報） |
| 3 | 案(b)は成立するか | **成立する。ただし「`reports/*.html` が0件ならデプロイをスキップする」ガードが必須** | 中（設計上は成立。実機未検証） |
| 4 | URLはどう取得するか | **GitHub は決定的に組み立てられる**（`https://<owner>.github.io/<repo>/pr-<n>/`）。GitLab は `CI_PAGES_URL` ＋ path_prefix | 高（一次情報） |
| 5 | 可視性設定に従えるか | **GitHub は従えない**（private リポジトリでも Pages サイトは既定で公開。非公開化は Enterprise Cloud のみ）。**GitLab は従える**（access control が Free tier で利用可） | 高（一次情報） |
| 6 | `plans/` も含めるか | **含める**（`pr-<n>/plans/` と `pr-<n>/reports/` に分ける） | 中（判断） |
| 7 | 配布資産に含めるか | **含めない。** ただし `.github/` は**何もしないと配布される**ため、`sync-assets.sh` 側で `workflows/` を除外する実装が要る | 高（実装を読んで確認） |

**最も重要な発見が2つある。**

1. **GitHub Pages は「プロジェクトの可視性設定に従う」を満たせない。** private / internal リポジトリ
   でも Pages サイトは既定でインターネットに公開される。issue #114 の受け入れ条件を破らないために、
   **ワークフロー側に「public リポジトリのときだけデプロイする」ガードが要る**。
2. **GitLab の並列デプロイは Premium/Ultimate 限定で、検証環境（GitLab CE ＝ Free）では実機検証
   できない。** flow-id 1-4 で合意した「GitLab Runner を立てて実機検証する」という方針は、
   **このままでは成立しない**（下記「想定と異なった点」）。

## 実施条件（測った対象・環境）

| 項目 | 値 |
|---|---|
| 実施日 | 2026-08-23 |
| リポジトリ | `yuki-matsu783/MR-driven-workflow`（`visibility: public` / `private: false` / `has_pages: false`） |
| ブランチ / PR | `feature-114-host-report-html-and-notify-url` / PR #180 |
| 一次情報 | GitHub Docs・GitLab Docs（下記の各項に参照先を記載） |
| 実測に使ったもの | `curl -sSI`（raw のContent-Type）、`gh api`（リポジトリ・Pages の状態）、リポジトリ内スクリプトの読解 |
| **実機検証していないもの** | GitHub Pages の有効化・デプロイ・URLの到達性、GitLab Runner の構築、GitLab Pages の並列デプロイ。**すべてフェーズ3で行う**（計画の「やらないこと」どおり） |

## 実施した内容と結果

### 問い1(i): 案(b)が成立する条件

案(b) ＝ **flow-id 5-4（統括レポートのcommit・push）でホストし、5-6（Draft解除＝マージ依頼）では
通知のみ行う**。計画の観点表に1項目ずつ答える。

| 確認すること | 結果 | 根拠 |
|---|---|---|
| 5-4 の push を CI がどのトリガで捉えるか | **`push` トリガ（featureブランチ）を使う。`pull_request` トリガは使わない。** fork からの `pull_request` では `GITHUB_TOKEN` が読み取り専用へ落とされ、`gh-pages` へ書き込めないため | GitHub Docs「Controlling permissions for GITHUB_TOKEN」: fork からの `pull_request` では write 権限が read へ調整される |
| 5-5（`reports/` 削除）の push が、既にホストされた内容を壊さないか | **壊しうる。ガードが必須。** 「Deploy from a branch」方式なら**サイトの実体は `gh-pages` ブランチの内容**なので、ワークフローが「`reports/*.html` が0件なら何もせず終了」すれば `pr-<n>/` は残る。**逆に `actions/deploy-pages`（artifact方式）はアップロードしたartifactがサイト全体になるため、前回のサブディレクトリごと消える** | GitHub Docs「Configuring a publishing source」: branch方式は指定ブランチ/フォルダの内容がそのままサイトになる。artifact方式は「デプロイするartifactにエントリファイルをトップレベルで含める」＝artifactがサイト全体 |
| 5-6 でURLをどう取得するか | **組み立てるだけでよい**（後述の問い1(iv)）。5-4 の結果をAPIで引き直す必要が無い | GitHub Docs（project site の URL 形式） |
| CIが無い／失敗する環境でフローが止まらないか | **止めない設計にできる。** 既存の `upload_attachment`（flow-id 5-4 の層3）と同じ「**失敗は正常系のひとつ**」の形にし、非0終了で呼び出し側がスキップする | `.claude/docs/spec/issue-mr-workflow.md`「提供関数」・DDR `i0111-01` |
| デプロイ完了を待つ必要があるか | **待つ必要がある。** 5-4→5-5→5-6 の間に人手が挟まらず数十秒で進む一方、Pagesのビルド・デプロイはそれより遅いことがある。**URLが決定的である以上「URLは出せるが中身がまだ無い」状態が起きうる**ので、5-6 では**到達性を確認してから提示する**（HTTPで引くか `gh run watch` で待つ） | 設計判断。**待ち時間の実測はフェーズ3** |

**結論: 案(b)は成立する。** 決め手は「サイトの実体をブランチの内容にする」ことで、これにより
5-5 の削除pushを**何もしない**ことで無害化できる。

### 問い1(ii): 案(a)(c) を却下した理由の裏取り

DDR `i0114-01` へ残すため、推測ではなく仕様で確かめた。

| 案 | 却下理由（裏取り済み） |
|---|---|
| **(a) 不変パス**（コミットSHA単位のパスへ毎push デプロイ） | **技術的には成立するが、デプロイ物が単調に増える。** GitHub の branch方式では `gh-pages` ブランチにSHA単位のディレクトリが積み上がり、掃除する仕組みがこのフローに無い（`cleanup-task.sh` はワークツリーの `reports/` を消すだけで、`gh-pages` には触れない）。GitLab の parallel deployments には既定24時間の失効があるが、**GitHub Pages には失効の仕組みが無い**。PR単位（`pr-<n>/`）なら1PRにつき1ディレクトリで済む |
| **(c) SHA指定**（5-6 で過去SHAを指定してCIを起こす） | **5-4 でホストする案(b)と比べて、得るものが無い。** `workflow_dispatch` で `ref` にSHAを渡す形になるが、(1) 5-4 で一度pushしている以上その時点で走らせればよく、(2) 5-6 で起動すると**デプロイ完了を待つ時間が丸ごとマージ依頼の直前に来る**、(3) `workflow_dispatch` はデフォルトブランチのワークフロー定義しか使えないため、機構を配布した直後（ワークフローがまだ default ブランチに無い）は動かない |

### 問い1(iii): `plans/` のHTMLビューをホスト対象に含めるか

**含める。** 判断の根拠は次の3点。

- `plans/` も `reports/` と同じく flow-id 5-5 で削除され、squash merge で `main` に残らない。
  **消える理由が同じなら、残す扱いも同じにするのが一貫している。**
- レビュアーが「計画（合意した内容）」と「結果」を同じURLから行き来できる。片方だけホストすると、
  結果を読んで計画を参照したくなったときに clone が要る。
- サイズが問題にならない。テンプレート由来のHTMLは自己完結だが**外部依存を持たない＝画像も無い**
  ため、1ファイル20〜40KB程度である（本ブランチの実測: 計画2本で計 42KB）。

**配置は `pr-<n>/plans/` と `pr-<n>/reports/` に分ける。** ファイル名が衝突しないうえ、
`pr-<n>/index.html` を自動生成して一覧を出せる。

### 問い2: GitHub の手段

**採用: GitHub Pages の「Deploy from a branch」方式**（`gh-pages` ブランチ / ルート）。
ワークフローが `pr-<PR番号>/` サブディレクトリへ書き込み、`gh-pages` へ push する。

| 確認項目 | 結果 |
|---|---|
| 1リポジトリ1サイトの制約下で並列プレビューをどう表現するか | **サブディレクトリ**。Pages は「Maximum of one pages site per repository」だが、サイトの実体がブランチの内容なので、`pr-1/` `pr-2/` … を同居させられる |
| デプロイ完了の待ち方とURL取得 | URLは決定的（下記）。完了は `gh run watch` またはURLへのHTTPリクエストで確認する |
| fork PR での `GITHUB_TOKEN` | **`push` トリガを使うことで回避する。** このフローは自リポジトリのfeatureブランチへ push するため、fork の問題に当たらない。**配布先でfork運用する場合は当たる**ので、その旨をドキュメントへ残す |
| Pages 有効化に必要な操作 | 未検証（フェーズ3）。現状 `gh api repos/{o}/{r}/pages` は **404**（未有効）で `has_pages: false` |
| **可視性設定との一致** | **一致しない。** 下記「可視性の制約」 |

**URLは決定的に組み立てられる**（プロジェクトサイトの形式は
`http(s)://<owner>.github.io/<repositoryname>`）。したがって本リポジトリなら
`https://yuki-matsu783.github.io/MR-driven-workflow/pr-180/reports/<ファイル名>.html` になる。
独自ドメインに追随するため、実装では `gh api repos/{o}/{r}/pages --jq .html_url` を土台にし、
取得できないときだけ `https://<owner>.github.io/<repo>` へフォールバックする。

#### 却下した手段（却下理由つき）

| 却下候補 | 却下理由 | 裏取り |
|---|---|---|
| **`raw.githubusercontent.com`** | **HTMLがレンダリングされない。** レスポンスヘッダが `content-type: text/plain; charset=utf-8` かつ `x-content-type-options: nosniff` で、ブラウザはHTMLとして解釈しない | **実測**（本ブランチのHTMLに対し `curl -sSI`。上記2ヘッダを確認） |
| **`actions/deploy-pages`（artifact方式）** | **1回のデプロイでサイト全体が置き換わる**ため、PRごとの並列プレビューを保てない。案(b)の要（5-5 の削除pushを無害化する）が成立しない | GitHub Docs「Configuring a publishing source」 |
| **Actions artifact（`actions/upload-artifact`）** | ダウンロード専用でブラウザ表示できない。ログインも要る | 仕様上明らか |
| **`upload_attachment`（既存の層3）** | 添付はダウンロード用であり、#114 の「ブラウザで直接開ける」を満たさない。**置き換えではなく併存させる** | `.claude/docs/spec/issue-mr-workflow.md` |
| **外部ホスティング（Netlify等）** | リポジトリ外のアカウントとシークレットが要り、**配布物として成立しない**（配布先ごとに人手の初期設定が必要になる） | 判断 |

### 問い3: GitLab の手段

**Review Apps（動的環境）は Free tier で使えるが、ホスト先のインフラは自前で用意する必要がある**
（GitLab Docs「Review apps」: "you must set up the infrastructure to host and deploy the review
apps"）。つまり Review Apps は**枠組み**であって、ホスティングそのものではない。

GitLab に組み込みで並列プレビューを提供するのは **GitLab Pages parallel deployments**
（`pages.path_prefix`）である。

| 確認項目 | 結果 |
|---|---|
| CI記法 | `pages:` ジョブに `path_prefix: "mr-$CI_MERGE_REQUEST_IID"` を書く。動的環境は `environment.name: review/$CI_COMMIT_REF_SLUG` ＋ `environment.url` ＋ `on_stop` / `auto_stop_in` |
| ホストの実体 | **GitLab Pages**（Runner 上の静的サーバは下記の理由で却下） |
| **必要なtier** | **Premium / Ultimate。GitLab 17.9 で GA**（機能フラグ `pages_multiple_versions_setting` は削除済み） |
| URL形式 | ユニークドメイン有: `https://project-123456.gitlab.io/<prefix>` ／ 無: `https://<namespace>.gitlab.io/<project>/<prefix>` |
| URL取得 | CI変数 `CI_PAGES_URL` ＋ path_prefix |
| 失効 | **既定24時間。** `expire_in` で変更でき、`expire_in: never` で無効化できる |
| 並列デプロイ数の上限 | ルートnamespace単位で制限。**具体的な数値はドキュメントに明記が無い** |
| **可視性設定との一致** | **一致する。** GitLab Pages access control は **Free tier** で利用でき、プロジェクトの可視性（private / internal / public）に従う。self-managed では管理者が `gitlab_pages['access_control'] = true` を設定する必要がある |
| self-managed の前提 | `gitlab.rb` に `pages_external_url` が要る。**GitLabインスタンスのドメインのサブドメインであってはならず**（`example.com` に対して `pages.example.com` は不可、`example.io` のような別ドメイン）、ワイルドカードDNS（`*.example.io`）が標準 |

#### Runner 上の静的サーバを却下した理由

計画で挙げていたもう一方の選択肢（Runner 上で静的サーバを立てる）は却下する。
**ホスト先がGitLabのアクセス制御の外に出るため、private プロジェクトの成果物が無認証で公開されうる**。
issue #114 の受け入れ条件「プロジェクトの可視性設定に従う」を、**選んだ時点で破る**。

### 問い4: 配布物としての扱い

**結論: CI設定（`.github/workflows/*.yml` と `.gitlab-ci.yml`）は配布資産に含めない。**

理由は、CI設定が**配布先のプラン・インフラ・可視性に強く依存する**ためである。GitLab側は
Premium/Ultimate が要り、GitHub側は private リポジトリだと受け入れ条件を破る。配布先の状況を
知らないまま置くと、動かないファイルが増えるか、意図しない公開が起きる。

**ただし「含めない」は、何もしなければ実現されない。** 現在の配布経路を読んだ結果は次のとおり。

| 対象 | 現在の扱い | 根拠 |
|---|---|---|
| `.github/` 配下 | **丸ごと配布される** | `sync-assets.sh:48-52` が `cp -R "${PROJECT_ROOT}/.github/"* "${ASSETS_DIR}/.github/"`、`install-to-project.sh:192-194` が `safe_copy_dir` で展開 |
| `.gitlab/` 配下 | **丸ごと配布される** | `sync-assets.sh:55-59` / `install-to-project.sh:197-199`（同上） |
| **`.gitlab-ci.yml`（ルート直下）** | **配布されない** | `sync-assets.sh` のルート直下コピーは明示リスト（`.mrworkflow.json` / `AGENTS.md` / `GEMINI.md` / `CLAUDE.md` / `HANDOFF.md` / `index.md` / `.gitattributes`）のみ |

**つまり非対称である。** `.github/workflows/deploy-pages.yml` を置いた瞬間に配布資産へ載る一方、
`.gitlab-ci.yml` は放っておいても載らない。

- 衝突時の挙動: `safe_copy_file` は内容が異なれば `<dest>.bak` を作って上書きし、警告を出す
  （`FORCE` または `is_always_overwrite` のときは `.bak` を作らない）。
  **配布先が既にワークフローを持っていれば、それが `.bak` へ退避される。**
- **実装方針**: `sync-assets.sh` の `.github/` コピーで `workflows/` を除外する。代わりに**雛形**を
  `.claude/skills/issue-mr-flow/assets/` 配下へ置き（`.claude/` 一式は配布されるため雛形は届く）、
  導入は配布先の判断で手動に委ねる。

## 確かめられなかったこと

**すべて計画の「やらないこと」に沿った意図的な未検証である**（リポジトリ設定を変える実機検証は
フェーズ3で行う）。フェーズ3のどの手順で確かめるかを併記する。

| 未検証の項目 | フェーズ3での確認手順 |
|---|---|
| GitHub Pages の有効化操作（APIで足りるか、Web UIが必須か） | `gh api -X POST repos/{o}/{r}/pages -f 'source[branch]=gh-pages' -f 'source[path]=/'` を実行し、失敗したらWeb UIへ切り替える |
| 実際にデプロイされたURLがブラウザで開けるか | `gh-pages` へ push 後、`curl -sSI <URL>` で `content-type: text/html` と 200 を確認し、ブラウザでも開く |
| ビルド・デプロイの所要時間（5-4→5-6 の待ち時間） | `gh run watch` の所要時間を3回計測する |
| 5-5 の削除pushでサイトが壊れないこと | `reports/` を空にした状態で push し、`pr-<n>/` のURLが200のままであることを確認する |
| GitLab Pages parallel deployments の実挙動 | **CE では検証できない**（下記「想定と異なった点」）。方針の再確認が要る |
| GitLab Pages access control が**並列デプロイにも適用されるか** | ドキュメントに記載が無い。実機で確認するほかない |
| GitLab の並列デプロイ数の上限（具体値） | ドキュメントに明記が無い。管理画面で確認する |
| 配布先が fork 運用の場合の `GITHUB_TOKEN` の挙動 | 本リポジトリでは再現しない。**ドキュメントへの注記に留める** |

## 設計への反映

フェーズ3の個別作業計画（flow-id 3-1）は、この結果だけを読んで書ける。要点は次のとおり。

1. **`Provider.sh` に「報告HTMLをホストしURLを返す」関数を追加する。** `upload_attachment` と同じく
   **失敗は正常系のひとつ**とし、非0終了で呼び出し側がスキップする。GitHub実装はPagesのURLを
   組み立てて返し、GitLab実装は `CI_PAGES_URL` ＋ path_prefix を返す。
2. **GitHub のワークフローは `push` トリガ・branch方式（`gh-pages`）で書く。** 必須のガードが2つ。
   - **`reports/*.html` と `plans/*.html` が0件ならデプロイをスキップする**（案(b)の要）
   - **リポジトリが public のときだけデプロイする**（可視性の受け入れ条件を守るため）
3. **`SKILL.md` の flow-id 5-4 へホスト、5-6 へ通知を組み込む。** 5-6 では**URLの到達性を確認して
   から**提示する。
4. **`sync-assets.sh` の `.github/` コピーから `workflows/` を除外する。** 雛形は
   `.claude/skills/issue-mr-flow/assets/` へ置く。
5. **DDR `i0114-01` に、ホスティング手段とタイミングの選定・却下案・可視性の制約を残す。**

## 想定と異なった点

### GitLab の実機検証は、現在の環境では成立しない

flow-id 1-4 で「GitLab Runner を立てて実機検証する」と合意したが、**その前提が崩れている**。

- 並列デプロイ（`pages.path_prefix`）は **Premium / Ultimate 限定**である。
- 検証環境（`.claude/docs/spec/gitlab-verification-environment.md` の `gitlab/gitlab-ce:18.5.4-ce.0`）
  は **Community Edition ＝ Free tier** であり、この機能を持たない。
- 加えて、self-managed で GitLab Pages を使うには `pages_external_url` に**インスタンスとは別の
  ドメイン**とワイルドカードDNSが要る。`localhost:8929` で動かしている現在の環境では、
  Runner を立てる以前にここが障害になる。

**取りうる道は3つある。判断は人間に委ねる**（この調査では決めない）。

| 案 | 内容 | コスト |
|---|---|---|
| α | **GitLab側の実機検証を見送り**、`Gitlab.sh` の既存関数と同じく「実機未検証」と明記して実装・ドキュメントを整える | 小。先例あり（`upload_attachment` の GitLab 実装も実機未検証） |
| β | **Premium/Ultimate のトライアルライセンス**をローカルCEへ適用し、`pages_external_url` ＋ ワイルドカードDNS（hostsファイル or `nip.io` 等）を整えて検証する | 大。ライセンス取得・DNS・Runner構築 |
| γ | **GitLab.com の無料アカウント**に検証用プロジェクトを作る。ただし並列デプロイは同じく Premium 以上なので、**Free では検証できない範囲が残る** | 中。ただし目的を果たせない |

### GitHub Pages は「可視性設定に従う」を満たせない

計画では「可視性設定と一致するかを確認する」としていたが、**確認したら一致しなかった**。
private / internal リポジトリでも Pages サイトは既定でインターネットに公開され、非公開にできるのは
GitHub Enterprise Cloud のみである。

これは**受け入れ条件を満たすためにワークフロー側のガードが必要**という形で設計へ跳ね返る。
「追加の認証・自動失効等の制御は行わない」というスコープ外の項目とは矛盾しない
（**制御を足すのではなく、条件を満たせないときにデプロイしない**という判断であるため）。

## 残課題

- **GitLab側の検証方針（上記 α / β / γ）の決定。** flow-id 2-8 のレビューで人間の判断を仰ぐ。
- **GitHub Pages の有効化。** フェーズ3の最初に行う。リポジトリ設定を変更するため、
  実行前にユーザーへ知らせる。
- **`gh-pages` ブランチの掃除。** PR単位のディレクトリはマージ後も残る。今回のスコープでは
  「寿命の制御は行わない」ため放置するが、**溜まり続けることは事実**なので、別issueの候補として
  記録しておく。
