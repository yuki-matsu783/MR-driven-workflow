---
title: 20260823 Gemini-CLIテレメトリ集計機構の実装 push10 worklog
type: log
description: issue #105フェーズ3（作業）flow-id 3-6の実装ログ。設定層・集計層・レポート層・配布gitignore是正・単体テストの実装過程
tags: [gemini-cli, telemetry, usage-report, issue-105]
keywords: [sync-gemini-assets, UsageTracking, post-push-usage-report, byteOffset, install-to-project, jq, フォールディング]
---

# worklog: Gemini-CLIテレメトリ集計機構の実装（push10）

flow-id 3-6。`plans/【設計】【実装】【テスト】Gemini-CLIテレメトリ集計機構の実装.md`
（レビュー1周目で20件の指摘反映済み）に従って、設定層・集計層・レポート層・配布gitignore是正・
単体テストを実装した。

## 実装した順序と内容

### 1. 設定層: `sync-gemini-assets.sh` への telemetry 注入

- `SETTINGS_JQ_FILTER` の出力オブジェクト構築末尾へ、次の固定値ブロックを追加した。

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

- `enabled: false` はレビュー1周目の指摘どおり固定値。有効化手段の確立は本issueのスコープ外
  （未決定事項）。
- `SETTINGS_IGNORED_KEYS` の `env` キーに関するコメントを更新し、telemetryはenvとは独立に
  固定値注入すること・`target: "local"` のため `listener.pl`（OTLPネットワーク受信）を経由
  しないことを明記した。
- 検証手順（計画の指示どおり、生成前に失敗することを先に確認）:
  1. `bash .claude/scripts/src/sync-gemini-assets.sh --check` → 生成前は不一致で exit=1 を確認。
  2. `bash .claude/scripts/src/sync-gemini-assets.sh` → 再生成。
  3. `.gemini/settings.json` の `telemetry` ブロックを `jq` で検証 → 期待どおりの値。
  4. `--check` を再実行 → exit=0。

### 2. `test_sync_gemini_assets.sh` のT9ゴールデンフィクスチャ更新

`settings-expected.json` を、`convert_settings` の実際の出力で上書きした（telemetryブロックが
末尾に追加された状態）。`bash .claude/scripts/test/test_sync_gemini_assets.sh` → `passed=83
failures=0`。

### 3. 集計層: `UsageTracking.sh` へのバイトオフセットカーソル集計関数群

既存のGemini CLIセッションログ集計（`_usage_gemini_fold`系、issue #97）とは完全に独立させ、
既存関数のシグネチャ・返り値を一切変更しないように新規関数群として追加した
（`_usage_filter_nonzero_subagents` の直前に挿入）。

- `_usage_otel_extract_complete_to_reply`: outfileの`byte_offset`以降のうち、完全にパースできた
  末尾までの部分を一時ファイルへ切り出す。「完全」の判定は、pretty-print出力
  （`safeJsonStringify(data, 2) + '\n'`）の性質を前提に、**行頭（列0）が`}`のみである最後の行**を
  1エントリの終端とみなす方式（計画で指摘され明記した方式）。複数戻り値のため
  `REPLY`/`REPLY_NEW_OFFSET` へ返す（`.claude/rules/shell-script-style.md`の規約に準拠）。
- `_usage_otel_fold`: 完全な範囲を畳み込み、モデル別トークン合計と呼び出し回数を返す。
  - **重要なハマりどころ**: 最初 `jq -R -n 'inputs'`（raw-input）で実装したところ、
    複数行にまたがるpretty-print JSON値を1行ずつ`fromjson`しようとして必ず失敗し、常に0件に
    なった。`-R`を外し `jq -n '[inputs]'`（jqのネイティブJSONストリームパーサ）に変更して解決。
    複数行にまたがるJSON値が改行区切りで連続する形式は、行単位の文字列読み込みでは扱えない。
  - metricsレコード（`dataPoints`/`sum`/`gauge`/`histogram`/`scopeMetrics`/`resourceMetrics`の
    いずれかを持つ）を除外。
  - `gemini_cli.api_response`のレガシー形式・semantic conventions形式の二重emit問題は、
    **semantic conventions形式（`gen_ai.*`属性キーを持つ）のみを採用しレガシー形式は無視する**
    設計（計画で確定済み）で解消。境界をまたいでも、無視される側がどちらの読み取りウィンドウに
    落ちても計上に影響しないため、原理的に二重計上しない。
- `_usage_read_otel_state` / `_usage_write_otel_state`: `usage/state/gemini-otel/cursor.json`
  （ブランチ非依存のグローバル状態。既存の`usage/state/<branch>.json`とのパス衝突を避けるため
  サブディレクトリ化）を読み書き。空・不正JSONは既定値（`{byteOffset: 0, sinceLastPush:
  {tokensByModel: {}, calls: 0}}`）へ自己回復する（`.claude/rules/shell-script-style.md`
  「JSON操作」の自己回復パターンに準拠）。
- `_sync_usage_state_otel`: 集計本体。outfile不在なら終了コード1。ファイル縮小検知
  （DDR i0097-01の`needsReset`と同じ考え方でbyte_offsetを0へリセット）・途中書き込み対応
  （完全なエントリが1つも無ければbyte_offsetを進めず今回は空扱い）を含む。
  **初回集計（カーソル0）でも特別扱いせず、既存に溜まっていたデータを含め全量をそのまま計上する**
  （計画の明示的な決定）。
- `_usage_reset_otel_since_last_push`: push成功後にsinceLastPushをゼロ初期化する
  （既存の`_usage_reset_since_last_push`とは別ファイルを対象とする独立関数）。

`bash -n` 構文チェック通過後、scratchpadで正常系・境界またぎ・metrics混在・カーソル継続・
ファイル縮小・状態ファイル破損・outfile不在・途中書き込みの各パターンを手動検証し、すべて
期待どおりの結果を確認した（後述のとおり、この時点の手動検証は本コミットで
`test_usage_tracking.sh`の恒久ケースへ置き換えた）。

### 4. レポート層: `post-push-usage-report.sh` への統合

- `build_usage_report_body()` に第6引数 `telemetry` を追加。**`local telemetry="${6:-}"`と
  既定値付きで受ける**ことで、既存の5引数呼び出し（テスト含む）を壊さないようにした
  （計画のレビューで見つかった設計ミスの修正を踏襲）。
- 新セクション「### Gemini CLI公式テレメトリ（参考値）」を、既存のサブエージェント集計セクション
  の直後・フッターの直前に追加。**既存のトークンテーブル（`$usage`由来）へは合算しない**
  （別枠の独立したセクション・別テーブル）。`telemetry.calls`が0（または`telemetry`自体が
  空/`null`）の場合はセクションごと出さない。
- `main()`内: `otel_outfile="${repo_root}/usage/gemini-otel.log"` の存在有無で
  `_sync_usage_state_otel`を呼ぶかどうかを判定する（**`engine`ではなくデータ（outfileの有無）で
  判定する**。既存設計方針「列構成はengineではなくデータで決める」との整合。計画レビューで
  修正した点）。得られた状態から`sinceLastPush`を`telemetry_usage`として`build_usage_report_body`
  へ渡す。
- push成功時の既存の`_usage_reset_since_last_push`呼び出しに続けて、
  `_usage_reset_otel_since_last_push`も呼ぶ（otel_stateが存在する場合のみ）。
- `bash -n`構文チェック通過。`test_usage_tracking.sh`（既存90ケース）が無変更で
  `passed=90 failures=0`のまま通ることを確認し、5引数呼び出しへの非破壊を担保した。

### 5. 配布gitignore是正: `install-to-project.sh`

`ignore_rules`配列（実ファイル確認済み3要素）の末尾へ`/usage/`を追加した（既存3行は変更しない）。
`test_install_to_project.sh`へ、配布先`.gitignore`へ`/usage/`が1行入ることを固定するテストケースを
1件追加した（既存の`/.claude/settings.local.json`確認ケースと同じ`grep -cFx`パターン）。

`bash .claude/scripts/test/test_install_to_project.sh` → `passed=24 failures=0`
（既存23ケース＋新規1ケース）。

### 6. `test_usage_tracking.sh` への恒久単体テスト追加（9ケース）

scratchpadでの手動検証を、`test_usage_tracking.sh`の恒久フィクスチャへ置き換えた。ヘルパー
（`otel_semantic_entry` / `otel_legacy_entry` / `otel_metric_entry` / `otel_repo`）を用意し、
以下9ケースを追加。

1. 正常系: レガシー形式＋semantic形式の対を書き込んでも、semantic形式のみが計上される
2. 境界またぎ2重emit: レガシー形式とsemantic形式が別々の読み取りウィンドウへ分かれても
   二重計上しない
3. metrics混在: 周期exportのmetricsレコードがtokens/callsへ現れない
4. カーソル継続: 1回目集計後の追記分だけが2回目の差分として計上される
5. 初回集計: 有効化前から溜まっていた複数エントリが、初回1回のカーソル0集計で全量計上される
6. ファイル縮小: byte_offsetがファイルサイズを超えて先行している状態を検知し0へリセット、
   **縮小前に積んだsinceLastPushは消えず新しい内容が上乗せされる**
7. 状態ファイル破損: cursor.jsonが空文字列（不正JSON）でも既定値へ自己回復する
8. 途中書き込み: 列0の`}`で終わらない末尾は今回の集計に含めず、完結後の次回集計で拾われる
9. レポート本文: `build_usage_report_body`の第6引数（telemetry）は別セクションとして出て
   既存のClaude/Geminiテーブルへ混ざらないこと。第6引数省略時・calls=0時はセクションが出ないこと

**ハマった点（(6)ファイル縮小ケース）**: 当初「10,5」→「999,999」という値の置き換えだけで
縮小を再現しようとしたが、桁数が増えたぶんJSON文字列が長くなり、**実際にはファイルサイズが
縮小しない**ケースがあり、`jq: Unmatched '}'`エラーで1件失敗した。1回目のモデル名を意図的に
長くパディングし、2回目は極端に短いモデル名（`"g"`）に差し替えることで、確実にファイルサイズが
縮小する構成へ修正して解決した。

**もう1点の設計理解の修正（(6)の期待値）**: 当初「縮小後は新しい内容の値だけになる」と誤って
期待していたが、実装は`sinceLastPush`をリセットせず維持したまま縮小後の再集計分を加算する
設計（DDR i0097-01の`needsReset`と同じ考え方）だった。テストの期待値を「縮小前に積んだ分は
別モデルキーとして残り、新しい内容が別途計上される」形へ修正した。

`bash .claude/scripts/test/test_usage_tracking.sh` → `passed=112 failures=0`
（既存90ケース＋新規22アサーション、9ケース分）。

## 最終検証（全体）

- `bash .claude/scripts/src/sync-gemini-assets.sh --check` → exit=0（`.claude/`変更を反映して
  再生成後）。
- 全`.claude/scripts/test/test_*.sh`を実行し、すべて`failures=0`。
- `git diff <ブランチ分岐点SHA> -- .claude/` の削除行を確認し、DDR/spec本文の point-in-time
  記録を破壊する削除が無いことを確認（実際の削除行2件は本セッションで自分が書いた
  `sync-gemini-assets.sh`内のコメント更新のみで、問題なし）。

## 次の一歩

- `reports/`へ作業結果を記録する（本ファイルとは別に、個別作業計画には結果を書かない方針
  どおり正文を`reports/`へ置く）。
- `HANDOFF.md`を更新し、flow-id 3-6完了・3-7（commit/push）へ進む。
- push後、フェーズ3の作業実施時敵対的レビューを1回実施する（ユーザー指示どおり）。

## 追記（敵対的レビュー2回目・push10後、実装の修正）

flow-id 3-7でpush10をcommit・push後、フェーズ3の作業実施時敵対的レビューを2回目実施した
（フェーズ3カウンタ=2）。対象はpush10の実装差分（設定層・集計層・レポート層・配布gitignore・
単体テスト）。12件の指摘（major 6件・minor 6件）のうち10件をMR #174へインラインコメント投稿し、
残り2件（minor/confidence medium）はレビュー本文へ報告のみとして記載した。**投稿・報告した12件
すべてに対応した。**

### 修正内容の詳細

1. **状態破壊バグ（最重要）**: `_usage_otel_fold`の出力や`_sync_usage_state_otel`の最終状態を
   検証せずに`_usage_write_otel_state`で`cursor.json`へ書き戻していた。実機で再現したところ、
   壊れたJSON行が1件混ざるだけで`jq: invalid JSON text passed to --argjson`となり
   `cursor.json`が0バイトになった。0バイトになると`_usage_read_otel_state`が既定値
   （byteOffset=0）へ自己回復するため、**次回以降は毎回ファイル先頭から読み直して同じ場所で
   失敗し続ける**（テレメトリが恒久的に集計されない）。
   - 直し方: `_usage_write_otel_state`へ書き込み前検証（`jq -e .`）を追加し、無効なら**書かず**
     終了コード1を返すよう変更。`_sync_usage_state_otel`側も`delta`・`new_state`それぞれの
     検証を追加し、無効なら警告をstderrへ出し既存の`state`をそのまま返す（今回の断面は次回へ
     持ち越す）よう修正。
   - 検証: 壊れたJSON（配列が閉じていない等）を含むoutfileに対し`_sync_usage_state_otel`を
     呼んでも、`cursor.json`が作られない（0バイトで壊れない）ことを確認。

2. **attributes配列形式でのクラッシュ**: OpenTelemetryの標準的なJSON表現では`attributes`が
   `[{key,value}]`という**配列**になりうるが、実装は`.attributes`が常にobjectであることを
   前提にしており、配列が来ると`keys | startswith`が`startswith() requires string inputs`で
   jqごと即死していた（＝上記1の状態破壊へ直結）。
   - 直し方: `is_metric_record`/`is_semantic_api_response`へ`type == "object"`のガードを
     追加。あわせて`event.name`の判定を`test("api_response")`（部分一致）から
     `== "gemini_cli.api_response"`（厳密一致）へ変更し、過剰計上のリスクも下げた。
   - 検証: attributes配列形式のエントリ1件だけのoutfileに対し、クラッシュせずcalls=0として
     扱われることを確認。

3. **カーソル妥当性検査の穴**: ファイルサイズによる縮小検知だけでは、outfileが削除・作り直し
   された後、前回のオフセットを超える量が新たに書かれた場合（＝サイズが縮まない作り直し）を
   検知できない。`tail -c`が別内容のJSONの途中から切り出し、パース失敗（→1の状態破壊）または
   誤った値の無言計上につながる。
   - 直し方: 前回読み込んだ範囲（先頭`byte_offset`バイト）のチェックサム（`cksum`）を
     `prefixFingerprint`としてstateへ保存し、次回読み込み前に同じ範囲のチェックサムを取り直して
     突き合わせる`_usage_otel_prefix_fingerprint_to_reply`を追加。不一致ならファイル縮小時と
     同じく先頭（byteOffset=0）から再取得する。
   - 検証: サイズが縮まない作り直し（削除→同程度以上のサイズで再作成）で、作り直し前の内容が
     消えず、作り直し後の内容が正しく別モデルキーとして計上されることを確認。

4. **投稿ゲートの欠落**: `post-push-usage-report.sh`の投稿要否判定（合計トークンが0なら投稿
   しない）にテレメトリの`calls`が入っておらず、「テレメトリしか無いpush」（issue #105が
   実現したい本命のケース）でレポートが出ないまま`sinceLastPush`へ繰り越され続ける不具合が
   あった。
   - 直し方: `otel_calls`を(a) `state`が空/不正な場合のフォールバック判定、(b) `total == 0`の
     投稿ゲート、の両方へ組み込んだ。stateが空でもtelemetryにcallsがある場合はトークン0の
     プレースホルダstateへフォールバックしてから通常のレポート組み立てへ進む。

5. **outfileパスの二重管理**: `sync-gemini-assets.sh`（書き込み側）が`usage/gemini-otel.log`を
   直書きし、`post-push-usage-report.sh`（読み取り側）も同じ文字列を独立して直書きしていた。
   片方を変えても、もう片方は`[ -f ... ]`で静かにスキップするだけで壊れたことに誰も気づけない。
   - 直し方: `sync-gemini-assets.sh`に`GEMINI_OTEL_OUTFILE_REL`定数を新設し`--arg`でjqフィルタへ
     渡す。読み取り側は`UsageTracking.sh`の`_usage_otel_resolve_outfile_to_reply`で
     `.gemini/settings.json`の`telemetry.outfile`を動的に読み、無ければ既定値へフォールバック
     する設計へ変更。

6. **specの矛盾・恒久参照禁止違反**: `sync-gemini-assets.sh`のコメントが「詳細:
   `.claude/docs/spec/sync-gemini-assets.md`」と正を指していたが、そのspecには
   telemetryについて「OTel計測が行われない」という**この変更で覆した結論**が書かれたままだった。
   また`UsageTracking.sh`・`post-push-usage-report.sh`のコメントがflow-id 5-5で削除される
   `reports/`のファイルを3箇所で参照していた（`.claude/rules/docs-workflow.md`が禁じる
   パターン。issue #9で過去に同じ事故が発生済み）。
   - 直し方: spec名指しをやめ`issue #105`のみを参照する形へ変更（フェーズ4でspec自体を
     更新する）。`reports/`参照はすべて`issue #105`のみの参照へ置き換えた。

7. **有効化不能であることの明示不足**: `enabled: false`固定＋`sync-gemini-assets.sh --check`の
   ゲートにより、利用者が`.gemini/settings.json`を手で`true`にしても次の再生成で無言で
   `false`へ戻り、戻す前に`--check`が食い違いを検知してflow-id 5-3が止まる。この帰結
   （現状どうやっても有効化できないこと）がコメントから読み取れなかった。
   - 直し方: コメントへ「現時点でこれをtrueへ切り替える手段は存在しない」ことを明記し、
     有効化手段の確立を本issueのスコープ外の未決定事項として明示した。

8. **テストの空洞化**: `grep -F '| モデル |' | grep -cF 'Cache Read | Thoughts'`という
   ヘッダ文字列頼みの検査は、テレメトリの数値を既存のClaude側モデル行へ加算するという
   最もありそうな退行では発火しなかった（ヘッダ文字列自体は変わらないため）。テレメトリ表の
   中身を検証するアサーションも1件も無かった。
   - 直し方: テレメトリ表の行を`| gemini-2.5-flash | 100 | 50 | 0 | 0 | 0 |`のように完全一致で
     固定するアサーションを追加。「混ざらない」の検証も、Claude側行が`$rp_claude`の値のまま
     完全一致することに加え、テレメトリのモデル名がClaude側テーブル（4列表）の範囲に1件も
     現れないことで表現し直した。

9. **md/htmlの不同期**: `reports/…実装結果.md`のケース表が9行なのに対し、対応するHTMLは8行で
   「レポート本文統合」の行が抜けていた。また、md側の複数箇所に`<div class="box ok">`
   `<span class="label">`というHTMLビュー用のマークアップがそのまま混入していた（GitHub上では
   classが効かずラベルだけが地の文として現れる）。
   - 直し方: md側のHTML断片をmarkdownの引用（`>`）へ置き換え、HTML側のケース表を最新の
     内容（12行）へ同期した。あわせてレポート全体を、今回の敵対的レビュー対応の内容を反映した
     形へ更新した（「4. 敵対的レビュー対応」節を新設）。

10. **`set -e`下でのクラッシュリスク（報告のみ・minor/medium）**: `_usage_otel_extract_
    complete_to_reply`内の`grep -n '^}$' ... | tail -1 | cut -d: -f1`は、境界行が1件も無い
    （完全なエントリが1つも無い）場合`grep`が非0を返し`pipefail`配下でパイプライン全体が
    非0になる。単純な代入文は`set -e`の一時停止対象外（`if`/`||`の中でのみ一時停止される）
    ため、この関数を直接（`||`で囲まずに）呼ぶ呼び出し文脈では関数ごと中断する。本番経路は
    `|| true`で偶然救われていたが、呼び出し文脈が変わると壊れる。
    - 直し方: 該当行へ`|| true`を追加。単体呼び出しでも安全に空扱いへ落ちることをテストで
      固定した。

11. **サマリの結論表現の言い過ぎ（報告のみ・minor/medium）**: `reports/…実装結果.md`のサマリが
    「8パターンで正しく動作することを確認」と言い切っていたが、実際に検証したのは
    「実装が前提にしている推測（属性名・境界判定方式）をそのまま写して生成した合成
    フィクスチャに対する動作」であり、実データに対する正しさは何も言っていない。
    - 直し方: サマリの結論・根拠の性質を「推測に基づく仕様どおりに動くことを合成フィクスチャ
      で確認（実データ未検証）」へ限定する表現へ修正した。

### 検証（修正後）

- `test_usage_tracking.sh`へ5ケース（作り直し検知・fold失敗時の状態保護・完全なエントリ0件・
  attributes配列形式・テレメトリ表の完全一致）を追加し、`passed=120 failures=0`を確認
  （修正前は`passed=112`）。
- `bash .claude/scripts/src/sync-gemini-assets.sh --check` → exit=0（`GEMINI_OTEL_OUTFILE_REL`
  導入・コメント修正後の再生成）。
- 全17本の`test_*.sh`を再実行し、すべて`failures=0`。
- `git diff <ブランチ分岐点SHA> -- .claude/`の削除行を再確認し、DDR/spec本文の point-in-time
  記録を破壊する削除が無いことを確認（削除行はすべて本セッションで自分が書いたコードの
  書き換えのみ）。

## 次の一歩

- 上記の修正一式を`commit`スキル経由でcommit・push（push11）し、レビュー依頼を行う（flow-id
  3-7の続き）。
- push後は3-8（人間レビュー）を待つ。
