---
title: i33-03. .gitattributesは配布先へ丸ごとコピーせず必要な行だけ追記する
type: ddr
description: 配布先の.gitattributesを全文置換せず行追記にし、判定を行全体の一致で行うと決めた記録
tags: [ddr, distribution, gitattributes]
keywords: [gitattributes, 行追記, 全文置換, grep -Fxq, 冪等, eol=lf, text=auto, install-to-project]
---

# i33-03. `.gitattributes`は配布先へ丸ごとコピーせず必要な行だけ追記する

issue #33。

## 背景

`.claude/rules/shell-script-style.md` は、`.sh` のLF改行の保証について
「`.gitattributes` に `*.sh text eol=lf` を追加する運用も検討できる（未導入）」と書いており、
実際の保証は各開発者の `core.autocrlf` 設定という個人環境依存のままだった。CRLFで取り出された
`.sh` はシバン行の解釈に失敗し `bash: $'\r': command not found` で動かない。

本家へ `.gitattributes` を置くこと自体に異論は無いが、**配布先へどう届けるか**は別の判断が要る。
`install-to-project.sh` の既定の配置方法（差分があれば `.bak` 退避のうえ全文置換）を
`.gitattributes` へ適用してよいのかが論点になった。

## 決定

**配布先の `.gitattributes` は全文置換しない。必要な行が無ければ末尾へ追記するだけにする。**

- 追記するのは **`*.sh text eol=lf` の1行のみ**。本家の `.gitattributes` にある
  `* text=auto` は**配らない**。
- 追記済みかどうかの判定は、部分一致ではなく**行全体の一致**（`grep -Fxq`）で行う。
  ただし**判定の前にCRを落とす**（配布先の `.gitattributes` はWindowsではCRLFで取り出されるため）。
- 配る行の定義は本家の `.gitattributes` が持ち（`# --- dist:begin ---` 〜 `# --- dist:end ---`）、
  スクリプト側へ書き写さない。
- 何度適用しても行が増えない（冪等）。
- 配布先の `.gitattributes` が末尾に改行を持たない場合は、追記前に改行を1つ補う。

実装は `install-to-project.sh` の `ensure_gitattributes_rules`。仕様は
[.claude/docs/spec/distribution-assets.md](../spec/distribution-assets.md)。

## 理由

### 全文置換にしない

issue #33 の調査で、使い捨ての配布先へ独自の `.gitattributes`
（`*.png binary` / `*.md text eol=lf diff=markdown`）を置いた状態で適用する実験を行った。
全文置換すると、これらの指定が消える。

`.bak` 退避があるとはいえ、**失われるものの性質が悪い**。`*.png binary` が消えると、以後 Gitは
PNGをテキストとして扱い、改行正規化によって**ファイルが破損した状態でコミットされる**。破損は
その時点では気づかれず、履歴に残る形で蓄積する。「あとで `.bak` を見て手でマージする」という
前提に立てる種類の変更ではない。

### 末尾追記が意味論としても正しい

`.gitattributes` は**後に書いた行が優先される**。末尾への追記は「配布先の既定を尊重しつつ、
配布したスクリプトに必要な指定だけを上書きする」という、まさに意図どおりの挙動になる。
配布先が意図的に `*.sh text eol=crlf` と書いていた場合にそれを上書きしてしまうが、その状態では
配布したスクリプトが動かないため、上書きする側が正しい。

### `* text=auto` を配らない

リポジトリ全体の正規化方針は配布先が決めるべきものである。勝手に足すと、配布先の既存ファイルが
次のコミットで一斉に正規化されうる（巨大な無関係diffが発生し、`git blame` も汚れる）。
配るのは「配布したスクリプトが動くのに必要な最小限」に限る。

### 判定を行全体の一致にする

最初は部分一致（`grep -Fq`）で実装したが、**失敗の向きが悪い**ため行全体の一致へ変更した。

- 部分一致だと、配布先が `# *.sh text eol=lf を入れるか検討中` のようにコメントで言及している
  だけでも「もう有る」と判定し、**必要な指定が入らないまま無言で終わる**。配布したスクリプトが
  CRLFで壊れても、誰も気づけない。
- 行全体の一致で万一取りこぼしても、起きるのは「同じ行が2度書かれる」ことだけで、
  `.gitattributes` の解釈は変わらない。

`.claude/scripts/test/test_install_to_project.sh` に、コメントだけを置いた配布先に対して
指定が入ることを確かめるケースを置いた。判定をわざと部分一致へ戻すと、このケースだけが落ちる
ことを実機で確認している。

### CRを落としてから判定する

`grep -Fxq` は行全体の一致を要求するため、配布先の `.gitattributes` が作業ツリーでCRLFになって
いると `*.sh text eol=lf\r` と一致せず「まだ無い」と判定される。Git for Windowsの既定は
`core.autocrlf=true` で、しかも**配る規則 `*.sh text eol=lf` は `.gitattributes` 自身には効かない**
ため、一度コミットされた配布先の `.gitattributes` は以後ずっとCRLFで取り出される。つまり
**この機構が主に想定するWindows環境でこそ、適用のたびに同じ行が追記され続ける**。

この壊れ方は「初回だけCRLFのフィクスチャ」では再現しない（追記した行はLFのまま残るので、
2回目は素直に一致する）。テストでは**適用のたびにファイル全体をCRLFへ正規化**して、
「コミット→チェックアウトのたびに全体がCRLFへ戻る」実際の状況を作っている。CR除去を外すと
このケースだけが `expected: 1 / actual: 3` で落ちることを確認した。

## 却下した案

- **他のルートファイルと同じ `safe_copy_file` で配る**: 実装は1行で済むが、上記のとおり配布先の
  設定を破壊しうる。
- **配らない（本家だけがLFを保証する）**: 配布物には `.sh` が多数含まれており、**配布先でこそ**
  この保証が要る。本家だけで保証しても意味が薄い。
- **配布先の `.gitattributes` を読み、AIが都度マージする**: 配布は非対話のスクリプトで完結すべき
  であり、実行のたびに判断を要する設計にはしない。
- **配る行を `install-to-project.sh` の配列へ直接書く**: 最初はこの形で実装したが、
  `sync-assets.sh` が `assets/.gitattributes` を集めているのに誰も読まない状態になり、
  「本家の `.gitattributes` へ配布したい行を足しても配布先へ永久に届かない」という食い違いを
  生んだ。マーカー方式へ変更し、定義を本家の1ファイルへ寄せた。
