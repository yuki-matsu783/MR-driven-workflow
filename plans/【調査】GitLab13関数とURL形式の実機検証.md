---
title: 【調査】GitLab13関数とURL形式の実機検証
type: plan
description: ローカルGitLab CE 18.5.4に対しProvider.sh経由で未検証13関数・URL系4種・サブグループ解決を実機検証するための個別調査計画。
tags: [gitlab, verification, provider, plan]
keywords: [GitLab CE, glab, Provider.sh, 差分アンカー, sha1, サブグループ, PAT, 検証手順, discussions API]
---

# 【調査】GitLab13関数とURL形式の実機検証

- issue: [#127](https://github.com/yuki-matsu783/MR-driven-workflow/issues/127) / PR: [#128](https://github.com/yuki-matsu783/MR-driven-workflow/pull/128)
- 全体作業計画: `plans/zippy-petting-crown.md`
- 対応するflow-id: 2-1（本計画） → 2-6（実施）

## 目的

`Gitlab.sh` 25関数のうち issue #48 の実機検証を受けていない**13関数**を、`gitlab_*` の直呼びでは
なく **`Provider.sh` 経由**でローカルGitLab CE 18.5.4に対して実行し、期待どおり動くことを確認する。
あわせてURL系4種の正否とサブグループ配下でのプロジェクト解決を確認する。

**この計画は「どう検証するか」だけを決める。結果は `reports/` へ書く。**

## 前提

### 環境（flow-id 1-4 の事前調査で確認済み）

| 項目 | 値 |
|---|---|
| GitLab | CE 18.5.4（Docker、コンテナ名 `gitlab`、`Up (healthy)`） |
| エンドポイント | `http://localhost:8929`（API: `http://localhost:8929/api/v4/`） |
| `glab` | 1.114.0。`localhost:8929` に `root` でログイン済み（トークンはOSキーリング） |
| 既存プロジェクト | `root/issue45-verify`（id=1）。**本issueでは一切触らない**（下記「やらないこと」） |

### 接続手段は http + PAT に決めた（flow-id 2-1 で実測して切り分け）

`glab` の設定上のgitプロトコルは ssh だが公開鍵が未登録で通らず、素の http クローンは
Git Credential Manager が介在して失敗する。**`-c credential.helper=` でGCMを無効化し、PATを
URLへ埋めてクローンする**手段を採る。切り分けの実測ログは worklog に、結果としての判断は
`reports/` に残す（本計画には結論だけを置く）。

**ssh鍵の登録・コンテナの作り直しは本issueの目的ではないので行わない。**

### PATの取り扱い（`.git/config` に残る前提で運用する）

URLへPATを埋めてクローンすると、**クローン先の `.git/config` にPATが平文で永続化される**。
「ファイルへ書かない」では済まないので、次の3点を守る。

1. **クローン直後に `git remote set-url origin` でPATを外す。**
   `Provider.sh` の `get_provider` / `get_repo_url` は `git remote get-url origin` を読むため、
   PATが残っていると `git remote -v` の出力をそのまま記録へ貼った瞬間に漏れる。
   リモートへの反映が必要なときだけ、その場でPAT付きURLを引数で渡す。
2. **クローンはスクラッチパッド配下に置き、検証終了時にディレクトリごと削除する。**
3. **記録へ貼る出力のマスクは、接頭辞の決め打ちではなく環境変数の値そのものを置換する。**
   `glpat-` は既定の接頭辞にすぎず（`personal_access_token_prefix` で変更可能）、正規表現の
   決め打ちは取りこぼす。

```bash
TOKEN="$(glab auth status --show-token 2>&1 | grep -oE 'glpat-[A-Za-z0-9._-]+' | head -1)"
mask() { sed -e "s|${TOKEN}|<redacted>|g"; }   # 値そのものを置換する
```

`glab auth status` は `gitlab.com` 側の401に引きずられて**終了コード2を返す**ため、
`set -e` 配下で素朴に呼ばない（終了コードを見ず出力だけを使う）。

### `Provider.sh` を source したシェルは `set -euo pipefail` になる

`Provider.sh` 冒頭が `set -euo pipefail` を宣言しており、source した呼び出し側シェルにも効く。
本計画は**意図的に失敗させて確かめるケース**（不正なfinding、冪等性、サブグループでの崩れ方）を
含むため、次を守る。

- **1関数につき1回のシェル呼び出しにする**か、`if func ...; then ok=0; else ok=$?; fi` の形で受ける。
- **`"$(func; echo $?)"` の形で終了コードを取らない**（`-e` によりサブシェルが `echo` に到達せず
  空文字列になる。`.claude/rules/shell-script-style.md`「テスト」）。

## 検証環境の作り方

以降、`REPO` は本リポジトリの絶対パス、`WORK` はスクラッチパッド配下の作業ディレクトリを指す。

1. 検証用プロジェクト `root/issue127-verify` を新規作成する。
2. `-c credential.helper=` + PAT付きURLでクローンし、**直後にPATを外す**。
3. `main` に数ファイル（**日本語ファイル名・スペースを含むパスを必ず含める**）をコミットし、
   検証用featureブランチを作って差分を作る。
4. 以降の `Provider.sh` 経由の呼び出しは、**このクローンをcwdにして**実行する
   （`get_provider` が `git remote get-url origin` を見るため、cwdが判定を決める）。
5. サブグループ検証用に `grp127/sub127/issue127-verify-sub` を別途作る。
6. **受け入れ条件8のための環境情報を、この時点で採取する**（下記）。

```bash
source "$REPO/.claude/scripts/src/vcs/Provider.sh"   # 以降のコマンドはこれを済ませた前提
```

`.mrworkflow.json` は検証用クローンに存在しないが、`get_workflow_config` の既定値は本リポジトリの
設定と同値であり、検証結果に影響しない。

### 受け入れ条件8のための情報採取（フェーズ2で行う）

再現手順の**元情報は、コンテナが生きている今しか採れない**。整形して正史のどこへ置くかは
flow-id 4-1 で決めるが、**採取そのものはこのフェーズで行い、生ログを `reports/` に残す**。

```bash
docker inspect gitlab | jq '.[0] | {Image: .Config.Image, Ports: .HostConfig.PortBindings,
  Mounts: [.Mounts[] | {Source, Destination}], Env: .Config.Env}'
glab auth status 2>&1 | mask
```

あわせて、本節のプロジェクト作成コマンドと `glab auth login` の方式も記録する。

## 検証対象と、何をもって「動いた」とするか

副作用の無いものから進める（**純粋関数 → URL組み立て → CLI呼び出し**）。

### `Provider.sh` に公開関数が無い3件がある（重要）

13関数のうち **#5 `get_mr_url` / #6 `get_note_url` / #10 `add_mr_thread` は、`Provider.sh` に
ディスパッチャが存在しない**（`add_mr_thread_reply` はあるが `add_mr_thread` は無い）。
`#11 build_discussion_body` / `#12 summary_post_kind` も同様である。これら5件は
**公開関数を踏み台にした間接確認**になる。「直接呼べない」ことを承知のうえで、どの経路で
踏むかを固定する。

| # | 関数 | 踏み台にする公開関数 | 結果がどこに現れるか |
|---|---|---|---|
| 5 | `gitlab_get_mr_url` | `get_mr_unresolved_comments` / `add_mr_thread_reply` | 出力の `url=<MR URL>#note_<id>` の前半（Gitlab.sh:163,181） |
| 6 | `gitlab_get_note_url` | `add_mr_thread_reply` | 同関数の戻り値そのもの（Gitlab.sh:182） |
| 10 | `gitlab_add_mr_thread` | `add_mr_inline_comments`（サマリが1件以上のとき） | GitLab上にスレッドが作られる（Gitlab.sh:395） |
| 11 | `gitlab_build_discussion_body` | `add_mr_inline_comments` | インラインコメントの位置と本文 |
| 12 | `gitlab_summary_post_kind` | `add_mr_inline_comments` | サマリがスレッドか単発noteか |

**この事実は `reports/` に明記する。** 「ディスパッチャ経由で13関数すべてを直接呼べた」と
書かないこと。

### グループA: 純粋関数

| # | 検証 | 判定 |
|---|---|---|
| 2 | `search_issues "検証"` | `iid`→`number`・`web_url`→`url`・`opened`→`open` の変換が実データで起きる |
| 9 | `get_diff_anchor_algo` | `sha1` を返す |
| 11 | 上表のとおり間接 | 新規行／削除行／コンテキスト行の3パターンで妥当な `position` が組まれる |
| 12 | 上表のとおり間接 | 0件→`note`、1件以上→`thread`（**両分岐を通す**。グループC #13参照） |

### グループB: URL（issueの言う「4種」）

**issue #127 が言う「URL系4種」は blob・差分アンカー・noteパーマリンク・Compareページ**であり、
**関数の4件とは対応しない**。Compareページ（`get_mr_diff_url`）は #48 で「API経由の動作」だけを
確認した関数だが、**ブラウザ表示は未確認**（spec の未決定事項 issue #13）なので、本計画では
URL種別として検証対象に含める。

| URL種別 | 生成 | 判定 |
|---|---|---|
| blob（#7） | `get_blob_url "$(get_repo_url)" main "$REPLY"` | PAT付きで200が返り、**サインインへリダイレクトされない**。日本語・スペース入りパスでも同じ |
| 差分アンカー（#8・#9） | `get_diff_anchor_url "$(get_mr_diff_url "$(get_repo_url)" main feat)" "$hash"` | 下記3段で `sha1` 前提の正否を確定させる |
| noteパーマリンク（#6） | `add_mr_thread_reply` の戻り値 | 実在するnote IDを指し、その位置が開く |
| Compare（`get_mr_diff_url`） | `get_mr_diff_url "$(get_repo_url)" main feat` | PAT付きで200が返り、差分が表示される |

```bash
url_encode_path_to_reply 'docs/検証 用.md'          # → REPLY にencode済みパス
get_blob_url "$(get_repo_url)" main "$REPLY"
hash_paths "$(get_diff_anchor_algo)" 'docs/検証 用.md'   # → sha1
```

**#8（差分アンカー）が本issue最大の焦点。** `diff-` 接頭辞なしの `#<パスのsha1>` という前提の
正否を、次の順で確定させる。

1. `hash_paths "$(get_diff_anchor_algo)" <path>` と `sha1sum` の自前計算が一致するか
   （実装内部の整合。これだけでは前提の証明にならない）。
2. **`get_diff_anchor_url` が指すのと同じCompareページのHTMLを取得し、`id=` 属性を抜き出して
   1. の値と突き合わせる。** これが直接証拠になる。GitHub側では issue #42 でこの方法を使い、
   Compareページが遅延読込する `file-list` 断片HTMLに `id="diff-<sha256(パス)>"` が出ることを
   75ファイルぶん照合している（spec「差分アンカーのハッシュ」）。GitLabでも同じ形で照合する。
   - **HTTPステータスは証拠にならない**。フラグメント識別子（`#...`）はサーバーへ送られないため、
     アンカーが正しくても誤っても同じステータスになる。ステータスは「ページがPAT付きで200を
     返すか」という別の判定にのみ使う。
   - private プロジェクトなので、**取得時は `PRIVATE-TOKEN` ヘッダを付ける**（未認証だと存在する
     パスでも404／サインインへの302になり、URL組み立ての誤りと区別がつかない）。
   - ハッシュの入力が `new_path` か `old_path` か、**percent-encode前か後か**も、この照合で
     切り分ける（encode前後で `id=` と一致する側が答え）。
3. **上記の結果にかかわらず、4種それぞれ代表1本のURLをユーザーへ提示してブラウザで開いてもらう**
   （下記「ユーザーへ依頼する確認」）。ハッシュが正しくても、差分本体が非同期挿入されるために
   実際にはスクロールしないという別の失敗様態があり、照合だけでは潰せない。

### グループC: CLI呼び出し

| # | 実行 | 判定 |
|---|---|---|
| 1 | `search_issues "検証" "コメント"` | open/closed 双方が返る。**`glab` の `--all` フラグがこのバージョンで通るか**を特に見る（spec の未決定事項が名指ししている） |
| 3 | `set_mr_ready <iid>` | `Draft:` 接頭辞が外れる。**接頭辞の無いMRに対して冪等**（2回目もエラーにならずタイトルが変わらない）。**`Draft: Draft:` の二重接頭辞も外れるか**（`(?i)^(\s*(?:draft:\|wip:)\s*)*` が繰り返しにマッチするか） |
| 4 | `add_issue_comment <iid> <file>` | issue側へコメントが1件付く（MRではない） |
| 10 | 上表のとおり間接（#13経由） | **解決可能なスレッド**として付く（単発noteではない） |
| 13 | 下記のとおり**2回**実行する | 戻り値と、サマリの投稿形態 |

**#13 は2回実行する。** 1回の実行では `summary_post_kind` の片方の分岐しか通らないため。

1. **全件が有効なfindings** → `{"posted":N,"summarized":0}` が返り、サマリが**単発note**で付く。
2. **確実に拒否される finding を混ぜる** → `summarized>=1` が返り、サマリが**スレッド**で付く。
   他の指摘が巻き添えで失敗しないことも確認する。
   - 拒否させる入力は「**diffに含まれないパス**」を使う。不正な行番号はAPIが受理して
     outdated なdiscussionになる可能性があり、その場合 `posted` が増えて `summarized=0` となり、
     **検証が何も検出しないまま成功に見える**。
   - 本番前に、選んだ不正入力を `glab api ... discussions` で1件だけ直接叩き、**実際に拒否される
     ことを確かめてから**進む。

`Draft: Draft: 検証MR` は `root/issue127-verify` 側に**自分で作って**入力にする
（二重接頭辞は再現可能であり、既存プロジェクトに依存する必要がない）。

### グループD: サブグループ解決

`grp127/sub127/issue127-verify-sub` のクローンをcwdにして `get_repo_slug` / `get_issue` /
`get_mr_for_branch` が通るかを見る。`get_repo_slug` は `owner`/`repo` の2階層しか持たないため、
**3階層以上のnamespaceで `owner` に何が入るか**を確認する（ここが崩れると、CLI不在時のMCP
フォールバック手順にも影響する）。

## ユーザーへ依頼する確認

ブラウザでの表示確認は人間の目が要る。**自動確認の成否にかかわらず必須**とし、URL系4種それぞれ
代表1本を一覧で提示して「意図した位置を指しているか」を回答してもらう。フェーズ2の終盤で
一度にまとめて依頼する。

## 記録先

- 正文: `reports/20260820_zippy-petting-crown_GitLab実機検証結果.md`
  - 関数ごとに「呼び出したコマンド／実際の出力（PATはマスク）／期待どおりか／差異」を表で残す。
  - **`Provider.sh` に公開関数が無い5件は、間接確認である旨を明記する。**
  - 受け入れ条件8のための環境情報（`docker inspect` 等）の生ログ。
- 視覚化: 同名 `.html`（TailwindCSS CDN、表形式。関連図が主題ではないのでcanvas形式は使わない）
- 試行錯誤: `worklog/20260820_zippy-petting-crown_【調査】GitLab13関数とURL形式の実機検証_push2.md`

## やらないこと

- gitlab.com（SaaS）・CE 18.5.4 以外のバージョン・EE での確認（issue の期待する動作7で範囲外）。
- ssh鍵の登録、コンテナの作り直し。
- **見つかった不具合の修正**（フェーズ3で行う）。本フェーズでは事実の記録に留める。
- **`root/issue45-verify` には一切触らない**（読み取りも含め、検証の入力に使わない）。過去の
  検証記録として参照されうるため。必要な状態は `root/issue127-verify` 側に自分で作る。
- issue #48 で検証済みの関数の**API経路の**再検証。ただし **Compareページのブラウザ表示だけは
  別**で、#48 が確認したのはAPI経路のみのため本計画の対象に含める（グループB）。

## 完了条件

1. 13関数すべてについて実行結果が `reports/` に記録されている（`Provider.sh` の公開関数経由か、
   踏み台経由の間接確認かの区別つき）。
2. 差分アンカーの `sha1` 前提の**正否が判明している**（`id=` 属性との照合による直接証拠つき）。
3. URL系4種のブラウザ表示確認の回答が記録されている。
4. サブグループ配下での解決結果が記録されている。
5. 受け入れ条件8のための環境情報が採取され、`reports/` にある。
6. 見つかった不具合が、フェーズ3で修正できる粒度（再現手順つき）で列挙されている。
