---
title: 【設計】【実装】【テスト】Gemini CLIテレメトリ集計機構の実装
type: plan
description: issue #105フェーズ3の個別作業計画。フェーズ2調査結果に基づき、.gemini/settings.jsonへのtelemetry設定注入、バイトオフセットカーソルによる差分集計ロジック、対応工数レポートへの反映、単体テストを実装する
tags: [gemini-cli, telemetry, usage-report, issue-105, implementation]
keywords: [telemetry, outfile, バイトオフセットカーソル, sync-gemini-assets, UsageTracking, 重複排除, install-to-project, 単体テスト]
---

# 【設計】【実装】【テスト】Gemini CLIテレメトリ集計機構の実装

## 前提（合意状況）

- 上位計画: `plans/squishy-painting-coral.md`（全体作業計画、flow-id 1-5で合意）。
- 直接の根拠: `reports/20260823_squishy-painting-coral_Gemini-CLIテレメトリ出力形式と統合方針の
  調査結果.md`（フェーズ2、flow-id 2-9で人間レビュー完了・「レビューOK」の合図を受領済み）。
  同reportの8方針・受け入れ条件9項目対応表をそのまま設計の出発点とする。
- 依拠する既存実装・DDR: issue #97（`_usage_gemini_fold`系、DDR i0097-01〜05）、issue #103
  （`.claude/hooks/otel/`、`.claude/docs/spec/otel-listener.md`）、issue #70/PR #157
  （`.gemini/`を`.claude/`からの変換生成物へ改めた変更。**本計画作成時点でdefaultブランチ追従に
  よりこのブランチへ取り込み済み**）。
- **本計画作成にあたり、事前調査エージェント（Explore、読み取り専用）で
  `.claude/hooks/lib/UsageTracking.sh` / `.claude/hooks/post-push-usage-report.sh` /
  `.claude/scripts/test/test_usage_tracking.sh` / `.gemini/settings.json` /
  `.claude/scripts/src/sync-gemini-assets.sh` / `.gitignore` /
  `.claude/docs/spec/otel-listener.md` / DDR i0097-01 を確認した。**その結果、フェーズ2報告
  作成時点では想定していなかった重要な制約が新たに判明した（下記「フェーズ2報告からの更新点」）。

### フェーズ2報告からの更新点（重要）

フェーズ2報告5.節・6.節・7.節は、`.gemini/settings.json`を**手で編集するファイル**という前提で
書かれていた。しかし、defaultブランチ追従で取り込んだPR #157（issue #70）により、**`.gemini/`は
`.claude/`からの変換生成物になっている**（`bash .claude/scripts/src/sync-gemini-assets.sh`が
`.gemini/`全体を再生成する。手で`.gemini/settings.json`を編集しても次回生成で失われる）。

`sync-gemini-assets.sh`の`convert_settings()`は`.claude/settings.json`をjqフィルタ
（`SETTINGS_JQ_FILTER`）で変換して`.gemini/settings.json`を作る。ここには**Claude Code側に
存在しない設定（`telemetry`）を注入する仕組みが無い**。加えて`SETTINGS_IGNORED_KEYS`の
`env`キーには「Gemini CLIのtelemetryブロックへ、Claude Code側のOTelリスナー
（`.claude/hooks/otel/listener.pl`）由来の値を流すと壊れるため意図的に変換しない」という
既存の設計判断が明記されている。

**本計画のtelemetry注入は、この既存判断と衝突しない。** 理由: (1) Claude Code側の`env`ブロック
（`CLAUDE_CODE_ENABLE_TELEMETRY`等）は一切参照しない。(2) 注入する`telemetry.target`は
`"local"`固定であり、`.claude/hooks/otel/listener.pl`のようなOTLPネットワーク受信は経由しない
（Gemini CLIが`outfile`へ直接ファイル書き込みする）。(3) 既存の`SETTINGS_IGNORED_KEYS`は
「変換しないキー」の記録であり、「新規キーを固定値で追加すること」を妨げない。

## この計画で何をするか

フェーズ2報告の8方針を、以下の3層で実装する。

1. **設定層**: `sync-gemini-assets.sh`（生成ロジック）を変更し、生成される
   `.gemini/settings.json`へ`telemetry`ブロックを固定値で注入する。
2. **集計層**: `UsageTracking.sh`へ、バイトオフセットカーソル方式の新規集計関数群を追加する。
3. **レポート層**: `post-push-usage-report.sh`へ、テレメトリ由来の値を別セクションとして
   追加する呼び出しを組み込む。

あわせて、配布時の`.gitignore`追記漏れ（フェーズ2報告7.節）を是正する。

## 変更対象

| ファイル | 変更内容 |
|---|---|
| `.claude/scripts/src/sync-gemini-assets.sh` | `SETTINGS_JQ_FILTER`（または専用の後処理関数）へ`telemetry`ブロックの固定注入を追加。`--check`/`--dry-run`との整合を確認 |
| `.claude/docs/spec/sync-gemini-assets.md` | 上記変更の仕様反映（フェーズ4で実施。本計画では変更しない） |
| `.claude/hooks/lib/UsageTracking.sh` | 新規関数群を追加（下記「方針」参照）。既存のClaude Code経路・Gemini経路（セッションログ）の関数は変更しない |
| `.claude/hooks/post-push-usage-report.sh` | テレメトリ集計の呼び出しと、レポート本文への別セクション追加 |
| `.claude/scripts/test/test_usage_tracking.sh` | 新規関数群の単体テストを追加（実jqをフィクスチャへ直接適用する既存方式に合わせる） |
| `.claude/skills/apply-mr-workflow-to-project/scripts/install-to-project.sh` | 配布先`.gitignore`への`/usage/`追記漏れを是正 |
| `.gitignore`（本リポジトリ自身） | 変更不要（`/usage/`が既にテレメトリ出力先・カーソル状態ファイルの両方をカバーする。事前調査で確認済み） |

## 方針

### 1. `.gemini/settings.json`への`telemetry`注入

`sync-gemini-assets.sh`の`SETTINGS_JQ_FILTER`（jq文字列）の末尾、最終的な出力オブジェクトを
組み立てる箇所へ、次の値を固定で追加する。

```json
{
  "telemetry": {
    "enabled": true,
    "target": "local",
    "outfile": "usage/gemini-otel.log",
    "logPrompts": false
  }
}
```

- `enabled: true`はフェーズ2報告7.節の判定を**この時点では反映しない**（後述「やらないこと」）。
  暫定的に`enabled: false`（既定と同じ、変更なし）から始め、7.節の2条件（配布先gitignore是正・
  tool_call機微情報確認）が揃うまでは、telemetryブロックの他のキー（`target`/`outfile`/
  `logPrompts`）だけを用意しておき、利用者が`enabled`を手動で`true`にする運用とする。
  **理由**: フェーズ2報告7.節の結論は「保留」であり、実機確認前に既定ONへ倒すのはその結論と
  矛盾する。
- `outfile`は相対パス`usage/gemini-otel.log`とする。フェーズ2報告3.節の残課題
  （相対パス解決基準が未確認）を踏まえ、**実機確認で問題が判明したら絶対パスへ変更する**ことを
  spec側の未決定事項として記録する（フェーズ4）。
- `--check`（生成物と一致するかの検証）・`--dry-run`（差分表示）が新しいキーを正しく検出することを、
  本計画の検証節で確認する。

### 2. バイトオフセットカーソル集計（`UsageTracking.sh`への追加）

フェーズ2報告4.節の設計をそのまま実装する。新規関数（案、実装時に命名を調整してよい）:

- `_usage_read_otel_cursor(repo_root)`: `usage/state/gemini-otel-cursor.json`を読む。
  空・不正JSON・ファイル無しなら`{"byteOffset": 0}`を返す（`_usage_read_gemini_totals`と
  同じ自己回復パターンを踏襲。事前調査で確認した既存の`[ -n "$content" ] && jq -e .`方式）。
- `_usage_write_otel_cursor(repo_root, byte_offset)`: 上記ファイルへ`{"byteOffset": <数値>}`を
  書く。
- `_usage_otel_fold(outfile_path, byte_offset)`: `outfile_path`の`byte_offset`以降を読み、
  **完全にパースできた末尾までのJSON値だけ**を対象にする（途中書き込み対応）。各JSON値のうち
  LogRecord形式のものだけを`gemini_cli.api_response`相当の属性で判定し、以下を行う。
  1. **metricsの除外**（フェーズ2報告の追加確認: `PeriodicExportingMetricReader`により
     10秒間隔で周期exportされるため、集計対象に含めない）。
  2. **同一イベントの2重emit（`toLogRecord`/`toSemanticLogRecord`）の重複排除**（フェーズ2報告の
     追加確認: 常に無条件で2回emitされる）。判定キーの具体案は下記「未決定事項」参照。
  3. 新しく完全パースできたバイト位置と、トークン種別ごとの合計・呼び出し回数を返す。
- ファイル縮小検知（DDR i0097-01の`needsReset`と同じ考え方）: 現在のファイルサイズが
  `byteOffset`より小さければ、カーソルを0へ戻してから読み直す。
- `_sync_usage_state_otel(repo_root, branch, outfile_path)`: 上記を組み合わせ、
  `usage/state/gemini-otel-cursor.json`（グローバル、ブランチ・セッション非依存。
  フェーズ2報告5.節の判断どおり）を読み書きし、今回pushでの差分（トークン合計・呼び出し回数）を
  返す。**既存の`sync_usage_state`（Claude Code経路・Gemini経路）とは完全に独立した関数**とし、
  既存関数のシグネチャ・返り値は一切変更しない（受け入れ条件4「既存の集計結果・レポート内容が
  変化しない」ことをコードレベルで保証するため）。

### 3. `post-push-usage-report.sh`への統合

- `main`関数内、`engine`が`"gemini"`のときに限り`_sync_usage_state_otel`を追加で呼び出す
  （既存の`sync_usage_state`呼び出しとは**別の呼び出し**とし、既存の`state`変数・
  `build_usage_report_body`への既存引数は変更しない）。
- `build_usage_report_body`へ新しい引数（テレメトリ集計結果）を追加し、値が存在する場合のみ
  「### Gemini CLI公式テレメトリ（参考値）」セクションを追加する（既存の「0件なら出さない」
  規約に従う）。**既存のトークンテーブル（`tokensByModel`）へは合算しない**（フェーズ2報告5.節、
  受け入れ条件2・3の核心）。
- `outfile_path`（`usage/gemini-otel.log`）が存在しない場合（テレメトリ未設定の利用者）は、
  何もせず既存の動作のまま終了する。

### 4. 配布gitignore是正

`install-to-project.sh`の`ignore_rules`配列（現状`/.claude/usage-state/`
`/.claude/session-logs/`という旧パス名）に、`/usage/`を追加する。**既存の2行は削除しない**
（旧パス名を使っていた過去の配布先との互換性のため。削除の要否はフェーズ4で別途判断する）。

### 5. テストフィクスチャ

フェーズ2報告のテストフィクスチャ方針（1.節「テストフィクスチャの妥当化方法」）に従い、
`safeJsonStringify(data, 2) + '\n'`形式（pretty-print、改行区切り）を模した固定文字列を
`test_usage_tracking.sh`内にヒアドキュメントで直接記述する（既存の`gm_dir/main.jsonl`と同じ
パターン）。少なくとも以下のケースを含める。

- 正常系: `gemini_cli.api_response`のLogRecordが2重emit（レガシー形式＋semantic conventions
  形式）された状態で、重複排除後のトークン数が1回分になること。
- metrics混在: ResourceMetrics相当の値が同じファイルに混在していても、集計対象から除外され
  トークン数へ影響しないこと。
- カーソル継続: 2回目の呼び出しで、前回処理済みバイト以降だけが新規として計上されること。
- ファイル縮小: ファイルサイズがカーソル値より小さい場合、カーソルが0へリセットされ、
  縮小後のファイル全体が再集計されること。
- 状態ファイル破損: 空・不正JSONの状態ファイルから、既定値（`{"byteOffset": 0}`）へ
  自己回復すること。
- 途中書き込み: 末尾が不完全なJSON（閉じ括弧が無い等）の場合、その部分を除いた完全な値までを
  処理し、カーソルがその手前で止まること。
- `post-push-usage-report.sh`のレポート本文テスト: テレメトリ集計結果がある場合・無い場合の
  両方で、既存のClaude Code/Gemini経路（セッションログ）のセクションが変化しないこと
  （受け入れ条件4の直接的な検証）。

## やらないこと（スコープ外）

- `telemetry.enabled`を既定`true`にすること（フェーズ2報告7.節の判断どおり、2条件
  ＝配布gitignore是正・tool_call機微情報確認が揃うまで見送る。本計画は前者のみ対応し、後者は
  人間への実機確認依頼に含める）。
- `GEMINI_TELEMETRY_OUTFILE`環境変数を使った起動ラッパーの新設（issue #103のような日次
  ローテーション整合。フェーズ2報告3.節・8.節で「将来の拡張」として明記済み）。
- `.claude/hooks/otel/listener.pl`（Claude Code側OTelリスナー）の変更・Gemini由来テレメトリの
  受け入れ（`sync-gemini-assets.sh`の既存コメントが明示的に対象外としている）。
- `outfile`の相対パス解決基準の実機確認（人間への依頼事項とする。フェーズ2報告3.節「残課題」）。

## 検証

```bash
# 1. sync-gemini-assets.sh がtelemetryブロックを注入し、--checkが通ること
bash .claude/scripts/src/sync-gemini-assets.sh
jq -e '.telemetry.target == "local" and .telemetry.outfile == "usage/gemini-otel.log"' \
  .gemini/settings.json
bash .claude/scripts/src/sync-gemini-assets.sh --check

# 2. 単体テスト全件が通ること（既存17本＋今回追加分）
for t in .claude/scripts/test/test_*.sh; do bash "$t" || echo "FAILED: $t"; done

# 3. 既存のClaude Code経路・Gemini経路（セッションログ）のテストケースが1件も変化しないこと
#    （test_usage_tracking.sh の既存ケース番号・アサーション文言をdiffで確認）
git diff --stat .claude/scripts/test/test_usage_tracking.sh

# 4. install-to-project.sh の配布gitignoreに /usage/ が追加されていること
grep -F -- '/usage/' .claude/skills/apply-mr-workflow-to-project/scripts/install-to-project.sh
```

合格条件: 上記4項目すべてが成功し、`test_usage_tracking.sh`が`passed=N failures=0`（Nは既存90件
＋新規テスト件数）を返すこと。

## issueの受け入れ条件との対応

| 受け入れ条件 | この計画での対応 |
|---|---|
| 1. telemetry設定によりusage/配下へファイルが生成・追記される | 設定層（方針1）で用意。実機生成確認は人間への依頼事項（本計画では実装のみ） |
| 2. テレメトリ由来の集計値が対応工数レポートへ載り差分が二重計上されない | 集計層・レポート層（方針2・3）＋テスト（方針5の重複排除ケース） |
| 3. issue #97実装のセッションログ集計とテレメトリ集計が二重計上にならない | 集計層（方針2、既存関数と完全独立）＋テスト（レポート本文テスト） |
| 4. Claude Code側の集計結果・レポート内容が変化せず既存テストが通る | 方針2「既存関数のシグネチャ・返り値は一切変更しない」＋検証節3 |
| 5. `.gemini/settings.json`がTelemetrySettingsスキーマに沿っている | 方針1（フェーズ2報告2.節のスキーマに準拠） |
| 6. `logPrompts`の既定・出力先がgitignore対象であることが明記されている | 方針1（`logPrompts: false`固定）・方針4（配布gitignore是正） |
| 7. 出力先配置がissue #103と整合している、または理由が記録されている | フェーズ2報告3.節で記録済み（本計画は変更しない） |
| 8. 設計判断がDDRとして記録されている | フェーズ4の対象（本計画では実施しない） |
| 9. 仕様がspecに記録されている、実機検証できない範囲は「未検証」と明示されている | フェーズ4の対象（本計画では実施しない） |

## 未決定事項（レビューで確認したいこと）

- **2重emitの重複排除キー**: `event.name`＋`model`＋`duration_ms`の組をキーとする案と、
  semantic conventions形式（`toSemanticLogRecord`）のみを採用しレガシー形式を無視する案の
  どちらを採るか。後者は実装が単純だが、実データでの2形式の判別方法（属性の形の違い）を
  実機確認前に確定できない。**本計画では両案を実装コメントに残し、実機確認結果（人間への依頼
  項目5）を見てフェーズ3のレビュー往復で確定する**ことを提案する。
- **LogRecordとmetricsの判別方法**: 事前調査でも実データを見られていないため、判別ロジックの
  具体的なjqフィルタはレビュー往復（3-6〜3-9）の中で実データ（人間からの実機確認結果）を
  踏まえて調整する前提とする。
