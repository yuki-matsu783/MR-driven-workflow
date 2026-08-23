---
title: 報告HTMLのホスト機構の実装結果（issue #114 フェーズ3）
type: report
description: Provider.shへの関数追加・GitHub/GitLabのCI設定・SKILL.mdへの組み込み・配布からの除外・単体テスト・実機検証の実施結果。GitHubは払い出したURLがブラウザで開けるところまで確認し、GitLabはpagesジョブの成功まで確認した。
tags: [issue114, hosting, github-pages, gitlab-pages, report]
keywords: [get_report_site_url, wait_for_report_site, report_site_prefix_to_reply, join_url_to_reply, github_pages_base_url_to_reply, gh-pages, path_prefix, sync-assets, nojekyll, index.html, gitlab-runner]
---

# 報告HTMLのホスト機構の実装結果（issue #114 フェーズ3）

- issue: [#114](https://github.com/yuki-matsu783/MR-driven-workflow/issues/114)
- PR: [#180](https://github.com/yuki-matsu783/MR-driven-workflow/pull/180)（Draft）
- 対応する個別作業計画: `plans/【実装】【テスト】【AIアセット作成】報告HTMLのホストとURL通知.md`

## サマリ（結論の一覧）

| # | 作業 | 結果 | 根拠の性質 |
|---|---|---|---|
| 1 | `Provider.sh` に純粋関数3つ＋公開関数2つを追加 | **完了** | 単体テスト＋**両プロバイダで実行** |
| 2 | `Github.sh` / `Gitlab.sh` にプロバイダ固有実装を追加 | **完了** | **実機で実行**（GitHubは成功経路、GitLabは失敗経路） |
| 3 | GitHub Actions ワークフローを作成 | **完了・実機で成功** | CIが11秒で成功し `gh-pages` が作られた |
| 4 | GitLab CI の `pages` ジョブを作成 | **完了・改変版が実機で成功** | GitLab CE + Runner を構築し、MRパイプラインで `pages` ジョブが成功した。**ただし動かしたのは `pages:` ブロック（`path_prefix` / `expire_in`）を削った CE 版**で、雛形そのものは未実行 |
| 5 | `sync-assets.sh` から `workflows/` と `index.jsonl` を除外 | **完了** | 実際に実行して配布物の中身を確認 |
| 6 | `SKILL.md` への組み込み（flow-id 5-4・5-6・新節・提供関数表） | **完了** | 目視確認 |
| 7 | 単体テスト | **完了**（`passed=237 failures=0`） | 実行結果 |
| 8 | 実機検証 | **GitHubは完了／GitLabは一部未** | 下記「作業8」 |

**払い出されたURLは実際にブラウザで開ける。**
`https://yuki-matsu783.github.io/MR-driven-workflow/pr-180/` が 200 を返し、一覧から各HTMLへ辿れる。

**残っているのは GitLab 側の3点**である——(a) Pages 配信（デーモン未有効。コンテナの再作成が要る）、
(b) `path_prefix` による並列デプロイ（Premium/Ultimate 限定）、(c) `expire_in: never` の効果。
**(b)(c) は配布する雛形の中核**なので、「配信だけが残っている」という言い方はしない。

## 実施条件（測った対象・環境）

- コミット: `50a5fee`（計画の確定）を起点に実装し、`ee5ee1c` でリモートへ反映した。
- 実行環境: Windows 10 / git bash（MSYS）。`jq` は Windows ネイティブ版。
- GitHub: このリポジトリ本体（Public）。Pages を**この作業で有効化した**。
- GitLab: Docker版 `gitlab/gitlab-ce:18.5.4-ce.0`（既存。4日稼働）＋
  `gitlab/gitlab-runner:latest`（**この作業で新規に立てた**）。検証用プロジェクト
  `root/issue114-pages`（id=8）を新規作成した。
- 単体テストは `bash .claude/scripts/test/test_vcs_provider.sh` を直接実行した。
- 配布物の確認は `bash .claude/skills/apply-mr-workflow-to-project/scripts/sync-assets.sh` を
  実際に走らせ、生成された `assets/` の中身を `ls -a` で見た。

## 実施した内容と結果

### 作業1・2: `Provider.sh` / `Github.sh` / `Gitlab.sh`

**純粋関数3つ**（`Provider.sh`）

| 関数 | 決めたこと |
|---|---|
| `report_site_prefix_to_reply <provider> <番号>` | `pr-<番号>` / `mr-<番号>` を `REPLY` へ。**番号が空・非数値、provider が github/gitlab 以外なら非0** |
| `join_url_to_reply <base> <path>` | スラッシュを重複させずに連結。**末尾スラッシュは付けない**（付けるのは `get_report_site_url` の責務） |
| `github_pages_base_url_to_reply <owner> <repo>` | `https://<owner>.github.io/<repo>`。**repo名が `<owner>.github.io` なら `https://<owner>.github.io`** |

**公開関数2つ**（`Provider.sh`）は、どちらも `upload_attachment` と同じ「**失敗は正常系のひとつ**」
として書いた。`get_report_site_url` は `require_vcs_cli` を通し、MR番号を省略したときだけ
`get_mr_for_branch` から取る。`wait_for_report_site` は `curl` で 200 を待ち、
**`curl` が無ければ待たずに非0で終える。**

**プロバイダ固有実装**

- `github_get_report_site_url`: `gh api repos/{owner}/{repo}/pages --jq .html_url` →
  失敗したら `github_pages_base_url_to_reply` で組み立てる。
- `gitlab_get_report_site_url`: `glab api projects/:id/pages` の `.url` → environments API の
  `external_url` → **どちらも引けなければ失敗させる。** GitLabのPagesドメインはインスタンス設定
  （`pages_external_url`）に依存し、GitHubのように規則で組み立てられないため、推測したURLは返さない。
  **プロジェクトの指定は `projects/:id` で行う**（`glab` が現在のリポジトリへ解決する）。
  当初は `get_repo_slug` の `path` を `url_encode_path_to_reply` へ通した値を使っていたが、
  **この関数は `/` を残すため `projects/group/repo/pages` という存在しないルートになり、
  Pagesが正常でも必ず404になっていた**（下記「想定と異なった点」）。

`mcp_tool_hint` には `get_report_site_url` / `wait_for_report_site` の分岐を足し、
`upload_attachment` と同じく**「代替なし」を名指しで返す**形にした。

### 作業3・4: CI設定

**雛形を正とし、実ファイルはそのコピーにした。**

| 雛形（配布物） | 実ファイル |
|---|---|
| `.claude/skills/issue-mr-flow/assets/publish-report-site.github.yml` | `.github/workflows/publish-report-site.yml` |
| `.claude/skills/issue-mr-flow/assets/publish-report-site.gitlab.yml` | `.gitlab-ci.yml` |

バイト一致は `test_vcs_provider.sh` が `cmp -s` で固定している。

**GitHub側で入れたガードと下ごしらえ**

1. `on: push: branches: ['feature-*']`。**`paths` フィルタは付けない**（flow-id 5-6 の削除の反映も
   拾って「0件ならスキップ」で無害化するため）。
2. `concurrency.group: gh-pages-deploy-${{ github.ref }}`（**PR単位**）。
3. 判定1: openなPRがちょうど1件か。判定2: `reports/*.html` ＋ `plans/*.html` が1件以上か。
4. `gh-pages` が無ければ `git switch --orphan` で作る。
5. ルートへ `.nojekyll` を置く。
6. **`pr-<n>/index.html` を生成する**（リンク一覧。Pages はディレクトリ一覧を自動生成しない）。
7. 反映は3回までリトライし、各回の前に `git pull --rebase`。

**GitLab側**は `rules` をMRパイプライン限定にし、`path_prefix: "mr-$CI_MERGE_REQUEST_IID"` ＋
`expire_in: never`。`public/index.html` も同様に生成する。**冒頭コメントで「Free tier / CE では
`pages:` ブロックを削る」ことを指示している。**

**0件のガードは `rules` の `exists` が持つ**（`if` とANDで効く）。当初は script 内の `exit 0` で
済ませていたが、**GitLab Runner は script を1つのシェルスクリプトへ連結して実行するため、
`exit 0` はジョブを「成功」で終わらせ、空の `public` がそのまま artifacts としてアップロード
されて `mr-<iid>/` を空（404）に置き換える**（下記「想定と異なった点」）。script 側に残した
0件判定は「`rules` を通ったのに0件」という想定外の検出だけを担い、**`exit 1` で失敗させる**。

### 作業5: 配布からの除外

`sync-assets.sh` の `.github` 同期を、`cp -R .github/*` から `for` ＋ `case` の除外ループへ変えた。
**`[ … ] && continue` は使っていない**（最後の要素が除外対象だとループの終了コードが1になり、
`set -e` 配下でスクリプトが落ちるため）。

実際に走らせた結果:

```
$ ls -a .claude/skills/apply-mr-workflow-to-project/assets/.github/
.  ..  ISSUE_TEMPLATE  pull_request_template.md
$ ls -a .claude/skills/apply-mr-workflow-to-project/assets/ | grep -c gitlab-ci
0
$ ls .claude/skills/apply-mr-workflow-to-project/assets/.claude/skills/issue-mr-flow/assets/ | grep publish
publish-report-site.github.yml
publish-report-site.gitlab.yml
```

**`workflows/` と `index.jsonl` が消え、`ISSUE_TEMPLATE/` と `pull_request_template.md` は残り、
雛形は `.claude/` 経由で配られている。** `.gitlab-ci.yml` はルート直下ファイルの明示的な
ホワイトリスト（7ファイル）に含めていないため、追加の除外は要らなかった。

### 作業6: `SKILL.md` への組み込み

- flow-id **5-4** の行の**末尾**へ1文を足した（既存の「詳細は下記…節」の係り先を動かさないため、
  追記は行末に置いた）。
- flow-id **5-6** の行へ、`get_report_site_url` → `wait_for_report_site` の呼び出しと
  「**到達性の確認に失敗してもURLは注記つきで提示し、フローは止めない**」を足した。
- 新節「**報告サイトのホストとURL通知（flow-id 5-4・5-6）**」を、
  「最終統括レポートとPR/MRへの反映（flow-id 5-4）」節の直後（`## PRがflow-id 5-5実施前に…` の
  直前）へ入れた。**直前の節の末尾は `### gh/glab CLI不在時` に閉じた文で、次の `##` を挟んでも
  係り先が変わらないことを確認してから挿入した。**
- 「提供関数」の表へ2行を追加した（どちらもMCP側は**代替なし**）。

新節は5つの小節を持つ: なぜ 5-4 でホストし 5-6 で通知するのか／CI側の仕組み／flow-id 5-6 での
呼び出し方／使う前に知っておくこと（配布先向け）／`gh`/`glab` CLI不在時。

### 作業7: 単体テスト

`test_vcs_provider.sh` へ **19件**を追加し、`passed=237 failures=0`。

| 対象 | 件数 | 内容 |
|---|---|---|
| `report_site_prefix_to_reply` | 6 | github / gitlab / 空番号 / 非数値 / provider空 / provider未知 |
| `join_url_to_reply` | 5 | 末尾・先頭スラッシュの4組み合わせ＋空パス |
| `github_pages_base_url_to_reply` | 2 | project site / user・org site |
| `get_report_site_url` の経路 | 2 | 組み立て結果＋**差し替えがサブシェルの外へ漏れていないこと** |
| `mcp_tool_hint` | 1 | 「代替なし」と案内すること |
| 雛形の同一性 | 2 | GitHub側・GitLab側 |
| （既存） | 219 | — |

**経路テストでは4つを差し替えた**（`github_get_report_site_url` / `get_provider` /
`require_vcs_cli` / `_PROVIDER_CACHE`）。差し替えはサブシェルへ閉じ込め、アサーションは外で行って
いる。**`test_vcs_provider.sh` の冒頭コメントも更新した**（「ディスパッチは対象外」に例外が1つ
できたことを明示）。

### 既存テスト一式

| テスト | 結果 |
|---|---|
| `test_block_direct_git_commit.sh` | `passed=26 failures=1`（**`main` 由来。着手時から同じ**） |
| `test_command_position.sh` | `passed=73 failures=2`（**同上**） |
| `test_sync_gemini_assets.sh` | **完走しない**（下記「想定と異なった点」） |
| その他12本 | すべて `failures=0` |

### 作業8: 実機検証

#### GitHub — 払い出したURLがブラウザで開けるところまで確認した

| 順 | やったこと | 結果 |
|---|---|---|
| 1 | ワークフローをリモートへ反映（`ee5ee1c`） | **CIが11秒で成功**（run id 32647820084） |
| 2 | `gh-pages` の中身を確認 | `.nojekyll` と `pr-180/`。`pr-180/` に `index.html` `plans` `reports` |
| 3 | Pages を有効化（`gh api -X POST …/pages`） | `html_url: https://yuki-matsu783.github.io/MR-driven-workflow/` |
| 4 | `get_report_site_url` を実行 | `https://yuki-matsu783.github.io/MR-driven-workflow/pr-180/` |
| 5 | `wait_for_report_site "$url" 120 10` | **200 OK** |
| 6 | `index.html` の中身と、リンク先HTMLの到達性 | 一覧に reports 2件・plans 3件。リンク先も **200** |

**`gh-pages` ブランチは存在しなかったので、ワークフローの orphan 作成の分岐が実際に働いた。**
`.nojekyll` の設置・`index.html` の生成・日本語ファイル名のリンクも、すべて意図どおりだった。

#### GitLab — `pages` ジョブの成功まで確認した

環境をこの作業で構築した。

```bash
docker network create gitlab-net && docker network connect gitlab-net gitlab
( export MSYS_NO_PATHCONV=1
  docker run -d --name gitlab-runner --restart unless-stopped --network gitlab-net \
    -v gitlab-runner-config:/etc/gitlab-runner -v //var/run/docker.sock:/var/run/docker.sock \
    gitlab/gitlab-runner:latest )
# Runner認証トークンは POST /user/runners（runner_type=project_type）で取る
docker exec gitlab-runner gitlab-runner register --non-interactive \
  --url http://gitlab:8929 --token "<token>" \
  --executor docker --docker-image alpine:3.20 --docker-network-mode gitlab-net
# config.toml へ clone_url = "http://gitlab:8929" を足す
```

| 順 | やったこと | 結果 |
|---|---|---|
| 1 | 検証用プロジェクト `root/issue114-pages`（id=8）を作成 | — |
| 2 | `pages:` ブロック（`path_prefix` / `expire_in`）を落とした CE 版の `.gitlab-ci.yml` と、HTMLを2件配置してブランチを反映 | — |
| 3 | MR !1 を作成 | `merge_request_event` のパイプラインが起動 |
| 4 | `pages` ジョブの完了を待つ | **`status=success`**（614秒） |
| 5 | 成果物（`artifacts.zip` 20,613バイト）を取り出して中身を確認 | `public/index.html` / `public/reports/…html` / `public/plans/…html` の3件 |
| 6 | `index.html` の中身 | `MR !1 の計画・レポート` の見出しと、reports・plans のリンク一覧 |

**`rules` がMRパイプライン限定で正しく働き、`$CI_MERGE_REQUEST_IID` も展開された。**
GitHub側と同じスクリプトで、同じ形の `index.html` が生成されている。

#### GitLab — 関数の失敗経路と、0件ガードを実機で確認した

**当初の実機確認は無効だった。** 検証環境の GitLab CE は Pages デーモンを有効にしていないため
`gitlab_get_report_site_url` は非0で終わり、それを「設計どおりの失敗」と読んだ。しかし
**実装のエンドポイント自体が壊れており、Pagesが正常でも404になる状態だった**ため、
観測した404が「Pages未デプロイ」なのか「経路が不正」なのか区別できていなかった。

修正後に、**2つの404を区別できることを実機で確かめた。**

```
$ glab api 'projects/:id'                       → {"id":8,"path_with_namespace":"root/issue114-pages",...}
$ glab api 'projects/:id/pages'                 → {"message":"404 Not Found"}   ← リソースが無い
$ glab api 'projects/root/issue114-pages/pages' → {"error":"404 Not Found"}     ← ルートが無い
```

**`message` と `error` でレスポンスの形が違う。** 前者はPages APIへ到達したうえで「Pagesが
未デプロイ」と言っており、後者はそもそもそのエンドポイントが存在しない。`projects/:id` が
プロジェクトを返すことも併せて、**経路が有効であることと、404の理由がPages未デプロイである
ことの両方**を示せた。

修正後の関数の実行結果は次のとおり。

```
provider=gitlab
gitlab_get_report_site_url → 非0
  「PagesのURLを取得できませんでした（未デプロイの可能性。報告サイトの提示はスキップしてよい）」
get_report_site_url 1     → 非0（同じメッセージを伝播）
report_site_prefix_to_reply gitlab 1 → REPLY=mr-1
```

**成功経路（Pagesが有効な場合）は依然として未確認**である。

#### GitLab — 0件のときジョブが作られないことを確認した

`rules` の `exists` へ変えた効果を、実機で確かめた。検証用MRのブランチから
**`reports/` `plans/` のHTMLをすべて削除**（flow-id 5-5 の片付けと同じ状態）してリモートへ反映した。

| 確認したこと | 結果 |
|---|---|
| MRのHEAD | `c5b39dbc`（削除後のコミット）へ進んだ |
| 新しいパイプライン | **作られなかった**（一覧の最新は削除前の `0e99d345` に対する pipeline 2 のまま） |
| `head_pipeline` | 2（削除前のもの）のまま |

**ジョブが1つも作られないためパイプライン自体が生成されず、直前のデプロイはそのまま残る。**
`exit 0` 版では「成功したジョブが空の `public` をアップロードする」ことになっていたので、
挙動が反転している。

## 確かめられなかったこと

- **GitLab の Pages 配信（＝`gitlab_get_report_site_url` の成功経路）。** 有効化するには
  `pages_external_url` を設定したうえで**コンテナに別ポートを公開する**必要があり、
  稼働中のコンテナを作り直すことになる。**`pages` ジョブが成功し `public/` が正しく作られる
  ところまでは確認済み**である。
- **`expire_in: never` の効果。** `pages:` ブロックごと削った版で検証したため、この指定が
  実際に寿命を延ばすかは見ていない。
- **GitLab の並列デプロイ（`path_prefix`）。** Premium/Ultimate 限定で、CE では実行できない
  （flow-id 2-9 でユーザーが「直列のみ検証でよい」と判断済み）。**検証したのは
  `pages:` ブロックを削った単一デプロイ版**であり、`path_prefix` を含む雛形そのものは動かして
  いない。
- **`concurrency` が実際に直列化する様子。** pushが重なる状況を作っていない。
- **fork からのPR**での挙動。
- **`gh-pages` が既にある状態での2回目以降のデプロイ**（`rm -rf` して置き換える経路）。今回は
  初回のorphan作成の経路しか通っていない。

## 設計への反映

なし（この作業で新しい設計判断は行っていない。すべて計画とフェーズ2の合意どおり）。
**DDR `i0114-01` はフェーズ4で書く。**

## 想定と異なった点

### GitLabのAPIエンドポイントが壊れていた（敵対的レビューで発覚）

`gitlab_get_report_site_url` を `projects/${encoded}/pages` で書いたが、`url_encode_path_to_reply`
は **`/` を残す**仕様（文字クラスが `[a-zA-Z0-9._~/-]`）なので、`projects/group/repo/pages` という
**存在しないルート**になっていた。namespaceを持つ全プロジェクトで、Pagesが正常でも必ず404になる。

**同じファイルの `gitlab_read_file_at_ref` は、まさにこの理由で `${REPLY//\//%2F}` を明示的に
行い、コメントでも述べていた。** 既存の近い関数を読んでから書けば防げた。

**もっと重いのは、この欠陥が「失敗経路を実機で確認した」という当初の結論を無効にしていたこと
である。** 観測した404が「Pages未デプロイ」なのか「経路が不正」なのか区別できていなかった。
**期待する失敗とバグによる失敗が同じ症状になる検証は、何も確かめていない。**
修正後は `message`（リソースが無い）と `error`（ルートが無い）でレスポンスの形が違うことを
使って区別できるようにした（上記「作業8」）。

### GitLabの `exit 0` はガードとして働かない（同上）

script 内の `exit 0` は**ジョブを「成功」で終わらせる**ため、空の `public` がそのまま
artifacts としてアップロードされ、`mr-<iid>/` を空（404）に置き換える。GitHub版は
`deploy=false` で以降のstepごとスキップするので `gh-pages` を一切触らず、**同じガードのつもりで
書いた2つの実装の強さが違っていた。** `rules` の `exists` へ移し、0件ならジョブ自体を作らせない
形にしたうえで、**実機でパイプラインが生成されないことを確認した**。

### `test_sync_gemini_assets.sh` が元から完走しない

計画の検証3は「`main` 由来の3件を除き緑」を合格条件にしていたが、**4本目として
`test_sync_gemini_assets.sh` が完走しない**ことが分かった。
`ln: failed to create symbolic link '/tmp/.../bin/printf'` で止まっており、Windowsでシンボリック
リンクを作る権限が無いのが原因。**`sync-assets.sh` への変更を `git stash` で退避した状態でも
同じ位置で止まる**ことを確認した。**合格条件の解釈を「`main` 由来の3件＋環境依存の1本を除き緑」へ
広げる。**

### `.gitlab-ci.yml` の除外は不要だった

計画では「`.gitlab-ci.yml` には追加の除外が要らない（ホワイトリスト方式のため）」と書いていたが、
**実際に走らせて確認するまでは推測だった。** 走らせた結果、`assets/` 直下に `.gitlab-ci.yml` は
現れなかった（`grep -c` が 0）。**推測どおりだったが、確認して初めて根拠になる。**

### GitLab CE のコンテナに Pages が有効化されていなかった

計画の作業8は「Runner を登録し、`path_prefix` を外した単一デプロイで `pages` ジョブが通ることを
確認する」だったので、**この範囲は達成できた**。ただし、`gitlab.rb` に `pages_external_url` が
無く、コンテナも 8929/2224 しか公開していないため、**Pages としての配信はできない**。
「`pages` ジョブが通ること」と「Pages で配信されること」は別物で、計画はここを区別していなかった。

### 実機のGitLabは応答が不安定だった

`glab api` が `wsarecv: An existing connection was forcibly closed` で断続的に失敗し、
`pages` ジョブ自体も614秒かかった。**リトライを前提に手順を組む必要がある。**
（`curl` で `127.0.0.1` を直接叩くと安定した。`localhost` が IPv6 の `[::1]` へ解決されるのが
一因と思われるが、切り分けはしていない。）

## 残課題

- **GitLab の Pages 配信の検証。** `pages_external_url` を設定し、コンテナへ別ポートを公開して
  作り直せば確認できる。**稼働中のコンテナを作り直すことになるため、ユーザーの判断を仰ぐ。**
  これができると `expire_in: never` の効果も併せて確認できる。
- **敵対的レビュー（フェーズ3・2回目）の未対応6件。** `wait_for_report_site` の `interval=0` で
  無限ループ／`index.html` のHTMLエスケープ漏れ／雛形バイト一致テストが配布先で失敗する／
  `SKILL.md` と YAML の二重管理／`index.jsonl` 除外が `.github/` のみ／`index.md` と
  `directory-structure.md` への追記漏れ。**GitLab以外の指摘は人間のレビュー（flow-id 3-8）を
  待って対応する。**
- **`gh-pages` の掃除は入れていない**（flow-id 2-9 の「恒久公開してよい」という判断による）。
  PR単位のディレクトリは溜まり続ける。**別issueの候補として記録する。**
- **検証用に作った資産の後始末。** GitLab側の `gitlab-runner` コンテナ・`gitlab-net` ネットワーク・
  プロジェクト `root/issue114-pages`（id=8）は、検証が終わったら消してよい。
  **`gitlab-verification-environment.md` へ Runner の構築手順を残すのはフェーズ4の担当。**
