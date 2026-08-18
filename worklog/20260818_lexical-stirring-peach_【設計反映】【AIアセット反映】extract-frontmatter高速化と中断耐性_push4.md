---
title: worklog 20260818 extract-frontmatter設計反映・AIアセット反映 push4
type: log
description: issue #11 フェーズ4（反映）の個別反映計画作成と、その過程で見つかったspecの記述誤りの記録（push4）
tags: [worklog, extract-frontmatter, 設計反映]
keywords: [個別反映計画, spec, ddr, リンク切れ, 0008, shell-scripts, flow-id 5-1, index.jsonl, AIアセット]
---

# worklog: 【設計反映】【AIアセット反映】extract-frontmatter高速化と中断耐性

対象: issue #11 フェーズ4（反映）の計画立案（2026-08-18）。
全体作業計画: `plans/lexical-stirring-peach.md`
個別反映計画: `plans/【設計反映】【AIアセット反映】extract-frontmatter高速化と中断耐性.md`
push回数: 4

## 試したこと

### flow-id 3-10（MR description更新）

未解決スレッドが0件であることを `get_mr_unresolved_comments 19 true` で再確認したうえで
（返ってきたのは自動投稿の対応工数レポート4件のみ、`threadId=` を含む行は0件）、
PR #19 のdescriptionをフェーズ3完了時点の内容へ更新した。

- `get_mr_unresolved_comments` の出力は**JSONではなく人間可読テキスト**であるため、
  `jq` へ直接パイプすると `parse error: Invalid numeric literal` になる。件数確認は
  `grep -c '^\[comment\]'` / `grep 'threadId='` で行う。
- `get_mr_for_branch` は**JSONオブジェクト**を返すため、MR番号は `| jq -r '.number'` で取り出す
  （生の番号ではない。前セッションでも同じ点を踏んだ）。

### flow-id 4-1（個別反映計画の作成）

反映元となる確定事項をA〜Iとして整理し、設計反映（spec更新・DDR新設）とAIアセット反映
（rules 2件・SKILL 1件・docs-workflow 1件）に割り付けた。種別は**併記**とした
（同じ実装結果から導かれるドキュメント更新で、分けても合意の単位が変わらないため）。

## うまくいったこと

- **反映先の実在確認をこの段階で済ませた**。計画に書いたパスを実際に `ls` で確認したところ、
  既存specに**2件の記述誤り**が見つかった。反映作業に入ってから気づくより早く拾えた。
  - `.claude/docs/spec/extract-frontmatter.md` の未決定事項が
    `.claude/scripts/docs/spec/shell-scripts.md` を参照しているが、**実体は
    `.claude/docs/spec/shell-scripts.md`**（issue #24 の移動時に現在状態を説明する節が追随して
    いなかった）。
  - 同specが2箇所で参照する `../ddr/0008-frontmatter抽出スクリプトの設計判断.md` が
    **このリポジトリに存在しない**（DDRは 0003〜0020 で、0008・0015 が欠番。移植元から
    持ち込まれていない）。新設するDDR 0021 へ参照を差し替える方針とした。
- 新設DDRの番号は既存の最大 `0020` の次で **`0021`** と確定した。

## ダメだったこと

- 特になし。

## 次の一歩

- flow-id 4-2: 個別反映計画・worklog push4・HANDOFF.md をcommitし、pushしてレビュー依頼（push4）。
- flow-id 4-6: 計画に沿って spec 更新・DDR 0021 新設・rules/SKILL への追記を行う。
- **flow-id 5-1 で `plans/index.jsonl` も削除する**（レビュー合意済み。4-6でSKILL.mdへ手順を追記する）。

---
