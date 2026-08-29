---
title: 【設計反映】Diffviewリンク出し分けのspec/DDR反映
type: plan
description: issue #205 フェーズ4の個別反映計画。get_mr_diff_url の4引数化・resolve_mr_number_for_head 新設・複数候補SHA対応をspec「提供関数」表・未決定事項へ反映し、新規DDRを起票する
tags: [plan, phase4, issue-mr-flow, spec, ddr]
keywords: [get_mr_diff_url, resolve_mr_number_for_head, refs/pull, 提供関数表, 未決定事項, DDR, mcp-fallback]
---

# 【設計反映】Diffviewリンク出し分けのspec/DDR反映

対象: issue #205「defaultブランチとの差分リンクをPR/MRのDiffviewへ変更する」フェーズ4（反映）。
全体作業計画: `wip/plans/diffview-link-switchover.md`
実装結果: `wip/reports/20260824_diffview-link-switchover_実装結果.md`
調査結果: `wip/reports/20260824_diffview-link-switchover_調査結果.md`

## 前提（合意状況）

上位計画（全体作業計画）はflow-id 1-4でこのセッションが作成し、人間の合意（flow-id 1-5）は
未取得（非対話的実行環境のため）。フェーズ2・3はいずれも人間レビューの代わりに敵対的レビュー
（各フェーズ2回ずつ）を実行し、指摘へ対応・返信済み。本計画（フェーズ4）も同じ扱いとし、
作成直後に敵対的レビューを1回実行する（計画時レビュー）。

## 反映対象（洗い出し）

実装結果・調査結果の両レポートから、spec/DDR側で更新が必要な箇所を洗い出す。

### 1. `.claude/docs/spec/issue-mr-workflow.md`「提供関数」表

| 行 | 現状 | 変更内容 |
|---|---|---|
| `get_mr_diff_url <repoUrl> <baseBranch> <headBranch>` | 3引数、常にCompareを返すと読める記述 | シグネチャを4引数（`[<mrUrl>]`）へ。説明へ「`mrUrl`が非空ならDiffview（GitHubは`/files`、GitLabは`/diffs`）、空ならCompare」を追記。issue #205を追記 |
| （新規行） `resolve_mr_number_for_head <sha>...` | 存在しない | 新設。「候補SHAのいずれかに対応するMR/PR番号を、CLIを使わずgit ls-remoteだけで解決する（GitHubのみ。GitLabは空を返す）。解決できなければ空＋終了コード0（呼び出し側はCompareへ縮退）」。GitHub列は`git ls-remote origin 'refs/pull/*/head'`、GitLab列は「未対応（空を返す）」 |

`get_mr_diff_since_url` / `get_diff_anchor_base_url` / `get_diff_anchor_url` は変更しない
（調査結果の決定4「`get_mr_diff_since_url`は変更しない」のとおり）。

### 2. `.claude/docs/spec/issue-mr-workflow.md`「未決定事項・懸念点」

- **（issue #13）`get_mr_diff_url`/`get_mr_diff_since_url`のURL形式: GitHub側のみブラウザ未検証**
  の項目を更新する。現状の記述はCompare方式を前提に「PR個別のサブタブ形式より安定していると
  考えられる」と書いているが、本issueでDiffview（`/files`）へ出し分ける経路が追加されたため、
  現状に合わせて書き直す。**「ブラウザ未検証」自体は本issueでも解消していない**（この実行環境
  ではブラウザ目視ができないため）ので、未決定事項としては残しつつ、Diffview経路の追加とissue
  #205を追記する形にする（削除はしない。DDRへの記録で判断の変遷を残す方針は調査結果flow-id
  2-6の回答のとおり）。
- 新規の未決定事項として、次の3点を追加する（実装結果「測っていないこと」・「追記」節より）。
  1. `git ls-remote` 呼び出しのgit bash（Windows）実機でのコスト・認証プロンプト対策の実効性が
     未検証。
  2. CLI経路（`get_vcs_access_mode`が`cli`）での`resolve_mr_number_for_head`呼び出しブロックの
     素通り（`[ -z "$mr_url" ]`）は、コードを読んだ上での判断であり実機確認ではない。
  3. `wip/state/review-links/<branch>.txt`のブランチ名重複衝突（`safe_branch`の記号潰し）による
     `prev_sha`混入リスクは、`git cat-file -e`検証で緩和したが、別ブランチが同じ状態ファイルを
     共有すること自体は解消していない（敵対的レビュー2回目 指摘2への対応で判明）。

### 3. 新規DDR `i0205-01`

意思決定の骨子（DDRとして残す価値がある「検討したが却下した案」を含む）:

1. **`get_mr_diff_url`を4引数の純粋関数に保つ設計**（第4引数`mrUrl`の有無で出し分け）。
   却下案: `get_mr_diff_url`の内部でMR URL解決まで行う設計 → 純粋関数でなくなり単体テストが
   困難になるため却下。
2. **MCP経路（`gh`/`glab`CLI不在）でのPR番号解決に`git ls-remote origin 'refs/pull/*/head'`を
   採用**。却下案: 案B（`wip/state/`の状態ファイルにPR番号を保存）→ silent staleness
   （黙って古い値を返す）を理由に却下。案C（`HANDOFF.md`のヘッダから読む）→ 表記依存で壊れやすい
   ことを理由に却下。GitLabは`refs/merge-requests/*/head`の実機検証ができず対象外。
3. **一致判定は「一致したPR番号の種類数がちょうど1のときだけ採用」**（`refs/pull/*/head`には
   マージ済み・クローズ済みPRのrefも永続的に残るため、「番号が最大のもの」では誤ったPRを
   選びうる。フェーズ2レビュー2回目で設計変更）。
4. **複数候補SHA（今回push・前回push）を解決関数へ渡す設計**（フェーズ3の実push検証で、
   `refs/pull/<n>/head`の更新がpushに対して遅れることを実際に観測したため追加。この経緯自体を
   DDRの「決定の背景」として記録する価値がある）。
5. **差分アンカーの土台（`compare_url`）とDiffviewリンク（`diff_url`）を分離**（GitHubの差分
   アンカーはCompareページ上でのみ実機確認済みで、PRの`/files`上での動作は未検証のため、土台を
   移すと後退するリスクがあった）。

### 4. `references/mcp-fallback.md`への追記

`.claude/skills/issue-mr-flow/references/mcp-fallback.md`の`gh`/`glab` CLI不在時のMCPフォール
バック節へ、次の2点を追記する。

- **hookのCLI/MCP経路ごとの挙動差**: `post-push-compact-prompt.sh`のレビュー依頼メッセージが、
  CLI経路では`get_mr_for_branch`が直接MR URLを返すのに対し、MCP経路では`mr_url`が空のときのみ
  `resolve_mr_number_for_head`（`git ls-remote`）を追加で試みる、という表を追加する。
- **MCPツールのbody引数における`*`喪失の既知の落とし穴**（フェーズ2で観測）を、
  `add_comment_to_pending_review`等のbodyへ`*`（強調記号・箇条書き）を渡す際の注意として記録
  する。**ただしこれはGit管理下のファイルへは影響しない**（今回の敵対的レビュー対応で確認した
  誤解の訂正も兼ねる）ことを明記する。

## 巻き添えの確認

- spec本文の「提供関数」表は、`get_mr_diff_url`の行**1行だけ**を書き換える（前後の行の書式・
  列幅崩れが起きないよう、既存の行を1行単位でコピーしてから編集する）。
- 「未決定事項・懸念点」の該当項目は、issue #13の項目として**既存の箇条書き構造を保ったまま**
  文言を差し替える（削除・新規追加ではなく更新であることを、diffで確認する）。
- DDR `i0205-01`のファイル名・frontmatterの`title`・本文冒頭の見出しの3箇所は
  `.claude/rules/markdown-frontmatter.md`の書式（`i0205-01. <タイトル>`）に揃える。

## 完了条件

1. spec「提供関数」表の`get_mr_diff_url`行が4引数版に、`resolve_mr_number_for_head`の新規行が
   追加されている。
2. 「未決定事項・懸念点」のissue #13項目が更新され、新規3項目が追加されている。
3. DDR `i0205-01`が作成され、`bash .claude/scripts/src/generate-ddr-list.sh`実行後に
   `.claude/docs/README.md`のDDR一覧へ反映されている。
4. `references/mcp-fallback.md`へ、hookのCLI/MCP経路ごとの挙動差（上記「反映対象」節の4）を
   追記する。
5. `bash .claude/scripts/src/check-doc-references.sh`を実行し、参照切れが無いことを確認する。
6. 既存の単体テスト21ファイルが全件 `failures=0` のまま（spec/DDR/rules変更はロジックに影響
   しないため、原則ノーオペだが念のため確認する）。
