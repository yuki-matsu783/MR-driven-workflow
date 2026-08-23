---
title: 【実装】【テスト】【AIアセット作成】報告HTMLのホストとURL通知
type: plan
description: 調査結果で決めたホスティング手段（GitHub Pages branch方式／GitLab Pages parallel deployments）を実装し、flow-id 5-4でホスト・5-6でURL通知を行う仕組みをProvider.sh・CI設定・SKILL.mdへ組み込むための個別作業計画。
tags: [issue-mr-flow, hosting, github-pages, gitlab-pages]
keywords: [issue114, Provider.sh, get_report_site_url, wait_for_report_site, gh-pages, path_prefix, sync-assets, flow-id 5-4, flow-id 5-6, 単体テスト]
---

# 【実装】【テスト】【AIアセット作成】報告HTMLのホストとURL通知

- issue: [#114](https://github.com/yuki-matsu783/MR-driven-workflow/issues/114)
- PR: [#180](https://github.com/yuki-matsu783/MR-driven-workflow/pull/180)（Draft）
- 全体作業計画: `plans/binary-soaring-eclipse.md`
- 前段の調査結果: `reports/20260823_binary-soaring-eclipse_ホスティング手段の比較.md`

## 前提（合意状況）

**この計画は新しい設計判断を行わない。** 下表はすべてフェーズ2で合意済みで、根拠は前段の
調査結果にある。ここでは「決まったことをどう実装するか」だけを書く。

| 前提 | 合意した flow-id |
|---|---|
| ホストは flow-id **5-4**、通知は **5-6**（案(b)） | 2-4 |
| GitHub は Pages「Deploy from a branch」方式（`gh-pages` の `pr-<PR番号>/`） | 2-8 |
| GitLab は Pages parallel deployments（`path_prefix: "mr-$CI_MERGE_REQUEST_IID"`） | 2-8 |
| ホスト対象に `plans/*.html` も含める | 2-8 |
| 可視性によるガードを入れず**恒久公開**する。`gh-pages` の掃除も入れない | 2-9 |
| GitLab は**実装は並列のまま・実機検証は直列（単一デプロイ）まで** | 2-9 |
| CI設定は**配布しない**（`sync-assets.sh` から除外する） | 2-8 |
| 未解決スレッド10件を残したままフェーズ2を閉じてよい | 2-9 |

**この計画で決めること**（レビューで覆してよい）は、下記「方針」の**関数名・ファイル名・
テストの粒度**の3つだけである。

## この計画で何をするか

調査結果「設計への反映」の6項目を実装する。**種別を3つ併記している**のは、`Provider.sh` の
関数（実装）・その単体テスト（テスト）・`SKILL.md` への組み込み（AIアセット作成）が
**1つの機能を構成しており、分けても合意の単位が変わらない**ためである
（`SKILL.md` の「種別を複数併記する場合／分ける場合」の基準による）。**フェーズ4の反映
（spec・DDR）はこの計画に含めない。**

## 変更対象

| ファイル | 操作 | 何をするか |
|---|---|---|
| `.claude/scripts/src/vcs/Provider.sh` | 変更 | 純粋関数2つ＋公開関数2つを追加し、プロバイダへ振り分ける |
| `.claude/scripts/src/vcs/Github.sh` | 変更 | `github_get_report_site_url` を追加 |
| `.claude/scripts/src/vcs/Gitlab.sh` | 変更 | `gitlab_get_report_site_url` を追加 |
| `.claude/skills/issue-mr-flow/assets/publish-report-site.github.yml` | 新規 | GitHub Actions ワークフローの**雛形**（配布物） |
| `.claude/skills/issue-mr-flow/assets/publish-report-site.gitlab.yml` | 新規 | GitLab CI の `pages` ジョブの**雛形**（配布物） |
| `.github/workflows/publish-report-site.yml` | 新規 | 上の雛形と**同一内容**。このリポジトリ自身で動かすもの |
| `.gitlab-ci.yml` | 新規 | 同上（GitLab側） |
| `.claude/skills/apply-mr-workflow-to-project/scripts/sync-assets.sh` | 変更 | `.github/` の一括コピーから `workflows/` を除外する |
| `.claude/skills/issue-mr-flow/SKILL.md` | 変更 | flow-id 5-4・5-6 の行と、新節「報告サイトのホストとURL通知」、提供関数の表、MCPフォールバックの表 |
| `.claude/scripts/test/test_vcs_provider.sh` | 変更 | 追加関数の単体テスト |

## 方針

### 作業1: `Provider.sh` に4つの関数を足す

**純粋関数2つ（単体テストの対象）**

| 関数 | 役割 | 戻り値 |
|---|---|---|
| `report_site_prefix_to_reply <provider> <番号>` | サブディレクトリ名を決める | `REPLY` に `pr-<番号>`（github）／`mr-<番号>`（gitlab） |
| `join_url_to_reply <base> <path>` | ベースURLとパスを連結する | `REPLY` に連結結果 |

- どちらも外部コマンド・コマンド置換を含めない（`.claude/rules/shell-script-style.md`
  「ホットパスの小さなヘルパー関数は `REPLY` へ返す」）。
- `join_url_to_reply` は、`base` の末尾スラッシュの有無・`path` の先頭スラッシュの有無を
  吸収して**スラッシュが重複しない**ようにする。空の `path` を渡した場合は `base` をそのまま返す。
- `report_site_prefix_to_reply` は、番号が空・非数値なら**非0で終える**（呼び出し側が
  「URLを組み立てられない」として扱えるようにする）。

**公開関数2つ**

```
get_report_site_url [<MR番号>]
  成功: URL（末尾スラッシュ付き）をstdoutへ / 終了コード0
  失敗: 理由をstderrへ / 終了コード非0

wait_for_report_site <url> [<上限秒=90>] [<間隔秒=5>]
  到達: 終了コード0
  未到達: 理由をstderrへ / 終了コード非0（上限に達した場合も含む）
```

- **`upload_attachment` と同じく「失敗は正常系のひとつ」**とする。呼び出し側（flow-id 5-6）は
  非0を受け取ったら注記だけ出してフローを続ける。関数の直上コメントにもその旨を書く
  （既存の `upload_attachment` の書き方に揃える）。
- MR番号を省略したときは `get_mr_for_branch` の結果から取る。**番号の導出はこの1経路に
  一本化する**（調査結果「設計への反映」1）。この関数はJSONを返すので `jq -r '.number'` で
  取り出す（値は1行なので `tr -d` は挟まない）。
- `wait_for_report_site` は `curl -sS -o /dev/null -w '%{http_code}'` で 200 を待つ。
  **`curl` が無い環境では即座に非0で終える**（待ち続けない）。

### 作業2: プロバイダ固有のURL取得

| プロバイダ | 一次経路 | フォールバック |
|---|---|---|
| GitHub | `gh api repos/{owner}/{repo}/pages --jq .html_url` | `https://<owner>.github.io/<repo>` を組み立てる |
| GitLab | `glab api projects/:id/pages --jq .url` | environments API から `external_url` を引く |

- 取得したベースURLへ `report_site_prefix_to_reply` の結果を `join_url_to_reply` で足す。
- **CLI不在（MCP経路）では `require_vcs_cli` で非0にする。** MCPにはPages情報を引くツールが
  無いため、フォールバックの組み立てだけを行う経路は用意しない（**URLが正しいと確認できない
  まま提示するほうが害が大きい**ため）。この判断は `mcp_tool_hint` にも1行として載せる。

### 作業3: GitHub Actions ワークフロー

`.github/workflows/publish-report-site.yml` を新規作成する。要点だけを示す（全文は実装時）。

```yaml
on:
  push:
    branches: ['feature-*']     # paths フィルタは付けない（削除pushも拾う必要がある）
concurrency:
  group: gh-pages-deploy
  cancel-in-progress: false     # 直列化する。取り消すと片方のデプロイが失われる
permissions:
  contents: write
  pull-requests: read
```

ジョブは次の順で判定する。**どちらかで外れたら何もせず正常終了する**（`exit 0`）。

1. **openなPRがちょうど1件か。** `gh pr list --head "$GITHUB_REF_NAME" --state open --json number`
   の件数が1でなければスキップ（0件＝PR作成前、複数件＝どれへ載せるか決まらない）。
2. **対象HTMLが1件以上あるか。** `reports/*.html` ＋ `plans/*.html` の件数が0ならスキップ。
   **これが flow-id 5-6 の削除で送られる変更を無害化する仕掛けである**（`gh-pages` 側の
   `pr-<n>/` は触られないので残る）。

デプロイは `gh-pages` ブランチを `checkout` し、`pr-<n>/reports/` `pr-<n>/plans/` を
**置き換えて**（`rm -rf` してから `cp`）リモートへ反映する。**反映は3回までリトライし、
各回の前に `git pull --rebase` する**（`concurrency` は同一リポジトリ内の直列化しか担保せず、
手動実行等と競合しうるため）。

### 作業4: GitLab CI

`.gitlab-ci.yml` を新規作成する。

```yaml
pages:
  stage: deploy
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
  pages:
    path_prefix: "mr-$CI_MERGE_REQUEST_IID"
    expire_in: never
  artifacts:
    paths: [public]
```

- `script` で `reports/*.html` `plans/*.html` を `public/` へ集め、**0件なら `exit 0` で
  ジョブを終える**（GitHub側と同じガード）。
- `path_prefix` が**空文字列に展開されると本番サイトを上書きする**ため、
  `$CI_MERGE_REQUEST_IID` が空なら `rules` で弾かれることを、コメントで明記する。

### 作業5: 配布からの除外

`sync-assets.sh` の `.github` 同期を、`workflows/` を除いたコピーへ変える。

**置き換え前**（`.claude/skills/apply-mr-workflow-to-project/scripts/sync-assets.sh`）

```bash
if [ -d "${PROJECT_ROOT}/.github" ]; then
  echo "Syncing .github templates..."
  mkdir -p "${ASSETS_DIR}/.github"
  cp -R "${PROJECT_ROOT}/.github/"* "${ASSETS_DIR}/.github/"
fi
```

**置き換え後**

```bash
if [ -d "${PROJECT_ROOT}/.github" ]; then
  echo "Syncing .github templates..."
  mkdir -p "${ASSETS_DIR}/.github"
  # workflows/ は配布しない（issue #114）。配布先のCI設定を上書きしうるうえ、
  # Pages の有効化・ブランチ運用は配布先ごとに異なる。雛形は
  # .claude/skills/issue-mr-flow/assets/publish-report-site.*.yml として配る。
  for entry in "${PROJECT_ROOT}/.github/"*; do
    [ -e "$entry" ] || continue
    [ "${entry##*/}" = "workflows" ] && continue
    cp -R "$entry" "${ASSETS_DIR}/.github/"
  done
fi
```

- **`ISSUE_TEMPLATE/` と `pull_request_template.md` は従来どおり配布される**（この2つが
  `.github/` 配下の既存の中身であり、除外してはいけない）。
- **`[ … ] && continue` を `set -e` 配下で使わない。** 最後の要素が `workflows` だった場合に
  ループ全体の終了コードが1になり、スクリプトが落ちる。実装では `if … then continue; fi` にする。
- `install-to-project.sh` 側は変更しない（`assets/` に無いものは配布されないため、
  除外は `sync-assets.sh` の1箇所で完結する）。

### 作業6: `SKILL.md` への組み込み

**(a) flow-id 5-4 の行**

**置き換え前**（末尾）

```
… サマリを `add_mr_comment` でPR/MRへ1回投稿する）。**反映は3層のフォールバック構造**で、層3が壊れても層1・層2でレビューは成立する。詳細は下記「最終統括レポートとPR/MRへの反映（flow-id 5-4）」節 | エージェント |
```

**置き換え後**（1文を足すだけ。既存の3層構造には手を入れない）

```
… サマリを `add_mr_comment` でPR/MRへ1回投稿する）。**反映は3層のフォールバック構造**で、層3が壊れても層1・層2でレビューは成立する。**層1のリモート反映がCIを起動し、報告HTMLがPR/MR単位のURLへホストされる**（AIエージェントがここで行う操作は無い。URLの提示は flow-id 5-6。詳細は下記「報告サイトのホストとURL通知（flow-id 5-4・5-6）」節）。詳細は下記「最終統括レポートとPR/MRへの反映（flow-id 5-4）」節 | エージェント |
```

**(b) flow-id 5-6 の行**

**置き換え前**

```
| 5-6 | `commit`スキル経由でcommitし、push して Draftを解除する（解除は `source .claude/scripts/src/vcs/Provider.sh && set_mr_ready <MR番号>` で行う。… MR番号は `get_mr_for_branch` で取得できる）。**AIエージェントはここで止まる**（マージへは進まない） | エージェント |
```

**置き換え後**

```
| 5-6 | `commit`スキル経由でcommitし、push して Draftを解除する（解除は `source .claude/scripts/src/vcs/Provider.sh && set_mr_ready <MR番号>` で行う。… MR番号は `get_mr_for_branch` で取得できる）。**続けて、flow-id 5-4 でホストされた報告サイトのURLをユーザーへ提示する**（`get_report_site_url` → `wait_for_report_site`。**到達性の確認に失敗してもURLは注記つきで提示し、フローは止めない**。詳細は下記「報告サイトのホストとURL通知（flow-id 5-4・5-6）」節）。**AIエージェントはここで止まる**（マージへは進まない） | エージェント |
```

**(c) 新節「報告サイトのホストとURL通知（flow-id 5-4・5-6）」**

「最終統括レポートとPR/MRへの反映（flow-id 5-4）」節の**直後**へ置く。**直前の節の末尾が
節全体にかかる地の文で終わっていないことを、挿入前に確認する**
（`.claude/rules/docs-workflow.md`「既存ドキュメントへ新しい見出しを差し込むときは」）。
内容は次のとおり。

- なぜ 5-4 でホストし 5-6 で通知するのか（対象ファイルは 5-5 で消えるため）
- **5-5 は commit もリモート反映も持たない**こと。削除の確定と通知はどちらも 5-6 にあり、
  **到達性確認は削除の確定より後**に行うこと
- 到達性確認の仕様（5秒間隔・最大90秒。上限到達時は注記つきで提示しフローを止めない）
- 呼び出し方のコード例（`upload_attachment` の節と同じ体裁）
- CIが無い・失敗する環境での扱い（**URLが得られなくてもフローを止めない**）
- 配布先が private リポジトリの場合、**中身が公開される**という注意

**(d) 提供関数の表・MCPフォールバックの表**

`get_report_site_url` / `wait_for_report_site` の行を足す。**MCP側は「代替なし」**で、
`upload_attachment` の行と同じ書き方に揃える。

### 作業7: 単体テスト

`.claude/scripts/test/test_vcs_provider.sh` へ追加する。**外部プロセスを起動しないもの**に限る。

| 対象 | ケース |
|---|---|
| `report_site_prefix_to_reply` | github→`pr-180` / gitlab→`mr-7` / 空番号→非0 / 非数値→非0 |
| `join_url_to_reply` | 末尾スラッシュあり・なし × 先頭スラッシュあり・なし の4通り / 空パス |
| `get_report_site_url` | **呼び出し経路を通す**（`github_get_report_site_url` をサブシェル内で差し替え、組み立て結果を確認する） |
| 雛形の同一性 | `.github/workflows/publish-report-site.yml` と `assets/publish-report-site.github.yml` が**バイト単位で一致**する。`.gitlab-ci.yml` と `assets/publish-report-site.gitlab.yml` も同様 |

- 関数の差し替えは**サブシェルへ閉じ込め**、アサーションはサブシェルの外で行う
  （`.claude/rules/shell-script-style.md`「テスト内で既存関数を再定義してから `unset -f`」）。
- 終了コードの検査に `"$(func; echo $?)"` の形を使わない（`if` で受ける。同ルール「テスト」節）。
- `wait_for_report_site` は `curl` を起動するため単体テストの対象外とし、**実機検証で確かめる**。

### 作業8: 実機検証

| 対象 | 手順 |
|---|---|
| GitHub Pages の有効化 | **リポジトリ設定を変更するため、実行前にユーザーへ知らせる**（調査結果「残課題」）。`gh api -X POST repos/{owner}/{repo}/pages` で `gh-pages` / `/` を publishing source に設定する |
| GitHub のデプロイ | このPRのブランチをリモートへ反映し、`pr-180/reports/…html` がブラウザで開けることを確認する |
| GitLab（直列のみ） | Docker版 GitLab CE に Runner を登録し、`path_prefix` を**外した**単一デプロイで `pages` ジョブが通ることを確認する。**並列部分は実機未検証と明記する** |

## やらないこと（スコープ外）

- **`gh-pages` ブランチの掃除**（PR単位ディレクトリはマージ後も残る）。恒久公開の判断（flow-id 2-9）
  により今回は放置し、別issueの候補として `reports/` へ記録する
- **可視性によるデプロイのガード**（flow-id 2-9 の判断）
- **GitLab の並列デプロイの実機検証**（CE では不可能。flow-id 2-9 の判断）
- **spec・DDRへの反映**（フェーズ4）
- **`main` 由来の既存テスト失敗3件の修正**（flow-id 2-4 でスコープ外と合意済み）
- 既存の `upload_attachment`（flow-id 5-4 層3）の置き換え。**添付とホスティングは併存させる**

## 検証

```bash
# 1. 構文チェック
bash -n .claude/scripts/src/vcs/Provider.sh
bash -n .claude/scripts/src/vcs/Github.sh
bash -n .claude/scripts/src/vcs/Gitlab.sh
bash -n .claude/skills/apply-mr-workflow-to-project/scripts/sync-assets.sh

# 2. 単体テスト（追加分を含む）
bash .claude/scripts/test/test_vcs_provider.sh

# 3. 既存テスト一式（main由来の3件を除き緑であること）
for f in .claude/scripts/test/test_*.sh; do echo "--- $f"; bash "$f" | tail -1; done

# 4. 配布物に workflows/ が入らないこと
bash .claude/skills/apply-mr-workflow-to-project/scripts/sync-assets.sh
ls .claude/skills/apply-mr-workflow-to-project/assets/.github/

# 5. ワークフロー定義がGitHubに認識されること
gh workflow list
```

**合格条件**:
(1) `test_vcs_provider.sh` が `failures=0`、
(2) 検証4で `workflows` が現れず `ISSUE_TEMPLATE` と `pull_request_template.md` は残る、
(3) GitHub で `pr-180/reports/…html` がブラウザで開ける、
(4) GitLab CE で `pages` ジョブが直列構成で成功する、
(5) `SKILL.md` の flow-id 5-4・5-6 と新節に、上記の呼び出し方が書かれている。
