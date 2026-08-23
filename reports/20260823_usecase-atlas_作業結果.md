---
title: usecase-atlas 作業結果（フェーズ3）
type: report
description: issue #170 フェーズ3の作業結果。usecase文書8本の作成・周辺7ファイル更新・検証7本の全合格と検出能力確認
tags: [usecase-docs, report, phase3]
keywords: [ユースケース, usecase, 作業結果, 検証, frontmatter, README, doc-search, 逆引き, REVIEW-POINTS, docs-workflow]
---

# usecase-atlas 作業結果（フェーズ3）

- issue: #170 / PR: #173
- 個別作業計画: `plans/【AIアセット作成】ユースケース文書一式と周辺更新.md`
- 実施日: 2026-08-23（Linuxリモート実行環境。Claude Code on the web）

## サマリ

| # | やったこと | 結果 | 根拠の性質 |
|---|---|---|---|
| 1 | `.claude/docs/usecase/` へユースケース文書8本を新規作成 | **完了**（記述の型・リンク規則を遵守） | 実測（検証1・2・4・5） |
| 2 | 周辺6ファイル＋観点表1件を更新 | **完了**（計画の変更対象どおり） | 実測（検証3・6・7） |
| 3 | 検証コマンド7本を実行 | **全合格** | 実測（下記に出力） |
| 4 | 検査の検出能力の確認（意図的な非合格） | **検証3・4・5が異常を検出することを確認** | 実測 |
| 5 | `--type usecase` の絞り込み（調査時点で未実測だった件） | **matched=8 を実測**（スクリプト変更不要の結論を裏取り） | 実測 |

## 実施した内容と結果

### 1. usecase文書8本の作成

計画「変更対象」の8本を `.claude/docs/usecase/` へ作成した（ファイル名は調査結果「問い1・2」の
表のとおり）。全8本が次を満たす。

- 4見出し（どんな場面か／使う機能と流れの概要／何が得られるか／詳細へのリンク）で統一。
- frontmatterは `type: usecase` ＋ `title`/`description`/`tags`/`keywords`（`resource` は
  対応する実リソースが無いため省略）。
- 手順詳細（コマンド列・手順番号）は書かず、コードフェンス0（検証4）。流れは散文＋箇条書きで
  概観に留め、spec/SKILL.mdへのリンクで参照。
- リンクはすべてファイル位置（`.claude/docs/usecase/`）からの相対パスで、全21リンクの実在を
  確認（検証5）。
- 分量は各30〜45行（目安30〜60行の範囲内）。

### 2. 周辺7ファイルの更新

| ファイル | 実施した変更 |
|---|---|
| `.claude/rules/markdown-frontmatter.md` | 「typeの値」表の `spec` 行の直後へ `usecase` 行を追加 |
| `.claude/docs/README.md` | 冒頭箇条書きの先頭へ `usecase/` 行を追加。`## spec（機能仕様）` 見出しの直前へ `## usecase（ユースケース逆引き）` 節（8本の一覧＋同一コミット更新ルール）を新設（生成マーカー区間の外）。frontmatterの `description`/`keywords` を更新 |
| `.claude/skills/issue-mr-flow/SKILL.md` | 4-6行「設計反映」項末尾（generate-ddr-list.sh の文の後）へ、usecase文書への影響確認を追記 |
| `.claude/rules/docs-workflow.md` | 「ドキュメント運用」表へusecase行を追加（寿命: 永続（最新状態）。README同一コミット更新ルールと、flow-id 4-6での影響確認を運用欄に明記） |
| `.claude/rules/directory-structure.md` | ツリーの `.claude/docs/` 配下へ `usecase/` 行を追加 |
| `index.md` | Repository Mapの `.claude/docs/` 配下へ `usecase/` 行を追加 |
| `.claude/REVIEW-POINTS.md` | 「ユースケース文書」節を新設（手順再掲の禁止＝散文再掲の検出の受け皿・4見出し・相対リンク・README同一コミット更新の4観点） |

### 3. 検証の実行結果（7本全合格）

計画「検証」節のコマンドをそのまま実行した。

- 検証1（ファイル数）: `8`
- 検証2（frontmatter検索）: `matched=8 total=140`
- 検証3（README⇔ファイル双方向一致）: `README⇔ファイル 双方向一致`（diff差分なし・件数ガード通過）
- 検証4（コードフェンスなし）: `files=8 fences=0`
- 検証5（リンク実在）: `links=21 missing=0`
- 検証6（4-6行のusecase言及）: `1`
- 検証7（周辺5ファイル）: `1 / 1 / 1 / 1 / 5`（frontmatter規約・docs-workflow・
  directory-structure・index.md・REVIEW-POINTS。いずれも1以上）

### 4. 検査の検出能力の確認

フェンス入り・リンク切れの一時ファイル（`一時検証用.md`）を意図的に置き、次を確認して削除した。

- 検証4が `files=9 fences=2` を出し非合格になる。
- 検証5が `missing: ../spec/存在しない.md` と `links=22 missing=1` を出し非合格になる。
- 検証3が件数ガード（9件≠8件）で停止し非合格になる。

### 5. `--type usecase` の実測（調査の裏取り）

調査結果「確かめられなかったこと」に残っていた `--type usecase` そのものの絞り込みを、
文書作成直後に実測した。`bash .claude/scripts/src/search-frontmatter.sh --type usecase
--format count` が `matched=8 total=140` を返し、**スクリプト変更なしで新しいtype値が
検索できる**という調査の結論（推論）が実測で裏付けられた（2026-08-23・Linuxリモート実行環境。
`total` はインデックス全件数のため時点依存の値）。

## 確かめられなかったこと

- 日本語ファイル名のusecase文書がWindows実機（git bash・cp932環境）で問題なく扱えるかは、
  この環境（Linux）では確認できない（DDR 75本が同じ形式で運用済みのため、リスクは新規ではない）。
- 散文・箇条書きの形をとった手順再掲が8本のどこにも無いことは、機械検査では証明できない
  （検証4は代理指標）。`.claude/REVIEW-POINTS.md` へ追加した観点と、このPRのレビューが受け皿。

## 設計への反映

1. usecase層の設計判断（README一本化・日本語ファイル名・生成物化の見送りと再検討条件・
   flow-id 4-6への組み込み）をDDRとして残すかを、flow-id 4-1で判断する。
2. `【AIアセット作成】` 種別の定義（SKILL.md「計画の2階層構造」）へ「設計ドキュメント
   （usecase等）の新設」を含めるかの追記要否も、flow-id 4-1の反映候補に含める（フェーズ2から
   持ち越し）。
3. `Provider.sh` の `add_empty_commit_for_draft_mr` 不具合（フェーズ1で発生）は引き続き
   flow-id 4-1の確定候補（本フェーズでは計画どおり `.sh` に触れていない）。
