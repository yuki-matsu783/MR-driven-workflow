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
   説明から始まる）。**`【設計反映】`（フェーズ4）との境界も同時に書く**。追記する文面（案）:
   「設計ドキュメント（usecase文書等）を**そのissueの主たる成果物として**新規作成・改訂する
   場合もこの種別に含む（issue #170の実績）。作業の過程で得た知見を既存のspec/ddrへ書き戻す
   のは `【設計反映】`（フェーズ4）の担当であり、この種別には含めない」。
2. **導入系ドキュメントのmanifest方式への追随**（mainマージにより対象を変更）: mainの
   issue #26（PR #154）で配布の単一の正が `.claude/dist-layers.json`（5層）へ移り、
   `apply-mr-workflow-to-project` SKILL.md は「何をどう配るかをこのファイルへ書かない」方式へ
   変わった。`.claude/docs/`（usecase含む）は `core` 層の `.claude` エントリに含まれ、配布される
   ことが定義上保証される。当初予定の「SKILL.mdの適用資産一覧へ `.claude/docs/` を明記」は、
   **明記先の一覧自体が新設計で禁止されたため行わない**（フェーズ3レビューへの返信で約束した
   「根拠を正史側へ持たせる」は、dist-layers.json の `.claude` エントリが既に果たしている）。
   代わりに、usecase文書「この機構を他プロジェクトへ導入する」の記述・リンクを
   manifest方式へ追随させる（配布の正が dist-layers.json であること・`.gemini/` は配らず
   インストーラが配布先で生成すること・詳細リンクへ `asset-distribution.md` を追加すること）。
3. **`.claude/VERSION` の増分**: 配布対象アセットが増えたため、`0.2.0` → `0.3.0`（MINOR:
   資産の追加）を**提案する**。増分の決定は人間の担当（`distribution-assets.md`）のため、
   非対話セッションでは**書き換えを実施しない**。提案は最終応答・HANDOFF「未解決の内容」へ
   記録し、判断を人間へ委ねる。
4. **据え置きの事実をspecのchangelogへ残す**: `distribution-assets.md`「`.claude/VERSION`」節の
   規約「据え置く場合は、そのissueのspecのchangelogへ据え置いた事実を残す」に従い、同specの
   changelogへ issue #170 のエントリとして「0.2.0のまま据え置き（0.3.0への増分は提案のみ。
   人間の決裁待ち）」と理由を追記する（最終応答・HANDOFFはマージ後に残らないため、mainへ残る
   記録はここが唯一になる）。

## やらないこと（スコープ外）

- `.claude/VERSION` の書き換え（上記のとおり人間の決裁事項）。
- `.gemini/` 配下の手動更新（flow-id 5-3 の変換同期が正）。

## 検証（実行できるコマンドと合格条件）

```bash
# 1. 種別定義に設計ドキュメントへの言及がある（出力1以上で合格。実施前は0であることを確認済み。
#    汎用語 '設計ドキュメント' はSKILL.md内に既出1件があり空振り合格するため使わない）
grep -c '設計ドキュメント（usecase' .claude/skills/issue-mr-flow/SKILL.md
# 2. 導入usecase文書がmanifest方式へ追随している（出力1以上で合格。実施前は0であることを
#    2026-08-23のmainマージ直後に実測済み）
grep -c 'dist-layers' .claude/docs/usecase/この機構を他プロジェクトへ導入する.md
# 3. VERSIONが書き換わっていない（非対話セッションで人間の決裁が無いまま進めた場合、
#    0.2.0 のままで合格。人間が増分を承認した場合はその値で合格。現在値0.2.0は2026-08-23に実測）
cat .claude/VERSION
# 4. 据え置きの事実がspecのchangelogへ残っている（出力1以上で合格。実施前は0を確認済み）
grep -c '0.2.0のまま' .claude/docs/spec/distribution-assets.md
```
