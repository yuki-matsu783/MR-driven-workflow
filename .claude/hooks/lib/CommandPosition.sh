#!/usr/bin/env bash
#
# コマンド文字列の「コマンド位置」判定（issue #53）。
# 設計: issue #53 → .claude/docs/spec/command-position.md
#
# hookが受け取る `tool_input.command` に対し、`git commit` / `git push` のような呼び出しが
# **実際にコマンドとして実行される位置**にあるかどうかを判定する。従来の
# `grep -qiE 'git[[:space:]]+commit'` は文字列のどこに現れてもマッチするため、
# ヒアドキュメント本文・クォート内・コメント・日本語の地の文に該当語が含まれるだけで
# 誤検知していた。
#
# 本ファイルは**外部コマンドを一切呼ばない純粋関数**だけで構成する
# （hookは毎ツール呼び出しで走るホットパスであり、git bashでは外部プロセス起動が
# 約95ms/回かかるため。.claude/rules/shell-script-style.md「外部プロセス起動のコスト」）。
# 単体テストは .claude/scripts/test/test_command_position.sh。
#
# 判定は2段構えである。
#   1. 正規化: クォート・ヒアドキュメント本文・コメントを、コマンド位置になりえない
#      プレースホルダ（`_`）へ潰す。ダブルクォート内の `$( )` と `` ` `` だけはコードとして
#      展開し直す（`echo "$(git commit)"` を見逃さないため）。
#   2. 走査: 正規化後の文字列をトークンへ割り、コマンド位置にある `git` の直後の
#      非オプショントークンが目的のサブコマンドかを見る。
#
# 位置判定で一致しなかった場合でも、**文字列をコードとして受け取りうる実行系**
# （`eval` / `bash -c` / `xargs` / `find` 等）がコマンド位置にあり、かつ従来の部分一致が
# 成立する場合は、保守的にブロック側へ倒す（素通りを増やさないため）。
#
# 意図的な文字列分割（`git "commit"` 等）による回避には対応しない。これは敵対的な
# 安全境界ではなく「既定動作を確実な方向へ倒す仕組み」であるため
# （.claude/docs/ddr/i0000-09-コミットはcommitスキル経由を機構的に強制する.md）。

# 改行・バックティックはリテラルとして書くと引用の解釈が絡んで読みにくいため定数へ逃がす。
_CP_NL=$'\n'
_CP_BT='`'

# パターンは `$'...'` で組み立ててから、パラメータ展開の中へ**クォートせず**展開する。
# ダブルクォートの中へブラケット式を直接書くと、`\\` と `\'` の解釈がシェルとパターン照合で
# 二重にかかり、意図した文字集合にならない（バックスラッシュが集合から落ちる）。
_CP_CODE_CHARS=$'[\'"#\\\\`<()\n]'
_CP_DQ_CHARS=$'["\\\\$`]'
_CP_SQ_CHARS=$'[\']'

# コマンド位置を保ったまま読み飛ばす語（シェルの予約語と、引数を素通しする透過的なラッパー）。
# ここに載る語の後は、次のセパレータまで**すべてのトークン**をコマンド位置候補として扱う
# （`sudo -u alice git commit` のように、間にオプションとその引数が挟まる形へ対応するため）。
_CP_PREFIX_WORDS=' if then elif else do while until ! time sudo doas env command builtin exec nohup nice ionice setsid stdbuf timeout '

# 文字列をコードとして受け取る実行系（無条件）。
_CP_OPAQUE_WORDS=' eval xargs find ssh watch flock parallel '

# コード指定オプションと併用されたときだけ、文字列をコードとして受け取る実行系。
# 無条件に載せると `bash .claude/scripts/src/create-commit.sh --message "..."` のような
# 通常の呼び出しまでフォールバックの対象になってしまう。
_CP_OPAQUE_WITH_OPT=' bash sh zsh ksh dash busybox python python3 perl ruby node deno pwsh powershell '

# 上記の実行系に「コードを文字列で渡す」意味を与えるオプション。
_CP_CODE_OPTS=' -c -e -E --command -command -encodedcommand '

# トークン走査中に、コード文字列を受け取りうる実行系を見つけたかどうか。
# command_invokes_git_subcommand のフォールバック判定が読む。
_CP_OPAQUE_FOUND=0

# シェルのコマンド文字列を正規化し、REPLY へ返す。
#
# クォート・コメント・ヒアドキュメント本文は、コマンド位置になりえないプレースホルダ `_` へ
# 潰す。ダブルクォート内の `$( )` / `` ` `` の中身だけはコードとして残す。
#
# 引数: $1 = コマンド文字列
# 戻り: REPLY = 正規化後の文字列
normalize_shell_command_to_reply() {
  local raw="$1"
  local -a lines=()
  # 行配列にしてから走査する。1文字ずつの `${s:i:1}` は文字列長に対して二乗のコストになり、
  # 10KB程度のヒアドキュメントで数百msかかる（issue #53の調査で実測）。
  mapfile -t lines <<<"$raw"

  local out='' state='code' rest head c prev=''
  local li=0 nlines=${#lines[@]}
  local paren=0
  # ダブルクォート内から `$( )` / `` ` `` でコードへ入ったときの復帰先。
  local -a ret_states=() ret_parens=() ret_closes=()
  # 未回収のヒアドキュメント区切り語（1行に複数書ける）。
  local -a hd_delims=() hd_strips=()

  while ((li < nlines)); do
    rest="${lines[li]}"

    while [[ -n $rest ]]; do
      case "$state" in
        code)
          head="${rest%%$_CP_CODE_CHARS*}"
          if ((${#head} == ${#rest})); then
            out+="$rest"
            prev="${rest: -1}"
            rest=''
            break
          fi
          out+="$head"
          [[ -n $head ]] && prev="${head: -1}"
          rest="${rest:${#head}}"
          c="${rest:0:1}"
          case "$c" in
            "'")
              state='sq'
              out+='_'
              prev='_'
              rest="${rest:1}"
              ;;
            '"')
              state='dq'
              out+='_'
              prev='_'
              rest="${rest:1}"
              ;;
            '#')
              # `#` がコメントを始めるのは語頭にあるときだけ。`foo#bar` の `#` は普通の文字。
              case "$prev" in
                '' | ' ' | $'\t' | $'\r' | ';' | '&' | '|' | '(' | ')' | '{' | '}' | "$_CP_BT")
                  out+='_'
                  prev='_'
                  rest=''
                  ;;
                *)
                  out+='#'
                  prev='#'
                  rest="${rest:1}"
                  ;;
              esac
              ;;
            '\')
              # エスケープされた1文字は、シェル上の意味を失うのでプレースホルダへ潰す。
              # 行末のバックスラッシュ（行継続）もここで消える。
              out+='_'
              prev='_'
              rest="${rest:2}"
              ;;
            "$_CP_BT")
              # コード中のバックティックは、開き・閉じのどちらもセパレータとして扱えば
              # 中身がコマンド位置として読める。ダブルクォートから入った区間なら、
              # ここが閉じなのでダブルクォートへ復帰する。
              if ((${#ret_states[@]} > 0)) && [[ "${ret_closes[-1]}" == "$_CP_BT" ]]; then
                state="${ret_states[-1]}"
                paren="${ret_parens[-1]}"
                unset 'ret_states[-1]' 'ret_parens[-1]' 'ret_closes[-1]'
              fi
              out+=" $_CP_BT "
              prev="$_CP_BT"
              rest="${rest:1}"
              ;;
            '(')
              paren=$((paren + 1))
              out+=' ( '
              prev='('
              rest="${rest:1}"
              ;;
            ')')
              if ((paren > 0)); then
                paren=$((paren - 1))
                out+=' ) '
                prev=')'
                rest="${rest:1}"
              elif ((${#ret_states[@]} > 0)) && [[ "${ret_closes[-1]}" == ')' ]]; then
                state="${ret_states[-1]}"
                paren="${ret_parens[-1]}"
                unset 'ret_states[-1]' 'ret_parens[-1]' 'ret_closes[-1]'
                out+=' ) '
                prev=')'
                rest="${rest:1}"
              else
                out+=' ) '
                prev=')'
                rest="${rest:1}"
              fi
              ;;
            '<')
              _cp_read_heredoc_open_to_reply "$rest"
              if [[ -n "$REPLY_CP_DELIM_SET" ]]; then
                hd_delims+=("$REPLY_CP_DELIM")
                hd_strips+=("$REPLY_CP_STRIP")
              fi
              out+="$REPLY"
              prev='_'
              rest="$REPLY_CP_REST"
              ;;
          esac
          ;;
        sq)
          # シングルクォートは改行をまたげる。閉じるまで中身をすべて捨てる。
          head="${rest%%$_CP_SQ_CHARS*}"
          if ((${#head} == ${#rest})); then
            rest=''
          else
            rest="${rest:${#head}+1}"
            state='code'
          fi
          ;;
        dq)
          head="${rest%%$_CP_DQ_CHARS*}"
          if ((${#head} == ${#rest})); then
            rest=''
            break
          fi
          rest="${rest:${#head}}"
          c="${rest:0:1}"
          case "$c" in
            '"')
              state='code'
              rest="${rest:1}"
              ;;
            '\')
              rest="${rest:2}"
              ;;
            '$')
              if [[ "${rest:1:1}" == '(' ]]; then
                ret_states+=('dq')
                ret_parens+=("$paren")
                ret_closes+=(')')
                state='code'
                paren=0
                out+=' ( '
                prev='('
                rest="${rest:2}"
              else
                rest="${rest:1}"
              fi
              ;;
            "$_CP_BT")
              ret_states+=('dq')
              ret_parens+=("$paren")
              ret_closes+=("$_CP_BT")
              state='code'
              paren=0
              out+=" $_CP_BT "
              prev="$_CP_BT"
              rest="${rest:1}"
              ;;
          esac
          ;;
      esac
    done

    # バックティックで開いたコード区間は、閉じのバックティックで dq へ戻す必要があるが、
    # 上のループでは `` ` `` をセパレータとして出力しているため戻り先を失う。
    # 実用上バックティックが行をまたぐことは無いので、行末で復帰させる。
    while ((${#ret_states[@]} > 0)) && [[ "${ret_closes[-1]}" == "$_CP_BT" ]]; do
      state="${ret_states[-1]}"
      paren="${ret_parens[-1]}"
      unset 'ret_states[-1]' 'ret_parens[-1]' 'ret_closes[-1]'
    done

    li=$((li + 1))
    out+="$_CP_NL"
    prev="$_CP_NL"

    # この行でヒアドキュメントが開いていたら、区切り行まで本文を読み飛ばす。
    if ((${#hd_delims[@]} > 0)); then
      local d strip body_line
      while ((${#hd_delims[@]} > 0)); do
        d="${hd_delims[0]}"
        strip="${hd_strips[0]}"
        hd_delims=("${hd_delims[@]:1}")
        hd_strips=("${hd_strips[@]:1}")
        while ((li < nlines)); do
          body_line="${lines[li]}"
          body_line="${body_line%$'\r'}"
          [[ "$strip" == '1' ]] && body_line="${body_line#"${body_line%%[!$'\t']*}"}"
          li=$((li + 1))
          [[ "$body_line" == "$d" ]] && break
        done
      done
      out+="_$_CP_NL"
      prev="$_CP_NL"
    fi
  done

  REPLY="$out"
}

# `<` から始まる並びを読み、ヒアドキュメントの開始なら区切り語を返す。
#
# 引数: $1 = `<` から始まる残り文字列
# 戻り:
#   REPLY               出力すべき文字列
#   REPLY_CP_REST       消費後の残り
#   REPLY_CP_DELIM_SET  ヒアドキュメントだったなら `1`、そうでなければ空
#   REPLY_CP_DELIM      区切り語
#   REPLY_CP_STRIP      `<<-` なら `1`（本文行の先頭タブを無視する）
_cp_read_heredoc_open_to_reply() {
  local r="$1"
  REPLY_CP_DELIM_SET=''
  REPLY_CP_DELIM=''
  REPLY_CP_STRIP='0'

  # `<<<`（ヒアストリング）と単なる `<`（リダイレクト）はヒアドキュメントではない。
  # `<<<` は3文字まとめて消費する。1文字ずつ返すと、残った `<<` を次の走査が
  # ヒアドキュメントの開始と誤認する。
  if [[ "${r:0:3}" == '<<<' ]]; then
    REPLY='<<<'
    REPLY_CP_REST="${r:3}"
    return 0
  fi
  if [[ "${r:0:2}" != '<<' ]]; then
    REPLY='<'
    REPLY_CP_REST="${r:1}"
    return 0
  fi

  r="${r:2}"
  if [[ "${r:0:1}" == '-' ]]; then
    REPLY_CP_STRIP='1'
    r="${r:1}"
  fi
  # 区切り語の前の空白を読み飛ばす。
  while [[ "${r:0:1}" == ' ' || "${r:0:1}" == $'\t' ]]; do r="${r:1}"; done

  # 区切り語を読む。クォート・バックスラッシュを取り除いた形が実際の区切りになる。
  local delim='' ch part
  while [[ -n $r ]]; do
    ch="${r:0:1}"
    case "$ch" in
      ' ' | $'\t' | $'\r' | ';' | '&' | '|' | '<' | '>' | '(' | ')') break ;;
      "'")
        r="${r:1}"
        part="${r%%$_CP_SQ_CHARS*}"
        delim+="$part"
        r="${r:${#part}}"
        r="${r#\'}"
        ;;
      '"')
        r="${r:1}"
        part="${r%%\"*}"
        delim+="$part"
        r="${r:${#part}}"
        r="${r#\"}"
        ;;
      '\')
        delim+="${r:1:1}"
        r="${r:2}"
        ;;
      *)
        delim+="$ch"
        r="${r:1}"
        ;;
    esac
  done

  REPLY_CP_DELIM_SET='1'
  REPLY_CP_DELIM="$delim"
  REPLY='_'
  REPLY_CP_REST="$r"
}

# 正規化済み文字列に `git <サブコマンド>` がコマンド位置で現れるかを判定する。
# 副作用として _CP_OPAQUE_FOUND を設定する。
#
# 引数: $1 = 正規化済み文字列 / $2 = サブコマンド（commit / push 等）
# 戻り: 0 = コマンド位置で一致 / 1 = 一致なし
_cp_scan_tokens() {
  local norm="$1" sub="${2,,}"
  _CP_OPAQUE_FOUND=0

  # セパレータを独立トークンへ切り出す（`x;git` のような連結を割るため）。
  local m
  for m in ';' '&' '|' '(' ')' '{' '}' "$_CP_BT"; do
    norm="${norm//"$m"/ $m }"
  done
  norm="${norm//"$_CP_NL"/ ; }"

  local -a tokens=()
  local IFS=$' \t\r\n'
  read -ra tokens <<<"$norm" || true

  local n=${#tokens[@]} i=0 j t u at_cmd=1 sticky=0 found=1
  while ((i < n)); do
    t="${tokens[i],,}"
    case "$t" in
      ';' | '&' | '|' | '(' | ')' | '{' | '}' | "$_CP_BT")
        at_cmd=1
        sticky=0
        i=$((i + 1))
        continue
        ;;
    esac

    if ((at_cmd || sticky)); then
      if [[ "$t" == 'git' ]]; then
        j=$((i + 1))
        while ((j < n)); do
          u="${tokens[j],,}"
          case "$u" in
            ';' | '&' | '|' | '(' | ')' | '{' | '}' | "$_CP_BT") break ;;
            '-c') j=$((j + 2)) ;;
            -*) j=$((j + 1)) ;;
            *) break ;;
          esac
        done
        if ((j < n)) && [[ "${tokens[j],,}" == "$sub" ]]; then
          found=0
        fi
        at_cmd=0
      elif [[ "$t" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
        : # 変数代入。コマンド位置は次のトークンへ持ち越す
      elif [[ "$_CP_PREFIX_WORDS" == *" $t "* ]]; then
        # 透過的なラッパー・予約語。次のセパレータまでコマンド位置を保ち続ける
        # （オプションとその引数が間に挟まる形へ対応するため）。
        sticky=1
      else
        if [[ "$_CP_OPAQUE_WORDS" == *" $t "* ]]; then
          _CP_OPAQUE_FOUND=1
        elif [[ "$_CP_OPAQUE_WITH_OPT" == *" $t "* ]]; then
          j=$((i + 1))
          while ((j < n)); do
            u="${tokens[j],,}"
            case "$u" in
              ';' | '&' | '|' | '(' | ')' | '{' | '}' | "$_CP_BT") break ;;
            esac
            if [[ "$_CP_CODE_OPTS" == *" $u "* ]]; then
              _CP_OPAQUE_FOUND=1
              break
            fi
            j=$((j + 1))
          done
        fi
        at_cmd=0
      fi
    fi
    i=$((i + 1))
  done

  return "$found"
}

# コマンド文字列が `git <サブコマンド>` を実行するかを判定する。
#
# 引数: $1 = コマンド文字列 / $2 = サブコマンド（commit / push 等）
# 戻り: 0 = 実行するとみなす（ブロック・検知の対象）/ 1 = 対象外
command_invokes_git_subcommand() {
  local s="${1:-}" sub="${2:?サブコマンドを指定すること}"
  [[ -n $s ]] || return 1

  normalize_shell_command_to_reply "$s"
  if _cp_scan_tokens "$REPLY" "$sub"; then
    return 0
  fi

  # 位置判定では一致しなかったが、文字列をコードとして受け取りうる実行系が
  # コマンド位置にある場合は、従来どおりの部分一致で保守的にブロックする。
  ((_CP_OPAQUE_FOUND)) || return 1
  local lower="${s,,}"
  [[ "$lower" =~ git[[:space:]]+${sub,,} ]] || return 1
  return 0
}
