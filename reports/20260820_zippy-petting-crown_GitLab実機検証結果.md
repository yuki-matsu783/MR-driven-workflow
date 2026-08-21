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
   **ただし、そのアンカーを付ける先が誤っている**（下の2件目）。
2. **不具合を2件検出した。**
   1件目: **アンカーの付け先がCompareページでは機能しない。** 現在の実装は Compareページ
   （`/-/compare/<from>...<to>`）にアンカーを付けるが、**GitLab CE 18.5.4 のブラウザ実機で
   スクロールしない**（ハッシュは正しいのに飛ばない）。**MR差分ページ
   （`/-/merge_requests/<iid>/diffs`）に同じハッシュを付けると初回から飛ぶ。**
   2件目: `gitlab_get_repo_url` が**未定義のまま2箇所から呼ばれており**、
   `gitlab_get_mr_url` / `gitlab_get_note_url` へ至る**実運用経路が到達不能**になっている
   （単体テストからは直接呼ばれており、テストは通る）。`add_mr_thread_reply` が返すはずの
   パーマリンクが空で返る。
3. **それ以外の11関数は期待どおり動いた。** サブグループ配下でのプロジェクト解決も通った。

**受け入れ条件1（`Provider.sh` 経由での実行）は、フェーズ2終了時点では #5・#6 の2件について
未達だった。** 踏み台にするはずだった公開関数が上記の不具合で到達不能だったため、この2件は
`gitlab_*` を直呼びして実装の正しさだけを確かめている。**フェーズ3でディスパッチャを追加して
再実行し、解消済み**（下記「フェーズ3の実施結果」）。

**不具合2件はフェーズ3で修正済み**で、残るのは修正後のブラウザ目視確認（依頼中）である。
修正の方針・却下案は同節と `plans/【設計】【実装】GitLab差分アンカーの土台と未定義関数呼び出しの修正.md` を参照。

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
| 5 | `get_mr_url` | 直接 | ✅ **フェーズ3でディスパッチャを追加して再実行し、受け入れ条件1を満たした**（下記「フェーズ3の実施結果」） |
| 6 | `get_note_url` | 直接 | ✅ 同上 |
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

**3段目（ブラウザ目視）— ここで2件目の不具合が判明した**

ユーザーに実際に開いてもらった結果、**Compareページのアンカーは飛ばず、MR差分ページのアンカーは
初回から飛んだ。**

| 開いたURL | 結果 |
|---|---|
| `/-/compare/main...feat-127#<sha1>` | **スクロールしない**（ページ先頭のまま） |
| `/-/merge_requests/1/diffs#<sha1>` | **初回から目的の差分へ飛ぶ** |

最初の目視は差分が3ファイルしか無くスクロール量が出なかったため、**34ファイル・約311KB**まで
差分を増やしてやり直した（目的地ファイルを33/34番目に配置し、対照としてアンカー無しURLも並べた）。
それでもCompareページでは飛ばなかった。

**原因の見立て**: `id="<sha1>"` は `<diff-file>` というカスタム要素に付いており、これは
`diffs_stream` が**非同期にストリーム描画する**要素である。ブラウザがフラグメント識別子を解決
する時点ではまだDOMに存在しないため、ネイティブのアンカー移動が空振りする。MR差分ページ側は
描画後に自前でスクロールし直すJSを持っているものと思われる（GitLab自身のページ内リンクは
`#line_<hash>_A<n>` という行単位の別形式である）。

**この失敗様態は、敵対的レビューが「ハッシュが正しくても差分本体が非同期挿入されるために実際には
スクロールしない可能性がある」と指摘していたものそのものである。** 自動確認（`id=` 属性との照合）
だけで済ませていたら「アンカーは正しい」と誤った結論を出していた。**ブラウザ目視を必須にした
判断が、実際に結論を変えた。**

**副次的に判明: GitLabは大きい差分を既定で折りたたむ。** 400行の変更を持つファイルは
`diffs_stream` に本文が出力されない（`collapsed`）。アンカーの飛び先が折りたたまれたファイル
だった場合の挙動は、Compareページ側がそもそも飛ばないため今回は切り分けていない。

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

### 1. 差分アンカーの付け先がCompareページになっており、GitLabでは機能しない

**症状**

`gitlab_get_diff_anchor_url` が生成するURLは、**ハッシュは正しいのにブラウザで目的の差分へ
飛ばない**（上記「3段目（ブラウザ目視）」）。同じハッシュをMR差分ページへ付ければ初回から飛ぶ。

**原因**

アンカーの土台になるURLは、呼び出し元の `.claude/hooks/post-push-compact-prompt.sh` が
**常にCompareページのURL**を渡している。

```bash
# post-push-compact-prompt.sh:292-296
local anchor_compare_url="$diff_url"          # get_mr_diff_url  → /-/compare/<base>...<branch>
[ -z "$since_url" ] || anchor_compare_url="$since_url"   # get_mr_diff_since_url → /-/compare/<sha>...<sha>
build_file_links_text "$repo_url" "$anchor_compare_url" ...
```

GitLab 18.5.4 のCompareページは rapid diffs 方式で差分を非同期描画するため、この土台では
アンカーが効かない。**GitHub側は同じ構造（compare + `#diff-<sha256>`）で issue #42 のときに
実機確認済み**であり、これはGitLab固有の問題である。

**影響**

`post-push-compact-prompt.sh` が出す「重点レビュー対象ファイル」の**差分リンクが、GitLab
リポジトリでは用をなさない**（ファイル単位で差分位置へ誘導するという機能の目的が達せられない）。
blobリンク側は問題なく機能する。

**修正の方向（設計判断はフェーズ3の flow-id 3-1 で決める）**

単純に「MR差分ページへ差し替える」だけでは済まない**トレードオフがある**ため、ここでは選択肢の
提示に留める。

| 案 | 内容 | 問題点 |
|---|---|---|
| A | GitLabのアンカーだけ `<repo>/-/merge_requests/<iid>/diffs#<sha1>` を土台にする | **「前回pushからの差分」という範囲指定が失われる**（MR差分ページはMR全体の差分を出す）。`get_mr_diff_since_url` の意図が消える |
| B | MR差分ページのバージョン指定（`?diff_id=&start_sha=`）を使って範囲も保つ | バージョンIDの解決に追加のAPI呼び出しが要る。GitHub側と処理が非対称になる |
| C | GitLabでは差分アンカーを出さず、blobリンクのみにする | 情報量は落ちるが、壊れたリンクを出すよりはよい |

**この関数はプロバイダ非依存の `get_diff_anchor_url(compare_url, path_hash)` という形をしており、
「どのページを土台にするか」は呼び出し元が決めている。** そのため修正は `Gitlab.sh` だけでは
閉じず、呼び出し元かインターフェースのどちらかに手を入れることになる。

### 2. `gitlab_get_repo_url` が未定義のまま呼ばれている

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

**ブラウザでの目視確認はAIには行えない**ため、ユーザーに開いてもらった。結果は次のとおり。

| 種別 | 生成URL | 自動確認 | ブラウザ目視 |
|---|---|---|---|
| blob | `/-/blob/main/docs/%E6%A4%9C%E8%A8%BC%20%E7%94%A8.md` | HTTP 200 | ✅ **予定どおり動作** |
| 差分アンカー | `/-/compare/main...feat-127#<sha1>` | `id=` 属性と一致 | ❌ **スクロールしない**（不具合1） |
| （参考）同じハッシュをMR差分ページへ | `/-/merge_requests/1/diffs#<sha1>` | — | ✅ **初回から飛ぶ** |
| noteパーマリンク | `/-/merge_requests/1#note_94` | `noteable_note_url` と一致 | ✅ **予定どおり動作** |
| Compare | `/-/compare/main...feat-127` | HTTP 200 | ✅ **予定どおり動作** |

**受け入れ条件2は満たした**（4種すべてのブラウザ表示確認結果が記録されている）。そのうち
差分アンカーだけが期待どおりに動かず、不具合として記録した。

**自動確認だけで終えていたら、誤った結論を出していた。** `id=` 属性とハッシュの一致は
「ハッシュ値が正しい」ことしか示さず、「そのURLがレビュアーを目的の位置へ運ぶ」ことは
示さなかった。

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

## 追記: フェーズ3の計画時に追加で計測した結果

不具合1（差分アンカーの土台）の修正方針を案A/B/Cから選ぶために、同じ検証環境
（`root/issue127-verify` MR !1）で追加計測した結果。**方針の決定そのものはフェーズ3の
個別作業計画で行う**（本節は計測結果のみ）。

### GitLabのMR差分ページの絞り込み（`?start_sha=`）

ページが実際に使う描画経路は `diffs_stream` ではなく **`diffs_batch.json`** である
（初期HTMLの `data-endpoint-batch` 属性で確認。素の `/diffs` も同じ経路）。`diffs_stream` へ
同じパラメータを渡しても無視される（パラメータ有無・不正SHAの3通りで応答が315,838バイトで完全一致）。

```bash
B="…/-/merge_requests/1/diffs_batch.json?diff_head=true&page=0&per_page=30"
curl -s "$B"                          | jq '(.diff_files//[])|length'   # 30
curl -s "$B&start_sha=<v10のhead>"    | jq '(.diff_files//[])|length'   # 1
curl -s "$B&diff_id=11&start_sha=…"   | jq '(.diff_files//[])|length'   # 1
```

| 確認したこと | 結果 |
|---|---|
| `?start_sha=<SHA>` による絞り込み | **効く**。`diff_id` の併用は**不要**（`/versions` への追加API呼び出しは要らない） |
| 絞り込み後のファイル集合 | 「そのSHA以降に変わったファイル」のみ |
| 絞り込み後の `file_hash` | `sha1(パス)` と一致。`docs/mmm-大きい差分.md` → `79ca8e71bf25b4152f332b840fc896571d810b36`（`sha1sum` の出力と同値） |
| **MRバージョンのheadでない `start_sha`** | **HTTP 200のまま0ファイル**。エラーにならず無言で空の差分ページになる（mainのbase commit・でたらめなSHAの2通りで確認） |

最後の行が案Bの弱点になる。`prev_sha` は hook がローカルのHEADから記録する値であり、
**pushを伴わない誤検知でも上書きされる**（`git` と `push` の部分文字列マッチ。issue #23で3回発生）。

### 案Aの機能後退（前pushで追加し今回削除したファイル）

`docs/mmm-大きい差分.md` を「前のpushで追加 → 今回のpushで削除」という状態にして、
同じファイルが土台ページに存在するかを比較した（sha1 = `79ca8e71…`）。

| 土台 | ページに載るファイル数 | 対象ファイルを含むか |
|---|---|---|
| 案A: MR全体の差分（`<mrUrl>/diffs`） | 30 | **0件（含まない）** |
| 案B: `?start_sha=<前pushのhead>` | 1 | 1件（含む） |

`build_file_links_text` は一覧を `diff_range = prev_sha...HEAD` から作り、**削除ファイルにも
差分アンカーを必ず出す**ため、案Aでは**存在しない要素を指すアンカー**が生成される。
現行のCompareページ（`prev_sha...HEAD`）ではこの形にならないので、**案Aは条件付きで現行より
悪くなる**。ファイルの改名も差分上は削除＋追加になるため、同じ形に該当する。

### GitHubのコメントURLの実形式

`github_get_note_url` の形式（`<mrUrl>#discussion_r<id>`）が推測でないことを、本リポジトリの
PR #128 の実コメントで確認した。`Github.sh` は本番経路ではGraphQLの `comment { url }` から
URLを受け取っており文字列を組み立てないが、そのAPIが返す実値は次の形である。

```
url=https://github.com/yuki-matsu783/MR-driven-workflow/pull/128#discussion_r3821657827
```

## フェーズ3の実施結果（flow-id 3-6）

計画: `plans/【設計】【実装】GitLab差分アンカーの土台と未定義関数呼び出しの修正.md`

### 変更したファイル

| ファイル | 変更 |
|---|---|
| `.claude/scripts/src/vcs/Provider.sh` | `get_diff_anchor_base_url` / `get_mr_url` / `get_note_url` の3ディスパッチャを追加。`get_diff_anchor_url` の引数名を `compare_url` → `base_url` へ |
| `.claude/scripts/src/vcs/Gitlab.sh` | `gitlab_get_diff_anchor_base_url` / `gitlab_mr_has_version_head` を追加。未定義の `gitlab_get_repo_url` → `get_repo_url`（2箇所） |
| `.claude/scripts/src/vcs/Github.sh` | `github_get_diff_anchor_base_url` / `github_get_mr_url` / `github_get_note_url` を追加 |
| `.claude/hooks/post-push-compact-prompt.sh` | 土台URLの決定を `get_diff_anchor_base_url` へ委譲。`mr_number` を取得。`build_file_links_text` の引数名とコメントを実態へ |
| `.claude/scripts/test/test_vcs_provider.sh` | 16ケース追加（下記） |

### 不具合2の修正（`Provider.sh` 経由で確認）

検証用クローンをcwdにして実行し、**`url=` が出力へ入るようになった**ことを確認した。
修正前は `command not found` が `2>/dev/null` に握りつぶされ、無言でurl無しへ縮退していた。

```
[unresolved threadId=7e4e5d63… README.md:2 url=http://localhost:8929/root/issue127-verify/-/merge_requests/1#note_87] root: …
```

### 受け入れ条件1の未達だった2件（`Provider.sh` 経由で再実行）

```
get_provider  = gitlab
get_mr_url    = http://localhost:8929/root/issue127-verify/-/merge_requests/1
get_note_url  = http://localhost:8929/root/issue127-verify/-/merge_requests/1#note_94
```

### 不具合1の修正（`get_diff_anchor_base_url`）

ローカルGitLabに対し、4通りの入力すべてが設計どおりに分岐することを確認した。

| 入力 | 出力 |
|---|---|
| `since_sha` 空（初回push相当） | `<mrUrl>/diffs` |
| `since_sha` がMRバージョンのhead | `<mrUrl>/diffs?start_sha=<sha>` |
| `since_sha` がバージョンheadでない | `<mrUrl>/diffs`（縮退） |
| `mr_url` 空（MCP経路相当） | `<repoUrl>/-/compare/…`（従来どおり） |

### GitHub側の出力が変わっていないことの確認

テストの追加だけでは、変更時点で生じた劣化を検出できない。**変更前（`a13f4aa`）と変更後の
`build_file_links_text` を、同じ入力（本リポジトリ＝GitHub remote）に対して実行して
突き合わせた。**

```
old: 2526 バイト / 15 行
new: 2526 バイト / 15 行
diff: 差分なし（完全一致）
```

出力が空でないこと（＝比較が空振りしていないこと）も、先頭3行を目視して確認している。

### テスト

`.claude/scripts/test/test_vcs_provider.sh` に16ケースを追加し、`passed=159 failures=0`。
単体テスト12本すべてが `failures=0` で通る。

- `get_diff_anchor_base_url` の両プロバイダぶん（GitLabは4通りの分岐＋`mr_number` 空）。
  `glab` をシェル関数で差し替えて外部プロセスを使わずに検証している。
- **呼び出し経路のテスト**: `gitlab_get_mr_unresolved_comments` の出力に、noteのパーマリンクが
  **完全な形で**入ることを検証する（`url` の有無ではなく文字列の完全一致）。`glab` に加えて
  `get_repo_url` も差し替える（この関数は `git remote get-url origin` を起動するため、
  差し替えないと origin の無いチェックアウトで落ち、かつ本リポジトリのoriginはGitHubなので
  実在しないGitLab形式のURLで通ってしまい検証にならない）。
- **未定義の `github_*` / `gitlab_*` 呼び出しの静的検出**。修正後は「0件」が恒久的な期待値に
  なり検証が空振りしうるため、(a) 参照件数・定義件数がそれぞれ1件以上あることを表明し、
  (b) `gitlab_get_repo_url` を1箇所だけ書き戻した一時ツリーに対して**実際にその1件を検出できる**
  ことまで確かめている。
  - 実装時に1度失敗した: `mcp_tool_hint` が文字列として持つMCPツール名（`github__list_pull_requests`
    のようにアンダースコア2つ）が識別子パターンに一致し、未定義の関数として9件検出された。
    アンダースコア2つで始まる名前を除外して解決した。

### ブラウザ目視確認（依頼中・未完了）

自動確認では「スクロールするか」を判定できないため、次の4本をユーザーへ提示している。
**いずれも、対象ファイルがそのページの差分に含まれていることをAPIで確認済み**（アンカーが
効かなかった場合に「ファイルが無かっただけ」と紛れないようにするため）。

| # | 目的 | 対象ファイル | ページ内の位置 |
|---|---|---|---|
| 1 | 通常の差分ファイル | `docs/aaa-01.md` | 1/32 |
| 2 | 行数の多いファイル（402行） | `docs/zzz-折りたたみ確認.md` | 31/32 |
| 3 | **前のpushで追加し今回のpushで削除**（案Aとの分かれ目） | `docs/mmm-大きい差分.md` | 31/33 |
| 4 | 多数ファイルの後方（非同期描画の影響） | `docs/zzz-目的地 ファイル.md` | 32/32 |

**2は「折りたたまれた差分」の確認にはなっていない。** 402行のファイルを置いても
`collapsed` が立たなかったため（上記「未完了」）、長いファイルへのスクロールの確認に留まる。

## フェーズ4の実施結果 — 設計反映（flow-id 4-6・1セット目）

計画: `plans/【設計反映】GitLab実機検証の結果をspecとDDRへ反映する.md`

### 反映したもの

| 反映先 | 内容 |
|---|---|
| `.claude/docs/spec/issue-mr-workflow.md`「未決定事項・懸念点」 | #61・#68・#13・#86 を**GitHub側のみ残す形へ範囲を絞った**。issue #42 の「GitLab側の重点ファイルリンク・コメントパーマリンクは【未検証】」は**前提そのものが成立しない**ため削除。#48・#45 の「プロジェクト構成（サブグループ）」も削除。差分アンカーの項目はGitLab側の結論（Compareページでは飛ばない）へ書き換え、**折りたたみの挙動を新規項目として追加** |
| 同「提供関数」表 | `get_diff_anchor_url`（引数名 `<baseUrl>` へ）・`get_diff_anchor_algo`・`add_issue_comment` の【未検証】を除去。**新規3行**（`get_diff_anchor_base_url` / `get_mr_url` / `get_note_url`）を追加 |
| 同 仕様本文 | 差分アンカーのハッシュ算出方法の節へ、GitLab側の実機確認結果と**「土台にするページはプロバイダで異なる」**を追記。「差分アンカーリンク（Compareページ内の…）」の表記も修正 |
| 同「影響範囲」 | **`### issue #127` エントリを追加**（不具合2件・変更ファイル・GitHub側の非後退確認・受け入れ条件1の経緯） |
| `.claude/docs/spec/adversarial-review.md` | 「非インラインのスレッド投稿は未検証」を、run1/run2 の実測値つきで**実機確認済みへ書き換え** |
| **`.claude/docs/ddr/0059-…md`（新規）** | 差分アンカーの土台の決定。原則・却下案（案A/案C/案B'）・**残した妥協**・DDR 0037 との関係 |
| `.claude/docs/spec/shell-scripts.md` | 移植表と「GitLab版の実機動作未検証」を、残る範囲（バージョン・エディション）へ絞った |
| `.claude/scripts/src/vcs/Gitlab.sh` | ヘッダを issue #48/#45/#127 の3段構成へ書き換え。**関数数を 27 と明記**し数え方も残した。関数個別の【未検証】マーカー2件（`gitlab_diff_anchor_algo` / `gitlab_add_issue_comment`）を除去 |
| **`.claude/docs/spec/gitlab-verification-environment.md`（新規）** | 受け入れ条件8の再現手順を恒久化（**flow-id 4-4 で作成の承認を得た**）。接続手段・PATの扱い・`glab auth status` の終了コード・Webページ取得にPATが効かないこと・差分の描画経路・`glab issue create` の stdout/stderr 分離まで含む |
| `.claude/docs/README.md` | spec一覧へ新規specを、DDR一覧へ 0059 を追記 |

### 検証結果

| 検証 | 結果 |
|---|---|
| frontmatterインデックスの再生成 | `files=108 built=11 reused=97 failed=0`。新規2ファイルとも `index.jsonl` に載った |
| DDR番号の重複 | 無し |
| `Gitlab.sh` の関数数 | **27**（ヘッダの記述と一致） |
| `bash -n .claude/scripts/src/vcs/Gitlab.sh` | 構文OK |
| 単体テスト | `test_vcs_provider` 170 / `test_search_frontmatter` 114 / `test_extract_frontmatter` 32 / `test_collect_review_points` 17、いずれも `failures=0` |

**「未検証」「未修正」「GitLab remote」の残存を、反映先4ファイルに対して洗い出した**（0件を
期待するのではなく、1件ずつ分類した）。結果、**取り残しが1件見つかり修正した**。

- **取り残し（修正済み）**: （issue #13）`get_mr_diff_url`/`get_mr_diff_since_url` のURL形式。
  計画の表からこの項目が落ちていた。GitLabのCompareページはブラウザで表示確認済みなので、
  GitHub側のみ残す形へ絞った。
- **意図して残したもの**: GitHub側が未検証の項目（#61 `gh pr ready` / #68 `gh issue list` /
  #86 `gh issue comment` / #13 GitHubのCompareページ / 差分アンカーのGitHub側スクロール）、
  バージョン・エディション、折りたたみの挙動（新規追加）、および今回と無関係な項目
  （Gemini CLI・対応工数レポート・サブエージェント関連）。
- **触っていないもの**: `## 影響範囲` 配下の過去エントリ（issue #25 / #42 / #86 の変更ファイル
  一覧に含まれる「【未検証】」の表記）。**point-in-timeの記録であり、書き換えると当時の状態が
  失われる**（`.claude/rules/docs-workflow.md`）。一括置換を使わず、現在の仕様を説明している節
  だけを個別に直した。

### 敵対的レビュー（フェーズ4・2回目）の指摘と対応

12件の指摘を受け、確度×重大度の振り分けで**7件をMRへインラインコメントとして投稿**した
（`{"posted":7,"summarized":0}`）。**投稿・報告の別によらず、実ファイルと突き合わせて
正しいと確認できたものはすべて修正した**（12件中11件を修正、1件は仕様の限界として明記）。

| # | 指摘 | 判定 | 対応 |
|---|---|---|---|
| 1 | `adversarial-review.md` run1 の「サマリは投稿されない」が実装と矛盾 | **正しい**（`gitlab_summary_post_kind` は0件で `note` を返し、`gitlab_add_mr_comment` が必ず1件投稿する） | 「0件の分岐（単発note）を通った。0件でも投稿は行われる」へ書き換え |
| 2 | 「全27関数を `Provider.sh` 経由で実機実行」が同commitの他記述と矛盾 | **正しい**（ディスパッチャを持つのは20関数。7関数は間接確認） | `shell-scripts.md` 2箇所と `Gitlab.sh` ヘッダを「20関数は直接／7関数は間接」へ |
| 3 | 「残る未検証はバージョン・エディションの1点だけ」が同じ節の他項目と矛盾 | **正しい**（同じ節に目視未完了・折りたたみ未検証が残っている） | 「関数がAPI経路で動くこと」と「URLがブラウザで働くこと」を分けて記述 |
| 4 | 差分アンカーの説明に旧引数名 `compareUrl` と旧仕様の地の文が残存 | **正しい**（提供関数表・実装は `base_url` へ変更済み） | `<baseUrl>` へ直し、土台の決定は `get_diff_anchor_base_url` が行うと明記 |
| 5 | 新規specに `## 背景・目的` `## 未決定事項・懸念点` が無い | **正しい**（既存specは全て持つ） | 両節を追加し、折りたたみの未解決事項を「落とし穴」節から移設 |
| 6 | 手順5のPAT取得が、同ファイルが警告している2点（接頭辞決め打ち・終了コード2）を自ら踏んでいる | **正しい** | `\|\| true` を添え、接頭辞に依存しない取り出し方へ（実際の出力行で動作確認済み） |
| 7 | 検証状況の「正」が2つ挙げられ、実際は4ファイルへ分散 | **正しい**（実際に `Gitlab.sh` ヘッダとspecが食い違っていた） | 正を `issue-mr-workflow.md` の1箇所に決め、他3ファイルは参照のみへ |
| 8 | issue #127 のchangelog表にドキュメント変更が1件も無い | **正しい** | 新規2ファイルを含む7行を追加 |
| 9 | DDRだけ読むと採用形（`?start_sha=` 付き）がブラウザ確認済みに読める | **正しい**（実測は絞り込みが効くことのみ） | 「目視で確認できているのはパラメータ無しまで」を明記 |
| 10 | 原則「土台の範囲＝`diff_range`」が、ベース取り込みを挟むpushでも成立するかは未確認 | **正しい**（確認したのはベース取り込みを挟まない形のみ） | DDRへ限界として明記し、確かめ方も残した |
| 11 | 折りたたみ検証の「32ファイル」とDDRの「30ファイル」が突き合わない | **断面が違う**（`diffs_batch.json` の1応答 対 MR全体） | 何を数えた値かを併記 |
| 12 | `get_mr_url`/`get_note_url` がGitHub側も issue #42 起源に読める | **正しい**（GitHub実装は #127 新設） | 「GitLab実装は #42、GitHub実装とディスパッチャは #127」へ |

**この回で最も重いのは #2・#3・#7 の3件で、いずれも「同じ主張を複数ファイルへ複製したこと」に
起因する。** 今回の設計反映そのものが「ヘッダの記述が実態と合わなくなった」ことの訂正だったのに、
**訂正の過程で同じ構造（4ファイルへの複製）を新たに作っていた**。正を1箇所に決めて他は参照に
するところまでやらないと、同じ陳腐化が次のissueで再発する。

修正後の再検証: frontmatterインデックス `files=109 built=7 reused=102 failed=0` /
DDR番号の重複なし / `bash -n .claude/scripts/src/vcs/Gitlab.sh` OK /
`grep -c '^gitlab_[a-z0-9_]*()'` = 27 / 単体テスト12本すべて `failures=0`。

## フェーズ4の実施結果 — AIアセット反映（flow-id 4-6・2セット目）

計画: `plans/【AIアセット反映】検証中に気づいたルールの不備を反映する.md`

**「今回たまたま起きたこと」ではなく「同じ失敗が次も起きる形になっているもの」だけを入れる**
という計画の方針どおり、**本issueで実際に踏んだ失敗のみ**を反映した。

### 反映したもの

| 反映先 | 内容 |
|---|---|
| `.claude/rules/shell-script-style.md`「テスト」節 | 5項目を追記。**純粋関数のテストは呼び出し経路を保証しない**（不具合2の本質）／**`unset -f` は実定義を消す**（bashの関数定義はスタックしない）／**`declare -F <名前>` は名前だけを出力する**／**接頭辞での静的検出はMCPツール名・jqのフィールド名を巻き込む**／**「異常が無ければ何も出ない」検出は空振りする** |
| 同 **新設 `## 秘密情報の扱い`** | **マスクは、そのパターンが実データに当たることを確かめてから使う**。「テスト」節の話ではないため独立した節にした |
| `.claude/skills/resolve-conflict/SKILL.md`「想定される失敗と対処」 | **「マージ後もテストが緑のまま、後で壊れていたと分かる」**類型を1行追加。既存の「マージ後にテストが落ちる」（semantic conflict）と対になる。予防策は重複させず `shell-script-style.md` を参照させた |
| `reports/REVIEW-POINTS.md`「HTML版」 | **同期を「追記」だけで済ませていないか**。判定の目安（md側の差分が「追加のみ」でないならHTML側も追加のみでは同期していない）も添えた |
| `plans/REVIEW-POINTS.md`「内容」 | **置き換え指示は前後の形を両方書く**（巻き添えを計画段階で検出するため）／**同一計画内の別の作業が、ある作業の前提を崩していないか** |
| `.claude/rules/git-workflow.md`「コミット運用」 | **`git status` の出力を機械的に全件渡さない**（`bash.exe.stackdump` を1度コミットした）／**新種の副産物を見つけたら `.gitignore` へ追加する**（一般則。除外リストそのものの運用は `commit` スキル側） |
| `.claude/rules/docs-workflow.md`「レビュー往復が何周目か」 | **ループ範囲へ「初めて」入るときは `add-round` ではなく `set-header --loop`**。既にある2つの記述（`add-round` のエラー条件・`set-header --loop` の逃げ道）を具体例で結び付けただけで、新しい事実は足していない |
| **`REVIEW-POINTS.md`（ルート）「ドキュメントの構造」** | **計画外の追加**。直前の敵対的レビュー（フェーズ4・2回目）で判明した2件——**「正」を2つ挙げない**／**要約した記述を詳細側と突き合わせる**——を、既存の「同じ内容が複数ファイルに重複して書かれていないか」の下位項目として足した |

### 反映しなかったもの・判断

- **並行ブランチのsemantic conflictをgitは報告しない**という教訓は、`resolve-conflict/SKILL.md` に
  既存の記述（「マージ後にテストが落ちる」）がある。**重複と判断して見送るのではなく、
  「テストが落ちないため気づけない」という別の失敗様態として1行足した**（本issueの実例は
  テストが緑のままだったため、既存の行ではカバーされない）。
- `add-round` のスクリプト自体を「初回も通る」ように変更することは行っていない（計画の
  「この計画で決めないこと」どおり、挙動の変更ではなく仕様の明文化に留めた）。
- 各教訓の置き場所は**1ファイルずつ**にした。`grep -rl` で、5つの実例がいずれも1ファイルにしか
  無いことを確認している。

### 検証結果（計画の5項目）

| # | 検証 | 結果 |
|---|---|---|
| 1 | frontmatter・`extract-frontmatter.sh` | `files=110 built=10 reused=100 failed=0` |
| 2 | 挿入位置の前後3行を目視（地の文の係り先） | 4ファイルとも確認。`shell-script-style.md` は**「テスト」節の末尾に地の文が無い**ことを確かめたうえで新節 `## 秘密情報の扱い` を後置した |
| 3 | 同じ内容を複数ファイルへ重複させていないこと | `declare -F` / `stackdump` / 「初めて入る」/「追記」だけ／「マスク（伏せ字）」の5語で `grep -rl` し、**いずれも1ファイル**であることを確認 |
| 4 | 単体テスト全数 | 12本すべて `failures=0` |
| 5 | 設計反映側 §6 が委譲した2件を受け取っていること | 2件とも受け取り済み（呼び出し経路の教訓 → `shell-script-style.md`／semantic conflict の実例 → `resolve-conflict/SKILL.md`） |

## 未完了（範囲内だが、まだ終わっていないこと）

**次の作業へ引き継ぐ。「範囲外」と混同しないこと**（範囲外として spec へ書くと、必要な作業が
落ちる）。

- **修正後の差分アンカーのブラウザ目視確認**（4本。下記「フェーズ3の実施結果」）。自動確認では
  「スクロールするか」を判定できないため、これが済むまで不具合1は解消と見なさない。
- **折りたたまれた差分に対するアンカーの挙動**。402行のファイルを含む差分を作り直したが、
  `diffs_batch.json` では `collapsed` が1件も立たず（32ファイル全件が展開された）、
  **折りたたみを再現できていない**。畳まれる条件（ファイル単体の行数ではなく、ページ全体の
  規模に依存すると思われる）が特定できていない。

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
| `.claude/docs/spec/issue-mr-workflow.md`「提供関数」表 | 差分アンカーの GitLab 欄の **【未検証】表記を外す**（`#<パスのsha1>`・`diff-` 接頭辞なしを実機確認済み）。ハッシュ入力が**encode前の生パス**である旨を追記。あわせて**Compareページではアンカーが機能しない**制約を明記する |
| **DDR（不具合1の設計判断）** | 差分アンカーの土台をどのページにするか（案A/B/C）を決めた記録。「同じハッシュでもページによって効く／効かないが変わる」というのは、GitHub側の前例からは予測できなかった事実であり、却下案も含めて残す価値がある |
| `.claude/docs/spec/shell-scripts.md` | 「GitLab版の実機動作未検証」（165〜166行）と移植表の `Gitlab.sh`「（未検証。GitLab実remoteが無いため）」を更新 |
| `.claude/scripts/src/vcs/Gitlab.sh` ヘッダ | issue #45 で解消済みなのに「未修正」と書いている記述を訂正。検証済み関数の数を実態へ（**#48当時13 − 1 + 今回13 = 25**）。未検証として残るのはバージョン・エディションのみ |
| **新規の置き場所（flow-id 4-1 で決める）** | **「受け入れ条件8: 検証環境の再現手順」節を恒久化する。** 新規specファイルを作る場合は人間の承認が必須 |
| DDR（要否は flow-id 4-1 で判断） | 「単体テストが緑でも呼び出し経路は保証されない」「並行ブランチのsemantic conflictをgitは報告しない」という教訓を残すか |
