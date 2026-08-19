---
title: worklog 20260820 【AIアセット反映】REVIEW-POINTSの運用ルールとshellの落とし穴 push12
type: log
description: issue #77 のAIアセット反映（2セット目）の作業ログ。push12時点。個別反映計画の作成を記録する。
tags: [worklog, ai-asset, review-points, rules]
keywords: [AIアセット反映, REVIEW-POINTS, flow-id 5-1, 削除対象, MSYS_NO_PATHCONV, 選別, docs-workflow]
---

# worklog: 【AIアセット反映】REVIEW-POINTSの運用ルールとshellの落とし穴

対象: issue #77 で気づいたルール・スキルの不備を `.claude/rules/` `.claude/skills/` へ反映する（2026-08-20）。
全体作業計画: `plans/prancy-herding-kahan.md`
個別反映計画: `plans/【AIアセット反映】REVIEW-POINTSの運用ルールとshellの落とし穴.md`
push回数: 12

## 試したこと

- flow-id 4-8で「続けて」の合意を得たため、`comments all` で全スレッドを再取得して未解決が
  0件であることを確認してから、4-6〜4-9のループを1周完了とした（`.claude/docs/spec/issue-mr-workflow.md`
  「完了合図の確認」）。検証用に投稿していた5件も解決済みになっていた。
- flow-id 4-10でMR descriptionのフェーズ4節を「1セット目完了 / 2セット目へ」へ更新した。
- 2セット目の flow-id 4-1 として個別反映計画を作成した。反映候補は事前に実地で確認した。
  - `grep -c REVIEW-POINTS .claude/rules/*.md` → `directory-structure.md` `docs-workflow.md`
    `shell-script-style.md` すべて **0件**。
  - `.claude/rules/markdown-frontmatter.md` の `type` の値の表に `review-points` が**無い**。

## うまくいったこと

- **`REVIEW-POINTS.md` が次タスクのflow-id 5-1で消える危険を、計画の段階で捕まえられた。**
  `.claude/rules/docs-workflow.md` は「`plans/` `worklog/` `reports/` の3つはflow-id 5-1でまとめて
  削除する」と書いており、`plans/REVIEW-POINTS.md` と `reports/REVIEW-POINTS.md` はその配下にある。
  仕様は `.claude/docs/spec/adversarial-review.md` に書いたが、**rulesを読んで動くエージェントからは
  見えない**ため、ライフサイクル表への追加を最優先項目にした。
- **反映候補を「入れる／入れない」で選別し、理由を計画に表で残した。** shellの落とし穴は4件
  挙がったが、`sed` の `\n` は既存の `\r` の記述と同型のため新設せず1文の追記に留める、
  節の差し込み手順は既に書かれているため入れない、と判断した。ルールファイルが長くなるほど
  読まれなくなるため、増やすこと自体をコストとして扱った。
- **`main` を取り込んだことで、削除タイミングの認識が更新された。** 1セット目の計画を書いた
  時点のローカルの記述は「PR作成前の設計反映で削除」だったが、現行の `docs-workflow.md` は
  **flow-id 5-1** と定めている。結果として「AIアセット反映の完了後に削除」という当初の判断は
  現行ルールと整合しており、削除は本計画の範囲外（フェーズ5）とした。

## ダメだったこと

- **`.gitignore` に予期しない差分が出ていた。** ワーキングツリー側が issue #32 の修正
  （裸の `参考ディレクトリ` 行をコメント化した変更）を打ち消す内容になっており、そのまま
  コミットすると `main` の修正を巻き戻すところだった。`git checkout HEAD -- .gitignore` で戻した
  （マージコミット自体は `main` 側を正しく採っている）。**マージ後の最初のコミットでは、
  `git status` に出ているパスを機械的に全部渡さず、`git diff --cached` の中身を確認する**べきだった。

## 次の一歩

- flow-id 4-2（2セット目）: commit・pushしてレビュー依頼 → 4-3（人間のレビュー）。
- 合意後 4-6 で rules 4ファイル（+ SKILL.md 1行）へ反映する。

---
