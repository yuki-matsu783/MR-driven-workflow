---
title: 20260823 hookの前置フィルタ実装（issue #159）
type: report
description: block-direct-git-commit.sh / post-issue-create-notice.sh へ追加した前置フィルタの実装結果。敵対的レビュー2回（作業計画・作業結果）で見つかった超集合の反例2件・execve/clone実測（変更前後）・残課題をまとめる
tags: [report, hooks, 前置フィルタ, 性能, issue-159]
keywords: [前置フィルタ, 超集合, execve, clone, jq, バックスラッシュ, JSONエスケープ, 敵対的レビュー, strace, 反例]
---

# 20260823 hookの前置フィルタ実装（issue #159）

## サマリ（結論の一覧）

| # | 問い／やったこと | 結論 | 根拠の性質 |
|---|---|---|---|
| 1 | 2本のhookの`main()`冒頭を前置フィルタへ置き換えたか | 実施した（issue #70/PR #157と同型の`read`+`case`パターン。比較対象の作り方は独自設計） | 実装の確認 |
| 2 | 前置フィルタは判定本体の超集合か | 敵対的レビューで2件の反例（バックスラッシュ分割・bash互換性）が見つかり、修正して超集合であることをテストで固定した | 実測（結合テスト・敵対的レビュー） |
| 3 | 対象外ペイロードで`jq`が1回も呼ばれないか | 呼ばれない（スタブjqで確認） | 実測（結合テスト） |
| 4 | 空振り時のexecve/clone回数は削減されたか | 大幅に削減された（詳細は「実施した内容と結果」） | 実測（strace） |
| 5 | 既存の判定挙動（block/notice）を変えていないか | 変えていない（既存テスト全件パス） | 実測（単体テスト） |

## 実施条件（測った対象・環境）

- 実行環境: Claude Code on the webのリモート実行環境（Linux, x86_64）
- 対象: `.claude/hooks/block-direct-git-commit.sh`, `.claude/hooks/post-issue-create-notice.sh`
- strace: 6.8、bash: 5.2.21、jq: 1.7
- 実施日: 2026-08-23
- **git bash実機（Windows）では未確認。** 本リポジトリの主な実行環境はgit bashだが、strace自体が
  Linux専用のため、ここでの実測値はLinux上での相対的な削減効果の参考値である。git bashでの
  絶対値はissue #159本文の実測（execve5/clone10, execve7/clone17）を参照する。

## 実施した内容と結果

### 1. 前置フィルタの実装（初版）と敵対的レビューによる改訂

issue #70（PR #157、未マージ）のpush系hook2本と同型の`read`+`case`パターンを、
`block-direct-git-commit.sh`（PreToolUse）・`post-issue-create-notice.sh`（PostToolUse）の
`main()`冒頭へ適用した。初版は`${raw,,}`による小文字化と単純な`*commit*`/`*create-issue.sh*`
部分一致だったが、**フェーズ3個別作業計画に対する敵対的レビュー（1回目）で2件の欠陥が
見つかり、実装前に方針を修正した**。

| 検出内容 | 深刻度 | 対応 |
|---|---|---|
| 超集合性の破綻: `git com\mit`（バックスラッシュで語を分割）は精密判定ではブロックされるが、単純な`*commit*`部分一致では素通りする | major | 比較前に`${raw//\\/}`でバックスラッシュを一括除去する |
| bash互換性: `${raw,,}`はbash 4.0以降専用の構文で、両hookが元々持つ「bash 4.3未満は部分一致へ縮退する」フォールバックより前に置くと、フォールバックへ到達する前に展開エラーで丸ごと落ちる | major | ブラケット式（`[Cc][Oo][Mm]...`）による大文字小文字非依存の比較に変更（bash 2.0から動作） |
| issue #149との整合性の論理誤り: 「コマンド位置判定は部分一致の部分集合になる」という当初の主張は、正規化による拡張（バックスラッシュ除去・小文字化）を見落としていた | major | 前置フィルタ自体を同じ正規化（バックスラッシュ除去＋大文字小文字非依存）にすることで、#149適用後も超集合であり続けるよう設計を変更。ただし無条件の保証ではなく前提付きの設計判断として明記 |
| 前置フィルタが`main()`内に直書きで、純粋関数として単体テストできない | major | `raw_hints_at_git_commit` / `raw_hints_at_issue_create` という独立した純粋関数へ切り出した |
| 合格条件の自己矛盾（`git -C /x push`を「前置フィルタを通過すべき例」として書いていた） | minor | 計画・テストを「通過すべき例」と「足切りされるべき例」に分けて修正 |
| `raw="$(cat)"`→`read -d ''`の挙動差（末尾改行・NUL）が計画に未記載 | minor | 計画へ追記 |
| 検証コマンドがプレースホルダのままで実行できない・前後の測定手順が無い | minor | 具体的なJSONペイロードと「実装前に測る」手順を計画へ明記 |
| 計画mdにHTMLタグが混入 | minor | 削除 |
| md/HTMLの見出し不一致・内容の同期漏れ | minor | HTMLを全面的に同期 |
| 全体計画のフェーズ2省略理由「自明」が実際には成り立たなかった | minor | 「検証すべき仮説」という表現へ修正 |
| フェーズ4の反映先に spec/command-position.md が入っていなかった | minor | フェーズ4の対象へ追加し、実際に反映した |
| 未マージのPR #157に依存したDDR記述（正が2つになるリスク） | minor | DDRの範囲を本issueが変更する2本のhookに限定する記述にした |

全件の詳細（該当ファイル・行・確度）は敵対的レビュー結果のJSONに記録されている
（本ブランチのコミット履歴に残る。個別作業計画の改訂履歴として要約を記載）。

### 1-2. 作業結果への敵対的レビュー（2回目）による再改訂

上記1回目の改訂を経てcommit直前に、フェーズ3の実装＋フェーズ4の反映をまとめた差分そのもの
（作業結果）へ2回目の敵対的レビューを実施した（commit前の差分に対して実施したため、指摘は
インラインコメントではなくこの会話・レポートへ記録し、直接コード・ドキュメントを修正した）。

| 検出内容 | 深刻度 | 対応 |
|---|---|---|
| **超集合性の破綻（再発）**: `raw_hints_at_git_commit`はjqデコード**前**の生JSON文字列を受け取るが、`${raw//\\/}`はバックスラッシュだけを除去する。実コマンド`git com\<改行>mit`（行継続でCommandPosition.shがブロックする）はJSON化すると`com\\\nmit`（バックスラッシュ3つ＋n）になり、バックスラッシュだけの除去では`n`が残って`comnmit`になり一致しなくなる（実機で反例・end-to-endのブロック解除を確認） | major | JSON文字列エスケープの2文字シーケンス（`\\` `\"` `\n` `\t` `\r` `\/` `\b` `\f`）を丸ごと除去してから残ったバックスラッシュを落とすよう修正。回帰テストを追加 |
| `read -r -d ''`は入力サイズに比例したread(2)回数になる（1バイト単位）ため、大きな`tool_input.command`では削減したexecve/clone以上のシステムコール増加になりうる。execve/clone回数の実測はいずれも60バイト程度の小さいペイロード1件のみで、この特性を測っていなかった | major | 実測不能（git bash実機が無い）ため実装は変更せず、この特性を`.claude/rules/shell-script-style.md`の該当節へ注記し、他hookへの無条件な横展開を防ぐ形で対応（「確かめられなかったこと」参照） |
| 「変更前 execve=6/clone=12」は`lib/CommandPosition.sh`が無い場所で旧実装を測った縮退経路の値で、本番と同じ相対配置では執行前execve=5/clone=10だった | minor | 正しい配置で再測定し、レポート・HANDOFF・DDRの数値を5/10へ訂正 |
| DDR・hookコメントの実測値（execve5/10・7/17）に測定環境（Linux/strace）が添えられておらず、issue本文のgit bash実機値と紛らわしい | minor | DDR「背景」・hookコメントへ測定環境を明記 |
| 新設したルールの実例（`.claude/rules/shell-script-style.md`）が、未マージのPR #157が対象とする2ファイルを指すが、本ブランチには前置フィルタがまだ実装されていない | minor | 実例をこのissueで実際に変更した2本へ限定し、push系2本は「issue #70で対応中（PR #157）」という参照に留めるよう修正 |
| コメント内の行番号参照がその後の編集でずれていた | minor | 行番号ではなく内容（`BASH_VERSINFO`判定・grepフォールバック）で参照するよう修正 |
| テストのコメントが「前置フィルタはmain()内部で関数として呼べない」と書いていたが、実際は純粋関数へ切り出し済みでsourceして直接呼んでいる（切り出し前の記述が残存） | minor | コメントを実装に合わせて修正 |
| `git com\mit`の回帰テストが前置フィルタの戻り値のみで、実際にブロックされる（exit 2）end-to-endのアサーションが無いのに、レポートは「回帰テストで固定した」と記述していた | minor | `run_hook_real`によるexit 2のアサーションを実際に追加 |
| 新規追加したreport/planのmdにYAML frontmatterが無く、`index.jsonl`へ`frontmatter:null`で載っていた | minor | 対象ファイルへfrontmatterを追加 |
| 新規個別反映計画のmd/HTMLで節が一致していない（HTMLに「issueの受け入れ条件との対応」が無い） | minor | HTMLへ同じ節を追加 |
| `HANDOFF.md`のflow-id 3-2が未完了（`[]`）のまま、「現在のループ」欄が`なし`のままだった | minor | `mark-done 3-2`・ループ範囲のヘッダを実態に合わせて更新 |
| レポートmdに`<div class="box ...">`のようなHTMLタグが残っており、同じレポートの指摘一覧が「計画mdへのHTMLタグ混入」を指摘事項として扱っているのと矛盾する | nit | markdown記法へ置き換え |

全件の詳細は敵対的レビュー結果のJSON（このセッションの会話履歴）に記録されている。

**最終的な前置フィルタ（純粋関数、2回目の改訂を反映）**:

```bash
raw_hints_at_git_commit() {
  local raw="$1"
  local probe="$raw"
  probe="${probe//\\\\/}"   # \\ （エスケープされたバックスラッシュ）を最初に処理する
  probe="${probe//\\\"/}"
  probe="${probe//\\n/}"
  probe="${probe//\\t/}"
  probe="${probe//\\r/}"
  probe="${probe//\\\//}"
  probe="${probe//\\b/}"
  probe="${probe//\\f/}"
  probe="${probe//\\/}"     # 残った単独のバックスラッシュ（\uXXXX 等）
  case "$probe" in
    *[Cc][Oo][Mm][Mm][Ii][Tt]*) return 0 ;;
    *) return 1 ;;
  esac
}
```

`post-issue-create-notice.sh`側の`raw_hints_at_issue_create`も同じ設計（CLI経路は上記と同じJSON
エスケープ除去＋大文字小文字非依存、MCP経路は`mcp__github__issue_write`の固定文字列一致）。

判定本体（`command_invokes_git_subcommand` / `is_issue_create_call`）は変更していない。

### 2. 超集合性の確認（改訂後）

**結論**: 前置フィルタが精密判定の超集合であることを、以下の観点で単体テスト・結合テスト
（`test_block_direct_git_commit.sh`, `test_post_issue_create_notice.sh`）に固定した。

- `git -C /x commit`（gitとcommitが非連続）でも前置フィルタを通過し、精密判定まで到達して
  実際にブロックされる（exit 2）。
- `git COMMIT`（大文字）でも前置フィルタを通過する。
- `git com\mit`（バックスラッシュによる語の分割）でも前置フィルタを通過し、実際にブロック
  される（exit 2）——1回目の敵対的レビューで見つかった反例に対する回帰テスト。
- `git com\<改行>mit`（バックスラッシュ+改行の行継続。JSON化すると`\\\n`という3バックスラッシュ
  +nの並びになる）でも前置フィルタを通過し、実際にブロックされる（exit 2）——**2回目（作業結果）
  の敵対的レビューで見つかった反例に対する回帰テスト**。
- `\git commit`（エイリアス迂回の定番書式）でも前置フィルタを通過する。
- `git -C /x push`（commitと無関係。gitとpushが非連続）は前置フィルタで正しく足切りされる
  （jqが呼ばれない）——通過してはいけない例も明示的にテストする。
- `cd /repo && bash .claude/scripts/src/create-issue.sh --title x`（複合コマンド）でも
  前置フィルタを通過する。
- `create-\issue.sh`（バックスラッシュ分割）・`CREATE-ISSUE.SH`（大文字）・
  `create-\<改行>issue.sh`（行継続）でも`raw_hints_at_issue_create`は通過を返す。
- `mcp__github__issue_write`は`method`の値（create/update）に関わらず前置フィルタを通過する
  （method の絞り込みは後段の`is_issue_create_call`が担うため、前置フィルタでは絞らない設計）。

```
$ bash .claude/scripts/test/test_block_direct_git_commit.sh
passed=27 failures=0
$ bash .claude/scripts/test/test_post_issue_create_notice.sh
passed=31 failures=0
$ bash .claude/scripts/test/test_command_position.sh
passed=75 failures=0
```

### 3. jqが1回も呼ばれないことの確認

**結論**: `PATH`の先頭へ「呼ばれたらマーカーファイルへ書いてから失敗するスタブ`jq`」を置き、対象外
ペイロード（例: `git status`, `git -C /x push`, 空入力, `Bash/PowerShell`以外の`tool_name`かつ
commitを含まない等）を実際にhookスクリプトのサブプロセスへ標準入力から渡して確認した。
いずれのケースでもマーカーファイルは空のまま（＝jqが1度も呼ばれない）で、`exit 0`となることを
確認した。時間計測には頼っていない。

### 4. execve/clone回数の実測（strace, Linux）

対象外ペイロード（`{"tool_name":"Bash","tool_input":{"command":"git status"}}`）1件を標準入力
から渡し、`strace -f -c`で集計した（測定環境: Claude Code on the webのリモート実行環境、Linux
x86_64。issue本文のgit bash実機実測とは環境が異なる。下記「確かめられなかったこと」参照）。
修正前（この
コミットより前の実装ファイルを`git show`で取得して測定）・修正後（初版）・最終版（敵対的
レビュー2回の指摘を反映後）の3点を測った。

```
$ printf '%s' "$payload" | strace -f -c -- bash .claude/hooks/block-direct-git-commit.sh 2>&1 >/dev/null
```

**修正前の測定は、`.claude/hooks/lib/`を隣に置いた本番と同じ相対配置で行う必要がある。**
最初の測定でこれを怠り、`lib/CommandPosition.sh`が無い場所に`git show`で取り出した旧
ファイルだけを置いて測っていたため、`source`が失敗して`printf | grep`のフォールバック経路
（+1 execve / +2 clone）が余分に走った値（execve6/clone12）を「変更前」として記録していた
（作業結果への敵対的レビューで検出。issue #159）。`lib/`を正しく配置し直して再測定した値へ
訂正する。

| hook | 変更前 execve | 変更前 clone | 最終版 execve | 最終版 clone |
|---|---|---|---|---|
| `block-direct-git-commit.sh` | 5 | 10 | 1 | 0 |
| `post-issue-create-notice.sh` | 7 | 17 | 1 | 1 |

- `block-direct-git-commit.sh`はexecve/cloneとも0近くまで削減された（execve 1はbash自身の起動）。
- `post-issue-create-notice.sh`のclone=1は、前置フィルタとは無関係な既存の`( main ) || true`
  （実サブシェル。issue #97以前からの既存実装）によるもので、jq起動によるforkは0になった。
- **敵対的レビュー（作業計画・作業結果の2回）で指摘された修正（バックスラッシュ除去・
  ブラケット式への変更、純粋関数への切り出し、JSON文字列エスケープ列の除去）を反映した
  最終版でも、この数値に変化は無い**（パラメータ展開・ブラケット式による`case`はいずれも
  bash組み込みでforkしないため）。
- 訂正後の変更前実測値（execve5/clone10、execve7/clone17）は、issue #159本文のgit bash実機
  実測（execve5/clone10、execve7/clone17）と**数値が一致する**。ただしLinuxとgit bash
  （MSYS）はシステムコールの構成が異なるため、これは同じ実装を指しているという意味での一致
  であり、両環境のシステムコール実装が同一であることを意味しない（偶然の一致として扱う）。

## 確かめられなかったこと

**この結果が言っていないこと**

- git bash（Windows）実機でのexecve/clone実測は行っていない（strace非対応のため）。issue本文の
  実測値は`main`ブランチ側の作業者によるgit bash実機実測であり、本レポートの実測はLinux上での
  相対的な削減効果の参考値にとどまる。
- **`IFS= read -r -d '' raw`は、パイプ入力に対して1バイトずつread(2)する**（bashはパイプから
  区切り文字を越えて読み過ぎないよう、1回のread(2)で1バイトしか読まない仕様のため）。60バイト
  程度の小さいペイロードでは無視できる回数だが、大きな`tool_input.command`
  （ヒアドキュメント等。`.claude/hooks/lib/CommandPosition.sh`が1行8192バイトの上限を持つのも、
  hookが数十KB〜数百KBのコマンド文字列を受け取りうることを前提にしているため）では、
  read(2)の回数が入力バイト数に比例して増える。本レポートのexecve/clone実測はいずれも
  60バイト程度の小さいペイロード1件のみで測っており、**この特性（大きな入力でのread(2)回数
  増加）を測っていない**（作業結果への敵対的レビューで指摘。issue #159）。Linux上の実測では
  200KBのペイロードでも`$(cat)`版とほぼ同じ壁時計（約50ms台）だったが、git bash（MSYS）の
  システムコールコストがLinuxより高いことを踏まえると、大きな入力での実際の遅速はgit bash実機
  でしか確認できない。実装は変更せず（issue #70のpush系hookとの一貫性を優先）、この特性を
  `.claude/rules/shell-script-style.md`の「hookの前置フィルタ」節へ注記し、他hookへ無条件に
  横展開されないようにした。
- 大規模な実運用（多数のBash/PowerShell呼び出しが発生する長時間セッション）での体感速度改善は
  計測していない。
- bash 3.2実機での動作確認は行っていない（手元に無いため）。ブラケット式によるcase比較は
  bash 2.0の仕様上動作するはずだが、実機での確認は「確かめられなかったこと」に留める。
- クォート断片の連結による意図的な文字列分割（例: `git 'com''mit'`）への対応は、精密判定自体が
  対象外としているため本実装も対応しない（スコープ外として明示。「設計への反映」参照）。

## 設計への反映

1. 前置フィルタパターンの意思決定をDDRとして新規作成した:
   `.claude/docs/ddr/i0159-01-hookの前置フィルタは純粋関数によるバックスラッシュ除去と大文字小文字非依存比較で超集合を保つ.md`。
   敵対的レビューで見つかった反例・却下案・issue #149との関係も含めて記録した。
2. `.claude/docs/spec/command-position.md`「利用元」節・「未決定事項・懸念点」節へ、前置フィルタの
   存在とissue #149着手時に再確認すべき点を追記した。
3. `.claude/rules/shell-script-style.md`「外部プロセス起動のコスト」節へ、hook向け前置フィルタ
   パターン（純粋関数への切り出し・超集合の要件・バックスラッシュ除去とブラケット式の理由）を
   一般化した形で追記した（次にこのパターンを使うhookのための再利用可能な記述）。
4. `.claude/docs/spec/issue-mr-workflow.md`は、対象2本のhookをアーキテクチャ概要レベルで
   言及するのみで、内部の判定メカニズムは記述していないため、更新は不要と判断した。

## 残課題

- push系2本のhook（`post-push-usage-report.sh` / `post-push-compact-prompt.sh`）は本issueの
  スコープ外（issue #70/PR #157の範囲）。
- `post-issue-create-notice.sh`の判定本体（`is_issue_create_call`）のコマンド位置判定化は
  issue #149の範囲。本issueの前置フィルタは#149の変更後も超集合であり続ける設計にしたが、
  無条件の保証ではないため、#149が着手する際は再確認が必要（DDR `i0159-01`・spec
  `command-position.md`に明記済み）。flow-id 5-2でissue #149へ通知する。
