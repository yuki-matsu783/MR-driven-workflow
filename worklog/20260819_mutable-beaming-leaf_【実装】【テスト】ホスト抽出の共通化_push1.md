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

計画どおり `split_remote_url` を新設し、`provider_from_remote_url` と `parse_repo_slug` を
その上へ載せ替えた。テストは8件追加し、既存36件は1件も変更していない。

**計画からの逸脱が1点だけある。** 計画では `split_remote_url` を「`parse_repo_slug` の直前」に
置くとしていたが、実際には `provider_from_remote_url` のコメントブロックの**手前**（`build_issue_body`
の直後）へ置いた。`provider_from_remote_url` が先に定義されており、そちらから
`split_remote_url "$1"` を呼ぶため、計画どおりの位置だと**上から読んだときに未定義の関数が
先に現れる**（bashは呼び出し時解決なので動作には影響しないが、読み手が定義を探すことになる）。
共有ヘルパーを最初の利用者より前に置くほうが素直と判断した。振る舞いへの影響はない。

### 検証結果

**1. テスト**: `passed=44 failures=0`（既存36 + 新規8）。既存21件（`parse_repo_slug` 6件・
`provider_from_remote_url` 15件）が無変更で通ったことが、共通化しても振る舞いが変わっていない
ことの主たる根拠。

**2. 統合前後の出力一致**（合成テストで終わらせないための実データ確認）。10種類のURLについて
変更前の `parse_repo_slug` 出力をscratchpadへ保存しておき、変更後と `diff` した。

```
10c10
< https://GitHub.COM/O/R.git  {"host":"GitHub.COM","owner":"O","repo":"R","path":"O/R","url":"https://GitHub.COM/O/R"}
---
> https://GitHub.COM/O/R.git  {"host":"github.com","owner":"O","repo":"R","path":"O/R","url":"https://github.com/O/R"}
```

**差分は予定していた1件のみ**。`.owner` / `.repo` / `.path` は `O/R` のままで、リポジトリ名の
大文字が保たれることも同時に確認できた。

**3. このリポジトリでの退行なし**

| 関数 | 結果 |
|---|---|
| `get_provider` | `github` |
| `get_repo_slug` | `{"host":"github.com","owner":"yuki-matsu783","repo":"MR-driven-workflow",...}` |
| `get_repo_url` | `https://github.com/yuki-matsu783/MR-driven-workflow` |
| `get_vcs_access_mode` | `cli` |
| `get_mr_for_branch` | `56` |
| `mcp_tool_hint get_issue` | `mcp__github__issue_read (method="get", owner, repo, issue_number)` |

**4. コスト削減**（旧実装を同一セッション内に `old_parse_repo_slug` として再現し、同じ条件で比較。
別々のタイミングで測るとマシン負荷の揺らぎがそのまま差として出てしまうため）

| 実装 | 20回 | 1回あたり |
|---|---|---|
| 旧（`sed`×2 + `jq`×1） | 8315ms | 415ms |
| 新（`jq`×1） | 2104ms | **105ms** |

**74%削減**。fork数 3→1 という設計上の期待と一致する。

**5. `provider_from_remote_url` のfork数がゼロのままであること**

最初、20回ループでの計測が `split_remote_url` 単体で177msと出て「forkしているのでは」と疑ったが、
これは `$(seq 20)` と `date` 自体のfork、および20回という試行回数の少なさによるノイズだった。
空関数を基準にした200回計測で切り分けた。

| 計測対象（200回） | 所要 | 空関数との差 |
|---|---|---|
| 空関数 `noop` | 80ms | — |
| `split_remote_url` | 93ms | +13ms（0.065ms/回） |
| `provider_from_remote_url` | 132ms | +52ms（0.26ms/回） |

同条件で `jq -nc '1'` は1回あたり138msかかっている。**両関数はその1/500以下であり、外部プロセスを
起動していないことが数字で確認できた**（DDR 0028の制約を維持）。

**計測は必ずベースライン（空関数）との差で見る**という教訓が得られた。git bashでは `date` を2回
呼ぶだけで既に数msかかるため、試行回数が少ないと「ゼロのはずのものが数十ms」に見えてしまう。

## うまくいったこと

- 「片方だけ直すとずれる」という抽象的な懸念を、**10形式の実測表**と**415ms対ゼロ**という
  具体的な数字に落とせた。計画のレビューで判断材料になった。
- 統合しても**既存テスト36件を1件も変えずに済む**設計にできた。全件通ることがそのまま
  「振る舞いを変えていない」ことの根拠になっている。
- 変更前の出力を先に保存しておいたおかげで、**「意図した1件以外は完全一致」を機械的に示せた**。
  合成テストだけだと「そもそも観点が漏れていないか」を自分では保証できないが、実データの
  before/after diffは漏れの有無ごと確認できる。
- scp形式とポート付きURLの区別を `case "$tail" in ''|*[!0-9]*)` というグロブで書けたため、
  `[[ =~ ]]` も外部コマンドも使わずにfork数ゼロを維持できた。

## ダメだったこと

- **計測をベースラインとの差で取らず、一度誤った結論に飛びかけた。** 20回ループでの計測で
  `split_remote_url` 単体が177msと出たため「どこかでforkしている」と疑った。実際は
  `$(seq 20)` と `date` 自体のfork・試行回数の少なさによるノイズで、空関数を基準にした
  200回計測では0.065ms/回だった。**「ゼロであること」を測るときは、必ず空関数との差で見る。**
- 全体作業計画の段階でパラメータ展開版を「35ms/20回」と記録していたが、これも同じ理由で
  ベースラインを含んだ値だった。数字自体の結論（forkゼロ）は変わらないが、比較の仕方が甘かった。

## 次の一歩

- flow-id 3-7: `commit`スキル経由でコミットし、リモートへ反映して実装のレビューを依頼する。
- flow-id 4-1: `【設計反映】`（specの内部ヘルパー段落・決定済み事項・影響範囲）と
  `【AIアセット反映】` の個別反映計画を**分けて**作成する。
- AIアセット反映の候補として、「**forkゼロを検証する計測は空関数をベースラインに取る**」という
  知見が `.claude/rules/shell-script-style.md`「外部プロセス起動のコスト」節に無い。
  同節は「起動を減らせ」とは書いているが、減らせたことの**確かめ方**は書いていない。

---
