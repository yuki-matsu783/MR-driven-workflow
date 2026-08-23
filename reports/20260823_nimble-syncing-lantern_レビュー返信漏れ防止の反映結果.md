---
title: レビュー返信漏れを機構で防ぐ反映の結果
type: report
description: issue #70 フェーズ4のAIアセット反映結果。ループ範囲へのmark-doneが未返信スレッド0件を要求する機構を入れ、関連するAIアセット・仕様・テストを更新した
tags: [ai-asset, review, handoff, issue-70]
keywords: [未返信スレッド, mark-done, set-header, 敵対的レビュー, レビュー完了合図, 検出力, 非互換]
---

# 実施結果: レビュー返信漏れを機構で防ぐ（案A）

個別反映計画: `plans/【AIアセット反映】レビュー返信漏れを機構で防ぐ.md`
対象: issue #70 / PR #157 / flow-id 4-6

## 結論

**`HANDOFF.md` のヘッダへ `- 未返信スレッド:` を新設し、レビュー往復のループ範囲への
`mark-done` が「0件」でなければ拒否する形にした。** 計画の変更5件をすべて実施し、
関連する仕様3本・テスト2本もあわせて更新した。全16本のテストが緑（**1037件**、
`update-handoff-progress` は 100→118、`cleanup-task` は 62→64）。`--check` も0。

**案Bを採らなかった理由は計画のとおりで、変わっていない。** 原因4つのうち
「守れる形になっていなかった」2つ（記録の欠落・記録の粒度）は文言では塞げない。

## 変更したもの

| # | ファイル | 内容 |
|---|---|---|
| 1 | `.claude/scripts/src/update-handoff-progress.sh` | `set-header --unreplied <n>` を追加／**ループ範囲への `mark-done` が `- 未返信スレッド:` を検査**／ヘッダ行の置換・挿入を `set_optional_header_in_lines` へ共通化 |
| 2 | `.claude/scripts/src/cleanup-task.sh` | `HANDOFF_TEMPLATE` のヘッダ雛形を6行→7行 |
| 3 | `.claude/skills/adversarial-review/SKILL.md` | **手順8「投稿したスレッドを `HANDOFF.md` へ記録する」を新設**（旧手順8＝報告は手順9へ） |
| 4 | `.claude/skills/issue-mr-flow/SKILL.md` | `comments` 手順2へ返信ゼロの一覧化／手順5へ `set-header --unreplied 0`／「レビュー完了合図の確認」へ **(3)** を追加／全体フロー表のループ行6件から同節への参照 |
| 5 | `.claude/rules/docs-workflow.md` | ループ範囲を `[x]` にする条件を2つに明文化 |
| 6 | `.claude/docs/spec/update-handoff-progress.md` | ヘッダ行の定義を7項目へ／サブコマンド表／新節「ループ範囲への`mark-done`と未返信スレッド」／影響範囲 |
| 7 | `.claude/docs/spec/cleanup-task.md` | 雛形6行→7行 |
| 8 | `.claude/docs/spec/adversarial-review.md` | 責務分離の図（手順8/9）／影響範囲 |
| 9 | `.claude/docs/ddr/i0066-01-…md` | `note` のみ追記（**本文は不変**）→ `generate-ddr-list.sh` で一覧を再生成 |
| 10 | `.claude/scripts/test/test_update_handoff_progress.sh` | 100→118ケース |
| 11 | `.claude/scripts/test/test_cleanup_task.sh` | 62→64ケース |

## 設計上の判断（計画に無かったもの）

### 1. `--unreplied` は行が無ければ「挿入する」（他の4項目と違う扱い）

`set-header` は既定では「対象行がちょうど1件見つからなければ失敗」だが、`--unreplied` は
`--loop` と同じく**行が無ければ挿入する**ことにした。**この行を持たない `HANDOFF.md` が既に
存在する以上、失敗にすると復旧手段が無くなる**ためである（`mark-done` が拒否し、その復旧に
必要な `set-header` も拒否する、という詰みが起きる）。

### 2. 行が無い場合の `mark-done` は「未確認」として拒否する

逆に `mark-done` 側は、行が無いことを**通さない**。素通りさせると、行を持たない古い
`HANDOFF.md` でだけ検査が効かなくなり、**まさに検査を足したかった状況で効かない**。
エラーメッセージに `set-header --unreplied 0` を出すので、復旧は1コマンドで済む。

### 3. ヘッダ行の置換・挿入を共通化した

`set_loop_header_in_lines` を `set_optional_header_in_lines <label> <text> <anchor>` へ
一般化し、`現在のループ` / `未返信スレッド` の2つがその薄いラッパーになった。**挿入位置は
anchor 正規表現で決まる**ため、`- 未返信スレッド:` は `- 現在のループ:` の直後、
`- 追従監視:` の前に入る（`- 追従監視:` はどちらの anchor にも含めない）。

### 4. `assets/` は `.gitignore` 対象なので同期不要

`.claude/skills/apply-mr-workflow-to-project/assets/` は `sync-assets.sh` が作る生成物で、
`.gitignore` の対象である。今回の変更で手を入れる必要はない（配布時に生成される）。

## 検証結果（計画の完了条件10項目）

| # | 条件 | 結果 |
|---|---|---|
| 1 | `bash -n` が全変更 `.sh` で通る | **OK** |
| 2 | 未返信が1件以上ならループ範囲への `mark-done` が非0で終わり、1件も書き換わらない | **OK**（`assert_unchanged` でバイト列比較） |
| 3 | 未返信0件ならループ範囲への `mark-done` が従来どおり通る | **OK**（既定の挙動が変わっていないことの表明） |
| 4 | 単発ステップへの `mark-done` は値に関わらず通る | **OK**（未返信3件のファイルで `1-1` を完了にできる） |
| 5 | 行が無いHANDOFFではループ範囲への `mark-done` が拒否される | **OK**（ファイルも不変） |
| 6 | `set-header --unreplied <n>` が当該行だけを書き換える | **OK**（本文中の引用行・他のヘッダ行を巻き込まない） |
| 7 | **検出力**: 判定を無効化するとテストが落ちる | **OK。5件落ちた**（`|| return 1` → `|| true` に置換して確認し、復元後は再び緑） |
| 8 | `cleanup-task.sh` の雛形に新設行がある | **OK**。**値まで検査する**（`0` を `1` に変えると1件落ちることも確認） |
| 9 | 全16本のテストが緑 | **OK**（passed=1037 failures=0） |
| 10 | `.gemini/` を再生成し `--check` が0 | **OK** |

## 気づいたこと

### 既存テストが一斉に落ちたこと自体が、検査が効いている証拠だった

フィクスチャへ `- 未返信スレッド:` を足すまで、**ループ範囲への `mark-done` を含む既存ケースが
すべて落ちた**。「テストを直す作業」に見えるが、実際には**新しい前提条件が本当に必須になって
いる**ことの表明である。落ちなかったなら、検査が働いていないことを疑うべきだった。

### `status_of` の期待値を取り違えた

`test_cleanup_task.sh` の `status_of` は「テストが真なら `0`」を返す。既存の
「進捗表の記号を含まない」が期待値 `1` だったのに引きずられ、「雛形に含まれる」ことの
期待値まで `1` と書いて1件落とした。**同じヘルパでも、肯定の検証と否定の検証で期待値が
反転する。**

## 残課題（このループでは扱わない）

- **`i0070-02` としてDDRを書くこと**（「返信漏れは文言ではなく機構で塞ぐ」という判断）。
  DDRの追加は `plans/【設計反映】gemini変換の仕様化とDDR整備.md` の担当なので、そちらへ寄せる。
  判断の根拠自体は `.claude/docs/spec/update-handoff-progress.md`
  「なぜ機構で止めるのか」に既に書いてある。
- **限界**: 値を書くのはAIエージェント自身なので、嘘を書けば通る。
  `block-direct-git-commit.sh` と同じく**既定動作を確実な方向へ倒す仕組み**であり、
  敵対的な安全境界ではない。

## 次にやること

同じフェーズ4の残り2本（`【設計反映】` `【実装反映】`）。種別ごとにレビューを分ける方針
（`.claude/skills/issue-mr-flow/SKILL.md`「原則併記せず分ける」）に従い、4-6〜4-9 を種別の数だけ回す。
