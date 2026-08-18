---
title: issue #11 全体作業計画 — extract-frontmatter.shの高速化と中断耐性
type: plan
description: extract-frontmatter.shのjq起動回数を1ファイル1回まで削減し、mtimeキャッシュによる差分スキップと一時ファイル差し替えによる原子的更新を導入する
tags: [extract-frontmatter, performance, atomic-write]
keywords: [extract-frontmatter, index.jsonl, jq, プロセス起動, mtime, キャッシュ, 原子的更新, 中断耐性, git ls-files, frontmatter]
---

# 全体作業計画: issue #11 対応

## Context

`.claude/scripts/src/extract-frontmatter.sh` は、markdownのYAML frontmatterを抽出して
ディレクトリごとの `index.jsonl` を生成するスクリプト（仕様:
[.claude/docs/spec/extract-frontmatter.md](../.claude/docs/spec/extract-frontmatter.md)）。
`.claude/rules/markdown-frontmatter.md` は「frontmatterを更新したら再生成する」運用を定めているが、
**リポジトリルート（`.`）を指定した一括実行が2分でタイムアウトし完了しない**。さらに走査中に
`index.jsonl` を直接truncate＋追記しているため、**中断すると既存の `index.jsonl` が不完全な状態で
壊れる**（issue #9対応時に `.claude/docs/ddr/index.jsonl` が18行→14行に破損した実例あり）。
結果として、frontmatter規約が定める再生成手順が実質的に運用できない状態になっている。

### 原因（本計画作成時に実測で特定済み）

git bash（MSYS）上での**外部プロセス起動が約95ms/回**と非常に重い（`jq -nc '1'` を50回実行して
4.73秒 = 94.6ms/回、実機計測）。現行実装はこれをファイルあたり約30回起動している。

| 箇所 | ファイルあたりの起動回数 |
|---|---|
| `frontmatter_block_to_json` が**キー1つ・配列要素1つごと**に `jq` を呼ぶ（`json=$(jq -c ... <<<"$json")` の累積更新） | 約20〜30 |
| 最終行を組み立てる `jq -nc` ＋ `tr -d '\r'` | 2 |
| `realpath` / `dirname`×2 / `stat` / `date` | 5 |

対象markdownは43ファイル（`git ls-files` で確認）。43 × 約30回 × 95ms ≈ **約2分**となり、
issueに報告された症状（ルート指定でタイムアウト、`.claude/docs/ddr` 15ファイル単体で44秒）と一致する。
**アルゴリズムではなくプロセス起動回数が支配的**であり、ここを削れば桁で改善する。

## 実施フェーズ

ボトルネックの特定が本計画作成時点で完了しているため、**フェーズ2（調査）は実施せず、
フェーズ3（設計・実装・テスト）から着手する**（ユーザ合意済み）。ベースライン実測は実装フェーズの
冒頭で行い、worklogに記録する。

## 対象範囲（フェーズ3で実施）

修正対象は `.claude/scripts/src/extract-frontmatter.sh` の1ファイル（＋新規テスト1ファイル）。
**frontmatterの解析ロジック（行の正規表現・`trim`/`unquote`・yq優先パス）は変更しない**。
変更するのは「解析結果をJSONへ組み立てる方法」「ファイル情報の取得方法」「出力の書き方」の3点に絞り、
回帰リスクを最小化する。

### 1. jq起動をファイルあたり1回にする（高速化の本丸）

- `frontmatter_block_to_json` を、解析結果を**シェル配列の中間表現へ溜める**形へ変更する
  （`種別 キー 値` の3要素組。種別はスカラー/真偽値/配列要素の別を表す）。ループ内での `jq` 呼び出しを
  すべて廃止する。
- 溜めた中間表現を `jq -nc --args ... "${items[@]}"` に**1回だけ**渡し、jq側で
  `$ARGS.positional` を畳み込んでJSONオブジェクトを構築する。
- 最終行（`concept_id` / `directory` / `frontmatter` / `mtime`）の組み立ても**同じjq呼び出しに統合**する。
- 引数長の上限に注意する（`.claude/rules/shell-script-style.md`「大きなJSONを`--argjson`/`--arg`で
  渡さない」。実測でおよそ32KB）。frontmatterは高々数百バイトのため直接渡して問題ないが、
  上限に達しうる長大なfrontmatterを検出した場合は一時ファイル経由へフォールバックする。

### 2. jq以外の外部コマンド起動も削る

- `main` の冒頭で `cd "$repo_root"` し、`git ls-files` の出力を常にリポジトリルート相対に揃える
  → `realpath --relative-to` が**不要**になる（`resolve_repo_root` はそのまま使う）。
- `dirname` → bashの文字列操作（`${rel%/*}`、`/` を含まなければ `.`）に置換する。
- `date -d "@$epoch"` → bash組み込みの `printf '%(%Y-%m-%dT%H:%M:%S)T'` に置換する（起動0回）。
- `stat -c %Y` → 全対象ファイル分を**1回のバッチ呼び出し**（`xargs -0 stat -c '%Y %n'`）でまとめて取得し、
  連想配列に持つ。`xargs` が引数長上限を自動分割するため大規模リポジトリでも安全。
- `tr -d '\r'` は最終書き出し時に1回だけ通す（Windows版native jqのCR付与対策。仕様維持）。

**見積: キャッシュ無効時で 43ファイル × 1起動 ≈ 5秒前後**（現行の約2分から改善）。

### 3. mtimeによる差分スキップ

- 既存の `index.jsonl` を読み、`concept_id` → 既存行 の連想配列を作る（bashの正規表現で
  `"concept_id":"..."` / `"mtime":"..."` を取り出す。外部プロセス起動0回）。
- 対象ファイルの現在のmtimeが既存行の `mtime` と一致すれば、**既存行をそのまま再利用**して
  jq呼び出しをスキップする。
- **解析ロジック変更時のキャッシュ自動無効化**: `extract-frontmatter.sh` 自身のmtimeが
  `index.jsonl` より新しい場合は、そのディレクトリを全再生成する（スクリプトを直したのに古い行が
  残る事故を防ぐ）。
- `--force`（`-f`）オプションで、キャッシュを無視した全再生成を明示的に指示できるようにする。
- **見積: 変更が無ければ起動ほぼ0回 → 1秒未満。**

### 4. 原子的更新（中断耐性）

- 現行の「走査中に `: >"$out_file"` でtruncateし1行ずつ追記」を**廃止**する。
- 生成した行はメモリ上（連想配列）に溜め、**全走査完了後**に出力する。出力は同一ディレクトリへ
  `index.jsonl.tmp.$$` として書き、`mv -f` で差し替える（同一ボリューム内のrename）。
- `trap ... EXIT INT TERM` で、中断時に一時ファイルを確実に削除する。
- **内容が既存と同一なら書き換えない**（不要なmtime更新・git差分ノイズを出さない）。
- これにより「実行中に強制中断しても既存の `index.jsonl` が保持される」という受け入れ条件を満たす。

### 5. 既知バグの切り分け（specの未決定事項。スコープに含める合意済み）

specの「未決定事項・懸念点」にある**「ディレクトリを絞って実行すると、スコープ外のディレクトリの
`index.jsonl` まで変更され、ルート `index.jsonl` に重複行が生じることがある（原因未特定）」**を扱う。

- まず再現手順を確立する（作業ツリーをクリーンにした状態で `extract-frontmatter.sh .claude/rules` を
  実行し、`git status` の差分を観測する）。
- 現時点の仮説と対策:
  - **パス表記の揺れ**（`./index.jsonl` と `index.jsonl` が別キーとして扱われる）
    → 上記2の「リポジトリルートへ `cd` してパスを正規化」＋ 上記4の「全走査後にまとめて出力」で
      構造的に解消される見込み。
  - **`git ls-files --cached --others` が同一パスを2回返す**
    → `sort -z` に `-u` を加えて重複排除する（現在のクリーンな作業ツリーでは重複0件を確認済みのため、
      予防的措置の位置づけ）。
- 解消できた場合はspecの未決定事項から削除し、解消できなかった場合は**判明した再現条件を追記して残す**
  （原因未特定のまま放置しない）。

### 6. テスト

- `tests/test_extract_frontmatter.sh` を新設する（`.claude/rules/shell-script-style.md`「テスト」の
  規約どおり、`passed=N failures=N` を出力し失敗時は終了コード1）。対象は副作用の無い純粋ロジック:
  `frontmatter_to_json`（スカラー / フロー配列 `[a, b, c]` / ブロック配列 `- item` / frontmatter無し /
  クォート付き値）と、新設する中間表現→JSON変換。
- specの「影響範囲」は `tests/test_extract_frontmatter.sh` が存在する前提で書かれているが、
  このテンプレートリポジトリには `tests/` ディレクトリ自体が無い。今回あわせて新設し、specの記述と
  実体を一致させる。

## 検証（受け入れ条件との対応）

| issueの受け入れ条件 | 検証方法 |
|---|---|
| ルート（`.`）指定の実行が完了する | `time bash .claude/scripts/src/extract-frontmatter.sh .` を実行し、完走することと所要時間を記録する（キャッシュ無効時／有効時の両方） |
| 強制中断しても既存の `index.jsonl` が保持される | `--force` 付き実行を途中で `Ctrl+C` 相当のシグナルで中断し、`git status` で `index.jsonl` に差分が無いこと・一時ファイルが残っていないことを確認する |
| 生成内容が現行実装と同一（回帰なし） | 作業ツリーをクリーンにしてから `--force` で全再生成し、`git diff -- '*index.jsonl'` が**空**であることを確認する（現在コミット済みの `index.jsonl` 群が現行実装の出力そのもののため、これが最も確実な回帰テストになる） |
| 差分スキップが効く | 1ファイルだけ `touch` して再実行し、そのディレクトリのみ再生成されること・所要時間が短いことを確認する |
| 単体テスト | `bash tests/test_extract_frontmatter.sh` が `failures=0` で終了する |
| 構文チェック | 変更した `.sh` に対し `bash -n` を実行する |

## フェーズ4（反映）で行うこと

- **設計反映**: [.claude/docs/spec/extract-frontmatter.md](../.claude/docs/spec/extract-frontmatter.md)
  を更新する（`--force` オプション、mtimeキャッシュとその無効化条件、原子的更新、性能の実測値、
  「影響範囲」へのissue #11 changelogエントリ追記、未決定事項の更新）。
- **DDR新設**: 「frontmatter抽出の高速化は1ファイル1回のjq呼び出しとmtimeキャッシュで行う」。
  却下案として「`yq` を必須依存にする」「全ファイルを1回のjqで処理する（解析ロジックをjq側へ移植する
  ことになり回帰リスクが大きい）」「純bashでJSONエスケープしjqを完全に排除する（エスケープの
  正しさを自前で保証する必要がある）」を記録する。
- **AIアセット反映**: `.claude/rules/shell-script-style.md` に、**git bashでの外部プロセス起動が
  約95ms/回と重く、ループ内で `jq` 等を繰り返し呼ぶ実装は避ける**（実測値つき）というルールを追記する。
  `.claude/rules/markdown-frontmatter.md` の再生成手順に `--force` の使いどころを追記する。

## スコープ外

- `index.jsonl` の自動再生成（git hook等）の導入。specの未決定事項に残っているが、issue #11の
  受け入れ条件に含まれないため今回は扱わない。
- `yq` 優先パスの実機検証（開発機に `yq` が無い状態は変わらない）。
- `index.jsonl` のスキーマ変更。回帰なしが受け入れ条件のため、出力フォーマットは一切変更しない。
