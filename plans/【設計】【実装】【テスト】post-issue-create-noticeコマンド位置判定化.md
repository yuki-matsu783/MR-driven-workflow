---
title: 【設計】【実装】【テスト】post-issue-create-notice.shのコマンド位置判定化
type: plan
description: issue #149。CommandPosition.shへスクリプト実行判定の公開関数を追加し、post-issue-create-notice.shのCLI経路検知を差し替える個別作業計画
tags: [hook, command-position, issue-149]
keywords: [CommandPosition, command_invokes_script, is_issue_create_call, テスト, 3段ガード, 敵対的レビュー]
---

# 【設計】【実装】【テスト】post-issue-create-notice.shのコマンド位置判定化

## 前提（合意状況）

- 上位の計画: `plans/post-issue-notice-command-position.md`（全体作業計画。非対話セッションのため
  flow-id 1-5の人間合意は取れていないが、issue本文・既存実装（issue #147）と矛盾しない内容として
  作成した）
- 本文書は敵対的レビュー1回目（`adversarial-reviewer`、2026-08-23）の指摘8件を反映した改訂版
  （初版との差分は「敵対的レビュー（1回目）を踏まえた設計改訂」節）

## この計画で何をするか

`.claude/hooks/lib/CommandPosition.sh` へ「任意のスクリプト（basename）がコマンド位置で
実行されるか」を判定する公開関数 `command_invokes_script` を追加し、
`.claude/hooks/post-issue-create-notice.sh` の `is_issue_create_call` のCLI経路判定を
それへ差し替える。あわせて単体テストを追加する。

## 変更対象

| ファイル | 操作 | 何をするか |
|---|---|---|
| `.claude/hooks/lib/CommandPosition.sh` | 変更 | `_cp_scan_tokens_for_script`（内部）と `command_invokes_script`（公開）を追加 |
| `.claude/hooks/post-issue-create-notice.sh` | 変更 | `is_issue_create_call` のCLI経路を新関数へ差し替え、3段ガードをトップレベルで確定させる。ヘッダコメント（現状・既知のトレードオフ・前置フィルタ節の記述）も更新する |
| `.claude/scripts/test/test_command_position.sh` | 変更 | `command_invokes_script` の単体テストを追加（発火/非発火・フォールバック・既知の制約の固定） |
| `.claude/scripts/test/test_post_issue_create_notice.sh` | 変更 | issue #149の受け入れ条件ケースを追加 |

## 方針

### `command_invokes_script` の設計

既存の `_cp_scan_tokens`（`git <サブコマンド>` 専用）と同じ「正規化済み文字列をトークン走査し、
コマンド位置（`at_cmd`/`sticky`）にあるトークンだけを見る」骨格を再利用しつつ、判定内容を
「basenameが対象スクリプト名と一致するか」に置き換えた専用関数 `_cp_scan_tokens_for_script` を
新設する（`_cp_scan_tokens` 自体は改変しない。gitのグローバルオプション読み飛ばしという
git固有ロジックを持ち、スクリプト名判定には不要なため。既存コードの局所性を保つ方針は
issue #159の前置フィルタでも採られている）。

判定する2形態:

1. **単体実行**: コマンド位置のトークンのbasename（パス・`.exe`を除いた末尾）が、対象スクリプト名
   （例: `create-issue.sh`）と一致する。
2. **インタプリタ経由**: コマンド位置のトークンが `_CP_OPAQUE_WITH_OPT`（`bash`/`sh`等）に該当し、
   その直後の非オプショントークン（コード文字列オプション `-c` 等が無い場合に限る）のbasenameが
   対象スクリプト名と一致する。

`cat` / `grep` のような無関係なコマンドの引数に現れるだけでは発火しない
（下記「敵対的レビュー（1回目）を踏まえた設計改訂」1点目のとおり、`_cp_scan_tokens`をそのまま
真似ると発火してしまうため、sticky（透過語）の扱いを変更する）。

```bash
# 概形（改訂版。実装時に確定させる）
_cp_scan_tokens_for_script() {
  local norm="$1" target="$2"   # target は小文字化済みのbasename
  _CP_OPAQUE_FOUND=0
  # セパレータのトークン化・IFS分割は _cp_scan_tokens と同じ前処理
  # ループ: at_cmd の間だけ判定
  #   base == target -> 一致（found=0; return）
  #   base が _CP_OPAQUE_WITH_OPT -> 直後の非オプショントークン（コード文字列オプション除く）を見る。
  #     一致すれば found=0。コード文字列オプションがあれば _CP_OPAQUE_FOUND=1（フォールバック用）
  #   base が _CP_OPAQUE_WORDS（eval/xargs/find等）-> _CP_OPAQUE_FOUND=1
  #   base が _CP_PREFIX_WORDS（sudo/if/timeout等）-> 次の非オプション（`-`始まりでない）トークンを
  #     「実コマンド」とみなし、それを本ループの通常の判定（上の各分岐）へ通す。sticky区間はここで
  #     終わる（次のセパレータまで保持し続けない）。※ _cp_scan_tokens とはこの点が異なる（下記参照）
  #   それ以外 -> at_cmd=0（判定終了。次のセパレータまでスキップ）
}

command_invokes_script() {
  local s="${1:-}" script="${2:?}"
  [[ -n $s ]] || return 1
  local script_lower="${script,,}"
  script_lower="${script_lower##*/}"; script_lower="${script_lower%.exe}"  # 呼び出し側の表記ゆれ吸収
  if _cp_has_overlong_line "$s"; then
    [[ "${s,,}" == *"$script_lower"* ]] && return 0
    return 1
  fi
  normalize_shell_command_to_reply "$s"
  if _cp_scan_tokens_for_script "$REPLY" "$script_lower"; then
    return 0
  fi
  # 保守的フォールバック（command_invokes_git_subcommand と同じ設計原則）。
  # eval/xargs/find や bash -c 等、文字列をコードとして受け取りうる実行系がコマンド位置に
  # あった場合は、位置判定が外れても部分一致で保守的に倒す。
  ((_CP_OPAQUE_FOUND)) || return 1
  [[ "${s,,}" == *"$script_lower"* ]] || return 1
  return 0
}
```

`normalize_shell_command_to_reply` と `_cp_has_overlong_line`（極端に長い行での部分一致への
縮退）はそのまま再利用する。

### `post-issue-create-notice.sh` の3段ガード（改訂）

3段ガード（bashバージョン `4.3` 以上・`source` の成否・`declare -F`）は**トップレベルで一度だけ
確定させる**（`main()`の中に置かない。下記「設計改訂」5点目の理由）。判定用の関数
`_pin_cli_match` をトップレベルで定義し、ガードを満たさない場合は本体を部分一致へ差し替える形にする。

置き換え前（現状）:

```bash
run_shell_command | Bash | PowerShell)
  [[ "$command" == *create-issue.sh* ]]
  ;;
```

置き換え後（イメージ。トップレベル、`is_issue_create_call` 定義より前に置く）:

```bash
# CLI経路の実判定（トップレベルで一度だけ確定させる。source直後から source されたテストからも
# 動く必要があるため main() の中には置かない）
_pin_cli_match() { [[ "$1" == *create-issue.sh* ]]; }  # 既定値（フォールバック）
_pin_lib_dir="${BASH_SOURCE[0]%/*}"
[ "$_pin_lib_dir" = "${BASH_SOURCE[0]}" ] && _pin_lib_dir='.'
_pin_lib="${_pin_lib_dir}/lib/CommandPosition.sh"
if ((BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 3))) &&
  [ -r "$_pin_lib" ] && source "$_pin_lib" 2>/dev/null &&
  declare -F command_invokes_script >/dev/null; then
  _pin_cli_match() { command_invokes_script "$1" 'create-issue.sh'; }
fi
```

`is_issue_create_call` はCLI経路の分岐で `_pin_cli_match "$command"` を呼ぶ形へ変更する
（引数3つのシグネチャは変えない）。`source`直後（`main()`を実行していない状態）でも
`_pin_cli_match`は定義済みなので、既存テスト（`is_issue_create_call`を直接呼ぶ4ケース）は
そのまま動く。

### 前置フィルタ（`raw_hints_at_issue_create`）は変更しない

既存の前置フィルタは判定本体の超集合であり続ける（`command_invokes_script`は部分一致の対象を
絞り込むだけで、前置フィルタが通過させる語形より広い語形を新たに拾うようにはならないため）。
実装後に`test_post_issue_create_notice.sh`の既存ケース（バックスラッシュ分割・大文字小文字混在）が
新しい判定本体に対しても成立することを確認する（テストケースの追加は不要、既存ケースの
再確認のみ）。

## 敵対的レビュー（1回目）を踏まえた設計改訂

敵対的レビュー（`adversarial-reviewer`、2026-08-23、フェーズ3・1回目）で8件の指摘を受けた。
反映内容は次のとおり（詳細な再現コマンドはレビュー結果を参照。本節は修正方針の要約）。

| # | 指摘 | 対応 |
|---|---|---|
| 1 | `_CP_PREFIX_WORDS`（`sudo`/`if`/`timeout`等）を通ると`sticky`が次のセパレータまで解除されず、`cat`/`grep`の引数（スクリプトパス）に対しても発火する。`${VAR}/path`のような`{`/`}`を含むトークン化でも同様に誤発火する | **修正**。`_cp_scan_tokens_for_script`では、prefix word の後に続く最初の非オプショントークンを「実コマンド」として1回だけ評価し、そこでsticky区間を終える（`_cp_scan_tokens`のようにセパレータまで保持し続けない）。上記「概形」参照 |
| 2 | `eval`/`bash -c`経由の保守的フォールバック（`_CP_OPAQUE_FOUND`）が設計に無く、既存の部分一致より検知が後退する | **修正**。`command_invokes_script`に`command_invokes_git_subcommand`と同じフォールバック段を追加する（上記「概形」参照） |
| 3 | クォートで囲まれたパス（`"$VAR/create-issue.sh"`等）が正規化で`_`へ潰れ、取りこぼす | **既知の制約として受容**。クォート内は「言及」（発火させたくない）と「実行対象パス」（発火させたい）を`CommandPosition.sh`の正規化だけでは区別できない構造的な制約（issue #53のクォート内非発火の設計と表裏一体）。issue #149の受け入れ条件にも明記が無いため、無理に解消せず、現状の挙動（miss）を回帰テストで固定し、specへ既知の制約として明記する（下記「やらないこと」） |
| 4 | PowerShell経路・バックスラッシュ区切りパス（`.claude\scripts\src\create-issue.sh`）が、normalizeのバックスラッシュエスケープ処理でパス区切りごと消え、basenameが一致しなくなる | **既知の制約として受容**。`CommandPosition.sh`のnormalizeはbash構文前提であり、この制約は`block-direct-git-commit.sh`が既にPowerShell経路へ同じ判定を適用している時点で共有している既存の制約（本issueが新たに生んだものではない）。アーキテクチャレベルの修正は本issueのスコープ外（「やらないこと」に明記し、現状の挙動を回帰テストで固定する） |
| 5 | `cli_match`を`main()`内で定義する案は、`source`して`main()`を実行せず`is_issue_create_call`を直接呼ぶ既存テスト4件を落とす | **修正**。3段ガードをトップレベルへ移す（上記「`post-issue-create-notice.sh`の3段ガード（改訂）」） |
| 6 | 3段ガードの置き換え後コードに`lib_dir`/`lib`の算出（および相対起動時のフォールバック代入）が無く、無言で縮退する | **修正**。上記の置き換え後イメージへ`_pin_lib_dir`/`_pin_lib`の算出を含めた |
| 7 | 公開関数`command_invokes_script`が、呼び出し側がパス付きでスクリプト名を渡した場合に無言で常に不一致になる | **修正**。関数内でbasename・`.exe`除去を行うようにした（上記「概形」参照） |
| 8 | 共有ライブラリ（`CommandPosition.sh`）を変更するのに、他の利用元hookの回帰確認・変更前後diffでの確認が検証に入っていない | **修正**。「検証」節へ`test_block_direct_git_commit.sh`の実行と、ブランチ分岐点との`git diff`確認を追加した |
| （spec反映先の不足） | `command-position.md`の「公開インターフェース」表・「利用元」・「判定の3段」§3も更新対象だが、全体作業計画のフェーズ4節が2箇所しか列挙していない | 個別反映計画（flow-id 4-1）を作る際に、この3箇所も反映先として明示する |
| （hookヘッダコメント） | 差し替え後に事実と異なる記述が残る（現状/既知のトレードオフ/前置フィルタ節のコメント） | **修正**。上記「変更対象」表に明記した |
| （HTML同期） | HTMLビューがmdの`###`3節・概形コード・前置フィルタ節を欠いている | **修正**。本改訂に合わせて`plans/…html`を同期する |

## やらないこと（スコープ外）

- MCP経路の判定変更（判断は全体作業計画へ送った）
- 他の3本のhookへの変更
- `.claude/settings.json` の `if` フィルタ変更
- **クォートで囲まれたスクリプトパスの検知**（既知の制約。上記「設計改訂」3点目）。
  `bash "$VAR/create-issue.sh"` のような呼び出しは発火しない。回帰テストで現状の挙動を固定する
- **PowerShell経路でのバックスラッシュ区切りパスの検知**（既知の制約。上記「設計改訂」4点目）。
  `.claude\scripts\src\create-issue.sh` のような呼び出しは発火しない。回帰テストで現状の挙動を固定する。
  `block-direct-git-commit.sh` も同じ制約を共有しており、本issueが新たに生んだ後退ではない

## 検証

```bash
bash -n .claude/hooks/lib/CommandPosition.sh
bash -n .claude/hooks/post-issue-create-notice.sh
bash .claude/scripts/test/test_command_position.sh
bash .claude/scripts/test/test_post_issue_create_notice.sh
bash .claude/scripts/test/test_block_direct_git_commit.sh
git diff <ブランチ分岐点のSHA> -- .claude/hooks/lib/CommandPosition.sh
```

合格条件:
- 上記3本のテストスクリプトが、追加ケースを含めて `passed=N failures=0` を出すこと
  （`test_block_direct_git_commit.sh` は既存の共有関数（`_cp_scan_tokens`・
  `command_invokes_git_subcommand`等）を変更していないことの回帰確認）。
- `git diff` で `_cp_scan_tokens` / `command_invokes_git_subcommand` 等の既存関数に削除行が
  無いこと（新規追加のみであることを確認する）。

## issueの受け入れ条件との対応

| 受け入れ条件 | この計画での対応箇所 |
|---|---|
| 発火しないこと（cat/grep/ドキュメント編集、コメント内、ヒアドキュメント本文内） | `test_command_position.sh` + `test_post_issue_create_notice.sh` へ追加（sticky修正込み） |
| 発火すること（単体実行、`cd … && …`、改行区切り2行目、`bash <パス>`） | 同上 |
| CommandPosition.shを再利用し公開関数を足す | `command_invokes_script` |
| 3段ガードでの縮退 | `post-issue-create-notice.sh` トップレベルの `_pin_cli_match` |
| test_post_issue_create_notice.sh全件failures=0 | 実施・確認 |
| spec更新（command-position.md「未決定事項・懸念点」「公開インターフェース」表「利用元」「判定の3段」§3、issue-mr-workflow.md「既知のトレードオフ」） | 個別反映計画（flow-id 4-1）で扱う |
