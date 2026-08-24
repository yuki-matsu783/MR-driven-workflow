#!/usr/bin/env bash
#
# push前チェックリストの生成・記録・検証を行う本体（issue #17）。
# 設計: issue #17 → .claude/docs/spec/push-checklist.md
#
# pushの前に済ませるべき作業（worklogの追記・HANDOFF.mdの更新・index.jsonlの最新化等）を、
# pushごとに一意なGit管理下のTSVとして持たせる。未完了のままpushしようとした場合は
# PreToolUse hook（.claude/hooks/block-unchecked-push.sh）が exit 2 でブロックする。
# 次回分の生成は PostToolUse hook（.claude/hooks/post-push-next-checklist.sh）が行う。
#
# 本スクリプトは hook から呼ばれるが、hook そのものではない。**exit 2 は返さない**
# （exit 2 は Claude Code のhook契約であり、スクリプト単体の終了コードとしては使わない。
# hook側が 1 を受けて 2 へ翻訳する）。
#
# サブコマンドと終了コード:
#   path                  最新チェックリストのパスをstdoutへ。無ければ 1
#   new                   次回分を生成する。生成条件を満たさなければ何もせず 0
#   check <id> <ログ>     その行を done にし4列目へログを書く。0 / 1
#   skip  <id> <理由>     その行を skip にし4列目へ理由を書く。0 / 1
#   verify                HEAD断面を検証する。0=通す / 1=検証失敗 / 3=HEADに対象なし
#   stale                 コミット忘れの検知。0=あり / 1=なし
#
# `check`/`skip` は**作業ツリー**を書き換え、`verify` は**HEADにコミット済みの断面**を読む。
# この非対称は意図的で、「作業ツリーだけ埋めてpushする」ことを防ぐためである
# （調査結果 Q4 の結論）。

set -euo pipefail

# ---------------------------------------------------------------------------
# 定数
# ---------------------------------------------------------------------------

# チェック項目（調査結果 Q2 の5件）。**外部定義ファイルにはしない**——項目はフロー定義
# そのものであり、`.claude/` は配布層 core（本家所有）だからである。
# 文言はQ3のTSVサンプルと一致させてある（markdownの表ではバッククォートが付くが、
# それは表の書式であって本文ではない。ファイルへ書き出すのは下の素のテキスト）。
CHECKLIST_IDS=(
  'worklog'
  'handoff'
  'frontmatter-index'
  'plan-report-sync'
  'commit-skill'
)
#
# **ディレクトリ名を文言へ決め打ちしない**（issue #17 フェーズ3の敵対的レビュー2回目で指摘）。
# 同じスクリプトが `plansDir` / `reportsDir` を `.mrworkflow.json` から読んでいるのに、項目の
# 文言だけ本リポジトリ固有の `wip/plans/` を埋め込んでいると、配布先で存在しないパスを案内する。
# テンプレート側にプレースホルダを置き、`init_context` が実際の設定値で埋める。
CHECKLIST_ITEM_TEMPLATES=(
  'worklogを作成し、このpushまでの試行錯誤を追記した'
  'HANDOFF.md の進捗表・ヘッダを更新した（commitより前・同じcommitに含めた）'
  'frontmatterを変更した場合、index.jsonl を最新化した'
  '{plansDir}/ {reportsDir}/ の md と html を同期した'
  'commit スキル（create-commit.sh）経由でコミットした'
)
# `init_context` を通さずに source した場合（単体テストの純粋関数層）でも参照できるよう、
# テンプレートのまま初期化しておく。
CHECKLIST_ITEMS=("${CHECKLIST_ITEM_TEMPLATES[@]}")

# ファイル名の末尾。ブランチ・日付部分は生成時に決まる。
CHECKLIST_SUFFIX='_checklist.tsv'

# ---------------------------------------------------------------------------
# 純粋関数（外部コマンドを呼ばない）
# ---------------------------------------------------------------------------

# ブランチ名をファイル名に使えるスラッグへ変換する。
# `post-push-compact-prompt.sh` と同じ変換（`[^a-zA-Z0-9_-]` を `_` へ）だが、
# hookから間接的に呼ばれる経路にあるため sed ではなくbash組み込みで行う（forkしない）。
# 戻り: REPLY
branch_slug_to_reply() {
  local s="$1" out='' c i
  for ((i = 0; i < ${#s}; i++)); do
    c="${s:i:1}"
    case "$c" in
      [a-zA-Z0-9_-]) out+="$c" ;;
      *) out+='_' ;;
    esac
  done
  REPLY="$out"
}

# TSVの1行をタブで分割する。**`IFS=$'\t' read -r -a` を使ってはいけない**——
# タブはbashのIFS空白文字であり、連続するタブが1つに畳まれ、行末のタブが捨てられる。
# 4フィールド固定（`pending` 行も4列目を空で持つ）という本機構の前提が壊れ、
# 「空の実施ログ」を検出できなくなる。
# 戻り: TSV_FIELDS 配列
split_tsv_line() {
  local rest="$1"
  TSV_FIELDS=()
  while :; do
    case "$rest" in
      *$'\t'*)
        TSV_FIELDS+=("${rest%%$'\t'*}")
        rest="${rest#*$'\t'}"
        ;;
      *)
        TSV_FIELDS+=("$rest")
        break
        ;;
    esac
  done
}

# 実施ログを1行の自由記述へ正規化する（タブ・改行・CRを半角スペースへ潰し、前後を刈る）。
# TSVのエスケープ規則は持ち込まない（`git diff` での読みやすさを優先する。調査結果 Q3）。
# 戻り: REPLY
normalize_log_to_reply() {
  local s="$1"
  s="${s//$'\t'/ }"
  s="${s//$'\n'/ }"
  s="${s//$'\r'/ }"
  while [ "${s# }" != "$s" ]; do s="${s# }"; done
  while [ "${s% }" != "$s" ]; do s="${s% }"; done
  REPLY="$s"
}

# チェックリストのファイル名から push番号 を取り出す。指定スラッグのブランチのものでなければ
# 非0を返す。$1=パスまたはファイル名 $2=ブランチスラッグ
# 戻り: REPLY = push番号
checklist_number_to_reply() {
  local base="${1##*/}" slug="$2"
  local rest num head
  REPLY=''
  case "$base" in
    *"$CHECKLIST_SUFFIX") ;;
    *) return 1 ;;
  esac
  rest="${base%"$CHECKLIST_SUFFIX"}"
  num="${rest##*_push}"
  # `_push` が現れなければ ##* は元の文字列をそのまま返す。
  [ "$num" != "$rest" ] || return 1
  case "$num" in
    '' | *[!0-9]*) return 1 ;;
  esac
  head="${rest%_push${num}}"
  # **接尾辞一致（`*_"$slug"`）にしてはいけない**（issue #17 フェーズ3の敵対的レビュー2回目で
  # 指摘）。`<日付>` がちょうど1フィールドであることを確かめないと、スラッグが別のスラッグの
  # `_` 区切りの接尾辞になっている場合（`claude/hook-impl-17` と `hook-impl-17` のような
  # 接頭辞付き／素のブランチの組）に、別ブランチのチェックリストを自分のものとして採用する。
  # `<日付>_<スラッグ>` として厳密に照合する。
  [ "$head" = "${head%%_*}_${slug}" ] || return 1
  REPLY="$num"
  return 0
}

# 改行区切りのパス一覧から、push番号が最大のものを選ぶ。
# $1=パス一覧（改行区切り） $2=ブランチスラッグ
# 戻り: REPLY = パス（無ければ空） / REPLY_N = push番号（無ければ 0）
max_checklist_to_reply() {
  local list="$1" slug="$2" line best='' best_n=0
  REPLY=''
  REPLY_N=0
  while IFS= read -r line; do
    line="${line//$'\r'/}"
    [ -n "$line" ] || continue
    checklist_number_to_reply "$line" "$slug" || continue
    # 10進数として比較する（08・09を8進数と読ませない）。
    if [ "$((10#$REPLY))" -gt "$best_n" ]; then
      best_n="$((10#$REPLY))"
      best="$line"
    fi
  done <<<"$list"
  REPLY="$best"
  REPLY_N="$best_n"
}

# ---------------------------------------------------------------------------
# 環境の解決
# ---------------------------------------------------------------------------

# リポジトリルートへ移動し、ディレクトリ設定とブランチスラッグを解決する。
# `.mrworkflow.json` にキーが無い場合のフォールバックは、**`cleanup-task.sh:232` と同一の
# 文字列**（`plans` / `worklog` / `reports`）を当てる。`get_workflow_config` は
# `.mrworkflow.json` が存在すればその中身をそのまま返すだけで、キー単位の既定値補完を
# 行わないため（`Provider.sh:53-61`）、ここで当てないと生成側が literal な `null/` へ書き、
# 削除側（`cleanup-task.sh`）は `worklog/` を見るという食い違いが起きる。
init_context() {
  local script_dir repo_root config dirs_tsv
  script_dir="${BASH_SOURCE[0]%/*}"
  [ "$script_dir" = "${BASH_SOURCE[0]}" ] && script_dir='.'
  # shellcheck source=./vcs/Provider.sh
  source "${script_dir}/vcs/Provider.sh"

  repo_root="$(get_repo_root)"
  cd "$repo_root"

  config="$(get_workflow_config)"
  dirs_tsv="$(printf '%s' "$config" |
    jq -r '[(.plansDir // "plans"), (.worklogDir // "worklog"), (.reportsDir // "reports")] | @tsv')"
  dirs_tsv="${dirs_tsv//$'\r'/}"
  split_tsv_line "$dirs_tsv"
  PLANS_DIR="${TSV_FIELDS[0]}"
  WORKLOG_DIR="${TSV_FIELDS[1]}"
  REPORTS_DIR="${TSV_FIELDS[2]}"

  # 項目文言のプレースホルダを実際の設定値で埋める（上記「ディレクトリ名を決め打ちしない」）。
  # テンプレート配列から作り直すので、複数回呼んでも同じ結果になる。
  local i item
  CHECKLIST_ITEMS=()
  for ((i = 0; i < ${#CHECKLIST_ITEM_TEMPLATES[@]}; i++)); do
    item="${CHECKLIST_ITEM_TEMPLATES[$i]}"
    item="${item//\{plansDir\}/$PLANS_DIR}"
    item="${item//\{reportsDir\}/$REPORTS_DIR}"
    CHECKLIST_ITEMS+=("$item")
  done

  BRANCH="$(git branch --show-current 2>/dev/null || true)"
  branch_slug_to_reply "$BRANCH"
  BRANCH_SLUG="$REPLY"
}

# HEADが存在するか（unborn branch でないか）。detached HEAD でも 0 を返す。
head_exists() {
  git rev-parse --verify -q HEAD >/dev/null 2>&1
}

# 作業ツリー上のチェックリスト一覧を改行区切りでstdoutへ。
list_worktree_checklists() {
  local f
  [ -d "$WORKLOG_DIR" ] || return 0
  for f in "$WORKLOG_DIR"/*"$CHECKLIST_SUFFIX"; do
    [ -f "$f" ] || continue
    printf '%s\n' "$f"
  done
}

# HEADにコミット済みのチェックリスト一覧を改行区切りでstdoutへ。
list_head_checklists() {
  head_exists || return 0
  git ls-tree -r --name-only HEAD -- "$WORKLOG_DIR" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# 検証
# ---------------------------------------------------------------------------

# TSVの中身（stdin）を検証する。**通してよいと積極的に確認できたときだけ 0 を返す**
# （否定形。調査結果 Q5）。判定できなかった・想定外だった場合はすべて 1 へ倒す。
# 検証に失敗した理由は1行ずつstdoutへ出す（hookがブロックメッセージへ載せる）。
#
# 条件（1つでも欠ければ 1）:
#   1. 全データ行がちょうど4フィールド
#   2. id列の集合が5件の定数と過不足なく一致（重複も不可）
#   3. 全行の状態が done または skip
#   4. done / skip の行の4列目が空でない
verify_stream() {
  local line lineno=0 ok=1
  local id state log i found
  local -a seen_ids=()

  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))
    line="${line//$'\r'/}"
    # 空行とコメント行（`#` 始まり）は読み飛ばす。
    [ -n "$line" ] || continue
    case "$line" in
      '#'*) continue ;;
    esac

    split_tsv_line "$line"
    if [ "${#TSV_FIELDS[@]}" -ne 4 ]; then
      printf '形式異常: %s行目のフィールド数が %s です（4である必要があります）\n' \
        "$lineno" "${#TSV_FIELDS[@]}"
      ok=0
      continue
    fi
    id="${TSV_FIELDS[0]}"
    state="${TSV_FIELDS[2]}"
    log="${TSV_FIELDS[3]}"

    found=0
    for i in "${CHECKLIST_IDS[@]}"; do
      [ "$i" = "$id" ] || continue
      found=1
      break
    done
    if [ "$found" -eq 0 ]; then
      printf '形式異常: %s行目のid「%s」は想定外です\n' "$lineno" "$id"
      ok=0
      continue
    fi
    for i in ${seen_ids[@]+"${seen_ids[@]}"}; do
      if [ "$i" = "$id" ]; then
        printf '形式異常: id「%s」が重複しています\n' "$id"
        ok=0
      fi
    done
    seen_ids+=("$id")

    case "$state" in
      done | skip) ;;
      pending)
        printf '未完了: %s（%s）\n' "$id" "$(item_text_for "$id")"
        ok=0
        continue
        ;;
      *)
        printf '形式異常: %s行目の状態「%s」は done / skip / pending のいずれでもありません\n' \
          "$lineno" "$state"
        ok=0
        continue
        ;;
    esac

    normalize_log_to_reply "$log"
    if [ -z "$REPLY" ]; then
      printf '実施ログが空です: %s（%s には何をしたかを書いてください）\n' \
        "$id" "$state"
      ok=0
    fi
  done

  # 件数の突き合わせ（欠落の検出）。
  for i in "${CHECKLIST_IDS[@]}"; do
    found=0
    for id in ${seen_ids[@]+"${seen_ids[@]}"}; do
      [ "$id" = "$i" ] || continue
      found=1
      break
    done
    if [ "$found" -eq 0 ]; then
      printf '行が足りません: %s（%s）\n' "$i" "$(item_text_for "$i")"
      ok=0
    fi
  done

  [ "$ok" -eq 1 ]
}

# idから項目の文言を引く。未知のidなら空。
item_text_for() {
  local want="$1" i
  for ((i = 0; i < ${#CHECKLIST_IDS[@]}; i++)); do
    if [ "${CHECKLIST_IDS[$i]}" = "$want" ]; then
      printf '%s' "${CHECKLIST_ITEMS[$i]}"
      return 0
    fi
  done
  return 0
}

# ---------------------------------------------------------------------------
# サブコマンド
# ---------------------------------------------------------------------------

cmd_path() {
  local list
  list="$(list_worktree_checklists)"
  max_checklist_to_reply "$list" "$BRANCH_SLUG"
  [ -n "$REPLY" ] || return 1
  printf '%s\n' "$REPLY"
}

cmd_verify() {
  local list content
  head_exists || {
    printf 'HEADにコミットがありません（チェックリストの検証対象がありません）\n'
    return 3
  }
  list="$(list_head_checklists)"
  max_checklist_to_reply "$list" "$BRANCH_SLUG"
  if [ -z "$REPLY" ]; then
    printf 'HEADにこのブランチのチェックリストがありません\n'
    return 3
  fi
  # `git show` の失敗も「対象なし」へ倒す（ブロックしない）。
  content="$(git show "HEAD:${REPLY}" 2>/dev/null)" || {
    printf 'HEADのチェックリストを読めませんでした: %s\n' "$REPLY"
    return 3
  }
  if printf '%s\n' "$content" | verify_stream; then
    return 0
  fi
  printf '対象: %s\n' "$REPLY"
  return 1
}

# 作業ツリーの最大N > HEADの最大N なら「コミットされていない新しいチェックリストがある」。
# **「HEADにチェックリストがあるか」では検知にならない**——チェックリストは flow-id 5-5 まで
# 蓄積するため、2回目以降のpushではHEADに必ず古いものが残っているからである。
# 戻り: 0 = コミット忘れあり / 1 = なし
cmd_stale() {
  local wt_n head_n
  max_checklist_to_reply "$(list_worktree_checklists)" "$BRANCH_SLUG"
  wt_n="$REPLY_N"
  max_checklist_to_reply "$(list_head_checklists)" "$BRANCH_SLUG"
  head_n="$REPLY_N"
  if [ "$wt_n" -gt "$head_n" ]; then
    printf 'コミットされていないチェックリストがあります（作業ツリー push%s > HEAD push%s）\n' \
      "$wt_n" "$head_n"
    return 0
  fi
  return 1
}

# HEADにタスク成果物（計画・worklog・レポート）が残っているか。
# `TEMPLATE.md` と `REVIEW-POINTS*.md` は flow-id 5-5 でも残る恒久ファイルなので除く。
head_has_task_artifacts() {
  local line base
  head_exists || return 1
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    base="${line##*/}"
    case "$base" in
      TEMPLATE.md | REVIEW-POINTS.md | REVIEW-POINTS.local.md) continue ;;
    esac
    return 0
  done < <(git ls-tree -r --name-only HEAD -- "$PLANS_DIR" "$WORKLOG_DIR" "$REPORTS_DIR" 2>/dev/null || true)
  return 1
}

# 次回分のチェックリストを生成する。生成条件（調査結果 Q6 の3つ）を1つでも欠けば
# **エラーではなく静かに 0 で終わる**（PostToolUse の正常系だから）。
cmd_new() {
  local head_sha remotes list path_ line f i n today

  head_exists || return 0
  head_sha="$(git rev-parse HEAD)"

  # 条件1: HEADが公開済み（リモート追跡ブランチのいずれかに含まれる）。
  # `HEAD == @{upstream}` は両方向に誤るため使わない（調査結果 Q6）。
  remotes="$(git branch --remotes --contains HEAD 2>/dev/null || true)"
  [ -n "${remotes//[[:space:]]/}" ] || return 0

  # 条件2: そのHEAD SHAを `# generated-for:` に持つチェックリストが1本も無い（冪等性）。
  list="$(list_worktree_checklists)"
  while IFS= read -r path_; do
    [ -n "$path_" ] || continue
    while IFS= read -r line || [ -n "$line" ]; do
      line="${line//$'\r'/}"
      case "$line" in
        '# generated-for: '*)
          [ "${line#\# generated-for: }" = "$head_sha" ] && return 0
          break
          ;;
        '#'*) continue ;;
        *) break ;;
      esac
    done <"$path_"
  done <<<"$list"

  # 条件3: HEADにタスク成果物が残っている（flow-id 5-5 の片付け後に再生成しない）。
  head_has_task_artifacts || return 0

  # 番号は作業ツリーとHEADの最大値のうち大きいほうに 1 を足す。
  max_checklist_to_reply "$list" "$BRANCH_SLUG"
  n="$REPLY_N"
  max_checklist_to_reply "$(list_head_checklists)" "$BRANCH_SLUG"
  [ "$REPLY_N" -gt "$n" ] && n="$REPLY_N"
  n=$((n + 1))

  printf -v today '%(%Y%m%d)T' -1
  f="${WORKLOG_DIR}/${today}_${BRANCH_SLUG}_push${n}${CHECKLIST_SUFFIX}"

  mkdir -p "$WORKLOG_DIR"
  {
    printf '# generated-for: %s\n' "$head_sha"
    printf '# id\t項目\t状態\t実施ログ\n'
    for ((i = 0; i < ${#CHECKLIST_IDS[@]}; i++)); do
      # 4フィールド固定。`pending` 行も4列目（空文字列）を持つため行末はタブで終わる。
      printf '%s\t%s\tpending\t\n' "${CHECKLIST_IDS[$i]}" "${CHECKLIST_ITEMS[$i]}"
    done
  } >"$f"
  printf '%s\n' "$f"
}

# `check` / `skip` の共通処理。$1=新しい状態 $2=id $3=ログ
set_state() {
  local new_state="$1" want_id="$2" raw_log="$3"
  local list target tmp line found=0 i log

  normalize_log_to_reply "$raw_log"
  log="$REPLY"
  if [ -z "$log" ]; then
    printf 'error: 実施ログが空です（何をしたかを1行で書いてください）\n' >&2
    return 1
  fi

  found=0
  for i in "${CHECKLIST_IDS[@]}"; do
    [ "$i" = "$want_id" ] || continue
    found=1
    break
  done
  if [ "$found" -eq 0 ]; then
    printf 'error: 未知のid「%s」です（有効なid: %s）\n' "$want_id" "${CHECKLIST_IDS[*]}" >&2
    return 1
  fi

  list="$(list_worktree_checklists)"
  max_checklist_to_reply "$list" "$BRANCH_SLUG"
  target="$REPLY"
  if [ -z "$target" ]; then
    printf 'error: このブランチのチェックリストが作業ツリーにありません（%s/）\n' "$WORKLOG_DIR" >&2
    return 1
  fi

  tmp="${target}.tmp.$$"
  found=0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line//$'\r'/}"
    case "$line" in
      '#'*)
        printf '%s\n' "$line"
        continue
        ;;
    esac
    if [ -z "$line" ]; then
      printf '\n'
      continue
    fi
    split_tsv_line "$line"
    if [ "${#TSV_FIELDS[@]}" -ge 2 ] && [ "${TSV_FIELDS[0]}" = "$want_id" ]; then
      printf '%s\t%s\t%s\t%s\n' "${TSV_FIELDS[0]}" "${TSV_FIELDS[1]}" "$new_state" "$log"
      found=1
    else
      printf '%s\n' "$line"
    fi
  done <"$target" >"$tmp"

  if [ "$found" -eq 0 ]; then
    rm -f "$tmp"
    printf 'error: チェックリストに id「%s」の行がありません: %s\n' "$want_id" "$target" >&2
    return 1
  fi
  mv "$tmp" "$target"
  printf '%s: %s -> %s\n' "$target" "$want_id" "$new_state"
}

usage() {
  cat >&2 <<'EOF'
usage: push-checklist.sh <subcommand> [args]

  path                   最新チェックリストのパスを出力する（無ければ終了コード1）
  new                    次回分を生成する（条件を満たさなければ何もせず0）
  check <id> <実施ログ>  その項目を done にする
  skip  <id> <理由>      その項目を skip にする
  verify                 HEAD断面を検証する（0=通す / 1=検証失敗 / 3=対象なし）
  stale                  コミット忘れを検知する（0=あり / 1=なし）

有効なid: worklog handoff frontmatter-index plan-report-sync commit-skill
詳細: .claude/docs/spec/push-checklist.md
EOF
}

main() {
  local sub="${1:-}"
  [ -n "$sub" ] || {
    usage
    return 1
  }
  shift

  case "$sub" in
    path | new | verify | stale | check | skip) ;;
    *)
      printf 'error: 未知のサブコマンド「%s」\n' "$sub" >&2
      usage
      return 1
      ;;
  esac

  init_context

  case "$sub" in
    path) cmd_path ;;
    new) cmd_new ;;
    verify) cmd_verify ;;
    stale) cmd_stale ;;
    check)
      [ "$#" -ge 2 ] || {
        usage
        return 1
      }
      set_state done "$1" "$2"
      ;;
    skip)
      [ "$#" -ge 2 ] || {
        usage
        return 1
      }
      set_state skip "$1" "$2"
      ;;
  esac
}

# `source` されたときは関数定義のみを読み込ませる（issue #57）。単体テストから純粋関数だけを
# 直接呼べるようにするため。
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
