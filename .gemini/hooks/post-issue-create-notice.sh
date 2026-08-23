#!/usr/bin/env bash
#
# Claude Code / Gemini CLI 共通 PostToolUse・AfterTool hook（issue起票の検知、同一セッションで
# issue-mr-flow へ進まないよう注意を促すメッセージ注入）。
# 設計: issue #39 →
#       .claude/docs/spec/issue-mr-workflow.md「issue起票後の着手確認（issue #39）」,
#       .claude/docs/ddr/i0039-01-issue起票後の着手確認はブロックせず注意喚起の注入で担保する.md
#
# 目的: AIエージェントがissueを起票した流れのまま、人間の確認なしにブランチ・Draft MR作成
# （`/issue-mr-flow start`）まで進んでしまうのを防ぐ。どのissueにいつ着手するかの判断を
# 人間が握れるようにするための、ドキュメント（issue-create / issue-mr-flow の各SKILL.md）に
# 対する多重防御。
#
# **ブロック（PreToolUse + exit 2）は行わない。** 「人間が明示的に着手を指示した」という正当な
# ケースをhookからは観測できず、ブロックするとその解除手段が「hookを黙らせる」ことになって
# しまうため。判断はエージェントに委ね、hookは起票の直後に一度だけ注意を注入する役割に留める
# （却下案を含む詳細はDDR i0039-01参照）。
#
# 検知対象は2経路ある（`.claude/settings.json` の matcher で両方を受ける）。
#   - CLI経路: Bash/PowerShell/run_shell_command のコマンド文字列に `create-issue.sh` を含む
#   - MCP経路: `mcp__github__issue_write` の `method` が `create`（`gh`/`glab` CLI不在時。issue #34）
# いずれもツール実行「後」に発火するため、起票そのものは妨げない。
#
# 既知のトレードオフ: 既存の push/commit 検知hookと同じく部分文字列マッチのため、
# `create-issue.sh` という語をたまたま含むコマンド（該当ファイルを開く・検索する等）でも
# 発火する。注入されるのは注意文だけで処理は妨げないため、実害は小さいものとして許容する。
#
# 注意（エラー方針）: 本体処理は `main` にまとめ、`( main )` の実サブシェルで呼ぶ
# （.claude/rules/shell-script-style.md「bashでのtry/catch相当の書き方」）。失敗はすべて
# 握りつぶし、元のツール実行はブロックしない。
#
# 本hookには if フィールドが無く、matcher（Bash|PowerShell|mcp__github__issue_write）に
# 一致する全呼び出しで起動する（issue #159）。空振り（起票と無関係なペイロード）でも
# `$(cat)` と `printf | jq` × 4 を経由すると execve 7 / clone 17 に達する（strace実測。
# 2026-08-22）。判定本体（is_issue_create_call）へ渡す前に、bash組み込みだけで足切りする
# （issue #70 のpush系hook2本と同じパターン。詳細: .claude/docs/ddr/i0159-01-hookの前置フィルタは純粋関数によるバックスラッシュ除去と大文字小文字非依存比較で超集合を保つ.md）。

set -uo pipefail

NOTICE_TEXT='issueの起票を検知しました（issue #39）。このまま同一セッションで `/issue-mr-flow start` へ進まないでください。

- 起票結果（issue番号・URL）をユーザーへ提示し、着手する際は**新しいセッション**で `/issue-mr-flow start <issue番号>` を実行することを勧めるに留めること（起票と実装が同じセッションに同居すると、進行中の別issueのブランチ・MRと作業コンテキストが混ざるため）。
- 着手するかどうかをAIから持ちかけないこと。着手してよいのは、ユーザーからの明示的な指示があったときのみ。
- この時点ではまだissueに対応するブランチが無いため、`HANDOFF.md` は更新しないこと（更新はflow-id 1-6の担当）。

詳細: `.claude/skills/issue-create/SKILL.md`「してはいけないこと」。'

write_additional_context() {
  local text="$1"
  jq -nc --arg text "$text" \
    '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $text}}'
}

# issue起票の呼び出しかどうかを判定する純粋関数（外部コマンド呼び出し無し）。
# $1=tool_name $2=コマンド文字列（CLI経路） $3=method（MCP経路）
# 起票と判定した場合のみ 0 を返す。
is_issue_create_call() {
  local tool_name="$1" command="${2:-}" method="${3:-}"
  case "$tool_name" in
    run_shell_command | Bash | PowerShell)
      [[ "$command" == *create-issue.sh* ]]
      ;;
    mcp__github__issue_write)
      [[ "$method" == "create" ]]
      ;;
    *)
      return 1
      ;;
  esac
}

# 生入力（hookへのJSON文字列そのもの。jqでパースする前）が起票呼び出しの可能性を示すかを
# 判定する純粋関数（外部コマンドを呼ばずforkしない）。is_issue_create_call の**超集合**で
# あるための前置フィルタ（issue #159）。$1=stdin全体
# 戻り: 0 = 判定本体へ進む可能性がある（通過）/ 1 = 起票と無関係と確定（足切りしてよい）
#
# CLI経路（`create-issue.sh`）は raw_hints_at_git_commit と同じ理由で、バックスラッシュ除去・
# 大文字小文字非依存の比較にする。is_issue_create_call 自体は大文字小文字を区別する部分一致
# だが、ここをそれに厳密に合わせて超集合の余白を削るより、緩めに保つ方が安全側に倒れる
# （過剰検知は後段が無害に落とすだけ。取りこぼす方が危険）。将来issue #149が
# is_issue_create_call のCLI経路判定をコマンド位置判定（CommandPosition.sh）へ差し替える際も、
# その正規化は同じくバックスラッシュ除去・大文字小文字非依存の比較を含むため、この前置フィルタは
# 引き続き超集合であり続ける（#149の実装時に、この関係が保たれているか再確認すること）。
# MCP経路は tool_name が固定文字列 `mcp__github__issue_write` なので、そのまま比較すればよい
# （method の値までは見ない——前置フィルタは足切りであって精密化ではなく、method の絞り込みは
# 後段の is_issue_create_call が担う）。
#
# **バックスラッシュだけを除去する初版には反例があった**（作業結果への敵対的レビューで検出。
# issue #159。block-direct-git-commit.sh の raw_hints_at_git_commit と同じ欠陥）。$1は
# jqでデコードする**前**の生JSON文字列であり、実コマンド中の1文字（改行・タブ等）は
# JSONエンコードされると2文字のエスケープ列（`\n` `\t` 等）になる。バックスラッシュだけを
# 消すとエスケープ列の2文字目が単独の文字として残り、`create-issue.sh` のような語の途中に
# 紛れ込んで一致しなくなりうる。対策として、JSON文字列エスケープの2文字シーケンス
# （`\\` `\"` `\n` `\t` `\r` `\/` `\b` `\f`）は2文字ともまとめて除去してから、残った
# バックスラッシュ（`\uXXXX` 等）を落とす。`\\` を最初に処理する理由・除去が単調に
# マッチ候補を増やすだけである理由は raw_hints_at_git_commit のコメントを参照。
raw_hints_at_issue_create() {
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
  case "$probe" in
    *[Cc][Rr][Ee][Aa][Tt][Ee]-[Ii][Ss][Ss][Uu][Ee].[Ss][Hh]*) return 0 ;;
    *mcp__github__issue_write*) return 0 ;;
    *) return 1 ;;
  esac
}

main() {
  set -euo pipefail

  # 前置フィルタ（issue #159）。`read` も raw_hints_at_issue_create の中身
  # （`${raw//\\/}` とcase）もbash組み込みだけで、forkしない。
  local raw
  # `|| true` を省かない理由は block-direct-git-commit.sh と同じ
  # （`read -d ''` は入力にNULが無いとEOFで非0を返す）。
  IFS= read -r -d '' raw || true
  [ -n "$raw" ] || exit 0
  raw_hints_at_issue_create "$raw" || exit 0

  local hook_input
  hook_input="$(printf '%s' "$raw" | jq -c '.' 2>/dev/null)" || exit 0
  [ -n "$hook_input" ] || exit 0

  local agent_id
  agent_id="$(printf '%s' "$hook_input" | jq -r '.agent_id // empty')"
  # サブエージェント内実行では何もしない（post-push-usage-report.shと同じガード）
  [ -z "$agent_id" ] || exit 0

  local tool_name command method
  tool_name="$(printf '%s' "$hook_input" | jq -r '.tool_name // empty')"
  command="$(printf '%s' "$hook_input" | jq -r '.tool_input.command // empty')"
  method="$(printf '%s' "$hook_input" | jq -r '.tool_input.method // empty')"

  is_issue_create_call "$tool_name" "$command" "$method" || exit 0

  write_additional_context "$NOTICE_TEXT"
}

# source 時に本体（`IFS= read -r -d '' raw` によるstdin読み取り）が走らないようにする
# （.claude/rules/shell-script-style.md「テスト」）。
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  ( main ) || true
  exit 0
fi
