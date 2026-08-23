# worklog: 【設計】【実装】【テスト】post-issue-create-notice.shのコマンド位置判定化（push3）

対象: issue #149 post-issue-create-notice.shの検知をコマンド位置ベースにして誤検知を減らす（2026-08-23）。
全体作業計画: `plans/post-issue-notice-command-position.md`
個別作業計画: `plans/【設計】【実装】【テスト】post-issue-create-noticeコマンド位置判定化.md`
push回数: 5

## 試したこと

敵対的レビュー（フェーズ3・2回目/最大3回。実装レビュー）で8件の指摘（major 3件・minor 4件・
nit 1件）を受け、実機で再現確認したうえですべて実装へ反映した。

1. **major: prefix語が値を取るオプションを持つと値を実コマンドと誤認する**（`timeout 60 bash
   <path>` 等が誤ってmissになる）。`_CP_PREFIX_OPTS_WITH_VALUE`（sudo/env/nice/ionice/timeout/
   stdbuf等が使う値取りオプションの集合）を追加し、prefix語の前方走査でオプションと一致したら
   値トークンもあわせて読み飛ばすよう変更した。加えて `timeout DURATION COMMAND` の語順に対応する
   `_CP_PREFIX_WORDS_WITH_LEADING_VALUE`（`timeout`のみ）を追加し、オプション読み飛ばし後の
   最初の非オプション引数（= 値）をさらに1つ読み飛ばす。実機確認: `timeout 60 bash <path>
   --title x` / `sudo -u alice bash <path>` / `nice -n 10 bash <path>` がいずれも意図どおり
   hitになった。対になる `timeout 5 grep -rn x <path>`（miss）も維持されていることを確認した。
2. **major: クォート付きパスが検知できず、旧実装（部分一致）に対する機能後退になっている**
   （`bash "$VAR/create-issue.sh"` 等）。インタプリタ経由（`_CP_OPAQUE_WITH_OPT`）の直後の
   引数トークンが、正規化でプレースホルダ`_`へ潰れている場合に限り、`_CP_OPAQUE_FOUND`を立てて
   保守的フォールバック（部分一致）の対象にするよう変更した。実機確認:
   `bash "$CLAUDE_PROJECT_DIR/.claude/scripts/src/create-issue.sh" --title x` がhitになり、
   無関係なクォート付き引数（`bash "$VAR/unrelated.sh"`）はmissのままであることを確認した。
3. **major: トップレベルでのsourceが前置フィルタより前に毎回走り、issue #159の最適化を一部
   戻している**（+35%/+1.0ms、実測）。`_pin_cli_match`をトップレベルで「関数として存在」させつつ、
   実際の初期化（バージョン確認・source・`declare -F`）は初回呼び出し時に遅延させ、自分自身を
   確定版へ再定義してから委譲する形に変更した。`source`のみでmain()を実行しない既存テスト
   （4件）が引き続き通ることで、トップレベルからの直接呼び出しでも正しく動作することを確認した。
4. **minor: `bash -n <script>`（構文チェックのみ、実行しない）を実行とみなして誤検知する**。
   `_CP_SHELL_INTERPRETERS`（bash/sh/zsh/ksh/dash/busybox）限定で`_CP_NONEXEC_OPTS`（`-n`）を
   持つ場合は検知対象から外すよう変更した。python/perl/ruby等は`-n`の意味が異なる
   （実行はする）ため対象に含めていない。実機確認: `bash -n <path>` / `sh -n <path>` がmissに
   なり、`bash -n -c "..."` はコードオプション`-c`が優先されhitのままであることを確認した。
5. **minor: target一致の判定が変数代入の判定より前にあり、`SCRIPT=<path>/create-issue.sh`
   （代入）を実行と誤認する**。判定順序を入れ替え、変数代入チェックを先に行うよう修正した。
6. **minor: ヘッダコメントの「見逃しだけ」という記述が実装と食い違う**（opaque語フォールバックに
   よる過検知が実際に残る）。`post-issue-create-notice.sh`のヘッダコメントを、クォートパスの
   扱い変更（上記2）とあわせて書き直し、`find . -name create-issue.sh`のような過検知が残ることを
   明記した。回帰テストとして `test_command_position.sh` へ固定した。
7. **minor: 3段ガードのフォールバック経路（ライブラリ非存在時）を検証するテストが無い**。
   `test_post_issue_create_notice.sh`へ、hookのみを`lib/`無しの一時ディレクトリへコピーして
   サブプロセス起動し、部分一致への縮退が実際に機能することを確認するテストを追加した。
8. **nit: 新規テスト名が既存の git 側ケースと重複している**。「上限超えの行が…」の2件を
   「script判定: 」接頭辞付きへ改名した。

## うまくいったこと

- 8件すべてを実機再現のうえ修正し、`bash -n`構文チェック・3つの単体テストスイート
  （`test_command_position.sh` 118件、`test_post_issue_create_notice.sh` 38件、
  `test_block_direct_git_commit.sh` 27件・共有ライブラリの回帰確認）すべて`failures=0`。
- `git diff <ブランチ分岐点>` で、既存のgit専用関数（`_cp_scan_tokens`・
  `command_invokes_git_subcommand`）がbyte-identicalであることを確認した（純粋な追加・
  `_cp_scan_tokens_for_script`内部の修正に限定されている）。

## ダメだったこと

- 特になし。

## 次の一歩

- flow-id 3-7: commit・push してレビュー依頼を行う。
- push後、フェーズ3の敵対的レビューは既に2回実施済み（最大3回）。3回目を追加で回すかは、
  今回の修正規模を踏まえて判断する（軽微な追加のみであれば3回目は見送り、フェーズ4へ進む）。
- フェーズ4（反映）へ進み、spec更新（`command-position.md`4箇所・`issue-mr-workflow.md`）を行う。

---
