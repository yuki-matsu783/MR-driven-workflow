---
title: issue #127 GitLab側13関数とURL形式のローカル実機検証（全体作業計画）
type: plan
description: ローカルGitLab CE 18.5.4に対しProvider.sh経由で未検証13関数・URL系4種・サブグループ解決を実機検証し、不具合修正と正史ドキュメントへの反映まで行う全体作業計画。
tags: [gitlab, verification, workflow, provider]
keywords: [GitLab CE, glab, Provider.sh, Gitlab.sh, 実機検証, 差分アンカー, sha1, サブグループ, 敵対的レビュー, 未決定事項]
---

# issue #127 全体作業計画

- issue: [#127](https://github.com/yuki-matsu783/MR-driven-workflow/issues/127)
- ブランチ: `feature-127-verify-gitlab-functions-and-url-formats`（base: `main`）
- PR: [#128](https://github.com/yuki-matsu783/MR-driven-workflow/pull/128)（Draft）

## Context（なぜやるか）

`Gitlab.sh` は issue #48 で全13関数を、issue #45 で `Provider.sh` 経由のディスパッチを、
ローカルGitLab CE 18.5.4に対して実機検証済みである。しかしその後 `Gitlab.sh` は25関数へ増え、
**追加された13関数が一度も実機で動いていない**。加えてURL系（blob・差分アンカー・note
パーマリンク・Compare）はブラウザでの表示確認が一度も行われておらず、`Gitlab.sh` のヘッダは
issue #45 で解消済みの制約を「未修正」と書いたまま古くなっている。

いま手元でGitLab CE 18.5.4コンテナが稼働し `glab` 1.114.0 が `localhost:8929` に認証済みという、
検証できる条件が揃っている。この機会に未検証範囲を潰し、spec の「未決定事項・懸念点」から
解消済み項目を落として、ドキュメントを実態に一致させる。

### 事前確認済みの事実（flow-id 1-4 時点）

| 項目 | 状態 |
|---|---|
| GitLab CEコンテナ | `gitlab` / `Up 20 hours (healthy)` / `0.0.0.0:8929->8929`, `0.0.0.0:2224->22` |
| `glab` | 1.114.0。`localhost:8929` に `root` でログイン済み（keyring）。git操作は **ssh** プロトコル設定 |
| 既存プロジェクト | `root/issue45-verify`（id=1）が残存。他2件は削除予約済み |
| `get_provider` | issue #45 で修正済み（`*github*` 以外はGitLab）。self-hosted・localhost を判定できる |
| 検証環境の再現手順 | **リポジトリ内に存在しない**（`docker run` / `glab auth login` の記載を grep で確認） |
| ローカルの検証用クローン | 見つからず。作り直しが必要 |

## スコープの判断

- **分割しない**（flow-id 1-4 でユーザーが決定）。13関数は「並列に作る成果物」ではなく1つの
  検証キャンペーンのチェック項目で、成果物は `reports/` 1本 + 不具合修正 + spec更新に収束する。
  GitLab CEコンテナ・`glab` 認証・テストプロジェクト作成という共通の固定費が大きく、分割すると
  5フェーズ41ステップの手続きコストが本体を上回る。
- **範囲外**: gitlab.com（SaaS）・CE 18.5.4 以外のバージョン・EE。issue の期待する動作7に従い、
  範囲外である旨を spec に残す。

## 検証対象の13関数

`Gitlab.sh` 25関数のうち、issue #48 の検証を受けていないもの。

| # | 関数 | 由来 | 種別 |
|---|---|---|---|
| 1 | `gitlab_search_issues` | #68 | CLI呼び出し |
| 2 | `gitlab_normalize_issue_search_results` | #68 | 純粋関数（jq） |
| 3 | `gitlab_set_mr_ready` | #61 | CLI呼び出し |
| 4 | `gitlab_add_issue_comment` | #86 | CLI呼び出し |
| 5 | `gitlab_get_mr_url` | #42 | URL組み立て |
| 6 | `gitlab_get_note_url` | #42 | URL組み立て |
| 7 | `gitlab_get_blob_url` | #42 | URL組み立て |
| 8 | `gitlab_get_diff_anchor_url` | #42 | URL組み立て |
| 9 | `gitlab_diff_anchor_algo` | #42 | 純粋関数 |
| 10 | `gitlab_add_mr_thread` | #77 | CLI呼び出し |
| 11 | `gitlab_build_discussion_body` | #77 | 純粋関数 |
| 12 | `gitlab_summary_post_kind` | #77 | 純粋関数 |
| 13 | `gitlab_add_mr_inline_comments` | #77/#121 | CLI呼び出し |

**すべて `gitlab_*` の直呼びではなく `Provider.sh` のディスパッチャ経由**（`search_issues` /
`set_mr_ready` / `add_issue_comment` / `get_mr_url` ...）で実行する。これが issue #48 との差分で
あり、期待する動作1の要点である。

## フェーズ2〈調査〉— 実施する

本issueの本体。検証そのものがフェーズ2にあたる。

### 2-1 個別調査計画で決めること

- **検証環境の作り方**: GitLab上に検証用プロジェクトを新規作成（例 `root/issue127-verify`）し、
  ローカルへクローンして `origin` をGitLab URLに向ける。`Provider.sh` は `git remote get-url origin`
  でプロバイダを判定するため、**cwdが検証用クローンであること**が `Provider.sh` 経由検証の前提。
  作業ディレクトリはスクラッチパッド配下に置き、本リポジトリのツリーを汚さない。
  - 確認事項: 検証用クローンには `.mrworkflow.json` が無いため `get_workflow_config` が
    既定値へフォールバックする。この差が検証結果に影響しないことを先に確かめる。
  - 確認事項: `glab` のgit操作が **ssh（port 2224）** 設定である点。http クローンで足りるかを
    先に切り分ける（ssh鍵の用意が要るなら http へ寄せる）。
- **検証の順序**: 純粋関数（#2, #9, #11, #12）→ URL組み立て（#5〜#8）→ CLI呼び出し
  （#1, #3, #4, #10, #13）。前二者は副作用が無く、失敗しても環境を汚さないため先に潰す。
  CLI呼び出し系は issue・MR・ノートという実データを順に作りながら進める。
- **記録の粒度**: 関数ごとに「呼び出しコマンド／実際の出力／期待どおりか／差異」を残す。

### 2-6 で実施する検証

1. **13関数を `Provider.sh` 経由で実行**（受け入れ条件1）。
2. **URL系4種の確認**（受け入れ条件2）。**差分アンカーが最大の焦点**で、実装は
   `#<パスのsha1>`（`diff-` 接頭辞なし）を前提にしている。GitLab CE 18.5.4 の実際の
   アンカーIDと突き合わせる。
   - 自動で取れる証拠: HTTPステータス、GitLab APIの diffs / diffs_metadata が返す
     ファイルハッシュ、`sha1` を自前計算した値との一致。
   - **ブラウザでの目視は私（AI）にはできない。** 自動確認で決着しない項目は、URLの一覧を
     提示してユーザーに開いてもらう（下記「ユーザーへ依頼する確認」）。
3. **サブグループ解決の確認**（受け入れ条件3）。`grp/sub/issue127-verify` のように
   ネストしたnamespaceへプロジェクトを作り、`glab` がプロジェクトを解決できるかを見る。
4. 結果を `reports/2026-08-20_zippy-petting-crown_gitlab実機検証結果.md`（正文）と
   同名 `.html`（視覚化）へ記録する。関数×検証観点のマトリクスが主題なので、canvas形式では
   なく通常のTailwind表形式を想定する。

### ユーザーへ依頼する確認

ブラウザでの表示確認は人間の目が要る。自動確認で確定できなかったURLだけを絞り込んで一覧提示し、
「意図した位置を指しているか」を回答してもらう。**一覧が出せる状態になった時点で依頼する**
（フェーズ2の終盤で一度にまとめる）。

## フェーズ3〈作業〉— 実施する見込み

検証で見つかった不具合の修正（受け入れ条件4）。issue #48 では3件見つかっており、今回も
0件で終わる可能性は低い。

- 修正対象は `.claude/scripts/src/vcs/Gitlab.sh`（必要なら `Provider.sh`）。
- 純粋関数の不具合は `.claude/scripts/test/test_vcs_provider.sh` へ**再発防止のケースを追加**する
  （既存のテスト構造に合わせる。`passed=N failures=N` 出力・失敗時 exit 1）。
- **検証で見つかった不具合が0件だった場合**、フェーズ3は「再現手順の文書化」だけになる可能性が
  ある。その場合もフェーズ3を丸ごと飛ばさず、文書化をここで行う。
- 修正後は、修正した関数を**もう一度 `Provider.sh` 経由で実行し直して**確認する
  （直したつもりで直っていない、を防ぐ）。

## フェーズ4〈反映〉— 必ず通る

反映対象は flow-id 4-1 で洗い出す。現時点での**候補**（確定ではない）:

- **設計反映**
  - `.claude/docs/spec/issue-mr-workflow.md`「未決定事項・懸念点」: #61 `gitlab_set_mr_ready`
    未検証・#68 `search_issues` CLI経路未検証・#13 URL形式のブラウザ未検証・#48/#45 の
    「プロジェクト構成（サブグループ）」の各項目を、検証結果に応じて削除／更新。
  - `.claude/docs/spec/shell-scripts.md`: 165〜166行「GitLab版の実機動作未検証」、27〜29行の
    移植表にある `Gitlab.sh`「（未検証。GitLab実remoteが無いため）」を更新。
  - `.claude/scripts/src/vcs/Gitlab.sh` ヘッダ: **issue #45 で解消済みなのに「未修正」と書いている
    記述の訂正**を含め、検証状況を実態へ合わせる。
  - 検証環境の再現手順（受け入れ条件8）の置き場所は 4-1 で決める。**新規specファイルを作る場合は
    人間の承認が必須**（`.claude/rules/docs-workflow.md`）。
  - 差分アンカーの `sha1` 前提が誤っていた場合など、方式の選択をやり直したらDDRを1本起こす。
- **AIアセット反映**: 検証中に気づいたルール・スキルの不備があれば `.claude/rules/`・
  `.claude/skills/` へ。無ければこの半分はスキップする。
- `【設計反映】` と `【AIアセット反映】` は原則ファイルを分ける。

## 進め方の取り決め

- **敵対的レビューを各pushの直後に実施する**（ユーザーからの明示指示）。対象は flow-id
  2-2/2-7/3-2/3-7/4-2/4-7 の直後、人間のレビューの前。各フェーズ最大3回の上限は
  `adversarial-review-count.sh` が強制する。実施しても進捗表は動かさない。
- **追従監視はローカル運用のため「なし」**。購読・自己チェックインの仕組みが無いので、
  各pushの直後と flow-id 5-2 で `check-base-conflicts.sh` を手動実行する。
- コミットは必ず `commit` スキル経由。`HANDOFF.md` の更新は同じコミットに含める。

## 検証（この計画自体の完了条件）

issue #127 の受け入れ条件9項目がすべて満たされていること。とくに次の3点を満たさない限り完了と
しない。

1. 13関数それぞれについて `Provider.sh` 経由の実行結果（成功／失敗と出力）が `reports/` にある。
2. 差分アンカーの `sha1` 前提の**正否が判明している**（「たぶん正しい」で終えない）。
3. `bash .claude/scripts/test/test_vcs_provider.sh` が `failures=0` で通る。
