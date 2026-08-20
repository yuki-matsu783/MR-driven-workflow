---
title: worklog 20260820 設計反映（push検知hookの環境差をspecへ併記） push10
type: log
description: issue #47 フェーズ4の設計反映（spec への環境差の併記）と、その途中で判明した main のDDR番号衝突の解消の試行錯誤ログ
tags: [log, spec, hook, issue-47]
keywords: [設計反映, spec, push検知, 環境差, 差し込み位置, DDR番号, 繰り下げ, resolve-conflict, 監視モード, worklog]
---

# worklog: フェーズ4（設計反映）

## 試したこと

### flow-id 4-6（設計反映の実施）

`.claude/docs/spec/issue-mr-workflow.md` の「誤検知（pushしていないのに発火する）」項へ、
issue #47 の観測を環境差として併記した。**既存記述を1文字も変えない**ことが要件だったため、
Edit（部分置換）ではなく**前後を `sed -n` で切り出して差し込む**方式を採った。

```bash
{ sed -n '1,1060p' "$F"; cat "$SP/spec-insert.md"; sed -n '1061,$p' "$F"; } > "$SP/spec.new"
```

差し込む段落は Write ツールで別ファイルへ書き出した（`.claude/rules/shell-script-style.md`
「`awk`/`sed` の置換文字列で `\r` を含むシェルコードを生成しない」の対処と同じ形）。

## うまくいったこと

- **「既存記述を変えていない」を目視ではなく機械的に確かめられた。** 検証コマンドを
  `git diff | grep '^-' | grep -v '^---'` に置いたことで、issue #23 の記録と過去のchangelogの
  両方が無傷であることを**1回の判定**で担保できた。結果は `38 insertions(+)`・削除0。
  - 目視だと「変えていないつもり」の確認にしかならない。差分の削除側という**機械が持っている
    情報**へ判定を寄せたのが効いた。
- **差し込み位置の判断が、計画の時点で固定されていた。** 既存項の末尾が「回避策」と
  `git-workflow.md` への誘導という**節全体にかかる地の文**で終わっているため、
  その手前へ入れると係り先が壊れる。計画に「項の末尾（次の箇条書きの直前）へ置く」と
  書いてあったので、実施時に迷わなかった。

### mainのマージ（DDR番号 0059 → 0061）

flow-id 4-5 でPRを取得したところ `mergeable_state: dirty` だった。`main` が2コミット進み、
**DDR 0059 と 0060 が同時に入っていた**ため、こちらの 0059 が衝突していた。

- `check-base-conflicts.sh` は `hasTextualConflict`（`.claude/docs/README.md`）と
  `hasDuplicateDdrNumber`（0059）の**両方**を真で返した。類型A（DDR番号の衝突）と
  類型C（一覧末尾への追記）で、いずれも**監視モードで承認を待たず自動解消してよい**範囲。
- 空き番号は 0061（main が 0059・0060 を使用済み）。

## ダメだったこと

- **flow-id 4-5 で `pull_request_read` を呼ぶまで、コンフリクトに気づいていなかった。**
  追従監視は購読済みだが、webhookはマージ可否の遷移を取りこぼすことがある
  （`SKILL.md`「実行環境別の手段」がまさにこれを警告している）。**各pushの直後に
  `check-base-conflicts.sh` を1回実行する**という決まりのほうが確実で、今回はそれを
  飛ばしていた（4-2 のpush直後に実行していれば、設計反映を始める前に気づけた）。

## 決まったこと

- **DDR 0059 は 0061 へ繰り下げる。** main 側の番号を正とする規則どおり
  （`resolve-conflict/SKILL.md` 類型A）。
- 改番の対象はファイル名だけではない。frontmatterの `title`・本文冒頭の見出し・
  `.claude/docs/README.md` のリンク（**ファイル名とテキストの両方**）・他ファイルからの
  `grep` 参照をすべて確認する。

## 次の一歩

- flow-id 4-6（AIアセット反映）。設計反映のラウンドを終えてから着手する。
- flow-id 5-1 で `check-base-conflicts.sh` をもう一度通す（main はまた進みうる）。
