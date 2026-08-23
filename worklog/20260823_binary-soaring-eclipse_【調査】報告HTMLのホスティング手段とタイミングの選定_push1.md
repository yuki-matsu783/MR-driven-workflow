---
title: worklog 20260823 報告HTMLのホスティング手段とタイミングの選定 push1
type: log
description: issue #114（報告HTMLのホスティングとURL通知）のフェーズ2〈調査〉における試行錯誤ログ（push1）。
tags: [worklog, issue114, hosting]
keywords: [issue114, 調査, Review Apps, GitHub Pages, GitLab Runner, flow-id 5-4, 配布資産, 敵対的レビュー]
---

# worklog: 【調査】報告HTMLのホスティング手段とタイミングの選定

対象: `reports/` 配下の報告HTMLをホストしURLを払い出す手段と、そのタイミングの選定（2026-08-23）。
全体作業計画: `plans/binary-soaring-eclipse.md`
個別作業計画: `plans/【調査】報告HTMLのホスティング手段とタイミングの選定.md`
push回数: 1

## 試したこと

### フェーズ1（起点）で確認したこと

- `gh repo view` でリポジトリの可視性を確認 → **PUBLIC**。GitHub Pages の利用条件は満たす。
- `gh api repos/yuki-matsu783/MR-driven-workflow/pages` → **404**。Pages は**未有効**である。
- `ls .github/workflows .gitlab-ci.yml` → **どちらも存在しない**。CI設定はゼロからの新規追加になる。
- `grep -r upload_attachment` → flow-id 5-3 の**層3**として既に添付機構がある
  （`Provider.sh` / `Github.sh` / `Gitlab.sh`）。GitHubは未ドキュメントAPI、GitLabは実機未検証。
- `main` が issue #114 の起票後に進んでおり、**#156（計画・レポートのHTMLビューのテンプレート
  切り出し）** が入っていた。これにより `plans/` にもHTMLビューが付くようになっている。

### issue本文と現行フローのずれ

issue #114 は「flow-id 5-4（Draft解除・マージ依頼）」「flow-id 5-1 でmainマージ前に削除される」と
書いているが、**#111（統括レポートの追加）・#112（片付けの並べ替え）により番号が繰り下がって
いる**。現行は次のとおり。

| issue本文の記述 | 現行のflow-id |
|---|---|
| Draft解除・マージ依頼 | **5-5** |
| `reports/` の削除 | **5-4** |

> **この表は push1 時点の観測である。push2 で `main`（#157）を取り込んだ結果さらに1つ繰り下がり、
> 現在はそれぞれ 5-6・5-5 になっている。**（下の push2 節を参照。最新の対応表は
> `plans/binary-soaring-eclipse.md`「issue 起票後に前提が変わっている」が正）

この結果、**「マージ依頼時にホストする」を素直に実装すると対象ファイルが既に無い**という矛盾が
生じることに気づいた。これを調査の問い1（最重要）として立てた。

## うまくいったこと

- 全体作業計画（`plans/binary-soaring-eclipse.md`）と個別調査計画を、テンプレート
  （`.claude/skills/issue-mr-flow/assets/plans.template.html`）を土台にHTMLビューまで作成できた。
  プレースホルダ0件・外部依存0件を `grep -c` で確認済み。
- **HTMLの組み立ては「テンプレートの `<style>` ブロックを `sed -n` で切り出し、本文だけを
  Writeツールで書いて `cat` で連結する」形にした。** テンプレート全体をコピーして編集するより
  差分が小さく、スタイルを取りこぼさない。

## ダメだったこと

- **`python` が Python 2 だった。** HTMLの一括置換に `python - "$O" <<'PY'` を使おうとしたところ、
  `SyntaxError: Non-ASCII character '\xe5' ... but no encoding declared` で失敗した。
  数行の修正は Edit ツールで直接行うほうが確実（`.claude/rules/shell-script-style.md`
  「AIエージェント向け注記」と同じ結論）。
- **md と HTML の節見出しがずれていた。** 最初に書いた全体作業計画の md は
  `Context` / `スコープ` / `フェーズ3〈作業〉` という独自の見出しだったが、HTMLビューは
  テンプレートの節構成（`前提（合意状況）` / `この計画で何をするか` / `変更対象` / `方針` …）
  だった。`plans/REVIEW-POINTS.md` の「md側とHTML側で、節の見出しが一致しているか」に反するため、
  **md 側をテンプレートの節構成へ揃え直した**（`### issue 起票後に前提が変わっている` などの
  h3 も HTML 側へ追加した）。

## 次の一歩

- flow-id 2-2: commit・push してレビュー依頼を出し、**計画に対する敵対的レビューを1回**実行する。
- flow-id 2-6: 調査を実施し、`reports/20260823_binary-soaring-eclipse_ホスティング手段の比較.md`
  と同名の `.html` へ結果を書く。

---

# push2（flow-id 2-4・レビュー往復1周目）

## 試したこと

- 敵対的レビュー（フェーズ2・1回目）を実施。12件の指摘のうち9件をPR #180 へインライン投稿し、
  3件は確度・重大度の振り分け（minor × medium）により報告のみに留めた。
- `main`（PR #157）の取り込み。`HANDOFF.md` に追記コンフリクトが出た。
- ユーザーからチャットで「(b) 5-3でホストがいいかな」という判断を受け、両計画へ反映した。

## うまくいったこと

- **敵対的レビューが、自分では気づけなかった前提の誤りを1件見つけた。**
  「`.github/workflows/*.yml` は `.claude/` の外なので配布対象外」と書いていたが、
  `sync-assets.sh:51` が `cp -R "${PROJECT_ROOT}/.github/"* "${ASSETS_DIR}/.github/"` で
  `.github/` を丸ごと配布資産へ集めており、`install-to-project.sh:194` が `safe_copy_dir` で
  展開していた。**「含めない」と決めても、何もしなければ実現されない**という帰結まで指摘された。
- `HANDOFF.md` のコンフリクトは**類型C（同じドキュメントの近接行への追記）**だったため、
  監視の規定に従い人間の確認を待たずに自動解消できた（`main` 側の新しいヘッダ行
  `- 未返信スレッド:` と、こちらの `- 追従監視:` の両方を残した）。

## ダメだったこと

- **`python` が Python 2、`python3` も無かった。** HTMLの一括置換に使おうとして2回失敗した
  （1回目は `SyntaxError: Non-ASCII character`、2回目は `Exit code 49`）。
  数行の修正は Edit ツール、全面書き換えは Write ツールで行うのが確実。
- **HTMLのヘッダ種別の class 名を `kicker` と書いていた。** テンプレートのCSSが定義しているのは
  `.kind` で、`kicker` にはスタイルが1つも当たらない（**見た目が崩れるだけで、
  プレースホルダ検査も自己完結検査も通ってしまう**ため気づきにくい）。
  テンプレート本体はこの位置をHTMLコメントで置き換えていて要素名が読めないので、
  **`<style>` 側のセレクタ一覧から class 名を確かめる**必要がある。

## 気づいたこと（フェーズ4の反映候補）

- **`main` を取り込んだらフローの flow-id が繰り下がっていた**（#157 が 5-3 に `.gemini/` 変換同期を
  新設）。計画・HANDOFF.md の flow-id 参照をすべて書き換えることになった。
  **計画に flow-id を書くときは、繰り下がりが起きうる前提で対応表を1箇所に持つ**とよい
  （今回は上位計画の「issue 起票後に前提が変わっている」節へ集約した）。
- `main` 由来の単体テスト失敗が3件ある（`test_block_direct_git_commit.sh` の
  バックスラッシュ+改行分割1件、`test_command_position.sh` の性能2件）。本issueとは無関係。

## 次の一歩

- flow-id 2-3（2周目）: 修正した計画について人間の再レビューを待つ。
- 合意後、flow-id 2-5（`describe`）→ 2-6（調査の実施）へ。

---

# push3（flow-id 2-6・調査の実施）

## 試したこと

- GitHub Docs / GitLab Docs を一次情報として、問い2・問い3の必要条件を確認した。
- `curl -sSI` で `raw.githubusercontent.com` のレスポンスヘッダを実測した。
- `gh api repos/{o}/{r}` と `.../pages` でリポジトリの可視性・Pagesの有効状態を確認した。
- `sync-assets.sh` / `install-to-project.sh` を読み、CI設定が配布経路に載るかを確認した。

## うまくいったこと

- **却下理由を推測ではなく実測で裏取りできた。** `raw.githubusercontent.com` は
  `content-type: text/plain; charset=utf-8` ＋ `x-content-type-options: nosniff` を返す。
  `nosniff` が付いている以上、ブラウザは絶対にHTMLとして解釈しない。
- **URLが決定的に組み立てられることが分かった**（`https://<owner>.github.io/<repo>/pr-<n>/`）。
  これにより「5-4 でホストして 5-6 で通知する」案(b)が、APIで結果を引き直さずに成立する。
- **配布経路の非対称を実装から特定できた。** `.github/` と `.gitlab/` はディレクトリ丸ごと配られる
  一方、`.gitlab-ci.yml` はルート直下の明示リストに無いので配られない。

## ダメだったこと

- **見出しの突き合わせスクリプトで `<code>` を含む見出しが途中で切れた。**
  `grep -oE '<h[234]>[^<]*'` は最初のタグで止まるため、`### 問い1(iii): <code>plans/</code>…` が
  `### 問い1(iii): ` になった。`grep -oE '<h[234]>.*'` ＋ `sed 's/<[^>]*>//g'` にして解決した。
- **md には `####` で書いた小見出しを、HTML では `.box` の `label` にしていた箇所が1件あった**
  （「Runner 上の静的サーバを却下した理由」）。`plans/REVIEW-POINTS.md`・
  `reports/REVIEW-POINTS.md` の「md側とHTML側で節の見出しが一致しているか」に反するため、
  `<h4>` ＋ `.box` の2段に直した。**box の label は見出しの代用にならない。**

## 気づいたこと（重大）

- **GitLab Pages の並列デプロイ（`pages.path_prefix`）は Premium/Ultimate 限定**（17.9 GA）。
  検証環境の `gitlab/gitlab-ce:18.5.4-ce.0` は **Community Edition ＝ Free tier** なので、
  flow-id 1-4 で合意した「Runner を立てて実機検証する」が**そのままでは成立しない**。
  加えて self-managed の GitLab Pages は `pages_external_url` に**インスタンスとは別ドメイン**と
  ワイルドカードDNSが要り、`localhost:8929` の環境では Runner 以前にここが壁になる。
- **GitHub Pages は private リポジトリでもサイトが既定で公開される**（非公開化は Enterprise Cloud
  のみ）。issue #114 の受け入れ条件「プロジェクトの可視性設定に従う」を満たすには、
  ワークフロー側に「public のときだけデプロイする」ガードが要る。
  **「確認する」と計画に書いておいて良かった項目**で、書いていなければ実装後に気づいていた。

## 次の一歩

- flow-id 2-7: commit・push してレビュー依頼を出し、**調査結果に対する敵対的レビューを1回**実行する。
- flow-id 2-8: GitLab側の検証方針（α 見送り / β トライアルライセンス / γ GitLab.com）の判断を仰ぐ。

---
