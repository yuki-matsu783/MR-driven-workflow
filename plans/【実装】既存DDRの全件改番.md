---
title: 【実装】既存DDRの全件改番
type: plan
description: issue #133 の個別作業計画。当初「改番しない」としていた既存の4桁連番DDR全56件を、issue番号ベースの新方式へ一括改番する
tags: [ddr, plan, naming, workflow]
keywords: [DDR, 改番, 連番, issue番号, i00, 一括置換, 参照追従, リンク検証, 全件改番]
---

# 【実装】既存DDRの全件改番（issue #133）

`plans/【実装】【テスト】DDR識別子の新方式への対応.md` では「既存の連番DDRは改番しない」
（新旧2方式の併存）としていたが、**ユーザーの判断で全件改番へ方針が変わった**ため、
その作業を別の個別作業計画として立てる。

方針転換の理由と、引き受けたリスクへの対処は
`.claude/docs/ddr/i133-01-DDR識別子はissue番号ベースにし連番採番をやめる.md`
「全件改番へ方針を変えた経緯」へ記録する。

## 対応issueの特定

改番には「そのDDRがどのissueの成果物か」が要る。**本文の記載を機械的に信用しない。**
このリポジトリはワークフロー機構のテンプレートとして別プロジェクトから切り出されたもので、
古いDDRは**移植元プロジェクトのissue番号**を書いており、本リポジトリの同番号issueとは
別物である（例: 旧 `0014` は「issue #48」と書くが、本リポジトリの #48 は無関係な内容）。

1. 全DDRの本文からissue番号・PR番号の記載を拾う。
2. 本リポジトリのissue一覧を取得し、**タイトルと突き合わせて**対応の妥当性を1件ずつ判定する。
3. 判定結果を根拠つきの一覧としてユーザーへ提示し、承認を得る。

## 作業項目

| # | 対象 | 内容 |
|---|---|---|
| 1 | `.claude/docs/ddr/*.md` | `git mv` でファイル名を `i<issue番号>-<枝番2桁>-<タイトル>.md` へ変更する |
| 2 | 同上 | frontmatterの `title` と本文冒頭の見出しの識別子を追従させる |
| 3 | 対応issueを特定できなかったDDR | 予約番号 `i00` を使い、`i00-01` から**リポジトリ全体の通し番号**で振る |
| 4 | リポジトリ全体 | ファイル名参照・`DDR NNNN` 形式の地の文・markdownリンクのラベルを一括置換する |
| 5 | `.claude/rules/markdown-frontmatter.md` | 「対応issueを持たないDDR（`i00`）」「旧方式（4桁連番）の扱い」の2節を追加し、「既存は改番しない」の記述を差し替える |
| 6 | `.claude/docs/README.md` | 2ブロック構成をやめ、issue番号の数値順の単一一覧にする（`i00` を先頭に置き、その意味を明記する） |
| 7 | `.claude/docs/spec/check-base-conflicts.md` / `.claude/skills/resolve-conflict/SKILL.md` / `.claude/skills/issue-mr-flow/SKILL.md` / `.claude/rules/docs-workflow.md` | 「既存の連番DDR同士」という前提を「旧形式を抱えた配布先・改番前のブランチ」へ書き換える |
| 8 | `.claude/scripts/src/check-base-conflicts.sh` | 旧形式の受け付けは残したまま、ヘッダコメントの前提だけを更新する |
| 9 | `.claude/scripts/test/test_check_base_conflicts.sh` | 予約番号 `i00` の抽出ケースを追加する |
| 10 | `.claude/docs/ddr/i133-01-….md` | 決定5・却下案C・却下案D・トレードオフを実態へ合わせ、「全件改番へ方針を変えた経緯」節を追加する |

## 書き換えてはいけないもの

**過去の事実の記録に現れる連番は、ファイルを指す参照ではない**（`.claude/rules/docs-workflow.md`）。
一括置換の対象から必ず外す。

- 過去のコミットメッセージの引用（`chore: mainをマージしDDR番号を0028へ繰り下げて…`）。
- 過去に重複した番号の一覧、`0034→0035→0036→0038` のような繰り下げの経過。
- `.claude/docs/spec/*.md` のissueごとのchangelogエントリ（point-in-timeの記録）。
- **`.claude/scripts/test/test_check_base_conflicts.sh` の `0027-…` フィクスチャ。**
  PR #52 で実際に起きた衝突を再現しているもので、片方だけ改番すると「重複しない2ファイル」に
  なりテストの意図が無言で失われる。**このファイルは一括置換の対象から丸ごと外す。**
- 移植元にあり本リポジトリへ持ち込んでいないDDR（旧番号 0001・0002・0008・0015）への言及。

## 検証

- **すべてのDDRリンクが実ファイルへ解決すること**を機械的に確認する（追従漏れの検出はこれが要）。
- `.claude/scripts/test/test_*.sh` を全件実行し `failures=0`。
- `bash .claude/scripts/src/extract-frontmatter.sh .` が新ファイル名で `index.jsonl` を再生成できる。
- `bash .claude/scripts/src/check-base-conflicts.sh --no-fetch` の `hasDuplicateDdrNumber` が `false`。
