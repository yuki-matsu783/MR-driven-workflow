---
title: issue #14 全体作業計画 — GitHub/GitLab情報取得はgh/glab CLIを使うことを明記
type: plan
description: issue #14「gitlab/githubの情報についてはwebfetchではなくgh,glabを利用して情報取得することを明記」の全体作業計画
---

# issue #14 全体作業計画

## Context

issue #14: 「gitlab/githubの情報についてはwebfetchではなくgh,glabを利用して情報取得することを明記」
（目的:「web fetchやcurlをするよりコマンドを使うようにする」）。

このリポジトリは既に `.claude/scripts/src/vcs/Provider.sh`（`gh`/`glab` CLI経由でissue/PR/MR情報を
取得する抽象化層）を持ち、`issue-mr-flow` スキルのサブコマンドは一貫してこの経由で情報取得している。
しかし「GitHub/GitLabの情報はWebFetchツールやcurlではなくgh/glab CLIを使う」という方針自体は、
AIエージェント向けルールとしてどこにも明文化されていない（`AGENTS.md`・`.claude/rules/`配下・
`.claude/skills/issue-mr-flow/SKILL.md`いずれにも "WebFetch" "curl" の言及は無いことをgrepで確認済み）。
明文化されていないことで、Provider.sh経由の手段が無い/気づかれない場面（単発のPRページ確認など）で
AIエージェントがWebFetchツールへ流れるリスクがある。本issueはこれをルールとして明記し、なぜgh/glabを
優先するのかの根拠も残すことが目的。

調査の結果、変更は「ドキュメント（ルール1箇所の追記＋DDR1件の新設）のみ」で完結し、スクリプト・
hookのコード変更は不要と判断した。既存のPlan/個別作業計画の2階層構造（`.claude/skills/issue-mr-flow/
SKILL.md`「計画の2階層構造」）に従い、本ファイルを全体作業計画としたうえで、下位の個別計画は
「調査」フェーズを省略し（本ファイルの調査で十分小さいため）、【実装】【設計反映】を1つの個別計画に
併記する（実装＝ルール追記と、反映＝DDR新設は同時に合意を取ってよい規模のため。
`.claude/skills/issue-mr-flow/SKILL.md`「種別を複数併記する場合／分ける場合」の判断基準に従う）。

## 実施するフェーズ

HANDOFF.mdには以下を記載する。

- フェーズ2（調査）: 実施しない（本計画のContextで完了済みのため individual な調査計画は作らない）
- フェーズ3（作業）: 実施する（`plans/【実装】【設計反映】gh-glab優先ルールの明記.md` を作成し、
  AGENTS.mdへのルール追記とDDR新設を1つの個別計画にまとめる）
- フェーズ4（反映）: フェーズ3に統合済み（上記個別計画がそのまま反映内容を兼ねる）
- フェーズ5（クローズ）: 通常通り実施

## 実装方針（個別計画の骨子）

### 1. `AGENTS.md` のルール節に1行追記

`## ルール` の既存箇条書きに、以下の内容を追記する（既存の他ルールと同じ粒度の一文）。

> GitHub/GitLabのissue・PR/MR・コメント等の情報を取得する際は、WebFetchツールやcurlではなく
> `gh`/`glab` CLI（`.claude/scripts/src/vcs/Provider.sh` 経由）を使う。認証済みで構造化JSONが
> 得られ、`.claude/skills/issue-mr-flow/SKILL.md` の各サブコマンドとも一貫するため。

frontmatterの`keywords`にも `gh`, `glab`, `webfetch` 等を追記し、`type: rule` 等の既存キーは
変更しない（`.claude/rules/markdown-frontmatter.md` のフォーマット規約に従う）。

### 2. DDR新設: `.claude/docs/ddr/0020-GitHub_GitLab情報取得はgh_glab-CLIを使いWebFetchは使わない.md`

既存DDRの書式（例: `0012-コミットはcommitスキル経由を機構的に強制する.md`）に合わせ、以下を記録する。

- **背景**: issue #14。Provider.sh抽象化は既にあるが、それを使わない単発の情報取得（WebFetch/curl）
  への流れを止める明文化されたルールが無かった。
- **決定**: AGENTS.mdへルールを1行追記する（上記）。技術的な強制（hookでのWebFetchブロック等）は
  今回のissueのスコープ外とし、ドキュメントでの明記に留める（理由: `git commit`のような不可逆・
  検知しづらい操作と異なり、WebFetch使用は実害が限定的でレビューでも気づきやすいため、DDR 0012ほどの
  機構的強制は過剰と判断）。
- **却下した案**:
  - hookによる機構的ブロック（`block-direct-git-commit.sh`と同様の仕組みをWebFetchツールにも適用）
    → 過剰対応と判断し却下（理由は上記）。将来同様の逸脱が繰り返し発生した場合に再検討してよい旨を残す。
- **理由の補足**（本文に含める）: `gh`/`glab`は認証済みでレート制限・ログイン処理を回避でき、
  `jq`で扱える構造化JSONを返す。WebFetchでのHTMLスクレイピングはページ構造変更に弱く、
  非公開issue/PRへのアクセスに認証が必要な場面にも対応しない。

### 3. インデックス更新

- `.claude/docs/README.md` のDDR一覧に `0020-...` の行を追記する。
- `bash .claude/scripts/src/extract-frontmatter.sh .claude/docs/ddr` と
  `bash .claude/scripts/src/extract-frontmatter.sh .`（AGENTS.mdはルートのため）を実行し、
  `index.jsonl` を再生成する（`.claude/rules/markdown-frontmatter.md`の運用ルールに従う）。

## 検証方法

- `grep -rn "WebFetch\|curl" AGENTS.md .claude/docs/ddr/0020-*.md` でルール文言が入っていることを確認。
- 新設DDRファイルが `.claude/rules/markdown-frontmatter.md` のfrontmatter規約（`type: ddr`、
  `description`は無変更前提で新規作成なので自由記述）を満たすことを目視確認。
- `index.jsonl`（ルート・`.claude/docs/ddr/`）が新規追記分を含めて再生成されていることを確認。
- `.claude/docs/README.md` のDDR一覧にリンク切れが無いことを確認。

## 備考

- 本issueはコード変更を伴わないため、bashスクリプトの構文チェック等は不要。
- 個別作業計画・worklogの作成、commit/push、MRレビュー往復は通常のissue-mr-flowフロー
  （flow-id 3-1以降、4相当の内容を3に統合）に従う。
