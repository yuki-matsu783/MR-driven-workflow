---
title: 個別調査計画 docs-workflow-mdのflow-id矛盾解消確認と再発防止策の選択肢整理
type: plan
description: issue #143が報告したdocs-workflow.mdのreports/行flow-id矛盾が現在も残っているかを最終確認し、再発防止策の選択肢を整理する個別調査計画
tags: [docs-workflow, flow-id, 調査, 再発防止]
keywords: [docs-workflow.md, SKILL.md, flow-id, reports, 矛盾, 再発防止策, DDR, issue143]
---

# 個別調査計画: docs-workflow.mdのflow-id矛盾解消確認と再発防止策の選択肢整理

## この計画で何をするか

issue #143の受け入れ条件を満たすため、次の2点を調べる。

1. issueが報告した「`reports/`行の運用欄がflow-id 5-1のままで、寿命欄・直後の注記と矛盾している」
   問題が、現在どうなっているかを最終確認する（結論は本計画には書かず、`reports/`へ記録する）。
2. 「再発防止策の要否を検討し、結論を記録する」という受け入れ条件を満たすため、再発防止策の
   選択肢を整理し、比較材料をまとめる。

## 変更対象

| ファイル | 操作 | 何をするか |
|---|---|---|
| `.claude/rules/docs-workflow.md` | 読み取りのみ | flow-id記述の現状確認（本計画では変更しない） |
| `.claude/skills/issue-mr-flow/SKILL.md` | 読み取りのみ | flow-idテーブル（`## 全体フロー`節）との突合 |
| `.claude/docs/ddr/i0112-01-…md` | 読み取りのみ | 既存の機械的検知見送り方針の確認 |
| `reports/20260823_linear-painting-pond_flow-id矛盾解消確認と再発防止策調査.md`（新規） | 新規 | 調査結果の記録先（正文） |
| `reports/20260823_linear-painting-pond_flow-id矛盾解消確認と再発防止策調査.html`（新規） | 新規 | 上記mdの視覚化ビュー（同時に作成する） |

## 方針

### (a) 矛盾の現状確認

- 現ブランチはこの時点で`docs-workflow.md`を変更していないため、作業ツリーの内容と
  `origin/main`の断面は一致する（`git show origin/main:.claude/rules/docs-workflow.md`で
  裏付けを取る）。
- `.claude/rules/docs-workflow.md`**全文**を対象に、`5-[0-9]`にマッチする全番号参照を列挙し
  （`flow-id`前置きの有無を問わない。裸の番号参照が実在するため）、件数と内訳を出す。
- 列挙した番号のうち片付け（`plans/` `worklog/` `reports/`の削除・HANDOFF.mdリセット）を指す
  ものが、SKILL.mdの現行テーブル（`## 全体フロー`節、5-4=片付け）と一致するかを1件ずつ突合する。
- **issueの受け入れ条件(1)は「flow-id 5-3を指している」ことを求めているが、現行のSKILL.mdでは
  5-3は「最終統括レポート作成」、5-4が「片付け」である。** この番号の食い違い自体が「issue起票後、
  さらにフェーズ5が繰り下がった」ことを示す可能性があるため、いつ・どのPRでこの繰り下げが
  起きたかを`git log --follow -p -- .claude/rules/docs-workflow.md`で確認し、受け入れ条件(1)を
  「5-3」ではなく「SKILL.mdの現行テーブルが片付けとして指す番号」と読み替えてよいかを調査結論の
  一部として明示する。
- **受け入れ条件(2)「他に残っていない」は`docs-workflow.md`1ファイルに閉じない。** リポジトリ
  全体を対象に`5-1`を含む記述を横断検索し、ヒットを次の3分類へ振り分ける。
  - コンフリクト解消の意味で使うflow-id 5-1（正当。SKILL.mdの現行テーブルどおり）
  - `.claude/docs/spec/` `.claude/docs/ddr/`の過去changelog・DDR本文（変更しない）
  - 片付けの意味でflow-id 5-1を使う現行記述（追従漏れ。あれば報告する）
- 過去の同型事案（issue #51）の対応記録（`.claude/docs/spec/issue-mr-workflow.md`のchangelog節）を
  参照し、今回との異同を整理する。

### (b) 再発防止策の選択肢整理

- `.claude/scripts/src/` `.claude/hooks/`配下を確認し、`docs-workflow.md`・`SKILL.md`内の
  flow-id参照の横断的な整合性を機械的に検証する既存の仕組みがあるか、あるとすれば何をどこまで
  検証しているかを調べる。
- `.claude/docs/ddr/i0112-01`（フェーズ5並べ替えのDDR）の却下案を確認し、「機械的検知の仕組みを
  作らず変更範囲を最小化する」という既存方針の妥当性を、今回実際に追従漏れが起きた事実を踏まえて
  再検討する。
- 選択肢を最低3案（機械的検知スクリプト新設／手順明記＋DDR記録／現状維持）で比較し、実現コストと
  実効性を軸に整理する。

## やらないこと（スコープ外）

- `.claude/docs/spec/` `.claude/docs/ddr/`の過去changelog・DDR本文の書き換えは行わない
  （issue #143の受け入れ条件(3)）。
- `docs-workflow.md`本体の修正は本調査の対象に含めない。修正が必要かどうかは(a)の調査結果として
  `reports/`へ記録し、要否の判断・実施はフェーズ3〈作業〉へ送る（本計画の時点では確認前であり、
  「修正が要らない」と断定しない）。
- 再発防止策の実装そのもの（判断はフェーズ3〈作業〉へ送る）。

## 検証

```bash
# (a) 全番号参照の列挙（flow-id前置きの有無を問わない）
grep -n -- '5-[0-9]' .claude/rules/docs-workflow.md

# mainの断面と作業ツリーが一致することの確認（本ブランチは未変更のはず）
diff <(git show origin/main:.claude/rules/docs-workflow.md) .claude/rules/docs-workflow.md

# 受け入れ条件(2): リポジトリ全体でのflow-id 5-1参照の横断確認（3分類に仕分ける）
grep -rn -- '5-1' --include='*.md' .

# 受け入れ条件(3): spec/ddrの過去changelogが変更されていないことの確認（削除行ゼロ）
git diff "$(git merge-base origin/main HEAD)" -- .claude/docs/spec/ .claude/docs/ddr/

# 変更履歴の確認（いつ・どのPRで繰り下げが起きたか）
git log --follow -p -- .claude/rules/docs-workflow.md
```

合格条件:
- 片付けを指す番号参照が、SKILL.mdの現行テーブルと1件ずつ突合できている（件数の根拠を明示）。
- リポジトリ全体で「片付け＝flow-id 5-1」と読める現行記述の有無が判定できている（3分類の内訳付き）。
- `git diff`の削除行が0であることを確認できている。
- 再発防止策の選択肢が最低3案、比較材料付きで整理できている。

## issueの受け入れ条件との対応

| 受け入れ条件 | この計画での対応箇所 |
|---|---|
| (1) `reports/…md` / `reports/…html`行の運用欄がflow-id 5-3を指している | 方針(a) 番号の読み替え確認＋全番号列挙 |
| (2) 「片付け＝flow-id 5-1」と読める現行記述が他に残っていない | 方針(a) リポジトリ全体の横断検索・3分類 |
| (3) spec/ddrの過去changelogが変更されていない | やらないこと／検証（git diffの削除行ゼロ確認） |
| (4) 再発防止策の要否が検討され、結論が記録されている | 方針(b) 選択肢整理 |
