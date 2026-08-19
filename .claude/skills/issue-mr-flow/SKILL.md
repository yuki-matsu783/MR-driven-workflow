---
name: issue-mr-flow
description: このプロジェクトの開発フロー全体（issue起票〜マージ）の唯一の実装フロー定義。新機能追加・既存動作の変更など、あらゆるタスクをissue起点で進めるときに使う。issue取得、feature-<issue番号>-<内容>ブランチとDraft MRの作成、レビューコメント取得、MR description更新をサブコマンドで行いつつ、設計ドキュメント作成・plan・実装・設計反映・AIアセット反映までの全ステップをこのファイルが定義する。
title: issue駆動 開発フロー
type: skill
tags: [issue-mr-flow, workflow, skill]
keywords: [start, resume, sync, comments, reply, describe, draft-pr, issue分割, 並列列挙, 実装フロー, squash-merge, レビュー返信, 着手確認]
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

flow-idは `<フェーズ番号>-<ステップ番号>` 形式で、全5フェーズ・40ステップからなる。

| フェーズ | 範囲 | 内容 |
|---|---|---|
| 1 | 1-1〜1-6 | 起点（issue起票・ブランチ/Draft MR作成・全体作業計画） |
| 2 | 2-1〜2-10 | 調査（調査計画 → レビュー → 調査実施 → レビュー） |
| 3 | 3-1〜3-10 | 作業（作業計画 → レビュー → 設計・実装 → レビュー） |
| 4 | 4-1〜4-10 | 反映（反映計画 → レビュー → 設計反映・AIアセット反映 → レビュー） |
| 5 | 5-1〜5-4 | クローズ（片付け・コンフリクト解消・Draft解除・マージ） |

フェーズ2〜4は「計画 → commit/push → レビュー → 実施 → commit/push → レビュー →
MR description更新」という同じ形を繰り返す。
フェーズ2,3はどちらかのみ実施する計画となることがありうるが、
フェーズ1,4,5についてはこのフローを利用する際は必ず実施する。

| flow-id | ステップ | 担当 |
|---|---|---|
| 1-1 | issueを起票する（`.github/ISSUE_TEMPLATE/task.md` / `.gitlab/issue_templates/Default.md` で目的・現状・期待する動作・受け入れ条件を記載） | 人間（AIが代行する場合は `issue-create` スキル） |
| 1-2 | issueの内容を取得する | `start <issue番号>` |
| 1-3 | featureブランチ（`feature-<issue番号>-<slug>`）とDraft MRを作成する（既にあれば `sync` のみ）。**Draft MRの作成に都度の明示指示は要らない**（下記「PR/MR作成・マージの担当」。ハーネスがPR作成を制限する環境での例外も同節） | `start`（エージェント） |
| 1-4 | **Planモードで「全体作業計画」を作成する**（このissueをどう進めるか＝何を調査し何を実装するかの全体像。ハーネスが提示するパス `plans/<自動命名>.md` へ出力）。**現在のブランチに既に全体作業計画があれば新規作成せず、既存を読むだけにとどめる**（詳細は下記「計画の2階層構造」）。**作成前に、issueが大きすぎないか（同型の成果物が並列に列挙されていないか）を判定し、該当すれば分割を提案する**（下記「issueが大きすぎる場合の分割提案」） | エージェント |
| 1-5 | 全体作業計画に合意する | 人間 |
| 1-6 | 全体作業計画をもとにHANDOFF.mdを更新する | エージェント |
| 2-1 | **個別調査計画**`plans/【調査】〜.md`を**planツールを使わず**Write/Editで作成する。このタイミングで `worklog/日付_<全体計画名>_<個別計画名>_push<N>.md` を作成 | エージェント |
| 2-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| 2-3 | MRで調査計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| 2-4 | レビュー内容を取得し、調査計画を修正する。対応が完了したコメントには対応内容を返信する（2-3〜2-4を合意まで繰り返す） | `comments` / `reply` |
| 2-5 | 調査計画をもとにMR descriptionを更新する | `describe` |
| 2-6 | **調査を実施**し、結果を個別調査計画・worklogに記録する。あわせて結果を視覚的に分かりやすくまとめた自己完結HTML（TailwindCSS CDN方式）を`reports/日付_<全体計画名>_<内容を簡潔に>.html`として作成する（複数要素間の関連・依存関係が主題の場合は、`.claude/skills/canvas-report/SKILL.md`のcanvas形式テンプレートの利用を検討する）。**ここで初めて規模が判明した場合は、未着手範囲を別issueへ切り出すことを検討する**（下記「issueが大きすぎる場合の分割提案」） | エージェント |
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
| 5-1 | 次タスクのために、`plans/` `worklog/` `reports/` を削除し、`HANDOFF.md` をリセットする | エージェント |
| 5-2 | **defaultブランチとのコンフリクトを検知し、あれば解消する**（`bash .claude/scripts/src/check-base-conflicts.sh` で判定 → `hasConflict` が真なら `AskUserQuestion` でユーザーに確認 → 承認されたら `resolve-conflict` スキルで解消。詳細は下記「defaultブランチとのコンフリクト検知・解消」節） | エージェント（`resolve-conflict` スキル） |
| 5-3 | `commit`スキル経由でcommitし、push して Draftを解除する（解除は `source .claude/scripts/src/vcs/Provider.sh && set_mr_ready <MR番号>` で行う。`gh pr ready` / `glab mr update --ready` を直接呼ばない。MR番号は `get_mr_for_branch` で取得できる）。**AIエージェントはここで止まる**（マージへは進まない） | エージェント |
| 5-4 | マージする（squash merge。ブランチは削除してよい）。**AIエージェントは、ユーザーから明示的に指示された場合に限り実行してよい**（下記「PR/MR作成・マージの担当」） | 人間 |

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

**`【設計反映】` と `【AIアセット反映】` は、基本的に併記せず分ける**（issue #36）。
タスクの種類（正史ドキュメントへの記録 対 運用ルールの改訂）・要求される人間の認知の種類が
大きく異なるため、1回のレビューでまとめて合意を取ろうとすると評価軸が混ざりやすい。
実施タイミングも計画ファイルと合わせて分離し、設計反映を完了・レビューしてから
AIアセット反映に着手する（flow-id 4-6〜4-10を2セット回す形になる。片方のみで完結する場合は
無理に2ファイルへ分けなくてよい）。

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
**flow-idが1つ進むごとに、必ず`HANDOFF.md`を更新する**。進捗表の記号更新は
`.claude/scripts/src/update-handoff-progress.sh`（`mark-done <flow-id>`でその行を、ループ扱いの
flow-idなら同じループ範囲の全行をまとめて`[x]`にする。フェーズ・ループ範囲を丸ごと省略する場合は
`mark-skip <flow-id...>`で`[-]`にする。詳細・制約は`.claude/docs/spec/update-handoff-progress.md`
参照）へ委譲し、それに続けて「やったこと」「次にやること」を書き換える。更新はcommit（flow-id
2-2/2-7/3-2/3-7/4-2/4-7/5-3）より前に行い、**同じcommitに含める**（別commitに分けると、レビュー
時点の進捗表と実際の変更内容が食い違う）。

**ただし、ループ範囲に属するflow-idでは記号を動かす条件が違う**（issue #64で実際に踏んだ。作業を
終えた時点で`mark-done 4-6`を呼び、まだcommitもレビューもしていない4-7〜4-9まで`[x]`になった）。
ループ範囲は`2-3 2-4` / `2-6`〜`2-9` / `3-3 3-4` / `3-6`〜`3-9` / `4-3 4-4` / `4-6`〜`4-9`の6つ。

- **`mark-done`を呼ぶのは、レビュー合意まで進んで1周が完了した時点だけ**にする。範囲内の途中の
  flow-id（作業が終わった直後・リモートへ反映した直後など）では進捗記号を動かさず、「やったこと」の
  文章だけを更新する。`mark-done`はループ範囲の全行をまとめて`[x]`にするため、途中で呼ぶと
  「人間のレビューが済んでいる」という誤った状態が表に残る。
- **2周目以降に入るときは、作業を始める前に`add-round <flow-id>`で`[]`を1つ足す。**
- 単発ステップ（1-4・2-5・3-1・4-1・4-10など）は従来どおり、そのステップを終えるたびに
  `mark-done`を呼んでよい。

### issueが大きすぎる場合の分割提案（issue #64）

1 issue = 1ブランチ = 1 MR がこのフローの単位である。**同型の成果物が並列に列挙された大きな
issue**をそのまま進めると、MRがレビュー可能な粒度を超え、フェーズ3以降でスコープが膨らんでも
軌道修正の契機が無くなる（実例: issue #24対応で、スコープ外としていた範囲を後から取り込むことに
なり全面書き直しが発生した。`.claude/docs/ddr/0013-dev-toolsをAI専用_人間専用に分離する.md`）。
AIエージェントは以下の基準で**分割を提案する**。**判断そのものは人間が行う**。

**主トリガー: 並列列挙構造**

issue本文・受け入れ条件が「AとBとCを作る」という**同じ種類の成果物の並び**になっている場合に
提案する。典型例は次のとおり。

- 画面・機能
- APIエンドポイント
- CLIサブコマンド
- バッチジョブ
- テーブル・マイグレーション
- 外部連携先

判定は次の一問に集約する。**「各項目が単独でマージされても、システムが壊れないか」**。
壊れないなら分割候補であり、壊れるなら次の「分割しない条件」に該当する。行数・受け入れ条件の
個数のような量的な尺度では判定しない（量が多くても不可分なissueはあり、少なくても独立した
成果物が並んでいることはあるため）。

**分割しない条件（誤爆防止）**

次のいずれかに該当する場合は分割を提案しない。

- **横断的変更**: 共通の型定義・スキーマ・認証基盤など、**同時に変えないと壊れるもの**。
  項目が並んで見えても単独でマージできないため、分割の対象ではない。
- **分割コストが本体を上回る**: 1件あたりが極小の場合。このフローはissue 1件につき
  **5フェーズ40ステップ**とレビュー往復という固定費がかかるため、分割すると本体の作業量より
  手続きのほうが大きくなることがある。
- **共通部分の先行実装が必要**: この場合は均等に割らず、**「基盤issue → 機能ごとのissue」**と
  いう依存順に割る（分割はするが、割り方が変わる）。

**issue分割と個別計画ファイル分割の切り分け**

「分ける」には2つの層がある。どちらを使うかは**マージの単位を分けたいかどうか**で決まる。

| やりたいこと | 使うもの |
|---|---|
| 各項目を**別々にマージ**したい（リリース単位・切り戻し単位を分けたい） | **issue分割**（本節） |
| 1つのMRでまとめてマージし、**レビューだけ分けたい** | **個別計画ファイルの分割**（上記「計画の2階層構造」） |

**判定タイミング**

- **主: flow-id 1-4**（全体作業計画の作成前）。issue全体を読み込む最初の機会であり、まだ
  ブランチ・Draft MRが1本しか無いため、割り直しの手戻りが最も小さい。
- **副: flow-id 1-1**（`issue-create` スキルでの起票時）。並列列挙構造は本文だけで検出できる
  ため、起票前に気づければブランチすら作らずに済む（手順:
  `.claude/skills/issue-create/SKILL.md`）。
- **フェーズ2で規模が判明した場合**: 調査（flow-id 2-6）で初めて規模が分かったときは、着手済みの
  範囲を現issueに残し、**未着手の範囲を新しいissueへ切り出す**ことを提案する。

**決定は人間が行う**

AIエージェントは**兆候と分割案を提示するに留める**。勝手に子issueを起票したり、スコープを削って
進めたりしない。提示は `AskUserQuestion` で行い、選択肢には最低限「分割する」「このまま1件で
進める」を含める。分割しない判断がされた場合は、その理由を全体作業計画と `HANDOFF.md` に残す
（同じ議論を後から蒸し返さないため）。

**分割することになった場合**

- **元issueは親として残し**、子issueへのリンクをチェックリスト（`- [ ] #NN`）で束ねる
  （元issueを閉じて作り直すと、議論の経緯が追えなくなるため）。
- 子issueの起票には `issue-create` スキルを使う。
- **共通部分を含む1件目を先に完了**させてから残りに着手する。並走させると共通部分がコンフリクト
  しやすく、DDR番号の重複（下記「defaultブランチとのコンフリクト検知・解消」）も起きやすい。

## PR/MR作成・マージの担当（flow-id 1-3・5-3・5-4）

**PR/MRの作成・更新はAIエージェントが実施してよい。マージのみユーザーの明示指示を必須とする**
（issue #41）。判断の根拠は「取り消せるか」で、PR/MRの作成・Draft解除・description更新はいつでも
取り消せて `main` を変えないのに対し、マージは `main` の正史を書き換える不可逆な操作である。

| 操作 | 担当 |
|---|---|
| Draft PR/MRの作成（flow-id 1-3）・description更新・レビュー依頼・レビュー返信・Draft解除（flow-id 5-3） | **AIエージェント**（都度の明示指示は不要） |
| マージ（flow-id 5-4） | **人間**。AIエージェントは明示的に指示された場合に限り実行してよい |

flow-id 5-3 を終えたAIエージェントは、フロー上マージが次の一手であっても**そこで止まる**。
「レビューが終わった」「Draftを解除した」「コンフリクトを解消した」はいずれもマージの指示ではない。

**ハーネス（実行基盤）のシステムプロンプトに「ユーザーが明示的に依頼しない限りPRを作成しない」
旨の指示がある環境**（Claude Code on the web のリモート実行環境等）では、ハーネス側の指示が優先
される。その場合の flow-id 1-3 の振る舞い（ブランチ作成まで進め、作成の可否を `AskUserQuestion` で
1回だけ確認する。応答を待てない非対話的セッションではPRを作成せず、その事実を最終応答へ明示する）は
`.claude/rules/git-workflow.md`「ハーネスがPR作成を制限する環境での扱い」が正である。

## サブコマンド

呼び出しは `/issue-mr-flow <サブコマンド> [引数]` の形。

**各サブコマンドは `gh`/`glab` CLIがある前提で書かれている。手順に入る前に必ず
`get_vcs_access_mode`（`Provider.sh`）で経路を確認し、`mcp` が返る環境では
「[`gh`/`glab` CLI不在時のMCPフォールバック](#ghglab-cli不在時のmcpフォールバック)」節の
読み替えに従うこと**（issue #34）。

### `start <issue番号>` — issue取得・ブランチ/MR作成（全体フロー 1-2〜1-3）

**起票（flow-id 1-1）の直後に、同じセッションで続けて `start` を実行してよいのは、ユーザーから
明示的な着手の指示があったときだけである**（issue #39）。`issue-create` スキルでAIが起票を代行した
場合も同じで、起票したこと自体は着手の指示ではない。AIから「続けて着手しますか？」と持ちかけず、
新しいセッションでの実行を勧めるに留める（起票と実装が同じセッションに同居すると、進行中の別issueの
ブランチ・MRと作業コンテキストが混ざるため。詳細:
`.claude/skills/issue-create/SKILL.md`「してはいけないこと」）。この前提は
`.claude/hooks/post-issue-create-notice.sh`（PostToolUse hook）の注意喚起でも補強されるが、
hookは多重防御であり、注入が無かったことは着手してよい根拠にならない。

1. `get_issue <issue番号>` でissueのtitle/body/urlを取得し、内容をユーザーに提示する。
   続けて `test_issue_sections "$(get_issue <issue番号> | jq -r '.body')"` を呼び、標準4見出し
   （目的・現状・期待する動作・受け入れ条件。`.github/ISSUE_TEMPLATE/task.md` /
   `.gitlab/issue_templates/Default.md` 参照）の過不足を確認する。欠けている見出しがあれば
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
     c. **Draft MRの作成に、ユーザーからの都度の明示指示は要らない**（issue #41。上記
        「PR/MR作成・マージの担当」節）。ただし、ハーネスのシステムプロンプトが「明示的に依頼
        されない限りPRを作成しない」と指示する環境では、ここで `AskUserQuestion` による確認を
        1回だけ挟む（`.claude/rules/git-workflow.md`「ハーネスがPR作成を制限する環境での扱い」）。
     d. `new_issue_branch <n> "<b.で考えた英語フレーズ>" [<base_branch>]` でブランチを作成・
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
   - 各行の角括弧内には `url=<コメントのパーマリンク>` が含まれる（issue #42）。**次のpush時の
     レビュー依頼メッセージへ「前回の指摘にどう返信したか」のリンクを載せるために使うので、
     返信したスレッドのURLは控えておくこと。**
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
   - **本関数は投稿した返信自身のパーマリンクを標準出力へ返す**（issue #42）。この
     URLをユーザーへ提示し、**次のpush時のレビュー依頼メッセージへ含める**
     （`post-push-compact-prompt.sh` の指示文でも同じことを促される）。
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
3. 提示した内容をもとに、全体フローの40ステップのうちどこから再開すべきかをAIエージェントが判断し、
   次にすべきことを提案する（この判断はサブエージェントではなく呼び出し元が行う）。
4. issue番号が特定できていればブランチ/MRの存在確認へ（`start` 手順2相当）、issueが特定できなければ
   ブランチ命名規則から外れている旨を伝えて `start <issue番号>` での対応を促す。

## `gh`/`glab` CLI不在時のMCPフォールバック

Claude Code on the webのリモート実行環境のように、`gh`/`glab` CLIが存在せず `git`・`jq` しか
使えない環境がある（issue #21対応時に実機確認）。この場合 `Provider.sh` のプロバイダ依存関数は
動かないため、GitHub公式のMCPサーバーツール（`mcp__github__*`）で代替する。**WebFetchツール・
curlへはフォールバックしない**（理由はDDR 0020のまま変わらない。経緯: DDR 0027）。

### 1. 経路の判定（各サブコマンドの最初に必ず行う）

```bash
source .claude/scripts/src/vcs/Provider.sh
get_vcs_access_mode   # → cli / mcp
```

- `cli`: 各サブコマンドに書かれているとおり `Provider.sh` の関数をそのまま使う。
- `mcp`: 下の対応表に従って読み替える。**その場の判断で別のツールを選ばない。**

判定を忘れてCLI経路の関数を呼んだ場合も、`require_vcs_cli` ガードが
「代替すべきMCPツール名・引数」をstderrへ出して失敗するため、そのメッセージに従えばよい
（`gh: command not found` のような手がかりの乏しい失敗にはならない）。

MCPツールが必須で要求する `owner` / `repo` は、CLIなしで次のように取得する。

```bash
get_repo_slug            # → {"host":...,"owner":...,"repo":...,"path":...,"url":...}
get_repo_slug | jq -r '.owner, .repo'
```

### 2. Provider関数 → MCPツール対応表（GitHubのみ）

| Provider関数（CLI経路） | MCPツール | 引数 | 補足 |
|---|---|---|---|
| `get_issue <n>` | `mcp__github__issue_read` | `method="get"`, `owner`, `repo`, `issue_number=<n>` | 返却JSONの `title`/`body`/`html_url` を、CLI版の `title`/`body`/`url` と読み替える |
| `new_issue <title> <body>` | `mcp__github__issue_write` | `method="create"`, `owner`, `repo`, `title`, `body` | `issue-create` スキル（`create-issue.sh`）の代替。本文は `build_issue_body` 相当の4見出しで組み立てる |
| `search_issues <キーワード...>` | `mcp__github__search_issues` | `query="<キーワード（複数可）>"`, `owner`, `repo` | `issue-create` スキルの起票前重複チェック（issue #68）の代替。**CLI版と違い、キーワードごとに呼び分ける必要はない**（自然言語のセマンティック検索で、既に `is:issue` にスコープされている）。1回の `query` に複数キーワードを平文で並べる。closedのissueも対象にしたいので `state` で絞り込まないこと。返却の `number`/`title`/`state`/`html_url` を、CLI版の `number`/`title`/`state`/`url` と読み替える |
| `new_draft_merge_request <n> <branch> <title> [<base>]` | `mcp__github__create_pull_request` | `owner`, `repo`, `title`, `head=<branch>`, `base=<base>`, `draft=true`, `body="Closes #<n>\n\n(plan作成中。/issue-mr-flow describe で更新する)"` | baseとの差分が無いと失敗する制約はMCP経路でも同じ。失敗したら `source .claude/scripts/src/vcs/Provider.sh && add_empty_commit_for_draft_mr` を実行してから1回だけ再試行する |
| `get_mr_for_branch <branch>` | `mcp__github__list_pull_requests` | `owner`, `repo`, `head="<owner>:<branch>"`, `state="open"` | 結果が空配列ならPRなし。`number`/`html_url`/`draft`/`title` を使う |
| `get_mr_unresolved_comments <n> [true]` | `mcp__github__pull_request_read` | `method="get_review_comments"`, `owner`, `repo`, `pullNumber=<n>` | スレッドごとに `isResolved` が付くので、**既定では `isResolved=false` のスレッドだけを提示する**（CLI版の「解決済みは機械的に除外」に相当）。`all` 指定時は全件。通常コメントは `method="get_comments"` を追加で呼ぶ。**コメントのパーマリンク（CLI版の `url=...`）は返却JSONの `html_url` を使う**（issue #42） |
| `add_mr_thread_reply <n> <threadId> <body>` | `mcp__github__add_reply_to_pull_request_comment` | `owner`, `repo`, `pullNumber=<n>`, `commentId=<返信先スレッドの先頭コメントの数値ID>`, `body` | **ID体系が違う。** CLI経路はGraphQLのthreadId（`PRRT_...`）を使うが、MCP経路は数値のcommentId（`#discussion_r...` の数字部分）を使う。`get_review_comments` の各スレッドに含まれるコメントのidを使うこと。**投稿した返信のURL（CLI版の戻り値）は、返却JSONの `html_url` を使う**（issue #42） |
| `set_mr_description <n> <file>` | `mcp__github__update_pull_request` | `owner`, `repo`, `pullNumber=<n>`, `body=<ファイルの内容>` | CLI版はファイルパスを渡すが、MCPは文字列で渡す。本文はReadツール等で読んでから渡す |
| `set_mr_ready <n>` | `mcp__github__update_pull_request` | `owner`, `repo`, `pullNumber=<n>`, `draft=false` | `set_mr_description` と同じツールだが渡す引数が違う。`draft=false` が「Draftを解除しレビュー可能にする」の意味（flow-id 5-3。issue #61） |
| `add_mr_comment <n> <file>` | `mcp__github__add_issue_comment` | `owner`, `repo`, `issue_number=<PR番号>`, `body=<ファイルの内容>` | PR番号を `issue_number` に渡す（GitHub APIの仕様上、PRもissueとして扱える） |
| `get_repo_url` | （MCP不要） | — | `git remote get-url origin` の正規化だけでリポジトリの正規URLを導出するプロバイダ非依存の関数のため、MCP経路でもそのまま呼べる（`get_mr_diff_url` / `get_mr_diff_since_url` も同様。issue #44） |
| `new_issue_branch` / `sync_branch` / `get_branch_work_files` / `get_issue_number_from_branch` / `to_slug` / `test_issue_sections` | （MCP不要） | — | git操作・純粋ロジックのみでCLIに依存しないため、MCP経路でもそのまま呼べる |

### 3. サブコマンドごとの読み替え

| サブコマンド | MCP経路での差分 |
|---|---|
| `start <n>` | 手順1の `get_issue` を `mcp__github__issue_read` に置き換える。`test_issue_sections` はbody文字列を渡せばそのまま使える。手順2のブランチ検索（`git branch --list` / `git ls-remote`）と `new_issue_branch` は変更なし。Draft PR作成のみ `mcp__github__create_pull_request` に置き換える |
| `comments [all]` | MR番号の取得を `mcp__github__list_pull_requests`、コメント取得を `mcp__github__pull_request_read` に置き換える。**未解決のみを既定で提示する絞り込みは、CLI版ではスクリプトが行っていた処理なので、MCP経路では自分で `isResolved` を見て行う。** コメントのパーマリンクは `html_url` から取る（issue #42） |
| `reply <threadId> <対応内容>` | 返信先の指定が数値のcommentIdになる（上表の補足参照）。**`Claude Codeより:` の署名行を先頭に付ける規約はMCP経路でも同じ**（MCPサーバーもユーザーの認証情報で動くため、投稿者は人間のアカウントとして表示される）。投稿後に返る `html_url` が返信のパーマリンクで、次のpushのレビュー依頼メッセージへ含める（issue #42） |
| `describe` | descriptionを一時ファイルへ書く手順は同じでよいが、最後は `mcp__github__update_pull_request` の `body` へ文字列として渡す |
| `sync` | 変更なし（git操作のみ） |
| `resume` | サブエージェント（`issue-mr-resume`）はProvider.sh経由でのCLI利用を前提とするため、MCP経路ではissue/PR情報の取得部分が失敗する。その場合はサブエージェントの報告のうちgit・ファイル系（ブランチ・plans/worklog・HANDOFF.md）を採用し、issue/PR情報は呼び出し元が上表のMCPツールで補う |

### 4. hookの挙動（CLI不在時）

hookはMCPツールを呼べないため、以下のように非侵襲的に縮退する（詳細:
`.claude/docs/spec/issue-mr-workflow.md`）。エージェント側で肩代わりが必要なものはその旨が
メッセージに出る。

| hook | CLI不在時 |
|---|---|
| `session-start.sh` | issue/PR情報の代わりに「経路はMCP」「ブランチ名から抽出したissue番号」「owner/repo」「本節への参照」を注入する |
| `post-push-usage-report.sh` | 集計状態の更新のみ行い、対応工数レポートの自動投稿はスキップする（stderrへ1行） |
| `post-push-compact-prompt.sh` | MRリンクだけを「MCPで取得すること」に差し替え、レビュー依頼メッセージと `/compact` の呼びかけは従来どおり行う。重点レビュー対象ファイルのリンク（issue #42）は `get_repo_url` のローカル組み立てとgit操作だけで作れるため、CLI不在時もそのまま供給される |
| `post-issue-create-notice.sh` | 縮退しない。CLI経路（`create-issue.sh` の実行）に加えMCP経路（`mcp__github__issue_write` の `method="create"`）も検知するため、CLI不在時も同じ注意喚起が出る（issue #39） |

### 5. GitLabは対象外

`glab` 不在時のGitLab向けMCP代替は**対象外**とする（このリポジトリでGitLab MCPサーバーの
利用実績が無く、ツール名・引数を検証できないため。未検証の対応表は誤誘導になりうる）。
GitLabリポジトリで `glab` が無い場合、`require_vcs_cli` はその旨を明示して失敗する。
`glab` をインストール・認証して使うこと。将来GitLab MCPサーバーを実機検証できた時点で、
本節に同じ形式の対応表を追加してよい（DDR 0027）。

## レビュー完了合図の確認（全体フロー 2-4・2-9・3-4・3-9・4-4・4-9）

人間から「レビューOK」「合意」等、レビューループを終えて次のステップに進んでよいという合図を
受けても、それだけを根拠に次のステップへ進んではいけない。**必ず `comments all`
（`get_mr_unresolved_comments <n> true`）でスレッドを再取得し、`unresolved` のスレッドが
残っていないか確認する。**

- 残っていなければ、そのまま次のステップに進む。
- 残っていれば、その旨（対象スレッドと内容）を人間に伝えて再確認を取り、解消されるまで次の
  ステップには進まない（GitHub/GitLabのスレッド解決自体はレビュアー側の操作であり、`reply` は
  解決を行わないため、返信済みでも `unresolved` のまま残ることがある）。

## defaultブランチとのコンフリクト検知・解消（flow-id 5-2）

マージ依頼（Draft解除）へ進む前に、**必ずdefaultブランチとの間にコンフリクトが無いことを確認する**
（issue #46）。過去4回、コンフリクトの存在に気づいたのが人間のマージ操作時になっており、
その都度その場の判断で解消していた。手順は `resolve-conflict` スキル
（`.claude/skills/resolve-conflict/SKILL.md`）を正とし、本節はフロー上の位置づけと分岐のみを定める。

1. **検知**（作業ツリーを変更しない）

   ```bash
   bash .claude/scripts/src/check-base-conflicts.sh
   ```

   判定結果のJSONの `hasConflict` を見る。**`git status` や `git merge` の結果で代用しない**
   （下記の理由により、gitが「コンフリクト無し」と報告する種類の衝突があるため）。

2. **`hasConflict` が `false`**: そのまま flow-id 5-3（commit・push・Draft解除）へ進む。

3. **`hasConflict` が `true`**: `AskUserQuestion` で「コンフリクトがあるので解消してよいか」を
   ユーザーに確認する。質問文には検知内容（対象ファイル・重複したDDR番号）を具体的に含める。
   ユーザーが承認したら `resolve-conflict` スキルを実行して解消してから flow-id 5-3 へ進む。
   承認されなければ、コンフリクトが残ったままである旨を明示して 5-3 へ進む。

**gitが検知できない衝突がある。** 両ブランチがそれぞれ新しいDDRを追加すると、`0027-A.md` と
`0027-B.md` のようにファイル名が異なるため、gitはコンフリクトを報告せず**無言で両方をマージする**
（結果として同じ番号のDDRが2つ並ぶ）。過去の4件はいずれもこの形であり、
`check-base-conflicts.sh` はテキストコンフリクトとは別に**DDR番号の重複**を直接調べる
（仕様: `.claude/docs/spec/check-base-conflicts.md`、経緯:
`.claude/docs/ddr/0029-defaultブランチとのコンフリクトは検知を機構化し解消手順をスキル化する.md`）。

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
   次タスク向けの空テンプレートへリセットする（内容はflow-id 5-1で行うものと同じ）。
4. commit・pushし、`main`を対象にPRを作成する。**PRの作成は他のPR操作と同様AIエージェントが
   行ってよく、都度の明示指示は要らない**。**マージのみ**、ユーザーから明示的な指示を受けてから
   実行する（上記「PR/MR作成・マージの担当」節、`.claude/rules/git-workflow.md`「PR・マージ」節）。

## 詳細ルールへのポインタ

全体フローの各ステップに関わる詳細は、以下の既存ルールを参照する（このファイルは順序立った
フローの定義に専念し、内容の重複は避ける）。

- ドキュメントの置き場所・ライフサイクル（`plans/` `worklog/` `.claude/docs/spec/` `.claude/docs/ddr/` `HANDOFF.md`）:
  `.claude/rules/docs-workflow.md` の「ドキュメント運用」表
- ブランチ命名規則・squash mergeの方針・コミット運用（`commit`スキル必須使用・PreToolUse hookに
  よる技術的強制）・PR/MR作成とマージの担当（ハーネスがPR作成を制限する環境での扱いを含む）:
  `.claude/rules/git-workflow.md`
- bashスクリプトの規約（`set -euo pipefail`・jq前提・改行/エンコーディング等）:
  `.claude/rules/shell-script-style.md`
- `Provider.sh`の設計・スクリプト言語選定方針（bash化できる/できない判断基準）:
  `.claude/docs/spec/shell-scripts.md`

## 前提

- `gh` CLI（GitHubの場合）または `glab` CLI（GitLabの場合）、および `jq` がインストール・認証済みであること。認証情報自体は各CLIの既存ログイン状態に依存し、本スキル側では管理しない。
  **CLIが存在しない実行環境（Claude Code on the webのリモート実行環境等）では、GitHubに限り
  MCPサーバーツールで代替できる**（上記「`gh`/`glab` CLI不在時のMCPフォールバック」節。GitLabは対象外）。
- リポジトリ直下に `.mrworkflow.json` があること（無い場合は `.claude/scripts/src/vcs/Provider.sh` の既定値が使われる）。
- issueは `.github/ISSUE_TEMPLATE/task.md`（GitHub）/ `.gitlab/issue_templates/Default.md`（GitLab）のテンプレートに沿って「目的・現状・期待する動作・受け入れ条件」を記載しておくことが望ましい
  （必須ではなく、`start` サブコマンドが欠落を警告する）。
- Claude Code/GeminiCLIのセッションとMRの関係性については、多:1の関係を許容する（1つのMRに対して複数セッションを切り替えて作業してもよい）。
  ただし、1:多は想定しない。つまり、同一セッション内で複数MRを同時に扱うことはできない（`resume` は1つのMRに対してのみ現在地確認を行うため）。
