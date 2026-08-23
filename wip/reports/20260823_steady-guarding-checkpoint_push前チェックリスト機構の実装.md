---
title: push前チェックリスト機構の実装（作業結果）
type: report
description: issue #17 のpush前チェックリスト機構を、スクリプト1本・hook2本・テスト3本＋既存T11/T12の改修として実装した結果と、その検証記録。
tags: [report, issue-mr-flow, hook, push]
keywords: [push前チェックリスト, PreToolUse, PostToolUse, push-checklist, verify, stale, TSV, T11, 単体テスト]
---

# push前チェックリスト機構の実装（作業結果）

対象: issue #17「hookを使って、push時にしてほしいことを実現する」フェーズ3（flow-id 3-6）。
全体作業計画: `wip/plans/steady-guarding-checkpoint.md`
個別作業計画: `wip/plans/【実装】【テスト】push前チェックリスト機構の実装.md`
前提となる調査結果: `wip/reports/20260823_steady-guarding-checkpoint_push前チェックリスト機構の設計調査.md`

**この文書が作業結果の正文である**（計画ファイルへ結果を書かないための分離先）。

## 重点レビュー依頼

### 判断してほしいこと

1. **登録後の自己適用をどう回すか**（計画「登録後の自己適用」節）。`settings.json` へ登録した
   時点から、この作業自身が機構の対象になる。フェーズ4で `commit` / `issue-mr-flow` の
   SKILL.md へ正式な手順を書くまでの間は、**各commit前に `check`/`skip` を手で実行する暫定
   手順**で回す。「フェーズ4が終わるまで登録を保留する」ほうがよければ、`settings.json` の
   変更だけを後ろへ回せる（他の8ファイルは登録と独立している）。
2. **`stale` 警告の exit 1 が実際にユーザーへ届くか**は未確認である（下記「確かめられなかった
   こと」）。届かない場合、コミット忘れは**気づかれないまま素通りする**（ブロックはしない設計
   のため実害は限定的だが、機構の一部が無言で効かなくなる）。届かないことが分かった場合の
   代案（exit 2 でブロック側へ倒す／PostToolUse の stdout で知らせる）をフェーズ4で決めたい。

### 方針を決めた点

3. **チェック項目の文言は、markdownの表ではなくQ3のTSVサンプルに合わせた**（バッククォートを
   含めない）。Q2の表は `` `HANDOFF.md` `` のようにバッククォートを付けているが、それは表の
   書式であって本文ではない。実ファイルへ書き出すのは素のテキストとした。
4. **`verify` の失敗理由は stdout へ出す**（stderr ではない）。hookが `$(...)` で捕まえて
   ブロックメッセージへ載せるためである。スクリプト自身のエラー（未知のid等）は stderr。

### 機械的な変更・自信のある点

5. 前置フィルタ `raw_hints_at_git_push` は既存2本から**バイト単位で同一**に写した
   （`diff` で確認済み。T11がこれを機械的に固定する）。
6. 既存push系hook 2本（`post-push-usage-report.sh` / `post-push-compact-prompt.sh`）は
   **1バイトも変更していない**（`git diff --stat` に現れない）。

## サマリ

| # | 結論 |
|---|---|
| 1 | 9ファイル（新規6・改修2・spec骨組み1）を作り、**単体テスト23本・1,699アサーションがすべて通過**した |
| 2 | `verify` は3値（0/1/3）。hookは 1 を exit 2 へ翻訳し、3 ではブロックしない |
| 3 | `stale` は「作業ツリーの最大N > HEADの最大N」。**初回pushと2回目以降のコミット忘れを同じ1条件で拾う**ことをテストで固定した |
| 4 | T11のドリフト検出を「基準1本 vs 残り全本」のループへ書き換え、**hookの一覧を実ファイルから導いて突き合わせる**アサーションを新設した。どちらも意図的に壊して落ちることを確認した |
| 5 | TSVの分割に `IFS=$'\t' read -r -a` を使えないことが実装中に判明した（タブはIFS空白文字で、行末タブが捨てられる）。bash組み込みだけの `split_tsv_line` を書いた |
| 6 | `check`/`skip` のログ中のタブは半角スペースへ潰す（未確定事項1を確定させた） |
| 7 | 変換同期（`sync-gemini-assets.sh --check`）は**未実施として検出される**。flow-id 5-3 で解消する |

## 確かめられなかったこと

- **PreToolUse の exit code 1 の stderr がユーザーへ届くか。** 調査結果（フェーズ2）から
  持ち越しの未確認事項。`stale` の警告経路がここに乗っている。届かなくても
  「ブロックはしない」という振る舞いは変わらないため、機構は壊れない。
- **git bash（Windows）実機での挙動と性能。** 本セッションはLinuxのため、CRLFの混入は
  `sed -i 's/$/\r/'` のフィクスチャで再現したにとどまる。外部プロセス起動が約95ms/回という
  環境での実所要時間は測っていない。
- **`settings.json` へ登録した状態での実push。** 本レポートを書いている時点ではまだ1度も
  pushしていない（このcommitのpushが初回になる）。計画の「登録後の自己適用」3で、
  flow-id 5-5 直後の 5-6 のpushで再生成されないことを実地確認する予定。
- **PostToolUse hook の stdout がどう扱われるか。** `post-push-next-checklist.sh` は生成した
  パスを stdout へ出すが、これが表示されるか `additionalContext` として扱われるかは未確認。
  表示されなくても生成そのものは行われる。

## 実施条件

- 実行環境: Claude Code on the web（Linux 6.18.44）／2026-08-23
- bash: システム既定（`BASH_VERSINFO` は4.3以上）
- 検証コマンド: 計画「検証（合格条件）」の7ブロックをそのまま実行
- 一時リポジトリ: `mktemp -d` + `git init`。公開済み判定は
  `git update-ref refs/remotes/origin/main <HEAD>` でリモート追跡refを直接作った
  （実際にリモートへ送らずに `git branch --remotes --contains HEAD` を成立させる）

## 実施した内容と結果

### 1. 作ったもの（9ファイル）

| # | ファイル | 種別 | 行数 |
|---|---|---|---|
| 1 | `.claude/scripts/src/push-checklist.sh` | 新規 | 約520 |
| 2 | `.claude/hooks/block-unchecked-push.sh` | 新規 | 約170 |
| 3 | `.claude/hooks/post-push-next-checklist.sh` | 新規 | 約140 |
| 4 | `.claude/scripts/test/test_push_checklist.sh` | 新規 | 87アサーション |
| 5 | `.claude/scripts/test/test_block_unchecked_push.sh` | 新規 | 32アサーション |
| 6 | `.claude/scripts/test/test_post_push_next_checklist.sh` | 新規 | 30アサーション |
| 7 | `.claude/scripts/test/test_sync_gemini_assets.sh` | 改修 | T11・T12を対象hook全件へ |
| 8 | `.claude/settings.json` | 改修 | PreToolUse 1件・PostToolUse 2件を追加 |
| 9 | `.claude/docs/spec/push-checklist.md` | 新規（骨組み） | 本文はフェーズ4 |

実装は計画の順序どおりに進めた（spec骨組み → 本体 → PreToolUse → PostToolUse →
T11/T12改修 → `settings.json` → 回帰）。各段でその段のテストを通してから次へ進んでいる。

### 2. `IFS=$'\t' read -r -a` が使えなかった（実装中に判明）

TSVを4フィールド固定にする設計の根幹に関わる問題を、実装中に踏んだ。

**タブはbashのIFS空白文字である。** `IFS=$'\t'` を指定しても「連続するIFS空白は1つの区切りへ
畳まれ、先頭・末尾のものは無視される」という規則が働くため、`read -r -a` で分割すると

- `pending` 行の**行末タブが捨てられ**、4フィールドのはずが3になる
- 実施ログが空の `done` 行も同様に3になり、**条件4（4列目が空でない）が検出できない**

つまり、生成器が4フィールドで書いても検証器が3としか読めず、`verify` が自分の生成物を
必ず落とす。bash組み込みだけでタブを走査する `split_tsv_line` を書いて解決した
（`${rest%%$'\t'*}` / `${rest#*$'\t'}` の繰り返し。forkしない）。

この落とし穴は**テストで固定してある**（「行末タブでも4フィールド」「連続タブを畳まない」）。

### 3. `verify` の3値と、hookでの翻訳

| `verify` | 意味 | hookの対応 |
|---|---|---|
| 0 | 4条件すべてを満たした | ブロックしない（ただし `stale` は別に見る） |
| 1 | 検証失敗（未完了・壊れている・件数が合わない） | **exit 2 でブロック** |
| 3 | HEADに対象のチェックリストが無い | ブロックしない（同上） |

unborn branch（コミットが1つも無い）・`git show` の失敗も 3 へ倒している。1（ブロック）へ
倒すと、コミットが1つも無いブランチで全pushが止まるためである。

hook側は `status=0; ... || status=$?` の形で受けている。`set -e` 配下で素の単純コマンドとして
受けると、**ブロックしたい場面でhook自身が exit 1 で終わり、ブロックされなくなる**。
この罠は「未完了なら exit 2」というテストケースが機械的に塞いでいる。

### 4. `stale`（コミット忘れの検知）が両方のケースを拾うこと

`stale` は「作業ツリーの最大N > HEADの最大N」だけを見る。テストで次の2つを固定した。

- **初回push**（HEADに無く作業ツリーにある = `0 → 1`）
- **2回目以降のコミット忘れ**（`1 → 2`）

後者では、同じ状態で `verify` が **0 を返す**ことも併せて表明してある
（HEADに残る古い・全 `done` のチェックリストを見るため）。**`verify` だけではコミット忘れを
検知できない**という、当初の設計が取りこぼしていた事実そのものをテストが記録している。

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
| 3. 新規テスト3本 | 非0（ファイルが無い） | **0**（87 / 32 / 30） |
| 4. 既存テスト回帰（全件） | 0 | **0**（実行本数=23、失敗0） |
| 5. `settings.json` の登録（`== 1` / `== 2`） | 非0（未登録） | **0** |
| 6. `sync-gemini-assets.sh --check` | 0 | **1**（＝flow-id 5-3 で解消すべき差分あり。期待どおり） |
| 7. `check-dist-coverage.sh`（回帰確認） | `結果: OK` | `結果: OK`（**この変更では1件も検出しない**。配布層の面が確かめられたと読まないこと） |

テスト23本の合計は **1,699アサーション・失敗0**。

### 7. 未確定事項の確定

| # | 計画時 | 確定した内容 |
|---|---|---|
| 1 | `check`/`skip` のログ中のタブをどう扱うか | **タブ・改行・CRをすべて半角スペースへ潰し、前後を刈る**（`normalize_log_to_reply`）。潰した結果が空なら `check` は終了コード1で拒否する（空の実施ログを `verify` が落とすため、先に止めたほうが原因が分かりやすい） |
| 2 | 警告（exit 1）の文面 | 「コミットされていないチェックリストがあります（作業ツリー push2 > HEAD push1）」＋「ブロックはしません」＋specのパス。**届かなくても機構が壊れないこと**は、ブロック判定と独立した経路にしてあることで担保している |

## 設計への反映

フェーズ4（flow-id 4-6）で次を行う。

- `.claude/docs/spec/push-checklist.md` の本文（現在は骨組みのみ）。
  上記2〜5の内容と、調査結果Q1〜Q8をここへ移す。
- DDR `i0017-01`。却下案として「チェック項目の実施そのものを機械判定する」
  「flow-idに応じて項目を可変にする」「`.gitignore` 対象の `wip/state/` へ置く」を残す。
- `.claude/docs/README.md` のspec一覧、`docs-workflow.md` のライフサイクル表
  （チェックリストは `wip/worklogs/` にあり flow-id 5-5 で削除される）、
  `directory-structure.md`、`index.md`。
- `commit` / `issue-mr-flow` の SKILL.md へ、`check`/`skip` を**commitより前に**実行する手順。
- `.claude/VERSION`。

## 残課題

- **`settings.json` の登録を含む状態での実push検証**（上記「確かめられなかったこと」）。
  flow-id 5-5 直後の 5-6 のpushで再生成されないことまで含めて、フェーズ5で実地確認する。
- **`stale` の警告が届くかどうか**による代案の決定（フェーズ4）。
- **生成条件3（HEADにタスク成果物が残っているか）は、チェックリスト自身を「成果物」に
  数えている。** `cleanup-task.sh` はチェックリストも同じディレクトリごと消すため実害は
  無いが、「チェックリストだけが残っている」状態を作れば生成が続く。計画どおり
  `TEMPLATE.md` / `REVIEW-POINTS*.md` のみを除外する実装にしてあり、**計画から逸脱しない
  ことを優先した**。フェーズ4のspecへ既知の性質として書く。
