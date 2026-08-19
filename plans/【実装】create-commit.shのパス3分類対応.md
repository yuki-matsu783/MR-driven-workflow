---
title: 【実装】create-commit.shのパス3分類対応
type: plan
description: create-commit.shが受け取ったパスをADD/SKIP/UNKNOWNへ分類し、削除済み・削除ステージ済みのパスをそのまま渡せるようにする実装計画
tags: [issue-60, create-commit, git-add, 実装]
keywords: [create-commit, git add, ls-files, ls-tree, 3分類, ADD, SKIP, UNKNOWN, 冪等, pathspec]
---

# 【実装】create-commit.shのパス3分類対応

- issue: [#60](https://github.com/yuki-matsu783/MR-driven-workflow/issues/60)
- 全体作業計画: `plans/cheeky-baking-lantern.md`
- 前提となる調査: `plans/【調査】git-addの削除済みパス挙動.md`（結論はレビュー済み・合意済み）
- flow-id: 3-1〜3-10

## 方針

`git add -A` は**採用しない**（調査結果2・4のとおり、症状を直さないうえ引数が空のとき
リポジトリ全体をステージする）。代わりに、`git add` へ渡す前にパスを3分類する。

| 分類 | 条件 | 扱い |
|---|---|---|
| ADD | worktree に存在する、または index にエントリがある | `git add -- <ADD...>` へ渡す（通常変更・新規・**追跡済みの削除**） |
| SKIP | worktree にも index にも無いが HEAD にはある | 削除が既にステージ済み。**何もせず成功扱い**（冪等）。1行だけ通知する |
| UNKNOWN | いずれにも無い | 想定原因を添えてエラー終了（終了コード1）。タイプミス検知を維持する |

## 変更対象

`.claude/scripts/src/create-commit.sh` の1ファイルのみ（既存の引数パース・バリデーションは変更しない）。

### 追加する処理（`git add` の直前）

```bash
# 追跡状態でパスを分類する。git の起動は ls-files / ls-tree の2回のみ（ループ内では起動しない）
declare -A in_index=() in_head=()
while IFS= read -r -d '' path; do in_index["$path"]=1; done < <(git ls-files -z -- "${files[@]}")
if git rev-parse --verify -q HEAD >/dev/null; then
  while IFS= read -r -d '' path; do in_head["$path"]=1; done \
    < <(git ls-tree -r -z --name-only HEAD -- "${files[@]}")
fi

add=(); skip=(); unknown=()
for f in "${files[@]}"; do
  if [ -e "$f" ] || [ -n "${in_index[$f]:-}" ]; then
    add+=("$f")
  elif [ -n "${in_head[$f]:-}" ]; then
    skip+=("$f")
  else
    unknown+=("$f")
  fi
done
```

### 分類後の振る舞い

1. `unknown` が1件以上 → 全件を列挙し、想定原因を添えてエラー終了（`exit 1`）。
   このとき `git add` は**一切実行しない**（一部だけステージされた中途半端な状態を作らない）。
   メッセージ案:

   ```
   エラー: 次のパスは git が把握していません（ステージング・コミットは行いませんでした）:
     - reports/20260819_report.html
   想定される原因:
     - 一度もコミットされないまま作成・削除された（未追跡ファイル）
     - パスの綴り誤り、または `git status` の8進エスケープ表記（\343\200\220...）をそのまま渡した
   ```

2. `skip` が1件以上 → 1行で通知する（エラーではない）。

   ```
   注記: 次のパスは削除が既にステージ済みのため、そのままコミットに含めます: <パス...>
   ```

3. `add` が1件以上のときのみ `git add -- "${add[@]}"` を実行する。
   **空配列を `git add --` へ渡さないためのガード**（現状は `-A` が無いため実害は無いが、
   将来 `-A` を足された場合に無制限ステージングへ化けるのを構造的に防ぐ）。

4. コミット実行は現行のまま。ステージ済みの変更が1つも無ければ `git commit` が
   「nothing to commit」で失敗する（現行と同じ挙動。自動ロールバックはしない）。

### コメントの更新

冒頭コメントの「`git add .`/`-A` 相当のオプションは持たない」の記述に、次を追記する。

- **削除済みファイルのパスをそのまま渡してよい**こと（`git rm` で先にステージする2段構えは不要。
  むしろ先にステージすると、そのパスは `git add` から見て「index に無い」状態になり失敗する）
- `-A` を採用しなかった理由への参照（`.claude/docs/spec/create-commit.md`・DDR 0029。
  DDR番号は設計反映フェーズで確定するため、コメントには**spec への参照のみ**を書き、
  DDR番号はspec側で辿れるようにする）

## 規約への適合

- `set -euo pipefail` を維持する。`while read` は process substitution から読む
  （パイプにするとサブシェルで代入が失われる。`shell-script-style.md`「REPLYやその他の
  グローバル変数へ結果を返す関数は、パイプではなくヒアストリングで呼ぶ」と同じ理由）
- **ループ内で外部コマンドを呼ばない**（`shell-script-style.md`「外部プロセス起動のコスト」）。
  git の起動はファイル数に依らず2回（HEADが無いリポジトリでは1回）。
  git bash では1起動あたり約95msのため、1コミットあたり約0.2秒の増加に留まる
- 日本語パスは `-z`（NUL区切り）で受け取り、8進エスケープを回避する
  （`git ls-files -z` / `git ls-tree -r -z --name-only` は実測でエスケープしないことを確認済み）
- 連想配列（`declare -A`）は bash 4.0 以降。実行環境の git bash は 5.2.12 で問題ない
- ファイルは UTF-8・BOM無し・LF改行を維持する

## 検証

回帰テストスクリプトは作成しない（着手前にユーザーと合意）。代わりに以下を行う。

1. `bash -n .claude/scripts/src/create-commit.sh`（構文チェック）
2. scratchpad配下の一時リポジトリで、ラッパー本体を直接呼んで次の6ケースを確認する
   （検証スクリプトはリポジトリに含めない。結果は worklog に残す）

   | # | ケース | 期待 |
   |---|---|---|
   | 1 | 通常変更のみ（従来の使い方） | 成功。ステージ内容が現行と同一 |
   | 2 | 削除済み＋通常変更＋新規の混在 | 1回の呼び出しで成功し、`D`/`M`/`A` が揃う |
   | 3 | `git rm` で削除をステージ済みのパスを再指定（**issueの回避策の再現**） | SKIP通知が出て成功する（現行はここで rc=128） |
   | 4 | 未追跡のまま削除されたパス | UNKNOWNとしてエラー終了し、**何もステージされていない**こと |
   | 5 | UNKNOWN と正常パスの混在 | 何もステージせずエラー終了（部分適用が起きない） |
   | 6 | 引数なし・`--message` なし | 現行どおりのバリデーションエラー |

3. pathspec 外の変更（別ディレクトリの変更・未追跡ファイル）が巻き込まれないことを、
   ケース2・3のステージ内容で確認する
4. 実地検証: 本ブランチの以降のコミットは全てこのラッパー経由になる。とくに flow-id 5-1 の
   片付けコミット（`plans/` `worklog/` `reports/` の削除を含む）が、削除パスをそのまま渡して
   成功することをもって最終確認とする

## 完了条件

- 上記6ケースが期待どおりの結果になる
- `bash -n` が通る
- issueの受け入れ条件のうち、実装に関わる3項目（混在コミット可・無制限ステージング不可・
  既存の使い方が従来どおり）を満たしている
- 冒頭コメントを読めば「削除済みパスをそのまま渡してよい」「`git rm` 先行は不要」が分かる

## 作業ログ

（flow-id 3-6 で記入する）
