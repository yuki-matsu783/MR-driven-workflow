---
title: worklog - 【設計】【実装】【テスト】wip集約とworklogs改名
type: log
description: issue #165フェーズ3実装の詳細ログ
tags: [worklog, issue-165]
keywords: [wip, plans, worklog, worklogs, reports, git mv, cleanup-task]
---

# worklog: 【設計】【実装】【テスト】wip集約とworklogs改名

対象: issue #165 フェーズ3 - wip集約とworklogs改名の実装（2026-08-23）。
全体作業計画: `plans/transient-brewing-pelican.md`
個別作業計画: `plans/【設計】【実装】【テスト】wip集約とworklogs改名.md`
push回数: 1

## 試したこと

- フェーズ3個別作業計画（`plans/【設計】【実装】【テスト】wip集約とworklogs改名.md`）作成後、
  `adversarial-reviewer`サブエージェントによる敵対的レビュー（1周目）を実施した。
- 指摘のうち「`KEEP_PATHS`動的化後に`is_keep_path`直接呼び出しテストが壊れる」という指摘について、
  実際にbashで簡易シミュレーションを行い、提案した設計（トップレベルは空配列で初期化・`main`内は
  素の代入・テスト側で明示セット）が正しく動くことを確認した（`main`経由・テスト直接呼び出し
  経由の両方で`is_keep_path`が期待どおり`kept`を返すことを実測）。

## うまくいったこと

- 指摘13件すべてに対し、具体的な置換前後のコード・対処方針を計画へ反映できた。とくに`declare`の
  ローカルスコープ問題は、bashの動的スコープにより`main`経由では偶然動くが直接呼び出しでは
  壊れるという「一見動くのにテストだけ落ちる」性質を持つため、レビューが無ければ実装後に
  初めて気づいていた可能性が高い。
- `Provider.sh`・`cleanup-task.sh:224`のjqフォールバック既定値を「変更しない」と明示的に決定
  したことで、`.mrworkflow.json`を持たない配布先（未移行の既存導入先）との後方互換性を保ちつつ、
  `test_cleanup_task.sh`の既存フィクスチャ（`.mrworkflow.json`無し）が今後も意味のある
  テストであり続けられるようにした。

## ダメだったこと

- （特になし。指摘はすべて計画レベルで解消できた）

## 試したこと（続き・作業実施）

- `.claude/scripts/src/cleanup-task.sh`のKEEP_PATHSを、トップレベルの`readonly`配列から
  `main()`内で組み立てる形へ変更した。`declare`を使うとローカル変数になる罠を避け、素の
  代入文にした。
- `test_cleanup_task.sh`に、`.mrworkflow.json`で`worklogDir: "wip/worklogs"`を指定する
  新規フィクスチャ（`setup_ct_repo_wip`）を追加し、`main()`経由の配線を直接検証する結合
  テストを2件足した。
- `git mv plans wip/plans` `git mv worklog wip/worklogs` `git mv reports wip/reports`を、
  `mkdir -p wip`＋移動先3つの非存在チェックを`if`文で結合したガードの下で実行した。
- `.mrworkflow.json`・`.claude/settings.json`・`.gemini/settings.json`・
  `install-to-project.sh`を変更した。
- ドキュメント更新（約45ファイル）は、複数のサブエージェント（Agent tool）へ
  ディレクトリ単位で分担し、それぞれに「現在の状態を説明する箇所のみ更新し、DDR本文・
  spec changelogは触らない」という同一の判断基準を明示して並行実行した。

## うまくいったこと（続き）

- KEEP_PATHSの動的化前に、bashでの簡易シミュレーションにより設計（トップレベル空配列＋
  main内素代入＋テスト側明示セット）が正しく動くことを事前に確認できた。実装時に手戻りが
  無かった。
- サブエージェントへの分担で「過去のissue changelogは触らない」基準を明示したところ、
  `.claude/docs/spec/issue-mr-workflow.md`の50以上の過去changelog小節を1件も誤って
  書き換えることなく、現在の状態を説明する節だけを正確に更新できた（分岐点SHA基準の
  `git diff`で確認）。

## ダメだったこと（続き）

- `test_install_to_project.sh`は`plans`/`worklog`/`reports`ディレクトリ作成そのものを
  検証していなかった（変更前後どちらも）。想定していた「既存テストの合格で確認できる」が
  成立せず、使い捨てリポジトリへの実行による手動確認で補った。

## 次の一歩

- 作業実施後の敵対的レビュー（ユーザー指示の「作業実施毎に一度」の対象）を実施し、
  指摘を反映してからcommit・push・レビュー依頼（flow-id 3-7）を行う。

---
