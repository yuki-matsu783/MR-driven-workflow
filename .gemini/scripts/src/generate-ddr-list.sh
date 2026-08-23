#!/usr/bin/env bash
#
# `.claude/docs/README.md` のDDR一覧を、DDRファイルのfrontmatterから生成する（issue #135）。
#
# 一覧はDDRを追加するたびに手書きで1行足す運用になっており、ファイル末尾への追記構造のため
# 2ブランチが同時にDDRを追加すると毎回テキストコンフリクトしていた（`resolve-conflict` の類型C）。
# 解消のたびに一覧全体を読み直して番号順へ並べ直す手作業が発生し、そのつど出力トークンを消費する。
# 一覧を生成物にすることで、コンフリクトは「片側を捨てて再生成」で終わる（類型B相当）。
#
# **生成結果はGit管理下に置きコミットする**（`index.jsonl` と違い `.gitignore` に加えない）。
# GitHub上で人間が開く目次であり、Git管理外にするとブラウザで見えず、clone直後にも存在しない。
# 加えてClaude CodeのGrepツール（ripgrep）は既定で `.gitignore` を尊重するため全文探索から消える。
# 詳細・却下案: `.claude/docs/ddr/i0135-01-DDR一覧は生成物にしつつGit管理下へ残す.md`
#
# 使い方:
#   generate-ddr-list.sh [--check] [--print] [--ddr-dir <パス>] [--readme <パス>]
#                        [--link-prefix <文字列>] [-h|--help]
#
#   --check              ... 書き換えず、再生成すると差分が出るかだけを判定する
#   --print              ... 書き換えず、生成した一覧そのものをstdoutへ出す（JSONは出さない）
#   --ddr-dir <パス>     ... DDRディレクトリ（既定: .mrworkflow.json の ddrDirs[0]）
#   --readme <パス>      ... 書き換え対象（既定: <ddr-dirの親>/README.md）
#   --link-prefix <文字列> ... リンクURLの接頭辞（既定: readmeからddr-dirへの相対パス + "/"）
#
# 出力: 実行内容のJSONをstdoutへ1つ出力する（`cleanup-task.sh` と同じ規約）。
#   {"check":false,"print":false,"repoRoot":"...","ddrDir":"...","readme":"...",
#    "linkPrefix":"ddr/","count":55,"changed":true,"written":true}
#   `--print` のときだけ、JSONではなく一覧そのものをstdoutへ出す。
#   人間向けの進捗ログは常にstderrへ出す（stdoutをJSONだけに保ち `jq` でそのまま読めるようにするため）。
#
# 終了コード:
#   0 = 成功（既定・`--print`）／`--check` で差分が無かった
#   1 = 失敗（引数不正・マーカー不在・DDRが1件も無い等）
#   2 = `--check` で差分があった（「失敗」ではなく「再生成が必要」を表すため1と区別する）
#
# 仕様: .claude/docs/spec/generate-ddr-list.md
# 規約: .claude/rules/shell-script-style.md
#   （set -euo pipefail / ループ内で外部コマンドを呼ばない / 日本語ファイル名を壊さない）
set -euo pipefail

# 置き換える区間を囲むマーカー。**この2行自体は書き換えず、間の行だけを差し替える。**
# 区間を推測しない（マーカーが無ければエラーで止まる）のは、見出しの位置や前後の地の文が
# 変わったときに、一覧と無関係な行を巻き込んで消さないため。
readonly GDL_BEGIN_MARKER='<!-- BEGIN GENERATED: ddr-list -->'
readonly GDL_END_MARKER='<!-- END GENERATED: ddr-list -->'

usage() {
  cat >&2 <<'USAGE'
usage: generate-ddr-list.sh [オプション]

  DDRファイルのfrontmatterから、.claude/docs/README.md のDDR一覧を生成して置き換える。

  --check                 書き換えず、再生成で差分が出るかだけを判定する（差分ありなら終了コード2）
  --print                 書き換えず、生成した一覧をstdoutへ出す（JSONは出さない）
  --ddr-dir <パス>        DDRディレクトリ（既定: .mrworkflow.json の ddrDirs[0]）
  --readme <パス>         書き換え対象のmarkdown（既定: <ddr-dirの親>/README.md）
  --link-prefix <文字列>  リンクURLの接頭辞（既定: readmeからddr-dirへの相対パス + "/"）
  -h, --help              この使い方を表示する

例:
  generate-ddr-list.sh              # README.md を書き換える
  generate-ddr-list.sh --check      # 差分の有無だけを見る（CI・テスト向け）
  generate-ddr-list.sh --print      # 生成結果を確認する
USAGE
}

# ---------------------------------------------------------------------------
# 純粋関数（外部コマンドを呼ばない。.claude/scripts/test/test_generate_ddr_list.sh の対象）
# ---------------------------------------------------------------------------

# markdownのリンク先として安全な表記へ整える。
#
# markdownのインラインリンク `[text](url)` は、URL中の括弧で閉じ位置が狂う。GitHubを含む
# CommonMark実装は `<...>` で囲んだURLを受け付けるため、括弧・空白を含む場合だけそちらを使う
# （現在のDDRファイル名には括弧も空白も無いが、`.claude/rules/markdown-frontmatter.md` は
#  ファイル名の文字種を制限していないため、将来足されても壊れないようにしておく）。
# 結果は $REPLY へ返す（ホットパスの小さなヘルパーはforkを避けるため標準出力を使わない）。
gdl_link_target_to_reply() {
  local url="$1"
  case "$url" in
    *'('* | *')'* | *' '*) REPLY="<$url>" ;;
    *) REPLY="$url" ;;
  esac
}

# frontmatterの status / superseded_by / note から、一覧行の末尾に付ける注記を組み立てる。
#
# 引数: $1=status $2=superseded_by $3=note
# 出力: $REPLY（注記が無ければ空文字列）
#
# status由来の注記が先、note由来が後。両方を持つDDRは現時点で無いが、順序を決めておかないと
# 片方を足したときに一覧全体の差分になるため固定する。
gdl_annotation_to_reply() {
  local status="$1" superseded_by="$2" note="$3"
  REPLY=''
  case "$status" in
    superseded)
      if [ -n "$superseded_by" ]; then
        REPLY=' ── **`status: superseded`（'"$superseded_by"'により置き換え）**'
      else
        REPLY=' ── **`status: superseded`**'
      fi
      ;;
    deprecated) REPLY=' ── **`status: deprecated`**' ;;
    '' | active) ;;
    *) REPLY=' ── **`status: '"$status"'`**' ;;
  esac
  [ -n "$note" ] && REPLY="$REPLY（$note）"
  return 0
}

# 一覧の1行を組み立てる。
#
# 引数: $1=ファイル名 $2=リンク接頭辞 $3=status $4=superseded_by $5=note
# 出力: $REPLY
gdl_list_line_to_reply() {
  local filename="$1" link_prefix="$2" status="$3" superseded_by="$4" note="$5"
  local target annotation
  gdl_link_target_to_reply "$link_prefix$filename"
  target="$REPLY"
  gdl_annotation_to_reply "$status" "$superseded_by" "$note"
  annotation="$REPLY"
  REPLY="- [$filename]($target)$annotation"
}

# YAMLのスカラー値から、囲みのクォートを1組だけ外す。
# 出力: $REPLY
gdl_unquote_to_reply() {
  local value="$1" len=${#1}
  if [ "$len" -ge 2 ]; then
    case "$value" in
      '"'*'"' | "'"*"'") value="${value:1:len-2}" ;;
    esac
  fi
  REPLY="$value"
}

# readme から ddr_dir を指すリンク接頭辞を求める。
#
# 引数: $1=readmeのリポジトリ相対パス $2=ddrディレクトリのリポジトリ相対パス
# 出力: $REPLY（末尾は "/"。同じディレクトリなら空文字列）
# 戻り値: readmeのあるディレクトリの配下にddr_dirが無ければ1（呼び出し側で --link-prefix を促す）
#
# READMEとDDRディレクトリが「親子」でない配置（`../` を挟む必要がある配置）はこのリポジトリに
# 存在しないため、ここでは扱わずエラーにして明示指定を促す（誤った相対パスを黙って出さない）。
gdl_link_prefix_to_reply() {
  local readme="$1" ddr_dir="$2" readme_dir
  readme_dir="${readme%/*}"
  [ "$readme_dir" = "$readme" ] && readme_dir='.'
  if [ "$readme_dir" = "$ddr_dir" ]; then
    REPLY=''
    return 0
  fi
  if [ "$readme_dir" = '.' ]; then
    REPLY="$ddr_dir/"
    return 0
  fi
  case "$ddr_dir/" in
    "$readme_dir"/*)
      REPLY="${ddr_dir#"$readme_dir"/}/"
      return 0
      ;;
  esac
  REPLY=''
  return 1
}

# ---------------------------------------------------------------------------
# 入出力を伴う処理
# ---------------------------------------------------------------------------

gdl_log() { printf '%s\n' "$*" >&2; }
gdl_die() {
  printf 'generate-ddr-list.sh: %s\n' "$*" >&2
  exit 1
}

# DDRディレクトリ配下の *.md すべてから、frontmatterの status / superseded_by / note を取り出す。
#
# **awkの起動は全体で1回だけ**にする（`.claude/rules/shell-script-style.md`「外部プロセス起動の
# コスト」。1ファイル1回の起動にすると、ファイル数に比例して所要時間が伸びる）。
# 出力は1ファイル1行の、**US（0x1f）区切り**:
#   <ファイル名>\x1f<status>\x1f<superseded_by>\x1f<note>\x1f<frontmatterがあれば1>
#
# タブ区切りにしないのは、bashの `read` がタブを**IFS空白文字**として扱い、連続する区切りを
# 1つへ畳んでしまうためである（実機確認: `printf 'A\t\t\tD' | IFS=$'\t' read -r a b c d` は
# b=D になり、空フィールドが消えて値が1つ前へずれる）。status と superseded_by が両方空の
# DDR（＝大多数）で note が status の位置へ入り込む、という形で表面化した。
# 0x1f はIFS空白文字ではないため、連続しても空フィールドがそのまま保たれる。
gdl_read_frontmatter() {
  local bom
  bom="$(printf '\357\273\277')"
  # シングルクォートはawkプログラム（シングルクォートで囲む）の中へ直接書けないため変数で渡す。
  awk -v bom="$bom" -v sq="'" '
    { sub(/\r$/, "") }
    function emit() {
      if (name != "") printf "%s\037%s\037%s\037%s\037%s\n", name, status, superseded_by, note, has_fm
    }
    FNR == 1 {
      emit()
      name = FILENAME
      sub(/.*\//, "", name)
      status = ""; superseded_by = ""; note = ""; in_fm = 0; closed = 0; has_fm = 0
      # UTF-8 BOM を落としてから判定する。落とさないと1行目が "---" と一致せず、
      # frontmatter を丸ごと見落として status を黙って捨てることになる。
      if (substr($0, 1, 3) == bom) $0 = substr($0, 4)
      if ($0 == "---") { in_fm = 1; has_fm = 1 }
      next
    }
    closed { next }
    in_fm && $0 == "---" { closed = 1; next }
    in_fm && /^(status|superseded_by|note)[[:space:]]*:/ {
      key = $0
      sub(/[[:space:]]*:.*$/, "", key)
      value = $0
      sub(/^[^:]*:[[:space:]]*/, "", value)
      # 行内コメントを落とす。YAMLでは空白に続く "#" 以降がコメントであり、
      # `superseded_by: "0019"  # 理由` の "# 理由" が値へ混ざると注記が壊れる。
      # クォート済みスカラーは閉じクォートまでを値とし、その後ろを捨てる
      # （クォート内の "#" は本文である。実際に note が "issue #97" を含む）。
      q = substr(value, 1, 1)
      if (q == "\"" || q == sq) {
        i = index(substr(value, 2), q)
        if (i > 0) value = substr(value, 1, i + 1)
      } else {
        sub(/[[:space:]]+#.*$/, "", value)
      }
      # 末尾の空白を落とす。落とさないと "status: superseded   " が superseded の分岐へ
      # 入らず、置き換え先の注記が消える（YAMLとしては正当な書き方であるため実際に起こる）。
      sub(/[[:space:]]+$/, "", value)
      # 複数行スカラー（note: | / note: > とその変種）は読まない。インジケータ文字だけが
      # 残ると「（|）」という無意味な注記がREADMEへ出るため、空として扱う。
      if (value ~ /^[|>][0-9+-]*$/) value = ""
      if (key == "status") status = value
      else if (key == "superseded_by") superseded_by = value
      else note = value
    }
    END { emit() }
  ' "$@"
}

# ファイル $1 の中から、マーカー行の行番号を探す。
# 出力: グローバル変数 GDL_BEGIN_LINE / GDL_END_LINE（見つからなければ0）
gdl_find_markers() {
  local file="$1" line lineno=0
  GDL_BEGIN_LINE=0
  GDL_END_LINE=0
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))
    line="${line%$'\r'}"
    if [ "$line" = "$GDL_BEGIN_MARKER" ] && [ "$GDL_BEGIN_LINE" -eq 0 ]; then
      GDL_BEGIN_LINE="$lineno"
    elif [ "$line" = "$GDL_END_MARKER" ] && [ "$GDL_BEGIN_LINE" -ne 0 ] && [ "$GDL_END_LINE" -eq 0 ]; then
      GDL_END_LINE="$lineno"
    fi
  done < "$file"
}

main() {
  local check=0 print=0 ddr_dir='' readme='' link_prefix='' link_prefix_given=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --check) check=1 ;;
      --print) print=1 ;;
      --ddr-dir)
        [ $# -ge 2 ] || gdl_die '--ddr-dir にはパスが必要です'
        ddr_dir="$2"
        shift
        ;;
      --readme)
        [ $# -ge 2 ] || gdl_die '--readme にはパスが必要です'
        readme="$2"
        shift
        ;;
      --link-prefix)
        [ $# -ge 2 ] || gdl_die '--link-prefix には文字列が必要です'
        link_prefix="$2"
        link_prefix_given=1
        shift
        ;;
      -h | --help)
        usage
        return 0
        ;;
      *) gdl_die "不明な引数: $1" ;;
    esac
    shift
  done

  [ "$check" -eq 1 ] && [ "$print" -eq 1 ] && gdl_die '--check と --print は同時に指定できません'

  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" ||
    gdl_die 'gitリポジトリの中で実行してください'
  cd "$repo_root"

  # ddrDirs[0] を .mrworkflow.json から読む（無ければ既定値）。
  if [ -z "$ddr_dir" ]; then
    if [ -f .mrworkflow.json ]; then
      # jq の失敗をそのまま `set -e` へ流すと、仕様に無い終了コード（jqの5）が返る。
      # `--check` の呼び出し側は 0/1/2 以外を想定していないため、gdl_die（1）で受ける。
      ddr_dir="$(jq -r '.ddrDirs[0] // ".claude/docs/ddr"' .mrworkflow.json 2>/dev/null | tr -d '\r')" ||
        gdl_die '.mrworkflow.json の読み取りに失敗しました（JSONとして不正の可能性があります）'
      [ -n "$ddr_dir" ] && [ "$ddr_dir" != 'null' ] ||
        gdl_die '.mrworkflow.json の ddrDirs[0] を読めませんでした'
    else
      ddr_dir='.claude/docs/ddr'
    fi
  fi
  ddr_dir="${ddr_dir%/}"
  [ -d "$ddr_dir" ] || gdl_die "DDRディレクトリが見つかりません: $ddr_dir"

  [ -n "$readme" ] || readme="${ddr_dir%/*}/README.md"

  if [ "$link_prefix_given" -eq 0 ]; then
    gdl_link_prefix_to_reply "$readme" "$ddr_dir" ||
      gdl_die "readme($readme)から見たddr-dir($ddr_dir)の相対パスを決められません。--link-prefix で指定してください"
    link_prefix="$REPLY"
  fi

  # 対象ファイルの列挙。glob は LC_ALL=C で決定的な（＝ロケールに依存しない）順序にする。
  # `git ls-files` を使わないのは、**まだコミットしていない新しいDDR**も一覧へ載せるため。
  local -a ddr_files=()
  local saved_lc="${LC_ALL-}" had_lc=0
  [ "${LC_ALL+x}" = 'x' ] && had_lc=1
  LC_ALL=C
  local nullglob_was_set=0
  shopt -q nullglob && nullglob_was_set=1
  shopt -s nullglob
  ddr_files=("$ddr_dir"/*.md)
  [ "$nullglob_was_set" -eq 1 ] || shopt -u nullglob
  if [ "$had_lc" -eq 1 ]; then LC_ALL="$saved_lc"; else unset LC_ALL; fi

  [ "${#ddr_files[@]}" -gt 0 ] || gdl_die "DDRが1件も見つかりません: $ddr_dir/*.md"

  # frontmatterの読み取り（awk 1回）とmarkdown行の組み立て。
  # ループの中では外部コマンドを呼ばない（パラメータ展開と $REPLY のみ）。
  local -a lines=() no_frontmatter=()
  local -A seen=()
  local filename status superseded_by note has_fm
  while IFS=$'\037' read -r filename status superseded_by note has_fm; do
    [ -n "$filename" ] || continue
    seen["$filename"]=1
    [ "$has_fm" = '1' ] || no_frontmatter+=("$filename")
    gdl_unquote_to_reply "$status"
    status="$REPLY"
    gdl_unquote_to_reply "$superseded_by"
    superseded_by="$REPLY"
    gdl_unquote_to_reply "$note"
    note="$REPLY"
    gdl_list_line_to_reply "$filename" "$link_prefix" "$status" "$superseded_by" "$note"
    lines+=("$REPLY")
  done < <(gdl_read_frontmatter "${ddr_files[@]}")

  # 件数が合わないときは、**どのファイルが落ちたか**まで出す。件数だけでは、DDRが数十件ある
  # ディレクトリで原因を総当たりで探すことになる（0バイトのファイルがあると awk が
  # FNR==1 のルールを実行せずレコードを出さない、というのが実際に起きた経路）。
  if [ "${#lines[@]}" -ne "${#ddr_files[@]}" ]; then
    local -a missing=() f base
    for f in "${ddr_files[@]}"; do
      base="${f##*/}"
      [ -n "${seen[$base]:-}" ] || missing+=("$base")
    done
    gdl_die "frontmatterを読めたのは ${#lines[@]} 件で、対象の ${#ddr_files[@]} 件と一致しません（読めなかったファイル: ${missing[*]:-不明}）"
  fi

  # frontmatterを持たないファイルは注記無しの行になる。**無言でスキップしない**
  # （`.claude/rules/shell-script-style.md`「スキップする場合は件数を必ず出す」）。
  # status を持つはずのDDRがBOM・先頭空行で読めていない場合、これが唯一の手がかりになる。
  if [ "${#no_frontmatter[@]}" -gt 0 ]; then
    gdl_log "警告: frontmatterを検出できないファイルが ${#no_frontmatter[@]} 件あります（注記なしとして扱いました）: ${no_frontmatter[*]}"
  fi

  local generated
  printf -v generated '%s\n' "${lines[@]}"

  if [ "$print" -eq 1 ]; then
    printf '%s' "$generated"
    return 0
  fi

  [ -f "$readme" ] || gdl_die "書き換え対象が見つかりません: $readme"

  gdl_find_markers "$readme"
  [ "$GDL_BEGIN_LINE" -ne 0 ] ||
    gdl_die "開始マーカーが $readme にありません: $GDL_BEGIN_MARKER"
  [ "$GDL_END_LINE" -ne 0 ] ||
    gdl_die "終了マーカーが $readme にありません（開始マーカーより後に置いてください）: $GDL_END_MARKER"

  # マーカーの行自体は残し、その間だけを差し替える。
  #
  # 一時ファイルは **$readme と同じディレクトリ**へ作る。`mv` を同一ファイルシステム内に
  # 収めて置き換えをアトミックにするためで、リダイレクト（`cat > "$readme"`）だと先に
  # ファイルを切り詰めるため、中断・ディスクフルでREADME全体（spec一覧・由来の注記を含む）が
  # 欠けた状態で残りうる。`--check` は「差分がある」としか言わないので、壊れたこと自体は
  # 検知できない。
  local readme_dir="${readme%/*}"
  [ "$readme_dir" = "$readme" ] && readme_dir='.'
  local tmp
  tmp="$(mktemp "$readme_dir/.ddr-list.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -f -- '$tmp'" RETURN
  {
    sed -n "1,${GDL_BEGIN_LINE}p" "$readme"
    printf '%s' "$generated"
    sed -n "${GDL_END_LINE},\$p" "$readme"
  } > "$tmp"

  local changed=0
  cmp -s "$tmp" "$readme" || changed=1

  local written=0
  if [ "$check" -eq 0 ] && [ "$changed" -eq 1 ]; then
    # mktemp は 0600 で作るため、元のパーミッションを引き継ぐ。
    chmod --reference="$readme" "$tmp" 2>/dev/null || chmod 644 "$tmp"
    mv -f -- "$tmp" "$readme"
    written=1
  fi

  if [ "$check" -eq 1 ]; then
    if [ "$changed" -eq 1 ]; then
      gdl_log "DDR一覧が最新ではありません（${#lines[@]}件）。bash .claude/scripts/src/generate-ddr-list.sh を実行してください"
    else
      gdl_log "DDR一覧は最新です（${#lines[@]}件）"
    fi
  elif [ "$written" -eq 1 ]; then
    gdl_log "DDR一覧を更新しました（${#lines[@]}件）: $readme"
  else
    gdl_log "DDR一覧に変更はありません（${#lines[@]}件）: $readme"
  fi

  jq -nc \
    --argjson check "$check" \
    --argjson changed "$changed" \
    --argjson written "$written" \
    --argjson count "${#lines[@]}" \
    --arg repoRoot "$repo_root" \
    --arg ddrDir "$ddr_dir" \
    --arg readme "$readme" \
    --arg linkPrefix "$link_prefix" \
    '{check: ($check == 1), print: false, repoRoot: $repoRoot, ddrDir: $ddrDir,
      readme: $readme, linkPrefix: $linkPrefix, count: $count,
      changed: ($changed == 1), written: ($written == 1)}' | tr -d '\r'

  if [ "$check" -eq 1 ] && [ "$changed" -eq 1 ]; then
    return 2
  fi
  return 0
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
