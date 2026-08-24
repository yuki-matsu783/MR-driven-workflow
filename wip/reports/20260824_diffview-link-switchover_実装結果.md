---
title: 実装結果: Diffviewリンクの出し分けとMCP経路でのPR URL解決
type: report
description: issue #205 フェーズ3の実装結果。4引数化・PR URL解決関数・hookの分離配線・テスト17件追加と、7つの完了条件の判定
tags: [report, implementation, issue-mr-flow]
keywords: [get_mr_diff_url, git ls-remote, refs/pull, compare_url, diff_url, 空振り, 経路テスト, 後退なし]
---

# 実装結果: Diffviewリンクの出し分けとMCP経路でのPR URL解決（issue #205 / flow-id 3-6）

- 個別作業計画: `wip/plans/【実装】【テスト】Diffviewリンクの出し分けとMCP経路でのPR URL解決.md`
- 調査結果: `wip/reports/20260824_diffview-link-switchover_調査結果.md`
- PR: #206

## 結論（先に3行）

1. **動いた。** この環境（`gh`/`glab` CLI不在のMCP経路）で、hook出力の「defaultブランチとの差分」が
   `https://github.com/yuki-matsu783/MR-driven-workflow/pull/206/files` になった。
2. **後退していない。** 差分アンカー付きリンク10本すべてがCompareページ上のまま（10/10で一致）。
3. **空振りでないことを確認した。** 第4引数の受け渡しを意図的に落とすと、追加したテストが実際に落ちる。

## 完了条件の判定

| # | 条件 | 判定 |
|---|---|---|
| 1 | 作業1〜4が実装され、検証1・2が通る | **達成**（構文チェック4ファイルOK、単体テスト21ファイル全件 `failures=0`） |
| 2 | 検証3で `sed` が1件当たったうえで、テストが実際に落ちる | **達成**（`before=6 after=5` で1件、壊した側は `/files` を返さなくなった） |
| 3 | 検証4-a が 1（差分リンクが `/pull/206/files`） | **達成**（`grep -c` = 1） |
| 4 | 検証4-b の2つの件数が一致（アンカーの土台が不変） | **達成**（アンカー付き10 / うちCompare上10） |
| 5 | 検証4-c が 1（MR行が実リンク） | **達成**（`grep -c` = 1） |
| 6 | 2回目以降のpushで `- コメント一覧(MR画面):` 行が出る | **未確認**。この検証時点では状態ファイルのSHAとHEADが一致しており `since_url` が空になるため出ない。**次の実push（flow-id 3-7）が最初の確認機会**である |
| 7 | GitLab経路が変わっていない（`gitlab_get_diff_anchor_base_url` の7アサーションが変更なしで通る） | **達成**（`git diff` の削除行は冒頭コメント2行のみ。既存アサーションは1行も変更していない） |

## 停止条件の判定

| 条件 | 該当したか |
|---|---|
| 検証3で `sed` は当たったのにテストが落ちない | **該当しない**（落ちた） |
| 検証3で `sed` が当たっていない | **該当しない**（`before - after == 1`） |
| 検証4-a が 0 になる | **該当しない**（1だった。配線バグと縮退の切り分けは不要） |
| 検証4-b の2つの件数が一致しない | **該当しない**（10 = 10） |
| 既存の単体テストが1件でも落ちる | **該当しない**（0件） |
| hookがハング・遅延する | **該当しない**（体感で分かる遅延は無かった。ただし下記「測っていないこと」参照） |

## 実装した内容

### 作業1: `get_mr_diff_url` の4引数化

`Github.sh` / `Gitlab.sh` / `Provider.sh` の3ファイル。第4引数 `mr_url` が非空なら
Diffview（GitHubは `<mrUrl>/files`、GitLabは `<mrUrl>/diffs`）、空なら従来どおりCompareを返す。
`${4:-}` を使い、既存の3引数呼び出しが `set -u` 配下で壊れないようにした。**純粋関数のまま**である。

### 作業2: `github_resolve_mr_number_for_head` の新設

`git ls-remote` で `refs/pull/*/head` を引き、HEADのSHAと突き合わせてPR番号を得る。
`Provider.sh` には同名のディスパッチャ `resolve_mr_number_for_head` を置いた（GitLabは空を返す）。

計画どおり、次の3つの制約を実装に落とした。

| 制約 | 実装 |
|---|---|
| 一致がちょうど1件のときだけ返す | `awk '$1 == sha { n++; r = $2 } END { if (n == 1) print r }'` の1行に収めた |
| remoteが `http(s)://` のときだけ試みる | `git remote get-url origin` を `case` で判定し、それ以外は即 `return 0` |
| 失敗しても非0で返さない | 各失敗点を `|| return 0` で受ける |

`wc -l` と `sed` は起動していない（件数判定を `awk` へ寄せ、末尾除去をパラメータ展開にした）。
`git` の起動は1回の呼び出しにつき2回（`remote get-url` と `ls-remote`）である。

### 作業3: hookの配線

`post-push-compact-prompt.sh` を3箇所。

| 箇所 | 内容 |
|---|---|
| 324行目付近 | `compare_url` を分離し、`diff_url="$compare_url"` で初期化 |
| 332行目（`current_sha` 算出）の直後 | PR URLの解決と `diff_url` の再計算を**両方**置いた |
| 358行目 | アンカーの土台を `compare_url` へ（`file_links_text=""` の宣言はそのまま残した） |

**3箇所とも、置き換え対象の行が兼ねていた役割を保っている。** 324行目は `repo_url` の `local` 宣言、
358行目は `file_links_text` の `local` 宣言と初期化を兼ねており、どちらも落としていない。

### 作業4: テスト17件の追加

`test_vcs_provider.sh` が `passed=225` から **`passed=242`** になった（+17）。

| 追加したもの | 件数 |
|---|---|
| `github_get_mr_diff_url` / `gitlab_get_mr_diff_url` の4引数版（Diffview／空文字でCompare） | 4 |
| ディスパッチャ経路（github/gitlab × 4引数あり/なし） | 4 |
| 差し替えがサブシェルに閉じていることの表明（`get_provider` / `git`） | 2 |
| `github_resolve_mr_number_for_head` の分岐（1件／0件／2件以上／scp形式／`ssh://`／失敗／失敗時の終了コード） | 7 |

**挿入位置は `get_provider` の全域上書き（220行目付近）より前**にした。同ファイルのコメントが
「`get_provider` に依存するテストをこれより後ろへ追加しないこと」と警告しているためである。

冒頭コメント（6-7行目）の「Provider.sh経由のディスパッチは対象外」も書き換えた
（ディスパッチャ経路テストを足したことで、そのままでは偽になるため）。

## 実際のhook出力（この環境で取得したもの）

```
参照リンク:
- MR: https://github.com/yuki-matsu783/MR-driven-workflow/pull/206
- defaultブランチとの差分: https://github.com/yuki-matsu783/MR-driven-workflow/pull/206/files
```

**変更前は次の2行だった**（同じ環境・同じブランチ）。

```
- MR: (gh/glab CLI不在のため未取得。mcp__github__list_pull_requests で head="<owner>:<branch>" を指定して取得すること)
- defaultブランチとの差分: https://github.com/yuki-matsu783/MR-driven-workflow/compare/main...claude/pr-mr-diffview-link-yxim1l
```

重点ファイルリンクは10本すべて `.../compare/main...<branch>#diff-<sha256>` のままである
（意図した残存制約であり、後退ではない。調査結果「分離の残存制約」参照）。

## 測っていないこと・確認できなかったこと

- **git bash（Windows）実機での挙動とコスト。** `git ls-remote` の往復がpushのたびに乗るが、
  Linuxでの実測（約400〜600ms）をそのまま持ち込めない。
- **認証プロンプト・ハング対策の実効性。** `credential.helper=` `core.askPass=`
  `http.lowSpeedLimit/lowSpeedTime` を付けたが、この環境では発動条件を作れない。
- **CLI経路（`get_vcs_access_mode` が `cli`）の挙動。** `gh`/`glab` が無いため実行できない。
  CLI経路では `mr_url` が最初から非空で、追加した解決ブロックは `[ -z "$mr_url" ]` により
  素通りする——これは**コードを読んだ上での判断であり、実機確認ではない**。
- **SSH remoteでの挙動。** 単体テストでは `case` の判定を固定したが、実際のSSH remoteで
  `ls-remote` が起動しないことは実環境で確認していない（`git` をスタブして確認した）。
- **完了条件6**（コメント一覧行）。次の実pushが最初の確認機会である。

## 想定と異なった点

| 見込み | 実際 |
|---|---|
| 検証4は「pushしてから目視」しかできないと思っていた | **hookはstdinからJSONを受ける単一プロセスなので、その場で何度でも実行できた。** 状態ファイルの退避だけ気をつければよい。切り分けが1pushにつき1回という制約は最初から存在しなかった |
| `refs/pull` の解決が失敗してCompareへ縮退する可能性を見込んでいた | **1発で解決した**（`refs/pull/206/head` がHEADと一致）。ただしこれは伝播が速かった場合の1例にすぎない |
