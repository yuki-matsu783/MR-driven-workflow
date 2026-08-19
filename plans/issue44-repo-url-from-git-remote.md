---
title: 【全体作業計画】get_repo_urlをgh/glab呼び出しからgit remote由来の導出へ置き換える
type: log
description: issue #44の全体作業計画。get_repo_urlのプロバイダ依存を解消し、git remoteの正規化だけでリポジトリURLを導出する方針と進め方
tags: [plan, vcs-provider, url]
keywords: [issue44, get_repo_url, repo_url_from_remote_url, git remote, プロバイダ非依存, DDR 0035, 単体テスト]
---

# 【全体作業計画】issue #44: get_repo_urlをgit remote由来の導出へ置き換える

> **注記**: 本ファイルは通常 planツール（Planモード）で作成する「全体作業計画」だが、本セッションは
> Claude Code on the web の非対話的実行環境であり、Planモードの承認往復ができない。そのため
> Write/Editで直接作成し、ファイル名もハーネス自動命名ではなく内容由来の名前にしている
> （`.claude/rules/docs-workflow.md`「非対話的実行環境」の考え方に準じる）。

## 対象

- issue: [#44](https://github.com/yuki-matsu783/MR-driven-workflow/issues/44)
- ブランチ: `claude/get-repo-url-git-remote-3f9oba`（本セッションで指定されたブランチ。
  `branchPrefixTemplate`（`feature-<issue番号>-<slug>`）とは異なるが、指示により変更しない）

## 全体像

`get_repo_url` は `gh repo view --json url` / `glab repo view --output json`（`.web_url`）へ
ディスパッチするプロバイダ依存関数になっているが、実機で両者の戻り値が `git remote get-url origin`
の値と `.git` サフィックスの有無しか違わないことがissue本文で確認済みである。これを
`git remote get-url origin` の正規化へ置き換えることで、

1. プロバイダ依存関数を1つ減らす（`Github.sh` / `Gitlab.sh` から repo URL 取得の関数が消える）
2. pushのたびに走る `post-push-compact-prompt.sh` から外部CLI起動＋API往復を1回除去する
3. `gh`/`glab` 不在環境（Claude Code on the web）でも同じ経路で参照リンクを組み立てられる
   （issue #34で入れた経路ごとの分岐も不要になる）

の3点を達成する。

## 進め方（フェーズ割り当て）

| フェーズ | 実施 | 理由 |
|---|---|---|
| 1（起票・準備） | 実施 | issueは起票済み。ブランチはセッション指定のものを使う。PRは指示があるまで作成しない |
| 2（調査） | **省略** | 調査の結論はissue本文の「現状」に既に書かれている（両CLIの戻り値の一致、gitで解決できる差分が他に無いこと、DDR 0023との関係）。改めて調査すべき未知が無い |
| 3（実装・テスト） | 実施 | `repo_url_from_remote_url` の実装、旧関数の削除、単体テストの追加 |
| 4（設計反映） | 実施 | spec「提供関数」表・新節、DDR 0035、`.claude/docs/README.md` のDDR一覧 |
| 5（片付け・マージ） | 一部 | `plans/` `worklog/` の削除・Draft解除・マージは人間の判断を要するため本セッションでは行わない |

## 受け入れ条件（issue #44）との対応

| 受け入れ条件 | 対応 |
|---|---|
| `get_repo_url` が `Provider.sh` に実装され、`Github.sh` / `Gitlab.sh` から repo URL 取得の関数が消えている | フェーズ3 |
| 本リポジトリで戻り値が `gh repo view --json url --jq '.url'` の出力と一致する | フェーズ3（実行環境に`gh`が無いため、issue本文に記録された実測値との一致で確認する） |
| 単体テストを追加し `passed=N failures=0` で通る | フェーズ3（`.claude/scripts/test/test_vcs_provider.sh`。issue本文の `tests/` はissue #63以前のパスで、現在の正しい配置は `.claude/scripts/test/`） |
| `post-push-compact-prompt.sh` が従来どおり参照リンクを組み立てられる | フェーズ3（hookへ疑似ペイロードを与えた実行で確認） |
| リスクケース（`insteadOf`・カスタムポート・リポジトリ名変更）の扱いを spec または DDR に明記 | フェーズ4（specの新節とDDR 0035の両方に記載） |

## 未決定事項

- PRの作成・Draft解除・マージは本セッションでは行わない（ユーザーからの明示的な指示待ち）。
