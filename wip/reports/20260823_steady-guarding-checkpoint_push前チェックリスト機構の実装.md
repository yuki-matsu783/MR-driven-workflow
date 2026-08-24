---
title: push前チェックリスト機構の実装（作業結果）
type: report
description: issue #17 のpush前チェックリスト機構を、スクリプト1本・hook2本・テスト3本＋既存T11/T12の改修として実装した結果と、その検証記録。
tags: [report, issue-mr-flow, hook, push]
keywords: [push前チェックリスト, PreToolUse, PostToolUse, push-checklist, verify, stale, TSV, T11, 単体テスト, 縮退]
---

# push前チェックリスト機構の実装（作業結果）

対象: issue #17「hookを使って、push時にしてほしいことを実現する」フェーズ3（flow-id 3-6／3-9）。
全体作業計画: `wip/plans/steady-guarding-checkpoint.md`
個別作業計画: `wip/plans/【実装】【テスト】push前チェックリスト機構の実装.md`
前提となる調査結果: `wip/reports/20260823_steady-guarding-checkpoint_push前チェックリスト機構の設計調査.md`

**この文書が作業結果の正文である**（計画ファイルへ結果を書かないための分離先）。
**敵対的レビュー2回目（8件）の反映を含む**（flow-id 3-9）。

## 重点レビュー依頼

### 判断してほしいこと

1. **登録後の自己適用をどう回すか**（[7](#7-登録後の自己適用と実運用での検証)）。`settings.json` へ登録した時点から、
   この作業自身が機構の対象になる。フェーズ4で `commit` / `issue-mr-flow` の SKILL.md へ正式な
   手順を書くまでの間は、**各commit前に `check`/`skip` を手で実行する暫定手順**で回す。
   実運用で分かったのは、**チェックリスト1本につきコミットが2回になる**こと（生成直後に
   `pending` のまま1回、埋めてから1回）。フェーズ4で (a) この2コミット方式を手順化する、
   (b) 生成を PostToolUse ではなく次のcommit時へ遅らせる、(c) 埋め終わるまで
   `.gitignore` 対象に置く、のどれを採るかを決めたい。**(a) を推す**——最も単純で、
   「何を確認してpushしたか」がGit履歴に2段階で残る利点がある。
2. **`git push --tags` / `git push origin --delete <branch>` のような、現在のブランチを
   送らないpushまで一律にブロックしてよいか**（敵対的レビュー2回目の報告のみ1件）。
   `verify` は「現在のブランチのHEADにある最新チェックリスト」だけを見ており、
   **何をpushしようとしているかは見ていない**。緊急時の抜け道は現状「全項目を `skip` する」
   しかなく、それはspecにもブロックメッセージにも書かれていない。フェーズ4で
   (a) ブロック対象を絞る、(b) 抜け道を明文化する、のどちらかを決めたい。

### 方針を決めた点

3. **`stale`（チェックリストのコミット忘れ）を、警告（exit 1）から**ブロック（exit 2）**へ変えた**
   （敵対的レビュー2回目の major 指摘）。詳細は[4](#4-staleコミット忘れの検知をブロックへ倒した)。
4. **縮退時（`lib/CommandPosition.sh` を読めない）のブロック判定を、前置フィルタの流用から
   専用の絞り込み関数へ変えた**（同 blocker 指摘）。詳細は[2](#2-縮退時のブロック判定が回復不能だった-blocker)。
5. **チェック項目の文言は、markdownの表ではなくQ3のTSVサンプルに合わせた**（バッククォートを
   含めない）。加えて、ディレクトリ名は `{plansDir}` / `{reportsDir}` のプレースホルダにして
   `init_context` が設定値で埋める形にした（同 minor 指摘）。
6. **`verify` の失敗理由は stdout へ出す**（stderr ではない）。hookが `$(...)` で捕まえて
   ブロックメッセージへ載せるためである。スクリプト自身のエラー（未知のid等）は stderr。

### 機械的な変更・自信のある点

7. 前置フィルタ `raw_hints_at_git_push` は既存2本から**バイト単位で同一**に写した
   （`diff` で確認済み。T11がこれを機械的に固定する）。
8. 既存push系hook 2本（`post-push-usage-report.sh` / `post-push-compact-prompt.sh`）は
   **1バイトも変更していない**。

## サマリ

| # | 結論 |
|---|---|
| 1 | 9ファイル（新規6・改修2・spec骨組み1）を作り、**単体テスト23本・合計1,630アサーション**が失敗0で通った |
| 2 | **敵対的レビュー2回目で blocker を1件検出した**——縮退時に「push」を含む全コマンドがブロックされ、回復用の `push-checklist.sh check` 自身も止まって回復不能だった。専用の絞り込み関数へ差し替え、縮退経路のテスト層を新設した |
| 3 | `verify` は3値（0/1/3）。hookは 1 を exit 2 へ翻訳し、3 ではブロックしない |
| 4 | `stale`（コミット忘れ）は**ブロック（exit 2）へ倒した**。機構が防ぎたい失敗が唯一ブロックされない経路になっていたため |
| 5 | T11のドリフト検出を「基準1本 vs 残り全本」のループへ書き換え、**hookの一覧を実ファイルから導いて突き合わせる**アサーションを新設した。どちらも意図的に壊して落ちることを確認した |
| 6 | TSVの分割に `IFS=$'\t' read -r -a` を使えないことが実装中に判明した（タブはIFS空白文字で、行末タブが捨てられる）。bash組み込みだけの `split_tsv_line` を書いた |
| 7 | **本番リポジトリでの実push検証が取れた**——生成 → 未完了でブロック（exit 2）→ 埋めて通過 → 次回分の生成、の一巡を実地で確認した |

## 確かめられなかったこと

- **git bash（Windows）実機での挙動と性能。** 本セッションはLinuxのため、CRLFの混入は
  `sed -i 's/$/\r/'` のフィクスチャで再現したにとどまる。外部プロセス起動が約95ms/回という
  環境での実所要時間は測っていない。
- **`command_hints_at_git_push_degraded`（縮退時のブロック判定）は、精密判定の超集合ではない。**
  `eval "git push"` のように静的に読めない形は取りこぼす。**これは意図的なトレードオフ**で、
  取りこぼし（1回のpushが素通りする）より回復不能（作業が止まる）の害が大きいと判断した。
  どこまで取りこぼすかの網羅的な確認は行っていない。
- **PreToolUse の exit code 1 の stderr がユーザーへ届くか。** `stale` をブロックへ倒したため、
  **本機構の判定経路からは exit 1 が無くなった**（この未確認事項に依存しなくなった）。
  ただし依然として未確認であることに変わりはない。
- **PostToolUse hook の stdout がどう扱われるか。** `post-push-next-checklist.sh` は生成した
  パスを stdout へ出すが、表示されるか `additionalContext` として扱われるかは未確認。
  表示されなくても生成そのものは行われる（実地で確認済み）。

## 実施条件

- 実行環境: Claude Code on the web（Linux 6.18.44）／2026-08-23〜24
- bash: システム既定（`BASH_VERSINFO` は4.3以上）
- 検証コマンド: 計画「検証（合格条件）」の7ブロックをそのまま実行
- 一時リポジトリ: `mktemp -d` + `git init`。公開済み判定は
  `git update-ref refs/remotes/origin/main <HEAD>` でリモート追跡refを直接作った
  （実際にリモートへ送らずに `git branch --remotes --contains HEAD` を成立させる）
- 縮退経路の再現: hookを `lib/` を持たない一時ディレクトリへコピーして起動した

## 実施した内容と結果

### 1. 作ったもの（9ファイル）

| # | ファイル | 種別 | 規模 |
|---|---|---|---|
| 1 | `.claude/scripts/src/push-checklist.sh` | 新規 | 約540行 |
| 2 | `.claude/hooks/block-unchecked-push.sh` | 新規 | 約200行 |
| 3 | `.claude/hooks/post-push-next-checklist.sh` | 新規 | 約145行 |
| 4 | `.claude/scripts/test/test_push_checklist.sh` | 新規 | 95アサーション |
| 5 | `.claude/scripts/test/test_block_unchecked_push.sh` | 新規 | 56アサーション |
| 6 | `.claude/scripts/test/test_post_push_next_checklist.sh` | 新規 | 30アサーション |
| 7 | `.claude/scripts/test/test_sync_gemini_assets.sh` | 改修 | T11・T12を対象hook全件へ |
| 8 | `.claude/settings.json` | 改修 | PreToolUse 1件・PostToolUse 2件 |
| 9 | `.claude/docs/spec/push-checklist.md` | 新規（骨組み） | 本文はフェーズ4 |

実装は計画の順序どおりに進めた（spec骨組み → 本体 → PreToolUse → PostToolUse →
T11/T12改修 → `settings.json` → 回帰）。各段でその段のテストを通してから次へ進んでいる。

### 2. 縮退時のブロック判定が回復不能だった（blocker）

**敵対的レビュー2回目で検出し、実際に再現できた最も重い欠陥。**

当初、`lib/CommandPosition.sh` を読めない場合（`BASH_VERSINFO` < 4.3、ファイル欠落、source失敗）の
フォールバックとして、前置フィルタ `raw_hints_at_git_push` をそのまま流用していた。これは
「生JSONに `push` という語が現れるか」しか見ない**超集合**であり、前置フィルタとしては正しいが、
**ブロック判定の本体に使うと過剰検知がそのまま exit 2 になる**。

`lib/` を持たない一時ディレクトリへhookをコピーして再現した（修正前）:

```
rc=0  ls -la
rc=2  echo "pushed already"
rc=2  cat docs/push-notes.md
rc=2  bash .claude/scripts/src/push-checklist.sh check worklog "追記した"
rc=2  bash .claude/scripts/src/push-checklist.sh path
rc=2  git push -u origin HEAD
```

**下から3・4行目が決定的で、ブロックを解くための `push-checklist.sh check` はパスに `push` を
含むため必ずブロックされる。** つまり縮退環境ではセッションが自力で回復できない。
**macOS 既定の `/bin/bash` は 3.2** なので、配布先で普通に起きる。

**修正**: 専用の純粋関数 `command_hints_at_git_push_degraded` を置き、生JSONではなく
`tool_input.command` を空白で分割して「basename が `git` のトークンがあり、その後ろに `push` の
トークンがある」ときだけブロックする。**`git` トークンをAND条件にしたことで、回復用コマンドは
構造的にブロックされない。** 修正後の実測:

```
rc=0  ls -la
rc=0  echo "pushed already"
rc=0  cat docs/push-notes.md
rc=0  bash .claude/scripts/src/push-checklist.sh check worklog "追記した"
rc=0  bash .claude/scripts/src/push-checklist.sh path
rc=0  bash .claude/scripts/src/create-commit.sh --message "chore: x" -- a.tsv
rc=2  git push -u origin HEAD
rc=2  git -C /x push
rc=2  git --no-pager push origin HEAD
rc=2  cd /tmp/x && git push -u origin feature-70
rc=2  git pu\sh
rc=2  git PUSH
```

**PostToolUse 側（`post-push-next-checklist.sh`）は前置フィルタの流用のままにした。**
あちらは生成であり、過剰検知しても `new` の3条件が受け止めて冪等に何もしない。
**この非対称は意図的**であり、両方のhookのコメントに理由を書いてある。

**あわせて、縮退経路のテスト層（層4）を新設した。** 当初のテストは hook を実パスから起動して
いたため `lib` が常に読め、`elif` の分岐が**一度も実行されていなかった**（テスト全緑のまま
この欠陥が素通りしていた）。

### 3. `IFS=$'\t' read -r -a` が使えなかった

TSVを4フィールド固定にする設計の根幹に関わる問題を、実装中に踏んだ。

**タブはbashのIFS空白文字である。** `IFS=$'\t'` を指定しても「連続するIFS空白は1つの区切りへ
畳まれ、先頭・末尾のものは無視される」という規則が働くため、`read -r -a` で分割すると

- `pending` 行の**行末タブが捨てられ**、4フィールドのはずが3になる
- 実施ログが空の `done` 行も同様に3になり、**条件4（4列目が空でない）が検出できない**

つまり、生成器が4フィールドで書いても検証器が3としか読めず、`verify` が自分の生成物を
必ず落とす。bash組み込みだけでタブを走査する `split_tsv_line` を書いて解決した
（`${rest%%$'\t'*}` / `${rest#*$'\t'}` の繰り返し。forkしない）。

この落とし穴は**テストで固定してある**（「行末タブでも4フィールド」「連続タブを畳まない」）。

### 4. `stale`（コミット忘れの検知）をブロックへ倒した

`verify` は「HEADにある**最大N**のチェックリストが全 done か」だけを見る。PostToolUse が
生成した次回分（push N+1）をコミットしなければ、HEADには**前回の全 done のチェックリスト
（push N）**が残っており、`verify` は 0 を返す。差分は `stale`（作業ツリーの最大N > HEADの最大N）が
拾うが、**当初そこは exit 1（非ブロックの警告）だった**。

敵対的レビュー2回目の指摘が正しかった。specが挙げる本機構の動機そのもの——「`HANDOFF.md` の
`- push回数:` をpushの後に更新し、**その1行だけが未コミットで残る**」＝**必要な更新をcommitへ
含め忘れた**——に当たるのがこの経路であり、**機構が防ぎたい失敗が唯一ブロックされない経路**に
なっていた。ブロックされるのは「チェックリストは含めたが埋めていない」場合だけで、これは
相対的に気づきやすい失敗である。

**修正**: `stale` が真なら exit 2 でブロックし、メッセージに回復手順（`check` で埋めてから
`create-commit.sh` でコミットへ含める）を出す。**回復手段が塞がらないこと**は確認済みで、
`create-commit.sh` の呼び出しは `git` トークンを持たないため縮退時も止まらない。

`stale` の判定式（Nの比較）自体は変えていない。**初回push**（`0 → 1`）と**2回目以降のコミット
忘れ**（`1 → 2`）を同じ1条件で拾うことは、引き続きテストが固定している。

### 5. T11・T12の改修（3箇所すべて）

計画どおり、ループ・同一性アサーション・T12のループの**3箇所すべて**を直した。加えて、
対象hookの一覧を**実ファイルから導いて突き合わせる**アサーションを新設した。

```bash
while IFS= read -r _f; do ... done < <(grep -lFx -- 'raw_hints_at_git_push() {' "$repo_root"/.claude/hooks/*.sh | sort)
```

**どちらのアサーションも、意図的に壊して実際に落ちることを確かめた**（「異常が無ければ何も
出ない検証」にしないため）。

| 壊し方 | 結果 |
|---|---|
| `post-push-next-checklist.sh` の関数本文へ1行コメントを足す | `FAIL: T11: post-push-next-checklist.sh の raw_hints_at_git_push が基準…と同一実装である` |
| 一覧へ載せずに5本目のhook（前置フィルタ持ち）を置く | `FAIL: T11: 前置フィルタを持つhookの一覧が実ファイルと一致する` |

### 6. 検証（計画の7ブロック）

**着手前に変更前のツリーで流し、1・5が期待どおり非0で落ちることを確認してから実装した。**

| ブロック | 実装前 | 実装後 |
|---|---|---|
| 1. 構文チェック（新規3本） | 非0（3本とも `No such file or directory`） | **0**（本数=3） |
| 2. `test_sync_gemini_assets.sh` | 0（既存2本のみ対象） | **0**（`passed=106 failures=0`） |
| 3. 新規テスト3本 | 非0（ファイルが無い） | **0**（95 / 56 / 30） |
| 4. 既存テスト回帰（全件） | 0 | **0**（実行本数=23、失敗0） |
| 5. `settings.json` の登録（`== 1` / `== 2`） | 非0（未登録） | **0** |
| 6. `sync-gemini-assets.sh --check` | 0 | **1**（＝flow-id 5-3 で解消すべき差分あり。期待どおり） |
| 7. `check-dist-coverage.sh`（回帰確認） | `結果: OK` | `結果: OK` |

**アサーション総数は 1,630（23ファイルの `passed=` の合計）。**

**当初この数を「1,699」と書いていたが誤りだった**（敵対的レビュー2回目の major 指摘）。
合計を実際に取らずに書いた数で、同じ数値が md・html・`HANDOFF.md` の6箇所へ伝播していた。
レビュー時点の断面（9738ec2）で実測すると 1,598 で、その後の修正で 1,630 になっている。

**さらに、訂正した直後の版で「1,631」と1件ずれていた**（flow-id 3-10 の直前に再実測して発見）。
指摘を受けて数え直したはずの数が、もう一度ずれていたことになる。23ファイルを回して
`passed=` を足し込むワンライナーで2回測り、どちらも 1,630 で一致することを確認してから
この版へ書いている。**数を書くときは、その場で合計を取ってから書く**——「前に測ったから
正しいはず」は根拠にならない（この文書の数は上の回帰実行の出力そのもの）。

7（dist-coverage）は**この変更に対しては1件も検出しない**。`.claude/dist-layers.json` が
`{"layer":"core","path":".claude"}` というディレクトリ単位のエントリを持つためで、
「配布層の面が確かめられた」と読まないこと。

### 7. 登録後の自己適用と、実運用での検証

**`settings.json` へ登録した瞬間から、この issue の作業自身が機構の対象になる。**
実際にこのブランチで一巡し、**フィクスチャではなく本番のリポジトリで**次を確認した。

| 段階 | 結果 |
|---|---|
| pushの直後、PostToolUse が `wip/worklogs/20260823_claude_hook-implementation-17-vjhppj_push1_checklist.tsv` を生成 | `# generated-for:` がHEADのSHAと一致。データ行はすべて4フィールド（`cat -A` で行末タブを確認） |
| 未完了のままpushを試行 | **PreToolUse が exit 2 でブロック**。5件の未完了項目名と `.claude/skills/commit/SKILL.md` / `.claude/docs/spec/push-checklist.md` を提示 |
| `check`×4・`skip`×1 で埋めてコミット | `verify` が 0 を返し、pushが通った |
| push後 | 次回分（`push2`）が生成された |

issue #17 の受け入れ条件のうち、**ブロック動作とメッセージ内容が実運用で満たされた**ことになる。

**同時に、実運用で見えた摩擦が1つある**: pushのたびに未追跡のチェックリストが1本残るため、
「作業ツリーをクリーンに保つ」タイプのhookや運用と噛み合わない（このセッションでも実際に
2回指摘を受けた）。**チェックリスト1本につきコミットが2回**になる。上記「重点レビュー依頼」1。

### 8. 未確定事項の確定

| # | 計画時 | 確定した内容 |
|---|---|---|
| 1 | `check` / `skip` のTSV書き換えで、実施ログ中のタブをどう扱うか | **タブ・改行・CRをすべて半角スペースへ潰し、前後を刈る**（`normalize_log_to_reply`）。潰した結果が空なら `check` は終了コード1で拒否する |
| 2 | 警告（exit 1）の文面 | **exit 1 の経路自体を無くした**（`stale` をブロックへ倒したため。上記4）。判定経路に残る終了コードは 0 と 2 だけになった |

## 設計への反映

フェーズ4（flow-id 4-6）で次を行う。

- `.claude/docs/spec/push-checklist.md` の本文（現在は骨組みのみ）。
  上記2〜5の内容と、調査結果Q1〜Q8をここへ移す。**縮退時の判定が精密判定の超集合ではない
  こと**と、その理由（回復不能を避ける）は必ず書く。
- DDR `i0017-01`。却下案として「チェック項目の実施そのものを機械判定する」
  「flow-idに応じて項目を可変にする」「`.gitignore` 対象の `wip/state/` へ置く」
  「縮退時のブロック判定に前置フィルタを流用する」を残す。
- `.claude/docs/README.md` のspec一覧、`docs-workflow.md` のライフサイクル表
  （チェックリストは `wip/worklogs/` にあり flow-id 5-5 で削除される）、
  `directory-structure.md`、`index.md`。
- `commit` / `issue-mr-flow` の SKILL.md へ、`check`/`skip` を**commitより前に**実行する手順と、
  「生成 → pendingでコミット → 埋めてコミット → push」の運用（重点レビュー依頼1の結論）。
- `.claude/VERSION`。

## 残課題

- **`git push --tags` / `git push origin --delete <branch>` のような、現在のブランチを送らない
  pushまで一律にブロックする**（敵対的レビュー2回目の報告のみ1件）。緊急時の抜け道が
  文書化されていない点も含め、フェーズ4で方針を決める。重点レビュー依頼2。
- **生成条件3（HEADにタスク成果物が残っているか）は、チェックリスト自身を「成果物」に
  数えている。** `cleanup-task.sh` はチェックリストも同じディレクトリごと消すため実害は
  無いが、「チェックリストだけが残っている」状態を作れば生成が続く。計画どおり
  `TEMPLATE.md` / `REVIEW-POINTS*.md` のみを除外する実装にしてあり、**計画から逸脱しない
  ことを優先した**。フェーズ4のspecへ既知の性質として書く。
- **flow-id 5-5 直後の 5-6 のpushで再生成されないこと**は、フェーズ5で実地確認する
  （生成条件3の本番検証）。
