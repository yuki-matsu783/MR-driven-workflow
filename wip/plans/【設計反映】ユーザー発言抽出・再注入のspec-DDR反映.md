---
title: 【設計反映】ユーザー発言抽出・再注入のspec・DDR反映
type: plan
description: issue #151 のフェーズ4〈反映〉。フェーズ2・3で確定した設計判断を、既存spec（issue-mr-workflow.md）への追記とDDR i0151-01新設として正史へ書き戻す個別反映計画
tags: [issue-mr-flow, session-start, transcript, 反映計画, ddr]
keywords: [spec, DDR, i0151-01, origin.kind, 除外辞書, transcript_path, sectionText, generate-ddr-list, issue-mr-workflow]
---

# 【設計反映】ユーザー発言抽出・再注入のspec・DDR反映

issue #151（PR #197）フェーズ4〈反映〉flow-id 4-1。

## 前提（合意状況）

- 依拠する作業結果: `wip/reports/20260830_session-start-user-utterance-reinject_作業結果.md`
  （flow-id 3-8〜3-9で人間レビュー承認済み）
- 依拠する設計判断・却下案: PR #197 description「設計判断・採らなかった案」（flow-id 3-10で確定）
- 敵対的レビュー（フェーズ4計画段階・1回目）で、以下の指摘を受けて全面的に書き直した:
  - 既存specの該当節（`.claude/docs/spec/issue-mr-workflow.md`「セッション開始時の自動コンテキスト
    注入（SessionStart hook）」）を見落とし、新設specが正史を2箇所に割る計画になっていた
  - spec構成案が実装値を読まずに書かれていた（抽出条件・文字数・出力位置）
  - コード内に残る `wip/plans/` 参照6箇所の付け替えが計画に無かった
  - 「やらないと決めた」項目をspecの「未決定事項」へ書く計画になっていた
  - 4類型の語彙をspec/ddrの洗い出しへ誤って流用していた
  - md/htmlの見出しが同期していなかった

## この計画で何をするか

フェーズ2・3で確定した設計判断は、まだ正史ドキュメント（`.claude/docs/spec/`
`.claude/docs/ddr/`）に1件も反映されていない。**新規specファイルは作らず**、既存の
`.claude/docs/spec/issue-mr-workflow.md`「セッション開始時の自動コンテキスト注入
（SessionStart hook）」節へ新しい項目として追記し、DDR `i0151-01` を新設する。

### 既存specの確認結果（新規ファイルを作らない理由）

`doc-search --type spec --text session-start` はfrontmatterしか見ないため
`otel-listener.md` のみがヒットし、本文中の該当節を見落としていた。本文grep
（`grep -rln 'SessionStart' .claude/docs/spec`）で `issue-mr-workflow.md` L922
「### セッション開始時の自動コンテキスト注入（SessionStart hook）」が既に存在し、
issue #57（compact再注入）・issue #113（SKILL.md再読み込み指示）・issue #160（現在地flow-id
注入）がいずれもこの1節へ箇条書き項目として追記される形で正史になっていることを確認した。
**この節が唯一の正であり、新設specを作ると正が2つに割れる**（`REVIEW-POINTS.md`「正が2つ
あると更新漏れを検出できず、片方だけが古くなる」）。issue #151も同じ節へ、issue #113・#160と
同形式の箇条書き項目として追記する。

## 反映対象の洗い出し（spec/ddr）

反映対象は2つ。**AIアセット反映の4類型（(a)〜(d)）はAIが読む・従うもの向けの枠組みであり、
spec/ddrの洗い出しには適用しない**（`references/planning.md`「AIアセット反映の対象の洗い出し」
は「spec/ddr・実装コード/テストコードの判定は別に必要」と明記している）。ここでは素直に
「該当する記述が既存specにあるか」を確認した結果を書く。

1. **spec追記**: `issue-mr-workflow.md`「セッション開始時の自動コンテキスト注入」節に、
   issue #151のユーザー発言抽出・再注入を扱う項目が無い（上記確認済み）。
2. **DDR新設**: 採用した判断・却下した案を記録するDDRが無い（`i0151-01`は未使用の枝番。
   `.claude/docs/README.md`のDDR一覧に該当なし）。

## 変更対象

| ファイル | 操作 | 何をするか |
|---|---|---|
| `.claude/docs/spec/issue-mr-workflow.md` | 変更 | 「セッション開始時の自動コンテキスト注入」節へ、issue #113・#160と同形式の新項目「ユーザー発言の抽出・再注入（issue #151）」を追記 |
| `.claude/docs/ddr/i0151-01-<決定文タイトル>.md` | 新規 | 採用案・却下案・しきい値改定・実装時のスキーマ変更の経緯 |
| `.claude/docs/README.md` | 変更 | `generate-ddr-list.sh`によるDDR一覧の再生成 |
| `.claude/hooks/session-start.sh`（L53, 89, 281, 507） | 変更 | `wip/plans/【設計】…実装.md`への参照4箇所を、新設したspec項目のアンカーへ差し替え |
| `.claude/hooks/lib/UserUtteranceSelect.jq`（L21） | 変更 | 同上（「設計の正」コメント） |
| `.claude/scripts/test/test_session_start.sh`（L521） | 変更 | 同上（「設計の正」コメント） |

## 方針

### spec追記の内容（実装値を読んで確定済み）

`.claude/hooks/session-start.sh` と `.claude/hooks/lib/UserUtteranceSelect.jq` の実装を読み、
以下の値で構成する（構想案ではなく確定値）。

```
**ユーザー発言の抽出・再注入（issue #151）**: 上記の現在地flow-id注入に続けて、
transcriptから抽出したユーザーの生発言を再注入する。「HANDOFF.md 次にやること」ブロックの
**直後**（SKILL.md再読み込み指示より前）へ挿入する。

- コンポーネント: `.claude/hooks/lib/UserUtteranceSelect.jq`（抽出・選定・整形の中核。
  `jq -R -n -f` + `inputs` で全走査）＋ `.claude/hooks/session-start-ack-words.txt`
  （除外辞書）＋ `session-start.sh` の `build_user_utterance_context` 等。
- 母集団の抽出条件（6条件すべてを満たす行）:
  `type=="user"` かつ `message.content` が文字列型 かつ `userType=="external"` かつ
  `isSidechain==false`（`//`演算子はfalseもfalsyにするため直接比較で書く。issue #151で
  実際に踏んだ） かつ `origin.kind=="human"`（肯定形。否定形だと`origin`キー自体を持たない
  行が混入する） かつ `uuid`（無ければ行番号を代替キー）による重複除去。
  さらにスラッシュコマンド単独行・タグ始まりの行を除外理由付きで弾く。
- 選定: 先頭3件＋直近7件（最大10件）。1件あたりの文字数は先頭群が頭120字+末尾40字、
  直近群が頭80字+末尾30字（中間を`…`で省略。`jq`の`.[0:N]`で文字単位に切る。
  `${var:0:N}`は環境によりバイト単位で日本語が壊れる）。改行・連続空白は半角スペース1つへ
  畳んでから切り出す。
- 除外規則（「育てる」辞書）: `.claude/hooks/session-start-ack-words.txt`
  （プレーンテキスト、1行1語、正規化後の完全一致）。除外実績を注入テキストへの内訳行と
  `wip/state/`（gitignore対象）への累積カウント（`uuid`集合で重複計上を防ぐ）で可視化する。
  発言本文は一切保存しない。
- サイズ管理: 発言節の上限6,000B（`append_size_warning`の第3引数`excluded_bytes`。末尾・
  省略可・既定0で既存6箇所の呼び出しは無変更）。再注入バイト数はセンチネル行
  `__USER_UTTERANCE_BYTES__:<N>`で`build_user_utterance_context`から`main`へ返す
  （`strip_utterance_sentinel_to_reply`が本文から除去）。
- 性能: しきい値500ms（flow-id 2-8で200ms→500msへ改定。全走査方式のまま採用）。
- fail-open: 読み取り・抽出に失敗しても他項目の注入を止めない（サブシェル内で`set -e`を
  掛け直し、失敗時は空文字列を返す2-form。DDR i0057-01のfail-open方針を踏襲）。
- スコープ外（意図的にやらないと決めたもの）: Gemini CLI経路（issue #201へ切り出し）、
  過去transcriptの走査（この節の既存注入で代替）、AskUserQuestion回答の母集団への混入対応
  （抽出条件の再設計に近い規模のため見送り）、除外辞書の配布層判断（issue #207へ切り出し）。
  詳細・却下案: [i0151-01-…](../ddr/i0151-01-…md)
```

### DDR本文の構成（1本にまとめる。決定文タイトルにする）

タイトル案: `i0151-01. compact後のユーザー発言再注入はorigin.kind条件・育てる辞書・全走査
（しきい値500ms）で実装する`

**12件の採用判断・11件の却下案を1本のDDRへまとめる。** 個別に採番して分割する案も検討したが、
既存DDR（例: `i0057-01`）も「matcherへの`compact`追加」「注入内容」「しきい値」「fail-open」の
複数facetを1本へまとめている前例があり、本件もissue #151という単一機能の一体の設計判断のため
1本にまとめる。タイトルは「何を決めたか」が一覧から読み取れるよう決定文にする。

- 採用した判断12項目（PR #197 description「設計判断・採らなかった案」の表を「検討したが○○を
  採用した」という理由付きの文体へ整理）
- 却下した案11項目
- しきい値改定（200ms→500ms）の経緯（人間判断であり、AIの自己判断による緩和ではないことを明記）
- 実装時にスキーマを`selected`/`excludedCounts`から`sectionText`/`excludedEvents`へ変更した経緯

## やらないこと（スコープ外）

- **Gemini CLI経路の対応**（issue #201へ切り出し済み。本specへは「スコープ外」として言及するに
  留め、詳細はissue #201側で扱う）
- **除外辞書の配布層判断**（issue #207へ切り出し済み）
- **git bash実機での再測**: これは「やらないと決めた」のではなく**未確認のまま**であり、
  spec本文の「未確認事項」として明記する（下記「実施手順」参照。決定済みのスコープ外項目とは
  区別する）
- **ブランチ絞りの効きの実データ検証**: 同上、未確認のまま明記する

## 検証

```bash
# 分岐点は実行時に求める（書き写さない。REVIEW-POINTS.md「分岐点は、fetchしてから実行時に求める」）
git fetch origin main
BASE_SHA="$(git merge-base origin/main HEAD)"

# DDR一覧の追加行を「行数」ではなく「i0151-01を含む行」で数える
git diff "$BASE_SHA" -- .claude/docs/README.md | grep -c '^+.*i0151-01'   # 期待値1

# 参照の付け替えが漏れていないことを確認する
grep -rn 'wip/plans/' .claude/hooks/session-start.sh .claude/hooks/lib/UserUtteranceSelect.jq \
  .claude/scripts/test/test_session_start.sh   # 期待値0件（汎用的な「wip/plans/配下」という
  # 言及（session-start.sh L103, L147）は対象外。特定のこの計画ファイルへのパス参照のみ0にする）

# .claude/ ディレクトリ単位で意図しない変更が無いことを確認する
git diff "$BASE_SHA" -- .claude/ | grep -c '^diff --git'

bash .claude/scripts/src/generate-ddr-list.sh
bash .claude/scripts/src/check-doc-references.sh
bash .claude/scripts/src/extract-frontmatter.sh .
```

合格条件: DDR一覧に`i0151-01`を含む行が1つだけ追加される。`wip/plans/`への特定パス参照が
コード側から0件になる。`check-doc-references.sh`が参照切れ0件を報告する。新規DDRの
frontmatterが`.claude/rules/markdown-frontmatter.md`の規約（type/title/description/tags/
keywords、DDR識別子書式）を満たす。
