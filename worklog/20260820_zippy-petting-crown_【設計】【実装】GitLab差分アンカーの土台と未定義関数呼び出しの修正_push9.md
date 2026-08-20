---
title: worklog 20260820 【設計】【実装】GitLab差分アンカーの土台と未定義関数呼び出しの修正 push9
type: log
description: issue #127のフェーズ3の試行錯誤ログ。差分アンカーの土台ページの案A/B/Cを実機計測で比較し、案Aを推奨として計画へ落とすまで。
tags: [worklog, gitlab, diff-anchor, provider]
keywords: [差分アンカー, start_sha, diffs_batch, MRバージョン, file_hash, gitlab_get_repo_url, ディスパッチャ, 再発防止]
---

# worklog: 【設計】【実装】GitLab差分アンカーの土台と未定義関数呼び出しの修正

対象: フェーズ2で検出した不具合2件の修正方針の決定と、個別作業計画の作成（2026-08-20）。
全体作業計画: `plans/zippy-petting-crown.md`
個別作業計画: `plans/【設計】【実装】GitLab差分アンカーの土台と未定義関数呼び出しの修正.md`
push回数: 9

## 試したこと

- **案Bの実現可能性の見極め**（`?diff_id=&start_sha=` で範囲を保ったままアンカーを効かせられるか）。
  1. `/merge_requests/1/versions` → `id` と `head_commit_sha` が取れることを確認（11/10/9/5）。
  2. `/-/merge_requests/1/diffs?start_sha=<head>` は200。`diffs_stream` も200で34ファイル。
  3. しかし **`diffs_stream` は `start_sha` も `diff_id` も無視していた**（パラメータ有無・
     でたらめなSHAの3通りで、いずれもバイト数が315838で完全一致）。
  4. 実際にページが使う描画経路を `data-endpoint-batch` 属性から特定し直し、
     **`diffs_batch.json` が本線**だと分かった（素の `/diffs` も同じ経路）。
  5. `diffs_batch.json` に対して同じ比較をやり直した。
- 絞り込み結果の妥当性検証として、返ってきた `file_hash` と `sha1sum` を突き合わせた。
- 異常系として、**MRバージョンのheadでないSHA**（mainのbase commit・でたらめなSHA）を
  `start_sha` に渡したときの挙動を確認した。
- 不具合2の直し方を決めるため、`Gitlab.sh` から `Provider.sh` の共有関数を呼ぶ先例があるかを
  調べた（`grep` で `to_slug` / `url_encode_path_to_reply` / `get_provider` 等の実呼び出しを判別）。

## うまくいったこと

- **`diffs_batch.json` では `start_sha` 単独で絞り込みが効く**ことを確認できた
  （パラメータ無し30件 → `start_sha` 付き1件）。**`diff_id` は不要**で、案Bでも
  `/versions` への追加API呼び出しは要らないと分かった。
- **絞り込み後のファイル集合が `build_file_links_text` の `diff_range` と一致する**設計であることと、
  `file_hash` が `sha1(パス)` そのものであることを実測で確認した
  （`docs/mmm-大きい差分.md` → `79ca8e71bf25b4152f332b840fc896571d810b36` が両者一致）。
- **案Bの弱点を先に見つけられた。** バージョンheadでない `start_sha` を渡すと、
  **HTTP 200のままファイル数0**になる（エラーにならない）。`prev_sha` は hookがローカルHEADから
  記録する値で、**pushを伴わない誤検知でも上書きされる**（issue #23で3回発生）。
  案Bはこの既知の問題を「無言で空の差分ページ」という形で表面化させる。
- 以上から**案A（`<mrUrl>/diffs#<sha1>`）を推奨**として計画に落とせた。案Aは唯一
  目視確認済みで、失うのは「アンカーの土台が今回pushの範囲に絞られる」ことだけである
  （範囲そのものは、メッセージが別に持つ「前回pushとの差分」リンクが引き続き担う）。
- **不具合2の直し方に新しい判断が不要**だと確認できた。`Gitlab.sh:31` が既に `to_slug`
  （`Provider.sh` の共有関数）を呼んでおり、`get_repo_url` を呼ぶ形は先例の範囲内。

## ダメだったこと

- **`diffs_stream` を本線だと思い込んだまま案Bを評価しかけた。** フェーズ2で
  「Compareページの `diffs_stream` から `id=` を取り出す」手法が当たったため、MR差分ページでも
  同じだろうと考えたが、実際は `diffs_batch.json` だった。**同じ結論（バイト数が完全一致）が
  3通りの入力で出た時点で「効いていない」ではなく「見ている場所が違う」を先に疑うべきだった。**
- 最初の異常系テストで、バージョンheadのSHAを手で切り詰めて継ぎ足した無効なSHAを使ってしまい、
  「効いていない」という誤った観測を1回混ぜた。**SHAは必ずAPIの出力から丸ごと取る。**
- `printf 'status=%%{http_code}\n'` と書いてしまい、`curl -w` へ渡す前にPercentが畳まれて
  リテラル出力になった（実害なし。`curl -w` の書式は `printf` の書式と混ぜない）。

## 次の一歩

- flow-id 3-2: 個別作業計画・worklog・HANDOFFをコミットしてリモートへ反映し、
  **敵対的レビュー（フェーズ3・1回目）**を実施したうえでレビュー依頼を出す。
- flow-id 3-3〜3-4: **案A/B/Cの選択**について合意を取る（設計判断）。
- flow-id 3-6: 作業1〜4を実施し、ブラウザ目視確認をユーザーへ依頼する。

---
