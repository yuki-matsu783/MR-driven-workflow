---
title: 【実装】【テスト】SKILL.md再読み込み指示の注入
type: plan
description: SessionStart hookへissue-mr-flow対象判定とSKILL.md再読み込み指示の組み立てを追加する個別作業計画
tags: [plan, session-start-hook, implementation, test]
keywords: [issue113, session-start, build_work_context, 純粋関数, 対象判定, 指示文, 単体テスト, 結合確認]
---

# 【実装】【テスト】SKILL.md再読み込み指示の注入

全体作業計画: `plans/breezy-humming-lantern.md`
対象issue: #113

実装とテストの合意は1回で取れる粒度のため、種別を併記する（`.claude/rules/docs-workflow.md`
「種別を複数併記する場合／分ける場合」）。

## これから何をするか

### 1. `session-start.sh` へ純粋関数を2つ追加する

`extract_handoff_next_steps` の直後（`build_context` の手前）へ置く。どちらも外部コマンドを
呼ばず、引数だけで結果が決まる形にして単体テストの対象にする。

| 関数 | 引数 | 返すもの |
|---|---|---|
| `issue_mr_flow_branch_reason` | ブランチ名から抽出したissue番号（無ければ空）／ブランチ固有の作業ファイル一覧（無ければ空） | 対象なら判定根拠を標準出力へ。対象外なら何も出さず終了コード1 |
| `format_skill_reload_instruction` | 判定根拠の文字列 | 「SKILL.mdを読み直すこと」の指示文（見出し＋本文） |

判定は**どちらか一方でも成り立てば対象**とする。両方そろう場合は根拠を `／` で連結する。

指示文に必ず含める要素:

- 読み直す対象のパス `.claude/skills/issue-mr-flow/SKILL.md`（唯一の実装フロー定義であること）
- **「このセッションで既に読んでいる場合も読み直すこと」**（issue #113の要点。要約後の
  エージェントは「もう読んだ」という認識だけを持っているため）
- 読み直さないと何を踏み外すか（レビュー往復・`commit`スキル経由の強制・`HANDOFF.md`の進捗更新）
- 判定根拠（誤判定時に原因が追えるようにするため）

### 2. `build_work_context` から呼び出す

- 第1引数でブランチ名を受け取る（`local branch="${1:-}"`）。
- 既存の `work_files` を判定材料として再利用する（`get_branch_work_files` の呼び出しは増やさない）。
- issue番号は `get_issue_number_from_branch "$branch" 2>/dev/null || true` で取る
  （`set -e` 配下で倒れないようにする。取れなければ空文字列）。
- 指示文は**組み立ての最後**に足す（作業ファイル行 → HANDOFF抜粋 → 指示文の順）。
- 呼び出し元2箇所（MCP経路の `build_context` 内・CLI経路の末尾）は `"$branch"` を渡すだけ。

### 3. 単体テストを追加する

`.claude/scripts/test/test_session_start.sh` へ、既存の `assert_*` を使って次を検証する。

- `issue_mr_flow_branch_reason`
  - 両方空 → 終了コード1・出力なし（**対象外で不要な指示を注入しない**という受け入れ条件に対応）
  - issue番号のみ → 根拠に命名規則とissue番号が入り、作業ファイルの根拠は入らない
  - 作業ファイルのみ → その逆
  - 両方 → 両方の根拠が入る
  - 改行だけの入力が「非空」として扱われること（`-n` の仕様の固定）
- `format_skill_reload_instruction`
  - 見出し行で始まる／SKILL.mdのパスを含む／判定根拠が埋め込まれる／
    「既に読んでいる場合も読み直すこと」を含む／`compact` に触れる
  - 指示文が1000バイト未満（しきい値8000に対して十分小さいことの固定）

日本語を含む比較は `${var:0:N}` を使わず `head -1` と部分一致で行う
（`.claude/rules/shell-script-style.md`「テスト」）。

### 4. 結合確認（合成フィクスチャだけで終わらせない）

使い捨てのgitリポジトリへ `.claude/` `.mrworkflow.json` `HANDOFF.md` を複製し、hook本体を
`CLAUDE_PROJECT_DIR` 付きで直接実行して `additionalContext` を目視する。確認する4状態:

1. `main` ブランチ … 何も注入されない（既存挙動）
2. `feature-113-<slug>` … 指示あり（根拠＝命名規則一致）
3. 命名規則外・作業ファイル無し … 指示なし（既存挙動を壊さない）
4. 命名規則外・`plans/` に個別計画あり … 指示あり（根拠＝作業ファイル）

### 5. 全単体テストの実行

`.claude/scripts/test/test_*.sh` を全て流し、`failures=0` を確認する。

## やらないこと

- `.claude/settings.json` の matcher は変更しない（注入の**内容**だけを増やす変更のため）。
- 起動要因（startup/resume/clear/compact）による分岐は持たせない（DDR 0032の方針）。
- SKILL.mdの中身・要約は注入しない（指示文だけを注入する）。
