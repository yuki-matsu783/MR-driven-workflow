---
title: 【AIアセット作成】ユースケース文書一式と周辺更新
type: plan
description: issue #170フェーズ3の個別作業計画。usecase文書8本の新規作成と、frontmatter規約・README・SKILL.md・docs-workflow・ツリー系・観点表の更新
tags: [usecase-docs, plan, ai-asset]
keywords: [ユースケース, usecase, frontmatter, README, flow-id 4-6, docs-workflow, directory-structure, 観点表]
---

# 【AIアセット作成】ユースケース文書一式と周辺更新

- issue: #170 / PR: #173
- 全体作業計画: `plans/usecase-atlas.md`
- 作成日: 2026-08-23

## 前提（合意状況）

- 依拠する調査結果: `reports/20260823_usecase-atlas_調査結果.md`（flow-id 2-6。非対話セッションの
  ため人間レビュー（2-8）は未実施。敵対的レビュー2回（計24件の指摘を修正）で代替した）。
- 上位の全体作業計画は flow-id 1-5 未合意のまま先行中（扱いは全体作業計画「実行環境と運用の前提」）。
- 種別を `【AIアセット作成】` とする根拠は全体作業計画「フェーズ3〈作業〉」に記載
  （usecase文書一式はこのissueの主たる成果物で、`.claude/` 配下の恒久アセットであるため）。

## この計画で何をするか

調査結果の結論どおり、`.claude/docs/usecase/` にユースケース文書8本を新規作成し、
周辺6ファイル＋観点表1件を更新する。実装（`.sh`）の変更は無い。

## 変更対象

### 新規作成（`.claude/docs/usecase/` 配下・8本）

調査結果「問い1・2」の表のとおり（ファイル名・場面・リンク先はそちらが正）。

1. `新しい機能開発を始める.md`
2. `途中の作業を再開・引き継ぐ.md`
3. `生成物にレビューコメントして修正させる.md`
4. `レビューをAIに補助してもらう.md`
5. `ベースブランチとのコンフリクトを解消する.md`
6. `リポジトリ内のドキュメントを探す.md`
7. `対応工数を把握する.md`
8. `この機構を他プロジェクトへ導入する.md`

### 既存ファイルの変更（7件）

調査結果「問い7」の表のとおり（各変更の詳細はそちらが正）。

1. `.claude/rules/markdown-frontmatter.md` — 「typeの値」表へ `usecase` 行を追加
2. `.claude/docs/README.md` — 冒頭箇条書き＋usecase節（生成マーカー区間の外）＋frontmatter更新
3. `.claude/skills/issue-mr-flow/SKILL.md` — 4-6行「設計反映」項末尾へ影響確認を追記
4. `.claude/rules/docs-workflow.md` — 「ドキュメント運用」表へusecase行を追加
5. `.claude/rules/directory-structure.md` — ツリーへ `usecase/` 行を追加
6. `index.md` — Repository Mapへ `usecase/` 行を追加
7. `.claude/REVIEW-POINTS.md` — usecase文書の観点（手順詳細を再掲しない等）を追加

## 方針（各usecase文書の記述の型）

全8本を次の4見出しで統一する（issue #170「期待する動作」の構成そのまま）。

```
# <ユースケース名>
## どんな場面か
## 使う機能と流れの概要
## 何が得られるか
## 詳細へのリンク
```

- frontmatterは `type: usecase` とし、`title`/`description`/`tags`/`keywords` を必ず持たせる
  （`.claude/rules/markdown-frontmatter.md` の規約どおり。`resource` は対応する実リソースが
  無いため省略）。
- **手順詳細（コマンド列・手順番号・オプションの説明）は書かない。** 流れは「何をどの順で使うか」の
  散文1〜3文＋箇条書き程度に留め、手順の正であるspec/SKILL.mdへのリンクで参照する。
  コードブロック（```フェンス）は使わない（検証で機械的に確認する）。
- 1本あたり30〜60行程度を目安にする（概観に徹する。長くなるのは手順を書き始めた兆候）。
- リンクは相対パスで書き、実在をループで検証する（下記）。

## やらないこと

- spec/SKILL.md側の手順詳細の転記（上記のとおり禁止）。
- `.sh` スクリプトの変更（`Provider.sh` の不具合対応はフェーズ4の `【実装反映】` 候補）。
- 既存ドキュメントの再構成・移動。

## 検証（実行できるコマンドと合格条件）

```bash
# 1. ファイル数: 8 であること
ls .claude/docs/usecase/*.md | wc -l

# 2. frontmatter検索: usecase文書を1本作った直後から実測できる（未追跡でも載る）。
#    最終的に matched=8 であること
bash .claude/scripts/src/search-frontmatter.sh --type usecase --format count

# 3. README目次からの到達: usecase節のリンク先が全件実在すること（0件は不合格。件数も出す）
grep -o 'usecase/[^)]*\.md' .claude/docs/README.md | sort -u | \
  { n=0; ok=0; while IFS= read -r p; do n=$((n+1)); [ -f ".claude/docs/$p" ] && ok=$((ok+1)) || echo "missing: $p"; done; echo "links=$n exists=$ok"; [ "$n" -gt 0 ] && [ "$n" = "$ok" ]; }

# 4. 手順詳細の再掲なし（機械検査）: 各usecase文書のコードフェンス数が0であること
grep -c '^```' .claude/docs/usecase/*.md || echo 'フェンスなし'

# 5. usecase文書内のリンク先（.claude/…・ルートのmd）が全件実在すること
grep -ho '([^)]*\.md[^)]*)' .claude/docs/usecase/*.md | tr -d '()' | sed 's/#.*//' | sort -u | \
  { n=0; ok=0; while IFS= read -r p; do n=$((n+1)); [ -f ".claude/docs/usecase/$p" ] || [ -f "$p" ] && ok=$((ok+1)) || echo "missing: $p"; done; echo "links=$n exists=$ok"; }

# 6. flow-id 4-6への組み込み: SKILL.mdの4-6行にusecaseへの言及があること
grep -n 'usecase' .claude/skills/issue-mr-flow/SKILL.md
```

合格条件: 1が8、2の `matched` が8、3が `links>0` かつ全件実在、4が全ファイル0（grep -c は
マッチ0で非0終了するため「フェンスなし」が出ればよい）、5が全件実在、6で4-6の作業内訳の行が
ヒットすること。検査コマンド自体が空振りしないことは、意図的にリンク切れ・フェンス入りの
一時ファイルを置いて非合格になることを1回確かめる。

## 検証に関する補足

- 相対リンクの解決基準はファイル位置（`.claude/docs/usecase/` から見た相対パス）なので、
  検証5のパス解決は「usecase/からの相対」と「リポジトリルートからの相対」の両方を試す
  簡易版とする（厳密なmarkdownリンク解決は行わない。実在確認が目的）。
