---
title: worklog 20260818 extract-frontmatter高速化と中断耐性 push2
type: log
description: issue #11 extract-frontmatter.shの高速化・中断耐性の実装と検証結果（push2）
tags: [worklog, extract-frontmatter, performance]
keywords: [extract-frontmatter, index.jsonl, jq, サブシェル, fork, mtime, キャッシュ, 原子的更新, ゴールデンファイル, 回帰テスト, 中断耐性]
---

# worklog: 【設計】【実装】【テスト】extract-frontmatter高速化と中断耐性

対象: `.claude/scripts/src/extract-frontmatter.sh` の高速化と中断耐性（2026-08-18）。
全体作業計画: `plans/lexical-stirring-peach.md`
個別作業計画: `plans/【設計】【実装】【テスト】extract-frontmatter高速化と中断耐性.md`
push回数: 2

## 試したこと

### 1. ベースライン計測（改修前）

| 対象 | 所要時間 |
|---|---|
| `.claude/docs/ddr`（16ファイル） | **46.4秒** |
| リポジトリルート `.`（46ファイル） | **136秒** |

issueに書かれていた「ルート指定で2分でタイムアウト」「ddr単体で44秒」を実機で再現できた
（2分のタイムアウトはClaude CodeのBashツール既定値であり、スクリプト固有の上限ではない。
上限を伸ばせば136秒で完走する）。

### 2. 回帰検証の方法を変更した（重要）

個別作業計画では「クリーンな作業ツリーで全再生成し `git diff -- '*index.jsonl'` が空」を回帰検証と
していたが、**この方法は成立しないと判明した**。理由は2つ。

- **コミット済みの `index.jsonl` が現行実装の出力と一致していない（陳腐化している）**。
  `.claude/rules/index.jsonl` には**削除済みの `plan-mode-safety.md` のエントリが残っていた**し、
  `.claude/skills/apply-mr-workflow-to-project/index.jsonl` は**そもそも存在しなかった**。
  再生成が遅すぎて回せなかった結果であり、issue #11 が解こうとしている問題そのものの帰結。
- **`mtime` はgitのcheckout/mergeでファイルのmtimeが更新されるため、ブランチ操作だけで変わる**。
  実際、`docs-workflow.md` / `git-workflow.md` のmtimeがブランチ切り替えで当日時刻に更新されていた。

**代替: ゴールデンファイル方式**に切り替えた。改修前の実装でリポジトリ全体を1回実行し、生成された
15個の `index.jsonl` をスクラッチ領域へ退避（golden）。改修後の出力をこのgoldenとバイト単位で
比較する。両方の実行の間にmarkdownを変更しなければ `mtime` も一致するため、完全な回帰テストになる。

### 3. 改修（3段階）

**(a) jq起動を1ファイル1回へ集約**

`frontmatter_block_to_json` がキー・配列要素ごとに `jq` を呼んでいた（`json=$(jq -c ... <<<"$json")`）
のを、解析結果を中間表現（`種別 キー 値` の3要素組）としてグローバル配列 `FM_ITEMS` へ溜め、
`jq --args` へ1回だけ渡す形へ置き換えた。jq側は `reduce range(0; length; 3)` で畳み込む。
最終行の組み立ても `build_index_line` として同じjq呼び出しへ統合した。

あわせて `realpath`（リポジトリルートへ `cd` して不要化）、`dirname`（bashの文字列操作）、
`date -d @epoch`（bash組み込みの `printf '%(...)T'`）、`stat`（`xargs -0` で一括取得）、
`tr -d '\r'`（bashのパラメータ展開）を、すべて外部プロセス起動なしへ置き換えた。

→ ddr 16ファイルで **46.4秒 → 9.7秒**（4.8倍）。

**(b) コマンド置換によるサブシェルforkの排除**

9.7秒はまだ遅く、残りの支配要因は `part="$(unquote "$(trim "$x")")"` のような**コマンド置換**
だった。コマンド置換は呼び出しのたびにサブシェルをforkするため、1ファイルあたり十数回呼ばれる
解析ホットパスでは致命的に効く。結果を標準出力ではなくグローバル変数 `REPLY` へ返す
`trim_unquote_to_reply` / `unquote_to_reply` を追加して置き換えた（`trim` / `unquote` は公開関数
として互換のため残した）。

→ ddr 16ファイルで **9.7秒 → 3.0秒**（合計 **15倍**）。

**(c) mtimeキャッシュと原子的更新**

- 既存 `index.jsonl` をbashの正規表現だけで読み、`concept_id` → 行 / mtime のマップを作る
  （外部プロセス起動0回）。mtimeが一致する行はそのまま再利用する。
- `--force` / `-f` でキャッシュを無効化。
- スクリプト自身のmtimeが `index.jsonl` より新しければ、そのディレクトリはキャッシュを使わない
  （解析ロジックを変えたのに古い行が残る事故を防ぐ）。
- 出力は全走査完了後に `index.jsonl.tmp.<PID>` へ書き `mv -f` で差し替える。
  `trap cleanup_tmp_files EXIT INT TERM` で中断時に一時ファイルを削除する。
- 内容が既存と同一なら書き換えず `unchanged:` を出す。

## うまくいったこと

### 性能

| 実行 | 改修前 | 改修後 |
|---|---|---|
| `.claude/docs/ddr`（16ファイル） | 46.4秒 | **3.0秒**（15倍） |
| リポジトリルート（46ファイル、全再生成） | 136秒 | **9.6〜11.8秒**（約12倍） |
| リポジトリルート（差分なし・キャッシュ有効） | ― | **1.5〜2.4秒**（`built=0 reused=46`） |

### 回帰なし（ゴールデン比較）

改修後に `--force` でリポジトリ全体を再生成し、改修前の出力（golden 15ファイル）と比較して
**全ファイルがバイト単位で完全一致**した。唯一の差分は、差分スキップの動作確認のために意図的に
`touch` した `0003-レビュースレッド解決は自動化しない.md` の `mtime` 1箇所のみで、これは期待どおりの挙動。

### 中断耐性

`timeout -s INT 2s` で `--force` 実行を強制中断し、以下を確認した。

- 15個すべての `index.jsonl` のmd5が中断前と一致（**内容が保持されている**）
- `index.jsonl.tmp.*` が1つも残っていない

対照として**改修前の実装**を同じ手順（`timeout -s INT 5s` で `.claude/docs/ddr` を実行）で中断すると、
`index.jsonl` が **16行 → 2行** に破損した。issue #9で報告された「18行→14行に破損」と同種の事象を
再現できた。改修後の実装で再生成して復旧した。

### 単体テスト

`tests/test_extract_frontmatter.sh` を新設（`tests/` ディレクトリ自体が無かったため新規作成）。
`passed=17 failures=0`。スカラー / フロー配列 / ブロック配列 / 空配列 / クォート付き値 / 真偽値 /
frontmatter無し / CRLF改行 / 中間表現 / `trim`・`unquote` 系 / `resolve_repo_root` /
`build_index_line` を網羅した。

### 既知バグ（specの未決定事項）

「ディレクトリを絞って実行すると、スコープ外のディレクトリの `index.jsonl` まで変更され、
ルート `index.jsonl` に重複行が生じることがある」は、**改修前・改修後のいずれでも再現しなかった**。

- 改修前に `extract-frontmatter.sh .claude/rules` を実行 → 変化したのは `.claude/rules/index.jsonl`
  のみ。その差分の内訳は「mtime更新2件」と「削除済み `plan-mode-safety` エントリの除去1件」で、
  **スコープ外への影響ではなかった**。
- 改修後に同じ操作を実行 → `files=6 built=0 reused=6` / 変化なし（全 `index.jsonl` のmd5が不変）。
- 全 `index.jsonl` に `concept_id` の重複行は0件。

→ **報告された現象は「スコープ外への漏れ」ではなく、`mtime` のブランチ操作による更新と、
陳腐化したエントリの除去を、スコープ外への影響と誤認したものだった可能性が高い**。改修後は
「内容が同じなら書き換えない（`unchanged:`）」ため、この種の誤認自体が起きにくくなった。

## ダメだったこと

- **キャッシュ自動無効化の初版に欠陥があった**。「内容が変わらず `unchanged` だったファイルは
  mtimeが更新されない」ため、スクリプトのmtimeより永久に古いままとなり、**差分が無くても毎回
  全ファイル再生成され続けた**（`built=16 reused=30` のまま減らない）。`unchanged` のファイルにも
  `touch` でmtimeだけ付け直す処理を加えて解消した（gitはmtimeを見ないためリポジトリに差分は出ない）。
  実行して初めて気づける類の不具合で、キャッシュ実装では定番の落とし穴。
- Bashツールへヒアドキュメントで長いスクリプト全文を渡そうとしたところ、引用の解釈が崩れて
  `unexpected EOF while looking for matching '` になった。長いファイルの新規作成はWriteツールを使う。

## 次の一歩

- flow-id 3-7: commit・pushしてレビュー依頼（push2）。
- **レビューで判断が必要な点**: 再生成された `index.jsonl` を今回どこまでコミットするか。
  今回は「クリーンな作業ツリーで実行すると差分が出ない」状態を保つため**すべてコミットする**方針に
  したが、`plans/index.jsonl`（新規）と `worklog/index.jsonl`（push1のworklogエントリが増える）は
  flow-id 5-1で削除される一時ファイルを指しているため、5-1の手順に
  「`plans/index.jsonl` の削除と `index.jsonl` 群の再生成」を追加すべきかを決めたい。
- フェーズ4（反映）: spec更新・DDR新設・`.claude/rules/shell-script-style.md` への
  「ループ内でjq等を起動しない」「コマンド置換もforkコストを持つ」ルール追記。

---
