---
title: 最終統括レポートを作成しPR/MRへサマリコメントとして反映する（issue #111）
type: plan
description: issue #111 の全体作業計画。フェーズ5へ統括レポートのステップを新設し、Provider.shへ添付関数を追加する。
tags: [plan, workflow, report, issue-mr-flow]
keywords: [統括レポート, サマリコメント, 添付, upload_attachment, flow-id, フェーズ5, フォールバック, 未ドキュメントAPI]
---

# 全体作業計画: 最終統括レポートとPR/MRサマリコメント（issue #111）

対象issue: [#111](https://github.com/yuki-matsu783/MR-driven-workflow/issues/111)

## 背景・目的

`plans/` `worklog/` `reports/` は片付け（現 flow-id 5-3）で削除され、squash mergeにより `main`
にも残らない。ブランチ全体を統括した成果がどこにも残らず、「このMRで何をどう検証したか」を
後から一望できない。**統括レポートをPR/MR上のコメントとして残し、ファイルが消えても追跡できる
ようにする**のが本issueの目的である。

## 着手時点で確定した判断（ユーザー承認済み）

| 論点 | 判断 | 理由 |
|---|---|---|
| ベースブランチの遅れ | `main` を merge して取り込む | DDR識別子が連番から `i<issue番号>-<枝番2桁>` へ全面改名された（issue #133 / PR #137）。取り込まずに旧連番でDDRを作ると、マージ時に必ず手戻りになる |
| 新ステップの挿入位置 | **新 5-3** として挿入し、片付け以降を繰り下げる | issue #111 本文の「flow-id 5-1（片付け）より前」は起票当時の番号。issue #112 でフェーズ5が並べ替えられ、片付けは現在 5-3。「片付けより前」を満たしつつ、5-1・5-2 の参照を無傷に保てる位置がここである |
| 統括レポートのHTML | `assets/reports.template.html` を**参照だけ**書き、無ければ手書きへフォールバック | 受け入れ条件が依存する issue #54 が未完了で、テンプレート実体が存在しない。テンプレートの新設は #54 の担当であり、先取りすると #54 のPRとコンフリクトする |

## フェーズ2〈調査〉

**実施する。** 本issueの中核が外部APIの実挙動（GitHubの未ドキュメント添付エンドポイント）に
依存しており、机上で決め切れないため。

- **調査1: フェーズ5の番号繰り下げが波及する範囲**。`flow-id 5-3` / `5-4` / `5-5` を参照する
  全ファイルを洗い出し、**書き換えてよいもの／書き換えてはいけないもの**（DDR本文・spec内の
  過去changelog）を分類する。`.claude/rules/docs-workflow.md` が禁じている「過去の記録の
  一括置換」を踏まないための下ごしらえである。
- **調査2: 添付APIの実現可能性**。GitHubの `uploads.github.com/user-attachments/assets` が
  この実行環境（`gh` CLI不在・MCP経路）で使えるのかを確認する。**使えない場合、それは
  「層3を任意にする」という設計判断の裏付けになる**ため、使えなかったこと自体が調査結果になる。
- **調査3: PR/MR通常コメントの種別識別**。issue #111 のコメントで指摘された「通常コメントが
  3種類になるので読み手が判別できる形が要る」への対応方針を、既存2種の実装から決める。

結果は `reports/日付_mellow-drifting-lantern_調査.md`（正文）と同名の `.html` に記録する。

## フェーズ3〈作業〉

**実施する。** 内訳は次の3つ。

1. **`Provider.sh` への `upload_attachment` 新設**。成功時は本文へ埋め込めるURL/markdownをJSONで
   返し、失敗時は非0で終える（呼び出し側がスキップできる）。GitHub実装には未ドキュメントAPIに
   依存する旨をコメントで明記する。GitLabは `projects/:id/uploads` の公式API。
2. **フローへのステップ追加**。`SKILL.md` の全体フロー表へ新 5-3 を追加し、5-3〜5-5 を
   5-4〜5-6 へ繰り下げる。統括レポートの手順（3層フォールバック）を専用の節として書く。
3. **波及箇所の追従**。調査1で「書き換えてよい」と分類したファイルのみを更新する。

`Provider.sh` の純粋ロジック（content-typeの判定等）には `.claude/scripts/test/` へ単体テストを
追加する。

## フェーズ4〈反映〉

**必ず通る。** 反映対象は flow-id 4-1 で洗い出す。現時点の見込みは次のとおり（確定ではない）。

- 設計反映: `.claude/docs/spec/issue-mr-workflow.md`（統括レポートの仕様）、新規DDR
  `i0111-01`（添付を任意層に置く判断）。DDRを追加したら `generate-ddr-list.sh` を実行する。
- AIアセット反映: `.claude/rules/docs-workflow.md`（ライフサイクル表）、
  `.claude/rules/directory-structure.md`、`.claude/rules/git-workflow.md`。

## やらないこと

- **`reports.template.html` の新設**（issue #54 の担当）。
- **GitLab添付の実機検証**（このリポジトリのremoteはGitHubで、GitLab実機がない。issue #127 が
  GitLab実機検証を担当している）。実装は公式APIの仕様に沿って書き、未検証である旨を明記する。
- **flow-id を増やさない代替案**（既存ステップへの統合）。issueが「ステップを追加する」ことを
  期待する動作として明示しているため。

## 進め方の制約

本ブランチは Claude Code on the web の非対話セッションで進めるため、人間担当のレビュー往復
（flow-id 2-3/2-8・3-3/3-8・4-3/4-8）を待てない。`.claude/rules/docs-workflow.md` の規定に従い、
該当ループ範囲の進捗記号は付けず、実施内容は `HANDOFF.md` の「やったこと」へ文章で残す。
その代わりに、各pushの後で**敵対的レビュー**（`adversarial-review` スキル）を実施する
（ユーザーからの明示的な指示による）。
