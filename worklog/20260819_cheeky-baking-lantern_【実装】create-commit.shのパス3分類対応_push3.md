---
title: worklog 20260819 cheeky-baking-lantern 【実装】create-commit.shのパス3分類対応 push3
type: log
description: create-commit.shへADD/SKIP/UNKNOWNのパス分類を実装した際の作業ログ
tags: [issue-60, worklog, create-commit, 実装]
keywords: [create-commit, ls-files, ls-tree, 3分類, SKIP, UNKNOWN, 冪等, git add, push3]
---

# worklog: 【実装】create-commit.shのパス3分類対応

対象: `create-commit.sh` が受け取ったパスを追跡状態で分類し、削除済み・削除ステージ済みのパスを
そのまま渡せるようにする（issue #60、2026-08-19）。
全体作業計画: `plans/cheeky-baking-lantern.md`
個別作業計画: `plans/【実装】create-commit.shのパス3分類対応.md`
push回数: 3

## 試したこと

- flow-id 3-1: フェーズ2の調査結果（`-A` 不採用・3分類方式）をもとに個別作業計画を作成した
- flow-id 3-4: レビューを受け、UNKNOWN のエラー文は**事実のみ**とし、原因の解説は spec へ集約する
  方針に修正した（推測を並べると、実際は別の原因だったときに誤誘導になるため）
- flow-id 3-6: 計画どおり「常に分類してから `git add`」を実装 → 検証で機能後退が判明 →
  「まず現行どおり試し、失敗したときだけ分類する」方式へ作り直した
- 検証は計画の6ケースに4ケース（SKIPのみ／ディレクトリ指定／`.gitignore`混在／HEAD無し）を足し、
  一時リポジトリで10ケース・29アサーションを実行した

## うまくいったこと

- **「まず `git add` を試し、失敗時だけ分類する」構造にしたことで、正常系が完全に現行のまま**に
  なった。追加のgit起動もゼロで、受け入れ条件「既存の使い方が従来どおり動作する」が
  コードの構造として保証される
- pathspec の解釈（ディレクトリ指定・末尾スラッシュ・相対/絶対表記）を**すべて git に委ねられた**。
  自前でパス正規化を書くと、`plans\...`（Windows形式区切り）や `./plans/...` の扱いを漏らしやすい
- `git add` がpathspecを先に検証し、1件でも不一致なら何もステージせずに終了する（フェーズ2で実測）
  という性質のおかげで、失敗時のリカバリが単純になった（部分適用のロールバックを考えなくてよい）
- issue の再現ケース（`git rm` 先行 → 同じパスを再指定）が rc=128 から**SKIP通知つきの成功**に
  変わった。10ケース29アサーションすべて通過（passed=29 failures=0）

## ダメだったこと

- **当初の実装（常に分類）は現行動作からの機能後退だった。** 分類をパス文字列の一致で行うと、
  ディレクトリごと削除された `reports/` をディレクトリ指定で渡すケースが UNKNOWN になる
  （`git ls-files -- reports` が返すのは `reports/xxx.html` であって `reports` ではないため）。
  検証ケース8を足していなければ、そのままコミットしていた。
  **「新しい判定ロジックを挟むときは、判定単位（パス文字列 対 pathspec）が元の実装と同じかを疑う」**
  という教訓
- 存在判定に `-z` を付けたところ、コマンド置換がNULバイトを扱えず
  `warning: command substitution: ignored null byte in input` が標準エラーへ出た。
  「1件でもマッチしたか」しか見ないので `-z` は不要だった（フェーズ2で `-z` が必要だったのは、
  出力そのものをパスとして使っていたため。用途が違えば必要な指定も違う）
- 計画のアサーションを書く際、`grep -E 'overall-plan|【調査】'` が
  `worklog/20260819_overall-plan_...` にもマッチして偽の失敗を3件出した。テスト側のパターンは
  `^plans/` のように**位置を固定する**こと

## 次の一歩

- flow-id 3-7: 実装をcommitし、リモートへ反映してレビュー依頼を行う
- flow-id 4-1以降: `.claude/docs/spec/create-commit.md` の新規作成（エラー文が参照している）と
  DDR 0029、commit SKILL / git-workflow への注記

---
