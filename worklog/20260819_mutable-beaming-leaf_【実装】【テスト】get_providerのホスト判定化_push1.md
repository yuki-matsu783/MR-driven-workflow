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

<!-- flow-id 3-6（作業実施）で追記する -->

## うまくいったこと

- 判定方式を「速度」だけでなく**「認証状態への依存」**という軸でも比較できた。速度だけで選んでいたら
  `config.yml` 直読み（0.1秒）を採っていた可能性があり、未ログイン環境で動かない実装になっていた。
- 既存の `Gitlab.sh` には手を入れずに済む見通しが立った（issue #48で検証済みの実装を触らない）。

## ダメだったこと

- （実装着手前のため、現時点では特になし。）

## 次の一歩

- flow-id 3-2: `commit`スキル経由でcommitし、リモートへ反映して作業計画のレビューを依頼する。
- flow-id 3-6: `provider_from_remote_url` の新設と `get_provider` の薄いラッパー化、テスト11件の追加。
- flow-id 3-6の検証で `docker start gitlab` を行い、**ディスパッチ経由**でGitLab関数が通ることを確認する
  （issue #48では `get_provider` に弾かれるため直接呼びで迂回していた部分）。

---
