---
title: 【実装】【テスト】get_repo_urlのgit remote由来導出への置き換え
type: log
description: issue #44の個別作業計画。repo_url_from_remote_urlの実装方針・正規化規則・削除対象・テストケース一覧
tags: [plan, vcs-provider, test]
keywords: [repo_url_from_remote_url, split_remote_url, build_repo_url_from_reply, scp形式, ポート, scheme, 単体テスト]
---

# 【実装】【テスト】get_repo_urlのgit remote由来導出への置き換え

全体作業計画: `plans/issue44-repo-url-from-git-remote.md`

【実装】と【テスト】を併記しているのは、テストが実装と同じ純粋関数を対象とし、合意を1回で
取れる粒度のため（`.claude/rules/docs-workflow.md`「種別を複数併記する場合／分ける場合」）。

## 実装方針

### 1. `split_remote_url` に scheme / port の抽出を追加する

既存の `REPLY_HOST` / `REPLY_PATH` はそのままに、`REPLY_SCHEME` / `REPLY_PORT` を追加する
（**追加のみ**なので既存の呼び出し元 `provider_from_remote_url` / `parse_repo_slug` の振る舞いは
変わらない）。パラメータ展開だけで実装し、外部コマンド・コマンド置換を使わない
（DDR 0028 の「プロセス起動ゼロ」を維持する）。

### 2. `build_repo_url_from_reply`（内部ヘルパー）を追加する

`split_remote_url` が設定した `REPLY_*` からWeb URLを組み立て `REPLY` へ返す。規則:

| 入力 | 出力 | 理由 |
|---|---|---|
| `https://host/o/r.git` | `https://host/o/r` | `.git`・末尾スラッシュ・認証情報の除去は `split_remote_url` 済み |
| `git@host:o/r.git`（scp形式） | `https://host/o/r` | SSHのWeb URLはhttps |
| `ssh://git@host:2222/o/r.git` | `https://host/o/r` | **2222はSSHの待ち受けポートでWeb UIのポートではない**ため引き継がない |
| `https://host:8443/o/r.git` | `https://host:8443/o/r` | http/httpsのポートはWeb UIのポートなので引き継ぐ |
| `http://localhost:8929/g/r.git` | `http://localhost:8929/g/r` | plain httpのself-hosted GitLabでhttpsへ寄せるとリンクが壊れる |

### 3. `repo_url_from_remote_url`（公開する純粋関数）を追加する

`split_remote_url` → 検証 → `build_repo_url_from_reply` の3段。ホストまたはパスが取れない場合は
`https:///` のような壊れた値を返さず終了コード1で失敗させる。

### 4. `get_repo_url` をプロバイダ非依存へ置き換える

```bash
get_repo_url() {
  repo_url_from_remote_url "$(git remote get-url origin)"
}
```

issue #34で入れた「MCP経路のときだけ `get_repo_slug` から組み立てる」分岐も削除する
（経路によらず同じ導出になるため）。

### 5. `parse_repo_slug` の `.url` を同じ組み立てへ揃える

`get_repo_url` と `parse_repo_slug` が同じリモートに対し違うURLを返すことがないよう、
`.url` の構成も `build_repo_url_from_reply` 経由にする。plain http・ポート付きURLでは
issue #34時点の値（常に `https://host/path`）から変わるが、消費側
（`.claude/hooks/session-start.sh`）は `.owner`/`.repo` しか使っていないため実害はない。

### 6. 旧関数を削除する

- `.claude/scripts/src/vcs/Github.sh`: `github_get_repo_url`
- `.claude/scripts/src/vcs/Gitlab.sh`: `gitlab_get_repo_url`
- `.claude/scripts/src/vcs/Provider.sh`: `get_repo_url` 内のディスパッチ

## テスト計画（`.claude/scripts/test/test_vcs_provider.sh`）

issue本文の受け入れ条件は `tests/test_vcs_provider.sh` と書かれているが、issue #63（DDR 0031）で
機構自身の単体テストは `.claude/scripts/test/` へ移設済みのため、現行の配置に合わせる。

`repo_url_from_remote_url`（14件）:

- https形式（`.git`付き／`.git`無し／末尾スラッシュ）
- scp形式SSH → https、`ssh://` 形式 → https
- 本リポジトリの実remote URL（`gh repo view` の実測値と一致すること）
- ホストは小文字化・パスの大文字は保つ
- GitLabのネストしたnamespace
- `ssh://` のポートは引き継がない／https のポートは引き継ぐ／http はhttpのまま
- 認証情報 `user@` は落とす
- ホスト空・パス空はいずれも終了コード1（`$(func; echo $?)` ではなく `if` で受ける）

`parse_repo_slug` との整合（2件）: `.url` が `repo_url_from_remote_url` と一致すること
（scp形式・http＋ポート付き）。

`split_remote_url` の scheme/port（5件）: https＋ポート／`ssh://`＋ポート／scp形式は両方空／
ポート無し／schemeの小文字化。

## 確認

- 6本の単体テストスクリプトすべてが `failures=0`
- `source Provider.sh && get_repo_url` が `https://github.com/yuki-matsu783/MR-driven-workflow` を返す
- `post-push-compact-prompt.sh` へ疑似ペイロードを渡し、参照リンクが従来どおり出ること
- 変更ファイルにCR混入が無いこと（`wc -c` と `tr -d '\r' | wc -c` の比較）
