---
title: 20260823 Gemini-CLIテレメトリ集計機構の実装結果
type: report
description: issue #105フェーズ3（作業）flow-id 3-6の実施結果。設定層・集計層・レポート層・配布gitignore是正・単体テストの実装内容と検証結果
tags: [gemini-cli, telemetry, usage-report, issue-105]
keywords: [sync-gemini-assets, UsageTracking, post-push-usage-report, byteOffset, install-to-project, 二重計上, テスト]
---

# Gemini CLIテレメトリ集計機構の実装結果（フェーズ3 / flow-id 3-6）

## サマリ（結論の一覧）

| # | やったこと | 結論 | 根拠の性質 |
|---|---|---|---|
| 1 | `.gemini/settings.json`へtelemetryブロックを注入する仕組みを実装 | `sync-gemini-assets.sh`経由で`enabled: false`固定・`target: "local"`・`outfile: "usage/gemini-otel.log"`を注入する形で実装完了 | 実装の確認＋`--check`の前後比較 |
| 2 | バイトオフセットカーソルによるテレメトリ差分集計を実装 | `UsageTracking.sh`へ既存経路と完全独立の関数群（`_sync_usage_state_otel`等）を追加し、正常系・境界またぎ・metrics混在・カーソル継続・初回全量計上・ファイル縮小・状態破損・途中書き込みの8パターンで正しく動作することを確認 | 実装の確認＋単体テスト |
| 3 | 対応工数レポートへのテレメトリ統合 | `post-push-usage-report.sh`へ第6引数`telemetry`を既定値付きで追加し、既存の5引数呼び出しを壊さずに独立した参考値セクションとして統合完了 | 実装の確認＋単体テスト |
| 4 | 配布先`.gitignore`へ`/usage/`の除外を追加 | `install-to-project.sh`の`ignore_rules`へ1行追加し、配布先で反映されることを確認 | 実装の確認＋結合テスト |
| 5 | 既存の集計結果・レポート内容が変化しないこと | Claude Code経路・Gemini CLIセッションログ経路（issue #97）の既存90ケースがすべて無変更で通過 | 単体テストの全件成功 |

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
次の固定値ブロックを追加した。

```jq
+ {
  telemetry: {
    enabled: false,
    target: "local",
    outfile: "usage/gemini-otel.log",
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

<div class="box ok">
<span class="label">結論</span>
telemetry設定は生成物経由で注入され、`--check`による同期検証が通る。手編集による設定ドリフトの
リスクは無い。
</div>

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

9件の単体テストケースを`test_usage_tracking.sh`へ追加し、下記の観点をすべて確認した。

| ケース | 確認内容 | 結果 |
|---|---|---|
| 正常系 | レガシー形式＋semantic形式の対 → semantic形式のみ計上（input=100, calls=1） | OK |
| 境界またぎ2重emit | レガシー形式とsemantic形式が別々の読み取りウィンドウに分かれても二重計上しない（input=200） | OK |
| metrics混在 | metricsレコードがtokens/callsへ現れない | OK |
| カーソル継続 | 1回目後の追記分のみが2回目の差分として計上される（累計120, calls=2） | OK |
| 初回集計 | 有効化前から溜まっていた3件が初回1回のカーソル0集計で全量計上される（calls=3） | OK |
| ファイル縮小 | byte_offsetが0へリセットされ、**縮小前に積んだsinceLastPushは消えず**新しい内容が別モデルキーとして上乗せされる | OK |
| 状態ファイル破損 | cursor.jsonが空文字列でも既定値へ自己回復する | OK |
| 途中書き込み | 列0の`}`で終わらない末尾は今回計上に含めず、完結後の次回集計で拾われる（calls 1→2） | OK |
| レポート本文統合 | 下記「3. レポート層」参照 | OK |

<div class="box warn">
<span class="label">実装過程で見つかった不具合と対処</span>
最初の実装は`jq -R -n 'inputs'`（raw-input）を使っており、複数行にまたがるpretty-print JSON値を
1行ずつ`fromjson`しようとして常に0件になっていた。`-R`を外し`jq -n '[inputs]'`
（ネイティブJSONストリームパーサ）へ変更して解決した。詳細は
`worklog/20260823_squishy-painting-coral_【設計】【実装】【テスト】Gemini-CLIテレメトリ集計機構の実装_push10.md`参照。
</div>

### 3. レポート層: `post-push-usage-report.sh`への統合

`build_usage_report_body()`へ第6引数`telemetry`を`local telemetry="${6:-}"`という既定値付きで
追加し、既存の5引数呼び出し（既存テスト含む）を壊さないようにした。テレメトリ由来の値は
既存のトークンテーブルへ**合算せず**、「### Gemini CLI公式テレメトリ（参考値）」という独立した
セクションとして出す。`telemetry.calls`が0（または`telemetry`自体が空/`null`）の場合は
セクションごと出さない。

`main()`では、`usage/gemini-otel.log`の**存在有無**（`engine`ではなくデータの有無）で
`_sync_usage_state_otel`を呼ぶかどうかを判定し、既存設計方針（列構成はengineではなくデータで
決める）と整合させた。

```
$ bash .claude/scripts/test/test_usage_tracking.sh
passed=112 failures=0   # 既存90ケース＋新規22アサーション
```

第6引数を省略した既存の5引数呼び出し（既存90ケース内で複数回呼ばれる）が無変更で通過することを
もって、既存のClaude Code経路・Gemini CLIセッションログ経路のレポート内容が変化しないことを
確認した。

<div class="box ok">
<span class="label">結論</span>
テレメトリ由来のトークンは、既存の対応工数集計（issue #97のセッションログ由来トークン）とは
独立した参考値として提示され、二重計上は起きない。
</div>

### 4. 配布gitignore是正

`.claude/skills/apply-mr-workflow-to-project/scripts/install-to-project.sh`の`ignore_rules`配列
（既存3要素）へ`/usage/`を追加した。`test_install_to_project.sh`へ、配布先`.gitignore`に
`/usage/`が1行入ることを固定するテストケースを1件追加した。

```
$ bash .claude/scripts/test/test_install_to_project.sh
passed=24 failures=0   # 既存23ケース＋新規1ケース
```

<div class="box ok">
<span class="label">結論</span>
配布先でも`usage/`配下（対応工数レポートの作業状態・テレメトリのoutfile）がGit管理対象外になる。
</div>

### 5. 全体検証

```
$ bash .claude/scripts/src/sync-gemini-assets.sh --check
.gemini/ は .claude/ と同期しています。
$ for f in .claude/scripts/test/test_*.sh; do bash "$f"; done
（全17ファイル、すべて failures=0）
```

`git diff <ブランチ分岐点SHA> -- .claude/`の削除行を確認し、DDR/spec本文のpoint-in-time記録を
破壊する削除が無いことを確認した（削除行2件は、いずれも本セッションで自分が追加した
`sync-gemini-assets.sh`内のコメントの言い換えのみ）。

## 確かめられなかったこと

<div class="box warn">
<span class="label">この結果が言っていないこと</span>
<ul>
<li>実機（Gemini CLI）でのテレメトリ出力を1度も観測していない。属性キー名
（<code>gen_ai.request.model</code>・<code>gen_ai.usage.*</code>）、レガシー/semantic
両形式の実在、pretty-print出力の列0<code>}</code>という境界判定方式が実データと一致するかは
すべて未検証（フェーズ2調査結果の記載を踏襲した推測）。</li>
<li>outfileが実際に長時間・大量に追記され続けた場合の性能特性（ファイルサイズが数百MB〜GB
規模になった場合の<code>wc -c</code>・<code>tail -c</code>・<code>grep</code>の所要時間）は
測っていない。</li>
<li><code>enabled: false</code>固定のため、有効化した状態でのエンドツーエンドの動作
（Gemini CLI起動→outfile書き込み→push集計→レポート反映の一連）は未検証。</li>
</ul>
</div>

## 設計への反映

1. 上記の未検証事項（属性名・境界判定方式）は、実機確認が得られ次第
   `.claude/docs/spec/`（新規specまたは`otel-listener.md`への追記）へ反映し、推測である旨の
   注記を外す。反映が無い場合も、フェーズ4（flow-id 4-6）で「未検証のまま」であることを
   spec側に明記する。
2. `enabled`の有効化手段（利用者への案内、または既定有効化の是非）は本issueのスコープ外の
   未決定事項として、DDRまたはspecの「未決定事項」節に記録する。
3. バイトオフセット境界判定方式（列0の`}`）が実装依存であることをDDRへ記録し、Gemini CLI側の
   出力形式が変わった場合に破損しうる旨を明示する。

## 残課題

- flow-id 3-7（commit/push）以降、フェーズ3の作業実施時敵対的レビューを1回実施し、指摘へ対応する。
- 上記「確かめられなかったこと」のうち実機確認が可能なものは、可能になり次第確認しフェーズ4へ
  反映する。
