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

# 追記: flow-id 2-6（検証の実施）

## 試したこと

- 検証環境の構築: `root/issue127-verify`（id=4）を新規作成 → http+PAT でクローン →
  **クローン直後に `git remote set-url origin` でPATを外した**（残存0件を `grep -c 'glpat-'` で確認）
  → 日本語＋スペースを含むパスを含む初期コンテンツを `main` へ、差分を `feat-127` へ。
- **コミットhookの誤検知に遭遇**: 検証用クローンでのgitの直接のコミット実行も
  `block-direct-git-commit.sh` にブロックされた。`create-commit.sh` はcwd依存の薄いラッパーで
  リポジトリルートを前提にしないため、**検証用クローンでもそのまま使えた**。
- 差分アンカーの直接証拠を取るため、Compareページを3通りの方法で取得した。
  1. `PRIVATE-TOKEN` ヘッダ付き → **302**（サインインへ）。PATはAPIにしか効かない。
  2. プロジェクトをpublicにして取得 → 200だが**ハッシュが1件も含まれない**（34,578バイト）。
  3. 初期HTML内に埋め込まれたエンドポイント定義から `diffs_stream` を特定して取得 → **一致**。
- `#13` を2回実行して `summary_post_kind` の両分岐を通した。事前に不正パスを `glab api` で
  単体POSTし、**400で拒否されること**を確かめてから本番へ進んだ。
- `#5`/`#6` の裏取りとして、GitLab自身が `discussions.json` で返す `noteable_note_url` と
  `gitlab_get_note_url` の出力を突き合わせた。

## うまくいったこと

- **差分アンカーの `sha1` 前提が正しいことを確定できた。** `diffs_stream` 断片の `id=` 属性、
  `diff_files_metadata` の `file_hash`、`sha1sum` の3つが一致。`diff-` 接頭辞は付かない。
  ハッシュ入力は**percent-encode前の生パス**で、blobリンク（encode必須）とは逆である点も判明。
- **不具合を1件検出**: `gitlab_get_repo_url` が未定義のまま Gitlab.sh:162,180 から呼ばれている。
  `2>/dev/null` で `command not found` が握りつぶされ、無言でurl無しへ縮退していた。
- **その不具合が「関数の数が合わない」問題の正体でもあった。** `#48` 当時の関数一覧と現在を
  `comm` で突き合わせたところ、消えた唯一の関数がこれだった（`13 - 1 + 13 = 25`）。
- **混入経路まで特定できた。** `7ebc615`（issue #42、呼び出し追加）と `8d01fbb`（issue #44、
  定義削除）は**並行ブランチ**（merge-base `7f089a5`）で、どちらも単体では正しい。
  gitがコンフリクトと見なさない semantic conflict だった。
- 同種の点検として全関数呼び出しを定義一覧と突き合わせ、**未定義の呼び出しはこの1件のみ**と確認。

## ダメだったこと

- `new_issue "..." "..." 2>&1 | jq` が `parse error: Invalid numeric literal`。
  `glab issue create` の進捗行 `- Creating issue in <project>` を **stderr から stdout へ
  混ぜてしまった**のが原因で、関数自体は正常。`2>/dev/null` にすれば stdout は純粋なJSON。
  **検証時に `2>&1` を癖で付けると、正常な関数を不具合と誤認する。**
- `new_draft_merge_request` を `xargs` へパイプした行が2分でタイムアウトした。MR自体は作成
  済みだった。`glab` の対話待ちが疑われるため、以降は単独実行＋`timeout` で回した。
- `git diff --cached --name-only` の8進エスケープを忘れ、`create-commit.sh` へ
  日本語パスを渡して「gitが把握していません」で1回失敗した（`-z` + `read -r -d ''` で解決）。

## 次の一歩

- flow-id 2-7: reports（md/html）・worklog・HANDOFFをコミットしリモートへ反映し、
  敵対的レビュー（フェーズ2・2回目）を実施したうえでレビュー依頼。
- **ユーザーへブラウザ目視確認を依頼する**（URL系4種の代表1本ずつ）。
- フェーズ3: `gitlab_get_repo_url` → `get_repo_url` の修正（2箇所）と、
  `get_mr_url` / `get_note_url` のディスパッチャ追加。

---
