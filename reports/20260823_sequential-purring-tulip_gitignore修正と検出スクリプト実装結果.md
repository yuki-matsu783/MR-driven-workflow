---
title: .gitignoreのDDR参照修正と検出スクリプト実装結果
type: report
description: issue #171フェーズ3で.gitignoreのDDR参照切れ2箇所を修正し、検出スクリプトcheck-doc-references.shと単体テストを実装した結果
tags: [gitignore, ddr, doc-references, issue-171]
keywords: [check-doc-references, 検出スクリプト, 単体テスト, 貪欲マッチ, コードフェンス除外, 実機確認]
---

# .gitignoreのDDR参照修正と検出スクリプト実装結果（issue #171 フェーズ3）

## サマリ（結論の一覧）

1. `.gitignore`の28行目・40行目のDDR参照切れを実在ファイル名へ修正した。修正後、参照側から
   検索した参照切れは**0件**。
2. 検出スクリプト`.claude/scripts/src/check-doc-references.sh`を新規実装した。個別作業計画
   （v2、敵対的レビュー対応済み）の設計どおり、bash単独方式（外部コマンドは`git ls-files`の
   1回のみ）・実際のタブ文字・issue番号／枝番とも桁数不問の正規表現・3ディレクトリ除外
   （`.claude/scripts/test/` `plans/` `reports/` `worklog/`）・省略記法除外・貪欲マッチによる
   終端規則・コードフェンス除外（未閉鎖時は安全側で除外しない）を実装した。
3. リポジトリ全体（走査ファイル数150、除外ディレクトリ配下25）に対して実行し、候補121件
   （省略記法による除外3件）のうち**参照切れ0件**を確認した。
4. 単体テスト`.claude/scripts/test/test_check_doc_references.sh`を実装し、5つの純粋関数を
   対象に28ケース全件成功した。

## 実施条件（測った対象・環境）

- 対象コミット: このworklog作成時点のワーキングツリー（ブランチ
  `claude/gitignore-ddr-references-rsjo83`、直前コミット`4c3f861`）。
- 実行環境: Linux 6.18.44、bash 5.2.21、grep 3.11、`LANG`未設定（`reports/
  20260823_sequential-purring-tulip_DDR参照切れの網羅調査結果.md`の「実施条件」と同一環境）。
- git bash（MSYS/Windows）実機での再検証は行っていない（個別作業計画「やらないこと」で
  理由付きで見送りと決定済み）。

## 実施した内容と結果

### 1. .gitignoreの修正

| 行 | 修正前 | 修正後 |
|---|---|---|
| 28行目 | `i00-13-gemini配下は…md` | `i0000-13-gemini配下は…md` |
| 40行目 | `i36-01-frontmatterのindex.jsonlを…md` | `i0036-01-frontmatterのindex.jsonlを…md` |

検証（計画の検証1、タブは実際のタブ文字を変数経由で使用）:

```bash
tab=$'\t'
grep -noE "\.claude/docs/ddr/i[0-9]+-[0-9]+-[^]) \"'\`($tab]*\.md" .gitignore \
  | while IFS=: read -r lineno path; do [[ -f "$path" ]] || echo "$lineno:$path"; done
```

修正前は28行目・40行目の2件が出力され、修正後は**出力0件**（終了コードで確認済み）。

### 2. 検出スクリプトの実装

`.claude/scripts/src/check-doc-references.sh`を新規作成した。個別作業計画からの変更点は
実装過程で1件見つかった（下記「想定と異なった点」）以外は計画どおり。

構成する純粋関数（テストから直接呼べる）:

- `is_excluded_target_path`: `.claude/scripts/test/` `plans/` `reports/` `worklog/`配下の判定
- `is_placeholder_candidate`: 省略記法（`...`/`…`）を含むかの判定
- `is_fence_delimiter_line`: 行がコードフェンス区切り（`` ``` ``/`~~~`、インデント可）かの判定
- `strip_fenced_lines_to_reply`: 複数行テキストからフェンス内の行を除いたテキストを返す。
  未閉鎖（奇数回トグル）なら除外せず入力をそのまま返す（安全側）
- `extract_ddr_candidates_to_reply`: 1行からDDRパス候補を貪欲マッチですべて抽出する

`main`は`if [ "${BASH_SOURCE[0]}" = "${0}" ]; then main; fi`でガードし、単体テストからの
`source`時に実行されないようにした。

検証（計画の検証2・3）:

```bash
bash -n .claude/scripts/src/check-doc-references.sh   # 構文OK
bash .claude/scripts/src/check-doc-references.sh
```

実行結果（標準エラーのサマリ）:

```
走査ファイル数=150（除外ディレクトリ配下=25）
候補数=121（省略記法による除外=3）
フェンス未閉鎖ファイル数=2（安全側のため除外なし）
参照切れ数=0
```

終了コードは0（`missing -eq 0`のとき成功）。

### 3. 単体テストの実装

`.claude/scripts/test/test_check_doc_references.sh`を新規作成した。個別作業計画のケース
一覧（枝番の桁数不問化、タブ区切り2候補、貪欲マッチ境界値、フェンス未閉鎖時の安全側挙動を
含む）をすべてカバーし、**28ケース全件成功**（`passed=28 failures=0`）。

```bash
bash .claude/scripts/test/test_check_doc_references.sh
```

## 想定と異なった点

- **個別作業計画のフェンス除外設計に、実装段階で1件バグを発見し修正した。** 計画の
  「実装上の注意」節は「行単位状態の追跡」とだけ書いており、1ファイル1回のストリーミング
  読み込み（行ごとに`in_fence`を更新しながらリアルタイムで除外判定する実装）を素朴に書くと、
  **フェンスが未閉鎖のままファイル末尾に達した場合、除外していた行が確定するのはファイルを
  最後まで読み終えた後**になるため、ストリーミング処理では「未閉鎖なら除外しない」という
  安全側の設計を正しく実装できない（読み進めながら捨ててしまった行を後から復元できない）。
  対応: ファイル全体を`content="$(<"$file")"`で一度読み込み（bash内蔵の変数展開、追加の
  外部プロセスフォークなし）、`strip_fenced_lines_to_reply`関数で「未閉鎖ならフェンス除外を
  一切行わない」という2パス方式に設計を変更した。この設計変更により、`.claude/rules/
  markdown-frontmatter.md`（フェンス11本で未閉鎖）から新たに3件の実在するDDRパス参照が
  候補に加わった（総候補数が当初の実測118件から121件に増加。いずれも実在ファイルであり
  参照切れではない）。
- 上記のバグは、個別作業計画へ提出した敵対的レビュー（1回目）の指摘10（コードフェンスの
  判定規則の未定義）が示唆していたリスクが、実装時に実際に顕在化した例である。

## 確かめられなかったこと

- git bash（MSYS/Windows）実機での動作確認（個別作業計画「やらないこと」で見送りと決定済み）。

## 検証まとめ（個別作業計画の合格条件との対応）

| 検証 | 結果 |
|---|---|
| 1. `.gitignore`参照切れ | 0件（修正前は2件） |
| 2. 構文チェック | OK |
| 3. リポジトリ全体走査 | 候補121件（N>0）、参照切れ0件 |
| 4. 単体テスト | `passed=28 failures=0` |
