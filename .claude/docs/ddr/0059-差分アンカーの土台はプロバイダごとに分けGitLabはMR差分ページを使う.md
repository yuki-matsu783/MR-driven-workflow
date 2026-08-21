---
title: 0059. 差分アンカーの土台はプロバイダごとに分けGitLabはMR差分ページを使う
type: ddr
description: レビュー依頼メッセージの差分アンカーが、GitLabではCompareページを土台にすると機能しないため、土台の決定をプロバイダへ委ね、GitLabはMR差分ページに前回push以降の絞り込みを付ける。
tags: [gitlab, diff-anchor, provider, hook]
keywords: [差分アンカー, Compareページ, MR差分ページ, start_sha, MRバージョン, diff_range, 非同期描画, rapid diffs]
---

# 0059. 差分アンカーの土台はプロバイダごとに分けGitLabはMR差分ページを使う

## 背景

issue #42 で、レビュー依頼メッセージへ「重点レビュー対象の候補ファイル」ごとの
**差分アンカーリンク**（そのファイルの差分位置を直接指すURL）を含める仕組みを入れた。
アンカーは `<土台ページのURL>#<パスのハッシュ>` という形で組み立てる。

当時の実装は、土台に**Compareページ**（`/compare/<from>...<to>`、GitLabは
`/-/compare/<from>...<to>`）を使い、プロバイダで変わるのはハッシュの算出方法
（GitHub: `#diff-<sha256>` ／ GitLab: `#<sha1>`）だけ、という設計だった。GitLab側は
当時このリポジトリにGitLab remoteが無く**未検証**のまま残っていた。

issue #127 でローカルGitLab CE 18.5.4 に対して実機検証したところ、次が判明した。

- **ハッシュの算出方法は正しかった。** `diffs_stream` 断片の `id=` 属性・
  `diff_files_metadata` の `file_hash`・`hash_paths` の値が一致した（`diff-` 接頭辞は付かない。
  入力はpercent-encode前の生パス）。
- **しかしCompareページを土台にしたアンカーは、ブラウザでスクロールしない。** GitLab 18.5 は
  差分を非同期にストリーム描画するため、ブラウザがフラグメントを解決する時点で対象要素が
  まだ存在しない。**同じハッシュを MR差分ページ（`/-/merge_requests/<iid>/diffs`）へ付けると
  初回ロードから飛ぶ**（目視で確認）。

**「同じハッシュでも、土台にするページによって効く／効かないが変わる」** という、GitHub側の
前例からは予測できなかった事実である。**自動確認（`id=` 属性との照合）だけでは
「ハッシュ値が正しい」ことしか示せず、「URLがレビュアーを目的の位置へ運ぶ」ことは別問題**
だった。

## 決定

**差分アンカーの土台にするページの決定を、プロバイダへ委ねる。** `Provider.sh` に
`get_diff_anchor_base_url <compareUrl> <mrUrl> <n> <sinceSha>` を新設し、hook
（`post-push-compact-prompt.sh`）はその戻り値を使う。

- **GitHub**: `compareUrl` をそのまま返す（**従来の挙動を1バイトも変えない**）。
- **GitLab**: MR差分ページを使う。土台が覆う範囲は、**ファイル一覧の供給元 `diff_range` と
  一致させる**。

| pushの回 | `diff_range`（一覧の供給元） | 土台URL |
|---|---|---|
| 初回（`sinceSha` 無し） | `origin/<base>...HEAD` | `<mrUrl>/diffs` |
| 2回目以降 | `prev_sha...HEAD` | `<mrUrl>/diffs?start_sha=<prev_sha>` |

`sinceSha` が**MRバージョンのheadでない**場合は `<mrUrl>/diffs` へ縮退する。判定は
`glab api projects/:id/merge_requests/<n>/versions` の `head_commit_sha` との突き合わせで行う。

`mrUrl` を取得できない経路（`get_vcs_access_mode` が `mcp` の場合。GitLabは対象外）では
`compareUrl` へ縮退する。

**目視で確認できているのは `<mrUrl>/diffs`（パラメータ無し）までである。** 2回目以降の形
`<mrUrl>/diffs?start_sha=<prev_sha>` について実測したのは**絞り込みが効くこと**（下記の
30件→1件）だけで、その状態でフラグメントがスクロールするかは未確認である。この目視確認の
状況は [issue-mr-workflow.md](../spec/issue-mr-workflow.md)「未決定事項・懸念点」が正。

## 理由

**「土台が覆う範囲を `diff_range` と一致させる」という一本の原則で決めた。** 一致していないと、
**一覧には載るのに土台ページには存在しないファイル**が生じ、アンカーが着地先を失う。

`build_file_links_text` は一覧を `diff_range` から作り、**削除されたファイルにも差分アンカーを
必ず出す**（blobリンクだけを空にする）。したがって範囲がずれると壊れる。

## 却下した案

### 案A: MR差分ページ（`<mrUrl>/diffs`）を常に土台にし、範囲を捨てる

実装が最も単純で、目視確認も済んでいた。しかし**特定条件で現行より悪くなる**ため却下した。

**前のpushで追加し、今回のpushで削除したファイル**（**ファイルの改名も差分上は削除＋追加
なので同型**）は、`diff_range` には現れるが**MR全体の差分には現れない**。実測値:

| 土台 | ページに載るファイル数 | 対象ファイルを含むか |
|---|---|---|
| 案A: `<mrUrl>/diffs`（MR全体） | 30 | **0件** |
| 採用案: `?start_sha=<前pushのhead>` | 1 | 1件 |

現行のCompareページ（`prev_sha...HEAD`）ではこの形にならないため、案Aは**機能後退**になる。

案Aはまた、土台に載るファイル数が増える方向でもある。Compareページでアンカーが効かなかった
原因が非同期描画である以上、ファイル数の多いMRでは同じ理由で効かなくなる懸念が残る。

### 案C: GitLabでは差分アンカーを出さず、blobリンクのみにする

issue #42 の受け入れ条件が挙げていた退避案。**アンカーが機能することを確認できた以上、
情報量を落とす理由が無い**ため却下した。

### 案B': `?diff_id=` を併用する

GitLabのUIが生成するURLはこの形だが、**`start_sha` 単独で絞り込みが効く**ことを実機で確認した
（パラメータ無し30件 → `start_sha` 付き1件）。`diff_id` を得るには `/versions` への
API呼び出しが要るため、**単独で足りるなら付けない**方が呼び出しが減る。

**この原則は、2つの範囲が同じ集合を指すことを前提にしている。** 一覧は
`git diff <prev_sha>...HEAD`（ローカルのmerge-base起点）で作るのに対し、土台はGitLabの
**MRバージョン間比較**（`?start_sha=<前バージョンのhead>`）である。**pushの間にベースブランチを
取り込んだ場合、両バージョンの `base_commit_sha` が変わるため、この2つが一致するかは未確認**
である（実機で確認したのは、ベース取り込みを挟まない通常のpushの形のみ）。ずれるようであれば、
案Aで問題にしたのと同じ「一覧に載るのに土台に無いファイル」が再び生じる。確かめるには、
ベースを進めてマージしたうえで2回目のpushを行い、一覧のファイル集合と `diffs_batch.json` が
返す集合を突き合わせればよい。

## 残した妥協

**`sinceSha` がMRバージョンのheadでないときの縮退は、上の原則を満たせない。** 縮退先は却下した
案Aと同じ形であり、呼び出し元の `diff_range` は `prev_sha...HEAD` のままなので、そのpushに
改名・削除されたファイルが含まれていればアンカーは着地先を失う。

それでも縮退させるのは、**不正な `start_sha` に対してGitLabがエラーを返さず、HTTP 200のまま
0ファイル**を返すためである（無言で空の差分ページになる）。空ページよりはMR全体の差分の方が
まだ役に立つ。

**根治には issue #23（hookのpush誤検知）を直す必要がある。** `prev_sha` は hook がローカルの
HEADから記録する値で、**pushを伴わない誤検知でも上書きされる**（`git` と `push` の部分文字列
マッチ。issue #23 で3回発生）。この場合 `prev_sha` はMRのバージョンとして存在しないSHAになる。

## DDR 0037 との関係

[DDR 0037](0037-リポジトリURLはgh_glabではなくgit-remoteから導出する.md) は「pushのたびに走る
本hookから外部CLIの起動とAPI往復が1回ずつ無くなっている」ことを成果として記録している。
**本決定は、GitLabかつ2回目以降のpushでAPI往復を1回足し戻している**（`/versions` の取得）。

それでも足す判断をしたのは、上記のとおり**この検証を省くと無言で空の差分ページを出しうる**
ためである。GitHub側の呼び出し回数は変わらない。

## 影響

- `.claude/scripts/src/vcs/Provider.sh`: `get_diff_anchor_base_url` を新設。
  `get_diff_anchor_url` の第1引数名を `compare_url` → `base_url` へ（意味が変わったため）。
- `.claude/scripts/src/vcs/Github.sh`: `github_get_diff_anchor_base_url` を新設（恒等）。
- `.claude/scripts/src/vcs/Gitlab.sh`: `gitlab_get_diff_anchor_base_url` /
  `gitlab_mr_has_version_head` を新設。
- `.claude/hooks/post-push-compact-prompt.sh`: 土台URLの決定を上記へ委譲し、`mr_number` を取得。
- **GitHub側の出力が変わらないことは、変更前後の `build_file_links_text` を同一入力で実行して
  突き合わせた**（old/new とも2,526バイト・15行、差分なし）。テストの追加だけでは、変更時点で
  生じた劣化を検出できないため。
