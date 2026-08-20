---
title: 実装結果 — set-headerの失敗検知とHANDOFFヘッダ表記の確定
type: report
description: issue #66の実装結果。変更点4つ・確定したヘッダ表記・テストの内訳と、修正前スクリプトでの反証確認
tags: [report, update-handoff-progress, handoff]
keywords: [set-header, 一致件数, ヘッダブロック, 挿入位置, HANDOFF_TEMPLATE, テスト, 実装追認, 検証]
---

# 実装結果 — set-headerの失敗検知とHANDOFFヘッダ表記の確定

対象issue: [#66](https://github.com/yuki-matsu783/MR-driven-workflow/issues/66)（flow-id 3-6）
個別作業計画: `plans/【実装】【テスト】set-headerの失敗検知とヘッダ表記の確定.md`
調査結果: `reports/2026-08-20_set-header-silent-failure_調査結果.md`

## 変更点

### 1. `set-header` の一致件数検査（`update-handoff-progress.sh`）

指定した項目（`--issue` / `--branch` / `--pr` / `--push-count`）ごとに、ヘッダブロック内での一致
件数を数える。**1件でない項目が1つでもあれば、ファイルを書き戻さずに終了コード1で止まる。**

```
$ update-handoff-progress.sh set-header --pr '#999' --file <「- Draft PR:」表記のファイル>
error: set-header: ヘッダ行がちょうど1件見つからなかった項目があります（1件も書き換えていません）
  PR: 一致 0 件（期待する行の書式: 「- PR: <値>」）
hint: HANDOFF.mdの「## フロー進捗状況」見出しの直下へ、次の6行をこの順で1行ずつ置いてください。
        - issue: / - ブランチ: / - PR: / - push回数: / - 現在のループ: / - 追従監視:
      「- Draft PR:」のような別名は使いません（Draftかどうかは値の側に書きます）。
      表記の定義: .claude/docs/spec/update-handoff-progress.md「HANDOFF.mdのヘッダ行」
$ echo $?
1
```

- **0件**: ヘッダ行が無い／表記が違う。
- **2件以上**: 「ヘッダ各項目は1行」という前提が崩れている。どちらを正とすべきか機械では
  決められないため、黙って両方書き換えない。
- `--loop` は行が無ければ挿入する仕様のため件数検査の対象外だが、**他項目の検査を通ってから
  書く**。検査に落ちる呼び出しで `- 現在のループ:` だけが更新される中途半端な状態を作らない。

### 2. ヘッダ行の探索範囲を「ヘッダブロック」へ限定（同上）

`resolve_header_block_to_reply` を新設した。ヘッダブロックは「ファイル先頭から
`## フロー進捗状況` 節の終わり（同見出し以降で最初に現れる別の `## ` 見出しの直前）まで」で、
見出しが無いファイルではファイル全体とする。

- 履歴上の2通りの配置（見出しの前9断面／後23断面）をどちらも拾う。
- 「やったこと」節で `- PR: …` のように引用された行を書き換えない。**変更前は書き換えていた。**
- 走査は行1回・bash組み込みのみで、外部プロセスの起動は増えていない。

### 3. `- 現在のループ:` 行の挿入位置（同上）

| 状況 | 変更前 | 変更後 |
|---|---|---|
| 既に行がある | その行を置換 | 同左 |
| ヘッダブロック内にヘッダ項目がある | **見出しより前**のヘッダ項目に限り、その直後 | 最後のヘッダ項目の直後 |
| ヘッダ項目が無く見出しがある | **見出しの直前** | **見出しの直後**（空行を挟む） |
| どちらも無い | 終了コード1 | 同左 |

変更前は、実物のHANDOFF.md（見出しの下にヘッダを置く形）で `- 現在のループ:` が
`## フロー進捗状況` の**上**へ入り、他のヘッダ項目から切り離されていた。
`- 追従監視:` は挿入位置の基準に含めない（`- 現在のループ:` より後ろに置く項目のため）。

### 4. `HANDOFF_TEMPLATE` へヘッダ行の雛形（`cleanup-task.sh`）

```
## フロー進捗状況

- issue: （未着手）
- ブランチ: （未着手）
- PR: （未着手）
- push回数: 0
- 現在のループ: なし
- 追従監視: なし

（進捗表は次タスク着手時に記入する）
```

タスクごとにAIエージェントが書き起こしていたことが表記ゆらぎの発生源だったため、
flow-id 5-3 のリセットで必ずこの6行が置かれる状態にした。

## 確定したヘッダ行の表記

- 行頭は `- <項目名>: `（半角ハイフン・半角スペース・項目名・半角コロン・半角スペース）。
- **項目名は `issue` / `ブランチ` / `PR` / `push回数` / `現在のループ` / `追従監視` の6つで固定。**
  `- Draft PR:` のような別名は使わない（Draftかどうかは値の側に書く）。
- **1項目1行**、上記の順で並べ、`## フロー進捗状況` 見出しの直下に置く。
- `- 追従監視:` は `set-header` の対象外で、手で書き換える（issue #88 の既存仕様。変更していない）。

## テスト

### `.claude/scripts/test/test_update_handoff_progress.sh`（45 → 64ケース）

実物と同じ形のフィクスチャを作る `write_real_fixture` を追加した（見出しの下にヘッダ6行、
「やったこと」節に引用行あり。PR行の項目名を引数で差し替えられる）。既存の `write_fixture`
（見出し無し）とケースは1件も変更していない。

追加したケース: 表記ゆらぎでのエラー終了／失敗時にファイルが変わらないこと（`cmp` でバイト比較）／
エラーメッセージに項目名・件数・期待する書式が出ること／複数指定で片方だけ見つからない場合に
見つかった側も書き換わらないこと／`--loop` 同時指定でも同様／同じ項目が2行あるときのエラー／
正常系／引用行を書き換えないこと／実物どおりの配置での挿入位置／`- 追従監視:` の前へ入ること。

既存の1ケース（`handoff16`「ヘッダ項目が無い場合の挿入位置」）だけは、**期待値を変更前の
「見出しの直前」から「見出しの直後」へ更新した**。これは上記の変更3による意図した挙動変更である。

### `.claude/scripts/test/test_cleanup_task.sh`（53 → 62ケース）

テンプレートがヘッダ行6行を持つこと／`- Draft PR:` 表記を含まないこと／
**テンプレートに対して `set-header` が実プロセスとして全項目を書き換えられること**を追加した。
最後の1件は、雛形と探索パターンが噛み合っていることの結合確認である。

## 検証

```
test_adversarial_review_count.sh   passed=22  failures=0
test_check_base_conflicts.sh       passed=31  failures=0
test_check_base_sync.sh            passed=55  failures=0
test_cleanup_task.sh               passed=62  failures=0
test_collect_review_points.sh      passed=17  failures=0
test_extract_frontmatter.sh        passed=32  failures=0
test_generate_ddr_list.sh          passed=52  failures=0
test_install_to_project.sh         passed=22  failures=0
test_post_issue_create_notice.sh   passed=14  failures=0
test_search_frontmatter.sh         passed=114 failures=0
test_session_start.sh              passed=51  failures=0
test_update_handoff_progress.sh    passed=64  failures=0
test_usage_tracking.sh             passed=90  failures=0
test_vcs_provider.sh               passed=177 failures=0
```

### 新しいテストが実装追認になっていないことの確認

**修正前のスクリプト（`git show <ブランチ分岐点>:…`）へ差し替えて同じテストを流した。**

| テスト | 修正前 | 修正後 |
|---|---|---|
| `test_update_handoff_progress.sh` | `passed=49 failures=15` | `passed=64 failures=0` |
| `test_cleanup_task.sh` | `passed=54 failures=8` | `passed=62 failures=0` |

「異常があるときに本当に検出できるか」を、意図的に異常を作って確かめた形である
（`REVIEW-POINTS.md`「検証コマンドが、異常があるときに本当に検出できるか」）。

### 実プロセスでの通し確認

- `- Draft PR:` 表記のファイルへ `set-header --pr` → 終了コード1、`diff` で差分なし。
- 表記を `- PR:` へ直したファイルへ `set-header --pr` → 成功。続けて `mark-done 2-3` を実行すると
  `- 現在のループ:` が `- push回数:` の直後へ入る。

## スコープ外として残したもの

- **issue #140**（`mark-skip` がループ範囲の一部だけを `[-]` にできる）。flow-id 2-6 の調査で
  「別issueのまま残す」と結論した。`mark-skip` の挙動は1行も変更していない。
- `- 追従監視:` を `set-header` の対象へ加えること。
- `set-header` が見つからないヘッダ行を**自動で挿入する**案。誤記のヘッダ行を残したまま正しい行が
  増える状態を作るため採らなかった（DDRへ却下案として記録する）。
