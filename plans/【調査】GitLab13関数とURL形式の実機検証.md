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
なく **`Provider.sh` のディスパッチャ経由**でローカルGitLab CE 18.5.4に対して実行し、期待どおり
動くことを確認する。あわせてURL系4種の正否とサブグループ配下でのプロジェクト解決を確認する。

**この計画は「どう検証するか」だけを決める。結果は `reports/` へ書く。**

## 前提（flow-id 1-4 の事前調査で確認済み）

| 項目 | 値 |
|---|---|
| GitLab | CE 18.5.4（Docker、コンテナ名 `gitlab`、`Up (healthy)`） |
| エンドポイント | `http://localhost:8929`（API: `http://localhost:8929/api/v4/`） |
| `glab` | 1.114.0。`localhost:8929` に `root` でログイン済み（トークンはOSキーリング） |
| 既存プロジェクト | `root/issue45-verify`（id=1）。branches 4本・MR 3件・issue 2件が残存 |

### git操作は http + PAT で行う（ssh は使えない）

- `glab` の設定上のgitプロトコルは **ssh** だが、`ssh -p 2224 git@localhost` は
  `Permission denied (publickey)` で通らない（公開鍵が未登録）。**ssh鍵の登録は本issueの
  目的ではないので行わない。**
- 素の http クローンは Git Credential Manager が介在して `helper error (143)` になる。
  **`git -c credential.helper= clone "http://oauth2:<PAT>@localhost:8929/<path>.git"`** の形で
  クローンする（GCMを無効化し、認証情報をURLへ埋める）。
- **PATをファイルへ書かない。** 実行のたびに
  `glab auth status --show-token` から取り出して環境変数へ入れ、コマンド内でのみ使う。
  出力を記録に残す際は `sed -E 's/glpat-[A-Za-z0-9._-]+/<redacted>/g'` を通す。
- 埋め込んだ認証情報が生成URLへ漏れないことは、`split_remote_url` が最初の `/` より前の `user@` を
  落とす実装であることと、実測（`get_repo_url` → `http://localhost:8929/root/issue45-verify`）の
  両方で確認済み。

## 検証環境の作り方

1. スクラッチパッド配下に作業ディレクトリを作る（**本リポジトリのツリーは汚さない**）。
2. GitLab上に**本issue専用のプロジェクト** `root/issue127-verify` を新規作成する。既存の
   `root/issue45-verify` は過去の検証記録として参照されうるため**再利用も削除もしない**。
3. 上記の http+PAT でクローンし、`main` に数ファイルをコミットして push、続けて検証用の
   featureブランチを作って差分を作る。
4. 以降の `Provider.sh` 経由の呼び出しは、**このクローンをcwdにして**実行する
   （`get_provider` が `git remote get-url origin` を見るため、cwdが判定を決める）。
   `Provider.sh` は本リポジトリの絶対パスから `source` する。
5. サブグループ検証用に `grp127/sub127/issue127-verify-sub` を別途作る。

`.mrworkflow.json` は検証用クローンに存在しないが、`get_workflow_config` の既定値は本リポジトリの
設定と同値であることを実測済みで、検証結果に影響しない。

## 検証対象と、何をもって「動いた」とするか

副作用の無いものから順に進める（**純粋関数 → URL組み立て → CLI呼び出し**）。前二者は環境を
汚さないため、先に潰しておくと失敗時の切り分けが楽になる。

### グループA: 純粋関数（4件）

| # | 経由する関数 | 判定 |
|---|---|---|
| 2 | `normalize_issue_search_results` 相当（`search_issues` 内部） | `iid`→`number`・`web_url`→`url`・`opened`→`open` の変換が実データで起きる |
| 9 | `get_diff_anchor_algo` | `sha1` を返す |
| 11 | `build_discussion_body` 相当（`add_mr_inline_comments` 内部） | 実MRの `diff_refs` に対し、新規行／削除行／コンテキスト行の3パターンで妥当な `position` を組む |
| 12 | `summary_post_kind` 相当 | 0件→`note`、1件以上→`thread` |

11・12はディスパッチャ経由の公開関数を持たないため、**`add_mr_inline_comments` の実行を通して
間接的に確認する**（内部で使われた結果がGitLab上のコメントの形として現れる）。この点を
reports に明記する。

### グループB: URL組み立て（4件）

| # | 経由する関数 | 生成される形 |
|---|---|---|
| 5 | `get_mr_url` | `<repo>/-/merge_requests/<iid>` |
| 6 | `get_note_url` | `<mr_url>#note_<id>` |
| 7 | `get_blob_url` | `<repo>/-/blob/<ref>/<path>` |
| 8 | `get_diff_anchor_url` | `<compare_url>#<sha1(path)>` |

**#8 が本issue最大の焦点。** 実装は `diff-` 接頭辞なしの `#<パスのsha1>` を前提にしている。
次の3段で「正否が判明した」と言える状態まで持っていく。

1. `hash_paths "$(get_diff_anchor_algo)" <path>` の値と、`sha1sum` で自前計算した値が一致するか。
2. GitLab APIが返すファイル識別子（MRの `diffs` / `diffs_metadata` 等が返す `file_hash` 系の
   フィールド）と 1. の値が一致するか。**一致すれば sha1 前提は正しい**と機械的に言える。
3. 上記で決着しない場合のみ、URLをユーザーへ提示してブラウザで開いてもらう。

日本語ファイル名・スペースを含むパスも対象に含める（`url_encode_path_to_reply` を通す経路と、
ハッシュ計算がエンコード前後どちらの文字列を使うかで結果が変わるため）。

### グループC: CLI呼び出し（5件）

| # | 経由する関数 | 実行内容 |
|---|---|---|
| 1 | `search_issues` | 検証用issueを数件作り、キーワードで検索して open/closed 双方が返るか。**`glab` の `--all` フラグがこのバージョンで通るか**を特に見る（spec の未決定事項が名指ししている） |
| 3 | `set_mr_ready` | Draft MRに対して実行し、タイトルの `Draft:` 接頭辞が外れるか。**接頭辞が無いMRに対して冪等か**も確認する |
| 4 | `add_issue_comment` | issueへコメントが1件付くか（MRではなくissue側のエンドポイント） |
| 10 | `add_mr_thread` | MRに**解決可能なスレッド**として付くか（単発noteではないこと） |
| 13 | `add_mr_inline_comments` | findings JSONを与え、`{posted, summarized}` が返り、インライン位置に付くか。**わざと不正な行番号のfindingを混ぜ**、その1件だけがサマリへ回り他が巻き添えにならないことを確認する |

既存の `root/issue45-verify` に `Draft: Draft: 検証MR` という**二重接頭辞のMR**が残っている。
#3 の検証では、この形（`(?i)^(\s*(?:draft:|wip:)\s*)*` が繰り返しにマッチするか）も試す。

### グループD: サブグループ解決

`grp127/sub127/issue127-verify-sub` を作り、そのクローンをcwdにして
`get_repo_slug` / `get_issue` / `get_mr_for_branch` が通るかを見る。`get_repo_slug` は
`owner`/`repo` の2階層しか持たないため、**3階層以上のnamespaceで `owner` に何が入るか**を
確認する（ここが崩れると、CLI不在時のMCPフォールバック手順にも影響する）。

## 記録先

- 正文: `reports/20260820_zippy-petting-crown_GitLab実機検証結果.md`
  - 関数ごとに「呼び出したコマンド／実際の出力（PATはマスク）／期待どおりか／差異」を表で残す。
- 視覚化: 同名 `.html`（TailwindCSS CDN、表形式。関連図が主題ではないのでcanvas形式は使わない）
- 試行錯誤: `worklog/20260820_zippy-petting-crown_【調査】GitLab13関数とURL形式の実機検証_push2.md`

## やらないこと

- gitlab.com（SaaS）・CE 18.5.4 以外のバージョン・EE での確認（issue の期待する動作7で範囲外）。
- ssh鍵の登録、コンテナの作り直し。
- **見つかった不具合の修正**（フェーズ3で行う）。本フェーズでは事実の記録に留める。
- `root/issue45-verify` の削除・改変（`Draft: Draft:` のMRを #3 の入力として読む以外）。
- issue #48 で検証済みの12関数の再検証。

## 完了条件

1. 13関数すべてについて `Provider.sh` 経由の実行結果が `reports/` に記録されている。
2. 差分アンカーの `sha1` 前提の**正否が判明している**（「たぶん正しい」で終えない）。
3. サブグループ配下での解決結果が記録されている。
4. 見つかった不具合が、フェーズ3で修正できる粒度（再現手順つき）で列挙されている。
