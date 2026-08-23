---
title: markdownのYAML frontmatter規約
type: rule
description: リポジトリ内markdownドキュメントに付与するOpen Knowledge Format風frontmatterのキー定義・type値一覧・例外ルール
tags: [markdown, frontmatter, rule]
keywords: [okf, frontmatter, フロントマター, キー定義, 開放知識形式, 対象外ファイル, タイプ, keywords]
---

# markdownのYAML frontmatter規約

issue #7対応。リポジトリ内の各markdownファイルに、ファイル種別・要約・タグ等を機械可読な形で
持たせることで、将来的な一覧化・検索・ツール連携をしやすくする。

## キー定義

OKF（Open Knowledge Format、https://okf.md/spec/ ）のフィールド定義に沿って各キーの意味を記載する。

| フィールド | 必須/推奨 | 説明 |
|---|---|---|
| `type` | 必須 | コンセプトのタイプを特定する短い文字列。ルーティング・フィルタリングに使う。中央登録は無く、値は本リポジトリで自由に定義する（値は下表「typeの値」参照） |
| `title` | 推奨 | 人間が読みやすい名前 |
| `description` | 推奨 | 1文でコンセプトを要約する。将来的な一覧化・インデックス生成に使う |
| `resource` | 推奨 | 実リソース（外部URL・社内配布先・BigQueryテーブルURI等）を一意に識別するURI。抽象的な概念や、対応する実リソースが無いファイルではキー自体を省略してよい（空文字列は使わない） |
| `tags` | 推奨 | 横断的カテゴリ分類用の文字列リスト（kebab-case、2〜4個程度。ディレクトリ・技術要素・工程等を表す） |
| `keywords` | 推奨 | OKF標準にはない拡張フィールド。本文中の頻出語・特徴的な語を検索用途で3〜20個（文章量に応じて増減、平均的な長さの文章なら10個前後）リスト形式で記載する。日本語で書かれたファイルでは、英語の技術用語のみに偏らず日本語の単語もバランスよく含める |
| `status` | DDRのみ・任意 | その意思決定が現在も有効かを表す（下記「DDRのstatus」参照）。省略時は有効（`active`）とみなす |
| `superseded_by` | DDRのみ・条件付き必須 | `status: superseded` のときに、置き換えた側のDDRの識別子を書く（例: `"i0133-01"`。下記「DDRの識別子」参照） |
| `note` | DDRのみ・任意 | `.claude/docs/README.md` のDDR一覧で、そのDDRの行の末尾へ添える散文の補足（下記「DDRのnote」）。1行で書く |

## DDRの識別子（ファイル名・`title`）

DDRは**issue番号ベースの識別子**で識別する（issue #133。経緯・却下案:
`.claude/docs/ddr/i0133-01-DDR識別子はissue番号ベースにし連番採番をやめる.md`）。

```
.claude/docs/ddr/i0133-01-DDR識別子はissue番号ベースにし連番採番をやめる.md
                 ~~~~ ~~
                 |    枝番: 2桁ゼロ埋め、01から。1件しか作らない場合も省略しない
                 issue番号: GitHub/GitLabが採番した番号を4桁ゼロ埋め（#133 → 0133）
```

| 書く場所 | 書式 | 例 |
|---|---|---|
| ファイル名 | `i<issue番号>-<枝番2桁>-<タイトル>.md` | `i0133-01-DDR識別子はissue番号ベースにし連番採番をやめる.md` |
| frontmatterの `title` | `i<issue番号>-<枝番2桁>. <タイトル>` | `title: i0133-01. DDR識別子はissue番号ベースにし連番採番をやめる` |
| 本文冒頭の見出し | `# i<issue番号>-<枝番2桁>. <タイトル>` | `# i0133-01. DDR識別子はissue番号ベースにし連番採番をやめる` |
| `superseded_by` | 置き換えた側の識別子（文字列） | `superseded_by: "i0133-01"` |

**なぜissue番号なのか**: 以前は4桁の連番（`0027-…md`）だったが、分散したブランチ上で共有の
単調増加カウンタを採番する方式のため、2つのブランチが同時に新しいDDRを追加すると**必ず**同じ番号に
なった。ファイル名が異なるためgitはコンフリクトと見なさず無言でマージするので、検知する仕組み
（`check-base-conflicts.sh`）と改番する手順（`resolve-conflict` スキルの類型A）を用意していたが、
過去4回（PR #29 / #37 / #49 / #52）すべてこの形で発生していた。issue番号は
**GitHub/GitLabが中央で採番する**ため、別ブランチ同士で同じ値になることが原理的に無い。

### 決めごと

- **枝番は1件しか作らない場合も必須**（`i0133-01`）。省略可にすると、後から2件目を足すときに
  1件目の改番が要る。改番は「DDRの本文は一度マージしたら変更しない」原則と、参照の追従漏れという
  今回無くしたリスクを、そのまま呼び戻してしまう。
- **枝番は同一issue（＝同一ブランチ）内で 01 から順に振る。** 同じissueへの追加作業を後日別の
  ブランチで行う場合は、defaultブランチに既にある最大の枝番の次から振る。
- **issue番号は4桁へゼロ埋めする**（`#133` → `i0133-01`）。**ファイル名の辞書順を数値順と
  一致させるため**である。`.claude/docs/README.md` のDDR一覧は `generate-ddr-list.sh` が
  ファイル名の昇順（`LC_ALL=C`）で生成する（issue #135）ため、ゼロ埋めしないと `i99-01` が
  `i133-01` より後ろに並ぶ。**issue番号が9999を超えたら5桁で書く**（桁数が増える側が辞書順で
  必ず後ろに来るので、4桁と5桁が混在しても順序は保たれる）。`check-base-conflicts.sh` の
  `ddr_identifier_to_reply` は**4桁未満を「DDRではない」として弾く**。ゼロ埋め漏れを通すと、
  同じDDRが `i133-01` と `i0133-01` の2つの識別子を持ちうるためである。
- **DDRはissueを起点とするフローの成果物なので、issue番号を持たないDDRは作らない。**
  記録したい意思決定があってissueが無い場合は、先にissueを起票する（`issue-create` スキル）。
- **接頭辞は小文字の `i` で固定**（`I133-01` や `issue133-01` は認めない）。表記の揺れを許すと、
  同じDDRが別の識別子として二重に採番されうる。`check-base-conflicts.sh` の
  `ddr_identifier_to_reply` も小文字の `i` ＋ 4桁以上のissue番号 ＋ 枝番ちょうど2桁だけを識別子として受け付ける。

### 対応issueを持たないDDR（`i0000`）

**issue番号 `0000` は「対応するissueが存在しない」ことを表す予約番号**である。issue #133 で既存の
連番DDRを一括改番した際、次の13件がこれに該当した。

- `i0000-01` / `i0000-02` — 移植元プロジェクトの **PR #4** から生まれた決定で、issueが存在しない。
- `i0000-03`〜`i0000-12` — 本文が名乗るissue番号が**移植元プロジェクトのもの**で、本リポジトリの
  同番号issueとは別物だった（例: 旧 `0014` は「issue #48: 調査結果をHTMLでも残す」と書いていたが、
  本リポジトリの #48 は「Gitlab.shに実機検証で判明した3件の不具合がある」）。
- `i0000-13` — issue・PRのどちらも記載が無い。

**`i0000` の枝番だけは、issueごとではなくリポジトリ全体の通し番号である**（`i0000-01`〜`i0000-13`）。
`i0000` は特定のissueを指さないため「同一issue内で01から」という原則が働かないためである。

- **新しく `i0000` を採番しない。** 今後のDDRは必ずissueを起点とするフローの成果物なので、
  issue番号を持つ（上記「決めごと」）。`i0000` は移植時に持ち込んだ13件だけの、閉じた集合である。
- `i0000` のDDRを参照するときも、他と同じく識別子（`i0000-06`）で書く。

### 旧方式（4桁連番）の扱い

**リポジトリ内に4桁連番のDDRはもう存在しない**（issue #133 で全56件を改番した）。ただし
`check-base-conflicts.sh` の `ddr_identifier_to_reply` は**旧形式も引き続き受け付ける**。
他プロジェクトへ配布したこの機構が旧形式のDDRを抱えている可能性と、改番前のブランチが
残っている可能性があるためである。

- 新旧は**先頭が数字かどうか**で機械的に区別できる（`^[0-9]{4}-` にマッチするのが旧、
  `^i[0-9]{4,}-[0-9]{2}-` にマッチするのが新）。
- **過去の記録として書かれた連番は書き換えない。** 具体的には、当時のコミットメッセージの引用
  （`chore: mainをマージしDDR番号を0028へ繰り下げて…`）、過去に重複した番号の一覧、
  `0034→0035→0036→0038` のような繰り下げの経過である。これらはファイルを指しておらず、
  書き換えると当時何が起きたかが読めなくなる。

### 識別子が重複しうる残りのケース

新方式でも、**同一issueへの追加作業を2つのブランチで並行して行った場合**は、どちらも同じ枝番
（例: どちらも `i0133-03`）を採りうる。枝番だけはローカルで決めるためである。頻度は連番方式とは
桁が違うが、ゼロではない。このため `check-base-conflicts.sh` の重複検知と `resolve-conflict`
スキルの類型Aは**廃止せず残している**（旧形式のDDRを抱えた配布先・改番前のブランチを拾う役目もある）。

## DDRのstatus（後から無効になった意思決定の扱い）

DDRは**本文を一度マージしたら変更しない**運用だが、**YAML frontmatterのみは後から更新してよい**
（issue #9で決定）。後続の意思決定によって無効になったDDRに、その事実を機械可読な形で残すため。

| `status` | 意味 | 併記するキー |
|---|---|---|
| （省略） / `active` | 現在も有効。**通常はキー自体を書かない** | — |
| `superseded` | 後続のDDRによって置き換えられた | `superseded_by: "<識別子>"` |
| `deprecated` | 置き換え先を持たずに廃止された（その決定自体が不要になった等） | — |

```yaml
---
title: i0000-06. Planモードre-entry時はgit checkout復元でなくarchiveスクリプトで対処する
type: ddr
status: superseded
superseded_by: "i0009-01"
description: <元のまま変更しない>
---
```

**`description` は書き換えない。** `description` は「そのDDRが何を決めたか」の要約であり、
一覧・検索・`index.jsonl` から参照される。無効化の情報で上書きすると、元の決定内容が読み取れなく
なってしまう。無効化の事実は `status` / `superseded_by` という専用キーで表現し、両方の情報を残す。

値に `disabled` ではなく `superseded` / `deprecated` を使うのは、DDRの元になったADR
（Architecture Decision Record）で広く使われている語彙に合わせるため（読み手が初見でも意味を
推測でき、外部ツールとも揃う）。

`status` / `superseded_by` を更新したら、**`bash .claude/scripts/src/generate-ddr-list.sh` を
実行して `.claude/docs/README.md` のDDR一覧を再生成する**（一覧の注記はこの2キーから生成される。
issue #135。手書きで注記を添えない）。

## DDRのnote（一覧へ添える散文の補足）

`.claude/docs/README.md` のDDR一覧は**生成物**であり、手書きで行を足さない（issue #135。
生成: `bash .claude/scripts/src/generate-ddr-list.sh`、仕様:
[.claude/docs/spec/generate-ddr-list.md](../docs/spec/generate-ddr-list.md)）。

一覧の各行は、そのDDRのfrontmatterだけから決まる。`status` / `superseded_by` から導けない
**散文の補足**を一覧へ出したい場合は、`note` キーへ書く。**READMEを直接編集しても次の生成で
消える**ため、注記の置き場はここが唯一である。

```yaml
---
title: 0022. push断面の全文コピーをやめ行番号インデックスで表現する
type: ddr
description: <元のまま変更しない>
note: 'うち「Gemini CLI対応の扱い」は、issue #97でメインセッションのみ集計対象へ変更された。詳細は0054'
---
```

- **値は1行で書く**（複数行のYAMLスカラーは読まない）。
- `description` の代わりに使わない。`description` は「そのDDRが何を決めたか」の要約で、
  `note` は「その後どう変わったか・読むときの注意」を添えるものである。
- `status` 由来の注記と併記した場合、一覧では **status由来が先、`note` が後**に並ぶ。
- `note` の追加・変更は frontmatter のみの更新であり、**DDR本文を変更しない**運用に反しない
  （上記「DDRのstatus」と同じ扱い）。

### 何を書くか

一覧を読む人が**そのDDRを開く前に知っておくべきこと**のうち、**他のキーからは導けないもの**
だけを書く。実際に使うのは次の類型である。

| 類型 | 例 |
|---|---|
| **決定の一部だけが後で変わった**（全体の置き換えではないので `status: superseded` は使えない） | 「うち『Gemini CLI対応の扱い』は、issue #97でメインセッションのみ集計対象へ変更された。詳細は0054」（`0022`） |
| **タイトル・ファイル名が現在の呼称と食い違う** | 「ファイル名の `flow-id5-1` は当時の番号。片付けは issue #112 の並べ替えで 5-3 になり、issue #111 の統括レポート追加で 5-4、issue #70 の変換同期の新設でさらに繰り下がって現在 flow-id 5-5。DDR i0112-01・i0111-01 参照」（`i0028-01`） |
| **本文を読むときの前提が変わった**（前提にしていた仕組み・用語が今は別物になっている等） | 「前提としていた〇〇は廃止済み。△△へ読み替えること」 |

いずれも「**その後どう変わったか／読むときに注意すること**」であり、後続の変更を追った人が
気づいた時点で足す。DDRを書いた本人が最初から埋めるキーではない。

書かないもの:

- **`status` / `superseded_by` で表せること**（「0019に置き換えられた」等）。一覧には
  status由来の注記が自動で出るため重複する。
- **そのDDRが何を決めたかの要約**。それは `description` の役割である（上記）。
- **本文を読めば分かる詳細**。`note` は一覧の1行に収まる長さに留め、開くべきかの判断材料にする。
- **やがて古くなる進捗**（「issue #NN で対応中」等）。DDRと同じく永続する前提で書く。

## index.jsonl（frontmatterの機械可読インデックスと検索）

`index.jsonl`（`.claude/scripts/src/extract-frontmatter.sh` が生成するfrontmatterの機械可読
インデックス）は**Git管理下に置かず、生成物として扱う**（issue #36。`.gitignore`の
`**/index.jsonl`対象）。`.claude/hooks/session-start.sh`（SessionStart hook）が**セッション開始の
たびに自動で再生成する**ため、frontmatterを更新した際に手動で `extract-frontmatter.sh` を
実行する必要はない（詳細:
[.claude/docs/ddr/i0036-01-frontmatterのindex.jsonlをGit管理から外しSessionStart-hookで生成する.md](../docs/ddr/i0036-01-frontmatterのindex.jsonlをGit管理から外しSessionStart-hookで生成する.md)）。

同一セッション内でfrontmatterを編集し、その場ですぐ最新の `index.jsonl` を参照したい場合や、
自動再生成を待たず手元で確認したい場合は、以下を手動実行してもよい（必須ではない）。

```bash
bash .claude/scripts/src/extract-frontmatter.sh .
```

- **通常はリポジトリルート（`.`）を指定して1回流せばよい。** mtimeが変わっていないファイルは
  前回の結果を再利用するため、差分が無ければ2秒未満で終わる（issue #11）。ディレクトリを絞る
  必要は無い。
- **`--force` は通常不要。** スクリプト自身を変更した場合はキャッシュが自動で無効化される。
  `--force` を使うのは、mtimeを保ったままファイル内容が変わった等、キャッシュを信用できない
  特殊なケースに限る。
- 仕様の詳細は
  [.claude/docs/spec/extract-frontmatter.md](../docs/spec/extract-frontmatter.md) を参照。

**生成された `index.jsonl` は、ドキュメントを探すための検索インデックスとして使う**（issue #38）。
`type` / `tags` / `keywords` / パス / フリーテキストでの絞り込みと、mtime等での並び替えが
`bash .claude/scripts/src/search-frontmatter.sh` で行える（最新化も兼ねるため、上記の
`extract-frontmatter.sh` を先に実行する必要はない）。**リポジトリ内のドキュメントを探すときは、
`grep`/`find`による全文探索より先にこちらを使う**（`AGENTS.md`のルール。使い方・jqレシピは
[.claude/skills/doc-search/SKILL.md](../skills/doc-search/SKILL.md)、仕様は
[.claude/docs/spec/search-frontmatter.md](../docs/spec/search-frontmatter.md)）。
ここで定める `description` / `keywords` の質が、そのまま検索の当たりやすさになる。

新規markdown作成時は原則このfrontmatterを付与する。既存のfrontmatterを持つファイル（後述）は
既存キーを変更せず、不足しているキーのみを追記する。

## typeの値

| type | 対象 |
|---|---|
| `ddr` | `.claude/docs/ddr/*.md` |
| `rule` | `.claude/rules/*.md`, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` |
| `agent` | `.claude/agents/*.md` |
| `skill` | `.claude/skills/*/SKILL.md` |
| `skill-reference` | `.claude/skills/*/references/*.md`（SKILL.mdから切り出したバンドルリソース。issue #160） |
| `plan` | `wip/plans/*.md`（planツールが出力する全体作業計画・`【種別】`付きの個別計画の両方。issue #95。同ディレクトリの`*.html`は対象外。下記「HTMLビューは対象外」） |
| `log` | `wip/worklogs/*.md` |
| `report` | `wip/reports/*.md`（調査結果・作業結果・反映結果の正文。issue #87。同ディレクトリの`*.html`はfrontmatterを持たないため対象外。下記「HTMLビューは対象外」） |
| `guide` | `README.md`, `DEVELOPERS.md`, `.claude/docs/README.md`, `index.md` |
| `handoff` | `HANDOFF.md` |
| `spec` | `.claude/docs/spec/*.md` |
| `review-points` | `**/REVIEW-POINTS.md`（配布元所有）と `**/REVIEW-POINTS.local.md`（配布先所有。issue #26）。いずれも各ディレクトリ直下のレビュー観点表（issue #77） |

アプリ本体を追加し、専用の`docs/spec/`・`docs/ddr/`・`docs/README.md`（必要なら`dev-tools/docs/`
配下も）を新設した場合は、上表に対象パスを追記する。

`type`の値は自動判定せず、ファイルごとに内容を見て個別に決定する。上表は現時点の割り当て例であり、
新しいディレクトリ・用途が増えた場合はこの表に追記する。

### HTMLビューは対象外（issue #54）

**`wip/plans/*.html` と `wip/reports/*.html`（人間レビュー用のHTMLビュー）は、frontmatterの対象外である。**
「typeの値」表への行追加も要らない。

- **HTMLはYAML frontmatterを持てない。** markdownと違い、先頭の `---` に囲まれたブロックが
  ページ本文としてそのまま表示されてしまう。
- **そもそもインデックスに載らない。** `extract-frontmatter.sh` の走査対象は `.md` だけで
  （`git ls-files ... | grep -z '\.md$'`）、`.html` は `index.jsonl` に現れない。実際に
  `plans/` へ `.html` を置いて `extract-frontmatter.sh` を実行し、`index.jsonl` に載らないことを
  確認済み（issue #54 のフェーズ2調査 Q7）。
- 同じ理由で、**テンプレート本体**（`.claude/skills/issue-mr-flow/assets/*.template.html`、
  `.claude/skills/canvas-report/assets/canvas-report.html`）も対象外である。

**HTMLビューの説明・使い方は、frontmatterではなくファイル冒頭のHTMLコメントに置く**
（テンプレートがその形を持っている。詳細:
`.claude/skills/issue-mr-flow/references/deliverables.md`「計画・レポートのHTMLビュー」）。

`plan`・`log`・`report` は、いずれもタスク（issue／ブランチ）単位で作られ flow-id 5-5 でまとめて
削除される寿命の短いファイルに与える値であり、永続する案内ドキュメントの `guide` とは区別する
（`.claude/rules/docs-workflow.md` のライフサイクル表と対応する）。issue #95以前は `plans/*.md`
についての規定が無く、実際には `guide` / `log` / `plan` / frontmatter無しが混在していたため、
専用の値 `plan` を新設して一意に定めた（経緯・却下案:
[.claude/docs/ddr/i0095-01-plans配下のfrontmatter-typeはguideではなくplanを新設する.md](../docs/ddr/i0095-01-plans配下のfrontmatter-typeはguideではなくplanを新設する.md)）。

## 対象外・特殊対応ファイル

以下は既に別スキーマのfrontmatterを持つか、機能上frontmatterの追加が適さないため、通常の
4〜6キーをそのまま追加しない。

| ファイル | 扱い | 理由 |
|---|---|---|
| `.gitlab/issue_templates/Default.md` | **対象外**（frontmatter追加しない） | GitLabはissueテンプレートのfrontmatterを特別扱いしないため、追加すると issue作成のたびに本文へYAMLがそのまま挿入されてしまう |
| `.github/ISSUE_TEMPLATE/task.md` | **対象外**（frontmatter追加しない） | GitHub仕様の`title`等の既存frontmatterと衝突・干渉するため。issueテンプレートにOKF frontmatterは不要と判断した |
| `.github/pull_request_template.md` | **対象外**（frontmatter追加しない） | issueテンプレートと同じ理由。PR作成のたびに本文へYAMLがそのまま挿入されてしまう（issue #33） |
| `.gitlab/merge_request_templates/Default.md` | **対象外**（frontmatter追加しない） | 同上（issue #33） |
| `.claude/agents/*.md` | `title`/`type`/`tags`/`keywords`/（該当すれば`resource`）のみ追加。`description`は追加しない | 既存の`description`はClaude Codeがサブエージェント選択に使う実キーのため、重複させず流用する |
| `.claude/skills/*/SKILL.md` | 同上 | 同上（skill選択に使う`description`を保持） |
| `.claude/rules/*.md`のうち`alwaysApply: true`を持つファイル | 既存キーの下に新キーを追記する | `alwaysApply`はClaude Codeのルール常時適用設定として実際に使われるため、値・位置を変更しない |

いずれも既存のfrontmatterブロックは1つのまま、新キーを既存キーの下に追記する形にし、既存キーの
値・順序は変更しない。

## 新規ファイル作成時のフォーマット例

```yaml
---
title: <ファイルの題名>
type: <上表のtype値>
description: <1行要約>
resource: <対応する実リソースがあれば記載。無ければキー自体を省略>
tags: [<kebab-caseのキーワード, 2〜4個>]
keywords: [<本文の頻出語・特徴語, 3〜20個（目安10個）>]
---
```
