---
title: 【設計反映】統括レポートの仕様とDDRを記録する
type: plan
description: issue #111 の個別反映計画（設計反映）。specへ統括レポートの仕様を、DDRへ添付を任意層に置く判断を記録する。
tags: [plan, design-reflection, workflow, ddr]
keywords: [設計反映, spec, DDR, i0111-01, 3層フォールバック, 未ドキュメントAPI, 影響範囲]
---

# 個別反映計画: 統括レポートの仕様とDDRを記録する（issue #111）

全体作業計画: `plans/mellow-drifting-lantern.md`

**`【AIアセット反映】` とは分ける**（`.claude/skills/issue-mr-flow/SKILL.md`「種別を複数併記する
場合／分ける場合」）。ただし今回のAIアセット側の変更（`.claude/rules/` の番号繰り下げ）は
フェーズ3の実装と不可分だったため既に済んでおり、フェーズ4で新たに行うのは設計反映のみである。

## 反映対象の洗い出し（flow-id 4-1）

| 反映先 | 内容 | 要否 |
|---|---|---|
| `.claude/docs/ddr/i0111-01-統括レポートの添付は任意層に置きフローを止めない.md` | 3層フォールバック構造の決定と却下案4件 | **要** |
| `.claude/docs/spec/issue-mr-workflow.md` | 統括レポートの仕様（節の新設）＋提供関数表へ `upload_attachment`＋MCP対応表＋影響範囲への新規エントリ | **要** |
| `.claude/docs/README.md` | DDR一覧（`generate-ddr-list.sh` で再生成） | **要** |
| `.claude/skills/apply-mr-workflow-to-project/assets/` | 配布用のミラー（`sync-assets.sh` で再生成） | **要** |
| `.claude/rules/` 各ファイル | 番号繰り下げ | **済**（フェーズ3で実施） |
| `.claude/VERSION` | 配布物の版 | **要**（フローの拡張なので MINOR。増分はユーザーが決める） |

## 方針

### DDR（`i0111-01`）

- 識別子は `main` から取り込んだ新方式（issue #133）に従い `i0111-01`。
- 記録するのは **「添付を任意層に置く」判断**（issueの受け入れ条件）と、その根拠になった実測。
- 却下案は4つ書く: (A) 添付を必須にする、(B) GitLabだけ対応する、(C) レポートを `main` へ残す、
  (D) MR descriptionへ書きコメントを投稿しない。加えて (E) 全種のコメントへラベルを付け直す。
- **issue #54 が「最終統括レポートは作らない」と決めた件との関係を明記する**（#54 の判断は
  テンプレートの適用範囲についてのもので、本issueはそれを独立に扱い直した）。

### spec（`issue-mr-workflow.md`）

- **`### 最終統括レポートとPR/MRへの反映（issue #111）`** を、`### マージ前の関連issue通知（issue #86）`
  の直後へ新設する（フェーズ5の並び順に合わせる）。
- 書くのは**決めごとの表**であり、手順は書かない（手順の正は `SKILL.md`。二重管理を避ける）。
- **未ドキュメントAPIへの依存範囲が層3に限られること**を明記する（issueの受け入れ条件）。
- 提供関数表（89行目〜）へ `upload_attachment` の行を足す。
- `### `gh`/`glab` CLI不在時のMCPフォールバック経路` に「代替が無い唯一の関数」であることを足す。
- **`## 影響範囲` へ新規エントリを追記する。既存エントリは書き換えない**（point-in-time の記録）。

## やらないこと

- **既存の `## 影響範囲` エントリの番号繰り下げ**（過去の記録の破壊になる）。
- **`.claude/VERSION` の増分をAIが独断で決めること**（`distribution-assets.md`。提案に留める）。

## 検証手順

1. `bash .claude/scripts/src/generate-ddr-list.sh` を実行し、`.claude/docs/README.md` の差分を
   同じコミットへ含める。`test_generate_ddr_list.sh` が `failures=0` になること。
2. `bash .claude/scripts/src/extract-frontmatter.sh .` でインデックスが更新できること
   （新設DDRのfrontmatterが正しく読めることの確認を兼ねる）。
3. `bash .claude/skills/apply-mr-workflow-to-project/scripts/sync-assets.sh` を実行し、
   配布ミラーが本家と一致すること。`test_install_to_project.sh` が `failures=0` になること。
4. `git diff origin/main...HEAD -- .claude/docs/ddr/` の削除行が、`note` を足した3件の
   frontmatter行だけであること（DDR本文を書き換えていないことの確認）。
