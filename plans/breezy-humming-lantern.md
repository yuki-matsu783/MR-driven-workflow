---
title: 全体作業計画 issue #113 compact後もissue-mr-flow対象ブランチではSKILL.mdの再読み込みを促す
type: plan
description: SessionStart hookの注入テキストへSKILL.md再読み込み指示を足すissue #113の全体作業計画
tags: [plan, session-start-hook, compact, issue-mr-flow]
keywords: [issue113, SessionStart, compact, SKILL.md, 再読み込み, 対象ブランチ判定, 全体作業計画, 調査, 反映]
---

# 全体作業計画: issue #113 compact後もissue-mr-flow対象ブランチではSKILL.mdの再読み込みを促す

対象issue: [#113](https://github.com/yuki-matsu783/MR-driven-workflow/issues/113)
ブランチ: `claude/skill-md-reload-prompt-jy5z5i`

## ゴール

issue-mr-flowに乗っているブランチでcompactが起きたとき、SessionStart hookが注入する追加
コンテキストへ「`.claude/skills/issue-mr-flow/SKILL.md` を読み直すこと」という指示が含まれる
ようにする。対象外のブランチでは既存の挙動（不要な指示を注入しない）を変えない。

## 実行環境・フロー適用上の前提

- Claude Code on the web のリモート実行環境で、`gh`/`glab` CLIが無い（MCP経路）。
- 人間のレビュー往復（flow-id 2-3/2-8・3-3/3-8・4-3/4-8）を待てない非対話セッションのため、
  該当ループ範囲の進捗記号は `[]` のまま残し、実施内容は `HANDOFF.md` の「やったこと」へ
  文章で残す（`.claude/rules/docs-workflow.md` の規定）。
- ブランチ名がハーネス由来の `claude/<slug>` 形式で、`branchPrefixTemplate`
  （`feature-{issue}-{slug}`）に一致しない。**この状況自体が、対象判定をブランチ名だけに
  依存させてはいけない根拠**になる（後述）。

## フェーズ2〈調査〉

`.claude/rules/docs-workflow.md` の規定に従い、節は必ず置く。実施要否は flow-id 2-1 で判断する。

調べる対象は次の3点。

1. `session-start.sh` の現在の注入内容と、注入テキストの組み立て経路（CLI経路・MCP経路の分岐、
   `build_work_context` の位置づけ）。
2. 「issue-mr-flow対象ブランチ」を判定できる材料は何か。候補は
   (a) `get_issue_number_from_branch`（`branchPrefixTemplate` との照合）、
   (b) `get_branch_work_files`（`plans/` `worklog/` `reports/` のブランチ固有ファイル）、
   (c) `HANDOFF.md` の進捗表の有無。それぞれの取りこぼしと取得コストを比較する。
3. DDR 0032（compact後の再注入・注入量の肥大化検知）の設計方針と矛盾しない追加になっているか
   （注入量のしきい値・切り詰めない方針・起動要因で分岐しない方針）。

**判断**: 対象がすでに読み切れる規模（`session-start.sh` 約280行、DDR 0032、spec 1節、
既存テスト 249行）であり、上記3点は実装に先立つ数回の読み取りで確定できた。フェーズ2を
独立したレビュー往復として回さず、調査結果は本計画・個別作業計画・`reports/` に集約する。

## フェーズ3〈実装・テスト〉

- `session-start.sh` へ2つの純粋関数を足す。
  - `issue_mr_flow_branch_reason <issue番号> <作業ファイル一覧>`: 対象なら**判定根拠**を
    標準出力へ返し、対象外なら終了コード1。外部コマンドを呼ばない。
  - `format_skill_reload_instruction <判定根拠>`: 指示文を組み立てる。
- `build_work_context` に第1引数（ブランチ名）を持たせ、組み立ての**最後**に指示文を足す。
  呼び出し元2箇所（CLI経路・MCP経路）はブランチ名を渡すだけの変更にとどめる。
- 単体テストを `test_session_start.sh` へ追加する（判定の4パターン、指示文の内容、指示文の
  バイト数）。加えて、使い捨てリポジトリでhook本体を実際に走らせ、4つのブランチ状態
  （main／命名規則一致／命名規則外・作業ファイル無し／命名規則外・作業ファイル有り）で
  出力を目視確認する。

## フェーズ4〈反映〉

反映対象の洗い出しは flow-id 4-1 で行う。現時点の見込みは次のとおり。

- `.claude/docs/spec/issue-mr-workflow.md`「セッション開始時の自動コンテキスト注入」節へ、
  判定・指示文の仕様と、テスト可能な純粋関数の一覧を反映する。「影響範囲」へ issue #113 の
  エントリを追加する。
- 判定材料の選び方・却下案をDDRへ残す（番号は当時の最新の次。実際には 0059）。
- `.claude/docs/README.md` のDDR一覧へ追加する。
- AIアセット（`.claude/rules/` `.claude/skills/`）への反映は、今回の作業で新しく判明した
  規約違反・ルールの不備が無ければ不要と判断する。

## フェーズ5

コンフリクト検知 → 関連issue通知の要否判断 → 片付け → commit・push・Draft解除まで。
マージは行わない（ユーザーの明示指示があるまで）。

## 比較検討した案

対象判定・指示文の置き方について検討した案と却下理由は、DDR
`0059-issue-mr-flow対象ブランチではSKILL.mdの再読み込みを注入で促す.md` に集約する
（本計画では重複させない）。
