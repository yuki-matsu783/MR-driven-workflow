---
title: worklog 20260819 【調査】インラインコメント投稿APIとセッション種別判定 push1
type: log
description: issue #77 フェーズ2の作業ログ（push1）。フェーズ1の実施内容と調査計画の作成までを記録する。
tags: [worklog, issue-mr-flow, research]
keywords: [worklog, issue77, 敵対的レビュー, インラインコメント, AUTOMATION, 調査計画, Draft PR]
---

# worklog: 【調査】インラインコメント投稿APIとセッション種別判定

対象: issue #77 MRへの敵対的レビューを行うスキル・専任サブエージェントを追加する（2026-08-19）。
全体作業計画: `plans/prancy-herding-kahan.md`
個別作業計画: `plans/【調査】インラインコメント投稿APIとセッション種別判定.md`
push回数: 1

## 試したこと

- flow-id 1-2〜1-3: `get_issue 77` でissueを取得し、`test_issue_sections` で標準4見出しの
  過不足を確認（欠落なし）。`feature-77-*` のブランチがローカル・リモートともに無いことを
  確認したうえで `new_issue_branch 77 "adversarial mr review skill"` →
  `new_draft_merge_request 77 ...` を実行し、Draft PR #80 を作成した。
- flow-id 1-4: 分割提案ルール（`.claude/docs/ddr/0034-...`）に従い、issue #77 が
  並列列挙構造かどうかを判定した。受け入れ条件9項目・レビュー対象3種という「並んで見える」
  構造だが、`AskUserQuestion` で分割案（基盤/機能の2分割・レビュー対象3種での3分割）を
  提示したうえで「このまま1件で進める」に合意した。
- 設計判断のため、既存資産を読んだ。
  - `Provider.sh` の関数一覧（31関数）とディスパッチ形式、`add_mr_thread_reply` /
    `add_mr_comment` の実装（`Github.sh` はGraphQL、`Gitlab.sh` はREST）。
  - `issue-mr-resume.md`（唯一のサブエージェント定義）のfrontmatter形式と読み取り専用の書きぶり。
  - `test_vcs_provider.sh` の「純粋関数だけを対象にする」方針と `passed=N failures=N` 規約。
- `docker --version` で実行環境にdockerがあること（29.7.2、起動中コンテナなし）を確認した。
- `update-handoff-progress.sh` が新しく書いた `HANDOFF.md` の40行テーブルを正しく解釈できるか、
  一時コピーに対して `mark-done 2-1` / `set-header --push-count 1` を試して確認した
  （本体は書き換えていない）。

## うまくいったこと

- Draft PR #80 の作成は既知の制約どおり1回目が「No commits between ...」で失敗し、
  `add_empty_commit_for_draft_mr` の自動リトライで成功した（DDR 0005の想定どおりの挙動）。
- 非対話セッションの判定材料として、ユーザーから `AUTOMATION` 環境変数
  （`AUTOMATION=1` なら非対話）という具体案が示された。スキルの手順1（スキップ不可）として
  組み込む方針を計画へ反映した。
- 無限ループ防止として「実施回数を機械的に記録し、各フェーズ最大3回で打ち切る」を計画へ追加した。
  AIの自制ではなくスクリプト側で強制する形にする。

## ダメだったこと

- 非対話セッションの判定について、リポジトリ内に既存の仕組みが無いか
  `grep -rn "非対話" / "CLAUDE_CODE" / "isInteractive"` で探したが、ドキュメント上の言及
  （`docs-workflow.md`・DDR 0024・spec）だけで、**機械的な判定は実装されていなかった**。
  そのためフェーズ2の調査項目として立てることにした。

## 次の一歩

- flow-id 2-2: 全体作業計画・個別調査計画・worklog・HANDOFF.md をcommitし、リモートへ反映して
  レビュー依頼を行う。
- レビュー合意後、flow-id 2-6 で調査1〜4を実施する（順序は 1・3・4 → 2（docker））。
