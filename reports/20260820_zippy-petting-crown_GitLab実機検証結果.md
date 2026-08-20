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
   `gitlab_get_mr_url` / `gitlab_get_note_url` へ至る**実運用経路が到達不能**になっている
   （単体テストからは直接呼ばれており、テストは通る）。`add_mr_thread_reply` が返すはずの
   パーマリンクが空で返る。
3. **それ以外の11関数は期待どおり動いた。** サブグループ配下でのプロジェクト解決も通った。

**受け入れ条件1（`Provider.sh` 経由での実行）は、#5・#6 の2件について未達である。** 踏み台に
するはずだった公開関数が上記の不具合で到達不能だったため、この2件は `gitlab_*` を直呼びして
実装の正しさだけを確かめた。**フェーズ3でディスパッチャを追加したうえで再実行する**
（flow-id 2-4 で決定済み。`plans/zippy-petting-crown.md`「フェーズ3〈作業〉」）。

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
- **PATは `.git/config` に平文で残る**ため、クローン直後に
  `git remote set-url origin http://localhost:8929/<path>.git` で外した。除去後の残存は0件
  （`grep -c 'glpat-' .git/config` → `0`）。

### 使用したプロジェクト

| プロジェクト | 用途 |
|---|---|
| `root/issue127-verify`（id=4） | 本検証のメイン。`main` / `feat-127`、MR !1、issue #1〜#3 |
| `grp127/sub127/issue127-verify-sub`（id=5） | サブグループ解決の確認（3階層namespace） |
| `root/issue45-verify`（id=1） | `set_mr_ready` の二重 `Draft:` 接頭辞ケースの入力（flow-id 2-4 で利用を許可された） |

**`root/issue127-verify` は検証中に visibility を private → public へ変更した。** Compareページの
HTMLをPATヘッダで取得できず（後述）、未認証で取得する必要があったため。アンカーIDの生成には
影響しない。

## 13関数の結果

「経路」列の意味は次のとおり。`Provider.sh` に**その名前の公開関数が無い**ものは
`gitlab_` 接頭辞付きで表記している（ディスパッチャが壊れているのではなく、最初から無い）。

| 表記 | 意味 | 受け入れ条件1 |
|---|---|---|
| **直接** | `Provider.sh` の公開関数をそのまま呼んだ | 満たす |
| **間接** | ディスパッチャが無いため、公開関数を踏み台にして通した | 満たす（`Provider.sh` 経由で実行されている） |
| **直呼び** | 踏み台も到達不能だったため `gitlab_*` を直接呼んだ | **満たさない**（フェーズ3で再実行する） |

| # | 関数 | 経路 | 結果 |
|---|---|---|---|
| 1 | `search_issues` | 直接 | ✅ open/closed の両方が返った |
| 2 | `normalize_issue_search_results` | 間接（`search_issues` 内部） | ✅ `iid`→`number`・`web_url`→`url`・`opened`→`open`・`closed` 維持 |
| 3 | `set_mr_ready` | 直接 | ✅ `Draft:` 除去・冪等・**二重接頭辞も1回で除去** |
| 4 | `add_issue_comment` | 直接 | ✅ issue側へnoteが1件付いた |
| 5 | `gitlab_get_mr_url` | **直呼び** | ⚠️ 実装は正しいが**実運用経路が到達不能**。受け入れ条件1は未達（下記「検出した不具合」） |
| 6 | `gitlab_get_note_url` | **直呼び** | ⚠️ 同上 |
| 7 | `get_blob_url` | 直接 | ✅ 200。**percent-encode必須**（生パスは失敗） |
| 8 | `get_diff_anchor_url` | 直接 | ✅ **sha1前提は正しい**（下記「差分アンカー」） |
| 9 | `get_diff_anchor_algo` | 直接 | ✅ `sha1` を返した |
| 10 | `gitlab_add_mr_thread` | 間接（#13 run2） | ✅ **解決可能なスレッド**として投稿された |
| 11 | `gitlab_build_discussion_body` | 間接（#13） | ✅ 新規行・日本語パスとも正しい `position` |
| 12 | `gitlab_summary_post_kind` | 間接（#13 ×2） | ✅ **両分岐を確認**（0件→note、1件以上→thread） |
| 13 | `add_mr_inline_comments` | 直接 | ✅ run1 `{3,0}` / run2 `{2,1}`、巻き添え失敗なし |

### 個別の記録

#### #1・#2 `search_issues` / `normalize_issue_search_results`

実際の戻り値は `merge_issue_search_results` を通った**1行のJSON配列**である。以下は読みやすさの
ため `jq -c '.[]'` で1件ずつ展開し、`url` を省略して掲げたもの（生出力そのままではない）。

```
$ search_issues "検証用" | jq -c '.[]'
{"number":3,"title":"クローズ済みの検証用issue","state":"closed","url":".../-/issues/3"}
{"number":2,"title":"検証用issue ベータ","state":"open","url":".../-/issues/2"}
{"number":1,"title":"検証用issue アルファ","state":"open","url":".../-/issues/1"}
```

並び（3→2→1）が `sort_by(.number) | reverse` と整合しており、統合処理も効いている。

**spec の未決定事項（issue #68）は、GitLab側のみ解消した。** 「GitLab側の `--all` フラグは
`glab` のバージョンによって名称が異なる可能性がある」と書かれていたが、**`glab` 1.114.0 で機能し、
closed のissueも返る**ことを確認した。ただし同項目は
**`gh issue list --search ... --state all --json ...` も未検証**だと書いており、そちらは本検証の
対象外である。**フェーズ4では項目を削除せず、GitHub側だけが残るよう範囲を絞って更新する。**

#### #3 `set_mr_ready`

| 入力 | 実行前 | 実行後 |
|---|---|---|
| 単一接頭辞 | `Draft: issue127 検証用MR` / `draft=true` | `issue127 検証用MR` / `draft=false` |
| 接頭辞なしへ再実行（冪等性） | `issue127 検証用MR` / `draft=false` | 変化なし・エラーなし |
| **二重接頭辞** | `Draft: Draft: 検証MR` / `draft=true` | `検証MR` / `draft=false` |

**二重接頭辞が1回の呼び出しで完全に除去された。** `glab` 側の除去正規表現
`(?i)^(\s*(?:draft:|wip:)\s*)*` が繰り返しにマッチするという実装ソースの読みが裏付けられた。

**spec の未決定事項（issue #61）は、GitLab側のみ解消した。** 同項目は
「あわせて、GitHub側の `github_set_mr_ready`（`gh pr ready`）も本環境では実行できていない」と
明記しており、締めも「`gh`/`glab` が使えるローカル環境で実PRに対して実行し、確認できた時点で
本項目を削除する」である。本検証で走らせたのは `glab mr update --ready` のみ。
**フェーズ4では項目を削除せず、GitHub側だけが残るよう範囲を絞って更新する。**

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

Compareページの初期HTML（34,578バイト）には、**アンカー用のパスハッシュが1件も含まれていなかった**。
40桁hexの文字列自体は27件（ユニーク18件）あるが、それらはコミットSHA等であって目的のものではない。

```
$ grep -oE '[0-9a-f]{40}' compare.html | wc -l                    # 27
$ grep -oE '[0-9a-f]{40}' compare.html | sort -u | wc -l          # 18
$ grep -c '8ec9a00bfd09b3190ac6b22251dbb1aa95a0579d' compare.html # 0  ← README.md のパスsha1
$ grep -c 'dbd436723fcd58b281afcd60bbd2b93e33d9cbca' compare.html # 0  ← docs/検証 用.md
```

GitLab 18.5 は "rapid diffs" 方式で差分を遅延読込しており、初期HTMLは器でしかない。HTML内に
埋め込まれたエンドポイント定義から実体を特定した。

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

**同じnote（id=94）について、GitLab自身が返す値とバイト単位で一致した。** MRの
`discussions.json` 断片に含まれる `noteable_note_url` フィールドが、まさにこの形式である。

```
gitlab_get_note_url の出力  : http://localhost:8929/root/issue127-verify/-/merge_requests/1#note_94
GitLabの noteable_note_url : http://localhost:8929/root/issue127-verify/-/merge_requests/1#note_94
```

note 94 は検証で投稿した返信（`glab api projects/4/merge_requests/1/notes/94` で
`system=false` を確認済み）。

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
- `gitlab_get_mr_url` / `gitlab_get_note_url` が**実運用経路から到達しない**。
  ただし `.claude/scripts/test/test_vcs_provider.sh:703-709` から直接呼ばれており、
  **単体テストは通る**。「テストは緑なのに実運用経路が丸ごと壊れている」という状態であり、
  これがこの不具合が見つからなかった理由でもある。純粋関数を単体で検証するテストは、
  その関数へ**至る呼び出し経路**の健全性を何も保証しない。

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

同じ形の欠落が他に無いかを機械的に確かめた。

```bash
for f in .claude/scripts/src/vcs/Gitlab.sh .claude/scripts/src/vcs/Github.sh; do
  defined="$(grep -oE '^[a-z_]+\(\)' "$f" .claude/scripts/src/vcs/Provider.sh \
             | sed 's/.*://; s/()//' | sort -u)"
  called="$(grep -oE '\b(gitlab|github)_[a-z_]+\b' "$f" | sort -u)"
  for c in $called; do echo "$defined" | grep -qx "$c" || echo "未定義: $f: $c"; done
done
```

- 検査範囲は **`Gitlab.sh` / `Github.sh` の2ファイル**、対象は **`gitlab_` / `github_` 接頭辞を
  持つ参照のみ**（定義側は `Provider.sh` を含む3ファイルから集めた）。
- 結果: 候補42件中、**未定義は `gitlab_get_repo_url` の1件のみ**。
  `Gitlab.sh:64` に現れる `github_search_issues` はコメント中の参照であり、かつ `Github.sh` に
  定義が存在するため候補から外れる。
- **この検査は接頭辞付きの参照しか見ていない。** `Provider.sh` の非接頭辞関数
  （`get_repo_url` / `hash_paths` 等）への呼び出しや、`8d01fbb` が同時に触った
  `.claude/hooks/` 配下は対象外である。フェーズ3で恒久的な検出手段を検討する際は、
  この範囲を広げることも含めて考える。

**修正方針（フェーズ3）**

`gitlab_get_repo_url` → `get_repo_url` に置き換える（2箇所）。あわせて、再発防止として次の2つを
検討する。**単体テストが緑のまま9日間見逃されたので、「関数を単体で検証するテスト」を足すだけ
では防げない**という点が要点である。

1. **未定義関数の呼び出しの静的検出**（上記「同種の点検」のスクリプトを常設化する。
   接頭辞に限らない範囲へ広げるかも含めて検討する）。
2. **呼び出し経路そのものを検証するテスト**（例: `get_mr_unresolved_comments` の出力に
   `url=` が含まれること）。関数単体ではなく、経路の出力を見る。

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

- `get_mr_for_branch` の戻り値で **Draft状態を表すキーは `draft` ではなく `isDraft`**
  （`Gitlab.sh:194` / `Github.sh:171` とも同じ）。存在しない `.draft` を引けば当然 `null` に
  なるが、**これはプロバイダ差ではない**。GitLab実装は `glab mr view <branch> --output json` の
  `work_in_progress` を `isDraft` へ写しており、実測でも真偽値が返る。

  ```
  $ glab mr view feat-127 -R root/issue127-verify --output json \
      | jq '{number: .iid, isDraft: .work_in_progress, draft: .draft}'
  {"number":1,"isDraft":false,"draft":false}
  ```

  （本レポートの初版はここを「GitLabでは `draft` が `null` になる」と誤って書いていた。
  存在しないキー名で問い合わせた結果を欠損と解釈したもので、敵対的レビューの指摘により訂正した。）
- `new_issue`（`glab issue create`）は `- Creating issue in <project>` という進捗行を出すが、
  **stderrへ出ており stdout はJSONのみ**。`new_issue | jq` は安全に書ける。
  ただし `new_issue 2>&1 | jq` のように**stderrを混ぜるとjqが構文エラーになる**。

## 受け入れ条件8: 検証環境の再現手順

> **この節はフェーズ4で `.claude/docs/spec/` 配下へ移す（置き場所は flow-id 4-1 で決める）。**
> `reports/` は片付けのステップで削除されるため、ここに置いたままではmainに残らず、
> 受け入れ条件8を満たさない。

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
#    MSYS_NO_PATHCONV=1 が無いと、git bashがコンテナ内パスを C:/Program Files/Git/etc/... へ
#    変換して失敗する（.claude/rules/shell-script-style.md「git bashのパス変換の落とし穴」）
MSYS_NO_PATHCONV=1 docker exec gitlab cat /etc/gitlab/initial_root_password

# 3. glab を認証する（トークンはOSキーリングへ入る）
glab auth login --hostname localhost:8929 --api-protocol http
export GITLAB_HOST=localhost:8929

# 4a. 検証用プロジェクト（単一namespace）を作る
#     差分アンカーの検証でHTMLをスクリプト取得する場合は visibility=public にする（下記の注記）
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

- **手順4aを `private` のままにすると、差分アンカーの検証（Compareページの
  `diffs_stream` 断片の取得）ができない。** PATヘッダはWebページの認証に効かず302になるため、
  HTMLをスクリプトから取得するにはプロジェクトを `public` にする必要がある。ブラウザで
  ログイン済みなら `private` のままでも目視確認はできる。
- `glab auth status` は `gitlab.com` 側の認証エラーに引きずられて**終了コード2を返す**。
  `set -e` 配下でそのまま呼ばないこと（出力だけを使う）。

## 未完了（範囲内だが、まだ終わっていないこと）

**次の作業へ引き継ぐ。「範囲外」と混同しないこと**（範囲外として spec へ書くと、必要な作業が
落ちる）。

- **URL系4種のブラウザ目視確認**（受け入れ条件2）。自動確認は完了しているが、目視はユーザーの
  回答待ち。自動確認だけでは受け入れ条件2を満たさない。
- **`gitlab_get_mr_url` / `gitlab_get_note_url` の `Provider.sh` 経由での実行**（受け入れ条件1）。
  フェーズ3でディスパッチャを追加してから再実行する。

## 範囲外（今回やらないと決めたこと）

- **gitlab.com（SaaS）・CE 18.5.4 以外のバージョン・EE**。issue #127 の期待する動作7で明示的に
  範囲外としたもの。spec にもその旨を残す。
- **ssh経由のgit操作**。公開鍵が未登録で通らなかったが、鍵の登録は本issueの目的ではないと判断し、
  http + PAT へ寄せた（`Gitlab.sh` の各関数は `glab` のAPI経由で動くため、gitのトランスポートは
  検証結果に影響しない）。

## 設計への反映（フェーズ4で行う）

本検証の知見のうち恒久的に残すものと、その反映先。**`reports/` 配下は片付けのステップで削除
されるため、ここに書いたままではmainに残らない。**

| 反映先 | 内容 |
|---|---|
| `.claude/docs/spec/issue-mr-workflow.md`「未決定事項・懸念点」 | **#61・#68 は削除せず範囲を絞る**（GitLab側のみ解消、GitHub側は未検証のまま）。**#48・#45 の「プロジェクト構成（サブグループ）」は削除**（解消）。**#13（URL形式のブラウザ未検証）はGitLab側の自動確認結果を追記**し、目視の回答が得られた時点で削除を判断 |
| `.claude/docs/spec/issue-mr-workflow.md`「提供関数」表 | 差分アンカーの GitLab 欄の **【未検証】表記を外す**（`#<パスのsha1>`・`diff-` 接頭辞なしを実機確認済み）。ハッシュ入力が**encode前の生パス**である旨を追記 |
| `.claude/docs/spec/shell-scripts.md` | 「GitLab版の実機動作未検証」（165〜166行）と移植表の `Gitlab.sh`「（未検証。GitLab実remoteが無いため）」を更新 |
| `.claude/scripts/src/vcs/Gitlab.sh` ヘッダ | issue #45 で解消済みなのに「未修正」と書いている記述を訂正。検証済み関数の数を実態へ（**#48当時13 − 1 + 今回13 = 25**）。未検証として残るのはバージョン・エディションのみ |
| **新規の置き場所（flow-id 4-1 で決める）** | **「受け入れ条件8: 検証環境の再現手順」節を恒久化する。** 新規specファイルを作る場合は人間の承認が必須 |
| DDR（要否は flow-id 4-1 で判断） | 「単体テストが緑でも呼び出し経路は保証されない」「並行ブランチのsemantic conflictをgitは報告しない」という教訓を残すか |
