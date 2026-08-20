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
> です。移植元プロジェクトの構成については `.claude/docs/ddr/i00-10-dev-toolsをAI専用_人間専用に分離する.md`
> を参照してください。

## spec（機能仕様）

- [issue-mr-workflow.md](spec/issue-mr-workflow.md) ── issue駆動MRワークフロー支援
- [shell-scripts.md](spec/shell-scripts.md) ── 開発補助スクリプトのシェル言語方針（bash採用の経緯）
- [extract-frontmatter.md](spec/extract-frontmatter.md) ── frontmatter抽出スクリプト（index.jsonl生成）
- [update-handoff-progress.md](spec/update-handoff-progress.md) ── HANDOFF.md進捗自動更新スクリプト
- [check-base-conflicts.md](spec/check-base-conflicts.md) ── defaultブランチとのコンフリクト検知スクリプト
- [check-base-sync.md](spec/check-base-sync.md) ── 作業開始・再開時のベースブランチ追従確認スクリプト
- [create-commit.md](spec/create-commit.md) ── コミット実行ラッパー（commitスキル専用）
- [adversarial-review.md](spec/adversarial-review.md) ── 敵対的レビュー（専任サブエージェント・インラインコメント投稿）
- [distribution-assets.md](spec/distribution-assets.md) ── 配布テンプレート資産（PR/MRテンプレート・`.gitattributes`・VERSION）と配布経路での扱い
- [cleanup-task.md](spec/cleanup-task.md) ── flow-id 5-3 後片付けの自動化スクリプト
- [search-frontmatter.md](spec/search-frontmatter.md) ── ドキュメント横断検索スクリプト（index.jsonl検索）

## ddr（意思決定ログ）

DDR（Design Decision Record）はADR（Architecture Decision Record）の考え方を拡張し、
architectureに限らない意思決定も記録対象とする（この改称自体は移植元のDDR 0001で決定したが、
そのファイルは本リポジトリには持ち込んでいない。下記注記参照）。

**識別子は `i<issue番号>-<枝番2桁>` である**（例: `i133-01`）。issue番号はGitHub/GitLabが中央で
採番するため、別ブランチ同士で識別子が衝突しない。issue #133 でこの方式へ変更し、それ以前の
4桁連番（`0003`〜`0064`）は**すべて新方式へ改番した**（本リポジトリに連番のDDRは残っていない）。
命名規則は `.claude/rules/markdown-frontmatter.md`「DDRの識別子」が正。

一覧は**issue番号の数値順**に並べる。issue番号をゼロ埋めしないため**ファイル名の辞書順とは
一致しない**（`i99-01` は `i133-01` より後ろに来る）ので、追記のたびに位置を確認すること。
**件数はこの一覧が正**であり、他のドキュメントへ件数を直書きしない（1件増えるだけで陳腐化するため）。

**先頭の `i00-*` は「対応するissueが無いDDR」である。** 改番の際、本文から対応issueを特定
できなかった13件に、`i00` を予約番号として枝番を通しで振ったもの（`i00` の枝番だけは、
他と違ってリポジトリ全体で連番になる）。**新しく `i00-*` を作ることはない**（新規DDRは必ず
issueを起点とするため）。詳細は
`.claude/rules/markdown-frontmatter.md`「対応issueを持たないDDR（i00）」。

**このリポジトリはワークフロー機構のテンプレートとして切り出されたものであり、移植元にあった
DDRのうち旧番号 0001・0002・0008・0015 の4件は持ち込んでいない。** 本文中に「移植元のDDR 0002」
のような言及が残っているのはこのためで、実体のファイルは本リポジトリに存在しない。

- [i00-01-レビュースレッド解決は自動化しない.md](ddr/i00-01-レビュースレッド解決は自動化しない.md)
- [i00-02-AI返信は署名で識別しbotアカウント分離は見送る.md](ddr/i00-02-AI返信は署名で識別しbotアカウント分離は見送る.md)
- [i00-03-DraftPR作成失敗時は空コミットで自動リトライする.md](ddr/i00-03-DraftPR作成失敗時は空コミットで自動リトライする.md)
- [i00-04-対応工数レポートはtranscript自前パースで実装する.md](ddr/i00-04-対応工数レポートはtranscript自前パースで実装する.md)
- [i00-05-hookのcommandはbashのPATH解決方式へ変更.md](ddr/i00-05-hookのcommandはbashのPATH解決方式へ変更.md)
- [i00-06-Planモードre-entry時はgit checkout復元でなくarchiveスクリプトで対処する.md](ddr/i00-06-Planモードre-entry時はgit checkout復元でなくarchiveスクリプトで対処する.md) ── **`status: superseded`（i9-01により置き換え）**
- [i00-07-ブランチslugの意訳生成はAIエージェントが行う.md](ddr/i00-07-ブランチslugの意訳生成はAIエージェントが行う.md)
- [i00-08-issue作成は独立スキルとして新設する.md](ddr/i00-08-issue作成は独立スキルとして新設する.md)
- [i00-09-コミットはcommitスキル経由を機構的に強制する.md](ddr/i00-09-コミットはcommitスキル経由を機構的に強制する.md)
- [i00-10-dev-toolsをAI専用_人間専用に分離する.md](ddr/i00-10-dev-toolsをAI専用_人間専用に分離する.md)
- [i00-11-調査結果のhtml版は自己完結htmlのコミットで作る.md](ddr/i00-11-調査結果のhtml版は自己完結htmlのコミットで作る.md)
- [i00-12-frontmatterスクリプトの走査方式にgit-ls-filesを採用する.md](ddr/i00-12-frontmatterスクリプトの走査方式にgit-ls-filesを採用する.md)
- [i00-13-gemini配下はGit管理下に置かずセットアップスクリプトで生成する.md](ddr/i00-13-gemini配下はGit管理下に置かずセットアップスクリプトで生成する.md)
- [i3-01-gemini-settings.jsonのhooksはレビュー提示スニペットのhooksセクションのみ採用する.md](ddr/i3-01-gemini-settings.jsonのhooksはレビュー提示スニペットのhooksセクションのみ採用する.md)
- [i9-01-planツール利用を全体作業計画に限定し個別計画をファイル分離する.md](ddr/i9-01-planツール利用を全体作業計画に限定し個別計画をファイル分離する.md)
- [i11-01-frontmatter抽出は1ファイル1回のjq呼び出しとmtimeキャッシュで高速化する.md](ddr/i11-01-frontmatter抽出は1ファイル1回のjq呼び出しとmtimeキャッシュで高速化する.md)
- [i13-01-レビュー依頼メッセージの参照リンクは前回pushSHAをローカル状態で保持して組み立てる.md](ddr/i13-01-レビュー依頼メッセージの参照リンクは前回pushSHAをローカル状態で保持して組み立てる.md)
- [i14-01-GitHub_GitLab情報取得はgh_glab-CLIを使いWebFetchは使わない.md](ddr/i14-01-GitHub_GitLab情報取得はgh_glab-CLIを使いWebFetchは使わない.md)
- [i20-01-HANDOFF進捗更新はMarkdownテーブル直接書き換えでループ範囲を一括操作する.md](ddr/i20-01-HANDOFF進捗更新はMarkdownテーブル直接書き換えでループ範囲を一括操作する.md)
- [i23-01-push断面の全文コピーをやめ行番号インデックスで表現する.md](ddr/i23-01-push断面の全文コピーをやめ行番号インデックスで表現する.md)（うち「Gemini CLI対応の扱い」は、issue #97でメインセッションのみ集計対象へ変更された。サブエージェントを集計しない部分は引き続き有効。詳細は i97-05）
- [i28-01-flow-id5-1の後片付けはスクリプト化しコミットは含めない.md](ddr/i28-01-flow-id5-1の後片付けはスクリプト化しコミットは含めない.md)（ファイル名の `flow-id5-1` は当時の番号。issue #112 の並べ替えにより、片付けは現在 flow-id 5-3。DDR i112-01 参照）
- [i32-01-GitLab-issueテンプレートは予約名Default.mdを正とし文書側を合わせる.md](ddr/i32-01-GitLab-issueテンプレートは予約名Default.mdを正とし文書側を合わせる.md)
- [i33-01-配布物の版はVERSIONファイル1つで表しCHANGELOGを持たない.md](ddr/i33-01-配布物の版はVERSIONファイル1つで表しCHANGELOGを持たない.md)
- [i33-02-配布テンプレートにLICENSEを同梱しない.md](ddr/i33-02-配布テンプレートにLICENSEを同梱しない.md)
- [i33-03-gitattributesは配布先へ丸ごとコピーせず必要な行だけ追記する.md](ddr/i33-03-gitattributesは配布先へ丸ごとコピーせず必要な行だけ追記する.md)
- [i34-01-gh_glab-CLI不在時はMCPフォールバック経路へ機構的に誘導する.md](ddr/i34-01-gh_glab-CLI不在時はMCPフォールバック経路へ機構的に誘導する.md)
- [i36-01-frontmatterのindex.jsonlをGit管理から外しSessionStart-hookで生成する.md](ddr/i36-01-frontmatterのindex.jsonlをGit管理から外しSessionStart-hookで生成する.md)
- [i38-01-ドキュメント探索はfrontmatterインデックス検索を第一手段にする.md](ddr/i38-01-ドキュメント探索はfrontmatterインデックス検索を第一手段にする.md)
- [i39-01-issue起票後の着手確認はブロックせず注意喚起の注入で担保する.md](ddr/i39-01-issue起票後の着手確認はブロックせず注意喚起の注入で担保する.md)
- [i41-01-PR_MR作成はAIエージェントに委ねマージのみ明示指示を必須にする.md](ddr/i41-01-PR_MR作成はAIエージェントに委ねマージのみ明示指示を必須にする.md)
- [i43-01-レビューコメントのソース断面はコメント時点のshaを優先し現HEADへ縮退する.md](ddr/i43-01-レビューコメントのソース断面はコメント時点のshaを優先し現HEADへ縮退する.md)
- [i44-01-リポジトリURLはgh_glabではなくgit-remoteから導出する.md](ddr/i44-01-リポジトリURLはgh_glabではなくgit-remoteから導出する.md)
- [i45-01-プロバイダ判定はremote-URLのホスト部でgithub以外をgitlabとみなす.md](ddr/i45-01-プロバイダ判定はremote-URLのホスト部でgithub以外をgitlabとみなす.md)
- [i46-01-defaultブランチとのコンフリクトは検知を機構化し解消手順をスキル化する.md](ddr/i46-01-defaultブランチとのコンフリクトは検知を機構化し解消手順をスキル化する.md)
- [i48-01-空コミットフォールバックはGitHub固有の制約として残す.md](ddr/i48-01-空コミットフォールバックはGitHub固有の制約として残す.md)
- [i50-01-チャットで受けたレビュー判断はAIがMRの通常コメントへ記録する.md](ddr/i50-01-チャットで受けたレビュー判断はAIがMRの通常コメントへ記録する.md)
- [i57-01-compact後もSessionStart-hookで作業コンテキストを再注入する.md](ddr/i57-01-compact後もSessionStart-hookで作業コンテキストを再注入する.md)
- [i60-01-create-commitは削除ステージ済みパスをgit-addの失敗時分類で吸収する.md](ddr/i60-01-create-commitは削除ステージ済みパスをgit-addの失敗時分類で吸収する.md)
- [i63-01-機構自身の単体テストは.claude_scripts_test配下へ置く.md](ddr/i63-01-機構自身の単体テストは.claude_scripts_test配下へ置く.md)
- [i64-01-issueの分割は並列列挙構造を主トリガーにAIが提案し人間が決定する.md](ddr/i64-01-issueの分割は並列列挙構造を主トリガーにAIが提案し人間が決定する.md)
- [i67-01-作業開始時のベースブランチ追従確認は専用スクリプトで検知しユーザー確認を挟む.md](ddr/i67-01-作業開始時のベースブランチ追従確認は専用スクリプトで検知しユーザー確認を挟む.md)
- [i68-01-issue起票前の重複チェックは検索をProvider層へ置きキーワード抽出はAIに委ねる.md](ddr/i68-01-issue起票前の重複チェックは検索をProvider層へ置きキーワード抽出はAIに委ねる.md)
- [i77-01-敵対的レビューは専任サブエージェントで独立コンテキストに切り出す.md](ddr/i77-01-敵対的レビューは専任サブエージェントで独立コンテキストに切り出す.md)
- [i77-02-レビュー観点はディレクトリごとのREVIEW-POINTSへ外だしする.md](ddr/i77-02-レビュー観点はディレクトリごとのREVIEW-POINTSへ外だしする.md)
- [i77-03-インラインコメントの位置指定はプロバイダごとの制約に合わせて縮退させる.md](ddr/i77-03-インラインコメントの位置指定はプロバイダごとの制約に合わせて縮退させる.md)
- [i86-01-マージ前の関連issue通知はDraft解除の直前に置き投稿前の人間承認を必須にする.md](ddr/i86-01-マージ前の関連issue通知はDraft解除の直前に置き投稿前の人間承認を必須にする.md)
- [i87-01-個別計画には結果を書かず実施結果はreports配下のmdへ分離する.md](ddr/i87-01-個別計画には結果を書かず実施結果はreports配下のmdへ分離する.md)
- [i88-01-PR作成後のdefaultブランチ追従は並行手順として定義し自動解消は一意に決まる類型に限る.md](ddr/i88-01-PR作成後のdefaultブランチ追従は並行手順として定義し自動解消は一意に決まる類型に限る.md)
- [i92-01-全体作業計画には調査・反映の枠を必ず残し省略判断は各フェーズ直前で行う.md](ddr/i92-01-全体作業計画には調査・反映の枠を必ず残し省略判断は各フェーズ直前で行う.md)
- [i95-01-plans配下のfrontmatter-typeはguideではなくplanを新設する.md](ddr/i95-01-plans配下のfrontmatter-typeはguideではなくplanを新設する.md)
- [i97-01-Gemini集計の差分はファイル全体の畳み込みと前回累計の差分で取る.md](ddr/i97-01-Gemini集計の差分はファイル全体の畳み込みと前回累計の差分で取る.md)
- [i97-02-Gemini集計はrewindToを読み飛ばしメッセージを削らない.md](ddr/i97-02-Gemini集計はrewindToを読み飛ばしメッセージを削らない.md)
- [i97-03-対応工数レポートのトークン列はengineではなくデータで決める.md](ddr/i97-03-対応工数レポートのトークン列はengineではなくデータで決める.md)
- [i97-04-Gemini経路のブランチ帰属は断面時点のブランチとし限界を明示する.md](ddr/i97-04-Gemini経路のブランチ帰属は断面時点のブランチとし限界を明示する.md)
- [i97-05-Gemini-CLIのサブエージェントは保存のみとし集計しない.md](ddr/i97-05-Gemini-CLIのサブエージェントは保存のみとし集計しない.md)
- [i106-01-敵対的レビューの非対話判定は環境変数ではなくAIエージェントの判断に委ねる.md](ddr/i106-01-敵対的レビューの非対話判定は環境変数ではなくAIエージェントの判断に委ねる.md)
- [i109-01-敵対的レビュー由来のスレッドも人間の指摘と同列に返信を必須とする.md](ddr/i109-01-敵対的レビュー由来のスレッドも人間の指摘と同列に返信を必須とする.md)
- [i112-01-フェーズ5は片付けをcommit直前へ移した順序に並べ替える.md](ddr/i112-01-フェーズ5は片付けをcommit直前へ移した順序に並べ替える.md)
- [i113-01-issue-mr-flow対象ブランチではSKILL.mdの再読み込みを注入で促す.md](ddr/i113-01-issue-mr-flow対象ブランチではSKILL.mdの再読み込みを注入で促す.md)
- [i117-01-削除済み追跡ファイルの除外はextract-frontmatter側で行う.md](ddr/i117-01-削除済み追跡ファイルの除外はextract-frontmatter側で行う.md)
- [i133-01-DDR識別子はissue番号ベースにし連番採番をやめる.md](ddr/i133-01-DDR識別子はissue番号ベースにし連番採番をやめる.md)
