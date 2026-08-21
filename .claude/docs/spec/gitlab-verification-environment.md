---
title: GitLab検証環境の再現手順
type: spec
description: Gitlab.sh をローカルGitLab CE（Docker）に対して実機検証するための環境構築手順と、実際に踏んだ落とし穴。
tags: [gitlab, verification, docker, glab]
keywords: [GitLab CE, docker run, glab auth, Personal Access Token, サブグループ, MSYS_NO_PATHCONV, credential.helper, diffs_stream]
---

# GitLab検証環境の再現手順

`.claude/scripts/src/vcs/Gitlab.sh` は、このリポジトリの実remoteがGitHubであるため、
**ローカルに立てたGitLab CE に対してのみ実機検証できる**。その環境を再現するための手順を残す
（issue #127 の受け入れ条件8）。

`Gitlab.sh` の現在の検証状況（どのissueで何を確認したか・残る未検証範囲）は同ファイルの
ヘッダと [issue-mr-workflow.md](issue-mr-workflow.md)「未決定事項・懸念点」が正である。

## 検証実績のある構成

| 項目 | 値 |
|---|---|
| イメージ | `gitlab/gitlab-ce:18.5.4-ce.0` |
| CLI | `glab` 1.114.0 |
| ホスト | Windows 10 + Docker Desktop、git bash（MSYS） |

**gitlab.com（SaaS）・CE 18.5.4 以外のバージョン・EE は検証範囲外**である。

## 手順

```bash
# 1. GitLab CE を起動する
docker run -d --name gitlab --restart unless-stopped --hostname localhost \
  -p 8929:8929 -p 2224:22 \
  -e GITLAB_OMNIBUS_CONFIG="external_url 'http://localhost:8929'
gitlab_rails['gitlab_shell_ssh_port'] = 2224
prometheus_monitoring['enable'] = false
gitlab_kas['enable'] = false
puma['worker_processes'] = 2
sidekiq['max_concurrency'] = 5" \
  -v gitlab-config:/etc/gitlab -v gitlab-logs:/var/log/gitlab -v gitlab-data:/var/opt/gitlab \
  gitlab/gitlab-ce:18.5.4-ce.0
# healthy になるまで数分かかる（docker ps の STATUS で確認する）

# 2. rootの初期パスワードを取り出し、UIでPersonal Access Token（api スコープ）を作る
MSYS_NO_PATHCONV=1 docker exec gitlab cat /etc/gitlab/initial_root_password

# 3. glab を認証する（トークンはOSキーリングへ入る）
glab auth login --hostname localhost:8929 --api-protocol http
export GITLAB_HOST=localhost:8929

# 4a. 検証用プロジェクト（単一namespace）を作る
glab api projects -X POST -f name=<name> -f path=<path> -f visibility=private

# 4b. サブグループ検証用（3階層namespace）を作る
gid="$(glab api groups -X POST -f name=grp127 -f path=grp127 -f visibility=public | jq -r '.id')"
sgid="$(glab api groups -X POST -f name=sub127 -f path=sub127 -f visibility=public \
        -f parent_id="$gid" | jq -r '.id')"
glab api projects -X POST -f name=<name>-sub -f path=<path>-sub -f visibility=public \
  -f namespace_id="$sgid" -f initialize_with_readme=true

# 5. クローンする（PATをURLへ埋め、GCMを無効化し、直後にPATを外す）
TOKEN="$(glab auth status --show-token 2>&1 | grep -oE 'glpat-[A-Za-z0-9._-]+' | head -1)"
git -c credential.helper= clone "http://oauth2:${TOKEN}@localhost:8929/<path>.git" clone
cd clone && git remote set-url origin "http://localhost:8929/<path>.git"
```

**手順5の作業ディレクトリを cwd にしてから `Provider.sh` を source する。**
`get_provider` は `git remote get-url origin` でプロバイダを判定するため、
**cwdが検証用クローンであることが `Provider.sh` 経由の検証の前提**になる。

## 実際に踏んだ落とし穴

### 接続手段

| 手段 | 結果 |
|---|---|
| ssh（port 2224） | `Permission denied (publickey)`（公開鍵未登録）。鍵の登録は検証の目的ではないため使わない |
| 素のhttpクローン | Git Credential Manager が介在し `fatal: helper error (143)` |
| **http + PAT + `-c credential.helper=`** | **成功。これを標準手段とする** |

### PATの扱い

- **URLへ埋めたPATはクローン先の `.git/config` へ平文で残る。** 手順5のとおり、クローン直後に
  `git remote set-url origin` で外す（`grep -c 'glpat-' .git/config` が `0` になることを確認する）。
- **PATをファイルへ書かない。** 必要になるたびに `glab auth status --show-token` から取り出す。
- 記録・ログへ貼る出力をマスクする場合は、**トークンの値そのものを置換する**。`glpat-` のような
  接頭辞は設定で変更できるため、接頭辞決め打ちの正規表現に頼らない。
- **検証用クローンはリポジトリのツリー外（スクラッチパッド配下など）に置き、終わったら消す。**

### `glab auth status` の終了コード

`gitlab.com` 側の認証エラーに引きずられて**終了コード2を返す**ことがある（`localhost:8929` の
行だけを見れば正常でも）。`set -e` 配下でそのまま呼ぶと止まるため、**出力だけを使い終了コードは
見ない**。

### Webページの取得にPATは効かない

`PRIVATE-TOKEN` ヘッダが効くのは `/api/v4/` だけで、**Webページ（HTML）へ付けても302でサインインへ
飛ばされる**。差分アンカーの検証のようにHTMLをスクリプトから取得する必要がある場合は、
プロジェクトを `public` にする。ブラウザでログイン済みなら `private` のままでも目視確認はできる。

### 差分の描画経路

GitLab 18.5 は差分を非同期に描画するため、**ページの初期HTMLにはアンカー用のパスハッシュが
含まれない**。実体を取るには初期HTMLの `data-endpoint-batch` / `data-endpoint` 属性から
エンドポイントを特定する。

- MRの差分ページ（`/-/merge_requests/<iid>/diffs`）が使うのは **`diffs_batch.json`**。
  `?start_sha=<MRバージョンのhead>` で「そのSHA以降に変わったファイル」へ絞り込める
  （`diff_id` の併用は不要）。
- Compareページ（`/-/compare/<from>...<to>`）が使うのは **`diffs_stream`**。こちらは
  `start_sha` / `diff_id` を無視する。
- **`start_sha` にMRバージョンのheadでないSHAを渡すと、エラーにならずHTTP 200のまま0ファイルを
  返す。** バージョンの一覧は `glab api projects/:id/merge_requests/<n>/versions` で得られる。
- **折りたたみ（`collapsed`）を再現する条件は特定できていない。** 402行のファイルを含む
  32ファイルの差分でも `collapsed` は1件も立たなかった（`diffs_stream` 経由では畳まれるのを
  観測している）。ファイル単体の行数ではなくページ全体の規模に依存すると思われる。

### `glab` の出力の扱い

`glab issue create` は進捗行（`- Creating issue in <project>`）を**stderrへ**、JSONを
**stdoutへ**出す。`2>&1` でまとめると `jq` が `parse error: Invalid numeric literal` で失敗し、
**正常な関数を不具合と誤認する**。`2>/dev/null` にすればstdoutは純粋なJSONになる。

## 関連

- `.claude/scripts/src/vcs/Gitlab.sh`（検証状況はヘッダを参照）
- [issue-mr-workflow.md](issue-mr-workflow.md)「未決定事項・懸念点」（残る未検証範囲）
- [shell-scripts.md](shell-scripts.md)（bashスクリプト全般の設計方針）
- `.claude/rules/shell-script-style.md`「git bashのパス変換の落とし穴」
  （`MSYS_NO_PATHCONV=1` が要る理由）
