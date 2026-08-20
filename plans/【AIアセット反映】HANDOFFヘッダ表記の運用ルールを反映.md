---
title: 【AIアセット反映】HANDOFFヘッダ表記の運用ルールを反映
type: plan
description: issue #66の個別反映計画（AIアセット反映）。docs-workflow.mdへヘッダ行の表記を、issue-mr-flow SKILL.mdへset-headerの失敗時の扱いを反映する
tags: [plan, update-handoff-progress, ai-asset]
keywords: [AIアセット反映, docs-workflow, SKILL.md, ヘッダ行, set-header, 無言の失敗, 運用ルール]
---

# 【AIアセット反映】HANDOFFヘッダ表記の運用ルールを反映

対象issue: [#66](https://github.com/yuki-matsu783/MR-driven-workflow/issues/66)（flow-id 4-1）
実装結果: `reports/2026-08-20_set-header-silent-failure_実装結果.md`

**この計画には結果を書かない。** 結果は
`reports/2026-08-20_set-header-silent-failure_反映結果.md` へ書く（設計反映と同じファイルへ、
節を分けて書く）。

`【設計反映】` とは分ける（原則併記しない）。設計反映（spec/DDRへの記録）を終えてから着手する。

## 洗い出した反映対象

| ファイル | 反映する内容 |
|---|---|
| `.claude/rules/docs-workflow.md` | HANDOFF.md の行に、**ヘッダ行の表記は `.claude/docs/spec/update-handoff-progress.md`「HANDOFF.mdのヘッダ行」が正**であることへの参照を1行足す。表記そのものは再掲しない（二重管理を避ける） |
| `.claude/skills/issue-mr-flow/SKILL.md` | `set-header` が**失敗しうる**こと、失敗したらHANDOFF.mdのヘッダ行を正しい表記へ直してから再実行することを、`update-handoff-progress.sh` へ委譲している節へ1〜2行で足す |

## 反映しないもの（と、その理由）

- `.claude/agents/issue-mr-resume.md`。`- 現在のループ:` / `- 追従監視:` 行を**読む**だけで、
  表記が確定したことによる変更は要らない。
- `.claude/rules/shell-script-style.md` への新しい教訓の追加。今回踏んだのは
  「探索範囲を限定していない」「一致件数を数えていない」という設計上の抜けで、
  **bash固有の罠ではない**。同ファイルはbash固有の罠を集めた場所なので、混ぜない。
  - ただし、テストを書く過程で**自分のテストヘルパーが同じ形の欠陥（ファイル全体を `grep`）を
    持っていた**ことは、`.claude/REVIEW-POINTS.md` の観点として足す価値があるかを検討する。

## この計画で判断すること

- `.claude/REVIEW-POINTS.md`（`.claude/` 配下のレビュー観点）へ、
  **「書き換え・検索の対象範囲が、意図した範囲に限定されているか」「対象が見つからなかった場合に
  エラーになるか」**という観点を足すか。
  - 足す場合は「テスト」節ではなく「スクリプトの作法」節へ置く（テストだけの話ではないため）。
  - 観点表は既に長いので、既存の観点で言い換えられるなら足さない。

## 検証手順

```bash
bash .claude/scripts/src/extract-frontmatter.sh .
bash .claude/scripts/test/test_collect_review_points.sh
bash .claude/scripts/test/test_search_frontmatter.sh
```

- 参照先のパス・節名が実在すること（リンク切れを作らない）。
- 同じ内容を複数ファイルへ重複して書いていないこと
  （`REVIEW-POINTS.md`「同じ内容が複数ファイルに重複して書かれていないか」）。
