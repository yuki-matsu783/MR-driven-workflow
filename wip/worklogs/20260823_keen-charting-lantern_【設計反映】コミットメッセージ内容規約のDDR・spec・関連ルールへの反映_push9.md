---
title: 20260823 keen-charting-lantern 【設計反映】コミットメッセージ内容規約のDDR・spec・関連ルールへの反映 push9
type: log
description: フェーズ4の個別反映計画を作成した記録と、反映対象の現況調査。
tags: [worklog, ddr, spec, 反映]
keywords: [反映計画, DDR, i0185-01, VERSION, usecase, 参照整理, check-doc-references]
---

# push9: フェーズ4の個別反映計画を作成

## 反映対象の現況（計画を立てる前に調べた）

| 対象 | 現況 |
|---|---|
| `.claude/docs/ddr/` | `i0185-*` は**存在しない**（新規作成。直近は `i0184-01`） |
| `.claude/docs/spec/create-commit.md` | `## 影響範囲` に `issue #60` `issue #54` の2節。**issue #185 の節を足す** |
| `.claude/rules/git-workflow.md` | 「コミット運用」がコミットメッセージに触れるのは3箇所だが、**いずれも hook の誤検知回避と `git status` の確認**の話で、**内容規約への参照は無い** |
| `.claude/skills/resolve-conflict/SKILL.md:376` | 「コミットメッセージには『何を』『どう』解消したかを書く」— **新設節と同じ主張**を独立に書いている |
| `.claude/skills/issue-mr-flow/SKILL.md:229` | 「確認した結果をコミットメッセージへ必ず残す」— 同上 |
| `.claude/VERSION` | `0.3.0` |
| `.claude/docs/usecase/` | 8本のうち `新しい機能開発を始める.md:45` だけが `commit` スキルを指す。**「フロー中のコミットの唯一の経路」という書き方で、規約の中身に踏み込んでいない**ため更新不要 |

## 気づいたこと

**usecase文書が更新不要だったのは、リンクが「何をする機能か」しか書いていないためである。**
仕様の中身をusecase側へ写していたら、今回の規約変更で古くなっていた。
`.claude/rules/docs-workflow.md` が usecase について「手順詳細（コマンド列・手順番号）は書かず
spec/SKILL.mdへのリンクで参照する」と定めているのが効いている。

**逆に、`resolve-conflict/SKILL.md:376` と `issue-mr-flow/SKILL.md:229` は同じ主張を独立に
書いており、今回まさに二重管理になっていた。** どちらも「何を」「どう」を書けと言っているが、
新設節が定めた判定基準（2段階）は持っていない。参照を張って正の所在を1箇所へ寄せる。

## 計画で決めきらなかったこと

- **`.claude/VERSION` の増分**は `0.4.0`（MINOR）を案として置いたが、根拠にする
  `.claude/docs/spec/distribution-assets.md` の更新規則を**まだ読み直していない**。
  実施（flow-id 4-6）の冒頭で確認する。**規則を読まずに「振る舞いが変わるからMINOR」と
  決めるのは、規則がある場所で自分の直感を優先することになる。**
