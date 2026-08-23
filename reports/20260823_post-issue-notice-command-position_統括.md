---
title: post-issue-create-notice.shコマンド位置判定化 最終統括レポート
type: report
description: issue #149。post-issue-create-notice.shのCLI経路検知を部分一致からコマンド位置判定へ移行した作業全体（設計・実装・spec/DDR反映）の統括
tags: [spec, ddr, issue-149, 統括レポート]
keywords: [command-position.md, CommandPosition.sh, post-issue-create-notice.sh, command_invokes_script, 誤検知, 敵対的レビュー, i0149-01]
---

# post-issue-create-notice.shコマンド位置判定化 最終統括レポート

対象: issue #149 「post-issue-create-notice.shの検知をコマンド位置ベースにして誤検知を減らす」 /
PR #179 / ブランチ `claude/post-issue-notice-detection-xleu14`

## 何を変えたか

`.claude/hooks/post-issue-create-notice.sh` のCLI経路検知（`is_issue_create_call`）を、
`create-issue.sh` という文字列の**単純な部分一致**から、**コマンド位置での判定**
（`command_invokes_script`）へ差し替えた。これにより、`grep create-issue.sh` や
コメント中の言及など、実行位置に無い文字列出現では発火しなくなる一方、実際の実行
（`bash <path>/create-issue.sh` や `sudo -u alice bash <path>` 等の間接実行を含む）は
引き続き検知する。

具体的な変更は次のとおり。

- `.claude/hooks/lib/CommandPosition.sh` へ、スクリプトのbasename一致に特化した
  `_cp_scan_tokens_for_script`/`command_invokes_script`（公開関数）を新規追加した。
  既存のgit専用判定（`_cp_scan_tokens`/`command_invokes_git_subcommand`）は無変更
  （byte-identicalを確認済み）。
- 値を取るprefixオプション（`sudo -u`/`timeout <秒数>` 等）・シェル系インタプリタ限定の
  `-n`（非実行）除外・クォート引数の保守的フォールバック（`_`プレースホルダヒューリスティック）
  など、script判定固有の振る舞いを追加した。
- `post-issue-create-notice.sh` の3段ガードを、常時初期化するトップレベル実行から、
  初回呼び出し時にのみ`CommandPosition.sh`を`source`する**遅延初期化（型B）**へ変更した。
  issue #159で導入した前置フィルタの空振りコスト削減効果を、判定ライブラリの常時読み込みで
  打ち消さないため。
- `.claude/scripts/test/test_command_position.sh`（+103件、計118件）・
  `.claude/scripts/test/test_post_issue_create_notice.sh`（+61件、計38件）にテストを追加した。
- `.claude/docs/spec/command-position.md`・`.claude/docs/spec/issue-mr-workflow.md`・
  `.claude/rules/shell-script-style.md` を現在の実装に合わせて更新し、
  `.claude/docs/ddr/i0149-01-post-issue-create-notice.shの検知をコマンド位置判定へ移行する.md`
  を新規作成した。

## なぜそうしたか

- **部分一致は「実行していないのに発火する」誤検知を構造的に避けられない。** issue #147
  （`block-direct-git-commit.sh`のコマンド位置化）で確立した`CommandPosition.sh`の設計を
  そのまま再利用できたため、同じ基盤で解決した。
- **git専用の既存判定を壊さずに拡張する必要があった。** そのため新規関数
  （`_cp_scan_tokens_for_script`/`command_invokes_script`）を追加する形にし、既存の
  `_cp_scan_tokens`/`command_invokes_git_subcommand`は一切変更していない（差分で確認）。
- **既知の制約（クォート付き直接起動の見逃し・値取りprefixオプションの見逃し等）を無くす
  のではなく、明示する方針にした。** 完全な検知は静的なトークン走査では原理的に困難
  （`eval`/`bash -c`等）であり、DDR `i0149-01`「却下案」表に判断根拠を残した。
- **遅延初期化（型B）を採用したのは、issue #159の前置フィルタ最適化と両立させるため。**
  常時sourceする型Aだと、前置フィルタで足切りされる（起票と無関係な）呼び出しでも
  ライブラリ読み込みコストが発生し、issue #159の効果を実質的に無効化する
  （実測+35%、100回・同一セッション・Linux条件）。

## 検証結果

```
$ bash -n .claude/hooks/lib/CommandPosition.sh && echo OK
OK
$ bash -n .claude/hooks/post-issue-create-notice.sh && echo OK
OK
$ bash .claude/scripts/test/test_command_position.sh
passed=118 failures=0
$ bash .claude/scripts/test/test_post_issue_create_notice.sh
passed=38 failures=0
$ bash .claude/scripts/test/test_block_direct_git_commit.sh
passed=27 failures=0
$ bash .claude/scripts/src/generate-ddr-list.sh
DDR一覧に変更はありません（84件）: .claude/docs/README.md
$ bash .claude/scripts/src/check-base-conflicts.sh
{"hasConflict": false, ...}
$ bash .claude/scripts/src/sync-gemini-assets.sh --check
.gemini/ は .claude/ と同期しています。
```

- git専用の既存関数（`_cp_scan_tokens`・`command_invokes_git_subcommand`）が
  byte-identicalであることを、マージ元との差分抽出で確認した。
- DDR識別子（`i0149-01`）の重複が無いことを確認した。
- defaultブランチ（main）がPR作成後に2回進んだため、`git merge origin/main`を2回実施し
  解消した（詳細は下記「残課題」直前の記述、およびPRのコミット履歴）。

## spec・DDRへの反映先

- `.claude/docs/spec/command-position.md`: 利用元・公開インターフェース表・判定の3段
  （縮退判定式の違い・相違点リスト・保守的フォールバック）・呼び出し側の責務節（3段ガード
  の2つの型、型A/型B）・既知の制約表・未決定事項・影響範囲・性能節を更新した。
- `.claude/docs/spec/issue-mr-workflow.md`: 「検知の条件」表のCLI行・判定説明・
  「既知のトレードオフ」節を現在の実装に合わせて更新した。
- `.claude/docs/ddr/i0149-01-post-issue-create-notice.shの検知をコマンド位置判定へ移行する.md`:
  新設。5つの設計判断（script専用関数の追加・sticky解除・`{`/`}`除外・遅延初期化型B・
  クォートパスの保守的フォールバック拡張）の理由と却下案を記録した。
- `.claude/rules/shell-script-style.md`: `create-issue.sh`の部分一致例が、現在は
  ライブラリ非存在時の縮退経路限定であることを追記した。

## 敵対的レビューの実施経緯

ユーザーの指示（「各フェーズでの計画時に一度敵対的レビュー、作業実施毎に一度ずつ敵対的
レビューを自動で行い、指摘に対する修正を行いながら進める」）に従い、フェーズ3・4それぞれで
計画レビュー・実装レビューを実施した。

| フェーズ | 回 | 対象 | 指摘件数 | 主な内容 |
|---|---|---|---|---|
| 3 | 1回目 | 個別作業計画 | 8件（major 4・minor 5） | sticky解除・保守的フォールバック・トップレベル3段ガード等の設計不足 |
| 3 | 2回目 | 実装 | 8件（major 3・minor 4・nit 1） | prefix値オプションの誤認・クォートパス見逃し・issue #159最適化の巻き戻し等 |
| 4 | 1回目 | 個別反映計画 | 13件（blocker 1・major 8・minor 3・nit 1） | 反映対象の過小評価（4箇所→9箇所へ拡大）・型A/B未説明・DDR新設漏れ等 |
| 4 | 2回目 | 実装（spec/DDR反映） | 9件（major 1・minor 6・nit 2） | 既知の制約表の説明不足・DDR記述の過大表現・測定条件の不備等 |

いずれも指摘をすべて実機・実文書で確認のうえ修正し、修正後に単体テスト・構文チェックで
回帰が無いことを確認した。フェーズ3・4とも3回目のレビューは、直前の修正がレビュー指摘への
対応であり新規の設計・反映対象追加を伴わないことを踏まえ見送った（各フェーズ上限3回のうち
2回の実施）。

## 関連issueへの通知

flow-id 5-2で、`plans/` `worklog/` `reports/`を除いた差分からキーワード抽出し
`search_issues`で候補検索した結果、issue #159（クローズ済み「hookの空振り起動コストを
前置フィルタで削減する」）を「前提が変わる」型の通知対象と判定した。DDR `i0159-01`が
前置フィルタの超集合性を確認した当時のテストは旧・単純部分一致の判定本体を前提にしており、
issue #149でその判定本体をコマンド位置判定へ差し替えたためその前提が変わったこと、
突き合わせテストは未追加であることを、ユーザー承認のうえで通知した
（[コメント](https://github.com/yuki-matsu783/MR-driven-workflow/issues/159#issuecomment-5385915905)）。

## 残課題

- 前置フィルタ（`raw_hints_at_issue_create`。issue #159）の超集合性は設計上の推論で
  再確認したが、判定本体を実際に通した突き合わせテストは追加していない（issue #159へ
  通知済み。上記「関連issueへの通知」）。
- Windows / git bash実機での動作・性能は未確認（プラットフォーム依存の構文は使っていない）。
- 実運用での誤検知の残存は、単体テスト（118件・38件）が代表例であって網羅ではない。
  既知の制約（クォート付き直接起動の見逃し・値取りprefixオプションの見逃し・opaque-word
  経由の過検知等）は`command-position.md`「既知の制約」表に明記済み。
