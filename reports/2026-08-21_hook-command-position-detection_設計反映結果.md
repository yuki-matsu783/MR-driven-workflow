---
title: 設計反映結果: コマンド位置判定のspecとDDR
type: report
description: issue #53の実装内容を.claude/docs/spec/と.claude/docs/ddr/へ反映した結果
tags: [report, 設計反映, hooks, issue-53]
keywords: [command-position, spec, DDR, i0053-01, i0000-09, note, generate-ddr-list, point-in-time]
---

# 設計反映結果: コマンド位置判定のspecとDDR

- issue: [#53](https://github.com/yuki-matsu783/MR-driven-workflow/issues/53)
- 個別反映計画: `plans/【設計反映】コマンド位置判定のspecとDDRを整備する.md`

## 反映した内容

### 新規作成

| ファイル | 内容 |
|---|---|
| `.claude/docs/spec/command-position.md` | 判定アルゴリズム（事前チェック → 正規化 → コマンド位置トークン走査 → 保守的フォールバック）・公開関数のインターフェース・呼び出し側hookの責務（3段ガード）・既知の制約・性能・未決定事項 |
| `.claude/docs/ddr/i0053-01-hookの検知は正規化とコマンド位置判定にし読めない実行体は部分一致へ縮退させる.md` | 線引きの決定と却下案6件 |

**`i0053-02` は作らなかった。** 計画では「失敗の向きの決め方」を分けるか判断するとしていたが、
`i0053-01` の「なぜ『読めないものはブロック』なのか（失敗の向き）」節に収まった。分けると、
同じ判断を2箇所から読むことになる。

### 既存specの更新

| ファイル | 何をしたか |
|---|---|
| `.claude/docs/spec/issue-mr-workflow.md` | 「誤検知（pushしていないのに発火する）」節へ**追記した**（本文は1文字も変更していない）。issue #23 / #47 の観測はpoint-in-timeの記録として残し、issue #53 での変化を表で足した。「制約は『対応工数レポート』節と共通」へも1文追記 |
| `.claude/docs/spec/create-commit.md` | 「部分一致でブロックする」を現状へ更新。**ラッパーが通る理由が変わった**ことを明記（「該当語を含まないから」ではなく「コマンド位置に立つ実行体が `bash` だから」） |
| `.claude/docs/spec/check-base-conflicts.md` | 誤発火への言及を現状へ更新。**判断の結論は変えていない**（自動実行しない主たる理由は `git fetch` のコストで、誤発火は副次的な理由だったため） |

### DDR

| 識別子 | 何をしたか |
|---|---|
| `i0053-01` | 新規作成 |
| `i0000-09` | **本文は不変。** frontmatterへ `note` を1行追加した。`status` は変えていない（コミットをスキル経由へ強制するという決定自体は有効なため） |
| `i0023-01` / `i0046-01` / `i0077-03` / `i0088-01` | **何もしていない。** 当時の部分一致に言及しているが、それぞれの決定自体は今回の変更で無効にならない。一覧を開く前に知っておくべき情報でもないため `note` も足していない |

`bash .claude/scripts/src/generate-ddr-list.sh` を実行し、`.claude/docs/README.md` の差分
（2行: `i0000-09` への注記付与と `i0053-01` の追加、計64件）を同じコミットへ含めた。

## 反映対象の洗い出しについて

`grep -rn '部分一致' --include='*.md' .` を起点にした。**ヒット件数の約半分が
`.claude/skills/apply-mr-workflow-to-project/assets/.claude/` 配下**で、これは
`sync-assets.sh` が生成する配布用ミラーである。

- `.gitignore` の9行目 `/.claude/skills/apply-mr-workflow-to-project/assets/` で除外されており、
  `git ls-files` にも出ない。
- `diff -q` で本体と比較したところ差分は無く、既に同期済みだった。
- **したがって手で二重反映する必要は無い**（対象一覧から除外した）。

同じ洗い出しを次に行う人が同じ確認を繰り返さないよう、この事実を個別反映計画にも書いた。

## やらなかったこと

- **DDR本文の書き換え。** `i0000-09` を含め、一度マージしたDDRの本文は変更していない。
- **過去changelogエントリの書き換え。** `issue-mr-workflow.md` の該当節は追記のみ。
- **`post-issue-create-notice.sh` への判定適用。** issue #53 が名指ししておらずスコープ外。
  `command-position.md` の「未決定事項・懸念点」へ、非対称であることを明記した。
- **`.claude/VERSION` の更新。** 提案のみで、決定は人間に委ねる（下記）。

## `.claude/VERSION` の提案（決定は人間）

**PATCH を1つ上げる（0.1.1 → 0.1.2）ことを提案する。** 根拠は次のとおり。

- 配布物へ新規ファイル（`CommandPosition.sh`・`command-position.md`・単体テスト）が加わるが、
  **公開インターフェース（hookの入出力・終了コードの意味）は変わっていない**。
- 利用側から見た挙動の変化は「誤検知が減る」方向のみで、破壊的変更ではない。
- 新しい依存（bash 4.3以上）が増えるが、**満たさない環境では従来の部分一致へ縮退する**ため、
  動かなくなる環境は無い。

MINOR を推す見方もありうる（機能追加とみなす場合）。**この判断はAIでは決めない。**

## 確認したこと

| 確認項目 | 結果 |
|---|---|
| 新規specがfrontmatter規約に沿う | OK（`type: spec`、6キー） |
| `generate-ddr-list.sh` 再実行後に差分が残らない | OK（再実行で `changed:false`） |
| hookのコメントが指す `.claude/docs/spec/command-position.md` が実在する | OK |
| `extract-frontmatter.sh` が成功し新規ファイルがインデックスへ載る | OK |
