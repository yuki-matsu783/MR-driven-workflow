#!/usr/bin/env bash
# .claude/hooks/lib/CommandPosition.sh の単体テスト（issue #53で新設）。
# 外部コマンド呼び出し・git操作・ネットワークを伴わない純粋関数だけを対象にする。
# 規約: passed=N failures=N を標準出力へ出し、失敗があれば終了コード1
#       （.claude/rules/shell-script-style.md「テスト」）。
# 実行: bash .claude/scripts/test/test_command_position.sh
set -euo pipefail

script_dir="${BASH_SOURCE[0]%/*}"
[[ "$script_dir" == "${BASH_SOURCE[0]}" ]] && script_dir="."
repo_root="$(cd "$script_dir/../../.." && pwd)"

# shellcheck source=../../../.claude/hooks/lib/CommandPosition.sh
source "$repo_root/.claude/hooks/lib/CommandPosition.sh"

passed=0
failures=0

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    passed=$((passed + 1))
  else
    failures=$((failures + 1))
    echo "FAIL: $name"
    echo "  expected: $expected"
    echo "  actual  : $actual"
  fi
}

# command_invokes_git_subcommand の結果を hit/miss で受け取る。
# set -e 配下でコマンド置換に頼ると終了コードが取れないため if で受ける
# （.claude/rules/shell-script-style.md「テスト」）。
detect() { # $1=コマンド文字列 $2=サブコマンド（省略時 commit）
  if command_invokes_git_subcommand "$1" "${2:-commit}"; then
    printf 'hit'
  else
    printf 'miss'
  fi
}

NL=$'\n'
BT='`'

# --- ブロックすべきケース（issue #53 の受け入れ条件） -------------------------
assert_eq "単体のコミット実行" "hit" "$(detect 'git commit -m "fix"')"
assert_eq "&& の右辺（複合コマンド）" "hit" "$(detect 'cd src && git commit -m "fix"')"
assert_eq "改行区切りの2行目" "hit" \
  "$(detect "branch=\$(git rev-parse --abbrev-ref HEAD)${NL}git commit -m x")"
assert_eq "; の右辺" "hit" "$(detect 'true; git commit')"
assert_eq "|| の右辺" "hit" "$(detect 'false || git commit')"
assert_eq "パイプの右辺" "hit" "$(detect 'echo y | git commit -F -')"
assert_eq "コマンド置換の中" "hit" "$(detect 'out=$(git commit -m x)')"
assert_eq "サブシェルの中" "hit" "$(detect '(cd src && git commit)')"
assert_eq "変数代入が前置されている" "hit" "$(detect 'GIT_EDITOR=true git commit')"
assert_eq "透過的なラッパー（sudo）" "hit" "$(detect 'sudo git commit')"
assert_eq "透過的なラッパーとそのオプション" "hit" "$(detect 'sudo -u alice git commit')"
assert_eq "if の条件部" "hit" "$(detect 'if git commit; then echo ok; fi')"
assert_eq "大文字混在（大小を区別しない）" "hit" "$(detect 'GIT COMMIT')"
assert_eq "gitのグローバルオプション -C" "hit" "$(detect 'git -C /repo commit -m x')"
assert_eq "gitのグローバルオプション -c（値を1つ取る）" "hit" \
  "$(detect 'git -c user.name=x commit -m y')"
assert_eq "行末にCRがあっても判定が変わらない" "hit" \
  "$(detect "cd src && git commit -m x"$'\r'"${NL}ls")"
assert_eq "ヒアドキュメントを閉じた後の実行" "hit" \
  "$(detect "cat > m.txt <<'EOF'${NL}memo${NL}EOF${NL}git commit -F m.txt")"

# --- ブロックすべきでないケース（issue #53 の受け入れ条件） -------------------
assert_eq "ヒアドキュメント本文（クォート付き区切り）" "miss" \
  "$(detect "cat > body.md <<'EOF'${NL}git commit を直接実行するとブロックされる${NL}EOF")"
assert_eq "ヒアドキュメント本文（素の区切り）" "miss" \
  "$(detect "cat > body.md <<EOF${NL}git commit の説明${NL}EOF")"
assert_eq "ヒアドキュメント本文（<<- でタブ字下げ）" "miss" \
  "$(detect "cat <<-EOF${NL}"$'\t'"git commit の説明${NL}"$'\t'"EOF")"
assert_eq "クォート内（--message の引数）" "miss" \
  "$(detect 'bash create-commit.sh --message "git commit を使わずに済ませる"')"
assert_eq "シングルクォート内" "miss" "$(detect "echo 'git commit の話'")"
assert_eq "日本語の地の文（echoの引数）" "miss" \
  "$(detect 'echo "この hook は git commit を検知してブロックする"')"
assert_eq "該当文字列を検索するgrep" "miss" "$(detect "grep -rn 'git commit' .claude/")"
assert_eq "行頭コメント" "miss" "$(detect "# git commit をブロックする hook${NL}ls")"
assert_eq "行末コメント" "miss" "$(detect 'ls  # git commit の話')"
assert_eq "ファイル名の一部（アンダースコア）" "miss" \
  "$(detect 'ls .claude/scripts/test/test_block_direct_git_commit.sh')"
assert_eq "ファイル名の一部（ハイフン）" "miss" \
  "$(detect 'ls .claude/hooks/block-direct-git-commit.sh')"
assert_eq "gitの別サブコマンドの引数に現れる" "miss" "$(detect 'git log --grep commit')"
assert_eq "gitのサブコマンドが別物" "miss" "$(detect 'git config --get commit.template')"
assert_eq "コマンド文字列が空" "miss" "$(detect '')"
assert_eq "無関係なコマンド" "miss" "$(detect 'git status')"
assert_eq "URLの一部（#の後ろ）" "miss" "$(detect 'echo https://example.com/x#git-commit')"

# --- 素通りさせたくないケース（コード文字列を受け取る実行系） -----------------
assert_eq "bash -c の中身" "hit" "$(detect 'bash -c "git commit -m x"')"
assert_eq "sh -c の中身" "hit" "$(detect 'sh -c "git commit"')"
assert_eq "eval の中身" "hit" "$(detect 'eval "git commit -m x"')"
assert_eq "ダブルクォート内のコマンド置換" "hit" "$(detect 'echo "$(git commit -m x)"')"
assert_eq "ダブルクォート内のバックティック" "hit" "$(detect "echo \"${BT}git commit${BT}\"")"
assert_eq "find -exec" "hit" "$(detect 'find . -name "*.txt" -exec git commit {} \;')"
assert_eq "xargs" "hit" "$(detect 'echo x | xargs git commit -m')"
assert_eq "bash はコード指定オプションが無ければ透過しない" "miss" \
  "$(detect 'bash .claude/scripts/src/create-commit.sh --message "git commit の話"')"

# --- push（同じ判定を push検知hookでも使う） ---------------------------------
assert_eq "pushの単体実行" "hit" "$(detect 'git push -u origin main' push)"
assert_eq "pushの複合コマンド" "hit" "$(detect 'cd /repo && git push origin main' push)"
assert_eq "pushの地の文（ヒアドキュメント）" "miss" \
  "$(detect "gh issue comment 23 --body \"\$(cat <<'EOF'${NL}git push のたびに集計する${NL}EOF${NL})\"" push)"
assert_eq "pushの地の文（コメント）" "miss" "$(detect "ls  # git push の話" push)"
assert_eq "pushとcommitを取り違えない" "miss" "$(detect 'git push origin main' commit)"

# --- 旧実装が拾えていた形を落としていないか（敵対的レビューでの指摘） ---------
# いずれも部分一致では当たっていた入力で、位置ベースにした際に素通りしうる。
assert_eq "行継続の先にコマンド位置がある" "hit" "$(detect "cd src && \\${NL}git commit -m x")"
assert_eq "行継続で引数が続くだけなら誤検知しない" "miss" "$(detect "echo \\${NL}git commit")"
assert_eq "行継続をまたぐgitとサブコマンド" "hit" "$(detect "git \\${NL}commit -m x")"
assert_eq "エイリアスを迂回する \\git" "hit" "$(detect '\git commit -m x')"
assert_eq "エスケープされた区切り文字は区切りにしない" "miss" "$(detect 'echo \;git commit')"
assert_eq "絶対パスでの起動" "hit" "$(detect '/usr/bin/git commit -m x')"
assert_eq "相対パスでの起動" "hit" "$(detect './git commit -m x')"
assert_eq "Windowsの実行ファイル名" "hit" "$(detect 'git.exe commit -m x')"
assert_eq "パス末尾がgitでもコマンド位置でなければ拾わない" "miss" "$(detect 'ls /srv/git commit')"
assert_eq "値を別トークンで取る --git-dir" "hit" "$(detect 'git --git-dir /x/.git commit -m x')"
assert_eq "値を = で繋ぐ --git-dir" "hit" "$(detect 'git --git-dir=/x/.git commit -m x')"
assert_eq "値を別トークンで取る --work-tree" "hit" "$(detect 'git --work-tree /x commit')"
assert_eq "値を別トークンで取る --namespace（push）" "hit" \
  "$(detect 'git --namespace ns push origin main' push)"
assert_eq "コマンド前のリダイレクト（演算子と先が連結）" "hit" "$(detect '>out.txt git commit -m x')"
assert_eq "コマンド前のリダイレクト（演算子と先が別トークン）" "hit" "$(detect '2> err git commit')"
assert_eq "算術左シフトを含む行の次行を捨てない" "hit" \
  "$(detect "echo \$((1<<2))${NL}git commit -m x")"
assert_eq "プロセス置換の中" "hit" "$(detect 'diff <(git commit) x')"
assert_eq "ブレースグループの中" "hit" "$(detect '{ git commit; }')"

# --- 正規化そのものの確認 ---------------------------------------------------
normalize_shell_command_to_reply 'echo "abc"'
assert_eq "ダブルクォートはプレースホルダへ潰れる" "echo _" "$(printf '%s' "$REPLY")"

normalize_shell_command_to_reply "echo 'abc'"
assert_eq "シングルクォートはプレースホルダへ潰れる" "echo _" "$(printf '%s' "$REPLY")"

normalize_shell_command_to_reply 'ls # memo'
assert_eq "コメントはプレースホルダへ潰れる" "ls _" "$(printf '%s' "$REPLY")"

normalize_shell_command_to_reply 'echo a#b'
assert_eq "語中の#はコメントではない" "echo a#b" "$(printf '%s' "$REPLY")"

normalize_shell_command_to_reply "cat <<<\"str\"${NL}ls"
assert_eq "ヒアストリング（<<<）は本文の読み飛ばしを起こさない" "cat <<<_${NL}ls" \
  "$(printf '%s' "$REPLY")"

normalize_shell_command_to_reply "cat <<EOF${NL}body${NL}EOF${NL}ls"
assert_eq "ヒアドキュメント本文は読み飛ばされる" "cat _${NL}_${NL}ls" "$(printf '%s' "$REPLY")"

normalize_shell_command_to_reply "cat <<EOF${NL}body"
assert_eq "閉じないヒアドキュメントは末尾まで本文とみなす" "cat _${NL}_" \
  "$(printf '%s' "$REPLY")"

# --- 極端に長い入力（性能の上限） -------------------------------------------
# 壁時計の閾値はマシン負荷で揺れるため、**空関数をベースラインに取った差**で見る
# （.claude/rules/shell-script-style.md「テスト」）。ここで確かめたいのは
# 「入力サイズに対して破綻しない」ことであって、絶対値ではない。
bench_ms() { # $1=回数 $2=入力
  local i start end
  start=$(date +%s%3N)
  for ((i = 0; i < $1; i++)); do command_invokes_git_subcommand "$2" commit || true; done
  end=$(date +%s%3N)
  printf '%s' "$((end - start))"
}

big_body=''
for ((i = 0; i < 400; i++)); do
  big_body+="この hook は該当語を検知してブロックする。説明文がここに続く。${NL}"
done
big="cat > body.md <<'EOF'${NL}${big_body}EOF"
baseline_ms="$(bench_ms 10 'ls -la')"
heredoc_ms="$(bench_ms 10 "$big")"
# 空に近い入力の10倍を超えないこと（実測では18KBのヒアドキュメントで数十ms）
if ((heredoc_ms - baseline_ms < 2000)); then
  passed=$((passed + 1))
else
  failures=$((failures + 1))
  echo "FAIL: 大きなヒアドキュメントの判定が遅すぎる（${heredoc_ms}ms - ${baseline_ms}ms / 10回）"
fi

# 1行が極端に長い入力は、正規化を諦めて部分一致へ落ちる（_CP_MAX_LINE_LENGTH）。
# 行内の走査は関心文字の数に対して二乗になるため、ここで頭打ちにしておかないと
# hookの遅延として現れる。
long_line='echo "x" '
while ((${#long_line} < 20000)); do long_line+='echo "x" '; done
long_ms="$(bench_ms 10 "$long_line")"
if ((long_ms - baseline_ms < 2000)); then
  passed=$((passed + 1))
else
  failures=$((failures + 1))
  echo "FAIL: 極端に長い1行の判定が遅すぎる（${long_ms}ms - ${baseline_ms}ms / 10回）"
fi
assert_eq "上限超えの行があっても実行は検知する" "hit" "$(detect "${long_line}${NL}git commit -m x")"
assert_eq "上限超えの行だけで該当語が無ければ検知しない" "miss" "$(detect "$long_line")"

# --- command_invokes_script（任意のスクリプト実行判定。issue #149） -------------------------
# command_invokes_git_subcommand の結果を hit/miss で受け取るのと同じ形。
detect_script() { # $1=コマンド文字列 $2=対象スクリプト名（省略時 create-issue.sh）
  if command_invokes_script "$1" "${2:-create-issue.sh}"; then
    printf 'hit'
  else
    printf 'miss'
  fi
}

SCRIPT_PATH='.claude/scripts/src/create-issue.sh'

# --- 発火すること（issue #149 受け入れ条件） ---------------------------------------------
assert_eq "単体実行" "hit" "$(detect_script "$SCRIPT_PATH --title x")"
assert_eq "複合コマンド（cd … && …）" "hit" "$(detect_script "cd /repo && bash $SCRIPT_PATH --title x")"
assert_eq "改行区切りの2行目" "hit" "$(detect_script "ls $SCRIPT_PATH${NL}bash $SCRIPT_PATH --title x")"
assert_eq "bash <パス> 形式" "hit" "$(detect_script "bash $SCRIPT_PATH")"
assert_eq "相対パス（./）での起動" "hit" "$(detect_script "./create-issue.sh --title x")"
assert_eq "絶対パスでの起動" "hit" "$(detect_script "/repo/$SCRIPT_PATH --title x")"
assert_eq "Windowsの実行ファイル名（.exe）" "hit" "$(detect_script "create-issue.sh.exe --title x" 'create-issue.sh')"
assert_eq "sh経由の実行" "hit" "$(detect_script "sh $SCRIPT_PATH")"
assert_eq "ブレースグループの中" "hit" "$(detect_script "{ bash $SCRIPT_PATH; }")"

# --- 発火しないこと（issue #149 受け入れ条件） ------------------------------------------
assert_eq "該当ファイル名を含むだけのcat" "miss" "$(detect_script "cat $SCRIPT_PATH")"
assert_eq "該当ファイル名を含むだけのgrep" "miss" "$(detect_script "grep -rn create-issue.sh .claude/")"
assert_eq "ドキュメント編集コマンド（sed）" "miss" "$(detect_script "sed -n '1,10p' $SCRIPT_PATH")"
assert_eq "コメント内の言及" "miss" "$(detect_script "# create-issue.shを実行するhook${NL}ls")"
assert_eq "ヒアドキュメント本文内の言及" "miss" \
  "$(detect_script "cat <<'EOF'${NL}create-issue.shの説明${NL}EOF")"
assert_eq "ダブルクォート内（地の文）" "miss" "$(detect_script 'echo "create-issue.shについて説明します"')"
assert_eq "無関係なコマンド" "miss" "$(detect_script 'git status')"
assert_eq "コマンド文字列が空" "miss" "$(detect_script '')"

# --- 敵対的レビュー（1回目）で検出された誤検知の再発防止 --------------------------------
assert_eq "sudoの後のcatの引数では発火しない" "miss" "$(detect_script "sudo cat $SCRIPT_PATH")"
assert_eq "ifの条件部のgrepの引数では発火しない" "miss" \
  "$(detect_script "if grep -q x $SCRIPT_PATH; then echo y; fi")"
assert_eq "timeoutの後のgrepの引数では発火しない" "miss" \
  "$(detect_script "timeout 5 grep -rn x $SCRIPT_PATH")"
assert_eq "パラメータ展開\${VAR}直後のパスでは誤って発火しない" "miss" \
  "$(detect_script 'cat ${REPO}/.claude/scripts/src/create-issue.sh')"
assert_eq "sudoで実際にスクリプトを実行する場合は発火する" "hit" "$(detect_script "sudo bash $SCRIPT_PATH")"

# --- 素通りさせたくないケース（コード文字列を受け取る実行系。保守的フォールバック） ------
assert_eq "eval の中身" "hit" "$(detect_script "eval \"bash $SCRIPT_PATH --title x\"")"
assert_eq "bash -c の中身" "hit" "$(detect_script "bash -c \"bash $SCRIPT_PATH\"")"
assert_eq "xargs" "hit" "$(detect_script "echo x | xargs bash $SCRIPT_PATH")"

# --- 極端に長い行（部分一致への縮退） ----------------------------------------------------
long_script_line='echo "x" '
while ((${#long_script_line} < 20000)); do long_script_line+='echo "x" '; done
assert_eq "上限超えの行があっても実行は検知する" "hit" \
  "$(detect_script "${long_script_line}${NL}bash $SCRIPT_PATH")"
assert_eq "上限超えの行だけで該当語が無ければ検知しない" "miss" "$(detect_script "$long_script_line")"

# --- 既知の制約（issue #149。回帰テストとして現状の挙動を固定する） ---------------------
assert_eq "既知の制約: クォートで囲まれたスクリプトパスは検知できない" "miss" \
  "$(detect_script 'bash "$CLAUDE_PROJECT_DIR/.claude/scripts/src/create-issue.sh" --title x')"
assert_eq "既知の制約: バックスラッシュ区切りパス（PowerShell）は検知できない" "miss" \
  "$(detect_script '.claude\scripts\src\create-issue.sh -Title x')"

# --- 公開関数の引数契約: パス付き・大文字混じりで渡しても表記ゆれを吸収する -------------
assert_eq "対象スクリプト名をパス付きで渡しても一致する" "hit" \
  "$(detect_script "$SCRIPT_PATH" '.claude/scripts/src/create-issue.sh')"
assert_eq "対象スクリプト名を大文字混じりで渡しても一致する" "hit" \
  "$(detect_script "$SCRIPT_PATH" 'Create-Issue.SH')"

# --- 変えていないことの確認: command_invokes_git_subcommand に影響していないか -----------
assert_eq "git検知は影響を受けない（回帰確認）" "hit" "$(detect 'git commit -m x')"
assert_eq "git検知のブレースグループも変わらない（回帰確認）" "hit" "$(detect '{ git commit; }')"

echo "passed=$passed failures=$failures"
[[ "$failures" -eq 0 ]]
