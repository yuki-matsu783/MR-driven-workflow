---
title: 敵対的レビュー
type: spec
description: 独立コンテキストの専任サブエージェントが意図的に欠陥を探し、指摘をMRへインラインコメントとして投稿する敵対的レビュー機構の仕様
tags: [adversarial-review, review, issue-mr-flow, spec]
keywords: [敵対的レビュー, インラインコメント, findings, 実施回数, REVIEW-POINTS, 有効行, new_line, old_line, 確度, 重大度, スレッド, discussions, サマリ]
---

# 敵対的レビュー

対象: `.claude/skills/adversarial-review/SKILL.md`, `.claude/skills/review-points/SKILL.md`,
`.claude/agents/adversarial-reviewer.md`, `.claude/scripts/src/adversarial-review-count.sh`,
`.claude/scripts/src/collect-review-points.sh`, `.claude/scripts/src/select-adversarial-findings.sh`,
`.claude/scripts/src/vcs/`（`add_mr_inline_comments` とプロバイダ実装）,
各ディレクトリの `REVIEW-POINTS.md`

## 背景・目的

issue #77。実装・計画・設計反映の各レビュー（flow-id 2-3/2-8/3-3/3-8/4-3/4-8）は、人間の負荷に
全面的に依存している。一方でAIエージェント自身の確認は、**自分が書いたものを追認する方向へ働き
やすく**、独立した検証にならない。

組み込みの `/code-review` は汎用のバグ探しであり、このリポジトリ固有の落とし穴
（`wip/plans/` の粒度、spec/DDR/rules の二重管理、point-in-time記録の破壊、DDR番号の衝突、
shellの既知の罠）は対象外である。本issue以前、このリポジトリにはレビューを担うスキルも
サブエージェントも存在しなかった（`.claude/agents/` は読み取り専用の `issue-mr-resume` のみ）。

そこで、**独立コンテキストの専任サブエージェントが意図的に穴を探す「敵対的レビュー」**を機構化し、
指摘をMRへインラインコメントとして投稿できるようにした。人間のレビューを置き換えるものではなく、
その**前**に挟む任意の補助である。

## 仕様

### 全体像（責務分離）

```
人間 → /adversarial-review（スキル）
          ├ 手順1 実施回数の上限確認（adversarial-review-count.sh）
          ├ 手順2 対象の判別と観点表の収集（collect-review-points.sh）
          ├ 手順3 投稿可否の確認（AskUserQuestion、1回だけ）
          ├ 手順4 サブエージェント起動 ─→ adversarial-reviewer（読み取り専用）
          │                                 └ findings JSON を返すだけ
          ├ 手順5 実施回数の加算
          ├ 手順6 確度×重大度で投稿／報告を振り分け
          ├ 手順7 add_mr_inline_comments（Provider.sh）で投稿
          ├ 手順8 未返信スレッド数の記録（update-handoff-progress.sh set-header --unreplied）
          └ 手順9 報告
```

**サブエージェントは投稿しない。** 投稿は呼び出し元（スキル）の責務とし、承認の所在を1箇所へ
寄せている。サブエージェントには `Read, Grep, Glob, Bash` しか与えず、Write/Editを持たせない。

**サブエージェントへ「なぜそう実装したか」の経緯を渡さない。** 渡すのはレビュー対象（diffまたは
ファイルパス一覧）・マージ済みの観点表・フェーズ番号の3つだけである。経緯を渡すと実装者の文脈に
引きずられ、追認するレビューになる。サブエージェント側から観点表を探しに行かせないのも同じ理由で、
対象範囲の判断を呼び出し元へ集約している。`git log` 等でコミットメッセージや過去の議論を読むことも
禁じている。

モデルは `model: opus`。浅い確認では敵対的レビューにならないため、`issue-mr-resume` の `sonnet` とは
役割が異なる。

### 全体フローにおける位置づけ

**`issue-mr-flow` の全体フロー表には含まれない。** flow-idを持たず、
commit・pushの直後（flow-id 2-2/2-7/3-2/3-7/4-2/4-7）から人間のレビュー（2-3/2-8/3-3/3-8/4-3/4-8）
までの間に挟む任意の手順として位置づける。実施しても `HANDOFF.md` の進捗表は動かさず、実施した
事実は「やったこと」へ文章で残す。

### 起動ポリシー

| 実行モード | 判定 | AIエージェントからの自律起動 |
|---|---|---|
| 非対話モード | 人間のレビュー往復が成立しない実行環境 | **許す** |
| 対話モード | 上記以外、または判断に迷う場合 | **禁止**。人間が `/adversarial-review` を呼んだときだけ実行する |

非対話かどうかは環境変数ではなく、**AIエージェント自身が実行環境の性質（人間とのレビュー往復が
成立するか）から判断する。** 判断はスキル本文の起動ポリシー（他のどの手順よりも先に適用される）
として扱う。

判断に迷う場合は対話モード（起動禁止）を既定とする。判定を誤ったときに「勝手に動く」側では
なく「動かない」側へ倒れるようにするためである。

対話モードで自律起動を禁じるのは、**レビューの主体が人間であるという前提を崩さないため**である。
AIが自分で書いて自分でレビューを起動し自分で直すと、人間がレビューする対象が「AIが既に納得した
もの」になり、レビューの独立性が失われる。AIから「敵対的レビューを実施しましょうか」と持ちかける
ことは構わないが、返事を待たずに実行してはならない。

### 実施回数の上限

非対話モードでは「レビュー → 修正 → 再レビュー」が人間の介在なく回りうるため、実施回数を
**各フェーズ最大3回**で機械的に打ち切る。AIエージェントの自制ではなくスクリプトで強制する。

```bash
bash .claude/scripts/src/adversarial-review-count.sh get <phase>        # 残回数の確認
bash .claude/scripts/src/adversarial-review-count.sh increment <phase>  # 加算（上限なら終了コード1）
bash .claude/scripts/src/adversarial-review-count.sh reset              # 人間の判断でのみ実行
```

- `<phase>` は issue-mr-flow のフェーズ番号（2/3/4）。
- 状態は `wip/state/adversarial-review/<ブランチ名>.json` に `{"2":N,"3":N,"4":N}` で持つ。
  ブランチ名の `/` は `__` へ置換する。`wip/state/` は `.gitignore` 対象のローカル作業状態で、
  ブランチ単位のため、ブランチを削除すれば自然に消える（`usage/` とは責務が異なるため混ぜない）。
  **issue #184 以前は `.claude/state/adversarial-review/` だった**（`.claude/` を配布資産だけに
  するため `wip/` 配下へ移した。DDR `i0184-01`）。
- **加算は「レビュー実行の直後・投稿の前」に、投稿の成否に関わらず行う**（失敗を口実に無限
  リトライできないようにするため）。
- 状態ファイルが空・壊れたJSONの場合は「状態なし」（`{}`）へフォールバックする。空文字列の判定を
  `jq -e .` より先に行うのは、空入力に対して `jq -e .` が終了コード0を返すことがあるため
  （`.claude/rules/shell-script-style.md`）。
- **上限を環境変数等で緩める口は用意しない。** 緩められる上限は上限ではないため。

### レビュー観点（REVIEW-POINTS.md）

**観点はスキル本文にもサブエージェント定義にも書かない。** 各ディレクトリ直下に置いた
`REVIEW-POINTS.md`（frontmatterの `type: review-points`）が持つ。

- **1つの `REVIEW-POINTS.md` は、そのディレクトリ配下すべて（孫以下を含む）に適用される。**
- 収集は、レビュー対象ファイルのあるディレクトリからリポジトリルートまで**祖先を遡って**行い、
  1つへマージする。
- 出力順は**浅い → 深い**（一般 → 具体）。由来が分かるよう `## <観点表のパス>` の見出しを挟む。
- 複数ファイルを渡した場合は各祖先チェーンの**和集合**を取り、同じ観点表は1回だけ出力する。
  そのため**対象ファイルは1回の呼び出しへまとめて渡す**。
- パス解決は `..` を打ち消す形で行い、**リポジトリルートより上へは決して出ない**。
- 観点表が1つも見つからない場合は、何も出力せず終了コード0で終わる（観点表が無くてもレビュー
  自体は一般的な観点で行えるため、エラーにしない）。その事実は手順9で報告する。

```bash
bash .claude/scripts/src/collect-review-points.sh <対象ファイルパス...>
```

現在の配置は `REVIEW-POINTS.md`（リポジトリ全体）・`.claude/REVIEW-POINTS.md`・
`wip/plans/REVIEW-POINTS.md`・`wip/reports/REVIEW-POINTS.md` の4つ。
単独でも使えるよう `review-points` スキル（`.claude/skills/review-points/SKILL.md`）として
切り出しており、人間のレビュー・`/code-review` の補助にも使える。

### レビュー対象の判別

現在のflow-idから自動判別する。曖昧なら `AskUserQuestion` で選ばせる（非対話モードでは既定として
「diff全体」を採る）。削除されたファイルは対象から外す。

| 対象 | 判別 | ファイルの列挙 |
|---|---|---|
| diff全体 | flow-id 3-7 / 4-7 の直後 | `git diff --name-only origin/<base>...HEAD` |
| `wip/plans/` の個別計画 | flow-id 2-2 / 3-2 / 4-2 の直後 | 該当する `wip/plans/【*.md` |
| 設計反映 | flow-id 4-7 の直後 | `.claude/docs/spec/` `.claude/docs/ddr/` `.claude/rules/` の変更ファイル |

### findings JSONスキーマ

サブエージェントは findings JSON **だけ**を返す（散文の講評・要約は返さない）。指摘が0件なら
`{"findings":[]}` を返すのが正しい結果であり、水増しのために `nit` を並べてはならない。

```json
{"findings":[
  {"path":".claude/scripts/src/x.sh","line":42,"side":"RIGHT",
   "severity":"major","confidence":"high","category":"shell-pitfall",
   "title":"ループ内でjqを起動している","body":"..."}
]}
```

| キー | 必須 | 内容 |
|---|---|---|
| `path` | 必須 | リポジトリルートからの相対パス |
| `line` | 任意 | 新ファイル側の行番号。**ファイル全体にかかる指摘では省略する** |
| `old_line` / `old_path` | 任意 | 旧ファイル側の行番号・パス |
| `side` | 任意 | 既定は `RIGHT` |
| `severity` | 必須 | `blocker` / `major` / `minor` / `nit` |
| `confidence` | 必須 | `high` / `medium` / `low` |
| `category` | 必須 | 指摘の種類を表す短いkebab-caseの語（例: `shell-pitfall` `doc-inconsistency`） |
| `title` | 必須 | 1行の要約 |
| `body` | 必須 | 何が問題か・どういう入力/状況で壊れるか・どう直すか の3点 |

サブエージェントは各指摘について**反証を1回試みる**ことを求められる。これを行わないと確度の
自己申告が意味を失うため。

### 投稿／報告の振り分け

まず**確度（`confidence`）と重大度（`severity`）**の表で1次振り分けを行う。

| 確度 \ 重大度 | blocker | major | minor | nit |
|---|---|---|---|---|
| high | 投稿候補 | 投稿候補 | 投稿候補 | 報告 |
| medium | 投稿候補 | 投稿候補 | 報告 | 報告 |
| low | 報告 | 報告 | 報告 | 報告 |

- **投稿候補** = 次の「投稿件数の選別」（下記）へ進む。**報告** = 会話（非対話モードでは
  wip/worklogs）にのみ書き、MRへは出さない。
- **この1次振り分け自体は変更していない**（issue #182）。「技術的に投稿可能か」（有効行かどうか）
  はコードの責務だが、「人間に見せる価値があるか」は判断であり、運用しながら調整できる場所に
  置くほうがよいという判断は維持している。

### 投稿件数の選別（issue #182）

1次振り分けを通過した「投稿候補」findingsのうち、実際に何件投稿するかは
`.claude/scripts/src/select-adversarial-findings.sh` が**決定的に**選別する。

```bash
bash .claude/scripts/src/select-adversarial-findings.sh <投稿候補findings JSONファイル>
# → {"posted":{"findings":[...]},"reported":{"findings":[...]}}
```

選別規則（層単位ルール・blocker無制限・ハードシーリング20件）:

1. **blocker は全件投稿する。** 「投稿するかどうか」自体は上限の対象外で、blocker が単独で
   20件を超える場合も全件投稿し、その場合は下位層（major・minor）を追加しない。
2. **blocker より下の層（major → minor）は、重大度の高い順に「層単位」で追加する。** 層の
   途中では切らない。累計が10件（層追加のしきい値）に達した時点で、それより下の層は追加しない。
   - 例: blocker 1件 + major 13件 + minor 5件 → blocker + majorの14件を投稿し、minorは
     累計14 ≥ 10のため追加しない。
3. **絶対上限（ハードシーリング）は20件。** 層を丸ごと追加すると累計が20件を超える場合に限り、
   その層内を**確度の降順（high→medium→low）→パスの昇順→行番号の昇順**の決定的な順序で
   20件まで切る。**blockerの件数自体はこの20件の枠を消費する**（例: blocker 9件 + major
   15件 → 20-9=11件までしかmajorは入らず、残り4件はreportedへ回る）。上記1.の
   「対象外」は打ち切り判定（2.でblockerが減らされることはない）を指し、消費した枠まで
   対象外になるわけではない。
4. **この選別で漏れたfindings**（層追加のしきい値・ハードシーリングで切られたもの）が
   出力の `reported.findings` に入る。**1次振り分けで「報告」に区分したfindingsは、
   そもそもこのスクリプトへ渡していない**ため `reported.findings` には含まれない
   （呼び出し側で両者を合わせて報告する。`adversarial-review/SKILL.md` 手順6・手順9）。

- **findingsは必ずファイル経由でjqへ渡す**（jqの引数長上限を避けるため。
  `.claude/rules/shell-script-style.md`「JSON操作」）。jqの起動は選別1回につき1回に集約している
  （層ごとの処理は `reduce` でまとめて1つのjqプログラム内に書く）。
- 単体テストは `.claude/scripts/test/test_select_adversarial_findings.sh` を正とする（本節へ
  ケース一覧を再掲しない。テストを追加してもこの節が古くならないようにするため）。
- **旧規則（1回あたりの投稿上限は固定10件・超過時は重大度の高い順に10件へ絞る）は廃止した。**
  同一重大度内でどれを落とすかのタイブレークが未定義でAIエージェントの裁量になっていたため
  （詳細・却下案: `.claude/docs/ddr/i0182-01-敵対的レビューの投稿件数選別を層単位ルールでスクリプト化する.md`）。

### 承認モデル

投稿の可否は、レビューを実行する**前**に `AskUserQuestion` で**1回だけ**確認する。承認後は指摘
ごとの個別承認を求めない。GitHubの提出済みレビューは削除できないため、「投稿してから取り消す」
前提の設計にできないからこそ、承認を投稿前の1点へ集約している。

非対話モードでは確認できないため、既定は「報告するだけ」ではなく**「投稿する」**とする
（非対話環境では会話への報告が誰にも読まれないため）。

### 投稿インターフェイス

```bash
source .claude/scripts/src/vcs/Provider.sh
add_mr_inline_comments <MR番号> <findings JSONファイル>   # → {"posted":N,"summarized":M}
```

既存の `add_mr_thread_reply` / `add_mr_comment` と同じディスパッチ形式で、
`github_add_mr_inline_comments` / `gitlab_add_mr_inline_comments` へ振り分ける。

**findingsは必ずファイル経由で渡す。** jqの引数長上限（`jq: Argument list too long`）と、
コマンド文字列へのhook誤検知語の混入の両方を避けるため（`.claude/rules/shell-script-style.md`）。

`summarized` は、対象がdiffに含まれず行を指定できなかったためサマリへ回った件数。サマリの出し方は
プロバイダで異なり、GitHubは**レビュー本文**へ載せ、GitLabは**別コメント**として投稿する
（指摘を含むならスレッドとして。後述「インライン以外のコメントもスレッドで投稿する」）。

### GitHubの投稿

`gh api repos/{owner}/{repo}/pulls/<n>/reviews` に `event=COMMENT` と `comments[]` を渡す形で、
**複数の指摘を1回のレビューにまとめて**投稿する（レビュアーへの通知が1回で済む）。

- **投稿はアトミックである。** 1件でも不正な行を指定すると、レビュー全体が422で失敗する。
  そのため投稿前に有効行を検証し、範囲外の指摘をサマリへ振り分ける。
- **有効行は `pulls/<n>/files` の `.patch` のhunkヘッダから求める。** `@@ -a,b +c,d @@` の
  `+c,d` が新ファイル側の範囲で、コメントを付けられるのはこの範囲内の行（追加行・コンテキスト行）
  に限られる。`d` を省略した `@@ -a,b +c @@` は1行を意味し、純粋な削除hunk（`d` が0）は新ファイル
  側に行を持たないため除外する。
- **行を1つずつ列挙せず「範囲」（`[開始, 終了]`）で保持する。** jqへ渡すデータ量を差分の大きさ
  ではなく hunk 数に比例させるため。
- **`line` 未指定のfinding（ファイル全体にかかる指摘）は、そのファイルの有効行の最小値へ寄せる。**
  新規追加ファイルはhunkが `@@ -0,0 +1,N @@` になるため、これは1行目に一致する。
- 有効行を持たないファイル（diffに現れない・`patch` が省略された）の指摘はサマリへ回る。
  これは特別扱いのコードではなく、有効行が空であることから自動的にそうなる。
- **提出済みのレビューは削除できない**（個々のコメントは削除できる）。

### GitLabの投稿

`projects/:id/merge_requests/<iid>/discussions` へ、finding 1件につき1回POSTする。

- `position` の必須項目（`base_sha` / `start_sha` / `head_sha` / `position_type` / `old_path` /
  `new_path`）は、MR JSONの **`diff_refs`** だけで揃う。`old_path` / `new_path` はGitLabが常に
  要求するため、片方しか無い場合は同じ値で埋める。
- **`-H "Content-Type: application/json"` を明示的に付ける必要がある**（`--input` だけでは
  足りない）。
- **行の種類ごとに、指定するキーが決まっている。**

  | 指摘したい行 | 指定するキー |
  |---|---|
  | 追加行（diffの `+`） | `new_line` のみ |
  | 削除行（diffの `-`） | `old_line` のみ |
  | 変更のない行（コンテキスト行） | `new_line` と `old_line` の**両方** |
  | ファイル全体 | どちらも指定しない |

  違反すると `400 Bad request - Note {:line_code=>["must be a valid line code"]}` となり、
  その指摘だけが投稿されずサマリへ回る。
- **MR作成直後は `diff_refs` が `null` のことがある**（実機確認）。1回だけ待って再取得し、
  それでも取れなければ終了コード1で失敗する。
- 1件ごとにHTTPリクエストが発生する経路のため、findingごとに `jq` を起動しても起動コストは
  無視できる（`.claude/rules/shell-script-style.md`「外部プロセス起動のコスト」は、ファイル数に
  比例して外部コマンドを起動するホットパスを対象とした指針である）。
- GitHubと違い**まとめ役のレビュー本文が存在しない**ため、投稿できなかった指摘のサマリは
  別の1コメントとして投稿する。**このサマリが指摘を1件でも含む場合は、単発noteではなく
  `discussions`（スレッド）で投稿する**（下記）。

#### インライン以外のコメントもスレッドで投稿する（issue #121）

サマリの投稿先は `gitlab_summary_post_kind` が件数から決める（`thread` / `note`）。

| サマリに含まれる指摘 | 投稿先 | 理由 |
|---|---|---|
| 1件以上 | `discussions`（`gitlab_add_mr_thread`） | インラインの指摘と同じく**対応を求める内容**であり、レビュアーが解決でき、`add_mr_thread_reply` で返信できる形にする必要がある |
| 0件 | `notes`（`gitlab_add_mr_comment`） | 本文が「すべての指摘をインラインコメントで示しています」という通知でしかなく、スレッドにすると誰も解決しないまま未解決一覧に残り続ける |

`notes` APIで作ったnoteはGitLab上で `individual_note: true` / `resolvable: false` になる。
`gitlab_normalize_discussions`（issue #43 以前は `gitlab_format_discussion_notes`）は
**resolvable でないnoteを常に「未解決」として出力する**ため
（解決しようが無いので当然そうなる）、対応を求めるコメントを単発noteで投稿すると、対応済みに
なっても `comments` サブコマンドの未解決一覧に残り続け、レビュー往復の完了判定を濁す。
`discussions` APIで投稿すればレビュアーが解決でき、この問題が起きない。

以下は採らなかった。

- **サマリの指摘を1件ずつ別スレッドにする。** 解決の粒度は細かくなるが、`posted`（インラインで
  示せた件数）と `summarized`（示せずサマリへ回った件数）という戻り値の意味が曖昧になる。
  行を指定できなかった指摘は、そもそもレビュアーが「どこの話か」を本文から読み取る必要があり、
  1つのスレッドにまとめて示すほうが読みやすい。
- **`gitlab_add_mr_comment` 自体を `discussions` へ切り替える。** 同関数は対応工数レポート
  （`post-push-usage-report.sh`）も使っており、そちらは**対応を求めない通知**である。
  スレッド化すると上記と同じ理由で未解決一覧を汚す。用途が違うため関数を分けた。

GitHub側は、インラインで示せなかった指摘を**レビュー本文**へ載せる形が既にまとめ役として
機能しているため変更しない（GitLabにその受け皿が無いことが、この分岐の出発点である）。

### AIの署名

インラインコメント本文の先頭に `Claude Codeより（敵対的レビュー）:` を付ける。`gh`/`glab` CLIは
人間のアカウントで認証されているため、投稿者名では誰が書いたか判別できない。これは
`issue-mr-flow/references/review-loop.md` の `reply` サブコマンド手順2が返信本文へ `Claude Codeより:` を必須と
しているのと同じ理由である。

**GitLabでは特に重要**で、1件ずつ独立したdiscussionになりまとめ役のレビュー本文が存在しないため、
署名が無いと人間の指摘と区別できない。

### 投稿されたスレッドの取得

投稿したスレッドは、既存の `comments` サブコマンド（`get_mr_unresolved_comments`）から
`unresolved` として位置つきで取得できる。

```
[review unresolved threadId=PRRT_... .claude/scripts/src/vcs/Gitlab.sh:117] ...
```

GitLab側も同様に、`position` を持つnoteは `path:line` を出力する（削除行への指摘は `new_line` が
無く `old_line` のみを持つため `old_path:old_line` を使う）。**敵対的レビューのために新しい取得
経路を作る必要はない。**

issue #43 以降、この行に続けて**指摘行前後のソーススライス（絶対行番号付き）**が
スレッドにつき1回添えられる（`.claude/docs/spec/issue-mr-workflow.md`
「レビューコメントのソーススライス」）。敵対的レビューが投稿したスレッドも例外ではなく、
指摘した箇所のコードを再取得せずに読めるようになる。

**取得したスレッドへの対応と返信は、本機構ではなく `issue-mr-flow` の `comments` / `reply`
ループ（flow-id 2-4/2-9/3-4/3-9/4-4/4-9）が担う**（issue #109）。取得経路を共有しているのと
同じ理由で、返信のルールも人間の指摘と共通である。

- **AI自身が投稿した指摘であることは、返信を省いてよい理由にならない。** 返信の無いスレッドは、
  人間のレビュアーから見て「未対応」と区別が付かない。指摘を直したこと自体はコードの差分に
  現れるが、「どの指摘をどう扱ったか」はMRに残らない。
- 対応しないと判断した指摘（指摘が誤り・意図した設計である等）にも理由を返信する。返信を
  省略してよい類型は作らない。
- **返信のタイミングは `comments` ループに揃え、敵対的レビューの直後には返信しない。** 投稿と
  返信の間に人間のレビューを挟むことで、同じスレッドへ人間が判断を示す余地を残す。
- ルールの本文は `.claude/skills/issue-mr-flow/references/review-loop.md` の `comments` サブコマンド手順4と
  「レビュー完了合図の確認」節が正で、`.claude/skills/adversarial-review/SKILL.md` には参照の
  1文だけを置く（手順の二重管理を避けるため）。
- **未返信スレッドを機械的に検出する専用の関数・スクリプトは設けない。** 判定条件は経路によらず
  「**スレッド内のコメントが1件だけ＝返信ゼロ**」であり、CLI経路では `comments all` の出力
  （同じ `threadId=` を持つ `[review ...]` 行が1本しか無い）、MCP経路では
  `mcp__github__pull_request_read` が返す各スレッドの `comments` 配列の件数で読む。
  **出力形式が違うため読み方は2通り書く必要があるが、それはドキュメント上の追記で済む**
  （詳細・却下案は DDR i0109-01）。

スレッドの解決（resolve）はレビュアー側の操作であり、本機構では行わない。

### `gh`/`glab` CLI不在時（MCP経路）

`get_vcs_access_mode` が `mcp` を返す環境では、投稿を
`mcp__github__pull_request_review_write` の3段構成へ読み替える（GitHubのみ。GitLabは対象外）。

1. `method="create"` で pending review を作る。
2. 指摘ごとに `method="add_comment_to_pending_review"`（`path` / `line` / `side` / `body`）。
3. **必ず `method="submit_pending"`（`event="COMMENT"`）まで実行する。** pending のまま放置すると
   次回の `create` が失敗し続ける。途中で失敗した場合は `method="delete_pending"` で片付ける。

CLI版と違い有効行の事前検証が入らないため、diffに含まれない行を指定すると個別に失敗する。
WebFetchツール・curlへはフォールバックしない（DDR i0014-01, DDR i0034-01）。

## 影響範囲

issue #77 で追加・変更したもの。

| ファイル | 内容 |
|---|---|
| `.claude/scripts/src/vcs/Provider.sh` | `add_mr_inline_comments` のディスパッチ、`format_findings_summary` |
| `.claude/scripts/src/vcs/Github.sh` | `github_valid_ranges_from_files_json` / `github_filter_findings_by_valid_lines` / `github_build_review_payload` / `github_add_mr_inline_comments` |
| `.claude/scripts/src/vcs/Gitlab.sh` | `gitlab_build_discussion_body` / `gitlab_add_mr_inline_comments`、`gitlab_format_discussion_notes` の位置出力 |
| `.claude/scripts/src/adversarial-review-count.sh` | 実施回数カウンタ（`get` / `increment` / `reset`） |
| `.claude/scripts/src/collect-review-points.sh` | 観点表の収集・マージ |
| `REVIEW-POINTS.md` / `.claude/REVIEW-POINTS.md` / `plans/REVIEW-POINTS.md` / `reports/REVIEW-POINTS.md` | レビュー観点表（`type: review-points`） |
| `.claude/agents/adversarial-reviewer.md` | 専任サブエージェント（読み取り専用・`model: opus`） |
| `.claude/skills/adversarial-review/SKILL.md` | 本機構のスキル（手順1〜9） |
| `.claude/skills/review-points/SKILL.md` | 観点表の収集・適用を単独でも使えるようにしたスキル |
| `.claude/skills/issue-mr-flow/SKILL.md` | 「敵対的レビューの位置づけ」節、MCP対応表への `add_mr_inline_comments` 行 |
| `.claude/scripts/test/test_vcs_provider.sh` | 純粋関数のテストを追加 |
| `.claude/scripts/test/test_adversarial_review_count.sh` | 新規（22件） |
| `.claude/scripts/test/test_collect_review_points.sh` | 新規（17件） |

変更（issue #106）:
- `.claude/skills/adversarial-review/SKILL.md`（`AUTOMATION` 環境変数による判定を廃止し、
  AIエージェントの判断へ置き換え。手順番号を1〜8へ繰り上げ）
- `.claude/docs/spec/adversarial-review.md`（本ドキュメント。起動ポリシー節・設定項目表・
  未決定事項から `AUTOMATION` の記述を除去）
- `.claude/skills/issue-mr-flow/SKILL.md`（「敵対的レビューの位置づけ」表から `AUTOMATION=1` の
  記述を除去）

新規（issue #106）:
- `.claude/docs/ddr/i0106-01-敵対的レビューの非対話判定は環境変数ではなくAIエージェントの判断に委ねる.md`

### 追記: GitLabのサマリをスレッドで投稿する（issue #121）

| ファイル | 内容 |
|---|---|
| `.claude/scripts/src/vcs/Gitlab.sh` | `gitlab_add_mr_thread`（`discussions` APIで非インラインのスレッドを立てる）／ `gitlab_summary_post_kind`（サマリの投稿先の判定）を追加、`gitlab_add_mr_inline_comments` のサマリ投稿を分岐 |
| `.claude/scripts/test/test_vcs_provider.sh` | `gitlab_summary_post_kind` のテストを追加（3件） |
| `.claude/docs/spec/adversarial-review.md` | 「インライン以外のコメントもスレッドで投稿する」節 |
| `.claude/docs/spec/issue-mr-workflow.md` | Provider関数一覧の `add_mr_inline_comments` 行 |
| `.claude/skills/adversarial-review/SKILL.md` | 手順7（issue #106以前は手順8）の戻り値の説明 |

### 追記: 敵対的レビュー由来スレッドの返信ルールを明文化する（issue #109）

| ファイル | 内容 |
|---|---|
| `.claude/skills/issue-mr-flow/SKILL.md` | 「敵対的レビューの位置づけ」表へ返信の担当を示す行を追加／`comments` サブコマンドへ手順4（敵対的レビュー由来スレッドの扱い）を追加し既存の手順4・5を5・6へ繰り下げ／「レビュー完了合図の確認」節へ未返信スレッドの確認を追加 |
| `.claude/skills/adversarial-review/SKILL.md` | 手順8の末尾へ返信の担当を示す**参照の1文**を追加／「してはいけないこと」へ投稿直後の自己返信の禁止を追加（**返信手順自体は書かない**） |
| `.claude/docs/spec/adversarial-review.md` | 本ドキュメント。「投稿されたスレッドの取得」節へ返信の扱いを追記 |
| `.claude/docs/ddr/i0109-01-敵対的レビュー由来のスレッドも人間の指摘と同列に返信を必須とする.md` | 新規 |
| `.claude/docs/spec/issue-mr-workflow.md` | 「チャットで受けたレビュー判断の記録」節の、繰り下がった手順番号への追随（手順5→手順6） |
| `.claude/docs/README.md` | DDR一覧へ i0109-01 を追加（当時の番号は `0064`。エントリ側に `0061` と書かれていたのは誤記で、issue #133 の改番時に訂正した） |

コード（`.claude/scripts/`）の変更は無い。`get_mr_unresolved_comments` は元から敵対的レビューの
スレッドも `unresolved` として返しており、**仕組み上は既に `comments` ループの対象だった**ため、
不足していたのはルールの明文化だけだったことによる（DDR i0109-01）。

### 追記: 投稿したスレッド数をHANDOFF.mdへ記録する（issue #70）

**手順8として「未返信スレッド数の記録」を新設し、旧手順8（報告）を手順9へ繰り下げた。**

- 投稿の直後に `update-handoff-progress.sh set-header --unreplied <posted>` を実行する。
  数えるのは**インラインで投稿できたスレッド**（`add_mr_inline_comments` の戻り値 `posted`）で、
  GitHubでレビュー本文へ回ったサマリ（`summarized`）はスレッドにならないため含めない。
- 既に0以外なら**上書きせず足し込む**（前のレビューの未返信が消えるため）。
- 投稿したスレッドのURL一覧も `HANDOFF.md` の「やったこと」へ残す（件数だけでは、次の
  セッションが返信先を特定できない）。

**なぜ必要だったか**: issue #109 で「返信は `issue-mr-flow` の `comments`/`reply` ループが担う」と
決めた結果、**投稿と返信の間に必ず人間のレビューが挟まる**構造になった。その間にセッションが
切れると、返信すべきスレッドの存在が会話ごと失われる。実際に issue #70 のフェーズ2で、投稿した
10スレッドが返信ゼロのまま `mark-done` され、約1日「未対応と区別が付かない」状態で残った。
**issue #109 の決定（返信を省略してよい類型を作らない）は維持したまま、忘れられない形にする**
のがこの追記である。

- 記録した値は、**レビュー往復のループ範囲への `mark-done` を0件になるまで拒否する**前提条件と
  して使われる（`.claude/docs/spec/update-handoff-progress.md`
  「ループ範囲への`mark-done`と未返信スレッド」が正）。

### 追記: 投稿件数選別を層単位ルールでスクリプト化する（issue #182）

**手順6（1次振り分け）と、新設した投稿件数の選別（本ドキュメント「投稿件数の選別」節）を
分離した。** 従来は手順6が「確度×重大度の表による振り分け」と「1回あたり10件への絞り込み」の
両方を1つの手順として持っていたが、後者を決定的なスクリプトへ切り出した。

| ファイル | 内容 |
|---|---|
| `.claude/scripts/src/select-adversarial-findings.sh` | 新規。層単位ルール（blocker無制限・層追加しきい値10・ハードシーリング20）による投稿件数の決定的な選別 |
| `.claude/scripts/test/test_select_adversarial_findings.sh` | 新規。境界ケースを含む単体テスト（詳細はファイル自体を正とする） |
| `.claude/skills/adversarial-review/SKILL.md` | 手順6を「1次振り分け＋スクリプト呼び出し」の形へ書き換え |
| `.claude/docs/spec/adversarial-review.md` | 本ドキュメント。「投稿件数の選別」節を新設、設定項目表を更新 |
| `.claude/docs/ddr/i0182-01-敵対的レビューの投稿件数選別を層単位ルールでスクリプト化する.md` | 新規 |
| `.claude/rules/shell-script-style.md` | 実装中に見つけたjqの落とし穴（`配列 \| index(.field)` のパイプ内`.`束縛）を追記 |
| `.claude/docs/README.md` | DDR一覧を `generate-ddr-list.sh` で再生成（i0182-01を追加） |

**なぜ変更したか**: 旧規則は「1回あたりの投稿上限は10件。超える場合は重大度の高い順に10件へ
絞る」とだけ規定しており、**同一重大度内でどれを落とすか**のタイブレークが未定義だった。
実行のたびにAIエージェントが手作業で選ぶ設計だったため、同じfindingsからでも実行ごとに異なる
投稿集合になりうる。件数選別を決定的なスクリプトへ切り出すことで、この裁量を無くした。

**確度×重大度による1次振り分け自体は変更していない。** 「技術的に投稿可能か」ではなく
「人間に見せる価値があるか」の判断であり、運用しながら調整できる場所（スキルの手順）に
置くという既存の判断は維持した。件数選別だけを切り出したのは、そちらが「同じ入力なら同じ
出力になるべき」という決定性の要件を持つのに対し、1次振り分けの表は運用感に応じて調整する
対象であり、性質が異なるためである（詳細・却下案はDDR i0182-01）。

## 設定項目

| 項目 | 既定 | 変更方法 |
|---|---|---|
| 実行モード | 対話モード（判断に迷う場合を含む） | AIエージェントが実行環境の性質（人間のレビュー往復が成立するか）から判断する。環境変数は使わない |
| 実施回数の上限 | 3回／フェーズ | `adversarial-review-count.sh` の `ADVERSARIAL_REVIEW_MAX_RUNS`（**緩める口は意図的に用意していない**） |
| 投稿候補への1次振り分け | 確度×重大度の表 | `adversarial-review/SKILL.md` 手順6 |
| 層追加のしきい値 | 10件 | `select-adversarial-findings.sh` の `LAYER_ADDITION_THRESHOLD`（**緩める口は意図的に用意していない**） |
| ハードシーリング | 20件 | `select-adversarial-findings.sh` の `HARD_CEILING`（同上） |
| レビュー観点 | 各ディレクトリの `REVIEW-POINTS.md` | 該当ディレクトリの観点表を編集する（スキル本文は編集しない） |

## 未決定事項・懸念点

- **観点表が増えたときのマージ結果が肥大する可能性。** 現在は4ファイルで問題にならないが、
  深い階層に観点表が増えると、サブエージェントへ渡す観点表が長くなる。
- **`/code-review` との併用方針。** 併用してよいとしているが、同じ欠陥が両方から指摘されたときの
  扱い（重複コメント）は運用で吸収している。
- **サマリへ回った指摘の追跡（GitHub）。** レビュー本文に載るだけで、スレッドとして解決状態を
  持たない。件数が増えた場合の扱いは未定。GitLab側は `discussions` で1つのスレッドとして投稿する
  ようにしたため解決状態を持つ（上記「インライン以外のコメントもスレッドで投稿する」）が、
  スレッド内の指摘は個別には解決できない。
- **非インラインのスレッド投稿は実機確認済み**（issue #127）。ローカルGitLab CE 18.5.4 に対し
  `add_mr_inline_comments` を2回実行し、`gitlab_summary_post_kind` の**両分岐を通した**。
  - run1（有効な指摘3件・サマリ0件）→ `{"posted":3,"summarized":0}`。0件の分岐
    （`gitlab_add_mr_comment` による**単発note**）を通った。**0件でも投稿は行われる**
    （本文が「すべての指摘をインラインコメントで示しています」という通知になるだけで、
    投稿そのものが省かれるわけではない。上記の表「0件 → `notes`」を参照）。
  - run2（有効2件・不正な行を指す1件）→ `{"posted":2,"summarized":1}`。サマリが
    `individual_note=false` / `resolvable=true` の**解決可能なスレッド**として投稿された
    （`position` を持たない `discussions` へのPOSTが通ることの確認を含む）。
  - 残る未検証はバージョン・エディション（gitlab.com・CE 18.5.4以外・EE）のみ。
