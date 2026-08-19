---
title: worklog 20260819 ホスト抽出の共通化
type: log
description: issue #55（remote URLのホスト抽出の二重実装）の実装・テストの試行錯誤ログ
tags: [worklog, vcs-provider, shell-script]
keywords: [split_remote_url, parse_repo_slug, provider_from_remote_url, パラメータ展開, REPLY, scp形式, フォーク]
---

# worklog: 【実装】【テスト】ホスト抽出の共通化

対象: issue #55 のフェーズ3（実装・テスト）（2026-08-19）。
全体作業計画: `plans/mutable-beaming-leaf.md`
個別作業計画: `plans/【実装】【テスト】ホスト抽出の共通化.md`
push回数: 1

## 試したこと

### 2実装の突き合わせ（全体作業計画の根拠）

`parse_repo_slug`（issue #34）と `provider_from_remote_url`（issue #45）のホスト抽出結果を、
10種類のURL形式で突き合わせた。

**差分は大文字小文字の扱いだけだった。**

| URL | `parse_repo_slug.host` | パラメータ展開版 |
|---|---|---|
| `https://GitHub.COM/O/R.git` | `GitHub.COM` | `github.com` |
| 上記以外の9件（https / scp形式 / `ssh://` / ポート付き / パスに`@` / ネストnamespace / localhost / IPアドレス / `github-mirror`） | すべて一致 | すべて一致 |

`parse_repo_slug` の `sed` は `s#^[^/@]+@##` という文字クラスを使っており、パスに `@` を含むURLでも
誤爆しない。**現状の挙動そのものに不具合は無い**ことを先に確認できたのは大きい。二重実装は
「いつか壊れる」種類の問題であって、今壊れている問題ではないと整理できた。

### コスト計測

git bash（MSYS）の外部プロセス起動は約95ms/回（`.claude/rules/shell-script-style.md`）。

| 実装 | 20回の所要時間 | 1回あたり |
|---|---|---|
| `parse_repo_slug`（`sed`×2 + `jq`×1） | 5706ms | **285ms** |
| パラメータ展開のみ | 35ms | 実質ゼロ |

285ms ≒ 95ms × 3 で、**プロセス起動回数がそのまま所要時間になっている**ことが確認できた。
`get_repo_slug` は `.claude/hooks/session-start.sh:91` から**セッション開始のたび**に呼ばれるため、
`sed` 2回を落とせば体感に効く。

### 設計上の最大の争点: scp形式とポート付きURLの区別

パラメータ展開だけでホスト部とパス部の両方を取り出すとき、唯一分岐が必要なのがここだった。

```
git@github.com:o/r.git              → `:` の後ろは「パス」
ssh://git@host.example.com:2222/o/r → `:` の後ろは「ポート」
```

`:` の後ろが**数字だけかどうか**で区別する。`case "$tail" in ''|*[!0-9]*)` という
グロブパターンで書けるため、`[[ =~ ]]` も外部コマンドも要らない。

`provider_from_remote_url` 側はホストしか要らないので、この分岐なしで
`${rest%%/*}` → `${host#*@}` → `${host%%:*}` の順に落とすだけで済んでいた。パス部まで返す
共通関数にするには、この分岐を持ち込む必要がある。**共通化のコストはここだけ**だと分かった。

### 除去の順序（既存の知見をそのまま引き継ぐ）

issue #45で確立した「パスを先に落としてから認証情報を落とす」という順序は、共通関数でも同じく
必要になる。ただし今回はパス部も返すため、`rest` を破壊せずに「最初の `/` より前の区間」
（`first`）だけを見て `@` の有無を判定する形にした。

```bash
first="${rest%%/*}"
if [ "$first" != "${first#*@}" ]; then rest="${rest#*@}"; first="${rest%%/*}"; fi
```

`https://gitlab.com/foo/b@r.git` では `first` が `gitlab.com` となり `@` を含まないので、
パス中の `@` に反応しない。

### 実装

<!-- flow-id 3-6（作業実施）で追記する -->

## うまくいったこと

- 「片方だけ直すとずれる」という抽象的な懸念を、**10形式の実測表**と**285ms対ゼロ**という
  具体的な数字に落とせた。計画のレビューで判断材料になる。
- 統合しても**既存テスト36件を1件も変えずに済む**設計にできた。全件通ることがそのまま
  「振る舞いを変えていない」ことの根拠になる。

## ダメだったこと

- （実装着手前のため、現時点では特になし。）

## 次の一歩

- flow-id 3-2: `commit`スキル経由でコミットし、リモートへ反映して作業計画のレビューを依頼する。
- flow-id 3-6: `split_remote_url` の新設と2関数の載せ替え、テスト8件の追加。
- flow-id 3-6の検証では、**変更前の `parse_repo_slug` の出力を先にscratchpadへ保存**してから
  着手する（合成テストだけで終わらせないため。`.claude/rules/shell-script-style.md`「テスト」）。

---
