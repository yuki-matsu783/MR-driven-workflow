# 全体作業計画: 敵対的レビューの投稿件数選別を層単位ルールでスクリプト化する（issue #182）

## 前提（合意状況）

issue #182 で規則（blocker無制限・層追加しきい値10件・ハードシーリング20件）は既に確定して
いる。本計画はその実装方針を示すもので、規則そのものの是非は議論の対象にしない。

## この計画で何をするか

`adversarial-review` スキル手順6の投稿件数の絞り込み（現行: 固定10件・重大度順に切る、
タイブレーク未定義）を、決定的な選別スクリプトへ置き換える。同じfindingsからは必ず同じ
投稿集合が得られるようにし、AIエージェントの裁量を無くす。

## 変更対象

- `.claude/scripts/src/select-adversarial-findings.sh`（新規）— 選別ロジック本体
- `.claude/scripts/test/test_select_adversarial_findings.sh`（新規）— 単体テスト
- `.claude/skills/adversarial-review/SKILL.md` 手順6 — スクリプト呼び出しへ置き換え
- `.claude/docs/spec/adversarial-review.md` — 「投稿件数の選別」節の新設・設定項目表の更新
- `.claude/docs/ddr/i0182-01-...md`（新規）— 設計判断の変更を記録するDDR
- `.claude/docs/README.md` — DDR一覧の再生成

## 方針

- **確度×重大度による1次振り分け（投稿候補／報告）は変更しない。** 選別スクリプトが受け取るのは
  「投稿候補」に絞られたfindingsのみとする。
- 選別規則は issue #182 の期待する動作をそのまま実装する（blocker無制限・層単位追加・
  層追加しきい値10・ハードシーリング20・層内切り捨ては確度降順→パス昇順→行番号昇順）。
- jqの起動は1回に集約する（`.claude/rules/shell-script-style.md`「外部プロセス起動のコスト」）。
  層ごとの逐次処理は `reduce` で1つのjqプログラム内に書く。
- findingsはファイル経由でjqへ渡す（引数長上限を避けるため。同ルール「JSON操作」）。
- 既存の `adversarial-review-count.sh`（実施回数カウンタ）と同じ設計方針（固定値・緩める口を
  用意しない・純粋関数を`source`で単体テストできるガード）を踏襲する。

## フェーズ2〈調査〉

**実施しない。** issue #182 本文が選別規則・境界ケース・出力形式まで具体的に確定しており、
実装方針を決めるための追加調査は不要と判断した。既存の `adversarial-review-count.sh` /
`collect-review-points.sh` を読むことで、このリポジトリのシェルスクリプト設計方針
（純粋関数・`source`ガード・`passed=N failures=N`規約）は十分に把握できた。

## フェーズ4〈反映〉

- **設計反映**: 本issueの変更内容そのものが `.claude/docs/spec/adversarial-review.md` と
  新設DDRへの反映を兼ねるため、フェーズ3の作業に含めて行う（分離しない）。
- **AIアセット反映**: 実装中に見つかったjqの落とし穴（`arr | index(.field)` のように
  パイプの右辺で `.` を参照すると、フィルタ内の `.` がパイプ元の値に置き換わり、
  意図した要素の `.field` を参照できない）を、`.claude/rules/shell-script-style.md` の
  JSON操作節へ追記する。既存の「JSON操作」節の書き方（実際に踏んだ失敗として記録する）に揃える。
- 実装コード・テストコードの修正を伴う「実装反映」の対象は、現時点では見込んでいない
  （フェーズ3のレビュー往復で解消しきれなかった不具合が出た場合にのみ発生する）。

## やらないこと（スコープ外）

- 確度×重大度による1次振り分け表そのものの変更（issue #182の対象外。DDR i0182-01「却下した案」参照）
- 実施回数の上限（3回／フェーズ）の変更
- GitLab側の投稿経路（`gitlab_add_mr_inline_comments`等）の変更（選別は投稿の前段であり、
  投稿インターフェイス自体には手を入れない）

## 検証

- `bash -n` で新規スクリプト・テストの構文確認
- `bash .claude/scripts/test/test_select_adversarial_findings.sh` が `passed=N failures=0` で終わる
  （0件／ちょうど10件／層跨ぎ／blocker単独20件超／ハードシーリング跨ぎの層内切り捨て順序／
  nit混入時の防御、を含む）
- 既存の関連テスト（`test_adversarial_review_count.sh` / `test_generate_ddr_list.sh` /
  `test_check_base_conflicts.sh`）が既存どおり通ることを確認する（回帰が無いことの確認）
- `bash .claude/scripts/src/generate-ddr-list.sh` を実行し、DDR一覧に i0182-01 が追加されている

## issueの受け入れ条件との対応

| 受け入れ条件 | 対応 |
|---|---|
| 選別スクリプトが規則1〜4を実装し、`bash -n`と単体テストが通る | `select-adversarial-findings.sh` + `test_select_adversarial_findings.sh` |
| 境界ケース（0件／ちょうど10件／層跨ぎ／blocker単独20件超／ハードシーリング跨ぎの層内切り捨て順序） | 単体テストの各ケースとして実装 |
| `adversarial-review/SKILL.md` 手順6がスクリプト呼び出しへ置き換わっている | 手順6を1次振り分け＋スクリプト呼び出しへ書き換え |
| `.claude/docs/spec/adversarial-review.md` の選別節・設定項目表が新規則と一致 | 「投稿件数の選別」節を新設、設定項目表を更新 |
| 設計判断の変更を記録したDDRが追加され、一覧が再生成されている | DDR i0182-01 を追加、`generate-ddr-list.sh` 実行 |
