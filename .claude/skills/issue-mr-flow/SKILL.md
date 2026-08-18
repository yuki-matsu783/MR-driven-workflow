---
name: issue-mr-flow
description: このプロジェクトの開発フロー全体（issue起票〜マージ）の唯一の実装フロー定義。新機能追加・既存動作の変更など、あらゆるタスクをissue起点で進めるときに使う。issue取得、feature-<issue番号>-<内容>ブランチとDraft MRの作成、レビューコメント取得、MR description更新をサブコマンドで行いつつ、設計ドキュメント作成・plan・実装・設計反映・AIアセット反映までの全ステップをこのファイルが定義する。
title: issue駆動 開発フロー
type: skill
tags: [issue-mr-flow, workflow, skill]
keywords: [start, resume, sync, comments, reply, describe, draft-pr, 実装フロー, squash-merge, レビュー返信]
---

# issue駆動 フロー（唯一のフロー定義）

このファイルは `.claude/docs/spec/issue-mr-workflow.md` の実装であり、このプロジェクトにおける
**issue起票からマージまでの唯一のフロー定義**である。適用要否の判定基準（除外してよい
「ごく小さな変更」の定義）は `AGENTS.md` を参照する。対象となるタスクは、このファイルの
手順で進める。

裏側の実処理は `.claude/scripts/src/vcs/Provider.sh`（GitHub/GitLabの差異を吸収する共通関数群。bash版。
設計: `.claude/docs/spec/shell-scripts.md`）に実装されている。各ステップの手順内で、必要に応じて
Bashツールで以下のようにsourceして使う。

```bash
source .claude/scripts/src/vcs/Provider.sh
```

各関数はJSON文字列をstdoutへ出力する設計のため、`jq`でフィールドを取り出す
（例: `get_issue 6 | jq -r '.title'`）。

プロジェクト固有のパス設定（ブランチ命名規則・`plans/` 等の場所）はリポジトリ直下の `.mrworkflow.json`
から読む（`get_workflow_config`）。他リポジトリへ移植する場合はこのファイルの値を書き換えるだけでよい。

## 全体フロー

担当列: 「人間」＝人間の作業／「サブコマンド」＝下記「サブコマンド」節の `/issue-mr-flow <名前>`／
「エージェント」＝AIエージェントの通常操作（git操作・ファイル編集等）。

flow-idは `<フェーズ番号>-<ステップ番号>` 形式で、全5フェーズ・39ステップからなる。

| フェーズ | 範囲 | 内容 |
|---|---|---|
| 1 | 1-1〜1-6 | 起点（issue起票・ブランチ/Draft MR作成・全体作業計画） |
| 2 | 2-1〜2-10 | 調査（調査計画 → レビュー → 調査実施 → レビュー） |
| 3 | 3-1〜3-10 | 作業（作業計画 → レビュー → 設計・実装 → レビュー） |
| 4 | 4-1〜4-10 | 反映（反映計画 → レビュー → 設計反映・AIアセット反映 → レビュー） |
| 5 | 5-1〜5-3 | クローズ（片付け・Draft解除・マージ） |

フェーズ2〜4は「計画 → commit/push → レビュー → 実施 → commit/push → レビュー →
MR description更新」という同じ形を繰り返す。
フェーズ2,3はどちらかのみ実施する計画となることがありうるが、
フェーズ1,4,5についてはこのフローを利用する際は必ず実施する。

| flow-id | ステップ | 担当 |
|---|---|---|
| 1-1 | issueを起票する（`.github/ISSUE_TEMPLATE/task.md` / `.gitlab/issue_templates/task.md` で目的・現状・期待する動作・受け入れ条件を記載） | 人間（AIが代行する場合は `issue-create` スキル） |
| 1-2 | issueの内容を取得する | `start <issue番号>` |
| 1-3 | featureブランチ（`feature-<issue番号>-<slug>`）とDraft MRを作成する（既にあれば `sync` のみ） | `start` |
| 1-4 | **Planモードで「全体作業計画」を作成する**（このissueをどう進めるか＝何を調査し何を実装するかの全体像。ハーネスが提示するパス `plans/<自動命名>.md` へ出力）。**現在のブランチに既に全体作業計画があれば新規作成せず、既存を読むだけにとどめる**（詳細は下記「計画の2階層構造」） | エージェント |
| 1-5 | 全体作業計画に合意する | 人間 |
| 1-6 | 全体作業計画をもとにHANDOFF.mdを更新する | エージェント |
| 2-1 | **個別調査計画**`plans/【調査】〜.md`を**planツールを使わず**Write/Editで作成する。このタイミングで `worklog/日付_<全体計画名>_<個別計画名>_push<N>.md` を作成 | エージェント |
| 2-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| 2-3 | MRで調査計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| 2-4 | レビュー内容を取得し、調査計画を修正する。対応が完了したコメントには対応内容を返信する（2-3〜2-4を合意まで繰り返す） | `comments` / `reply` |
| 2-5 | 調査計画をもとにMR descriptionを更新する | `describe` |
| 2-6 | **調査を実施**し、結果を個別調査計画・worklogに記録する。あわせて結果を視覚的に分かりやすくまとめた自己完結HTML（TailwindCSS CDN方式）を`reports/日付_<全体計画名>_<内容を簡潔に>.html`として作成する（複数要素間の関連・依存関係が主題の場合は、`.claude/skills/canvas-report/SKILL.md`のcanvas形式テンプレートの利用を検討する） | エージェント |
| 2-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| 2-8 | MRで調査結果についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| 2-9 | レビュー内容を取得し、調査結果を修正する。対応が完了したコメントには対応内容を返信する（`reports/`のHTMLも調査結果と同期して更新する。2-6〜2-9を合意まで繰り返す） | `comments` / `reply` |
| 2-10 | 調査結果をもとにMR descriptionを更新する | `describe` |
| 3-1 | **調査結果をもとに**、個別作業計画`plans/【設計】【実装】〜.md`等を**planツールを使わず**Write/Editで作成する | エージェント |
| 3-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| 3-3 | MRで作業計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| 3-4 | レビュー内容を取得し、作業計画を修正する。対応が完了したコメントには対応内容を返信する（3-3〜3-4を合意まで繰り返す） | `comments` / `reply` |
| 3-5 | 作業計画をもとにMR descriptionを更新する | `describe` |
| 3-6 | 作業計画をもとに作業を進める、作業内容はworklogに更新する | エージェント |
| 3-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| 3-8 | MRでレビュー・コメントする。レビュー済み連絡をするまで以降の作業は行わない。 | 人間 |
| 3-9 | レビュー内容を取得し、実装・ドキュメントを修正する。対応が完了したコメントには対応内容を返信する（3-6〜3-9の作業ループを合意まで繰り返す） | `comments` / `reply` |
| 3-10 | 作業内容をもとにMR descriptionを更新する | `describe` |
| 4-1 | **作業結果と`plans/` `worklog/` の内容をもとに**、個別反映計画`plans/【設計反映】【AIアセット反映】〜.md`等を**planツールを使わず**Write/Editで作成する | エージェント |
| 4-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| 4-3 | MRで反映計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| 4-4 | レビュー内容を取得し、反映計画を修正する。対応が完了したコメントには対応内容を返信する（4-3〜4-4を合意まで繰り返す） | `comments` / `reply` |
| 4-5 | 反映計画をもとにMR descriptionを更新する | `describe` |
| 4-6 | 反映計画をもとに作業を進める、反映内容はworklogに更新する（**設計反映**: `plans/` `worklog/` の内容を `.claude/docs/spec/` `.claude/docs/ddr/`（アプリ本体があれば`docs/spec/` `docs/ddr/`）へ反映する／**AIアセット反映**: 作業中に気づいたルール・スキルの不備を `.claude/rules/` `.claude/skills/` `CLAUDE.md` `AGENTS.md` に反映する） | エージェント |
| 4-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| 4-8 | MRでレビュー・コメントする。レビュー済み連絡をするまで以降の作業は行わない。 | 人間 |
| 4-9 | レビュー内容を取得し、設計・AIアセットの内容を修正する。対応が完了したコメントには対応内容を返信する（4-6〜4-9の反映ループを合意まで繰り返す） | `comments` / `reply` |
| 4-10 | 反映内容をもとにMR descriptionを更新する | `describe` |
| 5-1 | 次タスクのために、`plans/` `worklog/` `reports/` を削除し、`HANDOFF.md` をリセットする。**あわせて `plans/index.jsonl` も削除し、`bash .claude/scripts/src/extract-frontmatter.sh .` で `index.jsonl` 群を再生成する**（下記「flow-id 5-1での `index.jsonl` の扱い」） | エージェント |
| 5-2 | `commit`スキル経由でcommitし、push して Draftを解除する | エージェント |
| 5-3 | マージする（squash merge。ブランチは削除してよい） | 人間 |

### 計画の2階層構造（issue #9）

計画は**全体作業計画**（上位）と**個別調査計画・個別作業計画・個別反映計画**（下位）の2階層に分ける。
Claude Code / Gemini CLI は**セッションごとに1つのplanファイルしか割り当てない**ため、
planツールで複数の計画を作ろうとすると計画同士が混ざる。これを構造的に避けるための分離である。

| 種類 | 作り方 | ファイル名 | 単位 |
|---|---|---|---|
| **全体作業計画** | **planツール**（Planモード）で作成 | ハーネス提示パス `plans/<自動命名>.md` をそのまま使う | **issue（ブランチ）につき1回**（flow-id 1-4） |
| **個別調査計画** | **planツールを使わない**（Write/Editで直接作成） | `plans/【調査】タスク内容.md` | フェーズ2で必要な数だけ（flow-id 2-1） |
| **個別作業計画** | **planツールを使わない**（Write/Editで直接作成） | `plans/【種別】タスク内容.md` | フェーズ3で必要な数だけ（flow-id 3-1） |
| **個別反映計画** | **planツールを使わない**（Write/Editで直接作成） | `plans/【種別】タスク内容.md` | フェーズ4で必要な数だけ（flow-id 4-1） |

**タスク種別**（`【】`内）は次の6種を標準とする。

`【調査】` `【設計】` `【実装】` `【テスト】` `【設計反映】` `【AIアセット反映】`

#### 種別を複数併記する場合／分ける場合

1ファイルに複数の種別を併記してよい（例: `plans/【実装】【テスト】SKILLフロー改訂.md`）。
判断基準は「**その計画に対して人間の合意を1回で取るか、フェーズごとに分けて取るか**」である。

| | 併記する（1ファイル） | 分ける（複数ファイル） |
|---|---|---|
| **判断基準** | 分けても合意の単位が変わらず、記述が重複するだけの場合 | フェーズごとに個別の合意・レビューを挟みたい場合 |
| **例** | `【実装】【テスト】` — テストコードを実装と同時に書き、まとめて1回で合意する | `【調査】〜.md` → `【実装】〜.md` — 調査結果を見てから実装方針を決めるため、間に合意を挟む |
| | `【設計】【実装】` — 設計が小規模で、実装方針と一体で判断できる | `【実装】機能A.md` / `【実装】機能B.md` — 対象範囲が独立しており、別々にレビューしたい |

迷ったら**分ける**。1ファイルが大きくなるほど、レビューで一部だけを差し戻しにくくなる。
逆に、併記した計画のレビューで「この部分だけ先に進めたい」となった場合は、その時点で
ファイルを分割してよい（分割後も既存の合意内容は失わないこと）。

- **囲み文字は全角の `【】` を使う**（ASCIIの `[]` は使わない）。`[]` はbashのglobで**文字クラス**
  として解釈されるため、`plans/[調査]*.md` のようなパターンが意図どおりマッチしない。全角の
  `【】` はglob特殊文字ではないため、`plans/【調査】*.md` と未クォートで書いても正しくマッチする。
- **下位の個別計画（調査・作業・反映）は `plans/【*.md` で機械的に列挙できる**。逆に、それに一致しないものが
  全体作業計画である。flow-id 1-4 で「既に全体作業計画があるか」を判定する際にこの区別を使う。
- 日本語を含むパスをgitの出力から扱う場合は `-c core.quotepath=false` が必要
  （既定では8進エスケープされる。実装例: `Provider.sh` の `get_branch_work_files`）。

**flow-id 1-4 の判定**: `get_branch_work_files` でブランチ固有のplansファイルを列挙し、
`【` で始まらないものが既にあれば、それが全体作業計画である。その場合は**planツールで新しい
計画ファイルを作らず**、既存を読んで次のステップへ進む。`.claude/settings.json` の
`"defaultMode": "plan"` により新セッションは必ずPlanモードで始まるが、それは新規作成の理由に
ならない（作ると全体作業計画がセッションごとに増えてしまう）。

セッションのcompactは任意のタイミングで行ってよく、特定のflow-idには割り当てない（コンテキストが
大きくなってきたと感じたタイミングで、人間の判断で `/compact` を実行すればよい）。

**`start` から着手する場合を除き、このセッションでこのフローのサブコマンドを初めて使う前には、
必ず先に `resume` を実行して「今どこにいるか」を特定する。** `git branch --show-current` 等で
ブランチ名やissue番号が判明していることは、`resume` を省略してよい理由にはならない。`resume` の
目的はブランチ名の特定ではなく、PR/MRの状態・未解決コメント件数・plan/worklogファイル・
HANDOFF.mdとの矛盾など、ブランチ名だけでは分からない「このセッションでまだ確認していない現在地
情報」を集約することにある。
**flow-idが1つ進むごとに、必ず`HANDOFF.md`を更新する**。具体的には、完了したflow-idの行を
`[x]` にし、「やったこと」「次にやること」を書き換える。更新はcommit（flow-id 2-2/2-7/3-2/3-7/4-2/4-7/5-2）
より前に行い、**同じcommitに含める**（別commitに分けると、レビュー時点の進捗表と実際の変更内容が
食い違う）。

## サブコマンド

呼び出しは `/issue-mr-flow <サブコマンド> [引数]` の形。

### `start <issue番号>` — issue取得・ブランチ/MR作成（全体フロー 1-2〜1-3）

1. `get_issue <issue番号>` でissueのtitle/body/urlを取得し、内容をユーザーに提示する。
   続けて `test_issue_sections "$(get_issue <issue番号> | jq -r '.body')"` を呼び、標準4見出し
   （目的・現状・期待する動作・受け入れ条件。`.github/ISSUE_TEMPLATE/task.md` /
   `.gitlab/issue_templates/task.md` 参照）の過不足を確認する。欠けている見出しがあれば
   「issue本文に以下の見出しがありません: ...」とユーザーに警告する（処理は止めず、そのまま次へ進む）。
2. issue番号をキーに、既存ブランチの有無を確認する。`.mrworkflow.json` の `branchPrefixTemplate` の
   `{issue}` をissue番号に置換し `{slug}` 以降を `*` に置き換えたパターン
   （既定なら `feature-<issue番号>-*`）で `git branch --list "<pattern>"`（ローカル）・
   `git ls-remote --heads origin "<pattern>"`（リモート）を検索する。slug部分の内容は問わず、
   issue番号のprefix一致のみで判定する（次項の意訳フレーズはAIが都度生成するため非決定的であり、
   slugまで含めた完全一致では同一issueに対して重複してブランチ・Draft MRを作成しかねないため）。
   - 見つかった場合（セッション再開）: そのブランチ名をそのまま使い `sync_branch "<既存ブランチ名>"`
     でfetch・checkoutのみ行う。
   - 見つからない場合（新規作成）:
     a. **ベースブランチを確認する**（issue #15）: `get_workflow_config | jq -r '.defaultBaseBranch'`
        で既定のベースブランチを取得し、`AskUserQuestion` でユーザに確認する。選択肢は次の方針で
        組み立てる。
        - 常に含める: `<defaultBaseBranch>のまま (Recommended)`
        - `defaultBaseBranch` が `main` と異なる場合のみ追加: `main`
        - 常に含める: `別のブランチを指定する`（選択された場合、`AskUserQuestion` は選択式が
          主眼のため、続けて通常のプロンプトで具体的なブランチ名をユーザに尋ねる）
        確定したブランチ名を以降 `<base_branch>` として使う。既定のまま選ばれた場合は
        `<base_branch>` を指定せず、後続関数の省略時デフォルト（`defaultBaseBranch`）に委ねてよい。
     b. issueタイトルの意味を汲んだ、ブランチslug用の英語フレーズを考える（3〜6語程度、
        スペース区切りの単語列でよい。kebab-case化・記号除去・小文字化は `to_slug` が行うため
        ここでは不要。直訳ではなく意訳でよい。例:「ブランチ名のslugをリッチにしたい」→
        `enrich branch slug`）。タイトルが元々英語主体の場合はタイトルをそのまま使ってよい。
     c. `new_issue_branch <n> "<b.で考えた英語フレーズ>" [<base_branch>]` でブランチを作成・
        checkout・push、続けて `new_draft_merge_request <n> "<branch>" "<issue.Title>" [<base_branch>]`
        （**Draft MRのタイトルには引き続き生のissueタイトルを使う。英語フレーズはブランチ名専用**。
        `<base_branch>` は手順aで確定した値。既定のままなら省略）
        でDraft MRを作成する。**この呼び出しの標準エラー出力に `gh pr create` /
        `glab mr create` の失敗メッセージ（例:「No commits between ...」）や
        「baseとの差分が無いことによる既知の制約です。空コミットを1つ積んでリトライします」が
        出ても、それだけで失敗と判断しない**（`new_issue_branch` 直後はbaseとの差分がまだ無いため
        1回目の作成は必ず失敗する既知の制約で、内部の `add_empty_commit_for_draft_mr` が
        空コミット+pushで自動的に1回だけリトライする設計。詳細:
        `.claude/docs/spec/issue-mr-workflow.md`「Draft PR作成失敗時の自動リトライ」、
        `.claude/docs/ddr/0005-DraftPR作成失敗時は空コミットで自動リトライする.md`）。
        関数が最終的にPR/MR番号を標準出力へ返せば成功であり、それ以上の空コミット・push・
        `commit`スキル呼び出しは不要。番号が返らずエラーで終了した場合のみ実際の失敗として対処する。
3. 取得したissue内容をもとに、全体フロー 1-4（Planモードでの全体作業計画作成）に進む旨をユーザーに案内する。

### `comments [all]` — MRレビューコメントの取得（全体フロー 2-4・2-9・3-4・3-9・4-4・4-9）

1. `get_mr_for_branch "$(git branch --show-current)"` で現在のブランチに紐づくMR番号を取得する。
2. `get_mr_unresolved_comments <n>` で未解決コメントを取得し、そのまま提示する
   （ファイルパス・行番号・スレッドID・該当diffを含む）。対応済み（解決済み）のスレッドは既定で
   機械的に除外される。引数に `all` が指定された場合は `get_mr_unresolved_comments <n> true` で呼び、
   解決済みも含めた全件を取得する。
3. ユーザがプロンプトにおいて指摘を行った場合は、MRにコメントすることを促す。
4. 提示した内容をもとに、該当する計画ファイル（全体作業計画または下位の個別計画）を修正する、
   または設計・実装を修正する
   （この修正作業自体は本スキルの対象外。通常の編集で行う）。対応が完了したコメントには、
   `reply` サブコマンドで対応内容を返信する。

### `reply <threadId> <対応内容>` — レビューコメントへの返信（全体フロー 2-4・2-9・3-4・3-9・4-4・4-9）

1. `get_mr_for_branch "$(git branch --show-current)"` で現在のブランチに紐づくMR番号を取得する
   （`comments` の手順1と同じ）。
2. 返信本文を組み立てる。**AIエージェントが返信する場合は、本文の先頭に必ず
   `Claude Codeより:` の署名行を付ける。** `gh` / `glab` CLIは人間のアカウントで認証
   されているため、GitHub/GitLab上の投稿者アカウントは人間のものとして表示される。誰が書いた
   返信かをレビュアーが判別できるよう、本文側で明示する（`add_mr_thread_reply` 関数は自由文を
   そのまま渡す設計のため、署名の付与は呼び出し側であるこの手順の責務とする）。
3. `add_mr_thread_reply <n> "<threadId>" "<署名付きの対応内容>"` で、
   指定したスレッドに返信する。`threadId` は `comments` の出力に含まれる `threadId=...` を使う。
4. スレッドの解決（resolved）はレビュアー側の操作であり、本サブコマンドでは行わない。

### `describe` — MR descriptionの更新（全体フロー 2-5・2-10・3-5・3-10・4-5・4-10）

1. `get_branch_work_files` で現在のブランチ固有の計画・worklogを列挙し、**全体作業計画**
   （`plans/` 配下で `【` で始まらないもの）と**下位の個別計画**（`plans/【*.md`）、および
   worklogの要点を読む。
2. 以下のテンプレートでMR description本文を組み立て、一時ファイルへ書き出す。

   ```markdown
   Closes #<issue番号>

   ## Plan

   <全体作業計画の要約＋各個別計画の要点。計画が複数ある場合は、
    どのフェーズまで進んでいるかが分かるようにまとめる>

   ## 実装状況

   <worklogの「うまくいったこと」等から、現時点までの実装内容の要約。plan段階では「未着手」>
   ```

3. `get_mr_for_branch "$(git branch --show-current)"` で現在のブランチに紐づくMR番号を取得し
   （`comments` の手順1と同じ）、`set_mr_description <n> <一時ファイル>` で反映する。

### `sync` — セッション再開（全体フロー 1-3の再開版）

対象ブランチ名を引数に取り、`sync_branch "<branch>"` を呼ぶだけの単純なコマンド。
引数省略時は現在のブランチ名を使う。`resume` や `start` で既にこのセッションの現在地確認が
済んでいる状態で、ブランチを最新化したいだけの場合に使う。**新しいセッションで最初に使う
サブコマンドとしては使わない**（新しいセッションの最初の一手は必ず `resume` から入る）。

### `resume` — 途中引き継ぎ（引数なし）

このセッションでまだ「今どこにいるか」（issue／ブランチ／PRの、どの段階か）を確認していない
状態で使う。別セッション・別担当者が途中から引き継ぐ場合に限らず、`start` 以外のサブコマンドを
このセッションで初めて使う前は常にここから入る（ブランチ名やissue番号が判明していても対象）。

1. Agentツールで `issue-mr-resume` サブエージェント（`.claude/agents/issue-mr-resume.md`）を起動する。
2. サブエージェントが返す「現在地サマリ」（ブランチ・issue・PR/MR・未解決コメント件数・
   ブランチ固有のplan/worklogファイル・HANDOFF.mdの内容、および矛盾・注意点）をそのまま
   ユーザーに提示する。
3. 提示した内容をもとに、全体フローの39ステップのうちどこから再開すべきかをAIエージェントが判断し、
   次にすべきことを提案する（この判断はサブエージェントではなく呼び出し元が行う）。
4. issue番号が特定できていればブランチ/MRの存在確認へ（`start` 手順2相当）、issueが特定できなければ
   ブランチ命名規則から外れている旨を伝えて `start <issue番号>` での対応を促す。

## レビュー完了合図の確認（全体フロー 2-4・2-9・3-4・3-9・4-4・4-9）

人間から「レビューOK」「合意」等、レビューループを終えて次のステップに進んでよいという合図を
受けても、それだけを根拠に次のステップへ進んではいけない。**必ず `comments all`
（`get_mr_unresolved_comments <n> true`）でスレッドを再取得し、`unresolved` のスレッドが
残っていないか確認する。**

- 残っていなければ、そのまま次のステップに進む。
- 残っていれば、その旨（対象スレッドと内容）を人間に伝えて再確認を取り、解消されるまで次の
  ステップには進まない（GitHub/GitLabのスレッド解決自体はレビュアー側の操作であり、`reply` は
  解決を行わないため、返信済みでも `unresolved` のまま残ることがある）。

## flow-id 5-1での `index.jsonl` の扱い

`plans/` `worklog/` `reports/` を削除する際は、**`plans/index.jsonl` も一緒に削除する**。そのうえで
リポジトリルートで `index.jsonl` 群を再生成し、5-2のcommitに含める。

```bash
rm -f plans/index.jsonl
bash .claude/scripts/src/extract-frontmatter.sh .
```

`extract-frontmatter.sh` は「markdownが直下に存在するディレクトリ」だけを出力対象にするため、
`plans/*.md` を全削除すると `plans/index.jsonl` は**再生成の対象から外れ、削除済みの計画ファイルを
指したまま残ってしまう**（スクリプト側での自動削除は、スコープ外のファイルを消しうるため採用して
いない。詳細:
`.claude/docs/ddr/0021-frontmatter抽出は1ファイル1回のjq呼び出しとmtimeキャッシュで高速化する.md`
の却下案4）。`worklog/` は `TEMPLATE.md` が残るため、再生成すれば正しい状態になる。

なお `index.jsonl` は各ファイルの `mtime` を持つため、`HANDOFF.md` や `plans/` `worklog/` を編集した
flow-idでは毎回内容がずれる。**5-1に限らず、各commitの直前に
`bash .claude/scripts/src/extract-frontmatter.sh .` を1回流しておく**とよい（差分が無ければ2秒未満で
終わる。詳細: `.claude/rules/markdown-frontmatter.md`）。

## PRがflow-id 5-1実施前にマージされてしまった場合の対処

人間がレビュー後にそのままMR/PRをマージするなど、flow-id 5-1（`plans/` `worklog/` `reports/`の
削除・`HANDOFF.md`のリセット）を実施する前に**先にマージが完了してしまう**ことがある（issue #28,
PR #29のセッションで実際に発生）。この場合、タスク固有の`plans/`配下の計画ファイル（全体作業計画・
下位の個別計画）・`worklog/`・`reports/`のファイル・作業途中のままの`HANDOFF.md`が、そのまま
`main`へ残ってしまう（本来`worklog/`・`reports/`はsquash mergeの対象からflow-id 5-1で除外され
`main`に残らない設計であり、このズレはdocs-workflow.mdの運用と矛盾する）。

マージ後にこのズレに気づいた場合、**`main`へ直接コミットせず**、以下の手順で対処する
（`main`は共有の正史であり、レビューを経ないままの直接変更は避ける）。

1. `git fetch origin main` 等で最新の`main`を確認し、残ってしまった`plans/`・`worklog/`・
   `reports/`ファイル・`HANDOFF.md`の状態を特定する。
2. 新しいクリーンアップ用ブランチを`main`から作成する（対象のissue番号が無いことが多いため、
   `.mrworkflow.json`の`branchPrefixTemplate`に従う必要はなく、`chore/cleanup-<簡潔な説明>`の
   ような分かりやすい名前でよい）。
3. そのブランチ上で、該当する`plans/`・`worklog/`・`reports/`ファイルを削除し、`HANDOFF.md`を
   次タスク向けの空テンプレートへリセットする（内容はflow-id 5-1で行うものと同じ。
   `plans/index.jsonl`の削除と`index.jsonl`群の再生成も含む。上記「flow-id 5-1での
   `index.jsonl` の扱い」参照）。
4. commit・pushし、`main`を対象にPRを作成する。PR作成・マージの実行は、他のPR操作と同様
   ユーザーから明示的な指示を受けてから行う（`.claude/rules/git-workflow.md`の原則どおり、
   マージ自体は人間が行う）。

## 詳細ルールへのポインタ

全体フローの各ステップに関わる詳細は、以下の既存ルールを参照する（このファイルは順序立った
フローの定義に専念し、内容の重複は避ける）。

- ドキュメントの置き場所・ライフサイクル（`plans/` `worklog/` `.claude/docs/spec/` `.claude/docs/ddr/` `HANDOFF.md`）:
  `.claude/rules/docs-workflow.md` の「ドキュメント運用」表
- ブランチ命名規則・squash mergeの方針・コミット運用（`commit`スキル必須使用・PreToolUse hookに
  よる技術的強制）: `.claude/rules/git-workflow.md`
- bashスクリプトの規約（`set -euo pipefail`・jq前提・改行/エンコーディング等）:
  `.claude/rules/shell-script-style.md`
- `Provider.sh`の設計・スクリプト言語選定方針（bash化できる/できない判断基準）:
  `.claude/docs/spec/shell-scripts.md`

## 前提

- `gh` CLI（GitHubの場合）または `glab` CLI（GitLabの場合）、および `jq` がインストール・認証済みであること。認証情報自体は各CLIの既存ログイン状態に依存し、本スキル側では管理しない。
- リポジトリ直下に `.mrworkflow.json` があること（無い場合は `.claude/scripts/src/vcs/Provider.sh` の既定値が使われる）。
- issueは `.github/ISSUE_TEMPLATE/task.md`（GitHub）/ `.gitlab/issue_templates/Default.md`（GitLab）のテンプレートに沿って「目的・現状・期待する動作・受け入れ条件」を記載しておくことが望ましい
  （必須ではなく、`start` サブコマンドが欠落を警告する）。
- Claude Code/GeminiCLIのセッションとMRの関係性については、多:1の関係を許容する（1つのMRに対して複数セッションを切り替えて作業してもよい）。
  ただし、1:多は想定しない。つまり、同一セッション内で複数MRを同時に扱うことはできない（`resume` は1つのMRに対してのみ現在地確認を行うため）。
