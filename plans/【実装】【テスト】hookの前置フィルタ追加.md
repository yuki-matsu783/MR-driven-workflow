# 【実装】【テスト】hookの前置フィルタ追加

## 前提

- 上位の計画: `plans/reduce-hook-misfire-cost.md`（全体作業計画。flow-id 1-4）
- フェーズ2〈調査〉は実施しない（上位計画に理由を記載済み）。本計画は調査結果ではなく
  上位計画・issue #159本文・既存実装の読解のみに基づく。

## この計画で何をするか

`block-direct-git-commit.sh` と `post-issue-create-notice.sh` の `main()` 冒頭へ、
判定本体（jq呼び出しを含む）へ入る前の前置フィルタを追加し、対象外ペイロードで `jq` を
1回も呼ばないようにする。あわせて、前置フィルタが精密判定の超集合であることを固定する
単体テストを追加する。

## 変更対象

| ファイル | 操作 | 何をするか |
|---|---|---|
| `.claude/hooks/block-direct-git-commit.sh` | 変更 | `main()`冒頭の`raw="$(cat)"`を`IFS= read -r -d '' raw \|\| true`に、`[ -n "$raw" ] \|\| exit 0`の直後に`case "${raw,,}" in *commit*) ;; *) exit 0 ;; esac`を追加。ヘッダコメントへissue #159の説明を追記 |
| `.claude/hooks/post-issue-create-notice.sh` | 変更 | 同様に`main()`冒頭を`IFS= read -r -d '' raw \|\| true`へ、直後に`case "$raw" in *create-issue.sh*\|*mcp__github__issue_write*) ;; *) exit 0 ;; esac`を追加。ヘッダコメントへissue #159の説明を追記 |
| `.claude/scripts/test/test_block_direct_git_commit.sh` | 新規 | 前置フィルタの単体テスト（純粋ロジック部分）とスタブjqを使った結合テスト |
| `.claude/scripts/test/test_post_issue_create_notice.sh` | 変更 | 前置フィルタのテストケースを追記（既存の`is_issue_create_call`テストは変更しない） |

## 方針

### 前置フィルタの実装

issue #70（PR #157）で確立済みの型をそのまま踏襲する。

```bash
local raw
# `|| true` を省かない。`read -d ''` は入力にNULが無いとEOFで非0を返すため、
# `set -e` 配下では値が取れているのに終了する。
IFS= read -r -d '' raw || true
[ -n "$raw" ] || exit 0
case "<比較対象>" in
  <パターン>) ;;
  *) exit 0 ;;
esac
```

- `read`・`case`・`${raw,,}`はいずれもbash組み込みで、forkしない
  （`.claude/rules/shell-script-style.md`「外部プロセス起動のコスト」）。
- 判定本体は変更しない。前置フィルタは高速な足切りであり、正しさの根拠は従来どおり後段が持つ。

### block-direct-git-commit.sh: 超集合の設計

精密判定（`command_invokes_git_subcommand`, `.claude/hooks/lib/CommandPosition.sh`）は
以下の性質を持つ。

- コマンド全体を`${s,,}`で小文字化してから走査・比較する（`_cp_scan_tokens`の`${tokens[i],,}`、
  フォールバックの`${lower}`）。つまり `git COMMIT` のような大文字混じりも検知対象になりうる。
- `git`と`commit`が隣接している必要はない（`git -C /x commit`のようにオプションを挟める）。
- クォート除去・バックスラッシュエスケープの解決を経ても、マッチには最終的に文字列上
  どこかに「commit」という並びが（大文字小文字はどちらでも）残る
  （クォートで囲われた断片同士を連結して「commit」を合成する意図的な文字列分割への対応は、
  精密判定自体が対象外としている。`.claude/docs/ddr/i0000-09-....md`）。

よって前置フィルタは **`${raw,,}`で小文字化した上で`*commit*`を含むか** を見れば十分な超集合になる。
`raw`はhookへのJSON入力全体（`tool_input.command`だけでなく`tool_name`等も含む）であり、
`command`フィールド以外に偶然「commit」を含むケースも当然マッチするが、これは無害な過剰検知
であり後段のjq処理へ回るだけで実害はない。

### post-issue-create-notice.sh: 超集合の設計

精密判定（`is_issue_create_call`）は2経路。

- CLI経路: `tool_name`がBash/PowerShell/run_shell_commandで、`command`に`create-issue.sh`を
  **大文字小文字を区別する完全部分一致**で含む（`[[ "$command" == *create-issue.sh* ]]`）。
- MCP経路: `tool_name`が`mcp__github__issue_write`で、`method`が`create`。

前置フィルタは以下のいずれかを含むかで判定する（大文字小文字を吸収する必要は無い。精密判定自体が
大文字小文字を区別するため、小文字化すると精密判定より広い意味で超集合になるが、
過剰検知が増えるだけで実害は無い。ただし精密判定と表記を合わせ、意図を読みやすくするために
**小文字化はしない**）。

- `create-issue.sh`（CLI経路の超集合。`command`以外のフィールドに含まれていても無害な過剰検知）
- `mcp__github__issue_write`（MCP経路の超集合。`method`の値までは見ない——`method`が
  `create`以外でも前置フィルタは通過するが、後段の`is_issue_create_call`が正しく`create`のみへ
  絞り込む。前置フィルタは「足切り」であって「精密化」ではないため、`method`の値まで狭める必要は無い）

**issue #149との整合性**: #149は`is_issue_create_call`のCLI経路判定を、部分一致から
`.claude/hooks/lib/CommandPosition.sh`ベースのコマンド位置判定へ差し替える計画（未着手）。
コマンド位置判定は部分一致の対象を「コマンド位置にあるもの」へ**絞り込む**方向の変更であり、
マッチする集合は現状の部分一致の**部分集合**になる。前置フィルタ（`*create-issue.sh*`という
部分一致での超集合）は、#149適用後の狭められた判定に対しても引き続き超集合であり続ける
（絞り込まれた判定が拾う入力は、絞り込む前の部分一致でも必ず拾えるため）。したがって
本計画の前置フィルタは#149の着手順に関わらずそのまま有効であり、#149側での変更は不要になる。
この関係はDDR（フェーズ4）に明記し、#149へも通知する（flow-id 5-2）。

## やらないこと（スコープ外）

<div class="box stop">この計画では決めない・触らない</div>

- `is_issue_create_call` / `command_invokes_git_subcommand` の判定ロジック自体の変更
  （issue #149の範囲、または対象外）。
- `.claude/settings.json` の `if` フィールドの追加。
- push系2本のhook（issue #70の範囲）。

## 検証

```bash
bash -n .claude/hooks/block-direct-git-commit.sh
bash -n .claude/hooks/post-issue-create-notice.sh
bash .claude/scripts/test/test_command_position.sh
bash .claude/scripts/test/test_post_issue_create_notice.sh
bash .claude/scripts/test/test_block_direct_git_commit.sh

# スタブjqで「対象外ペイロードでjqが1回も呼ばれない」ことを確認（時間計測に頼らない）
# 上記2つの新規/追記テストの中で実施する

# 実測（Linux上での参考値。git bash実機の値そのものではない）
strace -f -c -- bash .claude/hooks/block-direct-git-commit.sh <<<'<対象外ペイロード>' 2>&1 | tail -20
```

合格条件: 全テスト `failures=0`。スタブjqが対象外ペイロードで1度も呼ばれない。
`git -C /x commit`・`git -C /x push`型（語が非連続）や大文字混じりでも、前置フィルタを
通過して精密判定まで到達し、精密判定どおりの結果（block/notice）になる。

## issueの受け入れ条件との対応

| 受け入れ条件 | この計画での対応箇所 |
|---|---|
| 2本の`main()`冒頭を`read -d ''`+`case`による足切りへ置き換える | 「変更対象」表 |
| `\|\| true`を省かない | 「方針」の実装コードブロック |
| パターンが超集合であることをテストで固定。`git -C /x push`のように語が連続しない形を含む | 「検証」 |
| 足切りされるペイロードでjqが1回も呼ばれないことをスタブjqで検証 | 「検証」 |
| issue #149と同じファイルを触る。前置フィルタは新しい判定の超集合であること | 「post-issue-create-notice.sh: 超集合の設計」 |
| 前後のexecve/cloneの実測値を記録に残す | 「検証」→`reports/`へ記録 |
