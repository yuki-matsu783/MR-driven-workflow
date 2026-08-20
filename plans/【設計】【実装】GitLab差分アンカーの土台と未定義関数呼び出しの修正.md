---
title: 【設計】【実装】GitLab差分アンカーの土台と未定義関数呼び出しの修正
type: plan
description: issue #127のフェーズ2で検出した不具合2件（差分アンカーの土台ページ・未定義関数呼び出し）の修正と、URL系ディスパッチャ2件の追加・再発防止までを行う個別作業計画。
tags: [gitlab, provider, diff-anchor, bugfix]
keywords: [差分アンカー, Compareページ, MR差分ページ, start_sha, gitlab_get_repo_url, ディスパッチャ, get_mr_url, get_note_url, 未定義関数, 再発防止]
---

# 個別作業計画（フェーズ3）: GitLab差分アンカーの土台と未定義関数呼び出しの修正

- 全体作業計画: `plans/zippy-petting-crown.md`
- 調査結果（正文）: `reports/20260820_zippy-petting-crown_GitLab実機検証結果.md`
- issue: [#127](https://github.com/yuki-matsu783/MR-driven-workflow/issues/127) / PR: [#128](https://github.com/yuki-matsu783/MR-driven-workflow/pull/128)

フェーズ2の検証で検出した不具合2件を直し、あわせて受け入れ条件1を満たすためのディスパッチャ2件を
追加する。**作業1は設計判断を含むため、ここでの合意（flow-id 3-3〜3-4）を経てから着手する。**

## 作業1: 差分アンカーの土台ページを変える（不具合1・設計判断あり）

### 何が起きているか

レビュー依頼メッセージの「差分」リンクが、**ブラウザで該当ファイルの位置までスクロールしない**
（GitLab）。ハッシュ値は正しく、`<mrUrl>/diffs#<sha1>` なら初回ロードから飛ぶことを目視で確認済み。
**誤っているのは土台にしているページ**で、`.claude/hooks/post-push-compact-prompt.sh:292-293` が
常にCompareページ（`/-/compare/A...B`）を渡している。

```bash
local anchor_compare_url="$diff_url"                    # get_mr_diff_url → /-/compare/...
[ -z "$since_url" ] || anchor_compare_url="$since_url"  # get_mr_diff_since_url → /-/compare/...
```

`get_diff_anchor_url(compare_url, path_hash)` はプロバイダ非依存の形で土台URLを受け取るため、
**`Gitlab.sh` の中だけでは直せない**（GitHubはCompareページのままで正しく動くため、一律に
変えることもできない）。

### 追加で分かったこと（この計画を書くにあたり実機で計測）

| 確認したこと | 結果 |
|---|---|
| `<mrUrl>/diffs?start_sha=<SHA>` の絞り込み | **効く**。`diff_id` の併用は不要 |
| 絞り込み後のファイル集合 | 「そのSHA以降に変わったファイル」のみ。`build_file_links_text` が使う `diff_range` と一致する |
| 絞り込み後の `file_hash` | `sha1(パス)` と一致（`docs/mmm-大きい差分.md` → `79ca8e71…` を実測） |
| `start_sha` に**MRバージョンのheadでないSHA**を渡した場合 | **HTTP 200のまま0ファイル**。エラーにならず、無言で空の差分ページになる |
| `diff_id` を併用した場合 | 挙動は同じ。取得には `/merge_requests/:iid/versions` への追加API呼び出しが要る |

最後の行が案Bの弱点になる。`prev_sha` は hook がローカルのHEADから記録する値であり、
**pushを伴わない誤検知でも上書きされる**（`git`+`push` の部分文字列マッチで発火する既知の問題。
issue #23で実際に3回発生）。この場合 `prev_sha` はMRのバージョンとして存在しないSHAになり、
案Bでは空の差分ページへ誘導してしまう。現行のCompareページはgitレベルの比較なのでこの影響を受けない。

### 案の比較

| | 案A: MR差分ページ（範囲を捨てる） | 案B: MR差分ページ + `?start_sha=` | 案C: GitLabではアンカーを出さない |
|---|---|---|---|
| 生成URL | `<mrUrl>/diffs#<sha1>` | `<mrUrl>/diffs?start_sha=<prev_sha>#<sha1>` | 差分リンク自体を出さない |
| スクロール | **目視確認済み（初回から飛ぶ）** | 未確認 | — |
| 今回pushの範囲 | 保てない（MR全体の差分になる） | 保てる | — |
| 追加API呼び出し | 不要 | 不要 | — |
| 新たな失敗様態 | 無し | **`prev_sha` がバージョンhead でないと無言で0ファイル** | 無し |
| 変更量 | 小 | 小〜中（異常系の判定が要る） | 小 |

### 推奨: 案A

理由は3つ。

1. **唯一、実機で動くことを確認できている形である。** 案Bはページ自体は200を返すが、
   アンカーが実際にスクロールするかは未確認で、確認するにはまた目視依頼の往復が要る。
2. **案Bは既知の不具合の上に新しい失敗様態を積む。** hookの誤検知で `prev_sha` が汚れる問題は
   未解決のまま残っており（issue #23）、案Bはそれを「空の差分ページ」という形で表面化させる。
   しかも200が返るため、壊れていることに気づけない。
3. **失うものが小さい。** レビュー依頼メッセージは「前回pushとの差分」へのリンクを
   **別途そのまま持っている**（`build_links_text` の `since_url`）。案Aで変わるのは
   ファイルごとのアンカーが指す土台だけで、リンク先のファイルは今回pushで変わったものに限られる
   （一覧の供給元が `diff_range` のため）。範囲の情報は失われず、置き場所が変わるだけである。

**この判断はレビューで覆してよい。** 範囲の保持を優先するなら案Bを採る。その場合は
「`prev_sha` がMRバージョンのheadか」を投稿前に確認し、外れていたら案Aへ縮退する分岐を足す
（`/merge_requests/:iid/versions` への1回のAPI呼び出しが増える）。

### 実装の形（案Aを採る場合）

土台URLの決定をプロバイダへ委ねる関数を1つ足し、hookはそれを呼ぶだけにする。

```bash
# Provider.sh（新規ディスパッチャ）
# 差分アンカーの土台にするページのURLを返す。GitHubはCompareページ上でアンカーが機能するが、
# GitLabはMRの差分ページでないと機能しないため、プロバイダごとに土台が異なる（issue #127）。
get_diff_anchor_base_url() {
  local compare_url="$1" mr_url="$2"
  case "$(get_provider)" in
    github) github_get_diff_anchor_base_url "$compare_url" "$mr_url" ;;
    gitlab) gitlab_get_diff_anchor_base_url "$compare_url" "$mr_url" ;;
  esac
}
```

- `github_get_diff_anchor_base_url` は `compare_url` をそのまま返す（現行の挙動を1バイトも変えない）。
- `gitlab_get_diff_anchor_base_url` は `mr_url` が非空なら `<mr_url>/diffs`、
  **空なら `compare_url` へ縮退する**。`mr_url` が空になるのは
  `get_vcs_access_mode` が `mcp` の経路（`Provider.sh` はMRを引かない）で、GitLabは対象外だが、
  空文字を土台にして壊れたURLを出すよりは現行動作を保つほうがよい。
- 呼び出し側（`post-push-compact-prompt.sh`）は `anchor_compare_url` の2行を
  `get_diff_anchor_base_url "$anchor_compare_url" "$mr_url"` の1行へ置き換える。
- あわせて `gitlab_get_diff_anchor_url` のコメント「Compareページ内の特定ファイルの…」と
  引数名 `compare_url` を実態に合わせて直す（`base_url`）。`Gitlab.sh` ヘッダの
  **【未検証】表記の更新はフェーズ4**で行う（コード側のコメントのみ今回直す）。

### 未確認のまま残すこと

- **折りたたまれた差分（`collapsed`）に対するアンカーの挙動。** フェーズ2では土台ページが
  そもそも飛ばなかったため切り分け不能だった。案Aの修正後、目視確認のついでに1件確かめる。

## 作業2: 未定義関数の呼び出しを直す（不具合2）

`.claude/scripts/src/vcs/Gitlab.sh` の162行目・180行目が、**定義の無い `gitlab_get_repo_url`**
を呼んでいる。`2>/dev/null` で `command not found` が握りつぶされ、条件が常に偽になるため、
`get_mr_unresolved_comments` / `add_mr_thread_reply` が**無言でURL無しへ縮退**している。

- `gitlab_get_repo_url` → **`get_repo_url`**（`Provider.sh:521`）へ置き換える。
  `get_repo_url` は `git remote` から導出するプロバイダ非依存の関数で、issue #44 が
  `gitlab_get_repo_url` を削除して一本化した先そのものである。
- **provider実装から `Provider.sh` の共有関数を呼ぶ形には既に先例がある**（`Gitlab.sh:31` の
  `to_slug`）ため、依存の向きについて新しい判断は要らない。
- `2>/dev/null` と `if` による握りつぶしは**残す**。`get_repo_url` は `origin` が無ければ失敗し、
  そのときコメント取得本体まで巻き添えにしたくないという元の意図は今も正しい。

## 作業3: `get_mr_url` / `get_note_url` のディスパッチャを追加する

flow-id 2-4 でユーザーが決定した対応。**受け入れ条件1（`Provider.sh` 経由での実行）が、
この2件について現在未達**であり、それを解消する。

- `Provider.sh` に `get_mr_url <repo_url> <mr_number>` / `get_note_url <mr_url> <note_id>` を追加。
- `Github.sh` に対応する実装を追加する。
  - `github_get_mr_url` → `<repo_url>/pull/<n>`
  - `github_get_note_url` → `<mr_url>#discussion_r<id>`
- **`Gitlab.sh` 内部の呼び出し（163・181-182行）はディスパッチャへ変えない。** `gitlab_*` の中から
  `gitlab_*` を直接呼ぶのが現行の形であり、わざわざ判定を経由させる理由が無い。
- 追加後、**この2件をディスパッチャ経由で実行し直して**検証を完了させる（実機・ローカルGitLab）。
- `add_mr_thread` はディスパッチャを追加しない（GitHubに対応物が無く、揃えると振る舞い差が残る。
  flow-id 2-4 の決定）。

## 作業4: 再発防止

不具合2は「定義が消えた側と呼び出しを足した側が並行ブランチで、gitがコンフリクトと見なさなかった」
ために混入した。同じ形は再発しうるため、機械的に検出できるようにする。

1. **未定義の `github_*` / `gitlab_*` 呼び出しの静的検出。** `Provider.sh` `Github.sh` `Gitlab.sh`
   に現れる `github_*` / `gitlab_*` の識別子を集め、**いずれのファイルにも定義が無いもの**を
   失敗として報告するテストを `.claude/scripts/test/test_vcs_provider.sh` へ追加する
   （コメント中の言及を拾わないよう、行頭の `#` を除いてから走査する）。今回の
   `gitlab_get_repo_url` はこれで検出できる。
2. **呼び出し経路を通すテスト。** 静的検出だけでは「定義はあるが引数の受け渡しが壊れている」形を
   拾えない。`glab` をシェル関数で差し替えて固定JSONを返させ、`gitlab_get_mr_unresolved_comments`
   の出力に **`url` が入っていること**を確認するケースを足す（外部プロセスもネットワークも使わない）。
   関数名で定義したシェル関数は同名の実行ファイルより優先されるため、実装側に手を入れずに検証できる。

## やらないこと

- gitlab.com（SaaS）・CE 18.5.4 以外のバージョン・EEでの確認（issue #127 の期待する動作7）。
- `add_mr_thread` のディスパッチャ追加（上記）。
- hookのpush誤検知（issue #23）そのものの修正。**案Aを採れば今回の不具合とは切り離せる**ため、
  本issueの範囲へ引き込まない。
- `Gitlab.sh` ヘッダの検証状況・spec の未決定事項の更新（**フェーズ4**の担当）。

## 検証手順

1. `bash -n` を変更した `.sh` すべてに対して実行する。
2. `bash .claude/scripts/test/test_vcs_provider.sh` が `failures=0`。
3. 既存テスト一式（`.claude/scripts/test/test_*.sh`）を実行し、**mainの時点で既に失敗している
   ものが無いか**を切り分けたうえで比較する。
4. ローカルGitLabの検証用プロジェクトに対し、`Provider.sh` 経由で次を実行する。
   - `get_mr_unresolved_comments <n>` の出力に `url` が入ること（作業2の確認）。
   - `get_mr_url` / `get_note_url` がディスパッチャ経由で期待値を返すこと（作業3の確認）。
   - `get_diff_anchor_base_url` + `get_diff_anchor_url` で組み立てたURLが
     `<mrUrl>/diffs#<sha1>` になること（作業1の確認）。
5. **ブラウザでの目視確認をユーザーへ依頼する**（作業1）。自動確認では
   「スクロールするか」を判定できないことがフェーズ2で確定しているため、これを省略しない。
   確認は2本: (a) 通常の差分ファイル、(b) 折りたたまれた差分ファイル。

## フェーズ4へ送るもの

- 差分アンカーの土台をプロバイダごとに変える判断のDDR（案A/B/Cと却下理由）。
- `Gitlab.sh` ヘッダの【未検証】表記と、`.claude/docs/spec/issue-mr-workflow.md`
  「未決定事項・懸念点」の該当項目の更新。
- 受け入れ条件8（検証環境の再現手順）の `.claude/docs/spec/` 配下への移設。
