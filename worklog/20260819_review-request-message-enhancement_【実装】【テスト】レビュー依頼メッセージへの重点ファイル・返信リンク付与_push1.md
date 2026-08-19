---
title: worklog 20260819 レビュー依頼メッセージへの重点ファイル・返信リンク付与 push1
type: log
description: issue #42の実装・テストで試したことと、GitHubの差分アンカーの算出方法を実機確認した記録
tags: [worklog, issue-mr-workflow, vcs-provider, hooks]
keywords: [差分アンカー, sha256, file-list, include-fragment, blobリンク, パーマリンク, percent-encode, fork, プロセス置換, Chromium, CA証明書]
---

# worklog: 【実装】【テスト】レビュー依頼メッセージへの重点ファイル・返信リンク付与

対象: issue #42（レビュー依頼メッセージに重点レビュー対象ファイルと返信コメントへのリンクを
含められるようにする）（2026-08-19）。
全体作業計画: なし（非対話のリモート実行環境のため、planツールによる全体計画は作成していない）
個別作業計画: `plans/【実装】【テスト】レビュー依頼メッセージへの重点ファイル・返信リンク付与.md`
push回数: 1

## 試したこと

### GitHubの差分アンカーの算出方法の実機確認（受け入れ条件の必須項目）

1. **Compareページを直接取得したが空振り**。
   `https://github.com/<owner>/<repo>/compare/<from>...<to>` のHTMLを取得しても `diff-` で始まる
   idは1つも含まれていなかった（`diff-comparisons` という無関係なclass名だけ）。ローカルで
   計算した `sha256sum` の値をHTML全体からgrepしても0件。現在のCompareページは差分本体を
   クライアント側で描画しており、初期HTMLに差分が入っていないため。
2. **コミットページはサーバレンダリングだった**。`/commit/<sha>` のHTMLには
   `id="diff-<64桁hex>"` が多数含まれており、`.claude/scripts/src/vcs/Gitlab.sh` に対する
   `645d26f1a0efff8ca3cef055f31fd35cb9b6659de3c37add0dd34de217c74631` が
   `printf '%s' '.claude/scripts/src/vcs/Gitlab.sh' | sha256sum` と一致した。ここで
   **「パス文字列のsha256」という算出方法が確定**した。
3. **Compareページ側でも同じアンカーが出ることを確認**。Compareページの初期HTMLに
   `<include-fragment src="/<owner>/<repo>/compare/file-list?range=<from>...<to>">` があり、
   この**断片HTMLを直接取得**すると `id="diff-<sha256(パス)>"` が全変更ファイルぶん出力されていた。
4. **75ファイルぶんで全件照合**。`8a39626...HEAD`（75ファイル）に対し、GitHubが出力した
   アンカー75件と、ローカルで `hash_paths sha256` を使って計算した75件が**完全一致**した
   （日本語ファイル名を含む）。
5. **blobリンクは実際にHTTP 200を確認**。percent-encodeした日本語パス
   （`plans/【実装】【テスト】単体テストの.claude配下への移動.md`）でも200が返った。

### ブラウザでのスクロール挙動の確認（できなかった）

Playwright + 同梱Chromiumで `#diff-<hash>` 付きURLを開いてスクロール位置を測ろうとしたが、
`net::ERR_CERT_AUTHORITY_INVALID` で失敗した。実行環境のegressプロキシがTLSを終端しており、
ChromiumがそのCA証明書を信頼していない（`curl` は同じURLで200を返すので、証明書設定が
ブラウザ側にだけ効いていない）。`--headless=new` で直接起動しても同じ。TLS検証を無効化する
方法は取らず、確認は人間へ残すことにした（HANDOFF.mdの「未解決の内容」）。

### 削除ファイルの扱い（実装中に発覚）

最初の実装では全変更ファイルに一律でblobリンクを出していたが、動作確認で出力されたURLを
叩いたところ**404が返るものがあった**。このpushで削除されたファイルは HEAD 時点に本体が
存在しないため当然だった。`git diff --diff-filter=D --name-only` で削除ファイル一覧を1回だけ
取得し、該当するものはblobリンクを出さず「（このpushで削除。本体のリンクは無し）」と注記して
差分アンカーリンクのみを出すようにした。

### 注入テキストのサイズ調整

上限15件で試したところ、注入テキスト全体が **8058バイト**になった。日本語ファイル名は
percent-encodeで3倍近くに膨らむうえ、1ファイルにつきURLを2本出すため。このhook自体が
コンテキスト肥大への対処（/compactの呼びかけ）を兼ねているのに供給側が肥大の原因になるのは
本末転倒なので、上限を10件へ下げた（**5936バイト**）。

## うまくいったこと

- **fork回数をファイル数から切り離せた**。`get_blob_url` / `get_diff_anchor_url` は標準出力へ
  返す既存インターフェースのままにしつつ、ループ全体を1つのプロセス置換 `< <( ... )` の中へ
  入れることで、URL組み立てのforkを1回に固定できた。あわせて `get_provider` の
  `$(git remote get-url origin)` をメモ化した（これを消さないとディスパッチャ内で毎回forkする）。
  結果、`build_file_links_text` のfork回数はファイル数に依存しない定数になった。この知見は
  `.claude/rules/shell-script-style.md`「外部プロセス起動のコスト」節へ追記した。
- **ハッシュ計算も1回に集約できた**。各パスを連番の一時ファイルへ書き出して `sha256sum` を
  1回だけ呼ぶ（`hash_paths`）。パスに改行・記号が含まれても影響を受けない。
- **percent-encodeをbash組み込みだけで実装**（`url_encode_path_to_reply`）。`LC_ALL=C` を
  ローカルに設定して `${s:i:1}` をバイト単位の切り出しにすることで、日本語パスも
  UTF-8バイト単位で `%XX` へ変換できた。単体テストで実際のGitHub URLと一致することを確認済み。
- **既存4リンクの挙動を変えずに済んだ**。`build_links_text` の引数から前回SHAの判定を外し、
  判定済みの `since_url` を受け取る形にしたことで、重点ファイルの差分範囲と参照リンクの差分範囲が
  必ず一致するようになった（両者が別々に判定していると食い違いうる）。

## ダメだったこと

- **Compareページの初期HTMLからアンカーを探そうとして時間を使った**（クライアント描画のため空振り）。
  遅延読込の `include-fragment` の `src` を辿るのが正解だった。GitHubのページ構造を調べるときは、
  まず初期HTMLに `include-fragment` / `react-partial` があるかを見るのが早い。
- **Chromiumでの確認は断念**（上記のCA証明書の件）。
- `gh` CLI がこの実行環境に無いため、`comments` / `reply` のCLI経路（GraphQLの `url` 追加、
  mutationの `comment { url }` 化）は**実際に実行しての確認ができていない**。GraphQLのフィールド
  自体はissue #42の本文で「PR #37で実機確認済み」と記録されているものを使っている。

## 次の一歩

- 人間による確認: ①差分アンカー付きURLをブラウザで開き、該当ファイルの差分位置までスクロールするか
  ②`gh` のある環境で `comments` / `reply` を実行し、`url=` と返信URLが出ることを確認する。
- GitLab側は【未検証】のまま（GitLab remoteが無いため。既存のGitLab実装と同じ扱い）。

---
