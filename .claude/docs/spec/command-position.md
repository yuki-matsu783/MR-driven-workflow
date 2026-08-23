---
title: コマンド位置判定（CommandPosition.sh）
type: spec
description: hookが受け取るコマンド文字列に対し、gitのサブコマンド／任意のスクリプトが実際にコマンドとして実行される位置にあるかを判定する仕組みの仕様
tags: [spec, hooks, 検知, shell]
keywords: [CommandPosition, コマンド位置, 正規化, ヒアドキュメント, クォート, 保守的フォールバック, 部分一致, 縮退, 純粋関数, bash, command_invokes_script, スクリプト実行判定]
---

# コマンド位置判定（CommandPosition.sh）

- 実装: `.claude/hooks/lib/CommandPosition.sh`
- 単体テスト: `.claude/scripts/test/test_command_position.sh` /
  `.claude/scripts/test/test_post_issue_create_notice.sh`（3段ガードの縮退経路を含む）
- 利用元: `.claude/hooks/block-direct-git-commit.sh` /
  `.claude/hooks/post-push-usage-report.sh` / `.claude/hooks/post-push-compact-prompt.sh`
  （いずれも`command_invokes_git_subcommand`経由） /
  `.claude/hooks/post-issue-create-notice.sh`（`command_invokes_script`経由。issue #149。
  下記「公開インターフェース」参照）
- 経緯: issue #53、DDR `i0053-01`（gitサブコマンドの判定を新設）。issue #149、DDR `i0149-01`
  （任意のスクリプト実行の判定を追加）
- **`.claude/hooks/block-direct-git-commit.sh` は、この判定本体へ渡す前に前置フィルタ
  （`raw_hints_at_git_commit`）を持つ**（issue #159、DDR `i0159-01`）。前置フィルタは
  判定本体の**超集合**（判定本体が検知する入力を1件も取りこぼさない）として設計されており、
  「本判定が実際に呼ばれる入力の集合」を狭めない（jqより前に足切りするのは、本判定が
  検知しないと確定できる入力のみ）。前置フィルタの正規化（バックスラッシュ除去・
  大文字小文字非依存の比較）は、本判定の正規化仕様（下記）に合わせて超集合性を保っている
  ——**ただし前置フィルタが受け取るのはjqがデコードする前の生JSON文字列であるため、単純な
  バックスラッシュ除去だけでは不十分で、JSON文字列エスケープの2文字シーケンスをまとめて
  除去する必要がある（作業結果への敵対的レビューで発見した反例。詳細はDDR `i0159-01`
  「なぜバックスラッシュ1文字だけの除去でも足りないのか」）。

## 背景・目的

hookは `tool_input.command`（AIエージェントがBash/PowerShellツールへ渡したコマンド文字列）を
受け取り、そこに `git commit` / `git push` のような呼び出しが含まれるかで発火を決める。

issue #53 以前の判定は `grep -qiE 'git[[:space:]]+commit'` という**部分一致**だけだった。
文字列のどこに該当語が現れてもマッチするため、次のものを実行と区別できなかった。

- ヒアドキュメント本文（issue本文・MR descriptionを渡すときの地の文）
- クォートされた文字列リテラル（`--message "…"`）
- `#` から始まるコメント（この仕組み自体を日本語で説明するとき）
- 該当文字列を検索する `grep` 等

実際に issue #39 で2回、#45・#47 で各1回踏んでおり、issue #53 の作業中にも2回踏んだ。

**目的は、実行を見逃さないまま、実行でないものへの発火を減らすことである。** 逆向きの誤り
（実行を素通りさせる）は許容度が低いため、判断がつかない場合は必ずブロック側へ倒す。

## 公開インターフェース

外部コマンドを一切呼ばない純粋関数として提供する。結果は標準出力ではなく `REPLY` および
終了コードで返す（コマンド置換によるforkを避けるため。
`.claude/rules/shell-script-style.md`「外部プロセス起動のコスト」）。

| 関数 | 引数 | 戻り |
|---|---|---|
| `normalize_shell_command_to_reply <コマンド文字列>` | コマンド文字列 | `REPLY` = 正規化後の文字列 |
| `command_invokes_git_subcommand <コマンド文字列> <サブコマンド>` | 例: `… commit` | 終了コード 0 = 実行とみなす（発火）／1 = 対象外 |
| `command_invokes_script <コマンド文字列> <対象スクリプト名>` | 例: `… create-issue.sh` | 終了コード 0 = 実行とみなす（発火）／1 = 対象外 |

サブコマンド名・対象スクリプト名は呼び出し側が指定する（`commit` / `push`、`create-issue.sh`
等）。判定は小文字化して行う。**`command_invokes_git_subcommand`はgitの固定サブコマンドを、
`command_invokes_script`は任意のスクリプトのbasenameを判定する**という役割の違いがある
（issue #149。実装は別々のトークン走査関数`_cp_scan_tokens`/`_cp_scan_tokens_for_script`に
分かれており、詳細な相違点は下記「判定の3段」参照）。`command_invokes_script`は、パス付き・
`.exe`付き・大文字混じりで渡された対象スクリプト名の表記ゆれも吸収する。

## 判定の3段

### 1. 事前チェック（縮退）

1行でも `_CP_MAX_LINE_LENGTH`（8192バイト）を超える行があれば、**正規化を行わず従来の部分一致で
判定する**。正規化は1行の中の特殊文字数に対して二乗のコストを持ち（下記「性能」）、hookは
すべてのツール呼び出しで走るため、上限を設けないと長い1行コマンドで体感遅延になる。
PreToolUseの `timeout` に達するとhookが効かないまま素通りするため、**遅くなるより誤検知が
残るほうを選ぶ**。

**縮退時の部分一致の判定式は、`command_invokes_git_subcommand`と`command_invokes_script`で
異なる**（issue #149）。前者はサブコマンド固定の正規表現 `git[[:space:]]+<sub>` を使うが、
後者は対象スクリプト名の単純な部分文字列一致（`*<script>*`）を使う（gitのように「間に
オプションが挟まる固定の2語」を前提にできず、任意のスクリプト名1語をそのまま探すため）。

### 2. 正規化

コマンド位置になりえない区間を、プレースホルダ `_` へ潰す。

| 区間 | 扱い |
|---|---|
| シングルクォート `'…'` | `_` へ潰す |
| ダブルクォート `"…"` | `_` へ潰す。ただし中の `$( )` と `` ` ` `` は**コードとして展開し直す**（`echo "$(… commit)"` を見逃さないため） |
| `#` 以降の行末まで | `_` へ潰す（コマンド位置に `#` があるときのみコメントとみなす） |
| ヒアドキュメント本文 | 区切り語に一致する行が現れるまで丸ごと `_` へ潰す。`<<-` のインデント付きにも対応 |
| 算術展開 `$(( … ))` | 対応する `))` まで一括で読み飛ばす（中の `<<` をヒアドキュメント開始と誤読しないため） |
| 行継続（行末の `\`） | 次の行と**連結して1行として扱う**（`git \`＋改行＋`commit` は1つのコマンド） |
| エスケープ `\x` | `x` が単語構成文字（`[A-Za-z0-9_./-]`）ならそのまま出す（`\git` → `git`）。それ以外は `_` |

`$(` からコードへ入るときは `' ( '`、`` ` `` からは `` ' ` ' `` を出力する。これらはセパレータと
して働くので、コード区間の先頭がコマンド位置になる。

**ヒアドキュメントの区切り語が空または数字のみの場合は、ヒアドキュメントとして扱わない。**
算術左シフト等の誤読で、以降の全行を本文として飲み込むのを防ぐ保守側の制限である
（1箇所の誤読が以降のすべてのコマンドを素通りさせるため、失敗の向きが悪い）。

### 3. コマンド位置でのトークン走査

正規化後の文字列を、空白（`IFS` に `\r` を含む）でトークンへ割る。次の位置を**コマンド位置**と
みなす。

- 文字列の先頭
- セパレータ（`;` `&&` `||` `|` `&` 改行 `(` `` ` ``）の直後

コマンド位置のトークンについて、次を行う。

| トークン | 扱い |
|---|---|
| リダイレクト（`>` `<` `2>` `>>` 等で始まる語、およびその値） | **コマンド位置を保ったまま読み飛ばす**（リダイレクト語はコマンド名ではない） |
| `_CP_PREFIX_WORDS`（`if` `sudo` `env` `time` `exec` 等） | 読み飛ばし、**次のセパレータまでコマンド位置を保つ**（sticky）。`sudo -u alice … commit` のように間にオプションとその引数が挟まる形へ対応する |
| `VAR=value` 形式の代入 | 読み飛ばす（コマンド位置は保つ） |
| コマンド名 | パスの末尾で比較し、`.exe` を落とす（`/usr/bin/git` `./git` `git.exe` を同一視） |

コマンド名が `git` だった場合、続くトークンを次の規則で読み進め、**最初の非オプショントークン**が
目的のサブコマンドかを比べる。

- `_CP_GIT_OPTS_WITH_VALUE`（`-c` `--git-dir` `--work-tree` `--namespace` `--exec-path`
  `--super-prefix`）は**2トークン**消費する。判定は小文字化後に行うため、`-c`（設定）と
  `-C`（ディレクトリ）は同じ項目に落ちる。どちらも値を1つ取るので区別は要らない。
- `--git-dir=/x/.git` のような `=` 連結形は1トークンなので1つだけ消費する。
- その他の `-*` は1トークン消費する。

#### `command_invokes_script`（`_cp_scan_tokens_for_script`）との相違点（issue #149）

任意のスクリプトのbasenameを判定する`_cp_scan_tokens_for_script`は、上記のgit専用
`_cp_scan_tokens`とトークン走査の骨格を共有しつつ、次の点を意図的に変えている。

- **インタプリタ経由の起動（`bash <path>` 等）を1トークン先読みして肯定的に検知する。**
  `_CP_OPAQUE_WITH_OPT`（`bash`/`sh`等）に一致したコマンド名の直後の非オプショントークンが
  対象スクリプトのbasenameなら、その場で一致とみなす（`create-issue.sh`は実際に
  `bash .claude/scripts/src/create-issue.sh …`のように起動されるため、**これが本判定の
  主検知経路である**）。ただし直後に`_CP_CODE_OPTS`（`-c`等）が挟まる場合は保守的
  フォールバックへ回り（下記§4）、`_CP_SHELL_INTERPRETERS`（bash/sh/zsh/ksh/dash/busybox）＋
  `_CP_NONEXEC_OPTS`（`-n`。構文チェックのみで実行しない）の場合は検知対象にしない。
  git版の`_cp_scan_tokens`にはこの肯定的検知経路自体が無く、`bash`を見た時点で
  `at_cmd=0`にして`-c`系の有無だけを見る。
- **`_CP_PREFIX_WORDS`通過後の挙動**: git版は次のセパレータまでコマンド位置を保つ
  （sticky）。script版は「次の非オプション・非代入トークンを実コマンドとして1回だけ判定し、
  そこでコマンド位置を終える」（`sudo cat <path>`のように、無関係なコマンドの引数に
  対象スクリプト名が現れるだけのケースで誤検知しないため）。
- **`{`/`}`のトークン化**: git版は人工的な空白挿入の対象に含めるが、script版は除外する
  （`${VAR}/path`のようなパラメータ展開の直後を誤ってコマンド位置と扱わないため。
  ブレースグループ`{ cmd; }`は素の空白分割で判定できるため検知は失われない）。
- **値を取るprefixオプション**（`_CP_PREFIX_OPTS_WITH_VALUE`。`sudo -u`・`nice -n`等）と、
  **最初の非オプション引数が値であるprefix語**（`_CP_PREFIX_WORDS_WITH_LEADING_VALUE`。
  `timeout DURATION COMMAND`の`DURATION`）は、script版のみが持つ（git版の
  `_CP_GIT_OPTS_WITH_VALUE`と同種の仕組みだが対象語が異なる）。これらを読み飛ばさないと、
  値トークンを実コマンドと誤認し、直後の本当のコマンドを見なくなる。**ただし
  `_CP_PREFIX_OPTS_WITH_VALUE`は該当prefix語のすべてのオプションを一律「値を1つ取る」と
  みなすため、`sudo -n`のように値を取らないオプションでは逆に対象スクリプト自体を値として
  読み飛ばして見逃す（下記「既知の制約」表）。**
- **変数代入の判定順序**: script版はtarget一致の判定より**先に**変数代入
  （`^[A-Za-z_][A-Za-z0-9_]*=`）を判定する（`SCRIPT=<path>/create-issue.sh`のような代入を、
  `${t##*/}`で削った結果が偶然targetと一致して誤検知しないため）。git版は`base == 'git'`の
  判定を代入判定より先に行っており、**順序が逆**である（git版はコマンド名が固定の`git`一語
  なので、代入の右辺がたまたま`git`という値になるケースが実運用上ほぼ無く、順序の影響が
  出にくいという違いによる）。

### 4. 保守的フォールバック

位置判定で一致しなかった場合でも、**文字列をコードとして受け取りうる実行系**がコマンド位置に
あり、かつ従来の部分一致が成立するなら、ブロック側へ倒す。

| 集合 | 語 | 条件 |
|---|---|---|
| `_CP_OPAQUE_WORDS` | `eval` `xargs` `find` `ssh` `watch` `flock` `parallel` | 無条件 |
| `_CP_OPAQUE_WITH_OPT` | `bash` `sh` `zsh` `ksh` `dash` `busybox` `python` `python3` `perl` `ruby` `node` `deno` `pwsh` `powershell` | `_CP_CODE_OPTS`（`-c` `-e` `-E` `--command` `-command` `-encodedcommand`）と併用されたときだけ |

**後者を無条件にできないのは**、`bash .claude/scripts/src/create-commit.sh --message "…"` の
ような正規の呼び出しまでフォールバックの対象になってしまうためである（issue #53 の受け入れ条件
「ブロックされないこと」に反する）。

`command_invokes_script`（script版）の保守的フォールバックは、上記に加えて次を持つ
（issue #149。上記「§3」の主検知経路と対になる仕組み）。

- インタプリタ経由（`_CP_OPAQUE_WITH_OPT`）の直後の引数が、正規化でプレースホルダ`_`へ
  潰れている（クォート等で囲まれていた）場合、`_CP_OPAQUE_FOUND`を立てて保守的フォールバックの
  対象にする（`bash "$VAR/create-issue.sh"`のようなクォート付きパスを拾うため。詳細・既知の
  制約は下記「既知の制約」表）。

## 呼び出し側（hook）の責務

ライブラリは bash 4.3 以上を必要とする（`mapfile` / `${var,,}` / `${arr[-1]}` /
`unset 'arr[-1]'`）。hookは次の3段ガードを通し、**満たさない場合は従来の部分一致へ落とす**。
実装には2つの型があり、いずれも同じ3段（バージョン・`source`成否・`declare -F`）を確認する
（issue #149でscript判定を追加した際に、既存のトップレベル確定型のほかに遅延初期化型が
必要になった）。

### 型A: トップレベルで確定させる（`block-direct-git-commit.sh`型）

```bash
local lib_dir="${BASH_SOURCE[0]%/*}"
[ "$lib_dir" = "${BASH_SOURCE[0]}" ] && lib_dir='.'
local lib="${lib_dir}/lib/CommandPosition.sh"
if ((BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 3))) &&
  [ -r "$lib" ] && source "$lib" 2>/dev/null &&
  declare -F command_invokes_git_subcommand >/dev/null; then
  ...
elif <従来の部分一致>; then
  ...
fi
```

`main()`内・前置フィルタ（issue #159）の後で確定させる。多くのhookはこの型で足りる。

- **`source` を `&&` の連鎖へ置くこと**が要点である。`main` は `set -euo pipefail` を宣言して
  おり、`source` を単独で書くと失敗時にスクリプトが終了コード2で落ちる。PreToolUseの
  終了コード2は「ブロック」を意味するため、**gitと無関係なコマンドを含むすべてのBash呼び出しが
  ブロックされる**（`if` の条件式の中では `set -e` が一時停止されるため、連鎖にすれば落ちない）。
- **`${BASH_SOURCE[0]%/*}` は `/` を含まない起動でファイル名自身を返す。** `.claude/hooks` を
  カレントにして `bash block-direct-git-commit.sh` と起動した場合が該当し、フォールバックへ
  無言で落ちる（エラーも警告も出ないため気づけない）。上記2行で `.` へ倒す。

### 型B: 初回呼び出しまで初期化を遅延させる（`post-issue-create-notice.sh`型。issue #149）

`post-issue-create-notice.sh`は、`source`して`main()`を実行せず判定関数を直接呼ぶ単体テストが
あるため、判定関数（`_pin_cli_match`）自体は**トップレベルで関数として存在**させる必要が
あった。一方、トップレベルで即座に`source`まで済ませると、`raw_hints_at_issue_create`
（前置フィルタ、issue #159。`main()`の中にありこの関数定義より後）で弾かれる呼び出しでも
毎回`CommandPosition.sh`（約800行）を読み込むことになり、フィルタ済みの高速経路で計測上
+35%（+1.0ms/回）の遅延が生じ、issue #159の最適化を一部無言で戻してしまう（測定条件は
下記「性能」節「型B比較」を参照）。

この2つの制約を両立させるため、判定関数は**呼ばれるたびに自分自身を確定版へ再定義してから
委譲する**形にした。

```bash
_pin_cli_match() {
  # ここで3段ガード（バージョン・source成否・declare -F）を確認する
  if <3段ガードを満たす>; then
    _pin_cli_match() { command_invokes_script "$1" 'create-issue.sh'; }
  else
    _pin_cli_match() { [[ "$1" == *create-issue.sh* ]]; }
  fi
  _pin_cli_match "$1"
}
```

初回呼び出し（`source`のみの単体テストからの直接呼び出しも含む）で確定版へ差し替わり、
以降の呼び出しは確定版へ直接委譲される（関数呼び出し自体のオーバーヘッドは残るが、
`CommandPosition.sh`の`source`は前置フィルタを通過した呼び出しでのみ発生する）。

## 既知の制約

| 類型 | 例 | 挙動 | 扱い |
|---|---|---|---|
| 意図的な文字列分割 | `git "commit"` / `git c""ommit` | 素通り | **対策しない。** 敵対的な安全境界ではなく「既定動作を確実な方向へ倒す仕組み」であるため（DDR `i0000-09`、issue #53 本文） |
| 変数展開の中身 | `c=commit; git $c` | 素通り | 同上（実行時の値は静的に決まらない） |
| `alias` / 関数による別名 | `alias g=git` の後の `g commit` | 素通り | 未対応。シェルの実行時状態に依存する |
| 8192バイトを超える行 | 巨大な1行コマンド | 部分一致へ縮退（誤検知は残る） | 安全側 |
| 静的に読めない実行体 | `eval "$var"` / `bash -c "$var"` | 部分一致へ縮退 | 安全側 |
| ライブラリを読めない環境 | bash 4.3未満・配布漏れ・構文エラー | 部分一致へ縮退 | 安全側 |
| クォートで囲まれたスクリプトパス、インタプリタ経由（`command_invokes_script`のみ。issue #149） | `bash "$VAR/create-issue.sh"` | 位置判定では追えないが、インタプリタ直後の引数がプレースホルダの場合は保守的フォールバックで拾う | 安全側（見逃しにくくなる方向） |
| クォートで囲まれたスクリプトパス、インタプリタを介さない直接起動（`command_invokes_script`のみ。issue #149） | `"$DIR/create-issue.sh" --title x` | 位置判定・保守的フォールバックのいずれも対象にしない（インタプリタ経由の判定にしか対応していないため）。旧・部分一致実装では検知できていた形なので、機能後退が一部残っている | 素通り（見逃し。issue #149, 3回目レビューで判明） |
| 値を取らないprefixオプション（`command_invokes_script`のみ。issue #149, 2回目レビュー） | `sudo -n <script>` / `command -p <script>` / `env -i <script>` | `_CP_PREFIX_OPTS_WITH_VALUE`は該当prefix語のすべてのオプションを一律「値を1つ取る」とみなすため、値を取らないオプションでは対象スクリプト自体を値として読み飛ばし、見逃す | 素通り（見逃し。issue #149, 3回目レビューで判明） |
| PowerShell経路でのバックスラッシュ区切りパス | `.claude\scripts\src\create-issue.sh` | 素通り（見逃し） | 安全側。`command_invokes_git_subcommand`も共有する既存の制約 |
| opaque語（`find`/`xargs`/`ssh`/`watch`/`flock`）がコマンド位置にある場合の保守的フォールバック | `find . -name create-issue.sh` | 対象語を引数に含むだけの検索コマンド等でも発火する（過検知） | 意図的（ブロックではなく注意喚起の注入に留まるhookでは実害が限定的。issue #149, 2回目レビューで判明） |

意図的な文字列分割・変数展開の中身・aliasによる別名（表の上3行）の「素通り」は
**issue #53 以前も同じ**であり、今回の変更で新たに生じたものではない。**今回追加した制約の
うち、クォートパス（インタプリタを介さない直接起動）・値を取らないprefixオプション・
PowerShellバックスラッシュパスは「発火しない側（見逃し）」に倒れる。一方、opaque語
フォールバックは逆に「発火する側（過検知）」に倒れる。** クォートパス（インタプリタ経由）は
保守的フォールバックにより見逃しにくくなる方向へ倒れる。いずれも「実行を見逃さない」という
本来の目的（上記「背景・目的」）には沿う設計判断だが、「必ず見逃し側に倒れる」という説明は
正確ではない（issue #149, 2回目の敵対的レビューで、この誤った説明が
`post-issue-create-notice.sh`のヘッダコメントにあることが判明し、訂正した）。

## 性能

判定部分だけの比較（200回あたり、同一セッション・空関数をベースライン。Linux）。

| 入力 | 空関数 | 旧（`printf` ＋ `grep`） | 新（純粋bash） |
|---|---|---|---|
| 短い1行（31バイト） | 4ms | 432ms | 98ms |
| ヒアドキュメント（18225バイト） | 23ms | 480ms | 1450ms |

- **短い入力では4.5倍速い。** forkが2回（`printf` と `grep`）から0回になるため。
- **大きなヒアドキュメントでは3倍遅い。** ただし fork のコストは git bash で約95ms/回であり、
  Linuxでの実測（fork 2回 ≒ 数ms）とは桁が違う。**git bash実機では未実測**である。
- **型B比較（issue #149）**: 上記「呼び出し側（hook）の責務」型Bが挙げる「+35%（+1.0ms/回）」
  は、前置フィルタで足切りされる（起票と無関係な）ペイロードを**100回**、同一セッション内で
  `CommandPosition.sh`をトップレベルで即座に`source`する版（型A相当）と現行の遅延初期化版
  （型B）を連続測定した差分（Linux）。287ms/292ms（ライブラリ不在相当）→384ms/392ms
  （トップレベルsource）という実測に基づく（詳細: 敵対的レビュー・実装レビュー2回目の
  指摘本文）。git bash実機では未測定であり、fork単価の違いから絶対値はそのまま外挿できない。
- 正規化は**1行の中の特殊文字数に対して二乗**（行数に対しては線形）。`_CP_MAX_LINE_LENGTH` は
  この二乗部分の頭打ちである。1文字ずつの `${s:i:1}` 走査は `LC_ALL=C` でも改善しないことを
  issue #53 の調査で実測しており、行配列＋チャンク読み飛ばしを採っている。

CR（Windows版native jqが付与する `\r`）への対処は不要である。`tr -d '\r'` を足さずに済むのは、
(1) トークン走査の `IFS` に `\r` を含めており、(2) ヒアドキュメント区切り語の比較前に末尾の
`\r` を落としているためである。スタブ `jq` を用いた検証で、CRの有無で判定が1件も変わらないことを
確認している（`.claude/rules/shell-script-style.md`「テスト」）。

## 影響範囲

### issue #53（新規作成）

- `.claude/hooks/lib/CommandPosition.sh` を新規作成（590行）。
- `.claude/hooks/block-direct-git-commit.sh` / `post-push-usage-report.sh` /
  `post-push-compact-prompt.sh` の判定を差し替え、上記3段ガードを追加。
- `.claude/scripts/test/test_command_position.sh` を新規作成（75件）。
- hookへ直接JSONを流す20ケースが 13/20 → **20/20**。変更前は誤検知6件・検知漏れ1件
  （`git -C dir commit` が素通り）だった。

### issue #149（追加）

- `.claude/hooks/lib/CommandPosition.sh` へ `_cp_scan_tokens_for_script`（内部）・
  `command_invokes_script`（公開）を追加。既存のgit専用関数（`_cp_scan_tokens`・
  `command_invokes_git_subcommand`）は無変更（分岐点との差分でbyte-identicalを確認済み）。
- `.claude/hooks/post-issue-create-notice.sh` のCLI経路判定を`command_invokes_script`へ
  差し替え、3段ガード（型B。上記「呼び出し側（hook）の責務」参照）を追加。
- `.claude/scripts/test/test_command_position.sh` へ受け入れ条件・敵対的レビュー由来の
  回帰ケースを追加（75件→118件）。`.claude/scripts/test/test_post_issue_create_notice.sh`
  へCLI経路のコマンド位置判定ケース・3段ガードの縮退経路テストを追加（31件→38件）。
- 敵対的レビューを計画時1回・実装後2回（計3回）実施し、指摘（sticky未解除・
  `${VAR}`のトークン化・保守的フォールバック欠落・値取りprefixオプション未対応・
  クォートパスの機能後退・3段ガードのホットパス性能回帰・`bash -n`誤検知等）をすべて
  実装へ反映した。詳細: `i0149-01`。

## 未決定事項・懸念点

- **`.claude/settings.json` の `if` フィルタは変更していない。** push検知側は「`if` で絞ってから
  スクリプト内でコマンド位置判定」という二段構えのままである。`if` の照合規則（前方一致か
  部分一致か）は issue #47 が両論併記のまま残しており、本issueでも切り分けていない。`if` を
  緩めると発火が増える方向になり、誤検知を減らすという目的と逆になるため触っていない。
- **`.claude/hooks/post-issue-create-notice.sh` の判定本体（`is_issue_create_call`）には
  issue #149で適用済み。** `command_invokes_script`によるコマンド位置判定へ差し替えた
  （詳細: 上記「利用元」「呼び出し側（hook）の責務」型B）。新たに判明した既知の制約・
  過検知の残存は「既知の制約」表（上記）を参照。
  - **前置フィルタ（`raw_hints_at_issue_create`。issue #159）の超集合性を再確認した。**
    根拠は、(1) 前置フィルタ自体はissue #149で変更しておらず、判定本体の入力形式を狭める
    要因が新たに増えていないこと、(2) 判定本体（`command_invokes_script`）は既存のgit専用
    判定と共通の`normalize_shell_command_to_reply`を経由しており、前置フィルタが既に
    吸収済みのゆらぎ（バックスラッシュ分割・大文字混じり）を判定本体側が追加で要求する
    設計にはなっていないこと、の2点である。**ただし、判定本体を実際に通した突き合わせ
    テスト（同一入力に対し「判定本体が発火するなら前置フィルタも通過する」ことを検証する
    もの）は無く、上記は設計上の推論に留まる**（issue #149, 3回目の敵対的レビューで、
    既存の`test_post_issue_create_notice.sh`の前置フィルタケース群は`raw_hints_at_issue_create`
    のみを直接呼んでおり判定本体を通らないため、この根拠にはならないと指摘された）。
- **Windows / git bash 実機での動作と性能が未確認。** プラットフォーム依存の構文は使っていない
  （`command_invokes_script`も同様）。
- 実運用での誤検知の残存。20ケース・単体テスト（`test_command_position.sh` 118件・
  `test_post_issue_create_notice.sh` 38件）は代表例であって網羅ではない。
