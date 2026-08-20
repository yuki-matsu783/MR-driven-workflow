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

# --- 性能: ヒアドキュメントが大きくても線形時間で終わること -------------------
big_body=''
for ((i = 0; i < 400; i++)); do
  big_body+="この hook は該当語を検知してブロックする。説明文がここに続く。${NL}"
done
big="cat > body.md <<'EOF'${NL}${big_body}EOF"
start=$(date +%s%3N)
normalize_shell_command_to_reply "$big"
end=$(date +%s%3N)
elapsed=$((end - start))
if ((elapsed < 500)); then
  passed=$((passed + 1))
else
  failures=$((failures + 1))
  echo "FAIL: 大きなヒアドキュメントの正規化が遅すぎる（${elapsed}ms）"
fi

echo "passed=$passed failures=$failures"
[[ "$failures" -eq 0 ]]
