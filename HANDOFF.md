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

- issue: #113
- ブランチ: `claude/skill-md-reload-prompt-jy5z5i`
- PR: #134（https://github.com/yuki-matsu783/MR-driven-workflow/pull/134 ）
- push回数: 1
- 現在のループ: なし
- 追従監視: 購読あり（web。subscribe_pr_activity + 定期チェックイン）

（進捗表は次タスク着手時に記入する）

<!--
本ブランチは Claude Code on the web の非対話セッションで進めたため、人間担当のレビュー往復
（flow-id 2-3/2-8, 3-3/3-8, 4-3/4-8）を待てない。`.claude/rules/docs-workflow.md` の規定に従い、
該当ループ範囲の記号は付けず、実施内容は下記「やったこと」に文章で残す。
-->

## やったこと

issue #113（compact後もissue-mr-flow対象ブランチではSKILL.mdの再読み込みを促す）に対応した。

- **調査**: `session-start.sh` の注入経路を読み、CLI経路・MCP経路の両方から1回ずつ呼ばれる
  `build_work_context` が唯一の追加ポイントだと確認した。対象ブランチの判定材料を3つ比較し
  （ブランチ名／ブランチ固有の作業ファイル／`HANDOFF.md` の進捗表）、前2つが互いに取りこぼしを
  補い合う関係にあることを確認した。**このブランチ自体が命名規則 `feature-{issue}-{slug}` に
  一致しない**ため、ブランチ名だけを材料にすると自分自身が対象外になる（取りこぼしは実在した）。
- **実装**: 純粋関数 `issue_mr_flow_branch_reason`（対象なら判定根拠を返す）と
  `format_skill_reload_instruction`（指示文を組み立てる）を追加し、`build_work_context` の
  **末尾**で指示文を足す。**いずれか一方の材料でも成り立てば対象**とし、判定根拠を指示文へ
  埋め込む。指示文の要点は「**このセッションで既に読んでいる場合も読み直すこと**」を明示する点。
- **検証**:
  - 使い捨てリポジトリでhook本体を実行し、4状態（main／`feature-113-…`／命名規則外・作業
    ファイル無し／命名規則外・`plans/` に個別計画あり）の出力を目視した。**状態3で指示文が
    出ないこと**（受け入れ条件「対象外では既存の挙動を壊さない」）を実出力で確認済み。
  - `test_session_start.sh` を 35 → 51 ケースへ拡張。全12テストスクリプトが `failures=0`
    （合計 649 ケース）。
  - 指示文の実測は 603 バイト（判定根拠2件で 690 バイト）。肥大化検知のしきい値 8000 バイトに
    対して十分小さく、DDR 0032 の方針と矛盾しない。
- **設計反映**: spec「セッション開始時の自動コンテキスト注入」節へ判定・指示文の仕様を追記、
  「影響範囲」へ issue #113 のエントリを追加、DDR 0059 を新規作成、`.claude/docs/README.md` の
  DDR一覧へ追加した。**AIアセット反映は不要と判断**（踏んだ落とし穴はいずれも
  `.claude/rules/shell-script-style.md` `.claude/rules/git-workflow.md` に既出）。
- **変更したファイル**:
  - `.claude/hooks/session-start.sh`
  - `.claude/scripts/test/test_session_start.sh`
  - `.claude/docs/spec/issue-mr-workflow.md`
  - `.claude/docs/ddr/0059-issue-mr-flow対象ブランチではSKILL.mdの再読み込みを注入で促す.md`（新規）
  - `.claude/docs/README.md`
- **変更していないファイル**: `.claude/settings.json` / `.gemini/settings.json`（matcher は
  `startup|resume|clear|compact` のまま。注入の**内容**だけを増やす変更のため）。
- **flow-id 5-1（コンフリクト検知）**: `check-base-conflicts.sh` で `hasConflict: false`
  （textualConflictFiles・duplicateDdrNumbers ともに空）。解消作業は不要だった。
- **flow-id 5-2（関連issue通知）**: 差分（`plans/` `worklog/` `reports/` を除く）から候補を検索し、
  **issue #129 のみが「前提が変わる」に該当**すると判断してユーザー承認のうえ通知した
  （https://github.com/yuki-matsu783/MR-driven-workflow/issues/129#issuecomment-5356414031 ）。
  #129 は `issue-mr-flow/SKILL.md` を `references/` へ分割する計画であり、分割後は
  「SKILL.md を読み直せ」という指示文の文言を見直す必要がある。issue #57（closed。DDR 0032）は
  **今回の変更が決定を覆すのではなく拡張する**関係のため通知対象から外した。

## 次にやること

- PR #134 のレビュー待ち。マージはユーザーの明示指示があるまで行わない。
- flow-id 5-1〜5-3（コンフリクト検知・関連issue通知・片付け）は、レビューが落ち着いてから行う。

## 判断を迷った内容

- **対象判定を何で行うか。** `HANDOFF.md` の進捗表の有無が「フローに乗っている」ことの証としては
  最も直接的だが、リセット直後（flow-id 5-3 の直後）とブランチ作成直後が空になり、**フローの
  最初と最後で取りこぼす**。表の書式変更にも判定が引きずられるため採らなかった（DDR 0059 に
  却下案として記録）。
- **指示文を注入テキストの先頭に置くか末尾に置くか。** 先頭だと「ブランチ情報 → 作業ファイル →
  次にやること」という現在地の並びを分断する。「作業を再開する**前に**すること」であることを
  踏まえ、末尾へ置いた。

## 未解決の内容

- **実際のcompact発生時の挙動は、この環境では確認していない。** 検証したのはhookの出力内容で
  あり、compactを起点にhookが発火すること自体は issue #57（DDR 0032）で確認済みの matcher 設定に
  依存する。今回 matcher は変更していない。
- 対象判定はヒューリスティックであり、「issue-mr-flowに乗せていないが `plans/` を作った」
  ブランチは対象と判定される。指示を1つ読ませるだけのコストなので、取りこぼす側より安全な方向へ
  倒している。

## 守るべき条件・触ってはいけない範囲

- `.claude/settings.json` の `hooks.SessionStart` matcher は変更しない（注入の内容だけを増やす
  変更であり、発火条件は issue #57 の決定のまま）。
- 起動要因（startup/resume/clear/compact）ごとに注入内容を分岐させない（DDR 0032 の方針）。
- SKILL.md の中身・要約は注入しない（注入するのは指示文のみ）。
