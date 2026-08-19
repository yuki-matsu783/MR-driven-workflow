---
title: issue #60 create-commit.sh が削除済みファイルを引数に取れない（全体作業計画）
type: plan
description: commitスキルのラッパーが削除済みパスを受け取れるようにし、採用方針をspec/DDR/SKILLへ記録するまでの全体計画
tags: [issue-60, create-commit, commit-skill, workflow]
keywords: [create-commit, git add -A, 削除済みファイル, pathspec, flow-id 5-1, commitスキル, DDR, spec]
---

# issue #60 全体作業計画

- issue: [#60 create-commit.sh が削除済みファイルを引数に取れない](https://github.com/yuki-matsu783/MR-driven-workflow/issues/60)
- ブランチ: `feature-60-accept-deleted-file-paths`（base: `main`）
- PR: [#62](https://github.com/yuki-matsu783/MR-driven-workflow/pull/62)（Draft）

## Context（なぜやるか）

`.claude/scripts/src/create-commit.sh` は `git add -- "${files[@]}"` を実行するため、削除済みの
パスを渡すと `fatal: pathspec '...' did not match any files`（終了コード128）でコミットに到達
しない。commitスキルはこのリポジトリの唯一の正規コミット経路であり、直接のコミット実行は
PreToolUse hookでブロックされているため、**削除を含むコミットだけが正規経路で完結しない**状態に
なっている。

flow-id 5-1（`plans/` `worklog/` `reports/` の削除・`HANDOFF.md` のリセット）は全タスクが必ず通る
工程であり、実際に issue #36・#55 の 5-1 で「先に削除をステージし、削除以外だけをラッパーへ渡す」
2段構えの回避策をその場で編み出している。この回避策は `.claude/skills/commit/SKILL.md` にも
`.claude/docs/spec/` にも記載が無く、**実行して失敗して初めて気づく**ため再発率が高い。

本タスクのゴールは、削除済みパスをそのまま渡してコミットできるようにし、かつ採用方針を
「commitスキルの絶対ルール（`git add .` / `git add -A` は使わない）と矛盾して見えない形」で
記録に残すこと。

## 方針（現時点の第一候補）

`git add -A -- "${files[@]}"` を採用する。`-A` は**pathspecと併用した場合そのパス配下に限定される**
ため、無制限のステージングにはならない。ラッパーは引き続き `--` 以降のファイル1件以上を必須とし、
`--amend` / `--no-verify` / パス指定なしのステージングは持たない。

`-A` のパス限定利用が commitスキルの絶対ルールと矛盾して見えないよう、スクリプト内コメント・
`.claude/docs/spec/`・`.claude/skills/commit/SKILL.md` の三箇所で「パス限定であること」「無制限
ステージングは引き続き不可能であること」を明示する。

代替案（渡されたパスの存在有無で `git add` と `git rm` に振り分ける）は実装が複雑になるため、
フェーズ2の実機検証で `-A` に問題が無いことを確認したうえで却下する想定。

## フェーズ構成

### フェーズ2（調査）— 軽量

`plans/【調査】git-addの削除済みパス挙動.md` を作成し、一時リポジトリ（scratchpad配下）で以下を
実機検証する。結果は worklog と `reports/` のHTMLへまとめる。

1. 現行実装の失敗再現: 削除済みパスを `git add -- <path>` に渡したときの終了コードとメッセージ
   （git 2.39.2.windows.1 / git bash）
2. `git add -A -- <path1> <path2>` で「削除済み＋通常変更＋新規追加」の混在を1回でステージできるか
3. `-A` のスコープ: pathspecに含めていない別ディレクトリの変更が巻き込まれないこと
4. 引数にディレクトリを渡した場合の差分（`git add -- dir/` と `git add -A -- dir/` の違い）
5. **`.` や `:/` のような「実質的に全体を指す pathspec」を渡された場合の挙動**
   （`-A` によって従来より巻き込み範囲が広がるなら、これらを拒否するガードを入れるか判断する）
6. 代替案（存在有無で `git add` / `git rm` に振り分け）の実装量と失敗モードの比較

### フェーズ3（実装）

`plans/【実装】create-commit.shの削除済みパス対応.md` を作成し、以下を行う。

- `.claude/scripts/src/create-commit.sh` の `git add -- "${files[@]}"` を `git add -A -- "${files[@]}"`
  に変更する（フェーズ2の結果次第で pathspec ガードを追加）
- ファイル冒頭コメントの「`git add .`/`-A` 相当のオプションは持たない」の記述を、**パス限定の `-A` を
  内部で使うこと・それでも無制限ステージングは構造的に不可能であること**が読み取れる文面へ更新する
- `bash -n .claude/scripts/src/create-commit.sh` で構文チェック
- 手動での実機確認（削除済み＋通常変更の混在コミット、従来どおりの通常変更のみのコミット）

回帰テストスクリプトは今回作成しない（ユーザー判断）。

### フェーズ4（反映）

**設計反映**（`plans/【設計反映】create-commit仕様の記録.md`）

- `.claude/docs/spec/create-commit.md` を新規作成する（仕様・引数・`-A` のパス限定採用理由・
  従来必要だった2段構えの回避策が不要になったこと・hook回避という存在理由）
- `.claude/docs/ddr/0029-<タイトル>.md` を新規作成し、`-A` のパス限定利用の採用と代替案（存在有無で
  振り分け／回避策の明文化のみ）の却下理由を記録する
- `.claude/docs/README.md` のDDR一覧・spec一覧へ追記する

**AIアセット反映**（`plans/【AIアセット反映】commitスキルの記述整合.md`）

- `.claude/skills/commit/SKILL.md` の絶対ルール「`git add .` / `git add -A` は使わない」に、
  ラッパー内部のパス限定 `-A` は例外である旨の注記を添える（呼び出し側の禁止は維持）
- `.claude/rules/git-workflow.md` の「コミット運用」節に、削除済みファイルもそのまま渡せる旨を追記する
- 削除を含むコミットで2段構えの回避策が不要になったことを、読み手が辿れる形にする

### フェーズ5（クローズ）

`plans/` `worklog/` `reports/` を削除し `HANDOFF.md` をリセット。**この片付けコミット自体が、
今回の修正の実地検証になる**（削除済みファイルをそのままラッパーへ渡してコミットできるか）。

## 検証方法

| 受け入れ条件 | 検証 |
|---|---|
| 削除＋通常変更の混在を1回の呼び出しでコミットできる | 一時リポジトリでの実機確認＋flow-id 5-1の片付けコミット本番 |
| パス指定なしの無制限ステージングが構造的に不可能 | `--` 以降1件以上必須のバリデーション（既存）＋ フェーズ2-5の判断に応じたガード |
| 既存の使い方が従来どおり動作する | 本ブランチの各フェーズのコミット（通常変更のみ）がすべてラッパー経由で成功すること |
| `bash -n` が通る | フェーズ3で実行 |
| 採用方針と理由が記録されている | spec新規＋DDR 0029＋SKILL.md/git-workflow.md注記 |

## 守るべき条件・触ってはいけない範囲

- ラッパーに `--amend` / `--no-verify` / パス指定なしのステージング手段を追加しない
- 呼び出し側（commitスキル利用者）に対する「必ず個別ファイル指定」のルールは緩めない
- `.claude/hooks/block-direct-git-commit.sh` の仕組みには手を入れない
- コミットメッセージ・PR本文・スクリプトのコメントで `git` と `commit`／`git` と `push` を
  半角スペース区切りで連続させない（hookの誤検知対策）
