---
title: GitLab検証環境の再現手順
type: spec
description: Gitlab.sh をローカルGitLab CE（Docker）に対して実機検証するための環境構築手順と、実際に踏んだ落とし穴。
tags: [gitlab, verification, docker, glab]
keywords: [GitLab CE, docker run, glab auth, Personal Access Token, サブグループ, MSYS_NO_PATHCONV, credential.helper, diffs_stream]
---

# GitLab検証環境の再現手順

## 背景・目的

`.claude/scripts/src/vcs/Gitlab.sh` は、このリポジトリの実remoteがGitHubであるため、
**ローカルに立てたGitLab CE に対してのみ実機検証できる**。issue #48・#45・#127 はいずれも
そのつど環境を作り直しており、手順がリポジトリ内に残っていなかった（issue #127 の着手時に
`docker run` / `glab auth login` の記載が1件も無いことを確認している）。次に `Gitlab.sh` を
変更する人が同じ環境を作り直せるように、手順と**実際に踏んだ落とし穴**を残す
（issue #127 の受け入れ条件8）。

**`Gitlab.sh` の検証状況（どのissueで何を確認したか・残る未検証範囲）の正は
[issue-mr-workflow.md](issue-mr-workflow.md)「未決定事項・懸念点」の1箇所である。**
本ファイル・`Gitlab.sh` のヘッダ・[shell-scripts.md](shell-scripts.md) は、いずれも
そこを参照するだけで、確認済み・未確認の一覧を再掲しない（同じ内容を複数箇所へ書くと、
片方だけが更新されて食い違う。issue #127 の敵対的レビューで実際に食い違いが検出された）。

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
#    `glab auth status` は gitlab.com 側の認証エラーで終了コード2を返しうるので `|| true` を添える
#    （下記「`glab auth status` の終了コード」）。トークンの接頭辞は設定で変えられるため、
#    `glpat-` 決め打ちではなく「対象ホストの節にある Token の行の末尾フィールド」を取り出す
#    （実際の行は `✓ Token found in operating system keyring: <値>`）。
TOKEN="$( { glab auth status --show-token 2>&1 || true; } \
  | awk '/localhost:8929/{f=1} f && /oken/{print $NF; exit}')"
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
- 記録・ログへ貼る出力のマスクの仕方は
  `.claude/rules/shell-script-style.md`「秘密情報の扱い」が正（値そのものを置換する・
  パターンが実データに当たることを確かめる・そもそも値を出さない形にできないか先に考える）。
  ここでは繰り返さない。
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
- **折りたたみ（`collapsed`）を再現する条件は特定できていない**（下記「未決定事項・懸念点」）。

### `glab` の出力の扱い

`glab issue create` は進捗行（`- Creating issue in <project>`）を**stderrへ**、JSONを
**stdoutへ**出す。`2>&1` でまとめると `jq` が `parse error: Invalid numeric literal` で失敗し、
**正常な関数を不具合と誤認する**。`2>/dev/null` にすればstdoutは純粋なJSONになる。

## 未決定事項・懸念点

- **折りたたまれた差分（`collapsed`）を再現する条件が特定できていない。** `diffs_batch.json`
  経由では、402行のファイルを含む**32ファイル**（`diffs_batch.json` が1回の応答で返した
  `diff_files` の件数。DDR i0127-01 が記録している「MR全体で30ファイル」とは断面が異なる）の
  差分でも `collapsed` は1件も立たなかった
  （`diffs_stream` 経由では畳まれるのを観測している）。ファイル単体の行数ではなくページ全体の
  規模に依存すると思われるが、条件を絞り込めていない。**この条件を作れないため、折りたたまれた
  ファイルへ差分アンカーが飛ぶかも検証できていない**（
  [issue-mr-workflow.md](issue-mr-workflow.md)「未決定事項・懸念点」の同項目と対応する）。
- **本ファイルの手順は、issue #127 の検証時点（2026-08-20〜21）の `glab` 1.114.0 /
  GitLab CE 18.5.4 の出力形式に依存している。** とくに手順5のトークン取り出しは
  `glab auth status --show-token` の出力行の形（`Token found in operating system keyring: <値>`）に
  依存しており、`glab` の更新で変わりうる。動かなくなったら出力を直接見て合わせること。
- 検証用プロジェクトの**後片付けは手順に含めていない**。ローカルGitLabのプロジェクト・グループ・
  クローン先ディレクトリは、検証が終わったら手で削除する。

## 関連

- `.claude/scripts/src/vcs/Gitlab.sh`（`glab` CLIラッパー本体）
- **[issue-mr-workflow.md](issue-mr-workflow.md)「未決定事項・懸念点」（`Gitlab.sh` の検証状況の正）**
- [shell-scripts.md](shell-scripts.md)（bashスクリプト全般の設計方針）
- `.claude/rules/shell-script-style.md`「git bashのパス変換の落とし穴」
  （`MSYS_NO_PATHCONV=1` が要る理由）
