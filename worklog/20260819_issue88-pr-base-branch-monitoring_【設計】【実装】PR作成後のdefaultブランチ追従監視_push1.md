---
title: worklog 20260819 issue88 【設計】【実装】PR作成後のdefaultブランチ追従監視 push1
type: log
description: issue #88の追従監視手順を設計し4つのAIアセットへ反映した際の試行錯誤ログ（push1）
tags: [worklog, conflict, workflow]
keywords: [追従監視, flow-id, 並行手順, resolve-conflict, subscribe_pr_activity, send_later, HANDOFF, 自動解消]
---

# worklog: 【設計】【実装】PR作成後のdefaultブランチ追従監視

対象: issue #88「PR作成後のdefaultブランチ追従を自動で監視し、コンフリクトを検知しだい解消する
手順を整備する」（2026-08-19）。
全体作業計画: `plans/issue88-pr-base-branch-monitoring.md`
個別作業計画: `plans/【設計】【実装】PR作成後のdefaultブランチ追従監視.md`
push回数: 1

## 試したこと

- 既存アセットの現状を実測で確認した（フェーズ2〈調査〉の代替）。
  - `issue-mr-flow/SKILL.md`: flow-id 5-2 とその解説節は「Draft解除の直前に1回」しか想定して
    いない。PR作成〜マージ間の追従に触れた記述は無い。
  - `resolve-conflict/SKILL.md`: 類型A〜Eと Step 2 の「必ずユーザー承認を取る」を確認。
  - `.claude/docs/ddr/0029-...md` の決定6 が、その承認の根拠であることを確認。
  - `update-handoff-progress.sh` の `set-header` は `- issue:` `- ブランチ:` `- PR:` `- push回数:`
    の4項目のみを書き換える仕様（spec で確認）。→ ヘッダへ `- 追従監視:` を1行足しても
    既存スクリプトの挙動に影響しない、と判断した。
- 監視をどう位置づけるかを3案で比較した。
  1. 新しいflow-id（例: 1-7）として挿入し以降を繰り下げる
  2. 既存の flow-id 5-2 の記述を拡張する
  3. flow-idを持たないフェーズ横断の並行手順として独立した節にする
- 自動解消の線引きを、issue #88 の記述（類型A/C/Dは自動、Eは人間）から一般化できるか検討した。

## うまくいったこと

- **案3（並行手順）を採用した。** 監視は「開始（1-3）から停止（5-4）まで続く状態」であり、
  進捗表の1行として `[x]` を付けられる性質のものではない。案1は40ステップの繰り下げが
  `update-handoff-progress.sh` のループ範囲定数・HANDOFF進捗表・rules/spec の複数箇所へ波及し、
  コストが内容に見合わない。案2は「Draft解除の直前」という位置づけと矛盾する。
- **flow-id 5-2 は残し、「最終ゲート」へ意味づけを変えた。** 監視は実行環境の機能とセッションの
  寿命に依存するため、必ず通るゲートが1つ無いと「監視が動かないまま Draft解除へ進む」経路が
  できてしまう。5-2 を消す案は採らなかった。
- **自動解消の基準を「解消方法が一意に決まるか」に一般化できた。** issue #88 が挙げた A/C/D と
  同じ基準で類型Bも自動解消に入る（「管理外にした側を採用する」と規則が確定しているため）。
  類型Cだけは条件付き（散文が両側で書き換わり矛盾する場合はEへ回す）とした。
- **セッション依存という制約への手当てを、リポジトリ側に残せる形にした。** 購読・自己チェックインは
  セッションが終われば消えるが、`HANDOFF.md` のヘッダ1行と `resume`（`issue-mr-resume` エージェント）
  の報告項目にすれば、次のセッションが必ず読む場所に監視状態が残る。issue #88 が問題視した
  「リポジトリのAIアセットには何も残らない」への直接の回答になる。
- **差し込み位置は「レビュー完了合図の確認」節と「defaultブランチとのコンフリクト検知・解消
  （flow-id 5-2）」節の間にした。** 直前の節が箇条書きで終わっており、節全体にかかる地の文が
  無いことを確認済み（`.claude/rules/docs-workflow.md`「既存ドキュメントへ新しい見出しを
  差し込むとき」）。差し込み後、前後3行を目視して空行の崩れが無いことも確認した。
- **検証はすべて通った。** 単体テスト7本（`passed` 合計229 / `failures=0`）、
  `extract-frontmatter.sh .` の再生成（`failed=0`）。今回の変更はmarkdownのみで `.sh` を触って
  いないため `bash -n` の対象は無い。

## ダメだったこと

- **`check-base-conflicts.sh` へ「defaultブランチが何コミット進んだか」を足す案は見送った。**
  監視の判断に必要なのは `hasConflict` だけで、behind件数は行動を変えない（衝突が無ければ
  squash merge が吸収する）。スクリプト・spec・単体テストの変更を伴う割に得るものが無いため、
  今回はドキュメント整備に絞った。
- **GitHubの "Update branch"（`mcp__github__update_pull_request_branch`）で自動追従する案は却下した。**
  gitが検知できない類型A（DDR番号の重複）を**無言でマージしてしまう**ため、むしろ検知の機会を
  奪う。過去4件のコンフリクトはすべて類型Aだった（DDR 0029）。
- **hook（PostToolUse / SessionStart）での自動チェックも見送った。** DDR 0029 が却下した理由
  （pushのたびの `git fetch` はコストに見合わない・push検知hookは部分一致で誤発火する）が
  そのまま当てはまる。監視の頻度は「イベントが来たとき」であって「pushのたび」ではない。

## 設計反映（フェーズ4）

- DDR番号は `0039` が空き（最新は0038）であることを `ls .claude/docs/ddr/` で確認して採番した。
  flow-id 5-2 の `check-base-conflicts.sh` で `hasDuplicateDdrNumber` を再確認する。
- **DDR 0029 を `status: superseded` にはしなかった。** 無効化されるのは決定6（必ず承認を取る）の
  うち監視モードに限った範囲で、DDR 0029 全体は有効なままだからである
  （`.claude/rules/markdown-frontmatter.md` の `superseded` は全体が置き換わった場合の仕組み）。
  代わりに新DDR側へ「どの決定をどの範囲で緩和したか」を明記した。
- `.claude/docs/spec/check-base-conflicts.md` の「hookによる自動実行はしていない」は、
  そのままだと「コンフリクトはマージ依頼の直前にだけ確認できればよい」という理由づけが本issueの
  結論と矛盾するため、理由をコスト・誤発火に限定し、監視から繰り返し呼ばれる旨の項を足した。
  **スクリプト自体は変更していない**（作業ツリーを変えず、何度でも実行でき、結果を終了コードでは
  なく `hasConflict` で返す既存の設計が、そのまま繰り返し実行に使えたため）。
- 検証: `extract-frontmatter.sh .`（`failed=0`）、単体テスト7本（`failures=0`）、
  DDR番号の重複なし（`ls | uniq -d` が空）。

## 次の一歩

- フェーズ5: `plans/` `worklog/` の削除・`HANDOFF.md` のリセット（flow-id 5-1）→
  コンフリクト検知（5-2）→ リモートへ反映。
