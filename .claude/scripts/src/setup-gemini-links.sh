#!/usr/bin/env bash
#
# .gemini/{docs,hooks,rules,scripts,skills} を .claude/ 配下の同名ディレクトリへのリンクとして
# 作成する（Gemini CLIとClaude Codeでルール・スキル・スクリプトの内容を二重管理しないため）。
# 設計: .claude/docs/ddr/i0000-13-gemini配下はGit管理下に置かずセットアップスクリプトで生成する.md
#
# .gemini/{docs,hooks,rules,scripts,skills} はGit管理下に置かない（.gitignore参照）。
# NTFSジャンクションはGitがリンクとして認識できず、中身をそのまま複製してコミットしてしまうため
# （Windows版の`git status`で`.gemini/docs/*.md`等が個別の新規ファイルとして列挙されることを
# 実機確認済み）。そのためclone直後・リンクが失われた場合に、このスクリプトを1度実行して
# 各開発者のマシン上にローカルでリンクを再生成する運用にする。
#
# 使い方:
#     bash .claude/scripts/src/setup-gemini-links.sh
#
# リンク（symlink / NTFSジャンクション）が既にある場合は何もしない（再実行しても安全）。
# symlinkもジャンクションも作れない環境では**実体コピーへフォールバックし、終了コード0で
# 終わる**（issue #26 受け入れ条件7）。実体コピーになっている場合、再実行すると
# .claude/ 側の最新内容へ入れ替える（同 受け入れ条件8）。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

TARGETS=(docs hooks rules scripts skills)

# 対象の現在の状態を REPLY へ返す（absent / symlink / junction / real / file）。
#
# `[ -L ]` はNTFSジャンクションを実体ディレクトリと区別できない。Windows実機でしか確認できない
# ため、次の順で**安全側**（迷ったら「リンク扱い」にして触らない）へ倒す。
classify_target_to_reply() {
  local link_path="$1"

  if [ ! -e "$link_path" ] && [ ! -L "$link_path" ]; then
    REPLY='absent'
    return 0
  fi
  if [ -L "$link_path" ]; then
    REPLY='symlink'
    return 0
  fi
  if [ ! -d "$link_path" ]; then
    REPLY='file'
    return 0
  fi
  # Windows（cygpath がある環境）でのみジャンクションを判定する。
  if command -v cygpath >/dev/null 2>&1 && command -v fsutil >/dev/null 2>&1; then
    if fsutil reparsepoint query "$(cygpath -w "$link_path")" >/dev/null 2>&1; then
      REPLY='junction'
      return 0
    fi
  fi
  REPLY='real'
}

# 実体コピーの中身を .claude/ 側の最新へ入れ替える（受け入れ条件8）。
#
# **`.gemini/<name>` 自体は削除しない。** 判定を誤ってリンクを実体だと見なした場合に、
# リンクを辿って `.claude/` 側を消してしまう事故を構造的に避けるため、操作対象は
# 「`.gemini/<name>` の中身」に限る。
sync_real_copy() {
  local src="$1" dst="$2" rel
  local src_real dst_real

  # 追加の安全網: 物理パスが同一なら、それはリンクであって実体コピーではない。
  # `pwd -P` はsymlinkを解決する（ジャンクションは環境によるため、上の classify と二重で持つ）。
  src_real="$(cd "$src" && pwd -P)"
  dst_real="$(cd "$dst" && pwd -P)"
  if [ "$src_real" = "$dst_real" ]; then
    printf 'skip（.claude/ と同じ実体を指しています。リンクとみなします）: %s\n' "$dst"
    return 0
  fi

  # 1. コピー元から消えたファイルを、コピー先から削除する。
  while IFS= read -r -d '' rel; do
    rel="${rel#./}"
    [ -e "${src}/${rel}" ] || rm -f "${dst}/${rel}"
  done < <(cd "$dst" && find . -type f -print0)

  # 2. コピー元の中身で上書きする。
  cp -R "${src}/." "${dst}/"

  # 3. 空になったディレクトリを掃除する（削除で空になった分だけ）。
  find "$dst" -mindepth 1 -type d -empty -delete 2>/dev/null || true
}

# `.claude/<name>` を実体コピーとして `.gemini/<name>` へ置く（受け入れ条件7）。
place_real_copy() {
  local name="$1" link_path="$2" target_path="$3"
  mkdir -p "$link_path"
  cp -R "${target_path}/." "${link_path}/"
  # 利用者が「リンクになっている」と誤解したまま .gemini/ を編集するのを防ぐため明示する。
  cat <<MSG
作成しました（実体コピー）: .gemini/${name}
  この環境ではsymlinkもNTFSジャンクションも作成できなかったため、中身を複製しました。
  **.gemini/${name} を直接編集しないこと**（次回このスクリプトを実行すると .claude/${name} の
  内容で上書きされます）。編集は常に .claude/${name} 側へ行ってください。
MSG
}

setup_target() {
  local name="$1"
  local link_path="${REPO_ROOT}/.gemini/${name}"
  local target_path="${REPO_ROOT}/.claude/${name}"

  classify_target_to_reply "$link_path"
  case "$REPLY" in
    symlink|junction)
      printf 'skip（既にリンクです / %s）: .gemini/%s\n' "$REPLY" "$name"
      return 0
      ;;
    file)
      printf 'エラー: .gemini/%s がディレクトリではありません。手動で確認してください\n' "$name" >&2
      return 1
      ;;
    real)
      printf '更新します（実体コピー）: .gemini/%s ← .claude/%s\n' "$name" "$name"
      sync_real_copy "$target_path" "$link_path"
      return 0
      ;;
  esac

  # 以降は absent の場合。
  # 1. まずシンボリックリンクを試みる（Linux/macOSでは常に成功する。Windowsでは開発者モード/
  #    管理者権限がある場合のみ成功する）。
  if ln -s "$target_path" "$link_path" 2>/dev/null; then
    printf '作成しました（symlink）: .gemini/%s -> .claude/%s\n' "$name" "$name"
    return 0
  fi

  # 2. シンボリックリンクに失敗した場合、Windows専用のNTFSジャンクションへフォールバックする
  #    （ディレクトリのみ対象。管理者権限・開発者モードいずれも不要）。
  #    `//c` `//J` の先頭 `//` は、git bash（MSYS）がDOS形式の単一スラッシュ引数を
  #    POSIXパスと誤認してWindowsパスへ自動変換してしまう問題の回避策
  #    （詳細: .claude/rules/shell-script-style.md「git bashのパス変換の落とし穴」）。
  # cygpath も併せて確認する（cmd.exe だけを見ると、cygpath 不在の環境で
  # `cygpath: command not found` を標準エラーへ漏らす）。
  if command -v cmd.exe >/dev/null 2>&1 && command -v cygpath >/dev/null 2>&1; then
    local win_link win_target
    win_link="$(cygpath -w "$link_path")"
    win_target="$(cygpath -w "$target_path")"
    if cmd.exe //c mklink //J "$win_link" "$win_target" >/dev/null 2>&1; then
      printf '作成しました（NTFSジャンクション。symlink作成に必要な権限が無かったための代替）: .gemini/%s -> .claude/%s\n' \
        "$name" "$name"
      return 0
    fi
  fi

  # 3. どちらも作れない環境では実体コピーへフォールバックする（失敗にしない）。
  place_real_copy "$name" "$link_path" "$target_path"
  return 0
}

main() {
  mkdir -p "${REPO_ROOT}/.gemini"

  local fail=0 t
  for t in "${TARGETS[@]}"; do
    setup_target "$t" || fail=1
  done

  if [ "$fail" -ne 0 ]; then
    printf '一部の対象で失敗しました。上記のエラーを確認してください。\n' >&2
    return 1
  fi

  printf '完了しました（対象 %s 件）。.gemini/{docs,hooks,rules,scripts,skills} は .claude/ 配下を参照します（Git管理下には置きません）。\n' \
    "${#TARGETS[@]}"
  return 0
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
