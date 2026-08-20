---
title: 【実装】【テスト】統括レポートのステップ追加とupload_attachment新設
type: plan
description: issue #111 の個別作業計画。フェーズ5へ新5-3を挿入し、Provider.shへupload_attachmentを追加する。
tags: [plan, implementation, workflow, attachment]
keywords: [flow-id, 5-3, 繰り下げ, upload_attachment, 3層フォールバック, サマリコメント, 単体テスト]
---

# 個別作業計画: 統括レポートのステップ追加と `upload_attachment` 新設（issue #111）

全体作業計画: `plans/mellow-drifting-lantern.md`
前提となる調査結果: `reports/20260821_mellow-drifting-lantern_調査.md`

**実装とテストを1ファイルへ併記する**（`.claude/skills/issue-mr-flow/SKILL.md`「種別を複数併記
する場合／分ける場合」）。追加する純粋関数のテストは実装と同時に書き、まとめて1回で合意を取る
のが自然な粒度であるため。

## 目的

タスク完了時の統括レポートを、**ファイルが消えてもPR/MR上に残る形**で反映できるようにする。
反映は3層のフォールバック構造とし、**層3（添付）が壊れてもフローが回る**ことを設計で保証する。

## 変更対象と方針

### 1. フェーズ5へ新 5-3 を挿入する

| flow-id | 変更後 |
|---|---|
| 5-1 | コンフリクト解消（**変更なし**） |
| 5-2 | 関連issue通知（**変更なし**） |
| **5-3** | **最終統括レポートの作成とPR/MRへの反映（新設）** |
| 5-4 | 片付け（旧 5-3） |
| 5-5 | commit・push・Draft解除（旧 5-4） |
| 5-6 | マージ（旧 5-5） |

- **新 5-3 は「作成 → `commit` スキル経由でcommit → push → サマリコメント投稿 →（任意）添付」を
  1ステップに含む複合ステップにする。** 統括レポートは 5-4（片付け）で削除されるため、
  **同じステップ内でコミットまで済ませないと、ブランチのコミット履歴にすら残らない**
  （層1「レビュアーはブランチをcheckoutすれば見られる」が成立しなくなる）。既存の 5-5 も
  「commitしpushしDraft解除する」という複合ステップであり、粒度の前例がある。
- 全体フローの総ステップ数を **41 → 42** へ更新する。

### 2. 番号の繰り下げ（68行）

調査1の分類表に従い、**群Aの68行のみ**を書き換える。凍結対象（spec の過去changelog 9行・
DDR本文 9行）には触れない。`i0117-01` `i0113-01` には frontmatter の `note` を足す。

**一括 `sed` を全体へ当てない。** `.claude/docs/spec/issue-mr-workflow.md` は
`## 影響範囲`（1624行目）より前の4箇所のみを個別に直す。

### 3. `Provider.sh` へ `upload_attachment` を新設する

```
upload_attachment <file> [<content_type>]
  成功: {"url":"...","markdown":"...","provider":"github|gitlab"} をstdoutへ / 終了コード0
  失敗: stderrへ理由 / 終了コード非0（呼び出し側はスキップする）
```

- **`require_vcs_cli` を先頭で通す。** 調査2のとおり、この機構の主要な作業環境（MCP経路）には
  添付に相当するツールが存在しない。ネットワークへ出る前にここで落ちるのが正しい振る舞いである。
- **GitHub**: 未ドキュメントの内部エンドポイント `uploads.github.com/user-attachments/assets` を
  使う。**未ドキュメントである旨・予告なく壊れる前提であることを関数コメントへ明記する。**
- **GitLab**: 公式APIの `POST /projects/:id/uploads`。レスポンスの `markdown` をそのまま返す。
  **実機未検証である旨をコメントへ明記する**（issue #127 の担当）。
- content-typeの推定は**純粋関数**（`content_type_from_path_to_reply`）へ切り出し、単体テストを書く。
  拡張子からの推定はプロバイダに依存しないうえ、副作用が無く単体テストできる唯一の部分であるため。
- `mcp_tool_hint` へ `upload_attachment` の分岐を足し、「**MCP経路に対応ツールは無い。層3は
  スキップしてよい**」と名指しで返す（他の関数と違い、代替を案内できないことを明示する）。

### 4. サマリコメントの1行目

`Claude Codeより（最終統括レポート）:` とする。既存の `Claude Codeより（敵対的レビュー）:` と
同じ形で、**既存3種のコメントは1件も書き換えない**（調査3）。
`SKILL.md` へ通常コメントの**種別一覧表（4種）**を置く。

## やらないこと

- **`reports.template.html` の新設**（issue #54 の担当）。HTMLは「テンプレートがあれば使い、
  無ければ手書き」と手順に書くにとどめる。
- **GitLab添付の実機検証**（実機なし）。
- **`i0041-01` `i0086-01` の陳腐化した flow-id 参照の巻き取り**（issue #112 由来で今回とは無関係）。
- **`upload_attachment` の実アップロード試行**（この環境では `require_vcs_cli` で落ちる）。

## 検証手順

1. `bash -n` で全変更スクリプトの構文チェック。
2. `.claude/scripts/test/` の**全テストスクリプト**を実行し `failures=0` を確認する
   （番号繰り下げでテストの固定文字列が壊れていないことの確認を兼ねる）。
3. `content_type_from_path_to_reply` のテストを新規追加し、拡張子あり・無し・大文字・
   未知の拡張子・ドットを含むパスを網羅する。
4. `upload_attachment` をこの環境（MCP経路）で呼び、**`require_vcs_cli` により非0で終える**
   ことと、stderrに「層3はスキップしてよい」という案内が出ることを確認する。
5. 繰り下げの検証: `git diff <分岐点SHA> -- .claude/docs/ddr/` の**削除行がゼロ**であること
   （DDR本文を書き換えていないことの確認。frontmatterの `note` 追加は追加行のみ）。
6. **`5-N` という数字列を、changelog とDDR本文を除いて全件列挙し、1件ずつ現在の意味と突き合わせる。**
   `grep -rn 'flow-id 5-[1-6]'` を数えるだけでは、(a) `flow-id` の語を伴わない裸の番号
   （見出し・frontmatterの `keywords`・コミット地点の列挙）と、(b) 元から誤っていた番号を
   構造的に検出できない（issue #111 の敵対的レビュー指摘）。
