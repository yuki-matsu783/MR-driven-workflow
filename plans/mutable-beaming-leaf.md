# issue #45 全体作業計画: get_providerがself-hosted GitLabを判定できない

/ issue: [#45](https://github.com/yuki-matsu783/MR-driven-workflow/issues/45)
/ ブランチ: `feature-45-detect-gitlab-provider-for-self-hosted`
/ PR: [#52](https://github.com/yuki-matsu783/MR-driven-workflow/pull/52) (Draft)

## Context

`get_provider()`（[Provider.sh:104-115](../.claude/scripts/src/vcs/Provider.sh)）は
`git remote get-url origin` の**URL文字列全体**への部分一致（`*github.com*` / `*gitlab*`）だけで
プロバイダを判定している。このためホスト名に `gitlab` を含まないGitLabインスタンス
（`git@git.example.co.jp:...`、`http://localhost:8929/...`）を「サポート対象外のリモートです」として
弾き、self-hosted GitLabでワークフローを使えない。

issue #48 で、ローカルGitLab CE 18.5.4に対し `Gitlab.sh` の全13関数が動作することを実機確認済み。
**`get_provider` の判定だけが唯一の障害**であることが分かっている（そのため #48 の検証は
`gitlab_*` を直接呼んで迂回した）。

### issue本文の訂正（対応済み）

issue #45 本文の「`glab api` はremoteを参照せず既定ホストへ接続する。`GITLAB_HOST` の明示が必要」は
**誤り**（未認証ホストでの観測を一般化したもの）。認証済みホストなら `glab api` もremoteから解決する。
[issue #45 へコメント済み](https://github.com/yuki-matsu783/MR-driven-workflow/issues/45#issuecomment-5337766876)。
**`GITLAB_HOST` 対応は不要**。

## 調査結果（この計画の根拠。フェーズ2は省略する）

判定方式の候補を実測で比較した。

| 候補 | 実測 | 判断 |
|---|---|---|
| `glab auth status` で既知ホストを照会 | **14.5秒**（ホストごとにネットワーク接続する） | 却下。判定に使える速度ではない |
| `glab config get token --host <host>` | 0.55〜0.9秒・オフラインで既知/未知を判別可 | 却下。ホスト判定のみで足りるため不要 |
| glabの `config.yml` を直接パース | 読み取り0.1秒。ただし配置は `%LOCALAPPDATA%/glab-cli/`（OS依存。`~/.config/glab-cli/` ではない） | 却下。OS依存パス＋自前YAMLパースが脆い |
| **remote URLのホスト部で判定** | 追加forkなし | **採用** |

`get_provider` は12個のディスパッチャから毎回呼ばれる。`case "$(get_provider)" in` という
**コマンド置換**のためサブシェルで実行され、グローバル変数によるメモ化が効かない。
判定に外部コマンドを足すと12箇所すべてで増えるため、追加forkゼロの方式を選ぶ。

## 方針: ホスト部を抽出し、`github` を含まなければGitLabとみなす

本ワークフローが対応するのはGitHubとGitLabの2つだけである。GitHubは判別しやすい
（SaaSは `github.com`、GHEも慣習的にホスト名へ `github` を含む）ため、
**GitHubでないものはGitLab**とみなすのが最も単純で、受け入れ条件をすべて満たす。

**URL全体ではなくホスト部で判定する点が本質的な修正**である。現行実装は
`https://gitlab.com/github-mirror/x.git` のように**パスに `github` を含むGitLab URL**を
GitHubと誤判定する（先に `*github.com*` へマッチするため）。

### 社内GitLab（Aslead）を明示ケースとして先に判定する

ユーザー指示により、**ホスト名に `aslead` を含む場合はGitLabと判定する**ケースを明示的に加える。

既定規則（`github` を含まなければGitLab）でも同じ結果になるため機能上は冗長だが、
**GitHub判定より前に置く**ことで、ホスト名に `github` と `aslead` が同時に含まれる場合でも
GitLabが優先される。実際に使う社内インスタンスを名前で明示しておくことで、将来この規則を
変更する際にも意図が失われない。判定順は次のとおり。

```
*aslead*  → gitlab   （社内GitLabの明示ケース。GitHub判定より先）
*github*  → github
それ以外  → gitlab
```

`.mrworkflow.json` への `provider` キー追加（issue本文の案）は採用しない。
`get_workflow_config` が `git rev-parse` と `jq` を呼ぶため、全ディスパッチで約190msずつ増える。
ホスト判定だけで全ケースを賄えるため、コストに見合わないと判断した（ユーザー合意済み）。

### 未認証（`gh`/`glab` 未ログイン）時の挙動

**この方式は認証状態に一切依存しない。** `get_provider` は `git remote get-url origin` を読むだけで、
`gh`/`glab` を呼ばないため、未ログインでも判定結果は変わらない。

これは却下した3方式との決定的な差である。`glab auth status` / `glab config get token --host` /
`config.yml` パースはいずれも**「glabに登録済みのホストか」を見る**ため、未ログイン状態では
self-hosted GitLabを判定できない。「動かすには先にログインが要る」ことと
「判定そのものがログインに依存する」ことは別問題で、後者は避けるべきである。

未認証時に失敗するのは後続の `gh`/`glab` 呼び出しであり、実測したメッセージは次のとおり。

| 状況 | メッセージ |
|---|---|
| `glab`: ホスト未登録 | `None of the git remotes configured for this repository point to a known GitLab host` |
| `glab`: ホスト登録済み・トークン無効 | `401 Unauthorized (HTTP 401)`（終了コード非0） |
| `gh`: 未ログイン | `gh auth login` を案内するエラー |

いずれもCLI由来のメッセージがそのまま出て次に取るべき操作が分かるため、`Provider.sh` 側に
事前チェックは**追加しない**（判定コストをゼロに保つという上記の方針とも整合する）。
`gh`/`glab` が認証済みであることは `.claude/skills/issue-mr-flow/SKILL.md`「前提」に記載済み。

### 受け入れるトレードオフ: 非対応リモートのエラーが分かりにくくなる

「`github` を含まなければGitLab」とみなす結果、**GitHub/GitLabのどちらでもないリモート**
（Bitbucket等、あるいはURLのtypo）に対して、現行の
`サポート対象外のリモートです（GitHub/GitLabのみ対応）` という明快なメッセージが出なくなり、
`glab` 側の `None of the git remotes ... known GitLab host` に変わる。

対応プロバイダが2つしかない以上、self-hostedを弾かずに非対応を弾く判定は原理的に書けない
（ホスト名だけでは区別できない）。self-hostedが使えないことの方が実害が大きいため受け入れる。
この点はDDRの「却下した案」ではなく**「受け入れたトレードオフ」として明記**する。

## フェーズ3: 実装・テスト

個別作業計画は `plans/【実装】【テスト】get_providerのホスト判定化.md` として1ファイルにまとめる。

### 純粋関数 `provider_from_remote_url` を新設する

`Provider.sh` に、URL文字列を受け取りプロバイダ名を返す**純粋関数**（外部コマンド呼び出しなし）を
追加し、`get_provider` を「`git remote get-url origin` の結果をこの関数へ渡すだけ」の薄いラッパーに
する。目的は `tests/test_vcs_provider.sh` から単体テストできるようにすること
（`.claude/rules/shell-script-style.md`「テスト」。issue #48 の
`gitlab_format_discussion_notes` と同じ切り出し方）。

ホスト抽出はパラメータ展開のみで行い、forkを増やさない（同「外部プロセス起動のコスト」）。
**除去の順序が重要**で、パスを先に落としてから認証情報を落とす。逆順にすると、パスに `@` を含む
URL（`https://gitlab.com/foo/b@r.git`）でホスト抽出が壊れる。

```
url  --("://" 以降を取る)-->  --("/" 以降を落とす)-->  --("@" まで落とす)-->  --(":" 以降を落とす)-->  小文字化
```

`git@github.com:foo/bar.git`（scp形式）も同じ手順で `github.com` になる。
抽出結果が空の場合のみ、従来同様エラー（終了コード1）にする。

### テスト

`tests/test_vcs_provider.sh` に追記する（既存の `assert_eq` / `passed=N failures=N` 規約に従う）。
このファイルは現在 `Github.sh` / `Gitlab.sh` のみをsourceしているので、`Provider.sh` を追加でsourceする
（source時にgit操作等の副作用は無く、`Github.sh`/`Gitlab.sh` を再sourceするだけなので安全）。

issue本文の実測表の全6ケースに加え、退行を防ぐケースを足す。

| 入力 | 期待 | 意図 |
|---|---|---|
| `https://github.com/foo/bar.git` | `github` | 退行防止 |
| `git@github.com:foo/bar.git` | `github` | scp形式 |
| `https://github.example.com/foo/bar.git` | `github` | GHEを誤ってGitLab扱いしない |
| `https://gitlab.com/foo/bar.git` | `gitlab` | 退行防止 |
| `https://gitlab.example.co.jp/foo/bar.git` | `gitlab` | 退行防止 |
| `git@git.example.co.jp:foo/bar.git` | `gitlab` | **受け入れ条件** |
| `http://localhost:8929/root/demo.git` | `gitlab` | **受け入れ条件** |
| `http://127.0.0.1:8929/root/demo.git` | `gitlab` | **受け入れ条件** |
| `ssh://git@gitlab.example.com:2222/foo/bar.git` | `gitlab` | ポート付きssh形式 |
| `https://gitlab.com/github-mirror/x.git` | `gitlab` | **現行実装のバグ**（パスの`github`で誤判定） |
| `https://user@gitlab.com:8080/foo/b@r.git` | `gitlab` | パスに`@`を含む（抽出順序の検証） |
| `https://aslead.example.co.jp/foo/bar.git` | `gitlab` | 社内GitLab（Aslead）の明示ケース |
| `git@aslead-git.corp.local:foo/bar.git` | `gitlab` | 同上（scp形式） |
| `https://github.aslead.example.com/foo/bar.git` | `gitlab` | `aslead` が `github` より優先されること |

## フェーズ4: 反映

`【設計反映】` と `【AIアセット反映】` は分けて実施する
（`.claude/skills/issue-mr-flow/SKILL.md`。flow-id 4-6〜4-9 を2セット）。

### 設計反映

- `.claude/docs/spec/issue-mr-workflow.md` L69 の `Provider.sh` の説明
  （「`git remote get-url origin` のホスト名（`github.com` / `gitlab.*`）でプロバイダを判定し」）を
  新方式へ更新する。**現在の状態を説明する節**のため書き換えてよい。
- 同「未決定事項・懸念点」の「GitLab側の動作未検証」にある**「`Provider.sh`経由のディスパッチ」の
  項目を解消**する（下記の実機検証で確認できるため）。他2点（バージョン・プロジェクト構成）は残す。
- 「提供関数」表の直後にある内部ヘルパーの段落へ `provider_from_remote_url` を追記する。
- 「影響範囲」へ**新規エントリを追記**する。過去のissueごとのchangelogは書き換えない
  （`.claude/rules/docs-workflow.md`）。
- DDR 0027 を新規作成する（**判断が必要**）。タイトル案:
  `0027-プロバイダ判定はremote URLのホスト部でgithub以外をgitlabとみなす.md`。
  却下案として上表の3方式（実測値つき）と `.mrworkflow.json` への `provider` 追加を記録する。
  独立させる価値はあると考えるが、レビューで却下されればspecの記述のみに留める。

### AIアセット反映

- 実装後に判明した知見があれば `.claude/rules/` へ反映する。現時点で予定している具体項目は無く、
  **不要なら「反映なし」で終える**（無理に書かない）。

## 変更対象ファイル

| ファイル | 内容 |
|---|---|
| `.claude/scripts/src/vcs/Provider.sh` | `provider_from_remote_url` 新設、`get_provider` を薄いラッパー化 |
| `tests/test_vcs_provider.sh` | 上表11ケースを追加、`Provider.sh` のsourceを追加 |
| `.claude/docs/spec/issue-mr-workflow.md` | 現状節の更新＋未決定事項の一部解消＋changelog新規エントリ（フェーズ4） |
| `.claude/docs/ddr/0027-...md` | 新規（フェーズ4・要判断） |
| `HANDOFF.md` | flow-idが進むごとに更新 |

## 検証方法

1. `bash -n .claude/scripts/src/vcs/Provider.sh` で構文チェック。
2. `bash tests/test_vcs_provider.sh` → `passed=N failures=0`（現在11 → 25前後）。
3. **このリポジトリ（GitHub）で退行が無いこと**: `get_provider` が `github` を返し、
   `get_mr_for_branch` 等のディスパッチが従来どおり動く。
4. **self-hosted GitLabでのend-to-end確認**（本issueの本丸）。
   `docker start gitlab` で検証環境を再開し、検証用リポジトリ（remoteが `http://localhost:8929/...`）で
   **`Provider.sh` の共通インターフェース関数を経由して**呼ぶ。issue #48 では `get_provider` が
   弾くため `gitlab_*` を直接呼んで迂回していた部分であり、ここが通ることが本issueの完了条件。
   - `get_provider` → `gitlab`
   - `get_issue` / `get_mr_for_branch` / `get_mr_unresolved_comments` / `add_mr_comment` /
     `set_mr_description` / `get_repo_url` がディスパッチ経由で動く
5. 合成フィクスチャのテストだけで完了としない（`.claude/rules/shell-script-style.md`「テスト」）。
   4. の実機確認を必ず行う。

## 守るべき条件・触ってはいけない範囲

- **`.claude/docs/spec/issue-mr-workflow.md` の「影響範囲」節にある過去issueのchangelogエントリを
  書き換えない。** issue #48分のエントリも含め、追記のみとする。
- **DDR 0005・0026 は変更しない。** 空コミットフォールバックの判断は本issueと独立しており、
  現在も有効。
- `Gitlab.sh` / `Github.sh` は原則変更しない。本issueは `Provider.sh` の判定ロジックが対象で、
  issue #48 で検証済みのプロバイダ固有実装には手を入れない。

## 未確定事項

- DDR 0027 を作成するかはフェーズ4のレビューで判断する。
- AIアセット反映は「反映なし」で終わる可能性がある。
