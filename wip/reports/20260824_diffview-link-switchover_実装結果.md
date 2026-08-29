---
title: 実装結果: Diffviewリンクの出し分けとMCP経路でのPR URL解決
type: report
description: issue #205 フェーズ3の実装結果。4引数化・PR URL解決関数（複数候補SHA対応）・hookの分離配線・テスト22件追加と、7つの完了条件の判定
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
| 6 | 2回目以降のpushで `- コメント一覧(MR画面):` 行が出る | **達成**。コミット `27786bd`（伝播遅延対策）のpush直後のhook出力で確認した:`- コメント一覧(MR画面): https://github.com/yuki-matsu783/MR-driven-workflow/pull/206`。同じpushで「defaultブランチとの差分」も即座に `/pull/206/files` になっており、伝播遅延対策（複数候補SHA）が実際のpushでも機能することを確認した |
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

### 作業4: テスト22件の追加

`test_vcs_provider.sh` が `passed=225` から **`passed=247`** になった（+22。うち17件は当初の実装分、5件はpushの伝播遅延対策（複数候補SHA）を追加した際に増分）。

| 追加したもの | 件数 |
|---|---|
| `github_get_mr_diff_url` / `gitlab_get_mr_diff_url` の4引数版（Diffview／空文字でCompare） | 4 |
| ディスパッチャ経路（github/gitlab × 4引数あり/なし） | 4 |
| 差し替えがサブシェルに閉じていることの表明（`get_provider` / `git`） | 2 |
| `github_resolve_mr_number_for_head` の分岐（1件／0件／2件以上／scp形式／`ssh://`／失敗／失敗時の終了コード） | 7 |
| 複数候補SHAでの解決（前回SHAのみ一致／同一PR番号への複数一致／前回SHAが空でも解決） | 3 |
| ディスパッチャ経由の複数候補受け渡し・GitLab経路が変わらないこと | 2 |

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

## 追記: pushの伝播遅延と対策

flow-id 3-7 の実push（コミット `22a23b7`）で、**調査結果（フェーズ2）が「観測されなかった」と
した伝播遅延が実際に発生した。**

- pushした直後、PostToolUse hookが自動発火した1回目は、`refs/pull/206/head` がまだ**前回push
  時点のSHA**を指しており、`git ls-remote` の突き合わせが不一致になって解決に失敗し、
  「defaultブランチとの差分」がCompareへ縮退した。
- 数十秒後、**同じコミット**（`22a23b7`）に対して解決関数を単体で直接呼び出すと、今度は成功した
  （`refs/pull/206/head` が新しいSHAへ更新されていた）。
- 同一コミット・同一環境で経過時間だけが異なる2回の呼び出しなので、**フェーズ2の計測条件が
  hookの実際の発火タイミング（push完了の直後）とずれていたことが原因**と判断した
  （フェーズ2の計測はpushからしばらく経ってから行っていた）。

**対策**: `github_resolve_mr_number_for_head`（および `Provider.sh` のディスパッチャ
`resolve_mr_number_for_head`）を、単一SHAではなく**複数の候補SHA**を受け取る形へ変更した。
`post-push-compact-prompt.sh` は、今回pushのSHA（`current_sha`）に加えて**前回pushのSHA**
（状態ファイル `wip/state/review-links/<branch>.txt` に記録済みの `prev_sha`）も候補として渡す。

判定基準も「一致したref数」から「**一致したPR番号の種類数**」へ変更した。複数の候補SHAが
同じPR番号のrefに一致するのは正常なケースだからである（例: `refs/pull/206/head` が前回SHA・
今回SHAのどちらを指していても、pushの直後というタイミングでは両方とも同じPR #206を指す）。
1種類のときだけ採用し、0種類（伝播遅延の窓の外・前回pushも無い等）・2種類以上（異なるPRに
またがる不自然な一致）は従来どおりCompareへ縮退する——**「誤ったURLを出すくらいなら
Compareのままにする」という当初方針は変えていない。**

この変更により、pushの直後というhookが実際に走るタイミングでも、`refs/pull/<n>/head` が
前回SHA・今回SHAのどちらを指していても解決できるようになった（どちらのSHAで引いても
同じPR番号が出るため）。`test_vcs_provider.sh` に検証を5件追加した（複数候補での解決・
候補が同じPR番号に一致するケース・前回SHAが空でも今回SHAだけで解決すること・ディスパッチャ
経由の複数候補受け渡し・GitLab経路が変わらないこと）。

**空振りでないことも検証3と同じ手順で確認した。** `mr_url` の受け渡しに加え、
`resolve_mr_number_for_head` の `"$@"` 渡しを1引数だけへ落とす改変を一時ツリーで加えたところ、
`test_vcs_provider.sh` は3件（`get_mr_diff_url` 系2件・ディスパッチャの複数候補受け渡し1件）が
実際に失敗した（`passed=244 failures=3`）。

## 想定と異なった点

| 見込み | 実際 |
|---|---|
| 検証4は「pushしてから目視」しかできないと思っていた | **hookはstdinからJSONを受ける単一プロセスなので、その場で何度でも実行できた。** 状態ファイルの退避だけ気をつければよい。切り分けが1pushにつき1回という制約は最初から存在しなかった |
| `refs/pull` の解決が失敗してCompareへ縮退する可能性を見込んでいた | **フェーズ2の計測時点では1発で解決した**（`refs/pull/206/head` がHEADと一致）。しかし**実際のpush直後（flow-id 3-7）には解決に失敗しCompareへ縮退した**（上記「追記: pushの伝播遅延と対策」）。フェーズ2の「1発で解決した」という記録は、計測をpushの直後ではなくしばらく経ってから行っていたための見かけ上の結果であり、伝播遅延は実在した |
