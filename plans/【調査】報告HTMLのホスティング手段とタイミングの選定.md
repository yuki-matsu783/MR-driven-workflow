---
title: 【調査】報告HTMLのホスティング手段とタイミングの選定
type: plan
description: reports/配下の報告HTMLをホストしURLを払い出す手段（GitLab Review Apps／GitHub Pages等）と、reports/が削除される前後のどこでホストするかを決めるための個別調査計画。
tags: [issue-mr-flow, hosting, review-apps, github-pages]
keywords: [issue114, 調査計画, Review Apps, GitHub Pages, GitLab Runner, 配布資産, flow-id 5-3, flow-id 5-5, タイミング, 却下案]
---

# 【調査】報告HTMLのホスティング手段とタイミングの選定

## 前提（合意状況）

- 上位の計画: `plans/binary-soaring-eclipse.md`（**flow-id 1-5 で合意**）。調査する4つの問いは
  その「フェーズ2〈調査〉」節が持つ。本計画はそれを実行手順まで具体化したものである。
- issue を分割せず1件で進めること・GitHub / GitLab とも**実機検証まで行う**ことは、
  **flow-id 1-4 でユーザーが判断**した。
- **まだ合意されていない**: 手段の選定結果そのもの。本調査の結論は `reports/` へ書き、
  flow-id 2-8 の人間のレビューで合意する。

## この計画で何をするか

issue #114 の実装方針を決めるために、次の2つを確定させる。

1. **どの手段でホストするか**（GitLab / GitHub それぞれ。却下した手段は却下理由つきで残す）
2. **フローのどこでホストし、どこで通知するか**（`reports/` は flow-id 5-4 で削除されるため、
   「マージ依頼時にホストする」を素直に実装できない）

あわせて、**配布物としてのCI設定の扱い**と、**実機検証に必要な環境の構築コスト**を見積もる。

## 変更対象

**この調査ではリポジトリのコード・設定を変更しない。** 成果物は `reports/` 配下のみ。

| ファイル | 操作 | 何をするか |
|---|---|---|
| `reports/20260823_binary-soaring-eclipse_ホスティング手段の比較.md` | 新規 | 調査結果の**正文**。4つの問いへの結論・根拠・却下案 |
| `reports/20260823_binary-soaring-eclipse_ホスティング手段の比較.html` | 新規 | 同内容の人間レビュー用ビュー（土台は `.claude/skills/issue-mr-flow/assets/reports.template.html`） |
| `worklog/20260823_binary-soaring-eclipse_【調査】報告HTMLのホスティング手段とタイミングの選定_push1.md` | 新規 | 試行錯誤の詳細ログ |

**実機検証（GitHub Pages の有効化・GitLab Runner の構築）はこの調査では行わない。**
必要条件の洗い出しと手順の確認までに留め、実際の構築・デプロイはフェーズ3で行う
（下記「やらないこと」）。

## 方針

### 問い1: タイミングの矛盾（最優先で解く）

現行のフロー順は **5-3（統括レポート作成・commit・push）→ 5-4（`reports/` 削除）→ 5-5
（commit・push・Draft解除＝マージ依頼）** である。「マージ依頼時にホストする」を素直に実装すると
対象ファイルが既に無い。

次の3案を、同じ観点で比較して1つ選ぶ。

| 案 | 概要 |
|---|---|
| (a) 不変パス | CI が push ごとにデプロイし、デプロイ先を**コミットSHA単位の不変パス**にする。5-4 の削除pushは新しい空デプロイを作るだけで、5-3 時点のデプロイは残る。5-5 では「最後に中身のあったデプロイ」のURLを提示する |
| (b) 5-3でホスト | ホスト自体を flow-id 5-3 で行い、5-5 では**通知のみ**行う |
| (c) SHA指定 | 5-5 で、削除前のコミット（5-3 のSHA）をCIへ明示的に指定してデプロイさせる |

**比較の観点**（3案すべてに同じ表で答える）:

- 5-4 の削除pushが、既にホストされた内容を**壊さないか**
- CIの実行回数・待ち時間（レビュー往復のたびにデプロイが走らないか）
- **CIが無い／失敗する環境で、フローが止まらないか**
- 配布先で設定が要るか（Pages の有効化、Runner の登録など）
- 実装が `Provider.sh` の既存の形（失敗は正常系）に収まるか

### 問い2: GitHub の手段

第一候補は **GitHub Pages ＋ Actions**。次を**一次情報（公式ドキュメント）で**確認する。

- Pages は1リポジトリ1サイトである制約下で、PRごとの並列プレビューをどう表現するか
  （`gh-pages` ブランチのサブディレクトリ方式／Pages の deployment API）
- Actions のデプロイ完了をどう待ち、URLをどう取得するか
  （`gh run watch` / `gh api repos/{o}/{r}/deployments` / environment の URL）
- fork からのPRで `GITHUB_TOKEN` の書き込み権限が落ちる問題の有無
- **Pages 有効化に必要な操作**（API で可能か、Web UI が必須か）

**却下候補は、却下理由つきで必ず記録する**（後で「なぜそれを使わないのか」を再検討しないため）。

| 却下候補 | 想定される却下理由（調査で裏を取る） |
|---|---|
| raw.githubusercontent.com | HTML を `text/plain` で返しレンダリングされない |
| Actions artifact | ダウンロードのみ。ブラウザで開けない・ログインが要る |
| `upload_attachment`（既存の層3） | 添付はダウンロード用。#114 の「ブラウザで開ける」を満たさない |
| 外部ホスティング（Netlify等） | リポジトリ外のアカウント・シークレットが要り、配布物として成立しない |

### 問い3: GitLab の手段

CI/CD Review Apps（動的環境）について次を確認する。

- `.gitlab-ci.yml` の `environment.name`（動的環境名）・`environment.url`・`on_stop` の書き方
- **ホストの実体**（GitLab Pages を使うか、Runner 上の静的サーバか）と、それぞれの前提
- **GitLab Runner の構築手順**: executor の選定、Docker版 GitLab CE（`gitlab-verification-environment.md`
  の構成）への登録手順、ローカル環境（Windows + Docker Desktop + git bash）で踏みそうな落とし穴
- 払い出された URL を `glab` から取得する方法（`glab api projects/:id/environments` 等）

### 問い4: 配布物としての扱い

`.gitlab-ci.yml` / `.github/workflows/*.yml` は `.claude/` の外に置かれるため、plugin配布の
対象外である。`.claude/docs/spec/distribution-assets.md` の仕組み（`.gitattributes` の
`dist:begin`〜`dist:end` 方式）を読み、次を決める。

- CI設定を配布資産に**含めるか／含めないか**
- 含める場合、**配布先が既にCI設定を持っているときに壊さない**方法（追記か、別ファイル名か、
  雛形の提示に留めるか）

### 進め方

1. 一次情報（GitHub Docs / GitLab Docs）を読み、問い2・問い3の必要条件を確定する
2. リポジトリ内の既存資産（`Provider.sh` の `upload_attachment`、`distribution-assets.md`、
   `gitlab-verification-environment.md`）を読み、既存の形に合わせられるかを確認する
3. 問い1の3案を、上記の観点表で比較して1案を選ぶ
4. 結果を `reports/` のmd（正文）とHTMLへ書く。worklog には試行錯誤を随時書き足す

## やらないこと（スコープ外）

- **実装（コード・CI設定・SKILL.md の変更）**。この調査は方針を決めるところまでで、実装は
  flow-id 3-1 以降で個別作業計画を立ててから行う。
- **GitHub Pages の有効化と、GitLab Runner の実構築**。必要条件と手順の確認までに留める
  （実機検証はフェーズ3で行う。ユーザーの判断で「実機検証まで行う」と決まっているが、
  調査段階でリポジトリ設定を変更すると、方針が覆ったときに戻す手間だけが残る）。
- **ホストしたHTMLの公開範囲・寿命の制御**（issue の受け入れ条件でスコープ外と確定済み）。
- **`reports/` の削除タイミング（flow-id 5-4）の変更**（上位計画でスコープ外と確定済み）。
- `plans/` のHTMLビューをホスト対象に含めるか — **この調査で判断する**（上位計画が
  flow-id 2-6 へ送った判断であるため、スコープ外ではなく問い1の付随事項として扱う）。

## 検証

調査そのものに自動テストは無い。**次の条件がすべて満たせたら、この調査は完了である。**

```bash
# 成果物が揃っていること
ls reports/20260823_binary-soaring-eclipse_ホスティング手段の比較.md \
   reports/20260823_binary-soaring-eclipse_ホスティング手段の比較.html

# HTMLにテンプレートのプレースホルダが残っていないこと（0であること）
grep -c '<!-- ここに書く' reports/20260823_binary-soaring-eclipse_ホスティング手段の比較.html

# HTMLが自己完結していること（いずれも0件であること）
grep -nE "(src|href)=['\"]?(https?:)?//" reports/20260823_binary-soaring-eclipse_ホスティング手段の比較.html
grep -nE "(url\(|@import[[:space:]]+)['\"]?(https?:)?//" reports/20260823_binary-soaring-eclipse_ホスティング手段の比較.html
```

**合格条件**:

1. 問い1の3案が**同じ観点表**で比較され、選んだ案とその理由が書かれている
2. 問い2・問い3が**一次情報の参照つき**で答えられている（推測のまま結論にしない）
3. **却下した手段が、却下理由つきで**記録されている（GitHub側の4候補を含む）
4. 問い4の結論（配布資産に含めるか）が書かれている
5. **フェーズ3で立てる個別作業計画が、この結果だけを読んで書ける**こと
6. md と HTML の節見出しが一致しており、内容が同期していること
