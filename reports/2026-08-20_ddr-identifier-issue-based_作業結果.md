---
title: 作業結果 DDR識別子をissue番号ベースへ変更する
type: report
description: issue #133 の作業結果。命名規則の規約化・check-base-conflicts.shの識別子抽出の一般化・単体テスト追加・スキルとDDR一覧の更新と、その検証結果
tags: [ddr, report, conflict, workflow]
keywords: [DDR識別子, issue番号, 枝番, check-base-conflicts, 単体テスト, resolve-conflict, 類型A, README, 検証結果]
---

# 作業結果: DDR識別子をissue番号ベースへ変更する（issue #133）

対象issue: [#133](https://github.com/yuki-matsu783/MR-driven-workflow/issues/133)
個別作業計画: `plans/【実装】【テスト】DDR識別子の新方式への対応.md`
調査結果: `reports/2026-08-20_ddr-identifier-issue-based_調査結果.md`

## 変更したもの

| # | ファイル | 変更内容 |
|---|---|---|
| 1 | `.claude/rules/markdown-frontmatter.md` | 「DDRの識別子」節を新設。命名・枝番・`title` / `superseded_by` の書式・既存連番の扱い・残る重複ケースを明記。`superseded_by` の説明を「番号」→「識別子」へ |
| 2 | `.claude/scripts/src/check-base-conflicts.sh` | `ddr_number_to_reply` → `ddr_identifier_to_reply`（`^(i[0-9]+-[0-9]{2})-` を追加）、`find_duplicate_ddr_numbers` → `find_duplicate_ddr_identifiers`。**JSON出力のキー名は据え置き**。`--help` の出力方式を変更（下記） |
| 3 | `.claude/scripts/test/test_check_base_conflicts.sh` | 関数名の追従＋新方式単独・新旧混在・不正形式のケースを追加（13→**28** アサーション） |
| 4 | `.claude/skills/resolve-conflict/SKILL.md` | 類型Aを **A-1（既存連番の重複）／A-2（同一issueの枝番重複）** へ分割。監視モードの表・検証コマンド・参照リンクも追従 |
| 5 | `.claude/docs/README.md` | DDR一覧を「issue番号ベース（新規はこちら）」「連番（新規追加しない）」の2ブロックへ分割 |
| 6 | `.claude/rules/docs-workflow.md` | ドキュメント運用表のDDR行（ファイル名例・「連番で管理し」） |
| 7 | `.claude/skills/issue-mr-flow/SKILL.md` | 監視の類型A行、flow-id 5-1 節の「gitが検知できない衝突」の説明、その他「DDR番号」→「DDR識別子」 |
| 8 | `.claude/skills/apply-mr-workflow-to-project/SKILL.md` | スクリプト紹介の1行 |
| 9 | `.claude/docs/spec/check-base-conflicts.md` | 「検知2」を識別子ベースへ書き換え、issue #133 の影響範囲エントリを追加 |
| 10 | `.claude/docs/ddr/i133-01-…md` | **新規。新方式の第1号**。採用理由と却下案4件を記録 |

## 決めた仕様

```
.claude/docs/ddr/i133-01-DDR識別子はissue番号ベースにし連番採番をやめる.md
                 ~~~~ ~~
                 |    枝番: 2桁ゼロ埋め、01から。1件しか作らない場合も省略しない
                 issue番号: GitHub/GitLabが採番した番号そのまま（ゼロ埋めしない）
```

`title` と本文冒頭の見出しは `i133-01. <タイトル>`、`superseded_by` は `"i133-01"`。
既存の連番DDR 55件（0003〜0059）は**改番せず**、参照も一切変更していない。

## 予定になかった修正

**`check-base-conflicts.sh` の `--help` が行番号直書きだった。** `sed -n '2,30p'` で先頭コメントを
出していたため、今回コメントを増やした時点でヘルプが説明の途中で切れた。行番号を書かず、
「2行目から最初の非コメント行の直前まで」を `awk` で取る形へ変えた。**コメントの増減で範囲が
黙ってずれる作りをそのままにすると、次に同じ壊れ方をする**ため、範囲指定ごと直した。

```bash
# 変更前（コメントを増減させると黙ってずれる）
sed -n '2,30p' "${BASH_SOURCE[0]}"
# 変更後
awk 'NR > 1 { if ($0 !~ /^#/) exit; print }' "${BASH_SOURCE[0]}"
```

## 検証結果

| # | 検証 | 結果 |
|---|---|---|
| 1 | `bash -n` （変更した `.sh` 2件） | OK |
| 2 | `bash .claude/scripts/test/test_check_base_conflicts.sh` | **`passed=28 failures=0`** |
| 3 | `.claude/scripts/test/test_*.sh` 全12件 | 全件 `failures=0`（合計664アサーション） |
| 4 | `check-base-conflicts.sh --no-fetch` | 正常なJSONを返し `hasConflict=false` / `hasDuplicateDdrNumber=false` |
| 5 | `extract-frontmatter.sh .` | `files=104 built=13 reused=91 failed=0`。新DDRが `index.jsonl` に入った |
| 6 | `search-frontmatter.sh --type ddr --text "issue番号ベース"` | 新DDRを1件で引ける（`doc-search` から到達できる） |
| 7 | `--help` の出力 | 先頭コメントブロック全体が出る（途中で切れない） |
| 8 | CR混入・BOM | 変更した9ファイルすべて CR差=0 / BOM無し |

### 追加した単体テストの中身（issue #133分）

新方式の抽出（3件）・不正形式の拒否（5件）・重複判定（6件）を追加した。とくに次の3つが
今回の設計判断を直接守っている。

| テスト | 何を守っているか |
|---|---|
| `別issueなら同じ枝番でも重複しない` | **本方式が衝突を無くす仕組みそのもの**（`i133-01` と `i134-01` は別） |
| `同一issue内の枝番重複は検出する` | 新方式でも残る唯一の衝突経路を、検知が拾えること |
| `0133 と i133-01 は別の識別子` | 4桁のissue番号を持つ新方式が、同じ数字の連番DDRと同一視されないこと |

不正形式（枝番1桁 `i133-1-`、枝番3桁 `i133-001-`、枝番なし、大文字 `I133-01-`、接頭辞
`issue133-01-`）をすべて「DDRではない」として弾くのは、表記の揺れが**別々の識別子として通り、
同じDDRが二重に採番される**のを防ぐため。

## 実装中に踏んだ問題

**単体テストが無出力・終了コード1で落ちた。** 追加したケースのうち
`ddr_identifier_to_reply ".claude/docs/ddr/i133-001-枝番が3桁.md"` を裸で呼んでいたため、
関数が終了コード1を返した時点で `set -e` によりテストスクリプト全体が停止し、
`passed=… failures=…` の行にすら到達しなかった。既存テストと同じく `if` の条件式で受ける形へ
直した（`.claude/rules/shell-script-style.md`「テスト」の既知の落とし穴。**失敗が
「アサーション失敗」ではなく「何も出ずに終わる」形になるため気づきにくい**）。

## やらなかったこと（意図的）

- **既存55件のDDRの改番。** issueの期待する動作どおり、ファイル名・本文・他ファイルからの参照
  （262行・919箇所）を一切変更していない。
- **JSONキー `duplicateDdrNumbers` / `hasDuplicateDdrNumber` の改名。** 理由は
  `.claude/docs/ddr/i133-01-…md`「JSONキーを改名しなかった理由」。
- **`search-frontmatter.sh:134` の `^[0-9]{4}-[0-9]{2}-[0-9]{2}$`。** `--since` の日付判定であり
  DDRとは無関係。
- **`.claude/docs/spec/issue-mr-workflow.md` の過去changelog**（`0034→0035→0036→0038` 等）。
  point-in-timeの記録のため書き換えない。

## 受け入れ条件との対応

| issueの受け入れ条件 | 状況 |
|---|---|
| 新方式の命名規則が `markdown-frontmatter.md` に明記されている | 済（「DDRの識別子」節） |
| 既存58件（実測55件）のファイル名・本文・参照が変更されていない | 済（差分に既存DDRは1件も含まれない） |
| `check-base-conflicts.sh` が新方式を正しく扱い、単体テストが新旧混在を含めて通る | 済（`passed=28 failures=0`） |
| `resolve-conflict` 類型Aに新方式で衝突が起きないこと・既存連番は従来どおり改番することが記載 | 済（A-1 / A-2 へ分割） |
| 採用理由と却下案（採番の遅延／レンジ分割）を記録したDDRがある | 済（`i133-01-…md`。却下案は4件記載） |
| `.claude/docs/README.md` のDDR一覧が破綻なく並んでいる | 済（2ブロック構成。新方式はissue番号の数値順） |
