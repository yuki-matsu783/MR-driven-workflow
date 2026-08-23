---
title: 【設計】【実装】【テスト】post-issue-create-notice.shのコマンド位置判定化
type: plan
description: issue #149。CommandPosition.shへスクリプト実行判定の公開関数を追加し、post-issue-create-notice.shのCLI経路検知を差し替える個別作業計画
tags: [hook, command-position, issue-149]
keywords: [CommandPosition, command_invokes_script, is_issue_create_call, テスト, 3段ガード]
---

# 【設計】【実装】【テスト】post-issue-create-notice.shのコマンド位置判定化

## 前提（合意状況）

- 上位の計画: `plans/post-issue-notice-command-position.md`（全体作業計画。非対話セッションのため
  flow-id 1-5の人間合意は取れていないが、issue本文・既存実装（issue #147）と矛盾しない内容として
  作成した）

## この計画で何をするか

`.claude/hooks/lib/CommandPosition.sh` へ「任意のスクリプト（basename）がコマンド位置で
実行されるか」を判定する公開関数 `command_invokes_script` を追加し、
`.claude/hooks/post-issue-create-notice.sh` の `is_issue_create_call` のCLI経路判定を
それへ差し替える。あわせて単体テストを追加する。

## 変更対象

| ファイル | 操作 | 何をするか |
|---|---|---|
| `.claude/hooks/lib/CommandPosition.sh` | 変更 | `_cp_scan_tokens_for_script`（内部）と `command_invokes_script`（公開）を追加 |
| `.claude/hooks/post-issue-create-notice.sh` | 変更 | `is_issue_create_call` のCLI経路を新関数へ差し替え、3段ガードを追加 |
| `.claude/scripts/test/test_command_position.sh` | 変更 | `command_invokes_script` の単体テストを追加 |
| `.claude/scripts/test/test_post_issue_create_notice.sh` | 変更 | issue #149の受け入れ条件ケースを追加 |

## 方針

### `command_invokes_script` の設計

既存の `_cp_scan_tokens`（`git <サブコマンド>` 専用）と同じ「正規化済み文字列をトークン走査し、
コマンド位置（`at_cmd`/`sticky`）にあるトークンだけを見る」骨格を再利用しつつ、判定内容を
「basenameが対象スクリプト名と一致するか」に置き換えた専用関数 `_cp_scan_tokens_for_script` を
新設する（`_cp_scan_tokens` 自体は改変しない。gitのグローバルオプション読み飛ばしという
git固有ロジックを持ち、スクリプト名判定には不要なため。既存コードの局所性を保つ方針は
issue #159の前置フィルタでも採られている）。

判定する2形態:

1. **単体実行**: コマンド位置のトークンのbasename（パス・`.exe`を除いた末尾）が、対象スクリプト名
   （例: `create-issue.sh`）と一致する。
2. **インタプリタ経由**: コマンド位置のトークンが `_CP_OPAQUE_WITH_OPT`（`bash`/`sh`等）に該当し、
   その直後の非オプショントークン（コード文字列オプション `-c` 等が無い場合に限る）のbasenameが
   対象スクリプト名と一致する。

`cat` / `grep` のような無関係なコマンドの引数に現れるだけでは、そのコマンド自身がコマンド位置を
消費した時点で `at_cmd` が0になるため、後続の引数はコマンド位置とみなされず判定対象外になる
（既存の `_cp_scan_tokens` と同じ振る舞い）。

```bash
# 概形（実装時に確定させる）
_cp_scan_tokens_for_script() {
  local norm="$1" target="$2"   # target は小文字化済みのbasename
  # セパレータのトークン化・IFS分割は _cp_scan_tokens と同じ前処理
  # ループ: at_cmd/sticky の間だけ判定
  #   base == target -> 一致
  #   base が _CP_OPAQUE_WITH_OPT -> 直後の非オプショントークン（コード文字列オプション除く）を見る
}

command_invokes_script() {
  local s="${1:-}" script="${2:?}"
  [[ -n $s ]] || return 1
  local script_lower="${script,,}"
  if _cp_has_overlong_line "$s"; then
    [[ "${s,,}" == *"$script_lower"* ]] && return 0
    return 1
  fi
  normalize_shell_command_to_reply "$s"
  _cp_scan_tokens_for_script "$REPLY" "$script_lower"
}
```

`normalize_shell_command_to_reply` と `_cp_has_overlong_line`（極端に長い行での部分一致への
縮退）はそのまま再利用する。

### `post-issue-create-notice.sh` の3段ガード

`block-direct-git-commit.sh` の `main()` と同じ形（bashバージョン `4.3` 以上・`source` の成否・
`declare -F` の3点）を `is_issue_create_call` の呼び出し前に置く。ライブラリを使えない場合は
現行の部分一致（`[[ "$command" == *create-issue.sh* ]]`）へ縮退する。

置き換え前（現状）:

```bash
run_shell_command | Bash | PowerShell)
  [[ "$command" == *create-issue.sh* ]]
  ;;
```

置き換え後（イメージ。3段ガードは `is_issue_create_call` を呼ぶ側 = `main()` に置き、
`is_issue_create_call` 自体は判定結果を受け取る形にする想定）:

```bash
# main() 冒頭、is_issue_create_call 呼び出し前
if ((BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 3))) &&
  [ -r "$lib" ] && source "$lib" 2>/dev/null &&
  declare -F command_invokes_script >/dev/null; then
  cli_match() { command_invokes_script "$1" 'create-issue.sh'; }
else
  cli_match() { [[ "$1" == *create-issue.sh* ]]; }
fi
```

`is_issue_create_call` は `cli_match` を呼ぶ形へ変更する（具体的な関数分割は実装時に確定する。
既存のテストが `is_issue_create_call` を直接呼んでいるため、シグネチャ（引数3つ）は変えない）。

### 前置フィルタ（`raw_hints_at_issue_create`）は変更しない

全体作業計画で述べたとおり、既存の前置フィルタは判定本体の超集合であり続ける。実装後に
`test_post_issue_create_notice.sh` の既存ケース（バックスラッシュ分割・大文字小文字混在）が
新しい判定本体に対しても成立することを確認する（テストケースの追加は不要、既存ケースの
再確認のみ）。

## やらないこと（スコープ外）

- MCP経路の判定変更（判断は全体作業計画へ送った）
- 他の3本のhookへの変更
- `.claude/settings.json` の `if` フィルタ変更

## 検証

```bash
bash -n .claude/hooks/lib/CommandPosition.sh
bash -n .claude/hooks/post-issue-create-notice.sh
bash .claude/scripts/test/test_command_position.sh
bash .claude/scripts/test/test_post_issue_create_notice.sh
```

合格条件: 上記4コマンドがすべてエラー無く終わり、2本のテストスクリプトが追加ケースを
含めて `passed=N failures=0` を出すこと。

## issueの受け入れ条件との対応

| 受け入れ条件 | この計画での対応箇所 |
|---|---|
| 発火しないこと（cat/grep/ドキュメント編集、コメント内、ヒアドキュメント本文内） | `test_command_position.sh` + `test_post_issue_create_notice.sh` へ追加 |
| 発火すること（単体実行、`cd … && …`、改行区切り2行目、`bash <パス>`） | 同上 |
| CommandPosition.shを再利用し公開関数を足す | `command_invokes_script` |
| 3段ガードでの縮退 | `post-issue-create-notice.sh` の `main()` |
| test_post_issue_create_notice.sh全件failures=0 | 実施・確認 |
| spec更新 | 個別反映計画（flow-id 4-1）で扱う |
