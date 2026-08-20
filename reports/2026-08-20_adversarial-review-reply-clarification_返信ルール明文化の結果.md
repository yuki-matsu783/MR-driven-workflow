---
title: 敵対的レビュー由来スレッドの返信ルール明文化の結果（issue #109）
type: report
description: issue #109 の作業結果。受け入れ条件6項目への対応状況と、機械的検出手段を設けなかった理由の記録
tags: [report, workflow, adversarial-review]
keywords: [敵対的レビュー, 返信, comments, reply, 未返信, レビュー完了合図, DDR0061, 受け入れ条件]
---

# 敵対的レビュー由来スレッドの返信ルール明文化の結果（issue #109）

## 結論

**コードは1行も変更していない。ドキュメントの明文化のみで対応した。**

`get_mr_unresolved_comments` は元から敵対的レビューのスレッドも `unresolved` として返しており、
flow-id 2-4/2-9/3-4/3-9/4-4/4-9 の `comments` / `reply` ループは**仕組み上は既にこれらのスレッドを
対象に含んでいた**。欠けていたのは「AI自身が投稿した指摘も返信の対象である」というルールの
明文化だけであり、issueの方針（返信の手順を新設しない）どおりに進められた。

## 変更したファイル

| ファイル | 内容 |
|---|---|
| `.claude/skills/issue-mr-flow/SKILL.md` | 「敵対的レビューの位置づけ」表へ返信の担当を示す行／`comments` サブコマンドへ手順4を新設（既存の手順4・5は5・6へ繰り下げ）／「レビュー完了合図の確認」節の確認項目を2つへ分割し (2) 未返信スレッドの確認を追加 |
| `.claude/skills/adversarial-review/SKILL.md` | 手順8末尾へ返信の担当を示す**参照の1文**／「してはいけないこと」へ投稿直後の自己返信の禁止 |
| `.claude/docs/spec/adversarial-review.md` | 「投稿されたスレッドの取得」節へ返信の扱い／「影響範囲」節末尾へ `### 追記: …（issue #109）` |
| `.claude/docs/ddr/0064-敵対的レビュー由来のスレッドも人間の指摘と同列に返信を必須とする.md` | 新規 |
| `.claude/docs/README.md` | DDR一覧へ0061を追加 |

## 受け入れ条件への対応

| # | 受け入れ条件 | 状況 |
|---|---|---|
| 1 | `issue-mr-flow/SKILL.md` の `comments` に、敵対的レビュー由来スレッドも返信対象である旨とAI自身の指摘だからと返信を省いてはならない旨 | **満たした**（手順4） |
| 2 | 同ファイルの「レビュー完了合図の確認」節に未返信スレッドの確認 | **満たした**（確認(2)） |
| 3 | `adversarial-review/SKILL.md` に、返信の担当が `comments`/`reply` ループであることを示す参照（手順自体は書かない） | **満たした**（手順8末尾。返信の署名・関数呼び出し等の手順は書いていない） |
| 4 | `spec/adversarial-review.md` の更新と「影響範囲」への本issue分のエントリ追記 | **満たした**（過去issue分は書き換えていない） |
| 5 | 返信を必須とする判断を新規DDRへ残すか既存への追記で足りるかの検討と結論の記録 | **満たした**（DDR 0064 の却下案(e)。**新規DDRを起こす**と結論） |
| 6 | 機械的な検出手段を追加した場合の単体テスト／既存テストがすべて通ること | **追加していない**（下記）。既存の単体テスト12スクリプト・683ケースが `failures=0` |

## 機械的検出手段を設けなかった理由

issue本文が「調査フェーズで判断する。設けない場合はその理由を記録する」としていた項目。
**設けない**と判断した。理由は2点（詳細はDDR 0064 却下案(f)）。

1. **CLI経路でしか動かない手段になる。** `Provider.sh` の関数は `require_vcs_cli` を通るため、
   `gh`/`glab` CLIが無い実行環境（Claude Code on the web。`get_vcs_access_mode` が `mcp`）では
   呼べない。ゲートは両経路で同じ強度である必要があり、片方でしか動かない検出手段は
   「使える環境と使えない環境でルールの強度が変わる」二層構造を作る。
2. **判定条件がそもそも出力から機械的に読める。** `format_review_comments` はスレッド内の全コメント
   を1行ずつ `[review ... threadId=...]` の形で render するため、**同じ `threadId=` の行が1本しか
   無い＝返信ゼロ**が確定する。数え上げではなく重複の有無の判定であり、`unresolved` の確認と
   同じ1回の `comments all` の出力から読み取れる。

将来この明文化だけでは返信漏れが止まらないと分かった場合は、CLI経路とMCP経路の両方から使える形
（正規化JSONを標準入力から受け取る純粋なフィルタ等）で再検討する。

## 先行issue #106 との競合

issue本文が懸念していた着手順・競合は、**確認した時点でどちらも解消済み**だった。

- PR #118（issue #106）はマージ済みで、`adversarial-review/SKILL.md` の手順番号は既に1〜8へ
  繰り上がっている。本作業は繰り上がり後の「手順8」を前提に書いている。
- `spec/adversarial-review.md`「影響範囲」節の追記は、#121 と同じ体裁の `### 追記:` サブセクション
  として**節の末尾**（`## 設定項目` の直前）へ置いた。当初 `新規（issue #106）:` の直後へ入れたが、
  それだと #109 が #121 より前に並んで時系列が逆になるため置き直した。

## HTML版を作らない判断

`.claude/rules/docs-workflow.md` が `reports/` の `.html` を必須としているのは **flow-id 2-6
（調査の実施）**であり、3-6・4-6 は「結果を視覚的にまとめる必要があれば同名の `.html` も作成する」
と任意になっている。本タスクはフェーズ2を丸ごと省略しており（HANDOFF.mdの進捗表で 2-* を `[-]`）、
成果は「4ファイルのどこに何を書いたか」という一次元の対応表に収まる。複数要素間の関連が主題では
ないため（`canvas-report` スキルの適用対象でもない）、**HTML版は作らない**と判断した。作り忘れと
区別が付くよう、この判断をここに残す。

## 検証

### 既存の単体テスト

```bash
for f in .claude/scripts/test/*.sh; do echo "$(basename "$f"): $(bash "$f" 2>&1 | tail -1)"; done
```

全12スクリプトが `failures=0`（合計683ケース）。内訳は
`test_adversarial_review_count.sh: passed=22` / `test_check_base_conflicts.sh: passed=13` /
`test_check_base_sync.sh: passed=55` / `test_cleanup_task.sh: passed=53` /
`test_collect_review_points.sh: passed=17` / `test_extract_frontmatter.sh: passed=32` /
`test_post_issue_create_notice.sh: passed=14` / `test_search_frontmatter.sh: passed=114` /
`test_session_start.sh: passed=51` / `test_update_handoff_progress.sh: passed=45` /
`test_usage_tracking.sh: passed=90` / `test_vcs_provider.sh: passed=177`。

コードは変更していないため、これは「変わっていないこと」の確認である。変更はすべてmarkdownで、
`bash -n` の対象となるスクリプトの変更は無い。

### 手順番号の繰り下げに対する相互参照の追随

`comments` サブコマンドへ手順4を挿し込み、既存の手順4・5を5・6へ繰り下げたため、番号で参照して
いる箇所を洗い出した。

```bash
grep -rn "comments.*手順[0-9]\|手順[0-9].*comments" .claude/ --include=*.md
```

- 追随させた（現在の仕様を説明している箇所）: `.claude/skills/issue-mr-flow/SKILL.md` の
  MCP読み替え表・「記録する単位とタイミング」節、`.claude/docs/spec/issue-mr-workflow.md` の
  「チャットで受けたレビュー判断の記録」節。
- **書き換えなかった（point-in-time記録）**: `.claude/docs/spec/issue-mr-workflow.md` の
  issue #50 changelogエントリ、`.claude/docs/ddr/0041-…md` の本文。DDRの本文は不変であり、
  specの過去changelogは当時の記録であるため（`.claude/rules/docs-workflow.md`）。DDR 0041 が
  「手順5」を指したまま古くなるのはこの繰り下げの避けられない帰結で、対応関係は
  `spec/adversarial-review.md`「影響範囲」の本issue分エントリ（「既存の手順4・5は5・6へ繰り下げ」）
  から辿れるようにした。

### `update-handoff-progress.sh` が進捗表を操作できること

進捗表がプレースホルダのままだと、`mark-done` 等が終了コード1で落ちることを実機で確認した。

```bash
cp HANDOFF.md /tmp/HANDOFF-test.md
bash .claude/scripts/src/update-handoff-progress.sh mark-done 4-1 --file /tmp/HANDOFF-test.md
# → error: flow-id 4-1 に該当する行が想定数（1）見つかりませんでした（実際: 0） / exit=1
```

41行の進捗表を復元したうえで、実施済みのflow-id（1-1/1-2/1-3/1-4/1-6/3-1/3-2/4-1/4-2）を
`mark-done`、フェーズ2の全ステップを `mark-skip` で埋め、いずれも終了コード0で通ることを確認した。

### PR #107 / #104 の返信ゼロ件数

DDR 0064・SKILL.md が根拠として挙げている件数は、**issue #109 本文の記述をそのまま引いたもの**で
あり、本タスクの中で数え直してはいない。数える場合は
`mcp__github__pull_request_read`（`method="get_review_comments"`）で各スレッドの `comments` 配列の
件数を見る（CLI経路なら `comments all` の出力で同じ `threadId=` の行数を見る）。
