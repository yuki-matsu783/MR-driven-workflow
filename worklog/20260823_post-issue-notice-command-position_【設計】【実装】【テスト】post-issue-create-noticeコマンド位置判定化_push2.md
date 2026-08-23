# worklog: 【設計】【実装】【テスト】post-issue-create-notice.shのコマンド位置判定化（push2）

対象: issue #149 post-issue-create-notice.shの検知をコマンド位置ベースにして誤検知を減らす（2026-08-23）。
全体作業計画: `plans/post-issue-notice-command-position.md`
個別作業計画: `plans/【設計】【実装】【テスト】post-issue-create-noticeコマンド位置判定化.md`
push回数: 4

## 試したこと

- 敵対的レビュー（1回目・計画レビュー）で8件の指摘を受けた。うち major 4件（sticky未解除・
  保守的フォールバック欠落・クォートパス・PowerShellバックスラッシュパス）、minor 5件
  （cli_matchのスコープ・lib_dir欠落・引数契約・回帰テスト不足・spec反映先不足・ヘッダ
  コメント不整合・HTML同期漏れ）。計画を改訂し、修正方針を「敵対的レビュー（1回目）を踏まえた
  設計改訂」節へ記録した。
- `_cp_scan_tokens_for_script` を実装し、実データで手動検証した:
  - `sudo cat <path>` / `if grep -q x <path>; then...` / `timeout 5 grep -rn x <path>` は
    いずれも改訂前の試作コードでは誤って発火した（sticky未解除）。実装ではprefix word通過後
    「次の非オプション・非代入トークンを1回だけ実コマンドとして判定」する形に変更し、いずれも
    miss になることを確認した。
  - `cat ${REPO}/.claude/scripts/src/create-issue.sh` も同様に誤って発火していた
    （`{`/`}`のトークン化で`}`直後がコマンド位置扱いになるため）。`{`/`}`を人工的な空白挿入
    の対象から除外することで解消した（ブレースグループ`{ cmd; }`は素の空白分割で判定できる
    ことを確認済み。既存の`_cp_scan_tokens`（git専用）は変更していないため影響なし）。
  - `eval "bash <path>"` / `bash -c "bash <path>"` は、`_CP_OPAQUE_FOUND`フォールバックを
    `command_invokes_git_subcommand`と同じ設計で追加し、hitになることを確認した。
- `sudo -u alice bash <path>`（オプションが値を取る場合）は依然miss。既知の限界として受容し、
  計画へは明記していないが軽微な既知の不整合として記録する（issueの受け入れ条件には無い）。
- `post-issue-create-notice.sh`の3段ガードをトップレベルへ移した。既存の
  `test_post_issue_create_notice.sh`（sourceして`main()`を実行せず直接`is_issue_create_call`を
  呼ぶ）が31件全通過することで、`main()`実行前でも判定が完成していることを確認した。

## うまくいったこと

- `bash -n` 構文チェック、`test_command_position.sh`（108件）、`test_post_issue_create_notice.sh`
  （36件）、`test_block_direct_git_commit.sh`（27件・共有ライブラリの回帰確認）すべて
  `failures=0`。
- `git diff <ブランチ分岐点> -- .claude/hooks/lib/CommandPosition.sh` で削除行が無いことを確認し、
  既存関数（`_cp_scan_tokens`・`command_invokes_git_subcommand`等）を変更していないことを
  機械的に確認した。

## ダメだったこと

- 特になし。

## 次の一歩

- 敵対的レビュー（実装レビュー・2回目/最大3回）をバックグラウンドで起動した。結果を確認し、
  指摘があれば修正する。
- フェーズ4（反映）へ進み、spec更新（`command-position.md`4箇所・`issue-mr-workflow.md`）を行う。

---
