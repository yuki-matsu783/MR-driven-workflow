---
title: 【AIアセット反映】種別定義と配布資産一覧の追記
type: plan
description: issue #170フェーズ4の個別反映計画（AIアセット反映）。SKILL.mdの【AIアセット作成】種別定義への設計ドキュメント追記・導入スキルの資産一覧への.claude/docs/明記・VERSION増分の扱い
tags: [usecase-docs, plan, ai-asset-reflect]
keywords: [AIアセット反映, 種別定義, AIアセット作成, apply-mr-workflow-to-project, 配布資産, VERSION, SemVer]
---

# 【AIアセット反映】種別定義と配布資産一覧の追記

- issue: #170 / PR: #173
- 全体作業計画: `plans/usecase-atlas.md`
- 作成日: 2026-08-23

## 前提（合意状況）

- 依拠する結果: フェーズ2敵対的レビューの報告のみ指摘2（種別根拠）・フェーズ3敵対的レビューの
  指摘（配布範囲の「正」の逸脱・VERSION受け皿欠落）。
- 上位の全体作業計画は flow-id 1-5 未合意のまま先行中。

## 反映対象（洗い出しの結果）

1. **種別定義への追記**: `.claude/skills/issue-mr-flow/SKILL.md`「計画の2階層構造」の
   `【AIアセット作成】` の定義（スキル・ルール・エージェント）に、今回のような
   **設計ドキュメント（usecase文書等）の新規作成・改訂**も含まれることを明記する
   （issue #170で実際にこの種別を使った実績の追認。定義に無いままだと次回また選定根拠の
   説明から始まる）。
2. **導入スキルの資産一覧への明記**: `.claude/skills/apply-mr-workflow-to-project/SKILL.md` の
   適用資産の記述へ、`.claude/docs/`（spec・ddr・usecaseの設計ドキュメント一式）が `.claude/`
   丸ごとコピーに含まれることを明記する（usecase文書「この機構を他プロジェクトへ導入する」の
   記述の根拠を正史側へ持たせる。フェーズ3レビューへの返信で約束した対応）。
3. **`.claude/VERSION` の増分**: 配布対象アセットが増えたため、`0.2.0` → `0.3.0`（MINOR:
   資産の追加）を**提案する**。増分の決定は人間の担当（`distribution-assets.md`）のため、
   非対話セッションでは**書き換えを実施しない**。提案は最終応答・HANDOFF「未解決の内容」へ
   記録し、判断を人間へ委ねる。

## やらないこと（スコープ外）

- `.claude/VERSION` の書き換え（上記のとおり人間の決裁事項）。
- `.gemini/` 配下の手動更新（flow-id 5-3 の変換同期が正）。

## 検証（実行できるコマンドと合格条件）

```bash
# 1. 種別定義に設計ドキュメントへの言及がある（出力1以上で合格。実施前は0であることを確認済み。
#    汎用語 '設計ドキュメント' はSKILL.md内に既出1件があり空振り合格するため使わない）
grep -c '設計ドキュメント（usecase' .claude/skills/issue-mr-flow/SKILL.md
# 2. 導入スキルにusecaseを含む設計ドキュメント一式への言及がある（出力1以上で合格。
#    実施前は0であることを確認済み）
grep -c 'usecase' .claude/skills/apply-mr-workflow-to-project/SKILL.md
# 3. VERSIONが書き換わっていない（0.2.0 のままで合格。増分は人間の決裁待ち。
#    現在値0.2.0は2026-08-23に実測）
cat .claude/VERSION
```
