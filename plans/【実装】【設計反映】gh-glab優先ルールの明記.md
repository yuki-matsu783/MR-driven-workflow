---
title: 【実装】【設計反映】GitHub/GitLab情報取得はgh/glab CLI優先ルールの明記
type: plan
description: issue #14対応。AGENTS.mdへのルール追記とDDR新設を1つの個別計画として併記する
---

# 【実装】【設計反映】GitHub/GitLab情報取得はgh/glab CLI優先ルールの明記

全体作業計画: `plans/elegant-puzzling-quasar.md`

## 対象

issue #14「gitlab/githubの情報についてはwebfetchではなくgh,glabを利用して情報取得することを明記」。
全体作業計画のContextで調査は完了済み（既存ルールにWebFetch/curl言及なしを確認済み）のため、
本計画では実装（ルール追記）と設計反映（DDR新設）を1つの計画として併記し、1回の合意で進める
（実装内容がそのまま反映内容であり、フェーズを分ける実益が無いため）。

## 実施内容

### 1. `AGENTS.md` のルール節への追記

`## ルール` の既存箇条書きの末尾に以下を追加する。

> - GitHub/GitLabのissue・PR/MR・コメント等の情報を取得する際は、WebFetchツールやcurlではなく
>   `gh`/`glab` CLI（`.claude/scripts/src/vcs/Provider.sh` 経由）を使う。認証済みで構造化JSONが
>   得られ、`.claude/skills/issue-mr-flow/SKILL.md` の各サブコマンドとも一貫するため（詳細・
>   却下案は `.claude/docs/ddr/0020-...` 参照）。

frontmatterの`keywords`に `gh`, `glab`, `webfetch` を追記する。他の既存キー（`type`等）は変更しない。

### 2. DDR新設

`.claude/docs/ddr/0020-GitHub_GitLab情報取得はgh_glab-CLIを使いWebFetchは使わない.md` を新規作成する。
書式は既存DDR（`0012-コミットはcommitスキル経由を機構的に強制する.md`等）に合わせる。

- 背景: issue #14。Provider.sh抽象化は既にあるが、それを使わない単発の情報取得（WebFetch/curl）
  への流れを止める明文化されたルールが無かった。
- 決定: AGENTS.mdへルール1行を追記する（技術的な強制＝hookでのWebFetchブロック等は本issueの
  スコープ外とし、ドキュメント明記に留める）。
- 却下した案: hookによる機構的ブロック（`block-direct-git-commit.sh`同様の仕組み）。
  git commitのような不可逆・検知しづらい操作と異なり実害が限定的でレビューでも気づきやすいため
  過剰と判断し却下。将来同種の逸脱が繰り返せば再検討してよい旨を残す。

### 3. インデックス更新

- `.claude/docs/README.md` のDDR一覧に新規DDRの行を追記する。
- `bash .claude/scripts/src/extract-frontmatter.sh .claude/docs/ddr` と
  `bash .claude/scripts/src/extract-frontmatter.sh .` を実行し `index.jsonl` を再生成する。

## 完了条件

- AGENTS.mdにルールが追記されている
- DDR 0020が新規作成され、README.mdのDDR一覧に反映されている
- ルート・`.claude/docs/ddr/`双方の`index.jsonl`が再生成されている
