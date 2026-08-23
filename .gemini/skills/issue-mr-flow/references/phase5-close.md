---
title: issue-mr-flow 参照: クローズ（関連issue通知〜Draft解除）
type: skill-reference
description: フェーズ5（flow-id 5-2〜5-6）の実行前に開く。マージ前の関連issue通知・`.gemini/` 変換同期・最終統括レポート・PRが先にマージされた場合の対処
tags: [issue-mr-flow, skill-reference, close]
keywords: [関連issue通知, 最終統括レポート, cleanup-task, Draft解除, set_mr_ready, squash merge, 先行マージ]
---

# issue-mr-flow 参照: クローズ（関連issue通知〜Draft解除）

## マージ前の関連issue通知（flow-id 5-2）

片付け（flow-id 5-5）・Draft解除（flow-id 5-6）へ進む前に、**今回のMRが影響する他のissueを特定し、
人間の承認を得てから当該issueへコメントで通知する**（issue #86）。MRがマージされても、その変更で
前提が変わる・一部が解決される・記述が矛盾する他のissueには何も残らず、後続タスクの担当者が影響に
気づけないため。

**影響先が無ければスキップしてよい。** その場合も「影響先なし」と判断したことを `HANDOFF.md` の
「やったこと」へ1行残し、flow-id 5-5 へ進む（判断を省いたのか、判断した結果なしだったのかを
次のセッションが区別できるようにするため）。**このステップが片付け（flow-id 5-5）より前に置かれて
いるのは、この1行の書き戻し先を残すためである**（issue #112。5-5 は `HANDOFF.md` を空テンプレートへ
リセットするため、後に置くと書き戻す先が無くなる）。

### 手順

1. **差分を確認する。** マージされる内容そのものを起点にする（issue本文や計画ファイルではなく、
   実際に何が変わったかを見る）。

   ```bash
   source .claude/scripts/src/vcs/Provider.sh
   base="$(get_workflow_config | jq -r '.defaultBaseBranch')"
   git diff --stat "origin/${base}...HEAD" -- . ':(exclude)plans' ':(exclude)worklog' ':(exclude)reports'
   ```

   **`plans/` `worklog/` `reports/` は差分から除外する**（issue #112）。これらの片付けは
   flow-id 5-5 でこのステップより後に行うため、この時点ではタスク単位の計画・ログ・レポートが
   まだ差分に含まれている。除外しないと、マージ後には残らないファイルの語（個別計画の種別名・
   worklogの見出し等）がキーワード抽出へ混ざり、通知先の判定を歪める。上記のpathspecを付けずに
   `git diff --stat` を見た場合は、これらのパスの行を読み飛ばすこと。

2. **AIエージェントが検索キーワードを抽出する。** 差分（上記のとおり `plans/` `worklog/`
   `reports/` を除いたもの）に現れた機能名・関数名・ファイル名・概念語から、**最大5件**
   （`search_issues` の `SEARCH_ISSUES_MAX_KEYWORDS`）を選ぶ。
   キーワード抽出をこの層でAIが担うのは、`issue-create` スキルの起票前重複チェックと同じ理由
   （日本語主体のissueから意味のある語を選ぶには形態素解析が要り、bashでは代替できない。
   DDR i0068-01）。

3. **候補を検索する。**

   ```bash
   search_issues "<キーワード1>" "<キーワード2>" ...
   ```

   - **closedのissueも候補に含まれる**（`search_issues` の仕様）。closedのissueは通知先として
     不適切なことが多いが、「その決定が今回の変更で覆る」ケースがあるため機械的には除外しない。
   - **今回のissue自身と、そのPR/MRは候補から除く**（自分自身への通知になるため）。

4. **影響の有無と種類を判定する。** 候補ごとに、今回の差分がそのissueへどう効くかを次の3類型で
   分類する。どれにも当てはまらないものは通知しない（関連語が一致しただけのissueへ機械的に
   投稿すると、通知そのものが無視されるようになる）。

   | 類型 | 意味 |
   |---|---|
   | 前提が変わる | そのissueの「現状」の記述が今回の変更で成立しなくなる |
   | 一部が解決される | そのissueの受け入れ条件の一部を今回の変更が満たす |
   | 記述が矛盾する | そのissueの「期待する動作」が今回の変更と衝突する |

5. **`AskUserQuestion` で承認を得る。** **承認なしに外部へ投稿しない**（経緯:
   `.claude/docs/ddr/i0086-01-マージ前の関連issue通知はDraft解除の直前に置き投稿前の人間承認を必須にする.md`）。
   質問には、投稿先のissue番号・タイトル・上表の類型・**投稿する本文そのもの**を含める
   （「投稿してよいか」だけを聞いて本文を見せない形にはしない）。投稿先が複数ある場合は
   `multiSelect: true` で対象を選ばせる。

6. **承認された分だけ投稿する。** 本文は**ファイルへ書き出してから**渡す（コマンド文字列へ
   長文を埋め込むと、地の文に `git` と `push` が連続しただけでpush検知hookが誤発火する。
   `.claude/rules/git-workflow.md`「push検知hookの誤検知」）。

   ```bash
   add_issue_comment <通知先issue番号> /tmp/notify-body.md
   ```

   本文の先頭には、`reply` サブコマンドと同じ **`Claude Codeより:` の署名行**を付ける。CLI・MCPの
   どちらの経路でも人間のアカウントで投稿されるため、誰が書いたかを本文側で明示する必要がある。

### 本文のテンプレート

```markdown
Claude Codeより: PR #<今回のPR番号>（issue #<今回のissue番号>）のマージ前通知です。

## このissueへの影響

<「前提が変わる」「一部が解決される」「記述が矛盾する」のどれかと、その理由を1〜3行で>

## 該当箇所

- `<ファイルパス>`: <何がどう変わったか>

## 参照

- PR: <PRのURL>
- issue: <今回のissueのURL>
```

### `gh`/`glab` CLI不在時

`add_issue_comment` は `mcp__github__add_issue_comment`（`owner`, `repo`,
`issue_number=<通知先のissue番号>`, `body=<ファイルの内容>`）へ読み替える（`references/mcp-fallback.md`
「`gh`/`glab` CLI不在時のMCPフォールバック」節の対応表）。**`add_mr_comment` と同じツールだが、
`issue_number` へ渡すのがPR番号ではなく通知先のissue番号である**点に注意する。候補の検索側
（`search_issues`）も同じ表に従って `mcp__github__search_issues` へ読み替える。

## `.claude/` → `.gemini/` の変換同期（flow-id 5-3）

統括レポート（flow-id 5-4）へ進む前に、**`.claude/` の変更を `.gemini/` へ反映する**（issue #70）。

```bash
bash .claude/scripts/src/sync-gemini-assets.sh
```

`.gemini/` は手書きの実体ではなく、**`.claude/` から機械的に決まる変換生成物**である
（agentsのfrontmatterと `settings.json` は Gemini CLI の記法へ変換し、残りはコピーする。除外するのは
生成物とローカル状態だけ）。**`.gemini/` 側を直接編集しない**——次の同期で上書きされる。

### なぜフェーズ5に1回置くのか（毎コミットではなく）

このフローでは `.claude/` の編集とコミットが何度も繰り返される。同期をコミットのたびに強制すると、
**`.claude/` を編集した直後は必ず食い違う**ため通常の作業が止まる。一方でどこにも置かないと、
`.gemini/` が古いまま `main` へ入る。**フェーズ5に1回だけ置く**のがこの折衷である。

### なぜ 5-3 なのか（5-2 と 5-4 の間）

- **5-4（統括レポート）より前**である必要がある。5-4 は自前でcommit・pushまで行うため、
  **同期で生えた `.gemini/**` の差分はそのcommitに載る**。このステップ自身はcommitを持たない。
- **5-1（コンフリクト解消）より後**である必要がある。5-1 でdefaultブランチから入った `.claude/`
  の変更も、同じ同期で拾えるようにするため。
- 5-5（片付け）より前でもある。片付けは `index.jsonl` を再生成するので、`.gemini/` の状態が
  確定していたほうがよい（`extract-frontmatter.sh` は `.gemini/` を走査対象から除外している）。

### 確認

食い違いの有無だけを見たい場合は `--check` を使う（生成せず、非0で終了する）。
**このフロー上、`--check` はどのhookにも自動では挿さっていない**（挿すと上記の「作業が止まる」
問題が戻るため）。**このステップを飛ばすと食い違いに気づけない**が、それは `HANDOFF.md` の
進捗表がこの行を持つことで担保する。

```bash
bash .claude/scripts/src/sync-gemini-assets.sh --check    # 一致=0 / 不一致=非0
bash .claude/scripts/src/sync-gemini-assets.sh --dry-run  # 何が変わるかだけ出す
```

**`jq` が無い環境では非0で終了する**（インストール方法を出す）。`jq` は `.gemini/` だけでなく
`.claude/` 機構全体の前提のため、生成だけを諦めて先へ進む形は採らない。

## 最終統括レポートとPR/MRへの反映（flow-id 5-4）

片付け（flow-id 5-5）へ進む前に、**そのブランチで何をやったかを1枚にまとめた最終統括レポートを
作成し、PR/MR上へ残す**（issue #111）。

`plans/` `worklog/` `reports/` は flow-id 5-5 で削除され、squash mergeにより `main` にも残らない。
統括をPR/MR上のコメントとして残すことで、**ファイルが消えてもレビュー時・マージ後の追跡に耐える**
状態にする。

### なぜ 5-4 なのか（5-3 と 5-5 の間）

- **5-5（片付け）より前**である必要がある。統括レポートは `plans/` `worklog/` `reports/` の内容を
  materialにして書くため、削除後には書けない。
- **このステップ自身がcommit・pushまでを含む**。統括レポートを作るだけで 5-5 へ進むと、
  作成と削除が同じ作業ツリー上で相殺され、**ブランチのコミット履歴にすら残らない**
  （層1が成立しなくなる）。5-5 と同じく複合ステップにしてあるのはこのためである。
- 5-1（コンフリクト解消）より後である必要もある。5-1 は作業ツリーがきれいなうちに `git merge` を
  走らせるステップで、その前にファイルを作ると解消結果と混ざる（flow-id 5-1 の節を参照）。

### 成果物

| ファイル | 位置づけ | 必須か |
|---|---|---|
| `reports/日付_<全体計画名>_統括.md` | **正文** | **必須** |
| `reports/日付_<全体計画名>_統括.html` | 人間レビュー用の視覚化 | 任意（下記） |

内容は「**何を変えたか／なぜそうしたか／検証結果／spec・ddrへの反映先／残課題**」。
個別の `reports/…md`（flow-id 2-6・3-6・4-6 の結果）を並べ直すのではなく、**ブランチ全体を
1枚に統括する**。

HTMLは `.claude/skills/issue-mr-flow/assets/reports.template.html` を土台にする
（`.claude/skills/canvas-report/SKILL.md` の判断基準は統括レポートにも当てはまる）。
使い方は `references/deliverables.md`「計画・レポートのHTMLビュー」が正である。

**統括レポートも flow-id 5-5 の削除対象である**（md・htmlの両方）。`cleanup-task.sh` は
`reports/` 配下を `REVIEW-POINTS.md` 以外すべて削除するため、スクリプト側の変更は要らない。
`main` に残るのは**PR/MR上のコメント**と `.claude/docs/spec/` `.claude/docs/ddr/` である。

### 反映は3層のフォールバック構造にする

**層3が壊れても層1・層2でレビューが成立する**ことが、この構造の要点である
（`.claude/docs/ddr/i0111-01-統括レポートの添付は任意層に置きフローを止めない.md`）。

| 層 | 何をするか | 必須か | 壊れたとき |
|---|---|---|---|
| **層1** | レポート本体を `reports/` に載せ、`commit` スキル経由でcommitしてリモートへ反映する | **必須** | — |
| **層2** | サマリをMarkdownでPR/MRへコメント投稿する（`add_mr_comment`） | **必須** | — |
| **層3** | HTMLファイルを添付する（`upload_attachment`） | **任意** | **警告のみ出してスキップし、フローは止めない** |

- **層1** はレビュアーがブランチをcheckoutすれば見られる状態にすること。squash mergeにより
  `main` には残らないが、**PRのコミット一覧からは辿れる**。
- **層2** が「ファイルが消えても残る」を担う実体である。GitHub/GitLabのどちらでも `add_mr_comment`
  で確実に動く（公式APIのみ）。
- **層3 は外部依存が最も弱い。** GitHubは未ドキュメントの内部エンドポイントに依存し、GitLabは
  公式APIだが実機未検証である。**加えて、`gh`/`glab` CLIが無い実行環境（Claude Code on the web）
  では、MCPに添付相当のツールが無いため必ず失敗する**（issue #111 の調査で実測）。

#### 層の番号は「フォールバックの優先順位」であって、実行順ではない

**実行順は 層1 → 層3 → 層2 である。**

```
レポート作成 → 層1（commit・push）→ 層3（添付を試す・任意）→ 層2（サマリを1回投稿）
```

**層3を層2より先に実行するのは、添付リンクをサマリ本文へ入れて1回で投稿するためである。**
`Provider.sh` には**投稿済みコメントを編集する関数が無い**（あるのは `add_mr_comment` /
`add_issue_comment` / `set_mr_description` で、いずれも新規投稿か description の上書き）。
層2を先に投稿してしまうと、添付リンクを後から本文へ足す手段が無く、コメントを2回投稿するか
CLIを直接叩くかの場当たり対応になる。

**層3が失敗しても層2は必ず実行する。** 添付リンクの行が本文から落ちるだけで、他は変わらない。

#### 層3の呼び出し方

```bash
source .claude/scripts/src/vcs/Provider.sh

# 層3（任意）。失敗しても続ける
attachment_md=""
if result="$(upload_attachment "reports/20260821_xxx_統括.html")"; then
  attachment_md="$(printf '%s' "$result" | jq -r '.markdown')"
else
  echo "添付をスキップしました（任意ステップ。層1・層2でレビューは成立する）" >&2
fi

# 層2（必須）。添付できたときだけ末尾へ1行足し、本文をファイルへ書き出してから投稿する
[ -z "$attachment_md" ] || printf '\n添付: %s\n' "$attachment_md" >> /tmp/summary.md
add_mr_comment "$mr_number" /tmp/summary.md
```

**成功を前提にした分岐を書かないこと。** 添付できたかどうかでサマリコメントの本質的な内容が
変わってはいけない（添付は「あれば便利」であって、レビューに必要な情報の置き場ではない）。
**変わってよいのは末尾の1行だけである。**

### サマリコメントの本文

**本文の1行目は `Claude Codeより（最終統括レポート）:` とする。** 括弧付きの種別ラベルは
敵対的レビューのインラインコメント（`Claude Codeより（敵対的レビュー）:`）と同じ形である。

```markdown
Claude Codeより（最終統括レポート）: issue #<番号> / PR #<番号>

## 何を変えたか

- <変更の要点。ファイル単位ではなく、振る舞い・ルールの単位で書く>

## なぜそうしたか

- <採用した案と、却下した案。詳細はDDRへのリンクで示す>

## 検証結果

- <実行したコマンドと結果。テストの `passed=N failures=N` を含める>

## spec・DDRへの反映先

- `.claude/docs/spec/<ファイル>`: <何を書いたか>
- `.claude/docs/ddr/<識別子>-<タイトル>.md`: <何を決めたか>

## 残課題

- <このPRで対応しなかったこと・別issueへ切り出したこと。無ければ「なし」>
```

- **本文はファイルへ書き出してから `add_mr_comment <n> <ファイル>` へ渡す。**
  コマンド文字列へ長文を埋め込むと、地の文に `git` と `push` が連続しただけでpush検知hookが
  誤発火する（`.claude/rules/git-workflow.md`「push検知hookの誤検知」）。
- 層3が成功した場合は、`upload_attachment` が返した `markdown` を本文の末尾へ添える。
  **層3は層2より先に実行する**（上記「層の番号は『フォールバックの優先順位』であって、実行順では
  ない」）。投稿済みコメントを編集する手段が無いため、投稿は1回で完結させる。

### PR/MRの通常コメントの種別（issue #111）

`add_mr_comment` で投稿される**通常コメント**（レビュースレッドではないもの）は4種類ある。
いずれも投稿者アカウントは人間のものとして表示されるため、**種別は本文の1行目で判別する**。

| 種別 | 本文1行目 | いつ |
|---|---|---|
| チャットで受けたレビュー判断の記録 | `Claude Codeより: チャットで受けたレビュー判断の記録（…）` | レビュー往復ごと（`comments` 手順6） |
| スレッドを持たない指摘への対応記録 | `Claude Codeより:` | レビュー往復ごと（`comments` 手順4） |
| 対応工数レポート | `Claude Codeより: 自動投稿（post-push-usage-report.sh …）` | pushごと（hookが自動投稿） |
| **最終統括レポートのサマリ** | **`Claude Codeより（最終統括レポート）:`** | **flow-id 5-4（ブランチにつき1回）** |

**既存3種の1行目は変更しない。** 統括レポートだけが括弧付きラベルを持てば、読み手は
「これは統括レポートか、それ以外か」を1行目で判別できる。全種の書式を揃え直すと、`SKILL.md` の
複数箇所・spec・既に投稿済みのコメントへ波及する一方、得られるのは表記の統一だけである。

### `gh`/`glab` CLI不在時

| 層 | MCP経路での扱い |
|---|---|
| 層1 | 変更なし（git操作のみ） |
| 層2 | `add_mr_comment` を `mcp__github__add_issue_comment`（`issue_number=<PR番号>`）へ読み替える |
| 層3 | **対応するMCPツールが無いためスキップする。** `upload_attachment` は `require_vcs_cli` により非0で終え、stderrへ「スキップしてよい」旨を出す |

**層3のスキップは異常ではない。** レポート本体（層1）とサマリコメント（層2）が揃っていれば、
このステップは完了である。

## PRがflow-id 5-5実施前にマージされてしまった場合の対処

人間がレビュー後にそのままMR/PRをマージするなど、flow-id 5-5（`plans/` `worklog/` `reports/`の
削除・`HANDOFF.md`のリセット）を実施する前に**先にマージが完了してしまう**ことがある（issue #28,
PR #29のセッションで実際に発生）。この場合、タスク固有の`plans/`配下の計画ファイル（全体作業計画・
下位の個別計画）・`worklog/`・`reports/`のファイル・作業途中のままの`HANDOFF.md`が、そのまま
`main`へ残ってしまう（本来`worklog/`・`reports/`はsquash mergeの対象からflow-id 5-5で除外され
`main`に残らない設計であり、このズレはdocs-workflow.mdの運用と矛盾する）。

マージ後にこのズレに気づいた場合、**`main`へ直接コミットせず**、以下の手順で対処する
（`main`は共有の正史であり、レビューを経ないままの直接変更は避ける）。

1. `git fetch origin main` 等で最新の`main`を確認し、残ってしまった`plans/`・`worklog/`・
   `reports/`ファイル・`HANDOFF.md`の状態を特定する。
2. 新しいクリーンアップ用ブランチを`main`から作成する（対象のissue番号が無いことが多いため、
   `.mrworkflow.json`の`branchPrefixTemplate`に従う必要はなく、`chore/cleanup-<簡潔な説明>`の
   ような分かりやすい名前でよい）。
3. そのブランチ上で、該当する`plans/`・`worklog/`・`reports/`ファイルを削除し、`HANDOFF.md`を
   次タスク向けの空テンプレートへリセットする（内容はflow-id 5-5で行うものと同じ）。
4. commit・pushし、`main`を対象にPRを作成する。**PRの作成は他のPR操作と同様AIエージェントが
   行ってよく、都度の明示指示は要らない**。**マージのみ**、ユーザーから明示的な指示を受けてから
   実行する（`.claude/skills/issue-mr-flow/SKILL.md`「PR/MR作成・マージの担当」節、`.claude/rules/git-workflow.md`「PR・マージ」節）。
