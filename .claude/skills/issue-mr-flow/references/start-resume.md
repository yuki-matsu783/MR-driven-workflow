---
title: issue-mr-flow 参照: 開始・再開（start / sync / resume）
type: skill-reference
description: 作業の開始（flow-id 1-2〜1-3）とセッション再開・途中引き継ぎの前に開く。サブコマンド共通の前提（get_vcs_access_modeでの経路確認）とベースブランチ追従確認を含む
tags: [issue-mr-flow, skill-reference, start]
keywords: [start, sync, resume, サブコマンド, get_vcs_access_mode, ベースブランチ, check-base-sync, Draft MR, 途中引き継ぎ]
---

# issue-mr-flow 参照: 開始・再開（start / sync / resume）

## サブコマンド

呼び出しは `/issue-mr-flow <サブコマンド> [引数]` の形。

**各サブコマンドは `gh`/`glab` CLIがある前提で書かれている。手順に入る前に必ず
`get_vcs_access_mode`（`Provider.sh`）で経路を確認し、`mcp` が返る環境では
`references/mcp-fallback.md` の
読み替えに従うこと**（issue #34）。
（この前提はレビュー往復系のサブコマンド `comments`/`reply`/`describe` にも適用され、
`references/review-loop.md` の冒頭に再掲されている。）

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
     でfetch・checkoutのみ行う。続けて
     [作業開始・再開時のベースブランチ追従確認](#作業開始再開時のベースブランチ追従確認issue-67)
     を行う（issue #67。**新規作成の場合は不要**）。
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
     c. **Draft MRの作成に、ユーザーからの都度の明示指示は要らない**（issue #41。`.claude/skills/issue-mr-flow/SKILL.md`
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
        `.claude/docs/ddr/i0000-03-DraftPR作成失敗時は空コミットで自動リトライする.md`）。
        関数が最終的にPR/MR番号を標準出力へ返せば成功であり、それ以上の空コミット・push・
        `commit`スキル呼び出しは不要。番号が返らずエラーで終了した場合のみ実際の失敗として対処する。
3. 取得したissue内容をもとに、全体フロー 1-4（Planモードでの全体作業計画作成）に進む旨をユーザーに案内する。
   **あわせて `.claude/skills/issue-mr-flow/assets/plans.template.html` と
   `.claude/skills/issue-mr-flow/assets/reports.template.html` を読む**（このブランチで作る
   計画・レポートのHTMLビューは、すべてこの2つを土台にする。
   `references/deliverables.md`「計画・レポートのHTMLビュー」節）。

### `sync` — セッション再開（全体フロー 1-3の再開版）

対象ブランチ名を引数に取り、`sync_branch "<branch>"` を呼び、続けて
[作業開始・再開時のベースブランチ追従確認](#作業開始再開時のベースブランチ追従確認issue-67)
を行う（issue #67。`sync_branch` は作業ブランチを最新化するだけで、ベースブランチの取り込みは
見ないため）。引数省略時は現在のブランチ名を使う。`resume` や `start` で既にこのセッションの現在地確認が
済んでいる状態で、ブランチを最新化したいだけの場合に使う。**新しいセッションで最初に使う
サブコマンドとしては使わない**（新しいセッションの最初の一手は必ず `resume` から入る）。

### `resume` — 途中引き継ぎ（引数なし）

このセッションでまだ「今どこにいるか」（issue／ブランチ／PRの、どの段階か）を確認していない
状態で使う。別セッション・別担当者が途中から引き継ぐ場合に限らず、`start` 以外のサブコマンドを
このセッションで初めて使う前は常にここから入る（ブランチ名やissue番号が判明していても対象）。

1. Agentツールで `issue-mr-resume` サブエージェント（`.claude/agents/issue-mr-resume.md`）を起動する。
2. サブエージェントが返す「現在地サマリ」をそのままユーザーに提示する。**項目の定義は
   `.claude/agents/issue-mr-resume.md` の報告フォーマットが正**（ブランチ・issue・PR/MR・
   未解決コメント件数・ブランチ固有のplan/worklogファイル・**ベースブランチとの差分**・
   HANDOFF.mdの内容、および矛盾・注意点）。同じ列挙を2箇所で管理するとどちらかが古くなるため、
   項目を増やしたくなったらこの節ではなくサブエージェント定義側を編集する。
3. 提示した内容をもとに、全体フローの43ステップのうちどこから再開すべきかをAIエージェントが判断し、
   次にすべきことを提案する（この判断はサブエージェントではなく呼び出し元が行う）。
4. issue番号が特定できていればブランチ/MRの存在確認へ（`start` 手順2相当。ただし
   **ベースブランチの追従確認はここでは行わない**。手順5で1回だけ扱う）、issueが特定できなければ
   ブランチ命名規則から外れている旨を伝えて `start <issue番号>` での対応を促す。
5. **ベースブランチの追従を確認する**（issue #67）。手順は
   [作業開始・再開時のベースブランチ追従確認](#作業開始再開時のベースブランチ追従確認issue-67)。
   **`check-base-sync.sh` を再実行せず、手順1のサブエージェントが現在地サマリへ含めて返した
   `- ベースブランチとの差分:` の値を使う**（同節「実施タイミング」の重複実行の注意を参照。
   例外は、その報告が「判定できなかった」だった場合のみ）。**遅れがあった場合に
   `AskUserQuestion` で取り込みの可否を確認するのは呼び出し元の役割**である
   （サブエージェントは読み取り専用で、判断も取り込みも行わない）。
6. **PRが存在し、まだマージ・クローズされていない場合は、defaultブランチの追従監視を取り直す**
   （購読・自己チェックインはセッションに紐づき、前のセッションの終了とともに止まっているため。
   手順は `references/base-branch-followup.md`「PR作成後のdefaultブランチ追従（監視）」節。取り直した状態は `HANDOFF.md` の
   ヘッダ `- 追従監視:` 行へ記録する）。

## 作業開始・再開時のベースブランチ追従確認（issue #67）

featureブランチで作業を**開始・再開する時点**で、ベースブランチ（既定 `main`）の最新がその
ブランチへ取り込まれているかを確認する。古いベースブランチを前提にした実装・レビューを防ぐため
である（実例: issue #60 対応中のセッションで、ローカルの `origin/main` が10コミット古いまま
作業していた。未取得分には `.claude/rules/shell-script-style.md` へのルール追記が含まれており、
作業中のルール判断に影響しうる状態だった）。

本節は「PR作成後のdefaultブランチ追従（監視）」と同じく、**特定のflow-idに属さない並行手順**
として定める（flow-idは増やさない）。

### 既存2機構との役割の違い

**この3つは代替関係ではなく補完関係である。**

| | 本節（issue #67） | PR作成後の追従監視（issue #88） | flow-id 5-1（issue #46） |
|---|---|---|---|
| いつ | **作業を開始・再開する時点** | PR作成〜マージの間、随時 | マージ依頼の直前（最終ゲート） |
| 判定軸 | **遅れているか**（behindコミット数） | 衝突するか（`hasConflict`） | 同左 |
| 検知手段 | `check-base-sync.sh` | `check-base-conflicts.sh` | 同左 |
| 遅れているが衝突しない状態 | **検知する** | 見逃す | 見逃す |

ベースブランチ側でルール・仕様**だけ**が追記された場合、テキストコンフリクトもDDR識別子の重複も
起きないため、既存2機構の `hasConflict` は偽のままになる。しかし作業ブランチはその追記を
知らないまま実装・レビューを進めることになる。この空白を埋めるのが本節である。

### 実施タイミング

| 地点 | 実施 | 備考 |
|---|---|---|
| `start` 手順2で**既存ブランチを検出した**場合 | **する** | いつ作られたブランチか分からないため |
| `start` 手順2で**新規にブランチを作成する**場合 | しない | `<base_branch>` から切るため、定義上その時点で追従済み |
| `resume` | **する（ただし1回だけ）** | セッションを跨いだ引き継ぎ。issue #67 が挙げた実例がこの経路。下記の重複実行の注意を参照 |
| `sync` | **する** | 「ブランチを最新化したいだけ」の経路。ここが素通りだと確認の抜け道になる |

**`resume` では検知を1回に留める。** `issue-mr-resume` サブエージェントが手順7で
`check-base-sync.sh` を実行し、その結果を現在地サマリへ含めて返す。呼び出し元（`resume` 手順5）は
**その報告値を使い、スクリプトを再実行しない**。`resume` 手順4が `start` 手順2相当の確認へ入る
場合も、追従確認は重ねて行わない。再実行すると `git fetch` が余分に走るうえ、その間に
`origin/<base>` が進むと1回目と2回目で `behind` が食い違い、ユーザーへ提示する値が定まらない。
**例外は、サブエージェントの報告が「判定できなかった」だった場合**で、このときだけ呼び出し元が
下記の手順1から実行し直す。

### 手順

1. **検知**（作業ツリーを変更しない）

   ```bash
   bash .claude/scripts/src/check-base-sync.sh
   ```

   判定結果のJSONの `isBehind` を見る。`behind`（遅れているコミット数）・`changedFiles`
   （未取り込みの変更ファイル。先頭50件）・`changedFilesTotal` もそのままユーザーへ提示する。
   **`git fetch` はこのスクリプトが行う**ため、呼び出し側で先に fetch しておく必要はない
   （`issue-mr-resume` サブエージェントが現在地サマリを組み立てる時点ではまだ fetch されて
   いないため、責務をスクリプト側へ寄せている）。

   **終了コードが非0だった場合は「判定できなかった」として扱い、`isBehind` を偽として
   扱わない**（`origin/<base>` が解決できない・リモート名が `origin` でない等でここへ来る）。
   stderrの1行目を添えてユーザーへ報告する。ネットワーク・認証起因が疑われる場合は、
   `.claude/skills/resolve-conflict/SKILL.md`「トラブルシュート」と同じく指数バックオフで
   最大4回まで再試行してよい。

2. **`hasCommonHistory` が `false`**: 履歴が繋がっていない。**取り込みを提案せず、ここで止まる。**

   共通祖先が無いとき `git rev-list --left-right --count` は失敗せず**ベース側の全コミット数**を
   返すため、`behind` は履歴全体の長さになり `isBehind` は真、一方 `changedFiles` は空・
   `changedFilesTotal` は0になる（実測で確認済み）。そのまま手順4へ進むと「N コミット遅れて
   います／未取り込みの変更ファイル: 0件」という矛盾した質問をユーザーへ出すことになり、
   承認されても `git merge` は `fatal: refusing to merge unrelated histories` で失敗する。
   **`--allow-unrelated-histories` を付けて回避しない**（無関係な履歴が接ぎ木される）。
   orphanブランチか、shallow cloneの深さが足りず共通祖先が取得できていない可能性を報告する。

3. **`isBehind` が `false`**: そのまま作業へ進む。ユーザーへの報告は不要。

4. **`isBehind` が `true`**: **`AskUserQuestion` でユーザーに確認する。承認を得るまで
   取り込まない**（AIエージェントが無断でマージしない）。質問文には検知内容
   （何コミット遅れているか・どのファイルが変わったか）を具体的に含める。選択肢は次の2つ。

   - `<base> を merge して取り込む (Recommended)`
   - `今は取り込まない`（遅れたまま進む。その旨を `HANDOFF.md` の「判断を迷った内容」へ残す）

   **`rebase で取り込む` を選択肢に出さない。** このリポジトリは
   `.claude/skills/resolve-conflict/SKILL.md`「絶対ルール」で「`git rebase` は使わない。
   `git merge` で取り込む」と無条件に定めている。作業ブランチは既にリモートへ反映済みであり、
   履歴を書き換えるとレビューコメントの紐づくコミットSHAが失われ、レビュアーのローカル
   チェックアウトとMR上の参照リンクの両方が壊れる。**非推奨と注記して選択肢に並べる形にも
   しない**（並んでいる時点で選べてしまうため）。

5. **取り込む前に、作業ツリーが汚れていないことを確認する。**

   ```bash
   git status --porcelain
   ```

   出力が空でなければ**取り込まない**。未コミットの変更があると
   `error: Your local changes to the following files would be overwritten by merge` で
   マージが拒否される。この確認が走るのは `resume`（セッション中断の直後）・`sync`
   （作業中の最新化）であり、**編集途中の変更が残っている確率がむしろ高い**ため、
   素通りする前提にしない。**AIエージェントは `git stash` を独断で実行しない**
   （復元されないまま次の作業へ進むと、実質的な作業消失になる）。コミットしてから取り込むか、
   取り込みを見送るかをユーザーへ確認する。

   空であれば取り込み、コンフリクトが出た場合は `resolve-conflict` スキルへ渡す。
   コミットは `commit` スキル経由で行う。

6. **判定が信頼できないことを示すキーを見る。** 各キーが何を表しているか（意味）の正は
   `.claude/docs/spec/check-base-sync.md` であり、ここが正とするのは**遭遇したときに何をするか**
   （運用手順）である。同じ判断を2箇所で管理しないための切り分けで、片方だけを読んで運用しない。

   | キー | 値 | 意味 |
   |---|---|---|
   | `fetchOk` | `false` | fetchに失敗している（ネットワーク・認証等）。古いリモート追跡参照を見ているため `behind` を過小評価しうる。`null` は `--no-fetch` 指定で試していないことを表す |
   | `isShallow` | `true` | shallow clone（Claude Code on the web のリモート実行環境は常にこれ）。**単体では警告の条件にしない**（この環境では常に真になるため、毎回警告を出すと `fetchOk: false` のような本当に危ういときの警告まで読み飛ばされる）。`hasCommonHistory` が偽のとき、または `mergeBase` が `.git/shallow` に列挙されたSHAと一致するときに限り、深さ不足を疑う（`git fetch --unshallow origin` してから再実行する） |
   | `hasCommonHistory` | `false` | merge-base が無い。手順2に従い、取り込みを提案せずに止まる |

   **`fetchOk` が偽のときは、`isBehind` が `false` でも「追従済み」と断定しない。**
   その旨をユーザーへ伝える。

**この確認は flow-id 5-1 を置き換えない。** 5-1 は判定軸が違う（衝突するか）うえ、必ず通る最終
ゲートとして機能している。スクリプトの仕様（出力キーの意味・判定順序・終了コード）は
`.claude/docs/spec/check-base-sync.md` が正。
