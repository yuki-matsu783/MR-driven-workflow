# worklog: 【設計】【実装】【テスト】post-issue-create-notice.shのコマンド位置判定化

対象: issue #149 post-issue-create-notice.shの検知をコマンド位置ベースにして誤検知を減らす（2026-08-23）。
全体作業計画: `plans/post-issue-notice-command-position.md`
個別作業計画: `plans/【設計】【実装】【テスト】post-issue-create-noticeコマンド位置判定化.md`
push回数: 2

## 試したこと

- issue #147（block-direct-git-commit.shのコマンド位置化）の実装（`.claude/hooks/lib/CommandPosition.sh`
  の`_cp_scan_tokens`・`command_invokes_git_subcommand`、`block-direct-git-commit.sh`の3段ガード）を
  読み、そのまま流用できる部分（`normalize_shell_command_to_reply`・`_cp_has_overlong_line`）と、
  新規に書く必要がある部分（スクリプトbasenameの走査ロジック）を切り分けた。
- `_cp_scan_tokens`をそのまま汎用化して共有する案を検討したが、gitのグローバルオプション読み飛ばし
  ロジックが不要な差分として残るため、専用関数`_cp_scan_tokens_for_script`を新設する方針にした
  （計画の「比較検討した案」参照）。

## うまくいったこと

- （このpushは計画作成まで。実装はこの後のpushで記録する）

## ダメだったこと

- 特になし。

## 次の一歩

- `command_invokes_script`と`_cp_scan_tokens_for_script`を実装する。
- `post-issue-create-notice.sh`の3段ガードを実装する。
- 単体テストを追加する（`test_command_position.sh`・`test_post_issue_create_notice.sh`）。

---
