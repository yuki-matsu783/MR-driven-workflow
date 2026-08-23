---
title: 設計反映の結果（配布方式のspecとDDR）
type: report
description: distribution-assets.md を層ベースへ書き換え、配布機構のspec asset-distribution.md を新設し、DDR i0026-01 を追加した結果
tags: [report, 設計反映, distribution, ddr]
keywords: [distribution-assets, asset-distribution, i0026-01, 未決定事項, changelog, VERSION据え置き, point-in-time, generate-ddr-list, 制御文字]
---

# 設計反映の結果: 配布方式のspecとDDR

flow-id 4-6（`【設計反映】`。フェーズ4の2セット目）。計画は
`plans/【設計反映】配布方式のspecとDDRへの反映.md`。

## 結論

**specを2つに割り、DDRを1件追加した。** `distribution-assets.md` は「配る**資産**の側」に絞り、
新設した `asset-distribution.md` が「配布**機構**の側」を持つ。

| 成果物 | 内容 |
|---|---|
| `.claude/docs/spec/distribution-assets.md`（更新） | 「配布経路での扱い」を層ベースへ全面書き換え／未決定事項5件のうち**4件を削除**／changelogへ `### issue #26（2026-08-23）` を追記 |
| `.claude/docs/spec/asset-distribution.md`（**新設**） | 5層・`dist-layers.json`・manifest・2パス構成・`merge` の2戦略・`requiredLine`・網羅性チェック・性能・未決定事項3件 |
| `.claude/docs/ddr/i0026-01-….md`（**新設**） | 方式選定（受け入れ条件11）・`exclude` の明示必須・`AGENTS.md` を `core` にしなかった判断を、**1件の中で節 a / b / c に分けて**記述 |
| `.claude/docs/README.md` | spec一覧へ1行追加＋DDR一覧を `generate-ddr-list.sh` で再生成（76件） |

**受け入れ条件11（方式選定のDDR）は、これで満たされた。**

## specを2つに割った線引き

| | `distribution-assets.md` | `asset-distribution.md`（新設） |
|---|---|---|
| 主題 | 配る**資産** | 配布**機構** |
| 持つもの | どの行を配るか（`.gitattributes` のマーカー）・PR/MRテンプレートの見出し規約・`.claude/VERSION` の増分規則 | 5層の定義・`dist-layers.json` のスキーマ・manifest のスキーマ・2パス構成・`lines-marker` / `json-keys`・`requiredLine`・網羅性チェック・性能 |
| issue | #33 が初版 | #26 が初版 |

**`.gitattributes` だけが両者にまたがる。** 「配る行の定義（マーカーの規約）」は資産側、
「`merge` / `lines-marker` という戦略の仕様」は機構側、と分けて相互リンクした。
同じことを二重に書いていない。

## `distribution-assets.md` の変更

### 「配布経路での扱い」を層ベースへ

旧: `sync-assets.sh` と `install-to-project.sh` の2列表（`safe_copy_dir` /
`ALWAYS_OVERWRITE_RELPATHS` / `ensure_gitattributes_rules` を現在の仕様として記述）。

新: 3資産それぞれの層と、その層で何が起きるか。

| 資産 | 層 | 配布先の既存ファイルの扱い |
|---|---|---|
| PR/MRテンプレート（`.github/` `.gitlab/`） | `core` | 常に上書き。配布先が適用後に変更していれば `.bak` 退避＋一覧 |
| `.claude/VERSION` | `core`（`.claude` エントリに含まれる） | 同上 |
| `.gitattributes` | `merge`（`lines-marker`） | 上書きしない。マーカー間の行が無ければ足すだけ |

**この表は計画に書いた値をそのまま使わず、`.claude/dist-layers.json` から `jq` で取り直した**
（計画の自己点検「実装が正」に従った）。結果は計画と一致していた。

あわせて、書き換えの過程で分かった2点を新しい節へ書いた。

- **`.claude/VERSION` の専用例外（旧 `ALWAYS_OVERWRITE_RELPATHS`）は要らなくなった。**
  旧方式は「本家と1バイトでも違えば改変」という判定しか持てず、**版を上げた回は必ず**
  警告と `.bak` が出るため、例外指定でそれを抑えていた。新方式は manifest の sha256 と比べる
  ので、配布先が触っていなければそもそも改変とみなさない。**上流の更新と配布先の改変を
  区別できるようになったことで、例外という仕組み自体が消えた。**
- **PR/MRテンプレートは `seed` ではなく `core` である。** 旧「未決定事項」の見込みが誤っていた
  （下記）。見出し構成が `describe` の出力と一致していなければならないため、配布先が
  書き換えることを想定しない。

### 未決定事項の整理（4件削除・2件残す）

| 項目 | 扱い | 解消先 |
|---|---|---|
| Windows実機での改行挙動が未確認 | **残す** | — （新specの3件と同根である旨を相互参照） |
| `.claude/VERSION` と manifest の役割 | **残して書き換え** | 「両方を持ち続けるかは未決定」という論点へ更新した |
| #26 への移行時の層の対応表 | **削除** | 「配布経路での扱い」の表が正。**旧表の「PR/MRテンプレート＝`seed`」は誤りで、実装は `core`** |
| `.gitignore` 追記の3つの問題 | **削除** | `merge` / `lines-marker` として作り直して解消 |
| `HAS_WARNED` が伝わらない | **削除** | `safe_copy_dir` ごと廃止。走査パスで件数を集計する形になった |
| ローカル生成物の混入 | **削除** | `local` 層（17エントリ） |

**削除と changelog への記録は必ず対にした**（計画の自己点検どおり）。削除した4項目それぞれに
「どこで解消したか」を changelog の表として残しているので、`git log` を辿らなくても解消先が分かる。

## `.claude/VERSION` を据え置いた事実（規定上必須）

`distribution-assets.md`「人間の判断で据え置くことがある」は、**据え置く場合はそのissueの
changelogへ据え置いた事実を残す**と定めている。これは任意ではないため、新しいエントリへ書いた。

- AIエージェントは `1.0.0`（`MAJOR`）を提案した。根拠は、旧方式で配られた `AGENTS.md` が
  `requiredLine` の一覧提示だけでは自動で直らず、**配布先に手作業での移行を要求する**こと。
- **この提案は採用されず、flow-id 4-4 のレビューで `0.2.0` 据え置きと決まった**
  （増分を決めるのは人間、という規定どおりの結果）。
- 実害（配布先は同じ版のまま**配布の仕組みごと入れ替わった** `.claude/` を受け取る）も書いた。
  ただし issue #26 で manifest が入ったため、**機械可読な同一性は manifest 側で判別できる**。
  VERSIONだけが手掛かりだった issue #54 の据え置きとは、この点が異なる。

## DDR i0026-01

**3件へ分ける当初案は、flow-id 4-4 のレビューで「細かいので1つにする」となった**ため、
1件の中で節を分けた。

| 節 | 決定 | 却下案 |
|---|---|---|
| a | manifest付きの直接コピーを選ぶ（**受け入れ条件11**） | git subtree/submodule・Claude Code plugin配布・差分をAIが都度判断する案・旧方式の個別修正 |
| b | 層は `exclude` を含む5つにし、配らないことを明示指定にする | 暗黙の既定値（未指定＝配らない） |
| c | 旧形式の `seed` は `core` へ昇格させず `requiredLine` で一覧提示にとどめる | `AGENTS.md` を `core` にする案・自動で書き換える案・何もしない案 |

- **節 a を最も厚くした**（計画の自己点検「3-a が 3-b・3-c に埋もれて薄くなる危険」への対処）。
  却下案を4つ挙げ、それぞれ「なぜ正攻法に見えるか」と「なぜ却下したか」を対にして書いている。
- **束ねたことの帰結を本文末尾へ1行残した。** 後から一部だけが無効になっても
  `status: superseded` はDDR単位でしか付けられないため、その場合は**後続DDRの本文で
  「`i0026-01` の a のみを置き換える」と明示する**、と書いた。

## 検証

| 検証 | 結果 |
|---|---|
| 検証1: 廃止された語の残存 | **11件**（すべて許容。内訳は下記） |
| 検証2: `generate-ddr-list.sh --check` | **最新（76件）** |
| 検証3: DDR識別子の重複 | **0件** |
| 検証4: frontmatterインデックス | `i0026-01` / `asset-distribution` の**2件**が載った |
| 検証5: 網羅性チェック | 追跡ファイル **221/221** 件・`.gitignore` 13/13 行・空振り0件・不正0件 |
| 検証6: 単体テスト | 18ファイル / **`passed=1147 failures=0`** |

### 検証1の内訳（0件を期待しない検証）

計画のとおり、この検証は**0件にならない**（過去changelogの行が必ず残る）。11件すべてが
「触ってはいけない行」か「新しい説明文の中で歴史として言及した行」であることを確認した。

| ファイル | 行 | 種別 |
|---|---|---|
| `distribution-assets.md` | 109, 121, 171, 191 | **新しい説明文**（`旧 ALWAYS_OVERWRITE_RELPATHS` / `当時の実装名` / `削除した語の一覧` / `解消先の表`） |
| `distribution-assets.md` | 143, 145 | issue #33 の changelog（**point-in-time。無傷**） |
| `issue-mr-workflow.md` | 2369, 3071, 3080 | 過去issueの changelog（issue #63 / #54）。**触らない** |
| `directory-structure.md` | 142, 144 | 「issue #26以前」と明記済み。フェーズ3で更新済み |

網羅性の分母が 218 → 221 に増えているのは、このセットで spec 1件・DDR 1件・計画/レポートの
md を足したためである。

## 計画との差分

| 計画 | 実際 |
|---|---|
| 新specのファイル名は実装時に確定してよい | **`asset-distribution.md`** に確定した |
| 「Windows実機での改行挙動」を新specへ集約するか、資産側に残すかは実装時に決める | **両方に残し、相互参照した。** 資産側は `.gitattributes` の改行、機構側は sha256 のLF正規化と `.gemini/` のリンク判定で、**主語が違う**ため片方へ寄せると読みにくくなる |
| `.claude/VERSION` と manifest の役割の項は「削除」候補ではなかった | **残したうえで論点を書き換えた**（「役割が重複しない」という事実の記述から、「両方を持ち続けるかは未決定」という未決の論点へ） |
| 範囲外: 実装・テストの修正 | **`check-dist-coverage.sh` の冒頭コメントの参照先だけ付け替えた**（下記） |

### 範囲外だが直した1箇所

`.claude/scripts/src/check-dist-coverage.sh` の3行目は
`# 仕様: .claude/docs/spec/distribution-assets.md（issue #26）` だった。このスクリプトは
**配布機構の網羅性チェッカ**なので、spec を割った時点で参照先が誤りになる。

**spec を割ったこと自体が作った不整合**であり、放置すると次に読む人が資産側の spec を開いて
「網羅性チェックの説明が無い」と混乱する。コメント1行の付け替えで挙動は変わらないため、
同じコミットへ含めた（`bash -n` で構文確認済み。単体テストも全件通っている）。

## 触らなかったことの確認

計画が挙げた「触ってはいけない箇所」は、いずれも差分に含まれていない。

- `.claude/docs/ddr/**` の既存本文（**`i0033-03` の `ensure_gitattributes_rules` はそのまま**。
  代わりに `distribution-assets.md` 側へ「同DDRの本文は当時の実装名で書かれている」という
  読み方の注意を添えた）
- `distribution-assets.md` の issue #33 / #54 の changelog エントリ
- `issue-mr-workflow.md` の 2369 / 3071 / 3080 行目付近
- `.claude/rules/directory-structure.md` 142〜144行目
