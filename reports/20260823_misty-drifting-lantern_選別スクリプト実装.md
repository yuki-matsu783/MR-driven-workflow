# 実装結果: 敵対的レビュー投稿件数選別スクリプト（issue #182）

## サマリ（結論の一覧）

- `.claude/scripts/src/select-adversarial-findings.sh` を新規実装し、issue #182 の選別規則
  （blocker無制限・層追加しきい値10件・ハードシーリング20件・層内切り捨ては確度降順→
  パス昇順→行番号昇順）をすべて満たすことを単体テストで確認した。
- `adversarial-review/SKILL.md` 手順6・`.claude/docs/spec/adversarial-review.md`・
  新設DDR（i0182-01）を更新し、issue #182 の受け入れ条件を満たした。
- 実装中に見つけたjqの落とし穴（パイプ右辺での `.` 参照）を `.claude/rules/shell-script-style.md`
  へ反映した（フェーズ4〈AIアセット反映〉）。

## 実施した内容と結果

### 選別スクリプトの実装

`select-adversarial-findings.sh` は、findings JSONファイルを受け取り、単一のjq呼び出し
（`SELECT_FILTER`という文字列にまとめた1プログラム）で選別する。層ごとの逐次処理は
`reduce` で表現し、jqの起動回数を1回に固定した（`.claude/rules/shell-script-style.md`
「外部プロセス起動のコスト」に沿う）。

出力は `{"posted":{"findings":[...]},"reported":{"findings":[...]}}`。`posted.findings` は
そのまま `add_mr_inline_comments`（Provider.sh）へ渡せる形にした。

### 単体テスト（`test_select_adversarial_findings.sh`）

16アサーション、`passed=16 failures=0`。issue #182 が明示する境界ケースを次のように検証した。

| ケース | 入力 | 期待する結果 | 検証内容 |
|---|---|---|---|
| 0件 | findings無し | posted=0 / reported=0 | 空配列でも例外にならない |
| ちょうど10件 | major 10件のみ | posted=10 / reported=0 | 層追加のしきい値ちょうどで層全体が入る |
| 層跨ぎ | blocker1 + major13 + minor5 | posted=14（blocker+major） / reported=5（minor全件） | 累計14≥10でminorが追加されない |
| blocker単独20件超 | blocker25 + major5 | posted=25（blocker全件） / reported=5（major全件） | blockerが上限の対象外であること |
| ハードシーリング跨ぎ | major: confidence=high 12件 + confidence=medium 13件 | posted=20 / reported=5（medium末尾5件） | 層内切り捨ての順序（確度降順→パス昇順） |
| nit混入（防御） | blocker1 + nit3 | posted=1 / reported=3 | 上流で本来除外されるはずのseverityが予算を消費しない |

既存テストへの回帰確認も行った。`test_adversarial_review_count.sh`（22件）・
`test_generate_ddr_list.sh`（52件）・`test_check_base_conflicts.sh`（31件）はいずれも
`failures=0` のまま変化なし。

### ドキュメント反映

- `adversarial-review/SKILL.md` 手順6: 確度×重大度による1次振り分け（表）はそのまま残し、
  「1回あたりの投稿上限は10件」という記述をスクリプト呼び出しと規則1〜4の箇条書きへ置き換えた。
- `.claude/docs/spec/adversarial-review.md`: 「投稿件数の選別」節を新設し、旧「投稿／報告の
  振り分け」節から件数選別の記述を分離した。設定項目表・影響範囲表・末尾の追記セクションも更新。
- `.claude/docs/ddr/i0182-01-...md`: 決定した規則と、却下した3案（タイブレーク規則の追記のみ、
  blockerも予算プールに含める設計、閾値の環境変数化）を記録。
- `bash .claude/scripts/src/generate-ddr-list.sh` を実行し、`.claude/docs/README.md` の
  DDR一覧（78件）へ i0182-01 を反映した。

## 確かめられなかったこと

- 実際のMRへ本スクリプトの出力を `add_mr_inline_comments` で投稿する経路の実機確認
  （本issueのスコープは選別ロジックであり、投稿インターフェイス自体は変更していないため、
  既存の実機確認結果（issue #77・#121・#127）を踏襲する前提とした）。

## 設計への反映

`.claude/docs/spec/adversarial-review.md`・DDR i0182-01 への反映は「実施した内容と結果」節に
記載のとおり完了している。次のissueへ持ち越す反映事項は無い。

## 想定と異なった点

jqの `index()` を `select()` 内で使う際、パイプの右辺で `.` を参照すると外側の値に束縛が
移ることに気づかず、実装当初のフィルタが実行時エラーになった（詳細:
`worklog/20260823_misty-drifting-lantern_選別スクリプトとドキュメント反映_push1.md`）。
`.severity` を変数へ先に束縛する形へ直して解決し、同じ落とし穴を
`.claude/rules/shell-script-style.md` へ反映した。
