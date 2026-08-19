# 【実装】【テスト】Gitlab.shの3件の不具合修正

対象issue: [#48](https://github.com/yuki-matsu783/MR-driven-workflow/issues/48)
全体作業計画: `plans/mutable-beaming-leaf.md`

3件とも `.claude/scripts/src/vcs/Gitlab.sh` 内の小さな修正であり、合意の単位を分ける必要が
無いため1ファイルにまとめる（`.claude/skills/issue-mr-flow/SKILL.md`「種別を複数併記する場合」）。

## ① 空コミットフォールバックのコメント修正

`gitlab_new_draft_merge_request` の内部コメント（現状 L47-51）を書き換える。**コードは変更しない。**

書き換えの要点:

- 「baseとの差分が無いブランチでは `glab mr create` が失敗する既知の制約」という**断定をやめる**。
- GitLab CE 18.5.4 での実測（mainと同一SHAのブランチでも `glab mr create` が成功し、
  フォールバックは発動しなかった）を明記する。
- この制約は `gh pr create` 側で実在することを併記する（issue #48対応時、本ブランチ作成で
  `No commits between main and feature-48-...` が実際に発生）。
- したがってGitLab側のこの分岐は「GitHub由来の制約に対する安全網であり、通常は到達しない」
  位置づけであること、検証済みバージョンが18.5.4のみであることを残す。

参照先は `.claude/docs/ddr/0005-DraftPR作成失敗時は空コミットで自動リトライする.md` のまま変えない
（DDRはGitHubについて有効なため）。

## ② `glab mr note --message` を `glab api` へ置き換え

```bash
# 変更前
gitlab_add_mr_comment() {
  local mr_number="$1" body_file="$2"
  local body
  body="$(cat "$body_file")"
  glab mr note "$mr_number" --message "$body" >/dev/null
}

# 変更後
gitlab_add_mr_comment() {
  local mr_number="$1" body_file="$2"
  local body
  body="$(cat "$body_file")"
  glab api "projects/:id/merge_requests/${mr_number}/notes" \
    -X POST -f "body=${body}" >/dev/null
}
```

- 直下の `gitlab_add_mr_thread_reply` と同じ `glab api` 方式になり実装が揃う。
- `glab mr note create` は EXPERIMENTAL 扱いのため採用しない（非推奨を実験的APIへ置き換えても
  寿命が延びない）。

## ③ システムノートの除外＋純粋関数の切り出し

jqフィルタを `gitlab_format_discussion_notes` として切り出し、`select($n.system | not)` を追加する。

```bash
# discussions APIのレスポンス(JSON文字列)を、表示用の文字列へ整形する純粋関数。
# `glab`呼び出しを伴わないため tests/test_vcs_provider.sh で単体テストできる。
gitlab_format_discussion_notes() {
  local discussions="$1" include_resolved="${2:-false}"
  printf '%s' "$discussions" | jq -r --argjson includeResolved "$include_resolved" '
    [
      .[] as $d
      | $d.notes[]
      | . as $n
      | select($n.system | not)
      | ($n.resolvable and $n.resolved) as $isResolved
      | select(($isResolved | not) or $includeResolved)
      | "[" + (if $isResolved then "resolved" else "unresolved" end)
        + " threadId=" + ($d.id | tostring) + "] " + $n.author.username + ": " + $n.body
    ] | join("\n\n")
  '
}

gitlab_get_mr_unresolved_comments() {
  local mr_number="$1" include_resolved="${2:-false}"
  local discussions
  discussions="$(glab api "projects/:id/merge_requests/${mr_number}/discussions")"
  gitlab_format_discussion_notes "$discussions" "$include_resolved"
}
```

- `select($n.system | not)` を `resolvable`/`resolved` の判定より**前**に置く
  （システムノートは `resolvable=false` のため、既存の「resolvableでないnoteは常に含める」
  意図と衝突する。先に落とすのが正しい順序）。
- 「個人メモ（individual_note）等 resolvable でないnoteは常に含める」という既存コメントは
  残しつつ、「ただしGitLabが自動生成するシステムノート（`system: true`）は除外する」を追記する。

## テスト（`tests/test_vcs_provider.sh` へ追記）

既存の `assert_eq` / `passed=N failures=N` 規約に従う。フィクスチャは実機で観測した形状を使う。

```
system=true   resolvable=false  resolved=null   body=changed the description
system=false  resolvable=true   resolved=false  body=検証用のMRコメントです。
system=false  resolvable=true   resolved=true   body=解決済みコメント
```

追加するケース:

1. `gitlab_format_discussion_notes <fixture> false` の出力に `changed the description` が
   **含まれない**
2. 同上の出力に未解決コメントが `[unresolved threadId=...] root: ...` 形式で含まれる
3. `gitlab_format_discussion_notes <fixture> true` では解決済みコメントも
   `[resolved threadId=...]` 形式で含まれる
4. 3.でもシステムノートは**含まれない**（`include_resolved=true` でも除外され続けること）

テストヘッダのコメント（対象関数の列挙、L2-8）にも `gitlab_format_discussion_notes` を追記する。

## 実施順序

1. `Gitlab.sh` の③（関数分割＋フィルタ修正）→ ②（`glab api`置換）→ ①（コメント修正）
2. `bash -n .claude/scripts/src/vcs/Gitlab.sh`
3. `tests/test_vcs_provider.sh` へケース追加 → `bash tests/test_vcs_provider.sh`
4. ローカルGitLabで全13関数を再実行（詳細は全体作業計画「検証方法」）

## 完了条件

- `bash tests/test_vcs_provider.sh` が `failures=0`
- ローカルGitLabでの再実行で、②の非推奨警告が消え、③の出力に `changed the description` が無い
- ①③以外の関数の出力が、issue #48起票時の検証結果と一致する
