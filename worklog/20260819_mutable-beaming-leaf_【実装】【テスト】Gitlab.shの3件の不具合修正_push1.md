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

## うまくいったこと

- 全13関数を実機で通し、`get_provider` さえ迂回すればself-hosted GitLabで機能することを確認できた。
- ①について、GitHub側では本ブランチ作成時に実際に`No commits between main and feature-48-...`が
  発生してフォールバックが動作した。GitLabでは発動しない。**同一セッション内で両者の差を
  実測できた**ため、「GitHub固有の制約」と断定できる根拠が揃った。

## ダメだったこと

- （実装着手前のため、現時点では特になし。）

## 次の一歩

- 個別作業計画に沿って③→②→①の順に`Gitlab.sh`を修正する。
- `tests/test_vcs_provider.sh` に`gitlab_format_discussion_notes`のテストを追加する。
- ローカルGitLabで全13関数を再実行し退行が無いことを確認する。

---
