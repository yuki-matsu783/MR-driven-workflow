---
title: 【実装反映】setup-gemini-links.sh の失敗握りつぶしの修正
type: plan
description: フェーズ3のレビュー往復では扱わず持ち越した、place_real_copy が cp -R の失敗を成功として報告する不具合を直す
tags: [plan, 実装反映, shell-script, gemini]
keywords: [setup-gemini-links, place_real_copy, cp, set -e, 終了コード, 失敗握りつぶし, run_or_fail, 単体テスト]
---

# 【実装反映】setup-gemini-links.sh の失敗握りつぶしの修正

flow-id 4-6（実装反映）の1つ目。**フェーズ3のレビュー往復ループ（3-6〜3-9）の外で見つかり、
フェーズ4へ持ち越すと決めた不具合**を扱う。

## この計画の範囲

`.claude/scripts/src/setup-gemini-links.sh` の `place_real_copy` が、**コピーに失敗しても
「作成しました（実体コピー）」と表示し、終了コード0で終わる**問題を直す。

**範囲外**: 同スクリプトのリンク作成経路（symlink / NTFSジャンクション）の挙動そのもの、
`.gemini/` の層の扱い（`local` のままで確定済み。フェーズ2の調査結果）。

## 何が壊れているか（現状）

3箇所が重なっている。

```bash
# 93-104行目
place_real_copy() {
  local name="$1" link_path="$2" target_path="$3"
  mkdir -p "$link_path"
  cp -R "${target_path}/." "${link_path}/"     # ← 失敗しても止まらない
  cat <<MSG
作成しました（実体コピー）: .gemini/${name}   # ← 失敗しても出る
...
MSG
}

# 155-156行目
  place_real_copy "$name" "$link_path" "$target_path"
  return 0                                     # ← 戻り値を見ずに成功を返す

# 164行目
    setup_target "$t" || fail=1                # ← `||` が set -e を関数内部まで一時停止させる
```

- `setup_target` は `|| fail=1` という**条件式の中で呼ばれている**ため、`set -e` の
  「失敗したら即座に終了する」動作が**その関数の内部にまで及んで一時停止**する
  （`.claude/rules/shell-script-style.md`「bashでのtry/catch相当の書き方」）。
  したがって `cp -R` が失敗しても `place_real_copy` は続行する。
- 続行した先で `cat <<MSG` が**無条件に成功メッセージを出す**。
- 呼び出し側の `return 0` が、戻り値を見ずに成功を確定させる。

**結果**: 配布先で `.gemini/rules` が空・欠けたままなのに「作成しました」と表示され、
`main` の `fail` も立たないので終了コードも0になる。フェーズ3の敵対的レビュー2回目で
`merge_json_keys` に見つけたのと**同じ「失敗が成功として報告される」類型**である。

## 直す方針

`install-to-project.sh` で導入済みの `run_or_fail <説明> <コマンド...>` と同じ形へ揃える
（同じ類型の不具合に別々の対処を持ち込まない）。

1. `place_real_copy` の `mkdir -p` と `cp -R` を、終了コードを検査する形にする。
   失敗したらメッセージを標準エラーへ出し、**非0で戻る**。
2. 成功メッセージ（`cat <<MSG`）は、コピーが成功した経路でだけ出す。
3. 呼び出し側（155〜156行目）の `return 0` をやめ、`place_real_copy` の戻り値をそのまま返す。
4. **`setup_target` を `|| fail=1` で呼ぶ形は変えない**（複数ターゲットのうち1つが失敗しても
   残りを試す意図があるため）。代わりに、`set -e` が一時停止していても失敗が伝わるよう、
   上記1〜3で**明示的に終了コードを検査する**。

`sync_real_copy`（`real` 経路。122〜123行目）にも同じ握りつぶしが無いかを併せて確認し、
あれば同じ形で直す。

## 変更するファイル

| ファイル | 変更 |
|---|---|
| `.claude/scripts/src/setup-gemini-links.sh` | `place_real_copy` / 呼び出し側 / （必要なら）`sync_real_copy` |
| `.claude/scripts/test/test_setup_gemini_links.sh` | **既存**（確認済み）。下記の表明を追加する |

## 新規・追加する表明

いずれも**副作用が実リポジトリへ及ばないよう、一時ディレクトリを `REPO_ROOT` に見立てて**行う。

| # | 表明 |
|---|---|
| 1 | コピー元が存在し書き込める場合、`.gemini/<name>/` に中身が複製され、終了コードが0 |
| 2 | **コピー先が書き込めない場合**（`chmod 500` した親ディレクトリ等）、成功メッセージが出ず、終了コードが非0 |
| 3 | 同上の場合、`main` の集約が非0で終わる（1ターゲットの失敗が全体の失敗として表れる） |
| 4 | 失敗時のメッセージが**標準エラー**へ出る（標準出力へ混ぜない） |

**表明2・3は、直す前の実装で実際に落ちることを確認してから直す**（フェーズ3で
「自分の書いた回帰テストが blocker を検出できていなかった」という失敗を踏んでいるため）。

## 検証（この計画の完了判定に実際に流すコマンド）

```bash
bash -n .claude/scripts/src/setup-gemini-links.sh
bash .claude/scripts/test/test_setup_gemini_links.sh     # passed=N failures=0
for t in .claude/scripts/test/test_*.sh; do bash "$t" | tail -1; done   # 全ファイル failures=0
bash .claude/scripts/src/check-dist-coverage.sh          # 分母が変わっていないことの確認
```

- **テストファイルは新規に増えない**（既存の `test_setup_gemini_links.sh` へ表明を足す）ので、
  網羅性チェックの分母は変わらない。変わっていたら想定外の変更が混ざっている。

## この計画の中で互いの前提を崩していないか（自己点検）

- **`run_or_fail` は `install-to-project.sh` のローカル関数であり、`setup-gemini-links.sh` からは
  呼べない。** 「同じ形へ揃える」とは書き方を揃えることであって、関数を共有することではない
  （共有するなら `.claude/scripts/src/` に共通ライブラリを新設する話になり、この計画の範囲を
  超える）。実装時に取り違えないこと。
- **`.gemini/` は `local` 層で、インストーラは触らない**（フェーズ2の調査結果・受け入れ条件2）。
  この修正は配布の挙動を変えない。受け入れ条件8を満たすのは引き続きこのスクリプトである。
- **この修正はフェーズ3の受け入れ条件の充足に影響しない。** 実装結果レポートの「受け入れ条件の
  充足（実測）」を書き換える必要は無い（結果は `reports/…実装結果.md` ではなく、
  この反映の結果レポートへ書く）。
