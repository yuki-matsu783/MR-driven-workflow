---
title: i0205-01. defaultブランチとの差分リンクをPR/MRのDiffviewへ出し分ける
type: ddr
description: レビュー依頼メッセージの「defaultブランチとの差分」リンクを、PR/MR URLが解決できた場合に限りCompareページからDiffview（レビューコメントを付けられるビュー）へ出し分ける設計判断を記録したDDR
tags: [github, gitlab, diff-url, provider, hook, mcp-fallback]
keywords: [get_mr_diff_url, resolve_mr_number_for_head, refs/pull, Diffview, Compare, mrUrl, 複数候補SHA, 伝播遅延]
---

# i0205-01. defaultブランチとの差分リンクをPR/MRのDiffviewへ出し分ける

## 背景

issue #205「defaultブランチとの差分リンクをPR/MRのDiffview（レビューコメントを付けられる
ビュー）へ変更する」。`post-push-compact-prompt.sh`がレビュー依頼メッセージへ含める
「defaultブランチとの差分」リンクは、DDR `i0013-01`の決定によりCompareページ
（`<repoUrl>/compare/<from>...<to>`）を組み立てていたが、issueの起票者（リポジトリ所有者）から
「Compareページはレビューコメントを付けられず、PR/MR本体のDiffview（GitHubの`/files`タブ、
GitLabの`/diffs`タブ）の方がレビューに使いやすい」という指摘を受けた。

期待する動作: PR/MR URLが取得できる場合（`gh`/`glab` CLIがある環境）は「defaultブランチとの
差分」リンクとしてGitHubなら`/files`、GitLabなら`/diffs`を使う。PR/MR URLが取得できない場合
（CLI不在のMCPフォールバック環境等）は、現行のCompareページへフォールバックする。

## 決定

### 1. `get_mr_diff_url`を4引数の純粋関数に保つ

`Provider.sh`の`get_mr_diff_url <repoUrl> <baseBranch> <headBranch> [<mrUrl>]`へ第4引数
`mrUrl`を追加する。`mrUrl`が非空ならDiffview（GitHubは`<mrUrl>/files`、GitLabは
`<mrUrl>/diffs`）を返し、空ならCompareへ縮退する。関数自体はMR/PR URLの解決を一切行わない
**純粋関数のまま**にする（却下案1参照）。

### 2. MCP経路でのPR番号解決に`git ls-remote origin 'refs/pull/*/head'`を採用

`gh`/`glab` CLI不在の環境（`get_vcs_access_mode`が`mcp`）では、そもそもMR/PR URLを
`get_mr_for_branch`経由で取得できないため、`mrUrl`が常に空になり`get_mr_diff_url`の恩恵を
受けられない。これを解消するため、`git`だけで完結する解決関数`resolve_mr_number_for_head`を
`Provider.sh`へ新設した（GitHubのみ。GitLabは`refs/merge-requests/*/head`の実機検証ができて
おらず対象外）。却下案2・3参照。

### 3. 一致判定は「一致したPR番号の種類数がちょうど1のときだけ採用」

`git ls-remote origin 'refs/pull/*/head'`は、**マージ済み・クローズ済みPRのrefも永続的に
残す**（本リポジトリでの実測: 99件のrefのうち、マージ済みPR（例: #4・#85）のrefが現存）。
HEADのSHAに一致するrefが複数のPR番号へまたがる場合、どれが正しいPRかを`git ls-remote`の
出力だけからは判断できない（stateもbaseも返さないため）。**当初案「番号が最大のものを採る」は、
フェーズ2の敵対的レビュー2回目で「案B・案Cを却下した理由（黙って誤ったURLを出す）と同じ失敗を
する」と指摘され、設計を変更した。** 一致したPR番号の種類数がちょうど1のときだけ採用し、
0件・2件以上はいずれもCompareへ縮退する（無害な失敗側へ倒す）。

### 4. 複数候補SHA（今回push・前回push）を解決関数へ渡す

フェーズ3の実push検証で、GitHubの`refs/pull/<n>/head`の更新がpushに対して**遅れる**ことを
実際に観測した（pushした直後に自動発火したhookが、当時のrefがまだ前回pushのSHAを指していた
ために解決に失敗しCompareへ縮退した。数十秒後に同じコミットへ対して単体で呼び出すと成功した）。
フェーズ2の調査時点では「本環境では観測されなかった」としていたが、これは計測をpush直後では
なくしばらく経ってから行っていたための見かけ上の結果だった。対策として、解決関数を単一SHAでは
なく**候補SHAを複数（可変長引数）受け取る形**へ変更し、呼び出し側（`post-push-compact-prompt.sh`）
は「今回pushのSHA」と「前回pushのSHA」の両方を候補として渡す。前回pushのSHAは
`git cat-file -e`で存在検証してから渡す（別ブランチの状態ファイル衝突による誤爆を避けるため。
「未検証事項・残る制約」参照）。

### 5. 差分アンカーの土台（`compare_url`）とDiffviewリンク（`diff_url`）を分離

`get_diff_anchor_base_url`（重点レビュー対象ファイルの差分アンカーの土台。issue #127参照）は、
GitHubでは実機確認済みのCompareページ上でのみアンカーが機能することが分かっている
（issue #42・#127）。PR本体の`/files`上でアンカーが機能するかは未検証のため、
`post-push-compact-prompt.sh`はこの土台へ`diff_url`（Diffviewを指しうる値）ではなく、
従来どおり`compare_url`を渡し続ける設計にした。これにより「defaultブランチとの差分」1リンクの
出し先だけがDiffviewへ変わり、重点ファイルの差分アンカーはCompareページ上に残る（「未検証事項・
残る制約」参照）。

## 理由

- **Q1: `<mrUrl>/files`・`<mrUrl>/diffs`というURL形式を、未検証のまま採用した根拠。**
  DDR `i0013-01`・`i0044-01`は、当時「UIの構造に対する推測でURLのsuffixを付け足す」実装を、
  **ブラウザでの表示確認ができない**という理由で却下し、Compare方式（PR/MR作成前から存在する
  標準機能で、issue以前から安定していると考えられる形式）へ変更した。本issueでも同じ確認不能の
  制約（この実行環境ではブラウザ目視ができない）は続いているが、`/files`・`/diffs`を採用した
  根拠は「推測」ではなく、**issue #205の起票者（リポジトリ所有者）がissue本文で明示的に
  指定したURL形式**であり、GitHub/GitLabの一般的な仕様として広く知られる形式でもある。
  それでもブラウザでの実機確認は取れていないため、**確度は「未検証」のまま残る**（specの
  「未決定事項・懸念点」へ引き継いだ）。
- **Q2: DDR `i0013-01`との関係——`superseded`にはしない。** `i0013-01`はCompare方式の採用と
  `wip/state/review-links/`によるSHA保持の両方を決めているが、本issueが変更したのは前者の
  一部（「defaultブランチとの差分」1リンクのみ）である。`get_mr_diff_since_url`（前回pushとの
  差分）・MRへのリンク自体・重点ファイルの差分アンカーの3リンクは、いずれも今回もCompare方式の
  まま変更しておらず、`i0013-01`の判断は生き続けている。したがって`i0013-01`のfrontmatterは
  変更せず（`status`は付与しない）、`i0205-01`は「部分的な変更」として独立に記録する。

## 却下した案

1. **`get_mr_diff_url`の内部でMR URL解決まで行う設計。** 却下理由: 純粋関数でなくなり
   （`git`を起動する副作用を持つ）、単体テストが困難になる。呼び出し側（hook）が解決してから
   引数で渡す設計を維持した。
2. **案B: `wip/state/`の状態ファイルにPR番号を保存する。** 却下理由: silent staleness
   （PRがクローズ・別番号へ変わった後も、状態ファイルを更新するタイミングが無ければ黙って
   古い値を返し続ける）。
3. **案C: `HANDOFF.md`のヘッダから読む。** 却下理由: `HANDOFF.md`の表記（`- PR: #206（URL）`
   の形式）に依存するため、書式が変わると壊れる。
4. **一致判定を「番号が最大のものを採る」にする案（当初案）。** 却下理由: 上記「決定」3参照。
   マージ済み・クローズ済みPRのrefが残るため、番号の大小では正しいPRを選べない。
5. **GitLabの`refs/merge-requests/<n>/head`相当の対応。** 却下理由: 実機検証ができる環境が
   無く（`glab`を使わない検証手段が無い）、実機確認済みの動作として記録できないため対象外と
   した。GitLab環境での検証が可能になった時点で別issueとして起票する（specの「未決定事項・
   懸念点」・個別反映計画「スコープ外」参照）。

## 未検証事項・残る制約

- GitHubの差分アンカー（`#diff-<sha256>`）がPR本体の`/files`上で機能するかは未検証。
  Compareページ上でのみ実機確認済み（issue #42・#127）。
- 上記の帰結として、GitHubでは重点レビュー対象ファイルの差分アンカーリンクがCompareページ上に
  残る。issueの目的は「defaultブランチとの差分」1リンクについてのみ達成される。
- `git ls-remote`のgit bash（Windows）実機でのコスト・認証プロンプト対策の実効性、
  `refs/pull/*/head`のref数増加時の所要時間、fork元PR・オフライン時の挙動、SSH remoteでの
  未起動確認は、いずれもこの実行環境（Linux）では確認できていない。
- CLI経路（`get_vcs_access_mode`が`cli`）での`resolve_mr_number_for_head`呼び出しブロックの
  素通り（`[ -z "$mr_url" ]`）は、コードを読んだ上での判断であり実機確認ではない。
- `wip/state/review-links/<branch>.txt`のブランチ名重複衝突（`safe_branch`の記号潰し）による
  `prev_sha`混入リスクは、`git cat-file -e`検証で緩和したが、別ブランチが同じ状態ファイルを
  共有すること自体は解消していない。

いずれも詳細はspec「未決定事項・懸念点」（issue #205関連の各項目）を正とする。

## 影響

| ファイル | 変更 |
|---|---|
| `.claude/scripts/src/vcs/Provider.sh` | `get_mr_diff_url`ディスパッチャへ第4引数`mrUrl`を追加。`resolve_mr_number_for_head`ディスパッチャを新設（GitHubのみ） |
| `.claude/scripts/src/vcs/Github.sh` | `github_get_mr_diff_url`が`mrUrl`非空時に`<mrUrl>/files`を返すよう変更。`github_resolve_mr_number_for_head`（複数候補SHA対応、`git ls-remote`＋一致PR番号の種類数判定）を新設 |
| `.claude/scripts/src/vcs/Gitlab.sh` | `gitlab_get_mr_diff_url`が`mrUrl`非空時に`<mrUrl>/diffs`を返すよう変更 |
| `.claude/hooks/post-push-compact-prompt.sh` | `mr_url`が空のとき`resolve_mr_number_for_head`（今回・前回pushのSHAを候補として渡す）で解決を試み、解決できれば`mr_url`へ格納。`compare_url`と`diff_url`を分離し、`get_diff_anchor_base_url`へは`compare_url`のみを渡す |
| `.claude/scripts/test/test_vcs_provider.sh` | 4引数版のアサーション、複数候補SHAでの解決、同一PR番号への複数一致、ディスパッチャ経由の経路テスト、awk失敗時の縮退テスト等を追加（`passed=225`→`249`） |
| `.claude/docs/spec/issue-mr-workflow.md` | 「提供関数」表・「未決定事項・懸念点」・「参照リンクの付与（issue #13）」節・「hookの縮退」節・「影響範囲」changelogを更新 |
| `.claude/skills/issue-mr-flow/references/mcp-fallback.md` | §2-bへ`create_pull_request`の`*`喪失の落とし穴を追加、§4の`post-push-compact-prompt.sh`行を更新 |
