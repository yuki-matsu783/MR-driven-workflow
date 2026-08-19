---
title: 【実装】【テスト】類似issue検索関数と起票前チェック手順
type: guide
description: issue #68の個別作業計画。search_issues関数群の実装方針・正規化するJSON形式・スキル手順の挿入位置・単体テストの対象を具体的に定める
tags: [issue-create, vcs-provider, test, plan]
keywords: [search_issues, normalize, merge_issue_search_results, gh issue list, glab issue list, 単体テスト, MCPフォールバック]
---

# 個別作業計画: 類似issue検索関数と起票前チェック手順（issue #68）

全体作業計画: `plans/duplicate-issue-check-flow.md`

種別を `【実装】` と `【テスト】` で併記するのは、追加するテストが実装した純粋関数の
振る舞いを固定するだけのもので、実装と別に合意を取る意味が無いため
（`.claude/skills/issue-mr-flow/SKILL.md`「種別を複数併記する場合／分ける場合」）。

## 1. 共通のJSON形式

`search_issues` の戻り値は、issue #68の指定どおり camelCase キーのJSON配列とする。

```json
[{"number":68,"title":"issue起票時に...","state":"open","url":"https://github.com/o/r/issues/68"}]
```

- `state` は `open` / `closed` の2値へ正規化する。GitHub CLI（`gh issue list --json state`）は
  `OPEN`/`CLOSED`、GitLab（`glab issue list --output json`）は `opened`/`closed` を返すため、
  そのままでは呼び出し側が両方を知らないと判定できない。
- 該当が無い場合は空配列 `[]` を返す（何も出力しない、ではない）。呼び出し側が
  `jq 'length'` で件数を判定できるようにするため。

## 2. `Github.sh`

```bash
github_normalize_issue_search_results <rawJson>   # 純粋関数（gh を呼ばない）
github_search_issues <limit> <keyword>...
```

- 検索は `gh issue list --search "<keyword>" --state all --limit <limit>
  --json number,title,state,url` を使う。
  - `gh issue list` はカレントリポジトリに限定され、PRを含まない（`gh search issues` と違い
    `--repo` 指定もPR除外も不要）。
  - `--state all` でclosedを含める（issue #68の期待する動作5）。
- 正規化は `jq` 1回。`state` は `ascii_downcase`。

## 3. `Gitlab.sh`

```bash
gitlab_normalize_issue_search_results <rawJson>   # 純粋関数（glab を呼ばない）
gitlab_search_issues <limit> <keyword>...
```

- 検索は `glab issue list --search "<keyword>" --all --per-page <limit> --output json`。
  `--all` が全state（opened/closed）を対象にする。
- 正規化で `iid` → `number`、`web_url` → `url`、`opened` → `open` へ読み替える
  （`gitlab_get_issue` が既に `iid`/`description`/`web_url` を読み替えているのと同じ方針）。

## 4. `Provider.sh`

```bash
SEARCH_ISSUES_MAX_KEYWORDS=5     # 上限（超過分は切り捨て、標準エラーへ通知）
SEARCH_ISSUES_LIMIT=20           # 1キーワードあたりの取得件数

merge_issue_search_results <normalizedJson>...   # 純粋関数
search_issues <keyword>...                        # ディスパッチャ
```

- `merge_issue_search_results` は、複数回の検索結果を `jq -s` で連結し `number` で重複排除、
  番号の降順（新しいissueが先）に並べる。**引数ではなく標準入力経由でjqへ渡す**
  （`.claude/rules/shell-script-style.md`「大きなJSONを `--argjson`/`--arg` 等のコマンドライン
  引数としてjqへ渡さない」。検索結果は件数が可変で上限を呼び出し側で保証できないため）。
  引数0個のときは `[]` を返す（`printf '%s\n' "$@"` が空行1つを出力し、jqがパースエラーに
  なるのを防ぐ）。
- `search_issues` は先頭で `require_vcs_cli search_issues || return 1` を呼び、CLI不在時は
  代替MCPツール名を提示して失敗する（他のプロバイダ依存関数と同じ形）。
- `mcp_tool_hint` に `search_issues) mcp__github__search_issues (query, owner, repo)` を追加する。

キーワードごとに1回ずつCLIを起動するため、外部プロセス起動は最大5回になる。
`.claude/rules/shell-script-style.md`「ループ内で `jq` 等の外部コマンドを呼ばない」は
1ファイルあたり数十回という規模を対象にした規約であり、ここは上限5回かつ各回が
ネットワークI/Oを伴う検索そのものなので、起動回数の削減より再現率を優先する
（AND検索1回では重複を取りこぼす）。この判断はDDRに残す。

## 5. `.claude/skills/issue-create/SKILL.md`

現在の手順2（最終確認）の**前**に、手順2として「類似・重複issueをチェックする」を挿入し、
以降を1つずつ繰り下げる（手順2→3、3→4、4→5）。新手順の内容:

1. 組み立てたタイトル・目的から検索キーワードを3〜5個選ぶ（AIが行う）。粒度の指針として
   「そのissue固有の語（機能名・ファイル名・スクリプト名・関数名・固有名詞）を選び、
   『追加』『修正』『対応』のような汎用語や、リポジトリ全体に頻出する語
   （`issue` `ワークフロー` 等）は選ばない」を明記する。
2. `source .claude/scripts/src/vcs/Provider.sh && search_issues "<kw1>" "<kw2>" ...` を実行。
   MCP経路では `mcp__github__search_issues` に読み替える。
3. 結果を「番号・状態・タイトル（＋URL）」の形で提示する。0件なら
   「類似issueは見つからなかった」と明示する。
4. 候補があった場合は `AskUserQuestion` で「新規に起票する」／「既存issueへコメントする」／
   「起票をやめる」をユーザーに選ばせる。**AIは候補提示に留め、重複と断定して勝手に
   起票を中止しない。**

「してはいけないこと」への追記:

- 類似issueが見つかったことだけを根拠に、ユーザーの判断を待たず起票を中止しない。
- 重複チェックのステップを省略して最終確認へ進まない。

各手順の見出しに内容を表す名前を併記し、issue #59 / #64 が後から手順を挿入するときに
番号ではなく名前で位置を指せるようにする。

## 6. `.claude/skills/issue-mr-flow/SKILL.md`

MCPフォールバック対応表（「2. Provider関数 → MCPツール対応表（GitHubのみ）」）に
`search_issues` の行を追加する。`mcp__github__search_issues` は自然言語のセマンティック検索で
既に `is:issue` にスコープされているため、CLI版のようなキーワードごとの繰り返し呼び出しは不要で、
1回の呼び出しに複数キーワードを平文で並べてよい旨を補足に書く。

## 7. `tests/test_vcs_provider.sh`

外部コマンド（`gh`/`glab`）を呼ばない純粋関数のみを対象にする（既存の
`gitlab_format_discussion_notes` と同じ位置づけ）。

| テスト対象 | 確認内容 |
|---|---|
| `github_normalize_issue_search_results` | `OPEN`/`CLOSED` が `open`/`closed` になる、キーが number/title/state/url になる、空配列は空配列のまま |
| `gitlab_normalize_issue_search_results` | `iid`→`number`、`web_url`→`url`、`opened`→`open`、`closed` はそのまま |
| `merge_issue_search_results` | 複数配列の連結、`number` での重複排除、番号の降順、引数0個で `[]`、空配列のみで `[]` |
| `mcp_tool_hint search_issues` | GitHubで `mcp__github__search_issues` を含む文字列を返す |

`search_issues` 本体・`github_search_issues` / `gitlab_search_issues` は CLI と
`get_provider`（`git remote`）に依存するため対象外とする（既存方針と同じ）。

キーワード抽出関数を作らないため、その単体テストも存在しない。理由はDDRへ記録する。
