---
title: 20260823 Gemini-CLIテレメトリ集計機構の実装結果
type: report
description: issue #105フェーズ3（作業）flow-id 3-6の実施結果。設定層・集計層・レポート層・配布gitignore是正・単体テストの実装内容と、作業実施時敵対的レビュー（2回目）で見つかった不具合の修正内容
tags: [gemini-cli, telemetry, usage-report, issue-105]
keywords: [sync-gemini-assets, UsageTracking, post-push-usage-report, byteOffset, install-to-project, 二重計上, テスト, 敵対的レビュー]
---

# Gemini CLIテレメトリ集計機構の実装結果（フェーズ3 / flow-id 3-6）

## サマリ（結論の一覧）

| # | やったこと | 結論 | 根拠の性質 |
|---|---|---|---|
| 1 | `.gemini/settings.json`へtelemetryブロックを注入する仕組みを実装 | `sync-gemini-assets.sh`経由で`enabled: false`固定・`target: "local"`・`outfile: "usage/gemini-otel.log"`を注入する形で実装完了 | 実装の確認＋`--check`の前後比較 |
| 2 | バイトオフセットカーソルによるテレメトリ差分集計を実装 | `UsageTracking.sh`へ既存経路と完全独立の関数群（`_sync_usage_state_otel`等）を追加した。**推測に基づく仕様どおりに動くことを合成フィクスチャ（実装と同じ仮定に基づく）で確認した**（実データでの検証ではない） | 実装の確認＋合成フィクスチャによる単体テスト |
| 3 | 対応工数レポートへのテレメトリ統合 | `post-push-usage-report.sh`へ第6引数`telemetry`を既定値付きで追加し、既存の5引数呼び出しを壊さずに独立した参考値セクションとして統合完了 | 実装の確認＋単体テスト |
| 4 | 配布先`.gitignore`へ`/usage/`の除外を追加 | `install-to-project.sh`の`ignore_rules`へ1行追加し、配布先で反映されることを確認 | 実装の確認＋結合テスト |
| 5 | 既存の集計結果・レポート内容が変化しないこと | Claude Code経路・Gemini CLIセッションログ経路（issue #97）の既存90ケースがすべて無変更で通過 | 単体テストの全件成功 |
| 6 | フェーズ3作業実施時敵対的レビュー（2回目）の指摘対応 | 12件の指摘（major 6・minor 6）すべてに対応した（詳細は下記「4. 敵対的レビュー対応」） | 実装の確認＋再現手順による検証＋単体テスト |

## 実施条件（測った対象・環境）

- 実行環境: Claude Code on the web（リモート実行環境、Linux）
- 対象: `claude/gemini-cli-telemetry-reporting-a253xp`ブランチ上の本リポジトリ
- 実施日: 2026-08-23
- 実機（Gemini CLI）でのテレメトリ出力形式の検証は、この実行環境に対象CLIが無いため実施不可
  （フェーズ2調査結果と同じ制約。集計側の属性名・イベント判定は推測に基づく実装であり、
  未検証のままである点は下記「確かめられなかったこと」に記載）。

## 実施した内容と結果

### 1. 設定層: `.gemini/settings.json`へのtelemetry注入

`.claude/scripts/src/sync-gemini-assets.sh`の`SETTINGS_JQ_FILTER`（出力オブジェクト構築部分）へ、
次の固定値ブロックを追加した。outfileのパスは`GEMINI_OTEL_OUTFILE_REL`という1つの定数から
`--arg`で渡す（後述「4. 敵対的レビュー対応」で読み取り側と共有する設計へ修正）。

```jq
+ {
  telemetry: {
    enabled: false,
    target: "local",
    outfile: $otelOutfile,
    logPrompts: false
  }
}
```

検証は「生成前に失敗することを先に確認する」手順で行った。

```
$ bash .claude/scripts/src/sync-gemini-assets.sh --check
.gemini/ が .claude/ と食い違っています。   # 変更直後は不一致（exit=1）
$ bash .claude/scripts/src/sync-gemini-assets.sh
.gemini/ を再生成しました。
$ jq -e '.telemetry.enabled == false and .telemetry.target == "local"
          and .telemetry.outfile == "usage/gemini-otel.log"' .gemini/settings.json
true
$ bash .claude/scripts/src/sync-gemini-assets.sh --check
.gemini/ は .claude/ と同期しています。   # exit=0
```

`test_sync_gemini_assets.sh`のT9ゴールデンフィクスチャ（`settings-expected.json`）も、実際の
出力で更新した。

> **結論**: telemetry設定は生成物経由で注入され、`--check`による同期検証が通る。手編集による
> 設定ドリフトのリスクは無い。ただし`enabled: false`を利用者側から有効化する手段は現時点で
> 存在しない（後述「4. 敵対的レビュー対応」）。

### 2. 集計層: バイトオフセットカーソルによる差分集計

`.claude/hooks/lib/UsageTracking.sh`へ、既存のGemini CLIセッションログ集計（issue #97）とは
入力データソース・状態ファイルとも完全に独立した関数群を追加した。

- `_usage_otel_extract_complete_to_reply`: 列0の`}`のみの行を1エントリの終端とみなし、
  「完全にパースできた末尾までの部分」を切り出す。
- `_usage_otel_fold`: metricsレコードを除外し、semantic conventions形式（`gen_ai.*`属性）の
  `api_response`のみを畳み込む。**レガシー形式は常に無視する**ことで、同一イベントの二重emitに
  よる二重計上を構造的に防いでいる。
- `_usage_read_otel_state` / `_usage_write_otel_state`: `usage/state/gemini-otel/cursor.json`
  （ブランチ非依存のグローバル状態）の読み書き。空・不正JSONは既定値へ自己回復する。
- `_sync_usage_state_otel`: 集計本体。ファイル縮小検知・途中書き込み対応を含む。**初回集計
  （カーソル0）でも特別扱いせず、既存の蓄積データを含め全量を計上する。**
- `_usage_reset_otel_since_last_push`: push成功後のゼロ初期化。

単体テストケースを`test_usage_tracking.sh`へ追加し（当初9件、後述の敵対的レビュー対応で5件を
追加し計14件）、下記の観点をすべて確認した。

| ケース | 確認内容 | 結果 |
|---|---|---|
| 正常系 | レガシー形式＋semantic形式の対 → semantic形式のみ計上（input=100, calls=1） | OK |
| 境界またぎ2重emit | レガシー形式とsemantic形式が別々の読み取りウィンドウに分かれても二重計上しない（input=200） | OK |
| metrics混在 | metricsレコードがtokens/callsへ現れない | OK |
| カーソル継続 | 1回目後の追記分のみが2回目の差分として計上される（累計120, calls=2） | OK |
| 初回集計 | 有効化前から溜まっていた3件が初回1回のカーソル0集計で全量計上される（calls=3） | OK |
| ファイル縮小 | byte_offsetが0へリセットされ、**縮小前に積んだsinceLastPushは消えず**新しい内容が別モデルキーとして上乗せされる | OK |
| 作り直し検知（サイズ不変） | サイズが縮まない作り直しも、前回読み込んだ範囲のチェックサム（prefixFingerprint）で検知し先頭から再取得する（後述レビュー対応） | OK |
| 状態ファイル破損 | cursor.jsonが空文字列でも既定値へ自己回復する | OK |
| fold失敗時の状態保護 | fold結果が不正なJSONでも、cursor.jsonを壊さず既存のsinceLastPushをそのまま返す（後述レビュー対応） | OK |
| 途中書き込み | 列0の`}`で終わらない末尾は今回計上に含めず、完結後の次回集計で拾われる（calls 1→2） | OK |
| 完全なエントリ0件 | 先頭から完全に途中書き込みのみのoutfileでも、単体呼び出しで例外なく終了する（後述レビュー対応） | OK |
| attributes配列形式 | OTLP標準形の`[{key,value}]`配列が来てもクラッシュせず0件として扱われる（後述レビュー対応） | OK |
| レポート本文統合 | 下記「3. レポート層」参照 | OK |

> **実装過程で見つかった不具合と対処**: 最初の実装は`jq -R -n 'inputs'`（raw-input）を使って
> おり、複数行にまたがるpretty-print JSON値を1行ずつ`fromjson`しようとして常に0件になって
> いた。`-R`を外し`jq -n '[inputs]'`（ネイティブJSONストリームパーサ）へ変更して解決した。
> 詳細はworklog（`_push10.md`）参照。

### 3. レポート層: `post-push-usage-report.sh`への統合

`build_usage_report_body()`へ第6引数`telemetry`を`local telemetry="${6:-}"`という既定値付きで
追加し、既存の5引数呼び出し（既存テスト含む）を壊さないようにした。テレメトリ由来の値は
既存のトークンテーブルへ**合算せず**、「### Gemini CLI公式テレメトリ（参考値）」という独立した
セクションとして出す。`telemetry.calls`が0（または`telemetry`自体が空/`null`）の場合は
セクションごと出さない。

`main()`では、`usage/gemini-otel.log`の**存在有無**（`engine`ではなくデータの有無）で
`_sync_usage_state_otel`を呼ぶかどうかを判定し、既存設計方針（列構成はengineではなくデータで
決める）と整合させた。**投稿要否のゲート（合計トークン0なら投稿しない判定）にもテレメトリの
`calls`を含めるよう後述のレビュー対応で修正した**（当初はテレメトリしか無いpushでレポートが
出ない不具合があった）。

```
$ bash .claude/scripts/test/test_usage_tracking.sh
passed=120 failures=0   # 既存90ケース＋新規30アサーション（当初22、レビュー対応で8追加）
```

第6引数を省略した既存の5引数呼び出し（既存90ケース内で複数回呼ばれる）が無変更で通過することを
もって、既存のClaude Code経路・Gemini CLIセッションログ経路のレポート内容が変化しないことを
確認した。

> **結論**: テレメトリ由来のトークンは、既存の対応工数集計（issue #97のセッションログ由来
> トークン）とは独立した参考値として提示され、二重計上は起きない。

### 4. 敵対的レビュー対応（フェーズ3・作業実施時・2回目）

flow-id 3-7でpush後、`adversarial-review`スキルに従いフェーズ3の作業実施時敵対的レビューを
1回目に続き2回目実施した（`adversarial-review-count.sh`のフェーズ3カウンタ=2）。対象は
push10の実装差分（設定層・集計層・レポート層・配布gitignore是正・単体テスト）。

12件の指摘（major 6件・minor 6件）のうち、確度×重大度の振り分け基準（major/high・major/medium・
minor/highはすべて投稿対象）に従い10件をMR #174へインラインコメント投稿し、残り2件
（いずれもminor/confidence medium）はレビュー本文へ報告のみとして記載した。**投稿・報告した
12件すべてに対応した。**

| # | 指摘 | 対応 |
|---|---|---|
| 1 | `_usage_otel_fold`/最終状態のjq出力が不正でも検証せず`cursor.json`へ書き戻し、1度の失敗で状態が0バイトになり恒久的に壊れる | `_usage_write_otel_state`に書き込み前検証を追加し無効なら書かず終了コード1。`_sync_usage_state_otel`もfold結果・最終状態の検証を追加し、無効なら既存stateをそのまま返す |
| 2 | `has()`/`keys|startswith`がOTLP標準のattributes配列でjqごとクラッシュする | `is_metric_record`/`is_semantic_api_response`へ`type == "object"`のガードを追加。event.nameも部分一致から厳密一致へ変更 |
| 3 | カーソル妥当性検査がファイル縮小しか見ておらず、サイズが縮まない作り直しを検知できない | 前回読み込んだ範囲のチェックサム（`prefixFingerprint`）をstateへ保存し、次回読み込み前に突き合わせて不一致なら先頭から再取得する`_usage_otel_prefix_fingerprint_to_reply`を追加 |
| 4 | 投稿要否の判定（total==0で終了）にテレメトリが入っておらず、テレメトリしか無いpushでレポートが出ない | `otel_calls`をゲート判定・state不在時のフォールバックの両方に組み込んだ |
| 5 | `enabled: false`の根拠として指しているspecに、逆の結論（OTel計測が行われない）が書かれたまま | spec名指しをやめ、issue #105のみを参照するコメントへ変更（フェーズ4でspec反映） |
| 6 | `enabled: false`固定＋`--check`ゲートにより現状どうやっても有効化できないことが読み取れない | コメントへ「現時点で有効化する手段は存在しない」ことを明記し、有効化手段の確立を未決定事項として明示 |
| 7 | コードコメントから`reports/`のファイル・フェーズ2報告を参照している（flow-id 5-5で消える） | issue #105番号のみの参照へ置き換えた（3箇所） |
| 8 | outfileのパスが変換フィルタと読み取り側の2箇所にハードコードされ、設定変更が無言でずれる | `sync-gemini-assets.sh`に`GEMINI_OTEL_OUTFILE_REL`定数を新設し、読み取り側は`_usage_otel_resolve_outfile_to_reply`で`.gemini/settings.json`の`telemetry.outfile`を動的に読む設計へ変更 |
| 9 | 「Claude側テーブルへ混ざらない」の検証がヘッダ文字列頼みで、数値加算の退行を検出できない／表の中身を検証していない | テレメトリ表の行を完全一致で固定するアサーションを追加し、「混ざらない」検証もClaude側行の完全一致＋テレメトリモデル名がClaude側テーブル範囲に現れないことで表現し直した |
| 10 | md版とHTML版のケース表が9行/8行で不一致、md側にHTMLビュー用マークアップ（`<div class="box">`等）が混入 | 本レポート（md）のHTML断片をmarkdown引用（`>`）へ置き換え、HTML版のケース表を最新の内容へ同期した |
| 11（報告のみ） | 完全なエントリが1件も無い経路が未テストで、直接呼び出し文脈では`set -e`により関数ごと落ちる | `grep`パイプラインへ`|| true`を追加し、単体呼び出しでも安全に空扱いへ落ちるよう修正。専用テストケースを追加 |
| 12（報告のみ） | サマリの結論表現が「動作を確認」と言い切っており、実際に検証した対象（実装と同じ仮定の合成フィクスチャ）とずれている | 本レポートのサマリ表現・根拠の性質欄を「合成フィクスチャで確認（実データ未検証）」へ修正 |

すべて実装ツリー上で再現・修正後の動作を確認した（jqクラッシュの再現・修正後の非クラッシュ、
cursor.jsonが0バイトへ壊れないこと、フィンガープリント不一致検知の動作、を個別に手動確認）。
単体テストは全120件`failures=0`で再度確認した。

### 5. 配布gitignore是正

`.claude/skills/apply-mr-workflow-to-project/scripts/install-to-project.sh`の`ignore_rules`配列
（既存3要素）へ`/usage/`を追加した。`test_install_to_project.sh`へ、配布先`.gitignore`に
`/usage/`が1行入ることを固定するテストケースを1件追加した。

```
$ bash .claude/scripts/test/test_install_to_project.sh
passed=24 failures=0   # 既存23ケース＋新規1ケース
```

> **結論**: 配布先でも`usage/`配下（対応工数レポートの作業状態・テレメトリのoutfile）が
> Git管理対象外になる。

### 6. 全体検証

```
$ bash .claude/scripts/src/sync-gemini-assets.sh --check
.gemini/ は .claude/ と同期しています。
$ for f in .claude/scripts/test/test_*.sh; do bash "$f"; done
（全17ファイル、すべて failures=0）
```

`git diff <ブランチ分岐点SHA> -- .claude/`の削除行を確認し、DDR/spec本文のpoint-in-time記録を
破壊する削除が無いことを確認した。

## 確かめられなかったこと

> **この結果が言っていないこと**
>
> - 実機（Gemini CLI）でのテレメトリ出力を1度も観測していない。属性キー名
>   （`gen_ai.request.model`・`gen_ai.usage.*`）、レガシー/semantic両形式の実在、
>   pretty-print出力の列0`}`という境界判定方式が実データと一致するかはすべて未検証
>   （フェーズ2調査結果の記載を踏襲した推測）。上記「実施した内容と結果」の単体テストは、
>   この推測を前提に作った合成フィクスチャに対する検証であり、実データに対する正しさを
>   示すものではない。
> - outfileが実際に長時間・大量に追記され続けた場合の性能特性（ファイルサイズが数百MB〜GB
>   規模になった場合の`wc -c`・`tail -c`・`grep`・`cksum`の所要時間）は測っていない。
> - `enabled: false`固定のため、有効化した状態でのエンドツーエンドの動作
>   （Gemini CLI起動→outfile書き込み→push集計→レポート反映の一連）は未検証。

## 設計への反映

1. 上記の未検証事項（属性名・境界判定方式）は、実機確認が得られ次第
   `.claude/docs/spec/`（新規specまたは`otel-listener.md`への追記）へ反映し、推測である旨の
   注記を外す。反映が無い場合も、フェーズ4（flow-id 4-6）で「未検証のまま」であることを
   spec側に明記する。
2. `enabled`の有効化手段（利用者への案内、または既定有効化の是非）は本issueのスコープ外の
   未決定事項として、DDRまたはspecの「未決定事項」節に記録する。現時点で有効化手段が
   存在しないことも明記する。
3. バイトオフセット境界判定方式（列0の`}`）とprefixFingerprint方式（`cksum`）がいずれも
   実装依存であることをDDRへ記録し、Gemini CLI側の出力形式が変わった場合に破損しうる旨を
   明示する。

## 残課題

- 上記「確かめられなかったこと」のうち実機確認が可能なものは、可能になり次第確認しフェーズ4へ
  反映する。
- outfileの性能特性（大規模ファイルでの所要時間）は、実データが得られる段階で計測を検討する。
