---
title: DDR一覧生成スクリプトの実装結果
type: report
description: issue #135 で .claude/docs/README.md のDDR一覧を生成スクリプト化した結果と、実装中に判明した2件の不具合・1件の既存不具合の記録
tags: [ddr, docs, script, report]
keywords: [generate-ddr-list, マーカー, note, IFS, タブ, CommonMark, 空白, リンク, 冪等, 単体テスト]
---

# DDR一覧生成スクリプトの実装結果（issue #135）

全体作業計画: `plans/ddr-list-generation.md` ／
個別作業計画: `plans/【設計】【実装】【テスト】DDR一覧生成スクリプト.md`

## 結論

DDR一覧の生成スクリプト化を完了した。issue #135 の受け入れ条件7項目をすべて満たしている。

| 受け入れ条件 | 状態 | 根拠 |
|---|---|---|
| 実行すると現在の一覧と等価な内容が生成される | ✅（1行を除き完全一致） | 下記「等価性の検証」 |
| 生成結果がGit管理下に残っている | ✅ | `.gitignore` へ追加していない。`git status` で追跡対象 |
| 一覧を手書きしない旨が `docs-workflow.md` に明記 | ✅ | 同ファイルのDDR行 |
| `resolve-conflict` に再生成で解消してよい旨を記載 | ✅ | 類型Bへ移動（類型Cから除外） |
| 単体テストが `passed=N failures=0` で通る | ✅ | `passed=48 failures=0` |
| 仕様が `spec/` にあり README のspec一覧に載っている | ✅ | `spec/generate-ddr-list.md` |
| 採用理由と却下案を記録したDDR | ✅ | `ddr/0061-…md`（却下案6件を表で記載） |

## 成果物

| ファイル | 内容 |
|---|---|
| `.claude/scripts/src/generate-ddr-list.sh` | 新規。生成本体 |
| `.claude/scripts/test/test_generate_ddr_list.sh` | 新規。単体テスト48件 |
| `.claude/docs/spec/generate-ddr-list.md` | 新規。仕様 |
| `.claude/docs/ddr/0061-DDR一覧は生成物にしつつGit管理下へ残す.md` | 新規。意思決定 |
| `.claude/docs/README.md` | 一覧をマーカーで囲み、生成物である旨を明記。spec一覧へ追加 |
| `.claude/docs/ddr/0022-…md` / `0048-…md` | 散文の注記を frontmatter の `note` へ移動（**本文は不変**） |
| `.claude/rules/markdown-frontmatter.md` | `note` キーの定義・「DDRのnote」節を追加。古い記述を1件修正 |
| `.claude/rules/docs-workflow.md` | DDR追加時に一覧を手書きしない旨を追加 |
| `.claude/skills/resolve-conflict/SKILL.md` | DDR一覧を類型C→類型Bへ移動。検証手順に `--check` を追加 |

## 設計上の決定（issueの「設計フェーズで決めること」への回答）

| 論点 | 採用 | 理由の要点 |
|---|---|---|
| 生成先 | README内のマーカー区間の置換 | 別ファイル分離は目次を開く手数が増え、目次として後退する |
| 実行方法 | AIの明示的な実行（`--check` で検証可能） | 出力がGit管理下にあるため、hookでの自動生成は意図しない差分を常時生む |
| 散文注記の置き場 | DDRのfrontmatterへ `note` キーを新設 | サイドカーは同期の手間とコンフリクトが戻る。捨てるのは情報欠落 |

却下案の詳細は DDR 0061 の表を参照。

## 等価性の検証

生成前の一覧（55行）を退避し、`--print` の出力と `diff` した。

- **54行は完全一致**（バイト単位）。
- **1行だけ差分が出た**（0009）。これは後述の既存不具合の修正であり、退行ではない。

その後 `--check` が終了コード0を返すこと（＝コミット済みの内容と生成結果が一致すること）を
単体テストにも組み込んだ。DDR 0061 を追加したあと再実行したところ、**56件へ自動で増えた**
（手書き更新が不要になったことの実地確認）。

## issueの前提との相違

**issueは「唯一の注記は0009の `status: superseded`」としていたが、実際には frontmatter から
導けない散文の注記が2件あった**（0022・0048）。この2件はREADMEにしか存在しない情報で、
素直に生成へ移すと消える。frontmatter へ `note` キーを新設して受け皿にした
（DDRは本文不変・frontmatterは更新可という既存運用に収まる）。

## 実装中に踏んだ不具合（すべて修正済み）

### 1. タブ区切りにしたため `note` が `status` の位置へずれ込んだ

awkからbashへ `<名前>\t<status>\t<superseded_by>\t<note>` の形で渡していたが、**bashの `read` は
タブをIFS空白文字として扱い、連続する区切りを1つへ畳む**。`status` と `superseded_by` が両方空の
DDR（＝大多数）で、`note` が `status` の位置へ入り込んだ。

```
$ printf 'A\t\t\tD\n' | { IFS=$'\t' read -r a b c d; echo "[$a][$b][$c][$d]"; }
[A][D][][]          ← 空フィールドが消えている
$ printf 'A\x1f\x1f\x1fD\n' | { IFS=$'\x1f' read -r a b c d; echo "[$a][$b][$c][$d]"; }
[A][][][D]          ← US(0x1f)はIFS空白文字ではないので保たれる
```

US（0x1f）区切りへ変更して解決した。**この不具合は、一覧の3行が
「`── **`status: <注記の全文>`**`」という壊れた形で出る**という分かりやすい形で表面化したが、
表面化したのは注記を持つDDRが実在したからである。注記が1件も無ければ気づけなかった。

### 2. `--check` の終了コードを1にしていた

「一覧が古い」と「スクリプトが壊れている」を呼び出し側が区別できないため、`--check` の差分ありを
**終了コード2**へ分けた（1は引数不正・マーカー不在等の失敗のまま）。

## 既存の不具合の発見（0009のリンクが壊れていた）

`0009-Planモードre-entry時はgit checkout復元でなくarchiveスクリプトで対処する.md` は
ファイル名に **「git checkout」の半角空白**を含む。CommonMark（GitHubのcmark-gfm）は
`<>` で囲まない限りリンク先に空白を含められないため、**手書き時代のこの行はリンクとして
解釈されず、地の文として表示されていた**。

```
$ python3 -c "import commonmark; print(commonmark.commonmark('[t](ddr/0009-a git checkout b.md)'))"
<p>[t](ddr/0009-a git checkout b.md)</p>              ← リンクになっていない

$ python3 -c "import commonmark; print(commonmark.commonmark('[t](<ddr/0009-a git checkout b.md>)'))"
<p><a href="ddr/0009-a%20git%20checkout%20b.md">t</a></p>   ← 正しくリンクになる
```

生成側で「空白または括弧を含む場合だけ `<>` で囲む」ようにした。このため**この1行だけは
手書き時代と内容が異なる**（壊れていたリンクが直る方向の差分）。等価性を厳密に優先するなら
`<>` を付けない選択もあり得たが、壊れたままの出力を機構として固定するほうが害が大きいと判断した。

## 未確認・申し送り

- **`0048` の `note` が参照するDDR番号「0056」は、内容から見て「0058」の誤りの可能性が高い**
  （フェーズ5の並べ替えを決めたのは 0058）。issue #135 の受け入れ条件が「既存の注記を含めて等価」
  であるため、**移設時に文言を変更していない**。修正する場合は `0048-…md` の `note` を書き換えて
  再生成する（1行の変更で済む）。
- 実行忘れの検出手段（`--check`）はあるが、**CIから自動で呼ぶ仕組みは入れていない**。
  必要になればSessionStart hookでの警告等を検討する（spec の「未決定事項」）。
- 本作業は非対話的セッションで進めたため、**人間によるレビュー往復（flow-id 3-3/3-8 等）は
  実施していない**。

## 検証結果

| 検証 | 結果 |
|---|---|
| `bash -n`（新規2ファイル） | OK |
| `test_generate_ddr_list.sh` | `passed=48 failures=0` |
| 既存の単体テスト12本 | すべて `failures=0`（`note` キー追加による退行なし） |
| `generate-ddr-list.sh --check` | 終了コード0 |
| 冪等性（2回連続実行） | 2回目は `changed=false` |
| 異常系（マーカー不在・DDR 0件・オプション併用） | いずれも終了コード1でREADMEを変更しない |
