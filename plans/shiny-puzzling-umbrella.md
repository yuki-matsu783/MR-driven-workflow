---
title: 全体作業計画 issue #20 HANDOFF.md進捗更新の自動化
type: guide
description: HANDOFF.mdの進捗表更新を専用スクリプトへ委譲するための全体作業計画
tags: [handoff, automation, shell-script]
keywords: [HANDOFF, 進捗表, flow-id, スクリプト化, docs-workflow]
---

# 全体作業計画: issue #20 HANDOFF.mdの進捗更新をスクリプトで自動化する

## Context

`.claude/rules/docs-workflow.md` と `.claude/skills/issue-mr-flow/SKILL.md` は「flow-idが1つ
進むごとに `HANDOFF.md` を更新し、commitより前に同じcommitへ含める」ことを求めているが、更新は
メインエージェントの手編集に依存している。進捗表は39行あり、記号の規則（ループ扱いのステップは
往復1回につき `[]` を1つ追加し、同じループ範囲内のステップは常に同数を保つ）も細かいため、
書き間違い・更新漏れが起きやすく、メインエージェントのコンテキストも消費する。これを解消するため、
`.claude/scripts/src/update-handoff-progress.sh`（仮称）で進捗表の記号・ヘッダ情報の更新を機械化する。

### 副次的に発見した状態: 前issue分の後始末が未実施

現在のブランチ `claude/github-issue-20-85bvts` はmainから分岐した状態だが、`HANDOFF.md` ・
`plans/` ・`worklog/` に、直前のissue #13（PR #29、squash mergeで既にmainへ取り込み済み）の
内容がそのまま残っている。`plans/【設計】【実装】【設計反映】レビュー依頼メッセージへの参照リンク
付与.md`、`worklog/20260818_issue13_..._push1.md` / `_push2.md` が該当し、`HANDOFF.md` も
issue #13時点の進捗表・記述のまま。これは `.claude/skills/issue-mr-flow/SKILL.md`
「PRがflow-id 5-1実施前にマージされてしまった場合の対処」に該当するケース。

同ドキュメントは対処として専用の `chore/cleanup-*` ブランチを推奨しているが、今回は
issue #20専用ブランチが既に外部から用意されているため、別ブランチを新規に立てず、**このブランチの
最初のコミットとして前issue分の片付け（`plans/` `worklog/` 削除・`HANDOFF.md` リセット・
`index.jsonl` 再生成）を単独で行い、そのあとissue #20本題に進む**方針とする。

## 進め方の方針

- **フェーズ2（調査）は個別調査計画を独立して設けない。** 既にExploreエージェントによる調査で
  `HANDOFF.md` の構造・`Provider.sh`/`create-commit.sh`/`extract-frontmatter.sh` の実装パターン・
  `docs-workflow.md` の記号規約・DDR命名規則を把握済みのため、フェーズ3（設計・実装・テスト）から
  開始する。
- フェーズ3の個別作業計画は `plans/【設計】【実装】【テスト】HANDOFF進捗自動更新スクリプト.md`
  として種別を併記する（設計が小規模で実装方針と一体で判断できるため）。
- フェーズ4（反映）で `.claude/docs/spec/` への新規spec作成、`.claude/rules/docs-workflow.md` への
  `[-]` 記号規約の明文化、`.claude/skills/issue-mr-flow/SKILL.md` のHANDOFF更新手順の委譲を行う。

## 実装方針の概要

### 新規スクリプト `.claude/scripts/src/update-handoff-progress.sh`

- サブコマンド構成（詳細な引数仕様はフェーズ3の個別作業計画で確定）:
  - `mark-done <flow-id>`: 該当行（ループ範囲に属する場合は同じ範囲の全flow-id行）の末尾のマスを
    `[]` → `[x]` にする。
  - `mark-skip <flow-id...>`: 該当行を `[-]` にする（「今回は実施しないフェーズ」用）。
  - `add-round <flow-id>`: ループ範囲の全行に新しい `[]` を1つ追加する（次の往復が始まったことを
    表す）。ループでないflow-idに対して呼ばれたらエラーにする。
  - `set-header --issue <n> --branch <name> --pr <n|なし> --push-count <n>`: ヘッダ3行
    （issue/ブランチ/PR、push回数）を更新する。
- ループ範囲テーブル（`2-3〜2-4`, `2-6〜2-9`, `3-3〜3-4`, `3-6〜3-9`, `4-3〜4-4`, `4-6〜4-9`）は
  スクリプト内に定数として持つ。
- `HANDOFF.md` のMarkdownテーブル行を直接文字列処理で書き換える（jqは対象外。JSON操作ではなく
  テーブル行の置換のため）。
- `.claude/rules/shell-script-style.md` 準拠: シバン `#!/usr/bin/env bash`、`set -euo pipefail`、
  BOM無しUTF-8・LF改行、関数名snake_case。
- `.claude/scripts/src/extract-frontmatter.sh` と同様、ファイル直接実行時のみ `main` を呼ぶガードを
  設け、`tests/` から関数をsourceして再利用できる構成にする。

### テスト

- `tests/test_update_handoff_progress.sh` を新規作成。一時ディレクトリに `HANDOFF.md` の
  フィクスチャを用意し、各サブコマンド適用後の内容を検証する純粋ロジックテスト
  （`.claude/rules/shell-script-style.md`「テスト」の `passed=N failures=N` 規約に従う。
  `tests/test_vcs_provider.sh` を参考にする）。

### ドキュメント更新

- `.claude/rules/docs-workflow.md`: `[-]`（今回は実施しないフェーズ）の記号を、既存の
  `HANDOFF.md` 内の凡例（`進捗記号: `[x]` 完了 / `[]` 未着手・進行中 / `[-]` 今回は実施しない`）を
  正史ルールとして明文化する。
- `.claude/skills/issue-mr-flow/SKILL.md`: 「flow-idが1つ進むごとに、必ず`HANDOFF.md`を更新する」
  の手順を、`update-handoff-progress.sh` 呼び出しへ委譲する形に書き換える。
- 新規spec `.claude/docs/spec/update-handoff-progress.md`（または既存
  `.claude/docs/spec/issue-mr-workflow.md` への追記。フェーズ3で最終判断）で、スクリプトの
  サブコマンド仕様・設計意図を記録する。

## 検証方法

- `bash -n .claude/scripts/src/update-handoff-progress.sh` で構文チェック。
- `bash tests/test_update_handoff_progress.sh` を実行し `passed=N failures=0` を確認。
- 実際の `HANDOFF.md` に対して各サブコマンドを試し、`git diff` で意図通りの変更か確認する。
