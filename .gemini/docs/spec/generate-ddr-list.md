---
title: DDR一覧生成スクリプト（generate-ddr-list.sh）
type: spec
description: .claude/docs/README.md のDDR一覧をDDRのfrontmatterから生成し、マーカー区間を置き換えるスクリプトの仕様
resource: .claude/scripts/src/generate-ddr-list.sh
tags: [ddr, docs, script, generation]
keywords: [generate-ddr-list, マーカー, note, superseded, awk, --check, --print, コンフリクト, 冪等, index.jsonl]
---

# DDR一覧生成スクリプト（generate-ddr-list.sh）

実体: `.claude/scripts/src/generate-ddr-list.sh` ／ 単体テスト:
`.claude/scripts/test/test_generate_ddr_list.sh` ／ issue #135

## 背景・目的

`.claude/docs/README.md` のDDR一覧は、DDRを追加するたびに手書きで1行足す運用だった。
一覧はファイル末尾への追記構造のため、**2ブランチが同時にDDRを追加すると毎回テキスト
コンフリクトする**（`resolve-conflict` の類型C）。解消はAIが一覧全体を読み直して両方の行を残し
番号順へ並べ直す手作業になり、そのつど出力トークンを消費していた。

一覧の内容はDDRのfrontmatterから機械生成できるため、生成物にすることで

- 追加時の手書き更新が不要になる
- コンフリクトは「片側を捨てて再生成」で終わる（類型B相当。`resolve-conflict` スキル参照）
- 上記2つに費やしていた出力トークンが減る

**生成結果はGit管理下に置きコミットする**（`index.jsonl` と異なり `.gitignore` に加えない）。
理由と却下案は
[.claude/docs/ddr/i0135-01-DDR一覧は生成物にしつつGit管理下へ残す.md](../ddr/i0135-01-DDR一覧は生成物にしつつGit管理下へ残す.md)。

## 仕様

```
generate-ddr-list.sh [--check] [--print] [--ddr-dir <パス>] [--readme <パス>]
                     [--link-prefix <文字列>] [-h|--help]
```

| オプション | 動作 |
|---|---|
| （なし） | `--readme` のマーカー区間を生成結果で置き換える。内容が同じなら書き込まない |
| `--check` | 書き換えず、再生成で差分が出るかだけを判定する |
| `--print` | 書き換えず、生成した一覧そのものをstdoutへ出す（JSONは出さない） |
| `--ddr-dir <パス>` | DDRディレクトリ。既定は `.mrworkflow.json` の `ddrDirs[0]` |
| `--readme <パス>` | 書き換え対象。既定は `<ddr-dirの親>/README.md` |
| `--link-prefix <文字列>` | リンクURLの接頭辞。既定はreadmeからddr-dirへの相対パス＋`/` |

`--check` と `--print` の同時指定はエラー。

**`--ddr-dir` / `--readme` に渡す相対パスは、カレントディレクトリではなくリポジトリルート基準**で
解決する（スクリプトは冒頭で `git rev-parse --show-toplevel` へ `cd` する）。サブディレクトリから
オプション無しで実行した場合に既定値が正しく効くようにするためで、オプションを渡すときは
リポジトリルートからのパスを書く。

### 終了コード

| コード | 意味 |
|---|---|
| 0 | 成功（既定・`--print`）／`--check` で差分が無かった |
| 1 | 失敗（引数不正・マーカー不在・DDRが1件も無い・相対パスを決められない等） |
| 2 | `--check` で差分があった |

**「再生成が必要」を1ではなく2で表す**のは、呼び出し側が「スクリプトが壊れている」と
「一覧が古い」を区別できるようにするため（`check-base-conflicts.sh` が
「コンフリクトの有無」を終了コードで表さないのとは逆に、ここは判定結果を終了コードで返す
ほうが `--check` の使い勝手がよい）。

### 出力

既定・`--check` ではstdoutへJSONを1つ出す（`cleanup-task.sh` と同じ規約）。人間向けの
進捗ログはstderr。

```json
{"check":false,"print":false,"repoRoot":"/…","ddrDir":".claude/docs/ddr",
 "readme":".claude/docs/README.md","linkPrefix":"ddr/","count":55,
 "changed":true,"written":true}
```

### マーカー

READMEの次の2行に囲まれた区間**だけ**を置き換える。マーカー行自体は書き換えない。

```
<!-- BEGIN GENERATED: ddr-list -->
<!-- END GENERATED: ddr-list -->
```

**マーカーが片方でも無ければエラーで停止し、区間を推測しない。** 見出しの位置や前後の地の文が
変わったときに、一覧と無関係な行を巻き込んで消さないため。開始マーカーは最初の1つ、終了
マーカーは**開始マーカーより後**の最初の1つを使う。

### 対象ファイルと並び順

- `ddr-dir` 直下の `*.md` すべて（サブディレクトリは見ない）。
- **並び順はファイル名の昇順**（`LC_ALL=C` でロケール非依存にする）。DDRの識別子
  `i<issue番号4桁ゼロ埋め>-<枝番2桁>` ではこれが数値順と一致する
  （`.claude/rules/markdown-frontmatter.md`「DDRの識別子」）。
  **issue番号をゼロ埋めするのは、まさにこの一致のためである**（issue #133 は当初ゼロ埋めしない
  方式で決着していたが、本スクリプトのglob順と噛み合わないため、issue #135 の取り込み時に
  ゼロ埋めへ変更した。経緯: DDR i0133-01「issue番号をゼロ埋めへ変えた経緯」）。
  そのため**本スクリプト側には並べ替えのロジックを持たせていない**。
- issue番号が9999を超えて5桁になっても順序は保たれる（桁数が増える側が辞書順で必ず後ろに来る）。
- 列挙に `git ls-files` を使わず glob を使うのは、**まだコミットしていない新しいDDR**も一覧へ
  載せるため（DDRを追加した直後にこのスクリプトを実行し、一覧の差分ごとコミットする運用のため）。
- `index.jsonl`（Git管理外の生成物）は `*.md` に一致しないため自然に除外される。

### 生成する行

```
- [<ファイル名>](<link-prefix><ファイル名>)<注記>
```

`<注記>` は次を**この順**で連結する（無ければ何も付けない）。順序を固定するのは、片方を後から
足したときに一覧全体が差分にならないようにするため。

| frontmatter | 出力される注記 |
|---|---|
| `status: superseded` + `superseded_by: "NNNN"` | <code> ── **\`status: superseded\`（NNNNにより置き換え）**</code> |
| `status: superseded`（`superseded_by` 無し） | <code> ── **\`status: superseded\`**</code> |
| `status: deprecated` | <code> ── **\`status: deprecated\`**</code> |
| `status` が未知の値 | <code> ── **\`status: <値>\`**</code>（黙って捨てない） |
| `note: <散文>` | `（<散文>）` |

`status` が無い／`active` のときは注記を出さない（`.claude/rules/markdown-frontmatter.md`
「DDRのstatus」と対応する）。

### リンク先の表記

ファイル名に**空白または括弧**が含まれる場合だけ、リンク先を `<...>` で囲む。

CommonMark（GitHubのcmark-gfm）は、`<>` で囲まない限りリンク先に空白を含められない。囲まないと
リンクとして解釈されず**地の文としてそのまま表示される**（実測確認済み）。実際に
`0009-Planモードre-entry時はgit checkout復元でなくarchiveスクリプトで対処する.md` は
「git checkout」の空白を含んでおり、**issue #135 以前のREADMEではリンクになっていなかった**。
生成へ移した結果、この1行だけは以前の手書き内容と異なる（壊れていたリンクが直る方向の差分）。

### frontmatterの読み取り

YAMLパーサではなく、`status` / `superseded_by` / `note` の3キーだけを行単位で拾う。扱いは次のとおり
（いずれも issue #135 の敵対的レビューで実機確認し、単体テストに回帰として入れてある）。

| 入力 | 扱い |
|---|---|
| `status: superseded   `（末尾に空白） | 末尾空白を落として `superseded` として扱う |
| `superseded_by: "0019"  # 理由`（行内コメント） | クォート済みなら閉じクォートまでを値とし、以降を捨てる |
| `status: superseded # 理由`（クォート無し＋コメント） | 空白に続く `#` 以降を捨てる |
| `note: 'issue #97 を参照'`（クォート内の `#`） | **コメントとして削らない**（本文として残す） |
| 先頭に UTF-8 BOM | BOMを落としてから `---` を判定する |
| `note: \|` / `note: >`（複数行スカラー） | **読まない**（空として扱う。インジケータ文字を出力しない） |
| frontmatterが無い／1行目が `---` でない | 注記なしの行にし、**件数をstderrへ警告として出す** |

**扱わない**もの（必要になったら対応を検討する）:

- ダブルクォート内のエスケープ（`"a\"b"`）。閉じクォートの判定を最初の `"` で行うため値が切れる。
- アンカー・エイリアス・複数行のフロースタイル。
- **1ファイルも読めなかった場合**（0バイトのファイル等でawkがレコードを出さない場合）は、
  件数が合わないこととして**エラーで停止し、読めなかったファイル名を出す**。READMEは変更しない。

### 散文の注記（`note`）

`status` から導けない補足は、DDRのfrontmatterへ `note` キーとして持たせる
（`.claude/rules/markdown-frontmatter.md`「キー定義」）。**DDRの本文は変更せずfrontmatterのみを
更新する**運用の範囲に収まる。

- 値は**1行**で書く。複数行のYAMLスカラー（`note: |` 等）は空として扱われ、注記が出ない。
- 一覧に出したい注記の唯一の置き場がここになる。READMEを直接編集しても次の生成で消える。

### 性能

frontmatterの抽出は**awkの起動1回**で全ファイルを処理する
（`.claude/rules/shell-script-style.md`「外部プロセス起動のコスト」。1ファイル1回の起動にすると
ファイル数に比例して所要時間が伸びる）。行の組み立てもループ内でコマンド置換を使わず、
`$REPLY` へ返すヘルパーだけで行う。

awkからbashへ渡す区切りは**US（0x1f）**であってタブではない。bashの `read` はタブを
**IFS空白文字**として扱い、連続する区切りを1つへ畳んでしまうため、`status` と `superseded_by` が
両方空のDDR（＝大多数）で `note` が `status` の位置へずれ込む（issue #135 の実装中に実際に踏んだ）。

### 書き込み

生成結果が現在の内容と同じなら**書き込まない**（mtimeを無用に動かさない）。書き込む場合は、
`$readme` と同じディレクトリへ作った一時ファイルへ全文を組み立ててから `mv` で置き換える。
リダイレクトで直接上書きすると先にファイルを切り詰めるため、中断・ディスクフルでREADME全体
（spec一覧・由来の注記を含む）が欠けた状態で残りうる。元のパーミッションは引き継ぐ。

## 影響範囲

| ファイル | 変更 |
|---|---|
| `.claude/scripts/src/generate-ddr-list.sh` | 新規 |
| `.claude/scripts/test/test_generate_ddr_list.sh` | 新規 |
| `.claude/docs/README.md` | DDR一覧をマーカーで囲み、生成物である旨の注記を追加。spec一覧に本仕様を追加 |
| `.claude/docs/ddr/0022-…md` / `0048-…md` | READMEにしか無かった散文の注記を frontmatter の `note` へ移動（本文は不変） |
| `.claude/rules/markdown-frontmatter.md` | `note` キーの定義を追加 |
| `.claude/rules/docs-workflow.md` | DDR追加時に一覧を手書きしない旨を追加 |
| `.claude/skills/resolve-conflict/SKILL.md` | DDR一覧のコンフリクトを類型C→類型Bへ移動。「絶対ルール」へ片側採用の例外条件を明記。Step 5 の検証順を「生成物の作り直し→単体テスト」へ入れ替え |
| `.claude/skills/issue-mr-flow/SKILL.md` | flow-id 4-6（設計反映）へ、DDR追加時に一覧を再生成する手順を追加 |

## 設定項目

`.mrworkflow.json` の `ddrDirs[0]` を既定のDDRディレクトリとして読む。複数の `ddrDirs` を
持つリポジトリで2つ目以降を対象にしたい場合は `--ddr-dir` で明示する。

## 未決定事項・懸念点

- **実行はAIエージェントの手動**であり、SessionStart hook等での自動生成は行わない。出力が
  Git管理下にあるため、自動生成にすると無関係な差分が勝手にワーキングツリーへ現れる
  （`index.jsonl` を自動生成にできるのはGit管理外だからである。DDR 0025との違い）。
  実行の入口は3か所に置いてある（`.claude/skills/issue-mr-flow/SKILL.md` の flow-id 4-6、
  `.claude/rules/docs-workflow.md` のDDR行、`.claude/skills/resolve-conflict/SKILL.md` の
  Step 5 検証手順）が、いずれもAIエージェントが読んで従う前提であり、**機構として強制する仕組み
  （CI・pre-commit hook）は無い**。実行忘れは `--check`（終了コード2）で検出できる。
  必要になったらSessionStart hookでの `--check` 警告や、pre-commit相当の呼び出しを検討する。
- spec一覧（README上部）は本スクリプトの対象外。README側の短い説明文が frontmatter の
  `description`（長文）と一致しないため、同じ方法では生成できない（issue #135 のスコープ外）。
