# hookの空振り起動コストを前置フィルタで削減する（issue #159）

## 前提

- 対象は `.claude/hooks/block-direct-git-commit.sh`（PreToolUse）と
  `.claude/hooks/post-issue-create-notice.sh`（PostToolUse）の2本。
  どちらも `.claude/settings.json` に `if` フィールドを持たず、Claude Codeでも
  Bash/PowerShell（後者はさらに `mcp__github__issue_write`）の**全呼び出しで起動する**。
- issue #159 の実測（2026-08-22, strace）: 空振り1回あたり
  `block-direct-git-commit.sh` = execve 5 / clone 10、`post-issue-create-notice.sh` =
  execve 7 / clone 17。原因は判定材料の取り出し（`raw="$(cat)"` と `printf | jq` の連鎖）で、
  判定本体（`command_invokes_git_subcommand` / `is_issue_create_call`）へ辿り着く前に
  このコストが掛かっている。
- **同じ問題を issue #70（PR #157、未マージ）が push系hook2本
  （`post-push-usage-report.sh` / `post-push-compact-prompt.sh`）で解決済み**。
  `main()` 冒頭を `IFS= read -r -d '' raw || true` + `case "$raw" in *push*) ;; *) exit 0 ;; esac`
  へ置き換えるパターンで、`read`/`case` がbash組み込みでforkしないことを利用している
  （PR #157 diffで確認済み）。issue #159 はこのパターンを残り2本へ適用する切り出し。
- issue #149（起票済み・未着手）は `post-issue-create-notice.sh` の判定本体を
  部分一致からコマンド位置判定へ差し替える別issue。**同じファイルを触るため、前置フィルタは
  #149 が入った後の新しい判定に対しても超集合であること**が受け入れ条件に明記されている。

## この計画で何をするか

- 2本のhookの `main()` 冒頭に、判定本体（jq呼び出しを含む）へ入る前の前置フィルタを追加し、
  対象外のペイロードで `jq` が1回も呼ばれないようにする。
- 判定本体（`command_invokes_git_subcommand` / `is_issue_create_call`）は変更しない。
- 前置フィルタのパターンが精密判定の**超集合**であることをテストで固定する。

## 全体の変更対象（ファイル群）

- `.claude/hooks/block-direct-git-commit.sh`（前置フィルタ追加）
- `.claude/hooks/post-issue-create-notice.sh`（前置フィルタ追加）
- `.claude/scripts/test/`（前置フィルタの単体テストを新規追加・既存テストへの追記）
- `.claude/docs/ddr/`（前置フィルタパターンの意思決定記録を新規作成）
- `.claude/rules/shell-script-style.md`（「外部プロセス起動のコスト」節へ、hook向けの
  前置フィルタパターンを簡潔に追記するか検討。実施要否はフェーズ4で確定する）

## フェーズ2〈調査〉

**実施しない。** 理由:

- 対象hookの現状（`if` を持たないこと・空振り時のjq呼び出し回数）はissue本文の実測値と、
  実際のスクリプト読解で既に確定している。
- 適用すべきパターンは issue #70（PR #157）が既に実装・実測済みで、diffを直接参照できる
  （「前提」節に記載）。新規に何かを調べる必要が無い。
- 精密判定のロジック（`CommandPosition.sh` / `is_issue_create_call`）も既存実装として
  読解済みで、前置フィルタが超集合になるための条件は自明に導ける。

## フェーズ4〈反映〉

- **設計反映**: 前置フィルタパターンの意思決定（なぜ`if`を変更せずスクリプト内で足切りするか、
  なぜ超集合を要求するか、既知のトレードオフ）をDDRとして新規作成する
  （`.claude/docs/ddr/i0159-01-....md`）。issue #70 がまだDDRを持たないため、本DDRが
  このパターンの正式な記録の初出になる。
- **AIアセット反映**: 作業中に、前置フィルタの一般的な書き方（read+caseの型・超集合の要件・
  `${raw,,}`で大文字小文字を吸収する判断基準）を再利用できる形で記述する価値があるか確認し、
  価値があれば `.claude/rules/shell-script-style.md`「外部プロセス起動のコスト」節へ簡潔に追記する。
- **実装反映**: 該当なし（フェーズ3のレビュー往復で解消しきれなかった不具合が出た場合のみ）。

## やらないこと（スコープ外）

- `post-push-usage-report.sh` / `post-push-compact-prompt.sh` への同パターン適用（issue #70の
  範囲。#159は明示的にそこから切り出されている）。
- `post-issue-create-notice.sh` の判定本体（`is_issue_create_call`）をコマンド位置判定へ
  差し替えること（issue #149の範囲）。
- `.claude/settings.json` の `if` フィールドの追加・変更（同ファイルの`if`照合規則は
  issue #47が両論併記のまま残しており、本issueでも触らない）。

## 検証

- `.claude/scripts/test/test_command_position.sh` が既存どおり `failures=0`。
- `.claude/scripts/test/test_post_issue_create_notice.sh` が新規ケースを含め `failures=0`。
- 新規作成する前置フィルタの単体テストが `failures=0`。
- `PATH` 先頭に「呼ばれたら失敗するスタブ `jq`」を置き、対象外ペイロードで実際にhookプロセスを
  起動して、スタブが1度も呼ばれないことを確認する。
- 変更前後で `strace -f -c` 相当の実測（execve/clone回数）を記録に残す
  （Linux上で実行するため、git bash実機の95ms/回という数値そのものは参考値として扱う）。

## issueの受け入れ条件との対応

| 受け入れ条件 | この計画での対応箇所 |
|---|---|
| 2本の`main()`冒頭を`read -d ''`+`case`による足切りへ置き換える | フェーズ3個別計画「変更対象」 |
| `\|\| true`を省かない | フェーズ3個別計画「方針」 |
| パターンが超集合であることをテストで固定。`git -C /x push`のように語が連続しない形を含む | フェーズ3個別計画「検証」 |
| 足切りされるペイロードでjqが1回も呼ばれないことをスタブjqで検証 | フェーズ3個別計画「検証」 |
| issue #149と同じファイルを触る。前置フィルタは新しい判定の超集合であること | 「前提」節・DDR（フェーズ4） |
| 前後のexecve/cloneの実測値を記録に残す | フェーズ3個別計画・報告（reports/） |
