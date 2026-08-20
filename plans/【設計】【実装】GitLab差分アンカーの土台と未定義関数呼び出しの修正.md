---
title: 【設計】【実装】GitLab差分アンカーの土台と未定義関数呼び出しの修正
type: plan
description: issue #127のフェーズ2で検出した不具合2件（差分アンカーの土台ページ・未定義関数呼び出し）の修正と、URL系ディスパッチャ2件の追加・再発防止までを行う個別作業計画。
tags: [gitlab, provider, diff-anchor, bugfix]
keywords: [差分アンカー, MR差分ページ, start_sha, MRバージョン, gitlab_get_repo_url, ディスパッチャ, get_mr_url, get_note_url, 未定義関数, 再発防止]
---

# 個別作業計画（フェーズ3）: GitLab差分アンカーの土台と未定義関数呼び出しの修正

- 全体作業計画: `plans/zippy-petting-crown.md`
- 調査結果（正文）: `reports/20260820_zippy-petting-crown_GitLab実機検証結果.md`
- issue: [#127](https://github.com/yuki-matsu783/MR-driven-workflow/issues/127) / PR: [#128](https://github.com/yuki-matsu783/MR-driven-workflow/pull/128)

フェーズ2の検証で検出した不具合2件を直し、あわせて受け入れ条件1を満たすためのディスパッチャ2件を
追加する。**作業1は設計判断を含むため、ここでの合意（flow-id 3-3〜3-4）を経てから着手する。**

> この計画の判断根拠になっている実機計測の結果は、正文である
> `reports/20260820_zippy-petting-crown_GitLab実機検証結果.md`
> 「追記: フェーズ3の計画時に追加で計測した結果」節にある（計画側には結果を書かない。issue #87）。

## 作業1: 差分アンカーの土台ページを変える（不具合1・設計判断あり）

### 何が起きているか

レビュー依頼メッセージの「差分」リンクが、**ブラウザで該当ファイルの位置までスクロールしない**
（GitLab）。ハッシュ値は正しく、`<mrUrl>/diffs#<sha1>` なら初回ロードから飛ぶことを目視で確認済み。
**誤っているのは土台にしているページ**で、`.claude/hooks/post-push-compact-prompt.sh:292-293` が
常にCompareページ（`/-/compare/A...B`）を渡している。

```bash
local anchor_compare_url="$diff_url" file_links_text=""   # ← file_links_text の local 宣言を兼ねる
[ -z "$since_url" ] || anchor_compare_url="$since_url"
```

`get_diff_anchor_url(compare_url, path_hash)` はプロバイダ非依存の形で土台URLを受け取るため、
**`Gitlab.sh` の中だけでは直せない**（GitHubはCompareページのままで正しく動くため、一律に
変えることもできない）。

### 案の比較

| | 案A: MR差分ページ（範囲を捨てる） | 案B: MR差分ページ + `?start_sha=` | 案C: GitLabではアンカーを出さない |
|---|---|---|---|
| 生成URL（2回目以降のpush） | `<mrUrl>/diffs#<sha1>` | `<mrUrl>/diffs?start_sha=<prev_sha>#<sha1>` | 差分リンクを出さない |
| 土台が覆う範囲 | MR全体（`base...HEAD`） | 前回push以降（`prev_sha..HEAD`） | — |
| `diff_range` との一致 | **しない** | する | — |
| **前pushで追加し今回削除したファイル** | **アンカーが着地先を失う（実測: 0件）** | 着地する（実測: 1件） | — |
| ページに載るファイル数 | MR全体ぶん（多くなる） | 今回pushぶん（少ない） | — |
| 追加API呼び出し | 不要 | **1回**（バージョンheadの検証） | 不要 |
| 新たな失敗様態 | 上記の機能後退 | 検証を省くと、`prev_sha` がバージョンheadでないとき無言で0ファイル | 差分リンクが無くなる |

### 推奨: 案B（バージョンheadの検証つき）

**土台が覆う範囲を、ファイル一覧の供給元 `diff_range` と一致させる**、という一本の原則で決める。

| pushの回 | `diff_range`（一覧の供給元） | 土台URL |
|---|---|---|
| 初回（`prev_sha` 無し） | `origin/<base>...HEAD` | `<mrUrl>/diffs` |
| 2回目以降 | `prev_sha...HEAD` | `<mrUrl>/diffs?start_sha=<prev_sha>` |

案Aを採らない理由は、**一覧に載るファイルが土台ページに存在するとは限らなくなる**ためである。
前のpushで追加したファイルを今回のpushで削除した場合（**ファイルの改名も同じ形になる**）、
そのファイルは `diff_range` には現れるがMR全体の差分には現れない。`build_file_links_text`
（`post-push-compact-prompt.sh:140-`）は削除ファイルに対してもblobリンクを空行にしたうえで
**差分アンカーは必ず出す**ため、存在しない要素を指すアンカーが生成される。これは現行のCompareページ
（`prev_sha...HEAD`）では起きないので、案Aは条件付きで**今より悪くなる**。実測済み（レポート参照）。

案Aは「ページに載るファイル数が増える」方向でもある。Compareページでアンカーが効かなかった原因が
非同期のストリーム描画である以上、ファイル数の多いMRでは同じ理由で効かなくなる懸念が残る。
案Bはページを小さく保つため、この懸念からも遠い。

**`prev_sha` の検証を伴わせる。** `start_sha` に**MRバージョンのheadでないSHA**を渡すと、
GitLabはHTTP 200のまま**0ファイル**を返す（エラーにならない）。`prev_sha` は hook がローカルの
HEADから記録する値で、**pushを伴わない誤検知でも上書きされる**（`git`+`push` の部分文字列マッチ。
issue #23で3回発生）。検証して外れていたら `<mrUrl>/diffs`（＝案Aの形）へ縮退する。

**この判断はレビューで覆してよい。** 追加のAPI呼び出しを避けたいなら案A、リンクの正しさを
保証できないなら案C。案Aを採る場合は、上記の機能後退を許容する旨を合意に含める。

### 実装の形

土台URLの決定をプロバイダへ委ねる関数を1つ足し、hookはそれを呼ぶだけにする。

```bash
# Provider.sh（新規ディスパッチャ）
# 差分アンカーの土台にするページのURLを返す。GitHubはCompareページ上でアンカーが機能するが、
# GitLabはMRの差分ページでないと機能しないため、プロバイダごとに土台が異なる（issue #127）。
get_diff_anchor_base_url() {
  local compare_url="$1" mr_url="$2" mr_number="$3" since_sha="$4"
  case "$(get_provider)" in
    github) github_get_diff_anchor_base_url "$compare_url" "$mr_url" "$mr_number" "$since_sha" ;;
    gitlab) gitlab_get_diff_anchor_base_url "$compare_url" "$mr_url" "$mr_number" "$since_sha" ;;
  esac
}
```

- `github_get_diff_anchor_base_url` は `compare_url` をそのまま返す（現行の挙動を変えない）。
- `gitlab_get_diff_anchor_base_url` は次の順で決める。
  1. `mr_url` が空なら `compare_url`（現行動作へ縮退）。空になるのは `get_vcs_access_mode` が
     `mcp` の経路で、GitLabは対象外だが、壊れたURLを出すより現行動作を保つ。
  2. `since_sha` が空なら `<mr_url>/diffs`。
  3. `since_sha` がMRバージョンのheadなら `<mr_url>/diffs?start_sha=<since_sha>`、
     でなければ `<mr_url>/diffs`。判定は
     `glab api "projects/:id/merge_requests/<n>/versions"` の `head_commit_sha` との突き合わせ。
- 呼び出し側（`post-push-compact-prompt.sh`）は**既存の `local` 宣言と `since_url` 分岐を残したまま**、
  土台URLを1行足す形にする（2行を消すと `file_links_text` の `local` 宣言まで失われ、
  未定義変数参照になる。このhookは末尾が `( main ) || true` なので**エラーが握りつぶされ、
  レビュー依頼メッセージが丸ごと出なくなるだけ**という気づきにくい壊れ方をする）。

```bash
  local anchor_compare_url="$diff_url" file_links_text="" anchor_base_url="" anchor_since_sha=""
  if [ -n "$since_url" ]; then
    anchor_compare_url="$since_url"
    anchor_since_sha="$prev_sha"
  fi
  anchor_base_url="$(get_diff_anchor_base_url \
    "$anchor_compare_url" "$mr_url" "$mr_number" "$anchor_since_sha" || true)"
  [ -n "$anchor_base_url" ] || anchor_base_url="$anchor_compare_url"
```

`mr_number` は既存の `mr`（`get_mr_for_branch` の戻り値）から `jq -r '.number'` で取る。

### 実態と食い違うようになるコメント（3箇所すべて直す）

| ファイル | 内容 |
|---|---|
| `.claude/scripts/src/vcs/Gitlab.sh`（`gitlab_get_diff_anchor_url`） | 「Compareページ内の特定ファイルの…」という説明と引数名 `compare_url` → `base_url` |
| `.claude/scripts/src/vcs/Provider.sh:557-559`（`get_diff_anchor_url`） | 「`compare_url` は `get_mr_diff_url` / `get_mr_diff_since_url` の戻り値を…渡す」という契約説明。GitLabでは由来が `get_diff_anchor_base_url` になる |
| `.claude/hooks/post-push-compact-prompt.sh:131-133`（`build_file_links_text`） | 「`compare_url` は差分範囲と対になるCompareページのURL」という説明と引数名 |

`Gitlab.sh` ヘッダの**【未検証】表記の更新はフェーズ4**で行う（ここではコード側のコメントのみ）。

### 未確認のまま残すこと

- **ファイル数の多いMR（10件以上）の後方に位置するファイル**でアンカーが効くか。案Bはページを
  小さく保つため懸念は小さいが、初回push（`<mrUrl>/diffs`）はMR全体を載せるので該当しうる。
- **折りたたまれた差分（`collapsed`）に対するアンカーの挙動。** フェーズ2では土台ページが
  そもそも飛ばなかったため切り分け不能だった。
- どちらも修正後の目視確認（検証手順5）で確かめる。

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
- **GitHub実装の形式は推測ではない。** `Github.sh` は本番経路ではコメントのURLをGraphQLの
  `comment { url }` から受け取っており文字列を組み立てないが、その実データが
  `…/pull/128#discussion_r3821657827` であることを確認済み（PR #128 の実コメント）。
  この事実をコード側のコメントに残し、**なぜ本番経路に呼び出し元が無いのか**（GitHubはAPIが
  URLを返すため補償実装が不要）も併記する。
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
   失敗として報告するテストを `.claude/scripts/test/test_vcs_provider.sh` へ追加する。
   - **空振りを潰す。** 参照件数・定義件数を出力し、**どちらかが0件なら失敗**させる
     （修正後は「未定義0件」が恒久的な期待値になるため、抽出が壊れても結果が変わらない）。
   - **落ちることを一度確かめる。** `gitlab_get_repo_url` を1箇所だけ書き戻した一時ファイルに
     対して検出ロジックを走らせ、実際に1件検出することを検証手順で確認する。
   - コメントの除去は**行頭 `#` だけでなく行末コメントも対象**にする（`foo  # gitlab_bar` を
     参照として拾わないため）。
2. **呼び出し経路を通すテスト。** 静的検出だけでは「定義はあるが引数の受け渡しが壊れている」形を
   拾えない。`gitlab_get_mr_unresolved_comments` の出力に `url` が入ることを確認するケースを足す。
   - `glab` だけでなく **`get_repo_url` もシェル関数で差し替える**。作業2の置き換えにより
     この関数は `git remote get-url origin` を起動するため、差し替えないと
     (a) `origin` の無いチェックアウトで落ち、(b) このリポジトリのoriginはGitHubなので
     `https://github.com/…/-/merge_requests/N` という実在しないURLで通ってしまう。
   - 期待値は `url` の有無ではなく、**固定のGitLab URLとの完全一致**で検証する。
3. **`get_diff_anchor_base_url` のテスト。** GitHub側は `compare_url` をそのまま返すこと、
   GitLab側は `mr_url` 空・`since_sha` 空・`since_sha` がバージョンhead・バージョンheadでない、
   の4通りを検証する（`glab` はシェル関数で差し替える）。
   **`.claude/scripts/test/` には hook を対象にしたテストが1つも無く、`build_file_links_text` を
   参照するテストも0件**であるため、既存テストの実行だけではGitHub側の後退を検出できない。

## やらないこと

- gitlab.com（SaaS）・CE 18.5.4 以外のバージョン・EEでの確認（issue #127 の期待する動作7）。
- `add_mr_thread` のディスパッチャ追加（上記）。
- hookのpush誤検知（issue #23）そのものの修正。案Bの `prev_sha` 検証は**その影響を受け止める**
  だけで、誤検知の原因には触れない。
- `Gitlab.sh` ヘッダの検証状況・spec の未決定事項の更新（**フェーズ4**の担当）。

## 検証手順

1. `bash -n` を変更した `.sh` すべてに対して実行する。
2. `bash .claude/scripts/test/test_vcs_provider.sh` が `failures=0`。
   **作業4-1の検出ロジックが実際に落ちることを、書き戻した一時ファイルで確認する。**
3. 既存テスト一式（`.claude/scripts/test/test_*.sh`）を実行する。**`main` の時点で既に失敗して
   いるものが無いかを先に切り分け**、その差分で判断する。
4. **GitHub側の出力が変わらないことを直接突き合わせる。** 変更前後の `build_file_links_text` を
   同じ入力（このリポジトリ＝GitHub remote）に対して実行し、出力が完全一致することを確かめる
   （テストを足すだけでは、変更時点で生じた劣化を検出できない）。
5. ローカルGitLabの検証用プロジェクトに対し、`Provider.sh` 経由で次を実行し、
   **結果を `reports/20260820_zippy-petting-crown_GitLab実機検証結果.md` の該当表・「未完了」節へ
   反映する**（実行しただけでは受け入れ条件1が文面上未達のまま残る）。
   - `get_mr_unresolved_comments <n>` の出力に `url` が入ること（作業2）。
   - `get_mr_url` / `get_note_url` がディスパッチャ経由で期待値を返すこと（作業3）。
   - `get_diff_anchor_base_url` + `get_diff_anchor_url` が
     `<mrUrl>/diffs?start_sha=<prev_sha>#<sha1>` を組み立てること（作業1）。
6. **ブラウザでの目視確認をユーザーへ依頼する**（作業1）。自動確認では「スクロールするか」を
   判定できないことがフェーズ2で確定しているため、これを省略しない。確認は4本。
   1. 通常の差分ファイル。
   2. 折りたたまれた差分ファイル。
   3. **前のpushで追加し、今回のpushで削除したファイル**（案Aとの分かれ目。案Bなら着地するはず）。
   4. **ファイル数の多いMRの後方に位置するファイル**（非同期描画の影響の有無）。

## フェーズ4へ送るもの

- 差分アンカーの土台をプロバイダごとに変える判断のDDR（案A/B/Cと却下理由。
  「土台が覆う範囲を `diff_range` と一致させる」という原則を含む）。
- `Gitlab.sh` ヘッダの【未検証】表記と、`.claude/docs/spec/issue-mr-workflow.md`
  「未決定事項・懸念点」の該当項目の更新。
- 受け入れ条件8（検証環境の再現手順）の `.claude/docs/spec/` 配下への移設。
