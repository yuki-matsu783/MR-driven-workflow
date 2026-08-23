---
title: 全体作業計画 ユースケース起点ドキュメント（.claude/docs/usecase/）の新設
type: plan
description: issue #170「機能の逆引きを可能にするユースケース起点ドキュメント層の新設」をどう進めるかの全体像（調査・作業・反映の枠組み）
tags: [usecase-docs, plan, docs]
keywords: [ユースケース, 逆引き, usecase, frontmatter, doc-search, README目次, 設計反映, 全体作業計画]
---

# 全体作業計画: ユースケース起点ドキュメント（.claude/docs/usecase/）の新設

- issue: #170
- ブランチ: `claude/usecase-docs-setup-uvs5li`（ハーネス指定。`feature-170-*` 形式は使わない）
- PR: #173（Draft）
- 作成日: 2026-08-23

## 目的

spec（15本）・DDR（76本）・スキル定義はいずれも機能起点であり、「やりたいこと」起点の索引が無い。
`.claude/docs/usecase/` を新設し、1ユースケース1ファイルで「どんな場面か／使う機能と流れの概要／
何が得られるか／詳細へのリンク」を提供する。手順の正は従来どおりspec/SKILL.md側に置き、
usecase文書は**逆引きの索引＋概観に徹する**（手順詳細を再掲しない）。

## 実行環境と運用の前提（このブランチ固有）

- 非対話セッション（Claude Code on the webのリモート実行環境）。人間のレビュー往復
  （flow-id 2-3/2-8/3-3/3-8/4-3/4-8）は待てないため、**ユーザーの明示指示に基づき、
  各フェーズの計画のpush後に1回・作業実施のpush後に1回、敵対的レビュー
  （`adversarial-review` スキル）を自律起動し、指摘を自動で修正しながら進める**。
  各フェーズ最大3回の上限（`adversarial-review-count.sh`）の範囲内に収まる（計画1回＋実施1回=2回）。
- 人間レビュー待ちのループ範囲の進捗記号は `[]` のまま残し、実施内容は「やったこと」へ文章で補足する
  （`.claude/rules/docs-workflow.md`「非対話的実行環境での扱い」）。
- 敵対的レビューが投稿したスレッドへは、修正後に `reply`（MCP経路）で全件返信する（issue #109）。

## issue分割の判定（flow-id 1-4）

issue #170の「期待する動作」には初期ユースケース8件が並列に列挙されているが、**分割しない**。
1件あたりが極小（1ファイル・数十行のmd）で、フローの固定費（5フェーズ42ステップ×8）が本体の
作業量を大きく上回るため（SKILL.md「分割しない条件: 分割コストが本体を上回る」に該当）。
文書一式は1回のレビューで俯瞰できる規模に収まる。

## 変更対象（領域の粒度。個別ファイルは各フェーズの個別計画で確定する）

| 領域 | 操作 | 何をするか |
|---|---|---|
| `.claude/docs/usecase/` | 新規 | ユースケース文書一式（＋必要なら目次） |
| `.claude/rules/markdown-frontmatter.md` | 変更 | 「typeの値」表へ `usecase` を追記 |
| `.claude/docs/README.md` | 変更 | 目次へusecase節を追加 |
| `.claude/skills/issue-mr-flow/SKILL.md` | 変更 | flow-id 4-6（設計反映）の確認対象へ「ユースケース文書への影響」を追加 |
| `.claude/rules/directory-structure.md`・`index.md` | 変更 | ディレクトリツリー・Repository Mapへ `usecase/` を反映（整合のため。要否はフェーズ2で確認） |

## 方針

- usecase文書の構成は issue の期待どおり「どんな場面か／使う機能と流れの概要／何が得られるか／
  詳細へのリンク（spec・SKILL.md）」の4部構成を基本形とする。
- frontmatterは既存規約（`.claude/rules/markdown-frontmatter.md`）に従い、`type: usecase` を新設して
  `doc-search`（index.jsonl）で `--type usecase` の絞り込みを可能にする。
- 初期ユースケースはissue記載の8件を起点に、フェーズ2の調査で取捨選択・追加を判断する。

## フェーズ2〈調査〉

実施する。調べる問い:

1. 初期ユースケース8件それぞれについて、対応する機能（スキル・スクリプト・hook・spec）が現存するか。
   リンク先（spec/SKILL.md/rules）はどこが適切か。
2. 8件の取捨選択・統合・追加の判断（例: 工数レポートhookは現存するか、他に主要なユースケースの
   取りこぼしが無いか）。
3. usecase文書のファイル命名規則と、目次の要否（README目次で足りるか、`usecase/README.md` を置くか）。
4. `type: usecase` の追加で `extract-frontmatter.sh` / `search-frontmatter.sh` 側の変更が要るか
   （typeを自由値として扱っているなら変更不要のはず。実機で確認する）。
5. flow-id 4-6 の手順文のどこへ「ユースケース文書への影響確認」を差し込むか（挿入位置の前後の
   係り受けの確認を含む。`.claude/rules/docs-workflow.md`「見出し差し込み時の注意」）。
6. `directory-structure.md`・`index.md`・`distribution-assets`（配布物）への波及の有無。

これらが分かれば、フェーズ3の個別作業計画（ファイル一覧・各文書の骨子）を書ける。

## フェーズ3〈作業〉

調査結果に基づき、`【AIアセット作成】` の個別作業計画を作成して実施する（usecase文書一式の作成、
frontmatter規約・README目次・SKILL.md 4-6・ツリー系ドキュメントの更新、index.jsonl再生成と
`doc-search` での検索確認）。

## フェーズ4〈反映〉

反映対象は flow-id 4-1 で洗い出す。見込みの候補（確定ではない）:

- 設計反映: usecase層の設計判断（配置・構成・typeの新設理由）をDDRへ残すかの判断。
- AIアセット反映: 作業中に気づいたルール・スキルの不備があれば反映する。

## フェーズ5〈クローズ〉

標準どおり（コンフリクト検知→関連issue通知→統括レポート→片付け→Draft解除）。
マージは行わない（人間の担当）。非対話セッションのため、関連issue通知（flow-id 5-2）は
**承認を取れない場合は投稿せず**、判断結果を最終応答とHANDOFF（リセット前）へ明示する。

## やらないこと（スコープ外）

- 既存spec/SKILL.mdの手順詳細のusecase文書への再掲（issueの明示的な禁止事項）。
- 既存ドキュメントの再構成・移動（usecase層の追加のみを行う）。
- GitLab側の検証（このリポジトリはGitHub。usecase文書は特定プロバイダに依存しない記述にする）。

## 検証（issue受け入れ条件との対応）

| 受け入れ条件 | 確認方法 |
|---|---|
| `.claude/docs/usecase/` に初期ユースケース文書一式（＋必要なら目次） | ファイル一覧の提示 |
| `type: usecase` が定義され `doc-search` で絞り込める | `bash .claude/scripts/src/search-frontmatter.sh --type usecase` が全usecase文書を返す |
| `.claude/docs/README.md` の目次から辿れる | README目次のリンク先が実在する |
| 手順詳細を重複記載していない（リンク参照） | 敵対的レビューの観点に含めて確認 |
| flow-id 4-6 にユースケース文書への影響確認が組み込まれている | SKILL.md（および関連ドキュメント）の差分確認 |
