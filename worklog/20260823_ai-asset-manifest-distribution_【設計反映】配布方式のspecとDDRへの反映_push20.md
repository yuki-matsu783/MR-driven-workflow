---
title: worklog 20260823 【設計反映】配布方式のspecとDDRへの反映 push20
type: log
description: distribution-assets.md の層ベース書き換え・asset-distribution.md の新設・DDR i0026-01 の追加を行った際の試行錯誤ログ
tags: [worklog, 設計反映, distribution, ddr]
keywords: [distribution-assets, asset-distribution, i0026-01, 未決定事項, changelog, 制御文字, US, generate-ddr-list]
---

# worklog: 【設計反映】配布方式のspecとDDRへの反映

対象: issue #26 のフェーズ4・2セット目（設計反映）（2026-08-23）。
全体作業計画: `plans/ai-asset-manifest-distribution.md`
個別作業計画: `plans/【設計反映】配布方式のspecとDDRへの反映.md`
push回数: 20

## 試したこと

- **`distribution-assets.md` の書き換えは、`sed` の一括置換を使わずPythonで位置指定した。**
  このファイルは「直す行」と「触ってはいけない行（過去changelog）」が同居しており、
  `sync-assets` を全置換すると issue #33 のエントリが壊れる。
  `s.index('### 配布経路での扱い')` 〜 `s.index('## 影響範囲')` の区間だけを差し替えた。
- **層の値は計画の表を信じず、`.claude/dist-layers.json` から `jq` で取り直した。**
  結果は計画どおり（PR/MRテンプレート＝`core` / `.claude/VERSION`＝`core`（`.claude` エントリに
  含まれる）/ `.gitattributes`＝`merge`・`lines-marker`）。
- **`.claude/VERSION` の `ALWAYS_OVERWRITE_RELPATHS` 例外が新方式でどうなったかを実装で確認した。**
  `install-to-project.sh` に該当の配列は無く、manifest の sha256 比較で「配布先が触っていなければ
  警告も `.bak` も出ない」形に変わっていた。**例外指定そのものが不要になった**ので、その理由を
  新しい「配布経路での扱い」節へ書いた。
- 検証1（廃止された語の残存確認）を流し、**11件のヒットがすべて許容されるもの**であることを
  1件ずつ確認した（内訳は結果レポート）。

## うまくいったこと

- **specを2つに割る線引きが、実際に書いてみて破綻しなかった。**
  `distribution-assets.md` =「配る**資産**の側」（どの行を配るか・VERSIONの増分規則）、
  `asset-distribution.md` =「配布**機構**の側」（5層・manifest・2パス・戦略）。
  `.gitattributes` のマーカー規約だけが両者にまたがるが、
  「配る行の定義は資産側、`lines-marker` という戦略は機構側」と分けて相互リンクした。
- **未決定事項の削除と changelog への解消先の記録を、必ず対にして行った**（計画の自己点検どおり）。
  4項目それぞれについて「どこで解消したか」を表で残している。
- **`.claude/VERSION` 据え置きの事実を changelog へ書いた**（規定上必須。忘れやすいので
  `HANDOFF.md` の「次にやること」へ2セッションにわたり残していた）。AIの `1.0.0` 提案が
  **採用されなかった**という経緯まで含めて書いた。

## ダメだったこと

- **spec本文へ生の制御文字（US = `0x1F`）を書いてしまった。**
  「US区切りの中間表現」と説明する箇所で、バッククォートの中へ**区切り文字そのもの**を
  書いていた。Bashツールが「承認ダイアログで見えない制御文字を含む」として弾き、
  そこで初めて気づいた。`.claude/rules/shell-script-style.md`「ソースコードへ生の制御文字を
  書かない。エスケープ表記を使う」がまさにこれで、**規約を知っていても踏んだ**。
  - `grep` では見えず、`wc -c` と `tr -d '\037' | wc -c` の差（1バイト）で確認した。
    規約が「除去の前後でバイト数を比較するのが確実」と書いているとおりだった。
  - 直したあとも同じ検査を流し、差が0になることを確認している。
- **DDRの節見出しを `a` / `b` / `c` にしたのに、spec側から `3-b` / `3-c` と参照していた。**
  計画ファイルの節番号（3-a/3-b/3-c）をそのまま書き写したため。DDRを書いた後に
  `grep -rn 'i0026-01 の'` で拾って直した。**計画の見出し番号と成果物の見出し番号は別物**である。

## 次の一歩

- 3セット目の `【AIアセット反映】`。**新設した spec のファイル名が
  `asset-distribution.md` に確定した**ので、ツリー・Repository Map へ載せられる。
- `check-dist-coverage.sh` の冒頭コメントの参照先を `asset-distribution.md` へ付け替えた。
  これは計画が「範囲外（実装・テストの修正）」としていたが、**spec を割ったこと自体が
  作った不整合**なので同じコミットで直した（結果レポートへ差分として記録した）。

---
