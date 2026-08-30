---
title: 最終統括レポート: defaultブランチとの差分リンクをPR/MRのDiffviewへ変更する
type: report
description: issue #205（PR #206）の最終統括。フェーズ2〈調査〉〜5〈クローズ〉で何を変え・なぜそうし・どう検証し・spec/DDRへ何を反映し・何が残っているかの1枚まとめ
tags: [report, summary, issue-mr-flow]
keywords: [Diffview, get_mr_diff_url, resolve_mr_number_for_head, 敵対的レビュー, mainマージ, push前チェックリスト, 統括レポート]
---

# 最終統括レポート: defaultブランチとの差分リンクをPR/MRのDiffviewへ変更する（issue #205 / flow-id 5-4）

- issue: #205
- ブランチ: `claude/pr-mr-diffview-link-yxim1l`
- PR: #206
- 個別計画・個別レポート一覧: `wip/plans/【調査】…md` `wip/plans/【実装】【テスト】…md`
  `wip/plans/【設計反映】…md`（+各`.html`）、`wip/reports/20260824_…調査結果.md`
  `wip/reports/20260824_…実装結果.md` `wip/reports/20260826_…反映結果.md`（+各`.html`）

## 何を変えたか

1. **`get_mr_diff_url` を4引数化した**（`Provider.sh` / `Github.sh` / `Gitlab.sh`）。第4引数
   `mrUrl`が非空ならDiffview（GitHub `<mrUrl>/files`、GitLab `<mrUrl>/diffs`）、空ならCompare
   （`<repoUrl>/compare/<from>...<to>`）を返す純粋関数のまま拡張した。
2. **`resolve_mr_number_for_head <sha>...`を新設した**（GitHubのみ）。`gh`/`glab` CLI不在の
   MCPフォールバック環境でも、`git ls-remote origin 'refs/pull/*/head'`だけでPR番号を解決する。
   複数候補SHA（今回push・前回push）を受け取り、一致したPR番号の種類数がちょうど1のときだけ
   採用する（0件・2件以上はCompareへ縮退）。HTTP(S)リモート限定。
3. **`post-push-compact-prompt.sh`で`compare_url`と`diff_url`を分離した。** 差分アンカーの
   土台（`get_diff_anchor_base_url`）へは今回もCompareページを渡し続け、「defaultブランチとの
   差分」1リンクだけがDiffviewへ変わる設計にした。
4. **`test_vcs_provider.sh`を225→249件へ拡張した**（4引数版アサーション、複数候補SHA、
   ディスパッチャ経由の経路テスト等）。
5. spec「提供関数」表・「未決定事項・懸念点」・「参照リンクの付与」節・「影響範囲」changelog、
   新規DDR `i0205-01`、`references/mcp-fallback.md`を更新した。

## なぜそうしたか

- **URL形式（`/files`・`/diffs`）は、issueの起票者（リポジトリ所有者）がissue本文で明示的に
  指定した形式であり、DDR `i0013-01`が却下した「UIの構造への推測」ではないと判断した。**
  ブラウザでの実機確認は取れていないため確度は「未検証」のまま残し、spec側へ引き継いだ。
- **PR番号解決を`git ls-remote`にした理由（案A採用・案B/C却下）**: 状態ファイル（案B）・
  `HANDOFF.md`（案C）はいずれも「黙って古い／誤ったURLを出す」（silent staleness）失敗の
  仕方をする。`git ls-remote`は解決できなければ空を返しCompareへ縮退するため、失敗が無害な
  側へ倒れる。
- **一致判定を「番号が最大のものを採る」から「種類数がちょうど1」へ変更した理由**: フェーズ2の
  敵対的レビューで、`refs/pull/*`にマージ済み・クローズ済みPRのrefも永続的に残ることが実測され
  （`refs/pull/4/head` `refs/pull/85/head`が現存）、番号の大小では正しいPRを選べないと判明した。
- **複数候補SHAへ変更した理由**: フェーズ3の実push検証で、GitHubの`refs/pull/<n>/head`が
  push直後は更新されず、hookの発火タイミングでは前回pushのSHAを指していることを実際に観測した。
  詳細はDDR `i0205-01`「決定」1〜5・「理由」を参照。

## 検証結果

| 検証 | 結果 |
|---|---|
| `test_vcs_provider.sh` | `passed=249 failures=0`（開始時225件から+24件） |
| 単体テスト全21ファイル | `passed=1882 failures=0` |
| `check-doc-references.sh` | 参照切れ数=0 |
| DDR識別子の重複 | 0件（`ls .claude/docs/ddr/ | grep -oE ... | sort | uniq -d`が空） |
| `sync-gemini-assets.sh --check` | `.gemini/`は`.claude/`と同期 |
| `test_sync_gemini_assets.sh` | `passed=106 failures=0` |
| この環境でのDiffviewリンク実測 | `- defaultブランチとの差分: https://github.com/yuki-matsu783/MR-driven-workflow/pull/206/files` を実際に確認 |
| 差分アンカー付きリンクの後退確認 | 全件Compareのまま（10/10で件数一致、後退なし） |
| push直後のref伝播遅延 | 実push（コミット`22a23b7`）で実際に発生・観測。数十秒後の再実行で解決成功を確認 |
| main（defaultブランチ）マージ後の`mergeable_state` | `clean` |

## spec・DDRへの反映先

- `.claude/docs/spec/issue-mr-workflow.md`: 「提供関数」表（`get_mr_diff_url`4引数化・
  `resolve_mr_number_for_head`新規行）、「未決定事項・懸念点」（issue #205関連6項目）、
  「参照リンクの付与（issue #13）」節（新設「MCPフォールバック時のMR/PR URL解決」小節）、
  「hookの縮退」節、「影響範囲」changelog（`### issue #205（…）`エントリ）。
- `.claude/docs/ddr/i0205-01-defaultブランチとの差分リンクをPR_MRのDiffviewへ出し分ける.md`
  （新規）: 決定1〜5・理由（Q1: URL形式の未検証採用根拠／Q2: `i0013-01`との関係）・却下した案
  5件・未検証事項/残る制約・影響。
- `.claude/docs/ddr/i0013-01-…md`: frontmatterへ`note`を追加（`i0205-01`との関係を記録。
  本文は不変のまま）。
- `.claude/skills/issue-mr-flow/references/mcp-fallback.md`: §2表へ
  `resolve_mr_number_for_head`行を追加、§2-bへ`mcp__github__create_pull_request`の`*`喪失の
  落とし穴を追加、§4の`post-push-compact-prompt.sh`行を更新。
- `.claude/docs/README.md`: `generate-ddr-list.sh`実行でDDR一覧を再生成（105件。うちmain側の
  8件を含む）。

## 敵対的レビュー（ユーザー指示: 各フェーズの計画時・作業実施後にそれぞれ1回ずつ自動実行）

| フェーズ | 回 | 対象 | 検出 | 投稿 | 対応・返信 |
|---|---|---|---|---|---|
| 2〈調査〉 | 1回目（計画時） | 個別調査計画 | 12件 | 11件 | 全件対応・返信済み（未返信0） |
| 2〈調査〉 | 2回目（作業実施後） | 調査結果 | 12件 | 9件 | 全件対応・返信済み（未返信0） |
| 3〈実装〉 | 1回目（計画時） | 個別作業計画 | 10件 | 10件 | 全件対応・返信済み（未返信0） |
| 3〈実装〉 | 2回目（作業実施後） | 実装差分 | 10件 | 10件 | 全件対応・返信済み（未返信0） |
| 4〈反映〉 | 1回目（計画時） | 個別反映計画 | 12件 | 9件 | 全件対応・返信済み（未返信0） |
| 4〈反映〉 | 2回目（作業実施後） | 反映差分 | 10件 | 8件 | 全件対応・返信済み（未返信0） |

計6回・検出66件・投稿57件（残る9件は確度・重大度が低く報告のみ）。投稿分はすべて修正・返信を
完了しており、現時点で未返信スレッドは0件。

## defaultブランチへの追従（flow-id 5-1）

main側で6コミット進んだ後、`resolve-conflict`スキルで取り込んだ（コミット`539627f`）。

- `.claude/docs/README.md`: DDR一覧の`<!-- BEGIN/END GENERATED: ddr-list -->`マーカー内が
  競合（類型B）。マーカー外に差分が無いことを確認してから片側を採用し、`generate-ddr-list.sh`
  再実行で105件へ再生成した（97件→105件）。
- `.claude/docs/spec/issue-mr-workflow.md`「未決定事項・懸念点」: 同じ「GitLab側の動作未検証」
  ブレットの直後へ、自ブランチ（issue #205関連6項目）とmain（issue #17エントリ）が並行して
  追記していた（類型D）。時系列順に両方残す形で統合した。
- main側で新設された**push前チェックリスト機構（issue #17）**へ初めて対応した
  （`push-checklist.sh`でチェックリストを埋めてコミット）。

## 残課題

- **GitHubの`/pull/<n>/files`をこの環境では一次情報（ブラウザ）で裏取りできていない。** URL形式は
  issue本文で明示的に指定されたものだが、実機確認（ブラウザでの表示確認）は未実施のまま残る。
- **GitHubの差分アンカー（`#diff-<sha256>`）がPR本体の`/files`上で機能するかは未検証。**
  実害を避けるため今回もCompareページを土台に使い続けており、重点レビュー対象ファイルのリンクは
  引き続きCompareページ上に残る。issueの目的が達成されるのは「defaultブランチとの差分」1リンク
  についてのみである。
- **GitLabの`refs/merge-requests/<n>/head`相当の対応は未実装。** `glab`を使わない検証環境が
  無く実機検証できないため対象外とした。GitLab検証が可能になった時点で別issueとして起票する。
- **`git ls-remote`のgit bash（Windows）実機コスト・認証プロンプト対策の実効性は未検証。**
  この実行環境（Linux）での実測値（約400〜600ms）はfork単価が桁違いのgit bash実機の値ではない。
- **一致したPR番号の種類数がちょうど1でも、そのPRが正しいとは限らない残存リスクがある。**
  `git ls-remote`の出力だけからはPRのstate（クローズ済みか）・base branchを検証できないため、
  対策は未実装のまま残す（詳細: DDR `i0205-01`「未検証事項・残る制約」）。

いずれも詳細はspec「未決定事項・懸念点」・DDR `i0205-01`を正とする。
