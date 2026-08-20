---
title: 全体作業計画 get_branch_work_filesを改名に強くする（issue #115）
type: plan
description: get_branch_work_filesの出力を「1行＝1つの実在するパス」へ揃えるための全体作業計画。
tags: [plan, issue-mr-flow, provider, workflow]
keywords: [get_branch_work_files, porcelain, 改名, rename, NUL, quotepath, resume, SessionStart, 単体テスト]
---

# 全体作業計画: `get_branch_work_files` を改名に強くする（issue #115）

対象issue: [#115](https://github.com/yuki-matsu783/MR-driven-workflow/issues/115)
ブランチ: `claude/branch-work-files-rename-rf7yzm`

> **注記（作成方法）**: 本ファイルはflow-id 1-4の全体作業計画だが、このセッション（Claude Code on
> the web のリモート実行環境）はPlanモードでの合意を取れないため、planツールではなくWrite/Editで
> 作成している。ファイル名もハーネスの自動命名ではなく手動で付けた。**このブランチの全体作業計画は
> このファイル1つだけ**であり、以降のセッションでも新規作成しない（`plans/` 配下で `【` で
> 始まらないファイルが全体作業計画）。

## 背景・課題

`.claude/scripts/src/vcs/Provider.sh` の `get_branch_work_files` は、未コミット分を
`git status --porcelain`（行単位）の出力から `sed -E 's/^...//'` で先頭3文字を落として得ていた。
改名は行単位形式では `R  <旧パス> -> <新パス>` の1行になるため、**どちらのパスとしても存在しない
`<旧パス> -> <新パス>` という1行**が結果に混ざる。

呼び出し元（`resume` の `issue-mr-resume` サブエージェント、SessionStart hookのコンテキスト注入）は
これを「このブランチの作業ファイル一覧」として人間・AIへ提示しているため、`while IFS= read -r f` で
回してファイル操作へ渡す・`create-commit.sh` へ渡す、といった素直な使い方ができない。

issue #97 の作業中に2回踏み、2回とも目視で回避している。目視で気づけたのは日本語ファイル名で
見た目が特徴的だったためで、ASCIIのみのパスなら見逃していた可能性が高い。

## ゴール（issueの受け入れ条件）

| # | 受け入れ条件 | 対応フェーズ |
|---|---|---|
| 1 | 改名を含む状態で `" -> "` を含む行が出力されないこと | フェーズ3 |
| 2 | ステージ済みの改名（`R `）・未ステージ側の変更を伴う改名（`RM`）の両方で新パスが返ること | フェーズ3 |
| 3 | 非ASCIIのパスでも壊れないこと（`-c core.quotepath=false` の維持） | フェーズ3 |
| 4 | `.claude/scripts/test/test_vcs_provider.sh` にフィクスチャでの単体テストが追加され `passed=N failures=0` で通ること | フェーズ3 |
| 5 | 改名が無い場合の既存呼び出し元の出力が従来と変わらないこと | フェーズ3 |

## フェーズ2〈調査〉

**今回は独立した調査フェーズを置かない（flow-id 2-1で判断）。**

- 原因・修正箇所・期待する出力はissue本文で特定済みで、追加で調べるべきは
  「`git status --porcelain -z` が改名エントリをどの順序・どの形式で出すか」の1点のみ。
- これは実機で2コマンド（`git mv` した状態で `--porcelain` と `--porcelain -z` を `od -c` で比較）
  確認すれば済み、個別調査計画をレビューに掛ける価値より、実装と同じ回で確かめて
  `reports/` に根拠として残す方が速い。
- **省略の判断はこの節ではなく flow-id 2-1 の時点で行った**（枠だけを残す規約に従い、節は置く）。

## フェーズ3〈作業〉

個別作業計画: `plans/【実装】【テスト】改名パスの一覧化.md`

1. `git status --porcelain -z` の出力形式を実機で確認する（改名エントリのフィールド順・クォートの
   有無・非ASCIIの扱い）。
2. `Provider.sh` に純粋関数 `porcelain_z_to_paths` を新設し、`get_branch_work_files` の未コミット分を
   `--porcelain -z | porcelain_z_to_paths` へ差し替える。
3. `.claude/scripts/test/test_vcs_provider.sh` にフィクスチャベースの単体テストを追加する。
4. 実機（実際に `git mv` したリポジトリ）で新旧の出力を比較する。

## フェーズ4〈反映〉

反映対象は flow-id 4-1 で洗い出す。現時点の見込み（確定した反映内容ではない）:

- **設計反映**: `.claude/docs/spec/issue-mr-workflow.md`（「提供関数」表、`core.quotepath` の注意、
  変更履歴）。DDRを起こすかは4-1で判断する。
- **AIアセット反映**: `.claude/rules/shell-script-style.md`「コマンド置換とNULバイト」節へ、
  `git status --porcelain` の行単位形式が改名で曖昧になる旨を一般化して残せる見込み。

## フェーズ5〈クローズ〉

`cleanup-task.sh` → コンフリクト確認 → 関連issue通知の要否判断 → commit/push → Draft解除。
**マージはユーザーの明示指示があるまで行わない。**

## この計画で決めないこと（スコープ外）

- **削除されたファイルの扱い**（issue本文で明示的に「このissueでは変更しない」とされている）。
  現行どおり、削除済みのパスも一覧に含まれる。
- コミット済み分の取得方法（`git diff --name-only`）。改名を新パス1件として返すため問題は無い。
- `get_branch_work_files` がベースブランチを固定で見ている件（specの未決定事項に既出。issue #15）。

## 検証

```bash
bash -n .claude/scripts/src/vcs/Provider.sh
bash .claude/scripts/test/test_vcs_provider.sh          # passed=N failures=0
source .claude/scripts/src/vcs/Provider.sh && get_branch_work_files
```

加えて、実際に `git mv` した状態で `get_branch_work_files` を呼び、`" -> "` を含む行が出ないこと・
出力の各行が実在するパスであることを確認する。

## 合意の記録

- 非対話的なリモート実行セッションのため、flow-id 1-5（人間による全体作業計画への合意）は
  取得できていない。issue #115 の「期待する動作」「受け入れ条件」を合意済みの要件として扱う。
