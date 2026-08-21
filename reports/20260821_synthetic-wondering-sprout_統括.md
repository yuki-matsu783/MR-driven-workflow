---
title: 統括レポート - 個別計画のタスク種別を6種から8種へ拡張する（issue #110）
type: report
description: issue #110（タスク種別8種への拡張）ブランチ全体の最終統括レポート
tags: [issue-mr-flow, タスク種別, docs, 統括]
keywords: [タスク種別, AIアセット作成, 実装反映, 設計反映, DDR, i0110-01, 敵対的レビュー]
---

# 統括レポート: 個別計画のタスク種別を6種から8種へ拡張する（issue #110）

対象issue: #110　対象PR: [#152](https://github.com/yuki-matsu783/MR-driven-workflow/pull/152)

## 何を変えたか

個別計画（`plans/【種別】〜.md`）のタスク種別を6種から8種へ拡張した。

- **`【AIアセット作成】`（フェーズ3〈作業〉）**: そのissueの主たる成果物としてAIアセット（スキル・
  ルール・エージェント）を新規作成・改訂する作業。`.claude/scripts/`配下のスクリプトは実装コード
  と同じ性質を持つため対象外（`【実装】`/`【実装反映】`側で扱う）。
- **`【実装反映】`（フェーズ4〈反映〉）**: フェーズ3のレビュー往復ループ（3-6〜3-9）では解消し
  きれず持ち越した不具合について、記録（spec/ddr等）への書き戻しと実装コード・テストコードの
  修正をあわせて行う作業。`【設計反映】`とspec/ddrへの書き戻しという対象が重なりうるが、実装・
  テストの修正を伴うかどうかで使い分ける。

変更したファイル:

| ファイル | 変更 |
|---|---|
| `.claude/skills/issue-mr-flow/SKILL.md` | 種別一覧を8種へ拡張し、フェーズ帰属表・新種別2つの定義・併記/分割の指針を新設。flow-id 4-1/4-6の反映対象洗い出し・スキップ判定・作業内訳へ`【実装反映】`を追記 |
| `.claude/docs/spec/issue-mr-workflow.md` | 「計画の2階層構造」節を8種へ更新。「影響範囲」へissue #110のエントリを追加 |
| `.claude/rules/docs-workflow.md` | ライフサイクル表の種別列挙を8種へ更新 |
| `plans/REVIEW-POINTS.md` | レビュー観点を8種へ更新（成果物/副産物の使い分け・フェーズ3ループとの重複チェックを追加） |
| `.claude/docs/ddr/i0110-01-個別計画のタスク種別を6種から8種へ拡張する.md`（新設） | 意思決定の記録（定義・却下した代替案） |
| `.claude/docs/README.md` | DDR一覧を再生成（71件） |

フロー構造（5フェーズ・flow-id）自体の変更は無い。

## なぜそうしたか

- **`【AIアセット作成】`が無かった理由**: `【実装】`は実装コードを指すため、AIアセット（非コードの
  運用資産）の作成には合わない。
- **`【実装反映】`が無かった理由**: `【設計反映】`はspec/ddr、`【AIアセット反映】`は`.claude/rules/`
  等が対象で、実装コードの更新を扱う種別が無かった。
- **却下した代替案**（詳細: DDR `i0110-01`）:
  - 既存種別（`【実装】`・`【AIアセット反映】`）を流用する案 → 対象・成果物か副産物かの区別が
    曖昧になるため却下。
  - 種別を増やさずfree-textで書く案 → 機械的な列挙（`plans/【*.md`）・レビュー観点表との整合が
    取れなくなるため却下。
  - `【実装反映】`を「フェーズ4の設計反映作業中にAIが気づいた実装との差分」に限定する案 →
    Planレビューで「反映計画では立てられず、起きたら別issueで書く内容」として却下。
  - AIアセットの定義にスクリプトを含める案 → `.claude/scripts/`配下は実装コードと同じ性質を
    持つため、含めると`【実装】`/`【実装反映】`との境界が消える（敵対的レビューで指摘され除外）。

## 検証結果

```
$ grep -rn "6種" .claude plans --include="*.md" | grep -v "6種から拡張\|6種から8種"
```
対象4ファイル（`SKILL.md` / `issue-mr-workflow.md` / `docs-workflow.md` / `REVIEW-POINTS.md`）
本体には、8種の列挙以外の場所に「6種」の残存は無い（経緯注記・plans側の言及のみ残る。詳細:
`reports/20260821_synthetic-wondering-sprout_タスク種別8種への拡張.md`「検証結果」）。

```
$ grep -c "AIアセット作成\|実装反映" .claude/skills/issue-mr-flow/SKILL.md \
  .claude/docs/spec/issue-mr-workflow.md .claude/rules/docs-workflow.md plans/REVIEW-POINTS.md
.claude/skills/issue-mr-flow/SKILL.md:11
.claude/docs/spec/issue-mr-workflow.md:7
.claude/rules/docs-workflow.md:1
plans/REVIEW-POINTS.md:5
```
4ファイルすべてで新種別への言及を確認済み。

```
$ bash .claude/scripts/src/check-base-conflicts.sh
```
`hasConflict: false`（defaultブランチとのコンフリクト無し）。

**敵対的レビュー（フェーズ3・1回目）を実施し、major 10件の指摘をすべて修正した。** `【実装反映】`
の適用条件の自己矛盾、フロー本体（flow-id 4-1/4-6）への種別未反映、`【AIアセット作成】`が改訂を
扱えない欠落、AIアセット定義とスクリプトの境界問題、reportsの検証出力の不一致、HANDOFF.mdの
進捗表の不整合、spec影響範囲エントリの欠落など。minor/nitの6件も同時に修正した。詳細は
`reports/20260821_synthetic-wondering-sprout_タスク種別8種への拡張.md`「敵対的レビュー対応」節、
PR #152のインラインコメント10件を参照。

## spec・DDRへの反映先

- `.claude/docs/spec/issue-mr-workflow.md`: 「計画の2階層構造」節の種別列挙を8種へ更新し、
  「影響範囲」へissue #110のエントリを追加した。
- `.claude/docs/ddr/i0110-01-個別計画のタスク種別を6種から8種へ拡張する.md`: 2種別を追加した
  経緯・定義・却下した代替案を記録した。

## 残課題

- issue-mr-workflow.mdでフェーズ帰属の説明がSKILL.mdと部分的に重複している点（敵対的レビューで
  minor指摘。実害は小さいと判断し今回は据え置いた）は、将来SKILL.mdのフェーズ帰属を見直す際に
  合わせて整理するとよい。
- その他は無し。
