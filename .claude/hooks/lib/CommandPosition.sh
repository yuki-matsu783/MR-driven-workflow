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
#      非オプショントークンが目的のサブコマンドかを見る。コマンド名はパスの末尾で比べ、
#      `.exe` は落とす（`/usr/bin/git` `./git` `git.exe` も同じ呼び出しであるため）。
#
# 位置判定で一致しなかった場合でも、**文字列をコードとして受け取りうる実行系**
# （`eval` / `bash -c` / `xargs` / `find` 等）がコマンド位置にあり、かつ従来の部分一致が
# 成立する場合は、保守的にブロック側へ倒す（素通りを増やさないため）。
#
# 意図的な文字列分割（`git "commit"` 等）による回避には対応しない。これは敵対的な
# 安全境界ではなく「既定動作を確実な方向へ倒す仕組み」であるため
# （.claude/docs/ddr/i0000-09-コミットはcommitスキル経由を機構的に強制する.md）。
#
# **bash 4.3以上を必要とする**（`mapfile` / `${var,,}` / `${arr[-1]}` / `unset 'arr[-1]'`）。
# 呼び出し側のhookは、バージョンと `source` の成否・関数の存在を確かめたうえで、満たさない
# 場合は従来どおりの部分一致へ落とす責任を持つ（`set -e` 配下では `source` の失敗が
# そのまま終了コードになり、PreToolUseでは無関係なコマンドまでブロックされるため）。

# 改行・バックティックはリテラルとして書くと引用の解釈が絡んで読みにくいため定数へ逃がす。
_CP_NL=$'\n'
_CP_BT='`'

# パターンは `$'...'` で組み立ててから、パラメータ展開の中へ**クォートせず**展開する。
# ダブルクォートの中へブラケット式を直接書くと、`\\` と `\'` の解釈がシェルとパターン照合で
# 二重にかかり、意図した文字集合にならない（バックスラッシュが集合から落ちる）。
_CP_CODE_CHARS=$'[\'"#\\\\`<()$\n]'
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

# 値を**別のトークン**で取るgitのグローバルオプション。これらは2トークン読み飛ばす。
# `--git-dir=/x/.git` のように `=` で繋ぐ形は1トークンなのでここには載らない。
# 判定は小文字化した文字列で行うため、`-c`（設定）と `-C`（ディレクトリ）は同じ項目になる。
# どちらも値を1つ取るので区別する必要は無い。
_CP_GIT_OPTS_WITH_VALUE=' -c --git-dir --work-tree --namespace --exec-path --super-prefix '

# 値を**別のトークン**で取る、_CP_PREFIX_WORDS配下のコマンド（sudo/env/nice/ionice/timeout/
# stdbuf等）のオプション。_cp_scan_tokens_for_script が使う（issue #149, 2回目レビュー）。
# if/then等、そもそもこれらのオプションを取らない語には影響しない
# （該当する文字列がその語の直後に現れることが無いため）。
_CP_PREFIX_OPTS_WITH_VALUE=' -u -g -p -h -r -t -c -a -n -s -k -i -o -e '

# 最初の非オプション・非代入引数が「値」であり実コマンドではない prefix語
# （`timeout DURATION COMMAND...` の語順のため）。_cp_scan_tokens_for_script が使う。
_CP_PREFIX_WORDS_WITH_LEADING_VALUE=' timeout '

# インタプリタ経由の実行で、コードを実行しない（構文チェックのみ等の）オプション。
# シェル系インタプリタに限って対象にする。python/perl/rubyは`-n`の意味が異なり
# （実行はする）、誤って検知漏れを増やすため対象に含めない（issue #149, 2回目レビュー）。
_CP_SHELL_INTERPRETERS=' bash sh zsh ksh dash busybox '
_CP_NONEXEC_OPTS=' -n '

# 正規化を行う1行あたりの長さの上限。
# 行内の走査は「次の関心文字まで読み飛ばして残りを切り出す」形のため、**1行の中の
# 関心文字の数に対して二乗**になる（行数に対しては線形）。特殊文字を多く含む極端に長い1行
# （実測: 16KB・関心文字4000個で約1.2秒）では、毎ツール呼び出しで走るhookの遅延として
# 現れる。上限を超える行がある場合は正規化を諦め、**従来どおりの部分一致**へ落とす
# （誤検知は残るが、素通りもタイムアウトも起こさない側へ倒す）。
_CP_MAX_LINE_LENGTH=8192

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
  # 行末のバックスラッシュ（行継続）で、次の行を同じ論理行として続けるかどうか。
  local line_cont=0
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
              if ((${#rest} == 1)); then
                # 行末のバックスラッシュは行継続。区切りを作らずに次の行を連結する。
                # `cd src && \` の次行はコマンド位置だが `echo \` の次行は引数の続きで、
                # 連結すればどちらも正しく判定できる（区切りを入れると前者しか合わない）。
                line_cont=1
                rest=''
              else
                # エスケープされた1文字はシェル上の意味を失う。ただし `\git` のように語を
                # 構成する文字はそのまま残す（`\git commit` はエイリアスを迂回してgitを
                # 実行する定番の書式で、実行そのものは普通に行われるため）。区切りになりうる
                # 文字はプレースホルダへ潰す（`echo \;git` の `;` を区切りとして読むと、
                # 後続が誤ってコマンド位置になる）。
                c="${rest:1:1}"
                case "$c" in
                  [A-Za-z0-9_./-]) out+="$c" ;;
                  *)
                    out+='_'
                    c='_'
                    ;;
                esac
                prev="$c"
                rest="${rest:2}"
              fi
              ;;
            '$')
              # 算術式 `$((...))` の中の `<<` は左シフトであってヒアドキュメントではない。
              if [[ "${rest:1:2}" == '((' ]]; then
                _cp_skip_arithmetic_to_reply "$rest"
                out+="$REPLY"
                prev='_'
                rest="$REPLY_CP_REST"
              else
                out+='$'
                prev='$'
                rest="${rest:1}"
              fi
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

    # 閉じないバックティックで開いたコード区間は、行末でダブルクォートへ復帰させる
    # （実用上バックティックが行をまたぐことは無い）。
    while ((${#ret_states[@]} > 0)) && [[ "${ret_closes[-1]}" == "$_CP_BT" ]]; do
      state="${ret_states[-1]}"
      paren="${ret_parens[-1]}"
      unset 'ret_states[-1]' 'ret_parens[-1]' 'ret_closes[-1]'
    done

    li=$((li + 1))
    if ((line_cont)); then
      line_cont=0
    else
      out+="$_CP_NL"
      prev="$_CP_NL"
    fi

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

# `$((` から始まる算術式を、対応する `))` まで読み飛ばす。
# 算術式の中の `<<` は左シフトであってヒアドキュメントではない。これを取り違えると
# 「区切り語が現れるまで残り全行を本文として捨てる」ため、以降のコマンドがまとめて
# 素通りする（issue #53 の敵対的レビューで検出）。
#
# 引数: $1 = `$((` から始まる残り文字列
# 戻り: REPLY = 出力すべき文字列 / REPLY_CP_REST = 消費後の残り
_cp_skip_arithmetic_to_reply() {
  local r="$1" i=1 depth=0 ch
  local n=${#r}
  while ((i < n)); do
    ch="${r:i:1}"
    case "$ch" in
      '(') depth=$((depth + 1)) ;;
      ')')
        depth=$((depth - 1))
        if ((depth == 0)); then
          REPLY='_'
          REPLY_CP_REST="${r:i+1}"
          return 0
        fi
        ;;
    esac
    i=$((i + 1))
  done
  # 対応する `))` が同じ行に無い場合は、算術式と決めつけず `$` 1文字だけを消費する
  # （残りをまとめて捨てると、その先のコマンドが検知対象から消えてしまう）。
  REPLY='$'
  REPLY_CP_REST="${r:1}"
  return 0
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

  # 区切り語が空、または数字だけの場合はヒアドキュメントとみなさない。算術式の取りこぼし
  # （`$((1<<2))`）に対する二重の網である。誤ってヒアドキュメント扱いすると以降の行が
  # まとめて素通りする方向へ倒れるため、ここは保守側へ寄せる。
  if [[ -z "$delim" || "$delim" =~ ^[0-9]+$ ]]; then
    REPLY='_'
    REPLY_CP_REST="$r"
    return 0
  fi

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

  local n=${#tokens[@]} i=0 j t u base at_cmd=1 sticky=0 found=1
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
    # `/usr/bin/git` `./git` `git.exe` も同じ呼び出しなので、パスの末尾と `.exe` を落として
    # 比べる（旧実装は部分一致だったためパス付きの起動もブロックしていた。ここを見ないと
    # 機能後退になる）。
    base="${t##*/}"
    base="${base%.exe}"

    if ((at_cmd || sticky)); then
      # コマンドの前に置かれたリダイレクト（`>out.txt git commit` / `2> err git commit`）は、
      # コマンド位置を保ったまま読み飛ばす。演算子だけのトークンなら、その次のトークン
      # （リダイレクト先）も読み飛ばす。
      if [[ "$t" =~ ^[0-9]*[\<\>]+ ]]; then
        [[ "$t" =~ ^[0-9]*[\<\>]+$ ]] && i=$((i + 1))
        i=$((i + 1))
        continue
      fi

      if [[ "$base" == 'git' ]]; then
        j=$((i + 1))
        while ((j < n)); do
          u="${tokens[j],,}"
          case "$u" in
            ';' | '&' | '|' | '(' | ')' | '{' | '}' | "$_CP_BT") break ;;
            *)
              if [[ "$_CP_GIT_OPTS_WITH_VALUE" == *" $u "* ]]; then
                j=$((j + 2))
              elif [[ "$u" == -* ]]; then
                j=$((j + 1))
              else
                break
              fi
              ;;
          esac
        done
        if ((j < n)) && [[ "${tokens[j],,}" == "$sub" ]]; then
          found=0
        fi
        at_cmd=0
      elif [[ "$t" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
        : # 変数代入。コマンド位置は次のトークンへ持ち越す
      elif [[ "$_CP_PREFIX_WORDS" == *" $base "* ]]; then
        # 透過的なラッパー・予約語。次のセパレータまでコマンド位置を保ち続ける
        # （オプションとその引数が間に挟まる形へ対応するため）。
        sticky=1
      else
        if [[ "$_CP_OPAQUE_WORDS" == *" $base "* ]]; then
          _CP_OPAQUE_FOUND=1
        elif [[ "$_CP_OPAQUE_WITH_OPT" == *" $base "* ]]; then
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

# _CP_MAX_LINE_LENGTH を超える行が含まれるかを返す。
# 戻り: 0 = 超える行がある / 1 = 無い
_cp_has_overlong_line() {
  # 全体が上限以下なら、どの行も上限以下である（行分割の前に安く弾く）。
  ((${#1} > _CP_MAX_LINE_LENGTH)) || return 1
  local -a lines=()
  local line
  mapfile -t lines <<<"$1"
  for line in "${lines[@]}"; do
    ((${#line} > _CP_MAX_LINE_LENGTH)) && return 0
  done
  return 1
}

# コマンド文字列が `git <サブコマンド>` を実行するかを判定する。
#
# 引数: $1 = コマンド文字列 / $2 = サブコマンド（commit / push 等）
# 戻り: 0 = 実行するとみなす（ブロック・検知の対象）/ 1 = 対象外
command_invokes_git_subcommand() {
  local s="${1:-}" sub="${2:?サブコマンドを指定すること}"
  [[ -n $s ]] || return 1

  local lower="${s,,}"
  # 極端に長い行を含む場合は正規化を諦め、従来どおりの部分一致で判定する
  # （上記 _CP_MAX_LINE_LENGTH の説明を参照）。
  if _cp_has_overlong_line "$s"; then
    [[ "$lower" =~ git[[:space:]]+${sub,,} ]] && return 0
    return 1
  fi

  normalize_shell_command_to_reply "$s"
  if _cp_scan_tokens "$REPLY" "$sub"; then
    return 0
  fi

  # 位置判定では一致しなかったが、文字列をコードとして受け取りうる実行系が
  # コマンド位置にある場合は、従来どおりの部分一致で保守的にブロックする。
  ((_CP_OPAQUE_FOUND)) || return 1
  [[ "$lower" =~ git[[:space:]]+${sub,,} ]] || return 1
  return 0
}

# 正規化済み文字列に、指定したスクリプト（basename）がコマンド位置で現れるかを判定する。
# 副作用として _CP_OPAQUE_FOUND を設定する（issue #149）。
#
# `_cp_scan_tokens`（git専用）とは次の点で異なる:
#
# 1. `_CP_PREFIX_WORDS`（sudo/if/timeout等）を通ったあとは、**次の非オプション・非代入トークンを
#    実コマンドとして1回だけ判定し、そこでコマンド位置を終える**（`_cp_scan_tokens`はセパレータ
#    まえコマンド位置を保ち続ける。gitのような「離れた位置にある固定語1つを探す」判定では実害が
#    小さいが、任意のスクリプトbasenameを探す判定でこれを真似ると、`sudo cat <スクリプトパス>`
#    のように無関係なコマンドの引数に現れただけで誤って一致してしまう。敵対的レビュー
#    （issue #149, 1回目）で検出）。
# 2. `{`/`}` をトークン化のための人工的な空白挿入の対象に**含めない**（`_cp_scan_tokens`は
#    含める）。`${VAR}/path` のようなパラメータ展開は、`{`側は`$`に、`}`側は変数名に隙間なく
#    連結されているため元々1トークンのままであり、意図せず分割すると `}` の直後（実際には
#    パスの続き）が誤ってコマンド位置として扱われる（同じくissue #149, 1回目で検出）。
#    ブレースグループ（`{ cmd; }`）は、bash構文上 `{`/`}` の前後に空白が必須のため、この人工的な
#    挿入が無くても素の空白分割で独立トークンになり、判定は変わらない。
#
# 引数: $1 = 正規化済み文字列 / $2 = 対象スクリプトのbasename（小文字化済み）
# 戻り: 0 = コマンド位置で一致 / 1 = 一致なし
_cp_scan_tokens_for_script() {
  local norm="$1" target="$2"
  _CP_OPAQUE_FOUND=0

  local m
  for m in ';' '&' '|' '(' ')' "$_CP_BT"; do
    norm="${norm//"$m"/ $m }"
  done
  norm="${norm//"$_CP_NL"/ ; }"

  local -a tokens=()
  local IFS=$' \t\r\n'
  read -ra tokens <<<"$norm" || true

  local n=${#tokens[@]} i=0 j t u base ubase at_cmd=1 found=1 code_opt noexec hit_sep
  while ((i < n)); do
    t="${tokens[i]}"
    case "${t,,}" in
      ';' | '&' | '|' | '(' | ')' | '{' | '}' | "$_CP_BT")
        at_cmd=1
        i=$((i + 1))
        continue
        ;;
    esac

    if ((!at_cmd)); then
      i=$((i + 1))
      continue
    fi

    # コマンドの前に置かれたリダイレクトは、コマンド位置を保ったまま読み飛ばす。
    if [[ "$t" =~ ^[0-9]*[\<\>]+ ]]; then
      [[ "$t" =~ ^[0-9]*[\<\>]+$ ]] && i=$((i + 1))
      i=$((i + 1))
      continue
    fi

    t="${t,,}"

    if [[ "$t" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
      # 変数代入。コマンド位置は次のトークンへ持ち越す。
      # target一致の判定より先に見る（`SCRIPT=<path>/create-issue.sh` のような代入を、
      # `${t##*/}` で削った結果が偶然targetと一致して誤検知しないため。issue #149, 2回目レビュー）。
      i=$((i + 1))
      continue
    fi

    base="${t##*/}"
    base="${base%.exe}"

    if [[ "$base" == "$target" ]]; then
      found=0
      break
    fi

    if [[ "$_CP_OPAQUE_WORDS" == *" $base "* ]]; then
      _CP_OPAQUE_FOUND=1
      at_cmd=0
      i=$((i + 1))
      continue
    fi

    if [[ "$_CP_OPAQUE_WITH_OPT" == *" $base "* ]]; then
      # インタプリタ経由。直後の非オプショントークン（コード文字列オプションが挟まれば除く）が
      # 対象スクリプトかを見る。
      j=$((i + 1))
      code_opt=0
      noexec=0
      hit_sep=0
      while ((j < n)); do
        case "${tokens[j],,}" in
          ';' | '&' | '|' | '(' | ')' | '{' | '}' | "$_CP_BT")
            hit_sep=1
            break
            ;;
        esac
        u="${tokens[j],,}"
        if [[ "$_CP_CODE_OPTS" == *" $u "* ]]; then
          code_opt=1
          break
        elif [[ "$_CP_SHELL_INTERPRETERS" == *" $base "* ]] && [[ "$_CP_NONEXEC_OPTS" == *" $u "* ]]; then
          # `bash -n` 等の構文チェックのみのオプション。実行はしないため、後段の判定へは
          # 進めるが検知対象にはしない（issue #149, 2回目レビュー）。他のオプションと
          # 組み合わせられる可能性があるため、ここでは break せず走査を続ける。
          noexec=1
          j=$((j + 1))
        elif [[ "$u" == -* ]]; then
          j=$((j + 1))
        else
          break
        fi
      done
      if ((code_opt)); then
        _CP_OPAQUE_FOUND=1
      elif ((noexec)); then
        : # 実行しないオプションが付いている。検知対象にしない。
      elif ((!hit_sep)) && ((j < n)); then
        ubase="${tokens[j],,}"
        ubase="${ubase##*/}"
        ubase="${ubase%.exe}"
        if [[ "$ubase" == "$target" ]]; then
          found=0
          break
        elif [[ "${tokens[j]}" == '_' ]]; then
          # 引数がクォート等でプレースホルダへ潰れている。中身は分からないが対象を
          # 含む可能性があるため、保守的フォールバック（部分一致）の対象にする
          # （issue #149, 2回目レビュー。`bash "$VAR/create-issue.sh"` 等）。
          _CP_OPAQUE_FOUND=1
        fi
      fi
      at_cmd=0
      i=$((i + 1))
      continue
    fi

    if [[ "$_CP_PREFIX_WORDS" == *" $base "* ]]; then
      # 透過的なラッパー・予約語。次のセパレータまでではなく、次の非オプション・非代入トークン
      # 「実コマンド」を1回だけ判定へ通す（上記コメント参照）。
      j=$((i + 1))
      hit_sep=0
      while ((j < n)); do
        case "${tokens[j],,}" in
          ';' | '&' | '|' | '(' | ')' | '{' | '}' | "$_CP_BT")
            hit_sep=1
            break
            ;;
        esac
        case "${tokens[j]}" in
          -*)
            # 値を別トークンで取るオプション（`sudo -u alice` 等）は、そのオプションの値も
            # あわせて読み飛ばす。読み飛ばさないと値トークンを実コマンドと誤認し、直後の
            # 本当のコマンドを見なくなる（issue #149, 2回目レビュー）。
            if [[ "$_CP_PREFIX_OPTS_WITH_VALUE" == *" ${tokens[j],,} "* ]]; then
              j=$((j + 2))
            else
              j=$((j + 1))
            fi
            ;;
          *)
            if [[ "${tokens[j]}" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
              j=$((j + 1))
            else
              break
            fi
            ;;
        esac
      done
      # `timeout DURATION COMMAND...` のように、オプション読み飛ばし後の最初の非オプション
      # 引数自体が値（実コマンドではない）である語は、その1トークンをさらに読み飛ばす
      # （issue #149, 2回目レビュー）。
      if ((!hit_sep)) && [[ "$_CP_PREFIX_WORDS_WITH_LEADING_VALUE" == *" $base "* ]] && ((j < n)); then
        case "${tokens[j],,}" in
          ';' | '&' | '|' | '(' | ')' | '{' | '}' | "$_CP_BT") hit_sep=1 ;;
          *) j=$((j + 1)) ;;
        esac
      fi
      if ((!hit_sep)) && ((j < n)); then
        i=$j
        continue
      fi
      at_cmd=0
      i=$((i + 1))
      continue
    fi

    # 一致しない通常のコマンド。コマンド位置をここで終える。
    at_cmd=0
    i=$((i + 1))
  done

  return "$found"
}

# コマンド文字列が、指定したスクリプト（basename）をコマンド位置で実行するかを判定する。
#
# 単体実行（パス付き・`.exe`付きでも末尾のbasenameが一致すれば可）と、インタプリタ経由の実行
# （`bash <path>` 等。直後にコード文字列オプションが来る場合は対象外）の両方を検知する。
# `cat` / `grep` のように無関係なコマンドの引数に現れるだけでは一致しない。
#
# 既知の制約（issue #149）: クォートで囲まれたスクリプトパス（`bash "$VAR/create-issue.sh"` 等）と、
# PowerShell経路でのバックスラッシュ区切りパス（`.claude\scripts\src\create-issue.sh`）は、
# `normalize_shell_command_to_reply` の正規化の性質上検知できない（前者はクォート内容がプレース
# ホルダへ潰れるため、後者はバックスラッシュがエスケープとして解決されパス区切りごと失われる
# ため。後者は `command_invokes_git_subcommand` も共有する既存の制約であり、本関数が新たに
# 生んだものではない）。詳細: `.claude/docs/spec/command-position.md`。
#
# 引数: $1 = コマンド文字列 / $2 = 対象スクリプトのbasename（例: create-issue.sh）
# 戻り: 0 = コマンド位置で実行される / 1 = 対象外
command_invokes_script() {
  local s="${1:-}" script="${2:?スクリプト名を指定すること}"
  [[ -n $s ]] || return 1

  # 呼び出し側がパス付き・大文字混じりで渡した場合の表記ゆれを吸収する。
  local script_lower="${script,,}"
  script_lower="${script_lower##*/}"
  script_lower="${script_lower%.exe}"

  local lower="${s,,}"
  if _cp_has_overlong_line "$s"; then
    [[ "$lower" == *"$script_lower"* ]] && return 0
    return 1
  fi

  normalize_shell_command_to_reply "$s"
  if _cp_scan_tokens_for_script "$REPLY" "$script_lower"; then
    return 0
  fi

  # 位置判定では一致しなかったが、文字列をコードとして受け取りうる実行系が
  # コマンド位置にある場合は、従来どおりの部分一致で保守的に倒す
  # （command_invokes_git_subcommand と同じ設計原則）。
  ((_CP_OPAQUE_FOUND)) || return 1
  [[ "$lower" == *"$script_lower"* ]] || return 1
  return 0
}
