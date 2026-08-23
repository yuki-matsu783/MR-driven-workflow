---
title: 20260823_misty-drifting-lantern_選別スクリプトとドキュメント反映_push1
type: log
description: 敵対的レビュー投稿件数選別スクリプトの実装過程の詳細ログ（issue #182）
tags: [adversarial-review, worklog]
keywords: [select-adversarial-findings, jq, reduce, index, 選別]
---

# worklog: 選別スクリプトとドキュメント反映（push1）

## やったこと

1. `.claude/scripts/src/select-adversarial-findings.sh` を実装。jqフィルタを1つの文字列
   （`SELECT_FILTER`）にまとめ、`reduce` で層（major→minor）を逐次処理する形にした。
2. 実装直後に手動でいくつかの境界ケースを `jq` へ直接通して検証してから、正式な単体テスト
   （`test_select_adversarial_findings.sh`）を書いた。

## ハマった点: `index(.field)` のパイプ内での挙動

「severityがblocker/major/minor以外のfindingを弾く」ために、最初は次のように書いた。

```jq
$all | map(select(($known | index(.severity)) == null))
```

これは `jq: error: Cannot index array with string "severity"` で落ちた。原因は
`$known | index(.severity)` の `.severity` が、`select()` の入力（各finding要素）ではなく
**`$known`（パイプの左辺である配列）** に対して評価されるため。`.` はパイプが進むたびに
更新されるので、`$known | ...` の右辺では `.` は `$known` を指す。

対策として、`.severity` を先に変数へ束縛してから `$known` をパイプする形へ直した。

```jq
$all | map(select(.severity as $sv | ($known | index($sv)) == null))
```

これは他のjqを書く場面でも踏みうる罠なので、`.claude/rules/shell-script-style.md` へ
反映する（フェーズ4〈反映〉、AIアセット反映）。

## 検証結果

- `bash -n` 2件とも構文OK。
- `test_select_adversarial_findings.sh`: `passed=16 failures=0`
  （0件／ちょうど10件／層跨ぎ／blocker単独20件超／ハードシーリング跨ぎの層内切り捨て順序／
  nit混入時の防御、の6カテゴリ16アサーション）
- 既存テスト `test_adversarial_review_count.sh`（22件）・`test_generate_ddr_list.sh`（52件）・
  `test_check_base_conflicts.sh`（31件）はいずれも回帰無し。
