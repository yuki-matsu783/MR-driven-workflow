---
title: 個別作業計画 — SKILL.mdのreferences分割と参照タイミングの機械化（issue #160）
type: plan
description: SKILL.mdを本文とreferences/7ファイルへ切り出し、全体フロー表の参照列とSessionStart hookで読むタイミングを機械的に決めるフェーズ3の作業計画
tags: [issue-mr-flow, skill, plan, session-start]
keywords: [references分割, 参照列, flow-id解決, frontmatter, Provider.sh, describe抽出, 参照追従, 機械置換の禁止, テスト新設]
---

# 個別作業計画 — SKILL.mdのreferences分割と参照タイミングの機械化（issue #160）

- issue: #160 ／ PR: #161 ／ フェーズ3〈作業〉 flow-id 3-1
- 全体作業計画: `plans/split-issue-mr-flow-skill-into-references.md`
- 前提となる調査結果: `reports/20260823_split-issue-mr-flow-skill-into-references_調査.md`

## 前提（合意状況）

| 事項 | いつ・どこで決まったか |
|---|---|
| 分割は「いつ読むか」で切る（案1）。サイズ4分割は却下 | フェーズ2〈調査〉 E-3（flow-id 2-6〜2-9） |
| 現在地flow-idは「最後の `[x]`/`[-]` の次の `[]`」で解決する | 同 C-1 / C-2 |
| flow-id → 参照ファイルの対応は全体フロー表の「参照」列から抽出する | 同 C-3 |
| `references/*.md` には frontmatter が必要で、type表への追記は**フェーズ3で**行う | 同 C-5 |
| 旧節名の**機械置換は使わない**（(b) が0件ではないため） | 同 B-3（2回目の敵対的レビューで訂正） |
| 本セッションは非対話的なため、flow-id 3-3 / 3-4 の人間レビューは敵対的レビュー1回で代替する（進捗記号は `[]` のまま） | ユーザー指示（issue着手時）。`HANDOFF.md`「判断を迷った内容」 |

## この計画で何をするか

`.claude/skills/issue-mr-flow/SKILL.md`（1446行 / 132,251バイト）を、**入口に絞った本文**と
`.claude/skills/issue-mr-flow/references/` 配下の**7ファイル**（本文と合わせて8ファイル）へ切り出し、あわせて
**参照ファイルを開くタイミングを機械的に決める仕組み**を実装する。

**見出しと節の中身は、切り貼り以外で触らない。** 切り出しは行の切り貼りだけで行い、
元の全行が失われていないことを機械的に確かめる（下記「検証」#2）。本文へ新しく足すのは、
全体フロー表の「参照」列・旧節名→新パスの対応表・各参照ファイルの frontmatter と H1・
`references/review-loop.md` の導入H2（作業1）だけである。

**唯一の書き換え例外は、分割で同一ファイル内に閉じなくなる参照の付け替えである。**
SKILL.md 内には `上記`/`下記`/`上表`/`前述`/`後述` を含む行が56件、アンカーリンク `](#…)` が
5件あり、**参照先が別ファイルへ移る組み合わせだけ**が壊れる（アンカーは448行→
`mcp-fallback.md`、513行→`deliverables.md` の2件が確実に切れる。475・610・634行は
`start-resume.md` 内に残る）。壊れる参照は `references/<ファイル名>.md「節名」` の形へ
付け替え、**付け替えた行の全件を `reports/` へ列挙する**（検証 #2 の全行差分が、この
例外リストと完全一致することを確かめる）。

## 方針

3つの原則で進める。作業項目はすべてこの3つから導かれる。

1. **本文は行の切り貼りだけで切り出す。** 手作業でコピー＆ペーストしない。スクリプトが各行の
   行き先を決め、漏れ・重複が無いことを `assert` で表明する。「同じ内容をどこに置くか**だけ**を
   変える」という全体作業計画の宣言を、機械的に確かめられる形にするためである。
2. **旧節名の機械置換を使わない。** specのpoint-in-time節（`## 影響範囲` 等）に節名を伴う参照が
   33件あり、しかも `## 影響範囲` の中へ現在の状態を説明する小節が混ざるため、行番号でも節名でも
   線引きできない（調査 B-3）。1件ずつ囲みH2と文脈を見る。
3. **flow-id → 参照ファイルの対応は、全体フロー表の「参照」列を唯一の正とする。** hook側に
   対応表を持たない。持つと二重管理になり、受け入れ条件「全体フロー表の各行に参照ファイルを
   明記する」と食い違う（調査 C-3）。

## 変更対象

| 対象 | 何をするか |
|---|---|
| `.claude/skills/issue-mr-flow/SKILL.md` | 本文を22,690バイトへ縮める。参照列・対応表を追加 |
| `.claude/skills/issue-mr-flow/references/*.md`（**新規7ファイル**） | 切り出した詳細。各ファイルへ frontmatter を付ける |
| `.claude/hooks/session-start.sh` | 現在地flow-idの解決と参照ファイルの注入を追加 |
| `.claude/scripts/src/vcs/Provider.sh` | 357行目・373行目の**実行時メッセージ**の案内先を追従 |
| `.claude/scripts/test/test_vcs_provider.sh` | 357行目の期待値を追従。**373行目の出力を検証するテストを新設** |
| `.claude/scripts/test/test_install_to_project.sh` | `describe` 節の抽出元を `references/` へ変更 |
| `.claude/scripts/test/test_session_start.sh` | 現在地解決・参照注入の単体テストを追加 |
| `.claude/rules/markdown-frontmatter.md` | `type` の値の表へ `references/*.md` の行を追加 |
| (c) の64件のうち、節名を伴う参照 | 1件ずつ判断して追従（下記 作業5） |

**変更しないもの**: (a) DDR本文26件、(b) specのpoint-in-time節33件、(d) 節名を伴わない83件。

## 作業項目

### 作業1: SKILL.md を8ファイルへ切り出す（【AIアセット作成】）

切り出し先と収める節は次のとおり（バイト数は末尾改行を含む数え方。調査 E-1）。

| ファイル | 収める節 | バイト |
|---|---|---|
| `SKILL.md`（本文） | 前文／全体フロー導入＋42行テーブル／PR/MR作成・マージの担当／詳細ルールへのポインタ／前提 | 22,690 |
| `references/planning.md` | 全体作業計画に必ず含めるフェーズ／計画の2階層構造／issueが大きすぎる場合の分割提案 | 20,222 |
| `references/deliverables.md` | 計画と実施結果の分離／計画・レポートのHTMLビュー | 4,947 |
| `references/start-resume.md` | サブコマンド導入／`start`／`sync`／`resume`／作業開始・再開時のベースブランチ追従確認 | 20,820 |
| `references/review-loop.md` | `comments`／`reply`／`describe`／敵対的レビューの位置づけ／チャットで受けたレビュー判断の記録／レビュー依頼メッセージ／レビュー完了合図の確認 | 20,972 |
| `references/base-branch-followup.md` | PR作成後のdefaultブランチ追従（監視）／defaultブランチとのコンフリクト検知・解消 | 11,051 |
| `references/mcp-fallback.md` | `gh`/`glab` CLI不在時のMCPフォールバック | 13,578 |
| `references/phase5-close.md` | マージ前の関連issue通知／最終統括レポートとPR/MRへの反映／PRが5-4実施前にマージされた場合の対処 | 17,971 |

**切り出しは手作業で行わない。** 行の切り貼りだけを行うスクリプトを使う。スクリプトは
H2/H3の見出し位置から各行の行き先を決め、`assert` で漏れ・重複が無いことを表明する。
**コードフェンス（```）の内外を区別し、フェンス内の `#` 始まり10行（1218・1222・1226・1318・
1326・1343・1347・1351・1355・1360行）を見出しとして扱わない**（誤認するとフェンスの途中で
ファイルが切れる。行の漏れ・重複は無いままレイアウトだけが壊れるため `assert` では捕まらない）。
**スクリプト全文は worklog へ貼って残す**（scratchpadはセッション固有の一時領域で、
レビュアーも後続セッションも検証できないため。`.claude/rules/ai-command-style.md`
「切り出し先の選び方」の趣旨）。

**各ファイルの先頭へ H1 と frontmatter を足す。** これは切り出し後の追加であり、本文の書き換えでは
ない。`description` は「その参照ファイルをいつ開くか」が読み取れる1文にする。

**`references/review-loop.md` だけは、H1の直後へ導入のH2を1つ補う**（`## サブコマンド
（レビュー往復系）` のような名前）。収める節の先頭3つ（`comments`/`reply`/`describe`）はH3で、
親のH2（`## サブコマンド`）は `start-resume.md` 側へ行くため、補わないと見出しが H1→H3 と飛ぶ。
導入H2の本文には、`## サブコマンド` 導入部が持つ**全サブコマンド共通の前提**（手順に入る前に
`get_vcs_access_mode` で経路を確認すること。SKILL.md 446〜449行）を**再掲**し、再掲である
ことを両ファイルに明記する。これは書き換えではなく**追加**である（冒頭の「本文へ新しく足すもの」
に含めた）。上の表のバイト数は、この追加とH1・frontmatterの分だけ実際には増える（表の値は
切り出し部分だけの目安）。

### 作業2: 全体フロー表へ「参照」列を追加する（【AIアセット作成】）

42行の各行へ、そのステップの実行前に開く参照ファイルを書く。

```
置き換え前:
| flow-id | ステップ | 担当 |
|---|---|---|
| 3-1 | **調査結果をもとに**、個別作業計画… | エージェント |

置き換え後:
| flow-id | ステップ | 担当 | 参照 |
|---|---|---|---|
| 3-1 | **調査結果をもとに**、個別作業計画… | エージェント | `references/planning.md` / `references/deliverables.md` |
```

- 参照が不要な行は `—` を入れる（空セルにしない。列がずれたことに気づけなくなるため）。
- **セルに `|` を含めない**（列位置をヘッダ行から求めるawkの前提。調査 C-3）。
- 割り当ては上表の「いつ開くか」に従う。全42行分の割り当ては作業時に決め、結果は
  `reports/` へ記録する（本計画には書かない）。

### 作業3: 旧節名→新パスの対応表を本文へ置く（【AIアセット作成】）

DDR本文26件・specのpoint-in-time節33件は**書き換えない**ので、読み手がそこから辿れるように、
本文の末尾近くへ対応表を置く。

| 旧節名（DDR・過去changelogが名指ししている名前） | 新しい場所 |
|---|---|
| 「計画の2階層構造」 | `references/planning.md` |
| 「レビュー依頼メッセージ」 | `references/review-loop.md` |
| …（全19種類の節名） | … |

- **左列の集合は機械的に作る**: 変更しない (a) DDR本文・(b) specのpoint-in-time節の該当行から、
  `「…」` で囲まれた節名を抽出した集合を正とする（検証 #3 で対応表の左列と `comm -3` を取り、
  差が0件であることを確かめる）。
- **分割後も本文（SKILL.md）に残る節も表へ載せ、右列を「本文（SKILL.md）に残る」と書く。**
  載せないと「表に無い節名」が、移動していないのか載せ忘れなのかを検証で区別できない。

### 作業4: SessionStart hook を拡張する（【実装】）

`.claude/hooks/session-start.sh` へ2つの関数を足し、注入テキストへ1行加える。

**4-a. 現在地flow-idの解決**（`current_flow_id_to_reply`）

`HANDOFF.md` の進捗表から「**最後の `[x]` または `[-]` の行より後に現れる、最初の `[]` の行**」の
flow-idを返す。解決できなければ空を返す（fail-open）。

- **正規表現は `update-handoff-progress.sh` の `parse_table_row_to_reply` が使うものと同一の
  リテラルを hook 側へ複製し、両者の一致をテストで表明する**（両ファイルで `ROW_RE='…'` という
  同名のグローバル変数として定義し、`test_session_start.sh` が両ファイルから `grep '^ROW_RE='`
  で取り出して完全一致を確かめる。作業6-d）。
- 調査 C-0 の (2) は「二重管理にしない（sourceで共有する）」としていたが、**`source` は使えない**
  ため、二重管理を許容してズレを機械検出する形へ改める。使えない理由は2つ:
  - `session-start.sh` は `set -uo pipefail`（**`-e` を意図的に外した** fail-open 設計）、
    `update-handoff-progress.sh` は `set -euo pipefail`。`source` すると後者の `set -e` が
    hook のシェルへ効き、以降の非ゼロ終了で hook が黙って死ぬ（注入コンテキストが丸ごと消える）。
  - 両者とも `main` を定義しており、`source` の後勝ちで上書きされる
    （`test_session_start.sh:89` が `main` の存在に依存している）。

**4-b. 参照ファイルの抽出**（`refs_for_flow_id_to_reply`）

SKILL.md の全体フロー表から、ヘッダ行で `参照` 列の位置を求め、指定flow-idの行のその列を返す。
**hook内に対応表を持たない**（調査 C-3）。

**4-c. 注入テキストへの追加**

`format_skill_reload_instruction`（`session-start.sh:138〜148`）の末尾へ、
「`現在地 flow-id <解決した値> の実行前に開く参照: <参照列の値>`」の1行を加える。
この関数は**非クォートの `cat <<EOF`** で、ソース上のバッククォートは `` \`commit\` `` のように
バックスラッシュでエスケープされている（「置き換え前」をそのまま検索してもソースと一致しない）。実装は次の形にする。

- 関数の第2引数として参照行（組み立て済みの1行、または空）を受け取り、
  `local refs_line="${2:-}"` と**既定値付き**で受ける（引数1つのままの既存呼び出しが
  `set -u` 配下でも落ちない）。
- 追加する1行は、**ヒアドキュメントの外で** flow-id と参照列の両方が解決できたときだけ
  組み立てて渡す。ヒアドキュメント内の変数展開で出し分けると、解決できないときに
  **空行が残る**ため。
- **解決できないときはこの1行を出さない**（「現在地: 不明」のような行も出さない。誤った
  名指しより、出ないほうが害が小さい。調査 C-0 の非対称）。
- 追加は約150バイトで、`CONTEXT_SIZE_WARN_BYTES`（8000）の2%未満（調査 C-4）。
- **呼び出し元は2箇所ある**: `session-start.sh:275`（`build_work_context` 内）と
  **`test_session_start.sh:287`**。後者のスクリプトは `set -euo pipefail` を宣言しているため、
  既定値を与えない実装だと `unbound variable` で**テストが1件も走らずに落ちる**。287の呼び出しと、
  その戻り値への既存アサーション（292行・306行）の追従も本作業に含める（アサーションが
  完全一致か部分一致かを実物で確かめてから直す）。
- **この関数が名指しする `.claude/skills/issue-mr-flow/SKILL.md` のパス（141行目付近）は
  変えない**（「フロー定義そのものを読み直せ」という指示であり、本文は分割後も SKILL.md に残る）。

### 作業5: 節名を伴う参照 (c) 64件を追従する（【実装】【AIアセット作成】）

**機械置換を使わない。** 1件ずつ、囲みH2と文脈を見て「現在の状態を説明しているか」を確かめて
から直す。置き換えの形は次の1通りだけである。

```
置き換え前: `.claude/skills/issue-mr-flow/SKILL.md`「レビュー依頼メッセージ」節が正
置き換え後: `.claude/skills/issue-mr-flow/references/review-loop.md`「レビュー依頼メッセージ」節が正
```

- **節名は変えない**（DDR側の記述と対応が付かなくなるため）。変えるのはパスだけである。
- 母集団は `git grep -n 'issue-mr-flow/SKILL\.md'`（**全拡張子**。`--include` で絞らない）。
  **作業時に再計測し、本タスク自身の成果物（`plans/` `reports/` `worklog/` `HANDOFF.md`）と
  配布用複製（`.claude/skills/apply-mr-workflow-to-project/assets/` 配下）を除いてから分類する**
  （調査時の206行/65ファイルという件数は、本タスクのファイルが増えるたびにズレる。固定値では
  なく除外規則のほうを正とする）。
- **次の行へ折り返している12件**は、行単位の確認では見落とす。2行を並べて読む。
- **パスを含まない参照も対象にする**（母集団の grep では引っかからない）: SKILL.md 内の
  アンカーリンク `](#…)` 5件（448・475・513・610・634行）と、`上記`/`下記` 等の相対参照56行の
  うち**参照先が別ファイルへ移るもの**。付け替えの形は「この計画で何をするか」の例外規則に
  従い、全件を `reports/` へ列挙する（検証 #13・#14）。
- **`.html` 2件**（`assets/plans.template.html:38` / `assets/reports.template.html:35`）と
  **issue/MRテンプレート2件**（`.github/pull_request_template.md:4` /
  `.gitlab/merge_request_templates/Default.md:7`）を忘れない。前者は全計画・全レポートの土台で
  あり、後者は `describe` 節を名指ししている。どちらも配布先へ渡る。
- **(a) DDR本文26件・(b) specのpoint-in-time節33件には触れない。** 触れたら検証 #9 で
  検出される。

### 作業6: 実行時メッセージとテストを追従する（【実装】【テスト】）

**6-a. `Provider.sh` の2箇所**

```
置き換え前（357行目、mcp_tool_hint の *) 分岐）:
    *) printf '対応するMCPツールは .claude/skills/issue-mr-flow/SKILL.md の対応表を参照\n' ;;
置き換え後:
    *) printf '対応するMCPツールは .claude/skills/issue-mr-flow/references/mcp-fallback.md の対応表を参照\n' ;;
```

```
置き換え前（373行目、require_vcs_cli）:
    printf '  手順: .claude/skills/issue-mr-flow/SKILL.md 「`gh`/`glab` CLI不在時のMCPフォールバック」節\n'
置き換え後:
    printf '  手順: .claude/skills/issue-mr-flow/references/mcp-fallback.md\n'
```

**あわせて `.claude/hooks/session-start.sh:187` も追従する**（MCP経路のときの注入テキストが
`SKILL.md「gh/glab CLI不在時のMCPフォールバック」節` を名指ししている。案内先を
`references/mcp-fallback.md` へ変える。4-c の「変えない」対象は141行目付近の再読み込み指示で
あり、この187行目は変える——混同しないこと）。

**6-b. `test_vcs_provider.sh`**

284-285行目の期待値を 6-a に合わせる。**あわせて `require_vcs_cli` の出力を検証するテストを
新設する**（現在どのテストも 373 を検証していないため、変え忘れても緑のまま通る。調査 D-3）。

```
新設するテスト（骨子。get_vcs_access_mode をサブシェル内で差し替える）:
assert_contains "require_vcs_cli: MCPフォールバックの手順の場所を案内する" \
  "$( get_vcs_access_mode() { printf 'mcp\n'; }; require_vcs_cli get_issue 2>&1 || true )" \
  "references/mcp-fallback.md"
```

差し替えは**サブシェルへ閉じ込め**、`assert_*` は**サブシェルの外**で行う
（`.claude/rules/shell-script-style.md`「テスト」。`unset -f` は実定義を消してしまう）。

**6-c. `test_install_to_project.sh`**

`describe_headings()` が読むファイルを `SKILL.md` から `references/review-loop.md` へ変える。

```
置き換え前:
  ' "${REPO_ROOT}/.claude/skills/issue-mr-flow/SKILL.md"
置き換え後:
  ' "${REPO_ROOT}/.claude/skills/issue-mr-flow/references/review-loop.md"
```

**開始パターン（`/^### \`describe\`/`）は変えないが、終端は広げる。** 現在の終端判定は
`/^### /` だけである。`review-loop.md` では `### describe` の後に来る見出しがH2
（`## 敵対的レビューの位置づけ`）のため、`in_section` が閉じずEOFまで走り、抽出が3行では
なく `## ` 始まりの行を全部拾ってしまう（3行ガードもテンプレート比較も落ちる）。
**終端の規則として `/^## / { in_section = 0 }` を追加する**。抽出対象の3行
（`Closes` / `## Plan` / `## 実装状況`）はコードフェンス内のインデント付きの行なので、
列0の `## ` を終端に使っても取りこぼさない。`/^#{2,3} /` へまとめる書き方は、mawk が
`{n,m}` の繰り返し記法を解釈しない可能性があるため使わない。
既存の「期待値そのものが空になっていないか」のガード（3行抽出できていること）はそのまま残す。

**6-d. `test_session_start.sh`**

作業4の2関数に対する単体テストを足す。最低限、調査 C-2 の4ケース（進捗表なし／全行 `[]`／
穴あき・`[-]` 混在／書式が想定と違う）と、存在しないflow-idで空が返ること、および
**`ROW_RE` のリテラルが `update-handoff-progress.sh` 側と完全一致すること**（作業4-a）を
確かめる。既存の287・292・306行（`format_skill_reload_instruction` の呼び出しと
アサーション）の追従は作業4-c に含めた。

### 作業7: frontmatter の type を決めて表へ追記する（【AIアセット作成】）

`references/*.md` は `.md` なので `index.jsonl` に載る（調査 C-5）。
`.claude/rules/markdown-frontmatter.md` の「typeの値」表へ1行足す。

**採る案**: 新しい値 `skill-reference` を設ける。

| 案 | 採否 | 理由 |
|---|---|---|
| 新設 `skill-reference` | **採用** | `doc-search --type skill` が「スキルの一覧」を返すという現在の意味を保てる |
| 既存の `skill` を流用 | 却下 | `type: skill` が9件から17件へ増え、「スキルを一覧する」問いに参照ファイルが混ざる |
| `guide` を流用 | 却下 | `guide` は永続する案内ドキュメント（README等）に与える値で、スキルのバンドルリソースとは寿命も読み手も違う |

```
置き換え前（typeの値の表）:
| `skill` | `.claude/skills/*/SKILL.md` |
置き換え後:
| `skill` | `.claude/skills/*/SKILL.md` |
| `skill-reference` | `.claude/skills/*/references/*.md`（SKILL.mdから切り出したバンドルリソース。issue #160） |
```

**`description` は通常どおり書く。** 「対象外・特殊対応ファイル」の表が `SKILL.md` の
`description` を特別扱いしているのは、Claude Codeがスキル選択に使う実キーだからである。
`references/*.md` はスキルの入口ではないので、この例外に当たらない。

## この計画で決めないこと（スコープ外）

| 事項 | どこで決まるか |
|---|---|
| spec（`issue-mr-workflow.md` 等）への反映内容、DDR `i0160-01` の本文 | フェーズ4〈反映〉 flow-id 4-1 |
| 「配布用 `assets/` の複製が grep の母集団を歪める」知見の反映先 | 同上 |
| `install-to-project.sh` の破壊的な既定（引数省略で `DEST_DIR="."`）の修正 | **本issueのスコープ外**。別issueとして起票する（調査の残課題） |
| `.claude/rules/directory-structure.md` の `references/` 行「（現時点で実例なし）」の更新 | フェーズ4〈反映〉（全体作業計画の記載どおり） |
| 他の8スキルの点検・スキル執筆規約の新設 | issue #129 |
| フロー自体の変更（flow-idの増減・ステップの並べ替え・手順の中身） | **やらない**（本issueは置き場所だけを変える） |
| `.gemini/` 側の動作確認 | この環境にリンクが無いため未確認のまま。フェーズ4で扱いを決める |

## issueの受け入れ条件との対応

| # | 受け入れ条件（issue #160） | 本計画での対応箇所 |
|---|---|---|
| 1 | SKILL.md 本文が概ね500行以内。抽出した節が `references/` 配下にある | 作業1（本文22,690バイト／8ファイルへ切り出し）、検証 #1 |
| 2 | 全体フロー表の各行が、そのステップの前に開く参照ファイルを名指ししている | 作業2、検証 #4 |
| 3 | 不変条件（`commit`スキル経由の強制／マージは人間／HANDOFF.mdの進捗更新／レビュー往復）が本文に残っている | 作業1（該当節はいずれも本文側の「全体フロー表」「PR/MR作成・マージの担当」「前提」に含まれる） |
| 4 | SessionStart hook が現在地flow-idに対応する参照ファイルを注入する（できない場合は理由を記録し、再読み込み指示の文面も新構造へ更新する） | 作業4（4-a/4-b/4-c。解決できないときは行を出さない） |
| 5 | 旧節名→新パスの対応表があり、DDR本文・specの過去changelogを書き換えずに辿れる | 作業3、検証 #3・#9 |
| 6 | `AGENTS.md`・`.claude/rules/`・spec からのリンク切れが無い | 作業5、検証 #8 |
| 7 | `test_install_to_project.sh` が新構造で通る | 作業6-c、検証 #6 |
| 8 | `.claude/rules/markdown-frontmatter.md` の type 表が `references/*.md` を扱っている | 作業7、検証 #11 |
| 9 | `references/` が配布先へ渡ることを確認済み | 検証 #10 |
| 10 | 決定と却下案を記録したDDRがある | **フェーズ4**（本計画のスコープ外。下記） |

## 検証

基準を分岐点のSHAへ固定してから行う。

```bash
base="$(git merge-base origin/main HEAD)"
```

| # | 何を確かめるか | コマンド／合格条件 |
|---|---|---|
| 1 | 本文が目標サイズに収まった | `wc -l` と `wc -c` の両方を出す。合格は**500行以内**（受け入れ条件 #1 の単位は行数）かつ概ね25,000バイト以下（参照列・対応表の追加分を含む） |
| 2 | **切り貼り以外で触っていない** | (i) 見出し: `git show "$base":…SKILL.md` の見出し62件が分割後の集合に**すべて含まれ**（`comm -23` が0件）、**増分が追加したH1 7件＋導入H2 1件＋対応表のH2 1件だけ**（`comm -13` が9件で、中身がその9つ。本文のH1は元から在るため増えない）。見出し抽出は元・分割後ともコードフェンス対応の方法で行う（フェンス無視の `grep '^#'` は両側で同じだけ誤検出して一致してしまう）。 (ii) 全行: 元の全行と、分割後の全行から追加分（frontmatter・H1・導入H2・参照列・対応表）を除いたものを `sort` して `diff` し、**差分行が「参照付け替えの例外リスト」（reports/ に列挙）と完全一致**することを出力する |
| 3 | 対応表が全節名を網羅 | 参照されている節名の集合と対応表の左列を `comm -3` で突き合わせ、**差が0件**であることを件数付きで出す |
| 4 | 参照列が全42行に入っている | 参照列が空のデータ行が**0件**であることを件数付きで出す |
| 5 | hookが正しいflow-idと参照を返す | `test_session_start.sh` の新規ケースが通る。あわせて実際の `HANDOFF.md` に対して手で実行し、現在地が期待どおりであることを確認する |
| 6 | **既存テストが1本も壊れていない** | `.claude/scripts/test/` 配下の**全テスト**を回し、合計 `failures=0`。**件数（実行本数・passed合計）も出す** |
| 7 | 373の変え忘れを検出できる | 新設したテストで、案内先を旧パスへ戻した一時ツリーが**実際に失敗する**ことまで確かめる |
| 8 | 参照追従にリンク切れが無い | `git grep -n 'issue-mr-flow/SKILL\.md'` の残存件数を出し、**すべてが (a)(b)(d) のいずれかである**ことを確認する |
| 9 | **DDR本文・過去changelogを書き換えていない** | `git diff "$base" -- .claude/docs/ddr/` の行数が**0**（数字で出す）。spec側は `git diff -U0 "$base" -- .claude/docs/spec/` の変更行番号を新ファイルの節見出しへ対応付け、`## 影響範囲` 配下に落ちる変更行数が**0件**であることを数字で出す |
| 10 | `references/` が配布先へ渡る | **先に `bash .claude/skills/apply-mr-workflow-to-project/scripts/sync-assets.sh` で配布物を作り直してから**（`install-to-project.sh` は事前ビルド済みの `assets/` からコピーするため、これを飛ばすと古い配布物で「渡ったように見える」）、`mktemp -d` ＋ `git init` した一時ディレクトリへ配り、`dest/.claude/skills/issue-mr-flow/references/` に7ファイルが現れることをコマンド出力で示す（調査 D-2 の**未達だった合格条件**） |
| 11 | `index.jsonl` に載る | `bash .claude/scripts/src/extract-frontmatter.sh .` 後、`references/*.md` 7件が `type: skill-reference` で載っている |
| 12 | 構文チェック | 変更した `.sh` すべてに `bash -n` |
| 13 | アンカーリンクが切れていない | 分割後の本文＋`references/*.md` それぞれで、`](#…)` の飛び先アンカーを同一ファイル内の見出しから生成した集合と突き合わせ、**不一致0件**を件数付きで出す |
| 14 | 相対参照の追跡漏れが無い | `上記`/`下記`/`上表`/`前述`/`後述` を含む行（元56行）を分割後の所在ファイルごとに点検した結果を reports/ の例外リストと突き合わせ、**別ファイル行きなのに付け替えていない参照が0件**であることを出す |

**`install-to-project.sh` は必ず一時ディレクトリを引数で渡す**（省略するとこのリポジトリ自身を
上書きする）。
