---
title: 最終統括レポート: 敵対的レビュー投稿件数選別のスクリプト化（issue #182）
type: report
description: issue #182（敵対的レビューの投稿件数選別を層単位ルールでスクリプト化する）のブランチ全体の統括。変更内容・検証結果・spec/DDRへの反映先・残課題をまとめる
tags: [adversarial-review, review, report, summary]
keywords: [敵対的レビュー, 投稿件数, 選別, 層単位, blocker, ハードシーリング, select-adversarial-findings, 統括レポート]
---

# 最終統括レポート: 敵対的レビュー投稿件数選別のスクリプト化（issue #182）

## サマリ（結論の一覧）

| # | 問い／やったこと | 結論 | 根拠の性質 |
|---|---|---|---|
| 1 | 敵対的レビューの投稿件数選別（blocker無制限・ハードシーリング20件）をスクリプト化できたか | できた（`.claude/scripts/src/select-adversarial-findings.sh`） | 実装の確認 |
| 2 | 選別規則（層単位追加・10件しきい値・20件ハードシーリング・層内タイブレーク）は仕様どおり動くか | 動く | 単体テスト（`passed=34 failures=0`） |
| 3 | フェーズ3の敵対的レビュー（自律実行）で見つかった指摘は対応済みか | 13件全件対応済み（9件修正・4件は報告のみで確認済み対応） | 実測（PRへの投稿・返信・再テスト） |
| 4 | ドキュメント（SKILL.md/spec/DDR）は最新の実装と一致しているか | 一致（誤記述4箇所を敵対的レビューで発見・修正） | ドキュメントの読解＋実装との突き合わせ |
| 5 | defaultブランチ（main）との統合は完了したか | 完了（コンフリクトはDDR一覧生成物のみ、再生成で解消） | 実測（`check-base-conflicts.sh`が`hasConflict: false`） |
| 6 | `.gemini/`は`.claude/`と同期しているか | 同期済み | 実測（`sync-gemini-assets.sh --check`が終了コード0） |

## 実施条件（測った対象・環境）

- 実行環境: Claude Code on the web（`gh`/`glab` CLI不在、GitHub MCPで代替）
- 対象: `yuki-matsu783/MR-driven-workflow`、ブランチ`claude/adversarial-review-script-2sba3d`、PR #183
- 実施日: 2026-08-23

## 実施した内容と結果

### 1. 選別スクリプトの実装と単体テスト

`.claude/scripts/src/select-adversarial-findings.sh`を新規実装した。findings JSONを受け取り、
単一のjq呼び出し（`reduce`による層の逐次処理）でblocker無制限・major→minorの層単位追加
（累計10件しきい値）・ハードシーリング20件・層内切り捨ての優先順位（確度降順→パス昇順→
行番号昇順）を実現する。出力は`{"posted":{"findings":[...]},"reported":{"findings":[...]}}`。

単体テスト（`test_select_adversarial_findings.sh`）は最終的に34アサーション、
`passed=34 failures=0`。境界ケース（ちょうど10件・ちょうど20件・blockerが20件超・
blockerがハードシーリングの枠を消費する境界・確度優先のタイブレーク・行番号タイブレーク・
main関数の入力検証5パターン）を網羅している。

### 2. ドキュメント反映

`adversarial-review/SKILL.md`手順6・`.claude/docs/spec/adversarial-review.md`・
新設DDR（`.claude/docs/ddr/i0182-01-...md`）を更新し、旧「1回あたりの投稿上限10件」という
記述を層単位ルールへ置き換えた。既存DDR`i0077-03`の決定6が本issueで無効化されたことを
frontmatterの`note`で追記し、`generate-ddr-list.sh`でDDR一覧を再生成した。

### 3. 敵対的レビュー実施と対応（フェーズ3・1回目）

`adversarial-reviewer`サブエージェントへdiff全体を渡し独立レビューを実施。13件のfindingsが
返り、確度×重大度の1次振り分けで9件が投稿候補、4件が報告のみとなった。
`select-adversarial-findings.sh`（blocker0件のため9件全件がposted）で選別したうえで
GitHub MCP（pending review→9件のインラインコメント→submit_pending）でPR #183へ投稿した。

投稿した9件は、`.posted.findings`と`.posted`の入力形式の不整合（受け取り側が要求する形式は
`.posted`＝オブジェクト全体）、選別漏れfindingsの集約範囲の文言、blockerがハードシーリングの
枠を消費するかどうかの規則の曖昧さ、`main`の入力検証欠如、確度優先タイブレークの検証不足など、
いずれも確認のうえその場で修正した。報告のみの4件（doc-duplication・DDRの誤参照・既存DDRの
note未追加・HANDOFF.mdの進捗記号未更新）も全て対応済み。詳細は
`reports/20260823_misty-drifting-lantern_選別スクリプト実装.md`「敵対的レビュー実施と対応」節
（このファイルはflow-id 5-5で削除されるため、恒久的な参照先は本レポートとPRのコミット履歴）。

修正後、単体テスト（34アサーション）・`bash -n`構文チェックを再実行し`failures=0`を確認した。
投稿9件すべてへ署名付きで返信し、返信後に本文が途中で切れていないことを確認した。

### 4. defaultブランチ（main）とのコンフリクト解消（flow-id 5-1）

`check-base-conflicts.sh`で`hasConflict: true`（`.claude/docs/README.md`のDDR一覧生成マーカー
区間のみ）を検知した。`resolve-conflict`スキルの類型B（生成物）に従い、マーカー内の競合
（このブランチの`i0182-01`行 vs mainの`i0171-01`行）を両方残す形で手動解消したうえで
`generate-ddr-list.sh`を実行し、「変更はありません（80件）」で機械生成結果と完全一致することを
確認した。マーカー外の差分（mainが追加したspec一覧行等）はgitが競合と見なさず既に自動マージ
済みであることも確認した。全単体テスト（`passed=1314 failures=0`、失敗ファイル0件）・
コンフリクトマーカー残存無し・DDR識別子重複無し・`HANDOFF.md`自体の非汚染を確認し、
マージコミットを作成・push。push後に`check-base-conflicts.sh`で`hasConflict: false`を確認した。

### 5. 関連issue通知（flow-id 5-2）と`.gemini/`同期（flow-id 5-3）

diff（`plans/`/`worklog/`/`reports/`除外）から抽出したキーワードで`search_issues`を実行したが、
今回のissue自身とclosed済み issueのみがヒットし、open の関連issueは無かったため通知は行わな
かった。`.gemini/`は`sync-gemini-assets.sh`で再生成し、`--check`が終了コード0（同期済み）に
なることを確認した。

## 確かめられなかったこと

- 実際に人間レビュアーがPR #183へ新規のレビューコメントを付けた場合の対応
  （このセッションは非対話モードのため、人間の実レビューはこのブランチのコミット履歴・
  PR上に残っており、今後の`comments`/`reply`ループで対応する）。
- 選別スクリプトの出力を実際のMRへ`add_mr_inline_comments`で投稿する経路は、今回の
  敵対的レビュー往復で実機確認済み（PR #183へ9件投稿・返信が成功）である。

## 設計への反映

- `.claude/docs/spec/adversarial-review.md`・`.claude/docs/ddr/i0182-01-...md`・
  `.claude/docs/ddr/i0077-03-...md`（frontmatterの`note`）・`.claude/rules/shell-script-style.md`
  （jqのパイプ内`.`参照の落とし穴）への反映は完了している。
- 次のissueへ持ち越す反映事項は無い。

## 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| 敵対的レビューは実装完了後の1回で足りると見込んでいた | 実際に1回のレビューで13件の指摘（うちmajor5件）が見つかった | 全件確認のうえその場で修正し、再テストで`failures=0`を確認した |
| jqの`index()`を`select()`内で素直に書けると見込んでいた | パイプ右辺での`.`参照が外側の値に束縛される落とし穴を踏んだ | `.severity`を変数へ先に束縛する形へ修正し、`shell-script-style.md`へ知見を反映した |

## 残課題

- 無し（issue #182の受け入れ条件はすべて満たしている）。

---
issue #182 / PR #183 — 結果の正文は同名の `.html`。
