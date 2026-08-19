---
title: 【AIアセット反映】REVIEW-POINTSの運用ルールとshellの落とし穴
type: plan
description: issue #77 の個別反映計画（AIアセット反映）。REVIEW-POINTS.mdの型・配置・ライフサイクルをrulesへ明文化し、実装中に踏んだshellの落とし穴を反映する。
tags: [issue-mr-flow, rules, review-points, ai-asset]
keywords: [AIアセット反映, REVIEW-POINTS, review-points, frontmatter, ライフサイクル, flow-id 5-1, MSYS_NO_PATHCONV, jq, shell-script-style]
---

# 【AIアセット反映】REVIEW-POINTSの運用ルールとshellの落とし穴

- issue: [#77](https://github.com/yuki-matsu783/MR-driven-workflow/issues/77)
- 全体作業計画: `plans/prancy-herding-kahan.md`
- flow-id: 4-1〜4-10（**2セット目**）

## この計画の範囲

1セット目〈設計反映〉（`plans/【設計反映】敵対的レビューのspecとDDR.md`、flow-id 4-1〜4-9で合意済み）は
「何を作ったか」を正史へ記録した。本計画は**作業中に気づいたルール・スキルの不備**を
`.claude/rules/` `.claude/skills/` へ反映する。

`.claude/docs/spec/` `.claude/docs/ddr/` は触らない（1セット目で完了済み）。

## 1. `REVIEW-POINTS.md` の運用がどのrulesにも書かれていない（**最優先**）

issue #77 で `REVIEW-POINTS.md` という**新しい種類のファイル**を4つ追加したが、
`.claude/rules/` のどのファイルにも記載が無い（`grep -c REVIEW-POINTS` が
`directory-structure.md` `docs-workflow.md` `shell-script-style.md` すべて 0）。
仕様は `.claude/docs/spec/adversarial-review.md` にあるが、**rulesを読んで動くAIエージェントからは
見えない**。

### 1-a. `.claude/rules/docs-workflow.md` — ライフサイクル表への追加（**これが最も危険**）

現在の同ファイルは「`plans/` `worklog/` `reports/` の3つは、いずれもflow-id 5-1でまとめて削除する」と
書いている。**`plans/REVIEW-POINTS.md` と `reports/REVIEW-POINTS.md` はこのディレクトリ配下にあるが、
削除してはならない恒久ファイルである。** 明文化しないと、次のタスクのflow-id 5-1でディレクトリごと
消える。

- ライフサイクル表へ `<ディレクトリ>/REVIEW-POINTS.md` の行を1つ足す
  （対象: 人間＋AI／寿命: **永続（最新状態）**／内容: そのディレクトリ配下に適用するレビュー観点／
  運用: 敵対的レビュー・人間のレビューが参照。**flow-id 5-1の削除対象に含めない**）。
- 「3つはflow-id 5-1でまとめて削除する」と書いている段落へ、**例外は `REVIEW-POINTS.md` だけ**である
  ことを明記する。
- 挿入位置は、直前の節の地の文の係り先を壊さない場所を選ぶ（同ファイル「既存ドキュメントへ
  新しい見出しを差し込むときは」の注意）。

### 1-b. `.claude/skills/issue-mr-flow/SKILL.md` — flow-id 5-1の記述

全体フロー表の 5-1 は「`plans/` `worklog/` `reports/` を削除し」とだけ書いている。
**`REVIEW-POINTS.md` は削除しない**旨を1行加える（詳細は docs-workflow.md 側を正とし、ここは短い
但し書きに留める）。

### 1-c. `.claude/rules/directory-structure.md` — 配置ルール

- ツリー図へ `REVIEW-POINTS.md` を書き加える（`plans/` `reports/` `.claude/` とルート直下）。
- 「配置の指針」へ、**各ディレクトリ直下に置き、そのディレクトリ配下すべて（孫以下を含む）に
  適用される／収集は祖先方向へ遡る**という配置の意味を1〜2文で書く。
  収集アルゴリズムの詳細は `.claude/docs/spec/adversarial-review.md` を参照させ、重複させない。

### 1-d. `.claude/rules/markdown-frontmatter.md` — `type` の値

`type` の値の表に `review-points`（対象: `**/REVIEW-POINTS.md`）を追加する。同ファイルは
「新しいディレクトリ・用途が増えた場合はこの表に追記する」と自ら書いており、その手順の実行にあたる。

## 2. `.claude/rules/shell-script-style.md` — 実装中に踏んだ落とし穴

**恒久的に有用なものだけを入れる。** このファイルは既に長く、セッション固有の事故を全部書くと
規約として読まれなくなるため、次の基準で選別した。

| 落とし穴 | 反映するか | 理由 |
|---|---|---|
| `export MSYS_NO_PATHCONV=1` した状態では、WindowsネイティブjqがMSYS形式のパス（`/c/Users/...`）を開けない | **する** | 既存の「git bashのパス変換の落とし穴」節が `MSYS_NO_PATHCONV=1` を推奨しているため、**その推奨に副作用があることを同じ節に書かないと、規約どおりに書いて壊れる**。docker操作用のexportをjqを使う処理と同じシェルへ広げない、という形で書く |
| 長いヒアドキュメントをBashツールへ渡すとパースに失敗することがある（150行規模）。長いファイル生成はWriteツールで行う | **する** | AIエージェント固有の制約だが、同ファイルには既に「AIエージェント向け注記」の前例がある。実際に本issueで複数回踏んだ |
| jq・perl・sedのパターン中のバックスラッシュが、ツール経由で1つに潰れることがある | **する** | 上と同じ理由。対策（正規表現は `[+]` のような文字クラスで書く／エスケープを含む修正はヒアドキュメント経由）まで書けるため実用的 |
| `sed` の置換文字列に `\n` を含むシェルコードを書かない | **しない**（既存へ1文追記に留める） | 同ファイル369行目に `\r` の同型の記述が既にある。**新しい節を作らず、その記述へ「`\n` も同様」と添える**（二重管理を避ける） |
| ファイルへの節の差し込みは範囲を `sed -n` で確認してから連結する | **しない** | 「差し込むファイルは先頭に空行を置かず末尾に空行を1つ」として既に書かれている |

## 3. スキル側の不備

作業中に気づいた範囲では、`adversarial-review` / `review-points` の両スキルに手直しの必要は無い
（実機検証を経て署名の追加まで済んでいる）。**この節は「確認したが変更なし」の記録**であり、
レビューで指摘があれば追加する。

## 4. `worklog/` `reports/` の削除は本計画では行わない

1セット目の計画では「AIアセット反映の完了後に削除する」としていたが、`main` を取り込んだ結果、
現行の `.claude/rules/docs-workflow.md` は**削除タイミングをflow-id 5-1と定めている**
（1セット目の計画を書いた時点のローカルの記述は「PR作成前の設計反映」だった）。
したがって削除は**フェーズ5（5-1）で行う**のが正しく、本計画の範囲外とする。

- 削除対象から外すもの: `plans/REVIEW-POINTS.md`, `reports/REVIEW-POINTS.md`（項目1-aで明文化する）。

## 検証

```bash
bash .claude/scripts/src/extract-frontmatter.sh .     # 変更したrulesのfrontmatterが拾えること
for t in .claude/scripts/test/test_*.sh; do bash "$t"; done   # 既存テストが壊れていないこと
grep -rn "REVIEW-POINTS" .claude/rules/ .claude/skills/issue-mr-flow/SKILL.md   # 記載漏れの確認
```

- rules はドキュメントのみの変更のため、スクリプトの挙動は変わらない。
- `test_post_issue_create_notice.sh` の1件失敗は `main` 由来の既存不具合（issue #94）であり、
  本計画では直さない。

## スコープ外

- `.claude/docs/spec/` `.claude/docs/ddr/` の変更（1セット目で完了済み）。
- 敵対的レビュー機構自体の実装変更。
- issue #94（`test_post_issue_create_notice.sh` のCR混入）の修正。
- `worklog/` `reports/` の削除（flow-id 5-1で行う）。
