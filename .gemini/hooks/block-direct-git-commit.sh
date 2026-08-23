#!/usr/bin/env bash
#
# Claude Code PreToolUse hook（`git commit`の直接実行をブロック、issue #39）。
# 設計: issue #39 →
#       .claude/docs/ddr/i0000-09-コミットはcommitスキル経由を機構的に強制する.md
#
# 目的: すべてのコミットを `.claude/skills/commit/SKILL.md`（`commit`スキル）経由で行わせる
# （issue #39の受け入れ条件）。ドキュメント上のルールだけではエージェントの遵守に依存するため、
# Bash/PowerShellツールのコマンド文字列が gitのコミットを**実行する**場合を機構的にブロックする。
#
# .claude/settings.json 側で matcher: "Bash|PowerShell" として広く受け、本スクリプト側で
# command 文字列を正規表現でチェックする（既存の post-push-usage-report.sh と同じ設計。
# `permissions.deny` の prefix マッチだけでは `cd src && git commit -m "fix"` のような
# 複合コマンドをすり抜けてしまうため、hook側でも実文字列を検査する）。
#
# commitスキル自身は `.claude/scripts/src/create-commit.sh` というラッパー経由でコミットするため、
# 呼び出し文字列にgitのコミット呼び出しが現れず、本hookには引っかからない
# （ラッパー内部で `git commit` を実行すること自体は問題ない。本hookが検査するのは
# Bash/PowerShellツールへの「呼び出し文字列」のみで、その呼び出しが実行するスクリプトの
# 内部処理までは見ていないため）。
#
# 判定は .claude/hooks/lib/CommandPosition.sh の command_invokes_git_subcommand が行う
# （issue #53）。以前は部分文字列マッチだったため、ヒアドキュメント本文・クォート内・
# コメント・日本語の地の文に該当語が含まれるだけで誤ってブロックしていた。現在は
# コマンドとして実行される位置にある場合だけブロックする。
#
# 既知のトレードオフ: 意図的な文字列分割等による回避への対策は行わない（安全境界ではなく、
# 既定動作を確実な方向へ倒すための仕組み）。逆に、文字列をコードとして受け取る実行系
# （`eval` / `bash -c` / `xargs` / `find` 等）が混ざる場合は、位置判定で一致しなくても
# 従来どおりの部分一致でブロックする（素通りを増やさないため）。詳細は
# .claude/docs/spec/command-position.md。
#
# 本hookには if フィールドが無く、Bash/PowerShellの全呼び出しで起動する（issue #159）。
# 空振り（commitと無関係なコマンド）でも `$(cat)` と `printf | jq` を経由すると
# execve 5 / clone 10 に達する（strace実測。2026-08-22）。判定本体
# （command_invokes_git_subcommand）へ渡す前に、bash組み込みだけで足切りする
# （issue #70 のpush系hook2本と同じパターン。詳細: .claude/docs/ddr/i0159-01-hookの前置フィルタは純粋関数によるバックスラッシュ除去と大文字小文字非依存比較で超集合を保つ.md）。

set -uo pipefail

# 生入力（hookへのJSON文字列そのもの。jqでパースする前）に「commit」という語が現れうるかを
# 判定する純粋関数（外部コマンドを呼ばずforkしない）。command_invokes_git_subcommand の
# **超集合**であるための前置フィルタ（issue #159）。$1=stdin全体
# 戻り: 0 = 判定本体へ進む可能性がある（通過）/ 1 = commitと無関係と確定（足切りしてよい）
#
# 精密判定（CommandPosition.sh）はエスケープ・大文字小文字を正規化してから比較するため、
# ここでも同じ正規化を先に施さないと超集合が壊れる（敵対的レビューで実際に反例が出た。
# `git com\mit` は精密判定ではブロックされるが、単純な `*commit*` 部分一致では
# 素通りしていた）。
#
# **バックスラッシュだけを除去する初版には、さらに別の反例があった**（作業結果への敵対的
# レビューで検出。issue #159）。この関数が受け取る $1 は jq でデコードする**前**の生JSON
# 文字列であり、実コマンド中の1文字（改行・タブ等）は、JSONエンコードされると2文字の
# エスケープ列（`\n` `\t` 等）になる。バックスラッシュだけを消すと、そのエスケープ列の
# 2文字目（`n`や`t`）が単独の文字として残ってしまう。実例: 実コマンド
# `git com\<改行>mit -m "x"`（バックスラッシュ＋改行の行継続。CommandPosition.shはこれを
# 結合して「commit」と判定しブロックする）はJSON化すると `com\\\nmit`（バックスラッシュ3つ＋n）
# になる。単純にバックスラッシュだけを除去すると `comnmit` が残り、`*commit*` に一致しなく
# なる（＝ブロックが素通りする）。対策として、JSON文字列エスケープの2文字シーケンス
# （`\\` `\"` `\n` `\t` `\r` `\/` `\b` `\f`）は**2文字とも**まとめて除去してから、残った
# バックスラッシュ（`\uXXXX` 等）を落とす。`\\`（エスケープされたバックスラッシュ）を最初に
# 処理するのは、`\\n`（エスケープされたバックスラッシュ＋素のn）を`\n`（改行のエスケープ）と
# 誤って分解しないため。いずれの除去も単調にマッチ候補を増やすだけで、既存のマッチを
# 壊さない（forkしない）。
raw_hints_at_git_commit() {
  local raw="$1"
  local probe="$raw"
  probe="${probe//\\\\/}"
  probe="${probe//\\\"/}"
  probe="${probe//\\n/}"
  probe="${probe//\\t/}"
  probe="${probe//\\r/}"
  probe="${probe//\\\//}"
  probe="${probe//\\b/}"
  probe="${probe//\\f/}"
  probe="${probe//\\/}"
  # bash 3.2でも動く大文字小文字非依存の比較。`${var,,}`（bash 4.0以降）は使わない
  # ——本hookは4.3未満のbashも動作対象とし、その場合は後段（BASH_VERSINFOによるバージョン
  # 判定・source失敗時のgrepフォールバック）で部分一致へ縮退する設計だが、`${var,,}` を
  # ここで使うと縮退より前に展開エラーで丸ごと落ちる。
  case "$probe" in
    *[Cc][Oo][Mm][Mm][Ii][Tt]*) return 0 ;;
    *) return 1 ;;
  esac
}

main() {
  set -euo pipefail

  # 前置フィルタ（issue #159）。`read` も raw_hints_at_git_commit の中身
  # （`${raw//\\/}` とcase）もbash組み込みだけで、forkしない
  # （実測で空関数と同じ execve 1 / clone 0）。
  local raw
  # `|| true` を省かない。`read -d ''` は入力にNULが無いとEOFで非0を返すため、`set -e` 配下では
  # 値が取れているのに終了する。
  IFS= read -r -d '' raw || true
  [ -n "$raw" ] || exit 0
  raw_hints_at_git_commit "$raw" || exit 0

  local hook_input
  hook_input="$(printf '%s' "$raw" | jq -c '.' 2>/dev/null)" || exit 0
  [ -n "$hook_input" ] || exit 0

  local tool_name
  tool_name="$(printf '%s' "$hook_input" | jq -r '.tool_name // empty')"
  if [ "$tool_name" != "Bash" ] && [ "$tool_name" != "PowerShell" ]; then
    exit 0
  fi

  local command
  command="$(printf '%s' "$hook_input" | jq -r '.tool_input.command // empty')"
  [ -n "$command" ] || exit 0

  # 判定は .claude/hooks/lib/CommandPosition.sh へ委譲する（issue #53）。
  # ライブラリを使えない場合だけ、従来どおりの部分一致で安全側へ倒す
  # （検知そのものが無効になるより、誤検知が残るほうがまし）。
  local lib_dir="${BASH_SOURCE[0]%/*}"
  # パスにディレクトリ成分が無い（`bash block-direct-git-commit.sh` のような起動）と
  # `%/*` はファイル名をそのまま返すため、明示的にカレントへ倒す。
  [ "$lib_dir" = "${BASH_SOURCE[0]}" ] && lib_dir='.'
  local lib="${lib_dir}/lib/CommandPosition.sh"

  # `[ -r ]` だけでは「読めるが読み込みに失敗する」（壊れたファイル・bash 4.3未満）を
  # 拾えない。`set -e` 配下では source の失敗がそのまま終了コード2になり、gitと無関係な
  # コマンドまでブロックされてしまうため、バージョン・source の成否・関数の存在まで確かめる。
  local blocked=1
  # shellcheck source=lib/CommandPosition.sh
  if ((BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 3))) &&
    [ -r "$lib" ] && source "$lib" 2>/dev/null &&
    declare -F command_invokes_git_subcommand >/dev/null; then
    if command_invokes_git_subcommand "$command" commit; then
      blocked=0
    fi
  elif printf '%s' "$command" | grep -qiE 'git[[:space:]]+commit'; then
    blocked=0
  fi

  if [ "$blocked" = 0 ]; then
    echo "git commit の直接実行はブロックされています。commit スキル（.claude/skills/commit/SKILL.md）経由で、.claude/scripts/src/create-commit.sh を使ってコミットしてください。" >&2
    exit 2
  fi

  exit 0
}

# `source` されたときは関数定義のみを読み込ませ、`main` を実行しない（issue #57）。
# `main` は冒頭で標準入力を読む（`IFS= read -r -d '' raw`）ため、ガードが無いとテストから
# `source` した時点でstdin待ちのままハングする。
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main
fi
