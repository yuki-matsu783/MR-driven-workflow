---
title: 【設計反映】gemini生成対象の判断をspec・DDRへ反映
type: plan
description: フェーズ3で決着した論点1〜3（自立化の却下・読まれない4ディレクトリの現状維持・.agents/skillsエイリアスの不成立）を.claude/docs/spec/sync-gemini-assets.mdと新規DDR i0172-01へ反映する個別反映計画（フェーズ4・1回目）
tags: [plan, gemini, sync-gemini-assets, 設計反映]
keywords: [反映, spec, DDR, i0172-01, 論点1, 論点2, 論点3, generate-ddr-list, check-doc-references]
---

# 【設計反映】gemini生成対象の判断をspec・DDRへ反映

issue #172（スコープ拡大後）／PR #193／フェーズ4〈反映〉の1回目。
フェーズ3で決着した3論点を `.claude/docs/spec/sync-gemini-assets.md` と新規DDRへ反映する
（**判断の結果そのものはフェーズ3で確定済み**。この計画は反映先・反映内容の洗い出しのみを行う。
issue #87「計画と実施結果の分離」）。

## 材料（すでに実施済みの判断・報告から）

- `wip/reports/20260823_mellow-drifting-lantern_gemini生成対象の採否.md`
  （サマリ結論1〜11、「設計への反映」節が反映対象の一次リストを持つ）
- `wip/plans/mellow-drifting-lantern.md`「スコープ拡大」節（論点1の決着記録）
- 現行 `.claude/docs/spec/sync-gemini-assets.md`（「未決定事項・懸念点」節に既存の3項目がある）

## この計画で決めること・洗い出すこと

### 反映対象1: `.claude/docs/spec/sync-gemini-assets.md`

- 「影響範囲」節へ **issue #172（新規追加）** の項を立てる。反映する内容:
  - 論点1（自立化）: 却下。`.claude/` への依存を明示する方針を維持（ユーザー判断）。
  - 論点2（`rules/` `docs/` `hooks/` `scripts/` の4ディレクトリ）: 現状維持（4つとも残す）。
    4軸の適用結果・3つの決め手・軸2の「18件→1件」の性質差（消える17件と残る1件の違い）を
    要約する。
  - 論点3（`.agents/skills/` エイリアス）: 不成立（Claude Code 公式ドキュメントに `.agents`
    の言及が0件）。
  - いずれも **Gemini CLI 実機・ソースコードは未検証** という制約を明記する
    （既存の「未決定事項・懸念点」節の1項目目と重複させず、issue #172 の文脈として書く）。
- 「未決定事項・懸念点」節へ、論点2の「外す根拠の有無」が未確定であることと、再検討の条件
  （ソースコード参照可能な別環境が用意されたら再検討）を追記する。

### 反映対象2: 新規DDR `i0172-01`

- 「却下した案」節: 案2（hooks/scripts/だけ外す）・案3（3つとも外す）・4ディレクトリ版の
  除去案・`.agents/skills/` エイリアス案の4つを却下理由付きで記録する。
- 「採用した理由」節: 3つの決め手（配布物は減らない／部分除去は中間状態になる／外す根拠は
  未観測の推論）と、rules/追加後の再評価結果（決め手2は弱まらない、むしろ落ちる割合は増える）。
- 「受け入れた制約」節: Gemini CLI 実機・ソースコード未検証のまま判断したこと。
- 「再検討の条件」節: 採否レポートの4条件をそのまま引く。
- 枝番は `01`（このissueで最初のDDR）。

### 反映対象3: 採否レポートがフェーズ4へ送った残り4項目

採否レポート「設計への反映」6〜8、2回目調査「設計への反映」6が個別に指定していた4項目。
洗い出し漏れを防ぐため、ここへ1項目ずつ書き起こす。

- **(a) 結論7（installerが失敗を警告のみで飲み込む）の扱い**: 「案1を採ったので実害が無い、
  ではない」（採否レポート6）。現行の弱点として `.claude/docs/spec/sync-gemini-assets.md`
  「未決定事項・懸念点」へ記録するに留め、installer側の改善（終了コードを非0にする／
  復旧案内へ `--force` を足す）は別issue化を検討する（本issueのスコープ外）。
- **(b) 変更しないコメント3箇所の明記**: `.claude/rules/directory-structure.md:50`・
  `.claude/docs/spec/sync-gemini-assets.md:96-97`・
  `.claude/scripts/test/test_install_to_project.sh:231` は、いずれも「外す場合のみ要追随」
  という前提のコメントで、外さないと決めた以上**変更しない**（採否レポート7）。この計画で
  「洗い出したが触れていない」に見えないよう明記する。
- **(c) `.gemini/**/*.md` 内の `.claude/…` 表記（2,255件）の書き換え可否**: 変換規則
  そのものの変更に当たり、全体作業計画がスコープ外と定めた範囲。別issueへ送るか判断を
  記録するかを spec の「未決定事項・懸念点」へ記す（採否レポート8）。
- **(d) `install-to-project.sh` に `.gemini/` 生成のスキップ手段が無いこと**: 現行の制約
  として spec の「未決定事項・懸念点」へ記録する（2回目調査「設計への反映」6）。

### 反映対象4: 機械的な整合性チェック

- `bash .claude/scripts/src/generate-ddr-list.sh` を実行し、`.claude/docs/README.md` の
  DDR一覧へ `i0172-01` を反映する。
- `bash .claude/scripts/src/check-doc-references.sh` を実行し、参照切れが無いかを確認する。
  **既知の無関係な既存欠陥**（`i0127-01-….md:132` が旧DDRファイル名 `0037-….md` を参照して
  おり、issue #133 の改番で `i0044-01-….md` へ改名済みのため切れている）が検出される見込み。
  この欠陥は本issueのスコープ外・DDR本文不変の原則（`.claude/rules/docs-workflow.md`）により
  この場では修正しない。`mcp__ccd_session__spawn_task` で別タスクとして切り出す
  （採否レポート「設計への反映」5番の判断: 別issueへ切り出す）。

## 決めないこと

- Gemini CLI実機・ソースコードでの検証（フェーズ3から持ち越し。別環境へ委ねたまま）
- `i0127-01` の切れリンクそのものの修正（別タスクへ切り出すのみ。この場では直さない）

## 進め方

1. spec `.claude/docs/spec/sync-gemini-assets.md` を編集する
2. 新規DDR `i0172-01-....md` を作成する
3. `generate-ddr-list.sh` を実行する
4. `check-doc-references.sh` を実行し、結果を確認する。既知の無関係な欠陥は
   `spawn_task` で切り出す
5. 敵対的レビュー（フェーズ4・1回目、上限3回のうち1回目）を反映内容に対して実施する
6. HANDOFF更新、commit・push

## 検証

```bash
# specに反映されたことを確認する
grep -c '^### issue #172' .claude/docs/spec/sync-gemini-assets.md
# 期待値: 1

# 新規DDRが存在し、frontmatterのtypeがddrであることを確認する
ls .claude/docs/ddr/i0172-01-*.md
grep -c '^type: ddr' .claude/docs/ddr/i0172-01-*.md
# 期待値: いずれも1件

# DDR一覧・参照切れチェックが通ることを確認する
bash .claude/scripts/src/generate-ddr-list.sh
git diff --stat .claude/docs/README.md
bash .claude/scripts/src/check-doc-references.sh; echo "exit=$?"
```

合格条件: 上記いずれのコマンドも期待どおりの結果を返すこと。あわせて、spec・DDRの本文を
目視確認し、次を満たすこと。

- 論点1〜3すべての判断と理由が、spec・DDRのいずれかに反映されている
- 「Gemini CLI実機・ソースコード未検証」という制約が明記されている
- 却下した案（4つ）がDDRに記録されている
- 再検討の条件がDDRに記録されている

---

正文はこの md 側。issue #172 / PR #193。
