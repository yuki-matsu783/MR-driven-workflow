#!/usr/bin/env bash
#
# Claude Code PreToolUse hook（push前チェックリストが未完了なら push をブロック、issue #17）。
# 設計: issue #17 → .claude/docs/spec/push-checklist.md
#
# 目的: push前に済ませるべき作業（worklogの追記・HANDOFF.mdの更新・index.jsonlの最新化等）を
# 取りこぼさないこと。判定の実体は .claude/scripts/src/push-checklist.sh が持ち、本hookは
# 「pushかどうか」を判定して呼び出し、終了コードをhookの契約（exit 2 = ブロック）へ翻訳する
# だけである。
#
# 責務は既存のpush系hook 2本（post-push-usage-report.sh / post-push-compact-prompt.sh）と
# 分離する。あちらは push の**後**に対応工数を集計し `/compact` を促す PostToolUse であり、
# こちらは push の**前**に止める PreToolUse である（issue #17 の受け入れ条件）。
# **既存2本のロジックは1バイトも変更しない。**
#
# 判定は .claude/hooks/lib/CommandPosition.sh の command_invokes_git_subcommand へ委譲する
# （issue #17 のコメントによる指示。push検知を自前で書かない）。
#
# 本hookには if フィールドが無く、Bash/PowerShellの全呼び出しで起動する。空振りのコストを
# 下げるため、判定本体（jq呼び出しを含む）へ入る前に bash組み込みだけの前置フィルタで
# 足切りする（.claude/rules/shell-script-style.md「hookの前置フィルタ」）。

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

# 縮退時（`lib/CommandPosition.sh` を使えない）のブロック判定に使う純粋関数。
# $1 = `tool_input.command`（jqでデコード**済み**の実コマンド文字列）
# 戻り: 0 = git の push とみなす（ブロック） / 1 = ブロックしない
#
# **前置フィルタ（raw_hints_at_git_push）をそのままブロック判定へ流用してはいけない**
# （issue #17 フェーズ3の敵対的レビュー2回目で指摘。実際に再現した）。前置フィルタは
# 「push という語がどこかに現れるか」しか見ない超集合であり、判定本体としては過剰検知が
# そのまま exit 2 になる。**回復のために叩く `push-checklist.sh check` はパスに push を
# 含むため必ずブロックされ、縮退環境では自力で回復できなくなる。**
# 「縮退時はブロック側へ倒す」方針は妥当だが、倒した先が回復不能では方針として成立しない。
#
# そこで、生JSONではなく実コマンド文字列を空白で分割し、
#   (1) basename が git のトークンがある
#   (2) その後ろに push というトークンがある
# の両方が揃ったときだけブロックする。**`git` トークンを AND 条件にしたことで、
# `push-checklist.sh` を叩く回復コマンドは構造的にブロックされない。**
# 精密判定の超集合ではなくなる（`eval "git push"` 等は取りこぼす）が、縮退時は元々
# best-effort であり、取りこぼしの害（1回のpushが素通りする）より回復不能の害が大きい。
command_hints_at_git_push_degraded() {
  local cmd="$1"
  # 精密判定と同じくバックスラッシュを落とす（`git pu\sh` を push と読むため）。
  cmd="${cmd//\\/}"
  local tok base seen_git=1
  # `IFS` へCR・タブ・改行を含める（CommandPosition.sh のトークン走査と同じ扱い）。
  local IFS=$' \t\n\r'
  for tok in $cmd; do
    base="${tok##*/}"
    case "$base" in
      [Gg][Ii][Tt]) seen_git=0 ;;
      [Pp][Uu][Ss][Hh]) [ "$seen_git" = 0 ] && return 0 ;;
    esac
  done
  return 1
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
  # Claude Code: Bash・PowerShell）。**`run_shell_command` を落とさない**——
  # `.gemini/` を変換同期の対象にしている以上、Gemini CLI 経路でも守らせる必要がある
  # （block-direct-git-commit.sh は Bash/PowerShell の2つだけだが、そちらへ揃えると
  # Gemini CLI では機構が丸ごと効かない）。
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
  # `set -e` 配下では source の失敗がそのまま終了コード2になり、pushと無関係なコマンドまで
  # ブロックされてしまうため、バージョン・source の成否・関数の存在まで確かめる。
  local lib_dir="${BASH_SOURCE[0]%/*}"
  # パスにディレクトリ成分が無い（`bash block-unchecked-push.sh` のような起動）と
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
  elif command_hints_at_git_push_degraded "$command"; then
    # 縮退時のフォールバック。**前置フィルタ（`raw_hints_at_git_push`）をそのまま使わない**
    # ——過剰検知がそのまま exit 2 になり、回復用の `push-checklist.sh check` まで止まる
    # （上記の関数コメント参照）。`grep -qiE 'git[[:space:]]+push'` も使わない
    # （`git -C /x push` を取りこぼす）。
    is_push=0
  fi
  [ "$is_push" = 0 ] || exit 0

  # ここから先は push だと判定できた場合のみ。push-checklist.sh は内部で
  # `git show HEAD:` / `git branch --remotes --contains HEAD` / `git rev-parse --show-toplevel` を
  # 実行するため、**cwdがリポジトリ内であることに依存する**。
  local project_dir="${GEMINI_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-}}"
  [ -n "$project_dir" ] || exit 0
  cd "$project_dir" || exit 0

  # **`lib_dir` からの相対では解決しない。** `lib_dir` は BASH_SOURCE 由来で相対にもなりうる
  # （`bash .claude/hooks/block-unchecked-push.sh` のような起動）ため、直前の `cd` で意味が
  # 変わってしまう。project_dir からの絶対パスで解決する
  # （post-push-compact-prompt.sh が Provider.sh を読む形と同じ）。
  local checklist="${project_dir}/.claude/scripts/src/push-checklist.sh"
  [ -r "$checklist" ] || exit 0

  # `set -e` 配下なので、非0を素の単純コマンドで受けない（受けるとhook自身が exit 1 で
  # 終わり、ブロックしたい場面でブロックされなくなる）。
  local detail status=0
  detail="$(bash "$checklist" verify 2>/dev/null)" || status=$?

  if [ "$status" = 1 ]; then
    {
      printf 'push前チェックリストが未完了です。pushはブロックされました。\n\n'
      printf '%s\n\n' "$detail"
      printf 'チェックリストを埋めてから、同じcommitに含めてコミットし直してください:\n'
      printf '  bash .claude/scripts/src/push-checklist.sh check <id> "<実施ログ>"\n'
      printf '  bash .claude/scripts/src/push-checklist.sh skip  <id> "<スキップの理由>"\n\n'
      printf 'ルール: .claude/skills/commit/SKILL.md / .claude/docs/spec/push-checklist.md\n'
    } >&2
    exit 2
  fi

  # status が 0（通してよい）でも 3（HEADに対象が無い）でも、**コミット忘れは別に見る**。
  # チェックリストは flow-id 5-5 まで蓄積するため、新しく生成された分をコミットし忘れても
  # verify は HEAD に残る古い（全 done の）チェックリストを見て 0 を返してしまう。
  #
  # **ここは当初 exit 1（非ブロックの警告）だった**（issue #17 フェーズ3の敵対的レビュー
  # 2回目で指摘）。しかし spec が挙げる本機構の動機そのもの——「必要な更新をcommitへ
  # 含め忘れ、その分だけが未コミットで残る」——に当たるのがこの経路であり、**機構が防ぎたい
  # 失敗が唯一ブロックされない経路になっていた**。加えて exit 1 の stderr が届くかは未確認で、
  # 届かなければ無言で素通りする。ブロックへ倒しても回復手段は「チェックリストをcommitへ
  # 含める」だけで、その `create-commit.sh` の呼び出しは push を含まないため止まらない。
  local stale_msg stale_status=0
  stale_msg="$(bash "$checklist" stale 2>/dev/null)" || stale_status=$?
  if [ "$stale_status" = 0 ]; then
    {
      printf 'push前チェックリストがコミットされていません。pushはブロックされました。\n\n'
      printf '%s\n\n' "$stale_msg"
      printf 'チェックリストを埋めたうえで、commit スキル経由でコミットへ含めてください:\n'
      printf '  bash .claude/scripts/src/push-checklist.sh check <id> "<実施ログ>"\n'
      printf '  bash .claude/scripts/src/create-commit.sh --message "..." -- <チェックリストのパス>\n\n'
      printf 'ルール: .claude/skills/commit/SKILL.md / .claude/docs/spec/push-checklist.md\n'
    } >&2
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
