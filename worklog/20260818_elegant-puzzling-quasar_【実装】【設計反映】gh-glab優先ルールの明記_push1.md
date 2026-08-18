---
title: worklog 【実装】【設計反映】gh-glab優先ルールの明記 push1
type: log
description: issue #14対応。AGENTS.mdへのルール追記とDDR新設のworklog（push1）
tags: [worklog, issue-mr-flow, gh, glab, webfetch]
keywords: [AGENTS.md, DDR, gh, glab, WebFetch, curl, Provider.sh, issue-14]
---

# worklog: 【実装】【設計反映】GitHub/GitLab情報取得はgh/glab CLI優先ルールの明記

対象: issue #14「gitlab/githubの情報についてはwebfetchではなくgh,glabを利用して情報取得することを
明記」（2026-08-18）。
全体作業計画: `plans/elegant-puzzling-quasar.md`
個別作業計画: `plans/【実装】【設計反映】gh-glab優先ルールの明記.md`
push回数: 1

## 試したこと

- `AGENTS.md`の「## ルール」節末尾に、GitHub/GitLab情報取得はWebFetch/curlではなくgh/glab CLI
  （Provider.sh経由）を使う旨の1文を追記。frontmatterの`keywords`にも`gh`/`glab`/`webfetch`を追加。
- `.claude/docs/ddr/0020-GitHub_GitLab情報取得はgh_glab-CLIを使いWebFetchは使わない.md`を新規作成し、
  背景・決定・却下案（hookによる機構的ブロックは実害の少なさから見送り）を記録。
- `.claude/docs/README.md`のDDR一覧に0020の行を追記。
- `.claude/scripts/src/extract-frontmatter.sh`で`.claude/docs/ddr`とリポジトリルートの
  `index.jsonl`を再生成。

## うまくいったこと

- 変更がAGENTS.md 1箇所の追記＋DDR新設のみで完結し、既存スクリプト・hookへのコード変更は不要だった
  （全体作業計画のContextでの調査判断どおり）。

## ダメだったこと

- `.claude/scripts/src/extract-frontmatter.sh .` はリポジトリルートを再帰的に走査するため、
  root（AGENTS.md等）だけを狙ったつもりが無関係な多数のディレクトリの`index.jsonl`まで
  再生成されてしまった。過去の類似コミット（`e17d565`）では変更した2ディレクトリ分のみ
  regenerateしている前例があったため、それに合わせて`git checkout --`で本issueと無関係な
  差分を破棄し、ルート・`.claude/docs/ddr/`の2ファイルのみに絞った。
- その過程で、`README.md`/`DEVELOPERS.md`にfrontmatterが無く、内容も本リポジトリと無関係な
  別テンプレート（"AI Asset Management Project"）のままになっている既存の不整合を発見した
  （最初期コミット`4ba0395`由来、issue #14とは無関係）。今回は修正せず、HANDOFF.mdの
  「未解決の内容」に記録し、別issue化を推奨するに留めた。

## 次の一歩

- 特になし（完了）。commit・push（flow-id 3-7）へ進む。

---
