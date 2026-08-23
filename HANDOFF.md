---
title: HANDOFF
type: handoff
description: セッション間・作業者間の引継ぎメモ（現在地・次回やること等）
tags: [handoff, workflow]
keywords: [フロー進捗, worklog, 引き継ぎ, plan, レビュー]
---

# HANDOFF

<!--
AI⇔AI/AI⇔人間の状況引継ぎメモ。常に「このブランチの現状」を表現する
-->

## フロー進捗状況

- issue: #159 hookの空振り起動コストを前置フィルタで削減する（block-direct-git-commit / post-issue-create-notice）
- ブランチ: claude/reduce-hook-misfire-cost-p4xzyo（ハーネスが事前作成。命名規則`feature-159-...`とは異なるが、指示によりこのブランチのまま作業する）
- PR: #162 https://github.com/yuki-matsu783/MR-driven-workflow/pull/162（Draft）
- push回数: 2
- 現在のループ: 3-6〜3-9 の1周目（進行中）
- 追従監視: 購読あり（web。subscribe_pr_activity + 1時間ごとの自己チェックイン）

| 進捗 | flow-id | ステップ | 担当 |
|---|---|---|---|
| [x] | 1-2 | issueの内容を取得する | エージェント |
| [x] | 1-3 | featureブランチ/Draft MR作成（ブランチはハーネスが事前作成済み） | エージェント |
| [x] | 1-4 | 全体作業計画を作成する | エージェント |
| [] | 1-5 | 全体作業計画に合意する | 人間 |
| [x] | 1-6 | HANDOFF.mdを更新する | エージェント |
| [-] | 2-1〜2-10 | フェーズ2〈調査〉（実施しない。理由は全体作業計画参照） | - |
| [x] | 3-1 | 個別作業計画を作成する | エージェント |
| [x] | 3-2 | commit・push・レビュー依頼 | エージェント |
| [] | 3-3 | 作業計画をレビューする | 人間 |
| [] | 3-4 | レビュー内容を取得し計画を修正する | エージェント |
| [] | 3-5 | MR descriptionを更新する | エージェント |
| [] | 3-6 | 作業を実施する | エージェント |
| [] | 3-7 | commit・push・レビュー依頼 | エージェント |
| [] | 3-8 | 作業結果をレビューする | 人間 |
| [] | 3-9 | レビュー内容を取得し修正する | エージェント |
| [] | 3-10 | MR descriptionを更新する | エージェント |
| [x] | 4-1 | 個別反映計画を作成する | エージェント |
| [] | 4-2〜4-10 | フェーズ4〈反映〉 | - |
| [] | 5-1〜5-6 | フェーズ5〈クローズ〉 | - |

## やったこと

- issue #159の内容を取得し、期待する動作・受け入れ条件を確認した。
- 参考実装として issue #70（PR #157、未マージ）のpush系hook2本への同パターン適用diffを取得し、
  適用すべきパターン（`IFS= read -r -d '' raw || true` + `case`）を確認した。
- issue #149（`post-issue-create-notice.sh`の判定本体をコマンド位置判定へ差し替える、未着手の
  別issue）の内容を確認し、前置フィルタが将来の判定変更に対しても超集合であり続ける根拠を検討した。
- 全体作業計画 `plans/reduce-hook-misfire-cost.md`（フェーズ2〈調査〉は実施しないと明記）と
  個別作業計画 `plans/【実装】【テスト】hookの前置フィルタ追加.md`、それぞれのHTMLビューを作成した。
- 個別作業計画に対する敵対的レビュー（1回目）を実施した（ユーザーからの明示指示により、
  非対話セッションでの自律起動として実施）。**major 4件・minor 8件**の指摘を受けた。
  主なもの: (1) 当初案`*commit*`部分一致は`git com\mit`のようなバックスラッシュ分割で
  超集合が壊れる、(2) `${raw,,}`はbash 4.0以降専用で既存のbash 4.3未満フォールバックより
  前に置くと展開エラーで丸ごと落ちる、(3) issue #149整合性の論理（部分集合になる、という
  主張）が誤り、(4) 前置フィルタを純粋関数へ切り出していないため単体テストできない。
  全指摘を計画・実装・テスト・DDR・specへ反映済み（詳細:
  `reports/20260823_reduce-hook-misfire-cost_前置フィルタ実装.md`）。
- commit・pushし、Draft PR #162 を作成した（ユーザーからの明示指示「PR作りながら対応して」を
  flow-id 1-3のPR作成の明示指示とみなした。`.claude/rules/git-workflow.md`
  「ハーネスがPR作成を制限する環境での扱い」に従う）。`subscribe_pr_activity`でPRイベントを購読した。
- `.claude/hooks/block-direct-git-commit.sh` / `post-issue-create-notice.sh` へ前置フィルタを
  実装した。判定本体は変更していない。
- `.claude/scripts/test/test_block_direct_git_commit.sh`を新規作成し、
  `.claude/scripts/test/test_post_issue_create_notice.sh`へ前置フィルタのテストケースを追記した。
  いずれもスタブjq（呼ばれたら失敗する）を使い、足切りされるペイロードでjqが1回も呼ばれないことと、
  `git -C /x commit`のような語が非連続の形・大文字混じりでも前置フィルタを通過して精密判定まで
  到達することを確認した。既存テスト（test_command_position.sh, 既存の
  test_post_issue_create_notice.shケース）もすべて引き続きパスすることを確認した。
- 変更前後のexecve/clone回数をstraceで実測した（対象外ペイロード1件、Linux環境）。
  敵対的レビューの指摘反映後（最終版）でも数値に変化が無いことを再測定で確認した。
  - `block-direct-git-commit.sh`: 変更前 execve=5 clone=10 → 最終版 execve=1 clone=0
  - `post-issue-create-notice.sh`: 変更前 execve=7 clone=17 → 最終版 execve=1 clone=1
    （clone=1は`( main ) || true`の実サブシェル分。jq起動は0）
- 前置フィルタパターンのDDR（`.claude/docs/ddr/i0159-01-....md`）を新規作成し、
  `.claude/docs/README.md`のDDR一覧を再生成した。
- `.claude/docs/spec/command-position.md`「利用元」節・「未決定事項・懸念点」節へ前置フィルタの
  存在とissue #149着手時の再確認事項を追記した。
- `.claude/rules/shell-script-style.md`「外部プロセス起動のコスト」節へ、hook向け前置フィルタ
  パターンを一般化して追記した（AIアセット反映）。
- 全テスト（`test_command_position.sh` 75件・`test_post_issue_create_notice.sh` 30件・
  `test_block_direct_git_commit.sh` 23件）が`failures=0`であることを確認した（1回目レビュー時点）。
- **commit直前の作業結果（フェーズ3の実装＋フェーズ4の反映をまとめた差分）に対する敵対的
  レビュー（2回目・作業結果の確認）を実施した。** major 2件・minor 8件・nit 1件の指摘を受け、
  全件を自分で再現・検証したうえで修正した。
  - **超集合性の破綻（再発、major）**: `raw_hints_at_git_commit`はjqデコード**前**の生JSON
    文字列を受け取るが、`${raw//\\/}`はバックスラッシュだけを除去するため、実コマンド
    `git com\<改行>mit`（行継続）はJSON化すると`com\\\nmit`（バックスラッシュ3つ+n）になり、
    `n`が残って一致しなくなっていた（実機で反例・end-to-endのブロック解除を確認）。
    JSON文字列エスケープの2文字シーケンス（`\\` `\"` `\n` `\t` `\r` `\/` `\b` `\f`）を丸ごと
    除去するよう修正し、回帰テストを追加（`test_block_direct_git_commit.sh` 23→27件、
    `test_post_issue_create_notice.sh` 30→31件）。
  - **read(2)回数の未計測（major）**: `read -r -d ''`は入力サイズに比例したread(2)回数になる
    （1バイト単位）ため、大きなペイロードでは削減したexecve/clone以上のシステムコール増加に
    なりうる。実測は小さいペイロードのみで、この特性を測っていなかった。git bash実機が無く
    実測できないため実装は変更せず、`shell-script-style.md`へ注記するに留めた。
  - **execve/clone「変更前」の値の誤り（minor）**: 最初の測定が`lib/CommandPosition.sh`の
    無い配置（縮退経路）で行われており、execve6/clone12だった。正しい配置で再測定し
    execve5/clone10へ訂正（レポート・本ファイル・DDRの数値を修正）。
  - その他minor（測定環境の明記漏れ・未マージPR #157への参照の誤り・行番号参照のずれ・
    テストコメントの記述漏れ・回帰テストの記述と実態の食い違い・frontmatter欠落・md/HTML
    同期漏れ・本ファイルの進捗記号）・nit（レポートmdへのHTMLタグ混入）を修正。
    詳細は`reports/20260823_reduce-hook-misfire-cost_前置フィルタ実装.md`。

## 次にやること

- commit・pushする（`commit`スキル経由）。
- MR descriptionを更新する（flow-id 3-5/3-10・4-5/4-10相当）。
- flow-id 5-1（コンフリクト確認）〜5-5（Draft解除）を実施する。issue #149への通知
  （flow-id 5-2）を実施する。

## 判断を迷った内容

- 全体フローのうち、人間のレビュー往復（3-3/3-4, 3-8/3-9等）を待てない非対話セッションのため、
  ユーザーからの「PR作りながら対応して」という指示を、flow-id 1-3のDraft PR作成についても
  明示指示とみなして進める。

## 未解決の内容

（無し）

## 守るべき条件・触ってはいけない範囲

- 判定本体（`command_invokes_git_subcommand` / `is_issue_create_call`）のロジックは変更しない
  （issue #159のスコープ外）。
- `.claude/settings.json` の `if` フィールドは変更しない。
