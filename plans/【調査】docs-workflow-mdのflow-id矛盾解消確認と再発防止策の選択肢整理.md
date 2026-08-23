---
title: 個別調査計画 docs-workflow-mdのflow-id矛盾解消確認と再発防止策の選択肢整理
type: plan
description: issue #143が報告したdocs-workflow.mdのreports/行flow-id矛盾が現在も残っているかを最終確認し、再発防止策の選択肢を整理する個別調査計画
tags: [docs-workflow, flow-id, 調査, 再発防止]
keywords: [docs-workflow.md, SKILL.md, flow-id, reports, 矛盾, 再発防止策, DDR, issue143]
---

# 個別調査計画: docs-workflow.mdのflow-id矛盾解消確認と再発防止策の選択肢整理

## 目的

issue #143の受け入れ条件を満たすため、次の2点を調査する。

1. issueが報告した「`reports/`行の運用欄がflow-id 5-1のままで、寿命欄・直後の注記と矛盾している」
   問題が、現在の`main`ブランチ（本ブランチの分岐元）で実際にどうなっているかを最終確認する。
2. 「再発防止策の要否を検討し、結論を記録する」という受け入れ条件を満たすため、再発防止策の
   選択肢を整理し、比較材料をまとめる。

## 調査対象・方法

### (a) 矛盾の現状確認

- `.claude/rules/docs-workflow.md`全文を対象に、`reports/`の2行（md/html）を含む「片付け」関連の
  記述が指すflow-id番号を洗い出す。
- `.claude/skills/issue-mr-flow/SKILL.md`のflow-idテーブル（38〜97行目）を正として、上記の番号が
  一致するか突合する。
- `git log`で、いつ・どのPRでこの箇所が変更されたかを確認する（issue #143自体が起票された経緯と、
  その後の変更履歴を時系列で押さえる）。
- 過去の同型事案（issue #51）の対応記録（`.claude/docs/spec/issue-mr-workflow.md`のchangelog節）を
  参照し、今回との異同を整理する。

### (b) 再発防止策の選択肢整理

- `.claude/scripts/src/` `.claude/hooks/`配下を確認し、flow-id参照の横断的な整合性を機械的に検証する
  既存の仕組みが無いことを再確認する。
- `.claude/docs/ddr/i0112-01`（フェーズ5並べ替えのDDR）の却下案を確認し、「機械的検知の仕組みを
  作らず変更範囲を最小化する」という既存方針の妥当性を、今回実際に追従漏れが起きた事実を踏まえて
  再検討する。
- 選択肢を最低3案（機械的検知スクリプト新設／手順明記＋DDR記録／現状維持）で比較し、実現コストと
  実効性を軸に整理する。

## やらないこと

- `.claude/docs/spec/` `.claude/docs/ddr/`の過去changelog・DDR本文の書き換えは行わない
  （issue #143の受け入れ条件）。
- 矛盾が実際には解消済みであるため、`docs-workflow.md`本体への修正は本調査の対象に含めない
  （修正が必要と判明した場合はフェーズ3で扱う）。

## 検証手順

- `grep -rn "flow-id 5-1\|flow-id 5-3" .claude/rules/docs-workflow.md`で、片付けの意味を持つ古い
  flow-id記述が残っていないことを確認する。
- `git log --oneline -p -- .claude/rules/docs-workflow.md`で該当箇所の変更履歴を確認する。
