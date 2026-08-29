#!/usr/bin/env bash
#
# Claude Code PostToolUse hook（次回push分のチェックリストを用意する、issue #17）。
# 設計: issue #17 → .claude/docs/spec/push-checklist.md
#
# push が成立した直後に、次のpushのためのチェックリストを1本生成する。生成の可否は
# .claude/scripts/src/push-checklist.sh の `new` が持ち（条件を満たさなければ静かに 0 で
# 終わる）、本hookは「pushかどうか」を判定して呼び出すだけである。
#
# 責務は既存のpush系hook 2本（post-push-usage-report.sh / post-push-compact-prompt.sh）と
# 分離する。**既存2本のロジックは1バイトも変更しない**（issue #17 の受け入れ条件）。
# `.claude/settings.json` では既存2本より**後ろ**に登録し、既存の出力を邪魔しない。
#
# 判定は .claude/hooks/lib/CommandPosition.sh の command_invokes_git_subcommand へ委譲する
# （issue #17 のコメントによる指示。push検知を自前で書かない）。
#
# `.claude/settings.json` では `if: "Bash(git push*)"` を持つが、Gemini CLI の hook 設定には
# `if` に相当するキーが無く `.gemini/settings.json` からは落ちる。空振りのコストを下げるため、
# 判定本体（jq呼び出しを含む）へ入る前に bash組み込みだけの前置フィルタで足切りする
# （.claude/rules/shell-script-style.md「hookの前置フィルタ」）。

set -uo pipefail

# 生入力（hookへのJSON文字列そのもの。jqでパースする前）に「push」という語が現れうるかを
# 判定する純粋関数（外部コマンドを呼ばずforkしない）。command_invokes_git_subcommand の
# **超集合**であるための前置フィルタ（issue #70, #159）。$1=stdin全体
# 戻り: 0 = 判定本体へ進む可能性がある（通過）/ 1 = pushと無関係と確定（足切りしてよい）
#
# **本文は post-push-usage-report.sh / post-push-compact-prompt.sh と一字一句同じにする。**
# 同一であることは test_sync_gemini_assets.sh のT11が機械的に固定している（実装を source して
# 比較するので、片方だけ直すとテストが落ちる）。理由・実測は
# .claude/docs/ddr/i0159-01-hookの前置フィルタは純粋関数によるバックスラッシュ除去と大文字小文字非依存比較で超集合を保つ.md
# を参照。要点だけ再掲すると、受け取るのは jq でデコードする**前**の生JSON文字列であり、
# 実コマンド中の1文字（改行・タブ等）はJSONエンコードで2文字のエスケープ列になるため、
# バックスラッシュだけを消すと2文字目が残って超集合が壊れる（`git pu\<改行>sh` が素通りする）。
raw_hints_at_git_push() {
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
  # （実行環境のbashバージョンを制御できず、後段のフォールバックへ到達する前に落ちるため）。
  case "$probe" in
    *[Pp][Uu][Ss][Hh]*) return 0 ;;
    *) return 1 ;;
  esac
}

main() {
  set -euo pipefail

  # 前置フィルタ。`read` も raw_hints_at_git_push の中身もbash組み込みだけで、forkしない。
  local raw
  # `|| true` を省かない。`read -d ''` は入力にNULが無いとEOFで非0を返すため、`set -e` 配下では
  # 値が取れているのに終了する。
  IFS= read -r -d '' raw || true
  [ -n "$raw" ] || exit 0
  raw_hints_at_git_push "$raw" || exit 0

  local hook_input
  hook_input="$(printf '%s' "$raw" | jq -c '.' 2>/dev/null)" || exit 0
  [ -n "$hook_input" ] || exit 0

  # tool_name から実行中のエンジンを判定する（Gemini CLI: run_shell_command /
  # Claude Code: Bash・PowerShell）。既存のpush系hook 2本と同じ3値を受ける。
  local tool_name
  tool_name="$(printf '%s' "$hook_input" | jq -r '.tool_name // empty')"
  case "$tool_name" in
    run_shell_command | Bash | PowerShell) ;;
    *) exit 0 ;;
  esac

  local command
  command="$(printf '%s' "$hook_input" | jq -r '.tool_input.command // empty')"
  [ -n "$command" ] || exit 0

  # 判定は .claude/hooks/lib/CommandPosition.sh へ委譲する（issue #53）。
  # `[ -r ]` だけでは「読めるが読み込みに失敗する」（壊れたファイル・bash 4.3未満）を拾えない。
  local lib_dir="${BASH_SOURCE[0]%/*}"
  # パスにディレクトリ成分が無い（`bash post-push-next-checklist.sh` のような起動）と
  # `%/*` はファイル名をそのまま返すため、明示的にカレントへ倒す。
  [ "$lib_dir" = "${BASH_SOURCE[0]}" ] && lib_dir='.'
  local lib="${lib_dir}/lib/CommandPosition.sh"

  local is_push=1
  # shellcheck source=lib/CommandPosition.sh
  if ((BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 3))) &&
    [ -r "$lib" ] && source "$lib" 2>/dev/null &&
    declare -F command_invokes_git_subcommand >/dev/null; then
    if command_invokes_git_subcommand "$command" push; then
      is_push=0
    fi
  elif raw_hints_at_git_push "$raw"; then
    # 縮退時のフォールバックは前置フィルタをそのまま使う（`grep -qiE 'git[[:space:]]+push'` は
    # 精密判定の部分集合であり、`git -C /x push` を取りこぼす。実測）。過剰検知は `new` 側の
    # 生成条件（公開済み・冪等・タスク成果物あり）が受け止めるので害が無い。
    #
    # **PreToolUse 側（block-unchecked-push.sh）は同じことをしていない**（issue #17 フェーズ3の
    # 敵対的レビュー2回目）。あちらは過剰検知がそのまま exit 2 になり、ブロックを解くための
    # `push-checklist.sh check` まで止まって回復不能になるため、専用の
    # `command_hints_at_git_push_degraded` で絞っている。**この非対称は意図的である**——
    # 生成（こちら）は何度余分に走っても冪等だが、ブロック（あちら）は1度でも誤ると作業が止まる。
    is_push=0
  fi
  [ "$is_push" = 0 ] || exit 0

  # push-checklist.sh は内部で `git branch --remotes --contains HEAD` /
  # `git rev-parse --show-toplevel` を実行するため、cwdがリポジトリ内であることに依存する。
  local project_dir="${GEMINI_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-}}"
  [ -n "$project_dir" ] || exit 0
  cd "$project_dir" || exit 0

  local checklist="${project_dir}/.claude/scripts/src/push-checklist.sh"
  [ -r "$checklist" ] || exit 0

  # `new` は生成条件を満たさなければ静かに 0 で終わる設計なので、hook側に条件分岐を持たない。
  # ただし `set -e` 配下なので**非0を素の単純コマンドで受けない**（受けるとhook自身が
  # 非0で終わり、PostToolUseのエラーがユーザーへ出続ける）。
  local created status=0
  created="$(bash "$checklist" new 2>/dev/null)" || status=$?
  if [ "$status" != 0 ]; then
    printf 'warning: 次回分のチェックリストを生成できませんでした（.claude/docs/spec/push-checklist.md）\n' >&2
    exit 0
  fi
  if [ -n "$created" ]; then
    printf '次回push用のチェックリストを作成しました: %s\n' "$created"
    printf '次のcommitに含めてください（埋め方: bash .claude/scripts/src/push-checklist.sh check <id> "<実施ログ>"）。\n'
  fi

  exit 0
}

# `source` されたときは関数定義のみを読み込ませ、`main` を実行しない（issue #57）。
# `main` は冒頭で標準入力を読む（`IFS= read -r -d '' raw`）ため、ガードが無いとテストから
# `source` した時点でstdin待ちのままハングする。
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main
fi
