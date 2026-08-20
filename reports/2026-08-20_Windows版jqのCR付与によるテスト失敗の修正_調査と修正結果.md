---
title: Windows版jqのCR付与によるテスト失敗の修正 - 調査と修正結果
type: report
description: issue #94。失敗の機構をLinux上で再現し、修正2件と横断確認95箇所の絞り込み結果を記録する
tags: [shell-script, test, windows, jq]
keywords: [jq, CR, コマンド置換, tr, 複数行, スタブ, 横断確認, テキストモード, issue94, git bash]
---

# Windows版jqのCR付与によるテスト失敗の修正 — 調査と修正結果

対象: issue #94 / 計画: `plans/【調査】【実装】Windows版jqのCR付与によるテスト失敗の修正.md`

## 結論

- 実際に壊れていたのは**1箇所だけ**（`test_post_issue_create_notice.sh` の
  `additionalContextへ注意文がそのまま入る`）だった。修正して `failures=0` になった。
- 横断確認の結果、**テスト側25箇所・本体側70箇所の「`tr -d '\r'` の無い `jq -r`」のうち、
  修正が必要なものは他に1件**（`Github.sh` の `github_get_mr_unresolved_comments`）だけだった。
  残りは値が1行に収まるため表面化しない。
- 判定基準（複数行かどうか）と、Windows実機なしで検証する方法を
  `.claude/rules/shell-script-style.md` へ追記した。

## 1. 失敗の機構（実測で確定）

観測される値は、次の2つの性質の**合成**である。

| 性質 | 主体 | 内容 |
|---|---|---|
| A | Windowsネイティブ `jq.exe` | 標準出力をテキストモードで開くため、**各行の行末**にCRを付ける |
| B | MSYS bash のコマンド置換 | 文字列**末尾**の `\r\n` はまとめて落とす |

したがって `$(... | jq -r ...)` で受けた値に残るCRは **「行数 − 1」個** になる。

- 値が**1行**なら、唯一のCRがBで落ちるため**表面化しない**。
- 値が**複数行**なら、最終行以外のCRが残る。期待値と実際の値は**目視では完全に同一に見える**のに
  一致しないという、最も気づきにくい形で失敗する。

issue #94本文の「hook本体の `jq -nc` 出力にも同じCRが付く」は、テストが実際に受け取る値には
当てはまらない（`jq -nc` の出力は1行なのでBで落ちる）。issueコメントでの訂正どおりであることを
本作業でも確認した。

### 実測値

`NOTICE_TEXT`（7行・901バイト）を `jq -r` で取り出した場合:

| | バイト数 | `tr -d '\r'` 後 |
|---|---|---|
| 期待値（`NOTICE_TEXT`） | 901 | 901 |
| 修正前に受け取る値 | 907 | 901 |
| 修正後に受け取る値 | 901 | 901 |

差の6バイト = CR 6個 = 行数7 − 1。上記の機構と一致する。

## 2. 再現方法（Windows実機なしでの検証）

Windows実機が無いため、上記A・Bの**合成結果**を再現するスタブ `jq` を作り、`PATH` の先頭へ置いた。
最終行**以外**の行末へCRを付ける（`sed '$!s/$/\r/'`）と、実際に観測される値と一致する。

このスタブで `test_post_issue_create_notice.sh` が **`passed=13 failures=1`** となり、
issue本文の報告値を正確に再現できた。失敗したアサーションも報告どおり1件のみだった。

**スタブが実機と合わない2ケース**（実際の不具合と取り違えないこと。詳細は規約へ追記済み）:

1. `jq` の後段に `head`/`sed` が挟まる場合 — `test_vcs_provider.sh` で4件。実jqは最終行にも
   CRを付けるため後段を通してもBで落ちる。実機は `passed=131 failures=0`（issueコメントの実測）。
2. テストが `PATH` 自体を差し替える場合 — `test_extract_frontmatter.sh` の `fake_bin` が実例。
   スタブが内部で呼ぶ `sed` もPATHから消えるため空を返す。

## 3. 修正した箇所

| ファイル | 内容 | 理由 |
|---|---|---|
| `.claude/scripts/test/test_post_issue_create_notice.sh` | `jq -r` の2箇所へ `\| tr -d '\r'` | issueが報告した失敗そのもの。`hookEventName` 側（1行の値）は現状表面化しないが、`jq -r` の結果は必ず除去するという `test_usage_tracking.sh` の既存方針へ揃えた |
| `.claude/scripts/src/vcs/Github.sh` | `github_get_mr_unresolved_comments` の `jq -r` へ `\| tr -d '\r'` | `join("\n\n")` で**複数行**のレビューコメント本文を出力するのに除去が無かった。GitLab側の対応関数 `gitlab_format_discussion_notes` には既に入っており、非対称だった |

`Github.sh` 側は `gh` CLIを必要とするため単体テストが無く、今回の失敗としては表面化していない。
GitLab側との非対称の解消として直した。

## 4. 修正しなかった箇所と、その判断

### 4-1. 値が1行に収まる `jq -r`（大多数）

`@tsv` / `join(", ")` / `length` / 単一フィールド参照など。Bにより表面化しないため触っていない。
`tr` の追加はfork1回分のコストを持つ（`.claude/rules/shell-script-style.md`
「外部プロセス起動のコスト」: git bashで約95ms/回）ため、効果の無い箇所へ機械的に足すのは
不利益のほうが大きい。

### 4-2. hookの `.tool_input.command`（4ファイル）

`post-push-usage-report.sh` / `post-push-compact-prompt.sh` / `post-issue-create-notice.sh` /
`block-direct-git-commit.sh` の4つは、ヒアドキュメントを含むコマンド文字列を受けるため
**複数行になりうる**が、以下の理由で `tr` を追加しなかった。

- 判定が**CRに依存しない**。`grep -qiE 'git[[:space:]]+push'` の `[[:space:]]` はCRにマッチし、
  `[[ "$command" == *create-issue.sh* ]]` は部分一致なのでCRがあっても結果が変わらない。
- これらのhookは**毎ツール呼び出しで発火する**ホットパスであり、効果の無い `tr` はfork1回分の
  遅延だけを残す。

代わりに「判定をCRに依存しない書き方に保つ」ことを規約へ明文化した。行アンカー付き正規表現や
完全一致へ変更する場合は、その時点でCR除去が必要になる。

## 5. 検証結果

`.claude/scripts/test/test_*.sh` を全12本、通常jqとスタブjqの両方で実行した。

| | 通常jq | スタブjq（Windows相当） |
|---|---|---|
| `test_post_issue_create_notice.sh` | `passed=14 failures=0` | `passed=14 failures=0` |
| 他11本 | すべて `failures=0` | `test_extract_frontmatter.sh` 1件・`test_vcs_provider.sh` 4件のみ（上記2のスタブ側の限界。実機では失敗しない） |

- CR混入の確認は `grep -c $'\r'` を使わず、`tr -d '\r'` 前後の**バイト数比較**で行った
  （変更した3ファイルはいずれも差0＝CRなし。BOMも無し）。
- 変更した `.sh` は `bash -n` で構文チェック済み。

## 6. 受け入れ条件の充足状況

| 受け入れ条件 | 状況 |
|---|---|
| `test_post_issue_create_notice.sh` が `failures=0` で終了する | 充足（通常jq・スタブjqの両方で `passed=14 failures=0`） |
| `test_*.sh` を全件実行し、すべて `failures=0` | 充足（通常jqで全12本 `failures=0`） |
| CR混入の検査にバイト数比較を使う | 充足（上記5） |
| jq出力をコマンド置換で受けている箇所の横断確認 | 充足（95箇所を「複数行になりうるか」で絞り込み、該当2件を修正。判断は上記4） |

## 7. 残課題

- `github_get_mr_unresolved_comments` は `gh` CLIに依存するため単体テストが無い。GitLab側のように
  整形部分を純粋関数へ切り出せばテストできるが、本issueの範囲を超えるため行っていない。
- 本修正はWindows実機では未検証（スタブによる再現・検証のみ）。実機で
  `bash .claude/scripts/test/test_post_issue_create_notice.sh` を流し `failures=0` を確認できると
  確実である。
