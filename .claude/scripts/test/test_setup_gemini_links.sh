#!/usr/bin/env bash
# .claude/scripts/src/setup-gemini-links.sh の単体テスト（issue #26 受け入れ条件7・8）。
#
# 確かめるのは次の3つ。
#   1. symlink もNTFSジャンクションも作れない環境で、**実体コピーへフォールバックし
#      終了コード0で終わる**（受け入れ条件7）。`ln` と `cmd.exe` のスタブをPATHの先頭へ
#      置いて、その環境を再現する。
#   2. 実体コピーの状態で再実行すると、`.claude/` 側の最新へ入れ替わる（受け入れ条件8）。
#      追加・変更・削除の3つとも反映されること。
#   3. **`.claude/` 側を壊さないこと。** リンクを実体と誤判定した場合に、リンクを辿って
#      配布元を消してしまう事故を避けるための安全網が効いていること。
#
# 実リポジトリは対象にしない（`mktemp -d` の使い捨てツリーの中で実プロセスとして起動する）。
#
# 規約: passed=N failures=N を標準出力へ出し、失敗があれば終了コード1
#       （.claude/rules/shell-script-style.md「テスト」）。
# 実行: bash .claude/scripts/test/test_setup_gemini_links.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
TARGET="${REPO_ROOT}/.claude/scripts/src/setup-gemini-links.sh"

passed=0
failures=0

if [ ! -f "$TARGET" ]; then
  echo "skipped: ${TARGET} が無いためスキップします"
  echo "passed=0 failures=0"
  exit 0
fi

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    passed=$((passed + 1))
  else
    failures=$((failures + 1))
    printf 'FAIL: %s\n  expected: %s\n  actual  : %s\n' "$label" "$expected" "$actual" >&2
  fi
}

exists() { [ -e "$1" ] || [ -L "$1" ] && echo 1 || echo 0; }

TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# 使い捨てツリーを作る。スクリプトは自身の位置から3つ上をリポジトリルートとみなすので、
# `<root>/.claude/scripts/src/` へ置く必要がある。
make_tree() {
  local root="$TMP_DIR/$1"
  mkdir -p "$root/.claude/scripts/src"
  local t
  for t in docs hooks rules skills; do
    mkdir -p "$root/.claude/$t"
    printf 'v1\n' > "$root/.claude/$t/a.md"
  done
  printf 'old\n' > "$root/.claude/rules/gone.md"
  cp "$TARGET" "$root/.claude/scripts/src/"
  printf '%s' "$root"
}

# リンクを作れない環境のスタブ。`ln` と `cmd.exe` の両方を失敗させる。
STUB_DIR="$TMP_DIR/stub"
mkdir -p "$STUB_DIR"
printf '#!/usr/bin/env bash\nexit 1\n' > "$STUB_DIR/ln"
printf '#!/usr/bin/env bash\nexit 1\n' > "$STUB_DIR/cmd.exe"
chmod +x "$STUB_DIR/ln" "$STUB_DIR/cmd.exe"

run_nolink() { PATH="$STUB_DIR:$PATH" bash "$1/.claude/scripts/src/setup-gemini-links.sh"; }
run_normal() { bash "$1/.claude/scripts/src/setup-gemini-links.sh"; }

status_of() {
  if "$@" > /dev/null 2>&1; then printf '0'; else printf '1'; fi
}

# --- 受け入れ条件7: 実体コピーへフォールバックし終了コード0 -----------------

root_fb="$(make_tree fallback)"
assert_eq "受け入れ条件7: リンクを作れなくても終了コード0" "0" "$(status_of run_nolink "$root_fb")"

for t in docs hooks rules skills; do
  assert_eq "受け入れ条件7: .gemini/$t が作られる" "1" "$(exists "$root_fb/.gemini/$t")"
  assert_eq "受け入れ条件7: .gemini/$t は symlink ではない（実体）" "1" \
    "$([ -L "$root_fb/.gemini/$t" ] && echo 0 || echo 1)"
done
assert_eq "受け入れ条件7: 中身が複製されている" "v1" "$(cat "$root_fb/.gemini/rules/a.md")"

# 利用者が「リンクになっている」と誤解しないよう、実体コピーである旨を出力へ明示すること。
# **対象5件すべてで**示されること（1件でも欠けると、その対象だけ誤解されうる）。
fb_out="$(run_nolink "$root_fb" 2>&1)"
assert_eq "受け入れ条件7: 実体コピーであることを全対象の出力で示す" "5" \
  "$(printf '%s\n' "$fb_out" | grep -c '（実体コピー）')"

# --- 受け入れ条件8: 実体コピー状態で再実行すると最新へ入れ替わる -------------

printf 'v2\n' > "$root_fb/.claude/rules/a.md"        # 変更
rm -f "$root_fb/.claude/rules/gone.md"                # 削除
printf 'new\n' > "$root_fb/.claude/rules/added.md"    # 追加
assert_eq "受け入れ条件8: 再実行しても終了コード0" "0" "$(status_of run_nolink "$root_fb")"
assert_eq "受け入れ条件8: 変更が反映される" "v2" "$(cat "$root_fb/.gemini/rules/a.md")"
assert_eq "受け入れ条件8: 削除が反映される" "0" "$(exists "$root_fb/.gemini/rules/gone.md")"
assert_eq "受け入れ条件8: 追加が反映される" "new" "$(cat "$root_fb/.gemini/rules/added.md")"

# **配布元を壊していないこと**（この確認が無いと、同期の実装が .claude/ 側を消していても通る）。
assert_eq "受け入れ条件8: .claude/ 側のファイルが残っている" "v2" "$(cat "$root_fb/.claude/rules/a.md")"
assert_eq "受け入れ条件8: .claude/ 側の追加ファイルも残っている" "new" \
  "$(cat "$root_fb/.claude/rules/added.md")"

# --- 通常経路（symlink が作れる環境）と冪等性 -------------------------------

root_ln="$(make_tree symlink)"
assert_eq "通常経路: 終了コード0" "0" "$(status_of run_normal "$root_ln")"
if [ -L "$root_ln/.gemini/rules" ]; then
  assert_eq "通常経路: symlink が作られる" "1" "1"
  # 再実行しても触らない（skip）こと。
  again="$(run_normal "$root_ln" 2>&1)"
  assert_eq "通常経路: 再実行では既にリンクとしてskipする" "5" \
    "$(printf '%s\n' "$again" | grep -c 'skip（既にリンクです')"
  # symlink を実体と誤判定して .claude/ 側を消していないこと。
  assert_eq "通常経路: .claude/ 側が壊れていない" "v1" "$(cat "$root_ln/.claude/rules/a.md")"
  assert_eq "通常経路: .claude/ 側の gone.md も残っている" "1" \
    "$(exists "$root_ln/.claude/rules/gone.md")"
else
  echo "note: この環境では symlink を作成できなかったため、通常経路の4件はスキップしました"
fi

# --- 対象がディレクトリでない場合はエラーにする -----------------------------

root_file="$(make_tree filecase)"
mkdir -p "$root_file/.gemini"
printf 'これはファイル\n' > "$root_file/.gemini/rules"
assert_eq "対象がファイルなら失敗する" "1" "$(status_of run_nolink "$root_file")"
assert_eq "対象がファイルでも中身は書き換えない" "これはファイル" "$(cat "$root_file/.gemini/rules")"

echo "passed=$passed failures=$failures"
[ "$failures" -eq 0 ]
