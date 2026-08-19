---
title: worklog 20260819 Gitlab.shの3件の不具合修正
type: log
description: issue #48（Gitlab.shの3件の不具合）の実装・テストの試行錯誤ログ
tags: [worklog, gitlab, vcs-provider]
keywords: [Gitlab.sh, システムノート, 非推奨, フォールバック, glab, 空コミット, jq, 単体テスト]
---

# worklog: 【実装】【テスト】Gitlab.shの3件の不具合修正

対象: issue #48「Gitlab.shに実機検証で判明した3件の不具合がある」（2026-08-19）。
全体作業計画: `plans/mutable-beaming-leaf.md`
個別作業計画: `plans/【実装】【テスト】Gitlab.shの3件の不具合修正.md`
push回数: 1

## 試したこと

### 前提となった実機検証（issue #45の作業として実施）

- ローカルにGitLab CE 18.5.4をDockerで構築し、`glab` 1.114.0をrootで認証させて
  `Gitlab.sh` の全13関数を実行した。`get_provider` がself-hosted URLを弾くため、
  `gitlab_*` 関数を直接呼ぶ形で迂回した。
- 全関数が動作したが、3件の不具合を確認した（詳細はissue #48）。

### 検証環境構築で踏んだ問題（今後の再現用に記録）

- **Docker Desktopが3.3.1（2021年4月）のままで起動しなかった。** 現行のStoreベースWSL
  （2.7.12、カーネル6.18）とかみ合わないのが原因。4.87.0へ更新して解決した。
- **`docker system prune` ではホストの空き容量が戻らない。** WSL2の`docker_data.vhdx`は
  動的拡張型で自動縮小しないため。中身が空であることを確認したうえでvhdxを削除し、
  Docker Desktopに再作成させて18.5GBを回収した。
- **`wsl --manage <distro> --set-sparse true` は使えなかった。** WSL 2.7.12ではデータ破損の
  可能性を理由に既定で無効化されており、`--allow-unsafe` が必要。加えて対象は
  ディストロ自身のvhdxであり、肥大化する`docker_data.vhdx`には効かないため見送った。
- **git bashから`docker exec`に絶対パスを渡すとMSYSがWindowsパスへ変換する。**
  `/etc/gitlab/initial_root_password` が `C:/Program Files/Git/etc/gitlab/...` に化けた。
  `export MSYS_NO_PATHCONV=1` で回避。`docker run -v name:/etc/gitlab` でも同じ対策が要る。
- **GitLab 17.9以降のPATはドットを含む形式**（`glpat-<38>.<2>.<9>`、計51文字）。
  トークン抽出の正規表現を `glpat-[A-Za-z0-9_-]+` にしていたため最初のドットで切り捨てられ、
  DBには有効なトークンがあるのにAPIが401を返す状態になった。`find_by_token` がNILを返すことで
  平文不一致と特定できた。
- **git credential helperのダイアログが出た。** システムのgitconfigに`manager`が設定されており、
  リポジトリ側で追加してもリストの後ろに並ぶだけだった。`git config --add credential.helper ""`
  で継承リストを打ち切ってから独自ヘルパーを追加して解決。ヘルパー本体は
  `glab config get token --host <host>` でキーリングから都度取り出す方式にし、平文ファイルは作らない。

### `glab api` のホスト解決について（自分の誤った結論を訂正した経緯）

- 当初「`glab api` はgit remoteを参照せず既定ホスト（gitlab.com）へ行く」と結論づけたが、
  **これは誤りだった**。そう見えたのは、観測時点で`localhost:8929`が未認証（unknown host）
  だったため単にフォールバックしていたから。
- 認証後に再検証したところ、リポジトリ内では`glab api version`が18.5.4を返し、リポジトリ外では
  401になった。`glab api --help`にも「Defaults to gitlab.com, or the authenticated host in the
  current Git directory.」と明記されている。
- 教訓: 未認証状態での観測を一般化しない。`Gitlab.sh`が`projects/:id`プレースホルダを
  使えているのは、この解決が効いているため。


### 実装（flow-id 3-6）

計画どおり③→②→①の順で `.claude/scripts/src/vcs/Gitlab.sh` を修正した。

- **③**: jqフィルタへ `select($n.system | not)` を追加し、純粋関数
  `gitlab_format_discussion_notes` を切り出した。`gitlab_get_mr_unresolved_comments` は
  `glab api` 呼び出し＋この関数の薄いラッパーになった。
- **②**: `glab mr note --message` → `glab api "projects/:id/merge_requests/<n>/notes" -X POST -f "body=..."`。
- **①**: コメントのみ書き換え（レビューでの合意どおりコードは変更していない）。

#### 計画外に1点追加した: jq出力のCR除去

`gitlab_format_discussion_notes` の出力を `od -c` で確認したところ、行末が `\r\n` になっていた。
Windowsネイティブjqがコマンド置換・パイプでもCRを付与するという既知の性質
（`.claude/rules/shell-script-style.md`「文字コード」）にそのまま該当する。

`| tr -d '\r'` を追加した。**この不具合は修正前から存在していた**（jqフィルタ自体は同じ）ため
issue #48の3件には含まれていないが、③でこの関数を単体テスト可能にした結果、
テストの期待値をCR込みで書くか関数側で正規化するかの選択が発生し、後者を採った。
CRの検査は `grep -c $'\r'` を使わずバイト数比較で行っている（同ルールの明示的な指示）。

#### `awk` で `\r` を置換しようとして失敗した

修正行を `awk 'NR==95{print "... tr -d '\''\r'\''"}'` で流し込もうとしたところ、awkが文字列
リテラル中の `\r` を**CR文字そのものへ展開**し、ソースコードに生のCRバイトが混入した
（`tr -d ''` に見える行が出来上がった）。クォート済みヒアドキュメントで1行を書き出し、
`sed` で前後を分割して連結する方法に切り替えて解決した。
シェルスクリプトのソースへ `\r` のようなエスケープを含む行を生成する場合、
`awk`/`sed` の置換文字列を経由させない方が安全。

### 再検証（ローカルGitLab CE 18.5.4）

`tests/test_vcs_provider.sh` は `passed=11 failures=0`（issue #13分の6件＋今回の5件）。

実機では全13関数＋新設の純粋関数を再実行した。

| 確認 | 結果 |
|---|---|
| ① 差分ゼロ（mainと同一SHA）のブランチでMR作成 | **成功**。stderrにフォールバックのメッセージが出ず、分岐に到達していないことを確認 |
| ② `gitlab_add_mr_comment` | 終了コード0・**非推奨警告なし**（修正前は警告が出ていた） |
| ③ `gitlab_get_mr_unresolved_comments` | `changed the description` が出力に現れない |
| CR混入 | 出力のバイト数が `tr -d '\r'` 前後で一致 |
| その他10関数 | 検証時と同じ出力 |

③は「除外が効いている」ことを**生データで裏取り**した。REST APIを直接叩くと
`system=true` のnoteが実在し（description更新のたびに増え、最終的に2件）、
同じペイロードを修正前のjqフィルタへ通すと `changed the description` が
`[unresolved ...]` として先頭に現れる。修正後は現れない。

合成フィクスチャだけで完了とせず実データで確認する、という
`.claude/rules/shell-script-style.md`「テスト」の指示に沿った形になった。

#### 一過性の失敗: glabがlocalhostをIPv6で解決して接続リセット

再検証中、`gitlab_set_mr_description` が
`read tcp [::1]:xxxxx->[::1]:8929: wsarecv: An existing connection was forcibly closed` で1度失敗した。

- `curl` で `127.0.0.1`（IPv4）へ3回叩くといずれも200。
- 同じ `glab` 呼び出しをリトライすると1回目で成功。
- エラーのアドレスが `[::1]` であることから、glabが `localhost` をIPv6優先で解決し、
  そちら側だけが断続的にリセットされていた。

**コードの不具合ではなく検証環境固有の事象**と判断した。ローカルGitLabを立てて検証する際は、
単発の接続エラーで不具合と判断せず、IPv4直指定での疎通と比較すること。

### 保留した点

`gitlab_new_draft_merge_request` の `echo` 文言（「baseとの差分が無いことによる既知の制約です」）は
GitHub由来の前提のまま残っている。レビューで「①はコメントの修正のみ」と合意したためコードは
触っていないが、直上のコメントとは説明が食い違う状態になる。実際にはGitLabで到達しない分岐の
メッセージのため実害は無い。

## うまくいったこと

- 全13関数を実機で通し、`get_provider` さえ迂回すればself-hosted GitLabで機能することを確認できた。
- ①について、GitHub側では本ブランチ作成時に実際に`No commits between main and feature-48-...`が
  発生してフォールバックが動作した。GitLabでは発動しない。**同一セッション内で両者の差を
  実測できた**ため、「GitHub固有の制約」と断定できる根拠が揃った。
- 修正後、差分ゼロのブランチ（`feature-2-reverify`、mainと同一SHA）でMR作成を**もう一度**
  実測し、フォールバックに到達しないことを再確認できた。
- ③を純粋関数へ切り出したことで、実際にAPIから取得したペイロードをそのまま関数へ流し込む形の
  検証ができた。合成フィクスチャ（`tests/`）と実データの両方で同じ関数を確認できている。

## ダメだったこと

- `awk` で `\r` を含む行を生成しようとして、ソースへ生のCRバイトを混入させた（上記参照）。
- 再検証中に接続リセットで1関数がNGになり、一瞬コードの不具合を疑った。IPv4での疎通と
  リトライで一過性と切り分けられたが、**単発の失敗を不具合と断定しない**という手順を
  最初から踏むべきだった。

## 次の一歩

- flow-id 3-7: `commit`スキル経由でcommitし、リモートへ反映して実装のレビューを依頼する。
- flow-id 4以降（反映）で扱う候補:
  - 設計反映: `.claude/docs/spec/issue-mr-workflow.md`「Draft PR作成失敗時の自動リトライ」節の訂正、
    changelogへの新規エントリ追記。
  - AIアセット反映: `Gitlab.sh` の `【未検証】` コメントの更新（検証済み／未検証の区別）、
    `MSYS_NO_PATHCONV=1`・GitLabのPAT形式・「awkで`\r`を生成しない」等をルール化するかの判断。

---
