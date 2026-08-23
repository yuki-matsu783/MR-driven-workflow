---
title: 【実装】【テスト】hookの前置フィルタ追加
type: plan
description: block-direct-git-commit.sh / post-issue-create-notice.sh のmain()冒頭へ、jq呼び出し前の超集合な前置フィルタ（純粋関数）を追加する個別作業計画（issue #159）
tags: [plan, hooks, 前置フィルタ, issue-159]
keywords: [前置フィルタ, 超集合, jq, execve, clone, バックスラッシュ, 敵対的レビュー]
---

# 【実装】【テスト】hookの前置フィルタ追加

## 前提

- 上位の計画: `plans/reduce-hook-misfire-cost.md`（全体作業計画。flow-id 1-4）
- フェーズ2〈調査〉は実施しない（上位計画に理由を記載済み）。本計画は調査結果ではなく
  上位計画・issue #159本文・既存実装の読解のみに基づく。
- **本計画は敵対的レビュー（1回目）を経て改訂済み。** 当初案の `${raw,,}` を使う小文字化と
  単純な`*commit*`部分一致には、後述の2件の欠陥（超集合性の破綻・bash 3.2非互換）が
  見つかったため、実装方針を変更した（「方針」節に反映）。

## この計画で何をするか

`block-direct-git-commit.sh` と `post-issue-create-notice.sh` の `main()` 冒頭へ、
判定本体（jq呼び出しを含む）へ入る前の前置フィルタを追加し、対象外ペイロードで `jq` を
1回も呼ばないようにする。あわせて、前置フィルタが精密判定の超集合であることを固定する
単体テストを追加する。

## 変更対象

| ファイル | 操作 | 何をするか |
|---|---|---|
| `.claude/hooks/block-direct-git-commit.sh` | 変更 | `main()`冒頭の`raw="$(cat)"`を`IFS= read -r -d '' raw \|\| true`に置き換え、直後に前置フィルタ関数`raw_hints_at_git_commit`（新規の純粋関数。`main()`の外、ファイル冒頭寄りに定義）の呼び出しを追加。ヘッダコメントへissue #159の説明を追記 |
| `.claude/hooks/post-issue-create-notice.sh` | 変更 | 同様に`main()`冒頭を`IFS= read -r -d '' raw \|\| true`へ置き換え、直後に前置フィルタ関数`raw_hints_at_issue_create`（新規の純粋関数）の呼び出しを追加。ヘッダコメントへissue #159の説明を追記 |
| `.claude/scripts/test/test_block_direct_git_commit.sh` | 新規 | `raw_hints_at_git_commit`を`source`して直接呼ぶ単体テスト（forkなし）と、スタブjqを使った結合テスト（フックプロセスを実際に起動し、jqが呼ばれないことを確認） |
| `.claude/scripts/test/test_post_issue_create_notice.sh` | 変更 | `raw_hints_at_issue_create`の単体テストと、前置フィルタの結合テストを追記（既存の`is_issue_create_call`テストは変更しない） |

**前置フィルタは`main()`内へ直書きせず、`raw_hints_at_*`という独立した純粋関数へ切り出す。**
`is_issue_create_call`と同じ形にすることで、`source`してから直接呼ぶ高速な単体テストが書ける
（`main()`は`BASH_SOURCE`ガードにより`source`時に実行されないため、直書きのままだと
サブプロセス起動を伴う結合テストでしか確認できない。両方のテストを用意する）。

## 方針

### 前置フィルタの実装（改訂版）

issue #70（PR #157、2026-08-23時点で未マージ）で確立された「`read -d ''` + `case`」という
型そのものは踏襲するが、**比較対象の作り方は独自に設計し直す**（理由は次項）。

```bash
# 純粋関数として切り出す（main()の外で定義）
raw_hints_at_git_commit() {
  local raw="$1"
  local probe="${raw//\\/}"           # バックスラッシュを除去してから比較する
  case "$probe" in
    *[Cc][Oo][Mm][Mm][Ii][Tt]*) return 0 ;;
    *) return 1 ;;
  esac
}

main() {
  set -euo pipefail
  local raw
  # `|| true` を省かない。`read -d ''` は入力にNULが無いとEOFで非0を返すため、
  # `set -e` 配下では値が取れているのに終了する。
  IFS= read -r -d '' raw || true
  [ -n "$raw" ] || exit 0
  raw_hints_at_git_commit "$raw" || exit 0
  # ここから先は既存の判定本体（変更なし）
  ...
}
```

- `read`・`case`・`${raw//\\/}`（バックスラッシュ除去）・ブラケット式による大文字小文字非依存の
  比較は、いずれもbash組み込みで forkしない
  （`.claude/rules/shell-script-style.md`「外部プロセス起動のコスト」）。
- 判定本体は変更しない。前置フィルタは高速な足切りであり、正しさの根拠は従来どおり後段が持つ。

**当初案からの変更点（敵対的レビュー1回目で検出。詳細は
`reports/20260823_reduce-hook-misfire-cost_前置フィルタ実装.md`参照）**

| 当初案 | 問題 | 改訂後 |
|---|---|---|
| `${raw,,}` で小文字化 | bash 4.0以降専用の構文。両hookは元々bash 4.0未満でも動く設計（`block-direct-git-commit.sh`は4.3未満なら部分一致へ縮退する2段構え）で、`${raw,,}`をここに置くと**その縮退が始まる前に展開エラーで丸ごと落ちる** | ブラケット式 `[Cc][Oo][Mm]...` による大文字小文字非依存の比較（bash 2.0から動く） |
| バックスラッシュエスケープを考慮しない単純な`*commit*` | `CommandPosition.sh`の正規化は`\x`（xが`[A-Za-z0-9_./-]`）のバックスラッシュを落としてxだけを残すため、`git com\mit`は精密判定ではブロックされるが単純な`*commit*`部分一致では**素通りする**（超集合が壊れる。実機で確認済み） | 比較前に`${raw//\\/}`でバックスラッシュを一括除去する。除去は単調にマッチ候補を増やすだけなので既存のマッチを壊さない |

### block-direct-git-commit.sh: 超集合の設計

精密判定（`command_invokes_git_subcommand`, `.claude/hooks/lib/CommandPosition.sh`）は
以下の性質を持つ。

- コマンド全体を`${s,,}`で小文字化してから走査・比較する（`_cp_scan_tokens`の`${tokens[i],,}`、
  フォールバックの`${lower}`）。つまり `git COMMIT` のような大文字混じりも検知対象になりうる。
- `git`と`commit`が隣接している必要はない（`git -C /x commit`のようにオプションを挟める）。
- `\x`（xが`[A-Za-z0-9_./-]`）のバックスラッシュを落としてxだけを残す正規化を行う。これは
  `\git`でエイリアスを迂回する定番の書式（`.claude/hooks/lib/CommandPosition.sh`ヘッダ参照）を
  拾うためだが、副作用として`com\mit`のように`commit`という語の**途中**へバックスラッシュを
  挟んだ場合も「commit」として拾う。

よって前置フィルタは、**バックスラッシュを除去したうえで大文字小文字非依存に`commit`を含むか**
を見れば超集合になる（上記「前置フィルタの実装（改訂版）」）。`raw`はhookへのJSON入力全体
（`tool_input.command`だけでなく`tool_name`等も含む）であり、`command`フィールド以外に偶然
「commit」を含むケースも当然マッチするが、これは無害な過剰検知であり後段のjq処理へ回るだけで
実害はない。

**なお、クォートで囲われた断片同士を連結して「commit」を合成する意図的な文字列分割
（例: `git 'com''mit'`）への対応は、精密判定自体が対象外としている
（`.claude/docs/ddr/i0000-09-....md`）。前置フィルタもこれには対応しない**（精密判定が
検知しないものを前置フィルタだけが検知しても意味が無いため、超集合の要件はあくまで
「精密判定が検知するものを前置フィルタが取りこぼさない」ことである）。

### post-issue-create-notice.sh: 超集合の設計

精密判定（`is_issue_create_call`）は2経路。

- CLI経路: `tool_name`がBash/PowerShell/run_shell_commandで、`command`に`create-issue.sh`を
  **大文字小文字を区別する完全部分一致**で含む（`[[ "$command" == *create-issue.sh* ]]`）。
- MCP経路: `tool_name`が`mcp__github__issue_write`で、`method`が`create`。

前置フィルタは以下のいずれかを含むかで判定する。

- `create-issue.sh`（バックスラッシュ除去後・大文字小文字非依存。CLI経路の超集合）。
  精密判定自体は大文字小文字を区別する部分一致だが、前置フィルタ側を緩める（超集合を広く取る）
  ことは常に安全側（過剰検知が増えるだけ）なので、あえて精密判定の表記に厳密に合わせない。
- `mcp__github__issue_write`（MCP経路の超集合。`method`の値までは見ない——`method`が
  `create`以外でも前置フィルタは通過するが、後段の`is_issue_create_call`が正しく`create`のみへ
  絞り込む。前置フィルタは「足切り」であって「精密化」ではないため、`method`の値まで狭める必要は無い。
  `tool_name`は固定文字列でありバックスラッシュ・大文字小文字のゆらぎを考慮する必要はない）

**issue #149との整合性（当初案から修正）**: #149は`is_issue_create_call`のCLI経路判定を、
部分一致からコマンド位置判定（`.claude/hooks/lib/CommandPosition.sh`ベース）へ差し替える計画
（未着手）。

**当初、「コマンド位置判定は部分一致の対象を絞り込む方向の変更なので、マッチする集合は
現状の部分一致の部分集合になり、前置フィルタは無条件に超集合であり続ける」と結論していたが、
これは誤りだった**（敵対的レビューで指摘）。コマンド位置判定は絞り込みだけでなく、
バックスラッシュエスケープ・大文字小文字の**正規化による拡張**も伴うため、単純な包含関係
（部分集合）は成り立たない。

改訂後の前置フィルタ（バックスラッシュ除去＋大文字小文字非依存）は、#149が
`CommandPosition.sh`と同じ正規化（バックスラッシュ除去・小文字化）を採用する限り、
その新判定に対しても超集合であり続ける。ただし**これは前提を明記した設計判断であり、
#149の着手時には必ずこの関係が保たれているかを再確認すること**（無条件に成り立つとは
主張しない）。この関係はDDR（フェーズ4）に明記し、#149へも通知する（flow-id 5-2）。

## やらないこと（スコープ外）

この計画では決めない・触らない:

- `is_issue_create_call` / `command_invokes_git_subcommand` の判定ロジック自体の変更
  （issue #149の範囲、または対象外）。
- `.claude/settings.json` の `if` フィールドの追加。
- push系2本のhook（issue #70の範囲）。
- クォート断片の連結による意図的な文字列分割への対応（精密判定自体が対象外としているため）。

## 検証

```bash
bash -n .claude/hooks/block-direct-git-commit.sh
bash -n .claude/hooks/post-issue-create-notice.sh
bash .claude/scripts/test/test_command_position.sh
bash .claude/scripts/test/test_post_issue_create_notice.sh
bash .claude/scripts/test/test_block_direct_git_commit.sh
```

スタブjqによる「対象外ペイロードでjqが1回も呼ばれない」ことの確認は、上記2つの新規/追記
テストの中で実施する（`PATH`先頭へ「呼ばれたら失敗するスタブjq」を置き、実際にhookプロセスを
起動して確認する）。

**execve/clone実測の手順（前後を両方測る）**:

1. **実装に着手する前に**、変更前のhookで測定する。
2. 実装後、同じペイロード・同じ環境で再測定する。

```bash
# ペイロード（対象外の例。実際にJSONとして有効な値を使う）
payload='{"tool_name":"Bash","tool_input":{"command":"git status"}}'

# 変更前後で同じ形で実行し、execve/clone行を比較する
printf '%s' "$payload" | strace -f -c -- bash .claude/hooks/block-direct-git-commit.sh 2>&1 >/dev/null \
  | grep -E "execve|clone|total"
```

strace はLinux専用のため、Windows/git bash実機では代替できない（issue #159本文の実測値を
参照する）。Linux上のstrace自体が使えない実行環境では、この実測ステップは省略し「確認できず」と
`reports/`へ明記する。

合格条件: 全テスト `failures=0`。スタブjqが対象外ペイロードで1度も呼ばれない。次の2種類を
区別してテストする。

- **前置フィルタを通過すべき（精密判定まで到達すべき）例**: `git commit`、
  `git -C /x commit`（gitとcommitが非連続）、`git COMMIT`（大文字）、
  `git com\mit`（バックスラッシュ分割）、`\git commit`（エイリアス迂回書式）。
  いずれも前置フィルタを通過し、精密判定どおりブロックされる（exit 2）。
- **前置フィルタで足切りされるべき例**: `git status`、`git -C /x push`（commitと無関係。
  gitとpushが非連続でも、commitではなくpushなので足切りされるのが正しい）。

## issueの受け入れ条件との対応

| 受け入れ条件 | この計画での対応箇所 |
|---|---|
| 2本の`main()`冒頭を`read -d ''`+`case`による足切りへ置き換える | 「変更対象」表・「方針」 |
| `\|\| true`を省かない | 「方針」の実装コードブロック |
| パターンが超集合であることをテストで固定。`git -C /x push`のように語が連続しない形を含む | 「検証」（`git -C /x commit`を通過例、`git -C /x push`を足切り例として明記） |
| 足切りされるペイロードでjqが1回も呼ばれないことをスタブjqで検証 | 「検証」 |
| issue #149と同じファイルを触る。前置フィルタは新しい判定の超集合であること | 「post-issue-create-notice.sh: 超集合の設計」 |
| 前後のexecve/cloneの実測値を記録に残す | 「検証」→`reports/`へ記録 |
