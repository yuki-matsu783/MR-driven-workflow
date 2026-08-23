---
title: 報告HTMLのホスト機構の実装結果（issue #114 フェーズ3）
type: report
description: Provider.shへの関数追加・GitHub/GitLabのCI設定・SKILL.mdへの組み込み・配布からの除外・単体テストの実施結果と、実機検証を残していることの記録。
tags: [issue114, hosting, github-pages, gitlab-pages, report]
keywords: [get_report_site_url, wait_for_report_site, report_site_prefix_to_reply, join_url_to_reply, github_pages_base_url_to_reply, gh-pages, path_prefix, sync-assets, nojekyll, index.html]
---

# 報告HTMLのホスト機構の実装結果（issue #114 フェーズ3）

- issue: [#114](https://github.com/yuki-matsu783/MR-driven-workflow/issues/114)
- PR: [#180](https://github.com/yuki-matsu783/MR-driven-workflow/pull/180)（Draft）
- 対応する個別作業計画: `plans/【実装】【テスト】【AIアセット作成】報告HTMLのホストとURL通知.md`

## サマリ（結論の一覧）

| # | 作業 | 結果 | 根拠の性質 |
|---|---|---|---|
| 1 | `Provider.sh` に純粋関数3つ＋公開関数2つを追加 | **完了** | 単体テストで確認 |
| 2 | `Github.sh` / `Gitlab.sh` にプロバイダ固有実装を追加 | **完了** | 構文チェックと経路テストのみ（**API呼び出しは実機未検証**） |
| 3 | GitHub Actions ワークフローを作成 | **完了（未実行）** | 静的な作成のみ。**CIとしては1度も走っていない** |
| 4 | GitLab CI の `pages` ジョブを作成 | **完了（未実行）** | 同上。**GitLab環境そのものが未構築** |
| 5 | `sync-assets.sh` から `workflows/` と `index.jsonl` を除外 | **完了** | 実際に実行して配布物の中身を確認 |
| 6 | `SKILL.md` への組み込み（flow-id 5-4・5-6・新節・提供関数表） | **完了** | 目視確認 |
| 7 | 単体テスト | **完了**（`passed=237 failures=0`） | 実行結果 |
| 8 | 実機検証 | **未実施** | リポジトリ設定を変えるため、ユーザーへ知らせてから行う |

**この時点で「動く」と言えるのは 1・5・7 だけである。** 2・3・4 は**書いただけ**で、CI が1度も
走っていない。

## 実施条件（測った対象・環境）

- コミット: `50a5fee`（計画の確定）を起点に実装した。
- 実行環境: Windows 10 / git bash（MSYS）。`jq` は Windows ネイティブ版。
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
| `test_sync_gemini_assets.sh` | **完走しない**（下記） |
| その他12本 | すべて `failures=0` |

**`test_sync_gemini_assets.sh` が完走しないのは、本ブランチの変更とは無関係である。**
`ln: failed to create symbolic link '/tmp/.../bin/printf'` で止まっており、Windowsでシンボリック
リンクを作る権限が無いことが原因。**`sync-assets.sh` への変更を `git stash` で退避した状態でも
同じ位置で止まることを確認した**（変更の有無で挙動が変わらない）。

## 確かめられなかったこと

- **CIが1度も走っていない。** ワークフローの構文・ガードの判定・`gh-pages` への反映・
  `index.html` の生成は、**すべて机上のままである。**
- **`gh api repos/{owner}/{repo}/pages` の応答を見ていない**（Pagesが未有効なため、現状は404が
  返る想定だが未確認）。フォールバック経路が実際に使われるかも未確認。
- **GitLab側は環境そのものが無い。** Docker版 GitLab CE も Runner も未構築である。
- `wait_for_report_site` は `curl` を起動するため単体テストの対象外にした。**1度も実行していない。**

## 設計への反映

なし（この作業で新しい設計判断は行っていない。すべて計画とフェーズ2の合意どおり）。
**DDR `i0114-01` はフェーズ4で書く。**

## 想定と異なった点

### `test_sync_gemini_assets.sh` が元から完走しない

計画の検証3は「`main` 由来の3件を除き緑」を合格条件にしていたが、**4本目として
`test_sync_gemini_assets.sh` が完走しない**ことが分かった。環境依存（シンボリックリンクの権限）で
あり、変更の有無で挙動が変わらないことを `git stash` で確認済み。**合格条件の解釈を
「`main` 由来の3件＋環境依存の1本を除き緑」へ広げる。**

### `.gitlab-ci.yml` の除外は不要だった

計画では「`.gitlab-ci.yml` には追加の除外が要らない（ホワイトリスト方式のため）」と書いていたが、
**実際に走らせて確認するまでは推測だった。** 走らせた結果、`assets/` 直下に `.gitlab-ci.yml` は
現れなかった（`grep -c` が 0）。**推測どおりだったが、確認して初めて根拠になる。**

## 残課題

- **作業8（実機検証）が丸ごと残っている。** `gh-pages` の作成・Pages の有効化・デプロイの確認・
  GitLab CE + Runner の構築。**リポジトリ設定を変える操作を含むため、ユーザーへ知らせてから行う。**
- **ワークフローをリモートへ反映した時点でCIが走る。** つまり「反映」そのものが実機検証の開始で
  あり、`gh-pages` ブランチが自動的に作られる。この点もユーザーへ伝えたうえで行う。
- `gh-pages` の掃除は入れていない（flow-id 2-9 の「恒久公開してよい」という判断による）。
  **別issueの候補として記録する。**
