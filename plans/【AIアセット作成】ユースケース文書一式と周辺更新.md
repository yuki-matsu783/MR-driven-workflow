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
2. `.claude/docs/README.md` — 冒頭箇条書き（`- spec/`・`- ddr/`）の先頭へ `usecase/` 行を追加し、
   **`## spec（機能仕様）` 見出しの直前**へ `## usecase（ユースケース逆引き）` 節（8本の一覧）を
   新設する（この位置はDDR一覧の生成マーカー区間（79行目〜）より前なので「区間の外」の条件を
   満たす）。frontmatterの `description`/`keywords` も更新
3. `.claude/skills/issue-mr-flow/SKILL.md` — 4-6行「設計反映」項末尾へ影響確認を追記
4. `.claude/rules/docs-workflow.md` — 「ドキュメント運用」表へusecase行を追加。行には運用ルール
   「**usecase文書を追加・改名・削除したら、READMEのusecase節を同じコミットで更新する**」を
   含める（調査結果「問い4」の結論。一覧は生成物にしない代わりに更新責務を明文化する）
5. `.claude/rules/directory-structure.md` — ツリーへ `usecase/` 行を追加
6. `index.md` — Repository Mapへ `usecase/` 行を追加
7. `.claude/REVIEW-POINTS.md` — usecase文書の観点（手順詳細を再掲しない等。**散文・箇条書きに
   よる手順再掲は機械検査で検出できないため、ここが検出の受け皿**）を追加

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
- **リンクはすべて「そのファイルの位置（`.claude/docs/usecase/`）からの相対パス」で書く**
  （例: `../spec/issue-mr-workflow.md`、`../../skills/issue-mr-flow/SKILL.md`、
  `../../../index.md`）。ルート相対・絶対パスは使わない。解決基準を1つに固定することで、
  検証5のパス解決も `.claude/docs/usecase/` 基準の1経路だけで済む。

## やらないこと（スコープ外）

- spec/SKILL.md側の手順詳細の転記（上記のとおり禁止）。
- `.sh` スクリプトの変更（`Provider.sh` の不具合対応はフェーズ4の `【実装反映】` 候補）。
- 既存ドキュメントの再構成・移動。

## 検証（実行できるコマンドと合格条件）

```bash
# 1. ファイル数: 出力が 8 であること
ls .claude/docs/usecase/*.md | wc -l

# 2. frontmatter検索: usecase文書を1本作った直後から実測できる（未追跡でも載る）。
#    最終的に matched=8 であること
bash .claude/scripts/src/search-frontmatter.sh --type usecase --format count

# 3. README⇔ファイルの双方向一致: READMEのusecase節リンクと実ファイル一覧が集合として
#    一致すること（リンク先の実在と、8本すべてがREADMEに載っていること＝逆方向の
#    取りこぼしを1つの検査で兼ねる。差分が出たら不合格。先頭の件数ガードにより、
#    両側とも0件の空一致は合格にならない）
[ "$(ls .claude/docs/usecase/*.md 2>/dev/null | wc -l)" -eq 8 ] && \
diff <(grep -o 'usecase/[^)]*\.md' .claude/docs/README.md | sed 's|^usecase/||' | sort -u) \
     <(cd .claude/docs/usecase && ls *.md | sort) && echo 'README⇔ファイル 双方向一致'

# 4. コードフェンスなし（手順再掲の代理指標）: files=8 fences=0 であること
#    （対象0ファイルではawkがエラーになるため、空振りでの見かけ合格は起きない）
awk 'FNR==1{files++} /^```/{fences++} END{printf "files=%d fences=%d\n", files, fences+0}' \
  .claude/docs/usecase/*.md

# 5. usecase文書内のリンク先が全件実在すること（.md/.sh/.json を対象。解決基準は
#    .claude/docs/usecase/ の1経路のみ。links>0 かつ missing=0 で合格）
grep -hoE '\]\([^)]+\.(md|sh|json)(#[^)]*)?\)' .claude/docs/usecase/*.md | \
  sed -E 's/^\]\(//; s/\)$//; s/#.*$//' | sort -u | \
  ( cd .claude/docs/usecase && n=0; miss=0; while IFS= read -r p; do n=$((n+1)); \
    if [ ! -f "$p" ]; then miss=$((miss+1)); echo "missing: $p"; fi; done; \
    echo "links=$n missing=$miss"; [ "$n" -gt 0 ] && [ "$miss" -eq 0 ] )

# 6. flow-id 4-6への組み込み: 全体フロー表の4-6の行（だけ）に usecase への言及があること
#    （出力が1以上で合格。SKILL.md全文ではなく表の4-6行に限定して検査する）
awk -F'|' '$2 ~ /^[[:space:]]*4-6[[:space:]]*$/' .claude/skills/issue-mr-flow/SKILL.md | \
  grep -c 'usecase'

# 7. 周辺ファイル5件の反映（いずれも出力が1以上で合格）
grep -c -- '| `usecase` |' .claude/rules/markdown-frontmatter.md   # typeの値表の行
grep -c -- 'usecase' .claude/rules/docs-workflow.md                # ドキュメント運用表の行
grep -c -- 'usecase/' .claude/rules/directory-structure.md         # ツリーの行
grep -c -- 'usecase' index.md                                      # Repository Mapの行
grep -c -- 'usecase' .claude/REVIEW-POINTS.md                      # レビュー観点
```

合格条件は各検査のコメントのとおり（1: 8／2: matched=8／3: 差分なし／4: files=8 fences=0／
5: links>0 かつ missing=0／6: 1以上／7: 5本すべて1以上）。検査コマンド自体が空振りしないことは、
意図的にリンク切れ・フェンス入りの一時ファイルを置いて非合格になることを1回確かめる。

## 検証に関する補足

- 検証4の「フェンス0」が保証するのは**コードブロックが無いことだけ**である。散文・箇条書きで
  書かれた手順再掲（手順番号付きの列挙等）は機械検査では検出できないため、代理指標と位置づけ、
  散文での再掲は `.claude/REVIEW-POINTS.md` へ追加するusecase観点（変更対象7）を検出の受け皿と
  する。
- 検証5は厳密なmarkdownリンク解決は行わない簡易版（実在確認が目的）。リンクの解決基準は
  「方針」節で `.claude/docs/usecase/` からの相対パスに統一しているため、検査も同じ1経路のみで
  解決する（複数経路を試すと、間違った基準でたまたま実在するパスに誤合格しうる）。
