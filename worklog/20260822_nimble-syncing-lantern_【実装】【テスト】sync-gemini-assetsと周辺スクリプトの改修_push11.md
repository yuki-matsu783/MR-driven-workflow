---
title: 【実装】【テスト】sync-gemini-assetsと周辺スクリプトの改修 push11
type: log
description: issue #70 flow-id 3-9 の作業ログ。敵対的レビューのblocker（配布先.gemini/の消失）を直した際の設計判断と、テストの検出力確認を記録する
tags: [worklog, gemini, blocker, issue-70]
keywords: [孤児検出, force, rm -rf, safe_copy_file, 中断, 検出力, list_gemini_orphans, install-to-project]
---

# worklog: blocker（配布先 `.gemini/` の消失）の修正（push11）

対象: issue #70 / PR #157 / flow-id 3-9（1周目）

## 何が起きていたか

`sync-gemini-assets.sh` の write モードは `rm -rf .gemini` → `mv` で丸ごと置き換える。
このリポジトリでは `.gemini/` の全体が生成物なので何も失われないが、
**`install-to-project.sh` から配布先で実行する形にした時点で前提が変わっていた。**

配布先には Gemini CLI 利用者が自分で書いた `.gemini/commands/*.toml`・`settings.json` が
普通にある。`install-to-project.sh` はそれらを `safe_copy_file`（差分があれば `.bak` へ退避して
警告、`--force` のときだけ上書き）で守る設計なのに、**生成器の呼び出しだけがその契約の外**に
あった。

## 設計で迷った2点

### 1. 「退避」か「中断」か

指摘は3案（検査して中断／`.gemini.bak` へ退避／呼び出し側で確認）を挙げていた。**中断を採った。**

- `.bak` 退避は `safe_copy_file` と同じ形だが、あちらは**ファイル単位**である。
  `.gemini` を**ディレクトリごと** `.gemini.bak` へ退避すると、生成物148件も一緒に退避され、
  何が自前のファイルだったのかが埋もれる。
- 中断なら、失われるファイルを**名指しで**出せる。1バイトも書いていないので、
  ユーザーが退避先も方法も自分で選べる。
- 消してよいと分かっているケース（CI・再インストール）は `--force` で通る。

### 2. 生成器の中断でインストール全体を止めるか

**止めない。** `set -e` に倒すと「`.claude/` 一式は書かれたが `.gitignore`/`.gitattributes` は
未更新」という中途半端な状態で終わる。生成器が中断した時点で `.gemini/` は無傷であり、
他は完了しているので、**警告して続けるほうが復旧しやすい**。

- 完了メッセージにも `⚠️ ATTENTION` として復旧手順を出す（`HAS_WARNED` と同じ形）。
- `install-to-project.sh` 自身の `--force` は生成器へ透過する。呼び出し側で `--force` を
  付けた人は「既存を上書きしてよい」と既に表明しているので、二度聞かない。

## テストの検出力を確認した

T13 は終了コードとファイルの実在を見る形なので「異常が無ければ何も出ない」型ではないが、
`.claude/rules/shell-script-style.md`「テスト」の作法に合わせて**意図的に壊して確かめた**。

```bash
sed -i 's/^  local force=0$/  local force=1/' .claude/scripts/src/sync-gemini-assets.sh
bash .claude/scripts/test/test_sync_gemini_assets.sh   # → passed=60 failures=3
```

**孤児が無いときに `--force` 無しで通ること**も明示的に表明した（T13の5番目）。
これが無いと、既定の挙動が変わっていないことを後から確認できず、flow-id 5-3 の同期が
いつのまにか `--force` 前提になっていても気づけない。

## 危なかった箇所

- **既存テスト「main: 生成物に無いファイルは再生成で消える」が、契約の変更でそのまま偽になった。**
  消すのが正しい挙動だと表明していたテストなので、放置すれば赤くなるが、**逆に「赤くなったから
  直す」で期待値だけ書き換えていたら、blockerをテストで追認するところだった。**
  契約が変わったのだと理解して、T13へ置き換えた。
- `local -a orphans=()` を `set -u` 配下で `"${#orphans[@]}"` 参照するのは安全だが、
  `install-to-project.sh` 側の `GEMINI_SYNC_ARGS` は**空配列の展開**になるため
  `"${GEMINI_SYNC_ARGS[@]+"${GEMINI_SYNC_ARGS[@]}"}"` の形にした（bash 4.3 未満で
  `unbound variable` になるのを避けるため）。
