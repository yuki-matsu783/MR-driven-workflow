---
title: 【設計反映】【AIアセット反映】extract-frontmatter高速化と中断耐性
type: plan
description: issue #11の実装結果をspec・DDR・rules・SKILLへ反映するフェーズ4の個別反映計画
tags: [extract-frontmatter, 設計反映, ai-asset]
keywords: [extract-frontmatter, index.jsonl, spec, ddr, shell-script-style, markdown-frontmatter, issue-mr-flow, flow-id 5-1, プロセス起動, mtimeキャッシュ]
---

# 個別反映計画: 【設計反映】【AIアセット反映】extract-frontmatter高速化と中断耐性

全体作業計画: [lexical-stirring-peach.md](lexical-stirring-peach.md)
前フェーズの個別作業計画: [【設計】【実装】【テスト】extract-frontmatter高速化と中断耐性.md](【設計】【実装】【テスト】extract-frontmatter高速化と中断耐性.md)
反映元: `worklog/20260818_lexical-stirring-peach_…_push1〜3.md`

種別を併記する理由: 設計反映（spec・DDR）とAIアセット反映（rules・SKILL）はいずれも
**同じ実装結果から導かれるドキュメント更新**であり、フェーズを分けても合意の単位が変わらず記述が
重複するだけのため、1ファイルにまとめて1回で合意を取る
（`.claude/skills/issue-mr-flow/SKILL.md`「種別を複数併記する場合／分ける場合」）。

## 反映元となる確定事項

| # | 確定事項 | 出典 |
|---|---|---|
| A | git bash（MSYS）の外部プロセス起動は**約95ms/回**。ループ内の `jq` 起動が性能を支配していた | 全体作業計画・worklog push2 |
| B | **コマンド置換 `$(...)` もサブシェルをforkする**ため、ホットパスでは同じコストを持つ | worklog push2（9.7秒 → 3.0秒の要因） |
| C | jq起動を**1ファイル1回**へ集約し、mtimeキャッシュ＋原子的更新を導入した | 実装 |
| D | 性能: ルート 136秒 →**9.6〜11.8秒**（全再生成）/**1.5〜2.4秒**（差分なし）。ddr単体 46.4秒 → 3.0秒 | worklog push2 |
| E | 回帰なし（ゴールデン比較で15ファイルすべてバイト一致）。中断耐性を実機確認 | worklog push2 |
| F | specの既知バグ「スコープ外の `index.jsonl` に影響・重複行」は**改修前後とも再現せず**。正体は mtime のブランチ操作による更新と陳腐化エントリの除去の誤認と考えられる | worklog push2 |
| G | 一時ファイル（`plans/` `worklog/`）も**jsonl作成の対象に含める**。`.gitignore` 対象は列挙自体が発生しない（実機確認済み） | レビュー合意・worklog push3 |
| H | flow-id 5-1 で **`plans/index.jsonl` も削除**し、`index.jsonl` 群を再生成してからcommitする | レビュー合意・worklog push3 |
| I | `index.jsonl` をコミット対象にしている以上、**commit直前に `extract-frontmatter.sh .` を1回流す**運用が要る（`HANDOFF.md`・worklog を編集するたびに mtime 経由で `index.jsonl` が陳腐化するため） | 今回のセッションで実際に「HANDOFF更新 → index再生成 → 追加コミット」が発生 |

## 1. 設計反映

### 1-1. `.claude/docs/spec/extract-frontmatter.md` を更新する

現在の状態を説明する節（「仕様」以下）のみを更新し、**過去issueごとのchangelog（「影響範囲」の
issue #24 / issue #54 のエントリ）は書き換えない**（`.claude/rules/docs-workflow.md`
「ファイル移動に伴うパス参照の一括置換は…point-in-timeの記録を対象に含めない」）。issue #11 の
記録は**新規エントリの追記**として残す。

| 節 | 変更内容 |
|---|---|
| 実行方法 | `[--force] <directory>` の書式・`--force` / `-f` の意味・`files=N built=N reused=N` の標準エラー出力を追記 |
| 出力単位 | 「既存があれば上書き」を、**「全走査完了後に一時ファイルへ書き `mv -f` で差し替える。内容が既存と同一なら書き換えず `unchanged:` を出力する」**へ更新 |
| **（新設）差分スキップ（mtimeキャッシュ）** | 既存 `index.jsonl` から `concept_id` → 行 / mtime を読み、mtimeが一致する行を再利用する。**スクリプト自身のmtimeが `index.jsonl` より新しい場合は自動的にキャッシュを捨てる**（解析ロジックを変えたのに古い行が残る事故の防止）。`unchanged` のファイルにも `touch` でmtimeを付け直す理由（付け直さないと自動無効化条件が永久に成立し続ける。確定事項Dの実測を裏付ける実バグ）も明記する |
| **（新設）原子的更新と中断耐性** | `index.jsonl.tmp.$$` → `mv -f`、`trap ... EXIT INT TERM` による一時ファイル削除。issue #9 で発生した「中断で18行→14行に破損」の再発防止であることを明記 |
| **（新設）性能** | 確定事項A・Dの実測値を表で記載。「支配要因はアルゴリズムではなくプロセス起動回数」であること |
| frontmatterのYAML→JSON変換 | 自前パーサーが**キーごとにjqを呼ぶ実装から、中間表現（`種別 キー 値` の3要素組）を `jq --args` へ1回だけ渡す実装**へ変わったことを追記。引数長上限（実測32KB程度）に達しうる場合は一時ファイル＋`--rawfile` へフォールバックすることも記載 |
| 走査方式 | 確定事項Gを追記（`plans/` `worklog/` のような一時ディレクトリも対象に含む。`.gitignore` 対象は `--exclude-standard` により列挙自体が発生しない） |
| 影響範囲 | **issue #11 のchangelogエントリを新規追記**（`.claude/scripts/src/extract-frontmatter.sh` 改修、`tests/test_extract_frontmatter.sh` 新規、新設DDR、`plans/index.jsonl` 等の追加） |
| 未決定事項・懸念点 | 「スコープ外への影響・重複行」を**確定事項Fの結論へ書き換える**（再現せず・原因の推定・改修後は起きにくい理由。原因未特定のまま放置しない）。あわせて確定事項Iを**新しい懸念点として追加**する |

あわせて次の**既存の記述の誤り**を修正する（いずれも現在の状態を説明する節のため対象）。

- 未決定事項の `.claude/scripts/docs/spec/shell-scripts.md` → **実体は `.claude/docs/spec/shell-scripts.md`**（存在しないパスを参照している）。
- 「frontmatterのYAML→JSON変換」「リポジトリルートの解決」節が参照する
  `../ddr/0008-frontmatter抽出スクリプトの設計判断.md` は**このリポジトリに存在しない**
  （移植元から持ち込まれていないDDR番号）。リンクを外し、参照先を新設DDR（下記1-2）へ差し替える。

### 1-2. DDRを新設する: `0021-frontmatter抽出は1ファイル1回のjq呼び出しとmtimeキャッシュで高速化する.md`

番号は既存の最大 `0020` の次を採る。内容は「採用した決定＋却下案」。

- **採用**: 解析結果を中間表現へ溜め、`jq --args` へ**1ファイル1回**だけ渡す。加えて mtime キャッシュ
  による差分スキップと、一時ファイル＋`mv -f` による原子的更新を組み合わせる。
- **却下案1: `yq` を必須依存にする** — フル YAML 文法に対応でき実装も単純になるが、
  `0008`（移植元）以来の「`yq` を新規の必須外部依存にしない」方針を覆すことになり、
  クローン直後に動かない環境が生まれる。プロセス起動回数の問題も1回/ファイルまでしか減らない。
- **却下案2: 全ファイルを1回のjq呼び出しで処理する** — 起動回数は理論上最小になるが、
  frontmatter の行解析ロジックごと jq 側へ移植する必要があり、**回帰なし**という受け入れ条件に対して
  リスクが大きすぎる。今回の1ファイル1回で既に十分な水準（ルート約10秒／差分なし約2秒）に達している。
- **却下案3: 純bashでJSONエスケープし jq を完全に排除する** — 起動回数を0にできるが、
  制御文字・サロゲートペア等を含む正しいエスケープを自前で保証する必要があり、
  「生成内容が現行実装と同一」の担保が難しくなる。
- **併記する背景**: 確定事項A・B（95ms/回、コマンド置換もfork）の実測値。

## 2. AIアセット反映

### 2-1. `.claude/rules/shell-script-style.md`

新規節「**外部プロセス起動のコスト**」を追加する（既存の「JSON操作」節の直後を想定）。

- git bash（MSYS）の外部プロセス起動は**約95ms/回**（実測: `jq -nc '1'` × 50回 = 4.73秒）。
  **ループ内で `jq` / `stat` / `date` / `dirname` 等を繰り返し呼ぶ実装にしない。**
- **コマンド置換 `$(...)`・パイプもサブシェルをforkするため同じコストを持つ**。
  ホットパスの小さなヘルパー関数は、標準出力へ返さず**グローバル変数 `REPLY` へ返す**形にする
  （実例: `extract-frontmatter.sh` の `trim_unquote_to_reply` / `unquote_to_reply`）。
- bash組み込みで代替できる典型例の表: `date -d @epoch` → `printf '%(%Y-%m-%dT%H:%M:%S)T'`、
  `dirname` → `${path%/*}`、`cat file` → `$(<file)`、`tr -d '\r'` → `${var//$'\r'/}`、
  `stat` の個別呼び出し → `xargs -0 stat` による一括取得。
- **`REPLY` へ返す関数はパイプではなくヒアストリング（`func <<<"$s"`）で呼ぶ**。パイプの右辺は
  サブシェルになるため、グローバル変数への代入が呼び出し元へ伝わらない（実装時に実際に踏んだ）。
- 実測値の出典として issue #11 と `.claude/docs/spec/extract-frontmatter.md` を挙げる
  （`plans/` `worklog/` は参照しない。`.claude/rules/docs-workflow.md` の
  「コード・スクリプト内のコメントから plans/worklog/reports を参照しない」に準じる）。

### 2-2. `.claude/rules/markdown-frontmatter.md`

末尾の再生成手順（`extract-frontmatter.sh <ディレクトリ>` を案内している箇所）に、次を追記する。

- 通常は**リポジトリルートで `bash .claude/scripts/src/extract-frontmatter.sh .`** を実行すればよい
  （差分が無ければ数秒で終わる）。
- **解析ロジックを変えたわけではないのに全再生成したい場合のみ `--force`** を使う
  （スクリプト自身を変更した場合は自動でキャッシュが無効化されるため、通常は不要）。
- 確定事項I: `index.jsonl` はGit管理下にあるため、**commit直前に1回流す**とレビュー時に
  「index.jsonl だけを直す追加コミット」が発生しない。

### 2-3. `.claude/skills/issue-mr-flow/SKILL.md`（確定事項H）

flow-id 5-1 の記述を更新する。

> 現行: 次タスクのために、`plans/` `worklog/` `reports/` を削除し、`HANDOFF.md` をリセットする

に、**「`plans/index.jsonl` も削除し、`bash .claude/scripts/src/extract-frontmatter.sh .` で
`index.jsonl` 群を再生成してから 5-2 のcommitに含める」**を加える。

理由（本文にも簡潔に書く）: 本スクリプトは「markdownが直下に存在するディレクトリ」だけを出力対象に
するため、`plans/*.md` を全削除すると `plans/index.jsonl` は再生成の対象から外れ、削除済みplanを
指したまま残る。`worklog/` は `TEMPLATE.md` が残るため再生成すれば正しい状態になる。

**スクリプト側で「markdownが無くなったディレクトリの `index.jsonl` を自動削除する」挙動は入れない**
（スコープ外のファイルを消しうるため、フロー手順側で担保する）。この判断も1-2のDDRに1行残す。

### 2-4. `.claude/rules/docs-workflow.md`（確定事項H）

「ドキュメント運用」表の `plans/` 行の運用欄に、flow-id 5-1 で `plans/index.jsonl` も削除する旨を
1行追記する（手順そのものはSKILL.md側に置き、ここは置き場所・ライフサイクルの参照表としての追記に
とどめる）。

## 3. worklog

`worklog/20260818_lexical-stirring-peach_【設計反映】【AIアセット反映】extract-frontmatter高速化と中断耐性_push4.md`
を新規作成し、反映作業の経過を記録する（push4）。

## 検証

| 項目 | 方法 |
|---|---|
| frontmatterの妥当性 | 新設DDR・更新した各mdに規約どおりの frontmatter があること（`.claude/rules/markdown-frontmatter.md`） |
| `index.jsonl` の再生成 | `bash .claude/scripts/src/extract-frontmatter.sh .` を実行し、新設DDRが `.claude/docs/ddr/index.jsonl` に載ること・完走時間が想定内（数秒）であること |
| リンク切れ | 本反映で追加・修正した相対リンクの参照先が実在すること（`0008` への切れたリンクの解消を含む） |
| 過去changelogの不変 | `git diff` で、`spec` の issue #24 / #54 エントリと既存DDR本文が**変更されていない**ことを確認する |
| 既存テスト | `bash tests/test_extract_frontmatter.sh` が `failures=0`（ドキュメント変更のみだが退行がないことの確認） |

## やらないこと

- **スクリプト（`.claude/scripts/src/extract-frontmatter.sh`）の変更**。フェーズ3で合意済みの実装を
  ドキュメントへ反映するフェーズであり、コード変更は行わない（確定事項Gのとおり、レビュー指摘は
  現行実装のままで満たされている）。
- **`index.jsonl` の自動再生成（git hook等）の導入**。specの未決定事項に残るが issue #11 の
  受け入れ条件外（全体作業計画のスコープ外に明記済み）。確定事項Iは**懸念点としてspecに書くのみ**とし、
  自動化の実装は行わない。
- **issue #20（HANDOFF更新の自動化・`[-]` 記号の明文化）**。別issue・別ブランチで対応する。
  進捗表の `[-]` は今回 `HANDOFF.md` 内の凡例行で説明するにとどめ、`.claude/rules/docs-workflow.md`
  への記号規約追記は issue #20 で行う。
- **`yq` 優先パスの実機検証**（開発機に `yq` が無い状況は変わらないため、specの未決定事項に残す）。
