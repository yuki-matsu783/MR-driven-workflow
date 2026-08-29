---
title: worklog: 【実装】【テスト】Diffviewリンクの出し分けとMCP経路でのPR URL解決
type: log
description: issue #205 フェーズ3の作業ログ。個別作業計画の作成から実装・テスト追加まで
tags: [worklog, implementation, issue-mr-flow]
keywords: [get_mr_diff_url, git ls-remote, compare_url, diff_url, ディスパッチャ, 経路テスト, 空振り]
---

# worklog: 【実装】【テスト】Diffviewリンクの出し分けとMCP経路でのPR URL解決

対象: issue #205「defaultブランチとの差分リンクをPR/MRのDiffviewへ変更する」（2026-08-24）。
全体作業計画: `wip/plans/diffview-link-switchover.md`
個別作業計画: `wip/plans/【実装】【テスト】Diffviewリンクの出し分けとMCP経路でのPR URL解決.md`
push回数: 5〜7

## 試したこと

- flow-id 3-1: 個別作業計画を作成した。**mdを先に書き、HTMLを後から写した**
  （フェーズ2の敵対的レビュー1回目で「HTMLにしか無い記述がある」と指摘された順序の逆をやる）。
- 計画HTMLに対して `wip/plans/REVIEW-POINTS.md` の検査を全件実行した。
  - 自己完結（外部を読みに行く記述）: 0件
  - テンプレートの埋め忘れ（`<!-- ここに書く`）: 0件
  - 重複ID・リンク切れ: いずれも無し
  - 表の `td`/`th` の列数: 全表で揃っている
  - md/HTMLの見出し突き合わせ: **完全一致**（片側にしか無い節が0）
- **HTML生成時に、コードブロック中の `*` を `[*]` へ置換しかけて戻した。** MCPツールの本文で
  アスタリスクが失われる事象（フェーズ2で観測）を意識しすぎたためだが、**この置換が要るのは
  MCPツールへ渡す本文だけ**で、Git管理下のファイルには不要である。置換したままだと
  md（素の `*`）とHTML（`[*]`）が食い違い、まさに直したばかりの同期漏れを再発させていた。

- flow-id 3-2 の直後に**敵対的レビュー（フェーズ3・1回目）を実行**した。10件検出（major 7 / minor 3）、
  全件をPR #206 へインライン投稿し、全件へ対応・返信した。
- **10件のうち3件は、計画のまま実装すると壊れるもの**だった。
  1. 「置き換え前」の `local anchor_compare_url="$diff_url"` が**実在しない行**だった
     （実物は `local anchor_compare_url="$diff_url" file_links_text=""`）。そのまま置き換えると
     `file_links_text` の `local` 宣言が消える。
  2. `http.lowSpeedLimit` / `http.lowSpeedTime` は**HTTPトランスポートにしか効かない**。
     SSH remoteではハング対策が丸ごと無効で、`GIT_TERMINAL_PROMPT=0` 等も ssh のプロンプトを止めない。
  3. `wc -l` の出力を `[ "$count" = "1" ]` と**文字列比較**していた。BSD系 `wc` は先頭に空白を付けるため、
     **常に不一致＝常に空を返す＝機能が一切入らない**のに、テストは緑のまま通る。

## うまくいったこと

- 計画へ**巻き添えの確認**を明示的に書けた。実装のスケッチをそのまま書くと
  `current_sha: unbound variable` になることに、コードを読んだ段階で気づけた
  （`current_sha` の算出が挿入位置より後ろにある）。計画に「置き換え前後の形を両方書く」という
  `wip/plans/REVIEW-POINTS.md` の観点が効いた。
- **`get_mr_diff_since_url` を触らない**という調査結果の判断のおかげで、変更範囲が
  4ファイル（Github.sh / Gitlab.sh / Provider.sh / post-push-compact-prompt.sh）＋テスト1ファイルに収まった。

- **敵対的レビューの指摘を追ううちに、レビューでは挙がっていない制約を自分で1つ見つけた。**
  `test_vcs_provider.sh` は**220行目付近で `get_provider` をファイル全域に効く形で上書き**しており、
  コメント自身が「`get_provider` に依存するテストをこれより後ろへ追加しないこと」と警告していた。
  今回追加するディスパッチャ経路テストはまさにこれに該当する。計画へ挿入位置の制約として追記した。
  **指摘そのものより、指摘が指した場所を読みに行ったことの副産物のほうが大きかった。**
- **検証3の骨子を実際に実行して動作を確認した**（一時ツリーへコピーして `source` し、
  ディスパッチャの戻り値を得るところまで）。計画に書いたまま動かない手順を残さずに済んだ。

## ダメだったこと

- 上記の `[*]` 置換（自分で入れて自分で戻した）。
- **検証3の初稿が `VCS_DIR="$broken_dir" bash test_vcs_provider.sh` という、動かない形だった。**
  `test_vcs_provider.sh` は source 元を `$repo_root` で決め打ちしており、環境変数で差し替えられない。
  レビューの「1344-1352行に手本がある」という指摘に従って実物を読んだ際、**手本が
  `vcs_undefined_names "$dir"` という引数でディレクトリを取る関数を使っているから成立していた**ことに
  気づいた。**手本の形だけを真似て、成立している理由を確かめていなかった。**

- flow-id 3-6: **作業1〜4を実装し、7つの完了条件のうち6つを達成した**（残り1つは次の実pushで確認）。
  結果は `wip/reports/20260824_diffview-link-switchover_実装結果.md`（+ `.html`）。
  - `test_vcs_provider.sh` が `passed=225` → **`passed=242`**（+17件）。単体テスト21ファイル全件 `failures=0`。
  - hookをダミーペイロードで直接実行し、`- defaultブランチとの差分:` が
    `https://github.com/yuki-matsu783/MR-driven-workflow/pull/206/files` になることを確認した。
  - **差分アンカー付きリンク10本がすべてCompareのまま**（10/10で一致）＝後退なし。
- **計画で「pushしてから目視」と書いた検証4が、その場で何度でも実行できると分かった。**
  hookはstdinからJSONを受ける単一プロセスなので、状態ファイルを退避すれば繰り返し流せる。
  「切り分けが1pushにつき1回」という制約は**最初から存在しなかった**（思い込みだった）。

- **flow-id 3-7 の実push（コミット `22a23b7`）で、伝播遅延が実際に発生した。** pushした直後に
  自動発火したPostToolUse hookは、`refs/pull/206/head` がまだ前回pushのSHAを指していたために
  解決に失敗し、Compareへ縮退した。数十秒後に同じコミットへ対して解決関数を単体で直接呼び出すと
  成功した。**フェーズ2の調査結果が「本環境では観測されなかった」としていたのは誤りで、計測を
  push直後ではなくしばらく経ってから行っていたための見かけ上の結果だった。**
  調査結果・実装結果の両レポート（mdとhtml）を訂正した。
- **対策として `github_resolve_mr_number_for_head` / `resolve_mr_number_for_head` を、
  単一SHAではなく複数の候補SHA（今回push・前回push）を受け取る形へ変更した。** 判定基準も
  「一致したref数」から「一致したPR番号の種類数」へ変えた（複数の候補が同じPR番号に一致するのは
  正常であるため）。3ファイル（Github.sh / Provider.sh / post-push-compact-prompt.sh）を修正。
- `test_vcs_provider.sh` へ5件追加（複数候補での解決・同一PR番号への複数一致・前回SHAが空でも
  解決・ディスパッチャ経由の複数候補受け渡し・GitLab経路が変わらないこと）。
  `passed=242` → **`passed=247`**。単体テスト21ファイル全件 `failures=0`。
- **検証3と同じ手順で空振りでないことを確認した。** `resolve_mr_number_for_head` の `"$@"` 渡しを
  1引数だけへ落とす改変を一時ツリーで加えたところ、3件（`get_mr_diff_url` 系2件・ディスパッチャの
  複数候補受け渡し1件）が実際に落ちた（`passed=244 failures=3`）。

## 次の一歩

- 本push（伝播遅延対策）をcommit・push（flow-id 3-7の追加分）する。
- flow-id 3-7 の直後に敵対的レビュー（フェーズ3・2回目）を実行する。
- flow-id 4-1: 個別反映計画（spec/DDR/AIアセットへの反映）を作成する。

---
