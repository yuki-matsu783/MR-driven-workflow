---
title: 20260822 【設計】gemini変換規則とsettings写像の確定 push8
type: log
description: 未決だったargsの連結規則とifの写像を、一次情報とstrace実測にもとづいて確定させた記録
tags: [worklog, gemini, hooks, performance]
keywords: [args, escapeShellArg, GEMINI_PROJECT_DIR, if, 前置フィルタ, fork, strace, ディスパッチャ, 超集合, read]
---

# 20260822 【設計】gemini変換規則とsettings写像の確定 push8

flow-id 3-6。**実装の直前に残っていた未決2件を確定させた。** どちらもゴールデンファイル（T9）の
中身を決めるため、コードを書き始める前に片付けると決めていたもの。

## 発端: ユーザーからの提案

前ターンで「`if` は落として hook 側で自己判定する」まで合意したあと、次の提案を受けた。

> 同じタイミングで発火するチェックについてはラップした共通チェックシェルを作成したうえで、
> そのシェルで判定して実行シェルを呼び出す形が性能的に有利ではないか？

**結論から言うと、問題意識は正しく、しかも私の見積もりが1桁小さかった。** 一方で、対処としては
ラップより別の形が良いと判断した。以下はその根拠。

## 実測: 空振り1回は「1 fork」ではなく「14 fork」だった

`if` を落とすコストを、当初は「プロセスが1つ増える（約95ms）」程度と見積もっていた。
`strace -f` で数えたところ、これは誤りだった。

| 早期終了パス（push以外のペイロード） | execve | clone |
|---|---|---|
| 空関数（ベースライン） | 1 | 0 |
| `post-push-usage-report.sh` | 6 | **14** |
| `post-push-compact-prompt.sh` | 6 | **14** |
| `post-issue-create-notice.sh` | 7 | **17** |
| `block-direct-git-commit.sh` | 5 | **10** |

原因は判定そのものではなく、**判定に辿り着くまでの材料取り出し**にあった。

```bash
raw="$(cat)"                                          # コマンド置換 + cat
hook_input="$(printf '%s' "$raw" | jq -c '.' ...)"    # jq 1回目
agent_id="$(... | jq -r '.agent_id // empty')"        # jq 2回目
tool_name="$(... | jq -r '.tool_name // empty')"      # jq 3回目
command="$(... | jq -r '.tool_input.command // empty')" # jq 4回目
command_invokes_git_subcommand "$command" push || exit 0  # ← ここでようやく判定
```

**「対象外なら即終了」と書いてあるが、即終了に辿り着くまでが高い。** `.claude/rules/
shell-script-style.md`「外部プロセス起動のコスト」が繰り返し警告している形そのもので、
hookスクリプト自身がそれを踏んでいた。

さらに、**`if` を落とすとBash用・PowerShell用の2エントリが同一内容になる**ため、重複排除
しなければ同じスクリプトが2回ずつ走る。素朴にやると 4起動 × 14 fork = **56 fork** が毎ツール
呼び出しに乗る計算になる。

## 案の比較: ディスパッチャ（提案）と前置フィルタ

**判定部分をbash組み込みだけで書けば、どちらの案も空関数と同じコストになる**ことが分かった。

```bash
IFS= read -r -d '' raw || true                 # read は組み込み → fork 0
case "$raw" in *push*) ;; *) exit 0 ;; esac    # case も組み込み → fork 0
```

`read` と `case` にプロセス生成が無い以上、**どこにこの4行を置くかで差が付くのは
「起動されるスクリプトの本数」だけ**になる。

| 1ツール呼び出しあたり | execve | clone |
|---|---|---|
| Claude 現状（`if` あり） | 12 | 27 |
| Gemini・`if` 削除のみ | 36 | 83 |
| Gemini・重複排除まで | 24 | 55 |
| **案A ディスパッチャ** | **13** | **27** |
| **案B 前置フィルタ** | **14** | **27** |
| 案B を4本すべてに適用 | **4** | **0** |

**案Aと案Bの差はexecve 1回だけだった。** そのためにディスパッチャを入れる判断はしなかった。

### 案Bを採った理由

1. **`.gemini/` にだけ存在する手書きスクリプトを作らずに済む。** issue #70 は「`.gemini/` を
   `.claude/` の変換生成物にする」ことが目的なので、変換元を持たないファイルを足すと、
   消したはずの二重管理が形を変えて戻ってくる。
2. **前置フィルタは `.claude/hooks/` 側の変更なので、Claude Codeにも効く。** 表の最終行が
   その効果で、`if` を持たず毎回起動している2本にも同じ手を入れると **27 clone → 0** になる。
   ディスパッチャ案はここに届かない（Claude側は `if` があるので束ねる対象が無い）。
3. **押し込む場所が既存関数の冒頭4行で済む。** 判定本体には触らないので、退行の範囲が狭い。

push系hookが増えたらディスパッチャが有利になる。そのときに移る。

### 超集合であることが要点

**前置フィルタのパターンは、精密判定の超集合でなければならない。**

```
git push          -> 通す
git  push         -> 通す
git -C /x push    -> 通す   ← `git[[:space:]]+push` だとここで取りこぼす
cd a && git push  -> 通す
ls -la            -> 落とす
```

`*push*` を選んだのはこのため。**issue #53 で判定を部分一致から位置ベースへ変えたのは
「誤検知を減らす」ためだったが、前置フィルタでは逆に誤検知側へ倒すのが正しい**——空振りは
後段が無害に落とすが、取りこぼしは機能が黙って死ぬ。同じリポジトリの中で、目的が違えば
正しい方向も逆になるという例になった。

`git[[:space:]]+push` へ縮めたくなる誘惑が実際にあった（既存のフォールバック実装がその形
だから）。**既存コードに同じ文字列があることは、それをコピーしてよい理由にならない**。

## `args` の連結規則 — 想定と逆だった

もう1件の未決。「連結時にこちらで引用符を付ける」と想定していたが、**逆だった。**

一次情報（評価: S）:

| 出典 | 事実 |
|---|---|
| `hookRunner.ts` L519 | `escapedCwd = escapeShellArg(input.cwd, shellType)` |
| `shell-utils.ts` `escapeShellArg` | bashでは `quote([arg])`（shell-quote）でPOSIXクォートする |
| `hookRunner.ts` L527 | `.replace(/\$GEMINI_PROJECT_DIR/g, () => escapedCwd)` |
| `hookRunner.ts` L350 | `GEMINI_PROJECT_DIR: input.cwd`（hookの子プロセス環境にのみ設定） |

**代入される値が既にクォート済み**なので、こちらで囲むと二重になって壊れる。

```
悪い例1: bash "$GEMINI_PROJECT_DIR/.claude/hooks/x.sh"
         → bash "'/c/My Dir'/.claude/hooks/x.sh"   単一引用符がリテラル化する
悪い例2: bash ${GEMINI_PROJECT_DIR}/.claude/hooks/x.sh
         → 置換の正規表現が波括弧形式に一致せず、リテラルのまま残る
良い例:  bash $GEMINI_PROJECT_DIR/.claude/hooks/x.sh
```

**波括弧が使えない点は見落としかけた。** `.claude/settings.json` 側が `${CLAUDE_PROJECT_DIR}` と
波括弧付きで書いているので、機械的に変数名だけ差し替える実装にすると**静かに壊れる**。
L531 に `$CLAUDE_PROJECT_DIR` の互換置換まで用意されているのに、こちらは波括弧付きなので
そちらにも一致しない。「互換のために用意されている」ことが、逆に「使えているはず」という
思い込みを誘う形になっていた。

環境変数解決（`envVarResolver`）は `${VAR}` 形式を扱えるが、**`GEMINI_PROJECT_DIR` はhookの
子プロセス環境にしか存在しない**ため、そちらの経路でも埋まらない。push7で確認した
「未解決の変数はリテラルのまま残る」という挙動と組み合わさると、**エラーにならずに
存在しないパスを叩く**という最も分かりにくい壊れ方になる。

## 次の一歩

未決は無くなったので実装へ入る。変更対象は11件から**13件**（前置フィルタ2本を追加）、
テストは T1〜T10 から **T1〜T12** になった。

- **T11**: 前置フィルタが超集合であること（上の5ケースを含む純粋関数テスト）
- **T12**: 足切りされるペイロードで `jq` が1回も呼ばれないこと。**`PATH` の先頭へ
  「呼ばれたら失敗するスタブ `jq`」を置く**ことで、時間計測に頼らず「forkしていない」を
  決定的に検証できる（`.claude/rules/shell-script-style.md`「起動回数がゼロであることを
  計測で確かめるときは空関数をベースラインに取る」の、計測に頼らない版）

`block-direct-git-commit.sh` と `post-issue-create-notice.sh` への同じ適用は、**効果が大きい
（Claude側 27 clone → 0）が issue #70 の要求範囲外**なので、別issueへ切り出すと計画へ書いた。
