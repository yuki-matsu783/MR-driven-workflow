---
title: .claude/docs配下の目次
type: guide
description: .claude/docs配下（issue駆動MRワークフロー機構自体のspec・ddr）の位置づけと各ドキュメントへのリンクをまとめた目次
tags: [claude-docs, docs, index, guide]
keywords: [正史仕様, 意思決定ログ, issue-mr-workflow, シェルスクリプト方針, frontmatter抽出]
---

# .claude/docs 配下の目次

`.claude/docs/` は、このリポジトリに同梱されている issue駆動MRワークフロー機構
（`.claude/skills/`, `.claude/scripts/`, `.claude/hooks/`, `.claude/agents/`）自体の設計ドキュメント
置き場。開発フロー全体は [.claude/skills/issue-mr-flow/SKILL.md](../skills/issue-mr-flow/SKILL.md)
（唯一の実装フロー定義）に従い、ドキュメントの置き場所・ライフサイクルは
[.claude/rules/docs-workflow.md](../rules/docs-workflow.md) の「ドキュメント運用」表を参照する。

- `spec/` ── ワークフロー機構の機能ごとの正史仕様（最新の仕様を上書き更新）
- `ddr/` ── ワークフロー機構関連の意思決定ログ（DDR: Design Decision Record。追記のみ）

> **由来について**: このワークフロー機構（`.claude/` 一式・`.mrworkflow.json`・`.github/`
> `.gitlab/` のissueテンプレート等）は、別プロジェクト向けに
> 実装されたものから、アプリ固有の内容（`src/` 等のアプリ本体コード・固有のルール・
> スキル・spec）を除いた汎用部分のみを移植したものです。`spec/` `ddr/` の本文には、移植元
> プロジェクトでの開発経緯（issue番号・当時のディレクトリ構成である `dev-tools/docs/` `docs/`
> 等への言及を含む）がそのまま残っている箇所があります。特にDDRは一度記録した内容を変更しない
> 運用（[docs-workflow.md](../rules/docs-workflow.md)参照）のため、意図的に手を加えていません。
> 現在この機構が実際に置かれている場所は、本リポジトリの `.claude/scripts/`・`.claude/docs/`
> です。移植元プロジェクトの構成については `.claude/docs/ddr/0013-dev-toolsをAI専用_人間専用に分離する.md`
> を参照してください。

## spec（機能仕様）

- [issue-mr-workflow.md](spec/issue-mr-workflow.md) ── issue駆動MRワークフロー支援
- [shell-scripts.md](spec/shell-scripts.md) ── 開発補助スクリプトのシェル言語方針（bash採用の経緯）
- [extract-frontmatter.md](spec/extract-frontmatter.md) ── frontmatter抽出スクリプト（index.jsonl生成）
- [update-handoff-progress.md](spec/update-handoff-progress.md) ── HANDOFF.md進捗自動更新スクリプト
- [check-base-conflicts.md](spec/check-base-conflicts.md) ── defaultブランチとのコンフリクト検知スクリプト
- [create-commit.md](spec/create-commit.md) ── コミット実行ラッパー（commitスキル専用）

## ddr（意思決定ログ）

DDR（Design Decision Record）はADR（Architecture Decision Record）の考え方を拡張し、
architectureに限らない意思決定も記録対象とする（この改称自体はDDR 0001で決定したが、
そのファイルは本リポジトリには持ち込んでいない。下記注記参照）。

**このリポジトリはワークフロー機構のテンプレートとして切り出されたものであり、移植元にあった
DDRのうち0001・0002・0008・0015は持ち込んでいない**（連番に欠番があるのはこのため。
欠番を埋め直すと既存DDR本文中の相互参照とずれるため、番号は移植元のまま維持する）。

- [0003-レビュースレッド解決は自動化しない.md](ddr/0003-レビュースレッド解決は自動化しない.md)
- [0004-AI返信は署名で識別しbotアカウント分離は見送る.md](ddr/0004-AI返信は署名で識別しbotアカウント分離は見送る.md)
- [0005-DraftPR作成失敗時は空コミットで自動リトライする.md](ddr/0005-DraftPR作成失敗時は空コミットで自動リトライする.md)
- [0006-対応工数レポートはtranscript自前パースで実装する.md](ddr/0006-対応工数レポートはtranscript自前パースで実装する.md)
- [0007-hookのcommandはbashのPATH解決方式へ変更.md](ddr/0007-hookのcommandはbashのPATH解決方式へ変更.md)
- [0009-Planモードre-entry時はgit checkout復元でなくarchiveスクリプトで対処する.md](ddr/0009-Planモードre-entry時はgit checkout復元でなくarchiveスクリプトで対処する.md) ── **`status: superseded`（0019により置き換え）**
- [0010-ブランチslugの意訳生成はAIエージェントが行う.md](ddr/0010-ブランチslugの意訳生成はAIエージェントが行う.md)
- [0011-issue作成は独立スキルとして新設する.md](ddr/0011-issue作成は独立スキルとして新設する.md)
- [0012-コミットはcommitスキル経由を機構的に強制する.md](ddr/0012-コミットはcommitスキル経由を機構的に強制する.md)
- [0013-dev-toolsをAI専用_人間専用に分離する.md](ddr/0013-dev-toolsをAI専用_人間専用に分離する.md)
- [0014-調査結果のhtml版は自己完結htmlのコミットで作る.md](ddr/0014-調査結果のhtml版は自己完結htmlのコミットで作る.md)
- [0016-frontmatterスクリプトの走査方式にgit-ls-filesを採用する.md](ddr/0016-frontmatterスクリプトの走査方式にgit-ls-filesを採用する.md)
- [0017-gemini配下はGit管理下に置かずセットアップスクリプトで生成する.md](ddr/0017-gemini配下はGit管理下に置かずセットアップスクリプトで生成する.md)
- [0018-gemini-settings.jsonのhooksはレビュー提示スニペットのhooksセクションのみ採用する.md](ddr/0018-gemini-settings.jsonのhooksはレビュー提示スニペットのhooksセクションのみ採用する.md)
- [0019-planツール利用を全体作業計画に限定し個別計画をファイル分離する.md](ddr/0019-planツール利用を全体作業計画に限定し個別計画をファイル分離する.md)
- [0020-GitHub_GitLab情報取得はgh_glab-CLIを使いWebFetchは使わない.md](ddr/0020-GitHub_GitLab情報取得はgh_glab-CLIを使いWebFetchは使わない.md)
- [0021-frontmatter抽出は1ファイル1回のjq呼び出しとmtimeキャッシュで高速化する.md](ddr/0021-frontmatter抽出は1ファイル1回のjq呼び出しとmtimeキャッシュで高速化する.md)
- [0022-push断面の全文コピーをやめ行番号インデックスで表現する.md](ddr/0022-push断面の全文コピーをやめ行番号インデックスで表現する.md)
- [0023-レビュー依頼メッセージの参照リンクは前回pushSHAをローカル状態で保持して組み立てる.md](ddr/0023-レビュー依頼メッセージの参照リンクは前回pushSHAをローカル状態で保持して組み立てる.md)
- [0024-HANDOFF進捗更新はMarkdownテーブル直接書き換えでループ範囲を一括操作する.md](ddr/0024-HANDOFF進捗更新はMarkdownテーブル直接書き換えでループ範囲を一括操作する.md)
- [0025-frontmatterのindex.jsonlをGit管理から外しSessionStart-hookで生成する.md](ddr/0025-frontmatterのindex.jsonlをGit管理から外しSessionStart-hookで生成する.md)
- [0026-空コミットフォールバックはGitHub固有の制約として残す.md](ddr/0026-空コミットフォールバックはGitHub固有の制約として残す.md)
- [0027-gh_glab-CLI不在時はMCPフォールバック経路へ機構的に誘導する.md](ddr/0027-gh_glab-CLI不在時はMCPフォールバック経路へ機構的に誘導する.md)
- [0028-プロバイダ判定はremote-URLのホスト部でgithub以外をgitlabとみなす.md](ddr/0028-プロバイダ判定はremote-URLのホスト部でgithub以外をgitlabとみなす.md)
- [0029-defaultブランチとのコンフリクトは検知を機構化し解消手順をスキル化する.md](ddr/0029-defaultブランチとのコンフリクトは検知を機構化し解消手順をスキル化する.md)
- [0030-create-commitは削除ステージ済みパスをgit-addの失敗時分類で吸収する.md](ddr/0030-create-commitは削除ステージ済みパスをgit-addの失敗時分類で吸収する.md)
- [0031-機構自身の単体テストは.claude_scripts_test配下へ置く.md](ddr/0031-機構自身の単体テストは.claude_scripts_test配下へ置く.md)
- [0032-compact後もSessionStart-hookで作業コンテキストを再注入する.md](ddr/0032-compact後もSessionStart-hookで作業コンテキストを再注入する.md)
- [0033-issue起票前の重複チェックは検索をProvider層へ置きキーワード抽出はAIに委ねる.md](ddr/0033-issue起票前の重複チェックは検索をProvider層へ置きキーワード抽出はAIに委ねる.md)
- [0034-issueの分割は並列列挙構造を主トリガーにAIが提案し人間が決定する.md](ddr/0034-issueの分割は並列列挙構造を主トリガーにAIが提案し人間が決定する.md)
- [0035-PR_MR作成はAIエージェントに委ねマージのみ明示指示を必須にする.md](ddr/0035-PR_MR作成はAIエージェントに委ねマージのみ明示指示を必須にする.md)
- [0036-GitLab-issueテンプレートは予約名Default.mdを正とし文書側を合わせる.md](ddr/0036-GitLab-issueテンプレートは予約名Default.mdを正とし文書側を合わせる.md)
