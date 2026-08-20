---
title: worklog 20260820 【調査】GitLab13関数とURL形式の実機検証 push2
type: log
description: issue #127のフェーズ2〈調査〉の試行錯誤ログ。検証環境の接続手段の切り分けとProvider.sh経由検証の準備。
tags: [worklog, gitlab, verification]
keywords: [GitLab CE, glab, PAT, ssh, credential helper, Provider.sh, split_remote_url, 差分アンカー]
---

# worklog: 【調査】GitLab13関数とURL形式の実機検証

対象: ローカルGitLab CE 18.5.4に対する `Gitlab.sh` 未検証13関数・URL系4種・サブグループ解決の
実機検証（2026-08-20）。
全体作業計画: `plans/zippy-petting-crown.md`
個別作業計画: `plans/【調査】GitLab13関数とURL形式の実機検証.md`
push回数: 2

## 試したこと

- **環境の生存確認**: `docker ps` でコンテナ `gitlab` が `Up 20 hours (healthy)`、
  ポート `8929->8929`・`2224->22` を確認。`glab --version` は 1.114.0。
- **`glab` の認証確認**: `glab auth status` で `localhost:8929` に `root` でログイン済み
  （keyring）。同時に `gitlab.com` 側が401で、コマンド全体の**終了コードが2になる**ことが分かった。
  `localhost:8929` の行だけを見れば正常。
- **既存プロジェクトの棚卸し**: `glab api "projects?membership=true"` で
  `root/issue45-verify`（id=1）のみ実質稼働。他2件は `deletion_scheduled`。
  id=1 には branches 4本（`main` / `feature-1-verify` / `feature-2-reverify` /
  `issue77-inline-test`）、MR 3件、issue 2件が残っている。
- **接続手段の切り分け**（クローンできないと `Provider.sh` 経由の検証自体が成立しないため最優先）:
  1. ssh: `ssh -p 2224 -o BatchMode=yes git@localhost` → `Permission denied (publickey)`。
  2. 素のhttp: `git clone http://localhost:8929/root/issue45-verify.git` →
     `warning: auto-detection of host provider took too long (>2000ms)` のあと
     `fatal: helper error (143): Unknown`。Git Credential Managerが介在している。
  3. http + PAT + GCM無効化:
     `git -c credential.helper= clone "http://oauth2:<PAT>@localhost:8929/root/issue45-verify.git"`
     → 成功。
- **クローン上での `Provider.sh` 動作確認**（本番検証の前の素振り）:
  `source <本リポジトリ>/.claude/scripts/src/vcs/Provider.sh` してから
  `get_provider` / `get_repo_url` / `get_repo_slug` / `get_workflow_config` を実行。

## うまくいったこと

- **接続手段は「http + PAT + `-c credential.helper=`」に確定**。ssh鍵の登録は本issueの目的では
  ないので行わない、という切り分けができた。
- **`get_provider` が `gitlab` を返した**。issue #45 の修正（`*github*` 以外はGitLab）が
  localhost に対して効いていることを、実クローン上で確認できた。
- **URLに埋めたPATが生成URLへ漏れないことを確認**した。
  `get_repo_url` → `http://localhost:8929/root/issue45-verify`、
  `get_repo_slug` → `{"host":"localhost","owner":"root","repo":"issue45-verify",...}`。
  `split_remote_url` が「最初の `/` より前に `@` があるときだけ `user@` を落とす」実装に
  なっているため（パスに `@` を含むURLで誤爆しない作り）。
- **`.mrworkflow.json` を持たない検証用クローンでも `get_workflow_config` が既定値で動く**ことを
  確認。既定値は本リポジトリの `.mrworkflow.json` と同値のため、検証結果に影響しない。
- 既存MRに `Draft: Draft: 検証MR` という**二重の `Draft:` 接頭辞**が付いたものを見つけた。
  `gitlab_set_mr_ready`（#3）の検証で、`glab` 側の除去正規表現
  `(?i)^(\s*(?:draft:|wip:)\s*)*` が繰り返しにマッチするかを試す入力として使える。

## ダメだったこと

- ssh経路（公開鍵未登録）と、素のhttpクローン（GCMが介在）。いずれも上記のとおり回避した。
- `glab auth status` を成功判定に使うこと。`gitlab.com` の401に引きずられて終了コードが2になる
  ため、`set -e` 配下で素朴に呼ぶと止まる。トークン取得は `--show-token` の出力から
  `grep -oE 'glpat-[A-Za-z0-9._-]+'` で拾い、終了コードは見ない形にした。

## 次の一歩

- flow-id 2-2: 個別調査計画・worklog・HANDOFF.mdをコミットしてリモートへ反映し、
  **敵対的レビュー**を実施したうえでレビュー依頼を出す。
- flow-id 2-6: 検証用プロジェクト `root/issue127-verify` と
  サブグループ `grp127/sub127/issue127-verify-sub` を作り、グループA〜Dの検証を実施する。

---
