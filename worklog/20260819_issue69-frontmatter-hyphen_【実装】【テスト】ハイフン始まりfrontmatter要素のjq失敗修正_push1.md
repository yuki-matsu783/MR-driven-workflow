---
title: worklog 20260819 ハイフン始まりfrontmatter要素のjq失敗修正 push1
type: log
description: issue #69（extract-frontmatter.shがハイフン始まりのfrontmatter要素でjqに失敗する）の実装・テストの試行錯誤ログ
tags: [worklog, extract-frontmatter, jq, bugfix]
keywords: [frontmatter, jq, ハイフン, index.jsonl, 位置引数, 終了コード, 回帰テスト, yq, rawfile, 再現]
---

# worklog: 【実装】【テスト】ハイフン始まりfrontmatter要素のjq失敗修正

対象: issue #69（2026-08-19）。
全体作業計画: 無し（非対話的セッションのためPlanモードを使えず、個別作業計画のみ作成した）
個別作業計画: `plans/【実装】【テスト】ハイフン始まりfrontmatter要素のjq失敗修正.md`
push回数: 1

## 試したこと

- **jq単体での再現**（jq 1.7 / この実行環境）。issue本文の記載どおりに再現した。

  ```
  $ jq -nc --args 'def items: $ARGS.positional; items' 'a' '-A' 'b'
  jq: Unknown option -A          # 終了コード2
  $ jq -nc --args 'def items: $ARGS.positional; items' -- 'a' '-A' 'b'
  ["a","-A","b"]                 # 終了コード0
  ```

  境界も確認した。要素0個 → `[]`（`--` を置いたまま位置引数が無くても問題なし）。
  要素自体が2連ハイフンの場合 → `-- 'a' '--' '-A'` は `["a","--","-A"]` になり、
  2つ目以降はそのまま位置引数として扱われる（オプション終端として消費されるのは最初の1つだけ）。

- **スクリプト全体での再現**。`keywords: [git add, -A, pathspec]` を持つmarkdownと通常の
  markdownを置いたディレクトリに対して実行したところ、issue本文の記述と完全に一致した。

  ```
  $ bash .claude/scripts/src/extract-frontmatter.sh --force .tmp-fmrepro
  jq: Unknown option -A
  wrote: .tmp-fmrepro/index.jsonl
  files=2 built=2 reused=0
  script exit=0                 # ← 0で完了してしまう
  ```

  出力された `index.jsonl` は1行目が空行（該当ファイルが丸ごと欠落）、2行目だけが有効なJSON。
  サマリは `built=2` と数えており、**数字だけ見ると成功したように見える**点が特に厄介だった。

- **`--rawfile` 経路の確認**。`ARGS_BYTES_LIMIT`（24576）は `readonly` で書き換えられないため、
  実際に大きなfrontmatter（keywords 901要素、見積り84132バイト）を作って経路を通した。
  末尾の `-A` が正しく保持され、この経路は元から影響を受けていないことを確認した。

- **失敗時の挙動の確認**。修正後は該当ケースが成功してしまい失敗経路を通せないため、
  スクリプトのコピーに「特定ファイルだけ `build_index_line` が1を返す」細工を入れて確認した。
  `error: failed to build index line: ...` を出し、空行を書かず、`failed=1`・終了コード1になった。

- **テストが回帰を検知できることの確認**。`--` だけを外した状態でテストを流し、
  4件が `FAIL`（`passed=19 failures=4`）になることを確認してから元に戻した。
  `--rawfile` 経路と `run_fm_jq` の終了コードのテストは、この変更では落ちない（別の性質を
  見ているため）のが期待どおり。

- **回帰確認**。既存16ファイルの `index.jsonl` を退避し、`--force` でリポジトリ全体
  （63ファイル）を再生成して `mtime` を除いた内容を diff した。差分なし。
  さらにissue本文の実例そのまま（`keywords: [git add, -A, pathspec, --cached, 削除]`）の
  一時ファイルを `plans/` に置いて実行し、2連ハイフンの要素も含めて正しくインデックスされることを
  確認した。

## うまくいったこと

- **`--` の追加**で本丸は解決した。フィルタの直後に置くだけで、追加の外部プロセス起動も
  中間表現の仕様変更も不要（計画で挙げた却下案2つの欠点を両方避けられる）。
- **`run_fm_jq` の `return 0` を外して終了コードを伝播**させたことで、この種の失敗が
  「終了コード0のまま無言で欠落」ではなくなった。`--rawfile` 側は `rm -f "$tmp"` の終了コードで
  上書きされていたため、そちらも `status` へ退避してから返すようにした。
- **`main()` 側で空行を書かずスキップ**するようにしたので、失敗しても `index.jsonl` に
  不正な行が残らない。1ファイルの失敗で全体が止まらないよう、他のファイルは通常どおり書き出し、
  最後にまとめて非ゼロ終了する形にした。
- **`yq` 不在の再現方法**として、`jq` と `mktemp` だけを symlink したディレクトリを `PATH` に
  設定する方法が使えた。この実行環境の `/usr/bin/yq` はmikefarah版ではなくPython版（kislyuk）で、
  `yq -o=json e '.' -` の呼び出しが失敗して自前パーサーへフォールバックしていた
  （＝この環境では既定でフォールバック経路を通る）。PATHを差し替えるテストを併せて持つことで、
  mikefarah版yqがある環境でも両経路を確認できる。

## ダメだったこと

- 最初、`sed` で `--` を一時的に外して「テストが落ちること」を確認しようとしたが、
  パターンが一致せず**何も置換されないまま**テストが通り、「テストが回帰を検知できない」と
  誤解しかけた。`grep` で置換後の状態を確認したところ未置換だと分かり、`python3` での
  文字列置換に切り替えた。**「落ちるはず」の確認は、まず対象が本当に書き換わったかを見ること。**
- `.claude/docs/spec/extract-frontmatter.md` に**生のNULバイトが1つ混入**していた
  （`--rawfile` 経路の説明にある `split(...)` の引数が、エスケープ表記ではなく実際のNULバイトに
  なっていた）。このため `grep` がこのファイルを binary 扱いし、`grep -n` で見出しを
  列挙できなかった。今回の修正対象と同じ経路の説明箇所だったため、あわせて表記を直した。
  なお `grep -c` にNULのANSI-Cクォートを渡すと、`.claude/rules/shell-script-style.md`「テスト」節の
  CRの例と同じ理由（空パターン扱い）で全行にマッチし 259 を返した。実際のNUL混入行数は
  `LC_ALL=C grep -aPc` で数えた 1 が正しい。

## 次の一歩

- 特になし（完了）。

### 引き継ぎメモ（このタスクの範囲外）

- `plans/nested-exploring-cloud.md`・`plans/【実装】【テスト】単体テストの.claude配下への移動.md`・
  `plans/【設計反映】テスト配置変更をspec_DDRへ反映.md`・
  `worklog/20260819_nested-exploring-cloud_..._push1.md` が main 由来で残っている
  （issue #63 の flow-id 5-1 での削除漏れと思われる）。今回のissueの範囲外のため触っていない。
