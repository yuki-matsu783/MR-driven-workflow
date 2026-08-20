---
title: issue #111 最終統括レポート（統括レポートのステップ新設とupload_attachment）
type: report
description: issue #111（最終統括レポートの作成とPR/MRへの反映）のブランチ全体を1枚に統括し、変更内容・設計判断・検証結果・spec/DDRへの反映先・残課題をまとめた最終統括レポート
tags: [workflow, report, issue-mr-flow, attachment]
keywords: [最終統括レポート, flow-id 5-3, 3層フォールバック, upload_attachment, 未ドキュメントAPI, 番号繰り下げ, 敵対的レビュー, サマリコメント, issue111, PR144]
---

# issue #111 最終統括レポート

- **issue**: [#111](https://github.com/yuki-matsu783/MR-driven-workflow/issues/111) 最終統括レポートを作成し、PR/MRへサマリコメントとして反映する（添付は任意ステップ）
- **PR**: [#144](https://github.com/yuki-matsu783/MR-driven-workflow/pull/144)
- **ブランチ**: `claude/final-report-pr-summary-k822hz`
- **全体作業計画**: `plans/mellow-drifting-lantern.md`

**このレポート自身が、今回新設したステップ（flow-id 5-3）の最初の適用例である。**

## 何を変えたか

### 1. フェーズ5へ新しいステップを追加した（全41 → 42ステップ）

タスク完了時に、そのブランチで何をやったかを1枚にまとめた**最終統括レポート**を作成し、
PR/MR上へ残すステップを新設した。

| flow-id | 内容 | 変更 |
|---|---|---|
| 5-1 | コンフリクト解消 | 据え置き |
| 5-2 | 関連issue通知 | 据え置き |
| **5-3** | **最終統括レポートの作成とPR/MRへの反映** | **新設** |
| 5-4 | 片付け | 旧 5-3 から繰り下げ |
| 5-5 | commit・push・Draft解除 | 旧 5-4 から繰り下げ |
| 5-6 | マージ | 旧 5-5 から繰り下げ |

**このステップ自身がcommit・pushまでを含む複合ステップである。** 作るだけで片付け（5-4）へ進むと、
作成と削除が同じ作業ツリー上で相殺され、**ブランチのコミット履歴にすら残らない**。

### 2. 反映を3層のフォールバック構造にした

| 層 | 何をするか | 必須か | 依存する外部API |
|---|---|---|---|
| 層1 | レポート本体を `reports/` に載せ、`commit` スキル経由でリモートへ反映する | **必須** | 無し（git操作のみ） |
| 層2 | サマリをMarkdownでPR/MRへコメント投稿する（`add_mr_comment`） | **必須** | **公式API**（GitHub/GitLab両対応） |
| 層3 | HTMLを添付する（`upload_attachment`） | **任意** | GitHub: **未ドキュメントAPI** / GitLab: 公式API（実機未検証） |

**層の番号はフォールバックの優先順位であって、実行順ではない。実行順は 層1 → 層3 → 層2 である。**
`Provider.sh` には投稿済みコメントを編集する関数が無いため、添付リンクを本文へ入れて1回で投稿するには、
層3を層2より先に実行する必要がある（この点は敵対的レビューの指摘で発覚し、修正した）。

### 3. `Provider.sh` へ `upload_attachment` を新設した

- `github_upload_attachment`: `uploads.github.com/user-attachments/assets`（**未ドキュメントの内部
  エンドポイント**）を `gh api` 経由で叩く。警告をコード・仕様の両方に明記した。
- `gitlab_upload_attachment`: 公式API（`POST /projects/:id/uploads`）。実機未検証である旨を明記。
- `content_type_from_path_to_reply`: 拡張子からContent-Typeを推定する純粋関数（`REPLY` へ返す）。
- `mcp_tool_hint`: **唯一「代替が無い」分岐**として「層3はスキップしてよい」と名指しで返す。

**失敗は正常系のひとつとして設計してある。** 非0で終え、呼び出し側は警告のみ出してフローを続ける。

### 4. サマリコメントの1行目を種別ラベル付きにした

`Claude Codeより（最終統括レポート）:` とした。`add_mr_comment` で投稿される通常コメントは
本issueの追加で**4種類**になったが、**既存3種の1行目は1件も書き換えていない**。

### 5. 番号繰り下げを68行へ適用した

`.claude/rules/` `.claude/docs/spec/` `.claude/scripts/src/` `.claude/skills/` `index.md` にまたがる
flow-id 参照を繰り下げた。**DDR本文（9行）とspecの過去changelog（9行）は凍結し、一切触っていない。**

## なぜそうしたか

### 採用: 添付を任意の層3へ閉じ込める

issueが挙げた「HTMLファイルの添付」は、**GitHubに公式APIが無い**。`gh` にも添付用フラグが無く、
要望は2020年から複数回上がって「プラットフォームAPI待ち」でクローズされ続けている（cli/cli#12960）。

さらにフェーズ2の調査で、**この機構の主要な作業環境では層3が実行できない**ことを実測した。

| 確認内容 | 結果 |
|---|---|
| `gh` / `glab` CLI の有無 | **どちらも無し** |
| `GH_TOKEN` / `GITHUB_TOKEN` | 存在するが**14文字**（GitHubのトークン形式に一致しない） |
| MCPの添付ツール | **該当なし** |
| `uploads.github.com` への到達性 | **403**（`api.github.com` は200） |

**403の発信元（プロキシかGitHubか）は切り分けられていない**ため、結論は「**この環境では動かない**」に
限定してある。それでも設計上の含意は変わらない。将来壊れるという想定以前に、**現時点で既に動かない
環境が存在し、しかもそれが主要な作業環境である**。

### 却下した案（詳細: [DDR i0111-01](../.claude/docs/ddr/i0111-01-統括レポートの添付は任意層に置きフローを止めない.md)）

| 案 | 却下理由 |
|---|---|
| A. 添付を必須にする | 主要な作業環境で動かず、フェーズ5を完了できなくなる |
| B. GitLabだけ対応する | このリポジトリのremoteはGitHubであり、主対象で機能しない |
| C. 統括レポートを `main` へ残す | `reports/` のライフサイクル設計と衝突し、ファイルが増え続ける |
| D. MR descriptionへ書く | descriptionは `describe` が**上書き**するため統括が消える |
| E. 全種のコメントへラベルを付け直す | 波及が大きい一方、得られるのは表記の統一だけ |

### 挿入位置を「新 5-3」にした理由

issue本文は「flow-id 5-1（片付け）より前に置く」と書いているが、これは**起票当時の番号**である。
issue #112 の並べ替え（DDR i0112-01）により片付けは既に 5-3 へ動いていた。「片付けより前」という
**意図**を満たす位置として新 5-3 を選んだ（ユーザー承認済み）。

## 検証結果

### 単体テスト

`.claude/scripts/test/` の**全14スクリプトが `failures=0`**。

```
test_adversarial_review_count.sh   passed=22   failures=0
test_check_base_conflicts.sh       passed=31   failures=0
test_check_base_sync.sh            passed=55   failures=0
test_cleanup_task.sh               passed=53   failures=0
test_collect_review_points.sh      passed=17   failures=0
test_extract_frontmatter.sh        passed=32   failures=0
test_generate_ddr_list.sh          passed=52   failures=0
test_install_to_project.sh         passed=22   failures=0
test_post_issue_create_notice.sh   passed=14   failures=0
test_search_frontmatter.sh         passed=114  failures=0
test_session_start.sh              passed=51   failures=0
test_update_handoff_progress.sh    passed=45   failures=0
test_usage_tracking.sh             passed=90   failures=0
test_vcs_provider.sh               passed=192  failures=0
--------------------------------------------------------
TOTAL                              passed=790  failures=0
```

`test_vcs_provider.sh` は 178 → **192件**（Content-Type推定8ケース・`upload_attachment` の早期returnを追加）。

### その他の確認

| 確認 | 結果 |
|---|---|
| 全 `.sh` の `bash -n` | 通過 |
| `check-base-conflicts.sh` | `hasConflict: false` |
| DDR本文の不変性 | `git diff --numstat -- .claude/docs/ddr/` が frontmatter の `note` 追加のみであることを確認 |
| `upload_attachment` の実環境動作 | MCP経路で `require_vcs_cli` により非0終了し、stderrへ「層3はスキップしてよい」旨が出ることを確認 |
| DDR一覧 | `generate-ddr-list.sh` で再生成済み |

### 敵対的レビュー（1回実施・指摘14件／投稿11件・**全件対応済み**）

| 重大度 | 指摘 | 対応 |
|---|---|---|
| major | **層の実行順が矛盾**（層2で投稿後に層3を添付する手順なのに、添付リンクをその本文へ埋めると書いていた。投稿済みコメントを編集する関数は存在しない） | 実行順を 層1→層3→層2 へ改め、専用の節で明文化 |
| major | **トークンがargvへ露出**（`curl -H "Authorization: Bearer $token"` は `ps` から平文で読める。加えてDDR i0014-01/i0034-01 の「curlへフォールバックしない」に抵触） | `curl` を廃し `gh api` へ全面差し替え |
| major | `glab api -F "file=@path"` が multipart にならない可能性（「未検証」ラベルが未検討の設計疑義を隠していた） | 疑義を具体的に明記し、issue #127 へ引き渡し |
| major | `add_issue_comment` の説明が 5-4 になっていた（**元から誤り**で、一括置換が誤りを移動させただけ） | 5-2 へ修正 |
| major | commit実施ステップの列挙に新 5-3 が抜けていた | `commit/SKILL.md` の frontmatter `description` を含む4箇所を修正 |
| minor ×6 | 番号の自己矛盾・`keywords` の陳腐化・タイムアウト無し・失敗時にレスポンス本文を破棄・GitLab側 `url` が相対パス | すべて修正 |

**指摘を受けて全 `5-N` 参照227件の棚卸しを実施し、今回の変更とは無関係に issue #112 由来で
陳腐化していた番号を3箇所発見・修正した**（`docs-workflow.md` ×2、`check-base-sync.sh`／`.md`）。
`grep 'flow-id 5-N'` では「裸の番号」と「元から間違っていた番号」を検知できないためで、
**この検証手順そのものを個別計画とspecへ記録した**。

## spec・DDRへの反映先

| ファイル | 何を書いたか |
|---|---|
| `.claude/skills/issue-mr-flow/SKILL.md` | **手順の正**。新 5-3 の節（3層の表・実行順・呼び出し方・サマリ本文テンプレート・通常コメント4種・CLI不在時の読み替え）、フロー表への行追加と繰り下げ |
| `.claude/docs/spec/issue-mr-workflow.md` | 仕様の正。挿入位置・3層構造・実測結果・コメント種別・`upload_attachment` の関数表・「代替が無い唯一の関数」・検証手順の教訓 |
| `.claude/docs/ddr/i0111-01-…md` | **添付を任意層に置きフローを止めない**という判断と、却下した5案 |
| `.claude/rules/docs-workflow.md` 他 | flow-id 番号の繰り下げ（68行） |
| `.claude/docs/ddr/i0028-01 / i0113-01 / i0117-01` | frontmatter の `note` のみ追加（**本文は不変**） |

## 残課題

| 項目 | 状態 |
|---|---|
| **受け入れ条件「htmlが `reports.template.html` を使っている」** | **部分達成**。依存する issue #54 が未完了でテンプレート実体が無いため、参照だけ書き手書きへフォールバックする形にした（ユーザー承認済み）。テンプレート投入時に土台を移す |
| **GitLab添付の multipart 形式の実機検証** | 未実施。issue #127（GitLab実機検証）の担当として引き渡す |
| **403の発信元の切り分け** | 未実施。レスポンスヘッダを取得するコマンドが実行環境の権限判定でブロックされたため、結論を「この環境では動かない」に限定した |
| **`.claude/VERSION` の増分** | 未実施。現在 `0.1.1`。フローの拡張なので **MINOR** が目安だが、`.claude/docs/spec/distribution-assets.md` により**AIが独断で上げない**（ユーザー判断待ち） |
| `i0041-01` / `i0086-01` の flow-id 参照 | issue #112 由来で既に陳腐化しているが、今回の変更が原因ではないため触っていない（調査レポートに記録済み） |
