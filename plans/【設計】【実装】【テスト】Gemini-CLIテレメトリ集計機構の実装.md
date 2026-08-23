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
| `.claude/scripts/src/sync-gemini-assets.sh` | `SETTINGS_JQ_FILTER`（または専用の後処理関数）へ`telemetry`ブロックの固定注入を追加。`SETTINGS_IGNORED_KEYS`の`env`コメントも更新。`--check`/`--dry-run`との整合を確認 |
| `.claude/docs/spec/sync-gemini-assets.md` | 上記変更の仕様反映（フェーズ4で実施。本計画では変更しない） |
| `.gemini/settings.json` | 生成物。`sync-gemini-assets.sh`変更後に再生成しコミットする（コミットしないと`--check`が以後失敗し続ける） |
| `.claude/scripts/test/test_sync_gemini_assets.sh` | T9のゴールデンフィクスチャ比較が`telemetry`キー追加により失敗するため、`fixtures/sync-gemini-assets/settings-expected.json`を更新する |
| `.claude/hooks/lib/UsageTracking.sh` | 新規関数群を追加（下記「方針」参照）。既存のClaude Code経路・Gemini経路（セッションログ）の関数は変更しない |
| `.claude/hooks/post-push-usage-report.sh` | テレメトリ集計の呼び出しと、レポート本文への別セクション追加 |
| `.claude/scripts/test/test_usage_tracking.sh` | 新規関数群の単体テストを追加（実jqをフィクスチャへ直接適用する既存方式に合わせる） |
| `.claude/skills/apply-mr-workflow-to-project/scripts/install-to-project.sh` | 配布先`.gitignore`への`/usage/`追記漏れを是正 |
| `.claude/scripts/test/test_install_to_project.sh` | 配布先`.gitignore`へ`/usage/`が1行入ることを確認するケースを追加 |
| `.gitignore`（本リポジトリ自身） | 変更不要（`/usage/`が既にテレメトリ出力先・カーソル状態ファイルの両方をカバーする。事前調査で確認済み） |

## 方針

### 1. `.gemini/settings.json`への`telemetry`注入

`sync-gemini-assets.sh`の`SETTINGS_JQ_FILTER`（jq文字列）の末尾、最終的な出力オブジェクトを
組み立てる箇所へ、次の値を固定で追加する。**`enabled`は`false`固定で注入する**（下記の理由）。

```json
{
  "telemetry": {
    "enabled": false,
    "target": "local",
    "outfile": "usage/gemini-otel.log",
    "logPrompts": false
  }
}
```

- **`enabled: false`固定とし、本計画の範囲では有効化しない。** フェーズ2報告7.節の結論は
  「保留」（配布先gitignore是正・tool_call機微情報確認の2条件が揃うまでON化しない）であり、
  実機確認前に既定ONへ倒すのはこの結論と矛盾するため。
  - **利用者による手動有効化は前提にしない。** `.gemini/settings.json`は`.claude/`からの
    変換生成物であり（前提節参照）、手編集しても次に`sync-gemini-assets.sh`が走った時点
    （flow-id 5-3が毎タスクで通る）で無言で`false`へ戻り、さらに`--check`が「生成物と
    一致しない」として失敗するようになる。したがって「利用者が手で`true`にする」運用は
    成立しない。
  - 有効化の手段（`GEMINI_TELEMETRY_ENABLED`環境変数を使うか、`.claude/settings.json`側に
    有効化フラグを持たせて`sync-gemini-assets.sh`が変換するか等）は、**本計画では決定せず
    未決定事項へ回す**（後述「未決定事項」）。有効化手段が無いままでも、`enabled: false`固定の
    配線自体（target/outfile/logPromptsの用意）は次のissueの土台として意味を持つため、
    本計画のスコープとして進める。
  - 受け入れ条件1（telemetry設定によりファイルが生成・追記される）は、本計画の実装だけでは
    **有効化できないため確認できない**。人間の実機確認では、`.gemini/settings.json`の
    `telemetry.enabled`を検証用に一時的に`true`へ書き換えてもらう手順が必要になる
    （下記「人間への実機確認依頼」）。
- `outfile`は相対パス`usage/gemini-otel.log`とする。**相対パスの解決基準（cwd基準かプロジェクト
  ルート基準か）は未確認のまま採用する。** 解決基準がcwd基準だった場合、サブディレクトリで
  Gemini CLIを起動すると`<subdir>/usage/gemini-otel.log`が作られ、配布先`.gitignore`へ足す
  `/usage/`（先頭スラッシュ＝リポジトリルート限定）の対象外になり、プロンプト・tool_call由来の
  機微情報を含みうるファイルが`git status`に現れる可能性がある（受け入れ条件6が守ろうとしている
  ものと衝突する）。**この解決基準は人間への実機確認依頼に含める**（依頼項目6）。確認できるまでは
  受け入れ条件6を「本リポジトリでは対応済み・配布先での解決基準は未確認」として扱う（対応表参照）。
- `--check`（生成物と一致するかの検証）・`--dry-run`（差分表示）が新しいキーを正しく検出することを、
  本計画の検証節で確認する。
- `SETTINGS_IGNORED_KEYS`の`env`キーに付与されている既存コメント（「Gemini CLI経路では対応工数の
  OTel計測が行われない」旨）は、本変更によりその帰結が変わる（envの変換自体は引き続き行わないが、
  telemetryブロックは固定値で注入されるようになる）。**コメントを「envブロックの変換は行わないが、
  telemetryブロックは固定値で注入する（issue #105）」の趣旨へ更新する**（同じファイルの中に
  相反する説明を残さないため）。

### 2. バイトオフセットカーソル集計（`UsageTracking.sh`への追加）

フェーズ2報告4.節の設計をそのまま実装する。新規関数（案、実装時に命名を調整してよい）:

- `_usage_read_otel_cursor(repo_root)`: `usage/state/gemini-otel/cursor.json`を読む。
  空・不正JSON・ファイル無しなら`{"byteOffset": 0}`を返す（`_usage_read_gemini_totals`と
  同じ自己回復パターンを踏襲。事前調査で確認した既存の`[ -n "$content" ] && jq -e .`方式）。
  **状態ファイルは`usage/state/`直下ではなく`usage/state/gemini-otel/`サブディレクトリへ置く**
  （直下に置くと、`usage/state/<branch>.json`のブランチ別状態ファイル名（`_usage_safe_branch_name`
  でブランチ名を`[^a-zA-Z0-9_-]`→`_`へ潰した名前）と、`gemini-otel-cursor`という名前のブランチが
  存在した場合に完全一致し、互いの内容を壊し合う可能性がある。issue #97が
  `usage/state/gemini-totals/<sessionId>.json`とサブディレクトリを切っているのと同じ理由）。
- `_usage_write_otel_cursor(repo_root, byte_offset)`: 上記ファイルへ`{"byteOffset": <数値>}`を
  書く。
- `_usage_otel_fold(outfile_path, byte_offset)`: `outfile_path`の`byte_offset`以降を読み、
  **完全にパースできた末尾までのJSON値だけ**を対象にする（途中書き込み対応）。
  - **エントリ境界の検出方法**: 1.「判明した事実」で確認したシリアライズ形式
    （`safeJsonStringify(data, 2) + '\n'`。インデント2のpretty-print JSON＋末尾改行1つ）を前提に、
    **行頭（列0）が`}`で始まる行の直後（その行の改行文字を含む）を、1エントリの終端**とみなして
    バイト単位で切り出す。JSON文字列値の中の改行は`\n`へエスケープされるため生の改行として
    現れず、インデント2のpretty-printでは各値のトップレベルの閉じ括弧だけが列0に来る、という
    性質を根拠にする。**この方式は`safeJsonStringify`のインデント幅・出力形式に依存する
    実装依存の判定であり、Gemini CLI側の出力形式が変わると壊れる**リスクをspec側に明記する
    （フェーズ4）。列0の`}`が1エントリ中に複数回現れないこと（トップレベルの型が常にobjectで
    あること）は、実機データで裏取りが必要な前提として未決定事項に残す。
  - 境界検出で切り出した各JSON値のうち、LogRecord形式のものだけを`gemini_cli.api_response`相当の
    属性で判定し、以下を行う。
    1. **metricsの除外**（フェーズ2報告の追加確認: `PeriodicExportingMetricReader`により
       10秒間隔で周期exportされるため、集計対象に含めない）。
    2. **同一イベントの2重emit（`toLogRecord`/`toSemanticLogRecord`）への対処**: 本計画では
       **semantic conventions形式（`toSemanticLogRecord`）のみを採用し、レガシー形式
       （`toLogRecord`）は集計対象から除外する**方式を既定として採用する（下記「境界をまたぐ
       二重計上」参照。判別方法の実データでの裏取りは未決定事項）。
    3. 新しく完全パースできたバイト位置と、トークン種別ごとの合計・呼び出し回数を返す。
  - **境界をまたぐ二重計上への対処**: 「今回読んだ新規バイト範囲の中」だけで重複排除キーを
    突き合わせる設計だと、`toLogRecord`と`toSemanticLogRecord`の2エントリが連続して書かれる際に
    片方だけが読み取り窓に入り、もう片方が次回の新規バイトに入るケースで、実際には1回のAPI応答が
    2回に分けて2回とも計上される（レガシー形式1回＋semantic形式1回＝2回）おそれがある。
    **上記2.で「semantic conventions形式のみを採用しレガシー形式を無視する」方式を選んだことで、
    この問題は原理的に発生しない**（無視される側がどちらの読み取り窓に入っても、集計対象は
    常にsemantic形式の1エントリだけになるため）。この判断の妥当性（実データでレガシー形式と
    semantic形式を確実に判別できるか）は未決定事項として残る。
  - **初回集計（カーソル0）での全量計上**: outfileはローテーション無しの無制限追記のため、
    テレメトリを有効化してから初めてレポートが走るまでに複数日分のデータが溜まっている
    可能性がある。**本計画では、初回もカーソル0から通常どおり全量を計上する**（特定の1回の
    pushへ多く計上されることを許容し、「カーソルを末尾へ合わせて0件扱いにする」特別扱いは
    行わない。理由: 特別扱いを入れると「有効化してから最初のデータがいつまで経っても
    集計されない」という別の分かりにくさを生むため）。この挙動を明示するテストケースを
    方針5へ追加する。
- ファイル縮小検知（DDR i0097-01の`needsReset`と同じ考え方）: 現在のファイルサイズが
  `byteOffset`より小さければ、カーソルを0へ戻してから読み直す。
- `_sync_usage_state_otel(repo_root, branch, outfile_path)`: 上記を組み合わせ、
  `usage/state/gemini-otel/cursor.json`（グローバル、ブランチ・セッション非依存。
  フェーズ2報告5.節の判断どおり）を読み書きし、今回pushでの差分（トークン合計・呼び出し回数）を
  返す。**既存の`sync_usage_state`（Claude Code経路・Gemini経路）とは完全に独立した関数**とし、
  既存関数のシグネチャ・返り値は一切変更しない（受け入れ条件4「既存の集計結果・レポート内容が
  変化しない」ことをコードレベルで保証するため）。

### 3. `post-push-usage-report.sh`への統合

- `main`関数内、`_sync_usage_state_otel`の呼び出しは**`engine`による分岐ではなく、
  `outfile_path`（`usage/gemini-otel.log`）が存在するかどうかで判定する**（既存の
  `sync_usage_state`呼び出しとは**別の呼び出し**とし、既存の`state`変数・
  `build_usage_report_body`への既存引数は変更しない）。
  - **engine分岐にしない理由**: `post-push-usage-report.sh`には既存の設計判断
    （「トークンテーブルの列構成はengineではなくデータで決める（issue #97）。『今回のengine』で
    列を決めると、混在時にどちらかの数値が無言で表から消える」）がある。もしengineで分岐すると、
    Gemini CLIでの作業後にClaude Code側の操作でpushが起きた場合にテレメトリ分の新規バイトが
    読まれずカーソルも進まず、その未処理バイトは次にengine=geminiでpushした回へ丸ごと計上される
    （数字が別push・別セッションへずれる）。データ側（outfileの有無・新規バイトの有無）で
    判定すれば、engineに関わらず「新しいテレメトリデータがあれば集計する」という一貫した
    振る舞いになり、この問題を避けられる。
- `build_usage_report_body`へ新しい引数（テレメトリ集計結果）を追加する際は、**既存の呼び出し
  （現在5引数）を壊さないよう、新引数は`"${6:-}"`のように既定値付きで受ける**
  （`test_usage_tracking.sh`の複数箇所が5引数のままこの関数を直接`source`して呼んでおり、
  `set -u`配下で単純に`local telemetry="$6"`とすると`$6: unbound variable`で既存ケースが
  一斉に失敗する。既定値付きで受ければ、既存の5引数呼び出しは値無し＝テレメトリセクション無し
  として扱われ、既存テストは無改修で通る）。値が存在する場合のみ「### Gemini CLI公式テレメトリ
  （参考値）」セクションを追加する（既存の「0件なら出さない」規約に従う）。**既存のトークン
  テーブル（`tokensByModel`）へは合算しない**（フェーズ2報告5.節、受け入れ条件2・3の核心）。
- `outfile_path`（`usage/gemini-otel.log`）が存在しない場合（テレメトリ未設定の利用者）は、
  何もせず既存の動作のまま終了する。

### 4. 配布gitignore是正

`install-to-project.sh`の`ignore_rules`配列は、実ファイル確認の結果**3要素**
（`/.claude/usage-state/` `/.claude/session-logs/` `/.claude/settings.local.json`）である。
このうち先頭2つは旧パス名（issue #23以前の`usage/`統合前の配置）だが、**3つ目
（`/.claude/settings.local.json`）は旧パスではなく、issue #70で意図的に配っている現行の行**
（`test_install_to_project.sh`がこの行の配布をアサートしている）。この3要素の末尾へ`/usage/`を
追加する。**既存の3行は削除しない**（旧パス名を使っていた過去の配布先との互換性のため。削除の
要否はフェーズ4で別途判断する）。

`test_install_to_project.sh`（変更対象へ追加）に、配布先`.gitignore`へ`/usage/`が1行入ることを
固定するケースを1件追加する（既存の`grep -cFx -- '/.claude/settings.local.json' "$dest_new/
.gitignore"`と同じ形で、実際に配布先を作って確認する）。

### 5. テストフィクスチャ

フェーズ2報告のテストフィクスチャ方針（1.節「テストフィクスチャの妥当化方法」）に従い、
`safeJsonStringify(data, 2) + '\n'`形式（pretty-print、改行区切り）を模した固定文字列を
`test_usage_tracking.sh`内にヒアドキュメントで直接記述する（既存の`gm_dir/main.jsonl`と同じ
パターン）。少なくとも以下のケースを含める。

- 正常系: `gemini_cli.api_response`のLogRecordが2重emit（レガシー形式＋semantic conventions
  形式）された状態で、semantic conventions形式のみが集計されトークン数が1回分になること。
- 境界またぎ2重emit: レガシー形式とsemantic形式の2エントリが**別々の読み取り窓**（1回目の
  集計とカーソル継続後の2回目の集計）に分かれて現れても、semantic形式の1回分しか計上されない
  こと（レガシー形式は無視されるため、窓をまたいでも二重計上が起きないことの検証）。
- metrics混在: ResourceMetrics相当の値が同じファイルに混在していても、集計対象から除外され
  トークン数へ影響しないこと。
- カーソル継続: 2回目の呼び出しで、前回処理済みバイト以降だけが新規として計上されること。
- 初回集計（カーソル0・既存データあり）: テレメトリ有効化前から複数エントリ分溜まっていた
  outfileに対し、初回の集計呼び出しで**全量が計上される**こと（カーソルを末尾へ合わせて0件と
  する特別扱いをしていないことの確認）。
- ファイル縮小: ファイルサイズがカーソル値より小さい場合、カーソルが0へリセットされ、
  縮小後のファイル全体が再集計されること。
- 状態ファイル破損: 空・不正JSONの状態ファイルから、既定値（`{"byteOffset": 0}`）へ
  自己回復すること。
- 途中書き込み: 末尾が不完全なJSON（列0の`}`+改行で終わっていない等）の場合、その部分を除いた
  完全な値までを処理し、カーソルがその手前で止まること。
- `post-push-usage-report.sh`のレポート本文テスト: テレメトリ集計結果がある場合・無い場合の
  両方で、既存のClaude Code/Gemini経路（セッションログ）のセクションが変化しないこと
  （受け入れ条件4の直接的な検証。既存の5引数呼び出しケースが無改修で通ることも確認する）。

## やらないこと（スコープ外）

- `telemetry.enabled`を既定`true`にすること（フェーズ2報告7.節の判断どおり、2条件
  ＝配布gitignore是正・tool_call機微情報確認が揃うまで見送る。本計画は前者のみ対応し、後者は
  人間への実機確認依頼に含める）。
- `GEMINI_TELEMETRY_OUTFILE`環境変数を使った起動ラッパーの新設（issue #103のような日次
  ローテーション整合。フェーズ2報告3.節・8.節で「将来の拡張」として明記済み）。
- `.claude/hooks/otel/listener.pl`（Claude Code側OTelリスナー）の変更・Gemini由来テレメトリの
  受け入れ（`sync-gemini-assets.sh`の既存コメントが明示的に対象外としている）。
- `outfile`の相対パス解決基準の実機確認（人間への依頼事項とする。フェーズ2報告3.節「残課題」）。
- `telemetry.enabled`の有効化手段の確立（環境変数・設定フラグ等）。本計画は`enabled: false`
  固定の配線のみを行い、有効化の仕組み自体は未決定事項として次のissueまたはフェーズ4へ送る。

## 検証

```bash
# 1a. 実装前（telemetry未注入の.gemini/settings.jsonのまま）は --check が失敗すること
#     （検証が本当に「注入されていない状態」を検出できることの確認。実装後に1回だけ実行）
bash .claude/scripts/src/sync-gemini-assets.sh --check; echo "exit=$?（0以外を期待）"

# 1b. 再生成してtelemetryブロックが注入され、--checkが通ること
bash .claude/scripts/src/sync-gemini-assets.sh
jq -e '.telemetry.enabled == false and .telemetry.target == "local" and
  .telemetry.outfile == "usage/gemini-otel.log" and .telemetry.logPrompts == false' \
  .gemini/settings.json
bash .claude/scripts/src/sync-gemini-assets.sh --check

# 2. 単体テスト全件が通ること（既存17本＋今回追加分）
for t in .claude/scripts/test/test_*.sh; do bash "$t" || echo "FAILED: $t"; done

# 3. 既存のClaude Code経路・Gemini経路（セッションログ）のテストケースが1件も削除・変更
#    されていないこと（ブランチ分岐点からの差分を基点にする。引数なしgit diffは使わない）
base_sha=$(git merge-base origin/main HEAD)
git diff "$base_sha" -- .claude/scripts/test/test_usage_tracking.sh | grep -c '^-[^-]'
#   ↑ 既存ケースの削除行数。0であることを確認する（新規ケースの追加行(+)は対象外）

# 4. install-to-project.sh の配布gitignoreに /usage/ が追加され、実際の配布先にも反映される
#    こと（スクリプト内の文字列存在だけでなく、test_install_to_project.sh の新規ケースで
#    配布先.gitignoreへ実際に1行入ることまで確認する）
bash .claude/scripts/test/test_install_to_project.sh
```

合格条件: 上記の全項目が成功し、`test_usage_tracking.sh`が`passed=N failures=0`（Nは既存90件
＋新規テスト件数）を返すこと。項目3は削除行数が0であることを確認する（`--stat`の行数要約では
文言変化を検出できないため使わない）。

## issueの受け入れ条件との対応

| 受け入れ条件 | この計画での対応 |
|---|---|
| 1. telemetry設定によりusage/配下へファイルが生成・追記される | 設定層（方針1、`enabled: false`固定）で配線のみ用意。**本計画の実装だけでは有効化できず自動確認できない**。人間の実機確認依頼で`telemetry.enabled`を一時的に`true`へ書き換えてもらい確認する |
| 2. テレメトリ由来の集計値が対応工数レポートへ載り差分が二重計上されない | 集計層・レポート層（方針2・3）＋テスト（方針5の重複排除ケース）。**テストフィクスチャは実機データではなく公式ソースからの推測に基づく**ため、実機出力との突き合わせが済むまで本条件は暫定確認にとどまる（下記「人間への実機確認依頼」で裏取りする） |
| 3. issue #97実装のセッションログ集計とテレメトリ集計が二重計上にならない | 集計層（方針2、既存関数と完全独立）＋テスト（レポート本文テスト） |
| 4. Claude Code側の集計結果・レポート内容が変化せず既存テストが通る | 方針2「既存関数のシグネチャ・返り値は一切変更しない」＋方針3（`build_usage_report_body`の新引数は既定値付き）＋検証節3 |
| 5. `.gemini/settings.json`がTelemetrySettingsスキーマに沿っている | 方針1（フェーズ2報告2.節のスキーマに準拠） |
| 6. `logPrompts`の既定・出力先がgitignore対象であることが明記されている | 方針1（`logPrompts: false`固定）・方針4（配布gitignore是正）。**ただし相対パス`outfile`の解決基準が未確認の間は、配布先での成立が保証できない**（人間への実機確認依頼項目6で裏取りする） |
| 7. 出力先配置がissue #103と整合している、または理由が記録されている | フェーズ2報告3.節で記録済み（本計画は変更しない） |
| 8. 設計判断がDDRとして記録されている | フェーズ4の対象（本計画では実施しない） |
| 9. 仕様がspecに記録されている、実機検証できない範囲は「未検証」と明示されている | フェーズ4の対象（本計画では実施しない） |

## 人間への実機確認依頼

受け入れ条件1・2・5・6の裏取りに必要な実機確認を、flow-id 3-3（作業計画レビュー時。または
3-6完了後のレビュー依頼で）人間へ依頼する。依頼する情報は調査結果1.節が挙げた7項目を用いる
（うち1〜5・7は調査結果と同一、6は本計画で相対パス解決基準の確認として明記）。

1. `gemini --version`の出力（バージョン）。
2. 使用した`.gemini/settings.json`の`telemetry`部分（本計画が生成する設定を、確認用に
   `enabled: true`へ書き換えたもの）。
3. 出力ファイルの先頭2〜3エントリ（プロンプト本文等の機微情報は伏せてもらう）。
4. 出力ファイルの`wc -c`（バイト数）と、含まれるJSON値の個数（`jq -n '[inputs] | length'`等）。
5. 同一の`gemini_cli.api_response`イベントが、レガシー形式・semantic conventions形式の
   2エントリとして現れているか。
6. `outfile`に相対パス`usage/gemini-otel.log`を指定した場合、実際にファイルが作られる場所
   （cwd基準かプロジェクトルート基準か）。
7. `logPrompts: false`のまま、ツール呼び出しを1回発生させた際の出力に機微情報が残るか
   （既定ON可否の判断材料。フェーズ4以降の検討事項）。

**データが得られない場合の代替**: 上記のいずれも得られないままフェーズ3を完了させる必要が
生じた場合は、方針2で既定とした「semantic conventions形式のみ採用」をそのまま確定値として進め、
実機データ入手後に別issueまたはフェーズ4の反映作業で差し替える。受け入れ条件1・2・5・6は
「未検証」として明示し（フェーズ4の対象）、フェーズ3のレビューでは実装そのもの（配線・集計
ロジック・二重計上回避設計）の妥当性のみを合意対象とする。

## 未決定事項（レビューで確認したいこと）

- **2重emitの判別方法**: レガシー形式（`toLogRecord`）とsemantic conventions形式
  （`toSemanticLogRecord`）を実データでどう判別するか（属性名・属性の形の違い）は、実機確認前に
  確定できない。方針2は「semantic conventions形式のみ採用」を既定としたが、判別に使う具体的な
  jqフィルタは、実機確認結果（人間への依頼項目5）を見てフェーズ3のレビュー往復で確定する。
- **LogRecordとmetricsの判別方法**: 事前調査でも実データを見られていないため、判別ロジックの
  具体的なjqフィルタはレビュー往復（3-6〜3-9）の中で実データ（人間からの実機確認結果）を
  踏まえて調整する前提とする。
- **telemetryの有効化手段**: `enabled: false`固定配線に対し、利用者がどう有効化するか
  （`GEMINI_TELEMETRY_ENABLED`環境変数を使うか、`.claude/settings.json`側にフラグを持たせ
  `sync-gemini-assets.sh`が変換するか等）は本計画では決定しない。次のissueまたはフェーズ4での
  検討事項とする。
- **境界検出方式の実データでの裏取り**: 列0の`}`+改行をエントリ境界とみなす方式が、実際の
  Gemini CLI出力（トップレベルが常にobjectであること）に対して成立するかは未確認のまま採用する。
