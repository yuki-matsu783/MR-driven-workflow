---
title: 【実装】【テスト】sync-gemini-assetsと周辺スクリプトの改修 push9
type: log
description: issue #70 フェーズ3の実装作業ログ。sync-gemini-assets.shの新規実装と周辺スクリプト改修で決めたこと・踏んだ罠を記録する
tags: [worklog, gemini, 実装, issue-70]
keywords: [sync-gemini-assets, tar, cp--parents, ホワイトリスト, ツール名対応表, matcher, 前置フィルタ, autoCompactWindow]
---

# worklog: 【実装】【テスト】sync-gemini-assetsと周辺スクリプトの改修（push9）

対象: issue #70 / PR #157 / flow-id 3-6

## 実装着手前に決めた3件（計画に書かれていなかった細部）

計画（`plans/【実装】【テスト】…`・`plans/【設計】…`）が確定していない粒度の判断が3件あった。
いずれも**変換規則そのものを変える**ので、ここに理由を残す。

### 1. hookのパスは書き換えない（`.claude/hooks/` のまま）

`args` の連結規則の決定（`【設計】`「`args` の連結規則」）は、良い例として
`bash $GEMINI_PROJECT_DIR/.claude/hooks/x.sh` を挙げている。**パス部分は `.claude/` のまま**である。
一方、現行の手書き `.gemini/settings.json` は `${GEMINI_PROJECT_DIR}/.gemini/hooks/…` を指していた
（`.gemini/hooks` が `.claude/hooks` へのリンクだったため、実体は同じだった）。

**書き換えない方を採る。** 理由は変換規則の単純さではなく**正しさ**である。

- `.gemini/hooks/` を指すと、**同期を忘れた状態で Gemini を動かしたとき、Claude 経路と挙動が
  食い違う**（`.gemini/` 側の古いコピーが走る）。`.claude/hooks/` を指せば、同期の鮮度に関わらず
  両経路が同じスクリプトを実行する。
- 変換で書き換えるのは `${CLAUDE_PROJECT_DIR}` → `$GEMINI_PROJECT_DIR` の**1箇所だけ**になり、
  「`args` は素の連結」という決定と矛盾しない。
- 「では `.gemini/hooks/` のコピーは何のためにあるのか」という問いには、**`.gemini/` は
  `.claude/` を丸ごと写す（除くのは生成物とローカル状態だけ）という単純な規則を保つため**と
  答える（`【実装】【テスト】` の方針1）。`hooks/` だけを例外にすると、その規則が崩れる。

### 2. `autoCompactWindow` は写像しない（未判定だった項目の決着）

調査結果が「10観点の外にあり未判定」として残していた1件。Gemini CLI 側に相当するのは
`model.compressionThreshold`（`packages/cli/src/config/settingsSchema.ts` L1111–L1121）だが、
**意味が違う**。

| | Claude `autoCompactWindow` | Gemini `model.compressionThreshold` |
|---|---|---|
| 値 | `600000`（絶対値） | `0.5`（**コンテキスト使用率の分数**） |
| 既定 | — | `0.5` |

分数と絶対値なので機械的な換算ができない（コンテキスト長を知らないと割り算にならず、その値は
モデル依存で変わる）。**写像せず、既定値に委ねる。**

### 3. 未知のトップレベルキーはエラーにする

調査結果が警告していた「変換スクリプトが情報を落としていることを単体テストが永久に緑で通す」を
塞ぐため、`.claude/settings.json` のトップレベルキーを次の3つに分類し、**どれにも該当しない
キーが現れたら非0で落とす**。

| 分類 | キー |
|---|---|
| 写像する | `plansDirectory` / `hooks` |
| **意図的に写像しない**（理由をコメントで持つ） | `permissions`（policy engineのWorkspace層が無効。upstream #18186）/ `autoCompactWindow`（上記2） |
| それ以外 | **エラー** |

ホワイトリスト方式を agents だけでなく settings にも効かせる、ということである。

## 実装で踏んだ罠

### ファイルコピーで148回forkしない

`.claude/` 配下は148件。`cp` をファイルごとに呼ぶと git bash で約95ms × 148 ≒ 14秒になる
（`.claude/rules/shell-script-style.md`「外部プロセス起動のコスト」）。

`printf '%s\0' … | xargs -0 cp --parents -t "$DST" --` の形にして、**fork回数をファイル数に
依存しない定数**へ抑えた。`xargs` が引数長の上限（Windowsで約32KB）に応じて自動で分割するので、
`.claude/` が将来大きくなっても `Argument list too long` にならない。

`cp --parents` は相対パスの階層をコピー先へ再現するため、`cd "$SRC"` した実サブシェルの中で
実行する。

### 除外は `git ls-files --exclude-standard` に任せる

「生成物とローカル状態だけを除く」という規則は、`git ls-files --cached --others
--exclude-standard` がそのまま実装している（`index.jsonl` も `.claude/state/` も `.gitignore`
対象なので列挙されない）。**`git check-ignore` をファイルごとに呼ぶ必要はない**
（計画では「まとめて渡す」としていたが、そもそも呼ばずに済んだ）。

ただし `--cached` は**削除したがまだステージしていない**追跡ファイルも列挙するため、
`[[ -f ]]` で落とす（issue #117 と同じ罠。`[[ ]]` は組み込みなのでforkは増えない）。
