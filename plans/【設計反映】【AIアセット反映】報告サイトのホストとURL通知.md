---
title: 【設計反映】【AIアセット反映】報告サイトのホストとURL通知
type: plan
description: issue #114 フェーズ4の個別反映計画。報告HTMLのホスト機構をspec・DDR・AIアセットへ反映するための、反映先ごとの具体的な変更内容を定める。
tags: [issue-mr-flow, reflection, spec, ddr]
keywords: [issue114, フェーズ4, 設計反映, AIアセット反映, DDR, i0114-01, issue-mr-workflow, gitlab-verification-environment, distribution-assets, shell-scripts, GitHub Pages, GitLab Pages, VERSION]
---

# 【設計反映】【AIアセット反映】報告サイトのホストとURL通知

- issue: [#114](https://github.com/yuki-matsu783/MR-driven-workflow/issues/114)
- PR: [#180](https://github.com/yuki-matsu783/MR-driven-workflow/pull/180)（Draft）
- 対象フェーズ: **フェーズ4〈反映〉**（flow-id 4-1〜4-10）

## 前提（合意状況）

依拠する成果物と、それがどの flow-id で合意されたか。

| 依拠するもの | 合意 |
|---|---|
| 上位の計画 `plans/binary-soaring-eclipse.md`（全体作業計画） | **flow-id 1-5** |
| 調査結果 `reports/20260823_binary-soaring-eclipse_ホスティング手段の比較.md` | **flow-id 2-9** |
| 作業結果 `reports/20260823_binary-soaring-eclipse_ホスト機構の実装.md` | **flow-id 3-9** |
| ベースブランチ `main`（分岐点 `318447a`） | flow-id 1-3 |

- **フェーズ3〈作業〉は完了済み**（flow-id 3-6〜3-9 の1周目を完了、3-10 で MR description を更新）。
- 敵対的レビューは**フェーズ3で2回**実施し（上限3回）、13件すべてを反映済み。
  **フェーズ4でも計画時1回・作業実施ごと1回、自動実行してMRへ投稿する**（全体作業計画 flow-id 1-4 の合意）。
- **反映のうち1件はフェーズ3から明示的に送られている**——`index.md` と
  `.claude/rules/directory-structure.md` への `.github/workflows/` `.gitlab-ci.yml` の追加
  （フェーズ3の敵対的レビュー指摘）。
- **種別を2つ併記した**のは、spec/DDRへの反映（設計反映）と `rules/` `index.md` への反映
  （AIアセット反映）が、どちらも「issue #114 で決めたことを恒久ドキュメントへ移す」という
  1つの作業だからである。合意の単位が分かれない。**`【実装反映】` は付けない**（実装は
  フェーズ3で完了しており、この反映で変わるコードは無い）。

## この計画で何をするか

issue #114 で決めたこと・作ったもの・踏んだ罠を、**タスク単位で消える成果物**（`plans/`
`worklog/` `reports/`）から、**永続するドキュメント**（`.claude/docs/spec/` `.claude/docs/ddr/`
`.claude/rules/` `index.md`）へ移す。

> **なぜ必要か**: `reports/` は flow-id 5-5 で削除され、squash merge により `main` にも残らない。
> 「なぜ `projects/:id` なのか」「なぜ `exit 0` がガードにならないのか」「なぜ `${v//a/b}` を
> 使わないのか」は、**次に同じ場所へ触る人が最も知りたい情報**でありながら、何もしなければ
> このMRのマージと同時に消える。

## どこを正にするか（先に決める）

**この計画で最も間違えやすいのは「新しく書く」ことではなく「既にあるものと二重に書く」ことである。**
`SKILL.md` には既にフェーズ3で書いた `## 報告サイトのホストとURL通知（flow-id 5-4・5-6）` 節
（1481〜1579行）があり、5つのブロックを持つ。**反映を始める前に、ブロックごとに行き先を決める。**

| `SKILL.md` の既存ブロック | 行 | 判断 |
|---|---|---|
| `### なぜ 5-4 でホストし、5-6 で通知するのか`（flow-idごとに何が起きるかの表） | 1491-1507 | **SKILL.md に残す。** flow-idの表は手順を実行する側が読むもの。**DDRは「なぜ案(b)を選び (a)(c) を捨てたか」だけを書き、この表を再掲しない** |
| `### CI側の仕組み`（方式・起動・デプロイ可否・寿命の対比表、`index.html` 生成の必要性） | 1509-1531 | **spec へ移し、`SKILL.md` は spec への1行リンクに置き換える。** CIの内部方式は「いま何がどうなっているか」であり spec の担当。AIエージェントは手順上CIを起動しないので、SKILL.md に詳細を持つ必要が無い |
| `### flow-id 5-6 での呼び出し方`（コード例・失敗時の扱い） | 1533-1553 | **SKILL.md に残す。** 手順そのもの。**spec は触れない** |
| `### 使う前に知っておくこと（配布先向け）`（公開範囲・fork運用・tier・ブランチパターン・掃除の表） | 1555-1567 | **SKILL.md に残す。** 雛形2本のヘッダが既に「正はこの表」と名指ししている。**spec・DDR は再掲せず、必要なら参照する**（DDRが書くのは「なぜその代償を受け入れたか」であって表の内容ではない） |
| `### gh/glab CLI不在時` | 1569-1579 | **SKILL.md に残す。** 手順。spec 側は「提供関数の表」に MCP 代替なしの行を持つのみ（表の一部であり重複ではない） |

**したがって spec の新節に新しく書くのは2つだけ**である——(a) `SKILL.md` から移設する「CI側の
仕組み」、(b) **実機検証で確かめた範囲と確かめていない範囲**（`SKILL.md` にも `reports/` にしか
無い）。

## 変更対象

| # | 反映先 | 操作 | 何を書くか |
|---|---|---|---|
| 1 | `.claude/docs/ddr/i0114-01-….md` | **新規** | ホスティング手段とタイミングの選定、および却下案 |
| 2 | `.claude/docs/README.md` | 変更（**生成**） | `generate-ddr-list.sh` の再実行結果 |
| 3 | `.claude/docs/spec/issue-mr-workflow.md` | 変更 | 提供関数の表に2行／新節（上表の(a)(b)）／`影響範囲` へ issue #114 のエントリ |
| 4 | `.claude/skills/issue-mr-flow/SKILL.md` | 変更 | `### CI側の仕組み` を spec への1行リンクへ置き換える（上表の判断に伴う） |
| 5 | `.claude/docs/spec/gitlab-verification-environment.md` | 変更 | **GitLab Runner の構築手順**と、そこで踏んだ落とし穴 |
| 6 | `.claude/docs/spec/distribution-assets.md` | 変更 | CI設定を配布しない判断／生成物・ローカル状態の一括除去 |
| 7 | `.claude/docs/spec/shell-scripts.md` | 変更 | `curl` 依存の追記 |
| 8 | `.claude/rules/shell-script-style.md` | 変更 | **bash 5.2 の `patsub_replacement`** の罠 |
| 9 | `.claude/rules/directory-structure.md` | 変更 | `.github/workflows/` と `.gitlab-ci.yml` をツリーへ／**`issue-mr-flow/assets/` の「テンプレート2本」を直す** |
| 10 | `index.md` | 変更 | 同上（Repository Map の行を追加） |
| 11 | `.claude/VERSION` | 変更（**人間の判断**） | 増分をAIが提案し人間が決める（下記） |
| 12 | `.claude/skills/adversarial-review/SKILL.md` | **変更しない**（下記「やらないこと」） | — |

### 1. DDR `i0114-01`（新規）

**識別子**: `i0114-01`（issue番号4桁ゼロ埋め＋枝番2桁。このissueで作るDDRは1件）。

| 節 | 書く内容 |
|---|---|
| 決定 | 報告HTMLは**CIでPR/MR単位のサブパスへデプロイし、flow-id 5-4 でホスト・5-6 で通知する**。GitHubは `gh-pages` の `pr-<n>/`、GitLabは Pages parallel deployments の `mr-<iid>/` |
| なぜタイミングが 5-4 なのか | **案(a) 不変パス・案(c) SHA指定を却下した理由**。**flow-idごとに何が起きるかの表は書かない**（`SKILL.md` 1491-1507 が正。ここは判断だけを書く） |
| なぜその手段なのか | 却下案4つ（raw.githubusercontent.com／Actions artifact／`upload_attachment`／外部ホスティング）と、それぞれの却下理由 |
| 受け入れた代償 | **なぜそれを受け入れてよいと判断したか**を書く。**代償の一覧そのものは再掲しない**（`SKILL.md` 1555-1567 の表が正）。判断の要点は「レビュー期間中に読まれることの価値が、公開範囲・fork運用・掃除の欠如という制約を上回る」こと |
| 失敗を正常系として扱う設計 | `upload_attachment`（flow-id 5-4 の層3）と同じ扱いにした理由 |

**本文には「実装がどうなっているか」を書かない**（それは spec の担当）。書くのは
**なぜそれを選び、何を捨てたか**である。

### 2. `.claude/docs/README.md`（生成）

```bash
bash .claude/scripts/src/generate-ddr-list.sh
```

**手書きしない。** 出た差分を同じコミットへ含める。

### 3. `.claude/docs/spec/issue-mr-workflow.md`

| 箇所 | 変更 |
|---|---|
| `### 提供関数` の表 | `get_report_site_url [<n>]` と `wait_for_report_site <url> [<上限秒>] [<間隔秒>]` の2行。GitHub実装／GitLab実装の列も埋める。**`wait_for_report_site` はプロバイダ非依存（`—`）であり、`require_vcs_cli` を通らない**ことを明記する |
| 新節 `### 報告サイトのホストとURL通知（issue #114）` | 上記「どこを正にするか」で決めた2つだけを書く——(a) `SKILL.md` から移設する**CI側の仕組み**、(b) **実機検証で確かめた範囲と確かめていない範囲** |
| `## 影響範囲` | `### issue #114（報告サイトのホストとURL通知）` を**新規エントリとして追記**する。**既存のエントリは1行も書き換えない**（point-in-time の記録であるため） |

**新節の挿入位置に注意する。** 「最終統括レポートとPR/MRへの反映（issue #111）」の節は、末尾
（800-804行）が**節全体を締める地の文**（「手順の正は SKILL.md …。判断の理由・却下案は i0111-01 を参照」）
で終わっている。**この直後へ差し込むと、その段落が新節の前置きに読める。**
`.claude/rules/docs-workflow.md` がまさにこのケースを注意しているので、**挿入前に係り先を確認し、
必要なら次の `###`（`セッション開始時の自動コンテキスト注入`）の直前など、係り先が変わらない位置へ回す。**

### 4. `.claude/skills/issue-mr-flow/SKILL.md`

`### CI側の仕組み`（1509-1531）を、**spec の新節への1行リンク**へ置き換える。
**移した先を名指しし、「詳細は spec」と書く**（節ごと消すと、手順を読んでいる途中で仕組みを
知りたくなった人が辿れなくなる）。他の4ブロックは触らない。

### 5. `.claude/docs/spec/gitlab-verification-environment.md`

**`## 手順` のコードブロックへ、Runner の登録を追記する**（現在は 1〜5 のみで Runner が無い）。

| 追記する内容 |
|---|
| `gitlab-net` ネットワークの作成と、GitLab コンテナの接続 |
| `gitlab/gitlab-runner` コンテナの起動（`-v //var/run/docker.sock:/var/run/docker.sock`。**`MSYS_NO_PATHCONV=1` をサブシェルへ閉じ込める**） |
| `POST /user/runners`（`runner_type=project_type`）による認証トークンの取得 |
| `config.toml` への `clone_url` 追記（コンテナ間はホスト名 `gitlab` で解決するため） |

**Runner認証トークンは、PATと同じ扱いにする。** 同ファイルの `### PATの扱い`（94-103行）は
「値をファイルへ書かない」「マスクは実データに当たることを確かめてから使う」と定めているが、
**Runnerトークンはこの節が扱っていない新種の秘密情報**である。

- 手順のコードブロックには**実値を載せず `<runner-token>` 等のプレースホルダで書く**。
- `config.toml` は**コンテナ側のボリューム内**にあり、リポジトリのツリーへ置かない旨を明記する。
- `### PATの扱い` 節の見出し・本文へ、Runnerトークンも対象であることを1行足す。

`## 実際に踏んだ落とし穴` へは次を足す。

- **`docker run -v /var/run/docker.sock:…` が `mkdir C:\Program Files\Git\var: Access is denied` になる**
  （MSYSのパス変換）。`//var/run/…` と `MSYS_NO_PATHCONV=1` の使い分け。
- **`glab api` が `wsarecv: An existing connection was forcibly closed` で断続的に落ちる**
  （`localhost` → `[::1]`）。`127.0.0.1` を明示する回避。
- **`projects/<group>/<repo>` は存在しないルートである**（`%2F` が要る）。**404のレスポンスの形が
  2種類ある**（`{"message":…}` はリソースが無い／`{"error":…}` はルートが無い）ことを、
  切り分けの道具として書く。

### 6. `.claude/docs/spec/distribution-assets.md`

| 箇所 | 変更 |
|---|---|
| `### 配布経路での扱い` | **CI設定（`.github/workflows/` `.gitlab-ci.yml`）は配布しない**という判断と理由。雛形を `.claude/skills/issue-mr-flow/assets/` へ置き、`.claude/` ごと配ることで代替している点 |
| 同上 | **2つは除外の機構が違う**（下記） |
| 同上 | **生成物・ローカル作業状態は、集め終えたあとに一括で除去する**（`index.jsonl` ／ `.claude/state/`）。**コピーの各所で個別に弾く形は取りこぼす**という教訓 |
| `## 影響範囲` | `### issue #114` を新規エントリとして追記 |

**「CI設定は配布しない」を2ファイル同列に書かない。**

| ファイル | 配布されない理由 | 壊れやすさ |
|---|---|---|
| `.github/workflows/` | `sync-assets.sh` の `case "${entry##*/}" in workflows) continue ;; esac` で**明示的に除外** | 除外行を消さない限り崩れない |
| `.gitlab-ci.yml` | 「5. ルートファイルの同期」が**個別に `cp` するホワイトリスト方式**で、そもそも列挙されていない | **ガードが無い。** 将来ルートファイルのコピーを一括化した人が、無言で配布物へ入れてしまう |

この差を書かずに1つの判断として記録すると、後者が崩れたときに**specの記述だけが正しいまま残る**。
なお **`sync-assets.sh` の除外を固定するテストは無い**（`test_vcs_provider.sh` が固定しているのは
雛形と実ファイルの**バイト一致**だけ）。テストを足すかどうかは flow-id 4-6 で判断し、
**足さないと決めた場合はその理由を spec へ書く**（「無い」ことが意図なのか漏れなのかを、次に読む人が
判別できるようにするため）。

### 7. `.claude/docs/spec/shell-scripts.md`

`### 前提（新規追加）` へ **`curl`** を足す。「`wait_for_report_site` のみ。無い場合は到達性確認を
スキップする」という限定と、**`AGENTS.md` の「curlへフォールバックしない」の対象外である理由**
（API情報取得ではないため）を併記する。

### 8. `.claude/rules/shell-script-style.md`

**`## 文字コード` の近く**（`sed`/`awk` のエスケープの罠が既にある場所）へ、次を足す。

> **bash の `${v//a/b}` の置換文字列に `&` を書かない。** bash 5.2 から `&` が
> 「マッチした文字列全体」へ展開される（`patsub_replacement`、既定で有効）。`\&` での退避は
> 5.1 以前と互換でない。**`sed` を使う**（`&` の意味も `\&` での退避も処理系をまたいで定まっている）。

実例（`esc="${esc//</&lt;}"` が `<lt;` になる）と、CI の shell が bash とも限らない点を添える。

### 9・10. `.claude/rules/directory-structure.md` と `index.md`

`.github/workflows/`（GitHub Actions ワークフロー）と `.gitlab-ci.yml`（GitLab CI 設定）を、
それぞれのツリー／Repository Map へ追加する。**どちらも「雛形は
`.claude/skills/issue-mr-flow/assets/` 側にあり、実ファイルとバイト一致する」**ことに触れる
（片方だけ直すと、次に読んだ人がどちらが正か分からない）。

**あわせて、このissueが古くした記述を直す。** `directory-structure.md` 24行目は

```
│   │   ├── issue-mr-flow/assets/  # 計画・レポートのHTMLビューのテンプレート2本（issue #54）
```

だが、フェーズ3で `publish-report-site.github.yml` / `publish-report-site.gitlab.yml` が加わり
**実際は4本**になっている。**「HTMLビューのテンプレート2本＋CI雛形2本」へ直す。**
同ファイル140行付近の `assets/` の実例欄（`issue-mr-flow/assets/reports.template.html` を挙げている）
にも追記が要るかを確認する。`index.md` 側に `.claude/skills/issue-mr-flow/assets/` の行があるかも
確認し、無ければ差が出ないことを flow-id 4-6 の結果レポートへ書く。

### 11. `.claude/VERSION`

`.claude/docs/spec/distribution-assets.md`「`.claude/VERSION`」節は、**更新のタイミングを
flow-id 4-6（AIアセット反映）**、**配布対象アセットに変更があった回だけ**、
**増分はAIが提案し人間が決める**と定めている。

このブランチは分岐点 `318447a` から次を変更しており、**いずれも配布対象**である。

- `.claude/scripts/src/vcs/{Provider,Github,Gitlab}.sh`（関数の追加）
- `.claude/scripts/test/test_vcs_provider.sh`
- `.claude/skills/issue-mr-flow/SKILL.md`
- `.claude/skills/issue-mr-flow/assets/publish-report-site.{github,gitlab}.yml`（**新規**）
- `.claude/skills/apply-mr-workflow-to-project/scripts/sync-assets.sh`

**AIからの提案は MINOR（`0.2.0` → `0.3.0`）**である。配布資産の追加であり、既存の呼び出しを
壊す変更が無いため。**決めるのは人間**で、**据え置きになった場合は
`distribution-assets.md` の changelog へ「据え置いた事実」を残す**（同specの要求）。

## 方針

- **反映先ごとに「正はどこか」を先に決めてから書く**（上記「どこを正にするか」）。同じことを
  2箇所へ書かない。手順は `SKILL.md`、仕組みと判断は `spec`、選定の経緯と却下案は `DDR`、
  コーディング上の罠は `rules`、という切り分けに従う。
- **`## 影響範囲` の既存エントリと DDR の本文は1行も書き換えない。** どちらも point-in-time の
  記録であり、`.claude/rules/docs-workflow.md` が書き換えを禁じている。追記のみ行う。
- **`reports/` の文章をそのまま貼らない。** レポートは「このタスクで何が起きたか」の記録、
  spec は「いま何がどうなっているか」の記述で、時制も主語も違う。

## やらないこと（スコープ外）

- **`.claude/skills/adversarial-review/SKILL.md` の起動ポリシーの恒久化。** 全体作業計画は
  反映候補に挙げているが、**本ブランチでの上書きはユーザーの明示指示による1回限りの判断**で
  あり、恒久ルールにしてよいかは別途合意が要る。**この判断自体を `HANDOFF.md` の
  「判断を迷った内容」へ残し、別issueの候補とする。**
- **`gh-pages` の掃除の仕組み**（残課題として記録済み。別issue候補）。
- **GitLab の Pages 配信・`path_prefix`・`expire_in: never` の実機検証。** 前者はコンテナの
  作り直しが要り、後の2つは Premium/Ultimate 限定である。**spec には「確かめていない」と書く**
  （確かめたかのように書かない）。
- **`main` 由来の既存テスト失敗3件の修正**（全体作業計画でスコープ外と合意済み。内訳は下記「検証」）。

## 検証

```bash
# 1. DDRを足したら一覧を再生成し、差分を同じコミットへ含める
bash .claude/scripts/src/generate-ddr-list.sh

# 2. frontmatterインデックスの再生成（新規DDRが載ることの確認）
bash .claude/scripts/src/extract-frontmatter.sh .

# 3. DDR i0114-01 が1件だけ在ること（0件でも2件以上でも異常）
ls .claude/docs/ddr/ | grep -c '^i0114-'

# 4. ベースとのDDR識別子重複を実データで検出する（flow-id 5-1 が使う本体）
#    hasConflict は worklog 等の追記でも true になるので、DDRの欄だけを見る
bash .claude/scripts/src/check-base-conflicts.sh | jq -c '.duplicateDdrNumbers'

# 5. point-in-time の記録を壊していないこと（削除行がゼロであること）
git diff 318447a -- .claude/docs/ | grep -c '^-[^-]'

# 6. 全テストを流し、着手時点と同じ結果であること
for t in .claude/scripts/test/test_*.sh; do printf '%s: ' "$t"; bash "$t" 2>&1 | tail -1; done
```

**3 と 5 の期待値**: 3 は `1`、5 は `0`。
**5 の範囲を `.claude/docs/` にする理由**: `.claude/` 全体へ広げると、フェーズ3の実装変更
（`.claude/scripts/` 等）の削除行が出て判定できない。

**6 の「着手時点と同じ結果」の定義**（この3本以外はすべて `failures=0`）:

| テスト | 着手時点の結果 | 由来 |
|---|---|---|
| `test_block_direct_git_commit.sh` | `passed=26 failures=1` | `main` 由来（スコープ外） |
| `test_command_position.sh` | `passed=73 failures=2` | `main` 由来（スコープ外） |
| `test_sync_gemini_assets.sh` | **完走しない**（`ln: failed to create symbolic link` で停止） | 環境依存（スコープ外） |

**合格条件**:
(1) DDR `i0114-01` が存在し、frontmatter の `title` / 本文冒頭の見出し / ファイル名の識別子が揃っている（検証3が `1`）、
(2) `.claude/docs/README.md` の DDR 一覧が**生成物として**更新されている（手書きの行が無い）、
(3) 変更対象表 3〜10 の反映が入っている、
(4) **`## 影響範囲` の既存エントリと既存DDRの本文に差分が無い**（検証5が `0`）、
(5) 検証6が上表と一致する、
(6) **`.claude/VERSION` について人間の判断を得ている**（増分を入れた／据え置いた事実が記録されている）、
(7) 敵対的レビュー（フェーズ4）の指摘へ対応・返信済みで、返信ゼロのスレッドが0件。

## 比較検討した案

| 論点 | 採用 | 却下した案と理由 |
|---|---|---|
| DDRの粒度 | **1件（`i0114-01`）にまとめる** | 「手段の選定」と「タイミングの選定」で2件に分ける案。**この2つは独立して決められない**（5-5 で消えるという制約が手段の選択肢を絞り、手段の性質がタイミングの可否を決める）ため、分けると片方だけ読んでも判断が再現できない |
| `SKILL.md` の「CI側の仕組み」 | **spec へ移し、`SKILL.md` はリンクにする** | (i) SKILL.md に残して spec は触れない案——新節が「確かめた範囲」だけの薄い節になり、仕組みの正史が手順書側にある状態が続く。(ii) 両方に書く案——**正が2つになり、片方だけが古くなる**（この計画が「正は1箇所」を方針に掲げている以上、採れない） |
| `index.md` / `directory-structure.md` の扱い | **フェーズ4で反映する** | フェーズ3で直す案。**ディレクトリ構成の記述はAIアセットであり、反映はフェーズ4の担当**という現行の切り分けに従った（フェーズ3で直すと、反映の一覧がどこにも残らない） |
| 敵対的レビューの起動ポリシー | **恒久化しない** | `adversarial-review/SKILL.md` へ例外を書く案。**1ブランチでの運用実績しかない**段階で既定を変えると、次のissueが暗黙にこの運用を引き継ぐ。判断は `HANDOFF.md` へ残して別issueにする |
| `.claude/VERSION` | **MINOR を提案し、人間が決める** | AIが決め打ちで上げる案（specが「人間が決める」と定めている）。触れずに通す案（**提案の機会が消え、配布先が中身の違う `.claude/` を同じ版で受け取る**） |
