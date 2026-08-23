---
title: Gemini CLIテレメトリ出力形式と統合方針の調査結果
type: report
description: issue #105フェーズ2の調査結果。公式ソース（google-gemini/gemini-cli mainブランチ）を直接確認し、出力形式・settings.jsonスキーマ・出力先配置・差分カーソル単位・二重計上回避・logPrompts・既定有効化・ローテーションの8項目について判断根拠を記録する
tags: [gemini-cli, telemetry, usage-report, issue-105, investigation]
keywords: [OpenTelemetry, outfile, FileSpanExporter, FileLogExporter, FileMetricExporter, TelemetrySettings, logPrompts, LogRecord, バイトオフセットカーソル, 二重計上, ローテーション]
---

# Gemini CLIテレメトリ出力形式と統合方針の調査結果

対応する計画: `plans/【調査】Gemini-CLIテレメトリ出力形式と統合方針.md`（flow-id 2-6）

## 実機検証可否の判定

```bash
command -v gemini
echo "exit=$?"
```

この実行環境（Claude Code on the webのリモート実行環境）には`gemini`コマンドが存在しない
（実行結果: `exit=1`）。**Gemini CLI本体を起動した実機検証は実施できない。**

代替として、**Gemini CLI本体の公式ソースコード**（`google-gemini/gemini-cli`、GitHub `main`ブランチ、
参照時点2026-08-23）を**WebSearch/WebFetchツール経由で**確認した。実機起動による動作確認は
未検証のまま。

**調査手法についての注記（重要）**: WebFetchはページ内容を小さく速いモデルが要約して返す仕組みで
あり、ソースコードを直接目視したものではない。本reportで「引用」と書いている箇所は、WebFetchが
返した引用（要約段階での言い換え・省略のリスクがある）であって、リポジトリを`git clone`して
直接読んだ逐語引用ではない。重要な判断（1.のシリアライズ形式・2.のスキーマ配置・3.の環境変数の
存在）は、**同一ファイル・同一質問で2回以上WebFetchを実行し、結果が一致することを確認**した
うえで採用している（1回きりの要約だけに依拠していない）。それでも一次資料そのものではないため、
フェーズ3で実装に落とし込む際は、可能であれば`git clone`等での再確認を推奨する。

## 1. 出力ファイル形式

### 確認したソース

- `docs/cli/telemetry.md`（公式ドキュメント）
- `packages/core/src/telemetry/sdk.ts`
- `packages/core/src/telemetry/file-exporters.ts`
- `packages/core/src/telemetry/loggers.ts`

### 判明した事実

- `outfile`は**単一ファイル固定パス**を指定する。`target: "local"`かつ`outfile`が設定された場合、
  `FileSpanExporter` / `FileLogExporter` / `FileMetricExporter` の3つのエクスポータが、
  **すべて同一の`telemetryOutfile`値で初期化される**（`sdk.ts`より、`config.getTelemetryOutfile()`
  の戻り値を3エクスポータ共通で渡している）。つまり**spans・logs・metricsが1つのファイルへ混在して
  追記される**。
- `file-exporters.ts`のコンストラクタは `fs.createWriteStream(filePath, { flags: 'a' })` で
  ファイルを**追記モード**で開く。
- シリアライズは `safeJsonStringify(data, 2) + '\n'`（インデント2のpretty-print JSON文字列＋末尾
  改行1つ）。**「1行1JSON」ではない。** 各エントリは複数行にわたるインデント付きJSONで、区切りは
  各エントリ末尾の改行1つのみ。ファイル全体は「複数のJSON値が連続して並ぶストリーム」になる
  （`jq -n 'inputs'`のようなホワイトスペース区切りの複数JSON値パーサで読める設計。厳密な検証は
  フェーズ3で実データ・フィクスチャに対して行う）。
- ローテーション実装は**`file-exporters.ts`には見当たらない**（確認したのはこの1ファイルのみ。
  `sdk.ts`側のファイルパス決定・起動時の初期化処理までは追えていないため、「Gemini CLI全体に
  ローテーション機構が無い」と断定はできない。この前提が崩れた場合は3.・8.の判断も再検討が
  必要）。
- `gemini_cli.api_response`イベントは**OpenTelemetryのLogRecord**として記録される
  （`loggers.ts`で`logger.emit(event.toLogRecord(config))` / `logger.emit(event.toSemanticLogRecord
  (config))`。Spanのイベント（`span.addEvent`）ではない）。属性には `model` / `status_code` /
  `duration_ms` と、`input_token_count` / `output_token_count` / `cached_content_token_count` /
  `thoughts_token_count` / `tool_token_count` の各トークン種別が含まれる（`loggers.ts`の
  `tokenUsageData`配列より）。
- **【重要・追加確認】同一イベントが常に2回LogRecordとしてemitされる。** `loggers.ts`の
  `logApiResponse()`を確認したところ、`logger.emit(event.toLogRecord(config))` と
  `logger.emit(event.toSemanticLogRecord(config))` は**条件分岐を挟まず無条件に両方とも
  呼ばれる**（レガシー形式＋semantic conventions形式を両方出力する設計）。つまり1回のAPI応答に
  つき、`gemini_cli.api_response`相当のLogRecordが**ファイル中に2エントリ現れる**。素朴に
  「`gemini_cli.api_response`という名前のレコードを全部数える」と、トークン数が2倍になる
  （受け入れ条件2・3の二重計上回避に直結する制約。4.・5.で対処方針を示す）。
- **【重要・追加確認】metricsは10秒間隔で周期的にexportされ、1回のemitで完結しない。** `sdk.ts`を
  確認したところ、`FileMetricExporter`は`PeriodicExportingMetricReader`
  （`exportIntervalMillis: 10000`）と組み合わせて登録されている。OpenTelemetryのメトリクスは
  既定でcumulative temporality（累計値）を持つため、同じカウンタの累計値が10秒ごとに
  繰り返し出力される可能性が高い。**metricsをそのまま合算対象に含めると、10秒間隔の回数分だけ
  同じトークン数を重複加算する。** 対処方針は4.に記す。
- `session.id`属性がresource属性かlog属性かは、`loggers.ts`単体からは確定できなかった
  （`event.toOpenTelemetryAttributes(config)`内で処理されており、この関数の実装までは追えて
  いない。**未確認**）。

### テストフィクスチャの妥当化方法

上記のシリアライズ形式（`safeJsonStringify(data, 2) + '\n'`。1.「判明した事実」で確認した
表記そのもの。以前の草稿では`serialize()`/`JSON.stringify(payload, null, 2)`という別表記で
書いていたが、実際に確認できたのは`safeJsonStringify`の呼び出しのみであり、`JSON.stringify`と
出力が完全に一致する保証は無いため、この節でも同じ表記へ統一する）を根拠に、フェーズ3の
テストフィクスチャは以下の方針で作成する。

- 各エントリはOpenTelemetry JS SDKの`ReadableLogRecord` / `ReadableSpan` /
  `ResourceMetrics`型のJSON表現を模した構造とする（正確なフィールド名は実データが無いため、
  OpenTelemetry JS SDKの型定義・`docs/cli/telemetry.md`のサンプル出力を参考にする）。
- ファイル全体は「複数のpretty-print JSON値が改行区切りで連続する」形式とし、jqでの読み込み方式
  （`inputs`によるストリーム読み込み）が正しく機能することを、まず最小のフィクスチャで単体検証
  してからテスト本体へ組み込む。
- **この段階のフィクスチャは推測に基づく**ため、フェーズ3実装時・フェーズ5（またはレビュー往復）で
  実機出力との突き合わせが取れ次第、フィクスチャを実データへ差し替える。差し替えるまでの間、
  spec・DDRに「フィクスチャは公式ソースコードからの推測であり実機出力での確認は未検証」と明示する。

### 受け入れ条件1（telemetry設定によりusage/配下へファイルが生成・追記される）の扱い

この実行環境では実機起動できないため、条件1の**実際の生成確認は本フェーズでは行えない**。
以下のいずれかを人間へ依頼する必要がある。

- (a) 人間のローカルGemini CLI環境で`telemetry.enabled: true` / `target: "local"` /
  `outfile: <パス>`を設定して1回実行し、出力ファイルが生成されることを確認してもらう。
- (b) 条件1の実機確認をフェーズ3のレビュー往復（3-8/3-9）またはフェーズ5への持ち越しとして
  記録する。

**本reportでは(b)を採用し、フェーズ3の個別作業計画に「受け入れ条件1の実機確認は人間へ依頼する」
と明記することを推奨する。** 依頼する際は、次の情報を具体的に採取してもらう（1回の実機実行で
本reportの結論の大半を検証できる見込み）。

1. `gemini --version`の出力（バージョン）。
2. 使用した`.gemini/settings.json`の`telemetry`部分（フェーズ3で追加する設定そのもの）。
3. 出力ファイルの**先頭2〜3エントリ**（プロンプト本文等の機微情報が含まれる場合は伏せてもらう。
   `.claude/rules/shell-script-style.md`「秘密情報の扱い」の方針に従う）。
4. 出力ファイルの`wc -c`（バイト数）と、含まれるJSON値の個数（`jq -n '[inputs] | length'`等）。
5. 同一の`gemini_cli.api_response`イベント（同じ`model`/`duration_ms`の組）が、レガシー形式・
   semantic conventions形式の**2エントリとして現れているか**（上記「判明した事実」で確認した
   常時2重emitが実データでも成立するかの裏取り）。
6. `outfile`に相対パスを指定した場合、実際にファイルが作られる場所（cwd基準かプロジェクト
   ルート基準か。3.の判断に影響する）。
7. `logPrompts: false`のまま、ツール呼び出し（`tool_call`相当のイベント）を1回発生させた際の
   出力に、ファイルパス・シェルコマンド・編集内容の断片等の機微情報が残るか（7.の既定ON可否の
   判断材料）。

## 2. `.gemini/settings.json`のスキーマ確認（受け入れ条件5）

### 確認したソース

- `packages/cli/src/config/settingsSchema.ts`
- `docs/cli/telemetry.md`

### 判明した事実

`settingsSchema.ts`で`telemetry`キーは次のように定義されている（引用）。

```typescript
telemetry: {
  type: 'object',
  label: 'Telemetry',
  category: 'Advanced',
  requiresRestart: true,
  default: undefined as TelemetrySettings | undefined,
  description: 'Telemetry configuration.',
  showInDialog: false,
  ref: 'TelemetrySettings',
}
```

**`telemetry`は`.gemini/settings.json`の トップレベルキー**であり、`general`配下ではない
（現行の`.gemini/settings.json`が持つ`general.plan.directory`とは別の階層）。

`docs/cli/telemetry.md`が示すキー一覧（`telemetry`オブジェクト直下）:

| キー | 型 | 既定値 | 備考 |
|---|---|---|---|
| `enabled` | boolean | `false` | テレメトリの有効/無効 |
| `traces` | boolean | `false` | 詳細属性トレーシング |
| `target` | `"local"` \| `"gcp"` | `"local"` | 送信先 |
| `otlpEndpoint` | string | `http://localhost:4317` | OTLPコレクタエンドポイント（`useCollector`利用時等） |
| `otlpProtocol` | `"grpc"` \| `"http"` | `"grpc"` | 転送プロトコル |
| `outfile` | string | （なし） | ファイル出力パス |
| `logPrompts` | boolean | `true` | プロンプト本文をログに含めるか |
| `useCollector` | boolean | `false` | 外部OTLPコレクタを使うか |
| `useCliAuth` | boolean | `false` | GCP向けCLI認証情報の利用 |

`TelemetrySettings`型自体の完全なフィールド定義（`packages/core/src/telemetry/types.ts`は
別の型セット（`BaseTelemetryEvent`等イベント型）であり見つからなかった）は未確認だが、
`docs/cli/telemetry.md`の設定例JSONと`settingsSchema.ts`のトップレベル配置により、本issueの
判断に必要な範囲（キー名・ネスト位置・型・既定値）は確認できた。

設定例（`docs/cli/telemetry.md`より引用）:

```json
{
  "telemetry": {
    "enabled": true,
    "target": "local",
    "outfile": ".gemini/telemetry.log"
  }
}
```

**判定**: 既存の`.gemini/settings.json`のキー（`general.plan.directory`, `hooks`）と衝突しない。
`telemetry`をトップレベルへ追加すればよい。

## 3. 出力先配置の比較（受け入れ条件7）

issue #103（Claude Code側OTelリスナー）は`usage/claude-otel-YYYYMMDD.jsonl`という**日次
ローテーション命名**を持つが、これは常駐perlリスナー自身が受信時刻に基づいてファイルを切り替える
ことで実現している（`.claude/docs/spec/otel-listener.md`）。

一方Gemini CLI側の`outfile`は、1.で確認したとおり`.gemini/settings.json`では**単一ファイル固定
パス**である。ただし、`.gemini/settings.json`が静的だからといって`outfile`自体が完全に固定される
わけではない。`docs/cli/telemetry.md`（設定リファレンス）には「Environment variables can
override these settings」という記載があり、対応する環境変数として`GEMINI_TELEMETRY_OUTFILE`
（および`GEMINI_TELEMETRY_ENABLED`等、telemetryの各設定キーに対応する`GEMINI_TELEMETRY_*`環境
変数群）が明記されている。**Gemini CLI起動をラップして`GEMINI_TELEMETRY_OUTFILE`を都度設定すれば、
起動のたびに動的な（日付入り等の）パスを渡すことが技術的には可能**であり、当初の「settings.json
が静的だから動的パスを渡せない」という判断は誤りだった。

とはいえ、この経路を採用するには次の条件が要る。(a) Gemini CLIの起動そのものを本機構側の
ラッパースクリプトが仲介していること（現状、そのようなラッパーは存在しない。利用者が直接
`gemini`コマンドを叩く運用のため、環境変数を都度注入する仕組みが無い）。(b) 環境変数の実際の
効果（`.gemini/settings.json`の値を上書きするか、そもそも読み取られるタイミング）は実機未検証
であること。

**判定: 環境変数経由の動的パス注入は技術的に可能だが、現時点でそれを行う仕組み（起動ラッパー）が
本リポジトリに無いため、フェーズ3では`.gemini/settings.json`による**固定ファイル名**
（`usage/gemini-otel.log`）を採用する。** issue #103のような日次ファイル分割は、Gemini CLI起動
ラッパーを新設する将来の拡張として残す（8.のローテーション方針とあわせてDDRの未決定事項に
記録する）。この判断はDDRへ「`GEMINI_TELEMETRY_OUTFILE`環境変数により動的パス注入自体は可能だが、
起動ラッパーが無いため当面は固定ファイル名を採用し、issue #103の日次命名パターンとは整合させ
ない」として記録する。

**残課題（未確認）**: `outfile`に相対パスを指定した場合、Gemini CLIがそれを何を基準に解決
するか（プロセスのcwd／プロジェクトルート／`~/.gemini`）は、`docs/cli/telemetry.md`にも
記載が無く未確認。cwd基準だった場合、リポジトリのサブディレクトリから`gemini`を起動すると
`<subdir>/usage/gemini-otel.log`のような意図しない場所へファイルが作られ、(1)集計側が空の
ファイルを見続ける、(2)`/usage/`の`.gitignore`（先頭スラッシュ＝ルート限定）の対象外となり
野良ファイルがコミット候補に現れる、という2つの問題が起こりうる。フェーズ3で実機確認するか、
確実性を優先するなら**絶対パス**（リポジトリルートからの絶対パス）を`outfile`へ指定することを
検討する。

## 4. 差分カーソル単位の判定

1.で確認したとおり、出力ファイルは「単一ファイル・追記型・spans/logs/metrics混在・各エントリが
複数行にわたるpretty-print JSON（区切りは末尾改行のみ）」という性質を持つ。

- **Claude Code経路の行カーソル方式（`lastLineCount`）は使えない**: 1エントリが複数行にまたがる
  ため、「行数」という単位そのものが意味を持たない。
- **Gemini CLIセッションログ経路の「ファイル全体を毎回`id`単位で畳み込む」方式（DDR i0097-01）も
  適さない**: セッションログは同一`id`のメッセージが後埋め・再送されるためこの方式を採ったが、
  テレメトリの**LogRecord**（`gemini_cli.api_response`等）は一度emitされたら不変であり、後から
  同じレコードが更新されて再出力されることは無い（`loggers.ts`の実装は、都度新しいイベントを
  `logger.emit()`するだけで、既存レコードの更新は行わない）。**ただしこれはlogsに限った性質で
  あり、metricsには当てはまらない**（後述のとおりmetricsは10秒間隔で周期的にexportされるため、
  「一度emitされたら再出力されない」という前提が崩れる）。
- **推奨方式: バイトオフセットカーソル。** 前回処理した末尾のバイト位置を状態ファイルへ記録し、
  次回はそこ以降の新規バイトだけを読んで、複数のJSON値としてパースする（`jq -n 'inputs'`のような
  ホワイトスペース区切りの複数JSON値読み込みが利用できる見込み。フェーズ3で実装・検証する）。
  各**LogRecord**は一度しか出力されないため、この方式なら「読み直しによる」二重計上は起きない
  （Claude Code経路の行カーソルと同じ「一度数えた範囲は二度と数え直さない」原則が成り立つ）。
  ただし「一度しか出力されない」が成り立つのはlogsだけで、**metricsは1.で確認したとおり10秒
  間隔で周期的にexportされる**ため、バイトオフセットカーソルで新規バイトを追うだけでは
  metrics由来の重複加算を防げない。**フェーズ3の実装では、集計対象を`gemini_cli.api_response`
  由来のLogRecordのみに限定し、metricsのレコード種別は集計対象から除外する。**
  レコード種別の判別は、各JSON値が持つ属性の形（LogRecordなら`body`/`attributes`、
  ResourceMetricsなら`scopeMetrics`等の構造の違い）で行う想定だが、正確な判別キーは実データ
  取得後（残課題「未検証・残課題」参照）にフェーズ3で確定する。
- **推奨方式（重複排除）**: 1.で確認したとおり、1回のAPI応答につき`toLogRecord`（レガシー形式）と
  `toSemanticLogRecord`（semantic conventions形式）の**2つのLogRecordが常に無条件でemitされる**。
  同じイベントを2重に数えないよう、フェーズ3の集計ロジックは**どちらか一方の形式だけを対象に
  含める**（例: semantic conventions形式のみを採用し、レガシー形式は無視する）か、
  イベントの一意キー（`model`+`duration_ms`+`status_code`等の組、または`event.name`＋属性の
  ハッシュ）で重複排除する。この設計判断（採用する形式・重複排除キー）はDDRへ記録する
  （5.も参照）。
- **カーソル方式の耐障害性（未実装・フェーズ3の必須要件）**: 上記の「新規バイトだけを読む」
  という単純な設計には、次の3つの失敗経路への対処が要る。
  1. **途中書き込み**: 集計時点でGemini CLIがエントリを書きかけていると、末尾が不完全なJSONに
     なりうる。カーソルは「最後に完全にパースできたJSON値の終端」までしか進めない
     （不完全な末尾は次回の集計へ持ち越す）。
  2. **ファイル縮小・差し替え**: 利用者が出力ファイルを削除・掃除すると、ファイルサイズが
     カーソル値より小さくなる。DDR i0097-01の`needsReset`と同じ考え方で、
     「現在のファイルサイズ＜カーソル値」を検知したらカーソルを0へ戻す。
  3. **状態ファイルの破損・空文字列**: `.claude/rules/shell-script-style.md`「JSON操作」が
     要求する自己回復ロジック（空・不正JSONなら既定値へフォールバック）を適用する。
  複数プロセスの同時追記（複数のGemini CLIセッションが同一`outfile`へ並行して書き込む場合の
  原子性）は実機未検証のため、残課題として次節へ記す。

## 5. 二重計上回避方針（受け入れ条件2・3）

セッションログ由来（issue #97、`_usage_gemini_fold`系）とテレメトリ由来は、**入力データソースが
完全に別物**（前者は`~/.gemini/tmp/<hash>/chats/*.jsonl`、後者は`outfile`が指すファイル）であり、
別の状態ファイル（例: `usage/state/gemini-otel-cursor.json`）を持たせる設計にする。

**状態ファイルのスコープ（ブランチ別かブランチ非依存か）**: DDR i0097-01は、Gemini
セッションログの前回累計をブランチ別（`usage/state/<branch>.json`）に置くと、同じセッションの
ままブランチを切り替えたときに蓄積済みの全件が新ブランチの初回差分として再計上されるため、
**ブランチ非依存の`usage/state/gemini-totals/<sessionId>.json`へ移した**という判断をしている。

テレメトリの`outfile`は、1.・3.で確認したとおり`.gemini/settings.json`（リポジトリ共有・
ブランチをまたいで同一）が指す**単一の固定ファイル**であり、セッションログのように
`~/.gemini/tmp/<hash>/`単位でセッションごとに分かれてもいない。つまり複数のブランチ・複数の
Gemini CLIセッションが**同じ1つの`outfile`へ書き込み続ける**ため、i0097-01と同じ理由
（ブランチ切り替えによる過去分の再計上）に加えて、そもそも「このバイト範囲はどのブランチの
作業か」を`outfile`の中身だけから判別する手段が無い（各LogRecordに紐づく`session.id`属性の
所在が未確認であるため、セッション単位の切り分けも現時点ではできない）。

**判定: 状態ファイルは`usage/state/`直下に置くが、i0097-01のセッション別累計とも異なり、
ブランチにもセッションにも紐づかない単一のグローバルなバイトオフセットカーソルとする**
（例: `usage/state/gemini-otel-cursor.json`、内容は`{"byteOffset": <数値>}`のような単純な
値のみ）。push毎の差分集計では「前回push時点のカーソル値」と「現在のカーソル値」の差分を
そのpushの貢献分として扱う想定だが、複数ブランチが同時並行で作業している場合に貢献が
どちらのpushへ計上されるかという曖昧さは残る（この曖昧さの扱いはフェーズ3で確定する）。

既存のトークン列判別ロジック（`thoughts`キーの有無で判定、DDR i0097-03）と衝突させないため、
**当面はテレメトリ由来の値を既存の`tokensByModel`へ合算せず、レポート上の別セクション
（例: 「### Gemini CLI公式テレメトリ（参考値）」）として追加表示する**方針を推奨する。

理由: 「どちらを正とするか」を決め打ちで片方だけ表示する設計は、既にマージ・安定稼働している
issue #97のセッションログ集計を置き換えることになり、受け入れ条件4「Claude Code側の集計結果・
レポート内容が変化せず既存テストが通る」のリスクを不必要に広げる。別セクション表示なら、
両者を独立に検証・ロールバックできる。この判断はDDRへ記録する。

## 6. `logPrompts`の扱い（受け入れ条件6）

既定値は`true`（2.のキー一覧表で確認。出典は`docs/cli/telemetry.md`であり、ソースコードでの
既定値確認は未実施）。プロンプト本文がログレコードの属性へ含まれる設計と見られる
（`docs/cli/telemetry.md`の記載。属性名までは本調査では未確認）。

**`logPrompts`が制御するのは「プロンプト本文」のみである点に注意する。** `logPrompts: false`を
指定しても、テレメトリ出力に含まれる**他の情報**（tool_callイベントの引数＝ファイルパス・
シェルコマンド・編集内容の断片、エラーメッセージ本文等）が抑制されるかは本調査では確認して
いない。したがって「`logPrompts: false`であれば機微情報の漏洩リスクが無い」とは言い切れず、
リスク評価はtool_call等の他イベントの属性を確認したうえで行う必要がある（フェーズ3以降の
実機確認事項に加える）。

**推奨: `.gemini/settings.json`へtelemetry設定を追記する際、`logPrompts: false`を明示的に
指定する。** これはプロンプト本文の抑制には有効だが、上記のとおり他の機微情報まで防げる
保証は無いため、**7.の既定有効化の可否判断は、tool_call等の属性確認が済むまで保留する**
（6.単独では「安全だから既定ONにしてよい」という結論を出さない）。

## 7. 既定有効化の可否（受け入れ条件7の一部）

issue #103（Claude Code側）は`.claude/settings.json`（共有ファイル）へ`env.
CLAUDE_CODE_ENABLE_TELEMETRY`等を追加し、**配布先の利用者全員に対して既定でONにした**
（`.claude/docs/spec/otel-listener.md`「配布時の扱い」）。

Gemini CLI側も同様に`.gemini/settings.json`（共有ファイル）へ`telemetry.enabled: true`を
追加すれば、配布先全体で既定有効になる。ただし6.のとおり、`logPrompts: false`だけでは
tool_call等の他イベントに残る機微情報までは防げない可能性があり、既定ONの安全性を
プロンプト本文だけで判断することはできない。

**もう一点、既定ONの前提として「出力先はリポジトリへコミットされない」ことが必要だが、
これは本リポジトリの`.gitignore`だけでは成り立たない。** 本リポジトリの`.gitignore`は
配布対象**ではない**（配布マーカー`dist:begin`〜`dist:end`を持つのは`.gitattributes`のみ。
`.gitignore`側は`.claude/skills/apply-mr-workflow-to-project/scripts/install-to-project.sh`が
`/.claude/usage-state/` `/.claude/session-logs/` `/.gemini/usage-state/`
`/.gemini/session-logs/`の4行を配布先へ追記するのみで、`/usage/`も`*.log`も追記しない）。
一方`.gemini/settings.json`は`sync-assets.sh`・`install-to-project.sh`により配布先へ
コピーされる（`install-to-project.sh`の該当行で確認済み）。つまり**「既定ON」だけが配布され、
それを安全にしている前提（`.gitignore`によるコミット回避）は配布されない**という非対称が
生じ、配布先ではテレメトリ出力ファイルが`git status`に現れコミットされうる。この問題は
Gemini CLI側の制約ではなく、**本機構（`install-to-project.sh`）側の配布漏れ**である。

**推奨: 次の2条件がいずれも満たされるまで、`telemetry.enabled: true`の既定ONは行わない。**
1. `install-to-project.sh`の配布行へ、テレメトリ出力先（例: `/usage/`または個別のログファイル
   パターン）の`.gitignore`追記を追加する（フェーズ3の作業項目とする）。
2. tool_call等の他イベントに機微情報が残らないことを実機確認する（受け入れ条件1の実機確認と
   あわせて依頼する。1.「受け入れ条件1の扱い」の依頼項目に追加する）。
条件が整うまでは、`logPrompts: false`を明示指定したうえで**任意設定として案内するに留める**
（利用者が自分の判断で有効化する）。

## 8. ローテーション方針

1.で確認したとおり、`file-exporters.ts`の範囲にはファイルローテーション機構が見当たらず、
`outfile`は起動中ずっと同じファイルへ追記され続ける（1.の確認範囲についての限定は「判明した
事実」の注記を参照。他ファイルまでは追えていない）。

対応工数レポート側（push検知hook）で日次ローテーションを試みることも考えられるが、**Gemini CLI
プロセスが起動中に元ファイルをリネームすると、そのプロセスは同じinodeへ書き込みを継続するため、
新しいファイル名で内容を追跡できなくなる**（Unix系のファイルディスクリプタの一般的な挙動。
Gemini CLI固有の検証はしていない）。実行中プロセスに影響を与えない安全なローテーションは、
本機構側だけでは実現が難しい。

3.で確認したとおり、`GEMINI_TELEMETRY_OUTFILE`環境変数によりGemini CLI起動時に動的な
パスを渡すこと自体は技術的に可能である。この経路が使えれば「起動のたびに新しいファイルへ
書かせる」形のローテーションが実現できるが、これには本機構側にGemini CLI起動を仲介する
ラッパーが必要であり、現状は存在しない。

**推奨: 当面はローテーションを実装せず、無制限の追記を許容する。** 4.のバイトオフセットカーソル
方式により集計自体は正しく差分計算できるため、ファイルサイズの増大は運用上の課題（ディスク
使用量）にとどまる。将来的な対処（定期的な手動クリーンアップの案内、`GEMINI_TELEMETRY_OUTFILE`
環境変数を使ったGemini CLI起動ラッパーの新設等）は、DDRの未決定事項として記録する。

## まとめ（フェーズ3への申し送り）

| 項目 | 判断 |
|---|---|
| 出力ファイル形式 | 単一ファイル・追記型・spans/logs/metrics混在・各エントリはpretty-print複数行JSON（区切りは末尾改行）。**同一イベントがログとして常に2重emitされる**・**metricsは10秒間隔で周期export**。実機未検証（ソースコードで確認） |
| settings.jsonのスキーマ | `telemetry`はトップレベルキー。`enabled`/`target`/`otlpEndpoint`/`otlpProtocol`/`outfile`/`logPrompts`/`useCollector`/`useCliAuth`。`GEMINI_TELEMETRY_*`環境変数群での上書きも可能 |
| 出力先配置 | 当面issue #103とは整合させず固定ファイル名（例: `usage/gemini-otel.log`）とする。ただし`GEMINI_TELEMETRY_OUTFILE`環境変数により動的パス注入自体は技術的に可能（起動ラッパーが無いため未採用） |
| 差分カーソル単位 | バイトオフセットカーソル（行カーソル・畳み込み方式のいずれも不適）。集計対象はlogsのLogRecordのみに限定し、metricsは除外。途中書き込み・ファイル縮小・状態破損への耐障害性をフェーズ3の必須要件とする |
| 二重計上回避 | (a) セッションログ由来とテレメトリ由来は別状態ファイル・レポート上は別セクション表示（合算しない）、(b) テレメトリ内部でも同一イベントの2重emit（toLogRecord/toSemanticLogRecord）を重複排除する、(c) 状態ファイルはブランチ・セッションいずれにも紐づかないグローバルなカーソルとする |
| logPrompts | `false`を明示指定。ただしプロンプト本文以外の機微情報（tool_call引数等）が出力に残るかは未確認 |
| 既定有効化 | **保留**。`.gitignore`が配布先へ出力先除外を配らない配布漏れと、tool_call等の機微情報未確認の2条件が解消するまで既定ONにしない。当面は任意設定として案内する |
| ローテーション | 当面実装しない（実行中プロセスへの影響が避けられないため）。`GEMINI_TELEMETRY_OUTFILE`を使った起動ラッパーは将来の拡張として残す |

## issueの受け入れ条件との対応（フェーズ2完了時点の到達状態）

| 受け入れ条件 | 到達状態 |
|---|---|
| 1. telemetry設定によりusage/配下へファイルが生成・追記される | **未検証・要実機**。人間への依頼項目（1.「受け入れ条件1の扱い」）として明記済み |
| 2. テレメトリ由来の集計値が対応工数レポートへ載り差分が二重計上されない（単体テスト検証） | **方針確定・実装はフェーズ3**。4.・5.で重複排除方式（形式選択・グローバルカーソル・metrics除外）まで具体化済み。フィクスチャは推測ベースのため実機確認後の差し替えが必要 |
| 3. issue #97実装のセッションログ集計とテレメトリ集計が二重計上にならない | **方針確定**。5.で別状態ファイル・別セクション表示とすることを決定 |
| 4. Claude Code側の集計結果・レポート内容が変化せず既存テストが通る | 本フェーズは調査のみで実装対象に含めない。フェーズ3の検証事項として申し送る |
| 5. `.gemini/settings.json`がTelemetrySettingsスキーマに沿っている | **確認済み**（2.、WebFetch経由での2回一致確認） |
| 6. `logPrompts`の既定・出力先がgitignore対象であることが明記されている | **既定値`false`を明示指定する方針は確定**。ただし「出力先がgitignore対象」という前提は配布先で成立しないことが判明したため、7.でこの前提の是正を必須項目とした |
| 7. 出力先配置がissue #103と整合している、または整合しない理由が記録されている | **確認済み**（3.。整合させない理由と、将来整合させる余地＝環境変数の存在を記録） |
| 8. 設計判断がDDRとして記録されている | 未着手（フェーズ4の対象）。本フェーズで記録した判断はすべてDDR化対象として申し送る |
| 9. 仕様がspecに記録されている、実機検証できない範囲は「未検証」と明示されている | 未着手（フェーズ4の対象）。本reportの「未検証・残課題」節が転記元 |

## 未検証・残課題

- Gemini CLI実機での動作確認（受け入れ条件1の生成確認、ファイル形式の実データ確認、
  `logPrompts:false`下でのtool_call等の機微情報の残存有無）はこの実行環境では実施できなかった。
  フェーズ3以降で人間のローカル環境での確認を依頼する（依頼項目は1.「受け入れ条件1の扱い」参照）。
- `session.id`属性がresource属性かlog属性かは未確認。
- `TelemetrySettings`型の完全なフィールド定義（`packages/core/src/telemetry/types.ts`ではなく
  別ファイルにある可能性）は未確認。`docs/cli/telemetry.md`とsettingsSchema.tsのトップレベル
  配置により、本issueの判断に必要な範囲は確認済み。
- `outfile`に相対パスを指定した場合の解決基準（cwd/プロジェクトルート）は未確認。
- 複数のGemini CLIセッションが同一`outfile`へ同時追記する場合の原子性は未確認。
- **参照した公式ソースの版**: 2026-08-23時点の`google-gemini/gemini-cli` `main`ブランチ
  （`main`は可変のブランチであり、以後のコミットで内容が変わりうる）。本reportの記述はすべて
  WebFetch経由の要約に基づく（冒頭「調査手法についての注記」参照）ため、追試可能性を確保する
  目的で、確認時点でのpermalinkを以下に残す（実際に本文中で確認した4ファイル＋公式ドキュメント。
  取得はいずれも2026-08-23、指しているコミットSHAは`f47d6c6f7a1308d81f9f57acf7d279f0928c5249`。
  本文で最初に各ファイルを参照した時点のコミットとは厳密には一致しない可能性がある点に注意）。
  - https://github.com/google-gemini/gemini-cli/blob/f47d6c6f7a1308d81f9f57acf7d279f0928c5249/packages/core/src/telemetry/sdk.ts
  - https://github.com/google-gemini/gemini-cli/blob/f47d6c6f7a1308d81f9f57acf7d279f0928c5249/packages/core/src/telemetry/file-exporters.ts
  - https://github.com/google-gemini/gemini-cli/blob/f47d6c6f7a1308d81f9f57acf7d279f0928c5249/packages/core/src/telemetry/loggers.ts
  - https://github.com/google-gemini/gemini-cli/blob/f47d6c6f7a1308d81f9f57acf7d279f0928c5249/packages/cli/src/config/settingsSchema.ts
  - https://github.com/google-gemini/gemini-cli/blob/f47d6c6f7a1308d81f9f57acf7d279f0928c5249/docs/cli/telemetry.md
