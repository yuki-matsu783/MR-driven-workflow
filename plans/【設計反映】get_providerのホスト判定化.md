# 【設計反映】get_providerのホスト判定化

対象issue: [#45](https://github.com/yuki-matsu783/MR-driven-workflow/issues/45)
全体作業計画: `plans/mutable-beaming-leaf.md`
前段の個別作業計画: `plans/【実装】【テスト】get_providerのホスト判定化.md`

`plans/` `worklog/` の内容を `.claude/docs/spec/` `.claude/docs/ddr/` へ反映する。
`.claude/rules/` `.claude/skills/` への反映（AIアセット反映）は
`plans/【AIアセット反映】get_providerのホスト判定化.md` として分け、本計画のレビュー・実施が
完了してから着手する（`.claude/skills/issue-mr-flow/SKILL.md`「種別を複数併記する場合／分ける場合」）。

## 反映対象の一覧

| ファイル | 種別 | 内容 |
|---|---|---|
| `.claude/docs/spec/issue-mr-workflow.md` L69 | 更新 | `Provider.sh` の判定方式の説明を新方式へ |
| 同 「提供関数」表直後の段落（L103-108） | 追記 | 内部ヘルパーの説明へ `provider_from_remote_url` を追加 |
| 同 「決定済み事項（旧・未決定事項）」 | 追記 | プロバイダ判定の規則を決定事項として記録 |
| 同 「未決定事項・懸念点」L1331- | 更新 | 「GitLab側の動作未検証」の3点のうち**ディスパッチの1点を解消**、残り2点は維持 |
| 同 「影響範囲」 | **新規エントリ追記** | issue #45分。**過去のエントリは書き換えない** |
| `.claude/docs/ddr/0027-....md` | 新規（**要判断**） | 判定方式の意思決定・却下案・受け入れたトレードオフ |
| `.claude/docs/README.md` | 追記 | DDR一覧（DDR 0027を作る場合のみ） |
| `.claude/scripts/src/vcs/Provider.sh` | 追記 | DDR 0027を作る場合のみ、関数コメントへ参照を1行追加 |

## 1. `Provider.sh` の説明（L69）を更新する

現状は判定方式が旧実装のままである。

> - **`Provider.sh`**: `git remote get-url origin` のホスト名（`github.com` / `gitlab.*`）でプロバイダを判定し、…

「ホスト名で判定」とは書いてあるが、実際の旧実装は**URL文字列全体への部分一致**であり、記述と実装が
食い違っていた（この食い違い自体がissue #45のバグの正体でもある）。次の内容へ書き換える。

- `git remote get-url origin` から**ホスト部を抽出**して判定すること
- 判定規則（`aslead` → gitlab ／ `github` を含む → github ／ それ以外 → gitlab）
- 純粋関数 `provider_from_remote_url` に切り出してあり、単体テスト可能であること
- `gh`/`glab` の認証状態に依存しないこと

**現在の状態を説明する節**なので書き換えてよい（`.claude/rules/docs-workflow.md`）。

## 2. 「提供関数」表直後の段落へ `provider_from_remote_url` を追記する

現在この段落は、issue #48で追加した `gitlab_format_discussion_notes` を例に「共通インターフェース表に
載らない内部ヘルパー」を説明している。`provider_from_remote_url` も同じ位置づけ（`Provider.sh` 内には
あるが、呼び出し側が直接使う共通インターフェースではなく、`get_provider` の内部実装）なので、
同じ段落に1〜2文で足す。

**あわせて「`Provider.sh` 内の関数がすべて公開インターフェースとは限らない」ことを明示する。**
実機検証中に、`github_get_compare_url` / `gitlab_get_compare_url` に対応するディスパッチャが
`Provider.sh` に無いことを知らずに `get_compare_url` を呼んで `command not found` になった
（公開されているのは `get_mr_diff_url` / `get_mr_diff_since_url` の方で、これは設計どおり）。
表と実ファイルの関係を読み手が誤解しない一文を添える。

## 3. 「決定済み事項（旧・未決定事項）」へ判定規則を追記する

「GitHubでなければGitLabとみなす」という規則自体は、後から読む人が最も疑問に思う点なので、
決定事項として1項目残す。内容は次の3点に絞る（詳細はDDRへ逃がす）。

- ホスト名に `github` を含めばGitHub、それ以外はGitLab。本ワークフローの対応プロバイダが
  GitHub/GitLabの2つに限られることが前提。
- 社内GitLab（`aslead`）はGitHub判定より前に明示ケースとして評価する。
- 判定は認証状態に依存しない（`gh`/`glab` を呼ばない）。

## 4. 「未決定事項・懸念点」の「GitLab側の動作未検証」を更新する

現在3点が残るとされているうち、**1点目（`Provider.sh` 経由のディスパッチ）を解消**する。

現状の記述:

> - **`Provider.sh`経由のディスパッチ**: `get_provider`がself-hostedのGitLab URLを判定できない
>   （issue #45、未修正）ため、検証は`gitlab_*`関数を直接呼ぶ形で行った。ディスパッチャ経由の
>   経路は依然として未検証。

これを、issue #45で解消した旨と、実際にディスパッチ経由で確認した関数一覧に差し替える
（`get_provider` / `get_repo_url` / `get_issue` / `get_mr_for_branch` /
`get_mr_unresolved_comments` / `add_mr_comment` / `set_mr_description` / `add_mr_thread_reply` /
`get_mr_diff_url` / `get_mr_diff_since_url` / `get_workflow_config` /
`get_issue_number_from_branch`）。

**残る2点（バージョン・エディション／プロジェクト構成）はそのまま残す。**
見出しの `（issue #48で部分解消）` は `（issue #48・#45で部分解消）` へ更新する。

L1456付近の `gitlab_new_issue` に関する「（issue #48で解消）」の項目は**変更しない**
（issue #45とは独立した記述で、内容も現在も正しいため）。

## 5. 「影響範囲」へ新規エントリを追記する

末尾へ issue #45 分のエントリを**追記**する。過去issueのエントリ（issue #48分を含む）は
**一切書き換えない**（`.claude/rules/docs-workflow.md`。issue #24で歴史を壊しかけた実例あり）。

記載内容:

```
変更（追加分・issue #45 get_providerのホスト判定化）:
- .claude/scripts/src/vcs/Provider.sh
  - provider_from_remote_url を純粋関数として新設（remote URLからホスト部を抽出し
    プロバイダ名を返す。パラメータ展開のみで外部コマンド呼び出し無し）
  - get_provider を上記関数の薄いラッパーへ変更。URL文字列全体への部分一致をやめたことで、
    ホスト名に gitlab を含まないself-hosted GitLabを判定できるようになり、
    パスに github を含むGitLab URL（https://gitlab.com/github-mirror/x.git）の誤判定も解消
- tests/test_vcs_provider.sh（provider_from_remote_url の単体テストを15件追加。Provider.sh の
  sourceを追加。passed=26 failures=0）
- .claude/docs/spec/issue-mr-workflow.md（本ファイル。…上記1〜4の各項目…、本エントリを追加）
```

DDR 0027を作る場合は「新規（追加分・issue #45 …）」の節も足す。

## 6. DDR 0027 を新規作成する（**要判断**）

**作るべきだと考える。** 理由は、この判定規則が「GitHubでなければGitLab」という*一見雑に見える*
決定であり、なぜそれで十分なのか・なぜ他の案を採らなかったのかを記録しないと、将来
「ちゃんとGitLabかどうか判定すべきでは」と再検討が起きやすいため。実測値を残せる点も大きい。

タイトル案:
`0027-プロバイダ判定はremote-URLのホスト部でgithub以外をgitlabとみなす.md`

構成案:

| 節 | 内容 |
|---|---|
| 背景 | self-hosted GitLabを弾いていた問題。issue #48で `Gitlab.sh` は検証済みで、判定だけが障害だったこと |
| 決定 | ホスト部を抽出し `aslead` → gitlab、`github` → github、それ以外 → gitlab |
| 却下した案 | ①`glab auth status`（14.5秒）②`glab config get token --host`（0.55〜0.9秒）③`config.yml`直読み（0.1秒だが`%LOCALAPPDATA%`依存）④`.mrworkflow.json`への`provider`キー（全ディスパッチで約190ms増）。**①〜③に共通する決定的な欠点は「未ログインでは判定できない」こと**を明記する |
| 受け入れたトレードオフ | 非対応リモート（Bitbucket・typo）に対する明快なエラーが出なくなる。対応プロバイダが2つしかない以上、self-hostedを通しつつ非対応を弾く判定は原理的に書けない。レビューで合意済み |
| メモ化できない理由 | 全ディスパッチャが `case "$(get_provider)" in` というコマンド置換で呼ぶためサブシェルとなり、グローバル変数によるキャッシュが効かない。ゆえに判定コストをゼロに保つ必要があった |

**DDR 0005・0026は変更しない**（空コミットフォールバックの判断は本issueと独立）。

DDR 0027を作る場合は、あわせて次の2つも行う。

- `.claude/docs/README.md` のDDR一覧へ0027を追加する。
- `Provider.sh` の `provider_from_remote_url` のコメントへDDR 0027への参照を1行追加する。
  **実装時は意図的に入れていない**（作らない可能性があり、辿れない参照を残さないため）。

## やらないこと

- `.claude/rules/` `.claude/skills/` `AGENTS.md` `CLAUDE.md` への反映
  （`plans/【AIアセット反映】get_providerのホスト判定化.md` で別途扱う）。
- `.claude/docs/spec/shell-scripts.md` の更新。本issueで新しいbash規約上の知見は
  `Provider.sh` 側ではなくテストの書き方に出たため、AIアセット反映側で扱う。
- 過去issueのchangelogエントリの書き換え・DDR本文の変更。

## worklog

flow-id 4-6（設計反映の実施）の開始時に
`worklog/20260819_mutable-beaming-leaf_【設計反映】get_providerのホスト判定化_push<N>.md` を作成する。
