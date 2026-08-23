---
title: i0149-01. post-issue-create-notice.shの検知をコマンド位置判定へ移行する
type: ddr
description: post-issue-create-notice.shのCLI経路検知を部分一致からコマンド位置判定へ移すにあたり、既存のgit専用トークン走査とは意図的に変えた4つの設計判断（sticky解除・{}除外・3段ガード遅延初期化・保守的フォールバックの踏襲）と却下案を記録したDDR
tags: [ddr, hooks, 検知, shell, command-position]
keywords: [command_invokes_script, コマンド位置, sticky, 遅延初期化, 保守的フォールバック, 前置フィルタ, issue-create, 誤検知, 検知漏れ]
---

# i0149-01. post-issue-create-notice.shの検知をコマンド位置判定へ移行する

## 背景

`.claude/hooks/post-issue-create-notice.sh` のCLI経路検知は、`[[ "$command" == *create-issue.sh* ]]`
という**部分一致**だけで発火を決めていた。issue #53（DDR `i0053-01`）で他の3本のhook
（`block-direct-git-commit.sh` / `post-push-usage-report.sh` / `post-push-compact-prompt.sh`）は
コマンド位置判定へ移行したが、issue #53 は本hookを名指ししておらずスコープ外としていた。

issue #53 の作業中に**誤発火を3回踏んでおり**（該当節に触れるたびに発火した）、issue #149として
起票された。既存の`CommandPosition.sh`はgitのサブコマンド固定の判定
（`command_invokes_git_subcommand` / `_cp_scan_tokens`）しか持たず、任意のスクリプトの
basenameを判定する仕組みが無かったため、これを新設して流用する方針とした。

## 決定

1. `.claude/hooks/lib/CommandPosition.sh` へ、任意のスクリプトbasenameをコマンド位置で判定する
   公開関数 `command_invokes_script` と、その内部実装 `_cp_scan_tokens_for_script` を追加する。
   既存のgit専用関数（`_cp_scan_tokens` / `command_invokes_git_subcommand`）は変更しない。
2. `_CP_PREFIX_WORDS`（sudo/if/timeout等）通過後の挙動を、git版のsticky（次のセパレータまで
   コマンド位置を保つ）ではなく、**「次の非オプション・非代入トークンを実コマンドとして
   1回だけ判定し、そこでコマンド位置を終える」**にする。
3. `{`/`}` を、トークン化のための人工的な空白挿入の対象から**除外**する（git版は含める）。
4. `post-issue-create-notice.sh`の3段ガードは、**判定関数自体をトップレベルで関数として
   存在させつつ、実際の初期化（`source`・バージョン確認）は初回呼び出しまで遅延させる**
   （自分自身を確定版へ再定義してから委譲する形）。他の3本が採る「`main()`内・前置フィルタの
   後で確定させる」型とは異なる。
5. 保守的フォールバック（`_CP_OPAQUE_FOUND`による部分一致への縮退）は、git版と同じ設計原則を
   踏襲しつつ、インタプリタ経由の直後の引数が正規化でプレースホルダへ潰れている場合
   （クォート付きパス等）も対象に加える。

## 理由

### 2. sticky を解除した理由

git版のsticky（`_CP_PREFIX_WORDS`通過後、次のセパレータまでコマンド位置を保ち続ける）は、
「離れた位置にある固定語（`git`）を1つ探す」判定では実害が小さい。しかし任意のスクリプト
basenameを探す判定でこれを真似ると、`sudo cat <スクリプトパス>` や
`timeout 5 grep -rn x <スクリプトパス>` のように、**無関係なコマンドの引数にスクリプト名が
現れただけ**で誤って一致してしまう（敵対的レビュー1回目で検出）。

### 3. `{`/`}` を除外した理由

`{`/`}` を人工的な空白挿入の対象に含めると、`${VAR}/path` のようなパラメータ展開の直後
（`}`の直後）が誤ってコマンド位置と認識される（敵対的レビュー1回目で検出。
`cat ${REPO}/.claude/scripts/src/create-issue.sh` が誤検知した）。ブレースグループ
（`{ cmd; }`）は、bash構文上`{`/`}`の前後に空白が必須のため、この人工的な挿入が無くても
素の空白分割で独立トークンになり、検知は失われない。

### 4. 3段ガードを遅延初期化にした理由

`post-issue-create-notice.sh`は、`source`して`main()`を実行せず判定関数を直接呼ぶ単体テストが
あるため、判定関数自体は**トップレベルで関数として存在**させる必要がある。しかし、トップレベルで
即座に`source`まで完了させると、`raw_hints_at_issue_create`（前置フィルタ、issue #159・DDR
`i0159-01`）で弾かれる呼び出しでも毎回`CommandPosition.sh`（約800行）を読み込むことになり、
フィルタ済みの高速経路で計測上+35%（+1.0ms/回）の遅延が生じる（敵対的レビュー2回目で検出・
実測）。issue #159 が「空振りのコストを空関数と同じ水準まで落とす」ことを目的にした最適化を、
issue #149 が無言で一部戻す形になってしまうため、初回呼び出し時に自分自身を確定版へ再定義する
形にして両立させた。

### 5. クォート付きパスを保守的フォールバックの対象に加えた理由

正規化の設計上、クォート内容はプレースホルダへ潰れるため、`bash "$VAR/create-issue.sh"`の
ような形は位置判定そのものでは検知できない。issue #149の実装当初はこれを「既知の制約」として
受容していたが、敵対的レビュー2回目で「**旧・部分一致実装に対する機能後退**である」（`.claude/settings.json`
自身が`"${CLAUDE_PROJECT_DIR}/..."`のようなクォート付きパスを使っており、実運用で普通に
起こりうる）と指摘された。インタプリタ直後の引数がプレースホルダに潰れている場合に限り
保守的フォールバックへ回すことで、位置判定の精度を落とさずに**インタプリタ経由の形について
検知漏れを解消した**。**ただし、インタプリタを介さない直接起動**（`"$DIR/create-issue.sh"
--title x`のように、実行ファイルとして直接呼ぶ形）**は今回の対応でも検知できず、既知の制約と
して残る**（`command-position.md`「既知の制約」参照。敵対的レビュー3回目で指摘）。

## 却下案

| 案 | 却下理由 |
|---|---|
| `_cp_scan_tokens`（git版）をそのまま流用し、対象語だけをパラメータ化する | 上記2・3の誤検知パターンをそのまま引き継ぐ。gitサブコマンドという「離れた位置の固定語探索」に最適化された設計を、「任意のスクリプト実行」判定へ転用すると誤検知の性質が変わる |
| 3段ガードをトップレベルで即座に`source`まで完了させる（他の3本と同じ型） | 前置フィルタで弾かれる呼び出しでも毎回ライブラリを読み込み、+35%の性能回帰を生む（敵対的レビュー2回目で実測） |
| クォート付きパスは（インタプリタ経由・直接起動とも）見逃したままにする（既知の制約として受容） | インタプリタ経由の形だけでも、旧・部分一致実装に対する機能後退になり、`.claude/settings.json`自身のような実運用パターンで検知漏れが悪化する（敵対的レビュー2回目で指摘）。直接起動の形は本対応でも解消せず既知の制約として残る（敵対的レビュー3回目で指摘） |
| `bash -n <script>`（構文チェックのみ）も他のオプションと同様に検知対象にする | 本hookが減らそうとしている「ファイルを検査するだけで発火する」クラスそのものであり、リポジトリ自身の規約（`.claude/rules/shell-script-style.md`「テスト」が`.sh`作成時に`bash -n`を必須とする）と直接衝突する |

## 影響範囲

- `.claude/hooks/lib/CommandPosition.sh`（`_cp_scan_tokens_for_script` / `command_invokes_script` 新規追加）
- `.claude/hooks/post-issue-create-notice.sh`（CLI経路判定の差し替え、3段ガード追加）
- `.claude/scripts/test/test_command_position.sh`（75件→118件）
- `.claude/scripts/test/test_post_issue_create_notice.sh`（31件→38件）
- `.claude/docs/spec/command-position.md`（利用元・公開インターフェース・判定の3段・呼び出し側の責務・既知の制約・未決定事項・影響範囲）
- `.claude/docs/spec/issue-mr-workflow.md`（検知の条件・既知のトレードオフ）
- `.claude/rules/shell-script-style.md`（create-issue.shの部分一致例が縮退経路限定になった旨の追記）
