---
title: 【設計】【実装】ベースブランチ確認のAskUserQuestion化
type: plan
description: issue #15対応。startサブコマンドの新規ブランチ作成前にAskUserQuestionでベースブランチを確認できるようにする設計・実装
tags: [issue-mr-flow, base-branch, ask-user-question]
keywords: [start, new_issue_branch, new_draft_merge_request, defaultBaseBranch, AskUserQuestion, Provider.sh, SKILL.md]
---

# 【設計】【実装】ベースブランチ確認のAskUserQuestion化

全体作業計画: [plans/woolly-tickling-thimble.md](./woolly-tickling-thimble.md)

## 設計

### `Provider.sh` の `new_issue_branch`

第3引数（省略可）でベースブランチの上書きを受け取る。省略時は従来どおり
`.mrworkflow.json` の `defaultBaseBranch` を使う。

```bash
new_issue_branch() {
  local issue_number="$1" slug_source="$2"
  local config slug branch base_branch template
  config="$(get_workflow_config)"
  slug="$(to_slug "$slug_source")"
  base_branch="${3:-$(printf '%s' "$config" | jq -r '.defaultBaseBranch')}"
  template="$(printf '%s' "$config" | jq -r '.branchPrefixTemplate')"
  branch="${template//\{issue\}/$issue_number}"
  branch="${branch//\{slug\}/$slug}"

  git fetch origin "$base_branch" >/dev/null
  git switch -c "$branch" "origin/$base_branch" >/dev/null
  git push -u origin "$branch" >/dev/null

  printf '%s\n' "$branch"
}
```

`new_draft_merge_request` は既に第4引数 `[<base>]` で上書きに対応済み（変更不要）。

### `SKILL.md` の `start` サブコマンド

手順2「見つからない場合（新規作成）」の先頭に、ベースブランチ確認のステップを追加する
（既存の a./b. は b./c. へ繰り下げ）。

```
- 見つからない場合（新規作成）:
  a. **ベースブランチを確認する**: `get_workflow_config | jq -r '.defaultBaseBranch'` で
     既定のベースブランチを取得し、`AskUserQuestion` でユーザに確認する。選択肢は次の方針で組み立てる。
     - 常に含める: `<defaultBaseBranch>のまま (Recommended)`
     - `defaultBaseBranch` が `main` と異なる場合のみ追加: `main`
     - 常に含める: `別のブランチを指定する`（選択された場合、続けて通常のプロンプトで具体的な
       ブランチ名をユーザに尋ねる。`AskUserQuestion` は選択式が主眼のため、自由入力はここで行う）
     確定したブランチ名を以降 `<base_branch>` として使う。既定のまま選ばれた場合は
     `<base_branch>` を指定せず、後続関数の省略時デフォルト（`defaultBaseBranch`）に委ねてよい。
  b. issueタイトルの意味を汲んだ、ブランチslug用の英語フレーズを考える（既存内容のまま）。
  c. `new_issue_branch <n> "<a.で考えた英語フレーズ>" [<base_branch>]` でブランチを作成・
     checkout・push、続けて `new_draft_merge_request <n> "<branch>" "<issue.Title>" [<base_branch>]`
     でDraft MRを作成する（`<base_branch>` は手順aで確定した値。既定のままなら省略）。
     ※空コミット自動リトライ等の既存の注記はそのまま維持する。
```

セッション再開（既存ブランチが見つかった場合）はベースブランチ確認済みのため聞き直さない
（`sync_branch` のみ）。

### `.claude/docs/spec/issue-mr-workflow.md`（フェーズ4の設計反映で実施。ここでは実装しない）

- 関数シグネチャ表の `new_issue_branch` の説明に `[<base>]` を追記
- `start`手順の変更を反映
- 「未決定事項・懸念点」に、既定以外のベースブランチを選んだ場合 `get_branch_work_files` や
  `resume` のヒューリスティックが実際のベースとズレる可能性がある既知の制約を追記

## 実装対象ファイル

- `.claude/scripts/src/vcs/Provider.sh`（`new_issue_branch`のみ変更）
- `.claude/skills/issue-mr-flow/SKILL.md`（`start`サブコマンド手順のみ変更）

## 検証方法

- `bash -n .claude/scripts/src/vcs/Provider.sh` で構文チェック
- 目視で `SKILL.md` の該当箇所が意図通りの手順になっているか確認
