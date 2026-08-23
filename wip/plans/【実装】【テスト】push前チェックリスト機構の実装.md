---
title: 【実装】【テスト】push前チェックリスト機構の実装
type: plan
description: issue #17 のpush前チェックリスト機構を、スクリプト1本・hook2本・テスト2本＋既存T11の改修として実装する計画。
tags: [plan, issue-mr-flow, hook, push]
keywords: [push前チェックリスト, PreToolUse, PostToolUse, push-checklist, 前置フィルタ, TSV, 単体テスト, T11]
---

# 【実装】【テスト】push前チェックリスト機構の実装

対象: issue #17「hookを使って、push時にしてほしいことを実現する」フェーズ3。
全体作業計画: `wip/plans/steady-guarding-checkpoint.md`
前提となる調査結果: `wip/reports/20260823_steady-guarding-checkpoint_push前チェックリスト機構の設計調査.md`
（**Q1〜Q8の結論がこの計画の入力である。設計判断をここで作り直さない**）

**合意の地点**: 上記の調査結果は **flow-id 2-6 で作成し、flow-id 2-8/2-9（敵対的レビュー2回目・
12件を反映）で合意した版**を入力とする。本セッションは非対話のため、人間のレビューの代わりに
敵対的レビューで合意を取っている（全体作業計画「本セッションは非対話」節）。
**Q1のフォールバック値（`worklog`）は、この計画を書く過程で調査結果側を訂正した結果である**
（当初は `wip/worklogs` と書かれていた）ため、訂正後の版を指している。

**種別を `【実装】【テスト】` と併記する理由**: テストコードは実装と同時に書き、まとめて1回で
合意を取る（`.claude/skills/issue-mr-flow/references/planning.md`「種別を複数併記する場合／分ける場合」）。
本機構はhookであり、**テストを伴わない実装は成立しない**（前置フィルタが超集合でなくなると
hookが無言で発火しなくなるため）。分けると同じ内容を2回説明することになる。

## この計画で作るもの

| # | ファイル | 種別 | 役割 |
|---|---|---|---|
| 1 | `.claude/scripts/src/push-checklist.sh` | 新規 | 生成・チェック記録・検証・パス解決の本体 |
| 2 | `.claude/hooks/block-unchecked-push.sh` | 新規 | PreToolUse。未完了なら exit 2 |
| 3 | `.claude/hooks/post-push-next-checklist.sh` | 新規 | PostToolUse。次回分を生成 |
| 4 | `.claude/scripts/test/test_push_checklist.sh` | 新規 | 1のテスト |
| 5 | `.claude/scripts/test/test_block_unchecked_push.sh` | 新規 | 2のテスト（2層構成） |
| 6 | `.claude/scripts/test/test_post_push_next_checklist.sh` | 新規 | 3のテスト（2層構成） |
| 7 | `.claude/scripts/test/test_sync_gemini_assets.sh` | **改修** | T11・T12を対象hook全件へ |
| 8 | `.claude/settings.json` | **改修** | hook登録（PreToolUse 1件・PostToolUse 2件） |
| 9 | `.claude/docs/spec/push-checklist.md` | 新規（**骨組みのみ**） | 実装・ブロックメッセージからの参照先を成立させる。中身はフェーズ4（下記「存在しないspecを参照しないこと」） |

**7・8は既存ファイルの改修であり、見落としやすい。** とくに7は、足さなければT11が緑のまま
新規hookの写経のドリフトを見逃す（調査結果Q5の指摘）。

**6は当初この表に無かった**（敵対的レビュー フェーズ3・1回目で指摘）。この計画自身が
「テストを伴わない実装は成立しない」と書いているのに、hook 3本目だけがその例外になっていた。

## 実装の順序

依存関係の順に並べる。**各段でその段のテストを通してから次へ進む**（最後にまとめてテストしない）。

0. **`.claude/docs/spec/push-checklist.md` の骨組みを置く。** 以降のヘッダコメント・ブロック
   メッセージがこのパスを参照するため、先に存在させる（中身はフェーズ4）。
1. **`push-checklist.sh` を書く**（テスト4も同時に書く）。hookはこれに委譲するだけなので、ここが本体。
2. **`block-unchecked-push.sh` を書く**（テスト5も同時に書く）。
3. **`post-push-next-checklist.sh` を書く**（テスト6も同時に書く）。
4. **`test_sync_gemini_assets.sh` のT11・T12を改修する**（3を書いた直後。先に改修すると
   ファイルが存在せず落ちる）。
5. **`.claude/settings.json` へ登録する。** ここから先、**この issue の作業自身が機構の対象になる**
   （下記「登録後の自己適用」）。
6. **回帰確認**（下記「検証」）。

## 1. `push-checklist.sh`（本体）

### サブコマンド

| サブコマンド | 引数 | 役割 | 終了コード |
|---|---|---|---|
| `path` | なし | カレントブランチの**最新**チェックリストのパスをstdoutへ。無ければ空で終了コード1 | 0 / 1 |
| `new` | なし | 次回分を生成する。生成条件（Q6の3つ）を満たさなければ**何もせず0で終わる** | 0 |
| `check <id> <ログ>` | id・実施ログ | その行を `done` にし、4列目へログを書く | 0 / 1 |
| `skip <id> <理由>` | id・理由 | その行を `skip` にし、4列目へ理由を書く | 0 / 1 |
| `verify` | なし | 最新チェックリストの**HEAD断面**を検証する（下表の3値） | 0 / 1 / 3 |

**`verify` の終了コードは3値にする**（敵対的レビュー フェーズ3・1回目で指摘）。0/1の2値だと
「未完了・壊れている」と「HEADに対象が無い」が同じ1になり、hook側の3分岐が表現できない。
どちらへ倒しても調査結果Q5に反する（1扱いにすると初回pushが全ブロック、0扱いにすると空ファイルが素通り）。

| 終了コード | 意味 | hook側の対応 |
|---|---|---|
| 0 | 通してよい（4条件すべてを満たした） | `exit 0` |
| 1 | **検証失敗**（未完了・壊れている・件数が合わない） | `exit 2`（ブロック） |
| 3 | **HEADに対象のチェックリストが無い** | ブロックしない（下記の警告条件へ） |

- **`verify` は exit 2 を返さない。** exit 2 はhookの契約であり、スクリプト単体の終了コードとしては
  使わない（テストから呼ぶときに紛らわしいため）。hook側が1を受けて2へ翻訳する。
- **HEADが未コミット（unborn branch）・detached HEAD で `git show HEAD:` 自体が失敗する場合は 3
  （対象なし）へ倒す。** 1（＝ブロック）へ倒すと、コミットが1つも無いブランチで全pushが止まる。
  `git rev-parse --verify HEAD` の成否を先に見て、`set -e` で落ちないようにする。
- **`check` / `skip` は作業ツリー上のファイルを書き換える**（`verify` はHEAD断面を読む）。
  この非対称は意図的で、調査結果Q4の結論（hookはHEADを読む）に対応する。

### 置き場所・命名

- 置き場所は `get_workflow_config`（`.claude/scripts/src/vcs/Provider.sh`）の `worklogDir` から
  解決する。**フォールバックは `cleanup-task.sh:232` と同一の文字列（`worklog`）を自分で当てる。**

  ```bash
  worklog_dir="$(get_workflow_config | jq -r '.worklogDir // "worklog"')"
  ```

  **当初「自前で `// "..."` を書かない（`get_workflow_config` 自身が既定値を持つ）」と書いて
  いたが、これは誤りだった**（敵対的レビュー フェーズ3・1回目で指摘）。`get_workflow_config` は
  **`.mrworkflow.json` が存在すればその中身をそのまま `cat` するだけ**で、キー単位の既定値補完を
  行わない（`Provider.sh:53-61`。既定値ヒアドキュメントはファイルが**丸ごと無い**ときにしか
  使われない）。一時リポジトリでの実測:

  ```
  $ echo '{"defaultBaseBranch":"main"}' > .mrworkflow.json
  $ get_workflow_config | jq -r '.worklogDir'             → null
  $ get_workflow_config | jq -r '.worklogDir // "worklog"' → worklog
  ```

  **`.mrworkflow.json` はあるが `worklogDir` キーが無い配布先**（seed層なので配布先が書き換える）
  では、キー単位の既定値を当てないと生成側が literal な `null/` ディレクトリへ書き、削除側
  （`cleanup-task.sh`）は `worklog/` を見る。**Q1が避けようとした食い違いをそのまま作る。**
  `plansDir` / `reportsDir` も同様に `// "plans"` / `// "reports"` を当てる。
- 命名は `<YYYYMMDD>_<ブランチslug>_push<N>_checklist.tsv`。
  - ブランチslugは `[^a-zA-Z0-9_-]` を `_` へ。`post-push-compact-prompt.sh` と同じ変換だが、
    **`sed` ではなくbash組み込み（`${branch//...}` のループ）で行う**（hookから呼ばれるため）。
  - `<N>` は既存チェックリストの最大値 + 1。

### ファイル形式

```
# generated-for: <HEADのSHA>
# id	項目	状態	実施ログ
worklog	worklogを作成し、このpushまでの試行錯誤を追記した	pending	
```

**上の `pending` 行も行末がタブで終わる（＝4フィールド）。** markdownでは末尾タブが不可視なので
明記する。**当初この行は3フィールドで、自分の「常に4フィールド」規則と `verify` 条件1に反して
いた**（敵対的レビュー フェーズ3・1回目で指摘）。そのまま写経すると、`new` が生成した直後の
チェックリストが**自分の `verify` に必ず落ちる**（しかもメッセージは「未完了項目」ではなく
形式異常になり、原因に辿り着きにくい）。

- 1行目・2行目は `#` で始まるコメント。**`#` で始まる行は読み飛ばす。**
- データ行は**常にちょうど4フィールド**（`pending` でも4列目を空で出す）。
- 状態は `pending` / `done` / `skip` の3値。
- 項目（5件）とidは**スクリプト内の定数**として持つ。**文言は調査結果Q2の表と一字一句同じ**に
  する（上のサンプルもQ2の定数と一致させてある。独自に短縮すると、生成器の定数・仕様文書・
  調査結果で文言が3系統に割れる）。

### `verify` の判定（否定形）

「通してよい」と積極的に確認できたときだけ0を返す。1つでも欠ければ1。

1. 全データ行が**ちょうど4フィールド**。
2. `id` 列の集合が**5件の定数と過不足なく一致**。
3. 全行の状態が `done` または `skip`。
4. `done` / `skip` の行の**4列目が空でない**。

**複数のチェックリストがHEADに存在する場合は `<N>` が最大の1本だけを見る。**

### コミット忘れの検知（`stale` 判定。ブロックはしない）

**「HEADにチェックリストがあるか」では検知にならない**（敵対的レビュー フェーズ3・1回目で指摘）。
チェックリストは flow-id 5-5 まで削除されず**蓄積する**ため、2回目以降のpushでは HEAD に必ず
古いものが残っている。当初の条件（HEADに無いが作業ツリーにある）は**初回pushでしか成立せず**、
新しく生成された `push<N+1>` をコミットし忘れても、`verify` は旧チェックリスト（全 `done`）を
見て通し、警告も出ない。**調査結果Q5が exit 1 の警告を置いた、まさにその失敗が素通りする。**

したがって判定は**Nの比較**で行う。

```
作業ツリーの最大N > HEADの最大N  →  コミットされていない新しいチェックリストがある
```

- この形なら、**初回push**（HEADに無く作業ツリーにある＝ `0 → 1`）も、**2回目以降のコミット忘れ**
  （`3 → 4`）も同じ1つの条件で拾える。
- `push-checklist.sh` に `stale` サブコマンドを設け、`0`＝コミット忘れあり／`1`＝なし を返す。
  hookはこれを見て `exit 1`（非ブロックのエラー）＋警告を出す。**通す側の判断は変えない。**

### `new` の生成条件（3つすべて）

1. HEADが公開済み（`git branch --remotes --contains HEAD` が1件以上）。
2. **そのHEAD SHAを `# generated-for:` に持つチェックリストが1本も無い。**
3. HEADにタスク成果物が残っている（`plansDir` / `worklogDir` / `reportsDir` のいずれかに、
   `TEMPLATE.md`・`REVIEW-POINTS*.md` を除くファイルがある）。

**条件を満たさないときは、エラーではなく静かに0で終わる**（PostToolUseの正常系だから）。

## 2. `block-unchecked-push.sh`（PreToolUse）

`block-direct-git-commit.sh` の構造をそのまま踏襲する。

1. `main()` 冒頭で**前置フィルタ** `raw_hints_at_git_push`（`post-push-compact-prompt.sh:222-240` と
   **同一実装**を写経）。
2. `jq` で `tool_name` / `tool_input.command` を取り出す。**受理する `tool_name` は
   `run_shell_command|Bash|PowerShell` の3つ**（`post-push-compact-prompt.sh:274-281` と同じ）。
   `block-direct-git-commit.sh` は `Bash`/`PowerShell` の2つだけだが、**そちらへ揃えると
   Gemini CLI経路（`run_shell_command`）で機構が丸ごと効かない**。`.gemini/` を変換同期の
   対象にしている以上、Gemini CLI でも守らせる。
3. **`project_dir` を解決して `cd` する**（`GEMINI_PROJECT_DIR` → `CLAUDE_PROJECT_DIR` の順。
   無ければ `exit 0`）。`push-checklist.sh` は内部で `git show HEAD:` /
   `git branch --remotes --contains HEAD` / `get_workflow_config`（`git rev-parse --show-toplevel`）を
   実行するため、**cwdがリポジトリ内であることに依存する**。`block-direct-git-commit.sh` は
   gitを一切呼ばないためこの手順を持たず、「同じ構造を踏襲する」だけでは埋まらない
   （`post-push-compact-prompt.sh:300-303` が持つ形をこちらへ持ってくる）。
   `push-checklist.sh` の位置は `${BASH_SOURCE[0]%/*}/../scripts/src/push-checklist.sh` で解決する
   （ディレクトリ成分が無い起動のためのカレント倒しを含む。`block-direct-git-commit.sh:117-121` と同型）。
4. `CommandPosition.sh` を `source` して `command_invokes_git_subcommand "$command" push`。
   `BASH_VERSINFO` ≥ 4.3・`[ -r ]`・`source` 成否・`declare -F` の4点を確かめる。
   **駄目なときの縮退は、既に手元にある `raw_hints_at_git_push`（前置フィルタ）をそのまま使う。**

   **`grep -qiE 'git[[:space:]]+push'` を使ってはいけない**（敵対的レビュー フェーズ3・1回目で
   指摘）。これは精密判定の**部分集合**であり、「ブロック側へ倒す」と逆向きに倒れる。実測:

   ```
   precise=1 grep=1 : git push
   precise=1 grep=0 : git -C /x push
   precise=1 grep=0 : git --no-pager push origin HEAD
   ```

   この2形は `test_sync_gemini_assets.sh` のT11が prefilter_cases として持っており、同ファイルの
   コメントも「`git[[:space:]]+push` へ縮めると、ここで落ちる」と警告している。
   前置フィルタは**超集合であることがT11で機械的に固定されている**ため、縮退判定に流用すれば
   その保証をそのまま引き継げる（過剰検知は「チェックを埋めれば通る」だけで済む）。
   `block-direct-git-commit.sh:134` が `grep` へ縮む形なのは既存の許容であり、新規hookで
   「ブロック側へ倒す」と宣言する根拠にはならない。
5. push と判定したら `push-checklist.sh verify` を呼ぶ。**`set -euo pipefail` 配下なので、
   非0を素の単純コマンドで受けない**（`-e` でhook自身が exit 1 で終わり、ブロックしたい場面で
   ブロックされなくなる）。`status=0; push-checklist.sh verify || status=$?` の形で受ける。
   - 0 → `exit 0`
   - 1（検証失敗） → **未完了の項目名**と**ルールファイルのパス**をstderrへ出して `exit 2`
   - 3（HEADに対象なし） → ブロックしない。ただし `push-checklist.sh stale` が0を返すなら
     `exit 1`（非ブロックのエラー）＋警告
   - **`verify` が 0 を返した場合も `stale` を見る**（2回目以降のコミット忘れはここで拾う）。
6. 末尾に `if [ "${BASH_SOURCE[0]}" = "${0}" ]; then main; fi` のガードを置く。

**ブロックメッセージには「未完了の項目名」と「`.claude/skills/commit/SKILL.md` /
`.claude/docs/spec/push-checklist.md`」を必ず含める**（issue #17 の受け入れ条件）。

## 3. `post-push-next-checklist.sh`（PostToolUse）

**2. の手順1〜4・6をそのまま持つ**（前置フィルタ／`tool_name` の3値／`project_dir` の解決と `cd`／
縮退時は `raw_hints_at_git_push` へ／`BASH_SOURCE` ガード）。違うのは手順5だけで、
`verify` の代わりに `push-checklist.sh new` を呼ぶ。

- **既存2本より後ろに登録する**（既存の出力を邪魔しない）。
- **既存2本のロジックは1バイトも変更しない**（issue #17 の受け入れ条件）。
- `new` が静かに0で終わる設計なので、hook側に条件分岐を持たない。
- **`new` の非0も素で受けない**（`set -e` で落ちる）。PostToolUseの非0はブロックしないが、
  エラーが出続けるだけで生成もされないため、`|| true` ではなく状態を見て握る。

## 4-6. 新規テスト3本

`test_block_direct_git_commit.sh` の2層構成を踏襲する。

- **層1（純粋関数）**: hookを `source` して `raw_hints_at_git_push` を直接呼ぶ。
  **超集合であることのケースを必ず持つ**（`pu\sh`・`PUSH`・JSONエスケープを跨いだ
  `pu\<改行>sh` 等）。終了コードは `if` で受ける（`$(func; echo $?)` は `set -e` 配下で空になる）。
- **層2（結合）**: サブプロセス起動＋`PATH` 先頭のスタブ `jq`。対象外ペイロードで
  **`jq` が1度も呼ばれないこと**を確認する。
- **hook 3本すべてに層1・層2を持たせる。** `post-push-next-checklist.sh` も例外にしない。
- `push-checklist.sh` のテストは、**一時ディレクトリにgitリポジトリを作って**実行する
  （このリポジトリの状態を変えない）。次を必ず含める（「異常が無ければ何も出ない」形にしない）。
  - `verify` の4条件それぞれについて、**意図的に壊したTSVで 1 が返ること**。
  - **HEADに対象が無いとき 3 が返ること**、`git rev-parse HEAD` が失敗するリポジトリ
    （unborn branch）でも**落ちずに 3 が返ること**。
  - **`stale` が、初回（`0 → 1`）と2回目以降のコミット忘れ（`3 → 4`）の両方で 0 を返すこと。**
    2回目以降のケースは、当初の設計が取りこぼしていた形なので必ず持つ。
  - **CRLFのフィクスチャで `# generated-for:` の SHA 比較が壊れないこと**（下記「改行コード」）。
- hookのテストには、**`verify` が1を返すペイロードで hook の終了コードが 2 であること**を
  1ケース置く（`set -e` で exit 1 へ落ちる罠を機械的に塞ぐ）。
- 出力は `passed=N failures=N`、失敗時は終了コード1。

## 7. `test_sync_gemini_assets.sh` のT11・T12改修

**対象は「`raw_hints_at_git_push` を持つhook」の全件＝既存2本＋新規2本の4本**である。
以降この本数を他の箇所へ書かず、「T11の対象hook」と参照する（数を表す語が散ると、実装時に
1箇所だけ直して残りが古くなる）。

```
323:for h in post-push-usage-report post-push-compact-prompt; do   ← ループ（行の存在確認）
338:assert_eq "T11: 2本の raw_hints_at_git_push が同一実装である"   ← ドリフト検出の本体
411:for h in post-push-usage-report post-push-compact-prompt; do   ← T12（ゼロforkの確認）
```

**3箇所すべてを直す**（敵対的レビュー フェーズ3・1回目で指摘）。当初はループだけを挙げていたが、
**ドリフトを実際に禁じているのはループの外にある338行の1対1 `assert_eq`** であり、そこを広げ
なければ新規2本は「行が存在する」ことしか確かめられず、**関数本文がドリフトしても緑のまま**になる。
写経方式を選ぶ根拠（既存2本の前例）が、その前例を支えているテストごと引き継げていなかった。

1. **ループ（323行）** へ新規2本を足す。
2. **同一性アサーション（338行）** を、基準1本（`post-push-usage-report.sh`）と残り全本を
   比べるループへ書き換える。ケース名も「T11の対象hook全件の raw_hints_at_git_push が
   同一実装である」のように件数を書かない形にする。
3. **T12のループ（411行）** へも新規2本を足す。前置フィルタを持たせる目的（空振り時のゼロfork）が、
   新規hookでも機械的に確かめられるようにする。`post-push-next-checklist.sh` は
   `settings.json` 登録前でも直接起動できるので検証できる。

**テストは実装を `source` して呼ぶ形を崩さない**（テスト側へ写経しない）。

**引用した行番号は実行時に取り直すこと。** 当初この計画は338行を `339` と書いていた（1行ずれ）。
位置を頼りに編集せず、`grep -n` で都度求める。

## 8. `.claude/settings.json`

- `PreToolUse` の `Bash|PowerShell` matcher へ `block-unchecked-push.sh` を追加（`if` は付けない。
  `block-direct-git-commit.sh` と同じ）。
- `PostToolUse` の `Bash|PowerShell` matcher の**末尾**へ、`if: "Bash(git push*)"` と
  `if: "PowerShell(git push*)"` の2エントリを追加。
- `timeout` は既存に合わせ、PreToolUse 10 / PostToolUse 20。

## 改行コード（CRLF対策）

**`.gitattributes` の `eol=lf` は `*.sh` にしか掛からず、`* text=auto` の行は配布対象外である**
（`dist:begin`〜`dist:end` の外）。したがって Windows で `core.autocrlf=true` の開発者・配布先が
チェックアウトすると、コミット済みチェックリストの**作業ツリー上の各行が CRLF になる**。

`verify` は `git show HEAD:` の blob（LF）を読むので無事だが、**作業ツリーを読む処理**——
`check`/`skip` の書き換え、生成条件2（`# generated-for:` の走査）、`<N>` の最大値スキャン、
`stale` の比較——は行末の `\r` を拾う。SHA比較が `<sha>\r` と `<sha>` の不一致になれば
**毎push新しいチェックリストが生えて冪等性が崩れる**。

**対処**: `push-checklist.sh` が作業ツリーの行を読む箇所で `${line//$'\r'/}` を当てる
（bash組み込みなのでforkは増えない）。`.gitattributes` を触る案は採らない——配布行の増減は
`check-dist-coverage.sh` と配布先への影響を伴い、この計画の範囲を超えるため。
テストにCRLFフィクスチャのケースを置いて機械的に固定する。

**実機（Windows）での再現は本セッションでは行っていない**（Linux環境のため）。仕様へもその旨を書く。

## 登録後の自己適用（フェーズ3〜5の運用）

**`.claude/settings.json` へ登録した瞬間から、この issue の作業自身が機構の対象になる**
（敵対的レビュー フェーズ3・1回目で指摘）。以降のpushで PostToolUse がチェックリストを生成し、
次のcommitへ含めなければ `stale` の警告が出て、`pending` のままpushすると exit 2 でブロックされる。

ところが「AIエージェントがcommit前に `check`/`skip` を実行する」手順は**フェーズ4**で
`commit` スキル・`issue-mr-flow` へ書く予定であり、フェーズ3〜5の間の運用が決まっていない。

**この計画では次の暫定手順を採る**（フェーズ4で正式な手順を書くまでの間）。

1. 各pushの前に `bash .claude/scripts/src/push-checklist.sh check <id> <実施ログ>` を項目ごとに
   実行する（該当しない項目は `skip <id> <理由>`）。
2. 生成されたチェックリストは、そのpushのcommitへ**必ず含める**。
3. flow-id 5-5（`cleanup-task.sh`）の直後の 5-6 のpushで**再生成されないこと**を実地で確認し、
   結果をworklogへ記録する。

**3は副次的に、生成条件3（HEADにタスク成果物が残っているときだけ生成する）の実地検証になる。**
本番相当で1度も通さずにマージへ進まないための手順でもある。

## 検証（合格条件）

**着手前に変更前のツリーで流し、期待どおりの結果になることを確かめてから実装する。**
下の各ブロックは、**新規ファイルが無い状態では 1・3・5 が非0で落ちる**（実測で確認した）。

```bash
# 1. 構文チェック（新規3本）。失敗を集計して終了コードへ伝播させる
fail=0; n=0
for f in .claude/scripts/src/push-checklist.sh \
         .claude/hooks/block-unchecked-push.sh \
         .claude/hooks/post-push-next-checklist.sh; do
  n=$((n + 1))
  bash -n "$f" || { echo "NG: $f"; fail=1; }
done
echo "構文チェック本数=$n"
[ "$n" -gt 0 ] && [ "$fail" = 0 ]

# 2. 前置フィルタが対象hook全件で同一実装であること（T11）＋ ゼロfork（T12）
bash .claude/scripts/test/test_sync_gemini_assets.sh

# 3. 新規テスト3本
bash .claude/scripts/test/test_push_checklist.sh
bash .claude/scripts/test/test_block_unchecked_push.sh
bash .claude/scripts/test/test_post_push_next_checklist.sh

# 4. 既存テストの回帰（同上）
fail=0; n=0
for t in .claude/scripts/test/test_*.sh; do
  n=$((n + 1))
  bash "$t" || { echo "NG: $t"; fail=1; }
done
echo "実行本数=$n"
[ "$n" -gt 0 ] && [ "$fail" = 0 ]

# 5. settings.json が妥当なJSONで、hookが過不足なく登録されていること
jq -e '[.hooks.PreToolUse[].hooks[]
        | select(.args[0] | endswith("block-unchecked-push.sh"))] | length == 1' \
  .claude/settings.json > /dev/null
jq -e '[.hooks.PostToolUse[].hooks[]
        | select(.args[0] | endswith("post-push-next-checklist.sh"))] | length == 2' \
  .claude/settings.json > /dev/null

# 6. 変換同期が未実施であることの検出（flow-id 5-3 で解消する）
bash .claude/scripts/src/sync-gemini-assets.sh --check

# 7. 配布層の網羅性（回帰確認）
bash .claude/scripts/src/check-dist-coverage.sh
```

**当初、1・5・6 は検証になっていなかった**（敵対的レビュー フェーズ3・1回目で指摘。3つとも
実際に実行して確かめた）。

| 検証 | 当初の主張 | 実測 | 直し方 |
|---|---|---|---|
| 1 | 「新規ファイルが無いので落ちる」 | `NG:`×3 を出して**終了コード0**（`\|\| echo` が失敗を吸収） | 4と同じ集計形へ |
| 5の2つ目 | 「登録漏れがあれば非0で落ちる」 | `0` を印字して**終了コード0**（件数を出すだけ） | `jq -e '… == 2'` で期待値を機械判定へ入れる |
| 旧6（dist-coverage） | 「`.claude/` へ足すと落ちうる」 | `.claude` は**ディレクトリ単位**で core 登録済み。`結果: OK` | この変更で実際に落ちる `sync-gemini-assets.sh --check` を新6として置き、dist-coverage は7（回帰確認）へ降格 |

**5は `jq -e` に `== 1` / `== 2` という期待値を入れてあるので、片方だけ足し忘れた場合も落ちる**
（PostToolUse は `Bash(git push*)` と `PowerShell(git push*)` の2エントリが要る。片方欠けても
件数を印字するだけの形では気づけなかった）。

**7（dist-coverage）は、この変更に対しては1件も検出しない。** `.claude/dist-layers.json` が
`{"layer":"core","path":".claude"}` というディレクトリ単位のエントリを持ち、`wip/worklogs` も
`layer: local` で登録済みだからである。**それでも流すのは他の3検査の回帰確認のため**であり、
「配布層の面が確かめられた」と読まないこと。

## やらないこと

- **チェック項目の実施そのものを機械判定しない**（自己申告のまま）。理由は調査結果の
  「守れない範囲」・DDR `i0017-01` の却下案として書く。
- **既存push系hook 2本のロジックを変更しない。**
- **`.gemini/` を直接編集しない**（flow-id 5-3 の変換同期で追随させる）。
- **`.gitattributes` を触らない**（CRLF対策はスクリプト側で行う。上記「改行コード」）。
- **spec / DDR / `docs-workflow.md` 等への反映はフェーズ4で行う**（この計画の対象外）。

### 存在しないspecを参照しないこと

**フェーズ3の時点で `.claude/docs/spec/push-checklist.md` は存在しない**（作るのはフェーズ4）。
当初この計画は「新規スクリプトのヘッダコメントに参照先として同ファイルを書く」「ブロック
メッセージにも含める」と指示していたが、**フェーズ3〜4の間、コードとブロックメッセージが
存在しないファイルを案内する**ことになる（敵対的レビュー フェーズ3・1回目で指摘）。
`check-doc-references.sh` は**DDRパスしか検出対象にしていない**（同スクリプト35行）ため、
この参照切れは**自動検出されない**（実際に流しても `参照切れ数=0`）。

**採る対処**: フェーズ3の実装単位に **spec のプレースホルダ作成を含める**。
`.claude/docs/spec/push-checklist.md` を、frontmatter ＋「## 背景・目的」「## 仕様」
「**この仕様は flow-id 4-6 で完成させる。現時点は実装からの参照先を成立させるための骨組みである**」
という最小の骨組みで先に置く。理由は次のとおり。

- ヘッダ・メッセージをフェーズ4で書き足す案は、**書き足し忘れが自動検出されない**（上記）。
- issue番号だけを参照する案は、**ブロックされた人がルールの本文へ辿り着けない**
  （issue #17 の受け入れ条件「ブロックメッセージがルールファイルのパスを示す」を満たさない）。

**中身の記述はフェーズ4のまま**なので、「spec / DDR への反映はフェーズ4」という上の線引きは
変わらない（フェーズ3で置くのは骨組みだけ）。

## 未確定事項（実装中に確定させる）

1. **`check` / `skip` のTSV書き換えで、実施ログ中のタブをどう扱うか。** 調査結果Q3は
   「エスケープしない」方針だが、`verify` が4フィールド固定を要求するため、
   **タブを空白へ潰す**のが最小の対処になる見込み。
2. **警告（exit 1）の文面**。stderrが届くか未確認なので、届かなくても機構が壊れないことを保つ。

**当初あった「T11の対象本数が3本か4本か」は、フェーズ3・1回目の敵対的レビューで確定した**
（`raw_hints_at_git_push` を持つhook全件＝既存2本＋新規2本の4本。上記「7.」）。
