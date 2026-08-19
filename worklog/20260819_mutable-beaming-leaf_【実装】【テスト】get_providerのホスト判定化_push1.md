---
title: worklog 20260819 get_providerのホスト判定化
type: log
description: issue #45（get_providerがself-hosted GitLabを判定できない）の実装・テストの試行錯誤ログ
tags: [worklog, gitlab, vcs-provider]
keywords: [get_provider, ホスト判定, self-hosted, glab, remote URL, パラメータ展開, 純粋関数]
---

# worklog: 【実装】【テスト】get_providerのホスト判定化

対象: issue #45 のフェーズ3（実装・テスト）（2026-08-19）。
全体作業計画: `plans/mutable-beaming-leaf.md`
個別作業計画: `plans/【実装】【テスト】get_providerのホスト判定化.md`
push回数: 1

## 試したこと

### 判定方式の実測比較（全体作業計画の根拠）

「glabに登録済みのホストか」を判定に使う案を検討し、コストを実測した。

| 方式 | 実測 | メモ |
|---|---|---|
| `glab auth status` | **14.5秒** | ホストごとにネットワーク接続する。停止中のコンテナがあると接続タイムアウトぶんさらに延びる |
| `glab config get token --host <host>` | 0.55〜0.9秒 | オフラインで既知/未知を判別できる。既知→token非空、未知→空 |
| `config.yml` 直読み | 0.1秒 | `hosts:` に登録ホストが並ぶ。ただし配置は `%LOCALAPPDATA%/glab-cli/config.yml` |

`config.yml` の場所が想定と違った点は記録しておく。glabの一般的なドキュメントは
`~/.config/glab-cli/config.yml` だが、**この環境（Windows）では `%LOCALAPPDATA%/glab-cli/`** にあり、
`~/.config/glab-cli/` は存在しなかった。OS依存パスを自前で解決するのは脆いと判断する材料になった。

### `get_provider` はメモ化できない

12個のディスパッチャがいずれも `case "$(get_provider)" in` の形で呼んでいる。
**コマンド置換はサブシェルを作るため、関数内でグローバル変数へ代入してもキャッシュが親に残らない。**
「1回だけ判定して使い回す」を実現するには12箇所を `REPLY` 方式（`.claude/rules/shell-script-style.md`
「ホットパスの小さなヘルパー関数は…`REPLY`へ返す」）へ書き換える必要があり、本issueの範囲を超える。

このため「判定に外部コマンドを足すと12箇所すべてで増える」という制約が効き、
**追加forkゼロで済むホスト判定**を選ぶ根拠になった。

### 未認証時の挙動（ユーザーからの質問で確認）

「glab, ghともにログイン前だとどうなる？」という問いを受けて確認した。

| 状況 | 実測 |
|---|---|
| `glab`: ホスト未登録 | `None of the git remotes configured for this repository point to a known GitLab host` |
| `glab`: ホスト登録済み・トークン無効（gitlab.com） | `{"message":"401 Unauthorized"}` / `glab: 401 Unauthorized (HTTP 401)` |
| `gh`: ログイン済み（今回の環境） | `✓ Logged in to github.com account ...` |

重要なのは、**採用した方式が認証状態に依存しない**こと。`get_provider` は
`git remote get-url origin` を読むだけで `gh`/`glab` を呼ばない。
却下した3方式はいずれも「glabに登録済みのホストか」を見るため、**未ログインでは
self-hosted GitLabを判定できない**。「動かすにはログインが要る」ことと「判定がログインに依存する」ことは
別問題であり、後者は避けるべきだと整理できた。この観点は当初の計画に無く、質問がきっかけで加わった。

### 現行実装のもう1つのバグ

判定を組み立てる過程で、**URL全体への部分一致**であることに起因する別のバグに気づいた。

```
https://gitlab.com/github-mirror/x.git
```

これは `*github.com*` に先にマッチするため、現行実装では `github` を返す。パスに `github.com` を
含むGitLab URLはすべて誤判定する。ホスト部を抽出してから判定すれば同時に解消するため、
回帰テストとしてケースに加えた。

### 社内GitLab（Aslead）の明示ケース追加

計画作成中にユーザーから「host名に `aslead` が入っていたらgitlabにして」という指示があった。

採用した既定規則（`github` を含まなければGitLab）では**すでに `gitlab` になる**ため機能上は冗長だが、
**GitHub判定より前に置く**形で明示ケースとして追加した。理由は2つ。

- ホスト名に `github` と `aslead` が同時に含まれた場合でもGitLabが優先される（順序に意味がある）。
- 実運用する社内インスタンスを名前で明示しておくと、将来この判定規則を変更する際に意図が失われない。

テストも3件足した（`aslead.example.co.jp` / `aslead-git.corp.local`（scp形式）/
`github.aslead.example.com`（優先順位の確認））。

### 実装

計画どおり `Provider.sh` へ純粋関数 `provider_from_remote_url` を新設し、`get_provider` を
`git remote get-url origin` の結果を渡すだけの薄いラッパーにした。パラメータ展開のみで実装し、
外部コマンド・コマンド置換を一切使っていないため追加forkはゼロ。

`tests/test_vcs_provider.sh` に `Provider.sh` のsourceを追加し、ケースを15件足した
（**計画の14件＋「ホスト名が空なら終了コード1」の1件**。旧実装の唯一のエラー経路が
新実装でどこへ移ったかを固定したかったため追加した）。既存11件と合わせて `passed=26 failures=0`。
計画に書いた期待値は25だったので、**実績は26**である。

### `set -e` 配下で終了コードを検査するテストの書き方

「ホスト名が空なら終了コード1」の検査を、最初は次のように書いた。

```bash
"$(provider_from_remote_url 'https://' 2>/dev/null; echo $?)"
```

実行すると期待どおり `1` が返って通ったが、これは**偶然通っているだけの可能性がある書き方**
だと判断して直した。テストスクリプトも `Provider.sh` も `set -euo pipefail` を宣言しており、
コマンド置換のサブシェルは `-e` を引き継ぐ。関数が失敗した時点でサブシェルが終了すれば
`echo $?` に到達せず、空文字列が返って別の理由で落ちる。環境や将来のbashの挙動に依存させたくない。

`if` の条件式では `-e` が一時停止される（`.claude/rules/shell-script-style.md`「エラー方針」）ので、
そちらへ寄せた。

```bash
if provider_from_remote_url 'https://' >/dev/null 2>&1; then
  empty_host_status=0
else
  empty_host_status=1
fi
```

### DDR参照を実装コメントへ先に書かなかった

計画（個別作業計画の該当コード）では、`provider_from_remote_url` のコメントに
`.claude/docs/ddr/0027-...md` への参照を含めていた。**実装では入れず、issue #45 への参照のみにした。**
DDR 0027の作成はフェーズ4のレビューで判断する未確定事項であり、作らなかった場合に
コード側へ辿れない参照が残ってしまうため（`.claude/rules/docs-workflow.md`「コード・スクリプト内の
コメントから…参照しない」の趣旨と同じ問題）。DDR 0027を作ることが決まった時点で、
フェーズ4で参照を追記する。

なお「受け入れたトレードオフ」（非対応リモートにも `gitlab` を返すこと）は、DDRの有無に関わらず
実装を読んだ人が最初に疑問に思う点なので、関数コメントへ直接書いた。

### 検証結果

| 検証 | 結果 |
|---|---|
| `bash -n .claude/scripts/src/vcs/Provider.sh` / `tests/test_vcs_provider.sh` | OK |
| `bash tests/test_vcs_provider.sh` | `passed=26 failures=0` |
| CR混入（バイト数比較） | 両ファイルとも raw == stripped |
| このリポジトリ（GitHub）での退行 | `get_provider` → `github`、`get_mr_for_branch` → MR#52、`get_repo_url` → OK |

### self-hosted GitLabでのend-to-end検証（本issueの本丸）

`docker start gitlab`（healthyまで約4分）で検証環境を再開し、検証用リポジトリ
（remote `http://localhost:8929/root/issue45-verify.git`、ブランチ `feature-2-reverify`）で
`Provider.sh` を**そのままsourceして共通インターフェース関数を呼んだ**。
issue #48 では `get_provider` に弾かれるため `gitlab_*` を直接呼んで迂回していた部分である。

| 関数（ディスパッチ経由） | 結果 |
|---|---|
| `get_provider` | `gitlab`（**従来はここでエラー終了していた**） |
| `get_repo_url` | `http://localhost:8929/root/issue45-verify` |
| `get_issue 1` | `{"number":1,"title":"検証用issue",...}` |
| `get_mr_for_branch feature-2-reverify` | `{"number":2,"url":".../merge_requests/2",...}` |
| `get_mr_unresolved_comments 1` | 既存2件のnoteを整形して取得 |
| `get_workflow_config` | `.mrworkflow.json` の内容 |
| `add_mr_comment 2 <file>` | 投稿成功 |
| `set_mr_description 2 <file>` | 更新成功 |
| `add_mr_thread_reply 1 <threadId> <本文>` | 返信成功 |
| `get_mr_diff_url` | `.../-/compare/main...feature-2-reverify` |
| `get_mr_diff_since_url` | `.../-/compare/HEAD~1...HEAD` |
| `get_issue_number_from_branch` | `2` |
| `to_slug` | `detect-gitlab-provider` |

**ディスパッチ経由でGitLabの全機能が通ることを確認できた**ため、
`.claude/docs/spec/issue-mr-workflow.md`「未決定事項・懸念点」の「GitLab側の動作未検証」のうち
**「`Provider.sh`経由のディスパッチが未検証」の項目は解消できる**（残る2点＝バージョン・エディション、
プロジェクト構成は引き続き未検証）。

## うまくいったこと

- 判定方式を「速度」だけでなく**「認証状態への依存」**という軸でも比較できた。速度だけで選んでいたら
  `config.yml` 直読み（0.1秒）を採っていた可能性があり、未ログイン環境で動かない実装になっていた。
- 既存の `Gitlab.sh` には手を入れずに済む見通しが立った（issue #48で検証済みの実装を触らない）。
- 実際に `Gitlab.sh` / `Github.sh` を1行も変更せずに済んだ。差分は `Provider.sh` の判定部分と
  テストのみで、issue #48 で検証済みの実装に影響を与えていない。
- 実機検証が**issue #48 でやり残した部分をちょうど埋める**形になった。#48 は「`gitlab_*` を直接
  呼べば動く」ことまでしか示せておらず、#45 で初めて「ワークフローの入口から通る」ことを確認できた。

## ダメだったこと

- **検証スクリプトの呼び出し側を3か所間違え、実装の問題と紛らわしいNGを出した。** いずれも
  `Provider.sh` 側の欠陥ではなく、こちらの引数・関数名の誤りだった。
  - `add_mr_thread_reply 2 <threadId>`: threadIdは**MR#1**から取ったものなのにMR番号へ2を渡し、
    `404 Discussion Not Found` になった。
  - `get_compare_url`: `command not found`。`Provider.sh` にこの名前のディスパッチャは無く、
    `github_get_compare_url` / `gitlab_get_compare_url` は各プロバイダ実装の**内部ヘルパー**で、
    公開されているのは `get_mr_diff_url` / `get_mr_diff_since_url` の方である（設計どおり）。
  - `get_mr_diff_url 2`: 実際のシグネチャは `(repo_url, base_branch, head_branch)` の3引数で、
    `$2: unbound variable` になった。
  - 教訓として、実機検証スクリプトはNGが出た時点で「実装の不具合」と決めつけず、
    まず**呼び出し側のシグネチャを関数定義で確認する**こと。

## 次の一歩

- flow-id 3-7: `commit`スキル経由でcommitし、リモートへ反映して実装のレビューを依頼する。
- flow-id 4-1: 個別反映計画 `plans/【設計反映】〜.md` と `plans/【AIアセット反映】〜.md` を分けて作成する。
  - 設計反映: `.claude/docs/spec/issue-mr-workflow.md` L69の`Provider.sh`説明の更新／
    「未決定事項・懸念点」のディスパッチ未検証の項目を解消／「提供関数」表直後の内部ヘルパー段落へ
    `provider_from_remote_url` を追記／「影響範囲」へ**新規エントリを追記**（過去のchangelogは書き換えない）／
    DDR 0027の新規作成（作成するかはレビューで判断。作る場合は実装コメントへの参照追記も同時に行う）。
  - AIアセット反映: 現時点で候補は「`set -e` 配下で終了コードを検査するテストの書き方」。
    `.claude/rules/shell-script-style.md`「エラー方針」に近い内容が既にあるため、
    重複にならない形で足せるかを反映計画で判断する。
- 検証環境のDockerコンテナ `gitlab` は起動したままなので、フェーズ4に入る前に停止しておく。

---
