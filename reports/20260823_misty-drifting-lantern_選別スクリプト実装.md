---
title: 実装結果: 敵対的レビュー投稿件数選別スクリプト
type: report
description: 敵対的レビューの投稿件数選別スクリプトの実装・単体テスト・ドキュメント反映の結果と、フェーズ3の敵対的レビュー実施・対応の記録
tags: [adversarial-review, review, report]
keywords: [敵対的レビュー, 投稿件数, 選別, 層単位, blocker, ハードシーリング, select-adversarial-findings, 単体テスト]
---

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

出力は `{"posted":{"findings":[...]},"reported":{"findings":[...]}}`。`.posted`
（オブジェクト全体。`{"findings":[...]}`の形）をそのまま `add_mr_inline_comments`（Provider.sh）へ
渡せる形にした（`.posted.findings` という配列単体を渡すと失敗する。下記「敵対的レビュー実施と
対応」参照）。

### 単体テスト（`test_select_adversarial_findings.sh`）

34アサーション、`passed=34 failures=0`。issue #182 が明示する境界ケースに加え、下記の敵対的
レビューで指摘された境界ケース・入力検証も含む。

| ケース | 入力 | 期待する結果 | 検証内容 |
|---|---|---|---|
| 0件 | findings無し | posted=0 / reported=0 | 空配列でも例外にならない |
| ちょうど10件 | major 10件のみ | posted=10 / reported=0 | 層追加のしきい値ちょうどで層全体が入る |
| 層跨ぎ | blocker1 + major13 + minor5 | posted=14（blocker+major） / reported=5（minor全件） | 累計14≥10でminorが追加されない |
| blocker単独20件超 | blocker25 + major5 | posted=25（blocker全件） / reported=5（major全件） | blockerが上限の対象外であること |
| ハードシーリング跨ぎ | major: confidence=high 12件 + confidence=medium 13件（パス接頭辞h/m） | posted=20 / reported=5（medium末尾5件） | 層内切り捨ての順序（確度降順→パス昇順） |
| 確度優先のタイブレーク | major: high 12件（パス接頭辞z）+ medium 13件（パス接頭辞a） | posted=20 / reported=5 | パスの辞書順ではなく確度が優先されること（z側が残りa側が切られる） |
| 行番号タイブレーク | 同一パス・confidence=high 25件をline降順で入力 | posted=20（line1〜20） / reported=5（line21〜25） | sort_keyの第3要素（行番号）が実際に効くこと |
| minorがpostedへ入る経路 | major3 + minor4 | posted=7 / reported=0 | major→minorの2周目でpostedへ足す分岐そのもの |
| ちょうど20件 | major 20件のみ | posted=20 / reported=0 | ハードシーリングの境界（層全体が入る） |
| blocker5+major15=20件 | blocker5 + major15 | posted=20 / reported=0 | blockerがハードシーリングの枠を消費すること |
| blocker9+major15 | blocker9 + major15 | posted=20（blocker9+major11） / reported=4 | 上記の枠消費により下位層が層内で切られる境界 |
| nit混入（防御） | blocker1 + nit3 | posted=1 / reported=3 | 上流で本来除外されるはずのseverityが予算を消費しない |
| main入力検証 | 存在しないファイル／空ファイル／findingsキー無し／トップレベル配列／有効な入力 | 前4件は終了コード1、最後は0 | 無言でゼロ件を返す壊れ方を防ぐ検証 |

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

## 敵対的レビュー実施と対応（フェーズ3・1回目）

`adversarial-reviewer` サブエージェントへ diff全体（origin/main...HEAD）を渡し、独立した
レビューを実施した（実施回数: フェーズ3の1/3回）。13件のfindingsが返り、確認のうえ次のとおり
対応した（このセッションは非対話モードのため、投稿の可否確認は「投稿する」を既定とし、確度×
重大度による1次振り分けを経て投稿・報告を選別している。投稿自体は本レポートの対象外で、
`comments`/`reply` ループが担当する）。

| 重大度 | 指摘 | 対応 |
|---|---|---|
| major | `.posted.findings`（配列単体）を `add_mr_inline_comments` へ渡す設計・記述は、受け取り側が `.findings` キーを直下に持つオブジェクトを要求するため失敗する | **修正**。`.posted`（オブジェクト全体）を渡す設計へ、SKILL.md・spec・DDR・レポート（本ファイル）・個別計画・全体計画のHTMLの記述を統一した |
| major | 選別で漏れたfindingsが `reported.findings` へ集約されるという規則4の記述が、1次振り分けの「報告」分（そもそもスクリプトへ渡していない）まで含むように読める | **修正**。spec・SKILL.mdの文言を「この選別で漏れた投稿候補のみが reported.findings に入り、1次振り分けの「報告」は呼び出し側で別途合わせて報告する」と明確化した |
| major | blockerの件数がハードシーリング（20件）の枠を消費するかどうかが規則の文面から一意に決まらない | **修正**。spec・DDR・スクリプトのコメントへ「blockerは打ち切り判定の対象外だが、消費した枠の対象外ではない」ことを明記し、境界値テスト（blocker5+major15=20件、blocker9+major15→20件+reported4件）を追加した |
| major | 空ファイル・findingsキー無し・トップレベル配列を渡しても`main`が無言で成功してしまう | **修正**。`main`に検証を追加し、5パターンの単体テストを追加した |
| major | ハードシーリング跨ぎのテストが、確度でソートしてもパスでソートしても同じ結果になるフィクスチャで、確度優先のタイブレークを検証できていない | **修正**。高確度側のパス接頭辞を辞書順で後ろになる文字にした「確度優先のタイブレーク」テストを追加し、常に0を返す空振りアサーションを削除した |
| minor | 行番号昇順のタイブレーク・minorがpostedへ入る経路・累計ちょうど20件の境界が未検証 | **修正**。3種のテストを追加した（上表参照） |
| minor | 新規の `plans/*.md` `reports/*.md` にYAML frontmatterが無い | **修正**。本ファイルを含む3ファイルへ `title`/`type`/`description`/`tags`/`keywords` を追記した |
| minor | spec末尾の追記セクションが「設定項目」配下に置かれ、既存3件の追記（「影響範囲」配下）と親が食い違う。変更ファイル表にも2ファイル漏れ | **修正**。「影響範囲」配下へ移動し、変更ファイル表に `shell-script-style.md`・`docs/README.md` を追加した |
| minor | 全体作業計画のmd/HTMLで「変更対象」の内容が食い違う（`shell-script-style.md`がHTMLにのみ存在）。個別作業計画でmdの`### 既存の記述を置き換える場合`（h3）がHTMLでは`<h3>`ではなく`.box`ラベルになっている | **修正**。mdへ不足行を追加し、HTML側は`<h3>`を追加してmd/HTML間の見出し構造を揃えた |
| minor | 選別規則1〜4がSKILL.md・spec・DDR・スクリプトコメントの4箇所に全文で複製されている | **一部対応**。SKILL.mdの規則本文を削除し、specを正として参照する形へ縮めた（spec・DDR・スクリプトコメントは、意思決定記録・実装コメントという別の役割を持つため複製ではなく残した） |
| minor | DDR i0182-01が`shell-script-style.md`に存在しない記述（「決定的な処理は関数・スクリプトへ切り出す」）を根拠として引用している | **修正**。実在する本機構内の前例（`adversarial-review-count.sh`・`collect-review-points.sh`）を指す書き方へ改めた |
| minor | 既存DDR i0077-03の決定6「1回あたりの投稿上限（10件）」がissue #182で無効化されたのに追随していない | **修正**。i0077-03のfrontmatterへ`note`を追加し、`generate-ddr-list.sh`でDDR一覧を再生成した |
| minor | `HANDOFF.md`で完了済みのflow-id 1-1・1-6が`[]`のまま残っている | **修正**。`update-handoff-progress.sh mark-done 1-1 1-6`で反映した |

対応後、`test_select_adversarial_findings.sh`（34アサーション）・`bash -n`構文チェックを再実行し、
`failures=0`であることを確認した。

## 確かめられなかったこと

- 実際のMRへ本スクリプトの出力を `add_mr_inline_comments` で投稿する経路の実機確認
  （本issueのスコープは選別ロジックであり、投稿インターフェイス自体は変更していないため、
  既存の実機確認結果（issue #77・#121・#127）を踏襲する前提とした）。**上記の敵対的レビューで
  この経路の入力形式の不整合が実際に見つかったため、コードレベルでの突き合わせ（受け取り側の
  jqフィルタを読み、`.posted`を渡せば動作し`.posted.findings`では失敗することを確認）は行ったが、
  実際にGitHub/GitLab上のMRへ投稿する実機確認そのものは未実施のまま**である。

## 設計への反映

`.claude/docs/spec/adversarial-review.md`・DDR i0182-01 への反映は「実施した内容と結果」節に
記載のとおり完了している。次のissueへ持ち越す反映事項は無い。

## 想定と異なった点

jqの `index()` を `select()` 内で使う際、パイプの右辺で `.` を参照すると外側の値に束縛が
移ることに気づかず、実装当初のフィルタが実行時エラーになった（詳細:
`worklog/20260823_misty-drifting-lantern_選別スクリプトとドキュメント反映_push1.md`）。
`.severity` を変数へ先に束縛する形へ直して解決し、同じ落とし穴を
`.claude/rules/shell-script-style.md` へ反映した。
