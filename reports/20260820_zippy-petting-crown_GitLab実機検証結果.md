---
title: GitLab側13関数とURL形式の実機検証結果（issue #127）
type: report
description: ローカルGitLab CE 18.5.4に対しProvider.sh経由で未検証13関数・URL系4種・サブグループ解決を実機検証した結果。差分アンカーのsha1前提が正しいことを確定し、gitlab_get_repo_url未定義の不具合を1件検出した。
tags: [gitlab, verification, provider, report]
keywords: [GitLab CE, glab, Provider.sh, 差分アンカー, sha1, diffs_stream, noteable_note_url, サブグループ, semantic conflict, gitlab_get_repo_url]
---

# GitLab側13関数とURL形式の実機検証結果（issue #127・flow-id 2-6）

- 計画: `plans/【調査】GitLab13関数とURL形式の実機検証.md` / `plans/zippy-petting-crown.md`
- 実施日: 2026-08-20

## 結論（先に3行）

1. **差分アンカーの `sha1` 前提は正しい。** `diff-` 接頭辞も付かない。GitLabが遅延読込する
   `diffs_stream` 断片HTMLの `id=` 属性と、`hash_paths` の値が完全一致した。
2. **不具合を1件検出した。** `gitlab_get_repo_url` が**未定義のまま2箇所から呼ばれており**、
   `get_mr_url` / `get_note_url` が到達不能（デッドコード）になっている。`add_mr_thread_reply` が
   返すはずのパーマリンクが空で返る。
3. **それ以外の11関数は期待どおり動いた。** サブグループ配下でのプロジェクト解決も通った。

## 検証環境

| 項目 | 値 |
|---|---|
| イメージ | `gitlab/gitlab-ce:18.5.4-ce.0`（`sha256:19eac5ba7766...`） |
| コンテナ | `gitlab`（`RestartPolicy: unless-stopped`、`Hostname: localhost`） |
| ポート | `8929:8929/tcp`、`2224:22/tcp` |
| ボリューム | `gitlab-config`→`/etc/gitlab`、`gitlab-logs`→`/var/log/gitlab`、`gitlab-data`→`/var/opt/gitlab` |
| `GITLAB_OMNIBUS_CONFIG` | `external_url 'http://localhost:8929'` / `gitlab_rails['gitlab_shell_ssh_port'] = 2224` / `prometheus_monitoring['enable'] = false` / `gitlab_kas['enable'] = false` / `puma['worker_processes'] = 2` / `sidekiq['max_concurrency'] = 5` |
| CLI | `glab` 1.114.0、`localhost:8929` に `root` でログイン（OSキーリング） |

再現手順の詳細は「受け入れ条件8: 検証環境の再現手順」節。

### 接続手段

- **ssh（port 2224）は使えない**: `Permission denied (publickey)`（公開鍵未登録）。
- **素のhttpクローンは失敗する**: Git Credential Manager が介在し `fatal: helper error (143)`。
- **採用**: `git -c credential.helper= clone "http://oauth2:<PAT>@localhost:8929/<path>.git"`。
- **PATは `.git/config` に平文で残る**ため、クロード直後に
  `git remote set-url origin http://localhost:8929/<path>.git` で外した。除去後の残存は0件
  （`grep -c 'glpat-' .git/config` → `0`）。

### 使用したプロジェクト

| プロジェクト | 用途 |
|---|---|
| `root/issue127-verify`（id=4） | 本検証のメイン。`main` / `feat-127`、MR !1、issue !1〜!3 |
| `grp127/sub127/issue127-verify-sub`（id=5） | サブグループ解決の確認（3階層namespace） |
| `root/issue45-verify`（id=1） | `set_mr_ready` の二重 `Draft:` 接頭辞ケースの入力（flow-id 2-4 で利用を許可された） |

**`root/issue127-verify` は検証中に visibility を private → public へ変更した。** Compareページの
HTMLをPATヘッダで取得できず（後述）、未認証で取得する必要があったため。アンカーIDの生成には
影響しない。

## 13関数の結果

「経路」列の**直接**は `Provider.sh` の公開関数をそのまま呼んだもの、**間接**は
`Provider.sh` にディスパッチャが無いため公開関数を踏み台にしたもの。

| # | 関数 | 経路 | 結果 |
|---|---|---|---|
| 1 | `search_issues` | 直接 | ✅ open/closed の両方が返った |
| 2 | `normalize_issue_search_results` | 間接（`search_issues` 内部） | ✅ `iid`→`number`・`web_url`→`url`・`opened`→`open`・`closed` 維持 |
| 3 | `set_mr_ready` | 直接 | ✅ `Draft:` 除去・冪等・**二重接頭辞も1回で除去** |
| 4 | `add_issue_comment` | 直接 | ✅ issue側へnoteが1件付いた |
| 5 | `gitlab_get_mr_url` | 間接 | ⚠️ **実装は正しいが到達不能**（下記「検出した不具合」） |
| 6 | `gitlab_get_note_url` | 間接 | ⚠️ 同上 |
| 7 | `get_blob_url` | 直接 | ✅ 200。**percent-encode必須**（生パスは失敗） |
| 8 | `get_diff_anchor_url` | 直接 | ✅ **sha1前提は正しい**（下記「差分アンカー」） |
| 9 | `get_diff_anchor_algo` | 直接 | ✅ `sha1` を返した |
| 10 | `gitlab_add_mr_thread` | 間接（#13 run2） | ✅ **解決可能なスレッド**として投稿された |
| 11 | `gitlab_build_discussion_body` | 間接（#13） | ✅ 新規行・日本語パスとも正しい `position` |
| 12 | `gitlab_summary_post_kind` | 間接（#13 ×2） | ✅ **両分岐を確認**（0件→note、1件以上→thread） |
| 13 | `add_mr_inline_comments` | 直接 | ✅ run1 `{3,0}` / run2 `{2,1}`、巻き添え失敗なし |

### 個別の記録

#### #1・#2 `search_issues` / `normalize_issue_search_results`

```
$ search_issues "検証用"
{"number":3,"title":"クローズ済みの検証用issue","state":"closed","url":".../-/issues/3"}
{"number":2,"title":"検証用issue ベータ","state":"open","url":".../-/issues/2"}
{"number":1,"title":"検証用issue アルファ","state":"open","url":".../-/issues/1"}
```

**spec の未決定事項（issue #68）が解消した。** 「GitLab側の `--all` フラグは `glab` のバージョンに
よって名称が異なる可能性がある」と書かれていたが、**`glab` 1.114.0 で機能し、closed のissueも
返る**ことを確認した。

#### #3 `set_mr_ready`

| 入力 | 実行前 | 実行後 |
|---|---|---|
| 単一接頭辞 | `Draft: issue127 検証用MR` / `draft=true` | `issue127 検証用MR` / `draft=false` |
| 接頭辞なしへ再実行（冪等性） | `issue127 検証用MR` / `draft=false` | 変化なし・エラーなし |
| **二重接頭辞** | `Draft: Draft: 検証MR` / `draft=true` | `検証MR` / `draft=false` |

**二重接頭辞が1回の呼び出しで完全に除去された。** `glab` 側の除去正規表現
`(?i)^(\s*(?:draft:|wip:)\s*)*` が繰り返しにマッチするという実装ソースの読みが裏付けられた。
**spec の未決定事項（issue #61）が解消した。**

#### #7 `get_blob_url`

| パス | encode結果 | HTTP |
|---|---|---|
| `README.md` | `README.md` | 200 |
| `docs/plain.txt` | `docs/plain.txt` | 200 |
| `docs/検証 用.md` | `docs/%E6%A4%9C%E8%A8%BC%20%E7%94%A8.md` | 200 |

生パス（encodeせず）を渡すと到達しない。**`url_encode_path_to_reply` を通す契約は必須**である。

#### #8・#9 差分アンカー — **sha1前提は正しい**

検証の焦点。3段で確定させた。

**1段目（実装内部の整合）**

| パス | `hash_paths sha1` | `sha1sum` |
|---|---|---|
| `README.md` | `8ec9a00bfd09b3190ac6b22251dbb1aa95a0579d` | 同一 |
| `docs/検証 用.md` | `dbd436723fcd58b281afcd60bbd2b93e33d9cbca` | 同一 |

**2段目（直接証拠）**

Compareページの初期HTML（34,578バイト）には**ハッシュが1件も含まれていなかった**。GitLab 18.5 は
"rapid diffs" 方式で差分を遅延読込しており、初期HTMLは器でしかない。HTML内に埋め込まれた
エンドポイント定義から実体を特定した。

```
diffs_stream_url:      /-/compare/diffs_stream?from=main&to=feat-127&view=inline
diff_files_endpoint:   /-/compare/diff_files_metadata?from=main&to=feat-127
```

`diffs_stream` を取得すると、**接頭辞の無い40桁hexの `id=` 属性**が現れた。

```
id="8ec9a00bfd09b3190ac6b22251dbb1aa95a0579d"     ← README.md
id="dbd436723fcd58b281afcd60bbd2b93e33d9cbca"     ← docs/検証 用.md
```

`diff_files_metadata` の `file_hash` も同一だった。

```json
{"path":"README.md","file_hash":"8ec9a00bfd09b3190ac6b22251dbb1aa95a0579d",
 "file_identifier_hash":"14e688a849c8209d6d1d93c29f305097ad8df999"}
{"path":"docs/検証 用.md","file_hash":"dbd436723fcd58b281afcd60bbd2b93e33d9cbca",
 "file_identifier_hash":"c53bd1e34340a225a2b07d264c450854974a7932"}
```

**確定した事実**

- アルゴリズムは **sha1**、**`diff-` 接頭辞は付かない**（GitHubの `#diff-<sha256>` と異なる）。
- ハッシュの入力は **percent-encode前の生パス**（`docs/検証 用.md` そのもの）。
  blobリンクがencode済みを要求するのと**逆**なので、両者を取り違えない。
- 入力は **`new_path`**（`file_identifier_hash` という別のハッシュも存在するが、`id=` 属性に
  使われているのは `file_hash` の側）。

**PATヘッダはWebページの認証に使えない。** `PRIVATE-TOKEN` を付けてCompareページを要求しても
**302**（サインインへのリダイレクト）になる。PATが有効なのはAPI（`/api/v4/`）に対してのみ。
本検証ではプロジェクトを一時的にpublicにして取得した。

#### #5・#6 `gitlab_get_mr_url` / `gitlab_get_note_url` — 実装は正しいが到達不能

直接呼べば正しい値を返す。

```
gitlab_get_mr_url  → http://localhost:8929/root/issue127-verify/-/merge_requests/1
gitlab_get_note_url → http://localhost:8929/root/issue127-verify/-/merge_requests/1#note_94
```

**GitLab自身が返す値とバイト単位で一致した。** MRの `discussions.json` 断片に含まれる
`noteable_note_url` フィールドが、まさにこの形式である。

```
"noteable_note_url":"http://localhost:8929/root/issue127-verify/-/merge_requests/1#note_84"
```

しかし**踏み台となる公開関数からは到達しない**（次節）。

#### #10〜#13 `add_mr_inline_comments` ほか

事前確認として、diffに含まれないパスへの `discussions` POSTが確実に拒否されることを単体で
確かめた（`400 Bad request - Note {:line_code=>["can't be blank", "must be a valid line code"]}`）。
これにより「拒否されるはずの入力が受理されて検証が空振りする」可能性を排除した。

| 実行 | 入力 | 戻り値 | サマリの形態 |
|---|---|---|---|
| run1 | 有効3件 | `{"posted":3,"summarized":0}` | **単発note**（`individual_note=true` / `resolvable=false`） |
| run2 | 有効2件＋不正1件 | `{"posted":2,"summarized":1}` | **スレッド**（`individual_note=false` / `resolvable=true`） |

- run1・run2とも、インラインコメントは指定した `path`・`new_line` に正しく付いた
  （日本語＋スペースを含むパスを含む）。
- run2で**不正な1件だけがサマリへ回り、有効な2件は巻き添えにならなかった**。GitLabが1リクエスト
  1指摘であるという設計上の期待どおり。
- `summary_post_kind` の**両分岐を実際に通した**（run1でnote、run2でthread）。

## 検出した不具合（フェーズ3で修正する）

### `gitlab_get_repo_url` が未定義のまま呼ばれている

**症状**

```
$ add_mr_thread_reply 1 "<threadId>" "..."
戻り値=[]        ← パーマリンクが返らない（返信の投稿自体は成功する）

$ get_mr_unresolved_comments 1
[unresolved threadId=7e4e5d63... README.md:2] root: ...
                                       ↑ url= が付かない
```

**原因**

`.claude/scripts/src/vcs/Gitlab.sh` の162行目・180行目が `gitlab_get_repo_url` を呼んでいるが、
**この関数はどこにも定義されていない**。正しくは `Provider.sh` のプロバイダ非依存関数
`get_repo_url` である。

```bash
if repo_url="$(gitlab_get_repo_url 2>/dev/null)" && [ -n "$repo_url" ]; then   # 常に偽
  mr_url="$(gitlab_get_mr_url "$repo_url" "$mr_number")"                       # 到達しない
fi
```

`2>/dev/null` で `command not found` が握りつぶされ、`if` が常に偽になるため、**エラーも出ずに
url無しの出力へ縮退する**。設計上「失敗しても本体のコメント取得は成功させたい」という意図の
握りつぶしが、そのまま不具合を覆い隠していた。

**影響**

- `get_mr_unresolved_comments` が `url=<パーマリンク>` を出力しない。
  `issue-mr-flow` の `comments` サブコマンドは、この `url=` を「次のpushのレビュー依頼メッセージへ
  返信リンクを載せる」ために使うと定めており（issue #42）、GitLabではこれが機能しない。
- `add_mr_thread_reply` が返信のパーマリンクを返さない（同じ用途）。
- `gitlab_get_mr_url` / `gitlab_get_note_url` が**デッドコード**になっている。

**なぜ混入したか（並行ブランチのsemantic conflict）**

| コミット | 日時 | 内容 |
|---|---|---|
| `91432db` | 2026-08-18 13:21 | `gitlab_get_repo_url` を**定義** |
| `7ebc615` | 2026-08-19 10:53 | issue #42。`gitlab_get_repo_url` の**呼び出しを追加**（当時は定義があり正しい） |
| `8d01fbb` | 2026-08-19 11:07 | issue #44。`get_repo_url` をプロバイダ非依存化し**定義を削除**（当時そのブランチに呼び出しは無い） |

`7ebc615` と `8d01fbb` は**直系ではなく並行ブランチ**（merge-base `7f089a5`）。どちらも単体では
正しく、**組み合わさったときだけ壊れる**。ファイルの別々の場所を変更しているため、gitは
コンフリクトを報告せず無言でマージした。`.claude/skills/resolve-conflict/SKILL.md` が
「両ブランチの変更が個別には正しいが組み合わせると壊れる（semantic conflict）」として警告している
類型そのものである。

**これが「関数の数が合わない」問題の正体でもある**

issue #127 の本文は「#48で全13関数を検証」「その後25関数へ増え、うち13関数が未検証」と書いており、
13 + 13 = 26 で1件合わなかった。差分を取ると、**#48当時にあって現在無い唯一の関数が
`gitlab_get_repo_url`** だった。

```
$ comm -23 <#48時点の関数一覧> <現在の関数一覧>
gitlab_get_repo_url
```

つまり `13 - 1 + 13 = 25` で数は閉じる。**数の不一致と本不具合は同じ1件の削除に由来する。**

**同種の点検**

`Gitlab.sh` / `Github.sh` の全関数呼び出しを定義済み一覧と突き合わせたところ、
**未定義の呼び出しは `gitlab_get_repo_url` の1件のみ**だった
（`Gitlab.sh:64` の `github_search_issues` はコメント中の参照で呼び出しではない）。

**修正方針（フェーズ3）**

`gitlab_get_repo_url` → `get_repo_url` に置き換える（2箇所）。あわせて、この種の
「未定義関数の呼び出し」を機械的に検出する手段を持つか検討する。

## URL系4種

| 種別 | 生成URL | 自動確認 | ブラウザ目視 |
|---|---|---|---|
| blob | `/-/blob/main/docs/%E6%A4%9C%E8%A8%BC%20%E7%94%A8.md` | HTTP 200 | **未（依頼中）** |
| 差分アンカー | `/-/compare/main...feat-127#8ec9a00b...` | `id=` 属性と一致 | **未（依頼中）** |
| noteパーマリンク | `/-/merge_requests/1#note_94` | `noteable_note_url` と一致 | **未（依頼中）** |
| Compare | `/-/compare/main...feat-127` | HTTP 200 | **未（依頼中）** |

**ブラウザでの目視確認はAIには行えない**ため、ユーザーへ依頼している。ハッシュが正しくても
差分本体の遅延読込によって実際にはスクロールしない、という失敗様態が残るため、自動確認だけでは
受け入れ条件2を満たさない。

## サブグループ配下でのプロジェクト解決

`grp127/sub127/issue127-verify-sub`（3階層namespace）で確認した。**spec の未決定事項
（issue #48・#45 の「プロジェクト構成」）が解消した。**

```
provider=gitlab
repo_url=http://localhost:8929/grp127/sub127/issue127-verify-sub
slug={"host":"localhost","owner":"grp127/sub127","repo":"issue127-verify-sub",
      "path":"grp127/sub127/issue127-verify-sub", "url":"..."}
```

- **`owner` には親namespace全体（`grp127/sub127`）が入り、`repo` は末尾のみ**になる。
  `parse_repo_slug` は2階層前提の命名だが、3階層以上でも `path` は正しく、`owner` が
  「末尾以外すべて」を保持するため破綻しない。
- `new_issue` / `get_issue` / `new_draft_merge_request` / `get_mr_for_branch` がいずれも動作した。
- **MCPフォールバックへの影響は無い。** MCP経路はGitHub専用であり（DDR 0027）、GitHubには
  サブグループの概念が無い。

### 観察（不具合ではない）

- `get_mr_for_branch` の戻り値の `draft` が **`null`** になる（GitHubは真偽値）。`glab mr list` の
  JSONに `draft` が含まれないため。`set_mr_ready` はこの値に依存しないので実害は無いが、
  `draft` を条件分岐に使うコードを将来書く場合は注意が要る。
- `new_issue`（`glab issue create`）は `- Creating issue in <project>` という進捗行を出すが、
  **stderrへ出ており stdout はJSONのみ**。`new_issue | jq` は安全に書ける。
  ただし `new_issue 2>&1 | jq` のように**stderrを混ぜるとjqが構文エラーになる**。

## 受け入れ条件8: 検証環境の再現手順

```bash
# 1. GitLab CE 18.5.4 を起動する
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
# healthy になるまで数分待つ（docker ps の STATUS で確認）

# 2. rootの初期パスワードを取り出し、UIでPersonal Access Token（api スコープ）を作る
docker exec gitlab cat /etc/gitlab/initial_root_password   # MSYS_NO_PATHCONV=1 が必要

# 3. glab を認証する（トークンはOSキーリングへ入る）
glab auth login --hostname localhost:8929 --api-protocol http

# 4. 検証用プロジェクトを作る
export GITLAB_HOST=localhost:8929
glab api projects -X POST -f name=<name> -f path=<path> -f visibility=private

# 5. クローンする（PATをURLへ埋め、GCMを無効化し、直後にPATを外す）
TOKEN="$(glab auth status --show-token 2>&1 | grep -oE 'glpat-[A-Za-z0-9._-]+' | head -1)"
git -c credential.helper= clone "http://oauth2:${TOKEN}@localhost:8929/<path>.git" clone
cd clone && git remote set-url origin "http://localhost:8929/<path>.git"
```

- `docker exec` へコンテナ内の絶対パスを渡すときは `MSYS_NO_PATHCONV=1` が要る
  （`.claude/rules/shell-script-style.md`）。
- **Webページ（HTML）をスクリプトから取得したい場合は、プロジェクトをpublicにする**。
  PATヘッダはAPIにしか効かない。

## 範囲外（確認していないこと）

- gitlab.com（SaaS）・CE 18.5.4 以外のバージョン・EE。
- ssh経由のgit操作（公開鍵未登録のまま）。
- ブラウザでの目視確認（ユーザーへ依頼中）。
