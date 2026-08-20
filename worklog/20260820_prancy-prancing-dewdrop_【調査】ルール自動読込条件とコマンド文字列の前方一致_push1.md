---
title: worklog 20260820 【調査】ルール自動読込条件とコマンド文字列の前方一致 push1
type: log
description: issue #47のフェーズ2〈調査〉における試行錯誤の記録（push1）
tags: [worklog, investigation, issue-47]
keywords: [alwaysApply, 自動読込, permissions, 前方一致, hook誤検知, 進捗表, awk, マルチバイト, issue-47]
---

# worklog: 【調査】ルール自動読込条件とコマンド文字列の前方一致

対象: issue #47（AIが実行する複数行コマンドに日本語コメントを必須とするルールを追加する）（2026-08-20）。
全体作業計画: `plans/prancy-prancing-dewdrop.md`
個別作業計画: `plans/【調査】ルール自動読込条件とコマンド文字列の前方一致.md`
push回数: 1

## 試したこと

### フェーズ1（flow-id 1-2〜1-6）

- `get_vcs_access_mode` の結果は `mcp`。`gh` CLI不在のため、issue取得・PR作成はすべて
  `mcp__github__*` へ読み替えた。
- `check-base-sync.sh` は `isBehind: false` / `hasCommonHistory: true` / `fetchOk: true` /
  `isShallow: true`。shallow cloneは web 実行環境では常に真になるため単体では警告条件にしない
  （SKILL.mdの規定どおり）。
- ブランチはハーネス指定の `claude/multiline-command-japanese-comments-k8c2pr`。`ahead=0` の
  状態でDraft PRを作ると必ず失敗すると分かっていたため、`add_empty_commit_for_draft_mr` を
  先に実行した。ただし**このブランチにはupstreamが無く、関数内の `git push` が失敗**した
  （空コミットは積まれた）。`git push -u origin <branch>` を別途実行して復旧した。

### HANDOFF.mdの進捗表の組み立て

- `cleanup-task.sh` が書き戻すHANDOFF.mdのテンプレートは進捗表を持たない（「（次タスク着手時に
  記入する）」）。41行の表を手写しすると転記ミスが起きるため、`SKILL.md` のフロー表から
  機械生成した。

## うまくいったこと

- **進捗表の機械生成**。`SKILL.md` の `| <flow-id> | ステップ | 担当 |` 行を抽出し、
  進捗列を先頭へ足す形で41行ちょうどを得られた。`update-handoff-progress.sh mark-done` が
  期待どおり動くことも確認できた（正規表現 `^(\|[[:space:]]*)(\[[^\|]*\])...` に合致する）。
- **hook誤検知の再現**。HANDOFF.mdの地の文へ `permissions.deny` のパターン文字列をそのまま
  書いてBashツールへ渡したところ、`block-direct-git-commit.sh` が exit 2 でブロックした。
  issue #47 が扱う論点の実例をこのセッション内で得られたので、ルール本文の根拠に使える。
  対処はWriteツールで一時ファイルへ書き出し、Bash側は連結だけを行う形にした。

## ダメだったこと

- **`awk` の文字クラスでマルチバイト文字を切ろうとして壊した**。ステップ列を短くするために
  `sub(/[（。].*$/, "", step)` と書いたところ、`（` `。` がバイト単位で扱われ、日本語の途中で
  切れて `**Plan` `調査�` のような壊れた文字列になった。bashのパラメータ展開
  （`${step%%（*}`）へ置き換えて解決した。UTF-8は自己同期的なので、**文字クラスではなく
  「その文字列全体」で一致させる**形なら安全である。
  - 既存ルール（`.claude/rules/shell-script-style.md`）には「日本語を含む文字列の先頭を
    `${var:0:N}` で切り出して比較しない」という近い注意はあるが、**awkの文字クラス**については
    書かれていない。フェーズ4のAIアセット反映の候補。
- **`set -euo pipefail` を宣言しないアドホックなコマンドで、HANDOFF.mdの進捗表を消した**。
  `last=$(grep -n '^| \[.\] | 5-5 |' ...)` の正規表現 `\[.\]` が `[]`（記号1文字を挟まない形）に
  マッチせず `last` が空になり、`sed -n "1,p"` が失敗。ところが `set -e` が無いため後続の
  `mv -f HANDOFF.md.new HANDOFF.md` がそのまま実行され、tailだけのファイルで上書きされた。
  scratchpadに断片を残していたため再構築できた。
  - 教訓は2つ。(1) **進捗記号 `[]` は「0文字」なので `\[.\]` ではマッチしない**（`\[[^]]*\]` を
    使う）。(2) **ファイルを上書きするアドホックなコマンドでも `set -euo pipefail` を宣言する**。
    フェーズ4のAIアセット反映の候補。

## 前方一致の裏取り（調査2の先行実施）

**issue #47 の前提と食い違う既存記録を見つけた。** `.claude/docs/spec/issue-mr-workflow.md` の
「制約」節と `.claude/docs/ddr/0022-...md` の「副次的な確認事項」に、issue #23 対応時の実機観測
3回をもとに「`if` フィールドは**前方一致ではなく部分一致**として動作する」と明記されている。
issue #47 は逆に「先頭がコメント行だと前方一致が外れる」と述べている。

そこで、このリモート実行環境で `if: "Bash(git push*)"` の発火条件を実測した。

| # | コマンドの構成 | 発火 |
|---|---|---|
| 1 | 1行目 `set -euo pipefail` / 2行目 `git push -u origin <branch> ...` | した |
| 2 | 1行目 `set -euo pipefail` / 2行目 コメント / 3行目 `echo '...git push...'` | **しない** |
| 3 | **1行目 コメント** / 2行目 `git push --dry-run origin <branch>` | **した** |

- #3 が本命。**1行目にコメントを置いても発火した**。少なくともこの環境では、
  issue #47 が言う「先頭がコメント行だと前方一致が外れる」は**再現しない**。
- #2 から、単純な部分一致でもないと分かる（`echo` の引数に該当語があっても発火しない）。
- #1〜#3 を最も素直に説明するのは「**コマンドを部分コマンドへ分解し、各部分コマンドに対して
  前方一致で照合する**」というモデルである。コメント行・無関係な行はマッチを妨げない。
- ただし DDR 0022 の観測（heredocの地の文で発火）はこのモデルでは説明できない。
  **Claude Codeのバージョン・プラットフォーム（Windows git bash 対 リモート実行環境）で
  挙動が違う可能性が高い**。片方の環境の観測だけを根拠に断定してはいけない。

**`permissions.deny` 側は安全に実測できない。** `deny` に載っているのはコミット操作のパターン
だけで、同じ文字列は PreToolUse hook（`block-direct-git-commit.sh`）にも引っかかる。hookが先に
exit 2 で止めるため、`deny` がマッチしたかどうかを切り分けられない。`allow` を試すには
`settings.json` の変更が要り、リポジトリの設定を実験のために書き換えることになるので行わない。

**flow-id 1-6 で観測した「地の文でのブロック」は、`if` の話ではない。** あれは
`block-direct-git-commit.sh` が発火したもので、このhookのmatcherは `Bash|PowerShell`
（ツール名のみ）であり、スクリプト内部の `grep -qiE 'git[[:space:]]+commit'` が
コマンド文字列**全体**を見ている。`if` フィールドの照合とは別の仕組みである。
**この2つを混同すると、ルール本文の根拠を取り違える。**

## 次の一歩

- flow-id 2-2（commit・push）→ 敵対的レビュー → flow-id 2-6（調査の実施）。

---
