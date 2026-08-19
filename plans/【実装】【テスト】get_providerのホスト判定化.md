# 【実装】【テスト】get_providerのホスト判定化

対象issue: [#45](https://github.com/yuki-matsu783/MR-driven-workflow/issues/45)
全体作業計画: `plans/mutable-beaming-leaf.md`

実装とテストは同時に書き、まとめて1回で合意を取るため1ファイルにまとめる
（`.claude/skills/issue-mr-flow/SKILL.md`「種別を複数併記する場合」）。

## 変更対象

| ファイル | 内容 |
|---|---|
| `.claude/scripts/src/vcs/Provider.sh` | 純粋関数 `provider_from_remote_url` を新設し、`get_provider` を薄いラッパーにする |
| `tests/test_vcs_provider.sh` | `Provider.sh` をsourceし、11ケースを追加する |

## 1. `provider_from_remote_url` を新設する

現行実装（`Provider.sh` の `get_provider`）は次のとおり。**URL文字列全体**への部分一致で判定している。

```bash
get_provider() {
  local url
  url="$(git remote get-url origin)"
  case "$url" in
    *github.com*) printf 'github\n' ;;
    *gitlab*) printf 'gitlab\n' ;;
    *)
      echo "サポート対象外のリモートです（GitHub/GitLabのみ対応）: $url" >&2
      return 1
      ;;
  esac
}
```

これを次の2関数へ分ける。

```bash
# remote URLからホスト部分を取り出し、プロバイダ名（github / gitlab）を返す純粋関数。
# 外部コマンド呼び出しを伴わないため tests/test_vcs_provider.sh から単体テストできる
# （.claude/rules/shell-script-style.md「テスト」）。
#
# 判定規則: ホスト名に `github` を含めばGitHub、それ以外はGitLabとみなす。本ワークフローが
# 対応するのはGitHub/GitLabの2つだけで、GitHubはSaaS（github.com）・GHEとも慣習的にホスト名へ
# `github` を含むため、「GitHubでなければGitLab」で全ケースを賄える。ホスト名に `gitlab` を
# 含まないself-hosted GitLab（git.example.co.jp / localhost:8929 等）を弾かないことが目的
# （issue #45）。
#
# URL全体ではなくホスト部で判定するのが要点。旧実装は `*github.com*` を先に見ていたため、
# https://gitlab.com/github-mirror/x.git のようにパスへ `github` を含むGitLab URLをGitHubと
# 誤判定していた。
#
# 判定はremote URLの文字列のみに依存し、`gh`/`glab` の認証状態には依存しない（未ログインでも
# 同じ結果になる）。詳細・却下案は
# .claude/docs/ddr/0027-プロバイダ判定はremote-URLのホスト部でgithub以外をgitlabとみなす.md 参照。
provider_from_remote_url() {
  local url="$1" host
  # scheme:// があれば除去（無ければそのまま）
  host="${url#*://}"
  # 最初の `/` 以降（パス）を除去。scp形式 git@host:path でも `/` 以降が落ちる
  host="${host%%/*}"
  # 認証情報 user@ を除去。パスを先に落としてからでないと、パスに `@` を含むURLで壊れる
  host="${host#*@}"
  # ポート（:8929）または scp形式のパス区切り（:foo）を除去
  host="${host%%:*}"
  host="${host,,}"

  if [ -z "$host" ]; then
    echo "remote URLからホスト名を取得できませんでした: $url" >&2
    return 1
  fi

  case "$host" in
    # 社内GitLab（Aslead）を明示的に先に判定する。既定規則（github以外はgitlab）でも同じ結果に
    # なるが、ホスト名に `github` と `aslead` が同時に含まれる場合でもGitLabを優先させるため、
    # GitHub判定より前に置く。
    *aslead*) printf 'gitlab\n' ;;
    *github*) printf 'github\n' ;;
    *) printf 'gitlab\n' ;;
  esac
}

# `git remote get-url origin` のホスト名からプロバイダを判定する
get_provider() {
  local url
  url="$(git remote get-url origin)"
  provider_from_remote_url "$url"
}
```

### 除去の順序（重要）

```
https://user@gitlab.com:8080/foo/b@r.git
  ── "://" 以降 ──▶  user@gitlab.com:8080/foo/b@r.git
  ── "/" 以降を落とす ──▶  user@gitlab.com:8080
  ── "@" まで落とす ──▶  gitlab.com:8080
  ── ":" 以降を落とす ──▶  gitlab.com
```

**パスを先に落としてから認証情報を落とす。** 逆順にすると `#*@` が最短一致でパス中の `@` に
かかり、`b@r.git` の `r.git` をホストとみなしてしまう。

scp形式も同じ手順で通る。

```
git@github.com:foo/bar.git
  ── "://" 無し ──▶  git@github.com:foo/bar.git
  ── "/" 以降を落とす ──▶  git@github.com:foo
  ── "@" まで落とす ──▶  github.com:foo
  ── ":" 以降を落とす ──▶  github.com
```

### 実装上の注意

- **パラメータ展開のみで実装し、`sed`/`awk`/コマンド置換を使わない**
  （`.claude/rules/shell-script-style.md`「外部プロセス起動のコスト」）。`get_provider` は12個の
  ディスパッチャから毎回呼ばれるため、ここでforkを増やすと全体に効く。
- `${host,,}`（小文字化）はbash 4以降の機能。実行環境のgit bashはbash 5系のため問題ない。
- エラーメッセージは「サポート対象外のリモートです」から変わる。到達するのはホスト名が空の
  ときだけになるため、文言もそれに合わせる。

## 2. テストを追加する

`tests/test_vcs_provider.sh` は現在 `Github.sh` / `Gitlab.sh` のみをsourceしている。
`Provider.sh` を追加でsourceする（source時の副作用は `set -euo pipefail` と
`Github.sh`/`Gitlab.sh` の再source、定数配列の定義のみで、git操作は行わないため安全）。

```bash
# shellcheck source=../.claude/scripts/src/vcs/Provider.sh
source "$repo_root/.claude/scripts/src/vcs/Provider.sh"
```

追加するケース（全体作業計画の表と同じ）。

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
| `https://github.aslead.example.com/foo/bar.git` | `gitlab` | **`aslead` が `github` より優先される**ことの確認 |

`https://gitlab.com/github-mirror/x.git` は**現行実装では `github` を返す**ため、
このテストは修正前に落ち、修正後に通る（回帰テストとして機能する）。

## 検証手順

1. `bash -n .claude/scripts/src/vcs/Provider.sh`
2. `bash tests/test_vcs_provider.sh` → `passed=25 failures=0`（既存11＋今回14）
3. **このリポジトリ（GitHub）で退行が無いこと**
   ```bash
   source .claude/scripts/src/vcs/Provider.sh
   get_provider                                   # → github
   get_mr_for_branch "$(git branch --show-current)" | jq -r '.number'
   ```
4. **self-hosted GitLabでのend-to-end確認（本issueの本丸）**
   ```bash
   docker start gitlab                            # healthyになるまで待つ
   export MSYS_NO_PATHCONV=1
   cd <scratchpad>/issue45-verify                 # remoteは http://localhost:8929/root/issue45-verify.git
   source <repo>/.claude/scripts/src/vcs/Provider.sh
   get_provider                                   # → gitlab（従来はここでエラー）
   get_issue 1 | jq -r '.title'
   get_mr_for_branch feature-1-verify | jq -r '.number'
   get_mr_unresolved_comments 1
   get_repo_url
   ```
   issue #48 では `get_provider` に弾かれるため `gitlab_*` を直接呼んで迂回していた部分であり、
   **ディスパッチ経由で通ることが本issueの完了条件**。
5. 合成フィクスチャだけで完了としない（`.claude/rules/shell-script-style.md`「テスト」）。
   4. を必ず実施する。

## やらないこと

- `.mrworkflow.json` への `provider` キー追加（全体作業計画のとおり見送り）。
- `GITLAB_HOST` 対応（issue本文の誤記に基づく要求であり不要）。
- `get_provider` のメモ化（`case "$(get_provider)" in` というコマンド置換のためサブシェルとなり、
  グローバル変数では効かない。12個のディスパッチャを `REPLY` 方式へ書き換える必要があり、
  本issueの範囲を超える。必要なら別issueとする）。
- `gh`/`glab` の認証状態の事前チェック（CLI由来のメッセージで十分。判定コストをゼロに保つ方針）。
