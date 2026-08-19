---
title: worklog 類似issue検索関数と起票前チェック手順（issue #68）
type: log
description: issue #68の実装ログ。search_issues関数群の設計判断・キーワード抽出をAI側へ置いた理由・単体テストの範囲を記録する
tags: [worklog, issue-create, vcs-provider]
keywords: [search_issues, merge_issue_search_results, 正規化, キーワード抽出, closed, MCPフォールバック, issue68]
---

# worklog: 【実装】【テスト】類似issue検索関数と起票前チェック手順

対象: issue #68「issue起票時に類似・重複issueをチェックする手順が無い」（2026-08-19）。
全体作業計画: `plans/duplicate-issue-check-flow.md`
個別作業計画: `plans/【実装】【テスト】類似issue検索関数と起票前チェック手順.md`
push回数: 1

## 試したこと

### キーワード抽出をbashで実装できるか

最初に「`extract_issue_keywords <text>` のような純粋関数をbashへ実装し、単体テストを付ける」形を
検討した（issue #68の受け入れ条件が「純粋ロジック部分（キーワード抽出等）の単体テスト」と
書いていたため）。日本語の分かち書きを外部依存なしで行う方法として、次を検討した。

| 方式 | 判定 |
|---|---|
| ひらがなを区切り文字とみなし、漢字・カタカナの連続を語として切り出す | 助詞・送り仮名がほぼひらがなであるため一見それらしく動くが、`${text:i:1}` による1文字取り出しがロケール依存（git bashで `LANG` がUTF-8でないとバイト単位になる）で、実行環境によって結果が変わる |
| bashの文字クラス（`[[ $c == [ぁ-ん] ]]`）で判定 | 同じくロケール（`LC_COLLATE`）依存。範囲指定の解釈が環境で変わる |
| 汎用語（「追加」「修正」等）のストップワードリストを持つ | リストの保守が必要で、しかも「そのissue固有の語かどうか」はリポジトリの文脈に依存するため、固定リストでは決まらない |

いずれも「動くこともあるが、環境と語彙に依存して静かに劣化する」形にしかならず、
**重複チェックの再現率が下がってもエラーにならない**（誰も気づけない）のが致命的だと判断した。

### 検索のAND/OR

`gh issue list --search "類似 重複 起票"` のように1回で検索するとAND条件になり、
キーワードを増やすほどヒットしなくなる。重複チェックで欲しいのは再現率なので、
キーワードごとに1回検索して結果を統合する方式へ変えた。

## うまくいったこと

- **キーワード抽出はスキル（AI）側の責務とし、`Provider.sh` は「与えられたキーワードで検索し
  結果を正規化・統合する」ことに専念させた。** `issue-create` スキルではAIが直前に自分で
  タイトル・4見出しを組み立てており、そのissue固有の語がどれかを最もよく知っている。
  スキル側には粒度の指針（選ぶ語／選ばない語の例）を書いて再現性を持たせた。
- **純粋関数として切り出せたのは正規化と統合の部分だった。** `github_normalize_issue_search_results`
  / `gitlab_normalize_issue_search_results` / `merge_issue_search_results` はいずれも
  `gh`/`glab` を呼ばずjqだけで完結するため、`.claude/scripts/test/test_vcs_provider.sh` から直接テストできる
  （`gitlab_format_discussion_notes` と同じ切り出し方）。単体テストは9件追加し、
  `passed=53 failures=0`。
- **`state` の表記ゆれを共通形式で吸収した。** GitHub CLIは `OPEN`/`CLOSED`、GitLabは
  `opened`/`closed` を返す。どちらも `open`/`closed` へ正規化することで、呼び出し側が
  プロバイダを意識せず「closedのissueがヒットした」と判定できる。
- `merge_issue_search_results` は引数0個のときに `[]` を返すようにした。`printf '%s\n' "$@"` は
  引数が無いと空行を1つ出力し、そのままjqへ流すとパースエラーになるため。テストでも固定した。
- jqへ渡すJSONは引数（`--argjson`）ではなく標準入力経由にした。検索結果の件数・本文長は
  呼び出し側で保証できず、`jq: Argument list too long` で起動自体が失敗しうるため
  （`.claude/rules/shell-script-style.md`「JSON操作」の既知の落とし穴）。

## ダメだったこと

- **この実行環境（Claude Code on the web）では `gh` CLIが無いため、`search_issues` の
  CLI経路そのものは実機検証できていない。** 検証できたのは、`require_vcs_cli` が正しく
  MCPフォールバックの案内（`mcp__github__search_issues`）を出して失敗するところまで。
  `gh issue list --search ... --state all --json number,title,state,url` の実行結果に対する
  正規化は、実際のCLI出力形式を模したフィクスチャでのテストに留まる。
  GitLab側（`glab issue list --search --all --per-page --output json`）も同様に未検証。
  この制約はspecの「未決定事項・懸念点」へ記録する。

## 次の一歩

- 設計反映（spec・DDR）へ進む。DDRには「キーワード抽出をAI側へ置いた判断」「closedを含める
  理由」「最終判断は人間が行う原則」と却下案を残す。
